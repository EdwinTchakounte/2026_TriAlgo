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
import '../../../core/utils/libelle_depuis_fichier.dart';
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

// =============================================================
// PARAMETRES DE PRISE D'IMAGE
// =============================================================
// CE QUI N'ALLAIT PAS AVANT
// -------------------------
// Le picker etait regle sur maxWidth 1024 / quality 80, c'est-a-dire
// exactement la taille finale visee par le serveur
// (IMAGE_MAX_DIMENSION = 1024, IMAGE_JPEG_QUALITY = 85).
//
// Consequence : l'image etait compressee DEUX fois, et surtout le
// redimensionnement decisif -- celui qui determine la nettete de la
// carte a l'ecran -- etait fait par le redimensionneur du telephone.
// Le passage LANCZOS du serveur ne trouvait plus rien a reduire et
// ne servait a rien. Sur un jeu ou les images SONT le contenu, on
// perdait de la qualite pour rien.
//
// CE QU'ON FAIT MAINTENANT
// ------------------------
// On envoie une source deux fois plus grande, a peine compressee.
// Le serveur reste seul juge de la reduction finale, en LANCZOS, en
// un seul passage.
//
// POURQUOI PAS L'ORIGINAL BRUT
// ----------------------------
// MAX_UPLOAD_BYTES vaut 5 Mo cote serveur. Une photo de telephone
// recente depasse regulierement ce seuil et repartirait en 413.
// 2048 px a qualite 92 tient autour de 1 a 2 Mo : large marge, et
// bien au-dela de ce dont le rendu final a besoin.
// =============================================================

/// Cote maximal de l'image envoyee au serveur (le double du rendu).
const int _kDimensionSource = 2048;

