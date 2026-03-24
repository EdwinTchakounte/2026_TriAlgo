// =============================================================
// FICHIER : lib/presentation/wireframes/t_leaderboard_page.dart
// ROLE   : Classement premium avec podium (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';

/// Classement premium avec podium anime.
class TLeaderboardPage extends StatelessWidget {
  const TLeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final leaderboard = MockData.mockLeaderboard;
    final podium = leaderboard.take(3).toList();
    final rest = leaderboard.skip(3).toList();

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // Header.
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
                    Text(tr('leaderboard.title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Podium.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _podium(podium[1], h: 80, color: Colors.grey.shade400, medal: '2'),
                    const SizedBox(width: 10),
                    _podium(podium[0], h: 110, color: const Color(0xFFF7C948), medal: '1'),
                    const SizedBox(width: 10),
                    _podium(podium[2], h: 60, color: const Color(0xFFCD7F32), medal: '3'),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Divider(color: Colors.white.withValues(alpha: 0.06), indent: 20, endIndent: 20),

              // Liste.
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  itemCount: rest.length,
                  itemBuilder: (_, i) {
                    final p = rest[i];
                    final isCurrent = p['isCurrentUser'] as bool;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isCurrent ? const Color(0xFFFF6B35).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent ? const Color(0xFFFF6B35).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text('#${p['rank']}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCurrent ? const Color(0xFFFF6B35) : Colors.white38)),
                            ),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isCurrent ? const Color(0xFFFF6B35).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                              child: Text(
                                (p['username'] as String)[0],
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCurrent ? const Color(0xFFFF6B35) : Colors.white38),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['username'] as String, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isCurrent ? Colors.white : Colors.white70)),
                                  Text('${tr('common.level')} ${p['level']}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
                                ],
                              ),
                            ),
                            Text('${p['score']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isCurrent ? const Color(0xFFFF6B35) : Colors.white)),
                          ],
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

  Widget _podium(Map<String, dynamic> p, {required double h, required Color color, required String medal}) {
    return Column(
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Center(child: Text(medal, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
        ),
        const SizedBox(height: 6),
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.25),
          child: Text((p['username'] as String)[0], style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        const SizedBox(height: 4),
        Text(p['username'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        Text('${p['score']}', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
        const SizedBox(height: 6),
        Container(
          width: 65, height: h,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.2)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          ),
        ),
      ],
    );
  }
}
