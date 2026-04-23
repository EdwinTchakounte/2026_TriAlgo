// =============================================================
// FICHIER : lib/presentation/wireframes/t_graph_loading_page.dart
// ROLE   : Chargement du graphe - cinematique "assemblage du plateau"
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Remplace CircularProgressIndicator + texte par une cinematique
//     ou "le plateau de jeu se construit" autour d'une mascotte.
//   - 12 cartes dorees apparaissent en cercle en stagger (80ms).
//   - Rayons de lumiere connectent le centre aux cartes.
//   - Texte narratif cyclique 3 phases (2.4s total):
//     "Reveil du plateau" -> "Assemblage des cartes" -> "Tissage des trios"
//   - Progress bar globale en bas.
//   - Duree minimum 1.2s affichage meme si sync tres rapide.
//
// CONTRAT PRESERVE :
// ------------------
//   - Appelle graphSyncService.syncAndBuild(gameId)
//   - Navigue vers TOnboardingPage (si jamais vu) sinon TGameModePage
//   - Fallback vers TActivationPage si gameId manquant
//   - Fallback vers ecran d'erreur si exception
// =============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/elevation.dart';
import 'package:trialgo/core/design_system/tokens/motion.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/core/preferences/onboarding_prefs.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_activation_page.dart';
import 'package:trialgo/presentation/wireframes/t_game_mode_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_onboarding_page.dart';


enum _LoadingStatus { loading, ready, error }

class TGraphLoadingPage extends ConsumerStatefulWidget {
  const TGraphLoadingPage({super.key});

  @override
  ConsumerState<TGraphLoadingPage> createState() =>
      _TGraphLoadingPageState();
}

