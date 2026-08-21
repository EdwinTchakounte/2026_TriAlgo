// =============================================================
// FICHIER : http_admin_users_repository.dart
// ROLE    : AdminUsersRepository contre /api/admin/users (FastAPI)
// =============================================================
//
// Mapping :
//   listAll()         -> GET   /api/admin/users?limit&offset
//   togglePromotion() -> POST  /api/admin/users/{id}/promote
//   setActive()       -> PATCH /api/admin/users/{id}
//
// POURQUOI PROMOTE EST UN POST SANS CORPS
// ---------------------------------------
// Le serveur bascule is_admin lui-meme : il n'accepte pas de
// valeur cible. Ce n'est pas un oubli, c'est ce qui lui permet de
// verifier le garde-fou "dernier administrateur actif" au moment
// exact ou il decide, sans risque d'ecart entre ce que le client
// croyait et l'etat reel de la base.
// =============================================================

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_users_repository.dart';

class HttpAdminUsersRepository implements AdminUsersRepository {
  final Dio _dio;
  HttpAdminUsersRepository() : _dio = DioClient.instance;

  AdminUser _parse(Map<String, dynamic> j) {
    return AdminUser(
      id: j['id'] as String,
      email: j['email'] as String,
      isAdmin: (j['is_admin'] as bool?) ?? false,
      isActive: (j['is_active'] as bool?) ?? true,
      emailConfirmedAt: _dateOuNull(j['email_confirmed_at']),
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

  // Le 'detail' de FastAPI porte ici les messages des garde-fous
  // ('Vous ne pouvez pas vous demouvoir...', 'Vous ne pouvez pas
  // desactiver votre propre compte'). Ce sont EXACTEMENT les
  // phrases a montrer a l'administrateur : on les fait remonter
  // telles quelles plutot que de les remplacer par un generique.
  Result<T> _erreurDio<T>(DioException e, String fallback) {
    final reponse = e.response;
    if (reponse != null) return _err(reponse, fallback);
    return Err(DataFailure('Erreur reseau : ${e.message}'));
  }

  @override
  Future<Result<PageDUtilisateurs>> listAll({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/admin/users',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Liste des comptes indisponible');
      }

      final data = res.data!;
      final items = (data['items'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_parse)
          .toList();

      return Ok(PageDUtilisateurs(
        items: items,
        total: (data['total'] as int?) ?? items.length,
        limit: (data['limit'] as int?) ?? limit,
        offset: (data['offset'] as int?) ?? offset,
      ));
    } on DioException catch (e) {
      return _erreurDio(e, 'Liste des comptes indisponible');
    }
  }

  @override
  Future<Result<AdminUser>> togglePromotion(String userId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/admin/users/$userId/promote',
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Changement de statut echoue');
      }
      return Ok(_parse(res.data!));
    } on DioException catch (e) {
      return _erreurDio(e, 'Changement de statut echoue');
    }
  }

  @override
  Future<Result<AdminUser>> setActive({
    required String userId,
    required bool isActive,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/admin/users/$userId',
        data: {'is_active': isActive},
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Mise a jour du compte echouee');
      }
      return Ok(_parse(res.data!));
    } on DioException catch (e) {
      return _erreurDio(e, 'Mise a jour du compte echouee');
    }
  }
}
