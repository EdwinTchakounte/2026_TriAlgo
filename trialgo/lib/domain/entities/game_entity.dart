// =============================================================
// FICHIER : lib/domain/entities/game_entity.dart
// ROLE   : Representer un jeu TRIALGO
// COUCHE : Domain > Entities
// =============================================================
//
// Un "jeu" dans TRIALGO est un set de cartes + noeuds organise
// autour d'un theme (Savane, Ocean, Foret, etc.). Chaque jeu a son
// propre graphe de 50 noeuds.
//
// Un utilisateur peut avoir plusieurs jeux actives (chacun via un
// code d'activation different). Le mode courant est indique dans
// user_profiles.selected_game_id.
// =============================================================

class GameEntity {

  /// Identifiant unique du jeu.
  final String id;

  /// Nom du jeu (ex: "TRIALGO Savane").
  final String name;

  /// Description courte.
  final String? description;

  /// Theme (ex: "savane", "ocean").
  final String? theme;

  /// URL ou path de la pochette du jeu.
  final String? coverImage;

  /// True si le jeu est disponible pour activation.
  final bool isActive;

  const GameEntity({
    required this.id,
    required this.name,
    this.description,
    this.theme,
    this.coverImage,
    this.isActive = true,
  });
}
