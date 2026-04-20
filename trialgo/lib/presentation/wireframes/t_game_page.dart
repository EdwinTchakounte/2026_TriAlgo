// =============================================================
// FICHIER : lib/presentation/wireframes/t_game_page.dart
// ROLE   : Ecran de jeu PREMIUM avec design carte de jeu (Hearthstone/Marvel Snap style)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// DESIGN PREMIUM CARD GAME
// -------------------------
// Ce fichier conserve TOUTE la logique de jeu identique (timer, scoring,
// navigation, mock data) mais transforme entierement la couche visuelle
// pour donner l'impression de jouer avec de VRAIES CARTES sur une table
// de jeu, inspire de Hearthstone, Marvel Snap et Legends of Runeterra.
//
// ELEMENTS VISUELS :
//   - Fond multi-couches avec particules animees reactives
//   - Barre superieure en verre depoli (frosted glass)
//   - Cartes du trio en forme de vraies cartes a jouer
//   - Carte masquee (?) avec dos de carte anime et glow pulsant
//   - Operateurs en losanges dores
//   - Cartes de choix avec ombre portee et effets de selection
//   - Barre de progression custom avec indicateurs de points
//   - Feedback anime (banniere, shake, bounce)
//
// REFERENCE : Recueil v3.0, sections 6 et 12.6
// =============================================================

import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trialgo/core/constants/game_constants.dart';
import 'package:trialgo/data/services/audio_service.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_game_result_page.dart';
import 'package:trialgo/presentation/wireframes/widgets/game/game_card_widgets.dart';
import 'package:trialgo/presentation/wireframes/widgets/game/game_painters.dart';

// =============================================================
// WIDGET PRINCIPAL : TGamePage
// =============================================================
// Ecran de jeu principal. Accepte un [level] (numero du niveau)
// et gere toute la logique de questions, timer, scoring et
// navigation vers la page de resultats.
// =============================================================

/// Ecran de jeu principal jouable avec design premium carte de jeu.
///
/// [level] : numero du niveau en cours de jeu.
class TGamePage extends ConsumerStatefulWidget {
  final int level;
  const TGamePage({required this.level, super.key});

  @override
  ConsumerState<TGamePage> createState() => _TGamePageState();
}

