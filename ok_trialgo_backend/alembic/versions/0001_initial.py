"""initial schema : users + games + cards + nodes

Revision ID: 0001_initial
Revises:
Create Date: 2026-05-30

Cree les 4 tables fondamentales avec contraintes :
  - users  (auth)
  - games  (jeux)
  - cards  (cartes, image stockee en object_key)
  - nodes  (fusions, avec CHECK + UNIQUE + FK cascade)
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---- USERS ----
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("password_hash", sa.String(60), nullable=False),
        sa.Column("is_admin", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    # ---- GAMES ----
    op.create_table(
        "games",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("theme", sa.String(60), nullable=True),
        sa.Column("cover_image", sa.Text, nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # ---- CARDS ----
    op.create_table(
        "cards",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("label", sa.String(120), nullable=False),
        sa.Column("object_key", sa.String(500), nullable=False),
        sa.Column("content_type", sa.String(60), nullable=False, server_default="image/jpeg"),
        sa.Column("card_type", sa.String(20), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "card_type IN ('emettrice','cable','receptrice')",
            name="ck_cards_card_type",
        ),
    )
    op.create_index("ix_cards_game_id", "cards", ["game_id"])

    # ---- NODES ----
    op.create_table(
        "nodes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("node_index", sa.Integer, nullable=False),
        sa.Column(
            "emettrice_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cards.id"),
            nullable=True,
        ),
        sa.Column(
            "cable_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cards.id"),
            nullable=False,
        ),
        sa.Column(
            "receptrice_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cards.id"),
            nullable=False,
        ),
        sa.Column(
            "parent_node_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("nodes.id", ondelete="CASCADE"),
            nullable=True,
        ),
        sa.Column("depth", sa.Integer, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("game_id", "node_index", name="uq_nodes_game_index"),
        sa.CheckConstraint("depth >= 1 AND depth <= 5", name="ck_nodes_depth_range"),
        sa.CheckConstraint(
            "(emettrice_id IS NULL) = (parent_node_id IS NOT NULL)",
            name="ck_nodes_emettrice_xor_parent",
        ),
    )
    op.create_index("ix_nodes_game_id", "nodes", ["game_id"])


def downgrade() -> None:
    op.drop_table("nodes")
    op.drop_table("cards")
    op.drop_table("games")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
