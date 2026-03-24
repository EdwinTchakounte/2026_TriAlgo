# TRIALGO - Note Technique Frontend

> Guide complet des syntaxes, patterns et logiques du wireframe Flutter.
> Ce document couvre chaque concept de code utilise dans le projet.
> Il prepare la transition vers l'integration backend Supabase.

---

## TABLE DES MATIERES

1. [Architecture du wireframe](#1-architecture-du-wireframe)
2. [Point d'entree et lancement](#2-point-dentree-et-lancement)
3. [Types de widgets](#3-types-de-widgets)
4. [Navigation entre pages](#4-navigation-entre-pages)
5. [Gestion d'etat](#5-gestion-detat)
6. [Animations](#6-animations)
7. [Layouts et responsive](#7-layouts-et-responsive)
8. [CustomPainter et dessin](#8-custompainter-et-dessin)
9. [Internationalisation (i18n)](#9-internationalisation-i18n)
10. [Theme et styles](#10-theme-et-styles)
11. [Patterns asynchrones](#11-patterns-asynchrones)
12. [Syntaxes Dart essentielles](#12-syntaxes-dart-essentielles)
13. [Composants UI recurrents](#13-composants-ui-recurrents)
14. [Logique du jeu](#14-logique-du-jeu)
15. [Preparation backend](#15-preparation-backend)

---

## 1. Architecture du wireframe

### Structure des fichiers

```
lib/presentation/wireframes/
├── t_wireframe_app.dart      # Point d'entree MaterialApp
├── t_app_state.dart          # Etat global (langue)
├── t_locale.dart             # Traductions FR/EN
├── t_theme.dart              # Couleurs, polices, background pattern
├── t_illustrations.dart      # Illustrations vectorielles custom
├── t_mock_data.dart          # Donnees fictives (cartes, user, scores)
│
├── t_splash_page.dart        # Ecran de chargement (30s)
├── t_auth_page.dart          # Connexion / Inscription
├── t_activation_page.dart    # Code d'activation
├── t_home_page.dart          # Menu principal (hub)
├── t_level_map_page.dart     # Carte des niveaux
├── t_game_page.dart          # Ecran de jeu (jouable)
├── t_game_result_page.dart   # Resultats fin de niveau
├── t_profile_page.dart       # Profil joueur
├── t_leaderboard_page.dart   # Classement
├── t_gallery_page.dart       # Galerie des cartes
├── t_tutorial_page.dart      # Tutoriel 4 pages
├── t_settings_page.dart      # Parametres + langue
├── t_edit_username_page.dart # Modifier le pseudo
├── t_avatar_page.dart        # Choisir un avatar
├── t_help_page.dart          # FAQ interactive
└── t_legal_page.dart         # Mentions legales
```

### Flux de navigation complet

```
SPLASH (30s, skip possible)
  └──> AUTH (connexion / inscription)
        └──> ACTIVATION (code physique)
              └──> HOME (hub central)
                    ├──> NIVEAUX ──> JEU ──> RESULTATS ──> JEU+1 / HOME
                    ├──> TUTORIEL (4 pages swipables)
                    ├──> GALERIE (E/C/R en onglets)
                    ├──> CLASSEMENT (podium + liste)
                    ├──> PROFIL (stats + historique)
                    └──> PARAMETRES
                          ├──> MODIFIER PSEUDO
                          ├──> CHOISIR AVATAR
                          ├──> AIDE & FAQ
                          ├──> MENTIONS LEGALES
                          └──> DECONNEXION ──> AUTH
```

---

## 2. Point d'entree et lancement

### main_wireframe.dart

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TWireframeApp());
}
```

**`WidgetsFlutterBinding.ensureInitialized()`** : initialise le moteur Flutter.
Obligatoire si du code s'execute avant `runApp()` (ex: Supabase.initialize).
Ici c'est une bonne pratique preventive.

### TWireframeApp - le widget racine

```dart
class TWireframeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,          // Ecoute les changements de langue
      builder: (context, _) {
        return TLocale(
          language: appState.language, // Injecte la langue dans l'arbre
          child: MaterialApp(
            theme: TTheme.themeData,   // Theme sombre gaming
            home: const TSplashPage(), // Premier ecran
          ),
        );
      },
    );
  }
}
```

**Pourquoi cette structure ?**

1. `ListenableBuilder` ecoute `appState` (ChangeNotifier)
2. Quand la langue change, il reconstruit TOUT l'arbre
3. `TLocale` (InheritedWidget) injecte la langue disponible partout
4. `MaterialApp` fournit le theme et la navigation

**Commande de lancement :**
```bash
flutter run -t lib/main_wireframe.dart
```

---

## 3. Types de widgets

### StatelessWidget - widget sans etat

```dart
class TLeaderboardPage extends StatelessWidget {
  const TLeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Reconstruit a chaque appel. Pas d'etat interne.
    return Scaffold(body: ...);
  }
}
```

**Quand l'utiliser :** la page affiche des donnees sans interaction qui change l'apparence.
Exemples : profil, classement, mentions legales.

### StatefulWidget - widget avec etat

```dart
class TAuthPage extends StatefulWidget {
  const TAuthPage({super.key});

  @override
  State<TAuthPage> createState() => _TAuthPageState();
}

class _TAuthPageState extends State<TAuthPage> {
  // Variables d'etat local.
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    // Utilise _isLogin et _obscurePassword pour le rendu.
    return Scaffold(body: ...);
  }
}
```

**Quand l'utiliser :** la page a des interactions qui changent l'affichage
(toggles, formulaires, animations, timers).

### setState - declencher une reconstruction

```dart
// Quand le joueur tape sur le toggle login/signup :
GestureDetector(
  onTap: () {
    setState(() {
      _isLogin = !_isLogin;  // Inverse la valeur.
    });
    // Flutter reconstruit build() avec la nouvelle valeur.
  },
)
```

**Regle fondamentale :** ne jamais modifier l'etat en dehors de setState().
Si on ecrit `_isLogin = !_isLogin` sans setState, l'ecran ne se redessine pas.

### Mixins pour les animations

```dart
class _THomePageState extends State<THomePage>
    with SingleTickerProviderStateMixin {
  // "with" ajoute un mixin a la classe.
  // SingleTickerProviderStateMixin fournit UN Ticker
  // (signal qui pulse a 60 fps) necessaire pour AnimationController.
}
```

Si on a PLUSIEURS AnimationController, utiliser `TickerProviderStateMixin` :
```dart
class _TGamePageState extends State<TGamePage>
    with TickerProviderStateMixin {
  // Fournit PLUSIEURS Tickers.
}
```

---

## 4. Navigation entre pages

### push - empiler un ecran

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const TProfilePage()),
);
```

**Effet :** la nouvelle page glisse par-dessus. Le bouton retour revient a l'ecran precedent.
**Pile :** `[Home, Profile]`

### pop - retirer l'ecran courant

```dart
Navigator.of(context).pop();
```

**Effet :** retire l'ecran courant et revient au precedent.
**Pile :** `[Home, Profile]` → `[Home]`

### pushReplacement - remplacer l'ecran courant

```dart
Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => const THomePage()),
);
```

**Effet :** l'ecran courant est DETRUIT et remplace par le nouveau.
Le bouton retour ne revient PAS a l'ancien ecran.
**Usage :** Splash → Auth, Auth → Activation, Activation → Home.

**PIEGE COURANT :** si on fait `pushReplacement` de A vers B,
puis `pop()` dans B, l'app crash (ecran noir) car il n'y a rien en dessous.
Solution : utiliser `pushReplacement` vers un ecran connu au lieu de `pop()`.

### pushAndRemoveUntil - vider toute la pile

```dart
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (_) => const TAuthPage()),
  (route) => false,  // Supprime TOUTES les routes.
);
```

**Effet :** vide completement la pile de navigation et place le nouvel ecran.
**Usage :** deconnexion (retour a auth depuis n'importe ou).

### PageRouteBuilder - transition personnalisee

```dart
Navigator.of(context).pushReplacement(
  PageRouteBuilder(
    pageBuilder: (c, a1, a2) => const TAuthPage(),
    transitionDuration: const Duration(milliseconds: 800),
    transitionsBuilder: (c, animation, a2, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  ),
);
```

**Effet :** au lieu du slide par defaut, la page apparait en fondu.
Utilise pour le splash → auth (transition cinematique).

---

## 5. Gestion d'etat

### Niveau 1 : setState (etat local)

```dart
// Etat qui ne concerne QU'UN SEUL widget.
bool _soundOn = true;

Switch.adaptive(
  value: _soundOn,
  onChanged: (v) => setState(() => _soundOn = v),
)
```

**Quand :** toggle, formulaire, selection, compteur local.
**Limite :** l'etat disparait quand le widget est detruit (navigation).

### Niveau 2 : ChangeNotifier (etat global)

```dart
// t_app_state.dart
class AppState extends ChangeNotifier {
  AppLanguage _language = AppLanguage.fr;
  AppLanguage get language => _language;

  void setLanguage(AppLanguage lang) {
    if (_language != lang) {
      _language = lang;
      notifyListeners(); // Signal aux ecouteurs de reconstruire.
    }
  }
}

final appState = AppState(); // Instance globale (singleton).
```

**Ecouter dans l'UI :**
```dart
ListenableBuilder(
  listenable: appState,
  builder: (context, _) {
    // Ce builder est rappele a chaque notifyListeners().
    return Text(appState.language == AppLanguage.fr ? 'Bonjour' : 'Hello');
  },
)
```

**Quand :** etat partage entre plusieurs pages (langue, theme, session user).
**Migration Riverpod :** `final appStateProvider = ChangeNotifierProvider((_) => AppState());`

### Niveau 3 : InheritedWidget (injection de dependance)

```dart
// t_locale.dart
class TLocale extends InheritedWidget {
  final AppLanguage language;

  const TLocale({required this.language, required super.child, super.key});

  // Methode statique pour acceder depuis n'importe quel widget enfant.
  static String Function(String key) of(BuildContext context) {
    final locale = context.dependOnInheritedWidgetOfExactType<TLocale>()!;
    final strings = locale.language == AppLanguage.fr ? _fr : _en;
    return (String key) => strings[key] ?? key;
  }

  @override
  bool updateShouldNotify(TLocale oldWidget) {
    return language != oldWidget.language;
    // Reconstruit les enfants SEULEMENT si la langue a change.
  }
}
```

**Usage dans n'importe quelle page :**
```dart
@override
Widget build(BuildContext context) {
  final tr = TLocale.of(context); // Recupere la fonction de traduction.
  return Text(tr('home.play'));   // "JOUER" en FR, "PLAY" en EN.
}
```

**Pourquoi InheritedWidget ?**
- Accessible depuis n'importe quel descendant sans passer de parametres
- Reconstruit automatiquement les widgets qui l'utilisent quand la valeur change
- C'est le pattern utilise par `Theme.of(context)`, `MediaQuery.of(context)`, etc.

---

## 6. Animations

### AnimationController - le moteur

```dart
late AnimationController _controller;

@override
void initState() {
  super.initState();
  _controller = AnimationController(
    vsync: this,                          // Lie au Ticker du widget.
    duration: const Duration(seconds: 3), // Duree totale.
  );
  _controller.forward();  // Lance de 0.0 vers 1.0.
}

@override
void dispose() {
  _controller.dispose();  // OBLIGATOIRE : libere les ressources.
  super.dispose();
}
```

**`vsync: this`** : synchronise l'animation avec le rafraichissement ecran (60 fps).
Evite de calculer des frames quand l'ecran n'est pas visible.

### Boucle infinie (pulse)

```dart
_controller = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 2000),
)..repeat(reverse: true);
// ".." cascade operator : appelle repeat() sur le meme objet.
// "reverse: true" : va de 0→1 puis 1→0 en boucle.
```

### Tween - definir les bornes

```dart
// La valeur passe de 0.3 a 0.7 sur la duree du controller.
final _pulseGlow = Tween<double>(begin: 0.3, end: 0.7).animate(
  CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
);
```

### CurvedAnimation - courbe d'acceleration

```dart
CurvedAnimation(parent: _controller, curve: Curves.easeOut)
// Demarre vite puis ralentit (deceleration naturelle).
```

Courbes disponibles :
- `Curves.easeIn` : lent puis rapide
- `Curves.easeOut` : rapide puis lent
- `Curves.easeInOut` : lent → rapide → lent
- `Curves.elasticOut` : rebond elastique
- `Curves.bounceOut` : rebond de balle

### Interval - phases dans une animation longue

```dart
// Le splash fait 30 secondes. Chaque phase a son intervalle :
_mascotFade = Tween<double>(begin: 0, end: 1).animate(
  CurvedAnimation(
    parent: _mainController,
    curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
    // De 0% a 10% du temps total (0s a 3s).
  ),
);

_logoFade = Tween<double>(begin: 0, end: 1).animate(
  CurvedAnimation(
    parent: _mainController,
    curve: const Interval(0.1, 0.2, curve: Curves.easeOut),
    // De 10% a 20% (3s a 6s).
  ),
);
```

### FadeTransition - fondu

```dart
FadeTransition(
  opacity: _fadeAnimation, // Animation<double> de 0 a 1.
  child: Text('Bonjour'),
)
// L'opacite du texte passe de 0 (invisible) a 1 (visible).
```

### ScaleTransition - zoom

```dart
ScaleTransition(
  scale: _scaleAnimation,
  child: Container(...),
)
// Le container grossit de 0 (point) a 1 (taille normale).
```

### AnimatedContainer - animation implicite

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  decoration: BoxDecoration(
    border: Border.all(
      color: isSelected ? Colors.amber : Colors.transparent,
      width: isSelected ? 3 : 1,
    ),
  ),
  child: ...,
)
// Quand isSelected change, la bordure anime automatiquement
// de transparent a amber en 200ms. Pas besoin d'AnimationController.
```

### AnimatedSwitcher - swap de widgets

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Text(
    _isLogin ? tr('auth.welcome_back') : tr('auth.join'),
    key: ValueKey(_isLogin),
    // La "key" DOIT changer pour que AnimatedSwitcher detecte
    // que le widget est different et joue l'animation.
  ),
)
```

### AnimatedBuilder - reconstruction a chaque frame

```dart
AnimatedBuilder(
  animation: _controller,
  builder: (context, _) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            // L'ombre pulse avec la valeur de l'animation.
            color: TTheme.orange.withValues(alpha: _pulseGlow.value),
            blurRadius: 30,
          ),
        ],
      ),
    );
  },
)
```

### Color.lerp - interpolation de couleur

```dart
Color.lerp(TTheme.orange, TTheme.gold, _pulseGlow.value)!
// A 0.0 : orange pur.
// A 0.5 : melange 50/50 orange + gold.
// A 1.0 : gold pur.
// Le "!" assure que le resultat n'est pas null.
```

---

## 7. Layouts et responsive

### Column + Row - les bases

```dart
Column(
  mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement.
  crossAxisAlignment: CrossAxisAlignment.start, // Aligne a gauche.
  children: [
    Text('Titre'),
    SizedBox(height: 8), // Espacement vertical.
    Text('Sous-titre'),
  ],
)

Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espace entre enfants.
  children: [
    Icon(Icons.star),
    Text('Score'),
    Text('4250'),
  ],
)
```

### Expanded vs Flexible

```dart
Row(
  children: [
    Expanded(
      flex: 3, // Prend 3 parts de l'espace disponible.
      child: Text('Long texte qui prend de la place'),
    ),
    SizedBox(width: 8),
    Expanded(
      flex: 1, // Prend 1 part (soit 25% total).
      child: Icon(Icons.arrow_forward),
    ),
  ],
)
```

**Expanded** : force l'enfant a remplir tout l'espace restant.
**Flexible** : permet a l'enfant de prendre MOINS que l'espace restant.

### Wrap - flow responsive

```dart
Wrap(
  spacing: 6,      // Espace horizontal entre les enfants.
  runSpacing: 4,   // Espace vertical entre les lignes.
  children: [
    _miniTag('Niv.7', Colors.blue),
    _miniTag('4250 pts', Colors.gold),
    _miniTag('#4', Colors.orange),
    // Si l'ecran est trop etroit, les tags passent a la ligne
    // au lieu de deborder (contrairement a Row qui overflow).
  ],
)
```

### LayoutBuilder - adaptation a l'espace reel

```dart
LayoutBuilder(
  builder: (context, constraints) {
    // constraints.maxWidth = largeur reelle disponible en pixels.
    final isNarrow = constraints.maxWidth < 280;

    if (isNarrow) {
      return Column(children: [heartsRow, timerWidget]);
    }
    return Row(children: [heartsRow, Spacer(), timerWidget]);
  },
)
```

**Quand :** adapter le layout selon la taille d'ecran sans MediaQuery.
Plus precis que MediaQuery car il mesure l'espace REEL du parent
(pas la taille totale de l'ecran).

### Stack + Positioned - superposition

```dart
Stack(
  children: [
    // Couche 1 : fond.
    Container(color: Colors.black),
    // Couche 2 : element positionne.
    Positioned(
      top: 10, right: 10,
      child: Icon(Icons.close),
    ),
    // Couche 3 : contenu centre.
    Positioned.fill(
      child: Center(child: Text('Centre')),
    ),
  ],
)
```

### SingleChildScrollView + ConstrainedBox

```dart
// Pattern anti-overflow pour les pages avec clavier :
SingleChildScrollView(
  physics: const ClampingScrollPhysics(),
  child: ConstrainedBox(
    constraints: BoxConstraints(minHeight: availableHeight),
    // minHeight garantit que le contenu remplit l'ecran
    // quand il est plus petit que l'ecran.
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [...],
    ),
  ),
)
```

### PageView - pages swipables

```dart
final _pageController = PageController();
int _currentPage = 0;

PageView(
  controller: _pageController,
  onPageChanged: (index) => setState(() => _currentPage = index),
  children: [page1, page2, page3, page4],
)

// Navigation programmatique :
_pageController.nextPage(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
);
```

### TabBar + TabBarView - onglets

```dart
late TabController _tabController;

@override
void initState() {
  super.initState();
  _tabController = TabController(length: 3, vsync: this);
}

// Dans build() :
TabBar(
  controller: _tabController,
  indicator: BoxDecoration(
    gradient: LinearGradient(colors: [orange, gold]),
    borderRadius: BorderRadius.circular(12),
  ),
  tabs: [Tab(text: 'E'), Tab(text: 'C'), Tab(text: 'R')],
)

TabBarView(
  controller: _tabController,
  children: [gridE, gridC, gridR],
)
```

### GridView.builder - grille dynamique

```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,          // 3 colonnes.
    crossAxisSpacing: 12,       // Espace horizontal.
    mainAxisSpacing: 12,        // Espace vertical.
    childAspectRatio: 0.75,     // Largeur / Hauteur (plus haut que large).
  ),
  itemCount: cards.length,
  itemBuilder: (context, index) => _buildCard(cards[index]),
)
```

---

## 8. CustomPainter et dessin

### Creer un painter

```dart
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke  // Contour seulement (pas rempli).
      ..strokeWidth = 0.6;

    // Dessiner un cercle :
    canvas.drawCircle(Offset(100, 100), 20, paint);

    // Dessiner une ligne :
    canvas.drawLine(Offset(0, 0), Offset(100, 100), paint);

    // Dessiner un rectangle arrondi :
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(50, 50), width: 20, height: 20),
        Radius.circular(4),
      ),
      paint,
    );

    // Dessiner un chemin (forme libre) :
    final path = Path()
      ..moveTo(50, 0)       // Deplacer sans tracer.
      ..lineTo(100, 100)    // Tracer une ligne.
      ..lineTo(0, 100)      // Autre ligne.
      ..close();            // Fermer le chemin.
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  // false = ne repeint jamais (le motif est statique).
  // true = repeint a chaque frame (utile pour les animations).
}
```

### Utiliser le painter

```dart
CustomPaint(
  painter: _PatternPainter(), // Dessine EN DESSOUS du child.
  child: SafeArea(child: ...),
)
```

### Le pattern de fond (TTheme.patterned)

```dart
static Widget patterned({required Widget child}) {
  return Container(
    decoration: const BoxDecoration(gradient: bgGradient),
    child: CustomPaint(
      painter: _PatternPainter(), // Grille de formes geometriques.
      child: child,
    ),
  );
}

// Usage dans chaque page :
Scaffold(
  body: TTheme.patterned(
    child: SafeArea(child: ...),
  ),
)
```

---

## 9. Internationalisation (i18n)

### Architecture

```
TWireframeApp
  └── ListenableBuilder (ecoute AppState.language)
        └── TLocale (InheritedWidget, injecte la langue)
              └── MaterialApp
                    └── Pages (appellent TLocale.of(context))
```

### Ajouter une traduction

1. Ouvrir `t_locale.dart`
2. Ajouter la cle dans `_fr` ET `_en` :

```dart
static const Map<String, String> _fr = {
  // ...
  'ma_page.mon_texte': 'Mon texte en francais',
};

static const Map<String, String> _en = {
  // ...
  'ma_page.mon_texte': 'My text in English',
};
```

3. Utiliser dans la page :
```dart
final tr = TLocale.of(context);
Text(tr('ma_page.mon_texte'))
```

### Convention de nommage des cles

```
{page}.{element}

Exemples :
  home.play          → Bouton JOUER sur la home
  game.question      → Texte de la question en jeu
  settings.logout    → Bouton deconnexion
  common.pts         → Texte "pts" utilise partout
```

### Changer la langue

```dart
// Depuis n'importe ou :
appState.setLanguage(AppLanguage.en);
// Toute l'app se reconstruit en anglais instantanement.
```

---

## 10. Theme et styles

### Couleurs centralisees

```dart
class TTheme {
  static const Color orange = Color(0xFFFF6B35);  // Accent principal
  static const Color gold   = Color(0xFFF7C948);  // Scores, etoiles
  static const Color blue   = Color(0xFF42A5F5);  // Emettrices, infos
  static const Color green  = Color(0xFF66BB6A);  // Receptrices, succes
  static const Color red    = Color(0xFFEF5350);  // Vies, erreurs
  static const Color bgDark = Color(0xFF0A0A1A);  // Fond le plus sombre
}
```

### Polices gaming (Google Fonts)

```dart
import 'package:google_fonts/google_fonts.dart';

// Rajdhani : titres, scores, boutons (style sci-fi)
static TextStyle titleStyle({Color color = Colors.white, double size = 26}) {
  return GoogleFonts.rajdhani(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
  );
}

// Exo 2 : texte courant, descriptions (style tech)
static TextStyle bodyStyle({Color? color, double size = 14}) {
  return GoogleFonts.exo2(
    fontSize: size,
    color: color ?? Colors.white.withValues(alpha: 0.6),
  );
}
```

### Degradees recurrents

```dart
// Fond global (3 couleurs verticales)
static const LinearGradient bgGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF0A0A1A), Color(0xFF12122A), Color(0xFF1A1A3E)],
);

// Boutons et accents (horizontal orange→gold)
static const LinearGradient accentGradient = LinearGradient(
  colors: [orange, Color(0xFFFF8F5E), gold],
);
```

### Texte en degrade (ShaderMask)

```dart
ShaderMask(
  shaderCallback: (bounds) => TTheme.accentGradient.createShader(bounds),
  child: Text('TRIALGO', style: TTheme.logoStyle()),
)
// Le texte est rempli avec le degrade au lieu d'une couleur unie.
```

---

## 11. Patterns asynchrones

### Future.delayed - attendre avant d'agir

```dart
Future.delayed(const Duration(milliseconds: 1800), () {
  if (!mounted) return; // Securite : le widget existe encore ?
  // Action apres le delai.
  Navigator.of(context).pushReplacement(...);
});
```

### async/await - operations sequentielles

```dart
Future<void> _activateCode() async {
  setState(() => _isActivating = true);   // 1. Afficher le spinner.

  await Future.delayed(Duration(ms: 1200)); // 2. Simuler un appel reseau.

  if (mounted) {                           // 3. Verifier que le widget existe.
    setState(() => _isActivating = false);
    Navigator.of(context).pushReplacement(...);
  }
}
```

### Timer.periodic - action repetee

```dart
Timer? _timer;

void _startTimer() {
  _timer?.cancel(); // Annuler le timer precedent.

  _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!mounted) { timer.cancel(); return; }

    setState(() {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
      } else {
        timer.cancel();
        _handleTimeout();
      }
    });
  });
}

@override
void dispose() {
  _timer?.cancel(); // TOUJOURS annuler dans dispose().
  super.dispose();
}
```

### Le guard `mounted`

```dart
if (mounted) {
  setState(() => ...);
}
```

**Pourquoi :** apres un `await` ou un `Future.delayed`, le widget peut avoir
ete detruit (le joueur a change de page). Appeler `setState` sur un widget
detruit cause un crash. `mounted` verifie qu'il est encore vivant.

---

## 12. Syntaxes Dart essentielles

### Null Safety

```dart
String? name;             // Peut etre null.
String name = 'Lion';     // Ne peut PAS etre null.
name?.length              // Appelle .length seulement si name != null.
name ?? 'Defaut'          // Si name est null, utilise 'Defaut'.
name!                     // Force : "je garantis que c'est pas null".
late String name;         // Sera initialise plus tard (avant utilisation).
```

### Spread operator (...)

```dart
Row(
  children: [
    Text('Label'),
    ...List.generate(5, (i) => Icon(Icons.star)),
    // "..." insere les 5 icones directement dans la liste du Row.
    // Sans "...", on aurait une List dans une List (erreur de type).
  ],
)
```

### Conditional spread (...if)

```dart
Row(
  children: [
    heartsRow,
    if (lives < maxLives) ...[
      const Spacer(),
      timerWidget,
    ],
    // Les 2 widgets sont ajoutes seulement si la condition est vraie.
  ],
)
```

### Cascade operator (..)

```dart
_controller = AnimationController(
  vsync: this,
  duration: const Duration(seconds: 2),
)..repeat(reverse: true);
// ".." appelle repeat() sur _controller et retourne _controller.
// Equivalent de :
//   _controller = AnimationController(...);
//   _controller.repeat(reverse: true);
```

### Switch expression

```dart
final Color timerColor = timerRatio > 0.6
    ? Colors.green
    : timerRatio > 0.3
        ? Colors.orange
        : Colors.red;
```

### Collection methods

```dart
// Filtrer et compter :
levels.where((l) => l['completed'] == true).length

// Prendre les N premiers :
leaderboard.take(3).toList()

// Ignorer les N premiers :
leaderboard.skip(3).toList()

// Transformer :
sessions.map((s) => _buildSessionTile(s))

// Limiter une valeur :
value.clamp(32.0, 48.0)  // Entre 32 et 48.
```

### Type casting

```dart
final username = user['username'] as String;
final level = user['currentLevel'] as int;
final passed = session['passed'] as bool;
```

### String interpolation

```dart
'Niveau $level'                    // Variable simple.
'${tr('common.level')} $level'     // Expression.
'${(_value * 100).toInt()}%'       // Calcul inline.
```

---

## 13. Composants UI recurrents

### Bouton degrade avec ombre

```dart
SizedBox(
  width: double.infinity, height: 54,
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [TTheme.orange, TTheme.gold]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: TTheme.orange.withValues(alpha: 0.4),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: () => ...,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,  // Le degrade vient du DecoratedBox.
        shadowColor: Colors.transparent,      // Pas d'ombre Material en plus.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text('JOUER', style: TTheme.buttonStyle()),
    ),
  ),
)
```

### Champ de texte moderne

```dart
TextField(
  controller: _controller,
  obscureText: isPassword ? _obscure : false,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: tr('auth.email'),
    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
    prefixIcon: Icon(Icons.email_outlined, color: Colors.white38),
    suffixIcon: isPassword ? IconButton(
      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
      onPressed: () => setState(() => _obscure = !_obscure),
    ) : null,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TTheme.orange, width: 1.5),
    ),
  ),
)
```

### Carte glassmorphism

```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.04),      // Fond transparent.
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white.withValues(alpha: 0.06)), // Bordure subtile.
  ),
  child: ...,
)
```

### Snackbar flottant

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Text(tr('activation.success')),
    ]),
    backgroundColor: TTheme.green,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 2),
  ),
);
```

### Dialog custom

```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => Dialog(
    backgroundColor: const Color(0xFF16163A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Hauteur = contenu.
        children: [
          Icon(...),
          Text(tr('game.quit_title')),
          ElevatedButton(onPressed: ..., child: Text(tr('game.continue'))),
          OutlinedButton(onPressed: ..., child: Text(tr('game.quit'))),
        ],
      ),
    ),
  ),
);
```

### Bottom Sheet

```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (ctx) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF16163A),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [...]),
  ),
);
```

### Image reseau avec loading et erreur

```dart
Image.network(
  imageUrl,
  fit: BoxFit.cover,
  loadingBuilder: (_, child, progress) {
    if (progress == null) return child; // Charge → affiche l'image.
    return Center(child: CircularProgressIndicator(strokeWidth: 2));
  },
  errorBuilder: (_, error, stack) => Container(
    color: Colors.grey[800],
    child: Icon(Icons.broken_image, color: Colors.white24),
  ),
)
```

---

## 14. Logique du jeu

### Cycle d'une question

```
_setupQuestion()
   │
   ├─ Choisir un trio aleatoire (E + C = R)
   ├─ Melanger 1 bonne reponse + 9 distracteurs
   ├─ Reset : _selectedCardId = null, _isAnswered = false
   └─ Demarrer le timer (30s)
        │
        ├─ Le joueur tape une carte → _handleAnswer(cardId)
        │   ├─ cardId == correctId → CORRECT (+score, +streak)
        │   └─ cardId != correctId → INCORRECT (+wrong, streak=0, -vie?)
        │
        ├─ Timer atteint 0 → _handleAnswer(null) → TIMEOUT
        │
        └─ Apres 1.8s de feedback visuel :
            ├─ Questions restantes → _setupQuestion() (boucle)
            └─ Fin du niveau ou vies=0 → TGameResultPage
