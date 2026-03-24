// =============================================================
// FICHIER : lib/presentation/wireframes/t_game_page.dart
// ROLE   : Ecran de jeu JOUABLE avec vraies images (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// C'EST L'ECRAN CENTRAL DU JEU, ENTIEREMENT JOUABLE.
// -----------------------------------------------------
// Les images sont chargees depuis picsum.photos (reseau).
// Le joueur peut reellement :
//   - Voir les cartes E + C et deviner R
//   - Scroller et taper sur une reponse
//   - Recevoir un feedback (correct/incorrect)
//   - Suivre son score et ses vies
//   - Terminer le niveau et voir les resultats
//
// Le trio change a chaque question (3 trios en rotation).
// Les distracteurs sont melanges aleatoirement.
//
// REFERENCE : Recueil v3.0, sections 6 et 12.6
// =============================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_game_result_page.dart';

/// Ecran de jeu principal jouable avec images reseau.
///
/// [level] : numero du niveau joue.
class TGamePage extends StatefulWidget {
  final int level;
  const TGamePage({required this.level, super.key});

  @override
  State<TGamePage> createState() => _TGamePageState();
}

class _TGamePageState extends State<TGamePage> with TickerProviderStateMixin {
  // --- Etat du jeu ---
  int _questionNumber = 1;
  final int _totalQuestions = 6;
  int _score = 0;
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

  // --- Donnees de la question courante ---
  late Map<String, dynamic> _currentEmettrice;
  late Map<String, dynamic> _currentCable;
  late Map<String, dynamic> _currentReceptrice;
  late String _correctCardId;
  late List<Map<String, dynamic>> _choices;

