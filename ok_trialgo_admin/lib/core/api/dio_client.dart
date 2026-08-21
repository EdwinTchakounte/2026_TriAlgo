// =============================================================
// FICHIER : dio_client.dart
// ROLE    : Factory Dio + interceptor Bearer + refresh 401
// =============================================================
//
// Centralise la construction du client HTTP utilise par TOUS les
// Http*Repository. L'interceptor fait deux choses :
//
//   1. AVANT chaque requete : injecte le header Authorization:
//      Bearer <access_jwt> s'il est disponible.
//
//   2. APRES chaque reponse : si 401 sur une requete autre que
//      /auth/refresh ou /auth/login, on tente de rafraichir
//      l'access avec le refresh stocke. Si succes, on rejoue la
//      requete originale ; si echec, on vide le storage et on
//      laisse l'erreur remonter (l'UI affichera le login).
//
// Le client est un singleton (lazy) cree au premier acces.
// =============================================================

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'token_storage.dart';

class DioClient {
  DioClient._();

  static final TokenStorage _storage = TokenStorage();
  static Dio? _instance;

  /// Singleton : meme Dio partage par tous les repos.
  static Dio get instance => _instance ??= _build();

  static Dio _build() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      // Reponses : on n'echoue pas tout de suite sur les 4xx/5xx,
      // on laisse les repos les decoder en Failure.
      validateStatus: (code) => code != null && code < 500,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Injection du Bearer (sauf endpoints publics qu'on
        // marque avec options.extra['noAuth'] = true).
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
      // Utilise une Dio neuve sans interceptor pour eviter une
      // boucle infinie (si refresh renvoie 401 lui aussi).
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
  // Accesseur direct au TokenStorage (utilise par AuthRepository).
  // -----------------------------------------------------------
  static TokenStorage get storage => _storage;
}
