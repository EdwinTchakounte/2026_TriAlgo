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
// 3. Lance l'app dans un ProviderScope (necessaire pour Riverpod)
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

// Import du widget racine du wireframe.
import 'package:trialgo/presentation/wireframes/t_wireframe_app.dart';

/// Lance le mode wireframe de TRIALGO.
///
/// Initialise Supabase et Riverpod, puis lance l'app.
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
