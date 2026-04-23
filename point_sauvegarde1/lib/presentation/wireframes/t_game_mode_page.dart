// =============================================================
// FICHIER : lib/presentation/wireframes/t_game_mode_page.dart
// ROLE   : Choix du mode de jeu (Solo ou Collectif)
// COUCHE : Presentation > Wireframes
// =============================================================
//
// DESIGN PREMIUM : CARTES A JOUER STYLE HEARTHSTONE / MARVEL SNAP
// -----------------------------------------------------------------
// Le joueur choisit entre :
//   - Mode Solo : l'appli genere des questions
//   - Mode Collectif : scan de 3 cartes physiques (QR codes)
//
// Chaque mode est represente par une grande carte stylisee
// avec des cotes concaves (bezier), des coins decoratifs
// (lettre initiale en haut-gauche, inversee en bas-droite),
// un symbole central type "enseigne" (comme coeur/pique),
// et des animations d'entree, de flottement et de selection.
//
// FLOW : Activation → [CETTE PAGE] → Home (solo) ou ScanPage (coop)
// =============================================================

import 'dart:math';
// "dart:math" fournit pi, sin, cos, Random... necessaires
// pour le CustomPainter des particules et la rotation pi.

import 'package:flutter/material.dart';
// Le framework Flutter Material : tous les widgets, animations,
// Canvas, Paint, Path, etc.

import 'package:google_fonts/google_fonts.dart';
// Permet d'utiliser Rajdhani (titres gaming) et Exo2 (body)
// directement depuis Google Fonts sans les telecharger manuellement.

import 'package:trialgo/presentation/wireframes/t_theme.dart';
// Notre fichier de theme centralise : couleurs, degrades, styles texte.

import 'package:trialgo/presentation/wireframes/t_home_page.dart';
// La page vers laquelle on navigue apres le choix du mode.

/// Page de choix du mode de jeu : Solo ou Collectif.
///
/// Deux grandes cartes stylisees comme des cartes a jouer premium
/// (cotes concaves, coins decoratifs, animations fluides).
/// Le joueur tape sur l'une pour choisir son mode.
class TGameModePage extends StatefulWidget {
  const TGameModePage({super.key});
  // "const" : le widget est immuable, Flutter peut l'optimiser.
  // "super.key" : transmet la cle au parent StatefulWidget.

  @override
  State<TGameModePage> createState() => _TGameModePageState();
  // Cree l'objet State mutable associe a ce widget.
}

