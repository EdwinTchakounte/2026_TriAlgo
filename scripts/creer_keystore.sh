#!/usr/bin/env bash
# =============================================================
# FICHIER : scripts/creer_keystore.sh
# ROLE    : Creer la cle de signature Android de MIXALGO, une
#           fois pour toute la vie des deux applications
# =============================================================
#
# CE QUE FAIT CE SCRIPT
# ---------------------
# Il fabrique UN fichier .jks contenant DEUX cles (deux alias) :
#
#   mixalgo        -> l'app joueur      (com.mixalgo.app)
#   mixalgo-admin  -> le studio admin   (com.trialgo.trialgo_admin)
#
# puis il ecrit les deux fichiers android/key.properties qui
# disent a Gradle ou trouver cette cle. Sans eux, `flutter build`
# retombe sur la cle de DEBUG et produit un binaire non publiable.
#
#
# POURQUOI UN SEUL FICHIER POUR DEUX APPLICATIONS
# -----------------------------------------------
# Rien n'oblige deux applications a partager un keystore : elles
# ont des applicationId distincts, Android ne les rapproche
# jamais. Mais un keystore est un objet qu'on doit sauvegarder,
# chiffrer et ne jamais perdre pendant dix ans. En avoir deux,
# c'est doubler le nombre d'occasions d'en egarer un. Deux alias
# dans un meme fichier donnent deux cles reellement distinctes --
# compromettre celle du studio ne compromet pas celle du joueur --
# pour une seule chose a proteger.
#
#
# POURQUOI LE .JKS EST CREE HORS DU DEPOT
# ---------------------------------------
# Par defaut dans ~/.mixalgo-cles/ et non dans le depot. Les
# regles .gitignore couvrent bien `**/*.jks`, mais une regle
# .gitignore est une ligne qu'un `git add -f` contourne et qu'une
# reecriture de fichier peut supprimer. Le depot 2026_TriAlgo est
# PUBLIC : une cle privee poussee une seule fois, meme retiree
# ensuite, doit etre consideree comme compromise a jamais. Le
# meilleur moyen de ne pas committer un fichier reste qu'il ne
# soit pas dans l'arborescence du depot.
#
#
# CE QUE CE SCRIPT NE FAIT PAS
# ----------------------------
# Il ne choisit pas vos mots de passe et ne les stocke nulle part
# ailleurs que dans les key.properties, qui sont ignores par git.
# Vous les saisissez, ils ne transitent par rien d'autre.
#
#
# CE QUI SE PASSE SI VOUS PERDEZ CE FICHIER
# -----------------------------------------
# Android refuse toute mise a jour signee par une cle differente
# de celle de l'installation existante. Perdre le .jks ou son mot
# de passe, c'est ne plus jamais pouvoir mettre a jour MIXALGO
# chez les joueurs qui l'ont deja : ils devraient desinstaller --
# et perdre leur progression -- pour installer la suite. Il n'y a
# aucun recours, aucune procedure de secours, chez Google ou
# ailleurs. En faire une sauvegarde chiffree hors de ce poste
# est la seule protection qui existe.
# =============================================================

set -euo pipefail

# -------------------------------------------------------------
# Emplacements
# -------------------------------------------------------------
# On resout la racine du depot depuis la position du script, et
# non depuis $PWD : le script doit marcher qu'on l'appelle depuis
# la racine, depuis scripts/, ou par un chemin absolu.
RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DOSSIER_CLES="${MIXALGO_DOSSIER_CLES:-$HOME/.mixalgo-cles}"
KEYSTORE="$DOSSIER_CLES/mixalgo-release.jks"

ALIAS_JOUEUR="mixalgo"
ALIAS_ADMIN="mixalgo-admin"

# Validite en jours. 10000 jours ~ 27 ans. Google Play exige une
# cle valide au-dela du 22 octobre 2033 ; une cle courte rendrait
# les mises a jour impossibles bien avant la fin du produit.
VALIDITE=10000

# Le nom distinctif (-dname) est fourni en une seule chaine plutot
# que par les questions interactives de keytool. Ces champs ne
# servent a rien fonctionnellement -- Android ne verifie que
# l'empreinte de la cle -- mais keytool les exige, et les laisser
# en mode question ferait dix invites de plus a traverser.
DNAME="CN=MIXALGO, OU=MIXALGO, O=MIXALGO, L=Douala, ST=Littoral, C=CM"

