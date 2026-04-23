// =============================================================
// FICHIER : lib/presentation/wireframes/t_home_page.dart
// ROLE   : Home refondue - hub principal du joueur
// COUCHE : Presentation > Wireframes
// =============================================================
//
// REFONTE (vs version precedente) :
// ---------------------------------
//   - Supprime : 3 cartes E+C=R decoratives (40% ecran non cliquables)
//   - Supprime : grille 2x2 de navigation redondante
//   - Supprime : auto-start musique (decide via settings)
//   - Ajoute   : streak badge (flamme + jours consecutifs)
//   - Ajoute   : hero card "JOUER" avec niveau, distance, stats
//   - Ajoute   : progress bar de progression dans la distance
//   - Ajoute   : section "Decouvre" (Deck, Classement, Defi)
//   - Ajoute   : derniere partie avec etoiles et date
//
// LA HIERARCHIE EN 3 SECONDES :
// -----------------------------
//   1. Qui je suis (avatar + username + streak)
//   2. Combien de vies (ligne 2 du header)
//   3. Qu'est-ce que je joue (hero card)
//   4. Ou je vais (progress bar)
//   5. Quoi decouvrir (decouvre section)
//   6. Ce qui vient d'arriver (derniere partie)
//
// NAVIGATION :
// ------------
//   avatar tap      -> TProfilePage
//   settings icon   -> TSettingsPage
//   help icon       -> THelpPage
//   admin badge     -> TAdminPage (si email admin)
//   JOUER           -> TGameModePage (choix solo/collectif)
//   Deck card       -> TGalleryPage
//   Classement card -> TLeaderboardPage
//   Defi card       -> placeholder snackbar ("Bientot disponible")
//   Derniere partie -> placeholder pour historique futur
// =============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trialgo/core/constants/admin_constants.dart';
import 'package:trialgo/core/design_system/tokens/brand.dart';
import 'package:trialgo/core/design_system/tokens/colors.dart';
import 'package:trialgo/core/design_system/tokens/radius.dart';
import 'package:trialgo/core/design_system/tokens/spacing.dart';
import 'package:trialgo/core/design_system/tokens/typography.dart';
import 'package:trialgo/domain/entities/session_entity.dart';
import 'package:trialgo/presentation/providers/graph_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/widgets/core/app_badge.dart';
import 'package:trialgo/presentation/widgets/core/app_button.dart';
import 'package:trialgo/presentation/widgets/core/app_card.dart';
import 'package:trialgo/presentation/widgets/core/loading_state.dart';
import 'package:trialgo/presentation/widgets/core/page_scaffold.dart';
import 'package:trialgo/presentation/widgets/core/section_header.dart';
import 'package:trialgo/presentation/widgets/lives_refill_timer.dart';
import 'package:trialgo/presentation/widgets/user_avatar.dart';
import 'package:trialgo/presentation/wireframes/t_admin_page.dart';
import 'package:trialgo/presentation/wireframes/t_collective_mode_page.dart';
import 'package:trialgo/presentation/wireframes/t_gallery_page.dart';
import 'package:trialgo/presentation/wireframes/t_leaderboard_page.dart';
import 'package:trialgo/presentation/wireframes/t_level_map_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_profile_page.dart';
import 'package:trialgo/presentation/wireframes/t_settings_page.dart';


/// Home page refondue — hub principal du joueur.
class THomePage extends ConsumerStatefulWidget {
  const THomePage({super.key});

  @override
  ConsumerState<THomePage> createState() => _THomePageState();
}

