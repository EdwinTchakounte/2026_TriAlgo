# TRIALGO — Le Livre du Developpeur
## De Zero a l'Application Complete avec Flutter & Supabase

---

**Projet** : TRIALGO — Jeu de cartes mobile
**Stack** : Flutter + Supabase + Riverpod + Clean Architecture
**Version du recueil** : v3.0
**Auteurs** : FOKAM FEKAM Cedrick (Chef de projet), TCHAMBA TCHAKOUNTE Edwin (Chef technique), HAPPE WAKAM Loic Belmond (Chef artistique)

---

# CHAPITRE 0 — LES FONDATIONS

> Avant d'ecrire la moindre ligne de code pour TRIALGO, ce chapitre pose les
> concepts essentiels que tout developpeur doit maitriser. Chaque notion sera
> illustree, commentee et reliee a son utilisation concrete dans le projet.

---

## 0.1 QU'EST-CE QUE TRIALGO ?

TRIALGO est un jeu de cartes mobile ou le joueur doit identifier des relations
visuelles entre des images. Le principe fondamental repose sur une formule
simple :

```
IMAGE Emettrice  (+)  IMAGE Cable  =  IMAGE Receptrice
```

**Exemple concret :**
- Emettrice : un dessin de lion
- Cable : une image de deux fleches symetriques (= miroir horizontal)
- Receptrice : le lion dessine en miroir

Les trois sont des **images reelles** dessinees par un artiste, stockees dans
le cloud (Supabase Storage). Il n'y a aucun algorithme de transformation
automatique — tout est visuel et humain.

**Le defi du joueur** : on lui montre 2 images sur 3, et il doit retrouver
la 3eme parmi 10 propositions (1 correcte + 9 distracteurs).

---

## 0.2 LES TECHNOLOGIES — VUE D'ENSEMBLE

Avant de plonger dans chaque technologie, comprenons pourquoi chacune a ete
choisie et quel role elle joue dans l'architecture globale.

```
+-------------------------------------------------------------------+
|                        APPLICATION MOBILE                          |
|                                                                    |
|   +------------------+  +------------------+  +-----------------+  |
|   |     FLUTTER      |  |    RIVERPOD      |  |     DART        |  |
|   | (Interface UI)   |  | (Etat & logique) |  | (Langage)       |  |
|   +------------------+  +------------------+  +-----------------+  |
|                                                                    |
+-------------------------------|------------------------------------+
                                |
                          INTERNET (HTTPS)
                                |
+-------------------------------|------------------------------------+
|                         SUPABASE (Backend)                         |
|                                                                    |
|   +----------+  +----------+  +----------+  +-----------------+   |
|   |   AUTH    |  | DATABASE |  | STORAGE  |  | EDGE FUNCTIONS  |   |
|   | (Comptes) |  | (Tables) |  | (Images) |  | (Logique serveur)|  |
|   +----------+  +----------+  +----------+  +-----------------+   |
|                                                                    |
+-------------------------------------------------------------------+
```

### Pourquoi ces choix ?

| Technologie | Role dans TRIALGO | Pourquoi ce choix |
|-------------|-------------------|-------------------|
| **Flutter** | Afficher les ecrans, les images, gerer les interactions | Multi-plateforme (Android + iOS + Web), performant, un seul code |
| **Dart** | Langage de programmation de Flutter | Typage fort, asynchrone natif (async/await), compile en natif |
| **Riverpod** | Gerer l'etat de l'application (score, vies, session...) | Plus robuste que Provider, testable, pas de BuildContext requis |
| **Supabase** | Backend complet (auth, base de donnees, stockage) | Alternative open-source a Firebase, PostgreSQL, API REST auto-generee |
| **Clean Architecture** | Organiser le code en couches separees | Maintenabilite, testabilite, separation des responsabilites |

---

## 0.3 DART — LE LANGAGE

Dart est le langage dans lequel on ecrit tout le code Flutter. Voici les
concepts Dart essentiels pour TRIALGO, chacun illustre avec un exemple
directement lie au projet.

### 0.3.1 Variables et types

```dart
// =============================================================
// DART — Les types de base
// =============================================================
// Dart est un langage a typage fort : chaque variable a un type
// defini a la compilation. Cela evite les erreurs a l'execution.
// =============================================================

// --- Types simples ---

// String : chaine de caracteres
// Utilisation TRIALGO : stocker le chemin d'une image dans Supabase
String imagePath = 'emettrices/savane/lion_base.webp';

// int : nombre entier
// Utilisation TRIALGO : le niveau actuel du joueur (1 a 23+)
int currentLevel = 7;

// double : nombre decimal
// Utilisation TRIALGO : le score de difficulte d'une carte (0.0 a 1.0)
double difficultyScore = 0.5;

// bool : vrai ou faux
// Utilisation TRIALGO : est-ce que la carte est active dans le jeu ?
bool isActive = true;

// --- Types composes ---

// List : liste ordonnee d'elements
// Utilisation TRIALGO : les tags thematiques d'une carte
List<String> themeTags = ['animal', 'lion', 'savane', 'felin'];

// Map : dictionnaire cle-valeur
// Utilisation TRIALGO : les donnees JSON recues de Supabase
Map<String, dynamic> cardJson = {
  'id': '550e8400-e29b-41d4-a716-446655440000',
  'card_type': 'emettrice',
  'image_path': 'emettrices/savane/lion_base.webp',
};
```

