// =============================================================
// FICHIER : lib/core/design_system/tokens/motion.dart
// ROLE   : Durations et courbes d'animation standardisees
// COUCHE : Core > Design System > Tokens
// =============================================================
//
// POURQUOI CES TOKENS ?
// ---------------------
// Duolingo et Pokemon Go ont des animations tres coherentes :
// micro-interactions rapides (100-150ms), transitions d'ecran
// douces (300-400ms), celebrations marquantes (500-800ms avec
// courbe elastique).
//
// Sans tokens, chaque developpeur choisit 200ms, 250ms, 300ms
// "au feeling" et le produit perd sa signature animee.
//
// REGLE POUR ENFANTS :
// --------------------
// Les enfants percoivent mieux les feedbacks UN PEU plus longs
// que les adultes (visibilite, sentiment de "ca se passe"). On
// adopte donc des durees moderement longues (normal = 250ms).
// Cependant les reponses directes aux taps restent rapides
// (<=150ms) pour eviter la sensation de lag.
// =============================================================

import 'package:flutter/animation.dart';

/// Tokens de duree.
class TDuration {

  /// 0ms — instantane (toggles sans transition).
  static const Duration instant = Duration.zero;

  /// 100ms — micro-interaction (ripple, pression bouton).
  static const Duration fast = Duration(milliseconds: 100);

  /// 150ms — feedback tactile + visuel immediat.
  static const Duration quick = Duration(milliseconds: 150);

  /// 250ms — transition standard (entrees de widgets, toggles).
  static const Duration normal = Duration(milliseconds: 250);

  /// 400ms — transition marquee (ouverture sheets, navigation).
  static const Duration slow = Duration(milliseconds: 400);

  /// 600ms — celebration / hero (bandeau de victoire, entrees hero).
  static const Duration slower = Duration(milliseconds: 600);

  /// 1000ms — sequences orchestrees (splash, onboarding).
  static const Duration dramatic = Duration(milliseconds: 1000);
}

// =============================================================
// CURVES
// =============================================================
// Les curves definissent le RYTHME d'une animation (rapide au
// debut, rapide a la fin, rebond, etc.). Choisir la bonne courbe
// transforme une anime "technique" en anime "vivante".
//
// Duolingo privilegie easeOutBack (petit overshoot) pour entree
// de cartes/boutons. Pokemon Go utilise easeOutQuart pour des
// transitions fluides et professionnelles.
// =============================================================

/// Tokens de courbes d'animation.
class TCurve {

  /// Standard : accelere puis decelere doucement.
  /// Defaut pour la plupart des transitions generiques.
  static const Curve standard = Curves.easeOutCubic;

  /// Emphasize : depart rapide, arrivee tres douce.
  /// Parfait pour entrees de page ou de gros elements.
  static const Curve emphasize = Curves.easeOutQuart;

  /// Overshoot : petit depassement a l'arrivee (style Duolingo).
  /// Donne du caractere aux boutons et badges a l'apparition.
  static const Curve overshoot = Curves.easeOutBack;

  /// Elastic : rebond prononce (celebrations, feedback correct).
  /// A utiliser moderement (trop = immature).
  static const Curve elastic = Curves.elasticOut;

  /// Bounce : retombee style balle (celebration, etoile gagnee).
  static const Curve bounce = Curves.bounceOut;

  /// In-out symetrique : pour pulses et loops infinis.
  /// Evite l'effet "saccade" qui se voit en boucle.
  static const Curve easeInOut = Curves.easeInOut;

  /// Linear : sans acceleration (rotations infinies, progress lineaires).
  /// A eviter ailleurs (semble mecanique).
  static const Curve linear = Curves.linear;
}
