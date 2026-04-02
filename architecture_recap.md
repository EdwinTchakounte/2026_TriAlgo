# TRIALGO — Récapitulatif Architectural

> Architecture du système de jeu de cartes TRIALGO.
> Dérivée du programme algorithmique originel (Programme_final_jeu_de_cartes.drawio)
> et implémentée en Flutter/Dart avec Supabase comme backend.

---

## 1. Vision globale

TRIALGO est un jeu hybride physique-numérique. Chaque boîte de jeu physique contient un ensemble de cartes illustrées et un code d'activation. L'application mobile permet deux modes de jeu autour de ces cartes.

```text
                    ┌─────────────────────────────┐
                    │     BOÎTE PHYSIQUE (Deck)    │
                    │                              │
                    │  ┌──────┐ ┌──────┐ ┌──────┐ │
                    │  │ 🦁   │ │  ↔️  │ │ 🦁↔️ │ │
                    │  │  E   │ │  C   │ │  R   │ │
                    │  └──────┘ └──────┘ └──────┘ │
                    │  ... × ~50 cartes            │
                    │                              │
                    │  Code : ABCD-1234-EFGH-5678  │
                    └──────────────┬───────────────┘
                                  │
                         joueur active le code
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │     APPLICATION MOBILE       │
                    │                              │
                    │  ┌───────────┐ ┌───────────┐ │
                    │  │   MODE    │ │   MODE    │ │
                    │  │INDIVIDUEL │ │ COLLECTIF │ │
                    │  │           │ │           │ │
                    │  │ L'appli   │ │ Scan de   │ │
                    │  │ génère    │ │ 3 cartes  │ │
                    │  │ des       │ │ physiques │ │
                    │  │ questions │ │ (QR code) │ │
                    │  └───────────┘ └───────────┘ │
                    │                              │
                    │  Filtré par le DECK activé   │
                    └─────────────────────────────┘
```

---

## 2. La formule fondamentale

Tout le jeu repose sur une seule formule :

```text
            ┌──────────┐         ┌──────────┐         ┌──────────┐
            │          │         │          │         │          │
            │  IMAGE   │  (+)    │ TRANSFOR-│  (=)    │  IMAGE   │
            │ DE BASE  │         │  MATION  │         │ RÉSULTAT │
            │          │         │          │         │          │
            └──────────┘         └──────────┘         └──────────┘
             Émettrice             Câble                Réceptrice
                E          +         C         =           R


  Exemples concrets :

  ┌──────────┐     ┌──────────┐     ┌──────────────┐
  │   🦁     │ (+) │    ↔️    │ (=) │    🦁↔️      │
  │  Lion    │     │  Miroir  │     │ Lion Miroir   │
  └──────────┘     └──────────┘     └──────────────┘

  ┌──────────┐     ┌──────────┐     ┌──────────────┐
  │   🦅     │ (+) │    🔄    │ (=) │    🦅🔄      │
  │  Aigle   │     │ Rotation │     │Aigle Rotation │
  └──────────┘     └──────────┘     └──────────────┘

  ┌──────────┐     ┌──────────┐     ┌──────────────┐
  │   🦈     │ (+) │    🔴    │ (=) │    🦈🔴      │
  │  Requin  │     │  Rouge   │     │ Requin Rouge  │
  └──────────┘     └──────────┘     └──────────────┘
```

Chaque combinaison valide (E, C, R) est un **trio**. C'est l'unité fondamentale du jeu. Les trios sont prédéfinis par l'artiste — on ne peut pas combiner librement n'importe quelle carte. `Lion + Rotation ≠ Lion Miroir`.

---

## 3. Le système de distances

Les distances créent des chaînes de transformations de complexité croissante. À chaque distance, la Réceptrice du trio précédent **devient** l'Émettrice du trio suivant.

### Distance 1 — Trio simple (3 images, 1 trio)

```text
  ┌──────┐     ┌──────┐     ┌──────┐
  │  E1  │ (+) │  C1  │ (=) │  R1  │
  │ Lion │     │Miroir│     │ Lion │
  │      │     │      │     │ Mir. │
  └──────┘     └──────┘     └──────┘

  Niveaux 1 à 6
```

### Distance 2 — Quintette (5 images, 2 trios liés)

```text
  ┌──────┐     ┌──────┐     ┌──────┐     ┌──────┐     ┌──────┐
  │  E1  │ (+) │  C1  │ (=) │  R1  │ (+) │  C2  │ (=) │  R2  │
  │ Lion │     │Miroir│     │ Lion │     │Rouge │     │ Lion │
  │      │     │      │     │ Mir. │     │      │     │M.Rge│
  └──────┘     └──────┘     └──┬───┘     └──────┘     └──────┘
                               │
                               │ R1 change de rôle :
                               │ elle ÉTAIT Réceptrice du trio D1,
                               │ elle DEVIENT Émettrice du trio D2.
                               │
                               ▼
                    Trio D1 : E1 + C1 = R1
                    Trio D2 : R1 + C2 = R2

  Niveaux 7 à 14
```

### Distance 3 — Septette (7 images, 3 trios liés)

