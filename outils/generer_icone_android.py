#!/usr/bin/env python3
# =============================================================
# FICHIER : outils/generer_icone_android.py
# ROLE    : Dessiner l'icone de lancement MIXALGO, toutes densites
# =============================================================
#
# POURQUOI DESSINER PLUTOT QUE RECADRER LE LOGO
# ---------------------------------------------
# Le logo MIXALGO est large (1400 x 970) et son element le plus
# reconnaissable est un mot ecrit. Une icone est carree et se lit a
# 48 pixels de cote dans une liste d'applications. A cette taille, un
# recadrage du logo ne donne rien : le mot devient une bouillie de
# trois pixels de haut, et l'eventail de cartes se retrouve tronque.
#
# On garde donc du logo ce qui survit a la reduction : le LOSANGE,
# et l'idee de cartes posees dedans. Le losange est la signature
# graphique du jeu, reprise partout sur la vitrine.
#
# DEUX JEUX DE FICHIERS, ET C'EST VOULU
# -------------------------------------
# 1. ic_launcher.png dans les cinq densites. C'est l'icone
#    historique, celle que lisent les anciens Android et certains
#    lanceurs.
#
# 2. Une ICONE ADAPTATIVE (Android 8 et plus, soit la quasi-totalite
#    du parc) : un fond et un avant-plan separes, que le lanceur
#    compose lui-meme dans la forme du systeme -- cercle, carre
#    arrondi, goutte selon le constructeur.
#
# Sans le second jeu, Android applique a l'icone historique un
# masque automatique : il la retrecit et la pose sur un fond blanc.
# Une icone concue sur fond sombre se retrouve alors en petit carre
# noir cerne de blanc. C'est le defaut le plus courant des
# applications Flutter qui n'ont jamais touche a leurs icones.
#
# LA ZONE SURE
# ------------
# Un avant-plan adaptatif mesure 108 unites, mais le lanceur peut en
# rogner jusqu'aux bords : seules les 66 unites CENTRALES sont
# garanties visibles, et le systeme anime parfois l'icone dans son
# masque. Tout ce qui compte doit tenir dans ces 61 % centraux.
# C'est la contrainte qui dimensionne tout le dessin ci-dessous.
#
# USAGE
#   python3 outils/generer_icone_android.py
#   python3 outils/generer_icone_android.py --app ok_trialgo_admin
# =============================================================

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

RACINE = Path(__file__).resolve().parents[1]

# Palette echantillonnee dans le logo, la meme que la vitrine.
NUIT = (6, 4, 26)
ABYSSE = (0, 24, 120)
CYAN = (0, 216, 240)
AMBRE = (240, 168, 0)
CRAIE = (234, 244, 250)

# On dessine grand puis on reduit : c'est le reechantillonnage qui
# donne des bords propres, pas le trace lui-meme.
TOILE = 1024

# Densites Android. La premiere valeur est la taille de l'icone
# historique, la seconde celle de l'avant-plan adaptatif (108/48 fois
# plus grand, par construction du format).
DENSITES = {
    "mdpi":    (48, 108),
    "hdpi":    (72, 162),
    "xhdpi":   (96, 216),
    "xxhdpi":  (144, 324),
    "xxxhdpi": (192, 432),
}

# Part de la toile occupee par le dessin.
#   - icone historique : le lanceur ne rogne pas, on peut remplir.
#   - avant-plan adaptatif : il rogne, d'ou la reduction a la zone sure.
PART_HISTORIQUE = 1.00
PART_ADAPTATIVE = 0.58


