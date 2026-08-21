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

## 7. Points ouverts

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

## 8. Git

Branche principale : `main`. Ne jamais committer les `*.apk` de la racine ni les gros
binaires (`.pdf`, `.jpeg` de travail) — ajouter un `.gitignore` avant tout commit large.
