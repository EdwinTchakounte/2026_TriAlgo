// =============================================================
// FICHIER : lib/presentation/wireframes/t_auth_gate.dart
// ROLE   : Gate d'authentification au demarrage
// COUCHE : Presentation > Wireframes
// =============================================================
//
// CE WIDGET :
// -----------
// 1. Ecoute les changements d'etat d'authentification Supabase
// 2. Au demarrage, verifie si une session existe deja
// 3. Si oui : route vers la home (sans repasser par auth + activation)
// 4. Si non : route vers la page d'auth
//
// IMPORTANT : grace a onAuthStateChange, si la session expire
// pendant l'utilisation, l'utilisateur est automatiquement
// redirige vers la page d'auth.
// =============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_auth_page.dart';
import 'package:trialgo/presentation/wireframes/t_activation_page.dart';
import 'package:trialgo/presentation/wireframes/t_graph_loading_page.dart';

/// Gate d'authentification qui route vers la bonne page selon l'etat.
///
/// Flow :
///   Session ? → NON → AuthPage
///             → OUI → Profil ?
///                       → Pas de game → ActivationPage
///                       → Game active → GraphLoadingPage → Home
class TAuthGate extends ConsumerStatefulWidget {
  const TAuthGate({super.key});

  @override
  ConsumerState<TAuthGate> createState() => _TAuthGateState();
}

class _TAuthGateState extends ConsumerState<TAuthGate> {

  /// Subscription pour ecouter les changements d'etat d'auth.
  StreamSubscription<AuthState>? _authSub;

  /// Future qui resout le routage initial.
  Future<Widget>? _initialRoute;

  @override
  void initState() {
    super.initState();

    // Demarrer la musique de fond des le lancement de l'app.
    // La musique va jouer sur toutes les pages (auth, activation,
    // home, etc.) sauf pendant le jeu ou elle continue aussi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioServiceProvider).startBackgroundMusic();
    });

    // Calculer la route initiale.
    _initialRoute = _computeInitialRoute();

    // Ecouter les changements d'auth (logout, expiration, etc.).
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.signedOut) {
        // Session terminee -> retour a la page d'auth.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TAuthPage()),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // =============================================================
  // ROUTAGE INITIAL
  // =============================================================
  // Verifie la session et le profil pour decider ou aller.
  // =============================================================

  Future<Widget> _computeInitialRoute() async {
    final session = supabase.auth.currentSession;

    // Pas de session -> auth.
    if (session == null) {
      return const TAuthPage();
    }

    // Session valide -> charger le profil pour savoir si un jeu est
    // deja active.
    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.loadProfile();

      if (profile == null) {
        // Profil manquant (premiere fois apres signUp) → activation.
        await profileService.createProfile(
          username: supabase.auth.currentUser?.email?.split('@').first,
        );
        return const TActivationPage();
      }

      final selectedGameId = profile['selected_game_id'] as String?;
      if (selectedGameId == null) {
        // Pas encore de jeu active → activation.
        return const TActivationPage();
      }

      // Tout est OK : charger le graphe et aller au jeu.
      // Le GraphLoadingPage recharge le profil et sync le graphe.
      return const TGraphLoadingPage();
    } catch (e) {
      // En cas d'erreur, retour a l'auth par securite.
      return const TAuthPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialRoute,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Loader initial le temps de resoudre la route.
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A1A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return const TAuthPage();
        }

        return snapshot.data!;
      },
    );
  }
}
