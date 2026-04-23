// =============================================================
// FICHIER : lib/presentation/wireframes/t_edit_username_page.dart
// ROLE   : Modification du pseudo - refonte design system
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Avatar XL en hero pour identification
//   - AppTextField avec validation temps reel (longueur 2-20)
//   - CTA gradient "C'EST MON NOM" + retour ghost
//   - Appel reel a ProfileNotifier.updateUsername (au lieu du
//     placeholder qui ne sauvegardait rien)
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/app_text_field.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/user_avatar.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


class TEditUsernamePage extends ConsumerStatefulWidget {
  const TEditUsernamePage({super.key});

  @override
  ConsumerState<TEditUsernamePage> createState() =>
      _TEditUsernamePageState();
}

class _TEditUsernamePageState extends ConsumerState<TEditUsernamePage> {
  late final TextEditingController _controller;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-remplit avec le pseudo courant.
    _controller =
        TextEditingController(text: ref.read(profileProvider).username);
    _controller.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    final tr = TLocale.of(context);
    if (raw.length < 2) {
      setState(() => _error = tr('editpseudo.min'));
      return;
    }
    if (raw.length > 20) {
      setState(() => _error = tr('editpseudo.max'));
      return;
    }
    setState(() => _isSaving = true);

    try {
      await ref.read(profileProvider.notifier).updateUsername(raw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('editpseudo.saved')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = tr('editpseudo.error_net'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final colors = TColors.of(context);
    final tr = TLocale.of(context);

    return PageScaffold(
      title: tr('editpseudo.title'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.xxl,
          vertical: TSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: TSpacing.xl),

            // --- Avatar XL ---
            Center(
              child: UserAvatar(
                avatarId: profile.avatarId,
                // On utilise le texte en cours de saisie pour que
                // l'initiale suive la frappe en temps reel (ludique).
                username: _controller.text.isEmpty
                    ? profile.username
                    : _controller.text,
                size: 110,
                showHalo: true,
              ),
            ),
            const SizedBox(height: TSpacing.xl),

            // --- Titre conversationnel ---
            Text(
              tr('editpseudo.hero'),
              textAlign: TextAlign.center,
              style: TTypography.headlineLg(color: colors.textPrimary),
            ),
            const SizedBox(height: TSpacing.xxl),

            // --- Champ + feedback ---
            AppTextField(
              controller: _controller,
              label: tr('editpseudo.label'),
              hint: tr('editpseudo.hint'),
              prefixIcon: Icons.person_outline,
              maxLength: 20,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              errorText: _error,
              enabled: !_isSaving,
              // onChanged implicite via le listener de _controller :
              // ca met a jour l'avatar XL en live.
            ),
            const SizedBox(height: TSpacing.xxl),

            // --- Bouton principal ---
            AppButton.primary(
              label: tr('editpseudo.cta_save'),
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              fullWidth: true,
              size: AppButtonSize.lg,
              onPressed: _save,
            ),
            const SizedBox(height: TSpacing.sm),

            // --- Retour ghost ---
            AppButton.ghost(
              label: tr('editpseudo.cta_cancel'),
              fullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
