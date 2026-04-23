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

  // ---------------------------------------------------------------
  // NOUVEAU SYSTEME DE NIVEAUX BASE SUR LES TABLES
  // ---------------------------------------------------------------
  // Chaque niveau correspond a UNE partie. Une partie utilise une
  // table specifique de noeuds logiques pour eviter que deux trios
  // de la meme chaine se retrouvent dans la meme partie.
  //
  // Le numero de niveau est mappé a (distance, tableIndex) via la
  // fonction buildLevelPlan() qui prend en entree le nombre de
  // tables disponibles pour chaque distance (calcul dynamique depuis
  // le graphe).
  //
  // Progression :
  //   Niveau 1 a N_D1 : D1 (1 table)
  //   Niveau N_D1+1 a N_D1+N_D2 : D2 (nombre de tables D2)
  //   Niveau ... : D3, D4, D5
  // ---------------------------------------------------------------

  /// Retourne les parametres du niveau [level] en fonction du nombre
  /// de tables disponibles pour chaque distance.
  ///
  /// [tablesPerDistance] : liste [nb_D1, nb_D2, nb_D3, nb_D4, nb_D5].
  /// Typiquement : [1, 5, 14, 27, 44] si toutes les distances ont
  /// au moins une chaine disponible, ou [1, 5, 14, 0, 0] si le
  /// graphe n'a que 3 niveaux de profondeur.
  ///
  /// Si [level] depasse le nombre total de niveaux disponibles,
  /// retourne la config du dernier niveau (bouclage).
  static LevelConfig getLevelConfigForTables(
    int level,
    List<int> tablesPerDistance,
  ) {
    // Parcourir les distances 1 a 5 et calculer l'intervalle de
    // niveaux qui leur appartient.
    int cumulativeLevel = 0;

    for (int k = 1; k <= 5; k++) {
      final nbTables = tablesPerDistance[k - 1];
      if (nbTables == 0) continue;

      // Niveaux pour cette distance : [cumulativeLevel + 1, cumulativeLevel + nbTables]
      final startLevel = cumulativeLevel + 1;
      final endLevel = cumulativeLevel + nbTables;

      if (level >= startLevel && level <= endLevel) {
        final tableIndex = level - startLevel;
        return _configForDistance(k, tableIndex);
      }

      cumulativeLevel = endLevel;
    }

    // Depassement : retourner la derniere config disponible.
    // (En pratique, l'UI devrait empecher cela.)
    return _configForDistance(1, 0);
  }

  /// Parametres par defaut pour une distance donnee.
  static LevelConfig _configForDistance(int distance, int tableIndex) {
    switch (distance) {
      case 1:
        return LevelConfig(
          distance: 1,
          tableIndex: tableIndex,
          configs: const ['A'],
          questions: 8,
          threshold: 6,
          livesPerWrong: 3,
          turnTimeSeconds: 30,
          basePoints: 10,
        );
      case 2:
        return LevelConfig(
          distance: 2,
          tableIndex: tableIndex,
          configs: tableIndex < 3 ? const ['A', 'B'] : const ['B'],
          questions: 10,
          threshold: 7,
          livesPerWrong: 2,
          turnTimeSeconds: 40,
          basePoints: 20,
        );
      case 3:
        return LevelConfig(
          distance: 3,
          tableIndex: tableIndex,
          configs: tableIndex < 7 ? const ['B', 'C'] : const ['C'],
          questions: 12,
          threshold: 8,
          livesPerWrong: 2,
          turnTimeSeconds: 50,
          basePoints: 35,
        );
      case 4:
        return LevelConfig(
          distance: 4,
          tableIndex: tableIndex,
          configs: const ['B', 'C'],
          questions: 12,
          threshold: 9,
          livesPerWrong: 1,
          turnTimeSeconds: 55,
          basePoints: 50,
        );
      case 5:
        return LevelConfig(
          distance: 5,
          tableIndex: tableIndex,
          configs: const ['C'],
          questions: 15,
          threshold: 11,
          livesPerWrong: 1,
          turnTimeSeconds: 55,
          basePoints: 75,
        );
      default:
        return LevelConfig(
          distance: 1,
          tableIndex: 0,
          configs: const ['A'],
          questions: 8,
          threshold: 6,
          livesPerWrong: 3,
          turnTimeSeconds: 30,
          basePoints: 10,
        );
    }
  }

  /// API de compatibilite : retourne une config par defaut sans
  /// tenir compte du nombre de tables. Utilise comme fallback.
  ///
  /// Pour la nouvelle API complete, utiliser [getLevelConfigForTables].
  static LevelConfig getLevelConfig(int level) {
    // Approximation : 1 D1 + 5 D2 + 14 D3 = 20 niveaux (graphe standard)
    return getLevelConfigForTables(level, const [1, 5, 14, 0, 0]);
  }

  // ---------------------------------------------------------------
  // MULTIPLICATEURS DE DISTANCE
  // ---------------------------------------------------------------
  // Reference : Recueil v3.0, section 7.2 (etendu D4/D5)
  //
  // Plus la distance est grande, plus les points sont multiplies.
  // D1 = trios simples       -> x1.0 (pas de bonus)
  // D2 = quintettes          -> x1.5
  // D3 = septettes           -> x2.0
  // D4 = chaines longues     -> x2.5
  // D5 = chaines legendaires -> x3.0
  //
  // La progression de +0.5 par distance garde une reward lineaire :
  // passer de D3 a D4 rapporte +25% par rapport a D3, puis D5 rapporte
  // +20% par rapport a D4. L'effort supplementaire reste bien paye
  // sans creer de ruptures exponentielles qui decourageraient les
  // joueurs intermediaires.
  // ---------------------------------------------------------------

  /// Retourne le multiplicateur de score selon la distance du trio.
  static double distanceMultiplier(int distance) {
    return switch (distance) {
      1 => 1.0,   // D1 : pas de multiplicateur
      2 => 1.5,   // D2 : +50%
      3 => 2.0,   // D3 : +100%
      4 => 2.5,   // D4 : +150%
      5 => 3.0,   // D5 : +200%
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
  /// Distance des trios utilises (1, 2, 3, 4 ou 5).
  final int distance;

  /// Index de la table a utiliser pour cette partie.
  /// Chaque distance a un nombre different de tables :
  ///   D1 : 1 table (index 0)
  ///   D2 : 5 tables (index 0 a 4)
  ///   D3 : 14 tables (index 0 a 13)
  ///   D4 : 27 tables
  ///   D5 : 44 tables
  final int tableIndex;

  /// Configurations de question disponibles (['A'], ['A','B'], etc.).
  final List<String> configs;

  /// Nombre total de questions dans le niveau.
  final int questions;

  /// Nombre de bonnes reponses requises pour passer au niveau suivant.
  final int threshold;

  /// Combien d'erreurs pour perdre 1 vie.
  final int livesPerWrong;

  /// Temps maximum en secondes pour repondre a une question.
  final int turnTimeSeconds;

  /// Points de base par bonne reponse (avant multiplicateurs).
  final int basePoints;

  const LevelConfig({
    required this.distance,
    required this.tableIndex,
    required this.configs,
    required this.questions,
    required this.threshold,
    required this.livesPerWrong,
    required this.turnTimeSeconds,
    required this.basePoints,
  });
}
