// =============================================================
// FICHIER : graph_page.dart
// ROLE    : Visualiser l'arbre des nodes + preview d'un trio
// =============================================================
//
// Le graphe TRIALGO n'est pas un arbre unique : c'est une foret
// de 15 D1, chacun pouvant avoir des descendants D2-D5. graphview
// place automatiquement les arbres deconnectes les uns a cote
// des autres (BuchheimWalker layout).
//
// Au tap sur un node, on ouvre un BottomSheet "preview" qui
// montre comment ce trio apparaitrait en jeu.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';

import '../../core/theme.dart';
import '../../data/models/card.dart';
import '../../data/models/node.dart';
import '../providers/cards_provider.dart';
import '../providers/nodes_provider.dart';
import '../widgets/card_thumbnail.dart';

class GraphPage extends ConsumerStatefulWidget {
  const GraphPage({super.key});

  @override
  ConsumerState<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends ConsumerState<GraphPage> {
  // Le Graph et la config BuchheimWalker sont recrees a chaque
  // rebuild des donnees (cf _buildGraph). On les garde dans le
  // state pour eviter de re-instancier a chaque build d'UI.
  Graph? _graph;
  BuchheimWalkerConfiguration? _config;

  // Map<int nodeIndex, GameNode> pour le tap-handler.
  final Map<int, GameNode> _nodeByIndex = {};

  // =========================================================
  // _buildGraph : transforme List<GameNode> en structure graphview
  // =========================================================
  // Chaque GameNode devient un graphview Node identifie par son
  // node_index. On ajoute une edge de parent vers enfant pour
  // construire la hierarchie.
  // =========================================================
  void _buildGraph(List<GameNode> nodes) {
    final g = Graph()..isTree = true;
    _nodeByIndex.clear();

    // Index nodes par id pour lookup parent rapide.
    final byId = {for (final n in nodes) n.id: n};

    for (final n in nodes) {
      _nodeByIndex[n.nodeIndex] = n;

      if (n.parentNodeId != null) {
        final parent = byId[n.parentNodeId];
        if (parent != null) {
          g.addEdge(
            Node.Id(parent.nodeIndex),
            Node.Id(n.nodeIndex),
          );
        }
      } else {
        // Node racine sans parent : on s'assure qu'il est dans le
        // graphe meme s'il n'a pas (encore) d'enfant.
        g.addNode(Node.Id(n.nodeIndex));
      }
    }

    _graph = g;
    _config = BuchheimWalkerConfiguration()
      ..siblingSeparation = 24
      ..levelSeparation = 60
      ..subtreeSeparation = 32
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  // =========================================================
  // _openPreview : BottomSheet avec rendu "comme en jeu"
  // =========================================================
  void _openPreview(GameNode node, List<GameCard> cards) {
    // Resoud les cartes par id, en deduisant l'emettrice du parent
    // pour les D>=2.
    final byId = {for (final c in cards) c.id: c};
    final cable = byId[node.cableId];
    final receptrice = byId[node.receptriceId];

    GameCard? emettrice;
    if (node.emettriceId != null) {
      emettrice = byId[node.emettriceId!];
    } else if (node.parentNodeId != null) {
      // Cherche le node parent dans la liste, puis prend sa receptrice.
      final parent = ref.read(nodesProvider).valueOrNull?.firstWhere(
            (n) => n.id == node.parentNodeId,
            orElse: () => node, // fallback (ne devrait pas arriver)
          );
      if (parent != null) {
        emettrice = byId[parent.receptriceId];
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NodePreviewSheet(
        node: node,
        emettrice: emettrice,
        cable: cable,
        receptrice: receptrice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(nodesProvider);
    final cardsAsync = ref.watch(cardsProvider);

    return Scaffold(
      body: nodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (nodes) {
          if (nodes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun node. Cree des trios depuis l\'onglet Trios.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // (Re)construit le graph a chaque changement de nodes.
          _buildGraph(nodes);

          return Column(
            children: [
              const _DepthLegend(),
              const Divider(height: 1),
              Expanded(
                // InteractiveViewer permet zoom + pan tactile,
                // indispensable pour un graphe de 50+ nodes.
                child: InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(200),
                  minScale: 0.2,
                  maxScale: 3.0,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: GraphView(
                      graph: _graph!,
                      algorithm: BuchheimWalkerAlgorithm(
                        _config!,
                        TreeEdgeRenderer(_config!),
                      ),
                      paint: Paint()
                        ..color = Colors.black26
                        ..strokeWidth = 1
                        ..style = PaintingStyle.stroke,
                      builder: (graphNode) {
                        // graphNode.key.value est le node_index Int
                        // qu'on a passe a Node.Id().
                        final idx = graphNode.key!.value as int;
                        final node = _nodeByIndex[idx];
                        if (node == null) {
                          return const SizedBox.shrink();
                        }
                        return _GraphNodeChip(
                          node: node,
                          onTap: () {
                            final cards = cardsAsync.valueOrNull ?? [];
                            _openPreview(node, cards);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================
// _DepthLegend : bandeau qui explique les couleurs D1->D5
// =============================================================
class _DepthLegend extends StatelessWidget {
  const _DepthLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (var d = 1; d <= 5; d++) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: TBrand.depthColor(d),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text('D$d'),
            const SizedBox(width: 16),
          ],
          const Spacer(),
          const Text(
            'Tap = preview',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// _GraphNodeChip : "noeud" visible dans le graphe (chip colore)
// =============================================================
class _GraphNodeChip extends StatelessWidget {
  final GameNode node;
  final VoidCallback onTap;

  const _GraphNodeChip({required this.node, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = TBrand.depthColor(node.depth);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('D${node.depth}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                )),
            const SizedBox(height: 2),
            Text('#${node.nodeIndex}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _NodePreviewSheet : preview d'un trio comme en jeu
// =============================================================
// Layout : E + C en haut (la "question") => R en bas (la reponse).
// Affiche aussi node_index et depth en sous-titre pour le debug.
// =============================================================
class _NodePreviewSheet extends StatelessWidget {
  final GameNode node;
  final GameCard? emettrice;
  final GameCard? cable;
  final GameCard? receptrice;

  const _NodePreviewSheet({
    required this.node,
    required this.emettrice,
    required this.cable,
    required this.receptrice,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre + meta.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TBrand.depthColor(node.depth).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('D${node.depth}',
                    style: TextStyle(
                        color: TBrand.depthColor(node.depth),
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Text('Trio #${node.nodeIndex}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          // Ligne "E + C =>".
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _slot(
                  label: 'Émettrice',
                  card: emettrice,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('+',
                    style: TextStyle(fontSize: 28, color: Colors.black54)),
              ),
              Expanded(
                child: _slot(
                  label: 'Câble',
                  card: cable,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Icon(Icons.south, size: 32, color: Colors.black45),
            ),
          ),
          // Receptrice agrandie.
          Center(
            child: SizedBox(
              width: 180,
              child: _slot(
                label: 'Réceptrice',
                card: receptrice,
                height: 220,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _slot({required String label, GameCard? card, double height = 160}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 4),
        if (card == null)
          Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('—'),
          )
        else
          CardThumbnail(card: card, height: height),
      ],
    );
  }
}
