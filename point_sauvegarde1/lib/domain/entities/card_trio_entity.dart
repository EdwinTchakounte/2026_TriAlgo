// =============================================================
// FICHIER : lib/domain/entities/card_trio_entity.dart
// ROLE   : Definir la structure d'un TRIO de cartes (E + C = R)
// COUCHE : Domain > Entities
// =============================================================
//
// QU'EST-CE QU'UN TRIO ?
// ----------------------
// Un trio est la relation OFFICIELLE entre 3 cartes :
//   - UNE Emettrice  (image de base)
//   - UN Cable       (image de transformation)
//   - UNE Receptrice (image resultat)
//
// C'est dans la table "card_trios" que l'on enregistre quelle
// combinaison est VALIDE. C'est la SOURCE DE VERITE du jeu.
//
// Quand un joueur choisit une image dans la ScrollView,
// le serveur verifie si le trio (E, C, R) existe dans cette table.
// Si oui -> bonne reponse. Si non -> mauvaise reponse.
//
// SYSTEME DE DISTANCES :
// ----------------------
//   D1 : E1 (+) C1 = R1           -> trio de 3 images
//   D2 : R1 (+) C2 = R2           -> trio de 3 images (R1 joue le role d'E)
//   D3 : R2 (+) C3 = R3           -> trio de 3 images (R2 joue le role d'E)
//
//   Une chaine complete = 7 images et 3 trios lies entre eux.
//
// REFERENCE : Recueil de conception v3.0, section 3.3
// =============================================================

/// Represente un TRIO valide de cartes dans TRIALGO.
///
/// Un trio est la combinaison officielle : Emettrice + Cable = Receptrice.
/// C'est l'unite fondamentale du jeu — chaque question est basee sur un trio.
///
/// La table `card_trios` en base de donnees contient tous les trios valides.
/// La contrainte UNIQUE(emettrice_id, cable_id, receptrice_id) garantit
/// qu'un meme trio ne peut pas etre enregistre deux fois.
class CardTrioEntity {

  // =============================================================
  // PROPRIETE : id
  // =============================================================
  // Type    : String
  // Contenu : UUID v4 genere par PostgreSQL
  //
  // Identifiant unique de CE trio specifique.
  // Genere automatiquement a l'INSERT par gen_random_uuid().
  // =============================================================
  final String id;

  // =============================================================
  // PROPRIETE : emettriceId
  // =============================================================
  // Type    : String
  // Contenu : UUID de la carte Emettrice de ce trio
  //
  // Pointe vers la carte qui joue le ROLE d'Emettrice dans ce trio.
  //
  // ATTENTION : pour un trio D2 ou D3, l'emettrice est en fait
  // une RECEPTRICE du trio precedent qui joue le role d'emettrice.
  //   D1 : emettriceId -> pointe vers l'Emettrice de base (lion_base)
  //   D2 : emettriceId -> pointe vers la Receptrice D1 (lion_miroir_h)
  //   D3 : emettriceId -> pointe vers la Receptrice D2 (lion_miroir_h_teinte_rouge)
  //
  // Contrainte SQL : NOT NULL REFERENCES cards(id)
  //   -> DOIT exister et pointer vers une carte valide
  // =============================================================
  final String emettriceId;

  // =============================================================
  // PROPRIETE : cableId
  // =============================================================
  // Type    : String
  // Contenu : UUID de la carte Cable de ce trio
  //
  // Pointe vers l'image de transformation utilisee.
  // C'est toujours une carte de type CardType.cable.
  //
  // Exemples :
  //   Trio D1 du lion : cableId -> miroir_h (fleches symetriques)
  //   Trio D2 du lion : cableId -> teinte_rouge (palette rouge)
  //   Trio D3 du lion : cableId -> fragmentation_3 (cercle divise en 3)
  //
  // Contrainte SQL : NOT NULL REFERENCES cards(id)
  // =============================================================
  final String cableId;

  // =============================================================
  // PROPRIETE : receptriceId
  // =============================================================
  // Type    : String
  // Contenu : UUID de la carte Receptrice de ce trio
  //
  // Pointe vers l'image RESULTAT de la fusion E (+) C.
  // C'est toujours une carte de type CardType.receptrice.
  //
  // Exemples :
  //   Trio D1 du lion : receptriceId -> lion_miroir_h
  //   Trio D2 du lion : receptriceId -> lion_miroir_h_teinte_rouge
  //   Trio D3 du lion : receptriceId -> lion_miroir_h_teinte_rouge_fragmente
  //
  // Contrainte SQL : NOT NULL REFERENCES cards(id)
  // =============================================================
  final String receptriceId;

  // =============================================================
  // PROPRIETE : distanceLevel
  // =============================================================
  // Type    : int
  // Valeurs : 1, 2 ou 3
  //
  // Distance de CE trio dans la chaine de transformations.
  //   1 : trio de base (E1 + C1 = R1)
  //   2 : extension   (R1 + C2 = R2)
  //   3 : extension   (R2 + C3 = R3)
  //
  // Ce champ est REDUNDANT avec les cartes (on pourrait le deduire
  // des distance_level des cartes), mais il est stocke pour
  // faciliter les requetes SQL de filtrage :
  //   SELECT * FROM card_trios WHERE distance_level = 1
  // est beaucoup plus rapide que de joindre la table cards.
  //
  // Contrainte SQL : NOT NULL DEFAULT 1
  // =============================================================
  final int distanceLevel;

  // =============================================================
  // PROPRIETE : parentTrioId
  // =============================================================
  // Type    : String? (nullable)
  // Contenu : UUID du trio PRECEDENT dans la chaine
  //
  // Cree un lien de parentee entre les trios d'une meme chaine.
  //
  // Valeurs :
  //   Trio D1 : null (c'est le premier trio, pas de parent)
  //   Trio D2 : pointe vers le trio D1
  //   Trio D3 : pointe vers le trio D2
  //
  // Utilite : permet de reconstituer la chaine complete
  // pour un affichage pedagogique ou une galerie.
  //
  // Contrainte SQL : UUID REFERENCES card_trios(id), null si D1
  // =============================================================
  final String? parentTrioId;

  // =============================================================
  // PROPRIETE : difficulty
  // =============================================================
  // Type    : double
  // Valeurs : entre 0.0 (trivial) et 1.0 (expert)
  // Defaut  : 0.5
  //
  // Difficulte globale de CE trio.
  // Prend en compte la complexite visuelle des 3 cartes.
  // Utilise pour selectionner des trios adaptes au niveau du joueur.
  //
  // Contrainte SQL : FLOAT DEFAULT 0.5
  // =============================================================
  final double difficulty;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Memes principes que CardEntity :
  //   - "const" pour l'optimisation memoire
  //   - Parametres nommes avec "required" pour les obligatoires
  //   - Valeurs par defaut pour les optionnels
  // =============================================================

  /// Cree une nouvelle instance de [CardTrioEntity].
  ///
  /// [id], [emettriceId], [cableId], [receptriceId] et [distanceLevel]
  /// sont obligatoires car un trio n'a pas de sens sans ses 3 cartes.
  const CardTrioEntity({
    required this.id,              // UUID du trio
    required this.emettriceId,     // UUID de l'Emettrice
    required this.cableId,         // UUID du Cable
    required this.receptriceId,    // UUID de la Receptrice
    required this.distanceLevel,   // 1, 2 ou 3
    this.parentTrioId,             // null si D1, UUID si D2/D3
    this.difficulty = 0.5,         // Difficulte moyenne par defaut
  });
}