### 0.3.2 Nullabilite (Null Safety)

```dart
// =============================================================
// DART — Null Safety
// =============================================================
// Depuis Dart 2.12, une variable ne peut PAS etre null par defaut.
// Pour autoriser null, on ajoute "?" apres le type.
// C'est crucial dans TRIALGO car certaines cartes n'ont PAS de parent.
// =============================================================

// --- Variable NON nullable ---
// Cette variable DOIT toujours avoir une valeur.
// Si on essaie de lui assigner null, Dart refuse a la compilation.
String imagePath = 'emettrices/savane/lion_base.webp';

// --- Variable NULLABLE ---
// Le "?" signifie : cette variable peut contenir une valeur OU null.
// Utilisation TRIALGO : une Emettrice racine n'a PAS de parent.
// Donc parentEmettriceId est null pour les Emettrices de base.
String? parentEmettriceId = null; // OK, autorise par le "?"

// --- Operateur "??" (valeur par defaut si null) ---
// Si la variable est null, on utilise la valeur apres "??".
// Utilisation TRIALGO : format d'image par defaut si non specifie.
String format = imageFormat ?? 'webp';
// Si imageFormat vaut null -> format = 'webp'
// Si imageFormat vaut 'png' -> format = 'png'

// --- Operateur "?." (appel conditionnel) ---
// Appelle la methode SEULEMENT si l'objet n'est pas null.
// Utilisation TRIALGO : longueur du username seulement s'il existe.
int? length = username?.length;
// Si username est null -> length = null (pas d'erreur)
// Si username vaut "LionMaster" -> length = 10
```

### 0.3.3 Classes et Constructeurs

```dart
// =============================================================
// DART — Classes
// =============================================================
// Une classe est un modele (un "moule") pour creer des objets.
// Dans TRIALGO, chaque concept du jeu est represente par une classe :
// - CardEntity    -> une carte (image)
// - UserEntity    -> un joueur
// - GameSession   -> une partie en cours
// =============================================================

// --- Classe simple avec constructeur nomme ---
// "final" signifie que la valeur ne peut plus changer apres creation.
// C'est une bonne pratique pour les entites : une carte ne change pas
// une fois chargee depuis la base de donnees.

class UserEntity {
  // Proprietes : les donnees que contient un utilisateur
  final String id;          // UUID unique (vient de Supabase Auth)
  final String username;    // Pseudo choisi par le joueur
  final int totalScore;     // Score cumule sur toutes les sessions
  final int currentLevel;   // Niveau actuel (1 a 23+)
  final int lives;          // Nombre de vies restantes (0 a 5)

  // Constructeur avec parametres nommes et requis
  // "const" permet d'optimiser les instances identiques en memoire.
  // "required" force l'appelant a fournir chaque parametre.
  const UserEntity({
    required this.id,
    required this.username,
    required this.totalScore,
    required this.currentLevel,
    required this.lives,
  });
}

// --- Creation d'un objet UserEntity ---
// On utilise le constructeur pour creer une instance :
final joueur = UserEntity(
  id: '550e8400-e29b-41d4-a716-446655440000',
  username: 'LionMaster',
  totalScore: 4250,
  currentLevel: 7,
  lives: 3,
);

// --- Acces aux proprietes ---
// On accede aux donnees avec la notation point :
print(joueur.username);     // Affiche : LionMaster
print(joueur.currentLevel); // Affiche : 7
```

### 0.3.4 Enumerations (enum)

```dart
// =============================================================
// DART — Enumerations
// =============================================================
// Un enum definit un ensemble FINI de valeurs possibles.
// C'est plus sur qu'un String car le compilateur verifie
// qu'on utilise uniquement des valeurs valides.
//
// Dans TRIALGO, le type de carte est un enum a 3 valeurs.
// Impossible d'avoir un 4eme type par erreur.
// =============================================================

enum CardType {
  emettrice,   // Image de base (ex: lion)
  cable,       // Image de transformation (ex: fleches miroir)
  receptrice,  // Image resultat (ex: lion en miroir)
}

// --- Utilisation dans le code ---
CardType type = CardType.emettrice;

// --- Switch exhaustif ---
// Dart oblige a gerer TOUS les cas d'un enum dans un switch.
// Si on ajoute un 4eme type plus tard, le compilateur nous
// previent partout ou il manque un case.
String label = switch (type) {
  CardType.emettrice  => 'Emettrice',
  CardType.cable      => 'Cable',
  CardType.receptrice => 'Receptrice',
};
```

### 0.3.5 Programmation asynchrone (async/await)

