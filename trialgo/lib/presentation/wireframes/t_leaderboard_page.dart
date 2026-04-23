// =============================================================
// FICHIER : lib/presentation/wireframes/t_leaderboard_page.dart
// ROLE   : Classement - podium top 3 + liste + ta position
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Podium top 3 visuellement distinct (or/argent/bronze)
//   - Ta ligne highlightee avec bordure + halo
//   - Avatars procedurals pour chaque joueur
//   - Si pas dans top 10, bloc "ta position" flottant en bas
//   - Loading via LoadingState, error via EmptyState error tone
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_card.dart';
import 'package:trialgo/presentation/widgets/core/empty_state.dart';
import 'package:trialgo/presentation/widgets/core/loading_state.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/user_avatar.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


class _LeaderEntry {
  final int rank;
  final String username;
  final String avatarId;
  final int score;
  final int level;
  final bool isCurrentUser;

  const _LeaderEntry({
    required this.rank,
    required this.username,
    required this.avatarId,
    required this.score,
    required this.level,
    required this.isCurrentUser,
  });
}


class TLeaderboardPage extends ConsumerStatefulWidget {
  const TLeaderboardPage({super.key});

  @override
  ConsumerState<TLeaderboardPage> createState() =>
      _TLeaderboardPageState();
}

class _TLeaderboardPageState extends ConsumerState<TLeaderboardPage> {
  List<_LeaderEntry> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final profile = ref.read(profileProvider);
      final currentUserId = supabase.auth.currentUser?.id;
      final gameId = profile.selectedGameId;

      if (gameId == null) {
        setState(() {
          _loading = false;
          _error = 'no_game_selected';
        });
        return;
      }

      // STEP 1 : Top 10 de user_games pour le jeu actif.
      // On evite l'embed Supabase (user_profiles!inner) qui necessite
      // une FK explicite entre user_games et user_profiles — absente
      // car les deux referencent auth.users separement.
      final gamesData = await supabase
          .from('user_games')
          .select('total_score, current_level, user_id')
          .eq('game_id', gameId)
          .order('total_score', ascending: false)
          .limit(10);

