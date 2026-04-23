// =============================================================
// FICHIER : lib/presentation/wireframes/t_activation_page.dart
// ROLE   : Activation du deck avec design PREMIUM carte a jouer
// COUCHE : Presentation > Wireframes
// =============================================================
//
// DESIGN : PAGE D'ACTIVATION PREMIUM STYLE HEARTHSTONE / MARVEL SNAP
// -------------------------------------------------------------------
// Inspiree des menus de jeux de cartes haut de gamme :
//   - Hearthstone : effet de profondeur, brillances dorees
//   - Marvel Snap : cartes trapezoidales, animations fluides
//   - Legends of Runeterra : particules ambiantes, atmospheriques
//
// ARCHITECTURE VISUELLE (couches de Stack, du fond au premier plan) :
//   1. Degrade multi-couche profond (bleu nuit → violet → bleu marine)
//   2. Particules ambiantes or/orange (CustomPainter + Ticker)
//   3. Spotlight radial anime (balayage lent sin/cos)
//   4. Contenu scrollable (header, code input, grille, bouton, aide)
//
// ANIMATIONS :
//   - _particleController : anime les 35 particules flottantes
//   - _spotlightController : deplace le centre du spotlight
//   - _shimmerController : effet de brillance sur les cartes verrouillees
//   - _pulseController : pulsation du bouton et de la bordure du code
//   - _entryController : entree echelonnee des cartes de la grille
//   - _codeEntryController : fade-in du champ de saisie du code
//
// FLOW : Auth → [CETTE PAGE] → GameModePage → Home
// =============================================================

import 'dart:math';
// "dart:math" fournit :
//   - sin(), cos() : fonctions trigonometriques pour le spotlight anime
//   - pi : constante pi (3.14159...) pour les rotations
//   - Random : generateur de nombres aleatoires pour les particules

import 'dart:ui';
// "dart:ui" fournit :
//   - ImageFilter.blur() : flou gaussien pour le "frosted glass"
//   - lerpDouble() : interpolation lineaire entre deux doubles

import 'package:flutter/material.dart';
// Le framework Flutter complet : widgets, animations, peinture, etc.

import 'package:google_fonts/google_fonts.dart';
// Permet d'utiliser les polices Google (Rajdhani, Exo 2) sans les
// telecharger manuellement. Mise en cache automatique apres 1er usage.

import 'package:trialgo/presentation/wireframes/t_theme.dart';
// Theme centralise : couleurs, degrades, styles de texte de TRIALGO.

import 'package:trialgo/presentation/wireframes/t_auth_page.dart';
// Page d'authentification (destination du bouton retour).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trialgo/presentation/providers/profile_provider.dart';
import 'package:trialgo/presentation/wireframes/t_graph_loading_page.dart';
// Page de choix du mode de jeu (destination apres activation reussie).


// =============================================================
// MODELE : Particule ambiante
// =============================================================
// Chaque particule est un petit point dore/orange qui flotte
// lentement vers le haut en arriere-plan, creant une atmosphere
// magique et premium comme dans les menus de Hearthstone.
//
// Proprietes :
//   - x, y : position actuelle (normalisee 0.0 → 1.0)
//   - speed : vitesse de montee (differente pour chaque particule)
//   - radius : taille du point (1-3 pixels)
//   - opacity : transparence (0.4 → 0.6)
// =============================================================

class _Particle {
  double x;       // Position horizontale normalisee (0.0 = gauche, 1.0 = droite).
  double y;       // Position verticale normalisee (0.0 = haut, 1.0 = bas).
  double speed;   // Vitesse de montee (plus petit = plus lent).
  double radius;  // Rayon du point en pixels logiques.
  double opacity; // Transparence du point (0.0 = invisible, 1.0 = opaque).

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.opacity,
  });
}


// =============================================================
// WIDGET PRINCIPAL : TActivationPage
// =============================================================
// StatefulWidget car la page contient :
//   - Des AnimationController (besoin de TickerProviderStateMixin)
//   - Un TextEditingController (saisie du code)
//   - Un etat mutable (_isActivating, _unlockedIndex)
// =============================================================

/// Page d'activation immersive avec design premium style jeu de cartes.
///
/// Le joueur voit les 6 univers de cartes disponibles (tous grises sauf
/// le premier), saisit le code imprime dans sa boite physique, et l'animation
/// de deverrouillage se joue avant la navigation vers le choix du mode.
class TActivationPage extends ConsumerStatefulWidget {
  const TActivationPage({super.key});

  @override
  ConsumerState<TActivationPage> createState() => _TActivationPageState();
}


// =============================================================
// STATE : _TActivationPageState
// =============================================================
// TickerProviderStateMixin fournit plusieurs Tickers (horloges)
// pour animer simultanement les particules, le spotlight, le shimmer,
// la pulsation, l'entree echelonnee et le fade-in du code.
//
// Un Ticker appelle un callback a chaque frame (~60 fps) pour
// mettre a jour les valeurs d'animation.
// =============================================================

