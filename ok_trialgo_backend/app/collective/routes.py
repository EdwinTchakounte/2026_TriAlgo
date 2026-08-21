# =============================================================
# FICHIER : app/collective/routes.py
# ROLE    : Endpoint mode collectif : verify_collective_trio
# =============================================================
#
# Endpoint :
#   POST /api/games/{game_id}/verify-collective
#     body : { node_index: int }
#     out  : { exists, node_index, depth, emettrice/cable/receptrice_label }
#
# Mode "collectif" : un anim referee donne un numero de trio
# (ex: "T17"), l'app du joueur verifie aupres du serveur si ce
# numero existe, et affiche les labels resolus. La resolution de
# l'emettrice tient compte du chainage (effective_emettrice depuis
# le parent si emettrice_id NULL).
#
# Auth user : pas admin (n'importe quel joueur connecte peut
# verifier). On veut quand meme une auth pour eviter le scraping
# anonyme de la structure du jeu (qui donnerait les reponses).
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..cards.models import Card
from ..db import get_db
from ..games.models import Game
from ..nodes.models import GameNode

router = APIRouter()


class VerifyCollectiveIn(BaseModel):
    node_index: int = Field(ge=1)


class VerifyCollectiveOut(BaseModel):
    exists: bool
    node_index: int | None = None
    depth: int | None = None
    emettrice_label: str | None = None
    cable_label: str | None = None
    receptrice_label: str | None = None
    message: str | None = None


@router.post(
    "/{game_id}/verify-collective",
    response_model=VerifyCollectiveOut,
    summary="Verifie l'existence d'un trio par node_index (user, mode collectif)",
    description=(
        "Mode collectif : un animateur referee annonce un numero "
        "(ex: 'T17') et l'app du joueur appelle cet endpoint pour "
        "confirmer l'existence du trio et obtenir les labels resolus "
        "(emettrice / cable / receptrice). L'emettrice effective est "
        "resolue via le chainage (emettrice du parent si NULL). Auth "
        "user obligatoire pour eviter le scraping anonyme de la "
        "structure. Erreur 404 si jeu introuvable."
    ),
)
async def verify_collective(
    game_id: UUID,
    body: VerifyCollectiveIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    _user: Annotated[User, Depends(get_current_user)],
) -> VerifyCollectiveOut:
    # Verifier que le jeu existe (404 sinon).
    if not await db.get(Game, game_id):
        raise HTTPException(404, "Jeu introuvable")

    # 1. Charger le node par (game_id, node_index).
    node = await db.scalar(
        select(GameNode).where(
            GameNode.game_id == game_id,
            GameNode.node_index == body.node_index,
        )
    )
    if not node:
        return VerifyCollectiveOut(
            exists=False,
            message="Trio inexistant pour ce jeu",
        )

    # 2. Resoudre l'emettrice effective (eventuellement depuis parent).
    if node.emettrice_id is not None:
        emettrice_id = node.emettrice_id
    else:
        if node.parent_node_id is None:
            # Incoherence : noeud sans emettrice ET sans parent.
            # Ne devrait pas arriver grace au CHECK constraint.
            return VerifyCollectiveOut(
                exists=False,
                message="Noeud incoherent",
            )
        parent = await db.get(GameNode, node.parent_node_id)
        if not parent:
            return VerifyCollectiveOut(
                exists=False,
                message="Parent introuvable",
            )
        emettrice_id = parent.receptrice_id

    # 3. Charger les 3 cartes pour avoir les labels (1 requete batchee).
    cards_rows = list(
        await db.scalars(
            select(Card).where(
                Card.id.in_([emettrice_id, node.cable_id, node.receptrice_id])
            )
        )
    )
    by_id: dict[UUID, Card] = {c.id: c for c in cards_rows}
    e = by_id.get(emettrice_id)
    c = by_id.get(node.cable_id)
    r = by_id.get(node.receptrice_id)

    return VerifyCollectiveOut(
        exists=True,
        node_index=node.node_index,
        depth=node.depth,
        emettrice_label=e.label if e else None,
        cable_label=c.label if c else None,
        receptrice_label=r.label if r else None,
    )
