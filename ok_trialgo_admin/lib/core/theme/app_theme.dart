// =============================================================
// FICHIER : app_theme.dart
// ROLE    : Construire le ThemeData global de l'app
// =============================================================
//
// Flutter centralise le theme dans MaterialApp(theme: ...). En
// definissant ici un buildAppTheme() qui agrege couleurs, typos
// et formes par defaut, on garantit qu'un nouvel ecran herite
// AUTOMATIQUEMENT du style cible, sans avoir a re-specifier
// font/color/elevation a chaque widget.
//
// Choix forts (theme "studio sombre") :
// - useMaterial3 = TRUE       : design language a jour
// - brightness   = DARK       : canvas anthracite, contenu clair
// - colorScheme.fromSeed      : palette deduite du seed (brand)
//   pour la coherence des nuances (primaryContainer, etc.)
// - input filled + radius 12  : look "moderne" doux
// - elevatedButton height 48  : tactile confortable
// =============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

ThemeData buildAppTheme() {
  // Generation de la palette Material a partir du brand, en mode
  // SOMBRE. fromSeed calcule les nuances (primaryContainer...) ;
  // on force ensuite surface/onSurface pour coller a notre charte
  // anthracite plutot qu'aux defauts Material.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.dark,
    primary: AppColors.brand,
    onPrimary: AppColors.textOnBrand,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,

    // Police globale = Rajdhani (textTheme entier rebati), en clair.
    textTheme: GoogleFonts.rajdhaniTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),

    // ---------------------------------------------------------
    // AppBar : se fond dans le canvas (pas de barre claire)
    // ---------------------------------------------------------
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTextStyles.sectionTitle(),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),

    // ---------------------------------------------------------
    // Card : radius 16, bordure douce, fond surface
    // ---------------------------------------------------------
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.zero,
    ),

    // ---------------------------------------------------------
    // Inputs : filled, radius 12, focus orange
    // ---------------------------------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface2,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: AppTextStyles.caption(),
      labelStyle: AppTextStyles.label(),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),

    // ---------------------------------------------------------
    // Boutons primaires (ElevatedButton)
    // ---------------------------------------------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.textOnBrand,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        textStyle: AppTextStyles.button(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // ---------------------------------------------------------
    // Boutons secondaires (OutlinedButton)
    // ---------------------------------------------------------
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        foregroundColor: AppColors.textPrimary,
        textStyle: AppTextStyles.button(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // ---------------------------------------------------------
    // Boutons tertiaires (TextButton, ex: liens, "Annuler")
    // ---------------------------------------------------------
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        textStyle: AppTextStyles.button(),
      ),
    ),

    // ---------------------------------------------------------
    // SnackBar : flottant, surface elevee claire-sombre
    // ---------------------------------------------------------
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface2,
      contentTextStyle: GoogleFonts.rajdhani(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),

    // ---------------------------------------------------------
    // BottomSheet / Dialog : surface elevee + radius
    // ---------------------------------------------------------
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: AppColors.surface,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),

    // ---------------------------------------------------------
    // Dividers fins
    // ---------------------------------------------------------
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
  );
}
