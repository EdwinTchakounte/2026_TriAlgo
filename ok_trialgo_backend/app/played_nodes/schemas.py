# =============================================================
# FICHIER : app/played_nodes/schemas.py
# =============================================================

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class PlayedNodeIn(BaseModel):
    game_id: UUID
    # Pas trop long pour eviter abus (255 chars cote DB).
    tracking_key: str = Field(min_length=1, max_length=255)


class PlayedNodeOut(BaseModel):
    id: UUID
    user_id: UUID
    game_id: UUID
    tracking_key: str
    played_at: datetime

    model_config = {"from_attributes": True}


class PlayedNodeBulkIn(BaseModel):
    """Reset (DELETE all) ou bulk-mark (futur)."""
    game_id: UUID
