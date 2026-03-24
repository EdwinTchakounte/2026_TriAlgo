// =============================================================
// FICHIER : lib/presentation/wireframes/t_legal_page.dart
// ROLE   : Mentions legales et conditions d'utilisation
// COUCHE : Presentation > Wireframes
// =============================================================

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Page des mentions legales et conditions d'utilisation.
class TLegalPage extends StatelessWidget {
  const TLegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white54, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(tr('legal.title'), style: TTheme.titleStyle(size: 20)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('Conditions d\'utilisation'),
                      _body(
                        'TRIALGO est un jeu educatif base sur les transformations visuelles. '
                        'En utilisant cette application, vous acceptez les presentes conditions.\n\n'
                        'Le jeu est destine a un usage personnel et non commercial. '
                        'Chaque code d\'activation est lie a un seul appareil.',
                      ),

                      const SizedBox(height: 24),
                      _section('Propriete intellectuelle'),
                      _body(
                        'Toutes les images, illustrations et concepts du jeu TRIALGO '
                        'sont proteges par le droit d\'auteur.\n\n'
                        'Les mascottes, les cartes (emettrices, cables, receptrices) '
                        'et le design de l\'application sont la propriete exclusive '
                        'de l\'equipe TRIALGO.',
                      ),

                      const SizedBox(height: 24),
                      _section('Donnees personnelles'),
                      _body(
                        'Nous collectons uniquement les donnees necessaires au fonctionnement '
                        'du jeu : email, pseudo, scores, progression.\n\n'
                        'Vos donnees sont stockees de maniere securisee sur Supabase '
                        'et ne sont jamais partagees avec des tiers.\n\n'
                        'Vous pouvez demander la suppression de votre compte '
                        'et de vos donnees a tout moment.',
                      ),

                      const SizedBox(height: 24),
                      _section('Contact'),
                      _body(
                        'Pour toute question relative aux conditions d\'utilisation '
                        'ou a vos donnees personnelles :\n\n'
                        'Email : contact@trialgo.com\n'
                        'Site web : www.trialgo.com',
                      ),

                      const SizedBox(height: 24),

                      // Logo signature.
                      Center(
                        child: Column(
                          children: [
                            Image.asset(MockData.logo, width: 60, height: 60, fit: BoxFit.contain),
                            const SizedBox(height: 8),
                            Text(
                              'Version 1.0.0  ·  Mars 2026',
                              style: TTheme.bodyStyle(size: 12, color: Colors.white.withValues(alpha: 0.25)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: TTheme.subtitleStyle(size: 17)),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: TTheme.bodyStyle(size: 13, color: Colors.white.withValues(alpha: 0.5)),
    );
  }
}
