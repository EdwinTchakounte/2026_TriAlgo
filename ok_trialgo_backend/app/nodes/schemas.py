from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class NodeCreate(BaseModel):
    parent_node_id: UUID | None = None
    emettrice_id: UUID | None = None
    cable_id: UUID
    receptrice_id: UUID
    depth: int = Field(ge=1, le=5)

    @model_validator(mode="after")
    def _xor_emettrice_parent(self) -> "NodeCreate":
        # Regle metier (xor) : si parent -> emettrice doit etre None (deduit)
        #                      si pas de parent -> emettrice obligatoire.
        if self.parent_node_id is None and self.emettrice_id is None:
            raise ValueError("Fusion racine : emettrice_id obligatoire")
        if self.parent_node_id is not None and self.emettrice_id is not None:
            raise ValueError("Fusion enfant : emettrice_id doit etre null (deduit du parent)")
        return self


class NodeOut(BaseModel):
    id: UUID
    game_id: UUID
    node_index: int
    emettrice_id: UUID | None
    cable_id: UUID
    receptrice_id: UUID
    parent_node_id: UUID | None
    depth: int
    created_at: datetime

    model_config = {"from_attributes": True}


# ---- Analyzer (3 cartes -> liaison) ----

class AnalysisKind(str, Enum):
    DIRECT_LINK = "direct_link"
    CHAINED_LINK = "chained_link"
    NO_LINK = "no_link"


class AnalyzeIn(BaseModel):
    card_ids: list[UUID] = Field(min_length=3, max_length=3)


class AnalyzeOut(BaseModel):
    kind: AnalysisKind
    involved_node_ids: list[UUID]
    summary: str
    detail: str | None = None
