// =============================================================
// FICHIER : lib/presentation/wireframes/t_activation_page.dart
// ROLE   : Ecran d'activation du jeu - experience "unboxing" gaming
// COUCHE : Presentation > Wireframes
// =============================================================
//
// METAPHORE :
// -----------
// L'app simule l'ouverture d'une boite au tresor. Le code d'activation
// est la "cle magique" qui deverrouille le cadenas. Une fois le code
// valide, une sequence theatrale se declenche :
//   1. Le cadenas tourne et explose en particules
//   2. Le couvercle de la boite se souleve
//   3. La mascotte surgit depuis l'interieur
//   4. Le titre "La Savane est a toi !" apparait
//
// POURQUOI CE FLOW ?
// ------------------
// Pour un enfant qui vient d'ouvrir une boite TRIALGO physique,
// l'acte d'activation virtuelle doit RESONNER avec l'acte physique.
// Une UI de formulaire classique ("Tapez votre code, cliquez Valider")
// tue la magie. Un "unboxing" virtuel la prolonge.
//
// REFONTE DEPUIS L'ANCIEN FICHIER (1600 lignes) :
// ------------------------------------------------
//   - Supprime : catalogue horizontal des 6 decks a decouvrir
//     (sera dedie a une future page "Marketplace")
//   - Supprime : couches visuelles confuses (preview + details + form)
//   - Ajoute   : scene theatrale d'unboxing
//   - Ajoute   : etat "deja activee" (boite ouverte + continuer)
//   - Ajoute   : feedback multi-sensoriel (haptic + sons + particules)
// =============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/data/services/audio_service.dart';
import 'package:trialgo/data/services/profile_service.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_graph_loading_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';


/// Ecran d'activation du jeu via un code unique (experience unboxing).
class TActivationPage extends ConsumerStatefulWidget {
  const TActivationPage({super.key});

  @override
  ConsumerState<TActivationPage> createState() => _TActivationPageState();
}

