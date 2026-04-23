// =============================================================
// FICHIER : lib/presentation/wireframes/t_splash_page.dart
// ROLE   : Splash brand de 2.2s (smart-skip pour users connectes)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// PHILOSOPHIE :
// -------------
// Le splash est le MOMENT BRAND de l'application. Ce n'est ni
// un temps mort ni une progression pendant qu'on charge des donnees
// (on n'en charge aucune). C'est une mise en scene pensee pour
// creer le meme sentiment que les intros de Pokemon Go : "Mon
// univers revient".
//
// SEQUENCE :
//   0ms      : fond sombre + particules dorees spawn
//   200ms    : assembly letter-by-letter "TRIALGO" (stagger 80ms)
//   700ms    : tagline mot par mot "Observe. Deduis. Gagne."
//   2200ms   : fade vers AuthGate (ou 1200ms pour user connecte)
//
// SMART SKIP :
// ------------
// Si supabase.auth.currentUser existe deja (retour d'un user connu),
// le splash dure 1200ms au lieu de 2200ms. L'utilisateur fidele
// n'attend pas, mais on montre quand meme le moment brand.
// =============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:trialgo/core/design_system/tokens/brand.dart';
import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/wireframes/t_auth_gate.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';


/// Splash page (2.2s de mise en scene brand).
class TSplashPage extends StatefulWidget {
  const TSplashPage({super.key});

  @override
  State<TSplashPage> createState() => _TSplashPageState();
}

