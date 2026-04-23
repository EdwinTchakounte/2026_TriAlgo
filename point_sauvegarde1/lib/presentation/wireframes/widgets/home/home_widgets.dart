// =============================================================
// FICHIER : lib/presentation/wireframes/widgets/home/home_widgets.dart
// ROLE   : Widgets premium de la home page, extraits pour la lisibilite
// COUCHE : Presentation > Wireframes > Widgets
// =============================================================
//
// Regroupe les widgets de la home qui ne dependent pas directement
// des AnimationControllers du _THomePageState :
//   - HomeQuickStats + HomeStatCard : 3 mini cartes de jeu pour les stats
//   - HomeNavGrid + HomeNavTile + HomeNavItem : grille 2x2 navigation
//   - HomeDeckBanner : banniere du deck actif en pile de cartes
//   - HomeInstructionGrid : 2 cellules "observer / zoom"
//   - HomeDecorativeLine : ligne decorative centree
//   - HomeAvatarXpRing : avatar + anneau XP + badge niveau
//
// Chaque widget est autonome et reutilisable. Ceux qui ont besoin
// des donnees du profil utilisent ConsumerWidget pour lire
// profileProvider directement plutot que recevoir les donnees en
// parametre, ce qui simplifie l'appelant.
//
// Extrait de t_home_page.dart lors du refacto de mise en production.
// =============================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/widgets/home/home_painters.dart';

// =============================================================
// HomeQuickStats — 3 mini cartes de jeu pour les stats
// =============================================================

