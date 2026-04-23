// =============================================================
// FICHIER : lib/presentation/wireframes/t_home_tour.dart
// ROLE   : Tour guide accueil (overlay au 1er demarrage)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Migration design system (tokens, AppButton, AppCard)
//   - Overlay scrim sombre + carte centrale pagine (3 etapes)
//   - Boutons "Precedent" / "Suivant" / "Terminer" selon l'etape
//   - Marque tour_seen au finish pour ne pas le reshow
//
// USAGE :
// -------
//   if (await HomeTourController.shouldShow()) {
//     showDialog(context: ctx, barrierColor: Colors.transparent,
//       builder: (_) => const THomeTour());
//   }
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';


/// Etape de l'overlay tour.
class _TourStep {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _TourStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}


/// Gere le flag "tour deja vu" en SharedPreferences.
class HomeTourController {
  static const String _key = 'home_tour_seen';

  /// Retourne true si on doit afficher le tour.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_key) ?? false);
  }

  /// Marque le tour comme vu.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}


/// Overlay de decouverte guidee de la home.
class THomeTour extends StatefulWidget {
  const THomeTour({super.key});

  @override
  State<THomeTour> createState() => _THomeTourState();
}

class _THomeTourState extends State<THomeTour> {
  int _step = 0;

  static const List<_TourStep> _steps = [
    _TourStep(
      icon: Icons.play_arrow_rounded,
      color: TColors.primary,
      title: 'La carte de JEU',
      body: "Le bouton JOUER au milieu te fait demarrer la partie\n"
          "de ton niveau actuel.",
    ),
    _TourStep(
      icon: Icons.emoji_events_outlined,
      color: TColors.primaryVariant,
      title: 'Tes stats',
      body: "En haut, retrouve ton niveau, tes points,\n"
          "tes vies et ta serie de jours.",
    ),
    _TourStep(
      icon: Icons.explore_rounded,
      color: TColors.info,
      title: 'Decouvre',
      body: "Consulte ta collection de cartes,\n"
          "le classement et les defis a venir.",
    ),
  ];

  void _next() {
    HapticFeedback.selectionClick();
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _prev() {
    HapticFeedback.selectionClick();
    setState(() => _step--);
  }

  Future<void> _finish() async {
    await HomeTourController.markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final colors = TColors.of(context);
    final isFirst = _step == 0;
    final isLast = _step == _steps.length - 1;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.75),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Carte centrale animee au changement d'etape ---
              AnimatedSwitcher(
                duration: TDuration.normal,
                child: Container(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.all(TSpacing.xxl),
                  decoration: BoxDecoration(
                    color: colors.bgRaised,
                    borderRadius: TRadius.xxlAll,
                    boxShadow: TElevation.high,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icone gradient.
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              step.color.withValues(alpha: 0.3),
                              step.color.withValues(alpha: 0.08),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: step.color.withValues(alpha: 0.3),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Icon(step.icon, size: 40, color: step.color),
                      ),
                      const SizedBox(height: TSpacing.lg),
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style:
                            TTypography.headlineMd(color: colors.textPrimary),
                      ),
                      const SizedBox(height: TSpacing.sm),
                      Text(
                        step.body,
                        textAlign: TextAlign.center,
                        style: TTypography.bodyMd(
                            color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: TSpacing.xxl),

              // --- Progression (dots) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  final active = i == _step;
                  return AnimatedContainer(
                    duration: TDuration.quick,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      color: active
                          ? TColors.primaryVariant
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  );
                }),
              ),

              const SizedBox(height: TSpacing.xxl),

              // --- CTA ---
              Row(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: AppButton.secondary(
                        label: 'Precedent',
                        icon: Icons.arrow_back_rounded,
                        onPressed: _prev,
                        size: AppButtonSize.lg,
                        fullWidth: true,
                      ),
                    ),
                  if (!isFirst) const SizedBox(width: TSpacing.sm),
                  Expanded(
                    child: AppButton.primary(
                      label: isLast ? 'TERMINER' : 'SUIVANT',
                      trailingIcon: isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _next,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: TSpacing.md),

              // --- Passer ---
              TextButton(
                onPressed: _finish,
                child: Text(
                  'Passer le tour',
                  style: TTypography.labelLg(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
