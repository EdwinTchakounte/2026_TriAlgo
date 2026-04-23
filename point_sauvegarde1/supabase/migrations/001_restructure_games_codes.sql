-- =============================================================
-- MIGRATION : 001_restructure_games_codes.sql
-- ROLE      : Restructurer games + codes + user_games + device binding
-- =============================================================
--
-- CHANGEMENTS MAJEURS :
--   1. Nouvelle table "games"                (catalogue des jeux)
--   2. Activation codes lies a un game et UNIQUES par utilisateur
--   3. Compteur de changements de device (max 3)
--   4. Table user_unlocked_cards (cartes gagnees = deck)
--   5. Avatar sur le profil
--   6. Fonction de verification pour le mode collectif
--
-- LOGIQUE :
--   Marc  → code X123 → jeu1 → lie a device-marc
--   Edwin → code X124 → jeu1 → lie a device-edwin
--   Un code d'activation est UNIQUE, assigne a UN utilisateur,
--   lie a UN jeu, et bind a UN device.
--
--   Changement de device autorise max 3 fois.
--   Apres ca, le code est bloque.
-- =============================================================


-- =============================================================
-- NETTOYAGE (re-execution propre)
-- =============================================================
DROP TABLE IF EXISTS user_unlocked_cards CASCADE;
DROP TABLE IF EXISTS user_played_nodes CASCADE;
DROP TABLE IF EXISTS activation_codes CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS nodes CASCADE;
DROP TABLE IF EXISTS cards CASCADE;
DROP TABLE IF EXISTS games CASCADE;


-- =============================================================
-- TABLE : games (catalogue des jeux disponibles)
-- =============================================================
-- Chaque "jeu" est un set de cartes + noeuds (ex: "Savane", "Ocean").
-- Plusieurs jeux peuvent coexister, chacun avec son propre graphe.
-- =============================================================
CREATE TABLE games (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,              -- "TRIALGO Savane"
  description  TEXT,                       -- description courte
  theme        TEXT,                       -- "savane", "ocean", etc.
  cover_image  TEXT,                       -- URL ou path de la pochette
  is_active    BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================
-- TABLE : cards (rattachees a un jeu)
-- =============================================================
CREATE TABLE cards (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id     UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  image_path  TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================
-- TABLE : nodes (rattachees a un jeu)
-- =============================================================
CREATE TABLE nodes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id         UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  node_index      INT NOT NULL,             -- unique PAR jeu
  emettrice_id    UUID REFERENCES cards(id),
  cable_id        UUID NOT NULL REFERENCES cards(id),
  receptrice_id   UUID NOT NULL REFERENCES cards(id),
  parent_node_id  UUID REFERENCES nodes(id) ON DELETE CASCADE,
  depth           INT NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ DEFAULT NOW(),

  -- L'index n'est unique que dans un meme jeu.
  UNIQUE(game_id, node_index),

  CHECK (depth BETWEEN 1 AND 5),
  CHECK (
    (depth = 1 AND parent_node_id IS NULL AND emettrice_id IS NOT NULL)
    OR
    (depth > 1 AND parent_node_id IS NOT NULL)
  )
);


-- =============================================================
-- TABLE : activation_codes
-- =============================================================
-- REGLES METIER :
--   - Chaque code est UNIQUE (primary key)
--   - Chaque code appartient a UN jeu specifique
--   - Chaque code peut etre assigne a UN seul utilisateur
--   - Le code est lie a UN device apres activation
--   - Le compteur device_changes_count monte a chaque changement
--   - Si device_changes_count >= max_device_changes : code bloque
-- =============================================================
CREATE TABLE activation_codes (
  code                 TEXT PRIMARY KEY,
  game_id              UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,

  -- NULL avant premiere utilisation. Un code = un utilisateur max.
  assigned_to          UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Device actuellement lie au code. NULL si jamais active.
  device_id            TEXT,

  -- Nombre de fois que le device a ete change.
  device_changes_count INT NOT NULL DEFAULT 0,

  -- Limite de changements autorises.
  max_device_changes   INT NOT NULL DEFAULT 3,

  -- Si true, le code est definitivement bloque.
  is_blocked           BOOLEAN NOT NULL DEFAULT FALSE,

  -- Si false, l'admin a desactive ce code manuellement.
  is_active            BOOLEAN NOT NULL DEFAULT TRUE,

  activated_at         TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT NOW(),

  -- Un utilisateur ne peut avoir qu'un seul code par jeu.
  UNIQUE(assigned_to, game_id)
);


-- =============================================================
-- TABLE : user_profiles
-- =============================================================
-- Profil general du joueur (independant du jeu).
-- Les stats par jeu sont dans user_games.
-- =============================================================
CREATE TABLE user_profiles (
  id                 UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username           TEXT NOT NULL DEFAULT 'Joueur',
  avatar_id          TEXT DEFAULT 'avatar_1',    -- ID de l'avatar selectionne
  selected_game_id   UUID REFERENCES games(id),  -- jeu actuellement joue
  is_admin           BOOLEAN DEFAULT FALSE,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);


-- =============================================================
-- TABLE : user_games (stats par jeu pour chaque utilisateur)
-- =============================================================
-- Chaque ligne = un jeu active par un joueur avec ses stats.
-- =============================================================
CREATE TABLE user_games (
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id          UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  activation_code  TEXT NOT NULL REFERENCES activation_codes(code),
  current_level    INT NOT NULL DEFAULT 1,
  total_score      INT NOT NULL DEFAULT 0,
  lives            INT NOT NULL DEFAULT 5,
  max_lives        INT NOT NULL DEFAULT 5,
  lives_last_refill TIMESTAMPTZ DEFAULT NOW(),
  activated_at     TIMESTAMPTZ DEFAULT NOW(),

  PRIMARY KEY (user_id, game_id),
  CHECK (lives >= 0 AND lives <= max_lives),
  CHECK (total_score >= 0)
);


-- =============================================================
-- TABLE : user_unlocked_cards (deck du joueur)
-- =============================================================
-- Cartes debloquees (gagnees par bonne reponse) pour chaque jeu.
-- C'est cette liste qui s'affiche dans la galerie.
-- =============================================================
CREATE TABLE user_unlocked_cards (
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  card_id      UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  game_id      UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  unlocked_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, card_id, game_id)
);


