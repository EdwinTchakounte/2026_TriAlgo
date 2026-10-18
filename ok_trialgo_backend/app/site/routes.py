# =============================================================
# FICHIER : app/site/routes.py
# ROLE    : Lecture publique et edition admin du contenu vitrine
# =============================================================
#
# Endpoints :
#   GET  /api/public/site/accueil   contenu publie (sans auth)
#   GET  /api/admin/site/accueil    idem, pour le studio (admin)
#   PUT  /api/admin/site/accueil    remplace le document (admin)
#   POST /api/admin/site/images     televerse une image (admin)
#
# DEUX ROUTERS DANS UN MODULE
# ---------------------------
# Le module monte ses routes sous deux prefixes differents :
# /api/public pour la vitrine, /api/admin pour le studio. Plutot
# que de reecrire le chemin complet dans chaque decorateur, on
# expose deux routers, chacun monte une fois dans main.py, comme
# le reste de l'API (public_router, admin_users_router).
#
# PUT ET NON PATCH
# ----------------
# Le studio edite TOUT le document puis le publie. Un PUT remplace
# donc le document en entier : ce que l'admin voit dans le
# formulaire est exactement ce qui est publie. Un PATCH fusionnerait
# avec l'ancien contenu, et un champ vide dans le formulaire ne
# pourrait plus jamais effacer une valeur publiee.
#
# LES IMAGES NE SONT PAS LIEES AU DOCUMENT
# ----------------------------------------
# Le televersement renvoie une URL ; c'est le PUT suivant qui la
# place dans la galerie. Une image televersee puis abandonnee reste
# donc dans le stockage sans etre referencee. C'est le meme
# arbitrage qu'a la suppression d'une carte : un orphelin invisible
# vaut mieux qu'une page qui pointe vers un fichier absent. On ne
# supprime rien automatiquement.
# =============================================================

from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import func

from ..auth.deps import get_current_admin
from ..auth.models import User
from ..cards.image import validate_and_process
from ..config import settings
from ..db import get_db
from ..storage import get_storage
from .models import SiteContent
from .schemas import SiteContentIn, SiteContentOut, SiteImageOut

public_router = APIRouter()
admin_router = APIRouter()

# Seule page editable aujourd'hui. Une constante plutot qu'un
# parametre de chemin libre : /site/{cle} accepterait n'importe
# quelle cle et creerait des documents que personne n'affiche.
CLE_ACCUEIL = "accueil"

# Prefixe des images dans le stockage : `site/<uuid>.jpg`, a cote
# des dossiers `<game_id>/` des cartes, sans collision possible
# (un game_id est un UUID, jamais le mot "site").
PREFIXE_IMAGES = "site"


async def _lire(db: AsyncSession) -> SiteContentOut:
    """Document publie, ou document vide si rien n'a jamais ete publie.

    Jamais de 404 : pour la vitrine, "pas encore de contenu" est un
    etat normal, qui veut dire "garde le HTML statique". Un 404
    s'afficherait en rouge dans la console de chaque visiteur.
    """
    row = await db.get(SiteContent, CLE_ACCUEIL)
    if row is None:
        return SiteContentOut(contenu={}, maj_le=None)
    return SiteContentOut(contenu=row.contenu, maj_le=row.maj_le)


# -------------------------------------------------------------
# PUBLIC : lecture par la vitrine
# -------------------------------------------------------------
@public_router.get(
    "/accueil",
    response_model=SiteContentOut,
    summary="Contenu publie de la page d'accueil de la vitrine (no auth)",
    description=(
        "Renvoie le document publie depuis le studio. Document vide "
        "(contenu = {}, maj_le = null) si rien n'a encore ete publie : "
        "la vitrine garde alors son contenu statique. Cache public de "
        "60 secondes."
    ),
)
async def get_public_accueil(
    response: Response,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SiteContentOut:
    # 60 s : chaque visiteur declenche cet appel. Une minute de cache
    # absorbe les pics sans que l'admin attende longtemps de voir sa
    # publication en ligne.
    response.headers["Cache-Control"] = "public, max-age=60"
    return await _lire(db)


# -------------------------------------------------------------
# ADMIN : lecture par le studio
# -------------------------------------------------------------
@admin_router.get(
    "/accueil",
    response_model=SiteContentOut,
    summary="Contenu de la page d'accueil, pour edition (admin only)",
    description=(
        "Meme document que la route publique, mais jamais mis en cache : "
        "le studio doit relire ce qu'il vient de publier."
    ),
)
async def get_admin_accueil(
    db: Annotated[AsyncSession, Depends(get_db)],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> SiteContentOut:
    return await _lire(db)


# -------------------------------------------------------------
# ADMIN : publication
# -------------------------------------------------------------
@admin_router.put(
    "/accueil",
    response_model=SiteContentOut,
    summary="Publie le contenu de la page d'accueil (admin only)",
    description=(
        "Remplace le document en entier. Tous les champs sont optionnels ; "
        "toute cle inconnue est refusee (422) pour qu'une faute de frappe "
        "ne passe pas inapercue."
    ),
)
async def put_admin_accueil(
    body: SiteContentIn,
    db: Annotated[AsyncSession, Depends(get_db)],
    admin: Annotated[User, Depends(get_current_admin)],
) -> SiteContentOut:
    # exclude_none : on ne stocke que ce qui est renseigne. Le JSON
    # publie reste lisible, et "absent" a un seul sens pour la vitrine.
    contenu = body.contenu.model_dump(mode="json", exclude_none=True)
    admin_id = admin.id

    row = await db.get(SiteContent, CLE_ACCUEIL)
    if row is None:
        row = SiteContent(cle=CLE_ACCUEIL, contenu=contenu, maj_par=admin_id)
        db.add(row)
    else:
        row.contenu = contenu
        row.maj_par = admin_id
        # server_default ne joue qu'a l'INSERT : a la mise a jour, la
        # date doit etre posee explicitement.
        row.maj_le = func.now()
    await db.commit()
    await db.refresh(row)
    return SiteContentOut(contenu=row.contenu, maj_le=row.maj_le)


# -------------------------------------------------------------
# ADMIN : televersement d'une image de la vitrine
# -------------------------------------------------------------
@admin_router.post(
    "/images",
    response_model=SiteImageOut,
    status_code=201,
    summary="Televerse une image pour la vitrine (multipart, admin only)",
    description=(
        "Meme pipeline que les cartes : lecture bornee (413 au-dela de "
        "MAX_UPLOAD_BYTES), type reel verifie par magic bytes, EXIF retire, "
        "redimensionnement, re-encodage JPEG (400 si invalide). Renvoie "
        "l'URL publique, a placer ensuite dans la galerie via le PUT."
    ),
)
async def upload_site_image(
    file: Annotated[UploadFile, File()],
    _admin: Annotated[User, Depends(get_current_admin)],
) -> SiteImageOut:
    raw = await file.read(settings.MAX_UPLOAD_BYTES + 1)
    if len(raw) > settings.MAX_UPLOAD_BYTES:
        raise HTTPException(413, "Fichier trop volumineux")

    try:
        processed = validate_and_process(raw, file.content_type)
    except ValueError as e:
        raise HTTPException(400, str(e)) from e

    # Pas de vignette : la vitrine affiche ses images en grand, et
    # choisit elle-meme la taille via le navigateur. On ne stocke que
    # le plein format.
    storage = get_storage()
    key = await storage.save(
        PREFIXE_IMAGES,
        processed.bytes,
        processed.content_type,
        processed.extension,
    )
    return SiteImageOut(object_key=key, url=await storage.public_url(key))
