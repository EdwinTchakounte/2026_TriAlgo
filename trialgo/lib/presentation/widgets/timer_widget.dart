// =============================================================
// FICHIER : lib/presentation/widgets/timer_widget.dart
// ROLE   : Afficher le chronometre de tour (barre circulaire animee)
// COUCHE : Presentation > Widgets
// =============================================================
//
// CE WIDGET AFFICHE :
// -------------------
// Un cercle progressif qui se vide au fur et a mesure que le temps
// passe. Le nombre de secondes restantes est affiche au centre.
//
//     ╭──────╮
//     │      │    <- cercle colore (se vide dans le sens horaire)
//     │  28s │    <- secondes restantes au centre
//     │      │
//     ╰──────╯
//
// Couleurs (reference : recueil section 8.1) :
//   > 60% restant -> Vert    (tout va bien)
//   30-60%        -> Orange  (attention, accelerer)
//   < 30%         -> Rouge   (urgence !)
//
// REFERENCE : Recueil v3.0, section 8.1
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/presentation/providers/question_timer_provider.dart';

/// Widget circulaire affichant le temps restant pour repondre.
///
/// Ecoute [questionTimerProvider] et se reconstruit chaque seconde.
/// Le cercle se vide progressivement et change de couleur.
class TimerWidget extends ConsumerWidget {
  /// Taille du cercle en pixels.
  final double size;

  const TimerWidget({this.size = 56, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- Lire l'etat du chronometre ---
    // Reconstruit le widget CHAQUE SECONDE (car le timer change).
    final timerState = ref.watch(questionTimerProvider);

    // --- Determiner la couleur selon l'urgence ---
    // "urgencyLevel" retourne 0 (vert), 1 (orange) ou 2 (rouge).
    //
    // "switch" expression pour convertir le niveau en couleur.
    final color = switch (timerState.urgencyLevel) {
      0 => Colors.green,   // > 60% restant
      1 => Colors.orange,  // 30-60% restant
      2 => Colors.red,     // < 30% restant
      _ => Colors.grey,    // Securite (ne devrait pas arriver)
    };
    // "_" est le WILDCARD : capture tous les cas non listes.
    // Obligatoire car switch sur un int n'est pas exhaustif
    // (un int peut valoir n'importe quel nombre).

    // --- Construction du widget ---
    // "SizedBox" fixe la taille du cercle.
    return SizedBox(
      width: size,
      height: size,

      // "Stack" empile des widgets les uns SUR les autres.
      // Comme des calques Photoshop :
      //   Calque 1 (fond)   : le cercle progressif
      //   Calque 2 (dessus) : le texte des secondes
      child: Stack(
        // "alignment" : comment aligner les calques.
        // "center" : tous les calques sont centres.
        alignment: Alignment.center,

        children: [
          // --- Calque 1 : Cercle progressif ---
          // "CircularProgressIndicator" : widget Flutter natif
          // qui affiche un cercle de progression.
          //
          // Deux modes :
          //   - Indetermine (pas de value) : tourne infiniment (spinner)
          //   - Determine (avec value) : remplit selon la valeur (0.0 a 1.0)
          //
          // Ici on l'utilise en mode DETERMINE pour montrer
          // la proportion de temps restant.
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              // "value" : la progression de 0.0 (vide) a 1.0 (plein).
              // "1.0 - timerState.progress" : on inverse car
              //   - progress = temps ecoule / temps total (0.0 -> 1.0)
              //   - On veut afficher le temps RESTANT (1.0 -> 0.0)
              //   - Au debut : 1.0 - 0.0 = 1.0 (cercle plein)
              //   - A la fin  : 1.0 - 1.0 = 0.0 (cercle vide)
              value: 1.0 - timerState.progress,

              // Couleur du cercle rempli (change selon l'urgence).
              valueColor: AlwaysStoppedAnimation<Color>(color),
              // "AlwaysStoppedAnimation" : cree une Animation qui
              // ne bouge jamais. C'est le format attendu par valueColor.
              // Le cercle ne s'anime pas (pas de rotation),
              // il change juste de longueur.

              // Couleur du fond du cercle (la partie non remplie).
              backgroundColor: Colors.grey[300],

              // Epaisseur du trait du cercle.
              strokeWidth: 5,
            ),
          ),

          // --- Calque 2 : Secondes restantes ---
          // Affiche le nombre de secondes restantes au centre du cercle.
          Text(
            // "${timerState.remainingSeconds}" :
            //   Interpolation de string : insere la valeur de la variable
            //   dans la chaine de caracteres.
            //   Exemple : si remainingSeconds = 28 -> affiche "28"
            '${timerState.remainingSeconds}',
            style: TextStyle(
              fontSize: size * 0.3,
              // Taille proportionnelle au cercle.
              // Si size = 56, fontSize = 16.8 (arrondi a ~17).
              fontWeight: FontWeight.bold,
              color: color,
              // Meme couleur que le cercle pour la coherence visuelle.
            ),
          ),
        ],
      ),
    );
  }
}
