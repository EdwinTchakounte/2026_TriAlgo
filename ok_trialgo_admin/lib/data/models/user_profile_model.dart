// =============================================================
// FICHIER : user_profile_model.dart (DTO data)
// ROLE    : Serialisation UserProfile <-> JSON Supabase
// =============================================================

import '../../domain/entities/user_profile.dart';

class UserProfileModel {
  UserProfileModel._();

  static UserProfile fromJson(Map<String, dynamic> j) {
    return UserProfile(
      id: j['id'] as String,
      // Defaut "Joueur" si username manquant (cas edge des comptes
      // anciens crees avant la colonne).
      username: (j['username'] as String?) ?? 'Joueur',
      avatarId: j['avatar_id'] as String?,
      isAdmin: (j['is_admin'] as bool?) ?? false,
    );
  }
}
