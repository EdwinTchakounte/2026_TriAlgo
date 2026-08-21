# =============================================================
# FICHIER : app/mail/tokens.py
# ROLE    : Generation + verification de tokens email TTL
# =============================================================
#
# Modele :
#   1. generate_email_token(user_id, purpose) :
#      - Tire un token clair (32 bytes urlsafe = 43 chars).
#      - Stocke EN DB son sha256 hex + expires_at.
#      - Renvoie le token CLAIR (a inserer dans l'URL email).
#
#   2. verify_and_consume(token_clair, purpose) :
#      - Hash le token recu.
#      - SELECT par token_hash + purpose + used_at IS NULL +
#        expires_at > now().
#      - Si trouve : SET used_at = now(), renvoie user_id.
#      - Sinon : None (rejet).
#
# Securite :
#   - Comparaison constant-time NON NECESSAIRE ici car on lookup
#     par hash en DB (pas de comparaison byte-a-byte dans le code).
#   - Token clair JAMAIS stocke nulle part (DB voit que le hash).
# =============================================================

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from .models import EMAIL_PURPOSE_CONFIRM, EMAIL_PURPOSE_RESET, EmailToken


def _hash_token(token_clear: str) -> str:
    """SHA-256 hex (64 chars). On stocke ca en DB, jamais le clair."""
    return hashlib.sha256(token_clear.encode("utf-8")).hexdigest()


def _ttl_minutes_for(purpose: str) -> int:
    """TTL configurable par usage."""
    if purpose == EMAIL_PURPOSE_RESET:
        return settings.EMAIL_TOKEN_TTL_RESET_MINUTES
    if purpose == EMAIL_PURPOSE_CONFIRM:
        return settings.EMAIL_TOKEN_TTL_CONFIRM_MINUTES
    # Defaut conservateur : 1h.
    return 60


async def generate_email_token(
    db: AsyncSession,
    user_id: UUID,
    purpose: str,
) -> str:
    """Cree un token TTL et renvoie le clair (a inclure dans l'URL).

    Le clair n'est PAS persiste : il vit uniquement le temps du
    mail. Si l'user perd le mail, il doit re-demander un nouveau
    token (et l'ancien expirera tout seul).
    """
    # 32 bytes urlsafe -> 43 caracteres alphanumeric + - et _.
    # secrets.token_urlsafe est cryptographiquement sur.
    token_clear = secrets.token_urlsafe(32)
    token_hash = _hash_token(token_clear)
    expires_at = datetime.now(timezone.utc) + timedelta(
        minutes=_ttl_minutes_for(purpose)
    )
    record = EmailToken(
        user_id=user_id,
        purpose=purpose,
        token_hash=token_hash,
        expires_at=expires_at,
    )
    db.add(record)
    # On ne commit pas ici : l'appelant decide (souvent il commit
    # dans la meme transaction qu'une autre op metier).
    await db.flush()
    return token_clear


async def verify_and_consume(
    db: AsyncSession,
    token_clear: str,
    purpose: str,
) -> UUID | None:
    """Verifie un token recu et le marque comme consomme.

    Renvoie le user_id si OK, None sinon (token invalide, expire,
    ou deja utilise, ou mauvais purpose).
    """
    if not token_clear:
        return None
    token_hash = _hash_token(token_clear)
    now = datetime.now(timezone.utc)
    record = await db.scalar(
        select(EmailToken).where(
            EmailToken.token_hash == token_hash,
            EmailToken.purpose == purpose,
            EmailToken.used_at.is_(None),
            EmailToken.expires_at > now,
        )
    )
    if record is None:
        return None
    # Marque consomme + commit transactionnel cote appelant.
    record.used_at = now
    await db.flush()
    return record.user_id
