# =============================================================
# FICHIER : app/cards/image.py
# ROLE    : Validation + optimisation des images uploadees
# =============================================================
#
# Pipeline :
#   1. Verifier la taille (settings.MAX_UPLOAD_BYTES).
#   2. Detecter le vrai MIME via magic bytes (pas confiance dans
#      le Content-Type client, falsifiable).
#   3. Re-encoder en JPEG quality 85, redimensionner si > 1024px.
#      Resultat : taille uniforme, format predictable, EXIF retire
#      (privacy : pas de coordonnees GPS qui fuient).
#   4. Produire EN PLUS une vignette (IMAGE_THUMB_DIMENSION, 256px).
#
# POURQUOI UNE VIGNETTE
# ---------------------
# Une question de jeu affiche 8 cartes : 2 en grand, et 6 dans une
# grille de choix ou chacune fait environ 150 px de cote. Servir du
# 1024 px pour ces six-la, c'est envoyer 10 a 20 fois plus d'octets
# que ce que l'ecran affiche.
#
# Avec des photos reelles (1024 px, q85), une carte pese 150 a
# 300 Ko : une question coute donc 1,5 a 2,5 Mo, et le deck complet
# de 76 cartes 11 a 23 Mo. En 4G, c'est ce qui separe une partie
# fluide d'une partie qui bute sur des images grises.
#
# La vignette est produite ICI plutot que par un service d'images a
# la volee : l'image est deja decompressee en memoire, la seconde
# reduction ne coute presque rien, et cela evite toute dependance
# supplementaire au moment de servir.
# =============================================================

import io
from typing import NamedTuple

import magic
from PIL import Image

from ..config import settings


class ProcessedImage(NamedTuple):
    bytes: bytes
    content_type: str
    extension: str
    # Vignette : meme format, meme extension, seulement plus petite.
    # Toujours renseignee -- une carte sans vignette obligerait le
    # client a retomber sur le plein format sans le savoir.
    thumb_bytes: bytes


def detect_mime(content: bytes) -> str:
    """Lit les 'magic bytes' du fichier pour determiner le vrai MIME."""
    return magic.from_buffer(content[:2048], mime=True)


def validate_and_process(raw: bytes, claimed_mime: str | None = None) -> ProcessedImage:
    """Verifie, optimise, renvoie les bytes prets a stocker.

    Leve ValueError avec un message utilisateur-friendly si invalide.
    """
    if len(raw) > settings.MAX_UPLOAD_BYTES:
        raise ValueError(
            f"Fichier trop volumineux ({len(raw)/1024:.0f} Ko > "
            f"{settings.MAX_UPLOAD_BYTES/1024:.0f} Ko)"
        )

    real_mime = detect_mime(raw)
    if real_mime not in settings.allowed_mime_set:
        raise ValueError(
            f"Format non autorise : {real_mime}. "
            f"Acceptes : {sorted(settings.allowed_mime_set)}"
        )

    # Pillow : ouvre, retire EXIF, resize, recompresse en JPEG.
    try:
        with Image.open(io.BytesIO(raw)) as im:
            # Convertir en RGB pour ecrire en JPEG (perd l'alpha si PNG/WEBP).
            if im.mode in ("RGBA", "LA", "P"):
                background = Image.new("RGB", im.size, (255, 255, 255))
                if im.mode == "P":
                    im = im.convert("RGBA")
                background.paste(im, mask=im.split()[-1] if im.mode != "P" else None)
                im = background
            elif im.mode != "RGB":
                im = im.convert("RGB")

            # Resize si depasse IMAGE_MAX_DIMENSION (preserve aspect).
            max_dim = settings.IMAGE_MAX_DIMENSION
            if max(im.size) > max_dim:
                im.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)

            out = io.BytesIO()
            im.save(out, format="JPEG", quality=settings.IMAGE_JPEG_QUALITY, optimize=True)

            # Vignette : on repart de l'image deja normalisee (RGB,
            # sans EXIF, deja bornee a IMAGE_MAX_DIMENSION). `copy()`
            # est indispensable -- thumbnail() modifie sur place, et
            # sans copie on ecraserait l'image plein format qui vient
            # d'etre encodee... mais surtout celle que la ligne
            # suivante lirait si l'ordre changeait un jour.
            vignette = im.copy()
            thumb_dim = settings.IMAGE_THUMB_DIMENSION
            vignette.thumbnail((thumb_dim, thumb_dim), Image.Resampling.LANCZOS)
            out_thumb = io.BytesIO()
            vignette.save(
                out_thumb,
                format="JPEG",
                quality=settings.IMAGE_THUMB_QUALITY,
                optimize=True,
            )

            return ProcessedImage(
                bytes=out.getvalue(),
                content_type="image/jpeg",
                extension=".jpg",
                thumb_bytes=out_thumb.getvalue(),
            )
    except Exception as e:
        raise ValueError(f"Image illisible : {e}") from e
