// =============================================================
// FICHIER : fusion_analyzer.dart
// ROLE    : Analyser si 3 cartes choisies sont liees dans l'arbre
// =============================================================
//
// Modele mental TRIALGO :
//   fuse(A, B) = C  (operation deterministe + injective)
//
// L'utilisateur picke 3 cartes ; le service determine s'il
// existe une RELATION entre elles dans le graphe de fusions
// du jeu courant. Trois reponses possibles :
//
//   1. directLink  : les 3 cartes forment exactement UNE fusion
//                    -> il existe un noeud N tel que
//                       {N.A, N.B, N.C} == {carte1, carte2, carte3}
//                    (ordre des roles indifferent pour le test)
//
//   2. chainedLink : les 3 cartes se trouvent dans 2 fusions
//                    successives liees par chainage parent-enfant
//                    -> il existe N1 et N2 tels que N2.parent = N1
//                       et l'union des cartes de {N1, N2} contient
//                       les 3 cartes choisies
//                    (typique : on selectionne A, B et le produit
//                    final d'une chaine D2)
//
//   3. noLink      : aucune des deux conditions n'est verifiee
//
// On retourne aussi les noeuds impliques pour que l'UI puisse
// afficher des references comme "Fusion #4 (D2)".
//
// Le service est PUR (pas d'IO, pas de Riverpod) : il prend ses
// inputs en arguments et retourne un objet. Testable et
// reutilisable hors UI.
// =============================================================

import '../entities/game_card.dart';
import '../entities/game_node.dart';

enum FusionAnalysisKind { directLink, chainedLink, noLink }

class FusionAnalysisResult {
  final FusionAnalysisKind kind;
  // Noeuds impliques dans la liaison trouvee.
  //   - directLink  : 1 element (la fusion qui contient les 3 cartes)
  //   - chainedLink : 2 elements (parent en [0], enfant en [1])
  //   - noLink      : liste vide
  final List<GameNode> involvedNodes;
  // Message court "humain" pret a afficher (ex: "Fusion directe #4 D2").
  final String summary;
  // Detail complementaire (ex: "Lion + Riviere = Gazelle").
  final String? detail;

  const FusionAnalysisResult({
    required this.kind,
    required this.involvedNodes,
    required this.summary,
    this.detail,
  });
}

class FusionAnalyzer {
  FusionAnalyzer._(); // pas d'instance, methodes statiques

  // -----------------------------------------------------------
  // POINT D'ENTREE PUBLIC
  // -----------------------------------------------------------
  // Analyse une selection de 3 cartes. Si la selection n'est pas
  // valide (moins de 3 cartes, ou doublons) on renvoie un noLink
  // documente. Sinon on cherche d'abord une fusion directe (cas
  // le plus simple), puis un chainage (cas plus elabore).
  static FusionAnalysisResult analyze({
    required List<GameCard> selectedCards,
    required List<GameNode> nodes,
    required List<GameCard> allCards,
  }) {
    // Garde-fous d'entree.
    if (selectedCards.length != 3) {
      return const FusionAnalysisResult(
        kind: FusionAnalysisKind.noLink,
        involvedNodes: [],
        summary: 'Selectionnez exactement 3 cartes',
      );
    }
    final ids = selectedCards.map((c) => c.id).toSet();
    if (ids.length != 3) {
      return const FusionAnalysisResult(
        kind: FusionAnalysisKind.noLink,
        involvedNodes: [],
        summary: 'Les cartes doivent etre distinctes',
      );
    }

    // ---- CAS 1 : fusion directe ----
    final direct = _findDirectLink(ids, nodes);
    if (direct != null) {
      final detail = _describeNode(direct, allCards);
      return FusionAnalysisResult(
        kind: FusionAnalysisKind.directLink,
        involvedNodes: [direct],
        summary: 'Fusion directe trouvee : #${direct.nodeIndex} (D${direct.depth})',
        detail: detail,
      );
    }

    // ---- CAS 2 : chainage parent <-> enfant ----
    final chain = _findChainedLink(ids, nodes);
    if (chain != null) {
      final parent = chain.$1;
      final child = chain.$2;
      final detail =
          '${_describeNode(parent, allCards)}\nchaine vers\n${_describeNode(child, allCards)}';
      return FusionAnalysisResult(
        kind: FusionAnalysisKind.chainedLink,
        involvedNodes: [parent, child],
        summary:
            'Chainage trouve : #${parent.nodeIndex} (D${parent.depth}) -> #${child.nodeIndex} (D${child.depth})',
        detail: detail,
      );
    }

    // ---- CAS 3 : rien ----
    return const FusionAnalysisResult(
      kind: FusionAnalysisKind.noLink,
      involvedNodes: [],
      summary: 'Ces 3 cartes ne sont pas liees dans cet arbre',
      detail:
          'Aucune fusion ne contient ces 3 cartes, et aucun chainage parent-enfant ne les couvre toutes les 3.',
    );
  }

