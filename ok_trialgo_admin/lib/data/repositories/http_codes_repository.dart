// =============================================================
// FICHIER : http_codes_repository.dart
// ROLE    : CodesRepository contre /api/admin/codes (FastAPI)
// =============================================================
//
// Mapping :
//   listAll()         -> GET    /api/admin/codes?limit&offset&game_id
//   create()          -> POST   /api/admin/codes
//   setActive()       -> PATCH  /api/admin/codes/{code}
//   resetAssignment() -> PATCH  /api/admin/codes/{code}
//   delete()          -> DELETE /api/admin/codes/{code}
//
// setActive et resetAssignment tapent la meme route avec un corps
// different : le backend expose un update partiel a deux champs
// independants (is_active, reset_assignment). Les separer ici rend
// l'intention lisible cote appelant -- "desactiver" et "remettre a
// zero pour le service apres-vente" sont deux gestes tres
// differents, meme s'ils empruntent le meme tuyau.
// =============================================================

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/activation_code.dart';
import '../../domain/repositories/codes_repository.dart';

class HttpCodesRepository implements CodesRepository {
  final Dio _dio;
  HttpCodesRepository() : _dio = DioClient.instance;

  // -----------------------------------------------------------
  // PARSING
  // -----------------------------------------------------------
  // Les dates nullables passent par tryParse plutot que parse :
  // une date malformee ne doit pas faire echouer toute la liste,
  // elle doit juste s'afficher comme absente.
  // -----------------------------------------------------------

  ActivationCode _parse(Map<String, dynamic> j) {
    return ActivationCode(
      code: j['code'] as String,
      gameId: j['game_id'] as String,
      assignedTo: j['assigned_to'] as String?,
      deviceId: j['device_id'] as String?,
      deviceChangesCount: (j['device_changes_count'] as int?) ?? 0,
      maxDeviceChanges: (j['max_device_changes'] as int?) ?? 3,
      isBlocked: (j['is_blocked'] as bool?) ?? false,
      isActive: (j['is_active'] as bool?) ?? true,
      activatedAt: _dateOuNull(j['activated_at']),
      createdAt: _dateOuNull(j['created_at']) ?? DateTime.now(),
    );
  }

  DateTime? _dateOuNull(Object? brut) {
    if (brut is! String) return null;
    return DateTime.tryParse(brut);
  }

  Result<T> _err<T>(Response r, String fallback) {
    final detail = r.data is Map<String, dynamic>
        ? (r.data['detail']?.toString() ?? fallback)
        : fallback;
    return Err(DataFailure('${r.statusCode}: $detail'));
  }

  // -----------------------------------------------------------
  // GESTION DES ERREURS DIO
  // -----------------------------------------------------------
  // Dio leve une DioException des que le statut n'est pas 2xx.
  // Le corps de la reponse porte alors le 'detail' de FastAPI,
  // qui est le message le plus utile pour l'administrateur
  // ('Code deja existant', 'Jeu introuvable'...). Le laisser de
  // cote pour afficher un 'Erreur reseau' generique reviendrait a
  // masquer exactement l'information dont il a besoin.
  // -----------------------------------------------------------

  Result<T> _erreurDio<T>(DioException e, String fallback) {
    final reponse = e.response;
    if (reponse != null) return _err(reponse, fallback);
    return Err(DataFailure('Erreur reseau : ${e.message}'));
  }

  // -----------------------------------------------------------
  // LIST
  // -----------------------------------------------------------

  @override
  Future<Result<PageDeCodes>> listAll({
    String? gameId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/admin/codes',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (gameId != null) 'game_id': gameId,
        },
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Liste des codes indisponible');
      }

      final data = res.data!;
      final items = (data['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_parse)
          .toList();

      return Ok(PageDeCodes(
        items: items,
        total: (data['total'] as int?) ?? items.length,
        limit: (data['limit'] as int?) ?? limit,
        offset: (data['offset'] as int?) ?? offset,
      ));
    } on DioException catch (e) {
      return _erreurDio(e, 'Liste des codes indisponible');
    }
  }

  // -----------------------------------------------------------
  // CREATE
  // -----------------------------------------------------------

  @override
  Future<Result<ActivationCode>> create({
    required String code,
    required String gameId,
    int maxDeviceChanges = 3,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/admin/codes',
        data: {
          'code': code,
          'game_id': gameId,
          'max_device_changes': maxDeviceChanges,
        },
      );
      if (res.statusCode != 201 || res.data == null) {
        return _err(res, 'Creation du code echouee');
      }
      return Ok(_parse(res.data!));
    } on DioException catch (e) {
      return _erreurDio(e, 'Creation du code echouee');
    }
  }

  // -----------------------------------------------------------
  // PATCH : is_active
  // -----------------------------------------------------------

  @override
  Future<Result<ActivationCode>> setActive({
    required String code,
    required bool isActive,
  }) async {
    return _patch(code, {'is_active': isActive}, 'Mise a jour echouee');
  }

  // -----------------------------------------------------------
  // PATCH : reset_assignment
  // -----------------------------------------------------------

  @override
  Future<Result<ActivationCode>> resetAssignment(String code) async {
    return _patch(code, {'reset_assignment': true}, 'Reinitialisation echouee');
  }

  Future<Result<ActivationCode>> _patch(
    String code,
    Map<String, dynamic> corps,
    String fallback,
  ) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/admin/codes/$code',
        data: corps,
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, fallback);
      }
      return Ok(_parse(res.data!));
    } on DioException catch (e) {
      return _erreurDio(e, fallback);
    }
  }

  // -----------------------------------------------------------
  // DELETE
  // -----------------------------------------------------------

  @override
  Future<Result<void>> delete(String code) async {
    try {
      final res = await _dio.delete<dynamic>('/api/admin/codes/$code');
      if (res.statusCode != 204) {
        return _err(res, 'Suppression echouee');
      }
      return const Ok(null);
    } on DioException catch (e) {
      // Cas frequent : 409 ou 500 parce qu'un user_games reference
      // encore ce code (contrainte RESTRICT). Le detail du serveur
      // est plus parlant que n'importe quel message generique.
      return _erreurDio(e, 'Suppression echouee');
    }
  }
}