-- =============================================================
-- TABLE : user_played_nodes (tracking des noeuds logiques joues)
-- =============================================================
CREATE TABLE user_played_nodes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id       UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  tracking_key  TEXT NOT NULL,
  played_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, game_id, tracking_key)
);


-- =============================================================
-- INDEX (performance)
-- =============================================================
CREATE INDEX idx_cards_game         ON cards(game_id);
CREATE INDEX idx_nodes_game         ON nodes(game_id);
CREATE INDEX idx_nodes_depth        ON nodes(depth);
CREATE INDEX idx_nodes_parent       ON nodes(parent_node_id);
CREATE INDEX idx_codes_user         ON activation_codes(assigned_to);
CREATE INDEX idx_codes_device       ON activation_codes(device_id);
CREATE INDEX idx_user_games_user    ON user_games(user_id);
CREATE INDEX idx_unlocked_user      ON user_unlocked_cards(user_id, game_id);


-- =============================================================
-- FONCTION : activate_code
-- =============================================================
-- Logique cle de l'activation.
-- Gere :
--   1. Premiere activation (assigne user + device)
--   2. Re-activation meme device (ok, pas de changement)
--   3. Changement de device (incremente compteur)
--   4. Blocage si max atteint
--
-- RETOUR :
--   { success: bool, message: text, blocked: bool, changes_left: int }
-- =============================================================
CREATE OR REPLACE FUNCTION activate_code(
  p_code TEXT,
  p_user_id UUID,
  p_device_id TEXT
) RETURNS JSONB AS $$
DECLARE
  v_code_row activation_codes%ROWTYPE;
  v_existing_code TEXT;
