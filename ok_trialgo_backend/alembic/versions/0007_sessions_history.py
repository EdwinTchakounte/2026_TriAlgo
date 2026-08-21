"""user_sessions : historique de chaque partie jouee

Revision ID: 0007_sessions_history
Revises: 0006_user_games
Create Date: 2026-06-04

Porte Supabase user_sessions :
  - 1 ligne = 1 partie jouee a un niveau precis
  - INSERT a la fin de la partie, JAMAIS UPDATE
  - Trace : level, score_gained, correct/wrong/total, max_streak,
    duration_seconds, passed, stars_earned (0..3 cosmetique)

Stars_earned (0-3) = recompense cosmetique badge fin de partie.
NE PAS confondre avec stars (wallet economy sur users) qui est
la monnaie virtuelle pour echanger contre des vies.

Note de nommage : Supabase appelle ca "user_sessions". J'aurais
prefere "play_history" ou "game_attempts" pour eviter la confusion
avec "session JWT". On garde user_sessions pour rester aligne avec
le code Flutter existant (Repository, providers, etc.).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0007_sessions_history"
down_revision: Union[str, None] = "0006_user_games"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_sessions",
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
        # Niveau joue (1..N).
        sa.Column("level", sa.Integer, nullable=False),
        # Score gagne pendant CETTE partie (delta, pas cumule).
        sa.Column(
            "score_gained",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Compteurs de bonnes/mauvaises reponses.
        sa.Column(
            "correct_answers",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "wrong_answers",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Nb total de questions de la partie (denormalise vs sum
        # correct+wrong pour permettre l'abandon en cours).
        sa.Column(
            "questions_total",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Meilleure serie de bonnes reponses consecutives.
        sa.Column(
            "max_streak",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Duree reelle de la partie (s).
        sa.Column(
            "duration_seconds",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Le joueur a-t-il valide le niveau ?
        sa.Column(
            "passed",
            sa.Boolean,
            nullable=False,
            server_default=sa.false(),
        ),
        # Etoiles cosmetiques (0..3 selon accuracy).
        sa.Column(
            "stars_earned",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "played_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        # CHECKs defensifs (coherence des compteurs).
        sa.CheckConstraint("level >= 1", name="ck_user_sessions_level"),
        sa.CheckConstraint("score_gained >= 0", name="ck_user_sessions_score"),
        sa.CheckConstraint("correct_answers >= 0", name="ck_user_sessions_correct"),
        sa.CheckConstraint("wrong_answers >= 0", name="ck_user_sessions_wrong"),
        sa.CheckConstraint("questions_total >= 0", name="ck_user_sessions_total"),
        sa.CheckConstraint("max_streak >= 0", name="ck_user_sessions_streak"),
        sa.CheckConstraint("duration_seconds >= 0", name="ck_user_sessions_duration"),
        sa.CheckConstraint(
            "stars_earned BETWEEN 0 AND 3",
            name="ck_user_sessions_stars",
        ),
        sa.CheckConstraint(
            "correct_answers + wrong_answers <= questions_total",
            name="ck_user_sessions_count_coherent",
        ),
    )

    # Index principal : historique d'un user pour un jeu.
    op.create_index(
        "ix_user_sessions_user_game_date",
        "user_sessions",
        ["user_id", "game_id", sa.text("played_at DESC")],
    )
    # Index stats par niveau.
    op.create_index(
        "ix_user_sessions_user_game_level",
        "user_sessions",
        ["user_id", "game_id", "level"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_user_sessions_user_game_level",
        table_name="user_sessions",
    )
    op.drop_index(
        "ix_user_sessions_user_game_date",
        table_name="user_sessions",
    )
    op.drop_table("user_sessions")
