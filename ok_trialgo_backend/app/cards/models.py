# =============================================================
# FICHIER : app/cards/models.py
# ROLE    : Modele SQLAlchemy Card
# =============================================================
#
# Note importante : on stocke `object_key` (chemin opaque dans le
# storage) plutot que l'URL finale. Pourquoi :
#   - Si on change de backend storage (local -> S3), l'URL change
#     mais object_key reste valide.
#   - L'URL signee (presigned) est calculee a la demande.
# =============================================================

import uuid
from datetime import datetime
from enum import Enum

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class CardType(str, Enum):
    EMETTRICE = "emettrice"
    CABLE = "cable"
    RECEPTRICE = "receptrice"


class Card(Base):
    __tablename__ = "cards"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    game_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("games.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label: Mapped[str] = mapped_column(String(120), nullable=False)
    object_key: Mapped[str] = mapped_column(String(500), nullable=False)
    # Cle de la vignette (256 px), servie dans la grille de choix du
    # jeu. NULLABLE a dessein : les cartes creees avant l'ajout des
    # vignettes n'en ont pas, et il ne faut pas qu'elles cessent de
    # s'afficher. Le client retombe alors sur `object_key`.
    # scripts/generer_vignettes.py comble le retard.
    thumb_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    content_type: Mapped[str] = mapped_column(String(60), nullable=False, default="image/jpeg")
    card_type: Mapped[CardType] = mapped_column(String(20), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
