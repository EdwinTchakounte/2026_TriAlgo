// =============================================================
// FICHIER : lib/core/constants/game_constants.dart
// ROLE   : Centraliser tous les parametres de gameplay
// COUCHE : Core (accessible par toutes les autres couches)
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// TRIALGO possede de nombreux parametres de jeu : nombre de questions
// par niveau, seuils de reussite, temps par tour, points de base, etc.
//
// Centraliser ces valeurs ici permet :
//   - De modifier l'equilibrage du jeu en UN seul endroit
//   - D'eviter les "nombres magiques" disperses dans le code
//   - De documenter clairement chaque regle de gameplay
//
// REFERENCE : Recueil de conception v3.0, sections 7 et 8
// =============================================================

/// Contient tous les parametres de gameplay de TRIALGO.
///
/// Ces constantes definissent l'equilibrage du jeu :
/// combien de questions, combien de temps, combien de points.
class GameConstants {
  // ---------------------------------------------------------------
  // SYSTEME DE VIES
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 8.5
  // ---------------------------------------------------------------

  /// Nombre maximum de vies qu'un joueur peut avoir.
  /// A la creation du compte, le joueur demarre avec ce nombre.
  static const int maxLives = 5;

  /// Nombre de vies au demarrage (= maximum).
  static const int initialLives = 5;

  /// Duree en minutes entre chaque recharge automatique d'une vie.
  /// Gere par pg_cron cote Supabase (toutes les 30 min, +1 vie si < max).
  static const int liveRefillMinutes = 30;

  // ---------------------------------------------------------------
  // NOMBRE DE CHOIX PAR QUESTION
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 6.1
  // ---------------------------------------------------------------

  /// Nombre total d'images proposees dans la ScrollView du bas.
  /// = 1 bonne reponse + 9 distracteurs.
  static const int totalChoices = 10;

  /// Nombre de distracteurs (images incorrectes) par question.
  static const int distractorCount = 9;

  // ---------------------------------------------------------------
  // CONFIGURATIONS DE QUESTION (A, B, C)
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 6.2
  //
  // Chaque configuration definit quelles 2 images sont visibles
  // et laquelle est masquee ("???") :
  //   Config A : Emettrice + Cable visibles  -> trouver Receptrice (facile)
  //   Config B : Emettrice + Receptrice      -> trouver Cable      (moyen)
  //   Config C : Cable + Receptrice          -> trouver Emettrice  (difficile)
  // ---------------------------------------------------------------

  /// Les 3 configurations possibles pour une question.
  /// La valeur indique quelle carte est MASQUEE.
  static const String configA = 'A'; // Masquee = Receptrice
  static const String configB = 'B'; // Masquee = Cable
  static const String configC = 'C'; // Masquee = Emettrice

  // ---------------------------------------------------------------
  // TABLEAU DE PROGRESSION PAR NIVEAU
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 7.1
  //
  // Chaque niveau definit :
  //   - distance     : D1, D2 ou D3 (complexite des trios)
  //   - configs      : quelles configurations de question sont utilisees
  //   - questions    : nombre de questions dans le niveau
  //   - seuil        : nombre de bonnes reponses requises pour passer
  //   - viesParQuestion : nombre de vies perdues par mauvaise reponse
  //   - tempsTour    : duree max par question en secondes
  //   - pointsBase   : points de base par bonne reponse
  // ---------------------------------------------------------------

