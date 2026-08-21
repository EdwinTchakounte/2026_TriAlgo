"""user_unlocked_cards + user_played_nodes

Revision ID: 0008_unlocked_and_played
Revises: 0007_sessions_history
Create Date: 2026-06-04

Deux tables proches conceptuellement :

  user_unlocked_cards :
    Deck du joueur. Quand il gagne une carte (bonne reponse), on
    insere une ligne. C'est ce qui peuple la page Galerie.
    PK composite (user, card, game) = idempotent par nature.

  user_played_nodes :
    Tracking_key opaque pour anti-doublon. Sert au generator de
    questions cote client : on ne re-pose pas une question deja
    jouee. UNIQUE(user, game, tracking_key) avec id UUID separe
    pour pouvoir le supprimer/recycler en cas de reset.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0008_unlocked_and_played"
down_revision: Union[str, None] = "0007_sessions_history"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---------------------------------------------------------
    # user_unlocked_cards
    # ---------------------------------------------------------
    op.create_table(
        "user_unlocked_cards",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "card_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cards.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # game_id redondant (deductible via cards.game_id) mais on
        # le garde explicite pour pouvoir indexer (user, game) sans
        # JOIN, et pour le scenario rare ou une carte serait mutee
        # de jeu.
        sa.Column(
            "game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "unlocked_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        # PK composite : un user ne peut "unlocker" deux fois la
        # meme carte sur le meme jeu (idempotent).
        sa.PrimaryKeyConstraint(
            "user_id", "card_id", "game_id",
            name="pk_user_unlocked_cards",
        ),
    )
    # Index pour la query la plus frequente : "mon deck pour ce jeu".
    op.create_index(
        "ix_user_unlocked_cards_user_game",
        "user_unlocked_cards",
        ["user_id", "game_id"],
    )

    # ---------------------------------------------------------
    # user_played_nodes
    # ---------------------------------------------------------
    op.create_table(
        "user_played_nodes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # Clef opaque generee cote client : combinaison de
        # node_index + level + variation par exemple. Pas de FK
        # vers nodes car la cle peut composer plusieurs nodes.
        sa.Column("tracking_key", sa.String(255), nullable=False),
        sa.Column(
            "played_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        # UNIQUE composite pour idempotence.
        sa.UniqueConstraint(
            "user_id", "game_id", "tracking_key",
            name="uq_user_played_nodes_key",
        ),
    )
    op.create_index(
        "ix_user_played_nodes_user_game",
        "user_played_nodes",
        ["user_id", "game_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_user_played_nodes_user_game",
        table_name="user_played_nodes",
    )
    op.drop_table("user_played_nodes")
    op.drop_index(
        "ix_user_unlocked_cards_user_game",
        table_name="user_unlocked_cards",
    )
    op.drop_table("user_unlocked_cards")
