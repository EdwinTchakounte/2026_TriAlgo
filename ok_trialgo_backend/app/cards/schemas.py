from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from .models import CardType


class CardOut(BaseModel):
    id: UUID
    game_id: UUID
    label: str
    object_key: str
    content_type: str
    card_type: CardType
    created_at: datetime
    # URL pre-calculee : pour eviter au client de signer lui-meme.
    image_url: str | None = None

    model_config = {"from_attributes": True}


class CardUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=120)
    card_type: CardType | None = None
