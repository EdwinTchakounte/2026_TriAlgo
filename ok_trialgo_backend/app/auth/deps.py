# =============================================================
# FICHIER : app/auth/deps.py
# ROLE    : Dependencies FastAPI pour auth (current user / admin)
# =============================================================
#
# Toutes les routes protegees declarent :
#   user: User = Depends(get_current_user)       # juste connecte
#   user: User = Depends(get_current_admin)      # connecte + admin
#
# get_current_admin = get_current_user + verif is_admin.
#
# Le header attendu est "Authorization: Bearer <access_jwt>".
# Si manquant ou invalide -> 401. Si non admin -> 403.
# =============================================================

from typing import Annotated, Optional
from uuid import UUID

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from .jwt import decode_token
from .models import User

# OAuth2PasswordBearer alimente le schema OpenAPI avec le bon header.
# tokenUrl est juste documentaire (le vrai endpoint login est ailleurs).
_oauth = OAuth2PasswordBearer(tokenUrl="api/auth/login")
# Variante "optionnelle" : auto_error=False -> ne leve PAS 401 si le
# header manque. Permet aux routes hybrides (publiques + enrichies si
# user connecte) de fonctionner avec ou sans token.
_oauth_optional = OAuth2PasswordBearer(tokenUrl="api/auth/login", auto_error=False)


async def get_current_user(
    token: Annotated[str, Depends(_oauth)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> User:
    credentials_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token invalide ou expire",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise credentials_exc
        sub = payload.get("sub")
        if not sub:
            raise credentials_exc
        user_id = UUID(sub)
    except (JWTError, ValueError) as e:
        raise credentials_exc from e

    user = await db.scalar(select(User).where(User.id == user_id))
    if not user or not user.is_active:
        raise credentials_exc
    return user


async def get_current_admin(
    user: Annotated[User, Depends(get_current_user)],
) -> User:
    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acces reserve aux admins",
        )
    return user


# -------------------------------------------------------------
# get_current_user_optional :
#   - Si Authorization Bearer absent  -> renvoie None (pas d'erreur)
#   - Si present mais invalide        -> renvoie None aussi (on degrade
#       gracieusement plutot que de bloquer une route publique pour
#       cause de token corrompu cote client)
#   - Si present et valide            -> renvoie l'User
#
# Cas d'usage : GET /api/games doit retourner :
#   - admin connecte : TOUS les games (meme is_active=false)
#   - utilisateur normal / anonyme : uniquement is_active=true
# La route teste user is None or not user.is_admin -> filtre.
# -------------------------------------------------------------
async def get_current_user_optional(
    token: Annotated[Optional[str], Depends(_oauth_optional)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Optional[User]:
    if not token:
        return None
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            return None
        sub = payload.get("sub")
        if not sub:
            return None
        user_id = UUID(sub)
    except (JWTError, ValueError):
        return None

    user = await db.scalar(select(User).where(User.id == user_id))
    if not user or not user.is_active:
        return None
    return user
