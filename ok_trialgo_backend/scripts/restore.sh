#!/usr/bin/env bash
# =============================================================
# FICHIER : scripts/restore.sh
# ROLE    : Remettre TRIALGO dans l'etat d'une sauvegarde
# =============================================================
#
# Le pendant de backup.sh. Il existe pour une raison simple :
# une sauvegarde qu'on n'a jamais restauree n'est pas une
# sauvegarde, c'est une intention. Les modes de defaillance d'une
# restauration (mauvais utilisateur, extensions manquantes,
# version d'Alembic decalee) ne se decouvrent pas le jour du
# sinistre.
#
# A ESSAYER UNE FOIS, A FROID, AVANT D'EN AVOIR BESOIN.
#
#
# CE QUE FAIT LA RESTAURATION
# ---------------------------
#   1. Ecrase le contenu de la base par celui du dump choisi.
#   2. Reverse les images sauvegardees dans le bucket.
#
# L'ordre est ici l'inverse de la sauvegarde -- images d'abord
# serait tentant, mais peu importe : pendant une restauration la
# stack ne sert personne. On garde l'ordre base puis images pour
# rester lisible.
#
#
# CE QU'ELLE N'EST PAS
# --------------------
# `pg_restore --clean` SUPPRIME les tables existantes avant de
# les recreer. Toute donnee posterieure au dump disparait. Ce
# n'est pas une fusion, c'est un retour en arriere. D'ou la
# confirmation explicite exigee plus bas : ce script est le seul
# du depot capable de detruire des donnees de production.
#
#
# USAGE
#   ./scripts/restore.sh                          # liste les dumps
#   ./scripts/restore.sh <chemin-du-dump>         # demande confirmation
#   ./scripts/restore.sh <dump> --je-confirme     # sans question (cron, CI)
#   ./scripts/restore.sh <dump> --base-seulement  # sans les images
# =============================================================

set -euo pipefail

DEST="${TRIALGO_BACKUP_DIR:-/var/backups/trialgo}"
COMPOSE_FILE="${TRIALGO_COMPOSE_FILE:-docker-compose.prod.yml}"

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"
COMPOSE=(docker compose -f "$COMPOSE_FILE")

DUMP="${1:-}"
CONFIRME=0
IMAGES=1
for arg in "${@:2}"; do
  case "$arg" in
    --je-confirme)     CONFIRME=1 ;;
    --base-seulement)  IMAGES=0 ;;
    *) echo "Option inconnue : $arg" >&2; exit 1 ;;
  esac
done

# --- Sans argument : on inventorie ---------------------------
if [ -z "$DUMP" ]; then
  echo "Sauvegardes disponibles dans $DEST/postgres :"
  echo
  if ! ls "$DEST"/postgres/*.dump >/dev/null 2>&1; then
    echo "  (aucune)"
    exit 1
  fi
  # Le manifeste ecrit par backup.sh porte le meme nom que le
  # dump ; on l'affiche pour eviter d'avoir a ouvrir l'archive.
  for d in "$DEST"/postgres/*.dump; do
    printf '  %s  (%s)\n' "$d" "$(du -h "$d" | cut -f1)"
    m="${d%.dump}.txt"
    [ -f "$m" ] && sed 's/^/      /' "$m"
    echo
  done
  echo "Relancer avec :  $0 <chemin-du-dump>"
  exit 0
fi

[ -f "$DUMP" ] || { echo "ERREUR : $DUMP introuvable" >&2; exit 1; }

# --- Confirmation --------------------------------------------
if [ "$CONFIRME" -eq 0 ]; then
  echo
  echo "  ATTENTION"
  echo "  ---------"
  echo "  La base de la stack '$COMPOSE_FILE' va etre ECRASEE par :"
  echo "      $DUMP"
  echo "  Toute donnee posterieure a cette sauvegarde sera perdue."
  echo
  printf "  Taper exactement  RESTAURER  pour continuer : "
  read -r reponse
  [ "$reponse" = "RESTAURER" ] || { echo "  Annule."; exit 1; }
fi

# --- 1. La base ----------------------------------------------
# --clean --if-exists : on part d'un schema propre. Sans
#   --if-exists, pg_restore hurle sur chaque objet absent d'une
#   base neuve et sort en erreur alors que tout va bien.
# --no-owner : le dump a ete pris sans proprietaires, on ne
#   tente pas de reattribuer a des roles qui n'existent pas ici.
# --single-transaction : tout ou rien. Une restauration a moitie
#   appliquee est pire que pas de restauration du tout.
echo "--> 1/2  Restauration de la base"
"${COMPOSE[@]}" exec -T postgres sh -c \
  'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
      --clean --if-exists --no-owner --no-privileges --single-transaction' \
  < "$DUMP"
echo "         OK"

# --- 2. Les images -------------------------------------------
if [ "$IMAGES" -eq 1 ]; then
  DOSSIER_OBJETS="$DEST/objects"
  if [ -d "$DOSSIER_OBJETS" ]; then
    echo "--> 2/2  Renvoi des images vers le bucket"
    # Sens inverse du miroir de sauvegarde. Toujours sans
    # --remove : on ajoute ce qui manque, on ne casse rien de ce
    # qui est deja en place.
    #
    # On rejoue d'abord init-bucket.sh (deja monte dans ce service,
    # et idempotent). Sur un serveur reconstruit de zero le bucket
    # n'existe pas encore ; un simple `mc mb` le creerait SANS sa
    # politique de lecture anonyme, et toutes les cartes
    # repondraient 403 une fois restaurees -- une panne d'autant
    # plus deroutante que la base, elle, serait parfaite. Passer
    # par le script garde une seule definition de cette politique.
    "${COMPOSE[@]}" run --rm --no-deps \
      -v "$DOSSIER_OBJETS:/sauvegarde:ro" \
      --entrypoint sh create_bucket -c '
        set -e
        sh /init-bucket.sh
        mc alias set dst "http://minio:9000" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" >/dev/null
        mc mirror --overwrite /sauvegarde "dst/$S3_BUCKET"
      ' 2>&1 | sed 's/^/         /'
  else
    echo "--> 2/2  Aucun dossier d'images dans $DEST, ignore."
  fi
else
  echo "--> 2/2  Images ignorees (--base-seulement)"
fi

# --- 3. Alignement des migrations ----------------------------
# Le dump porte le schema de son epoque, y compris la ligne
# alembic_version. Si le code deploye est plus recent, il faut
# rejouer les migrations manquantes -- sinon l'API demarre sur un
# schema qu'elle ne connait plus, et echoue a la premiere requete
# touchant une colonne ajoutee depuis.
echo
echo "==> Restauration terminee."
echo "    Verifier ensuite l'alignement du schema :"
echo "        docker compose -f $COMPOSE_FILE exec api alembic current"
echo "        docker compose -f $COMPOSE_FILE exec api alembic upgrade head"
