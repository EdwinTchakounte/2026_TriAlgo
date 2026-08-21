-- =============================================================
-- MIGRATION : 005_dashboard_admin.sql
-- ROLE      : Preparer le backend pour l'app dashboard admin
-- =============================================================
--
-- POURQUOI CETTE MIGRATION ?
-- --------------------------
-- L'app dashboard (trialgo_dashboard) doit pouvoir :
--   1. Identifier un admin de maniere fiable (pas un email
--      hardcode dans une policy SQL).
--   2. Filtrer les cartes par type (emettrice / cable /
--      receptrice) pour offrir une UI claire dans la page Cards.
--   3. Uploader des images dans le bucket Storage et lier les
--      URLs publiques aux nouvelles lignes "cards".
--
-- CHANGEMENTS :
--   1. Ajout colonne cards.card_type (CHECK enum)
--   2. Backfill des cartes existantes en deduisant le type a
--      partir du prefixe UUID (1*=emettrice, 2*=cable, 3*=
--      receptrice) -- convention du seed initial.
--   3. Drop des anciennes policies email-hardcoded et creation
--      de nouvelles policies basees sur user_profiles.is_admin.
--   4. Bucket Storage "trialgo-cards" + policies (lecture publique,
--      ecriture admin).
--
-- IDEMPOTENCE : ALTER...IF NOT EXISTS / DROP IF EXISTS partout
-- pour pouvoir rejouer la migration sans casse.
-- =============================================================


-- =============================================================
-- 1. COLONNE card_type sur cards
-- =============================================================
-- Trois roles distincts dans le jeu TRIALGO :
--   - emettrice  : carte de gauche, "source" de la transformation
--   - cable      : transformation appliquee (ex: rotation)
--   - receptrice : resultat (carte de droite)
-- Avant cette migration, la distinction etait implicite (preffixe
-- UUID dans le seed). Pour le dashboard, on veut filtrer
-- explicitement, donc on stocke le type en colonne.
-- =============================================================
ALTER TABLE cards
  ADD COLUMN IF NOT EXISTS card_type TEXT;

-- Contrainte de valeurs autorisees. On utilise un CHECK plutot
-- qu'un type ENUM PostgreSQL pour garder la flexibilite (ajouter
-- un nouveau type ne necessitera pas un ALTER TYPE).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'cards_card_type_check'
  ) THEN
    ALTER TABLE cards
      ADD CONSTRAINT cards_card_type_check
      CHECK (card_type IN ('emettrice', 'cable', 'receptrice'));
  END IF;
END $$;

-- Backfill : le seed initial utilise une convention sur les UUID
--   '11111111-...'  -> emettrice
--   '22222222-...'  -> cable
--   '33333333-...'  -> receptrice
-- On exploite cette regularite. Pour les futures cartes creees
-- via le dashboard, le client fournira card_type directement.
UPDATE cards
SET card_type = CASE
  WHEN id::TEXT LIKE '11111111-%' THEN 'emettrice'
  WHEN id::TEXT LIKE '22222222-%' THEN 'cable'
  WHEN id::TEXT LIKE '33333333-%' THEN 'receptrice'
  ELSE NULL
END
WHERE card_type IS NULL;

-- Index pour filtrage rapide par type dans la page Cards
CREATE INDEX IF NOT EXISTS idx_cards_type ON cards(game_id, card_type);


-- =============================================================
-- 2. POLICIES RLS : remplacer email-hardcoded par is_admin
-- =============================================================
-- AVANT : auth.jwt() ->> 'email' = 'admin@trialgo.com'
--   Probleme : un seul admin possible, et la valeur est ecrite
--   en dur dans la base. Difficile a maintenir.
--
-- APRES : EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid()
--                 AND is_admin = TRUE)
--   Avantage : on cree un admin en flippant un bool, pas en
--   touchant aux policies. Multi-admin gere naturellement.
-- =============================================================

-- Helper : fonction qui retourne TRUE si l'user courant est admin.
-- SECURITY DEFINER + STABLE pour que PostgreSQL puisse cacher le
-- resultat dans une meme requete.
CREATE OR REPLACE FUNCTION is_admin_user() RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid() AND is_admin = TRUE
  );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;


