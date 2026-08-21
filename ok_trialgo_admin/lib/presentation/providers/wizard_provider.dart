// =============================================================
// FICHIER : wizard_provider.dart
// ROLE    : Avancement du wizard 4-etapes
// =============================================================
//
// Le wizard est ce qui rend l'app "bien guidee" : l'admin n'est
// jamais perdu, il sait toujours quelle est l'etape courante,
// ce qu'il vient de finir et ce qui reste a faire.
//
// Etapes :
//   1. setup    : intro + selection/creation du game
//   2. cards    : ajouter au moins 1 emettrice + 1 cable + 1 receptrice
//   3. trios    : composer des relations entre cartes
//   4. preview  : visualiser l'arbre final
//
// Le provider memorise simplement l'index courant (0..3).
// La navigation (forward / back) est faite par les pages elles-
// memes via les boutons "Suivant" / "Precedent".
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum WizardStep { setup, cards, trios, preview }

extension WizardStepX on WizardStep {
  int get index => WizardStep.values.indexOf(this);
  // Label court pour le step indicator.
  String get shortLabel {
    switch (this) {
      case WizardStep.setup:
        return 'Jeu';
      case WizardStep.cards:
        return 'Cartes';
      case WizardStep.trios:
        return 'Fusions';
      case WizardStep.preview:
        return 'Arbre';
    }
  }

  // Label long pour le titre de page.
  String get longLabel {
    switch (this) {
      case WizardStep.setup:
        return 'Configuration du jeu';
      case WizardStep.cards:
        return 'Bibliotheque de cartes';
      case WizardStep.trios:
        return 'Composer les fusions';
      case WizardStep.preview:
        return 'Apercu de l\'arbre';
    }
  }
}

class WizardController extends Notifier<WizardStep> {
  @override
  WizardStep build() => WizardStep.setup;

  void goTo(WizardStep step) => state = step;

  void next() {
    final values = WizardStep.values;
    final i = values.indexOf(state);
    if (i < values.length - 1) state = values[i + 1];
  }

  void back() {
    final values = WizardStep.values;
    final i = values.indexOf(state);
    if (i > 0) state = values[i - 1];
  }

  // Au moment ou on quitte le wizard (retour au hub), on remet
  // a setup pour que la prochaine entree reprenne au debut.
  void reset() => state = WizardStep.setup;
}

final wizardProvider =
    NotifierProvider<WizardController, WizardStep>(WizardController.new);
