// =============================================================
// FICHIER : node_repository.dart
// ROLE    : CRUD sur la table "nodes" (graphe du jeu)
// =============================================================
//
// Methodes :
//   - listAll       : tous les nodes d'un jeu
//   - nextNodeIndex : MAX(node_index) + 1 pour le prochain trio
//   - createTrio    : insere un nouveau trio (D1 ou enfant)
//   - deleteNode    : supprime un node (cascade sur enfants)
// =============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/node.dart';

class NodeRepository {
  final SupabaseClient _client;
  NodeRepository(this._client);

  // =========================================================
  // listAll : tous les nodes d'un jeu, tries par index
  // =========================================================
  Future<List<GameNode>> listAll(String gameId) async {
    final rows = await _client
        .from('nodes')
        .select()
        .eq('game_id', gameId)
        .order('node_index', ascending: true);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GameNode.fromJson)
        .toList();
  }

  // =========================================================
  // nextNodeIndex : calcule le prochain numero disponible
  // =========================================================
  // node_index est UNIQUE par jeu (cf schema). Pour eviter de
  // gerer une sequence cote DB, on calcule MAX+1 en lecture.
  // Risque de race en cas d'usage concurrent : negligeable pour
  // un dashboard admin a une seule instance.
  // =========================================================
  Future<int> nextNodeIndex(String gameId) async {
    final rows = await _client
        .from('nodes')
        .select('node_index')
        .eq('game_id', gameId)
        .order('node_index', ascending: false)
        .limit(1);

    if (rows.isEmpty) return 1;
    return ((rows.first as Map)['node_index'] as int) + 1;
  }

  // =========================================================
  // createTrio : insere un nouveau noeud
  // =========================================================
  // Cas D1 (racine) :
  //   parentNodeId = null, emettriceId = explicite, depth = 1
  //
  // Cas D>=2 (enfant) :
  //   parentNodeId = UUID du parent, emettriceId = null
  //   (l'emettrice effective est la receptrice du parent),
  //   depth = parent.depth + 1
  //
  // [nodeIndex] doit etre calcule en amont via nextNodeIndex.
  // =========================================================
  Future<GameNode> createTrio({
    required String gameId,
    required int nodeIndex,
    required String? emettriceId,
    required String cableId,
    required String receptriceId,
    required String? parentNodeId,
    required int depth,
  }) async {
    final inserted = await _client
        .from('nodes')
        .insert({
          'game_id': gameId,
          'node_index': nodeIndex,
          'emettrice_id': emettriceId,
          'cable_id': cableId,
          'receptrice_id': receptriceId,
          'parent_node_id': parentNodeId,
          'depth': depth,
        })
        .select()
        .single();

    return GameNode.fromJson(inserted);
  }

  // =========================================================
  // deleteNode : supprime un node (cascade vers enfants)
  // =========================================================
  // Le schema definit ON DELETE CASCADE sur parent_node_id.
  // Donc supprimer un D1 efface tous ses descendants D2-D5.
  // L'UI doit afficher un avertissement clair avant de lancer.
  // =========================================================
  Future<void> deleteNode(String id) async {
    await _client.from('nodes').delete().eq('id', id);
  }
}