BEGIN
  -- Charger le code.
  SELECT * INTO v_code_row
  FROM activation_codes
  WHERE code = p_code;

  -- Code inexistant.
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Code invalide',
      'blocked', false
    );
  END IF;

  -- Code desactive par l'admin.
  IF NOT v_code_row.is_active THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Code desactive',
      'blocked', false
    );
  END IF;

  -- Code bloque (max changements atteint).
  IF v_code_row.is_blocked THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Code bloque (trop de changements de device)',
      'blocked', true
    );
  END IF;

  -- Code deja assigne a un AUTRE utilisateur.
  IF v_code_row.assigned_to IS NOT NULL
     AND v_code_row.assigned_to != p_user_id THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Ce code est deja utilise par un autre joueur',
      'blocked', false
    );
  END IF;

  -- CHECK : l'utilisateur a-t-il deja un code actif pour ce jeu ?
  -- Un utilisateur ne peut pas avoir 2 codes actifs pour le meme
  -- jeu. Message clair si c'est le cas.
  IF v_code_row.assigned_to IS NULL THEN
    SELECT code INTO v_existing_code
    FROM activation_codes
    WHERE assigned_to = p_user_id
      AND game_id = v_code_row.game_id
      AND code != p_code
    LIMIT 1;

    IF v_existing_code IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Vous avez deja active ce jeu avec le code ' || v_existing_code,
        'blocked', false
      );
    END IF;
  END IF;

  -- CAS 1 : premiere activation (pas encore de user assigne)
  IF v_code_row.assigned_to IS NULL THEN
    UPDATE activation_codes
    SET assigned_to = p_user_id,
        device_id = p_device_id,
        activated_at = NOW()
    WHERE code = p_code;

    -- Creer l'entree user_games.
    INSERT INTO user_games (user_id, game_id, activation_code)
    VALUES (p_user_id, v_code_row.game_id, p_code)
    ON CONFLICT (user_id, game_id) DO NOTHING;

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Code active',
      'game_id', v_code_row.game_id,
      'changes_left', v_code_row.max_device_changes
    );
  END IF;

  -- CAS 2 : re-activation sur le MEME device (RAS)
  IF v_code_row.device_id = p_device_id THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'Code deja actif sur ce device',
      'game_id', v_code_row.game_id,
      'changes_left', v_code_row.max_device_changes - v_code_row.device_changes_count
    );
  END IF;

  -- CAS 3 : changement de device
  -- Incrementer le compteur.
  IF v_code_row.device_changes_count + 1 >= v_code_row.max_device_changes THEN
    -- Blocage definitif.
    UPDATE activation_codes
    SET device_changes_count = device_changes_count + 1,
        is_blocked = TRUE,
        device_id = p_device_id
    WHERE code = p_code;

    RETURN jsonb_build_object(
      'success', false,
      'message', 'Limite de changements atteinte (code bloque)',
      'blocked', true,
      'changes_left', 0
    );
  ELSE
    -- Changement autorise.
    UPDATE activation_codes
    SET device_changes_count = device_changes_count + 1,
        device_id = p_device_id
    WHERE code = p_code;

    RETURN jsonb_build_object(
      'success', true,
      'message', 'Device change',
      'game_id', v_code_row.game_id,
      'changes_left', v_code_row.max_device_changes - (v_code_row.device_changes_count + 1)
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================
-- FONCTION : verify_collective_trio
-- =============================================================
-- Mode collectif : verifie si un numero de trio est valide.
--
-- Parametres :
--   p_game_id    : le jeu en cours
--   p_node_index : le numero du trio a verifier (ex: 12)
--
-- Retour : JSONB
--   { exists, label_e, label_c, label_r, depth }
-- =============================================================
CREATE OR REPLACE FUNCTION verify_collective_trio(
  p_game_id UUID,
  p_node_index INT
) RETURNS JSONB AS $$
DECLARE
  v_node nodes%ROWTYPE;
  v_e_label TEXT;
  v_c_label TEXT;
  v_r_label TEXT;
BEGIN
  -- Charger le noeud.
  SELECT * INTO v_node
  FROM nodes
  WHERE game_id = p_game_id AND node_index = p_node_index;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'exists', false,
      'message', 'Trio inexistant pour ce jeu'
    );
  END IF;

  -- Resoudre l'emettrice (deduite du parent si enfant).
  IF v_node.emettrice_id IS NOT NULL THEN
    SELECT label INTO v_e_label FROM cards WHERE id = v_node.emettrice_id;
  ELSE
    SELECT label INTO v_e_label
    FROM cards
    WHERE id = (
      SELECT receptrice_id FROM nodes WHERE id = v_node.parent_node_id
    );
  END IF;

  -- Labels cable et receptrice.
  SELECT label INTO v_c_label FROM cards WHERE id = v_node.cable_id;
  SELECT label INTO v_r_label FROM cards WHERE id = v_node.receptrice_id;

  RETURN jsonb_build_object(
    'exists', true,
    'node_index', v_node.node_index,
    'depth', v_node.depth,
    'emettrice_label', v_e_label,
    'cable_label', v_c_label,
    'receptrice_label', v_r_label
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- =============================================================
-- RLS : Row Level Security
-- =============================================================

ALTER TABLE games               ENABLE ROW LEVEL SECURITY;
ALTER TABLE cards               ENABLE ROW LEVEL SECURITY;
ALTER TABLE nodes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE activation_codes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_games          ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_unlocked_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_played_nodes   ENABLE ROW LEVEL SECURITY;


-- Tous les utilisateurs authentifies peuvent lire games/cards/nodes
CREATE POLICY games_select_authenticated ON games
  FOR SELECT TO authenticated USING (is_active = true);

CREATE POLICY cards_select_authenticated ON cards
  FOR SELECT TO authenticated USING (true);

CREATE POLICY nodes_select_authenticated ON nodes
  FOR SELECT TO authenticated USING (true);


-- Activation codes : chaque user ne voit que son propre code
CREATE POLICY codes_select_own ON activation_codes
  FOR SELECT TO authenticated
  USING (assigned_to = auth.uid() OR assigned_to IS NULL);


-- User profiles : chacun son profil
CREATE POLICY profiles_select_own ON user_profiles
  FOR SELECT TO authenticated USING (id = auth.uid());
CREATE POLICY profiles_insert_own ON user_profiles
  FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY profiles_update_own ON user_profiles
  FOR UPDATE TO authenticated USING (id = auth.uid());


-- User games : chacun ses propres jeux
CREATE POLICY user_games_select_own ON user_games
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY user_games_insert_own ON user_games
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY user_games_update_own ON user_games
  FOR UPDATE TO authenticated USING (user_id = auth.uid());


-- User unlocked cards : chacun son deck
CREATE POLICY unlocked_select_own ON user_unlocked_cards
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY unlocked_insert_own ON user_unlocked_cards
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());


-- Played nodes : chacun ses propres traces
CREATE POLICY played_select_own ON user_played_nodes
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY played_insert_own ON user_played_nodes
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY played_delete_own ON user_played_nodes
  FOR DELETE TO authenticated USING (user_id = auth.uid());


