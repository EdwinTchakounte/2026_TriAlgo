// =============================================================
// FICHIER : lib/domain/usecases/generate_logical_nodes_usecase.dart
// ROLE   : Precomputer tous les noeuds logiques jouables
// COUCHE : Domain > Usecases
// =============================================================
//
// REGLE FORMELLE :
// ----------------
// Pour une distance Dk (chaine de k noeuds), un trio est valide
// si et seulement si :
//   (i)   il contient exactement 3 elements de la chaine
//   (ii)  il contient R_k (la receptrice finale)
//   (iii) il n'est pas un noeud natif (pas egal a {N_j.E, N_j.C, N_j.R}
//         pour aucun j ∈ [1, k])
//
// NOMBRE MAX DE TRIOS :
// ---------------------
//   MaxTrios(Dk) = C(2k, 2) - 1
//   D1 : 0 (le noeud lui-meme est le seul trio)
//   D2 : 5
//   D3 : 14
//   D4 : 27
//   D5 : 44
//
// ORGANISATION EN TABLES :
// ------------------------
// Pour chaque distance Dk, on organise les trios en MaxTrios(Dk)
// tables. Chaque table contient 1 trio par chaine existante dans
// le graphe. Ainsi, pendant une partie, tous les trios peuvent
// etre piochés dans UNE SEULE table, garantissant qu'aucun trio
// de la meme chaine ne soit presente deux fois dans la meme partie.
//
// REFERENCE : Discussion architecture graphe, avril 2026
// =============================================================

import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/entities/logical_node_entity.dart';
import 'package:trialgo/domain/usecases/build_graph_usecase.dart';
import 'package:trialgo/data/services/graph_sync_service.dart';

/// Pool de noeuds logiques pre-calcules pour toutes les distances.
///
/// Organisation en TABLES :
///   - `tablesD1` : 1 table contenant 1 noeud par noeud natif
///   - `tablesD2` : 5 tables contenant chacune 1 trio par paire
///   - `tablesD3` : 14 tables contenant chacune 1 trio par chaine de 3
///   - `tablesD4` : 27 tables
///   - `tablesD5` : 44 tables
///
/// Une partie pioche UNIQUEMENT dans une seule table, ce qui garantit
/// qu'aucun trio de la meme chaine ne se retrouve deux fois dans la
/// meme partie.
class LogicalNodesPool {

  /// Tables de noeuds logiques de distance 1.
  /// Pour D1, il n'y a qu'1 seule table (le noeud lui-meme).
  final List<List<LogicalNodeEntity>> tablesD1;

  /// Tables de noeuds logiques de distance 2.
  /// Il y a jusqu'a 5 tables (MaxTrios(D2) = 5).
  final List<List<LogicalNodeEntity>> tablesD2;

  /// Tables de noeuds logiques de distance 3.
  /// Il y a jusqu'a 14 tables (MaxTrios(D3) = 14).
  final List<List<LogicalNodeEntity>> tablesD3;

  /// Tables de noeuds logiques de distance 4.
  /// Il y a jusqu'a 27 tables (MaxTrios(D4) = 27).
  final List<List<LogicalNodeEntity>> tablesD4;

  /// Tables de noeuds logiques de distance 5.
  /// Il y a jusqu'a 44 tables (MaxTrios(D5) = 44).
  final List<List<LogicalNodeEntity>> tablesD5;

  /// Cree un pool de noeuds logiques.
  const LogicalNodesPool({
    required this.tablesD1,
    required this.tablesD2,
    required this.tablesD3,
    required this.tablesD4,
    required this.tablesD5,
  });

  // =============================================================
  // GETTERS UTILITAIRES
  // =============================================================

  /// Nombre total de noeuds logiques generes dans tout le pool.
  int get totalCount {
    int total = 0;
    for (final table in tablesD1) { total += table.length; }
    for (final table in tablesD2) { total += table.length; }
    for (final table in tablesD3) { total += table.length; }
    for (final table in tablesD4) { total += table.length; }
    for (final table in tablesD5) { total += table.length; }
    return total;
  }

  /// Retourne les tables pour une distance donnee.
  List<List<LogicalNodeEntity>> tablesForDistance(int distance) {
    switch (distance) {
      case 1:
        return tablesD1;
      case 2:
        return tablesD2;
      case 3:
        return tablesD3;
      case 4:
        return tablesD4;
      case 5:
        return tablesD5;
      default:
        return [];
    }
  }

  /// Retourne une table specifique pour (distance, tableIndex).
  ///
  /// Retourne une liste vide si la combinaison n'existe pas.
  List<LogicalNodeEntity> table({required int distance, required int tableIndex}) {
    final tables = tablesForDistance(distance);
    if (tableIndex < 0 || tableIndex >= tables.length) return [];
    return tables[tableIndex];
  }

