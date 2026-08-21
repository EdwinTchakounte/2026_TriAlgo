"""reset play tables + extend users (profile fields + stars wallet)

Revision ID: 0004_reset_play_extend_users
Revises: 0003_email
Create Date: 2026-06-04

Cette migration fait deux choses :

  1. DROP des tables `game_sessions` et `session_attempts` creees
     dans 0002_play. Ces tables ont ete concues sur un modele de
     gameplay incorrect (sessions de decouverte de trios libres).
     Le vrai gameplay (porte depuis Supabase) repose sur des
     parties par niveau avec questions, qui seront introduites
     dans les migrations 0006+ (user_games + user_sessions).

  2. ETEND la table users avec :
       - username        (affichage social)
       - avatar_id       (selecteur d'avatar)
       - selected_game_id (jeu actuellement actif)
       - stars / stars_max / stars_last_regen (wallet economie)
     Coherent avec Supabase qui mettait ces colonnes sur une table
     user_profiles separee (parce que auth.users est manage par
     Supabase). Cote FastAPI on controle entierement la table users,
     donc pas besoin de duplication.

Pourquoi NE PAS creer une table user_profiles separee ?
  - Pas de service externe qui gere `users` -> on peut ajouter ce
    qu'on veut directement.
  - Un JOIN systematique users <-> user_profiles serait du
    sur-engineering pour zero benefice.
  - Le code Python est plus simple : `current_user.username` plutot
    que `current_user.profile.username`.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# Chainage Alembic : on suit 0003_email.
revision: str = "0004_reset_play_extend_users"
down_revision: Union[str, None] = "0003_email"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---------------------------------------------------------
    # 1. DROP des tables obsoletes
    # ---------------------------------------------------------
    # Ordre important : session_attempts a une FK vers game_sessions
    # (ON DELETE CASCADE), donc on droppe l'enfant en premier pour
    # ne pas dependre du CASCADE.
    op.drop_index(
        "uq_session_attempts_matched_unique",
        table_name="session_attempts",
    )
    op.drop_index(
        "ix_session_attempts_session_time",
        table_name="session_attempts",
    )
    op.drop_table("session_attempts")
    op.drop_index(
        "ix_game_sessions_user_started",
        table_name="game_sessions",
    )
    op.drop_index(
        "ix_game_sessions_leaderboard",
        table_name="game_sessions",
    )
    op.drop_table("game_sessions")

    # ---------------------------------------------------------
    # 2. EXTENSION de la table users
    # ---------------------------------------------------------

    # Username : affichage social (leaderboard, profil). Default
    # "Joueur" pour les users existants sans bloquer.
    op.add_column(
        "users",
        sa.Column(
            "username",
            sa.String(60),
            nullable=False,
            server_default="Joueur",
        ),
    )

    # avatar_id : selecteur d'avatar cote client (clef opaque,
    # ex: "avatar_1", "avatar_lion"). Pas de FK : c'est un asset
    # statique du package Flutter.
    op.add_column(
        "users",
        sa.Column(
            "avatar_id",
            sa.String(40),
            nullable=False,
            server_default="avatar_1",
        ),
    )

    # selected_game_id : jeu actuellement actif pour ce user.
    # NULL tant que l'user n'a pas active de code. SET NULL si le
    # jeu est supprime (ne casse pas l'user, juste son selecteur).
    op.add_column(
        "users",
        sa.Column(
            "selected_game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )

    # ---- Wallet etoiles ----
    # stars : compteur courant (0 a stars_max). Default 10 = 1 vie
    # de depannage pour un nouvel user.
    op.add_column(
        "users",
        sa.Column(
            "stars",
            sa.Integer,
            nullable=False,
            server_default="10",
        ),
    )
    # stars_max : plafond. Default 50 (cf Supabase).
    op.add_column(
        "users",
        sa.Column(
            "stars_max",
            sa.Integer,
            nullable=False,
            server_default="50",
        ),
    )
    # stars_last_regen : timestamp UTC du dernier moment ou la
    # regen a ete appliquee. Initialise a NOW() pour eviter qu'un
    # user existant gagne instantanement 10 etoiles supplementaires.
    op.add_column(
        "users",
        sa.Column(
            "stars_last_regen",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    # CHECK : stars borne entre 0 et stars_max (jamais negatif,
    # jamais au-dessus du plafond). Defense en profondeur en plus
    # de la logique Python.
    op.create_check_constraint(
        "ck_users_stars_range",
        "users",
        "stars >= 0 AND stars <= stars_max",
    )


def downgrade() -> None:
    # 1. Retirer les colonnes users (et le CHECK associe en premier).
    op.drop_constraint("ck_users_stars_range", "users", type_="check")
    op.drop_column("users", "stars_last_regen")
    op.drop_column("users", "stars_max")
    op.drop_column("users", "stars")
    op.drop_column("users", "selected_game_id")
    op.drop_column("users", "avatar_id")
    op.drop_column("users", "username")

    # 2. Re-creer les tables play (au cas ou on veut rollback).
    # Note : si l'on a perdu les donnees on les perd ; pas de
    # sauvegarde car ces tables n'auraient jamais du etre creees.
    op.create_table(
        "game_sessions",
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
        sa.Column(
            "started_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("score", sa.Integer, nullable=False, server_default="0"),
        sa.Column("trios_found", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default="active",
        ),
        sa.CheckConstraint(
            "status IN ('active','finished','abandoned')",
            name="ck_game_sessions_status",
        ),
        sa.CheckConstraint(
            "(status = 'active') = (finished_at IS NULL)",
            name="ck_game_sessions_finished_at_status",
        ),
    )
    op.create_index(
        "ix_game_sessions_leaderboard",
        "game_sessions",
        ["game_id", sa.text("score DESC")],
    )
    op.create_index(
        "ix_game_sessions_user_started",
        "game_sessions",
        ["user_id", sa.text("started_at DESC")],
    )
    op.create_table(
        "session_attempts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "session_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("game_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "card_a_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cards.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "card_b_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cards.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "card_c_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("cards.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "matched_node_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("nodes.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("points_delta", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "attempted_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_session_attempts_session_time",
        "session_attempts",
        ["session_id", "attempted_at"],
    )
    op.create_index(
        "uq_session_attempts_matched_unique",
        "session_attempts",
        ["session_id", "matched_node_id"],
        unique=True,
        postgresql_where=sa.text("matched_node_id IS NOT NULL"),
    )
