// =============================================================
// FICHIER : game_repository.dart (interface domain)
// ROLE    : CRUD des Games
// =============================================================

import '../../core/utils/result.dart';
import '../entities/game.dart';

abstract class GameRepository {
  // Liste de tous les games (active ou non). On affiche les
  // inactifs avec un badge "inactif" pour ne pas les perdre.
  Future<Result<List<Game>>> listAll();

  // Cree un nouveau game. id est genere cote DB.
  // Renvoie l'objet Game complet (avec id + createdAt remplis).
  Future<Result<Game>> create({
    required String name,
    String? description,
    String? theme,
  });

  // Update partiel : on passe seulement les champs a modifier.
  // Champs null = on ne touche pas.
  Future<Result<Game>> update({
    required String id,
    String? name,
    String? description,
    String? theme,
    bool? isActive,
  });
}
