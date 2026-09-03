# Suivi de déploiement MIXALGO

Feuille de route à cocher, adaptée au serveur `169.58.139.73`.
Chaque étape est numérotée : en cas de blocage, citez son numéro.

Ce document ne donne que **les commandes et le résultat attendu**. Le *pourquoi* de chaque
choix est dans [`DEPLOIEMENT_COMPLET.md`](DEPLOIEMENT_COMPLET.md), dont les sections sont
référencées en marge.

---

## État constaté sur le serveur

| Fait | Constaté le |
|---|---|
| nginx 1.24 sur l'hôte, ports 80 et 443, actif | vérifié |
| PostgreSQL sur l'hôte, `127.0.0.1:5432` et `172.17.0.1:5432` | vérifié |
| Docker actif, 4 conteneurs `caseformations` sur la boucle locale | vérifié |
| **Ports 8000, 9000 et 9001 libres** | vérifié, aucun décalage à faire |
| Utilisateur `mixalgo` créé (uid 1002), groupes `sudo` et `docker` | à finir, étape 1 |
| `main` à jour sur GitHub, commit `c27db85` | vérifié |

---

## Phase A. Le compte de déploiement

### 1. Poser le mot de passe manquant

`adduser` s'est terminé sans en définir un : les deux saisies ne correspondaient pas, et il a
poursuivi quand même. Sans mot de passe, `sudo` est inutilisable pour ce compte.

```bash
# en root
passwd mixalgo
passwd --status mixalgo      # 2e champ : P = défini (NP = aucun, L = verrouillé)
id mixalgo                   # doit lister sudo ET docker
```

- [ ] `passwd --status` affiche `P`
- [ ] `id` liste `sudo` et `docker`

### 2. Clé SSH, depuis votre poste

```bash
# sur VOTRE machine, pas le serveur
ssh-copy-id mixalgo@169.58.139.73
ssh mixalgo@169.58.139.73 'echo connexion OK'
```

- [ ] la connexion par clé fonctionne

> Si vous durcissez SSH (`PermitRootLogin no`, `PasswordAuthentication no`), **gardez votre
> session root ouverte** dans un second terminal jusqu'à ce que la connexion `mixalgo`
> fonctionne. Une erreur ici vous enferme dehors.

---

## Phase B. Le code

### 3. Reprendre le clone du bon côté

Le premier clone a été fait en root dans un dossier appartenant à `mixalgo`, d'où
`fatal: detected dubious ownership`. On repart proprement.

```bash
# en root
rm -rf /srv/trialgo
mkdir -p /srv/trialgo && chown mixalgo:mixalgo /srv/trialgo
su - mixalgo -c 'git clone https://github.com/EdwinTchakounte/2026_TriAlgo.git /srv/trialgo'
```

### 4. Vérifier qu'on a le bon contenu

```bash
su - mixalgo -c 'git -C /srv/trialgo log --oneline -1'
su - mixalgo -c 'ls /srv/trialgo/vitrine /srv/trialgo/ok_trialgo_backend/referentiels'
```

- [ ] le `git log` affiche `c27db85 merge: referentiel de jeu, vignettes, vitrine...`
- [ ] `vitrine/` et `referentiels/` existent

---

## Phase C. Configuration

**À partir d'ici, tout se fait en tant que `mixalgo`.**

### 5. Le fichier `.env`

```bash
ssh mixalgo@169.58.139.73
cd /srv/trialgo/ok_trialgo_backend
cp .env.production.example .env
chmod 600 .env
```

### 6. Générer les secrets, sur le serveur

Ne les faites transiter par aucune messagerie.

```bash
echo "JWT_SECRET=$(openssl rand -hex 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
echo "MINIO_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
```

### 7. Renseigner `.env`

```bash
nano .env
```

Les cinq valeurs qui cassent quelque chose **en silence** si elles sont fausses :

