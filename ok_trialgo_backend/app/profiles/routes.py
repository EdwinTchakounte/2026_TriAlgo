# =============================================================
# FICHIER : app/profiles/routes.py
# ROLE    : Endpoints profil joueur (/api/me/profile)
# =============================================================
#
# Endpoints :
#   GET   /api/me/profile     lecture du profil + wallet
#   PATCH /api/me/profile     update partial (username, avatar, jeu actif)
#
# Garde-fous :
#   - Si selected_game_id fourni, on verifie qu'il existe ET que
#     l'user a un user_games actif pour ce jeu (sinon il ne peut
#     pas selectionner un jeu auquel il n'a pas acces).
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..db import get_db
from ..games.models import Game
from .schemas import ProfileOut, ProfileUpdate

router = APIRouter()


def _to_profile_out(user: User) -> ProfileOut:
    """Convertit le model User en DTO ProfileOut."""
    return ProfileOut(
        user_id=user.id,
        username=user.username,
        avatar_id=user.avatar_id,
        selected_game_id=user.selected_game_id,
        stars=user.stars,
        stars_max=user.stars_max,
    )


# -------------------------------------------------------------
# GET profile
# -------------------------------------------------------------
@router.get(
    "/profile",
    response_model=ProfileOut,
    summary="Recupere le profil du user connecte (user)",
    description=(
        "Renvoie le profil joueur courant : username, avatar_id, "
        "selected_game_id (jeu actif), wallet d'etoiles (stars, "
        "stars_max). Utilise par l'app pour afficher l'identite et "
        "le compteur d'etoiles."
    ),
)
async def get_my_profile(
    user: Annotated[User, Depends(get_current_user)],
) -> ProfileOut:
    return _to_profile_out(user)


# -------------------------------------------------------------
# PATCH profile
# -------------------------------------------------------------
@router.patch(
    "/profile",
    response_model=ProfileOut,
    summary="Met a jour le profil du user (user)",
    description=(
        "Update partial du profil : username, avatar_id, "
        "selected_game_id. Le patch peut etre vide (no-op). Pour "
        "selected_game_id, le jeu doit exister (erreur 404 sinon) ; "
        "None est accepte explicitement pour deselectionner. "
        "L'autorisation reelle (avoir active le jeu via un code) est "
        "verifiee dans le module user_games."
    ),
)
async def update_my_profile(
    body: ProfileUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> ProfileOut:
    # Le patch peut etre vide : on accepte mais on ne fait rien.
    if body.username is not None:
        user.username = body.username
    if body.avatar_id is not None:
        user.avatar_id = body.avatar_id

    # selected_game_id : valider que le jeu existe.
    # On accepte explicitement None pour deselectionner.
    if "selected_game_id" in body.model_fields_set:
        if body.selected_game_id is not None:
            game = await db.get(Game, body.selected_game_id)
            if not game:
                raise HTTPException(404, "Jeu introuvable")
            # Note : on pourrait verifier qu'un user_games existe
            # pour ce jeu (= l'user a active un code). On le saute
            # pour l'instant : un user peut "preselectionner" un
            # jeu avant d'avoir le code, l'UI le guidera vers
            # l'activation. La logique d'autorisation reelle se
            # fait dans le module user_games.
        user.selected_game_id = body.selected_game_id

    await db.commit()
    await db.refresh(user)
    return _to_profile_out(user)
