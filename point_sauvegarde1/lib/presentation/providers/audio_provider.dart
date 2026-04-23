// =============================================================
// FICHIER : lib/presentation/providers/audio_provider.dart
// ROLE   : Provider Riverpod pour le service audio
// COUCHE : Presentation > Providers
// =============================================================
//
// Le AudioService est un singleton, donc le provider est de type
// Provider (pas StateNotifierProvider). L'audio n'a pas d'etat
// reactif a observer dans l'UI (les sons sont declenches via
// ref.read et non ref.watch).
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/data/services/audio_service.dart';

/// Fournit l'instance unique de [AudioService].
///
/// Le service est cree une seule fois et partage par toute l'app.
/// Pour declencher un son depuis un widget :
/// ```dart
/// ref.read(audioServiceProvider).playSfx(SoundEffect.correct);
/// ```
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  // Initialiser asynchroniquement (charge les preferences).
  // L'init n'a pas besoin d'etre attendu, les premieres lectures
  // utiliseront simplement les valeurs par defaut.
  service.init();
  return service;
});
