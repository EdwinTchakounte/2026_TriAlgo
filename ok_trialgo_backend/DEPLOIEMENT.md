# Mise en ligne de TRIALGO — serveur vierge

Procédure complète, depuis une machine Ubuntu sur laquelle rien n'est installé,
jusqu'à une API et un studio joignables en HTTPS.

Cible retenue : `169.58.139.73`, qui héberge déjà d'autres sites derrière **nginx 1.24**.
TRIALGO s'y installe **à côté**, sans toucher à l'existant.

```
Internet ─ nginx (hôte, 443, TLS déjà en place)
             ├─ caseformations.com      → existant, on n'y touche pas
             ├─ api.mixalgo.com         → 127.0.0.1:8000   API FastAPI
             ├─ api.mixalgo.com/files/  → 127.0.0.1:9000   MinIO
             └─ dashboard.mixalgo.com   → /srv/dashboard   studio Flutter web
```

---

## 0. Avant de commencer

| Prérequis | État |
|---|---|
| `api.mixalgo.com` → IP du serveur | ✅ déjà fait |
| `dashboard.mixalgo.com` → IP du serveur | ⬜ **à créer chez le registrar** |
| Ports 80 et 443 ouverts | ✅ vérifié |
| Accès SSH | ⬜ à configurer |
| Une clé API Brevo | ⬜ à obtenir sur brevo.com |

Le DNS met de quelques minutes à quelques heures à se propager. Le créer **maintenant**,
avant tout le reste : certbot refusera d'émettre le certificat du studio tant que
`dashboard.mixalgo.com` ne résout pas.

Vérifier depuis votre poste :

```bash
getent hosts dashboard.mixalgo.com     # doit renvoyer l'IP du serveur
```

---

## 1. Accès SSH

Depuis **votre poste**, pas le serveur :

```bash
ssh-keygen -t ed25519 -C "trialgo-deploiement"    # si vous n'avez pas déjà une clé
ssh-copy-id root@169.58.139.73                    # ou l'utilisateur fourni par l'hébergeur
ssh root@169.58.139.73                            # doit entrer sans mot de passe
```

Une fois la connexion par clé confirmée — et **seulement** une fois confirmée, sinon vous
vous enfermez dehors — désactiver le mot de passe dans `/etc/ssh/sshd_config` :

```
PasswordAuthentication no
PermitRootLogin prohibit-password
```

```bash
sudo systemctl reload ssh
```

Gardez une seconde session ouverte pendant ce changement. Si quelque chose se passe mal,
c'est votre seule porte de sortie.

---

## 2. Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER      # puis se reconnecter pour que ça prenne effet
docker compose version             # doit répondre v2.x
```

---

## 3. Pare-feu

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
sudo ufw status
```

**Ce que ufw ne protège pas.** Docker écrit ses propres règles iptables, en amont de
celles de ufw. Un conteneur qui publie `8000:8000` est joignable depuis Internet **même
si ufw affiche `8000 DENY`** — le pare-feu ment, et rien ne le signale.

C'est pourquoi `docker-compose.nginx.yml` publie les ports en `127.0.0.1:8000:8000`.
Le préfixe d'interface est la seule protection réelle ici. Ne le retirez jamais
« pour tester ».

---

## 4. Récupérer le code

Le dépôt est **public** : aucun identifiant n'est nécessaire sur le serveur.

```bash
sudo mkdir -p /srv && cd /srv
git clone https://github.com/EdwinTchakounte/2026_TriAlgo.git trialgo
cd trialgo/ok_trialgo_backend
git checkout feat/backend-fastapi-et-preparation-deploiement
```

> Le dépôt étant public, **aucun secret ne doit jamais y être commité**. Le `.env` est
> dans `.gitignore` ; l'historique a été vérifié, il est propre. Un secret poussé une
> seule fois reste lisible dans l'historique pour toujours, même après suppression :
> il faut le considérer comme compromis et le régénérer.

---

## 5. Le fichier `.env`

```bash
cp .env.production.example .env
```

Générer les secrets — **en hexadécimal, pas en base64** :

```bash
openssl rand -hex 32      # JWT_SECRET
openssl rand -hex 24      # POSTGRES_PASSWORD
openssl rand -hex 24      # S3_SECRET_KEY
openssl rand -hex 12      # S3_ACCESS_KEY
```

