// =============================================================
// FICHIER : lib/data/repositories/graph_repository_impl.dart
// ROLE   : Implementation du GraphRepository (Supabase OU FastAPI)
// COUCHE : Data > Repositories
// =============================================================
//
// Charge le graphe complet (cartes + fusions) d'un jeu pour permettre
// au generateur de questions cote client de fabriquer les triplets.
//
// Toutes les requetes sont filtrees par game_id car la DB contient
// plusieurs jeux. On ne sync qu'un jeu a la fois.
//
// BRANCHEMENT BACKEND :
//   - Supabase : SELECT direct sur cards/nodes (RLS authenticated)
//   - FastAPI  : GET /api/games/{gid}/cards et /api/games/{gid}/nodes
//                (auth user requise dans les deux cas)
//
// Les operations ADMIN (insert/delete) restent sur Supabase historique :
// elles ne sont pas appelees depuis l'app joueur. Si plus tard on veut
// les exposer (ex: studio admin sur trialgo aussi), on branchera vers
// les endpoints admin FastAPI a ce moment-la.
// =============================================================

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/data/datasources/http/http_public_games_datasource.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/data/models/graph_card_model.dart';
import 'package:trialgo/data/models/graph_node_model.dart';

class GraphRepositoryImpl implements GraphRepository {

  // Datasource HTTP partagee (singleton Dio).
  final HttpPublicGamesDatasource _httpGames = HttpPublicGamesDatasource();

  // =============================================================
  // LECTURE (utilisee par le client joueur)
  // =============================================================

  /// SELECT * FROM cards WHERE game_id = $gameId
  @override
  Future<List<GraphCardEntity>> getAllCards(String gameId) async {
    if (ApiConfig.isFastApi) {
      // GET /api/games/{gid}/cards (auth user, inclut card_type).
      // Le datasource renvoie une List<Map<String, dynamic>> brute.
      final rows = await _httpGames.listGameCardsAuth(gameId);
      return rows.map((j) => GraphCardModel.fromJson(j)).toList();
    }
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
    if (ApiConfig.isFastApi) {
      // GET /api/games/{gid}/nodes (auth user, deja ordered par node_index
      // cote backend cf nodes/routes.py).
      final rows = await _httpGames.listGameNodesAuth(gameId);
      return rows.map((j) => GraphNodeModel.fromJson(j)).toList();
    }
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
  // Ces methodes ne sont PAS appelees depuis l'app joueur, elles
  // restent sur Supabase historique. L'app admin FastAPI a ses
  // propres endpoints (cf ok_trialgo_admin/lib/data/repositories/
  // http_card_repository.dart et http_node_repository.dart).
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
