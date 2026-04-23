// =============================================================
// FICHIER : lib/core/design_system/tokens/elevation.dart
// ROLE   : Niveaux d'elevation (ombres) standardisees
// COUCHE : Core > Design System > Tokens
// =============================================================
//
// POURQUOI DES TOKENS D'ELEVATION ?
// ---------------------------------
// Les ombres communiquent la hierarchie des surfaces : quelle
// couche est "au-dessus" de quelle autre. Material 3 definit
// 6 niveaux (0-5), chaque niveau avec une recette d'ombres
// bien calibree (spread, blur, offset).
//
// Avoir des tokens pre-calcules evite que chaque developpeur
// "bidouille" ses propres blurs et crée des incoherences.
//
// CHILD + GAMING SPECIFICITE :
// -----------------------------
// Pour un jeu enfant style Pokemon Go/Duolingo, on privilegie :
//   - Ombres DOUCES (blur large, offset Y moderee)
//   - Ombres COLOREES sur les boutons primaires (glow orange)
//     plutot qu'une ombre noire banale
//   - Pas d'ombres agressives (noir 50% opacity) qui sentent le
//     "generateur de code brut"
// =============================================================

import 'package:flutter/widgets.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';

/// Tokens d'ombres (elevation M3-like, adaptes gaming).
class TElevation {

  // ---------------------------------------------------------------
  // LEVEL 0 — AUCUNE ELEVATION
  // ---------------------------------------------------------------
  // Surface au ras du fond. Aucune ombre. Utilise pour elements
  // inline qui n'ont pas besoin de se distinguer.
  // ---------------------------------------------------------------

  /// Aucune ombre.
  static const List<BoxShadow> none = [];

  // ---------------------------------------------------------------
  // LEVEL 1 — SUBTILE
  // ---------------------------------------------------------------
  // Pour cartes et panneaux qui se detachent legerement du fond.
  // Ombre tres douce, a peine visible, juste un "detail" de relief.
  // ---------------------------------------------------------------

  /// Ombre subtile (cartes simples, inputs).
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x14000000), // noir 8% opacity
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // ---------------------------------------------------------------
  // LEVEL 2 — MOYENNE
  // ---------------------------------------------------------------
  // Pour cartes qui doivent clairement se distinguer, buttons
  // secondaires. Double ombre (large + serree) pour plus de realisme.
  // ---------------------------------------------------------------

  /// Ombre moyenne (cartes principales, modals discrets).
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x1F000000), // 12%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4% pour l'edge sharpness
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  // ---------------------------------------------------------------
  // LEVEL 3 — HAUTE
  // ---------------------------------------------------------------
  // Modals, bottom sheets, menus flottants. Forte separation du fond.
  // ---------------------------------------------------------------

  /// Ombre haute (dialogs, sheets, popovers).
  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color(0x29000000), // 16%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0F000000), // 6%
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  // ---------------------------------------------------------------
  // LEVEL 4 — MAXIMALE
  // ---------------------------------------------------------------
  // Usage rare : elements "flottants" au-dessus de TOUT.
  // Ex: tooltip important, snackbar de victoire.
  // ---------------------------------------------------------------

  /// Ombre tres haute (rarement utilisee).
  static const List<BoxShadow> max = [
    BoxShadow(
      color: Color(0x33000000), // 20%
      blurRadius: 40,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x14000000), // 8%
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  // ---------------------------------------------------------------
  // GLOWS COLOREES (specificite gaming)
  // ---------------------------------------------------------------
  // Utilisees sur les boutons primaires, les cartes de score, les
  // elements qui "illuminent" visuellement. C'est la signature
  // premium Hearthstone/Marvel Snap / Pokemon Go.
  //
  // Ne pas les empiler avec une ombre noire : elles remplacent l'ombre.
  // ---------------------------------------------------------------

  /// Glow orange (bouton primaire, actions importantes).
  static const List<BoxShadow> glowPrimary = [
    BoxShadow(
      color: TColors.primaryGlow,
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  /// Glow dore (bonus, score, celebration).
  static const List<BoxShadow> glowGold = [
    BoxShadow(
      color: TColors.goldGlow,
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  /// Glow vert (succes, validation).
  static const List<BoxShadow> glowSuccess = [
    BoxShadow(
      color: TColors.successGlow,
      blurRadius: 18,
      offset: Offset(0, 4),
    ),
  ];

  /// Glow rouge (erreur, alerte).
  static const List<BoxShadow> glowError = [
    BoxShadow(
      color: TColors.errorGlow,
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}
