// =============================================================
// FICHIER : horizontal_strip.dart
// ROLE    : Bandeau horizontal defilable a la souris, au doigt
//           et a la molette, avec une barre de defilement visible
// =============================================================
//
// POURQUOI CE WIDGET EXISTE
// -------------------------
// Un ListView horizontal "nu" fonctionne tres bien au doigt sur
// mobile. Sur le web, c'est une autre histoire, et c'est la que
// le studio est utilise au quotidien (dashboard.mixalgo.com) :
//
//   1. Flutter IGNORE le glisser a la souris depuis la version 2.5.
//      Cliquer-tirer sur le bandeau ne fait rien.
//   2. La molette envoie un defilement VERTICAL. Le bandeau, lui,
//      est horizontal : il ne bouge pas, c'est la page qui defile.
//   3. Aucune barre de defilement n'est dessinee par defaut.
//
// Resultat constate : des que les cartes depassaient la largeur de
// l'ecran, les dernieres devenaient INATTEIGNABLES. Impossible de
// selectionner un produit cache a droite, sans aucun indice visuel
// qu'il existait.
//
// Ce widget corrige les trois points :
//   - barre de defilement toujours visible (on SAIT qu'il y a une suite)
//   - glisser a la souris autorise localement (ScrollConfiguration)
//   - molette verticale convertie en deplacement horizontal, mais
//     SEULEMENT tant que le bandeau peut encore avancer dans ce sens :
//     arrive en butee, la molette rend la main a la page, sinon on
//     "pieger" l'utilisateur au survol du bandeau.
// =============================================================

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class HorizontalStrip extends StatefulWidget {
  // Hauteur du contenu (sans la barre de defilement).
  final double height;

  // Nombre d'elements et fabrique, comme un ListView.builder.
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  // Espace horizontal entre deux elements.
  final double spacing;

  const HorizontalStrip({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 10,
  });

  @override
  State<HorizontalStrip> createState() => _HorizontalStripState();
}

class _HorizontalStripState extends State<HorizontalStrip> {
  // Le Scrollbar et le ListView doivent partager le MEME controleur :
  // c'est lui qui dit a la barre ou en est la liste. Sans controleur
  // explicite, thumbVisibility: true leve une assertion.
  final _controller = ScrollController();

  // Epaisseur reservee sous les cartes pour la barre, afin qu'elle ne
  // recouvre jamais le bas d'une vignette (le libelle y est ecrit).
  static const double _barArea = 14;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // Molette -> defilement horizontal
  // -----------------------------------------------------------
  // Un PointerScrollEvent porte un delta (dx, dy). Une souris
  // classique n'envoie que dy ; un trackpad peut envoyer dx. On
  // additionne les deux pour couvrir les deux cas.
  //
  // pointerSignalResolver : plusieurs widgets imbriques (notre bandeau
  // ET la page verticale qui le contient) recoivent le meme evenement.
  // Le resolver garantit qu'UN SEUL le traite : celui qui s'enregistre.
  // On ne s'enregistre donc que si on peut reellement bouger ; sinon
  // la page parente le prend, et la molette continue de faire
  // defiler la page normalement.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final delta = event.scrollDelta.dy + event.scrollDelta.dx;
    if (delta == 0) return;
    final canMove = delta > 0
        ? pos.pixels < pos.maxScrollExtent
        : pos.pixels > pos.minScrollExtent;
    if (!canMove) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final target = (pos.pixels + delta)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      _controller.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height + _barArea,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        // On elargit les peripheriques autorises a GLISSER, uniquement
        // pour ce sous-arbre. Par defaut Flutter web exclut la souris.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: Scrollbar(
            controller: _controller,
            // Toujours visible : la presence de la barre EST
            // l'information "il y a d'autres cartes plus loin".
            thumbVisibility: true,
            trackVisibility: true,
            // La barre est attrapable a la souris, comme partout.
            interactive: true,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: _barArea),
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
              itemBuilder: widget.itemBuilder,
            ),
          ),
        ),
      ),
    );
  }
}
