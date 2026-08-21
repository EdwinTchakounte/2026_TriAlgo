// =============================================================
// FICHIER : card_thumbnail.dart
// ROLE    : Mini-carte reutilisable (image + label)
// =============================================================
//
// Utilisee dans les listes (page Cards), les pickers (page Trios),
// et la preview (page Graph). Centralisee pour assurer une
// presentation coherente partout.
// =============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/card.dart';
import '../../data/models/card_type.dart';

class CardThumbnail extends StatelessWidget {
  final GameCard card;
  // Selectionnee = ring orange autour de la mini-carte (utilise
  // dans le picker pour signaler la carte choisie).
  final bool selected;
  // Si fourni, la mini-carte devient cliquable.
  final VoidCallback? onTap;
  // Hauteur cible. Permet de varier (grande dans la liste,
  // compacte dans le picker).
  final double height;

  const CardThumbnail({
    super.key,
    required this.card,
    this.selected = false,
    this.onTap,
    this.height = 140,
  });

  // Couleur d'accent par type pour repere visuel rapide.
  Color _typeColor() {
    switch (card.type) {
      case CardType.emettrice:
        return const Color(0xFF42A5F5); // bleu
      case CardType.cable:
        return const Color(0xFFAB47BC); // violet
      case CardType.receptrice:
        return const Color(0xFF66BB6A); // vert
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _typeColor();
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.cardColor,
          // Quand selected = true, on epaissit la bordure et on
          // passe en orange pour mettre en evidence le choix.
          border: Border.all(
            color: selected ? const Color(0xFFFF6B35) : accent.withValues(alpha: 0.3),
            width: selected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image en haut, prend tout l'espace dispo.
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: card.imagePath,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: accent.withValues(alpha: 0.1),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: accent.withValues(alpha: 0.1),
                    child: Icon(Icons.broken_image, color: accent),
                  ),
                ),
              ),
            ),
            // Bandeau bas avec label + chip type.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Petit point coloré indiquant le type.
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      card.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
