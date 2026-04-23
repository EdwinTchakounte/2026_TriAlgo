// =============================================================
// FICHIER : lib/presentation/wireframes/t_auth_page.dart
// ROLE   : Ecran connexion/inscription - refonte pro enfant-friendly
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE PAR RAPPORT A LA VERSION PRECEDENTE :
// ----------------------------------------------
//   - Toggle segmente "SE CONNECTER / S'INSCRIRE" en HAUT
//     (plus d'ambiguite, plus decouvrable)
//   - Mascotte duo en entete (chaleureux, evite le doublon avec splash)
//   - Copy conversationnelle ("Content de te revoir !" / "Bienvenue !")
//   - Champs AppTextField (design system) avec labels au-dessus
//   - Indicateur de force du mdp en inscription (4 segments)
//   - Erreurs inline sous le champ (plus de SnackBar volatile)
//   - Bouton primaire full-width + icone fleche
//   - Lien "Mot de passe oublie ?" discret, login uniquement
//   - Validation temps reel (email regex, mdp ≥ 6)
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/app_text_field.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_activation_page.dart';
import 'package:trialgo/presentation/wireframes/t_forgot_password_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';


/// Ecran d'authentification refondu (login ou signup via toggle).
class TAuthPage extends ConsumerStatefulWidget {
  const TAuthPage({super.key});

  @override
  ConsumerState<TAuthPage> createState() => _TAuthPageState();
}

