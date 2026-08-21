# ok_trialgo_backend

Backend FastAPI pour TRIALGO : auth admin + joueur, gestion des jeux, cartes (avec stockage S3/MinIO), fusions (graphe injectif), gameplay (sessions + scoring + leaderboard) et notifications email (Brevo).

## Stack

| Composant | Technologie |
|---|---|
| API | FastAPI 0.115 + Uvicorn |
| ORM | SQLAlchemy 2.0 async + asyncpg |
| Migrations | Alembic |
| Auth | JWT (python-jose) + bcrypt |
| DB | Postgres 16 |
| Stockage cartes | MinIO (S3-compatible) ou filesystem local |
| Email | Brevo API REST (via httpx async) + Jinja2 templates |
| Validation | Pydantic v2 |

## Demarrage (developpement local)

### 1. Pre-requis

- Docker + Docker Compose v2
- Make / curl (optionnel pour les tests rapides)

### 2. Configuration

```bash
cd ok_trialgo_backend
cp .env.example .env
# (editer .env : changer JWT_SECRET, mots de passe Postgres/MinIO)
```

Generer un secret JWT solide :
```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

### 3. Lancer la stack

```bash
docker compose up -d --build
```

3 services demarrent :
- **postgres** : `localhost:5432`
- **minio** : `localhost:9000` (API S3) et `localhost:9001` (console web)
- **api** : `http://localhost:8000`

Verifier :
```bash
curl http://localhost:8000/healthz
# {"status":"ok"}
```

OpenAPI auto : `http://localhost:8000/docs`

### 4. Appliquer les migrations

```bash
docker compose exec api alembic upgrade head
```

### 5. Creer le premier admin

Le PREMIER `POST /api/auth/register` cree automatiquement un admin (bootstrap). Les comptes suivants sont des users non-admin.

```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@trialgo.io","password":"change_me_now_8chars"}'
```

Login :
```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@trialgo.io","password":"change_me_now_8chars"}'
```

Recupere `access_token` -> mettre dans `Authorization: Bearer <token>` pour toute requete protegee.

### 6. Smoke test complet

```bash
TOKEN="<paste-token-ici>"

# Creer un jeu
curl -X POST http://localhost:8000/api/games \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"smoke","theme":"savane"}'

# Uploader une carte (image)
curl -X POST http://localhost:8000/api/games/<game-uuid>/cards \
  -H "Authorization: Bearer $TOKEN" \
  -F "label=Lion" \
  -F "card_type=emettrice" \
  -F "file=@/path/to/lion.jpg"

# Lister les cartes
curl http://localhost:8000/api/games/<game-uuid>/cards
```

## Endpoints

Vue graphique complete : `docs/endpoints_overview.jpg` (16 sections, ~50 endpoints). Flux email : `docs/mail_flows.jpg`.

Le backend couvre maintenant l'**app admin** (`ok_trialgo_admin`) ET l'**app joueur** (`trialgo/`), avec portage complet des concepts Supabase (activation_codes, user_games, user_sessions, user_unlocked_cards, user_played_nodes, stars wallet, verify_collective_trio).

### Auth
| Methode | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/register` | - | Cree compte (1er = admin), envoie mail welcome+confirm, auto-login |
| POST | `/api/auth/login` | - | Retourne (access, refresh) |
| POST | `/api/auth/refresh` | refresh JWT | Rafraichit l'access |
| GET | `/api/auth/me` | user | Profil courant + email_confirmed_at |
| POST | `/api/auth/confirm-email` | - | Consomme token + envoie mail welcome final |
| POST | `/api/auth/resend-confirmation` | - | Renvoie un mail confirm (anti-enum 200) |
| POST | `/api/auth/forgot-password` | - | Envoie mail reset (anti-enum 200) |
| POST | `/api/auth/reset-password` | - | Change mdp + mail notif securite |

### Public (no auth) - vitrine joueur
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/public/games` | - | Liste games is_active=true |
| GET | `/api/public/games/{id}` | - | Detail game actif |
| GET | `/api/public/games/{id}/cards` | - | Cartes (sans card_type leak) |

### Games (admin + hybrid)
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/games` | hybrid | Admin: tous ; autre: actifs uniquement |
| POST | `/api/games` | admin | Cree un jeu |
| GET | `/api/games/{id}` | hybrid | Idem hybrid sur is_active |
| PATCH | `/api/games/{id}` | admin | Update partial |
| DELETE | `/api/games/{id}` | admin | Supprime + cascade |

### Cards
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/games/{gid}/cards` | - | Liste cartes + image_url |
| POST | `/api/games/{gid}/cards` | admin | Multipart : label + type + file |
| PATCH | `/api/cards/{id}` | admin | Update label/type |
| DELETE | `/api/cards/{id}` | admin | Supprime carte + fichier |
| GET | `/api/cards/file/{key:path}` | - | Sert le binaire (mode LOCAL) |

