# =============================================================
# FICHIER : app/stars/schemas.py
# =============================================================

from uuid import UUID

from pydantic import BaseModel, Field


class WalletOut(BaseModel):
    """Etat du wallet apres regen applique."""
    stars: int
    stars_max: int
    # Temps avant la prochaine etoile, ou null si au max.
    seconds_to_next_star: int | None = None


class ExchangeIn(BaseModel):
    """Pas de params en input pour l'instant : cost fixe a 10."""
    # On accepte un game_id optionnel pour eviter ambiguite ;
    # sinon on utilise users.selected_game_id.
    game_id: UUID | None = None


class ExchangeOut(BaseModel):
    success: bool
    reason: str | None = None
    message: str
    # Etat apres exchange (utile pour rafraichir l'UI sans GET).
    stars_after: int
    lives_after: int | None = None
    max_lives_after: int | None = None
