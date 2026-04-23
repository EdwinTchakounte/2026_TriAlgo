// =============================================================
// FICHIER : lib/domain/usecases/generate_game_question_usecase.dart
// ROLE   : Generer une question de jeu a partir des noeuds logiques
// COUCHE : Domain > Usecases
// =============================================================
//
// CE QUE FAIT CE USECASE :
// ------------------------
// 1. Recoit la distance et la config du niveau
// 2. Tire un noeud logique non joue dans le tableau correspondant
// 3. Applique la config (A/B/C) pour determiner la carte masquee
// 4. Genere les distracteurs (5 cartes du catalogue local)
// 5. Retourne une GameQuestion complete
//
// PERFORMANCE :
// -------------
// Les noeuds logiques sont DEJA precomputes (par GenerateLogicalNodesUseCase
// au moment de la sync). Ce usecase fait juste un tirage et un assemblage.
// Pas de generation de combinaisons a la volee.
//
// TRACKING :
// ----------
// Les cles des noeuds joues sont stockees dans _usedTrackingKeys.
// Apres chaque question, la cle est ajoutee a ce Set.
// Au prochain tirage, on filtre pour exclure les cles deja utilisees.
//
// REFERENCE : Discussion architecture graphe, avril 2026
// =============================================================

import 'dart:math';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';
import 'package:trialgo/domain/entities/logical_node_entity.dart';
import 'package:trialgo/data/services/graph_sync_service.dart';

// =============================================================
// CLASSE : GameQuestion
// =============================================================
// Une question de jeu prete a etre affichee.
//
// Contient :
//   - Les 2 cartes visibles (haut de l'ecran)
//   - La carte masquee (a trouver, "?")
//   - La grille de 6 choix (1 bonne + 5 distracteurs, melanges)
//   - L'ID de la bonne reponse pour la verification
//   - Le noeud logique source (pour le debug et le tracking)
// =============================================================

/// Une question de jeu prete a etre affichee.
class GameQuestion {

  /// Les 2 cartes visibles affichees au joueur.
  final List<GraphCardEntity> visibleCards;

  /// La carte masquee que le joueur doit trouver.
  final GraphCardEntity maskedCard;

  /// Les 6 choix proposes (1 bonne + 5 distracteurs), melanges.
  final List<GraphCardEntity> choices;

  /// L'ID de la bonne reponse (pour la verification).
  final String correctCardId;

  /// Le noeud logique source (utile pour le debug).
  final LogicalNodeEntity sourceLogicalNode;

  /// La configuration appliquee : 'A', 'B' ou 'C'.
  final String config;

  /// Les noeuds natifs impliques dans cette question.
  List<GraphNodeEntity> get involvedNodes => sourceLogicalNode.sourceNodes;

  /// Cle de tracking unique de la question.
  String get trackingKey => sourceLogicalNode.trackingKey;

  /// Cree une question de jeu.
  const GameQuestion({
    required this.visibleCards,
    required this.maskedCard,
    required this.choices,
    required this.correctCardId,
    required this.sourceLogicalNode,
    required this.config,
  });
}


/// Usecase : genere une question de jeu a partir des noeuds logiques.
class GenerateGameQuestionUseCase {

  /// Le service de sync qui contient les noeuds logiques precomputes.
  final GraphSyncService _syncService;

  /// Generateur de nombres aleatoires.
  final Random _random = Random();

  /// Ensemble des cles de noeuds logiques deja joues.
  /// Mutable : des cles sont ajoutees apres chaque question.
  /// Reset entre les sessions de jeu via [reset].
  final Set<String> _usedTrackingKeys = {};

  /// Cree le usecase avec le service de sync.
  GenerateGameQuestionUseCase(this._syncService);

  // =============================================================
  // GETTER : usedKeys
  // =============================================================

  /// Les cles de tracking des noeuds deja joues (lecture seule).
  Set<String> get usedKeys => Set.unmodifiable(_usedTrackingKeys);

  // =============================================================
  // METHODE : call
  // =============================================================
  // Methode principale. Genere une question pour la distance et
  // la liste de configs disponibles.
  //
  // [distance]         : 1, 2 ou 3
  // [availableConfigs] : configs autorisees pour ce niveau (ex: ['A', 'B'])
  // [distractorCount]  : nombre de distracteurs (defaut 5)
  //
  // Retourne null si tous les noeuds logiques de cette distance
  // ont deja ete joues (epuisement).
  // =============================================================

