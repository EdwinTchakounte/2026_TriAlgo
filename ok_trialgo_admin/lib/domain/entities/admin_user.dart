// =============================================================
// FICHIER : admin_user.dart (entite domain)
// ROLE    : Vue administrateur d'un compte utilisateur
// =============================================================
//
// POURQUOI UNE ENTITE DISTINCTE DE UserProfile
// --------------------------------------------
// UserProfile decrit l'administrateur CONNECTE : c'est "moi".
// AdminUser decrit un compte VU depuis la console d'administration :
// c'est "quelqu'un d'autre". Les deux n'exposent pas les memes
// champs et n'ont pas le meme cycle de vie ; les confondre
// amenerait tot ou tard a afficher les droits de l'un pour l'autre.
//
// CE QUE L'ADMINISTRATEUR PEUT CHANGER, ET CE QU'IL NE PEUT PAS
// -------------------------------------------------------------
// Modifiable : [isActive] (suspendre un compte) et [isAdmin]
// (promouvoir / retrograder, via une route dediee qui declenche un
// courriel).
//
// Non modifiable : l'adresse de courriel et le mot de passe. Le
// serveur ne l'expose tout simplement pas. C'est deliberе : laisser
// un administrateur changer l'adresse d'un compte reviendrait a lui
// donner le moyen de s'approprier n'importe quel compte en
// declenchant ensuite une reinitialisation de mot de passe.
// =============================================================

class AdminUser {
  /// UUID du compte.
  final String id;

  /// Adresse de courriel, qui sert aussi d'identifiant de connexion.
  final String email;

  /// True si ce compte a acces a la console d'administration.
  final bool isAdmin;

  /// False si le compte est suspendu : la connexion est refusee.
  final bool isActive;

  /// Date de confirmation de l'adresse, ou null si jamais confirmee.
  final DateTime? emailConfirmedAt;

  /// Date de creation du compte.
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.isAdmin,
    required this.isActive,
    required this.emailConfirmedAt,
    required this.createdAt,
  });

  /// True si l'utilisateur a confirme son adresse de courriel.
  bool get emailConfirme => emailConfirmedAt != null;

  /// Libelle court decrivant l'etat du compte.
  String get statutLisible {
    if (!isActive) return 'Suspendu';
    if (isAdmin) return 'Administrateur';
    return 'Joueur';
  }
}
