#!/usr/bin/env bash
# =============================================================
# FICHIER : scripts/backup.sh
# ROLE    : Sauvegarder l'etat complet de TRIALGO (base + images)
# =============================================================
#
# Ce que perd exactement un `docker compose down -v` malheureux,
# ou un disque qui lache : les comptes, les codes d'activation
# vendus, les jeux, le graphe de noeuds, les parties jouees, les
# etoiles, le classement -- et les images des cartes, qui sont
# le seul contenu reellement irremplacable du projet. Le code se
# reconstruit depuis git ; une carte photographiee et decoupee a
# la main, non.
#
#
# POURQUOI PAS UNE COPIE DES VOLUMES DOCKER
# -----------------------------------------
# La tentation est de faire `tar` sur pg_data et minio_data. Ce
# serait plus court, et faux :
#
#   - Postgres ecrit en permanence. Copier les fichiers d'un
#     serveur en marche donne une image incoherente : des pages
#     a moitie ecrites, un WAL desynchronise. L'archive se
#     restaure sans erreur visible, et la base refuse de demarrer
#     -- ou pire, demarre avec des donnees corrompues. Une vraie
#     sauvegarde a chaud de fichiers demande pg_basebackup et
#     l'archivage du WAL, une machinerie disproportionnee ici.
#     `pg_dump` prend un instantane transactionnel coherent sans
#     bloquer personne. C'est la bonne granularite pour une base
#     de cette taille.
#
#   - Le volume MinIO contient l'inventaire interne du serveur,
#     lie a sa version. Une archive de `minio_data` ne se
#     restaure de facon sure que dans un MinIO comparable. Les
#     objets eux-memes, eux, se remettent dans n'importe quel S3.
#     On sauvegarde donc le CONTENU du bucket, pas le volume.
#
#
# L'ORDRE COMPTE : LA BASE D'ABORD, LES IMAGES ENSUITE
# ----------------------------------------------------
# Les deux moities ne sont pas prises au meme instant. Une carte
# televersee pendant la sauvegarde tombe forcement d'un cote.
#
#   Base d'abord, puis images  ->  la carte est dans le bucket
#   sauvegarde mais absente de la base. C'est un fichier orphelin :
#   il occupe de la place, personne ne le voit, rien ne casse.
#
#   Images d'abord, puis base  ->  la carte est dans la base mais
#   son fichier manque. La carte s'affiche cassee dans le jeu.
#
# C'est exactement l'arbitrage deja retenu a la suppression d'une
# carte dans l'API (DB d'abord, fichier ensuite) : un orphelin
# vaut mieux qu'une carte fantome. Le meme raisonnement, applique
# ici a l'envers du temps.
#
#
# LES IMAGES SONT CUMULATIVES, PAS DATEES
# ---------------------------------------
# Chaque execution ecrit un dump de base horodate, mais verse les
# images dans UN SEUL dossier `objects/` commun, sans jamais rien
# y supprimer. Deux raisons :
#
#   - Les cles sont des UUID et le contenu est immuable : une
#     copie par jour dupliquerait a l'identique des giga-octets.
#     `mc mirror` ne retransfere que les nouveautes.
#   - Ne rien supprimer protege de la suppression accidentelle :
#     une carte effacee par erreur dans le studio reste sur le
#     disque de sauvegarde, recuperable, meme des mois apres.
#
# Le prix a payer est un dossier qui ne decroit jamais. Vu la
# taille des cartes (JPEG q85, 1024px), c'est negligeable.
#
#
# USAGE
#   ./scripts/backup.sh                 # sauvegarde complete
#   TRIALGO_BACKUP_DIR=/mnt/nas/trialgo ./scripts/backup.sh
#   TRIALGO_COMPOSE_FILE=docker-compose.yml ./scripts/backup.sh
#
# En cron (tous les jours a 3h15, journal dans un fichier) :
#   15 3 * * * cd /srv/trialgo/ok_trialgo_backend && \
#              ./scripts/backup.sh >> /var/log/trialgo-backup.log 2>&1
# =============================================================

set -euo pipefail

# --- Reglages -----------------------------------------------
# Le dossier de destination. Par defaut sur la machine ; voir la
# section "Hors de la machine" du README pour la copie distante,
# qui est ce qui transforme ceci en vraie sauvegarde.
DEST="${TRIALGO_BACKUP_DIR:-/var/backups/trialgo}"

# Nombre de jours de dumps de base conserves. Les images, elles,
# ne sont jamais purgees (voir plus haut).
RETENTION_JOURS="${TRIALGO_BACKUP_RETENTION:-30}"

# Fichier compose a utiliser. La prod par defaut ; en dev,
# surcharger avec TRIALGO_COMPOSE_FILE=docker-compose.yml.
COMPOSE_FILE="${TRIALGO_COMPOSE_FILE:-docker-compose.prod.yml}"

# --- Contexte -----------------------------------------------
# On se place a la racine du backend quel que soit l'endroit
# d'ou le script est appele (cron n'a pas le meme cwd qu'un
# shell interactif -- c'est la premiere cause de tache planifiee
# qui "ne fait rien" sans erreur).
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "ERREUR : $COMPOSE_FILE introuvable depuis $RACINE" >&2
  echo "        Preciser TRIALGO_COMPOSE_FILE si la stack est ailleurs." >&2
  exit 1
