// =============================================================
// FICHIER : guidance_banner.dart
// ROLE    : Banniere "tu en es la, voila ce qui t'attend"
// =============================================================
//
// C'est LE composant qui rend l'app "bien guidee".
// Affiche en haut de chaque etape du wizard :
//   - Une icone d'etape
//   - Le titre de l'etape
//   - Une description explicative (ce que l'admin doit faire ici
//     ET pourquoi)
//
// Pourquoi des explications a chaque etape ? Parce que TRIALGO
// a une logique metier non-triviale (trios E+C=>R, chainage D2+).
// Un nouvel admin doit pouvoir comprendre sans documentation.
// =============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class GuidanceBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  // Couleur d'accent : par defaut brand. Permet de varier selon
  // l'etape (ex : couleur de profondeur sur la page trios).
  final Color? accent;

  const GuidanceBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.brand;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Fond tres clair de la couleur d'accent : suffisamment
        // visible pour distinguer la banniere du body, mais
        // pas agressif.
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cercle icone : prend de la place visuellement, oriente
          // immediatement l'oeil vers le bon endroit.
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.sectionTitle()),
                const SizedBox(height: 4),
                Text(description, style: AppTextStyles.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
