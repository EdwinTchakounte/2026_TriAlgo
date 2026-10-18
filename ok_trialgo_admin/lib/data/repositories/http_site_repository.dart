// =============================================================
// FICHIER : http_site_repository.dart
// ROLE    : SiteRepository contre /api/admin/site (FastAPI)
// =============================================================
//
// Mapping :
//   charger()         -> GET  /api/admin/site/accueil
//   publier()         -> PUT  /api/admin/site/accueil   {"contenu": {...}}
//   televerserImage() -> POST /api/admin/site/images    (multipart "file")
//
// LE CAS DU 422
// -------------
// Le backend valide le document avec Pydantic et refuse tout champ
// inconnu ou trop long. Son 'detail' n'est alors PAS une phrase
// mais une LISTE d'erreurs ({loc, msg}). L'afficher brut donnerait
// un "[{type: string_too_long, loc: [body, contenu, ...]..." illisible.
// _detail() la reformule en "hero > titre : String should have at
// most 120 characters", ce qui dit a l'administrateur QUEL champ
// corriger.
// =============================================================

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/site_content.dart';
import '../../domain/repositories/site_repository.dart';

class HttpSiteRepository implements SiteRepository {
  final Dio _dio;
  HttpSiteRepository() : _dio = DioClient.instance;

  static const _chemin = '/api/admin/site/accueil';

  // -----------------------------------------------------------
  // PARSING : {"contenu": {...}, "maj_le": iso|null}
  // -----------------------------------------------------------
  ContenuAccueil _parse(Map<String, dynamic> j) {
    final brut = j['contenu'];
    final majLe = j['maj_le'] is String
        ? DateTime.tryParse(j['maj_le'] as String)
        : null;
    return ContenuAccueil.fromJson(
      brut is Map<String, dynamic> ? brut : const {},
      majLe: majLe,
    );
  }

  // -----------------------------------------------------------
  // ERREURS
  // -----------------------------------------------------------
  String _detail(Object? data, String fallback) {
    if (data is! Map) return fallback;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List) {
      final lignes = <String>[];
      for (final e in detail) {
        if (e is! Map) continue;
        // On retire les segments techniques (body, contenu) : seul
        // le chemin DANS le document parle a l'administrateur.
        final loc = (e['loc'] is List ? e['loc'] as List : const [])
            .map((s) => s.toString())
            .where((s) => s != 'body' && s != 'contenu')
            .join(' > ');
        lignes.add(loc.isEmpty ? '${e['msg']}' : '$loc : ${e['msg']}');
      }
      if (lignes.isNotEmpty) return lignes.join('\n');
    }
    return fallback;
  }

  Result<T> _err<T>(Response r, String fallback) =>
      Err(DataFailure('${r.statusCode}: ${_detail(r.data, fallback)}'));

  Result<T> _erreurDio<T>(DioException e, String fallback) {
    final reponse = e.response;
    if (reponse != null) return _err(reponse, fallback);
    return Err(DataFailure('Erreur réseau : ${e.message}'));
  }

  // -----------------------------------------------------------
  // GET
  // -----------------------------------------------------------
  @override
  Future<Result<ContenuAccueil>> charger() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_chemin);
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Contenu de la vitrine indisponible');
      }
      return Ok(_parse(res.data!));
    } on DioException catch (e) {
      return _erreurDio(e, 'Contenu de la vitrine indisponible');
    }
  }

  // -----------------------------------------------------------
  // PUT
  // -----------------------------------------------------------
  @override
  Future<Result<ContenuAccueil>> publier(ContenuAccueil contenu) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        _chemin,
        data: {'contenu': contenu.toJson()},
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Publication échouée');
      }
      return Ok(_parse(res.data!));
    } on DioException catch (e) {
      return _erreurDio(e, 'Publication échouée');
    }
  }

  // -----------------------------------------------------------
  // POST multipart
  // -----------------------------------------------------------
  @override
  Future<Result<String>> televerserImage({
    required Uint8List octets,
    required String nomFichier,
    required String typeMime,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          octets,
          filename: nomFichier,
          contentType: DioMediaType.parse(typeMime),
        ),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/admin/site/images',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      final url = res.data?['url'];
      if (res.statusCode != 201 || url is! String) {
        return _err(res, 'Téléversement échoué');
      }
      return Ok(url);
    } on DioException catch (e) {
      // 413 (trop lourd) et 400 (pas une image) arrivent ici, avec
      // un detail serveur explicite qu'on remonte tel quel.
      return _erreurDio(e, 'Téléversement échoué');
    }
  }
}
