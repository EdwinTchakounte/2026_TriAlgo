// =============================================================
// FICHIER : trios_page.dart
// ROLE    : Composer un trio (Émettrice + Câble => Réceptrice)
// =============================================================
//
// Le user choisit 3 cartes et un parent (optionnel) :
//
//   [Emettrice] + [Cable]  =>  [Receptrice]
//   parent: [optionnel pour D>=2]
//
// Si parent est null  : le trio est un D1 (racine).
// Sinon              : le trio est un enfant du parent (D >= 2).
//                       L'emettrice doit etre = receptrice du parent
//                       (regle metier du graphe).
//
// On affiche un panneau "Composition" avec preview live, puis on
// valide. La validation calcule depth + node_index et fait l'INSERT.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/card.dart';
import '../../data/models/card_type.dart';
import '../../data/models/node.dart';
import '../providers/cards_provider.dart';
import '../providers/games_provider.dart';
import '../providers/nodes_provider.dart';
import '../providers/repositories_provider.dart';
import '../widgets/card_thumbnail.dart';

class TriosPage extends ConsumerStatefulWidget {
  const TriosPage({super.key});

  @override
  ConsumerState<TriosPage> createState() => _TriosPageState();
}

class _TriosPageState extends ConsumerState<TriosPage> {
  // Selections en cours.
  GameCard? _emettrice;
  GameCard? _cable;
  GameCard? _receptrice;
  GameNode? _parent;

  // Si _parent != null, on force _emettrice = receptrice du parent.
  // Donc le picker emettrice est cache et remplace par un readonly.

  void _reset() {
    setState(() {
      _emettrice = null;
      _cable = null;
      _receptrice = null;
      _parent = null;
    });
  }

  // =========================================================
  // _validate : INSERT du trio
  // =========================================================
  Future<void> _validate() async {
    final messenger = ScaffoldMessenger.of(context);
    final game = ref.read(selectedGameProvider);
    if (game == null) return;

    // Garde-fous : tous les ids doivent etre presents.
    if (_cable == null || _receptrice == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choisissez un cable et une receptrice')),
      );
      return;
    }

    // Cas D1 : on attend une emettrice explicite.
    if (_parent == null && _emettrice == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('D1 : choisissez une emettrice')),
      );
      return;
    }

    final repo = ref.read(nodeRepositoryProvider);

    // Calcule node_index = MAX+1 (idempotent suffisant pour MVP).
    final nextIndex = await repo.nextNodeIndex(game.id);

    // Profondeur : D1 si pas de parent, parent.depth + 1 sinon.
    final depth = (_parent?.depth ?? 0) + 1;
    if (depth > 5) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Profondeur max = 5')),
      );
      return;
    }

    try {
      await repo.createTrio(
        gameId: game.id,
        nodeIndex: nextIndex,
        // En D1 : emettrice explicite. En D>=2 : null (deduite cote app).
        emettriceId: _parent == null ? _emettrice!.id : null,
        cableId: _cable!.id,
        receptriceId: _receptrice!.id,
        parentNodeId: _parent?.id,
        depth: depth,
      );
      // Refresh la liste de nodes pour la page Graph.
      await ref.read(nodesProvider.notifier).refresh();
      _reset();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Trio cree (D$depth, n=$nextIndex)')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur creation : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final nodesAsync = ref.watch(nodesProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Choix du parent (optionnel, pour D>=2).
            _SectionHeader(
              title: 'Parent (laisser vide pour D1 racine)',
              hint: 'Le parent fournit l\'emettrice effective.',
            ),
            const SizedBox(height: 8),
            nodesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Erreur: $e'),
              data: (nodes) => _ParentPicker(
                nodes: nodes,
                value: _parent,
                onChanged: (n) {
                  setState(() {
                    _parent = n;
                    // Si on choisit un parent, l'emettrice est implicite.
                    _emettrice = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            // 2. Picker emettrice (D1) ou affichage readonly (D>=2).
            if (_parent == null) ...[
              _SectionHeader(title: 'Emettrice'),
              const SizedBox(height: 8),
              cardsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erreur: $e'),
                data: (cards) => _CardPickerStrip(
                  cards: cards.where((c) => c.type == CardType.emettrice).toList(),
                  selected: _emettrice,
                  onChanged: (c) => setState(() => _emettrice = c),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              _SectionHeader(
                title: 'Emettrice (deduite du parent)',
                hint: 'C\'est la receptrice du noeud parent.',
              ),
              const SizedBox(height: 8),
              cardsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (cards) {
                  final parentRecId = _parent!.receptriceId;
                  GameCard? deducedEmettrice;
                  for (final c in cards) {
                    if (c.id == parentRecId) {
                      deducedEmettrice = c;
                      break;
                    }
                  }
                  if (deducedEmettrice == null) {
                    return const Text('Receptrice du parent introuvable');
                  }
                  return SizedBox(
                    width: 120,
                    child: CardThumbnail(card: deducedEmettrice, height: 160),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

            // 3. Picker cable.
            _SectionHeader(title: 'Cable (transformation)'),
            const SizedBox(height: 8),
            cardsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Erreur: $e'),
              data: (cards) => _CardPickerStrip(
                cards: cards.where((c) => c.type == CardType.cable).toList(),
                selected: _cable,
                onChanged: (c) => setState(() => _cable = c),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Picker receptrice.
            _SectionHeader(title: 'Receptrice (resultat)'),
            const SizedBox(height: 8),
            cardsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('Erreur: $e'),
              data: (cards) => _CardPickerStrip(
                cards: cards.where((c) => c.type == CardType.receptrice).toList(),
                selected: _receptrice,
                onChanged: (c) => setState(() => _receptrice = c),
              ),
            ),
            const SizedBox(height: 24),

            // 5. CTA + reset.
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
                        ? 'Creer trio (D1)'
                        : 'Creer enfant (D${(_parent!.depth) + 1})'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _SectionHeader : titre de section + hint optionnel
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
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(hint!,
                style:
                    const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ],
    );
  }
}

// =============================================================
// _CardPickerStrip : carrousel horizontal de selection
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
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Aucune carte disponible'),
      );
    }
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cards[i];
          return SizedBox(
            width: 120,
            child: CardThumbnail(
              card: c,
              selected: selected?.id == c.id,
              onTap: () => onChanged(c),
              height: 160,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================
// _ParentPicker : dropdown des nodes existants pour choisir parent
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
    // On n'autorise comme parents que les nodes de profondeur < 5
    // (sinon l'enfant serait depth=6, interdit).
    final eligible = nodes.where((n) => n.depth < 5).toList();

    return DropdownButtonFormField<GameNode?>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Noeud parent',
        helperText: 'Aucun => trio racine D1',
      ),
      items: [
        const DropdownMenuItem<GameNode?>(
          value: null,
          child: Text('— Aucun (racine D1) —'),
        ),
        ...eligible.map(
          (n) => DropdownMenuItem<GameNode?>(
            value: n,
            child: Text('Node #${n.nodeIndex} (D${n.depth})'),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
