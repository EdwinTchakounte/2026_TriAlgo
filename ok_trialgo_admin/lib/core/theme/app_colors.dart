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
// LA PALETTE VIENT DU LOGO, PAS D'UN CHOIX LIBRE
// ----------------------------------------------
// Le studio, la vitrine et l'app joueur sont le meme produit. Ils
// portaient pourtant trois identites differentes : un anthracite
// neutre et un orange rouge ici, un bleu nuit et un cyan sur
// mixalgo.com. Un administrateur passant de l'un a l'autre
// changeait visiblement de marque.
//
// Les valeurs ci-dessous sont donc celles de la vitrine, qui les
// echantillonne dans le logo : l'ambre du mot « Mix », le cyan
// dominant du diamant, et le bleu nuit du fond.
// =============================================================

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // pas d'instance

  // -----------------------------------------------------------
  // MARQUE
  // -----------------------------------------------------------
  // Ambre du logo, celui du mot « Mix » : couleur primaire,
  // utilisee pour les CTA, les anneaux de selection et le splash.
  // Elle remplace l'orange rouge #FF6B35, qui n'existait nulle
  // part dans l'identite du produit.
  static const Color brand = Color(0xFFF0A800);
  // Variante sombre pour les etats "pressed" / hover.
  static const Color brandDark = Color(0xFFC88C00);
  // Variante claire pour les fonds et highlights subtils.
  static const Color brandLight = Color(0xFFFFC93C);

  // Le cyan du diamant. Il etait ABSENT de l'app alors qu'il est
  // la teinte dominante du logo apres le blanc. Il sert ici de
  // second accent : liens, etats informatifs, mise en evidence --
  // partout ou l'ambre, reservee a l'action, serait de trop.
  static const Color accent = Color(0xFF00D8F0);
  static const Color accentSoft = Color(0xFF7FE9F7);

  // -----------------------------------------------------------
  // SURFACES NEUTRES  —  THEME SOMBRE "STUDIO"
  // -----------------------------------------------------------
  // On empile 3 niveaux de gris anthracite pour creer de la
  // profondeur sans ombres lourdes :
  //   background  = canvas le plus sombre (Scaffold)
  //   surface     = cards / panneaux poses sur le canvas
  //   surface2    = elements imbriques (inputs, sheets, chips)
  // Plus on "monte" dans la hierarchie, plus la surface est claire.
  // Les trois niveaux sont ceux de la vitrine : --nuit, --voile,
  // --voile-clair. Le gris anthracite neutre d'avant ne venait
  // d'aucune des couleurs du produit.
  static const Color background = Color(0xFF06041A); // canvas, nuit
  static const Color surface = Color(0xFF0C0930); // cards / panneaux
  static const Color surface2 = Color(0xFF141046); // inputs / sheets
  // La vitrine dessine ses filets en cyan translucide. Flutter
  // n'ayant pas de couche de fusion ici, on pose le RESULTAT de
  // ce melange sur --voile : rgba(0,216,240,.16) donne #0A2A4F,
  // et la variante appuyee #075879.
  static const Color border = Color(0xFF0A2A4F);
  static const Color borderStrong = Color(0xFF075879);

  // -----------------------------------------------------------
  // TEXTE  (clair sur fond sombre)
  // -----------------------------------------------------------
  // Texte principal (titres, body) : presque blanc, jamais blanc
  // pur (#FFF fatigue l'oeil sur fond sombre).
  static const Color textPrimary = Color(0xFFEAF4FA);   // --craie
  // Texte secondaire (hint, captions) : le --brume de la vitrine.
  static const Color textSecondary = Color(0xFF96A2CC);
  // Texte sur fond ambre. PAS du blanc : blanc sur #FF6B35 ne
  // donnait que 2,84 pour 1, sous le seuil AA de 4,5 -- et c'etait
  // le bouton principal de tout le panneau. Ce brun tres sombre,
  // celui des boutons de la vitrine, monte a 9,27 pour 1.
  static const Color textOnBrand = Color(0xFF1A0F00);

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
