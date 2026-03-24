---
noteId: "32a3faf0260711f1b82a415705fd6862"
tags: []

---

# CHAPITRE 1 — CONFIGURATION DU PROJET

> Ce chapitre met en place les fondations techniques du projet :
> les dependances, la connexion a Supabase, la structure de dossiers,
> et les constantes partagees. A la fin de ce chapitre, l'application
> demarre, se connecte a Supabase, et affiche un ecran de confirmation.

---

## 1.1 OBJECTIF

A la fin de ce chapitre, nous aurons :
- Un projet Flutter configure avec toutes les dependances necessaires
- Une structure de dossiers Clean Architecture en place
- La connexion a Supabase fonctionnelle
- Les constantes de jeu et de stockage definies
- Un systeme d'erreurs structure
- Un ecran temporaire qui confirme que tout marche

---

## 1.2 LES DEPENDANCES (pubspec.yaml)

Le fichier `pubspec.yaml` est le **manifeste** du projet Flutter. Il declare
le nom du projet, sa version, et surtout ses **dependances** : les packages
externes dont le projet a besoin.

### Pourquoi ces packages ?

| Package | Version | Role dans TRIALGO |
|---------|---------|-------------------|
| `supabase_flutter` | ^2.8.4 | SDK complet : Auth, Database, Storage, Realtime, Edge Functions |
| `flutter_riverpod` | ^2.6.1 | Gestion d'etat reactive (providers) |
| `cached_network_image` | ^3.4.1 | Chargement d'images avec cache disque |
| `device_info_plus` | ^11.1.1 | Recuperer le Device ID pour l'activation |

### Le fichier pubspec.yaml modifie

```yaml
# pubspec.yaml — TRIALGO
# Fichier de configuration du projet Flutter

name: trialgo
description: "TRIALGO - Jeu de cartes mobile"
publish_to: 'none'    # Pas de publication sur pub.dev (projet prive)
version: 1.0.0+1      # version 1.0.0, build numero 1

# Version minimale de Dart requise
environment:
  sdk: ^3.11.1

# ---------------------------------------------------------------
# DEPENDANCES DE PRODUCTION
# ---------------------------------------------------------------
# Ces packages sont inclus dans l'application finale (APK/IPA).
# ---------------------------------------------------------------
dependencies:
  flutter:
    sdk: flutter

  # --- SUPABASE ---
  # SDK officiel Flutter pour Supabase.
  # Inclut automatiquement : supabase (core), gotrue (auth),
  # postgrest (database), storage_client, realtime_client, functions_client.
  # Un seul import pour tout le backend.
  supabase_flutter: ^2.8.4

  # --- GESTION D'ETAT ---
  # Riverpod pour Flutter. Fournit :
  #   - ProviderScope (conteneur global)
  #   - ConsumerWidget (widget qui lit les providers)
  #   - ref.watch / ref.read (acces aux providers)
  flutter_riverpod: ^2.6.1

  # --- IMAGES AVEC CACHE ---
  # Telecharge les images une seule fois, les stocke sur le disque.
  # Les chargements suivants lisent le cache local (instantane).
  # Fournit aussi un placeholder (pendant le chargement) et
  # un errorWidget (si l'image est introuvable).
  cached_network_image: ^3.4.1

  # --- ICONES ---
  cupertino_icons: ^1.0.8

  # --- IDENTIFIANT APPAREIL ---
  # Recupere un identifiant unique du telephone (Android ID, iOS identifierForVendor).
  # Utilise pour verifier qu'un code d'activation n'est pas reutilise
  # sur un autre appareil (securite anti-partage).
  device_info_plus: ^11.1.1
```

### Comment installer ?

Apres avoir modifie `pubspec.yaml`, on execute :

```bash
# Telecharge et installe tous les packages declares
flutter pub get
```

Cette commande :
1. Lit `pubspec.yaml` pour connaitre les dependances
2. Resout les versions compatibles entre elles
3. Telecharge les packages depuis pub.dev
4. Genere `pubspec.lock` (les versions exactes resolues)
5. Met les packages dans le cache local de Dart

---

