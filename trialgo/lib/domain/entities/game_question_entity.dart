// =============================================================
// FICHIER : lib/domain/entities/game_question_entity.dart
// ROLE   : Definir la structure d'une QUESTION de jeu
// COUCHE : Domain > Entities
// =============================================================
//
// QU'EST-CE QU'UNE QUESTION ?
// ---------------------------
// Une question est ce que le joueur voit a l'ecran pendant le jeu.
// Elle est composee de :
//
//   1. DEUX images VISIBLES en haut de l'ecran
//      (2 des 3 cartes du trio : E, C ou R selon la config)
//
//   2. UNE image MASQUEE affichee comme "???"
//      (la 3eme carte que le joueur doit trouver)
//
//   3. DIX images dans la ScrollView du bas
//      (1 correcte + 9 distracteurs melanges)
//
//   4. UNE configuration (A, B ou C)
//      qui definit quelle carte est masquee
//
// CONFIGURATIONS :
// ----------------
//   Config A : Emettrice + Cable visibles   -> trouver la Receptrice  (facile)
//   Config B : Emettrice + Receptrice       -> trouver le Cable       (moyen)
//   Config C : Cable + Receptrice           -> trouver l'Emettrice   (difficile)
//
// REFERENCE : Recueil de conception v3.0, section 6
// =============================================================

// On importe CardEntity car une question contient des cartes.
// C'est un import INTRA-COUCHE (Domain -> Domain) : autorise.
import 'package:trialgo/domain/entities/card_entity.dart';

/// Represente une question de jeu telle qu'affichee au joueur.
///
/// Une question est generee par le serveur (Edge Function `generate-question`)
/// a partir d'un trio aleatoire et de 9 distracteurs.
///
/// L'ecran de jeu utilise cette entite pour :
///   - Afficher les 2 images visibles en haut
///   - Afficher le "???" pour la carte masquee
///   - Peupler la ScrollView avec les 10 choix
///   - Connaitre la bonne reponse pour la validation
class GameQuestionEntity {

  // =============================================================
  // PROPRIETE : visibleCards
  // =============================================================
  // Type    : List<CardEntity>
  // Contenu : les 2 cartes VISIBLES affichees en haut de l'ecran
  // Taille  : toujours 2 elements
  //
  // "List<CardEntity>" signifie : une liste ordonnee d'objets CardEntity.
  // Le "<CardEntity>" est un GENERIQUE : il precise le type des elements.
  // Sans generique, la liste accepterait n'importe quoi (pas de securite).
  //
  // Le contenu depend de la configuration :
  //   Config A : [Emettrice, Cable]      -> le joueur voit E et C
  //   Config B : [Emettrice, Receptrice] -> le joueur voit E et R
  //   Config C : [Cable, Receptrice]     -> le joueur voit C et R
  //
  // L'ordre dans la liste correspond a l'ordre d'affichage
  // de gauche a droite sur l'ecran.
  // =============================================================
  final List<CardEntity> visibleCards;

  // =============================================================
  // PROPRIETE : maskedCard
  // =============================================================
  // Type    : CardEntity
  // Contenu : la carte que le joueur doit TROUVER
  //
  // C'est la 3eme carte du trio, celle qui est affichee comme "???".
  // Le joueur ne voit PAS cette image directement, mais doit
  // l'identifier parmi les 10 propositions dans la ScrollView.
  //
  // Le contenu depend de la configuration :
  //   Config A : maskedCard = Receptrice
  //   Config B : maskedCard = Cable
  //   Config C : maskedCard = Emettrice
  //
  // Apres la reponse (correcte ou incorrecte), cette image
  // est revelee avec une surbrillance verte pendant 1.5 secondes.
  // =============================================================
  final CardEntity maskedCard;

  // =============================================================
  // PROPRIETE : choices
  // =============================================================
  // Type    : List<CardEntity>
  // Contenu : les 10 images proposees dans la ScrollView du bas
  // Taille  : toujours 10 elements (1 correcte + 9 distracteurs)
  //
  // Cette liste est MELANGEE (shuffled) : la bonne reponse
  // n'est pas toujours a la meme position.
  //
  // Regles de selection des distracteurs :
  //   - Tous du MEME TYPE que la carte masquee
  //     (si masquee = Receptrice, les 9 distracteurs sont des Receptrices)
  //   - Choisis pour etre visuellement PROCHES (meme distance, memes tags)
  //     mais pas identiques a la bonne reponse
  //
  // Le joueur fait defiler cette liste horizontalement et tape
  // sur l'image qu'il pense etre la bonne reponse.
  // =============================================================
  final List<CardEntity> choices;