-- Ecriture cards/nodes/games : admin@trialgo.com seul
CREATE POLICY cards_admin_all ON cards
  FOR ALL TO authenticated
  USING (auth.jwt() ->> 'email' = 'admin@trialgo.com')
  WITH CHECK (auth.jwt() ->> 'email' = 'admin@trialgo.com');

CREATE POLICY nodes_admin_all ON nodes
  FOR ALL TO authenticated
  USING (auth.jwt() ->> 'email' = 'admin@trialgo.com')
  WITH CHECK (auth.jwt() ->> 'email' = 'admin@trialgo.com');

CREATE POLICY games_admin_all ON games
  FOR ALL TO authenticated
  USING (auth.jwt() ->> 'email' = 'admin@trialgo.com')
  WITH CHECK (auth.jwt() ->> 'email' = 'admin@trialgo.com');

CREATE POLICY codes_admin_all ON activation_codes
  FOR ALL TO authenticated
  USING (auth.jwt() ->> 'email' = 'admin@trialgo.com')
  WITH CHECK (auth.jwt() ->> 'email' = 'admin@trialgo.com');


-- =============================================================
-- DONNEES : un jeu de test + 3 codes + graphe complet
-- =============================================================

-- Jeu de test
INSERT INTO games (id, name, description, theme) VALUES
  ('99999999-9999-9999-9999-000000000001', 'TRIALGO Savane',
   'Le jeu de base avec les animaux de la savane', 'savane');

-- 3 codes de test : un pour chaque joueur potentiel
INSERT INTO activation_codes (code, game_id) VALUES
  ('X123', '99999999-9999-9999-9999-000000000001'),
  ('X124', '99999999-9999-9999-9999-000000000001'),
  ('123456789', '99999999-9999-9999-9999-000000000001');

-- Cartes du jeu Savane (identiques au seed precedent, + game_id)
-- EMETTRICES
INSERT INTO cards (id, game_id, label, image_path) VALUES
  ('11111111-1111-1111-1111-000000000001', '99999999-9999-9999-9999-000000000001', 'Lion',   'https://loremflickr.com/300/300/lion?lock=101'),
  ('11111111-1111-1111-1111-000000000002', '99999999-9999-9999-9999-000000000001', 'Aigle',  'https://loremflickr.com/300/300/eagle?lock=102'),
  ('11111111-1111-1111-1111-000000000003', '99999999-9999-9999-9999-000000000001', 'Requin', 'https://loremflickr.com/300/300/shark?lock=103'),
  ('11111111-1111-1111-1111-000000000004', '99999999-9999-9999-9999-000000000001', 'Renard', 'https://loremflickr.com/300/300/fox?lock=104'),
  ('11111111-1111-1111-1111-000000000005', '99999999-9999-9999-9999-000000000001', 'Panda',  'https://loremflickr.com/300/300/panda?lock=105');

-- CABLES
INSERT INTO cards (id, game_id, label, image_path) VALUES
  ('22222222-2222-2222-2222-000000000001', '99999999-9999-9999-9999-000000000001', 'Miroir',     'https://loremflickr.com/300/300/mirror?lock=201'),
  ('22222222-2222-2222-2222-000000000002', '99999999-9999-9999-9999-000000000001', 'Rotation',   'https://loremflickr.com/300/300/spiral?lock=202'),
  ('22222222-2222-2222-2222-000000000003', '99999999-9999-9999-9999-000000000001', 'Couleur',    'https://loremflickr.com/300/300/paint?lock=203'),
  ('22222222-2222-2222-2222-000000000004', '99999999-9999-9999-9999-000000000001', 'Dimension',  'https://loremflickr.com/300/300/geometry?lock=204'),
  ('22222222-2222-2222-2222-000000000005', '99999999-9999-9999-9999-000000000001', 'Fragment',   'https://loremflickr.com/300/300/broken?lock=205'),
  ('22222222-2222-2222-2222-000000000006', '99999999-9999-9999-9999-000000000001', 'Ombre',      'https://loremflickr.com/300/300/shadow?lock=206');

