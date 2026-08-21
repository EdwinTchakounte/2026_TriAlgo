// =============================================================
// FICHIER : http_profile_datasource.dart  (trialgo - app joueur)
// ROLE    : Appels HTTP vers /api/me/profile (FastAPI)
// =============================================================
//
// Endpoints couverts :
//   GET   /api/me/profile   lecture (username, avatar, selected_game,
//                                    stars wallet)
//   PATCH /api/me/profile   update partiel (username/avatar/game)
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpProfileDatasource {
  final Dio _dio;
  HttpProfileDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  // -----------------------------------------------------------
  // GET /api/me/profile
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> getMyProfile() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/me/profile');
    _ensure(res, 'Profil indisponible');
    return res.data!;
  }

  // -----------------------------------------------------------
  // PATCH /api/me/profile
  // -----------------------------------------------------------
  // Patch partiel : seuls les champs non-null sont envoyes.
  // selected_game_id peut etre explicitement null pour deselectionner.
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> updateMyProfile({
    String? username,
    String? avatarId,
    String? selectedGameId,
    bool clearSelectedGame = false,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (avatarId != null) body['avatar_id'] = avatarId;
    if (clearSelectedGame) {
      body['selected_game_id'] = null;
    } else if (selectedGameId != null) {
      body['selected_game_id'] = selectedGameId;
    }
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/me/profile',
      data: body,
    );
    _ensure(res, 'Mise a jour profil impossible');
    return res.data!;
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