      final gamesList = (gamesData as List<dynamic>).cast<Map<String, dynamic>>();
      if (gamesList.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _list = [];
        });
        return;
      }

      // STEP 2 : recuperer username + avatar pour tous ces user_ids.
      // Seconde requete mais simple, pas de JOIN -> pas de risque
      // de Schema cache error.
      final userIds = gamesList.map((g) => g['user_id'] as String).toList();
      final profilesData = await supabase
          .from('user_profiles')
          .select('id, username, avatar_id')
          .inFilter('id', userIds);

      // Map user_id -> profil pour lookup O(1).
      final profilesById = <String, Map<String, dynamic>>{
        for (final p in (profilesData as List<dynamic>))
          (p as Map<String, dynamic>)['id'] as String: p,
      };

      if (!mounted) return;

      // STEP 3 : assembler les entrees en conservant l'ordre de ranking.
      final rows = gamesList.asMap().entries.map((e) {
        final idx = e.key;
        final g = e.value;
        final userId = g['user_id'] as String;
        final p = profilesById[userId] ?? const <String, dynamic>{};
        return _LeaderEntry(
          rank: idx + 1,
          username: p['username'] as String? ?? 'Joueur',
          avatarId: p['avatar_id'] as String? ?? 'avatar_1',
          score: g['total_score'] as int,
          level: g['current_level'] as int,
          isCurrentUser: userId == currentUserId,
        );
      }).toList();

      setState(() {
        _loading = false;
        _list = rows;
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
    return PageScaffold(
      title: tr('lb.title'),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final tr = TLocale.of(context);
    if (_loading) {
      return LoadingState(message: tr('lb.loading'));
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr('lb.error_title'),
        description: tr('lb.error_body'),
        tone: EmptyStateTone.error,
        actionLabel: tr('lb.cta_retry'),
        onAction: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_list.isEmpty) {
      return EmptyState(
        icon: Icons.emoji_events_outlined,
        title: tr('lb.empty_title'),
        description: tr('lb.empty_body'),
      );
    }

    // Separe le top 3 pour le podium du reste pour la liste.
    final podium = _list.take(3).toList();
    final rest = _list.skip(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.xxl,
        vertical: TSpacing.lg,
      ),
      child: Column(
        children: [
          _buildPodium(podium),
          const SizedBox(height: TSpacing.xxl),
          for (final entry in rest) ...[
            _buildRow(entry),
            const SizedBox(height: TSpacing.sm),
          ],
        ],
      ),
    );
  }

  // =============================================================
  // PODIUM TOP 3
  // =============================================================

  Widget _buildPodium(List<_LeaderEntry> top3) {
    // On veut afficher visuellement : 2e (gauche), 1er (centre haut),
    // 3e (droite). Donc on reorganise l'ordre d'affichage.
    final p1 = top3.isNotEmpty ? top3[0] : null;
    final p2 = top3.length > 1 ? top3[1] : null;
    final p3 = top3.length > 2 ? top3[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _buildPodiumSlot(p2, height: 120, medalColor:
          const Color(0xFFC0C0C0), medalText: '2')),
        Expanded(child: _buildPodiumSlot(p1, height: 150, medalColor:
          TColors.primaryVariant, medalText: '1')),
        Expanded(child: _buildPodiumSlot(p3, height: 100, medalColor:
          const Color(0xFFCD7F32), medalText: '3')),
      ],
    );
  }

  Widget _buildPodiumSlot(
    _LeaderEntry? entry, {
    required double height,
    required Color medalColor,
    required String medalText,
  }) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    if (entry == null) {
      // Slot vide (moins de 3 joueurs dans le classement).
      return SizedBox(height: height);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar avec anneau medaille.
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              avatarId: entry.avatarId,
              username: entry.username,
              size: 56,
              showHalo: true,
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: medalColor,
                  border: Border.all(color: colors.bgBase, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  medalText,
                  style: TTypography.labelSm(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: TSpacing.sm),
        // Username + score.
        Text(
          entry.username,
          style: TTypography.titleMd(color: colors.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${entry.score} ${tr('lb.pts')}',
          style: TTypography.labelMd(color: colors.textSecondary),
        ),
        const SizedBox(height: TSpacing.sm),
        // Pilier du podium.
        Container(
          width: double.infinity,
          height: height - 56 - 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                medalColor.withValues(alpha: 0.4),
                medalColor.withValues(alpha: 0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(TRadius.md),
              topRight: Radius.circular(TRadius.md),
            ),
            border: Border.all(color: medalColor.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }

  // =============================================================
  // LIGNE DU CLASSEMENT (rang 4-10)
  // =============================================================

  Widget _buildRow(_LeaderEntry e) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);

    return Container(
      decoration: e.isCurrentUser
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TColors.primary.withValues(alpha: 0.15),
                  TColors.primaryVariant.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: TRadius.lgAll,
              border: Border.all(
                color: TColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: TElevation.glowPrimary,
            )
          : null,
      child: AppCard.glass(
        child: Row(
          children: [
            // Rang.
            SizedBox(
              width: 32,
              child: Text(
                '#${e.rank}',
                style: TTypography.numericSm(color: colors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: TSpacing.sm),

            // Avatar.
            UserAvatar(
              avatarId: e.avatarId,
              username: e.username,
              size: 40,
            ),
            const SizedBox(width: TSpacing.md),

            // Username + niveau.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.username,
                    style: TTypography.titleMd(
                      color: e.isCurrentUser
                          ? TColors.primary
                          : colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${tr('lb.level_label')} ${e.level}',
                    style: TTypography.labelMd(color: colors.textTertiary),
                  ),
                ],
              ),
            ),

            // Score.
            Text(
              '${e.score}',
              style: TTypography.numericMd(color: colors.textPrimary),
            ),
            const SizedBox(width: TSpacing.xxs),
            Text(
              tr('lb.pts'),
              style: TTypography.labelSm(color: colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
