// =============================================================
// FICHIER : lib/data/datasources/supabase_auth_datasource.dart
// ROLE   : Centraliser tous les appels d'authentification Supabase
// COUCHE : Data > Datasources
// =============================================================
//
// QU'EST-CE QU'UNE DATASOURCE ?
// -----------------------------
// Une datasource est la couche la plus BASSE de la couche Data.
// C'est elle qui fait les appels BRUTS a l'API externe (Supabase).
//
// Organisation :
//   Repository -> Datasource -> Supabase (reseau)
//
// Pourquoi cette couche supplementaire ?
//   - Isole les appels API dans UN fichier par service
//   - Facilite les tests (on mocke la datasource, pas Supabase)
//   - Si l'API Supabase change, on ne modifie que la datasource
//
// Dans TRIALGO, ce fichier gere :
//   - Inscription (signUp)
//   - Connexion email (signIn)
//   - Connexion Google (signInWithOAuth)
//   - Deconnexion (signOut)
//   - Lecture du profil (getProfile)
//   - Creation du profil (createProfile)
//   - Mise a jour du profil (updateProfile)
//
// REFERENCE : Recueil de conception v3.0, sections 10 et 13.1-13.3
// =============================================================

// Import du SDK Supabase pour les types GoTrueException, AuthResponse, etc.
import 'package:supabase_flutter/supabase_flutter.dart';

// Import du client Supabase global.
import 'package:trialgo/core/network/supabase_client.dart';

// Import des erreurs structurees pour les cas d'echec.
import 'package:trialgo/core/error/failures.dart';

/// Datasource pour l'authentification et le profil utilisateur.
///
/// Fait les appels directs a Supabase Auth et a la table `user_profiles`.
/// Transforme les erreurs Supabase en [Failure] structures.
class SupabaseAuthDatasource {

  // =============================================================
  // METHODE : signUp
  // =============================================================
  // Cree un nouveau compte avec email + mot de passe.
  //
  // Supabase Auth :
  //   1. Cree un utilisateur dans auth.users
  //   2. Envoie un email de verification
  //   3. Retourne l'utilisateur (mais PAS de session encore)
  //   4. La session est creee quand l'email est verifie
  //
  // API : POST /auth/v1/signup
  // =============================================================

