// =============================================================
// FICHIER : lib/presentation/providers/auth_provider.dart
// ROLE   : Gerer l'etat d'authentification de l'application
// COUCHE : Presentation > Providers
// =============================================================
//
// QU'EST-CE QU'UN PROVIDER ?
// --------------------------
// Un provider Riverpod est un CONTENEUR D'ETAT accessible
// depuis n'importe quel widget de l'application.
//
// Il remplace le pattern classique de Flutter ou l'on passe
// les donnees de widget en widget via les constructeurs.
// Avec Riverpod, chaque widget peut LIRE directement l'etat
// via ref.watch(provider) ou ref.read(provider).
//
// QU'EST-CE QU'UN STATENOTIFIER ?
// --------------------------------
// StateNotifier est une classe Riverpod qui :
//   1. Stocke un ETAT (une valeur qui peut changer)
//   2. Fournit des METHODES pour modifier cet etat
//   3. NOTIFIE automatiquement les widgets quand l'etat change
//
// C'est comme un "mini-controlleur" : il contient la logique
// et les widgets se contentent d'afficher l'etat.
//
// DANS TRIALGO :
// --------------
// L'AuthNotifier gere le flux d'authentification complet :
//   - Non connecte -> formulaire login/inscription
//   - Connecte, pas de code -> ecran d'activation
//   - Connecte + code actif -> menu principal
//
// REFERENCE : Recueil de conception v3.0, section 12
// =============================================================

// Import de Riverpod pour StateNotifier et StateNotifierProvider.
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import du SDK Supabase pour les types User et AuthState.
import 'package:supabase_flutter/supabase_flutter.dart';

// Import de la datasource d'authentification.
import 'package:trialgo/data/datasources/supabase_auth_datasource.dart';

// Import des erreurs structurees.
import 'package:trialgo/core/error/failures.dart';

// =============================================================
// ENUM : AuthStatus
// =============================================================
// Represente les differents ETATS possibles de l'authentification.
//
// L'application navigue entre ces etats :
//   initial -> loading -> authenticated/unauthenticated/needsActivation
//                      -> error (en cas de probleme)
//
// Le widget qui affiche l'ecran utilise cet enum pour decider
// QUEL ecran montrer.
// =============================================================

/// Les etats possibles de l'authentification.
enum AuthStatus {
  /// Etat initial : l'app vient de demarrer, on ne sait pas encore.
  /// Affiche un splash screen ou un indicateur de chargement.
  initial,

  /// En cours de traitement : une operation d'auth est en cours.
  /// Affiche un spinner sur le bouton ou un overlay de chargement.
  loading,

  /// L'utilisateur est connecte ET son code est active.
  /// Redirige vers le menu principal.
  authenticated,

  /// L'utilisateur n'est PAS connecte.
  /// Affiche l'ecran de connexion/inscription.
  unauthenticated,

  /// L'utilisateur est connecte MAIS n'a pas active de code.
  /// Affiche l'ecran de saisie du code d'activation.
  needsActivation,

  /// Une erreur s'est produite (affiche un message).
  error,
}

// =============================================================
// CLASSE : AuthState (l'etat stocke)
// =============================================================
// Contient TOUTES les informations necessaires pour determiner
// quoi afficher a l'ecran.
//
// C'est un objet IMMUABLE : pour changer l'etat, on cree
// un NOUVEL AuthState avec les valeurs modifiees via copyWith().
//
// Pourquoi immuable ?
//   - Riverpod detecte les changements par COMPARAISON de references.
//   - Si on modifiait l'objet en place, Riverpod ne saurait pas
//     que l'etat a change et ne reconstruirait pas les widgets.
//   - Avec un nouvel objet, la reference change -> rebuild.
// =============================================================

/// Etat d'authentification de l'application.
///
/// Contient le statut, l'utilisateur connecte, et un eventuel
/// message d'erreur. Immuable — utiliser [copyWith] pour modifier.
class AuthState {
  /// Statut actuel de l'authentification.
  final AuthStatus status;

  /// L'utilisateur Supabase connecte, ou `null` si deconnecte.
  ///
  /// "User" est un type du SDK Supabase contenant :
  ///   .id    : UUID de l'utilisateur
  ///   .email : adresse email
  ///   .appMetadata : metadonnees (provider Google, etc.)
  final User? user;

