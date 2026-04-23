// =============================================================
// FICHIER : lib/presentation/wireframes/t_new_password_page.dart
// ROLE   : Saisie du nouveau mot de passe apres clic sur lien email
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - PageScaffold avec titre + back auto
//   - AppTextField avec toggle visibility integre (plus de code maison)
//   - Indicateur de force du mdp (PasswordStrengthMeter extrait)
//   - Validation temps reel (mdp ≥ 6 + match)
//   - Succes : animation check bounce + SnackBar + redirection
//   - Copy enfant-friendly "bien fort"
//
// CONTRAT :
// ---------
// Cette page est push automatiquement par TWireframeApp quand
// supabase.auth.onAuthStateChange emet AuthChangeEvent.passwordRecovery
// (declenche par DeepLinkService apres le clic dans l'email).
//
// A ce moment, l'utilisateur a une session "recovery" active qui
// autorise supabase.auth.updateUser(password: ...) mais rien d'autre.
// =============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trialgo/core/design_system/tokens/brand.dart';
import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/app_text_field.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/password_strength_meter.dart';
import 'package:trialgo/presentation/wireframes/t_auth_gate.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


/// Ecran de saisie du nouveau mot de passe apres un reset.
class TNewPasswordPage extends StatefulWidget {
  const TNewPasswordPage({super.key});

  @override
  State<TNewPasswordPage> createState() => _TNewPasswordPageState();
}

class _TNewPasswordPageState extends State<TNewPasswordPage> {

  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();

  bool _isLoading = false;
  String? _newPwdError;
  String? _confirmPwdError;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    // Rebuild a chaque frappe pour mettre a jour la force du mdp
    // et reevaluer le match de la confirmation.
    _newPwdController.addListener(_onChange);
    _confirmPwdController.addListener(_onChange);
  }

  void _onChange() {
    // Efface les erreurs inline des que l'utilisateur retape.
    if (_newPwdError != null || _confirmPwdError != null) {
      setState(() {
        _newPwdError = null;
        _confirmPwdError = null;
      });
    } else {
      // Rebuild quand meme pour le strength meter / confirmation inline.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _handleUpdate
  // =============================================================

  Future<void> _handleUpdate() async {
    final pwd = _newPwdController.text;
    final confirm = _confirmPwdController.text;
    final tr = TLocale.of(context);

    // --- Validation ---
    if (pwd.length < 6) {
      setState(() => _newPwdError = tr('newpwd.error_min'));
      return;
    }
    if (pwd != confirm) {
      setState(() => _confirmPwdError = tr('newpwd.error_mismatch'));
      return;
    }

    setState(() {
      _isLoading = true;
      _globalError = null;
    });

    try {
      await supabase.auth.updateUser(UserAttributes(password: pwd));

      if (!mounted) return;
      // Celebration legere : SnackBar success + retour immediat a Auth.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: TSpacing.sm),
              Expanded(child: Text(tr('newpwd.success_snack'))),
            ],
          ),
          backgroundColor: TColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigation : push AuthGate en racine (l'utilisateur peut
      // devoir se reconnecter avec son nouveau mdp).
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TAuthGate()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _globalError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _globalError = TLocale.of(context)('forgot.error_network'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);

    // Bloque le back OS pendant l'appel reseau pour eviter un
    // pop au milieu d'un updateUser qui laisserait l'UI dans un
    // etat incoherent.
    return PopScope(
      canPop: !_isLoading,
      child: PageScaffold(
        title: tr('newpwd.title'),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: TSpacing.xxl,
            vertical: TSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TSpacing.xl),

              // --- Icone cercle orange gradient ---
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: TBrand.primary,
                    boxShadow: TElevation.glowPrimary,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: TSpacing.xl),

              // --- Titre + copy enfant-friendly ---
              Text(
                tr('newpwd.hero_title'),
                textAlign: TextAlign.center,
                style: TTypography.headlineLg(color: colors.textPrimary),
              ),
              const SizedBox(height: TSpacing.xxl),

              // --- Champ nouveau mdp ---
              AppTextField(
                controller: _newPwdController,
                label: tr('newpwd.field_new'),
                hint: tr('newpwd.field_hint_new'),
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.next,
                errorText: _newPwdError,
                enabled: !_isLoading,
              ),
              const SizedBox(height: TSpacing.sm),

              // --- Strength meter (composant partage avec signup) ---
              PasswordStrengthMeter(password: _newPwdController.text),
              const SizedBox(height: TSpacing.lg),

              // --- Champ confirmation ---
              AppTextField(
                controller: _confirmPwdController,
                label: tr('newpwd.field_confirm'),
                hint: tr('newpwd.field_hint_confirm'),
                prefixIcon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleUpdate(),
                errorText: _confirmPwdError,
                enabled: !_isLoading,
              ),
              const SizedBox(height: TSpacing.xl),

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

              // --- Bouton enregistrer ---
              AppButton.primary(
                label: tr('newpwd.cta_save'),
                icon: Icons.check_rounded,
                isLoading: _isLoading,
                fullWidth: true,
                size: AppButtonSize.lg,
                onPressed: _handleUpdate,
              ),
              const SizedBox(height: TSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
