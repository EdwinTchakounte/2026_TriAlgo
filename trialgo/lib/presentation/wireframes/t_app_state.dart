// =============================================================
// FICHIER : lib/presentation/wireframes/t_app_state.dart
// ROLE   : Etat global du wireframe (langue + theme)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// CE QUE GERE CE FICHIER :
// ------------------------
//   1. Langue de l'interface (FR / EN)
//   2. Mode de theme (light / dark / system)
//
// Les deux preferences sont persistees dans SharedPreferences
// pour survivre a une fermeture d'app.
// =============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trialgo/presentation/wireframes/t_locale.dart';


/// Etat global : gestion de la langue FR/EN + theme light/dark/system.
///
/// Utilise le pattern ChangeNotifier (simple, sans dependances),
/// consomme via ListenableBuilder dans TWireframeApp.
class AppState extends ChangeNotifier {

  // ---------------------------------------------------------------
  // CLES SharedPreferences
  // ---------------------------------------------------------------
  // Des cles prefixees "pref." pour eviter les collisions avec
  // d'autres prefs (ex: "onboarding_seen_<user_id>").
  // ---------------------------------------------------------------

  static const String _keyLanguage = 'pref.language';
  static const String _keyThemeMode = 'pref.theme_mode';

  // ---------------------------------------------------------------
  // LANGUE
  // ---------------------------------------------------------------

  AppLanguage _language = AppLanguage.fr;

  /// Langue active de l'interface.
  AppLanguage get language => _language;

  /// Change la langue, notifie les listeners et persiste la preference.
  Future<void> setLanguage(AppLanguage lang) async {
    if (_language != lang) {
      _language = lang;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLanguage, lang.name);
    }
  }

  // ---------------------------------------------------------------
  // THEME MODE
  // ---------------------------------------------------------------

  ThemeMode _themeMode = ThemeMode.system;

  /// Mode de theme courant (light, dark, ou system).
  ThemeMode get themeMode => _themeMode;

  /// Change le mode de theme, notifie les listeners et persiste.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeMode, mode.name);
    }
  }

  // ---------------------------------------------------------------
  // INITIALISATION
  // ---------------------------------------------------------------
  // Appele depuis main_wireframe.dart au demarrage pour restaurer
  // les preferences utilisateur avant le premier build.
  //
  // Silencieuse en cas d'erreur de parsing (ex: cle absente ou
  // enum renomme) : on garde les valeurs par defaut.
  // ---------------------------------------------------------------

  /// Restaure les preferences depuis SharedPreferences.
  /// A appeler UNE fois au demarrage, avant runApp.
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // --- Langue ---
    final langName = prefs.getString(_keyLanguage);
    if (langName != null) {
      _language = AppLanguage.values.firstWhere(
        (l) => l.name == langName,
        orElse: () => AppLanguage.fr,
      );
    }

    // --- Theme mode ---
    final modeName = prefs.getString(_keyThemeMode);
    if (modeName != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => ThemeMode.system,
      );
    }

    // On n'appelle pas notifyListeners() ici : l'app n'est pas
    // encore buildee. Le premier build lira les valeurs restauree.
  }
}

/// Instance globale. Pourra migrer vers un Riverpod Provider plus tard.
final appState = AppState();
