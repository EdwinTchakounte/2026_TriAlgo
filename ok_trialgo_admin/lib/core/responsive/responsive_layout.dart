// =============================================================
// FICHIER : responsive_layout.dart
// ROLE    : Widget conteneur qui adapte le contenu a la taille
// =============================================================
//
// On evite de re-coder partout "if width < 600 ... else ...".
// ResponsiveLayout centralise :
//   - le padding horizontal selon Breakpoints
//   - la largeur max du contenu (centre sur tablette)
//   - un scroll vertical par defaut
//
// Usage typique dans une page :
//   Scaffold(
//     body: ResponsiveLayout(child: Column(...)),
//   )
// =============================================================

import 'package:flutter/material.dart';

import 'breakpoints.dart';

class ResponsiveLayout extends StatelessWidget {
  // Le contenu a afficher. Souvent une Column ou un Form.
  final Widget child;
  // Si TRUE (defaut), enveloppe dans un SingleChildScrollView.
  // Si l'enfant gere deja son propre scroll (ex : GridView.builder),
  // mettre FALSE pour eviter le warning "nested scrollables".
  final bool scrollable;
  // Padding vertical haut/bas. Le horizontal est calcule via
  // Breakpoints, donc on le laisse parametrer ici seulement.
  final double verticalPadding;
  // Si on veut un fond different du Scaffold (ex : couleur brand
  // pour le splash). null = transparent.
  final Color? backgroundColor;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.scrollable = true,
    this.verticalPadding = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final horizontal = Breakpoints.horizontalPadding(context);
    final maxWidth = Breakpoints.maxContentWidth(context);

    // Le contenu centre sur tablette : on enveloppe dans un
    // ConstrainedBox avec maxWidth puis Center pour le centrer
    // horizontalement quand l'ecran est plus large que maxWidth.
    final inner = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: verticalPadding,
          ),
          child: child,
        ),
      ),
    );

    final body = scrollable
        ? SingleChildScrollView(child: inner)
        // Si non-scrollable, on respecte tout de meme le padding
        // mais on laisse l'enfant gerer son propre scroll/layout.
        : inner;

    if (backgroundColor != null) {
      return ColoredBox(color: backgroundColor!, child: body);
    }
    return body;
  }
}
