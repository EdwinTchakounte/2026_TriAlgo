// =============================================================
// FICHIER : lib/presentation/providers/game_session_provider.dart
// ROLE   : Gerer l'etat d'une session de jeu en cours
// COUCHE : Presentation > Providers
// =============================================================
//
// CE QUE GERE CE PROVIDER :
// -------------------------
// Une session de jeu = une tentative de jouer un niveau.
// Ce provider stocke et met a jour :
//   - Le score actuel
//   - Le nombre de bonnes/mauvaises reponses
//   - Le nombre de vies restantes
//   - La serie en cours (streak de bonnes reponses)
//   - La question actuelle
//   - L'etat de la session (en cours, terminee, etc.)
//
// Il orchestre le flux de jeu :
//   1. Demarrer une session (INSERT game_sessions)
//   2. Generer une question (usecase GenerateQuestion)
//   3. Valider la reponse du joueur
//   4. Appliquer bonus/malus
//   5. Passer a la question suivante ou terminer
//
// REFERENCE : Recueil v3.0, sections 7, 8, 12.6
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/constants/game_constants.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/domain/entities/card_entity.dart';
import 'package:trialgo/domain/entities/game_question_entity.dart';
import 'package:trialgo/domain/usecases/generate_question_usecase.dart';
import 'package:trialgo/data/repositories/card_repository_impl.dart';
import 'package:trialgo/data/repositories/card_trio_repository_impl.dart';
import 'package:trialgo/data/repositories/game_session_repository_impl.dart';
import 'package:trialgo/domain/repositories/game_session_repository.dart';

// =============================================================
// ENUM : GameSessionStatus
// =============================================================
// Les etats possibles d'une session de jeu.
// =============================================================

/// Etats possibles d'une session de jeu.
enum GameSessionStatus {
  /// Pas de session en cours. Le joueur est dans le menu.
  idle,

  /// Chargement : creation de la session ou generation de question.
  loading,

  /// Une question est affichee, le joueur peut repondre.
  playing,

  /// Le joueur a repondu. Affichage du resultat (bonne/mauvaise).
  answered,

  /// Le niveau est termine avec succes (seuil atteint).
  levelComplete,

  /// Le niveau est echoue (seuil non atteint ou vies = 0).
  levelFailed,

  /// Erreur technique (reseau, etc.).
  error,
}

// =============================================================
// CLASSE : GameSessionState
// =============================================================
// Etat complet d'une session de jeu.
// Immuable : chaque modification cree un nouvel objet via copyWith.
// =============================================================

/// Etat complet d'une session de jeu TRIALGO.
///
/// Contient toutes les informations necessaires pour afficher
/// l'ecran de jeu : question, score, vies, timer, etc.
class GameSessionState {
  /// Statut actuel de la session.
  final GameSessionStatus status;

  /// ID de la session en base de donnees (game_sessions.id).
  /// Null si aucune session n'est en cours.
  final String? sessionId;

  /// Numero du niveau en cours (1 a 23+).
  final int level;

  /// Configuration du niveau (distance, configs, seuil, etc.).
  /// Calculee a partir de [level] via GameConstants.
  final LevelConfig? levelConfig;

  /// La question actuellement affichee au joueur.
  /// Null si pas encore generee ou entre deux questions.
  final GameQuestionEntity? currentQuestion;

  /// Numero de la question actuelle (1, 2, 3, ...).
  /// Commence a 0, incremente a chaque nouvelle question.
  final int questionNumber;

  /// Score cumule dans cette session.
  final int score;

  /// Nombre de bonnes reponses dans cette session.
  final int correctAnswers;

  /// Nombre de mauvaises reponses dans cette session.
  final int wrongAnswers;

  /// Nombre de vies restantes.
  final int lives;

  /// Serie de bonnes reponses consecutives en cours.
  /// Remise a 0 apres une mauvaise reponse.
  final int streak;

  /// Points bonus gagnes dans cette session.
  final int bonusEarned;

  /// Points de malus recus dans cette session.
  final int malusReceived;

