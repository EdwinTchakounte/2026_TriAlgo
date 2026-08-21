// =============================================================
// FICHIER : step1_setup_page.dart
// ROLE    : Etape 1 du wizard - intro et confirmation du jeu
// =============================================================
//
// Pourquoi une etape "intro" alors que le jeu est deja selectionne ?
// - Re-confirmer visuellement le jeu sur lequel on travaille
//   (evite de bosser sur le mauvais jeu apres une nav rapide).
// - Donner un rappel pedagogique de la logique TRIALGO
//   (E + C => R, profondeurs 1-5, trios).
// - Montrer un compteur "X cartes, Y trios" pour situer l'admin.
// - Etape de "warmup" : pas de saisie, juste comprendre.
//
// C'est ici qu'on rend l'app "bien guidee" : sans cette page,
// un nouvel admin pourrait se demander a quoi sert "card_type",
// pourquoi "depth = 5 max", etc.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/card_type.dart';
import '../../providers/cards_provider.dart';
import '../../providers/games_provider.dart';
import '../../providers/nodes_provider.dart';
import '../../providers/wizard_provider.dart';
import '../../widgets/guidance_banner.dart';

class Step1SetupPage extends ConsumerWidget {
  const Step1SetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(selectedGameProvider)!;
    final cardsAsync = ref.watch(cardsProvider);
    final nodesAsync = ref.watch(nodesProvider);

    // Compteurs deduits (0 par defaut si en cours de chargement).
    final cards = cardsAsync.valueOrNull ?? const [];
    final nodes = nodesAsync.valueOrNull ?? const [];

    final emettrices = cards.where((c) => c.type == CardType.emettrice).length;
    final cables = cards.where((c) => c.type == CardType.cable).length;
    final receptrices =
        cards.where((c) => c.type == CardType.receptrice).length;

    return ResponsiveLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---------------------------------------------------
          // BANNER : c'est l'etape 1 et voila pourquoi
          // ---------------------------------------------------
          // (le logo reste uniquement dans l'AppBar du WizardShell
          // pour eviter le double affichage sur cette page.)
          GuidanceBanner(
            icon: Icons.flag_outlined,
            title: 'Configuration du jeu',
            description:
                'Verifions ensemble ce qui est deja en place pour "${game.name}". On va ensuite enrichir les cartes, puis composer les fusions.',
          ),

          const SizedBox(height: 20),

          // ---------------------------------------------------
          // RECAP : compteurs
          // ---------------------------------------------------
          Text('Etat actuel', style: AppTextStyles.sectionTitle()),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.bolt,
                  label: 'Ingredient A',
                  value: '$emettrices',
                  color: AppColors.cardEmettrice,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.cable,
                  label: 'Ingredient B',
                  value: '$cables',
                  color: AppColors.cardCable,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.adjust,
                  label: 'Produits',
                  value: '$receptrices',
                  color: AppColors.cardReceptrice,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatCard(
            icon: Icons.account_tree_outlined,
            label: 'Fusions composees',
            value: '${nodes.length}',
            color: AppColors.brand,
            wide: true,
          ),

          const SizedBox(height: 28),

          // ---------------------------------------------------
          // EXPLICATION DE LA LOGIQUE TRIALGO
          // ---------------------------------------------------
          Text('Rappel de la logique', style: AppTextStyles.sectionTitle()),
          const SizedBox(height: 10),
          _RuleBlock(
            n: '1',
            title: 'Une fusion = A + B => Produit',
            description:
                'Deux ingredients (A et B) fusionnent pour produire une carte resultat. C\'est la brique de base du jeu.',
          ),
          const SizedBox(height: 8),
          _RuleBlock(
            n: '2',
            title: 'Les fusions s\'enchainent',
            description:
                'Le produit d\'une fusion peut devenir l\'ingredient A d\'une fusion suivante. C\'est le chainage : D1 (racine), D2 (enfant), ... jusqu\'a D5.',
          ),
          const SizedBox(height: 8),
          _RuleBlock(
            n: '3',
            title: 'Indice unique par fusion',
            description:
                'Chaque fusion recoit un numero unique dans le jeu (1, 2, 3...). Il sert au mode collectif pour valider une reponse au clavier.',
          ),

          const SizedBox(height: 28),

          // ---------------------------------------------------
          // CTA : passer a l'etape 2
          // ---------------------------------------------------
          ElevatedButton.icon(
            onPressed: () => ref.read(wizardProvider.notifier).next(),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuer : ajouter des cartes'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// =============================================================
// _StatCard : tuile statistique colorée
// =============================================================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: wide
          ? Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: AppTextStyles.label()),
                ),
                Text(
                  value,
                  style: AppTextStyles.hero().copyWith(
                    fontSize: 24,
                    color: color,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: AppTextStyles.hero().copyWith(
                    fontSize: 22,
                    color: color,
                  ),
                ),
                Text(label, style: AppTextStyles.caption()),
              ],
            ),
    );
  }
}

// =============================================================
// _RuleBlock : bloc explicatif numerote
// =============================================================
class _RuleBlock extends StatelessWidget {
  final String n;
  final String title;
  final String description;

  const _RuleBlock({
    required this.n,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label()),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
