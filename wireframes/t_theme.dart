// =============================================================
// FICHIER : lib/presentation/wireframes/t_theme.dart
// ROLE   : Theme visuel centralisé du wireframe TRIALGO
// COUCHE : Presentation > Wireframes
// =============================================================
//
// CE FICHIER CENTRALISE :
// -----------------------
// - La police gaming (Rajdhani) pour les titres et accents
// - La police body (Exo 2) pour le texte courant
// - Les couleurs recurrentes du jeu
// - Les degrades recurrents
// - Les styles de texte pre-configures
//
// Rajdhani : police geometrique, angulaire, style sci-fi.
//   Utilisee dans : Cyberpunk 2077, No Man's Sky, jeux futuristes.
//   Disponible via Google Fonts, poids : 300-700.
//
// Exo 2 : police moderne, lisible, avec une touche tech.
//   Utilisee pour le texte courant (descriptions, labels).
// =============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme visuel centralisé de TRIALGO.
///
/// Utilise les polices Rajdhani (titres gaming) et Exo 2 (body).
/// Fournit des methodes pour creer des TextStyles coherents
/// dans tout le wireframe.
class TTheme {
  // ---------------------------------------------------------------
  // COULEURS PRINCIPALES
  // ---------------------------------------------------------------

  /// Orange principal TRIALGO (boutons, accents).
  static const Color orange = Color(0xFFFF6B35);

  /// Jaune dore TRIALGO (etoiles, scores).
  static const Color gold = Color(0xFFF7C948);

  /// Bleu (emettrices, infos).
  static const Color blue = Color(0xFF42A5F5);

  /// Vert (receptrices, succes).
  static const Color green = Color(0xFF66BB6A);

  /// Rouge (vies, erreurs).
  static const Color red = Color(0xFFEF5350);

  /// Violet profond (backgrounds).
  static const Color bgDark = Color(0xFF0A0A1A);
  static const Color bgMid = Color(0xFF12122A);
  static const Color bgLight = Color(0xFF1A1A3E);

  // ---------------------------------------------------------------
  // DEGRADES RECURRENTS
  // ---------------------------------------------------------------

