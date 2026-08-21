# CLAUDE.md — TRIALGO

Guide de travail pour toute session sur ce dépôt. À lire avant de modifier quoi que ce soit.

---

## 1. Ce qu'est TRIALGO

Jeu d'observation visuelle. Relation atomique entre trois cartes-images :

```
Émettrice  +  Câble  =  Réceptrice        (E + C = R)
```

- **E** donne la forme dominante, **C** applique une transformation visuelle, **R** est le résultat.
- Une carte est **neutre** : son rôle dépend de sa position dans un nœud, jamais d'un type figé.
- Un **nœud** = un trio validé par l'admin. C'est l'unité atomique du jeu.
- **Chaînage** : la réceptrice d'un nœud peut être l'émettrice du suivant (`N2.E = N1.R`).

### Distances D1 → D5

Pour une chaîne de `k` nœuds, les éléments disponibles sont `{E1} ∪ {C1..Ck} ∪ {R1..Rk}`, soit `2k+1`.

Un trio `T` est **valide en D_k** ssi :
1. `T ⊂ Elements(C_k)`
2. `|T| = 3`
3. `R_k ∈ T` — il contient toujours la réceptrice finale
4. `T` n'est un nœud natif d'aucun `N_j` de la chaîne

D'où `MaxTrios(D_k) = C(2k,2) − 1` : **D2→5, D3→14, D4→27, D5→44**.

Documents de référence (ne pas les dupliquer, les lire) :
- `trialgo/docs/TRIALGO_CORE.md` — la source de vérité fonctionnelle et mathématique
- `architecture_recap.md`, `diagramme_classes.md`, `workflow_cartes.md`
- `LIVRE_TRIALGO_CHAPITRE_*.md` — la version narrative/pédagogique

---

## 2. Les quatre briques du dépôt

| Dossier | Rôle | Statut |
|---|---|---|
| `ok_trialgo_backend/` | API FastAPI + Postgres + MinIO | **Brique centrale actuelle** |
| `ok_trialgo_admin/` | Studio admin Flutter (création des jeux/cartes/trios) | Actif, branché FastAPI |
| `trialgo/` | App joueur Flutter | Actif, **migration Supabase → FastAPI en cours** |
| `trialgo_dashboard/`, `trialgo_admin/`, `point_sauvegarde1/` | Legacy | **Ne pas modifier. À supprimer.** |

Le dossier `trialgo/supabase/migrations/` est l'ancien schéma Supabase — historique, remplacé par Alembic côté backend.

---

## 3. Backend — `ok_trialgo_backend/`

FastAPI 0.115 · SQLAlchemy 2.0 async + asyncpg · Postgres 16 · Alembic · JWT (python-jose + bcrypt) · MinIO/S3 · Brevo (emails) · Pydantic v2.

### Lancer en dev

```bash
cd ok_trialgo_backend
cp .env.example .env          # puis éditer JWT_SECRET et les mots de passe
docker compose up -d --build
docker compose exec api alembic upgrade head
curl http://localhost:8000/healthz     # {"status":"ok"}
```

OpenAPI : `http://localhost:8000/docs`. Console MinIO : `http://localhost:9001`.

⚠️ **Ports par défaut : 8000, 9000, 9001, 5432.** Sur cette machine ils sont souvent déjà pris
par d'autres stacks. Vérifier avec `ss -ltn` avant de lancer, et décaler via un
`docker-compose.override.yml` en utilisant `ports: !override [...]` (une simple redéfinition de
`ports:` **fusionne** les listes au lieu de les remplacer, et le bind échoue).

### Bootstrap admin

Le **premier** `POST /api/auth/register` crée un admin. Les suivants sont des users normaux.
La réponse de `register` imbrique les jetons sous `tokens` (`{user, tokens:{access_token, refresh_token}}`)
alors que `login` et `refresh` les renvoient **à plat**. Ne pas confondre les deux formes.

### Modules `app/`

`auth` · `games` · `cards` (+`image`) · `nodes` (+`analyzer`) · `public` · `admin_users` ·
`codes` · `user_games` (+`refill` vies) · `sessions_history` · `unlocked_cards` ·
`played_nodes` · `stars` (+`regen`) · `collective` · `leaderboard` · `mail` · `storage`.

