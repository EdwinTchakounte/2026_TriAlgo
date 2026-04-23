// =============================================================
// FICHIER : lib/presentation/wireframes/t_profile_page.dart
// ROLE   : Profil du joueur - sanctuaire personnel
// COUCHE : Presentation > Wireframes
// =============================================================
//
// STRUCTURE :
// -----------
//   1. Hero : avatar XL + halo + badge niveau + nom + streak
//   2. Carte "Ma carte de joueur" : stats cumulees en encart premium
//   3. Grille 4 trophees (debloque/grise selon conditions)
//   4. Historique : 3 dernieres parties avec etoiles
//   5. Actions : changer avatar, changer nom, deconnexion
//
// TROPHEES (4, calcules depuis AppProfileState) :
//   - PREMIER PAS  : level >= 2
//   - EXPLORATEUR  : level >= 10
//   - SERIE DE FEU : streak >= 7
//   - PERFECT      : au moins 1 session avec 3 etoiles
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/domain/entities/session_entity.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_card.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/core/section_header.dart';
import 'package:trialgo/presentation/widgets/user_avatar.dart';
import 'package:trialgo/presentation/wireframes/t_auth_gate.dart';
import 'package:trialgo/presentation/wireframes/t_avatar_page.dart';
import 'package:trialgo/presentation/wireframes/t_edit_username_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


class TProfilePage extends ConsumerWidget {
  const TProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = TLocale.of(context);
    final profile = ref.watch(profileProvider);

