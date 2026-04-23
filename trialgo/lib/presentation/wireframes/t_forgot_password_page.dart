// =============================================================
// FICHIER : lib/presentation/wireframes/t_forgot_password_page.dart
// ROLE   : Ecran "mot de passe oublie" refondu
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - PageScaffold avec titre + back auto (remplace layout manuel)
//   - Mascotte duo flottante (chaleur vs ecran nu precedent)
//   - Copy conversationnelle "Pas de souci !" (vs "Entrez votre email")
//   - AppTextField + AppButton (design system, plus d'inline CSS)
//   - Ecran confirmation CELEBRATOIRE (cercle success + mascot trio)
//   - Validation email temps reel
//
// CONTRAT SUPABASE :
// ------------------
// Appelle supabase.auth.resetPasswordForEmail avec redirectTo =
// 'trialgo://reset-password' qui declenche le deep-link documente
// dans data/services/deep_link_service.dart.
// =============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/app_text_field.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';


/// Ecran de demande de reinitialisation de mot de passe.
class TForgotPasswordPage extends StatefulWidget {
  const TForgotPasswordPage({super.key});

  @override
  State<TForgotPasswordPage> createState() => _TForgotPasswordPageState();
}

class _TForgotPasswordPageState extends State<TForgotPasswordPage>
    with SingleTickerProviderStateMixin {

  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _emailError;
  String? _globalError;

  /// Flottement mascotte (memes 4s sinus que l'Auth, coherent).
  late final AnimationController _mascotFloat;

  @override
  void initState() {
    super.initState();
    _mascotFloat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    // Efface l'erreur de champ des que l'utilisateur retape.
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() => _emailError = null);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _mascotFloat.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _handleReset
  // =============================================================

  Future<void> _handleReset() async {
    final email = _emailController.text.trim();
    final tr = TLocale.of(context);

    // Validation temps reel simple (format email minimal).
    if (email.isEmpty) {
      setState(() => _emailError = tr('forgot.email_hint'));
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _emailError = tr('forgot.invalid_email'));
      return;
    }

    setState(() {
      _isLoading = true;
      _globalError = null;
    });

    try {
      // Appel Supabase. redirectTo doit etre enregistre dans le
      // Dashboard Supabase -> Auth -> URL Configuration -> Redirect URLs.
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'trialgo://reset-password',
      );
      if (mounted) setState(() => _emailSent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _globalError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _globalError = tr('forgot.error_network'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    return PageScaffold(
      title: tr('forgot.title_refonte'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.xxl,
          vertical: TSpacing.lg,
        ),
        // AnimatedSwitcher : fade entre formulaire et confirmation.
        child: AnimatedSwitcher(
          duration: TDuration.normal,
          child: _emailSent ? _buildConfirmation() : _buildForm(),
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : ETAT FORMULAIRE
  // =============================================================

  Widget _buildForm() {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);

    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Logo TRIALGO (coherence avec auth page) ---
        _buildMascot(MockData.logo, height: 100),
        const SizedBox(height: TSpacing.xl),

        // --- Copy conversationnelle ---
        Text(
          tr('forgot.hero_title'),
          textAlign: TextAlign.center,
          style: TTypography.headlineLg(color: colors.textPrimary),
        ),
        const SizedBox(height: TSpacing.xs),
        Text(
          tr('forgot.hero_body'),
          textAlign: TextAlign.center,
          style: TTypography.bodyMd(color: colors.textSecondary),
        ),
        const SizedBox(height: TSpacing.xl),

        // --- Champ email ---
        AppTextField(
          controller: _emailController,
          label: tr('auth.email'),
          hint: 'tu@exemple.com',
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleReset(),
          errorText: _emailError,
          enabled: !_isLoading,
        ),
        const SizedBox(height: TSpacing.lg),

        // --- Erreur globale (reseau / Supabase) ---
        if (_globalError != null) ...[
          Container(
            padding: const EdgeInsets.all(TSpacing.md),
            decoration: BoxDecoration(
              color: Color.fromARGB(
                0x26,
                TColors.error.r.round(),
                TColors.error.g.round(),
                TColors.error.b.round(),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: Color.fromARGB(
                  0x4D,
                  TColors.error.r.round(),
                  TColors.error.g.round(),
                  TColors.error.b.round(),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: TColors.error, size: 20),
                const SizedBox(width: TSpacing.sm),
                Expanded(
                  child: Text(_globalError!,
                      style: TTypography.bodySm(color: TColors.error)),
                ),
              ],
            ),
          ),
          const SizedBox(height: TSpacing.md),
        ],

        // --- Bouton envoi ---
        AppButton.primary(
          label: tr('forgot.cta_send'),
          trailingIcon: Icons.arrow_forward_rounded,
          isLoading: _isLoading,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: _handleReset,
        ),
      ],
    );
  }

  // =============================================================
  // WIDGET : ETAT CONFIRMATION
  // =============================================================

  Widget _buildConfirmation() {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);

    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Cercle vert success avec icone mail ---
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [TColors.success, Color(0xFF81D884)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: TElevation.glowSuccess,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: TSpacing.xxl),

        // --- Titre celebration ---
        Text(
          tr('forgot.sent_title'),
          textAlign: TextAlign.center,
          style: TTypography.headlineLg(color: colors.textPrimary),
        ),
        const SizedBox(height: TSpacing.sm),

        // --- Description rassurante ---
        Text(
          tr('forgot.sent_body'),
          textAlign: TextAlign.center,
          style: TTypography.bodyMd(color: colors.textSecondary),
        ),
        const SizedBox(height: TSpacing.xxl),

        // --- Mascotte trio (sensation d'etre accompagne) ---
        _buildMascot(MockData.mascotMain, height: 100),
        const SizedBox(height: TSpacing.xxl),

        // --- Bouton retour ---
        AppButton.secondary(
          label: tr('forgot.cta_back_login'),
          icon: Icons.arrow_back_rounded,
          fullWidth: true,
          size: AppButtonSize.lg,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // =============================================================
  // WIDGET : mascotte avec float subtil
  // =============================================================

  Widget _buildMascot(String asset, {required double height}) {
    return AnimatedBuilder(
      animation: _mascotFloat,
      builder: (context, child) {
        final offset = Tween<double>(begin: -4, end: 4)
            .chain(CurveTween(curve: TCurve.easeInOut))
            .evaluate(_mascotFloat);
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: Center(
        child: Image.asset(asset, height: height, fit: BoxFit.contain),
      ),
    );
  }
}
