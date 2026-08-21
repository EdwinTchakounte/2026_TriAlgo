// =============================================================
// FICHIER : wizard_shell.dart
// ROLE    : Shell du wizard 4-etapes
// =============================================================
//
// Layout :
//   AppBar (titre du jeu + back)
//   StepIndicator (4 cercles avec progression)
//   <Step content> (un des 4 enfants)
//
// L'IndexedStack garde l'etat des enfants : si l'admin remplit
// le formulaire trios, navigue vers preview puis revient,
// le formulaire est intact. C'est le comportement attendu d'un
// wizard "bien guide".
//
// On lit selectedGameProvider en haut : si null (rare,
// theoriquement impossible si on arrive par games_hub_page),
// on affiche un fallback explicite.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/games_provider.dart';
import '../../providers/wizard_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/step_indicator.dart';
import 'step1_setup_page.dart';
import 'step2_cards_page.dart';
import 'step3_trios_page.dart';
import 'step4_preview_page.dart';

class WizardShell extends ConsumerWidget {
  const WizardShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(selectedGameProvider);
    final step = ref.watch(wizardProvider);

    // Garde-fou : si pas de game, on rebrousse chemin proprement.
    if (game == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(
          child: Text(
            'Aucun jeu selectionne. Retournez au hub.',
            style: AppTextStyles.body(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour au hub des jeux',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 4,
        // Logo compact + nom du jeu + libelle de l'etape.
        title: Row(
          children: [
            const AppLogo(size: AppLogoSize.compact, radius: 6),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    game.name,
                    style: AppTextStyles.pageTitle().copyWith(fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    step.longLabel,
                    style: AppTextStyles.caption(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------------------------------------------
            // BARRE DE PROGRESSION
            // ---------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: StepIndicator(current: step),
            ),

            // ---------------------------------------------------
            // CONTENU DE L'ETAPE (IndexedStack garde l'etat)
            // ---------------------------------------------------
            Expanded(
              child: IndexedStack(
                index: step.index,
                children: const [
                  Step1SetupPage(),
                  Step2CardsPage(),
                  Step3TriosPage(),
                  Step4PreviewPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
