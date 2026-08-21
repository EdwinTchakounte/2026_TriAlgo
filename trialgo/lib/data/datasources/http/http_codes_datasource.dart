// =============================================================
// FICHIER : http_codes_datasource.dart  (trialgo - app joueur)
// ROLE    : Activation de code (POST /api/codes/activate)
// =============================================================
//
// Le backend renvoie TOUJOURS un 200 OK avec un payload :
//   { success: bool, reason: string?, message: string,
//     game_id: uuid?, changes_left: int? }
//
// On ne fait PAS de throw sur success=false : c'est un cas
// metier prevu (mauvais code, deja assigne, bloque, etc.).
// Le caller (repository / UI) decode et affiche le message.
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpCodesDatasource {
  final Dio _dio;
  HttpCodesDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  // -----------------------------------------------------------
  // POST /api/codes/activate
  // -----------------------------------------------------------
  // 5 cas possibles, tous renvoyes en 200 OK :
  //   - success=true  : code accepte
  //   - reason='invalid' / 'inactive' / 'blocked' /
  //     'already_assigned_other' / 'already_active_other_game'
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> activate({
    required String code,
    required String deviceId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/codes/activate',
      data: {'code': code, 'device_id': deviceId},
    );
    _ensure(res, 'Activation impossible');
    return res.data!;
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    // Note : un 4xx ici signifie une erreur d'auth/validation,
    // pas un echec metier (les echecs metier renvoient 200).
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
