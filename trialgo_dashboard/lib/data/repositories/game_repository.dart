// =============================================================
// FICHIER : game_repository.dart
// ROLE    : Lecture des jeux disponibles
// =============================================================
//
// Pour le MVP, le dashboard charge la liste des games actifs
// pour proposer un dropdown "Jeu courant" (utile si on a Savane
// + Ocean plus tard). Pas de creation de jeu pour l'instant
// (peu frequent, plus simple a faire en SQL direct).
// =============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game.dart';

class GameRepository {
  final SupabaseClient _client;
  GameRepository(this._client);

  // Liste des jeux actifs. La RLS games_select_authenticated
  // filtre is_active = true, donc on n'a pas besoin de le
  // refiltrer cote client. On garde le where par defense.
  Future<List<Game>> listActive() async {
    final rows = await _client
        .from('games')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: true);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList();
  }
}
