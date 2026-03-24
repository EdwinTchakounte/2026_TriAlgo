---
noteId: "b7675ca0261111f1b82a415705fd6862"
tags: []

---

# CHAPITRE 5 — AUTHENTIFICATION (Connexion au Jeu)

> Ce chapitre construit le flux complet d'authentification :
> inscription, connexion, activation du code, et navigation
> automatique entre les ecrans selon l'etat du joueur.

---

## 5.1 OBJECTIF

A la fin de ce chapitre, nous aurons :
- Un provider Riverpod qui gere l'etat d'authentification (AuthNotifier)
- Un ecran de connexion/inscription (AuthPage)
- Un ecran d'activation du code physique (ActivationPage)
- Une navigation automatique selon l'etat (AuthGate)
- Le flux complet : inscription -> email -> code -> menu

---

## 5.2 LE FLUX D'AUTHENTIFICATION

```
LANCEMENT APP
     |
     v
[Splash Screen]
     |
     +-- Session active + profil existe ?
     |     OUI -> [Menu Principal]
     |     NON -> [AuthPage]
     |
     v
[AuthPage]
     |
     +-- Inscription email -> [Verifiez votre email] -> retour AuthPage
     +-- Connexion email   -> [Verification code] -> Menu ou ActivationPage
     +-- Google OAuth      -> [Verification code] -> Menu ou ActivationPage
     |
     v
[ActivationPage]
     |
     +-- Code valide + device libre  -> [Menu Principal]
     +-- Code valide + meme device   -> [Menu Principal] (reconnexion)
     +-- Code invalide               -> Message erreur, retry
     +-- Code autre device           -> Message erreur
     |
     v
[Menu Principal]  (authentifie + active)
```

---

## 5.3 LE PROVIDER D'AUTHENTIFICATION

### StateNotifier : le pattern

```
+----------------------------------+
|         AuthNotifier             |
|                                  |
|  state: AuthState {              |
|    status: AuthStatus.loading    |  <-- L'etat actuel
|    user: User(...)               |
|    errorMessage: null            |
|  }                               |
|                                  |
|  Methodes :                      |
|    signUp(email, password)       |  <-- Modifient "state"
|    signIn(email, password)       |
|    signInWithGoogle()            |
|    signOut()                     |
|    clearError()                  |
+----------------------------------+
         |
         | notifie automatiquement
         v
+----------------------------------+
|  Widgets (ref.watch)             |
|  Se reconstruisent quand         |
|  state change                    |
+----------------------------------+
```

### Le cycle de vie de l'etat

```
initial  --(demarrage)-->  loading  --(session trouvee)-->  authenticated
                                    --(pas de session)-->   unauthenticated
                                    --(pas de code)-->      needsActivation

unauthenticated  --(signIn)-->  loading  --(succes)-->  authenticated
                                         --(erreur)-->  error

error  --(clearError)-->  unauthenticated

authenticated  --(signOut)-->  unauthenticated
```

### ref.watch vs ref.read

```dart
// DANS BUILD : utiliser ref.watch (reconstruit le widget)
@override
Widget build(BuildContext context, WidgetRef ref) {
  final authState = ref.watch(authProvider);  // Reconstruit si change
  return Text(authState.status.name);
}

// DANS UN CALLBACK : utiliser ref.read (ne reconstruit PAS)
onPressed: () {
  ref.read(authProvider.notifier).signIn(email, password);  // Juste appeler
}
```

**Regle d'or** :
- `ref.watch` = dans `build()` = pour AFFICHER
- `ref.read` = dans callbacks = pour AGIR

### ref.listen : effets de bord

```dart
// Ecoute les changements SANS reconstruire le widget.
// Ideal pour : SnackBar, navigation, analytics.
ref.listen<AuthState>(authProvider, (previous, next) {
  if (next.status == AuthStatus.error) {
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
});
```

---

## 5.4 LA PAGE DE CONNEXION (AuthPage)

### ConsumerStatefulWidget

```
StatelessWidget        -> pas de State, pas de ref
StatefulWidget         -> State interne, pas de ref
ConsumerWidget         -> pas de State, avec ref
ConsumerStatefulWidget -> State interne ET ref     <-- AuthPage
```

AuthPage a besoin des DEUX :
- **State** : TextEditingControllers (doivent etre liberes dans dispose)
- **ref** : lire authProvider pour le statut et les actions

### Les controllers de texte

```dart
// Creation (dans le State)
final _emailController = TextEditingController();

// Lecture (dans _onSubmit)
final email = _emailController.text.trim();

// Liberation (dans dispose)
@override
void dispose() {
  _emailController.dispose();  // OBLIGATOIRE : evite les fuites memoire
  super.dispose();             // TOUJOURS appeler en dernier
}
```

