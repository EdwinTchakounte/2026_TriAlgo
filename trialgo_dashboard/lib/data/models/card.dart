// =============================================================
// FICHIER : card.dart
// ROLE    : Modele Dart pour la table SQL "cards"
// =============================================================
//
// Une carte TRIALGO est une image + un libelle + un type. Elle
// appartient a un jeu (game_id) et peut etre referencee par un
// node (en tant qu'emettrice, cable, ou receptrice).
//
// Les modeles sont immutables (final partout) pour eviter les
// surprises avec Riverpod : on remplace l'instance entiere
// quand on veut "mettre a jour", ce qui declenche les rebuilds.
// =============================================================

import 'card_type.dart';

class GameCard {
  // UUID Postgres genere cote serveur (gen_random_uuid).
  // Stocke en String cote client (pas de type natif Dart UUID).
  final String id;

  // FK vers le jeu auquel appartient cette carte.
  // Pour le MVP du dashboard on travaille toujours sur le meme
  // game_id (Savane), mais on garde la colonne pour multi-jeux.
  final String gameId;

  // Libelle court affiche sous l'image (ex: "Lion", "Rotation").
  final String label;

  // URL HTTPS de l'image (Storage public ou hote externe).
  // C'est cette URL que CachedNetworkImage va telecharger.
  final String imagePath;

  // Role metier (emettrice / cable / receptrice).
  // Migration 005 a backfille les cartes existantes.
  final CardType type;

  // Date de creation (utile pour trier par "plus recent").
  final DateTime createdAt;

  GameCard({
    required this.id,
    required this.gameId,
    required this.label,
    required this.imagePath,
    required this.type,
    required this.createdAt,
  });

  // =========================================================
  // CONVERSION JSON (Supabase REST renvoie du Map<String, dynamic>)
  // =========================================================
  // PostgREST serialise :
  //   - UUID en string
  //   - timestamptz en string ISO 8601
  //   - text en string
  // On parse avec verification minimale ; si Supabase renvoie un
  // null inattendu, on laisse exploser pour ne pas masquer un bug.
  // =========================================================
  factory GameCard.fromJson(Map<String, dynamic> json) {
    return GameCard(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      label: json['label'] as String,
      imagePath: json['image_path'] as String,
      type: CardType.fromDb(json['card_type'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // Pour les INSERT : on omet id et created_at (defauts SQL),
  // on ne fournit que les champs metier. Supabase remplira le
  // reste et renverra l'objet complet.
  Map<String, dynamic> toInsertJson() {
    return {
      'game_id': gameId,
      'label': label,
      'image_path': imagePath,
      'card_type': type.dbKey,
    };
  }
}
