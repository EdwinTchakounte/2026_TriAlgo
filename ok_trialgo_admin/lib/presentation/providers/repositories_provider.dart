// =============================================================
// FICHIER : repositories_provider.dart
// ROLE    : Injection de dependances (DI) via Riverpod
// =============================================================
//
// Ce fichier expose les Provider de tous les repositories.
// L'implementation concrete est SELECTIONNEE selon ApiMode :
//
//   ApiMode.fake     -> repositories en memoire (FakeStore)
//   ApiMode.supabase -> repositories qui appellent Supabase
//   ApiMode.fastapi  -> repositories qui appellent /api/ (Dio)
//
// Important : les pages/notifiers continuent de lire les MEMES
// providers. Aucun code de presentation ne change quand on bascule.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/api_config.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/card_repository_impl.dart';
import '../../data/repositories/fake_repositories.dart';
import '../../data/repositories/game_repository_impl.dart';
import '../../data/repositories/http_auth_repository.dart';
import '../../data/repositories/http_card_repository.dart';
import '../../data/repositories/http_game_repository.dart';
import '../../data/repositories/http_node_repository.dart';
import '../../data/repositories/http_admin_users_repository.dart';
import '../../data/repositories/http_codes_repository.dart';
import '../../data/repositories/node_repository_impl.dart';
import '../../data/repositories/unsupported_admin_repositories.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/codes_repository.dart';
import '../../domain/repositories/card_repository.dart';
import '../../domain/repositories/game_repository.dart';
import '../../domain/repositories/node_repository.dart';

// SupabaseClient global. Utilise UNIQUEMENT en ApiMode.supabase.
// Lu via lateinit : Supabase.initialize doit avoir tourne dans main().
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Fake store partage par les 3 fake repos. Lazy pour ne pas
// payer le seed en modes supabase / fastapi.
final _fakeStoreProvider = Provider<FakeStore>((_) => FakeStore.seeded());

// -----------------------------------------------------------
// Repositories : selection selon ApiMode.
// -----------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  switch (ApiConfig.mode) {
    case ApiMode.fake:
      // Pas d'auth en mode fake : on garde l'impl Supabase, mais
      // _AuthGate la court-circuite via kDevBypassAuth (= mode fake).
      return AuthRepositoryImpl(ref.watch(supabaseClientProvider));
    case ApiMode.supabase:
      return AuthRepositoryImpl(ref.watch(supabaseClientProvider));
    case ApiMode.fastapi:
      return HttpAuthRepository();
  }
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  switch (ApiConfig.mode) {
    case ApiMode.fake:
      return FakeGameRepository(ref.watch(_fakeStoreProvider));
    case ApiMode.supabase:
      return GameRepositoryImpl(ref.watch(supabaseClientProvider));
    case ApiMode.fastapi:
      return HttpGameRepository();
  }
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  switch (ApiConfig.mode) {
    case ApiMode.fake:
      return FakeCardRepository(ref.watch(_fakeStoreProvider));
    case ApiMode.supabase:
      return CardRepositoryImpl(ref.watch(supabaseClientProvider));
    case ApiMode.fastapi:
      return HttpCardRepository();
  }
});

final nodeRepositoryProvider = Provider<NodeRepository>((ref) {
  switch (ApiConfig.mode) {
    case ApiMode.fake:
      return FakeNodeRepository(ref.watch(_fakeStoreProvider));
    case ApiMode.supabase:
      return NodeRepositoryImpl(ref.watch(supabaseClientProvider));
    case ApiMode.fastapi:
      return HttpNodeRepository();
  }
});

// -----------------------------------------------------------
// Repositories d'administration : codes et comptes.
//
// Contrairement aux quatre precedents, ceux-ci n'ont PAS de
// variante fake ni supabase : les endpoints correspondants sont
// nes avec le backend FastAPI. Hors de ce mode on injecte une
// implementation inerte qui renvoie un Err explicite plutot que
// de planter ou de mentir (cf. unsupported_admin_repositories).
// -----------------------------------------------------------

final codesRepositoryProvider = Provider<CodesRepository>((ref) {
  return ApiConfig.mode == ApiMode.fastapi
      ? HttpCodesRepository()
      : const UnsupportedCodesRepository();
});

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  return ApiConfig.mode == ApiMode.fastapi
      ? HttpAdminUsersRepository()
      : const UnsupportedAdminUsersRepository();
});