  // --- Animation du feedback ---
  late AnimationController _feedbackController;
  late Animation<double> _feedbackScale;

  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Animation de zoom pour le feedback (correct/incorrect).
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _feedbackScale = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
      // "elasticOut" : effet de rebond (overshoot puis stabilise).
    );

    _setupQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  /// Prepare une nouvelle question avec un trio aleatoire.
  void _setupQuestion() {
    // Choisir un trio aleatoire parmi les 3 disponibles.
    final trioIndex = _random.nextInt(MockData.mockTrios.length);
    final trio = MockData.mockTrios[trioIndex];

    // Recuperer les cartes du trio.
    _currentEmettrice = MockData.allCards[trio['emettrice']]!;
    _currentCable = MockData.allCards[trio['cable']]!;
    _currentReceptrice = MockData.allCards[trio['receptrice']]!;
    _correctCardId = _currentReceptrice['id'] as String;

    // Construire les choix : bonne reponse + distracteurs melanges.
    _choices = [
      _currentReceptrice,
      ...MockData.mockDistractors,
    ];
    _choices.shuffle(_random);

    setState(() {
      _selectedCardId = null;
      _isAnswered = false;
      _lastAnswerCorrect = false;
      _remainingSeconds = 30;
    });

    _feedbackController.reset();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
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

  /// Traite la reponse du joueur (ou null pour timeout).
  void _handleAnswer(String? cardId) {
    if (_isAnswered) return;
    _timer?.cancel();

    final isCorrect = cardId == _correctCardId;

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
      } else {
        _wrongAnswers++;
        _streak = 0;
        if (_wrongAnswers % 2 == 0 && _lives > 0) _lives--;
      }
    });

    _feedbackController.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (_questionNumber >= _totalQuestions || _lives <= 0) {
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
      } else {
        setState(() => _questionNumber++);
        _setupQuestion();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final timerRatio = _remainingSeconds / 30;
    final Color timerColor = timerRatio > 0.6
        ? const Color(0xFF66BB6A)
        : timerRatio > 0.3
            ? const Color(0xFFFFA726)
            : const Color(0xFFEF5350);

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // =======================================================
              // APPBAR CUSTOM
              // =======================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                child: Row(
                  children: [
                    // Bouton quitter.
                    GestureDetector(
                      onTap: _showQuitDialog,
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Niveau.
                    Text(
                      '${tr('common.level')} ${widget.level}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const Spacer(),
                    // Vies.
                    ...List.generate(5, (i) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: i < _lives ? const Color(0xFFEF5350) : Colors.white12,
                        size: 16,
                      ),
                    )),
                    const SizedBox(width: 12),
                    // Score.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7C948).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_score',
                        style: const TextStyle(color: Color(0xFFF7C948), fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Timer circulaire.
                    SizedBox(
                      width: 38, height: 38,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: timerRatio,
                            strokeWidth: 3,
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation(timerColor),
                          ),
                          Center(
                            child: Text(
                              '$_remainingSeconds',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: timerColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // =======================================================
              // TRIO : E + C = ? (dans un conteneur dedie)
              // =======================================================
              // Conteneur avec fond subtil pour separer le trio du reste.
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    // Label discret.
                    Text(
                      tr('game.trio'),
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.25), letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Les 3 cartes avec operateurs.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTrioCard(_currentEmettrice, label: tr('game.emettrice')),
                        _operatorBadge('+'),
                        _buildTrioCard(_currentCable, label: tr('game.cable')),
                        _operatorBadge('='),
                        _buildTrioCard(
                          _currentReceptrice,
                          label: tr('game.receptrice'),
                          isMasked: !_isAnswered,
                          isRevealed: _isAnswered,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // =======================================================
              // QUESTION
              // =======================================================
              Text(
                tr('game.question'),
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 8),

              // =======================================================
              // FEEDBACK
              // =======================================================
              SizedBox(
                height: 40,
                child: _isAnswered
                    ? ScaleTransition(
                        scale: _feedbackScale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: _lastAnswerCorrect
                                ? const Color(0xFF66BB6A).withValues(alpha: 0.15)
                                : const Color(0xFFEF5350).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _lastAnswerCorrect
                                  ? const Color(0xFF66BB6A).withValues(alpha: 0.4)
                                  : const Color(0xFFEF5350).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _lastAnswerCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: _lastAnswerCorrect ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _lastAnswerCorrect
                                    ? '${tr('game.correct')}  +${20 + (_remainingSeconds * 0.5).round()} ${tr('common.pts')}'
                                    : _selectedCardId == null ? tr('game.timeout') : tr('game.incorrect'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _lastAnswerCorrect ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const Spacer(),

              // =======================================================
              // LABEL SECTION CHOIX
              // =======================================================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 3, height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('game.choose'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    const Spacer(),
                    Icon(Icons.swipe_rounded, size: 16, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(width: 4),
                    Text(tr('game.scroll'), style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.2))),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // =======================================================
              // CHOIX (ScrollView horizontale avec vraies images)
              // =======================================================
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _choices.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final card = _choices[index];
                    final cardId = card['id'] as String;
                    final isSelected = _selectedCardId == cardId;
                    final isCorrectCard = cardId == _correctCardId;
                    final isWrong = isSelected && _isAnswered && !isCorrectCard;
                    final isRevealed = isCorrectCard && _isAnswered;

                    return _buildChoiceCard(
                      card: card,
                      isSelected: isSelected,
                      isRevealed: isRevealed,
                      isWrong: isWrong,
                      onTap: _isAnswered ? null : () => _handleAnswer(cardId),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // =======================================================
              // PROGRESSION
              // =======================================================
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tr('game.question_of')} $_questionNumber / $_totalQuestions',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        if (_streak >= 2)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${tr('game.streak_label')} $_streak',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFFF6B35), fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _questionNumber / _totalQuestions,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // WIDGETS DE CONSTRUCTION
  // =============================================================

  /// Badge operateur (+, =) entre les cartes du trio.
  Widget _operatorBadge(String symbol) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          symbol,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.35)),
        ),
      ),
    );
  }

  /// Carte du trio (E, C ou ?) en haut de l'ecran.
  Widget _buildTrioCard(Map<String, dynamic> card, {
    String label = '',
    bool isMasked = false,
    bool isRevealed = false,
  }) {
    final imageUrl = card['imageUrl'] as String;

    return Column(
      children: [
        Container(
          width: 76, height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRevealed
              ? const Color(0xFF66BB6A)
              : Colors.white.withValues(alpha: 0.12),
          width: isRevealed ? 2.5 : 1,
        ),
        boxShadow: isRevealed
            ? [BoxShadow(color: const Color(0xFF66BB6A).withValues(alpha: 0.3), blurRadius: 12)]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: isMasked
            ? Container(
                color: const Color(0xFF16213E),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFFFF6B35))),
                      Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3))),
                    ],
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFF16213E),
                        child: const Center(
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B35))),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      color: const Color(0xFF16213E),
                      child: Icon(Icons.image_not_supported_outlined, color: Colors.white.withValues(alpha: 0.2), size: 24),
                    ),
                  ),
                  // Label en bas.
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),
        // Label sous la carte.
        const SizedBox(height: 4),
        Text(
          isMasked ? '?' : (card['label'] as String),
          style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }

  /// Carte de choix dans la ScrollView du bas.
  Widget _buildChoiceCard({
    required Map<String, dynamic> card,
    required bool isSelected,
    required bool isRevealed,
    required bool isWrong,
    VoidCallback? onTap,
  }) {
    final imageUrl = card['imageUrl'] as String;
    final label = card['label'] as String;

    final Color borderColor;
    if (isRevealed) {
      borderColor = const Color(0xFF66BB6A);
    } else if (isWrong) {
      borderColor = const Color(0xFFEF5350);
    } else if (isSelected) {
      borderColor = const Color(0xFFF7C948);
    } else {
      borderColor = Colors.white.withValues(alpha: 0.08);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 110, height: 130,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: (isRevealed || isWrong || isSelected) ? 2.5 : 1),
            boxShadow: (isSelected || isRevealed)
                ? [BoxShadow(color: borderColor.withValues(alpha: 0.4), blurRadius: 10)]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFF16213E),
                      child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFFF6B35)))),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    color: const Color(0xFF16213E),
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.white.withValues(alpha: 0.2)),
                  ),
                ),
                // Label en overlay.
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Check icon si revelee.
                if (isRevealed)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(color: Color(0xFF66BB6A), shape: BoxShape.circle),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
                // X icon si mauvaise reponse.
                if (isWrong)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(color: Color(0xFFEF5350), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuitDialog() {
    final tr = TLocale.of(context);
    _timer?.cancel(); // Pause le timer pendant le dialogue.

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF16163A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icone.
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFEF5350), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                tr('game.quit_title'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                tr('game.quit_desc'),
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Bouton Continuer.
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startTimer(); // Reprendre le timer.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('game.continue'), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              // Bouton Quitter.
              SizedBox(
                width: double.infinity, height: 46,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('game.quit'), style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
