# =============================================================
# FICHIER : app/mail/sender.py
# ROLE    : Couche haute : render template + envoi via Brevo
# =============================================================
#
# Une fonction par cas d'usage (lisible, type-safe). Chaque
# fonction :
#   1. Charge le template Jinja2 correspondant.
#   2. Render avec les vars.
#   3. Envoie via BrevoClient.
#   4. Renvoie SendResult (pour log/retry).
#
# Volontairement decouple de l'auth/play : on prend des params
# primitifs (email, name, urls...) et on assemble. Pas d'acces DB.
# =============================================================

from datetime import datetime
from pathlib import Path
from typing import Optional

from jinja2 import Environment, FileSystemLoader, select_autoescape

from ..config import settings
from .client import SendResult, get_brevo_client

# Setup Jinja2 : loader sur le dossier templates/ adjacent.
# autoescape pour HTML uniquement (les templates txt brut ne
# subiraient pas l'escape -- ici on n'envoie que du HTML).
_TEMPLATE_DIR = Path(__file__).parent / "templates"
_env = Environment(
    loader=FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=select_autoescape(["html"]),
    trim_blocks=True,
    lstrip_blocks=True,
)


def _render(template_name: str, **context) -> str:
    """Render un template Jinja2 avec le contexte donne."""
    template = _env.get_template(template_name)
    return template.render(**context)


# -------------------------------------------------------------
# 1. WELCOME + CONFIRM (a l'inscription, single mail)
# -------------------------------------------------------------
async def send_welcome_confirm(
    *,
    to_email: str,
    to_name: Optional[str],
    confirm_token: str,
) -> SendResult:
    # Lien de confirmation construit cote serveur pour rester
    # source de verite (le front se contente d'ouvrir l'URL).
    confirm_url = (
        f"{settings.APP_FRONTEND_URL.rstrip('/')}/confirm-email?token={confirm_token}"
    )
    html = _render(
        "welcome_confirm.html",
        subject="Bienvenue sur TRIALGO - Confirmez votre email",
        name=to_name,
        confirm_url=confirm_url,
        ttl_hours=settings.EMAIL_TOKEN_TTL_CONFIRM_MINUTES // 60,
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=to_name,
        subject="Bienvenue sur TRIALGO - Confirmez votre email",
        html=html,
    )


# -------------------------------------------------------------
# 2. WELCOME (apres confirmation email)
# -------------------------------------------------------------
async def send_welcome_confirmed(
    *,
    to_email: str,
    to_name: Optional[str],
) -> SendResult:
    html = _render(
        "welcome.html",
        subject="Votre compte TRIALGO est verifie",
        name=to_name,
        app_url=settings.APP_FRONTEND_URL,
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=to_name,
        subject="Votre compte TRIALGO est verifie",
        html=html,
    )


# -------------------------------------------------------------
# 3. PASSWORD RESET
# -------------------------------------------------------------
async def send_password_reset(
    *,
    to_email: str,
    reset_token: str,
) -> SendResult:
    reset_url = (
        f"{settings.APP_FRONTEND_URL.rstrip('/')}/reset-password?token={reset_token}"
    )
    html = _render(
        "password_reset.html",
        subject="Reinitialisation de votre mot de passe TRIALGO",
        reset_url=reset_url,
        ttl_minutes=settings.EMAIL_TOKEN_TTL_RESET_MINUTES,
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=None,
        subject="Reinitialisation de votre mot de passe TRIALGO",
        html=html,
    )


# -------------------------------------------------------------
# 4. PASSWORD CHANGED (notif securite post-reset)
# -------------------------------------------------------------
async def send_password_changed(
    *,
    to_email: str,
    changed_at: datetime,
) -> SendResult:
    html = _render(
        "password_changed.html",
        subject="Votre mot de passe TRIALGO a ete modifie",
        changed_at=changed_at.strftime("%d/%m/%Y a %H:%M UTC"),
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=None,
        subject="Votre mot de passe TRIALGO a ete modifie",
        html=html,
    )


# -------------------------------------------------------------
# 5. SESSION SUMMARY (opt-in)
# -------------------------------------------------------------
async def send_session_summary(
    *,
    to_email: str,
    to_name: Optional[str],
    game_name: str,
    score: int,
    trios_found: int,
    total_trios: int,
    completion_bonus: bool,
) -> SendResult:
    leaderboard_url = settings.APP_FRONTEND_URL.rstrip("/") + "/leaderboard"
    html = _render(
        "session_summary.html",
        subject=f"Bilan de votre partie : {game_name}",
        game_name=game_name,
        score=score,
        trios_found=trios_found,
        total_trios=total_trios,
        completion_bonus=completion_bonus,
        leaderboard_url=leaderboard_url,
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=to_name,
        subject=f"Bilan de votre partie : {game_name}",
        html=html,
    )


# -------------------------------------------------------------
# 6. NEW GAME (opt-in)
# -------------------------------------------------------------
async def send_new_game(
    *,
    to_email: str,
    to_name: Optional[str],
    game_name: str,
    game_description: Optional[str],
    game_id: str,
) -> SendResult:
    game_url = f"{settings.APP_FRONTEND_URL.rstrip('/')}/games/{game_id}"
    html = _render(
        "new_game.html",
        subject=f"Nouveau jeu sur TRIALGO : {game_name}",
        game_name=game_name,
        game_description=game_description,
        game_url=game_url,
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=to_name,
        subject=f"Nouveau jeu sur TRIALGO : {game_name}",
        html=html,
    )


# -------------------------------------------------------------
# 7. ADMIN PROMOTED
# -------------------------------------------------------------
async def send_admin_promoted(
    *,
    to_email: str,
    to_name: Optional[str],
) -> SendResult:
    admin_url = settings.APP_FRONTEND_URL.rstrip("/") + "/admin"
    html = _render(
        "admin_promoted.html",
        subject="Vous etes maintenant administrateur TRIALGO",
        admin_url=admin_url,
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=to_name,
        subject="Vous etes maintenant administrateur TRIALGO",
        html=html,
    )


# -------------------------------------------------------------
# 8. CODE ACTIVATED (1ere activation reussie)
# -------------------------------------------------------------
async def send_code_activated(
    *,
    to_email: str,
    to_name: Optional[str],
    game_name: str,
    code: str,
    changes_left: Optional[int],
) -> SendResult:
    """Envoye lors de la premiere activation reussie d'un code.

    On notifie l'user que son device est bind, lui rappelle le quota
    de changements restants (anti-perte de telephone), et l'invite a
    commencer la partie.
    """
    html = _render(
        "code_activated.html",
        subject=f"Votre code est active : {game_name}",
        name=to_name,
        game_name=game_name,
        code=code,
        changes_left=changes_left,
        app_url=settings.APP_FRONTEND_URL,
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=to_name,
        subject=f"Votre code est active : {game_name}",
        html=html,
    )


# -------------------------------------------------------------
# 9. ACCOUNT DEACTIVATED
# -------------------------------------------------------------
async def send_account_deactivated(
    *,
    to_email: str,
    deactivated_at: datetime,
) -> SendResult:
    html = _render(
        "account_deactivated.html",
        subject="Votre compte TRIALGO a ete desactive",
        deactivated_at=deactivated_at.strftime("%d/%m/%Y a %H:%M UTC"),
    )
    return await get_brevo_client().send(
        to_email=to_email,
        to_name=None,
        subject="Votre compte TRIALGO a ete desactive",
        html=html,
    )
