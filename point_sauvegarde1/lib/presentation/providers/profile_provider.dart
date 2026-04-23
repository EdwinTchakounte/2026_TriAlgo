// =============================================================
// FICHIER : lib/presentation/providers/profile_provider.dart
// ROLE   : Providers Riverpod pour le profil utilisateur
// COUCHE : Presentation > Providers
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/data/services/profile_service.dart';
import 'package:trialgo/domain/entities/game_entity.dart';

/// Singleton du ProfileService.
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// =============================================================
// ETAT : AppProfileState
// =============================================================
// Contient les 2 niveaux de donnees :
//   - general  : user_profiles (avatar, username)
//   - gameStats: user_games (level, score, vies pour le jeu actif)
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

  const AppProfileState({
    this.general,
    this.gameStats,
    this.games = const [],
    this.unlockedCards = const {},
  });

  AppProfileState copyWith({
    Map<String, dynamic>? general,
    Map<String, dynamic>? gameStats,
    List<GameEntity>? games,
    Set<String>? unlockedCards,
  }) {
    return AppProfileState(
      general: general ?? this.general,
      gameStats: gameStats ?? this.gameStats,
      games: games ?? this.games,
      unlockedCards: unlockedCards ?? this.unlockedCards,
    );
  }

  // Raccourcis UI
  String get username => (general?['username'] as String?) ?? 'Joueur';
  String get avatarId => (general?['avatar_id'] as String?) ?? 'avatar_1';
  int get level => (gameStats?['current_level'] as int?) ?? 1;
  int get score => (gameStats?['total_score'] as int?) ?? 0;
  int get lives => (gameStats?['lives'] as int?) ?? 5;
  int get maxLives => (gameStats?['max_lives'] as int?) ?? 5;
  String? get selectedGameId => general?['selected_game_id'] as String?;
}


/// Notifier reactif qui charge et met a jour le profil.
class ProfileNotifier extends StateNotifier<AppProfileState> {
  final ProfileService _service;

  ProfileNotifier(this._service) : super(const AppProfileState());

  /// Recharge tout le profil depuis Supabase.
  Future<void> reload() async {
    final general = await _service.loadProfile();
    final games = await _service.loadUserGames();
    final gameStats = await _service.loadCurrentGameStats();
    final unlockedCards = await _service.loadUnlockedCards();

    state = state.copyWith(
      general: general,
      gameStats: gameStats,
      games: games,
      unlockedCards: unlockedCards,
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

  /// Met a jour les stats apres une partie.
  Future<void> updateAfterGame({
    required int scoreGained,
    required int livesUsed,
    bool levelUp = false,
  }) async {
    await _service.updateStats(
      scoreGained: scoreGained,
      livesUsed: livesUsed,
      levelUp: levelUp,
    );
    state = state.copyWith(gameStats: _service.currentGameStats);
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
