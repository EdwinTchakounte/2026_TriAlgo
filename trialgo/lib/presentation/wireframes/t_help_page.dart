// =============================================================
// FICHIER : lib/presentation/wireframes/t_help_page.dart
// ROLE   : FAQ et aide
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE :
// ---------
//   - PageScaffold + design system
//   - Hero avec icone + titre + sous-titre conversationnel
//   - Sections Q&A en accordeons (AppCard glass avec ExpansionTile)
//   - Section "contact" a la fin avec CTA "Ouvrir le tutoriel"
//   - FAQ localisee : q1..q8 / a1..a8 dans t_locale.dart.
//     Mapping fixe : 3 questions jeu + 3 compte + 2 physique = 8 FAQs.
// =============================================================

import 'package:flutter/material.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/core/section_header.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_tutorial_page.dart';


class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}


class THelpPage extends StatelessWidget {
  const THelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);

    // FAQs localisees : chaque bloc consomme 3 ou 2 paires q/a successives
    // deja definies dans t_locale.dart.
    final gameplay = <_Faq>[
      _Faq(tr('help.q1'), tr('help.a1')),
      _Faq(tr('help.q2'), tr('help.a2')),
      _Faq(tr('help.q3'), tr('help.a3')),
    ];
    final account = <_Faq>[
      _Faq(tr('help.q4'), tr('help.a4')),
      _Faq(tr('help.q5'), tr('help.a5')),
    ];
    final physical = <_Faq>[
      _Faq(tr('help.q6'), tr('help.a6')),
      _Faq(tr('help.q7'), tr('help.a7')),
      _Faq(tr('help.q8'), tr('help.a8')),
    ];

    return PageScaffold(
      title: tr('help.title_refonte'),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: TSpacing.xxl,
          vertical: TSpacing.lg,
        ),
        children: [
          // --- Hero ---
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  0x33,
                  TColors.primary.r.round(),
                  TColors.primary.g.round(),
                  TColors.primary.b.round(),
                ),
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                size: 40,
                color: TColors.primary,
              ),
            ),
          ),
          const SizedBox(height: TSpacing.lg),
          Text(
            tr('help.hero_title'),
            textAlign: TextAlign.center,
            style: TTypography.headlineLg(color: colors.textPrimary),
          ),
          const SizedBox(height: TSpacing.xs),
          Text(
            tr('help.hero_body'),
            textAlign: TextAlign.center,
            style: TTypography.bodyMd(color: colors.textSecondary),
          ),
          const SizedBox(height: TSpacing.xxl),

          // --- Section gameplay ---
          SectionHeader(title: tr('help.section_gameplay')),
          ...gameplay.map(_buildFaqCard),
          const SizedBox(height: TSpacing.lg),

          // --- Section compte ---
          SectionHeader(title: tr('help.section_account')),
          ...account.map(_buildFaqCard),
          const SizedBox(height: TSpacing.lg),

          // --- Section jeu physique ---
          SectionHeader(title: tr('help.section_physical')),
          ...physical.map(_buildFaqCard),
          const SizedBox(height: TSpacing.xxl),

          // --- CTA : tutoriel ---
          AppButton.primary(
            label: tr('help.cta_tutorial'),
            icon: Icons.school_outlined,
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TTutorialPage()),
            ),
          ),
          const SizedBox(height: TSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildFaqCard(_Faq faq) {
    return Builder(
      builder: (context) {
        final colors = TColors.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: TSpacing.sm),
          // ExpansionTile pour un accordeon natif fluide.
          // On le pose dans un AppCard.glass pour homogeneite visuelle.
          child: Theme(
            // Retire le divider par defaut de l'ExpansionTile.
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: TRadius.lgAll,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: TSpacing.lg,
                  vertical: TSpacing.xs,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  TSpacing.lg,
                  0,
                  TSpacing.lg,
                  TSpacing.md,
                ),
                title: Text(
                  faq.question,
                  style:
                      TTypography.titleMd(color: colors.textPrimary),
                ),
                iconColor: TColors.primary,
                collapsedIconColor: colors.textSecondary,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      faq.answer,
                      style: TTypography.bodyMd(
                          color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
