// =============================================================
// FICHIER : lib/presentation/wireframes/t_illustrations.dart
// ROLE   : Illustrations vectorielles custom pour le wireframe
// COUCHE : Presentation > Wireframes
// =============================================================
//
// POURQUOI DES ILLUSTRATIONS CUSTOM ?
// -------------------------------------
// Au lieu d'utiliser des images rectangulaires (Image.asset),
// on cree des WIDGETS ILLUSTRES en pur Flutter :
//   - Pas de fichier image a charger (instantane)
//   - Redimensionnables sans perte de qualite
//   - Animes facilement
//   - Coherents avec le theme du jeu (couleurs, formes)
//
// DESIGN INSPIRE DE :
//   - Cards de jeu avec degrade et icones
//   - Geometric art abstrait (triangles, cercles, lignes)
//   - Neon glow effects (style cyberpunk gaming)
// =============================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Collection d'illustrations custom pour TRIALGO.
///
/// Chaque methode retourne un Widget auto-suffisant
/// qui ne depend d'aucune image externe.
class TIllustrations {

  // =============================================================
  // ILLUSTRATION 1 : Hero Banner (Home Page)
  // =============================================================
  // Grande banniere decorative avec :
  //   - 3 cartes stylisees E + C = R en perspective
  //   - Degrade vibrant en arriere-plan
  //   - Particules decoratives (cercles, lignes)
  //   - Logo TRIALGO integre
  // =============================================================

