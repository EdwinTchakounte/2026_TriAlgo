// =============================================================
// FICHIER : lib/presentation/wireframes/t_auth_page.dart
// ROLE   : Ecran connexion/inscription premium (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// Design premium : mascotte en arriere-plan, champs modernes
// avec glassmorphism, transitions fluides entre login/signup.
//
// REFERENCE : Recueil v3.0, section 12.3
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_activation_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';

/// Ecran d'authentification premium.
///
/// Design epure avec mascotte, champs au style glassmorphism,
/// et bascule fluide entre connexion et inscription.
class TAuthPage extends ConsumerStatefulWidget {
  const TAuthPage({super.key});

  @override
  ConsumerState<TAuthPage> createState() => _TAuthPageState();
}

class _TAuthPageState extends ConsumerState<TAuthPage> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _handleAuth
  // =============================================================
  // Gere la connexion ou l'inscription via Supabase.
  //
  // Si _isLogin == true  : signInWithPassword
  // Si _isLogin == false : signUp + auto sign-in
  //
  // En cas de succes, navigue vers TActivationPage.
  // En cas d'erreur, affiche un SnackBar avec le message.
  // =============================================================

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validation basique des champs.
    if (email.isEmpty || password.isEmpty) {
      _showError('Email et mot de passe requis');
      return;
    }
    if (password.length < 6) {
      _showError('Mot de passe : minimum 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileService = ref.read(profileServiceProvider);

      if (_isLogin) {
        // CONNEXION : utilisateur existant
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        // Charger le profil (le device check se fait au moment de
        // l'activation via la fonction SQL activate_code, pas ici).
        await profileService.loadProfile();
      } else {
        // INSCRIPTION : nouveau compte
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        // Si Supabase exige la verification email, la session est null.
        // En dev, on tente une connexion immediate.
        if (response.session == null) {
          await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
        }

        // Creer le profil immediatement (sans device_id, sera rempli
        // lors de l'activation du code).
        await profileService.createProfile(username: email.split('@').first);
      }

      // Succes : naviguer vers la page d'activation.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TActivationPage()),
        );
      }
    } on AuthException catch (e) {
      // Erreur Supabase Auth (email deja pris, mauvais mdp, etc.).
      _showError(_translateAuthError(e.message));
    } catch (e) {
      // Erreur generique (reseau, etc.).
      _showError('Erreur : $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Affiche un SnackBar d'erreur en bas de l'ecran.
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Traduit les messages d'erreur Supabase en francais.
  String _translateAuthError(String englishMessage) {
    if (englishMessage.contains('already registered') ||
        englishMessage.contains('already in use')) {
      return 'Cet email est deja utilise';
    }
    if (englishMessage.contains('Invalid login credentials')) {
      return 'Email ou mot de passe incorrect';
    }
    if (englishMessage.contains('Email not confirmed')) {
      return 'Email non confirme. Verifiez votre boite mail.';
    }
    if (englishMessage.contains('weak') ||
        englishMessage.contains('at least')) {
      return 'Mot de passe trop faible';
    }
    return englishMessage;
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1A), Color(0xFF1A1035), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height - padding.top - padding.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    // --- Logo TRIALGO ---
                    Image.asset(
                      MockData.logo,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),

                    // --- Titre "TRIALGO" en gradient ---
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                      ).createShader(bounds),
                      child: const Text(
                        'TRIALGO',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // --- Sous-titre anime ---
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isLogin ? tr('auth.welcome_back') : tr('auth.join'),
                        key: ValueKey(_isLogin),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- Formulaire glassmorphism ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _emailController,
                            hint: tr('auth.email'),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _passwordController,
                            hint: tr('auth.password'),
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 20),

                          // --- Bouton principal gradient ---
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleAuth,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLogin
                                            ? tr('auth.login')
                                            : tr('auth.signup'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- Separateur "ou" ---
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.12),
                              ]),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            tr('auth.or'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- Bouton Google ---
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          // Google OAuth pas configure dans cette demo.
                          // Affiche un message a l'utilisateur.
                          _showError(
                            'Google OAuth a configurer. '
                            'Utilisez email + mot de passe pour le test.',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.03),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('G', style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                )),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(tr('auth.google'), style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            )),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- Bascule login/signup ---
                    GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(text: _isLogin ? tr('auth.no_account') : tr('auth.has_account')),
                              TextSpan(
                                text: _isLogin ? tr('auth.signup_link') : tr('auth.login_link'),
                                style: const TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Construit un champ de texte au style moderne.
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.5),
        ),
      ),
    );
  }
}
