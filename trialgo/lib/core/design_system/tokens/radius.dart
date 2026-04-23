// =============================================================
// FICHIER : lib/core/design_system/tokens/radius.dart
// ROLE   : Rayons de coins standardises
// COUCHE : Core > Design System > Tokens
// =============================================================
//
// POURQUOI STANDARDISER LES RADIUS ?
// -----------------------------------
// Actuellement le code utilise circular(8), (10), (14), (18),
// (22), (24) selon les fichiers. Meme logique que pour l'espacement :
// on perd la coherence visuelle a mesure que les variations
// s'accumulent.
//
// Une echelle controlee donne une signature "formes arrondies" plus
// reconnaissable et plus pro.
//
// PHILOSOPHIE ENFANT + CARD GAME :
// --------------------------------
// Les rayons grands (>16) evoquent la douceur, parfait pour des UI
// enfants (moins aggressif). On privilegie "lg" et "xl" comme
// radius par defaut, "full" pour les chips et badges.
// =============================================================

import 'package:flutter/widgets.dart';

/// Tokens de rayons de coins (arrondis).
class TRadius {

  // ---------------------------------------------------------------
  // VALEURS NUMERIQUES (double)
  // ---------------------------------------------------------------

  /// 0pt — coins pointus (rare, utile pour separateurs pleins).
  static const double none = 0;

  /// 4pt — subtil (tags etroits, mini-badges).
  static const double xs = 4;

  /// 8pt — petit arrondi (inputs compacts).
  static const double sm = 8;

  /// 12pt — arrondi moyen (cartes interieures).
  static const double md = 12;

  /// 16pt — arrondi standard (boutons, cartes principales).
  static const double lg = 16;

  /// 20pt — arrondi doux (cartes hero, dialogs).
  static const double xl = 20;

  /// 24pt — arrondi prononce (sheets, modals).
  static const double xxl = 24;

  /// 999 — pleinement circulaire (chips, avatars, FABs circulaires).
  /// Grande valeur plutot que infinity pour compatibilite universelle.
  static const double full = 999;

  // ---------------------------------------------------------------
  // BORDER RADIUS PRE-CONSTRUITS (BorderRadius)
  // ---------------------------------------------------------------
  // Raccourcis pour eviter `BorderRadius.circular(TRadius.lg)` repete.
  // const + static = instances uniques en memoire, gratuit a utiliser.
  // ---------------------------------------------------------------

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
}
