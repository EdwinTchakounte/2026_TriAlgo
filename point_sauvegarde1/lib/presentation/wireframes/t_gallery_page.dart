// =============================================================
// FICHIER : lib/presentation/wireframes/t_gallery_page.dart
// ROLE   : Galerie des cartes debloquees (wireframe)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// QU'EST-CE QUE LA GALERIE ?
// ---------------------------
// C'est un ecran de COLLECTION qui affiche toutes les cartes
// que le joueur a decouvertes au fil des niveaux.
//
// Elle est organisee en 3 onglets (filtres par type) :
//   - Emettrices (images de base)
//   - Cables (transformations)
//   - Receptrices (resultats)
//
// Chaque carte est affichee en grille avec son image et son nom.
// Les cartes non debloquees sont affichees en silhouette.
//
// REFERENCE : Recueil v3.0, section 12.11
// =============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';

/// Galerie des cartes debloquees avec onglets de filtrage.
///
/// La galerie lit les cartes du graphe synchronise et determine
/// le ROLE de chaque carte (E, C ou R) selon les noeuds qui
/// l'utilisent.
class TGalleryPage extends ConsumerStatefulWidget {
  const TGalleryPage({super.key});

  @override
  ConsumerState<TGalleryPage> createState() => _TGalleryPageState();
}

