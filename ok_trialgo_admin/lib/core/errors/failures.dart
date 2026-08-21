// =============================================================
// FICHIER : failures.dart
// ROLE    : Modeliser les erreurs metier (vs exceptions techniques)
// =============================================================
//
// Pourquoi separer "Failure" et "Exception" ?
//
// Exception : erreur TECHNIQUE non prevue (timeout reseau, JSON
// malforme, plantage SDK Supabase). On la laisse remonter ou on
// la log brutalement.
//
// Failure : erreur METIER attendue (mauvais mot de passe, pas
// admin, jeu inexistant, image trop grosse). On la traite dans
// l'UI avec un message clair, c'est PAS un bug.
//
// Cette separation aide la couche presentation : elle peut
// matcher sur Failure et afficher le bon message sans casser
// le flow utilisateur.
// =============================================================

sealed class Failure {
  // Message lisible par l'utilisateur final (en francais).
  final String message;

  const Failure(this.message);

  @override
  String toString() => '$runtimeType($message)';
}

// -------------------------------------------------------------
// AUTH
// -------------------------------------------------------------
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class NotAdminFailure extends Failure {
  const NotAdminFailure()
      : super(
          'Ce compte n\'a pas les droits administrateur. '
          'Contactez le responsable du jeu pour obtenir l\'acces.',
        );
}

// -------------------------------------------------------------
// DONNEES (Supabase)
// -------------------------------------------------------------
class DataFailure extends Failure {
  const DataFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

// -------------------------------------------------------------
// STORAGE (upload image)
// -------------------------------------------------------------
class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure()
      : super('Image trop volumineuse (max 5 MB).');
}

// -------------------------------------------------------------
// VALIDATION (cote app)
// -------------------------------------------------------------
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
