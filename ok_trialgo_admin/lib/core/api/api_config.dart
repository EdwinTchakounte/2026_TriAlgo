// =============================================================
// FICHIER : api_config.dart
// ROLE    : Selecteur global du backend a utiliser + base URL
// =============================================================
//
// Remplace l'ancien flag `kDevBypassAuth` (binaire) par un enum
// a 3 valeurs :
//
//   ApiMode.fake     : repositories en memoire (FakeStore).
//                      Aucun reseau, aucun login. Demarre direct
//                      sur le hub avec un jeu seede.
//
//   ApiMode.supabase : repositories Supabase historiques. Utilise
//                      l'URL/anonKey de SupabaseConfig. Login via
//                      auth.users + verifie is_admin sur
//                      user_profiles (migration 005).
//
//   ApiMode.fastapi  : repositories HTTP qui parlent au backend
//                      ok_trialgo_backend (FastAPI + Postgres +
//                      MinIO). URL de base configurable.
//
// Pour basculer : changer kApiMode et rebuilder. Si tu veux le
// rendre runtime (toggle dans l'app), il suffit d'exposer un
// Notifier<ApiMode> et de l'utiliser dans repositories_provider.
// =============================================================

import 'package:flutter/foundation.dart' show kReleaseMode;

enum ApiMode { fake, supabase, fastapi }

class ApiConfig {
  ApiConfig._();

  // -----------------------------------------------------------
  // MODE actif au build. Modifier ici puis rebuild.
  // -----------------------------------------------------------
  // - fastapi : pour la nouvelle stack backend
  // - fake    : pour la demo offline (validation de flow)
  // - supabase: pour reprendre l'ancienne stack si besoin
  static const ApiMode mode = ApiMode.fastapi;

  // -----------------------------------------------------------
  // BASE URL du backend FastAPI
  // -----------------------------------------------------------
  // SOURCE UNIQUE DE VERITE. Aucun datasource ne doit contenir
  // d'URL en dur : tous lisent ApiConfig.baseUrl.
  //
  // La valeur est resolue en trois temps :
  //
  //  1. --dart-define=API_BASE_URL=... , s'il est passe au build.
  //     Il l'emporte toujours. Utile pour pointer une preprod ou
  //     un backend local depuis un appareil physique :
  //       flutter build apk --dart-define=API_BASE_URL=http://192.168.1.20:8000
  //
  //  2. Sinon, en build RELEASE : le domaine de production.
  //
  //  3. Sinon (build debug/profil) : 10.0.2.2, l'alias par lequel
  //     l'emulateur Android joint le localhost de la machine hote.
  //     Sur un telephone branche en USB, faire d'abord
  //       adb reverse tcp:8000 tcp:8000
  //     puis passer --dart-define=API_BASE_URL=http://localhost:8000
  //
  // POURQUOI DISTINGUER RELEASE ET DEBUG
  // ------------------------------------
  // Avant, le defaut valait 10.0.2.2 dans tous les cas. Un APK de
  // production construit sans penser au --dart-define partait donc
  // interroger une adresse d'emulateur : l'app s'installait, se
  // lancait, et echouait sur chaque appel reseau sans message
  // explicite. Le defaut suit desormais le type de build, ce qui
  // rend cet oubli impossible. Le --dart-define reste disponible
  // pour tous les cas particuliers.
  //
  // kReleaseMode vient de package:flutter/foundation.dart. C'est une
  // constante de compilation : le compilateur elimine la branche
  // morte, il n'y a aucun test a l'execution.
  // -----------------------------------------------------------

  /// Domaine de production de l'API admin.
  static const String _urlProduction = 'https://api.mixalgo.com';

  /// Defaut de developpement : hote vu depuis l'emulateur Android.
  static const String _urlDeveloppement = 'http://10.0.2.2:8000';

  /// URL de base effective du backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? _urlProduction : _urlDeveloppement,
  );
}
