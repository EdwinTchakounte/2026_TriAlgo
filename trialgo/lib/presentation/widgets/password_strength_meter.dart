// =============================================================
// FICHIER : lib/presentation/widgets/password_strength_meter.dart
// ROLE   : Indicateur visuel de la force d'un mot de passe
// COUCHE : Presentation > Widgets
// =============================================================
//
// DOIT ETRE UTILISE :
// -------------------
//   - Page signup (t_auth_page en mode inscription)
//   - Page new password (apres reset par mail)
//   - Eventuelle page "changer mon mot de passe" (settings profil)
//
// REGLES DE SCORE (0 a 4) :
// -------------------------
//   +1 si longueur >= 6
//   +1 si au moins 1 chiffre
//   +1 si au moins 1 lettre min ET majuscule
//   +1 si au moins 1 caractere special (!@#$%^&*...)
//
// LABELS :
// --------
//   0 : vide         (meter vide, pas de texte)
//   1 : Faible       (rouge)
//   2 : Moyen        (orange/warning)
//   3 : Bon          (vert/success)
//   4 : Fort         (vert/success)
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Barre de force du mot de passe + label contextuel.
class PasswordStrengthMeter extends StatelessWidget {

  /// Le texte actuellement saisi. Le score est calcule depuis.
  final String password;

  const PasswordStrengthMeter({
    super.key,
    required this.password,
  });

  // =============================================================
  // METHODE STATIQUE : computeScore
  // =============================================================
  // Exposee publiquement pour etre reutilisee ailleurs (ex: un
  // bouton "Enregistrer" grise si score < 2).
  // =============================================================

  /// Retourne un score 0 (vide) a 4 (tres fort).
  static int computeScore(String pwd) {
    if (pwd.isEmpty) return 0;
    int score = 0;
    if (pwd.length >= 6) score++;
    if (RegExp(r'\d').hasMatch(pwd)) score++;
    if (RegExp(r'[a-z]').hasMatch(pwd) &&
        RegExp(r'[A-Z]').hasMatch(pwd)) {
      score++;
    }
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=]').hasMatch(pwd)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final score = computeScore(password);

    // Tuple (label, couleur) selon le score.
    final (label, color) = switch (score) {
      0 => ('', TColors.error),
      1 => ('Faible', TColors.error),
      2 => ('Moyen', TColors.warning),
      3 => ('Bon', TColors.success),
      _ => ('Fort', TColors.success),
    };

    final colors = TColors.of(context);

    return Row(
      children: [
        // Les 4 segments, colores jusqu'a score.
        for (int i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: TDuration.quick,
              height: 4,
              decoration: BoxDecoration(
                color: i < score ? color : colors.borderDefault,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: TSpacing.sm),

        // Label a droite, largeur fixe pour ne pas sauter a la frappe.
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TTypography.labelMd(color: color),
          ),
        ),
      ],
    );
  }
}
