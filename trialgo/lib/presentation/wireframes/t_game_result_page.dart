// =============================================================
// FICHIER : lib/presentation/wireframes/t_game_result_page.dart
// ROLE   : Ecran de resultat de partie - celebration theatrale
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Remplace le fade-in generique par une SEQUENCE theatrale 2.8s :
//     1. (0-400ms)     Titre + mascot bounce in
//     2. (400-1600ms)  Mascotte (trio si succes, duo si echec)
//     3. (1600-2000ms) 3 etoiles en stagger (200ms entre chaque)
//     4. (2000-2800ms) Score count-up animated
//   - Particules dorees en fond (cohesion avec splash/activation)
//   - Stats en 3 cartes avec icones colorees (plus de liste plate)
//   - CTA principal gradient + CTA ghost retour accueil
//   - Theme-aware via TColors.of(context)
//
// CONTRAT PRESERVE :
// ------------------
//   - Meme constructeur (passed, level, score, correct, wrong,
//     total, maxStreak)
//   - Meme navigation : TGamePage(level+1 si success ou level si retry)
//     et THomePage en fallback
// =============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_game_page.dart';
import 'package:trialgo/presentation/wireframes/t_home_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';


/// Ecran de resultat apres une partie (celebration theatrale).
class TGameResultPage extends StatefulWidget {
  final bool passed;
  final int level;
  final int score;
  final int correctAnswers;
  final int wrongAnswers;
  final int totalQuestions;
  final int maxStreak;

  const TGameResultPage({
    required this.passed,
    required this.level,
    required this.score,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.totalQuestions,
    required this.maxStreak,
    super.key,
  });

  @override
  State<TGameResultPage> createState() => _TGameResultPageState();
}

