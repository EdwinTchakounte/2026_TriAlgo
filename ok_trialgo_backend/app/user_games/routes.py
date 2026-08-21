# =============================================================
# FICHIER : app/user_games/routes.py
# ROLE    : Endpoints /api/me/games (etat par-jeu du user connecte)
# =============================================================
#
# Endpoints :
#   GET /api/me/games              liste de tous les jeux actives par l'user
#   GET /api/me/games/{game_id}    detail d'un jeu (avec refill applique)
#
# Le refill auto des vies est applique a chaque lecture : on
# calcule delta, on UPDATE si necessaire, on commit. Cote client
# le compteur affiche est toujours a jour.
#
# Note : la creation d'une ligne user_games se fait via
# /api/codes/activate (module codes/), pas ici. Cet endpoint est
# lecture seule.
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..db import get_db
from .models import UserGame
from .refill import apply_refill
from .schemas import UserGameOut

router = APIRouter()


async def _apply_refill_persist(
    db: AsyncSession,
    ug: UserGame,
) -> int | None:
    """Applique le refill sur un user_game, persiste si change.

    Renvoie seconds_to_next_life (None si max).
    """
    res = apply_refill(
        current_lives=ug.lives,
        max_lives=ug.max_lives,
        last_refill=ug.lives_last_refill,
    )
    if res.lives_added > 0:
        ug.lives = res.new_lives
        ug.lives_last_refill = res.new_last_refill
        # Note : le commit est gere par l'endpoint appelant.
        await db.flush()
    return res.seconds_to_next_life


def _to_out(ug: UserGame, seconds_to_next: int | None) -> UserGameOut:
    return UserGameOut(
        user_id=ug.user_id,
        game_id=ug.game_id,
        activation_code=ug.activation_code,
        current_level=ug.current_level,
        total_score=ug.total_score,
        lives=ug.lives,
        max_lives=ug.max_lives,
        lives_last_refill=ug.lives_last_refill,
        activated_at=ug.activated_at,
        seconds_to_next_life=seconds_to_next,
    )


@router.get(
    "/games",
    response_model=list[UserGameOut],
    summary="Liste les jeux actives par le user avec refill (user)",
    description=(
        "Renvoie tous les user_games du user connecte (jeux actives "
        "via un code), tries par activated_at desc. Le refill auto "
        "des vies est applique a chaque lecture : delta calcule, "
        "UPDATE en DB si necessaire, commit. Le champ "
        "seconds_to_next_life indique le temps restant avant le "
        "prochain refill. Lecture seule : la creation se fait via "
        "/api/codes/activate."
    ),
)
async def list_my_games(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> list[UserGameOut]:
    rows = list(
        await db.scalars(
            select(UserGame)
            .where(UserGame.user_id == user.id)
            .order_by(UserGame.activated_at.desc())
        )
    )
    # Applique le refill pour chaque ligne (rare cas qu'il y en
    # ait beaucoup : un user a typiquement 1-3 jeux actives).
    out = []
    for ug in rows:
        sec = await _apply_refill_persist(db, ug)
        out.append(_to_out(ug, sec))
    await db.commit()
    return out


@router.get(
    "/games/{game_id}",
    response_model=UserGameOut,
    summary="Detail d'un jeu actif pour le user avec refill (user)",
    description=(
        "Renvoie l'etat du user_games pour ce jeu (current_level, "
        "total_score, lives, etc.) avec refill auto applique. Erreur "
        "404 sans leak si l'user n'a pas active ce jeu (on ne dit "
        "pas si le jeu lui-meme existe)."
    ),
)
async def get_my_game(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> UserGameOut:
    ug = await db.scalar(
        select(UserGame).where(
            UserGame.user_id == user.id,
            UserGame.game_id == game_id,
        )
    )
    if not ug:
        # 404 sans leak : on ne dit pas si le jeu existe ou pas,
        # juste que l'user n'a pas active ce jeu.
        raise HTTPException(404, "Jeu non active pour cet utilisateur")
    sec = await _apply_refill_persist(db, ug)
    await db.commit()
    return _to_out(ug, sec)
