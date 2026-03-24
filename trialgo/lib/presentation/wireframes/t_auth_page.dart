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
import 'package:trialgo/presentation/wireframes/t_activation_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';

/// Ecran d'authentification premium.
///
/// Design epure avec mascotte, champs au style glassmorphism,
/// et bascule fluide entre connexion et inscription.
class TAuthPage extends StatefulWidget {
  const TAuthPage({super.key});

  @override
  State<TAuthPage> createState() => _TAuthPageState();
}

class _TAuthPageState extends State<TAuthPage> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final size = MediaQuery.of(context).size;
    // "MediaQuery.of(context).size" : recupere les dimensions de l'ecran.
    // Permet d'adapter le layout a la taille reelle de l'appareil.

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0C29), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // ScrollView pour eviter l'overflow quand le clavier apparait.
            child: SizedBox(
              // Hauteur minimale = hauteur de l'ecran (moins SafeArea).
              // Garantit que le contenu remplit l'ecran meme sans scroll.
              height: size.height - MediaQuery.of(context).padding.top,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // --- Logo officiel TRIALGO ---
                    Image.asset(
                      MockData.logo,
                      height: size.height * 0.18,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 6),

                    AnimatedSwitcher(
                      // "AnimatedSwitcher" anime le changement de texte.
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isLogin ? tr('auth.welcome_back') : tr('auth.join'),
                        key: ValueKey(_isLogin),
                        // La "key" permet a AnimatedSwitcher de detecter
                        // que le widget a change et de jouer l'animation.
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // --- Conteneur glassmorphism pour le formulaire ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        // Effet glassmorphism : fond semi-transparent + flou.
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          // --- Champ Email ---
                          _buildTextField(
                            controller: _emailController,
                            hint: tr('auth.email'),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 14),

                          // --- Champ Mot de passe ---
                          _buildTextField(
                            controller: _passwordController,
                            hint: tr('auth.password'),
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),

                          const SizedBox(height: 22),

                          // --- Bouton principal ---
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF6B35), Color(0xFFFF8F5E)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const TActivationPage()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  _isLogin ? tr('auth.login') : tr('auth.signup'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- Separateur ---
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(tr('auth.or'), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.12))),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // --- Bouton Google ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const TActivationPage()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(width: 10),
                            Text(tr('auth.google'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // --- Bascule login/signup ---
                    GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
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
