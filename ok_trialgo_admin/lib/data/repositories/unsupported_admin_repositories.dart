// =============================================================
// FICHIER : unsupported_admin_repositories.dart
// ROLE    : Implementations de repli hors mode FastAPI
// =============================================================
//
// POURQUOI CE FICHIER EXISTE
// --------------------------
// La gestion des codes d'activation et des comptes utilisateurs
// n'a d'equivalent NI en mode 'fake' NI en mode 'supabase' : ces
// endpoints sont nes avec le backend FastAPI.
//
// Trois facons de traiter ce trou, et pourquoi on choisit la
// troisieme :
//
//   1. Ne pas enregistrer le provider hors fastapi -> plantage a
//      l'ouverture de l'ecran, avec une trace incomprehensible.
//   2. Renvoyer des listes vides -> l'administrateur croit que sa
//      base est vide alors qu'elle ne l'est pas. Le pire des trois.
//   3. Renvoyer un Err explicite -> l'ecran s'ouvre, affiche une
//      phrase qui dit quoi faire, et rien ne ment.
//
// L'UI n'a aucun cas particulier a gerer : elle traite ce Err
// exactement comme n'importe quelle autre erreur.
// =============================================================

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/activation_code.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../../domain/repositories/codes_repository.dart';

/// Message unique, pour ne pas le desynchroniser entre les deux.
const _message =
    "La gestion des codes et des comptes n'est disponible qu'avec "
    'le backend FastAPI. Basculez ApiConfig.mode sur fastapi.';

/// CodesRepository inerte, hors mode FastAPI.
class UnsupportedCodesRepository implements CodesRepository {
  const UnsupportedCodesRepository();

  @override
  Future<Result<PageDeCodes>> listAll({
    String? gameId,
    int limit = 50,
    int offset = 0,
  }) async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<ActivationCode>> create({
    required String code,
    required String gameId,
    int maxDeviceChanges = 3,
  }) async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<ActivationCode>> setActive({
    required String code,
    required bool isActive,
  }) async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<ActivationCode>> resetAssignment(String code) async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<void>> delete(String code) async =>
      const Err(DataFailure(_message));
}

/// AdminUsersRepository inerte, hors mode FastAPI.
class UnsupportedAdminUsersRepository implements AdminUsersRepository {
  const UnsupportedAdminUsersRepository();

  @override
  Future<Result<PageDUtilisateurs>> listAll({
    int limit = 20,
    int offset = 0,
  }) async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<AdminUser>> togglePromotion(String userId) async =>
      const Err(DataFailure(_message));

  @override
  Future<Result<AdminUser>> setActive({
    required String userId,
    required bool isActive,
  }) async =>
      const Err(DataFailure(_message));
}
