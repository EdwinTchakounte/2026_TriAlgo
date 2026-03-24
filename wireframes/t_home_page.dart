// =============================================================
// FICHIER : lib/presentation/wireframes/t_home_page.dart
// ROLE   : Hub central premium AAA - Header fixe + body scroll
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_illustrations.dart';
import 'package:trialgo/presentation/wireframes/t_level_map_page.dart';
import 'package:trialgo/presentation/wireframes/t_profile_page.dart';
import 'package:trialgo/presentation/wireframes/t_leaderboard_page.dart';
import 'package:trialgo/presentation/wireframes/t_settings_page.dart';
import 'package:trialgo/presentation/wireframes/t_tutorial_page.dart';
import 'package:trialgo/presentation/wireframes/t_gallery_page.dart';

/// Hub central premium AAA avec header fixe et body scrollable.
class THomePage extends StatefulWidget {
  const THomePage({super.key});

  @override
  State<THomePage> createState() => _THomePageState();
}

class _THomePageState extends State<THomePage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseGlow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseGlow = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final user = MockData.mockUser;
    final username = user['username'] as String;
    final level = user['currentLevel'] as int;
    final score = user['totalScore'] as int;
    final lives = user['lives'] as int;
    final maxLives = user['maxLives'] as int;

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // =======================================================
              // HEADER FIXE (ne scroll pas)
              // =======================================================
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E0F3C), Color(0xFF2D1B69), Color(0xFF1A1040)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Row 1 : Logo + Settings.
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(MockData.logo, width: 30, height: 30, fit: BoxFit.contain),
                            const SizedBox(width: 8),
                            ShaderMask(
                              shaderCallback: (bounds) => TTheme.accentGradient.createShader(bounds),
                              child: Text('TRIALGO', style: TTheme.subtitleStyle(size: 16)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _iconBtn(Icons.settings_rounded, () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TSettingsPage()),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Row 2 : Avatar + Infos + Mascotte.
                    Row(
                      children: [
                        // Avatar.
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: TTheme.accentGradient,
                          ),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFF1A1040),
                            child: Text(username[0], style: TTheme.scoreStyle(color: TTheme.gold, size: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Infos - Expanded empeche tout overflow horizontal.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: TTheme.subtitleStyle(size: 17),
                                overflow: TextOverflow.ellipsis,
                                // "ellipsis" : tronque avec "..." si trop long.
                              ),
                              const SizedBox(height: 2),
                              // Wrap au lieu de Row : les tags passent
                              // a la ligne si l'ecran est trop etroit.
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _miniTag('${tr('common.level')}$level', TTheme.blue),
                                  _miniTag('$score ${tr('common.pts')}', TTheme.gold),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge de jeu (remplace la mascotte).
                        TIllustrations.gameBadge(size: 46),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Row 3 : Vies.
                    // Utilise LayoutBuilder pour adapter la disposition
                    // a la largeur reelle disponible.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Si la largeur est < 300px (petit ecran),
                          // on empile les coeurs et le timer en colonne.
                          final isNarrow = constraints.maxWidth < 280;

                          final heartsRow = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...List.generate(maxLives, (i) => Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: Icon(
                                  i < lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: i < lives ? TTheme.red : Colors.white.withValues(alpha: 0.12),
                                  size: isNarrow ? 16 : 18,
                                ),
                              )),
                              const SizedBox(width: 4),
                              Text('$lives/$maxLives', style: TTheme.scoreStyle(size: 13)),
                            ],
                          );

                          final timerWidget = lives < maxLives
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: TTheme.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined, color: TTheme.red, size: 12),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${tr('home.next_life')} 12${tr('home.min')}',
                                        style: TTheme.tagStyle(color: TTheme.red, size: 10),
                                      ),
                                    ],
                                  ),
                                )
                              : null;

                          if (isNarrow && timerWidget != null) {
                            // Petit ecran : empiler verticalement.
                            return Column(
                              children: [
                                heartsRow,
                                const SizedBox(height: 6),
                                timerWidget,
                              ],
                            );
                          }

                          // Ecran normal : cote a cote.
                          return Row(
                            children: [
                              heartsRow,
                              if (timerWidget != null) ...[
                                const Spacer(),
                                timerWidget,
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // =======================================================
              // BODY SCROLLABLE
              // =======================================================
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  child: Column(
                    children: [
                      // --- BOUTON JOUER ---
                      AnimatedBuilder(
                        animation: _pulseGlow,
                        builder: (context, child) {
                          return GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TLevelMapPage()),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: TTheme.accentGradient,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color.lerp(TTheme.orange, TTheme.gold, _pulseGlow.value)!
                                        .withValues(alpha: _pulseGlow.value),
                                    blurRadius: 28, spreadRadius: 1,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52, height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, size: 32, color: Colors.white),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(tr('home.play'), style: TTheme.titleStyle(size: 26)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Niveau $level · Quintettes · D2',
                                            style: TTheme.bodyStyle(size: 11, color: Colors.white.withValues(alpha: 0.9)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 22),

                      // --- GRILLE 2x2 ---
                      Row(
                        children: [
                          _tile(Icons.school_rounded, tr('home.tutorial'), tr('home.tutorial_desc'),
                            [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TTutorialPage()))),
                          const SizedBox(width: 12),
                          _tile(Icons.collections_rounded, tr('home.gallery'), '18 cartes',
                            [const Color(0xFF11998E), const Color(0xFF38EF7D)],
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TGalleryPage()))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _tile(Icons.leaderboard_rounded, tr('home.leaderboard'), '#4 mondial',
                            [const Color(0xFFF7971E), const Color(0xFFFFD200)],
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TLeaderboardPage()))),
                          const SizedBox(width: 12),
                          _tile(Icons.person_rounded, tr('home.profile'), '$score ${tr('common.pts')}',
                            [const Color(0xFFFC5C7D), const Color(0xFF6A82FB)],
                            () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TProfilePage()))),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // --- STATS RAPIDES ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat('24', tr('home.games'), Icons.sports_esports_rounded, TTheme.blue),
                            _vDivider(),
                            _stat('87%', tr('home.accuracy'), Icons.gps_fixed_rounded, TTheme.green),
                            _vDivider(),
                            _stat('5', tr('home.streak'), Icons.local_fire_department_rounded, TTheme.orange),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // --- BANNIERE E+C=R illustree ---
                      TIllustrations.heroBanner(height: 130),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white54, size: 18),
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TTheme.tagStyle(color: color, size: 10)),
    );
  }

  Widget _tile(IconData icon, String label, String desc, List<Color> grad, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: grad),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: grad[0].withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(label, style: TTheme.subtitleStyle(size: 14)),
              Text(desc, style: TTheme.bodyStyle(size: 11, color: Colors.white.withValues(alpha: 0.35))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TTheme.scoreStyle(size: 16)),
        Text(label, style: TTheme.bodyStyle(size: 10, color: Colors.white.withValues(alpha: 0.35))),
      ],
    );
  }

  Widget _vDivider() => Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.06));
}
