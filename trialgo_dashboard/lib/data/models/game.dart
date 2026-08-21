// =============================================================
// FICHIER : game.dart
// ROLE    : Modele Dart pour la table SQL "games"
// =============================================================
//
// Un game = un univers de cartes (ex: Savane, Ocean). Chaque
// game a son propre set de cards et nodes (foreign key).
// =============================================================

class Game {
  final String id;
  final String name;
  final String? description;
  final String? theme;
  final String? coverImage;
  final bool isActive;

  Game({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    required this.coverImage,
    required this.isActive,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      theme: json['theme'] as String?,
      coverImage: json['cover_image'] as String?,
      // is_active a un DEFAULT TRUE en DB, mais on garde la
      // verification au cas ou la colonne serait NULL pour un row
      // ancien.
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}
