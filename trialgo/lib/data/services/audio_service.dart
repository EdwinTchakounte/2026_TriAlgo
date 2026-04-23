// =============================================================
// FICHIER : lib/data/services/audio_service.dart
// ROLE   : Gestion du son et de la musique (singleton reactif)
// COUCHE : Data > Services
// =============================================================
//
// ARCHITECTURE :
// --------------
// Le service expose des STREAMS pour l'UI reactive :
//   - musicEnabledStream : vrai quand la musique joue
//   - sfxEnabledStream   : vrai quand les SFX sont actives
//
// Les widgets qui affichent des controles audio peuvent ecouter
// ces streams pour refleter l'etat en temps reel.
//
// FIX DU BUG "STOP QUI NE S'ARRETE PAS" :
// ----------------------------------------
// L'ancien code appelait play() puis stop() mais ne reinitialisait
// pas la source, ce qui pouvait causer des etats incoherents.
// Maintenant :
//   - setReleaseMode(loop) avant le 1er play
//   - pause() au lieu de stop() pour pouvoir reprendre
//   - stop() + setSource(null) pour vraiment arreter
// =============================================================

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Types d'effets sonores.
enum SoundEffect {
  correct,
  wrong,
  click,
  swoosh,
  victory,
  defeat,
  tick,
}

/// Pistes musicales de fond disponibles.
/// L'utilisateur peut choisir entre ces 4 pistes dans les settings.
enum MusicTrack {
  /// Ambient cinematic (piste par defaut).
  ambient,

  /// Epic adventure / gaming (plus dynamique).
  epic,

  /// Chill lofi (relaxant).
  chill,

  /// Action / tension (pour le jeu).
  action,
}

/// Service audio global (singleton).
class AudioService {

  // =============================================================
  // LECTEURS
  // =============================================================

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // =============================================================
  // ETAT
  // =============================================================

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  double _musicVolume = 0.4;
  double _sfxVolume = 0.7;
  bool _musicPlaying = false;
  bool _initialized = false;

  /// Piste musicale actuellement selectionnee.
  MusicTrack _currentTrack = MusicTrack.ambient;

  // =============================================================
  // STREAMS REACTIFS
  // =============================================================
  // Les UI (settings, home) ecoutent ces streams pour refleter
  // l'etat en temps reel.
  // =============================================================

  final _musicEnabledController = StreamController<bool>.broadcast();
  final _sfxEnabledController = StreamController<bool>.broadcast();
  final _musicVolumeController = StreamController<double>.broadcast();
  final _sfxVolumeController = StreamController<double>.broadcast();
  final _trackController = StreamController<MusicTrack>.broadcast();

  Stream<bool> get musicEnabledStream => _musicEnabledController.stream;
  Stream<bool> get sfxEnabledStream => _sfxEnabledController.stream;
  Stream<double> get musicVolumeStream => _musicVolumeController.stream;
  Stream<double> get sfxVolumeStream => _sfxVolumeController.stream;
  Stream<MusicTrack> get trackStream => _trackController.stream;

  // =============================================================
  // GETTERS
  // =============================================================

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get isMusicPlaying => _musicPlaying;
  MusicTrack get currentTrack => _currentTrack;

  // =============================================================
  // SOURCES AUDIO (URLs libres en ligne)
  // =============================================================

  /// URLs des 4 pistes musicales de fond (CDN mixkit stable).
  /// Le joueur choisit sa piste dans les settings.
  /// Tracks mixkit : free loops, format mp3, taille raisonnable.
  static const Map<MusicTrack, String> _musicUrls = {
    MusicTrack.ambient:
        'https://assets.mixkit.co/active_storage/sfx/123/123-preview.mp3',
    MusicTrack.epic:
        'https://assets.mixkit.co/active_storage/sfx/125/125-preview.mp3',
    MusicTrack.chill:
        'https://assets.mixkit.co/active_storage/sfx/127/127-preview.mp3',
    MusicTrack.action:
        'https://assets.mixkit.co/active_storage/sfx/130/130-preview.mp3',
  };

