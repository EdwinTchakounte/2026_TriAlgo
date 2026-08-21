# =============================================================
# FICHIER : app/auth/routes.py
# ROLE    : Endpoints d'authentification (register, login, refresh,
#           confirm-email, resend-confirmation, forgot/reset password)
# =============================================================
#
# Endpoints exposes :
#   POST /api/auth/register              cree un compte (1er = admin),
#                                         envoie un mail welcome+confirm,
#                                         renvoie (user, tokens) -> auto-login
#   POST /api/auth/login                 retourne (access, refresh)
#   POST /api/auth/refresh               rafraichit l'access depuis le refresh
#   GET  /api/auth/me                    renvoie le profil authentifie
#   POST /api/auth/confirm-email         consomme un token de confirmation
#   POST /api/auth/resend-confirmation   renvoie un nouveau mail
#   POST /api/auth/forgot-password       declenche envoi mail reset
#   POST /api/auth/reset-password        consomme un token + change mdp
#
# Anti-enumeration : forgot/resend renvoient TOUJOURS 200, qu'on
# trouve ou pas le user. Sinon un attaquant pourrait deviner les
# emails enregistres par diff de reponse.
# =============================================================

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from jose import JWTError
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from ..mail.models import (
    EMAIL_PURPOSE_CONFIRM,
    EMAIL_PURPOSE_RESET,
    EmailPreferences,
)
from ..mail.sender import (
    send_password_changed,
    send_password_reset,
    send_welcome_confirm,
    send_welcome_confirmed,
)
from ..mail.tokens import generate_email_token, verify_and_consume
from .deps import get_current_user
from .jwt import create_access_token, create_refresh_token, decode_token
from .models import User
from .schemas import (
    ConfirmEmailIn,
    ForgotPasswordIn,
    GenericOk,
    RefreshIn,
    RegisterOut,
    ResendConfirmIn,
    ResetPasswordIn,
    TokenPair,
    UserCreate,
    UserLogin,
    UserOut,
)
from .security import hash_password, verify_password

router = APIRouter()


# -------------------------------------------------------------
# REGISTER : creer compte + welcome mail + auto-login
# -------------------------------------------------------------
@router.post(
    "/register",
    response_model=RegisterOut,
    status_code=201,
    summary="Inscription d'un nouveau compte (1er = admin bootstrap)",
    description=(
        "Cree un compte utilisateur. Le PREMIER compte cree dans la DB "
        "est automatiquement promu admin (bootstrap). Les comptes "
        "suivants sont des joueurs sans droits.\n\n"
        "Side-effects : envoi mail welcome+confirm en BackgroundTasks. "
        "Auto-login : la reponse inclut un TokenPair pour eviter au "
        "client de re-poster /login immediatement."
    ),
)
async def register(
    body: UserCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    background: BackgroundTasks,
) -> RegisterOut:
    # 1. Unicite email (eviter exception SQL).
    existing = await db.scalar(select(User).where(User.email == body.email))
    if existing:
        raise HTTPException(409, "Email deja utilise")

    # 2. Bootstrap : 1er user devient admin automatiquement.
    count = await db.scalar(select(func.count(User.id)))
    is_admin = count == 0

    # 3. Creation User + ligne de preferences email (defauts).
    user = User(
        email=body.email,
        password_hash=hash_password(body.password),
        is_admin=is_admin,
    )
    db.add(user)
    await db.flush()  # flush pour avoir user.id avant le token email
    # Ligne EmailPreferences avec defauts (marketing off, autres on).
    db.add(EmailPreferences(user_id=user.id))
    # 4. Generation du token de confirmation email.
    token_clear = await generate_email_token(
        db, user.id, EMAIL_PURPOSE_CONFIRM
    )
    await db.commit()
    await db.refresh(user)

    # 5. Envoi du mail welcome+confirm en background (non bloquant).
    # Si Brevo down ou cle absente : log dans send (DRY_RUN), le
    # register reussit quand meme.
    background.add_task(
        send_welcome_confirm,
        to_email=user.email,
        to_name=None,
        confirm_token=token_clear,
    )

    # 6. Auto-login : renvoie le user + paire de tokens.
    return RegisterOut(
        user=UserOut.model_validate(user),
        tokens=TokenPair(
            access_token=create_access_token(user.id, user.is_admin),
            refresh_token=create_refresh_token(user.id),
        ),
    )


