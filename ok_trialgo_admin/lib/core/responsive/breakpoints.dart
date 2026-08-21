// =============================================================
// FICHIER : breakpoints.dart
// ROLE    : Definir les seuils de tailles d'ecran
// =============================================================
//
// "Responsive" sur mobile Flutter ne signifie pas seulement
// "fluide entre 320 et 480 px". Une tablette 10" peut faire plus
// de 1000 px en orientation paysage. Sans breakpoints, le contenu
// devient soit gigantesque (textes etires), soit comique (grilles
// a 7 colonnes par exemple). On definit ici 3 paliers :
//
//   compact (< 600)     : telephone portrait, marges serrees
//   medium  (600-900)   : telephone paysage / petite tablette
//   expanded (>= 900)   : tablette paysage, layout en 2 colonnes
//
// Material 3 propose la meme classification (Compact / Medium /
// Expanded), donc on s'aligne dessus.
// =============================================================

import 'package:flutter/material.dart';

enum DeviceSize { compact, medium, expanded }

class Breakpoints {
  Breakpoints._();

  // Seuils en pixels logiques (independants du device pixel ratio).
  static const double compactMax = 600;
  static const double mediumMax = 900;

  // Renvoie le DeviceSize en fonction de la largeur courante du
  // contexte. Pratique : on l'appelle dans LayoutBuilder ou
  // build() pour adapter colonnes / paddings / typo.
  static DeviceSize of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactMax) return DeviceSize.compact;
    if (width < mediumMax) return DeviceSize.medium;
    return DeviceSize.expanded;
  }

  // Nombre de colonnes recommande pour les grilles de cartes.
  // - compact  : 2 colonnes (lisibilite sur telephone)
  // - medium   : 3 colonnes
  // - expanded : 4 colonnes (tablette)
  static int gridColumns(BuildContext context) {
    switch (of(context)) {
      case DeviceSize.compact:
        return 2;
      case DeviceSize.medium:
        return 3;
      case DeviceSize.expanded:
        return 4;
    }
  }

  // Padding horizontal recommande pour les pages.
  // Plus l'ecran est large, plus on aere les bords (sinon le
  // contenu serait colle aux bords sur tablette).
  static double horizontalPadding(BuildContext context) {
    switch (of(context)) {
      case DeviceSize.compact:
        return 16;
      case DeviceSize.medium:
        return 24;
      case DeviceSize.expanded:
        return 32;
    }
  }

  // Largeur maximale du contenu central. Sur tablette paysage,
  // on ne veut pas etirer un formulaire sur 1200 px : on le
  // contraint a 720 px max et on centre.
  static double maxContentWidth(BuildContext context) {
    return 720;
  }
}
