# =============================================================
# FICHIER : app/cards/routes.py
# ROLE    : CRUD cartes  +  upload multipart  +  serve local
# =============================================================
#
# Endpoints :
#   GET    /api/games/{gid}/cards      liste cartes du jeu
#   POST   /api/games/{gid}/cards      crée carte avec image (multipart, admin)
#   PATCH  /api/cards/{id}             update label / type (admin)
#   DELETE /api/cards/{id}             supprime carte + fichier (admin)
#   GET    /api/cards/file/{key:path}  sert un fichier (mode LOCAL)
#
# Upload multipart unique : on combine fichier + metadonnees dans
# UNE requete -> transaction logique "upload+INSERT ou rollback".
# Si l'INSERT DB rate apres upload, on supprime le fichier.
# =============================================================

from pathlib import Path
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_admin
from ..auth.models import User
from ..config import settings
from ..db import get_db
from ..games.models import Game
from ..storage import CardStorage, get_storage
from .image import validate_and_process
from .models import Card, CardType
from .schemas import CardOut, CardUpdate

router = APIRouter()


async def _build_card_out(card: Card, storage: CardStorage) -> CardOut:
    """Enrichit le DTO avec une image_url calculee selon backend."""
    url = await storage.public_url(card.object_key)
    return CardOut.model_validate({**card.__dict__, "image_url": url})


# -------------------------------------------------------------
# LIST par game
# -------------------------------------------------------------
@router.get(
    "/games/{game_id}/cards",
    response_model=list[CardOut],
    summary="Liste les cartes d'un jeu (user)",
    description=(
        "Renvoie toutes les cartes d'un jeu, triees par created_at, "
        "avec une image_url calculee selon le backend de stockage "
        "(local ou S3/MinIO). Erreur 404 si le jeu est introuvable."
    ),
)
async def list_cards(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[CardOut]:
    if not await db.get(Game, game_id):
        raise HTTPException(404, "Jeu introuvable")
    result = await db.scalars(
        select(Card).where(Card.game_id == game_id).order_by(Card.created_at)
    )
    storage = get_storage()
    return [await _build_card_out(c, storage) for c in result]


# -------------------------------------------------------------
# CREATE (multipart : metadata + file en une seule requete)
# -------------------------------------------------------------
@router.post(
    "/games/{game_id}/cards",
    response_model=CardOut,
    status_code=201,
    summary="Cree une carte avec upload d'image (multipart, admin only)",
    description=(
        "Cree une carte (label + card_type) avec son image en "
        "multipart/form-data en une seule requete. Etapes : "
        "(1) verif taille (MAX_UPLOAD_BYTES), (2) validation + "
        "optimisation Pillow, (3) upload storage, (4) INSERT DB. "
        "Si l'INSERT echoue apres upload, le fichier est supprime "
        "(transaction logique). Erreurs : 404 jeu, 413 trop gros, "
        "400 image invalide."
    ),
)
async def create_card(
    game_id: UUID,
    label: Annotated[str, Form(min_length=1, max_length=120)],
    card_type: Annotated[CardType, Form()],
    file: Annotated[UploadFile, File()],
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> CardOut:
    if not await db.get(Game, game_id):
        raise HTTPException(404, "Jeu introuvable")

    # 1. Lire les bytes (limite memoire = MAX_UPLOAD_BYTES).
    raw = await file.read(settings.MAX_UPLOAD_BYTES + 1)
    if len(raw) > settings.MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Fichier trop volumineux")

    # 2. Validation + optimisation (Pillow).
    try:
        processed = validate_and_process(raw, file.content_type)
    except ValueError as e:
        raise HTTPException(400, str(e)) from e

    # 3. Upload storage.
    storage = get_storage()
    key = await storage.save(
        str(game_id),
        processed.bytes,
        processed.content_type,
        processed.extension,
    )

    # 4. INSERT DB. Si echec -> rollback fichier (cohérence).
    try:
        card = Card(
            game_id=game_id,
            label=label,
            object_key=key,
            content_type=processed.content_type,
            card_type=card_type,
        )
        db.add(card)
        await db.commit()
        await db.refresh(card)
    except Exception:
        await db.rollback()
        await storage.delete(key)
        raise

    return await _build_card_out(card, storage)


# -------------------------------------------------------------
# UPDATE metadata
# -------------------------------------------------------------
@router.patch(
    "/cards/{card_id}",
    response_model=CardOut,
    summary="Met a jour les metadonnees d'une carte (admin only)",
    description=(
        "Update partial d'une Card : label et/ou card_type. L'image "
        "elle-meme N'EST PAS modifiable par ce endpoint (pour changer "
        "l'image, supprimer + recreer). Erreur 404 si introuvable."
    ),
)
async def update_card(
    card_id: UUID,
    body: CardUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> CardOut:
    card = await db.get(Card, card_id)
    if not card:
        raise HTTPException(404, "Carte introuvable")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(card, k, v)
    await db.commit()
    await db.refresh(card)
    return await _build_card_out(card, get_storage())


# -------------------------------------------------------------
# DELETE (DB + storage)
# -------------------------------------------------------------
@router.delete(
    "/cards/{card_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Supprime une carte et son fichier (admin only)",
    description=(
        "Supprime la ligne Card en DB puis le fichier dans le storage. "
        "Ordre intentionnel : DB d'abord (si le storage rate apres, on "
        "a juste un fichier orphelin, mieux qu'une Card fantome). "
        "Erreur 404 si carte introuvable."
    ),
)
async def delete_card(
    card_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> None:
    card = await db.get(Card, card_id)
    if not card:
        raise HTTPException(404, "Carte introuvable")
    storage = get_storage()
    # Supprime DB d'abord ; si storage rate on a une URL morte (mieux
    # qu'une carte fantome dans la DB).
    await db.delete(card)
    await db.commit()
    await storage.delete(card.object_key)


# -------------------------------------------------------------
# SERVE local (utilise UNIQUEMENT si STORAGE_BACKEND=local)
# -------------------------------------------------------------
# Pour le mode S3, l'URL retournee par public_url() pointe direct
# vers MinIO/S3 -> cet endpoint n'est jamais appele.
# -------------------------------------------------------------
@router.get(
    "/cards/file/{object_key:path}",
    include_in_schema=False,
    summary="Sert un fichier carte en mode storage local (no auth)",
    description=(
        "Endpoint interne utilise UNIQUEMENT quand STORAGE_BACKEND=local "
        "(en S3/MinIO les URLs pointent directement vers l'objet). "
        "Protege contre path traversal en verifiant que le chemin "
        "resolu reste dans LOCAL_STORAGE_DIR. Hidden de Swagger via "
        "include_in_schema=False. Erreurs : 404 si fichier introuvable "
        "ou backend != local."
    ),
)
async def serve_card_file(object_key: str) -> FileResponse:
    if settings.STORAGE_BACKEND != "local":
        raise HTTPException(404, "Endpoint local desactive (backend = s3)")
    root = Path(settings.LOCAL_STORAGE_DIR).resolve()
    path = (root / object_key).resolve()
    # Defense path traversal : verifie qu'on reste dans root.
    if not str(path).startswith(str(root)) or not path.exists():
        raise HTTPException(404, "Fichier introuvable")
    return FileResponse(
        path,
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )
