// =============================================================
// FICHIER : lib/presentation/widgets/card_image_widget.dart
// ROLE   : Afficher UNE carte du jeu (image avec cache et feedback)
// COUCHE : Presentation > Widgets
// =============================================================
//
// C'EST LE WIDGET LE PLUS UTILISE DE L'APPLICATION.
// -------------------------------------------------
// Chaque image sur l'ecran de jeu est un CardImageWidget :
//   - Les 2-3 cartes visibles en haut (E, C, R)
//   - La carte masquee ("???")
//   - Les 10 images de choix dans la ScrollView
//
// Il gere :
//   - Le chargement de l'image depuis Supabase Storage (avec cache)
//   - L'affichage d'un placeholder pendant le chargement
//   - L'affichage d'une icone d'erreur si l'image est introuvable
//   - La bordure de selection (doree quand selectionnee)
//   - Le masquage ("???" quand la carte est cachee)
//   - L'animation de selection (scale + shadow)
//   - Le callback quand le joueur tape sur l'image
//
// PACKAGE : cached_network_image
// ------------------------------
// Ce package telecharge l'image UNE FOIS depuis l'URL,
// la stocke dans le cache DISQUE du telephone, et la sert
// depuis le cache les fois suivantes.
//
// Avantage : les images des cartes ne sont telechargees qu'une seule
// fois. Les sessions suivantes chargent instantanement depuis le cache.
//
// REFERENCE : Recueil v3.0, section 5
// =============================================================

import 'package:flutter/material.dart';

// Import du package de cache d'images.
import 'package:cached_network_image/cached_network_image.dart';
// CachedNetworkImage : widget qui telecharge, cache et affiche une image URL.
// Il fournit :
//   - imageUrl : l'URL de l'image a charger
//   - placeholder : widget affiche PENDANT le chargement
//   - errorWidget : widget affiche si le chargement ECHOUE
//   - fit : comment l'image remplit son espace (cover, contain, etc.)

// Import de l'entite pour le typage.
import 'package:trialgo/domain/entities/card_entity.dart';

/// Widget qui affiche une carte du jeu TRIALGO.
///
/// Gere le chargement depuis le reseau, le cache, le masquage ("???"),
/// la selection (bordure doree), et le tap.
///
/// C'est un StatelessWidget car il n'a PAS d'etat interne.
/// Toutes les donnees viennent de l'exterieur (via les parametres).
/// Le parent (GamePage) gere l'etat et passe les bonnes valeurs.
class CardImageWidget extends StatelessWidget {

  // =============================================================
  // PROPRIETES
  // =============================================================

  /// La carte a afficher (contient l'URL de l'image, le type, etc.).
  final CardEntity card;

  /// Taille du widget en pixels (largeur = hauteur, c'est un carre).
  /// Par defaut 120px. Ajustable selon le contexte :
  ///   - 120px pour les cartes de la ScrollView (petit)
  ///   - 150px pour les cartes visibles en haut (grand)
  final double size;

  /// `true` si cette carte est selectionnee par le joueur.
  /// Affiche une bordure doree et une ombre quand true.
  final bool isSelected;

  /// `true` si cette carte doit etre masquee (affiche "???").
  /// Utilise pour la 3eme carte du trio qui est la question.
  final bool isMasked;

  /// `true` si cette carte est la bonne reponse revelee apres une erreur.
  /// Affiche une bordure verte surbrillante.
  final bool isRevealed;

  /// `true` si cette carte a ete choisie et est incorrecte.
  /// Affiche une bordure rouge.
  final bool isWrong;

  /// Callback appele quand le joueur tape sur cette carte.
  /// Null si le tap est desactive (carte visible, pas de choix).
  ///
  /// "VoidCallback?" :
  ///   - "VoidCallback" = une fonction sans parametre et sans retour
  ///     typedef VoidCallback = void Function();
  ///   - "?" = nullable (peut etre null)
  ///   - Si null, GestureDetector ne reagit pas au tap
  final VoidCallback? onTap;

