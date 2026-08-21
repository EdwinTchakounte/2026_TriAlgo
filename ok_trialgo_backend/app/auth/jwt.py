# =============================================================
# FICHIER : app/auth/jwt.py
# ROLE    : Encode / decode des tokens JWT (access + refresh)
# =============================================================
#
# JWT vs session :
#   - JWT = stateless (le serveur n'a rien a stocker)
#   - Le client envoie le token a chaque requete (Authorization: Bearer)
#   - On signe avec JWT_SECRET (HS256) : si secret fuite, on revoque
#     en changeant le secret (= invalide tous les tokens existants)
#
# Deux tokens differents :
#   - access  : courte duree (24h), sert a authentifier les requetes
#   - refresh : longue duree (30j), sert UNIQUEMENT a obtenir un
#               nouveau access. Stocke dans Storage securise cote
#               client.
# =============================================================

from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

from jose import JWTError, jwt

from ..config import settings


def _now() -> datetime:
    return datetime.now(timezone.utc)


def create_access_token(user_id: UUID, is_admin: bool) -> str:
    """JWT court : porte l'identite + flag admin."""
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "is_admin": is_admin,
        "type": "access",
        "iat": _now(),
        "exp": _now() + timedelta(minutes=settings.JWT_EXPIRE_MINUTES),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: UUID) -> str:
    """JWT long, pour renouveler les access sans relogin."""
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "type": "refresh",
        "iat": _now(),
        "exp": _now() + timedelta(days=settings.JWT_REFRESH_EXPIRE_DAYS),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict[str, Any]:
    """Decode + verifie signature + expiration. Leve JWTError si invalide."""
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])


__all__ = ["create_access_token", "create_refresh_token", "decode_token", "JWTError"]
