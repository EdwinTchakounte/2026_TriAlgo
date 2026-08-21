// =============================================================
// FICHIER : auth_repository_impl.dart
// ROLE    : Implementation Supabase de AuthRepository
// =============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_profile_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  // SupabaseClient est injecte (pas singleton fige) pour
  // faciliter les tests. En prod, on passera Supabase.instance.client.
  final SupabaseClient _client;

  AuthRepositoryImpl(this._client);

  // -----------------------------------------------------------
  // fetchCurrentProfile : appele au boot pour reprendre la
  // session persistee. Retourne null si pas de session.
  // -----------------------------------------------------------
  @override
  Future<Result<UserProfile?>> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // Pas connecte : succes "null" plutot que failure, parce
      // que c'est un etat normal au premier lancement.
      return const Ok<UserProfile?>(null);
    }
    try {
      // .single() = renvoie EXACTEMENT une ligne (ou throw).
      // user_profiles.id = auth.users.id par contrainte FK.
      final row = await _client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();
      return Ok(UserProfileModel.fromJson(row));
    } catch (e) {
      // On distingue le cas "pas de profil cree" (rare, devrait
      // pas arriver) du cas "erreur reseau" : message generique.
      return Err(DataFailure('Profil introuvable : $e'));
    }
  }

  // -----------------------------------------------------------
  // signIn : email + password. Cas a couvrir :
  //   1. Credentials invalides -> AuthException -> AuthFailure
  //   2. Login OK mais user_profiles n'a pas is_admin = TRUE
  //      -> on signOut et on renvoie NotAdminFailure
  //   3. Login OK + isAdmin -> Ok(UserProfile)
  // -----------------------------------------------------------
  @override
  Future<Result<UserProfile>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // GoTrue : valide les credentials et retourne une session.
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) {
        return const Err(AuthFailure('Connexion echouee'));
      }

      // On a une session : on FETCH le profil pour verifier
      // is_admin. La RLS sur user_profiles autorise l'user a
      // lire son propre profil (profiles_select_own).
      final profileRow = await _client
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .single();

      final profile = UserProfileModel.fromJson(profileRow);

      if (!profile.isAdmin) {
        // Pas admin : on degage la session pour qu'aucune
        // ecriture ne soit tentee. Et message clair.
        await _client.auth.signOut();
        return const Err(NotAdminFailure());
      }

      return Ok(profile);
    } on AuthException catch (e) {
      // Erreur GoTrue (mauvais password, email non confirme, etc.)
      // On expose le message tel quel (deja en anglais Supabase,
      // mais comprehensible).
      return Err(AuthFailure(e.message));
    } catch (e) {
      return Err(AuthFailure('Erreur : $e'));
    }
  }

  // -----------------------------------------------------------
  // signOut : sans gestion d'erreur particuliere. Si ca echoue,
  // la session sera de toute facon perdue au prochain restart.
  // -----------------------------------------------------------
  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
