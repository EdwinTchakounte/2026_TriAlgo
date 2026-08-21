"""activation_codes : licences par jeu + binding device

Revision ID: 0005_activation_codes
Revises: 0004_reset_play_extend_users
Create Date: 2026-06-04

Porte la logique Supabase de la migration 001 sur activation_codes :
  - Chaque code = UN jeu (un code ne marche que sur son jeu)
  - Chaque code peut etre assigne a UN seul user au max
  - Une fois assigne, le code est lie a UN device
  - Le user peut changer de device max 3 fois (compteur incremente)
  - Apres 3 changements : code bloque definitivement
  - Un admin peut desactiver un code manuellement (is_active=false)
  - Un user ne peut avoir qu'UN code par jeu (UNIQUE assigned_to,game_id)

La logique d'activation (avec gestion des 4 cas : first activation,
re-activation meme device, change device, blocage) sera dans
l'endpoint POST /api/codes/activate (module codes/) au lieu d'un RPC SQL.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005_activation_codes"
down_revision: Union[str, None] = "0004_reset_play_extend_users"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "activation_codes",
        # PK = code clair (alphanumeric, ex: "X123" ou "TRIALGO-ABCD-1234").
        # On utilise le code comme PK pour eviter une couche UUID
        # inutile : le code EST l'identifiant naturel cote business.
        sa.Column("code", sa.String(64), primary_key=True),
        # Jeu associe. CASCADE : si le jeu disparait, ses codes aussi.
        sa.Column(
            "game_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("games.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # User assigne. NULL tant que pas active. SET NULL si user
        # supprime (le code redevient disponible -- decision admin
        # de le re-attribuer ou bloquer).
        sa.Column(
            "assigned_to",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        # Device actuellement lie. String opaque (Android ID, iOS ID,
        # ou empreinte composite). NULL si jamais active.
        sa.Column("device_id", sa.String(200), nullable=True),
        # Compteur de changements de device.
        sa.Column(
            "device_changes_count",
            sa.Integer,
            nullable=False,
            server_default="0",
        ),
        # Limite (defaut 3). Override possible par code pour
        # cas particulier (ex: code de demo a 10 changements).
        sa.Column(
            "max_device_changes",
            sa.Integer,
            nullable=False,
            server_default="3",
        ),
        # Flag blocage definitif (apres max atteint).
        sa.Column(
            "is_blocked",
            sa.Boolean,
            nullable=False,
            server_default=sa.false(),
        ),
        # Flag desactivation admin (revocation manuelle).
        sa.Column(
            "is_active",
            sa.Boolean,
            nullable=False,
            server_default=sa.true(),
        ),
        # Timestamp de premiere activation (NULL avant).
        sa.Column(
            "activated_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        # Un user ne peut avoir qu'UN code par jeu (pas de double
        # vie via 2 codes pour le meme jeu).
        sa.UniqueConstraint(
            "assigned_to", "game_id",
            name="uq_activation_codes_user_game",
        ),
    )

    # Index pour lookup rapide "donne-moi le code de tel user".
    op.create_index(
        "ix_activation_codes_assigned_to",
        "activation_codes",
        ["assigned_to"],
    )
    # Index pour audit "combien de codes sur tel device".
    op.create_index(
        "ix_activation_codes_device",
        "activation_codes",
        ["device_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_activation_codes_device",
        table_name="activation_codes",
    )
    op.drop_index(
        "ix_activation_codes_assigned_to",
        table_name="activation_codes",
    )
    op.drop_table("activation_codes")
