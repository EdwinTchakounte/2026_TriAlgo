// =============================================================
// FICHIER : login_page.dart
// ROLE    : Ecran de connexion admin
// =============================================================
//
// L'admin saisit email + password. On appelle authProvider.signIn,
// qui :
//   - tente le signIn Supabase
//   - fetch user_profiles pour verifier is_admin
//   - signOut si pas admin et renvoie NotAdminFailure
//
// Design :
//   - Fond doux (gradient subtil)
//   - Logo entoure d'un halo bicouche (2 cercles concentriques)
//   - Formulaire dans une "card" arrondie avec ombre legere
//     -> sensation de profondeur sans agressivite
//   - Responsive : ResponsiveLayout centre + contraint la largeur
//     du formulaire sur tablette
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth.status == AuthStatus.loading;
    // Padding horizontal recommande selon la taille d'ecran.
    final hPad = Breakpoints.horizontalPadding(context);

    return Scaffold(
      // Fond gradient TRES doux : passe de white a un brand
      // ultra-dilue. Donne de la chaleur sans crier.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppColors.brand.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            // ConstrainedBox pour ne pas etirer le form sur tablette.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(hPad, 32, hPad, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ------------------------------------------
                      // BLOC HEADER : logo + titre + sous-titre
                      // ------------------------------------------
                      _Logo(),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'TRIALGO Admin',
                          style: AppTextStyles.hero(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Studio de creation de jeux',
                          style: AppTextStyles.caption(),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ------------------------------------------
                      // CARD : formulaire (effet eleve, doux)
                      // ------------------------------------------
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ERROR BANNER
                            if (auth.errorMessage != null) ...[
                              _ErrorBanner(message: auth.errorMessage!),
                              const SizedBox(height: 14),
                            ],

                            // EMAIL
                            TextFormField(
                              controller: _emailCtrl,
                              enabled: !isLoading,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                                hintText: 'votre@email.com',
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Email requis';
                                if (!s.contains('@')) return 'Email invalide';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // PASSWORD
                            TextFormField(
                              controller: _passwordCtrl,
                              enabled: !isLoading,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(
                                      () => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) {
                                if ((v ?? '').isEmpty) {
                                  return 'Mot de passe requis';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // CTA
                            ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Se connecter'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // PIED DE PAGE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Acces reserve aux administrateurs',
                            style: AppTextStyles.caption(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// _Logo : halo bicouche autour de l'icone marque
// =============================================================
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo exterieur (large, peu opaque).
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
          ),
          // Halo interieur (plus petit, plus dense).
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_mosaic,
              size: 40,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// _ErrorBanner : message d'erreur stylé (auth failed / not admin)
// =============================================================
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption().copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
