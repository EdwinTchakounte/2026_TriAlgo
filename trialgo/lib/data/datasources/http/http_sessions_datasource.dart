// =============================================================
// FICHIER : http_sessions_datasource.dart  (trialgo)
// ROLE    : Historique des parties jouees (POST/GET /api/me/sessions)
// =============================================================
//
// Endpoints :
//   POST /api/me/sessions   enregistre une partie terminee + UPDATE
//                           user_games (total_score, level, vies)
//   GET  /api/me/sessions   historique paginated (filtre game_id ok)
//
// Le backend met a jour user_games dans la meme transaction :
//   - total_score += score_gained
//   - si passed et level >= current_level : current_level = level + 1
//   - si !passed : lives -= 1 (plancher 0)
// La reponse renvoie new_total_score / new_current_level / new_lives.
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpSessionsDatasource {
  final Dio _dio;
  HttpSessionsDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  // -----------------------------------------------------------
  // POST /api/me/sessions
  // -----------------------------------------------------------
  // Body : tout l'etat de la partie terminee.
  // Reponse : { session: {...}, new_total_score, new_current_level,
  //             new_lives, new_max_lives }
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> recordSession({
    required String gameId,
    required int level,
    required int scoreGained,
    required int correctAnswers,
    required int wrongAnswers,
    required int questionsTotal,
    required int maxStreak,
    required int durationSeconds,
    required bool passed,
    required int starsEarned,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/me/sessions',
      data: {
        'game_id': gameId,
        'level': level,
        'score_gained': scoreGained,
        'correct_answers': correctAnswers,
        'wrong_answers': wrongAnswers,
        'questions_total': questionsTotal,
        'max_streak': maxStreak,
        'duration_seconds': durationSeconds,
        'passed': passed,
        'stars_earned': starsEarned,
      },
    );
    _ensure(res, 'Enregistrement de la partie impossible');
    return res.data!;
  }

  // -----------------------------------------------------------
  // GET /api/me/sessions?game_id=...&limit=...&offset=...
  // -----------------------------------------------------------
  // Reponse paginated : { items: [...], total, limit, offset }
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> listMySessions({
    String? gameId,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (gameId != null) 'game_id': gameId,
    };
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/me/sessions',
      queryParameters: query,
    );
    _ensure(res, 'Historique indisponible');
    return res.data!;
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
