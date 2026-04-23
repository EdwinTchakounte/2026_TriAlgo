// =============================================================
// FICHIER : lib/presentation/wireframes/t_edit_username_page.dart
// ROLE   : Page de modification du pseudo (sous-page Parametres)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Page de modification du pseudo joueur.
///
/// Accessible depuis Parametres > Modifier le pseudo.
/// Le joueur peut saisir un nouveau pseudo et le valider.
class TEditUsernamePage extends StatefulWidget {
  const TEditUsernamePage({super.key});

  @override
  State<TEditUsernamePage> createState() => _TEditUsernamePageState();
}

class _TEditUsernamePageState extends State<TEditUsernamePage> {
  final _controller = TextEditingController(text: 'LionMaster');
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: TTheme.patterned(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Header.
                Row(
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
                    Text(tr('edit_username.title'), style: TTheme.titleStyle(size: 20)),
                  ],
                ),

                const SizedBox(height: 40),

                // Icone.
                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: TTheme.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: TTheme.blue, size: 36),
                  ),
                ),

                const SizedBox(height: 28),

                // Label.
                Text(tr('edit_username.label'), style: TTheme.microStyle(alpha: 0.4)),
                const SizedBox(height: 10),

                // Champ de saisie.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: TTheme.subtitleStyle(size: 18),
                    maxLength: 20,
                    decoration: InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white24, size: 18),
                        onPressed: () => _controller.clear(),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  '${_controller.text.length}/20 ${tr('edit_username.chars')}  ·  ${tr('edit_username.rules')}',
                  style: TTheme.bodyStyle(size: 12, color: Colors.white.withValues(alpha: 0.3)),
                ),

                const SizedBox(height: 32),

                // Bouton sauvegarder.
                SizedBox(
                  width: double.infinity, height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _controller.text.length >= 3
                          ? const LinearGradient(colors: [TTheme.orange, TTheme.gold])
                          : null,
                      color: _controller.text.length >= 3 ? null : Colors.white12,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ElevatedButton(
                      onPressed: _controller.text.length >= 3 ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tr('edit_username.save'), style: TTheme.buttonStyle()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      final tr = TLocale.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${tr('edit_username.saved')} ${_controller.text}'),
          ]),
          backgroundColor: TTheme.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}
