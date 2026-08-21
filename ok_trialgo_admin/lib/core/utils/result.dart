// =============================================================
// FICHIER : result.dart
// ROLE    : Type sum "Result<T>" pour les retours de repository
// =============================================================
//
// Au lieu de :
//
//   Future<Game> createGame(...)        -> peut throw Failure ou Exception
//
// On expose :
//
//   Future<Result<Game>> createGame(...) -> renvoie Ok(game) ou Err(failure)
//
// Avantages :
//   1. La signature dit explicitement "ca peut echouer".
//   2. On force l'appelant a gerer les deux branches via pattern
//      matching (switch sur sealed class).
//   3. On peut chainer / mapper sans try/catch.
//
// Les exceptions inattendues (technique) restent levees ; Result
// modelise seulement les erreurs METIER (Failure).
// =============================================================

import '../errors/failures.dart';

sealed class Result<T> {
  const Result();

  // Helper : renvoie la valeur ou null si erreur. Pratique quand
  // l'UI veut juste afficher la valeur en cas de succes.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  // Helper inverse : renvoie le Failure ou null si succes.
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  // Test booleen rapide.
  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
}
