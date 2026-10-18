// =============================================================
// FICHIER : step4_preview_page.dart
// ROLE    : Etape 4 - apercu du graphe complet (theme studio)
// =============================================================
//
// L'admin voit visuellement le resultat de son travail :
// l'arbre des trios avec leurs profondeurs, sur un canvas
// sombre facon "studio".
//
// Implementation :
//   - graphview (BuchheimWalker) calcule les positions
//   - Fond : grille de points faible (_DotGridPainter) + vignette
//   - Chaque node = pastille compacte glowing (couleur = depth)
//     avec #index en gros + pill "Dx". Tap -> bottom sheet detail.
//   - InteractiveViewer (zoom + pan) pilote par un
//     TransformationController -> bouton "recentrer".
//   - Legende DYNAMIQUE : n'affiche que les profondeurs presentes.
//
// RACINE VIRTUELLE "JEU"
// ----------------------
// BuchheimWalker est un algorithme d'ARBRE : il part d'UNE racine,
// la premiere qu'il trouve (graphview 1.5, firstWhere sur les noeuds
// sans predecesseur). Or un jeu TRIALGO est une FORET : chaque fusion
// D1 sans parent est une racine. Les autres racines n'etaient jamais
// positionnees : elles restaient toutes empilees a l'origine, les unes
// sur les autres. Sur un jeu a huit fusions D1, on n'en voyait que deux.
//
// On ajoute donc un noeud fictif (cle _kRootKey) dont TOUTES les D1
// sont les enfants. La foret devient un arbre unique, que l'algorithme
// sait dessiner en entier. Ce noeud est rendu comme une pastille
// "jeu", visiblement differente d'une fusion, et n'est pas cliquable.
//
// CADRAGE AUTOMATIQUE
// -------------------
// Un arbre complet est souvent plus large que l'ecran. A l'ouverture
// (et a chaque modification du graphe), on mesure le graphe dessine
// et on calcule le zoom qui le fait tenir en entier : l'admin voit
// TOUT d'emblee, puis zoome la ou il veut. Le bouton "recentrer"
// rejoue ce meme cadrage au lieu de revenir a l'echelle 1.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/game_card.dart';
import '../../../domain/entities/game_node.dart';
import '../../providers/cards_provider.dart';
import '../../providers/games_provider.dart';
import '../../providers/nodes_provider.dart';
import '../../providers/wizard_provider.dart';
import '../../widgets/card_thumbnail.dart';
import '../../widgets/guidance_banner.dart';
import 'fusion_analyzer_sheet.dart';

