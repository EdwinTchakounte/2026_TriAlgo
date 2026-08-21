// =============================================================
// FICHIER : music_provider.dart
// ROLE    : Etat global "musique de fond" + persistance + lecteur
// =============================================================
//
// Trois responsabilites :
//   1. Memoriser ON/OFF entre les lancements (SharedPreferences).
//   2. Piloter le lecteur audio (audioplayers) -> jouer / arreter
//      l'asset assets/audio/bg.wav en boucle quand ON.
//   3. Exposer un Notifier Riverpod simple (bool) aux widgets.
//
// Robustesse :
//   - L'asset audio peut etre absent (build sans audio) -> on
//     attrape l'exception du lecteur et on log silencieusement,
//     l'UI reste fonctionnelle (toggle still on, mais muet).
//   - Toggle synchrone cote UI : on persiste avant de declencher
//     la lecture (evite les flickers).
// =============================================================

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicController extends AsyncNotifier<bool> {
  // Singleton du lecteur audio. Un seul player suffit ; le ReleaseMode
  // .loop fait que la lecture redemarre automatiquement a la fin de
  // la track sans intervention.
  static final AudioPlayer _player = AudioPlayer();
  static const _prefsKey = 'music_enabled';

  @override
  Future<bool> build() async {
    // 1. Lit l'etat persiste.
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKey) ?? false;

    // 2. Aligne le lecteur sur cet etat avant le 1er render.
    if (enabled) {
      await _safePlay();
    }
    return enabled;
  }

  // Toggle ON/OFF. Persiste, met a jour l'etat Riverpod, et
  // demarre/arrete le lecteur.
  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    final next = !current;
    state = AsyncData(next);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, next);

    if (next) {
      await _safePlay();
    } else {
      await _safeStop();
    }
  }

  // -----------------------------------------------------------
  // Helpers : encapsulent les appels du lecteur dans des try/catch
  // -----------------------------------------------------------
  // Si l'asset n'existe pas ou si le moteur audio rate (rare sur
  // Android), on echoue silencieusement. Le toggle reste utilisable,
  // l'UI ne crashe pas.
  Future<void> _safePlay() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.35); // 35% : un fond, pas un solo
      await _player.play(AssetSource('audio/bg.wav'));
    } catch (_) {
      // Asset manquant ou plateforme non supportee -> on ignore.
    }
  }

  Future<void> _safeStop() async {
    try {
      await _player.stop();
    } catch (_) {
      // Idem : non bloquant.
    }
  }
}

final musicProvider =
    AsyncNotifierProvider<MusicController, bool>(MusicController.new);