```dart
// =============================================================
// DART — Asynchrone (async / await / Future)
// =============================================================
// Dans TRIALGO, presque toutes les operations sont asynchrones :
// - Charger des cartes depuis Supabase (reseau)
// - Verifier l'authentification (reseau)
// - Pre-charger des images (reseau)
//
// "async" marque une fonction comme asynchrone.
// "await" attend le resultat d'une operation asynchrone.
// "Future<T>" est le type de retour : "une valeur T qui arrivera plus tard".
// =============================================================

// --- Exemple : charger le profil d'un joueur ---
// Cette fonction contacte Supabase, attend la reponse,
// puis retourne un UserEntity.

Future<UserEntity> chargerProfil(String userId) async {
  // "await" : on attend que Supabase reponde.
  // Pendant ce temps, l'application n'est PAS bloquee.
  // Flutter continue d'afficher l'interface normalement.
  final response = await supabase
      .from('user_profiles')  // Table Supabase ciblee
      .select()               // SELECT * (toutes les colonnes)
      .eq('id', userId)       // WHERE id = userId
      .single();              // On attend exactement 1 resultat

  // "response" est maintenant un Map<String, dynamic> (JSON)
  // On le transforme en objet Dart structure :
  return UserEntity(
    id: response['id'],
    username: response['username'],
    totalScore: response['total_score'],
    currentLevel: response['current_level'],
    lives: response['lives'],
  );
}

// --- Gestion des erreurs asynchrones ---
// Les operations reseau peuvent echouer (pas de connexion, timeout...).
// On utilise try/catch pour gerer ces cas.

Future<UserEntity?> chargerProfilSecurise(String userId) async {
  try {
    // Tente de charger le profil
    return await chargerProfil(userId);
  } catch (erreur) {
    // En cas d'echec : log l'erreur et retourne null
    print('Erreur chargement profil : $erreur');
    return null; // Le "?" dans le type de retour autorise null
  }
}
```

---

## 0.4 FLUTTER — LES FONDAMENTAUX

Flutter est le framework qui construit l'interface utilisateur. Tout dans
Flutter est un **Widget** : un bouton, un texte, une image, un ecran entier.

### 0.4.1 Qu'est-ce qu'un Widget ?

```dart
// =============================================================
// FLUTTER — Le concept de Widget
// =============================================================
// Un Widget est un element d'interface. Flutter fonctionne par
// COMPOSITION : on imbrique des widgets les uns dans les autres
// pour construire des ecrans complexes.
//
// Analogie : comme des briques LEGO, chaque widget est une piece
// et on les assemble pour creer l'interface.
//
// Il existe deux types de widgets :
//   1. StatelessWidget : ne change JAMAIS apres creation
//      -> Utilisation TRIALGO : afficher une image de carte
//   2. StatefulWidget  : peut changer (se reconstruire)
//      -> Utilisation TRIALGO : le chronometre qui decompte
// =============================================================
```

### 0.4.2 StatelessWidget — Widget sans etat

```dart
// =============================================================
// FLUTTER — StatelessWidget
// =============================================================
// Un StatelessWidget est un widget IMMUABLE.
// Une fois construit, il ne change plus.
// Il est ideal pour afficher des donnees fixes.
//
// Dans TRIALGO, l'affichage d'une carte (image) est un
// StatelessWidget : l'image ne change pas une fois chargee.
// =============================================================

import 'package:flutter/material.dart';
// "material.dart" contient tous les widgets de base de Flutter
// (Text, Container, Image, Column, Row, etc.)

/// Widget qui affiche une seule carte du jeu TRIALGO.
///
/// Ce widget recoit les donnees de la carte en parametre
/// et les affiche. Il ne gere aucun etat interne.
class CardImageWidget extends StatelessWidget {

  // --- Proprietes ---
  // "final" car elles ne changent jamais apres creation.

  /// L'URL complete de l'image a afficher.
  /// Exemple : "https://xxx.supabase.co/.../lion_base.webp"
  final String imageUrl;

  /// La taille du widget en pixels (largeur = hauteur).
  /// Par defaut 120px, ajustable selon le contexte.
  final double size;

  /// Est-ce que cette carte est actuellement selectionnee ?
  /// Si oui, on affiche une bordure doree.
  final bool isSelected;

  /// Callback appele quand le joueur tape sur la carte.
  /// Le "?" signifie que ce parametre est optionnel.
  final VoidCallback? onTap;

  // --- Constructeur ---
  // "const" : optimisation Flutter, permet de reutiliser
  // la meme instance si les parametres sont identiques.
  // "super.key" : identifiant unique pour Flutter (optimisation).
  const CardImageWidget({
    required this.imageUrl,   // Obligatoire : on doit savoir quoi afficher
    this.size = 120,          // Optionnel : valeur par defaut 120
    this.isSelected = false,  // Optionnel : pas selectionne par defaut
    this.onTap,               // Optionnel : pas de callback par defaut
    super.key,                // Cle Flutter pour le recycling
  });

  // --- Methode build ---
  // C'est ICI que l'on decrit ce que le widget affiche.
  // Flutter appelle cette methode pour "dessiner" le widget.
  // "BuildContext" donne acces a l'arbre de widgets parent.
  @override
  Widget build(BuildContext context) {
    // GestureDetector : detecte les taps (touchers) de l'utilisateur
    return GestureDetector(
      onTap: onTap, // Quand on tape, on execute le callback

      // Container : une boite avec des dimensions et un style
      child: Container(
        width: size,   // Largeur en pixels
        height: size,  // Hauteur en pixels

        // Decoration : le style visuel du container
        decoration: BoxDecoration(
          // Bordure : doree si selectionne, transparente sinon
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.transparent,
            width: 3,
          ),
          // Coins arrondis (12 pixels de rayon)
          borderRadius: BorderRadius.circular(12),
        ),

        // Image chargee depuis le reseau avec cache
        child: ClipRRect(
          // ClipRRect : decoupe l'image pour respecter les coins arrondis
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageUrl,          // URL de l'image a charger
            fit: BoxFit.cover, // L'image remplit tout le container
          ),
        ),
      ),
    );
  }
}
```

