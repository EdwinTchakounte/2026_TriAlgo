// =============================================================
// FICHIER : lib/main_wireframe.dart
// ROLE   : Point d'entree pour lancer le wireframe
// =============================================================
//
// COMMENT LANCER ?
// ----------------
//   flutter run -t lib/main_wireframe.dart
//
// CE QUE FAIT CE FICHIER :
// ------------------------
// 1. Initialise les bindings Flutter
// 2. Initialise Supabase (necessaire pour la sync du graphe)
// 3. Initialise le DeepLinkService (reset mot de passe par deep-link)
// 4. Lance l'app dans un ProviderScope (necessaire pour Riverpod)
//
// HISTORIQUE :
// ------------
// Avant l'integration du graphe, ce fichier ne faisait que lancer
// le wireframe sans Supabase ni Riverpod. Maintenant que l'app
// utilise les providers Riverpod (graphSyncServiceProvider, etc.)
// et Supabase (sync des cards et nodes), ces deux dependances
// sont indispensables.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import du client Supabase pour l'initialisation.
import 'package:trialgo/core/network/supabase_client.dart';

// Service d'ecoute des deep-links (reset password).
// Doit etre initialise APRES Supabase car il utilise supabase.auth
// pour traiter les tokens contenus dans les URIs entrantes.
import 'package:trialgo/data/services/deep_link_service.dart';

// Etat global (langue + theme mode). loadFromPrefs() doit etre
// appele avant runApp pour restaurer les preferences utilisateur.
import 'package:trialgo/presentation/wireframes/t_app_state.dart';

// Import du widget racine du wireframe.
import 'package:trialgo/presentation/wireframes/t_wireframe_app.dart';

/// Lance le mode wireframe de TRIALGO.
///
/// Initialise Supabase, le deep-link et Riverpod, puis lance l'app.
void main() async {
  // Initialise le binding Flutter.
  // Necessaire car on appelle du code asynchrone (initSupabase)
  // avant runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise le client Supabase avec l'URL et la cle anon.
  // Ces valeurs sont definies dans core/network/supabase_client.dart.
  // Apres cet appel, on peut utiliser le getter global "supabase"
  // pour faire des requetes (cards, nodes, auth, etc.).
  await initSupabase();

  // Restaure les preferences utilisateur (langue + mode de theme)
  // depuis SharedPreferences. Sans ce chargement, l'app demarre
  // toujours en FR / system theme, meme si l'utilisateur avait
  // change ces reglages a sa derniere session.
  await appState.loadFromPrefs();

  // Initialise le service d'ecoute des deep-links.
  // Declenche immediatement le traitement du lien qui a lance l'app
  // (cold start) si applicable, et ecoute les futurs liens entrants.
  // L'instance est conservee en memoire pendant toute la vie de l'app
  // via la reference top-level _deepLinkService ci-dessous.
  await _deepLinkService.init();

  // Lancer l'application dans un ProviderScope.
  //
  // ProviderScope est le widget racine de Riverpod.
  // Il fournit le contexte necessaire pour acceder aux providers
  // (graphRepositoryProvider, generateQuestionProvider, etc.) depuis
  // n'importe quel widget de l'arbre.
  //
  // Sans ProviderScope, tout appel a ref.read/ref.watch leve une
  // exception "No ProviderScope found".
  runApp(
    const ProviderScope(
      child: TWireframeApp(),
    ),
  );
}

// ---------------------------------------------------------------
// REFERENCE TOP-LEVEL AU DEEPLINK SERVICE
// ---------------------------------------------------------------
// Conservee ici pour garder l'instance vivante pendant toute la vie
// du processus Dart (sinon le Stream<Uri> pourrait etre garbage
// collecte si l'instance sortait du scope).
//
// Le service n'expose rien publiquement : son seul effet est de
// passer les URIs recues a Supabase, qui emet ensuite un evenement
// onAuthStateChange ecoute dans TWireframeApp.
// ---------------------------------------------------------------
final DeepLinkService _deepLinkService = DeepLinkService();
