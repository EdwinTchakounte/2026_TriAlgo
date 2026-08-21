// =============================================================
// FICHIER : api_config.dart  (trialgo - app joueur)
// ROLE    : Selecteur global du backend a utiliser + base URL
// =============================================================
//
// L'app joueur trialgo/ peut parler a deux backends :
//
//   ApiMode.supabase : code historique (supabase_flutter direct).
//                      Garde tout ce qui marchait sur Supabase
//                      (user_profiles, user_sessions, user_games,
//                      user_unlocked_cards, RPCs ...).
//
//   ApiMode.fastapi  : nouveau backend ok_trialgo_backend
//                      (FastAPI + Postgres + MinIO). Endpoints
//                      portes depuis Supabase (codes, sessions,
//                      stars, leaderboard, etc.).
//
// Pour basculer : changer ApiConfig.mode (ou passer la variable
// d'environnement API_BASE_URL au build) puis rebuild.
// =============================================================

import 'package:flutter/foundation.dart' show kReleaseMode;

enum ApiMode { supabase, fastapi }

class ApiConfig {
  ApiConfig._();

  // -----------------------------------------------------------
  // MODE actif au build. Modifier ici puis rebuild.
  // -----------------------------------------------------------
  // - supabase : pour garder l'ancienne stack (par defaut tant
  //              que le branchement FastAPI n'est pas valide).
  // - fastapi  : pour la nouvelle stack backend.
  //
  // En prod on bascule vers fastapi une fois les datasources
  // HTTP testes bout-en-bout.
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

  /// Domaine de production de l'API joueur.
  static const String _urlProduction = 'https://api.mixalgo.com';

  /// Defaut de developpement : hote vu depuis l'emulateur Android.
  static const String _urlDeveloppement = 'http://10.0.2.2:8000';

  /// URL de base effective du backend.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? _urlProduction : _urlDeveloppement,
  );

  // =============================================================
  // CONSTANTE : linkDomain
  // =============================================================
  // Domaine enregistrable des liens envoyes par courriel
  // (reinitialisation de mot de passe, confirmation d'adresse).
  //
  // POURQUOI UNE CONSTANTE SEPAREE DE baseUrl ?
  // -------------------------------------------
  // On pourrait croire qu'il suffit de deduire le domaine de
  // baseUrl. C'est faux pour deux raisons :
  //
  //   1. baseUrl depend de kReleaseMode. En debug il vaut
  //      'http://10.0.2.2:8000' -- une adresse IP, dont on ne peut
  //      tirer aucun domaine. Un build de debug branche sur le
  //      backend de production rejetterait alors tous les liens.
  //
  //   2. Le lien du courriel ne pointe PAS sur l'API mais sur
  //      APP_FRONTEND_URL, une variable distincte cote serveur.
  //      Les deux peuvent legitimement differer.
  //
  // Le domaine des liens est un fait de deploiement stable : il ne
  // change que le jour ou l'on change de nom de domaine. Il merite
  // sa propre constante, valable dans tous les modes de build.
  //
  // Tous les sous-domaines sont couverts : mixalgo.com,
  // api.mixalgo.com, dashboard.mixalgo.com, app.mixalgo.com.
  // =============================================================

  /// Domaine enregistrable autorise a ouvrir l'app via un lien https.
  static const String linkDomain = String.fromEnvironment(
    'APP_LINK_DOMAIN',
    defaultValue: 'mixalgo.com',
  );

  /// Helper pour savoir si on doit utiliser le backend FastAPI.
  static bool get isFastApi => mode == ApiMode.fastapi;

  /// Helper pour savoir si on doit utiliser le backend Supabase.
  static bool get isSupabase => mode == ApiMode.supabase;
}