```text
  ┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌────┐   ┌────┐
  │ E1 │(+)│ C1 │(=)│ R1 │(+)│ C2 │(=)│ R2 │(+)│ C3 │(=)│ R3 │
  │Lion│   │Mir.│   │Lion│   │Rou.│   │Lion│   │Fra.│   │Lion│
  │    │   │    │   │Mir.│   │    │   │M.Rg│   │    │   │Full│
  └────┘   └────┘   └─┬──┘   └────┘   └─┬──┘   └────┘   └────┘
                      │                  │
                      ▼                  ▼
          R1 devient E         R2 devient E
          pour trio D2         pour trio D3

  Trio D1 : E1 + C1 = R1
  Trio D2 : R1 + C2 = R2
  Trio D3 : R2 + C3 = R3

  Niveaux 15+
```

### Structure d'arbre des trios

Les trios forment un **arbre**. Chaque trio connaît son parent via `parentTrioId`. C'est le même arbre que dans le drawio originel (Tree Data Structure), stocké en base via le pattern "adjacency list".

```text
  ┌────────────────────────────────────────────────────────┐
  │  Arbre des trios dans la base :                        │
  │                                                        │
  │         T1 (D1)                    T4 (D1)             │
  │        Lion+Mir=R1               Aigle+Rot=R4          │
  │        parentTrioId=null         parentTrioId=null      │
  │       /           \                    |               │
  │      ▼             ▼                   ▼               │
  │   T2 (D2)       T3 (D2)           T5 (D2)             │
  │  R1+Rouge=R2   R1+Gris=R3       R4+Rouge=R8           │
  │  parentTrioId  parentTrioId      parentTrioId          │
  │   = T1          = T1              = T4                 │
  │      |                                                 │
  │      ▼                                                 │
  │   T6 (D3)                                              │
  │  R2+Frag=R9                                            │
  │  parentTrioId                                          │
  │   = T2                                                 │
  │                                                        │
  │  parentTrioId est une COMMODITÉ (dénormalisation).     │
  │  L'info est aussi reconstituable via emettrice_id      │
  │  qui pointe vers la receptrice_id du trio parent.      │
  └────────────────────────────────────────────────────────┘
```

---

## 4. Les 3 types de cartes en détail

```text
  ┌────────────────┬──────────────────┬──────────────────┬──────────────────┐
  │ Propriété      │ Émettrice (E)    │ Câble (C)        │ Réceptrice (R)   │
  ├────────────────┼──────────────────┼──────────────────┼──────────────────┤
  │ card_type      │ "emettrice"      │ "cable"          │ "receptrice"     │
  │                │                  │                  │                  │
  │ Rôle           │ Image de base    │ Transformation   │ Image résultat   │
  │                │ (animal, objet)  │ (miroir, couleur)│ (E transformée)  │
  │                │                  │                  │                  │
  │ cableCategory  │ null             │ "geometrique"    │ null             │
  │                │                  │ "couleur"        │                  │
  │                │                  │ "dimension"      │                  │
  │                │                  │ "complexe"       │                  │
  │                │                  │                  │                  │
  │ parentEmettri. │ null             │ null             │ ID de l'E ou R   │
  │                │ (pas de parent)  │ (pas de parent)  │ qui l'a créée    │
  │                │                  │                  │                  │
  │ parentCableId  │ null             │ null             │ ID du C utilisé  │
  │                │                  │                  │ pour la créer    │
  │                │                  │                  │                  │
  │ rootEmettri.   │ null             │ null             │ ID de l'E racine │
  │                │                  │                  │ (raccourci)      │
  └────────────────┴──────────────────┴──────────────────┴──────────────────┘

  Règle : seules les Réceptrices ont des parents.
  Les Émettrices et Câbles sont des cartes indépendantes.
```

---

## 5. Les 2 mécanismes de relation entre cartes

```text
  ╔══════════════════════════════════════════════════════════════════════╗
  ║  MÉCANISME 1 : table card_trios                                    ║
  ║  Question : "Est-ce que E + C = R ?"                               ║
  ║  Utilisé pour : JOUER (génération de questions, validation)        ║
  ║                                                                    ║
  ║  Chaque ligne = 1 combinaison valide :                             ║
  ║                                                                    ║
  ║    ┌─────┬──────────┬────────┬──────────┐                          ║
  ║    │ id  │ e_id     │ c_id   │ r_id     │                          ║
  ║    ├─────┼──────────┼────────┼──────────┤                          ║
  ║    │ T1  │ E1 (Lion)│C1 (Mir)│R1 (L.Mir)│  "Lion + Miroir         ║
  ║    │     │          │        │          │   donne Lion Miroir"     ║
  ║    └─────┴──────────┴────────┴──────────┘                          ║
  ║                                                                    ║
  ║  Si le trio existe → réponse correcte.                             ║
  ║  Si le trio n'existe pas → réponse incorrecte.                     ║
  ╠════════════════════════════════════════════════════════════════════╣
  ║  MÉCANISME 2 : auto-références dans cards                         ║
  ║  Question : "D'où vient cette image ?"                             ║
  ║  Utilisé pour : EXPLIQUER (galerie, tutoriel, chaînes)            ║
  ║                                                                    ║
  ║  Chaque Réceptrice connaît ses parents :                           ║
  ║                                                                    ║
  ║    R1.parentEmettriceId = E1    "je viens du Lion"                 ║
  ║    R1.parentCableId     = C1    "via le Miroir"                    ║
  ║    R1.rootEmettriceId   = null  "E1 est déjà la racine"           ║
  ║                                                                    ║
  ║    R2.parentEmettriceId = R1    "je viens de Lion Miroir"          ║
  ║    R2.parentCableId     = C2    "via Teinte Rouge"                 ║
  ║    R2.rootEmettriceId   = E1    "ma racine = Lion" (raccourci)     ║
  ║                                                                    ║
  ║  rootEmettriceId évite de remonter la chaîne pas à pas :           ║
  ║                                                                    ║
  ║    SANS raccourci : R3 → R2 → R1 → E1  (3 requêtes)               ║
  ║    AVEC raccourci : R3 → E1             (1 requête)                ║
  ╚════════════════════════════════════════════════════════════════════╝
```

