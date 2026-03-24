---
noteId: "1a90c520261511f1b82a415705fd6862"
tags: []

---

# CHAPITRE 6 — LE JEU PARTIE 1 (Session, Cartes, Timer)

> Ce chapitre construit le coeur du jeu : le provider de session,
> les widgets d'affichage de cartes, le chronometre, les vies,
> et l'ecran de jeu complet avec questions et choix.

---

## 6.1 OBJECTIF

A la fin de ce chapitre, nous aurons :
- Un provider de session de jeu (GameSessionNotifier) qui orchestre tout
- Un provider de chronometre (QuestionTimerNotifier) avec Timer Dart
- Un provider de vies en temps reel (StreamProvider via Supabase Realtime)
- Le widget CardImageWidget (image avec cache, selection, masquage)
- Le widget CardScrollView (liste horizontale des 10 choix)
- Le widget TimerWidget (cercle progressif vert/orange/rouge)
- Le widget LivesWidget (coeurs pleins/vides)
- L'ecran de jeu complet (GamePage) connecte a tout

---

## 6.2 ARCHITECTURE DU JEU

```
+----------------------------------------------------------+
|                    GamePage (ecran)                        |
|                                                          |
|  ref.watch(gameSessionProvider)  -> GameSessionState      |
|  ref.watch(questionTimerProvider) -> QuestionTimerState   |
|                                                          |
|  Widgets utilises :                                      |
|    CardImageWidget  -> affiche une carte (image + etat)  |
|    CardScrollView   -> 10 choix horizontaux scrollables  |
|    TimerWidget      -> cercle progressif avec secondes   |
|    LivesWidget      -> coeurs ❤️ pleins et vides         |
+----------------------------------------------------------+
         |                              |
         v                              v
+-------------------+    +---------------------------+
| GameSessionNotifier|   | QuestionTimerNotifier      |
|                   |    |                           |
| startSession()   |    | start(seconds)            |
| submitAnswer()   |    | stop()                    |
| nextQuestion()   |    | reset()                   |
| endSession()     |    | Timer.periodic(1s)        |
+-------------------+    +---------------------------+
         |
         v
+-------------------+
| GenerateQuestion  |
| UseCase           |
|   -> trioRepo     |
|   -> cardRepo     |
+-------------------+
```

---

## 6.3 LE PROVIDER DE SESSION (GameSessionNotifier)

### Le flux d'une session complete

```
startSession(level: 7, lives: 3)
  |
  v
[Loading] -> getLevelConfig(7) -> createSession(DB) -> generateQuestion()
  |
  v
[Playing] -> question affichee, timer demarre
  |
  +-- Joueur tape une image -> submitAnswer(card, elapsed)
  |     |
  |     +-- Correct -> calcul score + bonus -> [Answered] (2s) -> nextQuestion()
  |     +-- Incorrect -> -1 vie -> [Answered] (2s) -> nextQuestion() ou endSession()
  |
  +-- Timer expire -> submitAnswer(timeout) -> [Answered] -> next ou end
  |
  v
[LevelComplete] ou [LevelFailed] -> ecran de resultat -> retour menu
```

### Formule de score detaillee

```
Score = basePoints x distanceMultiplier x timeBonus + streakBonus

Exemple : Niveau 7, Distance 2, reponse en 10s sur 40s, serie de 4
  basePoints       = 20 (niveau 7-10)
  distanceMultiplier = 1.5 (D2)
  timeBonus        = 1.5 (10/40 = 0.25 = Turbo)
  streakBonus      = 20 (serie >= 3)

  Score = floor(20 x 1.5 x 1.5) + 20 = 45 + 20 = 65 points
```

### copyWith : le pattern immuable en action

```dart
// MAUVAIS : modifier l'objet en place
state.score += 10;  // Riverpod ne detecte PAS le changement !

// BON : creer un nouvel objet
state = state.copyWith(score: state.score + 10);
// Nouvelle reference -> Riverpod detecte -> widgets reconstruits
```

