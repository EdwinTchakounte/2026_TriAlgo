// =============================================================
// FICHIER : lib/main_wireframe.dart
// ROLE   : Point d'entree ALTERNATIF pour lancer le wireframe
// =============================================================
//
// CE FICHIER EST UN RACCOURCI.
// ----------------------------
// Au lieu de modifier main.dart (qui contient la vraie logique
// d'initialisation Supabase + Riverpod), on cree un point
// d'entree SEPARE pour le mode wireframe.
//
// COMMENT LANCER ?
// ----------------
// Option 1 (recommandee) : depuis le terminal :
//   flutter run -t lib/main_wireframe.dart
//
// Option 2 : dans l'IDE (VS Code / Android Studio) :
//   Modifier la configuration de lancement pour pointer
//   vers main_wireframe.dart au lieu de main.dart.
//
// Option 3 : modifier temporairement main.dart :
//   Remplacer :
//     home: const _AuthGate()
//   Par :
//     home: const TWireframeApp()
//
// AVANTAGE DE CE FICHIER :
// -------------------------
// - Pas besoin d'initialiser Supabase (pas de cle, pas de reseau)
// - Pas besoin de Riverpod (pas de ProviderScope)
// - Lancement instantane (pas d'attente de connexion)
// - Le code de production (main.dart) reste intact
// =============================================================

import 'package:flutter/material.dart';

// Import du widget racine du wireframe.
import 'package:trialgo/presentation/wireframes/t_wireframe_app.dart';

/// Lance le mode wireframe de TRIALGO.
///
/// Aucune initialisation necessaire (pas de Supabase, pas de Riverpod).
/// Tout fonctionne avec des donnees fictives locales.
void main() {
  // "WidgetsFlutterBinding.ensureInitialized()" :
  //   Initialise le binding Flutter.
  //   Necessaire si on appelle du code asynchrone avant runApp().
  //   Ici, ce n'est pas strictement necessaire (pas d'async),
  //   mais c'est une bonne pratique de toujours l'inclure.
  WidgetsFlutterBinding.ensureInitialized();

  // Lancer l'application wireframe.
  // Pas de ProviderScope car on n'utilise pas Riverpod.
  runApp(const TWireframeApp());
}