### Schéma des relations pour la chaîne du Lion

```text
  TABLE cards (filiation — auto-références) :

    E1 (Lion)                  C1 (Miroir)    C2 (Rouge)    C3 (Frag.)
      │                           │               │              │
      │ parentEmettriceId         │ parentCableId  │              │
      ▼                           ▼               │              │
    R1 (Lion Miroir) ─────────────┘               │              │
      │                                           │              │
      │ parentEmettriceId                         │ parentCableId│
      ▼                                           ▼              │
    R2 (Lion Mir. Rouge) ─────────────────────────┘              │
      │                                                          │
      │ parentEmettriceId                         parentCableId  │
      ▼                                                          ▼
    R3 (Lion Full) ──────────────────────────────────────────────┘
      │
      │ rootEmettriceId (raccourci direct)
      ▼
    E1 (Lion) ← on saute R2 et R1


  TABLE card_trios (jeu — combinaisons valides) :

    T1 : [ E1  + C1 = R1 ]  distance 1
           │
    T2 : [ R1  + C2 = R2 ]  distance 2   (R1 joue le rôle de E)
           │
    T3 : [ R2  + C3 = R3 ]  distance 3   (R2 joue le rôle de E)
```

---

## 6. Le concept de Deck

Un Deck représente une boîte physique de jeu. Toutes les entités liées au contenu du jeu sont filtrées par `deckId`.

```text
                         ┌──────────────────────┐
                         │    CardDeckEntity     │
                         │    "Savane"           │
                         │    id = deck-savane   │
                         └──────────┬───────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ▼                     ▼                     ▼
   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │  ~50 CardEntity  │  │ CardTrioEntity   │  │ActivationCode   │
   │  deckId =        │  │ deckId =         │  │deckId =         │
   │  deck-savane     │  │ deck-savane      │  │deck-savane      │
   │                  │  │                  │  │                  │
   │  Lion, Aigle,    │  │ Lion+Mir=L.Mir   │  │ABCD-1234-EFGH   │
   │  Miroir, Rot.,   │  │ Aigle+Rot=A.Rot  │  │MNOP-5555-QRST   │
   │  Lion Mir., ...  │  │ ...              │  │...               │
   └──────────────────┘  └──────────────────┘  └──────────────────┘


  JOUEUR A active "ABCD-1234-EFGH-5678"
    → user_profiles.active_deck_id = 'deck-savane'
    → toutes les requêtes de jeu filtrent par deck_id = 'deck-savane'
    → il ne voit JAMAIS de cartes d'un autre deck


  JOUEUR B active un code du deck "Océan"
    → user_profiles.active_deck_id = 'deck-ocean'
    → il joue dans un univers de cartes complètement différent
```

---

## 7. Les entités du système

### Vue d'ensemble (13 entités)

```text
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │              CardDeckEntity                                         │
  │              (1 boîte = 1 deck)                                    │
  │                    │                                                │
  │       ┌────────────┼────────────┬──────────────┐                   │
  │       │            │            │              │                   │
  │       ▼            ▼            ▼              ▼                   │
  │  CardEntity   CardTrioEntity  Activation    GameSession            │
  │  (50 cartes)  (combinaisons)  CodeEntity    Entity                 │
  │       │            │                           │                   │
  │       │       ┌────┴────┐                      │                   │
  │       │       │         │                      │                   │
  │       │       ▼         ▼                      │                   │
  │       │  GameQuestion ScanValidation           │                   │
  │       │  Entity       Entity                   │                   │
  │       │  (solo)       (collectif)              │                   │
  │       │                                        │                   │
  │       │                UserEntity ◄────────────┘                   │
  │       │                    │                                       │
  │       │          ┌─────────┼──────────┐                            │
  │       │          │         │          │                            │
  │       │          ▼         ▼          ▼                            │
  │       │     UserLevel  Unlocked   LevelConfig                      │
  │       │     Progress   CardEntity  (core)                          │
  │       │     Entity         │                                       │
  │       │                    │                                       │
  │       └────────────────────┘                                       │
  │       (cardId → CardEntity)                                        │
  │                                                                     │
  └─────────────────────────────────────────────────────────────────────┘
```

### Détail de chaque entité