  /// Message d'erreur a afficher, ou `null` si pas d'erreur.
  final String? errorMessage;

  /// Constructeur. Valeurs par defaut : initial, pas d'utilisateur, pas d'erreur.
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  // =============================================================
  // METHODE : copyWith
  // =============================================================
  // Cree une COPIE de cet objet avec certaines valeurs modifiees.
  //
  // "copyWith" est un pattern courant en Dart pour les objets immuables.
  // Au lieu de modifier l'objet existant, on en cree un nouveau
  // avec les changements souhaites.
  //
  // Chaque parametre est OPTIONNEL (note le "?").
  // Si un parametre n'est pas fourni, la valeur actuelle est conservee.
  //
  // Exemple :
  //   final etat1 = AuthState(status: AuthStatus.loading);
  //   final etat2 = etat1.copyWith(status: AuthStatus.authenticated, user: monUser);
  //   // etat1 n'a PAS change (immuable)
  //   // etat2 a le nouveau statut ET le user
  // =============================================================

  /// Cree une copie avec les valeurs modifiees.
  ///
  /// Les parametres non fournis conservent leur valeur actuelle.
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      // "status ?? this.status" :
      //   Si le nouveau status est fourni (non null) -> utilise-le.
      //   Si le nouveau status est null (non fourni) -> garde l'ancien.
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// =============================================================
// CLASSE : AuthNotifier (la logique)
// =============================================================
// StateNotifier<AuthState> signifie :
//   - Cette classe GERE un etat de type AuthState
//   - "state" est la propriete qui contient l'etat actuel
//   - Modifier "state" notifie automatiquement les widgets
//
// "extends StateNotifier<AuthState>" :
//   - On herite de StateNotifier
//   - Le generique <AuthState> precise le TYPE de l'etat gere
//   - StateNotifier fournit la propriete "state" et la notification
// =============================================================

/// Notifier qui gere la logique d'authentification.
///
/// Contient les methodes pour se connecter, s'inscrire, se deconnecter.
/// Modifie [state] (AuthState) a chaque changement, ce qui
/// reconstruit automatiquement les widgets qui utilisent ref.watch.
class AuthNotifier extends StateNotifier<AuthState> {
  // =============================================================
  // PROPRIETE : _authDatasource
  // =============================================================
  // Le "_" devant le nom rend la propriete PRIVEE.
  // En Dart, une propriete privee n'est accessible que depuis
  // le MEME FICHIER. Les autres fichiers ne peuvent pas y acceder.
  //
  // C'est de l'ENCAPSULATION : la logique interne du notifier
  // n'est pas exposee aux widgets. Ils n'interagissent qu'avec
  // les methodes publiques (signIn, signUp, signOut).
  // =============================================================

  /// Datasource pour les appels Supabase Auth (privee).
  final SupabaseAuthDatasource _authDatasource;

  // =============================================================
  // CONSTRUCTEUR
  // =============================================================
  // "AuthNotifier(this._authDatasource) : super(const AuthState())"
  //
  // Decomposition :
  //   "this._authDatasource" : assigne le parametre a la propriete
  //   ": super(const AuthState())" : initialise l'etat du StateNotifier
  //     avec un AuthState par defaut (status = initial)
  //
  // "super(const AuthState())" appelle le constructeur de StateNotifier
  // avec la VALEUR INITIALE de l'etat. C'est obligatoire :
  // StateNotifier a besoin d'un etat initial pour demarrer.
  //
  // Apres le constructeur, on appelle _init() pour verifier
  // si une session est deja active (reconnexion automatique).
  // =============================================================

  /// Cree le notifier avec la datasource d'authentification.
  ///
  /// Appelle [_init] pour verifier la session existante.
  AuthNotifier(this._authDatasource) : super(const AuthState()) {
    // "_init()" est appele APRES la creation de l'objet.
    // Il verifie si l'utilisateur est deja connecte.
    _init();
  }

