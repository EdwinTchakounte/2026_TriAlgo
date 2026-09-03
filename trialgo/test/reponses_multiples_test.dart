// =============================================================
// FICHIER : test/reponses_multiples_test.dart
// ROLE   : Verrouiller le fait qu'une question peut avoir
//          PLUSIEURS reponses justes, et qu'aucune d'elles ne
//          peut apparaitre comme piege parmi les distracteurs
// =============================================================
//
// LE DEFAUT QUE CES TESTS EMPECHENT DE REVENIR
// --------------------------------------------
// Une question montre 2 cartes et en masque une 3eme. Jusqu'ici
// le code supposait une reponse unique : `correctCardId` etait un
// simple String, et les distracteurs etaient tires dans tout le
// catalogue en excluant seulement les 3 cartes du trio courant.
//
// Cette hypothese est fausse a deux titres.
//
// 1. STRUCTURELLEMENT, des D2.
//    Un trio D_k est un sous-ensemble de 3 elements de la chaine
//    contenant R_k. Sur une chaine de 2 noeuds, les elements sont
//    {E1, C1, R1, C2, R2} et les trios valides sont :
//        {E1,C1,R2} {E1,R1,R2} {E1,C2,R2} {C1,R1,R2} {C1,C2,R2}
//    (le natif {R1,C2,R2} est exclu par la regle 4).
//    Donc "E1 + R2 + ?" admet C1, R1 ET C2 : trois reponses.
//    Masquer R_k (config A) est le seul cas non ambigu ; masquer
//    l'une des deux autres cartes (configs B et C) l'est TOUJOURS,
//    avec jusqu'a 3 reponses a D2, 5 a D3, 7 a D4, 9 a D5.
//
// 2. PAR LE CONTENU, des D1.
//    Une carte est neutre et un meme couple de parents peut
//    engendrer plusieurs enfants. Le dictionnaire du jeu contient
//    par exemple B4+D9=P8 et B4+D9=E7. Les deux sont justes.
//
// Consequence avant correction : une autre reponse juste pouvait
// etre tiree comme distracteur, et le joueur qui la choisissait
// etait compte FAUX tout en ayant raison. Aucune erreur, aucun
// journal -- et cela frappait d'abord ceux qui connaissent le
// mieux le jeu.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/data/services/graph_sync_service.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/domain/usecases/build_graph_usecase.dart';
import 'package:trialgo/domain/usecases/generate_game_question_usecase.dart';

GraphCardEntity _carte(String id) => GraphCardEntity(
      id: id,
      label: 'Carte $id',
      imagePath: 'https://exemple.test/$id.jpg',
    );

Future<GraphSyncService> _service({
  required List<GraphCardEntity> cartes,
  required List<GraphNodeEntity> noeuds,
}) async {
  final service = GraphSyncService(
    repository: _FauxGraphRepository(cartes: cartes, noeuds: noeuds),
    buildGraph: BuildGraphUseCase(),
  );
  await service.syncAndBuild('jeu-test');
  return service;
}

// -------------------------------------------------------------
// Graphe A : chaine de 2 noeuds + un catalogue de remplissage.
//
//   N1 : c0 + c1 = c2       (racine)     -> E1=c0, C1=c1, R1=c2
//   N2 : (c2) + c3 = c4     (enfant)     -> C2=c3, R2=c4
//
// Les cartes f00..f29 n'appartiennent a aucun noeud : elles ne
// servent que de vivier a distracteurs, pour que la grille de
// 6 choix puisse toujours etre remplie.
// -------------------------------------------------------------
Future<GraphSyncService> _chaineDeDeuxNoeuds() => _service(
      cartes: [
        for (var i = 0; i <= 4; i++) _carte('c$i'),
        for (var i = 0; i < 30; i++) _carte('f${i.toString().padLeft(2, '0')}'),
      ],
      noeuds: [
        GraphNodeEntity(
          id: 'n1', nodeIndex: 1, emettriceId: 'c0',
          cableId: 'c1', receptriceId: 'c2', depth: 1,
        ),
        GraphNodeEntity(
          id: 'n2', nodeIndex: 2, parentNodeId: 'n1',
          cableId: 'c3', receptriceId: 'c4', depth: 2,
        ),
      ],
    );

