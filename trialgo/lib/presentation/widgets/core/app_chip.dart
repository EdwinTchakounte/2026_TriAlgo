// =============================================================
// FICHIER : lib/presentation/widgets/core/app_chip.dart
// ROLE   : Chip interactive (selectable, filter, toggle)
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// DIFFERENCE AVEC AppBadge :
// --------------------------
//   AppBadge  = statique, affichage d'information (ex: "NOUVEAU", "D2")
//   AppChip   = interactif, on clique pour selectionner/deselectionner
//
// EXEMPLES D'USAGE :
// ------------------
//   - Filtres de gallery : "Toutes" / "Debloquees" / "A debloquer"
//   - Switch de categories : "E" / "C" / "R"
//   - Tags selectionnables dans un questionnaire
//
// ACCESSIBILITE :
// ---------------
// Hauteur minimum 36px pour rester tactile. Role button implicit.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Chip interactive de TRIALGO (selectable).
class AppChip extends StatelessWidget {

  /// Texte affiche dans le chip.
  final String label;

  /// Icone optionnelle a gauche.
  final IconData? icon;

  /// Etat selectionne.
  final bool selected;

  /// Callback quand l'utilisateur tape. Si null, le chip est desactive.
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final enabled = onTap != null;

    // --- Couleurs selon etat ---
    // Selectionne : fond primary + texte blanc + bordure primary.
    // Non-selectionne : surface + texte secondary + bordure subtile.
    final Color bgColor;
    final Color fgColor;
    final Color borderColor;
    if (selected) {
      bgColor = TColors.primary;
      fgColor = colors.textOnBrand;
      borderColor = TColors.primary;
    } else {
      bgColor = colors.surface;
      fgColor = colors.textSecondary;
      borderColor = colors.borderDefault;
    }

    return GestureDetector(
      onTap: enabled
          ? () {
              // Feedback haptique leger a la selection.
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: TDuration.quick,
        curve: TCurve.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.md,
          vertical: TSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.all(Radius.circular(TRadius.full)),
          border: Border.all(color: borderColor),
        ),
        // Opacite reduite si desactive, pour signaler l'inactivite.
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fgColor),
                const SizedBox(width: TSpacing.xs),
              ],
              Text(
                label,
                style: TTypography.labelLg(color: fgColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
