# TRIALGO v3.1 — Diagramme de Classes des Entités

> Les éléments marqués **[NEW]** comblent les écarts wireframes ↔ backend.

---

## Vue globale des relations

```text
╔══════════════════╗
║  <<enumeration>> ║
║    CardType      ║
╠══════════════════╣
║ emettrice        ║
║ cable            ║
║ receptrice       ║
╚════════╤═════════╝
         │ cardType
         │
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
╚══════════════════════╤════════════════════════╝
                       │
                       │ trioId
                       │
╔══════════════════════▼════════════════════════╗
║            GameQuestionEntity                 ║
╠═══════════════════════════════════════════════╣
║ + visibleCards     : List<CardEntity>   {2}   ║
║ + maskedCard       : CardEntity         {1}   ║
║ + choices          : List<CardEntity>   {10}  ║
║ + config           : String  {"A"|"B"|"C"}   ║
║ + correctCardId    : String                   ║
║ + trioId           : String ──► CardTrioEntity║
║ + timeLimitSeconds : int                      ║
╚═══════════════════════════════════════════════╝


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
╚═══╤═══════════╤═══════════╤═══════════╤══════╝
    │           │           │           │
    │ 0..*      │ 0..*      │ 0..*      │ 0..1
    │           │           │           │
╔═══▼═══════════▼═══╗ ╔═════▼═══════╗ ╔═▼══════════════════════════════════╗
║ GameSessionEntity ║ ║ UserLevel   ║ ║ ActivationCodeEntity    ★ [NEW]   ║
║          ★ [NEW]  ║ ║ Progress    ║ ╠════════════════════════════════════╣
╠═══════════════════╣ ║ Entity      ║ ║ + id           : String            ║
║ + id              ║ ║    ★ [NEW]  ║ ║ + codeValue    : String            ║
║ + userId          ║ ╠═════════════╣ ║ + isActivated  : bool = false      ║
║ + levelNumber     ║ ║ + id        ║ ║ + deviceId     : String?           ║
║ + score           ║ ║ + userId    ║ ║ + userId       : String?           ║
║ + correctAnswers  ║ ║ + levelNum  ║ ║ + activatedAt  : DateTime?         ║
║ + wrongAnswers    ║ ║ + stars     ║ ╚════════════════════════════════════╝
║ + bonusEarned     ║ ║   {0..3}   ║
║ + malusReceived   ║ ║ + bestScore ║    ╔════════════════════════════════╗
║ + durationSeconds ║ ║ + completed ║    ║ UnlockedCardEntity   ★ [NEW]  ║
║ + completed       ║ ║ + completed ║    ╠════════════════════════════════╣
║ + passed ★[NEW]   ║ ║   At       ║    ║ + id          : String         ║
║ + totalQuestions  ║ ╚═════════════╝    ║ + userId      : String ─►User ║
║          ★[NEW]   ║                    ║ + cardId      : String ─►Card ║
║ + maxStreak       ║                    ║ + unlockedAt  : DateTime       ║
║          ★[NEW]   ║                    ║ + unlockCount : int = 1        ║
║ + startedAt       ║                    ╚════════════════════════════════╝
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
┌─────────────────────────────────────────────────────────────────────┐
│                       ASSOCIATIONS                                  │
├────────────────────────┬──────────┬─────────────────────────────────┤
│ Source                 │ Cardina. │ Cible                           │
├────────────────────────┼──────────┼─────────────────────────────────┤
│ CardEntity             │    ◆──►  │ CardType (composition)          │
│ CardEntity             │  0..1    │ CardEntity (parentEmettriceId)  │
│ CardEntity             │  0..1    │ CardEntity (parentCableId)      │
│ CardEntity             │  0..1    │ CardEntity (rootEmettriceId)    │
├────────────────────────┼──────────┼─────────────────────────────────┤
│ CardTrioEntity         │  1 ──► 1 │ CardEntity (emettriceId)        │
│ CardTrioEntity         │  1 ──► 1 │ CardEntity (cableId)            │
│ CardTrioEntity         │  1 ──► 1 │ CardEntity (receptriceId)       │
│ CardTrioEntity         │  0..1    │ CardTrioEntity (parentTrioId)   │
├────────────────────────┼──────────┼─────────────────────────────────┤
│ GameQuestionEntity     │  1 ──► 2 │ CardEntity (visibleCards)       │
│ GameQuestionEntity     │  1 ──► 1 │ CardEntity (maskedCard)         │
│ GameQuestionEntity     │  1 ──►10 │ CardEntity (choices)            │
│ GameQuestionEntity     │  1 ──► 1 │ CardTrioEntity (trioId)         │
├────────────────────────┼──────────┼─────────────────────────────────┤
│ GameSessionEntity      │  * ──► 1 │ UserEntity (userId)             │
│ UserLevelProgressEntity│  * ──► 1 │ UserEntity (userId)             │
│ ActivationCodeEntity   │  1 ──► 1 │ UserEntity (userId)             │
├────────────────────────┼──────────┼─────────────────────────────────┤
│ UnlockedCardEntity     │  * ──► 1 │ UserEntity (userId)             │
│ UnlockedCardEntity     │  * ──► 1 │ CardEntity (cardId)             │
└────────────────────────┴──────────┴─────────────────────────────────┘
```

---

## Corrections appliquées

```text
┌────┬───────────────────────────────────┬──────────────────────────────┐
│ #  │ Correction                        │ Entité                       │
├────┼───────────────────────────────────┼──────────────────────────────┤
│  1 │ Ajout champ label : String        │ CardEntity                   │
│  2 │ Création entité complète          │ GameSessionEntity            │
│  3 │ Ajout passed, totalQuestions,     │ GameSessionEntity            │
│    │ maxStreak                         │                              │
│  4 │ Création entité                   │ UserLevelProgressEntity      │
│  5 │ Création entité                   │ ActivationCodeEntity         │
│  6 │ Création entité                   │ UnlockedCardEntity           │
└────┴───────────────────────────────────┴──────────────────────────────┘

★ [NEW] = élément ajouté pour combler un écart wireframe ↔ backend
```
