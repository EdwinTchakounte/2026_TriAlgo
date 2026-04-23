// =============================================================
// FICHIER : lib/presentation/wireframes/widgets/game/game_painters.dart
// ROLE   : Painters et particule utilises par la page de jeu
// COUCHE : Presentation > Wireframes > Widgets
// =============================================================
//
// Regroupe :
//   - GameParticle : structure d'une particule flottante
//   - GameParticlePainter : dessine les particules sur le canvas
//   - CardBackPatternPainter : motif "dos de carte" losanges
//
// Extrait de t_game_page.dart pour reduire la taille du fichier
// principal et permettre de tester les painters en isolation.
// =============================================================

import 'package:flutter/material.dart';

// =================================================================
// GameParticle — structure d'une particule flottante du fond
// =================================================================

/// Particule individuelle utilisee pour l'effet de poussiere
/// lumineuse en arriere-plan de la page de jeu.
class GameParticle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  Color color;

  /// Phase du mouvement sinusoidal lateral.
  double wobble;

  GameParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.color,
    required this.wobble,
  });
}

// =================================================================
// GameParticlePainter — dessine les particules
// =================================================================

/// Dessine une liste de particules flottantes avec flou gaussien.
///
/// Le [repaintNotifier] (AnimationController du state) declenche un
/// repaint a chaque tick pour animer les particules.
class GameParticlePainter extends CustomPainter {
  final List<GameParticle> particles;

  GameParticlePainter({
    required this.particles,
    required Listenable repaintNotifier,
  }) : super(repaint: repaintNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GameParticlePainter oldDelegate) => true;
  // Les particules bougent a chaque frame.
}

// =================================================================
// CardBackPatternPainter — motif dos de carte
// =================================================================

/// Motif decoratif de losanges en filigrane, utilise pour le dos
/// des cartes masquees dans le jeu.
class CardBackPatternPainter extends CustomPainter {
  const CardBackPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 16.0;
    const diamondSize = 5.0;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        final path = Path()
          ..moveTo(x, y - diamondSize)
          ..lineTo(x + diamondSize, y)
          ..lineTo(x, y + diamondSize)
          ..lineTo(x - diamondSize, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
