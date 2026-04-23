// =============================================================
// FICHIER : lib/presentation/providers/profile_provider.dart
// ROLE   : Providers Riverpod pour le profil utilisateur
// COUCHE : Presentation > Providers
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/core/constants/game_constants.dart';
import 'package:trialgo/data/services/profile_service.dart';
import 'package:trialgo/data/services/streak_service.dart';
import 'package:trialgo/domain/entities/game_entity.dart';
import 'package:trialgo/domain/entities/session_entity.dart';

/// Singleton du ProfileService.
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

/// Singleton du StreakService (streak local en SharedPreferences).
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService();
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

  /// Streak (nombre de jours consecutifs avec au moins une partie).
  /// 0 si jamais joue ou si la serie a ete cassee.
  final int streak;

  const AppProfileState({
    this.general,
    this.gameStats,
    this.games = const [],
    this.unlockedCards = const {},
    this.recentSessions = const [],
    this.streak = 0,
  });

  AppProfileState copyWith({
    Map<String, dynamic>? general,
    Map<String, dynamic>? gameStats,
    List<GameEntity>? games,
    Set<String>? unlockedCards,
    List<SessionEntity>? recentSessions,
    int? streak,
  }) {
    return AppProfileState(
      general: general ?? this.general,
      gameStats: gameStats ?? this.gameStats,
      games: games ?? this.games,
      unlockedCards: unlockedCards ?? this.unlockedCards,
      recentSessions: recentSessions ?? this.recentSessions,
      streak: streak ?? this.streak,
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

  // ---------------------------------------------------------------
  // WALLET ETOILES (transverse a tous les jeux du joueur)
  // ---------------------------------------------------------------
  // Les etoiles sont stockees sur user_profiles (pas user_games) :
  // un joueur qui en gagne sur la savane peut les depenser sur ocean.
  // Source : migration 003_stars_economy.sql.
  // ---------------------------------------------------------------

  int get stars => (general?['stars'] as int?) ?? 0;
  int get starsMax => (general?['stars_max'] as int?) ?? 50;

  /// Horodatage (UTC) du dernier moment ou la regen d'etoiles a ete
  /// appliquee (cote client ou server). Null avant la premiere regen.
  DateTime? get starsLastRegen {
    final raw = general?['stars_last_regen'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Horodatage prevu de la prochaine etoile (ajout de +5 min au
  /// dernier regen). Retourne null si deja au plafond.
  DateTime? get nextStarAt {
    if (stars >= starsMax) return null;
    final last = starsLastRegen;
    if (last == null) return null;
    return last.add(const Duration(minutes: 5));
  }

  /// Derniere session jouee, ou null si aucun historique.
  /// Raccourci pratique pour la home ("derniere session : 6/8").
  SessionEntity? get lastSession =>
      recentSessions.isEmpty ? null : recentSessions.first;

  // ---------------------------------------------------------------
  // RECHARGE DES VIES
  // ---------------------------------------------------------------
  // pg_cron (cote Supabase) ajoute 1 vie au joueur toutes les
  // liveRefillMinutes (30 min par defaut) tant que lives < max.
  // La colonne lives_last_refill est mise a jour a chaque passage.
  //
  // Pour afficher un compte a rebours "Prochaine vie dans mm:ss",
  // on lit ce timestamp et on ajoute la duree configuree.
  //
  // Ces getters encapsulent la logique pour que les widgets n'aient
  // pas a manipuler directement gameStats['lives_last_refill'].
  // ---------------------------------------------------------------

  /// Horodatage (UTC) du dernier passage du cron de recharge.
  /// Null si pas de jeu actif ou si la colonne n'est pas encore remplie.
  DateTime? get livesLastRefill {
    final raw = gameStats?['lives_last_refill'] as String?;
    if (raw == null) return null;
    // Supabase retourne un ISO 8601. DateTime.parse le gere nativement.
    return DateTime.tryParse(raw);
  }

  /// Horodatage estime du prochain ajout de vie, ou null si :
  ///   - pas de donnees de recharge (timestamp manquant)
  ///   - vies deja au max (pas d'ajout a venir)
  DateTime? get nextRefillAt {
    if (lives >= maxLives) return null;
    final last = livesLastRefill;
    if (last == null) return null;
    return last.add(const Duration(minutes: GameConstants.liveRefillMinutes));
  }

  // ---------------------------------------------------------------
  // PROGRESSION DANS LA DISTANCE COURANTE
  // ---------------------------------------------------------------
  // La config de niveau (GameConstants.getLevelConfigForTables) nous
  // donne (distance, tableIndex) pour le niveau courant. On en deduit :
  //   - distance courante (1..5)
  //   - tableIndex courant (0..nbTables-1)
  //   - progression dans la distance en fraction (0..1)
  //
  // Quand progression atteint 1, on est au dernier niveau de la distance ;
  // le prochain niveau bascule sur la distance suivante.
  //
  // Pour calculer, on a besoin de tablesPerDistance. Non accessible
  // depuis AppProfileState (pas d'acces au LogicalNodesPool ici).
  // Donc ce getter NECESSITE un parametre.
  // ---------------------------------------------------------------

  /// Retourne un objet decrivant la progression dans la distance courante.
  ///
  /// [tablesPerDistance] : liste [nb_D1, nb_D2, nb_D3, nb_D4, nb_D5]
  /// obtenue depuis le LogicalNodesPool (graphSyncService.logicalNodes).
  LevelProgress progressFor(List<int> tablesPerDistance) {
    final config = GameConstants.getLevelConfigForTables(level, tablesPerDistance);
    final total = tablesPerDistance[config.distance - 1];
    final current = config.tableIndex + 1; // convert 0-index -> 1-index

    return LevelProgress(
      distance: config.distance,
      currentInDistance: current,
      totalInDistance: total,
      questions: config.questions,
      turnTimeSeconds: config.turnTimeSeconds,
      threshold: config.threshold,
    );
  }
}


// =============================================================
// CLASSE : LevelProgress
// =============================================================
// Fiche de progression du niveau courant, deduit du level + des
// tables disponibles. Consomme par le widget HERO de la home.
// =============================================================

/// Decrit la progression dans la distance courante.
class LevelProgress {
  /// Distance du niveau courant (1, 2 ou 3).
  final int distance;

  /// Niveau dans la distance (1-based). Ex: 3 dans une distance
  /// qui a 5 tables signifie "3eme partie de D2".
  final int currentInDistance;

  /// Nombre total de niveaux dans cette distance.
  final int totalInDistance;

  /// Nombre de questions par partie dans ce niveau.
  final int questions;

  /// Temps par tour en secondes.
  final int turnTimeSeconds;

  /// Seuil de bonnes reponses pour valider le niveau.
  final int threshold;

  const LevelProgress({
    required this.distance,
    required this.currentInDistance,
    required this.totalInDistance,
    required this.questions,
    required this.turnTimeSeconds,
    required this.threshold,
  });

  /// Fraction 0..1 de la progression. Utile pour une progress bar.
  double get fraction {
    if (totalInDistance <= 0) return 0;
    return (currentInDistance / totalInDistance).clamp(0.0, 1.0);
  }

  /// Nombre de parties restantes avant de passer a la distance suivante.
  int get remainingInDistance =>
      (totalInDistance - currentInDistance).clamp(0, totalInDistance);
}


/// Notifier reactif qui charge et met a jour le profil.
class ProfileNotifier extends StateNotifier<AppProfileState> {
  final ProfileService _service;
  final StreakService _streakService;

  ProfileNotifier(this._service, this._streakService)
      : super(const AppProfileState());

  /// Recharge tout le profil depuis Supabase + streak local.
  Future<void> reload() async {
    // Chargement sequentiel car certains appels dependent de l'etat
    // precedent (loadCurrentGameStats a besoin que selectedGameId
    // soit connu via loadProfile). Le cout reste minime (< 200ms).
    await _service.loadProfile();
    // Appliquer la regen d'etoiles AVANT de capturer le profil final.
    // Ainsi la home affiche immediatement les etoiles fraichement
    // creditees apres une absence prolongee. Idempotent : no-op si
    // pas de cycle de 5 min complet depuis le dernier regen.
    await _service.applyStarsRegen();

    final games = await _service.loadUserGames();
    final gameStats = await _service.loadCurrentGameStats();
    final unlockedCards = await _service.loadUnlockedCards();
    final recentSessions = await _service.loadRecentSessions();
    // Streak : lecture locale (SharedPreferences), tres rapide.
    final streak = await _streakService.getStreak();

    state = state.copyWith(
      general: _service.profile,
      gameStats: gameStats,
      games: games,
      unlockedCards: unlockedCards,
      recentSessions: recentSessions,
      streak: streak,
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

  /// Met a jour le username du joueur.
  Future<void> updateUsername(String username) async {
    await _service.updateUsername(username);
    state = state.copyWith(
      general: {...?state.general, 'username': username.trim()},
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

    // Etape 3 : enregistrer la journee de jeu pour le streak.
    // Local (SharedPreferences), n'affecte pas la BDD Supabase.
    // Le service gere lui-meme la regle "meme jour = no-op".
    final newStreak = await _streakService.recordPlay();

    // Mettre a jour l'etat :
    //   - gameStats : le nouveau cumul (depuis le cache du service)
    //   - recentSessions : la nouvelle session prefixee (si insert ok)
    //   - streak : la nouvelle valeur retournee par le service
    final updatedSessions = session != null
        ? [session, ...state.recentSessions]
        : state.recentSessions;

    state = state.copyWith(
      gameStats: _service.currentGameStats,
      recentSessions: updatedSessions,
      streak: newStreak,
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

  // ---------------------------------------------------------------
  // METHODE : loseLife
  // ---------------------------------------------------------------
  // Decremente -1 vie de maniere synchrone BDD + etat Riverpod.
  // La home page (qui ecoute profileProvider) se met a jour
  // automatiquement. Appele depuis la page de jeu a chaque perte.
  // ---------------------------------------------------------------

  /// Decremente de 1 la vie et retourne le nouveau total.
  Future<int> loseLife() async {
    final next = await _service.loseLife();
    state = state.copyWith(gameStats: _service.currentGameStats);
    return next;
  }

  // ---------------------------------------------------------------
  // ECONOMIE ETOILES
  // ---------------------------------------------------------------

  /// Applique la regen cote DB puis synchronise l'etat Riverpod.
  /// Utile apres une ouverture d'app ou un retour en foreground.
  Future<void> refreshStars() async {
    await _service.applyStarsRegen();
    state = state.copyWith(general: _service.profile);
  }

  /// Echange [cost] etoiles contre 1 vie (RPC atomique).
  /// Retourne le Map reponse du serveur (success + stars/lives a jour
  /// ou reason d'echec : 'not_enough_stars', 'lives_already_max', etc.).
  Future<Map<String, dynamic>?> exchangeStarsForLife({int cost = 10}) async {
    final result = await _service.exchangeStarsForLife(cost: cost);
    if (result != null && (result['success'] as bool? ?? false)) {
      state = state.copyWith(
        general: _service.profile,
        gameStats: _service.currentGameStats,
      );
    }
    return result;
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
  return ProfileNotifier(
    ref.read(profileServiceProvider),
    ref.read(streakServiceProvider),
  );
});
