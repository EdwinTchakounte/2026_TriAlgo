// =============================================================
// FICHIER : lib/data/repositories/game_session_repository_impl.dart
// ROLE   : Implementation CONCRETE du GameSessionRepository
// COUCHE : Data > Repositories
// =============================================================
//
// Gere le CRUD sur la table game_sessions dans Supabase.
// Une session = une tentative de jouer un niveau.
//
// Operations :
//   createSession -> INSERT (debut de partie)
//   updateSession -> UPDATE (apres chaque question)
//   endSession    -> UPDATE (fin de partie, succes ou echec)
//
// REFERENCE : Recueil de conception v3.0, section 13.5
// =============================================================

import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/domain/repositories/game_session_repository.dart';

/// Implementation de [GameSessionRepository] utilisant Supabase.
///
/// Gere la table `game_sessions` : creation, mise a jour et cloture.
class GameSessionRepositoryImpl implements GameSessionRepository {

  // =============================================================
  // METHODE : createSession
  // =============================================================
  // Insere une nouvelle ligne dans game_sessions.
  //
  // SQL genere :
  //   INSERT INTO game_sessions (user_id, level_number)
  //   VALUES ($userId, $levelNumber)
  //   RETURNING *
  //
  // Les autres colonnes prennent leurs valeurs DEFAULT :
  //   score = 0, correct_answers = 0, wrong_answers = 0,
  //   completed = false, started_at = now()
  // =============================================================

  /// Cree une nouvelle session de jeu dans Supabase.
  ///
  /// Retourne les donnees de la session creee (incluant l'ID genere).
  @override
  Future<Map<String, dynamic>> createSession({
    required String userId,
    required int levelNumber,
  }) async {
    // ".insert({...})" : insere une nouvelle ligne
    //   -> Le Map contient les colonnes et leurs valeurs
    //   -> Les colonnes absentes prennent la valeur DEFAULT
    //
    // ".select()" apres insert : demande a Supabase de RETOURNER
    //   la ligne inseree (equivalent de RETURNING * en SQL).
    //   Sans .select(), l'insert ne retourne rien.
    //
    // ".single()" : on attend exactement 1 resultat (la ligne inseree).
    final session = await supabase
        .from('game_sessions')
        .insert({
          'user_id': userId,          // UUID de l'utilisateur
          'level_number': levelNumber, // Numero du niveau (1-23+)
          // Pas besoin de specifier les autres colonnes :
          // score, correct_answers, wrong_answers -> DEFAULT 0
          // completed -> DEFAULT false
          // started_at -> DEFAULT now()
        })
        .select()   // RETURNING *
        .single();  // Exactement 1 resultat

    // Retourne le Map JSON complet de la session creee.
    // Contient notamment 'id' (UUID genere par PostgreSQL)
    // et 'started_at' (timestamp genere par DEFAULT now()).
    return session;
  }

  // =============================================================
  // METHODE : updateSession
  // =============================================================
  // Met a jour une session en cours (apres chaque question).
  //
  // Le Map "updates" contient les colonnes a modifier :
  //   Apres bonne reponse : {'score': 1297, 'correct_answers': 4, 'bonus_earned': 57}
  //   Apres mauvaise reponse : {'wrong_answers': 2, 'malus_received': 1}
  //
  // SQL genere :
  //   UPDATE game_sessions
  //   SET score = 1297, correct_answers = 4
  //   WHERE id = $sessionId
  // =============================================================

  /// Met a jour une session en cours avec les [updates] fournis.
  @override
  Future<void> updateSession({
    required String sessionId,
    required Map<String, dynamic> updates,
  }) async {
    // ".update(updates)" : met a jour les colonnes specifiees.
    //   Seules les colonnes presentes dans le Map sont modifiees.
    //   Les autres colonnes restent inchangees.
    //
    // ".eq('id', sessionId)" : WHERE id = $sessionId
    //   Indique QUELLE ligne mettre a jour.
    //   Sans ce filtre, TOUTES les lignes seraient modifiees
    //   (mais le RLS empeche de modifier les sessions des autres).
    //
    // Pas de "await" explicite dans un return void,
    // mais la methode est async donc le Future est retourne.
    await supabase
        .from('game_sessions')
        .update(updates)
        .eq('id', sessionId);
  }

  // =============================================================
  // METHODE : endSession
  // =============================================================
  // Cloture definitivement une session.
  //
  // Si completed = true (niveau reussi) :
  //   -> On met a jour game_sessions (completed, ended_at, duration)
  //   -> Le provider appellera ensuite updateProfile pour incrementer le niveau
  //
  // Si completed = false (echec) :
  //   -> On met a jour game_sessions (completed=false, ended_at, duration)
  //   -> Le niveau n'est PAS incremente
  //
  // SQL genere :
  //   UPDATE game_sessions
  //   SET completed = $completed,
  //       ended_at = NOW(),
  //       duration_seconds = $durationSeconds
  //   WHERE id = $sessionId
  // =============================================================

  /// Cloture une session de jeu.
  ///
  /// [completed] : `true` si le niveau est reussi, `false` sinon.
  /// [durationSeconds] : duree totale de la session en secondes.
  @override
  Future<void> endSession({
    required String sessionId,
    required bool completed,
    required int durationSeconds,
  }) async {
    await supabase
        .from('game_sessions')
        .update({
          'completed': completed,
          'duration_seconds': durationSeconds,
          // "DateTime.now().toIso8601String()" :
          //   Convertit la date actuelle en format ISO 8601.
          //   Exemple : "2025-09-15T14:47:22Z"
          //   C'est le format standard pour les timestamps en JSON.
          //
          //   "DateTime.now()" : la date et l'heure actuelles
          //   ".toIso8601String()" : convertit en String ISO 8601
          //
          //   Supabase attend ce format pour les colonnes TIMESTAMPTZ.
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);
  }
}
