// =============================================================
// FICHIER : lib/presentation/providers/question_timer_provider.dart
// ROLE   : Gerer le chronometre de tour (compte a rebours par question)
// COUCHE : Presentation > Providers
// =============================================================
//
// CE QUE FAIT CE PROVIDER :
// -------------------------
// Chaque question a un TEMPS LIMITE (30 a 55 secondes selon le niveau).
// Ce provider gere un compte a rebours qui :
//   1. Demarre quand la question est affichee
//   2. Decremente chaque seconde
//   3. Change de couleur (vert -> orange -> rouge)
//   4. Vibre quand il reste < 30% du temps
//   5. Declenche un timeout quand il atteint 0
//
// PATTERN : StateNotifier avec Timer.periodic
// -------------------------------------------
// On utilise un Timer Dart qui "tick" toutes les secondes.
// A chaque tick, on decremente le compteur et on met a jour l'etat.
// Les widgets qui ref.watch ce provider se reconstruisent
// automatiquement a chaque seconde (pour mettre a jour l'affichage).
//
// "autoDispose" : le provider est DETRUIT quand plus aucun widget
// ne l'ecoute. Le Timer est arrete automatiquement.
// C'est important pour eviter les fuites memoire (un Timer non arrete
// continue de tourner meme quand l'ecran est ferme).
//
// REFERENCE : Recueil v3.0, section 8.1
// =============================================================

import 'dart:async';
// "dart:async" fournit Timer (chronometre periodique).
// Timer.periodic(duration, callback) execute le callback
// a intervalles reguliers.

import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================
// CLASSE : QuestionTimerState
// =============================================================
// Contient l'etat du chronometre : secondes restantes,
// secondes ecoulees, et si le temps est expire.
// =============================================================

/// Etat du chronometre de question.
class QuestionTimerState {
  /// Secondes restantes avant l'expiration.
  final int remainingSeconds;

  /// Secondes ecoulees depuis le debut de la question.
  final int elapsedSeconds;

  /// Temps total autorise pour cette question (en secondes).
  final int totalSeconds;

  /// `true` si le temps est ecoule (remainingSeconds <= 0).
  final bool isExpired;

  const QuestionTimerState({
    required this.remainingSeconds,
    required this.elapsedSeconds,
    required this.totalSeconds,
    this.isExpired = false,
  });

  /// Ratio du temps ecoule (0.0 = debut, 1.0 = fin).
  ///
  /// Utilise pour :
  ///   - La barre de progression circulaire
  ///   - Le changement de couleur (vert/orange/rouge)
  ///   - Le calcul du bonus temps
  ///
  /// "totalSeconds == 0" : securite pour eviter la division par zero.
  double get progress =>
      totalSeconds == 0 ? 1.0 : elapsedSeconds / totalSeconds;

  /// Couleur du chronometre selon le temps restant.
  ///
  /// > 60% restant -> vert (tout va bien)
  /// 30-60% restant -> orange (attention)
  /// < 30% restant -> rouge (urgence)
  ///
  /// Retourne un int representant un code couleur (pas un Color Flutter
  /// car on ne veut pas importer material.dart dans le provider).
  ///   0 = vert, 1 = orange, 2 = rouge
  int get urgencyLevel {
    // Ratio du temps RESTANT (inverse de progress).
    final remainingRatio = 1.0 - progress;
    if (remainingRatio > 0.6) return 0;  // Vert : plus de 60% restant
    if (remainingRatio > 0.3) return 1;  // Orange : 30-60% restant
    return 2;                             // Rouge : moins de 30%
  }

  /// Copie avec modifications.
  QuestionTimerState copyWith({
    int? remainingSeconds,
    int? elapsedSeconds,
    int? totalSeconds,
    bool? isExpired,
  }) {
    return QuestionTimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      isExpired: isExpired ?? this.isExpired,
    );
  }
}

// =============================================================
// CLASSE : QuestionTimerNotifier
// =============================================================
// Gere le Timer Dart et met a jour l'etat chaque seconde.
// =============================================================

/// Notifier du chronometre de question.
///
/// Gere un compte a rebours par question :
/// - [start] : demarre le chrono pour N secondes
/// - [stop] : arrete le chrono (reponse donnee)
/// - [reset] : remet a zero (nouvelle question)
class QuestionTimerNotifier extends StateNotifier<QuestionTimerState> {
  // =============================================================
  // PROPRIETE : _timer
  // =============================================================
  // "Timer?" : le timer periodique Dart (ou null si pas demarre).
  //
  // "Timer.periodic(Duration, callback)" :
  //   Execute la callback a intervalles reguliers.
  //   Exemple : Timer.periodic(Duration(seconds: 1), (t) { ... })
  //   -> Execute la callback TOUTES LES SECONDES.
  //
  // "_timer?.cancel()" : arrete le timer (pas d'execution future).
  // Si _timer est null, "?." ne fait rien (pas d'erreur).
  // =============================================================

  /// Le timer periodique Dart (1 tick par seconde).
  Timer? _timer;

  /// Callback appelee quand le temps expire.
  /// Permet au GameSessionNotifier de reagir au timeout.
  final void Function()? onExpired;

  /// Constructeur. Etat initial : pas de chrono en cours.
  QuestionTimerNotifier({this.onExpired})
      : super(const QuestionTimerState(
          remainingSeconds: 0,
          elapsedSeconds: 0,
          totalSeconds: 0,
        ));

  // =============================================================
  // METHODE : start
  // =============================================================
  // Demarre un nouveau compte a rebours.
  //
  // [totalSeconds] : le temps maximum pour cette question.
  //
  // Le Timer tick toutes les secondes et decremente le compteur.
  // Quand le compteur atteint 0, il s'arrete et appelle onExpired.
  // =============================================================

  /// Demarre le chrono pour [totalSeconds] secondes.
  void start(int totalSeconds) {
    // Arreter un eventuel timer precedent.
    _timer?.cancel();

    // Initialiser l'etat.
    state = QuestionTimerState(
      remainingSeconds: totalSeconds,
      elapsedSeconds: 0,
      totalSeconds: totalSeconds,
    );

    // Creer un nouveau timer periodique.
    // "Duration(seconds: 1)" : intervalle d'1 seconde entre chaque tick.
    // "(timer)" : parametre du callback (l'objet Timer lui-meme).
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // A chaque tick (chaque seconde) :
      final newRemaining = state.remainingSeconds - 1;
      final newElapsed = state.elapsedSeconds + 1;

      if (newRemaining <= 0) {
        // --- Temps ecoule ---
        // Arreter le timer.
        timer.cancel();

        // Mettre a jour l'etat avec isExpired = true.
        state = state.copyWith(
          remainingSeconds: 0,
          elapsedSeconds: newElapsed,
          isExpired: true,
        );

        // Notifier le GameSessionNotifier que le temps est expire.
        // "onExpired?.call()" : appelle la callback SI elle n'est pas null.
        onExpired?.call();
      } else {
        // --- Temps restant ---
        state = state.copyWith(
          remainingSeconds: newRemaining,
          elapsedSeconds: newElapsed,
        );
      }
    });
  }

  /// Arrete le chrono (le joueur a repondu).
  void stop() {
    _timer?.cancel();
  }

  /// Remet le chrono a zero (entre deux questions).
  void reset() {
    _timer?.cancel();
    state = const QuestionTimerState(
      remainingSeconds: 0,
      elapsedSeconds: 0,
      totalSeconds: 0,
    );
  }

  // =============================================================
  // DISPOSE
  // =============================================================
  // Appele automatiquement par Riverpod quand le provider
  // est detruit (grace a autoDispose).
  // DOIT arreter le timer pour eviter les fuites memoire.
  // =============================================================

  @override
  void dispose() {
    _timer?.cancel();   // Arreter le timer avant destruction.
    super.dispose();    // Appeler le dispose parent.
  }
}

// =============================================================
// PROVIDER : questionTimerProvider
// =============================================================
// ".autoDispose" : le provider est detruit quand plus aucun
// widget ne l'ecoute (ecran de jeu ferme -> timer arrete).
// =============================================================

/// Provider du chronometre de question (auto-dispose).
final questionTimerProvider =
    StateNotifierProvider.autoDispose<QuestionTimerNotifier, QuestionTimerState>(
  (ref) => QuestionTimerNotifier(),
);
