// =============================================================
// FICHIER : lib/presentation/wireframes/t_level_map_page.dart
// ROLE   : Carte des niveaux premium (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// Design premium : barre de progression, tuiles avec etoiles
// animees, tags colores, effet de verrouillage.
//
// REFERENCE : Recueil v3.0, section 7.1
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_game_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';

/// Carte de selection des niveaux premium.
class TLevelMapPage extends StatelessWidget {
  const TLevelMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final levels = MockData.mockLevels;
    final completed = levels.where((l) => l['completed'] == true).length;

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // --- Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(tr('levels.title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$completed/${levels.length}',
                        style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Barre de progression ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: completed / levels.length,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B35)),
                    minHeight: 5,
                  ),
                ),
              ),

              // --- Liste ---
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: levels.length,
                  itemBuilder: (context, index) {
                    final lv = levels[index];
                    final unlocked = lv['unlocked'] as bool;
                    final isCompleted = lv['completed'] as bool;
                    final isCurrent = unlocked && !isCompleted;
                    final stars = lv['stars'] as int;
                    final lvNum = lv['level'] as int;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: unlocked
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => TGamePage(level: lvNum)))
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFFFF6B35).withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: unlocked ? 0.04 : 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFFFF6B35).withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: isCurrent ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icone statut.
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrent
                                      ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
                                      : isCompleted
                                          ? const Color(0xFFF7C948).withValues(alpha: 0.15)
                                          : Colors.white.withValues(alpha: 0.04),
                                ),
                                child: isCurrent
                                    ? const Icon(Icons.play_arrow_rounded, color: Color(0xFFFF6B35), size: 24)
                                    : isCompleted
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: List.generate(3, (i) => Icon(
                                              i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                                              color: i < stars ? const Color(0xFFF7C948) : Colors.white12,
                                              size: 12,
                                            )),
                                          )
                                        : Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.15), size: 18),
                              ),
                              const SizedBox(width: 14),
                              // Infos.
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${tr('common.level')} $lvNum · ${lv['label']}',
                                      style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w700,
                                        color: unlocked ? Colors.white : Colors.white30,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _tag(lv['distance'] as String, const Color(0xFF42A5F5), unlocked),
                                        const SizedBox(width: 6),
                                        _tag(lv['configs'] as String, const Color(0xFFF7C948), unlocked),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isCurrent)
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFFFF6B35), size: 22),
                            ],
                          ),
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

  Widget _tag(String text, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (active ? color : Colors.white24).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: active ? color : Colors.white30, fontWeight: FontWeight.w600),
      ),
    );
  }
}
