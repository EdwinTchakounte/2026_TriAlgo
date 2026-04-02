# TRIALGO v3.2 — Diagramme de Classes des Entités

> Version 3.2 : ajout du concept de **Deck** (jeu de cartes physique)
> et distinction **mode individuel** vs **mode collectif**.
> Les éléments marqués **★ [NEW]** sont des ajouts par rapport au code existant.

---

## Les 2 modes de jeu

```text
  ┌─────────────────────────────────────┬─────────────────────────────────────┐
  │         MODE INDIVIDUEL             │          MODE COLLECTIF             │
  ├─────────────────────────────────────┼─────────────────────────────────────┤
  │ L'appli GÉNÈRE la question          │ Le joueur SCANNE 3 cartes           │
  │                                     │ physiques (QR codes)                │
  │ 1. Tire 1 trio du deck              │                                     │
  │ 2. Montre 2 cartes                  │ 1. Scan QR → carte 1               │
  │ 3. Cache 1 carte                    │ 2. Scan QR → carte 2               │
  │ 4. Génère 9 distracteurs du deck    │ 3. Scan QR → carte 3               │
  │ 5. Joueur choisit parmi 10          │ 4. Vérifie E + C = R dans le deck  │
  │                                     │                                     │
  │ Entités :                           │ Entités :                           │
  │   GameQuestionEntity                │   ScanValidationEntity ★ [NEW]     │
  │   GameSessionEntity                 │   CollectiveSessionEntity ★ [NEW]  │
  │                                     │                                     │
  │ Requêtes :                          │ Requête :                           │
  │   getRandomTrio(deckId)             │   isCoherent(e, c, r, deckId)      │
  │   getDistractors(deckId)            │   (1 seule requête)                │
  └─────────────────────────────────────┴─────────────────────────────────────┘
```

---

## Vue globale des relations

