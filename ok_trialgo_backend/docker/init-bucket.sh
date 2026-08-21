#!/bin/sh
# =============================================================
# FICHIER : docker/init-bucket.sh
# ROLE    : Creer le bucket des cartes et poser sa politique
# =============================================================
#
# Execute par le service `create_bucket` a chaque demarrage de la
# stack. Idempotent : creer un bucket existant ou reposer la meme
# politique ne fait rien de plus.
#
# POURQUOI CE SCRIPT REMPLACE `mc anonymous set download`
# ------------------------------------------------------
# La commande precedente etait :
#
#     mc anonymous set download local/$S3_BUCKET
#
# Elle a l'air anodine, et son nom suggere "lecture seule". La
# politique qu'elle installe reellement est celle-ci :
#
#     s3:GetBucketLocation + s3:ListBucket  sur le bucket
#     s3:GetObject                          sur bucket/*
#
# Le probleme est `s3:ListBucket`. Il autorise n'importe qui a
# demander l'INVENTAIRE du bucket :
#
#     curl https://api.mixalgo.com/files/trialgo-cards/
#
# ... qui repond par un XML listant toutes les cles, de tous les
# jeux. Or une cle suffit a telecharger l'image. Autrement dit :
# le catalogue complet des cartes -- c'est-a-dire l'integralite du
# contenu du produit -- devenait aspirable en deux commandes, sans
# authentification et sans laisser de trace exploitable.
#
# CE QU'ON POSE A LA PLACE
# ------------------------
# Uniquement s3:GetObject sur bucket/*. Consequence :
#
#   - une URL d'image connue fonctionne toujours (c'est ce dont le
#     jeu a besoin : les image_url sont distribuees par l'API aux
#     utilisateurs authentifies) ;
#   - l'inventaire renvoie desormais AccessDenied.
#
# Les cles etant des UUID v4, elles ne se devinent pas. Sans la
# liste, il n'y a plus de porte d'entree.
#
# CE QUE CETTE POLITIQUE NE PROTEGE PAS
# -------------------------------------
# Un utilisateur legitime qui recupere les image_url par l'API peut
# toujours telecharger les cartes du jeu qu'il a active. C'est
# inherent au choix d'un bucket public, assume ici : les images
# doivent s'afficher dans l'application sans jeton. Ce qu'on ferme,
# c'est l'acces massif et anonyme, par un tiers qui n'a active
# aucun jeu.
# =============================================================

set -e

mc alias set local "http://minio:9000" "$S3_ACCESS_KEY" "$S3_SECRET_KEY"

# -p : ne proteste pas si le bucket existe deja.
mc mb -p "local/$S3_BUCKET"

# Politique explicite : lecture d'objet, et rien d'autre.
# On l'ecrit dans un fichier car `mc anonymous set-json` attend un
# chemin, pas une chaine.
cat > /tmp/politique-cartes.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LectureAnonymeDesImagesUniquement",
      "Effect": "Allow",
      "Principal": { "AWS": ["*"] },
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::$S3_BUCKET/*"]
    }
  ]
}
JSON

mc anonymous set-json /tmp/politique-cartes.json "local/$S3_BUCKET"

echo "Bucket pret : lecture d'objet anonyme, inventaire interdit."
