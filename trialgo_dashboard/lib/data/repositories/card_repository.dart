// =============================================================
// FICHIER : card_repository.dart
// ROLE    : CRUD sur la table "cards" + upload Storage
// =============================================================
//
// Toutes les operations sur les cartes passent par ici :
//   - listAll        : recupere les cartes d'un jeu (avec filtre type)
//   - createCard     : INSERT apres upload image
//   - updateCard     : UPDATE label / type
//   - deleteCard     : DELETE (supprime aussi le fichier Storage)
//   - uploadImage    : envoie un fichier dans le bucket et renvoie l'URL
// =============================================================

import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_config.dart';
import '../models/card.dart';
import '../models/card_type.dart';

class CardRepository {
  final SupabaseClient _client;
  CardRepository(this._client);

  // =========================================================
  // listAll : charge toutes les cartes d'un jeu
  // =========================================================
  // [type] optionnel : si fourni, on filtre cote DB (plus rapide
  // que de tout charger pour filtrer en local).
  // =========================================================
  Future<List<GameCard>> listAll({
    required String gameId,
    CardType? type,
  }) async {
    // PostgREST : .from() ouvre la table, .select() projete les
    // colonnes (toutes par defaut), .eq() filtre.
    var query = _client.from('cards').select().eq('game_id', gameId);

    if (type != null) {
      query = query.eq('card_type', type.dbKey);
    }

    // .order() ajoute un ORDER BY ; ascending: false = DESC.
    // Les cartes les plus recentes apparaissent en premier.
    final rows = await query.order('created_at', ascending: false);

    // PostgREST renvoie List<Map<String, dynamic>>.
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GameCard.fromJson)
        .toList();
  }

  // =========================================================
  // uploadImage : envoie un fichier dans le bucket Storage
  // =========================================================
  // [bytes]  : contenu binaire du fichier (lu depuis XFile.readAsBytes)
  // [originalName] : nom original (pour deduire l'extension)
  //
  // On genere un nom unique pour eviter les collisions (deux admins
  // qui uploadent "lion.jpg" en meme temps ne doivent pas s'ecraser).
  //
  // RLS Storage : seul un admin peut uploader (cf migration 005).
  // =========================================================
  Future<String> uploadImage({
    required Uint8List bytes,
    required String originalName,
    required String contentType,
  }) async {
    // Construit un chemin sans collisions :
    //   "1730487600000_lion.jpg"
    // Le timestamp epoch ms garantit l'unicite cote client.
    final ext = p.extension(originalName).isEmpty ? '.jpg' : p.extension(originalName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final basename = p.basenameWithoutExtension(originalName);
    final safeBase = basename.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath = '${ts}_$safeBase$ext';

    // .storage.from(bucket).uploadBinary() :
    //   - upload du blob
    //   - upsert: false = erreur si le fichier existe (rare avec
    //     un timestamp, mais explicite)
    //   - contentType pour que le navigateur affiche correctement
    //     l'image (image/jpeg, image/png, image/webp)
    await _client.storage.from(SupabaseConfig.cardsBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );

    // L'URL publique est composee, pas signee, donc immediatement
    // utilisable tant que le bucket reste public.
    return _client.storage
        .from(SupabaseConfig.cardsBucket)
        .getPublicUrl(filePath);
  }

  // =========================================================
  // createCard : INSERT apres upload reussi
  // =========================================================
  Future<GameCard> createCard({
    required String gameId,
    required String label,
    required String imagePath,
    required CardType type,
  }) async {
    final inserted = await _client
        .from('cards')
        .insert({
          'game_id': gameId,
          'label': label,
          'image_path': imagePath,
          'card_type': type.dbKey,
        })
        // .select() apres .insert() force PostgREST a renvoyer le
        // row insere (avec id et created_at remplis par la DB).
        .select()
        .single();

    return GameCard.fromJson(inserted);
  }

  // =========================================================
  // updateCard : modifie label et/ou type
  // =========================================================
  Future<GameCard> updateCard({
    required String id,
    String? label,
    CardType? type,
  }) async {
    final patch = <String, dynamic>{};
    if (label != null) patch['label'] = label;
    if (type != null) patch['card_type'] = type.dbKey;

    if (patch.isEmpty) {
      throw ArgumentError('updateCard: rien a modifier');
    }

    final updated = await _client
        .from('cards')
        .update(patch)
        .eq('id', id)
        .select()
        .single();

    return GameCard.fromJson(updated);
  }

  // =========================================================
  // deleteCard : supprime la ligne + le fichier Storage
  // =========================================================
  // Attention : si la carte est referencee par un node
  // (emettrice/cable/receptrice), la FK echoue. C'est voulu :
  // on protege l'integrite du graphe. L'admin doit d'abord
  // supprimer les nodes qui utilisent la carte.
  // =========================================================
  Future<void> deleteCard(GameCard card) async {
    // 1. Supprimer la ligne SQL (peut throw si FK violee).
    await _client.from('cards').delete().eq('id', card.id);

    // 2. Supprimer le fichier Storage si l'URL pointe sur notre
    // bucket. Pour les cartes seed (URLs externes loremflickr),
    // on ne touche a rien.
    if (card.imagePath.startsWith(SupabaseConfig.storagePublicBase)) {
      final filename =
          card.imagePath.substring(SupabaseConfig.storagePublicBase.length + 1);
      await _client.storage
          .from(SupabaseConfig.cardsBucket)
          .remove([filename]);
    }
  }
}