### 0.4.3 L'arbre de Widgets — Comment Flutter construit un ecran

```
// =============================================================
// FLUTTER — L'arbre de widgets
// =============================================================
// Un ecran Flutter est un ARBRE de widgets imbriques.
// Chaque widget contient un ou plusieurs enfants (child/children).
//
// Voici l'arbre simplifie de l'ecran de jeu TRIALGO :
// =============================================================

Scaffold                          // Structure de base d'un ecran
  |
  +-- AppBar                      // Barre du haut
  |     +-- Text("Niveau 7")     // Titre
  |     +-- LivesWidget           // Affichage des vies
  |
  +-- Column                      // Disposition verticale
        |
        +-- Row                   // Ligne du haut : les cartes visibles
        |     +-- CardImageWidget  // Image Emettrice (visible)
        |     +-- CardImageWidget  // Image Cable (visible)
        |     +-- CardImageWidget  // "???" (masquee)
        |
        +-- Text("Quelle image...?")  // Question
        |
        +-- ListView.horizontal   // Defilement horizontal
              +-- CardImageWidget  // Choix 1
              +-- CardImageWidget  // Choix 2
              +-- CardImageWidget  // Choix 3 (la bonne reponse)
              +-- CardImageWidget  // Choix 4
              +-- ...             // ... jusqu'a 10
```

### 0.4.4 Widgets de mise en page essentiels

```dart
// =============================================================
// FLUTTER — Les widgets de layout (mise en page)
// =============================================================
// Flutter utilise des widgets pour organiser la disposition.
// Les 4 principaux pour TRIALGO :
// =============================================================

// --- 1. Column : empile les enfants VERTICALEMENT ---
// Utilisation TRIALGO : structure generale de l'ecran de jeu
// (barre du haut, puis les cartes, puis la question, puis les choix)
Column(
  children: [
    Text('Element 1'),   // En haut
    Text('Element 2'),   // Au milieu
    Text('Element 3'),   // En bas
  ],
)

// --- 2. Row : aligne les enfants HORIZONTALEMENT ---
// Utilisation TRIALGO : les 3 cartes cote a cote (E, C, R)
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  // "spaceEvenly" : espace egal entre chaque enfant
  children: [
    CardImageWidget(imageUrl: urlEmettrice),
    CardImageWidget(imageUrl: urlCable),
    CardImageWidget(imageUrl: '???'),
  ],
)

// --- 3. ListView : liste scrollable ---
// Utilisation TRIALGO : les 10 images de choix en bas de l'ecran
ListView(
  scrollDirection: Axis.horizontal, // Defilement horizontal
  children: [
    // Les 10 CardImageWidget sont ici
  ],
)

// --- 4. Scaffold : structure complete d'un ecran ---
// Utilisation TRIALGO : chaque page (jeu, menu, auth)
Scaffold(
  appBar: AppBar(title: Text('TRIALGO')), // Barre du haut
  body: Column(...),                       // Contenu principal
)
```

---

## 0.5 SUPABASE — LE BACKEND

Supabase est notre serveur. Il fournit 4 services que TRIALGO utilise.
Comprendre chacun est essentiel avant de coder.

### 0.5.1 Vue d'ensemble des 4 services

```
+------------------------------------------------------------------+
|                       SUPABASE                                    |
|                                                                   |
|  +------------------+     +----------------------------------+   |
|  |                  |     |                                  |   |
|  |   1. AUTH        |     |   2. DATABASE (PostgreSQL)       |   |
|  |                  |     |                                  |   |
|  | - Inscription    |     | Tables :                        |   |
|  | - Connexion      |     |   - cards (les cartes-images)    |   |
|  | - Google OAuth   |     |   - card_trios (les trios E+C=R) |   |
|  | - Tokens JWT     |     |   - user_profiles (joueurs)      |   |
|  |                  |     |   - game_sessions (parties)      |   |
|  +------------------+     |   - activation_codes             |   |
|                           |   - user_unlocked_cards          |   |
|                           +----------------------------------+   |
|                                                                   |
|  +------------------+     +----------------------------------+   |
|  |                  |     |                                  |   |
|  |   3. STORAGE     |     |   4. EDGE FUNCTIONS              |   |
|  |                  |     |                                  |   |
|  | Bucket :         |     | Fonctions serveur (Deno/TS) :    |   |
|  |  trialgo-cards/  |     |   - activate-code                |   |
|  |   emettrices/    |     |   - generate-question            |   |
|  |   cables/        |     |   - validate-answer              |   |
|  |   receptrices/   |     |                                  |   |
|  |                  |     | Executees cote serveur pour      |   |
|  | Images .webp     |     | empecher la triche.              |   |
|  +------------------+     +----------------------------------+   |
|                                                                   |
+------------------------------------------------------------------+
```

### 0.5.2 AUTH — Authentification

