// =============================================================
// FICHIER : lib/presentation/wireframes/t_tutorial_page.dart
// ROLE   : Tutoriel interactif expliquant E + C = R
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE :
// ---------
//   - PageScaffold + design system tokens
//   - Trio de cartes demo qui s'animent : E apparait, puis C, puis
//     "=" apparait, puis R avec glow de fusion
//   - Copy simple et claire pour enfant
//   - Bouton "J'ai compris" en bas
//
// CONTRAT :
// ---------
//   Navigue simplement en pop a la fin. Accessible depuis Home/Settings/Help.
// =============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/brand.dart';
import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


class TTutorialPage extends ConsumerStatefulWidget {
  const TTutorialPage({super.key});

  @override
  ConsumerState<TTutorialPage> createState() => _TTutorialPageState();
}

class _TTutorialPageState extends ConsumerState<TTutorialPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    // Animation 4s qui boucle : les 3 cartes apparaissent en stagger,
    // puis glow de fusion, puis reset.
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    // Tente de recuperer 3 cartes reelles du graphe pour la demo.
    // Fallback sur des labels statiques si non disponible.
    final sync = ref.watch(graphSyncServiceProvider);
    final demo = _pickDemoTrio(sync);

    return PageScaffold(
      title: tr('tuto.title'),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.xxl,
          vertical: TSpacing.lg,
        ),
        child: Column(
          children: [
            const SizedBox(height: TSpacing.lg),

            // --- Hero : "Le trio magique" ---
            Text(
              tr('tuto.hero_title'),
              textAlign: TextAlign.center,
              style: TTypography.headlineLg(color: colors.textPrimary),
            ),
            const SizedBox(height: TSpacing.sm),
            Text(
              tr('tuto.hero_body'),
              textAlign: TextAlign.center,
              style: TTypography.bodyMd(color: colors.textSecondary),
            ),
            const SizedBox(height: TSpacing.xxl),

            // --- Demo trio anime ---
            _buildDemoTrio(demo),
            const SizedBox(height: TSpacing.xxl),

            // --- Explication pas a pas ---
            _buildStep(
              number: '1',
              color: TColors.info,
              title: tr('tuto.step1_title'),
              body: tr('tuto.step1_body'),
            ),
            const SizedBox(height: TSpacing.md),
            _buildStep(
              number: '2',
              color: TColors.primary,
              title: tr('tuto.step2_title'),
              body: tr('tuto.step2_body'),
            ),
            const SizedBox(height: TSpacing.md),
            _buildStep(
              number: '3',
              color: TColors.success,
              title: tr('tuto.step3_title'),
              body: tr('tuto.step3_body'),
            ),
            const SizedBox(height: TSpacing.xxl),

            // --- CTA ---
            AppButton.primary(
              label: tr('tuto.cta_ok'),
              icon: Icons.check_circle_rounded,
              fullWidth: true,
              size: AppButtonSize.lg,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Retourne 3 labels demo (E, C, R) ou fallback generique.
  List<String> _pickDemoTrio(dynamic sync) {
    try {
      final graph = sync.gameGraph;
      if (graph != null && graph.nodesByIndex.isNotEmpty) {
        // Prend le 1er noeud D1 pour illustration.
        final node = graph.nodesByIndex.values.firstWhere(
          (n) => n.depth == 1,
          orElse: () => graph.nodesByIndex.values.first,
        );
        final cards = sync.cards;
        final e = cards[node.effectiveEmettriceId]?.label ?? 'Lion';
        final c = cards[node.cableId]?.label ?? 'Miroir';
        final r = cards[node.receptriceId]?.label ?? 'Lion Miroir';
        return [e, c, r];
      }
    } catch (_) {}
    return const ['Lion', 'Miroir', 'Lion Miroir'];
  }

  // =============================================================
  // DEMO ANIMEE : 3 cartes qui apparaissent en stagger
  // =============================================================

  Widget _buildDemoTrio(List<String> labels) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        // Phases :
        //   0.0-0.25 : E apparait
        //   0.25-0.50 : C apparait
        //   0.50-0.75 : = et R apparaissent (fusion glow)
        //   0.75-1.0  : glow max, puis pause avant reset
        final eOpacity = _interval(t, 0.0, 0.25);
        final cOpacity = _interval(t, 0.25, 0.50);
        final rOpacity = _interval(t, 0.50, 0.75);
        final glow = math.max(0.0, _interval(t, 0.60, 0.90));

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _demoCard(
              role: 'E',
              label: labels[0],
              color: TColors.info,
              opacity: eOpacity,
              glow: 0,
            ),
            _plusSign(cOpacity),
            _demoCard(
              role: 'C',
              label: labels[1],
              color: TColors.primary,
              opacity: cOpacity,
              glow: 0,
            ),
            _equalSign(rOpacity),
            _demoCard(
              role: 'R',
              label: labels[2],
              color: TColors.success,
              opacity: rOpacity,
              glow: glow,
            ),
          ],
        );
      },
    );
  }

  Widget _demoCard({
    required String role,
    required String label,
    required Color color,
    required double opacity,
    required double glow,
  }) {
    return Expanded(
      child: Opacity(
        opacity: opacity,
        child: Container(
          height: 90,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: TRadius.mdAll,
            border: Border.all(color: color.withValues(alpha: 0.5 + glow * 0.5)),
            boxShadow: glow > 0
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: glow * 0.5),
                      blurRadius: 20 * glow,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                role,
                style: TTypography.displaySm(color: color),
              ),
              const SizedBox(height: TSpacing.xxs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TTypography.labelMd(
                      color: TColors.of(context).textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plusSign(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          '+',
          style: TTypography.displaySm(color: TColors.of(context).textPrimary),
        ),
      ),
    );
  }

  Widget _equalSign(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ShaderMask(
          shaderCallback: (bounds) => TBrand.primary.createShader(bounds),
          child: Text(
            '=',
            style: TTypography.displaySm(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required Color color,
    required String title,
    required String body,
  }) {
    final colors = TColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromARGB(
              0x33,
              color.r.round(),
              color.g.round(),
              color.b.round(),
            ),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TTypography.numericSm(color: color),
          ),
        ),
        const SizedBox(width: TSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TTypography.titleLg(color: colors.textPrimary),
              ),
              const SizedBox(height: TSpacing.xxs),
              Text(
                body,
                style: TTypography.bodyMd(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Interval clampe [0..1] entre start et end.
  double _interval(double t, double start, double end) {
    if (t < start) return 0;
    if (t > end) return 1;
    return (t - start) / (end - start);
  }
}
