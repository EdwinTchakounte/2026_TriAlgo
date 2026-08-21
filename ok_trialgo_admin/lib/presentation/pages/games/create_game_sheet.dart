// =============================================================
// FICHIER : create_game_sheet.dart
// ROLE    : ModalBottomSheet pour creer un nouveau jeu
// =============================================================
//
// Pourquoi un bottom sheet et pas une page entiere ?
// - L'admin est sur "Games Hub", il veut creer un jeu rapidement
//   sans perdre le contexte de la liste.
// - Sur mobile, une feuille modale est plus naturelle qu'une
//   navigation vers une nouvelle page.
// - showModalBottomSheet sur grand ecran s'adapte automatiquement.
//
// On collecte name (requis), description (optionnel), theme
// (optionnel). Apres creation OK, on POP le sheet en retournant
// le nouveau Game pour que la page parent puisse l'auto-selectionner.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/game.dart';
import '../../providers/games_provider.dart';

class CreateGameSheet extends ConsumerStatefulWidget {
  const CreateGameSheet({super.key});

  // Helper pour ouvrir le sheet ailleurs. Renvoie le Game cree
  // (ou null si l'admin annule).
  static Future<Game?> show(BuildContext context) {
    return showModalBottomSheet<Game>(
      context: context,
      isScrollControlled: true, // important : laisse place clavier
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateGameSheet(),
    );
  }

  @override
  ConsumerState<CreateGameSheet> createState() => _CreateGameSheetState();
}

class _CreateGameSheetState extends ConsumerState<CreateGameSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _themeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _themeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final game = await ref.read(gamesProvider.notifier).createGame(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          theme: _themeCtrl.text.trim().isEmpty
              ? null
              : _themeCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (game == null) {
      // Erreur cote serveur : on affiche un snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creation impossible. Reessayez.')),
      );
      return;
    }
    // Pop avec la valeur creee pour que le parent l'utilise.
    Navigator.of(context).pop(game);
  }

  @override
  Widget build(BuildContext context) {
    // Padding bas pour ne pas etre cache par le clavier mobile.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pille de drag en haut (style bottom sheet iOS).
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

              Text('Nouveau jeu', style: AppTextStyles.pageTitle()),
              const SizedBox(height: 4),
              Text(
                'Donnez un nom et un theme. Les cartes et trios viendront ensuite.',
                style: AppTextStyles.caption(),
              ),

              const SizedBox(height: 20),

              // NAME
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom du jeu',
                  hintText: 'TRIALGO Savane',
                  prefixIcon: Icon(Icons.gamepad_outlined),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Nom requis';
                  if (s.length < 3) return 'Au moins 3 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // DESCRIPTION
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  hintText: 'Le jeu de base avec les animaux de la savane',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 12),

              // THEME
              TextFormField(
                controller: _themeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Theme (optionnel)',
                  hintText: 'savane',
                  prefixIcon: Icon(Icons.palette_outlined),
                ),
              ),

              const SizedBox(height: 24),

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
                    : const Icon(Icons.add),
                label: const Text('Creer le jeu'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
