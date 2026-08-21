// =============================================================
// FICHIER : empty_state.dart
// ROLE    : Composant d'etat vide ("aucun X pour l'instant")
// =============================================================
//
// Au lieu de montrer une liste vide brutale, on affiche :
//   - Une icone (suggere ce qui manque)
//   - Un titre (constat)
//   - Une description (que faire pour avancer)
//   - Optionnellement un bouton d'action principal
//
// Centre vertical et horizontal pour bonne presence visuelle.
// =============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  // Texte du bouton (null = pas de bouton).
  final String? actionLabel;
  // Handler du bouton (requis si actionLabel != null).
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cercle clair avec icone : peu agressif visuellement.
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.brand),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.sectionTitle(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTextStyles.caption(),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
