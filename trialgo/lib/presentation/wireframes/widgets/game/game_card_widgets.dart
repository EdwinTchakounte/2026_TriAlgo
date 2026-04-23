// =============================================================
// FICHIER : lib/presentation/wireframes/widgets/game/game_card_widgets.dart
// ROLE   : Widgets de cartes premium du jeu (trio + choix + operateur)
// COUCHE : Presentation > Wireframes > Widgets
// =============================================================
//
// Regroupe les widgets visuels utilises dans la page de jeu :
//   - GameOperatorBadge : losange dore avec un symbole (+ ou =)
//   - GameTrioCard      : carte du trio (E, C ou ? masquee)
//   - GameTrioCardFallback : fallback visible si l'image reseau echoue
//   - GameChoiceCard    : carte proposable dans la grille de choix
//   - GameChoiceCardFallback : fallback pour les cartes de choix
//
// Les widgets sont sans etat et recoivent animations et callbacks
// via leurs parametres. Cela facilite leur test et leur reutilisation
// hors de la page de jeu.
// =============================================================

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:trialgo/presentation/wireframes/widgets/game/game_painters.dart';

// =============================================================
// GameOperatorBadge
// =============================================================

/// Losange dore affichant un operateur (+, =) entre les cartes.
class GameOperatorBadge extends StatelessWidget {
  final String symbol;

  const GameOperatorBadge({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: pi / 4,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B35).withValues(alpha: 0.2),
              const Color(0xFFF7C948).withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFF7C948).withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: Transform.rotate(
            angle: -pi / 4,
            child: Text(
              symbol,
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFF7C948).withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// GameTrioCardFallback
// =============================================================

/// Fallback visuel pour les cartes du trio quand l'image reseau
/// ne charge pas : fond colore + grande lettre au centre.
class GameTrioCardFallback extends StatelessWidget {
  final String letter;
  final Color color;

  const GameTrioCardFallback({
    super.key,
    required this.letter,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.2),
            const Color(0xFF0D0D20),
          ],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.rajdhani(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: color.withValues(alpha: 0.7),
            shadows: [
              Shadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// GameTrioCard
// =============================================================

/// Carte du trio (E, C ou receptrice masquee) affichee en haut.
///
/// Les animations [pulseAnimation] (scale 1.0→1.02) et
/// [pulseController] (blur du glow) ne sont utilisees que lorsque
/// la carte est masquee. Le callback [onView] est invoque quand le
/// joueur tape sur une carte visible (ou revelee) pour la voir en
/// plein ecran.
class GameTrioCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final String label;
  final Color borderColor;
  final bool isMasked;
  final bool isRevealed;
  final Animation<double> pulseAnimation;
  final Animation<double> pulseController;
  final VoidCallback onView;

  const GameTrioCard({
    super.key,
    required this.card,
    required this.pulseAnimation,
    required this.pulseController,
    required this.onView,
    this.label = '',
    this.borderColor = Colors.white24,
    this.isMasked = false,
    this.isRevealed = false,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = card['imageUrl'] as String;

    Widget cardContent;

    if (isMasked) {
      cardContent = AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 80,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(
                    painter: CardBackPatternPainter(),
                  ),
                ),
                Center(
                  child: AnimatedBuilder(
                    animation: pulseController,
                    builder: (context, child) {
                      final glowBlur = 8.0 + (pulseController.value * 8.0);
                      return Text(
                        '?',
                        style: GoogleFonts.rajdhani(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF6B35),
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.6),
                              blurRadius: glowBlur,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.exo2(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.25),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final typeInitial = label.isNotEmpty ? label[0].toUpperCase() : '?';

      cardContent = Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (isRevealed ? const Color(0xFF66BB6A) : borderColor)
                  .withValues(alpha: 0.15),
              const Color(0xFF0D0D20),
              (isRevealed ? const Color(0xFF66BB6A) : borderColor)
                  .withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRevealed ? const Color(0xFF66BB6A) : borderColor,
            width: isRevealed ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            if (isRevealed)
              BoxShadow(
                color: const Color(0xFF66BB6A).withValues(alpha: 0.3),
                blurRadius: 14,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => GameTrioCardFallback(
                  letter: typeInitial,
                  color: borderColor,
                ),
                errorWidget: (context, error, stack) => GameTrioCardFallback(
                  letter: typeInitial,
                  color: borderColor,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.exo2(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 5, left: 7,
                child: Text(
                  typeInitial,
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: borderColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!isMasked || isRevealed) {
      cardContent = GestureDetector(
        onTap: onView,
        child: cardContent,
      );
    }

    return Column(
      children: [
        cardContent,
        const SizedBox(height: 4),
        Text(
          isMasked ? '?' : (card['label'] as String),
          style: GoogleFonts.exo2(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// GameChoiceCardFallback
// =============================================================

/// Fallback pour les cartes de choix : fond sombre + nom en grand.
class GameChoiceCardFallback extends StatelessWidget {
  final String label;

  const GameChoiceCardFallback({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1040),
            Color(0xFF0D0D20),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// GameChoiceCard
// =============================================================

/// Carte proposable dans la grille de choix du jeu.
///
/// [feedbackScale] : animation utilisee pour le badge check au
/// moment de la reponse. [onTap] declenche la selection (ignore si
/// null). [onView] ouvre la carte en plein ecran (double-tap).
class GameChoiceCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool isSelected;
  final bool isRevealed;
  final bool isWrong;
  final Animation<double> feedbackScale;
  final VoidCallback? onTap;
  final VoidCallback onView;

  const GameChoiceCard({
    super.key,
    required this.card,
    required this.isSelected,
    required this.isRevealed,
    required this.isWrong,
    required this.feedbackScale,
    required this.onView,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = card['imageUrl'] as String;
    final label = card['label'] as String;

    final Color borderColor;
    if (isRevealed) {
      borderColor = const Color(0xFF66BB6A);
    } else if (isWrong) {
      borderColor = const Color(0xFFEF5350);
    } else if (isSelected) {
      borderColor = const Color(0xFFF7C948);
    } else {
      borderColor = Colors.white.withValues(alpha: 0.1);
    }

    final borderWidth = (isRevealed || isWrong || isSelected) ? 2.0 : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                borderColor.withValues(alpha: 0.1),
                const Color(0xFF0D0D20),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
              if (isRevealed)
                BoxShadow(
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              if (isWrong)
                BoxShadow(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              if (isSelected && !isRevealed && !isWrong)
                BoxShadow(
                  color: const Color(0xFFF7C948).withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => GameChoiceCardFallback(label: label),
                  errorWidget: (context, error, stack) =>
                      GameChoiceCardFallback(label: label),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (isRevealed)
                  Positioned(
                    top: 4, right: 4,
                    child: ScaleTransition(
                      scale: feedbackScale,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF66BB6A),
                              Color(0xFF388E3C),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF66BB6A)
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ),
                if (isWrong)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEF5350),
                            Color(0xFFC62828),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF5350)
                                .withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
