// =============================================================
// FICHIER : games_provider.dart
// ROLE    : Liste des jeux + jeu courant selectionne
// =============================================================
//
// Le dashboard travaille sur UN jeu a la fois (Savane par
// defaut). Toutes les pages (Cards, Trios, Graph) lisent
// `selectedGameProvider` pour savoir sur quel jeu travailler.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/game.dart';
import 'repositories_provider.dart';

// Liste de tous les jeux actifs. FutureProvider parce qu'on
// charge depuis Supabase au premier acces et on cache.
final gamesListProvider = FutureProvider<List<Game>>((ref) async {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.listActive();
});

// Jeu actuellement selectionne dans le dashboard. On le stocke
// en StateProvider (mutable, simple). Initialise a null : la
// HomePage choisira automatiquement le premier jeu disponible.
final selectedGameProvider = StateProvider<Game?>((ref) => null);
