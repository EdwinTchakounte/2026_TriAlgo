// =============================================================
// FICHIER : lib/presentation/widgets/core/app_divider.dart
// ROLE   : Separateur horizontal, avec ou sans label central
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// DEUX MODES :
// ------------
// 1. Simple : ligne horizontale (equivalent Divider)
//    AppDivider()
//
// 2. Avec label : ligne + texte au centre
//    AppDivider(label: 'OU SAISIE MANUELLE')
//
// La variante labelled remplace le pattern repete Row(Divider +
// Text + Divider) present dans plusieurs pages (auth, collectif...).
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Separateur horizontal standard, avec ou sans label central.
class AppDivider extends StatelessWidget {

  /// Label optionnel affiche au centre. Null = simple ligne.
  /// Par convention en majuscules (ex: "OU", "SAISIE MANUELLE").
  final String? label;

  /// Marge verticale externe au separateur (haut et bas).
  /// Par defaut TSpacing.lg (16pt) pour respirer.
  final double verticalSpacing;

  const AppDivider({
    super.key,
    this.label,
    this.verticalSpacing = TSpacing.lg,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);

    // --- Ligne de base reutilisee pour les 2 modes ---
    // Hauteur 1px, couleur bordure subtile du theme.
    // Expanded pour qu'elle remplisse l'espace dispo (indispensable
    // en mode label ou il y en a une a gauche et a droite).
    Widget line() => Expanded(
          child: Container(
            height: 1,
            color: colors.borderSubtle,
          ),
        );

    // --- Mode "ligne seule" ---
    if (label == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: verticalSpacing),
        child: Row(children: [line()]),
      );
    }

    // --- Mode "ligne + label + ligne" ---
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalSpacing),
      child: Row(
        children: [
          line(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TSpacing.md),
            child: Text(
              label!,
              style: TTypography.labelSm(color: colors.textTertiary),
            ),
          ),
          line(),
        ],
      ),
    );
  }
}
