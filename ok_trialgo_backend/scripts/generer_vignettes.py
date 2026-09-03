#!/usr/bin/env python3
# =============================================================
# FICHIER : scripts/generer_vignettes.py
# ROLE    : Fabriquer les vignettes des cartes creees avant elles
# =============================================================
#
# POURQUOI CE SCRIPT
# ------------------
# La migration 0010 ajoute `cards.thumb_key`, NULL pour toutes les
# cartes existantes. Le client sait retomber sur le plein format,
# donc rien n'est casse -- mais rien n'est gagne non plus : la
# grille de 6 choix continue de telecharger du 1024 px.
#
# Ce script relit chaque original depuis le stockage, en derive la
# vignette et renseigne la colonne. Aucun re-televersement n'est
# demande a l'administrateur.
#
# IDEMPOTENT
# ----------
# Ne traite que les cartes dont `thumb_key` est NULL. Le relancer
# apres une interruption reprend ou il s'etait arrete, sans refaire
# le travail deja fait ni creer de doublons dans le stockage.
#
# ORDRE DES ECRITURES
# -------------------
# Vignette ecrite dans le stockage D'ABORD, colonne mise a jour
# ENSUITE. Une interruption entre les deux laisse un fichier
# orphelin -- invisible et inoffensif ; l'inverse laisserait la base
# pointant une vignette inexistante, donc des images cassees dans le
# jeu. Meme arbitrage que le pipeline d'upload.
#
# USAGE
# -----
#   docker compose exec api python scripts/generer_vignettes.py
#   docker compose exec api python scripts/generer_vignettes.py --essai
#
# --essai n'ecrit rien : il annonce ce qui serait fait.
# =============================================================

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

# Le script est lance depuis la racine du projet (ou depuis le
# conteneur, dont le WORKDIR est cette racine) : on s'assure que
# `app` est importable meme si le repertoire courant differe.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select  # noqa: E402

from app.cards.image import ProcessedImage  # noqa: E402
from app.cards.models import Card  # noqa: E402
from app.db import SessionLocal  # noqa: E402
from app.storage import get_storage  # noqa: E402

# Import indispensable, meme s'il n'est jamais utilise directement :
# `cards.game_id` porte une cle etrangere vers `games`, et SQLAlchemy
# ne sait la resoudre que si la table cible est enregistree dans le
# metadata. Sans cette ligne, la premiere requete leve
# NoReferencedTableError. Meme raison que les imports d'alembic/env.py.
from app.games.models import Game  # noqa: E402,F401


def _vignette_depuis(raw: bytes) -> ProcessedImage:
    """Reduit une image deja normalisee en vignette.

    On ne repasse PAS par validate_and_process : l'original stocke a
    deja ete valide, converti en RGB, debarrasse de son EXIF et borne
    a IMAGE_MAX_DIMENSION au moment de son televersement. Le
    revalider ne prouverait rien et risquerait de rejeter une image
    parfaitement bonne si les regles ont change depuis.
    """
    import io

    from PIL import Image

    from app.config import settings

    with Image.open(io.BytesIO(raw)) as im:
        if im.mode != "RGB":
            im = im.convert("RGB")
        dim = settings.IMAGE_THUMB_DIMENSION
        im.thumbnail((dim, dim), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        im.save(
            out,
            format="JPEG",
            quality=settings.IMAGE_THUMB_QUALITY,
            optimize=True,
        )
        return ProcessedImage(
            bytes=raw,
            content_type="image/jpeg",
            extension=".jpg",
            thumb_bytes=out.getvalue(),
        )


async def executer(essai: bool) -> int:
    storage = get_storage()

    async with SessionLocal() as db:
        cartes = list(
            await db.scalars(
                select(Card).where(Card.thumb_key.is_(None)).order_by(Card.created_at)
            )
        )

        if not cartes:
            print("Aucune carte sans vignette : rien a faire.")
            return 0

        print(f"{len(cartes)} carte(s) sans vignette.")
        if essai:
            for c in cartes[:10]:
                print(f"  - {c.label}  ({c.object_key})")
            if len(cartes) > 10:
                print(f"  ... et {len(cartes) - 10} autre(s)")
            print("\n--essai : rien n'a ete ecrit.")
            return 0

        faits = 0
        echecs = 0
        octets_avant = 0
        octets_apres = 0

        for carte in cartes:
            try:
                raw = await storage.read(carte.object_key)
            except Exception as e:
                print(f"  ! {carte.label} : original illisible ({e})")
                echecs += 1
                continue

            try:
                traitee = _vignette_depuis(raw)
            except Exception as e:
                print(f"  ! {carte.label} : reduction impossible ({e})")
                echecs += 1
                continue

            # Stockage d'abord, base ensuite (cf. bandeau).
            cle = await storage.save(
                str(carte.game_id),
                traitee.thumb_bytes,
                traitee.content_type,
                traitee.extension,
            )
            carte.thumb_key = cle
            await db.commit()

            octets_avant += len(raw)
            octets_apres += len(traitee.thumb_bytes)
            faits += 1
            if faits % 20 == 0:
                print(f"  {faits}/{len(cartes)}...")

        print(f"\nVignettes creees : {faits}")
        if echecs:
            print(f"Echecs           : {echecs} (cartes laissees sans vignette)")
        if faits:
            print(
                f"Poids de la grille : {octets_avant / 1024:.0f} Ko -> "
                f"{octets_apres / 1024:.0f} Ko "
                f"(divise par {octets_avant / max(octets_apres, 1):.1f})"
            )
        return 1 if echecs else 0


def main() -> int:
    p = argparse.ArgumentParser(
        description="Genere les vignettes manquantes des cartes existantes.",
    )
    p.add_argument(
        "--essai",
        action="store_true",
        help="annonce ce qui serait fait, sans rien ecrire",
    )
    args = p.parse_args()
    return asyncio.run(executer(args.essai))


if __name__ == "__main__":
    sys.exit(main())