class _TActivationPageState extends ConsumerState<TActivationPage>
    with TickerProviderStateMixin {

  // ---------------------------------------------------------------
  // CONTROLEURS DE SAISIE
  // ---------------------------------------------------------------

  /// Controleur du champ texte du code d'activation.
  /// Permet de lire la valeur saisie (_codeController.text) et
  /// de reagir aux changements via onChanged.
  final _codeController = TextEditingController();

  // ---------------------------------------------------------------
  // ETAT MUTABLE
  // ---------------------------------------------------------------

  /// True pendant la simulation d'appel reseau (activation en cours).
  bool _isActivating = false;

  /// Index du deck qui vient d'etre debloque (null = aucun).
  int? _unlockedIndex;

  /// True quand le bouton est presse (effet de scale 0.95).
  bool _isButtonPressed = false;

  /// Liste des jeux charges depuis Supabase (table "games").
  /// Format : Map avec les cles attendues par l'UI existante
  /// (name, description, color, imageUrl, isUnlocked, cardCount).
  /// Vide tant que le chargement n'a pas eu lieu.
  List<Map<String, dynamic>> _gamesFromDb = [];

  // ---------------------------------------------------------------
  // PARTICULES AMBIANTES (35 points dores flottants)
  // ---------------------------------------------------------------
  // La liste est generee une seule fois dans initState().
  // Le _particleController fait avancer les particules a chaque frame.
  // ---------------------------------------------------------------

  /// Liste des 35 particules ambiantes.
  final List<_Particle> _particles = [];

  /// Controleur d'animation pour les particules (boucle infinie de 10s).
  late AnimationController _particleController;

  // ---------------------------------------------------------------
  // SPOTLIGHT RADIAL ANIME
  // ---------------------------------------------------------------
  // Un cercle de lumiere douce qui se deplace lentement sur le fond
  // en suivant une trajectoire circulaire (sin/cos).
  // ---------------------------------------------------------------

  /// Controleur du spotlight (cycle complet en 8 secondes).
  late AnimationController _spotlightController;

  // ---------------------------------------------------------------
  // SHIMMER SUR LES CARTES VERROUILLEES
  // ---------------------------------------------------------------
  // Un bandeau diagonal blanc semi-transparent qui balaye les cartes
  // grisees toutes les 3 secondes, suggerant qu'elles sont deblocables.
  // ---------------------------------------------------------------

  /// Controleur du shimmer (cycle de 3 secondes, repete a l'infini).
  late AnimationController _shimmerController;

  // ---------------------------------------------------------------
  // PULSATION DU BOUTON ET DE LA BORDURE DU CODE
  // ---------------------------------------------------------------
  // Quand le code est assez long (>= 4 chars), la bordure du champ
  // et l'ombre du bouton pulsent entre deux intensites.
  // ---------------------------------------------------------------

  /// Controleur de pulsation (1.8s aller-retour).
  late AnimationController _pulseController;

  /// Animation lineaire 0.0 → 1.0 → 0.0 avec easing.
  late Animation<double> _pulseAnim;

  // ---------------------------------------------------------------
  // ENTREE ECHELONNEE DES CARTES DE LA GRILLE
  // ---------------------------------------------------------------
  // Les 6 cartes apparaissent une par une en glissant depuis le bas,
  // avec un delai croissant (0ms, 50ms, 100ms, 150ms, 200ms, 250ms).
  // Cela cree un effet "cascade" tres satisfaisant visuellement.
  // ---------------------------------------------------------------

  /// Controleur de l'animation d'entree (800ms au total).
  late AnimationController _entryController;

  // ---------------------------------------------------------------
  // FADE-IN DU CHAMP DE CODE
  // ---------------------------------------------------------------
  // Le champ de saisie apparait en glissant depuis le haut avec
  // un fondu d'opacite (slide down + fade in).
  // ---------------------------------------------------------------

  /// Controleur du fade-in du code (600ms).
  late AnimationController _codeEntryController;

  /// Animation 0.0 → 1.0 avec courbe deceleration.
  late Animation<double> _codeEntryAnim;


  // =============================================================
  // INIT STATE : Initialisation de tous les controleurs
  // =============================================================

  @override
  void initState() {
    super.initState();
    // super.initState() doit etre appele en premier pour initialiser
    // le TickerProviderStateMixin correctement.

    // Charger la liste des jeux depuis Supabase au demarrage.
    // La liste remplacera le mock deck data.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGamesFromDb());

    // --- Generer les 35 particules avec des positions aleatoires ---
    // Chaque particule a des proprietes uniques pour eviter un motif
    // repetitif. Random() sans seed donne des valeurs differentes a
    // chaque lancement de l'application.
    final rng = Random();
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),           // Position X aleatoire (0.0 → 1.0).
        y: rng.nextDouble(),           // Position Y aleatoire (0.0 → 1.0).
        speed: 0.15 + rng.nextDouble() * 0.35,  // Vitesse entre 0.15 et 0.50.
        radius: 1.0 + rng.nextDouble() * 2.0,   // Rayon entre 1px et 3px.
        opacity: 0.4 + rng.nextDouble() * 0.2,  // Opacite entre 40% et 60%.
      ));
    }

    // --- Controleur des particules (boucle infinie, 10s par cycle) ---
    // La duration de 10s est arbitraire : chaque particule a sa propre
    // vitesse, donc le mouvement est continu et non synchronise.
    _particleController = AnimationController(
      vsync: this,   // "this" est le TickerProvider (fournit l'horloge).
      duration: const Duration(seconds: 10),
    )..repeat();
    // "..repeat()" demarre immediatement et boucle a l'infini.
    // A chaque frame, le listener (ajoute plus bas) met a jour les positions.

    _particleController.addListener(_updateParticles);
    // addListener : appele a chaque frame (~60 fps) pour deplacer les particules.

    // --- Controleur du spotlight (cycle de 8s, boucle infinie) ---
    _spotlightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    // Le spotlight utilise sin/cos sur _spotlightController.value * 2 * pi
    // pour decrire un cercle complet en 8 secondes.

    // --- Shimmer : cycle de 3 secondes en boucle ---
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    // Le shimmer est un bandeau diagonal qui traverse les cartes verrouillees.

    // --- Pulsation : 1.8s aller-retour ---
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    // "reverse: true" fait osciller la valeur entre 0.0 et 1.0 puis retour.

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // CurvedAnimation applique une courbe d'acceleration/deceleration
    // pour rendre la pulsation plus organique (pas lineaire).

    // --- Entree echelonnee des cartes (800ms au total) ---
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    // "forward()" joue l'animation une seule fois (pas de repeat).

    // --- Fade-in du champ de code (600ms) ---
    _codeEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    // forward() lance l'animation du fade-in au chargement de la page.

    _codeEntryAnim = CurvedAnimation(
      parent: _codeEntryController,
      curve: Curves.easeOut,
    );
    // Curves.easeOut : demarre vite puis ralentit (deceleration naturelle).
  }


  // =============================================================
  // MISE A JOUR DES PARTICULES (appelee a chaque frame)
  // =============================================================
  // Chaque particule monte d'un increment proportionnel a sa vitesse.
  // Quand elle sort par le haut (y < 0), elle reapparait en bas (y = 1).
  // C'est le principe du "wrapping" (bouclage vertical).
  // =============================================================

  void _updateParticles() {
    for (final p in _particles) {
      // Deplacer vers le haut : soustraire une fraction de la vitesse.
      // 0.0005 est le facteur de base pour un mouvement tres lent.
      p.y -= p.speed * 0.0005;

      // Si la particule sort par le haut, la replacer en bas.
      if (p.y < 0) {
        p.y = 1.0;
        // Optionnel : repositionner X aleatoirement pour varier le motif.
        p.x = Random().nextDouble();
      }
    }
  }


  // =============================================================
  // DISPOSE : Nettoyage des controleurs
  // =============================================================
  // REGLE D'OR : chaque AnimationController cree dans initState()
  // doit etre dispose() ici pour eviter les fuites memoire.
  // Si oublie, le Ticker continue de tourner meme apres la
  // destruction du widget, causant des erreurs "ticker was not
  // disposed" dans la console.
  // =============================================================

  @override
  void dispose() {
    _codeController.dispose();
    _particleController.removeListener(_updateParticles);
    _particleController.dispose();
    _spotlightController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    _codeEntryController.dispose();
    super.dispose();
    // super.dispose() en dernier pour respecter le contrat de State.
  }


  // =============================================================
  // BUILD : Construction de l'arbre de widgets
  // =============================================================
  // L'arbre visuel est un Stack avec 4 couches :
  //   1. Degrade multi-couche (Container avec BoxDecoration)
  //   2. Particules ambiantes (CustomPaint avec AnimatedBuilder)
  //   3. Spotlight radial anime (AnimatedBuilder avec Container)
  //   4. Contenu scrollable (SafeArea + SingleChildScrollView)
  // =============================================================

  @override
  Widget build(BuildContext context) {
    // La liste des jeux vient de Supabase (chargee dans initState).
    // Tant que le fetch n'a pas termine, _gamesFromDb est vide.
    final decks = _gamesFromDb;

    return Scaffold(
      // Scaffold fournit la structure de base Material (body, snackbar, etc.).
      body: Stack(
        // Stack empile les enfants les uns sur les autres.
        // Le premier enfant est le plus en arriere (fond).
        children: [

          // =====================================================
          // COUCHE 1 : DEGRADE MULTI-COUCHE PROFOND
          // =====================================================
          // Trois couleurs qui creent une profondeur visuelle :
          //   #0A0A1A (bleu nuit tres sombre) en haut a gauche
          //   #1A1035 (violet profond) au centre
          //   #0D1B2A (bleu marine) en bas a droite
          // L'orientation diagonale (topLeft → bottomRight) donne
          // une sensation de profondeur et de mouvement.
          // =====================================================
          Positioned.fill(
            // Positioned.fill : occupe tout l'espace du Stack parent.
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0A1A),  // Bleu nuit ultra-sombre.
                    Color(0xFF1A1035),  // Violet profond.
                    Color(0xFF0D1B2A),  // Bleu marine fonce.
                  ],
                ),
              ),
            ),
          ),

          // =====================================================
          // COUCHE 2 : PARTICULES AMBIANTES DOREES
          // =====================================================
          // Un CustomPainter dessine les 35 particules a chaque frame.
          // AnimatedBuilder ecoute le _particleController et rebuild
          // le CustomPaint a chaque tick (~60 fps).
          //
          // Les particules sont des cercles dores/orange de 1-3px
          // avec 40-60% d'opacite, flottant lentement vers le haut.
          // Elles creent l'ambiance "magique" des jeux de cartes.
          // =====================================================
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  // CustomPaint appelle le painter a chaque rebuild.
                  painter: _ParticlePainter(particles: _particles),
                );
              },
            ),
          ),

          // =====================================================
          // COUCHE 3 : SPOTLIGHT RADIAL ANIME
          // =====================================================
          // Un cercle de lumiere doree tres diffuse qui se deplace
          // lentement sur le fond en suivant une trajectoire
          // circulaire (sin/cos sur le temps).
          //
          // Cela cree un effet de "respiration lumineuse" subtil
          // qui rend le fond vivant sans distraire le joueur.
          // =====================================================
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _spotlightController,
              builder: (context, _) {
                // Calculer la position du centre du spotlight.
                // sin/cos decrivent un cercle quand le parametre
                // varie de 0 a 2*pi (un cycle complet).
                final t = _spotlightController.value * 2 * pi;
                final centerX = 0.5 + 0.3 * sin(t); // Oscille entre 0.2 et 0.8.
                final centerY = 0.4 + 0.2 * cos(t); // Oscille entre 0.2 et 0.6.

                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      // Le centre du gradient se deplace grace a Alignment.
                      // Alignment va de -1.0 (gauche/haut) a 1.0 (droite/bas).
                      center: Alignment(
                        (centerX - 0.5) * 2,  // Convertir 0-1 en -1 → +1.
                        (centerY - 0.5) * 2,
                      ),
                      radius: 0.8, // Rayon du cercle lumineux (80% de l'ecran).
                      colors: [
                        TTheme.gold.withValues(alpha: 0.06), // Centre : or faible.
                        Colors.transparent,                    // Bord : invisible.
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // =====================================================
          // COUCHE 4 : CONTENU SCROLLABLE
          // =====================================================
          // SafeArea evite les encoches et barres systeme.
          // SingleChildScrollView permet le defilement si le
          // contenu depasse la hauteur de l'ecran.
          // =====================================================
          // Contenu qui tient sur une page sans scroll.
          // Utilise Expanded + Column pour distribuer l'espace
          // verticalement sans overflow.
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // HEADER : Bouton retour + Titre.
                    _buildHeader(),

                    const SizedBox(height: 14),

                    // CHAMP DE SAISIE DU CODE.
                    _buildCodeInput(),

                    const SizedBox(height: 14),

                    // LABEL "UNIVERS DISPONIBLES".
                    _buildSectionLabel(decks),

                    const SizedBox(height: 10),

                    // GRILLE DES 6 DECKS — prend l'espace restant.
                    Expanded(
                      child: _buildDeckGrid(decks),
                    ),

                    const SizedBox(height: 10),

                    // BOUTON ACTIVER.
                    _buildActivateButton(),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // =============================================================
  // WIDGET : HEADER (bouton retour frosted + titre ombre)
  // =============================================================
  // Le bouton retour utilise un effet "frosted glass" :
  //   1. ClipRRect arrondit les coins
  //   2. BackdropFilter applique un flou sur le fond derriere
  //   3. Container avec blanc 5% donne l'effet de verre depoli
  //
  // Le titre utilise TextShadow orange pour un effet de lueur
  // chaleureuse qui rappelle la lumiere des cartes en jeu.
  // =============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        // --- Bouton retour avec frosted glass ---
        GestureDetector(
          // GestureDetector detecte le tap sans effet visuel Material.
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TAuthPage()),
          ),
          // pushReplacement : remplace la page actuelle dans la pile
          // de navigation (pas de bouton "back" possible apres).
          child: ClipRRect(
            // ClipRRect coupe le contenu aux coins arrondis AVANT
            // d'appliquer le BackdropFilter (sinon le flou deborde).
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              // BackdropFilter applique un filtre sur tout ce qui est
              // DERRIERE ce widget dans le Stack (les particules, le
              // degrade, le spotlight). Le flou de 10px cree l'effet
              // de verre depoli ("frosted glass").
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  // Fond blanc a 5% d'opacite : le verre est presque
                  // transparent mais visible grace au flou derriere.
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // --- Titre et sous-titre ---
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre principal avec ombre orange.
              Text(
                'Activez votre deck',
                style: GoogleFonts.rajdhani(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  // TextShadow : lueur orange diffuse derriere le texte.
                  // blurRadius 8 rend l'ombre tres douce et etalee.
                  shadows: [
                    Shadow(
                      color: TTheme.orange.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              // Sous-titre discret.
              Text(
                'Saisissez le code de votre boite de jeu',
                style: TTheme.bodyStyle(
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // =============================================================
  // WIDGET : CHAMP DE SAISIE DU CODE (design carte physique)
  // =============================================================
  // Le champ est concu comme une CARTE PHYSIQUE posee sur la table :
  //   - Bordure doree en degrade (2px) quand du texte est saisi
  //   - Fond sombre #0D0D20
  //   - Bandeau superieur avec coin coupe a 45 degres (ClipPath)
  //   - 4 points de progression (chaque 4 chars en remplit un)
  //   - TextField centre avec espacement large
  //   - Animation de pulsation de la bordure quand >= 4 chars
  //
  // Le tout est enveloppe dans un AnimatedBuilder lie au
  // _codeEntryAnim pour le fade-in/slide-down a l'ouverture,
  // et dans un autre AnimatedBuilder lie a _pulseAnim pour la
  // pulsation de la bordure doree.
  // =============================================================

  Widget _buildCodeInput() {
    final hasCode = _codeController.text.length >= 4;
    // hasCode : true si le joueur a saisi au moins 4 caracteres.
    // Utilise pour activer la pulsation et le bouton.

    // --- Fade-in + slide down du champ de code ---
    return AnimatedBuilder(
      animation: _codeEntryAnim,
      builder: (context, child) {
        return Opacity(
          // Opacite progressive de 0.0 (invisible) a 1.0 (visible).
          opacity: _codeEntryAnim.value,
          child: Transform.translate(
            // Glissement vertical : commence 20px au-dessus et descend a 0.
            offset: Offset(0, -20 * (1 - _codeEntryAnim.value)),
            child: child,
          ),
        );
      },

      // --- Pulsation de la bordure doree ---
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) {
          // Calculer le blur de l'ombre qui pulse entre 12 et 24.
          // lerpDouble interpole lineairement entre deux valeurs.
          final shadowBlur = hasCode
              ? lerpDouble(12, 24, _pulseAnim.value)!
              : 0.0;

          return Container(
            // Container EXTERIEUR : bordure doree en degrade.
            // L'astuce pour une bordure en degrade est d'utiliser
            // deux Containers imbriques : l'exterieur a le degrade
            // en fond, l'interieur (plus petit de 2px) couvre le reste.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: hasCode
                  ? LinearGradient(
                      colors: [
                        TTheme.gold.withValues(alpha: 0.8),
                        TTheme.orange.withValues(alpha: 0.6),
                        TTheme.gold.withValues(alpha: 0.8),
                      ],
                    )
                  : null,
              // Bordure simple quand pas de code.
              border: hasCode
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.08)),
              // Ombre doree pulsante quand le code est en cours de saisie.
              boxShadow: hasCode
                  ? [
                      BoxShadow(
                        color: TTheme.gold.withValues(
                          alpha: 0.15 + 0.1 * _pulseAnim.value,
                        ),
                        blurRadius: shadowBlur,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            // Padding de 2px = epaisseur de la bordure doree.
            padding: hasCode ? const EdgeInsets.all(2) : EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(hasCode ? 18 : 20),
              child: Container(
                // Container INTERIEUR : fond sombre de la carte.
                color: const Color(0xFF0D0D20),
                child: Column(
                  children: [
                    // --- Bandeau superieur avec coin coupe ---
                    // ClipPath utilise un CustomClipper pour couper
                    // le coin haut-droit a 45 degres, comme un pli
                    // de carte a jouer.
                    ClipPath(
                      clipper: _CornerCutClipper(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: hasCode
                                ? [
                                    TTheme.gold.withValues(alpha: 0.15),
                                    TTheme.orange.withValues(alpha: 0.08),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.04),
                                    Colors.white.withValues(alpha: 0.02),
                                  ],
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icone cle.
                            Icon(
                              Icons.vpn_key_rounded,
                              size: 16,
                              color: hasCode
                                  ? TTheme.gold
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                            const SizedBox(width: 8),
                            // Label "CODE D'ACTIVATION" en majuscules.
                            Text(
                              "CODE D'ACTIVATION",
                              style: GoogleFonts.rajdhani(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                                color: hasCode
                                    ? TTheme.gold
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            const Spacer(),
                            // --- 4 points de progression ---
                            // Chaque point se remplit quand le joueur
                            // tape 4 caracteres supplementaires.
                            // _codeController.text.length ~/ 4 donne
                            // le nombre de groupes de 4 chars saisis.
                            ...List.generate(
                              4,
                              (i) => Padding(
                                padding: const EdgeInsets.only(left: 3),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        i < (_codeController.text.length ~/ 4)
                                            ? TTheme.gold
                                            : Colors.white
                                                .withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Champ de texte principal ---
                    // Le TextField est le coeur de la "carte" d'activation.
                    // Style Rajdhani 800, 28px, espacement large (5) pour
                    // donner un aspect "code technique" solennel.
                    Stack(
                      children: [
                        // --- Vignette interieure (ombre sombre aux bords) ---
                        // Simule un effet d'ombre interieure pour donner
                        // de la profondeur a la carte.
                        Positioned.fill(
                          child: IgnorePointer(
                            // IgnorePointer : la vignette ne bloque pas
                            // les taps sur le TextField en dessous.
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 1.0,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // --- Le TextField lui-meme ---
                        TextField(
                          controller: _codeController,
                          style: GoogleFonts.rajdhani(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 5,
                          ),
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          // Forcer les majuscules pour le code d'activation.
                          maxLength: 19,
                          // 19 chars = format XXXX-XXXX-XXXX-XXXX.
                          decoration: InputDecoration(
                            hintText: 'XXXX-XXXX-XXXX-XXXX',
                            hintStyle: GoogleFonts.rajdhani(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.1),
                              letterSpacing: 4,
                            ),
                            counterText: '',
                            // Masquer le compteur de caracteres natif.
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          // setState force un rebuild pour mettre a jour
                          // les points de progression et l'etat du bouton.
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }


  // =============================================================
  // WIDGET : LABEL DE SECTION "UNIVERS DISPONIBLES"
  // =============================================================
  // Barre horizontale avec un accent orange a gauche, le texte
  // en majuscules au centre, et un badge "1/6 active" a droite.
  // =============================================================

  Widget _buildSectionLabel(List<Map<String, dynamic>> decks) {
    return Row(
      children: [
        // Barre verticale orange (accent visuel).
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: TTheme.accentGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        // Texte "UNIVERS DISPONIBLES" en micro style.
        Text('UNIVERS DISPONIBLES', style: TTheme.microStyle(alpha: 0.5)),
        const Spacer(),
        // Badge compteur.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: TTheme.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '1/${decks.length} active',
            style: TTheme.tagStyle(color: TTheme.gold, size: 10),
          ),
        ),
      ],
    );
  }


  // =============================================================
  // WIDGET : GRILLE DES 6 DECKS (3x2, cartes trapezoidales)
  // =============================================================
  // Chaque deck est represente par une carte en forme de trapeze
  // (plus large en bas qu'en haut) grace au _PlayingCardClipper.
  //
  // Cartes verrouillees :
  //   - Filtre de desaturation (grayscale) + 30% opacite
  //   - Shimmer diagonal (ShaderMask avec gradient anime)
  //   - Icone cadenas dans un cercle frosted
  //
  // Cartes debloquees :
  //   - Couleur pleine avec l'accent du deck
  //   - Bordure lumineuse animee (BoxShadow pulse)
  //   - Badge "ACTIF" en haut a droite
  //   - Decorations de coins (symbole en haut-gauche et bas-droite)
  //
  // Animation d'entree : chaque carte glisse depuis le bas avec
  // un delai croissant (staggered animation) grace a Interval.
  // =============================================================

  Widget _buildDeckGrid(List<Map<String, dynamic>> decks) {
    return GridView.builder(
      // Pas de shrinkWrap — le parent Expanded donne la contrainte.
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,        // 3 colonnes.
        crossAxisSpacing: 10,     // Espace horizontal entre les cartes.
        mainAxisSpacing: 10,      // Espace vertical entre les cartes.
        childAspectRatio: 0.72,   // Ratio plus large pour moins de hauteur.
      ),
      itemCount: decks.length,    // 6 decks au total.
      itemBuilder: (context, index) {
        final deck = decks[index];
        final isUnlocked = deck['isUnlocked'] as bool;
        final justUnlocked = _unlockedIndex == index;
        final color = Color(deck['color'] as int);
        final name = deck['name'] as String;

        // --- Animation d'entree echelonnee ---
        // Interval decoupe l'animation globale (0.0 → 1.0) en segments.
        // Chaque carte a un segment decale de 0.05 (environ 40ms a 800ms total).
        // "begin: delay" et "end: delay + 0.5" signifient que la carte
        // commence son animation a "delay" et la termine a "delay + 0.5".
        final delay = index * 0.05;
        final entryAnim = CurvedAnimation(
          parent: _entryController,
          curve: Interval(
            delay.clamp(0.0, 0.5),          // Debut (0.0, 0.05, 0.10, ...).
            (delay + 0.5).clamp(0.0, 1.0),  // Fin (0.5, 0.55, 0.60, ...).
            curve: Curves.easeOutCubic,      // Deceleration forte.
          ),
        );

        return AnimatedBuilder(
          animation: Listenable.merge([_shimmerController, entryAnim, _pulseAnim]),
          // Listenable.merge : ecouter plusieurs animations a la fois.
          // Rebuild quand l'une d'elles change (shimmer, entree, ou pulse).
          builder: (context, _) {
            return Opacity(
              // Fade-in pendant l'animation d'entree.
              opacity: entryAnim.value,
              child: Transform.translate(
                // Glissement vertical : commence 40px en dessous.
                offset: Offset(0, 40 * (1 - entryAnim.value)),
                child: _buildDeckCard(
                  deck: deck,
                  index: index,
                  isUnlocked: isUnlocked,
                  justUnlocked: justUnlocked,
                  color: color,
                  name: name,
                ),
              ),
            );
          },
        );
      },
    );
  }


  // =============================================================
  // WIDGET : UNE CARTE DE DECK INDIVIDUELLE
  // =============================================================
  // Chaque carte est clippee avec _PlayingCardClipper pour avoir
  // une forme trapezoidale (plus etroite en haut, plus large en bas).
  //
  // Structure interne (Stack) :
  //   1. Image reseau (fond complet, "full bleed")
  //   2. Gradient overlay (transparent → 80% noir en bas)
  //   3. Shimmer (cartes verrouillees uniquement)
  //   4. Icone cadenas (cartes verrouillees uniquement)
  //   5. Badge "ACTIF" (cartes debloquees uniquement)
  //   6. Nom et nombre de cartes (en bas)
  //   7. Decorations de coins (cartes debloquees uniquement)
  // =============================================================

  Widget _buildDeckCard({
    required Map<String, dynamic> deck,
    required int index,
    required bool isUnlocked,
    required bool justUnlocked,
    required Color color,
    required String name,
  }) {
    return AnimatedContainer(
      // AnimatedContainer interpole automatiquement entre les
      // anciens et nouveaux parametres de decoration (couleur,
      // ombre, bordure) quand justUnlocked passe a true.
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Bordure lumineuse animee pour les cartes debloquees.
        border: Border.all(
          color: isUnlocked || justUnlocked
              ? color.withValues(alpha: 0.5 + 0.2 * _pulseAnim.value)
              : Colors.white.withValues(alpha: 0.06),
          width: isUnlocked || justUnlocked ? 1.5 : 1,
        ),
        // Ombre coloree qui pulse pour les cartes debloquees.
        boxShadow: isUnlocked || justUnlocked
            ? [
                BoxShadow(
                  color: color.withValues(
                    alpha: 0.2 + 0.15 * _pulseAnim.value,
                  ),
                  blurRadius: 12 + 6 * _pulseAnim.value,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: ClipPath(
          // _PlayingCardClipper donne la forme trapezoidale.
          clipper: _PlayingCardClipper(),
          child: Stack(
            children: [
              // --- Image de fond du deck ---
              // ColorFiltered applique un filtre de desaturation
              // sur les cartes verrouillees (grayscale + 30% opacite).
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: isUnlocked || justUnlocked
                      ? const ColorFilter.mode(
                          Colors.transparent, BlendMode.multiply)
                      // Mode multiply avec transparent = pas de filtre.
                      : const ColorFilter.matrix(<double>[
                          // Matrice de desaturation (grayscale).
                          // Chaque ligne calcule un canal (R, G, B, A).
                          // Les coefficients 0.2126, 0.7152, 0.0722
                          // sont les poids de luminance perceptuelle.
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 0.3, 0, // Alpha a 30%.
                        ]),
                  child: Image.network(
                    deck['imageUrl'] as String,
                    fit: BoxFit.cover,
                    // BoxFit.cover : l'image couvre tout le conteneur
                    // en etant croppee si necessaire (pas de barres).
                    errorBuilder: (c, e, s) => Container(
                      color: color.withValues(alpha: 0.1),
                    ),
                    // errorBuilder : si l'image ne charge pas (pas de
                    // reseau), afficher un fond de couleur a la place.
                  ),
                ),
              ),

              // --- Overlay gradient pour lisibilite du texte ---
              // Transparent en haut, 80% noir en bas pour que le
              // nom du deck soit lisible sur n'importe quelle image.
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
              ),

              // --- Shimmer diagonal pour les cartes verrouillees ---
              // Un bandeau blanc semi-transparent qui balaye la carte
              // en diagonal toutes les 3 secondes.
              if (!isUnlocked && !justUnlocked)
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      // Le gradient se deplace de gauche a droite grace
                      // a _shimmerController.value (0.0 → 1.0).
                      return LinearGradient(
                        begin: Alignment(
                          -1.0 + 2.0 * _shimmerController.value,
                          -0.3,
                        ),
                        end: Alignment(
                          0.0 + 2.0 * _shimmerController.value,
                          0.3,
                        ),
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcATop,
                    // srcATop : le shimmer n'apparait que sur les pixels
                    // deja opaques (pas sur le fond transparent).
                    child: Container(color: Colors.white),
                  ),
                ),

              // --- Icone cadenas (cartes verrouillees) ---
              // Un cercle sombre avec une bordure blanche subtile,
              // centre sur la carte, contenant un cadenas.
              if (!isUnlocked && !justUnlocked)
                Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 16,
                    ),
                  ),
                ),

              // --- Badge "ACTIF" (cartes debloquees) ---
              if (isUnlocked || justUnlocked)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      'ACTIF',
                      style: GoogleFonts.rajdhani(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

              // --- Nom du deck et nombre de cartes (en bas) ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.rajdhani(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isUnlocked || justUnlocked
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${deck['cardCount']} cartes',
                        style: GoogleFonts.exo2(
                          fontSize: 9,
                          color: isUnlocked || justUnlocked
                              ? color
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Decoration coin haut-gauche (cartes debloquees) ---
              // Un petit symbole decoratif comme sur une vraie carte
              // a jouer (coin superieur gauche).
              if (isUnlocked || justUnlocked)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),

              // --- Decoration coin bas-droite (rotation 180 degres) ---
              // Symetrique du coin haut-gauche, tourne de 180 degres
              // comme sur une carte a jouer classique.
              if (isUnlocked || justUnlocked)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Transform.rotate(
                    angle: pi,
                    // pi radians = 180 degres (demi-tour complet).
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  // =============================================================
  // WIDGET : BOUTON ACTIVER (custom, shimmer, scale)
  // =============================================================
  // PAS un ElevatedButton standard. C'est un Container custom avec :
  //   - Gradient orange→or (TTheme.accentGradient)
  //   - Effet de scale 0.95 quand presse (GestureDetector)
  //   - Shimmer : bandeau blanc diagonal qui balaye toutes les 3s
  //   - Quand desactive : 30% opacite, pas d'ombre
  //   - Quand active : ombre orange qui pulse
  //
  // Le shimmer utilise un ShaderMask avec un LinearGradient anime
  // par _shimmerController. Le bandeau blanc fait 20% de la largeur
  // et se deplace de gauche a droite.
  // =============================================================

  Widget _buildActivateButton() {
    final hasCode = _codeController.text.length >= 4;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _shimmerController]),
      builder: (context, _) {
        return GestureDetector(
          // GestureDetector pour l'effet de scale sans ripple Material.
          onTapDown: (_) => setState(() => _isButtonPressed = true),
          // onTapDown : le doigt touche le bouton → scale 0.95.
          onTapUp: (_) {
            setState(() => _isButtonPressed = false);
            if (hasCode && !_isActivating) _activateCode();
            // Lancer l'activation uniquement si le code est assez long
            // et qu'aucune activation n'est deja en cours.
          },
          onTapCancel: () => setState(() => _isButtonPressed = false),
          // onTapCancel : le doigt glisse hors du bouton → annuler.
          child: AnimatedScale(
            // AnimatedScale interpole smoothly entre 1.0 et 0.95.
            scale: _isButtonPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedOpacity(
              // Opacite 30% quand desactive, 100% quand active.
              opacity: hasCode ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: TTheme.accentGradient,
                  borderRadius: BorderRadius.circular(18),
                  // Ombre orange pulsante quand active.
                  boxShadow: hasCode
                      ? [
                          BoxShadow(
                            color: TTheme.orange.withValues(
                              alpha: 0.3 + 0.15 * _pulseAnim.value,
                            ),
                            blurRadius: 20 + 8 * _pulseAnim.value,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ShaderMask(
                    // ShaderMask applique le shimmer par-dessus le contenu.
                    shaderCallback: (bounds) {
                      // Bandeau blanc diagonal qui se deplace de gauche a droite.
                      final shimmerValue = _shimmerController.value;
                      return LinearGradient(
                        begin: Alignment(-1.0 + 3.0 * shimmerValue, -0.5),
                        end: Alignment(-0.5 + 3.0 * shimmerValue, 0.5),
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: hasCode ? 0.2 : 0.0),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcATop,
                    child: Center(
                      child: _isActivating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_open_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'ACTIVER MON DECK',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  // =============================================================
  // LOGIQUE : Activation du code
  // =============================================================
  // Simule un appel reseau de 1.5s, puis :
  //   1. Marque le deck #1 (Ocean) comme debloque
  //   2. Affiche un SnackBar de confirmation
  //   3. Attend 1.8s pour que le joueur voie le feedback
  //   4. Navigue vers TGameModePage
  // =============================================================

  // =============================================================
  // CHARGEMENT DES JEUX DEPUIS SUPABASE
  // =============================================================
  // Remplace la liste hardcodee MockData.mockDecks par les vrais
  // jeux recuperes de la table "games" en BDD.
  //
  // Les jeux sont convertis au format attendu par _buildDeckCard
  // pour garder l'UI existante sans la modifier.
  //
  // Couleurs : palette fixe assignee cycliquement aux jeux selon
  // leur ordre dans la liste (premier = orange, deuxieme = bleu...).
  // =============================================================

  Future<void> _loadGamesFromDb() async {
    try {
      final data = await Supabase.instance.client
          .from('games')
          .select()
          .eq('is_active', true)
          .order('created_at');

      if (!mounted) return;

      // Palette de couleurs pour les jeux (cyclique).
      const palette = <int>[
        0xFFFF6B35, // Orange
        0xFF42A5F5, // Bleu
        0xFF66BB6A, // Vert
        0xFF80DEEA, // Cyan
        0xFFF7C948, // Or
        0xFFFF8A65, // Corail
      ];

      setState(() {
        _gamesFromDb = (data as List<dynamic>).asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value as Map<String, dynamic>;
          return {
            'id': row['id'] as String,
            'name': row['name'] as String,
            'description': (row['description'] as String?) ?? '',
            // cardCount : valeur affichage. Le vrai nombre vient du graphe.
            'cardCount': 50,
            // Image cover : si fournie, l'utiliser, sinon placeholder.
            'imageUrl': (row['cover_image'] as String?) ??
                'https://loremflickr.com/300/400/${row['theme'] ?? 'game'}?lock=$index',
            'color': palette[index % palette.length],
            // Tous les jeux sont "unlocked" dans cette page.
            // C'est le code d'activation qui valide l'acces reel.
            'isUnlocked': true,
          };
        }).toList();
      });
    } catch (e) {
      // Echec de chargement : on laisse la liste vide.
      // L'UI affichera simplement "aucun jeu" (ou le mock en fallback).
      if (mounted) {
        _showError('Erreur chargement jeux : $e');
      }
    }
  }

  /// Affiche un SnackBar d'erreur.
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _activateCode() async {
    // Passer en mode "chargement" pour afficher le spinner.
    setState(() => _isActivating = true);

    // Recuperer le code saisi (sans tirets/espaces).
    final code = _codeController.text
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .trim();

    try {
      // Appel du ProfileService qui utilise la fonction SQL activate_code().
      // Cette fonction gere TOUTE la logique :
      //   - Validation du code
      //   - Device binding (1er use, re-use, changement)
      //   - Compteur de changements (max 3)
      //   - Blocage apres max
      //   - Creation de l'entree user_games
      final profileService = ref.read(profileServiceProvider);
      final result = await profileService.activateCode(code);

      if (!mounted) return;

      if (!result.success) {
        setState(() => _isActivating = false);
        _showError(result.message);
        return;
      }

      // Activation reussie : recharger le profil dans le provider.
      await ref.read(profileProvider.notifier).reload();

      if (!mounted) return;

      // Marquer le deverrouillage visuel.
      setState(() {
        _isActivating = false;
        _unlockedIndex = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActivating = false);
      _showError('Erreur : $e');
      return;
    }

    // Afficher un SnackBar de confirmation avec animation.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deck active !',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Univers Ocean debloque',
                  style: GoogleFonts.exo2(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: TTheme.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );

    // Attendre que le joueur voie le feedback visuel.
    await Future.delayed(const Duration(milliseconds: 1800));

    // Naviguer vers la page de chargement du graphe.
    // Cette page synchronise les cards + nodes depuis Supabase
    // et construit le graphe en memoire avant d'afficher la home.
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TGraphLoadingPage()),
      );
    }
  }
}


// =============================================================
// CUSTOM PAINTER : Particules ambiantes dorees
// =============================================================
// Dessine les 35 particules comme des cercles dores/orange.
// Appele a chaque frame par AnimatedBuilder.
//
// Chaque particule est dessinee avec :
//   - Position : x * largeur, y * hauteur (normalise → pixels)
//   - Couleur : interpolation entre or et orange (alterne pair/impair)
//   - Opacite : la valeur stockee dans la particule
//   - Rayon : la valeur stockee dans la particule (1-3px)
// =============================================================

class _ParticlePainter extends CustomPainter {
  /// Liste des particules a dessiner.
  final List<_Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    // Preparer un Paint reutilisable (evite de creer un objet par particule).
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Alterner entre or et orange pour varier les teintes.
      // Les particules paires sont dorees, les impaires sont orangees.
      final baseColor = i.isEven ? TTheme.gold : TTheme.orange;

      paint.color = baseColor.withValues(alpha: p.opacity);
      // withValues(alpha:) remplace withOpacity() (syntaxe moderne Flutter).

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        // Convertir les coordonnees normalisees (0-1) en pixels.
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
  // "true" : toujours repeindre car les positions changent a chaque frame.
  // C'est le prix a payer pour des particules fluides.
}


// =============================================================
// CUSTOM CLIPPER : Coin coupe a 45 degres (bandeau du code)
// =============================================================
// Coupe le coin superieur droit du bandeau "CODE D'ACTIVATION"
// a 45 degres pour donner un aspect de carte a jouer premium.
//
// Le chemin (Path) suit le contour du rectangle mais remplace
// le coin haut-droit par une ligne diagonale.
//
// Avant : rectangle parfait
//   +-------------------+
//   |                   |
//   +-------------------+
//
// Apres : coin coupe
//   +---------------+
//   |                \
//   +-------------------+
// =============================================================

class _CornerCutClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // La taille de la coupe (20px de chaque cote du coin).
    const cut = 20.0;

    final path = Path()
      ..moveTo(0, 0)                              // Coin haut-gauche.
      ..lineTo(size.width - cut, 0)                // Haut jusqu'a la coupe.
      ..lineTo(size.width, cut)                    // Diagonale 45 degres.
      ..lineTo(size.width, size.height)            // Descente droite.
      ..lineTo(0, size.height)                     // Bas.
      ..close();                                   // Retour au depart.

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
  // "false" : la forme ne change jamais, pas besoin de recalculer.
}


// =============================================================
// CUSTOM CLIPPER : Forme de carte a jouer trapezoidale
// =============================================================
// Donne aux cartes de deck une forme legerement trapezoidale :
// plus etroite en haut, plus large en bas, avec des coins arrondis.
//
// Ce design est inspire de Marvel Snap ou les cartes ont une
// legere perspective qui les rend plus dynamiques.
//
// Le "inset" de 4px en haut retrecit le bord superieur.
// Les coins sont arrondis avec un rayon de 12px.
//
//     +------+        (bord superieur plus etroit)
//    /        \
//   /          \
//  +------------+     (bord inferieur pleine largeur)
// =============================================================

class _PlayingCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    // "inset" : de combien le haut est plus etroit que le bas.
    const inset = 4.0;
    // "r" : rayon des coins arrondis.
    const r = 12.0;

    final path = Path()
      // Coin haut-gauche (decale de "inset" vers la droite).
      ..moveTo(inset + r, 0)
      // Bord superieur (decale de "inset" des deux cotes).
      ..lineTo(size.width - inset - r, 0)
      // Coin haut-droit arrondi.
      ..quadraticBezierTo(size.width - inset, 0, size.width - inset, r)
      // Bord droit diagonal (de inset en haut a 0 en bas).
      ..lineTo(size.width, size.height - r)
      // Coin bas-droit arrondi.
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      // Bord inferieur (pleine largeur).
      ..lineTo(r, size.height)
      // Coin bas-gauche arrondi.
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      // Bord gauche diagonal (de 0 en bas a inset en haut).
      ..lineTo(inset, r)
      // Coin haut-gauche arrondi.
      ..quadraticBezierTo(inset, 0, inset + r, 0)
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
  // "false" : la forme est statique, pas besoin de recalculer.
}