Il n'y a **pas** de module `app/play/` : la migration `0004_reset_play_extend_users` a supprimé
`game_sessions`/`session_attempts` (modèle de gameplay abandonné). Le vrai gameplay passe par
`user_games` + `sessions_history` (`/api/me/sessions`). La section « Play » du README backend
est obsolète sur ce point.

### Stockage des cartes

L'abstraction `CardStorage` (`app/storage/base.py`) a deux implémentations, choisies par
`STORAGE_BACKEND` :

- `local` → filesystem, servi par `GET /api/cards/file/{key}` (protégé contre le path traversal)
- `s3` → MinIO/AWS/R2 via aioboto3, URL directe vers le bucket

Le reste du code ne manipule qu'un `object_key` opaque. Layout : `<game_id>/<uuid>.jpg`.

Pipeline d'upload (`POST /api/games/{gid}/cards`, multipart) :
1. lecture bornée à `MAX_UPLOAD_BYTES` → 413 au-delà
2. `validate_and_process` : MIME réel par **magic bytes** (le `Content-Type` client n'est pas
   cru), conversion RGB, EXIF supprimé, resize `IMAGE_MAX_DIMENSION`, ré-encodage JPEG q85 → 400 si invalide
3. upload storage
4. INSERT DB ; **si l'INSERT échoue, le fichier est supprimé** (transaction logique)