fi

COMPOSE=(docker compose -f "$COMPOSE_FILE")

HORODATAGE="$(date +%Y-%m-%d_%H%M%S)"
DOSSIER_DUMPS="$DEST/postgres"
DOSSIER_OBJETS="$DEST/objects"
DUMP="$DOSSIER_DUMPS/trialgo_$HORODATAGE.dump"

mkdir -p "$DOSSIER_DUMPS" "$DOSSIER_OBJETS"

echo "==> Sauvegarde TRIALGO  ($HORODATAGE)"
echo "    destination : $DEST"
echo "    stack       : $COMPOSE_FILE"

# --- Verification prealable ---------------------------------
# Sauvegarder une stack a l'arret produirait un dump vide sans
# que rien ne le signale. On refuse plutot que de mentir.
if ! "${COMPOSE[@]}" ps --status running --services 2>/dev/null | grep -qx postgres; then
  echo "ERREUR : le service postgres ne tourne pas. Rien n'a ete sauvegarde." >&2
  exit 1
fi

# --- 1. La base ---------------------------------------------
# `exec -T` : pas de pseudo-terminal, sinon la sortie binaire du
# dump est corrompue par la traduction des fins de ligne.
#
# POSTGRES_USER et POSTGRES_DB sont lus DANS le conteneur, pas
# depuis .env : ils y sont deja, et le script n'a ainsi jamais
# besoin de toucher au fichier de secrets.
#
# -Fc : format "custom" -- compresse, et surtout restaurable
# table par table avec pg_restore, ce qu'un dump SQL a plat ne
# permet pas.
echo "--> 1/3  Dump de la base"
"${COMPOSE[@]}" exec -T postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc --no-owner --no-privileges' \
  > "$DUMP"

# Un dump tronque par un disque plein pese quelques octets et ne
# provoque aucune erreur : la redirection reussit, pg_dump meurt
# en silence de l'autre cote du tube. On relit donc la table des
# matieres de l'archive, seule preuve qu'elle est exploitable.
echo "--> 2/3  Verification de l'archive"
if ! "${COMPOSE[@]}" exec -T postgres pg_restore --list < "$DUMP" > /dev/null 2>&1; then
  echo "ERREUR : le dump produit est illisible. Il est supprime." >&2
  rm -f "$DUMP"
  exit 1
fi
TAILLE_DUMP="$(du -h "$DUMP" | cut -f1)"
echo "         OK  ($TAILLE_DUMP)"

# --- 2. Les images ------------------------------------------
# On reutilise le service `create_bucket` : c'est deja l'image
# minio/mc, deja branchee au reseau interne, et ses cles S3 sont
# deja injectees par compose. --no-deps evite de reveiller MinIO
# si la stack est partiellement arretee, --entrypoint remplace
# le script de creation du bucket.
echo "--> 3/3  Miroir des images du bucket"
"${COMPOSE[@]}" run --rm --no-deps \
  -v "$DOSSIER_OBJETS:/sauvegarde" \
  --entrypoint sh create_bucket -c '
    set -e
    mc alias set src "http://minio:9000" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" >/dev/null
    # Pas de --remove : le miroir ne fait que grossir, une carte
    # supprimee par erreur reste recuperable.
    mc mirror --overwrite "src/$S3_BUCKET" /sauvegarde
  ' 2>&1 | sed 's/^/         /'

NB_OBJETS="$(find "$DOSSIER_OBJETS" -type f | wc -l)"
TAILLE_OBJETS="$(du -sh "$DOSSIER_OBJETS" | cut -f1)"

# --- 3. Manifeste -------------------------------------------
# Une sauvegarde sans inventaire ne dit pas ce qu'elle contient.
# Ce fichier permet, six mois plus tard, de choisir quel dump
# restaurer sans avoir a tous les ouvrir.
cat > "$DOSSIER_DUMPS/trialgo_$HORODATAGE.txt" <<MANIFESTE
Sauvegarde TRIALGO
date            : $(date -Iseconds)
machine         : $(hostname)
stack           : $COMPOSE_FILE
dump base       : $(basename "$DUMP")  ($TAILLE_DUMP)
images (cumul)  : $NB_OBJETS fichiers, $TAILLE_OBJETS
version alembic : $("${COMPOSE[@]}" exec -T api alembic current 2>/dev/null | tail -1 || echo "indisponible")
MANIFESTE

# --- 4. Purge -----------------------------------------------
# Seuls les dumps de base sont purges. Les images ne le sont
# jamais : elles sont cumulatives par construction.
SUPPRIMES="$(find "$DOSSIER_DUMPS" -type f \( -name 'trialgo_*.dump' -o -name 'trialgo_*.txt' \) \
             -mtime "+$RETENTION_JOURS" -print -delete | wc -l)"

echo
echo "==> Termine."
echo "    base    : $DUMP  ($TAILLE_DUMP)"
echo "    images  : $NB_OBJETS fichiers, $TAILLE_OBJETS  (cumulatif)"
echo "    purge   : $SUPPRIMES fichiers de plus de $RETENTION_JOURS jours"
