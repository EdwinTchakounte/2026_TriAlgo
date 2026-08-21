// =============================================================
// FICHIER : http_user_games_datasource.dart  (trialgo)
// ROLE    : Etat par-jeu de l'utilisateur (level, score, vies)
// =============================================================
//
// Endpoints :
//   GET /api/me/games               liste de tous les jeux actives
//                                   (refill vies applique)
//   GET /api/me/games/{game_id}     detail d'un jeu specifique
//
// Le backend applique automatiquement la regen des vies a chaque
// lecture, donc l'UI affiche toujours un compteur a jour.
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpUserGamesDatasource {
  final Dio _dio;
  HttpUserGamesDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<List<Map<String, dynamic>>> listMyGames() async {
    final res = await _dio.get<List<dynamic>>('/api/me/games');
    _ensure(res, 'Jeux indisponibles');
    return res.data!.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getMyGame(String gameId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/me/games/$gameId');
    _ensure(res, 'Jeu indisponible');
    return res.data!;
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
