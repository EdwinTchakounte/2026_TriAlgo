// =============================================================
// FICHIER : users_provider.dart
// ROLE    : Etat de la console des comptes utilisateurs
// =============================================================
//
// Meme structure que codes_provider : une page chargee, un total,
// un indicateur de chargement incremental, et des actions
// d'ecriture qui renvoient le message d'erreur du serveur ou null.
//
// LA PARTICULARITE DE CET ECRAN
// -----------------------------
// L'administrateur peut se retrograder ou se suspendre lui-meme.
// Le serveur refuse les deux cas qui rendraient la console
// inaccessible (dernier administrateur actif, auto-suspension) et
// repond 400 avec une phrase explicite. On ne duplique PAS ces
// regles ici : le client n'a pas de vue fiable sur "combien
// d'administrateurs actifs restent", et deux implementations de la
// meme regle finissent toujours par diverger. On affiche donc la
// reponse du serveur telle quelle.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/entities/admin_user.dart';
import 'repositories_provider.dart';

/// Nombre de comptes charges par page. Le serveur borne a 100.
const int kTailleDePageDesComptes = 20;

/// Etat complet de la console des comptes.
class EtatDesComptes {
  /// Les comptes charges jusqu'ici.
  final List<AdminUser> comptes;

  /// Nombre total de comptes.
  final int total;

  /// True s'il reste des comptes a charger.
  final bool aUneSuite;

  /// True pendant le chargement d'une page supplementaire.
  final bool chargeLaSuite;

  const EtatDesComptes({
    required this.comptes,
    required this.total,
    required this.aUneSuite,
    this.chargeLaSuite = false,
  });

  EtatDesComptes copyWith({
    List<AdminUser>? comptes,
    int? total,
    bool? aUneSuite,
    bool? chargeLaSuite,
  }) {
    return EtatDesComptes(
      comptes: comptes ?? this.comptes,
      total: total ?? this.total,
      aUneSuite: aUneSuite ?? this.aUneSuite,
      chargeLaSuite: chargeLaSuite ?? this.chargeLaSuite,
    );
  }
}

class UsersNotifier extends AsyncNotifier<EtatDesComptes> {
  @override
  Future<EtatDesComptes> build() async => _chargerPremierePage();

  Future<EtatDesComptes> _chargerPremierePage() async {
    final repo = ref.read(adminUsersRepositoryProvider);
    final res = await repo.listAll(
      limit: kTailleDePageDesComptes,
      offset: 0,
    );

    return switch (res) {
      Ok(value: final page) => EtatDesComptes(
          comptes: page.items,
          total: page.total,
          aUneSuite: page.aUneSuite,
        ),
      Err(failure: final f) => throw Exception(f.message),
    };
  }

  /// Recharge depuis la premiere page.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_chargerPremierePage);
  }

  /// Charge la page suivante et l'ajoute a la liste courante.
  Future<void> chargerLaSuite() async {
    final courant = state.valueOrNull;
    if (courant == null || !courant.aUneSuite || courant.chargeLaSuite) {
      return;
    }

    state = AsyncData(courant.copyWith(chargeLaSuite: true));

    final repo = ref.read(adminUsersRepositoryProvider);
    final res = await repo.listAll(
      limit: kTailleDePageDesComptes,
      offset: courant.comptes.length,
    );

    switch (res) {
      case Ok(value: final page):
        state = AsyncData(EtatDesComptes(
          comptes: [...courant.comptes, ...page.items],
          total: page.total,
          aUneSuite: page.aUneSuite,
        ));
      case Err():
        state = AsyncData(courant.copyWith(chargeLaSuite: false));
    }
  }

  // -----------------------------------------------------------
  // ECRITURE
  // -----------------------------------------------------------

  /// Promeut ou retrograde un compte. Retourne null si succes.
  ///
  /// C'est une bascule cote serveur : on ne dit pas vers quel etat
  /// aller, le serveur inverse et applique ses garde-fous.
  Future<String?> basculerPromotion(String userId) async {
    final repo = ref.read(adminUsersRepositoryProvider);
    final res = await repo.togglePromotion(userId);

    switch (res) {
      case Ok():
        await refresh();
        return null;
      case Err(failure: final f):
        return f.message;
    }
  }

  /// Suspend ou reactive un compte. Retourne null si succes.
  Future<String?> basculerActivation({
    required String userId,
    required bool versActif,
  }) async {
    final repo = ref.read(adminUsersRepositoryProvider);
    final res = await repo.setActive(userId: userId, isActive: versActif);

    switch (res) {
      case Ok():
        await refresh();
        return null;
      case Err(failure: final f):
        return f.message;
    }
  }
}

final usersProvider =
    AsyncNotifierProvider<UsersNotifier, EtatDesComptes>(UsersNotifier.new);
