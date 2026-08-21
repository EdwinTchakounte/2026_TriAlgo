# =============================================================
# FICHIER : app/profiles/schemas.py
# ROLE    : DTOs profil joueur (username, avatar, selected game)
# =============================================================
#
# Le profil etend la table users (colonnes ajoutees dans 0004).
# On expose un endpoint /api/me/profile pour eviter de mettre
# trop de logique dans /api/auth/me (qui reste minimal).
# =============================================================

from uuid import UUID

from pydantic import BaseModel, Field


class ProfileOut(BaseModel):
    """Vue complete du profil (incluant wallet etoiles)."""
    user_id: UUID
    username: str
    avatar_id: str
    selected_game_id: UUID | None
    # Wallet etoiles : on expose ici pour eviter au client de
    # taper aussi /api/me/stars juste pour afficher le compteur
    # dans la home page.
    stars: int
    stars_max: int


class ProfileUpdate(BaseModel):
    """Champs modifiables. Tous optionnels (PATCH partiel)."""
    username: str | None = Field(default=None, min_length=1, max_length=60)
    avatar_id: str | None = Field(default=None, max_length=40)
    # Permet de switcher le jeu actif (chargement nouveau graphe
    # cote client). UUID ou null pour deselectionner.
    selected_game_id: UUID | None = None