class _TActivationPageState extends ConsumerState<TActivationPage>
    with TickerProviderStateMixin {

  final _codeController = TextEditingController();

  /// Mode "expansion du formulaire" pour ajouter un jeu supplementaire
  /// quand l'utilisateur a deja un jeu actif.
  bool _expandedAddForm = false;

  /// True pendant l'appel Supabase activate_code.
  bool _isLoading = false;

  /// Message d'erreur inline (code invalide, bloque, etc.).
  String? _error;

  /// Resultat succes (conserve pour l'affichage de l'ecran "succes").
  /// Non null => on est en mode scene de succes.
  ActivationResult? _successResult;

  /// Particules en fond (boucle infinie).
  late final AnimationController _particles;

  /// Shake du cadenas sur erreur (one-shot).
  late final AnimationController _shake;

  /// Sequence complete de succes (2500ms one-shot).
  late final AnimationController _success;

  final List<_GoldParticle> _particleList = [];
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 24; i++) {
      _particleList.add(_GoldParticle.random(_rnd));
    }
    _particles = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(() {
        for (final p in _particleList) {
          p.update();
        }
      })
      ..repeat();

    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Sequence de succes, decoupe par intervalles narratifs :
    //   0.0-0.12  (0-300ms)   : cadenas tourne et fade
    //   0.12-0.32 (300-800ms) : couvercle se souleve
    //   0.32-0.60 (800-1500ms): mascotte scale bounce
    //   0.60-1.00 (1500-2500ms): titre + CTA scale in
    _success = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _codeController.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _particles.dispose();
    _shake.dispose();
    _success.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _handleActivate
  // =============================================================

  Future<void> _handleActivate() async {
    final raw = _codeController.text.trim().toUpperCase();

    if (raw.isEmpty) {
      setState(() => _error = TLocale.of(context)('activation.code_empty'));
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final audio = ref.read(audioServiceProvider);
    audio.playSfx(SoundEffect.swoosh);

    final result = await ref
        .read(profileServiceProvider)
        .activateCode(raw);

    if (!mounted) return;

    if (result.success) {
      HapticFeedback.heavyImpact();
      audio.playSfx(SoundEffect.victory);
      await ref.read(profileProvider.notifier).reload();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successResult = result;
      });
      _success.forward(from: 0);
    } else {
      audio.playSfx(SoundEffect.wrong);
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _error = result.message;
      });
      _triggerShake();
    }
  }

  void _triggerShake() {
    _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final tr = TLocale.of(context);
    final hasActiveGames = profile.games.isNotEmpty;

    return PageScaffold(
      title: tr('activation.title'),
      showBack: Navigator.of(context).canPop(),
      child: Stack(
        children: [
          // --- Layer 1 : particules dorees en fond ---
          Positioned.fill(
            child: CustomPaint(
              painter: _GoldParticlePainter(
                particles: _particleList,
                repaint: _particles,
              ),
            ),
          ),

          // --- Layer 2 : contenu principal selon l'etat ---
          _successResult != null
              ? _buildSuccessScene()
              : hasActiveGames && !_expandedAddForm
                  ? _buildAlreadyActiveView(profile)
                  : _buildUnboxingScene(hasReturn: hasActiveGames),
        ],
      ),
    );
  }

  // =============================================================
  // SCENE : UNBOXING (formulaire de code + boite verrouillee)
  // =============================================================

  Widget _buildUnboxingScene({bool hasReturn = false}) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.xxl,
        vertical: TSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TSpacing.lg),

          Center(
            child: _LockedBox(
              shake: _shake,
              error: _error != null,
            ),
          ),
          const SizedBox(height: TSpacing.xxl),

          Text(
            tr('activation.locked_title'),
            textAlign: TextAlign.center,
            style: TTypography.headlineLg(color: colors.textPrimary),
          ),
          const SizedBox(height: TSpacing.xs),
          Text(
            tr('activation.locked_body'),
            textAlign: TextAlign.center,
            style: TTypography.bodyMd(color: colors.textSecondary),
          ),
          const SizedBox(height: TSpacing.xl),

          _buildCodeInput(),

          if (_error != null) ...[
            const SizedBox(height: TSpacing.md),
            _buildErrorInline(_error!),
          ],

          const SizedBox(height: TSpacing.xl),

          AppButton.primary(
            label: tr('activation.cta_open'),
            icon: Icons.vpn_key_rounded,
            isLoading: _isLoading,
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: _handleActivate,
          ),

          if (hasReturn) ...[
            const SizedBox(height: TSpacing.md),
            AppButton.ghost(
              label: tr('activation.cta_back_games'),
              icon: Icons.arrow_back_rounded,
              onPressed: () => setState(() {
                _expandedAddForm = false;
                _error = null;
                _codeController.clear();
              }),
            ),
          ],

          const SizedBox(height: TSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.lg,
        vertical: TSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            TColors.primary.withValues(alpha: 0.15),
            TColors.primaryVariant.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: TRadius.lgAll,
        border: Border.all(
          color: TColors.primaryVariant.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: TextField(
        controller: _codeController,
        enabled: !_isLoading,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 18,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
          _UpperCaseFormatter(),
        ],
        onChanged: (_) {
          HapticFeedback.selectionClick();
          ref.read(audioServiceProvider).playSfx(SoundEffect.click);
        },
        onSubmitted: (_) => _handleActivate(),
        style: TTypography.displaySm(color: TColors.primaryVariant).copyWith(
          letterSpacing: 4,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'XXXX-XXXX-XXXX',
          hintStyle: TTypography.displaySm(
            color: TColors.primaryVariant.withValues(alpha: 0.3),
          ).copyWith(letterSpacing: 4),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildErrorInline(String message) {
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
            child: Text(message,
                style: TTypography.bodySm(color: TColors.error)),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // SCENE : ALREADY ACTIVE (boite ouverte + cartes dedans)
  // =============================================================

  Widget _buildAlreadyActiveView(AppProfileState profile) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    final activeGameName = profile.games.isNotEmpty
        ? profile.games.first.name
        : 'Ton aventure';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.xxl,
        vertical: TSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TSpacing.lg),
          Center(child: _OpenBox(title: activeGameName)),
          const SizedBox(height: TSpacing.xxl),

          Text(
            tr('activation.already_open_title'),
            textAlign: TextAlign.center,
            style: TTypography.headlineLg(color: colors.textPrimary),
          ),
          const SizedBox(height: TSpacing.xs),
          Text(
            activeGameName,
            textAlign: TextAlign.center,
            style: TTypography.bodyLg(color: TColors.primaryVariant),
          ),
          const SizedBox(height: TSpacing.xl),

          AppButton.primary(
            label: tr('activation.cta_continue'),
            trailingIcon: Icons.arrow_forward_rounded,
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const TGraphLoadingPage(),
                ),
              );
            },
          ),
          const SizedBox(height: TSpacing.xxl),

          Divider(color: colors.borderSubtle, height: 1),
          const SizedBox(height: TSpacing.md),
          AppButton.ghost(
            label: tr('activation.cta_add_another'),
            icon: Icons.add_circle_outline_rounded,
            fullWidth: true,
            onPressed: () => setState(() => _expandedAddForm = true),
          ),

          const SizedBox(height: TSpacing.xl),
        ],
      ),
    );
  }

  // =============================================================
  // SCENE : SUCCESS (theatral, 2.5s)
  // =============================================================

  Widget _buildSuccessScene() {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    return AnimatedBuilder(
      animation: _success,
      builder: (context, _) {
        final t = _success.value;

        final boxOpen = _interval(t, 0.12, 0.32);
        final mascotScale = _interval(t, 0.32, 0.60);
        final titleIn = _interval(t, 0.60, 1.00);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: TSpacing.xxl,
            vertical: TSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: TSpacing.xxl),

              SizedBox(
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: _bouncyScale(mascotScale),
                      child: Opacity(
                        opacity: mascotScale.clamp(0.0, 1.0),
                        // Logo TRIALGO surgit de la boite ouverte :
                        // c'est le moment brand de l'activation, pas
                        // un moment narratif (la mascotte viendra en
                        // gameplay).
                        child: Image.asset(
                          MockData.logo,
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -80 * boxOpen),
                      child: Opacity(
                        opacity: (1 - boxOpen).clamp(0.0, 1.0),
                        child: _LockedBox(
                          shake: _shake,
                          error: false,
                          opening: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TSpacing.xxl),

              Opacity(
                opacity: titleIn.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: _bouncyScale(titleIn),
                  child: Column(
                    children: [
                      Text(
                        tr('activation.success_title'),
                        textAlign: TextAlign.center,
                        style: TTypography.displaySm(color: TColors.primary),
                      ),
                      const SizedBox(height: TSpacing.sm),
                      Text(
                        tr('activation.success_body'),
                        textAlign: TextAlign.center,
                        style: TTypography.bodyMd(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: TSpacing.xxl),

              Opacity(
                opacity: (titleIn - 0.4).clamp(0.0, 1.0) / 0.6,
                child: AppButton.primary(
                  label: tr('activation.cta_start'),
                  trailingIcon: Icons.arrow_forward_rounded,
                  fullWidth: true,
                  size: AppButtonSize.lg,
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const TGraphLoadingPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: TSpacing.xxl),
            ],
          ),
        );
      },
    );
  }

  /// Retourne une progression normalisee 0..1 sur un Interval [start, end].
  double _interval(double t, double start, double end) {
    if (t < start) return 0;
    if (t > end) return 1;
    return (t - start) / (end - start);
  }

  /// Scale rebondissant : 0 -> 1.1 -> 1 (effet "qui surgit").
  double _bouncyScale(double t) {
    return Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
  }
}


// =============================================================
// WIDGET : _LockedBox
// =============================================================

class _LockedBox extends StatelessWidget {
  final AnimationController shake;
  final bool error;
  final bool opening;

  const _LockedBox({
    required this.shake,
    required this.error,
    this.opening = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) {
        final t = shake.value;
        final offsetX = t > 0
            ? math.sin(t * math.pi * 8) * 10 * (1 - t)
            : 0.0;
        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: child,
        );
      },
      child: SizedBox(
        width: 200,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // --- Corps de la boite ---
            Positioned(
              bottom: 0,
              child: Container(
                width: 200,
                height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      TColors.primary.withValues(alpha: 0.9),
                      TColors.primaryVariant.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  boxShadow: TElevation.glowPrimary,
                ),
                child: CustomPaint(
                  painter: _BoxTexturePainter(),
                ),
              ),
            ),

            // --- Couvercle (rectangle plus fonce au dessus) ---
            Positioned(
              top: 30,
              child: Container(
                width: 210,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [TColors.primary, TColors.primaryVariant],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

            // --- Cadenas dore (masque si boite en cours d'ouverture) ---
            if (!opening)
              Positioned(
                top: 0,
                child: _Padlock(error: error),
              ),
          ],
        ),
      ),
    );
  }
}


