// =============================================================
// FICHIER : lib/domain/usecases/build_graph_usecase.dart
// ROLE   : Construire le graphe de jeu en memoire locale
// COUCHE : Domain > Usecases
// =============================================================
//
// CE QUE FAIT CE USECASE :
// ------------------------
// 1. Recoit la liste brute des noeuds (depuis la synchro Supabase)
// 2. Construit un arbre en memoire (Map index -> noeud)
// 3. Resout les emettrices des noeuds enfants
//    (enfant.E = parent.R)
// 4. Retourne le graphe pret a etre utilise par le jeu
//
// QUAND EST-IL APPELE ?
// ---------------------
// Au lancement du jeu, APRES la synchronisation des donnees :
//   1. Synchro : telecharger cards + nodes depuis Supabase
//   2. BuildGraph : construire le graphe en memoire
//   3. Le jeu peut commencer (tout est local)
//
// LE GRAPHE N'EST PAS UN ARBRE CLASSIQUE.
// ----------------------------------------
// On ne construit pas une structure arborescente avec des pointeurs.
// On utilise un Map<int, GraphNodeEntity> indexe par nodeIndex.
// Le lien parent-enfant est resolu en copiant parent.receptriceId
// dans enfant.resolvedEmettriceId.
//
// Apres la construction, chaque noeud a :
//   - effectiveEmettriceId : l'ID de son emettrice (stockee ou resolue)
//   - cableId              : l'ID de son cable
//   - receptriceId         : l'ID de sa receptrice
//
// Le jeu peut ensuite acceder a n'importe quel noeud par index
// et obtenir ses 3 cartes immediatement, sans requete ni calcul.
//
// REFERENCE : Discussion architecture graphe, avril 2026
// =============================================================

import 'package:trialgo/domain/entities/graph_node_entity.dart';

/// Resultat de la construction du graphe.
///
/// Contient le graphe indexe par nodeIndex et les noeuds
/// organises par profondeur pour un acces rapide.
class GameGraph {

  // =============================================================
  // PROPRIETE : nodesByIndex
  // =============================================================
  // Map de TOUS les noeuds, indexes par leur nodeIndex.
  //
  // Map<int, GraphNodeEntity> :
  //   - Cle   : nodeIndex (1, 2, ... 50)
  //   - Valeur : le noeud complet avec emettrice resolue
  //
  // Acces en O(1) : nodesByIndex[16] retourne le noeud N16
  // directement, sans parcourir une liste.
  // =============================================================

  /// Tous les noeuds indexes par leur nodeIndex.
  final Map<int, GraphNodeEntity> nodesByIndex;

  // =============================================================
  // PROPRIETE : nodesByDepth
  // =============================================================
  // Les noeuds regroupes par profondeur.
  //
  // Map<int, List<GraphNodeEntity>> :
  //   - Cle   : profondeur (1, 2 ou 3)
  //   - Valeur : liste des noeuds a cette profondeur
  //
  // Utilite : quand le jeu veut un noeud de profondeur 1,
  // il prend nodesByDepth[1] et en choisit un au hasard.
  // =============================================================

  /// Les noeuds regroupes par profondeur (1, 2 ou 3).
  final Map<int, List<GraphNodeEntity>> nodesByDepth;

  // =============================================================
  // PROPRIETE : childrenOf
  // =============================================================
  // Pour chaque noeud parent, la liste de ses enfants directs.
  //
  // Map<int, List<GraphNodeEntity>> :
  //   - Cle   : nodeIndex du PARENT
  //   - Valeur : liste des noeuds enfants
  //
  // Utilite : construire les noeuds logiques de distance 2.
  // Pour le noeud N01, childrenOf[1] retourne [N16, N17, ...]
  // =============================================================

  /// Les enfants directs de chaque noeud, indexes par nodeIndex du parent.
  final Map<int, List<GraphNodeEntity>> childrenOf;

  /// Cree un graphe de jeu.
  const GameGraph({
    required this.nodesByIndex,
    required this.nodesByDepth,
    required this.childrenOf,
  });

  // =============================================================
  // GETTER : totalNodes
  // =============================================================
  // Nombre total de noeuds dans le graphe.
  // Utile pour les statistiques et la validation.
  // =============================================================

  /// Nombre total de noeuds dans le graphe.
  int get totalNodes => nodesByIndex.length;

  // =============================================================
  // GETTER : rootNodes
  // =============================================================
  // Raccourci pour acceder aux noeuds racines (profondeur 1).
  // Retourne une liste vide si aucun noeud racine.
  // =============================================================

  /// Les noeuds racines (profondeur 1).
  List<GraphNodeEntity> get rootNodes => nodesByDepth[1] ?? [];

