#!/usr/bin/env python3
# =============================================================
# FICHIER : vitrine/outils/extraire_cartes.py
# ROLE    : Tirer les visuels de cartes de la planche d'impression
# =============================================================
#
# LA SOURCE
# ---------
# TRIALGO_15_cartes_A4_63x88mm-1.pdf est une planche d'impression :
# quinze cartes au format 63 x 88 mm sur deux pages A4, produites
# pour etre decoupees. Chaque carte y est une image bitmap de
# 1109 x 1575 pixels, soit environ 450 points par pouce.
#
# CE QUE FAIT CE SCRIPT
# ---------------------
# Il extrait ces quinze images, les dedoublonne par code de carte,
# et les reduit au format du web.
#
# POURQUOI DES DOUBLONS
# ---------------------
# KEZEU (B3) apparait TROIS fois sur la planche, MILLA (Z8) deux
# fois. Ce n'est pas une erreur de mise en page : KEZEU est
# l'emettrice partagee des trois trios que la planche permet de
# composer, et on ne peut pas poser trois trios simultanement sur
# une table avec un seul exemplaire de la carte commune.
#
#   B3 + Z8 = L9      KEZEU + MILLA    = TUEKAM
#   B3 + M3 = A4      KEZEU + BABADJI  = BEMA
#   B3 + C7 = N1      KEZEU + BIKOKO   = WAKAM
#
# Les exemplaires sont le meme dessin a des echelles legerement
# differentes, d'ou des empreintes de fichier distinctes. On garde
# le plus grand de chaque code.
#
# POURQUOI LE PDF N'EST PAS DANS LE DEPOT
# ---------------------------------------
# Il pese 47 Mo. Git conserve chaque version pour toujours : deux
# revisions de la planche suffiraient a alourdir le depot de cent
# megaoctets que plus personne ne pourrait retirer sans reecrire
# l'historique. Ce sont les WebP produits ici, environ 300 Ko en
# tout, qui sont versionnes.
#
# Consequence a connaitre : regenerer les visuels demande d'avoir
# le PDF sous la main. Il n'est pas reconstructible depuis le depot.
#
# USAGE
#   python3 vitrine/outils/extraire_cartes.py
#   python3 vitrine/outils/extraire_cartes.py --pdf autre-planche.pdf
# =============================================================

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

RACINE = Path(__file__).resolve().parents[2]
PDF_DEFAUT = RACINE / "TRIALGO_15_cartes_A4_63x88mm-1.pdf"
DOSSIER_DEFAUT = RACINE / "vitrine" / "assets" / "cartes"

# L'ordre de sortie de pdfimages suit l'ordre de dessin dans le PDF,
# c'est a dire la lecture de la planche : cinq colonnes, trois
# rangees. Cette table associe chaque rang au code de la carte.
#
# Elle est ecrite a la main parce que les cartes ne portent AUCUNE
# metadonnee : le code est peint dans le pixel, en bas a droite du
# visuel. Le seul moyen de l'obtenir automatiquement serait une
# reconnaissance de caracteres, dont la marge d'erreur sur douze
# valeurs ne se justifie pas.
ORDRE = [
    "X1", "M8", "K2", "Y5", "D9",
    "Z8", "Z8", "B3", "L9", "B3",
    "M3", "A4", "B3", "C7", "N1",
]

# Largeur des visuels servis par la vitrine. La grille affiche des
# cartes d'environ 170 px : 380 px couvre les ecrans a haute densite
# sans envoyer les 1109 px de la planche, qui sont faits pour une
# imprimante, pas pour un ecran.
LARGEUR_WEB = 380

# Un exemplaire agrandi, pour la section qui detaille l'anatomie
# d'une carte et l'affiche donc en grand.
LARGEUR_DETAIL = 760
CODE_DETAIL = "B3"

QUALITE = 82


def extraire(pdf: Path, dossier: Path) -> None:
    if not shutil.which("pdfimages"):
        raise SystemExit(
            "pdfimages est introuvable. Sur Debian ou Ubuntu :\n"
            "  sudo apt install poppler-utils"
        )

    dossier.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as temporaire:
        prefixe = Path(temporaire) / "carte"
        subprocess.run(
            ["pdfimages", "-png", str(pdf), str(prefixe)],
            check=True, capture_output=True,
        )
        brutes = sorted(Path(temporaire).glob("carte-*.png"))

        if len(brutes) != len(ORDRE):
            raise SystemExit(
                "La planche contient %d images, la table d'ordre en decrit %d.\n"
                "Le PDF a change : verifier ORDRE avant de continuer, sinon les\n"
                "codes seront attribues aux mauvais dessins."
                % (len(brutes), len(ORDRE))
            )

        # Dedoublonnage : on retient, pour chaque code, l'exemplaire
        # dont la surface est la plus grande.
        meilleures: dict[str, Image.Image] = {}
        for chemin, code in zip(brutes, ORDRE):
            image = Image.open(chemin).convert("RGB")
            precedente = meilleures.get(code)
            if precedente is None or image.width * image.height > precedente.width * precedente.height:
                meilleures[code] = image.copy()

        for code, image in sorted(meilleures.items()):
            _ecrire(image, dossier / (code + ".webp"), LARGEUR_WEB)
            if code == CODE_DETAIL:
                _ecrire(image, dossier / (code + "-detail.webp"), LARGEUR_DETAIL)

    total = sum(f.stat().st_size for f in dossier.glob("*.webp")) / 1024
    print("%d cartes uniques, %.0f Ko au total" % (len(meilleures), total))


def _ecrire(image: Image.Image, sortie: Path, largeur: int) -> None:
    hauteur = round(image.height * largeur / image.width)
    reduite = image.resize((largeur, hauteur), Image.Resampling.LANCZOS)
    reduite.save(sortie, format="WEBP", quality=QUALITE, method=6)
    print("  %-16s %4dx%-4d %5.0f Ko"
          % (sortie.name, reduite.width, reduite.height,
             sortie.stat().st_size / 1024))


def main() -> None:
    parseur = argparse.ArgumentParser(
        description="Extrait les visuels de cartes de la planche d'impression."
    )
    parseur.add_argument("--pdf", type=Path, default=PDF_DEFAUT)
    parseur.add_argument("--dossier", type=Path, default=DOSSIER_DEFAUT)
    args = parseur.parse_args()

    if not args.pdf.exists():
        raise SystemExit(
            "Planche introuvable : %s\n"
            "Elle n'est pas versionnee (47 Mo). La recuperer aupres de\n"
            "l'auteur du jeu avant de relancer ce script." % args.pdf
        )

    extraire(args.pdf, args.dossier)


if __name__ == "__main__":
    main()
