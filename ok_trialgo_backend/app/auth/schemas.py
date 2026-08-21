# =============================================================
# FICHIER : app/auth/schemas.py
# ROLE    : Schemas Pydantic pour I/O des routes auth
# =============================================================
#
# Pydantic valide automatiquement le body JSON des requetes ET
# serialise les reponses. Si l'admin envoie un email mal forme,
# FastAPI repond 422 avec un message detaille - on n'ecrit aucun
# code de validation manuel.
# =============================================================

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    id: UUID
    email: EmailStr
    is_admin: bool
    is_active: bool
    # NULL si email pas encore confirme (utile pour le client qui
    # peut afficher une banniere "Confirmez votre email").
    email_confirmed_at: datetime | None = None

    # Pydantic v2 : autorise la conversion depuis attributs SQLAlchemy.
    model_config = {"from_attributes": True}


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshIn(BaseModel):
    refresh_token: str


# -------------------------------------------------------------
# RegisterOut : combine user + tokens pour auto-login.
# Le client n'a pas a re-poster /login juste apres /register.
# -------------------------------------------------------------
class RegisterOut(BaseModel):
    user: UserOut
    tokens: TokenPair


# -------------------------------------------------------------
# Email confirmation
# -------------------------------------------------------------
class ConfirmEmailIn(BaseModel):
    # Token clair recu dans le lien email (?token=...).
    token: str = Field(min_length=20, max_length=128)


class ResendConfirmIn(BaseModel):
    # Email cible : on accepte meme si le user n'est pas connecte
    # (qui a perdu le mail original n'a pas forcement de session
    # active). Anti-enumeration : reponse 200 meme si email inconnu.
    email: EmailStr


# -------------------------------------------------------------
# Password reset (2 phases : demande + confirmation)
# -------------------------------------------------------------
class ForgotPasswordIn(BaseModel):
    email: EmailStr


class ResetPasswordIn(BaseModel):
    token: str = Field(min_length=20, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


# Reponse generique "OK" pour les routes qui ne renvoient pas de
# donnees specifiques (pour eviter d'envoyer du contenu qui pourrait
# servir au scraping / enumeration).
class GenericOk(BaseModel):
    ok: bool = True
