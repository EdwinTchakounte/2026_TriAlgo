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

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/session/session_utilisateur.dart';
import 'package:trialgo/core/api/dio_client.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/data/datasources/http/http_providers.dart';
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

    // Ecouter les changements d'auth Supabase. En mode FastAPI on
    // n'a pas de stream equivalent : la deconnexion se fait par
    // clearing des tokens cote client + l'interceptor Dio refresh
    // bascule sur signOut local si le refresh echoue. On laisse
    // quand meme ce listener actif : il sera no-op en mode FastAPI
    // (aucun event ne sera emis).
    if (ApiConfig.isSupabase) {
      _authSub = supabase.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        if (data.event == AuthChangeEvent.signedOut) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const TAuthPage()),
            (route) => false,
          );
        }
      });
    }
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
    // ---------------------------------------------------------
    // BRANCHEMENT BACKEND : on regarde d'abord ApiConfig.mode
    // pour savoir quel systeme de session inspecter.
    // ---------------------------------------------------------
    if (ApiConfig.isFastApi) {
      return _computeInitialRouteFastApi();
    }
    return _computeInitialRouteSupabase();
  }

  // -----------------------------------------------------------
  // Routing initial en mode FastAPI (JWT en flutter_secure_storage)
  // -----------------------------------------------------------
  Future<Widget> _computeInitialRouteFastApi() async {
    // Pas de token persiste -> auth.
    if (!await DioClient.storage.hasSession()) {
      return const TAuthPage();
    }

    try {
      // Verifier que le token est encore valide en appelant /me.
      // L'interceptor Dio refresh-uera automatiquement si 401.
      final authDs = ref.read(httpAuthDatasourceProvider);
      final me = await authDs.me();
      if (me == null) {
        // Jeton absent, expire ou revoque : on repart de l'ecran
        // d'authentification, et on vide l'identite en cache pour ne
        // pas laisser trainer celle de la session precedente.
        SessionUtilisateur.effacer();
        return const TAuthPage();
      }

      // Session restauree : on repeuple le cache d'identite. C'est le
      // pendant, au demarrage, de ce que fait TAuthPage a la connexion.
      // Sans cela, apres un simple relancement de l'app, l'entree admin
      // disparaitrait et la cle d'onboarding retomberait sur 'anon'.
      SessionUtilisateur.memoriserDepuisJson(me);

      // Charger le profil joueur (username, avatar, selected_game).
      final profileDs = ref.read(httpProfileDatasourceProvider);
      final profile = await profileDs.getMyProfile();
      final selectedGameId = profile['selected_game_id'] as String?;
      if (selectedGameId == null) {
        // Pas encore active de jeu -> page activation code.
        return const TActivationPage();
      }
      // Sinon : graphe + home.
      return const TGraphLoadingPage();
    } catch (_) {
      // Toute erreur reseau / token invalide -> retour auth.
      return const TAuthPage();
    }
  }

  // -----------------------------------------------------------
  // Routing initial en mode SUPABASE (historique)
  // -----------------------------------------------------------
  Future<Widget> _computeInitialRouteSupabase() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      return const TAuthPage();
    }

    try {
      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.loadProfile();

      if (profile == null) {
        await profileService.createProfile(
          username: supabase.auth.currentUser?.email?.split('@').first,
        );
        return const TActivationPage();
      }

      final selectedGameId = profile['selected_game_id'] as String?;
      if (selectedGameId == null) {
        return const TActivationPage();
      }

      return const TGraphLoadingPage();
    } catch (e) {
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
