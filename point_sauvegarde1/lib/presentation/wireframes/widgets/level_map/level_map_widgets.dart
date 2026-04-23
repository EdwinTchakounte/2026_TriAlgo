// =============================================================
// FICHIER : lib/presentation/wireframes/widgets/level_map/level_map_widgets.dart
// ROLE   : Widgets premium de la carte des niveaux, extraits pour
//          la lisibilite et la reutilisation.
// COUCHE : Presentation > Wireframes > Widgets
// =============================================================
//
// Regroupe :
//   - LevelMapTierHeader : entete d'un pallier (distance D1..D5)
//   - LevelMapLevelCard  : carte cliquable d'un niveau individuel
//   - LevelMapLevelIcon  : cercle avec numero de niveau
//   - LevelMapTag        : pilule distance/config
//
// Les widgets sont stateless et recoivent toutes leurs donnees via
// leurs parametres (y compris l'animation de pulse pour le niveau
// actif). C'est plus testable qu'un rendu base sur `Map<String,
// dynamic>`.
// =============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================
// LevelMapTierHeader
// =============================================================

/// Entete visuelle d'un pallier (D1..D5) regroupant les niveaux.
class LevelMapTierHeader extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final IconData icon;
  final int totalLevels;
  final int completedLevels;
  final bool isActive;
  final bool unlocked;
  final bool isFirst;

  const LevelMapTierHeader({
    super.key,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.totalLevels,
    required this.completedLevels,
    required this.isActive,
    required this.unlocked,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalLevels == 0 ? 0.0 : completedLevels / totalLevels;

    return Padding(
      // Espacement plus grand au-dessus pour separer visuellement
      // les palliers, sauf pour le premier qui colle au header.
      padding: EdgeInsets.only(top: isFirst ? 6 : 22, bottom: 10),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withValues(alpha: isActive ? 0.18 : 0.08),
                color.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isActive ? 0.45 : 0.18),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.5),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.exo2(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$completedLevels/$totalLevels',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Mini barre de progression du pallier.
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: constraints.maxWidth * ratio,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withValues(alpha: 0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// LevelMapLevelCard
// =============================================================

/// Carte d'un niveau individuel dans la liste.
///
/// Trois etats visuels : en cours, complete, verrouille. Le niveau
/// en cours utilise [pulseAnim] pour animer le bouton play.
class LevelMapLevelCard extends StatelessWidget {
  final int lvNum;
  final String lvLabel;
  final String distance;
  final String configs;
  final bool unlocked;
  final bool isCompleted;
  final int stars;
  final String levelWord;
  final Animation<double> pulseAnim;
  final VoidCallback? onTap;

  const LevelMapLevelCard({
    super.key,
    required this.lvNum,
    required this.lvLabel,
    required this.distance,
    required this.configs,
    required this.unlocked,
    required this.isCompleted,
    required this.stars,
    required this.levelWord,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = unlocked && !isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isCurrent
                  ? [
                      const Color(0xFFFF6B35).withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.03),
                    ]
                  : isCompleted
                      ? [
                          Colors.white.withValues(alpha: 0.04),
                          Colors.white.withValues(alpha: 0.02),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.02),
                          Colors.white.withValues(alpha: 0.01),
                        ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xFFFF6B35).withValues(alpha: 0.4)
                  : isCompleted
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.04),
              width: isCurrent ? 1.5 : 1,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Opacity(
            opacity: unlocked ? 1.0 : 0.4,
            child: Row(
              children: [
                LevelMapLevelIcon(
                  lvNum: lvNum,
                  isCurrent: isCurrent,
                  isCompleted: isCompleted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$levelWord $lvNum \u00b7 $lvLabel',
                        style: GoogleFonts.rajdhani(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: unlocked ? Colors.white : Colors.white30,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          LevelMapTag(
                            text: distance,
                            color: const Color(0xFF42A5F5),
                            active: unlocked,
                          ),
                          const SizedBox(width: 6),
                          LevelMapTag(
                            text: configs,
                            color: const Color(0xFFF7C948),
                            active: unlocked,
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            ...List.generate(3, (i) => Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                i < stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: i < stars
                                    ? const Color(0xFFF7C948)
                                    : Colors.white.withValues(alpha: 0.1),
                                size: 14,
                              ),
                            )),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  AnimatedBuilder(
                    animation: pulseAnim,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: pulseAnim.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B35)
                                .withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                else if (!unlocked)
                  Icon(
                    Icons.lock_rounded,
                    color: Colors.white.withValues(alpha: 0.12),
                    size: 18,
                  )
                else
                  Icon(
                    Icons.check_circle_rounded,
                    color: const Color(0xFFF7C948).withValues(alpha: 0.4),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// LevelMapLevelIcon
// =============================================================

/// Cercle avec le numero du niveau, stylise selon l'etat.
class LevelMapLevelIcon extends StatelessWidget {
  final int lvNum;
  final bool isCurrent;
  final bool isCompleted;

  const LevelMapLevelIcon({
    super.key,
    required this.lvNum,
    required this.isCurrent,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isCurrent
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
              )
            : isCompleted
                ? LinearGradient(
                    colors: [
                      const Color(0xFFF7C948).withValues(alpha: 0.2),
                      const Color(0xFFF7C948).withValues(alpha: 0.08),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
        border: isCurrent
            ? null
            : Border.all(
                color: isCompleted
                    ? const Color(0xFFF7C948).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
              ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '$lvNum',
          style: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isCurrent
                ? Colors.white
                : isCompleted
                    ? const Color(0xFFF7C948)
                    : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// LevelMapTag
// =============================================================

/// Petite pilule coloree affichant un tag (distance ou config).
class LevelMapTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool active;

  const LevelMapTag({
    super.key,
    required this.text,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (active ? color : Colors.white24).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (active ? color : Colors.white12).withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.exo2(
          fontSize: 10,
          color: active ? color : Colors.white30,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