Au DELETE, l'ordre est inverse : DB d'abord, puis fichier (un orphelin vaut mieux qu'une carte fantôme).

### Contrainte structurante en base

Sur `nodes` : `(emettrice_id IS NULL) = (parent_node_id IS NOT NULL)`.
Un nœud est **soit** une racine avec émettrice explicite, **soit** un enfant qui hérite
l'émettrice de son parent. Jamais les deux, jamais aucun.

---

## 4. Apps Flutter

Même architecture dans les deux : `core/` · `domain/` (entities, repositories, usecases) ·
`data/` (models, datasources, repositories impl) · `presentation/`. État via **Riverpod**.

### Le commutateur de backend

Les deux apps ont un `lib/core/api/api_config.dart` :

```dart
enum ApiMode { fake, supabase, fastapi }   // 'fake' seulement côté admin
static const ApiMode mode = ApiMode.fastapi;
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');
```

`ApiConfig.baseUrl` est la **source unique de vérité** : aucun datasource ne doit contenir
d'URL en dur. Le code est en dual-mode (`if (ApiConfig.isFastApi) … else …`) pour garder le
chemin Supabase comme repli tant que la bascule n'est pas validée.

`DioClient` (les deux apps) : intercepteur qui injecte `Authorization: Bearer`, et sur 401
tente un `/api/auth/refresh` puis rejoue la requête. `extra: {'noAuth': true}` pour les
endpoints publics, `{'noRetry': true}` pour couper la boucle de refresh.

### Lancer

```bash
# App joueur — entrypoint NON standard
cd trialgo && flutter run -t lib/main_wireframe.dart

# Studio admin
cd ok_trialgo_admin && flutter run

# Avec un backend distant
flutter run --dart-define=API_BASE_URL=https://api.trialgo.io
```

`flutter analyze` doit rester propre (seuls des `info` de lint sont tolérés).

### App joueur — points d'attention

- Le gameplay est **côté client** : `graph_sync_service` télécharge cartes + nœuds, puis
  `GenerateGameQuestionUseCase` fabrique les questions localement à partir de `GraphCardEntity`.
  Conséquence assumée : `GET /api/games/{gid}/nodes` est ouvert à tout utilisateur authentifié
  (il révèle les réponses). Ne pas le « corriger » en admin-only sans repenser le gameplay.
- `GraphCardEntity.imageUrl` accepte déjà une URL absolue (`startsWith('http')`) et ne
  reconstruit un préfixe Supabase que pour un chemin relatif.
- **Supabase n'est plus initialisé au démarrage** en mode `fastapi` : `main()` appelle
  `initSupabaseSiNecessaire()`, qui ne fait rien hors du mode `supabase`. Le getter global
  `supabase` lève alors une `StateError` explicite — l'atteindre signale un chemin non migré,
  pas une situation normale. `test/demarrage_sans_supabase_test.dart` verrouille ce contrat.
- L'identité de l'utilisateur connecté passe par `SessionUtilisateur` (`lib/core/session/`),
  qui répond dans les deux modes : cache mémoire alimenté par `TAuthGate` et `TAuthPage` en
  `fastapi`, délégation au SDK en `supabase`. Tout besoin **synchrone** d'identité
  (`AdminConstants.isAdmin()`, clé d'onboarding) doit passer par lui, jamais par
  `supabase.auth.currentUser`.
- `t_mock_data.dart` sert de jeu de données de démonstration (`picsum.photos`) — ce n'est pas
  du code mort, plusieurs écrans wireframe s'appuient dessus.

---

## 5. Conventions du projet

- **Tout est commenté en détail, en français, style livre pédagogique.** Chaque fichier commence
  par un bandeau `FICHIER / ROLE`, et les blocs non triviaux expliquent le *pourquoi*, pas
  seulement le *quoi*. Respecter cette densité : c'est une contrainte explicite du projet, pas
  du bruit.
- Le code Python et les commentaires Dart sont écrits **sans accents** (héritage de contraintes
  d'encodage). Les chaînes destinées à l'utilisateur final, elles, sont accentuées normalement.
- Vérifier soi-même dans le code/la config avant de poser une question à l'utilisateur.

---

## 6. Déploiement

### Topologie retenue

Domaine `mixalgo.com` :

| Hôte | Sert | Servi par |
|---|---|---|
| `mixalgo.com` | vitrine | hors de ce dépôt |
| `api.mixalgo.com` | API FastAPI | Caddy → `api:8000` |
| `api.mixalgo.com/files/*` | images des cartes | Caddy → `minio:9000` (préfixe retiré) |
| `dashboard.mixalgo.com` | studio admin (Flutter web) | Caddy → `/srv/dashboard` |

Les images passent par un **chemin** du domaine API plutôt que par un sous-domaine dédié :
un enregistrement DNS et un certificat de moins. Aucune collision possible, l'API n'expose que
`/api/*`, `/healthz`, `/docs` et `/openapi.json`. Pour basculer plus tard vers
`files.mixalgo.com`, une seule variable change (`S3_PUBLIC_ENDPOINT_URL`) plus le bloc Caddy.

### Fichiers concernés

- `ok_trialgo_backend/docker-compose.prod.yml` — Postgres et MinIO **sans port publié**,
  Caddy seul exposé sur 80/443
- `ok_trialgo_backend/docker/Caddyfile` — TLS automatique, routage, en-têtes de sécurité
- `ok_trialgo_backend/.env.production.example` — gabarit renseigné pour `mixalgo.com`
- `ok_trialgo_backend/app/core/startup_checks.py` — contrôles au boot

### Séquence

```bash
# 1. DNS : api.mixalgo.com et dashboard.mixalgo.com → IP du serveur, ports 80/443 ouverts

# 2. Backend
cd ok_trialgo_backend
cp .env.production.example .env        # renseigner les <chevrons> restants
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec api alembic upgrade head
docker compose -f docker-compose.prod.yml logs api | grep -A20 'CONFIGURATION INCOMPLETE'
#    ^ doit ne rien renvoyer. Sinon, corriger le .env et redémarrer.

# 3. Premier admin (le tout premier register devient admin)
curl -X POST https://api.mixalgo.com/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"...","password":"..."}'

# 4. Studio admin en web
cd ok_trialgo_admin && flutter build web --release
cp -r build/web/* ../ok_trialgo_backend/docker/dashboard/

# 5. APK release (l'URL de prod est le défaut en release, --dart-define facultatif)
cd trialgo && flutter build appbundle --release
cd ok_trialgo_admin && flutter build apk --release
```

### Contrôles au démarrage

`app/core/startup_checks.py` inspecte la configuration au boot et journalise un bloc
`CRITICAL` par valeur restée en mode développement : secrets d'exemple, URL locales,
CORS purement local, Brevo absent. **Ces contrôles avertissent, ils ne bloquent pas** —
bloquer casserait le dev local et la CI. Lire les logs du premier démarrage.

Le piège que ces contrôles adressent : `S3_PUBLIC_ENDPOINT_URL` est recopiée telle quelle dans
chaque `image_url` renvoyée aux clients. Restée sur `localhost`, l'API répond 200 partout,
les logs serveur sont vides, et toutes les cartes s'affichent cassées sur mobile.

### Signature Android

Les deux apps lisent `android/key.properties` (hors dépôt, voir `key.properties.example`).
Si le fichier est absent, le build retombe sur la clé de debug **avec un avertissement Gradle** —
pratique pour un `flutter run --release` local, mais ce binaire n'est pas publiable.
Perdre le keystore ou son mot de passe interdit définitivement toute mise à jour Play Store :
en garder une sauvegarde chiffrée hors du poste de développement.

---

## 7. Alignement des flux (fait)

Les endpoints suivants existaient sans aucun appelant. Ils sont maintenant branchés :

| Endpoint | Consommateur | Détail |
|---|---|---|
| `POST/GET /api/me/played-nodes` | app joueur | `PlayedNodesTracker` (data/services). Amorçage dans `TGraphLoadingPage` via `seedPlayedKeys`, notification via le callback `onNodePlayed` du usecase |
| `POST /api/games/{gid}/verify-collective` | app joueur | `CollectiveVerifier` (data/services). Serveur d'abord, repli local en cas de panne |
| `GET/POST/PATCH/DELETE /api/admin/codes` | studio admin | `CodesPage` + génération par lot |
| `GET/POST/PATCH /api/admin/users` | studio admin | `UsersPage` |

**Le tracking anti-doublon est devenu une préférence, plus une condition d'arrêt.**
Avant, une table épuisée faisait renvoyer `null` à `GenerateGameQuestionUseCase`, ce que
`t_game_page` traduit par une fin de partie sèche. Les clés étant désormais persistées et
relues au démarrage, l'épuisement serait devenu définitif — le niveau ne serait plus jamais
jouable. Une table épuisée repioche donc dans la table complète. `null` n'est renvoyé que
pour une table réellement vide.

**Les deux couches restent séparées.** `GenerateGameQuestionUseCase` et
`VerifyTrioCardsUseCase` sont dans `domain/` : ils ne connaissent ni Dio ni `ApiConfig`. Le
branchement passe par un callback injecté depuis `graph_provider`. C'est aussi ce qui rend
ces usecases testables sans faux client HTTP.

**Deep-link : `ApiConfig.linkDomain`.** Le host accepté pour un lien `https` est une
constante (`mixalgo.com`, surchargeable par `--dart-define=APP_LINK_DOMAIN`), pas une
dérivation de `baseUrl` — `baseUrl` vaut `10.0.2.2` en debug, d'où aucun domaine
exploitable. L'ancien test `host.contains('trialgo')` rejetait silencieusement tous les
liens de production.

**Manifeste Android.** Un `--` dans un commentaire XML est interdit par la spécification et
rendait `android/app/src/main/AndroidManifest.xml` impossible à parser : le build release
échouait sur `processReleaseMainManifest`. Corrigé, et la présence de `INTERNET` dans le
manifeste fusionné de release est vérifiée.

---

### Bugs trouves en integration et corriges

Le passage sur stack reelle a mis au jour trois defauts qu'aucune relecture n'avait vus.

**`POST /api/me/played-nodes` et `POST /api/me/unlocked-cards` repondaient 500 au rejeu**,
alors que les deux sont documentes comme idempotents. La cause n'etait pas le conflit UNIQUE,
correctement rattrape, mais le `await db.rollback()` du bloc `except` : il **expire tous les
objets de la session**, y compris le `user` injecte par la dependance. La ligne suivante lisait
`user.id`, declenchant un rechargement paresseux depuis un acces d'attribut synchrone, d'ou un
`MissingGreenlet` transforme en 500. Les deux routes utilisent desormais
`INSERT ... ON CONFLICT DO NOTHING` (PostgreSQL), ce que leur documentation promettait deja :
plus de commit en echec, donc plus de rollback, donc plus d'objet expire. Le mode de
defaillance disparait au lieu d'etre rattrape. Motif a surveiller ailleurs : **ne jamais lire
un attribut ORM apres un rollback** — capturer les valeurs avant.

**Le bucket MinIO exposait son inventaire a tout le monde.** `mc anonymous set download`, malgre
son nom, installe `s3:ListBucket` en plus de `s3:GetObject`. Un simple
`curl https://api.mixalgo.com/files/trialgo-cards/` renvoyait le XML de toutes les cles, de tous
les jeux — soit le catalogue complet des cartes, aspirable sans authentification. Remplace par
`docker/init-bucket.sh`, qui pose une politique explicite limitee a `s3:GetObject`. Les URL
connues fonctionnent toujours, l'inventaire repond 403. Les cles etant des UUID v4, elles ne se
devinent pas.

**Le manifeste Android etait invalide.** Un `--` dans un commentaire XML, interdit par la
specification : `flutter build apk --release` echouait sur `processReleaseMainManifest`.

### Durcissements

- Caddy ne transmet plus que `GET` et `HEAD` sur `/files/*` ; les autres methodes recoivent 405
  sans atteindre MinIO. La politique du bucket les refuse deja, mais elle se change par
  inadvertance.
- `startup_checks.py` detecte une barre oblique finale sur `S3_PUBLIC_ENDPOINT_URL` :
  `public_url()` concatene sans normaliser, et un double separateur donne des images en 404
  pendant que tout le reste fonctionne.

### Pages de rebond des courriels

`app/links/` sert deux pages HTML **hors du prefixe `/api`** (elles n'apparaissent donc pas
dans OpenAPI) :

| Page | Comportement |
|---|---|
| `GET /reset-password?token=` | Bascule vers `trialgo://reset-password?token=`, avec bouton manuel de repli. **Ne consomme pas le jeton** : un aspirateur de liens le brulerait avant le clic |
| `GET /confirm-email?token=` | **Consomme** le jeton et affiche le resultat. Confirmer ne demande aucune saisie, le clic *est* l'action |

Les deux liens des courriels sont desormais batis sur **`PUBLIC_BASE_URL`** et non plus sur
`APP_FRONTEND_URL` : ces pages sont servies par l'API, seule brique de la topologie capable
d'executer du code. Le studio est un binaire Flutter web sans routes serveur — y pointer menait
a sa page de connexion, et **la reinitialisation de mot de passe etait donc inutilisable sans
qu'aucune erreur ne le signale.** `APP_FRONTEND_URL` continue de servir aux liens de navigation
(classement, jeu), ce qui reste correct.

Le schema applicatif vient de `APP_DEEP_LINK_SCHEME` (defaut `trialgo`), a garder aligne avec
`deep_link_service.dart` et les manifestes.

En mode DRY-RUN (`BREVO_API_KEY` vide), `app/mail/client.py` journalise aussi les liens porteurs
de jeton — sans quoi ces deux parcours sont **intestables en local** : le courriel ne part pas et
la base ne stocke que le condensat du jeton. Ce branchement ne s'execute jamais en production.

### Stockage des jetons cote studio : pas de `flutter_secure_storage` sur le web

`TokenStorage` utilise `flutter_secure_storage` sur mobile (Keystore / Keychain, protection
reelle) et **`SharedPreferences` sur le web**. Deux raisons :

1. **Fiabilite** — les operations du plugin sur le web ne se terminaient pas toujours : ni
   resultat, ni erreur, la `Future` restait en attente. Le studio se figeait sur « Chargement de
   votre session », indefiniment, sans message et sans autre recours que vider le stockage du
   navigateur. **Constate sur le build web destine a `dashboard.mixalgo.com` : apres la premiere
   connexion, toute reprise de session etait impossible.**
2. **Fond** — sur le web ce chiffrement ne protege de rien : la cle est rangee dans le meme
   `localStorage`, a cote des valeurs. Toute faille XSS lit les deux. On payait en fiabilite une
   securite qui n'existait pas.

Toutes les operations sont bornees par un delai : lire un jeton est une commodite, jamais une
raison de figer l'application. `HttpAuthRepository` a par ailleurs recu un `catch` general —
sans lui, toute exception hors `DioException` laissait l'etat sur `loading` pour toujours.

### Ce qui a ete valide sur stack reelle

Auth (premier inscrit admin, jetons imbriques au register et a plat au login, refresh) ·
CRUD jeux · upload d'images (magic bytes, 413, 401, 403, EXIF retire, resize 1024, cache
immutable) · graphe (racine, chainage, XOR emettrice/parent) · analyzer · codes d'activation
(creation, doublon 409, activation joueur, reset SAV) · comptes (promotion, garde-fous dernier
admin) · played-nodes · verify-collective (emettrice heritee du parent) · sessions (vies
decrementees par le serveur) · etoiles · classement · endpoints publics ·
**routage Caddy complet, topologie de production**.

Et **le studio web pilote dans un navigateur reel** contre cette stack : connexion, reprise de
session apres rechargement, liste des jeux, ecran des codes (generation par lot de 5 codes
verifies en base), ecran des comptes (garde-fou « dernier admin actif » remonte tel quel par le
serveur), wizard, et affichage des images de cartes servies par MinIO.

Non exerce : **l'import de cartes par lot**. Le declencher ouvre le selecteur de fichiers natif,
qui bloque l'automatisation du navigateur. La chaine d'upload sous-jacente est prouvee par
ailleurs, et la deduction de libelle a ses tests unitaires.

---

## 8. Points ouverts

- Le paquet `supabase_flutter` reste une dépendance de `pubspec.yaml` : le mode `supabase`
  demeure disponible en repli. Il n'est simplement plus activé au démarrage. À retirer le jour
  où ce repli est abandonné.
- Écrans et méthodes **sans équivalent FastAPI**, neutralisés proprement plutôt que laissés à
  planter : `TAdminPage` (remplacé par le studio `ok_trialgo_admin` — son entrée est masquée
  dans `THomePage`) et `ProfileService.buyLives()` (aucun endpoint « score → vies » côté
  serveur ; retourne `false`, ce que l'appelant traite déjà comme un refus).
- Les 5 méthodes d'écriture de `GraphRepositoryImpl` (`insertCard`, `insertRootNode`,
  `insertChildNode`, `deleteNode`, `deleteCard`) sont **purement Supabase et sans aucun
  appelant** — `TAdminPage` écrivait en direct, pas via le repository. Elles restent
  uniquement parce qu'elles font partie du contrat `GraphRepository`. Les rebrancher exige
  de passer par les endpoints `/api/games/{id}/nodes`, qui valident les invariants du graphe.
- **Le lien de réinitialisation de mot de passe ne mène nulle part.** `mail/sender.py` le
  construit depuis `APP_FRONTEND_URL`, que `.env.production.example` fixe à
  `https://dashboard.mixalgo.com` — le studio admin, qui n'a aucune route `/reset-password`.
  Côté app joueur le host est désormais accepté, mais il faut encore **une page de rebond
  côté serveur** : `GET /reset-password` renvoyant un HTML qui bascule vers
  `trialgo://reset-password?token=...`, et `GET /confirm-email` qui consomme le jeton
  directement. Aucune page `/confirm-email` n'existe nulle part aujourd'hui.
- **La confirmation d'adresse n'est pas exigée** : `login` ne teste pas `email_confirmed_at`.
  À rendre explicite via un `REQUIRE_EMAIL_CONFIRMATION` plutôt que de le laisser implicite.
- **`POST /api/games/{gid}/nodes/analyze` est doublé** par `FusionAnalyzer` (Dart), utilisé
  par `fusion_analyzer_sheet`. Deux implémentations de la même règle métier, qui peuvent
  diverger.
- En mode `fastapi`, les filtres `distance_level`, `cable_category` et `is_active` sur les cartes
  sont **ignorés** : ces colonnes n'existent pas côté backend. `CardModel.fromJson` retombe sur
  `distanceLevel = 1`. La distance se déduit désormais du graphe de nœuds, pas de la carte.
- `GET /api/games/{id}/nodes` est ouvert à tout utilisateur authentifié et révèle les réponses.
  Conséquence assumée du gameplay client-side (voir §4). Ne pas « corriger » isolément.
- Aucun test automatisé sur le backend (`pytest` déclaré, suite non écrite).
- L'app joueur en Flutter web : `device_info_plus` n'y fournit pas d'identifiant stable, donc le
  binding « un code d'activation = un appareil » ne tient pas. Le studio admin en web, lui, est
  sans problème.
- `README.md` du backend : la section « Play » décrit des endpoints (`/api/sessions/...`) qui
  n'existent plus depuis la migration `0004`.

---

## 9. Git

Branche principale : `main`. Ne jamais committer les `*.apk` de la racine ni les gros
binaires (`.pdf`, `.jpeg` de travail) — ajouter un `.gitignore` avant tout commit large.
