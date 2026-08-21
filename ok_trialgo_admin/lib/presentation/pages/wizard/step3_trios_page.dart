// =============================================================
// FICHIER : step3_trios_page.dart
// ROLE    : Etape 3 - composer les fusions (A + B => Produit)
// =============================================================
//
// Modele mental : une fusion est une operation deterministe
//   ingredient A  +  ingredient B   =   produit
// L'injectivite de la fusion (un produit a UNE seule recette)
// fait que l'arbre TRIALGO est bien un arbre.
//
// Logique du formulaire :
//
//   [Parent]      : aucun (= fusion racine D1) OU noeud existant
//   [Ingredient A] : si pas de parent -> pickable
//                    si parent        -> deduit (= produit du parent)
//   [Ingredient B] : pickable
//   [Produit]      : pickable
//
// Auto-link parent (option declenchee par l'injectivite) :
//   si l'utilisateur choisit un Ingredient A qui est deja le
//   produit d'un noeud existant, on auto-selectionne ce noeud
//   comme parent (avec un toast d'info). Pas d'ambiguite possible.
//
// A la validation :
//   - nodeIndex = MAX + 1 pour ce game
//   - depth = (parent?.depth ?? 0) + 1, max 5
//   - INSERT row nodes via repo
//
// Liste des fusions deja creees affichee en bas pour suivre la
// progression. Tap sur la corbeille = supprimer (avec confirmation).
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/result.dart';
import '../../../domain/entities/card_type.dart';
import '../../../domain/entities/game_card.dart';
import '../../../domain/entities/game_node.dart';
import '../../providers/cards_provider.dart';
import '../../providers/games_provider.dart';
import '../../providers/nodes_provider.dart';
import '../../providers/repositories_provider.dart';
import '../../providers/wizard_provider.dart';
import '../../widgets/card_thumbnail.dart';
import '../../widgets/guidance_banner.dart';
import '../../widgets/wizard_nav.dart';

class Step3TriosPage extends ConsumerStatefulWidget {
  const Step3TriosPage({super.key});

  @override
  ConsumerState<Step3TriosPage> createState() => _Step3TriosPageState();
}

class _Step3TriosPageState extends ConsumerState<Step3TriosPage> {
  // Selections en cours.
  GameCard? _emettrice;
  GameCard? _cable;
  GameCard? _receptrice;
  GameNode? _parent;

  void _reset() {
    setState(() {
      _emettrice = null;
      _cable = null;
      _receptrice = null;
      _parent = null;
    });
  }

  // -----------------------------------------------------------
  // Auto-link parent  (consequence de l'INJECTIVITE de fuse)
  // -----------------------------------------------------------
  // Si l'ingredient A choisi se trouve etre le produit d'une
  // fusion existante, on auto-selectionne cette fusion comme
  // parent : il n'y a au plus QU'UN candidat (injectivite), donc
  // pas d'ambiguite. L'utilisateur voit un petit toast d'info.
  // L'ingredient A devient alors deduit (l'UI bascule sur le
  // mode "enfant").
  void _tryAutoLinkParent(GameCard? ingredientA, List<GameNode> nodes) {
    if (ingredientA == null) return;
    if (_parent != null) return; // parent deja choisi manuellement
    // Cherche la fusion dont le produit == ingredientA.
    GameNode? candidate;
    for (final n in nodes) {
      if (n.receptriceId == ingredientA.id) {
        candidate = n;
        break;
      }
    }
    if (candidate == null) return;
    if (candidate.depth >= 5) return; // sinon enfant depasserait D5
    setState(() {
      _parent = candidate;
      // L'ingredient A devient deduit -> on libere la selection.
      _emettrice = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Chainage automatique : parent = fusion #${candidate.nodeIndex} (D${candidate.depth})',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // -----------------------------------------------------------
  // Validation + INSERT
  // -----------------------------------------------------------
  Future<void> _validate() async {
    final messenger = ScaffoldMessenger.of(context);
    final game = ref.read(selectedGameProvider);
    if (game == null) return;

    // Garde-fous.
    if (_cable == null || _receptrice == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choisissez un ingredient B et un produit')),
      );
      return;
    }
    if (_parent == null && _emettrice == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Fusion racine : choisissez l\'ingredient A')),
      );
      return;
    }

