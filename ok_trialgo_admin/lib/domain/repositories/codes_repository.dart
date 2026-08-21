// =============================================================
// FICHIER : codes_repository.dart (contrat domain)
// ROLE    : Gestion des codes d'activation par l'administrateur
// =============================================================
//
// Correspond aux cinq routes /api/admin/codes du backend. Elles
// existaient depuis le debut sans aucun ecran pour les appeler :
// les codes se creaient a la main via /docs ou curl.
//
// PAGINATION
// ----------
// listAll renvoie une PAGE et le TOTAL, pas la liste entiere. Un
// jeu diffuse en boite peut compter plusieurs milliers de codes ;
// tout charger d'un coup ferait ramer la console pour rien.
// =============================================================

import '../../core/utils/result.dart';
import '../entities/activation_code.dart';

/// Une page de codes, avec de quoi calculer la suite.
class PageDeCodes {
  /// Les codes de cette page.
  final List<ActivationCode> items;

  /// Nombre total de codes correspondant au filtre, toutes pages
  /// confondues. Sert a savoir s'il reste quelque chose a charger.
  final int total;

  /// Taille de page demandee.
  final int limit;

  /// Decalage de cette page depuis le debut.
  final int offset;

  const PageDeCodes({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// True s'il reste des codes a charger apres cette page.
  bool get aUneSuite => offset + items.length < total;
}

abstract class CodesRepository {
  /// Liste une page de codes, filtree sur [gameId] si fourni.
  Future<Result<PageDeCodes>> listAll({
    String? gameId,
    int limit = 50,
    int offset = 0,
  });

  /// Cree un code rattache a [gameId].
  ///
  /// Echoue si le code existe deja (409 cote serveur) ou si le jeu
  /// est introuvable (404).
  Future<Result<ActivationCode>> create({
    required String code,
    required String gameId,
    int maxDeviceChanges = 3,
  });

  /// Active ou desactive un code.
  Future<Result<ActivationCode>> setActive({
    required String code,
    required bool isActive,
  });

  /// Remet un code dans l'etat "jamais active".
  ///
  /// LE CAS D'USAGE REEL : un joueur a perdu son telephone, ou a
  /// epuise son quota de changements d'appareil. Cette operation
  /// detache le code de son proprietaire, oublie l'appareil, remet
  /// le compteur a zero et leve le blocage.
  ///
  /// A manier avec precaution : le code redevient utilisable par
  /// n'importe qui, y compris par quelqu'un a qui il aurait fuite.
  Future<Result<ActivationCode>> resetAssignment(String code);

  /// Supprime definitivement un code.
  ///
  /// Peut echouer si un joueur y est encore rattache : la cle
  /// etrangere user_games.activation_code est en RESTRICT cote
  /// base. C'est voulu -- on preserve l'historique du joueur
  /// plutot que de le casser en silence.
  Future<Result<void>> delete(String code);
}
