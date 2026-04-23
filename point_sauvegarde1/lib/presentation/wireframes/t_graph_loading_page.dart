// =============================================================
// FICHIER : lib/presentation/wireframes/t_graph_loading_page.dart
// ROLE   : Synchroniser le graphe du jeu selectionne
// COUCHE : Presentation > Wireframes
// =============================================================
//
// QU'EST-CE QUE CETTE PAGE ?
// --------------------------
// Affichee juste apres l'activation (ou au retour de l'app si une
// session active existe). Elle :
//   1. Verifie qu'un jeu est selectionne dans le profil
//   2. Synchronise cards + nodes du jeu depuis Supabase
//   3. Construit le graphe en memoire + precompute les noeuds logiques
//   4. Navigue vers TGameModePage quand pret
//
// FIX BUG "PRET !" :
// -------------------
// L'ancien code naviguait trop vite apres le state ready, ce qui
// empechait le rebuild de la UI pour afficher "Pret !". Maintenant :
//   - Delay augmente a 1200ms
//   - scheduleMicrotask pour s'assurer que le rebuild est fait
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_activation_page.dart';
import 'package:trialgo/presentation/wireframes/t_game_mode_page.dart';
import 'package:trialgo/presentation/wireframes/t_onboarding_page.dart';

/// Statuts possibles pendant le chargement du graphe.
enum _LoadingStatus { loading, ready, error }

/// Page de chargement du graphe.
class TGraphLoadingPage extends ConsumerStatefulWidget {
  const TGraphLoadingPage({super.key});

  @override
  ConsumerState<TGraphLoadingPage> createState() => _TGraphLoadingPageState();
}

class _TGraphLoadingPageState extends ConsumerState<TGraphLoadingPage>
    with SingleTickerProviderStateMixin {

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  _LoadingStatus _status = _LoadingStatus.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Lancer le chargement apres le premier build pour acceder a ref.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // =============================================================
  // CHARGEMENT
  // =============================================================
  // 1. Charger le profil pour connaitre le selected_game_id
  // 2. Si aucun jeu selectionne → retour activation
  // 3. Sinon sync le graphe du jeu
  // 4. Afficher "Pret !" puis naviguer
  // =============================================================

  Future<void> _load() async {
    try {
      // 1. Charger/rafraichir le profil.
      await ref.read(profileProvider.notifier).reload();
      final profile = ref.read(profileProvider);
      final gameId = profile.selectedGameId;

      if (gameId == null) {
        // Pas de jeu active → retour activation.
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TActivationPage()),
        );
        return;
      }

      // 2. Sync le graphe du jeu.
      final sync = ref.read(graphSyncServiceProvider);
      await sync.syncAndBuild(gameId);

      if (!mounted) return;

      // 3. Afficher "Pret !" pendant 1.2s puis naviguer.
      setState(() => _status = _LoadingStatus.ready);
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;

      // 4. Verifier si c'est le premier login (onboarding pas encore vu).
      // Si oui, afficher le tutoriel avant la home.
      final prefs = await SharedPreferences.getInstance();
      final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

      if (!mounted) return;

      if (!onboardingSeen) {
        // Premier login : afficher l'onboarding, puis naviguer a la home.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => TOnboardingPage(
              onFinish: () {
                Navigator.of(ctx).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const TGameModePage(),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // Deja vu : direct a la home.
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
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
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnim.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFF7C948)],
                  ).createShader(bounds),
                  child: Text(
                    'TRIALGO',
                    style: GoogleFonts.rajdhani(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildStatusContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent() {
    switch (_status) {
      case _LoadingStatus.loading:
        return Column(
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Color(0xFFFF6B35),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Synchronisation du graphe...',
              style: GoogleFonts.exo2(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        );

      case _LoadingStatus.ready:
        return Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF66BB6A),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Pret !',
              style: GoogleFonts.rajdhani(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF66BB6A),
              ),
            ),
          ],
        );

      case _LoadingStatus.error:
        return Column(
          children: [
            const Icon(Icons.error_rounded, color: Colors.red, size: 32),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _errorMessage ?? 'Erreur inconnue',
                textAlign: TextAlign.center,
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// Accesseur public pour que d'autres pages puissent verifier que
/// le graphe est deja synchronise.
bool isGraphReady(WidgetRef ref) {
  return ref.read(graphSyncServiceProvider).isReady;
}
