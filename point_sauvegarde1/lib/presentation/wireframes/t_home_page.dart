// =============================================================
// FICHIER : lib/presentation/wireframes/t_home_page.dart
// ROLE   : Hub central PREMIUM - Design jeu de cartes AAA
//          Inspire de Hearthstone, Marvel Snap, Legends of Runeterra
// COUCHE : Presentation > Wireframes
// =============================================================
//
// ARCHITECTURE VISUELLE (v2 — Card Game Hero) :
// ----------------------------------------------
// 1. Fond multi-couche : gradient diagonal profond
//    + motif anime de symboles de cartes (losanges, cercles, croix)
//    + rayons lumineux radiaux derriere le bouton PLAY
// 2. Header frosted glass compact : logo + avatar anime + vies
// 3. CENTRE HERO (70% ecran) : 3 cartes E + C = R
//    La carte R est un "?" lumineux = bouton JOUER
//    Pulsation doree, shimmer, respiration de scale
// 4. Barre de navigation horizontale en bas : 4 cercles frosts
//    (Tutorial, Gallery, Leaderboard, Profile)
// 5. Banniere deck tres discrete en bas
//
// ANIMATIONS :
// ------------
// - Rayons lumineux : rotation lente (20s par tour complet)
// - Cartes flottantes : oscillation Y +-3px, cycle 3s decale
// - Carte "?" : breathing 1.0->1.03, shimmer, glow pulse
// - Coeurs : pulsation staggered (vague de gauche a droite)
// - Avatar ring : rotation continue gradient sweep
// - Entree : fade-in echelonne du centre vers l'exterieur
//
// TickerProviderStateMixin pour les multiples controllers.
// =============================================================

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:trialgo/core/constants/admin_constants.dart';
import 'package:trialgo/data/services/audio_service.dart';
import 'package:trialgo/presentation/providers/audio_provider.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_admin_page.dart';
import 'package:trialgo/presentation/wireframes/t_gallery_page.dart';
import 'package:trialgo/presentation/wireframes/t_home_tour.dart';
import 'package:trialgo/presentation/wireframes/t_leaderboard_page.dart';
import 'package:trialgo/presentation/wireframes/t_level_map_page.dart';
import 'package:trialgo/presentation/wireframes/t_locale.dart';
import 'package:trialgo/presentation/wireframes/t_mock_data.dart';
import 'package:trialgo/presentation/wireframes/t_profile_page.dart';
import 'package:trialgo/presentation/wireframes/t_settings_page.dart';
import 'package:trialgo/presentation/wireframes/t_theme.dart';
import 'package:trialgo/presentation/wireframes/t_tutorial_page.dart';
import 'package:trialgo/presentation/wireframes/widgets/home/home_painters.dart';
import 'package:trialgo/presentation/wireframes/widgets/home/home_widgets.dart';

// =============================================================
// WIDGET PRINCIPAL : THomePage
// =============================================================
// StatefulWidget car on gere de nombreux AnimationControllers
// pour les rayons, le glow, le shimmer, les cartes flottantes,
// l'avatar ring, les coeurs et les entrees echelonnees.
// =============================================================

/// Hub central premium avec design jeu de cartes.
///
/// Affiche le header frosted glass (avatar anime, vies pulsantes),
/// la formule E + C = R en cartes flottantes (le "?" est le bouton JOUER),
/// la barre de navigation circulaire et la banniere deck.
class THomePage extends ConsumerStatefulWidget {
  const THomePage({super.key});

  @override
  ConsumerState<THomePage> createState() => _THomePageState();
}

