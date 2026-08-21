# =============================================================
# FICHIER : app/played_nodes/models.py
# ROLE    : Modele UserPlayedNode (anti-doublon questions)
# =============================================================

import uuid
from datetime import datetime
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class UserPlayedNode(Base):
    __tablename__ = "user_played_nodes"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "game_id", "tracking_key",
            name="uq_user_played_nodes_key",
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
    # Clef opaque generee cote client (ex: "node_5_lvl_3_var_a").
    tracking_key: Mapped[str] = mapped_column(String(255), nullable=False)
    played_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
