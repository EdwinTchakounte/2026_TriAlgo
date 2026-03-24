---
noteId: "8aa7ba20261611f1b82a415705fd6862"
tags: []

---

# CONFIGURATION SUPABASE — GUIDE PAS A PAS

> Ce guide vous accompagne pour configurer le backend Supabase
> necessaire au fonctionnement de l'application TRIALGO.
> Chaque etape est a executer dans le SQL Editor de Supabase.

---

## ETAPE 0 : Acceder au SQL Editor

1. Allez sur https://supabase.com/dashboard
2. Selectionnez votre projet (olovolsbopjporwpuphm)
3. Dans le menu de gauche, cliquez sur **SQL Editor**
4. Collez et executez chaque script ci-dessous dans l'ordre

---

## ETAPE 1 : Creer les tables

Copiez et executez CE script dans le SQL Editor :

```sql
-- =============================================================
-- SCRIPT 1 : CREATION DES TABLES
-- Projet : TRIALGO v3.0
-- Ordre : important (les references doivent exister avant)
-- =============================================================

-- ----- TABLE : cards -----
-- Stocke TOUTES les cartes du jeu (Emettrices, Cables, Receptrices)
-- Chaque carte = une image dans Supabase Storage
CREATE TABLE IF NOT EXISTS cards (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    card_type       TEXT        NOT NULL CHECK (card_type IN ('emettrice', 'cable', 'receptrice')),
    distance_level  INT         NOT NULL DEFAULT 1 CHECK (distance_level BETWEEN 1 AND 3),
    image_path      TEXT        NOT NULL,
    image_width     INT,
    image_height    INT,
    image_format    TEXT        DEFAULT 'webp',
    cable_category  TEXT,
    theme_tags      TEXT[]      DEFAULT '{}'::TEXT[],
    parent_emettrice_id UUID   REFERENCES cards(id),
    parent_cable_id     UUID   REFERENCES cards(id),
    root_emettrice_id   UUID   REFERENCES cards(id),
    difficulty_score    FLOAT  DEFAULT 0.5,
    is_active       BOOLEAN    DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ----- TABLE : card_trios -----
-- Enregistre chaque combinaison valide E + C = R
-- C'est la SOURCE DE VERITE pour la validation des reponses
CREATE TABLE IF NOT EXISTS card_trios (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    emettrice_id    UUID        NOT NULL REFERENCES cards(id),
    cable_id        UUID        NOT NULL REFERENCES cards(id),
    receptrice_id   UUID        NOT NULL REFERENCES cards(id),
    distance_level  INT         NOT NULL DEFAULT 1,
    parent_trio_id  UUID        REFERENCES card_trios(id),
    difficulty      FLOAT       DEFAULT 0.5,
    UNIQUE (emettrice_id, cable_id, receptrice_id)
);

-- ----- TABLE : user_profiles -----
-- Profil de chaque joueur (lie a auth.users)
CREATE TABLE IF NOT EXISTS user_profiles (
    id              UUID        PRIMARY KEY REFERENCES auth.users(id),
    username        TEXT        UNIQUE NOT NULL,
    avatar_url      TEXT,
    total_score     INT         DEFAULT 0,
    current_level   INT         DEFAULT 1,
    lives           INT         DEFAULT 5,
    lives_last_refill TIMESTAMPTZ DEFAULT now(),
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ----- TABLE : activation_codes -----
-- Codes physiques imprimes dans les boites de jeu
CREATE TABLE IF NOT EXISTS activation_codes (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    code_value      TEXT        UNIQUE NOT NULL,
    is_activated    BOOLEAN     DEFAULT FALSE,
    device_id       TEXT,
    user_id         UUID        REFERENCES user_profiles(id),
    activated_at    TIMESTAMPTZ
);

-- ----- TABLE : game_sessions -----
-- Chaque tentative de jouer un niveau
CREATE TABLE IF NOT EXISTS game_sessions (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        REFERENCES user_profiles(id),
    level_number    INT         NOT NULL,
    score           INT         DEFAULT 0,
    correct_answers INT         DEFAULT 0,
    wrong_answers   INT         DEFAULT 0,
    bonus_earned    INT         DEFAULT 0,
    malus_received  INT         DEFAULT 0,
    duration_seconds INT,
    completed       BOOLEAN     DEFAULT FALSE,
    started_at      TIMESTAMPTZ DEFAULT now(),
    ended_at        TIMESTAMPTZ
);

-- ----- TABLE : user_unlocked_cards -----
-- Cartes debloquees par chaque joueur (galerie)
CREATE TABLE IF NOT EXISTS user_unlocked_cards (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    card_id         UUID        NOT NULL REFERENCES cards(id),
    unlocked_at     TIMESTAMPTZ DEFAULT now(),
    unlock_count    INT         DEFAULT 1,
    UNIQUE (user_id, card_id)
);

-- ----- TABLE : broken_image_reports -----
-- Signalement d'images cassees (monitoring)
CREATE TABLE IF NOT EXISTS broken_image_reports (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id         UUID        REFERENCES cards(id),
    image_url       TEXT        NOT NULL,
    error_msg       TEXT,
    reported_by     UUID        REFERENCES user_profiles(id),
    reported_at     TIMESTAMPTZ DEFAULT now(),
    resolved        BOOLEAN     DEFAULT FALSE
);
```