```dart
// =============================================================
// SUPABASE AUTH — Gestion des comptes utilisateurs
// =============================================================
// Supabase Auth gere tout le cycle de vie d'un compte :
//   - Inscription (email + mot de passe)
//   - Connexion (email ou Google)
//   - Verification email
//   - Token JWT (prouve qu'on est connecte)
//   - Refresh token (renouvelle le JWT automatiquement)
//
// DANS TRIALGO :
//   - Le joueur s'inscrit par email ou Google
//   - Apres connexion, il doit entrer un code d'activation physique
//   - Le JWT est envoye automatiquement avec chaque requete
// =============================================================

// --- Inscription par email ---
// Supabase cree un compte et envoie un email de verification.
// Tant que l'email n'est pas verifie, pas de session.
final response = await supabase.auth.signUp(
  email: 'joueur@example.com',
  password: 'MonMotDePasse123',
);
// response.user -> l'objet utilisateur cree
// response.session -> null (en attente de verification email)

// --- Connexion par email ---
// Apres verification, le joueur peut se connecter.
// Supabase retourne un JWT (access_token) valide 1h.
final response = await supabase.auth.signInWithPassword(
  email: 'joueur@example.com',
  password: 'MonMotDePasse123',
);
// response.session!.accessToken -> le JWT a envoyer avec les requetes

// --- Connexion Google OAuth ---
// Le navigateur systeme s'ouvre, le joueur se connecte avec Google,
// puis est redirige vers l'application.
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'io.supabase.trialgo://callback',
);

// --- Deconnexion ---
// Supprime le JWT local. Le joueur devra se reconnecter.
await supabase.auth.signOut();
```

### 0.5.3 DATABASE — PostgreSQL

```dart
// =============================================================
// SUPABASE DATABASE — Operations CRUD
// =============================================================
// Supabase expose PostgreSQL via une API REST automatique.
// Depuis Flutter, on utilise le SDK Supabase qui traduit
// nos appels Dart en requetes SQL.
//
// Les 4 operations de base (CRUD) :
//   C = Create (INSERT)  -> creer une donnee
//   R = Read   (SELECT)  -> lire des donnees
//   U = Update (UPDATE)  -> modifier une donnee
//   D = Delete (DELETE)  -> supprimer une donnee
// =============================================================

// --- READ : Lire toutes les cartes de type "emettrice" ---
// SQL equivalent : SELECT * FROM cards WHERE card_type = 'emettrice'
final data = await supabase
    .from('cards')                    // Table cible
    .select()                         // Toutes les colonnes
    .eq('card_type', 'emettrice')     // Filtre : type = emettrice
    .eq('is_active', true);           // Filtre : seulement les actives
// "data" est une List<Map<String, dynamic>> (liste de lignes JSON)

// --- READ : Lire UN profil utilisateur specifique ---
// SQL equivalent : SELECT * FROM user_profiles WHERE id = 'xxx' LIMIT 1
final profil = await supabase
    .from('user_profiles')
    .select()
    .eq('id', userId)
    .single();    // ".single()" garantit exactement 1 resultat
// "profil" est un Map<String, dynamic> (une seule ligne JSON)

// --- CREATE : Creer une nouvelle session de jeu ---
// SQL equivalent : INSERT INTO game_sessions (...) VALUES (...)
final session = await supabase
    .from('game_sessions')
    .insert({
      'user_id': userId,
      'level_number': 7,
      'score': 0,
      'completed': false,
    })
    .select()       // Retourne la ligne inseree
    .single();

// --- UPDATE : Mettre a jour le score ---
// SQL equivalent : UPDATE game_sessions SET score = 1297 WHERE id = 'xxx'
await supabase
    .from('game_sessions')
    .update({'score': 1297, 'correct_answers': 4})
    .eq('id', sessionId);

// --- Requete avec jointure ---
// Supabase permet de charger des relations en une seule requete.
// Ici on charge un trio avec les details de chaque carte.
final trio = await supabase
    .from('card_trios')
    .select('''
      *,
      emettrice:cards!emettrice_id(*),
      cable:cards!cable_id(*),
      receptrice:cards!receptrice_id(*)
    ''')
    .eq('distance_level', 1)
    .limit(1)
    .single();
```

### 0.5.4 STORAGE — Stockage d'images

```dart
// =============================================================
// SUPABASE STORAGE — Stockage et CDN d'images
// =============================================================
// Dans TRIALGO, toutes les cartes sont des IMAGES stockees dans
// un bucket Supabase Storage nomme "trialgo-cards" (public).
//
// Structure du bucket :
//   trialgo-cards/
//     emettrices/
//       savane/lion_base.webp
//       ocean/requin_base.webp
//     cables/
//       geometrique/miroir_h.webp
//       couleur/teinte_rouge.webp
//     receptrices/
//       savane/d1/lion_miroir_h.webp
//       savane/d2/lion_miroir_h_teinte_rouge.webp
//
// Chaque image a une URL publique stable :
//   https://<PROJECT_REF>.supabase.co/storage/v1/object/public/trialgo-cards/<path>
//
// L'application Flutter n'uploade JAMAIS d'images.
// C'est le chef artistique qui les uploade manuellement.
// L'app ne fait que les LIRE via leur URL.
// =============================================================

// --- Construction de l'URL depuis le chemin relatif ---
// En base de donnees, on stocke le chemin RELATIF (ex: "emettrices/savane/lion_base.webp")
// L'URL complete est reconstruite cote client :

class StorageConstants {
  // URL de base du bucket public
  // "<PROJECT_REF>" sera remplace par l'ID reel du projet Supabase
  static const String baseUrl =
      'https://<PROJECT_REF>.supabase.co/storage/v1/object/public/trialgo-cards';

  // Construit l'URL complete a partir du chemin relatif
  // Exemple : imagePath = "emettrices/savane/lion_base.webp"
  //        -> "https://xxx.supabase.co/.../emettrices/savane/lion_base.webp"
  static String fullUrl(String imagePath) => '$baseUrl/$imagePath';
}
```

