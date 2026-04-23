// =============================================================
// FICHIER : lib/domain/usecases/validate_triplet_usecase.dart
// ROLE   : Valider si un trio de cartes est coherent
// COUCHE : Domain > Usecases
// =============================================================
//
// QU'EST-CE QU'UN USECASE ?
// -------------------------
// Un usecase (cas d'utilisation) est une ACTION METIER.
// C'est une classe qui fait UNE SEULE CHOSE.
//
// Un usecase :
//   - Recoit les DONNEES necessaires (parametres)
//   - Utilise un REPOSITORY pour acceder aux donnees
//   - Retourne un RESULTAT
//   - Ne contient AUCUNE logique d'affichage (pas de Flutter)
//   - Ne contient AUCUNE logique d'acces aux donnees (pas de Supabase)
//
// Pourquoi une classe pour une seule action ?
//   - TESTABILITE : on peut tester l'action isolement
//   - LISIBILITE : le nom de la classe decrit l'action
//   - REUTILISABILITE : l'action est appelee de la meme facon partout
//   - INJECTION : on injecte le repository (pas de dependance directe)
//
// DANS TRIALGO :
// --------------
// ValidateTripletUseCase verifie si 3 IDs de cartes forment
// un trio VALIDE dans la table card_trios.
//
// C'est l'action executee quand le joueur TAP sur une image
// dans la ScrollView pour donner sa reponse.
//
// REFERENCE : Recueil de conception v3.0, section 4.5
// =============================================================

// Import du repository INTERFACE (pas de l'implementation).
// Le usecase ne sait PAS que Supabase existe.
// Il connait juste le CONTRAT : "je peux appeler isCoherent()".
import 'package:trialgo/domain/repositories/card_trio_repository.dart';

/// Usecase : verifie si un trio (E, C, R) est une combinaison valide.
///
/// Quand le joueur selectionne une image dans la ScrollView,
/// ce usecase est appele pour verifier si les 3 images forment
/// un trio enregistre dans la base de donnees.
///
/// Utilisation :
/// ```dart
/// // 1. Creer le usecase (injection du repository)
/// final validateTriplet = ValidateTripletUseCase(trioRepository);
///
/// // 2. Appeler le usecase
/// final isValid = await validateTriplet.call(
///   emettriceId:  'uuid-emettrice',
///   cableId:      'uuid-cable',
///   receptriceId: 'uuid-receptrice',
/// );
///
/// // 3. Reagir au resultat
/// if (isValid) {
///   // Bonne reponse ! -> ajouter points, bonus, etc.
/// } else {
///   // Mauvaise reponse -> perdre une vie, afficher la bonne image
/// }
/// ```
class ValidateTripletUseCase {

  // =============================================================
  // PROPRIETE : repository
  // =============================================================
  // Type : CardTrioRepository (INTERFACE, pas implementation)
  //
  // "final" : assigne une seule fois dans le constructeur.
  //
  // Ce repository est INJECTE par le constructeur.
  // "Injection" signifie : on recoit l'objet de l'exterieur
  // au lieu de le creer nous-memes.
  //
  // Avantage de l'injection :
  //   - En production : on injecte CardTrioRepositoryImpl (vrai Supabase)
  //   - En test       : on injecte un MockCardTrioRepository (faux, en memoire)
  //   - Le usecase fonctionne de la meme facon dans les deux cas
  // =============================================================

  /// Le repository utilise pour acceder aux trios de cartes.
  ///
  /// Injecte via le constructeur. C'est une INTERFACE :
  /// le usecase ne sait pas quelle implementation est utilisee.
  final CardTrioRepository repository;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // "ValidateTripletUseCase(this.repository)" :
  //   - Parametre positionnel (pas de nom, pas de {})
  //   - "this.repository" : assigne directement le parametre
  //     a la propriete "repository"
  //
  // Equivalent long :
  //   ValidateTripletUseCase(CardTrioRepository repo) : repository = repo;
  //
  // Pas de "const" car le repository n'est pas forcement constant
  // (il contient un client Supabase avec un etat interne).
  // =============================================================

  /// Cree le usecase avec le repository de trios injecte.
  ///
  /// [repository] : l'implementation du repository de trios.
  ValidateTripletUseCase(this.repository);

  // =============================================================
  // METHODE : call
  // =============================================================
  // Nom "call" par convention dans les usecases.
  //
  // En Dart, si une classe a une methode "call", on peut
  // appeler l'objet comme une FONCTION :
  //   final usecase = ValidateTripletUseCase(repo);
  //   usecase.call(...)  // Appel classique
  //   usecase(...)       // Raccourci Dart (appelle .call automatiquement)
  //
  // Parametres nommes (entre {}) avec "required" :
  //   Tous sont obligatoires car on a besoin des 3 IDs pour verifier.
  //
  // Retour : Future<bool>
  //   - Future : operation asynchrone (requete reseau)
  //   - bool   : true = trio valide, false = trio invalide
  //
  // Le mot-cle "async" est ABSENT ici car on retourne directement
  // le Future du repository sans traitement supplementaire.
  // Si on ecrivait "async", Dart creerait un Future supplementaire
  // inutilement (double encapsulation).
  // =============================================================

  /// Verifie si les 3 cartes forment un trio valide.
  ///
  /// [emettriceId]  : UUID de la carte Emettrice (ou celle jouant ce role).
  /// [cableId]      : UUID de la carte Cable.
  /// [receptriceId] : UUID de la carte Receptrice.
  ///
  /// Retourne `true` si le trio existe dans `card_trios`, `false` sinon.
  Future<bool> call({
    required String emettriceId,
    required String cableId,
    required String receptriceId,
  }) {
    // On DELEGUE directement au repository.
    // Le usecase ne fait aucun traitement supplementaire ici.
    //
    // Dans un usecase plus complexe, on pourrait ajouter :
    //   - De la validation des parametres
    //   - Du logging
    //   - De la logique metier supplementaire
    //
    // Mais ici, la verification est simple :
    // "est-ce que ce trio existe dans la base ?" -> oui ou non.
    return repository.isCoherent(
      emettriceId: emettriceId,   // Passe tel quel au repository
      cableId: cableId,           // Passe tel quel au repository
      receptriceId: receptriceId, // Passe tel quel au repository
    );
  }
}
