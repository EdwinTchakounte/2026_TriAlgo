// =============================================================
// FICHIER : step_indicator.dart
// ROLE    : Barre de progression "1 - 2 - 3 - 4" du wizard
// =============================================================
//
// Affichage visuel des 4 etapes en haut du wizard.
//   - Cercles numerotes
//   - Chacun a 3 etats : completed (orange plein), current
//     (orange contour), todo (gris)
//   - Sous chaque cercle, le shortLabel ("Jeu", "Cartes"...)
//   - Lignes entre les cercles pour montrer la progression
//
// Responsive : sur ecran compact on reduit les paddings pour
// que les 4 etapes tiennent dans la largeur. Sur tablette on
// laisse plus d'espace.
// =============================================================

import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/wizard_provider.dart';

class StepIndicator extends StatelessWidget {
  // Etape actuelle (souligne le cercle).
  final WizardStep current;

  const StepIndicator({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    // Sur compact on resserre tout pour eviter overflow.
    final compact = size == DeviceSize.compact;
    final circleSize = compact ? 28.0 : 36.0;
    final labelStyle = AppTextStyles.caption();

    final steps = WizardStep.values;

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          // Cercle de l'etape i. Etat compare a current.index.
          Expanded(
            child: _StepCircle(
              step: steps[i],
              status: _statusFor(i),
              size: circleSize,
              labelStyle: labelStyle,
            ),
          ),
          // Trait entre 2 cercles (sauf apres le dernier).
          if (i < steps.length - 1)
            SizedBox(
              width: compact ? 8 : 16,
              child: Container(
                height: 2,
                color: i < current.index
                    ? AppColors.brand
                    : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }

  _StepStatus _statusFor(int i) {
    if (i < current.index) return _StepStatus.completed;
    if (i == current.index) return _StepStatus.current;
    return _StepStatus.todo;
  }
}

enum _StepStatus { completed, current, todo }

class _StepCircle extends StatelessWidget {
  final WizardStep step;
  final _StepStatus status;
  final double size;
  final TextStyle labelStyle;

  const _StepCircle({
    required this.step,
    required this.status,
    required this.size,
    required this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == _StepStatus.completed;
    final isCurrent = status == _StepStatus.current;

    // Couleur de fond/contour selon status.
    final fillColor = isCompleted
        ? AppColors.brand
        : (isCurrent ? Colors.white : AppColors.background);
    final borderColor = (isCurrent || isCompleted)
        ? AppColors.brand
        : AppColors.border;
    final textColor = isCompleted
        ? Colors.white
        : (isCurrent ? AppColors.brand : AppColors.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? Icon(Icons.check, size: size * 0.55, color: Colors.white)
              : Text(
                  '${step.index + 1}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.45,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        // Label sous le cercle. Tronque si trop long.
        Text(
          step.shortLabel,
          style: labelStyle.copyWith(
            color: isCurrent ? AppColors.brand : AppColors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
