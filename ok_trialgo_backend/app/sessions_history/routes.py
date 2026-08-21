# =============================================================
# FICHIER : app/sessions_history/routes.py
# ROLE    : Endpoints /api/me/sessions (historique parties)
# =============================================================
#
# Endpoints :
#   POST /api/me/sessions    enregistre une partie terminee + maj
#                            user_games (total_score, level, vies)
#   GET  /api/me/sessions    historique paginated (filtre game_id ok)
#
# La logique POST :
#   1. Verifie que l'user a bien un user_games pour ce game_id
#      (sinon -> il essaie d'enregistrer une partie sans avoir
#      active le jeu : refus).
#   2. INSERT user_sessions (snapshot).
#   3. UPDATE user_games :
#        - total_score += score_gained
#        - si passed et level >= current_level : current_level = level+1
#        - lives -= 1 (la partie a consomme une vie, sauf si gratuite ?)
#          *** decision : on perd une vie SEULEMENT si passed = false.
#              Sinon le joueur progresse, garde sa vie.
#   4. Commit transactionnel atomique.
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..db import get_db
from ..games.models import Game
from ..mail.models import EmailPreferences
from ..mail.sender import send_session_summary
from ..user_games.models import UserGame
from .models import UserSession
from .schemas import (
    PaginatedSessions,
    SessionRecordedResponse,
    SessionRecordIn,
    SessionRecordOut,
)

router = APIRouter()


# -------------------------------------------------------------
# POST /api/me/sessions : enregistre une partie terminee
# -------------------------------------------------------------
@router.post(
    "/sessions",
    response_model=SessionRecordedResponse,
    status_code=201,
    summary="Enregistre une partie terminee et met a jour user_games (user)",
    description=(
        "Insere une ligne user_sessions (snapshot de partie) et met a "
        "jour user_games en mode atomique : total_score += "
        "score_gained ; si passed et level >= current_level alors "
        "current_level = level + 1 ; si NOT passed alors lives -= 1 "
        "(clamp >= 0). L'user doit avoir active le jeu via un code "
        "(403 sinon). Renvoie les nouveaux totaux pour rafraichir l'UI."
    ),
)
async def record_session(
    body: SessionRecordIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    background: BackgroundTasks,
) -> SessionRecordedResponse:
    # 1. Charger user_games (la partie ne peut etre enregistree que
    # si l'user a active le jeu via un code).
    ug = await db.scalar(
        select(UserGame).where(
            UserGame.user_id == user.id,
            UserGame.game_id == body.game_id,
        )
    )
    if not ug:
        raise HTTPException(403, "Jeu non active pour cet utilisateur")

    # 2. INSERT historique.
    session = UserSession(
        user_id=user.id,
        game_id=body.game_id,
        level=body.level,
        score_gained=body.score_gained,
        correct_answers=body.correct_answers,
        wrong_answers=body.wrong_answers,
        questions_total=body.questions_total,
        max_streak=body.max_streak,
        duration_seconds=body.duration_seconds,
        passed=body.passed,
        stars_earned=body.stars_earned,
    )
    db.add(session)

    # 3. UPDATE user_games.
    ug.total_score += body.score_gained
    # Niveau : passe au suivant si partie reussie et qu'on etait
    # au moins au niveau atteint (eviter regression).
    if body.passed and body.level >= ug.current_level:
        ug.current_level = body.level + 1
    # Vies : on consomme 1 vie SEULEMENT si la partie a echoue
    # (perte d'une chance). Clamp >= 0.
    if not body.passed:
        ug.lives = max(0, ug.lives - 1)

    await db.commit()
    await db.refresh(session)
    await db.refresh(ug)

    # 4. Envoi mail "session_summary" en background si l'user a opt-in.
    # On ne notifie pas a chaque partie ratee dans un grind : le user
    # peut desactiver depuis ses preferences (PATCH email_preferences).
    # Decision : on n'envoie que pour les parties RECUSSES OU avec un
    # bonus (stars_earned >= 1) pour eviter le spam de defaites.
    if body.passed or body.stars_earned >= 1:
        prefs = await db.scalar(
            select(EmailPreferences).where(EmailPreferences.user_id == user.id)
        )
        if prefs is None or prefs.session_summary:
            # Pas de prefs (anciens comptes) ou opt-in actif : on envoie.
            # Charger le nom du jeu pour le template.
            game = await db.get(Game, body.game_id)
            game_name = game.name if game else "TRIALGO"
            # Total_trios du jeu : nb de nodes (cache nul ici, fetch direct).
            from ..nodes.models import GameNode  # import local pour eviter cycles
            total_trios = await db.scalar(
                select(func.count(GameNode.id)).where(GameNode.game_id == body.game_id)
            ) or 0
            background.add_task(
                send_session_summary,
                to_email=user.email,
                to_name=user.username,
                game_name=game_name,
                score=body.score_gained,
                trios_found=body.correct_answers,
                total_trios=int(total_trios),
                completion_bonus=(body.stars_earned >= 3),
            )

    return SessionRecordedResponse(
        session=SessionRecordOut.model_validate(session),
        new_total_score=ug.total_score,
        new_current_level=ug.current_level,
        new_lives=ug.lives,
        new_max_lives=ug.max_lives,
    )


# -------------------------------------------------------------
# GET /api/me/sessions : historique paginated
# -------------------------------------------------------------
@router.get(
    "/sessions",
    response_model=PaginatedSessions,
    summary="Historique paginated des parties du user (user)",
    description=(
        "Renvoie l'historique des user_sessions du user connecte, "
        "trie par played_at desc. Filtre optionnel par game_id pour "
        "limiter a un jeu. Bornes : limit dans [1,100], offset >= 0. "
        "Erreur 400 si parametres hors bornes."
    ),
)
async def list_my_sessions(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
    game_id: UUID | None = None,
    limit: int = 20,
    offset: int = 0,
) -> PaginatedSessions:
    if limit < 1 or limit > 100:
        raise HTTPException(400, "limit doit etre entre 1 et 100")
    if offset < 0:
        raise HTTPException(400, "offset >= 0")

    stmt = (
        select(UserSession)
        .where(UserSession.user_id == user.id)
        .order_by(UserSession.played_at.desc())
    )
    count_stmt = select(func.count(UserSession.id)).where(
        UserSession.user_id == user.id
    )
    if game_id is not None:
        stmt = stmt.where(UserSession.game_id == game_id)
        count_stmt = count_stmt.where(UserSession.game_id == game_id)

    total = await db.scalar(count_stmt)
    rows = list(await db.scalars(stmt.limit(limit).offset(offset)))
    return PaginatedSessions(
        items=[SessionRecordOut.model_validate(s) for s in rows],
        total=int(total or 0),
        limit=limit,
        offset=offset,
    )
