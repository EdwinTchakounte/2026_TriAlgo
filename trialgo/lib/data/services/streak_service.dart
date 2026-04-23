// =============================================================
// FICHIER : lib/data/services/streak_service.dart
// ROLE   : Compte le nombre de jours consecutifs ou l'utilisateur a joue
// COUCHE : Data > Services
// =============================================================
//
// POURQUOI UN STREAK ?
// --------------------
// La "flamme" (streak) est l'un des outils de retention les plus
// puissants dans les apps pour enfants :
//   - Duolingo : icone flamme dans le header, celebration tous les 7j
//   - Snapchat : flammes entre amis
//   - Wordle : compteur de parties consecutives
//
// Pour TRIALGO, le streak mesure "combien de jours d'affilee j'ai
// joue au moins une partie".
//
// REGLES :
// --------
//   - Premier jour joue        -> streak = 1
//   - Joue encore le lendemain -> streak += 1
//   - Joue le meme jour        -> streak inchange
//   - Saute un jour complet    -> streak reset a 1 au prochain jeu
//
// IMPLEMENTATION LOCALE :
// -----------------------
// Utilise SharedPreferences (pas de BDD Supabase). Simple, rapide,
// offline-first. Inconvenient : si l'utilisateur change de telephone
// ou reinstalle, le streak est perdu. C'est acceptable pour v1.
// Migration vers Supabase possible dans une phase ulterieure.
// =============================================================

import 'package:shared_preferences/shared_preferences.dart';


/// Service de gestion du streak (serie de jours consecutifs).
class StreakService {

  // ---------------------------------------------------------------
  // CLES SharedPreferences
  // ---------------------------------------------------------------
  // Prefixees "streak." pour eviter les collisions avec d'autres
  // preferences du meme SharedPreferences.
  // ---------------------------------------------------------------

  static const String _keyLastPlayed = 'streak.last_played';
  static const String _keyCount = 'streak.count';

  // =============================================================
  // METHODE : getStreak
  // =============================================================
  // Retourne le streak courant, en tenant compte du fait que si
  // l'utilisateur n'a pas joue depuis plus d'un jour, le streak
  // est perdu (on retourne 0 meme si la valeur en prefs est >0).
  //
  // La valeur en prefs n'est reset qu'au prochain appel a recordPlay,
  // pour eviter des ecritures inutiles au simple affichage du home.
  // =============================================================

  /// Retourne le streak courant (0 si jamais joue ou serie cassee).
  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString(_keyLastPlayed);

    // Jamais joue : pas de streak.
    if (lastStr == null) return 0;

    // Parse la date. En cas d'erreur (valeur corrompue), reset a 0.
    final last = DateTime.tryParse(lastStr);
    if (last == null) return 0;

    // On compare au niveau "debut de journee" pour ne pas etre
    // sensible a l'heure precise. Ex: hier 23h59 vs ce matin 00h01
    // = 1 jour d'ecart, streak intact.
    final today = _atMidnight(DateTime.now());
    final lastDay = _atMidnight(last);
    final daysSince = today.difference(lastDay).inDays;

    // Si plus d'1 jour sans jouer, le streak est rompu.
    if (daysSince > 1) return 0;

    return prefs.getInt(_keyCount) ?? 0;
  }

  // =============================================================
  // METHODE : recordPlay
  // =============================================================
  // A appeler quand l'utilisateur complete une partie (ou la demarre,
  // selon la semantique voulue). Ici : appel depuis
  // ProfileNotifier.recordGameSession() a la fin d'une partie.
  //
  // Gere les 4 cas (premiere fois, meme jour, lendemain, coupure).
  // Retourne la nouvelle valeur du streak.
  // =============================================================

  /// Enregistre une session de jeu et retourne le nouveau streak.
  Future<int> recordPlay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _atMidnight(DateTime.now());
    final lastStr = prefs.getString(_keyLastPlayed);

    int newCount;

    if (lastStr == null) {
      // Cas 1 : jamais joue avant. Premier streak = 1.
      newCount = 1;
    } else {
      final last = DateTime.tryParse(lastStr);
      if (last == null) {
        // Donnees corrompues : on reset proprement.
        newCount = 1;
      } else {
        final lastDay = _atMidnight(last);
        final daysSince = today.difference(lastDay).inDays;

        if (daysSince == 0) {
          // Cas 2 : deja joue aujourd'hui. Pas de changement.
          return prefs.getInt(_keyCount) ?? 1;
        } else if (daysSince == 1) {
          // Cas 3 : joue hier, on incremente.
          newCount = (prefs.getInt(_keyCount) ?? 0) + 1;
        } else {
          // Cas 4 : gap >= 2 jours, la serie est cassee. On redemarre a 1.
          newCount = 1;
        }
      }
    }

    // Persistance de la nouvelle valeur.
    await prefs.setString(_keyLastPlayed, today.toIso8601String());
    await prefs.setInt(_keyCount, newCount);
    return newCount;
  }

  // =============================================================
  // METHODE : _atMidnight
  // =============================================================
  // Normalise une date a minuit (00:00:00). Utile pour ne comparer
  // QUE les jours, sans etre influence par l'heure de la journee.
  // =============================================================

  /// Retourne une DateTime ramenee au debut du jour.
  DateTime _atMidnight(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  // =============================================================
  // METHODE : reset (utilitaire admin/debug)
  // =============================================================

  /// Efface le streak. Reserve aux cas debug / deconnexion.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastPlayed);
    await prefs.remove(_keyCount);
  }
}
