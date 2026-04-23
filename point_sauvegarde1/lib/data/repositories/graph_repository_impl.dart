// =============================================================
// FICHIER : lib/data/repositories/graph_repository_impl.dart
// ROLE   : Implementation Supabase du GraphRepository
// COUCHE : Data > Repositories
// =============================================================
//
// TOUTES les requetes sont filtrees par game_id car la BDD
// contient plusieurs jeux. On ne sync qu'un jeu a la fois.
// =============================================================

import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/data/models/graph_card_model.dart';
import 'package:trialgo/data/models/graph_node_model.dart';

class GraphRepositoryImpl implements GraphRepository {

  /// SELECT * FROM cards WHERE game_id = $gameId
  @override
  Future<List<GraphCardEntity>> getAllCards(String gameId) async {
    final data = await supabase
        .from('cards')
        .select()
        .eq('game_id', gameId);

    return data
        .map((json) => GraphCardModel.fromJson(json))
        .toList();
  }

  /// SELECT * FROM nodes WHERE game_id = $gameId ORDER BY node_index ASC
  @override
  Future<List<GraphNodeEntity>> getAllNodes(String gameId) async {
    final data = await supabase
        .from('nodes')
        .select()
        .eq('game_id', gameId)
        .order('node_index', ascending: true);

    return data
        .map((json) => GraphNodeModel.fromJson(json))
        .toList();
  }

  // =============================================================
  // ADMIN OPERATIONS
  // =============================================================

  @override
  Future<GraphCardEntity> insertCard({
    required String gameId,
    required String label,
    required String imagePath,
  }) async {
    final json = await supabase
        .from('cards')
        .insert({
          'game_id': gameId,
          'label': label,
          'image_path': imagePath,
        })
        .select()
        .single();

    return GraphCardModel.fromJson(json);
  }

  @override
  Future<GraphNodeEntity> insertRootNode({
    required String gameId,
    required int nodeIndex,
    required String emettriceId,
    required String cableId,
    required String receptriceId,
  }) async {
    final json = await supabase
        .from('nodes')
        .insert({
          'game_id': gameId,
          'node_index': nodeIndex,
          'emettrice_id': emettriceId,
          'cable_id': cableId,
          'receptrice_id': receptriceId,
          'parent_node_id': null,
          'depth': 1,
        })
        .select()
        .single();

    return GraphNodeModel.fromJson(json);
  }

  @override
  Future<GraphNodeEntity> insertChildNode({
    required String gameId,
    required int nodeIndex,
    required String cableId,
    required String receptriceId,
    required String parentNodeId,
    required int depth,
  }) async {
    final json = await supabase
        .from('nodes')
        .insert({
          'game_id': gameId,
          'node_index': nodeIndex,
          'emettrice_id': null,
          'cable_id': cableId,
          'receptrice_id': receptriceId,
          'parent_node_id': parentNodeId,
          'depth': depth,
        })
        .select()
        .single();

    return GraphNodeModel.fromJson(json);
  }

  @override
  Future<void> deleteNode(String nodeId) async {
    await supabase.from('nodes').delete().eq('id', nodeId);
  }

  @override
  Future<void> deleteCard(String cardId) async {
    await supabase.from('cards').delete().eq('id', cardId);
  }
}