### 0.5.5 ROW LEVEL SECURITY (RLS)

```sql
-- =============================================================
-- SUPABASE RLS — Securite au niveau des lignes
-- =============================================================
-- RLS est un mecanisme PostgreSQL qui filtre les donnees
-- AUTOMATIQUEMENT selon QUI fait la requete.
--
-- Sans RLS : n'importe qui peut lire/modifier toutes les donnees.
-- Avec RLS : chaque utilisateur ne voit que SES propres donnees.
--
-- C'est la DERNIERE ligne de defense : meme si quelqu'un
-- contourne l'application Flutter, PostgreSQL refuse l'acces.
--
-- DANS TRIALGO :
--   - Un joueur ne peut lire que SON profil
--   - Un joueur ne peut modifier que SES sessions non terminees
--   - Les cartes sont en lecture seule pour tout le monde
--   - Les codes d'activation sont geres uniquement par les Edge Functions
-- =============================================================

-- Exemple : politique sur user_profiles
-- "auth.uid()" retourne l'ID de l'utilisateur connecte (via le JWT)

-- Le joueur ne peut lire QUE son propre profil :
CREATE POLICY "user_profiles_select_own"
  ON user_profiles FOR SELECT
  USING (auth.uid() = id);
  -- USING : condition qui FILTRE les lignes visibles
  -- Seules les lignes ou "id = mon_uid" sont retournees

-- Le joueur ne peut modifier QUE son propre profil :
CREATE POLICY "user_profiles_update_own"
  ON user_profiles FOR UPDATE
  USING (auth.uid() = id)          -- Je ne vois que ma ligne
  WITH CHECK (auth.uid() = id);    -- Je ne peux modifier que ma ligne
```

---

## 0.6 CLEAN ARCHITECTURE — L'ORGANISATION DU CODE

### 0.6.1 Pourquoi une architecture ?

```
// =============================================================
// CLEAN ARCHITECTURE — Le probleme qu'elle resout
// =============================================================
//
// SANS architecture (tout dans un seul fichier) :
//   - Melange d'UI, logique metier, et appels reseau
//   - Impossible de tester la logique sans lancer l'app
//   - Changer de backend (ex: Firebase -> Supabase) = tout reecrire
//   - Difficulte a travailler en equipe (conflits sur les memes fichiers)
//
// AVEC Clean Architecture (code separe en couches) :
//   - Chaque couche a UNE responsabilite
//   - On peut tester chaque couche independamment
//   - Changer de backend = modifier UNE seule couche
//   - L'equipe travaille en parallele sur des couches differentes
// =============================================================
```

### 0.6.2 Les 3 couches + 1

```
+-------------------------------------------------------------------+
|                                                                    |
|  COUCHE 1 : DOMAIN (le coeur — ne depend de RIEN)                 |
|  +---------------------------------------------------------+      |
|  | Entities     : CardEntity, UserEntity, GameQuestion      |      |
|  | Repositories : CardRepository (INTERFACE seulement)      |      |
|  | Usecases     : ValidateTripletUseCase, GenerateQuestion  |      |
|  +---------------------------------------------------------+      |
|       ^                                                            |
|       | depend de                                                  |
|       |                                                            |
|  COUCHE 2 : DATA (les details techniques)                         |
|  +---------------------------------------------------------+      |
|  | Models       : CardModel (= CardEntity + fromJson)       |      |
|  | Datasources  : SupabaseCardDatasource (appels Supabase)   |      |
|  | Repositories : CardRepositoryImpl (implemente l'interface)|      |
|  | Services     : DistractorService                          |      |
|  +---------------------------------------------------------+      |
|       ^                                                            |
|       | depend de                                                  |
|       |                                                            |
|  COUCHE 3 : PRESENTATION (l'interface utilisateur)                |
|  +---------------------------------------------------------+      |
|  | Providers    : gameSessionProvider, livesProvider         |      |
|  | Pages        : GamePage, AuthPage, ActivationPage        |      |
|  | Widgets      : CardImageWidget, TimerWidget              |      |
|  +---------------------------------------------------------+      |
|                                                                    |
|  COUCHE 0 : CORE (utilitaires partages entre toutes les couches)  |
|  +---------------------------------------------------------+      |
|  | Constants    : StorageConstants, GameConstants            |      |
|  | Errors       : Failures (types d'erreurs)                 |      |
|  | Network      : SupabaseClient (singleton)                 |      |
|  +---------------------------------------------------------+      |
|                                                                    |
+-------------------------------------------------------------------+
```

### 0.6.3 La regle de dependance

