---
noteId: "ee03fad0260b11f1b82a415705fd6862"
tags: []

---

# CHAPITRE 3 — LE DOMAIN LAYER (Le Coeur du Jeu)

> Le Domain est la couche la plus importante de l'application.
> Elle definit les CONCEPTS METIER (entites), les CONTRATS D'ACCES
> aux donnees (repositories), et les ACTIONS du jeu (usecases).
> Cette couche ne depend de RIEN : ni Flutter, ni Supabase.

---

## 3.1 OBJECTIF

A la fin de ce chapitre, nous aurons :
- 4 entites : CardEntity, CardTrioEntity, UserEntity, GameQuestionEntity
- 3 interfaces de repositories : CardRepository, CardTrioRepository, GameSessionRepository
- 3 usecases : ValidateTripletUseCase, GenerateQuestionUseCase, ActivateCodeUseCase
- Zero dependance vers Flutter ou Supabase dans cette couche

---

## 3.2 PRINCIPES CLES

### Le Domain ne depend de RIEN

```
  PRESENTATION
       |
       v
     DATA
       |
       v
    DOMAIN  <-- Aucune fleche ne sort du Domain
```

Le Domain ne fait AUCUN import de :
- `package:flutter/...` (pas de widgets)
- `package:supabase_flutter/...` (pas d'acces reseau)
- `lib/data/...` (pas d'implementation)
- `lib/presentation/...` (pas d'interface)

Il peut importer :
- `dart:math` (librairie standard Dart)
- `lib/core/...` (constantes et erreurs partagees)
- `lib/domain/...` (lui-meme, intra-couche)

### Tout est immuable

Chaque propriete est `final` : une fois creee, l'entite ne change plus.
Pour "modifier" une entite, on en cree une nouvelle avec les nouvelles valeurs.

### Les repositories sont des interfaces

La couche Domain definit CE QU'ON PEUT FAIRE (interfaces abstraites).
La couche Data definit COMMENT ON LE FAIT (implementations concretes).

---

## 3.3 LES ENTITES

### CardEntity — Le coeur du jeu

C'est la classe la plus importante. Chaque carte est UNE image avec :

| Propriete | Type | Role |
|-----------|------|------|
| `id` | String | UUID unique (PostgreSQL) |
| `cardType` | CardType (enum) | emettrice, cable ou receptrice |
| `distanceLevel` | int | 1, 2 ou 3 |
| `imagePath` | String | Chemin relatif dans Storage |
| `imageWidth/Height` | int? | Dimensions en pixels |
| `imageFormat` | String | 'webp', 'png' ou 'jpg' |
| `cableCategory` | String? | Categorie du cable (null pour E et R) |
| `themeTags` | List\<String\> | Tags thematiques |
| `parentEmettriceId` | String? | UUID de l'Emettrice parente |
| `parentCableId` | String? | UUID du Cable utilise |
| `rootEmettriceId` | String? | UUID de l'Emettrice racine |
| `difficultyScore` | double | 0.0 (trivial) a 1.0 (expert) |
| `isActive` | bool | Utilisable dans le jeu ? |

**Getters calcules** :
- `imageUrl` : reconstruit l'URL complete depuis `imagePath`
- `isRootEmettrice` : true si c'est une Emettrice sans parent
- `isCable` / `isReceptrice` : raccourcis de verification de type

### CardTrioEntity — La relation E + C = R

| Propriete | Type | Role |
|-----------|------|------|
| `id` | String | UUID du trio |
| `emettriceId` | String | UUID de l'Emettrice |
| `cableId` | String | UUID du Cable |
| `receptriceId` | String | UUID de la Receptrice |
| `distanceLevel` | int | 1, 2 ou 3 |
| `parentTrioId` | String? | UUID du trio precedent (null si D1) |
| `difficulty` | double | Difficulte globale du trio |

### UserEntity — Le profil joueur

| Propriete | Type | Role |
|-----------|------|------|
| `id` | String | UUID Supabase Auth |
| `username` | String | Pseudo unique |
| `avatarUrl` | String? | URL de l'avatar |
| `totalScore` | int | Score cumule total |
| `currentLevel` | int | Niveau actuel (1-23+) |
| `lives` | int | Vies restantes (0-5) |
| `livesLastRefill` | DateTime? | Derniere recharge |

### GameQuestionEntity — Une question de jeu

| Propriete | Type | Role |
|-----------|------|------|
| `visibleCards` | List\<CardEntity\> | 2 cartes visibles en haut |
| `maskedCard` | CardEntity | La carte cachee ("???") |
| `choices` | List\<CardEntity\> | 10 propositions (1 + 9 distracteurs) |
| `config` | String | 'A', 'B' ou 'C' |
| `correctCardId` | String | UUID de la bonne reponse |
| `trioId` | String | UUID du trio source |
| `timeLimitSeconds` | int | Temps max pour repondre |

---

## 3.4 LES REPOSITORIES (Interfaces)

### CardRepository

```dart
abstract class CardRepository {
  Future<CardEntity> getCardById(String id);
  Future<List<CardEntity>> getCardsByType(CardType type);
  Future<List<CardEntity>> getCardsByDistance(int distance);
  Future<List<CardEntity>> getCardsByTypeAndDistance(CardType type, int distance);
  Future<List<CardEntity>> getDistractors({required CardEntity correctCard, int count = 9});
}
```

### CardTrioRepository

```dart
abstract class CardTrioRepository {
  Future<CardTrioEntity> getRandomTrio({required int distance, List<String> excludeIds});
  Future<bool> isCoherent({required String emettriceId, required String cableId, required String receptriceId});
  Future<List<CardTrioEntity>> getTriosByDistance(int distance);
}
```

### GameSessionRepository

```dart
abstract class GameSessionRepository {
  Future<Map<String, dynamic>> createSession({required String userId, required int levelNumber});
  Future<void> updateSession({required String sessionId, required Map<String, dynamic> updates});
  Future<void> endSession({required String sessionId, required bool completed, required int durationSeconds});
}
```

---

## 3.5 LES USECASES

### ValidateTripletUseCase — "Ce trio est-il valide ?"

Le usecase le plus simple. Il delegue au repository.
```
Joueur tape une image -> call(E, C, R) -> repository.isCoherent() -> true/false
```

### GenerateQuestionUseCase — "Donne-moi une question"

Le usecase le plus complexe. Il orchestre :
```
1. getLevelConfig(level)       -> parametres du niveau
2. getRandomTrio(distance)     -> un trio aleatoire
3. getCardById() x3            -> les 3 cartes (en parallele)
4. Choisir config (A/B/C)      -> quelle carte masquer
5. getDistractors()            -> 9 fausses reponses
6. Assembler + melanger        -> GameQuestionEntity
```

### ActivateCodeUseCase — "Activer mon code de jeu"

Appelle directement l'Edge Function Supabase :
```
1. Valider le format (regex)   -> erreur si invalide
2. invoke('activate-code')     -> appel serveur
3. Analyser la reponse         -> succes, reconnexion, ou erreur
```

---

## 3.6 FICHIERS CREES

```
lib/domain/
  entities/
    card_entity.dart              ✅  Emettrice, Cable, Receptrice
    card_trio_entity.dart         ✅  Trio E + C = R
    user_entity.dart              ✅  Profil joueur
    game_question_entity.dart     ✅  Question de jeu
  repositories/
    card_repository.dart          ✅  Interface cartes
    card_trio_repository.dart     ✅  Interface trios
    game_session_repository.dart  ✅  Interface sessions
  usecases/
    validate_triplet_usecase.dart ✅  Verification de trio
    generate_question_usecase.dart✅  Generation de question
    activate_code_usecase.dart    ✅  Activation de code
```

**Resultat `flutter analyze` : No issues found!**

---

## 3.7 RECAPITULATIF

### Concepts Dart appris

| Concept | Utilisation |
|---------|-------------|
| `enum` | CardType (emettrice, cable, receptrice) |
| `class` avec `final` | Entites immuables |
| `const` constructor | Optimisation memoire Flutter |
| Parametres nommes `{}` | Constructeurs lisibles (required this.id) |
| Null safety `?` | Proprietes optionnelles (parentEmettriceId?) |
| `abstract class` | Interfaces de repositories |
| `Future<T>` et `async/await` | Operations asynchrones |
| `Future.wait` | Executer des requetes en parallele |
| Getter `get` | Proprietes calculees (imageUrl) |
| `late` | Variables initialisees plus tard |
| `switch` expression | Choix exhaustif selon un enum ou String |
| Spread `...` | Etaler une liste dans une autre |
| Cascade `..` | Appeler une methode et retourner l'objet |
| `RegExp` | Validation de format avec expressions regulieres |
| `throw` / `rethrow` | Lancer et relancer des exceptions |

### Prochain chapitre

**Chapitre 4 : Le Data Layer** — Nous allons implementer les repositories :
- `CardModel` : CardEntity + fromJson (deserialisation JSON)
- `CardTrioModel` : CardTrioEntity + fromJson
- `CardRepositoryImpl` : implementation concrete avec Supabase
- `DistractorService` : generation intelligente des distracteurs

C'est la couche qui PARLE a Supabase.