/// Qualite JPEG a la prise. Volontairement haute : la compression
/// qui compte est celle du serveur, pas celle-ci.
const int _kQualiteSource = 92;

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
  // Import par lot : selection multiple puis upload sequentiel.
  //
  // On ouvre le selecteur AVANT la feuille : si l'administrateur
  // annule la selection, aucune feuille vide ne s'affiche.
  // -----------------------------------------------------------
  Future<void> _openImportLotSheet() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: _kQualiteSource,
      maxWidth: _kDimensionSource.toDouble(),
      maxHeight: _kDimensionSource.toDouble(),
    );
    if (images.isEmpty || !mounted) return;

    final importees = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ImportLotSheet(fichiers: images),
    );
    if (importees == true && mounted) {
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
                  // Import par lot : le chemin normal pour constituer
                  // un jeu. Un jeu complet demande une cinquantaine de
                  // cartes ; les ajouter une par une n'est pas tenable.
                  IconButton.filledTonal(
                    onPressed: _openImportLotSheet,
                    icon: const Icon(Icons.library_add_outlined),
                    tooltip: 'Importer plusieurs images',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      foregroundColor: AppColors.brand,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 8),
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
  // Picker : ouvre la galerie ou l'appareil photo.
  //
  // Voir _kDimensionSource / _kQualiteSource pour le raisonnement
  // sur les valeurs : on n'envoie PAS une image deja reduite a la
  // taille finale, sinon c'est le redimensionneur du telephone qui
  // decide de la qualite au lieu de celui du serveur.
  // -----------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: _kQualiteSource,
      maxWidth: _kDimensionSource.toDouble(),
      maxHeight: _kDimensionSource.toDouble(),
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

// =============================================================
// FEUILLE D'IMPORT PAR LOT
// =============================================================
// POURQUOI CET ECRAN EXISTE
// -------------------------
// Un jeu TRIALGO complet compte une cinquantaine de cartes (les
// 50 noeuds natifs de D1 en consomment trois chacun, avec
// reutilisation). Les saisir une par une, chacune dans sa propre
// feuille modale, represente une cinquantaine d'allers-retours.
// C'est le genre de friction qui decourage de creer un jeu.
//
// CE QU'ON DEMANDE A L'ADMINISTRATEUR
// -----------------------------------
// Le minimum : un role pour tout le lot, et un libelle par image.
// Le libelle est pre-rempli avec le nom du fichier, sans son
// extension -- une photo nommee "lion.jpg" donne "Lion". Dans la
// pratique, une serie d'images bien nommee ne demande alors aucune
// saisie du tout.
//
// UN ROLE UNIQUE POUR TOUT LE LOT, ET POURQUOI C'EST LE BON CHOIX
// ---------------------------------------------------------------
// On pourrait laisser choisir le role image par image. Mais les
// cartes arrivent presque toujours par famille : on prepare
// d'abord ses emettrices, puis ses cables, puis ses receptrices.
// Un selecteur unique correspond a ce geste reel, et trois imports
// successifs restent bien plus rapides qu'une saisie unitaire.
//
// UPLOAD SEQUENTIEL, PAS PARALLELE
// --------------------------------
// Le serveur traite chaque image avec Pillow (decodage, conversion
// RGB, redimensionnement LANCZOS, re-encodage). Lancer cinquante
// requetes de front ferait surtout monter la memoire de l'API sans
// rien accelerer. On enchaine donc, en montrant la progression.
//
// ET SI UNE IMAGE ECHOUE
// ----------------------
// Contrairement a la generation de codes, on NE s'arrete PAS a la
// premiere erreur : chaque image est independante, et une seule
// illisible ne doit pas condamner les quarante-neuf autres. On
// collecte les echecs et on les recapitule a la fin.
// =============================================================

/// Une image en attente d'import, avec son libelle editable.
class _ImageAImporter {
  _ImageAImporter({required this.fichier, required this.libelle});

  /// Le fichier choisi par l'administrateur.
  final XFile fichier;

  /// Champ de saisie du libelle, pre-rempli depuis le nom de fichier.
  final TextEditingController libelle;

  /// Les octets, lus une seule fois puis conserves.
  Uint8List? octets;
}

class _ImportLotSheet extends ConsumerStatefulWidget {
  const _ImportLotSheet({required this.fichiers});

  final List<XFile> fichiers;

  @override
  ConsumerState<_ImportLotSheet> createState() => _ImportLotSheetState();
}

class _ImportLotSheetState extends ConsumerState<_ImportLotSheet> {
  late final List<_ImageAImporter> _images;

  /// Role applique a toutes les cartes du lot.
  CardType _type = CardType.emettrice;

  /// Vrai pendant l'import : verrouille le formulaire.
  bool _enCours = false;

  /// Nombre d'images deja traitees, pour la barre de progression.
  int _traitees = 0;

  /// Libelles des images qui ont echoue, avec la raison.
  final List<String> _echecs = [];

  @override
  void initState() {
    super.initState();
    _images = [
      for (final f in widget.fichiers)
        _ImageAImporter(
          fichier: f,
          libelle: TextEditingController(
            text: libelleDepuisNomDeFichier(f.name),
          ),
        ),
    ];
  }

  @override
  void dispose() {
    for (final image in _images) {
      image.libelle.dispose();
    }
    super.dispose();
  }

  // -----------------------------------------------------------
  // IMPORT
  // -----------------------------------------------------------

  Future<void> _importer() async {
    final game = ref.read(selectedGameProvider);
    if (game == null) return;

    // Un libelle vide serait refuse par le serveur (Form min_length=1).
    // On le detecte ici pour donner un message utile plutot qu'un 422.
    final vides = _images.where((i) => i.libelle.text.trim().isEmpty).length;
    if (vides > 0) {
      _annoncer('$vides image(s) sans libelle. Completez-les d\'abord.');
      return;
    }

    setState(() {
      _enCours = true;
      _traitees = 0;
      _echecs.clear();
    });

    final repo = ref.read(cardRepositoryProvider);
    var reussies = 0;

    for (final image in _images) {
      final libelle = image.libelle.text.trim();

      try {
        // Lecture paresseuse : on ne charge les octets qu'au moment
        // de l'envoi. Garder cinquante images en memoire des
        // l'ouverture de la feuille ferait gonfler l'application
        // pour rien, surtout sur un telephone.
        image.octets ??= await image.fichier.readAsBytes();

        final up = await repo.uploadImage(
          gameId: game.id,
          fileName: image.fichier.name,
          bytes: image.octets!,
          contentType:
              lookupMimeType(image.fichier.name) ?? 'image/jpeg',
        );

        if (up case Err(failure: final f)) {
          _echecs.add('$libelle : ${f.message}');
        } else {
          final res = await repo.create(
            gameId: game.id,
            label: libelle,
            imagePath: (up as Ok<String>).value,
            type: _type,
          );
          switch (res) {
            case Ok():
              reussies++;
            case Err(failure: final f):
              _echecs.add('$libelle : ${f.message}');
          }
        }
      } catch (e) {
        // Fichier illisible, permission refusee, memoire : on note
        // et on passe a la suivante.
        _echecs.add('$libelle : $e');
      }

      if (!mounted) return;
      setState(() => _traitees++);
    }

    if (!mounted) return;

    // Tout est passe : on ferme et la grille se rafraichit.
    if (_echecs.isEmpty) {
      Navigator.of(context).pop(true);
      _annoncer('$reussies carte(s) importee(s).', succes: true);
      return;
    }

    // Des echecs : on reste sur la feuille pour les montrer, mais on
    // signale les reussites (la grille sera rafraichie a la
    // fermeture manuelle).
    setState(() => _enCours = false);
    _annoncer(
      '$reussies importee(s), ${_echecs.length} en echec.',
    );
  }

  void _annoncer(String message, {bool succes = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: succes ? AppColors.success : AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Importer ${_images.length} image(s)',
                      style: AppTextStyles.sectionTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Les libelles sont deduits des noms de fichiers. '
                      'Corrigez ceux qui en ont besoin.',
                      style: AppTextStyles.caption(),
                    ),
                    const SizedBox(height: 14),
                    _SelecteurDeRole(
                      valeur: _type,
                      actif: !_enCours,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: _images.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LigneDImage(
                    image: _images[i],
                    actif: !_enCours,
                  ),
                ),
              ),
              if (_echecs.isNotEmpty) _BlocDEchecs(echecs: _echecs),
              _PiedDImport(
                enCours: _enCours,
                traitees: _traitees,
                total: _images.length,
                onImporter: _importer,
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================
// SELECTEUR DE ROLE (applique a tout le lot)
// =============================================================

class _SelecteurDeRole extends StatelessWidget {
  const _SelecteurDeRole({
    required this.valeur,
    required this.actif,
    required this.onChanged,
  });

  final CardType valeur;
  final bool actif;
  final ValueChanged<CardType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CardType>(
      segments: [
        for (final t in CardType.values)
          ButtonSegment(value: t, label: Text(t.label)),
      ],
      selected: {valeur},
      onSelectionChanged:
          actif ? (s) => onChanged(s.first) : null,
      showSelectedIcon: false,
    );
  }
}

// =============================================================
// LIGNE D'IMAGE : apercu + libelle editable
// =============================================================

class _LigneDImage extends StatelessWidget {
  const _LigneDImage({required this.image, required this.actif});

  final _ImageAImporter image;
  final bool actif;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            // FutureBuilder : l'apercu se charge sans bloquer la
            // construction de la liste. Sur cinquante images, lire
            // tous les octets d'un coup ferait sauter l'ouverture
            // de la feuille.
            child: FutureBuilder<Uint8List>(
              future: image.fichier.readAsBytes(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return Container(color: AppColors.surface2);
                }
                return Image.memory(snap.data!, fit: BoxFit.cover);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: image.libelle,
            enabled: actif,
            decoration: const InputDecoration(
              labelText: 'Libelle',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// RECAPITULATIF DES ECHECS
// =============================================================

class _BlocDEchecs extends StatelessWidget {
  const _BlocDEchecs({required this.echecs});

  final List<String> echecs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${echecs.length} image(s) non importee(s)',
            style: AppTextStyles.caption()
                .copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 6),
          // On borne l'affichage : au-dela de cinq, la liste
          // deborderait et la cause est de toute facon la meme.
          for (final e in echecs.take(5))
            Text('- $e', style: AppTextStyles.caption()),
          if (echecs.length > 5)
            Text('- et ${echecs.length - 5} autre(s)...',
                style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

// =============================================================
// PIED : progression + bouton
// =============================================================

class _PiedDImport extends StatelessWidget {
  const _PiedDImport({
    required this.enCours,
    required this.traitees,
    required this.total,
    required this.onImporter,
  });

  final bool enCours;
  final int traitees;
  final int total;
  final VoidCallback onImporter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          if (enCours) ...[
            LinearProgressIndicator(
              value: total == 0 ? null : traitees / total,
              backgroundColor: AppColors.surface2,
              color: AppColors.brand,
            ),
            const SizedBox(height: 8),
            Text('$traitees / $total', style: AppTextStyles.caption()),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enCours ? null : onImporter,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(enCours
                  ? 'Import en cours...'
                  : 'Importer $total carte(s)'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
