// =============================================================
// FICHIER : http_played_nodes_datasource.dart  (trialgo)
// ROLE    : Tracking anti-doublon des questions jouees
// =============================================================
//
// Endpoints :
//   POST   /api/me/played-nodes               marque une tracking_key
//   GET    /api/me/played-nodes?game_id=...   liste les keys jouees
//   DELETE /api/me/played-nodes?game_id=...   reset pour ce jeu
//
// La tracking_key est generee cote client (ex: combinaison
// node_index + level + variation). Le serveur garantit
// l'unicite via UNIQUE(user, game, tracking_key).
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpPlayedNodesDatasource {
  final Dio _dio;
  HttpPlayedNodesDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> markPlayed({
    required String gameId,
    required String trackingKey,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/me/played-nodes',
      data: {'game_id': gameId, 'tracking_key': trackingKey},
    );
    _ensure(res, 'Tracking impossible');
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> listPlayedKeys({
    required String gameId,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/me/played-nodes',
      queryParameters: {'game_id': gameId},
    );
    _ensure(res, 'Liste tracking indisponible');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<void> resetPlayed({required String gameId}) async {
    final res = await _dio.delete<dynamic>(
      '/api/me/played-nodes',
      queryParameters: {'game_id': gameId},
    );
    _ensure(res, 'Reset impossible');
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