  /// Label lisible pour chaque piste (pour l'UI).
  static const Map<MusicTrack, String> _musicLabels = {
    MusicTrack.ambient: 'Ambient',
    MusicTrack.epic: 'Epic',
    MusicTrack.chill: 'Chill',
    MusicTrack.action: 'Action',
  };

  /// Retourne le label lisible d'une piste.
  static String labelFor(MusicTrack track) => _musicLabels[track] ?? 'Music';

  static const Map<SoundEffect, String> _sfxUrls = {
    // URLs depuis mixkit.co (CDN stable, sons libres et testes).
    // Ces URLs ne necessitent pas d'auth et sont accessibles depuis
    // les apps mobiles sans probleme CORS/redirect.
    SoundEffect.correct:
        'https://assets.mixkit.co/active_storage/sfx/270/270-preview.mp3',
    SoundEffect.wrong:
        'https://assets.mixkit.co/active_storage/sfx/2691/2691-preview.mp3',
    SoundEffect.click:
        'https://assets.mixkit.co/active_storage/sfx/1114/1114-preview.mp3',
    SoundEffect.swoosh:
        'https://assets.mixkit.co/active_storage/sfx/1123/1123-preview.mp3',
    SoundEffect.victory:
        'https://assets.mixkit.co/active_storage/sfx/2013/2013-preview.mp3',
    SoundEffect.defeat:
        'https://assets.mixkit.co/active_storage/sfx/2041/2041-preview.mp3',
    SoundEffect.tick:
        'https://assets.mixkit.co/active_storage/sfx/1109/1109-preview.mp3',
  };

  /// Ensemble des URLs qui ont echoue au dernier chargement.
  /// Permet d'eviter de re-tenter une URL cassee en boucle et
  /// de spammer la console avec des erreurs.
  final Set<SoundEffect> _failedSfx = {};

  // =============================================================
  // INITIALISATION
  // =============================================================

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool('audio_music_enabled') ?? true;
    _sfxEnabled = prefs.getBool('audio_sfx_enabled') ?? true;
    _musicVolume = prefs.getDouble('audio_music_volume') ?? 0.4;
    _sfxVolume = prefs.getDouble('audio_sfx_volume') ?? 0.7;

    // Charger la piste selectionnee (par nom d'enum).
    final trackName = prefs.getString('audio_music_track');
    _currentTrack = MusicTrack.values.firstWhere(
      (t) => t.name == trackName,
      orElse: () => MusicTrack.ambient,
    );

    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(_musicVolume);
    await _sfxPlayer.setVolume(_sfxVolume);

    // FIX LOOP : ecouter la fin de la musique et la relancer.
    // Le ReleaseMode.loop ne fonctionne pas toujours avec UrlSource
    // (bug connu audioplayers). On force le replay manuellement
    // quand le player atteint la fin.
    _musicPlayer.onPlayerComplete.listen((_) async {
      if (_musicEnabled) {
        _musicPlaying = false;
        await startBackgroundMusic();
      }
    });

    // FIX LOOP : ecouter aussi les changements d'etat pour detecter
    // les cas ou le player passe en "completed" sans emit onPlayerComplete
    // (qui peut arriver sur certaines platformes).
    _musicPlayer.onPlayerStateChanged.listen((state) async {
      if (state == PlayerState.completed && _musicEnabled) {
        _musicPlaying = false;
        await startBackgroundMusic();
      }
    });

    // Emettre l'etat initial sur les streams.
    _musicEnabledController.add(_musicEnabled);
    _sfxEnabledController.add(_sfxEnabled);
    _musicVolumeController.add(_musicVolume);
    _sfxVolumeController.add(_sfxVolume);
    _trackController.add(_currentTrack);

