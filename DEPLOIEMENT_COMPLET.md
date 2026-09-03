# Déploiement complet de MIXALGO

Guide unique, du serveur nu jusqu'à l'APK téléchargeable. À suivre dans l'ordre.

Les deux autres documents restent utiles et ne sont pas répétés ici :
[`ok_trialgo_backend/RESSOURCES_MUTUALISEES.md`](ok_trialgo_backend/RESSOURCES_MUTUALISEES.md)
argumente ce qu'on partage avec le serveur, et
[`ok_trialgo_backend/DEPLOIEMENT.md`](ok_trialgo_backend/DEPLOIEMENT.md) détaille la variante
sur machine dédiée.

---

## Sommaire

1. [Ce que vous allez obtenir](#1-ce-que-vous-allez-obtenir)
2. [Lire votre serveur](#2-lire-votre-serveur)
3. [Préparer le serveur](#3-préparer-le-serveur)
4. [Récupérer le projet](#4-récupérer-le-projet)
5. [Configurer](#5-configurer)
6. [Lancer la stack](#6-lancer-la-stack)
7. [nginx et TLS](#7-nginx-et-tls)
8. [Initialiser les données](#8-initialiser-les-données)
9. [Les trois façades](#9-les-trois-façades)
10. [La chaîne QR vers APK vers backend](#10-la-chaîne-qr-vers-apk-vers-backend)
11. [Vérification finale](#11-vérification-finale)
12. [Sauvegardes](#12-sauvegardes)
13. [Mettre à jour plus tard](#13-mettre-à-jour-plus-tard)
14. [Pannes courantes](#14-pannes-courantes)

---

## 1. Ce que vous allez obtenir

```
Internet
   │
   └── nginx (hôte, ports 80 et 443, TLS Let's Encrypt)
         ├── caseformations.com      → existant, on n'y touche pas
         ├── mixalgo.com             → /srv/vitrine          fichiers statiques
         ├── api.mixalgo.com         → 127.0.0.1:8000        API FastAPI
         ├── api.mixalgo.com/files/  → 127.0.0.1:9000        images MinIO
         └── dashboard.mixalgo.com   → /srv/dashboard        studio Flutter web
```

Quatre livrables :

| Livrable | Où | Qui le consomme |
|---|---|---|
| API FastAPI | conteneur `api` | l'app joueur, le studio, la vitrine |
| Vitrine publique | `/srv/vitrine` | les visiteurs |
| Studio admin | `/srv/dashboard` | vous |
| APK Android | `/srv/vitrine/telechargements/` | les joueurs |

---

## 2. Lire votre serveur

Votre `docker ps` montre quatre conteneurs et **ni nginx ni PostgreSQL**. C'est normal,
et c'est même une bonne nouvelle.

```
127.0.0.1:8021->8000/tcp   cf_api
127.0.0.1:3021->3000/tcp   cf_vitrine
127.0.0.1:3022->3000/tcp   cf_dashboard
                           cf_qcluster   (aucun port publié)
```

**`docker ps` ne montre que Docker.** nginx et PostgreSQL tournent sur l'hôte, en services
systemd.

La preuve est dans cette sortie même. Ces ports sont publiés sur `127.0.0.1`, donc
joignables uniquement depuis la machine : depuis Internet, ils n'existent pas. Or
caseformations.com répond. Un processus de l'hôte fait donc le pont entre le 443 public et
ces ports locaux, et ce processus est nginx.

Pour PostgreSQL, même raisonnement : `cf_api` lance `python manage.py qcluster`, c'est du
Django, il a forcément une base. Aucun conteneur `postgres` dans la liste, donc elle est
sur l'hôte.

MIXALGO reproduit exactement ce motif. Vous le maîtrisez déjà.

### Confirmer, et relever les ports libres

```bash
systemctl status nginx --no-pager | head -5
systemctl status postgresql --no-pager | head -5
sudo ss -ltnp
```

**`postgresql.service` affiche `Active: active (exited)`, et c'est normal.** Sur Debian et
Ubuntu, cette unité est une simple enveloppe qui ne fait tourner aucun processus : elle
démarre les vraies instances puis se termine, d'où `active (exited)` et un temps processeur
de quelques millisecondes. Le vrai serveur est ailleurs :

```bash
pg_lsclusters                                    # version, port, état, répertoire
systemctl status 'postgresql@*-main' --no-pager | head -8
```

Dans la sortie de `ss`, vérifier que **8000, 9000 et 9001 sont libres**. S'ils sont pris,
choisir trois autres ports et les reporter dans **deux fichiers seulement** :

- `ok_trialgo_backend/docker-compose.nginx.yml` (les trois lignes `ports:`)
- `ok_trialgo_backend/docker/nginx/api.mixalgo.com.conf` (les deux `proxy_pass`)

> Votre convention actuelle est en `80xx` et `30xx`. Rien n'oblige à s'y tenir, mais rester
> cohérent évitera une collision le jour où vous ajouterez un quatrième projet.

---

## 3. Préparer le serveur

### 3.1 Un utilisateur dédié

Ne pas déployer en `root`. Un conteneur compromis qui s'échappe hérite des droits du
compte qui l'a lancé.

```bash
# En root, une seule fois
adduser mixalgo                      # mot de passe demandé
usermod -aG sudo mixalgo             # pour les commandes nginx et certbot
usermod -aG docker mixalgo           # pour lancer docker sans sudo

# Contrôle : les deux groupes doivent apparaître
id mixalgo

# Clé SSH (depuis VOTRE poste, pas le serveur)
ssh-copy-id mixalgo@169.58.139.73
```

⚠️ **`adduser` peut se terminer sans avoir posé de mot de passe.** Si les deux saisies ne
correspondent pas, il affiche `passwd: password unchanged`, propose `Try again? [y/N]`, et
**poursuit quand même** la création du compte. L'utilisateur existe alors sans mot de passe,
et `sudo` lui est inutilisable : il le réclamera indéfiniment sans jamais l'accepter.

Le message passe inaperçu au milieu du reste. Vérifiez, et corrigez si besoin :

```bash
passwd --status mixalgo    # 2e champ : P = mot de passe défini, L = verrouillé, NP = aucun
passwd mixalgo             # pour en poser un
```

⚠️ **`usermod -aG docker` est un octroi de privilèges quasi total.** Un membre du groupe
`docker` peut monter `/` dans un conteneur et devenir root. C'est le compromis habituel et
accepté sur un serveur d'application ; ne mettez dans ce groupe que des comptes en qui vous
avez la même confiance qu'en root.

Durcir SSH pendant qu'on y est :

```bash
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl reload ssh
```

> **Ne fermez pas votre session en cours avant d'avoir vérifié**, depuis un SECOND terminal,
> que `ssh mixalgo@169.58.139.73` fonctionne avec la clé. Une erreur ici vous enferme dehors.

### 3.2 Docker

Vous l'avez déjà, `docker ps` le prouve. Pour mémoire, sur une machine neuve :

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
docker compose version        # doit répondre v2.x
```

`docker compose` en deux mots, pas `docker-compose` : la v1 en Python n'est plus maintenue
et ne comprend pas certaines clés utilisées ici.

### 3.3 Pare-feu

```bash
sudo ufw status
# Doivent être autorisés : 22 (SSH), 80 et 443 (nginx). Rien d'autre.
```

⚠️ **Le piège Docker.** Si vous publiez un port **sans** le préfixe `127.0.0.1:`, Docker
écrit lui-même une règle iptables qui **court-circuite ufw**. Le pare-feu affiche
`8000 DENY` pendant que le port répond au monde entier, en clair, hors de tout contrôle de
nginx. Docker ne prévient pas. C'est la raison d'être de `docker-compose.nginx.yml`.

Contrôle après démarrage :

```bash
sudo ss -ltnp | grep -E ':(8000|9000|9001)\s'
# Doit afficher 127.0.0.1:8000 et non 0.0.0.0:8000
```

### 3.4 DNS

Trois enregistrements `A` vers l'IP du serveur, **à créer maintenant** : la propagation
prend de quelques minutes à quelques heures, et certbot refuse d'émettre un certificat
pour un domaine qui ne pointe pas encore sur la machine.

| Nom | Type | Valeur |
|---|---|---|
| `mixalgo.com` | A | `169.58.139.73` |
| `www.mixalgo.com` | A | `169.58.139.73` |
| `api.mixalgo.com` | A | `169.58.139.73` |
| `dashboard.mixalgo.com` | A | `169.58.139.73` |

```bash
dig +short mixalgo.com www.mixalgo.com api.mixalgo.com dashboard.mixalgo.com
# Les quatre doivent renvoyer l'IP du serveur avant de continuer.
```

---

## 4. Récupérer le projet

**Toute cette section se fait en tant que `mixalgo`, pas en root.**

```bash
# En root : préparer l'emplacement, puis rendre la main
mkdir -p /srv/trialgo
chown mixalgo:mixalgo /srv/trialgo

# Basculer sur le compte de déploiement
su - mixalgo          # ou se reconnecter en ssh mixalgo@169.58.139.73

git clone https://github.com/EdwinTchakounte/2026_TriAlgo.git /srv/trialgo
cd /srv/trialgo
git log --oneline -3        # vérifier qu'on a bien la dernière version
```

⚠️ **Cloner en root dans un dossier appartenant à `mixalgo` échoue :**

```
fatal: detected dubious ownership in repository at '/srv/trialgo'
```

git refuse d'opérer sur un dépôt dont le propriétaire n'est pas l'utilisateur courant. C'est
une protection réelle : un dépôt écrit par un autre compte peut contenir des `core.hooksPath`
ou des filtres qui s'exécutent au premier `git status`.

**Ne suivez pas le conseil que git affiche** (`git config --global --add safe.directory`) : il
fait taire le contrôle sans corriger la cause, et vous laisse un dépôt aux fichiers mélangés
entre deux propriétaires, que `git pull` ne pourra plus mettre à jour depuis le compte de
déploiement. Le vrai correctif est de refaire le clone du bon côté :

```bash
# En root
rm -rf /srv/trialgo
mkdir -p /srv/trialgo && chown mixalgo:mixalgo /srv/trialgo
su - mixalgo -c 'git clone https://github.com/EdwinTchakounte/2026_TriAlgo.git /srv/trialgo'
```

> Le dépôt est **public**. C'est aussi pourquoi `.env` ne doit jamais y entrer : un secret
> poussé une seule fois reste dans l'historique même après suppression du fichier, et doit
> alors être considéré comme compromis et régénéré.

---

## 5. Configurer

```bash
cd /srv/trialgo/ok_trialgo_backend
cp .env.production.example .env
chmod 600 .env               # personne d'autre que vous n'a à le lire
```

### Générer les secrets

**Sur le serveur, jamais ailleurs.** Ne les faites transiter par aucune messagerie.

```bash
echo "JWT_SECRET=$(openssl rand -hex 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
echo "MINIO_ROOT_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
```

Reportez ces valeurs dans `.env`, puis renseignez les `<chevrons>` restants.

### Les valeurs qui comptent

| Variable | Valeur | Ce qui casse si elle est fausse |
|---|---|---|
| `PUBLIC_BASE_URL` | `https://api.mixalgo.com` | Les liens de réinitialisation de mot de passe ne mènent nulle part |
| `S3_PUBLIC_ENDPOINT_URL` | `https://api.mixalgo.com/files` | **Toutes les images cassées sur mobile**, avec des logs serveur vides |
| `CORS_ALLOWED_ORIGINS` | `https://dashboard.mixalgo.com,https://mixalgo.com` | Le studio et la vitrine ne peuvent plus appeler l'API |
| `TRUST_PROXY_HEADERS` | `true` | L'API voit tout venir de `127.0.0.1` : le premier utilisateur actif bloque tous les autres |
| `BREVO_API_KEY` | votre clé | Les courriels sont seulement journalisés |

**`S3_PUBLIC_ENDPOINT_URL` est le piège le plus coûteux.** Cette valeur est recopiée telle
quelle dans chaque `image_url` renvoyée aux clients. Restée sur `localhost`, l'API répond
200 partout, les journaux sont vides, et toutes les cartes s'affichent cassées sur les
téléphones. **Pas de barre oblique finale** : `public_url()` concatène sans normaliser, et
un double séparateur donne des images en 404 pendant que tout le reste fonctionne.

---

## 6. Lancer la stack

### Quels fichiers compose, et pourquoi deux

```bash
cd /srv/trialgo/ok_trialgo_backend
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml up -d --build
```

- **`docker-compose.prod.yml`** définit tout : `postgres`, `minio`, `create_bucket`, `api`,
  `caddy`. C'est la source de vérité unique des services.
- **`docker-compose.nginx.yml`** ne redéfinit que ce qui change sur ce serveur : il
  neutralise Caddy (par un `profiles` jamais activé, car on ne peut pas *supprimer* un
  service hérité) et republie les ports **sur la boucle locale**.

Avant de lancer, on peut voir la configuration effective :

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml config
```

### Contrôler le démarrage

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml ps
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml logs api | grep -A20 'CONFIGURATION INCOMPLETE'
```

Ce `grep` **ne doit rien renvoyer**. `app/core/startup_checks.py` journalise un bloc
`CRITICAL` par valeur restée en mode développement. **Ces contrôles avertissent, ils ne
bloquent pas** : bloquer casserait le développement local et la CI. Lisez les journaux du
premier démarrage.

Pour alléger la suite, un alias :

```bash
echo "alias mix='docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml'" >> ~/.bashrc
source ~/.bashrc
```

### Les migrations

```bash
mix exec api alembic upgrade head
mix exec api alembic current      # doit afficher 0010_card_thumbnails
```

### Contrôle local, avant nginx

```bash
curl -s http://127.0.0.1:8000/healthz          # {"status":"ok"}
curl -s http://127.0.0.1:9000/minio/health/live -o /dev/null -w '%{http_code}\n'   # 200
```

---

## 7. nginx et TLS

Trois vhosts, fournis dans le dépôt.

```bash
cd /srv/trialgo/ok_trialgo_backend/docker/nginx
sudo cp mixalgo.com.conf api.mixalgo.com.conf dashboard.mixalgo.com.conf \
        /etc/nginx/sites-available/

sudo ln -s /etc/nginx/sites-available/mixalgo.com.conf           /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/api.mixalgo.com.conf       /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/dashboard.mixalgo.com.conf /etc/nginx/sites-enabled/

# Les racines statiques, avant le premier rechargement
sudo mkdir -p /srv/vitrine /srv/dashboard /srv/vitrine/telechargements
sudo chown -R www-data:www-data /srv/vitrine /srv/dashboard

sudo nginx -t && sudo systemctl reload nginx
```

### Les certificats

```bash
sudo certbot --nginx -d mixalgo.com -d www.mixalgo.com
sudo certbot --nginx -d api.mixalgo.com
sudo certbot --nginx -d dashboard.mixalgo.com
```

⚠️ **Ne pas écrire les directives `ssl_*` ni la redirection 80 vers 443 à la main.** certbot
les pose lui-même et les réécrit à chaque renouvellement ; les doubler crée un conflit
silencieux.

### Trois traductions du Caddyfile qui ne vont pas de soi

| Point | Caddy | nginx |
|---|---|---|
| Retrait du préfixe `/files` | `uri strip_prefix /files` | **barre finale** de `proxy_pass http://127.0.0.1:9000/;` |
| Lecture seule sur `/files` | `method GET HEAD` + `respond 405` | `if ($request_method !~ ^(GET\|HEAD)$) { return 405; }` |
| Taille des téléversements | illimitée par défaut | **`client_max_body_size 6m;`** |

Le troisième est le piège coûteux : **nginx plafonne par défaut à 1 Mo** alors que l'API
accepte 5 Mo. Sans cette directive, toute carte entre 1 et 5 Mo est rejetée par un 413 que
l'API n'a jamais émis, absent de ses journaux, affiché tel quel par le studio.

Autre piège, dans le vhost du studio et celui de la vitrine : **un `add_header` dans un
`location` annule ceux du niveau serveur.** Ils se remplacent, ils ne s'ajoutent pas. HSTS
et `nosniff` sont donc répétés dans chaque bloc qui pose un `Cache-Control`.

---

## 8. Initialiser les données

### 8.1 Le premier administrateur

**Le tout premier `register` crée un admin.** Les suivants sont des joueurs normaux.

```bash
curl -X POST https://api.mixalgo.com/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"vous@exemple.com","password":"<mot de passe fort>"}'
```

> La réponse de `register` imbrique les jetons sous `tokens`
> (`{user, tokens:{access_token, refresh_token}}`) alors que `login` et `refresh` les
> renvoient **à plat**. Ne pas confondre les deux formes.

### 8.2 Le contenu du jeu

```bash
cd /srv/trialgo/ok_trialgo_backend

# 1. Valider AVANT d'envoyer quoi que ce soit
python3 scripts/referentiel.py valider referentiels/mixalgo-savane.yml

# 2. Importer, via l'API et jamais en SQL direct
export TRIALGO_ADMIN_PASSWORD='<votre mot de passe>'
python3 scripts/referentiel.py importer referentiels/mixalgo-savane.yml \
  --api https://api.mixalgo.com \
  --email vous@exemple.com \
  --images /chemin/vers/les/76/images
unset TRIALGO_ADMIN_PASSWORD
```

⚠️ **L'import exige les 76 images, sans exception.** Le script s'arrête sur la première
manquante avec `! image introuvable`. C'est délibéré : dans un jeu d'observation, une carte
sans visuel n'est pas une carte dégradée, c'est une carte inutilisable.

Le nom de fichier attendu est celui du champ `image:` du YAML, par exemple `A3.jpg` pour la
carte `A3`. **Formats acceptés : JPEG, PNG et WebP**, détectés par leurs octets d'en-tête et
non par leur extension. Taille maximale 5 Mo par carte.

> **À ce jour, seules 12 des 76 images existent** (celles de la planche d'impression, dans
> `vitrine/assets/cartes/`). Tant que les 64 autres manquent, l'import ne peut pas aboutir.
> Le backend se déploie quand même : il sera simplement sans deck jusque-là.

⚠️ **L'import refuse d'écrire par-dessus un graphe existant**, sauf `--remplacer`. Ce
garde-fou n'est pas une précaution de principe : un second passage créerait 46 nœuds
supplémentaires et **décalerait tous les `node_index`**, c'est-à-dire tous les numéros de
trio déjà imprimés sur les cartes physiques et annoncés en séance.

### 8.3 Les vignettes

Les cartes importées après la migration `0010` ont déjà leur vignette. Pour rattraper
d'éventuelles cartes plus anciennes :

```bash
mix exec api python scripts/generer_vignettes.py --essai   # simulation
mix exec api python scripts/generer_vignettes.py           # pour de vrai
```

Idempotent : il ne traite que les cartes dont `thumb_key` est nul.

---

## 9. Les trois façades

### 9.1 La vitrine

Aucune compilation. Le dossier se recopie tel quel.

```bash
cd /srv/trialgo
sudo rsync -a --delete --exclude 'telechargements' vitrine/ /srv/vitrine/
sudo chown -R www-data:www-data /srv/vitrine
```

> `--exclude 'telechargements'` protège l'APK : sans lui, `--delete` effacerait le fichier
> à chaque mise à jour de la vitrine, et le bouton de téléchargement renverrait un 404
> silencieux.

Les visuels sont reconstructibles depuis les sources, si besoin :

```bash
python3 vitrine/outils/detourer_logo.py      # logo, favicon, image de partage
python3 vitrine/outils/extraire_cartes.py    # les 12 cartes (exige le PDF d'impression)
python3 vitrine/outils/generer_qr.py         # le QR de téléchargement
```

### 9.2 Le studio admin

À compiler **sur votre poste**, pas sur le serveur : Flutter n'a rien à y faire.

```bash
# Sur votre poste
cd ok_trialgo_admin
flutter build web --release --dart-define=API_BASE_URL=https://api.mixalgo.com

# Envoi
rsync -a --delete build/web/ mixalgo@169.58.139.73:/tmp/dashboard/
ssh mixalgo@169.58.139.73 'sudo rsync -a --delete /tmp/dashboard/ /srv/dashboard/ && \
                           sudo chown -R www-data:www-data /srv/dashboard'
```

> Le `--dart-define` est facultatif : en release, `ApiConfig.baseUrl` vaut déjà
> `https://api.mixalgo.com` (`api_config.dart` bascule sur `kReleaseMode`). Le passer
> explicitement ne coûte rien et rend la commande lisible.

### 9.3 L'APK

```bash
# Sur votre poste
cd trialgo
flutter build apk --release -t lib/main_wireframe.dart
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

⚠️ **Le `-t lib/main_wireframe.dart` n'est pas optionnel.** L'app joueur n'a **pas** de
`lib/main.dart` : son unique point d'entrée porte un autre nom. Sans ce drapeau, la
compilation s'arrête sur `Target file "lib/main.dart" not found` avant même d'avoir
commencé. La même règle vaut pour `flutter run` et pour `flutter build appbundle`.

Pour le Play Store, c'est un **AAB** qu'il faut, pas un APK :

```bash
flutter build appbundle --release -t lib/main_wireframe.dart
```

⚠️ **Sans `android/key.properties`, Gradle retombe sur la clé de debug** avec un
avertissement. Ce binaire s'installe et fonctionne, mais **il n'est pas publiable**, et une
version correctement signée ne pourra jamais le mettre à jour : Android refuse un changement
de signature. Voir la section « Signature Android » du `CLAUDE.md`.

Dépôt sur le serveur :

```bash
scp build/app/outputs/flutter-apk/app-release.apk mixalgo@169.58.139.73:/tmp/mixalgo.apk
ssh mixalgo@169.58.139.73 \
  'sudo mv /tmp/mixalgo.apk /srv/vitrine/telechargements/mixalgo.apk && \
   sudo chown www-data:www-data /srv/vitrine/telechargements/mixalgo.apk'
```

---

## 10. La chaîne QR vers APK vers backend

Trois maillons, chacun vérifiable séparément.

### Maillon 1 : le QR mène à la page

`vitrine/assets/qr-telechargement.png` encode **exactement** :

```
https://mixalgo.com/#telecharger
```

Vérifié par ré-encodage : l'image régénérée depuis cette URL est identique au pixel près à
celle du dépôt, et une URL différente produit une image différente.

```bash
python3 vitrine/outils/generer_qr.py --sortie /tmp/controle.png
cmp /tmp/controle.png vitrine/assets/qr-telechargement.png && echo "QR conforme"
```

**Pourquoi la page et non le fichier directement.** Un QR pointant sur l'APK déclenche un
téléchargement brut, sans contexte : le visiteur reçoit un fichier qu'Android traite comme
suspect, sans avoir lu la consigne d'autorisation des sources inconnues, et sans savoir ce
qu'il vient de récupérer. La page l'accueille sur le bloc de téléchargement, où le script
a déjà remplacé le libellé du bouton par **« Installer sur cet appareil »** puisqu'il
détecte Android. Un seul geste sépare le scan de l'installation.

Pour pointer directement sur le fichier malgré tout, une constante à changer dans
`vitrine/outils/generer_qr.py` :

```python
CIBLE_DEFAUT = "https://mixalgo.com/telechargements/mixalgo.apk"
```

### Maillon 2 : la page mène à l'APK

Le bouton porte `href="/telechargements/mixalgo.apk"`, servi par le bloc
`location /telechargements/` du vhost, dont la racine est `/srv/vitrine`. Le fichier
attendu est donc `/srv/vitrine/telechargements/mixalgo.apk`.

Le vhost force deux en-têtes sur ce dossier :

- `Content-Type: application/vnd.android.package-archive`. Sans lui, nginx annonce
  `application/octet-stream` et certains navigateurs Android **refusent d'ouvrir le fichier
  avec l'installateur** : le téléchargement réussit, et rien ne se passe au clic.
- `Content-Disposition: attachment; filename="mixalgo.apk"`, pour que le fichier arrive sous
  un nom reconnaissable.

```bash
curl -sI https://mixalgo.com/telechargements/mixalgo.apk | grep -iE 'HTTP/|content-type|content-disposition'
# HTTP/2 200
# content-type: application/vnd.android.package-archive
# content-disposition: attachment; filename="mixalgo.apk"
```

### Maillon 3 : l'APK parle au bon backend

`trialgo/lib/core/api/api_config.dart` :

```dart
static const String _urlProduction   = 'https://api.mixalgo.com';
static const String _urlDeveloppement = 'http://10.0.2.2:8000';

static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kReleaseMode ? _urlProduction : _urlDeveloppement,
);
```

`kReleaseMode` vaut `true` dans tout build `--release`. **Un APK release pointe donc sur
`https://api.mixalgo.com` sans qu'aucun `--dart-define` soit nécessaire.** `10.0.2.2` est
l'adresse de la machine hôte vue depuis l'émulateur Android : elle ne sert qu'en
développement et ne peut pas fuiter en production par cette voie.

Contrôle sur l'APK produit, qui ne demande aucun appareil :

```bash
unzip -p build/app/outputs/flutter-apk/app-release.apk \
      assets/flutter_assets/kernel_blob.bin 2>/dev/null \
  | strings | grep -c 'api.mixalgo.com'
# Doit être supérieur à 0. En build AOT, chercher plutôt dans lib/*/libapp.so :
unzip -p build/app/outputs/flutter-apk/app-release.apk lib/arm64-v8a/libapp.so \
  | strings | grep -c 'api.mixalgo.com'
```

`ApiConfig.linkDomain` vaut `mixalgo.com` par défaut : c'est le seul hôte accepté pour un
deep-link `https`. Il est **constant et non dérivé de `baseUrl`**, parce que `baseUrl` vaut
`10.0.2.2` en debug, d'où aucun domaine exploitable.

---

## 11. Vérification finale

À passer d'une traite. Chaque ligne doit produire le résultat annoncé.

```bash
# --- API ---
curl -s https://api.mixalgo.com/healthz                       # {"status":"ok"}
curl -so /dev/null -w '%{http_code}\n' https://api.mixalgo.com/docs        # 200
curl -so /dev/null -w '%{http_code}\n' https://api.mixalgo.com/api/inexistant  # 404

# --- Images ---
curl -so /dev/null -w '%{http_code}\n' https://api.mixalgo.com/files/trialgo-cards/   # 403
#   ^ 403 et non 200 : l'inventaire du bucket ne doit PAS être listable
curl -X POST -so /dev/null -w '%{http_code}\n' https://api.mixalgo.com/files/x        # 405

# --- Vitrine ---
curl -so /dev/null -w '%{http_code}\n' https://mixalgo.com/                # 200
curl -so /dev/null -w '%{http_code}\n' https://mixalgo.com/robots.txt      # 200
curl -sI https://www.mixalgo.com/ | head -1                                # 301
curl -sI https://mixalgo.com/ | grep -i strict-transport                   # présent

# --- Studio ---
curl -so /dev/null -w '%{http_code}\n' https://dashboard.mixalgo.com/      # 200

# --- API publique, celle que lit la vitrine ---
curl -s https://api.mixalgo.com/api/public/games | head -c 300

# --- Ports : rien ne doit écouter en 0.0.0.0 ---
sudo ss -ltnp | grep -E ':(8000|9000|9001)\s'
```

Puis, dans un navigateur :

- `https://mixalgo.com` affiche la vitrine, les cartes, et la démonstration de fusion
  répond au bouton « Fusion suivante ».
- `https://dashboard.mixalgo.com` : connexion, puis **rechargement de la page** pour
  vérifier la reprise de session.
- Depuis un téléphone Android, scanner le QR de la vitrine : la page s'ouvre sur le bloc de
  téléchargement, et le bouton affiche « Installer sur cet appareil ».

---

## 12. Sauvegardes

Le code se reconstruit depuis git. Une carte photographiée et découpée à la main, non.

```bash
cd /srv/trialgo/ok_trialgo_backend
./scripts/backup.sh                  # base + images
./scripts/restore.sh                 # liste les sauvegardes disponibles
```

En cron, dès le premier jour :

```bash
crontab -e
# 15 3 * * * cd /srv/trialgo/ok_trialgo_backend && ./scripts/backup.sh >> /var/log/trialgo-backup.log 2>&1
```

**Deux choses que ces scripts ne font pas, et qui restent à votre charge :**

1. **Sortir les sauvegardes de la machine.** Un dossier sur le serveur meurt avec le
   serveur. `rclone sync /var/backups/trialgo distant:trialgo-backups` après le cron, ou un
   montage NAS.
2. **Sauvegarder le `.env`**, hors dépôt et chiffré. Il n'est pas dans le miroir : c'est un
   fichier de secrets, il n'a rien à faire à côté d'un dump en clair. Le perdre ne détruit
   pas les données mais rend le volume PostgreSQL inutilisable (mot de passe) et invalide
   tous les jetons émis (`JWT_SECRET`).

---

## 13. Mettre à jour plus tard

```bash
cd /srv/trialgo
git pull

# Backend : reconstruire et recréer
cd ok_trialgo_backend
mix up -d --build
mix exec api alembic upgrade head

# Vitrine
sudo rsync -a --delete --exclude 'telechargements' ../vitrine/ /srv/vitrine/
sudo chown -R www-data:www-data /srv/vitrine
```

⚠️ **`docker compose restart` ne relit pas le `.env`.** Il redémarre le processus dans le
conteneur existant, avec la configuration déjà résolue. Modifier `.env` puis `restart` ne
change **rien**.

```bash
mix up -d api            # relit env_file
mix restart api          # NE le relit PAS
```

Le symptôme est déroutant : le fichier contient la bonne valeur, l'API se comporte comme si
elle n'existait pas. Pour vérifier ce que l'API voit vraiment :

```bash
mix exec api python -c "from app.config import settings; print(settings.S3_PUBLIC_ENDPOINT_URL)"
```

---

## 14. Pannes courantes

| Symptôme | Cause probable | Vérification |
|---|---|---|
| Images cassées sur mobile, API en 200, logs vides | `S3_PUBLIC_ENDPOINT_URL` sur `localhost`, ou barre oblique finale | `mix exec api python -c "from app.config import settings; print(settings.S3_PUBLIC_ENDPOINT_URL)"` |
| Le studio ou la vitrine ne peuvent rien appeler | Origine absente de `CORS_ALLOWED_ORIGINS` | Onglet Réseau du navigateur : préflight en 400 |
| Carte de 2 Mo refusée en 413 sans trace côté API | `client_max_body_size` manquant | `grep client_max_body_size /etc/nginx/sites-enabled/api.mixalgo.com.conf` |
| Le premier joueur actif bloque tous les autres | `TRUST_PROXY_HEADERS` à `false` | Contrôle 8 des `startup_checks` dans les logs |
| Le lien de réinitialisation ne mène nulle part | `PUBLIC_BASE_URL` pointant sur le studio | Doit valoir `https://api.mixalgo.com` |
| L'API répond sur `http://<ip>:8000` | Port publié sans `127.0.0.1:` | `sudo ss -ltnp \| grep 8000` |
| Le bouton APK renvoie 404 | Fichier absent, ou effacé par un `rsync --delete` | `ls -l /srv/vitrine/telechargements/` |
| L'APK se télécharge mais ne s'installe pas | Type MIME | `curl -sI .../mixalgo.apk \| grep -i content-type` |
| Le studio se fige sur « Chargement de votre session » | Stockage du navigateur | Vider le stockage du site ; le correctif est déjà en place |
| `docker compose exec api python scripts/...` : fichier introuvable | Image construite avant l'ajout de `scripts/` | `mix up -d --build api` |
| Modification de `.env` sans effet | `restart` au lieu de `up -d` | Voir §13 |

---

## Ce qui reste ouvert

Ces points **ne bloquent pas** la mise en ligne du serveur, mais ils sont connus :

- **Aucun keystore Android.** L'APK produit est signé avec la clé de debug : installable,
  non publiable, et non remplaçable par une version signée correctement.
- **12 images de cartes sur 76.** L'import du référentiel ne peut pas aboutir tant que les
  64 autres manquent.
- **`K2`, `X1` et `Y5`** figurent sur la planche d'impression mais n'appartiennent à aucune
  fusion du référentiel Savane.
- **La boucle `M8 + E4 = B9` / `B9 + M8 = E4`** réduit une chaîne à 3 cartes distinctes au
  lieu de 5 : elle stérilise un niveau D2 et en ampute deux D3.
- **Huit chaînages** (`n30`, `n31`, `n32`, `n33`, `n36`, `n41`, `n44`, `n45`) ont été
  arbitrés d'après l'ordre écrit du dictionnaire, sans confirmation.
- **Aucun test automatisé côté backend** (`pytest` est déclaré, la suite n'est pas écrite).