```text
╔══════════════════════════════════════════════╗
║          CardDeckEntity          ★ [NEW]     ║
║          (1 boîte physique = 1 deck)         ║
╠══════════════════════════════════════════════╣
║ + id          : String                       ║
║ + name        : String                       ║
║ + description : String?                      ║
║ + cardCount   : int = 50                     ║
║ + isActive    : bool = true                  ║
╚══════╤═══════╤════════╤══════════╤═══════════╝
       │       │        │          │
       │       │        │          │ deckId (FK)
       │       │        │          │
       │       │        │    ╔═════▼════════════════════════════════╗
       │       │        │    ║       ActivationCodeEntity ★ [NEW]  ║
       │       │        │    ╠═════════════════════════════════════╣
       │       │        │    ║ + id          : String               ║
       │       │        │    ║ + codeValue   : String               ║
       │       │        │    ║ + deckId      : String  ★ [NEW]     ║
       │       │        │    ║ + isActivated : bool = false         ║
       │       │        │    ║ + deviceId    : String?              ║
       │       │        │    ║ + userId      : String?              ║
       │       │        │    ║ + activatedAt : DateTime?            ║
       │       │        │    ╚═════════════════════════════════════╝
       │       │        │
       │deckId │deckId  │deckId
       │       │        │
╔══════▼═══════╤════════╤═══════════════════════╗
║  <<enum>>    │        │                       ║
║  CardType    │        │                       ║
╠══════════════╝        │                       ║
║ emettrice             │                       ║
║ cable                 │                       ║
║ receptrice            │                       ║
╚════════╤══════════════╝                       ║
         │ cardType                              ║
╔════════▼══════════════════════════════════════╗
║                  CardEntity                   ║
╠═══════════════════════════════════════════════╣
║ + id              : String                    ║
║ + cardType        : CardType                  ║
║ + distanceLevel   : int {1..3}                ║
║ + imagePath       : String                    ║
║ + imageWidth      : int?                      ║
║ + imageHeight     : int?                      ║
║ + imageFormat     : String = "webp"           ║
║ + cableCategory   : String?                   ║
║ + themeTags       : List<String>              ║
║ + parentEmettriceId : String?        ──┐      ║
║ + parentCableId     : String?        ──┤ self ║
║ + rootEmettriceId   : String?        ──┘ ref  ║
║ + difficultyScore : double = 0.5              ║
║ + isActive        : bool = true               ║
║ + label           : String          ★ [NEW]   ║
║ + deckId          : String          ★ [NEW]   ║
║ + qrCode          : String?        ★ [NEW]   ║
╠═══════════════════════════════════════════════╣
║ «get» imageUrl        : String                ║
║ «get» isRootEmettrice : bool                  ║
║ «get» isCable         : bool                  ║
║ «get» isReceptrice    : bool                  ║
╚══════╤═══════╤════════╤═══════════════════════╝
       │       │        │
       │1      │1       │1
       │       │        │
╔══════▼═══════▼════════▼═══════════════════════╗
║              CardTrioEntity                   ║
╠═══════════════════════════════════════════════╣
║ + id             : String                     ║
║ + emettriceId    : String  ───► CardEntity(E) ║
║ + cableId        : String  ───► CardEntity(C) ║
║ + receptriceId   : String  ───► CardEntity(R) ║
║ + distanceLevel  : int {1..3}                 ║
║ + parentTrioId   : String? ───► self (chaîne) ║
║ + difficulty     : double = 0.5               ║
║ + deckId         : String          ★ [NEW]   ║
╚══════════════════════╤════════════════════════╝
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
  MODE INDIVIDUEL    MODE COLLECTIF   COMMUN
        │              │              │
╔═══════▼══════════╗ ╔═▼═════════════════════════════════╗
║ GameQuestion     ║ ║ ScanValidationEntity    ★ [NEW]  ║
║ Entity           ║ ╠══════════════════════════════════╣
╠══════════════════╣ ║ + scannedCardIds : List<String>  ║
║ + visibleCards   ║ ║   {3}                            ║
║   List<Card> {2} ║ ║ + emettriceId   : String?       ║
║ + maskedCard     ║ ║ + cableId       : String?        ║
║   CardEntity {1} ║ ║ + receptriceId  : String?        ║
║ + choices        ║ ║ + isValid       : bool           ║
║   List<Card>{10} ║ ║ + matchedTrioId : String?        ║
║ + config         ║ ║ + deckId        : String         ║
║   {"A"|"B"|"C"}  ║ ╚══════════════════════════════════╝
║ + correctCardId  ║
║ + trioId         ║
║ + timeLimitSec.  ║
╚══════════════════╝


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
║ + activeDeckId     : String?       ★ [NEW]  ║
╚═══╤═══════════╤═══════════╤═══════════╤══════╝
    │           │           │           │
    │ 0..*      │ 0..*      │ 0..*      │ 0..*
    │           │           │           │
╔═══▼═══════════▼═══╗ ╔═════▼═══════╗ ╔═▼══════════════════════════════════╗
║ GameSessionEntity ║ ║ UserLevel   ║ ║ UnlockedCardEntity     ★ [NEW]   ║
║          ★ [NEW]  ║ ║ Progress    ║ ╠════════════════════════════════════╣
╠═══════════════════╣ ║ Entity      ║ ║ + id          : String             ║
║ + id              ║ ║    ★ [NEW]  ║ ║ + userId      : String ──► User   ║
║ + userId          ║ ╠═════════════╣ ║ + cardId      : String ──► Card   ║
║ + deckId ★ [NEW]  ║ ║ + id        ║ ║ + unlockedAt  : DateTime          ║
║ + levelNumber     ║ ║ + userId    ║ ║ + unlockCount : int = 1           ║
║ + gameMode ★[NEW] ║ ║ + levelNum  ║ ╚════════════════════════════════════╝
║   {"solo"|"coop"} ║ ║ + stars     ║
║ + score           ║ ║   {0..3}   ║
║ + correctAnswers  ║ ║ + bestScore ║
║ + wrongAnswers    ║ ║ + completed ║
║ + bonusEarned     ║ ║ + completed ║
║ + malusReceived   ║ ║   At       ║
║ + durationSeconds ║ ╚═════════════╝
║ + completed       ║
║ + passed ★[NEW]   ║
║ + totalQuestions  ║
║          ★[NEW]   ║
║ + maxStreak       ║
║          ★[NEW]   ║
║ + startedAt       ║
║ + endedAt         ║
╚═══════════════════╝


╔═══════════════════════════════════════════════╗
║           LevelConfig  «core»                 ║
╠═══════════════════════════════════════════════╣
║ + distance        : int                       ║
║ + configs         : List<String>              ║
║ + questions       : int                       ║
║ + threshold       : int                       ║
║ + livesPerWrong   : int                       ║
║ + turnTimeSeconds : int                       ║
║ + basePoints      : int                       ║
╚═══════════════════════════════════════════════╝
```

---

## Détail des relations

