// =============================================================
// FICHIER : lib/data/models/graph_card_model.dart
// ROLE   : Convertir les donnees JSON de Supabase en GraphCardEntity
// COUCHE : Data > Models
// =============================================================
//
// Herite de GraphCardEntity et ajoute :
//   - fromJson() : JSON (Supabase) -> objet Dart
//   - toJson()   : objet Dart -> JSON (Supabase)
//
// FORMAT JSON ATTENDU (depuis la table "cards") :
// {
//   "id": "uuid-001",
//   "label": "Lion",
//   "image_path": "savane/lion_base.webp",
//   "created_at": "2026-04-08T10:00:00Z"
// }
//
// CONVENTION :
//   PostgreSQL : snake_case (image_path)
//   Dart       : camelCase (imagePath)
//   La conversion se fait ici dans fromJson/toJson.
// =============================================================

import 'package:trialgo/domain/entities/graph_card_entity.dart';

/// Model de carte : [GraphCardEntity] + conversion JSON.
///
/// Utilise par la couche Data pour convertir les reponses Supabase
/// en objets Dart et inversement.
class GraphCardModel extends GraphCardEntity {

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Transmet tous les parametres au constructeur parent via "super".
  // =============================================================

  /// Constructeur principal. Transmet tout a [GraphCardEntity].
  const GraphCardModel({
    required super.id,
    required super.label,
    required super.imagePath,
  });

  // =============================================================
  // FACTORY : fromJson
  // =============================================================
  // Cree un GraphCardModel depuis un Map JSON retourne par Supabase.
  //
  // Tres simple car la table "cards" n'a que 3 champs utiles
  // (id, label, image_path). Pas d'enum a convertir, pas de
  // listes a transformer.
  // =============================================================

  /// Cree un [GraphCardModel] a partir d'un Map JSON (reponse Supabase).
  ///
  /// [json] : une ligne de la table `cards`.
  ///
  /// Exemple :
  /// ```dart
  /// final data = await supabase.from('cards').select().single();
  /// final card = GraphCardModel.fromJson(data);
  /// ```
  factory GraphCardModel.fromJson(Map<String, dynamic> json) {
    return GraphCardModel(
      // 'id' : UUID de la carte, retourne comme String par Supabase.
      id: json['id'] as String,

      // 'label' : nom descriptif de la carte.
      label: json['label'] as String,

      // 'image_path' : chemin relatif dans Supabase Storage.
      // snake_case (PostgreSQL) -> camelCase (Dart).
      imagePath: json['image_path'] as String,
    );
  }

  // =============================================================
  // METHODE : toJson
  // =============================================================
  // Convertit en Map JSON pour INSERT dans la table "cards".
  // L'id n'est PAS inclus : genere par PostgreSQL automatiquement.
  // =============================================================

  /// Convertit ce [GraphCardModel] en Map JSON pour Supabase.
  ///
  /// Exemple :
  /// ```dart
  /// await supabase.from('cards').insert(card.toJson());
  /// ```
  Map<String, dynamic> toJson() {
    return {
      // Pas d'id : genere par PostgreSQL via gen_random_uuid().
      'label': label,
      'image_path': imagePath,
    };
  }
}