-- Cards : drop l'ancienne policy email puis cree la nouvelle
DROP POLICY IF EXISTS cards_admin_all ON cards;
CREATE POLICY cards_admin_all ON cards
  FOR ALL TO authenticated
  USING (is_admin_user())
  WITH CHECK (is_admin_user());

-- Nodes : idem
DROP POLICY IF EXISTS nodes_admin_all ON nodes;
CREATE POLICY nodes_admin_all ON nodes
  FOR ALL TO authenticated
  USING (is_admin_user())
  WITH CHECK (is_admin_user());

-- Games : idem
DROP POLICY IF EXISTS games_admin_all ON games;
CREATE POLICY games_admin_all ON games
  FOR ALL TO authenticated
  USING (is_admin_user())
  WITH CHECK (is_admin_user());

-- Activation codes : idem
DROP POLICY IF EXISTS codes_admin_all ON activation_codes;
CREATE POLICY codes_admin_all ON activation_codes
  FOR ALL TO authenticated
  USING (is_admin_user())
  WITH CHECK (is_admin_user());


-- =============================================================
-- 3. STORAGE BUCKET : trialgo-cards
-- =============================================================
-- Le bucket peut deja exister (cf. memoire projet : URL publique
-- https://...supabase.co/storage/v1/object/public/trialgo-cards).
-- ON CONFLICT DO NOTHING garantit l'idempotence.
--
-- public = TRUE : les URLs sont accessibles sans token JWT.
-- C'est ce qu'on veut : le jeu mobile lit ces images sans devoir
-- gerer une URL signee qui expire.
-- =============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'trialgo-cards',
  'trialgo-cards',
  TRUE,
  5242880,                          -- 5 MB max par image (largement suffisant)
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;


-- =============================================================
-- 4. POLICIES STORAGE : lecture publique, ecriture admin
-- =============================================================
-- Note : storage.objects a aussi RLS active par defaut. Il faut
-- donc creer des policies meme si le bucket est public.
-- =============================================================

-- LECTURE : tout le monde (anon + authenticated) peut lire
-- les fichiers de trialgo-cards. C'est la cle pour que le jeu
-- mobile affiche les cartes sans authentification prealable.
DROP POLICY IF EXISTS "trialgo_cards_read_public" ON storage.objects;
CREATE POLICY "trialgo_cards_read_public" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'trialgo-cards');

-- INSERT : seul un admin peut uploader. is_admin_user() utilise
-- auth.uid() qui est dispo dans les RLS des storage.objects.
DROP POLICY IF EXISTS "trialgo_cards_insert_admin" ON storage.objects;
CREATE POLICY "trialgo_cards_insert_admin" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'trialgo-cards' AND is_admin_user());

-- UPDATE : idem (rarement utilise mais on le couvre).
DROP POLICY IF EXISTS "trialgo_cards_update_admin" ON storage.objects;
CREATE POLICY "trialgo_cards_update_admin" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'trialgo-cards' AND is_admin_user())
  WITH CHECK (bucket_id = 'trialgo-cards' AND is_admin_user());

-- DELETE : idem (suppression d'une carte = nettoyage du fichier).
DROP POLICY IF EXISTS "trialgo_cards_delete_admin" ON storage.objects;
CREATE POLICY "trialgo_cards_delete_admin" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'trialgo-cards' AND is_admin_user());


-- =============================================================
-- 5. PROMOTION INITIALE D'UN ADMIN
-- =============================================================
-- Cette migration ne peut pas connaitre l'UUID du futur admin.
-- Pour le bootstrap, lance dans le SQL editor Supabase :
--
--   UPDATE user_profiles
--   SET is_admin = TRUE
--   WHERE id = (SELECT id FROM auth.users
--               WHERE email = 'tchambaedwin@gmail.com');
--
-- Apres ca, le compte connecte avec cet email aura tous les
-- droits d'ecriture sur cards/nodes/games + storage.
-- =============================================================


-- =============================================================
-- VERIFICATION
-- =============================================================
SELECT 'cards_with_type' AS k, COUNT(*) AS n FROM cards WHERE card_type IS NOT NULL
UNION ALL
SELECT 'cards_no_type',       COUNT(*)      FROM cards WHERE card_type IS NULL
UNION ALL
SELECT 'admins',              COUNT(*)      FROM user_profiles WHERE is_admin = TRUE
UNION ALL
SELECT 'storage_bucket',      COUNT(*)      FROM storage.buckets WHERE id = 'trialgo-cards';
