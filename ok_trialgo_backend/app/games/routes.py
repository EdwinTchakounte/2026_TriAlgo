# =============================================================
# FICHIER : app/games/routes.py
# ROLE    : CRUD jeux  -  /api/games
# =============================================================
#
# Endpoints :
#   GET    /api/games            list (hybride : admin voit tout,
#                                       autres voient is_active=true)
#   POST   /api/games            cree (admin)
#   GET    /api/games/{id}       detail (idem hybride)
#   PATCH  /api/games/{id}       update partial (admin)
#   DELETE /api/games/{id}       suppression (admin)
#
# La logique hybride est portee par get_current_user_optional :
#   - token absent / invalide -> user is None    -> filtre actifs
#   - token user normal       -> user.is_admin=False -> filtre actifs
#   - token admin             -> aucun filtre (voit drafts inactifs)
#
# Pour l'app joueur publique, le module public/ expose
# /api/public/games qui force le filtre actif sans header.
# =============================================================

from typing import Annotated, Optional
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..auth.deps import get_current_admin, get_current_user_optional
from ..auth.models import User
from ..db import get_db
from ..mail.models import EmailPreferences
from ..mail.sender import send_new_game
from .models import Game
from .schemas import GameCreate, GameOut, GameUpdate

router = APIRouter()


@router.get(
    "",
    response_model=list[GameOut],
    summary="Liste les jeux (admin voit tout, autres voient les actifs)",
    description=(
        "Renvoie la liste des jeux triee par created_at desc. "
        "Comportement hybride dependant du token : sans auth ou user "
        "normal -> filtre is_active=true (drafts caches) ; admin -> "
        "voit tout y compris les drafts inactifs. Pour la vitrine "
        "publique sans auth, preferer /api/public/games."
    ),
)
async def list_games(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[Optional[User], Depends(get_current_user_optional)],
) -> list[Game]:
    # Construction de la requete : ORDER BY created_at desc.
    stmt = select(Game).order_by(Game.created_at.desc())
    # Si caller absent ou non-admin : on filtre is_active=true pour
    # ne pas exposer les jeux en cours de prepa (drafts).
    if user is None or not user.is_admin:
        stmt = stmt.where(Game.is_active.is_(True))
    result = await db.scalars(stmt)
    return list(result)


@router.post(
    "",
    response_model=GameOut,
    status_code=201,
    summary="Cree un nouveau jeu (admin only)",
    description=(
        "Insere un nouveau Game a partir du payload GameCreate. "
        "Reserve aux admins. Le jeu nouvellement cree est typiquement "
        "is_active=false (draft) le temps d'y ajouter cartes et "
        "fusions avant publication."
    ),
)
async def create_game(
    body: GameCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
    background: BackgroundTasks,
) -> Game:
    game = Game(**body.model_dump())
    db.add(game)
    await db.commit()
    await db.refresh(game)

    # Notification "nouveau jeu" : envoye uniquement si le jeu est
    # publie (is_active=true). Si l'admin cree un draft (is_active=false),
    # la notification sera envoyee plus tard au moment de la publication
    # via PATCH (cf update_game). On filtre par email_preferences.new_game
    # pour respecter l'opt-out.
    if game.is_active:
        await _notify_new_game(db, game, background)

    return game


# -------------------------------------------------------------
# Helper : notify_new_game (mass mailing avec opt-in)
# -------------------------------------------------------------
async def _notify_new_game(
    db: AsyncSession,
    game: Game,
    background: BackgroundTasks,
) -> None:
    """Envoie le mail 'nouveau jeu' a tous les users opt-in.

    On JOIN users <-> email_preferences pour ne prendre que ceux qui
    ont accepte. Les users sans ligne preferences (anciens comptes
    avant migration 0003_email) sont consideres opt-out par defaut
    pour eviter le spam involontaire.

    Chaque envoi est non-bloquant via BackgroundTasks ; Brevo absorbe
    100-1000 mails/heure sans probleme.
    """
    stmt = (
        select(User.email, User.username)
        .join(EmailPreferences, EmailPreferences.user_id == User.id)
        .where(
            User.is_active.is_(True),
            EmailPreferences.new_game.is_(True),
        )
    )
    rows = (await db.execute(stmt)).all()
    for row in rows:
        background.add_task(
            send_new_game,
            to_email=row.email,
            to_name=row.username,
            game_name=game.name,
            game_description=game.description,
            game_id=str(game.id),
        )


@router.get(
    "/{game_id}",
    response_model=GameOut,
    summary="Recupere le detail d'un jeu (admin voit drafts)",
    description=(
        "Renvoie le detail d'un Game par UUID. Meme logique hybride "
        "que list_games : un non-admin ne peut pas voir un jeu inactif "
        "(draft) meme via son id direct. Erreur 404 si jeu introuvable "
        "ou inaccessible (sans fuir l'existence)."
    ),
)
async def get_game(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[Optional[User], Depends(get_current_user_optional)],
) -> Game:
    g = await db.get(Game, game_id)
    if not g:
        raise HTTPException(404, "Jeu introuvable")
    # Meme regle que list_games : un non-admin ne peut pas voir un
    # jeu inactif (draft) meme via son id direct.
    if (user is None or not user.is_admin) and not g.is_active:
        raise HTTPException(404, "Jeu introuvable")
    return g


@router.patch(
    "/{game_id}",
    response_model=GameOut,
    summary="Met a jour partiellement un jeu (admin only)",
    description=(
        "Update partial d'un Game. Seuls les champs fournis dans le "
        "payload (exclude_unset=True) sont modifies. Utile pour "
        "basculer is_active true/false (publication/depublication), "
        "modifier le theme ou le cover. Erreur 404 si jeu introuvable."
    ),
)
async def update_game(
    game_id: UUID,
    body: GameUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
    background: BackgroundTasks,
) -> Game:
    g = await db.get(Game, game_id)
    if not g:
        raise HTTPException(404, "Jeu introuvable")
    # Snapshot avant update pour detecter une PUBLICATION (false -> true)
    # qui declenchera le mail "nouveau jeu".
    was_active = g.is_active
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(g, k, v)
    await db.commit()
    await db.refresh(g)
    # PUBLICATION : seul cas qui notifie. Re-activation d'un jeu deja
    # publie precedemment (false -> true apres avoir ete true) declenche
    # aussi le mail : c'est volontaire car les joueurs peuvent avoir
    # ete deactives entre temps.
    if not was_active and g.is_active:
        await _notify_new_game(db, g, background)
    return g


@router.delete(
    "/{game_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Supprime un jeu (admin only)",
    description=(
        "Supprime definitivement un Game. La cascade FK supprime "
        "egalement cartes, fusions, codes d'activation et donnees "
        "user associees selon la configuration. Erreur 404 si "
        "introuvable. Action irreversible : a utiliser avec prudence."
    ),
)
async def delete_game(
    game_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> None:
    g = await db.get(Game, game_id)
    if not g:
        raise HTTPException(404, "Jeu introuvable")
    await db.delete(g)
    await db.commit()
