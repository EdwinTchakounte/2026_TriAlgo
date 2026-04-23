// =============================================================
// FICHIER : lib/presentation/wireframes/t_wireframe_app.dart
// ROLE   : Point d'entree wireframe avec i18n FR/EN
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_app_state.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_splash_page.dart';

/// Point d'entree wireframe avec gestion langue FR/EN.
class TWireframeApp extends StatelessWidget {
  const TWireframeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return TLocale(
          language: appState.language,
          child: MaterialApp(
            title: 'TRIALGO',
            debugShowCheckedModeBanner: false,
            theme: TTheme.themeData,
            home: const TSplashPage(),
          ),
        );
      },
    );
  }
}
