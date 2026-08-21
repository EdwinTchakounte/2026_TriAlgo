# =============================================================
# FICHIER : app/mail/models.py
# ROLE    : Modeles SQLAlchemy EmailToken + EmailPreferences
# =============================================================
#
# EmailToken :
#   Token TTL pour confirm/reset. On stocke le HASH (sha256) du
#   token, pas le clair. used_at marque la consommation single-use.
#
# EmailPreferences :
#   Opt-in par categorie. Ne couvre PAS les emails transactionnels
#   (welcome/reset/etc.) qui sont obligatoires.
# =============================================================

import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


# Constantes purpose : aligne avec CHECK de la migration.
EMAIL_PURPOSE_CONFIRM = "email_confirm"
EMAIL_PURPOSE_RESET = "password_reset"


class EmailToken(Base):
    __tablename__ = "email_tokens"
    __table_args__ = (
        CheckConstraint(
            "purpose IN ('email_confirm','password_reset')",
            name="ck_email_tokens_purpose",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    # Type d'usage : pour rejeter un reset pretend etre un confirm.
    purpose: Mapped[str] = mapped_column(String(40), nullable=False)
    # SHA-256 hex (64 chars) du token clair envoye au user.
    token_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    # Date d'expiration absolue (TTL).
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    # Marqueur single-use : NULL = jamais utilise, sinon date de
    # consommation. Une fois set, le token est dead -> replay block.
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class EmailPreferences(Base):
    __tablename__ = "email_preferences"

    # PK = user_id : un seul jeu de prefs par user.
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    # Marketing : off par defaut (RGPD-friendly).
    marketing: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    # Resume de fin de session : on par defaut (engagement).
    session_summary: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    # Notif nouveau jeu : on par defaut.
    new_game: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