```text
  ╔═══════════════════════════════════════╗
  ║           CardDeckEntity              ║
  ╠═══════════════════════════════════════╣
  ║ + id          : String               ║
  ║ + name        : String               ║
  ║ + description : String?              ║
  ║ + cardCount   : int                  ║
  ║ + isActive    : bool                 ║
  ╚═══════════════════════════════════════╝
  1 boîte physique = 1 deck.
  Contient ~50 cartes et plusieurs
  codes d'activation.


  ╔═══════════════════════════════════════════════╗
  ║                  CardEntity                   ║
  ╠═══════════════════════════════════════════════╣
  ║ + id              : String                    ║
  ║ + cardType        : CardType                  ║
  ║ + distanceLevel   : int {1..3}                ║
  ║ + imagePath       : String                    ║
  ║ + label           : String                    ║
  ║ + deckId          : String                    ║
  ║ + qrCode          : String?                   ║
  ║ + imageWidth      : int?                      ║
  ║ + imageHeight     : int?                      ║
  ║ + imageFormat     : String                    ║
  ║ + cableCategory   : String?                   ║
  ║ + themeTags       : List<String>              ║
  ║ + parentEmettriceId : String?                 ║
  ║ + parentCableId     : String?                 ║
  ║ + rootEmettriceId   : String?                 ║
  ║ + difficultyScore : double                    ║
  ║ + isActive        : bool                      ║
  ╠═══════════════════════════════════════════════╣
  ║ «get» imageUrl        : String                ║
  ║ «get» isRootEmettrice : bool                  ║
  ║ «get» isCable         : bool                  ║
  ║ «get» isReceptrice    : bool                  ║
  ╚═══════════════════════════════════════════════╝
  1 carte = 1 image. Type : emettrice, cable
  ou receptrice. Appartient à 1 deck.
  qrCode identifie la carte physique.


  ╔═══════════════════════════════════════════════╗
  ║              CardTrioEntity                   ║
  ╠═══════════════════════════════════════════════╣
  ║ + id             : String                     ║
  ║ + emettriceId    : String  ───► CardEntity    ║
  ║ + cableId        : String  ───► CardEntity    ║
  ║ + receptriceId   : String  ───► CardEntity    ║
  ║ + distanceLevel  : int {1..3}                 ║
  ║ + parentTrioId   : String?                    ║
  ║ + difficulty     : double                     ║
  ║ + deckId         : String                     ║
  ╚═══════════════════════════════════════════════╝
  Source de vérité du jeu. Si le trio
  existe → combinaison valide.
  En D2/D3, emettriceId peut pointer vers
  une carte de type 'receptrice'.


  ╔═══════════════════════════════════════════════╗
  ║            GameQuestionEntity                 ║
  ║            (mode individuel)                  ║
  ╠═══════════════════════════════════════════════╣
  ║ + visibleCards     : List<CardEntity>   {2}   ║
  ║ + maskedCard       : CardEntity         {1}   ║
  ║ + choices          : List<CardEntity>   {10}  ║
  ║ + config           : String  {"A"|"B"|"C"}   ║
  ║ + correctCardId    : String                   ║
  ║ + trioId           : String                   ║
  ║ + timeLimitSeconds : int                      ║
  ╚═══════════════════════════════════════════════╝
  Assemblée en mémoire. Contient tout pour
  afficher 1 écran de jeu : 2 visibles,
  1 masquée, 10 choix mélangés.


  ╔═══════════════════════════════════════════════╗
  ║          ScanValidationEntity                 ║
  ║          (mode collectif)                     ║
  ╠═══════════════════════════════════════════════╣
  ║ + scannedCardIds  : List<String> {3}          ║
  ║ + emettriceId     : String?                   ║
  ║ + cableId         : String?                   ║
  ║ + receptriceId    : String?                   ║
  ║ + isValid         : bool                      ║
  ║ + matchedTrioId   : String?                   ║
  ║ + deckId          : String                    ║
  ╚═══════════════════════════════════════════════╝
  3 QR codes scannés → on vérifie si les
  3 cartes forment un trio valide dans
  le même deck.


  ╔═══════════════════════════════════════════════╗
  ║                 UserEntity                    ║
  ╠═══════════════════════════════════════════════╣
  ║ + id               : String                  ║
  ║ + username         : String                  ║
  ║ + avatarUrl        : String?                 ║
  ║ + totalScore       : int                     ║
  ║ + currentLevel     : int                     ║
  ║ + lives            : int {0..5}              ║
  ║ + livesLastRefill  : DateTime?               ║
  ║ + activeDeckId     : String?                 ║
  ╚═══════════════════════════════════════════════╝
  Lié à auth.users de Supabase.
  activeDeckId détermine le deck actif.


  ╔═══════════════════════════════════════════════╗
  ║            GameSessionEntity                  ║
  ╠═══════════════════════════════════════════════╣
  ║ + id              : String                    ║
  ║ + userId          : String                    ║
  ║ + deckId          : String                    ║
  ║ + gameMode        : GameMode {solo|coop}      ║
  ║ + levelNumber     : int                       ║
  ║ + score           : int                       ║
  ║ + correctAnswers  : int                       ║
  ║ + wrongAnswers    : int                       ║
  ║ + totalQuestions  : int                       ║
  ║ + passed          : bool                      ║
  ║ + maxStreak       : int                       ║
  ║ + bonusEarned     : int                       ║
  ║ + malusReceived   : int                       ║
  ║ + durationSeconds : int?                      ║
  ║ + completed       : bool                      ║
  ║ + startedAt       : DateTime                  ║
  ║ + endedAt         : DateTime?                 ║
  ╚═══════════════════════════════════════════════╝
  1 tentative de niveau. Enregistre le
  deck et le mode de jeu utilisés.


  ╔═══════════════════════════╗  ╔═══════════════════════════╗
  ║ UserLevelProgressEntity  ║  ║ ActivationCodeEntity      ║
  ╠═══════════════════════════╣  ╠═══════════════════════════╣
  ║ + id          : String   ║  ║ + id          : String    ║
  ║ + userId      : String   ║  ║ + codeValue   : String    ║
  ║ + levelNumber : int      ║  ║ + deckId      : String    ║
  ║ + stars       : int {0..3}║  ║ + isActivated : bool      ║
  ║ + bestScore   : int      ║  ║ + deviceId    : String?   ║
  ║ + completed   : bool     ║  ║ + userId      : String?   ║
  ║ + completedAt : DateTime?║  ║ + activatedAt : DateTime? ║
  ╚═══════════════════════════╝  ╚═══════════════════════════╝
  Étoiles et meilleur score       Code physique imprimé dans
  par niveau.                     la boîte. Lie un joueur
                                  à un deck.

  ╔═══════════════════════════╗  ╔═══════════════════════════╗
  ║ UnlockedCardEntity       ║  ║ LevelConfig  «core»       ║
  ╠═══════════════════════════╣  ╠═══════════════════════════╣
  ║ + id          : String   ║  ║ + distance       : int    ║
  ║ + userId      : String   ║  ║ + configs        : List   ║
  ║ + cardId      : String   ║  ║ + questions      : int    ║
  ║ + unlockedAt  : DateTime ║  ║ + threshold      : int    ║
  ║ + unlockCount : int      ║  ║ + livesPerWrong  : int    ║
  ╚═══════════════════════════╝  ║ + turnTimeSeconds: int    ║
  Galerie des cartes              ║ + basePoints     : int    ║
  découvertes par le joueur.     ╚═══════════════════════════╝
                                  Règles d'un niveau.
                                  Indépendant du deck.
```