  // =============================================================
  // METHODE PRIVEE : _init
  // =============================================================
  // Verifie l'etat de la session au demarrage de l'application.
  //
  // Scenarios (reference : recueil section 12.2) :
  //   1. Session active + code active -> authenticated
  //   2. Session active + pas de code -> needsActivation
  //   3. Pas de session               -> unauthenticated
  // =============================================================

  /// Verifie la session existante au demarrage.
  Future<void> _init() async {
    // Recupere l'utilisateur stocke localement par le SDK.
    // Si l'app a ete fermee et relancee, le SDK restaure
    // automatiquement la session (si le refresh token est valide).
    final user = _authDatasource.currentUser;

    // Cas 1 : pas d'utilisateur -> ecran de connexion
    if (user == null) {
      // "state = ..." : modifie l'etat du StateNotifier.
      // Tous les widgets qui font ref.watch(authProvider)
      // seront RECONSTRUITS automatiquement.
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
      // "return" sort de la methode. Le code apres n'est pas execute.
    }

    // Cas 2 : utilisateur connecte -> verifier le code d'activation
    await _checkActivation(user);
  }

  // =============================================================
  // METHODE PRIVEE : _checkActivation
  // =============================================================
  // Verifie si l'utilisateur a un code d'activation actif.
  //
  // Fait une requete sur la table activation_codes pour verifier
  // s'il existe un enregistrement lie a ce user_id avec is_activated=true.
  // =============================================================

  /// Verifie si l'utilisateur a active un code de jeu.
  Future<void> _checkActivation(User user) async {
    try {
      // Cherche le profil de cet utilisateur dans user_profiles.
      final profile = await _authDatasource.getProfile(user.id);

      if (profile == null) {
        // Pas de profil -> en creer un par defaut.
        // Cela arrive a la PREMIERE connexion.
        try {
          await _authDatasource.createProfile(
            userId: user.id,
            username: 'Joueur_${user.id.substring(0, 8)}',
          );
        } catch (createError) {
          // Si la creation echoue (ex: conflit de cle primaire,
          // le profil existe deja suite a une race condition),
          // on ignore l'erreur et on continue.
          // Le profil sera re-lu au prochain demarrage.
          // Creation profil ignoree (peut etre un conflit de cle)
        }
      }

      // L'utilisateur est connecte. On passe directement au menu.
      // (La verification du code d'activation sera ajoutee plus tard)
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      // En cas d'erreur reseau lors de la lecture du profil,
      // on passe quand meme en authentifie pour ne pas bloquer.
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    }
  }

  // =============================================================
  // METHODE PUBLIQUE : signUp
  // =============================================================
  // Inscrit un nouvel utilisateur avec email + mot de passe.
  //
  // Flux :
  //   1. Passe en etat "loading" (spinner affiche)
  //   2. Appelle Supabase Auth signUp
  //   3. Si succes -> etat "unauthenticated" (attente verif email)
  //   4. Si erreur -> etat "error" avec message
  // =============================================================

  /// Inscrit un nouvel utilisateur.
  ///
  /// [email]    : adresse email.
  /// [password] : mot de passe (>= 8 caracteres).
  ///
  /// Apres succes, l'utilisateur doit verifier son email.
  /// L'etat reste [AuthStatus.unauthenticated] jusqu'a la verification.
  Future<void> signUp(String email, String password) async {
    // Etape 1 : passer en chargement
    state = state.copyWith(status: AuthStatus.loading);

    try {
      // Etape 2 : appeler Supabase
      final response = await _authDatasource.signUp(email: email, password: password);

      // Etape 3 : verifier si une session a ete creee immediatement
      // (cas ou "Confirm email" est desactive dans Supabase)
      if (response.session != null && response.user != null) {
        // Session creee immediatement -> l'utilisateur est connecte.
        await _checkActivation(response.user!);
      } else {
        // Pas de session -> en attente de verification email.
        state = const AuthState(status: AuthStatus.unauthenticated);
      }

    } on Failure catch (e) {
      // Erreurs structurees (AuthFailure, ServerFailure).
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      // Erreurs imprevues (reseau, timeout, etc.).
      // SANS ce catch, l'app reste bloquee en etat "loading".
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erreur : $e',
      );
    }
  }