## 1.3 STRUCTURE DE DOSSIERS (Clean Architecture)

Avant d'ecrire du code metier, on cree la structure de dossiers.
Chaque dossier correspond a une couche de l'architecture.

```
lib/
|
|-- main.dart                    # Point d'entree (ce chapitre)
|
|-- core/                        # Utilitaires partages (ce chapitre)
|   |-- constants/
|   |   |-- storage_constants.dart   # URLs Supabase Storage
|   |   +-- game_constants.dart      # Parametres de gameplay
|   |-- error/
|   |   +-- failures.dart            # Types d'erreurs
|   +-- network/
|       +-- supabase_client.dart     # Singleton Supabase
|
|-- domain/                      # Logique metier pure (Chapitre 3)
|   |-- entities/                # Modeles de donnees pures
|   |-- repositories/            # Interfaces (contrats)
|   +-- usecases/                # Actions metier
|
|-- data/                        # Implementation technique (Chapitre 4)
|   |-- models/                  # Entites + serialisation JSON
|   |-- datasources/             # Appels Supabase concrets
|   |-- repositories/            # Implementation des interfaces
|   +-- services/                # Services techniques
|
+-- presentation/                # Interface utilisateur (Chapitres 5-8)
    |-- providers/               # Etat Riverpod
    |-- pages/                   # Ecrans complets
    +-- widgets/                 # Composants reutilisables
```

### Convention de nommage des fichiers

| Convention | Exemple | Explication |
|-----------|---------|-------------|
| snake_case | `card_entity.dart` | Tout en minuscules, mots separes par `_` |
| Suffixe `_entity` | `card_entity.dart` | Entite de la couche Domain |
| Suffixe `_model` | `card_model.dart` | Modele de la couche Data (entite + JSON) |
| Suffixe `_repository` | `card_repository.dart` | Interface de repository (Domain) |
| Suffixe `_impl` | `card_repository_impl.dart` | Implementation du repository (Data) |
| Suffixe `_provider` | `auth_provider.dart` | Provider Riverpod (Presentation) |
| Suffixe `_page` | `game_page.dart` | Page/ecran complet (Presentation) |
| Suffixe `_widget` | `timer_widget.dart` | Widget reutilisable (Presentation) |

---

## 1.4 LE CLIENT SUPABASE (core/network/supabase_client.dart)

Ce fichier est le **pont** entre notre application Flutter et le backend Supabase.
Il contient trois elements :

### Les constantes de connexion

```dart
// URL du projet Supabase (identifie QUEL projet on utilise)
const String supabaseUrl = 'https://olovolsbopjporwpuphm.supabase.co';

// Cle publique (identifie l'app aupres de Supabase)
// SAFE a mettre dans le code client — la securite repose sur RLS, pas sur cette cle
const String supabaseAnonKey = 'sb_publishable_HSet9rvoO4ARe7BdVGZlLg__T-UZVHH';
```

**Question frequente** : "Est-ce dangereux de mettre la cle dans le code ?"

Non. La cle `anon` est volontairement publique. Elle est equivalente a l'URL
d'une API publique — elle dit "je veux parler a CE projet". La securite des
donnees est assuree par les politiques RLS (Row Level Security) cote PostgreSQL,
qui filtrent les donnees selon le JWT de l'utilisateur connecte.

### Le getter global

```dart
// Au lieu d'ecrire "Supabase.instance.client" partout :
SupabaseClient get supabase => Supabase.instance.client;

// Utilisation simplifiee partout dans l'app :
final cards = await supabase.from('cards').select();
final user = supabase.auth.currentUser;
```

### La fonction d'initialisation

```dart
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
}
```

`Supabase.initialize()` est asynchrone car elle :
1. Configure le client HTTP interne
2. Verifie s'il existe une session stockee localement
3. Si oui, tente de la restaurer (refresh du JWT si necessaire)
4. Prepare le canal Realtime pour les mises a jour en temps reel

---

## 1.5 LES CONSTANTES DE STOCKAGE (core/constants/storage_constants.dart)

Ce fichier traduit les chemins relatifs en URLs completes.

### Le probleme

