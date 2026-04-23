// =============================================================
// FICHIER : lib/core/design_system/tokens/typography.dart
// ROLE   : Type scale standardisee (display/headline/title/body/label)
// COUCHE : Core > Design System > Tokens
// =============================================================
//
// STRUCTURE DU TYPE SCALE :
// -------------------------
// Inspire de Material 3 avec 5 categories, chacune en 3 tailles :
//   DISPLAY   : titres hero immenses (splash, celebration)
//   HEADLINE  : titres de section
//   TITLE     : titres de composants (card title, button)
//   BODY      : contenu courant (paragraphes, descriptions)
//   LABEL     : meta-donnees (form labels, chips, badges)
//
// Chaque categorie en large/medium/small pour permettre une
// hierarchie fine sans inventer de tailles custom.
//
// POLICES :
// ---------
// - DISPLAY, HEADLINE, TITLE : Rajdhani (800/900) -> gaming/sci-fi
// - BODY, LABEL              : Exo 2 (400/500/600) -> lisibilite
//
// LISIBILITE ENFANT (6-12 ans) :
// -------------------------------
// Body minimum 14pt. Labels minimum 12pt. Pas en dessous.
// line-height (height) 1.4-1.5 sur le body pour respirer.
// Poids minimum 500 sur le body pour garder du corps (les
// polices fines fatiguent en lecture prolongee).
// =============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type scale TRIALGO (Material 3 + gaming).
class TTypography {

  // ---------------------------------------------------------------
  // DISPLAY : pour les titres hero (rares, impactants)
  // ---------------------------------------------------------------

  /// 48pt Rajdhani 900 — splash, celebration majeure.
  static TextStyle displayLg({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        height: 1.1,
        color: color,
      );

  /// 36pt Rajdhani 900 — hero de page, resultat de partie.
  static TextStyle displayMd({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        height: 1.15,
        color: color,
      );

  /// 28pt Rajdhani 800 — titre de page principal.
  static TextStyle displaySm({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
        height: 1.2,
        color: color,
      );

  // ---------------------------------------------------------------
  // HEADLINE : titres de section dans une page
  // ---------------------------------------------------------------

  /// 24pt Rajdhani 800 — titre de section majeure.
  static TextStyle headlineLg({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        height: 1.25,
        color: color,
      );

  /// 20pt Rajdhani 700 — titre de section standard.
  static TextStyle headlineMd({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        height: 1.3,
        color: color,
      );

  /// 18pt Rajdhani 700 — titre de section mineure.
  static TextStyle headlineSm({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.35,
        color: color,
      );

  // ---------------------------------------------------------------
  // TITLE : titres de composants (cards, dialogs, buttons)
  // ---------------------------------------------------------------

  /// 16pt Rajdhani 700 — titre de carte, texte de bouton primaire.
  static TextStyle titleLg({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        height: 1.4,
        color: color,
      );

  /// 14pt Rajdhani 700 — titre secondaire, bouton standard.
  static TextStyle titleMd({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        height: 1.4,
        color: color,
      );

  /// 12pt Rajdhani 700 (UPPERCASE par convention) — overline de section.
  /// A utiliser typiquement en majuscules + letterSpacing large.
  static TextStyle titleSm({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        height: 1.4,
        color: color,
      );

  // ---------------------------------------------------------------
  // BODY : contenu courant
  // ---------------------------------------------------------------

  /// 16pt Exo 2 500 — paragraphes principaux (accueil, descriptions).
  static TextStyle bodyLg({Color? color}) => GoogleFonts.exo2(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: color,
      );

  /// 14pt Exo 2 500 — body standard de l'application.
  static TextStyle bodyMd({Color? color}) => GoogleFonts.exo2(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: color,
      );

  /// 13pt Exo 2 500 — hints, captions, texte secondaire.
  static TextStyle bodySm({Color? color}) => GoogleFonts.exo2(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );

  // ---------------------------------------------------------------
  // LABEL : meta-donnees, chips, form labels
  // ---------------------------------------------------------------

  /// 14pt Exo 2 600 — labels de formulaire, tags visibles.
  static TextStyle labelLg({Color? color}) => GoogleFonts.exo2(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.4,
        color: color,
      );

  /// 12pt Exo 2 600 — chips, badges, metadata.
  static TextStyle labelMd({Color? color}) => GoogleFonts.exo2(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.4,
        color: color,
      );

  /// 10pt Exo 2 700 (UPPERCASE par convention) — microcopy, cues.
  /// Exemple : "NIVEAU", "SCORE", "DERNIER".
  static TextStyle labelSm({Color? color}) => GoogleFonts.exo2(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        height: 1.3,
        color: color,
      );

  // ---------------------------------------------------------------
  // NUMERIC : tokens dedies a l'affichage de chiffres
  // ---------------------------------------------------------------
  // Pour scores, timers, compteurs : on utilise tabularFigures
  // pour que les chiffres aient tous la meme largeur (evite les
  // "sauts" quand un 1 devient un 0).
  //
  // Rajdhani est deja tabulaire par defaut, mais on force au cas ou
  // une variante numerique serait utilisee.
  // ---------------------------------------------------------------

  /// 32pt Rajdhani 900 tabulaire — gros score.
  static TextStyle numericLg({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  /// 18pt Rajdhani 800 tabulaire — compteur standard.
  static TextStyle numericMd({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  /// 12pt Rajdhani 700 tabulaire — chiffre discret (ex: timer vies).
  static TextStyle numericSm({Color? color}) => GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      );

  // ---------------------------------------------------------------
  // MATERIAL TEXT THEME : pour MaterialApp/Theme
  // ---------------------------------------------------------------
  // Compose un TextTheme complet Material 3 a partir de nos styles.
  // Utilise par app_theme.dart pour que les widgets Material par
  // defaut (AppBar, TabBar, etc.) adoptent nos typos sans override.
  // ---------------------------------------------------------------

  /// Construit le TextTheme Material a partir du scale TRIALGO.
  static TextTheme textThemeFor({required Color defaultColor}) {
    return TextTheme(
      displayLarge:   displayLg(color: defaultColor),
      displayMedium:  displayMd(color: defaultColor),
      displaySmall:   displaySm(color: defaultColor),
      headlineLarge:  headlineLg(color: defaultColor),
      headlineMedium: headlineMd(color: defaultColor),
      headlineSmall:  headlineSm(color: defaultColor),
      titleLarge:     titleLg(color: defaultColor),
      titleMedium:    titleMd(color: defaultColor),
      titleSmall:     titleSm(color: defaultColor),
      bodyLarge:      bodyLg(color: defaultColor),
      bodyMedium:     bodyMd(color: defaultColor),
      bodySmall:      bodySm(color: defaultColor),
      labelLarge:     labelLg(color: defaultColor),
      labelMedium:    labelMd(color: defaultColor),
      labelSmall:     labelSm(color: defaultColor),
    );
  }
}
