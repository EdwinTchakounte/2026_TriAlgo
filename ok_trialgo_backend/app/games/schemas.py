from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class GameCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str | None = None
    theme: str | None = Field(default=None, max_length=60)


class GameUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = None
    theme: str | None = Field(default=None, max_length=60)
    is_active: bool | None = None


class GameOut(BaseModel):
    id: UUID
    name: str
    description: str | None
    theme: str | None
    cover_image: str | None
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}