-- RECEPTRICES (50 cartes)
INSERT INTO cards (id, game_id, label, image_path) VALUES
  ('33333333-3333-3333-3333-000000000001', '99999999-9999-9999-9999-000000000001', 'Lion Miroir',     'https://loremflickr.com/300/300/lion,reflection?lock=301'),
  ('33333333-3333-3333-3333-000000000002', '99999999-9999-9999-9999-000000000001', 'Lion Rotation',   'https://loremflickr.com/300/300/lion,wild?lock=302'),
  ('33333333-3333-3333-3333-000000000003', '99999999-9999-9999-9999-000000000001', 'Lion Couleur',    'https://loremflickr.com/300/300/lion,sunset?lock=303'),
  ('33333333-3333-3333-3333-000000000004', '99999999-9999-9999-9999-000000000001', 'Aigle Miroir',    'https://loremflickr.com/300/300/eagle,water?lock=304'),
  ('33333333-3333-3333-3333-000000000005', '99999999-9999-9999-9999-000000000001', 'Aigle Rotation',  'https://loremflickr.com/300/300/eagle,flight?lock=305'),
  ('33333333-3333-3333-3333-000000000006', '99999999-9999-9999-9999-000000000001', 'Aigle Dimension', 'https://loremflickr.com/300/300/eagle,sky?lock=306'),
  ('33333333-3333-3333-3333-000000000007', '99999999-9999-9999-9999-000000000001', 'Requin Miroir',   'https://loremflickr.com/300/300/shark,ocean?lock=307'),
  ('33333333-3333-3333-3333-000000000008', '99999999-9999-9999-9999-000000000001', 'Requin Couleur',  'https://loremflickr.com/300/300/shark,blue?lock=308'),
  ('33333333-3333-3333-3333-000000000009', '99999999-9999-9999-9999-000000000001', 'Requin Fragment', 'https://loremflickr.com/300/300/shark,deep?lock=309'),
  ('33333333-3333-3333-3333-000000000010', '99999999-9999-9999-9999-000000000001', 'Renard Rotation', 'https://loremflickr.com/300/300/fox,forest?lock=310'),
  ('33333333-3333-3333-3333-000000000011', '99999999-9999-9999-9999-000000000001', 'Renard Dimension','https://loremflickr.com/300/300/fox,winter?lock=311'),
  ('33333333-3333-3333-3333-000000000012', '99999999-9999-9999-9999-000000000001', 'Renard Ombre',    'https://loremflickr.com/300/300/fox,night?lock=312'),
  ('33333333-3333-3333-3333-000000000013', '99999999-9999-9999-9999-000000000001', 'Panda Couleur',   'https://loremflickr.com/300/300/panda,bamboo?lock=313'),
  ('33333333-3333-3333-3333-000000000014', '99999999-9999-9999-9999-000000000001', 'Panda Fragment',  'https://loremflickr.com/300/300/panda,baby?lock=314'),
  ('33333333-3333-3333-3333-000000000015', '99999999-9999-9999-9999-000000000001', 'Panda Ombre',     'https://loremflickr.com/300/300/panda,tree?lock=315'),
  ('33333333-3333-3333-3333-000000000016', '99999999-9999-9999-9999-000000000001', 'Lion Spirale',    'https://loremflickr.com/300/300/lion,roar?lock=316'),
  ('33333333-3333-3333-3333-000000000017', '99999999-9999-9999-9999-000000000001', 'Lion Surface',    'https://loremflickr.com/300/300/lion,mane?lock=317'),
  ('33333333-3333-3333-3333-000000000018', '99999999-9999-9999-9999-000000000001', 'Lion Teinte',     'https://loremflickr.com/300/300/lion,golden?lock=318'),
  ('33333333-3333-3333-3333-000000000019', '99999999-9999-9999-9999-000000000001', 'Lion Eclat',      'https://loremflickr.com/300/300/lion,proud?lock=319'),
  ('33333333-3333-3333-3333-000000000020', '99999999-9999-9999-9999-000000000001', 'Aigle Prisme',    'https://loremflickr.com/300/300/eagle,majestic?lock=320'),
  ('33333333-3333-3333-3333-000000000021', '99999999-9999-9999-9999-000000000001', 'Aigle Penombre',  'https://loremflickr.com/300/300/eagle,nest?lock=321'),
  ('33333333-3333-3333-3333-000000000022', '99999999-9999-9999-9999-000000000001', 'Aigle Crescendo', 'https://loremflickr.com/300/300/eagle,wings?lock=322'),
  ('33333333-3333-3333-3333-000000000023', '99999999-9999-9999-9999-000000000001', 'Requin Reflet',   'https://loremflickr.com/300/300/shark,white?lock=323'),
  ('33333333-3333-3333-3333-000000000024', '99999999-9999-9999-9999-000000000001', 'Requin Cristal',  'https://loremflickr.com/300/300/shark,reef?lock=324'),
  ('33333333-3333-3333-3333-000000000025', '99999999-9999-9999-9999-000000000001', 'Requin Echo',     'https://loremflickr.com/300/300/shark,fish?lock=325'),
  ('33333333-3333-3333-3333-000000000026', '99999999-9999-9999-9999-000000000001', 'Renard Mirage',   'https://loremflickr.com/300/300/fox,red?lock=326'),
  ('33333333-3333-3333-3333-000000000027', '99999999-9999-9999-9999-000000000001', 'Renard Brisure',  'https://loremflickr.com/300/300/fox,snow?lock=327'),
  ('33333333-3333-3333-3333-000000000028', '99999999-9999-9999-9999-000000000001', 'Renard Prisme',   'https://loremflickr.com/300/300/fox,jump?lock=328'),
  ('33333333-3333-3333-3333-000000000029', '99999999-9999-9999-9999-000000000001', 'Panda Reflet',    'https://loremflickr.com/300/300/panda,zoo?lock=329'),
  ('33333333-3333-3333-3333-000000000030', '99999999-9999-9999-9999-000000000001', 'Panda Surface',   'https://loremflickr.com/300/300/panda,sleep?lock=330'),
  ('33333333-3333-3333-3333-000000000031', '99999999-9999-9999-9999-000000000001', 'Panda Spirale',   'https://loremflickr.com/300/300/panda,play?lock=331'),
  ('33333333-3333-3333-3333-000000000032', '99999999-9999-9999-9999-000000000001', 'Aigle Halo',      'https://loremflickr.com/300/300/eagle,bald?lock=332'),
  ('33333333-3333-3333-3333-000000000033', '99999999-9999-9999-9999-000000000001', 'Aigle Vortex',    'https://loremflickr.com/300/300/eagle,hunt?lock=333'),
  ('33333333-3333-3333-3333-000000000034', '99999999-9999-9999-9999-000000000001', 'Requin Spirale',  'https://loremflickr.com/300/300/shark,jaw?lock=334'),
  ('33333333-3333-3333-3333-000000000035', '99999999-9999-9999-9999-000000000001', 'Requin Brume',    'https://loremflickr.com/300/300/shark,depths?lock=335'),
  ('33333333-3333-3333-3333-000000000036', '99999999-9999-9999-9999-000000000001', 'Lion Cristal',    'https://loremflickr.com/300/300/lion,king?lock=336'),
  ('33333333-3333-3333-3333-000000000037', '99999999-9999-9999-9999-000000000001', 'Lion Voile',      'https://loremflickr.com/300/300/lion,savanna?lock=337'),
  ('33333333-3333-3333-3333-000000000038', '99999999-9999-9999-9999-000000000001', 'Lion Halo',       'https://loremflickr.com/300/300/lion,africa?lock=338'),
  ('33333333-3333-3333-3333-000000000039', '99999999-9999-9999-9999-000000000001', 'Aigle Diamant',   'https://loremflickr.com/300/300/eagle,golden?lock=339'),
  ('33333333-3333-3333-3333-000000000040', '99999999-9999-9999-9999-000000000001', 'Aigle Brume',     'https://loremflickr.com/300/300/eagle,storm?lock=340'),
  ('33333333-3333-3333-3333-000000000041', '99999999-9999-9999-9999-000000000001', 'Requin Eclat',    'https://loremflickr.com/300/300/shark,whale?lock=341'),
  ('33333333-3333-3333-3333-000000000042', '99999999-9999-9999-9999-000000000001', 'Renard Vortex',   'https://loremflickr.com/300/300/fox,arctic?lock=342'),
  ('33333333-3333-3333-3333-000000000043', '99999999-9999-9999-9999-000000000001', 'Renard Echo',     'https://loremflickr.com/300/300/fox,silver?lock=343'),
  ('33333333-3333-3333-3333-000000000044', '99999999-9999-9999-9999-000000000001', 'Panda Voile',     'https://loremflickr.com/300/300/panda,wild?lock=344'),
  ('33333333-3333-3333-3333-000000000045', '99999999-9999-9999-9999-000000000001', 'Aigle Cristal',   'https://loremflickr.com/300/300/eagle,perched?lock=345'),
  ('33333333-3333-3333-3333-000000000046', '99999999-9999-9999-9999-000000000001', 'Requin Diamant',  'https://loremflickr.com/300/300/shark,attack?lock=346'),
  ('33333333-3333-3333-3333-000000000047', '99999999-9999-9999-9999-000000000001', 'Requin Halo',     'https://loremflickr.com/300/300/shark,giant?lock=347'),
  ('33333333-3333-3333-3333-000000000048', '99999999-9999-9999-9999-000000000001', 'Panda Diamant',   'https://loremflickr.com/300/300/panda,red?lock=348'),
  ('33333333-3333-3333-3333-000000000049', '99999999-9999-9999-9999-000000000001', 'Aigle Voile',     'https://loremflickr.com/300/300/eagle,fierce?lock=349'),
  ('33333333-3333-3333-3333-000000000050', '99999999-9999-9999-9999-000000000001', 'Requin Brisure',  'https://loremflickr.com/300/300/shark,tooth?lock=350');


