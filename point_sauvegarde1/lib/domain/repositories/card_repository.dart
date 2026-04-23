// =============================================================
// FICHIER : lib/domain/repositories/card_repository.dart
// ROLE   : Definir l'INTERFACE du repository de cartes
// COUCHE : Domain > Repositories
// =============================================================
//
// QU'EST-CE QU'UN REPOSITORY ?
// ----------------------------
// Un repository est un CONTRAT (interface) qui definit QUELLES
// operations sont disponibles sur les donnees, SANS dire COMMENT
// elles sont implementees.
//
// Analogie : c'est comme un menu de restaurant.
//   - Le menu (interface) liste les plats disponibles.
//   - La cuisine (implementation) prepare les plats.
//   - Le client (usecase) commande un plat sans savoir comment il est fait.
//
// POURQUOI UNE INTERFACE ?
// ------------------------
// 1. SEPARATION : la couche Domain ne sait pas que Supabase existe.
//    Elle definit juste "je veux pouvoir charger des cartes".
//
// 2. TESTABILITE : pour les tests, on peut creer une fausse
//    implementation (mock) qui retourne des donnees en dur,
//    sans avoir besoin d'une vraie connexion reseau.
//
// 3. FLEXIBILITE : si on change de backend (ex: Supabase -> Firebase),
//    on ne modifie que l'implementation dans la couche Data.
//    La couche Domain et Presentation restent inchangees.
//
// SYNTAXE DART :
// --------------
// "abstract class" : classe qui ne peut PAS etre instanciee directement.
//   On ne peut pas faire : final repo = CardRepository(); // ERREUR
//   On doit faire :       final repo = CardRepositoryImpl(); // OK (sous-classe)
//
// Les methodes n'ont PAS de corps (pas d'accolades {}).
// Elles sont juste DECLAREES : type de retour + nom + parametres.
// L'implementation (le corps) sera dans CardRepositoryImpl (couche Data).
//
// REFERENCE : Recueil de conception v3.0, section 9.1
// =============================================================

// Import de l'entite CardEntity pour typer les retours des methodes.
// C'est un import INTRA-COUCHE (Domain -> Domain) : autorise.
import 'package:trialgo/domain/entities/card_entity.dart';

/// Interface definissant les operations disponibles sur les cartes.
///
/// Cette classe abstraite est le CONTRAT entre la couche Domain
/// (qui utilise les cartes) et la couche Data (qui les fournit).
///
/// L'implementation concrete [CardRepositoryImpl] se trouve dans
/// `lib/data/repositories/card_repository_impl.dart` et utilise
/// Supabase pour recuperer les donnees.
///
/// Chaque methode retourne un [Future] car les donnees viennent
/// du reseau (Supabase) et le chargement est asynchrone.
abstract class CardRepository {

  // =============================================================
  // METHODE : getCardById
  // =============================================================
  // Signature : Future<CardEntity> getCardById(String id)
  //
  // "Future<CardEntity>" signifie :
  //   - "Future" : le resultat n'est pas disponible immediatement
  //     (il faut attendre la reponse du serveur)
  //   - "<CardEntity>" : quand le resultat arrive, c'est un objet CardEntity
  //
  // "String id" : parametre positionnel (pas de "required" car pas nomme)
  //   C'est l'UUID de la carte a recuperer.
  //
  // Pas de corps {} : c'est une methode ABSTRAITE.
  // Le ";" a la fin indique que la declaration est complete
  // sans implementation. Le corps sera dans CardRepositoryImpl.
  //
  // SQL equivalent :
  //   SELECT * FROM cards WHERE id = $id AND is_active = true LIMIT 1
  //
  // Cas d'utilisation dans TRIALGO :
  //   - Charger les details d'une carte selectionnee dans la galerie
  //   - Recuperer une carte par son ID lors de la validation d'un trio
  // =============================================================

  /// Recupere UNE carte par son identifiant unique.
  ///
  /// [id] : UUID de la carte dans la table `cards`.
  ///
  /// Retourne la [CardEntity] correspondante.
  /// Leve une exception si la carte n'existe pas ou n'est pas active.
  Future<CardEntity> getCardById(String id);

