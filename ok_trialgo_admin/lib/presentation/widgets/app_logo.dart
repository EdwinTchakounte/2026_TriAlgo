// =============================================================
// FICHIER : app_logo.dart
// ROLE    : Widget reutilisable d'affichage du logo TRIALGO
// =============================================================
//
// Le logo (assets/images/logo.jpeg) est un visuel "fond noir +
// halo bleu/orange" qui matche le theme studio sombre. On
// l'expose ici en widget unique pour deux raisons :
//   1. Cohrence : meme rendu partout (Hub, Wizard, Step 1, etc.)
//   2. Maintenance : changer le fichier ou ajuster le glow ne
//      necessite qu'une seule edition.
//
// Trois tailles preconfigurees (compact / medium / hero) +
// option `glow` qui ajoute un halo brand autour. Le glow est
// surtout utile pour l'empty state (logo en hero) ; il est
// rarement souhaitable sur un AppBar (trop bruite).
// =============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppLogoSize { compact, medium, hero }

class AppLogo extends StatelessWidget {
  // Taille predefinie : compact = AppBar, medium = bandeau,
  // hero = empty state. Permet d'eviter les "magic numbers"
  // dans les pages.
  final AppLogoSize size;
  // Halo brand autour du logo. Off par defaut (eviter le bruit).
  final bool glow;
  // Coins arrondis : si null, on garde le ratio du logo brut
  // (qui a deja un fond noir, donc les coins sont noirs aussi).
  // Mettre un radius = arrondir + clip.
  final double? radius;

  const AppLogo({
    super.key,
    this.size = AppLogoSize.medium,
    this.glow = false,
    this.radius,
  });

  // Resolution taille -> dimensions concretes en pixels logiques.
  // On garde le ratio natif du logo (768x432 ~ 16:9), donc on
  // fixe la HAUTEUR et la largeur suit.
  double get _height {
    switch (size) {
      case AppLogoSize.compact:
        return 34;
      case AppLogoSize.medium:
        return 72;
      case AppLogoSize.hero:
        return 130;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Conteneur principal : on calcule la largeur via le ratio
    // 16:9 (largeur = hauteur * 16/9).
    final h = _height;
    final w = h * 16 / 9;

    // PNG transparent (fond noir retire en pre-traitement PIL,
    // voir docs/make_logo_transparent.py). Du coup pas besoin de
    // clip arrondi : la transparence se fond avec n'importe quel
    // fond (canvas anthracite, surface, surface2...).
    Widget img = Image.asset(
      'assets/images/logo.png',
      height: h,
      width: w,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    // Glow optionnel : halo rond brand derriere le logo. Comme le
    // logo n'a plus de fond rectangulaire, on pose le glow sur un
    // SizedBox carre derriere pour qu'il soit visible meme apres
    // detourage. radius (parametre) sert juste a moduler la forme
    // du glow (cercle plein si null, arrondi sinon).
    if (glow) {
      img = Container(
        decoration: BoxDecoration(
          borderRadius: radius != null
              ? BorderRadius.circular(radius!)
              : BorderRadius.circular(h / 2),
          boxShadow: AppColors.glow(
            AppColors.brand,
            strength: size == AppLogoSize.compact ? 0.4 : 0.8,
          ),
        ),
        child: img,
      );
    }

    return img;
  }
}
