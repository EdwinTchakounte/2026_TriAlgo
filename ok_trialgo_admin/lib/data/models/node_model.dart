// =============================================================
// FICHIER : node_model.dart (DTO data)
// ROLE    : Serialisation GameNode <-> JSON Supabase
// =============================================================

import '../../domain/entities/game_node.dart';

class NodeModel {
  NodeModel._();

  static GameNode fromJson(Map<String, dynamic> j) {
    return GameNode(
      id: j['id'] as String,
      gameId: j['game_id'] as String,
      // node_index est un INT cote DB -> deja un int en JSON.
      nodeIndex: (j['node_index'] as num).toInt(),
      // emettrice_id peut etre NULL (D>=2, deduit du parent).
      emettriceId: j['emettrice_id'] as String?,
      cableId: j['cable_id'] as String,
      receptriceId: j['receptrice_id'] as String,
      parentNodeId: j['parent_node_id'] as String?,
      depth: (j['depth'] as num).toInt(),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  // Insert : on respecte la CHECK constraint :
  //   - depth = 1 : emettrice_id NOT NULL, parent_node_id NULL
  //   - depth > 1 : emettrice_id NULL, parent_node_id NOT NULL
  static Map<String, dynamic> toInsert({
    required String gameId,
    required int nodeIndex,
    required String? emettriceId,
    required String cableId,
    required String receptriceId,
    required String? parentNodeId,
    required int depth,
  }) {
    return {
      'game_id': gameId,
      'node_index': nodeIndex,
      'emettrice_id': emettriceId,
      'cable_id': cableId,
      'receptrice_id': receptriceId,
      'parent_node_id': parentNodeId,
      'depth': depth,
    };
  }
}
