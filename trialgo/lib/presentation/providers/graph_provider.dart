// =============================================================
// FICHIER : lib/presentation/providers/graph_provider.dart
// ROLE   : Providers Riverpod pour le graphe de jeu
// COUCHE : Presentation > Providers
// =============================================================
//
// CE FICHIER EXPOSE :
// -------------------
//   1. graphRepositoryProvider     : le repository (injection)
//   2. buildGraphUseCaseProvider   : le usecase de construction
//   3. graphSyncServiceProvider    : le service de sync orchestrateur
//   4. graphStateProvider          : l'etat du graphe (loading/ready/error)
//   5. generateQuestionProvider    : le usecase de generation de questions
//
// FLOW :
// ------
// Au lancement de l'app :
//   - Le splash lit graphStateProvider
//   - GraphNotifier declenche graphSyncService.syncAndBuild()
//   - Quand termine, l'etat passe a "ready"
//   - Le splash navigue vers la home
//
// Pendant le jeu :
//   - t_game_page lit generateQuestionProvider
//   - Appelle .call(distance: X, availableConfigs: ...) pour
//     obtenir une question
//
// REFERENCE : Architecture Riverpod, projet TRIALGO
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/data/repositories/graph_repository_impl.dart';
import 'package:trialgo/data/services/collective_verifier.dart';
import 'package:trialgo/data/services/graph_sync_service.dart';
import 'package:trialgo/data/services/played_nodes_tracker.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/domain/usecases/build_graph_usecase.dart';
import 'package:trialgo/domain/usecases/generate_game_question_usecase.dart';
import 'package:trialgo/domain/usecases/verify_trio_cards_usecase.dart';

// =============================================================
// PROVIDER 1 : graphRepositoryProvider
// =============================================================
// Fournit l'instance unique de GraphRepository (interface Domain).
// L'implementation concrete est GraphRepositoryImpl (cote Data).
//
// "Provider" : provider Riverpod basique qui retourne une valeur
// constante (instance creee une seule fois et reutilisee).
//
// Pourquoi exposer l'interface plutot que l'implementation ?
//   - Decouplage : les autres providers dependent de GraphRepository,
//     pas de GraphRepositoryImpl. Plus facile a tester (mock).
//   - Respect du principe d'inversion de dependance.
// =============================================================

/// Fournit l'instance unique de [GraphRepository].
final graphRepositoryProvider = Provider<GraphRepository>((ref) {
  return GraphRepositoryImpl();
});

// =============================================================
// PROVIDER 2 : buildGraphUseCaseProvider
// =============================================================
// Fournit l'instance unique de BuildGraphUseCase.
// Logique pure, pas de dependance externe.
// =============================================================

/// Fournit l'instance unique de [BuildGraphUseCase].
final buildGraphUseCaseProvider = Provider<BuildGraphUseCase>((ref) {
  return BuildGraphUseCase();
});

// =============================================================
// PROVIDER 3 : graphSyncServiceProvider
// =============================================================
// Fournit l'instance unique de GraphSyncService.
// Ce service est le point central : il contient le graphe,
// le catalogue de cartes et les noeuds logiques precomputes.
//
// SINGLETON : Riverpod garde la meme instance pendant toute la
// vie de l'app. La sync ne se fait qu'une fois.
// =============================================================

/// Fournit l'instance unique de [GraphSyncService].
final graphSyncServiceProvider = Provider<GraphSyncService>((ref) {
  return GraphSyncService(
    repository: ref.read(graphRepositoryProvider),
    buildGraph: ref.read(buildGraphUseCaseProvider),
  );
});

// =============================================================
// NOTE : L'ancien graphStateProvider (qui lancait la sync dans son
// constructeur) a ete supprime au profit de TGraphLoadingPage qui
// gere directement le chargement avec le gameId selectionne.
// =============================================================

// =============================================================
// PROVIDER : playedNodesTrackerProvider
// =============================================================
// Fournit la passerelle vers /api/me/played-nodes.
// =============================================================

/// Fournit l'instance unique de [PlayedNodesTracker].
///
/// Singleton lui aussi : il ne porte pas d'etat, mais rien ne
/// justifie d'en recreer un a chaque question.
final playedNodesTrackerProvider = Provider<PlayedNodesTracker>((ref) {
  return PlayedNodesTracker();
});

// =============================================================
// PROVIDER : generateQuestionProvider
// =============================================================
// Fournit le usecase de generation de questions.
//
// C'est ICI que le tracking memoire est raccorde au serveur : on
// passe au usecase un callback qui delegue au PlayedNodesTracker.
//
// Le gameId n'est pas fige a la construction : il est relu sur le
// GraphSyncService au moment ou le callback se declenche. C'est
// necessaire parce que le joueur peut changer de jeu sans que ce
// provider soit reconstruit -- le service, lui, est toujours a jour
// puisque syncAndBuild met currentGameId a la valeur du jeu charge.
//
// IMPORTANT : ce usecase a un ETAT INTERNE mutable (les cles de
// tracking _usedTrackingKeys). Il doit donc etre un singleton,
// sinon le tracking serait perdu entre les questions. Riverpod
// garantit cela avec "Provider".
// =============================================================

/// Fournit l'instance unique de [GenerateGameQuestionUseCase].
///
/// Le tracking des noeuds joues est conserve dans cette instance,
/// donc elle doit etre partagee pendant toute la session.
final generateQuestionProvider = Provider<GenerateGameQuestionUseCase>((ref) {
  final sync = ref.read(graphSyncServiceProvider);
  final tracker = ref.read(playedNodesTrackerProvider);

  return GenerateGameQuestionUseCase(
    sync,
    onNodePlayed: (trackingKey) {
      // Pas de jeu charge -> rien a rattacher, on laisse tomber.
      final gameId = sync.currentGameId;
      if (gameId == null) return;

      // Non bloquant : le tracker poste en tache de fond.
      tracker.marquerJoue(gameId: gameId, trackingKey: trackingKey);
    },
  );
});

// =============================================================
// PROVIDER : verifyTrioCardsProvider
// =============================================================
// Fournit le usecase de verification d'un trio pour le mode collectif.
// Pas d'etat interne : c'est un use case pur (stateless), mais on le
// singleton-ise pour eviter la creation d'instance a chaque scan.
// =============================================================

/// Fournit l'instance unique de [CollectiveVerifier].
final collectiveVerifierProvider = Provider<CollectiveVerifier>((ref) {
  return CollectiveVerifier();
});

/// Fournit l'instance unique de [VerifyTrioCardsUseCase].
///
/// Le resolveur distant est branche ici : le usecase interroge
/// d'abord /api/games/{gid}/verify-collective, et ne retombe sur le
/// graphe local que si le serveur est injoignable ou hors sujet.
///
/// Comme pour generateQuestionProvider, le gameId est relu sur le
/// GraphSyncService au moment de l'appel et non fige a la
/// construction, pour suivre un changement de jeu.
final verifyTrioCardsProvider = Provider<VerifyTrioCardsUseCase>((ref) {
  final sync = ref.read(graphSyncServiceProvider);
  final verifier = ref.read(collectiveVerifierProvider);

  return VerifyTrioCardsUseCase(
    sync,
    verifierDistant: (nodeIndex) => verifier.verifier(
      gameId: sync.currentGameId,
      nodeIndex: nodeIndex,
    ),
  );
});
