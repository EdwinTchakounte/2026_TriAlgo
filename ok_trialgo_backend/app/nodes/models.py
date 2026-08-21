# =============================================================
# FICHIER : app/nodes/models.py
# ROLE    : Modele SQLAlchemy GameNode (une fusion)
# =============================================================
#
# Une fusion = (ingredient_a + ingredient_b => produit) avec un
# parent optionnel (chainage Dn -> Dn+1).
#
# Invariants encodes :
#   - CHECK depth >= 1 AND depth <= 5
#   - CHECK (emettrice_id IS NULL) = (parent_node_id IS NOT NULL)
#     => exactement un des deux (un xor : emettrice OU parent, pas
#     les deux a la fois - voir Pydantic schema pour message clair)
#   - UNIQUE (game_id, node_index) : numerotation dense par jeu
#   - FK parent_node_id -> nodes.id ON DELETE CASCADE
#   - FK *_id -> cards.id (pas de cascade : on protege l'integrite)
# =============================================================

import uuid
from datetime import datetime

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class GameNode(Base):
    __tablename__ = "nodes"
    __table_args__ = (
        UniqueConstraint("game_id", "node_index", name="uq_nodes_game_index"),
        CheckConstraint("depth >= 1 AND depth <= 5", name="ck_nodes_depth_range"),
        CheckConstraint(
            "(emettrice_id IS NULL) = (parent_node_id IS NOT NULL)",
            name="ck_nodes_emettrice_xor_parent",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    game_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("games.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    node_index: Mapped[int] = mapped_column(Integer, nullable=False)
    emettrice_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cards.id"), nullable=True,
    )
    cable_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cards.id"), nullable=False,
    )
    receptrice_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("cards.id"), nullable=False,
    )
    parent_node_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("nodes.id", ondelete="CASCADE"),
        nullable=True,
    )
    depth: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
