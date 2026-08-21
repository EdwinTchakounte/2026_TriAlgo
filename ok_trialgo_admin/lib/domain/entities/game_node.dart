// =============================================================
// FICHIER : game_node.dart (entite domain)
// ROLE    : Modeliser un noeud (trio) dans le graphe d'un jeu
// =============================================================
//
// Un noeud est UNE relation entre 3 cartes :
//
//   emettrice + cable  =>  receptrice
//
// Et il peut avoir un parent (chainage).
//
//   - depth = 1 : noeud racine. parentNodeId = null. emettriceId
//                 est forcement renseigne explicitement.
//   - depth >= 2 : noeud enfant. parentNodeId pointe vers le parent.
//                  emettriceId peut etre NULL : dans ce cas elle
//                  est DEDUITE -> emettrice = receptrice du parent.
//
// Cette regle (emettrice deduite) est appliquee par le seed et la
// fonction SQL verify_collective_trio. Cote app, on la respecte
// dans le wizard etape 3.
//
// nodeIndex : entier UNIQUE par game. Utilise pour le mode
// collectif (le joueur tape "12" pour valider le trio #12).
// =============================================================

class GameNode {
  final String id;
  final String gameId;
  // Numero d'affichage (unique par game). Le wizard calcule
  // MAX(node_index) + 1 lors de la creation pour assurer
  // l'unicite et garder la sequence visible/dense.
  final int nodeIndex;
  // emettriceId NULL si depth > 1 (deduite du parent).
  final String? emettriceId;
  final String cableId;
  final String receptriceId;
  // parentNodeId NULL si depth = 1 (racine).
  final String? parentNodeId;
  // Profondeur dans l'arbre. CHECK (1..5) cote DB.
  final int depth;
  final DateTime createdAt;

  const GameNode({
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

  // Helper booleen : est-ce un noeud racine ?
  bool get isRoot => depth == 1;
}
