# TRIALGO — Document Coeur du Projet

> Document de reference technique et fonctionnel.
> Couvre la logique du jeu, la formalisation mathematique, l'architecture,
> la strategie de synchronisation et les metriques de performance.

---

## Table des matieres

1. [Concept et philosophie](#1-concept-et-philosophie)
2. [Formalisation mathematique du graphe](#2-formalisation-mathematique-du-graphe)
3. [Logique des distances (D1 a D5)](#3-logique-des-distances-d1-a-d5)
4. [Regles de validation des trios](#4-regles-de-validation-des-trios)
5. [Algorithme de pre-computation](#5-algorithme-de-pre-computation)
6. [Principe de synchronisation](#6-principe-de-synchronisation)
7. [Occupation memoire](#7-occupation-memoire)
8. [Strategie de gameplay](#8-strategie-de-gameplay)
9. [Scoring et progression](#9-scoring-et-progression)
10. [Estimations de temps et longevite](#10-estimations-de-temps-et-longevite)
11. [Architecture logicielle](#11-architecture-logicielle)
12. [Persistance et securite](#12-persistance-et-securite)
13. [Extensibilite](#13-extensibilite)

---

## 1. Concept et philosophie

### 1.1 L'idee centrale

TRIALGO est un jeu d'**observation visuelle** ou chaque carte represente une image.
Le joueur doit identifier des relations entre ces images selon un principe fondamental :

```
  Emettrice  +  Cable  =  Receptrice
      E      +    C    =      R
```

- **E** (Emettrice) donne la **forme dominante**
- **C** (Cable) apporte une **transformation visuelle** (decor, motif, filtre)
- **R** (Receptrice) est le **resultat visuel** de la fusion E + C

### 1.2 Neutralite des cartes

Une carte est **neutre** : elle n'a pas de type fixe. Son role depend de sa
**position** dans un noeud. Une meme carte peut etre :
- Emettrice dans un noeud
- Cable dans un autre
- Receptrice dans un troisieme

### 1.3 Le trio comme unite atomique

Un **noeud** = un trio de 3 cartes liees par la relation E + C = R.
Chaque noeud est un **fait du jeu** : une combinaison validee par l'admin.

### 1.4 Principe du chainage

La receptrice d'un noeud peut devenir l'emettrice d'un autre noeud, creant des
**chaines de transformations** :

```
N1 :  E1 + C1 = R1
N2 :  R1 + C2 = R2    <- E2 = R1 (chainage)
N3 :  R2 + C3 = R3    <- E3 = R2
```

Ce chainage fonde toute la mecanique des distances.

---

## 2. Formalisation mathematique du graphe

### 2.1 Definition du graphe

Soit G = (N, E) un graphe oriente ou :
- **N** = ensemble des noeuds natifs (trios E+C=R)
- **E** = ensemble des aretes parent → enfant, tel que `enfant.E = parent.R`

### 2.2 Profondeur d'un noeud

La **profondeur** d'un noeud est la longueur du chemin depuis la racine :

```
depth(n) =
  1                     si n est une racine (pas de parent)
  depth(parent(n)) + 1  sinon
```

### 2.3 Chaine de profondeur k

Une chaine de k noeuds est une sequence :
```
C_k = [N_1, N_2, ..., N_k]
```
ou pour tout i ∈ [2, k] : `N_i.E = N_{i-1}.R`

### 2.4 Elements disponibles dans une chaine

Pour une chaine de k noeuds, les elements uniques sont :
```
Elements(C_k) = {E_1} ∪ {C_1, C_2, ..., C_k} ∪ {R_1, R_2, ..., R_k}
```

Nombre d'elements : `|Elements(C_k)| = 1 + k + k = 2k + 1`

| k | elements | contenu |
|:---:|:---:|:---|
| 1 | 3 | E1, C1, R1 |
| 2 | 5 | E1, C1, R1, C2, R2 |
| 3 | 7 | E1, C1, R1, C2, R2, C3, R3 |
| 4 | 9 | E1, C1, R1, C2, R2, C3, R3, C4, R4 |
| 5 | 11 | E1, C1, R1, ..., C5, R5 |

### 2.5 Notation des trios

Un **trio** T est un ensemble (non ordonne) de 3 elements :
```
T = {x, y, z}  avec  x, y, z ∈ Elements(C_k)
```

L'ordre des cartes dans un trio n'a pas de signification semantique, seule
l'appartenance compte.

---

## 3. Logique des distances (D1 a D5)

### 3.1 Distance 1

Un trio D1 correspond a un **noeud natif** :
```
T_D1 = {N.E, N.C, N.R}
```
Le joueur voit 2 cartes visibles et doit trouver la 3eme. C'est le cas de base.

### 3.2 Distance 2

Un trio D2 utilise des elements d'une chaine de 2 noeuds (`N_1 → N_2`).
Le trio contient toujours R_2 et n'est pas un noeud natif.

**Exemple** avec N1 : E1+C1=R1 et N2 : R1+C2=R2.

Les **5 trios valides** sont :
```
1. { E1, R1, R2 }     debut + lien + fin
2. { E1, C1, R2 }     debut + premier cable + fin
3. { C1, R1, R2 }     cable + lien + fin
4. { E1, C2, R2 }     debut + dernier cable + fin
5. { C1, C2, R2 }     les deux cables + fin
```

### 3.3 Distance 3

Un trio D3 utilise des elements d'une chaine de 3 noeuds (`N_1 → N_2 → N_3`).
Le trio contient toujours R_3 et n'est pas un noeud natif.

**14 trios valides** (selon la regle simple : contient R_k et n'est pas natif).

### 3.4 Generalisation

Pour une distance D_k :
- La chaine contient k noeuds
- Les elements disponibles sont au nombre de `2k + 1`
- Le trio contient toujours **R_k** (la receptrice finale)

---

## 4. Regles de validation des trios

### 4.1 Regle fondamentale

Un trio T est **valide** pour la distance D_k si et seulement si :

```
(i)   T ⊂ Elements(C_k)            (appartient a la chaine)
(ii)  |T| = 3                       (3 elements)
(iii) R_k ∈ T                       (contient la receptrice finale)
(iv)  T ≠ {N_j.E, N_j.C, N_j.R}    pour tout j ∈ [1, k]  (pas un noeud natif)
```

### 4.2 Consequence : nombre maximum de trios

Nombre de trios contenant R_k = `C(2k, 2)` (choisir 2 parmi les 2k autres).
Nombre de noeuds natifs contenant R_k = 1 (seul N_k contient R_k).

```
MaxTrios(D_k) = C(2k, 2) - 1
```

| Distance | C(2k, 2) | - natif | **Max par chaine** |
|:---:|:---:|:---:|:---:|
| D1 | 1 | -1 | 0 (= noeud lui-meme) |
| D2 | 6 | -1 | **5** |
| D3 | 15 | -1 | **14** |
| D4 | 28 | -1 | **27** |
| D5 | 45 | -1 | **44** |

### 4.3 Regle de distribution dans les parties

Pour eviter que le joueur voie deux trios issus de la meme chaine pendant la
**meme partie**, les trios sont ranges dans des **tableaux** :

```
Pour une distance D_k :
  - Nombre de tables = MaxTrios(D_k)
  - Chaque table contient 1 trio par chaine
  - Une partie pioche tous ses trios dans UNE SEULE table
```

Pour D2 (5 possibilites par paire) :
```
Table D2_1 : 1er trio de chaque paire  ex: {E1,R1,R2}, {E2,R2,R18}, ...
Table D2_2 : 2eme trio de chaque paire  ex: {E1,C1,R2}, {E2,C2,R18}, ...
Table D2_3 : 3eme trio de chaque paire
Table D2_4 : 4eme trio de chaque paire
Table D2_5 : 5eme trio de chaque paire
```

Une partie pioche dans **une seule table**. La table suivante est utilisee a la
partie suivante. Le joueur ne voit jamais deux trios de la meme paire dans la
meme partie.

### 4.4 Choix des distracteurs

Les **distracteurs** sont les 5 mauvaises reponses affichees a cote de la bonne.

Algorithme :
```
pour chaque question :
  1. Identifier la carte correcte (trio.masquee)
  2. Identifier les cartes a exclure :
     - La carte correcte elle-meme
     - Les 2 cartes visibles du trio
  3. Piocher 5 cartes aleatoirement dans Catalogue \ Exclusions
  4. Melanger : [correct, distracteur1, ..., distracteur5]
  5. Afficher dans une grille 3×2
```

Avec **61 cartes** dans le catalogue, il y a toujours au moins `61 - 3 = 58`
candidats pour les 5 distracteurs.

---

## 5. Algorithme de pre-computation

### 5.1 Objectif

Calculer une **seule fois** au demarrage tous les trios logiques possibles pour
toutes les distances, afin d'avoir un simple tirage en O(1) pendant le jeu.

### 5.2 Pseudocode

```
function precomputeLogicalNodes(graph):
  pools = { D1: [], D2: [], D3: [], D4: [], D5: [] }

  // D1 : trivial
  for node in graph.nodes:
    pools.D1.append(LogicalNode(node, distance=1))

  // D2..D5 : recursif
  for k in [2, 3, 4, 5]:
    for chain in graph.chainsOfLength(k):
      for trio in generateValidTrios(chain, k):
        pools[k].append(LogicalNode(trio, chain, distance=k))

  return pools
```

### 5.3 Organisation en tables

Apres pre-computation, on reorganise les pools en **tables** pour le tirage
sans collision :

```
function organizeInTables(pool_k, maxTrios_k):
  tables = [[] for _ in range(maxTrios_k)]
  for trio in pool_k:
    tables[trio.possibilityIndex].append(trio)
  return tables
```

### 5.4 Complexite

```
Complexite temporelle :
  O(|N|) pour D1
  O(|paires| × 5) pour D2 = O(|N|)
  O(|triples| × 14) pour D3 = O(|N|)
  ...
  O(|N|) globalement

Complexite spatiale :
  D1 : |N|
  D2 : |paires| × 5 ≤ |N| × 5
  D3 : |triples| × 14 ≤ |N| × 14
  ...
  Total O(|N|) par distance
```

Pour un graphe de 50 noeuds, la pre-computation prend **quelques ms** et
produit quelques centaines de trios.

---

## 6. Principe de synchronisation

### 6.1 Philosophie

Le jeu est **local-first**. La synchronisation avec Supabase a lieu :
- **Une seule fois** au demarrage (download du graphe du jeu)
- **A la fin de chaque partie** (upload score, cartes debloquees, noeuds joues)

Pendant une partie, **aucune requete reseau** n'est faite. Tout est en memoire.

### 6.2 Flow de synchronisation au demarrage

```
1. App demarre
   ↓
2. initSupabase() + lecture session locale
   ↓
3. Si session valide → checkProfile()
   Si non → AuthPage
   ↓
4. ProfileService.loadProfile() + loadUserGames()
   ↓
5. Selectionner le jeu actif (selected_game_id)
   ↓
6. GraphRepository.getAllCards(gameId)     [~12 KB]
   ↓
7. GraphRepository.getAllNodes(gameId)     [~8 KB]
   ↓
8. ProfileService.loadUnlockedCards()      [~5 KB]
   ↓
9. ProfileService.loadPlayedKeys()         [~5 KB]
   ↓
10. BuildGraphUseCase(nodes)               [sync, ~10 ms]
    - Indexer par nodeIndex
    - Resoudre emettrices (enfant.E = parent.R)
    - Regrouper par profondeur
    - Construire childrenOf
    ↓
11. PrecomputeLogicalNodes(graph)          [sync, ~50 ms]
    - D1, D2, D3, D4, D5
    ↓
12. Jeu pret !
```

**Total download : ~30 KB**. En 4G ou WiFi, ce transfert est instantane (<1s).

### 6.3 Flow pendant la partie

```
  AUCUNE requete reseau
  ─────────────────────
  • Tirage trio        : O(1) lecture dans table en memoire
  • Verification reponse : comparaison de string (card.id)
  • Calcul du score    : arithmetique pure
  • Affichage cartes   : CachedNetworkImage (telechargement a la demande)
```

Les **images** sont la seule chose qui peut generer du trafic reseau pendant la
partie. Mais elles sont **cachees localement** apres le premier affichage.

### 6.4 Flow a la fin de la partie

```
1. Calcul du score final
   ↓
2. UPDATE user_games SET total_score, lives, current_level, lives_last_refill
   WHERE user_id = ? AND game_id = ?       [1 requete, ~200 bytes]
   ↓
3. INSERT INTO user_unlocked_cards (nouvelles cartes gagnees)
   ON CONFLICT DO NOTHING                   [1 requete batch, ~500 bytes]
   ↓
4. INSERT INTO user_played_nodes (cles de tracking jouees)
   ON CONFLICT DO NOTHING                   [1 requete batch, ~300 bytes]
   ↓
5. Mise a jour du cache local (SharedPreferences)
```

**Total upload : ~1 KB**. Instantane.

### 6.5 Resume

| Phase | Requetes | Volume | Frequence |
|---|:---:|:---:|:---|
| Auth | 2-3 | ~2 KB | 1 fois par session |
| Sync initiale | 4 | ~30 KB | 1 fois par changement de jeu |
| Pendant la partie | 0 | 0 | — |
| Fin de partie | 3 | ~1 KB | Apres chaque partie |
| Images | N | variable | Lazy + cache |

---

## 7. Occupation memoire

Cette section detaille precisement la memoire occupee par **chaque structure
initialisee** par l'application, avec les tailles reelles des objets Dart.

### 7.1 Base : taille des objets Dart

En Dart, chaque objet a un **header** d'environ 16 octets (classe + taille +
hash). Il faut l'ajouter aux valeurs propres. Les references (pointeurs) font
8 octets chacune.

| Type Dart | Taille (bytes) |
|:---|:---:|
| Header objet | 16 |
| `int` | 8 |
| `double` | 8 |
| `bool` | 1 |
| reference (pointeur) | 8 |
| `String` | 16 + 2 × length (UTF-16) |
| Map entry (cle+valeur+hash+next) | ~40 |
| List entry (reference) | ~8 |

### 7.2 Entites et modeles (taille unitaire)

#### GraphCardEntity

```
Champ                               Octets
──────────────────────────────────────────
Header                                  16
id          (UUID, 36 caracteres)       88   (16 + 72)
label       (~12 caracteres)            40
imagePath   (~60 caracteres)           136
──────────────────────────────────────────
TOTAL par GraphCardEntity            ~280 octets
```

#### GraphNodeEntity

```
Champ                               Octets
──────────────────────────────────────────
Header                                  16
id                                      88
nodeIndex            (int)               8
emettriceId          (String?)          88
cableId              (String)           88
receptriceId         (String)           88
parentNodeId         (String?)          88
depth                (int)               8
resolvedEmettriceId  (String? mut)      88
──────────────────────────────────────────
TOTAL par GraphNodeEntity            ~560 octets
```

#### LogicalNodeEntity

```
Champ                               Octets
──────────────────────────────────────────
Header                                  16
trackingKey   (~25 caracteres)          66
distance      (int)                      8
cardA         (ref)                      8
cardB         (ref)                      8
cardC         (ref)                      8
sourceNodes   (List, 2-3 refs)          40
──────────────────────────────────────────
TOTAL par LogicalNodeEntity          ~154 octets
```

### 7.3 Structures principales initialisees

#### GraphSyncService (singleton)

```
GraphSyncService
│
├── Map<String, GraphCardEntity> cards      (61 entrees)
│   ├── 61 entrees × 40 octets                    2 440
│   └── 61 × GraphCardEntity × 280               17 080
│   TOTAL                                      ~19.5 KB
│
├── GameGraph? gameGraph
│   │
│   ├── Map<int, GraphNodeEntity> nodesByIndex  (50 entrees)
│   │   ├── 50 × 40                              2 000
│   │   └── 50 × GraphNodeEntity × 560          28 000
│   │   TOTAL                                   ~30 KB
│   │
│   ├── Map<int, List<GraphNodeEntity>> nodesByDepth
│   │   ├── 3 entrees (depth 1, 2, 3)              120
│   │   └── Listes de refs (50 refs total)         400
│   │   TOTAL                                   ~0.5 KB
│   │
│   └── Map<int, List<GraphNodeEntity>> childrenOf
│       ├── ~30 entrees (parents)                1 200
│       └── ~35 refs enfants                       280
│       TOTAL                                   ~1.5 KB
│
├── LogicalNodesPool? logicalNodes
│   │
│   ├── List<LogicalNodeEntity> logicalD1      (50 trios)
│   │   ├── 50 × 8 (refs)                          400
│   │   └── 50 × LogicalNodeEntity × 154         7 700
│   │   TOTAL                                     ~8 KB
│   │
│   ├── List<LogicalNodeEntity> logicalD2      (100 trios)
│   │   TOTAL                                    ~16 KB
│   │
│   ├── List<LogicalNodeEntity> logicalD3      (210 trios)
│   │   TOTAL                                    ~33 KB
│   │
│   ├── List<LogicalNodeEntity> logicalD4      (0 sans D4)   0 KB
│   └── List<LogicalNodeEntity> logicalD5      (0 sans D5)   0 KB
│
└── String? currentGameId                           ~90
─────────────────────────────────────────────────────────
TOTAL GraphSyncService                           ~110 KB
```

#### GenerateGameQuestionUseCase (singleton)

```
GenerateGameQuestionUseCase
│
├── GraphSyncService _syncService (ref)              8
├── Random _random                                  40
│
└── Set<String> _usedTrackingKeys
    │
    ├── Au demarrage                                  0
    ├── Croissance lineaire : ~40 octets / cle
    │
    └── Apres saturation (toutes parties jouees)
        360 cles × 40 octets                   ~14 KB
─────────────────────────────────────────────────────────
TOTAL au max                                    ~14 KB
```

#### ProfileNotifier (singleton Riverpod)

```
ProfileNotifier
│
└── AppProfileState state
    │
    ├── Map general (user_profiles, ~5 cles)        200
    ├── Map gameStats (user_games, ~8 cles)         320
    ├── List<GameEntity> games (1-3 jeux)           200
    └── Set<String> unlockedCards (max 60 cartes)  1 600
─────────────────────────────────────────────────────────
TOTAL ProfileNotifier                             ~2.5 KB
```

#### AudioService (singleton)

```
AudioService
│
├── AudioPlayer × 2 (native Android / iOS)
│   └── Ressources natives (hors heap Dart)       ~50 KB
│
├── StreamController × 5
│   └── ~2 KB
│
├── _currentTrack (MusicTrack enum)                     8
├── _musicUrls Map<MusicTrack, String>               ~1 KB
├── _sfxUrls Map<SoundEffect, String>             ~1.5 KB
├── _failedSfx Set<SoundEffect>                        40
└── prefs flags (bool, double)                        ~40
─────────────────────────────────────────────────────────
TOTAL AudioService (Dart heap)                    ~4.5 KB
TOTAL AudioService (avec natif)                   ~55 KB
```

### 7.4 Cache d'images (CachedNetworkImage)

```
Cache memoire
├── Limite par defaut : 100 images simultanees
├── Poids moyen : ~30 KB par image compressee
├── Max theorique : 100 × 30 KB = 3 MB
└── En pratique TRIALGO : ~60 images × 30 KB = ~1.8 MB

Cache disque (persistant)
├── Limite par defaut : 100 MB
├── TRIALGO reel : ~1.8 MB (toutes les cartes)
└── Gere automatiquement par CachedNetworkImage
```

### 7.5 Totaux consolides

```
┌────────────────────────────────┬────────────────┐
│  STRUCTURE                     │  MEMOIRE VIVE  │
├────────────────────────────────┼────────────────┤
│  GraphSyncService              │    ~110 KB     │
│    ├─ Map cards (61)           │      ~20 KB    │
│    ├─ GameGraph                │      ~32 KB    │
│    │   ├─ nodesByIndex         │      ~30 KB    │
│    │   ├─ nodesByDepth         │     ~0.5 KB    │
│    │   └─ childrenOf           │     ~1.5 KB    │
│    └─ LogicalNodesPool         │      ~57 KB    │
│        ├─ logicalD1 (50)       │       ~8 KB    │
│        ├─ logicalD2 (100)      │      ~16 KB    │
│        └─ logicalD3 (210)      │      ~33 KB    │
│                                │                │
│  GenerateQuestionUseCase       │     ~14 KB     │
│    └─ usedTrackingKeys (max)   │      ~14 KB    │
│                                │                │
│  ProfileNotifier               │    ~2.5 KB     │
│    └─ AppProfileState          │     ~2.5 KB    │
│                                │                │
│  AudioService (Dart)           │    ~4.5 KB     │
│  AudioService (natif)          │     ~50 KB     │
│                                │                │
│  Cache images (memoire)        │    ~1.8 MB     │
│  Cache images (disque)         │    ~1.8 MB     │
├────────────────────────────────┼────────────────┤
│  TOTAL Dart heap               │    ~131 KB     │
│  TOTAL avec natif audio        │    ~181 KB     │
│  TOTAL avec cache images       │    ~2 MB       │
└────────────────────────────────┴────────────────┘
```

### 7.6 Evolution au cours d'une session

```
INSTANT T0 : app fraichement lancee
  → ~55 KB (services natifs + audio)

INSTANT T1 : apres sync du graphe
  → ~185 KB (+ GraphSyncService rempli)

INSTANT T2 : premiere question jouee
  → ~185 KB (inchange, tracking += 40 octets)

INSTANT T3 : 10 questions jouees
  → ~185 KB + 400 octets tracking

INSTANT T4 : fin de session avec 50 questions
  → ~185 KB + 2 KB tracking
  → Upload vers Supabase

INSTANT T5 : apres 10 sessions completes
  → ~185 KB + 14 KB tracking (max)
  → Les images vues sont cachees sur disque
```

### 7.7 Implications pratiques

**Pour un telephone moderne avec 2 GB de RAM** :
- TRIALGO occupe **~200 KB** de heap Dart (0.01% de la RAM)
- Le cache images est **~2 MB** au total (0.1% de la RAM)
- **Impact : negligeable**, l'app peut tourner sans contrainte

**Pour un vieux telephone avec 512 MB de RAM** :
- TRIALGO occupe toujours ~200 KB heap (0.04% de la RAM)
- Cache images ~2 MB (0.4% de la RAM)
- **Impact : toujours negligeable**

**Pour un telephone bas de gamme avec 1 GB stockage disque** :
- Cache images sur disque : ~2 MB
- Base SharedPreferences : ~50 KB
- **Impact : 0.2% du stockage**

### 7.8 Points d'attention

1. **Le `Set<String> usedTrackingKeys` grandit lineairement** avec les parties
   jouees. Apres toutes les parties (~45 dans le graphe actuel), il atteint
   ~14 KB. Cela reste minimal mais il faudra le **reset** entre les jeux ou
   le **purger periodiquement** si on ajoute beaucoup de contenu.

2. **Les noeuds logiques sont tous en memoire des la sync**. Pour un graphe
   a profondeur 5 (D5 active), cela pourrait monter a ~300 KB de pool logique.
   Toujours negligeable, mais a surveiller.

3. **Les `StreamController` de `AudioService` sont `.broadcast()`** donc
   n'accumulent pas d'events non consommes. Pas de fuite memoire.

4. **Le cache `CachedNetworkImage` est gere par le package** avec eviction
   automatique LRU. Pas de risque de saturation.

5. **Les references dans les `Map` sont des pointeurs**, pas des copies. Ainsi
   `childrenOf` et `nodesByIndex` pointent vers les **memes instances** de
   `GraphNodeEntity`. Pas de duplication.

---

## 8. Strategie de gameplay

### 8.1 Ordre de progression

```
Niveau 1  → Distance 1 (partie 1)
Niveau 2  → Distance 1 (partie 2)
...
Niveau 6  → Distance 1 (partie 6, derniere)
Niveau 7  → Distance 2 (partie 1 avec Table D2_1)
...
Niveau 11 → Distance 2 (partie 5 avec Table D2_5)
Niveau 12 → Distance 3 (partie 1 avec Table D3_1)
...
```

Chaque niveau = 1 partie = N questions.

### 8.2 Configuration d'une question (A, B, C)

Pour une carte donnee, 3 configurations sont possibles selon ce qui est masque :

| Config | Visible | Masquee | Niveau |
|:---:|:---:|:---:|:---:|
| A | cardA, cardB | **cardC** | facile |
| B | cardA, cardC | **cardB** | moyen |
| C | cardB, cardC | **cardA** | difficile |

Le choix de la config depend du niveau :
```
Niveau 1-6   : config A uniquement        (facile)
Niveau 7-14  : config A ou B              (moyen)
Niveau 15+   : config A, B ou C           (difficile)
```

### 8.3 Flow d'une question

```
1. Determiner distance, configs autorisees (GameConstants.getLevelConfig)
2. Tirer un trio depuis la table courante (non encore joue)
3. Choisir une config au hasard parmi les autorisees
4. Determiner les cartes visibles + la masquee
5. Generer 5 distracteurs depuis le catalogue
6. Assembler et melanger les 6 choix
7. Afficher a l'ecran, demarrer le timer
8. Ecouter la reponse (tap) ou timeout
9. Verifier (cardId == correctCardId)
10. Feedback visuel + sonore + animation
11. Mise a jour state (score, lives, streak)
12. Passer a la question suivante ou fin de partie
```

---

## 9. Scoring et progression

### 9.1 Formule de base

```
score_question = basePoints × distanceMultiplier × timeBonus + streakBonus
```

### 9.2 Parametres par niveau

| Niveau | Distance | Configs | Qst | Seuil | Temps | Points base |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1-3 | D1 | A | 8 | 6/8 | 30s | 10 |
| 4-6 | D1 | A+B | 10 | 7/10 | 35s | 15 |
| 7-10 | D2 | A+B | 10 | 7/10 | 40s | 20 |
| 11-14 | D2 | B | 10 | 7/10 | 45s | 25 |
| 15-18 | D3 | B+C | 12 | 8/12 | 50s | 35 |
| 19-22 | D3 | C | 12 | 9/12 | 55s | 50 |
| 23+ | D3 | A+B+C | 15 | 11/15 | 45s | 75 |

### 9.3 Multiplicateurs

- **distanceMultiplier** : x1.0 (D1), x1.5 (D2), x2.0 (D3), x2.5 (D4), x3.0 (D5)
- **timeBonus** :
  - <25% du temps : x1.5 (Turbo)
  - <50% : x1.25 (Rapide)
  - <75% : x1.0 (Normal)
  - >=75% : x0.75 (Lent)
- **streakBonus** :
  - +10 points apres 3 bonnes reponses consecutives
  - +25 points apres 7 bonnes reponses consecutives (MEGA_STREAK)

### 9.4 Vies

```
Max  : 5
Perte : selon livesPerWrong (3 au debut, 2 niveau 7+, 1 niveau 15+)
Recharge : +1 toutes les 30 min (cron Supabase)
Achat : possible avec les points (100 pts = 1 vie)
```

### 9.5 Progression de niveau

```
Si correctAnswers >= seuil :
  - Niveau passe  → currentLevel += 1
  - Etoiles : 1 (seuil), 2 (>=80%), 3 (100%)
  - Nouvelles cartes debloquees (ajoutees au deck)
Sinon :
  - Niveau echoue → pas de progression
  - Peut rejouer
```

---

## 10. Estimations de temps et longevite

### 10.1 Duree d'une partie

```
1 question :
  - Chargement trio + affichage  : instantane
  - Temps de reflexion joueur    : 5 a 30 secondes
  - Feedback apres reponse       : 1.8 secondes
  ─────────────────────────────
  ≈ 8 a 32 secondes par question

1 partie de 10 questions :
  ≈ 80 a 320 secondes
  ≈ 1.3 a 5.5 minutes

1 partie moyenne              ≈ 3 minutes
```

### 10.2 Longevite totale (graphe actuel)

```
Total trios logiques precomputables :
  D1 :  50 trios
  D2 : 100 trios
  D3 : 210 trios
  ─────────────
  360 trios

Nombre de parties jouables (8 questions par partie) :
  ≈ 45 parties

Temps total de jeu :
  45 parties × 3 minutes ≈ 135 minutes
  ≈ 2 heures 15 minutes de contenu unique
```

### 10.3 Longevite etendue (graphe D4 + D5)

Si on etend le graphe a profondeur 5 :
```
D4 :  27 × 10 chaines = 270 trios
D5 :  44 ×  5 chaines = 220 trios
  ─────────────────────
 +490 trios

Total etendu : 850 trios
Parties      : 106 parties
Temps        : 5 heures de contenu unique
```

### 10.4 Replayabilite

Une fois toutes les parties jouees, le joueur peut :
- **Rejouer** les niveaux pour ameliorer son score (3 etoiles)
- **Attendre** les mises a jour de contenu (admin ajoute des noeuds)
- **Activer** un autre jeu (ex: code X124 pour un deck Ocean)

---

## 11. Architecture logicielle

### 11.1 Clean Architecture

```
  ┌──────────────────────────────────────┐
  │        Presentation (Flutter)        │
  │  - Widgets, Pages, Providers         │
  │  - Animations, UI, State management  │
  └──────────────────┬───────────────────┘
                     │
  ┌──────────────────▼───────────────────┐
  │            Domain (pur)              │
  │  - Entities (GraphNode, Card)         │
  │  - Repositories (interfaces)          │
  │  - Usecases (BuildGraph, GenerateQ)   │
  └──────────────────┬───────────────────┘
                     │
  ┌──────────────────▼───────────────────┐
  │          Data (implementation)        │
  │  - Models (JSON <-> Entity)          │
  │  - Repositories (Supabase)            │
  │  - Services (Sync, Audio, Profile)    │
  └──────────────────┬───────────────────┘
                     │
  ┌──────────────────▼───────────────────┐
  │        Backend (Supabase)             │
  │  - PostgreSQL tables                  │
  │  - Row Level Security                 │
  │  - Edge Functions (activate_code)     │
  │  - Storage (optionnel, images)        │
  └──────────────────────────────────────┘
```

### 11.2 Flux de donnees

```
User action (tap)
  → ConsumerWidget.onTap
    → ref.read(provider).method()
      → UseCase.call(params)
        → Repository.method()
          → Supabase query / local cache

Result flow inverse (retour de donnees).
```

### 11.3 Gestion d'etat (Riverpod)

- **Providers** : singleton services (audio, profile, graph)
- **StateNotifierProvider** : etats reactifs (profile state, game state)
- **FutureProvider / StreamProvider** : donnees asynchrones

---

## 12. Persistance et securite

### 12.1 Tables Supabase

```
games                - Catalogue des jeux disponibles
cards                - Catalogue de cartes par jeu
nodes                - Graphe (trios natifs)
activation_codes     - Codes uniques par utilisateur
user_profiles        - Profil joueur (avatar, pseudo)
user_games           - Stats par jeu (score, niveau, vies)
user_unlocked_cards  - Deck du joueur
user_played_nodes    - Tracking des trios joues
```

### 12.2 Row Level Security

Chaque table a des politiques RLS :
- **Lecture** : autorisee a tous les utilisateurs authentifies (pour cards, nodes, games)
- **Lecture perso** : `user_id = auth.uid()` pour les tables utilisateur
- **Ecriture admin** : `auth.jwt() ->> 'email' = 'admin@trialgo.com'`

### 12.3 Device binding

```
Fonction SQL activate_code() :
  1. Verifie existence et validite du code
  2. Premier use : assigne user_id + device_id
  3. Re-use meme device : OK
  4. Changement device : incremente compteur
  5. Si compteur >= 3 : code bloque definitivement
```

Un compte = un device. Protection anti-partage.

### 12.4 Multi-jeux

Un utilisateur peut avoir plusieurs codes, chacun liant a un jeu different :
```
Marc : X001 → Jeu Savane
Marc : X042 → Jeu Ocean
Marc : X088 → Jeu Foret
```

---

## 13. Extensibilite

### 13.1 Ajouter un jeu

1. Admin cree un jeu dans `games`
2. Admin ajoute des cartes dans `cards` avec `game_id`
3. Admin cree des noeuds dans `nodes` avec le graphe
4. Admin genere des codes d'activation lies au jeu
5. Distribution aux joueurs

### 13.2 Ajouter une distance (D6, D7)

Le code est deja prevu pour :
- La formule mathematique fonctionne pour tout k
- `BuildGraphUseCase` supporte n'importe quelle profondeur
- Il suffit d'ajouter des noeuds plus profonds dans la BDD

### 13.3 Mode collectif

Deja implemente via la fonction SQL `verify_collective_trio()` :
```
Input  : game_id + numero de trio
Output : { exists, labels E/C/R, depth }
```

Utilise pour verifier des trios lors d'un jeu physique entre plusieurs joueurs.

### 13.4 Ajouter des modes de jeu

Possibilites futures :
- **Mode chronometre** : completer X questions en Y secondes
- **Mode survie** : 1 seule vie, combien de questions ?
- **Mode expert** : uniquement distances elevees (D4, D5)
- **Mode daily** : defi quotidien avec un jeu unique

---

## 14. Metriques cles en un coup d'oeil

| Metrique | Valeur |
|:---|:---:|
| Cartes par jeu (current) | 61 |
| Noeuds natifs par jeu | 50 |
| Profondeur max graphe actuel | 3 |
| Trios logiques precomputables | 360 |
| Parties jouables (8 q/partie) | ≈ 45 |
| Temps total de contenu | ≈ 2h15 |
| Temps de sync initiale | <1s |
| Memoire occupee (hors images) | ~160 KB |
| Requetes pendant la partie | 0 |
| Vies max | 5 |
| Cout vie en points | 100 |
| Max changements de device | 3 |
| Nombre de distances supportees | 5 (D1-D5) |
| Nombre de configurations | 3 (A, B, C) |
| Distracteurs par question | 5 |

---

## 15. Conclusion

TRIALGO est un jeu d'observation base sur :

1. **Un concept fort** : la relation E + C = R entre cartes neutres
2. **Une formalisation mathematique claire** : graphe oriente, chaines, trios
3. **Une regle simple et elegante** : `MaxTrios(D_k) = C(2k, 2) - 1`
4. **Une architecture local-first** : sync 1 fois, jeu en memoire, 0 requete
5. **Une scalabilite naturelle** : multi-jeux, multi-distances, multi-joueurs
6. **Une securite renforcee** : device binding, RLS, fonction SQL centralisee

Le moteur du jeu est **leger** (~160 KB), **rapide** (pre-computation en <100 ms),
et **robuste** (fonctionne offline apres sync initiale).

La pre-computation des trios en tables garantit une repartition equitable des
possibilites entre les parties, offrant une experience sans repetition immediate
tout en utilisant efficacement le graphe existant.

---

*Document v1.0 — 11 avril 2026 — TRIALGO core engine*
