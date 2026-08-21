// =============================================================
// FICHIER : lib/data/services/deep_link_service.dart
// ROLE   : Ecouter les deep-links entrants (ex: reset password)
// COUCHE : Data > Services
// =============================================================
//
// QU'EST-CE QU'UN DEEP-LINK ?
// ---------------------------
// Un deep-link est une URL qui, quand elle est cliquee, ouvre une
// page specifique d'une app native au lieu d'un navigateur.
//
// Exemple :
//   - L'utilisateur recoit un mail "Reinitialiser mon mdp"
//   - Le mail contient un lien "trialgo://reset-password#access_token=xyz"
//   - L'utilisateur clique dessus
//   - iOS/Android detecte le scheme "trialgo://" et ouvre TRIALGO
//   - L'URI complet est transmis a l'app via un Stream
//
// QUE FAIT CE SERVICE ?
// ---------------------
// 1. Au demarrage : recupere le lien qui a LANCE l'app (cold start)
// 2. En arriere-plan : ecoute les liens recus pendant que l'app tourne
// 3. Pour chaque URI recu : le transmet a Supabase qui extrait le
//    token et met a jour la session (evenement passwordRecovery)
//
// L'evenement passwordRecovery est ecoute ailleurs (au niveau de
// TWireframeApp) pour declencher la navigation vers l'ecran de
// nouveau mot de passe.
//
// RELATION AVEC SUPABASE :
// ------------------------
// Supabase genere un lien du type :
//   https://<project>.supabase.co/auth/v1/verify?type=recovery&token=...
//   &redirect_to=trialgo://reset-password
//
// Une fois le token verifie, Supabase redirige vers :
//   trialgo://reset-password#access_token=...&refresh_token=...&type=recovery
//
// C'est cet URI final qui arrive dans notre app et qu'on doit passer
// a supabase.auth.getSessionFromUrl() pour creer la session de
// recuperation.
// =============================================================

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/navigation/app_navigator.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/presentation/wireframes/t_new_password_page.dart';


/// Service d'ecoute des deep-links de l'application.
///
/// Instance unique, initialisee dans main() apres initSupabase.
class DeepLinkService {

  /// Instance du package app_links qui fournit les streams de deep-links.
  /// Cree au constructeur, garde privee pour eviter les usages directs.
  final AppLinks _appLinks = AppLinks();

  /// Subscription au `Stream<Uri>` pour pouvoir annuler l'ecoute si besoin.
  /// Peut etre null avant init(), ou apres dispose().
  StreamSubscription<Uri>? _subscription;

  // =============================================================
  // METHODE : init
  // =============================================================
  // Doit etre appelee UNE SEULE FOIS au demarrage de l'app.
  // Elle :
  //   1. Verifie si l'app a ete lancee VIA un deep-link (cold start)
  //   2. Commence a ecouter les futurs deep-links
  //
  // Les deep-links recus sont transmis a _handleUri() qui les passe
  // a Supabase pour traitement de la session.
  // =============================================================

  /// Initialise l'ecoute des deep-links.
  Future<void> init() async {
    // --- Cas 1 : l'app est lancee PAR un deep-link ---
    // getInitialLink() retourne l'URI qui a declenche le lancement
    // de l'app (si applicable), ou null si l'app a ete lancee
    // normalement (icone, multitache, etc.).
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        // Traitement asynchrone : on ne bloque pas le demarrage.
        // ignore: unawaited_futures
        _handleUri(initialUri);
      }
    } catch (e) {
      // Les deep-links peuvent echouer sur certaines plateformes
      // (tests, web...) : on continue sans crash.
    }

    // --- Cas 2 : ecoute permanente pendant la vie de l'app ---
    // uriLinkStream est un Stream<Uri> qui emet a chaque nouvelle
    // URI entrante tant que l'app tourne. Chaque event passe
    // directement a _handleUri.
    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {
        // Silencieux : un lien mal forme ne doit pas crasher l'app.
      },
    );
  }

  // =============================================================
  // METHODE : _handleUri
  // =============================================================
  // Traite un URI recu.
  //
  // Pour un lien de reset password, l'URI contient des fragments
  // (#access_token=...). supabase.auth.getSessionFromUrl(uri) :
  //   - extrait les tokens du fragment
  //   - cree la session "recovery"
  //   - emet un evenement onAuthStateChange(passwordRecovery)
  //
  // C'est cet evenement qui, ecoute dans TWireframeApp, declenche
  // la navigation vers la page "nouveau mot de passe".
  // =============================================================

  /// Traite un URI deep-link recu.
  ///
  /// Deux formats selon le backend :
  ///   - Supabase : trialgo://reset-password#access_token=...&refresh_token=...
  ///     -> getSessionFromUrl pose une session de recovery puis
  ///        TWireframeApp ecoute AuthChangeEvent.passwordRecovery.
  ///   - FastAPI  : trialgo://reset-password?token=`token_clair`
  ///        ou https://app.trialgo.io/reset-password?token=`...`
  ///     -> on extrait le param token et on push TNewPasswordPage
  ///        avec recoveryToken pre-rempli.
  Future<void> _handleUri(Uri uri) async {
    // On accepte trialgo:// (custom scheme) et https:// (App Links / Universal Links).
    final isTrialgoScheme = uri.scheme == 'trialgo';
    final isHttpsApp = uri.scheme == 'https' && uri.host.contains('trialgo');
    if (!isTrialgoScheme && !isHttpsApp) return;

    // ---- Branche FastAPI : extrait le token query param ----
    if (ApiConfig.isFastApi) {
      final token = uri.queryParameters['token'];
      final isResetPath = uri.path.contains('reset-password') ||
          uri.host == 'reset-password' ||
          uri.host == 'reset_password';
      if (isResetPath && token != null && token.isNotEmpty) {
        final navigator = appNavigatorKey.currentState;
        if (navigator != null) {
          // ignore: unawaited_futures
          navigator.push(
            MaterialPageRoute(
              builder: (_) => TNewPasswordPage(recoveryToken: token),
            ),
          );
        }
      }
      return;
    }

    // ---- Branche SUPABASE : delegation au SDK ----
    try {
      await supabase.auth.getSessionFromUrl(uri);
    } catch (_) {
      // Lien deja consomme, expire, ou format inattendu : l'user
      // peut relancer le flux "mot de passe oublie".
    }
  }

  // =============================================================
  // METHODE : dispose
  // =============================================================
  // Annule la subscription au Stream<Uri>. A appeler lors de la
  // fermeture de l'app (rarement necessaire en pratique, l'OS
  // nettoie les ressources au kill du processus).
  // =============================================================

  /// Annule l'ecoute des deep-links.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
