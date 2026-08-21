// =============================================================
// FICHIER : home_page.dart
// ROLE    : Shell du dashboard (3 onglets : Cards / Trios / Graph)
// =============================================================
//
// La HomePage est l'ecran principal apres connexion admin. Elle
// expose 3 zones de travail via une BottomNavigationBar :
//   - Cards : gestion des cartes (upload + liste + edit)
//   - Trios : creation de trios (E + C => R) et nodes
//   - Graph : visualisation arbre + preview
//
// Au demarrage, on charge automatiquement le premier jeu actif
// pour eviter un dropdown vide. L'utilisateur peut switcher de
// jeu via un dropdown dans l'AppBar.
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/game.dart';
import '../providers/auth_provider.dart';
import '../providers/games_provider.dart';
import 'cards_page.dart';
import 'graph_page.dart';
import 'trios_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // Index de l'onglet courant. 0=Cards, 1=Trios, 2=Graph.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesListProvider);
    final selectedGame = ref.watch(selectedGameProvider);

    // Auto-selection du premier jeu si aucun n'est selectionne.
    // listen() ne re-build pas le widget quand l'AsyncValue change,
    // mais on l'utilise dans build pour la simplicite (Riverpod
    // garantit qu'on n'a pas de side-effect en boucle).
    gamesAsync.whenData((games) {
      if (selectedGame == null && games.isNotEmpty) {
        // Schedule pour ne pas modifier l'etat pendant un build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(selectedGameProvider.notifier).state = games.first;
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('TRIALGO Dashboard'),
            const SizedBox(width: 16),
            // Dropdown de selection du jeu (Savane, Ocean...).
            // Affiche un placeholder tant que la liste charge.
            Expanded(
              child: gamesAsync.when(
                loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Text('Erreur: $e',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
                data: (games) => _GameDropdown(
                  games: games,
                  selected: selectedGame,
                  onChanged: (g) {
                    ref.read(selectedGameProvider.notifier).state = g;
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Deconnexion',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      // IndexedStack conserve l'etat des trois onglets meme
      // quand on change de tab (les listes restent chargees, le
      // formulaire trio garde ses valeurs).
      body: IndexedStack(
        index: _tab,
        children: const [
          CardsPage(),
          TriosPage(),
          GraphPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.image_outlined),
            selectedIcon: Icon(Icons.image),
            label: 'Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_outlined),
            selectedIcon: Icon(Icons.link),
            label: 'Trios',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Graph',
          ),
        ],
      ),
    );
  }
}

// =============================================================
// _GameDropdown : selecteur de jeu compact dans l'AppBar
// =============================================================
class _GameDropdown extends StatelessWidget {
  final List<Game> games;
  final Game? selected;
  final ValueChanged<Game?> onChanged;

  const _GameDropdown({
    required this.games,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return const Text('Aucun jeu',
          style: TextStyle(fontSize: 14, color: Colors.black54));
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<Game>(
        value: selected,
        isDense: true,
        // On affiche juste le nom dans l'AppBar pour rester compact.
        items: games
            .map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g.name, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
