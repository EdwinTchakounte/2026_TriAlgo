// =============================================================
// FICHIER : dio_client.dart  (trialgo - app joueur)
// ROLE    : Factory Dio + interceptor Bearer + refresh auto 401
// =============================================================
//
// Centralise la construction du client HTTP utilise par TOUS les
// Http*Datasource du joueur. L'interceptor fait deux choses :
//
//   1. AVANT chaque requete : injecte le header Authorization:
//      Bearer <access_jwt> s'il est disponible. On peut bypass en
//      passant options.extra['noAuth'] = true (pour /api/public).
//
//   2. APRES chaque reponse : si 401 sur une requete autre que
//      /auth/refresh ou /auth/login, on tente de rafraichir
//      l'access avec le refresh stocke. Si succes, on rejoue la
//      requete originale ; si echec, on vide le storage et on
//      laisse l'erreur remonter (l'UI affichera le login).
//
// Le client est un singleton lazy : meme Dio partage par tous
// les datasources, donc une seule pile de connexions HTTP.
// =============================================================

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

class DioClient {
  DioClient._();

  static final TokenStorage _storage = TokenStorage();
  static Dio? _instance;

  /// Singleton : meme Dio pour tous les datasources.
  static Dio get instance => _instance ??= _build();

  /// Reset (pour tests ou switch d'environnement runtime).
  static void reset() {
    _instance = null;
  }

  static Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      // On n'echoue pas tout de suite sur les 4xx/5xx : les
      // datasources les decoderont en Failure (cf. Result<T>).
      validateStatus: (code) => code != null && code < 500,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Injection du Bearer sauf endpoints publics marques
        // explicitement avec extra['noAuth'] = true.
        if (options.extra['noAuth'] != true) {
          final (access, _) = await _storage.read();
          if (access != null) {
            options.headers['Authorization'] = 'Bearer $access';
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) async {
        // 401 sur requete normale + on a un refresh -> tenter le
        // rafraichissement. Si succes : on rejoue la requete.
        if (response.statusCode == 401 &&
            response.requestOptions.extra['noRetry'] != true) {
          final retried = await _tryRefreshAndReplay(response.requestOptions);
          if (retried != null) {
            handler.resolve(retried);
            return;
          }
          // Refresh echoue : on vide les tokens, l'UI doit
          // basculer sur l'ecran de login.
          await _storage.clear();
        }
        handler.next(response);
      },
    ));

    return dio;
  }

  // -----------------------------------------------------------
  // Tentative de refresh JWT + replay de la requete originale.
  // -----------------------------------------------------------
  static Future<Response<dynamic>?> _tryRefreshAndReplay(
    RequestOptions original,
  ) async {
    final (_, refresh) = await _storage.read();
    if (refresh == null) return null;

    try {
      // Dio neuve SANS interceptor pour eviter une boucle si le
      // refresh renvoie lui-meme 401.
      final raw = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final res = await raw.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refresh_token': refresh},
      );
      if (res.statusCode != 200 || res.data == null) return null;

      final access = res.data!['access_token'] as String?;
      final newRefresh = res.data!['refresh_token'] as String?;
      if (access == null || newRefresh == null) return null;

      await _storage.save(access: access, refresh: newRefresh);

      // Rejouer la requete originale avec le nouveau token.
      original.headers['Authorization'] = 'Bearer $access';
      original.extra['noRetry'] = true;
      return await instance.fetch(original);
    } catch (_) {
      return null;
    }
  }

  // -----------------------------------------------------------
  // Accesseur direct au TokenStorage (utilise par
  // HttpAuthDatasource pour save/clear).
  // -----------------------------------------------------------
  static TokenStorage get storage => _storage;
}
