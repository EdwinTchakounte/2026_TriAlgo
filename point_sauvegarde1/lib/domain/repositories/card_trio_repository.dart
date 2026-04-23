// =============================================================
// FICHIER : lib/domain/repositories/card_trio_repository.dart
// ROLE   : Definir l'INTERFACE du repository de trios
// COUCHE : Domain > Repositories
// =============================================================
//
// Ce repository gere les operations sur les TRIOS (combinaisons
// valides de 3 cartes : Emettrice + Cable = Receptrice).
//
// Il fournit deux operations essentielles :
//   1. Recuperer un trio aleatoire pour generer une question
//   2. Verifier si un trio est coherent (validation de reponse)
//
// REFERENCE : Recueil de conception v3.0, sections 3.3 et 4.5
// =============================================================

// Import de l'entite CardTrioEntity pour typer les retours.
import 'package:trialgo/domain/entities/card_trio_entity.dart';

/// Interface definissant les operations sur les trios de cartes.
///
/// Un trio represente la relation E (+) C = R.
/// La table `card_trios` est la SOURCE DE VERITE du jeu :
/// si un trio existe dans cette table, la combinaison est valide.
abstract class CardTrioRepository {

  // =============================================================
  // METHODE : getRandomTrio
  // =============================================================
  // Recupere un trio ALEATOIRE pour generer une question de jeu.
  //
  // Parametres :
  //   "int distance" : filtre par distance (1, 2 ou 3)
  //     -> On ne veut que des trios D1 pour les premiers niveaux
  //
  //   "List<String> excludeIds" : liste d'IDs de trios a EXCLURE
  //     -> Evite de reposer le meme trio dans la meme session
  //     -> Par defaut : liste vide (aucune exclusion)
  //     -> "const []" : liste vide constante (allocation a la compilation)
  //
  // SQL equivalent :
  //   SELECT * FROM card_trios
  //   WHERE distance_level = $distance
  //     AND id NOT IN ($excludeIds)
  //   ORDER BY RANDOM()
  //   LIMIT 1
  //
  // "ORDER BY RANDOM()" : PostgreSQL choisit une ligne au hasard.
  // C'est ce qui rend chaque session de jeu unique.
  // =============================================================

  /// Recupere un trio aleatoire d'une distance donnee.
  ///
  /// [distance]   : la distance du trio voulu (1, 2 ou 3).
  /// [excludeIds] : IDs des trios deja utilises dans cette session.
  ///
  /// Retourne un [CardTrioEntity] aleatoire.
  /// Leve une exception si aucun trio n'est disponible.
  Future<CardTrioEntity> getRandomTrio({
    required int distance,
    List<String> excludeIds = const [],
  });

  // =============================================================
  // METHODE : isCoherent
  // =============================================================
  // Verifie si un trio (E, C, R) existe dans la table card_trios.
  //
  // C'est LA verification centrale du jeu :
  //   - Le joueur choisit une image dans la ScrollView
  //   - On prend les IDs des 3 cartes (E visible, C visible, R choisie)
  //   - On verifie si cette combinaison est enregistree
  //   - Si oui -> BONNE REPONSE
  //   - Si non -> MAUVAISE REPONSE
  //
  // Parametres : les 3 UUIDs des cartes du trio
  //   emettriceId  : ID de la carte Emettrice (ou Receptrice jouant ce role)
  //   cableId      : ID de la carte Cable
  //   receptriceId : ID de la carte Receptrice
  //
  // Retour : bool (true = trio valide, false = trio invalide)
  //
  // SQL equivalent (via la fonction PostgreSQL is_coherent) :
  //   SELECT EXISTS (
  //     SELECT 1 FROM card_trios
  //     WHERE emettrice_id  = $emettriceId
  //       AND cable_id      = $cableId
  //       AND receptrice_id = $receptriceId
  //   );
  //
  // IMPORTANT : dans le jeu final, cette verification se fait
  // cote SERVEUR (Edge Function validate-answer) pour empecher
  // la triche. Cette methode cote client est un apercu rapide.
  // =============================================================

  /// Verifie si le trio (E, C, R) est une combinaison valide.
  ///
  /// Retourne `true` si ce trio existe dans la table `card_trios`,
  /// `false` sinon.
  ///
  /// [emettriceId]  : UUID de la carte jouant le role d'Emettrice.
  /// [cableId]      : UUID de la carte Cable.
  /// [receptriceId] : UUID de la carte Receptrice.
  Future<bool> isCoherent({
    required String emettriceId,
    required String cableId,
    required String receptriceId,
  });

  // =============================================================
  // METHODE : getTriosByDistance
  // =============================================================
  // Recupere TOUS les trios d'une distance donnee.
  //
  // Cas d'utilisation :
  //   - Compter combien de trios sont disponibles par distance
  //   - Verifier qu'il y a assez de contenu pour un niveau
  //   - Debug et administration
  //
  // SQL equivalent :
  //   SELECT * FROM card_trios WHERE distance_level = $distance
  // =============================================================

  /// Recupere tous les trios d'une distance donnee.
  ///
  /// [distance] : le niveau de distance (1, 2 ou 3).
  ///
  /// Retourne une liste de [CardTrioEntity].
  Future<List<CardTrioEntity>> getTriosByDistance(int distance);
}
