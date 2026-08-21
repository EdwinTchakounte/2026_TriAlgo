// =============================================================
// FICHIER : card_thumbnail.dart
// ROLE    : Mini-carte reutilisable (image + label + chip type)
// =============================================================
//
// Sert dans 3 endroits :
//   - Page Cards : liste/grille
//   - Page Trios : pickers (E, C, R)
//   - Page Preview : aperçu d'un node
//
// L'API permet :
//   - selected : ring orange autour pour le picker
//   - onTap    : optionnel (sans onTap, le widget est juste
//                affichage)
//   - height   : variable selon contexte (compact / detail)
// =============================================================

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/card_type.dart';
import '../../domain/entities/game_card.dart';

class CardThumbnail extends StatelessWidget {
  final GameCard card;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  const CardThumbnail({
    super.key,
    required this.card,
    this.selected = false,
    this.onTap,
    this.height = 140,
  });

  // Couleur d'accent selon le role de la carte.
  Color _typeColor() {
    switch (card.type) {
      case CardType.emettrice:
        return AppColors.cardEmettrice;
      case CardType.cable:
        return AppColors.cardCable;
      case CardType.receptrice:
        return AppColors.cardReceptrice;
      // Type null = ancienne carte seed -> gris.
      case null:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _typeColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          // Selectionnee : ring orange epais. Sinon : trait fin
          // de la couleur de type pour signaler le role.
          border: Border.all(
            color: selected ? AppColors.brand : accent.withValues(alpha: 0.3),
            width: selected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------------------------------------------------
            // IMAGE (haut, prend l'espace dispo)
            // -------------------------------------------------
            // Trois sources possibles selon le scheme :
            //   - file://  -> Image.file (image locale, mode mock ou
            //                 reels uploads en cours)
            //   - http(s)  -> CachedNetworkImage (Supabase Storage)
            //   - vide ou inconnu -> avatar genere (lettre + couleur)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: _ImageContent(
                  path: card.imagePath,
                  label: card.label,
                  accent: accent,
                ),
              ),
            ),
            // -------------------------------------------------
            // BANDEAU BAS (point colore + label)
            // -------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(13),
                ),
              ),
              child: Row(
                children: [
                  // Petit dot colore = role de la carte.
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
                      style: AppTextStyles.label(),
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

// =============================================================
// _ImageContent : aiguilleur de source d'image
// =============================================================
// On centralise ici la decision "comment afficher cette image"
// pour eviter de polluer le build() principal de CardThumbnail.
//
//   - vide / null         -> avatar genere
//   - file:// ou /chemin  -> Image.file
//   - http(s)://          -> CachedNetworkImage
//   - autre               -> avatar genere (fallback safe)
class _ImageContent extends StatelessWidget {
  final String path;
  final String label;
  final Color accent;

  const _ImageContent({
    required this.path,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return _Avatar(label: label, accent: accent);
    }

    // Cas file:// ou chemin absolu : on lit le fichier directement.
    if (trimmed.startsWith('file://') || trimmed.startsWith('/')) {
      final filePath = trimmed.startsWith('file://')
          ? Uri.parse(trimmed).toFilePath()
          : trimmed;
      final f = File(filePath);
      // existsSync() est synchrone mais bon marche ; evite un FutureBuilder.
      if (!f.existsSync()) {
        return _BrokenImage(accent: accent);
      }
      return Image.file(
        f,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _BrokenImage(accent: accent),
      );
    }

    // Cas reseau : on garde CachedNetworkImage pour la mise en cache.
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: trimmed,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          color: accent.withValues(alpha: 0.1),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => _BrokenImage(accent: accent),
      );
    }

    return _Avatar(label: label, accent: accent);
  }
}

// =============================================================
// _Avatar : vignette generee depuis la 1re lettre du label
// =============================================================
// Sert quand la carte n'a pas (encore) d'image - typique du jeu
// de demo seedé. Couleur du role + grosse lettre = identification
// immediate sans dependre du reseau.
class _Avatar extends StatelessWidget {
  final String label;
  final Color accent;

  const _Avatar({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    final letter = label.isNotEmpty ? label.characters.first.toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.10),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: accent,
          fontSize: 40,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// =============================================================
// _BrokenImage : etat erreur (fichier introuvable, url 404)
// =============================================================
class _BrokenImage extends StatelessWidget {
  final Color accent;
  const _BrokenImage({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Icon(Icons.broken_image, color: accent),
    );
  }
}
