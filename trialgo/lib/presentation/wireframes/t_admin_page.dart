// =============================================================
// FICHIER : lib/presentation/wireframes/t_admin_page.dart
// ROLE   : Interface d'administration des cartes et du graphe
// COUCHE : Presentation > Wireframes
// =============================================================
//
// ACCESSIBLE UNIQUEMENT A admin@trialgo.com.
//
// FONCTIONNALITES :
//   1. Voir le catalogue de cartes (images uploadees)
//   2. Ajouter des cartes au catalogue
//   3. Voir l'arbre des noeuds (graphe visuel)
//   4. Creer des noeuds racines (E + C + R)
//   5. Creer des noeuds enfants (parent + C + R)
//   6. Supprimer des noeuds
//   7. Lancer une demo de jeu
//
// DESIGN : sobre et fonctionnel (pas premium comme le jeu).
// L'admin a besoin de clarte et d'efficacite, pas d'animations.
//
// REFERENCE : Discussion architecture graphe, avril 2026
// =============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/network/supabase_client.dart';
import 'package:trialgo/data/models/graph_card_model.dart';
import 'package:trialgo/data/models/graph_node_model.dart';
import 'package:trialgo/domain/entities/graph_card_entity.dart';
import 'package:trialgo/domain/entities/graph_node_entity.dart';

/// Page d'administration du graphe de jeu.
///
/// Permet a l'admin de gerer les cartes et les noeuds du graphe
/// directement depuis l'application. Deux onglets :
///   - Cartes : catalogue d'images
///   - Graphe : arbre des noeuds
class TAdminPage extends StatefulWidget {
  const TAdminPage({super.key});

  @override
  State<TAdminPage> createState() => _TAdminPageState();
}