-- NOEUDS D1 (15 racines)
INSERT INTO nodes (id, game_id, node_index, emettrice_id, cable_id, receptrice_id, parent_node_id, depth) VALUES
  ('44444444-4444-4444-4444-000000000001', '99999999-9999-9999-9999-000000000001',  1, '11111111-1111-1111-1111-000000000001', '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000001', NULL, 1),
  ('44444444-4444-4444-4444-000000000002', '99999999-9999-9999-9999-000000000001',  2, '11111111-1111-1111-1111-000000000001', '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000002', NULL, 1),
  ('44444444-4444-4444-4444-000000000003', '99999999-9999-9999-9999-000000000001',  3, '11111111-1111-1111-1111-000000000001', '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000003', NULL, 1),
  ('44444444-4444-4444-4444-000000000004', '99999999-9999-9999-9999-000000000001',  4, '11111111-1111-1111-1111-000000000002', '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000004', NULL, 1),
  ('44444444-4444-4444-4444-000000000005', '99999999-9999-9999-9999-000000000001',  5, '11111111-1111-1111-1111-000000000002', '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000005', NULL, 1),
  ('44444444-4444-4444-4444-000000000006', '99999999-9999-9999-9999-000000000001',  6, '11111111-1111-1111-1111-000000000002', '22222222-2222-2222-2222-000000000004', '33333333-3333-3333-3333-000000000006', NULL, 1),
  ('44444444-4444-4444-4444-000000000007', '99999999-9999-9999-9999-000000000001',  7, '11111111-1111-1111-1111-000000000003', '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000007', NULL, 1),
  ('44444444-4444-4444-4444-000000000008', '99999999-9999-9999-9999-000000000001',  8, '11111111-1111-1111-1111-000000000003', '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000008', NULL, 1),
  ('44444444-4444-4444-4444-000000000009', '99999999-9999-9999-9999-000000000001',  9, '11111111-1111-1111-1111-000000000003', '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000009', NULL, 1),
  ('44444444-4444-4444-4444-000000000010', '99999999-9999-9999-9999-000000000001', 10, '11111111-1111-1111-1111-000000000004', '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000010', NULL, 1),
  ('44444444-4444-4444-4444-000000000011', '99999999-9999-9999-9999-000000000001', 11, '11111111-1111-1111-1111-000000000004', '22222222-2222-2222-2222-000000000004', '33333333-3333-3333-3333-000000000011', NULL, 1),
  ('44444444-4444-4444-4444-000000000012', '99999999-9999-9999-9999-000000000001', 12, '11111111-1111-1111-1111-000000000004', '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000012', NULL, 1),
  ('44444444-4444-4444-4444-000000000013', '99999999-9999-9999-9999-000000000001', 13, '11111111-1111-1111-1111-000000000005', '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000013', NULL, 1),
  ('44444444-4444-4444-4444-000000000014', '99999999-9999-9999-9999-000000000001', 14, '11111111-1111-1111-1111-000000000005', '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000014', NULL, 1),
  ('44444444-4444-4444-4444-000000000015', '99999999-9999-9999-9999-000000000001', 15, '11111111-1111-1111-1111-000000000005', '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000015', NULL, 1);