```dart
// =============================================================
// CLEAN ARCHITECTURE — La regle d'or
// =============================================================
// Les dependances vont TOUJOURS de l'exterieur vers l'interieur :
//
//   PRESENTATION -> DATA -> DOMAIN
//
// Autrement dit :
//   - DOMAIN ne connait RIEN des autres couches
//     (pas d'import de Flutter, pas d'import de Supabase)
//   - DATA connait DOMAIN (elle implemente ses interfaces)
//     (importe les entites et repositories du domain)
//   - PRESENTATION connait DATA et DOMAIN
//     (utilise les usecases et affiche les entites)
//
// POURQUOI ?
//   - Si Supabase ferme demain, on ne modifie que DATA
//   - Si on change de design, on ne modifie que PRESENTATION
//   - DOMAIN (la logique metier) ne change JAMAIS
// =============================================================

// --- Exemple concret dans TRIALGO ---

// DOMAIN : definit ce qu'on VEUT faire (interface)
// Ce fichier ne sait PAS que Supabase existe.
abstract class CardRepository {
  Future<List<CardEntity>> getActiveCards();
}

// DATA : definit COMMENT on le fait (implementation)
// Ce fichier connait Supabase et sait comment appeler l'API.
class CardRepositoryImpl implements CardRepository {
  final SupabaseClient supabase;

  @override
  Future<List<CardEntity>> getActiveCards() async {
    final data = await supabase
        .from('cards')
        .select()
        .eq('is_active', true);
    return data.map((json) => CardModel.fromJson(json)).toList();
  }
}

// PRESENTATION : utilise le repository sans savoir d'ou viennent les donnees
// Ce fichier ne sait PAS si les donnees viennent de Supabase, Firebase, ou un fichier local.
class GamePage extends StatelessWidget {
  final CardRepository repository; // Interface, pas implementation

  // ...utilise repository.getActiveCards()
}
```

---

## 0.7 RIVERPOD — LA GESTION D'ETAT

### 0.7.1 Le probleme de l'etat

```dart
// =============================================================
// RIVERPOD — Pourquoi gerer l'etat ?
// =============================================================
// L'ETAT d'une application = toutes les donnees qui changent
// au cours de l'utilisation.
//
// Dans TRIALGO, l'etat comprend :
//   - Le joueur est-il connecte ? (AUTH)
//   - Quel est son niveau actuel ? (PROFIL)
//   - Combien de vies lui reste-t-il ? (VIES)
//   - Quel est le score de la session en cours ? (SESSION)
//   - Quelle question est affichee ? (QUESTION)
//   - Combien de temps reste-t-il ? (TIMER)
//   - Le joueur a-t-il une serie en cours ? (STREAK)
//
// Le PROBLEME : ces donnees doivent etre accessibles depuis
// PLUSIEURS ecrans et widgets, et se mettre a jour en TEMPS REEL.
//
// Riverpod resout cela en centralisant l'etat dans des "providers"
// accessibles partout, sans passer par l'arbre de widgets.
// =============================================================
```

### 0.7.2 Les types de providers

```dart
// =============================================================
// RIVERPOD — Les types de providers utilises dans TRIALGO
// =============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

// --- 1. StateNotifierProvider ---
// Pour un etat COMPLEXE avec des methodes de modification.
// Le StateNotifier contient la logique de modification de l'etat.
//
// Utilisation TRIALGO : session de jeu (score, vies, streak)

// D'abord, on definit le StateNotifier (la logique) :
class GameSessionNotifier extends StateNotifier<GameSessionState> {
  // "super()" definit l'etat initial
  GameSessionNotifier() : super(GameSessionState.initial());

  // Methode pour ajouter des points
  void addScore(int points) {
    // "state" est l'etat actuel
    // On cree un NOUVEL etat (immutabilite)
    state = state.copyWith(score: state.score + points);
  }

  // Methode pour perdre une vie
  void loseLife() {
    state = state.copyWith(lives: state.lives - 1);
  }
}

// Puis, on cree le provider (le point d'acces global) :
final gameSessionProvider =
    StateNotifierProvider<GameSessionNotifier, GameSessionState>(
  (ref) => GameSessionNotifier(),
);

// --- 2. FutureProvider ---
// Pour des donnees chargees de maniere ASYNCHRONE (une seule fois).
//
// Utilisation TRIALGO : classement (leaderboard)

final leaderboardProvider = FutureProvider<List<UserEntity>>((ref) async {
  // Cette fonction est executee automatiquement
  // quand un widget lit ce provider pour la premiere fois.
  final data = await supabase
      .from('user_profiles')
      .select('username, total_score, current_level')
      .order('total_score', ascending: false)
      .limit(50);
  return data.map((json) => UserEntity.fromJson(json)).toList();
});

// --- 3. StreamProvider ---
// Pour des donnees qui changent EN TEMPS REEL.
//
// Utilisation TRIALGO : nombre de vies (mis a jour par pg_cron)

final livesProvider = StreamProvider<int>((ref) {
  // Supabase Realtime envoie les mises a jour automatiquement
  return supabase
      .from('user_profiles')
      .stream(primaryKey: ['id'])
      .eq('id', currentUserId)
      .map((data) => data.first['lives'] as int);
});
```

### 0.7.3 Utiliser un provider dans un widget