class _THomePageState extends ConsumerState<THomePage>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------
  // ANIMATION CONTROLLERS
  // ---------------------------------------------------------------
  // Chaque controller pilote un aspect visuel different.
  // TickerProviderStateMixin fournit autant de Tickers que necessaire.
  // ---------------------------------------------------------------

  /// Controller pour le glow pulsant de la carte "?".
  /// Oscille entre blur faible et fort, opacite basse et haute.
  late AnimationController _glowController;

  /// Animation derivee du glow : valeur entre 0.0 et 1.0.
  late Animation<double> _glowAnim;

  /// Controller pour le shimmer (balayage lumineux) de la carte "?".
  /// Cycle complet de 3 secondes, gauche a droite.
  late AnimationController _shimmerController;

  /// Controller pour la "respiration" de la carte "?" (scale 1.0->1.03).
  /// Oscillation douce sur 2.5 secondes.
  late AnimationController _breathController;

  /// Animation de scale de la respiration.
  late Animation<double> _breathAnim;

  /// Controller pour l'oscillation verticale des 3 cartes flottantes.
  /// Cycle de 3 secondes ; chaque carte a un decalage de phase.
  late AnimationController _floatController;

  /// Controller pour la rotation continue du ring autour de l'avatar.
  /// Un tour complet en 10 secondes.
  late AnimationController _avatarRingController;

  /// Controller pour la pulsation en vague des coeurs (vies).
  /// Chaque coeur pulse a un instant decale de 100ms.
  late AnimationController _heartController;

  /// Controller pour l'animation d'entree echelonnee des sections.
  /// Chaque section apparait avec un delai croissant.
  late AnimationController _entryController;

  /// Animation d'entree : valeur 0.0 (invisible) a 1.0 (visible).
  late Animation<double> _entryAnim;

  /// True si on doit afficher le tour guide sur la home.
  bool _showTour = false;

  @override
  void initState() {
    super.initState();

    // Charger le profil + relancer la musique de fond + verifier le tour.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(profileProvider.notifier).reload();

      // Relancer la musique si l'utilisateur l'a activee.
      // Volume soft (25%) specifique a la home pour un effet ambient.
      final audio = ref.read(audioServiceProvider);
      audio.setMusicVolume(0.25);
      audio.startBackgroundMusic();

      // Verifier si c'est la premiere visite de la home → afficher le tour.
      final shouldShow = await THomeTour.shouldShow();
      if (!mounted) return;
      if (shouldShow) {
        setState(() => _showTour = true);
      }
    });

    // --- Glow de la carte "?" : oscillation 2s aller-retour ---
    // La bordure doree pulse entre une lueur faible et intense.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // --- Shimmer : balayage de gauche a droite en 3 secondes ---
    // Une bande lumineuse traverse la carte "?" periodiquement.
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // --- Respiration : scale 1.0->1.03->1.0 en 2.5 secondes ---
    // La carte "?" gonfle et degonfle subtilement pour attirer l'oeil.
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // --- Flottement vertical des cartes : cycle de 3s ---
    // Les 3 cartes E, C, R oscillent en Y avec des phases decalees.
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // --- Avatar ring : rotation complete en 10 secondes ---
    // Le SweepGradient tourne autour de l'avatar pour un effet lumineux.
    _avatarRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // --- Coeurs : pulsation en boucle sur 1.5 secondes ---
    // Chaque coeur utilise un Interval decale pour creer la vague.
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // --- Entree echelonnee : une seule lecture de 1000ms ---
    // Les elements apparaissent progressivement du centre vers l'exterieur.
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _entryAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    // Demarre l'animation d'entree au prochain frame.
    _entryController.forward();
  }

  @override
  void dispose() {
    // Liberer TOUS les controllers pour eviter les fuites memoire.
    // Chaque AnimationController cree un Ticker qui consomme des
    // ressources systeme. Ne pas les disposer = memory leak.
    _glowController.dispose();
    _shimmerController.dispose();
    _breathController.dispose();
    _floatController.dispose();
    _avatarRingController.dispose();
    _heartController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // METHODE BUILD PRINCIPALE
  // ---------------------------------------------------------------
  // Structure : Scaffold avec Stack multi-couche.
  //   Couche 1 : gradient diagonal profond
  //   Couche 2 : motif de symboles de cartes (CustomPainter)
  //   Couche 3 : rayons lumineux radiaux (CustomPainter anime)
  //   Couche 4 : contenu (header + hero central + nav + deck)
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // --- Recuperation des donnees depuis le profil utilisateur ---
    // Le profil est charge reactivement depuis Supabase.
    // Les getters sur AppProfileState fournissent des valeurs par defaut.
    final tr = TLocale.of(context);
    final profile = ref.watch(profileProvider);

    final username = profile.username;
    final level = profile.level;
    final score = profile.score;
    final lives = profile.lives;
    final maxLives = profile.maxLives;

    return Scaffold(
      // Fond noir pour eviter tout flash blanc au demarrage.
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // =======================================================
          // COUCHE 1 : GRADIENT DE FOND DIAGONAL MULTI-COUCHE
          // =======================================================
          // Trois couleurs profondes en diagonale qui evoquent
          // l'univers sombre et premium des jeux de cartes.
          // #0A0A1A (quasi-noir bleute) -> #1A1035 (violet profond)
          // -> #0D1B2A (bleu marine sombre).
          // La direction diagonale ajoute du dynamisme par rapport
          // a un gradient purement vertical.
          // =======================================================
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A1A), // Quasi-noir bleute en haut-gauche.
                  Color(0xFF1A1035), // Violet profond au centre.
                  Color(0xFF0D1B2A), // Bleu marine sombre en bas-droite.
                ],
              ),
            ),
          ),

          // =======================================================
          // COUCHE 2 : MOTIF ANIME DE SYMBOLES DE CARTES
          // =======================================================
          // CustomPainter qui dessine des losanges (Emettrice),
          // des cercles (Cable) et des croix/plus (Receptrice)
          // a 3-4% d'opacite, flottant tres subtilement.
          // Ces symboles rappellent E, C, R et renforcent
          // l'identite "jeu de cartes" du fond.
          // =======================================================
          RepaintBoundary(
            child: CustomPaint(
              painter: CardSymbolsPainter(animation: _floatController),
              size: Size.infinite,
            ),
          ),

          // COUCHE 3 supprimee : rayons lumineux retires.

          // =======================================================
          // COUCHE 4 : CONTENU PRINCIPAL
          // =======================================================
          // SafeArea protege le contenu des encoches et barres systeme.
          // Column avec : header fixe + body scrollable.
          // =======================================================
          SafeArea(
            child: Column(
              children: [
                // --- HEADER FIXE (frosted glass compact) ---
                // Logo + avatar anime + vies pulsantes.
                _buildStaggered(
                  delay: 0.0,
                  child: _buildHeader(tr, username, level, score, lives, maxLives),
                ),

                // --- BODY (non scrollable, tout tient sur l'ecran) ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                    child: Column(
                      children: [
                        // HERO : les 3 cartes E + C = R.
                        // Expanded force le hero a prendre tout l'espace dispo.
                        Expanded(
                          flex: 3,
                          child: _buildStaggered(
                            delay: 0.10,
                            child: _buildHeroSection(tr, level),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // STATISTIQUES RAPIDES.
                        _buildStaggered(
                          delay: 0.35,
                          child: const HomeQuickStats(),
                        ),
                        const SizedBox(height: 6),

                        // Ligne decorative.
                        _buildStaggered(
                          delay: 0.45,
                          child: const HomeDecorativeLine(),
                        ),
                        const SizedBox(height: 6),

                        // Navigation 2x2 premium.
                        // Expanded donne une contrainte tight pour que
                        // les tuiles internes s'adaptent a l'espace dispo.
                        Expanded(
                          flex: 2,
                          child: _buildStaggered(
                            delay: 0.55,
                            child: HomeNavGrid(items: _navItems(tr)),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Banniere deck actif toujours visible en bas.
                        _buildStaggered(
                          delay: 0.70,
                          child: const HomeDeckBanner(),
                        ),

                        // Bouton admin (visible uniquement pour admin).
                        if (AdminConstants.isAdmin()) ...[
                          const SizedBox(height: 4),
                          _buildStaggered(
                            delay: 0.80,
                            child: _buildAdminButton(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =======================================================
          // OVERLAY : TOUR GUIDE (premier login uniquement)
          // =======================================================
          if (_showTour)
            THomeTour(
              onFinish: () {
                if (mounted) setState(() => _showTour = false);
              },
            ),
        ],
      ),
    );
  }

  // =============================================================
  // SECTION 1 : HEADER FROSTED GLASS COMPACT
  // =============================================================
  // Panel fixe en haut, style "frosted glass" : fond semi-transparent
  // + bordure inferieure arrondie + ombres douces.
  //
  // Contient 2 rangees compactes :
  //   R1 : Logo TRIALGO + avatar anime + username + tags + settings
  //   R2 : Coeurs pulses + timer de vie
  //
  // Optimise pour prendre le MINIMUM d'espace vertical afin
  // de laisser 70% de l'ecran au hero central.
  // =============================================================

  Widget _buildHeader(
    String Function(String) tr,
    String username,
    int level,
    int score,
    int lives,
    int maxLives,
  ) {
    return ClipRRect(
      // ClipRRect arrondit les coins inferieurs du panel.
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(24),
        bottomRight: Radius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        decoration: BoxDecoration(
          // Fond blanc a 5% d'opacite : effet "frosted glass".
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          // Ombres multiples pour simuler la profondeur du verre depoli.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.03),
              blurRadius: 1,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            // ----- ROW 1 : Logo + Avatar + Username + Tags + Settings -----
            _buildHeaderRow1(tr, username, level, score),
            const SizedBox(height: 8),

            // ----- ROW 2 : Vies pulsantes + Timer -----
            _buildHeaderRow2Hearts(lives, maxLives, tr),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // HEADER ROW 1 : Logo + Avatar anime + Username/Tags + Settings
  // ---------------------------------------------------------------
  // Tout tient sur UNE seule ligne pour maximiser la compacite.
  // Le logo est a gauche, l'avatar avec son ring tournant juste apres,
  // puis le username et les tags de niveau/score, et le gear settings
  // a droite.
  // ---------------------------------------------------------------

  Widget _buildHeaderRow1(
    String Function(String) tr,
    String username,
    int level,
    int score,
  ) {
    return Row(
      children: [
        // Logo image (asset local) : petit, 24px.
        Image.asset(MockData.logo, width: 24, height: 24, fit: BoxFit.contain),
        const SizedBox(width: 6),
        // Texte "TRIALGO" avec degrade via ShaderMask.
        // Le ShaderMask applique le gradient orange->or sur le texte blanc.
        ShaderMask(
          shaderCallback: (bounds) => TTheme.accentGradient.createShader(bounds),
          child: Text('TRIALGO', style: TTheme.subtitleStyle(size: 14)),
        ),
        const SizedBox(width: 10),

        // Avatar avec ring gradient tournant.
        // Le SweepGradient tourne en continu grace a Transform.rotate
        // lie a _avatarRingController. Le contenu (initiale) reste droit
        // =============================================================
        // AVATAR PREMIUM avec XP RING
        // =============================================================
        // Le ring exterieur est une CustomPaint qui dessine un arc
        // proportionnel au pourcentage XP du niveau en cours.
        // L'arc est colore (orange/or) et rotate legerement pour
        // un effet "vivant".
        //
        // Au centre : l'avatar avec un glow subtil.
        // Le texte "LVL X" est superpose en bas de l'avatar.
        // =============================================================
        HomeAvatarXpRing(
          avatarId: ref.watch(profileProvider).avatarId,
          level: level,
          score: score,
        ),
        const SizedBox(width: 10),

        // Username + tags (level, score) empiles verticalement.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username en Rajdhani 700, 14px.
              Text(
                username,
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              // Tags "Niveau X" et "XXXX pts" en pilules colorees.
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  _miniTag('${tr('common.level')}$level', TTheme.blue),
                  _miniTag('$score ${tr('common.pts')}', TTheme.gold),
                ],
              ),
            ],
          ),
        ),

        // Bouton settings : cercle frosted glass avec icone gear.
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TSettingsPage()),
          ),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white54, size: 16),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // HEADER ROW 2 : Coeurs pulsants (heartbeat wave) + Timer
  // ---------------------------------------------------------------
  // Chaque coeur plein pulse (scale 1.0 -> 1.1 -> 1.0) avec un
  // decalage de ~100ms par rapport au precedent, creant un effet
  // de "vague cardiaque" de gauche a droite.
  //
  // L'animation utilise un seul controller (_heartController)
  // avec des Intervals decales pour chaque coeur.
  // ---------------------------------------------------------------

  Widget _buildHeaderRow2Hearts(int lives, int maxLives, String Function(String) tr) {
    return GestureDetector(
      // Ouvre le dialogue d'achat de vies quand on tap la barre de coeurs.
      // Permet d'acheter des vies avec les points accumules.
      onTap: () {
        ref.read(audioServiceProvider).playSfx(SoundEffect.click);
        _showBuyLivesDialog(lives, maxLives);
      },
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Construction des coeurs avec pulsation vague.
          AnimatedBuilder(
            animation: _heartController,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Generation des coeurs avec pulsation decalee.
                  // Chaque coeur a un decalage de 0.067 (~100ms sur 1500ms).
                  ...List.generate(maxLives, (i) {
                    final isFilled = i < lives;

                    // Calcul du scale pour ce coeur specifique.
                    double scale = 1.0;
                    if (isFilled) {
                      final offset = i * 0.067;
                      // Position dans le cycle pour ce coeur.
                      final t = (_heartController.value - offset) % 1.0;
                      // Pulse uniquement dans la premiere moitie du cycle.
                      if (t < 0.3) {
                        // Aller-retour : monte puis descend.
                        final pulse = t < 0.15
                            ? (t / 0.15)                      // 0 -> 1 (monte).
                            : 1.0 - ((t - 0.15) / 0.15);     // 1 -> 0 (descend).
                        scale = 1.0 + 0.1 * pulse;            // 1.0 -> 1.1 -> 1.0.
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Icon(
                          isFilled
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFilled
                              ? TTheme.red
                              : Colors.white.withValues(alpha: 0.12),
                          size: 16,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  // Compteur "X/5".
                  Text('$lives/$maxLives', style: TTheme.scoreStyle(size: 12)),
                ],
              );
            },
          ),

          const Spacer(),

          // Timer de prochaine vie (affiche seulement si vies < max).
          // Informe le joueur du temps restant avant la recharge.
          if (lives < maxLives)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TTheme.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: TTheme.red, size: 11),
                  const SizedBox(width: 3),
                  Text(
                    '${tr('home.next_life')} 12${tr('home.min')}',
                    style: TTheme.tagStyle(color: TTheme.red, size: 9),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    );
  }

  // =============================================================
  // DIALOGUE D'ACHAT DE VIES
  // =============================================================
  // Affiche un dialogue permettant d'acheter une vie avec les
  // points accumules. Cout par defaut : 100 points = 1 vie.
  //
  // Verifie :
  //   - Vies pas deja au maximum
  //   - Points suffisants
  //
  // En cas de succes, la musique joue un son de success et le
  // profil est mis a jour (BDD + cache local).
  // =============================================================

  void _showBuyLivesDialog(int currentLives, int maxLives) {
    final profile = ref.read(profileProvider);
    final score = profile.score;
    const costPerLife = 100;

    if (currentLives >= maxLives) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vies deja au maximum.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final canAfford = score >= costPerLife;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1035),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: TTheme.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Acheter une vie',
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vies actuelles : $currentLives/$maxLives',
              style: GoogleFonts.exo2(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Score : $score pts',
              style: GoogleFonts.exo2(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Cout : $costPerLife pts = 1 vie',
              style: GoogleFonts.rajdhani(
                color: canAfford ? TTheme.green : Colors.red,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: canAfford
                ? () async {
                    Navigator.pop(ctx);
                    // Effectuer l'achat via le provider.
                    final ok = await ref
                        .read(profileProvider.notifier)
                        .buyLives(count: 1, costPerLife: costPerLife);

                    if (!mounted) return;
                    if (ok) {
                      ref
                          .read(audioServiceProvider)
                          .playSfx(SoundEffect.victory);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('+1 vie !'),
                          backgroundColor: TTheme.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Achat impossible'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: TTheme.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Acheter'),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // SECTION 2 : HERO CENTRAL — LES 3 CARTES E + C = R
  // =============================================================
  // C'est le coeur de la page : la formule fondamentale du jeu
  // rendue visuelle. Trois cartes sont disposees horizontalement :
  //
  //   [E]  (+)  [C]  (=)  [?]
  //
  // E et C sont des silhouettes de cartes semi-transparentes
  // (20-30% opacite, legerement inclinées +-5 degres).
  // La carte R est un "?" lumineux avec bordure doree pulsante,
  // shimmer, respiration de scale — c'est le BOUTON JOUER.
  //
  // Les 3 cartes flottent verticalement (+-3px, cycle 3s decale).
  //
  // Sous les cartes : texte "TROUVER LA CARTE MANQUANTE" en gradient,
  // puis "JOUER" en grand Rajdhani, et un pill info niveau.
  // =============================================================

  Widget _buildHeroSection(String Function(String) tr, int level) {
    // FittedBox permet au hero de se reduire automatiquement
    // pour tenir dans l'espace alloue par Expanded, evitant
    // tout overflow sur les petits ecrans.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: _buildHeroContent(tr, level),
    );
  }

  Widget _buildHeroContent(String Function(String) tr, int level) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),

        // --- Tagline courte et moderne (2 lignes max) ---
        // Un texte punchy en 2 lignes seulement.
        // Ligne 1 : l'action (petit, espace)
        // Ligne 2 : le benefice (plus grand, gradient)
        Text(
          tr('home.tagline_small'),
          textAlign: TextAlign.center,
          style: GoogleFonts.exo2(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95),
              const Color(0xFFF7C948).withValues(alpha: 0.9),
            ],
          ).createShader(bounds),
          child: Text(
            tr('home.tagline_big'),
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
              height: 1.1,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // --- Les 3 cartes flottantes : E (+) C (=) ? ---
        // Chaque carte oscille en Y avec une phase decalee.
        AnimatedBuilder(
          animation: _floatController,
          builder: (context, _) {
            final t = _floatController.value * 2 * pi;
            final yE = sin(t) * 3.0;
            final yC = sin(t + 2 * pi / 3) * 3.0;
            final yR = sin(t + 4 * pi / 3) * 3.0;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- Carte E (Emettrice) ---
                Transform.translate(
                  offset: Offset(0, yE),
                  child: Transform.rotate(
                    angle: -5 * pi / 180,
                    child: _buildGhostCard(label: 'E', color: TTheme.blue),
                  ),
                ),

                // Operateur "+" en losange dore.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildOperatorDiamond('+'),
                ),

                // --- Carte C (Cable) ---
                Transform.translate(
                  offset: Offset(0, yC),
                  child: Transform.rotate(
                    angle: 5 * pi / 180,
                    child: _buildGhostCard(label: 'C', color: TTheme.green),
                  ),
                ),

                // Operateur "=" en losange dore.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildOperatorDiamond('='),
                ),

                // --- Carte ? (Receptrice/PLAY) ---
                Transform.translate(
                  offset: Offset(0, yR),
                  child: _buildMysteryCard(tr),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // OPERATEUR EN LOSANGE DORE (+, =)
  // ---------------------------------------------------------------
  // Un carre tourne a 45 degres avec degrade orange->or subtil.
  // Remplace les operateurs texte plats par un element graphique
  // premium qui rappelle les gemmes des jeux de cartes.
  // ---------------------------------------------------------------

  Widget _buildOperatorDiamond(String symbol) {
    // Separateur minimal : juste un petit point dore subtil entre
    // les cartes. Plus de "+" ni "=", on garde uniquement un dot
    // discret pour separer visuellement les cartes du trio.
    // Le parametre symbol est ignore (conserve pour la compat API).
    return SizedBox(
      width: 16,
      height: 24,
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TTheme.gold.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // NAVIGATION : 4 items de la grille 2x2 inferieure
  // ---------------------------------------------------------------
  // Les callbacks utilisent `context` et `ref` de ce state pour
  // pouvoir naviguer ; c'est pour cela que cette liste est
  // construite ici plutot que dans le widget HomeNavGrid.
  // ---------------------------------------------------------------

  List<HomeNavItem> _navItems(String Function(String) tr) {
    return [
      HomeNavItem(
        icon: Icons.menu_book_rounded,
        label: tr('home.tutorial'),
        color: const Color(0xFF9C27B0),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TTutorialPage()),
        ),
      ),
      HomeNavItem(
        icon: Icons.grid_view_rounded,
        label: tr('home.gallery'),
        color: const Color(0xFF00BCD4),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TGalleryPage()),
        ),
      ),
      HomeNavItem(
        icon: Icons.emoji_events_rounded,
        label: tr('home.leaderboard'),
        color: const Color(0xFFF7C948),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TLeaderboardPage()),
        ),
      ),
      HomeNavItem(
        icon: Icons.person_rounded,
        label: tr('home.profile'),
        color: const Color(0xFFE91E63),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TProfilePage()),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------
  // CARTE FANTOME (E ou C) : silhouette semi-transparente
  // ---------------------------------------------------------------
  // Container avec coins arrondis, bordure fine, fond tres sombre,
  // et une lettre centree. Opacite globale a 25%.
  // Evoque une carte posee face cachee sur la table.
  // ---------------------------------------------------------------

  Widget _buildGhostCard({required String label, required Color color}) {
    return Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        // Fond sombre avec teinte coloree subtile et profondeur.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            const Color(0xFF0D0D20),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        // Bordure degradee simulee par double container.
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.5,
        ),
        // Ombre subtile coloree.
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.5),
        child: Stack(
          children: [
            // Motif de losanges en filigrane (dos de carte).
            Positioned.fill(
              child: CustomPaint(
                painter: MiniCardPatternPainter(color: color),
              ),
            ),
            // Coin sup-gauche : initiale petite.
            Positioned(
              top: 6,
              left: 8,
              child: Text(
                label,
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
            ),
            // Coin inf-droit : initiale inversee.
            Positioned(
              bottom: 6,
              right: 8,
              child: Transform.rotate(
                angle: pi,
                child: Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            // Lettre centrale grande avec glow.
            Center(
              child: Text(
                label,
                style: GoogleFonts.rajdhani(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: color.withValues(alpha: 0.8),
                  shadows: [
                    Shadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ),
            // Barre decorative en bas.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      color.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // CARTE MYSTERE "?" : le bouton JOUER deguise en carte
  // ---------------------------------------------------------------
  // C'est la piece maitresse : une carte avec un "?" lumineux,
  // une bordure doree pulsante, un shimmer qui balaie, et une
  // respiration de scale (1.0->1.03).
  //
  // Au tap, elle compresse (scale 0.95) puis navigue vers TLevelMapPage.
  //
  // Combine 3 animations simultanees :
  //   - _breathAnim : scale 1.0->1.03 (respiration)
  //   - _glowAnim : intensite du glow doré (bordure + ombre)
  //   - _shimmerController : position de la bande lumineuse
  //   - _playTapScale : compression au toucher
  // ---------------------------------------------------------------

  Widget _buildMysteryCard(String Function(String) tr) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnim, _shimmerController, _breathAnim]),
      builder: (context, _) {
        final glowBlur = lerpDouble(8, 18, _glowAnim.value)!;
        final glowOpacity = lerpDouble(0.3, 0.7, _glowAnim.value)!;
        final glowColor = Color.lerp(TTheme.orange, TTheme.gold, _glowAnim.value)!;

        // La carte "JOUER" est maintenant le BOUTON de lancement du jeu.
        // Tap = navigue vers la level map (comme l'ancien bouton JOUER).
        return GestureDetector(
          onTap: () {
            ref.read(audioServiceProvider).playSfx(SoundEffect.swoosh);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TLevelMapPage()),
            );
          },
          child: Transform.scale(
          scale: _breathAnim.value,
          child: Container(
            width: 78,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2A1800),
                  Color(0xFF1A1000),
                  Color(0xFF2A1500),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: glowColor.withValues(alpha: glowOpacity),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: glowOpacity * 0.5),
                  blurRadius: glowBlur,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Motif dos de carte dore.
                  Positioned.fill(
                    child: CustomPaint(
                      painter: MiniCardPatternPainter(
                        color: TTheme.gold,
                      ),
                    ),
                  ),
                  // Shimmer.
                  Positioned.fill(
                    child: ShaderMask(
                      blendMode: BlendMode.srcATop,
                      shaderCallback: (bounds) {
                        final pos = -1.0 + 3.0 * _shimmerController.value;
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: [
                            (pos - 0.15).clamp(0.0, 1.0),
                            pos.clamp(0.0, 1.0),
                            (pos + 0.15).clamp(0.0, 1.0),
                          ],
                        ).createShader(bounds);
                      },
                      child: Container(color: Colors.white.withValues(alpha: 0.01)),
                    ),
                  ),
                  // Coins decoratifs "PLAY".
                  Positioned(
                    top: 6,
                    left: 8,
                    child: Text(
                      '▶',
                      style: TextStyle(
                        fontSize: 9,
                        color: TTheme.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    right: 8,
                    child: Transform.rotate(
                      angle: pi,
                      child: Text(
                        '▶',
                        style: TextStyle(
                          fontSize: 9,
                          color: TTheme.gold.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),

                  // --- PASTILLE PLAY CENTRALE ---
                  // Un cercle dore avec icone play_arrow, plus un ring
                  // exterieur pulsant. Beaucoup plus explicite qu'un "?".
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            TTheme.gold,
                            TTheme.orange,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: TTheme.gold.withValues(alpha: 0.6),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: TTheme.orange.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- Label "JOUER" en haut ---
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Text(
                      'JOUER',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Barre basse doree.
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          TTheme.gold.withValues(alpha: 0.6),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),  // fin GestureDetector (click = lancer le jeu)
        );
      },
    );
  }




  // =============================================================
  // BOUTON ADMIN (visible uniquement pour admin@trialgo.com)
  // =============================================================
  // Bouton discret en bas de la page pour acceder a l'interface
  // d'administration des cartes et du graphe.
  // =============================================================

  // =============================================================
  // BOUTON ADMIN PREMIUM
  // =============================================================
  // Un card-style button style "carte legendaire" avec :
  //   - Fond degrade violet/or (admin est special)
  //   - Badge ADMIN en haut a gauche
  //   - Icone shield 3D
  //   - Glow violet subtil
  //   - Effet shimmer comme les autres cartes premium
  // =============================================================

  Widget _buildAdminButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return GestureDetector(
          onTap: () {
            ref.read(audioServiceProvider).playSfx(SoundEffect.click);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TAdminPage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF7B2CBF).withValues(alpha: 0.25),
                  const Color(0xFF1A1040).withValues(alpha: 0.4),
                  const Color(0xFFF7C948).withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF7C948).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B2CBF).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFFF7C948).withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                children: [
                  // --- Shimmer diagonal ---
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          final dx = -1.0 + _shimmerController.value * 3.0;
                          return LinearGradient(
                            begin: Alignment(dx, -0.5),
                            end: Alignment(dx + 0.5, 0.5),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(color: Colors.white12),
                      ),
                    ),
                  ),

                  // --- Contenu ---
                  Row(
                    children: [
                      // Icone shield dans un cercle premium.
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF7C948),
                              Color(0xFFFF6B35),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF7C948)
                                  .withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Labels.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badge ADMIN.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7C948)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFF7C948)
                                      .withValues(alpha: 0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'ADMIN',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFF7C948),
                                  letterSpacing: 1.5,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Titre.
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [
                                  Colors.white,
                                  Color(0xFFF7C948),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'Administration',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              'Cartes · Graphe · Config',
                              style: GoogleFonts.exo2(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.45),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Chevron avec glow.
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: const Color(0xFFF7C948)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFF7C948),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =============================================================
  // UTILITAIRE : ENTREE ECHELONNEE (staggered entry)
  // =============================================================
  // Chaque section apparait avec un delai croissant.
  // L'animation combine un fade (opacite 0->1) et un slide up
  // (decalage vertical 20px -> 0px).
  //
  // [delay] : fraction de l'animation totale (0.0 a 1.0) ou
  // le widget commence a apparaitre. Par exemple, 0.25 = le
  // widget commence a 25% de la duree totale d'entree.
  //
  // Le calcul : on prend la valeur actuelle de l'animation (0->1),
  // on soustrait le delay, et on normalise sur une fenetre de 0.4.
  // Cela donne une progression locale pour chaque widget.
  // =============================================================

  Widget _buildStaggered({required double delay, required Widget child}) {
    return AnimatedBuilder(
      animation: _entryAnim,
      builder: (context, _) {
        // Progression locale : le widget apparait entre [delay] et [delay+0.4].
        final progress = ((_entryAnim.value - delay) / 0.4).clamp(0.0, 1.0);

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            // Glissement vers le haut de 20px a 0px.
            offset: Offset(0, 20 * (1.0 - progress)),
            child: child,
          ),
        );
      },
    );
  }

  // =============================================================
  // UTILITAIRE : TAG MINIATURE (pilule coloree)
  // =============================================================
  // Petit badge avec fond colore a 15% d'opacite et texte
  // de la meme couleur. Utilise pour "Niveau 7", "4250 pts", etc.
  // =============================================================

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text, style: TTheme.tagStyle(color: color, size: 9)),
    );
  }
}