```text
┌──────────────────────────┬──────────┬─────────────────────────────────────┐
│ Source                   │ Cardina. │ Cible                               │
├──────────────────────────┼──────────┼─────────────────────────────────────┤
│ CardDeckEntity           │  1 ──► * │ CardEntity (deckId)                 │
│ CardDeckEntity           │  1 ──► * │ CardTrioEntity (deckId)             │
│ CardDeckEntity           │  1 ──► * │ ActivationCodeEntity (deckId)       │
│ CardDeckEntity           │  1 ──► * │ GameSessionEntity (deckId)          │
├──────────────────────────┼──────────┼─────────────────────────────────────┤
│ CardEntity               │    ◆──►  │ CardType (composition)              │
│ CardEntity               │  * ──► 1 │ CardDeckEntity (deckId)             │
│ CardEntity               │  0..1    │ CardEntity (parentEmettriceId)      │
│ CardEntity               │  0..1    │ CardEntity (parentCableId)          │
│ CardEntity               │  0..1    │ CardEntity (rootEmettriceId)        │
├──────────────────────────┼──────────┼─────────────────────────────────────┤
│ CardTrioEntity           │  1 ──► 1 │ CardEntity (emettriceId)            │
│ CardTrioEntity           │  1 ──► 1 │ CardEntity (cableId)               │
│ CardTrioEntity           │  1 ──► 1 │ CardEntity (receptriceId)          │
│ CardTrioEntity           │  * ──► 1 │ CardDeckEntity (deckId)            │
│ CardTrioEntity           │  0..1    │ CardTrioEntity (parentTrioId)      │
├──────────────────────────┼──────────┼─────────────────────────────────────┤
│ GameQuestionEntity       │  1 ──► 2 │ CardEntity (visibleCards)          │
│ GameQuestionEntity       │  1 ──► 1 │ CardEntity (maskedCard)            │
│ GameQuestionEntity       │  1 ──►10 │ CardEntity (choices)               │
│ GameQuestionEntity       │  1 ──► 1 │ CardTrioEntity (trioId)            │
├──────────────────────────┼──────────┼─────────────────────────────────────┤
│ ScanValidationEntity     │  1 ──► 3 │ CardEntity (scannedCardIds)        │
│ ScanValidationEntity     │  0..1    │ CardTrioEntity (matchedTrioId)     │
│ ScanValidationEntity     │  1 ──► 1 │ CardDeckEntity (deckId)            │
├──────────────────────────┼──────────┼─────────────────────────────────────┤
│ UserEntity               │  0..1    │ CardDeckEntity (activeDeckId)      │
│ GameSessionEntity        │  * ──► 1 │ UserEntity (userId)                │
│ GameSessionEntity        │  * ──► 1 │ CardDeckEntity (deckId)            │
│ UserLevelProgressEntity  │  * ──► 1 │ UserEntity (userId)                │
│ ActivationCodeEntity     │  1 ──► 1 │ CardDeckEntity (deckId)            │
│ ActivationCodeEntity     │  0..1    │ UserEntity (userId)                │
│ UnlockedCardEntity       │  * ──► 1 │ UserEntity (userId)                │
│ UnlockedCardEntity       │  * ──► 1 │ CardEntity (cardId)                │
└──────────────────────────┴──────────┴─────────────────────────────────────┘
```

---

## Flux du deck : de la boîte au jeu

