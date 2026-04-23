// =============================================================
// FICHIER : lib/presentation/wireframes/t_avatar_page.dart
// ROLE   : Selection de l'avatar - galerie 12 avatars procedurals
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Preview XL en haut (avatar selectionne)
//   - Grille 3 colonnes de 12 avatars (gradient + initiale)
//   - Selection = halo dore + bordure blanche + feedback haptic
//   - Validation explicite via bouton "VALIDER MON AVATAR"
//   - Pas de validation auto au tap : l'enfant peut essayer plusieurs
//     avant de decider
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/data/services/audio_service.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/user_avatar.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


class TAvatarPage extends ConsumerStatefulWidget {
  const TAvatarPage({super.key});

  @override
  ConsumerState<TAvatarPage> createState() => _TAvatarPageState();
}

class _TAvatarPageState extends ConsumerState<TAvatarPage> {
  late String _selected;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(profileProvider).avatarId;
  }

  void _onTapAvatar(String id) {
    if (_selected == id) return;
    HapticFeedback.selectionClick();
    ref.read(audioServiceProvider).playSfx(SoundEffect.click);
    setState(() => _selected = id);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).updateAvatar(_selected);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    final hasChanged = _selected != profile.avatarId;

    return PageScaffold(
      title: tr('avatar.title_refonte'),
      child: Column(
        children: [
          // --- Preview XL en haut ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.xxl,
              vertical: TSpacing.xl,
            ),
            child: Column(
              children: [
                UserAvatar(
                  avatarId: _selected,
                  username: profile.username,
                  size: 120,
                  showHalo: true,
                ),
                const SizedBox(height: TSpacing.md),
                Text(
                  profile.username,
                  style: TTypography.titleLg(color: colors.textPrimary),
                ),
              ],
            ),
          ),

          // --- Grille 3 colonnes de 12 avatars ---
          // Reprend l'approche de l'ancien systeme : 12 avatars icones
          // thematiques (pets, water, fire, psychology...) avec chacun
          // son gradient de couleur dedie.
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: TSpacing.xxl,
                vertical: TSpacing.lg,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: TSpacing.lg,
                crossAxisSpacing: TSpacing.lg,
                childAspectRatio: 1,
              ),
              itemCount: kAllAvatarIds.length,
              itemBuilder: (context, index) {
                final id = kAllAvatarIds[index];
                final isSelected = _selected == id;
                return GestureDetector(
                  onTap: () => _onTapAvatar(id),
                  child: Center(
                    child: UserAvatar(
                      avatarId: id,
                      username: profile.username,
                      size: 72,
                      showHalo: isSelected,
                      selected: isSelected,
                    ),
                  ),
                );
              },
            ),
          ),

          // --- Bouton valider ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.xxl,
              vertical: TSpacing.lg,
            ),
            child: AppButton.primary(
              label: tr('avatar.cta_save'),
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              fullWidth: true,
              size: AppButtonSize.lg,
              onPressed: hasChanged ? _save : null,
            ),
          ),
        ],
      ),
    );
  }
}
