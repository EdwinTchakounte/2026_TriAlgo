from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from .models import CardType


class CardOut(BaseModel):
    id: UUID
    game_id: UUID
    label: str
    object_key: str
    # Expose par symetrie avec object_key : sans lui, une carte lue
    # via l'API semble ne pas avoir de vignette alors qu'elle en a
    # une. Les clients utilisent thumb_url, pas cette cle.
    thumb_key: str | None = None
    content_type: str
    card_type: CardType
    created_at: datetime
    # URL pre-calculee : pour eviter au client de signer lui-meme.
    image_url: str | None = None
    # URL de la vignette 256 px, ou None pour une carte creee avant
    # l'ajout des vignettes. Le client doit traiter None comme
    # "utiliser image_url" et non comme une erreur.
    thumb_url: str | None = None

    model_config = {"from_attributes": True}


class CardUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=1, max_length=120)
    card_type: CardType | None = None
