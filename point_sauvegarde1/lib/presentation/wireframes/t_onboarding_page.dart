// =============================================================
// FICHIER : lib/presentation/wireframes/t_onboarding_page.dart
// ROLE   : Tutoriel premier demarrage (4 slides swipables)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// QU'EST-CE QUE CETTE PAGE ?
// --------------------------
// Affichee UNE SEULE FOIS lors du premier login (apres activation
// reussie d'un code de jeu). Guide le nouveau joueur a travers
// les concepts cles :
//   1. Bienvenue sur TRIALGO
//   2. Le trio magique (E + C = R)
//   3. Observe et deduis
//   4. Pret a jouer ?
//
// La page se ferme via :
//   - Swipe jusqu'au dernier slide + tap "Commencer"
//   - Bouton "Passer" en haut a droite (saute direct)
//
// PERSISTANCE :
// -------------
// Un flag "onboarding_seen" est stocke dans SharedPreferences.
// La page n'est plus affichee apres la premiere fois.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trialgo/presentation/wireframes/t_locale.dart';

/// Tutoriel premier demarrage.
class TOnboardingPage extends ConsumerStatefulWidget {
  /// Callback appele quand le joueur termine ou skip l'onboarding.
  final VoidCallback onFinish;

  const TOnboardingPage({required this.onFinish, super.key});

  @override
  ConsumerState<TOnboardingPage> createState() => _TOnboardingPageState();
}

class _TOnboardingPageState extends ConsumerState<TOnboardingPage>
    with TickerProviderStateMixin {

  /// Controller pour swiper entre les pages.
  final PageController _pageController = PageController();

  /// Index de la page courante.
  int _currentPage = 0;

  /// Les 4 slides a afficher.
  late List<_OnboardSlide> _slides;

  @override
  void initState() {
    super.initState();
    // Les slides sont construits dans build() pour acceder a tr().
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // =============================================================
  // METHODES
  // =============================================================

  /// Marque l'onboarding comme vu et appelle le callback.
  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    widget.onFinish();
  }

  /// Avance a la page suivante ou termine si on est a la derniere.
  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);

    // Construction des 4 slides avec traductions.
    _slides = [
      _OnboardSlide(
        icon: Icons.waving_hand_rounded,
        iconColor: const Color(0xFFF7C948),
        title: tr('onb.1_title'),
        body: tr('onb.1_body'),
      ),
      _OnboardSlide(
        icon: Icons.auto_awesome_rounded,
        iconColor: const Color(0xFFFF6B35),
        title: tr('onb.2_title'),
        body: tr('onb.2_body'),
      ),
      _OnboardSlide(
        icon: Icons.touch_app_rounded,
        iconColor: const Color(0xFF66BB6A),
        title: tr('onb.3_title'),
        body: tr('onb.3_body'),
      ),
      _OnboardSlide(
        icon: Icons.rocket_launch_rounded,
        iconColor: const Color(0xFF42A5F5),
        title: tr('onb.4_title'),
        body: tr('onb.4_body'),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // --- Fond degrade profond ---
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A1A),
                  Color(0xFF1A1035),
                  Color(0xFF0D1B2A),
                ],
              ),
            ),
          ),

          // --- PageView avec les slides ---
          SafeArea(
            child: Column(
              children: [
                // Bouton "Passer" en haut a droite.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _finish,
                        child: Text(
                          tr('onb.skip'),
                          style: GoogleFonts.exo2(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // PageView : les slides horizontaux.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) => _buildSlide(
                      _slides[index],
                    ),
                  ),
                ),

                // Indicateurs de progression (dots).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: i == _currentPage
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B35),
                                  Color(0xFFF7C948),
                                ],
                              )
                            : null,
                        color: i == _currentPage
                            ? null
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),

                // Bouton action principal (Suivant / Commencer).
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF6B35),
                              Color(0xFFF7C948),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _currentPage == _slides.length - 1
                                ? tr('onb.start')
                                : tr('onb.next'),
                            style: GoogleFonts.rajdhani(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construit un slide (icone + titre + body).
  Widget _buildSlide(_OnboardSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icone centrale avec glow.
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  slide.iconColor.withValues(alpha: 0.35),
                  slide.iconColor.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.iconColor.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                slide.icon,
                color: slide.iconColor,
                size: 68,
                shadows: [
                  Shadow(
                    color: slide.iconColor.withValues(alpha: 0.6),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Titre.
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white,
                slide.iconColor,
              ],
            ).createShader(bounds),
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Body.
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modele interne pour un slide d'onboarding.
class _OnboardSlide {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _OnboardSlide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}