  /// Retourne les parametres du niveau demande.
  ///
  /// [level] : numero du niveau (1 a 23+)
  /// Retourne un [LevelConfig] contenant tous les parametres de ce niveau.
  static LevelConfig getLevelConfig(int level) {
    // Niveaux 1-3 : Introduction (D1, config A uniquement)
    // Le joueur apprend le mecanisme de base avec les trios simples.
    if (level <= 3) {
      return const LevelConfig(
        distance: 1,          // Trios simples (3 images)
        configs: ['A'],       // Trouver la Receptrice uniquement
        questions: 8,         // Peu de questions
        threshold: 6,         // Seuil bas (6/8 = 75%)
        livesPerWrong: 3,     // Tolerant (perd 1 vie pour 3 erreurs)
        turnTimeSeconds: 30,  // 30 secondes par question
        basePoints: 10,       // Points de base faibles
      );
    }
    // Niveaux 4-6 : Decouverte config B (D1, configs A+B)
    // Le joueur doit maintenant aussi trouver le Cable.
    if (level <= 6) {
      return const LevelConfig(
        distance: 1,
        configs: ['A', 'B'],   // Ajout de la config B
        questions: 10,
        threshold: 7,          // Seuil 7/10
        livesPerWrong: 3,
        turnTimeSeconds: 35,
        basePoints: 15,
      );
    }
    // Niveaux 7-10 : Introduction Distance 2 (D1+D2, configs A+B)
    // Les trios deviennent plus complexes (chaines de 5 images).
    if (level <= 10) {
      return const LevelConfig(
        distance: 2,           // Ajout des quintettes
        configs: ['A', 'B'],
        questions: 10,
        threshold: 7,
        livesPerWrong: 2,      // Moins tolerant
        turnTimeSeconds: 40,
        basePoints: 20,
      );
    }
    // Niveaux 11-14 : Config B exclusive (D2, config B)
    // Le joueur doit identifier visuellement les transformations.
    if (level <= 14) {
      return const LevelConfig(
        distance: 2,
        configs: ['B'],        // Config B uniquement
        questions: 10,
        threshold: 7,
        livesPerWrong: 2,
        turnTimeSeconds: 45,
        basePoints: 25,
      );
    }
    // Niveaux 15-18 : Introduction Distance 3 + Config C (D2+D3, B+C)
    if (level <= 18) {
      return const LevelConfig(
        distance: 3,
        configs: ['B', 'C'],   // Ajout de la config C (difficile)
        questions: 12,
        threshold: 8,
        livesPerWrong: 2,
        turnTimeSeconds: 50,
        basePoints: 35,
      );
    }
    // Niveaux 19-22 : Expert (D3, config C)
    if (level <= 22) {
      return const LevelConfig(
        distance: 3,
        configs: ['C'],        // Config C uniquement (la plus dure)
        questions: 12,
        threshold: 9,
        livesPerWrong: 1,      // Chaque erreur coute 1 vie
        turnTimeSeconds: 55,
        basePoints: 50,
      );
    }
    // Niveau 23+ : Maitre (toutes configs, toutes distances)
    return const LevelConfig(
      distance: 3,
      configs: ['A', 'B', 'C'], // Toutes les configs
      questions: 15,
      threshold: 11,
      livesPerWrong: 1,
      turnTimeSeconds: 45,      // Moins de temps !
      basePoints: 75,
    );
  }

  // ---------------------------------------------------------------
  // MULTIPLICATEURS DE DISTANCE
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 7.2
  //
  // Plus la distance est grande, plus les points sont multiplies.
  // D1 = trios simples      -> x1.0 (pas de bonus)
  // D2 = quintettes         -> x1.5
  // D3 = septettes          -> x2.0
  // ---------------------------------------------------------------

  /// Retourne le multiplicateur de score selon la distance du trio.
  static double distanceMultiplier(int distance) {
    return switch (distance) {
      1 => 1.0,   // D1 : pas de multiplicateur
      2 => 1.5,   // D2 : +50%
      3 => 2.0,   // D3 : +100%
      _ => 1.0,   // Securite : valeur par defaut
    };
  }

  // ---------------------------------------------------------------
  // BONUS TEMPS
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 7.2
  //
  // Le joueur est recompense pour sa rapidite.
  // Le ratio = temps_ecoule / temps_max.
  // Plus le ratio est bas (reponse rapide), plus le bonus est eleve.
  // ---------------------------------------------------------------

