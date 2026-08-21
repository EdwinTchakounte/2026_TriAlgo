// =============================================================
// FICHIER : node.dart
// ROLE    : Modele Dart pour la table SQL "nodes"
// =============================================================
//
// Un "node" est un trio + sa position dans l'arbre du graphe.
// Format typique :
//   D1 (racine) : emettrice + cable + receptrice (parent_id = NULL)
//   D2..D5      : cable + receptrice. L'emettrice effective est
//                 la receptrice du parent (chaine logique).
//
// Pour le dashboard, on charge tous les nodes d'un jeu en une
// requete, puis on les visualise en arbre.
// =============================================================

class GameNode {
  // UUID du node (PK).
  final String id;

  // FK jeu.
  final String gameId;

  // Index lisible humain (1, 2, ..., N) UNIQUE par jeu.
  // C'est ce numero qui apparait dans le mode collectif et sur
  // les cartes physiques imprimees.
  final int nodeIndex;

  // Pour les D1 uniquement : l'emettrice est explicite. Pour les
  // D>=2, c'est NULL : l'emettrice se deduit en remontant la chaine
  // (parent_node_id -> receptrice du parent).
  final String? emettriceId;

  // Carte qui represente la transformation (toujours non null).
  final String cableId;

  // Carte resultat (toujours non null).
  final String receptriceId;

  // Pour D>=2 : pointe vers le node parent (D1 du meme arbre).
  // Pour D=1 : NULL.
  final String? parentNodeId;

  // Profondeur dans l'arbre (1 a 5).
  final int depth;

  // Date de creation.
  final DateTime createdAt;

  GameNode({
    required this.id,
    required this.gameId,
    required this.nodeIndex,
    required this.emettriceId,
    required this.cableId,
    required this.receptriceId,
    required this.parentNodeId,
    required this.depth,
    required this.createdAt,
  });

  factory GameNode.fromJson(Map<String, dynamic> json) {
    return GameNode(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      nodeIndex: json['node_index'] as int,
      // Les colonnes nullables peuvent etre absentes : on cast en
      // String? pour gerer null sans NullPointerException.
      emettriceId: json['emettrice_id'] as String?,
      cableId: json['cable_id'] as String,
      receptriceId: json['receptrice_id'] as String,
      parentNodeId: json['parent_node_id'] as String?,
      depth: json['depth'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Pour creer un nouveau node depuis le dashboard.
  // node_index doit etre calcule cote client : on prend MAX+1
  // pour le jeu courant.
  Map<String, dynamic> toInsertJson() {
    return {
      'game_id': gameId,
      'node_index': nodeIndex,
      'emettrice_id': emettriceId,
      'cable_id': cableId,
      'receptrice_id': receptriceId,
      'parent_node_id': parentNodeId,
      'depth': depth,
    };
  }
}
