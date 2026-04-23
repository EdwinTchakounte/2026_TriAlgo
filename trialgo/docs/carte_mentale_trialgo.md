# TRIALGO — Carte Mentale du Jeu

> Document de reference pour l'implementation du jeu TRIALGO.
> Chaque section decrit un aspect du jeu de maniere detaillee.

---

## Table des matieres

1. [Concept fondamental](#1-concept-fondamental)
2. [Le Graphe](#2-le-graphe)
3. [Les Distances](#3-les-distances)
4. [Les Configurations](#4-les-configurations)
5. [Deroulement complet d'une partie](#5-deroulement-complet-dune-partie)
6. [Generation d'une question](#6-generation-dune-question)
7. [Systeme de score](#7-systeme-de-score)
8. [Systeme de vies](#8-systeme-de-vies)
9. [Tracking des noeuds joues](#9-tracking-des-noeuds-joues)
10. [Progression des niveaux](#10-progression-des-niveaux)
11. [Architecture Backend / Local](#11-architecture-backend--local)
12. [Interface Admin](#12-interface-admin)
13. [Architecture fichiers](#13-architecture-fichiers)

---

## 1. Concept fondamental

### Une carte est neutre

Dans TRIALGO, une carte est simplement une **image**. Elle n'a pas de type fixe.
Son role depend de sa **position** dans un noeud.

La meme carte peut etre :
- **Emettrice** dans le noeud N01
- **Cable** dans le noeud N25
- **Receptrice** dans le noeud N12

### Le noeud : brique de base

Un noeud est un **trio de 3 cartes** liees par une relation de fusion visuelle :

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│          │     │          │     │          │
│ EMETTRICE│  +  │  CABLE   │  =  │RECEPTRICE│
│   (E)    │     │   (C)    │     │   (R)    │
│          │     │          │     │          │
│  forme   │     │ decor /  │     │ resultat │
│ dominante│     │ transfo  │     │ de fusion│
└──────────┘     └──────────┘     └──────────┘
```

- **E (Emettrice)** : donne la forme dominante au resultat
- **C (Cable)** : apporte le decor et les transformations visuelles
- **R (Receptrice)** : nouvelle carte nee de la fusion visuelle de E + C

---

## 2. Le Graphe

### Structure : arbre de 50 noeuds, profondeur 3

Le graphe est un **arbre** ou chaque noeud contient un trio (E + C = R).
Les noeuds sont relies par une regle simple :

> **Regle de chainage : l'Emettrice d'un enfant est TOUJOURS la Receptrice de son parent.**

### Repartition

| Profondeur | Nombre de noeuds | Role |
|:---:|:---:|:---|
| 1 | 15 noeuds | Racines — E est une carte de base |
| 2 | 20 noeuds | Enfants — E = R du parent |
| 3 | 15 noeuds | Petits-enfants — E = R du parent (P2) |
| **Total** | **50 noeuds** | |

### Cartes necessaires

| Type | Quantite | Detail |
|:---|:---:|:---|
| Emettrices (base) | 5 | E1 a E5, reutilisees dans plusieurs noeuds |
| Cables | 6 | C1 a C6, reutilises dans plusieurs noeuds |
| Receptrices | 50 | R01 a R50, 1 unique par noeud |
| **Total** | **61 cartes** | |

### Exemple : famille "Lion" (E1)

```
E1─┬─+C1─► N01(R01)─┬─+C2─► N16(R16)─┬─+C5─► N36(R36)
   │                 │                 └─+C6─► N37(R37)
   │                 └─+C4─► N17(R17)────+C3─► N38(R38)
   │
   ├─+C2─► N02(R02)───+C3─► N18(R18)
   │
   └─+C3─► N03(R03)───+C5─► N19(R19)
```

**Lecture :**
- N01 : `E1 (Lion) + C1 (Miroir) = R01 (Lion Miroir)`
- N16 : `R01 (Lion Miroir) + C2 (Rotation) = R16 (Lion Spirale)` — E de N16 = R de N01
- N36 : `R16 (Lion Spirale) + C5 (Fragment) = R36 (Lion Cristal)` — E de N36 = R de N16

### Reutilisation des cartes

Une meme carte apparait dans **plusieurs noeuds** a des positions differentes :

- **E1 (Lion)** → Emettrice dans N01, N02, N03 (3 noeuds)
- **C1 (Miroir)** → Cable dans N01, N04, N07, N26, N29... (7+ noeuds)
- **R01 (Lion Miroir)** → Receptrice dans N01, mais **Emettrice** dans N16 et N17

---

## 3. Les Distances

La distance determine **d'ou viennent** les 3 cartes presentees au joueur.
Quelle que soit la distance, le format est **toujours le meme** :

> **2 cartes visibles + 1 carte masquee = 3 cartes presentees**

### Distance 1 — les 3 cartes viennent de 1 noeud

```
N01 :  E1 + C1 = R01

Trio presente : ( E1 , C1 , R01 )
                  │    │     │
                N01  N01   N01    ← tout vient du meme noeud
```

Le joueur voit une relation **directe** entre les cartes.

### Distance 2 — les 3 cartes viennent de 2 noeuds lies

```
N01 :  E1  + C1 = R01
N16 :  R01 + C2 = R16

Trio presente : ( E1 , R01 , R16 )
                  │     │      │
                N01  N01/N16  N16
                       ↑
                 R01 est le LIEN entre les 2 noeuds
```

Le joueur ne voit **pas** C1 ni C2. Il doit comprendre la relation
entre des cartes separees par des transformations intermediaires invisibles.

### Distance 3 — les 3 cartes viennent de 3 noeuds lies

```
N01 :  E1  + C1 = R01
N16 :  R01 + C2 = R16
N36 :  R16 + C5 = R36

Trio presente : ( E1 , R16 , R36 )
                  │      │      │
                N01    N16    N36
                 ↑       ↑      ↑
               debut  milieu   fin de la chaine
```

Le joueur ne voit **pas** C1, C2, C5, ni R01. La relation est encore
plus abstraite — il doit identifier la similarite entre des cartes
separees par 2 niveaux de transformations.

### Pourquoi la difficulte augmente

| Distance | Cartes visibles | Transformations cachees | Difficulte |
|:---:|:---|:---:|:---:|
| D1 | E et C du meme noeud | 0 | Facile |
| D2 | Debut et lien de la chaine | 1 (C1 cache) | Moyen |
| D3 | Debut et milieu de la chaine | 2 (C1, C2 caches) | Difficile |

---

## 4. Les Configurations

La configuration determine **quelle carte est masquee** parmi les 3 du trio.

### Les 3 configurations

Pour un trio ( A , B , C ) :

| Config | Visibles | Masquee (a trouver) | Difficulte |
|:---:|:---:|:---:|:---:|
| **A** | A + B | C | Facile |
| **B** | A + C | B | Moyen |
| **C** | B + C | A | Difficile |

### Exemples concrets par distance

**Distance 1** — Trio : ( E1 , C1 , R01 )

| Config | Visible | Masquee | Question implicite |
|:---:|:---:|:---:|:---|
| A | E1 + C1 | **R01** | "Quel est le resultat de cette fusion ?" |
| B | E1 + R01 | **C1** | "Quel element a transforme E1 en R01 ?" |
| C | C1 + R01 | **E1** | "Quelle est l'image de depart ?" |

**Distance 2** — Trio : ( E1 , R01 , R16 )

| Config | Visible | Masquee | Question implicite |
|:---:|:---:|:---:|:---|
| A | E1 + R01 | **R16** | "Quelle est l'etape suivante ?" |
| B | E1 + R16 | **R01** | "Quelle est l'etape intermediaire ?" |
| C | R01 + R16 | **E1** | "Quel est le point de depart ?" |

**Distance 3** — Trio : ( E1 , R16 , R36 )

| Config | Visible | Masquee | Question implicite |
|:---:|:---:|:---:|:---|
| A | E1 + R16 | **R36** | "Quelle est l'etape finale ?" |
| B | E1 + R36 | **R16** | "Quelle est l'etape intermediaire ?" |
| C | R16 + R36 | **E1** | "Quel est l'ancetre commun ?" |

---

## 5. Deroulement complet d'une partie

### Phase 1 : Lancement

```
Ouverture app
    │
    ▼
Initialisation Supabase SDK
    │
    ▼
Session existante ? ──NON──► Page Auth (email/mdp ou Google)
    │ OUI                              │
    ▼                                  ▼
Splash (auto-login)           Activation (code, 1ere fois)
    │                                  │
    └──────────────┬───────────────────┘
                   ▼
             PAGE D'ACCUEIL
```

### Phase 2 : Navigation

```
PAGE D'ACCUEIL
    │
    ├── Tutoriel
    ├── Galerie
    ├── Classement
    ├── Profil / Parametres / Avatar / Langue
    ├── Admin (si admin@trialgo.com uniquement)
    │
    └── JOUER ──► Carte des niveaux
                       │
                       ▼
                  Tap sur un niveau debloque
```

### Phase 3 : Initialisation de la partie

```
1. SYNCHRONISATION (si premiere fois)
   Supabase → Local
   Telecharger toutes les cartes (61)
   Telecharger tous les noeuds (50)

2. CONSTRUCTION DU GRAPHE
   Indexer les noeuds par index
   Resoudre les emettrices : enfant.E = parent.R
   Regrouper par profondeur (1, 2, 3)
   Construire les listes d'enfants

3. PARAMETRES DU NIVEAU
   Distance (1, 2 ou 3)
   Configs disponibles (A, B, C ou mix)
   Nombre de questions
   Seuil de reussite
   Temps par question
   Points de base
```

### Phase 4 : Boucle de jeu

```
Pour chaque question (repetee N fois) :

  1. Selectionner un noeud/chaine non joue
  2. Extraire le trio de 3 cartes
  3. Choisir la config (A, B ou C)
  4. Generer 5 distracteurs
  5. Melanger : 1 bonne + 5 fausses = 6 choix
  6. Afficher la question
  7. Attendre la reponse (ou timeout)
  8. Verifier localement
  9. Feedback visuel (1.8s)
  10. Question suivante ou fin de partie
```

### Phase 5 : Fin de partie

```
Bonnes reponses >= seuil ?
    │
    ├── OUI : Niveau reussi
    │         Etoiles attribuees (1, 2 ou 3)
    │         Niveau suivant debloque
    │         Score total mis a jour
    │
    └── NON : Niveau echoue
              Pas de progression
              Peut rejouer le meme niveau

    ▼
Page Resultats
    Score, bonnes/mauvaises, streak, bonus, etoiles
    [Rejouer] [Accueil]
```

---

## 6. Generation d'une question

### Etape 1 : Selection du trio

Selon la distance du niveau, le systeme choisit un noeud ou une chaine :

| Distance | Source | Trio extrait | Cle de tracking |
|:---:|:---|:---|:---|
| D1 | 1 noeud (ex: N01) | E1, C1, R01 | `"N01"` |
| D2 | 2 noeuds lies (ex: N01 + N16) | E1, R01, R16 | `"N01-N16"` |
| D3 | 3 noeuds lies (ex: N01 + N16 + N36) | E1, R16, R36 | `"N01-N16-N36"` |

Le systeme verifie que la cle de tracking n'a pas deja ete utilisee.

### Etape 2 : Masquage selon la config

Le trio selectionne est ( A , B , C ). Selon la configuration :
- Config A : masquer C → le joueur voit A + B
- Config B : masquer B → le joueur voit A + C
- Config C : masquer A → le joueur voit B + C

### Etape 3 : Distracteurs

```
Catalogue local : 61 cartes
Exclure         : les 3 cartes du trio
Piocher         : 5 cartes au hasard dans le reste
Assembler       : 1 bonne reponse + 5 distracteurs = 6 choix
Melanger        : ordre aleatoire
```

### Etape 4 : Affichage

```
┌───────────────────────────────────────────────────┐
│  BARRE SUPERIEURE                                 │
│  [ ♥♥♥ ]    Score: 420    Q: 3/10    timer 28s   │
├───────────────────────────────────────────────────┤
│                                                   │
│  ZONE DU TRIO                                     │
│                                                   │
│   ┌────────┐         ┌────────┐         ┌──────┐ │
│   │        │         │        │         │  ??  │ │
│   │ carte  │    +    │ carte  │    =    │      │ │
│   │visible1│         │visible2│         │ glow │ │
│   │        │         │        │         │      │ │
│   └────────┘         └────────┘         └──────┘ │
│                                         masquee  │
├───────────────────────────────────────────────────┤
│                                                   │
│  GRILLE DE CHOIX (3 x 2)                          │
│                                                   │
│   ┌──────┐  ┌──────┐  ┌──────┐                   │
│   │      │  │      │  │  ★   │                   │
│   │  d1  │  │  d2  │  │BONNE │                   │
│   └──────┘  └──────┘  └──────┘                   │
│   ┌──────┐  ┌──────┐  ┌──────┐                   │
│   │      │  │      │  │      │                   │
│   │  d3  │  │  d4  │  │  d5  │                   │
│   └──────┘  └──────┘  └──────┘                   │
│                                                   │
│   1 bonne + 5 distracteurs = 6 cartes             │
│   Positions melangees aleatoirement               │
│                                                   │
└───────────────────────────────────────────────────┘
```

### Etape 5 : Verification

```
Le joueur tape une carte OU le timer atteint 0

Si carte.id == correctId :
    ✓ BONNE REPONSE
    correctAnswers++
    streak++
    Score += basePoints × distanceMultiplier × timeBonus
    Feedback : banniere verte, particules vertes, scale score

Sinon :
    ✗ MAUVAISE REPONSE (ou TIMEOUT)
    wrongAnswers++
    streak = 0
    Si wrongAnswers atteint le seuil livesPerWrong → lives--
    Feedback : banniere rouge, shake, bonne reponse revelee

Pause 1.8s (animation feedback)

Si vies > 0 ET questionNum < totalQuestions :
    → question suivante
Sinon :
    → fin de partie
```

---

## 7. Systeme de score

### Formule par bonne reponse

```
score = basePoints × distanceMultiplier × timeBonus
```

### Base points (selon le niveau)

| Niveaux | Points de base |
|:---:|:---:|
| 1-3 | 10 |
| 4-6 | 15 |
| 7-10 | 20 |
| 11-14 | 25 |
| 15-18 | 35 |
| 19-22 | 50 |
| 23+ | 75 |

### Multiplicateur de distance

| Distance | Multiplicateur |
|:---:|:---:|
| D1 | x 1.0 |
| D2 | x 1.5 |
| D3 | x 2.0 |

### Bonus de temps

| Temps utilise | Multiplicateur | Label |
|:---:|:---:|:---|
| ≤ 25% | x 1.50 | Turbo |
| ≤ 50% | x 1.25 | Rapide |
| ≤ 75% | x 1.00 | Normal |
| > 75% | x 0.75 | Lent |

### Bonus speciaux

| Bonus | Condition |
|:---|:---|
| STREAK | 3 bonnes reponses consecutives |
| MEGA_STREAK | 7 bonnes reponses consecutives |
| PERFECT | Niveau termine sans aucune faute |
| TURBO | Reponse en moins de 25% du temps |
| SPEED_RUN | 5 questions repondues en moins de 15s chacune |
| LIFESAVER | Niveau termine sans perdre de vie |
| EXPERT | Config C reussie |

### Malus

| Malus | Condition |
|:---|:---|
| TIMEOUT | Chrono a 0, pas de reponse |
| WRONG | Mauvaise reponse |
| STREAK_BREAK | Erreur apres une serie >= 3 |
| INCOHERENT | 2 erreurs sur la meme question |
| LEVEL_FAIL | Seuil non atteint en fin de niveau |
| SESSION_TIMEOUT | Session expiree (temps global) |

---

## 8. Systeme de vies

| Parametre | Valeur |
|:---|:---|
| Maximum | 5 vies |
| Depart | 5 vies |
| Recharge | +1 vie toutes les 30 minutes (pg_cron Supabase) |
| Plafond | Ne depasse jamais 5 |

### Perte de vies selon le niveau

| Niveaux | livesPerWrong | Signification |
|:---:|:---:|:---|
| 1-6 | 3 | 1 vie perdue toutes les 3 erreurs (tolerant) |
| 7-14 | 2 | 1 vie perdue toutes les 2 erreurs (modere) |
| 15+ | 1 | 1 vie perdue a chaque erreur (strict) |

### Comportement a 0 vies

La partie se termine **immediatement**. Le joueur est redirige vers la page de resultats.

---

## 9. Tracking des noeuds joues

### Stockage

En memoire Flutter : `Set<String>` mutable.

### Format des cles

| Distance | Format de la cle | Exemple |
|:---:|:---|:---|
| D1 | `"N{index}"` | `"N01"` |
| D2 | `"N{parent}-N{enfant}"` | `"N01-N16"` |
| D3 | `"N{gp}-N{parent}-N{enfant}"` | `"N01-N16-N36"` |

### Regle importante

Les cles sont **independantes** entre les distances :
- Jouer `"N01"` en D1 **n'empeche pas** de jouer `"N01-N16"` en D2
- Ce sont des experiences de jeu differentes
- Les memes noeuds peuvent apparaitre dans des combinaisons differentes

### Exemple de session

```
Q1 → tracking : "N03"              (D1, noeud seul)
Q2 → tracking : "N07"              (D1, noeud seul)
Q3 → tracking : "N01-N16"          (D2, paire)
Q4 → tracking : "N02-N18"          (D2, paire)
Q5 → tracking : "N04-N20"          (D2, paire)
Q6 → tracking : "N01-N16-N36"      (D3, chaine de 3)
...
```

### Epuisement

Si tous les noeuds/paires/chaines d'une distance sont epuises,
la generation retourne `null` et la session se termine.

### Reset

Le tracking est remis a zero a chaque nouvelle session de jeu.

---

## 10. Progression des niveaux

| Niveau | Distance | Configs | Questions | Seuil | Vies/Erreur | Temps (s) | Points |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1-3 | D1 | A | 8 | 6/8 | 3 err = -1 vie | 30 | 10 |
| 4-6 | D1 | A+B | 10 | 7/10 | 3 err = -1 vie | 35 | 15 |
| 7-10 | D2 | A+B | 10 | 7/10 | 2 err = -1 vie | 40 | 20 |
| 11-14 | D2 | B | 10 | 7/10 | 2 err = -1 vie | 45 | 25 |
| 15-18 | D3 | B+C | 12 | 8/12 | 2 err = -1 vie | 50 | 35 |
| 19-22 | D3 | C | 12 | 9/12 | 1 err = -1 vie | 55 | 50 |
| 23+ | D3 | A+B+C | 15 | 11/15 | 1 err = -1 vie | 45 | 75 |

### Lecture d'une ligne

**Niveau 7** : distance 2, config A ou B (aleatoire), 10 questions par session,
seuil de reussite 7/10, perd 1 vie toutes les 2 erreurs, 40 secondes par question, 20 points de base.

### Etoiles

| Etoiles | Condition |
|:---:|:---|
| ★★★ | 100% de bonnes reponses |
| ★★ | >= 80% de bonnes reponses |
| ★ | >= seuil de reussite |
| — | Niveau echoue (sous le seuil) |

---

## 11. Architecture Backend / Local

### Principe fondamental

```
BACKEND (Supabase)                    FLUTTER (Local)
═══════════════════                   ════════════════════════════
Stocke les donnees brutes             Gere TOUTE la logique de jeu
  • Table cards (61 images)             • Construction du graphe
  • Table nodes (50 trios + liens)      • Resolution des emettrices
                                        • Generation des questions
Sync UNE SEULE FOIS                    • Generation des distracteurs
au lancement du jeu                     • Tracking des noeuds joues
                                        • Verification des reponses
                                        • Scoring
                                        • ZERO requete pendant le jeu
```

### Table `cards`

```sql
cards (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label       TEXT NOT NULL,
  image_path  TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
)
```

Pas de type fixe. Une carte = juste une image avec un label.

### Table `nodes`

```sql
nodes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  node_index      INT UNIQUE NOT NULL,
  emettrice_id    UUID REFERENCES cards(id),     -- NULL si enfant
  cable_id        UUID NOT NULL REFERENCES cards(id),
  receptrice_id   UUID NOT NULL REFERENCES cards(id),
  parent_node_id  UUID REFERENCES nodes(id) ON DELETE CASCADE,
  depth           INT NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(emettrice_id, cable_id, receptrice_id),
  CHECK (depth BETWEEN 1 AND 3),
  CHECK (
    (depth = 1 AND parent_node_id IS NULL AND emettrice_id IS NOT NULL)
    OR
    (depth > 1 AND parent_node_id IS NOT NULL)
  )
)
```

### Securite (RLS)

| Operation | Qui peut | Comment |
|:---|:---|:---|
| Lecture (SELECT) | Tous les utilisateurs authentifies | Politique RLS `USING (true)` |
| Ecriture (INSERT, UPDATE, DELETE) | admin@trialgo.com uniquement | Verification `auth.jwt() ->> 'email'` |

### Flow de synchronisation

```
1. App lance
2. Supabase SDK initialisee
3. Telecharger TOUTES les cartes (SELECT * FROM cards)
4. Telecharger TOUS les noeuds (SELECT * FROM nodes ORDER BY node_index)
5. Construire le graphe en memoire :
   a. Indexer les noeuds par node_index
   b. Pour chaque enfant : enfant.E = parent.R
   c. Regrouper par profondeur
   d. Construire les listes d'enfants
6. Le jeu est pret — plus aucune requete backend
```

### Structure du graphe en memoire

```
GameGraph {
  nodesByIndex : Map<int, Node>       → acces O(1) par index
  nodesByDepth : Map<int, List<Node>> → noeuds par profondeur
  childrenOf   : Map<int, List<Node>> → enfants de chaque noeud
  getChain(index) → [grandparent, parent, enfant]
}

cards : Map<String, Card>             → catalogue complet par UUID
```

---

## 12. Interface Admin

### Acces

- Reservee a `admin@trialgo.com`
- Bouton discret en bas de la page d'accueil
- Verification client (UX) + verification serveur (RLS)

### Onglet Cartes

| Action | Detail |
|:---|:---|
| Voir | Grille de toutes les images avec label |
| Ajouter | Formulaire : label + chemin image dans Storage |
| Supprimer | Possible seulement si la carte n'est pas utilisee dans un noeud |

### Onglet Graphe

| Action | Detail |
|:---|:---|
| Voir | Noeuds groupes par profondeur (P1 vert, P2 bleu, P3 orange) |
| Ajouter racine | Formulaire : index + E + C + R |
| Ajouter enfant | Formulaire : index + parent + C + R (E deduit automatiquement) |
| Supprimer | Cascade : les enfants sont aussi supprimes |

### Workflow d'ajout

```
NOEUD RACINE (profondeur 1) :
  L'admin saisit    : index + E + C + R     → 4 champs
  Le systeme ecrit  : emettrice_id = E, cable_id = C, receptrice_id = R, depth = 1

NOEUD ENFANT (profondeur 2 ou 3) :
  L'admin saisit    : index + parent + C + R   → 4 champs
  Le systeme ecrit  : emettrice_id = NULL, cable_id = C, receptrice_id = R,
                      parent_node_id = parent.id, depth = parent.depth + 1
  Flutter resout    : enfant.E = parent.R (lors de la construction du graphe)
```

---

## 13. Architecture fichiers

```
lib/
├── core/
│   ├── constants/
│   │   ├── game_constants.dart          ← parametres de gameplay par niveau
│   │   ├── admin_constants.dart         ← detection admin@trialgo.com
│   │   └── storage_constants.dart       ← URLs Supabase Storage
│   └── network/
│       └── supabase_client.dart         ← client Supabase singleton
│
├── domain/
│   ├── entities/
│   │   ├── graph_card_entity.dart       ← carte neutre (id, label, imagePath)
│   │   ├── graph_node_entity.dart       ← noeud avec resolveEmettrice()
│   │   └── game_question_entity.dart    ← question de jeu
│   ├── repositories/
│   │   └── graph_repository.dart        ← interface (contrat)
│   └── usecases/
│       ├── build_graph_usecase.dart      ← construction graphe + GameGraph
│       └── generate_game_question_usecase.dart ← D1/D2/D3 + distracteurs + tracking
│
├── data/
│   ├── models/
│   │   ├── graph_card_model.dart        ← fromJson / toJson
│   │   └── graph_node_model.dart        ← fromJson / toJson
│   ├── repositories/
│   │   └── graph_repository_impl.dart   ← implementation Supabase
│   └── services/
│       └── graph_sync_service.dart      ← sync + build orchestration
│
└── presentation/
    └── wireframes/
        ├── t_home_page.dart             ← bouton admin conditionnel
        ├── t_admin_page.dart            ← interface admin (cartes + graphe)
        ├── t_game_page.dart             ← ecran de jeu
        ├── t_level_map_page.dart        ← carte des niveaux
        └── t_game_result_page.dart      ← resultats fin de partie

supabase/
└── migrations/
    ├── 001_create_graph_tables.sql      ← tables cards + nodes + RLS
    └── 002_create_admin_account.sql     ← instructions compte admin
```

---

> **Document genere le 8 avril 2026**
> Derniere mise a jour : correction du nombre de choix (1 bonne + 5 distracteurs = 6 cartes)