**Pourquoi pas `base64`.** Le mot de passe Postgres est recopié *à l'intérieur d'une URL* :

```
DATABASE_URL=postgresql+asyncpg://trialgo:LE_MOT_DE_PASSE@postgres:5432/trialgo
```

`openssl rand -base64` produit régulièrement des `/`, `+` et `=`. Un `/` coupe l'URL au
milieu, un `@` en déplacerait l'hôte. L'erreur qui en résulte parle de connexion refusée
ou d'hôte introuvable — jamais du mot de passe. On cherche longtemps. L'hexadécimal n'a
que `0-9a-f` : rien à échapper.

Valeurs à renseigner :

| Variable | Valeur |
|---|---|
| `POSTGRES_PASSWORD` | le hex généré |
| `DATABASE_URL` | `postgresql+asyncpg://trialgo:<hex>@postgres:5432/trialgo` |
| `ALEMBIC_DATABASE_URL` | `postgresql://trialgo:<hex>@postgres:5432/trialgo` |
| `JWT_SECRET` | le hex généré |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | les hex générés |
| `BREVO_API_KEY` | votre clé Brevo |
| `TRUST_PROXY_HEADERS` | `true` |

**L'hôte de la base est `postgres`**, le nom du service Docker — pas `localhost`, qui
depuis le conteneur de l'API désigne l'API elle-même. Le gabarit indique `<hote-db>`
parce qu'il envisage aussi une base managée ; ici c'est le conteneur.

**`S3_PUBLIC_ENDPOINT_URL=https://api.mixalgo.com/files`**, sans barre oblique finale.
Cette valeur est recopiée telle quelle dans chaque `image_url` renvoyée aux clients.
Une barre en trop donne un double séparateur : toutes les images en 404 pendant que le
reste de l'API répond parfaitement. `startup_checks.py` le détecte au démarrage.

Puis mettre le fichier hors de portée :

```bash
chmod 600 .env
```

---

## 6. Démarrer la stack

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml up -d --build
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml exec api alembic upgrade head
```

**Lire les contrôles de démarrage.** Ils avertissent sans bloquer :

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml logs api | grep -A20 'CONFIGURATION INCOMPLETE'
```

Cette commande doit ne **rien** renvoyer. Sinon, corriger le `.env` puis :

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml up -d api
```

`up -d`, **jamais** `restart` : `restart` relance le processus dans le conteneur existant,
avec la configuration déjà résolue. Le `.env` contient la bonne valeur, l'API se comporte
comme si elle n'existait pas. Vérifier en cas de doute :

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml \
  exec api python -c "from app.config import settings; print(settings.TRUST_PROXY_HEADERS)"
```

Vérifier en local sur le serveur :

```bash
curl http://127.0.0.1:8000/healthz     # {"status":"ok"}
```

---

## 7. nginx et TLS

```bash
sudo cp docker/nginx/api.mixalgo.com.conf       /etc/nginx/sites-available/
sudo cp docker/nginx/dashboard.mixalgo.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/api.mixalgo.com.conf       /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/dashboard.mixalgo.com.conf /etc/nginx/sites-enabled/
sudo mkdir -p /srv/dashboard && echo ok | sudo tee /srv/dashboard/index.html
sudo nginx -t && sudo systemctl reload nginx
```

**Vérifier qu'aucun vhost existant ne capte déjà `api.mixalgo.com`.** Aujourd'hui ce
domaine répond 404 : c'est le vhost par défaut du serveur qui répond, faute de mieux.
Une fois le nôtre en place il prendra la main — mais si un `server_name _;` ou un
`default_server` le devance, il continuera de répondre à sa place.

```bash
sudo nginx -T | grep -n 'server_name'      # inventaire des vhosts
```

Puis les certificats :

```bash
sudo certbot --nginx -d api.mixalgo.com -d dashboard.mixalgo.com
```

certbot écrit lui-même les directives `ssl_*` et la redirection 80→443 dans les fichiers.
Ne pas les poser à la main : il les réécrirait au renouvellement.

---

## 8. Premier administrateur