---

## 8. Génération d'une question (mode individuel)

```text
  Joueur au niveau 8, deck "Savane"

  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 1 — Règles du niveau                                        │
  │                                                                     │
  │   getLevelConfig(8) → distance: 2, configs: [A,B], temps: 40s      │
  │   Opération locale, 0 requête.                                      │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 2 — Tirer 1 trio aléatoire du deck                          │
  │                                                                     │
  │   SELECT * FROM card_trios                                          │
  │   WHERE distance_level = 2                                          │
  │     AND deck_id = 'deck-savane'        ← filtré par deck            │
  │     AND id NOT IN (trios déjà posés)                                │
  │   LIMIT 10                                                          │
  │                                                                     │
  │   → choix aléatoire côté client : T9 { e:R1, c:C3, r:R9 }         │
  │   1 requête réseau.                                                 │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 3 — Charger les 3 cartes EN PARALLÈLE                       │
  │                                                                     │
  │   ┌──────────────────────────┐                                      │
  │   │ getCardById(R1)  ───┐   │                                      │
  │   │ getCardById(C3)  ───┤   │  3 requêtes simultanées              │
  │   │ getCardById(R9)  ───┘   │  (Future.wait)                       │
  │   └──────────────────────────┘                                      │
  │                                                                     │
  │   → emettrice  = R1 (Lion Miroir, type réel = receptrice)           │
  │   → cable      = C3 (Teinte Rouge)                                  │
  │   → receptrice = R9 (Lion Miroir Rouge)                             │
  │   3 requêtes en parallèle = temps d'1 seule.                        │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 4 — Choisir la configuration                                 │
  │                                                                     │
  │   configs disponibles = ['A', 'B'] → tirage aléatoire → 'B'        │
  │                                                                     │
  │   Config B :                                                        │
  │     ┌──────────────┐       ┌──────────┐       ┌──────────────┐     │
  │     │ R1           │  (+)  │   ???    │  (=)  │ R9           │     │
  │     │ Lion Miroir  │       │          │       │Lion Mir.Rouge│     │
  │     │ (visible)    │       │ (masqué) │       │ (visible)    │     │
  │     └──────────────┘       └──────────┘       └──────────────┘     │
  │                                                                     │
  │   visible = [R1, R9],  masquée = C3 (Teinte Rouge)                  │
  │   Opération locale, 0 requête.                                      │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 5 — Générer 9 distracteurs du deck                          │
  │                                                                     │
  │   Masquée = C3 (câble, catégorie "couleur")                         │
  │                                                                     │
  │   Requête 1 — même catégorie, même deck :                          │
  │     SELECT FROM cards                                               │
  │     WHERE card_type = 'cable'                                       │
  │       AND cable_category = 'couleur'                                │
  │       AND deck_id = 'deck-savane'      ← filtré par deck            │
  │       AND id != C3                                                  │
  │     LIMIT 4                                                         │
  │     → [Niv.Gris, Sépia, Inversion, T.Bleu]                         │
  │                                                                     │
  │   Requête 2 — autres catégories, même deck :                       │
  │     SELECT FROM cards                                               │
  │     WHERE card_type = 'cable'                                       │
  │       AND cable_category != 'couleur'                               │
  │       AND deck_id = 'deck-savane'      ← filtré par deck            │
  │       AND id != C3                                                  │
  │     LIMIT 5                                                         │
  │     → [Miroir V, Rot.90, Fragment, Zoom, Ombre]                     │
  │                                                                     │
  │   Total : 9 distracteurs, tous du deck Savane.                      │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 6 — Assembler et mélanger                                    │
  │                                                                     │
  │   choices = [C3, Niv.Gris, Sépia, Inversion, T.Bleu,               │
  │              Miroir V, Rot.90, Fragment, Zoom, Ombre]               │
  │                                                                     │
  │   choices.shuffle() →                                               │
  │                                                                     │
  │   ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐   │
  │   │Rot.││Niv.││Ombr││ C3 ││Frag││Sépi││Zoom││Mi.V││Inv.││T.Bl│   │
  │   │    ││Gris││    ││ ✓  ││    ││    ││    ││    ││    ││    │   │
  │   └────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘   │
  │                       ↑                                             │
  │                 bonne réponse                                       │
  │              (position aléatoire)                                   │
  │                                                                     │
  │   Opération locale, 0 requête.                                      │
  └─────────────────────────────────────────────────────────────────────┘


  BILAN : 5-6 requêtes réseau, ~250ms, tout filtré par deck.
  Le joueur ne voit QUE des cartes de sa boîte.
```