  /// Inscrit un nouvel utilisateur avec email et mot de passe.
  ///
  /// [email]    : adresse email du joueur.
  /// [password] : mot de passe (minimum 8 caracteres).
  ///
  /// Retourne un [AuthResponse] contenant l'utilisateur cree.
  /// La session est `null` tant que l'email n'est pas verifie.
  ///
  /// Leve une [AuthFailure] si l'email est deja utilise ou le mdp trop faible.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    // "try/catch" : gere les erreurs de l'API Supabase.
    // Supabase leve une "AuthException" en cas d'echec.
    try {
      // "supabase.auth" : acces au module d'authentification.
      // ".signUp()" : cree un nouveau compte.
      //
      // Parametres :
      //   email: l'adresse email
      //   password: le mot de passe
      //
      // Retour : AuthResponse
      //   .user    -> l'objet User cree (id, email, created_at)
      //   .session -> null (en attente de verification email)
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      // Retourne la reponse complete au repository/provider
      // qui decidera quoi faire (afficher "verifiez votre email").
      return response;

    } on AuthException catch (e) {
      // "on AuthException catch (e)" :
      //   - "on AuthException" : n'attrape QUE les AuthException
      //     (pas les autres types d'exceptions)
      //   - "catch (e)" : capture l'exception dans la variable "e"
      //
      // "e.message" : message d'erreur retourne par Supabase.
      // On le compare pour retourner l'erreur appropriee.

      // "contains()" : verifie si la chaine contient le texte.
      if (e.message.contains('already registered')) {
        // L'email est deja associe a un compte existant.
        throw AuthFailure.emailAlreadyUsed();
      }
      if (e.message.contains('weak_password') ||
          e.message.contains('at least')) {
        // Le mot de passe est trop court (< 6 car. cote Supabase).
        throw AuthFailure.weakPassword();
      }

      // Erreur non reconnue : on la relance comme erreur serveur generique.
      throw ServerFailure(message: e.message, code: 'auth_signup_error');
    }
  }

  // =============================================================
  // METHODE : signIn
  // =============================================================
  // Connecte un utilisateur existant avec email + mot de passe.
  //
  // API : POST /auth/v1/token?grant_type=password
  //
  // Retourne un JWT (access_token) valide 1 heure et un
  // refresh_token valide 7 jours.
  // =============================================================

  /// Connecte un utilisateur avec email et mot de passe.
  ///
  /// Retourne un [AuthResponse] avec la session active (JWT).
  /// Leve une [AuthFailure] si les identifiants sont incorrects.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        throw AuthFailure.invalidCredentials();
      }
      if (e.message.contains('Email not confirmed')) {
        throw AuthFailure.emailNotConfirmed();
      }
      throw ServerFailure(message: e.message, code: 'auth_signin_error');
    }
  }

  // =============================================================
  // METHODE : signInWithGoogle
  // =============================================================
  // Lance le flux OAuth Google via le navigateur systeme.
  //
  // Le SDK gere automatiquement :
  //   1. Ouvre le navigateur sur la page de consentement Google
  //   2. L'utilisateur accepte
  //   3. Google redirige vers l'app via un Deep Link
  //   4. Le SDK capture le token et cree la session Supabase
  //
  // Pas de AuthResponse retourne directement : la session est
  // creee automatiquement via le callback onAuthStateChange.
  // =============================================================

  /// Lance la connexion Google OAuth.
  ///
  /// Le navigateur systeme s'ouvre. Apres connexion, l'utilisateur
  /// est redirige vers l'app et la session est creee automatiquement.
  Future<void> signInWithGoogle() async {
    // "signInWithOAuth" : lance le flux OAuth.
    //
    // "OAuthProvider.google" : enum indiquant le fournisseur OAuth.
    //   Supabase supporte aussi apple, github, facebook, etc.
    //
    // "redirectTo" : URL de redirection apres connexion Google.
    //   C'est un Deep Link que l'app Flutter capture.
    //   Le schema "io.supabase.trialgo" est configure dans :
    //     - Android : AndroidManifest.xml
    //     - iOS : Info.plist
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.trialgo://callback',
    );
  }

  // =============================================================
  // METHODE : signOut
  // =============================================================
  // Deconnecte l'utilisateur : supprime le JWT local.
  //
  // API : POST /auth/v1/logout
  // =============================================================

  /// Deconnecte l'utilisateur actuel.
  ///
  /// Supprime la session locale (JWT + refresh token).
  /// L'utilisateur devra se reconnecter.
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // =============================================================
  // METHODE : getProfile
  // =============================================================
  // Lit le profil de l'utilisateur depuis user_profiles.
  //
  // SQL : SELECT * FROM user_profiles WHERE id = $userId LIMIT 1
  // =============================================================

  /// Recupere le profil d'un utilisateur.
  ///
  /// [userId] : UUID de l'utilisateur (= auth.uid()).
  ///
  /// Retourne le Map JSON du profil, ou `null` si aucun profil n'existe.
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    // ".maybeSingle()" : retourne 1 resultat ou null.
    //   Contrairement a ".single()" qui leve une erreur si 0 resultats,
    //   ".maybeSingle()" retourne simplement null.
    //   C'est utile car un nouvel utilisateur peut ne pas avoir
    //   de profil encore (il est cree juste apres).
    final data = await supabase
        .from('user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return data; // Map<String, dynamic> ou null
  }

  // =============================================================
  // METHODE : createProfile
  // =============================================================
  // Cree un profil par defaut pour un nouvel utilisateur.
  // Appele automatiquement apres la premiere connexion.
  //
  // SQL : INSERT INTO user_profiles (id, username, total_score, current_level, lives)
  //       VALUES ($userId, $username, 0, 1, 5)
  // =============================================================

  /// Cree un profil utilisateur avec les valeurs par defaut.
  ///
  /// [userId]   : UUID de l'utilisateur (auth.uid()).
  /// [username] : pseudo genere par defaut (ex: "Joueur_a1b2").
  Future<Map<String, dynamic>> createProfile({
    required String userId,
    required String username,
  }) async {
    final profile = await supabase
        .from('user_profiles')
        .insert({
          'id': userId,            // Meme ID que auth.users
          'username': username,    // Pseudo par defaut
          'total_score': 0,        // Score initial
          'current_level': 1,      // Niveau 1
          'lives': 5,              // 5 vies au depart
        })
        .select()
        .single();

    return profile;
  }

  // =============================================================
  // METHODE : updateProfile
  // =============================================================
  // Met a jour le profil apres un niveau reussi.
  //
  // SQL : UPDATE user_profiles
  //       SET current_level = $level, total_score = $score
  //       WHERE id = $userId
  // =============================================================

  /// Met a jour le profil d'un utilisateur.
  ///
  /// [userId]  : UUID de l'utilisateur.
  /// [updates] : colonnes a modifier (ex: {'current_level': 8, 'total_score': 5700}).
  Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    await supabase
        .from('user_profiles')
        .update(updates)
        .eq('id', userId);
  }

  // =============================================================
  // GETTERS UTILITAIRES
  // =============================================================
  // Raccourcis pour acceder aux infos de session courante
  // sans passer par le provider Riverpod.
  // =============================================================

  /// L'utilisateur actuellement connecte, ou `null` si deconnecte.
  ///
  /// "supabase.auth.currentUser" : propriete du SDK qui retourne
  /// l'objet User stocke localement (pas d'appel reseau).
  User? get currentUser => supabase.auth.currentUser;

  /// La session actuelle, ou `null` si aucune session active.
  ///
  /// Contient le JWT (accessToken) et le refreshToken.
  Session? get currentSession => supabase.auth.currentSession;

  /// Le stream des changements d'etat d'authentification.
  ///
  /// "Stream" : flux de donnees en temps reel.
  /// Chaque fois que l'etat d'authentification change
  /// (connexion, deconnexion, refresh token), un nouvel
  /// evenement est emis dans ce stream.
  ///
  /// Utilise par le AuthProvider pour reagir aux changements.
  Stream<AuthState> get onAuthStateChange =>
      supabase.auth.onAuthStateChange;
}
