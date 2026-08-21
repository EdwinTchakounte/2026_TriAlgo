// =============================================================
// FICHIER : nodes_provider.dart
// ROLE    : Liste reactive des nodes du jeu courant
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/node.dart';
import 'games_provider.dart';
import 'repositories_provider.dart';

class NodesNotifier extends AsyncNotifier<List<GameNode>> {
  @override
  Future<List<GameNode>> build() async {
    final game = ref.watch(selectedGameProvider);
    if (game == null) return [];
    final repo = ref.watch(nodeRepositoryProvider);
    return repo.listAll(game.id);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final game = ref.read(selectedGameProvider);
      if (game == null) return <GameNode>[];
      final repo = ref.read(nodeRepositoryProvider);
      return repo.listAll(game.id);
    });
  }
}

final nodesProvider = AsyncNotifierProvider<NodesNotifier, List<GameNode>>(
  NodesNotifier.new,
);
