// =============================================================
// FICHIER : cards_provider.dart
// ROLE    : Liste reactive des cartes du jeu courant
// =============================================================
//
// Quand on uploade une carte, on appelle `refresh()` sur ce
// provider pour re-fetch et propager aux widgets qui affichent
// la liste.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/card.dart';
import 'games_provider.dart';
import 'repositories_provider.dart';

// AsyncNotifier : permet de combiner etat asynchrone (loading /
// data / error) avec des methodes mutatrices (createCard,
// deleteCard) qui re-fetchent automatiquement.
class CardsNotifier extends AsyncNotifier<List<GameCard>> {
  @override
  Future<List<GameCard>> build() async {
    final game = ref.watch(selectedGameProvider);
    if (game == null) return [];

    final repo = ref.watch(cardRepositoryProvider);
    return repo.listAll(gameId: game.id);
  }

  // refresh() force le re-fetch en remettant l'etat a loading
  // puis en re-executant build().
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final game = ref.read(selectedGameProvider);
      if (game == null) return <GameCard>[];
      final repo = ref.read(cardRepositoryProvider);
      return repo.listAll(gameId: game.id);
    });
  }
}

final cardsProvider = AsyncNotifierProvider<CardsNotifier, List<GameCard>>(
  CardsNotifier.new,
);