| Variable | Valeur exacte |
|---|---|
| `PUBLIC_BASE_URL` | `https://api.mixalgo.com` |
| `S3_PUBLIC_ENDPOINT_URL` | `https://api.mixalgo.com/files` **sans barre finale** |
| `CORS_ALLOWED_ORIGINS` | `https://dashboard.mixalgo.com,https://mixalgo.com` |
| `TRUST_PROXY_HEADERS` | `true` |
| `BREVO_API_KEY` | votre clé, sinon les courriels sont seulement journalisés |

- [ ] plus aucun `<chevron>` dans le fichier
- [ ] `S3_PUBLIC_ENDPOINT_URL` ne se termine pas par `/`

---

## Phase D. Le DNS

### 8. Quatre enregistrements A vers `169.58.139.73`

À créer **avant** certbot, chez votre registrar.

| Nom | Type | Valeur |
|---|---|---|
| `mixalgo.com` | A | `169.58.139.73` |
| `www.mixalgo.com` | A | `169.58.139.73` |
| `api.mixalgo.com` | A | `169.58.139.73` |
| `dashboard.mixalgo.com` | A | `169.58.139.73` |

```bash
dig +short mixalgo.com www.mixalgo.com api.mixalgo.com dashboard.mixalgo.com
```

- [ ] les quatre renvoient `169.58.139.73`

---

## Phase E. La stack

### 9. Créer l'alias qui allège tout le reste

```bash
cd /srv/trialgo/ok_trialgo_backend
echo "alias mix='docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml'" >> ~/.bashrc
source ~/.bashrc
```

### 10. Démarrer

```bash
mix up -d --build
mix ps
```

