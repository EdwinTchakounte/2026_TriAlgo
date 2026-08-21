// =============================================================
// FICHIER : http_game_repository.dart
// ROLE    : GameRepository contre /api/games (FastAPI)
// =============================================================
//
// Mapping :
//   listAll()  -> GET /api/games
//   create()   -> POST /api/games  (admin only cote serveur)
//   update()   -> PATCH /api/games/{id}
//
// On factorise le parsing JSON -> Game dans _parseGame.
// =============================================================

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/game.dart';
import '../../domain/repositories/game_repository.dart';

class HttpGameRepository implements GameRepository {
  final Dio _dio;
  HttpGameRepository() : _dio = DioClient.instance;

  Game _parseGame(Map<String, dynamic> j) {
    return Game(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      theme: j['theme'] as String?,
      coverImage: j['cover_image'] as String?,
      isActive: j['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  Result<T> _err<T>(Response r, String fallback) {
    final detail = r.data is Map<String, dynamic>
        ? (r.data['detail']?.toString() ?? fallback)
        : fallback;
    return Err(DataFailure('${r.statusCode}: $detail'));
  }

  @override
  Future<Result<List<Game>>> listAll() async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/games');
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Liste indisponible');
      }
      final list = res.data!
          .cast<Map<String, dynamic>>()
          .map(_parseGame)
          .toList();
      return Ok(list);
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<Game>> create({
    required String name,
    String? description,
    String? theme,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/games',
        data: {
          'name': name,
          if (description != null) 'description': description,
          if (theme != null) 'theme': theme,
        },
      );
      if (res.statusCode != 201 || res.data == null) {
        return _err(res, 'Creation echouee');
      }
      return Ok(_parseGame(res.data!));
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<Game>> update({
    required String id,
    String? name,
    String? description,
    String? theme,
    bool? isActive,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;
      if (theme != null) body['theme'] = theme;
      if (isActive != null) body['is_active'] = isActive;

      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/games/$id',
        data: body,
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Update echoue');
      }
      return Ok(_parseGame(res.data!));
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }
}
