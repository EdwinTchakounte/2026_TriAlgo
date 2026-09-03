"""cards.thumb_key : vignette 256 px servie dans la grille de choix

Revision ID: 0010_card_thumbnails
Revises: 0009_rate_limits
Create Date: 2026-09-02

POURQUOI CETTE COLONNE
----------------------
Une question de jeu affiche 8 cartes : 2 en grand, et 6 dans une
grille ou chacune fait environ 150 px de cote. Ces six-la etaient
servies en 1024 px, soit 10 a 20 fois plus d'octets que ce que
l'ecran montre.

Avec des photos reelles (1024 px, q85 : 150 a 300 Ko par carte), une
question coutait 1,5 a 2,5 Mo et le deck complet de 76 cartes 11 a
23 Mo. La vignette ramene la grille a environ un dixieme.

NULLABLE, ET CE N'EST PAS UN OUBLI
----------------------------------
Les cartes creees avant cette migration n'ont pas de vignette. La
colonne doit donc accepter NULL, sinon la migration echouerait sur
toute base contenant deja des cartes -- c'est-a-dire toutes.

Le contrat cote client est explicite : `thumb_url` a NULL signifie
« utilise image_url », pas « erreur ». Une carte ancienne continue
donc de s'afficher, simplement sans le gain de poids.

scripts/generer_vignettes.py comble le retard sur les cartes
existantes, sans re-televerser les originaux : il relit chaque objet
depuis le stockage, en derive la vignette et met la colonne a jour.

PAS DE DOWNGRADE DESTRUCTIF DES FICHIERS
----------------------------------------
Le downgrade retire la colonne mais NE SUPPRIME PAS les vignettes
deja ecrites dans le stockage. Un retour arriere de schema laisse
donc des objets orphelins -- invisibles, inoffensifs, et surtout
recuperables si l'on ré-applique la migration. L'inverse (supprimer
les fichiers) rendrait le retour arriere irreversible.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0010_card_thumbnails"
down_revision: Union[str, None] = "0009_rate_limits"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "cards",
        sa.Column("thumb_key", sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("cards", "thumb_key")
