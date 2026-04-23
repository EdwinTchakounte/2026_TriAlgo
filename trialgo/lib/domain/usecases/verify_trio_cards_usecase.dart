// =============================================================
// FICHIER : lib/domain/usecases/verify_trio_cards_usecase.dart
// ROLE   : Verifier un trio de cartes cote client (mode collectif)
// COUCHE : Domain > UseCases
// =============================================================
//
// POURQUOI CLIENT-SIDE ?
// ----------------------
// Le graphe et le pool de noeuds logiques sont deja charges en
// memoire apres syncAndBuild (cf. GraphSyncService). Faire un RPC
// Supabase serait plus lent, dependrait du reseau et redondant avec
// les donnees deja disponibles cote client.
//
// QUE CHERCHE-T-ON VRAIMENT ?
// ---------------------------
// Un trio est "valide" s'il fait partie du LogicalNodesPool.
// Ce pool contient TOUTES les combinaisons de 3 cartes jouables
// par le jeu (D1, D2, D3, etc.), soit :
//   - D1 : 50 trios natifs  (1 table)
//   - D2 : 5 tables * N paires parent-enfant
//   - D3 : 14 tables * N chaines de 3 noeuds
//
// Le mode collectif verifie contre D1, D2 et D3 (comme demande).
//
// DEUX MODES DE VERIFICATION :
// ----------------------------
// 1. verifyByCardIds  : l'utilisateur a scanne 3 QR codes.
//    On cherche un noeud logique (dans D1/D2/D3) dont l'ensemble
//    {cardA, cardB, cardC} correspond exactement aux 3 UUIDs
//    scannes (ordre libre).
// 2. verifyByNodeIndex : l'utilisateur a saisi un numero de noeud.
//    On le convertit en trio natif D1 (E, C, R) et on renvoie
//    via verifyByCardIds pour obtenir un resultat unifie.
//
// COMPLEXITE :
// ------------
// O(N) avec N = nombre total de noeuds logiques <= ~1000 pour
// un jeu avec 50 noeuds natifs. Quelques microsecondes par verif.
// =============================================================

import 'package:trialgo/data/services/graph_sync_service.dart';
import 'package:trialgo/domain/entities/logical_node_entity.dart';
import 'package:trialgo/domain/entities/verify_trio_result.dart';


/// Use case client-side de verification d'un trio.
class VerifyTrioCardsUseCase {

  /// Reference au service qui porte le graphe et le catalogue de cartes.
  /// Injecte au constructeur pour faciliter les tests (mock possible).
  final GraphSyncService _syncService;

  VerifyTrioCardsUseCase(this._syncService);

  // =============================================================
  // METHODE : verifyByCardIds
  // =============================================================
  // Cherche dans les tables D1, D2, D3 du LogicalNodesPool si un
  // noeud logique match exactement les 3 cartes scannees.
  // =============================================================

  /// Verifie qu'un trio forme par les 3 cartes scannees existe.
  VerifyTrioResult verifyByCardIds(List<String> cardIds) {
    // Validation d'entree : on attend exactement 3 cartes distinctes.
    if (cardIds.length != 3) {
      return VerifyTrioResult.invalid('Il faut exactement 3 cartes');
    }
    final scannedSet = cardIds.toSet();
    if (scannedSet.length != 3) {
      return VerifyTrioResult.invalid('Cartes en doublon');
    }

    // Le pool logique doit avoir ete precompute (via syncAndBuild).
    final pool = _syncService.logicalNodes;
    if (pool == null) {
      return VerifyTrioResult.invalid('Graphe non charge');
    }

    // On cherche dans D1, D2, D3 (limite demandee pour le mode collectif).
    // Pour chaque distance : iterer chaque table, puis chaque logical node.
    // Structure : pool.tablesForDistance(d) = List<List<LogicalNodeEntity>>
    //   [table_0, table_1, ...]
    // ou chaque table est une liste de noeuds logiques.
    //
    // L'ordre D1 -> D2 -> D3 est important : en cas de multiple matches
    // (ne devrait pas arriver car les generators excluent les doublons),
    // on retourne le plus simple (distance la plus basse).
    for (final distance in const [1, 2, 3]) {
      final tables = pool.tablesForDistance(distance);

      for (final table in tables) {
        for (final logical in table) {
          final match = _matchLogical(logical, scannedSet);
          if (match != null) return match;
        }
      }
    }

    // Aucun noeud ne matche.
    return VerifyTrioResult.invalid(
      'Ces 3 cartes ne forment pas un trio valide',
    );
  }