```dart
// =============================================================
// RIVERPOD — Lire un provider dans l'interface
// =============================================================
// Pour utiliser Riverpod, le widget doit heriter de
// ConsumerWidget (au lieu de StatelessWidget).
//
// La methode build recoit un "WidgetRef ref" en plus du contexte.
// "ref" est le pont entre le widget et les providers.
// =============================================================

class ScoreDisplay extends ConsumerWidget {
  const ScoreDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- ref.watch ---
    // Lit la valeur ET se reconstruit automatiquement quand elle change.
    // Ideal pour l'affichage : des que le score change, le widget se redessine.
    final session = ref.watch(gameSessionProvider);

    return Text(
      'Score : ${session.score}',
      style: const TextStyle(fontSize: 24),
    );
    // Ce Text se met a jour AUTOMATIQUEMENT quand le score change.
    // Pas besoin de setState(), pas besoin de callback.
  }
}
```

---

## 0.8 STRUCTURE DE FICHIERS — CE QUE NOUS ALLONS CONSTRUIRE

Voici la structure complete du projet que nous allons construire pas a pas.
Chaque fichier sera cree, commente et explique dans les chapitres suivants.

```
lib/
|
|-- main.dart                           # CHAPITRE 1 : Point d'entree
|
|-- core/                               # CHAPITRE 2 : Fondations partagees
|   |-- constants/
|   |   |-- storage_constants.dart      #   URLs Supabase Storage
|   |   +-- game_constants.dart         #   Seuils, limites, parametres
|   |-- error/
|   |   +-- failures.dart              #   Types d'erreurs structures
|   +-- network/
|       +-- supabase_client.dart       #   Singleton Supabase
|
|-- domain/                             # CHAPITRE 3 : Logique metier pure
|   |-- entities/
|   |   |-- card_entity.dart           #   Modele de carte (E, C, R)
|   |   |-- card_trio_entity.dart      #   Trio E+C=R
|   |   |-- game_question_entity.dart  #   Question de jeu
|   |   +-- user_entity.dart           #   Profil joueur
|   |-- repositories/
|   |   |-- card_repository.dart       #   Interface cartes
|   |   |-- card_trio_repository.dart  #   Interface trios
|   |   +-- game_session_repository.dart # Interface sessions
|   +-- usecases/
|       |-- generate_question_usecase.dart
|       |-- validate_triplet_usecase.dart
|       +-- activate_code_usecase.dart
|
|-- data/                               # CHAPITRE 4 : Implementation technique
|   |-- models/
|   |   |-- card_model.dart            #   CardEntity + fromJson
|   |   +-- card_trio_model.dart       #   Trio + fromJson
|   |-- datasources/
|   |   |-- supabase_card_datasource.dart
|   |   +-- supabase_auth_datasource.dart
|   |-- repositories/
|   |   +-- card_repository_impl.dart  #   Implementation concrete
|   +-- services/
|       +-- distractor_service.dart    #   Generation des distracteurs
|
+-- presentation/                       # CHAPITRE 5-8 : Interface utilisateur
    |-- providers/
    |   |-- auth_provider.dart         #   CHAPITRE 5
    |   |-- game_session_provider.dart #   CHAPITRE 6
    |   |-- question_timer_provider.dart
    |   |-- session_timer_provider.dart
    |   |-- lives_provider.dart
    |   +-- leaderboard_provider.dart
    |-- pages/
    |   |-- auth_page.dart             #   CHAPITRE 5
    |   |-- activation_page.dart       #   CHAPITRE 5
    |   +-- game_page.dart             #   CHAPITRE 7
    +-- widgets/
        |-- card_image_widget.dart      #   CHAPITRE 6
        |-- card_scroll_view.dart       #   CHAPITRE 7
        |-- timer_widget.dart           #   CHAPITRE 7
        +-- lives_widget.dart           #   CHAPITRE 7
```

---

## 0.9 PLAN DU LIVRE — LES PROCHAINES ETAPES

| Chapitre | Titre | Ce qu'on construit |
|----------|-------|--------------------|
| **0** | Les Fondations (ce chapitre) | Concepts Dart, Flutter, Supabase, Architecture |
| **1** | Configuration du projet | pubspec.yaml, main.dart, connexion Supabase |
| **2** | Le Core | Constants, Errors, Client Supabase |
| **3** | Le Domain | Entities, Repositories (interfaces), Usecases |
| **4** | Le Data | Models, Datasources, Repository implementations |
| **5** | Authentification | Auth provider, pages login/inscription, activation code |
| **6** | Le Jeu - Partie 1 | Session provider, generation de questions, CardImageWidget |
| **7** | Le Jeu - Partie 2 | Ecran de jeu complet, timers, bonus/malus |
| **8** | Fonctionnalites avancees | Galerie, leaderboard, gestion hors-ligne |

Chaque chapitre suivra le meme format :
1. **Objectif** : ce qu'on va construire et pourquoi
2. **Theorie** : les concepts necessaires, expliques
3. **Code** : implementation pas a pas, chaque ligne commentee
4. **Verification** : comment tester que ca marche
5. **Recapitulatif** : ce qu'on a appris et ce qui suit

---

> **Fin du Chapitre 0**
>
> Vous avez maintenant les bases pour comprendre chaque ligne de code
> que nous ecrirons dans les chapitres suivants. Les concepts de Dart,
> Flutter, Supabase, Clean Architecture et Riverpod seront appliques
> concretement a TRIALGO.
>
> **Prochain chapitre** : Configuration du projet Flutter, installation
> des dependances, et connexion a Supabase.