/// Section des statistiques rapides sous forme de 3 mini cartes.
///
/// Lit le score, le niveau et la derniere session pour les afficher.
/// Chaque stat est rendue via [HomeStatCard].
class HomeQuickStats extends ConsumerWidget {
  const HomeQuickStats({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final level = profile.level;
    final score = profile.score;

    // MockData expose encore l'historique pour la demo : la valeur
    // affichee n'a pas d'impact fonctionnel, c'est un placeholder.
    final lastSession = MockData.mockSessionHistory[0];
    final lastCorrect = lastSession['correct'] as int;
    final lastTotal = lastCorrect + (lastSession['wrong'] as int);

    return Row(
      children: [
        Expanded(
          child: HomeStatCard(
            icon: Icons.star_rounded,
            color: TTheme.gold,
            value: '$score',
            label: 'POINTS',
            corner: '★',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HomeStatCard(
            icon: Icons.trending_up_rounded,
            color: TTheme.blue,
            value: 'N$level',
            label: 'NIVEAU',
            corner: '◆',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: HomeStatCard(
            icon: Icons.local_fire_department_rounded,
            color: TTheme.orange,
            value: '$lastCorrect/$lastTotal',
            label: 'DERNIER',
            corner: '♦',
          ),
        ),
      ],
    );
  }
}

/// Mini carte de jeu affichant une statistique unique.
///
/// Rendue avec coins decoratifs (rank-style), icone + valeur centrale,
/// motif dos de carte en filigrane et bordure coloree.
class HomeStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String corner;

  const HomeStatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.corner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            const Color(0xFF0D0D20),
            color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Motif dos de carte en filigrane.
            Positioned.fill(
              child: CustomPaint(
                painter: MiniCardPatternPainter(color: color),
              ),
            ),
            // Reflet superieur.
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Coins decoratifs.
            Positioned(
              top: 5,
              left: 7,
              child: Text(
                corner,
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ),
            Positioned(
              bottom: 5,
              right: 7,
              child: Transform.rotate(
                angle: pi,
                child: Text(
                  corner,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            // Contenu central.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: GoogleFonts.rajdhani(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                      shadows: [
                        Shadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: GoogleFonts.exo2(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            // Barre decorative basse.
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      color.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// HomeNavGrid — grille 2x2 de tuiles de navigation style carte
// =============================================================

/// Item de navigation pour la grille de la home.
class HomeNavItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const HomeNavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Grille 2x2 de 4 tuiles de navigation.
class HomeNavGrid extends StatelessWidget {
  final List<HomeNavItem> items;

  const HomeNavGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'HomeNavGrid attend exactement 4 items.');
    // Column utilise Expanded pour que les 2 rangees
    // se partagent l'espace vertical disponible.
    // Les tuiles s'adaptent donc a la hauteur du parent.
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: HomeNavTile(item: items[0])),
              const SizedBox(width: 8),
              Expanded(child: HomeNavTile(item: items[1])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(child: HomeNavTile(item: items[2])),
              const SizedBox(width: 8),
              Expanded(child: HomeNavTile(item: items[3])),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tuile de navigation individuelle, stylisee comme une carte de jeu.
class HomeNavTile extends StatelessWidget {
  final HomeNavItem item;

  const HomeNavTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        // Pas de hauteur fixe : la tuile prend l'espace donne par son parent.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              item.color.withValues(alpha: 0.22),
              const Color(0xFF0D0D20),
              item.color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.color.withValues(alpha: 0.38),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: item.color.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: MiniCardPatternPainter(color: item.color),
                ),
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 6,
                child: Icon(
                  item.icon,
                  color: item.color.withValues(alpha: 0.5),
                  size: 8,
                ),
              ),
              Positioned(
                bottom: 4,
                right: 6,
                child: Transform.rotate(
                  angle: pi,
                  child: Icon(
                    item.icon,
                    color: item.color.withValues(alpha: 0.5),
                    size: 8,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            item.color,
                            item.color.withValues(alpha: 0.55),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Icon(item.icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rajdhani(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.92),
                        letterSpacing: 1.0,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        item.color.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
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
// HomeDeckBanner — banniere en pile de cartes du deck actif
// =============================================================

/// Banniere du deck actuellement actif, stylisee en pile de cartes.
class HomeDeckBanner extends ConsumerWidget {
  const HomeDeckBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final selectedId = profile.selectedGameId;
    final activeGame = selectedId == null
        ? null
        : profile.games.where((g) => g.id == selectedId).firstOrNull;

    final deckName = activeGame?.name ?? 'Jeu actif';
    final cardCount = profile.unlockedCards.length;
    const deckColor = Color(0xFFFF6B35);

    return SizedBox(
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Carte arriere 2 (la plus decalee).
          Positioned(
            left: 8,
            top: 6,
            right: 4,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    deckColor.withValues(alpha: 0.08),
                    const Color(0xFF0D0D20),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: deckColor.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          // Carte arriere 1 (legerement decalee).
          Positioned(
            left: 4,
            top: 3,
            right: 2,
            bottom: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    deckColor.withValues(alpha: 0.12),
                    const Color(0xFF0D0D20),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: deckColor.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),
          // Carte avant principale.
          Positioned(
            left: 0, top: 0, right: 0, bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    deckColor.withValues(alpha: 0.22),
                    const Color(0xFF0D0D20),
                    deckColor.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: deckColor.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: deckColor.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: MiniCardPatternPainter(color: deckColor),
                      ),
                    ),
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      left: 8,
                      child: Icon(
                        Icons.style_rounded,
                        color: deckColor.withValues(alpha: 0.5),
                        size: 10,
                      ),
                    ),
                    Positioned(
                      bottom: 5,
                      right: 8,
                      child: Transform.rotate(
                        angle: pi,
                        child: Icon(
                          Icons.style_rounded,
                          color: deckColor.withValues(alpha: 0.5),
                          size: 10,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              deckColor.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4),
                      child: Row(
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
                                  deckColor,
                                  deckColor.withValues(alpha: 0.55),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: deckColor.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.style_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  deckName,
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$cardCount cartes debloquees \u00b7 Mode Solo',
                                  style: GoogleFonts.exo2(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  deckColor.withValues(alpha: 0.2),
                                  deckColor.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: deckColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: deckColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ACTIF',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: deckColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// HomeInstructionGrid — 2 cellules d'instruction
// =============================================================

/// Grille de 2 cellules d'instruction (observer / zoomer).
class HomeInstructionGrid extends StatelessWidget {
  const HomeInstructionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.015),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HomeInstructionCell(
              icon: Icons.visibility_rounded,
              iconColor: const Color(0xFF42A5F5),
              title: tr('home.instr_find'),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          Expanded(
            child: _HomeInstructionCell(
              icon: Icons.touch_app_rounded,
              iconColor: const Color(0xFFF7C948),
              title: tr('home.instr_zoom'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeInstructionCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _HomeInstructionCell({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.exo2(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// HomeDecorativeLine — ligne decorative avec losange central
// =============================================================

/// Trait horizontal avec un losange dore central.
class HomeDecorativeLine extends StatelessWidget {
  const HomeDecorativeLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Transform.rotate(
            angle: pi / 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                ),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// HomeAvatarXpRing — avatar avec anneau XP et badge niveau
// =============================================================

/// Avatar du joueur avec un anneau XP colore proportionnel au score.
///
/// Affiche :
///   - Arc XP de fond (gris subtil, plein cercle)
///   - Arc XP colore (gradient orange/or, portion = score%1000)
///   - Avatar rond au centre avec l'icone correspondante
///   - Badge niveau en bas (gradient orange/or)
class HomeAvatarXpRing extends StatelessWidget {
  final String avatarId;
  final int level;
  final int score;

  const HomeAvatarXpRing({
    super.key,
    required this.avatarId,
    required this.level,
    required this.score,
  });

  /// Map "avatar_N" → icone.
  static IconData _avatarIcon(String avatarId) {
    const map = <String, IconData>{
      'avatar_1': Icons.pets,
      'avatar_2': Icons.flutter_dash,
      'avatar_3': Icons.water,
      'avatar_4': Icons.local_fire_department,
      'avatar_5': Icons.park,
      'avatar_6': Icons.nightlight_round,
      'avatar_7': Icons.bolt,
      'avatar_8': Icons.ac_unit,
      'avatar_9': Icons.whatshot,
      'avatar_10': Icons.psychology,
      'avatar_11': Icons.terrain,
      'avatar_12': Icons.waves,
    };
    return map[avatarId] ?? Icons.person;
  }

  @override
  Widget build(BuildContext context) {
    const xpPerLevel = 1000;
    final currentXp = score % xpPerLevel;
    final xpRatio = currentXp / xpPerLevel;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: XpRingPainter(
              progress: 1.0,
              color: Colors.white.withValues(alpha: 0.08),
              strokeWidth: 3.5,
            ),
          ),
          CustomPaint(
            size: const Size(56, 56),
            painter: XpRingPainter(
              progress: xpRatio,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFFF6B35),
                  Color(0xFFF7C948),
                  Color(0xFFFF8A35),
                ],
              ),
              strokeWidth: 3.5,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1040),
              border: Border.all(
                color: const Color(0xFF2A1850),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(
              _avatarIcon(avatarId),
              color: TTheme.gold,
              size: 22,
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '$level',
                style: GoogleFonts.rajdhani(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// HomeMarqueeBanner — texte defilant horizontal (marquee)
// =============================================================
// Affiche une liste de textes qui defilent horizontalement
// en boucle infinie, separes par des etoiles dorees.
// Utilise un AnimationController pour deplacer le contenu.
// =============================================================

/// Banniere de texte defilant horizontalement.
///
/// Prend une liste de [texts] et les affiche en boucle infinie
/// avec un defilement fluide de droite a gauche.
class HomeMarqueeBanner extends StatefulWidget {
  /// Les textes a afficher en defilement.
  final List<String> texts;

  const HomeMarqueeBanner({super.key, required this.texts});

  @override
  State<HomeMarqueeBanner> createState() => _HomeMarqueeBannerState();
}

class _HomeMarqueeBannerState extends State<HomeMarqueeBanner>
    with SingleTickerProviderStateMixin {
  /// Controller pour le defilement continu.
  /// Duree de 12 secondes pour un cycle complet.
  late AnimationController _scrollController;

  /// Cle globale pour mesurer la largeur du contenu duplique.
  final GlobalKey _contentKey = GlobalKey();

  /// Largeur mesuree du contenu (une seule copie).
  double _contentWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Mesurer la largeur du contenu apres le premier frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureContent();
    });
  }

  /// Mesure la largeur du contenu pour le defilement en boucle.
  void _measureContent() {
    final box =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && mounted) {
      setState(() => _contentWidth = box.size.width);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Construire le texte combine avec separateurs etoiles.
    final combined = widget.texts.join('  ★  ');
    // Doubler le texte pour un defilement sans coupure.
    final marqueeText = '$combined  ★  $combined  ★  ';

    // Container decore avec clipBehavior pour eviter l'overflow visuel.
    return Container(
      height: 28,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      // OverflowBox donne une largeur infinie au child
      // pour que le Row ne declenche pas d'overflow layout.
      // Le clipBehavior du Container parent coupe visuellement.
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _scrollController,
          builder: (context, child) {
            final offset = _contentWidth > 0
                ? -_scrollController.value * _contentWidth
                : 0.0;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            key: _contentKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MarqueeTextSegment(text: marqueeText),
              _MarqueeTextSegment(text: marqueeText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segment de texte stylise pour le marquee.
class _MarqueeTextSegment extends StatelessWidget {
  final String text;

  const _MarqueeTextSegment({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: GoogleFonts.exo2(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.65),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
