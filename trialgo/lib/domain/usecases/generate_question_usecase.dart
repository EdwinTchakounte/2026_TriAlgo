// =============================================================
// FICHIER : lib/domain/usecases/generate_question_usecase.dart
// ROLE   : Generer une question de jeu complete
// COUCHE : Domain > Usecases
// =============================================================
//
// CE QUE FAIT CE USECASE :
// ------------------------
// 1. Determine les parametres du niveau (distance, config, temps)
// 2. Recupere un trio aleatoire de la bonne distance
// 3. Charge les 3 cartes du trio (Emettrice, Cable, Receptrice)
// 4. Choisit la configuration (A, B ou C)
// 5. Determine quelle carte est masquee et lesquelles sont visibles
// 6. Genere 9 distracteurs du meme type que la carte masquee
// 7. Melange les 10 choix (1 bonne + 9 distracteurs)
// 8. Retourne une GameQuestionEntity complete
//
// C'est le usecase le plus COMPLEXE de TRIALGO car il orchestre
// plusieurs repositories et applique la logique de generation.
//
// REFERENCE : Recueil de conception v3.0, sections 6.1 a 6.3
// =============================================================

// "dart:math" fournit la classe Random pour generer des nombres aleatoires.
// Utilise pour :
//   - Choisir une configuration aleatoire parmi celles disponibles
//   - Melanger les choix (shuffle)
import 'dart:math';

// Imports des entites et repositories de la couche Domain.
// Tous ces imports sont INTRA-COUCHE : aucune violation d'architecture.
import 'package:trialgo/core/constants/game_constants.dart';
import 'package:trialgo/domain/entities/card_entity.dart';
import 'package:trialgo/domain/entities/game_question_entity.dart';
import 'package:trialgo/domain/repositories/card_repository.dart';
import 'package:trialgo/domain/repositories/card_trio_repository.dart';

/// Usecase : genere une question de jeu complete.
///
/// Orchestre la creation d'une question en :
/// 1. Choisissant un trio aleatoire
/// 2. Determinant la configuration (A/B/C)
/// 3. Chargeant les cartes et les distracteurs
/// 4. Assemblant le tout en [GameQuestionEntity]
///
/// Ce usecase a besoin de DEUX repositories :
///   - [CardTrioRepository] pour recuperer un trio aleatoire
///   - [CardRepository] pour charger les cartes et les distracteurs
class GenerateQuestionUseCase {

  // =============================================================
  // PROPRIETES : les deux repositories injectes
  // =============================================================
  // Ce usecase depend de deux repositories car il fait deux choses :
  //   1. Recuperer un trio (CardTrioRepository)
  //   2. Charger des cartes individuelles + distracteurs (CardRepository)
  // =============================================================

  /// Repository pour acceder aux trios de cartes.
  final CardTrioRepository trioRepository;

  /// Repository pour acceder aux cartes individuelles.
  final CardRepository cardRepository;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // Recoit les deux repositories en parametres POSITIONNELS.
  //
  // Parametres positionnels vs nommes :
  //   Positionnels : GenerateQuestionUseCase(trioRepo, cardRepo)
  //     -> L'ordre compte. Plus concis mais moins lisible.
  //   Nommes       : GenerateQuestionUseCase(trioRepo: ..., cardRepo: ...)
  //     -> L'ordre ne compte pas. Plus verbeux mais plus clair.
  //
  // Ici on utilise des positionnels car il n'y en a que 2
  // et leur nom est explicite dans le constructeur.
  // =============================================================

  /// Cree le usecase avec les repositories necessaires.
  GenerateQuestionUseCase(this.trioRepository, this.cardRepository);

  // =============================================================
  // METHODE : call
  // =============================================================
  // Methode principale du usecase. Genere une question complete.
  //
  // Parametres :
  //   level       : niveau actuel du joueur (1 a 23+)
  //                 Determine la distance, les configs dispo, le temps, etc.
  //
  //   excludeTrioIds : IDs des trios deja utilises dans cette session
  //                    Evite de reposer la meme question deux fois.
  //                    "const []" : liste vide par defaut (premiere question).
  //
  // Retour : Future<GameQuestionEntity>
  //   -> La question complete, prete a etre affichee par le widget.
  //
  // "async" : cette methode contient des "await" (appels reseau).
  // =============================================================

