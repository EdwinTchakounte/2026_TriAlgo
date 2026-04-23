// =============================================================
// FICHIER : lib/data/models/game_model.dart
// ROLE   : Model JSON pour la table games
// COUCHE : Data > Models
// =============================================================

import 'package:trialgo/domain/entities/game_entity.dart';

class GameModel extends GameEntity {
  const GameModel({
    required super.id,
    required super.name,
    super.description,
    super.theme,
    super.coverImage,
    super.isActive,
  });

  /// Cree un [GameModel] depuis un Map JSON retourne par Supabase.
  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      theme: json['theme'] as String?,
      coverImage: json['cover_image'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Convertit en JSON pour INSERT.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'theme': theme,
      'cover_image': coverImage,
      'is_active': isActive,
    };
  }
}