- [ ] `postgres`, `minio` et `api` sont `Up`
- [ ] `caddy` est **absent** (neutralisé par la surcouche nginx, c'est voulu)

### 11. Contrôler la configuration au démarrage

```bash
mix logs api | grep -A20 'CONFIGURATION INCOMPLETE'
```

- [ ] **ne renvoie rien.** Sinon, corriger `.env` puis `mix up -d api`

> `mix restart api` **ne relit pas** `.env`. Il faut `mix up -d api`.

### 12. Les migrations

```bash
mix exec api alembic upgrade head
mix exec api alembic current
```

- [ ] affiche `0010_card_thumbnails`

### 13. Vérifier en local, avant nginx

```bash
curl -s http://127.0.0.1:8000/healthz
curl -so /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/minio/health/live
sudo ss -ltnp | grep -E ':(8000|9000|9001)\s'
```

- [ ] `{"status":"ok"}`
- [ ] `200`
- [ ] les trois ports montrent `127.0.0.1:` et **jamais** `0.0.0.0:`

---

## Phase F. nginx et TLS

### 14. Préparer les racines statiques

```bash
sudo mkdir -p /srv/vitrine/telechargements /srv/dashboard
sudo chown -R www-data:www-data /srv/vitrine /srv/dashboard
```

### 15. Installer les trois vhosts

```bash
cd /srv/trialgo/ok_trialgo_backend/docker/nginx
sudo cp mixalgo.com.conf api.mixalgo.com.conf dashboard.mixalgo.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/mixalgo.com.conf           /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/api.mixalgo.com.conf       /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/dashboard.mixalgo.com.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

- [ ] `nginx -t` répond `syntax is ok` et `test is successful`
- [ ] caseformations.com répond toujours

### 16. Les certificats

```bash
sudo certbot --nginx -d mixalgo.com -d www.mixalgo.com
sudo certbot --nginx -d api.mixalgo.com
sudo certbot --nginx -d dashboard.mixalgo.com
sudo certbot certificates | grep -E "Certificate Name|Domains|Expiry"
```

- [ ] les trois certificats sont émis

> Ne pas écrire les directives `ssl_*` ni la redirection 80 vers 443 à la main : certbot les
> pose et les réécrit à chaque renouvellement.

---

## Phase G. Les données

### 17. Le premier administrateur

Le **tout premier** `register` devient admin. Les suivants sont des joueurs.

```bash
curl -X POST https://api.mixalgo.com/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"vous@exemple.com","password":"<mot de passe fort>"}'
```

- [ ] la réponse contient `"is_admin": true`

### 18. Le contenu du jeu

⚠️ **Exige les 76 images.** Le script s'arrête sur la première manquante. À ce jour, seules
12 existent (`vitrine/assets/cartes/`), donc **cette étape ne peut pas aboutir aujourd'hui**.
Le reste du déploiement fonctionne sans elle : le jeu sera simplement sans deck.

```bash
cd /srv/trialgo/ok_trialgo_backend
python3 scripts/referentiel.py valider referentiels/mixalgo-savane.yml

export TRIALGO_ADMIN_PASSWORD='<votre mot de passe>'
python3 scripts/referentiel.py importer referentiels/mixalgo-savane.yml \
  --api https://api.mixalgo.com \
  --email vous@exemple.com \
  --images /chemin/vers/les/76/images
unset TRIALGO_ADMIN_PASSWORD
```

Le nom de fichier attendu est celui du champ `image:` du YAML (`A3.jpg` pour la carte `A3`).
Formats acceptés : JPEG, PNG, WebP. 5 Mo maximum par carte.

- [ ] `valider` répond `referentiel valide`
- [ ] `importer` annonce 76 cartes et 46 nœuds

### 19. Les vignettes des cartes antérieures

```bash
mix exec api python scripts/generer_vignettes.py --essai
mix exec api python scripts/generer_vignettes.py
```

---

## Phase H. Les trois façades

### 20. La vitrine

```bash
cd /srv/trialgo
sudo rsync -a --delete --exclude 'telechargements' vitrine/ /srv/vitrine/
sudo chown -R www-data:www-data /srv/vitrine
```

> `--exclude 'telechargements'` protège l'APK : sans lui, `--delete` l'effacerait à chaque
> mise à jour du site.

- [ ] `https://mixalgo.com` affiche la vitrine

### 21. Le studio admin, compilé sur VOTRE poste

```bash
# sur votre machine
cd ok_trialgo_admin
flutter build web --release --dart-define=API_BASE_URL=https://api.mixalgo.com
rsync -a --delete build/web/ mixalgo@169.58.139.73:/tmp/dashboard/
ssh mixalgo@169.58.139.73 'sudo rsync -a --delete /tmp/dashboard/ /srv/dashboard/ && \
                           sudo chown -R www-data:www-data /srv/dashboard'
```

- [ ] connexion au studio, puis **rechargement de la page** pour vérifier la reprise de session

### 22. L'APK

⚠️ **Bloqué tant qu'il n'y a pas de keystore.** Sans `android/key.properties`, Gradle signe
avec la clé de debug : le binaire s'installe, mais il n'est pas publiable et **aucune version
correctement signée ne pourra jamais le mettre à jour**.

```bash
# sur votre machine, une seule fois dans la vie du projet
keytool -genkey -v -keystore ~/mixalgo-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias mixalgo

cp trialgo/android/key.properties.example trialgo/android/key.properties
nano trialgo/android/key.properties     # keyAlias, keyPassword, storeFile, storePassword
```

Puis le build. **Le `-t` est obligatoire** : l'app joueur n'a pas de `lib/main.dart`.

```bash
cd trialgo
flutter build apk --release -t lib/main_wireframe.dart

# contrôle : le certificat ne doit plus dire "Android Debug"
$ANDROID_HOME/build-tools/*/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk | grep "certificate DN"
```

- [ ] le certificat porte **votre** nom, pas `CN=Android Debug`

Dépôt sur le serveur :

```bash
scp build/app/outputs/flutter-apk/app-release.apk mixalgo@169.58.139.73:/tmp/mixalgo.apk
ssh mixalgo@169.58.139.73 \
  'sudo mv /tmp/mixalgo.apk /srv/vitrine/telechargements/mixalgo.apk && \
   sudo chown www-data:www-data /srv/vitrine/telechargements/mixalgo.apk'
```

⚠️ **Avant de distribuer le premier APK**, trancher l'`applicationId`. Il vaut aujourd'hui
`com.trialgo.app` et devient **définitif** dès la première publication : le Play Store ne
permet jamais de le changer.

---

## Phase I. Vérification finale

### 23. À passer d'une traite

```bash
# API
curl -s https://api.mixalgo.com/healthz                                        # {"status":"ok"}
curl -so /dev/null -w 'docs %{http_code}\n'   https://api.mixalgo.com/docs                 # 200
curl -so /dev/null -w '404? %{http_code}\n'   https://api.mixalgo.com/api/inexistant       # 404

# Images : l'inventaire du bucket ne doit PAS être listable
curl -so /dev/null -w 'liste %{http_code}\n'  https://api.mixalgo.com/files/trialgo-cards/ # 403
curl -X POST -so /dev/null -w 'post %{http_code}\n' https://api.mixalgo.com/files/x        # 405

# Vitrine
curl -so /dev/null -w 'vitrine %{http_code}\n' https://mixalgo.com/                        # 200
curl -so /dev/null -w 'robots %{http_code}\n'  https://mixalgo.com/robots.txt              # 200
curl -sI https://www.mixalgo.com/ | head -1                                                # 301
curl -sI https://mixalgo.com/ | grep -i strict-transport                                   # présent

# Studio
curl -so /dev/null -w 'studio %{http_code}\n'  https://dashboard.mixalgo.com/              # 200

# API publique, celle que lit la vitrine
curl -s https://api.mixalgo.com/api/public/games | head -c 300

# APK, une fois déposé
curl -sI https://mixalgo.com/telechargements/mixalgo.apk | grep -iE 'HTTP/|content-type'
# content-type: application/vnd.android.package-archive

# Rien ne doit écouter en 0.0.0.0
sudo ss -ltnp | grep -E ':(8000|9000|9001)\s'
```

### 24. Dans un navigateur

- [ ] `https://mixalgo.com` : les cartes s'affichent, « Fusion suivante » répond
- [ ] `https://dashboard.mixalgo.com` : connexion puis rechargement de page
- [ ] depuis un Android, scanner le QR : la page s'ouvre et le bouton dit « Installer sur cet appareil »

---

## Phase J. Sauvegardes

### 25. Première exécution manuelle

```bash
cd /srv/trialgo/ok_trialgo_backend
./scripts/backup.sh
./scripts/restore.sh            # doit lister la sauvegarde qu'on vient de faire
```

### 26. En cron, dès le premier jour

```bash
crontab -e
```

```
15 3 * * * cd /srv/trialgo/ok_trialgo_backend && ./scripts/backup.sh >> /var/log/trialgo-backup.log 2>&1
```

### 27. Les deux choses que les scripts ne font pas

- [ ] **Sortir les sauvegardes de la machine.** `rclone sync /var/backups/trialgo distant:trialgo-backups`, ou un montage NAS. Un dossier sur le serveur meurt avec le serveur.
- [ ] **Sauvegarder `.env` chiffré, hors du serveur.** Le perdre rend le volume PostgreSQL inutilisable et invalide tous les jetons émis.
- [ ] **Sauvegarder le keystore chiffré, hors du poste.** Le perdre interdit définitivement toute mise à jour de l'application.

---

## Mise à jour, plus tard

```bash
cd /srv/trialgo && git pull
cd ok_trialgo_backend && mix up -d --build && mix exec api alembic upgrade head
sudo rsync -a --delete --exclude 'telechargements' ../vitrine/ /srv/vitrine/
sudo chown -R www-data:www-data /srv/vitrine
```

---

## Récapitulatif des points bloquants

| Étape | Bloquant | Qui |
|---|---|---|
| 18 | 64 images de cartes manquantes sur 76 | vous |
| 22 | aucun keystore Android | vous |
| 22 | `applicationId` `com.trialgo.app`, à trancher avant publication | vous |

Aucun des trois n'empêche les phases A à H et J. Le serveur, la vitrine et le studio montent
sans eux ; le jeu sera sans deck et le bouton de téléchargement en 404 jusqu'à leur
résolution.
