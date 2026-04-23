// =============================================================
// FICHIER : lib/presentation/widgets/core/app_badge.dart
// ROLE   : Pastille status/compteur (neutral, success, warning, error...)
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// QUAND L'UTILISER ?
// ------------------
//   - Indiquer un statut : "EN COURS", "NOUVEAU", "D1/D2/D3"
//   - Afficher un compteur : "3" (vies), "+2" (bonus)
//   - Tagger une carte : "Premium", "Gratuit", "Locked"
//
// NE PAS UTILISER POUR :
//   - Les boutons interactifs -> utiliser AppButton.sm ou AppChip
//   - Les gros titres -> TTypography.titleSm
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Palette de couleurs semantique pour AppBadge.
enum AppBadgeTone {
  /// Gris neutre (pour tags sans semantique forte).
  neutral,

  /// Orange primary (brand, highlight).
  primary,

  /// Vert (reussite, completion).
  success,

  /// Jaune/Orange (attention, warning).
  warning,

  /// Rouge (erreur, danger).
  error,

  /// Bleu (info, neutre positif).
  info,
}


/// Pastille compacte pour status / compteur / tag.
class AppBadge extends StatelessWidget {

  /// Texte affiche dans la pastille.
  final String text;

  /// Icone optionnelle avant le texte.
  final IconData? icon;

  /// Ton semantique (couleur).
  final AppBadgeTone tone;

  /// Si true, fond solide (plus visible).
  /// Si false (defaut), fond semi-transparent (plus discret).
  final bool solid;

  const AppBadge({
    super.key,
    required this.text,
    this.icon,
    this.tone = AppBadgeTone.neutral,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsForTone(tone, context: context, solid: solid);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.sm,
        vertical: TSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(TRadius.full)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: TSpacing.xs),
          ],
          Text(
            text,
            style: TTypography.labelSm(color: fg),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // METHODE : _colorsForTone
  // =============================================================
  // Retourne (couleur_fond, couleur_texte) selon le ton et le mode
  // solid/transparent.
  //
  // Mode SOLID : fond color sature + texte blanc. Haute visibilite.
  // Mode TRANSPARENT : fond color 15% + texte color foncee. Discret.
  // =============================================================

  /// Couleurs pour un ton donne.
  (Color bg, Color fg) _colorsForTone(
    AppBadgeTone tone, {
    required BuildContext context,
    required bool solid,
  }) {
    final colors = TColors.of(context);

    // Couleur "pleine" associee a chaque ton.
    final fullColor = switch (tone) {
      AppBadgeTone.neutral => colors.textSecondary,
      AppBadgeTone.primary => TColors.primary,
      AppBadgeTone.success => TColors.success,
      AppBadgeTone.warning => TColors.warning,
      AppBadgeTone.error   => TColors.error,
      AppBadgeTone.info    => TColors.info,
    };

    if (solid) {
      // Fond sature + texte blanc pour contraste.
      return (fullColor, colors.textOnBrand);
    } else {
      // Fond semi-transparent + texte color pleine.
      // Color.fromARGB avec alpha ~15% (0x26). On ne peut pas utiliser
      // withValues en expression const, mais on n'a pas besoin de const
      // ici car le build est deja dynamique.
      return (
        Color.fromARGB(0x26, fullColor.r.round(), fullColor.g.round(), fullColor.b.round()),
        fullColor,
      );
    }
  }
}
