# =============================================================
# FICHIER : app/core/rate_limit.py
# ROLE    : Limiter le debit des endpoints sensibles
# =============================================================
#
# POURQUOI CE MODULE EXISTE
# -------------------------
# Sans limitation, trois portes restent grandes ouvertes :
#
#   1. POST /api/auth/login          -> force brute sur les mots de passe.
#   2. POST /api/codes/activate      -> enumeration des codes de vente.
#      C'est le plus couteux : un code devine est une licence volee.
#   3. POST /api/auth/forgot-password -> chaque appel envoie un courriel
#      Brevo. Une boucle de trois lignes vide le quota d'envoi, ou noie
#      la boite d'un tiers.
#
# POURQUOI POSTGRES ET PAS LA MEMOIRE
# -----------------------------------
# La production tourne avec `uvicorn --workers 2` (cf. Dockerfile).
# Un compteur en memoire serait :
#   - par worker, donc la limite reelle vaudrait le double ;
#   - perdu a chaque redemarrage, ce qui offre a un attaquant une
#     remise a zero gratuite.
# Les endpoints proteges sont tous a faible trafic par nature (on ne
# se connecte pas 100 fois par seconde), donc un aller-retour SQL par
# appel est un cout negligeable face a la garantie obtenue.
#
# ALGORITHME : FENETRE FIXE
# -------------------------
# On arrondit l'instant courant au debut de la fenetre, et on compte
# les coups dans (cle, debut_de_fenetre) via un UPSERT atomique en un
# seul aller-retour.
#
# Limite connue et acceptee : a cheval sur deux fenetres, un attaquant
# peut placer 2x la limite en un court instant. Pour de la force brute
# cela ne change rien — ce qui compte est le debit soutenu. Une fenetre
# glissante exigerait une ligne par coup et un COUNT a chaque appel :
# beaucoup plus cher pour un gain nul ici.
#
# COMPORTEMENT EN CAS DE PANNE : ON LAISSE PASSER
# -----------------------------------------------
# Si la table est inaccessible, on journalise et on autorise. Un
# limiteur casse ne doit jamais mettre l'API a terre : refuser tout le
# monde transformerait un incident de base en panne totale.
# =============================================================

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import get_db

logger = logging.getLogger(__name__)


# =============================================================
# IDENTIFICATION DE L'APPELANT
# =============================================================
# Derriere Caddy, `request.client.host` vaut l'IP du reverse proxy :
# tout le monde partagerait le meme compteur, et le premier a
# depasser la limite bloquerait tous les autres.
#
# Caddy AJOUTE l'IP du pair immediat a la fin de X-Forwarded-For.
# Donc si un client malveillant envoie lui-meme
#     X-Forwarded-For: 9.9.9.9
# l'en-tete recu par l'API vaut
#     X-Forwarded-For: 9.9.9.9, <vraie IP du client>
#
# La vraie IP est donc la DERNIERE, jamais la premiere. Lire la
# premiere — le reflexe habituel — laisserait n'importe qui usurper
# une identite differente a chaque requete et contourner la limite.
# =============================================================

def client_ip(request: Request) -> str:
    """Retourne l'IP de l'appelant, en tenant compte du reverse proxy."""
    if settings.TRUST_PROXY_HEADERS:
        transmis = request.headers.get("x-forwarded-for")
        if transmis:
            # Dernier maillon = celui ajoute par notre propre proxy.
            dernier = transmis.split(",")[-1].strip()
            if dernier:
                return dernier
    if request.client is not None:
        return request.client.host
    return "inconnu"


# =============================================================
# COMPTAGE
# =============================================================

async def _enregistrer_coup(
    db: AsyncSession,
    cle: str,
    fenetre_secondes: int,
) -> tuple[int, datetime]:
    """Incremente le compteur de [cle] et renvoie (total, fin_de_fenetre).

    L'UPSERT est atomique : deux workers qui frappent la meme cle au
    meme instant obtiennent deux valeurs distinctes, jamais la meme.
    """
    maintenant = datetime.now(timezone.utc)
    # Arrondi au debut de la fenetre courante.
    epoch = int(maintenant.timestamp())
    debut_epoch = epoch - (epoch % fenetre_secondes)
    debut = datetime.fromtimestamp(debut_epoch, tz=timezone.utc)
    fin = debut + timedelta(seconds=fenetre_secondes)

    resultat = await db.execute(
        text(
            """
            INSERT INTO rate_limit_buckets (bucket_key, window_start, hits)
            VALUES (:cle, :debut, 1)
            ON CONFLICT (bucket_key, window_start)
            DO UPDATE SET hits = rate_limit_buckets.hits + 1
            RETURNING hits
            """
        ),
        {"cle": cle, "debut": debut},
    )
    total = resultat.scalar_one()
    await db.commit()
    return total, fin


async def verifier_quota(
    db: AsyncSession,
    *,
    cle: str,
    limite: int,
    fenetre_secondes: int,
) -> None:
    """Leve un 429 si [cle] a depasse [limite] coups dans la fenetre.

    Utilisable directement dans une route quand la cle depend du corps
    de la requete (par exemple l'adresse email visee par une tentative
    de connexion), ce qu'une dependance ne peut pas connaitre.
    """
    try:
        total, fin = await _enregistrer_coup(db, cle, fenetre_secondes)
    except Exception:  # noqa: BLE001 - on laisse passer, cf. bandeau
        logger.exception("rate-limit indisponible, requete autorisee (cle=%s)", cle)
        return

    if total > limite:
        secondes_restantes = max(1, int((fin - datetime.now(timezone.utc)).total_seconds()))
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Trop de tentatives. Reessayez dans un instant.",
            headers={"Retry-After": str(secondes_restantes)},
        )


# =============================================================
# DEPENDANCE REUTILISABLE
# =============================================================
# S'utilise en decoration de route :
#
#   @router.post(
#       "/login",
#       dependencies=[Depends(RateLimit("login", limite=10, fenetre_secondes=60))],
#   )
#
# La dependance ne voit que l'IP. Pour une limite adossee a une valeur
# du corps (email, code), appeler `verifier_quota` dans la route.
# =============================================================

class RateLimit:
    """Fabrique une dependance FastAPI qui limite par IP."""

    def __init__(self, nom: str, *, limite: int, fenetre_secondes: int) -> None:
        self.nom = nom
        self.limite = limite
        self.fenetre_secondes = fenetre_secondes

    async def __call__(
        self,
        request: Request,
        db: Annotated[AsyncSession, Depends(get_db)],
    ) -> None:
        if not settings.RATE_LIMIT_ENABLED:
            return
        await verifier_quota(
            db,
            cle=f"{self.nom}:ip:{client_ip(request)}",
            limite=self.limite,
            fenetre_secondes=self.fenetre_secondes,
        )


# =============================================================
# MENAGE
# =============================================================
# Les lignes de fenetres passees ne servent plus a rien. On les
# supprime au demarrage : la table reste petite sans avoir a
# installer de tache planifiee, et le cout est paye une fois.
# =============================================================

async def purger_fenetres_expirees(db: AsyncSession, *, garder_heures: int = 24) -> int:
    """Supprime les compteurs anterieurs a [garder_heures]. Renvoie le nombre efface."""
    limite = datetime.now(timezone.utc) - timedelta(hours=garder_heures)
    resultat = await db.execute(
        text("DELETE FROM rate_limit_buckets WHERE window_start < :limite"),
        {"limite": limite},
    )
    await db.commit()
    return resultat.rowcount or 0
