// =============================================================
// FICHIER : lib/data/models/session_model.dart
// ROLE   : Convertir les lignes Supabase <-> SessionEntity
// COUCHE : Data > Models
// =============================================================
//
// POURQUOI UN MODEL ?
// -------------------
// Les "Entity" (domain layer) ne doivent PAS savoir comment
// les donnees sont stockees en BDD. Elles representent le concept
// metier pur (une session = les champs utiles au jeu).
//
// Le "Model" (data layer) sait traduire le JSON brut renvoye
// par Supabase vers une SessionEntity propre pour le domain.
// C'est la frontiere "I/O" entre la BDD et le reste du code.
//
// Cela permet de :
//   - Changer le schema BDD sans toucher au domain
//   - Tester le domain sans mock Supabase
//   - Gerer les valeurs nulles / manquantes au seul endroit utile
// =============================================================

import 'package:trialgo/domain/entities/session_entity.dart';


/// Utilitaires pour convertir une ligne Supabase en SessionEntity.
class SessionModel {

  /// Cree une SessionEntity a partir d'un Map JSON renvoye par Supabase.
  ///
  /// [json] correspond a une ligne de la table user_sessions renvoyee
  /// par un select(). Les cles sont les noms de colonnes SQL.
  ///
  /// Appel type :
  /// ```dart
  /// final data = await supabase.from('user_sessions').select()...;
  /// final sessions = (data as List).map(SessionModel.fromJson).toList();
  /// ```
  static SessionEntity fromJson(Map<String, dynamic> json) {
    return SessionEntity(
      // --- id : UUID genere par PostgreSQL ---
      // Toujours present (PRIMARY KEY NOT NULL), cast direct.
      id: json['id'] as String,

      // --- user_id / game_id : FK UUID ---
      // Toujours presents (NOT NULL dans la migration).
      userId: json['user_id'] as String,
      gameId: json['game_id'] as String,

      // --- level : INT NOT NULL ---
      // Cast direct, jamais null par design.
      level: json['level'] as int,

      // --- Scores et compteurs : INT NOT NULL DEFAULT 0 ---
      // Cast direct. Le DEFAULT 0 cote BDD garantit une valeur.
      scoreGained: json['score_gained'] as int,
      correctAnswers: json['correct_answers'] as int,
      wrongAnswers: json['wrong_answers'] as int,
      questionsTotal: json['questions_total'] as int,
      maxStreak: json['max_streak'] as int,
      durationSeconds: json['duration_seconds'] as int,

      // --- passed : BOOLEAN NOT NULL DEFAULT FALSE ---
      passed: json['passed'] as bool,

      // --- stars_earned : INT NOT NULL DEFAULT 0, CHECK 0-3 ---
      starsEarned: json['stars_earned'] as int,

      // --- played_at : TIMESTAMPTZ NOT NULL ---
      // Supabase renvoie un ISO 8601 (ex: "2026-04-20T14:30:00+00:00").
      // DateTime.parse le lit correctement et retourne une date en UTC.
      // toLocal() peut etre appele a l'affichage pour le fuseau du user.
      playedAt: DateTime.parse(json['played_at'] as String),
    );
  }

  /// Convertit les champs d'une session en Map pret pour INSERT.
  ///
  /// Note : on N'INCLUT PAS id ni played_at : ils sont remplis par
  /// PostgreSQL via les DEFAULT (gen_random_uuid() et NOW()).
  /// Les renvoyer ici risquerait d'ecraser les valeurs serveur.
  ///
  /// On n'inclut pas non plus user_id : il est ajoute par le service
  /// a partir de supabase.auth.currentUser.id pour garantir qu'un
  /// joueur ne peut pas inserer une session au nom d'un autre.
  static Map<String, dynamic> toInsertJson({
    required String gameId,
    required int level,
    required int scoreGained,
    required int correctAnswers,
    required int wrongAnswers,
    required int questionsTotal,
    required int maxStreak,
    required int durationSeconds,
    required bool passed,
    required int starsEarned,
  }) {
    return {
      // Les cles doivent correspondre aux noms de colonnes SQL.
      'game_id': gameId,
      'level': level,
      'score_gained': scoreGained,
      'correct_answers': correctAnswers,
      'wrong_answers': wrongAnswers,
      'questions_total': questionsTotal,
      'max_streak': maxStreak,
      'duration_seconds': durationSeconds,
      'passed': passed,
      'stars_earned': starsEarned,
    };
  }
}
