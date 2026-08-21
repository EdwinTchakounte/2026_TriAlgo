// =============================================================
// FICHIER : cards_page.dart
// ROLE    : Liste + upload + edition des cartes du jeu courant
// =============================================================
//
// Layout :
//   - AppBar du dashboard (de HomePage)
//   - Filtre par type (Tous / Émettrice / Câble / Réceptrice)
//   - Grille reactive des cartes (CardThumbnail)
//   - FAB "+" : ouvre le sheet d'ajout de carte
//
// L'ajout d'une carte enchaine :
//   1. image_picker (galerie)
//   2. saisie label + type
//   3. upload Storage
//   4. INSERT cards
//   5. refresh provider => grille mise a jour
// =============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../data/models/card.dart';
import '../../data/models/card_type.dart';
import '../providers/cards_provider.dart';
import '../providers/games_provider.dart';
import '../providers/repositories_provider.dart';
import '../widgets/card_thumbnail.dart';

class CardsPage extends ConsumerStatefulWidget {
  const CardsPage({super.key});

  @override
  ConsumerState<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends ConsumerState<CardsPage> {
  // null = "Tous". Sinon filtre cote client la liste deja chargee.
  CardType? _filter;

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(cardsProvider);
    final selectedGame = ref.watch(selectedGameProvider);

    return Scaffold(
      body: Column(
        children: [
          // Bandeau de filtres en haut.
          _FilterBar(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const Divider(height: 1),
          // Liste reactive.
          Expanded(
            child: cardsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: 'Erreur de chargement : $e',
                onRetry: () => ref.read(cardsProvider.notifier).refresh(),
              ),
              data: (cards) {
                final filtered = _filter == null
                    ? cards
                    : cards.where((c) => c.type == _filter).toList();
                if (filtered.isEmpty) {
                  return _EmptyState(filter: _filter);
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(cardsProvider.notifier).refresh(),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final card = filtered[index];
                      return CardThumbnail(
                        card: card,
                        onTap: () => _openEditSheet(context, card),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Le bouton ne doit etre actif que si un jeu est selectionne.
        onPressed: selectedGame == null ? null : _openCreateSheet,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Nouvelle carte'),
      ),
    );
  }

  // =========================================================
  // Ouvre le bottom-sheet de creation
  // =========================================================
  Future<void> _openCreateSheet() async {
    final result = await showModalBottomSheet<_NewCardData>(
      context: context,
      isScrollControlled: true,
      // Hauteur dynamique : on laisse 90% pour clavier + image preview.
      builder: (_) => const _CreateCardSheet(),
    );
    if (result == null || !mounted) return;

    // On a recu : bytes + label + type. On declenche l'upload.
    await _performCreate(result);
  }

  // =========================================================
  // _performCreate : upload Storage + INSERT cards + refresh
  // =========================================================
  Future<void> _performCreate(_NewCardData data) async {
    final messenger = ScaffoldMessenger.of(context);
    final game = ref.read(selectedGameProvider);
    if (game == null) return;

    final repo = ref.read(cardRepositoryProvider);

    // Affiche un dialog modal de progression. On le ferme dans
    // tous les cas (success ou erreur) via Navigator.pop.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Upload image
      final url = await repo.uploadImage(
        bytes: data.bytes,
        originalName: data.filename,
        contentType: data.contentType,
      );
      // 2. Insert row
      await repo.createCard(
        gameId: game.id,
        label: data.label,
        imagePath: url,
        type: data.type,
      );
      // 3. Refresh la liste
      await ref.read(cardsProvider.notifier).refresh();

      if (!mounted) return;
      Navigator.pop(context); // ferme le loader
      messenger.showSnackBar(
        const SnackBar(content: Text('Carte ajoutee')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur upload : $e')),
      );
    }
  }

  // =========================================================
  // _openEditSheet : edition / suppression d'une carte existante
  // =========================================================
  Future<void> _openEditSheet(BuildContext ctx, GameCard card) async {
    final messenger = ScaffoldMessenger.of(ctx);
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => _EditCardSheet(
        card: card,
        onSave: (newLabel, newType) async {
          await ref.read(cardRepositoryProvider).updateCard(
                id: card.id,
                label: newLabel,
                type: newType,
              );
          await ref.read(cardsProvider.notifier).refresh();
          if (!ctx.mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('Carte mise a jour')),
          );
        },
        onDelete: () async {
          // Confirmation explicite (suppression irreversible).
          final ok = await showDialog<bool>(
            context: ctx,
            builder: (_) => AlertDialog(
              title: const Text('Supprimer cette carte ?'),
              content: const Text(
                  'Si la carte est utilisee dans un node, la suppression echouera.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          );
          if (ok != true) return;
          try {
            await ref.read(cardRepositoryProvider).deleteCard(card);
            await ref.read(cardsProvider.notifier).refresh();
            if (!ctx.mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Carte supprimee')),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Suppression impossible : $e')),
            );
          }
        },
      ),
    );
  }
}

// =============================================================
// _FilterBar : chips horizontaux pour filtrer par type
// =============================================================
class _FilterBar extends StatelessWidget {
  final CardType? value;
  final ValueChanged<CardType?> onChanged;

  const _FilterBar({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _chip(context, label: 'Tous', selected: value == null, onTap: () => onChanged(null)),
          const SizedBox(width: 8),
          for (final t in CardType.values) ...[
            _chip(context,
                label: t.label,
                selected: value == t,
                onTap: () => onChanged(t)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext ctx,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// =============================================================
// _EmptyState : message quand la grille est vide
// =============================================================
class _EmptyState extends StatelessWidget {
  final CardType? filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = filter == null
        ? 'Aucune carte. Tapez "+" pour en creer une.'
        : 'Aucune carte de type ${filter!.label}.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.collections_outlined, size: 64, color: Colors.black26),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reessayer')),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _NewCardData : DTO retourne par _CreateCardSheet
// =============================================================
class _NewCardData {
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final String label;
  final CardType type;

  _NewCardData({
    required this.bytes,
    required this.filename,
    required this.contentType,
    required this.label,
    required this.type,
  });
}

// =============================================================
// _CreateCardSheet : formulaire de creation
// =============================================================
class _CreateCardSheet extends StatefulWidget {
  const _CreateCardSheet();

  @override
  State<_CreateCardSheet> createState() => _CreateCardSheetState();
}

class _CreateCardSheetState extends State<_CreateCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  CardType _type = CardType.emettrice;

  // Etat de l'image picked.
  XFile? _picked;
  Uint8List? _bytes;

  // image_picker singleton.
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    // Source.gallery par defaut. On limite la qualite a 80% pour
    // reduire la taille (evite d'envoyer des photos 10MB).
    final f = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() {
      _picked = f;
      _bytes = bytes;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_bytes == null || _picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une image')),
      );
      return;
    }
    // Determine le content-type a partir du nom (image/jpeg, image/png).
    final mime = lookupMimeType(_picked!.name) ?? 'image/jpeg';

    Navigator.pop(
      context,
      _NewCardData(
        bytes: _bytes!,
        filename: _picked!.name,
        contentType: mime,
        label: _labelCtrl.text.trim(),
        type: _type,
      ),
    );
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Gestion clavier : viewInsets.bottom pousse le sheet.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nouvelle carte',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              // Zone image (preview ou bouton "Choisir").
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: _bytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_bytes!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40),
                            SizedBox(height: 8),
                            Text('Toucher pour choisir une image'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelCtrl,
                decoration: const InputDecoration(labelText: 'Libelle'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Libelle requis' : null,
              ),
              const SizedBox(height: 12),
              // Selecteur de type.
              DropdownButtonFormField<CardType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: CardType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Uploader la carte'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// _EditCardSheet : modification rapide d'une carte existante
// =============================================================
class _EditCardSheet extends StatefulWidget {
  final GameCard card;
  final Future<void> Function(String label, CardType type) onSave;
  final Future<void> Function() onDelete;

  const _EditCardSheet({
    required this.card,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditCardSheet> createState() => _EditCardSheetState();
}

class _EditCardSheetState extends State<_EditCardSheet> {
  late TextEditingController _labelCtrl;
  late CardType _type;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.card.label);
    _type = widget.card.type;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Editer la carte',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              decoration: const InputDecoration(labelText: 'Libelle'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CardType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: CardType.values
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onDelete();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Supprimer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.onSave(_labelCtrl.text.trim(), _type);
                    },
                    child: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
