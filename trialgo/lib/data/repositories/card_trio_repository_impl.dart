// =============================================================
// FICHIER : lib/data/repositories/card_trio_repository_impl.dart
// ROLE   : Implementation CONCRETE du CardTrioRepository (bi-mode)
// COUCHE : Data > Repositories
// =============================================================
//
// Implemente les 3 methodes de CardTrioRepository :
//   1. getRandomTrio       -> un trio aleatoire pour une question
//   2. isCoherent          -> verifier si un trio est valide
//   3. getTriosByDistance  -> tous les trios d'une distance
//
// BRANCHEMENT BACKEND :
//   - Supabase : SELECT direct sur table card_trios (vue precalculee).
//   - FastAPI  : pas de table card_trios cote backend ; on reconstruit
//                les trios a la volee depuis les nodes du jeu actif.
//                Un GameNode correspond exactement a un trio :
//                  emettrice_id (ou parent.receptrice_id si chaine)
//                  + cable_id + receptrice_id
//                  -> CardTrioEntity (depth devient distanceLevel).
//
// REFERENCE : Recueil de conception v3.0, sections 3.3 et 4.5
// =============================================================

import 'dart:math';

import 'package:trialgo/core/api/api_config.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/data/datasources/http/http_public_games_datasource.dart';
import 'package:trialgo/data/services/profile_service.dart';
import 'package:trialgo/domain/entities/card_trio_entity.dart';
import 'package:trialgo/domain/repositories/card_trio_repository.dart';
import 'package:trialgo/data/models/card_trio_model.dart';

/// Implementation de [CardTrioRepository] bi-mode.
class CardTrioRepositoryImpl implements CardTrioRepository {

  // -----------------------------------------------------------
  // DATASOURCES (mode FastAPI)
  // -----------------------------------------------------------
  final HttpPublicGamesDatasource _httpGames = HttpPublicGamesDatasource();
  final ProfileService _profileService = ProfileService();

  // -----------------------------------------------------------
  // Cache nodes en memoire (mode FastAPI) pour eviter de
  // re-telecharger a chaque appel. Cle = gameId.
  // -----------------------------------------------------------
  final Map<String, List<Map<String, dynamic>>> _nodesCache = {};

  // =============================================================
  // HELPERS FASTAPI
  // =============================================================

  /// Recupere les nodes du jeu actif (avec cache).
  /// Renvoie [] si aucun jeu n'est selectionne.
  Future<List<Map<String, dynamic>>> _loadNodesFastApi() async {
    var gameId = _profileService.selectedGameId;
    if (gameId == null) {
      await _profileService.loadProfile();
      gameId = _profileService.selectedGameId;
    }
    if (gameId == null) return const <Map<String, dynamic>>[];
    if (_nodesCache.containsKey(gameId)) return _nodesCache[gameId]!;
    final rows = await _httpGames.listGameNodesAuth(gameId);
    _nodesCache[gameId] = rows;
    return rows;
  }

  /// Convertit un GameNode (FastAPI) en CardTrioEntity, avec
  /// resolution de l'emettrice effective (deduite du parent si chaine).
  CardTrioEntity _nodeToTrio(
    Map<String, dynamic> node,
    Map<String, Map<String, dynamic>> nodesById,
  ) {
    // emettrice_id NULL = node enfant : on prend parent.receptrice.
    String? emettriceId = node['emettrice_id'] as String?;
    if (emettriceId == null) {
      final parentId = node['parent_node_id'] as String?;
      if (parentId != null) {
        final parent = nodesById[parentId];
        emettriceId = parent?['receptrice_id'] as String?;
      }
    }
    // CardTrioModel attend un JSON proche de Supabase. On forge un
    // Map compatible : id, emettrice_id, cable_id, receptrice_id,
    // distance_level (= depth), parent_trio_id, difficulty.
    final json = <String, dynamic>{
      'id': node['id'],
      'emettrice_id': emettriceId ?? '',
      'cable_id': node['cable_id'],
      'receptrice_id': node['receptrice_id'],
      'distance_level': node['depth'],
      'parent_trio_id': node['parent_node_id'],
      // Difficulty inconnu cote FastAPI : on met 1.0 par defaut
      // (le client peut moduler ailleurs si besoin).
      'difficulty': 1.0,
    };
    return CardTrioModel.fromJson(json);
  }

