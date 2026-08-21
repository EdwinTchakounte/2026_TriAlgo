# =============================================================
# FICHIER : app/unlocked_cards/routes.py
# ROLE    : Endpoints /api/me/unlocked-cards (deck galerie)
# =============================================================
#
# Endpoints :
#   POST /api/me/unlocked-cards               unlock une carte
#   GET  /api/me/unlocked-cards?game_id=...   deck pour ce jeu
#
# Le POST est idempotent (ON CONFLICT DO NOTHING via la PK
# composite : si la carte est deja unlocked, no-op + 200).
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..cards.models import Card
from ..db import get_db
from ..storage import get_storage
from .models import UserUnlockedCard
from .schemas import UnlockCardIn, UnlockedCardOut

router = APIRouter()


# -------------------------------------------------------------
# POST unlock
# -------------------------------------------------------------
@router.post(
    "/unlocked-cards",
    response_model=UnlockedCardOut,
    status_code=201,
    summary="Debloque une carte pour le deck du user (user)",
    description=(
        "Marque une carte comme debloquee pour le user dans un jeu "
        "donne. Idempotent : si la carte est deja debloquee, on "
        "absorbe l'IntegrityError et renvoie la ligne existante (no-op). "
        "Anti-cross-game : la carte doit appartenir au jeu declare "
        "(404 sinon). Renvoie label + image_url enrichis."
    ),
)
async def unlock_card(
    body: UnlockCardIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> UnlockedCardOut:
    # Verifier que la carte existe et appartient au game declare
    # (anti-cross-game cheat).
    card = await db.get(Card, body.card_id)
    if not card or card.game_id != body.game_id:
        raise HTTPException(404, "Carte introuvable pour ce jeu")

    # INSERT idempotent : si deja unlocked, on absorbe l'IntegrityError.
    row = UserUnlockedCard(
        user_id=user.id,
        card_id=body.card_id,
        game_id=body.game_id,
    )
    db.add(row)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        # Recharger la ligne existante pour renvoyer son unlocked_at.
        existing = await db.scalar(
            select(UserUnlockedCard).where(
                UserUnlockedCard.user_id == user.id,
                UserUnlockedCard.card_id == body.card_id,
                UserUnlockedCard.game_id == body.game_id,
            )
        )
        if existing:
            row = existing
        # Sinon on tombera sur le refresh ci-dessous (peu probable).

    if row.unlocked_at is None:
        await db.refresh(row)

    url = await get_storage().public_url(card.object_key)
    return UnlockedCardOut(
        card_id=card.id,
        game_id=card.game_id,
        unlocked_at=row.unlocked_at,
        label=card.label,
        image_url=url,
    )


# -------------------------------------------------------------
# GET deck par jeu
# -------------------------------------------------------------
@router.get(
    "/unlocked-cards",
    response_model=list[UnlockedCardOut],
    summary="Renvoie le deck de cartes debloquees pour un jeu (user)",
    description=(
        "Liste les cartes debloquees par le user pour le game_id "
        "donne, triees par unlocked_at desc. Effectue un JOIN avec "
        "Card pour enrichir label + image_url. Utilise par l'ecran "
        "Galerie du jeu."
    ),
)
async def list_my_deck(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    game_id: UUID,
) -> list[UnlockedCardOut]:
    # JOIN UserUnlockedCard <-> Card pour enrichir label + image.
    stmt = (
        select(UserUnlockedCard, Card)
        .join(Card, Card.id == UserUnlockedCard.card_id)
        .where(
            UserUnlockedCard.user_id == user.id,
            UserUnlockedCard.game_id == game_id,
        )
        .order_by(UserUnlockedCard.unlocked_at.desc())
    )
    rows = list((await db.execute(stmt)).all())
    storage = get_storage()
    out = []
    for row in rows:
        unlocked: UserUnlockedCard = row[0]
        card: Card = row[1]
        url = await storage.public_url(card.object_key)
        out.append(
            UnlockedCardOut(
                card_id=card.id,
                game_id=card.game_id,
                unlocked_at=unlocked.unlocked_at,
                label=card.label,
                image_url=url,
            )
        )
    return out
