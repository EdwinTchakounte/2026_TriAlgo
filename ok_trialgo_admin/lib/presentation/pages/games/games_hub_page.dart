// =============================================================
// FICHIER : games_hub_page.dart
// ROLE    : Hub d'entree post-login. Liste des jeux + creer
// =============================================================
//
// Apres login admin, on arrive ici. C'est la VITRINE :
//   - Liste de tous les jeux existants (cards verticales)
//   - Bouton "Nouveau jeu" en haut a droite
//   - Bouton "logout"
//
// Cliquer sur un jeu  :
//   1. set selectedGameProvider
//   2. reset wizardProvider a setup
//   3. push WizardShell
//
// Etat vide (aucun jeu) :
//   - Affiche un EmptyState avec CTA "Creer mon premier jeu"
//
// Responsive : sur mobile 1 colonne, sur tablette 2 colonnes via
// Breakpoints.gridColumns. Pour la simplicite on garde 1 colonne
// partout (les cards ont du contenu vertical, c'est plus lisible).
// =============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/game.dart';
import '../../providers/auth_provider.dart';
import '../../providers/games_provider.dart';
import '../admin/codes_page.dart';
import '../admin/users_page.dart';
import '../../providers/music_provider.dart';
import '../../providers/wizard_provider.dart';
import '../../widgets/app_logo.dart';
import '../wizard/wizard_shell.dart';
import 'create_game_sheet.dart';

class GamesHubPage extends ConsumerWidget {
  const GamesHubPage({super.key});