---

## 6.4 LE TIMER (QuestionTimerNotifier)

### Timer.periodic : le chronometre Dart

```dart
// Cree un timer qui "tick" toutes les secondes
_timer = Timer.periodic(
  const Duration(seconds: 1),  // Intervalle entre chaque tick
  (timer) {                     // Callback executee a chaque tick
    // Decrementer les secondes restantes
    // Quand 0 -> arreter le timer + notifier expiration
  },
);
```

### autoDispose : nettoyage automatique

```dart
// Sans autoDispose : le timer continue meme si l'ecran est ferme
final provider = StateNotifierProvider<TimerNotifier, TimerState>(...);

// Avec autoDispose : le timer est arrete quand l'ecran est ferme
final provider = StateNotifierProvider.autoDispose<TimerNotifier, TimerState>(...);
```

Le `.autoDispose` appelle automatiquement `dispose()` du StateNotifier
quand plus aucun widget n'ecoute le provider (ecran de jeu ferme).
Notre `dispose()` fait `_timer?.cancel()` -> pas de fuite memoire.

---

## 6.5 LES VIES EN TEMPS REEL (StreamProvider)

### Stream vs Future

| | Future | Stream |
|---|---|---|
| Nombre de valeurs | 1 seule | 0, 1, ou N |
| Quand | Une fois | En continu |
| Utilisation | Charger des donnees | Ecouter des changements |
| Riverpod | FutureProvider | StreamProvider |

### Supabase Realtime

```dart
// Ecoute les changements sur user_profiles en temps reel
supabase
  .from('user_profiles')
  .stream(primaryKey: ['id'])  // Observer cette table
  .eq('id', userId)             // Filtrer par utilisateur
  .map((data) => data.first['lives'] as int);  // Extraire les vies
```

Quand pg_cron recharge une vie (UPDATE lives = lives + 1),
Supabase Realtime envoie automatiquement la nouvelle valeur
-> le StreamProvider emet la nouvelle valeur
-> le widget se reconstruit avec le nouveau nombre de vies.

### AsyncValue.when : gerer les 3 etats d'un provider async

```dart
final livesAsync = ref.watch(livesProvider);

livesAsync.when(
  data: (lives) => LivesWidget(lives: lives),     // Donnees dispo
  loading: () => CircularProgressIndicator(),       // En chargement
  error: (e, s) => Text('Erreur: $e'),             // Erreur
);
```

---

## 6.6 LES WIDGETS

### CardImageWidget — Le widget le plus utilise

```
+--------------------+
| CachedNetworkImage  |  <- Image chargee avec cache disque
|   imageUrl          |  <- URL reconstruite depuis imagePath
|   placeholder       |  <- Spinner pendant le chargement
|   errorWidget       |  <- Icone si image introuvable
+--------------------+
|                    |
| AnimatedContainer  |  <- Transition animee (200ms)
|   border           |  <- Transparent/ambre/vert/rouge
|   borderRadius     |  <- Coins arrondis (12px)
|   boxShadow        |  <- Ombre si selectionnee
+--------------------+
|                    |
| GestureDetector    |  <- Detecte les taps
|   onTap            |  <- null = desactive
+--------------------+
```

### CardScrollView — Les 10 choix

```
SizedBox(height: 140)
  └── ListView.builder(horizontal)
        ├── Padding > CardImageWidget (choix 1)
        ├── Padding > CardImageWidget (choix 2)
        ├── Padding > CardImageWidget (choix 3) <- bonne reponse
        ├── Padding > CardImageWidget (choix 4)
        └── ... (10 au total)
```

### TimerWidget — Le cercle progressif

```
Stack(alignment: center)
  ├── CircularProgressIndicator  <- cercle qui se vide
  │     value: 1.0 - progress    <- inverse (plein -> vide)
  │     color: vert/orange/rouge <- selon urgencyLevel
  └── Text("28")                 <- secondes restantes
```

