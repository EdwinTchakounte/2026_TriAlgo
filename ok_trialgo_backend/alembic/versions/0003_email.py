"""email schema : email_tokens + email_preferences + users.email_confirmed_at

Revision ID: 0003_email
Revises: 0002_play
Create Date: 2026-06-04

Ajoute le support des emails transactionnels :
  - users.email_confirmed_at  : null tant que le user n'a pas
                                clique sur le lien de confirmation
  - email_tokens              : tokens TTL pour confirm/reset
  - email_preferences         : opt-in/out par categorie

On stocke le HASH du token, pas le token clair (defense en
profondeur : un dump DB ne permet pas d'usurper les confirms).
Le token clair n'est connu que par l'envoi mail initial.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# Chainage Alembic : on suit 0002_play.
revision: str = "0003_email"
down_revision: Union[str, None] = "0002_play"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ---------------------------------------------------------
    # users : ajout email_confirmed_at
    # ---------------------------------------------------------
    # Nullable car les comptes existants n'ont pas encore
    # confirme. Les routes auth peuvent traiter NULL = pas
    # confirme ; on definira la policy (block login ? warning ?)
    # dans la refonte du module auth.
    op.add_column(
        "users",
        sa.Column(
            "email_confirmed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    # ---------------------------------------------------------
    # email_tokens : tokens TTL pour confirm + reset
    # ---------------------------------------------------------
    op.create_table(
        "email_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        # purpose : differencie le type d'usage. CHECK contraint
        # pour eviter qu'on cree un token de confirm pour reset
        # par accident.
        sa.Column("purpose", sa.String(40), nullable=False),
        # token_hash : SHA-256 hex (64 chars) du token clair.
        # On compare hash(received) au hash stocke -> verification
        # constant-time via hmac.compare_digest cote app.
        sa.Column("token_hash", sa.String(128), nullable=False),
        # expires_at : TTL absolu. Past expires_at -> rejet.
        sa.Column(
            "expires_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        # used_at : marqueur "single-use". Une fois set, un token
        # ne peut plus etre re-consomme (replay protection).
        sa.Column(
            "used_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "purpose IN ('email_confirm','password_reset')",
            name="ck_email_tokens_purpose",
        ),
    )
    # Index pour lookup rapide par hash (verifier un token recu).
    op.create_index(
        "ix_email_tokens_hash",
        "email_tokens",
        ["token_hash"],
        unique=True,
    )
    # Index pour nettoyage perio des tokens expires.
    op.create_index(
        "ix_email_tokens_expires",
        "email_tokens",
        ["expires_at"],
    )

    # ---------------------------------------------------------
    # email_preferences : opt-in/out par categorie
    # ---------------------------------------------------------
    # Lignes creees a l'inscription avec defauts ; un user peut
    # tout desactiver sauf les emails TRANSACTIONNELS (welcome,
    # confirm, reset, password_changed, account_deactivated) qui
    # sont obligatoires legalement / securite.
    op.create_table(
        "email_preferences",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        # Marketing : annonces produit, newsletter.
        sa.Column(
            "marketing",
            sa.Boolean,
            nullable=False,
            server_default=sa.false(),
        ),
        # Resume de fin de session (peut etre verbeux, opt-in).
        sa.Column(
            "session_summary",
            sa.Boolean,
            nullable=False,
            server_default=sa.true(),
        ),
        # Notification quand un nouveau jeu est publie.
        sa.Column(
            "new_game",
            sa.Boolean,
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("email_preferences")
    op.drop_index("ix_email_tokens_expires", table_name="email_tokens")
    op.drop_index("ix_email_tokens_hash", table_name="email_tokens")
    op.drop_table("email_tokens")
    op.drop_column("users", "email_confirmed_at")
