"""play schema : game_sessions + session_attempts

Revision ID: 0002_play
Revises: 0001_initial
Create Date: 2026-06-04

Ajoute les tables necessaires au mode joueur :

  - game_sessions     une partie jouee par un user sur un game
  - session_attempts  log de chaque tentative de fusion (3 cartes)

Le score / progression sont denormalises dans game_sessions pour
permettre un leaderboard rapide sans JOIN sur attempts.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# Identifiants Alembic : down_revision pointe sur l'init pour chainer.
revision: str = "0002_play"
down_revision: Union[str, None] = "0001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---------------------------------------------------------
    # GAME_SESSIONS
    # ---------------------------------------------------------
    # Une session = une partie. Un user peut avoir plusieurs
    # sessions sur le meme game (re-tenter pour ameliorer son
    # score). status track l'etat de vie : active / finished /
    # abandoned. finished_at est NULL tant que pas termine.
    op.create_table(
        "game_sessions",
        # PK UUID generee cote app (uuid4) pour rester aligne sur
        # le reste du schema.
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        # FK user : si user supprime, on garde les sessions ? Non,
        # CASCADE car les sessions n'ont aucun sens sans owner et
        # les stats agregees seraient fausses.
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # FK game : si le jeu est supprime, ses sessions partent
        # aussi (sinon orphelines).
        sa.Column(
            "game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # Timestamps : started_at par defaut now() au commit
        # serveur. finished_at NULL puis date precise au finish.
        sa.Column(
            "started_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "finished_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        # Score courant (peut etre negatif logiquement si on
        # comptait des malus ; on clampe a 0 cote app mais
        # pas de check pour ne pas bloquer un futur design).
        sa.Column(
            "score",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Nombre de trios decouverts (denormalise pour ne pas
        # faire un COUNT(*) sur attempts a chaque GET).
        sa.Column(
            "trios_found",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Status : machine a etats.
        #   active    : partie en cours, attempts acceptees
        #   finished  : terminee proprement, score fige
        #   abandoned : abandonnee (timeout / fermeture app)
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default="active",
        ),
        # CHECK status pour garantir qu'on ne stocke jamais une
        # valeur invalide (defense en profondeur en plus du Pydantic).
        sa.CheckConstraint(
            "status IN ('active','finished','abandoned')",
            name="ck_game_sessions_status",
        ),
        # CHECK coherence finished_at / status : si finished, doit
        # avoir une date ; si active, ne doit PAS en avoir.
        sa.CheckConstraint(
            "(status = 'active') = (finished_at IS NULL)",
            name="ck_game_sessions_finished_at_status",
        ),
    )
    # Index leaderboard : pour GET /api/games/{gid}/leaderboard
    # on tri par score DESC sur un game donne -> index composite.
    op.create_index(
        "ix_game_sessions_leaderboard",
        "game_sessions",
        ["game_id", sa.text("score DESC")],
    )
    # Index historique perso : pour GET /api/users/me/sessions on
    # liste les sessions d'un user tri chronologique inverse.
    op.create_index(
        "ix_game_sessions_user_started",
        "game_sessions",
        ["user_id", sa.text("started_at DESC")],
    )

    # ---------------------------------------------------------
    # SESSION_ATTEMPTS
    # ---------------------------------------------------------
    # Une ligne = une soumission de 3 cartes par le joueur.
    # matched_node_id NULL = tentative ratee.
    # On garde TOUT l'historique meme apres finish pour
    # anti-triche, replay, et stats avancees.
    op.create_table(
        "session_attempts",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        # FK session : CASCADE car les attempts n'ont aucun sens
        # sans la session parent.
        sa.Column(
            "session_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("game_sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # Les 3 cartes soumises. Pas de CASCADE sur cards : si un
        # admin supprime une carte, on prefere garder l'historique
        # avec FK qui pointe encore (ou on met SET NULL si on veut
        # garder la trace). On choisit SET NULL pour ne pas perdre
        # la session du joueur a cause d'une action admin.
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
        # Node matche (NULL = echec). SET NULL pour la meme raison.
        sa.Column(
            "matched_node_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("nodes.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # Points reellement attribues a cette tentative (peut etre
        # 0 si trio deja decouvert, ou negatif si on stocke le
        # malus -5 separement -- ici on stockera juste le delta).
        sa.Column(
            "points_delta",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Timestamp pour ordre + rate-limiting.
        sa.Column(
            "attempted_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    # Index pour timeline d'une session : GET /progress, anti-spam.
    op.create_index(
        "ix_session_attempts_session_time",
        "session_attempts",
        ["session_id", "attempted_at"],
    )
    # UNIQUE PARTIAL : un meme node ne peut etre matche qu'une
    # seule fois par session (evite double-comptage si le joueur
    # re-soumet le meme trio). Postgres-only via WHERE clause.
    op.create_index(
        "uq_session_attempts_matched_unique",
        "session_attempts",
        ["session_id", "matched_node_id"],
        unique=True,
        postgresql_where=sa.text("matched_node_id IS NOT NULL"),
    )


def downgrade() -> None:
    # Ordre inverse de creation : on droppe les index implicitement
    # via drop_table, mais on est explicite pour les composites.
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
