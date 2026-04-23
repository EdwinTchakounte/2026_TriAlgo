// =============================================================
// FICHIER : lib/presentation/wireframes/t_home_tour.dart
// ROLE   : Navigation guidee interactive sur la home (tour)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// QU'EST-CE QUE CE FICHIER ?
// --------------------------
// Un overlay en plein ecran qui guide le nouveau joueur a travers
// les elements cles de la home page au premier demarrage.
//
// Chaque etape affiche :
//   - Un fond sombre semi-transparent
//   - Une "carte" d'info avec titre, description, icone
//   - Un bouton "Suivant" / "Termine"
//   - Le numero d'etape (1/4)
//
// PERSISTANCE :
// -------------
// Un flag "home_tour_seen" est stocke dans SharedPreferences.
// Le tour ne s'affiche plus apres la premiere fois.
// =============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Etape du tour guide.
class _TourStep {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _TourStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

/// Overlay interactif de navigation guidee.
///
/// A afficher UNE FOIS en overlay sur la home lors du premier login.
/// Appelle [onFinish] quand le joueur termine ou passe.
class THomeTour extends StatefulWidget {
  final VoidCallback onFinish;

  const THomeTour({required this.onFinish, super.key});

  @override
  State<THomeTour> createState() => _THomeTourState();

  // =============================================================
  // HELPER STATIQUE : doit-on afficher le tour ?
  // =============================================================

  /// Retourne true si le tour n'a pas encore ete vu.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('home_tour_seen') ?? false);
  }

  /// Marque le tour comme vu.
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_tour_seen', true);
  }
}

class _THomeTourState extends State<THomeTour>
    with SingleTickerProviderStateMixin {

  int _currentStep = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _steps = [
    _TourStep(
      icon: Icons.touch_app_rounded,
      color: Color(0xFFF7C948),
      title: 'Carte JOUER',
      body: 'Tape la carte doree au centre pour commencer une partie. '
          'C\'est ton bouton de lancement principal.',
    ),
    _TourStep(
      icon: Icons.visibility_rounded,
      color: Color(0xFF42A5F5),
      title: 'Observe le trio',
      body: 'Le jeu te presente 3 cartes. 2 sont visibles, '
          '1 est masquee. Trouve la carte manquante parmi les choix.',
    ),
    _TourStep(
      icon: Icons.zoom_in_rounded,
      color: Color(0xFF66BB6A),
      title: 'Zoom sur une carte',
      body: 'Tap simple = choisir ta reponse. '
          'Double-tap = voir la carte en plein ecran sans repondre.',
    ),
    _TourStep(
      icon: Icons.favorite_rounded,
      color: Color(0xFFEF5350),
      title: 'Vies et score',
      body: 'Chaque mauvaise reponse coute une vie. '
          'Gagne des points, monte en niveau, debloque de nouvelles cartes.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _fadeController.forward(from: 0);
      });
    } else {
      await THomeTour.markAsSeen();
      widget.onFinish();
    }
  }

  Future<void> _skip() async {
    await THomeTour.markAsSeen();
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Stack(
          children: [
            // --- Bouton skip en haut a droite ---
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _skip,
                child: Text(
                  'Passer',
                  style: GoogleFonts.exo2(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            // --- Carte d'info centrale ---
            Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1A1040).withValues(alpha: 0.95),
                        const Color(0xFF0D1B2A).withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: step.color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: step.color.withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icone circulaire.
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              step.color.withValues(alpha: 0.3),
                              step.color.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: step.color.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          step.icon,
                          color: step.color,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Etape X/Y.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: step.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currentStep + 1} / ${_steps.length}',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: step.color,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Titre.
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white, step.color],
                        ).createShader(bounds),
                        child: Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description.
                      Text(
                        step.body,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dots indicateurs.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _steps.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _currentStep ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: i == _currentStep
                                  ? step.color
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Bouton next/termine.
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: step.color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _currentStep == _steps.length - 1
                                ? 'Termine'
                                : 'Suivant',
                            style: GoogleFonts.rajdhani(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
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
    );
  }
}