Le **tout premier** compte inscrit devient admin. Les suivants sont des joueurs normaux.
À faire immédiatement après la mise en ligne — avant que quiconque d'autre puisse
s'inscrire.

```bash
curl -X POST https://api.mixalgo.com/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"vous@exemple.com","password":"..."}'
```

La réponse imbrique les jetons sous `tokens`. `login` et `refresh`, eux, les renvoient
à plat — ce n'est pas une incohérence à corriger, c'est le contrat existant.

---

## 9. Sauvegardes

**Avant d'avoir des données à perdre**, pas après.

```bash
cd /srv/trialgo/ok_trialgo_backend
sudo mkdir -p /var/backups/trialgo
TRIALGO_COMPOSE_FILE="docker-compose.prod.yml docker-compose.nginx.yml" ./scripts/backup.sh
```

Puis en cron (`sudo crontab -e`) :

```
15 3 * * * cd /srv/trialgo/ok_trialgo_backend && TRIALGO_COMPOSE_FILE="docker-compose.prod.yml docker-compose.nginx.yml" ./scripts/backup.sh >> /var/log/trialgo-backup.log 2>&1
```

Deux choses que le script ne fait pas et qu'il faut faire à la main :

1. **Sortir les sauvegardes de la machine.** Un dossier sur le serveur meurt avec le
   serveur. `rclone sync /var/backups/trialgo distant:trialgo` après le cron, ou un NAS.
2. **Sauvegarder le `.env`, chiffré, hors du serveur.** Le perdre ne détruit pas les
   données mais rend le volume Postgres inutilisable (mot de passe) et invalide tous les
   jetons émis. Même règle que le keystore Android.

Et **essayer une restauration une fois, à froid**, avant d'en avoir besoin :

```bash
TRIALGO_COMPOSE_FILE="docker-compose.prod.yml docker-compose.nginx.yml" \
  ./scripts/restore.sh          # liste ce qui est disponible
```

---

## 10. Studio admin

Depuis **votre poste** :

```bash
cd ok_trialgo_admin
flutter build web --release --dart-define=API_BASE_URL=https://api.mixalgo.com
rsync -a --delete build/web/ root@169.58.139.73:/srv/dashboard/
ssh root@169.58.139.73 'chown -R www-data:www-data /srv/dashboard'
```

---

## 11. Vérifications finales

```bash
curl https://api.mixalgo.com/healthz                          # {"status":"ok"}
curl -o /dev/null -w '%{http_code}\n' https://api.mixalgo.com/files/trialgo-cards/      # 403
curl -o /dev/null -w '%{http_code}\n' -X POST https://api.mixalgo.com/files/x           # 405
curl -o /dev/null -w '%{http_code}\n' https://dashboard.mixalgo.com/                    # 200
curl -sD - -o /dev/null https://api.mixalgo.com/healthz | grep -i strict-transport      # présent
```

Et le limiteur de débit, qui doit basculer en 429 à la 11ᵉ tentative :

```bash
for i in $(seq 1 12); do
  curl -s -o /dev/null -w "$i:%{http_code} " -X POST https://api.mixalgo.com/api/auth/login \
    -H 'Content-Type: application/json' -d '{"email":"x@x.fr","password":"faux"}'
done; echo
```

Puis, dans le studio : créer un jeu, téléverser une carte, vérifier qu'elle **s'affiche**.
C'est le test qui attrape une `S3_PUBLIC_ENDPOINT_URL` mal renseignée — l'API répond 200
partout, les journaux sont vides, et seules les images sont cassées.

---

## 12. Ce qui reste après

La mise en ligne ne rend pas le produit vendable pour autant.

- **Le contenu.** La base ne contient que 7 cartes et 2 nœuds, soit une chaîne de longueur
  2 : **D2 au maximum**. D3, D4 et D5 n'ont aucun contenu réel. Un joueur épuise ça en
  quelques minutes. C'est le vrai chantier.
- **Le keystore Android**, à générer et sauvegarder hors du poste avant toute publication.
  Le perdre interdit définitivement toute mise à jour Play Store.
- **Aucun paiement** n'est intégré : les codes d'activation se vendent hors du logiciel et
  se génèrent à la main dans le studio.
- **Aucun test automatisé côté backend.** La prochaine modification peut casser quelque
  chose sans que rien ne prévienne.