---

## ETAPE 2 : Creer les index

Les index accelerent les requetes frequentes.

```sql
-- =============================================================
-- SCRIPT 2 : INDEX
-- =============================================================

-- Index sur cards
CREATE INDEX IF NOT EXISTS idx_cards_type ON cards(card_type);
CREATE INDEX IF NOT EXISTS idx_cards_distance ON cards(distance_level);
CREATE INDEX IF NOT EXISTS idx_cards_active ON cards(is_active);
CREATE INDEX IF NOT EXISTS idx_cards_parent_e ON cards(parent_emettrice_id);
CREATE INDEX IF NOT EXISTS idx_cards_parent_c ON cards(parent_cable_id);
CREATE INDEX IF NOT EXISTS idx_cards_root ON cards(root_emettrice_id);
CREATE INDEX IF NOT EXISTS idx_cards_cable_cat ON cards(cable_category);
CREATE INDEX IF NOT EXISTS idx_cards_tags ON cards USING GIN(theme_tags);

-- Index sur card_trios
CREATE INDEX IF NOT EXISTS idx_trios_emettrice ON card_trios(emettrice_id);
CREATE INDEX IF NOT EXISTS idx_trios_cable ON card_trios(cable_id);
CREATE INDEX IF NOT EXISTS idx_trios_receptrice ON card_trios(receptrice_id);
CREATE INDEX IF NOT EXISTS idx_trios_distance ON card_trios(distance_level);

-- Index sur game_sessions
CREATE INDEX IF NOT EXISTS idx_sessions_user ON game_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_completed ON game_sessions(completed);

-- Index sur user_unlocked_cards
CREATE INDEX IF NOT EXISTS idx_unlocked_user ON user_unlocked_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_unlocked_card ON user_unlocked_cards(card_id);
```

---

## ETAPE 3 : Configurer le Row Level Security (RLS)

```sql
-- =============================================================
-- SCRIPT 3 : ROW LEVEL SECURITY (RLS)
-- =============================================================

-- ===== user_profiles =====
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Un utilisateur peut lire SON profil
CREATE POLICY "user_profiles_select_own" ON user_profiles
    FOR SELECT USING (auth.uid() = id);

-- Un utilisateur peut creer SON profil
CREATE POLICY "user_profiles_insert_own" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Un utilisateur peut modifier SON profil
CREATE POLICY "user_profiles_update_own" ON user_profiles
    FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ===== game_sessions =====
ALTER TABLE game_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "game_sessions_select_own" ON game_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "game_sessions_insert_own" ON game_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "game_sessions_update_own_active" ON game_sessions
    FOR UPDATE USING (auth.uid() = user_id AND completed = FALSE);

-- ===== cards =====
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;

-- Lecture publique pour tous les utilisateurs authentifies (cartes actives)
CREATE POLICY "cards_select_authenticated" ON cards
    FOR SELECT TO authenticated
    USING (is_active = TRUE);

-- ===== card_trios =====
ALTER TABLE card_trios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "card_trios_select_authenticated" ON card_trios
    FOR SELECT TO authenticated
    USING (TRUE);

-- ===== activation_codes =====
ALTER TABLE activation_codes ENABLE ROW LEVEL SECURITY;

-- Un utilisateur peut voir SES codes actives
CREATE POLICY "activation_codes_select_own" ON activation_codes
    FOR SELECT USING (auth.uid() = user_id AND is_activated = TRUE);

-- ===== user_unlocked_cards =====
ALTER TABLE user_unlocked_cards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "unlocked_cards_own" ON user_unlocked_cards
    FOR ALL USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ===== broken_image_reports =====
ALTER TABLE broken_image_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "broken_images_insert" ON broken_image_reports
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = reported_by);
```

