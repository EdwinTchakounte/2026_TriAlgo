// =============================================================
// FICHIER : lib/presentation/widgets/core/page_scaffold.dart
// ROLE   : Scaffold standardise pour toutes les pages TRIALGO
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// POURQUOI CE WIDGET ?
// --------------------
// Toutes les pages repetaient la meme structure :
//   Scaffold(
//     backgroundColor: ...,
//     body: Container(
//       decoration: BoxDecoration(gradient: TTheme.bgGradient),
//       child: SafeArea(
//         child: ...
//       )
//     )
//   )
//
// Avec souvent des variantes non intentionnelles (alignment topLeft
// vs topCenter, couleurs differentes, etc.).
//
// PageScaffold unifie le comportement :
//   - Background = gradient selon theme (dark: violet/bleu, light: lavande)
//   - SafeArea automatique
//   - Header optionnel (titre + back + actions)
//   - Body passe en child
//
// USAGE :
// -------
// PageScaffold(
//   title: 'Mode Collectif',
//   showBack: true,
//   child: Padding(
//     padding: const EdgeInsets.all(TSpacing.xxl),
//     child: Column(children: [...]),
//   ),
// )
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/brand.dart';
import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Scaffold standardise de TRIALGO (gradient fond + SafeArea + header).
class PageScaffold extends StatelessWidget {

  /// Contenu principal de la page.
  /// Non encapsule dans un Padding : l'appelant decide.
  final Widget child;

  /// Titre du header. Si null, aucun header n'est affiche.
  final String? title;

  /// Affiche le bouton back dans le header.
  /// Par defaut true si un titre est fourni.
  final bool showBack;

  /// Widgets additionnels a droite du header (icones, actions).
  /// Affiches uniquement si [title] est fourni.
  final List<Widget>? actions;

  /// Override du gradient de fond. Null = gradient par defaut du theme.
  /// Utile pour des pages speciales (splash par exemple).
  final Gradient? backgroundGradient;

  /// Si true, pose un SafeArea autour du child.
  /// Mettre false si la page gere elle-meme l'espace systeme
  /// (ex: une page plein ecran avec scanner QR).
  final bool safeArea;

  const PageScaffold({
    super.key,
    required this.child,
    this.title,
    this.showBack = true,
    this.actions,
    this.backgroundGradient,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    // Selection du gradient selon le theme en cours.
    // Theme.of(context).brightness est rempli automatiquement par
    // MaterialApp selon themeMode (dark / light / system).
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = backgroundGradient ??
        (isDark ? TBrand.bgDark : TBrand.bgLight);

    // --- Assemblage du contenu ---
    // On construit DANS CET ORDRE :
    //   1. child (le corps passe par l'appelant)
    //   2. si title : on ajoute un header au-dessus via Column
    //   3. puis on wrap dans SafeArea (pour que header ET content
    //      soient protegees des encoches / status bar)
    //
    // L'ancien code mettait SafeArea AVANT d'ajouter le header, ce
    // qui laissait le header passer sous la status bar. BUG CORRIGE.
    Widget content = child;

    if (title != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            title: title!,
            showBack: showBack,
            actions: actions,
          ),
          Expanded(child: content),
        ],
      );
    }

    if (safeArea) content = SafeArea(child: content);

    // Couleur de fallback : si le gradient a un bord transparent (cas
    // theorique) on veut au moins une couleur coherente avec le theme.
    final fallbackBg =
        isDark ? TSurfaceColors.darkBgBase : TSurfaceColors.lightBgBase;

    return Scaffold(
      // Fallback solide = meme teinte que le bgBase du theme.
      // Evite le "rectangle noir" quand le Container gradient ne
      // couvre pas parfaitement tout l'espace disponible.
      backgroundColor: fallbackBg,
      // SizedBox.expand force le Container a occuper 100% du body
      // (width + height). Sans ca, le Container prenait parfois la
      // taille naturelle du child et laissait une zone non-peinte.
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: content,
        ),
      ),
    );
  }
}


// =============================================================
// WIDGET : _PageHeader
// =============================================================
// Header custom rendu uniquement si [title] est fourni.
// Compose : [back] [title] ...[actions] .
//
// Hauteur fixe de kToolbarHeight (56) pour rester predictable.
// =============================================================

class _PageHeader extends StatelessWidget {

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  const _PageHeader({
    required this.title,
    required this.showBack,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);

    return SizedBox(
      height: kToolbarHeight,
      child: Row(
        children: [
          // --- Bouton back ou espacement equivalent ---
          // On garde toujours un padding gauche pour aligner le
          // titre meme quand le back est absent.
          if (showBack && Navigator.of(context).canPop())
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Retour',
            )
          else
            const SizedBox(width: TSpacing.xxl),

          // --- Titre ---
          Expanded(
            child: Text(
              title,
              style: TTypography.headlineMd(color: colors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // --- Actions ---
          // Row pour grouper les icones a droite. Mini-padding a droite
          // pour ne pas coller au bord physique.
          if (actions != null && actions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: TSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              ),
            )
          else
            const SizedBox(width: TSpacing.sm),
        ],
      ),
    );
  }
}
