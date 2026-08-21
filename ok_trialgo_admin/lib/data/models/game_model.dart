// =============================================================
// FICHIER : game_model.dart (DTO data)
// ROLE    : Serialisation Game <-> JSON Supabase
// =============================================================
//
// Pourquoi un DTO separe de l'entite domain ?
// - Le DTO connait le format JSON exact renvoye par PostgREST.
// - L'entite ne devrait rien savoir de Supabase. Si demain on
//   passe a Firestore, on remplace le DTO, l'entite ne bouge pas.
// =============================================================

import '../../domain/entities/game.dart';

class GameModel {
  GameModel._();

  // Construit une Game depuis la row PostgREST. On parse les
  // dates en UTC ; si createdAt est null (jamais en pratique
  // pour une row valide), on retombe sur DateTime.now() pour
  // ne pas crasher le flux.
  static Game fromJson(Map<String, dynamic> j) {
    return Game(
      id: j['id'] as String,
      name: j['name'] as String,
      description: j['description'] as String?,
      theme: j['theme'] as String?,
      coverImage: j['cover_image'] as String?,
      isActive: (j['is_active'] as bool?) ?? true,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  // Construit le payload d'INSERT. On omet id (genere par DB) et
  // createdAt (DEFAULT NOW()). is_active = true par defaut.
  static Map<String, dynamic> toInsert({
    required String name,
    String? description,
    String? theme,
  }) {
    return {
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (theme != null && theme.isNotEmpty) 'theme': theme,
      'is_active': true,
    };
  }

  // Payload d'UPDATE partiel : on inclut seulement les champs
  // non-null. Permet de modifier juste le nom sans toucher au
  // theme par exemple.
  static Map<String, dynamic> toUpdate({
    String? name,
    String? description,
    String? theme,
    bool? isActive,
  }) {
    final m = <String, dynamic>{};
    if (name != null) m['name'] = name;
    if (description != null) m['description'] = description;
    if (theme != null) m['theme'] = theme;
    if (isActive != null) m['is_active'] = isActive;
    return m;
  }
}