  // =============================================================
  // METHODE : getNode
  // =============================================================
  // Recupere un noeud par son index.
  // Retourne null si l'index n'existe pas dans le graphe.
  // =============================================================

  /// Recupere un noeud par son [index]. Null si inexistant.
  GraphNodeEntity? getNode(int index) => nodesByIndex[index];

  // =============================================================
  // METHODE : getChain
  // =============================================================
  // Remonte la chaine parent -> grand-parent -> ... depuis un noeud.
  // Retourne la liste ordonnee du noeud racine jusqu'au noeud demande.
  //
  // Exemple pour N36 (profondeur 3) :
  //   getChain(36) -> [N01, N16, N36]
  //   Le noeud racine est en premier, le noeud demande en dernier.
  //
  // Utilite : pour la distance 2, le jeu appelle getChain sur un
  // noeud de profondeur 2 et obtient [parent, enfant].
  // Pour la distance 3 : [grand-parent, parent, enfant].
  // =============================================================

  /// Remonte la chaine de parents depuis le noeud [index].
  ///
  /// Retourne la liste ordonnee du noeud racine au noeud demande.
  /// Exemple : getChain(36) -> [N01, N16, N36]
  ///
  /// Retourne une liste vide si le noeud n'existe pas.
  List<GraphNodeEntity> getChain(int index) {
    final chain = <GraphNodeEntity>[];
    var current = nodesByIndex[index];

    while (current != null) {
      chain.insert(0, current);

      if (current.parentNodeId != null) {
        current = nodesByIndex.values.cast<GraphNodeEntity?>().firstWhere(
          (n) => n?.id == current!.parentNodeId,
          orElse: () => null,
        );
      } else {
        current = null;
      }
    }

    return chain;
  }

  // =============================================================
  // METHODE : allChainsOfLength
  // =============================================================
  // Retourne toutes les chaines de k noeuds consecutifs dans le
  // graphe. Chaque chaine est une liste [racine, ..., feuille] de k
  // noeuds ou chaque element i est parent de l'element i+1.
  //
  // UTILISATION :
  //   - k=1 : retourne tous les noeuds individuels
  //   - k=2 : retourne toutes les paires parent-enfant
  //   - k=3 : retourne toutes les chaines grand-parent → parent → enfant
  //   - k=4 : chaines de 4 noeuds
  //   - k=5 : chaines de 5 noeuds
  //
  // ALGORITHME :
  //   Pour chaque noeud N de profondeur >= k :
  //     reconstruire sa chaine vers les racines (getChain)
  //     si la longueur totale >= k :
  //       prendre les k dernieres positions comme chaine de longueur k
  //
  // Si le graphe a une profondeur max < k, retourne une liste vide.
  // =============================================================

  /// Retourne toutes les chaines continues de [k] noeuds consecutifs.
  ///
  /// Une chaine est une liste ordonnee `[n1, n2, ..., nk]` telle que
  /// `n_{i+1}.parent == n_i`. Le dernier noeud est la "feuille" de
  /// la chaine, le premier est la "racine" (pas necessairement une
  /// racine absolue du graphe, juste le debut de la chaine).
  List<List<GraphNodeEntity>> allChainsOfLength(int k) {
    if (k < 1) return [];

    // Pour k=1 : chaque noeud est sa propre chaine de longueur 1.
    if (k == 1) {
      return nodesByIndex.values.map((n) => [n]).toList();
    }

    // Pour k >= 2 : on itere sur tous les noeuds qui peuvent etre la
    // "feuille" d'une chaine de longueur k. Un noeud peut etre feuille
    // d'une chaine de k noeuds s'il a AU MOINS k-1 ancetres (parents
    // successifs), donc si son chemin vers la racine est >= k-1.
    final result = <List<GraphNodeEntity>>[];

    for (final node in nodesByIndex.values) {
      final chain = getChain(node.nodeIndex);
      if (chain.length >= k) {
        // Prendre les k derniers elements de la chaine (les plus proches
        // de la feuille). Ca produit une chaine de k noeuds consecutifs.
        final subChain = chain.sublist(chain.length - k);
        result.add(subChain);
      }
    }

    return result;
  }
}


/// Usecase : construit le graphe de jeu en memoire locale.
///
/// Prend la liste brute des noeuds (depuis Supabase) et produit
/// un [GameGraph] pret a etre utilise par le jeu.
///
/// Etapes :
/// 1. Indexer les noeuds par nodeIndex
/// 2. Resoudre les emettrices des noeuds enfants
/// 3. Regrouper par profondeur
/// 4. Construire les listes d'enfants
class BuildGraphUseCase {

