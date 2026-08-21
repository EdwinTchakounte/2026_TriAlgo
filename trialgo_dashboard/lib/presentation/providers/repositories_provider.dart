// =============================================================
// FICHIER : repositories_provider.dart
// ROLE    : Exposer les repositories via Riverpod
// =============================================================
//
// Pourquoi Riverpod ?
//   - Singleton automatique : un repository par session
//   - Override en tests : on peut remplacer par un fake
//   - Dependence chainee : un provider peut lire un autre
//
// Tous les providers ici sont du type `Provider<T>` (pas
// `StateProvider`) car les repositories sont stateless : ils
// n'ont pas de "valeur" qui change au fil du temps.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/card_repository.dart';
import '../../data/repositories/game_repository.dart';
import '../../data/repositories/node_repository.dart';

// Le client Supabase global est expose en provider pour pouvoir
// le mocker en test. En prod, il pointe sur le singleton
// Supabase.instance.client (initialise dans main.dart).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(ref.watch(supabaseClientProvider));
});

final nodeRepositoryProvider = Provider<NodeRepository>((ref) {
  return NodeRepository(ref.watch(supabaseClientProvider));
});

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(ref.watch(supabaseClientProvider));
});
