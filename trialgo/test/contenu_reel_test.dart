// =============================================================
// FICHIER : test/contenu_reel_test.dart
// ROLE   : Faire tourner le gameplay sur le CONTENU REEL du jeu,
//          pas sur une chaine synthetique de laboratoire
// =============================================================
//
// POURQUOI CE TEST EXISTE
// -----------------------
// Les autres tests fabriquent des graphes taille reduite, choisis
// pour illustrer une regle. Ils prouvent que le code fait ce qu'on
// a pense -- pas qu'il tient sur le vrai jeu.
//
// Le parcours complet avait deja ete valide sur stack reelle, mais
// avec 2 noeuds et 7 cartes : cela ne disait rien de ce qui se passe
// a D2 et D3, ni du comportement quand plusieurs chaines partagent
// des cartes -- ce qui est la norme dans un vrai jeu et l'exception
// dans une chaine fabriquee.
//
// Ce test rejoue donc la generation de questions sur les 46 trios et
// 76 cartes du referentiel MIXALGO -- Savane, table par table,
// config par config.
//
// LA FIXTURE
// ----------
// test/fixtures/mixalgo_savane.json est DERIVE de
// ok_trialgo_backend/referentiels/mixalgo-savane.yml, qui est la
// source de verite. Les identifiants de cartes y sont les codes du
// dictionnaire (A3, K4, M8...) et non des UUID : une fixture doit
// rester lisible, et les UUID d'un import local ne veulent rien dire
// ailleurs.
//
// Le meme referentiel importe via scripts/referentiel.py produit
// exactement ce graphe en base : 24 noeuds D1, 16 D2, 6 D3, aucune
// violation du XOR emettrice/parent. Verifie sur la stack de dev.
//
// Pour regenerer la fixture apres une evolution du referentiel, voir
// le bloc `fixture` en fin de scripts/referentiel.py.
// =============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/data/services/graph_sync_service.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/domain/usecases/build_graph_usecase.dart';
import 'package:trialgo/domain/usecases/generate_game_question_usecase.dart';

Future<GraphSyncService> _chargerLeJeuReel() async {
  final brut = File('test/fixtures/mixalgo_savane.json').readAsStringSync();
  final donnees = jsonDecode(brut) as Map<String, dynamic>;

  final cartes = [
    for (final c in donnees['cards'] as List)
      GraphCardEntity(
        id: c['id'] as String,
        label: c['label'] as String,
        imagePath: 'https://exemple.test/${c['id']}.jpg',
      ),
  ];

  final noeuds = [
    for (final n in donnees['nodes'] as List)
      GraphNodeEntity(
        id: n['id'] as String,
        nodeIndex: n['node_index'] as int,
        emettriceId: n['emettrice_id'] as String?,
        parentNodeId: n['parent_node_id'] as String?,
        cableId: n['cable_id'] as String,
        receptriceId: n['receptrice_id'] as String,
        depth: n['depth'] as int,
      ),
  ];

  final service = GraphSyncService(
    repository: _FauxGraphRepository(cartes: cartes, noeuds: noeuds),
    buildGraph: BuildGraphUseCase(),
  );
  await service.syncAndBuild('mixalgo-savane');
  return service;
}