---

## 9. Sélection des distracteurs selon la config et la distance

```text
  ┌──────────┬────────────┬─────────────────────┬───────────────────────────┐
  │ Distance │ Config     │ Carte masquée       │ Distracteurs              │
  ├──────────┼────────────┼─────────────────────┼───────────────────────────┤
  │          │            │                     │                           │
  │ D1       │ A (→R)     │ Réceptrice, dist 1  │ 9 réceptrices D1 du deck  │
  │          │            │                     │                           │
  │ D1       │ B (→C)     │ Câble, dist 1       │ 4 même catégorie          │
  │          │            │                     │ + 5 autres catégories     │
  │          │            │                     │ (du deck)                 │
  │          │            │                     │                           │
  │ D1       │ C (→E)     │ Émettrice, dist 1   │ 9 émettrices D1 du deck   │
  │          │            │                     │                           │
  ├──────────┼────────────┼─────────────────────┼───────────────────────────┤
  │          │            │                     │                           │
  │ D2       │ A (→R)     │ Réceptrice, dist 2  │ 9 réceptrices D2 du deck  │
  │          │            │                     │                           │
  │ D2       │ B (→C)     │ Câble, dist 2       │ 4 même catégorie          │
  │          │            │                     │ + 5 autres (du deck)      │
  │          │            │                     │                           │
  │ D2       │ C (→"E")   │ Réceptrice, dist 1  │ 9 réceptrices D1 du deck  │
  │          │            │ (R1 joue E mais     │ (type RÉEL, pas le rôle)  │
  │          │            │  reste 'receptrice') │                           │
  │          │            │                     │                           │
  ├──────────┼────────────┼─────────────────────┼───────────────────────────┤
  │          │            │                     │                           │
  │ D3       │ A (→R)     │ Réceptrice, dist 3  │ 9 réceptrices D3 du deck  │
  │          │            │                     │                           │
  │ D3       │ B (→C)     │ Câble, dist 3       │ 4 même catégorie          │
  │          │            │                     │ + 5 autres (du deck)      │
  │          │            │                     │                           │
  │ D3       │ C (→"E")   │ Réceptrice, dist 2  │ 9 réceptrices D2 du deck  │
  │          │            │ (R2 joue E mais     │ (type RÉEL, pas le rôle)  │
  │          │            │  reste 'receptrice') │                           │
  │          │            │                     │                           │
  └──────────┴────────────┴─────────────────────┴───────────────────────────┘

  Règle d'or : les distracteurs sont choisis par le TYPE RÉEL
  et la DISTANCE RÉELLE de la carte masquée, filtrés par deck_id.
  Pas par le rôle dans le trio.
```

---

## 10. Validation de scan (mode collectif)

```text
  Le joueur et ses amis partagent les cartes physiques
  d'une même boîte sur la table.

  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 1 — Scanner 3 cartes                                        │
  │                                                                     │
  │   Scan QR 1 → id = 'E1'  (Lion)                                    │
  │   Scan QR 2 → id = 'C1'  (Miroir)                                  │
  │   Scan QR 3 → id = 'R1'  (Lion Miroir)                             │
  │                                                                     │
  │   3 × getCardById → charger les 3 cartes complètes                 │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 2 — Vérifier le deck                                        │
  │                                                                     │
  │   E1.deckId = 'deck-savane'                                         │
  │   C1.deckId = 'deck-savane'     → tous identiques → OK ✓           │
  │   R1.deckId = 'deck-savane'                                         │
  │                                                                     │
  │   Si un deckId diffère → INVALIDE (cartes de boîtes différentes)   │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 3 — Identifier les rôles                                     │
  │                                                                     │
  │   E1.cardType = 'emettrice'   → rôle E                              │
  │   C1.cardType = 'cable'       → rôle C                              │
  │   R1.cardType = 'receptrice'  → rôle R                              │
  │                                                                     │
  │   Cas D2/D3 : 2 cartes 'receptrice' + 1 'cable'                    │
  │   → tester les 2 combinaisons possibles                             │
  └──────────────────────────────┬──────────────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────────────┐
  │ ÉTAPE 4 — Vérifier le trio                                         │
  │                                                                     │
  │   SELECT id FROM card_trios                                         │
  │   WHERE emettrice_id = 'E1'                                         │
  │     AND cable_id = 'C1'                                             │
  │     AND receptrice_id = 'R1'                                        │
  │                                                                     │
  │   → 1 résultat (T1 existe) → VALIDE ✓                              │
  │   → 0 résultat             → INVALIDE ✗                            │
  └─────────────────────────────────────────────────────────────────────┘
```