  /// La carte que le joueur a selectionnee (pour le feedback visuel).
  /// Null si le joueur n'a pas encore repondu.
  final CardEntity? selectedCard;

  /// `true` si la derniere reponse etait correcte.
  /// Null si pas encore repondu.
  final bool? lastAnswerCorrect;

  /// IDs des trios deja poses dans cette session (pour eviter les repetitions).
  final List<String> usedTrioIds;

  /// Message d'erreur eventuel.
  final String? errorMessage;

  /// Timestamp de debut de session (pour calculer la duree).
  final DateTime? startedAt;

  /// Constructeur avec valeurs par defaut.
  const GameSessionState({
    this.status = GameSessionStatus.idle,
    this.sessionId,
    this.level = 1,
    this.levelConfig,
    this.currentQuestion,
    this.questionNumber = 0,
    this.score = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.lives = 5,
    this.streak = 0,
    this.bonusEarned = 0,
    this.malusReceived = 0,
    this.selectedCard,
    this.lastAnswerCorrect,
    this.usedTrioIds = const [],
    this.errorMessage,
    this.startedAt,
  });

  /// Cree une copie avec les valeurs modifiees.
  ///
  /// Pattern immuable : chaque modification cree un NOUVEL objet.
  /// Les champs non specifies gardent leur valeur actuelle.
  GameSessionState copyWith({
    GameSessionStatus? status,
    String? sessionId,
    int? level,
    LevelConfig? levelConfig,
    GameQuestionEntity? currentQuestion,
    int? questionNumber,
    int? score,
    int? correctAnswers,
    int? wrongAnswers,
    int? lives,
    int? streak,
    int? bonusEarned,
    int? malusReceived,
    CardEntity? selectedCard,
    bool? lastAnswerCorrect,
    List<String>? usedTrioIds,
    String? errorMessage,
    DateTime? startedAt,
  }) {
    return GameSessionState(
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      level: level ?? this.level,
      levelConfig: levelConfig ?? this.levelConfig,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      questionNumber: questionNumber ?? this.questionNumber,
      score: score ?? this.score,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      wrongAnswers: wrongAnswers ?? this.wrongAnswers,
      lives: lives ?? this.lives,
      streak: streak ?? this.streak,
      bonusEarned: bonusEarned ?? this.bonusEarned,
      malusReceived: malusReceived ?? this.malusReceived,
      selectedCard: selectedCard ?? this.selectedCard,
      lastAnswerCorrect: lastAnswerCorrect ?? this.lastAnswerCorrect,
      usedTrioIds: usedTrioIds ?? this.usedTrioIds,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }
}

// =============================================================
// CLASSE : GameSessionNotifier
// =============================================================
// Le cerveau du jeu. Orchestre tout le flux d'une session.
// =============================================================

/// Notifier qui gere la logique d'une session de jeu.
///
/// Methodes publiques :
///   - [startSession] : demarre une nouvelle session pour un niveau
///   - [submitAnswer] : soumet la reponse du joueur
///   - [nextQuestion] : passe a la question suivante
///   - [endSession]   : termine la session (succes ou echec)
class GameSessionNotifier extends StateNotifier<GameSessionState> {
  // =============================================================
  // DEPENDANCES INJECTEES
  // =============================================================
  // Le notifier a besoin de :
  //   - generateQuestion : usecase pour creer des questions
  //   - sessionRepository : pour sauvegarder en base
  // =============================================================

  /// Usecase pour generer les questions de jeu.
  final GenerateQuestionUseCase _generateQuestion;

  /// Repository pour les operations CRUD sur game_sessions.
  final GameSessionRepository _sessionRepository;

  /// Constructeur. Initialise l'etat a "idle" (pas de session).
  GameSessionNotifier(this._generateQuestion, this._sessionRepository)
      : super(const GameSessionState());

  // =============================================================
  // METHODE : startSession
  // =============================================================
  // Demarre une nouvelle session de jeu pour un niveau donne.
  //
  // Flux :
  //   1. Charger la config du niveau
  //   2. Creer la session en base (INSERT game_sessions)
  //   3. Generer la premiere question
  //   4. Passer en etat "playing"
  // =============================================================

