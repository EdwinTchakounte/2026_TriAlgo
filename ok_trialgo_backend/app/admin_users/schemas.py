# =============================================================
# FICHIER : app/admin_users/schemas.py
# ROLE    : DTOs admin pour la gestion des comptes users
# =============================================================

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr


class AdminUserOut(BaseModel):
    """Vue admin d'un user (plus de champs que UserOut public)."""
    id: UUID
    email: EmailStr
    is_admin: bool
    is_active: bool
    email_confirmed_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class AdminUserUpdate(BaseModel):
    """Modifications autorisees par admin (sauf email + password)."""
    is_active: bool | None = None
    # is_admin se modifie via la route dediee /promote pour
    # forcer une trace explicite + envoi mail.


class PaginatedAdminUsers(BaseModel):
    items: list[AdminUserOut]
    total: int
    limit: int
    offset: int
