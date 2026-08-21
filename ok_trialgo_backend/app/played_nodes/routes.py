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
from sqlalchemy.dialects.postgresql import insert as pg_insert
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
    # -----------------------------------------------------------
    # POURQUOI ON N'ATTRAPE PLUS L'IntegrityError
    # -----------------------------------------------------------
    # La version precedente inserait puis rattrapait le conflit :
    #
    #     db.add(row)
    #     try:            await db.commit()
    #     except IntegrityError:
    #         await db.rollback()
    #         existing = await db.scalar(select(...user.id...))
    #
    # Elle renvoyait 500 a chaque rejeu, alors que la contrainte
    # UNIQUE etait bien la et l'endpoint documente comme idempotent.
    #
    # La raison n'etait pas le conflit lui-meme, correctement
    # rattrape, mais le rollback : dans SQLAlchemy, rollback()
    # EXPIRE tous les objets de la session, y compris le `user`
    # injecte par la dependance. La ligne suivante lisait `user.id`,
    # ce qui declenchait un rechargement paresseux -- donc une
    # entree/sortie -- depuis un acces d'attribut synchrone. D'ou le
    # MissingGreenlet, transforme en 500 par FastAPI.
    #
    # On confie donc la resolution du conflit a PostgreSQL, avec le
    # ON CONFLICT DO NOTHING que la documentation de cet endpoint
    # promettait deja. Plus de commit en echec, donc plus de
    # rollback, donc plus d'objet expire : le mode de defaillance
    # disparait au lieu d'etre rattrape.
    #
    # On lit user.id AVANT toute ecriture, par principe : c'est ce
    # qui rend la fonction insensible a un futur rollback.
    # -----------------------------------------------------------
    user_id = user.id

    insertion = (
        pg_insert(UserPlayedNode)
        .values(
            user_id=user_id,
            game_id=body.game_id,
            tracking_key=body.tracking_key,
        )
        .on_conflict_do_nothing(constraint="uq_user_played_nodes_key")
        .returning(UserPlayedNode)
    )
    row = await db.scalar(insertion)
    await db.commit()

    if row is None:
        # Conflit : la cle etait deja marquee. DO NOTHING ne renvoie
        # rien dans ce cas, on relit donc la ligne existante pour
        # pouvoir retourner son played_at d'origine.
        row = await db.scalar(
            select(UserPlayedNode).where(
                UserPlayedNode.user_id == user_id,
                UserPlayedNode.game_id == body.game_id,
                UserPlayedNode.tracking_key == body.tracking_key,
            )
        )
        if row is None:
            # Inatteignable en pratique : il y a eu conflit, donc la
            # ligne existe. Sauf suppression concurrente entre les
            # deux requetes.
            raise HTTPException(409, "Ligne supprimee pendant l'insertion")

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
