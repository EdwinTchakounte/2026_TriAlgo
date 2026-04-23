// =============================================================
// FICHIER : lib/core/design_system/theme/app_theme.dart
// ROLE   : Construit les ThemeData dark et light de TRIALGO
// COUCHE : Core > Design System > Theme
// =============================================================
//
// CE FICHIER ASSEMBLE :
// ---------------------
//   1. Les couleurs brand et surface (tokens/colors.dart)
//   2. Le type scale (tokens/typography.dart)
//   3. Les radius, spacing et motion
//   4. Les styles Material (ElevatedButton, AppBar, Dialog, ...)
//
// EN DEUX VARIANTES :
// -------------------
//   - TAppTheme.dark  -> premium gaming (bleu profond + orange)
//   - TAppTheme.light -> clean diurne (blanc casse + orange)
//
// COMPATIBILITE :
// ---------------
// Le code existant utilise TTheme (ancien) qui reste fonctionnel.
// Les nouvelles pages (Phase 2-6) utiliseront directement TAppTheme
// et les tokens, et TTheme sera progressivement remplace.
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Assembleur des ThemeData TRIALGO.
class TAppTheme {

  // ---------------------------------------------------------------
  // THEME DARK
  // ---------------------------------------------------------------

  /// ThemeData pour le mode dark (premium gaming).
  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        surface: TSurfaceColors.dark,
      );

  // ---------------------------------------------------------------
  // THEME LIGHT
  // ---------------------------------------------------------------

  /// ThemeData pour le mode light (clean diurne).
  static ThemeData get light => _build(
        brightness: Brightness.light,
        surface: TSurfaceColors.light,
      );

  // ---------------------------------------------------------------
  // CONSTRUCTEUR COMMUN
  // ---------------------------------------------------------------
  // Une seule fonction qui prend les differences (brightness +
  // surface) pour produire un ThemeData. Evite la duplication
  // entre dark et light.
  // ---------------------------------------------------------------

  /// Construit un ThemeData a partir d'une [brightness] et d'une
  /// palette [surface].
  static ThemeData _build({
    required Brightness brightness,
    required TSurfaceColors surface,
  }) {
    // --- ColorScheme (standard Material 3) ---
    // Base sur notre brand orange. Material derive les nuances
    // automatiquement, mais on override les cles importantes pour
    // rester coherent avec les couleurs TRIALGO.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: TColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: TColors.primary,
      onPrimary: surface.textOnBrand,
      secondary: TColors.primaryVariant,
      onSecondary: TColors.black,
      error: TColors.error,
      onError: surface.textOnBrand,
      surface: surface.bgRaised,
      onSurface: surface.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface.bgBase,

      // --- Typographie par defaut (utilisee par tous les widgets Material) ---
      // Le TextTheme est construit avec la couleur primaire du theme
      // pour que "Text('hello')" sans style explicite soit deja lisible.
      textTheme: TTypography.textThemeFor(defaultColor: surface.textPrimary),

      // --- AppBar ---
      appBarTheme: AppBarTheme(
        backgroundColor: surface.bgRaised,
        foregroundColor: surface.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TTypography.headlineMd(color: surface.textPrimary),
      ),

      // --- Cartes Material (rare usage, on prefere AppCard) ---
      cardTheme: CardThemeData(
        color: surface.bgRaised,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: TRadius.lgAll),
      ),

      // --- Boutons Material (garde-fou : on prefere AppButton) ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TColors.primary,
          foregroundColor: surface.textOnBrand,
          shape: const RoundedRectangleBorder(borderRadius: TRadius.lgAll),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TTypography.titleLg(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: surface.textPrimary,
          side: BorderSide(color: surface.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: TRadius.lgAll),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // --- SnackBar ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface.bgRaised,
        contentTextStyle: TTypography.bodyMd(color: surface.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: TRadius.mdAll),
      ),

      // --- Dialog ---
      dialogTheme: DialogThemeData(
        backgroundColor: surface.bgRaised,
        shape: const RoundedRectangleBorder(borderRadius: TRadius.xxlAll),
        titleTextStyle: TTypography.headlineMd(color: surface.textPrimary),
        contentTextStyle: TTypography.bodyMd(color: surface.textSecondary),
      ),

      // --- Extensions custom (nos tokens de surfaces) ---
      // C'est ce qui permet TColors.of(context).bgBase partout.
      extensions: [surface],
    );
  }
}


// =============================================================
// ENUM : TThemeMode
// =============================================================
// Ajout d'un enum pour typer proprement la preference de l'utilisateur.
// M3 a deja ThemeMode (light/dark/system), on reutilise simplement.
// =============================================================

/// Alias de l'enum Material ThemeMode pour nommage TRIALGO coherent.
///
/// Material fournit :
///   - ThemeMode.light  : force le mode clair
///   - ThemeMode.dark   : force le mode sombre
///   - ThemeMode.system : suit le reglage OS
///
/// L'utilisateur choisit l'un des 3 via les settings. Le defaut est
/// "system" pour respecter la preference initiale du telephone.
typedef TThemeMode = ThemeMode;
