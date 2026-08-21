# =============================================================
# FICHIER : app/sessions_history/models.py
# ROLE    : Modele SQLAlchemy UserSession (historique partie)
# =============================================================

import uuid
from datetime import datetime
from uuid import UUID

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class UserSession(Base):
    __tablename__ = "user_sessions"
    __table_args__ = (
        CheckConstraint("level >= 1", name="ck_user_sessions_level"),
        CheckConstraint("score_gained >= 0", name="ck_user_sessions_score"),
        CheckConstraint("correct_answers >= 0", name="ck_user_sessions_correct"),
        CheckConstraint("wrong_answers >= 0", name="ck_user_sessions_wrong"),
        CheckConstraint("questions_total >= 0", name="ck_user_sessions_total"),
        CheckConstraint("max_streak >= 0", name="ck_user_sessions_streak"),
        CheckConstraint("duration_seconds >= 0", name="ck_user_sessions_duration"),
        CheckConstraint(
            "stars_earned BETWEEN 0 AND 3",
            name="ck_user_sessions_stars",
        ),
        CheckConstraint(
            "correct_answers + wrong_answers <= questions_total",
            name="ck_user_sessions_count_coherent",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
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
    level: Mapped[int] = mapped_column(Integer, nullable=False)
    score_gained: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    correct_answers: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    wrong_answers: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    questions_total: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    max_streak: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    duration_seconds: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    passed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False
    )
    # Cosmetique fin de partie (0..3) selon accuracy.
    stars_earned: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0
    )
    played_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
