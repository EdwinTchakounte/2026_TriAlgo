// =============================================================
// FICHIER : admin_users_repository.dart (contrat domain)
// ROLE    : Gestion des comptes utilisateurs par l'administrateur
// =============================================================
//
// Correspond aux quatre routes /api/admin/users du backend, elles
// aussi sans aucun appelant jusqu'ici.
//
// LES DEUX GARDE-FOUS QUE LE SERVEUR IMPOSE
// -----------------------------------------
// Ils ne sont pas duplicables cote client de facon fiable, donc on
// laisse le serveur trancher et on affiche son message :
//
//   1. Un administrateur ne peut pas se retrograder s'il est le
//      dernier administrateur actif. Sans ce garde-fou, la console
//      deviendrait definitivement inaccessible.
//   2. Un administrateur ne peut pas suspendre son propre compte,
//      pour la meme raison.
//
// Les deux repondent 400 avec un message explicite.
// =============================================================

import '../../core/utils/result.dart';
import '../entities/admin_user.dart';

/// Une page de comptes utilisateurs.
class PageDUtilisateurs {
  /// Les comptes de cette page.
  final List<AdminUser> items;

  /// Nombre total de comptes, toutes pages confondues.
  final int total;

  /// Taille de page demandee.
  final int limit;

  /// Decalage de cette page depuis le debut.
  final int offset;

  const PageDUtilisateurs({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// True s'il reste des comptes a charger apres cette page.
  bool get aUneSuite => offset + items.length < total;
}

abstract class AdminUsersRepository {
  /// Liste une page de comptes, du plus recent au plus ancien.
  ///
  /// Le serveur borne [limit] a 100.
  Future<Result<PageDUtilisateurs>> listAll({
    int limit = 20,
    int offset = 0,
  });

  /// Bascule le statut administrateur d'un compte.
  ///
  /// C'est un TOGGLE cote serveur : il n'y a pas de parametre
  /// "vers quel etat". Promouvoir declenche l'envoi d'un courriel
  /// au compte concerne ; retrograder n'en envoie aucun.
  Future<Result<AdminUser>> togglePromotion(String userId);

  /// Suspend ou reactive un compte.
  ///
  /// Une suspension declenche l'envoi d'un courriel de notification.
  Future<Result<AdminUser>> setActive({
    required String userId,
    required bool isActive,
  });
}
