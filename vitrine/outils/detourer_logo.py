#!/usr/bin/env python3
# =============================================================
# FICHIER : vitrine/outils/detourer_logo.py
# ROLE    : Transformer ok_logo.jpeg en PNG a fond transparent
# =============================================================
#
# LE PROBLEME
# -----------
# Le logo MIXALGO est une image neon sur fond NOIR OPAQUE. Pose tel
# quel sur la vitrine, il affiche un rectangle noir au milieu de la
# page, quelle que soit la couleur du fond derriere lui.
#
# POURQUOI UN SIMPLE SEUIL NE SUFFIT PAS
# --------------------------------------
# La reponse naive est : "tout pixel plus sombre que N devient
# transparent". Elle marche pour un logo a bords nets, pas pour
# celui-ci. Le logo est fait de HALOS : le diamant, les etoiles et
# les lettres rayonnent, et ce rayonnement va progressivement du
# blanc au noir. Un seuil coupe ce degrade en deux : ce qui est au
# dessus devient completement opaque, ce qui est en dessous
# disparait. On obtient un halo qui s'arrete net, avec un contour
# visible en forme de patatoide. Sur fond clair, le halo restant
# ressort comme une tache bleu sombre.
#
# LA METHODE RETENUE : L'EXTRACTION ADDITIVE
# ------------------------------------------
# Une lumiere sur fond noir est un phenomene ADDITIF : le noir n'est
# pas une couleur posee derriere la lumiere, c'est l'ABSENCE de
# lumiere. On peut donc reconstruire exactement l'image d'origine en
# considerant que chaque pixel est une lumiere coloree dont
# l'intensite est son opacite.
#
#   alpha  = max(R, G, B)          l'intensite lumineuse du pixel
#   RGB'   = RGB x 255 / alpha     la couleur pure, desatureee du noir
#
# Cette transformation a une propriete qu'on peut verifier au calcul :
# recompose sur du noir, le resultat est STRICTEMENT identique a
# l'original.
#
#   resultat = RGB' x alpha/255 = (RGB x 255/alpha) x alpha/255 = RGB
#
# Autrement dit, on ne degrade rien, et on gagne le fait que sur
# n'importe quel autre fond le halo se comporte comme une vraie
# lumiere : il eclaircit ce qu'il y a derriere au lieu de le salir.
#
# LE PLANCHER
# -----------
# Le fichier source est un JPEG. La compression laisse dans les zones
# noires un bruit de quelques unites (des pixels a 3, 7, 11 au lieu de
# 0). Sans plancher, chacun devient un point legerement visible, et
# toute la surface de l'image prend un voile sale. On force donc a
# zero en dessous de PLANCHER_BAS, et on monte progressivement
# jusqu'a PLANCHER_HAUT pour ne pas recreer la coupure nette que
# toute cette methode cherche justement a eviter.
#
# USAGE
# -----
#   python3 vitrine/outils/detourer_logo.py
#   python3 vitrine/outils/detourer_logo.py --source autre.jpeg
# =============================================================

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

# Racine du depot, deduite de l'emplacement de ce fichier.
RACINE = Path(__file__).resolve().parents[2]

SOURCE_DEFAUT = RACINE / "ok_logo.jpeg"

# En dessous : bruit de compression, force a transparent.
PLANCHER_BAS = 10
# Au dessus : lumiere reelle, gardee telle quelle.
# Entre les deux : montee progressive.
PLANCHER_HAUT = 26

# Marge laissee autour du contenu apres recadrage, en pixels.
# Zero collerait le halo au bord et le ferait couper par un
# eventuel overflow:hidden cote CSS.
MARGE = 8


def detourer(source: Path) -> Image.Image:
    """Renvoie `source` en RGBA, fond noir devenu transparent."""
    image = Image.open(source).convert("RGB")
    pixels = np.asarray(image).astype(np.float32)

    # ---- 1. L'opacite est l'intensite lumineuse -----------------
    # max() plutot que la luminance perceptuelle : un bleu neon pur
    # (0, 40, 255) est une lumiere INTENSE, alors que sa luminance
    # perceptuelle est basse (le bleu pese 0.114). Le prendre pour
    # de la penombre effacerait la moitie du logo.
    alpha = pixels.max(axis=2)

    # ---- 2. Le plancher, contre le bruit JPEG -------------------
    rampe = np.clip(
        (alpha - PLANCHER_BAS) / (PLANCHER_HAUT - PLANCHER_BAS), 0.0, 1.0
    )
    alpha_final = alpha * rampe

    # ---- 3. La couleur, debarrassee du noir ---------------------
    # Division par alpha, pas par alpha_final : on veut la teinte
    # d'origine du pixel, la rampe ne concerne que son opacite.
    # np.maximum evite la division par zero sur le noir pur.
    couleur = pixels * 255.0 / np.maximum(alpha, 1.0)[:, :, None]

    # ---- 3 bis. Neutraliser les pixels invisibles ---------------
    # La division de l'etape 3 sature les couleurs : un pixel de bruit
    # a (1, 0, 3) devient (85, 0, 255), un magenta vif. Il est
    # invisible puisque son alpha est nul, mais il existe dans le
    # fichier -- et un compresseur ne peut rien faire d'une plage de
    # bruit sature aleatoire. Concretement, le PNG passait de 266 Ko
    # a plus d'un megaoctet a cause de pixels que personne ne verra
    # jamais. On les remet a plat.
    invisible = alpha_final <= 0
    couleur[invisible] = 0.0

    rgba = np.dstack([
        np.clip(couleur, 0, 255),
        np.clip(alpha_final, 0, 255),
    ]).astype(np.uint8)

    resultat = Image.fromarray(rgba, mode="RGBA")

    # ---- 4. Recadrage sur le contenu reel -----------------------
    # Le logo ne remplit pas son cadre : il reste des bandes noires
    # en haut et en bas, devenues transparentes. Les garder revient a
    # exporter du vide, que le CSS devrait ensuite compenser a la
    # main pour centrer optiquement le logo.
    boite = resultat.getchannel("A").getbbox()
    if boite is not None:
        gauche, haut, droite, bas = boite
        gauche = max(0, gauche - MARGE)
        haut = max(0, haut - MARGE)
        droite = min(resultat.width, droite + MARGE)
        bas = min(resultat.height, bas + MARGE)
        resultat = resultat.crop((gauche, haut, droite, bas))

    return resultat