  /// Constructeur avec parametres nommes.
  const CardImageWidget({
    required this.card,          // Obligatoire : quelle carte afficher
    this.size = 120,             // Taille par defaut : 120px
    this.isSelected = false,     // Pas selectionnee par defaut
    this.isMasked = false,       // Pas masquee par defaut
    this.isRevealed = false,     // Pas revelee par defaut
    this.isWrong = false,        // Pas incorrecte par defaut
    this.onTap,                  // Pas de callback par defaut
    super.key,                   // Cle Flutter pour le recycling
  });

  @override
  Widget build(BuildContext context) {
    // --- Determiner la couleur de la bordure ---
    // Selon l'etat de la carte, la bordure change de couleur.
    //
    // Priorite (de la plus haute a la plus basse) :
    //   1. Revelee (bonne reponse) -> vert
    //   2. Incorrecte (mauvaise reponse) -> rouge
    //   3. Selectionnee -> ambre/dore
    //   4. Aucun etat special -> transparent
    //
    // "Color" est le type Flutter pour les couleurs.
    // "Colors.transparent" = invisible (pas de bordure visible).
    final Color borderColor;
    if (isRevealed) {
      borderColor = Colors.green;
    } else if (isWrong) {
      borderColor = Colors.red;
    } else if (isSelected) {
      borderColor = Colors.amber;
    } else {
      borderColor = Colors.transparent;
    }

    // --- GestureDetector : detecte les taps ---
    // "GestureDetector" enveloppe un widget et detecte les gestes.
    // "onTap" : callback appele quand l'utilisateur tape une fois.
    // Si onTap est null, le GestureDetector n'intercepte PAS le geste
    // (le tap "passe a travers" vers le widget en dessous).
    return GestureDetector(
      onTap: onTap,

      // --- AnimatedContainer : animation de transition ---
      // "AnimatedContainer" est un Container qui ANIME les changements.
      // Quand une propriete change (taille, couleur, bordure...),
      // la transition est animee sur la duree specifiee.
      //
      // Exemple : quand isSelected passe de false a true,
      // la bordure passe de transparent a ambre avec une animation
      // de 200 millisecondes. Pas besoin d'AnimationController.
      child: AnimatedContainer(
        // Duree de l'animation de transition.
        duration: const Duration(milliseconds: 200),

        // Dimensions du container (carre).
        width: size,
        height: size,

        // --- Decoration : style visuel ---
        // "BoxDecoration" definit l'apparence du container :
        //   bordure, coins arrondis, ombre, etc.
        decoration: BoxDecoration(
          // Bordure coloree selon l'etat.
          border: Border.all(
            color: borderColor,
            width: 3,
          ),

          // Coins arrondis (12 pixels de rayon).
          // "BorderRadius.circular(12)" cree des coins arrondis
          // uniformes sur les 4 coins.
          borderRadius: BorderRadius.circular(12),

          // Ombre quand selectionnee (effet de "soulevee").
          // "boxShadow" : liste d'ombres appliquees au container.
          // Si isSelected est false, la liste est vide (pas d'ombre).
          boxShadow: isSelected || isRevealed
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.5),
                    // ".withValues(alpha: 0.5)" : rend la couleur semi-transparente.
                    // alpha = 0.5 -> 50% transparent.
                    blurRadius: 8,
                    // "blurRadius" : rayon de flou de l'ombre (en pixels).
                    // Plus la valeur est grande, plus l'ombre est diffuse.
                    spreadRadius: 2,
                    // "spreadRadius" : extension de l'ombre au-dela du container.
                  ),
                ]
              : [],
          // "? [...] : []" : operateur ternaire
          //   Si la condition est true -> liste avec une ombre
          //   Si false -> liste vide (pas d'ombre)
        ),

        // --- Contenu : image ou masque ---
        // "ClipRRect" decoupe son enfant pour respecter les coins arrondis.
        // Sans ClipRRect, l'image deborderait aux coins.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          // 10 < 12 (container) pour que la bordure reste visible
          // autour de l'image.