    return PageScaffold(
      title: tr('profile.title'),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.xxl,
          vertical: TSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(context, profile),
            const SizedBox(height: TSpacing.xxl),

            _buildPlayerCard(context, profile),
            const SizedBox(height: TSpacing.lg),

            SectionHeader(title: tr('profile.section_trophies')),
            _buildTrophies(context, profile, tr),
            const SizedBox(height: TSpacing.xl),

            if (profile.recentSessions.isNotEmpty) ...[
              SectionHeader(title: tr('profile.section_recent')),
              ...profile.recentSessions.take(3).map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: TSpacing.sm),
                      child: _buildSessionCard(context, s, tr),
                    ),
                  ),
              const SizedBox(height: TSpacing.xl),
            ],

            SectionHeader(title: tr('profile.section_account')),
            const SizedBox(height: TSpacing.sm),
            AppCard.glass(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TAvatarPage()),
              ),
              child: _buildActionRow(
                context,
                icon: Icons.face_retouching_natural_outlined,
                label: tr('profile.action_avatar'),
                color: TColors.info,
              ),
            ),
            const SizedBox(height: TSpacing.sm),
            AppCard.glass(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TEditUsernamePage()),
              ),
              child: _buildActionRow(
                context,
                icon: Icons.edit_outlined,
                label: tr('profile.action_username'),
                color: TColors.primary,
              ),
            ),
            const SizedBox(height: TSpacing.sm),
            AppCard.glass(
              onTap: () => _confirmSignOut(context, ref, tr),
              child: _buildActionRow(
                context,
                icon: Icons.logout_rounded,
                label: tr('settings.sign_out'),
                color: TColors.error,
              ),
            ),

            const SizedBox(height: TSpacing.xxl),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // HERO
  // =============================================================

  Widget _buildHero(BuildContext context, AppProfileState profile) {
    final colors = TColors.of(context);
    return Column(
      children: [
        SizedBox(
          width: 136,
          height: 136,
          child: Stack(
            children: [
              Center(
                child: UserAvatar(
                  avatarId: profile.avatarId,
                  username: profile.username,
                  size: 120,
                  showHalo: true,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 8,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.bgRaised,
                    border: Border.all(color: TColors.primary, width: 3),
                    boxShadow: TElevation.glowPrimary,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${profile.level}',
                    style: TTypography.numericSm(color: TColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TSpacing.md),
        Text(
          profile.username,
          style: TTypography.headlineLg(color: colors.textPrimary),
        ),
        const SizedBox(height: TSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              profile.streak > 0
                  ? Icons.local_fire_department_rounded
                  : Icons.local_fire_department_outlined,
              color: profile.streak > 0
                  ? TColors.primaryVariant
                  : colors.textTertiary,
              size: 18,
            ),
            const SizedBox(width: TSpacing.xxs),
            Text(
              profile.streak > 0
                  ? '${profile.streak} jour${profile.streak > 1 ? "s" : ""}'
                  : 'Pas de serie',
              style: TTypography.labelLg(
                color: profile.streak > 0
                    ? TColors.primaryVariant
                    : colors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =============================================================
  // PLAYER CARD
  // =============================================================

  Widget _buildPlayerCard(BuildContext context, AppProfileState profile) {
    return AppCard.elevated(
      padding: const EdgeInsets.all(TSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _buildPlayerStat(
              context,
              icon: Icons.flash_on_rounded,
              label: 'Niveau',
              value: 'N${profile.level}',
              color: TColors.info,
            ),
          ),
          _verticalDivider(context),
          Expanded(
            child: _buildPlayerStat(
              context,
              icon: Icons.star_rounded,
              label: 'Score',
              value: '${profile.score}',
              color: TColors.primaryVariant,
            ),
          ),
          _verticalDivider(context),
          Expanded(
            child: _buildPlayerStat(
              context,
              icon: Icons.collections_bookmark_rounded,
              label: 'Cartes',
              value: '${profile.unlockedCards.length}',
              color: TColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: TColors.of(context).borderSubtle,
        margin: const EdgeInsets.symmetric(horizontal: TSpacing.xs),
      );

  Widget _buildPlayerStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colors = TColors.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: TSpacing.xs),
        Text(value, style: TTypography.numericMd(color: colors.textPrimary)),
        Text(label, style: TTypography.labelSm(color: colors.textTertiary)),
      ],
    );
  }

  // =============================================================
  // TROPHEES
  // =============================================================

  Widget _buildTrophies(
    BuildContext context,
    AppProfileState profile,
    String Function(String) tr,
  ) {
    final trophies = <_TrophyData>[
      _TrophyData(
        icon: Icons.rocket_launch_rounded,
        label: tr('profile.trophy_first_title'),
        hint: tr('profile.trophy_first_hint'),
        unlocked: profile.level >= 2,
        color: TColors.info,
      ),
      _TrophyData(
        icon: Icons.explore_rounded,
        label: tr('profile.trophy_explorer_title'),
        hint: tr('profile.trophy_explorer_hint'),
        unlocked: profile.level >= 10,
        color: TColors.primaryVariant,
      ),
      _TrophyData(
        icon: Icons.local_fire_department_rounded,
        label: tr('profile.trophy_streak_title'),
        hint: tr('profile.trophy_streak_hint'),
        unlocked: profile.streak >= 7,
        color: TColors.primary,
      ),
      _TrophyData(
        icon: Icons.auto_awesome_rounded,
        label: tr('profile.trophy_perfect_title'),
        hint: tr('profile.trophy_perfect_hint'),
        unlocked: profile.recentSessions.any((s) => s.starsEarned == 3),
        color: TColors.success,
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < trophies.length; i++) ...[
          Expanded(child: _TrophyBadge(data: trophies[i])),
          if (i < trophies.length - 1) const SizedBox(width: TSpacing.sm),
        ],
      ],
    );
  }

  // =============================================================
  // HISTORIQUE
  // =============================================================

  Widget _buildSessionCard(
    BuildContext context,
    SessionEntity s,
    String Function(String) tr,
  ) {
    final colors = TColors.of(context);
    final ago = _formatRelative(s.playedAt, tr);
    final statusColor = s.passed ? TColors.success : TColors.error;

    return AppCard.glass(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromARGB(
                0x33,
                statusColor.r.round(),
                statusColor.g.round(),
                statusColor.b.round(),
              ),
            ),
            child: Icon(
              s.passed ? Icons.check_rounded : Icons.close_rounded,
              color: statusColor,
            ),
          ),
          const SizedBox(width: TSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Niveau ${s.level} · ${s.correctAnswers}/${s.questionsTotal}',
                  style: TTypography.titleMd(color: colors.textPrimary),
                ),
                Text(
                  ago,
                  style: TTypography.labelMd(color: colors.textTertiary),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final filled = i < s.starsEarned;
              return Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: filled
                    ? TColors.primaryVariant
                    : colors.borderStrong,
              );
            }),
          ),
        ],
      ),
    );
  }

  String _formatRelative(DateTime played, String Function(String) tr) {
    final diff = DateTime.now().difference(played);
    if (diff.inMinutes < 1) return tr('profile.relative_now');
    if (diff.inHours < 1) {
      return tr('profile.relative_min').replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inDays < 1) {
      return tr('profile.relative_h').replaceAll('{n}', '${diff.inHours}');
    }
    if (diff.inDays == 1) return tr('profile.relative_yesterday');
    if (diff.inDays < 7) {
      return tr('profile.relative_days').replaceAll('{n}', '${diff.inDays}');
    }
    return '${played.day}/${played.month}/${played.year}';
  }

  // =============================================================
  // ACTION ROW
  // =============================================================

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final colors = TColors.of(context);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromARGB(
              0x26,
              color.r.round(),
              color.g.round(),
              color.b.round(),
            ),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: TSpacing.md),
        Expanded(
          child: Text(label,
              style: TTypography.titleMd(color: colors.textPrimary)),
        ),
        Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
      ],
    );
  }

  // =============================================================
  // SIGN OUT DIALOG
  // =============================================================

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    String Function(String) tr,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: TRadius.xlAll),
          title: Text(tr('settings.sign_out_confirm_title')),
          content: Text(tr('settings.sign_out_confirm_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                tr('settings.sign_out'),
                style: const TextStyle(color: TColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      await ref.read(profileProvider.notifier).signOut();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TAuthGate()),
        (_) => false,
      );
    }
  }
}


// =============================================================
// CLASSES INTERNES
// =============================================================

class _TrophyData {
  final IconData icon;
  final String label;
  final String hint;
  final bool unlocked;
  final Color color;

  const _TrophyData({
    required this.icon,
    required this.label,
    required this.hint,
    required this.unlocked,
    required this.color,
  });
}


class _TrophyBadge extends StatelessWidget {
  final _TrophyData data;

  const _TrophyBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final color = data.unlocked ? data.color : colors.textTertiary;
    return Opacity(
      opacity: data.unlocked ? 1.0 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(TSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TRadius.lgAll,
          border: Border.all(
            color: data.unlocked ? color : colors.borderSubtle,
            width: data.unlocked ? 1.5 : 1,
          ),
          boxShadow: data.unlocked
              ? [
                  BoxShadow(
                    color: Color.fromARGB(
                      0x33,
                      color.r.round(),
                      color.g.round(),
                      color.b.round(),
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(data.icon, size: 24, color: color),
            const SizedBox(height: TSpacing.xs),
            Text(
              data.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TTypography.labelSm(color: colors.textPrimary),
            ),
            Text(
              data.hint,
              textAlign: TextAlign.center,
              style: TTypography.labelSm(color: colors.textTertiary)
                  .copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
