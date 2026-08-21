// =============================================================
// FICHIER : test/tracking_questions_jouees_test.dart
// ROLE   : Verrouiller la persistance des questions deja jouees
// =============================================================
//
// CE QUE CES TESTS PROTEGENT
// --------------------------
// GenerateGameQuestionUseCase evite de reposer deux fois le meme
// trio. Trois proprietes doivent tenir, et chacune correspond a un
// bug qui a reellement existe :
//
//   1. seedPlayedKeys ecarte les trios deja vus lors des sessions
//      precedentes. Sans ca, le Set repartait vide a chaque
//      lancement et le joueur tournait en rond.
//
//   2. Chaque trio consomme est notifie UNE SEULE FOIS via le
//      callback, pour ne pas marteler POST /api/me/played-nodes.
//
//   3. Une table epuisee repioche dans la table complete au lieu
//      de renvoyer null. Depuis que les cles sont persistees,
//      renvoyer null rendrait le niveau definitivement injouable.
//
// POURQUOI PAS DE MOCK HTTP ICI
// -----------------------------
// Le usecase est dans la couche Domain : il ne connait que le
// GraphSyncService et un callback. On construit donc un vrai
// graphe minuscule en memoire et on observe le callback. Aucun
// reseau, aucun faux client Dio, test instantane.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:trialgo/data/services/graph_sync_service.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/domain/usecases/build_graph_usecase.dart';
import 'package:trialgo/domain/usecases/generate_game_question_usecase.dart';

// =============================================================
// FAUX REPOSITORY
// =============================================================
// On fabrique un jeu jouable minimal : assez de cartes pour que
// _pickDistractors trouve de quoi remplir, et trois noeuds racine
// distincts pour avoir trois trios D1 dans la meme table.
// =============================================================

/// Fabrique une carte de test.
GraphCardEntity _carte(String id) => GraphCardEntity(
      id: id,
      label: 'Carte $id',
      imagePath: 'https://exemple.test/$id.jpg',
    );