class _TGalleryPageState extends ConsumerState<TGalleryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Listes computees a partir du graphe sync.
  /// Vides tant que la sync n'a pas eu lieu.
  List<_GalleryCard> _emettrices = [];
  List<_GalleryCard> _cables = [];
  List<_GalleryCard> _receptrices = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Charger les cartes apres le premier frame pour avoir ref dispo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromGraph());
  }

  // =============================================================
  // CHARGEMENT DEPUIS LE GRAPHE LOCAL
  // =============================================================
  // Parcourt le catalogue de cartes et le graphe pour identifier
  // le role de chaque carte (E, C ou R).
  //
  // ROLES :
  //   - Une carte est EMETTRICE si elle apparait comme emettrice
  //     dans au moins un noeud racine (depth = 1).
  //   - Une carte est CABLE si elle apparait comme cable_id dans
  //     au moins un noeud.
  //   - Une carte est RECEPTRICE si elle apparait comme receptrice_id.
  //
  // Note : une meme carte peut avoir plusieurs roles. On la classe
  // dans toutes les categories ou elle apparait.
  // =============================================================

  void _loadFromGraph() {
    final sync = ref.read(graphSyncServiceProvider);
    if (!sync.isReady) return;

    final cards = sync.cards;
    final graph = sync.gameGraph;
    if (graph == null) return;

    // Lire les cartes debloquees par le joueur (son deck reel).
    // Si une carte n'a pas encore ete gagnee, elle est affichee
    // en silhouette verrouillee.
    final unlockedIds = ref.read(profileProvider).unlockedCards;

    // Collecter les IDs par role (toutes les cartes du graphe).
    final emettriceIds = <String>{};
    final cableIds = <String>{};
    final receptriceIds = <String>{};

    for (final node in graph.nodesByIndex.values) {
      try {
        emettriceIds.add(node.effectiveEmettriceId);
      } catch (_) {}
      cableIds.add(node.cableId);
      receptriceIds.add(node.receptriceId);
    }

    // Construire les listes.
    // Chaque carte est marquee comme "unlocked" si son id est dans
    // le deck du joueur (user_unlocked_cards).
    setState(() {
      _emettrices = emettriceIds
          .map((id) => cards[id])
          .whereType<dynamic>()
          .map((c) => _GalleryCard(
                c.label,
                c.imageUrl,
                unlockedIds.contains(c.id),
              ))
          .toList();

      _cables = cableIds
          .map((id) => cards[id])
          .whereType<dynamic>()
          .map((c) => _GalleryCard(
                c.label,
                c.imageUrl,
                unlockedIds.contains(c.id),
              ))
          .toList();

      _receptrices = receptriceIds
          .map((id) => cards[id])
          .whereType<dynamic>()
          .map((c) => _GalleryCard(
                c.label,
                c.imageUrl,
                unlockedIds.contains(c.id),
              ))
          .toList();
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = TLocale.of(context);
    final totalUnlocked = _emettrices.where((c) => c.unlocked).length
        + _cables.where((c) => c.unlocked).length
        + _receptrices.where((c) => c.unlocked).length;
    final totalCards = _emettrices.length + _cables.length + _receptrices.length;

    return Scaffold(
      body: TTheme.patterned(
        child: SafeArea(
          child: Column(
            children: [
              // --- Header ---
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
                    Text(tr('gallery.title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
                    const Spacer(),
                    // Compteur de collection.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF11998E).withValues(alpha: 0.2),
                            const Color(0xFF38EF7D).withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38EF7D).withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        '$totalUnlocked/$totalCards',
                        style: const TextStyle(
                          color: Color(0xFF38EF7D), fontWeight: FontWeight.w700, fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- Barre de progression de la collection ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: totalUnlocked / totalCards,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF38EF7D)),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(totalUnlocked / totalCards * 100).round()}% ${tr('gallery.unlocked')}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- Onglets (Emettrices / Cables / Receptrices) ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFF7C948)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'E (${_emettrices.where((c) => c.unlocked).length})'),
                    Tab(text: 'C (${_cables.where((c) => c.unlocked).length})'),
                    Tab(text: 'R (${_receptrices.where((c) => c.unlocked).length})'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- Grille de cartes ---
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGrid(_emettrices, const Color(0xFF42A5F5)),
                    _buildGrid(_cables, const Color(0xFFFFA726)),
                    _buildGrid(_receptrices, const Color(0xFF66BB6A)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit la grille de cartes pour un onglet.
  Widget _buildGrid(List<_GalleryCard> cards, Color accentColor) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        // 3 colonnes par ligne.
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
        // Ratio largeur/hauteur : les cartes sont plus hautes que larges.
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return _buildCardTile(card, accentColor);
      },
    );
  }

  /// Construit une tuile de carte dans la grille.
  Widget _buildCardTile(_GalleryCard card, Color accentColor) {
    return GestureDetector(
      onTap: card.unlocked
          ? () => _showCardDetail(card, accentColor)
          : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: card.unlocked
                ? accentColor.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image ou silhouette.
              if (card.unlocked)
                CachedNetworkImage(
                  imageUrl: card.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                  errorWidget: (c, e, s) => Container(
                    color: accentColor.withValues(alpha: 0.15),
                    child: Icon(Icons.image,
                        color: accentColor.withValues(alpha: 0.3)),
                  ),
                )
              else
                Container(
                  color: Colors.white.withValues(alpha: 0.03),
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withValues(alpha: 0.1),
                      size: 28,
                    ),
                  ),
                ),

              // Label en bas.
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: card.unlocked ? 0.7 : 0.3),
                      ],
                    ),
                  ),
                  child: Text(
                    card.unlocked ? card.name : '???',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: card.unlocked ? Colors.white : Colors.white24,
                    ),
                  ),
                ),
              ),

              // Badge "NEW" pour les cartes recentes.
              if (card.unlocked && card.name == 'Requin Coul.')
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('NEW', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche le detail d'une carte en popup.
  void _showCardDetail(_GalleryCard card, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF16163A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre de poignee.
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Image.
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: card.imageUrl,
                width: 180,
                height: 180,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(
                  width: 180,
                  height: 180,
                  color: color.withValues(alpha: 0.1),
                ),
                errorWidget: (c, e, s) => Container(
                  width: 180,
                  height: 180,
                  color: color.withValues(alpha: 0.2),
                  child: Icon(Icons.image, color: color, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(card.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Debloquee',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Modele de carte pour la galerie.
class _GalleryCard {
  final String name;
  final String imageUrl;
  final bool unlocked;

  const _GalleryCard(this.name, this.imageUrl, this.unlocked);
}
