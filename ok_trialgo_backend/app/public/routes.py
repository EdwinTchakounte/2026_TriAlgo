# =============================================================
# FICHIER : app/public/routes.py
# ROLE    : Endpoints de decouverte joueur (sans auth requise)
# =============================================================
#
# Endpoints :
#   GET  /api/public/games                 liste games actifs
#   GET  /api/public/games/{id}            detail game actif
#   GET  /api/public/games/{id}/cards      cartes (sans type)
#
# Pas d'auth requise -> permet une vitrine "marketing" / preview
# avant inscription. Aucun champ sensible exposé.
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..cards.models import Card
from ..db import get_db
from ..games.models import Game
from ..storage import get_storage
from ..storage.base import CardStorage
from .schemas import PublicCardOut, PublicGameOut

router = APIRouter()


def _to_public_game(g: Game) -> PublicGameOut:
    """Strip les champs sensibles avant de renvoyer au joueur."""
    return PublicGameOut(
        id=g.id,
        name=g.name,
        description=g.description,
        theme=g.theme,
        cover_image=g.cover_image,
    )


async def _to_public_card(c: Card, storage: CardStorage) -> PublicCardOut:
    """Card publique : pas de card_type, juste l'image + label."""
    url = await storage.public_url(c.object_key)
    return PublicCardOut(
        id=c.id,
        game_id=c.game_id,
        label=c.label,
        image_url=url,
    )


# -------------------------------------------------------------
# LIST games actifs
# -------------------------------------------------------------
@router.get(
    "/games",
    response_model=list[PublicGameOut],
    summary="Liste les jeux actifs en mode vitrine (no auth)",
    description=(
        "Liste publique des jeux actifs (is_active=true), triee par "
        "created_at desc. Sans champs sensibles. Permet une vitrine "
        "marketing/preview avant inscription, sans avoir besoin d'un "
        "compte ni d'un token."
    ),
)
async def list_public_games(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[PublicGameOut]:
    rows = await db.scalars(
        select(Game)
        .where(Game.is_active.is_(True))
        .order_by(Game.created_at.desc())
    )
    return [_to_public_game(g) for g in rows]


# -------------------------------------------------------------
# GET game actif (detail)
# -------------------------------------------------------------
@router.get(
    "/games/{game_id}",
    response_model=PublicGameOut,
    summary="Detail d'un jeu actif en mode vitrine (no auth)",
    description=(
        "Renvoie le detail d'un jeu actif. Erreur 404 si jeu "
        "introuvable OU inactif (ne pas leaker l'existence d'un draft). "
        "Champs filtres : seulement infos vitrine (pas de structure)."
    ),
)
async def get_public_game(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> PublicGameOut:
    g = await db.get(Game, game_id)
    # Renvoie 404 si introuvable OU si inactif (ne pas leak).
    if not g or not g.is_active:
        raise HTTPException(404, "Jeu introuvable")
    return _to_public_game(g)


# -------------------------------------------------------------
# LIST cards d'un game actif
# -------------------------------------------------------------
@router.get(
    "/games/{game_id}/cards",
    response_model=list[PublicCardOut],
    summary="Liste les cartes d'un jeu actif en vitrine (no auth)",
    description=(
        "Liste publique des cartes d'un jeu actif, triees par label. "
        "Le card_type N'EST PAS expose (info de gameplay sensible) : "
        "seulement id, label et image_url. Erreur 404 si jeu "
        "introuvable ou inactif."
    ),
)
async def list_public_cards(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[PublicCardOut]:
    g = await db.get(Game, game_id)
    if not g or not g.is_active:
        raise HTTPException(404, "Jeu introuvable")
    rows = await db.scalars(
        select(Card)
        .where(Card.game_id == game_id)
        .order_by(Card.label.asc())
    )
    storage = get_storage()
    return [await _to_public_card(c, storage) for c in rows]