class _THomePageState extends ConsumerState<THomePage>
    with TickerProviderStateMixin {

  /// Controller de flottement pour la mascotte en background.
  late final AnimationController _mascotFloat;

  /// Controller du shimmer qui traverse le bouton JOUER
  /// (loop infini 3s).
  late final AnimationController _shimmer;

  /// Controller du pulse du hero card (respiration du glow).
  late final AnimationController _heroPulse;

  /// Controller des particules dorees en fond (loop 1s).
  late final AnimationController _particles;

  /// Liste des particules dorees qui derivent sur la page.
  final List<_HomeParticle> _particleList = [];
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _mascotFloat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    // Shimmer du bouton JOUER : 3s pour une traversee, pause
    // implicite en mode "rapid sweep then wait" est geree par
    // Interval dans le build (translate 0 -> 1 en 30% du temps,
    // puis hors de l'ecran les 70% restants).
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Respiration du glow du hero : 1.5s aller, 1.5s retour.
    _heroPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Particules dorees : init 15 particules aleatoires.
    for (int i = 0; i < 15; i++) {
      _particleList.add(_HomeParticle.random(_rnd));
    }
    _particles = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(() {
        for (final p in _particleList) {
          p.update();
        }
      })
      ..repeat();

    // Recharger le profil au premier build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).reload();
    });
  }

  @override
  void dispose() {
    _mascotFloat.dispose();
    _shimmer.dispose();
    _heroPulse.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final pool = ref.watch(graphSyncServiceProvider).logicalNodes;

    // Si le graphe n'est pas encore pret, on attend.
    // En pratique, TGraphLoadingPage s'assure que c'est pret avant
    // d'arriver ici. Cette garde est juste defensive.
    if (pool == null) {
      return PageScaffold(
        child: LoadingState(message: TLocale.of(context)('common.loading')),
      );
    }

    // tablesPerDistance : compte de tables par distance, pour que
    // progressFor calcule la position du niveau courant.
    final tablesPerDistance = [
      pool.numberOfTables(1),
      pool.numberOfTables(2),
      pool.numberOfTables(3),
      pool.numberOfTables(4),
      pool.numberOfTables(5),
    ];
    final progress = profile.progressFor(tablesPerDistance);

    return PageScaffold(
      child: Stack(
        children: [
          // --- Layer 0 : motif de cartes E/C/R en fond ---
          // Couleur dore @ 12% pour une presence visible sans
          // envahir. Sensation "table de jeu" qui accroche l'oeil
          // sans concurrencer le contenu.
          Positioned.fill(
            child: CustomPaint(
              painter: _HomeCardPatternPainter(
                color: TColors.primaryVariant.withValues(alpha: 0.12),
              ),
            ),
          ),

          // --- Layer 1 : particules dorees qui derivent ---
          // 15 points lumineux qui flottent en permanence.
          // Donne "vie" a la page sans distraire du contenu
          // (opacity 0.1-0.35 selon particule, taille 1.5-4 px).
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HomeParticlePainter(
                  particles: _particleList,
                  repaint: _particles,
                ),
              ),
            ),
          ),

          // --- Layer 2 : mascotte flottante en background ---
          _buildBackgroundMascot(),

          // --- Layer 3 : contenu scrollable ---
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: TSpacing.lg,
              vertical: TSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(profile),
                const SizedBox(height: TSpacing.xl),
                _buildHeroCard(profile, progress),
                const SizedBox(height: TSpacing.md),
                _buildProgressBar(progress),
                const SizedBox(height: TSpacing.xxl),
                SectionHeader(title: TLocale.of(context)('home.discover')),
                _buildDiscoverRow(profile),
                const SizedBox(height: TSpacing.lg),
                if (profile.lastSession != null) ...[
                  SectionHeader(
                      title: TLocale.of(context)('home.last_game_section')),
                  _buildLastSessionCard(profile.lastSession!),
                ],
                const SizedBox(height: TSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // WIDGET : mascotte de fond flottante
  // =============================================================

  /// Logo TRIALGO flottant en bas-droit en decor de la home
  /// (c'est le brand, pas la mascotte narrative).
  /// Opacity 18% pour un fond present sans distraire.
  Widget _buildBackgroundMascot() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: AnimatedBuilder(
          animation: _mascotFloat,
          builder: (context, child) {
            final t = _mascotFloat.value;
            final offsetY = math.sin(t * math.pi) * 8;
            return Transform.translate(
              offset: Offset(20, -40 + offsetY),
              child: Opacity(
                opacity: 0.18,
                child: child,
              ),
            );
          },
          child: Image.asset(
            MockData.logo,
            height: 220,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : HEADER sur 2 lignes
  // =============================================================
  // Ligne 1 : avatar + username + streak      | settings + help
  // Ligne 2 : niveau + points + vies + refill
  // =============================================================

  Widget _buildHeader(AppProfileState profile) {
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    final isAdmin = AdminConstants.isAdmin();

    return Column(
      children: [
        // --- Ligne 1 ---
        Row(
          children: [
            // Avatar cliquable -> profil.
            // Avatar icone thematique (gradient + icone), meme systeme
            // que la profile page + galerie. Refletee des que le user
            // change d'avatar (via ref.watch(profileProvider)).
            GestureDetector(
              onTap: () => _navigateTo(const TProfilePage()),
              child: UserAvatar(
                avatarId: profile.avatarId,
                username: profile.username,
                size: 44,
              ),
            ),
            const SizedBox(width: TSpacing.md),

            // Username + streak.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.username,
                    style: TTypography.titleLg(color: colors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: TSpacing.xxs),
                  _buildStreak(profile.streak),
                ],
              ),
            ),

            // Admin badge (si applicable).
            if (isAdmin) ...[
              IconButton(
                onPressed: () => _navigateTo(const TAdminPage()),
                icon: Icon(Icons.admin_panel_settings_outlined,
                    color: TColors.primary),
                tooltip: 'Administration',
              ),
            ],

            // Settings.
            IconButton(
              onPressed: () => _navigateTo(const TSettingsPage()),
              icon: Icon(Icons.settings_outlined,
                  color: colors.textSecondary),
              tooltip: 'Parametres',
            ),
          ],
        ),

        const SizedBox(height: TSpacing.md),

        // --- Ligne 2 : stats compactes sur 2 lignes pour eviter
        // l'overflow avec 4 chips + 5 coeurs + timer sur un ecran
        // etroit (360px). Ligne 1 : progression (niveau + points).
        // Ligne 2 : economie (etoiles + vies cliquables). ---
        AppCard.glass(
          padding: const EdgeInsets.symmetric(
            horizontal: TSpacing.md,
            vertical: TSpacing.md,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _StatChip(
                    icon: Icons.flash_on_rounded,
                    value: 'N${profile.level}',
                    label: tr('home.stat_level'),
                    color: TColors.info,
                  ),
                  _buildVerticalDivider(),
                  _StatChip(
                    icon: Icons.paid_rounded,
                    value: '${profile.score}',
                    label: tr('home.stat_points'),
                    color: TColors.primaryVariant,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TSpacing.sm,
                ),
                child: Container(
                  height: 1,
                  color: colors.borderSubtle,
                ),
              ),
              Row(
                children: [
                  // Etoiles : wallet transverse, compteur + countdown.
                  _StarsChip(
                    stars: profile.stars,
                    starsMax: profile.starsMax,
                    nextStarAt: profile.nextStarAt,
                    label: tr('home.stat_stars'),
                  ),
                  _buildVerticalDivider(),
                  // Vies : cliquable pour ouvrir le dialog d'echange
                  // si vies < max. Timer de refill sous les coeurs.
                  Expanded(
                    child: InkWell(
                      onTap: profile.lives < profile.maxLives
                          ? () => _openExchangeDialog(context)
                          : null,
                      borderRadius: TRadius.smAll,
                      child: Column(
                        children: [
                          _LivesInline(
                            lives: profile.lives,
                            maxLives: profile.maxLives,
                          ),
                          const SizedBox(height: TSpacing.xxs),
                          const LivesRefillTimer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Ouvre le dialog d'echange etoiles -> vie.
  /// Rafraichit d'abord la regen pour que le stock affiche soit a jour
  /// (utile si le joueur reste longtemps sur la home sans reload).
  Future<void> _openExchangeDialog(BuildContext ctx) async {
    await ref.read(profileProvider.notifier).refreshStars();
    if (!context.mounted) return;
    await showDialog<void>(
      context: ctx,
      builder: (_) => const _StarsExchangeDialog(),
    );
  }

  Widget _buildVerticalDivider() {
    final colors = TColors.of(context);
    return Container(
      width: 1,
      height: 28,
      color: colors.borderSubtle,
      margin: const EdgeInsets.symmetric(horizontal: TSpacing.sm),
    );
  }

  Widget _buildStreak(int streak) {
    final tr = TLocale.of(context);
    final colors = TColors.of(context);
    if (streak == 0) {
      return Row(
        children: [
          Icon(Icons.local_fire_department_outlined,
              size: 14, color: colors.textTertiary),
          const SizedBox(width: TSpacing.xxs),
          Text(
            tr('home.streak_start'),
            style: TTypography.labelMd(color: colors.textTertiary),
          ),
        ],
      );
    }
    // Serie active : flamme orange + nombre + "jour(s)" localise.
    final unit =
        streak > 1 ? tr('home.streak_days') : tr('home.streak_day');
    return Row(
      children: [
        const Icon(Icons.local_fire_department_rounded,
            size: 16, color: TColors.primaryVariant),
        const SizedBox(width: TSpacing.xxs),
        Text(
          '$streak $unit',
          style: TTypography.labelLg(color: TColors.primaryVariant),
        ),
      ],
    );
  }

  // =============================================================
  // WIDGET : HERO CARD (le CTA principal JOUER)
  // =============================================================

  Widget _buildHeroCard(AppProfileState profile, LevelProgress progress) {
    final tr = TLocale.of(context);
    // Hero "carte a collectionner" avec glow pulsant (respiration).
    // La BoxShadow est modulee par _heroPulse : le blur change de
    // 12 a 24, l'opacite de 0.35 a 0.55. Effet "carte magique" vivant.
    return AnimatedBuilder(
      animation: _heroPulse,
      builder: (context, child) {
        final t = _heroPulse.value;
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: TBrand.primary,
            borderRadius: TRadius.xxlAll,
            boxShadow: [
              BoxShadow(
                color: TColors.primary.withValues(alpha: 0.35 + 0.2 * t),
                blurRadius: 12 + 12 * t,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(TSpacing.xl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              TColors.primary.withValues(alpha: 0.92),
              TColors.primaryVariant.withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Ligne titre + badge distance ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NIVEAU ${profile.level}',
                style: TTypography.displaySm(color: Colors.white),
              ),
              AppBadge(
                text: 'D${progress.distance}',
                solid: true,
                tone: AppBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: TSpacing.sm),

          // --- Description stats (questions, temps, seuil) ---
          Text(
            '${progress.questions} ${tr('home.questions')} · '
            '${progress.turnTimeSeconds}${tr('home.turn_seconds')} · '
            '${tr('home.threshold')} ${progress.threshold}',
            style: TTypography.bodyMd(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: TSpacing.xl),

          // --- Bouton JOUER ---
          // Bouton blanc translucide pour ressortir sur le gradient
          // orange (inverse des autres AppButton.primary qui sont deja
          // orange eux-memes).
          GestureDetector(
            // JOUER = direct vers la carte des parties (level map),
            // ou l'utilisateur choisit quel niveau jouer (avec vue
            // deblocage / etoiles / progression).
            onTap: () => _navigateTo(const TLevelMapPage()),
            child: ClipRRect(
              // ClipRRect pour que le shimmer ne deborde pas du bouton.
              borderRadius: TRadius.lgAll,
              child: Stack(
                children: [
                  // --- Bouton blanc de base ---
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: TRadius.lgAll,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            size: 28, color: TColors.primary),
                        const SizedBox(width: TSpacing.sm),
                        Text(
                          'JOUER',
                          style: TTypography.titleLg(color: TColors.primary),
                        ),
                        const SizedBox(width: TSpacing.sm),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 20, color: TColors.primary),
                      ],
                    ),
                  ),

                  // --- Shimmer overlay ---
                  // Bande diagonale blanche translucide qui traverse
                  // le bouton de gauche a droite toutes les 3s.
                  // Pause implicite : le shimmer ne traverse visible-
                  // ment qu'entre t=0 et t=0.35 (~1s), puis reste hors
                  // ecran les 2s restantes (effet "pulse rare").
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _shimmer,
                      builder: (context, _) {
                        final t = _shimmer.value;
                        // Map 0-0.35 -> translation de -1 a 1 (horiz)
                        // Hors de cet intervalle, la bande est hors ecran.
                        final double dx;
                        if (t < 0.35) {
                          dx = (t / 0.35) * 2 - 1;
                        } else {
                          dx = 1;
                        }
                        return FractionalTranslation(
                          translation: Offset(dx, 0),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.6),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.3, 0.5, 0.7],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // =============================================================
  // WIDGET : PROGRESS BAR de la distance courante
  // =============================================================

  Widget _buildProgressBar(LevelProgress progress) {
    final tr = TLocale.of(context);
    final colors = TColors.of(context);
    final remaining = progress.remainingInDistance;
    final nextDistance = progress.distance + 1;

    // Label explicite en fonction de l'etat, traduit.
    // Format des templates : {n} remplace par remaining, {d} par nextDistance.
    final String label;
    if (remaining == 0) {
      label = tr('home.next_is_distance').replaceAll('{d}', '$nextDistance');
    } else if (remaining == 1) {
      label = tr('home.remaining_one').replaceAll('{d}', '$nextDistance');
    } else {
      label = tr('home.remaining_many')
          .replaceAll('{n}', '$remaining')
          .replaceAll('{d}', '$nextDistance');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar custom (pas LinearProgressIndicator qui est trop fin).
        ClipRRect(
          borderRadius: TRadius.smAll,
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 8,
            backgroundColor: colors.surface,
            valueColor: const AlwaysStoppedAnimation(TColors.primary),
          ),
        ),
        const SizedBox(height: TSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TTypography.labelMd(color: colors.textSecondary),
            ),
            Text(
              '${progress.currentInDistance}/${progress.totalInDistance}',
              style: TTypography.labelMd(color: colors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  // =============================================================
  // WIDGET : SECTION "DECOUVRE" (3 cartes)
  // =============================================================

  Widget _buildDiscoverRow(AppProfileState profile) {
    final tr = TLocale.of(context);
    final unlockedCount = profile.unlockedCards.length;

    return Row(
      children: [
        Expanded(
          child: _DiscoverCard(
            icon: Icons.collections_bookmark_outlined,
            title: tr('home.card_deck'),
            value: '$unlockedCount ${tr('home.card_deck_count')}',
            color: TColors.info,
            onTap: () => _navigateTo(const TGalleryPage()),
          ),
        ),
        const SizedBox(width: TSpacing.sm),
        Expanded(
          child: _DiscoverCard(
            icon: Icons.emoji_events_outlined,
            title: tr('home.card_ranking'),
            value: tr('home.card_ranking_value'),
            color: TColors.primaryVariant,
            onTap: () => _navigateTo(const TLeaderboardPage()),
          ),
        ),
        const SizedBox(width: TSpacing.sm),
        Expanded(
          child: _DiscoverCard(
            icon: Icons.groups_rounded,
            title: tr('home.card_collective'),
            value: tr('home.card_collective_sub'),
            color: TColors.success,
            onTap: () => _navigateTo(const TCollectiveModePage()),
          ),
        ),
      ],
    );
  }

  // =============================================================
  // WIDGET : DERNIERE PARTIE
  // =============================================================

  Widget _buildLastSessionCard(SessionEntity session) {
    final colors = TColors.of(context);
    final ago = _formatRelativeDate(session.playedAt);

    return AppCard.glass(
      child: Row(
        children: [
          // Icone circle avec check ou croix selon passed.
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: session.passed
                  ? Color.fromARGB(0x26, 102, 187, 106) // success tinted
                  : Color.fromARGB(0x26, 239, 83, 80),  // error tinted
            ),
            child: Icon(
              session.passed
                  ? Icons.check_rounded
                  : Icons.close_rounded,
              color: session.passed ? TColors.success : TColors.error,
            ),
          ),
          const SizedBox(width: TSpacing.md),

          // Texte principal : "Niv. X · 6/8"
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Niveau ${session.level} · '
                  '${session.correctAnswers}/${session.questionsTotal}',
                  style: TTypography.titleMd(color: colors.textPrimary),
                ),
                const SizedBox(height: TSpacing.xxs),
                Text(
                  ago,
                  style: TTypography.labelMd(color: colors.textTertiary),
                ),
              ],
            ),
          ),

          // Etoiles obtenues (0 a 3).
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final filled = i < session.starsEarned;
              return Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 18,
                color: filled
                    ? TColors.primaryVariant
                    : colors.borderStrong,
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Formate une date en "il y a X" lisible (approximatif).
  String _formatRelativeDate(DateTime played) {
    final now = DateTime.now();
    final diff = now.difference(played);
    if (diff.inMinutes < 1) return 'a l\'instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${played.day}/${played.month}/${played.year}';
  }

  // =============================================================
  // METHODE : _navigateTo
  // =============================================================
  // Helper pour pousser une route et recharger le profil au retour
  // (permet a la home de refleter des changements faits ailleurs).
  // =============================================================

  void _navigateTo(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) {
      // Au retour, on rafraichit le profil (score, vies, streak...).
      if (mounted) ref.read(profileProvider.notifier).reload();
    });
  }
}


// (Widget _AvatarCircle supprime : on utilise UserAvatar partout
// pour un rendu coherent et refletable via profileProvider.)


// =============================================================
// WIDGET : _StatChip
// =============================================================
// Colonne icone + valeur + label utilisee dans la carte stats
// de la ligne 2 du header.
// =============================================================

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: TSpacing.xxs),
          Text(
            value,
            style: TTypography.numericSm(color: colors.textPrimary),
          ),
          Text(
            label,
            style: TTypography.labelSm(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}


// =============================================================
// WIDGET : _LivesInline
// =============================================================
// Affiche les vies sous forme de coeurs (comme dans l'ancien header),
// compact pour tenir dans la cellule stats.
// =============================================================

class _LivesInline extends StatelessWidget {
  final int lives;
  final int maxLives;

  const _LivesInline({required this.lives, required this.maxLives});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLives, (i) {
        final filled = i < lives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 14,
            color: filled
                ? TColors.error
                : TColors.of(context).borderDefault,
          ),
        );
      }),
    );
  }
}


// =============================================================
// WIDGET : _StarsChip
// =============================================================
// Affiche le wallet d'etoiles sous forme compacte : icone + valeur +
// plafond + petit countdown vers la prochaine etoile. Rentre dans
// la meme Row que les autres stats (Niveau, Points, Vies).
//
// Le countdown se met a jour chaque seconde via un StreamBuilder
// base sur un Ticker : pas besoin de passer par un AnimationController
// -> plus leger, pas de dispose a gerer.
// =============================================================

class _StarsChip extends StatefulWidget {
  final int stars;
  final int starsMax;
  final DateTime? nextStarAt;
  final String label;

  const _StarsChip({
    required this.stars,
    required this.starsMax,
    required this.nextStarAt,
    required this.label,
  });

  @override
  State<_StarsChip> createState() => _StarsChipState();
}

class _StarsChipState extends State<_StarsChip> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    // Ticker qui emet un int croissant chaque seconde, consommé
    // uniquement pour forcer un rebuild et rafraichir le countdown.
    _ticker = Stream<int>.periodic(
      const Duration(seconds: 1),
      (i) => i,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    return Expanded(
      child: StreamBuilder<int>(
        stream: _ticker,
        builder: (context, _) {
          final countdown = _formatCountdown(widget.nextStarAt);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ligne 1 : icone etoile + valeur + label.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded,
                      color: TColors.primary, size: 18),
                  const SizedBox(width: TSpacing.xxs),
                  Flexible(
                    child: Text(
                      '${widget.stars}/${widget.starsMax}',
                      style: TTypography.numericSm(color: colors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TSpacing.xxs),
              Text(
                widget.label,
                style: TTypography.labelSm(color: colors.textTertiary),
              ),
              // Countdown petit en dessous (visible uniquement si regen active).
              if (widget.nextStarAt != null)
                Text(
                  '+1 ${widget.label.toLowerCase()} · $countdown',
                  style: TTypography.labelSm(color: colors.textTertiary)
                      .copyWith(fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        },
      ),
    );
  }

  /// Retourne "mm:ss" avant la prochaine etoile, ou "--:--" si au plafond
  /// ou timestamp indisponible.
  String _formatCountdown(DateTime? nextAt) {
    if (nextAt == null) return '--:--';
    final diff = nextAt.difference(DateTime.now().toUtc());
    if (diff.isNegative) return '0:00';
    final mm = diff.inMinutes;
    final ss = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}


// =============================================================
// WIDGET : _StarsExchangeDialog
// =============================================================
// Dialog d'echange 10 etoiles -> 1 vie. Affiche le stock actuel
// d'etoiles et l'etat des vies. Le CTA est desactive si pas assez
// d'etoiles OU vies deja au max. Apres echange, la home page se
// rafraichit automatiquement (Riverpod listener).
// =============================================================

const int _exchangeCost = 10;

class _StarsExchangeDialog extends ConsumerStatefulWidget {
  const _StarsExchangeDialog();

  @override
  ConsumerState<_StarsExchangeDialog> createState() =>
      _StarsExchangeDialogState();
}

class _StarsExchangeDialogState
    extends ConsumerState<_StarsExchangeDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _exchange() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref
        .read(profileProvider.notifier)
        .exchangeStarsForLife(cost: _exchangeCost);
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _busy = false;
        _error = 'network';
      });
      return;
    }
    final success = result['success'] as bool? ?? false;
    if (success) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = (result['reason'] as String?) ?? 'unknown';
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final colors = TColors.of(context);
    final tr = TLocale.of(context);
    final canExchange =
        profile.stars >= _exchangeCost && profile.lives < profile.maxLives;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: TColors.primary, size: 22),
          const SizedBox(width: TSpacing.sm),
          Expanded(
            child: Text(
              tr('home.exchange_title'),
              style: TTypography.titleLg(color: colors.textPrimary),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('home.exchange_ratio'),
            style: TTypography.bodyMd(color: colors.textSecondary),
          ),
          const SizedBox(height: TSpacing.md),
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: TColors.primary, size: 18),
              const SizedBox(width: TSpacing.xs),
              Text(
                '${profile.stars}/${profile.starsMax}',
                style: TTypography.numericMd(color: colors.textPrimary),
              ),
              const SizedBox(width: TSpacing.lg),
              const Icon(Icons.favorite_rounded,
                  color: TColors.error, size: 18),
              const SizedBox(width: TSpacing.xs),
              Text(
                '${profile.lives}/${profile.maxLives}',
                style: TTypography.numericMd(color: colors.textPrimary),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: TSpacing.md),
            Text(
              _errorMessage(_error!, tr),
              style: TTypography.bodySm(color: TColors.error),
            ),
          ],
        ],
      ),
      actions: [
        AppButton.ghost(
          label: tr('home.exchange_cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: tr('home.exchange_cta'),
          icon: Icons.check_rounded,
          isLoading: _busy,
          onPressed: canExchange && !_busy ? _exchange : null,
        ),
      ],
    );
  }

  String _errorMessage(String reason, String Function(String) tr) {
    switch (reason) {
      case 'not_enough_stars':
        return tr('home.exchange_err_stars');
      case 'lives_already_max':
        return tr('home.exchange_err_lives_max');
      case 'no_game_selected':
        return tr('home.exchange_err_no_game');
      case 'network':
        return tr('home.exchange_err_network');
      default:
        return tr('home.exchange_err_unknown');
    }
  }
}


// =============================================================
// WIDGET : _DiscoverCard
// =============================================================
// Mini-carte de la section "Decouvre" : icone + titre + valeur.
// AppCard.glass sous-jacent pour le rendu.
// =============================================================

class _DiscoverCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _DiscoverCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TColors.of(context);
    final appliedColor = color;

    return AppCard.glass(
      onTap: onTap,
      padding: const EdgeInsets.all(TSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB(
                  0x26,
                  appliedColor.r.round(),
                  appliedColor.g.round(),
                  appliedColor.b.round(),
                ),
              ),
              child: Icon(icon, color: appliedColor, size: 20),
            ),
            const SizedBox(height: TSpacing.sm),
            Text(
              title,
              style: TTypography.titleMd(color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: TSpacing.xxs),
            Text(
              value,
              style: TTypography.labelMd(color: colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}


// =============================================================
// PAINTER : _HomeCardPatternPainter
// =============================================================
// Dessine un motif subtil de silhouettes de cartes (rectangles aux
// coins arrondis) reparties en grille diagonale sur le fond de la
// home. Donne une sensation "table de jeu" / "salle de cartes".
//
// Opacite maitrisee via la couleur [color] passee par l'appelant :
// typiquement TColors.of(context).borderSubtle pour rester discret.
// =============================================================

class _HomeCardPatternPainter extends CustomPainter {
  final Color color;

  _HomeCardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // --- Cartes-silhouettes : petits rectangles 14x20 ---
    // Grille 60x80 (cellule) avec decalage en quinconce pour un
    // effet visuel plus organique qu'une grille parfaite.
    const cellW = 64.0;
    const cellH = 88.0;
    const cardW = 14.0;
    const cardH = 20.0;

    int row = 0;
    for (double y = 0; y < size.height + cellH; y += cellH) {
      final xOffset = row.isOdd ? cellW / 2 : 0.0;
      for (double x = xOffset; x < size.width + cellW; x += cellW) {
        // Legere rotation aleatoire (mais stable) selon position
        // pour eviter l'aspect "grille robotique".
        final rotation = ((x + y) % 17) / 17 * 0.25 - 0.12;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-cardW / 2, -cardH / 2, cardW, cardH),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.restore();
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant _HomeCardPatternPainter old) =>
      old.color != color;
}


// =============================================================
// CLASSE : _HomeParticle
// =============================================================
// Particule doree qui derive lentement sur la home. Position en
// coordonnees 0..1 (fraction de l'ecran) pour etre responsive.
// =============================================================

class _HomeParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;

  _HomeParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
  });

  factory _HomeParticle.random(math.Random r) => _HomeParticle(
        x: r.nextDouble(),
        y: r.nextDouble(),
        // Vitesses tres faibles pour un mouvement meditatif.
        vx: (r.nextDouble() - 0.5) * 0.0006,
        vy: (r.nextDouble() - 0.5) * 0.0006,
        size: 1.5 + r.nextDouble() * 2.5,
        opacity: 0.1 + r.nextDouble() * 0.25,
      );

  /// Avance d'un tick avec wrap aux bords (sortie gauche = entree droite).
  void update() {
    x = (x + vx + 1) % 1.0;
    y = (y + vy + 1) % 1.0;
  }
}


// =============================================================
// PAINTER : _HomeParticlePainter
// =============================================================
// Dessine les particules en couleur primaryVariant (dore).
// Simple et rapide (CustomPainter est plus leger que 15 widgets).
// =============================================================

class _HomeParticlePainter extends CustomPainter {
  final List<_HomeParticle> particles;

  _HomeParticlePainter({
    required this.particles,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = TColors.primaryVariant.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HomeParticlePainter old) => false;
}
