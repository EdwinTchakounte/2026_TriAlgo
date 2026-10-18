# =============================================================
# FICHIER : app/site/models.py
# ROLE    : Modele SQLAlchemy SiteContent (contenu de la vitrine)
# =============================================================
#
# POURQUOI UNE TABLE CLE -> DOCUMENT JSON
# ---------------------------------------
# La vitrine n'a qu'une page aujourd'hui, l'accueil. Ses textes et
# ses images forment UN document, qu'on edite et qu'on publie d'un
# bloc depuis le studio. Le decouper en colonnes (hero_titre,
# hero_accroche, ...) obligerait a une migration a chaque nouveau
# champ de la page, pour un contenu qui n'est jamais interroge
# champ par champ.
#
# La forme du document n'est pas libre pour autant : elle est
# verrouillee par le schema Pydantic (schemas.py), a l'ecriture.
# La base stocke, l'API garantit.
#
# La cle (`cle`) prepare le jour ou une deuxieme page existera :
# une ligne de plus, aucune migration.
# =============================================================

from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class SiteContent(Base):
    __tablename__ = "site_content"

    # Identifiant de la page : 'accueil' pour l'instant.
    cle: Mapped[str] = mapped_column(String(64), primary_key=True)

    # Le document complet, deja valide par l'API avant ecriture.
    contenu: Mapped[dict[str, Any]] = mapped_column(
        JSONB, nullable=False, server_default="{}"
    )

    # Date de derniere publication : la vitrine ne s'en sert pas,
    # le studio l'affiche ("publie il y a ...").
    maj_le: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Qui a publie. SET NULL : supprimer un compte ne doit pas
    # emporter le contenu du site avec lui.
    maj_par: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
