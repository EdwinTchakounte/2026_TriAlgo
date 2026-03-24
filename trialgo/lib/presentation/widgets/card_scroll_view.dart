// =============================================================
// FICHIER : lib/presentation/widgets/card_scroll_view.dart
// ROLE   : Afficher la liste horizontale des 10 images de choix
// COUCHE : Presentation > Widgets
// =============================================================
//
// CE WIDGET AFFICHE :
// -------------------
// La partie BASSE de l'ecran de jeu : une bande horizontale
// scrollable contenant les 10 images parmi lesquelles le joueur
// doit choisir la bonne reponse.
//
//   <- faire defiler les 10 images ->
//   +------+------+------+------+------+------+
//   |[img1]|[img2]|[img3]|[img4]|[img5]|[img6]| ...
//   +------+------+------+------+------+------+
//
// Le joueur fait defiler horizontalement avec le doigt et tape
// sur l'image qu'il pense etre la bonne reponse.
//
// REFERENCE : Recueil v3.0, section 6.1
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/domain/entities/card_entity.dart';
import 'package:trialgo/presentation/widgets/card_image_widget.dart';

/// Liste horizontale scrollable des images de choix.
///
/// Affiche [cards] dans un ListView horizontal.
/// Chaque image est un [CardImageWidget] cliquable.
///
/// [onCardSelected] est appele quand le joueur tape sur une image.
/// [selectedCardId] permet de mettre en surbrillance la carte selectionnee.
/// [correctCardId] permet de reveler la bonne reponse apres une erreur.
class CardScrollView extends StatelessWidget {

  /// Les 10 cartes a afficher (1 correcte + 9 distracteurs, melangees).
  final List<CardEntity> cards;

  /// Callback appele quand le joueur tape sur une carte.
  ///
  /// Recoit la carte selectionnee en parametre.
  /// "void Function(CardEntity)" :
  ///   - "void" : la fonction ne retourne rien
  ///   - "Function(CardEntity)" : elle prend un CardEntity en parametre
  ///
  /// Null si le joueur ne peut plus repondre (deja repondu ou timeout).
  final void Function(CardEntity)? onCardSelected;

  /// ID de la carte selectionnee par le joueur (bordure doree).
  /// Null si le joueur n'a pas encore repondu.
  final String? selectedCardId;

  /// ID de la bonne reponse (bordure verte, revelee apres erreur).
  /// Null si on ne doit pas encore reveler la reponse.
  final String? correctCardId;

  /// `true` si le joueur a deja repondu (desactive les taps).
  final bool isAnswered;

  const CardScrollView({
    required this.cards,
    this.onCardSelected,
    this.selectedCardId,
    this.correctCardId,
    this.isAnswered = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // --- SizedBox avec hauteur fixe ---
    // Le ListView horizontal a besoin d'une HAUTEUR definie.
    // Sans SizedBox, il prendrait toute la hauteur de l'ecran.
    // 140 = taille de la carte (120) + marges (20).
    return SizedBox(
      height: 140,

      // --- ListView.builder ---
      // "ListView.builder" construit les elements A LA DEMANDE.
      // Contrairement a "ListView(children: [...])" qui construit
      // TOUS les elements d'un coup, .builder ne construit que
      // les elements VISIBLES a l'ecran.
      //
      // Pour 10 images, la difference est negligeable.
      // Mais c'est une bonne pratique pour des listes plus longues.
      //
      // Parametres :
      //   scrollDirection : direction du defilement
      //   itemCount : nombre total d'elements
      //   itemBuilder : fonction qui construit chaque element
      //   padding : espace autour de la liste
      child: ListView.builder(
        // Defilement HORIZONTAL (gauche-droite).
        // Par defaut, ListView defile verticalement.
        scrollDirection: Axis.horizontal,

        // Nombre total d'elements dans la liste.
        // "cards.length" = 10 (1 correcte + 9 distracteurs).
        itemCount: cards.length,

        // Espace au debut et a la fin de la liste.
        // "EdgeInsets.symmetric(horizontal: 8)" :
        //   8 pixels a gauche + 8 pixels a droite.
        padding: const EdgeInsets.symmetric(horizontal: 8),

        // --- itemBuilder : construit chaque element ---
        // Appele pour chaque index de 0 a itemCount-1.
        //
        // "context" : le BuildContext Flutter
        // "index" : l'index de l'element (0, 1, 2, ..., 9)
        //
        // Retourne le widget a afficher pour cet index.
        itemBuilder: (context, index) {
          // Recuperer la carte a cet index.
          final card = cards[index];

          // --- Determiner l'etat visuel de cette carte ---
          // Est-ce la carte selectionnee par le joueur ?
          final isSelected = selectedCardId == card.id;

          // Est-ce la bonne reponse (a reveler apres une erreur) ?
          final isRevealed = correctCardId == card.id && isAnswered;

          // Est-ce la carte choisie ET c'est une mauvaise reponse ?
          final isWrong = isSelected && isAnswered && correctCardId != card.id;

          // --- Padding autour de chaque carte ---
          // "Padding" ajoute un espace entre les cartes.
          // Sans lui, les cartes seraient collees les unes aux autres.
          return Padding(
            // 6 pixels a gauche et a droite de chaque carte.
            // Total entre deux cartes : 6 + 6 = 12 pixels.
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),

            child: CardImageWidget(
              card: card,
              size: 120,
              isSelected: isSelected,
              isRevealed: isRevealed,
              isWrong: isWrong,

              // --- Callback de selection ---
              // Si le joueur a deja repondu (isAnswered), onTap est null
              // -> la carte n'est pas cliquable.
              // Sinon, on appelle onCardSelected avec cette carte.
              //
              // "isAnswered ? null : () { ... }" :
              //   Operateur ternaire qui desactive le tap apres une reponse.
              onTap: isAnswered
                  ? null
                  : () => onCardSelected?.call(card),
              // "onCardSelected?.call(card)" :
              //   - "?." : appelle la methode SEULEMENT si onCardSelected n'est pas null
              //   - ".call(card)" : execute la fonction avec "card" en parametre
              //   - Equivalent de : if (onCardSelected != null) onCardSelected!(card);
            ),
          );
        },
      ),
    );
  }
}
