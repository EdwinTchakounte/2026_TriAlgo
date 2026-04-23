// =============================================================
// FICHIER : lib/presentation/wireframes/t_gallery_page.dart
// ROLE   : Galerie des cartes - collection du joueur
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Stats header : "X/Y cartes debloquees" + progress bar
//   - Filter chips : Toutes / Debloquees / A decouvrir
//   - Role chips : Tous / E / C / R
//   - Grille 2 colonnes de cartes (AppCard.glass)
//   - Carte unlocked : image pleine + label + badge de role
//   - Carte locked : silhouette + "?" + cadenas superpose
//   - Tap unlocked : reveal fullscreen dialog
//   - Empty state si le filtre ne matche aucune carte
// =============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_card.dart';
import 'package:trialgo/presentation/widgets/core/app_chip.dart';
import 'package:trialgo/presentation/widgets/core/empty_state.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/core/section_header.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';


/// Filtre sur l'etat des cartes.
enum _CardsFilter { all, unlocked, locked }

/// Filtre sur le role des cartes.
enum _CardsRole { all, emettrice, cable, receptrice }


class _GalleryCard {
  final String id;
  final String label;
  final String imageUrl;
  final bool unlocked;
  final _CardsRole role;

  const _GalleryCard({
    required this.id,
    required this.label,
    required this.imageUrl,
    required this.unlocked,
    required this.role,
  });
}


class TGalleryPage extends ConsumerStatefulWidget {
  const TGalleryPage({super.key});

  @override
  ConsumerState<TGalleryPage> createState() => _TGalleryPageState();
}

class _TGalleryPageState extends ConsumerState<TGalleryPage> {
  _CardsFilter _filter = _CardsFilter.all;
  _CardsRole _role = _CardsRole.all;

  /// Construit la liste complete des cartes a partir du graphe.
  List<_GalleryCard> _buildAllCards() {
    final sync = ref.read(graphSyncServiceProvider);
    if (!sync.isReady) return const [];

    final cards = sync.cards;
    final graph = sync.gameGraph!;
    final unlockedIds = ref.read(profileProvider).unlockedCards;

    // Collecter les roles par carte (une carte peut avoir plusieurs roles).
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

    final result = <_GalleryCard>[];
    for (final c in cards.values) {
      // Determine le role principal : R > E > C (priorite).
      final _CardsRole r;
      if (receptriceIds.contains(c.id)) {
        r = _CardsRole.receptrice;
      } else if (emettriceIds.contains(c.id)) {
        r = _CardsRole.emettrice;
      } else if (cableIds.contains(c.id)) {
        r = _CardsRole.cable;
      } else {
        continue; // carte orpheline du graphe, on l'ignore
      }

      result.add(_GalleryCard(
        id: c.id,
        label: c.label,
        imageUrl: c.imageUrl,
        unlocked: unlockedIds.contains(c.id),
        role: r,
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    final all = _buildAllCards();
    final unlockedCount = all.where((c) => c.unlocked).length;
    final total = all.length;
    final progress = total == 0 ? 0.0 : unlockedCount / total;

    // Applique les filtres.
    final filtered = all.where((c) {
      if (_filter == _CardsFilter.unlocked && !c.unlocked) return false;
      if (_filter == _CardsFilter.locked && c.unlocked) return false;
      if (_role != _CardsRole.all && c.role != _role) return false;
      return true;
    }).toList();

    return PageScaffold(
      title: tr('gallery.title'),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- Stats header ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TSpacing.xxl,
                TSpacing.md,
                TSpacing.xxl,
                TSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('gallery.unlocked_count'),
                          style: TTypography.bodyMd(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '$unlockedCount/$total',
                        style: TTypography.numericMd(color: TColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: TSpacing.sm),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.surface,
                      valueColor: const AlwaysStoppedAnimation(TColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Filter chips : etat (scrollable horizontal) ---
          // SingleChildScrollView horizontal + Row pour eviter tout
          // overflow sur petits ecrans et garder les chips alignes
          // sur une ligne claire, sans coupures ou sauts de ligne.
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: TSpacing.xxl,
                vertical: TSpacing.xs,
              ),
              child: Row(
                children: [
                  AppChip(
                    label: tr('gallery.chip_all'),
                    selected: _filter == _CardsFilter.all,
                    onTap: () => setState(() => _filter = _CardsFilter.all),
                  ),
                  const SizedBox(width: TSpacing.sm),
                  AppChip(
                    label: tr('gallery.chip_unlocked'),
                    selected: _filter == _CardsFilter.unlocked,
                    onTap: () =>
                        setState(() => _filter = _CardsFilter.unlocked),
                  ),
                  const SizedBox(width: TSpacing.sm),
                  AppChip(
                    label: tr('gallery.chip_locked'),
                    selected: _filter == _CardsFilter.locked,
                    onTap: () =>
                        setState(() => _filter = _CardsFilter.locked),
                  ),
                ],
              ),
            ),
          ),

          // --- Role chips (scrollable horizontal) ---
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: TSpacing.xxl,
                vertical: TSpacing.xs,
              ),
              child: Row(
                children: [
                  AppChip(
                    label: tr('gallery.chip_all_roles'),
                    selected: _role == _CardsRole.all,
                    onTap: () => setState(() => _role = _CardsRole.all),
                  ),
                  const SizedBox(width: TSpacing.sm),
                  AppChip(
                    label: tr('gallery.chip_emettrice'),
                    icon: Icons.circle,
                    selected: _role == _CardsRole.emettrice,
                    onTap: () =>
                        setState(() => _role = _CardsRole.emettrice),
                  ),
                  const SizedBox(width: TSpacing.sm),
                  AppChip(
                    label: tr('gallery.chip_cable'),
                    icon: Icons.cable_rounded,
                    selected: _role == _CardsRole.cable,
                    onTap: () => setState(() => _role = _CardsRole.cable),
                  ),
                  const SizedBox(width: TSpacing.sm),
                  AppChip(
                    label: tr('gallery.chip_receptrice'),
                    icon: Icons.star_rounded,
                    selected: _role == _CardsRole.receptrice,
                    onTap: () =>
                        setState(() => _role = _CardsRole.receptrice),
                  ),
                ],
              ),
            ),
          ),

          // --- Titre de section ou empty state ---
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: tr('gallery.empty_title'),
                description: tr('gallery.empty_body'),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: TSpacing.xxl),
                child: SectionHeader(
                  title:
                      '${filtered.length} ${filtered.length > 1 ? tr('gallery.count_suffix_many') : tr('gallery.count_suffix_one')}',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                TSpacing.xxl,
                TSpacing.sm,
                TSpacing.xxl,
                TSpacing.xxxl,
              ),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: TSpacing.md,
                  crossAxisSpacing: TSpacing.md,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final card = filtered[index];
                    return _buildCardTile(card);
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =============================================================
  // CARTE TILE
  // =============================================================