  // =============================================================
  // METHODE : getRandomTrio
  // =============================================================

  /// Recupere un trio aleatoire d'une [distance] donnee.
  ///
  /// [excludeIds] : IDs de trios a exclure (deja poses dans la session).
  @override
  Future<CardTrioEntity> getRandomTrio({
    required int distance,
    List<String> excludeIds = const [],
  }) async {
    // ---- Mode FastAPI : construction depuis les nodes ----
    if (ApiConfig.isFastApi) {
      final nodes = await _loadNodesFastApi();
      final nodesById = {for (final n in nodes) (n['id'] as String): n};
      // Filtre par depth (= distance) + exclusion.
      final exclude = excludeIds.toSet();
      final pool = nodes
          .where((n) => (n['depth'] as int) == distance)
          .where((n) => !exclude.contains(n['id'] as String))
          .toList();
      if (pool.isEmpty) {
        throw Exception('Aucun trio disponible pour la distance $distance');
      }
      pool.shuffle(Random());
      return _nodeToTrio(pool.first, nodesById);
    }

    // ---- Mode Supabase : SELECT sur card_trios ----
    var query = supabase
        .from('card_trios')
        .select()
        .eq('distance_level', distance);
    if (excludeIds.isNotEmpty) {
      query = query.not('id', 'in', excludeIds);
    }
    final data = await query.limit(10);
    if (data.isEmpty) {
      throw Exception('Aucun trio disponible pour la distance $distance');
    }
    final randomIndex = DateTime.now().millisecondsSinceEpoch % data.length;
    return CardTrioModel.fromJson(data[randomIndex]);
  }

  // =============================================================
  // METHODE : isCoherent
  // =============================================================

  /// Verifie si le trio (E, C, R) existe dans le graphe du jeu actif.
  /// Retourne `true` si la combinaison est valide, `false` sinon.
  @override
  Future<bool> isCoherent({
    required String emettriceId,
    required String cableId,
    required String receptriceId,
  }) async {
    // ---- Mode FastAPI : parcours des nodes en local ----
    if (ApiConfig.isFastApi) {
      final nodes = await _loadNodesFastApi();
      final nodesById = {for (final n in nodes) (n['id'] as String): n};
      for (final n in nodes) {
        // Calcule l'emettrice effective : si null, on remonte au parent.
        String? effectiveA = n['emettrice_id'] as String?;
        if (effectiveA == null) {
          final parentId = n['parent_node_id'] as String?;
          if (parentId != null) {
            effectiveA = nodesById[parentId]?['receptrice_id'] as String?;
          }
        }
        if (effectiveA == emettriceId &&
            n['cable_id'] == cableId &&
            n['receptrice_id'] == receptriceId) {
          return true;
        }
      }
      return false;
    }

    // ---- Mode Supabase : SELECT EXISTS sur card_trios ----
    final data = await supabase
        .from('card_trios')
        .select('id')
        .eq('emettrice_id', emettriceId)
        .eq('cable_id', cableId)
        .eq('receptrice_id', receptriceId);
    return data.isNotEmpty;
  }

  // =============================================================
  // METHODE : getTriosByDistance
  // =============================================================

  /// Recupere tous les trios d'une [distance] donnee.
  @override
  Future<List<CardTrioEntity>> getTriosByDistance(int distance) async {
    // ---- Mode FastAPI : nodes -> trios ----
    if (ApiConfig.isFastApi) {
      final nodes = await _loadNodesFastApi();
      final nodesById = {for (final n in nodes) (n['id'] as String): n};
      return nodes
          .where((n) => (n['depth'] as int) == distance)
          .map((n) => _nodeToTrio(n, nodesById))
          .toList();
    }

    // ---- Mode Supabase ----
    final data = await supabase
        .from('card_trios')
        .select()
        .eq('distance_level', distance);
    return data.map((json) => CardTrioModel.fromJson(json)).toList();
  }
}