### LivesWidget — Les coeurs

```
Row
  ├── Icon(favorite, red)       <- vie pleine
  ├── Icon(favorite, red)       <- vie pleine
  ├── Icon(favorite, red)       <- vie pleine
  ├── Icon(favorite_border, grey) <- vie perdue
  └── Icon(favorite_border, grey) <- vie perdue
```

---

## 6.7 L'ECRAN DE JEU (GamePage)

### initState + addPostFrameCallback

```dart
@override
void initState() {
  super.initState();
  // Executer APRES la construction du widget
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(gameSessionProvider.notifier).startSession(...);
  });
}
```

Pourquoi `addPostFrameCallback` ?
- `initState` s'execute AVANT le premier `build`
- Les providers Riverpod ne sont pas encore prets
- `addPostFrameCallback` attend que le premier frame soit dessine
- A ce moment, le widget est dans l'arbre et `ref` fonctionne

### ref.listen dans GamePage : orchestration

```dart
// Quand la session passe en "playing" -> demarrer le timer
ref.listen(gameSessionProvider, (prev, next) {
  if (next.status == playing) timer.start(next.timeLimitSeconds);
  if (next.status == answered) timer.stop();
});

// Quand le timer expire -> soumettre un timeout
ref.listen(questionTimerProvider, (prev, next) {
  if (next.isExpired) session.submitAnswer(timeout);
});
```

---

## 6.8 FICHIERS CREES / MODIFIES

```
lib/
  main.dart                                    ✏️  Bouton Jouer connecte
  presentation/
    providers/
      game_session_provider.dart               ✅  Session de jeu complete
      question_timer_provider.dart             ✅  Chronometre par question
      lives_provider.dart                      ✅  Vies en temps reel
    pages/
      game_page.dart                           ✅  Ecran de jeu complet
    widgets/
      card_image_widget.dart                   ✅  Affichage d'une carte
      card_scroll_view.dart                    ✅  Liste des 10 choix
      timer_widget.dart                        ✅  Cercle progressif
      lives_widget.dart                        ✅  Coeurs de vies
```

**Resultat `flutter analyze` : No issues found!**

---

## 6.9 RECAPITULATIF

### Concepts appris

| Concept | Utilisation |
|---------|-------------|
| `Timer.periodic` | Chronometre qui tick chaque seconde |
| `.autoDispose` | Provider detruit quand plus ecoute |
| `StreamProvider` | Vies en temps reel via Supabase Realtime |
| `supabase.stream()` | Ecouter les changements en base |
| `AsyncValue.when` | Gerer data/loading/error |
| `CachedNetworkImage` | Image avec cache disque |
| `AnimatedContainer` | Transition animee sans AnimationController |
| `ListView.builder` | Liste construite a la demande |
| `Stack` | Empiler des widgets (cercle + texte) |
| `Spacer` | Prendre tout l'espace disponible |
| `List.generate` | Creer une liste de coeurs |
| `initState` | Code execute a la creation du widget |
| `addPostFrameCallback` | Code execute apres le premier rendu |
| `Navigator.push/pop` | Navigation par pile d'ecrans |
| `showDialog` | Popup modal de confirmation |
| `?.call()` | Appeler une callback nullable |

### Etat du projet

L'application est maintenant FONCTIONNELLE de bout en bout :
1. Connexion/inscription (email ou Google)
2. Activation du code (Edge Function)
3. Menu principal avec bouton "Jouer"
4. Ecran de jeu avec questions, choix, timer, score, vies
5. Fin de niveau (succes ou echec)
6. Retour au menu

### Prochain chapitre

**Chapitre 7/8 : Fonctionnalites avancees** :
- Galerie des cartes debloquees
- Leaderboard (classement global)
- Gestion hors-ligne
- Ameliorations UX (animations, sons)
