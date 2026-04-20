// =============================================================
// FICHIER : lib/core/navigation/app_navigator.dart
// ROLE   : Cle globale du Navigator pour navigation hors widget tree
// COUCHE : Core > Navigation
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// La plupart du temps, on navigue via "Navigator.of(context)".
// Mais certains services sont initialises HORS de l'arbre Flutter :
//   - DeepLinkService ecoute un Stream<Uri> depuis main()
//   - Notifications push arrivent dans le callback natif
//
// Ces services n'ont PAS de BuildContext disponible. On leur donne
// donc une reference a une GlobalKey<NavigatorState> partagee, qui
// sait acceder au Navigator de MaterialApp meme sans context.
//
// PATTERN :
// ---------
// 1. MaterialApp(navigatorKey: appNavigatorKey, ...)
// 2. appNavigatorKey.currentState?.push(...)  // depuis n'importe ou
// 3. appNavigatorKey.currentContext          // context valide
// =============================================================

import 'package:flutter/material.dart';

/// Cle globale partagee du Navigator principal de l'app.
///
/// Connectee au MaterialApp dans t_wireframe_app.dart.
/// Utilisee par DeepLinkService pour naviguer lors de la reception
/// d'un deep-link, sans avoir besoin d'un BuildContext.
///
/// Unique dans toute l'app : declaration "final" top-level qui agit
/// comme un singleton via le chargement du module Dart.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
