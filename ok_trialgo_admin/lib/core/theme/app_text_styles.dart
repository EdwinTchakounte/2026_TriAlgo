// =============================================================
// FICHIER : app_text_styles.dart
// ROLE    : Styles de texte reutilisables (utilises hors ThemeData)
// =============================================================
//
// ThemeData expose deja un textTheme (titleLarge, bodyMedium...),
// mais on a besoin de styles "metier" hors de Material : ex le
// label "Etape 2/4" du wizard, le compteur "12 cartes" sur la
// page Cards. Les regrouper ici evite la duplication.
//
// Toutes les fontes utilisent Rajdhani (google_fonts) pour rester
// dans la meme famille typographique que le jeu principal.
// =============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // -----------------------------------------------------------
  // TITRE HERO (utilise sur le splash et les empty states)
  // -----------------------------------------------------------
  // Taille 32, weight w800, lettrage serre : casse "marque".
  static TextStyle hero() => GoogleFonts.rajdhani(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  // -----------------------------------------------------------
  // TITRE DE PAGE (en haut de chaque ecran)
  // -----------------------------------------------------------
  static TextStyle pageTitle() => GoogleFonts.rajdhani(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // -----------------------------------------------------------
  // TITRE DE SECTION (intra-page)
  // -----------------------------------------------------------
  static TextStyle sectionTitle() => GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // -----------------------------------------------------------
  // LABEL (formulaires, chips, badges)
  // -----------------------------------------------------------
  static TextStyle label() => GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // -----------------------------------------------------------
  // BODY (paragraphes, descriptions)
  // -----------------------------------------------------------
  static TextStyle body() => GoogleFonts.rajdhani(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // -----------------------------------------------------------
  // CAPTION (hints, helpers, metadata)
  // -----------------------------------------------------------
  static TextStyle caption() => GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  // -----------------------------------------------------------
  // BUTTON LABEL (CTA principal)
  // -----------------------------------------------------------
  // Taille 15, weight w700 : suffisamment marque pour etre lu
  // dans un ElevatedButton.
  static TextStyle button() => GoogleFonts.rajdhani(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      );

  // -----------------------------------------------------------
  // STEP LABEL (wizard : "Etape 2 / 4")
  // -----------------------------------------------------------
  static TextStyle stepLabel() => GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.brand,
        letterSpacing: 1.0,
      );
}