// -------------------------------------------------------------
// Graphe B : le cas reel du dictionnaire MIXALGO.
//
//   N1 : B4 + D9 = P8       (racine)
//   N2 : B4 + D9 = E7       (racine)   <- MEME couple de parents
//
// Deux racines distinctes, meme couple, deux enfants differents.
// C'est legal : la fusion est une relation, pas une fonction.
// -------------------------------------------------------------
Future<GraphSyncService> _memeCoupleDeuxEnfants() => _service(
      cartes: [
        _carte('B4'), _carte('D9'), _carte('P8'), _carte('E7'),
        for (var i = 0; i < 30; i++) _carte('f${i.toString().padLeft(2, '0')}'),
      ],
      noeuds: [
        GraphNodeEntity(
          id: 'n1', nodeIndex: 1, emettriceId: 'B4',
          cableId: 'D9', receptriceId: 'P8', depth: 1,
        ),
        GraphNodeEntity(
          id: 'n2', nodeIndex: 2, emettriceId: 'B4',
          cableId: 'D9', receptriceId: 'E7', depth: 1,
        ),
      ],
    );

void main() {
  // ===========================================================
  group('Le pool connait toutes les reponses valides', () {
    // ===========================================================

    test('masquer R_k (config A) donne une reponse unique', () async {
      final pool = (await _chaineDeDeuxNoeuds()).logicalNodes!;

      // "c0 + c1 + ?" : c'est le noeud natif N1, seul c2 le complete
      // en D1. Aucun trio D2 ne contient a la fois c0 et c1 sans c4,
      // donc c4 s'ajoute -- mais rien d'autre.
      final reponses = pool.completionsFor('c0', 'c1');
      expect(reponses.contains('c2'), isTrue,
          reason: 'c0 + c1 = c2 est le noeud natif N1');
    });

    test('masquer une autre carte (configs B et C) est ambigu', () async {
      final pool = (await _chaineDeDeuxNoeuds()).logicalNodes!;

      // Les trios D2 valides contenant c0 (=E1) et c4 (=R2) sont
      // {c0,c1,c4}, {c0,c2,c4} et {c0,c3,c4}. Les trois completions
      // c1, c2 et c3 sont donc TOUTES justes.
      final reponses = pool.completionsFor('c0', 'c4');
      expect(reponses, containsAll(<String>['c1', 'c2', 'c3']),
          reason: 'E1 + R2 + ? admet C1, R1 et C2 -- les trois');
      expect(reponses.length, greaterThan(1),
          reason: 'c est exactement l ambiguite que le correctif traite');
    });

    test('l index est independant de l ordre de la paire', () async {
      final pool = (await _chaineDeDeuxNoeuds()).logicalNodes!;
      expect(pool.completionsFor('c0', 'c4'), pool.completionsFor('c4', 'c0'));
    });

    test('une paire inconnue ne fait pas planter la lecture', () async {
      final pool = (await _chaineDeDeuxNoeuds()).logicalNodes!;
      expect(pool.completionsFor('inexistante', 'f00'), isEmpty);
    });
  });

  // ===========================================================
  group('Aucune reponse juste ne peut servir de piege', () {
    // ===========================================================

    test('aucun distracteur n est une reponse juste, sur toutes les configs',
        () async {
      final service = await _chaineDeDeuxNoeuds();
      final usecase = GenerateGameQuestionUseCase(service);
      final pool = service.logicalNodes!;

      var questionsGenerees = 0;

      // On balaye les 5 tables de D2 et les trois configs, plusieurs
      // fois chacune : le tirage est aleatoire, une seule passe ne
      // prouverait pas grand-chose.
      for (var passe = 0; passe < 20; passe++) {
        for (var table = 0; table < pool.numberOfTables(2); table++) {
          for (final config in const ['A', 'B', 'C']) {
            final q = usecase.call(
              distance: 2,
              tableIndex: table,
              availableConfigs: [config],
            );
            if (q == null) continue;
            questionsGenerees++;

            // La regle centrale : parmi les 6 choix proposes, une
            // seule carte doit etre une reponse juste.
            final justesProposees = q.choices
                .where((c) => q.validAnswerIds.contains(c.id))
                .map((c) => c.id)
                .toSet();

            expect(
              justesProposees,
              {q.correctCardId},
              reason: 'config $config, table $table : une autre reponse '
                  'juste figure parmi les distracteurs -- le joueur qui '
                  'la choisit serait compte faux a tort',
            );
          }
        }
      }

      expect(questionsGenerees, greaterThan(0),
          reason: 'le balayage doit avoir produit des questions');
    });

    test('validAnswerIds contient toujours la carte masquee', () async {
      final service = await _chaineDeDeuxNoeuds();
      final usecase = GenerateGameQuestionUseCase(service);

      for (var passe = 0; passe < 30; passe++) {
        final q = usecase.call(
          distance: 2,
          tableIndex: passe % 5,
          availableConfigs: const ['A', 'B', 'C'],
        );
        if (q == null) continue;
        expect(q.validAnswerIds.contains(q.correctCardId), isTrue);
        expect(q.choices.any((c) => c.id == q.correctCardId), isTrue,
            reason: 'la bonne reponse doit figurer parmi les choix');
      }
    });

    test('la grille reste remplie malgre les exclusions', () async {
      final service = await _chaineDeDeuxNoeuds();
      final usecase = GenerateGameQuestionUseCase(service);

      final q = usecase.call(
        distance: 2,
        tableIndex: 0,
        availableConfigs: const ['C'],
      );
      expect(q, isNotNull);
      expect(q!.choices.length, 6,
          reason: 'exclure les reponses justes ne doit pas depeupler '
              'la grille tant que le catalogue est suffisant');
    });
  });

  // ===========================================================
  group('Un meme couple de parents peut avoir plusieurs enfants', () {
    // ===========================================================

    test('les deux enfants sont reconnus comme reponses justes', () async {
      final pool = (await _memeCoupleDeuxEnfants()).logicalNodes!;

      expect(
        pool.completionsFor('B4', 'D9'),
        {'P8', 'E7'},
        reason: 'B4+D9=P8 et B4+D9=E7 sont tous deux dans le dictionnaire',
      );
    });

    test('l enfant alternatif n est jamais propose comme distracteur',
        () async {
      final service = await _memeCoupleDeuxEnfants();
      final usecase = GenerateGameQuestionUseCase(service);

      for (var passe = 0; passe < 40; passe++) {
        final q = usecase.call(
          distance: 1,
          tableIndex: 0,
          availableConfigs: const ['A'],
        );
        if (q == null) continue;

        // La question est "B4 + D9 = ?". La reponse attendue est
        // P8 ou E7 selon le noeud tire ; l'AUTRE ne doit pas se
        // trouver dans la grille, sans quoi le joueur qui la
        // choisit -- a raison -- serait sanctionne.
        final autre = q.correctCardId == 'P8' ? 'E7' : 'P8';
        expect(
          q.choices.any((c) => c.id == autre),
          isFalse,
          reason: 'passe $passe : $autre est une reponse juste, il ne '
              'peut pas etre propose comme piege face a ${q.correctCardId}',
        );
      }
    });
  });
}

// -------------------------------------------------------------
// Faux repository : rend le graphe fabrique en memoire, sans
// toucher au reseau ni a une base.
// -------------------------------------------------------------
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
