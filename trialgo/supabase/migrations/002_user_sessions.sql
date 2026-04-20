-- =============================================================
-- MIGRATION : 002_user_sessions.sql
-- ROLE      : Ajouter la table d'historique des sessions de jeu
-- =============================================================
--
-- POURQUOI CETTE MIGRATION ?
-- --------------------------
-- La table user_games (migration 001) stocke uniquement l'etat
-- CUMULATIF du joueur pour un jeu donne :
--   - total_score   : score total depuis le debut
--   - current_level : niveau courant
--   - lives         : vies restantes
--
-- Ces donnees ne permettent PAS de repondre aux questions suivantes :
--   - Quelle etait la derniere partie jouee ?
--   - Combien de fois ai-je joue le niveau 5 ?
--   - Quelle est ma progression recente (7 derniers jours) ?
--   - Avec quelle precision ai-je passe le niveau 3 ?
--
-- Cette migration cree une table user_sessions qui trace CHAQUE
-- partie individuelle, avec toutes ses statistiques detaillees.
--
-- UTILISATEUR :
-- -------------
-- - La home affiche "derniere session : niveau X, score Y"
-- - La page profil peut afficher un historique complet
-- - Le leaderboard peut afficher "meilleure session" en bonus
-- - Les analytics internes peuvent calculer la retention, etc.
--
-- RELATION AVEC user_games :
-- --------------------------
-- A la fin d'une partie, on fait DEUX operations :
--   1. UPDATE sur user_games (score cumule, niveau, vies)
--   2. INSERT dans user_sessions (snapshot de la partie jouee)
-- =============================================================


-- =============================================================
-- NETTOYAGE (pour re-execution en dev)
-- =============================================================
-- Le DROP IF EXISTS permet de relancer la migration sans erreur
-- si la table existe deja. "CASCADE" supprime aussi tous les
-- objets dependants (contraintes, index, policies RLS).
-- =============================================================
DROP TABLE IF EXISTS user_sessions CASCADE;


