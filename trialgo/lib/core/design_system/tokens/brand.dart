// =============================================================
// FICHIER : lib/core/design_system/tokens/brand.dart
// ROLE   : Gradients et effets signature de TRIALGO
// COUCHE : Core > Design System > Tokens
// =============================================================
//
// POURQUOI UN FICHIER SEPARE ?
// ----------------------------
// Les gradients font partie de l'identite visuelle forte de
// TRIALGO (bouton primary = orange -> dore). Les isoler :
//   - Permet de les modifier sans toucher aux couleurs scalar
//   - Les rend decouvrables (autocompletion "TBrand.*")
//   - Evite la tentation de les redefinir localement
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/core/design_system/tokens/colors.dart';

/// Gradients et effets signature de TRIALGO.
class TBrand {

  // ---------------------------------------------------------------
  // GRADIENTS BOUTONS / ACCENTS
  // ---------------------------------------------------------------

  /// Gradient principal : orange -> dore.
  /// Utilise sur les boutons primaires, les hero CTA, les badges.
  static const LinearGradient primary = LinearGradient(
    colors: [TColors.primary, TColors.primaryVariant],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient success : vert foncé -> vert clair.
  /// Pour les bannières de victoire et de validation.
  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFF81D884)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient error : rouge plus fonce -> rouge clair.
  /// Evite un rouge totalement sature qui heurte les yeux.
  static const LinearGradient error = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFEF5350)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------------------------------------------------------------
  // GRADIENTS FOND DE PAGE
  // ---------------------------------------------------------------
  // Utilises par PageScaffold selon le theme actif.
  //
  // En dark : reprise du gradient actuel (profondeur spatiale).
  // En light : camaieu tres doux pour garder du relief sans heurter.
  // ---------------------------------------------------------------

  /// Gradient fond de page en mode dark (violet/bleu profond).
  ///
  /// Reprend les 3 niveaux de fond dark de TSurfaceColors pour
  /// garder une source unique de verite. Si on change la palette
  /// dark, le gradient suit automatiquement.
  static const LinearGradient bgDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      TSurfaceColors.darkBgBase,
      TSurfaceColors.darkBgRaised,
      TSurfaceColors.darkBgSunken,
    ],
  );

  /// Gradient fond de page en mode light (creme/lavande tres pale).
  ///
  /// Reste doux pour preserver la lisibilite des cartes blanches
  /// qui se poseront dessus. Inspire des UI Duolingo diurnes.
  static const LinearGradient bgLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      TSurfaceColors.lightBgBase,
      TSurfaceColors.lightBgRaised,
      TSurfaceColors.lightBgSunken,
    ],
  );
}