class _TGamePageState extends ConsumerState<TGamePage>
    with TickerProviderStateMixin {
  // =============================================================
  // ETAT DU JEU (identique a l'original)
  // =============================================================
  // Ces variables tracent la progression du joueur :
  //   - _questionNumber : question actuelle (1-based)
  //   - _totalQuestions : nombre total de questions dans le niveau
  //   - _score : score cumule du joueur
  //   - _lives : vies restantes (perd 1 vie toutes les 2 erreurs)
  //   - _correctAnswers / _wrongAnswers : compteurs de reponses
  //   - _streak / _maxStreak : serie de bonnes reponses consecutives
  //   - _remainingSeconds : temps restant pour la question courante
  //   - _selectedCardId : ID de la carte selectionnee par le joueur
  //   - _isAnswered : true si le joueur a deja repondu
  //   - _lastAnswerCorrect : true si la derniere reponse etait bonne
  // =============================================================

  int _questionNumber = 1;
  // Nombre total de questions pour ce niveau. Initialise dans
  // initState() depuis GameConstants.getLevelConfig(widget.level).
  late int _totalQuestions;
  int _score = 0;

  /// Temps de jeu cumulatif en secondes. Augmente chaque seconde
  /// pendant toute la partie (sauf en pause). Affiche en haut a droite
  /// pour que le joueur voie combien de temps il passe en jeu.
  int _sessionElapsedSeconds = 0;
  Timer? _elapsedTimer;
  int _lives = 3;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _remainingSeconds = 30;
  Timer? _timer;
  String? _selectedCardId;
  bool _isAnswered = false;
  bool _lastAnswerCorrect = false;

  /// Etat de pause : true si la partie est mise en pause.
  bool _isPaused = false;

  // =============================================================
  // DONNEES DE LA QUESTION COURANTE
  // =============================================================
  // Le trio E + C = R est choisi aleatoirement parmi MockData.mockTrios.
  // _choices contient la bonne reponse + les distracteurs melanges.
  // =============================================================

  late Map<String, dynamic> _currentEmettrice;
  late Map<String, dynamic> _currentCable;
  late Map<String, dynamic> _currentReceptrice;
  late String _correctCardId;
  late List<Map<String, dynamic>> _choices;

  // =============================================================
  // CONTROLEURS D'ANIMATION
  // =============================================================
  // TickerProviderStateMixin permet de creer plusieurs AnimationControllers.
  //
  // _feedbackController : anime le feedback (correct/incorrect) avec un
  //   effet elastique (bounce) lors de l'affichage.
  //
  // _particleController : tourne en boucle pour animer les particules
  //   en arriere-plan. Il sert de repaint notifier pour le CustomPainter.
  //
  // _pulseController : anime le glow pulsant de la carte masquee (?)
  //   et du timer quand il est < 10 secondes. Boucle infinie.
  //
  // _scoreScaleController : breve animation de scale-up quand le score
  //   augmente (1.0 -> 1.15 -> 1.0, 300ms), pour un feedback visuel.
  //
  // _shakeController : animation de secousse horizontale pour le
  //   feedback d'erreur (translateX oscillation, 300ms).
  // =============================================================

  late AnimationController _feedbackController;
  late Animation<double> _feedbackScale;

  late AnimationController _particleController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scoreScaleController;
  late Animation<double> _scoreScale;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // =============================================================
  // PARTICULES FLOTTANTES
  // =============================================================
  // 20 particules qui flottent dans le fond. Leur couleur change
  // selon l'etat du jeu (gold par defaut, vert apres bonne reponse,
  // rouge apres mauvaise reponse).
  // =============================================================

  final List<GameParticle> _particles = [];
  final _random = Random();

  // Couleur cible des particules (change selon l'etat du jeu).
  Color _particleTargetColor = const Color(0xFFF7C948);

  @override
  void initState() {
    super.initState();

    // --- Feedback : animation elastique pour le bandeau correct/incorrect ---
    // elasticOut produit un effet de rebond (depasse la cible puis revient).
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _feedbackScale = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    );

    // --- Particules : controller en boucle pour le repaint continu ---
    // Les particules sont mises a jour dans le listener de ce controller.
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateParticles);
    _particleController.repeat();

    // --- Pulse : oscillation 1.0 -> 1.02 -> 1.0 pour le glow ---
    // Utilise pour la carte masquee et le timer < 10s.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // --- Score scale : breve animation quand le score augmente ---
    // 1.0 -> 1.15 -> 1.0 en 300ms. Declenchee manuellement dans _handleAnswer.
    _scoreScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scoreScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _scoreScaleController,
      curve: Curves.easeOut,
    ));

    // --- Shake : oscillation horizontale pour l'erreur ---
    // +-5px en 300ms. Appliquee sur le bandeau de feedback d'erreur.
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 5, end: -5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -5, end: 4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 4, end: -3), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 25),
    ]).animate(_shakeController);

    // Initialiser le nombre de questions depuis la config du niveau.
    // Exemple : niveau 1-3 = 8 questions, niveau 4-6 = 10, etc.
    _totalQuestions = GameConstants.getLevelConfig(widget.level).questions;

    // Initialiser les 20 particules avec des positions aleatoires.
    _initParticles();

    // La musique de fond est deja lancee par TAuthGate au demarrage.
    // Elle continue pendant le jeu sans interruption.

    // Son de debut de partie (swoosh d'entree).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).playSfx(SoundEffect.swoosh);
    });

    // Demarrer le chronometre cumulatif (temps total de jeu).
    // Tick chaque seconde, sauf en pause.
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isPaused) return;
      setState(() => _sessionElapsedSeconds++);
    });

    // Preparer la premiere question.
    _setupQuestion();
  }

  /// Cree 20 particules avec des positions, tailles et vitesses aleatoires.
  /// Chaque particule demarre a un endroit aleatoire de l'ecran
  /// pour eviter qu'elles apparaissent toutes au meme endroit au lancement.
  void _initParticles() {
    for (int i = 0; i < 20; i++) {
      _particles.add(GameParticle(
        x: _random.nextDouble() * 400,
        y: _random.nextDouble() * 800,
        speed: 0.3 + _random.nextDouble() * 0.7,
        size: 1.5 + _random.nextDouble() * 2.5,
        opacity: 0.1 + _random.nextDouble() * 0.25,
        color: const Color(0xFFF7C948), // Or par defaut.
        wobble: _random.nextDouble() * 2 * pi,
      ));
    }
  }

  /// Met a jour la position de chaque particule a chaque frame d'animation.
  /// Les particules montent lentement (y -= speed) avec un mouvement
  /// sinusoidal lateral (x += sin(wobble)). Quand une particule sort
  /// par le haut, elle reapparait en bas avec de nouvelles proprietes.
  void _updateParticles() {
    for (final p in _particles) {
      // Deplacement vertical vers le haut.
      p.y -= p.speed;
      // Mouvement lateral sinusoidal pour un effet organique.
      p.wobble += 0.02;
      p.x += sin(p.wobble) * 0.3;
      // Transition douce de la couleur vers la couleur cible.
      p.color = _particleTargetColor;

      // Si la particule sort par le haut, la replacer en bas
      // avec de nouvelles proprietes aleatoires.
      if (p.y < -10) {
        p.y = 820;
        p.x = _random.nextDouble() * 400;
        p.speed = 0.3 + _random.nextDouble() * 0.7;
        p.size = 1.5 + _random.nextDouble() * 2.5;
        p.opacity = 0.1 + _random.nextDouble() * 0.25;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedTimer?.cancel();
    _feedbackController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _scoreScaleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Format mm:ss pour le chronometre de temps de jeu.
  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // =============================================================
  // POPUP PLEIN ECRAN D'UNE CARTE
  // =============================================================
  // Affiche une carte en grand (zoom visuel) dans un dialog
  // sombre. Le joueur peut tap n'importe ou pour fermer.
  //
  // Utilisation :
  //   - Tap sur une carte visible du trio
  //   - Long press sur une carte de la grille de propositions
  //
  // Pendant l'affichage du popup, le timer de la question continue
  // (pour eviter de faire pause) mais le jeu reste jouable.
  // =============================================================

  void _showCardFullscreen(Map<String, dynamic> card) {
    final imageUrl = card['imageUrl'] as String;
    final label = card['label'] as String? ?? '';

    // Son de feedback leger.
    ref.read(audioServiceProvider).playSfx(SoundEffect.click);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return GestureDetector(
          // Tap n'importe ou pour fermer.
          onTap: () => Navigator.of(ctx).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  // --- Image plein ecran avec zoom interactif ---
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Hero(
                        tag: 'card-${card['id']}',
                        child: Material(
                          color: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B35)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFF7C948)
                                        .withValues(alpha: 0.15),
                                    blurRadius: 60,
                                    spreadRadius: 16,
                                  ),
                                ],
                                border: Border.all(
                                  color: const Color(0xFFF7C948)
                                      .withValues(alpha: 0.6),
                                  width: 2,
                                ),
                              ),
                              child: InteractiveViewer(
                                // Permet de pincer pour zoomer.
                                minScale: 0.8,
                                maxScale: 3.0,
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, _) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFFF6B35),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    padding: const EdgeInsets.all(40),
                                    color: Colors.white10,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.white24,
                                      size: 80,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- Label en bas avec gradient ---
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFF7C948)],
                          ).createShader(bounds),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rajdhani(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap pour fermer',
                          style: GoogleFonts.exo2(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Bouton close en haut a droite ---
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =============================================================
  // LOGIQUE DE JEU (identique a l'original)
  // =============================================================

  /// Convertit une carte du graphe en Map pour la compatibilite UI.
  ///
  /// L'UI existante utilise des `Map<String, dynamic>` avec les cles
  /// 'id', 'label', 'imageUrl'. Pour eviter de tout reecrire, on
  /// adapte la GraphCardEntity en Map equivalent.
  Map<String, dynamic> _cardToMap(GraphCardEntity card) {
    return {
      'id': card.id,
      'label': card.label,
      'imageUrl': card.imageUrl,
      'type': '', // non utilise dans l'affichage
    };
  }

  /// Prepare une nouvelle question en utilisant le GRAPHE LOCAL.
  ///
  /// Le flow :
  /// 1. Determine les parametres du niveau (distance + configs)
  ///    via GameConstants.getLevelConfig(level).
  /// 2. Appelle GenerateGameQuestionUseCase qui :
  ///    - Tire un noeud logique non joue (D1, D2 ou D3)
  ///    - Applique la config (A, B ou C) pour masquer une carte
  ///    - Genere les distracteurs depuis le catalogue local
  /// 3. Convertit les cartes en Maps pour la compatibilite UI.
  ///
  /// Si tous les noeuds logiques sont epuises, retourne null
  /// et termine la session immediatement.
  void _setupQuestion() {
    // --- Lire les parametres du niveau ---
    // Le niveau encode (distance, tableIndex) via la config dynamique
    // basee sur le nombre reel de tables disponibles dans le pool.
    final pool = ref.read(graphSyncServiceProvider).logicalNodes;
    final tablesPerDistance = [
      pool?.numberOfTables(1) ?? 0,
      pool?.numberOfTables(2) ?? 0,
      pool?.numberOfTables(3) ?? 0,
      pool?.numberOfTables(4) ?? 0,
      pool?.numberOfTables(5) ?? 0,
    ];
    final levelConfig = GameConstants.getLevelConfigForTables(
      widget.level,
      tablesPerDistance,
    );

    // --- Generer la question via le usecase ---
    // Pioche dans la table specifique (distance + tableIndex) pour
    // garantir qu'aucun trio de la meme chaine n'apparait deux fois
    // dans la meme partie.
    final question = ref.read(generateQuestionProvider).call(
          distance: levelConfig.distance,
          tableIndex: levelConfig.tableIndex,
          availableConfigs: levelConfig.configs,
          distractorCount: 5,
        );

    // --- Cas : plus de noeud disponible ---
    // Tous les noeuds logiques de cette distance ont ete joues.
    // Fin de session immediate avec resultats actuels.
    if (question == null) {
      _endSessionWithResults();
      return;
    }

    // --- Convertir en Maps pour l'UI existante ---
    // visibleCards[0] -> slot E (premier emplacement du trio)
    // visibleCards[1] -> slot C (deuxieme emplacement)
    // maskedCard      -> slot R (troisieme, affichee comme "?")
    //
    // Note : peu importe la config utilisee, on remplit toujours
    // les 3 slots dans cet ordre. La carte masquee est dans le 3eme.
    _currentEmettrice = _cardToMap(question.visibleCards[0]);
    _currentCable = _cardToMap(question.visibleCards[1]);
    _currentReceptrice = _cardToMap(question.maskedCard);
    _correctCardId = question.correctCardId;

    // --- Choix : 1 bonne + 5 distracteurs = 6 cartes ---
    // Deja melanges par le usecase.
    _choices = question.choices.map(_cardToMap).toList();

    // Mettre a jour le temps selon le niveau.
    final timePerQuestion = levelConfig.turnTimeSeconds;

    setState(() {
      _selectedCardId = null;
      _isAnswered = false;
      _lastAnswerCorrect = false;
      _remainingSeconds = timePerQuestion;
    });

    _particleTargetColor = const Color(0xFFF7C948);
    _feedbackController.reset();
    _startTimer();
  }

  /// Termine la session prematurement (epuisement des noeuds).
  ///
  /// Affiche la page de resultats avec l'etat actuel du joueur.
  void _endSessionWithResults() {
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TGameResultPage(
          passed: _correctAnswers >= 4,
          level: widget.level,
          score: _score,
          correctAnswers: _correctAnswers,
          wrongAnswers: _wrongAnswers,
          totalQuestions: _totalQuestions,
          maxStreak: _maxStreak,
        ),
      ),
    );
  }

  /// Demarre le decompte de 30 secondes.
  /// A chaque seconde, decremente _remainingSeconds.
  /// Quand il atteint 0, appelle _handleAnswer(null) pour timeout.
  ///
  /// Respecte l'etat de pause : si _isPaused == true, le timer ne
  /// decremente pas (on saute le tick).
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_isPaused) return; // Tic ignore pendant la pause.
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          if (!_isAnswered) _handleAnswer(null);
        }
      });
    });
  }

  /// Mettre en pause / reprendre la partie.
  /// Freeze le timer et pause la musique.
  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    final audio = ref.read(audioServiceProvider);
    if (_isPaused) {
      audio.pauseBackgroundMusic();
    } else {
      audio.resumeBackgroundMusic();
    }
  }

  /// Traite la reponse du joueur (ou null pour timeout).
  /// Calcule le score : basePoints (20) + timeBonus + streakBonus.
  /// Gere les vies (perd 1 vie toutes les 2 erreurs).
  /// Apres 1.8s, passe a la question suivante ou aux resultats.
  void _handleAnswer(String? cardId) {
    if (_isAnswered) return;
    _timer?.cancel();

    final isCorrect = cardId == _correctCardId;

    // Jouer le son de feedback approprie.
    final audio = ref.read(audioServiceProvider);
    if (cardId == null) {
      // Timeout : son d'erreur
      audio.playSfx(SoundEffect.wrong);
    } else if (isCorrect) {
      audio.playSfx(SoundEffect.correct);
      // Sauvegarder la carte gagnee dans le deck du joueur (BDD).
      // Fire-and-forget : on n'attend pas pour ne pas bloquer l'UI.
      ref.read(profileProvider.notifier).unlockCard(_correctCardId);
    } else {
      audio.playSfx(SoundEffect.wrong);
    }

    setState(() {
      _selectedCardId = cardId;
      _isAnswered = true;
      _lastAnswerCorrect = isCorrect;

      if (isCorrect) {
        _correctAnswers++;
        _streak++;
        if (_streak > _maxStreak) _maxStreak = _streak;
        final basePoints = 20;
        final timeBonus = (_remainingSeconds * 0.5).round();
        final streakBonus = _streak >= 3 ? 10 : 0;
        _score += basePoints + timeBonus + streakBonus;

        // Feedback visuel : particules vertes + animation scale du score.
        _particleTargetColor = const Color(0xFF66BB6A);
        _scoreScaleController.forward(from: 0);
      } else {
        _wrongAnswers++;
        _streak = 0;
        if (_wrongAnswers % 2 == 0 && _lives > 0) _lives--;

        // Feedback visuel : particules rouges + animation shake.
        _particleTargetColor = const Color(0xFFEF5350);
        _shakeController.forward(from: 0);
      }
    });

    _feedbackController.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_questionNumber >= _totalQuestions || _lives <= 0) {
        // Jouer le son de fin de partie.
        final passed = _correctAnswers >= 4;
        ref.read(audioServiceProvider).playSfx(
          passed ? SoundEffect.victory : SoundEffect.defeat,
        );

        // Sauvegarder la partie cote Supabase en DEUX etapes :
        //   1. INSERT dans user_sessions (historique detaille : level,
        //      correct, wrong, duree, streak, etoiles, ...)
        //   2. UPDATE dans user_games (cumul : total_score, level, vies)
        // Les deux operations sont encapsulees dans recordGameSession.
        //
        // Le calcul du nombre de vies utilisees est base sur _wrongAnswers
        // et le seuil livesPerWrong du niveau (1 vie toutes les 2 erreurs).
        final livesUsed = (_wrongAnswers ~/ 2);
        ref.read(profileProvider.notifier).recordGameSession(
          level: widget.level,
          scoreGained: _score,
          correctAnswers: _correctAnswers,
          wrongAnswers: _wrongAnswers,
          questionsTotal: _totalQuestions,
          maxStreak: _maxStreak,
          // _sessionElapsedSeconds est incremente par _elapsedTimer pendant
          // toute la partie, pause incluse puis exclue. C'est la meilleure
          // approximation de la duree active cote client.
          durationSeconds: _sessionElapsedSeconds,
          passed: passed,
          livesUsed: livesUsed,
          levelUp: passed,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TGameResultPage(
              passed: passed,
              level: widget.level,
              score: _score,
              correctAnswers: _correctAnswers,
              wrongAnswers: _wrongAnswers,
              totalQuestions: _totalQuestions,
              maxStreak: _maxStreak,
            ),
          ),
        );
      } else {
        setState(() => _questionNumber++);
        _setupQuestion();
      }
    });
  }

  // =============================================================
  // BUILD : Construction de l'interface premium
  // =============================================================

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    // Ratio du timer pour les indicateurs visuels (1.0 = plein, 0.0 = vide).
    final timerRatio = _remainingSeconds / 30;
    // Couleur dynamique du timer : vert > 60%, jaune > 30%, rouge sinon.
    final Color timerColor = timerRatio > 0.6
        ? const Color(0xFF66BB6A)
        : timerRatio > 0.3
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);

    return Scaffold(
      body: Stack(
        children: [
          // =======================================================
          // COUCHE 1 : FOND DEGRADE MULTI-COUCHES
          // =======================================================
          // Trois couleurs profondes (#0A0A1A -> #1A1035 -> #0D1B2A)
          // creent un fond sombre et immersif style table de jeu.
          // Le degrade vertical donne de la profondeur.
          // =======================================================
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A1A), // Noir spatial profond en haut.
                  Color(0xFF1A1035), // Violet sombre au milieu.
                  Color(0xFF0D1B2A), // Bleu nuit en bas.
                ],
              ),
            ),
          ),

          // =======================================================
          // COUCHE 2 : PARTICULES ANIMEES REACTIVES
          // =======================================================
          // 20 particules flottent en permanence. Leur couleur change
          // en fonction de l'etat du jeu :
          //   - Or (defaut) : ambiance neutre, mysterieuse
          //   - Vert : apres une bonne reponse (celebration)
          //   - Rouge : apres une mauvaise reponse (alerte)
          // Le CustomPainter est relie au _particleController pour
          // etre repeint a chaque frame d'animation (~60fps).
          // =======================================================
          Positioned.fill(
            child: CustomPaint(
              painter: GameParticlePainter(
                particles: _particles,
                repaintNotifier: _particleController,
              ),
            ),
          ),

          // =======================================================
          // COUCHE 3 : CONTENU DU JEU
          // =======================================================
          // Utilise un SingleChildScrollView pour eviter les overflow
          // sur les petits ecrans et distribuer l'espace correctement.
          SafeArea(
            child: Column(
              children: [
                // =======================================================
                // BARRE SUPERIEURE FROSTED GLASS
                // =======================================================
                // Un panneau en verre depoli contient tous les indicateurs :
                //   - Bouton quitter (cercle avec X)
                //   - Badge de niveau (pill avec degrade orange->or)
                //   - Coeurs de vie (mini-cartes avec degrade)
                //   - Score (pill doree avec etoile, scale-up a chaque gain)
                //   - Timer circulaire (anneau degrade, pulse si < 10s)
                //
                // Le fond blanc a 5% + bordure blanche a 8% + coins arrondis
                // en bas creent l'effet "frosted glass" sans BackdropFilter
                // (qui serait couteux en performance ici).
                // =======================================================
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  // =====================================================
                  // HEADER EN 2 LIGNES pour eviter l'overflow
                  // =====================================================
                  // Ligne 1 : Quit + Pause + Level + Spacer + Hearts
                  // Ligne 2 : Chrono total + Score + Timer question
                  // =====================================================
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ========== LIGNE 1 : controles + niveau + vies ==========
                      Row(
                        children: [
                          // Bouton quitter.
                          GestureDetector(
                            onTap: _showQuitDialog,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white38,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Bouton pause.
                          GestureDetector(
                            onTap: _togglePause,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _isPaused
                                    ? const Color(0xFFFF6B35)
                                        .withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                color: _isPaused
                                    ? const Color(0xFFFF6B35)
                                    : Colors.white38,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Badge niveau.
                          Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B35),
                                  Color(0xFFF7C948),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1B2A),
                                borderRadius: BorderRadius.circular(8.5),
                              ),
                              child: Text(
                                'Niv. ${widget.level}',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF7C948),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),

                      // --- Coeurs de vie : mini-cartes compactes ---
                      ...List.generate(5, (i) {
                        final isActive = i < _lives;
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Container(
                            width: 18,
                            height: 22,
                            decoration: BoxDecoration(
                              // Fond degrade pour les coeurs actifs, transparent sinon.
                              gradient: isActive
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFEF5350),
                                        Color(0xFFC62828),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(4),
                              // Contour pour les coeurs vides.
                              border: isActive
                                  ? null
                                  : Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                              // Glow subtil pour les coeurs actifs.
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFEF5350)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.1),
                              size: 11,
                            ),
                          ),
                        );
                      }),
                        ],
                      ),

                      // ========== LIGNE 2 : chrono + score + timer ==========
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Chrono cumulatif mm:ss.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  color: Colors.white38,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatElapsed(_sessionElapsedSeconds),
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),

                          // Score pill doree.
                          ScaleTransition(
                            scale: _scoreScale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF7C948)
                                        .withValues(alpha: 0.2),
                                    const Color(0xFFFF6B35)
                                        .withValues(alpha: 0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFF7C948)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFF7C948),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_score',
                                    style: GoogleFonts.rajdhani(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFF7C948),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Timer circulaire de la question.
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              final scale = _remainingSeconds < 10
                                  ? (0.95 +
                                      (_pulseAnimation.value - 1.0) * 5 +
                                      0.05)
                                  : 1.0;
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: timerRatio,
                                    strokeWidth: 3,
                                    backgroundColor: Colors.white
                                        .withValues(alpha: 0.06),
                                    valueColor: AlwaysStoppedAnimation(
                                        timerColor),
                                  ),
                                  Center(
                                    child: Text(
                                      '$_remainingSeconds',
                                      style: GoogleFonts.rajdhani(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: timerColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- BODY SCROLLABLE ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),

                // =======================================================
                // SECTION TRIO : E + C = ? (LE CENTRE DU JEU)
                // =======================================================
                // C'est la piece maitresse de l'ecran. Trois cartes sont
                // affichees dans un conteneur en verre depoli :
                //   - Carte Emettrice (bordure bleue) : l'image de base
                //   - Carte Cable (bordure orange) : la transformation
                //   - Carte Receptrice (bordure verte ou masquee) : le resultat
                //
                // Les operateurs (+, =) sont des losanges dores au lieu
                // de simples cercles, pour un style plus premium.
                //
                // Le conteneur a un degrade subtil sur le bord superieur
                // pour le distinguer du fond.
                // =======================================================
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            // Fond plus doux : gradient tres subtil.
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.035),
                                Colors.white.withValues(alpha: 0.012),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            children: [
                              // Label "TRIO" en lettres espacees, plus discret.
                              Text(
                                tr('game.trio'),
                                style: GoogleFonts.exo2(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.25),
                                  letterSpacing: 5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Les 3 cartes du trio avec operateurs losange.
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  GameTrioCard(
                                    card: _currentEmettrice,
                                    label: tr('game.emettrice'),
                                    borderColor: const Color(0xFF42A5F5),
                                    pulseAnimation: _pulseAnimation,
                                    pulseController: _pulseController,
                                    onView: () =>
                                        _showCardFullscreen(_currentEmettrice),
                                  ),
                                  const GameOperatorBadge(symbol: '+'),
                                  GameTrioCard(
                                    card: _currentCable,
                                    label: tr('game.cable'),
                                    borderColor: const Color(0xFFFF6B35),
                                    pulseAnimation: _pulseAnimation,
                                    pulseController: _pulseController,
                                    onView: () =>
                                        _showCardFullscreen(_currentCable),
                                  ),
                                  const GameOperatorBadge(symbol: '='),
                                  GameTrioCard(
                                    card: _currentReceptrice,
                                    label: tr('game.receptrice'),
                                    borderColor: const Color(0xFF66BB6A),
                                    isMasked: !_isAnswered,
                                    isRevealed: _isAnswered,
                                    pulseAnimation: _pulseAnimation,
                                    pulseController: _pulseController,
                                    onView: () =>
                                        _showCardFullscreen(_currentReceptrice),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Texte de la question (plus doux, moins charge).
                        Text(
                          tr('game.question'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.exo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 0.3,
                          ),
                        ),

                        const SizedBox(height: 8),

                // =======================================================
                // BANNIERE DE FEEDBACK (correct / incorrect / timeout)
                // =======================================================
                // Trois etats possibles :
                //   1. Correct : banniere verte avec checkmark bounce +
                //      texte "+XX pts" et icone d'etoiles
                //   2. Incorrect : banniere rouge avec X + shake animation
                //   3. Timeout : banniere rouge avec icone horloge
                //
                // La banniere utilise ScaleTransition (elasticOut) pour
                // apparaitre avec un rebond. Le shake (translateX oscillation)
                // est ajoute par-dessus pour les erreurs.
                // =======================================================
                SizedBox(
                  height: 44,
                  child: _isAnswered
                      ? AnimatedBuilder(
                          // Utiliser le shakeAnimation pour le deplacement horizontal.
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            // Appliquer le shake uniquement pour les mauvaises reponses.
                            final offset = _lastAnswerCorrect
                                ? 0.0
                                : _shakeAnimation.value;
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              child: child,
                            );
                          },
                          child: ScaleTransition(
                            scale: _feedbackScale,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                // Degrade de fond vert ou rouge selon la reponse.
                                gradient: LinearGradient(
                                  colors: _lastAnswerCorrect
                                      ? [
                                          const Color(0xFF66BB6A)
                                              .withValues(alpha: 0.25),
                                          const Color(0xFF388E3C)
                                              .withValues(alpha: 0.15),
                                        ]
                                      : [
                                          const Color(0xFFEF5350)
                                              .withValues(alpha: 0.25),
                                          const Color(0xFFC62828)
                                              .withValues(alpha: 0.15),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _lastAnswerCorrect
                                      ? const Color(0xFF66BB6A)
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFEF5350)
                                          .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Icone : check, X ou horloge.
                                  Icon(
                                    _lastAnswerCorrect
                                        ? Icons.check_circle_rounded
                                        : _selectedCardId == null
                                            ? Icons.access_time_rounded
                                            : Icons.cancel_rounded,
                                    color: _lastAnswerCorrect
                                        ? const Color(0xFF66BB6A)
                                        : const Color(0xFFEF5350),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  // Texte de feedback avec points.
                                  Text(
                                    _lastAnswerCorrect
                                        ? '${tr('game.correct')}  +${20 + (_remainingSeconds * 0.5).round()} ${tr('common.pts')}'
                                        : _selectedCardId == null
                                            ? tr('game.timeout')
                                            : tr('game.incorrect'),
                                    style: GoogleFonts.rajdhani(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _lastAnswerCorrect
                                          ? const Color(0xFF66BB6A)
                                          : const Color(0xFFEF5350),
                                    ),
                                  ),
                                  // Etoile bonus si correct.
                                  if (_lastAnswerCorrect) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: Color(0xFFF7C948),
                                      size: 16,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 12),

                        // Label "Choisissez la bonne image".
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 14,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr('game.choose'),
                                style: GoogleFonts.rajdhani(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Grille de choix 3 colonnes x 2 lignes (6 cartes).
                        // Design moderne : cartes en grille au lieu du scroll
                        // horizontal, pour une meilleure visibilite et UX.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            children: [
                              // Ligne 1 : cartes 0, 1, 2.
                              Row(
                                children: List.generate(3, (i) {
                                  if (i >= _choices.length) return const Expanded(child: SizedBox());
                                  return Expanded(child: _buildGridChoiceCard(i));
                                }),
                              ),
                              const SizedBox(height: 8),
                              // Ligne 2 : cartes 3, 4, 5.
                              Row(
                                children: List.generate(3, (i) {
                                  final idx = i + 3;
                                  if (idx >= _choices.length) return const Expanded(child: SizedBox());
                                  return Expanded(child: _buildGridChoiceCard(idx));
                                }),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Barre de progression.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${tr('game.question_of')} $_questionNumber / $_totalQuestions',
                                    style: GoogleFonts.rajdhani(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  if (_streak >= 2)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                // Interpolation de couleur orange -> rouge
                                // synchronisee avec le pulse controller.
                                final color = Color.lerp(
                                  const Color(0xFFFF6B35),
                                  const Color(0xFFEF5350),
                                  _pulseController.value,
                                )!;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Icone flamme avec couleur animee.
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 14,
                                        color: color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${tr('game.streak_label')} $_streak',
                                        style: GoogleFonts.rajdhani(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Indicateurs de points (un par question).
                      // Chaque point est un petit cercle : rempli si la
                      // question a ete repondue, vide sinon, avec le point
                      // courant legerement plus grand.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_totalQuestions, (i) {
                          final isAnswered = i < _questionNumber - 1 ||
                              (i == _questionNumber - 1 && _isAnswered);
                          final isCurrent = i == _questionNumber - 1;
                          return Container(
                            width: isCurrent ? 10 : 7,
                            height: isCurrent ? 10 : 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              // Degrade orange->or pour les points repondus.
                              gradient: isAnswered
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B35),
                                        Color(0xFFF7C948),
                                      ],
                                    )
                                  : null,
                              // Contour pour les points non repondus.
                              border: isAnswered
                                  ? null
                                  : Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                              // Glow pour le point courant.
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFF6B35)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),

                      // Barre de progression custom.
                      // Track sombre (#0D0D20, 6px, arrondi) + remplissage
                      // degrade orange->or proportionnel a la progression.
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D20),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculer la largeur du remplissage.
                            final fillWidth = constraints.maxWidth *
                                (_questionNumber / _totalQuestions);
                            return Stack(
                              children: [
                                // Remplissage degrade anime.
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  width: fillWidth,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B35),
                                        Color(0xFFF7C948),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                            ],
                          ),
                        ),

                      ], // Fin Column interne (scrollable)
                    ),
                  ),
                ), // Fin Expanded + SingleChildScrollView
              ],
            ),
          ),
        ],
      ),
    );
  }


  // =============================================================
  // DIALOGUE DE CONFIRMATION DE SORTIE
  // =============================================================
  // Affiche un dialogue modal demandant au joueur s'il veut
  // vraiment quitter la partie. Le timer est mis en pause pendant
  // le dialogue et reprend si le joueur choisit "Continuer".
  // Logique IDENTIQUE a l'original.
  // =============================================================

  /// Construit une carte de choix pour la grille 3x2.
  /// Wrapper qui recupere les donnees de la carte a l'index donne
  /// et construit le widget avec les bons etats visuels.
  Widget _buildGridChoiceCard(int index) {
    final card = _choices[index];
    final cardId = card['id'] as String;
    final isSelected = _selectedCardId == cardId;
    final isCorrectCard = cardId == _correctCardId;
    final isWrong = isSelected && _isAnswered && !isCorrectCard;
    final isRevealed = isCorrectCard && _isAnswered;

    return GameChoiceCard(
      card: card,
      isSelected: isSelected,
      isRevealed: isRevealed,
      isWrong: isWrong,
      feedbackScale: _feedbackScale,
      onView: () => _showCardFullscreen(card),
      onTap: _isAnswered ? null : () => _handleAnswer(cardId),
    );
  }

  void _showQuitDialog() {
    final tr = TLocale.of(context);
    _timer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF16163A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icone de sortie dans un cercle rouge subtil.
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.exit_to_app_rounded,
                  color: Color(0xFFEF5350),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              // Titre du dialogue.
              Text(
                tr('game.quit_title'),
                style: GoogleFonts.rajdhani(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              // Description.
              Text(
                tr('game.quit_desc'),
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Bouton "Continuer" : degrade orange, reprend le timer.
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startTimer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TTheme.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr('game.continue'),
                    style: TTheme.buttonStyle(size: 16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Bouton "Quitter" : contour subtil, ferme l'ecran.
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    tr('game.quit'),
                    style: GoogleFonts.exo2(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