class Step4PreviewPage extends ConsumerWidget {
  const Step4PreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodesAsync = ref.watch(nodesProvider);
    final cardsAsync = ref.watch(cardsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: GuidanceBanner(
            icon: Icons.account_tree_outlined,
            title: 'Aperçu de l\'arbre',
            description:
                'Le graphe des fusions du jeu. Pincez/molette pour zoomer, glissez pour naviguer. Tapez une fusion pour voir ses cartes.',
          ),
        ),
        Expanded(
          child: nodesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Erreur: $e', style: AppTextStyles.caption()),
            ),
            data: (nodes) {
              if (nodes.isEmpty) {
                return _EmptyTree();
              }
              final cards = cardsAsync.valueOrNull ?? const [];
              return _GraphView(nodes: nodes, cards: cards);
            },
          ),
        ),

        // ----------------------------------------------------
        // LEGENDE depth (dynamique) + bas de page
        // ----------------------------------------------------
        _BottomBar(
          depths: _presentDepths(nodesAsync.valueOrNull ?? const []),
          onBack: () => ref.read(wizardProvider.notifier).back(),
          onFinish: () {
            ref.read(wizardProvider.notifier).reset();
            ref.read(selectedGameProvider.notifier).state = null;
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  // Profondeurs reellement presentes, triees (pour la legende).
  List<int> _presentDepths(List<GameNode> nodes) {
    final set = <int>{for (final n in nodes) n.depth};
    final list = set.toList()..sort();
    return list;
  }
}

// =============================================================
// _EmptyTree : etat vide stylise (pas de trios)
// =============================================================
class _EmptyTree extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(Icons.account_tree_outlined,
                  size: 40, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Text('Aucune fusion pour le moment',
                style: AppTextStyles.sectionTitle()),
            const SizedBox(height: 6),
            Text(
              'Revenez à l\'étape précédente pour composer vos premières fusions.',
              style: AppTextStyles.caption(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _GraphView : visualisation graphview + tap handler
// =============================================================
class _GraphView extends StatefulWidget {
  final List<GameNode> nodes;
  final List<GameCard> cards;
  const _GraphView({required this.nodes, required this.cards});

  @override
  State<_GraphView> createState() => _GraphViewState();
}

// Cle du noeud fictif "jeu". Les nodeIndex reels commencent a 1 : une
// valeur negative ne peut jamais entrer en collision avec eux.
const int _kRootKey = -1;

class _GraphViewState extends State<_GraphView> {
  late Graph _graph;
  // Permet de mesurer le graphe une fois dessine (cadrage auto).
  final _graphKey = GlobalKey();
  late BuchheimWalkerConfiguration _builder;
  // Controle le zoom/pan : permet le bouton "recentrer".
  final _tc = TransformationController();
  // Node selectionne (pour le mettre en avant visuellement).
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _GraphView old) {
    super.didUpdateWidget(old);
    if (old.nodes != widget.nodes) _rebuild();
  }

  void _rebuild() {
    _graph = Graph();
    final byId = <String, Node>{};
    for (final n in widget.nodes) {
      byId[n.id] = Node.Id(n.nodeIndex);
    }
    // Racine fictive : voir l'en-tete du fichier. Toute fusion sans
    // parent CONNU lui est rattachee. "Connu" compte : un parent
    // supprime cote serveur laisserait sinon un noeud orphelin, que
    // l'algorithme traiterait comme une seconde racine, donc invisible.
    final root = Node.Id(_kRootKey);
    for (final n in widget.nodes) {
      final parentId = n.parentNodeId;
      if (parentId != null && byId.containsKey(parentId)) {
        _graph.addEdge(byId[parentId]!, byId[n.id]!);
      } else {
        _graph.addEdge(root, byId[n.id]!);
      }
    }
    // Le cadrage se calcule APRES le dessin : il faut connaitre la
    // taille reelle du graphe, que seul le layout fournit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToView());
    // Layout BuchheimWalker : arbre top-down, niveaux espaces.
    _builder = BuchheimWalkerConfiguration()
      ..siblingSeparation = 36
      ..levelSeparation = 64
      ..subtreeSeparation = 36
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  GameNode? _byIndex(int idx) {
    for (final n in widget.nodes) {
      if (n.nodeIndex == idx) return n;
    }
    return null;
  }

  void _recenter() => _fitToView();

  // -----------------------------------------------------------
  // Cadrage : tout le graphe visible, centre
  // -----------------------------------------------------------
  // scale = le plus petit des deux rapports (largeur, hauteur) entre
  // la zone visible et le graphe, plafonne a 1 : un petit arbre n'est
  // pas agrandi (des pastilles geantes n'apportent rien), un grand est
  // reduit jusqu'a tenir. Le plancher 0.25 = minScale du viewer.
  // On translate ensuite pour centrer le graphe dans la zone.
  void _fitToView() {
    if (!mounted) return;
    final viewport = context.size;
    final graphBox =
        _graphKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || graphBox == null || !graphBox.hasSize) return;
    final g = graphBox.size;
    if (g.width == 0 || g.height == 0) return;
    final scale = [
      viewport.width / g.width,
      viewport.height / g.height,
      1.0,
    ].reduce((a, b) => a < b ? a : b).clamp(0.25, 1.0);
    final dx = (viewport.width - g.width * scale) / 2;
    final dy = (viewport.height - g.height * scale) / 2;
    _tc.value = Matrix4.identity()
      ..translateByDouble(dx, dy < 0 ? 0.0 : dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _openDetail(GameNode node) {
    setState(() => _selectedIndex = node.nodeIndex);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _NodeDetailSheet(node: node, cards: widget.cards),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedIndex = null);
    });
  }

  // Paint des aretes : trait fin teinte brand (effet "energie").
  Paint get _edgePaint => Paint()
    ..color = AppColors.brand.withValues(alpha: 0.45)
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fond : grille de points faible (canvas studio).
        Positioned.fill(
          child: CustomPaint(painter: _DotGridPainter()),
        ),
        // Le graphe, zoomable / pannable.
        InteractiveViewer(
          transformationController: _tc,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(120),
          minScale: 0.25,
          maxScale: 3.0,
          child: Padding(
            key: _graphKey,
            padding: const EdgeInsets.all(40),
            child: GraphView(
              graph: _graph,
              algorithm: BuchheimWalkerAlgorithm(
                _builder,
                TreeEdgeRenderer(_builder),
              ),
              paint: _edgePaint,
              builder: (Node node) {
                final idx = node.key!.value as int;
                if (idx == _kRootKey) {
                  return _GameRootBubble(
                    roots: widget.nodes
                        .where((n) => n.parentNodeId == null)
                        .length,
                  );
                }
                final gameNode = _byIndex(idx);
                if (gameNode == null) return const SizedBox.shrink();
                return _NodeBubble(
                  node: gameNode,
                  selected: _selectedIndex == idx,
                  onTap: () => _openDetail(gameNode),
                );
              },
            ),
          ),
        ),
        // Pile de boutons flottants (bas-droite) : analyseur + recentrer.
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AnalyzerButton(
                onTap: () =>
                    FusionAnalyzerSheet.show(context, widget.nodes),
              ),
              const SizedBox(height: 10),
              _RecenterButton(onTap: _recenter),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================
// _AnalyzerButton : ouvre l'analyseur de fusion sur 3 cartes
// =============================================================
class _AnalyzerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AnalyzerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Style "primaire" (fond brand) pour contraster avec le
    // recentrer (secondaire). Indique que c'est l'action
    // exploratoire principale sur cette page.
    return Material(
      color: AppColors.brand,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.science_outlined,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Analyser',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// _DotGridPainter : grille de points discrete (fond canvas)
// =============================================================
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppColors.border.withValues(alpha: 0.5);
    const step = 28.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.0, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// =============================================================
// _RecenterButton : pastille flottante pour recentrer
// =============================================================
class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.center_focus_strong,
              color: AppColors.brand, size: 22),
        ),
      ),
    );
  }
}

