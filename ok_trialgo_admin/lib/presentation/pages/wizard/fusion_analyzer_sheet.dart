// =============================================================
// FICHIER : fusion_analyzer_sheet.dart
// ROLE    : Sheet plein ecran "Analyseur de fusion"
// =============================================================
//
// Permet a l'admin de selectionner 3 cartes parmi la bibliotheque
// du jeu en cours, puis de demander a l'app si ces 3 cartes sont
// LIEES dans l'arbre de fusions :
//
//   - directLink  : elles forment exactement une fusion
//   - chainedLink : elles couvrent un chainage parent-enfant
//   - noLink      : rien
//
// Le calcul est delegue a FusionAnalyzer (service pur dans
// domain/services). Ici on s'occupe UNIQUEMENT de :
//   1. afficher 3 slots de selection (chips avec petite image)
//   2. ouvrir un picker bottom-sheet pour remplir chaque slot
//   3. afficher le resultat dans un bloc colore + icones
//
// Style aligne sur le theme studio sombre : surfaces empilees,
// chips avec border subtile, badges colores selon le statut.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/game_card.dart';
import '../../../domain/entities/game_node.dart';
import '../../../domain/services/fusion_analyzer.dart';
import '../../providers/cards_provider.dart';
import '../../widgets/card_thumbnail.dart';

class FusionAnalyzerSheet extends ConsumerStatefulWidget {
  // Les nodes du jeu courant. On les passe en parametre pour
  // eviter de re-watcher le provider dans le sheet (deja fait
  // dans la page hote, evite les rebuilds inutiles).
  final List<GameNode> nodes;

  const FusionAnalyzerSheet({super.key, required this.nodes});

  // -----------------------------------------------------------
  // Helper de presentation : ouvre le sheet en modal plein ecran.
  // Style : DraggableScrollableSheet aurait pu marcher mais
  // showModalBottomSheet avec isScrollControlled = true + padding
  // top suffit pour notre usage (3 slots + bouton + resultat).
  // -----------------------------------------------------------
  static Future<void> show(BuildContext context, List<GameNode> nodes) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        // Padding bas dynamique : evite que le clavier (s'il y en
        // avait un un jour) ne masque le contenu. Top reduit pour
        // laisser apparaitre le canvas derriere.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: FusionAnalyzerSheet(nodes: nodes),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<FusionAnalyzerSheet> createState() =>
      _FusionAnalyzerSheetState();
}

class _FusionAnalyzerSheetState extends ConsumerState<FusionAnalyzerSheet> {
  // 3 slots indexes : null = vide. On limite a 3 selections pour
  // matcher la signature (A + B = C) qui implique exactement 3 cartes.
  final List<GameCard?> _slots = [null, null, null];
  // Resultat courant. null tant qu'on n'a pas lance l'analyse.
  FusionAnalysisResult? _result;