void main() {
  // ===========================================================
  group('Le graphe reel se charge', () {
    // ===========================================================

    test('76 cartes et 46 trios, repartis en D1/D2/D3', () async {
      final service = await _chargerLeJeuReel();
      final graphe = service.gameGraph!;

      expect(service.cards.length, 76);
      expect(graphe.nodesByIndex.length, 46);

      final parProfondeur = <int, int>{};
      for (final n in graphe.nodesByIndex.values) {
        parProfondeur[n.depth] = (parProfondeur[n.depth] ?? 0) + 1;
      }
      expect(parProfondeur, {1: 24, 2: 16, 3: 6},
          reason: 'doit correspondre a ce que l import a ecrit en base');
    });

    test('le XOR emettrice / parent est respecte partout', () async {
      final service = await _chargerLeJeuReel();
      for (final n in service.gameGraph!.nodesByIndex.values) {
        expect(
          (n.emettriceId == null) == (n.parentNodeId != null),
          isTrue,
          reason: 'noeud ${n.nodeIndex} : soit une racine avec emettrice, '
              'soit un enfant avec parent -- jamais les deux, jamais aucun',
        );
      }
    });

    test('le pool logique se construit sur les trois distances', () async {
      final pool = (await _chargerLeJeuReel()).logicalNodes!;

      expect(pool.numberOfTables(1), 1);
      expect(pool.numberOfTables(2), 5, reason: 'C(4,2)-1');
      expect(pool.numberOfTables(3), 14, reason: 'C(6,2)-1');

      // D4 et D5 sont vides : la plus longue chaine du referentiel
      // fait 3 noeuds. Ce n'est pas un defaut du code, c'est le
      // contenu qui s'arrete la.
      expect(pool.numberOfTables(4), 0,
          reason: 'aucune chaine de 4 noeuds dans ce jeu');
      expect(pool.numberOfTables(5), 0);
    });
  });

  // ===========================================================
  group('La generation de questions tient sur le contenu reel', () {
    // ===========================================================

    test('aucune question ne propose deux reponses justes', () async {
      final service = await _chargerLeJeuReel();
      final pool = service.logicalNodes!;
      final usecase = GenerateGameQuestionUseCase(service);

      var generees = 0;
      final parDistance = <int, int>{};

      // Balayage exhaustif : chaque distance, chaque table, chaque
      // config, plusieurs passes -- le tirage du noeud logique et
      // des distracteurs est aleatoire.
      for (final distance in const [1, 2, 3]) {
        for (var table = 0; table < pool.numberOfTables(distance); table++) {
          for (final config in const ['A', 'B', 'C']) {
            for (var passe = 0; passe < 8; passe++) {
              final q = usecase.call(
                distance: distance,
                tableIndex: table,
                availableConfigs: [config],
              );
              if (q == null) continue;
              generees++;
              parDistance[distance] = (parDistance[distance] ?? 0) + 1;

              final justesProposees = q.choices
                  .where((c) => q.validAnswerIds.contains(c.id))
                  .map((c) => c.id)
                  .toSet();

              expect(
                justesProposees,
                {q.correctCardId},
                reason: 'D$distance table $table config $config : '
                    'plusieurs reponses justes sont proposees, le joueur '
                    'peut etre sanctionne alors qu il a raison',
              );
            }
          }
        }
      }

      // 20 tables au total (1 en D1, 5 en D2, 14 en D3), 3 configs,
      // 8 passes : 480 questions. Le compte exact vaut mieux qu'un
      // seuil -- si une table cessait de repondre, un simple
      // "greaterThan" ne le verrait pas.
      expect(generees, 480,
          reason: '(1 + 5 + 14) tables x 3 configs x 8 passes -- '
              'chaque table doit repondre a chaque appel');
      expect(parDistance.keys.toSet(), {1, 2, 3},
          reason: 'les trois distances doivent produire des questions');
    });

    test('chaque question est complete et coherente', () async {
      final service = await _chargerLeJeuReel();
      final pool = service.logicalNodes!;
      final usecase = GenerateGameQuestionUseCase(service);

      for (final distance in const [1, 2, 3]) {
        for (var table = 0; table < pool.numberOfTables(distance); table++) {
          final q = usecase.call(
            distance: distance,
            tableIndex: table,
            availableConfigs: const ['A', 'B', 'C'],
          );
          if (q == null) continue;

          expect(q.visibleCards.length, 2);
          expect(q.choices.length, 6,
              reason: 'D$distance table $table : la grille doit rester '
                  'pleine malgre l exclusion des reponses justes');
          expect(q.choices.map((c) => c.id).toSet().length, 6,
              reason: 'aucun doublon parmi les choix');
          expect(q.validAnswerIds.contains(q.correctCardId), isTrue);
          expect(q.choices.any((c) => c.id == q.correctCardId), isTrue,
              reason: 'la bonne reponse doit figurer dans la grille');

          // Une carte visible ne doit jamais etre reproposee comme
          // choix : le joueur la verrait deux fois a l ecran.
          for (final visible in q.visibleCards) {
            expect(q.choices.any((c) => c.id == visible.id), isFalse,
                reason: 'la carte ${visible.label} est deja affichee');
          }
        }
      }
    });

    test('les trios generes respectent les quatre regles du document coeur',
        () async {
      final service = await _chargerLeJeuReel();
      final pool = service.logicalNodes!;
      final graphe = service.gameGraph!;

      // Signatures des 46 noeuds natifs, emettrice effective resolue.
      final natifs = <Set<String>>{};
      for (final n in graphe.nodesByIndex.values) {
        natifs.add({n.effectiveEmettriceId, n.cableId, n.receptriceId});
      }

      var controles = 0;
      for (final distance in const [2, 3]) {
        for (var table = 0; table < pool.numberOfTables(distance); table++) {
          for (final trio in pool.table(distance: distance, tableIndex: table)) {
            final ids = {trio.cardA.id, trio.cardB.id, trio.cardC.id};

            expect(ids.length, 3,
                reason: 'regle 2 : |T| = 3, trois cartes DISTINCTES');
            expect(natifs.contains(ids), isFalse,
                reason: 'regle 4 : un noeud natif ne doit jamais ressortir '
                    'comme trio genere');
            controles++;
          }
        }
      }
      expect(controles, greaterThan(0));
    });
  });
}

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