---

## 11. Les 3 configurations de question

```text
  CONFIG A — Trouver la Réceptrice (facile)
  "Quel est le RÉSULTAT de cette transformation ?"

    ┌──────────┐       ┌──────────┐       ┌──────────┐
    │   🦁     │  (+)  │    ↔️    │  (=)  │   ???    │
    │  Lion    │       │  Miroir  │       │          │
    │ VISIBLE  │       │ VISIBLE  │       │  MASQUÉ  │
    └──────────┘       └──────────┘       └──────────┘
    Le joueur a les 2 indices → il imagine le résultat.


  CONFIG B — Trouver le Câble (moyen)
  "Quelle TRANSFORMATION relie ces deux images ?"

    ┌──────────┐       ┌──────────┐       ┌──────────┐
    │   🦁     │  (+)  │   ???    │  (=)  │   🦁↔️   │
    │  Lion    │       │          │       │Lion Mir. │
    │ VISIBLE  │       │  MASQUÉ  │       │ VISIBLE  │
    └──────────┘       └──────────┘       └──────────┘
    Le joueur voit l'avant/après → il identifie la transformation.


  CONFIG C — Trouver l'Émettrice (difficile)
  "Quelle est l'image DE DÉPART ?"

    ┌──────────┐       ┌──────────┐       ┌──────────┐
    │   ???    │  (+)  │    ↔️    │  (=)  │   🦁↔️   │
    │          │       │  Miroir  │       │Lion Mir. │
    │  MASQUÉ  │       │ VISIBLE  │       │ VISIBLE  │
    └──────────┘       └──────────┘       └──────────┘
    Le joueur doit raisonner "à l'envers" → inversion mentale.
```

---

## 12. Progression et scoring

```text
  ┌─────────┬──────────┬──────────┬──────────┬───────────┬─────────┬────────┐
  │ Niveaux │ Distance │ Configs  │ Questions│ Seuil     │ Temps/Q │ Points │
  ├─────────┼──────────┼──────────┼──────────┼───────────┼─────────┼────────┤
  │  1 - 3  │   D1     │    A     │    8     │  6 (75%)  │  30s    │   10   │
  │  4 - 6  │   D1     │   A+B    │   10     │  7 (70%)  │  35s    │   15   │
  │  7 - 10 │   D2     │   A+B    │   10     │  7 (70%)  │  40s    │   20   │
  │ 11 - 14 │   D2     │    B     │   10     │  7 (70%)  │  45s    │   25   │
  │ 15 - 18 │   D3     │   B+C    │   12     │  8 (67%)  │  50s    │   35   │
  │ 19 - 22 │   D3     │    C     │   12     │  9 (75%)  │  55s    │   50   │
  │   23+   │   D3     │  A+B+C   │   15     │ 11 (73%)  │  45s    │   75   │
  └─────────┴──────────┴──────────┴──────────┴───────────┴─────────┴────────┘

  Score = basePoints × distanceMultiplier × timeBonus

  ┌────────────────────────────────────────────────────────────────┐
  │  Distance Multiplier :     Time Bonus :                       │
  │    D1 → ×1.0                 < 25% du temps → ×1.5 (turbo)   │
  │    D2 → ×1.5                 25-50%         → ×1.25 (rapide) │
  │    D3 → ×2.0                 50-75%         → ×1.0 (normal)  │
  │                              > 75%          → ×0.75 (lent)   │
  ├────────────────────────────────────────────────────────────────┤
  │  Vies :                      Étoiles :                        │
  │    Maximum : 5                 ≥ 90% bonnes réponses → ★★★    │
  │    Recharge : +1 / 30 min     ≥ 70%                 → ★★     │
  │    Perte : selon livesPerWrong < 70%                 → ★      │
  └────────────────────────────────────────────────────────────────┘
```

---

## 13. Correspondance avec le programme algorithmique originel

Le drawio décrit l'algorithme en pseudocode avec un arbre en mémoire (RAM). Notre implémentation traduit la même logique en architecture persistante (SQL + Flutter).

