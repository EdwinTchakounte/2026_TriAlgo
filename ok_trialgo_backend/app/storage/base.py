# =============================================================
# FICHIER : app/storage/base.py
# ROLE    : Protocole abstrait de stockage des fichiers cartes
# =============================================================
#
# Deux implementations existantes : LocalCardStorage (filesystem)
# et S3CardStorage (MinIO ou AWS S3 ou Cloudflare R2 etc.).
# Le repository Card n'importe JAMAIS une implementation concrete :
# il prend un CardStorage en dependance et appelle save/delete/url.
#
# Cela permet :
#   - tests : injecter un fake in-memory
#   - migration : passer local -> s3 en changeant juste la config
#   - prod multi-region : derriere une API unique
# =============================================================

from typing import Protocol


class CardStorage(Protocol):
    """Interface uniforme pour persister/lire les fichiers cartes."""

    async def save(
        self,
        game_id: str,
        content: bytes,
        content_type: str,
        extension: str,
    ) -> str:
        """Ecrit le fichier. Retourne un object_key opaque (chemin storage)."""
        ...

    async def delete(self, object_key: str) -> None:
        """Supprime le fichier. No-op si l'objet n'existe plus."""
        ...

    async def public_url(self, object_key: str) -> str:
        """URL accessible par le client.
        - Local  : URL servie par FastAPI (/api/cards/file/...)
        - S3/MinIO : URL publique du bucket ou URL presignee si privee
        """
        ...
