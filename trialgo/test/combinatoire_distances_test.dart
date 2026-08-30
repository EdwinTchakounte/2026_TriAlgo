// =============================================================
// FICHIER : test/combinatoire_distances_test.dart
// ROLE   : Verrouiller la combinatoire des distances D1 a D5
// =============================================================
//
// CE QUE CES TESTS PROTEGENT
// --------------------------
// GenerateLogicalNodesUseCase est la piece sur laquelle tout le
// jeu repose : c'est elle qui transforme un graphe de noeuds en
// tables de trios jouables. Si elle se trompe, chaque partie est
// fausse, et rien ailleurs ne le signale.
//
// Jusqu'ici elle n'avait jamais tourne au-dela de D2, faute de
// contenu en base. On lui fabrique donc ici une chaine de 5
// noeuds en memoire, et on verifie les quatre regles du document
// coeur :
//
//   1. T est inclus dans Elements(C_k)   (2k+1 elements)
//   2. |T| = 3                            (trois cartes DISTINCTES)
//   3. R_k appartient a T                 (la receptrice finale)
//   4. T n'est un noeud natif d'aucun N_j de la chaine
//
// D'ou MaxTrios(D_k) = C(2k,2) - 1, soit D2=5, D3=14, D4=27, D5=44.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/data/services/graph_sync_service.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/domain/usecases/build_graph_usecase.dart';

GraphCardEntity _carte(String id) => GraphCardEntity(
      id: id,
      label: 'Carte $id',
      imagePath: 'https://exemple.test/$id.jpg',
    );

// -------------------------------------------------------------
// Graphe A : une chaine lineaire de 5 noeuds, 11 cartes toutes
// distinctes. C'est le cas nominal : 2k+1 = 11 elements en D5.
//
//   N1 : c0 + c1 = c2          (racine)
//   N2 : (c2) + c3 = c4        (enfant de N1)
//   N3 : (c4) + c5 = c6
//   N4 : (c6) + c7 = c8
//   N5 : (c8) + c9 = c10
// -------------------------------------------------------------
Future<GraphSyncService> _chaineDeCinqNoeuds() async {
  final cartes = [for (var i = 0; i <= 10; i++) _carte('c$i')];

  final noeuds = <GraphNodeEntity>[
    GraphNodeEntity(
      id: 'n1', nodeIndex: 1, emettriceId: 'c0',
      cableId: 'c1', receptriceId: 'c2', depth: 1,
    ),
    GraphNodeEntity(
      id: 'n2', nodeIndex: 2, parentNodeId: 'n1',
      cableId: 'c3', receptriceId: 'c4', depth: 2,
    ),
    GraphNodeEntity(
      id: 'n3', nodeIndex: 3, parentNodeId: 'n2',
      cableId: 'c5', receptriceId: 'c6', depth: 3,
    ),
    GraphNodeEntity(
      id: 'n4', nodeIndex: 4, parentNodeId: 'n3',
      cableId: 'c7', receptriceId: 'c8', depth: 4,
    ),
    GraphNodeEntity(
      id: 'n5', nodeIndex: 5, parentNodeId: 'n4',
      cableId: 'c9', receptriceId: 'c10', depth: 5,
    ),
  ];

  final service = GraphSyncService(
    repository: _FauxGraphRepository(cartes: cartes, noeuds: noeuds),
    buildGraph: BuildGraphUseCase(),
  );
  await service.syncAndBuild('jeu-test');
  return service;
}

// -------------------------------------------------------------
// Graphe B : une chaine de 3 noeuds ou LE MEME CABLE sert deux
// fois. C'est parfaitement legal — une carte est neutre, et un
// cable "miroir" a vocation a etre reutilise dans plusieurs
// noeuds. Un vrai jeu en contiendra forcement.
//
//   N1 : c0 + MIROIR = c2
//   N2 : (c2) + c3   = c4
//   N3 : (c4) + MIROIR = c6      <- meme cable qu'en N1
// -------------------------------------------------------------
Future<GraphSyncService> _chaineAvecCableReutilise() async {
  final cartes = [
    _carte('c0'), _carte('MIROIR'), _carte('c2'),
    _carte('c3'), _carte('c4'), _carte('c6'),
  ];

  final noeuds = <GraphNodeEntity>[
    GraphNodeEntity(
      id: 'n1', nodeIndex: 1, emettriceId: 'c0',
      cableId: 'MIROIR', receptriceId: 'c2', depth: 1,
    ),
    GraphNodeEntity(
      id: 'n2', nodeIndex: 2, parentNodeId: 'n1',
      cableId: 'c3', receptriceId: 'c4', depth: 2,
    ),
    GraphNodeEntity(
      id: 'n3', nodeIndex: 3, parentNodeId: 'n2',
      cableId: 'MIROIR', receptriceId: 'c6', depth: 3,
    ),
  ];

  final service = GraphSyncService(
    repository: _FauxGraphRepository(cartes: cartes, noeuds: noeuds),
    buildGraph: BuildGraphUseCase(),
  );
  await service.syncAndBuild('jeu-test');
  return service;
}

