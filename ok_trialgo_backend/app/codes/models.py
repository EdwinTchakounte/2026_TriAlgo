# =============================================================
# FICHIER : app/codes/models.py
# ROLE    : Modele SQLAlchemy ActivationCode
# =============================================================

from datetime import datetime
from uuid import UUID

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class ActivationCode(Base):
    __tablename__ = "activation_codes"
    __table_args__ = (
        # Un user ne peut avoir qu'UN code par jeu.
        UniqueConstraint(
            "assigned_to", "game_id",
            name="uq_activation_codes_user_game",
        ),
    )

    # PK = le code clair (str). C'est l'identifiant naturel cote business.
    code: Mapped[str] = mapped_column(String(64), primary_key=True)
    game_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("games.id", ondelete="CASCADE"),
        nullable=False,
    )
    # SET NULL : si user supprime, le code redevient disponible.
    assigned_to: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    device_id: Mapped[str | None] = mapped_column(String(200), nullable=True)
    device_changes_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    max_device_changes: Mapped[int] = mapped_column(
        Integer, nullable=False, default=3
    )
    is_blocked: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    activated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