En base de donnees, on stocke le chemin **relatif** :
```
emettrices/savane/lion_base.webp
```

Mais pour afficher l'image dans Flutter, on a besoin de l'URL **complete** :
```
https://olovolsbopjporwpuphm.supabase.co/storage/v1/object/public/trialgo-cards/emettrices/savane/lion_base.webp
```

### La solution

```dart
class StorageConstants {
  static const String baseUrl =
    'https://olovolsbopjporwpuphm.supabase.co/storage/v1/object/public/trialgo-cards';

  // Methode generique (tout type de carte)
  static String fullUrl(String imagePath) => '$baseUrl/$imagePath';

  // Helpers specifiques
  static String emettriceUrl(String theme, String filename) =>
    '$baseUrl/emettrices/$theme/$filename';

  static String cableUrl(String category, String filename) =>
    '$baseUrl/cables/$category/$filename';

  static String receptriceUrl(String theme, int distance, String filename) =>
    '$baseUrl/receptrices/$theme/d$distance/$filename';
}
```

### Pourquoi stocker le chemin relatif et pas l'URL complete ?

- Si le projet Supabase change (migration), on modifie `baseUrl` en UN endroit
- Le chemin relatif est plus court (economie de stockage en base)
- Le chemin relatif est lisible et explicite (`emettrices/savane/lion_base.webp`)

---

## 1.6 LES CONSTANTES DE JEU (core/constants/game_constants.dart)

Ce fichier centralise TOUS les parametres d'equilibrage du jeu.

### Le tableau de progression

```
Niveaux 1-3   : D1, config A,     8 questions, seuil 6/8,  30s, 10 pts
Niveaux 4-6   : D1, config A+B,  10 questions, seuil 7/10, 35s, 15 pts
Niveaux 7-10  : D2, config A+B,  10 questions, seuil 7/10, 40s, 20 pts
Niveaux 11-14 : D2, config B,    10 questions, seuil 7/10, 45s, 25 pts
Niveaux 15-18 : D3, config B+C,  12 questions, seuil 8/12, 50s, 35 pts
Niveaux 19-22 : D3, config C,    12 questions, seuil 9/12, 55s, 50 pts
Niveaux 23+   : D3, config A+B+C,15 questions, seuil 11/15,45s, 75 pts
```

### La formule de score

```
Score = Points_base x Multiplicateur_distance x Bonus_temps
```

Ou :
- Points_base : depend du niveau (10 a 75 pts)
- Multiplicateur_distance : D1=x1.0, D2=x1.5, D3=x2.0
- Bonus_temps : Turbo=x1.5, Rapide=x1.25, Normal=x1.0, Lent=x0.75

Exemple : Niveau 7 (D2, 20 pts base), reponse en 8s sur 40s (ratio 0.20 = Turbo) :
```
Score = 20 x 1.5 x 1.5 = 45 points
```

---

## 1.7 LES ERREURS STRUCTUREES (core/error/failures.dart)

### Pourquoi typer les erreurs ?

Sans structure :
```dart
// MAUVAIS : on ne sait pas quel type d'erreur c'est
catch (e) {
  showDialog(message: e.toString()); // Message cryptique
}
```

Avec structure :
```dart
// BON : on reagit differemment selon le type d'erreur
catch (e) {
  if (e is AuthFailure) {
    // Rediriger vers l'ecran de connexion
  } else if (e is ServerFailure) {
    // Afficher "pas de connexion, reessayez"
  } else if (e is ActivationFailure) {
    // Afficher le message specifique du code
  }
}
```

### La hierarchie d'erreurs TRIALGO

