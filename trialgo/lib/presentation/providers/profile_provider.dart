// =============================================================
// FICHIER : lib/presentation/providers/profile_provider.dart
// ROLE   : Providers Riverpod pour le profil utilisateur
// COUCHE : Presentation > Providers
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/data/services/profile_service.dart';
import 'package:trialgo/domain/entities/game_entity.dart';
import 'package:trialgo/domain/entities/session_entity.dart';

/// Singleton du ProfileService.
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// =============================================================
// ETAT : AppProfileState
// =============================================================
// Contient les donnees du profil presentees a l'UI :
//   - general        : user_profiles (avatar, username)
//   - gameStats      : user_games (level, score, vies pour le jeu actif)
//   - games          : liste des jeux actives par l'utilisateur
//   - unlockedCards  : cartes debloquees pour le jeu actif
//   - recentSessions : historique des dernieres parties (plus recent en tete)
//
// L'etat est IMMUABLE : chaque modification passe par copyWith et
// cree une nouvelle instance. Riverpod detecte alors le changement
// et rebuild les widgets qui ecoutent.
// =============================================================

class AppProfileState {
  /// Profil general (user_profiles).
  final Map<String, dynamic>? general;

  /// Stats du jeu selectionne (user_games).
  final Map<String, dynamic>? gameStats;

  /// Liste des jeux actives de l'utilisateur.
  final List<GameEntity> games;

  /// Cartes debloquees (deck).
  final Set<String> unlockedCards;

  /// Historique des N dernieres sessions pour le jeu actif.
  /// Trie plus recent en premier. Mis a jour apres chaque partie.
  final List<SessionEntity> recentSessions;

  const AppProfileState({
    this.general,
    this.gameStats,
    this.games = const [],
    this.unlockedCards = const {},
    this.recentSessions = const [],
  });

  AppProfileState copyWith({
    Map<String, dynamic>? general,
    Map<String, dynamic>? gameStats,
    List<GameEntity>? games,
    Set<String>? unlockedCards,
    List<SessionEntity>? recentSessions,
  }) {
    return AppProfileState(
      general: general ?? this.general,
      gameStats: gameStats ?? this.gameStats,
      games: games ?? this.games,
      unlockedCards: unlockedCards ?? this.unlockedCards,
      recentSessions: recentSessions ?? this.recentSessions,
    );
  }

  // ---------------------------------------------------------------
  // RACCOURCIS UI : getters pour eviter de faire le null-check dans
  // chaque widget. Valeurs par defaut sensees pour les cas initiaux.
  // ---------------------------------------------------------------

  String get username => (general?['username'] as String?) ?? 'Joueur';
  String get avatarId => (general?['avatar_id'] as String?) ?? 'avatar_1';
  int get level => (gameStats?['current_level'] as int?) ?? 1;
  int get score => (gameStats?['total_score'] as int?) ?? 0;
  int get lives => (gameStats?['lives'] as int?) ?? 5;
  int get maxLives => (gameStats?['max_lives'] as int?) ?? 5;
  String? get selectedGameId => general?['selected_game_id'] as String?;

  /// Derniere session jouee, ou null si aucun historique.
  /// Raccourci pratique pour la home ("derniere session : 6/8").
  SessionEntity? get lastSession =>
      recentSessions.isEmpty ? null : recentSessions.first;
}


/// Notifier reactif qui charge et met a jour le profil.
class ProfileNotifier extends StateNotifier<AppProfileState> {
  final ProfileService _service;

  ProfileNotifier(this._service) : super(const AppProfileState());

  /// Recharge tout le profil depuis Supabase.
  ///
  /// Utilise au demarrage et apres un changement de jeu.
  /// Recupere aussi l'historique recent pour la home.
  Future<void> reload() async {
    // Chargement sequentiel car certains appels dependent de l'etat
    // precedent (loadCurrentGameStats a besoin que selectedGameId
    // soit connu via loadProfile). Le cout reste minime (< 200ms).
    final general = await _service.loadProfile();
    final games = await _service.loadUserGames();
    final gameStats = await _service.loadCurrentGameStats();
    final unlockedCards = await _service.loadUnlockedCards();
    final recentSessions = await _service.loadRecentSessions();

    state = state.copyWith(
      general: general,
      gameStats: gameStats,
      games: games,
      unlockedCards: unlockedCards,
      recentSessions: recentSessions,
    );
  }

