#!/usr/bin/env bash
# =============================================================
# FICHIER : scripts/preparer_env.sh
# ROLE    : Fabriquer le .env de production, secrets compris
# =============================================================
#
# LE PROBLEME
# -----------
# .env.production.example contient huit valeurs a remplacer, dont six
# sont des secrets a generer. Les recopier a la main est long et se
# rate en silence : un <chevron> oublie dans DATABASE_URL et Postgres
# refuse la connexion avec un message qui parle d'authentification,
# pas de configuration.
#
# Et surtout, oublier l'etape entierement donne ceci, sans que rien
# ne dise quoi faire :
#
#   env file /srv/trialgo/ok_trialgo_backend/.env not found
#   WARN The "POSTGRES_USER" variable is not set. Defaulting to a
#        blank string.
#
# CE QUE FAIT CE SCRIPT
# ---------------------
# Il copie le gabarit, genere les six secrets avec openssl, les
# substitue, et laisse en evidence les valeurs qui ne peuvent pas
# etre devinees -- la cle Brevo aujourd'hui.
#
# Les secrets sont generes SUR LA MACHINE et n'apparaissent nulle
# part ailleurs : ni dans l'historique du shell, ni dans une sortie
# de commande, ni dans une conversation.
#
# POURQUOI DE L'HEXADECIMAL
# -------------------------
# Le mot de passe Postgres est recopie dans DATABASE_URL, une URL.
# Un mot de passe base64 y glisse des `/`, `+` et `=` qu'il faudrait
# encoder en pourcents, faute de quoi la chaine de connexion est
# tronquee au premier caractere special. L'hexadecimal n'a pas ce
# probleme, et sa longueur compense sa faible densite.
#
# USAGE
#   cd /srv/trialgo/ok_trialgo_backend
#   ./scripts/preparer_env.sh
# =============================================================

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GABARIT="$RACINE/.env.production.example"
CIBLE="$RACINE/.env"

# Nom du service Postgres dans docker-compose.prod.yml. C'est le nom
# d'hote que les conteneurs se donnent entre eux sur le reseau Docker.
HOTE_DB="postgres"

if [[ ! -f "$GABARIT" ]]; then
  echo "Gabarit introuvable : $GABARIT" >&2
  exit 1
fi

# Ne JAMAIS ecraser un .env existant : il contient les mots de passe
# du volume Postgres deja initialise. Les regenerer rendrait la base
# inaccessible, avec des donnees intactes mais illisibles.
if [[ -e "$CIBLE" ]]; then
  echo "Un .env existe deja : $CIBLE"
  echo
  echo "Il n'est pas ecrase : ses mots de passe sont ceux du volume"
  echo "Postgres deja initialise. En generer de nouveaux rendrait la"
  echo "base inaccessible sans rien effacer -- le pire des deux mondes."
  echo
  echo "Pour repartir de zero, et SEULEMENT si la base est vide :"
  echo "  mv .env .env.ancien && ./scripts/preparer_env.sh"
  exit 1
fi

echo "Generation des secrets..."
MDP_DB="$(openssl rand -hex 24)"
JWT="$(openssl rand -hex 32)"
CLE_S3="$(openssl rand -hex 10)"
SECRET_S3="$(openssl rand -hex 24)"

cp "$GABARIT" "$CIBLE"
chmod 600 "$CIBLE"

# On substitue les motifs exacts du gabarit. Chaque remplacement est
# verifie ensuite : une modification du gabarit qui ferait manquer un
# motif doit s'entendre tout de suite, pas au demarrage de la stack.
sed -i \
  -e "s|<mot-de-passe-genere>|$MDP_DB|g" \
  -e "s|<hote-db>|$HOTE_DB|g" \
  -e "s|<48-caracteres-aleatoires>|$JWT|g" \
  -e "s|<cle-minio-generee>|$CLE_S3|g" \
  -e "s|<secret-minio-genere>|$SECRET_S3|g" \
  "$CIBLE"

# Reliquat de l'ancien nom du produit dans les courriels sortants.
sed -i -e "s|^BREVO_SENDER_NAME=TRIALGO$|BREVO_SENDER_NAME=MIXALGO|" "$CIBLE"

echo "Ecrit : $CIBLE (permissions 600)"
echo

# ---- Ce qui reste a la main --------------------------------------
# Les lignes de commentaire sont exclues : le gabarit en contient qui
# citent des <chevrons> a titre d'exemple, et les signaler comme
# "a renseigner" enverrait editer des lignes qui n'attendent rien.
RESTANTS="$(grep -n '<[a-z0-9.-]*>' "$CIBLE" | grep -v '^[0-9]*:[[:space:]]*#' || true)"
if [[ -n "$RESTANTS" ]]; then
  echo "A RENSEIGNER A LA MAIN :"
  echo "$RESTANTS" | sed 's/^/  /'
  echo
  echo "  BREVO_API_KEY : sans elle, les courriels sont seulement"
  echo "  journalises (mode DRY-RUN). L'API demarre et fonctionne,"
  echo "  mais aucune reinitialisation de mot de passe ne part."
  echo
  echo "  nano $CIBLE"
else
  echo "Aucun <chevron> restant."
fi

echo
echo "Controle des valeurs qui cassent quelque chose en silence :"
for cle in PUBLIC_BASE_URL S3_PUBLIC_ENDPOINT_URL CORS_ALLOWED_ORIGINS TRUST_PROXY_HEADERS; do
  printf "  %-24s %s\n" "$cle" "$(grep -m1 "^$cle=" "$CIBLE" | cut -d= -f2-)"
done

# S3_PUBLIC_ENDPOINT_URL avec une barre finale donne des images en
# 404 pendant que tout le reste fonctionne : public_url() concatene
# sans normaliser, et le double separateur passe inapercu.
if grep -q '^S3_PUBLIC_ENDPOINT_URL=.*/$' "$CIBLE"; then
  echo
  echo "ATTENTION : S3_PUBLIC_ENDPOINT_URL se termine par une barre." >&2
  echo "Les images repondront 404 alors que tout le reste marchera." >&2
  exit 1
fi

echo
echo "Etape suivante :  mix up -d --build"