  // =============================================================
  // PROPRIETE : config
  // =============================================================
  // Type    : String
  // Valeurs : 'A', 'B' ou 'C'
  //
  // La configuration definit le SCHEMA de la question :
  //
  //   'A' (facile - niveaux 1-5) :
  //     Visible : Emettrice + Cable
  //     Masquee : Receptrice
  //     Question : "Quelle image complete ce trio ?"
  //     Le joueur doit imaginer le RESULTAT de la transformation.
  //
  //   'B' (moyen - niveaux 4-18) :
  //     Visible : Emettrice + Receptrice
  //     Masquee : Cable
  //     Question : "Quelle image-cable relie ces deux images ?"
  //     Le joueur doit identifier la TRANSFORMATION appliquee.
  //
  //   'C' (difficile - niveaux 8+) :
  //     Visible : Cable + Receptrice
  //     Masquee : Emettrice
  //     Question : "Quelle est l'image de depart ?"
  //     Le joueur doit deviner l'image ORIGINALE avant transformation.
  //
  // La config est choisie par le serveur selon le niveau du joueur
  // (voir GameConstants.getLevelConfig).
  // =============================================================
  final String config;

  // =============================================================
  // PROPRIETE : correctCardId
  // =============================================================
  // Type    : String
  // Contenu : UUID de la carte qui est la BONNE REPONSE
  //
  // C'est l'ID de maskedCard, stocke separement pour faciliter
  // la verification rapide de la reponse.
  //
  // Quand le joueur tape sur une image dans la ScrollView,
  // on compare l'ID de l'image tapee avec correctCardId :
  //   if (selectedCard.id == question.correctCardId) -> BONNE REPONSE
  //   sinon -> MAUVAISE REPONSE
  //
  // Note : cette verification locale est un APERCU.
  // La vraie validation se fait cote serveur (Edge Function validate-answer)
  // pour empecher la triche (manipulation du code client).
  // =============================================================
  final String correctCardId;

  // =============================================================
  // PROPRIETE : trioId
  // =============================================================
  // Type    : String
  // Contenu : UUID du trio dans la table card_trios
  //
  // Identifie LE trio qui a servi a generer cette question.
  // Envoye au serveur lors de la validation pour la tracabilite.
  //
  // Utilite :
  //   - Logs et debugging (quel trio a pose probleme ?)
  //   - Eviter de re-poser le meme trio dans la meme session
  //     (le champ exclude_ids de generate-question utilise cet ID)
  //   - Statistiques (quels trios sont les plus souvent rates ?)
  // =============================================================
  final String trioId;

  // =============================================================
  // PROPRIETE : timeLimitSeconds
  // =============================================================
  // Type    : int
  // Contenu : temps maximum en secondes pour repondre
  // Exemple : 40 (secondes)
  //
  // Determine par le niveau du joueur (voir GameConstants).
  // Le chronometre commence quand les images sont chargees
  // et s'arrete quand le joueur tape une image ou que le temps expire.
  //
  // Si le temps expire :
  //   - La question est comptee comme mauvaise reponse
  //   - MALUS_TIMEOUT est applique (-1 vie, -5 pts session)
  //   - La bonne image est revelee en surbrillance
  //   - Passage a la question suivante apres 2 secondes
  // =============================================================
  final int timeLimitSeconds;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  /// Cree une nouvelle question de jeu.
  ///
  /// Tous les parametres sont obligatoires car une question
  /// n'a pas de sens sans ses composants.
  const GameQuestionEntity({
    required this.visibleCards,       // 2 cartes visibles
    required this.maskedCard,        // La carte a trouver
    required this.choices,           // 10 propositions (1 + 9)
    required this.config,            // 'A', 'B' ou 'C'
    required this.correctCardId,     // ID de la bonne reponse
    required this.trioId,            // ID du trio source
    required this.timeLimitSeconds,  // Temps max en secondes
  });
}
