// =============================================================
// FICHIER : http_unlocked_cards_datasource.dart  (trialgo)
// ROLE    : Deck du joueur (galerie de cartes debloquees)
// =============================================================
//
// Endpoints :
//   POST /api/me/unlocked-cards     unlock une carte (idempotent)
//   GET  /api/me/unlocked-cards?game_id=...   deck pour ce jeu
//
// Le POST est idempotent grace a la PK composite cote serveur :
// si la carte est deja unlocked, on absorbe le conflit et on
// renvoie la ligne existante (no-op).
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpUnlockedCardsDatasource {
  final Dio _dio;
  HttpUnlockedCardsDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> unlockCard({
    required String cardId,
    required String gameId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/me/unlocked-cards',
      data: {'card_id': cardId, 'game_id': gameId},
    );
    _ensure(res, 'Deblocage impossible');
    return res.data!;
  }

  Future<List<Map<String, dynamic>>> listMyDeck({required String gameId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/me/unlocked-cards',
      queryParameters: {'game_id': gameId},
    );
    _ensure(res, 'Deck indisponible');
    return res.data!.cast<Map<String, dynamic>>();
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
