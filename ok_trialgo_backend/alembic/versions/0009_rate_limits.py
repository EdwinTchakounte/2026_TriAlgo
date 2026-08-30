"""rate_limit_buckets : compteurs de limitation de debit

Revision ID: 0009_rate_limits
Revises: 0008_unlocked_and_played
Create Date: 2026-08-29

Table de service pour app/core/rate_limit.py.

POURQUOI EN BASE ET PAS EN MEMOIRE
----------------------------------
La production tourne avec `uvicorn --workers 2` : un compteur en
memoire vaudrait le double de la limite annoncee, et repartirait de
zero a chaque redemarrage — une remise a zero offerte a l'attaquant.

PAS DE MODELE ORM
-----------------
Cette table n'est jamais lue par l'ORM. Le seul acces est un UPSERT
atomique (`ON CONFLICT DO UPDATE ... RETURNING`) qui doit rester en
SQL brut pour que deux workers frappant la meme cle au meme instant
obtiennent deux valeurs distinctes. Un aller-retour SELECT puis
UPDATE via l'ORM introduirait une course.

CLE PRIMAIRE COMPOSITE
----------------------
(bucket_key, window_start) : une ligne par cle et par fenetre. C'est
elle qui rend l'UPSERT possible.

L'index sur window_start sert au menage (purge des fenetres passees
au demarrage) : sans lui, le DELETE ferait un parcours complet.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0009_rate_limits"
down_revision: Union[str, None] = "0008_unlocked_and_played"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "rate_limit_buckets",
        sa.Column("bucket_key", sa.String(200), nullable=False),
        sa.Column("window_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("hits", sa.Integer(), nullable=False, server_default="0"),
        sa.PrimaryKeyConstraint("bucket_key", "window_start", name="pk_rate_limit_buckets"),
    )
    op.create_index(
        "ix_rate_limit_buckets_window",
        "rate_limit_buckets",
        ["window_start"],
    )


def downgrade() -> None:
    op.drop_index("ix_rate_limit_buckets_window", table_name="rate_limit_buckets")
    op.drop_table("rate_limit_buckets")
