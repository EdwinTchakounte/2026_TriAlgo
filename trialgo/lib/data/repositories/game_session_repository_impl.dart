// =============================================================
// FICHIER : lib/data/repositories/game_session_repository_impl.dart
// ROLE   : Implementation CONCRETE du GameSessionRepository
// COUCHE : Data > Repositories
// =============================================================
//
// Gere le CRUD sur les sessions de jeu selon le backend actif :
//
//   - SUPABASE : 3 ecritures successives sur la table game_sessions
//     (createSession INSERT, updateSession UPDATE, endSession UPDATE)
//
//   - FASTAPI  : 1 seul POST /api/me/sessions a la FIN de la partie
//     avec toutes les stats agregees (cf module sessions_history/).
//     createSession + updateSession deviennent NO-OP cote serveur :
//     on accumule l'etat en memoire, puis endSession fait le POST.
//
// Pourquoi 2 modeles differents ?
//   - Supabase : on aime l'incremental pour avoir la session "live"
//     visible dans la DB (debug, monitoring).
//   - FastAPI : on prefere une transaction atomique fin-de-partie
//     pour eviter les sessions orphelines (crash en cours), et le
//     backend met a jour user_games.{total_score, current_level,
//     lives} dans le meme commit.
//
// REFERENCE : Recueil de conception v3.0, section 13.5
// =============================================================

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/data/datasources/http/http_sessions_datasource.dart';
import 'package:trialgo/domain/repositories/game_session_repository.dart';

/// Implementation de [GameSessionRepository] bi-mode (Supabase ou FastAPI).
class GameSessionRepositoryImpl implements GameSessionRepository {

  // -----------------------------------------------------------
  // CACHE EN MEMOIRE (mode FastAPI uniquement)
  // -----------------------------------------------------------
  // Comme le backend FastAPI attend tout en 1 POST a la fin de la
  // partie, on accumule l'etat ici entre create/update/end.
  // Cle = sessionId local (genere par createSession).
  // -----------------------------------------------------------
  final Map<String, Map<String, dynamic>> _localSessions = {};

  // Datasource HTTP partagee (singleton Dio).
  final HttpSessionsDatasource _httpSessions = HttpSessionsDatasource();

  // =============================================================
  // METHODE : createSession
  // =============================================================

  /// Cree une nouvelle session de jeu.
  ///
  /// Supabase : INSERT direct, retourne la ligne creee (avec id genere).
  /// FastAPI  : genere un id local et bufferise l'etat en memoire.
  @override
  Future<Map<String, dynamic>> createSession({
    required String userId,
    required int levelNumber,
  }) async {
    if (ApiConfig.isFastApi) {
      // ID local provisoire : on utilise un timestamp + user_id pour
      // l'unicite. Le vrai id (UUID DB) sera attribue par le backend
      // au POST de endSession.
      final localId = 'local-${DateTime.now().millisecondsSinceEpoch}-$userId';
      final session = <String, dynamic>{
        'id': localId,
        'user_id': userId,
        'level_number': levelNumber,
        'score': 0,
        'correct_answers': 0,
        'wrong_answers': 0,
        'questions_total': 0,
        'max_streak': 0,
        'completed': false,
        'started_at': DateTime.now().toIso8601String(),
      };
      _localSessions[localId] = session;
      return session;
    }

    // Mode Supabase : INSERT + RETURNING.
    final session = await supabase
        .from('game_sessions')
        .insert({
          'user_id': userId,
          'level_number': levelNumber,
        })
        .select()
        .single();
    return session;
  }

  // =============================================================
  // METHODE : updateSession
  // =============================================================

  /// Met a jour les stats d'une session en cours.
  ///
  /// Supabase : UPDATE direct sur la ligne.
  /// FastAPI  : merge les updates dans le buffer local.
  @override
  Future<void> updateSession({
    required String sessionId,
    required Map<String, dynamic> updates,
  }) async {
    if (ApiConfig.isFastApi) {
      final existing = _localSessions[sessionId];
      if (existing != null) {
        existing.addAll(updates);
      }
      return;
    }

    await supabase
        .from('game_sessions')
        .update(updates)
        .eq('id', sessionId);
  }

  // =============================================================
  // METHODE : endSession
  // =============================================================

  /// Cloture une session.
  ///
  /// Supabase : UPDATE final (completed + ended_at + duration).
  /// FastAPI  : POST /api/me/sessions avec toutes les stats agregees
  ///            (le backend met a jour user_games dans la meme tx).
  @override
  Future<void> endSession({
    required String sessionId,
    required bool completed,
    required int durationSeconds,
  }) async {
    if (ApiConfig.isFastApi) {
      // 1. Recuperer le buffer accumule.
      final session = _localSessions[sessionId];
      if (session == null) {
        // Pas de buffer : la session a peut-etre deja ete close, ou
        // createSession n'a pas ete appele. On ignore proprement.
        return;
      }

      // 2. Resoudre game_id : il devrait etre dans le buffer (mis
      // par updateSession plus tot via game_id key) ou fallback
      // sur la level_number / contexte appelant. Pour respecter
      // l'API actuelle, on attend que l'appelant ait mis game_id
      // via updateSession. Si absent, no-op silencieux.
      final gameId = session['game_id'] as String?;
      if (gameId == null) {
        // Pas de game_id : on nettoie et abandon (logique appelante
        // doit avoir mis game_id via updateSession).
        _localSessions.remove(sessionId);
        return;
      }

      // 3. POST /api/me/sessions avec les stats finales.
      try {
        await _httpSessions.recordSession(
          gameId: gameId,
          level: (session['level_number'] as int?) ?? 1,
          scoreGained: (session['score'] as int?) ?? 0,
          correctAnswers: (session['correct_answers'] as int?) ?? 0,
          wrongAnswers: (session['wrong_answers'] as int?) ?? 0,
          questionsTotal: (session['questions_total'] as int?) ??
              (((session['correct_answers'] as int?) ?? 0) +
                  ((session['wrong_answers'] as int?) ?? 0)),
          maxStreak: (session['max_streak'] as int?) ?? 0,
          durationSeconds: durationSeconds,
          passed: completed,
          starsEarned: (session['stars_earned'] as int?) ?? 0,
        );
      } finally {
        // Quoi qu'il arrive on libere le buffer.
        _localSessions.remove(sessionId);
      }
      return;
    }

    // Mode Supabase : UPDATE final.
    await supabase
        .from('game_sessions')
        .update({
          'completed': completed,
          'duration_seconds': durationSeconds,
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId);
  }
}