rouge()  { printf '\033[31m%s\033[0m\n' "$*"; }
vert()   { printf '\033[32m%s\033[0m\n' "$*"; }
jaune()  { printf '\033[33m%s\033[0m\n' "$*"; }
titre()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

# -------------------------------------------------------------
# 1. Verifications prealables
# -------------------------------------------------------------
titre "1/5  Verifications"

if ! command -v keytool >/dev/null 2>&1; then
  rouge "keytool est introuvable."
  echo "Il est fourni avec le JDK. Sur Debian/Ubuntu :"
  echo "  sudo apt install default-jdk"
  exit 1
fi
vert "  keytool present : $(command -v keytool)"

# Refus net si le keystore existe deja. L'ecraser detruirait la
# cle de publication en cours -- exactement le scenario decrit
# en tete de fichier. On ne propose meme pas de forcer.
if [ -f "$KEYSTORE" ]; then
  rouge "Un keystore existe deja : $KEYSTORE"
  echo
  echo "Ce script ne l'ecrasera pas : ce serait detruire la cle de"
  echo "publication de MIXALGO, sans retour possible."
  echo
  echo "Pour en inspecter le contenu :"
  echo "  keytool -list -v -keystore \"$KEYSTORE\""
  exit 1
fi

mkdir -p "$DOSSIER_CLES"
# 700 : lisible par vous seul. Un keystore est protege par son
# mot de passe, mais un fichier que personne d'autre ne peut lire
# est une serrure de plus, gratuite.
chmod 700 "$DOSSIER_CLES"
vert "  dossier des cles : $DOSSIER_CLES (permissions 700)"

# -------------------------------------------------------------
# 2. Saisie du mot de passe
# -------------------------------------------------------------
titre "2/5  Mot de passe du keystore"

cat <<'TXT'
  Choisissez un mot de passe d'au moins 6 caracteres (limite de
  keytool). Il protege la cle privee de vos deux applications.

  Notez-le AILLEURS que sur ce poste, maintenant : gestionnaire
  de mots de passe, ou papier dans un tiroir. Le retrouver plus
  tard sera impossible.

  La saisie n'affiche rien a l'ecran, c'est normal.

TXT

# La saisie se fait sur /dev/tty et non sur l'entree standard.
# La difference compte : lance depuis un outil qui redirige stdin
# (un agent, un pipe, une tache planifiee), un `read` classique
# recoit immediatement une fin de fichier. Avec `set -e` le script
# s'arrete alors en silence, juste apres avoir affiche l'invite --
# on croit avoir tape un mot de passe, et rien n'a ete cree.
# /dev/tty designe toujours le terminal de controle, quelle que
# soit la redirection.
# On TENTE l'ouverture plutot que de tester `-r /dev/tty` : sans
# terminal de controle, le fichier existe et parait lisible, mais
# l'open echoue avec "No such device or address". Seule une
# ouverture reelle repond a la question.
if ! (exec < /dev/tty) 2>/dev/null; then
  rouge "Aucun terminal disponible pour saisir le mot de passe."
  echo
  echo "Ce script doit etre lance depuis un vrai terminal, et non"
  echo "au travers d'un outil qui redirige l'entree standard."
  echo
  echo "Ouvrez un terminal et relancez :"
  echo "  cd $RACINE && ./scripts/creer_keystore.sh"
  exit 1
fi

read -r -s -p "  Mot de passe          : " MDP < /dev/tty; echo
read -r -s -p "  Confirmez             : " MDP2 < /dev/tty; echo

if [ "$MDP" != "$MDP2" ]; then
  rouge "Les deux saisies different. Rien n'a ete cree."
  exit 1
