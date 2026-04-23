// =============================================================
// FICHIER : lib/presentation/wireframes/t_splash_page.dart
// ROLE   : Splash screen premium - 30 secondes avec animations
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_auth_gate.dart';

/// Splash screen premium 30 secondes avec animations sequentielles.
///
/// Sequence :
///   0-3s   : Fondu mascotte
///   3-6s   : Apparition logo TRIALGO
///   6-9s   : Sous-titre + formule E+C=R
///   9-12s  : Animation des 3 types de cartes
///   12-20s : Textes d'ambiance + faits
///   20-28s : Barre de chargement
///   28-30s : Transition vers auth
class TSplashPage extends StatefulWidget {
  const TSplashPage({super.key});

  @override
  State<TSplashPage> createState() => _TSplashPageState();
}

class _TSplashPageState extends State<TSplashPage> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _mascotFade;
  late Animation<double> _logoFade;
  late Animation<double> _subtitleFade;
  late Animation<double> _cardsFade;
  late Animation<double> _factsFade;
  late Animation<double> _progressFade;
  late Animation<double> _progressValue;

  // Faits affiches en sequence.
  int _currentFact = 0;
  final _facts = const [
    'E + C = R',
    'L\'image EST l\'algorithme',
    '3 distances de difficulte',
    '23+ niveaux a explorer',
    'Des centaines de cartes',
  ];

  @override
  void initState() {
    super.initState();

    // Splash raccourci a 3 secondes : suffisant pour l'intro visuelle,
    // evite d'attendre trop longtemps a chaque demarrage de l'app.
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Intervals pour chaque phase (normalises entre 0.0 et 1.0).
    // 30s total : 0.1 = 3s, 0.2 = 6s, etc.
    _mascotFade = _interval(0.0, 0.1);
    _logoFade = _interval(0.1, 0.2);
    _subtitleFade = _interval(0.2, 0.28);
    _cardsFade = _interval(0.28, 0.4);
    _factsFade = _interval(0.4, 0.65);
    _progressFade = _interval(0.65, 0.72);
    _progressValue = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.65, 0.95, curve: Curves.easeInOut),
      ),
    );

    // Cycler les faits toutes les 3 secondes.
    _mainController.addListener(() {
      final sec = (_mainController.value * 30).round();
      final factIndex = ((sec - 12) ~/ 3).clamp(0, _facts.length - 1);
      if (factIndex != _currentFact && sec >= 12) {
        setState(() => _currentFact = factIndex);
      }
    });

    _mainController.forward();

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => const TAuthGate(),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (c, animation, a2, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }

  Animation<double> _interval(double begin, double end) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: TTheme.bgGradient),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _mainController,
            builder: (context, _) {
              return Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),

                        // --- Phase 1 : Logo officiel TRIALGO ---
                        FadeTransition(
                          opacity: _mascotFade,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: TTheme.orange.withValues(alpha: 0.25),
                                  blurRadius: 40,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              MockData.logo,
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // --- Phase 2 : Titre texte ---
                        FadeTransition(
                          opacity: _logoFade,
                          child: ShaderMask(
                            shaderCallback: (b) => TTheme.accentGradient.createShader(b),
                            child: Text('TRIALGO', style: TTheme.logoStyle()),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // --- Phase 3 : Sous-titre ---
                        FadeTransition(
                          opacity: _subtitleFade,
                          child: Text(
                            tr('splash.subtitle'),
                            style: TTheme.microStyle(alpha: 0.45),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // --- Phase 4 : 3 types de cartes ---
                        FadeTransition(
                          opacity: _cardsFade,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _typeChip('E', TTheme.blue),
                              _opChip('+'),
                              _typeChip('C', TTheme.orange),
                              _opChip('='),
                              _typeChip('R', TTheme.green),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // --- Phase 5 : Faits en rotation ---
                        FadeTransition(
                          opacity: _factsFade,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              _facts[_currentFact],
                              key: ValueKey(_currentFact),
                              style: TTheme.bodyStyle(
                                size: 16,
                                weight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- Phase 6 : Barre de progression ---
                        FadeTransition(
                          opacity: _progressFade,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: _progressValue.value,
                                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                                    valueColor: const AlwaysStoppedAnimation(TTheme.orange),
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${tr('splash.loading')} ${(_progressValue.value * 100).toInt()}%',
                                  style: TTheme.bodyStyle(size: 11, color: Colors.white.withValues(alpha: 0.25)),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- Skip button ---
                        GestureDetector(
                          onTap: () {
                            _mainController.stop();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const TAuthGate()),
                            );
                          },
                          child: Text(
                            'Skip >',
                            style: TTheme.bodyStyle(size: 12, color: Colors.white.withValues(alpha: 0.2)),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String letter, Color color) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Center(
        child: Text(letter, style: TTheme.scoreStyle(color: color, size: 20)),
      ),
    );
  }

  Widget _opChip(String op) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(op, style: TTheme.scoreStyle(color: Colors.white24, size: 18)),
    );
  }
}