  /// Demarre une nouvelle session pour le niveau [level].
  ///
  /// [level] : numero du niveau (1 a 23+).
  /// [lives] : nombre de vies actuelles du joueur.
  Future<void> startSession({required int level, required int lives}) async {
    // --- Etape 1 : Passer en chargement ---
    state = state.copyWith(
      status: GameSessionStatus.loading,
      level: level,
      lives: lives,
    );

    try {
      // --- Etape 2 : Charger la config du niveau ---
      // GameConstants.getLevelConfig retourne les parametres :
      //   distance, configs, questions, seuil, temps, points
      final config = GameConstants.getLevelConfig(level);

      // --- Etape 3 : Creer la session en base ---
      // Recupere l'ID de l'utilisateur connecte.
      final userId = supabase.auth.currentUser!.id;

      // INSERT dans game_sessions, retourne l'ID de la session creee.
      final sessionData = await _sessionRepository.createSession(
        userId: userId,
        levelNumber: level,
      );

      // --- Etape 4 : Generer la premiere question ---
      final question = await _generateQuestion.call(
        level: level,
        excludeTrioIds: const [], // Pas encore de trio utilise
      );

      // --- Etape 5 : Mettre a jour l'etat ---
      state = GameSessionState(
        status: GameSessionStatus.playing,
        sessionId: sessionData['id'],   // UUID de la session creee
        level: level,
        levelConfig: config,
        currentQuestion: question,
        questionNumber: 1,              // Premiere question
        score: 0,
        correctAnswers: 0,
        wrongAnswers: 0,
        lives: lives,
        streak: 0,
        bonusEarned: 0,
        malusReceived: 0,
        usedTrioIds: [question.trioId], // Le trio de cette question
        startedAt: DateTime.now(),
      );

    } catch (e) {
      // Erreur : reseau, pas de trio disponible, etc.
      state = state.copyWith(
        status: GameSessionStatus.error,
        errorMessage: 'Erreur au demarrage : $e',
      );
    }
  }

  // =============================================================
  // METHODE : submitAnswer
  // =============================================================
  // Le joueur a tape sur une image dans la ScrollView.
  // On verifie si c'est la bonne reponse et on calcule les points.
  //
  // Flux :
  //   1. Comparer l'ID de la carte selectionnee avec correctCardId
  //   2. Si correct : calculer points + bonus
  //   3. Si incorrect : appliquer malus + perdre vie
  //   4. Passer en etat "answered" (feedback visuel 1.5s)
  //   5. Mettre a jour la session en base
  // =============================================================

  /// Soumet la reponse du joueur.
  ///
  /// [selectedCard]   : la carte choisie par le joueur dans la ScrollView.
  /// [elapsedSeconds] : le temps mis pour repondre (en secondes).
  void submitAnswer({
    required CardEntity selectedCard,
    required int elapsedSeconds,
  }) {
    // Securite : verifier qu'une question est en cours.
    final question = state.currentQuestion;
    if (question == null) return;

    // --- Verification : bonne ou mauvaise reponse ? ---
    // On compare l'ID de la carte selectionnee avec l'ID
    // de la bonne reponse stocke dans la question.
    final isCorrect = selectedCard.id == question.correctCardId;

    if (isCorrect) {
      _handleCorrectAnswer(selectedCard, elapsedSeconds);
    } else {
      _handleWrongAnswer(selectedCard);
    }
  }

  // =============================================================
  // METHODE PRIVEE : _handleCorrectAnswer
  // =============================================================
  // Calcule les points gagnes et met a jour l'etat.
  //
  // Formule de score (reference : recueil section 7.2) :
  //   Score = Points_base x Multiplicateur_distance x Bonus_temps
  //
  // Bonus possibles :
  //   - BONUS_TURBO  : reponse < 25% du temps -> x1.5
  //   - BONUS_STREAK : 3 bonnes consecutives -> +20 pts/reponse
  //   - BONUS_MEGA_STREAK : 7 bonnes consecutives -> +10s chrono
  // =============================================================

