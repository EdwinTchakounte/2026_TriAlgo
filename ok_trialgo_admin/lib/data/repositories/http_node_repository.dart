// =============================================================
// FICHIER : http_node_repository.dart
// ROLE    : NodeRepository contre /api/games/.../nodes (FastAPI)
// =============================================================

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/game_node.dart';
import '../../domain/repositories/node_repository.dart';

class HttpNodeRepository implements NodeRepository {
  final Dio _dio;
  HttpNodeRepository() : _dio = DioClient.instance;

  GameNode _parseNode(Map<String, dynamic> j) {
    return GameNode(
      id: j['id'] as String,
      gameId: j['game_id'] as String,
      nodeIndex: j['node_index'] as int,
      emettriceId: j['emettrice_id'] as String?,
      cableId: j['cable_id'] as String,
      receptriceId: j['receptrice_id'] as String,
      parentNodeId: j['parent_node_id'] as String?,
      depth: j['depth'] as int,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  Result<T> _err<T>(Response r, String fb) {
    final d = r.data is Map<String, dynamic>
        ? (r.data['detail']?.toString() ?? fb)
        : fb;
    return Err(DataFailure('${r.statusCode}: $d'));
  }

  @override
  Future<Result<List<GameNode>>> listByGame(String gameId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/games/$gameId/nodes');
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Liste nodes indisponible');
      }
      return Ok(res.data!.cast<Map<String, dynamic>>().map(_parseNode).toList());
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<int>> nextNodeIndex(String gameId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
          '/api/games/$gameId/nodes/next-index');
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'next-index indisponible');
      }
      return Ok(res.data!['next_index'] as int);
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

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
    // Note : le serveur ignore nodeIndex envoye (il calcule MAX+1
    // lui-meme cote DB pour eviter les races). On envoie quand
    // meme la valeur pour symetrie d'interface, sans la lire.
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/games/$gameId/nodes',
        data: {
          if (emettriceId != null) 'emettrice_id': emettriceId,
          if (parentNodeId != null) 'parent_node_id': parentNodeId,
          'cable_id': cableId,
          'receptrice_id': receptriceId,
          'depth': depth,
        },
      );
      if (res.statusCode != 201 || res.data == null) {
        return _err(res, 'Creation node echouee');
      }
      return Ok(_parseNode(res.data!));
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<void>> delete(String nodeId) async {
    try {
      final res = await _dio.delete('/api/nodes/$nodeId');
      if (res.statusCode != 204) {
        return _err(res, 'Suppression echouee');
      }
      return const Ok<void>(null);
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }
}