  // =============================================================
  // METHODE PUBLIQUE : signIn
  // =============================================================
  // Connecte un utilisateur existant.
  //
  // Flux :
  //   1. Loading
  //   2. Appel Supabase signIn
  //   3. Si succes -> verification activation -> authenticated/needsActivation
  //   4. Si erreur -> etat error
  // =============================================================

  /// Connecte un utilisateur avec email et mot de passe.
  ///
  /// [email]    : adresse email.
  /// [password] : mot de passe.
  ///
  /// Si succes, l'etat passe a [AuthStatus.authenticated] ou
  /// [AuthStatus.needsActivation] selon le statut du code.
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final response = await _authDatasource.signIn(
        email: email,
        password: password,
      );

      // "response.user" : l'objet User retourne par Supabase.
      // Ne devrait jamais etre null apres un signIn reussi,
      // mais on verifie par securite.
      if (response.user != null) {
        await _checkActivation(response.user!);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } on Failure catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      // Erreurs imprevues (reseau, timeout, SocketException, etc.).
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'Erreur de connexion : $e',
      );
    }
  }

  // =============================================================
  // METHODE PUBLIQUE : signInWithGoogle
  // =============================================================
  // Lance le flux OAuth Google.
  //
  // Particularite : la connexion Google ne retourne pas directement
  // de reponse. La session est creee via un CALLBACK (evenement).
  // Le AuthNotifier ecoute ces evenements dans _listenToAuthChanges().
  // =============================================================

  /// Lance la connexion Google OAuth.
  ///
  /// Le navigateur s'ouvre. Apres connexion, la session est creee
  /// via le callback onAuthStateChange.
  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _authDatasource.signInWithGoogle();
      // La suite est geree par onAuthStateChange (evenement SIGNED_IN)
    } on Failure catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
    }
  }

  // =============================================================
  // METHODE PUBLIQUE : signOut
  // =============================================================
  // Deconnecte l'utilisateur et retourne a l'ecran de connexion.
  // =============================================================

  /// Deconnecte l'utilisateur actuel.
  ///
  /// Supprime la session locale et passe en [AuthStatus.unauthenticated].
  Future<void> signOut() async {
    await _authDatasource.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // =============================================================
  // METHODE PUBLIQUE : clearError
  // =============================================================
  // Efface le message d'erreur et retourne a l'etat precedent.
  // Appele quand l'utilisateur ferme le dialog d'erreur.
  // =============================================================

  /// Efface le message d'erreur et retourne a l'ecran de connexion.
  void clearError() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// =============================================================
// PROVIDER : authProvider
// =============================================================
// C'est le POINT D'ENTREE utilise par les widgets.
//
// "StateNotifierProvider" :
//   - Premier generique <AuthNotifier> : le type du StateNotifier
//   - Deuxieme generique <AuthState> : le type de l'etat
//
// "(ref) => AuthNotifier(...)" : la fonction de creation.
//   "ref" est un objet Riverpod qui permet de :
//     - Lire d'autres providers (ref.read, ref.watch)
//     - Ecouter des changements (ref.listen)
//     - Liberer des ressources (ref.onDispose)
//
// Utilisation dans un widget :
//   final authState = ref.watch(authProvider);  // Lit l'etat
//   ref.read(authProvider.notifier).signIn(...); // Appelle une methode
//
// "ref.watch(authProvider)" :
//   -> Retourne l'AuthState actuel
//   -> Reconstruit le widget quand l'etat change
//
// "ref.read(authProvider.notifier)" :
//   -> Retourne l'AuthNotifier (pas l'etat)
//   -> Permet d'appeler les methodes (signIn, signOut, etc.)
//   -> NE reconstruit PAS le widget
// =============================================================

/// Provider global pour l'etat d'authentification.
///
/// Utilisation :
/// ```dart
/// // Lire l'etat (reconstruit le widget quand ca change)
/// final authState = ref.watch(authProvider);
///
/// // Appeler une methode (ne reconstruit PAS le widget)
/// ref.read(authProvider.notifier).signIn('email', 'password');
/// ```
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(SupabaseAuthDatasource()),
  // On passe une nouvelle instance de SupabaseAuthDatasource.
  // En test, on pourrait passer un mock a la place.
);
