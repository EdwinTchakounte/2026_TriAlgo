// =============================================================
// FICHIER : lib/presentation/pages/game_page.dart
// ROLE   : Ecran principal du jeu (questions + choix + score)
// COUCHE : Presentation > Pages
// =============================================================
//
// C'EST L'ECRAN CENTRAL DE TRIALGO.
// ----------------------------------
// Il affiche :
//
//   +------------------------------------------------+
//   | [NIV.7]  ❤️❤️❤️🖤🖤   SCORE: 1240  ⏱ 28s   |  <- AppBar
//   +------------------------------------------------+
//   |                                                |
//   |   +--------+  +--------+  +--------+          |
//   |   |[IMAGE] |  |[IMAGE] |  |  ???   |          |  <- Trio
//   |   |Emett.  |  | Cable  |  | Masque |          |
//   |   +--------+  +--------+  +--------+          |
//   |                                                |
//   |   "Quelle image complete ce trio ?"            |  <- Question
//   |                                                |
//   |   <- defiler les 10 images ->                  |
//   |   +----+ +----+ +----+ +----+ +----+ +----+   |  <- Choix
//   |   |img1| |img2| |img3| |img4| |img5| |img6|   |
//   |   +----+ +----+ +----+ +----+ +----+ +----+   |
//   |                                                |
//   |   Question 3 / 10                              |  <- Progression
//   +------------------------------------------------+
//
// REFERENCE : Recueil v3.0, sections 6 et 12.6
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/presentation/providers/game_session_provider.dart';
import 'package:trialgo/presentation/providers/question_timer_provider.dart';
import 'package:trialgo/presentation/widgets/card_image_widget.dart';
import 'package:trialgo/presentation/widgets/card_scroll_view.dart';
import 'package:trialgo/presentation/widgets/timer_widget.dart';
import 'package:trialgo/presentation/widgets/lives_widget.dart';

/// Ecran principal du jeu TRIALGO.
///
/// Affiche la question en cours, les cartes visibles, la carte masquee,
/// les 10 choix, le score, les vies et le chronometre.
///
/// Utilise ConsumerStatefulWidget pour :
///   - "Consumer" : lire les providers (gameSession, timer)
///   - "Stateful" : gerer les animations post-reponse
class GamePage extends ConsumerStatefulWidget {
  /// Niveau a jouer.
  final int level;

  /// Vies actuelles du joueur.
  final int lives;

  const GamePage({
    required this.level,
    required this.lives,
    super.key,
  });

  @override
  ConsumerState<GamePage> createState() => _GamePageState();
}

class _GamePageState extends ConsumerState<GamePage> {
  // =============================================================
  // INIT STATE : demarrage de la session
  // =============================================================
  // "initState" est appele UNE SEULE FOIS quand le widget est cree.
  // C'est l'endroit ideal pour lancer la session de jeu.
  //
  // "WidgetsBinding.instance.addPostFrameCallback" :
  //   Execute le code APRES que le premier frame soit affiche.
  //   Necessaire car on ne peut pas appeler ref.read dans initState
  //   directement (le widget n'est pas encore dans l'arbre).
  // =============================================================

  @override
  void initState() {
    super.initState();

    // Demarrer la session APRES la construction du widget.
    // "addPostFrameCallback" : execute apres le premier rendu.
    // "(callback)" : la callback recoit un Duration (le temps du frame).
    // "(_)" : on ignore ce parametre (on n'en a pas besoin).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameSessionProvider.notifier).startSession(
        level: widget.level,
        lives: widget.lives,
      );
      // "widget.level" : accede au parametre "level" du widget parent.
      // Dans un ConsumerState, "widget" reference le StatefulWidget associe.
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- Lire l'etat de la session ---
    final gameState = ref.watch(gameSessionProvider);

    // --- Lire l'etat du timer ---
    final timerState = ref.watch(questionTimerProvider);

