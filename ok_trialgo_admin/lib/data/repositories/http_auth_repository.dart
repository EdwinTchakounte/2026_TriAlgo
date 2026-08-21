// =============================================================
// FICHIER : http_auth_repository.dart
// ROLE    : AuthRepository qui parle au backend FastAPI
// =============================================================
//
// Mapping :
//   AuthRepository.fetchCurrentProfile()  -> GET /api/auth/me
//   AuthRepository.signIn(email, pwd)     -> POST /api/auth/login
//                                            puis GET /me pour profil
//   AuthRepository.signOut()              -> efface tokens locaux
//                                            (pas d'endpoint serveur,
//                                            JWT stateless)
//
// Difference cle vs Supabase : ici le serveur retourne is_admin
// directement dans /me, donc pas de fetch supplementaire d'une
// table profile separe. On adapte UserProfile en consequence.
// =============================================================

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

class HttpAuthRepository implements AuthRepository {
  final Dio _dio;
  HttpAuthRepository() : _dio = DioClient.instance;

  // -----------------------------------------------------------
  // Mapping helper : DTO JSON -> UserProfile domain.
  // -----------------------------------------------------------
  // Le serveur renvoie { id, email, is_admin, is_active }.
  // UserProfile attend (id, username, avatarId, isAdmin) : on
  // utilise l'email comme username faute de mieux.
  UserProfile _parseUser(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: (json['email'] as String?) ?? 'admin',
      avatarId: null,
      isAdmin: (json['is_admin'] as bool?) ?? false,
    );
  }

  @override
  Future<Result<UserProfile?>> fetchCurrentProfile() async {
    // Si on n'a pas de token stocke, inutile de tenter.
    final (access, _) = await DioClient.storage.read();
    if (access == null) return const Ok<UserProfile?>(null);

    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/auth/me');
      if (res.statusCode == 200 && res.data != null) {
        return Ok<UserProfile?>(_parseUser(res.data!));
      }
      // 401 / autre -> pas de session valide.
      return const Ok<UserProfile?>(null);
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<UserProfile>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Login : recupere access + refresh.
      final loginRes = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email, 'password': password},
        options: Options(extra: {'noAuth': true}),
      );
      if (loginRes.statusCode != 200 || loginRes.data == null) {
        final msg = loginRes.data?['detail']?.toString() ?? 'Login refuse';
        return Err(AuthFailure(msg));
      }
      final access = loginRes.data!['access_token'] as String;
      final refresh = loginRes.data!['refresh_token'] as String;
      await DioClient.storage.save(access: access, refresh: refresh);

      // 2. Profile : lit is_admin pour gater l'app.
      final meRes = await _dio.get<Map<String, dynamic>>('/api/auth/me');
      if (meRes.statusCode != 200 || meRes.data == null) {
        await DioClient.storage.clear();
        return const Err(AuthFailure('Profil indisponible apres login'));
      }
      final profile = _parseUser(meRes.data!);

      // 3. Gate admin : si non admin, signOut et erreur.
      if (!profile.isAdmin) {
        await DioClient.storage.clear();
        return const Err(NotAdminFailure());
      }
      return Ok(profile);
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<void> signOut() async {
    await DioClient.storage.clear();
  }
}