    final depth = (_parent?.depth ?? 0) + 1;
    if (depth > 5) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Profondeur max = 5')),
      );
      return;
    }

    final nodeRepo = ref.read(nodeRepositoryProvider);

    // Calcule node_index = MAX + 1.
    final idxRes = await nodeRepo.nextNodeIndex(game.id);
    if (idxRes is Err) {
      messenger.showSnackBar(SnackBar(
        content: Text(idxRes.failureOrNull!.message),
      ));
      return;
    }
    final nodeIndex = (idxRes as Ok<int>).value;

    final createRes = await nodeRepo.createTrio(
      gameId: game.id,
      nodeIndex: nodeIndex,
      emettriceId: _parent == null ? _emettrice!.id : null,
      cableId: _cable!.id,
      receptriceId: _receptrice!.id,
      parentNodeId: _parent?.id,
      depth: depth,
    );

    switch (createRes) {
      case Ok():
        await ref.read(nodesProvider.notifier).refresh();
        _reset();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Fusion creee (D$depth, n=$nodeIndex)')),
        );
      case Err(failure: final f):
        messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  // -----------------------------------------------------------
  // Suppression d'une fusion
  // -----------------------------------------------------------
  Future<void> _deleteNode(GameNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cette fusion ?'),
        content: Text(
          'La fusion #${node.nodeIndex} (D${node.depth}) sera supprimee, '
          'ainsi que tous ses descendants. Action irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final res = await ref.read(nodeRepositoryProvider).delete(node.id);
    if (res is Ok) {
      await ref.read(nodesProvider.notifier).refresh();
    } else if (!mounted) {
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.failureOrNull!.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final nodesAsync = ref.watch(nodesProvider);
    final cards = cardsAsync.valueOrNull ?? const [];
    final nodes = nodesAsync.valueOrNull ?? const [];

    // Au moins 1 trio = condition pour passer a l'apercu.
    final canContinue = nodes.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -------------------------------------------
                // GUIDANCE
                // -------------------------------------------
                GuidanceBanner(
                  icon: Icons.account_tree_outlined,
                  title: 'Composer les fusions',
                  description:
                      'Une fusion : ingredient A + ingredient B = produit. Pour chainer (D>=2), choisissez un parent : l\'ingredient A sera deduit du produit du parent.',
                ),
                const SizedBox(height: 18),

                // -------------------------------------------
                // PARENT PICKER
                // -------------------------------------------
                _SectionHeader(
                  title: 'Parent (optionnel)',
                  hint:
                      'Vide = fusion racine (D1). Sinon la fusion sera enfant du parent.',
                ),
                const SizedBox(height: 8),
                _ParentPicker(
                  nodes: nodes,
                  value: _parent,
                  onChanged: (n) {
                    setState(() {
                      _parent = n;
                      _emettrice = null; // reset emettrice si parent change
                    });
                  },
                ),
                const SizedBox(height: 20),

                // -------------------------------------------
                // INGREDIENT A  (ex Emettrice)
                // -------------------------------------------
                if (_parent == null) ...[
                  _SectionHeader(
                    title: 'Ingredient A',
                    hint:
                        'Premier ingredient de la fusion. Si c\'est aussi le produit d\'une fusion existante, le chainage sera automatique.',
                  ),
                  const SizedBox(height: 8),
                  _CardPickerStrip(
                    cards: cards
                        .where((c) => c.type == CardType.emettrice)
                        .toList(),
                    selected: _emettrice,
                    onChanged: (c) {
                      setState(() => _emettrice = c);
                      _tryAutoLinkParent(c, nodes);
                    },
                  ),
                ] else ...[
                  _SectionHeader(
                    title: 'Ingredient A (deduit du parent)',
                    hint:
                        'C\'est automatiquement le produit du noeud parent.',
                  ),
                  const SizedBox(height: 8),
                  _DeducedEmettrice(parent: _parent!, cards: cards),
                ],
                const SizedBox(height: 20),

                // -------------------------------------------
                // INGREDIENT B  (ex Cable)
                // -------------------------------------------
                _SectionHeader(title: 'Ingredient B'),
                const SizedBox(height: 8),
                _CardPickerStrip(
                  cards:
                      cards.where((c) => c.type == CardType.cable).toList(),
                  selected: _cable,
                  onChanged: (c) => setState(() => _cable = c),
                ),
                const SizedBox(height: 20),

                // -------------------------------------------
                // PRODUIT  (ex Receptrice)
                // -------------------------------------------
                _SectionHeader(title: 'Produit'),
                const SizedBox(height: 8),
                _CardPickerStrip(
                  cards: cards
                      .where((c) => c.type == CardType.receptrice)
                      .toList(),
                  selected: _receptrice,
                  onChanged: (c) => setState(() => _receptrice = c),
                ),
                const SizedBox(height: 24),

                // -------------------------------------------
                // ACTIONS : reset + valider
                // -------------------------------------------
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _reset,
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _validate,
                        icon: const Icon(Icons.check),
                        label: Text(_parent == null
                            ? 'Creer fusion (D1)'
                            : 'Creer fusion enfant (D${(_parent!.depth) + 1})'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // -------------------------------------------
                // LISTE DES TRIOS DEJA CREES
                // -------------------------------------------
                if (nodes.isNotEmpty) ...[
                  _SectionHeader(title: 'Deja composees (${nodes.length})'),
                  const SizedBox(height: 8),
                  for (final n in nodes)
                    _TrioRow(
                      node: n,
                      cards: cards,
                      onDelete: () => _deleteNode(n),
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ----------------------------------------------------
        // BAS DE PAGE : retour + continuer (widget partage)
        // ----------------------------------------------------
        WizardNav(
          canContinue: canContinue,
          continueLabel: 'Continuer : voir l\'arbre',
          missingHint: canContinue
              ? null
              : 'Composez au moins une fusion pour passer a l\'apercu.',
          onBack: () => ref.read(wizardProvider.notifier).back(),
          onNext: () => ref.read(wizardProvider.notifier).next(),
        ),
      ],
    );
  }
}

// =============================================================
// _SectionHeader : titre + hint
// =============================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? hint;
  const _SectionHeader({required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.label().copyWith(fontSize: 15)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: AppTextStyles.caption()),
        ],
      ],
    );
  }
}

