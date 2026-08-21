// =============================================================
// FICHIER : auth_repository.dart
// ROLE    : Encapsuler les operations d'authentification Supabase
// =============================================================
//
// Le dashboard est protege : seul un user authentifie ET avec
// is_admin = TRUE peut acceder. Ce repository expose 4 methodes :
//   - signIn(email, password) : connexion classique
//   - signOut()                : deconnexion
//   - currentUser              : user courant (ou null)
//   - fetchIsAdmin()           : flag depuis user_profiles
// =============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  // Acces au client Supabase global initialise dans main.dart.
  // On le recupere une seule fois pour ne pas le passer partout.
  final SupabaseClient _client;

  AuthRepository(this._client);

  // =========================================================
  // signIn : connecte avec email + password
  // =========================================================
  // Renvoie le User Supabase si la connexion reussit. Throw
  // AuthException sinon (mauvais credentials, compte non
  // verifie...). On laisse remonter l'exception pour que la UI
  // affiche un message specifique.
  // =========================================================
  Future<User> signIn(String email, String password) async {
    final res = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = res.user;
    if (user == null) {
      // Ne devrait jamais arriver avec password auth, mais on
      // garde la garde par securite.
      throw const AuthException('Connexion echouee : utilisateur null');
    }
    return user;
  }

  // Deconnexion : supprime le token local + invalide cote serveur.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // User courant. null si pas de session active.
  User? get currentUser => _client.auth.currentUser;

  // =========================================================
  // fetchIsAdmin : verifie le flag is_admin dans user_profiles
  // =========================================================
  // C'est LA porte d'entree du dashboard. Apres connexion, on
  // appelle cette methode. Si elle renvoie false, on deconnecte
  // immediatement et on affiche "Compte non admin".
  //
  // RLS en place : un user ne peut lire que son propre profil
  // (policy profiles_select_own). Donc id = auth.uid() implicite.
  // =========================================================
  Future<bool> fetchIsAdmin() async {
    final uid = currentUser?.id;
    if (uid == null) return false;

    final row = await _client
        .from('user_profiles')
        .select('is_admin')
        .eq('id', uid)
        .maybeSingle();

    if (row == null) return false;
    return (row['is_admin'] as bool?) ?? false;
  }
}
