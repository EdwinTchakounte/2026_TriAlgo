// =============================================================
// FICHIER : wizard_nav.dart
// ROLE    : Barre de navigation bas-de-page du wizard
// =============================================================
//
// Composant partage par toutes les etapes qui ont besoin de
// "retour + continuer" en bas (steps 2, 3, 4).
//
// Comportement :
//   - Si canContinue = false : le CTA est grise, et le
//     missingHint (s'il est fourni) est affiche en banner
//     warning au-dessus.
//   - SafeArea protege du gesture bar Android / home indicator iOS.
// =============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class WizardNav extends StatelessWidget {
  // Si false, le CTA principal est disabled (et le hint apparait).
  final bool canContinue;
  // Texte du CTA principal. Ex : "Continuer : composer des trios".
  final String continueLabel;
  // Hint affiche quand canContinue = false. null sinon = pas de hint.
  final String? missingHint;
  // Callback "Retour" et "Continuer".
  final VoidCallback onBack;
  final VoidCallback onNext;
  // Icone du bouton next. Par defaut fleche droite.
  final IconData nextIcon;

  const WizardNav({
    super.key,
    required this.canContinue,
    required this.continueLabel,
    required this.onBack,
    required this.onNext,
    this.missingHint,
    this.nextIcon = Icons.arrow_forward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        // Trait fin en haut pour separer du contenu scrollable.
        border: const Border(top: BorderSide(color: AppColors.border)),
        // Ombre legere vers le haut : suggere que c'est une barre
        // "ancree" qui se distingue du body au-dessus.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (missingHint != null) ...[
              _HintBanner(message: missingHint!),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Retour'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: canContinue ? onNext : null,
                    icon: Icon(nextIcon, size: 18),
                    label: Text(
                      continueLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _HintBanner : banner warning quand on ne peut pas continuer
// =============================================================
class _HintBanner extends StatelessWidget {
  final String message;
  const _HintBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption().copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