  /// Traite une bonne reponse.
  void _handleCorrectAnswer(CardEntity selectedCard, int elapsedSeconds) {
    final config = state.levelConfig!;

    // --- Calcul du score ---
    // Points de base du niveau.
    final basePoints = config.basePoints;

    // Multiplicateur selon la distance du trio (D1=1.0, D2=1.5, D3=2.0).
    final distMultiplier = GameConstants.distanceMultiplier(config.distance);

    // Bonus temps selon la rapidite de la reponse.
    final timeMult = GameConstants.timeBonus(elapsedSeconds, config.turnTimeSeconds);

    // Score final pour cette question.
    // ".floor()" : arrondit vers le bas (37.5 -> 37).
    // On ne veut pas de decimales dans le score affiche.
    final questionScore = (basePoints * distMultiplier * timeMult).floor();

    // --- Calcul de la serie (streak) ---
    final newStreak = state.streak + 1;

    // --- Calcul des bonus de serie ---
    int streakBonus = 0;
    if (newStreak >= 3) {
      // Bonus serie : +20 pts par reponse apres 3 consecutives.
      streakBonus = 20;
    }

    // --- Mise a jour de l'etat ---
    state = state.copyWith(
      status: GameSessionStatus.answered,
      selectedCard: selectedCard,
      lastAnswerCorrect: true,
      score: state.score + questionScore + streakBonus,
      correctAnswers: state.correctAnswers + 1,
      streak: newStreak,
      bonusEarned: state.bonusEarned + streakBonus,
    );

    // --- Sauvegarder en base (asynchrone, non bloquant) ---
    _updateSessionInDb();
  }

  // =============================================================
  // METHODE PRIVEE : _handleWrongAnswer
  // =============================================================
  // Applique les penalites et met a jour l'etat.
  //
  // Penalites :
  //   - MALUS_WRONG : -1 vie
  //   - Streak remise a 0
  //   - 0 points pour cette question
  // =============================================================

  /// Traite une mauvaise reponse.
  void _handleWrongAnswer(CardEntity selectedCard) {
    final newLives = state.lives - 1;

    state = state.copyWith(
      status: GameSessionStatus.answered,
      selectedCard: selectedCard,
      lastAnswerCorrect: false,
      wrongAnswers: state.wrongAnswers + 1,
      lives: newLives,
      streak: 0,               // Serie brisee
      malusReceived: state.malusReceived + 1,
    );

    // --- Verifier si les vies sont epuisees ---
    if (newLives <= 0) {
      // Pas de vies -> session terminee immediatement.
      endSession(completed: false);
      return;
    }

    _updateSessionInDb();
  }

  // =============================================================
  // METHODE : nextQuestion
  // =============================================================
  // Passe a la question suivante ou termine le niveau.
  //
  // Appele apres le delai de feedback (1.5s) suivant une reponse.
  // =============================================================

  /// Passe a la question suivante ou termine le niveau.
  Future<void> nextQuestion() async {
    final config = state.levelConfig!;

    // --- Verifier si le niveau est termine ---
    // Le niveau est termine quand toutes les questions ont ete posees.
    if (state.questionNumber >= config.questions) {
      // Verifier si le seuil de bonnes reponses est atteint.
      final passed = state.correctAnswers >= config.threshold;
      await endSession(completed: passed);
      return;
    }

    // --- Generer la question suivante ---
    state = state.copyWith(status: GameSessionStatus.loading);

    try {
      final question = await _generateQuestion.call(
        level: state.level,
        excludeTrioIds: state.usedTrioIds, // Exclure les trios deja poses
      );

      state = state.copyWith(
        status: GameSessionStatus.playing,
        currentQuestion: question,
        questionNumber: state.questionNumber + 1,
        // Ajouter le trio a la liste des utilises.
        // "[...state.usedTrioIds, question.trioId]" :
        //   Cree une nouvelle liste avec tous les anciens IDs + le nouveau.
        //   On ne modifie PAS la liste existante (immutabilite).
        usedTrioIds: [...state.usedTrioIds, question.trioId],
        // Reinitialiser le feedback de la reponse precedente.
        selectedCard: null,
        lastAnswerCorrect: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: GameSessionStatus.error,
        errorMessage: 'Erreur generation question : $e',
      );
    }
  }