class _TAuthPageState extends ConsumerState<TAuthPage>
    with SingleTickerProviderStateMixin {

  /// Mode actuel : login (true) ou signup (false).
  bool _isLogin = true;

  /// Flag de chargement (pendant l'appel Supabase).
  bool _isLoading = false;

  /// Controleurs des 2 champs.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Erreurs inline sous chaque champ (null = pas d'erreur).
  String? _emailError;
  String? _passwordError;

  /// Erreur globale (generale au formulaire, ex: "email deja pris").
  String? _globalError;

  /// Controller de flottement pour la mascotte (sinusoide legere).
  late final AnimationController _mascotFloat;

  @override
  void initState() {
    super.initState();

    // Flottement mascotte : 3s reverse, pattern identique au splash
    // pour une continuite visuelle de l'app.
    _mascotFloat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Revalide les champs a chaque frappe : feedback d'erreur
    // disparait des que l'utilisateur corrige.
    _passwordController.addListener(() {
      if (_passwordError != null) {
        setState(() => _passwordError = null);
      }
      // Rebuild pour mettre a jour l'indicateur de force (signup).
      if (!_isLogin) setState(() {});
    });
    _emailController.addListener(() {
      if (_emailError != null) {
        setState(() => _emailError = null);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mascotFloat.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _toggleMode
  // =============================================================
  // Bascule entre login et signup. Efface les erreurs pour repartir
  // sur une ardoise propre (ex: l'email etait invalide en login,
  // on passe en signup, l'erreur ne fait plus sens).
  // =============================================================

  void _toggleMode(bool loginMode) {
    if (_isLogin == loginMode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isLogin = loginMode;
      _emailError = null;
      _passwordError = null;
      _globalError = null;
    });
  }

  // =============================================================
  // METHODE : _validate
  // =============================================================
  // Validation cote client avant l'appel Supabase.
  // Retourne true si le formulaire est valide, false sinon.
  // Met a jour les champs d'erreur inline.
  // =============================================================

  bool _validate() {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;
    bool ok = true;

    final tr = TLocale.of(context);
    // Email : non vide + regex simple (une '@' + un '.').
    if (email.isEmpty) {
      setState(() => _emailError = tr('auth.email_empty'));
      ok = false;
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _emailError = tr('auth.email_invalid'));
      ok = false;
    }

    // Mot de passe : minimum 6 caracteres (cote Supabase aussi).
    if (pwd.isEmpty) {
      setState(() => _passwordError = tr('auth.password_empty'));
      ok = false;
    } else if (pwd.length < 6) {
      setState(() => _passwordError = tr('auth.password_min'));
      ok = false;
    }

    return ok;
  }

  // =============================================================
  // METHODE : _handleAuth
  // =============================================================
  // Execute login ou signup selon _isLogin.
  //
  // CAS D'ERREUR GERES :
  //   - Email deja pris (signup)
  //   - Mauvais identifiants (login)
  //   - Email non confirme
  //   - Erreur reseau generique
  //
  // SUCCES :
  //   - Profil cree immediatement (signup)
  //   - Navigation vers page d'activation
  // =============================================================

  Future<void> _handleAuth() async {
    // Pre-validation client.
    if (!_validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _globalError = null;
    });

    try {
      final profileService = ref.read(profileServiceProvider);

      if (_isLogin) {
        // CONNEXION
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        // Charger le profil : le device binding se fait a l'activation,
        // pas ici.
        await profileService.loadProfile();
      } else {
        // INSCRIPTION
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
        );
        // Si la verification email est active, signUp ne cree pas de
        // session. En dev/prod sans verif, on tente le login direct.
        if (response.session == null) {
          await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
        }
        // Profil initial : username = prefixe de l'email.
        await profileService.createProfile(
          username: email.split('@').first,
        );
      }

      // Succes : on navigue vers l'activation du code.
      if (mounted) {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TActivationPage()),
        );
      }
    } on AuthException catch (e) {
      // Erreurs metier Supabase : on les traduit pour l'enfant.
      if (mounted) {
        setState(() => _globalError = _translateError(e.message));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _globalError = TLocale.of(context)('auth.error_network'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Traduit les messages Supabase en langue courante.
  String _translateError(String raw) {
    final tr = TLocale.of(context);
    if (raw.contains('already registered') ||
        raw.contains('already in use')) {
      return tr('auth.error_taken');
    }
    if (raw.contains('Invalid login credentials')) {
      return tr('auth.error_invalid');
    }
    if (raw.contains('Email not confirmed')) {
      return tr('auth.error_unconfirmed');
    }
    if (raw.contains('weak') || raw.contains('at least')) {
      return tr('auth.error_weak');
    }
    return raw;
  }

  // =============================================================
  // METHODE : _passwordStrength
  // =============================================================
  // Calcule un score 0-4 pour l'indicateur de force du mot de passe.
  //
  // REGLES (simples et comprehensibles pour un enfant) :
  //   +1 si >= 6 caracteres
  //   +1 si contient chiffre
  //   +1 si contient lettre minuscule ET majuscule
  //   +1 si contient caractere special (!@#$%^&*...)
  // =============================================================

  /// Retourne un score 0 (vide) a 4 (tres fort).
  int _passwordStrength(String pwd) {
    if (pwd.isEmpty) return 0;
    int score = 0;
    if (pwd.length >= 6) score++;
    if (RegExp(r'\d').hasMatch(pwd)) score++;
    if (RegExp(r'[a-z]').hasMatch(pwd) &&
        RegExp(r'[A-Z]').hasMatch(pwd)) {
      score++;
    }
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=]').hasMatch(pwd)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);

    return PageScaffold(
      // Pas de titre : la page est une entree, pas une sous-page.
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.xxl,
          vertical: TSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Mascotte duo qui flotte legerement ---
            _buildMascot(),
            const SizedBox(height: TSpacing.xl),

            // --- Titre conversationnel (change selon login/signup) ---
            AnimatedSwitcher(
              duration: TDuration.normal,
              child: Text(
                _isLogin
                    ? TLocale.of(context)('auth.welcome_back_hero')
                    : TLocale.of(context)('auth.welcome_new_hero'),
                key: ValueKey(_isLogin),
                textAlign: TextAlign.center,
                style: TTypography.headlineLg(color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: TSpacing.xs),
            Text(
              _isLogin
                  ? TLocale.of(context)('auth.welcome_back_sub')
                  : TLocale.of(context)('auth.welcome_new_sub'),
              textAlign: TextAlign.center,
              style: TTypography.bodyMd(color: colors.textSecondary),
            ),
            const SizedBox(height: TSpacing.xl),

            // --- Toggle segmente SE CONNECTER / S'INSCRIRE ---
            _buildSegmentedToggle(),
            const SizedBox(height: TSpacing.xl),

            // --- Champ email ---
            AppTextField(
              controller: _emailController,
              label: TLocale.of(context)('auth.email'),
              hint: TLocale.of(context)('auth.email_hint'),
              prefixIcon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _emailError,
              enabled: !_isLoading,
            ),
            const SizedBox(height: TSpacing.lg),

            // --- Champ mot de passe ---
            AppTextField(
              controller: _passwordController,
              label: TLocale.of(context)('auth.password'),
              hint: _isLogin
                  ? TLocale.of(context)('auth.password_hint_signin')
                  : TLocale.of(context)('auth.password_hint_signup'),
              prefixIcon: Icons.lock_outline,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleAuth(),
              errorText: _passwordError,
              enabled: !_isLoading,
            ),

            // --- Indicateur de force (signup uniquement) ---
            if (!_isLogin) ...[
              const SizedBox(height: TSpacing.sm),
              _buildStrengthMeter(),
            ],

            // --- Lien "Mot de passe oublie" (login uniquement) ---
            if (_isLogin) ...[
              const SizedBox(height: TSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TForgotPasswordPage(),
                            ),
                          );
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TSpacing.sm,
                      vertical: TSpacing.xs,
                    ),
                  ),
                  child: Text(
                    'Mot de passe oublie ?',
                    style: TTypography.labelLg(color: TColors.primary),
                  ),
                ),
              ),
            ],

            const SizedBox(height: TSpacing.xl),

            // --- Erreur globale (ex: email deja pris) ---
            if (_globalError != null) ...[
              _buildGlobalError(_globalError!),
              const SizedBox(height: TSpacing.md),
            ],

            // --- Bouton principal ---
            AppButton.primary(
              label: _isLogin
                  ? TLocale.of(context)('auth.cta_signin')
                  : TLocale.of(context)('auth.cta_signup'),
              trailingIcon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              fullWidth: true,
              size: AppButtonSize.lg,
              onPressed: _handleAuth,
            ),

            const SizedBox(height: TSpacing.xxl),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : mascotte flottante
  // =============================================================

  Widget _buildMascot() {
    return AnimatedBuilder(
      animation: _mascotFloat,
      builder: (context, child) {
        // Flottement leger +/- 4px.
        final offset = Tween<double>(begin: -4, end: 4)
            .chain(CurveTween(curve: TCurve.easeInOut))
            .evaluate(_mascotFloat);
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: Center(
        // Logo TRIALGO en hero de l'auth : c'est le premier ecran
        // brande que voit l'utilisateur, le logo est la signature
        // (la mascotte duo viendra en gameplay, pas ici).
        child: Image.asset(
          MockData.logo,
          height: 110,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : toggle segmente SE CONNECTER / S'INSCRIRE
  // =============================================================

  Widget _buildSegmentedToggle() {
    final colors = TColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: TRadius.lgAll,
        border: Border.all(color: colors.borderSubtle),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segmentTab(
            label: TLocale.of(context)('auth.tab_signin'),
            selected: _isLogin,
            onTap: () => _toggleMode(true),
          ),
          _segmentTab(
            label: TLocale.of(context)('auth.tab_signup'),
            selected: !_isLogin,
            onTap: () => _toggleMode(false),
          ),
        ],
      ),
    );
  }

  /// Rend un onglet du toggle segmente.
  Widget _segmentTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = TColors.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: TDuration.quick,
          curve: TCurve.standard,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Onglet actif : gradient primary + shadow.
            // Onglet inactif : transparent (pour laisser voir le parent).
            color: selected ? TColors.primary : Colors.transparent,
            borderRadius: TRadius.mdAll,
          ),
          child: Text(
            label,
            style: TTypography.titleSm(
              color: selected ? colors.textOnBrand : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : indicateur de force du mdp (4 segments)
  // =============================================================

  Widget _buildStrengthMeter() {
    final pwd = _passwordController.text;
    final score = _passwordStrength(pwd);
    // Label et couleur en fonction du score.
    final tr = TLocale.of(context);
    final (label, color) = switch (score) {
      0 => ('', TColors.error),
      1 => (tr('auth.strength_weak'), TColors.error),
      2 => (tr('auth.strength_medium'), TColors.warning),
      3 => (tr('auth.strength_good'), TColors.success),
      _ => (tr('auth.strength_strong'), TColors.success),
    };

    return Row(
      children: [
        // 4 segments qui se remplissent selon le score.
        for (int i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: TDuration.quick,
              height: 4,
              decoration: BoxDecoration(
                color: i < score ? color : TColors.of(context).borderDefault,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: TSpacing.sm),
        // Label (vide si score 0).
        SizedBox(
          width: 52, // largeur fixe pour eviter le "saut" au changement.
          child: Text(
            label,
            style: TTypography.labelMd(color: color),
          ),
        ),
      ],
    );
  }

  // =============================================================
  // WIDGET : bloc d'erreur globale (au-dessus du bouton primaire)
  // =============================================================

  Widget _buildGlobalError(String message) {
    return Container(
      padding: const EdgeInsets.all(TSpacing.md),
      decoration: BoxDecoration(
        color: Color.fromARGB(
          0x26,
          TColors.error.r.round(),
          TColors.error.g.round(),
          TColors.error.b.round(),
        ),
        borderRadius: TRadius.mdAll,
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
          const Icon(Icons.error_outline, color: TColors.error, size: 20),
          const SizedBox(width: TSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TTypography.bodySm(color: TColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
