# =============================================================
# FICHIER : app/mail/client.py
# ROLE    : Client async pour l'API REST Brevo (transactional)
# =============================================================
#
# Doc API : https://developers.brevo.com/reference/sendtransacemail
# Endpoint : POST https://api.brevo.com/v3/smtp/email
# Header   : api-key: <BREVO_API_KEY>
# Body     :
#   {
#     "sender":      {"name": "...", "email": "..."},
#     "to":          [{"email": "...", "name": "..."}],
#     "subject":     "...",
#     "htmlContent": "<p>...</p>",
#     "textContent": "..."  (optionnel, fallback no-HTML)
#   }
#
# Si BREVO_API_KEY est vide : on log-only et on renvoie un id
# fake "DRY_RUN" -- utile en dev sans cle Brevo.
# =============================================================

import logging
import re
from dataclasses import dataclass
from typing import Optional

import httpx

from ..config import settings

logger = logging.getLogger("trialgo.mail")

_BREVO_URL = "https://api.brevo.com/v3/smtp/email"


# -------------------------------------------------------------
# Extraction des liens d'action (mode DRY RUN uniquement)
# -------------------------------------------------------------
# On ne remonte que les deux chemins qui portent un jeton et sans
# lesquels un parcours ne peut pas etre suivi de bout en bout. Les
# liens ordinaires des courriels (classement, jeu, vitrine) ne sont
# pas repris : ils n'apprennent rien et alourdiraient les journaux.
_CHEMINS_A_JOURNALISER = ("/reset-password?token=", "/confirm-email?token=")


def _liens_dactions(html: str) -> list[str]:
    """Retourne les liens porteurs de jeton contenus dans [html]."""
    liens = re.findall(r'href="([^"]+)"', html)
    return [
        lien
        for lien in liens
        if any(chemin in lien for chemin in _CHEMINS_A_JOURNALISER)
    ]


@dataclass(frozen=True)
class SendResult:
    """Resultat d'un envoi Brevo : message_id (ou DRY_RUN) + status."""
    message_id: str
    dry_run: bool
    error: Optional[str] = None


class BrevoClient:
    """Client async minimaliste pour les transactional emails Brevo."""

    def __init__(
        self,
        api_key: str,
        sender_email: str,
        sender_name: str,
        timeout_seconds: float = 10.0,
    ) -> None:
        self._api_key = api_key
        self._sender_email = sender_email
        self._sender_name = sender_name
        self._timeout = timeout_seconds

    async def send(
        self,
        *,
        to_email: str,
        to_name: Optional[str],
        subject: str,
        html: str,
        text: Optional[str] = None,
    ) -> SendResult:
        # Mode DRY RUN : pas de cle -> on log et on sort.
        # Utile en dev local pour ne pas spammer Brevo.
        if not self._api_key:
            logger.warning(
                "DRY-RUN email (BREVO_API_KEY vide) | to=%s | subject=%s",
                to_email,
                subject,
            )
            # On journalise aussi les liens d'action contenus dans le
            # message.
            #
            # POURQUOI, ET POURQUOI C'EST SANS DANGER ICI
            # -------------------------------------------
            # Sans cela, les parcours "mot de passe oublie" et
            # "confirmation d'adresse" sont tout simplement
            # intestables en local : le jeton n'est jamais affiche
            # (le courriel n'est pas envoye) et la base ne stocke que
            # son condensat. Il fallait une cle Brevo et une vraie
            # boite aux lettres pour verifier une page de rebond.
            #
            # Un lien de reinitialisation est un secret, et il n'a
            # normalement rien a faire dans un journal. Mais ce
            # branchement ne s'execute QUE lorsque BREVO_API_KEY est
            # vide -- c'est-a-dire quand aucun courriel ne part, une
            # situation que les controles de demarrage signalent deja
            # comme incompatible avec la production. En production,
            # la cle est renseignee et pas une ligne de ceci ne
            # s'execute.
            for lien in _liens_dactions(html):
                logger.warning("DRY-RUN lien | %s", lien)
            return SendResult(message_id="DRY_RUN", dry_run=True)

        payload = {
            "sender": {"email": self._sender_email, "name": self._sender_name},
            "to": [{"email": to_email, **({"name": to_name} if to_name else {})}],
            "subject": subject,
            "htmlContent": html,
        }
        if text:
            payload["textContent"] = text

        headers = {
            "api-key": self._api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                resp = await client.post(_BREVO_URL, json=payload, headers=headers)
        except httpx.HTTPError as e:
            logger.exception("Brevo HTTP error | to=%s", to_email)
            return SendResult(message_id="", dry_run=False, error=str(e))

        if resp.status_code >= 400:
            # Brevo renvoie un JSON {code, message} en erreur.
            logger.error(
                "Brevo %d | to=%s | body=%s",
                resp.status_code,
                to_email,
                resp.text[:300],
            )
            return SendResult(
                message_id="",
                dry_run=False,
                error=f"HTTP {resp.status_code} {resp.text[:200]}",
            )

        # Succes : Brevo renvoie {"messageId": "<...>@..."}.
        data = resp.json() if resp.content else {}
        message_id = data.get("messageId", "")
        return SendResult(message_id=message_id, dry_run=False)


# Singleton initialise depuis settings. Reinstanciable si besoin
# (changement de cle a chaud -> redemarrer le process).
_client: Optional[BrevoClient] = None


def get_brevo_client() -> BrevoClient:
    global _client
    if _client is None:
        _client = BrevoClient(
            api_key=settings.BREVO_API_KEY,
            sender_email=settings.BREVO_SENDER_EMAIL,
            sender_name=settings.BREVO_SENDER_NAME,
        )
    return _client
