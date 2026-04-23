// =============================================================
// FICHIER : lib/presentation/wireframes/t_onboarding_page.dart
// ROLE   : Onboarding premier demarrage (4 slides)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE :
// ---------
//   - PageScaffold + design system tokens partout
//   - Mascot trio flottante en fond (identite)
//   - 4 slides avec icones gradient + titre + body
//   - Dots indicators custom (pilule etiree pour slide active)
//   - CTA "SUIVANT" sur les 3 premiers, "COMMENCER L'AVENTURE" sur le 4e
//   - "Passer" discret en top-right
//   - Marque onboarding_seen via OnboardingPrefs au finish
//
// FLUX :
// ------
// Affiche au 1er login apres activation (cf. t_graph_loading_page).
// OnFinish -> callback fourni par le parent, typiquement navigation
// vers TGameModePage.
// =============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/core/preferences/onboarding_prefs.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';


/// Slide definition.
class _Slide {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}


class TOnboardingPage extends ConsumerStatefulWidget {
  /// Callback appele a la fin (skip ou swipe complet).
  final VoidCallback onFinish;

  const TOnboardingPage({required this.onFinish, super.key});

  @override
  ConsumerState<TOnboardingPage> createState() =>
      _TOnboardingPageState();
}

class _TOnboardingPageState extends ConsumerState<TOnboardingPage>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _mascotFloat;

  /// Slides construits dans build() pour acceder aux traductions.
  List<_Slide> _slidesFor(String Function(String) tr) => [
        _Slide(
          icon: Icons.waving_hand_rounded,
          iconColor: TColors.primaryVariant,
          title: tr('onb.slide1_title'),
          body: tr('onb.slide1_body'),
        ),
        _Slide(
          icon: Icons.auto_awesome_rounded,
          iconColor: TColors.primary,
          title: tr('onb.slide2_title'),
          body: tr('onb.slide2_body'),
        ),
        _Slide(
          icon: Icons.touch_app_rounded,
          iconColor: TColors.success,
          title: tr('onb.slide3_title'),
          body: tr('onb.slide3_body'),
        ),
        _Slide(
          icon: Icons.rocket_launch_rounded,
          iconColor: TColors.info,
          title: tr('onb.slide4_title'),
          body: tr('onb.slide4_body'),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _mascotFloat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mascotFloat.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingPrefs.markSeen();
    widget.onFinish();
  }

  void _next(int slideCount) {
    HapticFeedback.selectionClick();
    if (_currentPage < slideCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: TCurve.standard,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final colors = TColors.of(context);
    final slides = _slidesFor(tr);
    final isLast = _currentPage == slides.length - 1;

    return PageScaffold(
      showBack: false,
      child: Stack(
        children: [
          // --- Mascot en fond decoratif (opacity basse) ---
          _buildBackgroundMascot(),

          // --- Contenu ---
          Column(
            children: [
              // Top bar : bouton "Passer" a droite.
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: TSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          tr('onb.skip_btn'),
                          style: TTypography.labelLg(
                              color: colors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Slides scrollables.
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentPage = i);
                  },
                  itemBuilder: (context, i) => _buildSlide(slides[i]),
                ),
              ),

              // Dots indicators.
              _buildDots(slides.length),
              const SizedBox(height: TSpacing.xl),

              // CTA.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TSpacing.xxl,
                ),
                child: AppButton.primary(
                  label: isLast ? tr('onb.start_btn') : tr('onb.next_btn'),
                  trailingIcon: isLast
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_forward_rounded,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  onPressed: () => _next(slides.length),
                ),
              ),
              const SizedBox(height: TSpacing.xxl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundMascot() {
    // Mascotte trio en decor tres discret en bas a droite.
    // Opacity faible pour ne pas concurrencer le logo hero.
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: AnimatedBuilder(
          animation: _mascotFloat,
          builder: (context, child) {
            final t = _mascotFloat.value;
            final offsetY = math.sin(t * math.pi) * 10;
            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Opacity(opacity: 0.05, child: child),
            );
          },
          child: Image.asset(
            MockData.mascotMain,
            height: 220,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide slide) {
    final colors = TColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // --- Hero : logo TRIALGO ---
          // Le logo est la signature visuelle forte de l'onboarding.
          // Il reste le meme sur les 4 slides pour ancrer l'identite
          // (les icones de contexte viendront en dessous).
          Image.asset(
            MockData.logo,
            height: 140,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: TSpacing.xl),

          // --- Badge icone contextuelle de la slide ---
          // Petit cercle gradient avec l'icone qui illustre le
          // message de la slide (gestes, observation, fusee...).
          // Remplace l'ancien gros cercle central.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  slide.iconColor.withValues(alpha: 0.35),
                  slide.iconColor.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.iconColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Icon(slide.icon, size: 28, color: slide.iconColor),
          ),
          const SizedBox(height: TSpacing.xl),

          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TTypography.headlineLg(color: colors.textPrimary),
          ),
          const SizedBox(height: TSpacing.md),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: TTypography.bodyMd(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Indicateurs de progression (pilule extended pour la slide active).
  Widget _buildDots(int slideCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(slideCount, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: TDuration.quick,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            gradient: active
                ? const LinearGradient(
                    colors: [TColors.primary, TColors.primaryVariant],
                  )
                : null,
            color: active
                ? null
                : TColors.of(context).borderDefault,
            boxShadow: active ? TElevation.glowPrimary : null,
          ),
        );
      }),
    );
  }
}
