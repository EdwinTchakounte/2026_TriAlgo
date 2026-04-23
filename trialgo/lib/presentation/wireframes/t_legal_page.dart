// =============================================================
// FICHIER : lib/presentation/wireframes/t_legal_page.dart
// ROLE   : Mentions legales + conditions + credits
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE :
// ---------
//   - PageScaffold + design system
//   - Tabs : Mentions / Conditions / Credits
//   - Typographie lisible (bodyLg pour paragraphes, headlineSm pour titres)
//   - Design minimaliste pour une page "obligatoire"
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


class TLegalPage extends StatelessWidget {
  const TLegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    return DefaultTabController(
      length: 3,
      child: PageScaffold(
        title: tr('legal.title_refonte'),
        child: Column(
          children: [
            // Tabs.
            _buildTabs(context),
            // Contenu.
            Expanded(
              child: TabBarView(
                children: [
                  _tabContent(context, _LegalContent.mentions),
                  _tabContent(context, _LegalContent.conditions),
                  _tabContent(context, _LegalContent.credits),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    return Container(
      color: Colors.transparent,
      child: TabBar(
        indicatorColor: TColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: colors.textPrimary,
        unselectedLabelColor: colors.textTertiary,
        labelStyle: TTypography.titleSm(),
        tabs: [
          Tab(text: tr('legal.tab_mentions')),
          Tab(text: tr('legal.tab_conditions')),
          Tab(text: tr('legal.tab_credits')),
        ],
      ),
    );
  }

  Widget _tabContent(BuildContext context, _LegalContent content) {
    final colors = TColors.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: TSpacing.xxl,
        vertical: TSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: content.sections.map((s) {
          return Padding(
            padding: const EdgeInsets.only(bottom: TSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: TTypography.headlineSm(color: colors.textPrimary),
                ),
                const SizedBox(height: TSpacing.sm),
                Text(
                  s.body,
                  style: TTypography.bodyLg(color: colors.textSecondary),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}


// =============================================================
// CONTENU STATIQUE (3 onglets)
// =============================================================
//
// Texte placeholder pour v1. A remplacer par le texte legal reel
// fourni par l'editeur (CGU, politique de confidentialite signees
// par le responsable juridique).
//
// Note : les sections sont courtes volontairement — on ne veut pas
// enterrer l'enfant sous du juridique. Langage simple, phrases courtes.
// =============================================================

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

class _LegalContent {
  final List<_Section> sections;
  const _LegalContent(this.sections);

  static const mentions = _LegalContent([
    _Section(
      "Editeur",
      "TRIALGO est edite par la societe TRIALGO. "
          "Contact : contact@trialgo.com",
    ),
    _Section(
      "Hebergement",
      "Cette application utilise les services de Supabase pour "
          "l'hebergement des donnees et Google Play Store / Apple App "
          "Store pour la distribution.",
    ),
    _Section(
      "Proprietaire du contenu",
      "Les illustrations, musiques et code source de cette "
          "application sont la propriete exclusive de TRIALGO.",
    ),
  ]);

  static const conditions = _LegalContent([
    _Section(
      "Utilisation",
      "Cette application est destinee aux enfants a partir de 6 ans, "
          "sous la supervision d'un adulte. En l'utilisant, tu acceptes "
          "les presentes conditions.",
    ),
    _Section(
      "Donnees personnelles",
      "Nous collectons uniquement les donnees necessaires au jeu : "
          "email, pseudo, progression. Aucune donnee n'est partagee "
          "avec des tiers a des fins commerciales.",
    ),
    _Section(
      "Suppression du compte",
      "Tu peux supprimer ton compte a tout moment depuis les "
          "parametres. Toutes tes donnees seront effacees dans les 30 "
          "jours suivants.",
    ),
    _Section(
      "Contact",
      "Pour toute question relative a tes donnees ou au jeu, "
          "contacte-nous a privacy@trialgo.com.",
    ),
  ]);

  static const credits = _LegalContent([
    _Section(
      "Equipe",
      "TRIALGO est une creation collective : design, developpement, "
          "game design et illustrations.",
    ),
    _Section(
      "Polices",
      "Rajdhani et Exo 2 sont distribuees sous licence Open Font "
          "License via Google Fonts.",
    ),
    _Section(
      "Remerciements",
      "Un grand merci aux enfants qui ont teste TRIALGO en avant-"
          "premiere et nous ont aides a faire des choix de design !",
    ),
  ]);
}