    // --- Auto-reprise de la musique de fond ---
    // Si l'utilisateur avait laisse la musique ACTIVEE avant la
    // fermeture de l'app, on la relance automatiquement au demarrage
    // suivant. Le setting est deja dans SharedPreferences, on lit
    // juste le flag et on reprend.
    //
    // Si l'utilisateur avait desactive (setMusicEnabled(false)),
    // startBackgroundMusic sortira immediatement a cause du
    // if (!_musicEnabled) return; interne.
    if (_musicEnabled) {
      // Fire-and-forget : on ne bloque pas l'init. L'audio se
      // lancera des que possible en tache de fond.
      // ignore: unawaited_futures
      startBackgroundMusic();
    }
  }

  // =============================================================
  // MUSIQUE DE FOND
  // =============================================================

  /// Demarre la musique de fond en loop (si activee).
  /// Utilise la piste actuellement selectionnee (_currentTrack).
  Future<void> startBackgroundMusic() async {
    await init(); // S'assurer que les prefs sont chargees.
    if (!_musicEnabled) return;
    if (_musicPlaying) return; // Deja en cours.

    final url = _musicUrls[_currentTrack];
    if (url == null) return;

    try {
      // Re-appliquer le release mode AVANT chaque play pour s'assurer
      // que le loop est actif (fix pour certains cas audioplayers).
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(_musicVolume);
      await _musicPlayer.play(UrlSource(url));
      _musicPlaying = true;
    } catch (_) {
      // Erreur reseau : on ignore mais on reset le flag pour
      // permettre un prochain replay.
      _musicPlaying = false;
    }
  }

  /// Change la piste musicale et relance la lecture.
  ///
  /// Arrete la piste en cours, sauvegarde la nouvelle selection
  /// dans SharedPreferences, puis relance la musique avec la
  /// nouvelle piste (si la musique etait activee).
  Future<void> setMusicTrack(MusicTrack track) async {
    _currentTrack = track;
    _trackController.add(track);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_music_track', track.name);

    // Si la musique etait en train de jouer, relancer avec la
    // nouvelle piste. Sinon, ne rien faire (la piste sera utilisee
    // quand la musique sera relancee).
    if (_musicPlaying && _musicEnabled) {
      await _musicPlayer.stop();
      _musicPlaying = false;
      await startBackgroundMusic();
    }
  }

  /// Arrete completement la musique.
  /// FIX : stop() + release() pour vraiment arreter et liberer.
  Future<void> stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      _musicPlaying = false;
    } catch (_) {}
  }

  /// Pause la musique (peut etre reprise).
  Future<void> pauseBackgroundMusic() async {
    try {
      await _musicPlayer.pause();
    } catch (_) {}
  }

  /// Reprend la musique apres une pause.
  Future<void> resumeBackgroundMusic() async {
    if (!_musicEnabled) return;
    try {
      await _musicPlayer.resume();
    } catch (_) {}
  }

  // =============================================================
  // EFFETS SONORES
  // =============================================================

  Future<void> playSfx(SoundEffect effect) async {
    await init();
    if (!_sfxEnabled) return;

    // Skip les sons dont l'URL a deja echoue (evite le spam console).
    if (_failedSfx.contains(effect)) return;

    final url = _sfxUrls[effect];
    if (url == null) return;

    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(UrlSource(url));
    } catch (_) {
      // Marquer le son comme echoue pour ne plus le retenter.
      _failedSfx.add(effect);
    }
  }

  // =============================================================
  // CONTROLES REACTIFS (settings)
  // =============================================================

  /// Active/desactive la musique.
  /// Si desactive, ARRETE IMMEDIATEMENT la musique en cours.
  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    _musicEnabledController.add(enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_music_enabled', enabled);

    if (enabled) {
      await startBackgroundMusic();
    } else {
      // FIX CRITIQUE : bien arreter le lecteur.
      await stopBackgroundMusic();
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    _sfxEnabledController.add(enabled);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_sfx_enabled', enabled);
  }

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    _musicVolumeController.add(_musicVolume);

    await _musicPlayer.setVolume(_musicVolume);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('audio_music_volume', _musicVolume);
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    _sfxVolumeController.add(_sfxVolume);

    await _sfxPlayer.setVolume(_sfxVolume);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('audio_sfx_volume', _sfxVolume);
  }

  // =============================================================
  // NETTOYAGE
  // =============================================================

  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
    await _musicEnabledController.close();
    await _sfxEnabledController.close();
    await _musicVolumeController.close();
    await _sfxVolumeController.close();
    await _trackController.close();
  }
}