-- NOEUDS D2 (20 enfants)
INSERT INTO nodes (id, game_id, node_index, emettrice_id, cable_id, receptrice_id, parent_node_id, depth) VALUES
  ('44444444-4444-4444-4444-000000000016', '99999999-9999-9999-9999-000000000001', 16, NULL, '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000016', '44444444-4444-4444-4444-000000000001', 2),
  ('44444444-4444-4444-4444-000000000017', '99999999-9999-9999-9999-000000000001', 17, NULL, '22222222-2222-2222-2222-000000000004', '33333333-3333-3333-3333-000000000017', '44444444-4444-4444-4444-000000000001', 2),
  ('44444444-4444-4444-4444-000000000018', '99999999-9999-9999-9999-000000000001', 18, NULL, '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000018', '44444444-4444-4444-4444-000000000002', 2),
  ('44444444-4444-4444-4444-000000000019', '99999999-9999-9999-9999-000000000001', 19, NULL, '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000019', '44444444-4444-4444-4444-000000000003', 2),
  ('44444444-4444-4444-4444-000000000020', '99999999-9999-9999-9999-000000000001', 20, NULL, '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000020', '44444444-4444-4444-4444-000000000004', 2),
  ('44444444-4444-4444-4444-000000000021', '99999999-9999-9999-9999-000000000001', 21, NULL, '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000021', '44444444-4444-4444-4444-000000000004', 2),
  ('44444444-4444-4444-4444-000000000022', '99999999-9999-9999-9999-000000000001', 22, NULL, '22222222-2222-2222-2222-000000000004', '33333333-3333-3333-3333-000000000022', '44444444-4444-4444-4444-000000000005', 2),
  ('44444444-4444-4444-4444-000000000023', '99999999-9999-9999-9999-000000000001', 23, NULL, '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000023', '44444444-4444-4444-4444-000000000007', 2),
  ('44444444-4444-4444-4444-000000000024', '99999999-9999-9999-9999-000000000001', 24, NULL, '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000024', '44444444-4444-4444-4444-000000000007', 2),
  ('44444444-4444-4444-4444-000000000025', '99999999-9999-9999-9999-000000000001', 25, NULL, '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000025', '44444444-4444-4444-4444-000000000008', 2),
  ('44444444-4444-4444-4444-000000000026', '99999999-9999-9999-9999-000000000001', 26, NULL, '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000026', '44444444-4444-4444-4444-000000000010', 2),
  ('44444444-4444-4444-4444-000000000027', '99999999-9999-9999-9999-000000000001', 27, NULL, '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000027', '44444444-4444-4444-4444-000000000010', 2),
  ('44444444-4444-4444-4444-000000000028', '99999999-9999-9999-9999-000000000001', 28, NULL, '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000028', '44444444-4444-4444-4444-000000000011', 2),
  ('44444444-4444-4444-4444-000000000029', '99999999-9999-9999-9999-000000000001', 29, NULL, '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000029', '44444444-4444-4444-4444-000000000013', 2),
  ('44444444-4444-4444-4444-000000000030', '99999999-9999-9999-9999-000000000001', 30, NULL, '22222222-2222-2222-2222-000000000004', '33333333-3333-3333-3333-000000000030', '44444444-4444-4444-4444-000000000013', 2),
  ('44444444-4444-4444-4444-000000000031', '99999999-9999-9999-9999-000000000001', 31, NULL, '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000031', '44444444-4444-4444-4444-000000000014', 2),
  ('44444444-4444-4444-4444-000000000032', '99999999-9999-9999-9999-000000000001', 32, NULL, '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000032', '44444444-4444-4444-4444-000000000006', 2),
  ('44444444-4444-4444-4444-000000000033', '99999999-9999-9999-9999-000000000001', 33, NULL, '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000033', '44444444-4444-4444-4444-000000000006', 2),
  ('44444444-4444-4444-4444-000000000034', '99999999-9999-9999-9999-000000000001', 34, NULL, '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000034', '44444444-4444-4444-4444-000000000009', 2),
  ('44444444-4444-4444-4444-000000000035', '99999999-9999-9999-9999-000000000001', 35, NULL, '22222222-2222-2222-2222-000000000004', '33333333-3333-3333-3333-000000000035', '44444444-4444-4444-4444-000000000009', 2);


