// =============================================================
// FICHIER : lib/core/error/failures.dart
// ROLE   : Definir les types d'erreurs structures de l'application
// COUCHE : Core > Error
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// Dans une application, les erreurs sont inevitables :
//   - Pas de connexion internet
//   - Token JWT expire
//   - Code d'activation invalide
//   - Image introuvable dans le storage
//
// Sans structure, on gere les erreurs avec des try/catch generiques
// et des messages en dur. C'est fragile et difficile a maintenir.
//
// Ce fichier definit une HIERARCHIE d'erreurs typees :
//   Failure (classe de base abstraite)
//     +-- ServerFailure       : erreur reseau / serveur
//     +-- AuthFailure         : erreur d'authentification
//     +-- ActivationFailure   : erreur de code d'activation
//     +-- CardFailure         : erreur liee aux cartes
//
// AVANTAGE : on peut reagir differemment selon le TYPE d'erreur
// (afficher un message specifique, rediriger vers un ecran, etc.)
// =============================================================

/// Classe de base pour toutes les erreurs metier de TRIALGO.
///
/// [Failure] est "sealed" (scellee) : seules les sous-classes
/// definies dans CE fichier peuvent en heriter.
/// Cela garantit que l'on connait TOUS les types d'erreur possibles
/// et que le compilateur verifie qu'on les gere tous.
///
/// Chaque erreur contient un [message] lisible par l'utilisateur
/// et un [code] technique pour le debugging.
sealed class Failure {
  /// Message affichable a l'utilisateur (en francais).
  final String message;

  /// Code technique pour identifier l'erreur dans les logs.
  final String code;

  const Failure({required this.message, required this.code});

  @override
  String toString() => 'Failure($code): $message';
}

// ---------------------------------------------------------------
// ServerFailure : erreurs reseau et serveur
// ---------------------------------------------------------------
// Cas d'usage dans TRIALGO :
//   - Pas de connexion internet
//   - Supabase est en panne (timeout)
//   - Erreur 500 du serveur
// ---------------------------------------------------------------

/// Erreur de communication avec le serveur Supabase.
class ServerFailure extends Failure {
  /// Code HTTP de la reponse (ex: 500, 503), ou null si pas de reponse.
  final int? statusCode;

  const ServerFailure({
    required super.message,
    super.code = 'server_error',
    this.statusCode,
  });

  /// Constructeur pour les erreurs de connexion (pas d'internet).
  factory ServerFailure.noConnection() => const ServerFailure(
        message: 'Pas de connexion internet. Verifiez votre reseau.',
        code: 'no_connection',
      );

  /// Constructeur pour les timeouts (serveur trop lent).
  factory ServerFailure.timeout() => const ServerFailure(
        message: 'Le serveur met trop de temps a repondre. Reessayez.',
        code: 'timeout',
      );
}

// ---------------------------------------------------------------
// AuthFailure : erreurs d'authentification
// ---------------------------------------------------------------
// Cas d'usage dans TRIALGO :
//   - Email/mot de passe incorrect
//   - Email deja utilise
//   - Email pas encore verifie
//   - Token JWT expire
// ---------------------------------------------------------------

/// Erreur liee a l'authentification Supabase.
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code = 'auth_error',
  });

  /// Email ou mot de passe incorrect lors de la connexion.
  factory AuthFailure.invalidCredentials() => const AuthFailure(
        message: 'Email ou mot de passe incorrect.',
        code: 'invalid_credentials',
      );

  /// L'email est deja associe a un compte existant.
  factory AuthFailure.emailAlreadyUsed() => const AuthFailure(
        message: 'Cet email est deja associe a un compte. Connectez-vous.',
        code: 'user_already_exists',
      );

  /// L'email n'a pas encore ete verifie (lien non clique).
  factory AuthFailure.emailNotConfirmed() => const AuthFailure(
        message: 'Email non confirme. Un nouveau lien a ete envoye.',
        code: 'email_not_confirmed',
      );

  /// Le mot de passe est trop faible (< 8 caracteres).
  factory AuthFailure.weakPassword() => const AuthFailure(
        message: 'Minimum 8 caracteres requis.',
        code: 'weak_password',
      );

  /// Le token JWT a expire et le refresh token est invalide.
  /// Le joueur doit se reconnecter.
  factory AuthFailure.sessionExpired() => const AuthFailure(
        message: 'Session expiree. Veuillez vous reconnecter.',
        code: 'session_expired',
      );
}

// ---------------------------------------------------------------
// ActivationFailure : erreurs du code d'activation physique
// ---------------------------------------------------------------
// Cas d'usage dans TRIALGO :
//   - Code invalide (n'existe pas en base)
//   - Code deja utilise sur un autre appareil
//   - Format incorrect du code
// ---------------------------------------------------------------

/// Erreur liee a l'activation du code de jeu physique.
class ActivationFailure extends Failure {
  const ActivationFailure({
    required super.message,
    super.code = 'activation_error',
  });

  /// Le code saisi n'existe pas dans la base de donnees.
  factory ActivationFailure.notFound() => const ActivationFailure(
        message: 'Code introuvable. Verifiez le code inscrit dans votre boite.',
        code: 'not_found',
      );

  /// Le code a deja ete active sur un autre appareil.
  factory ActivationFailure.deviceConflict() => const ActivationFailure(
        message: 'Ce code a deja ete active sur un autre appareil.',
        code: 'device_conflict',
      );

  /// Le format du code est incorrect (pas 16 caracteres alphanumeriques).
  factory ActivationFailure.invalidFormat() => const ActivationFailure(
        message: 'Format incorrect. Le code contient 16 caracteres.',
        code: 'invalid_format',
      );
}

// ---------------------------------------------------------------
// CardFailure : erreurs liees aux cartes et trios
// ---------------------------------------------------------------
// Cas d'usage dans TRIALGO :
//   - Aucun trio disponible pour le niveau demande
//   - Image introuvable dans le storage
// ---------------------------------------------------------------

/// Erreur liee au chargement ou a la validation des cartes.
class CardFailure extends Failure {
  const CardFailure({
    required super.message,
    super.code = 'card_error',
  });

  /// Aucun trio disponible pour la distance et le niveau demande.
  factory CardFailure.noTrioAvailable() => const CardFailure(
        message: 'Aucun trio disponible pour cette distance et ce niveau.',
        code: 'no_trio_available',
      );

  /// L'image d'une carte est introuvable dans Supabase Storage.
  factory CardFailure.brokenImage(String imagePath) => CardFailure(
        message: 'Image introuvable : $imagePath',
        code: 'broken_image',
      );
}
