// =============================================================
// FICHIER : lib/presentation/wireframes/widgets/home/home_painters.dart
// ROLE   : Custom painters partages par la home page premium
// COUCHE : Presentation > Wireframes > Widgets
// =============================================================
//
// Regroupe les CustomPainter utilises sur la home :
//   - CardSymbolsPainter  : motif anime de symboles de cartes en fond
//   - LightRaysPainter    : rayons lumineux radiaux derriere le hero
//   - MiniCardPatternPainter : motif dos de carte (losanges) pour les
//     mini-cartes (stats, nav, deck banner)
//   - XpRingPainter       : arc circulaire XP autour de l'avatar
//
// Extrait de t_home_page.dart lors du refacto de mise en production
// pour reduire la taille du fichier principal et permettre la
// reutilisation des motifs "dos de carte" dans d'autres widgets.
// =============================================================

import 'dart:math';

import 'package:flutter/material.dart';

// =================================================================
// CardSymbolsPainter
// =================================================================
// Dessine un motif de grille de symboles de cartes (losanges,
// cercles, croix) a tres faible opacite sur l'ensemble de l'ecran.
// Les symboles oscillent verticalement pour un effet de flottement.
//
// Le `Listenable animation` est passe au constructeur pour que le
// painter se repaint automatiquement a chaque tick du controller.
// =================================================================

class CardSymbolsPainter extends CustomPainter {
  /// Animation de la home (float controller) a laquelle se lier
  /// pour declencher un repaint a chaque tick.
  final Listenable animation;

  /// Taille d'une cellule de la grille (en pixels).
  static const double _cellSize = 48;

  /// Taille des symboles individuels.
  static const double _symbolSize = 10;

  CardSymbolsPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Pinceau pour dessiner les symboles en mode "stroke" (contour seul).
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Valeur de temps pour l'oscillation (0.0 -> 1.0 sur 3 secondes
    // via le float controller), convertie en radians.
    final t = (animation as Animation<double>).value * 2 * pi;

    int index = 0;

    // Parcours de la grille cellule par cellule.
    for (double y = 0; y < size.height; y += _cellSize) {
      for (double x = 0; x < size.width; x += _cellSize) {
        // Opacite tres faible (3-4%) pour rester subtil.
        final alpha = 0.03 + 0.01 * sin(index * 0.7);
        paint.color = Colors.white.withValues(alpha: alpha);

        // Oscillation verticale individuelle : chaque symbole bouge
        // legerement en Y avec une phase differente.
        final yOffset = sin(t + index * 0.5) * 1.5;

        final cx = x + _cellSize / 2;
        final cy = y + _cellSize / 2 + yOffset;

        // Alternance entre les 3 types de symboles selon la position.
        final shape = index % 3;
        final half = _symbolSize / 2;

        switch (shape) {
          case 0:
            // LOSANGE : represente l'Emettrice (E).
            final path = Path()
              ..moveTo(cx, cy - half)
              ..lineTo(cx + half, cy)
              ..lineTo(cx, cy + half)
              ..lineTo(cx - half, cy)
              ..close();
            canvas.drawPath(path, paint);
          case 1:
            // CERCLE : represente le Cable (C).
            canvas.drawCircle(Offset(cx, cy), half, paint);
          case 2:
            // CROIX (+) : represente la Receptrice (R).
            canvas.drawLine(
              Offset(cx - half, cy),
              Offset(cx + half, cy),
              paint,
            );
            canvas.drawLine(
              Offset(cx, cy - half),
              Offset(cx, cy + half),
              paint,
            );
        }

        index++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CardSymbolsPainter oldDelegate) => false;
  // Le repaint est gere par `super(repaint: animation)`.
}

// =================================================================
// LightRaysPainter
// =================================================================
// Dessine 8 rayons triangulaires fins emanant du centre. Utilise
// derriere la carte hero pour un effet "halo legendaire".
//
// La rotation est geree par le parent (Transform.rotate avec un
// AnimationController), pas par le painter lui-meme.
// =================================================================

class LightRaysPainter extends CustomPainter {
  /// Nombre de rayons a dessiner autour du centre.
  static const int _rayCount = 8;

  /// Demi-ouverture angulaire de chaque rayon (en radians).
  static const double _rayHalfAngle = 2 * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < _rayCount; i++) {
      final angle = (2 * pi / _rayCount) * i;
      final a1 = angle - _rayHalfAngle;
      final a2 = angle + _rayHalfAngle;

      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + radius * cos(a1), cy + radius * sin(a1))
        ..lineTo(cx + radius * cos(a2), cy + radius * sin(a2))
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =================================================================
// MiniCardPatternPainter
// =================================================================
// Dessine un motif repete de petits losanges en filigrane pour
// simuler le dos d'une carte a jouer. Reutilise dans toutes les
// mini-cartes de la home (stats, nav, deck banner, mystery card).
// =================================================================

class MiniCardPatternPainter extends CustomPainter {
  /// Couleur des losanges (opacite appliquee en interne).
  final Color color;

  const MiniCardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const spacing = 14.0;
    const diamondSize = 4.0;

    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
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
  bool shouldRepaint(covariant MiniCardPatternPainter old) =>
      old.color != color;
}

// =================================================================
// XpRingPainter
// =================================================================
// Dessine un arc circulaire avec une portion coloree proportionnelle
// a [progress] (0.0 a 1.0). Utilise pour le ring XP de l'avatar.
//
// Accepte soit une couleur unie soit un gradient sweep.
// L'arc commence a -pi/2 (haut) et tourne dans le sens horaire.
// =================================================================

class XpRingPainter extends CustomPainter {
  /// Pourcentage d'avancement (0.0 a 1.0).
  final double progress;

  /// Couleur unie (utilisee si [gradient] est null).
  final Color? color;

  /// Gradient a appliquer a l'arc (prioritaire sur [color]).
  final Gradient? gradient;

  /// Epaisseur du trait en pixels.
  final double strokeWidth;

  const XpRingPainter({
    required this.progress,
    this.color,
    this.gradient,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else if (color != null) {
      paint.color = color!;
    }

    canvas.drawArc(
      rect,
      -pi / 2,
      progress * 2 * pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant XpRingPainter old) =>
      old.progress != progress;
}
