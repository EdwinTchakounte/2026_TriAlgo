// =============================================================
// FICHIER : lib/presentation/wireframes/t_forgot_password_page.dart
// ROLE   : Ecran "mot de passe oublie" (saisie email)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// FLUX UTILISATEUR :
// ------------------
// 1. Depuis la page d'auth, l'utilisateur clique "Mot de passe oublie ?"
// 2. Il arrive ici, saisit son email
// 3. Il clique "Envoyer le lien"
// 4. Supabase envoie un email avec un lien "trialgo://reset-password..."
// 5. On affiche une confirmation "Email envoye, consultez votre boite"
// 6. L'utilisateur ferme l'app, clique sur le lien dans l'email
// 7. L'app se rouvre, le DeepLinkService capture l'URI, Supabase
//    emet un evenement "passwordRecovery", et on navigue vers
//    TNewPasswordPage automatiquement (cf. TWireframeApp).
// =============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';

/// Ecran de demande de reinitialisation de mot de passe.
class TForgotPasswordPage extends StatefulWidget {
  const TForgotPasswordPage({super.key});

  @override
  State<TForgotPasswordPage> createState() => _TForgotPasswordPageState();
}

class _TForgotPasswordPageState extends State<TForgotPasswordPage> {

  // Controleur du champ email, libere dans dispose().
  final _emailController = TextEditingController();

  // True pendant l'appel reseau a Supabase (affiche le spinner).
  bool _isLoading = false;

  // True apres un envoi reussi : on bascule sur l'ecran de confirmation.
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _handleReset
  // =============================================================
  // Appelle Supabase pour envoyer l'email de reset.
  //
  // Le parametre redirectTo est CRITIQUE : c'est l'URI que Supabase
  // inclura dans le lien de l'email, et qui doit correspondre
  // au scheme configure dans AndroidManifest.xml / Info.plist.
  //
  // ATTENTION : ce redirectTo doit aussi etre ajoute dans
  //   Dashboard Supabase > Auth > URL Configuration > Redirect URLs
  // sinon Supabase refuse l'operation avec "redirect_to not allowed".
  // =============================================================

  /// Envoie l'email de reinitialisation.
  Future<void> _handleReset() async {
    final email = _emailController.text.trim();

    // Validation basique : l'email doit contenir au moins un "@".
    // Supabase fera une validation complete cote serveur.
    if (email.isEmpty || !email.contains('@')) {
      _showError('Email invalide');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Appel Supabase : declenche l'envoi d'un email avec un lien
      // "trialgo://reset-password#access_token=..." vers le deep-link.
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'trialgo://reset-password',
      );

      // Bascule vers l'ecran de confirmation.
      if (mounted) {
        setState(() => _emailSent = true);
      }
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

  /// SnackBar rouge en bas d'ecran pour signaler une erreur.
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
    // Helper de traduction partage avec toute l'app.
    final tr = TLocale.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Container(
        // Meme gradient que la page d'auth pour coherence visuelle.
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
            child: Column(
              children: [
                // --- Barre du haut : bouton retour ---
                // IconButton avec fleche <- pour pop la route courante.
                // Sauf si _isLoading (verrouille pendant l'envoi).
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),

                // Le reste bascule entre "formulaire" et "confirmation".
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      // AnimatedSwitcher : fade entre les 2 etats pour un
                      // rendu doux lors du passage formulaire -> confirmation.
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _emailSent
                            ? _buildConfirmation(tr)
                            : _buildForm(tr),
                      ),
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

  // =============================================================
  // WIDGET : _buildForm
  // =============================================================
  // Bloc saisie de l'email + bouton d'envoi.
  // Presente tant que _emailSent == false.
  // =============================================================

  /// Formulaire de saisie de l'email.
  Widget _buildForm(String Function(String) tr) {
    return Column(
      key: const ValueKey('form'), // Cle pour AnimatedSwitcher.
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Titre ---
        Text(
          tr('forgot.title'),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),

        // --- Description ---
        Text(
          tr('forgot.desc'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // --- Champ email (glassmorphism) ---
        // Container avec transparence + border pour le style "glass".
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: tr('auth.email'),
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
              ),
              border: InputBorder.none,
              // InputBorder.none : on gere le style via le Container parent.
              icon: Icon(
                Icons.email_outlined,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // --- Bouton "Envoyer le lien" ---
        SizedBox(
          width: double.infinity,
          height: 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleReset,
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
                      tr('forgot.send'),
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
    );
  }

  // =============================================================
  // WIDGET : _buildConfirmation
  // =============================================================
  // Etat de succes : email envoye, message rassurant + bouton retour.
  // =============================================================

  /// Ecran de confirmation apres envoi reussi.
  Widget _buildConfirmation(String Function(String) tr) {
    return Column(
      key: const ValueKey('sent'), // Cle pour AnimatedSwitcher.
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Icone cercle vert (succes) ---
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: Colors.white, size: 40),
        ),
        const SizedBox(height: 24),

        // --- Titre de confirmation ---
        Text(
          tr('forgot.sent_title'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // --- Description rassurante ---
        Text(
          tr('forgot.sent_desc'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // --- Bouton "Retour a la connexion" ---
        // OutlinedButton plus discret que le bouton primaire :
        // l'action principale etait l'envoi, desormais terminee.
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              tr('forgot.back_to_login'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
