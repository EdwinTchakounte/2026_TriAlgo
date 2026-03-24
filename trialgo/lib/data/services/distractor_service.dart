// =============================================================
// FICHIER : lib/data/services/distractor_service.dart
// ROLE   : Generer les 9 images distractrices pour une question
// COUCHE : Data > Services
// =============================================================
//
// QU'EST-CE QU'UN SERVICE ?
// -------------------------
// Un service est une classe qui contient de la logique technique
// qui n'est ni un repository (pas de CRUD pur) ni un usecase
// (pas une action metier complete).
//
// DistractorService contient la LOGIQUE DE SELECTION des distracteurs :
//   - Quels criteres pour choisir des distracteurs pertinents ?
//   - Comment prioriser les distracteurs visuellement proches ?
//   - Comment completer si on n'en a pas assez ?
//
// NOTE : dans la version actuelle, la logique des distracteurs
// est integree directement dans CardRepositoryImpl.getDistractors().
// Ce service existe pour encapsuler une logique plus avancee
// si besoin (ex: scoring de pertinence, cache, etc.).
//
// REFERENCE : Recueil de conception v3.0, section 6.3
// =============================================================

import 'package:trialgo/domain/entities/card_entity.dart';
import 'package:trialgo/domain/repositories/card_repository.dart';

/// Service de generation des distracteurs pour les questions de jeu.
///
/// Les distracteurs sont les 9 images INCORRECTES proposees au joueur
/// dans la ScrollView, en plus de la bonne reponse (total = 10).
///
/// Regles de selection :
///   1. Meme TYPE que la carte masquee (si Cable, 9 autres Cables)
///   2. Exclure la bonne reponse
///   3. Prioriser les cartes visuellement proches
///   4. Melanger le resultat final
class DistractorService {

  // =============================================================
  // PROPRIETE : cardRepository
  // =============================================================
  // Le service a besoin du repository pour charger les cartes
  // depuis la base de donnees.
  //
  // Injection de dependance : le repository est passe au constructeur,
  // pas cree en interne. Facilite les tests.
  // =============================================================

  /// Repository pour acceder aux cartes (injecte).
  final CardRepository cardRepository;

  /// Cree le service avec le repository de cartes [cardRepository].
  DistractorService(this.cardRepository);

  // =============================================================
  // METHODE : generateDistractors
  // =============================================================
  // Methode principale : genere les distracteurs pour une question.
  //
  // Parametres :
  //   correctCard : la bonne reponse (pour connaitre le type a chercher)
  //   level       : niveau du joueur (pour ajuster la difficulte)
  //   count       : nombre de distracteurs (9 par defaut)
  //
  // Retour : List<CardEntity> contenant [count] distracteurs.
  //
  // Strategie de selection selon le type de carte masquee :
  //
  //   Receptrice masquee (config A) :
  //     -> 9 autres Receptrices
  //     -> Priorite : meme distance_level, puis memes theme_tags
  //     -> Le joueur doit reconnaitre le bon RESULTAT
  //
  //   Cable masque (config B) :
  //     -> 9 autres Cables
  //     -> Priorite : meme cable_category, puis autres categories
  //     -> Le joueur doit reconnaitre la bonne TRANSFORMATION
  //
  //   Emettrice masquee (config C) :
  //     -> 9 autres Emettrices
  //     -> Priorite : memes theme_tags partiels, puis themes differents
  //     -> Le joueur doit reconnaitre la bonne image DE DEPART
  // =============================================================

  /// Genere [count] distracteurs pour une question de jeu.
  ///
  /// [correctCard] : la carte qui est la bonne reponse.
  /// [level]       : niveau actuel du joueur (pour ajuster la difficulte).
  /// [count]       : nombre de distracteurs voulus (defaut: 9).
  ///
  /// Retourne une liste de cartes qui ne sont PAS la bonne reponse
  /// mais qui sont du MEME TYPE.
  Future<List<CardEntity>> generateDistractors({
    required CardEntity correctCard,
    required int level,
    int count = 9,
  }) async {
    // On delegue au repository qui contient deja la logique
    // de selection avec priorisation par categorie/distance.
    //
    // Si on veut une logique plus sophistiquee a l'avenir
    // (scoring de pertinence, diversite garantie, etc.),
    // c'est ICI qu'on l'ajouterait, sans toucher au repository.
    final distractors = await cardRepository.getDistractors(
      correctCard: correctCard,
      count: count,
    );

    // --- Verification : a-t-on assez de distracteurs ? ---
    // Si la base ne contient pas assez de cartes du meme type,
    // on pourrait avoir moins de 9 distracteurs.
    //
    // Dans ce cas, on accepte ce qu'on a.
    // L'interface s'adaptera (ScrollView avec moins d'images).
    //
    // En production, il devrait toujours y avoir assez de cartes.
    // Ce cas n'arrive que pendant le developpement quand la base
    // est partiellement remplie.
    if (distractors.length < count) {
      // On pourrait logger un avertissement ici :
      // print('Attention : seulement ${distractors.length}/$count distracteurs disponibles');
    }

    return distractors;
  }
}
