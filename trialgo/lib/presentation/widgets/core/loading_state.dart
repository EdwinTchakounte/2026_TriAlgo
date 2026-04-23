// =============================================================
// FICHIER : lib/presentation/widgets/core/loading_state.dart
// ROLE   : Indicateur de chargement standardise (spinner + message)
// COUCHE : Presentation > Widgets > Core
// =============================================================
//
// TROIS VARIANTES :
// -----------------
// 1. LoadingState()         -> spinner centre plein ecran
// 2. LoadingState(message)  -> spinner + texte descriptif
// 3. Skeleton (widget      -> futurs placeholders shimmer pour
//     separe plus tard)      les cartes de contenu
//
// POURQUOI UN WIDGET DEDIE ?
// --------------------------
// CircularProgressIndicator brut est sec : aucun contexte, pas de
// message, aucune branding. Pour une app pro, on wrappe avec :
//   - Message explicite ("Chargement de la partie...")
//   - Couleur brand (primary)
//   - Taille coherente
//
// Cela evite le sentiment "l'app a freeze" quand une requete traine.
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';


/// Indicateur de chargement standardise.
class LoadingState extends StatelessWidget {

  /// Message affiche sous le spinner. Null = spinner seul.
  final String? message;

  /// Taille du spinner.
  final double size;

  /// Couleur du spinner. Defaut = primary.
  final Color? color;

  const LoadingState({
    super.key,
    this.message,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final spinnerColor = color ?? TColors.primary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Spinner ---
          // On utilise un CircularProgressIndicator standard dimensionne
          // via SizedBox pour controler precisement l'espace qu'il prend.
          // strokeWidth proportionnel a la taille pour rester propre.
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              color: spinnerColor,
              strokeWidth: size < 24 ? 2 : 3,
            ),
          ),

          // --- Message ---
          // Affiche en textSecondary pour rester discret par rapport
          // au spinner qui est la cible visuelle.
          if (message != null) ...[
            const SizedBox(height: TSpacing.lg),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TTypography.bodyMd(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}


// =============================================================
// WIDGET : SkeletonBox
// =============================================================
// Placeholder animé pour indiquer qu'un contenu va apparaitre.
// Plus moderne qu'un spinner pour les listes de cartes / leaderboard.
//
// Utilise dans des ListView.builder avec le meme format que la
// carte finale, pour que la transition soit quasi-invisible.
// =============================================================

/// Placeholder shimmer anime pour rectangles de contenu.
///
/// Usage :
/// ```dart
/// SkeletonBox(width: 200, height: 24)  // ligne de texte
/// SkeletonBox(height: 80)              // carte pleine largeur
/// ```
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}


class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {

  /// Controller du shimmer : tourne en boucle 1.2s.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Le gradient translate d'un cote a l'autre en boucle.
        // stops dynamique pour creer l'effet "wave" qui traverse.
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              colors: [
                colors.surface,
                colors.borderSubtle,
                colors.surface,
              ],
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}