class _TGameModePageState extends State<TGameModePage>
    with TickerProviderStateMixin {
  // "TickerProviderStateMixin" : fournit plusieurs Tickers (horloges)
  // pour alimenter nos AnimationControllers.
  // On en a besoin de plusieurs (float, entry, shimmer, badge pulse).

  // ---------------------------------------------------------------
  // ETAT
  // ---------------------------------------------------------------

  /// Mode selectionne : null = aucun, 0 = solo, 1 = coop.
  int? _selectedMode;

  // ---------------------------------------------------------------
  // CONTROLEURS D'ANIMATION
  // ---------------------------------------------------------------

  /// Animation de flottement perpetuel des cartes (haut/bas ±4px).
  /// Cycle de 3 secondes, aller-retour, simule un leger mouvement.
  late AnimationController _floatController;
  late Animation<double> _floatAnim;
  // "late" : initialise dans initState, pas dans le constructeur.

  /// Animation d'entree des cartes depuis les cotes de l'ecran.
  /// Carte gauche glisse de -200px, carte droite de +200px.
  late AnimationController _entryController;
  late Animation<double> _entryLeft;
  // Offset X de la carte gauche : -200 → 0 (apparait de la gauche).
  late Animation<double> _entryRight;
  // Offset X de la carte droite : +200 → 0 (apparait de la droite).

  /// Animation du shimmer (bande blanche) sur le bouton Continuer.
  /// Balaye de gauche a droite toutes les 3 secondes.
  late AnimationController _shimmerController;

  /// Animation du badge "ACTIF" : pulsation douce de l'opacite.
  late AnimationController _badgePulseController;
  late Animation<double> _badgePulseAnim;

  /// Animation du bouton Continuer : slide up + fade in.
  /// Declenchee quand _selectedMode passe de null a une valeur.
  late AnimationController _buttonEntryController;
  late Animation<double> _buttonSlide;
  // Offset Y du bouton : 30px (en bas) → 0px (position finale).
  late Animation<double> _buttonFade;
  // Opacite du bouton : 0.0 → 1.0.

  // ---------------------------------------------------------------
  // DONNEES DES PARTICULES AMBIANTES
  // ---------------------------------------------------------------
  // On genere une liste de particules a l'avance (positions, tailles,
  // vitesses) pour les dessiner dans le CustomPainter.
  // Chaque particule derive lentement, creant une ambiance premium.

  /// Liste des particules generees aleatoirement au demarrage.
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    // "super.initState()" : obligation d'appeler le parent d'abord.

    // --- PARTICULES AMBIANTES ---
    // On genere 25 particules avec des positions et vitesses aleatoires.
    final rng = Random();
    // "Random()" : generateur de nombres aleatoires.
    _particles = List.generate(25, (i) {
      return _Particle(
        x: rng.nextDouble(),
        // Position X initiale : 0.0 a 1.0 (fraction de la largeur).
        y: rng.nextDouble(),
        // Position Y initiale : 0.0 a 1.0 (fraction de la hauteur).
        radius: 1.5 + rng.nextDouble() * 2.5,
        // Rayon : entre 1.5 et 4.0 pixels.
        speed: 0.15 + rng.nextDouble() * 0.35,
        // Vitesse de derive : entre 0.15 et 0.50 (unite arbitraire).
        alpha: 0.05 + rng.nextDouble() * 0.12,
        // Opacite : entre 0.05 et 0.17 (tres subtil).
        isBlue: rng.nextBool(),
        // Couleur : bleu ou violet, alterne aleatoirement.
      );
    });

    // --- FLOTTEMENT PERPETUEL ---
    // Les cartes oscillent verticalement de -4px a +4px en 3 secondes.
    _floatController = AnimationController(
      vsync: this,
      // "vsync: this" : le State fournit le Ticker via le mixin.
      duration: const Duration(milliseconds: 3000),
      // 3 secondes pour un cycle complet aller.
    )..repeat(reverse: true);
    // "..repeat(reverse: true)" : boucle infinie aller-retour.
    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
      // "Curves.easeInOut" : acceleration douce au debut et a la fin,
      // ce qui donne un mouvement naturel et fluide.
    );

    // --- ENTREE DES CARTES ---
    // Les cartes glissent depuis les cotes en 800ms avec un rebond.
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryLeft = Tween<double>(begin: -200.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
        // "Interval(0.0, 0.7)" : l'animation gauche commence au debut
        // et finit a 70% de la duree totale (560ms).
        // "Curves.easeOutBack" : decelere avec un leger depassement
        // (overshoot) qui donne un rebond organique.
      ),
    );
    _entryRight = Tween<double>(begin: 200.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOutBack),
        // "Interval(0.15, 0.85)" : demarre 15% plus tard (stagger 120ms)
        // et finit a 85%. La carte droite suit la gauche avec un delai.
      ),
    );
    _entryController.forward();
    // "forward()" : lance l'animation d'entree immediatement.

    // --- SHIMMER DU BOUTON ---
    // Une bande blanche balaye le bouton toutes les 3 secondes.
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    // "repeat()" sans reverse : le shimmer va toujours dans le meme sens.

    // --- PULSE DU BADGE "ACTIF" ---
    // L'opacite du badge oscille entre 0.6 et 1.0 en 2 secondes.
    _badgePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _badgePulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _badgePulseController, curve: Curves.easeInOut),
    );

    // --- ENTREE DU BOUTON CONTINUER ---
    // Slide up (30px → 0px) + fade in (0 → 1), 300ms.
    _buttonEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _buttonSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
          parent: _buttonEntryController, curve: Curves.easeOutCubic),
    );
    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _buttonEntryController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    // IMPORTANT : liberer tous les controleurs pour eviter les fuites memoire.
    _floatController.dispose();
    _entryController.dispose();
    _shimmerController.dispose();
    _badgePulseController.dispose();
    _buttonEntryController.dispose();
    super.dispose();
    // "super.dispose()" : toujours appeler en dernier.
  }

  /// Methode appelee quand le joueur tape sur une carte.
  /// Met a jour l'etat et declenche l'animation du bouton.
  void _selectMode(int index) {
    setState(() => _selectedMode = index);
    // "setState" : signale a Flutter de reconstruire le widget.
    _buttonEntryController.forward(from: 0.0);
    // "forward(from: 0.0)" : relance l'animation depuis le debut
    // a chaque changement de selection (meme si on change de mode).
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // "Scaffold" : structure de base Material (body, appBar, etc.).
      body: Stack(
        // "Stack" : empile les couches visuelles les unes sur les autres.
        // Couche 1 : fond degrade + particules.
        // Couche 2 : vignette (bords sombres).
        // Couche 3 : contenu interactif (header, cartes, bouton).
        children: [
          // =============================================================
          // COUCHE 1 : FOND DEGRADE + PARTICULES AMBIANTES
          // =============================================================
          // Le fond utilise le degrade standard TTheme.bgGradient
          // (bgDark → bgMid → bgLight, du haut vers le bas).
          // Par-dessus, un CustomPainter dessine 25 particules
          // bleues/violettes qui derivent lentement.
          Positioned.fill(
            // "Positioned.fill" : remplit tout l'espace du Stack.
            child: Container(
              decoration: const BoxDecoration(gradient: TTheme.bgGradient),
              // "BoxDecoration" : decore le Container avec un degrade.
              child: AnimatedBuilder(
                // "AnimatedBuilder" : reconstruit son child a chaque tick
                // de l'animation, ici le flottement (qui fait aussi
                // avancer les particules via le temps).
                animation: _floatController,
                builder: (context, _) {
                  return CustomPaint(
                    // "CustomPaint" : widget qui appelle un Painter custom.
                    painter: _AmbientParticlePainter(
                      particles: _particles,
                      // Les donnees des particules (positions, tailles...).
                      tick: _floatController.value,
                      // On passe la valeur du controleur comme "horloge"
                      // pour animer les positions des particules.
                    ),
                    size: Size.infinite,
                    // "Size.infinite" : prend tout l'espace disponible.
                  );
                },
              ),
            ),
          ),

          // =============================================================
          // COUCHE 2 : EFFET VIGNETTE (bords sombres)
          // =============================================================
          // Un degrade radial transparent au centre, noir sur les bords.
          // Donne un effet cinematographique premium.
          Positioned.fill(
            child: IgnorePointer(
              // "IgnorePointer" : cette couche ne capture pas les taps.
              // Les taps passent a travers vers le contenu en-dessous.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    // "RadialGradient" : degrade circulaire depuis le centre.
                    center: Alignment.center,
                    radius: 0.85,
                    // 0.85 : le cercle transparent couvre ~85% de l'ecran.
                    colors: [
                      Colors.transparent,
                      // Centre : totalement transparent (pas d'assombrissement).
                      Colors.black.withValues(alpha: 0.4),
                      // Bords : noir a 40% d'opacite (assombrissement subtil).
                    ],
                    stops: const [0.5, 1.0],
                    // Transition : transparent jusqu'a 50%, puis progressif.
                  ),
                ),
              ),
            ),
          ),

          // =============================================================
          // COUCHE 3 : CONTENU INTERACTIF
          // =============================================================
          // =============================================================
          // COUCHE 3 : CONTENU SCROLLABLE (evite l'overflow)
          // =============================================================
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 20),

                      // HEADER
                      _buildHeader(),

                      const SizedBox(height: 32),

                      // TITRE
                      _buildTitle(),

                      const SizedBox(height: 8),

                      // LIGNE DECORATIVE
                      _buildDecorativeLine(),

                      const SizedBox(height: 24),

                      // LES 2 CARTES DE MODE
                      _buildModeCards(),

                      const SizedBox(height: 28),

                      // BOUTON CONTINUER
                      _buildContinueButton(),

                      const SizedBox(height: 12),

                      // TEXTE INFORMATIF
                      Text(
                        'Vous pourrez changer de mode a tout moment',
                        style: GoogleFonts.exo2(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // WIDGET : HEADER (bouton retour + deck info + badge ACTIF)
  // =============================================================
  // Le header affiche :
  //   - Un bouton retour en verre givre (frosted glass)
  //   - Le nom du deck actif ("Deck Savane") avec un point colore
  //   - Le nombre de cartes ("50 cartes")
  //   - Un badge "ACTIF" pulsant doucement
  // =============================================================
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // Marge horizontale de 24px de chaque cote.
      child: Row(
        // "Row" : dispose les enfants horizontalement.
        children: [
          // --- BOUTON RETOUR (frosted glass) ---
          GestureDetector(
            // "GestureDetector" : detecte les taps sur son enfant.
            onTap: () => Navigator.of(context).pop(),
            // "Navigator.pop()" : retourne a l'ecran precedent.
            child: Container(
              width: 42,
              height: 42,
              // Taille fixe 42x42 pour un bouton carre.
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                // Fond blanc a 6% : effet "verre givre" subtil.
                borderRadius: BorderRadius.circular(14),
                // Coins arrondis de rayon 14.
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  // Bordure blanche a 8% : liseré a peine visible.
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white54,
                // "Colors.white54" : blanc a ~54% d'opacite.
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 14),
          // Espace entre le bouton et le texte.

          // --- INFO DECK ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // Aligne le texte a gauche.
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                // "MainAxisSize.min" : le Row prend le minimum de largeur.
                children: [
                  // Point colore indicateur du deck.
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: TTheme.orange,
                      // Point orange (couleur du deck Savane).
                      shape: BoxShape.circle,
                      // Forme circulaire.
                      boxShadow: [
                        BoxShadow(
                          color: TTheme.orange.withValues(alpha: 0.4),
                          blurRadius: 6,
                          // Petit halo orange autour du point.
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Deck Savane',
                    style: TTheme.subtitleStyle(size: 16),
                    // Police Rajdhani 700, 16px, blanc.
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                // Aligne "50 cartes" sous le nom du deck (apres le point).
                child: Text(
                  '50 cartes',
                  style: TTheme.bodyStyle(
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                    // Texte tres discret.
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),
          // "Spacer" : pousse le badge a droite.

          // --- BADGE "ACTIF" avec pulsation ---
          AnimatedBuilder(
            animation: _badgePulseAnim,
            // Reconstruit a chaque tick pour animer l'opacite.
            builder: (context, child) {
              return Opacity(
                opacity: _badgePulseAnim.value,
                // L'opacite oscille entre 0.6 et 1.0 (pulsation douce).
                child: child,
              );
            },
            child: Container(
              // "child" passe a AnimatedBuilder : pas reconstruit a chaque tick.
              // Seul l'Opacity change, ce qui est performant.
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  TTheme.orange.withValues(alpha: 0.2),
                  TTheme.gold.withValues(alpha: 0.1),
                  // Degrade orange/or tres subtil.
                ]),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TTheme.orange.withValues(alpha: 0.3),
                  // Bordure orange a 30%.
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: TTheme.orange, size: 14),
                  const SizedBox(width: 4),
                  Text('ACTIF',
                      style: TTheme.tagStyle(color: TTheme.orange, size: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // WIDGET : TITRE avec ShaderMask gradient orange → or
  // =============================================================
  // "ShaderMask" applique un shader (ici un degrade) sur le texte.
  // Le texte est blanc, et le shader le colore en orange/or.
  // Cela donne un effet metallique tres premium.
  // =============================================================
  Widget _buildTitle() {
    return ShaderMask(
      // "ShaderMask" : applique un shader graphique sur son enfant.
      shaderCallback: (bounds) {
        // "shaderCallback" recoit le rectangle du widget
        // et retourne un Shader (ici un LinearGradient).
        return const LinearGradient(
          colors: [
            Color(0xFFFF6B35),
            // Orange vif (debut du degrade).
            Color(0xFFF7C948),
            // Or (fin du degrade).
          ],
        ).createShader(bounds);
        // "createShader(bounds)" : convertit le Gradient en Shader
        // adapte aux dimensions du texte.
      },
      blendMode: BlendMode.srcIn,
      // "BlendMode.srcIn" : le shader colore uniquement les pixels
      // non-transparents du texte. Le fond reste transparent.
      child: Text(
        'CHOISISSEZ VOTRE MODE',
        style: GoogleFonts.rajdhani(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
          // 4px entre chaque lettre : effet "small caps" premium.
          color: Colors.white,
          // Le blanc sera remplace par le degrade via ShaderMask.
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : LIGNE DECORATIVE avec losange central
  // =============================================================
  // Une ligne horizontale fine avec un petit losange (carre tourne
  // a 45 degres) au centre. Effet inspiré des jeux de cartes.
  // =============================================================
  Widget _buildDecorativeLine() {
    return SizedBox(
      width: 200,
      // Largeur fixe de 200px pour la ligne decorative.
      height: 20,
      // Hauteur de 20px pour contenir la ligne + le losange.
      child: CustomPaint(
        painter: _DiamondLinePainter(),
        // Notre Painter custom qui dessine la ligne + le losange.
      ),
    );
  }

  // =============================================================
  // WIDGET : LES DEUX CARTES DE MODE (SOLO + COOP)
  // =============================================================
  // Chaque carte est un ClipPath avec _PlayingCardClipper
  // (cotes concaves via bezier quadratiques).
  // Les cartes sont animees : entree laterale + flottement.
  // =============================================================
  Widget _buildModeCards() {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnim, _entryController]),
      // "Listenable.merge" : combine deux Listenables en un seul.
      // Le builder se reconstruit quand l'un OU l'autre change.
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // --- CARTE SOLO ---
              Expanded(
                // "Expanded" : la carte prend tout l'espace disponible
                // (50% de la largeur moins le SizedBox entre les deux).
                child: Transform.translate(
                  offset: Offset(_entryLeft.value, _floatAnim.value),
                  // Combine l'offset d'entree (X) et le flottement (Y).
                  // Au demarrage : X = -200 → 0, Y oscille ±4px.
                  child: _buildModeCard(
                    index: 0,
                    title: 'SOLO',
                    subtitle: 'Mode Individuel',
                    description:
                        'L\'appli genere des questions a partir de votre deck',
                    icon: Icons.person_rounded,
                    // Icone "personne" pour le mode solo.
                    accentColor: TTheme.orange,
                    // Couleur d'accent : orange.
                    gradientColors: [
                      const Color(0xFFFF6B35),
                      // Orange vif.
                      const Color(0xFFF7C948),
                      // Or.
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),
              // Espace entre les deux cartes.

              // --- CARTE COOP ---
              Expanded(
                child: Transform.translate(
                  offset: Offset(_entryRight.value, -_floatAnim.value),
                  // La carte droite flotte en sens inverse (-_floatAnim)
                  // pour un mouvement asymetrique plus organique.
                  child: _buildModeCard(
                    index: 1,
                    title: 'COOP',
                    subtitle: 'Mode Collectif',
                    description:
                        'Scannez 3 cartes physiques et verifiez le trio',
                    icon: Icons.qr_code_scanner_rounded,
                    // Icone "scanner QR" pour le mode cooperatif.
                    accentColor: TTheme.blue,
                    // Couleur d'accent : bleu.
                    gradientColors: [
                      const Color(0xFF42A5F5),
                      // Bleu clair.
                      const Color(0xFF667EEA),
                      // Bleu/violet.
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =============================================================
  // WIDGET : UNE CARTE DE MODE (style carte a jouer premium)
  // =============================================================
  //
  // Structure de la carte :
  //   ┌─────────────────────┐
  //   │ S      ♟            │  ← coin sup-gauche : initiale + icone
  //   │                     │
  //   │      [ ICONE ]      │  ← icone central dans un cercle gradient
  //   │       SOLO          │  ← titre en Rajdhani 900
  //   │   Mode Individuel   │  ← sous-titre en Exo2
  //   │                     │
  //   │  description text   │  ← description courte
  //   │        ✓            │  ← checkmark si selectionne
  //   │ ♟            Ꙅ     │  ← coin inf-droit : icone + initiale inversee
  //   └─────────────────────┘
  //
  // Les cotes de la carte sont legerement concaves (quadratic bezier)
  // pour un look unique inspire des jeux de cartes premium.
  // =============================================================
  Widget _buildModeCard({
    required int index,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
  }) {
    final isSelected = _selectedMode == index;
    // true si cette carte est celle actuellement selectionnee.
    final isOtherSelected = _selectedMode != null && _selectedMode != index;
    // true si l'AUTRE carte est selectionnee (pour dimmer celle-ci).

    // Facteur d'echelle : 1.03 si selectionnee, 0.97 si l'autre est selectionnee.
    final scale = isSelected
        ? 1.03
        : isOtherSelected
            ? 0.97
            : 1.0;

    // Opacite : 1.0 si selectionnee ou aucune, 0.6 si l'autre est selectionnee.
    final opacity = isOtherSelected ? 0.6 : 1.0;

    return GestureDetector(
      onTap: () => _selectMode(index),
      // Quand on tape sur la carte, on selectionne ce mode.
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        opacity: opacity,
        // Transition douce de l'opacite.
        child: TweenAnimationBuilder<double>(
          // "TweenAnimationBuilder" : anime automatiquement la transition
          // entre l'ancienne et la nouvelle valeur de "scale".
          // Plus simple qu'un AnimationController pour une valeur unique.
          tween: Tween<double>(begin: scale, end: scale),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, scaleValue, child) {
            return Transform.scale(
              scale: scaleValue,
              // Applique le facteur d'echelle.
              child: child,
            );
          },
          child: ClipPath(
            clipper: _PlayingCardClipper(),
            // "ClipPath" : decoupe le widget selon un Path custom.
            // "_PlayingCardClipper" cree une forme de carte avec
            // des cotes legerement concaves (bezier quadratiques).
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              // Transition douce pour tous les changements visuels.
              height: MediaQuery.of(context).size.height * 0.42,
              // Hauteur responsive : 42% de l'ecran (evite l'overflow).
              decoration: BoxDecoration(
                // --- FOND DE LA CARTE ---
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          gradientColors[0].withValues(alpha: 0.25),
                          // Degrade colore a 25% en haut-gauche.
                          Colors.transparent,
                          // Transparent en bas-droite.
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1E1E3A),
                          // Fond sombre (#1E1E3A) pour carte non selectionnee.
                          Color(0xFF1E1E3A),
                        ],
                      ),
                // --- BORDURE ---
                border: Border.all(
                  color: isSelected
                      ? gradientColors[0].withValues(alpha: 0.5)
                      // Bordure coloree a 50% si selectionnee.
                      : Colors.white.withValues(alpha: 0.08),
                  // Bordure blanche a 8% si non selectionnee.
                  width: isSelected ? 1.5 : 1,
                ),
                // --- OMBRE EXTERNE (glow) ---
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.25),
                          blurRadius: 24,
                          // Halo lumineux de 24px autour de la carte.
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ===========================================
                    // COIN SUPERIEUR : initiale + symbole
                    // ===========================================
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lettre initiale du mode (S ou C).
                        Text(
                          title[0],
                          // "title[0]" : premier caractere du titre.
                          style: GoogleFonts.rajdhani(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? gradientColors[0]
                                : Colors.white.withValues(alpha: 0.15),
                            // Coloree si selectionnee, tres pale sinon.
                          ),
                        ),
                        const Spacer(),
                        // Symbole "enseigne" (comme coeur/pique/carreau).
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected
                              ? gradientColors[0]
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ===========================================
                    // ICONE CENTRAL dans un cercle gradient
                    // ===========================================
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isSelected ? 58 : 50,
                      height: isSelected ? 58 : 50,
                      // Grossit legerement quand selectionnee.
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(colors: gradientColors)
                            // Degrade colore si selectionnee.
                            : null,
                        color: isSelected
                            ? null
                            : Colors.white.withValues(alpha: 0.06),
                        // Fond gris tres subtil si non selectionnee.
                        shape: BoxShape.circle,
                        // Forme circulaire (pas borderRadius car cercle).
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      gradientColors[0].withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  // Halo lumineux autour de l'icone.
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        icon,
                        size: isSelected ? 30 : 26,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        // Icone blanche si selectionnee, pale sinon.
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===========================================
                    // TITRE DU MODE (SOLO / COOP)
                    // ===========================================
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        // Large espacement pour un look premium.
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),

                    const SizedBox(height: 2),

                    // ===========================================
                    // SOUS-TITRE (Mode Individuel / Mode Collectif)
                    // ===========================================
                    Text(
                      subtitle,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? accentColor
                            // Colore (orange ou bleu) quand selectionnee.
                            : Colors.white.withValues(alpha: 0.25),
                      ),
                    ),

                    const Spacer(),

                    // ===========================================
                    // DESCRIPTION
                    // ===========================================
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.exo2(
                        fontSize: 10,
                        color: Colors.white
                            .withValues(alpha: isSelected ? 0.5 : 0.2),
                        // Plus visible quand selectionnee.
                        height: 1.3,
                        // Interligne de 1.3x la taille de police.
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ===========================================
                    // CHECKMARK (apparait si selectionne)
                    // ===========================================
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: isSelected ? 1.0 : 0.0,
                      // Invisible si non selectionnee, visible si oui.
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        offset: isSelected
                            ? Offset.zero
                            // Position finale : en place.
                            : const Offset(0, 0.5),
                        // Position initiale : decale vers le bas.
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: gradientColors[0],
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ===========================================
                    // COIN INFERIEUR : symbole + initiale inversee
                    // ===========================================
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isSelected
                              ? gradientColors[0]
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                        const Spacer(),
                        Transform.rotate(
                          angle: pi,
                          // "pi" radians = 180 degres.
                          // La lettre est inversee comme sur une vraie
                          // carte a jouer (lisible dans les deux sens).
                          child: Text(
                            title[0],
                            style: GoogleFonts.rajdhani(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? gradientColors[0]
                                  : Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // WIDGET : BOUTON CONTINUER
  // =============================================================
  // Apparait en slide up + fade in quand un mode est selectionne.
  // Le degrade et le texte changent selon le mode choisi.
  // Un shimmer (bande blanche) balaye le bouton toutes les 3s.
  // =============================================================
  Widget _buildContinueButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: AnimatedBuilder(
        animation:
            Listenable.merge([_buttonEntryController, _shimmerController]),
        // Reconstruit quand le bouton entre OU quand le shimmer avance.
        builder: (context, _) {
          // Si aucun mode n'est selectionne, on cache le bouton.
          final show = _selectedMode != null;

          return Opacity(
            opacity: show ? _buttonFade.value : 0.0,
            // Opacite animee : 0 → 1 quand le mode est choisi.
            child: Transform.translate(
              offset: Offset(0, show ? _buttonSlide.value : 30),
              // Slide up : 30px → 0px.
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: _buildShimmerButton(),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Construit le bouton avec l'effet shimmer.
  Widget _buildShimmerButton() {
    // Determine le degrade selon le mode selectionne.
    final gradient = _selectedMode == 0
        ? const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFF7C948)])
        : _selectedMode == 1
            ? const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF667EEA)])
            : const LinearGradient(
                colors: [Color(0xFF333333), Color(0xFF222222)]);

    // Couleur d'ombre selon le mode.
    final shadowColor = _selectedMode == 0
        ? TTheme.orange
        : _selectedMode == 1
            ? TTheme.blue
            : Colors.transparent;

    return GestureDetector(
      onTap: _selectedMode != null
          ? () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const THomePage()),
                // "pushReplacement" : remplace cette page par THomePage.
                // L'utilisateur ne peut pas revenir ici avec "retour".
              );
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _selectedMode != null
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          // "ClipRRect" : decoupe le shimmer aux bords arrondis du bouton.
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // --- CONTENU DU BOUTON (icone + texte) ---
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedMode == 0
                          ? Icons.play_arrow_rounded
                          // Icone "play" pour le mode solo.
                          : _selectedMode == 1
                              ? Icons.qr_code_scanner_rounded
                              // Icone "scanner" pour le mode coop.
                              : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedMode == 0
                          ? 'COMMENCER EN SOLO'
                          : _selectedMode == 1
                              ? 'LANCER LE SCAN'
                              : 'CONTINUER',
                      style: TTheme.buttonStyle(size: 14),
                      // Police Rajdhani 700, 14px, blanc, letterSpacing 2.
                    ),
                  ],
                ),
              ),

              // --- SHIMMER (bande blanche qui balaye) ---
              if (_selectedMode != null)
                Positioned.fill(
                  child: IgnorePointer(
                    // Le shimmer ne bloque pas les taps.
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        // Position de la bande : -1.0 a 2.0
                        // pour qu'elle traverse tout le bouton.
                        final dx = -1.0 + _shimmerController.value * 3.0;
                        // A 0.0 : bande a -1.0 (hors ecran a gauche).
                        // A 1.0 : bande a 2.0 (hors ecran a droite).
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment(dx, 0),
                              // Position de debut du degrade.
                              end: Alignment(dx + 0.5, 0),
                              // Position de fin (bande de 0.5 de large).
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.15),
                                // Bande blanche a 15%.
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcATop,
                          // "srcATop" : le shader se melange par-dessus.
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            // Fond tres leger pour que le ShaderMask
                            // ait quelque chose a colorer.
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// CLIPPER : Forme de carte a jouer avec cotes concaves
// =============================================================
//
// Les quatre cotes de la carte ne sont pas droits : ils sont
// legerement incurves vers l'interieur (concaves).
// Cela donne un look de carte a jouer premium / fantaisie.
//
// On utilise des courbes de Bezier quadratiques :
//   path.quadraticBezierTo(controlX, controlY, endX, endY)
//
// Le point de controle est decale vers l'interieur de la carte
// (de ~6px), ce qui courbe le segment vers l'interieur.
//
//        P1 ─────── controlTop ─────── P2
//        │                              │
//   controlLeft                   controlRight
//        │                              │
//        P4 ─────── controlBot ─────── P3
//
// =============================================================
class _PlayingCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    // "w" : largeur totale de la carte.
    final h = size.height;
    // "h" : hauteur totale de la carte.
    const r = 16.0;
    // "r" : rayon des coins arrondis.
    const concavity = 6.0;
    // "concavity" : decalage du point de controle vers l'interieur (en px).
    // Plus cette valeur est grande, plus les cotes sont creuses.

    final path = Path();

    // --- Debut : coin superieur gauche ---
    path.moveTo(r, 0);
    // On commence au bord superieur, decale de "r" pixels a droite
    // pour laisser la place au coin arrondi.

    // --- Bord superieur (de gauche a droite, concave vers le bas) ---
    path.quadraticBezierTo(
      w / 2,
      // Point de controle X : milieu horizontal.
      concavity,
      // Point de controle Y : decale vers le bas de 6px
      // (le bord se courbe legerement vers l'interieur).
      w - r,
      // Point final X : bord droit moins le rayon du coin.
      0,
      // Point final Y : y=0 (aligné avec le haut).
    );

    // --- Coin superieur droit (arc arrondi) ---
    path.quadraticBezierTo(w, 0, w, r);
    // De (w-r, 0) vers (w, r) avec un controle en (w, 0).
    // Cela arrondit le coin superieur droit.

    // --- Bord droit (de haut en bas, concave vers la gauche) ---
    path.quadraticBezierTo(
      w - concavity,
      // Point de controle X : decale vers la gauche de 6px.
      h / 2,
      // Point de controle Y : milieu vertical.
      w,
      // Point final X : bord droit.
      h - r,
      // Point final Y : bord inferieur moins le rayon du coin.
    );

    // --- Coin inferieur droit (arc arrondi) ---
    path.quadraticBezierTo(w, h, w - r, h);
    // De (w, h-r) vers (w-r, h) avec un controle en (w, h).

    // --- Bord inferieur (de droite a gauche, concave vers le haut) ---
    path.quadraticBezierTo(
      w / 2,
      // Point de controle X : milieu horizontal.
      h - concavity,
      // Point de controle Y : decale vers le haut de 6px.
      r,
      // Point final X : bord gauche plus le rayon du coin.
      h,
      // Point final Y : bord inferieur.
    );

    // --- Coin inferieur gauche (arc arrondi) ---
    path.quadraticBezierTo(0, h, 0, h - r);
    // De (r, h) vers (0, h-r) avec un controle en (0, h).

    // --- Bord gauche (de bas en haut, concave vers la droite) ---
    path.quadraticBezierTo(
      concavity,
      // Point de controle X : decale vers la droite de 6px.
      h / 2,
      // Point de controle Y : milieu vertical.
      0,
      // Point final X : bord gauche.
      r,
      // Point final Y : haut plus le rayon du coin.
    );

    // --- Coin superieur gauche (arc arrondi) ---
    path.quadraticBezierTo(0, 0, r, 0);
    // De (0, r) vers (r, 0) avec un controle en (0, 0).

    path.close();
    // "close()" : ferme le chemin en reliant le dernier point au premier.
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
  // "false" : la forme ne change jamais, pas besoin de recalculer.
}

// =============================================================
// PAINTER : Ligne decorative avec losange central
// =============================================================
//
// Dessine :
//   ────────── ◇ ──────────
// Une ligne horizontale fine avec un petit carre tourne a 45°
// au centre (losange/diamant).
//
// Rappelle les separateurs decoratifs des jeux de cartes.
// =============================================================
class _DiamondLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    // Centre horizontal du widget.
    final centerY = size.height / 2;
    // Centre vertical du widget.
    const diamondSize = 5.0;
    // Demi-diagonale du losange (5px).

    // --- Peinture pour la ligne et le losange ---
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      // Blanc a 20% d'opacite : subtil mais visible.
      ..strokeWidth = 0.8
      // Ligne tres fine (0.8px).
      ..style = PaintingStyle.stroke;
    // "PaintingStyle.stroke" : dessine le contour, pas le remplissage.

    // --- Ligne gauche (du bord gauche au losange) ---
    canvas.drawLine(
      Offset(0, centerY),
      Offset(centerX - diamondSize - 4, centerY),
      // S'arrete 4px avant le losange pour un petit espace.
      paint,
    );

    // --- Ligne droite (du losange au bord droit) ---
    canvas.drawLine(
      Offset(centerX + diamondSize + 4, centerY),
      // Commence 4px apres le losange.
      Offset(size.width, centerY),
      paint,
    );

    // --- Losange central (carre tourne a 45°) ---
    final diamondPath = Path()
      ..moveTo(centerX, centerY - diamondSize)
      // Sommet haut du losange.
      ..lineTo(centerX + diamondSize, centerY)
      // Sommet droit.
      ..lineTo(centerX, centerY + diamondSize)
      // Sommet bas.
      ..lineTo(centerX - diamondSize, centerY)
      // Sommet gauche.
      ..close();
    // Ferme le losange.

    canvas.drawPath(diamondPath, paint);
    // Dessine le contour du losange.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  // Le dessin est statique, pas besoin de repeindre.
}

// =============================================================
// PAINTER : Particules ambiantes bleues/violettes
// =============================================================
//
// Dessine 25 particules semi-transparentes qui derivent lentement.
// Le "tick" (valeur du controleur de flottement) fait bouger
// les particules a chaque frame.
//
// Chaque particule est un cercle flou (shadowBlur) avec une
// couleur alternant entre bleu (#42A5F5) et violet (#667EEA).
//
// Le mouvement est base sur sin/cos pour un deplacement circulaire
// naturel, pas lineaire.
// =============================================================
class _AmbientParticlePainter extends CustomPainter {
  /// Les donnees des particules (position, taille, vitesse...).
  final List<_Particle> particles;

  /// Valeur entre 0.0 et 1.0, liee au controleur de flottement.
  /// Sert d'horloge pour animer les positions.
  final double tick;

  const _AmbientParticlePainter({
    required this.particles,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Pour chaque particule, on calcule sa position actuelle.

      // Position X : combine la position de base avec un sinus
      // pour un mouvement oscillatoire horizontal.
      final dx = (p.x + sin(tick * pi * 2 * p.speed) * 0.02) * size.width;
      // "sin(tick * pi * 2 * p.speed)" : oscille entre -1 et 1.
      // "* 0.02" : amplitude tres faible (2% de la largeur).
      // "* size.width" : convertit la fraction en pixels.

      // Position Y : combine la position de base avec un cosinus
      // pour un mouvement oscillatoire vertical (dephasé de 90°).
      final dy = (p.y + cos(tick * pi * 2 * p.speed) * 0.03) * size.height;
      // "cos" au lieu de "sin" : les axes X et Y oscillent differemment,
      // ce qui cree un mouvement circulaire/elliptique.

      // Couleur de la particule : bleu ou violet selon isBlue.
      final color = p.isBlue
          ? const Color(0xFF42A5F5).withValues(alpha: p.alpha)
          // Bleu clair a l'opacite de la particule.
          : const Color(0xFF667EEA).withValues(alpha: p.alpha);
      // Violet a l'opacite de la particule.

      final paint = Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 1.5);
      // "MaskFilter.blur" : applique un flou gaussien au cercle.
      // Le rayon du flou est 1.5x le rayon de la particule,
      // ce qui donne un aspect diffus comme un "orbe" lumineux.

      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
      // Dessine un cercle flou a la position calculee.
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientParticlePainter oldDelegate) {
    return oldDelegate.tick != tick;
    // On repeint uniquement si le tick a change (chaque frame).
  }
}

// =============================================================
// MODELE : Donnees d'une particule ambiante
// =============================================================
// Chaque particule a :
//   - x, y : position initiale (fraction 0.0 a 1.0)
//   - radius : taille en pixels
//   - speed : vitesse de derive
//   - alpha : opacite
//   - isBlue : couleur (bleu ou violet)
// =============================================================
class _Particle {
  final double x;
  // Position X initiale (0.0 = gauche, 1.0 = droite).
  final double y;
  // Position Y initiale (0.0 = haut, 1.0 = bas).
  final double radius;
  // Rayon de la particule en pixels.
  final double speed;
  // Vitesse de derive (affecte la frequence de l'oscillation).
  final double alpha;
  // Opacite de la particule (0.0 = invisible, 1.0 = opaque).
  final bool isBlue;
  // true = bleu (#42A5F5), false = violet (#667EEA).

  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.alpha,
    required this.isBlue,
  });
}