  Widget _buildCardTile(_GalleryCard card) {
    return AppCard.glass(
      padding: EdgeInsets.zero,
      onTap: card.unlocked ? () => _revealFullscreen(card) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Image ---
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(TRadius.lg),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image ou silhouette selon l'etat.
                  card.unlocked
                      ? CachedNetworkImage(
                          imageUrl: card.imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              _buildImageFallback(),
                          placeholder: (_, _) => _buildImageFallback(),
                        )
                      : _buildLockedSilhouette(),

                  // Cadenas superpose si locked.
                  if (!card.unlocked)
                    const Center(
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white70,
                        size: 32,
                      ),
                    ),

                  // Badge de role en haut a gauche.
                  Positioned(
                    top: TSpacing.xs,
                    left: TSpacing.xs,
                    child: _buildRoleBadge(card.role),
                  ),
                ],
              ),
            ),
          ),

          // --- Nom de carte ---
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.sm,
              vertical: TSpacing.sm,
            ),
            child: Text(
              card.unlocked ? card.label : '???',
              style: TTypography.labelLg(
                color: card.unlocked
                    ? TColors.of(context).textPrimary
                    : TColors.of(context).textTertiary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFallback() {
    return Container(
      color: TColors.of(context).surface,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.white38),
    );
  }

  Widget _buildLockedSilhouette() {
    return Container(
      color: Color.fromARGB(
        0x40,
        TColors.of(context).borderDefault.r.round(),
        TColors.of(context).borderDefault.g.round(),
        TColors.of(context).borderDefault.b.round(),
      ),
    );
  }

  Widget _buildRoleBadge(_CardsRole role) {
    late final String label;
    late final Color color;
    switch (role) {
      case _CardsRole.emettrice:
        label = 'E';
        color = TColors.info;
      case _CardsRole.cable:
        label = 'C';
        color = TColors.primary;
      case _CardsRole.receptrice:
        label = 'R';
        color = TColors.success;
      case _CardsRole.all:
        label = '?';
        color = Colors.grey;
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TTypography.labelSm(color: Colors.white),
      ),
    );
  }

  // =============================================================
  // FULLSCREEN REVEAL (dialog)
  // =============================================================

  void _revealFullscreen(_GalleryCard card) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(TSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: TRadius.xxlAll,
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: card.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: TSpacing.md),
            Text(
              card.label,
              style: TTypography.headlineMd(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