def _dessiner_marque(taille: int, part: float, avec_fond: bool) -> Image.Image:
    """Le losange et ses trois cartes, sur une toile carree."""
    image = Image.new("RGBA", (taille, taille), NUIT + (255,) if avec_fond else (0, 0, 0, 0))
    dessin = ImageDraw.Draw(image)
    centre = taille // 2

    if avec_fond:
        # Degrade radial : le centre remonte vers le bleu profond du
        # logo, ce qui detache la marque du bord de l'icone.
        for rayon in range(centre, 0, -3):
            k = 1 - rayon / centre
            couleur = tuple(
                int(NUIT[i] + (ABYSSE[i] - NUIT[i]) * k * 0.55) for i in range(3)
            )
            dessin.ellipse(
                [centre - rayon, centre - rayon, centre + rayon, centre + rayon],
                fill=couleur,
            )

    demi = taille * part * 0.40
    interieur = taille * part * 0.27

    def losange(rayon: float, couleur, epaisseur: int, cible=None):
        (cible or dessin).polygon(
            [(centre, centre - rayon), (centre + rayon, centre),
             (centre, centre + rayon), (centre - rayon, centre)],
            outline=couleur, width=epaisseur,
        )

    # La lueur : le meme losange, floute, compose sous le trait net.
    # C'est ce qui fait lire le cyan comme du neon plutot que comme
    # une bordure.
    lueur = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
    losange(demi, CYAN + (255,), max(2, taille // 40), ImageDraw.Draw(lueur))
    image.alpha_composite(lueur.filter(ImageFilter.GaussianBlur(taille // 40)))

    losange(demi, CYAN, max(2, taille // 85))
    losange(interieur, AMBRE, max(1, taille // 170))

    # Les trois cartes. L'ecart et l'inclinaison sont ceux de
    # l'eventail du logo, reduits pour tenir dans le losange.
    largeur = int(taille * part * 0.155)
    hauteur = int(taille * part * 0.225)
    ecart = int(taille * part * 0.135)
    for decalage, angle, remplissage, bord in [
        (-ecart, 14, ABYSSE, CYAN),
        (0, 0, (20, 16, 60), CRAIE),
        (ecart, -14, ABYSSE, AMBRE),
    ]:
        carte = Image.new("RGBA", (largeur, hauteur), (0, 0, 0, 0))
        ImageDraw.Draw(carte).rounded_rectangle(
            [0, 0, largeur - 1, hauteur - 1],
            radius=max(2, int(largeur * 0.14)),
            fill=remplissage + (255,), outline=bord + (255,),
            width=max(2, largeur // 22),
        )
        carte = carte.rotate(angle, expand=True, resample=Image.BICUBIC)
        image.alpha_composite(
            carte, (centre + decalage - carte.width // 2, centre - carte.height // 2)
        )

    return image


def generer(app: str) -> None:
    res = RACINE / app / "android" / "app" / "src" / "main" / "res"
    if not res.is_dir():
        raise SystemExit("Dossier de ressources introuvable : %s" % res)

    historique = _dessiner_marque(TOILE, PART_HISTORIQUE, avec_fond=True)
    avant_plan = _dessiner_marque(TOILE, PART_ADAPTATIVE, avec_fond=False)

    for densite, (taille_icone, taille_avant) in DENSITES.items():
        dossier = res / ("mipmap-" + densite)
        dossier.mkdir(parents=True, exist_ok=True)

        historique.convert("RGB").resize(
            (taille_icone, taille_icone), Image.Resampling.LANCZOS
        ).save(dossier / "ic_launcher.png", optimize=True)

        avant_plan.resize(
            (taille_avant, taille_avant), Image.Resampling.LANCZOS
        ).save(dossier / "ic_launcher_foreground.png", optimize=True)

        print("  mipmap-%-8s %3d px  +  avant-plan %3d px" % (densite, taille_icone, taille_avant))

    # ---- La declaration de l'icone adaptative -------------------
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    declaration = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!--\n"
        "  Icone adaptative, lue par Android 8 et plus.\n"
        "  Le lanceur compose lui-meme le fond et l'avant-plan dans la\n"
        "  forme du systeme. Sans ce fichier, il appliquerait a\n"
        "  ic_launcher.png un masque automatique qui la retrecit et la\n"
        "  pose sur du blanc.\n"
        "-->\n"
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n"
    )
    # Pas de ic_launcher_round : le manifeste ne declare pas
    # android:roundIcon, et le declarer casserait la compilation pour
    # Android < 26, ou aucune ressource ronde n'existe. Les lanceurs
    # qui cherchent une icone ronde retombent sur celle-ci, desormais
    # adaptative, et la masquent eux-memes.
    (anydpi / "ic_launcher.xml").write_text(declaration, encoding="utf-8")
    print("  mipmap-anydpi-v26  ic_launcher.xml")

    # ---- La couleur de fond ------------------------------------
    valeurs = res / "values"
    valeurs.mkdir(parents=True, exist_ok=True)
    (valeurs / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- Le fond de l'icone adaptative. Aplat et non degrade : le\n"
        "     lanceur peut animer le fond independamment de l'avant-plan,\n"
        "     et un degrade se decalerait alors de son centre. -->\n"
        "<resources>\n"
        '    <color name="ic_launcher_background">#06041A</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )
    print("  values/ic_launcher_background.xml  #06041A")


def main() -> None:
    parseur = argparse.ArgumentParser(
        description="Genere l'icone de lancement MIXALGO dans toutes les densites."
    )
    parseur.add_argument("--app", default="trialgo",
                         help="dossier de l'application (defaut : trialgo)")
    args = parseur.parse_args()
    print("Icone MIXALGO ->", args.app)
    generer(args.app)


if __name__ == "__main__":
    main()
