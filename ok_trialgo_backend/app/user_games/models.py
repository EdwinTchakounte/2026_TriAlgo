# =============================================================
# FICHIER : app/user_games/models.py
# ROLE    : Modele SQLAlchemy UserGame (etat par-jeu d'un user)
# =============================================================

from datetime import datetime
from uuid import UUID

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    PrimaryKeyConstraint,
    String,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class UserGame(Base):
    __tablename__ = "user_games"
    __table_args__ = (
        # PK composite (defini aussi cote migration).
        PrimaryKeyConstraint("user_id", "game_id", name="pk_user_games"),
        CheckConstraint(
            "lives >= 0 AND lives <= max_lives",
            name="ck_user_games_lives_range",
        ),
        CheckConstraint(
            "total_score >= 0",
            name="ck_user_games_score_positive",
        ),
        CheckConstraint(
            "current_level >= 1",
            name="ck_user_games_level_positive",
        ),
    )

    user_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    game_id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("games.id", ondelete="CASCADE"),
        nullable=False,
    )
    activation_code: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("activation_codes.code", ondelete="RESTRICT"),
        nullable=False,
    )
    current_level: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1
    )
    total_score: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    lives: Mapped[int] = mapped_column(
        Integer, nullable=False, default=5
    )
    max_lives: Mapped[int] = mapped_column(
        Integer, nullable=False, default=5
    )
    lives_last_refill: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    activated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
