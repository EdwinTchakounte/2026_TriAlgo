// =============================================================
// FICHIER : lib/presentation/widgets/core/app_button.dart
// ROLE   : Bouton standard de TRIALGO (variantes + tailles + etats)
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// POURQUOI CE WIDGET ?
// --------------------
// Les pages utilisent actuellement soit ElevatedButton direct, soit
// des Container + GestureDetector custom, avec des styles eparpilles.
// Consequence : variations non voulues (radius different, glow
// absent, loading state bricolé, etc.).
//
// AppButton unifie tout avec :
//   - 4 variantes : primary (orange gradient), secondary (surface),
//     ghost (text-only), danger (rouge)
//   - 3 tailles   : sm, md, lg
//   - etats       : normal, pressed, loading, disabled
//   - icone       : leading, trailing, icon-only
//   - haptic      : feedback leger a la pression (UX mobile premium)
//   - animation   : leger scale-down au press (0.96)
//
// USAGE :
// -------
// AppButton.primary(label: 'JOUER', icon: Icons.play_arrow, onPressed: ...)
// AppButton.secondary(label: 'Annuler', onPressed: ...)
// AppButton.ghost(label: 'Passer', onPressed: ...)
// AppButton.danger(label: 'Supprimer', onPressed: ...)
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:trialgo/core/design_system/tokens/brand.dart';
import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


// =============================================================
// ENUMS : variante et taille
// =============================================================

/// Variantes visuelles du bouton.
enum AppButtonVariant {
  /// Action primaire : gradient orange+dore + glow.
  primary,

  /// Action secondaire : surface + bordure.
  secondary,

  /// Action tertiaire "text-only" : sans fond.
  ghost,

  /// Action destructive : rouge.
  danger,
}

/// Tailles standard du bouton.
enum AppButtonSize {
  /// 40px de haut (chips, actions secondaires).
  sm,

  /// 48px de haut (default, formulaires, majorite des cas).
  md,

  /// 56px de haut (CTA hero, actions primaires emphasees).
  lg,
}


// =============================================================
// WIDGET : AppButton
// =============================================================

/// Bouton standardise de TRIALGO.
class AppButton extends StatefulWidget {

  /// Texte affiche dans le bouton. Requis sauf si [iconOnly] = true.
  final String? label;

  /// Callback au tap. Si null, le bouton est desactive.
  final VoidCallback? onPressed;

  /// Icone a gauche du label (ou seule si iconOnly).
  final IconData? icon;

  /// Icone a droite du label (ex: fleche continue).
  final IconData? trailingIcon;

  /// Variante visuelle.
  final AppButtonVariant variant;

  /// Taille standard.
  final AppButtonSize size;

  /// Si true, remplace le contenu par un CircularProgressIndicator.
  /// Le bouton est alors non-interactif meme si onPressed != null.
  final bool isLoading;

  /// Si true, le bouton prend toute la largeur disponible.
  final bool fullWidth;

  /// Mode "icon only" : ignore le label, affiche uniquement [icon].
  /// Utile pour boutons d'action tres compacts.
  final bool iconOnly;

  const AppButton({
    super.key,
    this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.fullWidth = false,
    this.iconOnly = false,
  }) : assert(
          iconOnly ? icon != null : (label != null),
          'label est requis sauf si iconOnly=true (dans ce cas icon est requis)',
        );

  // ---------------------------------------------------------------
  // FACTORIES : raccourcis pour chaque variante
  // ---------------------------------------------------------------
  // Permet d'ecrire AppButton.primary(...) plutot que
  // AppButton(variant: AppButtonVariant.primary, ...).
  // Plus lisible, plus facile a autocompleter.
  // ---------------------------------------------------------------

  /// Action primaire (orange gradient + glow).
  factory AppButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    AppButtonSize size = AppButtonSize.md,
    bool isLoading = false,
    bool fullWidth = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        trailingIcon: trailingIcon,
        variant: AppButtonVariant.primary,
        size: size,
        isLoading: isLoading,
        fullWidth: fullWidth,
      );

  /// Action secondaire (surface + bordure).
  factory AppButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    AppButtonSize size = AppButtonSize.md,
    bool isLoading = false,
    bool fullWidth = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        trailingIcon: trailingIcon,
        variant: AppButtonVariant.secondary,
        size: size,
        isLoading: isLoading,
        fullWidth: fullWidth,
      );

  /// Bouton texte (sans fond).
  factory AppButton.ghost({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    IconData? trailingIcon,
    AppButtonSize size = AppButtonSize.md,
    bool fullWidth = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        trailingIcon: trailingIcon,
        variant: AppButtonVariant.ghost,
        size: size,
        fullWidth: fullWidth,
      );

  /// Action destructive (rouge).
  factory AppButton.danger({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    AppButtonSize size = AppButtonSize.md,
    bool isLoading = false,
    bool fullWidth = false,
  }) =>
      AppButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        variant: AppButtonVariant.danger,
        size: size,
        isLoading: isLoading,
        fullWidth: fullWidth,
      );

  @override
  State<AppButton> createState() => _AppButtonState();
}


class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {

  /// Controleur du scale-on-press (1.0 -> 0.96 -> 1.0).
  /// Construit l'animation dans build() via ScaleTransition.
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: TDuration.fast,
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  /// Indique si le bouton est actuellement interactif.
  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _handleTapDown(TapDownDetails _) {
    if (!_isEnabled) return;
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isEnabled) return;
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  void _handleTap() {
    if (!_isEnabled) return;
    // Feedback haptique leger (bouton standard). Silencieux sur PC.
    HapticFeedback.lightImpact();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(size: widget.size, variant: widget.variant);
    final colors = TColors.of(context);

    // Couleurs de texte et d'icone selon la variante.
    // - primary / danger : texte blanc (contraste sur fond colore)
    // - secondary / ghost : texte.primary du theme
    final foregroundColor = switch (widget.variant) {
      AppButtonVariant.primary || AppButtonVariant.danger =>
        colors.textOnBrand,
      AppButtonVariant.secondary || AppButtonVariant.ghost =>
        colors.textPrimary,
    };

    // Couleur / decoration du fond selon la variante.
    final decoration = _buildBackground(
      variant: widget.variant,
      enabled: _isEnabled,
      colors: colors,
    );

    // --- Construction du contenu (icone + label + trailing) ---
    Widget inner;
    if (widget.isLoading) {
      // Spinner qui remplace le contenu pendant le chargement.
      inner = SizedBox(
        width: spec.iconSize + 2,
        height: spec.iconSize + 2,
        child: CircularProgressIndicator(
          color: foregroundColor,
          strokeWidth: 2.2,
        ),
      );
    } else if (widget.iconOnly) {
      inner = Icon(widget.icon, color: foregroundColor, size: spec.iconSize);
    } else {
      inner = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, color: foregroundColor, size: spec.iconSize),
            const SizedBox(width: TSpacing.sm),
          ],
          Text(
            widget.label!,
            style: spec.textStyle.copyWith(color: foregroundColor),
          ),
          if (widget.trailingIcon != null) ...[
            const SizedBox(width: TSpacing.sm),
            Icon(widget.trailingIcon,
                color: foregroundColor, size: spec.iconSize),
          ],
        ],
      );
    }

    // --- Construction du conteneur (taille, background, scale) ---
    Widget button = ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _scaleController, curve: TCurve.standard),
      ),
      child: Container(
        height: spec.height,
        padding: spec.padding,
        decoration: decoration,
        alignment: Alignment.center,
        child: inner,
      ),
    );

    // --- fullWidth : etend sur toute la largeur dispo ---
    if (widget.fullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    }

    // --- GestureDetector pour capter les taps + animer le scale ---
    // On utilise TapDown/TapUp/TapCancel plutot que onTap seul pour
    // avoir le feedback visuel IMMEDIAT au doigt qui se pose.
    return Opacity(
      opacity: _isEnabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: _handleTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        behavior: HitTestBehavior.opaque,
        child: button,
      ),
    );
  }

  // =============================================================
  // METHODE : _buildBackground
  // =============================================================
  // Construit la decoration (couleur de fond, bordure, shadow)
  // en fonction de la variante et de l'etat.
  // =============================================================

  BoxDecoration _buildBackground({
    required AppButtonVariant variant,
    required bool enabled,
    required TSurfaceColors colors,
  }) {
    switch (variant) {
      case AppButtonVariant.primary:
        return BoxDecoration(
          gradient: TBrand.primary,
          borderRadius: TRadius.lgAll,
          // Glow seulement si actif : si disable, le glow serait
          // visuellement "faux" (on ne peut pas clicker).
          boxShadow: enabled ? TElevation.glowPrimary : null,
        );

      case AppButtonVariant.danger:
        return BoxDecoration(
          gradient: TBrand.error,
          borderRadius: TRadius.lgAll,
          boxShadow: enabled ? TElevation.glowError : null,
        );

      case AppButtonVariant.secondary:
        return BoxDecoration(
          color: colors.surface,
          borderRadius: TRadius.lgAll,
          border: Border.all(color: colors.borderDefault),
        );

      case AppButtonVariant.ghost:
        // Pas de fond ni bordure : texte seul, mais on garde un
        // BorderRadius pour que le ripple futur reste propre.
        return const BoxDecoration(borderRadius: TRadius.lgAll);
    }
  }

  // =============================================================
  // METHODE : _specFor
  // =============================================================
  // Retourne la "fiche technique" d'un bouton selon sa taille et
  // sa variante : height, padding, text style, icon size.
  // =============================================================

  _ButtonSpec _specFor({
    required AppButtonSize size,
    required AppButtonVariant variant,
  }) {
    switch (size) {
      case AppButtonSize.sm:
        return _ButtonSpec(
          height: 40,
          padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.lg, vertical: TSpacing.sm),
          textStyle: TTypography.titleMd(),
          iconSize: 16,
        );
      case AppButtonSize.md:
        return _ButtonSpec(
          height: 48,
          padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.xxl, vertical: TSpacing.md),
          textStyle: TTypography.titleLg(),
          iconSize: 18,
        );
      case AppButtonSize.lg:
        return _ButtonSpec(
          height: 56,
          padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.xxl, vertical: TSpacing.lg),
          textStyle: TTypography.titleLg(),
          iconSize: 20,
        );
    }
  }
}


/// Specification visuelle d'un bouton pour une combinaison size/variant.
class _ButtonSpec {
  final double height;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final double iconSize;

  const _ButtonSpec({
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.iconSize,
  });
}