/// Construit un GraphSyncService deja peuple, sans passer par le reseau.
Future<GraphSyncService> _serviceAvecTroisNoeuds() async {
  // 9 cartes : 3 noeuds x 3 cartes, toutes distinctes.
  final cartes = <GraphCardEntity>[
    for (var i = 1; i <= 9; i++) _carte('c$i'),
  ];

  // 3 noeuds racine independants -> 3 trios D1 dans la table 0.
  final noeuds = <GraphNodeEntity>[
    for (var n = 0; n < 3; n++)
      GraphNodeEntity(
        id: 'n${n + 1}',
        nodeIndex: n + 1,
        depth: 1,
        emettriceId: 'c${n * 3 + 1}',
        cableId: 'c${n * 3 + 2}',
        receptriceId: 'c${n * 3 + 3}',
        parentNodeId: null,
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
  group('Tracking des questions jouees', () {
    test('seedPlayedKeys ecarte les trios deja vus', () async {
      final service = await _serviceAvecTroisNoeuds();

      // Session 1 : on consomme un trio et on note sa cle.
      final session1 = GenerateGameQuestionUseCase(service);
      final q1 = session1.call(
        distance: 1,
        tableIndex: 0,
        availableConfigs: const ['A'],
      );
      expect(q1, isNotNull, reason: 'le graphe de test doit produire un trio');
      final dejaVue = q1!.trackingKey;

      // Session 2 : nouvelle instance (comme apres un redemarrage de
      // l'app), amorcee avec ce que le serveur aurait renvoye.
      final session2 = GenerateGameQuestionUseCase(service)
        ..seedPlayedKeys({dejaVue});

      final q2 = session2.call(
        distance: 1,
        tableIndex: 0,
        availableConfigs: const ['A'],
      );

      expect(q2, isNotNull);
      expect(
        q2!.trackingKey,
        isNot(dejaVue),
        reason: 'un trio amorce comme deja joue ne doit pas ressortir',
      );
    });

    test('chaque trio n est notifie qu une seule fois', () async {
      final service = await _serviceAvecTroisNoeuds();
      final notifiees = <String>[];

      final usecase = GenerateGameQuestionUseCase(
        service,
        onNodePlayed: notifiees.add,
      );

      // On consomme largement plus de questions qu'il n'y a de trios
      // (3 trios disponibles, 10 tirages) : les tirages en trop
      // repiochent forcement dans du deja-joue.
      for (var i = 0; i < 10; i++) {
        usecase.call(
          distance: 1,
          tableIndex: 0,
          availableConfigs: const ['A'],
        );
      }

      expect(
        notifiees.length,
        notifiees.toSet().length,
        reason: 'aucune trackingKey ne doit etre notifiee deux fois',
      );
      expect(
        notifiees.length,
        3,
        reason: 'les 3 trios de la table doivent avoir ete notifies',
      );
    });

    test('une table epuisee repioche au lieu de bloquer la partie',
        () async {
      final service = await _serviceAvecTroisNoeuds();

      // On marque TOUS les trios comme deja joues, ce qui est
      // exactement l'etat d'un joueur revenant apres avoir tout vu.
      final usecase = GenerateGameQuestionUseCase(service);
      final toutes = <String>{};
      for (var i = 0; i < 3; i++) {
        final q = usecase.call(
          distance: 1,
          tableIndex: 0,
          availableConfigs: const ['A'],
        );
        if (q != null) toutes.add(q.trackingKey);
      }
      expect(toutes.length, 3);

      final revenant = GenerateGameQuestionUseCase(service)
        ..seedPlayedKeys(toutes);

      final question = revenant.call(
        distance: 1,
        tableIndex: 0,
        availableConfigs: const ['A'],
      );

      expect(
        question,
        isNotNull,
        reason:
            'table epuisee -> on rejoue ; renvoyer null rendrait le '
            'niveau definitivement injouable',
      );
    });

    test('une table vide renvoie bien null', () async {
      final service = await _serviceAvecTroisNoeuds();
      final usecase = GenerateGameQuestionUseCase(service);

      // Distance 5 : aucun trio possible avec 3 noeuds isoles.
      final question = usecase.call(
        distance: 5,
        tableIndex: 0,
        availableConfigs: const ['A'],
      );

      expect(question, isNull);
    });
  });
}

// =============================================================
// FAUX REPOSITORY
// =============================================================

class _FauxGraphRepository implements GraphRepository {
  _FauxGraphRepository({required this.cartes, required this.noeuds});

  final List<GraphCardEntity> cartes;
  final List<GraphNodeEntity> noeuds;

  @override
  Future<List<GraphCardEntity>> getAllCards(String gameId) async => cartes;

  @override
  Future<List<GraphNodeEntity>> getAllNodes(String gameId) async => noeuds;

  // -----------------------------------------------------------
  // Les 5 methodes d'ECRITURE du contrat.
  //
  // Elles sont purement Supabase et sans aucun appelant dans
  // l'app (cf. CLAUDE.md section 7). Elles ne font partie de ce
  // faux que parce que Dart exige d'implementer tout le contrat.
  // Les appeler dans un test serait une erreur de test, d'ou le
  // UnimplementedError explicite plutot qu'un retour bidon.
  // -----------------------------------------------------------

  @override
  Future<GraphCardEntity> insertCard({
    required String gameId,
    required String label,
    required String imagePath,
  }) =>
      throw UnimplementedError('ecriture non utilisee par ces tests');

  @override
  Future<GraphNodeEntity> insertRootNode({
    required String gameId,
    required int nodeIndex,
    required String emettriceId,
    required String cableId,
    required String receptriceId,
  }) =>
      throw UnimplementedError('ecriture non utilisee par ces tests');

  @override
  Future<GraphNodeEntity> insertChildNode({
    required String gameId,
    required int nodeIndex,
    required String parentNodeId,
    required String cableId,
    required String receptriceId,
    required int depth,
  }) =>
      throw UnimplementedError('ecriture non utilisee par ces tests');

  @override
  Future<void> deleteNode(String nodeId) =>
      throw UnimplementedError('ecriture non utilisee par ces tests');

  @override
  Future<void> deleteCard(String cardId) =>
      throw UnimplementedError('ecriture non utilisee par ces tests');
}
