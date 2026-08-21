// =============================================================
// FICHIER : http_card_repository.dart
// ROLE    : CardRepository contre /api/.../cards (FastAPI)
// =============================================================
//
// Particularite : le serveur expose UN SEUL endpoint multipart
// pour creer une carte (image + metadata en une POST). Mais
// l'interface domain expose 2 methodes :
//
//   uploadImage(...) -> renvoie un URL
//   create(...)      -> insere la carte avec cet URL
//
// Pour respecter le contrat sans casser le code existant cote
// presentation (step2_cards_page), on adopte une astuce :
//   uploadImage stocke les bytes EN MEMOIRE dans une Map indexee
//   par fileName, et retourne une cle synthetique "memory://...".
//   Au moment du create(), on reconnait la cle, on POST le multipart
//   au serveur en lisant les bytes correspondants, et on retourne
//   le card serveur (qui contient image_url calcule).
//
// Cette mecanique est totalement interne au repository : la couche
// presentation n'a pas a savoir.
// =============================================================

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/dio_client.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/card_type.dart';
import '../../domain/entities/game_card.dart';
import '../../domain/repositories/card_repository.dart';

class HttpCardRepository implements CardRepository {
  final Dio _dio;
  HttpCardRepository() : _dio = DioClient.instance;

  // Buffer temporaire : memory_key -> (bytes, contentType, fileName).
  // Vide apres usage par create(). Survit pas a un kill de l'app, ce
  // qui est l'effet voulu : pas de bytes orphelins.
  final Map<String, _PendingUpload> _pending = {};
  int _seq = 0;

  // -----------------------------------------------------------
  // Parsing : reponse serveur -> domain GameCard.
  // -----------------------------------------------------------
  // Le serveur retourne image_url pre-calcule (selon backend storage).
  // C'est cet URL qu'on stocke dans GameCard.imagePath : CardThumbnail
  // sait dejas afficher http(s).
  GameCard _parseCard(Map<String, dynamic> j) {
    return GameCard(
      id: j['id'] as String,
      gameId: j['game_id'] as String,
      label: j['label'] as String,
      imagePath: (j['image_url'] as String?) ?? '',
      type: CardType.fromDb(j['card_type'] as String?),
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  Result<T> _err<T>(Response r, String fb) {
    final d = r.data is Map<String, dynamic>
        ? (r.data['detail']?.toString() ?? fb)
        : fb;
    return Err(DataFailure('${r.statusCode}: $d'));
  }

  @override
  Future<Result<List<GameCard>>> listByGame(String gameId) async {
    try {
      final res = await _dio.get<List<dynamic>>('/api/games/$gameId/cards');
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Liste cartes indisponible');
      }
      return Ok(
        res.data!.cast<Map<String, dynamic>>().map(_parseCard).toList(),
      );
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<String>> uploadImage({
    required String gameId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // Pas d'upload reseau ici : on bufferise. L'upload reel se fait
    // dans create() une fois qu'on a aussi label + type.
    _seq += 1;
    final key = 'memory://upload-$_seq';
    _pending[key] = _PendingUpload(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      gameId: gameId,
    );
    return Ok(key);
  }

  @override
  Future<Result<GameCard>> create({
    required String gameId,
    required String label,
    required String imagePath,
    required CardType type,
  }) async {
    // Le imagePath peut etre :
    //   - "memory://upload-N"  -> on a des bytes a uploader
    //   - autre                -> impossible cote backend (multipart only)
    final pending = _pending.remove(imagePath);
    if (pending == null) {
      return const Err(DataFailure(
        'Pour ce backend, image obligatoire via uploadImage() prealable',
      ));
    }

    // Garde-fou de coherence : les bytes ont ete bufferises POUR un
    // jeu donne. Si create() est appele avec un autre gameId, c'est
    // un bug d'appelant -- l'image partirait dans le mauvais jeu, et
    // personne ne s'en apercevrait avant de voir une carte etrangere
    // apparaitre dans une partie. On refuse plutot que d'obeir.
    if (pending.gameId != gameId) {
      return Err(DataFailure(
        'Incoherence interne : image bufferisee pour le jeu '
        '${pending.gameId}, creation demandee pour $gameId',
      ));
    }
    try {
      final form = FormData.fromMap({
        'label': label,
        'card_type': type.dbKey,
        'file': MultipartFile.fromBytes(
          pending.bytes,
          filename: pending.fileName,
          contentType: DioMediaType.parse(pending.contentType),
        ),
      });
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/games/$gameId/cards',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (res.statusCode != 201 || res.data == null) {
        return _err(res, 'Upload carte echoue');
      }
      return Ok(_parseCard(res.data!));
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<GameCard>> update({
    required String id,
    String? label,
    CardType? type,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (label != null) body['label'] = label;
      if (type != null) body['card_type'] = type.dbKey;
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/cards/$id',
        data: body,
      );
      if (res.statusCode != 200 || res.data == null) {
        return _err(res, 'Update carte echoue');
      }
      return Ok(_parseCard(res.data!));
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }

  @override
  Future<Result<void>> delete({
    required String id,
    required String imagePath,
  }) async {
    try {
      final res = await _dio.delete('/api/cards/$id');
      if (res.statusCode != 204) {
        return _err(res, 'Suppression carte echouee');
      }
      return const Ok<void>(null);
    } on DioException catch (e) {
      return Err(DataFailure('Erreur reseau : ${e.message}'));
    }
  }
}

class _PendingUpload {
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final String gameId;
  _PendingUpload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.gameId,
  });
}