### Nodes - tous admin (revele les reponses du jeu)
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/games/{gid}/nodes` | admin | Liste fusions |
| GET | `/api/games/{gid}/nodes/next-index` | admin | MAX+1 (wizard admin) |
| POST | `/api/games/{gid}/nodes` | admin | Cree fusion + valide invariants |
| DELETE | `/api/nodes/{id}` | admin | Supprime + cascade descendants |
| POST | `/api/games/{gid}/nodes/analyze` | admin | Analyse 3 cartes (admin only) |

### Play (gameplay joueur)
| Methode | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/sessions` | user | Demarre une partie |
| GET | `/api/sessions/{sid}` | user | Etat courant (score + trios_found) |
| POST | `/api/sessions/{sid}/attempts` | user | Soumet 3 cartes (ne revele pas la structure) |
| GET | `/api/sessions/{sid}/progress` | user | Trios decouverts uniquement |
| POST | `/api/sessions/{sid}/finish` | user | Termine + fige score |
| POST | `/api/sessions/{sid}/abandon` | user | Marque abandonnee |
| GET | `/api/games/{gid}/leaderboard` | user | Top scores (1 session/user finished) |
| GET | `/api/users/me/stats` | user | Agregats perso |
| GET | `/api/users/me/sessions` | user | Historique paginated |

### Admin users
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/admin/users` | admin | Liste paginated |
| GET | `/api/admin/users/{id}` | admin | Detail |
| POST | `/api/admin/users/{id}/promote` | admin | Toggle is_admin + mail notif |
| PATCH | `/api/admin/users/{id}` | admin | Active/desactive + mail si off |

### Profile joueur
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/me/profile` | user | username + avatar + selected_game + wallet etoiles |
| PATCH | `/api/me/profile` | user | Update username/avatar/selected_game |

### Activation codes
| Methode | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/codes/activate` | user | 5 cas : success + 4 erreurs reasoned (invalid/blocked/...) |
| GET | `/api/admin/codes` | admin | Liste paginated (filtre game_id) |
| POST | `/api/admin/codes` | admin | Cree un code |
| GET | `/api/admin/codes/{code}` | admin | Detail |
| PATCH | `/api/admin/codes/{code}` | admin | is_active / reset_assignment (SAV) |
| DELETE | `/api/admin/codes/{code}` | admin | Suppression |

### User Games (etat par jeu)
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/me/games` | user | Liste jeux actives (refill vies applique) |
| GET | `/api/me/games/{gid}` | user | Detail (level, score, vies + seconds_to_next) |

### Sessions historique
| Methode | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/me/sessions` | user | INSERT partie + UPDATE total_score/level/lives |
| GET | `/api/me/sessions` | user | Historique paginated (filtre game_id) |

### Deck (galerie)
| Methode | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/me/unlocked-cards` | user | Unlock une carte (idempotent) |
| GET | `/api/me/unlocked-cards?game_id=...` | user | Deck du jeu (label + image_url) |

### Played nodes (anti-doublon)
| Methode | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/me/played-nodes` | user | Mark tracking_key (idempotent) |
| GET | `/api/me/played-nodes?game_id=...` | user | Liste tracking_keys jouees |
| DELETE | `/api/me/played-nodes?game_id=...` | user | Reset pour ce jeu |

### Stars (wallet etoiles)
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/me/stars` | user | Wallet apres regen (1 etoile / 5min) |
| POST | `/api/me/stars/exchange-for-life` | user | 10 etoiles → 1 vie (atomique) |

### Collective (mode anim)
| Methode | Path | Auth | Description |
|---|---|---|---|
| POST | `/api/games/{gid}/verify-collective` | user | Verifie un node_index + resout labels |

### Leaderboard + Stats
| Methode | Path | Auth | Description |
|---|---|---|---|
| GET | `/api/games/{gid}/leaderboard` | user | Top users sur user_games.total_score |
| GET | `/api/me/stats` | user | Agregats perso |

## Scoring (gameplay joueur)

| Evenement | Delta |
|---|---|
| Trio correct (1ere decouverte) | +100 pts |
| Trio correct deja decouvert | 0 pt (anti-grind) |
| Tentative ratee | -5 pts (plancher 0) |
| Bonus completion 100% | +500 pts (one-shot) |

