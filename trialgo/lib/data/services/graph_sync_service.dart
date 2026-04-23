// =============================================================
// FICHIER : lib/data/services/graph_sync_service.dart
// ROLE   : Synchroniser le graphe d'un jeu specifique
// COUCHE : Data > Services
// =============================================================
//
// NOUVELLE LOGIQUE :
// ------------------
// On sync UN jeu a la fois (par gameId). Si l'utilisateur change
// de jeu, on refait la sync pour le nouveau jeu.
//
// Le service expose :
//   - syncAndBuild(gameId)  : charge et construit le graphe du jeu
//   - cards / gameGraph / logicalNodes : donnees du jeu actif
//   - reset()               : efface les donnees avant un changement
// =============================================================

import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/repositories/graph_repository.dart';
import 'package:trialgo/domain/usecases/build_graph_usecase.dart';
import 'package:trialgo/domain/usecases/generate_logical_nodes_usecase.dart';

/// Service de synchronisation du graphe (par jeu).
class GraphSyncService {

  final GraphRepository _repository;
  final BuildGraphUseCase _buildGraph;
  late final GenerateLogicalNodesUseCase _generateLogicalNodes;

  /// Toutes les cartes du jeu actuel, indexees par UUID.
  Map<String, GraphCardEntity> cards = {};

  /// Le graphe construit en memoire.
  GameGraph? gameGraph;

  /// Pool des noeuds logiques precomputes (D1/D2/D3).
  LogicalNodesPool? logicalNodes;

  /// ID du jeu actuellement charge (pour eviter les doubles sync).
  String? currentGameId;

  GraphSyncService({
    required GraphRepository repository,
    required BuildGraphUseCase buildGraph,
  })  : _repository = repository,
        _buildGraph = buildGraph {
    _generateLogicalNodes = GenerateLogicalNodesUseCase(this);
  }

  /// Synchronise et construit le graphe d'un jeu.
  ///
  /// Si [gameId] est deja charge, ne refait rien (sauf si force = true).
  Future<void> syncAndBuild(String gameId, {bool force = false}) async {
    if (currentGameId == gameId && !force && isReady) return;

    // Reset avant de charger un nouveau jeu.
    if (currentGameId != gameId) {
      reset();
    }

    currentGameId = gameId;

    // Charger les cartes du jeu.
    final cardList = await _repository.getAllCards(gameId);
    cards = {for (final c in cardList) c.id: c};

    // Charger les noeuds du jeu.
    final nodeList = await _repository.getAllNodes(gameId);

    // Construire le graphe + precomputer les noeuds logiques.
    gameGraph = _buildGraph(nodeList);
    logicalNodes = _generateLogicalNodes(gameGraph!);
  }

  /// True si le service est pret (apres un syncAndBuild reussi).
  bool get isReady =>
      gameGraph != null && cards.isNotEmpty && logicalNodes != null;

  /// Reset : efface toutes les donnees en memoire.
  void reset() {
    cards = {};
    gameGraph = null;
    logicalNodes = null;
    currentGameId = null;
  }

  /// Recupere une carte par son UUID.
  GraphCardEntity getCard(String id) {
    final card = cards[id];
    if (card == null) {
      throw StateError('Carte $id introuvable dans le cache local.');
    }
    return card;
  }
}
