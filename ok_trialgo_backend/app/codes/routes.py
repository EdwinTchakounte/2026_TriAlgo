# =============================================================
# FICHIER : app/codes/routes.py
# ROLE    : Endpoints activation_codes (joueur + admin)
# =============================================================
#
# Joueur :
#   POST /api/codes/activate   {code, device_id}
#     -> 5 cas possibles (success + 4 erreurs reasoned)
#
# Admin :
#   GET   /api/admin/codes               liste paginated
#   POST  /api/admin/codes               cree un code
#   GET   /api/admin/codes/{code}        detail
#   PATCH /api/admin/codes/{code}        is_active / reset_assignment
#   DELETE /api/admin/codes/{code}       suppression
#
# La route joueur encapsule la logique RPC Supabase activate_code
# en Python pur (pas de plpgsql). On garde l'atomicite via la
# transaction SQLAlchemy (un seul commit pour tout le bloc).
# =============================================================

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_admin, get_current_user
from ..auth.models import User
from ..core.rate_limit import RateLimit, verifier_quota
from ..db import get_db
from ..games.models import Game
from ..mail.sender import send_code_activated
from ..user_games.models import UserGame
from .models import ActivationCode
from .schemas import (
    ActivateCodeIn,
    ActivateCodeOut,
    AdminCodeCreate,
    AdminCodeOut,
    AdminCodeUpdate,
    PaginatedAdminCodes,
)

router = APIRouter()


