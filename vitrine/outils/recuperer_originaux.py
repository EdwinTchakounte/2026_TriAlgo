#!/usr/bin/env python3
# =============================================================
# FICHIER : vitrine/outils/recuperer_originaux.py
# ROLE    : Rapatrier les illustrations ORIGINALES des cartes
#           (sans cadre ni texte) depuis l'API publique, et en
#           produire les WebP servis par la vitrine
# =============================================================
#
# POURQUOI CE SCRIPT EXISTE
# -------------------------
# Les visuels de assets/cartes/ sont extraits de la planche
# d'impression (extraire_cartes.py) : ce sont les cartes telles
# qu'on les tient en main, cadre orange, nom, code et attributs
# compris. Sur un ecran, ce cadre est du bruit : il reduit
# l'illustration -- ce qui porte le jeu -- a la moitie de la
# surface, et le meme cadre repete douze fois uniformise tout.
#
# Les illustrations brutes, elles, existent deja : ce sont les
# images televersees dans le studio pour le jeu en production.
# L'API les sert sans authentification (GET /api/public/...),
# precisement pour la vitrine. Ce script les rapatrie UNE FOIS et
# les fige dans le depot :
#
#   - la page s'affiche complete meme si l'API est injoignable ;
#   - le premier rendu ne depend d'aucun appel reseau ;
#   - les images sont recadrees et compressees pour le web, ce que
#     l'API ne fait pas (elle sert du 1024 px JPEG).
#
# Le contenu EDITABLE depuis le studio (galerie de la page
# d'accueil) passe, lui, par /api/public/site/accueil : ce dossier
# n'est que le socle par defaut.
#
# CE QUE LE SCRIPT PRODUIT
# ------------------------
#   assets/originaux/<CODE>-480.webp    grille, eventail, demo
#   assets/originaux/<CODE>-960.webp    ecrans a haute densite
#
# Format 4:5 (portrait) : c'est le rapport des cartes physiques a
# peu de chose pres (63 x 88 mm vaut 0,72, 4:5 vaut 0,8) et celui
# des illustrations sources (928 x 1024 = 0,91), qu'il suffit de
# rogner legerement sur les cotes. Rogner au centre garde le
# personnage, toujours centre dans ces compositions.
#
# USAGE
# -----
#   python3 vitrine/outils/recuperer_originaux.py
#   python3 vitrine/outils/recuperer_originaux.py --jeu "MixAlgo Puzzle 1"
#
# Dependance : pillow.
# =============================================================

import argparse
import io
import json
import sys
import urllib.request
from pathlib import Path

from PIL import Image

RACINE = Path(__file__).resolve().parents[2]
DOSSIER = RACINE / "vitrine" / "assets" / "originaux"
API = "https://api.mixalgo.com"
JEU_DEFAUT = "MixAlgo Puzzle 1"

# Deux largeurs, sans plus : 480 couvre une carte de ~240 px
# affichee sur un ecran de densite 2, 960 le hero et la demo sur
# grand ecran. Une troisieme largeur alourdirait le depot pour un
# gain invisible.
LARGEURS = (480, 960)
RAPPORT = 4 / 5
QUALITE = 80


def lire_json(url: str):
    # Un User-Agent explicite : certains pare-feu applicatifs
    # rejettent celui de urllib par defaut.
    requete = urllib.request.Request(url, headers={"User-Agent": "mixalgo-vitrine"})
    with urllib.request.urlopen(requete, timeout=30) as reponse:
        return json.load(reponse)


def lire_octets(url: str) -> bytes:
    requete = urllib.request.Request(url, headers={"User-Agent": "mixalgo-vitrine"})
    with urllib.request.urlopen(requete, timeout=60) as reponse:
        return reponse.read()


def rogner_au_rapport(image: Image.Image) -> Image.Image:
    # On retire ce qui depasse du rapport 4:5, a parts egales des
    # deux cotes : rognage CENTRE, jamais de deformation.
    largeur, hauteur = image.size
    if largeur / hauteur > RAPPORT:
        cible = round(hauteur * RAPPORT)
        marge = (largeur - cible) // 2
        return image.crop((marge, 0, marge + cible, hauteur))
    cible = round(largeur / RAPPORT)
    marge = (hauteur - cible) // 2
    return image.crop((0, marge, largeur, marge + cible))


def main() -> None:
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument("--jeu", default=JEU_DEFAUT,
                         help="nom exact du jeu source en production")
    parseur.add_argument("--api", default=API)
    args = parseur.parse_args()

    jeux = lire_json(f"{args.api}/api/public/games")
    jeu = next((j for j in jeux if j["name"] == args.jeu), None)
    if jeu is None:
        noms = ", ".join(j["name"] for j in jeux)
        raise SystemExit(f"Jeu « {args.jeu} » introuvable. Disponibles : {noms}")

    cartes = lire_json(f"{args.api}/api/public/games/{jeu['id']}/cards")
    DOSSIER.mkdir(parents=True, exist_ok=True)

    # Un meme code peut figurer plusieurs fois dans un jeu (exemplaires
    # multiples d'une carte commune a plusieurs trios). Une seule image
    # par code suffit a la vitrine : on garde la premiere.
    vus: set[str] = set()
    for carte in cartes:
        code = carte["label"].strip().upper()
        if code in vus:
            continue
        vus.add(code)
        # image_url et non thumb_url : la vignette fait 256 px, trop
        # petite pour la version 960.
        source = Image.open(io.BytesIO(lire_octets(carte["image_url"]))).convert("RGB")
        portrait = rogner_au_rapport(source)
        for largeur in LARGEURS:
            hauteur = round(largeur / RAPPORT)
            sortie = portrait.resize((largeur, hauteur), Image.LANCZOS)
            sortie.save(DOSSIER / f"{code}-{largeur}.webp", "WEBP",
                        quality=QUALITE, method=6)
        print(f"  {code}")

    print(f"{len(vus)} illustrations ecrites dans {DOSSIER.relative_to(RACINE)}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
