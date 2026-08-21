# =============================================================
# FICHIER : app/auth/models.py
# ROLE    : Modele SQLAlchemy User (compte admin)
# =============================================================
#
# Schema minimal pour faire tourner l'auth :
#   - id          UUID (clef primaire portable)
#   - email       unique, indexé (lookup login)
#   - password_hash  bcrypt (jamais en clair)
#   - is_admin    boolean (gate les routes write)
#   - is_active   boolean (desactiver sans supprimer)
#   - created_at  timestamp
#
# On garde un seul role pour demarrer : "admin". Les joueurs
# (sans is_admin) ne peuvent rien ecrire ; ils consulteront le
# jeu en lecture seule. Pour des roles plus fins, ajouter une
# table roles ou un champ "role: Enum" plus tard.
# =============================================================

import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from ..db import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        # Wallet etoiles : entre 0 et stars_max (jamais negatif,
        # jamais au-dessus du plafond). Defense en profondeur.
        CheckConstraint(
            "stars >= 0 AND stars <= stars_max",
            name="ck_users_stars_range",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    email: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    # bcrypt hash (60 chars), jamais le mot de passe en clair.
    password_hash: Mapped[str] = mapped_column(String(60), nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    # Date de confirmation de l'email. NULL = pas encore confirme.
    email_confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # ---- Profil (porte depuis Supabase user_profiles) ----
    # Affichage social : leaderboard, profil.
    username: Mapped[str] = mapped_column(
        String(60), nullable=False, default="Joueur"
    )
    # Selecteur d'avatar (asset statique cote Flutter, clef opaque).
    avatar_id: Mapped[str] = mapped_column(
        String(40), nullable=False, default="avatar_1"
    )
    # Jeu actuellement actif (NULL tant que pas de code active).
    # SET NULL si le jeu est supprime (ne casse pas l'user).
    selected_game_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("games.id", ondelete="SET NULL"),
        nullable=True,
    )
    # ---- Wallet etoiles ----
    # Compteur courant.
    stars: Mapped[int] = mapped_column(
        Integer, nullable=False, default=10
    )
    # Plafond.
    stars_max: Mapped[int] = mapped_column(
        Integer, nullable=False, default=50
    )
    # Timestamp UTC du dernier moment ou la regen a ete appliquee.
    # Sert au calcul : delta = floor((now - stars_last_regen) / 5min).
    stars_last_regen: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