  /// Degrade de fond principal (vertical, 3 couleurs).
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDark, bgMid, bgLight],
  );

  /// Degrade orange->jaune pour les boutons hero.
  static const LinearGradient accentGradient = LinearGradient(
    colors: [orange, Color(0xFFFF8F5E), gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------------------------------------------------------------
  // POLICES GAMING
  // ---------------------------------------------------------------
  //
  // "GoogleFonts.rajdhani" : retourne un TextStyle avec la police
  // Rajdhani appliquee. La police est telechargee au premier usage
  // puis mise en cache localement.
  //
  // Si pas de reseau, google_fonts utilise la police par defaut
  // du systeme (fallback gracieux).
  // ---------------------------------------------------------------

  /// Style titre ENORME (logo, splash).
  /// Rajdhani 900, 48px, espacement large.
  static TextStyle logoStyle({Color color = Colors.white}) {
    return GoogleFonts.rajdhani(
      fontSize: 48,
      fontWeight: FontWeight.w900,
      color: color,
      letterSpacing: 8,
    );
  }

  /// Style titre principal (sections, pages).
  /// Rajdhani 800, 26px.
  static TextStyle titleStyle({Color color = Colors.white, double size = 26}) {
    return GoogleFonts.rajdhani(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
    );
  }

  /// Style sous-titre / label important.
  /// Rajdhani 700, 16px.
  static TextStyle subtitleStyle({Color color = Colors.white, double size = 16}) {
    return GoogleFonts.rajdhani(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }

  /// Style bouton texte.
  /// Rajdhani 700, 16px, lettrage large.
  static TextStyle buttonStyle({double size = 16}) {
    return GoogleFonts.rajdhani(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 2,
    );
  }

  /// Style body / texte courant.
  /// Exo 2, poids et taille configurables.
  static TextStyle bodyStyle({
    Color? color,
    double size = 14,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.exo2(
      fontSize: size,
      fontWeight: weight,
      color: color ?? Colors.white.withValues(alpha: 0.6),
    );
  }

  /// Style score / chiffres.
  /// Rajdhani bold pour les valeurs numeriques.
  static TextStyle scoreStyle({Color color = Colors.white, double size = 18}) {
    return GoogleFonts.rajdhani(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
    );
  }

  /// Style tag / badge petit texte.
  static TextStyle tagStyle({required Color color, double size = 11}) {
    return GoogleFonts.exo2(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
    );
  }

  /// Style micro label (10px, discret).
  static TextStyle microStyle({double alpha = 0.3}) {
    return GoogleFonts.exo2(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Colors.white.withValues(alpha: alpha),
      letterSpacing: 1.5,
    );
  }

  // ---------------------------------------------------------------
  // THEME MATERIAL COMPLET
  // ---------------------------------------------------------------

  /// Theme MaterialApp sombre unique.
  static ThemeData get themeData {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: orange,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      textTheme: GoogleFonts.exo2TextTheme(ThemeData.dark().textTheme),
    );
  }

  // ---------------------------------------------------------------
  // FOND PATTERN CARREAUX (style WhatsApp)
  // ---------------------------------------------------------------
  //
  // Widget reutilisable qui superpose :
  //   1. Le degrade de fond habituel (bgGradient)
  //   2. Un pattern de petits carreaux/icones subtils par-dessus
  //
  // L'opacite est tres faible (0.03-0.04) pour rester discret
  // tout en ajoutant de la texture au fond.
  //
  // USAGE :
  //   TTheme.patterned(child: SafeArea(child: ...))
  //
  // Remplace :
  //   Container(decoration: BoxDecoration(gradient: TTheme.bgGradient))
  // ---------------------------------------------------------------

  /// Fond avec degrade + motif de carreaux subtils.
  ///
  /// Emballe [child] dans un Container avec le degrade standard
  /// et un CustomPaint qui dessine le motif par-dessus.
  ///
  /// Utilise sur toutes les pages internes de l'application
  /// (pas sur splash ni auth qui ont leur propre fond).
  static Widget patterned({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(gradient: bgGradient),
      child: CustomPaint(
        painter: _PatternPainter(),
        child: child,
      ),
    );
  }
}

// =============================================================
// PAINTER : Motif de carreaux style WhatsApp
// =============================================================
//
// Dessine une grille de petites icones/formes geometriques
// en arriere-plan avec une opacite tres faible.
//
// Le motif inclut :
//   - Petits carres avec coins arrondis
//   - Petits losanges
//   - Petits cercles
//   - Mini-icones E/C/R (rappel du jeu)
//
// Le tout forme un tissu visuel subtil qui personnalise
// le fond sans distraire du contenu.
// =============================================================

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // --- Parametre du motif ---
    const double cellSize = 32;      // Taille d'une cellule de la grille.
    const double iconSize = 8;       // Taille des petites formes.
    final baseAlpha = 0.035;         // Opacite tres faible.

    // Couleurs alternees pour varier le motif.
    final colors = [
      Colors.white.withValues(alpha: baseAlpha),
      Colors.white.withValues(alpha: baseAlpha * 0.7),
      Colors.white.withValues(alpha: baseAlpha * 1.2),
    ];

    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.6;

    int index = 0;

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        paint.color = colors[index % colors.length];

        // Alterner entre differentes formes selon la position.
        final shape = index % 5;

        switch (shape) {
          case 0:
            // Petit carre avec coins arrondis.
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset(x + cellSize / 2, y + cellSize / 2),
                  width: iconSize,
                  height: iconSize,
                ),
                const Radius.circular(2),
              ),
              paint,
            );
          case 1:
            // Losange (carre tourne a 45 degres).
            final center = Offset(x + cellSize / 2, y + cellSize / 2);
            final half = iconSize / 2;
            final path = Path()
              ..moveTo(center.dx, center.dy - half)
              ..lineTo(center.dx + half, center.dy)
              ..lineTo(center.dx, center.dy + half)
              ..lineTo(center.dx - half, center.dy)
              ..close();
            canvas.drawPath(path, paint);
          case 2:
            // Petit cercle.
            canvas.drawCircle(
              Offset(x + cellSize / 2, y + cellSize / 2),
              iconSize / 2,
              paint,
            );
          case 3:
            // Petit triangle (rappel du logo).
            final center = Offset(x + cellSize / 2, y + cellSize / 2);
            final half = iconSize / 2;
            final path = Path()
              ..moveTo(center.dx, center.dy - half)
              ..lineTo(center.dx + half, center.dy + half)
              ..lineTo(center.dx - half, center.dy + half)
              ..close();
            canvas.drawPath(path, paint);
          case 4:
            // Croix fine (+).
            final center = Offset(x + cellSize / 2, y + cellSize / 2);
            final half = iconSize / 2;
            canvas.drawLine(
              Offset(center.dx - half, center.dy),
              Offset(center.dx + half, center.dy),
              paint,
            );
            canvas.drawLine(
              Offset(center.dx, center.dy - half),
              Offset(center.dx, center.dy + half),
              paint,
            );
        }

        index++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  // "false" : le motif ne change jamais, pas besoin de repeindre.
}
