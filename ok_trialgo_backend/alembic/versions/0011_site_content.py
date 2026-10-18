"""site_content : textes et images de la vitrine, edites depuis le studio

Revision ID: 0011_site_content
Revises: 0010_card_thumbnails
Create Date: 2026-10-18

POURQUOI CETTE TABLE
--------------------
Les textes et les images de mixalgo.com etaient ecrits en dur dans
vitrine/index.html. Changer une phrase demandait de modifier le
fichier, puis de le recopier sur le serveur. Le studio peut desormais
publier un document "accueil" que la vitrine lit au chargement.

UNE LIGNE PAR PAGE, UN DOCUMENT JSONB PAR LIGNE
-----------------------------------------------
Le contenu n'est jamais interroge champ par champ : il est lu et
ecrit d'un bloc. Sa forme est verrouillee par le schema Pydantic de
app/site/schemas.py, a l'ecriture. Ajouter un champ a la page ne
demande donc pas de migration.

AUCUNE LIGNE INSEREE
--------------------
Une table vide est un etat valide : l'API repond alors un document
vide, et la vitrine garde son contenu statique. Pre-remplir ici
dupliquerait le HTML, et les deux copies divergeraient.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0011_site_content"
down_revision: Union[str, None] = "0010_card_thumbnails"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "site_content",
        sa.Column("cle", sa.String(length=64), primary_key=True),
        sa.Column(
            "contenu",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "maj_le",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "maj_par",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )


def downgrade() -> None:
    # Les images televersees (site/*.jpg) ne sont PAS supprimees du
    # stockage : meme regle que 0010, un retour arriere de schema ne
    # doit pas detruire de fichiers.
    op.drop_table("site_content")
