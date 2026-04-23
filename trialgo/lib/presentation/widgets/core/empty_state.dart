// =============================================================
// FICHIER : lib/presentation/widgets/core/empty_state.dart
// ROLE   : Ecran "rien a afficher" standardise
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// QUAND L'UTILISER ?
// ------------------
// Quand une liste ou une section n'a rien a montrer a l'utilisateur :
//   - Historique de parties vide (nouveau joueur)
//   - Gallery sans cartes debloquees
//   - Leaderboard sans joueurs
//   - Recherche sans resultat
//   - Erreur reseau (variante error)
//
// POURQUOI PAS JUSTE "Container vide" ?
// -------------------------------------
// Un ecran vide sans explication est PERCU comme cassé par
// l'utilisateur. L'EmptyState apporte :
//   - Icone grande (feedback visuel)
//   - Titre (constat en une phrase)
//   - Description (explication + appel a l'action)
//   - Bouton optionnel (pour resoudre le vide immediatement)
//
// STYLE :
// -------
// S'inspire de Duolingo : icone illustrative en couleur brand,
// ton encourageant, action claire.
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';


/// Ecran "vide" standardise avec icone + titre + description + action.
class EmptyState extends StatelessWidget {

  /// Icone illustrative. Choisir une icone expressive.
  /// Ex: Icons.inbox_outlined, Icons.search_off, Icons.cloud_off.
  final IconData icon;

  /// Titre court (1 ligne idealement).
  final String title;

  /// Description qui explique le vide et/ou invite a agir.
  /// 1-2 lignes max pour rester digeste.
  final String description;

  /// Label du bouton d'action optionnel.
  /// Si non-null avec [onAction], un AppButton.primary est rendu.
  final String? actionLabel;

  /// Callback du bouton d'action.
  final VoidCallback? onAction;

  /// Icone du bouton d'action (optionnelle).
  final IconData? actionIcon;

  /// Ton de l'icone : primary (marque), neutral (gris),
  /// error (rouge, pour les erreurs reseau).
  final EmptyStateTone tone;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.tone = EmptyStateTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);

    // Couleur de l'icone en fonction du ton.
    final iconColor = switch (tone) {
      EmptyStateTone.primary => TColors.primary,
      EmptyStateTone.neutral => colors.textTertiary,
      EmptyStateTone.error   => TColors.error,
    };

    // --- Montage du bouton d'action si fourni ---
    final hasAction = actionLabel != null && onAction != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Cercle illustration avec icone ---
            // Fond tres transparent avec couleur de ton, qui fait
            // office de "halo" pour adoucir l'icone.
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  0x26, // ~15% d'opacite
                  iconColor.r.round(),
                  iconColor.g.round(),
                  iconColor.b.round(),
                ),
              ),
              child: Icon(icon, size: 48, color: iconColor),
            ),
            const SizedBox(height: TSpacing.xl),

            // --- Titre ---
            Text(
              title,
              textAlign: TextAlign.center,
              style: TTypography.headlineSm(color: colors.textPrimary),
            ),
            const SizedBox(height: TSpacing.sm),

            // --- Description ---
            Text(
              description,
              textAlign: TextAlign.center,
              style: TTypography.bodyMd(color: colors.textSecondary),
            ),

            // --- Action optionnelle ---
            if (hasAction) ...[
              const SizedBox(height: TSpacing.xl),
              AppButton.primary(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// Ton semantique d'un EmptyState.
enum EmptyStateTone {
  /// Gris neutre (vide normal).
  neutral,

  /// Orange primary (invitation a l'action).
  primary,

  /// Rouge (erreur reseau, probleme).
  error,
}