### setState vs state (Riverpod)

| | `setState()` (Flutter) | `state = ...` (Riverpod) |
|---|---|---|
| Ou ? | Dans un StatefulWidget | Dans un StateNotifier |
| Portee | Ce widget UNIQUEMENT | TOUS les widgets qui ref.watch |
| Usage | UI locale (toggle password) | Etat partage (auth status) |

```dart
// setState : change locale (masquer le mot de passe)
setState(() { _obscurePassword = !_obscurePassword; });

// state = : change globale (statut d'authentification)
state = AuthState(status: AuthStatus.authenticated, user: user);
```

---

## 5.5 LA PAGE D'ACTIVATION (ActivationPage)

### Le flux d'activation

```
[Saisie du code]
     |
     v
Validation locale (regex ^[A-Z0-9-]{16}$)
     |
     +-- Format invalide -> Message erreur
     |
     v
Recuperation Device ID
     |
     v
Appel Edge Function "activate-code"
     |
     +-- Code inexistant (404)      -> "Code introuvable"
     +-- Autre appareil (403)       -> "Code deja utilise"
     +-- Activation reussie (200)   -> Animation + Menu
     +-- Reconnexion (200)          -> Menu direct
     +-- Erreur reseau              -> "Verifiez votre connexion"
```

### Widget conditionnel dans children

```dart
// Dart permet "if" directement dans une liste children :
Column(
  children: [
    Text('Toujours affiche'),

    // Affiche UNIQUEMENT si _successMessage n'est pas null
    if (_successMessage != null)
      Container(child: Text(_successMessage!)),

    Text('Aussi toujours affiche'),
  ],
)
```

### La propriete "mounted"

```dart
await Future.delayed(Duration(seconds: 2));

// Apres un delai, le widget a peut-etre ete detruit.
// Si on modifie le state d'un widget detruit -> EXCEPTION.
if (mounted) {
  setState(() { ... });  // Safe : le widget existe encore
}
```

---

## 5.6 LA NAVIGATION PAR ETAT (AuthGate)

### Le pattern

Au lieu de :
```dart
// MAUVAIS : navigation manuelle (spaghetti)
Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage()));
```

On fait :
```dart
// BON : l'ecran depend de l'etat
return switch (authState.status) {
  AuthStatus.unauthenticated => const AuthPage(),
  AuthStatus.needsActivation => const ActivationPage(),
  AuthStatus.authenticated   => const MenuScreen(),
  ...
};
```

**Avantages** :
- Pas de `Navigator.push/pop` a gerer manuellement
- L'ecran se met a jour AUTOMATIQUEMENT quand l'etat change
- Impossible d'acceder au menu sans etre authentifie
- Le bouton retour ne pose pas de probleme (pas de pile de navigation)

---

## 5.7 FICHIERS CREES / MODIFIES

```
lib/
  main.dart                                    ✏️  Modifie (AuthGate + navigation)
  presentation/
    providers/
      auth_provider.dart                       ✅  Cree (AuthNotifier + AuthState)
    pages/
      auth_page.dart                           ✅  Cree (connexion/inscription)
      activation_page.dart                     ✅  Cree (saisie du code)
```

**Resultat `flutter analyze` : No issues found!**

---

## 5.8 RECAPITULATIF

### Concepts appris

| Concept | Utilisation |
|---------|-------------|
| `StateNotifier<T>` | AuthNotifier gere l'etat AuthState |
| `StateNotifierProvider` | authProvider expose le notifier |
| `ref.watch()` | Lire l'etat + reconstruire le widget |
| `ref.read()` | Appeler une methode sans reconstruire |
| `ref.listen()` | Reagir aux changements (SnackBar) |
| `ConsumerStatefulWidget` | Widget avec State + ref |
| `ConsumerWidget` | Widget sans State + ref |
| `copyWith()` | Modifier un objet immuable |
| `TextEditingController` | Gerer les champs de saisie |
| `dispose()` | Liberer les ressources |
| `setState()` | Modifier l'etat LOCAL du widget |
| `mounted` | Verifier que le widget existe encore |
| `switch` expression | Navigation par etat |
| `if` dans `children` | Widget conditionnel dans une liste |
| `on Type catch (e)` | Attraper un type specifique d'erreur |
| `ScaffoldMessenger` | Afficher des SnackBars |

### Prochain chapitre

**Chapitre 6 : Le Jeu - Partie 1** — Nous allons creer :
- Le provider de session de jeu (GameSessionProvider)
- Le widget CardImageWidget (affichage d'une carte avec cache)
- La generation de questions (liaison avec le usecase)
- Le debut de l'ecran de jeu