---

## ETAPE 4 : Creer le bucket Storage

1. Dans le menu Supabase, allez dans **Storage**
2. Cliquez **New Bucket**
3. Nom : `trialgo-cards`
4. Cochez **Public bucket** (les images doivent etre accessibles sans auth)
5. Cliquez **Create bucket**

Ensuite, creez la structure de dossiers dans le bucket :
- `emettrices/savane/`
- `emettrices/ocean/`
- `emettrices/foret/`
- `cables/geometrique/`
- `cables/couleur/`
- `cables/dimension/`
- `cables/complexe/`
- `receptrices/savane/d1/`
- `receptrices/savane/d2/`
- `receptrices/savane/d3/`
- `receptrices/ocean/d1/`

---

## ETAPE 5 : Inserer des donnees de test

Ce script insere des cartes et des trios de test pour que
l'application puisse generer des questions.

**IMPORTANT** : Avant d'executer ce script, vous devez uploader
des images de test dans le bucket `trialgo-cards`.
Si vous n'avez pas encore d'images, les cartes seront creees
mais les images afficheront le widget d'erreur (icone grise).

```sql
-- =============================================================
-- SCRIPT 5 : DONNEES DE TEST
-- =============================================================
-- Insere des cartes et trios fictifs pour tester le jeu.
-- Les image_path pointent vers des fichiers qui doivent
-- exister dans le bucket trialgo-cards.
-- =============================================================

-- ===== EMETTRICES DE TEST =====

INSERT INTO cards (id, card_type, distance_level, image_path, image_width, image_height, theme_tags)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'emettrice', 1, 'emettrices/savane/lion_base.webp', 512, 512, ARRAY['animal', 'lion', 'savane']),
    ('00000000-0000-0000-0000-000000000002', 'emettrice', 1, 'emettrices/savane/elephant_base.webp', 512, 512, ARRAY['animal', 'elephant', 'savane']),
    ('00000000-0000-0000-0000-000000000003', 'emettrice', 1, 'emettrices/ocean/requin_base.webp', 512, 512, ARRAY['animal', 'requin', 'ocean']),
    ('00000000-0000-0000-0000-000000000004', 'emettrice', 1, 'emettrices/savane/girafe_base.webp', 512, 512, ARRAY['animal', 'girafe', 'savane']),
    ('00000000-0000-0000-0000-000000000005', 'emettrice', 1, 'emettrices/ocean/baleine_base.webp', 512, 512, ARRAY['animal', 'baleine', 'ocean']),
    ('00000000-0000-0000-0000-000000000006', 'emettrice', 1, 'emettrices/foret/renard_base.webp', 512, 512, ARRAY['animal', 'renard', 'foret'])
ON CONFLICT DO NOTHING;

-- ===== CABLES DE TEST =====

INSERT INTO cards (id, card_type, distance_level, image_path, cable_category, theme_tags)
VALUES
    ('00000000-0000-0000-0000-000000000101', 'cable', 1, 'cables/geometrique/miroir_h.webp', 'geometrique', ARRAY['miroir', 'symetrie', 'geometrie']),
    ('00000000-0000-0000-0000-000000000102', 'cable', 1, 'cables/geometrique/miroir_v.webp', 'geometrique', ARRAY['miroir', 'symetrie', 'geometrie']),
    ('00000000-0000-0000-0000-000000000103', 'cable', 1, 'cables/geometrique/rotation_90.webp', 'geometrique', ARRAY['rotation', 'geometrie']),
    ('00000000-0000-0000-0000-000000000104', 'cable', 1, 'cables/geometrique/rotation_180.webp', 'geometrique', ARRAY['rotation', 'geometrie']),
    ('00000000-0000-0000-0000-000000000105', 'cable', 1, 'cables/couleur/teinte_rouge.webp', 'couleur', ARRAY['rouge', 'teinte', 'couleur']),
    ('00000000-0000-0000-0000-000000000106', 'cable', 1, 'cables/couleur/teinte_bleue.webp', 'couleur', ARRAY['bleue', 'teinte', 'couleur']),
    ('00000000-0000-0000-0000-000000000107', 'cable', 1, 'cables/couleur/niveaux_gris.webp', 'couleur', ARRAY['gris', 'couleur']),
    ('00000000-0000-0000-0000-000000000108', 'cable', 1, 'cables/couleur/inversion.webp', 'couleur', ARRAY['inversion', 'couleur']),
    ('00000000-0000-0000-0000-000000000109', 'cable', 1, 'cables/dimension/agrandissement_2x.webp', 'dimension', ARRAY['agrandissement', 'dimension']),
    ('00000000-0000-0000-0000-000000000110', 'cable', 1, 'cables/dimension/reduction_2x.webp', 'dimension', ARRAY['reduction', 'dimension']),
    ('00000000-0000-0000-0000-000000000111', 'cable', 1, 'cables/complexe/fragmentation_3.webp', 'complexe', ARRAY['fragmentation', 'complexe']),
    ('00000000-0000-0000-0000-000000000112', 'cable', 1, 'cables/complexe/ombre_portee.webp', 'complexe', ARRAY['ombre', 'complexe'])
ON CONFLICT DO NOTHING;

-- ===== RECEPTRICES DE TEST (D1) =====

INSERT INTO cards (id, card_type, distance_level, image_path, theme_tags, parent_emettrice_id, parent_cable_id)
VALUES
    -- Lion + miroir_h = lion_miroir_h
    ('00000000-0000-0000-0000-000000000201', 'receptrice', 1, 'receptrices/savane/d1/lion_miroir_h.webp',
     ARRAY['animal', 'lion', 'savane', 'miroir'],
     '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000101'),

    -- Lion + teinte_rouge = lion_teinte_rouge
    ('00000000-0000-0000-0000-000000000202', 'receptrice', 1, 'receptrices/savane/d1/lion_teinte_rouge.webp',
     ARRAY['animal', 'lion', 'savane', 'rouge'],
     '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000105'),

    -- Lion + rotation_90 = lion_rotation_90
    ('00000000-0000-0000-0000-000000000203', 'receptrice', 1, 'receptrices/savane/d1/lion_rotation_90.webp',
     ARRAY['animal', 'lion', 'savane', 'rotation'],
     '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000103'),

    -- Elephant + miroir_h = elephant_miroir_h
    ('00000000-0000-0000-0000-000000000204', 'receptrice', 1, 'receptrices/savane/d1/elephant_miroir_h.webp',
     ARRAY['animal', 'elephant', 'savane', 'miroir'],
     '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000101'),

    -- Elephant + teinte_rouge = elephant_teinte_rouge
    ('00000000-0000-0000-0000-000000000205', 'receptrice', 1, 'receptrices/savane/d1/elephant_teinte_rouge.webp',
     ARRAY['animal', 'elephant', 'savane', 'rouge'],
     '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000105'),

    -- Requin + miroir_h = requin_miroir_h
    ('00000000-0000-0000-0000-000000000206', 'receptrice', 1, 'receptrices/ocean/d1/requin_miroir_h.webp',
     ARRAY['animal', 'requin', 'ocean', 'miroir'],
     '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000101'),

    -- Girafe + miroir_v = girafe_miroir_v
    ('00000000-0000-0000-0000-000000000207', 'receptrice', 1, 'receptrices/savane/d1/girafe_miroir_v.webp',
     ARRAY['animal', 'girafe', 'savane', 'miroir'],
     '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000102'),

    -- Baleine + teinte_bleue = baleine_teinte_bleue
    ('00000000-0000-0000-0000-000000000208', 'receptrice', 1, 'receptrices/ocean/d1/baleine_teinte_bleue.webp',
     ARRAY['animal', 'baleine', 'ocean', 'bleue'],
     '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000106'),

    -- Renard + niveaux_gris = renard_niveaux_gris
    ('00000000-0000-0000-0000-000000000209', 'receptrice', 1, 'receptrices/foret/d1/renard_niveaux_gris.webp',
     ARRAY['animal', 'renard', 'foret', 'gris'],
     '00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000107'),

    -- Lion + miroir_v = lion_miroir_v
    ('00000000-0000-0000-0000-000000000210', 'receptrice', 1, 'receptrices/savane/d1/lion_miroir_v.webp',
     ARRAY['animal', 'lion', 'savane', 'miroir'],
     '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000102')
ON CONFLICT DO NOTHING;

-- ===== TRIOS DE TEST (D1) =====

INSERT INTO card_trios (emettrice_id, cable_id, receptrice_id, distance_level)
VALUES
    -- Lion + miroir_h = lion_miroir_h
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000201', 1),
    -- Lion + teinte_rouge = lion_teinte_rouge
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000202', 1),
    -- Lion + rotation_90 = lion_rotation_90
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000203', 1),
    -- Elephant + miroir_h = elephant_miroir_h
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000204', 1),
    -- Elephant + teinte_rouge = elephant_teinte_rouge
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000105', '00000000-0000-0000-0000-000000000205', 1),
    -- Requin + miroir_h = requin_miroir_h
    ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000206', 1),
    -- Girafe + miroir_v = girafe_miroir_v
    ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000207', 1),
    -- Baleine + teinte_bleue = baleine_teinte_bleue
    ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000106', '00000000-0000-0000-0000-000000000208', 1),
    -- Renard + niveaux_gris = renard_niveaux_gris
    ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000107', '00000000-0000-0000-0000-000000000209', 1),
    -- Lion + miroir_v = lion_miroir_v
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000210', 1)
ON CONFLICT DO NOTHING;

-- ===== CODE D'ACTIVATION DE TEST =====
-- Ce code peut etre utilise pour tester l'activation
INSERT INTO activation_codes (code_value)
VALUES
    ('TRLG-TEST-0001AB'),
    ('TRLG-TEST-0002CD'),
    ('TRLG-TEST-0003EF')
ON CONFLICT DO NOTHING;
```