# =============================================================
# LES DERIVES
# =============================================================
# Une page web n'a pas besoin d'UN fichier mais d'une famille :
#
#   - deux largeurs, pour ne pas envoyer 900 px de logo a un
#     telephone qui en affiche 300 ;
#   - du WebP, qui pese ici deux fois moins lourd que le PNG a
#     qualite comparable, avec un PNG en repli pour les navigateurs
#     qui l'ignorent (moins de 1 % aujourd'hui, et <picture> ne
#     telecharge de toute facon qu'un seul des deux) ;
#   - une image de partage social au format impose par les reseaux ;
#   - une favicon.
#
# Tout est reconstruit depuis la meme source : aucune retouche
# manuelle a refaire si le logo change.
# =============================================================

# Fond des visuels qui n'acceptent pas la transparence (partage
# social, favicon). Identique au fond de la vitrine, pour que
# l'image ne montre pas de rectangle rapporte.
FOND = (9, 7, 24)

# Format impose par Open Graph et Twitter Cards. Une image aux
# mauvaises proportions est recadree par la plateforme, en general
# au pire endroit.
OG_LARGEUR, OG_HAUTEUR = 1200, 630


def _poser_sur_fond(logo: Image.Image, taille: tuple[int, int],
                    remplissage: float) -> Image.Image:
    """Centre `logo` sur un aplat opaque de `taille`."""
    fond = Image.new("RGB", taille, FOND)
    largeur_cible = int(taille[0] * remplissage)
    hauteur = round(logo.height * largeur_cible / logo.width)
    if hauteur > taille[1] * remplissage:
        hauteur = int(taille[1] * remplissage)
        largeur_cible = round(logo.width * hauteur / logo.height)
    reduit = logo.resize((largeur_cible, hauteur), Image.Resampling.LANCZOS)
    fond.paste(
        reduit,
        ((taille[0] - largeur_cible) // 2, (taille[1] - hauteur) // 2),
        reduit,
    )
    return fond


def generer_derives(logo: Image.Image, dossier: Path) -> None:
    """Ecrit toute la famille de visuels a partir du logo detoure."""
    dossier.mkdir(parents=True, exist_ok=True)

    def redimensionner(largeur: int) -> Image.Image:
        hauteur = round(logo.height * largeur / logo.width)
        return logo.resize((largeur, hauteur), Image.Resampling.LANCZOS)

    sorties: list[Path] = []

    # ---- Le logo lui meme, deux largeurs, deux formats -----------
    for largeur in (512, 900):
        reduit = redimensionner(largeur)
        chemin = dossier / f"mixalgo-logo-{largeur}.webp"
        reduit.save(chemin, format="WEBP", quality=84, method=6)
        sorties.append(chemin)

    repli = dossier / "mixalgo-logo.png"
    redimensionner(900).save(repli, format="PNG", optimize=True)
    sorties.append(repli)

    # ---- Image de partage social --------------------------------
    # 0.82 laisse respirer le halo : colle aux bords, il serait
    # tronque par les vignettes arrondies de certaines messageries.
    og = _poser_sur_fond(logo, (OG_LARGEUR, OG_HAUTEUR), 0.82)
    chemin_og = dossier / "mixalgo-og.jpg"
    og.save(chemin_og, format="JPEG", quality=88, optimize=True, progressive=True)
    sorties.append(chemin_og)

    # ---- Favicon ------------------------------------------------
    # 0.98 : a 32 px, la moindre marge rend le logo illisible dans
    # un onglet. On remplit le carre.
    favicon = _poser_sur_fond(logo, (512, 512), 0.98)
    chemin_fav = dossier / "favicon.png"
    favicon.save(chemin_fav, format="PNG", optimize=True)
    sorties.append(chemin_fav)

    chemin_ico = dossier / "favicon.ico"
    favicon.save(chemin_ico, format="ICO",
                 sizes=[(16, 16), (32, 32), (48, 48)])
    sorties.append(chemin_ico)

    for chemin in sorties:
        with Image.open(chemin) as ouverte:
            dimensions = f"{ouverte.width}x{ouverte.height}"
        poids = chemin.stat().st_size / 1024
        print(f"  {chemin.name:26} {dimensions:>10}  {poids:6.0f} Ko")


def main() -> None:
    parseur = argparse.ArgumentParser(
        description="Detoure le logo MIXALGO et genere les visuels de la vitrine."
    )
    parseur.add_argument("--source", type=Path, default=SOURCE_DEFAUT)
    parseur.add_argument(
        "--dossier",
        type=Path,
        default=RACINE / "vitrine" / "assets",
        help="Ou ecrire les visuels (defaut vitrine/assets).",
    )
    args = parseur.parse_args()

    if not args.source.exists():
        raise SystemExit(f"Source introuvable : {args.source}")

    print(f"Source : {args.source.name}")
    logo = detourer(args.source)
    print(f"Detoure : {logo.width}x{logo.height}")
    generer_derives(logo, args.dossier)


if __name__ == "__main__":
    main()