-- NOEUDS D3 (15 petits-enfants)
INSERT INTO nodes (id, game_id, node_index, emettrice_id, cable_id, receptrice_id, parent_node_id, depth) VALUES
  ('44444444-4444-4444-4444-000000000036', '99999999-9999-9999-9999-000000000001', 36, NULL, '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000036', '44444444-4444-4444-4444-000000000016', 3),
  ('44444444-4444-4444-4444-000000000037', '99999999-9999-9999-9999-000000000001', 37, NULL, '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000037', '44444444-4444-4444-4444-000000000016', 3),
  ('44444444-4444-4444-4444-000000000038', '99999999-9999-9999-9999-000000000001', 38, NULL, '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000038', '44444444-4444-4444-4444-000000000017', 3),
  ('44444444-4444-4444-4444-000000000039', '99999999-9999-9999-9999-000000000001', 39, NULL, '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000039', '44444444-4444-4444-4444-000000000020', 3),
  ('44444444-4444-4444-4444-000000000040', '99999999-9999-9999-9999-000000000001', 40, NULL, '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000040', '44444444-4444-4444-4444-000000000020', 3),
  ('44444444-4444-4444-4444-000000000041', '99999999-9999-9999-9999-000000000001', 41, NULL, '22222222-2222-2222-2222-000000000004', '33333333-3333-3333-3333-000000000041', '44444444-4444-4444-4444-000000000023', 3),
  ('44444444-4444-4444-4444-000000000042', '99999999-9999-9999-9999-000000000001', 42, NULL, '22222222-2222-2222-2222-000000000003', '33333333-3333-3333-3333-000000000042', '44444444-4444-4444-4444-000000000026', 3),
  ('44444444-4444-4444-4444-000000000043', '99999999-9999-9999-9999-000000000001', 43, NULL, '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000043', '44444444-4444-4444-4444-000000000026', 3),
  ('44444444-4444-4444-4444-000000000044', '99999999-9999-9999-9999-000000000001', 44, NULL, '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000044', '44444444-4444-4444-4444-000000000029', 3),
  ('44444444-4444-4444-4444-000000000045', '99999999-9999-9999-9999-000000000001', 45, NULL, '22222222-2222-2222-2222-000000000005', '33333333-3333-3333-3333-000000000045', '44444444-4444-4444-4444-000000000032', 3),
  ('44444444-4444-4444-4444-000000000046', '99999999-9999-9999-9999-000000000001', 46, NULL, '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000046', '44444444-4444-4444-4444-000000000034', 3),
  ('44444444-4444-4444-4444-000000000047', '99999999-9999-9999-9999-000000000001', 47, NULL, '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000047', '44444444-4444-4444-4444-000000000034', 3),
  ('44444444-4444-4444-4444-000000000048', '99999999-9999-9999-9999-000000000001', 48, NULL, '22222222-2222-2222-2222-000000000006', '33333333-3333-3333-3333-000000000048', '44444444-4444-4444-4444-000000000030', 3),
  ('44444444-4444-4444-4444-000000000049', '99999999-9999-9999-9999-000000000001', 49, NULL, '22222222-2222-2222-2222-000000000001', '33333333-3333-3333-3333-000000000049', '44444444-4444-4444-4444-000000000022', 3),
  ('44444444-4444-4444-4444-000000000050', '99999999-9999-9999-9999-000000000001', 50, NULL, '22222222-2222-2222-2222-000000000002', '33333333-3333-3333-3333-000000000050', '44444444-4444-4444-4444-000000000025', 3);


-- =============================================================
-- VERIFICATION
-- =============================================================
SELECT 'games' AS t, COUNT(*) AS n FROM games
UNION ALL SELECT 'cards', COUNT(*) FROM cards
UNION ALL SELECT 'nodes', COUNT(*) FROM nodes
UNION ALL SELECT 'activation_codes', COUNT(*) FROM activation_codes;
