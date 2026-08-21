# =============================================================
# FICHIER : app/nodes/routes.py
# ROLE    : Endpoints fusions  +  analyse de liaison
# =============================================================
#
# Endpoints (TOUS admin-only : la structure des fusions est le
# secret du jeu ; un joueur qui pourrait list/next-index/analyze
# obtiendrait toutes les reponses gratuitement) :
#   GET    /api/games/{gid}/nodes              liste fusions   (admin)
#   GET    /api/games/{gid}/nodes/next-index   prochain node_index (admin)
#   POST   /api/games/{gid}/nodes              cree une fusion (admin)
#   DELETE /api/nodes/{id}                     supprime (admin, cascade)
#   POST   /api/games/{gid}/nodes/analyze      analyse 3 cartes (admin)
#
# Le joueur passe par /api/sessions/{sid}/attempts (module play/)
# qui valide une tentative sans jamais reveler la structure.
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_admin, get_current_user
from ..auth.models import User
from ..cards.models import Card
from ..db import get_db
from ..games.models import Game
from .analyzer import analyze_fusion
from .models import GameNode
from .schemas import AnalyzeIn, AnalyzeOut, NodeCreate, NodeOut

router = APIRouter()


# -------------------------------------------------------------
# LIST par game
# -------------------------------------------------------------
@router.get(
    "/games/{game_id}/nodes",
    response_model=list[NodeOut],
    summary="Liste les fusions d'un jeu (user authentifie)",
    description=(
        "Renvoie toutes les fusions (GameNode) d'un jeu, triees par "
        "node_index. Necessite une auth user (pas anonyme) : l'app "
        "joueur a besoin du graphe pour generer les questions cote "
        "client (calcul des distances entre cartes, choix des "
        "distracteurs, etc.). Le filtre anti-anonymous evite le "
        "scraping sans compte. Erreur 404 si jeu introuvable."
    ),
)
async def list_nodes(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _user: Annotated[User, Depends(get_current_user)],
) -> list[GameNode]:
    if not await db.get(Game, game_id):
        raise HTTPException(404, "Jeu introuvable")
    result = await db.scalars(
        select(GameNode).where(GameNode.game_id == game_id).order_by(GameNode.node_index)
    )
    return list(result)


