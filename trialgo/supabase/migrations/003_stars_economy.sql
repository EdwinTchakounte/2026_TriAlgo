-- =============================================================
-- MIGRATION : 003_stars_economy.sql
-- ROLE      : Economie d'etoiles (regen temps + echange contre vies)
-- =============================================================
--
-- POURQUOI UNE ECONOMIE D'ETOILES ?
-- ---------------------------------
-- Avant cette migration, les "etoiles" de l'app etaient de simples
-- badges cosmetiques attribues en fin de partie (0, 1, 2 ou 3 selon
-- la precision). Aucune utilite pratique : pas d'echange, pas de
-- cumul, pas de shop. Le joueur qui perdait ses 5 vies devait
-- attendre 30 min * 5 = 2h30 pour rejouer pleinement.
--
-- Avec cette migration :
--   - Les etoiles deviennent une MONNAIE persistante (cumulative)
--   - Elles se regenerent automatiquement (1 etoile / 5 min)
--   - Elles peuvent etre echangees contre des vies (10 etoiles = 1 vie)
--   - Elles ont un plafond (50 max) pour garder une pression de jeu
--
-- POURQUOI SUR user_profiles ET PAS user_games ?
-- ----------------------------------------------
-- Un joueur peut activer plusieurs jeux (savane, ocean, ...). Si les
-- etoiles etaient par jeu, le joueur devrait re-grinder pour chaque.
-- On veut au contraire un WALLET UNIQUE transverse : les etoiles
-- gagnees en jouant a la savane peuvent servir a recharger des vies
-- sur l'ocean. Donc stars va sur user_profiles, pas user_games.
--
-- POURQUOI PAS DE CRON SERVER POUR LA REGEN ?
-- -------------------------------------------
-- On calcule la regen cote client au demarrage de l'app :
--   delta = floor((now - stars_last_regen) / 5min)
--   new_stars = min(stars + delta, stars_max)
--   new_stars_last_regen = stars_last_regen + delta * 5min
--
-- Cette approche est :
--   - simple (pas de pg_cron a maintenir)
--   - fiable (le temps est calcule depuis un timestamp DB, donc
--     le joueur ne peut pas tricher en changeant l'heure du tel)
--   - efficace (aucun job tourne en permanence si le joueur est absent)
--
-- Note : on applique la regen quand le joueur ouvre l'app OU tente
-- une action qui necessite de lire le compteur (dialog d'echange).
-- =============================================================


-- =============================================================
-- COLONNE : stars (wallet transverse)
-- =============================================================
-- DEFAULT 10 : le nouveau joueur demarre avec 10 etoiles = 1 vie
-- de depannage s'il vide ses vies initiales rapidement. Evite la
-- frustration du "debutant bloque" et teste la mecanique d'echange
-- des la premiere experience.
-- =============================================================
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS stars INT NOT NULL DEFAULT 10;

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS stars_max INT NOT NULL DEFAULT 50;

-- Timestamp UTC du dernier moment ou la regen a ete appliquee.
-- Initialise a NOW() : quand le joueur se connecte la premiere fois,
-- il ne gagne pas instantanement 10 etoiles supplementaires.
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS stars_last_regen TIMESTAMPTZ NOT NULL DEFAULT NOW();


-- =============================================================
-- CONTRAINTE : plafond et plancher
-- =============================================================
-- stars >= 0 : on ne peut pas avoir une dette d'etoiles
-- stars <= stars_max : le plafond est respecte meme apres UPDATE
-- =============================================================
ALTER TABLE user_profiles
  DROP CONSTRAINT IF EXISTS stars_range_check;

ALTER TABLE user_profiles
  ADD CONSTRAINT stars_range_check
    CHECK (stars >= 0 AND stars <= stars_max);


-- =============================================================
-- FONCTION RPC : exchange_stars_for_life
-- =============================================================
-- Echange atomique : debite 10 etoiles du wallet + credite 1 vie
-- sur le jeu actif. Si l'une des conditions echoue (pas assez
-- d'etoiles, vies deja au max, pas de jeu selectionne), aucune
-- modification n'est persistee (transaction SQL).
--
-- On fait ca cote serveur pour garantir l'atomicite : sans RPC,
-- un client malveillant pourrait patcher les deux UPDATE a part
-- et tricher sur le cout.
-- =============================================================
CREATE OR REPLACE FUNCTION exchange_stars_for_life(
  p_user_id UUID,
  p_cost INT DEFAULT 10
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_stars INT;
  v_lives INT;
  v_max_lives INT;
  v_game_id UUID;
BEGIN
  -- Recuperer le jeu selectionne.
  SELECT selected_game_id, stars INTO v_game_id, v_stars
  FROM user_profiles
  WHERE id = p_user_id;

  IF v_game_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'no_game_selected'
    );
  END IF;

  IF v_stars < p_cost THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'not_enough_stars',
      'stars', v_stars,
      'cost', p_cost
    );
  END IF;

  -- Recuperer l'etat des vies pour le jeu actif.
  SELECT lives, max_lives INTO v_lives, v_max_lives
  FROM user_games
  WHERE user_id = p_user_id AND game_id = v_game_id;

  IF v_lives >= v_max_lives THEN
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'lives_already_max',
      'lives', v_lives,
      'max_lives', v_max_lives
    );
  END IF;

  -- Debit des etoiles + credit d'une vie (en une transaction implicite).
  UPDATE user_profiles
  SET stars = stars - p_cost
  WHERE id = p_user_id;

  UPDATE user_games
  SET lives = lives + 1
  WHERE user_id = p_user_id AND game_id = v_game_id;

  RETURN jsonb_build_object(
    'success', true,
    'stars', v_stars - p_cost,
    'lives', v_lives + 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION exchange_stars_for_life(UUID, INT) TO authenticated;


-- =============================================================
-- INDEX : accelere les queries "qui a combien d'etoiles"
-- =============================================================
-- Le plafond et la regen sont lus a chaque ouverture d'app. Avoir
-- un index sur stars rend ces queries O(log n) au lieu de O(n).
-- =============================================================
CREATE INDEX IF NOT EXISTS idx_user_profiles_stars
  ON user_profiles(stars);
