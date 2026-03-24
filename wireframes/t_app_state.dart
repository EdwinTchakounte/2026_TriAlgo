// =============================================================
// FICHIER : lib/presentation/wireframes/t_app_state.dart
// ROLE   : Etat global du wireframe (langue uniquement)
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';

/// Etat global : gestion de la langue FR/EN.
class AppState extends ChangeNotifier {
  AppLanguage _language = AppLanguage.fr;
  AppLanguage get language => _language;

  void setLanguage(AppLanguage lang) {
    if (_language != lang) {
      _language = lang;
      notifyListeners();
    }
  }
}

/// Instance globale (sera un Riverpod Provider dans la version finale).
final appState = AppState();
