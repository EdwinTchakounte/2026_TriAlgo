// =============================================================
// FICHIER : http_stars_datasource.dart  (trialgo)
// ROLE    : Wallet etoiles (regen + exchange contre vie)
// =============================================================
//
// Endpoints :
//   GET  /api/me/stars                       wallet (regen appliquee)
//   POST /api/me/stars/exchange-for-life     10 etoiles -> 1 vie
//
// Le backend applique la regen 1 etoile / 5 min cote serveur,
// et persiste si du temps a passe. Le client n'a pas besoin de
// calculer lui-meme.
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpStarsDatasource {
  final Dio _dio;
  HttpStarsDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> getMyWallet() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/me/stars');
    _ensure(res, 'Wallet indisponible');
    return res.data!;
  }

  // -----------------------------------------------------------
  // POST /api/me/stars/exchange-for-life
  // -----------------------------------------------------------
  // game_id optionnel : si null, utilise selected_game_id du profil.
  // Reponse : { success, reason?, message, stars_after, lives_after,
  //             max_lives_after }
  // Renvoie toujours 200 OK ; le caller doit lire success/reason.
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> exchangeForLife({String? gameId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/me/stars/exchange-for-life',
      data: {if (gameId != null) 'game_id': gameId},
    );
    _ensure(res, 'Echange impossible');
    return res.data!;
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
