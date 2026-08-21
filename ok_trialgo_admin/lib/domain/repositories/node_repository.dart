// =============================================================
// FICHIER : node_repository.dart (interface domain)
// ROLE    : CRUD des noeuds (trios) du graphe
// =============================================================

import '../../core/utils/result.dart';
import '../entities/game_node.dart';

abstract class NodeRepository {
  // Liste TOUS les noeuds d'un game, ordonne par node_index.
  // Cette liste sert a la fois pour le picker de parent (etape 3)
  // et pour la preview de l'arbre (etape 4).
  Future<Result<List<GameNode>>> listByGame(String gameId);

  // Calcule le prochain node_index libre pour ce game.
  // Renvoie MAX(node_index) + 1, ou 1 si aucune ligne.
  // Note : pas garanti race-safe a 100%, mais largement suffisant
  // pour un MVP single-admin.
  Future<Result<int>> nextNodeIndex(String gameId);

  // Cree un trio. Selon depth/parent :
  //   - D1   : emettriceId DOIT etre fourni, parentNodeId = null
  //   - D>=2 : parentNodeId DOIT etre fourni ; emettriceId = null
  //            (deduit du parent cote app/jeu)
  Future<Result<GameNode>> createTrio({
    required String gameId,
    required int nodeIndex,
    required String? emettriceId,
    required String cableId,
    required String receptriceId,
    required String? parentNodeId,
    required int depth,
  });

  // Suppression : la contrainte ON DELETE CASCADE cote DB
  // supprime aussi les descendants. On affichera donc un
  // confirmation dialog cote UI avant d'appeler ca.
  Future<Result<void>> delete(String nodeId);
}
