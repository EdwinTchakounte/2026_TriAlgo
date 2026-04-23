// =============================================================
// FICHIER : lib/presentation/wireframes/t_leaderboard_page.dart
// ROLE   : Classement premium avec podium (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Classement premium avec podium anime.
///
/// Charge les donnees depuis Supabase :
///   SELECT user_profiles.username, user_games.total_score,
///          user_games.current_level
///   FROM user_games JOIN user_profiles
///   ORDER BY total_score DESC LIMIT 10
class TLeaderboardPage extends ConsumerStatefulWidget {
  const TLeaderboardPage({super.key});

  @override
  ConsumerState<TLeaderboardPage> createState() => _TLeaderboardPageState();
}

class _TLeaderboardPageState extends ConsumerState<TLeaderboardPage> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLeaderboard());
  }

  // =============================================================
  // CHARGEMENT DEPUIS SUPABASE
  // =============================================================
  // Requete qui combine user_profiles (username, avatar) et
  // user_games (score, level). Trie par score descendant, top 10.
  //
  // Le jeu selectionne est filtre pour ne voir que les joueurs du
  // meme jeu dans le classement.
  // =============================================================

  Future<void> _loadLeaderboard() async {
    try {
      final profile = ref.read(profileProvider);
      final currentUserId = supabase.auth.currentUser?.id;
      final gameId = profile.selectedGameId;

      if (gameId == null) {
        setState(() {
          _loading = false;
          _error = 'Aucun jeu selectionne';
        });
        return;
      }

      // JOIN user_games avec user_profiles pour avoir le username.
      // Le foreign join Supabase : user_games → user_profiles via user_id.
      final data = await supabase
          .from('user_games')
          .select('total_score, current_level, user_id, '
              'user_profiles!inner(username, avatar_id)')
          .eq('game_id', gameId)
          .order('total_score', ascending: false)
          .limit(10);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _leaderboard = (data as List<dynamic>).asMap().entries.map((entry) {
          final idx = entry.key;
          final row = entry.value as Map<String, dynamic>;
          final profileData = row['user_profiles'] as Map<String, dynamic>;
          return {
            'rank': idx + 1,
            'username': profileData['username'] as String? ?? 'Joueur',
            'score': row['total_score'] as int,
            'level': row['current_level'] as int,
            'isCurrentUser': row['user_id'] == currentUserId,
          };
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A1A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    if (_error != null || _leaderboard.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: TTheme.patterned(
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.leaderboard_rounded,
                    color: Colors.white24,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _leaderboard.isEmpty
                        ? 'Aucun joueur dans le classement'
                        : 'Erreur : $_error',
                    style: const TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retour'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final leaderboard = _leaderboard;
    final podium = leaderboard.take(3).toList();
    final rest = leaderboard.skip(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
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
