// =============================================================
// FICHIER : step2_cards_page.dart
// ROLE    : Etape 2 - bibliotheque de cartes (CRUD + upload)
// =============================================================
//
// L'admin :
//   1. Voit la grille des cartes existantes
//   2. Filtre par type (Emettrice / Cable / Receptrice / Toutes)
//   3. Ajoute une nouvelle carte via un bottom sheet :
//      - choix d'image (galerie ou camera)
//      - label
//      - type
//   4. Tape sur une carte pour la modifier ou la supprimer
//
// Garde-fou pour passer a l'etape 3 :
//   il faut au moins 1 E + 1 C + 1 R, sinon impossible de
//   composer un trio. Le CTA "Continuer" est disabled tant que
//   cette condition n'est pas remplie ; un texte explicatif
//   apparait pour expliquer pourquoi.
// =============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/result.dart';
import '../../../domain/entities/card_type.dart';
import '../../../domain/entities/game_card.dart';
import '../../providers/cards_provider.dart';
import '../../providers/games_provider.dart';
import '../../providers/repositories_provider.dart';
import '../../providers/wizard_provider.dart';
import '../../widgets/card_thumbnail.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/guidance_banner.dart';
import '../../widgets/wizard_nav.dart';

class Step2CardsPage extends ConsumerStatefulWidget {
  const Step2CardsPage({super.key});

  @override
  ConsumerState<Step2CardsPage> createState() => _Step2CardsPageState();
}

class _Step2CardsPageState extends ConsumerState<Step2CardsPage> {
  // Filtre courant. null = toutes les cartes.
  CardType? _filter;

  // -----------------------------------------------------------
  // Ouvre le sheet de creation. Si succes, on refresh la liste.
  // -----------------------------------------------------------
  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateCardSheet(),
    );
    if (created == true && mounted) {
      await ref.read(cardsProvider.notifier).refresh();
    }
  }

  // -----------------------------------------------------------
  // Tap sur une carte existante : sheet de modification.
  // -----------------------------------------------------------
  Future<void> _openEditSheet(GameCard card) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditCardSheet(card: card),
    );
    if (changed == true && mounted) {
      await ref.read(cardsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final cards = cardsAsync.valueOrNull ?? const [];

    // Conditions pour passer a l'etape suivante.
    final hasE = cards.any((c) => c.type == CardType.emettrice);
    final hasC = cards.any((c) => c.type == CardType.cable);
    final hasR = cards.any((c) => c.type == CardType.receptrice);
    final canContinue = hasE && hasC && hasR;

    // Liste filtree (sur la valeur du filtre).
    final filtered = _filter == null
        ? cards
        : cards.where((c) => c.type == _filter).toList();

    return Column(
      children: [
        // ----------------------------------------------------
        // EN-TETE FIXE : banniere + filtre + bouton ajout
        // ----------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GuidanceBanner(
                icon: Icons.collections_outlined,
                title: 'Cartes du jeu',
                description:
                    'Ajoutez vos cartes en specifiant leur role dans la fusion : Ingredient A, Ingredient B, ou Produit. Il faut au moins 1 de chaque pour composer une fusion.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _FilterBar(
                    value: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                  )),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _openCreateSheet,
                    icon: const Icon(Icons.add),
                    tooltip: 'Ajouter une carte',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ----------------------------------------------------
        // GRILLE des cartes filtrees
        // ----------------------------------------------------
        Expanded(
          child: cardsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (_) {
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.add_photo_alternate_outlined,
                  title: _filter == null
                      ? 'Aucune carte pour l\'instant'
                      : 'Aucune ${_filter!.label.toLowerCase()}',
                  description:
                      'Tapez sur le + ci-dessus pour importer votre premiere image.',
                  actionLabel: 'Ajouter une carte',
                  onAction: _openCreateSheet,
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(cardsProvider.notifier).refresh(),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Breakpoints.gridColumns(context),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return CardThumbnail(
                      card: c,
                      onTap: () => _openEditSheet(c),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // ----------------------------------------------------
        // BAS DE PAGE : retour + continuer (widget partage)
        // ----------------------------------------------------
        WizardNav(
          canContinue: canContinue,
          continueLabel: 'Continuer : composer des fusions',
          missingHint: canContinue
              ? null
              : 'Pour continuer, il faut au moins 1 ingredient A, 1 ingredient B et 1 produit.',
          onBack: () => ref.read(wizardProvider.notifier).back(),
          onNext: () => ref.read(wizardProvider.notifier).next(),
        ),
      ],
    );
  }
}

// =============================================================
// _FilterBar : ChoiceChips pour filtrer par type
// =============================================================
class _FilterBar extends StatelessWidget {
  final CardType? value;
  final ValueChanged<CardType?> onChanged;

  const _FilterBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Une rangee de chips scroll horizontal si trop large.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'Toutes',
            selected: value == null,
            onTap: () => onChanged(null),
          ),
          const SizedBox(width: 6),
          for (final t in CardType.values) ...[
            _Chip(
              label: t.label,
              selected: value == t,
              color: switch (t) {
                CardType.emettrice => AppColors.cardEmettrice,
                CardType.cable => AppColors.cardCable,
                CardType.receptrice => AppColors.cardReceptrice,
              },
              onTap: () => onChanged(t),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.brand;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: c.withValues(alpha: 0.2),
      labelStyle: AppTextStyles.label().copyWith(
        color: selected ? c : AppColors.textPrimary,
      ),
      side: BorderSide(
        color: selected ? c : AppColors.border,
      ),
    );
  }
}