# -------------------------------------------------------------
# LOGIN
# -------------------------------------------------------------
@router.post(
    "/login",
    response_model=TokenPair,
    summary="Connexion par email/mot de passe (user)",
    description=(
        "Authentifie un utilisateur via email + mot de passe et renvoie "
        "un couple access/refresh JWT. Le message d'erreur est "
        "volontairement vague (anti-enumeration : on ne distingue pas "
        "email inconnu vs mauvais mot de passe). Erreurs : 401 si "
        "credentials invalides, 403 si compte desactive."
    ),
)
async def login(
    body: UserLogin,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TokenPair:
    user = await db.scalar(select(User).where(User.email == body.email))
    # Message volontairement vague (anti-enumeration).
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(401, "Email ou mot de passe invalide")
    if not user.is_active:
        raise HTTPException(403, "Compte desactive")
    return TokenPair(
        access_token=create_access_token(user.id, user.is_admin),
        refresh_token=create_refresh_token(user.id),
    )


# -------------------------------------------------------------
# REFRESH
# -------------------------------------------------------------
@router.post(
    "/refresh",
    response_model=TokenPair,
    summary="Rafraichit l'access token depuis un refresh token (user)",
    description=(
        "Echange un refresh token valide contre une nouvelle paire "
        "(access + refresh). Verifie le type du token (refresh), "
        "l'existence de l'utilisateur et son etat actif. Erreurs : "
        "401 si refresh invalide, expire, mauvais type ou user "
        "introuvable/desactive."
    ),
)
async def refresh(
    body: RefreshIn,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> TokenPair:
    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(401, "Token de mauvais type")
        user_id = UUID(payload["sub"])
    except (JWTError, KeyError, ValueError) as e:
        raise HTTPException(401, "Refresh token invalide") from e

    user = await db.scalar(select(User).where(User.id == user_id))
    if not user or not user.is_active:
        raise HTTPException(401, "Utilisateur introuvable ou desactive")

    return TokenPair(
        access_token=create_access_token(user.id, user.is_admin),
        refresh_token=create_refresh_token(user.id),
    )


# -------------------------------------------------------------
# ME
# -------------------------------------------------------------
@router.get(
    "/me",
    response_model=UserOut,
    summary="Recupere le profil de l'utilisateur authentifie (user)",
    description=(
        "Renvoie le profil complet (UserOut) du user identifie par "
        "le bearer token. Endpoint pratique pour le client mobile/web "
        "qui veut afficher l'identite courante. Necessite un access "
        "token valide ; 401 sinon."
    ),
)
async def me(user: Annotated[User, Depends(get_current_user)]) -> User:
    return user


# -------------------------------------------------------------
# CONFIRM EMAIL : consomme un token recu par mail
# -------------------------------------------------------------
@router.post(
    "/confirm-email",
    response_model=GenericOk,
    summary="Confirme l'email via un token recu par mail (no auth)",
    description=(
        "Consomme le token de confirmation transmis dans le mail "
        "welcome+confirm. Idempotent : si l'email est deja confirme, "
        "on n'ecrase pas la date initiale. Side-effect : envoie un mail "
        "'compte verifie' uniquement a la PREMIERE confirmation. "
        "Erreur 400 si token invalide ou expire."
    ),
)
async def confirm_email(
    body: ConfirmEmailIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    background: BackgroundTasks,
) -> GenericOk:
    user_id = await verify_and_consume(db, body.token, EMAIL_PURPOSE_CONFIRM)
    if user_id is None:
        # On renvoie 400 (et pas 404) car le client a soumis qqch.
        raise HTTPException(400, "Token de confirmation invalide ou expire")

    user = await db.get(User, user_id)
    if not user:
        # Edge case : user supprime entre la generation et la conso.
        raise HTTPException(400, "Utilisateur introuvable")
    # Idempotent : si deja confirme on n'ecrase pas la date initiale.
    if user.email_confirmed_at is None:
        user.email_confirmed_at = datetime.now(timezone.utc)
        await db.commit()
        # Envoie le mail "compte verifie" en background uniquement
        # a la 1ere confirmation (eviter spam si lien rejoue).
        background.add_task(
            send_welcome_confirmed,
            to_email=user.email,
            to_name=None,
        )
    else:
        await db.commit()
    return GenericOk()


# -------------------------------------------------------------
# RESEND CONFIRMATION
# -------------------------------------------------------------
@router.post(
    "/resend-confirmation",
    response_model=GenericOk,
    summary="Renvoie un mail de confirmation d'email (no auth)",
    description=(
        "Regenere un token de confirmation et renvoie le mail "
        "welcome+confirm si l'utilisateur existe, est actif et non "
        "encore confirme. Anti-enumeration : la reponse est TOUJOURS "
        "200 OK meme si l'email est inconnu ou deja confirme, pour ne "
        "pas leaker la liste des comptes."
    ),
)
async def resend_confirmation(
    body: ResendConfirmIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    background: BackgroundTasks,
) -> GenericOk:
    user = await db.scalar(select(User).where(User.email == body.email))
    # Anti-enumeration : 200 meme si user inconnu ou deja confirme.
    if user and user.email_confirmed_at is None and user.is_active:
        token_clear = await generate_email_token(
            db, user.id, EMAIL_PURPOSE_CONFIRM
        )
        await db.commit()
        background.add_task(
            send_welcome_confirm,
            to_email=user.email,
            to_name=None,
            confirm_token=token_clear,
        )
    return GenericOk()


# -------------------------------------------------------------
# FORGOT PASSWORD : declenche l'envoi d'un mail reset
# -------------------------------------------------------------
@router.post(
    "/forgot-password",
    response_model=GenericOk,
    summary="Declenche l'envoi d'un mail de reinitialisation (no auth)",
    description=(
        "Genere un token de reset et envoie en background le mail "
        "contenant le lien de reinitialisation, si l'utilisateur "
        "existe et est actif. Anti-enumeration : la reponse est "
        "TOUJOURS 200 OK quel que soit le cas (email inconnu inclus) "
        "pour eviter le scraping des emails enregistres."
    ),
)
async def forgot_password(
    body: ForgotPasswordIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    background: BackgroundTasks,
) -> GenericOk:
    user = await db.scalar(select(User).where(User.email == body.email))
    # Anti-enumeration : 200 toujours.
    if user and user.is_active:
        token_clear = await generate_email_token(
            db, user.id, EMAIL_PURPOSE_RESET
        )
        await db.commit()
        background.add_task(
            send_password_reset,
            to_email=user.email,
            reset_token=token_clear,
        )
    return GenericOk()


# -------------------------------------------------------------
# RESET PASSWORD : consomme un token + change mot de passe
# -------------------------------------------------------------
@router.post(
    "/reset-password",
    response_model=GenericOk,
    summary="Consomme un token de reset et change le mot de passe (no auth)",
    description=(
        "Valide le token de reset (verify_and_consume) puis remplace "
        "le hash du mot de passe par celui du nouveau. Side-effect : "
        "envoie en background un mail 'mot de passe change' a "
        "l'adresse du user (notification de securite). Erreurs : "
        "400 si token invalide/expire ou user introuvable/desactive."
    ),
)
async def reset_password(
    body: ResetPasswordIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    background: BackgroundTasks,
) -> GenericOk:
    user_id = await verify_and_consume(db, body.token, EMAIL_PURPOSE_RESET)
    if user_id is None:
        raise HTTPException(400, "Token de reset invalide ou expire")

    user = await db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(400, "Utilisateur introuvable ou desactive")

    user.password_hash = hash_password(body.new_password)
    changed_at = datetime.now(timezone.utc)
    await db.commit()

    # Notif securite : on previent toujours quand le mdp change.
    background.add_task(
        send_password_changed,
        to_email=user.email,
        changed_at=changed_at,
    )
    return GenericOk()