  /// Retourne le multiplicateur de bonus temps.
  ///
  /// [elapsedSeconds] : temps mis pour repondre
  /// [maxSeconds]     : temps maximum autorise pour la question
  static double timeBonus(int elapsedSeconds, int maxSeconds) {
    // Calcul du ratio : quelle proportion du temps a ete utilisee ?
    final ratio = elapsedSeconds / maxSeconds;

    if (ratio <= 0.25) return 1.5;  // Turbo  : dans les premiers 25% -> x1.5
    if (ratio <= 0.50) return 1.25; // Rapide : entre 25% et 50%      -> x1.25
    if (ratio <= 0.75) return 1.0;  // Normal : entre 50% et 75%      -> x1.0
    return 0.75;                     // Lent   : apres 75%             -> x0.75
  }

  // ---------------------------------------------------------------
  // DUREES MAXIMALES DE SESSION
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 8.2
  // ---------------------------------------------------------------

  /// Retourne la duree maximale de session en minutes selon le niveau.
  static int sessionMaxMinutes(int level) {
    if (level <= 5) return 10;
    if (level <= 10) return 15;
    if (level <= 15) return 20;
    return 25;
  }

  // ---------------------------------------------------------------
  // CODES BONUS ET MALUS
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, sections 8.3 et 8.4
  //
  // Ces constantes sont utilisees pour identifier les evenements
  // de bonus/malus dans le systeme de scoring.
  // ---------------------------------------------------------------

  // Bonus
  static const String bonusTurbo = 'BONUS_TURBO';           // Reponse < 25% du temps
  static const String bonusStreak = 'BONUS_STREAK';         // 3 bonnes consecutives
  static const String bonusMegaStreak = 'BONUS_MEGA_STREAK'; // 7 bonnes consecutives
  static const String bonusPerfect = 'BONUS_PERFECT';       // Niveau sans faute
  static const String bonusExpert = 'BONUS_EXPERT';         // Config C reussie
  static const String bonusSpeedRun = 'BONUS_SPEED_RUN';    // 5 questions < 15s chacune
  static const String bonusLifesaver = 'BONUS_LIFESAVER';   // Niveau sans perdre de vie

  // Malus
  static const String malusTimeout = 'MALUS_TIMEOUT';             // Chrono a 0
  static const String malusWrong = 'MALUS_WRONG';                 // Mauvaise reponse
  static const String malusStreakBreak = 'MALUS_STREAK_BREAK';    // Erreur apres serie >= 3
  static const String malusIncoherent = 'MALUS_INCOHERENT';       // 2 erreurs meme question
  static const String malusLevelFail = 'MALUS_LEVEL_FAIL';        // Seuil non atteint
  static const String malusSessionTimeout = 'MALUS_SESSION_TIMEOUT'; // Session expiree
}

// =============================================================
// CLASSE : LevelConfig
// ROLE   : Represente les parametres d'un niveau de jeu
// =============================================================
//
// Chaque niveau a ses propres regles. Cette classe les encapsule
// dans un objet structure plutot que dans un Map non type.
//
// "const" permet de creer ces objets a la compilation,
// pas a l'execution -> meilleure performance.
// =============================================================

class LevelConfig {
  /// Distance maximale des trios utilises (1, 2 ou 3).
  final int distance;

  /// Configurations de question disponibles (['A'], ['A','B'], etc.).
  final List<String> configs;

  /// Nombre total de questions dans le niveau.
  final int questions;

  /// Nombre de bonnes reponses requises pour passer au niveau suivant.
  final int threshold;

  /// Combien d'erreurs pour perdre 1 vie.
  /// 3 = tolerant (1 vie pour 3 erreurs), 1 = strict (1 erreur = 1 vie).
  final int livesPerWrong;

  /// Temps maximum en secondes pour repondre a une question.
  final int turnTimeSeconds;

  /// Points de base par bonne reponse (avant multiplicateurs).
  final int basePoints;

  const LevelConfig({
    required this.distance,
    required this.configs,
    required this.questions,
    required this.threshold,
    required this.livesPerWrong,
    required this.turnTimeSeconds,
    required this.basePoints,
  });
}
