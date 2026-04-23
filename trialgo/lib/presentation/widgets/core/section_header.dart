// =============================================================
// FICHIER : lib/presentation/widgets/core/section_header.dart
// ROLE   : En-tete de section standardise (titre + action optionnelle)
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// USAGE :
// -------
// SectionHeader(title: 'Derniers trios')
// SectionHeader(
//   title: 'Classement',
//   trailing: AppButton.ghost(label: 'Tout voir', onPressed: ...),
// )
//
// RESPECTE LA GRILLE :
// --------------------
// Le label de section est en style labelSm (10pt, uppercase,
// letterSpacing large) = "NOUVELLE" "DERNIERS TRIOS" "PARAMETRES".
// Ce pattern evoque Duolingo et Apple HIG.
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// En-tete de section (titre overline + widget trailing optionnel).
class SectionHeader extends StatelessWidget {

  /// Titre de la section. Affiche en uppercase par convention
  /// (le widget n'applique pas lui-meme la transformation, c'est
  /// a l'appelant de passer un string deja en majuscules s'il le
  /// souhaite — plus flexible si on veut mixer).
  final String title;

  /// Widget optionnel a droite (bouton "voir tout", chip de filtre).
  final Widget? trailing;

  /// Espacement vertical autour du header.
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(
      top: TSpacing.lg,
      bottom: TSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- Titre overline ---
          // labelSm = 10pt + letterSpacing 1.5 + poids 700.
          // Cette echelle donne le rendu "overline section" pro.
          Expanded(
            child: Text(
              title,
              style: TTypography.labelSm(color: colors.textTertiary),
            ),
          ),

          // --- Trailing ---
          // Typiquement un AppButton.ghost ou un IconButton.
          ?trailing,
        ],
      ),
    );
  }
}
