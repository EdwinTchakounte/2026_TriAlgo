// =============================================================
// FICHIER : lib/data/models/card_trio_model.dart
// ROLE   : Convertir les donnees JSON de Supabase en CardTrioEntity
// COUCHE : Data > Models
// =============================================================
//
// Meme principe que CardModel :
//   - Herite de CardTrioEntity (couche Domain)
//   - Ajoute fromJson() et toJson()
//   - Fait le pont entre le format JSON de Supabase et les objets Dart
//
// FORMAT JSON ATTENDU :
// {
//   "id": "uuid-trio-001",
//   "emettrice_id": "uuid-emettrice-001",
//   "cable_id": "uuid-cable-001",
//   "receptrice_id": "uuid-receptrice-001",
//   "distance_level": 1,
//   "parent_trio_id": null,
//   "difficulty": 0.5
// }
//
// REFERENCE : Recueil de conception v3.0, section 3.3
// =============================================================

import 'package:trialgo/domain/entities/card_trio_entity.dart';

/// Model de trio : [CardTrioEntity] + conversion JSON.
///
/// Herite de [CardTrioEntity] et ajoute la serialisation/deserialisation.
class CardTrioModel extends CardTrioEntity {

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Transmet tous les parametres au constructeur parent via "super".
  // Meme logique que CardModel.
  // =============================================================

  /// Constructeur principal. Transmet tout a [CardTrioEntity].
  const CardTrioModel({
    required super.id,              // -> CardTrioEntity.id
    required super.emettriceId,     // -> CardTrioEntity.emettriceId
    required super.cableId,         // -> CardTrioEntity.cableId
    required super.receptriceId,    // -> CardTrioEntity.receptriceId
    required super.distanceLevel,   // -> CardTrioEntity.distanceLevel
    super.parentTrioId,             // -> CardTrioEntity.parentTrioId (null)
    super.difficulty,               // -> CardTrioEntity.difficulty (0.5)
  });

  // =============================================================
  // FACTORY : fromJson
  // =============================================================
  // Cree un CardTrioModel depuis un Map JSON retourne par Supabase.
  //
  // Plus simple que CardModel.fromJson car :
  //   - Pas d'enum a convertir (tous les champs sont des types simples)
  //   - Pas de List<dynamic> a convertir
  //   - Moins de champs
  // =============================================================

  /// Cree un [CardTrioModel] a partir d'un Map JSON (reponse Supabase).
  ///
  /// [json] : une ligne de la table `card_trios` retournee par Supabase.
  ///
  /// Exemple :
  /// ```dart
  /// final data = await supabase.from('card_trios').select().single();
  /// final trio = CardTrioModel.fromJson(data);
  /// ```
  factory CardTrioModel.fromJson(Map<String, dynamic> json) {
    return CardTrioModel(
      // -------------------------------------------------------
      // id : UUID du trio
      // -------------------------------------------------------
      // json['id'] retourne un dynamic.
      // Dart le cast implicitement en String (type attendu).
      // -------------------------------------------------------
      id: json['id'],

      // -------------------------------------------------------
      // emettriceId : UUID de la carte Emettrice du trio
      // -------------------------------------------------------
      // Cle JSON : 'emettrice_id' (snake_case PostgreSQL)
      // Propriete Dart : emettriceId (camelCase Dart)
      // -------------------------------------------------------
      emettriceId: json['emettrice_id'],

      // -------------------------------------------------------
      // cableId : UUID de la carte Cable du trio
      // -------------------------------------------------------
      cableId: json['cable_id'],

      // -------------------------------------------------------
      // receptriceId : UUID de la carte Receptrice du trio
      // -------------------------------------------------------
      receptriceId: json['receptrice_id'],

      // -------------------------------------------------------
      // distanceLevel : 1, 2 ou 3
      // -------------------------------------------------------
      // Supabase retourne un int, pas de conversion necessaire.
      // -------------------------------------------------------
      distanceLevel: json['distance_level'],

      // -------------------------------------------------------
      // parentTrioId : UUID du trio parent (ou null si D1)
      // -------------------------------------------------------
      // Nullable : null pour les trios D1 (pas de parent).
      // UUID pour les trios D2 (pointe vers D1) et D3 (pointe vers D2).
      // -------------------------------------------------------
      parentTrioId: json['parent_trio_id'],

      // -------------------------------------------------------
      // difficulty : score de difficulte du trio
      // -------------------------------------------------------
      // Meme logique que difficultyScore dans CardModel :
      //   - ?? 0.5 : valeur par defaut si null
      //   - .toDouble() : convertit int en double si necessaire
      // -------------------------------------------------------
      difficulty: (json['difficulty'] ?? 0.5).toDouble(),
    );
  }

  // =============================================================
  // METHODE : toJson
  // =============================================================
  // Convertit en Map JSON pour INSERT dans card_trios.
  //
  // Utilisation :
  //   await supabase.from('card_trios').insert(trio.toJson());
  // =============================================================

  /// Convertit ce [CardTrioModel] en Map JSON pour Supabase.
  Map<String, dynamic> toJson() {
    return {
      // Pas d'id : genere par PostgreSQL via gen_random_uuid()
      'emettrice_id': emettriceId,
      'cable_id': cableId,
      'receptrice_id': receptriceId,
      'distance_level': distanceLevel,
      'parent_trio_id': parentTrioId,   // null si D1
      'difficulty': difficulty,
    };
  }
}
