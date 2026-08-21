// =============================================================
// FICHIER : theme.dart
// ROLE    : Definir le theme visuel du dashboard
// =============================================================
//
// On reutilise la palette du jeu TRIALGO (orange #FF6B35) pour
// la coherence visuelle, mais avec une UI plus "outils admin"
// (densite plus haute, focus sur les listes et les formulaires).
//
// Design system minimaliste :
//   - couleurs definies en constantes typees (pas de magic numbers)
//   - typo via google_fonts (Rajdhani comme l'app principale)
//   - rayon arrondi unique (12) pour les cartes
//   - elevation discrete (1-2) pour ne pas distraire l'admin
// =============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TBrand {
  // Couleur signature TRIALGO (orange "energie").
  // Utilisee sur les CTA primaires et accents.
  static const Color orange = Color(0xFFFF6B35);

  // Variante plus chaude pour gradients / hovers.
  static const Color orangeDeep = Color(0xFFEC4F1A);

  // Couleurs par profondeur du graphe (D1 -> D5). Memes valeurs
  // que dans l'app jeu pour que la lecture visuelle soit
  // identique entre dashboard et terrain.
  static const Color d1 = Color(0xFFFFB74D); // D1 = chaud
  static const Color d2 = Color(0xFFAED581); // D2 = vert clair
  static const Color d3 = Color(0xFF9575CD); // D3 = violet
  static const Color d4 = Color(0xFFFF8F87); // D4 = corail
  static const Color d5 = Color(0xFF7AB6FF); // D5 = bleu legendaire

  // Helper : recupere la couleur de zone pour une profondeur k.
  // Utilise dans la vue graphe et la liste des nodes.
  static Color depthColor(int depth) {
    switch (depth) {
      case 1:
        return d1;
      case 2:
        return d2;
      case 3:
        return d3;
      case 4:
        return d4;
      case 5:
        return d5;
      default:
        return Colors.grey;
    }
  }
}

// =============================================================
// THEME LIGHT (mode clair) — par defaut sur le dashboard
// =============================================================
// Le dashboard est utilise en bureau / desktop : le mode clair
// est plus lisible pour les longues sessions de saisie.
// =============================================================
ThemeData buildTheme() {
  // ColorScheme.fromSeed propage automatiquement la couleur de
  // marque sur primary/secondary/surfaceTint/etc. Material 3.
  final scheme = ColorScheme.fromSeed(
    seedColor: TBrand.orange,
    brightness: Brightness.light,
  );

  // Typo : Rajdhani (sci-fi/gaming) pour rester coherent avec
  // l'app jeu. textTheme charge la police pour TOUS les TextStyle.
  final textTheme = GoogleFonts.rajdhaniTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),

    // AppBar plate (pas d'ombre) pour un look outil moderne.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),

    // Cards : rayon 12 partout, ombre legere.
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    // CTAs primaires : couleur de marque, hauteur confortable.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TBrand.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // Inputs : bordures discretes, focus orange.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: TBrand.orange, width: 2),
      ),
    ),

    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}
