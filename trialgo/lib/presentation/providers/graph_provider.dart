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
import 'package:trialgo/data/services/graph_sync_service.dart';
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
// PROVIDER : generateQuestionProvider
// =============================================================
// Fournit le usecase de generation de questions.
//
// IMPORTANT : ce usecase a un ETAT INTERNE mutable
// (les cles de tracking _usedTrackingKeys). Il doit donc etre
// un singleton, sinon le tracking serait perdu entre les questions.
// Riverpod garantit cela avec "Provider".
// =============================================================

/// Fournit l'instance unique de [GenerateGameQuestionUseCase].
///
/// Le tracking des noeuds joues est conserve dans cette instance,
/// donc elle doit etre partagee pendant toute la session.
final generateQuestionProvider = Provider<GenerateGameQuestionUseCase>((ref) {
  return GenerateGameQuestionUseCase(ref.read(graphSyncServiceProvider));
});

// =============================================================
// PROVIDER : verifyTrioCardsProvider
// =============================================================
// Fournit le usecase de verification d'un trio pour le mode collectif.
// Pas d'etat interne : c'est un use case pur (stateless), mais on le
// singleton-ise pour eviter la creation d'instance a chaque scan.
// =============================================================

/// Fournit l'instance unique de [VerifyTrioCardsUseCase].
final verifyTrioCardsProvider = Provider<VerifyTrioCardsUseCase>((ref) {
  return VerifyTrioCardsUseCase(ref.read(graphSyncServiceProvider));
});