# -------------------------------------------------------------
# NEXT INDEX (utilitaire pour le client admin : MAX+1)
# Admin-only : sert au wizard de creation de trio.
# -------------------------------------------------------------
@router.get(
    "/games/{game_id}/nodes/next-index",
    summary="Renvoie le prochain node_index disponible (admin only)",
    description=(
        "Utilitaire pour le wizard de creation de fusion : retourne "
        "MAX(node_index)+1 pour le jeu, ou 1 si aucune fusion. "
        "Permet au client admin d'afficher 'Vous creez le trio N+1'. "
        "ADMIN-ONLY (pour les memes raisons de secret que list_nodes)."
    ),
)
async def next_node_index(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> dict[str, int]:
    max_idx = await db.scalar(
        select(func.max(GameNode.node_index)).where(GameNode.game_id == game_id)
    )
    return {"next_index": (max_idx or 0) + 1}


# -------------------------------------------------------------
# CREATE fusion
# -------------------------------------------------------------
@router.post(
    "/games/{game_id}/nodes",
    response_model=NodeOut,
    status_code=201,
    summary="Cree une fusion / trio dans un jeu (admin only)",
    description=(
        "Cree un GameNode (fusion emettrice + cable + receptrice). "
        "Verifications : (1) toutes les cartes referencees existent "
        "et appartiennent au jeu (anti-cross-game), (2) si parent_node_id "
        "fourni, parent du meme jeu et depth = parent.depth + 1. "
        "node_index est auto-attribue (MAX+1). Erreurs : 404 jeu, 400 "
        "cartes invalides / parent invalide / contrainte violee."
    ),
)
async def create_node(
    game_id: UUID,
    body: NodeCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> GameNode:
    if not await db.get(Game, game_id):
        raise HTTPException(404, "Jeu introuvable")

    # Verifie que toutes les cartes referencees appartiennent bien
    # au jeu (evite cross-game node).
    ref_ids = [body.cable_id, body.receptrice_id]
    if body.emettrice_id:
        ref_ids.append(body.emettrice_id)
    cards = list(
        await db.scalars(
            select(Card).where(Card.id.in_(ref_ids), Card.game_id == game_id)
        )
    )
    if len(cards) != len(ref_ids):
        raise HTTPException(400, "Une ou plusieurs cartes referencees sont introuvables ou hors-jeu")

    # Si parent fourni : doit appartenir au meme jeu + depth coherent.
    if body.parent_node_id:
        parent = await db.get(GameNode, body.parent_node_id)
        if not parent or parent.game_id != game_id:
            raise HTTPException(400, "Parent introuvable ou hors-jeu")
        if body.depth != parent.depth + 1:
            raise HTTPException(400, f"depth doit valoir {parent.depth + 1} (parent.depth + 1)")

    # node_index : MAX + 1 pour ce jeu.
    max_idx = await db.scalar(
        select(func.max(GameNode.node_index)).where(GameNode.game_id == game_id)
    )
    node = GameNode(
        game_id=game_id,
        node_index=(max_idx or 0) + 1,
        emettrice_id=body.emettrice_id,
        cable_id=body.cable_id,
        receptrice_id=body.receptrice_id,
        parent_node_id=body.parent_node_id,
        depth=body.depth,
    )
    db.add(node)
    try:
        await db.commit()
    except IntegrityError as e:
        await db.rollback()
        raise HTTPException(400, f"Violation contrainte : {e.orig}") from e
    await db.refresh(node)
    return node


# -------------------------------------------------------------
# DELETE fusion (cascade descendants via FK CASCADE)
# -------------------------------------------------------------
@router.delete(
    "/nodes/{node_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Supprime une fusion (cascade descendants, admin only)",
    description=(
        "Supprime un GameNode. Les noeuds enfants (parent_node_id) sont "
        "supprimes en cascade via FK ON DELETE CASCADE. Erreur 404 si "
        "fusion introuvable. Action irreversible."
    ),
)
async def delete_node(
    node_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> None:
    node = await db.get(GameNode, node_id)
    if not node:
        raise HTTPException(404, "Fusion introuvable")
    await db.delete(node)
    await db.commit()


# -------------------------------------------------------------
# ANALYZE 3 cartes
# -------------------------------------------------------------
@router.post(
    "/games/{game_id}/nodes/analyze",
    response_model=AnalyzeOut,
    summary="Analyse un trio de cartes contre les fusions (admin only)",
    description=(
        "Etant donne 3 card_ids, dit si elles forment une fusion "
        "existante (D1 simple ou D2 chainee), et quel role elles "
        "occupent. Outil d'aide a la creation pour les admins. "
        "STRICT ADMIN-ONLY : un joueur ayant acces a cet endpoint "
        "decouvre toute la structure du jeu en iterant. Le joueur "
        "doit utiliser sessions/attempts qui valide sans reveler."
    ),
)
async def analyze(
    game_id: UUID,
    body: AnalyzeIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> AnalyzeOut:
    # Admin-only : un joueur ne doit JAMAIS pouvoir appeler cet
    # endpoint, sinon il decouvre toute la structure du jeu en
    # iterant. Le joueur a son propre endpoint /api/sessions/.../
    # attempts qui valide sans reveler.
    if not await db.get(Game, game_id):
        raise HTTPException(404, "Jeu introuvable")
    nodes = list(await db.scalars(select(GameNode).where(GameNode.game_id == game_id)))
    cards = list(await db.scalars(select(Card).where(Card.game_id == game_id)))
    return analyze_fusion(body.card_ids, nodes, cards)
