// =============================================================
// FICHIER : game_repository_impl.dart
// ROLE    : Implementation Supabase de GameRepository
// =============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/game.dart';
import '../../domain/repositories/game_repository.dart';
import '../models/game_model.dart';

class GameRepositoryImpl implements GameRepository {
  final SupabaseClient _client;

  GameRepositoryImpl(this._client);

  // Nom de la table pour eviter les magic strings dispersees.
  static const _table = 'games';

  // -----------------------------------------------------------
  // listAll : ordonne par created_at decroissant.
  // Les RLS autorisent tous les authenticated a SELECT les games
  // actifs ; admin voit tout via games_admin_all.
  // -----------------------------------------------------------
  @override
  Future<Result<List<Game>>> listAll() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false);
      // PostgREST renvoie une List<dynamic> ; on cast chaque row.
      final games = (rows as List)
          .map((r) => GameModel.fromJson(r as Map<String, dynamic>))
          .toList();
      return Ok(games);
    } catch (e) {
      return Err(DataFailure('Liste games impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // create : INSERT puis SELECT immediat avec .single() pour
  // recuperer la ligne complete (id, created_at).
  // -----------------------------------------------------------
  @override
  Future<Result<Game>> create({
    required String name,
    String? description,
    String? theme,
  }) async {
    try {
      final row = await _client
          .from(_table)
          .insert(GameModel.toInsert(
            name: name,
            description: description,
            theme: theme,
          ))
          // .select().single() apres insert = recupere la ligne
          // creee avec ses defauts (id genere, created_at).
          .select()
          .single();
      return Ok(GameModel.fromJson(row));
    } catch (e) {
      return Err(DataFailure('Creation game impossible : $e'));
    }
  }

  // -----------------------------------------------------------
  // update : UPDATE partiel. Si aucun champ a modifier, on
  // renvoie une erreur de validation.
  // -----------------------------------------------------------
  @override
  Future<Result<Game>> update({
    required String id,
    String? name,
    String? description,
    String? theme,
    bool? isActive,
  }) async {
    final patch = GameModel.toUpdate(
      name: name,
      description: description,
      theme: theme,
      isActive: isActive,
    );
    if (patch.isEmpty) {
      return const Err(
        ValidationFailure('Aucun champ a modifier'),
      );
    }
    try {
      final row = await _client
          .from(_table)
          .update(patch)
          .eq('id', id)
          .select()
          .single();
      return Ok(GameModel.fromJson(row));
    } catch (e) {
      return Err(DataFailure('Update game impossible : $e'));
    }
  }
}
