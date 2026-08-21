# =============================================================
# FICHIER : app/codes/schemas.py
# ROLE    : DTOs pour les activation_codes
# =============================================================

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


# -------------------------------------------------------------
# JOUEUR : activation d'un code
# -------------------------------------------------------------
class ActivateCodeIn(BaseModel):
    # Le code (4-64 chars alphanumeric).
    code: str = Field(min_length=4, max_length=64)
    # Identifiant device : string opaque (Android ID, IDFV, ou hash
    # composite). Le client est libre de la forme.
    device_id: str = Field(min_length=4, max_length=200)


class ActivateCodeOut(BaseModel):
    """Reponse standardisee qui couvre les 5 cas (success + 4 erreurs).

    success=True  : code accepte, l'user peut jouer ce game.
    success=False : un des 4 cas d'erreur, voir reason + message.
    """
    success: bool
    # Code raison machine-lisible (ex: 'invalid', 'blocked',
    # 'already_assigned_other', 'inactive', 'already_active_other_game').
    reason: str | None = None
    message: str
    game_id: UUID | None = None
    # Nombre de changements de device restants (0..max).
    changes_left: int | None = None


# -------------------------------------------------------------
# ADMIN : CRUD des codes
# -------------------------------------------------------------
class AdminCodeCreate(BaseModel):
    code: str = Field(min_length=4, max_length=64)
    game_id: UUID
    max_device_changes: int = Field(default=3, ge=1, le=20)


class AdminCodeUpdate(BaseModel):
    """Admin peut desactiver ou reset le compteur device."""
    is_active: bool | None = None
    # Reset complet : remet le code a son etat 'jamais active'.
    # Utile en SAV (joueur a perdu son tel, on debloque).
    reset_assignment: bool | None = None


class AdminCodeOut(BaseModel):
    code: str
    game_id: UUID
    assigned_to: UUID | None
    device_id: str | None
    device_changes_count: int
    max_device_changes: int
    is_blocked: bool
    is_active: bool
    activated_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class PaginatedAdminCodes(BaseModel):
    items: list[AdminCodeOut]
    total: int
    limit: int
    offset: int