class _TAdminPageState extends State<TAdminPage>
    with SingleTickerProviderStateMixin {

  // =============================================================
  // ETAT
  // =============================================================

  /// Controller pour les 2 onglets (Cartes / Graphe).
  late TabController _tabController;

  /// Liste des cartes chargees depuis Supabase.
  List<GraphCardEntity> _cards = [];

  /// Liste des noeuds charges depuis Supabase.
  List<GraphNodeEntity> _nodes = [];

  /// Indicateur de chargement.
  bool _loading = true;

  /// Message d'erreur eventuel.
  String? _error;

  @override
  void initState() {
    super.initState();
    // 2 onglets : Cartes et Graphe.
    _tabController = TabController(length: 2, vsync: this);
    // Charger les donnees au demarrage.
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =============================================================
  // CHARGEMENT DES DONNEES
  // =============================================================
  // Charge les cartes et les noeuds depuis Supabase.
  // Appele au demarrage et apres chaque modification.
  // =============================================================

  /// Charge les cartes et noeuds depuis Supabase.
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Charger les cartes et les noeuds en parallele.
      final results = await Future.wait([
        supabase.from('cards').select().order('created_at'),
        supabase.from('nodes').select().order('node_index', ascending: true),
      ]);

      // results[0] = List<Map> des cartes
      // results[1] = List<Map> des noeuds
      final cardData = results[0] as List<dynamic>;
      final nodeData = results[1] as List<dynamic>;

      setState(() {
        _cards = cardData
            .map((j) => GraphCardModel.fromJson(j as Map<String, dynamic>))
            .toList();
        _nodes = nodeData
            .map((j) => GraphNodeModel.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TSurfaceColors.darkBgBase,
      appBar: AppBar(
        backgroundColor: TSurfaceColors.darkBgRaised,
        title: Text(
          'Administration',
          style: GoogleFonts.rajdhani(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        // Les 2 onglets.
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TColors.primary,
          labelColor: TColors.primary,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.exo2(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Cartes'),
            Tab(icon: Icon(Icons.account_tree), text: 'Graphe'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: Color(0xFFFF6B35),
            ))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Reessayer'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCardsTab(),
                    _buildGraphTab(),
                  ],
                ),
    );
  }

  // =============================================================
  // ONGLET CARTES
  // =============================================================
  // Affiche le catalogue de cartes en grille.
  // Bouton flottant pour ajouter une carte.
  // =============================================================

  Widget _buildCardsTab() {
    return Stack(
      children: [
        // Grille des cartes.
        _cards.isEmpty
            ? Center(
                child: Text(
                  'Aucune carte.\nUtilisez le + pour en ajouter.',
                  style: GoogleFonts.exo2(color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  return _buildCardTile(_cards[index]);
                },
              ),
        // Bouton d'ajout.
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: TColors.primary,
            onPressed: _showAddCardDialog,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Tuile d'une carte dans la grille.
  Widget _buildCardTile(GraphCardEntity card) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Image de la carte.
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: card.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6B35),
                  ),
                ),
                errorWidget: (context, error, stack) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white24,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          // Label de la carte.
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              card.label,
              style: GoogleFonts.exo2(
                fontSize: 11,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // ONGLET GRAPHE
  // =============================================================
  // Affiche l'arbre des noeuds par profondeur.
  // Chaque noeud montre E + C = R avec les labels des cartes.
  // Bouton flottant pour ajouter un noeud.
  // =============================================================

  Widget _buildGraphTab() {
    // Regrouper les noeuds par profondeur.
    final byDepth = <int, List<GraphNodeEntity>>{};
    for (final node in _nodes) {
      byDepth.putIfAbsent(node.depth, () => []).add(node);
    }

    return Stack(
      children: [
        _nodes.isEmpty
            ? Center(
                child: Text(
                  'Aucun noeud.\nUtilisez le + pour en ajouter.',
                  style: GoogleFonts.exo2(color: Colors.white38),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                children: [
                  // Compteur total.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${_nodes.length} noeuds',
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF7C948),
                      ),
                    ),
                  ),

                  // Afficher par profondeur.
                  for (int depth = 1; depth <= 3; depth++) ...[
                    if (byDepth[depth] != null &&
                        byDepth[depth]!.isNotEmpty) ...[
                      // Titre de la profondeur.
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _depthColor(depth)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Profondeur $depth  (${byDepth[depth]!.length})',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _depthColor(depth),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Les noeuds de cette profondeur.
                      ...byDepth[depth]!.map((n) => _buildNodeTile(n)),
                    ],
                  ],
                ],
              ),
        // Bouton d'ajout de noeud.
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: TColors.primary,
            onPressed: _showAddNodeDialog,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Couleur selon la profondeur.
  Color _depthColor(int depth) {
    switch (depth) {
      case 1:
        return const Color(0xFF66BB6A); // Vert pour les racines.
      case 2:
        return const Color(0xFF42A5F5); // Bleu pour P2.
      case 3:
        return TColors.primary; // Orange pour P3.
      default:
        return Colors.white54;
    }
  }

  /// Tuile d'un noeud dans la liste.
  Widget _buildNodeTile(GraphNodeEntity node) {
    // Retrouver les labels des cartes.
    final eLabel = _findCardLabel(node.emettriceId);
    final cLabel = _findCardLabel(node.cableId);
    final rLabel = _findCardLabel(node.receptriceId);

    // Retrouver le parent si enfant.
    String? parentLabel;
    if (node.parentNodeId != null) {
      final parent = _nodes.cast<GraphNodeEntity?>().firstWhere(
            (n) => n?.id == node.parentNodeId,
            orElse: () => null,
          );
      if (parent != null) {
        parentLabel = 'N${parent.nodeIndex}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _depthColor(node.depth).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Index du noeud dans un cercle.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _depthColor(node.depth).withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                'N${node.nodeIndex}',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _depthColor(node.depth),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Details du trio.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Trio E + C = R.
                Text(
                  '${eLabel ?? "?"} + $cLabel = $rLabel',
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Parent si enfant.
                if (parentLabel != null)
                  Text(
                    'Parent : $parentLabel',
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      color: Colors.white30,
                    ),
                  ),
              ],
            ),
          ),
          // Bouton supprimer.
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red.withValues(alpha: 0.5),
            onPressed: () => _confirmDeleteNode(node),
          ),
        ],
      ),
    );
  }

  /// Trouve le label d'une carte par son ID.
  String? _findCardLabel(String? cardId) {
    if (cardId == null) return null;
    final card = _cards.cast<GraphCardEntity?>().firstWhere(
          (c) => c?.id == cardId,
          orElse: () => null,
        );
    return card?.label;
  }

  // =============================================================
  // DIALOGUES
  // =============================================================

  /// Dialogue pour ajouter une carte.
  void _showAddCardDialog() {
    final labelController = TextEditingController();
    final pathController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TSurfaceColors.darkBgRaised,
        title: Text(
          'Ajouter une carte',
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Label',
                labelStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Chemin image (ex: savane/lion.webp)',
                labelStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFFF6B35)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColors.primary,
            ),
            onPressed: () async {
              if (labelController.text.isEmpty ||
                  pathController.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              await _addCard(labelController.text, pathController.text);
            },
            child: const Text('Ajouter',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Dialogue pour ajouter un noeud.
  void _showAddNodeDialog() {
    if (_cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez des cartes avant de creer des noeuds.'),
        ),
      );
      return;
    }

    final indexController = TextEditingController();
    String? selectedEmettriceId;
    String? selectedCableId;
    String? selectedReceptriceId;
    String? selectedParentId;
    int selectedDepth = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Construire la liste des cartes pour les dropdowns.
          final cardItems = _cards
              .map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.label,
                        style: const TextStyle(color: Colors.white)),
                  ))
              .toList();

          // Construire la liste des noeuds parents potentiels.
          final parentItems = _nodes
              .where((n) => n.depth < 3) // Un parent ne peut pas etre P3.
              .map((n) => DropdownMenuItem(
                    value: n.id,
                    child: Text('N${n.nodeIndex}',
                        style: const TextStyle(color: Colors.white)),
                  ))
              .toList();

          return AlertDialog(
            backgroundColor: TSurfaceColors.darkBgRaised,
            title: Text(
              'Ajouter un noeud',
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Index du noeud.
                  TextField(
                    controller: indexController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Index (ex: 1)'),
                  ),
                  const SizedBox(height: 12),

                  // Profondeur.
                  Text('Profondeur',
                      style: GoogleFonts.exo2(
                          color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 4),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                    ],
                    selected: {selectedDepth},
                    onSelectionChanged: (v) {
                      setDialogState(() => selectedDepth = v.first);
                    },
                    style: ButtonStyle(
                      foregroundColor:
                          WidgetStateProperty.all(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Parent (si profondeur > 1).
                  if (selectedDepth > 1) ...[
                    _dropdownField(
                      label: 'Parent',
                      value: selectedParentId,
                      items: parentItems,
                      onChanged: (v) =>
                          setDialogState(() => selectedParentId = v),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Emettrice (si profondeur 1).
                  if (selectedDepth == 1) ...[
                    _dropdownField(
                      label: 'Emettrice (E)',
                      value: selectedEmettriceId,
                      items: cardItems,
                      onChanged: (v) =>
                          setDialogState(() => selectedEmettriceId = v),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Cable (toujours).
                  _dropdownField(
                    label: 'Cable (C)',
                    value: selectedCableId,
                    items: cardItems,
                    onChanged: (v) =>
                        setDialogState(() => selectedCableId = v),
                  ),
                  const SizedBox(height: 12),

                  // Receptrice (toujours).
                  _dropdownField(
                    label: 'Receptrice (R)',
                    value: selectedReceptriceId,
                    items: cardItems,
                    onChanged: (v) =>
                        setDialogState(() => selectedReceptriceId = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TColors.primary,
                ),
                onPressed: () async {
                  final index = int.tryParse(indexController.text);
                  if (index == null) { return; }
                  if (selectedCableId == null ||
                      selectedReceptriceId == null) { return; }
                  if (selectedDepth == 1 &&
                      selectedEmettriceId == null) { return; }
                  if (selectedDepth > 1 &&
                      selectedParentId == null) { return; }

                  Navigator.pop(ctx);
                  await _addNode(
                    index: index,
                    depth: selectedDepth,
                    emettriceId: selectedEmettriceId,
                    cableId: selectedCableId!,
                    receptriceId: selectedReceptriceId!,
                    parentNodeId: selectedParentId,
                  );
                },
                child: const Text('Ajouter',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Decoration commune pour les champs texte des dialogues.
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderSide:
            BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFF6B35)),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  /// Dropdown personalise avec label.
  Widget _dropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.exo2(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButton<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            dropdownColor: TSurfaceColors.darkBgRaised,
            underline: const SizedBox(),
            hint: Text('Choisir...',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25))),
          ),
        ),
      ],
    );
  }

  /// Confirmer la suppression d'un noeud.
  void _confirmDeleteNode(GraphNodeEntity node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TSurfaceColors.darkBgRaised,
        title: Text(
          'Supprimer N${node.nodeIndex} ?',
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Les noeuds enfants seront aussi supprimes (cascade).',
          style: GoogleFonts.exo2(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteNode(node.id);
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // OPERATIONS SUPABASE
  // =============================================================

  /// Ajoute une carte au catalogue.
  Future<void> _addCard(String label, String imagePath) async {
    try {
      await supabase.from('cards').insert({
        'label': label,
        'image_path': imagePath,
      });
      await _loadData(); // Recharger la liste.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  /// Ajoute un noeud au graphe.
  Future<void> _addNode({
    required int index,
    required int depth,
    String? emettriceId,
    required String cableId,
    required String receptriceId,
    String? parentNodeId,
  }) async {
    try {
      await supabase.from('nodes').insert({
        'node_index': index,
        'depth': depth,
        'emettrice_id': emettriceId,   // null si enfant.
        'cable_id': cableId,
        'receptrice_id': receptriceId,
        'parent_node_id': parentNodeId, // null si racine.
      });
      await _loadData(); // Recharger la liste.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  /// Supprime un noeud.
  Future<void> _deleteNode(String nodeId) async {
    try {
      await supabase.from('nodes').delete().eq('id', nodeId);
      await _loadData(); // Recharger la liste.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }
}