# =============================================================
# JOUEUR : POST /api/codes/activate
# =============================================================
@router.post(
    "/codes/activate",
    dependencies=[Depends(RateLimit("activation", limite=20, fenetre_secondes=3600))],
    response_model=ActivateCodeOut,
    summary="Active un code d'activation pour le user (user)",
    description=(
        "Tente d'activer un ActivationCode pour le user connecte sur "
        "un device donne. 5 cas possibles renvoyes 200 OK avec "
        "success+reason : (1) succes premiere activation, cree la "
        "ligne user_games ; (2) re-activation meme device (no-op) ; "
        "(3) changement de device (consomme un quota, bloque si limite "
        "atteinte) ; (4) deja assigne a un autre user ; (5) user a "
        "deja un autre code pour ce jeu (anti-double-vie)."
    ),
)
async def activate_code(
    body: ActivateCodeIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    background: BackgroundTasks,
) -> ActivateCodeOut:
    # Limite adossee au COMPTE, en plus de celle par IP.
    #
    # C'est ici que se joue la protection du produit : un code devine
    # est une licence volee. La limite par IP se contourne avec un
    # simple relais ; celle-ci oblige a creer un compte par tranche de
    # 20 essais, ce qui rend l'enumeration inexploitable.
    #
    # 20 essais par heure laisse toute la place aux fautes de frappe
    # d'un acheteur legitime, qui en fait deux ou trois au plus.
    await verifier_quota(
        db,
        cle=f"activation:compte:{user.id}",
        limite=20,
        fenetre_secondes=3600,
    )

    # 1. Charger le code (PK = string).
    code = await db.get(ActivationCode, body.code)
    if not code:
        return ActivateCodeOut(
            success=False,
            reason="invalid",
            message="Code invalide",
        )

    # 2. Code desactive par admin.
    if not code.is_active:
        return ActivateCodeOut(
            success=False,
            reason="inactive",
            message="Code desactive",
        )

    # 3. Code bloque (max changements atteint).
    if code.is_blocked:
        return ActivateCodeOut(
            success=False,
            reason="blocked",
            message="Code bloque (trop de changements de device)",
            changes_left=0,
        )

    # 4. Code deja assigne a un AUTRE user.
    if code.assigned_to is not None and code.assigned_to != user.id:
        return ActivateCodeOut(
            success=False,
            reason="already_assigned_other",
            message="Ce code est deja utilise par un autre joueur",
        )

    # 5. Si pas encore assigne, verifier que l'user n'a pas deja
    #    un code actif pour ce jeu (anti-double-vie).
    if code.assigned_to is None:
        existing_code = await db.scalar(
            select(ActivationCode.code).where(
                ActivationCode.assigned_to == user.id,
                ActivationCode.game_id == code.game_id,
                ActivationCode.code != body.code,
            )
        )
        if existing_code:
            return ActivateCodeOut(
                success=False,
                reason="already_active_other_game",
                message=f"Vous avez deja active ce jeu avec le code {existing_code}",
            )

    # ---- A partir d'ici, le code est valide pour cet user ----

    # CAS A : Premiere activation (pas encore de user assigne).
    if code.assigned_to is None:
        code.assigned_to = user.id
        code.device_id = body.device_id
        code.activated_at = datetime.now(timezone.utc)
        # Creer la ligne user_games associee (etat initial : level 1,
        # 5 vies, score 0). ON CONFLICT DO NOTHING pour idempotence
        # si l'admin a creer cette ligne par avance.
        existing_ug = await db.scalar(
            select(UserGame).where(
                UserGame.user_id == user.id,
                UserGame.game_id == code.game_id,
            )
        )
        if existing_ug is None:
            db.add(
                UserGame(
                    user_id=user.id,
                    game_id=code.game_id,
                    activation_code=code.code,
                )
            )
        # Charger le nom du jeu pour le mail (avant commit pour eviter
        # un round-trip apres).
        game = await db.get(Game, code.game_id)
        await db.commit()
        # Envoi mail "code active" en background (non bloquant).
        # Notification one-shot : on n'envoie pas a chaque re-activation
        # ou changement de device pour eviter le spam.
        if game is not None:
            background.add_task(
                send_code_activated,
                to_email=user.email,
                to_name=user.username,
                game_name=game.name,
                code=code.code,
                changes_left=code.max_device_changes,
            )
        return ActivateCodeOut(
            success=True,
            message="Code active",
            game_id=code.game_id,
            changes_left=code.max_device_changes,
        )

    # CAS B : Re-activation sur le MEME device (RAS).
    if code.device_id == body.device_id:
        await db.commit()  # no-op mais conservatif
        return ActivateCodeOut(
            success=True,
            message="Code deja actif sur ce device",
            game_id=code.game_id,
            changes_left=code.max_device_changes - code.device_changes_count,
        )

    # CAS C : Changement de device.
    new_count = code.device_changes_count + 1
    if new_count >= code.max_device_changes:
        # Blocage definitif.
        code.device_changes_count = new_count
        code.is_blocked = True
        code.device_id = body.device_id
        await db.commit()
        return ActivateCodeOut(
            success=False,
            reason="blocked",
            message="Limite de changements atteinte (code bloque)",
            changes_left=0,
        )
    # Changement autorise.
    code.device_changes_count = new_count
    code.device_id = body.device_id
    await db.commit()
    return ActivateCodeOut(
        success=True,
        message="Device change",
        game_id=code.game_id,
        changes_left=code.max_device_changes - new_count,
    )


# =============================================================
# ADMIN : CRUD
# =============================================================

@router.get(
    "/admin/codes",
    response_model=PaginatedAdminCodes,
    summary="Liste paginee des codes d'activation (admin only)",
    description=(
        "Renvoie une page de codes triee par created_at desc, avec "
        "filtre optionnel game_id. Bornes : limit dans [1,200], "
        "offset >= 0. Utilise par le studio admin pour gerer les "
        "stocks de codes."
    ),
)
async def list_codes(
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
    limit: int = 50,
    offset: int = 0,
    game_id: UUID | None = None,
) -> PaginatedAdminCodes:
    if limit < 1 or limit > 200:
        raise HTTPException(400, "limit doit etre entre 1 et 200")
    if offset < 0:
        raise HTTPException(400, "offset >= 0")

    # Filtres optionnels.
    stmt = select(ActivationCode).order_by(ActivationCode.created_at.desc())
    count_stmt = select(func.count(ActivationCode.code))
    if game_id is not None:
        stmt = stmt.where(ActivationCode.game_id == game_id)
        count_stmt = count_stmt.where(ActivationCode.game_id == game_id)

    total = await db.scalar(count_stmt)
    rows = list(await db.scalars(stmt.limit(limit).offset(offset)))
    return PaginatedAdminCodes(
        items=[AdminCodeOut.model_validate(c) for c in rows],
        total=int(total or 0),
        limit=limit,
        offset=offset,
    )


