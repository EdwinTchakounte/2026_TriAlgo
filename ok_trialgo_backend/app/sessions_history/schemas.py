# =============================================================
# FICHIER : app/sessions_history/schemas.py
# ROLE    : DTOs pour /api/me/sessions
# =============================================================

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


# -------------------------------------------------------------
# INPUT : INSERT d'une partie terminee
# -------------------------------------------------------------
class SessionRecordIn(BaseModel):
    """Payload envoye par le client a la fin d'une partie."""
    game_id: UUID
    level: int = Field(ge=1, le=100)
    score_gained: int = Field(ge=0)
    correct_answers: int = Field(ge=0)
    wrong_answers: int = Field(ge=0)
    questions_total: int = Field(ge=0)
    max_streak: int = Field(ge=0)
    duration_seconds: int = Field(ge=0)
    passed: bool
    stars_earned: int = Field(ge=0, le=3)


# -------------------------------------------------------------
# OUTPUT : vue d'une session enregistree
# -------------------------------------------------------------
class SessionRecordOut(BaseModel):
    id: UUID
    user_id: UUID
    game_id: UUID
    level: int
    score_gained: int
    correct_answers: int
    wrong_answers: int
    questions_total: int
    max_streak: int
    duration_seconds: int
    passed: bool
    stars_earned: int
    played_at: datetime

    model_config = {"from_attributes": True}


class PaginatedSessions(BaseModel):
    items: list[SessionRecordOut]
    total: int
    limit: int
    offset: int


# -------------------------------------------------------------
# Reponse au record : etat user_game mis a jour (score, level, vies)
# -------------------------------------------------------------
class SessionRecordedResponse(BaseModel):
    """Renvoie la session enregistree + le user_game mis a jour."""
    session: SessionRecordOut
    # On expose user_game refraichi pour eviter au client de devoir
    # refaire un GET /api/me/games/{gid} immediatement.
    new_total_score: int
    new_current_level: int
    new_lives: int
    new_max_lives: int