---

## ETAPE 6 : Activer Supabase Realtime

Pour que le provider de vies fonctionne en temps reel :

1. Allez dans **Database > Replication** dans le dashboard Supabase
2. Dans la section **supabase_realtime**, activez la table `user_profiles`
3. Cochez au minimum : **INSERT**, **UPDATE**

Cela permet au StreamProvider de recevoir les mises a jour
quand les vies sont modifiees (par le jeu ou par pg_cron).

---

## ETAPE 7 : Configurer l'authentification

1. Allez dans **Authentication > Providers**
2. Verifiez que **Email** est active (il l'est par defaut)
3. Pour Google OAuth (optionnel pour les tests) :
   - Activez **Google**
   - Configurez les credentials Google Cloud Console
   - Ajoutez le redirect URL

Pour les tests, l'auth par email suffit.

---

## ETAPE 8 : Verification

Executez ces requetes pour verifier que tout est en place :

```sql
-- Verifier les tables
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Compter les cartes par type
SELECT card_type, COUNT(*) FROM cards GROUP BY card_type;

-- Compter les trios
SELECT distance_level, COUNT(*) FROM card_trios GROUP BY distance_level;

-- Verifier les codes d'activation
SELECT code_value, is_activated FROM activation_codes;

-- Verifier les politiques RLS
SELECT tablename, policyname, cmd FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

Resultats attendus :
- 6 tables creees
- 6 emettrices, 12 cables, 10 receptrices = 28 cartes
- 10 trios D1
- 3 codes d'activation de test
- Politiques RLS sur toutes les tables

---

## ETAPE 9 : Tester l'application

1. Lancez l'application Flutter :
```bash
cd /home/tchakounte/Desktop/TriAlgo/trialgo
flutter run
```

2. Testez le flux :
   - L'ecran de connexion doit s'afficher
   - Creez un compte avec un email de test
   - Verifiez l'email (ou desactivez la verification dans Supabase Auth settings pour les tests)
   - Le menu principal doit s'afficher
   - Tapez "Jouer"
   - L'ecran de jeu doit charger une question avec des cartes

3. Si les images ne chargent pas (normal sans images uploadees) :
   - Les cartes afficheront l'icone de fallback (grise)
   - Le jeu fonctionne quand meme (la logique est independante des images)

---

## NOTES POUR LE DEVELOPPEMENT

### Desactiver la verification email (pour les tests)

Dans Supabase Dashboard :
1. **Authentication > Providers > Email**
2. Decochez **Confirm email**
3. Sauvegardez

Cela permet de se connecter immediatement apres l'inscription
sans avoir a verifier l'email. A reactiver en production.

### Contourner l'activation du code (pour les tests)

L'activation du code necessite une Edge Function qui n'est pas
encore deployee. Pour tester sans, vous pouvez :

1. Commenter temporairement la verification du code dans le provider auth
2. Ou inserer manuellement un code active pour votre utilisateur :

```sql
-- Remplacez <votre-user-id> par votre UUID (visible dans Authentication > Users)
UPDATE activation_codes
SET is_activated = TRUE,
    user_id = '<votre-user-id>',
    device_id = 'test-device',
    activated_at = now()
WHERE code_value = 'TRLG-TEST-0001AB';
```