// =============================================================
// _CreateCardSheet : formulaire d'ajout (image + label + type)
// =============================================================
class _CreateCardSheet extends ConsumerStatefulWidget {
  const _CreateCardSheet();

  @override
  ConsumerState<_CreateCardSheet> createState() => _CreateCardSheetState();
}

class _CreateCardSheetState extends ConsumerState<_CreateCardSheet> {
  final _labelCtrl = TextEditingController();
  // Bytes de l'image selectionnee. null = pas encore choisie.
  Uint8List? _imageBytes;
  String? _imageName;
  String? _contentType;
  CardType _type = CardType.emettrice;
  bool _submitting = false;
  String? _errorMsg;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // Picker : ouvre la galerie. imageQuality 80 / maxWidth 1024
  // pour limiter la taille du fichier upload (bucket = 5 MB max).
  // -----------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
      // mime lookup : depuis l'extension du fichier. Fallback jpeg
      // si lookup echoue.
      _contentType = lookupMimeType(picked.name) ?? 'image/jpeg';
      _errorMsg = null;
    });
  }

  Future<void> _submit() async {
    if (_imageBytes == null) {
      setState(() => _errorMsg = 'Choisissez une image');
      return;
    }
    if (_labelCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Donnez un label a la carte');
      return;
    }
    final game = ref.read(selectedGameProvider);
    if (game == null) return;

    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    final cardRepo = ref.read(cardRepositoryProvider);

    // 1. Upload l'image dans le bucket.
    final upRes = await cardRepo.uploadImage(
      gameId: game.id,
      fileName: _imageName ?? 'card.jpg',
      bytes: _imageBytes!,
      contentType: _contentType ?? 'image/jpeg',
    );
    if (upRes is Err) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMsg = upRes.failureOrNull?.message ?? 'Upload echoue';
      });
      return;
    }
    final publicUrl = (upRes as Ok<String>).value;

    // 2. INSERT row cards avec l'URL recue.
    final cardRes = await cardRepo.create(
      gameId: game.id,
      label: _labelCtrl.text.trim(),
      imagePath: publicUrl,
      type: _type,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (cardRes) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(failure: final f):
        setState(() => _errorMsg = f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text('Nouvelle carte', style: AppTextStyles.pageTitle()),
            const SizedBox(height: 4),
            Text(
              'Image + label + type. L\'image sera uploadee dans Supabase Storage.',
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 16),

            // PREVIEW IMAGE ou placeholder.
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: _imageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.image_outlined,
                              size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          Text('Aucune image',
                              style: AppTextStyles.caption()),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(_imageBytes!,
                            fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galerie'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Lion',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            Text('Type', style: AppTextStyles.label()),
            const SizedBox(height: 6),
            // SegmentedButton pour choisir le type explicitement.
            SegmentedButton<CardType>(
              segments: const [
                ButtonSegment(
                  value: CardType.emettrice,
                  label: Text('Ingredient A'),
                  icon: Icon(Icons.bolt),
                ),
                ButtonSegment(
                  value: CardType.cable,
                  label: Text('Ingredient B'),
                  icon: Icon(Icons.cable),
                ),
                ButtonSegment(
                  value: CardType.receptrice,
                  label: Text('Produit'),
                  icon: Icon(Icons.adjust),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMsg!,
                style: AppTextStyles.caption()
                    .copyWith(color: AppColors.danger),
              ),
            ],

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: const Text('Uploader la carte'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _EditCardSheet : modifier ou supprimer une carte existante
// =============================================================
class _EditCardSheet extends ConsumerStatefulWidget {
  final GameCard card;
  const _EditCardSheet({required this.card});

  @override
  ConsumerState<_EditCardSheet> createState() => _EditCardSheetState();
}

class _EditCardSheetState extends ConsumerState<_EditCardSheet> {
  late final TextEditingController _labelCtrl;
  late CardType _type;
  bool _submitting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.card.label);
    _type = widget.card.type ?? CardType.emettrice;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });
    final repo = ref.read(cardRepositoryProvider);
    final res = await repo.update(
      id: widget.card.id,
      label: _labelCtrl.text.trim().isEmpty
          ? null
          : _labelCtrl.text.trim(),
      type: _type,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (res) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(failure: final f):
        setState(() => _errorMsg = f.message);
    }
  }

  Future<void> _delete() async {
    // Confirmation explicite : suppression irreversible.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la carte ?'),
        content: const Text(
          'L\'image sera supprimee du bucket Storage. Cette action est irreversible.',
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
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });
    final repo = ref.read(cardRepositoryProvider);
    final res = await repo.delete(
      id: widget.card.id,
      imagePath: widget.card.imagePath,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (res) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(failure: final f):
        setState(() => _errorMsg = f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Modifier la carte', style: AppTextStyles.pageTitle()),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: CardThumbnail(card: widget.card, height: 180),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Label',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            Text('Type', style: AppTextStyles.label()),
            const SizedBox(height: 6),
            SegmentedButton<CardType>(
              segments: const [
                ButtonSegment(
                    value: CardType.emettrice, label: Text('Ingredient A')),
                ButtonSegment(
                    value: CardType.cable, label: Text('Ingredient B')),
                ButtonSegment(
                    value: CardType.receptrice, label: Text('Produit')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMsg!,
                style: AppTextStyles.caption()
                    .copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _submitting ? null : _delete,
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.danger),
              label: const Text(
                'Supprimer cette carte',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
