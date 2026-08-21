// =============================================================
// FICHIER : lib/data/services/profile_service.dart
// ROLE   : Gestion du profil + activation + device binding
// COUCHE : Data > Services
// =============================================================
//
// ARCHITECTURE :
// --------------
// Le profil utilisateur est compose de :
//   - user_profiles : infos generales (username, avatar, admin)
//   - user_games    : stats par jeu (level, score, vies)
//
// Le service expose :
//   - createProfile()     : creer user_profiles apres signUp
//   - checkDevice()       : verifier le device binding au login
//   - activateCode()      : valider un code + lier au device (via RPC)
//   - loadCurrentGame()   : charger les stats du jeu selectionne
//   - updateStats()       : sauvegarder apres une partie
//   - unlockCard()        : ajouter une carte au deck
//   - buyLives()          : acheter des vies avec les points
//
// DEVICE BINDING :
// ----------------
// La verification est faite au moment de l'activation (pas au login)
// via la fonction SQL activate_code() qui gere tout :
//   - Premier use → bind
//   - Re-use meme device → ok
//   - Change device → incremente compteur
//   - Max 3 changements → blocage
//
// =============================================================

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/core/session/session_utilisateur.dart';
import 'package:trialgo/data/datasources/http/http_auth_datasource.dart';
import 'package:trialgo/data/datasources/http/http_codes_datasource.dart';
import 'package:trialgo/data/datasources/http/http_profile_datasource.dart';
import 'package:trialgo/data/datasources/http/http_public_games_datasource.dart';
import 'package:trialgo/data/datasources/http/http_sessions_datasource.dart';
import 'package:trialgo/data/datasources/http/http_stars_datasource.dart';
import 'package:trialgo/data/datasources/http/http_unlocked_cards_datasource.dart';
import 'package:trialgo/data/datasources/http/http_user_games_datasource.dart';
import 'package:trialgo/domain/entities/game_entity.dart';
import 'package:trialgo/domain/entities/session_entity.dart';
import 'package:trialgo/data/models/game_model.dart';
import 'package:trialgo/data/models/session_model.dart';

/// Resultat d'une tentative d'activation de code.
class ActivationResult {
  /// True si l'activation a reussi.
  final bool success;

  /// Message a afficher a l'utilisateur.
  final String message;

  /// True si le code est definitivement bloque.
  final bool isBlocked;

  /// Nombre de changements de device restants.
  final int? changesLeft;

  /// ID du jeu active (si succes).
  final String? gameId;

  const ActivationResult({
    required this.success,
    required this.message,
    this.isBlocked = false,
    this.changesLeft,
    this.gameId,
  });
}


/// Service de gestion du profil utilisateur.
class ProfileService {

  // =============================================================
  // DATASOURCES HTTP (mode FastAPI)
  // =============================================================
  // Instances reutilisees a chaque appel : evite de recreer les
  // clients Dio inutilement. Toutes partagent le meme Dio singleton
  // (DioClient.instance) via leur constructeur par defaut. Inertes
  // en mode Supabase (jamais touchees).
  // =============================================================

  final HttpProfileDatasource _httpProfile = HttpProfileDatasource();
  final HttpUserGamesDatasource _httpUserGames = HttpUserGamesDatasource();
  final HttpUnlockedCardsDatasource _httpUnlockedCards =
      HttpUnlockedCardsDatasource();
  final HttpSessionsDatasource _httpSessions = HttpSessionsDatasource();
  final HttpStarsDatasource _httpStars = HttpStarsDatasource();
  final HttpPublicGamesDatasource _httpPublicGames = HttpPublicGamesDatasource();

  // =============================================================
  // CACHE EN MEMOIRE
  // =============================================================

  /// Device ID en cache (recupere une fois).
  String? _cachedDeviceId;

  /// Profil utilisateur general (user_profiles).
  Map<String, dynamic>? _profile;

  /// Stats du jeu actuellement joue (user_games).
  Map<String, dynamic>? _currentGameStats;

  /// Liste des jeux actifs de l'utilisateur.
  List<GameEntity> _userGames = [];

  /// Cache des N dernieres sessions du jeu actif.
  /// Rempli par loadRecentSessions() et rafraichi apres chaque insertSession().
  /// Le plus recent en premier (ORDER BY played_at DESC).
  List<SessionEntity> _recentSessions = [];

  // =============================================================
  // GETTERS
  // =============================================================

  Map<String, dynamic>? get profile => _profile;
  Map<String, dynamic>? get currentGameStats => _currentGameStats;
  List<GameEntity> get userGames => _userGames;
  List<SessionEntity> get recentSessions => _recentSessions;

  /// ID du jeu actuellement selectionne.
  String? get selectedGameId => _profile?['selected_game_id'] as String?;

  // =============================================================
  // METHODE : getDeviceId
  // =============================================================
  // Recupere l'identifiant unique du device via device_info_plus.
  // Cache en memoire + fallback SharedPreferences pour le web.
  // =============================================================