  // -----------------------------------------------------------
  // Ouvre le picker pour remplir le slot d'index `slotIndex`.
  // Le picker affiche toutes les cartes du jeu en grille ; tap
  // ferme et renseigne le slot. On filtre les cartes deja choisies
  // dans d'autres slots pour eviter les doublons.
  // -----------------------------------------------------------
  Future<void> _openPicker(int slotIndex, List<GameCard> allCards) async {
    final excluded = <String>{
      for (int i = 0; i < _slots.length; i++)
        if (i != slotIndex && _slots[i] != null) _slots[i]!.id,
    };
    final available = allCards.where((c) => !excluded.contains(c.id)).toList();
    final picked = await showModalBottomSheet<GameCard>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CardPickerGrid(cards: available),
    );
    if (picked != null) {
      setState(() {
        _slots[slotIndex] = picked;
        _result = null; // on invalide le resultat precedent
      });
    }
  }

  // -----------------------------------------------------------
  // Lance l'analyse via FusionAnalyzer.
  // -----------------------------------------------------------
  void _analyze(List<GameCard> allCards) {
    final selected = _slots.whereType<GameCard>().toList();
    final r = FusionAnalyzer.analyze(
      selectedCards: selected,
      nodes: widget.nodes,
      allCards: allCards,
    );
    setState(() => _result = r);
  }

  // -----------------------------------------------------------
  // Reset complet : vide les 3 slots et le resultat.
  // -----------------------------------------------------------
  void _reset() {
    setState(() {
      for (int i = 0; i < _slots.length; i++) {
        _slots[i] = null;
      }
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final allCards = cardsAsync.valueOrNull ?? const <GameCard>[];
    final canAnalyze = _slots.every((s) => s != null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ------------------------------------------------------
        // POIGNEE + TITRE
        // ------------------------------------------------------
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppColors.glow(AppColors.brand, strength: 0.4),
                ),
                child: const Icon(Icons.science_outlined,
                    color: AppColors.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analyseur de fusion',
                        style: AppTextStyles.pageTitle()
                            .copyWith(fontSize: 20)),
                    Text(
                      'Choisissez 3 cartes : on vous dit si elles sont liees.',
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Fermer',
              ),
            ],
          ),
        ),
        const Divider(height: 28),

        // ------------------------------------------------------
        // CORPS SCROLLABLE
        // ------------------------------------------------------
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3 slots horizontaux.
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Expanded(
                        child: _SlotTile(
                          index: i + 1,
                          card: _slots[i],
                          onTap: allCards.isEmpty
                              ? null
                              : () => _openPicker(i, allCards),
                        ),
                      ),
                      if (i < 2)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            i == 0 ? '+' : '?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // CTA principaux.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed:
                            canAnalyze ? () => _analyze(allCards) : null,
                        icon: const Icon(Icons.science),
                        label: const Text('Analyser la liaison'),
                      ),
                    ),
                  ],
                ),
                if (!canAnalyze) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Remplissez les 3 emplacements pour activer l\'analyse.',
                    style: AppTextStyles.caption(),
                    textAlign: TextAlign.center,
                  ),
                ],

                // ----------------------------------------------
                // RESULTAT
                // ----------------------------------------------
                if (_result != null) ...[
                  const SizedBox(height: 24),
                  _ResultBlock(result: _result!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// _SlotTile : un emplacement de selection (vide ou rempli)
// =============================================================
class _SlotTile extends StatelessWidget {
  final int index;
  final GameCard? card;
  final VoidCallback? onTap;

  const _SlotTile({
    required this.index,
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: card != null
                ? AppColors.brand.withValues(alpha: 0.6)
                : AppColors.border,
            width: card != null ? 1.6 : 1,
          ),
          boxShadow: card != null
              ? AppColors.glow(AppColors.brand, strength: 0.4)
              : null,
        ),
        child: card == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.textSecondary, size: 28),
                  const SizedBox(height: 6),
                  Text('Carte $index',
                      style: AppTextStyles.caption().copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CardThumbnail(card: card!, height: 150),
              ),
      ),
    );
  }
}

// =============================================================
// _CardPickerGrid : grille du picker (selection d'une carte)
// =============================================================
class _CardPickerGrid extends StatelessWidget {
  final List<GameCard> cards;
  const _CardPickerGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Choisir une carte',
                    style: AppTextStyles.sectionTitle()),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: cards.isEmpty
                  ? Center(
                      child: Text(
                        'Aucune carte disponible.',
                        style: AppTextStyles.caption(),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (_, i) {
                        final c = cards[i];
                        return CardThumbnail(
                          card: c,
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _ResultBlock : affichage du resultat d'analyse
// =============================================================
class _ResultBlock extends StatelessWidget {
  final FusionAnalysisResult result;
  const _ResultBlock({required this.result});

  @override
  Widget build(BuildContext context) {
    // Couleur d'accent + icone en fonction du verdict.
    final accent = switch (result.kind) {
      FusionAnalysisKind.directLink => AppColors.success,
      FusionAnalysisKind.chainedLink => AppColors.brand,
      FusionAnalysisKind.noLink => AppColors.warning,
    };
    final icon = switch (result.kind) {
      FusionAnalysisKind.directLink => Icons.check_circle_outline,
      FusionAnalysisKind.chainedLink => Icons.account_tree_outlined,
      FusionAnalysisKind.noLink => Icons.cancel_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: AppColors.glow(accent, strength: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.summary,
                  style: AppTextStyles.label().copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (result.detail != null) ...[
            const SizedBox(height: 10),
            Text(
              result.detail!,
              style: AppTextStyles.body(),
            ),
          ],
          if (result.involvedNodes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in result.involvedNodes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.depth(n.depth).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.depth(n.depth).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '#${n.nodeIndex}  -  D${n.depth}',
                      style: AppTextStyles.caption().copyWith(
                        color: AppColors.depth(n.depth),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