  /// Genere une question de jeu pour le niveau donne.
  ///
  /// [level]          : numero du niveau actuel du joueur.
  /// [excludeTrioIds] : IDs des trios deja poses dans cette session.
  ///
  /// Retourne une [GameQuestionEntity] prete a etre affichee.
  Future<GameQuestionEntity> call({
    required int level,
    List<String> excludeTrioIds = const [],
  }) async {

    // --- ETAPE 1 : Determiner les parametres du niveau ---
    // GameConstants.getLevelConfig() retourne un LevelConfig
    // contenant tous les parametres de ce niveau : distance,
    // configs disponibles, temps par tour, points de base, etc.
    //
    // Exemple pour level = 7 :
    //   distance = 2, configs = ['A', 'B'], turnTimeSeconds = 40
    final levelConfig = GameConstants.getLevelConfig(level);

    // --- ETAPE 2 : Recuperer un trio aleatoire ---
    // On demande un trio de la distance correspondant au niveau.
    // Les trios deja utilises (excludeTrioIds) sont exclus.
    //
    // "await" : on attend la reponse de Supabase (appel reseau).
    // Pendant ce temps, l'interface Flutter n'est PAS bloquee.
    final trio = await trioRepository.getRandomTrio(
      distance: levelConfig.distance,  // D1, D2 ou D3 selon le niveau
      excludeIds: excludeTrioIds,       // Exclure les trios deja poses
    );

    // --- ETAPE 3 : Charger les 3 cartes du trio ---
    // Le trio ne contient que les IDs. On doit charger les cartes
    // completes (avec imagePath, themeTags, etc.) depuis la base.
    //
    // "Future.wait" execute les 3 requetes EN PARALLELE.
    // C'est plus rapide que de les faire l'une apres l'autre :
    //   Sequentiel : 100ms + 100ms + 100ms = 300ms
    //   Parallele  : max(100ms, 100ms, 100ms) = 100ms
    //
    // "Future.wait" prend une List<Future> et retourne une List<resultat>
    // dans le MEME ORDRE que les futures d'entree.
    //   results[0] = emettrice (premier Future)
    //   results[1] = cable     (deuxieme Future)
    //   results[2] = receptrice (troisieme Future)
    final results = await Future.wait([
      cardRepository.getCardById(trio.emettriceId),   // [0] = Emettrice
      cardRepository.getCardById(trio.cableId),       // [1] = Cable
      cardRepository.getCardById(trio.receptriceId),  // [2] = Receptrice
    ]);

    // Extraction des resultats dans des variables nommees pour la lisibilite.
    // "results[0]" n'est pas tres parlant -> on le nomme "emettrice".
    final emettrice  = results[0]; // La carte Emettrice
    final cable      = results[1]; // La carte Cable
    final receptrice = results[2]; // La carte Receptrice

    // --- ETAPE 4 : Choisir une configuration aleatoire ---
    // Le niveau autorise certaines configurations (A, B, C ou un mix).
    // On en choisit UNE au hasard parmi celles disponibles.
    //
    // "Random()" cree un generateur de nombres aleatoires.
    // ".nextInt(n)" retourne un entier aleatoire entre 0 et n-1.
    //
    // Exemple : configs = ['A', 'B']
    //   Random().nextInt(2) -> 0 ou 1
    //   configs[0] = 'A' ou configs[1] = 'B'
    final random = Random();
    final config = levelConfig.configs[
      random.nextInt(levelConfig.configs.length)
    ];
    // "levelConfig.configs.length" : nombre de configs disponibles
    // "random.nextInt(length)" : index aleatoire dans la liste

    // --- ETAPE 5 : Determiner visible/masque selon la config ---
    // Selon la config choisie, on determine :
    //   - visibleCards : les 2 cartes affichees en haut
    //   - maskedCard   : la carte cachee ("???")
    //
    // "late" : la variable sera initialisee PLUS TARD (dans le switch).
    // Le compilateur verifie qu'elle est assignee avant utilisation.
    // Sans "late", il faudrait lui donner une valeur par defaut.
    late List<CardEntity> visibleCards;
    late CardEntity maskedCard;

    // "switch" sur la config pour determiner le schema de la question.
    // Dart 3+ oblige a gerer TOUS les cas possibles (exhaustivite).
    switch (config) {
      case 'A':
        // Config A (facile) : E + C visibles, trouver R
        // Le joueur voit l'image de base ET la transformation.
        // Il doit imaginer le resultat.
        visibleCards = [emettrice, cable];
        maskedCard = receptrice;

      case 'B':
        // Config B (moyen) : E + R visibles, trouver C
        // Le joueur voit l'avant et l'apres.
        // Il doit identifier QUELLE transformation a ete appliquee.
        visibleCards = [emettrice, receptrice];
        maskedCard = cable;

      case 'C':
        // Config C (difficile) : C + R visibles, trouver E
        // Le joueur voit la transformation et le resultat.
        // Il doit deviner l'image de DEPART.
        visibleCards = [cable, receptrice];
        maskedCard = emettrice;

      default:
        // Securite : si config inconnue, on utilise la config A.
        // Ce cas ne devrait JAMAIS arriver car les configs viennent
        // de GameConstants, mais la securite est une bonne pratique.
        visibleCards = [emettrice, cable];
        maskedCard = receptrice;
    }

    // --- ETAPE 6 : Generer les distracteurs ---
    // On charge 9 cartes du MEME TYPE que la carte masquee.
    // Ces cartes seront les "mauvaises reponses" dans la ScrollView.
    //
    // Exemple : si maskedCard est un Cable, les 9 distracteurs
    // sont d'autres images de cables (miroir_v, rotation_90, teinte_bleue...).
    final distractors = await cardRepository.getDistractors(
      correctCard: maskedCard, // La bonne reponse (sera exclue)
      count: 9,                // On veut exactement 9 distracteurs
    );

    // --- ETAPE 7 : Assembler les 10 choix et melanger ---
    // On cree une liste contenant la bonne reponse + les 9 distracteurs.
    //
    // "[maskedCard, ...distractors]" :
    //   - "[...]" cree une nouvelle List
    //   - "maskedCard" est le premier element (la bonne reponse)
    //   - "...distractors" est l'operateur SPREAD : il "etale"
    //     tous les elements de la liste distractors dans cette liste.
    //     Equivalent de : [maskedCard, distractors[0], distractors[1], ..., distractors[8]]
    //
    // ".shuffle()" melange la liste ALEATOIREMENT en place.
    // Apres shuffle, la bonne reponse peut etre a n'importe quelle position.
    // IMPORTANT : shuffle modifie la liste ET la retourne.
    final choices = [maskedCard, ...distractors]..shuffle();
    // ".." est l'operateur CASCADE :
    //   - Il appelle shuffle() sur la liste
    //   - Mais retourne la LISTE (pas le retour de shuffle)
    //   - Equivalent de :
    //       final choices = [maskedCard, ...distractors];
    //       choices.shuffle();

    // --- ETAPE 8 : Retourner la question complete ---
    // On assemble toutes les pieces dans un GameQuestionEntity.
    return GameQuestionEntity(
      visibleCards: visibleCards,                // 2 cartes visibles
      maskedCard: maskedCard,                    // La carte a trouver
      choices: choices,                          // 10 choix melanges
      config: config,                            // 'A', 'B' ou 'C'
      correctCardId: maskedCard.id,              // ID de la bonne reponse
      trioId: trio.id,                           // ID du trio source
      timeLimitSeconds: levelConfig.turnTimeSeconds, // Temps max
    );
  }
}
