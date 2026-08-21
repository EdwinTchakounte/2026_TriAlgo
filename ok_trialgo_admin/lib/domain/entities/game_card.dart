// =============================================================
// FICHIER : game_card.dart (entite domain)
// ROLE    : Modeliser une carte du jeu
// =============================================================
//
// Une carte = image + label + role (emettrice/cable/receptrice),
// rattachee a un game. Les trios la combineront en E + C => R.
//
// L'image_path est une URL publique Supabase Storage (bucket
// "trialgo-cards", lecture sans auth). On la stocke en string
// car on s'en sert dans CachedNetworkImage cote UI.
//
// Note : on appelle cette classe "GameCard" (pas "Card") pour
// eviter le conflit de nom avec material.dart::Card (le widget).
// Sans ce prefixe, chaque import devrait gerer un alias.
// =============================================================

import 'card_type.dart';

class GameCard {
  final String id;
  final String gameId;
  final String label;
  // URL publique de l'image (bucket Supabase Storage).
  final String imagePath;
  // Role de la carte dans le trio. Nullable parce que le schema
  // tolere encore quelques cartes seed sans type (avant migration
  // 005). On filtrera ces cartes-la dans l'UI si rencontrees.
  final CardType? type;
  final DateTime createdAt;

  const GameCard({
    required this.id,
    required this.gameId,
    required this.label,
    required this.imagePath,
    required this.type,
    required this.createdAt,
  });

  GameCard copyWith({
    String? id,
    String? gameId,
    String? label,
    String? imagePath,
    CardType? type,
    DateTime? createdAt,
  }) {
    return GameCard(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      label: label ?? this.label,
      imagePath: imagePath ?? this.imagePath,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