Le matching utilise le **raisonnement de similarite suivant l'arbre** :  pour chaque node, on calcule son triplet effectif `{ingredient_a_effectif, cable, receptrice}` (avec deduction depuis le parent si chainage) et on compare au set des 3 cartes soumises sans ordre.

## Configuration Brevo (emails)

1. Compte Brevo : `https://app.brevo.com` -> Account -> SMTP & API -> API Keys -> create v3 key.
2. Verifier un sender : `Senders & IP` -> ajouter `noreply@trialgo.app` (DNS DKIM recommande).
3. Coller la cle dans `.env` :
   ```
   BREVO_API_KEY=xkeysib-...
   BREVO_SENDER_EMAIL=noreply@trialgo.app
   BREVO_SENDER_NAME=TRIALGO
   APP_FRONTEND_URL=https://trialgo.app
   ```
4. Si `BREVO_API_KEY` est vide : mode **DRY_RUN** (log seulement). Utile en dev sans cle.

8 templates Jinja2 dans `app/mail/templates/` :
`welcome_confirm`, `welcome`, `password_reset`, `password_changed`, `session_summary`, `new_game`, `admin_promoted`, `account_deactivated`.

## Architecture stockage cartes

Deux backends interchangeables via `STORAGE_BACKEND` env var :

- `local` : ecrit dans `LOCAL_STORAGE_DIR` (filesystem) ; sert via FastAPI
- `s3` : MinIO/S3 (production-ready, scale horizontal)

Le code repository ne connait jamais l'implementation : il manipule un `object_key` opaque. Migration `local -> s3` = changer la config + recopier les fichiers.

Bucket MinIO en dev :
- Cree automatiquement au demarrage (service `create_bucket` du compose)
- Policy `anonymous download` activee (cartes accessibles en GET sans auth)
- Mutations limitees aux clients ayant la cle (API uniquement)

## Tests

```bash
docker compose exec api pytest
```

(suite a venir : auth + games + cards + analyzer)

## Migrations

### Creer une nouvelle revision

```bash
docker compose exec api alembic revision -m "ajoute table X" --autogenerate
docker compose exec api alembic upgrade head
```

### Downgrade

```bash
docker compose exec api alembic downgrade -1
```

## Deploiement serveur

Le compose est dimensionne pour le dev. Pour la prod :

1. Build l'image API : `docker build -t trialgo-api:latest .`
2. Pousser sur ton registry (Docker Hub, GHCR, ECR)
3. Cote serveur : compose simplifie avec
   - Postgres managee (RDS, Cloud SQL) au lieu du service postgres
   - MinIO standalone OU S3/R2 managee
   - Reverse proxy (Caddy, Traefik) devant l'API pour HTTPS + CORS
4. Variables d'env : injecter via secrets manager (jamais en `.env` sur disque)
5. `alembic upgrade head` dans le hook de deploiement

## Structure

```
ok_trialgo_backend/
├── app/
│   ├── main.py              # FastAPI factory + include_router
│   ├── config.py            # Settings (.env)
│   ├── db.py                # SQLAlchemy async session
│   ├── auth/                # users + JWT + register/login + confirm/reset
│   ├── games/               # CRUD jeux (admin + hybrid)
│   ├── cards/               # CRUD cartes + upload + image processing
│   ├── nodes/               # CRUD fusions + analyzer (admin only)
│   ├── play/                # Sessions + attempts + leaderboard + stats
│   ├── public/              # Vitrine joueur (no auth)
│   ├── admin_users/         # Gestion comptes (list/promote/deactivate)
│   ├── mail/                # Brevo client + templates Jinja2 + tokens
│   │   └── templates/       # 8 templates HTML (welcome, reset, ...)
│   └── storage/             # CardStorage (Local / S3)
├── alembic/
│   └── versions/
│       ├── 0001_initial.py  # users, games, cards, nodes
│       ├── 0002_play.py     # game_sessions, session_attempts
│       └── 0003_email.py    # email_tokens, email_preferences, users.email_confirmed_at
├── docs/
│   ├── endpoints_overview.jpg
│   ├── mail_flows.jpg
│   ├── upload_flow.jpg
│   ├── retrieval_flow.jpg
│   ├── gen_endpoints_overview.py
│   ├── gen_mail_flows.py
│   └── gen_flow_diagrams.py
├── docker-compose.yml
├── Dockerfile
├── pyproject.toml
├── .env.example
└── README.md
```
