// =============================================================
// FICHIER : auth_provider.dart
// ROLE    : NotifierProvider qui maintient l'etat d'auth
// =============================================================
//
// Etats possibles (AuthStatus) :
//   loading    : splash, on attend la verif initiale
//   signedOut  : pas de session, on montre LoginPage
//   notAdmin   : connecte mais pas admin, on bloque + message
//   admin      : pret a utiliser l'app
//
// AuthState = status + profile + errorMessage (UI lit ces 3).
//
// Flow :
//   1. build() declenche _bootstrap() : tente de recuperer un
//      profil existant (session persistee).
//   2. signIn() : delegue au repo, met a jour le state.
//   3. signOut() : delegue + retour a signedOut.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/user_profile.dart';
import 'repositories_provider.dart';

enum AuthStatus { loading, signedOut, notAdmin, admin }

class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  // Message a afficher dans LoginPage si echec/notAdmin.
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.profile,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    String? errorMessage,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Le bootstrap se fait en arriere-plan ; on demarre en loading.
    _bootstrap();
    return const AuthState(status: AuthStatus.loading);
  }

  // -----------------------------------------------------------
  // _bootstrap : appele une fois au boot par build().
  // Tente de reprendre la session persistee par Supabase.
  // -----------------------------------------------------------
  Future<void> _bootstrap() async {
    final repo = ref.read(authRepositoryProvider);
    final res = await repo.fetchCurrentProfile();

    switch (res) {
      case Ok(value: final profile):
        if (profile == null) {
          state = const AuthState(status: AuthStatus.signedOut);
        } else if (!profile.isAdmin) {
          // Session existe mais pas admin : kick out.
          await repo.signOut();
          state = const AuthState(
            status: AuthStatus.notAdmin,
            errorMessage: 'Ce compte n\'a pas les droits administrateur.',
          );
        } else {
          state = AuthState(
            status: AuthStatus.admin,
            profile: profile,
          );
        }
      case Err(failure: final f):
        // Erreur reseau ou autre : on retombe sur signedOut
        // pour que l'utilisateur puisse re-tenter.
        state = AuthState(
          status: AuthStatus.signedOut,
          errorMessage: f.message,
        );
    }
  }

  // -----------------------------------------------------------
  // signIn : tente la connexion. Met l'etat en loading pendant
  // l'appel pour bloquer un double-tap sur "Se connecter".
  // -----------------------------------------------------------
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    final repo = ref.read(authRepositoryProvider);
    final res = await repo.signIn(email: email, password: password);

    switch (res) {
      case Ok(value: final profile):
        state = AuthState(status: AuthStatus.admin, profile: profile);
      case Err(failure: final f):
        // Si NotAdminFailure -> on tag notAdmin ; sinon signedOut.
        state = AuthState(
          status: f is NotAdminFailure
              ? AuthStatus.notAdmin
              : AuthStatus.signedOut,
          errorMessage: f.message,
        );
    }
  }

  // -----------------------------------------------------------
  // signOut : on remet a zero. Les autres providers (cards,
  // nodes) vont s'auto-invalider quand on reviendra a login.
  // -----------------------------------------------------------
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  // Pour effacer le message d'erreur apres affichage.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