  /// Nombre de tables disponibles pour une distance.
  int numberOfTables(int distance) => tablesForDistance(distance).length;
}


/// Usecase : pre-genere tous les noeuds logiques jouables.
///
/// Utilise la formule mathematique MaxTrios(Dk) = C(2k, 2) - 1 pour
/// enumerer toutes les combinaisons valides, puis les organise en
/// tables pour le tirage sans collision.
class GenerateLogicalNodesUseCase {

  final GraphSyncService _syncService;

  GenerateLogicalNodesUseCase(this._syncService);

  /// Genere tous les noeuds logiques a partir du [graph].
  LogicalNodesPool call(GameGraph graph) {
    final tablesD1 = _generateForDistance(graph, 1);
    final tablesD2 = _generateForDistance(graph, 2);
    final tablesD3 = _generateForDistance(graph, 3);
    final tablesD4 = _generateForDistance(graph, 4);
    final tablesD5 = _generateForDistance(graph, 5);

    return LogicalNodesPool(
      tablesD1: tablesD1,
      tablesD2: tablesD2,
      tablesD3: tablesD3,
      tablesD4: tablesD4,
      tablesD5: tablesD5,
    );
  }

  // =============================================================
  // GENERATION GENERIQUE PAR DISTANCE
  // =============================================================
  // Pour une distance k donnee :
  //   1. Recuperer toutes les chaines de longueur k du graphe
  //   2. Pour chaque chaine, generer toutes les combinaisons valides
  //   3. Ranger les trios dans les tables (1 trio par chaine par table)
  // =============================================================

  List<List<LogicalNodeEntity>> _generateForDistance(
    GameGraph graph,
    int k,
  ) {
    // Recuperer toutes les chaines de longueur k du graphe.
    final chains = graph.allChainsOfLength(k);
    if (chains.isEmpty) return [];

    // Pour D1, chaque noeud est un trio unique (pas de variantes).
    if (k == 1) {
      return _generateD1Tables(chains);
    }

    // Pour D2+, calculer les trios valides pour chaque chaine
    // et les organiser en tables.
    return _generateDkTables(chains, k);
  }

  // =============================================================
  // CAS SPECIAL : DISTANCE 1
  // =============================================================
  // Chaque noeud natif produit un unique trio logique = lui-meme.
  // Une seule table contenant 1 trio par noeud.
  // =============================================================

  List<List<LogicalNodeEntity>> _generateD1Tables(
    List<List<GraphNodeEntity>> chains,
  ) {
    final table = <LogicalNodeEntity>[];

    for (final chain in chains) {
      // Pour D1, chaque chaine a exactement 1 noeud.
      final node = chain.first;

      final e = _syncService.getCard(node.effectiveEmettriceId);
      final c = _syncService.getCard(node.cableId);
      final r = _syncService.getCard(node.receptriceId);

      table.add(LogicalNodeEntity(
        trackingKey: 'D1#N${node.nodeIndex}',
        distance: 1,
        cardA: e,
        cardB: c,
        cardC: r,
        sourceNodes: [node],
      ));
    }

    // D1 : 1 seule table
    return [table];
  }

  // =============================================================
  // CAS GENERAL : DISTANCES 2 A 5
  // =============================================================
  // Pour une chaine de k noeuds, on enumere toutes les combinaisons
  // de 3 elements qui :
  //   - contiennent R_k
  //   - ne sont pas un noeud natif
  //
  // Le nombre exact de trios valides est donne par :
  //   MaxTrios(Dk) = C(2k, 2) - 1
  //
  // Ces trios sont indexes de 0 a MaxTrios(Dk) - 1. Pour chaque
  // index, on cree une table qui contient le trio d'index i de
  // chaque chaine. Ainsi, une partie qui pioche dans la table i
  // ne verra jamais deux trios de la meme chaine.
  // =============================================================

  List<List<LogicalNodeEntity>> _generateDkTables(
    List<List<GraphNodeEntity>> chains,
    int k,
  ) {
    if (chains.isEmpty) return [];

    // Allouer le bon nombre de tables (MaxTrios(Dk)).
    final maxTrios = _maxTrios(k);
    final tables = List<List<LogicalNodeEntity>>.generate(
      maxTrios,
      (_) => <LogicalNodeEntity>[],
    );

    // Pour chaque chaine, generer ses trios valides et les distribuer
    // dans les tables selon leur index.
    for (final chain in chains) {
      final trios = _validTriosForChain(chain, k);

      for (int i = 0; i < trios.length && i < maxTrios; i++) {
        tables[i].add(trios[i]);
      }
    }

    return tables;
  }