  // =============================================================
  // METHODE : call
  // =============================================================
  // Methode principale. Construit le graphe complet.
  //
  // [nodes] : la liste brute des noeuds telecharges depuis Supabase.
  //           Doit etre triee par node_index (les parents avant
  //           les enfants) pour que la resolution fonctionne.
  //
  // Retour : un GameGraph pret a l'emploi.
  //
  // Cette methode est SYNCHRONE (pas de Future, pas d'await).
  // Toutes les donnees sont deja en memoire.
  // =============================================================

  /// Construit le graphe de jeu a partir de la liste des noeuds.
  ///
  /// [nodes] : les noeuds telecharges depuis Supabase, tries par index.
  ///
  /// Retourne un [GameGraph] avec les emettrices resolues et les
  /// noeuds organises par profondeur et par parent.
  GameGraph call(List<GraphNodeEntity> nodes) {

    // --- ETAPE 1 : Indexer les noeuds par nodeIndex ---
    // On cree un Map pour un acces O(1) par index.
    //
    // "Map<int, GraphNodeEntity>" :
    //   Cle = nodeIndex (1, 2, ... 50)
    //   Valeur = le noeud
    //
    // "{}" : cree un Map vide.
    // "for (final node in nodes)" : parcourt chaque noeud.
    // "map[node.nodeIndex] = node" : ajoute l'entree au Map.
    final Map<int, GraphNodeEntity> nodesByIndex = {};
    for (final node in nodes) {
      nodesByIndex[node.nodeIndex] = node;
    }

    // --- ETAPE 2 : Creer un index par UUID ---
    // Le parentNodeId est un UUID, pas un nodeIndex.
    // On a besoin d'un Map UUID -> noeud pour resoudre les parents.
    //
    // "Map<String, GraphNodeEntity>" :
    //   Cle = UUID du noeud
    //   Valeur = le noeud
    final Map<String, GraphNodeEntity> nodesById = {};
    for (final node in nodes) {
      nodesById[node.id] = node;
    }

    // --- ETAPE 3 : Resoudre les emettrices des enfants ---
    // Pour chaque noeud enfant (depth > 1), on copie la receptriceId
    // du parent dans resolvedEmettriceId.
    //
    // PREREQUIS : les noeuds sont tries par index. Les parents
    // (index plus petit) sont traites AVANT leurs enfants.
    // Cela garantit que parent.receptriceId est disponible.
    for (final node in nodes) {
      // Si le noeud a un parent, resoudre son emettrice.
      if (node.parentNodeId != null) {
        // Trouver le parent par son UUID.
        final parent = nodesById[node.parentNodeId];
        if (parent != null) {
          // enfant.emettrice = parent.receptrice
          node.resolveEmettrice(parent.receptriceId);
        }
      }
    }

    // --- ETAPE 4 : Regrouper par profondeur ---
    // On cree un Map profondeur -> liste de noeuds.
    //
    // "Map<int, List<GraphNodeEntity>>" :
    //   Cle = profondeur (1, 2 ou 3)
    //   Valeur = liste des noeuds a cette profondeur
    //
    // "putIfAbsent(depth, () => [])" :
    //   Si la cle n'existe pas encore, cree une liste vide.
    //   Retourne la liste existante ou nouvellement creee.
    //   Puis ".add(node)" ajoute le noeud a cette liste.
    final Map<int, List<GraphNodeEntity>> nodesByDepth = {};
    for (final node in nodes) {
      nodesByDepth.putIfAbsent(node.depth, () => []).add(node);
    }

    // --- ETAPE 5 : Construire les listes d'enfants ---
    // Pour chaque noeud parent, on liste ses enfants directs.
    //
    // Map<int, List<GraphNodeEntity>> :
    //   Cle = nodeIndex du PARENT
    //   Valeur = liste des enfants
    //
    // On parcourt tous les noeuds. Si un noeud a un parent,
    // on l'ajoute a la liste des enfants de ce parent.
    final Map<int, List<GraphNodeEntity>> childrenOf = {};
    for (final node in nodes) {
      if (node.parentNodeId != null) {
        // Trouver le parent pour obtenir son nodeIndex.
        final parent = nodesById[node.parentNodeId];
        if (parent != null) {
          childrenOf
              .putIfAbsent(parent.nodeIndex, () => [])
              .add(node);
        }
      }
    }

    // --- ETAPE 6 : Retourner le graphe complet ---
    return GameGraph(
      nodesByIndex: nodesByIndex,
      nodesByDepth: nodesByDepth,
      childrenOf: childrenOf,
    );
  }
}
