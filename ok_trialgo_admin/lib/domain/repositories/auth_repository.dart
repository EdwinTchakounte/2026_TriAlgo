// =============================================================
// FICHIER : auth_repository.dart (interface domain)
// ROLE    : Contrat pour la couche auth (sign-in / out / profile)
// =============================================================
//
// L'interface vit dans domain/ : elle est independante de
// Supabase. L'implementation concrete est dans data/ et utilise
// le SDK. Cette separation permet (1) de mocker pour les tests
// et (2) de changer de backend sans toucher a la presentation.
//
// Toutes les operations qui peuvent echouer fonctionnellement
// renvoient un Result<T> pour forcer la gestion d'erreur.
// =============================================================

import '../../core/utils/result.dart';
import '../entities/user_profile.dart';

abstract class AuthRepository {
  // Renvoie le profil de l'utilisateur connecte (lit auth.users
  // puis user_profiles via Supabase). null si pas de session.
  // Cette methode est utilisee au boot pour reprendre la session.
  Future<Result<UserProfile?>> fetchCurrentProfile();

  // Connexion email/password. Apres signIn reussi, on FETCH le
  // profil pour verifier isAdmin. Si l'user n'est PAS admin,
  // l'implementation doit signOut et renvoyer NotAdminFailure.
  Future<Result<UserProfile>> signIn({
    required String email,
    required String password,
  });

  // Deconnexion totale (vide la session locale Supabase).
  Future<void> signOut();
}
