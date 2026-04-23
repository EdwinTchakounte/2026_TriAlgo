// =============================================================
// FICHIER : lib/data/models/graph_node_model.dart
// ROLE   : Convertir les donnees JSON de Supabase en GraphNodeEntity
// COUCHE : Data > Models
// =============================================================
//
// Herite de GraphNodeEntity et ajoute :
//   - fromJson() : JSON (Supabase) -> objet Dart
//   - toJson()   : objet Dart -> JSON (Supabase)
//
// FORMAT JSON ATTENDU (depuis la table "nodes") :
// {
//   "id": "uuid-node-001",
//   "node_index": 1,
//   "emettrice_id": "uuid-card-001",    <- null si enfant
//   "cable_id": "uuid-card-002",
//   "receptrice_id": "uuid-card-003",
//   "parent_node_id": null,             <- null si racine
//   "depth": 1,
//   "created_at": "2026-04-08T10:00:00Z"
// }
//
// CONVENTION :
//   PostgreSQL : snake_case (node_index, emettrice_id)
//   Dart       : camelCase (nodeIndex, emettriceId)
// =============================================================

import 'package:trialgo/domain/entities/graph_node_entity.dart';

/// Model de noeud : [GraphNodeEntity] + conversion JSON.
///
/// Utilise par la couche Data pour convertir les reponses Supabase
/// en objets Dart et inversement.
class GraphNodeModel extends GraphNodeEntity {

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Transmet tous les parametres au constructeur parent via "super".
  // Pas "const" car GraphNodeEntity a un champ mutable
  // (resolvedEmettriceId).
  // =============================================================

  /// Constructeur principal. Transmet tout a [GraphNodeEntity].
  GraphNodeModel({
    required super.id,
    required super.nodeIndex,
    super.emettriceId,
    required super.cableId,
    required super.receptriceId,
    super.parentNodeId,
    required super.depth,
  });

  // =============================================================
  // FACTORY : fromJson
  // =============================================================
  // Cree un GraphNodeModel depuis un Map JSON retourne par Supabase.
  //
  // Points d'attention :
  //   - emettrice_id peut etre null (noeuds enfants)
  //   - parent_node_id peut etre null (noeuds racines)
  //   - node_index est un int (pas de conversion necessaire)
  //   - depth est un int (pas de conversion necessaire)
  // =============================================================

  /// Cree un [GraphNodeModel] a partir d'un Map JSON (reponse Supabase).
  ///
  /// [json] : une ligne de la table `nodes`.
  ///
  /// Exemple :
  /// ```dart
  /// final data = await supabase.from('nodes').select();
  /// final nodes = data.map((j) => GraphNodeModel.fromJson(j)).toList();
  /// ```
  factory GraphNodeModel.fromJson(Map<String, dynamic> json) {
    return GraphNodeModel(
      // 'id' : UUID du noeud.
      id: json['id'] as String,

      // 'node_index' : index numerique unique (1 a 50).
      // Supabase retourne un int, pas de conversion necessaire.
      nodeIndex: json['node_index'] as int,

      // 'emettrice_id' : UUID de la carte Emettrice.
      // Peut etre null pour les noeuds enfants (depth > 1).
      // "as String?" : cast en String nullable.
      emettriceId: json['emettrice_id'] as String?,

      // 'cable_id' : UUID de la carte Cable. Toujours renseigne.
      cableId: json['cable_id'] as String,

      // 'receptrice_id' : UUID de la carte Receptrice. Toujours renseigne.
      receptriceId: json['receptrice_id'] as String,

      // 'parent_node_id' : UUID du noeud parent.
      // Null pour les racines (depth = 1).
      parentNodeId: json['parent_node_id'] as String?,

      // 'depth' : profondeur dans l'arbre (1, 2 ou 3).
      depth: json['depth'] as int,
    );
  }

  // =============================================================
  // METHODE : toJson
  // =============================================================
  // Convertit en Map JSON pour INSERT dans la table "nodes".
  // L'id n'est PAS inclus : genere par PostgreSQL automatiquement.
  //
  // IMPORTANT : emettrice_id est inclus meme s'il est null.
  // PostgreSQL accepte les valeurs NULL pour les colonnes nullable.
  // =============================================================

  /// Convertit ce [GraphNodeModel] en Map JSON pour Supabase.
  ///
  /// Exemple :
  /// ```dart
  /// await supabase.from('nodes').insert(node.toJson());
  /// ```
  Map<String, dynamic> toJson() {
    return {
      // Pas d'id : genere par PostgreSQL via gen_random_uuid().
      'node_index': nodeIndex,
      'emettrice_id': emettriceId,       // null si enfant
      'cable_id': cableId,
      'receptrice_id': receptriceId,
      'parent_node_id': parentNodeId,    // null si racine
      'depth': depth,
    };
  }
}
