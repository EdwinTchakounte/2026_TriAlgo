// =============================================================
// FICHIER : lib/presentation/wireframes/t_settings_page.dart
// ROLE   : Parametres avec langue FR/EN + theme dark/light
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_app_state.dart';
import 'package:trialgo/presentation/wireframes/t_auth_page.dart';
import 'package:trialgo/presentation/wireframes/t_edit_username_page.dart';
import 'package:trialgo/presentation/wireframes/t_avatar_page.dart';
import 'package:trialgo/presentation/wireframes/t_help_page.dart';
import 'package:trialgo/presentation/wireframes/t_legal_page.dart';

/// Parametres avec langue, theme, sous-pages.
class TSettingsPage extends StatefulWidget {
  const TSettingsPage({super.key});

  @override
  State<TSettingsPage> createState() => _TSettingsPageState();
}

class _TSettingsPageState extends State<TSettingsPage> {
  bool _soundOn = true;
  bool _musicOn = true;
  bool _notifOn = true;

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final currentLang = TLocale.languageOf(context);
    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // Header fixe.
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
                    Text(tr('settings.title'), style: TTheme.titleStyle(size: 20)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Body scrollable.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===========================================
                      // LANGUE
                      // ===========================================
                      Text(tr('settings.language'), style: TTheme.microStyle(alpha: 0.35)),
                      const SizedBox(height: 10),

                      // Selecteur de langue (2 boutons cote a cote).
                      Row(
                        children: [
                          _langButton(
                            label: tr('settings.lang_fr'),
                            flag: '🇫🇷',
                            isActive: currentLang == AppLanguage.fr,
                            onTap: () => appState.setLanguage(AppLanguage.fr),
                          ),
                          const SizedBox(width: 10),
                          _langButton(
                            label: tr('settings.lang_en'),
                            flag: '🇬🇧',
                            isActive: currentLang == AppLanguage.en,
                            onTap: () => appState.setLanguage(AppLanguage.en),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ===========================================
                      // AUDIO
                      // ===========================================
                      Text(tr('settings.audio'), style: TTheme.microStyle(alpha: 0.35)),
                      const SizedBox(height: 10),
                      _switchTile(Icons.volume_up_rounded, tr('settings.sounds'), tr('settings.sounds_desc'), _soundOn, (v) => setState(() => _soundOn = v)),
                      const SizedBox(height: 8),
                      _switchTile(Icons.music_note_rounded, tr('settings.music'), tr('settings.music_desc'), _musicOn, (v) => setState(() => _musicOn = v)),

                      const SizedBox(height: 20),

                      // NOTIFICATIONS.
                      Text(tr('settings.notif'), style: TTheme.microStyle(alpha: 0.35)),
                      const SizedBox(height: 10),
                      _switchTile(Icons.notifications_active_rounded, tr('settings.notif_lives'), tr('settings.notif_desc'), _notifOn, (v) => setState(() => _notifOn = v)),

                      const SizedBox(height: 20),

                      // COMPTE.
                      Text(tr('settings.account'), style: TTheme.microStyle(alpha: 0.35)),
                      const SizedBox(height: 10),
                      _actionTile(Icons.edit_rounded, tr('settings.edit_pseudo'), 'LionMaster', () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TEditUsernamePage()));
                      }),
                      const SizedBox(height: 8),
                      _actionTile(Icons.camera_alt_rounded, tr('settings.edit_avatar'), tr('settings.no_avatar'), () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TAvatarPage()));
                      }),

                      const SizedBox(height: 20),

                      // A PROPOS.
                      Text(tr('settings.about'), style: TTheme.microStyle(alpha: 0.35)),
                      const SizedBox(height: 10),
                      _infoTile(Icons.info_outline_rounded, tr('settings.version'), '1.0.0'),
                      const SizedBox(height: 8),
                      _actionTile(Icons.description_outlined, tr('settings.legal'), tr('settings.legal_desc'), () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TLegalPage()));
                      }),
                      const SizedBox(height: 8),
                      _actionTile(Icons.help_outline_rounded, tr('settings.help'), tr('settings.help_desc'), () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const THelpPage()));
                      }),

                      const SizedBox(height: 32),

                      // Deconnexion.
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded, color: TTheme.red, size: 18),
                          label: Text(tr('settings.logout'), style: TTheme.subtitleStyle(color: TTheme.red, size: 14)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: TTheme.red.withValues(alpha: 0.35)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Center(
                        child: TextButton(
                          onPressed: () => _snack(tr('common.soon')),
                          child: Text(tr('settings.delete_account'), style: TTheme.bodyStyle(size: 12, color: Colors.white.withValues(alpha: 0.2))),
                        ),
                      ),
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

  // =============================================================
  // WIDGETS
  // =============================================================

  Widget _langButton({required String label, required String flag, required bool isActive, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? TTheme.orange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? TTheme.orange.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                label,
                style: TTheme.bodyStyle(
                  size: 13,
                  weight: FontWeight.w600,
                  color: isActive ? TTheme.orange : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile(IconData icon, String label, String sub, bool val, ValueChanged<bool> cb) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TTheme.bodyStyle(size: 13, weight: FontWeight.w600, color: Colors.white)),
              Text(sub, style: TTheme.bodyStyle(size: 11, color: Colors.white.withValues(alpha: 0.3))),
            ],
          )),
          Switch.adaptive(value: val, onChanged: cb, activeTrackColor: TTheme.orange),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, String sub, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TTheme.bodyStyle(size: 13, weight: FontWeight.w600, color: Colors.white)),
                if (sub.isNotEmpty) Text(sub, style: TTheme.bodyStyle(size: 11, color: Colors.white.withValues(alpha: 0.3))),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.15), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TTheme.bodyStyle(size: 13, weight: FontWeight.w600, color: Colors.white)),
          const Spacer(),
          Text(val, style: TTheme.bodyStyle(size: 13, color: Colors.white.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 1),
    ));
  }

  void _logout() {
    final tr = TLocale.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16163A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${tr('settings.logout')} ?', style: TTheme.subtitleStyle(size: 18)),
        content: Text(tr('settings.logout_confirm'), style: TTheme.bodyStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr('settings.cancel'))),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const TAuthPage()),
                (route) => false,
              );
            },
            child: Text(tr('settings.logout_action'), style: TTheme.bodyStyle(size: 14, weight: FontWeight.w600, color: TTheme.red)),
          ),
        ],
      ),
    );
  }
}