-- =============================================================
-- TABLE : user_sessions
-- =============================================================
-- Trace chaque partie jouee par un utilisateur.
--
-- Une ligne = une partie completee (ou abandonnee).
-- La ligne est INSEREE a la fin de la partie, jamais mise a jour.
-- =============================================================
CREATE TABLE user_sessions (

  -- --- IDENTIFIANT UNIQUE DE LA SESSION ---
  -- UUID genere automatiquement par PostgreSQL.
  -- "gen_random_uuid()" provient de l'extension pgcrypto
  -- (activee par defaut sur Supabase).
  -- Permet d'avoir un identifiant unique sans avoir besoin
  -- d'une sequence et sans devoiler le nombre total de sessions.
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- --- CLE ETRANGERE VERS L'UTILISATEUR ---
  -- Reference vers auth.users (table geree par Supabase Auth).
  -- NOT NULL : une session doit toujours etre rattachee a un user.
  -- ON DELETE CASCADE : si l'utilisateur supprime son compte,
  -- toutes ses sessions sont supprimees (RGPD : droit a l'oubli).
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- --- CLE ETRANGERE VERS LE JEU JOUE ---
  -- Reference vers games (catalogue des jeux, ex: "Savane", "Ocean").
  -- NOT NULL : une session est toujours rattachee a un jeu precis.
  -- ON DELETE CASCADE : si l'admin supprime un jeu complet, les
  -- sessions associees disparaissent aussi (coherence referentielle).
  game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,

  -- --- NIVEAU JOUE ---
  -- Le numero du niveau sur lequel a porte cette partie (1, 2, 3...).
  -- INT suffit largement (on ne depassera jamais 100 niveaux).
  -- NOT NULL : une session sans niveau ne fait pas sens.
  level INT NOT NULL,

  -- --- SCORE GAGNE DANS CETTE PARTIE ---
  -- Attention : c'est le score de LA PARTIE (pas le score cumule).
  -- Le score cumule est dans user_games.total_score.
  -- DEFAULT 0 : si la partie est abandonnee tres tot, score = 0.
  score_gained INT NOT NULL DEFAULT 0,

  -- --- NOMBRE DE BONNES REPONSES ---
  -- Compteur de bonnes reponses pendant la partie.
  -- Utile pour calculer la precision : correct / (correct + wrong).
  correct_answers INT NOT NULL DEFAULT 0,

  -- --- NOMBRE DE MAUVAISES REPONSES ---
  -- Inclut les timeouts (questions sans reponse dans le temps imparti).
  wrong_answers INT NOT NULL DEFAULT 0,

  -- --- NOMBRE TOTAL DE QUESTIONS DE LA PARTIE ---
  -- Techniquement deductible depuis correct_answers + wrong_answers,
  -- mais stocke explicitement pour simplifier les requetes UI :
  --   - "6 / 8 bonnes reponses" sans avoir a additionner
  --   - calcul direct du taux de completion
  -- Correspond a LevelConfig.questions au moment ou la partie a ete jouee.
  -- Pratique aussi si plus tard on autorise l'abandon en cours : dans
  -- ce cas correct + wrong < questions_total, information utile.
  questions_total INT NOT NULL DEFAULT 0,

  -- --- PLUS LONGUE SERIE DE BONNES REPONSES CONSECUTIVES ---
  -- Le "streak" maximal atteint pendant la partie.
  -- Utile pour afficher un badge "Meilleur combo : 7".
  -- Utile aussi pour les analytics de difficulte.
  max_streak INT NOT NULL DEFAULT 0,

  -- --- DUREE DE LA PARTIE EN SECONDES ---
  -- Temps passe reellement dans la partie (pause exclue cote app).
  -- Permet de calculer le temps moyen par question, detecter les
  -- sessions anormalement longues (probablement pause de l'app).
  duration_seconds INT NOT NULL DEFAULT 0,

  -- --- LA PARTIE A-T-ELLE ETE REUSSIE ? ---
  -- TRUE si le joueur a atteint le seuil de bonnes reponses pour
  -- valider le niveau, FALSE sinon.
  -- Permet de filtrer rapidement "parties reussies vs echouees"
  -- sans avoir a recalculer le seuil pour chaque session.
  passed BOOLEAN NOT NULL DEFAULT FALSE,

  -- --- ETOILES OBTENUES ---
  -- Entre 0 et 3 etoiles, calcule cote client en fonction de
  -- l'accuracy (cf. t_game_result_page.dart:72-76) :
  --   - 0 etoile  : partie echouee
  --   - 1 etoile  : accuracy < 70%
  --   - 2 etoiles : accuracy entre 70% et 89%
  --   - 3 etoiles : accuracy >= 90%
  -- Stocke ici pour affichage direct dans l'historique sans recalcul,
  -- et pour figer la regle au moment ou la partie a ete jouee
  -- (si on fait evoluer la regle plus tard, les anciennes sessions
  -- gardent leur note d'origine).
  stars_earned INT NOT NULL DEFAULT 0,

  -- --- DATE ET HEURE DE LA PARTIE ---
  -- Remplie automatiquement au moment de l'INSERT.
  -- TIMESTAMPTZ (with time zone) : stocke en UTC, reconverti
  -- selon le fuseau horaire du client. Indispensable pour une
  -- app utilisee dans plusieurs fuseaux.
  -- Utilisee pour trier "dernieres sessions" par ordre decroissant.
  played_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- --- CONTRAINTES DE COHERENCE ---
  -- Ces CHECKs bloquent les INSERTs avec des valeurs aberrantes
  -- au niveau de la base (derniere ligne de defense).
  -- Meme si le code client a un bug, la BDD reste coherente.
  CHECK (level >= 1),
  CHECK (score_gained >= 0),
  CHECK (correct_answers >= 0),
  CHECK (wrong_answers >= 0),
  CHECK (questions_total >= 0),
  CHECK (max_streak >= 0),
  CHECK (duration_seconds >= 0),
  -- stars_earned : contraint entre 0 et 3 (cf. regle d'affichage).
  CHECK (stars_earned BETWEEN 0 AND 3),
  -- Coherence : la somme bonnes+mauvaises ne peut pas depasser le total.
  -- Protege contre un bug cote client qui enverrait des valeurs aberrantes.
  CHECK (correct_answers + wrong_answers <= questions_total)
);


-- =============================================================
-- INDEX : performance des requetes "historique"
-- =============================================================
-- La requete la plus frequente sera :
--   SELECT * FROM user_sessions
--   WHERE user_id = ? AND game_id = ?
--   ORDER BY played_at DESC
--   LIMIT 5;
--
-- Cet index couvre exactement ce cas :
--   - Filtrage par (user_id, game_id) : les 2 premieres colonnes
--   - Tri par played_at DESC : la 3eme colonne
-- PostgreSQL peut utiliser l'index pour les 3 a la fois.
--
-- SANS cet index, avec 10 000 sessions en BDD, la requete ferait
-- un "sequential scan" (lecture de toutes les lignes).
-- AVEC cet index, elle trouve les 5 dernieres sessions en O(log n).
-- =============================================================
CREATE INDEX idx_sessions_user_game_date
  ON user_sessions(user_id, game_id, played_at DESC);


-- =============================================================
-- INDEX : statistiques par niveau
-- =============================================================
-- Pour repondre a "combien de fois ai-je joue le niveau 5 ?"
-- ou "meilleur score du niveau 3".
--
-- Optionnel mais peu couteux, et evite un scan complet quand on
-- fera des analytics profil ("progression par niveau").
-- =============================================================
CREATE INDEX idx_sessions_user_game_level
  ON user_sessions(user_id, game_id, level);


-- =============================================================
-- RLS : Row Level Security
-- =============================================================
-- Active la protection au niveau ligne. Sans cela, N'IMPORTE QUEL
-- utilisateur connecte pourrait lire les sessions des autres.
--
-- Par defaut, l'activation de RLS BLOQUE tout acces.
-- On doit ensuite creer des policies explicites pour autoriser.
-- =============================================================
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;


-- =============================================================
-- POLICY : SELECT (lecture)
-- =============================================================
-- L'utilisateur authentifie ne peut lire QUE ses propres sessions.
-- "auth.uid()" : fonction Supabase qui retourne l'UUID de
-- l'utilisateur actuellement connecte (extrait du JWT).
-- USING : condition d'acces pour les operations de lecture.
-- =============================================================
CREATE POLICY sessions_select_own ON user_sessions
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());


-- =============================================================
-- POLICY : INSERT (creation d'une session)
-- =============================================================
-- L'utilisateur peut inserer une session UNIQUEMENT si user_id
-- correspond a son propre auth.uid().
--
-- Sans cette contrainte, un attaquant pourrait inserer des
-- sessions au nom d'autres joueurs (pollution de leur historique).
-- WITH CHECK : condition appliquee lors de l'INSERT (et UPDATE).
-- =============================================================
CREATE POLICY sessions_insert_own ON user_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());


-- =============================================================
-- PAS DE POLICY UPDATE / DELETE
-- =============================================================
-- Volontairement : l'historique est en lecture seule cote user.
-- Une session une fois jouee ne doit pas etre modifiee ni effacee
-- (integrite de l'historique et des statistiques).
--
-- Seul l'admin (via la service role key, qui bypasse RLS) peut
-- faire des UPDATE/DELETE sur ces lignes, pour le support ou RGPD.
-- =============================================================


-- =============================================================
-- VERIFICATION : la table est creee et accessible
-- =============================================================
-- On compte les lignes juste apres creation (devrait retourner 0).
-- Utile pour confirmer que la migration s'est bien executee.
-- =============================================================
SELECT 'user_sessions' AS table_created, COUNT(*) AS rows FROM user_sessions;
