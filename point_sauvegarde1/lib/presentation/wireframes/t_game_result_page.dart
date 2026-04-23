// =============================================================
// FICHIER : lib/presentation/wireframes/t_game_result_page.dart
// ROLE   : Ecran de resultats premium avec animation
// COUCHE : Presentation > Wireframes
// =============================================================
//
// Design premium : animation de fondu, etoiles animees,
// statistiques en cards, boutons d'action.
//
// REFERENCE : Recueil v3.0, section 12.7
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_game_page.dart';
import 'package:trialgo/presentation/wireframes/t_home_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Ecran de resultats premium apres un niveau.
class TGameResultPage extends StatefulWidget {
  final bool passed;
  final int level;
  final int score;
  final int correctAnswers;
  final int wrongAnswers;
  final int totalQuestions;
  final int maxStreak;

  const TGameResultPage({
    required this.passed, required this.level, required this.score,
    required this.correctAnswers, required this.wrongAnswers,
    required this.totalQuestions, required this.maxStreak, super.key,
  });

  @override
  State<TGameResultPage> createState() => _TGameResultPageState();
}

class _TGameResultPageState extends State<TGameResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final accuracy = widget.totalQuestions > 0
        ? (widget.correctAnswers / widget.totalQuestions * 100).round()
        : 0;

    final int stars;
    if (!widget.passed) { stars = 0; }
    else if (accuracy >= 90) { stars = 3; }
    else if (accuracy >= 70) { stars = 2; }
    else { stars = 1; }

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return FadeTransition(
                opacity: _fadeIn,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        // --- Icone de resultat ---
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: widget.passed
                                  ? [const Color(0xFFF7C948).withValues(alpha: 0.3), const Color(0xFFFF6B35).withValues(alpha: 0.1)]
                                  : [const Color(0xFFEF5350).withValues(alpha: 0.2), const Color(0xFFEF5350).withValues(alpha: 0.05)],
                            ),
                          ),
                          child: Icon(
                            widget.passed ? Icons.emoji_events_rounded : Icons.replay_rounded,
                            size: 52,
                            color: widget.passed ? const Color(0xFFF7C948) : const Color(0xFFEF5350),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          widget.passed ? '${tr('result.success')} ${widget.level}' : '${tr('result.failed')} ${widget.level}',
                          style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800,
                            color: widget.passed ? Colors.white : const Color(0xFFEF5350),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          widget.passed ? tr('result.congrats') : tr('result.retry_msg'),
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4)),
                        ),

                        // --- Etoiles ---
                        if (widget.passed) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 44,
                                color: i < stars ? const Color(0xFFF7C948) : Colors.white.withValues(alpha: 0.15),
                              ),
                            )),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // --- Stats ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            children: [
                              _stat(tr('result.score'), '${widget.score} ${tr('common.pts')}', Icons.star_rounded, const Color(0xFFF7C948)),
                              _divider(),
                              _stat(tr('result.correct'), '${widget.correctAnswers}/${widget.totalQuestions}', Icons.check_circle_rounded, const Color(0xFF66BB6A)),
                              _divider(),
                              _stat(tr('result.accuracy'), '$accuracy%', Icons.percent_rounded, const Color(0xFF42A5F5)),
                              _divider(),
                              _stat(tr('result.max_streak'), '${widget.maxStreak}', Icons.local_fire_department_rounded, const Color(0xFFFF6B35)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- Bouton principal ---
                        SizedBox(
                          width: double.infinity, height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.passed
                                    ? [const Color(0xFFFF6B35), const Color(0xFFFF8F5E)]
                                    : [const Color(0xFF42A5F5), const Color(0xFF64B5F6)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: (widget.passed ? const Color(0xFFFF6B35) : const Color(0xFF42A5F5)).withValues(alpha: 0.4),
                                  blurRadius: 16, offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => TGamePage(level: widget.passed ? widget.level + 1 : widget.level),
                                  ),
                                );
                              },
                              icon: Icon(widget.passed ? Icons.arrow_forward_rounded : Icons.replay_rounded),
                              label: Text(widget.passed ? tr('result.next_level') : tr('result.retry'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const THomePage()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.home_rounded, color: Colors.white38, size: 18),
                          label: Text(tr('result.home'), style: const TextStyle(color: Colors.white38)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  Widget _divider() => Divider(color: Colors.white.withValues(alpha: 0.06), height: 20);
}
