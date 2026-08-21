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
            return ProcessedImage(
                bytes=out.getvalue(),
                content_type="image/jpeg",
                extension=".jpg",
            )
    except Exception as e:
        raise ValueError(f"Image illisible : {e}") from e
