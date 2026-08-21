// =============================================================
// FICHIER : node_repository_impl.dart
// ROLE    : Implementation Supabase de NodeRepository
// =============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/game_node.dart';
import '../../domain/repositories/node_repository.dart';
import '../models/node_model.dart';

class NodeRepositoryImpl implements NodeRepository {
  final SupabaseClient _client;

  NodeRepositoryImpl(this._client);

  static const _table = 'nodes';

  // -----------------------------------------------------------
  // listByGame : tri par node_index pour faciliter le picker
  // de parent et la preview de l'arbre.
  // -----------------------------------------------------------
  @override
  Future<Result<List<GameNode>>> listByGame(String gameId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('game_id', gameId)
          .order('node_index', ascending: true);
      final nodes = (rows as List)
          .map((r) => NodeModel.fromJson(r as Map<String, dynamic>))
          .toList();
      return Ok(nodes);
    } catch (e) {
      return Err(DataFailure('Liste nodes impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // nextNodeIndex : MAX + 1, ou 1 si vide.
  // PostgREST ne supporte pas directement MAX(...) en SELECT ;
  // on demande la ligne avec le node_index le plus haut et on
  // ajoute 1. Pour un MVP single-admin c'est suffisant ; un vrai
  // multi-admin necessiterait une transaction SQL (RPC).
  // -----------------------------------------------------------
  @override
  Future<Result<int>> nextNodeIndex(String gameId) async {
    try {
      final rows = await _client
          .from(_table)
          .select('node_index')
          .eq('game_id', gameId)
          .order('node_index', ascending: false)
          .limit(1);
      // Si aucune ligne : on commence a 1.
      if ((rows as List).isEmpty) return const Ok(1);
      final max = ((rows.first as Map)['node_index'] as num).toInt();
      return Ok(max + 1);
    } catch (e) {
      return Err(DataFailure('Calcul node_index impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // createTrio : INSERT avec respect strict de la CHECK
  // constraint depth/parent (cote app on a deja valide).
  // -----------------------------------------------------------
  @override
  Future<Result<GameNode>> createTrio({
    required String gameId,
    required int nodeIndex,
    required String? emettriceId,
    required String cableId,
    required String receptriceId,
    required String? parentNodeId,
    required int depth,
  }) async {
    try {
      final row = await _client
          .from(_table)
          .insert(NodeModel.toInsert(
            gameId: gameId,
            nodeIndex: nodeIndex,
            emettriceId: emettriceId,
            cableId: cableId,
            receptriceId: receptriceId,
            parentNodeId: parentNodeId,
            depth: depth,
          ))
          .select()
          .single();
      return Ok(NodeModel.fromJson(row));
    } catch (e) {
      return Err(DataFailure('Creation trio impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // delete : ON DELETE CASCADE (cote DB) supprime les enfants.
  // -----------------------------------------------------------
  @override
  Future<Result<void>> delete(String nodeId) async {
    try {
      await _client.from(_table).delete().eq('id', nodeId);
      return const Ok<void>(null);
    } catch (e) {
      return Err(DataFailure('Suppression node impossible : $e'));
    }
  }
}