  /// Calcule MaxTrios(Dk) = C(2k, 2) - 1.
  int _maxTrios(int k) {
    if (k < 1) return 0;
    if (k == 1) return 1;
    // C(2k, 2) = 2k * (2k - 1) / 2 = k * (2k - 1)
    final binomial = k * (2 * k - 1);
    return binomial - 1; // -1 pour le noeud natif final
  }

  // =============================================================
  // GENERATION DES TRIOS VALIDES POUR UNE CHAINE
  // =============================================================
  // Elements de la chaine de k noeuds :
  //   Slot 0  : E1 (emettrice du 1er noeud)
  //   Slot 1  : C1 (cable du 1er noeud)
  //   Slot 2  : R1 (receptrice du 1er noeud = emettrice du 2eme)
  //   Slot 3  : C2 (cable du 2eme noeud)
  //   Slot 4  : R2 (receptrice du 2eme noeud)
  //   ...
  //   Slot 2k : Rk (receptrice finale)
  //
  // Total d'elements = 2k + 1
  //
  // On enumere toutes les combinaisons de 3 elements qui contiennent
  // l'element a l'index 2k (= R_k) et on filtre celles qui sont des
  // noeuds natifs.
  // =============================================================

  List<LogicalNodeEntity> _validTriosForChain(
    List<GraphNodeEntity> chain,
    int k,
  ) {
    // Construire la liste des elements de la chaine.
    // L'ordre est : E1, C1, R1, C2, R2, C3, R3, ..., Ck, Rk
    final elements = <_ChainElement>[];

    // E1 : l'emettrice effective du premier noeud de la chaine.
    elements.add(_ChainElement(
      card: chain[0].effectiveEmettriceId,
      label: 'E1',
    ));

    // Pour chaque noeud i de la chaine : Ci puis Ri.
    for (int i = 0; i < k; i++) {
      elements.add(_ChainElement(
        card: chain[i].cableId,
        label: 'C${i + 1}',
      ));
      elements.add(_ChainElement(
        card: chain[i].receptriceId,
        label: 'R${i + 1}',
      ));
    }

    // L'index de Rk dans la liste est 2k (0-based).
    final rkIndex = 2 * k;
    final rkElement = elements[rkIndex];

    // Identifier les combinaisons qui correspondent a un noeud natif.
    // Un noeud natif Nj est l'ensemble {E_j (= R_{j-1}), C_j, R_j}.
    // On stocke les "signatures" de noeuds natifs (ensembles de card IDs).
    final nativeSignatures = <Set<String>>{};
    for (int j = 0; j < k; j++) {
      final eId = chain[j].effectiveEmettriceId;
      final cId = chain[j].cableId;
      final rId = chain[j].receptriceId;
      nativeSignatures.add({eId, cId, rId});
    }

    // Enumerer toutes les combinaisons de 3 elements qui contiennent Rk.
    // On fixe Rk et on choisit 2 elements parmi les 2k autres.
    final result = <LogicalNodeEntity>[];
    final chainKey = chain.map((n) => 'N${n.nodeIndex}').join('-');

    for (int i = 0; i < elements.length; i++) {
      if (i == rkIndex) continue;
      for (int j = i + 1; j < elements.length; j++) {
        if (j == rkIndex) continue;

        final elem1 = elements[i];
        final elem2 = elements[j];

        // Le trio est {elem1.card, elem2.card, rkElement.card}.
        final trioCardIds = {
          elem1.card,
          elem2.card,
          rkElement.card,
        };

        // Filtrer si le trio est un noeud natif.
        if (nativeSignatures.contains(trioCardIds)) {
          continue;
        }

        // Construire le LogicalNodeEntity.
        // L'ordre cardA/B/C suit l'ordre des slots dans la chaine
        // pour rendre le trio plus "naturel" visuellement.
        final cardA = _syncService.getCard(elem1.card);
        final cardB = _syncService.getCard(elem2.card);
        final cardC = _syncService.getCard(rkElement.card);

        final composition = '${elem1.label}-${elem2.label}-${rkElement.label}';
        final trackingKey = 'D$k#$chainKey#$composition';

        result.add(LogicalNodeEntity(
          trackingKey: trackingKey,
          distance: k,
          cardA: cardA,
          cardB: cardB,
          cardC: cardC,
          sourceNodes: chain,
        ));
      }
    }

    return result;
  }
}

// =============================================================
// CLASSE UTILITAIRE : element de chaine (slot)
// =============================================================
// Represente une position dans la chaine (E1, C1, R1, C2, R2...).
// Contient l'ID de la carte et un label lisible pour le debug
// et la cle de tracking.
// =============================================================

class _ChainElement {
  final String card;   // ID de la carte
  final String label;  // Label lisible (E1, C1, R1, etc.)

  const _ChainElement({required this.card, required this.label});
}
