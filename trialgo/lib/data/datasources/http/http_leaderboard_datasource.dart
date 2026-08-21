// =============================================================
// FICHIER : http_leaderboard_datasource.dart  (trialgo)
// ROLE    : Leaderboard d'un jeu + stats personnelles
// =============================================================
//
// Endpoints :
//   GET /api/games/{gid}/leaderboard?limit=20
//     -> top users par user_games.total_score
//   GET /api/me/stats
//     -> agregats perso (best, sessions_passed, etc.)
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpLeaderboardDatasource {
  final Dio _dio;
  HttpLeaderboardDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> getLeaderboard({
    required String gameId,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/games/$gameId/leaderboard',
      queryParameters: {'limit': limit},
    );
    _ensure(res, 'Classement indisponible');
    return res.data!;
  }

  Future<Map<String, dynamic>> getMyStats() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/me/stats');
    _ensure(res, 'Statistiques indisponibles');
    return res.data!;
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
