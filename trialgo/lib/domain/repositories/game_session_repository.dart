// =============================================================
// FICHIER : lib/domain/repositories/game_session_repository.dart
// ROLE   : Definir l'INTERFACE du repository de sessions de jeu
// COUCHE : Domain > Repositories
// =============================================================
//
// QU'EST-CE QU'UNE SESSION ?
// --------------------------
// Une session est UNE tentative de jouer un niveau.
// Elle a un debut (started_at), une fin (ended_at), et un resultat
// (completed = true si niveau reussi, false sinon).
//
// Pendant une session, le joueur repond a N questions.
// Chaque reponse modifie le score, les bonnes/mauvaises reponses, etc.
//
// La session se termine quand :
//   - Le seuil de bonnes reponses est atteint (niveau reussi)
//   - Toutes les questions sont posees sans atteindre le seuil (echec)
//   - Les vies tombent a 0 (session forcee terminee)
//   - Le temps de session expire (timeout global)
//
// REFERENCE : Recueil de conception v3.0, sections 3.4 et 12.6
// =============================================================

/// Interface definissant les operations sur les sessions de jeu.
///
/// Une session correspond a une ligne dans la table `game_sessions`.
/// Elle est creee au debut d'une partie et mise a jour apres
/// chaque question.
abstract class GameSessionRepository {

  // =============================================================
  // METHODE : createSession
  // =============================================================
  // Cree une nouvelle session dans la base de donnees.
  // Appelee quand le joueur appuie sur "Jouer" dans le menu principal.
  //
  // "Map<String, dynamic>" est le type de retour :
  //   - "Map" : un dictionnaire cle-valeur (comme un JSON)
  //   - "<String, dynamic>" : les cles sont des String, les valeurs
  //     peuvent etre n'importe quel type (String, int, bool...)
  //
  // On retourne un Map et non une entite car la session est un
  // objet technique (pas un concept metier pur). Les donnees brutes
  // suffisent et seront gerees par le provider Riverpod.
  //
  // SQL equivalent :
  //   INSERT INTO game_sessions (user_id, level_number)
  //   VALUES ($userId, $levelNumber)
  //   RETURNING *
  // =============================================================

  /// Cree une nouvelle session de jeu.
  ///
  /// [userId]      : UUID de l'utilisateur qui joue.
  /// [levelNumber] : numero du niveau tente.
  ///
  /// Retourne les donnees de la session creee (id, user_id, level_number, etc.).
  Future<Map<String, dynamic>> createSession({
    required String userId,
    required int levelNumber,
  });

  // =============================================================
  // METHODE : updateSession
  // =============================================================
  // Met a jour les compteurs de la session apres chaque question.
  //
  // "Map<String, dynamic> updates" :
  //   Les champs a modifier et leurs nouvelles valeurs.
  //   Exemples :
  //     {'score': 1297, 'correct_answers': 4}  -> apres bonne reponse
  //     {'wrong_answers': 2, 'malus_received': 1}  -> apres mauvaise reponse
  //
  // On passe un Map libre plutot que des parametres fixes car
  // les champs mis a jour varient selon le type de reponse
  // (bonne reponse, mauvaise reponse, timeout...).
  //
  // SQL equivalent :
  //   UPDATE game_sessions SET score = $score, ... WHERE id = $sessionId
  // =============================================================

  /// Met a jour une session en cours.
  ///
  /// [sessionId] : UUID de la session a modifier.
  /// [updates]   : dictionnaire des champs a modifier.
  Future<void> updateSession({
    required String sessionId,
    required Map<String, dynamic> updates,
  });

  // =============================================================
  // METHODE : endSession
  // =============================================================
  // Cloture definitivement une session (succes ou echec).
  //
  // "bool completed" :
  //   true  -> niveau reussi (seuil de bonnes reponses atteint)
  //   false -> niveau echoue (seuil non atteint OU vies epuisees)
  //
  // "int durationSeconds" :
  //   Duree totale de la session en secondes.
  //   Calculee : ended_at - started_at
  //
  // Cette methode :
  //   1. Met a jour game_sessions (completed, ended_at, duration_seconds)
  //   2. Si completed = true : met a jour user_profiles (current_level + 1, total_score)
  //
  // SQL equivalent :
  //   UPDATE game_sessions
  //   SET completed = $completed, ended_at = NOW(), duration_seconds = $duration
  //   WHERE id = $sessionId
  // =============================================================

  /// Cloture une session de jeu.
  ///
  /// [sessionId]       : UUID de la session a cloturer.
  /// [completed]       : true si le niveau est reussi, false sinon.
  /// [durationSeconds] : duree totale de la session en secondes.
  Future<void> endSession({
    required String sessionId,
    required bool completed,
    required int durationSeconds,
  });
}