void main() {
  group('Combinatoire des distances', () {
    test('le nombre de tables suit C(2k,2) - 1 jusqu a D5', () async {
      final service = await _chaineDeCinqNoeuds();
      final pool = service.logicalNodes!;

      expect(pool.numberOfTables(1), 1, reason: 'D1 : une seule table');
      expect(pool.numberOfTables(2), 5, reason: 'D2 : C(4,2)-1');
      expect(pool.numberOfTables(3), 14, reason: 'D3 : C(6,2)-1');
      expect(pool.numberOfTables(4), 27, reason: 'D4 : C(8,2)-1');
      expect(pool.numberOfTables(5), 44, reason: 'D5 : C(10,2)-1');
    });

    test('chaque chaine remplit exactement toutes ses tables', () async {
      final service = await _chaineDeCinqNoeuds();
      final pool = service.logicalNodes!;

      // Dans une chaine lineaire de 5 noeuds, il y a (6 - k) chaines
      // distinctes de longueur k : 4 en D2, 3 en D3, 2 en D4, 1 en D5.
      for (final k in [2, 3, 4, 5]) {
        final chainesAttendues = 6 - k;
        for (var i = 0; i < pool.numberOfTables(k); i++) {
          expect(
            pool.table(distance: k, tableIndex: i).length,
            chainesAttendues,
            reason: 'D$k table $i : une entree par chaine de longueur $k',
          );
        }
      }
    });

    test('tout trio contient la receptrice finale et exclut les natifs',
        () async {
      final service = await _chaineDeCinqNoeuds();
      final pool = service.logicalNodes!;

      // Signatures des 5 noeuds natifs de la chaine complete.
      final natifs = <Set<String>>{
        {'c0', 'c1', 'c2'},
        {'c2', 'c3', 'c4'},
        {'c4', 'c5', 'c6'},
        {'c6', 'c7', 'c8'},
        {'c8', 'c9', 'c10'},
      };

      for (var i = 0; i < pool.numberOfTables(5); i++) {
        for (final trio in pool.table(distance: 5, tableIndex: i)) {
          final ids = {trio.cardA.id, trio.cardB.id, trio.cardC.id};

          expect(ids.contains('c10'), isTrue,
              reason: 'regle 3 : R5 doit appartenir a tout trio D5');
          expect(natifs.contains(ids), isFalse,
              reason: 'regle 4 : un noeud natif ne doit jamais ressortir');
        }
      }
    });

    test('tout trio compte trois cartes distinctes, cable reutilise inclus',
        () async {
      // Regle 2 du document coeur : |T| = 3.
      // Un cable reutilise dans deux noeuds de la meme chaine ne doit
      // pas produire de trio degenere ou la meme image apparait deux
      // fois parmi les trois.
      final service = await _chaineAvecCableReutilise();
      final pool = service.logicalNodes!;

      final degeneres = <String>[];
      for (final k in [1, 2, 3]) {
        for (var i = 0; i < pool.numberOfTables(k); i++) {
          for (final trio in pool.table(distance: k, tableIndex: i)) {
            final ids = {trio.cardA.id, trio.cardB.id, trio.cardC.id};
            if (ids.length != 3) degeneres.add(trio.trackingKey);
          }
        }
      }

      expect(degeneres, isEmpty,
          reason: 'trios avec moins de 3 cartes distinctes : $degeneres');
    });
  });
}

class _FauxGraphRepository implements GraphRepository {
  _FauxGraphRepository({required this.cartes, required this.noeuds});

  final List<GraphCardEntity> cartes;
  final List<GraphNodeEntity> noeuds;

  @override
  Future<List<GraphCardEntity>> getAllCards(String gameId) async => cartes;

  @override
  Future<List<GraphNodeEntity>> getAllNodes(String gameId) async => noeuds;

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