class _TSplashPageState extends State<TSplashPage>
    with TickerProviderStateMixin {

  // ---------------------------------------------------------------
  // CONTROLLERS
  // ---------------------------------------------------------------
  // Chaque element anime a son propre controller pour un timing
  // precis et la possibilite de stopper/restarter independamment.
  // ---------------------------------------------------------------

  /// Controller en boucle infinie pour les particules dorees.
  late final AnimationController _particleController;

  /// Controller en boucle infinie pour le float sinusoidal du mascot.
  late final AnimationController _mascotController;

  /// Controller one-shot pour l'assembly des 7 lettres TRIALGO.
  late final AnimationController _logoController;

  /// Controller one-shot pour l'apparition sequentielle de la tagline.
  late final AnimationController _taglineController;

  /// Controller en boucle infinie pour les 3 dots pulsants.
  late final AnimationController _dotsController;

  // ---------------------------------------------------------------
  // PARTICULES
  // ---------------------------------------------------------------
  // 30 particules dorees qui flottent en arriere-plan.
  // Reproduisent la signature visuelle du jeu (cohesion en-game).
  // ---------------------------------------------------------------

  final List<_SplashParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // --- Particules : init 30 aleatoires, controller 1s repeat ---
    for (int i = 0; i < 30; i++) {
      _particles.add(_SplashParticle.random(_random));
    }
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(_tickParticles)
      ..repeat();

    // --- Mascot float : 3s sinus reverse ---
    _mascotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // --- Logo letters : 700ms one-shot ---
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // --- Tagline : 800ms one-shot ---
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // --- Dots loader : 1200ms repeat ---
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Lancer la sequence de mise en scene.
    _runSequence();
  }

  // =============================================================
  // METHODE : _runSequence
  // =============================================================
  // Orchestre le timing des animations + navigation vers AuthGate.
  //
  // Smart skip : si l'utilisateur est deja connecte via Supabase,
  // on raccourcit la sequence (les utilisateurs fideles n'attendent
  // pas autant que les premiers arrivants).
  // =============================================================

  Future<void> _runSequence() async {
    // --- Phase 1 : entree des lettres ---
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoController.forward();
    // Haptic leger a l'apparition du logo (feedback "on demarre").
    await HapticFeedback.lightImpact();

    // --- Phase 2 : tagline ---
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _taglineController.forward();

    // --- Phase 3 : attente avant navigation ---
    // Si deja connecte (retour), on reduit fortement la pause.
    final isReturning = supabase.auth.currentUser != null;
    final waitMs = isReturning ? 500 : 1500;
    await Future.delayed(Duration(milliseconds: waitMs));
    if (!mounted) return;

    // Haptic medium "bump" a l'arrivee sur l'app reelle.
    // Pas de await : haptic est fire-and-forget, inutile d'attendre.
    // Cela evite aussi un "async gap" supplementaire avant la nav.
    HapticFeedback.mediumImpact();

    // --- Phase 4 : navigation avec fade out ---
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (c, a, b) => const TAuthGate(),
        transitionDuration: TDuration.slow,
        transitionsBuilder: (c, animation, b, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Avance les particules d'un frame.
  void _tickParticles() {
    for (final p in _particles) {
      p.update();
    }
  }

  @override
  void dispose() {
    _particleController
      ..removeListener(_tickParticles)
      ..dispose();
    _mascotController.dispose();
    _logoController.dispose();
    _taglineController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Splash TOUJOURS en dark : c'est un choix narratif (drame,
      // relief des particules dorees). Meme en mode clair, le splash
      // reste sombre le temps de la mise en scene, puis le reste de
      // l'app respecte le theme choisi par l'utilisateur.
      backgroundColor: TSurfaceColors.darkBgBase,
      body: Container(
        decoration: const BoxDecoration(gradient: TBrand.bgDark),
        child: SafeArea(
          child: Stack(
            children: [
              // --- Layer 1 : particules dorees (fond atmospheric) ---
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashParticlePainter(
                    particles: _particles,
                    repaint: _particleController,
                  ),
                ),
              ),

              // --- Layer 2 : contenu centre ---
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mascotte qui flotte en sinusoide douce.
                    _buildFloatingMascot(),
                    const SizedBox(height: TSpacing.xxl),

                    // Les 7 lettres TRIALGO qui arrivent en stagger.
                    _buildLogoLetters(),
                    const SizedBox(height: TSpacing.md),

                    // Tagline en 3 mots qui apparaissent en sequence.
                    _buildTagline(),
                  ],
                ),
              ),

              // --- Layer 3 : dots loader en bas ---
              Positioned(
                left: 0,
                right: 0,
                bottom: TSpacing.huge,
                child: _buildDotsLoader(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : mascotte flottante
  // =============================================================

  /// Rend l'image mascotte avec un mouvement sinusoidal vertical.
  Widget _buildFloatingMascot() {
    return AnimatedBuilder(
      animation: _mascotController,
      builder: (context, child) {
        // t varie 0→1 puis 1→0 (repeat reverse), on le mappe en sinus
        // pour un mouvement plus naturel que le triangle par defaut.
        final t = _mascotController.value;
        final offsetY = math.sin(t * math.pi) * 6; // ±6px de flottement
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: child,
        );
      },
      // child est construit UNE fois (l'image est lourde), seul le
      // Transform est recalcule a chaque frame.
      child: Image.asset(
        MockData.mascotMain,
        width: 160,
        fit: BoxFit.contain,
      ),
    );
  }

  // =============================================================
  // WIDGET : lettres TRIALGO animees
  // =============================================================

  /// Rend les 7 lettres TRIALGO qui arrivent l'une apres l'autre
  /// avec un leger overshoot (style Pokemon Go / Duolingo).
  Widget _buildLogoLetters() {
    const letters = ['T', 'R', 'I', 'A', 'L', 'G', 'O'];

    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(letters.length, (i) {
            // Chaque lettre commence a i*step et dure 0.35 du total.
            // Stagger calcule pour que la derniere lettre finisse
            // legerement avant la fin du controller.
            const step = 0.08;
            const span = 0.45;
            final start = i * step;
            final end = start + span;

            // Progress local de cette lettre : 0 avant son start,
            // 1 apres son end, progression entre les deux.
            final raw = ((_logoController.value - start) / (end - start))
                .clamp(0.0, 1.0);
            final t = Curves.easeOutBack.transform(raw);

            // Opacite directement mappee sur la progression.
            final opacity = t.clamp(0.0, 1.0);
            // Lettres qui tombent du ciel : translate Y de -20 a 0.
            final translateY = (1 - t) * -20;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Opacity(
                  opacity: opacity,
                  // ShaderMask applique le gradient orange->dore sur
                  // le texte : signature visuelle TRIALGO reutilisee
                  // partout ou on veut mettre en avant l'identite.
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        TBrand.primary.createShader(bounds),
                    child: Text(
                      letters[i],
                      // displayMd = 36pt bold. La taille donne l'impact
                      // tout en restant lisible sur petits ecrans.
                      style: TTypography.displayMd(color: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // =============================================================
  // WIDGET : tagline sequentielle
  // =============================================================

  /// Rend "Observe. Deduis. Gagne." avec chaque mot qui monte en fade-in.
  Widget _buildTagline() {
    const words = ['Observe.', 'Deduis.', 'Gagne.'];

    return AnimatedBuilder(
      animation: _taglineController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(words.length, (i) {
            // Meme logique que les lettres : start decalé par mot.
            final start = i * 0.25;
            final end = start + 0.5;
            final raw = ((_taglineController.value - start) / (end - start))
                .clamp(0.0, 1.0);
            final t = Curves.easeOutCubic.transform(raw);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: TSpacing.xs),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 8), // leger slide-up
                child: Opacity(
                  opacity: t,
                  child: Text(
                    words[i],
                    style: TTypography.bodyLg(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // =============================================================
  // WIDGET : dots loader custom
  // =============================================================

  /// Rend 3 dots dores qui pulsent en stagger infini.
  ///
  /// Remplace le CircularProgressIndicator generique par un motif
  /// plus "brand" et plus doux (moins agressif pour l'enfant).
  Widget _buildDotsLoader() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            // Phase decalee par dot : 0%, 33%, 66% du cycle.
            final phase = (_dotsController.value + i * 0.33) % 1.0;
            // Pulse : sin(phase * pi) va de 0 a 1 a 0 sur un cycle.
            final pulse = math.sin(phase * math.pi);
            // Taille et opacite modulees par le pulse.
            final size = 4 + 4 * pulse; // 4-8 px
            final opacity = 0.3 + 0.7 * pulse; // 0.3-1.0

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    color: TColors.primaryVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}


// =============================================================
// CLASSE : _SplashParticle
// =============================================================
// Mini structure mutable pour une particule. Position, velocite,
// taille, opacite. Les coordonnees sont en 0..1 (proportion de
// l'ecran), ce qui rend le rendu responsive quelle que soit la
// taille de l'ecran.
// =============================================================

class _SplashParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;

  _SplashParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
  });

  /// Cree une particule aleatoire (position, velocite, taille).
  factory _SplashParticle.random(math.Random r) {
    return _SplashParticle(
      x: r.nextDouble(),
      y: r.nextDouble(),
      // Vitesses faibles pour un mouvement contemplatif.
      vx: (r.nextDouble() - 0.5) * 0.0008,
      vy: (r.nextDouble() - 0.5) * 0.0008,
      size: 1.5 + r.nextDouble() * 2.5, // 1.5-4 px
      opacity: 0.1 + r.nextDouble() * 0.35, // 10-45%
    );
  }

  /// Avance la particule d'un tick (appelee a chaque frame).
  /// Wrap-around : quand on sort d'un cote, on reapparait de l'autre.
  void update() {
    x = (x + vx + 1) % 1.0;
    y = (y + vy + 1) % 1.0;
  }
}


// =============================================================
// PAINTER : _SplashParticlePainter
// =============================================================
// Dessine les particules dorees. CustomPainter performant pour
// des centaines de particules (beaucoup plus rapide que 30 widgets).
// =============================================================

class _SplashParticlePainter extends CustomPainter {

  final List<_SplashParticle> particles;

  _SplashParticlePainter({
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
  bool shouldRepaint(covariant _SplashParticlePainter oldDelegate) {
    // Le repaint est declenche par le controller via super.repaint.
    // On n'a pas besoin de rechecker ici.
    return false;
  }
}