  /// Genere une question de jeu pour la [distance] et la [tableIndex].
  ///
  /// La partie pioche UNIQUEMENT dans la table specifiee pour eviter
  /// que deux trios de la meme chaine se retrouvent dans la meme partie.
  ///
  /// [distance]         : 1, 2, 3, 4 ou 5.
  /// [tableIndex]       : index de la table (0 a maxTables-1 pour cette distance).
  /// [availableConfigs] : liste des configs autorisees (ex: ['A', 'B']).
  /// [distractorCount]  : nombre de distracteurs (defaut 5).
  ///
  /// Retourne null si aucun noeud logique non joue n'est disponible
  /// dans la table specifiee.
  GameQuestion? call({
    required int distance,
    required int tableIndex,
    required List<String> availableConfigs,
    int distractorCount = 5,
  }) {
    // Recuperer le pool de noeuds logiques precomputes.
    final pool = _syncService.logicalNodes;
    if (pool == null) return null;

    // Recuperer UNIQUEMENT la table specifiee.
    final currentTable = pool.table(
      distance: distance,
      tableIndex: tableIndex,
    );

    // Filtrer ceux non encore joues.
    final available = currentTable
        .where((node) => !_usedTrackingKeys.contains(node.trackingKey))
        .toList();

    // Plus aucun noeud disponible -> session epuisee.
    if (available.isEmpty) return null;

    // Tirer un noeud logique au hasard.
    final logicalNode = available[_random.nextInt(available.length)];

    // Choisir une config au hasard parmi celles disponibles.
    final config = availableConfigs[_random.nextInt(availableConfigs.length)];

    // Determiner les cartes visibles et la carte masquee selon la config.
    // Le trio est (cardA, cardB, cardC) :
    //   Config A : visible cardA + cardB, masquee cardC
    //   Config B : visible cardA + cardC, masquee cardB
    //   Config C : visible cardB + cardC, masquee cardA
    late List<GraphCardEntity> visibleCards;
    late GraphCardEntity maskedCard;

    switch (config) {
      case 'A':
        visibleCards = [logicalNode.cardA, logicalNode.cardB];
        maskedCard = logicalNode.cardC;
      case 'B':
        visibleCards = [logicalNode.cardA, logicalNode.cardC];
        maskedCard = logicalNode.cardB;
      case 'C':
        visibleCards = [logicalNode.cardB, logicalNode.cardC];
        maskedCard = logicalNode.cardA;
      default:
        // Securite : config inconnue, on utilise A par defaut.
        visibleCards = [logicalNode.cardA, logicalNode.cardB];
        maskedCard = logicalNode.cardC;
    }

    // Generer les distracteurs depuis le catalogue local.
    // On exclut les 3 cartes du trio pour eviter les doublons.
    final excludeIds = logicalNode.allCards.map((c) => c.id).toSet();
    final distractors = _pickDistractors(
      exclude: excludeIds,
      count: distractorCount,
    );

    // Assembler les choix : 1 bonne + 5 distracteurs = 6 cartes.
    // Melanger pour que la bonne reponse ne soit pas toujours en 1ere.
    final choices = [maskedCard, ...distractors]..shuffle(_random);

    // Marquer ce noeud logique comme joue.
    _usedTrackingKeys.add(logicalNode.trackingKey);

    return GameQuestion(
      visibleCards: visibleCards,
      maskedCard: maskedCard,
      choices: choices,
      correctCardId: maskedCard.id,
      sourceLogicalNode: logicalNode,
      config: config,
    );
  }

  // =============================================================
  // METHODE PRIVEE : _pickDistractors
  // =============================================================
  // Choisit des distracteurs au hasard dans le catalogue local.
  //
  // [exclude] : IDs des cartes a exclure (les cartes de la question).
  // [count]   : nombre de distracteurs voulus.
  //
  // Retourne une liste de cartes choisies aleatoirement parmi
  // toutes les cartes du catalogue, sauf celles exclues.
  // =============================================================

  /// Pioche [count] distracteurs au hasard, en excluant [exclude].
  List<GraphCardEntity> _pickDistractors({
    required Set<String> exclude,
    required int count,
  }) {
    // Toutes les cartes sauf celles exclues.
    final pool = _syncService.cards.values
        .where((c) => !exclude.contains(c.id))
        .toList();

    // Melanger et prendre les N premiers.
    pool.shuffle(_random);
    return pool.take(count).toList();
  }

  // =============================================================
  // METHODE : reset
  // =============================================================

  /// Remet a zero le tracking. Tous les noeuds redeviennent disponibles.
  /// Appele entre les sessions de jeu.
  void reset() {
    _usedTrackingKeys.clear();
  }
}
