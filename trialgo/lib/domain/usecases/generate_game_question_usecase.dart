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

  /// L'ID de la carte effectivement masquee (celle qui sera revelee).
  ///
  /// C'est la reponse que l'interface met en avant apres coup. Pour
  /// savoir si le joueur a eu juste, utiliser [validAnswerIds] : a
  /// partir de D2, plusieurs cartes different peuvent completer
  /// correctement la paire visible.
  final String correctCardId;

  // =============================================================
  // CHAMP : validAnswerIds
  // =============================================================
  // TOUTES les cartes qui completent valablement la paire visible.
  //
  // Contient toujours [correctCardId], et parfois davantage : voir
  // le long commentaire de LogicalNodesPool.completionsFor, qui
  // explique pourquoi les configs B et C sont structurellement
  // ambigues (jusqu'a 9 reponses justes a D5).
  //
  // Deux usages, complementaires :
  //   1. GENERATION - ces cartes sont retirees du vivier de
  //      distracteurs, pour qu'une seule reponse juste figure
  //      parmi les 6 choix. C'est la correction principale : le
  //      joueur ne peut plus tomber sur un piege insoluble.
  //   2. VERIFICATION - si malgre tout l'une d'elles apparait
  //      (catalogue trop petit pour fournir assez de distracteurs,
  //      pool reconstruit entre-temps), la reponse est acceptee.
  //      Filet de securite : mieux vaut valider a tort que
  //      sanctionner un joueur qui a raison.
  // =============================================================

  /// Toutes les reponses justes possibles (contient [correctCardId]).
  final Set<String> validAnswerIds;

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
    required this.validAnswerIds,
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

  // =============================================================
  // CHAMP : _onNodePlayed
  // =============================================================
  // Callback appele a chaque fois qu'un noeud logique est consomme.
  //
  // POURQUOI UN CALLBACK PLUTOT QU'UNE DEPENDANCE ?
  // -----------------------------------------------
  // Ce usecase vit dans la couche Domain. Il n'a pas le droit de
  // connaitre Dio, une datasource HTTP ou ApiConfig : ce serait
  // une dependance Domain -> Data, exactement l'inversion que
  // l'architecture du projet cherche a eviter.
  //
  // Un simple `void Function(String)` laisse la couche Presentation
  // (graph_provider) brancher ce qu'elle veut : en production le
  // PlayedNodesTracker qui appelle POST /api/me/played-nodes, dans
  // un test un espion qui accumule les cles dans une liste.
  //
  // Le callback est volontairement SYNCHRONE et sans valeur de
  // retour : la generation d'une question ne doit jamais attendre
  // le reseau. Le tracker se debrouille pour poster en tache de
  // fond et absorber ses propres erreurs.
  // =============================================================

  /// Appele avec la trackingKey a chaque noeud logique consomme.
  final void Function(String trackingKey)? _onNodePlayed;

  /// Cree le usecase avec le service de sync.
  ///
  /// [onNodePlayed] est optionnel : sans lui, le tracking reste
  /// purement en memoire (comportement historique, utile en test).
  GenerateGameQuestionUseCase(
    this._syncService, {
    void Function(String trackingKey)? onNodePlayed,
  }) : _onNodePlayed = onNodePlayed;

  // =============================================================
  // GETTER : usedKeys
  // =============================================================

  /// Les cles de tracking des noeuds deja joues (lecture seule).
  Set<String> get usedKeys => Set.unmodifiable(_usedTrackingKeys);

  // =============================================================
  // METHODE : seedPlayedKeys
  // =============================================================
  // Pre-remplit le tracking avec les cles deja jouees par ce joueur
  // lors de ses sessions PRECEDENTES, relues depuis le serveur.
  //
  // Sans cet amorcage, le Set repartait vide a chaque lancement de
  // l'application : le joueur retombait indefiniment sur les memes
  // trios. Le serveur gardait bien l'historique (table
  // user_played_nodes), personne ne le relisait.
  //
  // Appele une fois, juste apres syncAndBuild, par la page de
  // chargement du graphe.
  // =============================================================

  /// Amorce le tracking avec des cles deja jouees (venues du serveur).
  void seedPlayedKeys(Iterable<String> keys) {
    _usedTrackingKeys.addAll(keys);
  }

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

    // Une table vide n'a rien a proposer : c'est le seul cas ou on
    // renvoie null (le jeu n'a pas assez de noeuds pour ce niveau).
    if (currentTable.isEmpty) return null;

    // Filtrer ceux non encore joues.
    final jamaisJoues = currentTable
        .where((node) => !_usedTrackingKeys.contains(node.trackingKey))
        .toList();

    // =============================================================
    // EPUISEMENT DE LA TABLE : on rejoue au lieu de bloquer
    // =============================================================
    // Avant, `available.isEmpty` renvoyait null, ce que t_game_page
    // traduit par _endSessionWithResults() : la partie se terminait
    // seche, au milieu d'un niveau.
    //
    // Tant que le tracking vivait uniquement en memoire, le cas
    // etait rare et se reparait tout seul au redemarrage de l'app.
    // Maintenant que les cles jouees sont persistees et relues au
    // demarrage, l'epuisement devient DEFINITIF : un joueur ayant
    // vu tous les trios d'une table ne pourrait plus jamais rejouer
    // ce niveau. Inacceptable.
    //
    // On degrade donc proprement : l'anti-doublon devient une
    // PREFERENCE ("ne repete rien tant qu'il reste du neuf") et non
    // plus une condition d'arret. Table epuisee -> on repioche dans
    // la table complete.
    // =============================================================
    final available =
        jamaisJoues.isNotEmpty ? jamaisJoues : currentTable;

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

    // =============================================================
    // REPONSES JUSTES : il peut y en avoir plusieurs
    // =============================================================
    // On demande au pool toutes les cartes qui completent valablement
    // la paire visible. A D1 (config A) il n'y en a qu'une ; a partir
    // de D2, masquer autre chose que la receptrice finale en donne
    // systematiquement 2 a 9 (cf. LogicalNodesPool.completionsFor).
    //
    // L'union avec maskedCard.id est defensive : si le pool a ete
    // reconstruit entre le tirage et ici, la carte masquee reste
    // par construction une reponse juste.
    // =============================================================
    final reponsesJustes = <String>{
      maskedCard.id,
      ...pool.completionsFor(visibleCards[0].id, visibleCards[1].id),
    };

    // Generer les distracteurs depuis le catalogue local.
    //
    // On exclut les 3 cartes du trio (pour eviter les doublons) ET
    // toutes les autres reponses justes : sans cette seconde
    // exclusion, une carte correcte pouvait se retrouver parmi les
    // distracteurs, et le joueur qui la choisissait etait compte
    // faux tout en ayant raison.
    final distractors = _pickDistractors(
      exclude: <String>{
        ...logicalNode.allCards.map((c) => c.id),
        ...reponsesJustes,
      },
      count: distractorCount,
    );

    // =============================================================
    // CATALOGUE TROP PETIT : completer sans jamais pieger
    // =============================================================
    // Exclure toutes les reponses justes retrecit le vivier. Sur un
    // jeu bien fourni (plusieurs dizaines de cartes) l'effet est
    // negligeable, mais sur un petit catalogue on pourrait ne plus
    // avoir assez de distracteurs et afficher une grille de 2 ou
    // 3 cartes -- ce qui rend la reponse evidente.
    //
    // On complete donc avec les reponses justes restantes plutot
    // que de laisser la grille depeuplee. C'est sans danger : ces
    // cartes sont dans validAnswerIds, donc le joueur qui en choisit
    // une est compte JUSTE. On perd un peu de difficulte, jamais
    // l'equite.
    if (distractors.length < distractorCount) {
      final complement = _pickDistractors(
        exclude: <String>{
          ...logicalNode.allCards.map((c) => c.id),
          ...distractors.map((c) => c.id),
        },
        count: distractorCount - distractors.length,
      );
      distractors.addAll(complement);
    }

    // Assembler les choix : 1 bonne + 5 distracteurs = 6 cartes.
    // Melanger pour que la bonne reponse ne soit pas toujours en 1ere.
    final choices = [maskedCard, ...distractors]..shuffle(_random);

    // Marquer ce noeud logique comme joue, en memoire ET cote serveur.
    //
    // On ne notifie le serveur que sur une VRAIE premiere fois : si
    // la cle etait deja dans le Set (cas du rejeu apres epuisement),
    // .add renvoie false et on evite un POST inutile. L'endpoint est
    // idempotent, mais autant ne pas le solliciter pour rien.
    final premiereFois = _usedTrackingKeys.add(logicalNode.trackingKey);
    if (premiereFois) {
      _onNodePlayed?.call(logicalNode.trackingKey);
    }

    return GameQuestion(
      visibleCards: visibleCards,
      maskedCard: maskedCard,
      choices: choices,
      correctCardId: maskedCard.id,
      validAnswerIds: reponsesJustes,
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