  /// Retourne l'identifiant unique du device.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final deviceInfo = DeviceInfoPlugin();

    try {
      try {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedDeviceId = androidInfo.id;
        return _cachedDeviceId!;
      } catch (_) {}

      try {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'ios-unknown';
        return _cachedDeviceId!;
      } catch (_) {}

      // Fallback web/desktop : UUID local persistant.
      final prefs = await SharedPreferences.getInstance();
      var fallback = prefs.getString('device_id_fallback');
      if (fallback == null) {
        fallback = 'web-${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id_fallback', fallback);
      }
      _cachedDeviceId = fallback;
      return _cachedDeviceId!;
    } catch (_) {
      _cachedDeviceId = 'unknown-device';
      return _cachedDeviceId!;
    }
  }

  // =============================================================
  // METHODE : createProfile
  // =============================================================
  // Cree le profil utilisateur apres signUp.
  // Idempotent : si le profil existe deja, ne fait rien.
  // =============================================================

  /// Cree le profil de l'utilisateur connecte.
  Future<void> createProfile({String? username}) async {
    if (ApiConfig.isFastApi) {
      // Rien a creer : cote FastAPI, le profil n'est pas une table
      // separee. username, avatar_id et selected_game_id sont des
      // colonnes de `users`, renseignees avec leurs valeurs par
      // defaut des l'inscription (POST /api/auth/register).
      //
      // Cette methode existait pour compenser une contrainte de
      // Supabase : auth.users y est gere par le service, donc il
      // fallait une table user_profiles a cote, creee a la main apres
      // l'inscription. La contrainte a disparu avec le changement de
      // backend (voir la migration 0004 cote serveur).
      //
      // Si un username est fourni, on le pousse quand meme, pour que
      // l'appelant obtienne le comportement qu'il attend.
      if (username != null && username.isNotEmpty) {
        await updateUsername(username);
      }
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('Aucun utilisateur connecte');

    // Upsert : insert ou update selon si la ligne existe.
    await supabase.from('user_profiles').upsert({
      'id': user.id,
      'username': username ?? 'Joueur',
      'avatar_id': 'avatar_1',
    }, onConflict: 'id');
  }

  // =============================================================
  // METHODE : activateCode
  // =============================================================
  // Active un code d'activation.
  // Appelle la fonction SQL activate_code() qui gere tout :
  //   - Validation du code
  //   - Verification du device
  //   - Incrementation du compteur en cas de changement
  //   - Blocage apres max changements
  //   - Creation de l'entree user_games
  //
  // Retourne un ActivationResult avec le message approprie.
  // =============================================================

  /// Active un code et lie le device.
  ///
  /// Branche selon [ApiConfig.mode] :
  ///   - FastAPI : POST /api/codes/activate puis PATCH /api/me/profile
  ///   - Supabase : RPC activate_code (logique SQL serveur).
  Future<ActivationResult> activateCode(String code) async {
    final deviceId = await getDeviceId();

    if (ApiConfig.isFastApi) {
      return _activateCodeFastApi(code: code, deviceId: deviceId);
    }
    return _activateCodeSupabase(code: code, deviceId: deviceId);
  }

  // -----------------------------------------------------------
  // Branche FastAPI : /api/codes/activate (5 cas reasoned)
  // -----------------------------------------------------------
  Future<ActivationResult> _activateCodeFastApi({
    required String code,
    required String deviceId,
  }) async {
    try {
      // 1. POST /api/codes/activate {code, device_id}
      //    Le backend cree la ligne user_games si premiere activation
      //    (cf module codes/routes.py).
      final res = await HttpCodesDatasource().activate(
        code: code,
        deviceId: deviceId,
      );
      final success = res['success'] as bool? ?? false;
      final message = res['message'] as String? ?? 'Erreur inconnue';
      final reason = res['reason'] as String?;
      final gameId = res['game_id'] as String?;
      final changesLeft = res['changes_left'] as int?;
      // is_blocked deductible du reason='blocked'.
      final isBlocked = reason == 'blocked';

      if (success && gameId != null) {
        // 2. Marquer ce jeu comme selectionne (PATCH /api/me/profile).
        try {
          await HttpProfileDatasource().updateMyProfile(
            selectedGameId: gameId,
          );
        } catch (_) {
          // Selection non bloquante : on garde le succes meme si
          // l'update profil echoue (l'user pourra reselectionner).
        }
      }

      return ActivationResult(
        success: success,
        message: message,
        isBlocked: isBlocked,
        changesLeft: changesLeft,
        gameId: gameId,
      );
    } catch (e) {
      return ActivationResult(
        success: false,
        message: 'Erreur reseau : ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  // -----------------------------------------------------------
  // Branche SUPABASE (historique) : RPC activate_code
  // -----------------------------------------------------------
  Future<ActivationResult> _activateCodeSupabase({
    required String code,
    required String deviceId,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const ActivationResult(
        success: false,
        message: 'Aucun utilisateur connecte',
      );
    }

    // S'assurer que le profil existe (necessaire pour user_games FK).
    await createProfile(username: user.email?.split('@').first);

    try {
      final response = await supabase.rpc('activate_code', params: {
        'p_code': code,
        'p_user_id': user.id,
        'p_device_id': deviceId,
      });

      final result = response as Map<String, dynamic>;
      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? 'Erreur inconnue';
      final isBlocked = result['blocked'] as bool? ?? false;
      final changesLeft = result['changes_left'] as int?;
      final gameId = result['game_id'] as String?;

      if (success && gameId != null) {
        await supabase.from('user_profiles').update({
          'selected_game_id': gameId,
        }).eq('id', user.id);
        await loadProfile();
        await loadUserGames();
      }

      return ActivationResult(
        success: success,
        message: message,
        isBlocked: isBlocked,
        changesLeft: changesLeft,
        gameId: gameId,
      );
    } catch (e) {
      return ActivationResult(
        success: false,
        message: 'Erreur reseau : $e',
      );
    }
  }

  // =============================================================
  // METHODE : loadProfile
  // =============================================================

  /// Charge le profil user_profiles dans le cache.
  Future<Map<String, dynamic>?> loadProfile() async {
    if (ApiConfig.isFastApi) {
      // FastAPI : GET /api/me/profile (auth via interceptor Dio).
      // Reponse contient user_id, username, avatar_id, selected_game_id,
      // stars, stars_max -> ce Map sert tel quel comme cache _profile.
      try {
        final data = await _httpProfile.getMyProfile();
        _profile = data;
        return data;
      } catch (_) {
        // En cas d'echec reseau on garde le cache existant pour ne pas
        // ecraser un profil deja charge.
        return _profile;
      }
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final data = await supabase
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    _profile = data;
    return data;
  }

  // =============================================================
  // METHODE : loadUserGames
  // =============================================================

  /// Charge la liste des jeux actives par l'utilisateur.
  Future<List<GameEntity>> loadUserGames() async {
    if (ApiConfig.isFastApi) {
      // FastAPI : /api/me/games renvoie seulement les user_games
      // (game_id, level, score, vies, seconds_to_next_life...) sans
      // les infos meta du jeu (name, description, cover_image).
      // On croise avec /api/public/games (catalogue public) pour
      // construire des GameEntity complets.
      try {
        final userGames = await _httpUserGames.listMyGames();
        if (userGames.isEmpty) {
          _userGames = [];
          return [];
        }

        // Map gameId -> meta pour lookup O(1) lors du croisement.
        final publicGames = await _httpPublicGames.listPublicGames();
        final metaById = <String, Map<String, dynamic>>{
          for (final g in publicGames) g['id'] as String: g,
        };

        _userGames = userGames.map((row) {
          final gid = row['game_id'] as String;
          final meta = metaById[gid];
          if (meta != null) {
            // Le catalogue public a tout le meta : on construit via
            // GameModel.fromJson (memes cles : id/name/description/...).
            return GameModel.fromJson(meta);
          }
          // Fallback : jeu desactive cote public mais toujours actif
          // pour cet user. On construit une entite minimale.
          return GameEntity(
            id: gid,
            name: 'Jeu inconnu',
          );
        }).toList();

        return _userGames;
      } catch (_) {
        _userGames = [];
        return [];
      }
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null) {
      _userGames = [];
      return [];
    }

    // JOIN entre user_games et games pour recuperer les infos du jeu.
    final data = await supabase
        .from('user_games')
        .select('game_id, games(*)')
        .eq('user_id', user.id);

    _userGames = (data as List<dynamic>)
        .map((row) => GameModel.fromJson(row['games'] as Map<String, dynamic>))
        .toList();

    return _userGames;
  }

  // =============================================================
  // METHODE : loadCurrentGameStats
  // =============================================================

  /// Charge les stats du jeu selectionne (depuis user_games).
  Future<Map<String, dynamic>?> loadCurrentGameStats() async {
    if (ApiConfig.isFastApi) {
      // Sans jeu actif on ne sait pas quoi requeter.
      if (selectedGameId == null) {
        _currentGameStats = null;
        return null;
      }
      try {
        // GET /api/me/games/{game_id} : renvoie un Map prepare
        // (current_level, total_score, lives, max_lives,
        // seconds_to_next_life...). Le backend a deja applique le
        // refill, donc l'UI affiche un compteur a jour.
        final data = await _httpUserGames.getMyGame(selectedGameId!);
        _currentGameStats = data;
        return data;
      } catch (_) {
        // 404 ou reseau : on ecrase pour eviter d'afficher un cache stale.
        _currentGameStats = null;
        return null;
      }
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null || selectedGameId == null) return null;

    final data = await supabase
        .from('user_games')
        .select()
        .eq('user_id', user.id)
        .eq('game_id', selectedGameId!)
        .maybeSingle();

    _currentGameStats = data;
    return data;
  }

  // =============================================================
  // METHODE : selectGame
  // =============================================================

  /// Change le jeu actuellement joue.
  Future<void> selectGame(String gameId) async {
    if (ApiConfig.isFastApi) {
      // PATCH /api/me/profile {selected_game_id} : le backend valide
      // que le user a bien active ce jeu (via user_games). Pas besoin
      // de re-verifier cote client.
      await _httpProfile.updateMyProfile(selectedGameId: gameId);
      // Recharger pour synchroniser le cache _profile + stats du jeu.
      await loadProfile();
      await loadCurrentGameStats();
      return;
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('user_profiles').update({
      'selected_game_id': gameId,
    }).eq('id', user.id);

    await loadProfile();
    await loadCurrentGameStats();
  }

  // =============================================================
  // METHODE : updateStats
  // =============================================================

  /// Met a jour les stats apres une partie (score, vies, niveau).
  Future<void> updateStats({
    required int scoreGained,
    required int livesUsed,
    bool levelUp = false,
  }) async {
    if (ApiConfig.isFastApi) {
      // Rien a ecrire ici. Cote FastAPI, score, niveau et vies sont
      // deja mis a jour par POST /api/me/sessions, appele juste avant
      // par insertSession(). Refaire le calcul localement puis le
      // pousser reviendrait a compter deux fois les points gagnes.
      //
      // Le role de cette methode se reduit donc a rafraichir le cache
      // local depuis la valeur qui fait autorite, celle du serveur.
      // C'est aussi plus juste que le calcul local d'origine : le
      // backend applique en plus le refill des vies lie au temps
      // ecoule, que le client ne sait pas reproduire.
      //
      // Les parametres restent dans la signature pour ne pas modifier
      // les appelants, et parce qu'ils gardent leur sens en mode
      // supabase.
      await loadCurrentGameStats();
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null || _currentGameStats == null) return;

    final newScore = (_currentGameStats!['total_score'] as int) + scoreGained;
    final newLives = ((_currentGameStats!['lives'] as int) - livesUsed)
        .clamp(0, _currentGameStats!['max_lives'] as int);
    final newLevel = levelUp
        ? (_currentGameStats!['current_level'] as int) + 1
        : _currentGameStats!['current_level'] as int;

    await supabase
        .from('user_games')
        .update({
          'total_score': newScore,
          'lives': newLives,
          'current_level': newLevel,
        })
        .eq('user_id', user.id)
        .eq('game_id', selectedGameId!);

    _currentGameStats = {
      ..._currentGameStats!,
      'total_score': newScore,
      'lives': newLives,
      'current_level': newLevel,
    };
  }

  // =============================================================
  // METHODE : insertSession
  // =============================================================
  // Enregistre une session de jeu (une partie) dans user_sessions.
  //
  // Cette methode est APPELEE A LA FIN D'UNE PARTIE. Elle trace le
  // snapshot complet de la partie jouee :
  //   - combien de bonnes/mauvaises reponses
  //   - quel score gagne
  //   - etoiles obtenues
  //   - duree totale
  //
  // Complementaire a updateStats() :
  //   - updateStats  : MAJ du cumul (total_score, level, lives)
  //   - insertSession: AJOUT d'une ligne d'historique
  //
  // Ces deux operations sont appelees ENSEMBLE par le flux fin de
  // partie (cf. ProfileNotifier.recordGameSession).
  //
  // Apres l'insert, on met a jour le cache _recentSessions en
  // prefixant la nouvelle session : pas besoin de re-requeter la BDD,
  // gain de perf pour l'affichage immediat sur la home.
  // =============================================================

  /// Insere une ligne dans user_sessions pour tracer la partie.
  ///
  /// Retourne la [SessionEntity] construite a partir de la reponse
  /// Supabase (avec id et played_at remplis par la BDD).
  /// Retourne null si aucun utilisateur connecte ou pas de jeu actif.
  Future<SessionEntity?> insertSession({
    required int level,
    required int scoreGained,
    required int correctAnswers,
    required int wrongAnswers,
    required int questionsTotal,
    required int maxStreak,
    required int durationSeconds,
    required bool passed,
    required int starsEarned,
  }) async {
    // Securite : sans jeu actif, on ne sait pas a quel jeu rattacher.
    final gameId = selectedGameId;
    if (gameId == null) return null;

    if (ApiConfig.isFastApi) {
      // POST /api/me/sessions fait DEUX choses dans une meme
      // transaction serveur :
      //   - insere la ligne d'historique de la partie ;
      //   - met a jour total_score, current_level et lives sur
      //     user_games.
      //
      // C'est pour cela que updateStats() n'a plus d'ecriture a faire
      // dans ce mode : elle se contente de relire l'etat (voir son
      // commentaire).
      //
      // Faire porter les deux ecritures par le serveur evite qu'une
      // coupure reseau entre les deux laisse le score et l'historique
      // en desaccord -- ce que le chemin Supabase, en deux requetes
      // separees, ne garantissait pas.
      //
      // Pas de user_id a fournir : le backend le deduit du JWT.
      try {
        final data = await _httpSessions.recordSession(
          gameId: gameId,
          level: level,
          scoreGained: scoreGained,
          correctAnswers: correctAnswers,
          wrongAnswers: wrongAnswers,
          questionsTotal: questionsTotal,
          maxStreak: maxStreak,
          durationSeconds: durationSeconds,
          passed: passed,
          starsEarned: starsEarned,
        );
        final session = SessionModel.fromJson(data);
        _recentSessions = [session, ..._recentSessions];
        return session;
      } catch (_) {
        // L'historique est perdu pour cette partie, mais on ne casse
        // pas l'ecran de resultat : l'appelant sait traiter le null.
        return null;
      }
    }

    // Securite : sans user connecte, on ne peut pas tracer.
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    // Preparer le payload via SessionModel (source unique de mapping).
    // user_id est ajoute ici explicitement pour correspondre a la
    // policy RLS (WITH CHECK user_id = auth.uid()).
    final payload = <String, dynamic>{
      'user_id': user.id,
      ...SessionModel.toInsertJson(
        gameId: gameId,
        level: level,
        scoreGained: scoreGained,
        correctAnswers: correctAnswers,
        wrongAnswers: wrongAnswers,
        questionsTotal: questionsTotal,
        maxStreak: maxStreak,
        durationSeconds: durationSeconds,
        passed: passed,
        starsEarned: starsEarned,
      ),
    };

    // INSERT + RETURNING : on recupere la ligne inseree complete
    // (avec id UUID et played_at TIMESTAMPTZ remplis par la BDD).
    // .select().single() renvoie la ligne en Map<String, dynamic>.
    final inserted = await supabase
        .from('user_sessions')
        .insert(payload)
        .select()
        .single();

    // Convertir en entite domain propre.
    final session = SessionModel.fromJson(inserted);

    // Mettre a jour le cache local : insere en tete (plus recent en premier).
    // Cela permet a la home de montrer instantanement la session sans
    // attendre un re-fetch de la BDD.
    _recentSessions = [session, ..._recentSessions];

    return session;
  }

  // =============================================================
  // METHODE : loadRecentSessions
  // =============================================================
  // Charge les N dernieres sessions du joueur pour le jeu actif.
  //
  // Utilisee au reload du profil, pour populer le cache une fois.
  // L'affichage de la home lit ensuite _recentSessions (cache).
  //
  // Le tri est fait cote BDD via ORDER BY played_at DESC, qui utilise
  // l'index idx_sessions_user_game_date (migration 002) pour etre
  // efficace meme avec des milliers de sessions en BDD.
  // =============================================================

  /// Charge les [limit] dernieres sessions du jeu actif dans le cache.
  ///
  /// Retourne la liste chargee (aussi accessible via get recentSessions).
  /// Retourne [] si pas de user ou pas de jeu actif.
  Future<List<SessionEntity>> loadRecentSessions({int limit = 5}) async {
    if (ApiConfig.isFastApi) {
      // Sans jeu actif on ne charge rien : meme contrat que Supabase.
      if (selectedGameId == null) {
        _recentSessions = [];
        return [];
      }
      try {
        // GET /api/me/sessions?game_id=...&limit=...
        // Reponse : { items: [...], total, limit, offset }
        // items est trie par played_at DESC cote backend (cf module
        // sessions_history/routes.py), donc on peut mapper directement.
        final page = await _httpSessions.listMySessions(
          gameId: selectedGameId,
          limit: limit,
        );
        final items = (page['items'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        // SessionModel.fromJson lit les memes cles que FastAPI
        // expose (id, user_id, game_id, level, score_gained,
        // correct_answers, wrong_answers, questions_total, max_streak,
        // duration_seconds, passed, stars_earned, played_at ISO8601).
        _recentSessions = items.map(SessionModel.fromJson).toList();
        return _recentSessions;
      } catch (_) {
        _recentSessions = [];
        return [];
      }
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null || selectedGameId == null) {
      _recentSessions = [];
      return [];
    }

    // SELECT filtre par user + jeu, trie par date decroissante, limite a N.
    // L'index couvrant (user_id, game_id, played_at DESC) rend cette
    // requete O(log n) meme avec beaucoup de sessions.
    final data = await supabase
        .from('user_sessions')
        .select()
        .eq('user_id', user.id)
        .eq('game_id', selectedGameId!)
        .order('played_at', ascending: false)
        .limit(limit);

    // Caster et mapper vers SessionEntity via SessionModel.fromJson.
    _recentSessions = (data as List<dynamic>)
        .map((row) => SessionModel.fromJson(row as Map<String, dynamic>))
        .toList();

    return _recentSessions;
  }

  // =============================================================
  // METHODE : unlockCard
  // =============================================================

  /// Ajoute une carte au deck du joueur (apres bonne reponse).
  /// Idempotent : si la carte est deja debloquee, ne fait rien.
  Future<void> unlockCard(String cardId) async {
    if (ApiConfig.isFastApi) {
      // Sans jeu actif, le backend ne saurait pas a quel game lier.
      if (selectedGameId == null) return;
      try {
        // POST /api/me/unlocked-cards {card_id, game_id}
        // Idempotent serveur : absorbe le conflit PK composite si la
        // carte est deja unlocked (renvoie la ligne existante).
        await _httpUnlockedCards.unlockCard(
          cardId: cardId,
          gameId: selectedGameId!,
        );
      } catch (_) {
        // Idem comportement Supabase : on ignore toute erreur (conflit
        // ou reseau) pour ne pas casser le gameplay.
      }
      return;
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null || selectedGameId == null) return;

    try {
      await supabase.from('user_unlocked_cards').insert({
        'user_id': user.id,
        'card_id': cardId,
        'game_id': selectedGameId!,
      });
    } catch (_) {
      // Ignore le conflit (carte deja debloquee).
    }
  }

  // =============================================================
  // METHODE : loadUnlockedCards
  // =============================================================

  /// Charge la liste des IDs de cartes debloquees pour le jeu actif.
  Future<Set<String>> loadUnlockedCards() async {
    if (ApiConfig.isFastApi) {
      if (selectedGameId == null) return {};
      try {
        // GET /api/me/unlocked-cards?game_id=...
        // Renvoie une liste de UnlockedCardOut (card_id, game_id,
        // unlocked_at, label, image_url). On garde uniquement card_id
        // pour matcher le contrat retourne par la branche Supabase.
        final rows = await _httpUnlockedCards.listMyDeck(
          gameId: selectedGameId!,
        );
        return rows.map((r) => r['card_id'] as String).toSet();
      } catch (_) {
        return {};
      }
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null || selectedGameId == null) return {};

    final data = await supabase
        .from('user_unlocked_cards')
        .select('card_id')
        .eq('user_id', user.id)
        .eq('game_id', selectedGameId!);

    return (data as List<dynamic>)
        .map((row) => row['card_id'] as String)
        .toSet();
  }

  // =============================================================
  // METHODE : updateAvatar
  // =============================================================

  /// Change le username (pseudo) du joueur.
  Future<void> updateUsername(String username) async {
    final trimmed = username.trim();

    if (ApiConfig.isFastApi) {
      // PATCH /api/me/profile {username}. Le backend trim/valide deja,
      // on envoie tel quel apres trim cote client pour coherence UI.
      await _httpProfile.updateMyProfile(username: trimmed);
      if (_profile != null) {
        _profile = {..._profile!, 'username': trimmed};
      }
      return;
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('user_profiles').update({
      'username': trimmed,
    }).eq('id', user.id);

    // Synchroniser le cache local.
    if (_profile != null) {
      _profile = {..._profile!, 'username': trimmed};
    }
  }

  /// Change l'avatar du joueur.
  Future<void> updateAvatar(String avatarId) async {
    if (ApiConfig.isFastApi) {
      // PATCH /api/me/profile {avatar_id}. Idem qu'un update partiel.
      await _httpProfile.updateMyProfile(avatarId: avatarId);
      if (_profile != null) {
        _profile = {..._profile!, 'avatar_id': avatarId};
      }
      return;
    }

    // Mode Supabase historique.
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('user_profiles').update({
      'avatar_id': avatarId,
    }).eq('id', user.id);

    // Update le cache local.
    if (_profile != null) {
      _profile = {..._profile!, 'avatar_id': avatarId};
    }
  }

  // =============================================================
  // METHODE : loseLife
  // =============================================================
  // Decrement atomique du compteur de vies (-1), clamped a 0.
  // Appele pendant le gameplay des qu'une vie doit etre consommee
  // (ex: toutes les N mauvaises reponses selon la regle du niveau).
  //
  // POURQUOI ATOMIQUE EN DB MAINTENANT ?
  // ------------------------------------
  // Avant : les vies etaient deduites en UNE SEULE FOIS a la fin de
  // partie via updateStats(livesUsed). Probleme : pendant la partie
  // le compteur cote home page restait a 5 meme si le joueur avait
  // perdu 3 vies -> desync visuelle et logique. Pire : la partie
  // demarrait toujours avec un _lives hardcode, sans lire la DB.
  //
  // Maintenant : chaque perte est persistee immediatement, donc la
  // home page reflete la realite en temps reel (via listener provider)
  // et la prochaine partie demarre avec le bon compteur.
  // =============================================================

  /// Decremente de 1 la vie cote DB + cache, clamped a 0.
  /// Retourne le nouveau nombre de vies apres decrement.
  Future<int> loseLife() async {
    if (ApiConfig.isFastApi) {
      // SPECIFICITE FASTAPI :
      // En mode FastAPI, la decrementation des vies est centralisee
      // dans le backend lors de l'enregistrement d'une session non
      // passee (POST /api/me/sessions decrement lives si passed=false,
      // cf. module sessions_history/routes.py). On NE decremente DONC
      // PAS cote client : ce serait une double-soustraction.
      //
      // Cette methode reste appelable pour rester compatible avec le
      // code gameplay existant : elle se contente de relire l'etat
      // courant en BDD (GET /api/me/games/{id}) et de renvoyer le
      // compteur de vies a jour (en mettant aussi le cache a jour).
      if (selectedGameId == null) {
        return _currentGameStats?['lives'] as int? ?? 0;
      }
      try {
        final data = await _httpUserGames.getMyGame(selectedGameId!);
        _currentGameStats = data;
        return data['lives'] as int? ?? 0;
      } catch (_) {
        // Pas de relecture possible -> on retourne le cache local.
        return _currentGameStats?['lives'] as int? ?? 0;
      }
    }

    // Mode Supabase historique : decrement atomique cote client.
    final user = supabase.auth.currentUser;
    if (user == null || _currentGameStats == null) {
      return _currentGameStats?['lives'] as int? ?? 0;
    }

    final current = _currentGameStats!['lives'] as int;
    if (current <= 0) return 0;
    final next = current - 1;

    await supabase
        .from('user_games')
        .update({'lives': next})
        .eq('user_id', user.id)
        .eq('game_id', selectedGameId!);

    _currentGameStats = {
      ..._currentGameStats!,
      'lives': next,
    };

    return next;
  }

  // =============================================================
  // METHODE : buyLives
  // =============================================================

  /// Achete des vies avec les points du jeu actuel.
  Future<bool> buyLives({int count = 1, int costPerLife = 100}) async {
    if (_currentGameStats == null) return false;

    final currentLives = _currentGameStats!['lives'] as int;
    final maxLives = _currentGameStats!['max_lives'] as int;
    final currentScore = _currentGameStats!['total_score'] as int;

    if (currentLives >= maxLives) return false;

    final actual = count.clamp(0, maxLives - currentLives);
    final totalCost = actual * costPerLife;
    if (currentScore < totalCost) return false;

    if (ApiConfig.isFastApi) {
      // Pas d'equivalent cote backend : l'economie FastAPI ne prevoit
      // qu'un seul moyen de regagner une vie, l'echange d'etoiles
      // (POST /api/me/stars/exchange-for-life). Il n'existe aucun
      // endpoint pour convertir du score en vies.
      //
      // Le faire cote client est exclu : il faudrait ecrire
      // directement dans user_games, ce que le backend n'autorise pas,
      // et cela ouvrirait la porte a des vies gratuites en trafiquant
      // les requetes.
      //
      // On retourne donc false, ce que l'appelant interprete deja
      // comme "achat refuse" (solde insuffisant, vies au maximum). Le
      // bouton reste sans effet plutot que de mentir a l'utilisateur.
      //
      // Pour retablir la fonction : ajouter un endpoint dedie cote
      // serveur, puis brancher _httpUserGames dessus ici.
      return false;
    }

    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final newScore = currentScore - totalCost;
    final newLives = currentLives + actual;

    await supabase
        .from('user_games')
        .update({
          'total_score': newScore,
          'lives': newLives,
        })
        .eq('user_id', user.id)
        .eq('game_id', selectedGameId!);

    _currentGameStats = {
      ..._currentGameStats!,
      'total_score': newScore,
      'lives': newLives,
    };

    return true;
  }

  // =============================================================
  // ECONOMIE ETOILES
  // =============================================================
  // Les etoiles sont une monnaie cumulative sur user_profiles.
  //   - regen : +1 toutes les 5 min jusqu'au plafond stars_max
  //   - depense : echange 10 etoiles -> 1 vie (RPC atomique)
  //
  // La regen est calculee cote client a chaque reload du profil :
  // on lit stars_last_regen, on calcule combien de cycles de 5 min
  // se sont ecoules, on avance le compteur et le timestamp.
  // Pas de cron serveur -> simple et fiable.
  // =============================================================

  /// Applique la regen des etoiles (1 toutes les 5 min) si du temps
  /// s'est ecoule depuis le dernier regen. Idempotent : ne fait rien
  /// si aucun cycle complet n'est passe, ou si deja au plafond.
  ///
  /// Retourne le nouveau nombre d'etoiles apres regen.
  Future<int> applyStarsRegen() async {
    if (ApiConfig.isFastApi) {
      // La regeneration est calculee par le serveur : GET /api/me/stars
      // applique le rattrapage (1 etoile toutes les 5 minutes) puis
      // renvoie le portefeuille a jour.
      //
      // C'est un vrai gain de robustesse par rapport au calcul local
      // ci-dessous, qui s'appuyait sur DateTime.now() du telephone :
      // avancer l'horloge de l'appareil suffisait a fabriquer des
      // etoiles. Le serveur, lui, fait foi.
      try {
        final wallet = await _httpStars.getMyWallet();
        _profile = {...?_profile, ...wallet};
        return wallet['stars'] as int? ?? (_profile?['stars'] as int? ?? 0);
      } catch (_) {
        // Reseau indisponible : on renvoie la derniere valeur connue
        // plutot que zero, qui afficherait un portefeuille vide a tort.
        return _profile?['stars'] as int? ?? 0;
      }
    }

    final user = supabase.auth.currentUser;
    if (user == null || _profile == null) {
      return _profile?['stars'] as int? ?? 0;
    }

    final stars = _profile!['stars'] as int? ?? 0;
    final starsMax = _profile!['stars_max'] as int? ?? 50;
    if (stars >= starsMax) return stars;

    final lastRegenRaw = _profile!['stars_last_regen'] as String?;
    if (lastRegenRaw == null) return stars;
    final lastRegen = DateTime.tryParse(lastRegenRaw);
    if (lastRegen == null) return stars;

    // Combien de cycles de 5 min se sont ecoules depuis le dernier regen ?
    final now = DateTime.now().toUtc();
    final elapsedMin = now.difference(lastRegen).inMinutes;
    final cycles = elapsedMin ~/ 5;
    if (cycles <= 0) return stars;

    // On ne peut pas depasser le plafond : on borne le gain a la marge
    // encore disponible. Le timestamp avance seulement du nombre de
    // cycles reellement credites pour eviter de "perdre" les minutes
    // deja ecoulees non gainables (ne change rien si on est plafonne).
    final availableSlots = starsMax - stars;
    final credited = cycles.clamp(0, availableSlots);
    if (credited == 0) return stars;

    final newStars = stars + credited;
    final newTimestamp = lastRegen.add(Duration(minutes: credited * 5));

    await supabase
        .from('user_profiles')
        .update({
          'stars': newStars,
          'stars_last_regen': newTimestamp.toIso8601String(),
        })
        .eq('id', user.id);

    _profile = {
      ..._profile!,
      'stars': newStars,
      'stars_last_regen': newTimestamp.toIso8601String(),
    };

    return newStars;
  }

  /// Echange [cost] etoiles contre 1 vie via la RPC atomique.
  /// Retourne null si pas autorise ou pas d'user connecte, sinon
  /// un Map avec les nouvelles valeurs { stars, lives } ou
  /// { success: false, reason } si le serveur refuse.
  Future<Map<String, dynamic>?> exchangeStarsForLife({int cost = 10}) async {
    if (ApiConfig.isFastApi) {
      // POST /api/me/stars/exchange-for-life : le debit des etoiles et
      // le credit de la vie se font dans une seule transaction cote
      // serveur, donc sans etat intermediaire ou l'un serait applique
      // sans l'autre.
      //
      // Le cout est fixe par le backend (10 etoiles). Le parametre
      // [cost] n'est donc pas transmis : le laisser decider au client
      // reviendrait a lui laisser fixer son propre prix. Il reste dans
      // la signature pour le mode supabase et les appelants existants.
      try {
        final resultat = await _httpStars.exchangeForLife(
          gameId: selectedGameId,
        );
        // Le portefeuille renvoye fait autorite : on rafraichit le
        // cache pour que l'UI affiche immediatement le bon solde.
        _profile = {...?_profile, ...resultat};
        // Les vies vivent sur user_games, pas sur le profil : il faut
        // une seconde lecture pour que le compteur de vies suive.
        await loadCurrentGameStats();
        return resultat;
      } catch (_) {
        return null;
      }
    }

    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await supabase.rpc('exchange_stars_for_life', params: {
        'p_user_id': user.id,
        'p_cost': cost,
      });

      final result = response as Map<String, dynamic>;
      final success = result['success'] as bool? ?? false;
      if (success) {
        // Synchroniser les caches locaux pour refleter immediatement.
        _profile = {
          ...?_profile,
          'stars': result['stars'] as int,
        };
        if (_currentGameStats != null) {
          _currentGameStats = {
            ..._currentGameStats!,
            'lives': result['lives'] as int,
          };
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  // =============================================================
  // METHODE : signOut
  // =============================================================

  /// Deconnecte et nettoie le cache.
  Future<void> signOut() async {
    if (ApiConfig.isFastApi) {
      // Cote FastAPI il n'y a pas de session serveur a invalider :
      // l'authentification repose sur des JWT sans etat. Se
      // deconnecter consiste donc a effacer les jetons du stockage
      // securise -- c'est ce que fait HttpAuthDatasource.logout().
      await HttpAuthDatasource().logout();
    } else {
      await supabase.auth.signOut();
    }

    // Dans les deux cas, l'identite en cache doit partir : sans cela,
    // AdminConstants.isAdmin() continuerait de repondre vrai et la cle
    // d'onboarding resterait scopee a l'utilisateur precedent.
    SessionUtilisateur.effacer();
    _profile = null;
    _currentGameStats = null;
    _userGames = [];
    // Sessions : on vide le cache pour ne pas exposer l'historique
    // du precedent user si un nouveau user se connecte ensuite.
    _recentSessions = [];
    _cachedDeviceId = null;
  }
}
