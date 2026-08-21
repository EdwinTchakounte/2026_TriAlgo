// =============================================================
// FICHIER : auth_provider.dart
// ROLE    : Etat d'authentification + flag admin
// =============================================================
//
// Trois etats possibles dans l'app :
//
//   1. Anonyme (pas connecte)         => LoginPage
//   2. Connecte mais NON admin        => message d'erreur + signOut
//   3. Connecte ET admin              => HomePage (dashboard)
//
// On modelise ca avec une enum AuthStatus + un Notifier qui
// expose la transition.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories_provider.dart';

enum AuthStatus {
  // Au demarrage, on attend que Supabase restaure la session.
  loading,
  // Aucun user connecte.
  signedOut,
  // User connecte mais is_admin = false : refuse l'acces.
  notAdmin,
  // User connecte ET admin : peut utiliser le dashboard.
  admin,
}

class AuthState {
  final AuthStatus status;
  final String? errorMessage; // pour afficher dans LoginPage

  const AuthState({required this.status, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  // build() est appele par Riverpod a la creation. On y fait la
  // detection initiale : Supabase a-t-il deja une session
  // restauree depuis le stockage local ?
  @override
  AuthState build() {
    // Au premier frame, on bootstrap : on lance la verif sans
    // bloquer le build (Future...then).
    Future.microtask(_bootstrap);
    return const AuthState(status: AuthStatus.loading);
  }

  // =========================================================
  // _bootstrap : check la session existante au demarrage
  // =========================================================
  // Cas 1 : pas de session en cache => signedOut
  // Cas 2 : session valide + admin    => admin
  // Cas 3 : session valide + NOT admin => notAdmin (signOut)
  // =========================================================
  Future<void> _bootstrap() async {
    final auth = ref.read(authRepositoryProvider);

    if (auth.currentUser == null) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }

    try {
      final isAdmin = await auth.fetchIsAdmin();
      if (isAdmin) {
        state = const AuthState(status: AuthStatus.admin);
      } else {
        // Session valide mais pas admin : on deconnecte pour
        // eviter qu'un user "normal" reste coince sur l'app
        // dashboard.
        await auth.signOut();
        state = const AuthState(
          status: AuthStatus.notAdmin,
          errorMessage: "Ce compte n'a pas les droits administrateur.",
        );
      }
    } catch (e) {
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: 'Verification du profil echouee : $e',
      );
    }
  }

  // =========================================================
  // signIn : connexion + verif is_admin
  // =========================================================
  Future<void> signIn(String email, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    final auth = ref.read(authRepositoryProvider);

    try {
      await auth.signIn(email, password);
      final isAdmin = await auth.fetchIsAdmin();

      if (isAdmin) {
        state = const AuthState(status: AuthStatus.admin);
      } else {
        // Pas admin : on deconnecte pour ne pas garder une
        // session orpheline.
        await auth.signOut();
        state = const AuthState(
          status: AuthStatus.notAdmin,
          errorMessage:
              "Ce compte n'est pas administrateur. Demandez la promotion is_admin = TRUE.",
        );
      }
    } on AuthException catch (e) {
      // Erreur typique : "Invalid login credentials"
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: e.message,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: 'Erreur inattendue : $e',
      );
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

// Provider expose au reste de l'app. Pas de .autoDispose : on
// veut que l'etat persiste tant que l'app vit.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
