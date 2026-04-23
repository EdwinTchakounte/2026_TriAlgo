// =============================================================
// FICHIER : lib/presentation/wireframes/t_profile_page.dart
// ROLE   : Profil joueur premium (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Ecran de profil premium avec stats du joueur.
///
/// Lit les vraies donnees depuis profileProvider :
///   - username, avatar_id  → user_profiles
///   - score, level, vies    → user_games du jeu selectionne
///   - cartes debloquees     → user_unlocked_cards
class TProfilePage extends ConsumerWidget {
  const TProfilePage({super.key});

  /// Map avatar_id → icone (meme correspondance que la home).
  IconData _avatarIcon(String avatarId) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = TLocale.of(context);
    final profile = ref.watch(profileProvider);

    // Donnees reelles depuis le profile provider.
    final username = profile.username;
    final avatarId = profile.avatarId;
    final level = profile.level;
    final score = profile.score;
    final unlockedCount = profile.unlockedCards.length;
    // Nombre de jeux actives (pour la stat "jeux").
    final gamesCount = profile.games.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
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
                    child: Icon(
                      _avatarIcon(avatarId),
                      size: 44,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr('common.level')} $level  ·  $score ${tr('common.pts')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),

                const SizedBox(height: 28),

                // Stats reelles.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _statCard(
                        '$gamesCount',
                        'Jeux',
                        Icons.sports_esports_rounded,
                        const Color(0xFFF7C948),
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        '$score',
                        tr('profile.score'),
                        Icons.star_rounded,
                        const Color(0xFFFF6B35),
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        '$unlockedCount',
                        'Cartes',
                        Icons.style_rounded,
                        const Color(0xFF66BB6A),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // --- Liste des jeux actives par l'utilisateur ---
                // Remplace l'historique mock par la vraie liste depuis
                // user_games via profileProvider.games.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sports_esports_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mes jeux',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Si aucun jeu, message informatif.
                      if (profile.games.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Aucun jeu active',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        )
                      else
                        // Liste des jeux avec leur nom + statut actif.
                        ...profile.games.map((game) {
                          final isActive = game.id == profile.selectedGameId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFFFF6B35)
                                        .withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xFFFF6B35)
                                          .withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFF6B35)
                                          .withValues(alpha: 0.15),
                                    ),
                                    child: const Icon(
                                      Icons.style_rounded,
                                      color: Color(0xFFFF6B35),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          game.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        if (game.theme != null)
                                          Text(
                                            game.theme!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF66BB6A)
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'ACTIF',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF66BB6A),
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
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
