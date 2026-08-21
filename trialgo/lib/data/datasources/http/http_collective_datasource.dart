// =============================================================
// FICHIER : http_collective_datasource.dart  (trialgo)
// ROLE    : Mode collectif - verifier un node_index annonce par anim
// =============================================================
//
// Endpoint :
//   POST /api/games/{gid}/verify-collective  body: { node_index }
//     -> { exists, node_index, depth, emettrice_label, cable_label,
//          receptrice_label, message }
//
// Auth user requise (pas anonyme) pour eviter le scraping de la
// structure du jeu (qui donnerait les reponses).
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpCollectiveDatasource {
  final Dio _dio;
  HttpCollectiveDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> verifyTrio({
    required String gameId,
    required int nodeIndex,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/games/$gameId/verify-collective',
      data: {'node_index': nodeIndex},
    );
    _ensure(res, 'Verification impossible');
    return res.data!;
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
