// =============================================================
// FICHIER : lib/presentation/widgets/core/app_card.dart
// ROLE   : Conteneur carte standardise (glass / solid / elevated)
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// POURQUOI CE WIDGET ?
// --------------------
// Le pattern "glassmorphism container" (fond semi-transparent +
// bordure subtile + radius arrondi) est repete ~15 fois dans l'app,
// avec a chaque fois des variations (alpha 0.05 vs 0.06 vs 0.08,
// radius 14 vs 18 vs 22, border 0.08 vs 0.1 vs 0.12).
//
// AppCard unifie en 3 variantes claires :
//   - glass    : semi-transparent, pour superposer sur un fond image
//   - solid    : opaque bgRaised, pour zones informatives
//   - elevated : solid + shadow, pour zones qui doivent se detacher
//
// Tous les rendus sont theme-aware (couleurs prises dans le theme
// actif), sans hardcoding.
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';


// =============================================================
// ENUM : variante de carte
// =============================================================

/// Variantes visuelles de AppCard.
enum AppCardVariant {
  /// Semi-transparent, effet "frosted glass".
  glass,

  /// Opaque (surface raised du theme).
  solid,

  /// Opaque + shadow (se detache du fond).
  elevated,
}


// =============================================================
// WIDGET : AppCard
// =============================================================

/// Carte standard de TRIALGO.
class AppCard extends StatelessWidget {

  /// Contenu de la carte (enfant).
  final Widget child;

  /// Variante visuelle.
  final AppCardVariant variant;

  /// Padding interne. Defaut : lg (16pt) sur tous les cotes.
  final EdgeInsetsGeometry padding;

  /// Rayon des coins. Defaut : lg (16pt).
  final BorderRadius borderRadius;

  /// Callback optionnel si la carte est tappable.
  /// Quand fourni, ajoute un ripple Material standard.
  final VoidCallback? onTap;

  /// Hauteur fixe optionnelle (utile pour aligner des cartes dans un Row).
  final double? height;

  /// Largeur fixe optionnelle.
  final double? width;

  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.glass,
    this.padding = const EdgeInsets.all(TSpacing.lg),
    this.borderRadius = TRadius.lgAll,
    this.onTap,
    this.height,
    this.width,
  });

  // ---------------------------------------------------------------
  // FACTORIES : raccourcis par variante
  // ---------------------------------------------------------------

  /// Carte glass (semi-transparente).
  factory AppCard.glass({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(TSpacing.lg),
    BorderRadius borderRadius = TRadius.lgAll,
    VoidCallback? onTap,
    double? height,
    double? width,
  }) =>
      AppCard(
        key: key,
        variant: AppCardVariant.glass,
        padding: padding,
        borderRadius: borderRadius,
        onTap: onTap,
        height: height,
        width: width,
        child: child,
      );

  /// Carte solid (opaque surface raised).
  factory AppCard.solid({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(TSpacing.lg),
    BorderRadius borderRadius = TRadius.lgAll,
    VoidCallback? onTap,
    double? height,
    double? width,
  }) =>
      AppCard(
        key: key,
        variant: AppCardVariant.solid,
        padding: padding,
        borderRadius: borderRadius,
        onTap: onTap,
        height: height,
        width: width,
        child: child,
      );

  /// Carte elevated (opaque + shadow).
  factory AppCard.elevated({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(TSpacing.lg),
    BorderRadius borderRadius = TRadius.lgAll,
    VoidCallback? onTap,
    double? height,
    double? width,
  }) =>
      AppCard(
        key: key,
        variant: AppCardVariant.elevated,
        padding: padding,
        borderRadius: borderRadius,
        onTap: onTap,
        height: height,
        width: width,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);

    // --- Decoration selon variante ---
    final decoration = switch (variant) {
      AppCardVariant.glass => BoxDecoration(
          color: colors.surface,
          borderRadius: borderRadius,
          border: Border.all(color: colors.borderSubtle),
        ),
      AppCardVariant.solid => BoxDecoration(
          color: colors.bgRaised,
          borderRadius: borderRadius,
        ),
      AppCardVariant.elevated => BoxDecoration(
          color: colors.bgRaised,
          borderRadius: borderRadius,
          boxShadow: TElevation.medium,
        ),
    };

    // --- Contenu (padding + child) ---
    Widget content = Padding(padding: padding, child: child);

    // --- Si tappable, on ajoute un InkWell pour le ripple ---
    // On wrap dans Material(type: Material.transparency) pour que le
    // ripple se dessine correctement SANS changer le fond de la carte.
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: content,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: decoration,
      // clipBehavior pour que le ripple ne depasse pas les coins arrondis.
      clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
      child: content,
    );
  }
}
