// =============================================================
// FICHIER : lib/presentation/wireframes/t_new_password_page.dart
// ROLE   : Ecran "nouveau mot de passe" (apres clic sur lien email)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// COMMENT ON ARRIVE SUR CETTE PAGE ?
// ----------------------------------
// L'utilisateur a recu un email avec un lien "trialgo://reset-password..."
// Il clique dessus, l'OS rouvre TRIALGO, le DeepLinkService capte
// l'URI et le passe a supabase.auth.getSessionFromUrl(uri).
// Supabase emet ensuite un evenement AuthChangeEvent.passwordRecovery.
//
// TWireframeApp ecoute cet evenement et pousse cette page via le
// navigatorKey global. A ce moment, l'utilisateur a une session
// "recovery" limitee : il peut updateUser(password: ...) mais pas
// acceder aux autres operations protegees.
//
// FLUX UTILISATEUR :
// ------------------
// 1. Saisit nouveau mot de passe + confirmation
// 2. Clique "Enregistrer"
// 3. Supabase enregistre le nouveau mdp
// 4. On affiche une SnackBar de succes et on route vers la page d'auth
// 5. L'utilisateur peut maintenant se connecter avec son nouveau mdp
// =============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/wireframes/t_auth_gate.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';

/// Ecran de saisie du nouveau mot de passe apres un reset.
class TNewPasswordPage extends StatefulWidget {
  const TNewPasswordPage({super.key});

  @override
  State<TNewPasswordPage> createState() => _TNewPasswordPageState();
}

class _TNewPasswordPageState extends State<TNewPasswordPage> {

  // Controleurs des 2 champs mdp, liberes dans dispose().
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Spinner d'appel reseau.
  bool _isLoading = false;

  // Toggles de visibilite pour chaque champ (icone oeil).
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _handleUpdate
  // =============================================================
  // Valide la saisie puis appelle Supabase pour enregistrer le mdp.
  //
  // Pre-condition : l'utilisateur doit avoir une session active
  // en mode "recovery" (ce qui est le cas apres getSessionFromUrl).
  // Sinon l'appel updateUser leverait une AuthException.
  // =============================================================

  /// Enregistre le nouveau mot de passe cote Supabase.
  Future<void> _handleUpdate() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation : longueur minimale cote client (alignee sur celle
    // de la creation de compte dans t_auth_page.dart : 6 caracteres).
    if (newPassword.length < 6) {
      _showError('Mot de passe : minimum 6 caracteres');
      return;
    }

    // Validation : les deux saisies doivent etre identiques.
    // Garde-fou classique pour eviter une faute de frappe qui
    // enfermerait l'utilisateur avec un mdp qu'il ne connait pas.
    if (newPassword != confirmPassword) {
      _showError(TLocale.of(context)('newpwd.mismatch'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Appel Supabase : met a jour le mdp de l'utilisateur courant.
      // UserAttributes encapsule les champs modifiables (email,
      // password, data). Ici on ne change que password.
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // --- Succes ---
      // On affiche un SnackBar de confirmation puis on redirige
      // vers l'AuthGate qui routera automatiquement vers la home
      // si la session est toujours valide, ou la page d'auth sinon.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TLocale.of(context)('newpwd.success')),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // pushAndRemoveUntil : vide la pile et pose AuthGate en racine.
      // L'utilisateur ne peut plus "back" vers la page de reset.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TAuthGate()),
        (_) => false,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Erreur reseau');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// SnackBar rouge pour signaler une erreur de saisie ou reseau.
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

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    // WillPopScope : on bloque le back OS pendant l'appel reseau
    // pour eviter une navigation au milieu d'un updateUser.
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A1A),
        body: Container(
          // Meme gradient que les autres pages d'auth.
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0A1A),
                Color(0xFF1A1035),
                Color(0xFF0D1B2A),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Icone clef ---
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF6B35),
                              Color(0xFFF7C948),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.lock_reset,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 24),

                      // --- Titre + description ---
                      Text(
                        tr('newpwd.title'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('newpwd.desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // --- Champ "nouveau mot de passe" ---
                      _buildPasswordField(
                        controller: _newPasswordController,
                        hint: tr('newpwd.new'),
                        obscure: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                      const SizedBox(height: 12),

                      // --- Champ "confirmer mot de passe" ---
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        hint: tr('newpwd.confirm'),
                        obscure: _obscureConfirm,
                        onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                      const SizedBox(height: 20),

                      // --- Bouton "Enregistrer" ---
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF6B35),
                                Color(0xFFF7C948),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleUpdate,
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
                                    tr('newpwd.submit'),
                                    style: const TextStyle(
                                      fontSize: 15,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : _buildPasswordField
  // =============================================================
  // Factorise le style des 2 champs mdp : glassmorphism + icone cle
  // + bouton oeil pour toggler la visibilite.
  //
  // [obscure] pilote l'obfuscation (true = masque avec des puces).
  // [onToggle] est appele quand on clique l'icone oeil.
  // =============================================================

  /// Champ de saisie de mdp avec bouton "afficher/masquer".
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
          ),
          border: InputBorder.none,
          icon: Icon(
            Icons.lock_outline,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}
