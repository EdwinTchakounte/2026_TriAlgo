# =============================================================
# FICHIER : app/unlocked_cards/schemas.py
# =============================================================

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class UnlockCardIn(BaseModel):
    card_id: UUID
    game_id: UUID


class UnlockedCardOut(BaseModel):
    card_id: UUID
    game_id: UUID
    unlocked_at: datetime
    # Champs enrichis pour eviter au client de re-fetch les cartes :
    label: str
    image_url: str | None = None