          // Si masquee -> afficher "???"
          // Si non masquee -> afficher l'image
          child: isMasked ? _buildMaskedCard() : _buildImageCard(),
        ),
      ),
    );
  }

  // =============================================================
  // METHODE PRIVEE : _buildMaskedCard
  // =============================================================
  // Construit le widget "???" affiche quand la carte est masquee.
  // C'est un container gris avec un point d'interrogation blanc.
  // =============================================================

  /// Construit l'affichage masque ("???").
  Widget _buildMaskedCard() {
    return Container(
      // "color" : couleur de fond du container.
      // "Colors.grey[800]" : gris fonce.
      // Le "[800]" est un indice de nuance (100=clair, 900=fonce).
      color: Colors.grey[800],

      // "Center" centre son enfant.
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 48,           // Grande taille pour la visibilite
            color: Colors.white,    // Blanc sur fond gris fonce
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // =============================================================
  // METHODE PRIVEE : _buildImageCard
  // =============================================================
  // Construit le widget qui affiche l'image depuis le reseau.
  // Utilise CachedNetworkImage pour le cache disque.
  // =============================================================

  /// Construit l'affichage de l'image (avec cache et fallbacks).
  Widget _buildImageCard() {
    // "CachedNetworkImage" : widget du package cached_network_image.
    // Il telecharge l'image, la cache sur le disque, et l'affiche.
    return CachedNetworkImage(
      // --- URL de l'image ---
      // "card.imageUrl" : getter qui reconstruit l'URL complete
      // a partir du chemin relatif (imagePath) et de StorageConstants.baseUrl.
      // Exemple : "https://olovolsbopjporwpuphm.supabase.co/.../lion_base.webp"
      imageUrl: card.imageUrl,

      // --- Comment l'image remplit le container ---
      // "BoxFit.cover" : l'image remplit TOUT le container.
      //   - Si l'image est plus grande : elle est coupee (croppee)
      //   - Si l'image est plus petite : elle est agrandie
      //   - Le ratio est conserve (pas de deformation)
      //
      // Autres options :
      //   BoxFit.contain : l'image entiere est visible (avec marges)
      //   BoxFit.fill    : l'image est deformee pour remplir
      fit: BoxFit.cover,

      // --- Placeholder : pendant le chargement ---
      // "placeholder" : fonction qui retourne le widget affiche
      // PENDANT que l'image se telecharge.
      //
      // "(context, url)" : parametres fournis par CachedNetworkImage
      //   context : le BuildContext Flutter
      //   url     : l'URL de l'image en cours de chargement
      //
      // On affiche un fond gris clair avec un petit spinner.
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // "strokeWidth" : epaisseur du cercle du spinner.
              // 2 = fin (adapte a la petite taille de la carte).
            ),
          ),
        ),
      ),

      // --- ErrorWidget : si le chargement echoue ---
      // Affiche quand l'image est introuvable (404), corrompue,
      // ou que le reseau est indisponible.
      //
      // "(context, url, error)" : parametres
      //   error : l'objet d'erreur (pour le debug)
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icone d'image cassee.
            Icon(
              _fallbackIcon(card.cardType),
              // Icone differente selon le type de carte.
              size: 32,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 4),
            // Label du type de carte.
            Text(
              _fallbackLabel(card.cardType),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // METHODES PRIVEES : icones et labels de fallback
  // =============================================================
  // Quand une image ne charge pas, on affiche une icone
  // differente selon le type de carte.
  // =============================================================

  /// Retourne l'icone de fallback selon le [type] de carte.
  ///
  /// - Emettrice  : icone "image" (la base)
  /// - Cable      : icone "fleches" (la transformation)
  /// - Receptrice : icone "auto_awesome" (le resultat magique)
  IconData _fallbackIcon(CardType type) => switch (type) {
    CardType.emettrice  => Icons.image_outlined,
    CardType.cable      => Icons.compare_arrows,
    CardType.receptrice => Icons.auto_awesome,
  };
  // "switch" expression : retourne directement la valeur.
  // Chaque cas retourne un IconData (type des icones Material).
  // "=>" est le raccourci pour une expression de retour.

  /// Retourne le label de fallback selon le [type] de carte.
  String _fallbackLabel(CardType type) => switch (type) {
    CardType.emettrice  => 'Emettrice',
    CardType.cable      => 'Cable',
    CardType.receptrice => 'Receptrice',
  };
}
