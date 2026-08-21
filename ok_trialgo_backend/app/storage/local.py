# =============================================================
# FICHIER : app/storage/local.py
# ROLE    : Implementation CardStorage sur filesystem local
# =============================================================

import uuid
from pathlib import Path

import aiofiles

from ..config import settings
from .base import CardStorage


class LocalCardStorage(CardStorage):
    def __init__(self, root: str | None = None) -> None:
        self.root = Path(root or settings.LOCAL_STORAGE_DIR)
        self.root.mkdir(parents=True, exist_ok=True)

    async def save(
        self,
        game_id: str,
        content: bytes,
        content_type: str,
        extension: str,
    ) -> str:
        # Layout : <root>/<game_id>/<uuid>.<ext>
        # uuid garantit unicite (pas de collision de nom).
        key = f"{game_id}/{uuid.uuid4()}{extension}"
        path = self.root / key
        path.parent.mkdir(parents=True, exist_ok=True)
        async with aiofiles.open(path, "wb") as f:
            await f.write(content)
        return key

    async def delete(self, object_key: str) -> None:
        path = self.root / object_key
        try:
            path.unlink()
        except FileNotFoundError:
            pass  # idempotent

    async def public_url(self, object_key: str) -> str:
        # Sert via l'endpoint FastAPI /api/cards/file/<key>.
        # PUBLIC_BASE_URL pointe vers l'API exposee.
        return f"{settings.PUBLIC_BASE_URL}/api/cards/file/{object_key}"
