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

import 'package:flutter/material.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';

/// Galerie des cartes debloquees avec onglets de filtrage.
class TGalleryPage extends StatefulWidget {
  const TGalleryPage({super.key});

  @override
  State<TGalleryPage> createState() => _TGalleryPageState();
}

class _TGalleryPageState extends State<TGalleryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Donnees de la galerie : cartes debloquees et verrouillees.
  // Chaque categorie a ses propres cartes.
  final List<_GalleryCard> _emettrices = [
    _GalleryCard('Lion', MockData.emettrice1['imageUrl'] as String, true),
    _GalleryCard('Aigle', MockData.emettrice2['imageUrl'] as String, true),
    _GalleryCard('Requin', MockData.emettrice3['imageUrl'] as String, true),
    _GalleryCard('Tigre', 'https://picsum.photos/seed/gal-e4/200/200', false),
    _GalleryCard('Renard', 'https://picsum.photos/seed/gal-e5/200/200', false),
    _GalleryCard('Panda', 'https://picsum.photos/seed/gal-e6/200/200', false),
    _GalleryCard('Loup', 'https://picsum.photos/seed/gal-e7/200/200', false),
    _GalleryCard('Ours', 'https://picsum.photos/seed/gal-e8/200/200', false),
  ];

  final List<_GalleryCard> _cables = [
    _GalleryCard('Miroir', MockData.cable1['imageUrl'] as String, true),
    _GalleryCard('Rotation', MockData.cable2['imageUrl'] as String, true),
    _GalleryCard('Couleur', MockData.cable3['imageUrl'] as String, true),
    _GalleryCard('Inversion', 'https://picsum.photos/seed/gal-c4/200/200', true),
    _GalleryCard('Fragment.', 'https://picsum.photos/seed/gal-c5/200/200', false),
    _GalleryCard('Ombre', 'https://picsum.photos/seed/gal-c6/200/200', false),
  ];

  final List<_GalleryCard> _receptrices = [
    _GalleryCard('Lion Miroir', MockData.receptrice1['imageUrl'] as String, true),
    _GalleryCard('Aigle Rot.', MockData.receptrice2['imageUrl'] as String, true),
    _GalleryCard('Requin Coul.', MockData.receptrice3['imageUrl'] as String, true),
    _GalleryCard('Lion Rot.', 'https://picsum.photos/seed/gal-r4/200/200', true),
    _GalleryCard('Aigle Coul.', 'https://picsum.photos/seed/gal-r5/200/200', false),
    _GalleryCard('Tigre Miroir', 'https://picsum.photos/seed/gal-r6/200/200', false),
    _GalleryCard('Renard Rot.', 'https://picsum.photos/seed/gal-r7/200/200', false),
    _GalleryCard('Panda Miroir', 'https://picsum.photos/seed/gal-r8/200/200', false),
    _GalleryCard('Loup Coul.', 'https://picsum.photos/seed/gal-r9/200/200', false),
    _GalleryCard('Ours Rot.', 'https://picsum.photos/seed/gal-r10/200/200', false),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
                Image.network(
                  card.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: accentColor.withValues(alpha: 0.15),
                    child: Icon(Icons.image, color: accentColor.withValues(alpha: 0.3)),
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
              child: Image.network(
                card.imageUrl,
                width: 180, height: 180,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: 180, height: 180,
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
