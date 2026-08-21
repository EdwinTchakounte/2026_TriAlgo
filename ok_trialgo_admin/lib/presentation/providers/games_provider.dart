// =============================================================
// FICHIER : games_provider.dart
// ROLE    : Liste des games + game selectionne pour le wizard
// =============================================================
//
// Deux providers ici :
//
//   gamesProvider : AsyncNotifier<List<Game>>
//     -> fetch initial + methode refresh + methodes create/update
//
//   selectedGameProvider : StateProvider<Game?>
//     -> game courant choisi par l'admin pour entrer dans le
//        wizard. null tant qu'on n'a pas selectionne / cree.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/entities/game.dart';
import 'repositories_provider.dart';

class GamesNotifier extends AsyncNotifier<List<Game>> {
  @override
  Future<List<Game>> build() async {
    return _fetch();
  }

  // Helper prive : appelle le repo, throw en cas d'erreur pour
  // que AsyncNotifier passe en error state automatiquement.
  Future<List<Game>> _fetch() async {
    final repo = ref.read(gameRepositoryProvider);
    final res = await repo.listAll();
    return switch (res) {
      Ok(value: final list) => list,
      Err(failure: final f) => throw Exception(f.message),
    };
  }

  // Forcer un re-fetch (utilise apres create/update).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  // Cree un game et refresh la liste. Renvoie le Game cree en cas
  // de succes (utile pour auto-selectionner apres creation).
  Future<Game?> createGame({
    required String name,
    String? description,
    String? theme,
  }) async {
    final repo = ref.read(gameRepositoryProvider);
    final res = await repo.create(
      name: name,
      description: description,
      theme: theme,
    );
    switch (res) {
      case Ok(value: final game):
        await refresh();
        return game;
      case Err():
        return null;
    }
  }
}

final gamesProvider =
    AsyncNotifierProvider<GamesNotifier, List<Game>>(GamesNotifier.new);

// -----------------------------------------------------------
// selectedGameProvider : le game choisi pour le wizard.
// Quand l'admin clique sur "Continuer" depuis la liste de jeux,
// ou apres avoir cree un nouveau game, on set ce provider.
// La navigation vers le wizard lit cette valeur.
// -----------------------------------------------------------
final selectedGameProvider = StateProvider<Game?>((ref) => null);
