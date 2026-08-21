# =============================================================
# FICHIER : app/db.py
# ROLE    : SQLAlchemy async engine + Base declarative + session
# =============================================================
#
# Pattern moderne SQLAlchemy 2.0 :
#   - DeclarativeBase pour les modeles
#   - async_engine + async_sessionmaker pour les sessions async
#   - dependency get_db() utilisee par les routes FastAPI :
#       async def route(..., db: AsyncSession = Depends(get_db)): ...
#
# La session est unique par requete HTTP : ouverture en debut,
# fermeture en fin. Si exception -> rollback automatique.
# =============================================================

from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from .config import settings


# Base declarative : toutes les tables herriteront d'ici.
# (alembic detecte les modeles via cette Base, voir alembic/env.py)
class Base(DeclarativeBase):
    pass


# Engine async : pool de connexions vers Postgres.
# echo=False en prod ; mettre True pour debug SQL en dev.
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    pool_pre_ping=True,   # detecte les connexions cassees, important
    pool_size=10,
    max_overflow=20,
)

# Factory de sessions : expire_on_commit=False = on peut lire les
# attributs apres commit sans re-fetch (gain de perf + ergonomie).
SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency FastAPI : injecte une session par requete."""
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        # Pas de commit auto : chaque route choisit (sec contre les
        # writes accidentels).