  // Selectionne un jeu et navigue vers le wizard.
  void _openWizardFor(BuildContext context, WidgetRef ref, Game game) {
    ref.read(selectedGameProvider.notifier).state = game;
    ref.read(wizardProvider.notifier).reset();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WizardShell()),
    );
  }

  // Ouvre le sheet de creation, et si OK ouvre direct le wizard.
  Future<void> _createAndOpen(BuildContext context, WidgetRef ref) async {
    final game = await CreateGameSheet.show(context);
    if (game != null && context.mounted) {
      _openWizardFor(context, ref, game);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gamesProvider);
    final profile = ref.watch(authProvider).profile;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        // Logo a gauche du titre : rappelle l'identite TRIALGO
        // sans encombrer la barre (taille compacte 34px).
        title: Row(
          children: [
            const AppLogo(size: AppLogoSize.compact, radius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bonjour ${profile?.username ?? "Admin"}',
                    style: AppTextStyles.pageTitle().copyWith(fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Choisissez un jeu ou creez-en un nouveau',
                    style: AppTextStyles.caption(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Toggle musique de fond.
          // - musicProvider est async (lit SharedPreferences au boot)
          // - on watch().valueOrNull ; si encore null on affiche un
          //   icone neutre pour eviter un flicker
          _MusicToggleButton(),
          // Administration : codes d'activation et comptes.
          // Regroupes dans un menu plutot qu'en icones separees :
          // ce sont des ecrans rarement utilises, la barre doit
          // rester lisible sur un telephone.
          const _AdminMenuButton(),
          IconButton(
            tooltip: 'Se deconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createAndOpen(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau jeu'),
        backgroundColor: AppColors.brand,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(gamesProvider.notifier).refresh(),
        // gamesAsync.when : 3 etats explicites pour UX claire.
        child: gamesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: '$e', onRetry: () {
            ref.read(gamesProvider.notifier).refresh();
          }),
          data: (games) {
            if (games.isEmpty) {
              return ListView(
                // ListView pour permettre quand meme le pull-to-refresh.
                children: [
                  const SizedBox(height: 80),
                  // Empty state avec CTA principal.
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Logo en hero : presence forte sur empty state,
                          // halo brand pour amplifier le cote neon studio.
                          const AppLogo(
                            size: AppLogoSize.hero,
                            glow: true,
                            radius: 16,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Aucun jeu pour l\'instant',
                            style: AppTextStyles.sectionTitle(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Creez votre premier jeu pour commencer a importer des cartes et composer des fusions.',
                            style: AppTextStyles.caption(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 260,
                            child: ElevatedButton.icon(
                              onPressed: () => _createAndOpen(context, ref),
                              icon: const Icon(Icons.add),
                              label: const Text('Creer mon premier jeu'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            // Liste : chaque jeu dans une card.
            return ResponsiveLayout(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final g in games) ...[
                    _GameCard(
                      game: g,
                      onTap: () => _openWizardFor(context, ref, g),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Espace bas pour ne pas etre cache par le FAB.
                  const SizedBox(height: 96),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================
// _MusicToggleButton : bouton AppBar pour activer/desactiver
// la musique de fond. Persistee via shared_preferences.
// =============================================================
class _MusicToggleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(musicProvider).valueOrNull ?? false;
    return IconButton(
      tooltip: enabled ? 'Couper la musique' : 'Activer la musique',
      icon: Icon(enabled ? Icons.music_note : Icons.music_off),
      // Couleur brand quand active : retour visuel immediat.
      color: enabled ? AppColors.brand : AppColors.textSecondary,
      onPressed: () => ref.read(musicProvider.notifier).toggle(),
    );
  }
}

// =============================================================
// _GameCard : carte cliquable representant un jeu
// =============================================================
class _GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const _GameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      // Splash subtil : feedback tactile sans effet de "claquage".
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: AppColors.brand.withValues(alpha: 0.06),
        highlightColor: AppColors.brand.withValues(alpha: 0.03),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            // Ombre portee sombre : sur canvas anthracite elle
            // "decolle" subtilement la card du fond (profondeur).
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar : double cercle (halo + dot central) pour
              // un look plus raffine que le simple carre colore.
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.brand.withValues(alpha: 0.28),
                            AppColors.brand.withValues(alpha: 0.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.35),
                        ),
                        boxShadow: AppColors.glow(AppColors.brand, strength: 0.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        game.name.isNotEmpty
                            ? game.name.characters.first.toUpperCase()
                            : '?',
                        style: AppTextStyles.pageTitle().copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            game.name,
                            style: AppTextStyles.sectionTitle(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!game.isActive) ...[
                          const SizedBox(width: 8),
                          // Badge "inactif" : signale visuellement que
                          // ce jeu n'est plus expose aux joueurs.
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'inactif',
                              style: AppTextStyles.caption().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (game.description != null &&
                        game.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        game.description!,
                        style: AppTextStyles.caption(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (game.theme != null && game.theme!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${game.theme}',
                          style: AppTextStyles.caption().copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// _ErrorView : ecran d'erreur avec bouton retry
// =============================================================
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
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger les jeux',
              style: AppTextStyles.sectionTitle(),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTextStyles.caption(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// _AdminMenuButton : acces aux ecrans d'administration
// =============================================================
// Les codes d'activation et les comptes utilisateurs ne relevent
// pas du cycle "creer un jeu" que porte le reste de cet ecran :
// on les sort du flux principal plutot que de les melanger aux
// cartes de jeux.
// =============================================================

enum _DestinationAdmin { codes, comptes }

class _AdminMenuButton extends StatelessWidget {
  const _AdminMenuButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DestinationAdmin>(
      tooltip: 'Administration',
      icon: const Icon(Icons.tune),
      onSelected: (destination) {
        final page = switch (destination) {
          _DestinationAdmin.codes => const CodesPage(),
          _DestinationAdmin.comptes => const UsersPage(),
        };
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        );
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _DestinationAdmin.codes,
          child: ListTile(
            leading: Icon(Icons.confirmation_number_outlined),
            title: Text('Codes d\'activation'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: _DestinationAdmin.comptes,
          child: ListTile(
            leading: Icon(Icons.people_outline),
            title: Text('Comptes utilisateurs'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