  // =============================================================
  // METHODE : _matchLogical
  // =============================================================
  // Teste si un noeud logique donne correspond a l'ensemble des
  // 3 cartes scannees. Retourne un VerifyTrioResult.success si oui,
  // null sinon (pour que l'appelant continue son parcours).
  // =============================================================

  /// Verifie si [logical] match l'ensemble [scannedSet] de 3 UUIDs.
  VerifyTrioResult? _matchLogical(
    LogicalNodeEntity logical,
    Set<String> scannedSet,
  ) {
    final aId = logical.cardA.id;
    final bId = logical.cardB.id;
    final cId = logical.cardC.id;

    // Le generator logique garantit deja cette propriete, mais
    // defensive : un noeud ou 2 cartes sont identiques ne peut pas
    // correspondre a un scan de 3 cartes distinctes.
    if (aId == bId || bId == cId || aId == cId) return null;

    // Les 3 cartes du noeud logique doivent TOUTES etre dans le set
    // scanne. Comme les 3 sont distinctes et que le set a 3 elements
    // distincts, ca garantit l'egalite des ensembles.
    if (!scannedSet.contains(aId)) return null;
    if (!scannedSet.contains(bId)) return null;
    if (!scannedSet.contains(cId)) return null;

    // Match trouve. On construit le resultat avec :
    //   - distance : 1, 2 ou 3
    //   - cardLabels : dans l'ordre cardA/B/C du noeud logique
    //   - sourceNodeIndices : les noeuds natifs traverses
    //     (ex: [1, 16] pour D2 = "N01 → N16")
    //   - trackingKey : pour debug / admin
    return VerifyTrioResult.success(
      distance: logical.distance,
      cardLabels: [
        logical.cardA.label,
        logical.cardB.label,
        logical.cardC.label,
      ],
      sourceNodeIndices:
          logical.sourceNodes.map((n) => n.nodeIndex).toList(growable: false),
      trackingKey: logical.trackingKey,
    );
  }

  // =============================================================
  // METHODE : verifyByNodeIndex
  // =============================================================
  // Variante "saisie manuelle" : l'utilisateur entre un numero de
  // noeud (1 a 50). On retrouve le noeud natif et on recupere ses
  // 3 cartes (E effective, C, R), puis on delegue a verifyByCardIds
  // pour obtenir un resultat unifie (meme format).
  //
  // Avantage : une seule route de resultat dans l'UI,
  // cohesion des 2 flux (scan + manuel).
  // =============================================================

  /// Verifie qu'un noeud existe en le cherchant par son numero.
  VerifyTrioResult verifyByNodeIndex(int nodeIndex) {
    if (nodeIndex < 1) {
      return VerifyTrioResult.invalid('Numero de trio invalide');
    }

    final graph = _syncService.gameGraph;
    if (graph == null) {
      return VerifyTrioResult.invalid('Graphe non charge');
    }

    final node = graph.nodesByIndex[nodeIndex];
    if (node == null) {
      return VerifyTrioResult.invalid('Trio inexistant pour ce jeu');
    }

    if (node.depth > 3) {
      return VerifyTrioResult.invalid('Trio hors mode collectif (D > 3)');
    }

    // Resolution de l'emettrice effective (D1 direct, D2+ via parent).
    final String eId;
    try {
      eId = node.effectiveEmettriceId;
    } catch (_) {
      return VerifyTrioResult.invalid('Donnees du trio incompletes');
    }

    // On delegue a verifyByCardIds pour garder UNE SEULE logique de
    // match et un format de resultat uniforme. Les 3 UUIDs sont
    // {E effective, C, R} du noeud natif.
    return verifyByCardIds([eId, node.cableId, node.receptriceId]);
  }
}