fi
if [ ${#MDP} -lt 6 ]; then
  rouge "Mot de passe trop court : keytool en exige 6 au minimum."
  exit 1
fi
unset MDP2
vert "  mot de passe accepte"

# -------------------------------------------------------------
# 3. Generation des deux cles
# -------------------------------------------------------------
titre "3/5  Generation des cles"

# Le mot de passe est transmis a keytool par son entree standard,
# et non par -storepass sur la ligne de commande : un argument de
# ligne de commande est visible par tout utilisateur de la machine
# dans `ps aux` pendant l'execution.
#
# keytool pose ici deux questions : le mot de passe du keystore,
# puis celui de la cle ("RETURN if same as keystore password").
# La ligne vide repond "le meme", ce que Gradle attend puisque
# key.properties donne la meme valeur aux deux champs.

genere_cle() {
  local alias="$1" libelle="$2"
  printf '%s\n%s\n\n' "$MDP" "$MDP" | keytool -genkeypair \
    -alias "$alias" \
    -keystore "$KEYSTORE" \
    -storetype JKS \
    -keyalg RSA -keysize 2048 \
    -validity "$VALIDITE" \
    -dname "$DNAME" \
    >/dev/null 2>&1
  vert "  cle creee : $alias  ($libelle)"
}

# La toute premiere generation cree aussi le fichier keystore.
# keytool demande alors le mot de passe deux fois (saisie et
# confirmation) au lieu d'une : d'ou les deux %s du printf.
genere_cle "$ALIAS_JOUEUR" "app joueur, com.mixalgo.app"
genere_cle "$ALIAS_ADMIN"  "studio admin, com.trialgo.trialgo_admin"

chmod 600 "$KEYSTORE"

# -------------------------------------------------------------
# 4. Ecriture des deux key.properties
# -------------------------------------------------------------
titre "4/5  Fichiers key.properties"

# storeFile est resolu par Gradle avec rootProject.file(), donc
# relativement au dossier android/. On y met un chemin ABSOLU :
# le keystore vit hors du depot, aucun chemin relatif ne serait
# a la fois juste et lisible.

ecrit_properties() {
  local dossier="$1" alias="$2" app="$3"
  local cible="$dossier/key.properties"

  if [ -f "$cible" ]; then
    jaune "  $cible existe deja -- conserve, non ecrase"
    return
  fi

  cat > "$cible" <<PROPS
# =============================================================
# key.properties  -  signature Android de $app
# =============================================================
# Genere par scripts/creer_keystore.sh.
#
# Ce fichier contient des mots de passe : il est ignore par git
# (voir android/.gitignore) et ne doit jamais etre partage.
#
# Le keystore qu'il designe est la cle de publication de MIXALGO.
# Le perdre interdit definitivement toute mise a jour de l'app
# chez les joueurs qui l'ont deja installee.
# =============================================================

keyAlias=$alias
keyPassword=$MDP
storeFile=$KEYSTORE
storePassword=$MDP
PROPS

  chmod 600 "$cible"
  vert "  ecrit : $cible"
}

ecrit_properties "$RACINE/trialgo/android"         "$ALIAS_JOUEUR" "l'app joueur"
ecrit_properties "$RACINE/ok_trialgo_admin/android" "$ALIAS_ADMIN"  "le studio admin"

unset MDP

# -------------------------------------------------------------
# 5. Verification
# -------------------------------------------------------------
titre "5/5  Verification"

# On relit le keystore pour confirmer que les deux alias y sont.
# Cette lecture ne demande pas le mot de passe : lister les
# entrees d'un keystore est une operation publique, seule
# l'extraction des cles privees est protegee.
keytool -list -keystore "$KEYSTORE" -storepass:env VIDE 2>/dev/null \
  | grep -E "^($ALIAS_JOUEUR|$ALIAS_ADMIN)," \
  || keytool -list -keystore "$KEYSTORE" </dev/null 2>/dev/null \
  | grep -E "^($ALIAS_JOUEUR|$ALIAS_ADMIN)," \
  || jaune "  (liste non affichable sans mot de passe, ce n'est pas une erreur)"

cat <<TXT

$(vert "Keystore cree.")

  Fichier   : $KEYSTORE
  Alias     : $ALIAS_JOUEUR (joueur), $ALIAS_ADMIN (admin)
  Validite  : $VALIDITE jours

$(jaune "A FAIRE MAINTENANT, ET UNE SEULE FOIS :")

  1. Sauvegarder le keystore hors de ce poste, chiffre :

       gpg -c "$KEYSTORE"
       # puis deposer le .gpg sur une cle USB ou un stockage
       # distant, et noter la phrase de passe avec le reste

  2. Verifier que rien de tout cela n'entre dans git :

       cd "$RACINE" && git status --short

     Ni le .jks (il est hors du depot) ni les key.properties
     (ignores) ne doivent apparaitre. Le depot est PUBLIC.

  3. Reconstruire les binaires, qui seront alors signes :

       cd "$RACINE/trialgo"          && flutter build apk --release -t lib/main_wireframe.dart
       cd "$RACINE/ok_trialgo_admin" && flutter build apk --release

TXT