    // --- Gerer les changements d'etat de la session ---
    // Ecouter pour les evenements qui necessitent une action UI.
    ref.listen<GameSessionState>(gameSessionProvider, (previous, next) {
      // Quand une question est prete -> demarrer le timer.
      if (next.status == GameSessionStatus.playing &&
          next.currentQuestion != null &&
          previous?.status == GameSessionStatus.loading) {
        ref.read(questionTimerProvider.notifier)
            .start(next.currentQuestion!.timeLimitSeconds);
      }

      // Quand le joueur repond -> arreter le timer.
      if (next.status == GameSessionStatus.answered) {
        ref.read(questionTimerProvider.notifier).stop();

        // Passer a la question suivante apres 2 secondes.
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            ref.read(gameSessionProvider.notifier).nextQuestion();
          }
        });
      }

      // Quand le niveau est termine -> afficher le resultat.
      if (next.status == GameSessionStatus.levelComplete ||
          next.status == GameSessionStatus.levelFailed) {
        ref.read(questionTimerProvider.notifier).stop();
      }
    });

    // --- Gerer le timeout du timer ---
    ref.listen<QuestionTimerState>(questionTimerProvider, (previous, next) {
      if (next.isExpired && gameState.status == GameSessionStatus.playing) {
        // Le temps est ecoule -> traiter comme une mauvaise reponse.
        // On soumet une reponse "vide" qui sera forcement fausse.
        if (gameState.currentQuestion != null) {
          ref.read(gameSessionProvider.notifier).submitAnswer(
            selectedCard: gameState.currentQuestion!.choices.last,
            // On prend la derniere carte (peu importe laquelle, c'est un timeout).
            elapsedSeconds: gameState.currentQuestion!.timeLimitSeconds,
          );
        }
      }
    });

    // --- Affichage selon l'etat ---
    return Scaffold(
      // Fond colore subtil.
      backgroundColor: Theme.of(context).colorScheme.surface,

      // --- AppBar avec infos de jeu ---
      appBar: AppBar(
        // Bouton retour personnalise.
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Quitter la session',
          onPressed: () => _showQuitDialog(context),
          // On demande confirmation avant de quitter.
        ),

        // Titre : numero du niveau.
        title: Text('Niveau ${gameState.level}'),

        // Actions a droite : vies, score, timer.
        actions: [
          // Vies.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: LivesWidget(lives: gameState.lives, heartSize: 18),
          ),

          // Score.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                '${gameState.score}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // Timer.
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: TimerWidget(size: 40),
          ),
        ],
      ),

      // --- Corps de l'ecran ---
      body: _buildBody(gameState, timerState),
    );
  }

  // =============================================================
  // METHODE : _buildBody
  // =============================================================
  // Construit le contenu principal selon l'etat de la session.
  // =============================================================

  /// Construit le corps de l'ecran selon l'etat.
  Widget _buildBody(GameSessionState gameState, QuestionTimerState timerState) {
    // --- Etat de chargement ---
    if (gameState.status == GameSessionStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- Etat d'erreur ---
    if (gameState.status == GameSessionStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(gameState.errorMessage ?? 'Erreur inconnue'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              // "Navigator.of(context).pop()" :
              //   Retourne a l'ecran precedent (le menu principal).
              //   "pop" = retirer cet ecran de la pile de navigation.
              child: const Text('Retour au menu'),
            ),
          ],
        ),
      );
    }

    // --- Niveau termine (succes ou echec) ---
    if (gameState.status == GameSessionStatus.levelComplete ||
        gameState.status == GameSessionStatus.levelFailed) {
      return _buildEndScreen(gameState);
    }

    // --- Question en cours ---
    final question = gameState.currentQuestion;
    if (question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- Ecran de jeu principal ---
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // --- Les cartes visibles + masquee en haut ---
          // "Padding" autour de la zone des cartes.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),

            // "Row" aligne les cartes horizontalement.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              // "spaceEvenly" : espace EGAL entre chaque enfant
              // et entre les bords et les enfants.

              children: [
                // --- Carte visible 1 ---
                CardImageWidget(
                  card: question.visibleCards[0],
                  size: 100,
                  // Pas de onTap : les cartes visibles ne sont pas cliquables.
                ),

                // --- Carte visible 2 ---
                CardImageWidget(
                  card: question.visibleCards[1],
                  size: 100,
                ),

                // --- Carte masquee ("???") ---
                // Apres reponse : reveler la bonne image.
                CardImageWidget(
                  card: question.maskedCard,
                  size: 100,
                  isMasked: gameState.status != GameSessionStatus.answered,
                  // Masquee SAUF si le joueur a repondu (on revele).
                  isRevealed: gameState.status == GameSessionStatus.answered &&
                      gameState.lastAnswerCorrect == true,
                  // Bordure verte si la reponse etait correcte.
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Texte de la question ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _getQuestionText(question.config),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          // --- Feedback de reponse ---
          if (gameState.status == GameSessionStatus.answered)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                gameState.lastAnswerCorrect == true
                    ? 'Bonne reponse ! +${_lastPoints(gameState)} pts'
                    : 'Mauvaise reponse...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: gameState.lastAnswerCorrect == true
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),

          // --- Spacer : pousse le reste vers le bas ---
          // "Spacer" prend tout l'espace disponible.
          // Les cartes visibles sont en haut, les choix en bas.
          const Spacer(),

          // --- ScrollView des 10 choix ---
          CardScrollView(
            cards: question.choices,
            selectedCardId: gameState.selectedCard?.id,
            correctCardId: gameState.status == GameSessionStatus.answered
                ? question.correctCardId
                : null,
            isAnswered: gameState.status == GameSessionStatus.answered,
            onCardSelected: (card) {
              // Le joueur a tape sur une image -> soumettre la reponse.
              ref.read(gameSessionProvider.notifier).submitAnswer(
                selectedCard: card,
                elapsedSeconds: ref.read(questionTimerProvider).elapsedSeconds,
              );
            },
          ),

          const SizedBox(height: 8),

          // --- Progression (question X / Y) ---
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Question ${gameState.questionNumber} / ${gameState.levelConfig?.questions ?? "?"}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // METHODE : _buildEndScreen
  // =============================================================
  // Ecran affiche a la fin du niveau (succes ou echec).
  // =============================================================

  /// Ecran de fin de niveau.
  Widget _buildEndScreen(GameSessionState gameState) {
    final isSuccess = gameState.status == GameSessionStatus.levelComplete;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icone de resultat.
          Icon(
            isSuccess ? Icons.emoji_events : Icons.replay,
            size: 80,
            color: isSuccess ? Colors.amber : Colors.grey,
          ),

          const SizedBox(height: 16),

          // Titre.
          Text(
            isSuccess ? 'Niveau reussi !' : 'Niveau echoue',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isSuccess ? Colors.green : Colors.red,
            ),
          ),

          const SizedBox(height: 24),

          // Statistiques.
          _statRow('Score', '${gameState.score}'),
          _statRow('Bonnes reponses', '${gameState.correctAnswers}'),
          _statRow('Mauvaises reponses', '${gameState.wrongAnswers}'),
          _statRow('Serie max', '${gameState.streak}'),

          const SizedBox(height: 32),

          // Bouton retour au menu.
          ElevatedButton.icon(
            onPressed: () {
              ref.read(gameSessionProvider.notifier).resetSession();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.home),
            label: const Text('Retour au menu'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // METHODES UTILITAIRES
  // =============================================================

  /// Texte de la question selon la configuration.
  String _getQuestionText(String config) => switch (config) {
    'A' => 'Quelle image complete ce trio ?',
    'B' => 'Quelle image-cable relie ces deux images ?',
    'C' => 'Quelle est l\'image de depart ?',
    _   => 'Quelle image complete ce trio ?',
  };

  /// Points de la derniere reponse (approximation affichage).
  int _lastPoints(GameSessionState state) {
    if (state.lastAnswerCorrect != true) return 0;
    return state.levelConfig?.basePoints ?? 0;
  }

  /// Ligne de statistique (label : valeur).
  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // "spaceBetween" : le label a gauche, la valeur a droite.
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }

  /// Dialogue de confirmation pour quitter la session.
  void _showQuitDialog(BuildContext context) {
    // "showDialog" affiche un popup modal (AlertDialog).
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la session ?'),
        content: const Text(
          'Votre progression sera perdue.',
        ),
        actions: [
          // Bouton "Annuler" : ferme le dialogue.
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          // Bouton "Quitter" : termine la session et retourne au menu.
          TextButton(
            onPressed: () {
              ref.read(gameSessionProvider.notifier)
                  .endSession(completed: false);
              ref.read(gameSessionProvider.notifier).resetSession();
              Navigator.of(context).pop(); // Ferme le dialogue
              Navigator.of(context).pop(); // Retourne au menu
            },
            child: const Text('Quitter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
