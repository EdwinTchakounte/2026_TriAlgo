// =============================================================
// FICHIER : codes_provider.dart
// ROLE    : Etat de la console des codes d'activation
// =============================================================
//
// Deux providers :
//
//   codesFilterProvider : StateProvider<String?>
//     -> UUID du jeu sur lequel filtrer, ou null pour "tous".
//
//   codesProvider : AsyncNotifier<EtatDesCodes>
//     -> la page courante, le total, et les actions d'ecriture.
//
// POURQUOI UN ETAT DEDIE PLUTOT QU'UNE SIMPLE List<ActivationCode>
// ----------------------------------------------------------------
// L'ecran a besoin de trois choses que la liste seule ne porte
// pas : combien de codes existent au total, s'il reste une page a
// charger, et si un chargement supplementaire est en cours. Les
// deduire depuis l'UI donnerait un compteur faux des qu'un code
// est cree ou supprime.
//
// LE FILTRE DECLENCHE UN RECHARGEMENT
// -----------------------------------
// codesProvider surveille codesFilterProvider. Changer de jeu
// dans le selecteur relance donc automatiquement la requete, sans
// que l'ecran ait a orchestrer quoi que ce soit.
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/entities/activation_code.dart';
import 'repositories_provider.dart';

/// Nombre de codes charges par page.
const int kTailleDePageDesCodes = 50;

/// Etat complet de la console des codes.
class EtatDesCodes {
  /// Les codes charges jusqu'ici (page courante + pages precedentes).
  final List<ActivationCode> codes;

  /// Nombre total de codes correspondant au filtre courant.
  final int total;

  /// True s'il reste des codes a charger.
  final bool aUneSuite;

  /// True pendant le chargement d'une page supplementaire.
  ///
  /// Distinct de l'etat AsyncLoading global : on veut garder la
  /// liste deja affichee et n'afficher qu'un indicateur en bas,
  /// pas remplacer tout l'ecran par un rond qui tourne.
  final bool chargeLaSuite;

  const EtatDesCodes({
    required this.codes,
    required this.total,
    required this.aUneSuite,
    this.chargeLaSuite = false,
  });

  EtatDesCodes copyWith({
    List<ActivationCode>? codes,
    int? total,
    bool? aUneSuite,
    bool? chargeLaSuite,
  }) {
    return EtatDesCodes(
      codes: codes ?? this.codes,
      total: total ?? this.total,
      aUneSuite: aUneSuite ?? this.aUneSuite,
      chargeLaSuite: chargeLaSuite ?? this.chargeLaSuite,
    );
  }
}

/// UUID du jeu sur lequel filtrer, null = tous les jeux.
final codesFilterProvider = StateProvider<String?>((ref) => null);

class CodesNotifier extends AsyncNotifier<EtatDesCodes> {
  @override
  Future<EtatDesCodes> build() async {
    // watch et non read : changer de filtre relance ce build.
    final gameId = ref.watch(codesFilterProvider);
    return _chargerPremierePage(gameId);
  }

  Future<EtatDesCodes> _chargerPremierePage(String? gameId) async {
    final repo = ref.read(codesRepositoryProvider);
    final res = await repo.listAll(
      gameId: gameId,
      limit: kTailleDePageDesCodes,
      offset: 0,
    );

    return switch (res) {
      Ok(value: final page) => EtatDesCodes(
          codes: page.items,
          total: page.total,
          aUneSuite: page.aUneSuite,
        ),
      // On leve pour que AsyncNotifier bascule en etat d'erreur :
      // l'ecran affiche alors le message et un bouton Reessayer.
      Err(failure: final f) => throw Exception(f.message),
    };
  }

  // -----------------------------------------------------------
  // LECTURE
  // -----------------------------------------------------------

  /// Recharge depuis la premiere page.
  Future<void> refresh() async {
    final gameId = ref.read(codesFilterProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _chargerPremierePage(gameId));
  }

  /// Charge la page suivante et l'ajoute a la liste courante.
  Future<void> chargerLaSuite() async {
    final courant = state.valueOrNull;
    // Rien a charger, ou un chargement deja en cours : on sort.
    if (courant == null || !courant.aUneSuite || courant.chargeLaSuite) {
      return;
    }

    state = AsyncData(courant.copyWith(chargeLaSuite: true));

    final repo = ref.read(codesRepositoryProvider);
    final res = await repo.listAll(
      gameId: ref.read(codesFilterProvider),
      limit: kTailleDePageDesCodes,
      offset: courant.codes.length,
    );

    switch (res) {
      case Ok(value: final page):
        state = AsyncData(EtatDesCodes(
          codes: [...courant.codes, ...page.items],
          total: page.total,
          aUneSuite: page.aUneSuite,
        ));
      case Err():
        // Echec du "charger la suite" : on retire simplement
        // l'indicateur. Remplacer tout l'ecran par une erreur
        // ferait perdre les codes deja affiches, ce qui serait une
        // regression pour un incident mineur.
        state = AsyncData(courant.copyWith(chargeLaSuite: false));
    }
  }

  // -----------------------------------------------------------
  // ECRITURE
  // -----------------------------------------------------------
  // Toutes renvoient le message d'erreur du serveur, ou null en
  // cas de succes. L'ecran n'a qu'a tester la nullite pour decider
  // s'il affiche une bandeau rouge.
  //
  // On recharge apres chaque ecriture plutot que de bricoler la
  // liste en local : les codes changent d'etat par effet de bord
  // (un joueur peut activer un code pendant qu'on regarde), et une
  // liste reconstruite depuis le serveur ne ment jamais.
  // -----------------------------------------------------------

  /// Cree un code. Retourne null si tout s'est bien passe.
  Future<String?> creer({
    required String code,
    required String gameId,
    required int maxDeviceChanges,
  }) async {
    final repo = ref.read(codesRepositoryProvider);
    final res = await repo.create(
      code: code,
      gameId: gameId,
      maxDeviceChanges: maxDeviceChanges,
    );

    switch (res) {
      case Ok():
        await refresh();
        return null;
      case Err(failure: final f):
        return f.message;
    }
  }

  /// Active ou desactive un code. Retourne null si succes.
  Future<String?> basculerActivation({
    required String code,
    required bool versActif,
  }) async {
    final repo = ref.read(codesRepositoryProvider);
    final res = await repo.setActive(code: code, isActive: versActif);

    switch (res) {
      case Ok():
        await refresh();
        return null;
      case Err(failure: final f):
        return f.message;
    }
  }

  /// Remet un code dans l'etat "jamais active". Retourne null si succes.
  Future<String?> reinitialiser(String code) async {
    final repo = ref.read(codesRepositoryProvider);
    final res = await repo.resetAssignment(code);

    switch (res) {
      case Ok():
        await refresh();
        return null;
      case Err(failure: final f):
        return f.message;
    }
  }

  /// Supprime un code. Retourne null si succes.
  Future<String?> supprimer(String code) async {
    final repo = ref.read(codesRepositoryProvider);
    final res = await repo.delete(code);

    switch (res) {
      case Ok():
        await refresh();
        return null;
      case Err(failure: final f):
        return f.message;
    }
  }
}

final codesProvider =
    AsyncNotifierProvider<CodesNotifier, EtatDesCodes>(CodesNotifier.new);
