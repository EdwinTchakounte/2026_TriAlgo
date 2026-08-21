// =============================================================
// FICHIER : user_profile.dart (entite domain)
// ROLE    : Profil utilisateur courant (post-login)
// =============================================================
//
// Une seule chose nous interesse vraiment cote dashboard admin :
// isAdmin. Le reste (username, avatar) n'est pas vital ici mais
// on l'expose au cas ou on veut afficher "Bonjour Edwin".
//
// On distingue volontairement UserProfile (table user_profiles)
// de la session Supabase (auth.users + JWT). Une session existe
// avant qu'on confirme is_admin. Si la fetch echoue, on
// considere l'utilisateur comme non-admin.
// =============================================================

class UserProfile {
  // Meme UUID que auth.users.id (foreign key).
  final String id;
  final String username;
  final String? avatarId;
  // SEUL champ critique pour cette app. Si false, on bloque
  // l'acces aux pages d'edition.
  final bool isAdmin;

  const UserProfile({
    required this.id,
    required this.username,
    required this.avatarId,
    required this.isAdmin,
  });
}