  /// Change le jeu actif.
  Future<void> selectGame(String gameId) async {
    await _service.selectGame(gameId);
    await reload();
  }

  /// Met a jour l'avatar.
  Future<void> updateAvatar(String avatarId) async {
    await _service.updateAvatar(avatarId);
    state = state.copyWith(
      general: {...?state.general, 'avatar_id': avatarId},
    );
  }

  // ---------------------------------------------------------------
  // METHODE : recordGameSession
  // ---------------------------------------------------------------
  // UNIQUE point d'entree pour persister la fin d'une partie.
  //
  // Effectue DEUX operations Supabase successives :
  //   1. INSERT dans user_sessions (historique detaille)
  //   2. UPDATE dans user_games (cumul score/level/vies)
  //
  // L'ordre est important : on enregistre d'abord la session detaillee
  // pour preserver l'historique meme si l'update cumulatif echoue.
  //
  // A la fin, on met a jour l'etat Riverpod avec les nouveaux
  // gameStats ET la session ajoutee en tete de recentSessions.
  // Les widgets qui ecoutent profileProvider (home, profil) se
  // rafraichissent automatiquement.
  //
  // Appele depuis t_game_page.dart a la fin du dernier tour.
  // ---------------------------------------------------------------

  /// Enregistre une partie jouee (INSERT session + UPDATE stats cumulees).
  ///
  /// Les [correctAnswers], [wrongAnswers] et [questionsTotal] servent a
  /// calculer automatiquement le nombre d'etoiles via SessionEntity.
  /// [livesUsed] est le nombre de vies consommees pendant la partie
  /// (derive de wrongAnswers via la regle du niveau).
  Future<void> recordGameSession({
    required int level,
    required int scoreGained,
    required int correctAnswers,
    required int wrongAnswers,
    required int questionsTotal,
    required int maxStreak,
    required int durationSeconds,
    required bool passed,
    required int livesUsed,
    bool levelUp = false,
  }) async {
    // Calcul des etoiles via le helper centralise (SessionEntity).
    // Regroupe la regle en un seul endroit : pas de divergence
    // possible entre l'etoile stockee en BDD et celle affichee UI.
    final stars = SessionEntity.computeStars(
      passed: passed,
      correctAnswers: correctAnswers,
      questionsTotal: questionsTotal,
    );

    // Etape 1 : INSERT dans user_sessions.
    // Si l'insert echoue (reseau / RLS), on garde la session null
    // mais on continue pour au moins mettre a jour le cumul.
    final session = await _service.insertSession(
      level: level,
      scoreGained: scoreGained,
      correctAnswers: correctAnswers,
      wrongAnswers: wrongAnswers,
      questionsTotal: questionsTotal,
      maxStreak: maxStreak,
      durationSeconds: durationSeconds,
      passed: passed,
      starsEarned: stars,
    );

    // Etape 2 : UPDATE dans user_games (total cumule du jeu).
    await _service.updateStats(
      scoreGained: scoreGained,
      livesUsed: livesUsed,
      levelUp: levelUp,
    );

    // Mettre a jour l'etat :
    //   - gameStats : le nouveau cumul (depuis le cache du service)
    //   - recentSessions : la nouvelle session prefixee (si insert ok)
    final updatedSessions = session != null
        ? [session, ...state.recentSessions]
        : state.recentSessions;

    state = state.copyWith(
      gameStats: _service.currentGameStats,
      recentSessions: updatedSessions,
    );
  }

  /// Debloque une carte dans le deck.
  Future<void> unlockCard(String cardId) async {
    await _service.unlockCard(cardId);
    state = state.copyWith(
      unlockedCards: {...state.unlockedCards, cardId},
    );
  }

  /// Achete des vies.
  Future<bool> buyLives({int count = 1, int costPerLife = 100}) async {
    final ok = await _service.buyLives(count: count, costPerLife: costPerLife);
    if (ok) {
      state = state.copyWith(gameStats: _service.currentGameStats);
    }
    return ok;
  }

  /// Deconnexion.
  Future<void> signOut() async {
    await _service.signOut();
    state = const AppProfileState();
  }
}


/// Provider reactif de l'etat profil.
final profileProvider =
    StateNotifierProvider<ProfileNotifier, AppProfileState>((ref) {
  return ProfileNotifier(ref.read(profileServiceProvider));
});
