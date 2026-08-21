// =============================================================
// FICHIER : card_repository_impl.dart
// ROLE    : Implementation Supabase de CardRepository
// =============================================================
//
// Ce repo couvre 2 backends Supabase :
//   - la TABLE cards (PostgREST)
//   - le BUCKET Storage trialgo-cards (Supabase Storage)
//
// L'upload se fait via le SDK Storage. On utilise getPublicUrl()
// pour recuperer l'URL accessible sans token (cf bucket public).
// =============================================================

import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/card_type.dart';
import '../../domain/entities/game_card.dart';
import '../../domain/repositories/card_repository.dart';
import '../models/card_model.dart';

class CardRepositoryImpl implements CardRepository {
  final SupabaseClient _client;

  CardRepositoryImpl(this._client);

  static const _table = 'cards';

  // -----------------------------------------------------------
  // listByGame : filtre par game_id + tri par label.
  // -----------------------------------------------------------
  @override
  Future<Result<List<GameCard>>> listByGame(String gameId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('game_id', gameId)
          .order('label', ascending: true);
      final cards = (rows as List)
          .map((r) => CardModel.fromJson(r as Map<String, dynamic>))
          .toList();
      return Ok(cards);
    } catch (e) {
      return Err(DataFailure('Liste cartes impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // create : INSERT row cards + recup ligne complete.
  // -----------------------------------------------------------
  @override
  Future<Result<GameCard>> create({
    required String gameId,
    required String label,
    required String imagePath,
    required CardType type,
  }) async {
    try {
      final row = await _client
          .from(_table)
          .insert(CardModel.toInsert(
            gameId: gameId,
            label: label,
            imagePath: imagePath,
            type: type,
          ))
          .select()
          .single();
      return Ok(CardModel.fromJson(row));
    } catch (e) {
      return Err(DataFailure('Creation carte impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // update : UPDATE label / card_type.
  // -----------------------------------------------------------
  @override
  Future<Result<GameCard>> update({
    required String id,
    String? label,
    CardType? type,
  }) async {
    final patch = CardModel.toUpdate(label: label, type: type);
    if (patch.isEmpty) {
      return const Err(ValidationFailure('Aucun champ a modifier'));
    }
    try {
      final row = await _client
          .from(_table)
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      return Ok(CardModel.fromJson(row));
    } catch (e) {
      return Err(DataFailure('Update carte impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // delete : DELETE row puis best-effort cleanup Storage.
  // On extrait le chemin (apres "/trialgo-cards/") depuis l'URL
  // publique. Si l'URL n'est pas dans le bucket (legacy
  // loremflickr par ex.), on saute le cleanup Storage.
  // -----------------------------------------------------------
  @override
  Future<Result<void>> delete({
    required String id,
    required String imagePath,
  }) async {
    try {
      // 1. Supprimer la row DB.
      await _client.from(_table).delete().eq('id', id);

      // 2. Si l'URL pointe vers notre bucket, on retire aussi
      // le fichier pour eviter les orphelins.
      final prefix = SupabaseConfig.storagePublicBase;
      if (imagePath.startsWith(prefix)) {
        // Chemin relatif au bucket :
        //   {url}/storage/v1/object/public/trialgo-cards/{path}
        //   -> on garde {path}
        final relPath = imagePath.substring(prefix.length + 1);
        // remove() est tolerant : si le fichier n'existe pas,
        // ca log un warning mais ne throw pas.
        await _client.storage.from(SupabaseConfig.cardsBucket).remove([relPath]);
      }
      return const Ok<void>(null);
    } catch (e) {
      return Err(DataFailure('Suppression carte impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // uploadImage : pousse les bytes dans le bucket et renvoie
  // l'URL publique. Le chemin est :
  //   {gameId}/{ts}_{slug}{ext}
  // pour eviter les collisions et organiser visuellement.
  // -----------------------------------------------------------
  @override
  Future<Result<String>> uploadImage({
    required String gameId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      // Verif basique : 5 MB max (le bucket le rejetterait sinon).
      // On previent ici pour un message UX plus clair.
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        return const Err(FileTooLargeFailure());
      }

      // Slug : nom de base sans extension, ASCII safe.
      final ext = p.extension(fileName).toLowerCase();
      final baseRaw = p.basenameWithoutExtension(fileName);
      // Replace : conserve lettres/chiffres/-_ ; reste -> "_"
      final base = baseRaw
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          .toLowerCase();

      // Timestamp ms pour quasi-unicite + lisibilite (tri par
      // ordre alphabetique = ordre chronologique).
      final ts = DateTime.now().millisecondsSinceEpoch;
      final objectPath = '$gameId/${ts}_$base$ext';

      // uploadBinary : envoie les bytes ; contentType important
      // car le bucket valide allowed_mime_types.
      await _client.storage
          .from(SupabaseConfig.cardsBucket)
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      // getPublicUrl renvoie l'URL HTTPS finale, accessible sans
      // auth (le bucket est public, cf migration 005).
      final publicUrl = _client.storage
          .from(SupabaseConfig.cardsBucket)
          .getPublicUrl(objectPath);

      return Ok(publicUrl);
    } catch (e) {
      return Err(StorageFailure('Upload echoue : $e'));
    }
  }
}
