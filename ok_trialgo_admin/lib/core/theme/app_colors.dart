// =============================================================
// FICHIER : app_colors.dart
// ROLE    : Palette de couleurs centralisee pour toute l'app
// =============================================================
//
// On regroupe toutes les couleurs ici pour deux raisons :
//   1. Coherence visuelle : impossible d'avoir 3 orange differents
//      qui se baladent dans l'app si on ne reference qu'une seule
//      constante "AppColors.orange".
//   2. Maintenance : si la marque change, on edite UN fichier.
//
// La couleur principale (orange) est celle du jeu TRIALGO. Le
// dashboard suit la meme charte pour rester identifiable comme
// "outil officiel du jeu".
// =============================================================

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // pas d'instance

  // -----------------------------------------------------------
  // MARQUE
  // -----------------------------------------------------------
  // Orange TRIALGO : couleur primaire, utilisee pour les CTA,
  // les ringings de selection et le splash screen. Sur fond
  // sombre elle "pop" naturellement (effet neon) ; on l'utilise
  // aussi pour les glows (BoxShadow teinte brand).
  static const Color brand = Color(0xFFFF6B35);
  // Variante sombre pour les etats "pressed" / hover.
  static const Color brandDark = Color(0xFFE85420);
  // Variante claire pour les fonds ou les highlights subtils.
  static const Color brandLight = Color(0xFFFFB199);

  // -----------------------------------------------------------
  // SURFACES NEUTRES  —  THEME SOMBRE "STUDIO"
  // -----------------------------------------------------------
  // On empile 3 niveaux de gris anthracite pour creer de la
  // profondeur sans ombres lourdes :
  //   background  = canvas le plus sombre (Scaffold)
  //   surface     = cards / panneaux poses sur le canvas
  //   surface2    = elements imbriques (inputs, sheets, chips)
  // Plus on "monte" dans la hierarchie, plus la surface est claire.
  static const Color background = Color(0xFF121419); // canvas anthracite
  static const Color surface = Color(0xFF1C1F26); // cards / panneaux
  static const Color surface2 = Color(0xFF252932); // inputs / sheets
  // Bordures fines : a peine plus claires que surface2, discretes.
  static const Color border = Color(0xFF323845);

  // -----------------------------------------------------------
  // TEXTE  (clair sur fond sombre)
  // -----------------------------------------------------------
  // Texte principal (titres, body) : presque blanc, jamais blanc
  // pur (#FFF fatigue l'oeil sur fond sombre).
  static const Color textPrimary = Color(0xFFF3F5F9);
  // Texte secondaire (hint, captions) : gris bleute moyen.
  static const Color textSecondary = Color(0xFF9AA1AE);
  // Texte sur fond colore (brand) : reste blanc pur (contraste).
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // -----------------------------------------------------------
  // SEMANTIQUE (status)
  // -----------------------------------------------------------
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // -----------------------------------------------------------
  // TYPE DE CARTE (visualisation rapide)
  // -----------------------------------------------------------
  // Trois couleurs distinctes pour reperer en un coup d'oeil
  // le role d'une carte dans un trio.
  static const Color cardEmettrice = Color(0xFF42A5F5); // bleu
  static const Color cardCable = Color(0xFFAB47BC); // violet
  static const Color cardReceptrice = Color(0xFF66BB6A); // vert

  // -----------------------------------------------------------
  // PROFONDEUR DU NODE (D1 a D5)
  // -----------------------------------------------------------
  // Chaque profondeur a sa propre teinte pour la preview de
  // l'arbre. Du plus vif (D1, racine) au plus tamise (D5, feuille).
  static Color depth(int d) {
    switch (d) {
      case 1:
        return const Color(0xFFE53935); // rouge vif
      case 2:
        return const Color(0xFFFB8C00); // orange
      case 3:
        return const Color(0xFFFDD835); // jaune
      case 4:
        return const Color(0xFF43A047); // vert
      case 5:
        return const Color(0xFF1E88E5); // bleu
      default:
        return const Color(0xFF6B7280); // gris neutre
    }
  }

  // -----------------------------------------------------------
  // GLOW  (halo colore facon "neon", signature du theme studio)
  // -----------------------------------------------------------
  // Retourne une liste de BoxShadow a passer a un BoxDecoration.
  // Deux couches : une diffuse (large, tres douce) + une proche
  // (serree, plus dense) pour un halo credible sur fond sombre.
  static List<BoxShadow> glow(Color color, {double strength = 1.0}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.28 * strength),
        blurRadius: 24 * strength,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.18 * strength),
        blurRadius: 8 * strength,
      ),
    ];
  }
}
