# =============================================================
# FICHIER : app/storage/__init__.py
# ROLE    : Factory pour selectionner l'implementation CardStorage
# =============================================================

from functools import lru_cache

from ..config import settings
from .base import CardStorage
from .local import LocalCardStorage
from .s3 import S3CardStorage


@lru_cache
def get_storage() -> CardStorage:
    """Selection auto selon STORAGE_BACKEND env."""
    if settings.STORAGE_BACKEND == "s3":
        return S3CardStorage()
    return LocalCardStorage()


__all__ = ["CardStorage", "LocalCardStorage", "S3CardStorage", "get_storage"]
