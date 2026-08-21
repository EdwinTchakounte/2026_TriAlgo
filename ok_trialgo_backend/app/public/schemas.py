# =============================================================
# FICHIER : app/public/schemas.py
# ROLE    : DTOs PUBLICS pour l'app joueur (sans champs sensibles)
# =============================================================
#
# Difference cruciale avec games/cards/schemas :
#   - PublicCardOut N'EXPOSE PAS card_type (emettrice/cable/
#     receptrice) : sinon le joueur connait deja le role de
#     chaque carte et peut deviner les fusions plus facilement.
#   - PublicGameOut n'expose ni is_active (toujours true pour le
#     public) ni created_at (info admin).
# =============================================================

from uuid import UUID

from pydantic import BaseModel


class PublicGameOut(BaseModel):
    id: UUID
    name: str
    description: str | None
    theme: str | None
    cover_image: str | None


class PublicCardOut(BaseModel):
    id: UUID
    game_id: UUID
    label: str
    # URL signee/publique selon backend storage.
    image_url: str | None = None
    # Volontairement absent : card_type, object_key, created_at.
