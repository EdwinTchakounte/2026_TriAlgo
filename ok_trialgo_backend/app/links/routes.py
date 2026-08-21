# =============================================================
# FICHIER : app/links/routes.py
# ROLE    : Pages de rebond des liens envoyes par courriel
# =============================================================
#
# Endpoints (hors /api, ce sont des pages, pas des ressources) :
#   GET /reset-password?token=...   rebond vers l'application
#   GET /confirm-email?token=...    consomme le jeton et affiche le resultat
#
# LE PROBLEME QUE CES DEUX PAGES RESOLVENT
# ----------------------------------------
# Le backend envoyait deja les courriels, creait deja les jetons...
# et les liens ne menaient nulle part. Ils etaient construits sur
# APP_FRONTEND_URL, qui vaut `https://dashboard.mixalgo.com` en
# production : le studio d'administration, dont le routage renvoie
# index.html pour toute route inconnue. Un joueur ayant oublie son
# mot de passe atterrissait donc sur la page de connexion de
# l'administration, et personne ne consommait son jeton.
#
# Autrement dit : la reinitialisation de mot de passe etait
# inutilisable, sans qu'aucune erreur ne le signale nulle part.
#
# POURQUOI CES PAGES VIVENT SUR LE DOMAINE DE L'API
# -------------------------------------------------
# Parce que c'est le seul service de la topologie qui sache
# executer du code. La vitrine est hors de ce depot, et le studio
# est un binaire Flutter web sans routes serveur. Caddy transmet
# deja tout ce qui n'est pas /files a l'API : ces deux chemins
# arrivent donc ici sans une ligne de configuration supplementaire.
#
# Les deux emplacements des liens changent donc de APP_FRONTEND_URL
# vers PUBLIC_BASE_URL (cf. app/mail/sender.py). Les autres liens
# des courriels -- classement, jeu, administration -- continuent de
# viser APP_FRONTEND_URL, ce qui reste correct pour eux.
# =============================================================

from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.models import User
from ..config import settings
from ..db import get_db
from ..mail.models import EMAIL_PURPOSE_CONFIRM
from ..mail.sender import send_welcome_confirmed
from ..mail.tokens import verify_and_consume
from .pages import page_confirmation, page_reinitialisation

router = APIRouter()


# -------------------------------------------------------------
# GET /reset-password
# -------------------------------------------------------------
@router.get(
    "/reset-password",
    response_class=HTMLResponse,
    include_in_schema=False,
    summary="Page de rebond vers l'application (reinitialisation)",
)
async def page_de_reinitialisation(
    token: Annotated[str, Query(min_length=8, max_length=512)],
) -> HTMLResponse:
    # On NE consomme PAS le jeton ici : cette page ne fait que
    # transmettre. C'est l'application qui appellera
    # POST /api/auth/reset-password avec le nouveau mot de passe.
    #
    # La distinction compte : un aspirateur de liens (antivirus de
    # messagerie, previsualisation) qui suivrait ce lien brulerait
    # le jeton avant meme que le joueur ne clique.
    lien = f"{settings.APP_DEEP_LINK_SCHEME}://reset-password?token={token}"

    return HTMLResponse(
        page_reinitialisation(lien_application=lien, jeton=token),
        # Une page portant un jeton dans son URL n'a rien a faire
        # dans un cache partage.
        headers={"Cache-Control": "no-store"},
    )


# -------------------------------------------------------------
# GET /confirm-email
# -------------------------------------------------------------
@router.get(
    "/confirm-email",
    response_class=HTMLResponse,
    include_in_schema=False,
    summary="Confirme l'adresse et affiche le resultat",
)
async def page_de_confirmation(
    token: Annotated[str, Query(min_length=8, max_length=512)],
    db: Annotated[AsyncSession, Depends(get_db)],
    background: BackgroundTasks,
) -> HTMLResponse:
    # Ici, a l'inverse, on consomme le jeton directement.
    #
    # POURQUOI CETTE ASYMETRIE AVEC LA PAGE PRECEDENTE
    # ------------------------------------------------
    # Confirmer une adresse ne demande aucune saisie : le clic EST
    # l'action. Renvoyer vers l'application ajouterait une etape
    # sans rien apporter, et echouerait pour qui ouvre son courriel
    # depuis un ordinateur.
    #
    # Le risque connu : un aspirateur de liens confirmerait
    # l'adresse a la place du destinataire. La consequence est
    # benigne -- l'adresse est marquee verifiee, ce que le
    # destinataire s'appretait de toute facon a faire -- et c'est le
    # compromis retenu par la plupart des services.
    #
    # La logique reproduit celle de POST /api/auth/confirm-email,
    # qui reste en place pour les clients souhaitant confirmer
    # eux-memes.
    user_id = await verify_and_consume(db, token, EMAIL_PURPOSE_CONFIRM)
    if user_id is None:
        return HTMLResponse(
            page_confirmation(
                reussi=False,
                message="Ce lien de confirmation est invalide ou a expire.",
            ),
            status_code=400,
            headers={"Cache-Control": "no-store"},
        )

    user = await db.get(User, user_id)
    if user is None:
        return HTMLResponse(
            page_confirmation(
                reussi=False,
                message="Ce compte n'existe plus.",
            ),
            status_code=400,
            headers={"Cache-Control": "no-store"},
        )

    # Idempotent : une seconde visite ne doit pas ecraser la date
    # d'origine, ni renvoyer un second courriel de bienvenue.
    premiere_confirmation = user.email_confirmed_at is None
    if premiere_confirmation:
        user.email_confirmed_at = datetime.now(timezone.utc)
        await db.commit()
        background.add_task(
            send_welcome_confirmed,
            to_email=user.email,
            to_name=None,
        )

    return HTMLResponse(
        page_confirmation(
            reussi=True,
            message=(
                "Votre adresse est verifiee, votre compte est actif."
                if premiere_confirmation
                else "Cette adresse etait deja confirmee."
            ),
        ),
        headers={"Cache-Control": "no-store"},
    )