```text
  ┌──────────────────────────────┬──────────────────────────────────────┐
  │ DRAWIO (pseudocode)          │ TRIALGO (Flutter + Supabase)        │
  ├──────────────────────────────┼──────────────────────────────────────┤
  │                              │                                      │
  │ Carte (id, image, QR_Code)  │ CardEntity                           │
  │                              │ (id, imagePath, qrCode, deckId)     │
  │                              │                                      │
  │ Noeud (3 enfants)           │ CardTrioEntity                       │
  │                              │ (emettriceId, cableId, receptriceId)│
  │                              │                                      │
  │ Game (root, graphe)         │ GameSessionNotifier                  │
  │                              │ + GenerateQuestionUseCase            │
  │                              │                                      │
  │ Tree Data Structure          │ Table card_trios avec parentTrioId   │
  │ (arbre en RAM)               │ (arbre en SQL, adjacency list)      │
  │                              │                                      │
  │ Graphe d'adjacence           │ Table card_trios                     │
  │ addEdge(a, b)                │ INSERT INTO card_trios               │
  │                              │                                      │
  │ Puzzle P[rows][cols]         │ GameQuestionEntity                   │
  │                              │ (visibleCards, maskedCard, choices)  │
  │                              │                                      │
  │ NodeOneContains(number)      │ switch(config) { A, B, C }          │
  │ carte_position (0,1,2)       │                                      │
  │                              │                                      │
  │ AddOneLinePuzzle             │ GenerateQuestionUseCase.call()       │
  │                              │                                      │
  │ alreadyAdded[]               │ excludeTrioIds                       │
  │                              │                                      │
  │ isFull()                     │ questionNumber >= totalQuestions     │
  │                              │                                      │
  │ QR_Code scan                 │ ScanValidationEntity                │
  │                              │ + ActivationCodeEntity               │
  │                              │                                      │
  │ Données perdues à la         │ Données persistantes (PostgreSQL)    │
  │ fermeture de l'app           │ Multi-joueur, synchronisation temps  │
  │                              │ réel via Supabase Realtime           │
  │                              │                                      │
  └──────────────────────────────┴──────────────────────────────────────┘
```

---

## 14. Architecture logicielle

L'application suit le pattern **Clean Architecture** avec 4 couches :

```text
  ┌─────────────────────────────────────────────────────────────────────┐
  │                                                                     │
  │  PRESENTATION                                                       │
  │  Flutter Widgets + Riverpod Providers                               │
  │                                                                     │
  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              │
  │  │  Pages   │ │ Widgets  │ │ Notifiers│ │ Stream   │              │
  │  │ AuthPage │ │ CardImage│ │ AuthNotif.│ │ Providers│              │
  │  │ GamePage │ │ LivesWdg │ │ GameSess.│ │ lives    │              │
  │  │ ...      │ │ TimerWdg │ │ QTimer   │ │          │              │
  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘              │
  │       │                          │                                  │
  ├───────┼──────────────────────────┼──────────────────────────────────┤
  │       ▼                          ▼                                  │
  │  DOMAIN                                                             │
  │  Entités + Use Cases + Interfaces                                   │
  │                                                                     │
  │  ┌──────────────┐ ┌────────────────────┐ ┌────────────────────┐    │
  │  │   Entités    │ │     Use Cases      │ │    Repositories    │    │
  │  │ CardEntity   │ │ GenerateQuestion   │ │ CardRepository     │    │
  │  │ CardTrio     │ │ ValidateTriplet    │ │ CardTrioRepository │    │
  │  │ UserEntity   │ │ ActivateCode       │ │ GameSessionRepo    │    │
  │  │ GameQuestion │ │                    │ │ (interfaces)       │    │
  │  │ ...          │ │                    │ │                    │    │
  │  └──────────────┘ └────────────────────┘ └────────────────────┘    │
  │                          │                        ▲                 │
  ├──────────────────────────┼────────────────────────┼─────────────────┤
  │                          ▼                        │                 │
  │  DATA                                             │                 │
  │  Models + Implémentations + DataSources           │                 │
  │                                                   │                 │
  │  ┌──────────────┐ ┌────────────────────┐ ┌───────┴──────────┐     │
  │  │   Models     │ │  Implementations   │ │   DataSources    │     │
  │  │ CardModel    │ │ CardRepoImpl       │ │ SupabaseAuth     │     │
  │  │  .fromJson() │ │ CardTrioRepoImpl   │ │ SupabaseCard     │     │
  │  │  .toJson()   │ │ GameSessionRepoImpl│ │                  │     │
  │  └──────────────┘ └────────────────────┘ └──────────────────┘     │
  │                          │                                          │
  ├──────────────────────────┼──────────────────────────────────────────┤
  │                          ▼                                          │
  │  CORE                                                               │
  │  Constants + Errors + Network                                       │
  │                                                                     │
  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐               │
  │  │GameConstants │ │   Failures   │ │SupabaseClient│               │
  │  │LevelConfig   │ │ AuthFailure  │ │ initSupabase │               │
  │  │StorageConst. │ │ CardFailure  │ │ supabaseUrl  │               │
  │  └──────────────┘ └──────────────┘ └──────────────┘               │
  │                                          │                          │
  └──────────────────────────────────────────┼──────────────────────────┘
                                             │
                                             ▼
                               ┌──────────────────────┐
                               │      SUPABASE         │
                               │                       │
                               │  PostgreSQL (tables)  │
                               │  Storage (images)     │
                               │  Auth (comptes)       │
                               │  Realtime (vies)      │
                               └──────────────────────┘
```

Supabase sert d'entrepôt de données. Toute l'intelligence métier réside dans le code Flutter (use cases, providers). Supabase ne fait que stocker et restituer des données via des requêtes SQL classiques.