  // =============================================================
  // METHODE : endSession
  // =============================================================
  // Termine la session et met a jour la base de donnees.
  // =============================================================

  /// Termine la session en cours.
  ///
  /// [completed] : `true` si le niveau est reussi, `false` sinon.
  Future<void> endSession({required bool completed}) async {
    // Calculer la duree de la session.
    final duration = state.startedAt != null
        ? DateTime.now().difference(state.startedAt!).inSeconds
        : 0;
    // "DateTime.now().difference(startedAt)" retourne un Duration.
    // ".inSeconds" convertit la duree en secondes (int).

    // Mettre a jour le statut.
    state = state.copyWith(
      status: completed
          ? GameSessionStatus.levelComplete
          : GameSessionStatus.levelFailed,
    );

    // Sauvegarder en base.
    if (state.sessionId != null) {
      try {
        await _sessionRepository.endSession(
          sessionId: state.sessionId!,
          completed: completed,
          durationSeconds: duration,
        );

        // Si le niveau est reussi, mettre a jour le profil.
        if (completed) {
          await supabase.from('user_profiles').update({
            'current_level': state.level + 1,
            'total_score': state.score, // TODO: ajouter au score existant
          }).eq('id', supabase.auth.currentUser!.id);
        }
      } catch (_) {
        // Silencieux : on ne bloque pas le joueur si la sauvegarde echoue.
      }
    }
  }

  // =============================================================
  // METHODE : resetSession
  // =============================================================
  // Remet l'etat a zero pour retourner au menu.
  // =============================================================

  /// Remet l'etat a zero (retour au menu).
  void resetSession() {
    state = const GameSessionState();
  }

  // =============================================================
  // METHODE PRIVEE : _updateSessionInDb
  // =============================================================
  // Sauvegarde l'etat actuel dans game_sessions.
  // Appele apres chaque reponse (bonne ou mauvaise).
  // Non bloquant : on ne bloque pas le jeu si la sauvegarde echoue.
  // =============================================================

  /// Sauvegarde l'etat courant en base (non bloquant).
  Future<void> _updateSessionInDb() async {
    if (state.sessionId == null) return;

    try {
      await _sessionRepository.updateSession(
        sessionId: state.sessionId!,
        updates: {
          'score': state.score,
          'correct_answers': state.correctAnswers,
          'wrong_answers': state.wrongAnswers,
          'bonus_earned': state.bonusEarned,
          'malus_received': state.malusReceived,
        },
      );
    } catch (_) {
      // Silencieux : la sauvegarde en base est un "best effort".
    }
  }
}

// =============================================================
// PROVIDER : gameSessionProvider
// =============================================================
// Point d'acces global au notifier de session de jeu.
//
// Utilisation :
//   ref.watch(gameSessionProvider)              -> lire l'etat
//   ref.read(gameSessionProvider.notifier)      -> appeler les methodes
// =============================================================

/// Provider pour la session de jeu.
final gameSessionProvider =
    StateNotifierProvider<GameSessionNotifier, GameSessionState>(
  (ref) {
    // Creer les dependances du notifier.
    // Les repositories sont instancies ici et injectes.
    final cardRepo = CardRepositoryImpl();
    final trioRepo = CardTrioRepositoryImpl();
    final sessionRepo = GameSessionRepositoryImpl();

    // Le usecase a besoin des deux repositories de cartes.
    final generateQuestion = GenerateQuestionUseCase(trioRepo, cardRepo);

    // Le notifier a besoin du usecase et du repository de sessions.
    return GameSessionNotifier(generateQuestion, sessionRepo);
  },
);