// =============================================================
// WIDGET : _Padlock
// =============================================================

class _Padlock extends StatelessWidget {
  final bool error;

  const _Padlock({required this.error});

  @override
  Widget build(BuildContext context) {
    final color = error ? TColors.error : TColors.primaryVariant;

    return SizedBox(
      width: 60,
      height: 70,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Arche (haut du cadenas).
          Positioned(
            top: 0,
            child: Container(
              width: 34,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border.all(color: color, width: 5),
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.3), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Corps du cadenas.
          Positioned(
            top: 30,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: error
                    ? TElevation.glowError
                    : TElevation.glowGold,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// =============================================================
// WIDGET : _OpenBox (boite deja ouverte)
// =============================================================

class _OpenBox extends StatelessWidget {
  final String title;

  const _OpenBox({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: Container(
              width: 200,
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TColors.primary.withValues(alpha: 0.9),
                    TColors.primaryVariant.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                boxShadow: TElevation.glowPrimary,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: 120,
                height: 20,
                decoration: const BoxDecoration(
                  color: TColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            // Logo TRIALGO dans la boite deja ouverte (etat "deja active").
            child: Image.asset(
              MockData.logo,
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}


// =============================================================
// PAINTER : texture de boite (grain diagonal subtil)
// =============================================================

class _BoxTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BoxTexturePainter oldDelegate) => false;
}


// =============================================================
// CLASSE : _GoldParticle
// =============================================================

class _GoldParticle {
  double x, y, vx, vy, size, opacity;

  _GoldParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
  });

  factory _GoldParticle.random(math.Random r) => _GoldParticle(
        x: r.nextDouble(),
        y: r.nextDouble(),
        vx: (r.nextDouble() - 0.5) * 0.0008,
        vy: (r.nextDouble() - 0.5) * 0.0008,
        size: 1 + r.nextDouble() * 2.5,
        opacity: 0.1 + r.nextDouble() * 0.3,
      );

  void update() {
    x = (x + vx + 1) % 1.0;
    y = (y + vy + 1) % 1.0;
  }
}


// =============================================================
// PAINTER : _GoldParticlePainter
// =============================================================

class _GoldParticlePainter extends CustomPainter {
  final List<_GoldParticle> particles;

  _GoldParticlePainter({
    required this.particles,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = TColors.primaryVariant.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GoldParticlePainter old) => false;
}


// =============================================================
// FORMATTER : force l'entree en majuscules
// =============================================================

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
