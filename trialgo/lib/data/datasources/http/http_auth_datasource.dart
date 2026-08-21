// =============================================================
// FICHIER : http_auth_datasource.dart  (trialgo - app joueur)
// ROLE    : Appels HTTP vers /api/auth/* du backend FastAPI
// COUCHE  : Data > Datasources > HTTP
// =============================================================
//
// Couvre tous les endpoints d'authentification du backend FastAPI :
//   - register             : creation compte (+ auto-login)
//   - login                : recupere (access, refresh)
//   - refresh              : rafraichit l'access (gere aussi par
//                            l'interceptor Dio, mais expose ici si
//                            besoin manuel)
//   - me                   : profil minimal de l'utilisateur connecte
//   - confirm-email        : consomme le token recu par email
//   - resend-confirmation  : redemande un mail de confirmation
//   - forgot-password      : demande un lien de reset
//   - reset-password       : applique le nouveau mot de passe
//   - logout (local only)  : vide les tokens (JWT stateless)
//
// Cette couche NE manipule QUE des Map<String, dynamic> (JSON brut).
// Le repository fait la conversion en entites typees.
// =============================================================

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class HttpAuthDatasource {
  final Dio _dio;

  HttpAuthDatasource({Dio? dio}) : _dio = dio ?? DioClient.instance;

  // -----------------------------------------------------------
  // POST /api/auth/register
  // -----------------------------------------------------------
  // Cree un compte + envoie un mail de bienvenue+confirm en
  // background cote serveur. La reponse contient :
  //   { user: {...}, tokens: { access_token, refresh_token } }
  // Auto-login : on persiste directement les tokens.
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {'email': email, 'password': password},
      // Pas besoin d'envoyer un Bearer pour register.
      options: Options(extra: {'noAuth': true}),
    );
    _ensureSuccess(res, 'Inscription impossible');
    final data = res.data!;
    // Persistance des tokens pour les prochaines requetes.
    final tokens = data['tokens'] as Map<String, dynamic>;
    await DioClient.storage.save(
      access: tokens['access_token'] as String,
      refresh: tokens['refresh_token'] as String,
    );
    return data;
  }

  // -----------------------------------------------------------
  // POST /api/auth/login
  // -----------------------------------------------------------
  // Recupere (access, refresh) et les persiste.
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: {'noAuth': true}),
    );
    _ensureSuccess(res, 'Email ou mot de passe invalide');
    final data = res.data!;
    await DioClient.storage.save(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    return data;
  }

  // -----------------------------------------------------------
  // POST /api/auth/refresh
  // -----------------------------------------------------------
  // Rafraichissement manuel. L'interceptor Dio le fait
  // automatiquement sur 401 ; cette methode est utile si on veut
  // forcer le refresh (ex : avant un long upload).
  // -----------------------------------------------------------
  Future<Map<String, dynamic>> refresh() async {
    final (_, refresh) = await DioClient.storage.read();
    if (refresh == null) {
      throw Exception('Aucun refresh token disponible');
    }
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/refresh',
      data: {'refresh_token': refresh},
      options: Options(extra: {'noAuth': true, 'noRetry': true}),
    );
    _ensureSuccess(res, 'Refresh impossible');
    final data = res.data!;
    await DioClient.storage.save(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    return data;
  }

  // -----------------------------------------------------------
  // GET /api/auth/me
  // -----------------------------------------------------------
  // Profil minimal de l'user connecte (id, email, is_admin,
  // is_active, email_confirmed_at).
  // -----------------------------------------------------------
  Future<Map<String, dynamic>?> me() async {
    final (access, _) = await DioClient.storage.read();
    if (access == null) return null;
    final res = await _dio.get<Map<String, dynamic>>('/api/auth/me');
    if (res.statusCode == 401) {
      // L'interceptor a deja tente un refresh. Si on est encore en
      // 401 ici, c'est que la session est morte.
      return null;
    }
    _ensureSuccess(res, 'Profil indisponible');
    return res.data;
  }

  // -----------------------------------------------------------
  // POST /api/auth/confirm-email
  // -----------------------------------------------------------
  // Le token clair vient du lien recu par mail. Anti-enum 200
  // toujours cote backend.
  // -----------------------------------------------------------
  Future<void> confirmEmail({required String token}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/confirm-email',
      data: {'token': token},
      options: Options(extra: {'noAuth': true}),
    );
    _ensureSuccess(res, 'Token de confirmation invalide ou expire');
  }

  // -----------------------------------------------------------
  // POST /api/auth/resend-confirmation
  // -----------------------------------------------------------
  // Redemander un mail de confirmation. Renvoie 200 meme si email
  // inconnu (anti-enumeration). On ne fait pas remonter d'erreur.
  // -----------------------------------------------------------
  Future<void> resendConfirmation({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/auth/resend-confirmation',
      data: {'email': email},
      options: Options(extra: {'noAuth': true}),
    );
  }

  // -----------------------------------------------------------
  // POST /api/auth/forgot-password
  // -----------------------------------------------------------
  // Declenche l'envoi mail de reset. 200 toujours (anti-enum).
  // -----------------------------------------------------------
  Future<void> forgotPassword({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/auth/forgot-password',
      data: {'email': email},
      options: Options(extra: {'noAuth': true}),
    );
  }

  // -----------------------------------------------------------
  // POST /api/auth/reset-password
  // -----------------------------------------------------------
  // Consomme le token recu par mail + applique le nouveau mdp.
  // -----------------------------------------------------------
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/auth/reset-password',
      data: {'token': token, 'new_password': newPassword},
      options: Options(extra: {'noAuth': true}),
    );
    _ensureSuccess(res, 'Token de reset invalide ou expire');
  }

  // -----------------------------------------------------------
  // logout
  // -----------------------------------------------------------
  // JWT stateless : on vide juste les tokens cote client. Pas
  // d'appel serveur (le backend ne maintient pas de session).
  // -----------------------------------------------------------
  Future<void> logout() async {
    await DioClient.storage.clear();
  }

  // -----------------------------------------------------------
  // Helper : assure que la reponse est 2xx, sinon throw avec le
  // message d'erreur du backend (champ "detail" de FastAPI).
  // -----------------------------------------------------------
  void _ensureSuccess(Response res, String fallback) {
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) return;
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    throw Exception(detail?.toString() ?? '$fallback (HTTP $code)');
  }
}
