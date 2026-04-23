// =============================================================
// FICHIER : lib/presentation/wireframes/t_settings_page.dart
// ROLE   : Parametres de l'app (theme, audio, langue, a propos)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE :
// ---------
//   - PageScaffold + design system tokens
//   - Sections ordonnees : Apparence, Audio, Langue, Info, Compte
//   - Segmented control pour le theme (Clair / Sombre / Systeme)
//   - Segmented control pour la langue (FR / EN)
//   - Switches reactifs pour musique/SFX (via AudioService streams)
//   - Actions du compte : deconnexion (bouton rouge ghost)
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_card.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/core/section_header.dart';
import 'package:trialgo/presentation/wireframes/t_app_state.dart';
import 'package:trialgo/presentation/wireframes/t_auth_gate.dart';
import 'package:trialgo/presentation/wireframes/t_collective_mode_page.dart';
import 'package:trialgo/presentation/wireframes/t_help_page.dart';
import 'package:trialgo/presentation/wireframes/t_legal_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_tutorial_page.dart';


class TSettingsPage extends ConsumerStatefulWidget {
  const TSettingsPage({super.key});

  @override
  ConsumerState<TSettingsPage> createState() => _TSettingsPageState();
}

class _TSettingsPageState extends ConsumerState<TSettingsPage> {

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final colors = TColors.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return PageScaffold(
          title: tr('settings.title'),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.xxl,
              vertical: TSpacing.lg,
            ),
            children: [
              // --- APPARENCE ---
              SectionHeader(title: tr('settings.section_appearance')),
              AppCard.glass(
                padding: const EdgeInsets.all(TSpacing.sm),
                child: _buildThemeToggle(colors, tr),
              ),
              const SizedBox(height: TSpacing.lg),

              // --- AUDIO ---
              SectionHeader(title: tr('settings.section_audio')),
              _buildAudioToggles(tr),
              const SizedBox(height: TSpacing.lg),

              // --- LANGUE ---
              SectionHeader(title: tr('settings.section_language')),
              AppCard.glass(
                padding: const EdgeInsets.all(TSpacing.sm),
                child: _buildLanguageToggle(colors),
              ),
              const SizedBox(height: TSpacing.lg),

              // --- OUTILS (mode collectif) ---
              // Le mode collectif est un verificateur de trios
              // (scan 3 cartes ou saisie numero), independant des
              // sessions de jeu. Accessible depuis ici pour la
              // decouverte + depuis la home.
              SectionHeader(title: tr('settings.section_tools')),
              AppCard.glass(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TCollectiveModePage(),
                  ),
                ),
                child: _row(
                  icon: Icons.groups_rounded,
                  label: tr('settings.collective_mode'),
                  color: TColors.success,
                ),
              ),
              const SizedBox(height: TSpacing.lg),

              // --- INFORMATIONS ---
              SectionHeader(title: tr('settings.section_info')),
              AppCard.glass(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TTutorialPage()),
                ),
                child: _row(
                  icon: Icons.school_outlined,
                  label: tr('settings.how_to_play'),
                  color: TColors.info,
                ),
              ),
              const SizedBox(height: TSpacing.sm),
              AppCard.glass(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const THelpPage()),
                ),
                child: _row(
                  icon: Icons.help_outline_rounded,
                  label: tr('settings.help'),
                  color: TColors.primary,
                ),
              ),
              const SizedBox(height: TSpacing.sm),
              AppCard.glass(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TLegalPage()),
                ),
                child: _row(
                  icon: Icons.description_outlined,
                  label: tr('settings.legal'),
                  color: TColors.success,
                ),
              ),
              const SizedBox(height: TSpacing.lg),

              // --- COMPTE ---
              SectionHeader(title: tr('settings.section_account')),
              AppCard.glass(
                onTap: () => _confirmSignOut(context, tr),
                child: _row(
                  icon: Icons.logout_rounded,
                  label: tr('settings.sign_out'),
                  color: TColors.error,
                ),
              ),
              const SizedBox(height: TSpacing.xxl),

              // Version + marque.
              Text(
                'TRIALGO · v1.0.0',
                textAlign: TextAlign.center,
                style: TTypography.labelSm(color: colors.textTertiary),
              ),
              const SizedBox(height: TSpacing.xxl),
            ],
          ),
        );
      },
    );
  }

  // =============================================================
  // THEME TOGGLE (Clair / Sombre / Systeme)
  // =============================================================

  Widget _buildThemeToggle(
    TSurfaceColors colors,
    String Function(String) tr,
  ) {
    final current = appState.themeMode;
    return Row(
      children: [
        _segmentButton(
          label: tr('settings.theme_light'),
          icon: Icons.light_mode_outlined,
          selected: current == ThemeMode.light,
          onTap: () => appState.setThemeMode(ThemeMode.light),
        ),
        _segmentButton(
          label: tr('settings.theme_dark'),
          icon: Icons.dark_mode_outlined,
          selected: current == ThemeMode.dark,
          onTap: () => appState.setThemeMode(ThemeMode.dark),
        ),
        _segmentButton(
          label: tr('settings.theme_system'),
          icon: Icons.brightness_auto_outlined,
          selected: current == ThemeMode.system,
          onTap: () => appState.setThemeMode(ThemeMode.system),
        ),
      ],
    );
  }

  // =============================================================
  // LANGUE (FR / EN)
  // =============================================================

  Widget _buildLanguageToggle(TSurfaceColors colors) {
    final current = appState.language;
    return Row(
      children: [
        _segmentButton(
          label: 'Francais',
          icon: Icons.language,
          selected: current == AppLanguage.fr,
          onTap: () => appState.setLanguage(AppLanguage.fr),
        ),
        _segmentButton(
          label: 'English',
          icon: Icons.language,
          selected: current == AppLanguage.en,
          onTap: () => appState.setLanguage(AppLanguage.en),
        ),
      ],
    );
  }

  // =============================================================
  // AUDIO (music + SFX)
  // =============================================================

  Widget _buildAudioToggles(String Function(String) tr) {
    final audio = ref.read(audioServiceProvider);

    // StreamBuilder pour rester reactif aux changements.
    return Column(
      children: [
        StreamBuilder<bool>(
          stream: audio.musicEnabledStream,
          initialData: audio.musicEnabled,
          builder: (context, snap) {
            final enabled = snap.data ?? true;
            return _buildSwitchRow(
              icon: Icons.music_note_rounded,
              label: tr('settings.music'),
              color: TColors.info,
              value: enabled,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                audio.setMusicEnabled(v);
              },
            );
          },
        ),
        const SizedBox(height: TSpacing.sm),
        StreamBuilder<bool>(
          stream: audio.sfxEnabledStream,
          initialData: audio.sfxEnabled,
          builder: (context, snap) {
            final enabled = snap.data ?? true;
            return _buildSwitchRow(
              icon: Icons.volume_up_rounded,
              label: tr('settings.sfx'),
              color: TColors.primary,
              value: enabled,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                audio.setSfxEnabled(v);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = TColors.of(context);
    return AppCard.glass(
      child: Row(
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: TColors.primary,
          ),
        ],
      ),
    );
  }

  // =============================================================
  // SEGMENT BUTTON (pour theme / langue)
  // =============================================================

  Widget _segmentButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = TColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: TDuration.quick,
          height: 56,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? TColors.primary : Colors.transparent,
            borderRadius: TRadius.mdAll,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? colors.textOnBrand : colors.textSecondary,
              ),
              const SizedBox(height: TSpacing.xxs),
              Text(
                label,
                style: TTypography.labelMd(
                  color: selected ? colors.textOnBrand : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // ROW GENERIQUE (pour cartes de navigation)
  // =============================================================

  Widget _row({
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
  // SIGN OUT
  // =============================================================

  Future<void> _confirmSignOut(
    BuildContext context,
    String Function(String) tr,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      ),
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
