// =============================================================
// FICHIER : nodes_provider.dart
// ROLE    : Noeuds (trios) du game selectionne
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/entities/game_node.dart';
import 'games_provider.dart';
import 'repositories_provider.dart';

class NodesNotifier extends AsyncNotifier<List<GameNode>> {
  @override
  Future<List<GameNode>> build() async {
    return _fetch();
  }

  Future<List<GameNode>> _fetch() async {
    final game = ref.watch(selectedGameProvider);
    if (game == null) return [];

    final repo = ref.read(nodeRepositoryProvider);
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

final nodesProvider =
    AsyncNotifierProvider<NodesNotifier, List<GameNode>>(NodesNotifier.new);