// =============================================================
// _CardPickerStrip : carrousel horizontal
// =============================================================
class _CardPickerStrip extends StatelessWidget {
  final List<GameCard> cards;
  final GameCard? selected;
  final ValueChanged<GameCard> onChanged;

  const _CardPickerStrip({
    required this.cards,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Aucune carte de ce type. Revenez a l\'etape Cartes pour en ajouter.',
          style: AppTextStyles.caption(),
          textAlign: TextAlign.center,
        ),
      );
    }
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cards[i];
          return SizedBox(
            width: 120,
            child: CardThumbnail(
              card: c,
              selected: selected?.id == c.id,
              onTap: () => onChanged(c),
              height: 170,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// _DeducedEmettrice : affichage readonly de l'emettrice deduite
// =============================================================
class _DeducedEmettrice extends StatelessWidget {
  final GameNode parent;
  final List<GameCard> cards;

  const _DeducedEmettrice({required this.parent, required this.cards});

  @override
  Widget build(BuildContext context) {
    GameCard? deduced;
    for (final c in cards) {
      if (c.id == parent.receptriceId) {
        deduced = c;
        break;
      }
    }
    if (deduced == null) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Produit du parent introuvable. La carte a peut-etre ete supprimee.',
          style: AppTextStyles.caption()
              .copyWith(color: AppColors.danger),
          textAlign: TextAlign.center,
        ),
      );
    }
    return SizedBox(
      height: 170,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: CardThumbnail(card: deduced, height: 170),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deduction', style: AppTextStyles.label()),
                  const SizedBox(height: 4),
                  Text(
                    'Cette carte (${deduced.label}) sera l\'ingredient A de la nouvelle fusion, parce qu\'elle est le produit du parent #${parent.nodeIndex}.',
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// _ParentPicker : dropdown des nodes existants (depth < 5)
// =============================================================
class _ParentPicker extends StatelessWidget {
  final List<GameNode> nodes;
  final GameNode? value;
  final ValueChanged<GameNode?> onChanged;

  const _ParentPicker({
    required this.nodes,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Seuls les noeuds depth < 5 peuvent avoir un enfant.
    final eligible = nodes.where((n) => n.depth < 5).toList();
    return DropdownButtonFormField<GameNode?>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Noeud parent',
        prefixIcon: Icon(Icons.account_tree),
      ),
      items: [
        const DropdownMenuItem<GameNode?>(
          value: null,
          child: Text('Aucun (racine D1)'),
        ),
        ...eligible.map(
          (n) => DropdownMenuItem<GameNode?>(
            value: n,
            child: Text('Fusion #${n.nodeIndex} (D${n.depth})'),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

// =============================================================
// _TrioRow : ligne resumant un trio existant
// =============================================================
class _TrioRow extends StatelessWidget {
  final GameNode node;
  final List<GameCard> cards;
  final VoidCallback onDelete;

  const _TrioRow({
    required this.node,
    required this.cards,
    required this.onDelete,
  });

  GameCard? _find(String? id) {
    if (id == null) return null;
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // L'emettrice effective : explicite si D1, sinon = receptrice
    // du parent (qu'on ne reconstruit pas ici, on affiche juste "?").
    final e = _find(node.emettriceId);
    final c = _find(node.cableId);
    final r = _find(node.receptriceId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Badge profondeur a gauche.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.depth(node.depth).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'D${node.depth}',
              style: TextStyle(
                color: AppColors.depth(node.depth),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${node.nodeIndex}',
                  style: AppTextStyles.label(),
                ),
                Text(
                  '${e?.label ?? "(deduit)"} + ${c?.label ?? "?"}  =>  ${r?.label ?? "?"}',
                  style: AppTextStyles.caption(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Supprimer cette fusion',
          ),
        ],
      ),
    );
  }
}

