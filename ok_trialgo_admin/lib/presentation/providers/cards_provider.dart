// =============================================================
// FICHIER : cards_provider.dart
// ROLE    : Cartes du game selectionne
// =============================================================
//
// On utilise ref.watch(selectedGameProvider) pour relancer la
// fetch quand l'admin change de jeu courant. Si selectedGame
// est null, on renvoie une liste vide (etat normal avant
// selection).
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/entities/game_card.dart';
import 'games_provider.dart';
import 'repositories_provider.dart';

class CardsNotifier extends AsyncNotifier<List<GameCard>> {
  @override
  Future<List<GameCard>> build() async {
    return _fetch();
  }

  Future<List<GameCard>> _fetch() async {
    final game = ref.watch(selectedGameProvider);
    if (game == null) return [];

    final repo = ref.read(cardRepositoryProvider);
    final res = await repo.listByGame(game.id);
    return switch (res) {
      Ok(value: final list) => list,
      Err(failure: final f) => throw Exception(f.message),
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final cardsProvider =
    AsyncNotifierProvider<CardsNotifier, List<GameCard>>(CardsNotifier.new);
