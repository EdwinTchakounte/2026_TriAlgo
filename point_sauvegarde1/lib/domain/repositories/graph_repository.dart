// =============================================================
// FICHIER : lib/domain/repositories/graph_repository.dart
// ROLE   : Interface du repository pour le graphe de jeu
// COUCHE : Domain > Repositories
// =============================================================

import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';

/// Interface pour les operations sur le graphe.
///
/// TOUTES les methodes sont filtrees par [gameId] car une BDD
/// peut contenir plusieurs jeux. On ne sync qu'un jeu a la fois.
abstract class GraphRepository {

  /// Recupere TOUTES les cartes d'un jeu specifique.
  Future<List<GraphCardEntity>> getAllCards(String gameId);

  /// Recupere TOUS les noeuds d'un jeu specifique, tries par index.
  Future<List<GraphNodeEntity>> getAllNodes(String gameId);

  // Admin operations (optionnelles - utilisees par l'interface admin).

  Future<GraphCardEntity> insertCard({
    required String gameId,
    required String label,
    required String imagePath,
  });

  Future<GraphNodeEntity> insertRootNode({
    required String gameId,
    required int nodeIndex,
    required String emettriceId,
    required String cableId,
    required String receptriceId,
  });

  Future<GraphNodeEntity> insertChildNode({
    required String gameId,
    required int nodeIndex,
    required String cableId,
    required String receptriceId,
    required String parentNodeId,
    required int depth,
  });

  Future<void> deleteNode(String nodeId);
  Future<void> deleteCard(String cardId);
}