  // =============================================================
  // METHODE : getCardsByType
  // =============================================================
  // Signature : Future<List<CardEntity>> getCardsByType(CardType type)
  //
  // "Future<List<CardEntity>>" signifie :
  //   - Le resultat sera une LISTE de CardEntity
  //   - La liste peut etre vide si aucune carte ne correspond
  //
  // "CardType type" : le type de carte a filtrer (enum).
  //   CardType.emettrice  -> toutes les Emettrices actives
  //   CardType.cable      -> tous les Cables actifs
  //   CardType.receptrice -> toutes les Receptrices actives
  //
  // SQL equivalent :
  //   SELECT * FROM cards WHERE card_type = $type AND is_active = true
  //
  // Cas d'utilisation dans TRIALGO :
  //   - Charger tous les cables pour generer les distracteurs
  //   - Charger toutes les emettrices pour la galerie
  // =============================================================

  /// Recupere toutes les cartes actives d'un type donne.
  ///
  /// [type] : le type de carte voulu (emettrice, cable ou receptrice).
  ///
  /// Retourne une liste de [CardEntity]. Liste vide si aucune carte.
  Future<List<CardEntity>> getCardsByType(CardType type);

  // =============================================================
  // METHODE : getCardsByDistance
  // =============================================================
  // Signature : Future<List<CardEntity>> getCardsByDistance(int distance)
  //
  // "int distance" : le niveau de distance (1, 2 ou 3).
  //
  // SQL equivalent :
  //   SELECT * FROM cards WHERE distance_level = $distance AND is_active = true
  //
  // Cas d'utilisation dans TRIALGO :
  //   - Charger les cartes d'une distance specifique pour un niveau
  //   - Generer des distracteurs de meme distance
  // =============================================================

  /// Recupere toutes les cartes actives d'une distance donnee.
  ///
  /// [distance] : le niveau de distance (1, 2 ou 3).
  ///
  /// Retourne une liste de [CardEntity]. Liste vide si aucune carte.
  Future<List<CardEntity>> getCardsByDistance(int distance);

  // =============================================================
  // METHODE : getCardsByTypeAndDistance
  // =============================================================
  // Combine les deux filtres precedents pour plus de precision.
  //
  // SQL equivalent :
  //   SELECT * FROM cards
  //   WHERE card_type = $type
  //     AND distance_level = $distance
  //     AND is_active = true
  //
  // Cas d'utilisation dans TRIALGO :
  //   - Charger toutes les Receptrices D1 pour les distracteurs
  //   - Charger tous les Cables D2 pour un niveau intermediaire
  // =============================================================

  /// Recupere les cartes actives filtrees par type ET distance.
  ///
  /// [type]     : le type de carte voulu.
  /// [distance] : le niveau de distance (1, 2 ou 3).
  Future<List<CardEntity>> getCardsByTypeAndDistance(
    CardType type,
    int distance,
  );

  // =============================================================
  // METHODE : getDistractors
  // =============================================================
  // Methode specialisee pour la generation des distracteurs.
  //
  // Les distracteurs sont les 9 images INCORRECTES proposees
  // dans la ScrollView, en plus de la bonne reponse.
  //
  // Regles de selection (reference : recueil section 6.3) :
  //   - Meme TYPE que la carte masquee
  //   - ID different de la bonne reponse (on ne veut pas 2 fois la meme)
  //   - Tries par pertinence (meme categorie/distance/tags en priorite)
  //   - Limite a [count] resultats (par defaut 9)
  //
  // "{}" autour des parametres : parametres NOMMES (clarifies a l'appel)
  //   getDistractors(correctCard: ..., count: 9)
  //   Plus lisible que : getDistractors(card, 9)
  // =============================================================

  /// Recupere les cartes distractrices pour une question de jeu.
  ///
  /// [correctCard] : la bonne reponse (sera exclue des resultats).
  /// [count]       : nombre de distracteurs voulus (defaut: 9).
  ///
  /// Les distracteurs sont du MEME TYPE que [correctCard] mais
  /// ne sont PAS la bonne reponse.
  Future<List<CardEntity>> getDistractors({
    required CardEntity correctCard,
    int count = 9,
  });
}
