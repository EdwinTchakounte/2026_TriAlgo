# Ressources du serveur : ce qu'on mutualise, ce qu'on garde à part

Le serveur cible (`169.58.139.73`) n'est pas une machine dédiée : il héberge déjà
d'autres sites derrière **nginx 1.24** et Let's Encrypt. Installer TRIALGO revient
donc à répondre, service par service, à une seule question :

> **Est-ce qu'on réutilise ce qui est déjà là, ou est-ce qu'on apporte le nôtre ?**

Ce document tranche cette question et donne ce qu'il faut vérifier avant de commencer.
La procédure d'installation complète est dans
[`../DEPLOIEMENT_COMPLET.md`](../DEPLOIEMENT_COMPLET.md).

---

## 1. La décision, service par service

`docker-compose.prod.yml` déclare quatre services : `postgres`, `minio`, `api`, `caddy`
(plus `mc`, un conteneur éphémère qui ne fait que poser la politique du bucket au premier
démarrage, puis s'arrête).

| Ressource | Sur le serveur ? | Décision | En une phrase |
|---|---|---|---|
| **nginx + certbot** | oui, nginx 1.24 | **Mutualiser** | Obligatoire : deux serveurs ne peuvent pas écouter sur 443. |
| **Docker** | à vérifier | **Mutualiser** | Rien de particulier. |
| **PostgreSQL** | probablement | **Garder celui du compose** | Les scripts de sauvegarde en dépendent. Voir §2. |
| **MinIO** | non | **Apporter le nôtre** | Aucun équivalent installé. |
| **Redis** | — | **Rien à faire** | Le projet n'en utilise pas : le limiteur de débit vit en mémoire dans le process. |

### nginx : déjà traité

C'est le seul point où la mutualisation est **imposée**, et il est déjà résolu.
`docker-compose.nginx.yml` neutralise Caddy et republie tout sur la boucle locale :

```
Internet ─ nginx (hôte, 443, TLS déjà en place)
             ├─ caseformations.com      → existant, on n'y touche pas
             ├─ api.mixalgo.com         → 127.0.0.1:8000   API FastAPI
             ├─ api.mixalgo.com/files/  → 127.0.0.1:9000   MinIO
             └─ dashboard.mixalgo.com   → /srv/dashboard   studio Flutter web
```

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.nginx.yml up -d --build
```

Le préfixe `127.0.0.1:` des `ports:` n'est pas décoratif. Sans lui, Docker ouvre le port
sur **toutes** les interfaces *et* écrit une règle iptables qui court-circuite ufw : le
pare-feu afficherait `8000 DENY` pendant que le port répond au monde entier, en clair,
hors de tout contrôle de nginx — et MinIO avec lui sur 9000, console d'administration
comprise. Docker ne prévient pas.

---

## 2. Pourquoi ne pas partager le PostgreSQL de l'hôte

Le réflexe est légitime : une instance Postgres tourne sans doute déjà, pourquoi en
lancer une seconde ? Trois raisons, dans l'ordre de leur importance réelle.

### 2.1 Les scripts de sauvegarde passent par le conteneur

```bash
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc ...'
```

`backup.sh` et `restore.sh` sont exactement ce qui protège la seule donnée du projet
qu'on ne peut **pas** reconstruire : le code se retrouve dans git, une carte
photographiée et découpée à la main, non.

Partager la base impose de réécrire les deux — et de retester le chemin de restauration,
qui est le seul du dépôt capable de détruire des données de production
(`pg_restore --clean` supprime les tables avant de les recréer). Ce chemin n'a
volontairement jamais été exercé sur une base vivante.

### 2.2 Le couplage des versions

L'image est épinglée sur `postgres:16-alpine`. Si l'hôte tourne en 14 ou 15, le cycle de
vie de TRIALGO devient solidaire de celui des autres sites : plus personne ne peut faire
une montée de version majeure sans arbitrer pour tout le monde à la fois.

### 2.3 Le rayon d'explosion

Une instance partagée, c'est un disque plein, une requête folle ou une erreur de frappe
sur un autre projet qui emporte TRIALGO — et réciproquement.

### Ce que coûte le fait de ne pas partager

**Environ 60 Mo de RAM au repos.** Ce n'est pas un arbitrage serré.

---

## 3. Si vous voulez quand même partager la base

Cas légitime : un VPS vraiment contraint en mémoire. Voici tout ce qui change.

### 3.1 Une surcouche compose

Créer `docker-compose.pg-hote.yml`, à empiler **après** les deux autres :

```yaml
services:

  # Même astuce que pour Caddy : on ne peut pas "supprimer" un service
  # hérité d'un autre fichier compose, mais un profil jamais activé le
  # rend inerte -- ni construit, ni démarré.
  postgres:
    profiles: ["avec-postgres-conteneur"]

  api:
    # Rend l'hôte joignable depuis le conteneur sous un nom stable.
    # L'IP du bridge Docker (172.17.0.1) marche aussi, mais elle change
    # si le réseau est recréé.
    extra_hosts:
      - "host.docker.internal:host-gateway"
    # depends_on: postgres  <-- à retirer, le service n'existe plus
```

Et dans le `.env` :

```
DATABASE_URL=postgresql+asyncpg://trialgo:<mot-de-passe>@host.docker.internal:5432/trialgo
```

```bash
docker compose -f docker-compose.prod.yml \
               -f docker-compose.nginx.yml \
               -f docker-compose.pg-hote.yml up -d --build
```

### 3.2 Côté hôte

Postgres n'écoute par défaut que sur `localhost`, ce qui **exclut** le bridge Docker.

```bash
# postgresql.conf
listen_addresses = 'localhost,172.17.0.1'

# pg_hba.conf -- autoriser le sous-réseau Docker, et lui seul
host    trialgo    trialgo    172.16.0.0/12    scram-sha-256
```

```sql
CREATE USER trialgo WITH PASSWORD '<...>';
CREATE DATABASE trialgo OWNER trialgo;
```

⚠️ Vérifier ensuite que **5432 n'est joignable que depuis la machine** :
`sudo ss -ltnp | grep 5432` ne doit montrer que `127.0.0.1` et `172.17.0.1`,
jamais `0.0.0.0`.

### 3.3 Les sauvegardes

`backup.sh` et `restore.sh` doivent appeler `pg_dump` / `pg_restore` directement sur
l'hôte au lieu de passer par `docker compose exec`. Le reste de leur logique — dump
`-Fc` relu par `pg_restore --list`, miroir cumulatif du bucket, manifeste, purge à
30 jours — reste valable tel quel.

---

## 4. Ce qu'il faut vérifier avant de commencer

À lancer **sur le serveur**, en SSH :

```bash
hostnamectl | head -3; free -h; df -h /
echo "--- ports occupés ---";  sudo ss -ltnp
echo "--- postgres ---";       psql --version 2>/dev/null || echo "absent"
echo "--- docker ---";         docker --version; docker compose version
echo "--- nginx ---";          nginx -v; ls /etc/nginx/sites-enabled/
echo "--- certbot ---";        sudo certbot certificates 2>/dev/null | grep -E "Certificate Name|Domains"
echo "--- dns ---";            dig +short api.mixalgo.com dashboard.mixalgo.com
```

Ce qu'on cherche dans cette sortie, et pourquoi :

| Ligne | Ce qu'on vérifie | Si ça coince |
|---|---|---|
| `ss -ltnp` | **8000, 9000 et 9001 libres** | Décaler dans `docker-compose.nginx.yml` **et** dans les `proxy_pass` des vhosts, sinon nginx pointe dans le vide. |
| `free -h` | Marge mémoire | Sous 2 Go, relire le §3. |
| `sites-enabled/` | Pas de vhost attrape-tout | Un `server_name _;` existant capterait `api.mixalgo.com` avant le nôtre. |
| `dig` | DNS déjà propagé | Certbot refuse d'émettre un certificat pour un domaine qui ne pointe pas sur la machine. Le créer **d'abord**, la propagation prend de quelques minutes à quelques heures. |
| `psql --version` | Version de l'hôte | Uniquement utile si vous choisissez le §3. |

---

## 5. Les secrets ne transitent pas par le dépôt

Le dépôt GitHub est **public**. `.env` est ignoré par git, et il doit le rester :
il contient `JWT_SECRET`, le mot de passe Postgres, les clés MinIO et la clé API Brevo.
Un secret poussé une seule fois reste dans l'historique même après suppression du
fichier — il faut alors le considérer comme compromis et le régénérer.

Les valeurs se fabriquent **sur le serveur**, jamais ailleurs :

```bash
openssl rand -hex 32     # JWT_SECRET
openssl rand -base64 24  # mots de passe Postgres / MinIO
```

Et il faut **sauvegarder le `.env` chiffré, hors de la machine**. Il n'est pas dans le
miroir des sauvegardes : c'est un fichier de secrets, il n'a rien à faire à côté d'un
dump en clair. Le perdre ne détruit pas les données, mais rend le volume Postgres
inutilisable (mot de passe) et invalide tous les jetons déjà émis (`JWT_SECRET`).
Même règle que pour le keystore Android.

---

## 6. Récapitulatif

Ce qu'on prend au serveur : **nginx, certbot, Docker.**
Ce qu'on apporte : **PostgreSQL, MinIO, l'API.**
Ce qu'on ne touche pas : **les sites déjà en production.**

La seule contrainte non négociable est nginx. Tout le reste est un arbitrage entre
mémoire économisée et simplicité d'exploitation — et pour l'instant, la simplicité gagne.
