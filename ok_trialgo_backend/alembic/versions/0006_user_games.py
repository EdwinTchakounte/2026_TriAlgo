"""user_games : etat par-jeu d'un user (level, score, vies)

Revision ID: 0006_user_games
Revises: 0005_activation_codes
Create Date: 2026-06-04

Porte Supabase user_games :
  - 1 ligne = etat d'un user dans UN jeu specifique
  - current_level : niveau atteint (1..N)
  - total_score : score cumule sur ce jeu (utilise par leaderboard)
  - lives / max_lives / lives_last_refill : systeme de vies avec
    refill auto (30 min/vie cf decision user)
  - activation_code : reference au code utilise

PK composite (user_id, game_id) : pas besoin d'un id UUID, le
couple est l'identite naturelle (un user ne peut avoir qu'UN etat
par jeu, garanti par UNIQUE de activation_codes).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006_user_games"
down_revision: Union[str, None] = "0005_activation_codes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_games",
        # Composante 1 de la PK : user. CASCADE car les stats n'ont
        # aucun sens sans le user.
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # Composante 2 : jeu. CASCADE car idem.
        sa.Column(
            "game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # Code utilise pour activer ce jeu. RESTRICT : on ne peut
        # pas supprimer un code qui est encore utilise activement
        # (force l'admin a desassocier d'abord = is_active=false).
        sa.Column(
            "activation_code",
            sa.String(64),
            sa.ForeignKey("activation_codes.code", ondelete="RESTRICT"),
            nullable=False,
        ),
        # Niveau courant (1..N selon contenu du jeu).
        sa.Column(
            "current_level",
            sa.Integer,
            nullable=False,
            server_default="1",
        ),
        # Score cumule (utilise pour leaderboard).
        sa.Column(
            "total_score",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Vies courantes (0..max_lives).
        sa.Column(
            "lives",
            sa.Integer,
            nullable=False,
            server_default="5",
        ),
        # Plafond des vies. Default 5 (cf Supabase).
        sa.Column(
            "max_lives",
            sa.Integer,
            nullable=False,
            server_default="5",
        ),
        # Timestamp UTC du dernier refill applique. Sert au calcul
        # de regen automatique (30 min/vie).
        sa.Column(
            "lives_last_refill",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "activated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        # PK composite (user_id, game_id).
        sa.PrimaryKeyConstraint("user_id", "game_id", name="pk_user_games"),
        # CHECKs defensifs.
        sa.CheckConstraint(
            "lives >= 0 AND lives <= max_lives",
            name="ck_user_games_lives_range",
        ),
        sa.CheckConstraint(
            "total_score >= 0",
            name="ck_user_games_score_positive",
        ),
        sa.CheckConstraint(
            "current_level >= 1",
            name="ck_user_games_level_positive",
        ),
    )

    # Index pour leaderboard rapide : "top scores pour ce jeu".
    op.create_index(
        "ix_user_games_leaderboard",
        "user_games",
        ["game_id", sa.text("total_score DESC")],
    )


def downgrade() -> None:
    op.drop_index("ix_user_games_leaderboard", table_name="user_games")
    op.drop_table("user_games")
