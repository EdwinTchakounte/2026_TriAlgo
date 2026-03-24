// =============================================================
// FICHIER : lib/presentation/widgets/lives_widget.dart
// ROLE   : Afficher les vies du joueur (coeurs)
// COUCHE : Presentation > Widgets
// =============================================================
//
// CE WIDGET AFFICHE :
// -------------------
// Une rangee de coeurs representant les vies du joueur.
// Les coeurs pleins = vies restantes.
// Les coeurs vides = vies perdues.
//
//   ❤️❤️❤️🖤🖤    <- 3 vies sur 5
//
// REFERENCE : Recueil v3.0, section 8.5
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/core/constants/game_constants.dart';

/// Widget affichant les vies du joueur sous forme de coeurs.
///
/// [lives] coeurs pleins (rouges) et [maxLives - lives] coeurs
/// vides (gris) sont affiches en ligne.
class LivesWidget extends StatelessWidget {

  /// Nombre de vies restantes (0 a maxLives).
  final int lives;

  /// Nombre maximum de vies (par defaut 5).
  final int maxLives;

  /// Taille de chaque coeur en pixels.
  final double heartSize;

  const LivesWidget({
    required this.lives,
    this.maxLives = GameConstants.maxLives,
    this.heartSize = 24,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // "Row" aligne les coeurs horizontalement.
    return Row(
      // "mainAxisSize: MainAxisSize.min" :
      //   La Row prend le MINIMUM de largeur necessaire.
      //   Sans cela, la Row prendrait toute la largeur de l'ecran.
      mainAxisSize: MainAxisSize.min,

      // --- Generer la liste de coeurs ---
      // "List.generate(count, builder)" :
      //   Cree une liste de "count" elements.
      //   Le builder est appele pour chaque index (0 a count-1).
      //
      //   Exemple avec maxLives = 5 et lives = 3 :
      //     index 0 -> coeur plein (0 < 3)
      //     index 1 -> coeur plein (1 < 3)
      //     index 2 -> coeur plein (2 < 3)
      //     index 3 -> coeur vide  (3 >= 3)
      //     index 4 -> coeur vide  (4 >= 3)
      children: List.generate(maxLives, (index) {
        // "index < lives" : si l'index est inferieur au nombre
        // de vies restantes, le coeur est PLEIN.
        final isFilled = index < lives;

        // "Padding" ajoute un petit espace entre chaque coeur.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            // Icone de coeur : plein (favorite) ou vide (favorite_border).
            isFilled ? Icons.favorite : Icons.favorite_border,
            // "Icons.favorite" : coeur plein (❤️)
            // "Icons.favorite_border" : contour de coeur (🖤)

            // Couleur : rouge si plein, gris si vide.
            color: isFilled ? Colors.red : Colors.grey[400],

            // Taille du coeur.
            size: heartSize,
          ),
        );
      }),
    );
  }
}