// =============================================================
// _NodeBubble : pastille glowing representant un node
// =============================================================
class _NodeBubble extends StatelessWidget {
  final GameNode node;
  final bool selected;
  final VoidCallback onTap;

  const _NodeBubble({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.depth(node.depth);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 78,
          height: 72,
          decoration: BoxDecoration(
            // Degrade vertical pour donner du volume a la pastille.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                Color.lerp(color, Colors.black, 0.28)!,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.brand : Colors.white.withValues(alpha: 0.12),
              width: selected ? 2.5 : 1,
            ),
            // Glow : plus fort si selectionne.
            boxShadow: AppColors.glow(color, strength: selected ? 1.6 : 1.0),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${node.nodeIndex}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 5),
              // Pill "Dx" sur fond translucide sombre.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'D${node.depth}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// _GameRootBubble : la racine fictive qui regroupe les D1
// =============================================================
// Volontairement differente d'une fusion : contour seul, pas de
// remplissage colore, pas de numero. Elle n'est pas une donnee du jeu
// mais un point d'accroche pour le dessin ; elle annonce simplement
// combien de fusions racines elle porte.
class _GameRootBubble extends StatelessWidget {
  final int roots;
  const _GameRootBubble({required this.roots});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hub_outlined, color: AppColors.brand, size: 20),
          const SizedBox(height: 3),
          Text(
            '$roots racine${roots > 1 ? 's' : ''}',
            style: AppTextStyles.caption().copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// _BottomBar : legende dynamique + navigation
// =============================================================
class _BottomBar extends StatelessWidget {
  final List<int> depths;
  final VoidCallback onBack;
  final VoidCallback onFinish;
  const _BottomBar({
    required this.depths,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Legende : uniquement les profondeurs presentes.
            if (depths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    for (final d in depths)
                      _LegendChip(depth: d, color: AppColors.depth(d)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onFinish,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Terminer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _NodeDetailSheet : bottom sheet detail du node tap
// =============================================================
class _NodeDetailSheet extends StatelessWidget {
  final GameNode node;
  final List<GameCard> cards;
  const _NodeDetailSheet({required this.node, required this.cards});

  GameCard? _find(String? id) {
    if (id == null) return null;
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final e = _find(node.emettriceId);
    final c = _find(node.cableId);
    final r = _find(node.receptriceId);
    final depthColor = AppColors.depth(node.depth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: depthColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.glow(depthColor, strength: 0.7),
                ),
                child: Text(
                  'D${node.depth}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('Fusion #${node.nodeIndex}',
                  style: AppTextStyles.sectionTitle()),
              const Spacer(),
              if (node.parentNodeId == null)
                _Tag(text: 'RACINE', color: AppColors.brand)
              else
                _Tag(text: 'parent', color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 18),
          // Layout E + C => R.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (e != null)
                Expanded(child: CardThumbnail(card: e, height: 132))
              else
                Expanded(
                  child: _MissingCardBox(
                    label: node.parentNodeId != null
                        ? 'Ingredient A\ndeduit (produit parent)'
                        : 'Ingredient A\nmanquant',
                    deduced: node.parentNodeId != null,
                  ),
                ),
              const _Operator('+'),
              if (c != null)
                Expanded(child: CardThumbnail(card: c, height: 132))
              else
                const Expanded(
                  child: _MissingCardBox(label: 'Ingredient B\nmanquant'),
                ),
              const _Operator('='),
              if (r != null)
                Expanded(child: CardThumbnail(card: r, height: 132))
              else
                const Expanded(
                  child: _MissingCardBox(label: 'Produit\nmanquant'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Petit operateur "+" / "=" entre les cartes.
class _Operator extends StatelessWidget {
  final String symbol;
  const _Operator(this.symbol);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// Petit tag arrondi (RACINE / parent).
class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MissingCardBox extends StatelessWidget {
  final String label;
  final bool deduced;
  const _MissingCardBox({required this.label, this.deduced = false});

  @override
  Widget build(BuildContext context) {
    final accent = deduced ? AppColors.cardReceptrice : AppColors.border;
    return Container(
      height: 132,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: deduced ? 0.5 : 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            deduced ? Icons.link : Icons.help_outline,
            color: deduced ? AppColors.cardReceptrice : AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================
// _LegendChip : indicateur de couleur depth
// =============================================================
class _LegendChip extends StatelessWidget {
  final int depth;
  final Color color;
  const _LegendChip({required this.depth, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: AppColors.glow(color, strength: 0.5),
          ),
        ),
        const SizedBox(width: 5),
        Text('Profondeur $depth', style: AppTextStyles.caption()),
      ],
    );
  }
}