@router.post(
    "/admin/codes",
    response_model=AdminCodeOut,
    status_code=201,
    summary="Cree un nouveau code d'activation (admin only)",
    description=(
        "Cree un ActivationCode rattache a un jeu, avec un quota "
        "max_device_changes. Verifie que le jeu existe (404 sinon) et "
        "que le code n'existe pas deja (409 sinon). Le code est "
        "immediatement is_active=true et non assigne."
    ),
)
async def create_code(
    body: AdminCodeCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> AdminCodeOut:
    # Verifier que le jeu existe.
    if not await db.get(Game, body.game_id):
        raise HTTPException(404, "Jeu introuvable")

    # Verifier unicite du code (PK).
    if await db.get(ActivationCode, body.code):
        raise HTTPException(409, "Code deja existant")

    c = ActivationCode(
        code=body.code,
        game_id=body.game_id,
        max_device_changes=body.max_device_changes,
    )
    db.add(c)
    await db.commit()
    await db.refresh(c)
    return AdminCodeOut.model_validate(c)


@router.get(
    "/admin/codes/{code}",
    response_model=AdminCodeOut,
    summary="Detail d'un code d'activation (admin only)",
    description=(
        "Renvoie le detail d'un code (etat, assigne, device, "
        "compteur de changements, blocage). Erreur 404 si introuvable."
    ),
)
async def get_code(
    code: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> AdminCodeOut:
    c = await db.get(ActivationCode, code)
    if not c:
        raise HTTPException(404, "Code introuvable")
    return AdminCodeOut.model_validate(c)


@router.patch(
    "/admin/codes/{code}",
    response_model=AdminCodeOut,
    summary="Met a jour un code (activate / reset SAV) (admin only)",
    description=(
        "Update partial d'un ActivationCode : (1) is_active "
        "true/false pour (de)activer le code, (2) reset_assignment "
        "remet le code dans l'etat 'jamais active' (assigned_to/device "
        "a NULL, compteur a 0, deblocage). Use case principal : SAV "
        "lorsque le joueur a perdu son telephone. Erreur 404 si "
        "introuvable."
    ),
)
async def update_code(
    code: str,
    body: AdminCodeUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> AdminCodeOut:
    c = await db.get(ActivationCode, code)
    if not c:
        raise HTTPException(404, "Code introuvable")
    if body.is_active is not None:
        c.is_active = body.is_active
    # Reset assignment : remet le code a "jamais active". Sert au SAV
    # (joueur a perdu son tel) ou pour realloer un code.
    if body.reset_assignment:
        c.assigned_to = None
        c.device_id = None
        c.device_changes_count = 0
        c.is_blocked = False
        c.activated_at = None
    await db.commit()
    await db.refresh(c)
    return AdminCodeOut.model_validate(c)


@router.delete(
    "/admin/codes/{code}",
    status_code=204,
    summary="Supprime un code d'activation (admin only)",
    description=(
        "Supprime definitivement un ActivationCode. Note : le FK "
        "user_games.activation_code est en RESTRICT, donc la suppression "
        "echouera si un user_games s'y refere encore (force l'admin a "
        "desassocier d'abord). Erreur 404 si introuvable."
    ),
)
async def delete_code(
    code: str,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> None:
    c = await db.get(ActivationCode, code)
    if not c:
        raise HTTPException(404, "Code introuvable")
    # Note : RESTRICT sur user_games.activation_code peut empecher
    # la suppression si un user_games s'y refere encore. C'est
    # voulu (force admin a desassocier d'abord).
    await db.delete(c)
    await db.commit()
