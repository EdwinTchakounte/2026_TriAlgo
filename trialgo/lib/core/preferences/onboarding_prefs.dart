// =============================================================
// FICHIER : lib/core/preferences/onboarding_prefs.dart
// ROLE   : Gerer le flag "onboarding vu" en SharedPreferences
// COUCHE : Core > Preferences
// =============================================================
//
// POURQUOI CE FICHIER ?
// ---------------------
// Deux endroits dans l'app lisent/ecrivent le flag onboarding_seen :
//   - t_graph_loading_page.dart : DECIDE si on affiche l'onboarding
//   - t_onboarding_page.dart    : MARQUE l'onboarding comme vu
//
// Sans cette classe, les deux fichiers duplicaient la logique :
//   - format de la cle SharedPreferences
//   - scoping par user_id
//
// Centraliser ici garantit qu'un seul fichier definit le format
// de cle. Si on decide demain de changer de strategie (ex: migrer
// vers Supabase user_profiles.onboarding_seen), un seul fichier
// a modifier.
//
// POURQUOI SCOPER PAR USER_ID ?
// -----------------------------
// Sans scoping, le flag est GLOBAL au device. Consequence :
//   - User A s'inscrit, voit l'onboarding, flag = true
//   - User A se deconnecte
//   - User B s'inscrit sur le meme telephone
//   - User B n'a JAMAIS vu l'onboarding, pourtant il est skippe (BUG)
//
// Avec scoping (cle par user_id), chaque user a son propre flag.
// =============================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:trialgo/core/network/supabase_client.dart';


/// Helper pour le flag "onboarding vu" en SharedPreferences.
///
/// Classe statique (pas d'instanciation) : methodes utilitaires.
class OnboardingPrefs {

  /// Prefixe de la cle dans SharedPreferences.
  /// La cle complete est : `onboarding_seen_<user_id>`.
  /// "private" (underscore) pour eviter qu'un autre fichier l'utilise
  /// directement — tout doit passer par isSeen() / markSeen().
  static const String _keyPrefix = 'onboarding_seen_';

  // =============================================================
  // METHODE : _keyForCurrentUser
  // =============================================================
  // Construit la cle a partir de l'UUID du user actuellement connecte.
  //
  // Si aucun user n'est connecte (cas theorique, ne devrait pas
  // arriver en pratique car l'onboarding est affiche APRES l'auth),
  // on utilise un suffixe 'anon'. Mieux qu'une crash, et le flag
  // 'anon' ne gene personne puisque personne ne se verra assigner
  // cet ID en BDD.
  // =============================================================

  /// Retourne la cle SharedPreferences scopee au user actuel.
  static String _keyForCurrentUser() {
    final userId = supabase.auth.currentUser?.id ?? 'anon';
    return '$_keyPrefix$userId';
  }

  // =============================================================
  // METHODE : isSeen
  // =============================================================
  // Lit le flag pour le user actuel.
  // Retourne false si jamais marque (premiere fois ou nouveau user).
  // =============================================================

  /// Retourne true si l'utilisateur courant a deja vu l'onboarding.
  static Future<bool> isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyForCurrentUser()) ?? false;
  }

  // =============================================================
  // METHODE : markSeen
  // =============================================================
  // Ecrit le flag a true pour le user actuel.
  // Appelee depuis t_onboarding_page._finish().
  // =============================================================

  /// Marque l'onboarding comme vu pour l'utilisateur courant.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyForCurrentUser(), true);
  }
}