class _TGraphLoadingPageState extends ConsumerState<TGraphLoadingPage>
    with TickerProviderStateMixin {

  _LoadingStatus _status = _LoadingStatus.loading;
  String? _errorMessage;

  /// Index de la phase narrative courante (0, 1, 2).
  int _phaseIndex = 0;

  /// Timer pour cycler entre les 3 phases de texte.
  Timer? _phaseTimer;

  /// Nombre de phases narratives affichees cycliquement.
  /// Les libelles sont resolus au build via TLocale (loading.phase1/2/3).
  static const int _phaseCount = 3;

  /// Progression globale 0..1, linearise de maniere simulee
  /// pour donner un feedback regulier meme si la sync est instantanee.
  late final AnimationController _progress;

  /// Controller pour le pulse de la mascotte centrale (boucle).
  late final AnimationController _pulse;

  /// Controller pour l'entree en stagger des 12 cartes en cercle.
  late final AnimationController _cards;

  @override
  void initState() {
    super.initState();

    // Progress : passe de 0 a 1 sur la duree totale min de 1.2s.
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Pulse mascotte : boucle infinie 1.5s reverse.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Entree des cartes en stagger : 80ms × 12 = 960ms total.
    _cards = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    // Cycle les phases texte toutes les 400ms.
    _phaseTimer = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) {
        if (!mounted) return;
        setState(() {
          _phaseIndex = (_phaseIndex + 1) % _phaseCount;
        });
      },
    );

    _progress.forward();
    _load();
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _progress.dispose();
    _pulse.dispose();
    _cards.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODE : _load
  // =============================================================
  // Declenche la sync du graphe + attend la duree minimum d'affichage
  // pour ne pas "flasher" la cinematique meme si la sync est instantanee.
  // =============================================================

  Future<void> _load() async {
    final minDisplay = Future.delayed(const Duration(milliseconds: 1200));

    try {
      await ref.read(profileProvider.notifier).reload();
      final profile = ref.read(profileProvider);
      final gameId = profile.selectedGameId;

      if (gameId == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TActivationPage()),
        );
        return;
      }

      final sync = ref.read(graphSyncServiceProvider);
      await sync.syncAndBuild(gameId);

      // On attend au minimum la duree de la cinematique pour laisser
      // le spectacle se jouer meme si la sync a dure 50ms.
      await minDisplay;

      if (!mounted) return;
      setState(() => _status = _LoadingStatus.ready);

      // Petite pause pour que l'etat "ready" soit visible (~600ms).
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      // Navigation : onboarding si premiere fois, sinon game mode.
      final onboardingSeen = await OnboardingPrefs.isSeen();
      if (!mounted) return;

      if (!onboardingSeen) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => TOnboardingPage(
              onFinish: () {
                Navigator.of(ctx).pushReplacement(
                  MaterialPageRoute(builder: (_) => const TGameModePage()),
                );
              },
            ),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TGameModePage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _LoadingStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _LoadingStatus.error) {
      return _buildError();
    }
    return _buildCinematic();
  }

  // =============================================================
  // CINEMATIQUE : mascotte pulse + cartes en cercle + rayons + texte
  // =============================================================

  Widget _buildCinematic() {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    final phaseLabels = [
      tr('loading.phase1'),
      tr('loading.phase2'),
      tr('loading.phase3'),
    ];

    return PageScaffold(
      safeArea: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.xxl,
          vertical: TSpacing.xxl,
        ),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // --- Cercle assembly : mascotte + 12 cartes + rayons ---
            Expanded(
              flex: 5,
              child: AnimatedBuilder(
                animation: Listenable.merge([_cards, _pulse]),
                builder: (context, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Diametre du cercle des cartes = 80% du min.
                      final side = math.min(
                          constraints.maxWidth, constraints.maxHeight);
                      return CustomPaint(
                        painter: _AssemblyPainter(
                          progress: _cards.value,
                          pulse: _pulse.value,
                          radius: side * 0.38,
                        ),
                        child: Center(
                          child: _buildMascotPulse(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // --- Texte narratif qui change ---
            AnimatedSwitcher(
              duration: TDuration.normal,
              child: Text(
                _status == _LoadingStatus.ready
                    ? tr('loading.ready')
                    : phaseLabels[_phaseIndex],
                key: ValueKey(_status == _LoadingStatus.ready
                    ? 'ready'
                    : _phaseIndex),
                style: TTypography.headlineSm(color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: TSpacing.md),

            // --- Progress bar globale ---
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  return LinearProgressIndicator(
                    value: _status == _LoadingStatus.ready
                        ? 1.0
                        : _progress.value,
                    minHeight: 6,
                    backgroundColor: colors.surface,
                    valueColor:
                        const AlwaysStoppedAnimation(TColors.primaryVariant),
                  );
                },
              ),
            ),

            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildMascotPulse() {
    // Pulse : scale 1.0 -> 1.08 -> 1.0 (reverse continu).
    // Halo dore autour via BoxShadow glowGold qui "respire".
    final scale = 1.0 + 0.08 * _pulse.value;
    // Hero du chargement : LOGO TRIALGO centre avec halo dore pulsant.
    // Le logo est la signature brand ; la mascotte duo apparaitra en
    // gameplay et en resultat (contextes narratifs).
    //
    // ClipOval n'est plus utilise car le logo.png n'est pas destine
    // a etre decoupe en cercle. On l'affiche rond-decoratif via le
    // Container exterieur avec un padding qui l'isole.
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 140,
        height: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: TColors.primaryVariant.withValues(alpha: 0.25),
            width: 2,
          ),
          boxShadow: TElevation.glowGold,
        ),
        child: Image.asset(
          MockData.logo,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // =============================================================
  // ETAT D'ERREUR
  // =============================================================

  Widget _buildError() {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    return PageScaffold(
      title: tr('loading.oops'),
      child: Padding(
        padding: const EdgeInsets.all(TSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  0x33,
                  TColors.error.r.round(),
                  TColors.error.g.round(),
                  TColors.error.b.round(),
                ),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  color: TColors.error, size: 44),
            ),
            const SizedBox(height: TSpacing.xl),
            Text(
              tr('loading.error_title'),
              style: TTypography.headlineLg(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TSpacing.sm),
            Text(
              _errorMessage ?? tr('loading.error_body'),
              style: TTypography.bodyMd(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: TSpacing.xxl),
            AppButton.primary(
              label: tr('loading.cta_retry'),
              icon: Icons.refresh_rounded,
              fullWidth: true,
              onPressed: () {
                setState(() {
                  _status = _LoadingStatus.loading;
                  _errorMessage = null;
                });
                _progress
                  ..reset()
                  ..forward();
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }
}


// =============================================================
// PAINTER : _AssemblyPainter
// =============================================================
// Dessine 12 "cartes" (petits carres dores) en cercle autour du
// centre, avec des rayons reliant le centre a chaque carte.
//
// L'animation [progress] 0..1 fait apparaitre les cartes en stagger :
// chaque carte a son propre start-time base sur son index.
// [pulse] 0..1 module la luminosite des rayons pour un effet "vivant".
// =============================================================

class _AssemblyPainter extends CustomPainter {

  final double progress;
  final double pulse;
  final double radius;
  static const int _count = 12;

  _AssemblyPainter({
    required this.progress,
    required this.pulse,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < _count; i++) {
      // Angle equireparti autour du cercle.
      final angle = (i / _count) * 2 * math.pi - math.pi / 2;
      final cardCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      // Timing stagger : chaque carte a son creneau de 80ms.
      // cumulOffset evite que les dernieres cartes terminent apres
      // la fin du controller (limite la somme a 0.9 pour laisser
      // du temps a la derniere).
      final start = (i / _count) * 0.9;
      final end = start + 0.25;
      final t = ((progress - start) / (end - start)).clamp(0.0, 1.0);

      if (t <= 0) continue;

      // --- Rayon du centre vers la carte ---
      // Longueur croissante a mesure que la carte apparait.
      final rayPaint = Paint()
        ..color = TColors.primaryVariant
            .withValues(alpha: 0.15 + 0.15 * pulse)
        ..strokeWidth = 1.5;
      final rayEnd = Offset.lerp(center, cardCenter, t)!;
      canvas.drawLine(center, rayEnd, rayPaint);

      // --- Carte (petit rectangle dore) ---
      final eased = Curves.easeOutBack.transform(t);
      final cardPaint = Paint()
        ..color = TColors.primaryVariant.withValues(alpha: eased)
        ..style = PaintingStyle.fill;
      final rectSize = 12.0 * eased;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: cardCenter, width: rectSize, height: rectSize * 1.4),
          const Radius.circular(2),
        ),
        cardPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AssemblyPainter old) =>
      old.progress != progress || old.pulse != pulse;
}
