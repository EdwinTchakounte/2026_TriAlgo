# =============================================================
# FICHIER : app/leaderboard/routes.py
# ROLE    : Endpoints leaderboard + stats joueur
# =============================================================
#
# Endpoints :
#   GET /api/games/{game_id}/leaderboard?limit=20
#     -> top users par user_games.total_score (un par user)
#
#   GET /api/me/stats
#     -> agregats perso (best_score, total games joues, etc.)
#
# Leaderboard base sur user_games.total_score (score cumule par
# jeu), pas sur user_sessions (partie individuelle). C'est ce qui
# donne le ranking global "qui est le meilleur sur ce jeu".
# =============================================================

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_user
from ..auth.models import User
from ..db import get_db
from ..games.models import Game
from ..sessions_history.models import UserSession
from ..user_games.models import UserGame

router = APIRouter()


# -------------------------------------------------------------
# Schemas
# -------------------------------------------------------------
class LeaderboardEntry(BaseModel):
    rank: int
    user_id: UUID
    username: str
    avatar_id: str
    total_score: int
    current_level: int


class LeaderboardOut(BaseModel):
    game_id: UUID
    entries: list[LeaderboardEntry]


class UserStatsOut(BaseModel):
    """Agregats personnels du user connecte."""
    games_activated: int        # nb de user_games (jeux actives via code)
    total_sessions_played: int   # nb total de parties jouees
    sessions_passed: int          # nb de parties reussies
    total_score_cumulated: int   # somme total_score de tous les jeux
    best_session_score: int      # meilleure score_gained sur une partie
    total_stars_earned: int      # somme stars_earned sur l'historique


# -------------------------------------------------------------
# GET leaderboard par jeu
# -------------------------------------------------------------
@router.get(
    "/games/{game_id}/leaderboard",
    response_model=LeaderboardOut,
    summary="Classement top joueurs d'un jeu par total_score (user)",
    description=(
        "Renvoie le top N (limit, defaut 20) des joueurs sur un jeu, "
        "trie par user_games.total_score desc puis activated_at asc "
        "(en cas d'egalite, le plus ancien gagne). Chaque entree "
        "inclut rank, user_id, username, avatar_id, total_score et "
        "current_level. Bornes limit dans [1,100]. Erreurs : 400 "
        "limite invalide, 404 jeu introuvable."
    ),
)
async def get_leaderboard(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _user: Annotated[User, Depends(get_current_user)],
    limit: int = 20,
) -> LeaderboardOut:
    if limit < 1 or limit > 100:
        raise HTTPException(400, "limit doit etre entre 1 et 100")
    if not await db.get(Game, game_id):
        raise HTTPException(404, "Jeu introuvable")

    # JOIN user_games <-> users pour avoir username + avatar.
    stmt = (
        select(
            UserGame.user_id,
            UserGame.total_score,
            UserGame.current_level,
            User.username,
            User.avatar_id,
        )
        .join(User, User.id == UserGame.user_id)
        .where(UserGame.game_id == game_id)
        .order_by(desc(UserGame.total_score), UserGame.activated_at.asc())
        .limit(limit)
    )
    rows = list((await db.execute(stmt)).all())

    entries = [
        LeaderboardEntry(
            rank=idx + 1,
            user_id=r.user_id,
            username=r.username,
            avatar_id=r.avatar_id,
            total_score=r.total_score,
            current_level=r.current_level,
        )
        for idx, r in enumerate(rows)
    ]
    return LeaderboardOut(game_id=game_id, entries=entries)


# -------------------------------------------------------------
# GET stats perso
# -------------------------------------------------------------
@router.get(
    "/me/stats",
    response_model=UserStatsOut,
    summary="Agregats statistiques du user connecte (user)",
    description=(
        "Calcule en 2 requetes agregees les stats perso : "
        "games_activated (nb jeux actives), total_sessions_played, "
        "sessions_passed (succes), total_score_cumulated (somme), "
        "best_session_score (meilleur), total_stars_earned. Utilise "
        "par l'ecran Profil pour afficher le palmares."
    ),
)
async def get_my_stats(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> UserStatsOut:
    from sqlalchemy import case

    # Agregat user_games en 1 requete (count + sum cumule).
    ug_row = (
        await db.execute(
            select(
                func.count(UserGame.user_id).label("games"),
                func.coalesce(func.sum(UserGame.total_score), 0).label("score_sum"),
            ).where(UserGame.user_id == user.id)
        )
    ).one()

    # Agregat user_sessions en 1 requete.
    us_row = (
        await db.execute(
            select(
                func.count(UserSession.id).label("total"),
                func.sum(
                    case((UserSession.passed.is_(True), 1), else_=0)
                ).label("passed"),
                func.coalesce(func.max(UserSession.score_gained), 0).label("best"),
                func.coalesce(func.sum(UserSession.stars_earned), 0).label("stars"),
            ).where(UserSession.user_id == user.id)
        )
    ).one()

    return UserStatsOut(
        games_activated=int(ug_row.games or 0),
        total_sessions_played=int(us_row.total or 0),
        sessions_passed=int(us_row.passed or 0),
        total_score_cumulated=int(ug_row.score_sum or 0),
        best_session_score=int(us_row.best or 0),
        total_stars_earned=int(us_row.stars or 0),
    )
