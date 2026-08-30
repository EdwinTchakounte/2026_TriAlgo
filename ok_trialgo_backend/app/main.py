# =============================================================
# FICHIER : app/main.py
# ROLE    : FastAPI app factory + routers + middlewares
# =============================================================
#
# Pattern factory : `create_app()` retourne une instance FastAPI
# configuree (utile pour les tests : on peut reconstruire l'app
# avec une config differente sans toucher au module global).
#
# Le `app = create_app()` final est ce que uvicorn lance via
# `app.main:app`.
# =============================================================

import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .admin_users.routes import router as admin_users_router
from .auth.routes import router as auth_router
from .cards.routes import router as cards_router
from .codes.routes import router as codes_router
from .collective.routes import router as collective_router
from .config import settings
from .core.startup_checks import journaliser_controles_de_demarrage
from .games.routes import router as games_router
from .leaderboard.routes import router as leaderboard_router
from .links.routes import router as links_router
from .nodes.routes import router as nodes_router
from .played_nodes.routes import router as played_nodes_router
from .profiles.routes import router as profiles_router
from .public.routes import router as public_router
from .sessions_history.routes import router as sessions_history_router
from .stars.routes import router as stars_router
from .unlocked_cards.routes import router as unlocked_cards_router
from .user_games.routes import router as user_games_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    """Hooks startup/shutdown de l'app."""
    # Startup : controle des variables d'environnement sensibles.
    # Certaines valeurs de dev (S3_PUBLIC_ENDPOINT_URL sur localhost,
    # JWT_SECRET d'exemple, CORS purement local...) ne provoquent
    # AUCUNE erreur cote serveur mais cassent les clients en prod.
    # On les signale bruyamment dans les logs plutot que de laisser
    # le probleme se manifester par des images cassees sur mobile.
    journaliser_controles_de_demarrage()

    # Menage des compteurs de limitation de debit.
    #
    # Les fenetres passees ne servent plus a rien. On les purge ici
    # plutot que via une tache planifiee : la table reste petite sans
    # infrastructure supplementaire, et le cout est paye une fois par
    # demarrage. Une panne de ce menage ne doit rien empecher — d'ou
    # le try/except large.
    try:
        from .core.rate_limit import purger_fenetres_expirees
        from .db import SessionLocal

        async with SessionLocal() as session:
            efface = await purger_fenetres_expirees(session)
        if efface:
            logger.info("rate-limit : %d compteurs expires purges", efface)
    except Exception:  # noqa: BLE001
        logger.warning("rate-limit : purge au demarrage impossible", exc_info=True)

    yield
    # Shutdown : ici on dispose les ressources (engine, etc.).
    from .db import engine
    await engine.dispose()


def create_app() -> FastAPI:
    app = FastAPI(
        title="TRIALGO Backend",
        version="0.1.0",
        description="API admin + jeu pour TRIALGO (fusions de cartes).",
        lifespan=lifespan,
    )

    # ----- CORS -----
    # Autorise les apps Flutter web/desktop a appeler l'API depuis
    # un domaine different. Pour Flutter Android natif, CORS n'est
    # pas concerne (pas de navigateur). On garde quand meme pour
    # le mode web.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ----- Healthcheck -----
    # Endpoint trivial pour les health checks Docker + load balancers.
    @app.get("/healthz", tags=["meta"])
    async def healthz() -> dict[str, str]:
        return {"status": "ok"}

    # ----- Routers metier (admin + catalogue) -----
    app.include_router(auth_router,        prefix="/api/auth",   tags=["auth"])
    app.include_router(games_router,       prefix="/api/games",  tags=["games"])
    app.include_router(cards_router,       prefix="/api",        tags=["cards"])
    app.include_router(nodes_router,       prefix="/api",        tags=["nodes"])
    app.include_router(public_router,      prefix="/api/public", tags=["public"])
    app.include_router(admin_users_router, prefix="/api/admin",  tags=["admin-users"])

    # ----- Routers JOUEUR (porte depuis Supabase) -----
    # Profil + wallet etoiles : GET/PATCH /api/me/profile.
    app.include_router(profiles_router,         prefix="/api/me",   tags=["profile"])
    # Activation codes (joueur + admin codes).
    app.include_router(codes_router,            prefix="/api",      tags=["codes"])
    # Etat par-jeu (lives + refill) : /api/me/games.
    app.include_router(user_games_router,       prefix="/api/me",   tags=["user-games"])
    # Historique parties : POST + GET /api/me/sessions.
    app.include_router(sessions_history_router, prefix="/api/me",   tags=["sessions"])
    # Deck galerie : /api/me/unlocked-cards.
    app.include_router(unlocked_cards_router,   prefix="/api/me",   tags=["deck"])
    # Tracking anti-doublon : /api/me/played-nodes.
    app.include_router(played_nodes_router,     prefix="/api/me",   tags=["played-nodes"])
    # Wallet etoiles + exchange : /api/me/stars.
    app.include_router(stars_router,            prefix="/api/me",   tags=["stars"])
    # Mode collectif : /api/games/{gid}/verify-collective.
    app.include_router(collective_router,       prefix="/api/games", tags=["collective"])
    # Leaderboard + stats perso : /api/games/{gid}/leaderboard + /api/me/stats.
    # Note: ce router monte BOTH /api/me/stats ET /api/games/.../leaderboard,
    # donc on le prefixe a /api (pas /api/me) et chaque route inclut son chemin complet.
    app.include_router(leaderboard_router,      prefix="/api",      tags=["leaderboard"])

    # ----- Pages de rebond des liens envoyes par courriel -----
    # Montees a la RACINE, sans prefixe /api : ce sont des pages
    # ouvertes dans un navigateur, pas des ressources d'API. Elles
    # n'apparaissent pas dans OpenAPI (include_in_schema=False).
    #   GET /reset-password  -> rend la main a l'application mobile
    #   GET /confirm-email   -> consomme le jeton et affiche le resultat
    app.include_router(links_router, tags=["links"])

    return app


# Instance ASGI lancee par uvicorn (app.main:app).
app = create_app()
