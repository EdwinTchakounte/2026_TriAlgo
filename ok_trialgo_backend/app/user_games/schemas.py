# =============================================================
# FICHIER : app/user_games/schemas.py
# ROLE    : DTOs pour /api/me/games
# =============================================================

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class UserGameOut(BaseModel):
    """Vue d'un user_game avec refill applique avant retour."""
    user_id: UUID
    game_id: UUID
    activation_code: str
    current_level: int
    total_score: int
    lives: int
    max_lives: int
    lives_last_refill: datetime
    activated_at: datetime
    # Temps en secondes avant la prochaine vie regagnee, ou null
    # si deja au max (UI affiche un timer).
    seconds_to_next_life: int | None = None
