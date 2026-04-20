// =============================================================
// FICHIER : lib/domain/entities/session_entity.dart
// ROLE   : Representer une session de jeu (une partie jouee)
// COUCHE : Domain > Entities
// =============================================================
//
// QU'EST-CE QU'UNE SESSION ?
// --------------------------
// Une SESSION = une partie jouee sur un niveau donne, du debut
// a la fin (ou abandon). Chaque fois que le joueur termine un
// niveau (reussi ou pas), on INSERE une ligne dans user_sessions.
//
// RELATION AVEC LES AUTRES ENTITES :
//   - GameEntity      : le jeu global (ex: "Savane")
//   - UserEntity      : le joueur
//   - SessionEntity   : UNE partie concrete (level X, score Y, ...)
//
// Cote UI, on lit SessionEntity pour afficher :
//   - L'historique sur la home ("derniere session : 6/8")
//   - La page profil ("historique des parties")
//   - Les stars du niveau ("★★☆ sur le niveau 3")
// =============================================================


/// Une session de jeu = une partie completee par le joueur.
///
/// C'est un snapshot immuable d'une partie donnee. Une fois cree,
/// une session ne doit PAS etre modifiee (integrite de l'historique).
/// Les champs sont tous "final" pour refleter cette immutabilite.
class SessionEntity {

  /// Identifiant unique de la session (UUID genere par PostgreSQL).
  /// Utile pour fluter des clefs stables dans les ListView Flutter.
  final String id;

  /// UUID du joueur auquel la session appartient.
  /// Correspond a auth.users.id cote Supabase.
  final String userId;

  /// UUID du jeu joue (ex: "Savane", "Ocean").
  /// Correspond a games.id cote Supabase.
  final String gameId;

  /// Numero du niveau joue (1, 2, 3, ...).
  final int level;

  /// Score gagne DANS cette partie precisement (pas le cumul).
  /// Le cumul total est dans user_games.total_score.
  final int scoreGained;

  /// Nombre de bonnes reponses dans la partie.
  final int correctAnswers;

  /// Nombre de mauvaises reponses (timeouts inclus).
  final int wrongAnswers;

  /// Nombre total de questions posees pendant la partie.
  /// Correspond a LevelConfig.questions pour le niveau joue.
  final int questionsTotal;

  /// Plus longue serie de bonnes reponses consecutives.
  final int maxStreak;

  /// Duree de la partie en secondes (temps actif, hors pause).
  final int durationSeconds;

  /// True si le joueur a valide le niveau (seuil atteint).
  final bool passed;

  /// Etoiles obtenues (0 a 3). Calculees selon l'accuracy.
  final int starsEarned;

  /// Date et heure a laquelle la partie a eu lieu.
  /// Stockee en UTC cote BDD, reconvertie automatiquement cote Dart.
  final DateTime playedAt;

  /// Constructeur "const" : un SessionEntity peut etre cree a la
  /// compilation quand tous ses champs sont const. En pratique ce
  /// sera surtout utile pour les mocks de tests.
  const SessionEntity({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.level,
    required this.scoreGained,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.questionsTotal,
    required this.maxStreak,
    required this.durationSeconds,
    required this.passed,
    required this.starsEarned,
    required this.playedAt,
  });

  // ---------------------------------------------------------------
  // GETTERS CALCULES
  // ---------------------------------------------------------------
  // Ces getters ne sont pas stockes en BDD : ils sont derives des
  // champs existants a la volee. Les placer ici evite de dupliquer
  // la logique dans chaque widget qui voudrait afficher ces infos.
  // ---------------------------------------------------------------

  /// Taux de precision en pourcent (0-100). 0 si questionsTotal est 0.
  ///
  /// Formule : (correct / total) * 100, arrondi a l'entier le plus proche.
  /// Protection contre la division par zero pour les sessions vides.
  int get accuracyPercent {
    if (questionsTotal <= 0) return 0;
    return (correctAnswers / questionsTotal * 100).round();
  }

  // ---------------------------------------------------------------
  // HELPER STATIQUE : calcul des etoiles
  // ---------------------------------------------------------------
  // Regroupe la regle "combien d'etoiles pour une partie" en UN
  // seul endroit, pour ne pas la dupliquer entre :
  //   - le game_result_page qui affiche les etoiles en UI
  //   - le moment ou on INSERE la session en BDD
  //
  // Quand la regle evolue, un seul endroit a modifier.
  // ---------------------------------------------------------------

  /// Calcule le nombre d'etoiles (0-3) pour une partie donnee.
  ///
  /// Regle :
  ///   - 0 etoile  : partie ratee (passed = false)
  ///   - 3 etoiles : accuracy >= 90%
  ///   - 2 etoiles : accuracy entre 70% et 89%
  ///   - 1 etoile  : accuracy < 70% mais partie reussie
  ///
  /// [passed] vient du calcul de seuil cote GameConstants.
  /// [correctAnswers] et [questionsTotal] sont les stats de la partie.
  static int computeStars({
    required bool passed,
    required int correctAnswers,
    required int questionsTotal,
  }) {
    // Partie ratee = 0 etoile, peu importe l'accuracy.
    if (!passed) return 0;

    // Division par zero : 0 etoile par securite (cas degenere).
    if (questionsTotal <= 0) return 0;

    // Calcul de l'accuracy en pourcent (entier arrondi).
    final accuracy = (correctAnswers / questionsTotal * 100).round();

    // Seuils en ordre decroissant. Le premier qui match gagne.
    if (accuracy >= 90) return 3;
    if (accuracy >= 70) return 2;
    return 1;
  }
}
