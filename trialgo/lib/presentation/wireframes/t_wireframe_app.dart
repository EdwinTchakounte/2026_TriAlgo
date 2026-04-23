// =============================================================
// FICHIER : lib/presentation/wireframes/t_wireframe_app.dart
// ROLE   : Racine MaterialApp avec theme dark/light + i18n + auth listener
// COUCHE : Presentation > Wireframes
// =============================================================
//
// Ce widget racine :
//   - Configure MaterialApp (themes dark + light + mode actuel)
//   - Fournit le navigatorKey global (utilise par DeepLinkService)
//   - Ecoute les evenements Supabase Auth pour rerouter sur
//     AuthChangeEvent.passwordRecovery (retour du deep-link)
// =============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trialgo/core/design_system/theme/app_theme.dart';
import 'package:trialgo/core/navigation/app_navigator.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/wireframes/t_app_state.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_new_password_page.dart';
import 'package:trialgo/presentation/wireframes/t_splash_page.dart';

/// Point d'entree wireframe avec gestion langue FR/EN + theme dark/light.
///
/// StatefulWidget car on doit s'abonner a supabase.auth.onAuthStateChange
/// pour capter l'evenement passwordRecovery emis par le DeepLinkService.
class TWireframeApp extends StatefulWidget {
  const TWireframeApp({super.key});

  @override
  State<TWireframeApp> createState() => _TWireframeAppState();
}

class _TWireframeAppState extends State<TWireframeApp> {

  /// Subscription au Stream d'evenements auth Supabase.
  /// Ecoute active pendant toute la vie de l'app.
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // --- Ecoute des evenements auth ---
    // onAuthStateChange emet un AuthState a chaque changement :
    // signedIn, signedOut, tokenRefreshed, passwordRecovery, etc.
    // On ne s'interesse qu'a passwordRecovery ici (retour du deep-link).
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigateToNewPassword();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Navigue vers l'ecran de saisie du nouveau mot de passe.
  void _navigateToNewPassword() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(builder: (_) => const TNewPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder re-build quand appState notifie un changement.
    // Ainsi un toggle de langue OU de theme se propage instantanement.
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return TLocale(
          language: appState.language,
          child: MaterialApp(
            title: 'TRIALGO',
            debugShowCheckedModeBanner: false,

            // --- Themes dark + light ---
            // Flutter bascule automatiquement entre theme/darkTheme
            // selon themeMode. Si mode == system, il suit le reglage
            // de l'OS (utile pour le "mode nuit auto").
            theme: TAppTheme.light,
            darkTheme: TAppTheme.dark,
            themeMode: appState.themeMode,

            // --- Navigator key pour deep-link / services externes ---
            navigatorKey: appNavigatorKey,
            home: const TSplashPage(),
          ),
        );
      },
    );
  }
}