```text
  ┌─────────────────────────────────────────────────────────────────────────┐
  │  1. L'administrateur crée un deck et y associe 50 cartes              │
  │                                                                        │
  │     INSERT INTO card_decks (id, name) VALUES ('deck-savane', 'Savane')│
  │     INSERT INTO cards (..., deck_id) VALUES (..., 'deck-savane') ×50  │
  │     INSERT INTO card_trios (..., deck_id) VALUES (..., 'deck-savane') │
  │     INSERT INTO activation_codes (code_value, deck_id)                │
  │       VALUES ('ABCD-1234-EFGH-5678', 'deck-savane')                   │
  │                                                                        │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  2. Le joueur achète la boîte et active le code                       │
  │                                                                        │
  │     Joueur tape : ABCD-1234-EFGH-5678                                 │
  │     → activation_codes.deck_id = 'deck-savane'                        │
  │     → user_profiles.active_deck_id = 'deck-savane'                    │
  │                                                                        │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  3. MODE INDIVIDUEL — le joueur lance une partie                      │
  │                                                                        │
  │     deckId = user.activeDeckId = 'deck-savane'                        │
  │     getRandomTrio(distance, deckId)     → trio du deck Savane         │
  │     getDistractors(maskedCard, deckId)  → cartes du deck Savane       │
  │     Le joueur ne voit QUE des cartes de sa boîte.                     │
  │                                                                        │
  ├─────────────────────────────────────────────────────────────────────────┤
  │  4. MODE COLLECTIF — le joueur scanne 3 cartes physiques             │
  │                                                                        │
  │     Scan QR carte 1 → id = 'E1' (Lion)                               │
  │     Scan QR carte 2 → id = 'C1' (Miroir)                             │
  │     Scan QR carte 3 → id = 'R1' (Lion Miroir)                        │
  │                                                                        │
  │     Vérification :                                                     │
  │       a) Les 3 cartes sont-elles du même deck ?                       │
  │          E1.deckId == C1.deckId == R1.deckId ? → OUI                  │
  │       b) Ce trio existe-t-il ?                                         │
  │          isCoherent(E1, C1, R1) → OUI                                 │
  │       → VALIDE ✓                                                       │
  │                                                                        │
  │     Si le joueur mélange des cartes de 2 boîtes différentes :         │
  │       E1.deckId = 'deck-savane'                                       │
  │       C3.deckId = 'deck-ocean'                                        │
  │       → deck différent → INVALIDE ✗ (même si le trio existe)          │
  │                                                                        │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## Mode collectif : ScanValidationEntity en détail

```text
  Le joueur scanne 3 QR codes successivement.
  Chaque QR code contient l'ID de la carte physique.

  ╔══════════════════════════════════════════════════════════╗
  ║              ScanValidationEntity        ★ [NEW]        ║
  ╠══════════════════════════════════════════════════════════╣
  ║ + scannedCardIds  : List<String> {3}                    ║
  ║     les 3 IDs des cartes scannées                       ║
  ║                                                         ║
  ║ + emettriceId     : String?                             ║
  ║ + cableId         : String?                             ║
  ║ + receptriceId    : String?                             ║
  ║     les 3 IDs triés par rôle (E, C, R)                 ║
  ║     null si pas encore identifiés                       ║
  ║                                                         ║
  ║ + isValid         : bool                                ║
  ║     true si les 3 forment un trio valide                ║
  ║                                                         ║
  ║ + matchedTrioId   : String?                             ║
  ║     l'ID du trio dans card_trios (si valide)            ║
  ║                                                         ║
  ║ + deckId          : String                              ║
  ║     le deck du joueur (pour vérifier la cohérence)      ║
  ╚══════════════════════════════════════════════════════════╝

  Flux de validation :

    1. Joueur scanne 3 cartes → on a 3 IDs
    2. On charge les 3 cartes depuis cards
    3. On vérifie qu'elles sont du même deck
    4. On identifie les rôles par card_type :
         - celle de type 'emettrice' → E
         - celle de type 'cable' → C
         - celle de type 'receptrice' → R
    5. On appelle isCoherent(E, C, R)
    6. Si oui → isValid = true, matchedTrioId = l'ID du trio

  Cas spécial D2/D3 :
    2 cartes sont de type 'receptrice' et 1 de type 'cable'
    → il faut tester les 2 combinaisons possibles :
       isCoherent(R1, C2, R2) ou isCoherent(R2, C2, R1)
    → celle qui match = le bon trio
```

---

## Corrections appliquées (v3.1 → v3.2)

```text
┌────┬──────────────────────────────────────────────┬──────────────────────────────┐
│ #  │ Correction                                   │ Entité                       │
├────┼──────────────────────────────────────────────┼──────────────────────────────┤
│  1 │ Ajout champ label : String                   │ CardEntity                   │
│  2 │ Création entité complète                     │ GameSessionEntity            │
│  3 │ Ajout passed, totalQuestions, maxStreak       │ GameSessionEntity            │
│  4 │ Création entité                              │ UserLevelProgressEntity      │
│  5 │ Création entité                              │ ActivationCodeEntity         │
│  6 │ Création entité                              │ UnlockedCardEntity           │
├────┼──────────────────────────────────────────────┼──────────────────────────────┤
│  7 │ Création entité (boîte physique)             │ CardDeckEntity               │
│  8 │ Ajout deckId + qrCode dans les cartes        │ CardEntity                   │
│  9 │ Ajout deckId dans les trios                  │ CardTrioEntity               │
│ 10 │ Ajout deckId dans les codes d'activation     │ ActivationCodeEntity         │
│ 11 │ Ajout activeDeckId dans le profil joueur     │ UserEntity                   │
│ 12 │ Ajout deckId + gameMode dans les sessions    │ GameSessionEntity            │
│ 13 │ Création entité (scan 3 cartes physiques)    │ ScanValidationEntity         │
└────┴──────────────────────────────────────────────┴──────────────────────────────┘

★ [NEW] = élément ajouté par rapport au code existant
v3.1 → v3.2 : ajout du concept de Deck et du mode collectif
```
