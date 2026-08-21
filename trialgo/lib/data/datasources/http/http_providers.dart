// =============================================================
// FICHIER : http_providers.dart  (trialgo - app joueur)
// ROLE    : Providers Riverpod pour toutes les HTTP datasources
// COUCHE  : Data > Datasources > HTTP > Providers
// =============================================================
//
// Ce fichier expose chaque datasource HTTP sous forme de provider
// Riverpod. Les pages, providers d'etat, services consomment ces
// providers via ref.watch / ref.read au lieu d'instancier
// directement.
//
// Avantages :
//   1. Singleton implicite : Riverpod garantit une seule instance
//      par container.
//   2. Override pour tests : on peut remplacer un datasource par
//      un mock dans un ProviderContainer de test.
//   3. Decouplage : les pages ne savent pas comment le datasource
//      est construit (Dio injecte, baseURL, etc.).
//
// Usage typique dans un widget :
//   final dt = ref.read(httpAuthDatasourceProvider);
//   final tokens = await dt.login(email: ..., password: ...);
//
// Tous les datasources partagent le meme Dio singleton (cf
// DioClient.instance), donc une seule pile de connexions HTTP +
// un seul interceptor Bearer/refresh.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_auth_datasource.dart';
import 'http_codes_datasource.dart';
import 'http_collective_datasource.dart';
import 'http_leaderboard_datasource.dart';
import 'http_played_nodes_datasource.dart';
import 'http_profile_datasource.dart';
import 'http_public_games_datasource.dart';
import 'http_sessions_datasource.dart';
import 'http_stars_datasource.dart';
import 'http_unlocked_cards_datasource.dart';
import 'http_user_games_datasource.dart';

// -----------------------------------------------------------
// AUTH : login, register, refresh, me, confirm-email, reset...
// -----------------------------------------------------------
final httpAuthDatasourceProvider = Provider<HttpAuthDatasource>(
  (ref) => HttpAuthDatasource(),
);

// -----------------------------------------------------------
// PROFILE : GET/PATCH /api/me/profile
// -----------------------------------------------------------
final httpProfileDatasourceProvider = Provider<HttpProfileDatasource>(
  (ref) => HttpProfileDatasource(),
);

// -----------------------------------------------------------
// CODES : POST /api/codes/activate
// -----------------------------------------------------------
final httpCodesDatasourceProvider = Provider<HttpCodesDatasource>(
  (ref) => HttpCodesDatasource(),
);

// -----------------------------------------------------------
// PUBLIC GAMES : catalogue + cartes (sans card_type)
// -----------------------------------------------------------
final httpPublicGamesDatasourceProvider = Provider<HttpPublicGamesDatasource>(
  (ref) => HttpPublicGamesDatasource(),
);

// -----------------------------------------------------------
// USER GAMES : etat par-jeu (lives, level, score)
// -----------------------------------------------------------
final httpUserGamesDatasourceProvider = Provider<HttpUserGamesDatasource>(
  (ref) => HttpUserGamesDatasource(),
);

// -----------------------------------------------------------
// SESSIONS : POST + GET historique
// -----------------------------------------------------------
final httpSessionsDatasourceProvider = Provider<HttpSessionsDatasource>(
  (ref) => HttpSessionsDatasource(),
);

// -----------------------------------------------------------
// UNLOCKED CARDS : deck galerie
// -----------------------------------------------------------
final httpUnlockedCardsDatasourceProvider = Provider<HttpUnlockedCardsDatasource>(
  (ref) => HttpUnlockedCardsDatasource(),
);

// -----------------------------------------------------------
// PLAYED NODES : tracking anti-doublon
// -----------------------------------------------------------
final httpPlayedNodesDatasourceProvider = Provider<HttpPlayedNodesDatasource>(
  (ref) => HttpPlayedNodesDatasource(),
);

// -----------------------------------------------------------
// STARS : wallet + exchange-for-life
// -----------------------------------------------------------
final httpStarsDatasourceProvider = Provider<HttpStarsDatasource>(
  (ref) => HttpStarsDatasource(),
);

// -----------------------------------------------------------
// LEADERBOARD + STATS
// -----------------------------------------------------------
final httpLeaderboardDatasourceProvider = Provider<HttpLeaderboardDatasource>(
  (ref) => HttpLeaderboardDatasource(),
);

// -----------------------------------------------------------
// COLLECTIVE : verify-collective par node_index
// -----------------------------------------------------------
final httpCollectiveDatasourceProvider = Provider<HttpCollectiveDatasource>(
  (ref) => HttpCollectiveDatasource(),
);