```

### Scoring

```dart
if (isCorrect) {
  final basePoints = 20;                        // Points de base fixes.
  final timeBonus = (_remainingSeconds * 0.5).round(); // Plus rapide = plus de points.
  final streakBonus = _streak >= 3 ? 10 : 0;   // Bonus apres 3 consecutives.
  _score += basePoints + timeBonus + streakBonus;
}
```

### Perte de vie

```dart
if (_wrongAnswers % 2 == 0 && _lives > 0) {
  _lives--;
  // 1 vie perdue toutes les 2 erreurs (wireframe tolerant).
  // Version finale : GameConstants.getLevelConfig(level).livesPerWrong
}
```

### Fin de niveau

```dart
if (_questionNumber >= _totalQuestions || _lives <= 0) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => TGameResultPage(
        passed: _correctAnswers >= 4,  // Seuil : 4/6 = 67%.
        level: widget.level,
        score: _score,
        // ...
      ),
    ),
  );
}
```

---

## 15. Preparation backend

### Ce qui change avec Supabase

| Wireframe (actuel) | Backend (futur) |
|---|---|
| `MockData.mockUser` | `supabase.from('user_profiles').select()` |
| `MockData.mockTrios` | `supabase.from('card_trios').select()` |
| `MockData.mockDistractors` | `DistractorService.generate()` |
| `appState.setLanguage()` | Riverpod `StateNotifier` |
| `setState()` pour le jeu | `GameSessionNotifier` (Riverpod) |
| `Image.network(picsum)` | `CachedNetworkImage(card.imageUrl)` |
| Navigation manuelle | `AuthGate` (navigation par etat) |
| `Timer.periodic` dans le widget | `QuestionTimerNotifier` (Riverpod) |

### Ou brancher Supabase

```
t_auth_page.dart        → SupabaseAuthDatasource.signIn()
t_activation_page.dart  → ActivateCodeUseCase.execute()
t_home_page.dart        → UserEntity depuis user_profiles (StreamProvider)
t_game_page.dart        → GenerateQuestionUseCase + ValidateTripletUseCase
t_game_result_page.dart → GameSessionRepository.endSession()
t_profile_page.dart     → UserEntity + game_sessions history
t_leaderboard_page.dart → user_profiles ORDER BY total_score DESC
t_gallery_page.dart     → cards WHERE is_active = true
t_settings_page.dart    → Riverpod appSettingsProvider
```

### Pattern de migration (exemple pour l'auth)

**Avant (wireframe) :**
```dart
ElevatedButton(
  onPressed: () {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TActivationPage()),
    );
  },
  child: Text(tr('auth.login')),
)
```

**Apres (backend) :**
```dart
ElevatedButton(
  onPressed: () async {
    await ref.read(authProvider.notifier).signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    // La navigation est geree par _AuthGate dans main.dart
    // (navigation par etat, pas de Navigator.push manuel).
  },
  child: Text(tr('auth.login')),
)
```

### Checklist integration backend

```
[ ] 1. Remplacer TWireframeApp par TrialgoApp (main.dart)
[ ] 2. Ajouter ProviderScope (Riverpod) autour de MaterialApp
[ ] 3. Migrer AppState → Riverpod StateNotifier
[ ] 4. Migrer TLocale → flutter_localizations + intl (ARB)
[ ] 5. Brancher AuthProvider → SupabaseAuthDatasource
[ ] 6. Brancher GameSessionProvider → GenerateQuestionUseCase
[ ] 7. Remplacer MockData par des appels Supabase reels
[ ] 8. Remplacer Image.network(picsum) par CachedNetworkImage(card.imageUrl)
[ ] 9. Activer le Realtime pour les vies (LivesProvider)
[ ] 10. Tester le flux complet : inscription → activation → jeu → score
```

---

> **Ce document est la reference technique du frontend TRIALGO.**
> Chaque syntaxe, chaque pattern, chaque decision architecturale y est documentee.
> Il sert de pont entre le wireframe (interface) et le backend (Supabase).