class _TGameResultPageState extends State<TGameResultPage>
    with TickerProviderStateMixin {

  /// Controller de la sequence principale (2800ms).
  late final AnimationController _sequence;

  /// Controller en boucle infinie pour les particules de fond.
  late final AnimationController _particles;

  /// Liste de particules dorees en fond.
  final List<_ResultParticle> _particleList = [];
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();

    _sequence = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _particles = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(() {
        for (final p in _particleList) {
          p.update();
        }
      })
      ..repeat();

    // Plus de particules si succes 3 etoiles (effet confetti).
    final particleCount = widget.passed ? 40 : 16;
    for (int i = 0; i < particleCount; i++) {
      _particleList.add(_ResultParticle.random(_rnd));
    }

    // Demarrer la sequence theatrale.
    _playSequence();
  }

  @override
  void dispose() {
    _sequence.dispose();
    _particles.dispose();
    super.dispose();
  }

  /// Joue la sequence + haptic/son synchronises aux moments cles.
  Future<void> _playSequence() async {
    // Demarre l'animation globale.
    _sequence.forward();

    // Haptic medium au depart.
    HapticFeedback.mediumImpact();

    // Petits haptics a chaque etoile (1600ms, 1800ms, 2000ms si 3/3).
    final stars = _computeStars();
    for (int i = 0; i < stars; i++) {
      await Future.delayed(Duration(milliseconds: 1600 + i * 200));
      if (!mounted) return;
      HapticFeedback.lightImpact();
    }
  }

  /// Calcule le nombre d'etoiles obtenu (0-3).
  int _computeStars() {
    if (!widget.passed) return 0;
    final accuracy = widget.totalQuestions > 0
        ? (widget.correctAnswers / widget.totalQuestions * 100).round()
        : 0;
    if (accuracy >= 90) return 3;
    if (accuracy >= 70) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    final stars = _computeStars();
    final accuracy = widget.totalQuestions > 0
        ? (widget.correctAnswers / widget.totalQuestions * 100).round()
        : 0;

    return PageScaffold(
      // Pas de back : on force le choix entre continuer ou retour accueil.
      showBack: false,
      child: Stack(
        children: [
          // --- Layer 1 : particules en fond (celebration subtile) ---
          Positioned.fill(
            child: CustomPaint(
              painter: _ResultParticlePainter(
                particles: _particleList,
                repaint: _particles,
                gold: TColors.primaryVariant,
              ),
            ),
          ),

          // --- Layer 2 : contenu orchestre ---
          AnimatedBuilder(
            animation: _sequence,
            builder: (context, _) {
              final t = _sequence.value;

              // Intervalles narratifs (cf commentaire du header).
              final titleIn = _interval(t, 0.0, 0.143);     // 0-400ms
              final mascotIn = _interval(t, 0.143, 0.571);  // 400-1600ms
              final starsIn = _interval(t, 0.571, 0.714);   // 1600-2000ms
              final scoreIn = _interval(t, 0.714, 1.0);     // 2000-2800ms

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: TSpacing.xxl,
                  vertical: TSpacing.xxl,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: TSpacing.xl),

                    // --- Titre conditionnel ---
                    Opacity(
                      opacity: titleIn,
                      child: Transform.scale(
                        scale: _bouncyScale(titleIn),
                        child: Column(
                          children: [
                            Text(
                              widget.passed
                                  ? tr('result.bravo')
                                  : tr('result.almost'),
                              style: TTypography.displaySm(
                                color: widget.passed
                                    ? TColors.primaryVariant
                                    : TColors.info,
                              ),
                            ),
                            const SizedBox(height: TSpacing.xs),
                            Text(
                              (widget.passed
                                      ? tr('result.level_passed')
                                      : tr('result.level_retry'))
                                  .replaceAll('{n}', '${widget.level}'),
                              style: TTypography.bodyMd(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: TSpacing.xl),

                    // --- Mascot qui surgit ---
                    // Trio (img1) si succes, duo (img2) si echec.
                    // Scale bounce avec easeOutBack.
                    Opacity(
                      opacity: mascotIn,
                      child: Transform.scale(
                        scale: _bouncyScale(mascotIn),
                        child: Image.asset(
                          widget.passed
                              ? MockData.mascotMain
                              : MockData.mascotDuo,
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: TSpacing.lg),

                    // --- Etoiles (si succes) ou message d'echec ---
                    if (widget.passed)
                      _buildStars(stars, starsIn)
                    else
                      Opacity(
                        opacity: starsIn,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TSpacing.lg,
                            vertical: TSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                              0x26,
                              TColors.info.r.round(),
                              TColors.info.g.round(),
                              TColors.info.b.round(),
                            ),
                            borderRadius: TRadius.mdAll,
                          ),
                          child: Text(
                            tr('result.keep_going'),
                            style: TTypography.bodyMd(color: TColors.info),
                          ),
                        ),
                      ),
                    const SizedBox(height: TSpacing.xxl),

                    // --- Score anime count-up ---
                    Opacity(
                      opacity: scoreIn,
                      child: Column(
                        children: [
                          Text(
                            tr('result.score_label'),
                            style:
                                TTypography.labelSm(color: colors.textTertiary),
                          ),
                          const SizedBox(height: TSpacing.xs),
                          // TweenAnimationBuilder pour count-up sur 800ms
                          // demarre quand scoreIn > 0 (via AnimatedSwitcher
                          // cle sur la valeur cible).
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: widget.score),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text(
                              '$value',
                              style: TTypography.displayMd(
                                color: TColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TSpacing.xxl),

                    // --- Stats en 3 cartes (apparaissent apres score) ---
                    Opacity(
                      opacity: scoreIn,
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.check_circle_outline,
                              label: tr('result.stat_correct'),
                              value: '${widget.correctAnswers}'
                                  '/${widget.totalQuestions}',
                              color: TColors.success,
                            ),
                          ),
                          const SizedBox(width: TSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.percent_rounded,
                              label: tr('result.stat_accuracy'),
                              value: '$accuracy%',
                              color: TColors.info,
                            ),
                          ),
                          const SizedBox(width: TSpacing.sm),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.local_fire_department_rounded,
                              label: tr('result.stat_combo'),
                              value: 'x${widget.maxStreak}',
                              color: TColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TSpacing.xxl),

                    // --- CTA principaux (apres tout le reste) ---
                    Opacity(
                      opacity: scoreIn,
                      child: Column(
                        children: [
                          AppButton.primary(
                            label: widget.passed
                                ? tr('result.cta_next_level')
                                : tr('result.cta_retry'),
                            trailingIcon: widget.passed
                                ? Icons.arrow_forward_rounded
                                : Icons.replay_rounded,
                            fullWidth: true,
                            size: AppButtonSize.lg,
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => TGamePage(
                                    level: widget.passed
                                        ? widget.level + 1
                                        : widget.level,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: TSpacing.sm),
                          AppButton.ghost(
                            label: tr('result.cta_home'),
                            icon: Icons.home_rounded,
                            fullWidth: true,
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const THomePage(),
                                ),
                                (_) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // =============================================================
  // WIDGET : etoiles avec stagger
  // =============================================================

  Widget _buildStars(int filled, double starsIn) {
    final colors = TColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        // Chaque etoile apparait a partir de i/3 du temps de starsIn.
        final localStart = i / 3;
        final localEnd = localStart + 0.33;
        final starT = ((starsIn - localStart) / (localEnd - localStart))
            .clamp(0.0, 1.0);
        final isFilled = i < filled;
        final scale = Curves.easeOutBack.transform(starT);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: TSpacing.sm),
          child: Transform.scale(
            scale: isFilled ? scale : 1.0,
            child: Icon(
              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 52,
              color: isFilled
                  ? TColors.primaryVariant
                  : colors.borderStrong,
            ),
          ),
        );
      }),
    );
  }

  // =============================================================
  // HELPERS
  // =============================================================

  double _interval(double t, double start, double end) {
    if (t < start) return 0;
    if (t > end) return 1;
    return (t - start) / (end - start);
  }

  double _bouncyScale(double t) => Curves.easeOutBack.transform(t);
}


// =============================================================
// WIDGET : _StatCard
// =============================================================
// Petite carte stat avec icone + valeur + label.
// =============================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    return Container(
      padding: const EdgeInsets.all(TSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TRadius.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromARGB(
                0x26,
                color.r.round(),
                color.g.round(),
                color.b.round(),
              ),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: TSpacing.sm),
          Text(value, style: TTypography.titleLg(color: colors.textPrimary)),
          const SizedBox(height: TSpacing.xxs),
          Text(label, style: TTypography.labelSm(color: colors.textTertiary)),
        ],
      ),
    );
  }
}


// =============================================================
// CLASSE + PAINTER : particules dorees en fond
// =============================================================

class _ResultParticle {
  double x, y, vx, vy, size, opacity;
  _ResultParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
  });

  factory _ResultParticle.random(math.Random r) => _ResultParticle(
        x: r.nextDouble(),
        y: r.nextDouble(),
        vx: (r.nextDouble() - 0.5) * 0.001,
        vy: (r.nextDouble() - 0.8) * 0.0015, // montent plus qu'elles ne descendent
        size: 1.5 + r.nextDouble() * 3,
        opacity: 0.15 + r.nextDouble() * 0.35,
      );

  void update() {
    x = (x + vx + 1) % 1.0;
    y = (y + vy + 1) % 1.0;
  }
}


class _ResultParticlePainter extends CustomPainter {
  final List<_ResultParticle> particles;
  final Color gold;

  _ResultParticlePainter({
    required this.particles,
    required Listenable repaint,
    required this.gold,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = gold.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ResultParticlePainter old) => false;
}
