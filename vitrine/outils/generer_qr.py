#!/usr/bin/env python3
# =============================================================
# FICHIER : vitrine/outils/generer_qr.py
# ROLE    : Le pont entre l'ordinateur et le telephone
# =============================================================
#
# LE PROBLEME
# -----------
# MIXALGO s'installe sur un telephone Android. Or une bonne part
# des visiteurs decouvrent le site sur un ORDINATEUR : ils cliquent
# sur "Telecharger", recuperent un APK sur une machine qui ne peut
# rien en faire, et le parcours s'arrete la.
#
# LA REPONSE
# ----------
# Un QR code, affiche uniquement hors Android. Le visiteur le scanne,
# son telephone ouvre la page, et le telechargement part du bon
# appareil. Aucune saisie d'adresse, aucun envoi de lien a soi meme.
#
# POURQUOI DU NOIR SUR DU BLANC
# -----------------------------
# La tentation est d'habiller le QR aux couleurs de la page, en cyan
# sur fond nuit. Un code inverse reste lisible par beaucoup de
# scanners, mais pas par tous, et un QR qui echoue une fois sur dix
# ne remplit pas son office. Il est donc pose sur une pastille
# blanche, comme un ticket sur une table sombre : c'est aussi ce qui
# le fait lire comme un objet a scanner plutot qu'un ornement.
#
# La marge blanche autour du motif (quiet zone) n'est pas negociable
# non plus : sans elle, un scanner ne trouve pas les bords du code.
#
# USAGE
#   python3 vitrine/outils/generer_qr.py
#   python3 vitrine/outils/generer_qr.py --cible https://exemple.test/
# =============================================================

from __future__ import annotations

import argparse
from pathlib import Path

import qrcode
from qrcode.constants import ERROR_CORRECT_M

RACINE = Path(__file__).resolve().parents[2]
SORTIE_DEFAUT = RACINE / "vitrine" / "assets" / "qr-telechargement.png"

# La page, pas le fichier. Arriver sur la vitrine depuis son telephone
# laisse le visiteur lire les consignes d'installation avant de
# declencher un telechargement qu'Android traite comme suspect.
CIBLE_DEFAUT = "https://mixalgo.com/#telecharger"

# Correction d'erreur moyenne : environ 15 % du code reste lisible
# meme abime. Suffisant pour un ecran, et cela garde le motif assez
# large pour etre scanne de loin.
CORRECTION = ERROR_CORRECT_M


def generer(cible: str, sortie: Path) -> None:
    code = qrcode.QRCode(
        version=None,          # la plus petite version qui contienne l'URL
        error_correction=CORRECTION,
        box_size=12,
        border=3,              # la marge blanche, en modules
    )
    code.add_data(cible)
    code.make(fit=True)

    image = code.make_image(fill_color="#06041A", back_color="white")
    sortie.parent.mkdir(parents=True, exist_ok=True)
    image.save(sortie)

    print("%s  %dx%d  %.0f Ko  ->  %s"
          % (sortie.name, image.size[0], image.size[1],
             sortie.stat().st_size / 1024, cible))


def main() -> None:
    parseur = argparse.ArgumentParser(
        description="Genere le QR code de telechargement de la vitrine."
    )
    parseur.add_argument("--cible", default=CIBLE_DEFAUT)
    parseur.add_argument("--sortie", type=Path, default=SORTIE_DEFAUT)
    args = parseur.parse_args()
    generer(args.cible, args.sortie)


if __name__ == "__main__":
    main()