  /// Banniere hero pour la page d'accueil.
  ///
  /// Affiche le concept E + C = R sous forme de 3 cartes
  /// stylisees avec effets de profondeur et lumieres.
  static Widget heroBanner({double height = 140}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // --- Fond degrade ---
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A0F3C),
                    Color(0xFF2D1B69),
                    Color(0xFF0F2027),
                  ],
                ),
              ),
            ),

            // --- Grille decorative (lignes subtiles) ---
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter()),
            ),

            // --- Orbe lumineuse orange (haut droite) ---
            Positioned(
              top: -20, right: -10,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      TTheme.orange.withValues(alpha: 0.25),
                      TTheme.orange.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // --- Orbe lumineuse bleue (bas gauche) ---
            Positioned(
              bottom: -15, left: -15,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      TTheme.blue.withValues(alpha: 0.2),
                      TTheme.blue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),

            // --- Les 3 cartes E + C = R ---
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    // Texte a gauche.
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) => TTheme.accentGradient.createShader(b),
                            child: Text('TRIALGO', style: TTheme.titleStyle(size: 20)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'E + C = R',
                            style: TTheme.scoreStyle(
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Master the visual\ntransformations',
                            style: TTheme.bodyStyle(
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3 mini-cartes a droite (flexibles).
                    Expanded(
                      flex: 4,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Adapter la taille des cartes a l'espace disponible.
                          // Chaque carte = ~30% de la largeur, max 48px.
                          final cardW = (constraints.maxWidth * 0.28).clamp(32.0, 48.0);
                          final cardH = cardW * 1.3;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _miniCard('E', TTheme.blue, Icons.image_rounded, -6, cardW, cardH),
                              SizedBox(width: cardW * 0.06),
                              _miniCard('C', TTheme.orange, Icons.compare_arrows_rounded, 0, cardW, cardH),
                              SizedBox(width: cardW * 0.06),
                              _miniCard('R', TTheme.green, Icons.auto_awesome_rounded, 6, cardW, cardH),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mini-carte stylisee (E, C ou R) avec rotation subtile.
  static Widget _miniCard(String letter, Color color, IconData icon, double rotDeg, double w, double h) {
    return Transform.rotate(
      angle: rotDeg * pi / 180,
      child: Container(
        width: w, height: h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.25),
              color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: w * 0.38),
            SizedBox(height: w * 0.06),
            Container(
              padding: EdgeInsets.symmetric(horizontal: w * 0.12, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                letter,
                style: TTheme.scoreStyle(color: color, size: w * 0.22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // ILLUSTRATION 2 : Header Compact (Home Page header)
  // =============================================================
  // Remplace la mini-mascotte par un badge de jeu stylise.
  // =============================================================

  /// Badge de jeu compact pour le header.
  ///
  /// Hexagone avec icone et glow, remplace la mascotte.
  static Widget gameBadge({double size = 46}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A0F3C)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: TTheme.gold.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: TTheme.gold.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow interne.
          Container(
            width: size * 0.6, height: size * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  TTheme.orange.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Icone.
          Icon(Icons.extension_rounded, color: TTheme.gold, size: size * 0.45),
        ],
      ),
    );
  }

  // =============================================================
  // ILLUSTRATION 3 : Activation Key Visual
  // =============================================================
  // Illustration premium pour la page d'activation :
  //   - Cle stylisee avec particules
  //   - Anneau lumineux
  //   - Effet de scan/unlock
  // =============================================================

  /// Illustration de cle d'activation premium.
  static Widget activationVisual({double size = 160}) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- Anneau externe pulsant ---
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  TTheme.gold.withValues(alpha: 0.05),
                  TTheme.gold.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 0.75, 1.0],
              ),
            ),
          ),

          // --- Anneau intermediaire ---
          Container(
            width: size * 0.75, height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: TTheme.gold.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
          ),

          // --- Anneau interne ---
          Container(
            width: size * 0.55, height: size * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: TTheme.orange.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
          ),

          // --- Points cardinaux decoratifs ---
          ..._orbitalDots(size * 0.375, 8, TTheme.gold.withValues(alpha: 0.3)),

          // --- Centre : icone cle ---
          Container(
            width: size * 0.4, height: size * 0.4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TTheme.gold.withValues(alpha: 0.2),
                  TTheme.orange.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: TTheme.gold.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: TTheme.gold.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.vpn_key_rounded,
              size: size * 0.18,
              color: TTheme.gold,
            ),
          ),

          // --- Petites etoiles decoratives ---
          Positioned(
            top: size * 0.08, right: size * 0.15,
            child: Icon(Icons.auto_awesome, size: 12, color: TTheme.gold.withValues(alpha: 0.4)),
          ),
          Positioned(
            bottom: size * 0.12, left: size * 0.1,
            child: Icon(Icons.auto_awesome, size: 10, color: TTheme.orange.withValues(alpha: 0.3)),
          ),
          Positioned(
            top: size * 0.25, left: size * 0.08,
            child: Icon(Icons.auto_awesome, size: 8, color: TTheme.blue.withValues(alpha: 0.25)),
          ),
        ],
      ),
    );
  }

  /// Cree des points en orbite autour d'un centre.
  static List<Widget> _orbitalDots(double radius, int count, Color color) {
    return List.generate(count, (i) {
      final angle = (2 * pi / count) * i;
      return Positioned(
        left: radius + radius * cos(angle) - 2.5,
        top: radius + radius * sin(angle) - 2.5,
        child: Container(
          width: 5, height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i % 2 == 0 ? color : color.withValues(alpha: 0.15),
          ),
        ),
      );
    });
  }

  // =============================================================
  // ILLUSTRATION 4 : Splash Logo
  // =============================================================
  // Logo premium anime pour le splash screen :
  //   - 3 cartes E/C/R en cercle
  //   - Anneaux lumineux
  //   - Design futuriste
  // =============================================================

  /// Logo premium pour le splash screen.
  static Widget splashLogo({double size = 180}) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- Anneau externe degrade ---
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  TTheme.orange.withValues(alpha: 0.3),
                  TTheme.gold.withValues(alpha: 0.1),
                  TTheme.blue.withValues(alpha: 0.2),
                  TTheme.green.withValues(alpha: 0.1),
                  TTheme.orange.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),

          // --- Masque central (trou) ---
          Container(
            width: size * 0.88, height: size * 0.88,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: TTheme.bgDark,
            ),
          ),

          // --- Les 3 cartes en triangle ---
          // E en haut.
          Positioned(
            top: size * 0.08,
            child: _splashCard('E', TTheme.blue, Icons.image_rounded),
          ),
          // C en bas gauche.
          Positioned(
            bottom: size * 0.12, left: size * 0.08,
            child: _splashCard('C', TTheme.orange, Icons.compare_arrows_rounded),
          ),
          // R en bas droite.
          Positioned(
            bottom: size * 0.12, right: size * 0.08,
            child: _splashCard('R', TTheme.green, Icons.auto_awesome_rounded),
          ),

          // --- Centre : logo ---
          Container(
            width: size * 0.28, height: size * 0.28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [TTheme.orange.withValues(alpha: 0.15), TTheme.gold.withValues(alpha: 0.08)],
              ),
              border: Border.all(color: TTheme.orange.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.extension_rounded, color: TTheme.orange, size: size * 0.12),
          ),

          // --- Lignes de connexion (decoratives) ---
          CustomPaint(
            size: Size(size, size),
            painter: _ConnectionPainter(),
          ),
        ],
      ),
    );
  }

  /// Petite carte pour le splash logo.
  static Widget _splashCard(String letter, Color color, IconData icon) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          Text(letter, style: TTheme.scoreStyle(color: color, size: 10)),
        ],
      ),
    );
  }

  // =============================================================
  // ILLUSTRATION 5 : Auth Header Visual
  // =============================================================
  // Design abstrait pour remplacer la mascotte sur l'ecran auth.
  // =============================================================

  /// Illustration abstraite pour l'ecran d'authentification.
  static Widget authVisual({double height = 160}) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cercles concentriques decoratifs.
          ...List.generate(3, (i) {
            final r = 50.0 + i * 28.0;
            return Container(
              width: r * 2, height: r * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: [TTheme.orange, TTheme.gold, TTheme.blue][i].withValues(alpha: 0.1 - i * 0.02),
                  width: 1,
                ),
              ),
            );
          }),
          // 3 cartes flottantes.
          Positioned(
            left: 20, top: 10,
            child: Transform.rotate(
              angle: -0.15,
              child: _authCard(TTheme.blue, Icons.image_rounded, 'E'),
            ),
          ),
          Positioned(
            right: 30, top: 5,
            child: Transform.rotate(
              angle: 0.1,
              child: _authCard(TTheme.green, Icons.auto_awesome_rounded, 'R'),
            ),
          ),
          // Centre : grande carte Cable.
          _authCard(TTheme.orange, Icons.compare_arrows_rounded, 'C', size: 56),
        ],
      ),
    );
  }

  /// Carte decorative pour l'ecran auth.
  static Widget _authCard(Color color, IconData icon, String letter, {double size = 44}) {
    return Container(
      width: size, height: size * 1.25,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: size * 0.38),
          const SizedBox(height: 2),
          Text(letter, style: TTheme.scoreStyle(color: color, size: size * 0.22)),
        ],
      ),
    );
  }
}

// =============================================================
// PAINTERS CUSTOM
// =============================================================

/// Peint une grille subtile en arriere-plan.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 0.5;

    // Lignes horizontales.
    for (var y = 0.0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Lignes verticales.
    for (var x = 0.0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Peint des lignes de connexion entre les 3 cartes du splash.
class _ConnectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final top = Offset(size.width / 2, size.height * 0.18);
    final bottomLeft = Offset(size.width * 0.18, size.height * 0.78);
    final bottomRight = Offset(size.width * 0.82, size.height * 0.78);

    // Triangle entre les 3 cartes.
    final path = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..close();

    canvas.drawPath(path, paint);

    // Lignes vers le centre.
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    canvas.drawLine(center, top, centerPaint);
    canvas.drawLine(center, bottomLeft, centerPaint);
    canvas.drawLine(center, bottomRight, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
