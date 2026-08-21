# =============================================================
# FICHIER : app/played_nodes/routes.py
# ROLE    : Endpoints /api/me/played-nodes (tracking anti-doublon)
# =============================================================
#
# Endpoints :
#   POST   /api/me/played-nodes                marque une tracking_key
#   GET    /api/me/played-nodes?game_id=...    liste les keys deja jouees
#   DELETE /api/me/played-nodes?game_id=...    reset (vide pour ce jeu)
#
# Le POST est idempotent (ON CONFLICT DO NOTHING via UNIQUE).
# Le GET retourne juste les tracking_key (le client compare en local).
# Le DELETE permet a un user de "reset" ses tracking_keys pour
# rejouer des questions qu'il avait deja vues.
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..db import get_db
from .models import UserPlayedNode
from .schemas import PlayedNodeIn, PlayedNodeOut

router = APIRouter()


# -------------------------------------------------------------
# POST mark played
# -------------------------------------------------------------
@router.post(
    "/played-nodes",
    response_model=PlayedNodeOut,
    status_code=201,
    summary="Marque une tracking_key comme deja jouee (user)",
    description=(
        "Insere une ligne user_played_nodes (anti-doublon de questions). "
        "Idempotent : sur conflit (UNIQUE user/game/tracking_key), on "
        "absorbe l'erreur et retourne la ligne existante. Le serveur "
        "garde l'historique, le client compare en local pour eviter "
        "de poser deux fois la meme question."
    ),
)
async def mark_played(
    body: PlayedNodeIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> PlayedNodeOut:
    row = UserPlayedNode(
        user_id=user.id,
        game_id=body.game_id,
        tracking_key=body.tracking_key,
    )
    db.add(row)
    try:
        await db.commit()
        await db.refresh(row)
    except IntegrityError:
        # Deja marque : on retourne la ligne existante (idempotent).
        await db.rollback()
        existing = await db.scalar(
            select(UserPlayedNode).where(
                UserPlayedNode.user_id == user.id,
                UserPlayedNode.game_id == body.game_id,
                UserPlayedNode.tracking_key == body.tracking_key,
            )
        )
        if not existing:
            # Cas tres improbable (race), fallback erreur.
            raise HTTPException(500, "Etat incoherent") from None
        row = existing
    return PlayedNodeOut.model_validate(row)


# -------------------------------------------------------------
# GET played keys (par jeu)
# -------------------------------------------------------------
@router.get(
    "/played-nodes",
    response_model=list[PlayedNodeOut],
    summary="Liste les tracking_keys deja jouees pour un jeu (user)",
    description=(
        "Renvoie toutes les tracking_keys deja marquees comme jouees "
        "par le user pour un game_id, triees par played_at desc. "
        "Le client utilise ces keys pour filtrer les questions deja "
        "vues lors de la generation de session locale."
    ),
)
async def list_played(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    game_id: UUID,
) -> list[PlayedNodeOut]:
    rows = list(
        await db.scalars(
            select(UserPlayedNode)
            .where(
                UserPlayedNode.user_id == user.id,
                UserPlayedNode.game_id == game_id,
            )
            .order_by(UserPlayedNode.played_at.desc())
        )
    )
    return [PlayedNodeOut.model_validate(r) for r in rows]


# -------------------------------------------------------------
# DELETE reset (par jeu)
# -------------------------------------------------------------
@router.delete(
    "/played-nodes",
    status_code=204,
    summary="Reset les tracking_keys jouees pour un jeu (user)",
    description=(
        "Supprime toutes les lignes user_played_nodes pour le user "
        "et le game_id donnes. Permet au user de 'recommencer a zero' "
        "et de rejouer des questions deja vues. Action irreversible "
        "mais sans danger (les scores et l'historique de sessions sont "
        "preserves)."
    ),
)
async def reset_played(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    game_id: UUID,
) -> None:
    await db.execute(
        delete(UserPlayedNode).where(
            UserPlayedNode.user_id == user.id,
            UserPlayedNode.game_id == game_id,
        )
    )
    await db.commit()
