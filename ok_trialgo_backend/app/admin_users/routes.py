# =============================================================
# FICHIER : app/admin_users/routes.py
# ROLE    : Endpoints admin de gestion des comptes users
# =============================================================
#
# Endpoints (tous get_current_admin) :
#   GET   /api/admin/users                  liste paginated
#   GET   /api/admin/users/{id}             detail
#   POST  /api/admin/users/{id}/promote     toggle is_admin + mail notif
#   PATCH /api/admin/users/{id}             modif (is_active)
#                                            -> envoie mail deactivated
#
# Guards specifiques :
#   - Un admin ne peut PAS se desactiver lui-meme (eviter le
#     lockout).
#   - Un admin ne peut PAS se demouvoir si c'est le SEUL admin
#     restant (eviter de perdre tous les acces admin).
# =============================================================

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_admin
from ..auth.models import User
from ..db import get_db
from ..mail.sender import send_account_deactivated, send_admin_promoted
from .schemas import AdminUserOut, AdminUserUpdate, PaginatedAdminUsers

router = APIRouter()


# -------------------------------------------------------------
# LIST users (paginated)
# -------------------------------------------------------------
@router.get(
    "/users",
    response_model=PaginatedAdminUsers,
    summary="Liste paginee des comptes utilisateurs (admin only)",
    description=(
        "Renvoie une page de comptes users (UserOut), triee par "
        "created_at desc, avec total / limit / offset pour la "
        "pagination cote client. Bornes : limit dans [1,100], offset "
        ">= 0. Erreur 400 si parametres hors bornes."
    ),
)
async def list_users(
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
    limit: int = 20,
    offset: int = 0,
) -> PaginatedAdminUsers:
    if limit < 1 or limit > 100:
        raise HTTPException(400, "limit doit etre entre 1 et 100")
    if offset < 0:
        raise HTTPException(400, "offset >= 0")

    # Total separe (count) puis page (select).
    total = await db.scalar(select(func.count(User.id)))
    rows = list(
        await db.scalars(
            select(User)
            .order_by(User.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
    )
    return PaginatedAdminUsers(
        items=[AdminUserOut.model_validate(u) for u in rows],
        total=int(total or 0),
        limit=limit,
        offset=offset,
    )


# -------------------------------------------------------------
# GET user (detail)
# -------------------------------------------------------------
@router.get(
    "/users/{user_id}",
    response_model=AdminUserOut,
    summary="Detail d'un compte utilisateur (admin only)",
    description=(
        "Renvoie le profil complet d'un user par UUID, avec champs "
        "admin (is_active, is_admin, email_confirmed_at, etc.). "
        "Erreur 404 si introuvable."
    ),
)
async def get_user(
    user_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> AdminUserOut:
    u = await db.get(User, user_id)
    if not u:
        raise HTTPException(404, "Utilisateur introuvable")
    return AdminUserOut.model_validate(u)


# -------------------------------------------------------------
# TOGGLE is_admin
# -------------------------------------------------------------
@router.post(
    "/users/{user_id}/promote",
    response_model=AdminUserOut,
    summary="Bascule le statut admin d'un compte (admin only)",
    description=(
        "Toggle is_admin sur un user (promotion ou demotion). "
        "Garde-fou : un admin ne peut PAS se demouvoir s'il est le "
        "SEUL admin actif restant (eviter lockout). Side-effect : "
        "envoie un mail 'vous etes promu admin' uniquement lors de la "
        "promotion (pas en demotion). Erreurs : 404 introuvable, 400 "
        "auto-demotion interdite."
    ),
)
async def promote_user(
    user_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    admin: Annotated[User, Depends(get_current_admin)],
    background: BackgroundTasks,
) -> AdminUserOut:
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(404, "Utilisateur introuvable")

    # Garde-fou : demotion de soi-meme alors qu'on est le seul admin
    # restant -> rejet (sinon plus aucun admin). On compte les
    # autres admins actifs (pas inclus l'admin courant).
    if target.id == admin.id and target.is_admin:
        other_admins = await db.scalar(
            select(func.count(User.id)).where(
                User.is_admin.is_(True),
                User.is_active.is_(True),
                User.id != admin.id,
            )
        )
        if not other_admins:
            raise HTTPException(
                400,
                "Vous ne pouvez pas vous demouvoir : aucun autre admin actif",
            )

    # Toggle.
    was_promoted = not target.is_admin
    target.is_admin = not target.is_admin
    await db.commit()
    await db.refresh(target)

    # Mail uniquement si on vient de promouvoir (pas de mail si on
    # demotait : la notif "vous etes plus admin" est sensible -
    # a faire plus tard si necessaire).
    if was_promoted:
        background.add_task(
            send_admin_promoted,
            to_email=target.email,
            to_name=None,
        )
    return AdminUserOut.model_validate(target)


# -------------------------------------------------------------
# PATCH user (is_active)
# -------------------------------------------------------------
@router.patch(
    "/users/{user_id}",
    response_model=AdminUserOut,
    summary="Met a jour un compte (is_active) (admin only)",
    description=(
        "Update partial d'un user. Pour l'instant gere is_active "
        "(activation/desactivation du compte). Garde-fou : un admin "
        "ne peut PAS desactiver son propre compte. Side-effect : si "
        "passage active -> inactive, envoie un mail 'compte desactive' "
        "en background. Erreurs : 404 introuvable, 400 self-deactivate."
    ),
)
async def update_user(
    user_id: UUID,
    body: AdminUserUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    admin: Annotated[User, Depends(get_current_admin)],
    background: BackgroundTasks,
) -> AdminUserOut:
    target = await db.get(User, user_id)
    if not target:
        raise HTTPException(404, "Utilisateur introuvable")

    # Garde-fou : pas de self-deactivation.
    if (
        body.is_active is False
        and target.id == admin.id
    ):
        raise HTTPException(400, "Vous ne pouvez pas desactiver votre propre compte")

    was_active = target.is_active
    if body.is_active is not None:
        target.is_active = body.is_active
    await db.commit()
    await db.refresh(target)

    # Mail uniquement si on vient de PASSER de active->inactive
    # (eviter spam si patch repete).
    if was_active and target.is_active is False:
        background.add_task(
            send_account_deactivated,
            to_email=target.email,
            deactivated_at=datetime.now(timezone.utc),
        )
    return AdminUserOut.model_validate(target)