```
Failure (sealed class — classe de base)
  |
  +-- ServerFailure         # Pas d'internet, timeout, erreur 500
  |     noConnection()      # "Pas de connexion internet..."
  |     timeout()           # "Le serveur met trop de temps..."
  |
  +-- AuthFailure           # Problemes d'authentification
  |     invalidCredentials() # "Email ou mot de passe incorrect"
  |     emailAlreadyUsed()   # "Cet email est deja associe..."
  |     emailNotConfirmed()  # "Email non confirme..."
  |     weakPassword()       # "Minimum 8 caracteres requis"
  |     sessionExpired()     # "Session expiree..."
  |
  +-- ActivationFailure     # Problemes de code d'activation
  |     notFound()           # "Code introuvable..."
  |     deviceConflict()     # "Code deja active sur un autre appareil"
  |     invalidFormat()      # "Format incorrect..."
  |
  +-- CardFailure           # Problemes de cartes
        noTrioAvailable()    # "Aucun trio disponible..."
        brokenImage(path)    # "Image introuvable : ..."
```

---

## 1.8 LE POINT D'ENTREE (main.dart)

### Les 3 etapes du demarrage

```dart
void main() async {
  // Etape 1 : Initialiser le binding Flutter
  // OBLIGATOIRE avant tout appel async dans main()
  WidgetsFlutterBinding.ensureInitialized();

  // Etape 2 : Connecter a Supabase
  // Configure le SDK, restaure la session precedente
  await initSupabase();

  // Etape 3 : Lancer l'app avec Riverpod
  // ProviderScope = conteneur de TOUS les providers
  runApp(const ProviderScope(child: TrialgoApp()));
}
```

### Pourquoi `WidgetsFlutterBinding.ensureInitialized()` ?

Dart execute `main()` avant que le moteur Flutter ne soit pret. Si on appelle
`await` (comme `initSupabase()`) sans avoir initialise le binding, Flutter
ne peut pas gerer les callbacks asynchrones et leve une exception.

Cette ligne dit : "Flutter, initialise-toi MAINTENANT, j'ai besoin de toi."

### Pourquoi `ProviderScope` enveloppe tout ?

```dart
runApp(
  const ProviderScope(    // <-- Conteneur Riverpod
    child: TrialgoApp(),  // <-- Notre application
  ),
);
```

`ProviderScope` est le "cerveau" de Riverpod. Il :
- Stocke l'etat de chaque provider en memoire
- Notifie les widgets quand un etat change
- Gere le cycle de vie (creation, destruction) des providers

Sans lui, aucun `ref.watch()` ne fonctionne.

---

## 1.9 VERIFICATION

### Fichiers crees dans ce chapitre

```
lib/
  main.dart                              ✅ Modifie (point d'entree)
  core/
    constants/
      storage_constants.dart             ✅ Cree (URLs Storage)
      game_constants.dart                ✅ Cree (parametres de jeu)
    error/
      failures.dart                      ✅ Cree (types d'erreurs)
    network/
      supabase_client.dart               ✅ Cree (connexion Supabase)
```

### Comment verifier que tout fonctionne ?

```bash
# 1. Verifier que les dependances sont installees
flutter pub get

# 2. Verifier que le code compile sans erreur
flutter analyze

# 3. Lancer l'application (sur un emulateur ou un appareil)
flutter run
```

Si tout est correct, l'ecran affiche :
- L'icone de nuage vert
- "Supabase connecte !"
- "Aucune session active (non connecte)"

---

## 1.10 RECAPITULATIF

### Ce qu'on a appris

| Concept | Application |
|---------|-------------|
| pubspec.yaml | Declarer les dependances du projet |
| Clean Architecture | Structure de dossiers en 4 couches |
| Supabase.initialize() | Connexion au backend au demarrage |
| Singleton pattern | Un seul client Supabase pour toute l'app |
| Getter global | Acces simplifie au client Supabase |
| Sealed class | Hierarchie d'erreurs fermee et exhaustive |
| Factory constructors | Constructeurs nommes pour les erreurs courantes |
| ProviderScope | Conteneur obligatoire de Riverpod |

### Prochain chapitre

**Chapitre 2** — pas necessaire car nous avons integre le Core dans ce chapitre.

**Chapitre 3 : Le Domain Layer** — Nous allons creer les entites metier :
- `CardEntity` : une carte (Emettrice, Cable ou Receptrice)
- `CardTrioEntity` : un trio E + C = R
- `GameQuestionEntity` : une question de jeu
- `UserEntity` : un profil joueur

C'est le coeur de l'application — la couche qui ne depend de RIEN.
