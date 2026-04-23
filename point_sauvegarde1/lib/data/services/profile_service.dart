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

import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/domain/entities/game_entity.dart';
import 'package:trialgo/data/models/game_model.dart';

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

  // =============================================================
  // GETTERS
  // =============================================================

  Map<String, dynamic>? get profile => _profile;
  Map<String, dynamic>? get currentGameStats => _currentGameStats;
  List<GameEntity> get userGames => _userGames;

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

  /// Active un code et lie le device via la fonction SQL.
  Future<ActivationResult> activateCode(String code) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const ActivationResult(
        success: false,
        message: 'Aucun utilisateur connecte',
      );
    }

    // S'assurer que le profil existe (necessaire pour user_games FK).
    await createProfile(username: user.email?.split('@').first);

    final deviceId = await getDeviceId();

    try {
      // Appel de la fonction SQL activate_code().
      final response = await supabase.rpc('activate_code', params: {
        'p_code': code,
        'p_user_id': user.id,
        'p_device_id': deviceId,
      });

      // La fonction retourne un JSONB qui arrive comme Map cote Dart.
      final result = response as Map<String, dynamic>;
      final success = result['success'] as bool? ?? false;
      final message = result['message'] as String? ?? 'Erreur inconnue';
      final isBlocked = result['blocked'] as bool? ?? false;
      final changesLeft = result['changes_left'] as int?;
      final gameId = result['game_id'] as String?;

      if (success && gameId != null) {
        // Marquer ce jeu comme selectionne.
        await supabase.from('user_profiles').update({
          'selected_game_id': gameId,
        }).eq('id', user.id);

        // Recharger le profil et la liste des jeux.
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
  // METHODE : unlockCard
  // =============================================================

  /// Ajoute une carte au deck du joueur (apres bonne reponse).
  /// Idempotent : si la carte est deja debloquee, ne fait rien.
  Future<void> unlockCard(String cardId) async {
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

  /// Change l'avatar du joueur.
  Future<void> updateAvatar(String avatarId) async {
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
  // METHODE : signOut
  // =============================================================

  /// Deconnecte et nettoie le cache.
  Future<void> signOut() async {
    await supabase.auth.signOut();
    _profile = null;
    _currentGameStats = null;
    _userGames = [];
    _cachedDeviceId = null;
  }
}
