// =============================================================
// FICHIER : lib/presentation/wireframes/t_profile_page.dart
// ROLE   : Profil joueur premium (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';

/// Ecran de profil premium avec stats et historique.
class TProfilePage extends StatelessWidget {
  const TProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final user = MockData.mockUser;
    final sessions = MockData.mockSessionHistory;

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: SingleChildScrollView(
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
                      Text(tr('profile.title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Avatar.
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFF7C948)]),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.3), blurRadius: 16)],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF1A1A2E),
                    child: Text(
                      (user['username'] as String)[0],
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFFFF6B35)),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Text(user['username'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '${tr('common.level')} ${user['currentLevel']}  ·  ${user['totalScore']} ${tr('common.pts')}',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
                ),

                const SizedBox(height: 28),

                // Stats.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _statCard('${sessions.where((s) => s['passed'] == true).length}/${sessions.length}', tr('profile.victories'), Icons.emoji_events_rounded, const Color(0xFFF7C948)),
                      const SizedBox(width: 10),
                      _statCard('${user['totalScore']}', tr('profile.score'), Icons.star_rounded, const Color(0xFFFF6B35)),
                      const SizedBox(width: 10),
                      _statCard('5', tr('profile.max_streak'), Icons.local_fire_department_rounded, const Color(0xFFEF5350)),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Historique.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_rounded, color: Colors.white.withValues(alpha: 0.4), size: 18),
                          const SizedBox(width: 8),
                          Text(tr('profile.history'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.7))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...sessions.map((s) {
                        final passed = s['passed'] as bool;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: passed ? const Color(0xFF66BB6A).withValues(alpha: 0.15) : const Color(0xFFEF5350).withValues(alpha: 0.15),
                                  ),
                                  child: Icon(
                                    passed ? Icons.check_rounded : Icons.close_rounded,
                                    color: passed ? const Color(0xFF66BB6A) : const Color(0xFFEF5350), size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${tr('common.level')} ${s['level']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                                      Text('${s['correct']}/${(s['correct'] as int) + (s['wrong'] as int)} · ${s['date']}',
                                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                                    ],
                                  ),
                                ),
                                Text('${s['score']} ${tr('common.pts')}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: passed ? const Color(0xFF66BB6A) : const Color(0xFFEF5350))),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}
