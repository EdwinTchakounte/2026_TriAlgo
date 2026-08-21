# =============================================================
# FICHIER : app/stars/routes.py
# ROLE    : Endpoints /api/me/stars (wallet + exchange-for-life)
# =============================================================
#
# Endpoints :
#   GET  /api/me/stars                       wallet (regen appliquee)
#   POST /api/me/stars/exchange-for-life     porte du RPC Supabase
#
# Cout fixe (10 etoiles) defini en constante. Si on veut un cout
# variable plus tard, le param sera dans ExchangeIn.
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..db import get_db
from ..user_games.models import UserGame
from .regen import apply_regen
from .schemas import ExchangeIn, ExchangeOut, WalletOut

router = APIRouter()


# Cost fixe d'une vie (cf Supabase).
EXCHANGE_COST = 10


# -------------------------------------------------------------
# GET wallet (regen appliquee + persiste si change)
# -------------------------------------------------------------
@router.get(
    "/stars",
    response_model=WalletOut,
    summary="Recupere le wallet d'etoiles avec regen appliquee (user)",
    description=(
        "Renvoie le solde d'etoiles du user (stars, stars_max) avec "
        "regen automatique appliquee : si du temps s'est ecoule "
        "depuis le dernier read, on credite les etoiles regenerees "
        "(clamp a stars_max) et on persiste. Le champ "
        "seconds_to_next_star indique le delai avant la prochaine "
        "etoile (None si deja au max)."
    ),
)
async def get_my_wallet(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> WalletOut:
    res = apply_regen(
        current_stars=user.stars,
        stars_max=user.stars_max,
        last_regen=user.stars_last_regen,
    )
    if res.stars_added > 0:
        user.stars = res.new_stars
        user.stars_last_regen = res.new_last_regen
        await db.commit()
    return WalletOut(
        stars=user.stars,
        stars_max=user.stars_max,
        seconds_to_next_star=res.seconds_to_next_star,
    )


# -------------------------------------------------------------
# POST exchange-for-life
# -------------------------------------------------------------
@router.post(
    "/stars/exchange-for-life",
    response_model=ExchangeOut,
    summary="Echange 10 etoiles contre une vie (user)",
    description=(
        "Echange atomique : applique d'abord la regen, puis si "
        "wallet suffisant et vies < max_lives pour le jeu cible "
        "(body.game_id ou selected_game_id du profil), debite "
        "EXCHANGE_COST (10) etoiles et credite +1 vie en un seul "
        "commit. Renvoie success=false avec reason si echec : "
        "no_game_selected, not_enough_stars, game_not_activated, "
        "lives_already_max."
    ),
)
async def exchange_for_life(
    body: ExchangeIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> ExchangeOut:
    # 1. Appliquer la regen avant l'echange (le user peut avoir
    # gagne assez d'etoiles depuis le dernier read).
    regen = apply_regen(
        current_stars=user.stars,
        stars_max=user.stars_max,
        last_regen=user.stars_last_regen,
    )
    if regen.stars_added > 0:
        user.stars = regen.new_stars
        user.stars_last_regen = regen.new_last_regen
        await db.flush()

    # 2. Resoudre le jeu cible : body.game_id ou selected_game_id.
    target_game_id = body.game_id or user.selected_game_id
    if target_game_id is None:
        return ExchangeOut(
            success=False,
            reason="no_game_selected",
            message="Aucun jeu selectionne",
            stars_after=user.stars,
        )

    # 3. Verifier le wallet.
    if user.stars < EXCHANGE_COST:
        return ExchangeOut(
            success=False,
            reason="not_enough_stars",
            message=f"Pas assez d'etoiles ({user.stars}/{EXCHANGE_COST})",
            stars_after=user.stars,
        )

    # 4. Charger user_games pour ce jeu.
    ug = await db.scalar(
        select(UserGame).where(
            UserGame.user_id == user.id,
            UserGame.game_id == target_game_id,
        )
    )
    if not ug:
        return ExchangeOut(
            success=False,
            reason="game_not_activated",
            message="Jeu non active pour cet utilisateur",
            stars_after=user.stars,
        )

    if ug.lives >= ug.max_lives:
        return ExchangeOut(
            success=False,
            reason="lives_already_max",
            message=f"Vies deja au max ({ug.lives}/{ug.max_lives})",
            stars_after=user.stars,
            lives_after=ug.lives,
            max_lives_after=ug.max_lives,
        )

    # 5. Atomique : -10 etoiles, +1 vie. Le commit unique garantit
    # l'integrite (ou tout passe, ou rien).
    user.stars -= EXCHANGE_COST
    ug.lives += 1
    await db.commit()

    return ExchangeOut(
        success=True,
        message="Echange reussi",
        stars_after=user.stars,
        lives_after=ug.lives,
        max_lives_after=ug.max_lives,
    )