  // -----------------------------------------------------------
  // CAS 1 : chercher un noeud dont les 3 ids de cartes egalent
  // la selection. emettriceId peut etre NULL (noeud enfant ou
  // l'ingredient A est deduit du parent) : dans ce cas on substitue
  // par la receptriceId du parent pour reconstituer l'equation
  // complete.
  // -----------------------------------------------------------
  static GameNode? _findDirectLink(Set<String> selectedIds, List<GameNode> nodes) {
    for (final n in nodes) {
      final aId = _effectiveEmettriceId(n, nodes);
      if (aId == null) continue;
      final nodeIds = {aId, n.cableId, n.receptriceId};
      if (nodeIds.length == 3 && nodeIds.containsAll(selectedIds)) {
        return n;
      }
    }
    return null;
  }

  // -----------------------------------------------------------
  // CAS 2 : pour chaque couple (parent, enfant) lie par parentNodeId,
  // calculer l'union des cartes des deux noeuds et tester si elle
  // contient la selection. On retourne (parent, child) du premier
  // couple matchant.
  //
  // Pourquoi "contient" et pas "egal" ? Parce qu'une chaine D2
  // implique 4 cartes au total (A1, B1, R1, B2, R2) mais R1 est
  // partagee. Donc l'union peut avoir 4 elements pour 2 fusions ;
  // on cherche si nos 3 cartes y sont incluses.
  // -----------------------------------------------------------
  static (GameNode, GameNode)? _findChainedLink(
      Set<String> selectedIds, List<GameNode> nodes) {
    for (final child in nodes) {
      if (child.parentNodeId == null) continue;
      GameNode? parent;
      for (final p in nodes) {
        if (p.id == child.parentNodeId) {
          parent = p;
          break;
        }
      }
      if (parent == null) continue;
      final union = <String>{
        _effectiveEmettriceId(parent, nodes) ?? '',
        parent.cableId,
        parent.receptriceId,
        _effectiveEmettriceId(child, nodes) ?? '',
        child.cableId,
        child.receptriceId,
      }..remove('');
      if (selectedIds.every(union.contains)) {
        return (parent, child);
      }
    }
    return null;
  }

  // -----------------------------------------------------------
  // Helper : recupere l'ingredient A effectif d'un noeud.
  // - Si emettriceId est non null -> direct.
  // - Sinon (noeud enfant) -> on remonte au parent et on prend
  //   sa receptriceId (le produit qui est devenu ingredient A).
  // - Si pas trouve (parent supprime ou orphelin) -> null.
  // -----------------------------------------------------------
  static String? _effectiveEmettriceId(GameNode node, List<GameNode> nodes) {
    if (node.emettriceId != null) return node.emettriceId;
    if (node.parentNodeId == null) return null;
    for (final p in nodes) {
      if (p.id == node.parentNodeId) return p.receptriceId;
    }
    return null;
  }

  // -----------------------------------------------------------
  // Helper : construit une description humaine d'une fusion.
  // Ex : "Lion + Liane = Riviere" (pour D1)
  //      "(Riviere deduite) + Pont = Gazelle" (pour D2)
  // -----------------------------------------------------------
  static String _describeNode(GameNode node, List<GameCard> allCards) {
    String labelOf(String id) {
      for (final c in allCards) {
        if (c.id == id) return c.label;
      }
      return '?';
    }

    final aId = node.emettriceId;
    final aLabel = aId == null
        ? '(deduit)'
        : labelOf(aId);
    final bLabel = labelOf(node.cableId);
    final cLabel = labelOf(node.receptriceId);
    return '$aLabel + $bLabel = $cLabel';
  }
}
