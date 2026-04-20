// =============================================================
// FICHIER : lib/presentation/wireframes/t_wireframe_app.dart
// ROLE   : Point d'entree wireframe avec i18n FR/EN + auth listener
// COUCHE : Presentation > Wireframes
// =============================================================
//
// Ce widget racine :
//   - Configure MaterialApp (theme, langue, navigator key)
//   - Ecoute les evenements Supabase Auth pour rerouter sur
//     AuthChangeEvent.passwordRecovery (retour du deep-link)
// =============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trialgo/core/navigation/app_navigator.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/wireframes/t_app_state.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_new_password_page.dart';
import 'package:trialgo/presentation/wireframes/t_splash_page.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Point d'entree wireframe avec gestion langue FR/EN.
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
    //   - signedIn, signedOut, tokenRefreshed, passwordRecovery, etc.
    //
    // On ne s'interesse qu'a passwordRecovery ici : c'est l'evenement
    // emis par Supabase lorsque getSessionFromUrl(uri) reussit a
    // extraire un token de reset depuis un deep-link.
    //
    // A ce moment, on pousse TNewPasswordPage au-dessus de l'ecran
    // courant via le navigatorKey global.
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigateToNewPassword();
      }
    });
  }

  @override
  void dispose() {
    // Nettoyer la subscription pour eviter les fuites memoire
    // (pratique standard pour tout StreamSubscription).
    _authSubscription?.cancel();
    super.dispose();
  }

  // =============================================================
  // METHODE : _navigateToNewPassword
  // =============================================================
  // Pousse TNewPasswordPage via le navigatorKey global.
  //
  // Le navigatorKey est utilise ici (plutot que Navigator.of(context))
  // car l'evenement peut arriver AVANT qu'on ait un context utile
  // (cold start avec deep-link, par exemple).
  // =============================================================

  /// Navigue vers l'ecran de saisie du nouveau mot de passe.
  void _navigateToNewPassword() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return; // app pas encore montee, rare.

    // push (pas pushReplacement) : l'utilisateur peut potentiellement
    // revenir en arriere, mais la page bloque le back pendant l'appel
    // reseau pour eviter les etats incoherents.
    navigator.push(
      MaterialPageRoute(builder: (_) => const TNewPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return TLocale(
          language: appState.language,
          child: MaterialApp(
            title: 'TRIALGO',
            debugShowCheckedModeBanner: false,
            theme: TTheme.themeData,
            // navigatorKey : expose le Navigator au DeepLinkService
            // et a toute autre logique hors arbre widget qui aurait
            // besoin de naviguer sans BuildContext.
            navigatorKey: appNavigatorKey,
            home: const TSplashPage(),
          ),
        );
      },
    );
  }
}
