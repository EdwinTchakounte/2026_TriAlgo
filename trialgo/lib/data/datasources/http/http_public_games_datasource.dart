// =============================================================
// FICHIER : http_public_games_datasource.dart  (trialgo)
// ROLE    : Catalogue public des jeux et leurs cartes
// =============================================================
//
// Endpoints PUBLICS (pas d'auth requise) :
//   GET /api/public/games                 liste games actifs
//   GET /api/public/games/{id}            detail d'un game
//   GET /api/public/games/{id}/cards      liste cartes (sans card_type)
//
// Note : pour avoir le card_type (necessaire au gameplay), il faut
// passer par GET /api/games/{gid}/cards (auth user). Ce datasource
// expose le catalogue "vitrine".
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpPublicGamesDatasource {
  final Dio _dio;
  HttpPublicGamesDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  // GET /api/public/games (no auth)
  Future<List<Map<String, dynamic>>> listPublicGames() async {
    final res = await _dio.get<List<dynamic>>(
      '/api/public/games',
      options: Options(extra: {'noAuth': true}),
    );
    _ensure(res, 'Catalogue indisponible');
    return res.data!.cast<Map<String, dynamic>>();
  }

  // GET /api/public/games/{id} (no auth)
  Future<Map<String, dynamic>> getPublicGame(String gameId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/public/games/$gameId',
      options: Options(extra: {'noAuth': true}),
    );
    _ensure(res, 'Jeu indisponible');
    return res.data!;
  }

  // GET /api/public/games/{id}/cards (no auth, sans card_type)
  Future<List<Map<String, dynamic>>> listPublicCards(String gameId) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/public/games/$gameId/cards',
      options: Options(extra: {'noAuth': true}),
    );
    _ensure(res, 'Cartes indisponibles');
    return res.data!.cast<Map<String, dynamic>>();
  }

  // GET /api/games/{gid}/cards (auth user, INCLUT card_type)
  // Utilise par le gameplay (besoin de connaitre les types pour
  // generer les questions cote client).
  Future<List<Map<String, dynamic>>> listGameCardsAuth(String gameId) async {
    final res = await _dio.get<List<dynamic>>('/api/games/$gameId/cards');
    _ensure(res, 'Cartes indisponibles');
    return res.data!.cast<Map<String, dynamic>>();
  }

  // GET /api/games/{gid}/nodes (auth user requise)
  // Utilise par le graph_repository pour reconstruire le graphe
  // cote client (cards + nodes -> generate questions).
  Future<List<Map<String, dynamic>>> listGameNodesAuth(String gameId) async {
    final res = await _dio.get<List<dynamic>>('/api/games/$gameId/nodes');
    _ensure(res, 'Graphe indisponible');
    return res.data!.cast<Map<String, dynamic>>();
  }

  void _ensure(Response res, String fb) {
    final c = res.statusCode ?? 0;
    if (c >= 200 && c < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fb (HTTP $c)');
  }
}
