# =============================================================
# FICHIER : alembic/env.py
# ROLE    : Hook Alembic  -  branche sur SQLAlchemy Base + .env
# =============================================================
#
# Alembic execute ce module pour decouvrir les modeles (target_metadata)
# et la connexion DB. On charge l'URL depuis settings (= .env) plutot
# que depuis alembic.ini, pour ne pas dupliquer la config.
# =============================================================

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

# Import explicite des modeles : oblige SQLAlchemy a peupler Base.metadata.
# autogenerate ne detecte que les tables connues de Base.metadata.
from app.auth.models import User  # noqa: F401
from app.cards.models import Card  # noqa: F401
from app.config import settings
from app.db import Base
from app.games.models import Game  # noqa: F401
from app.nodes.models import GameNode  # noqa: F401

config = context.config
# Injecte l'URL DB depuis .env (driver psycopg2 sync requis par Alembic).
config.set_main_option("sqlalchemy.url", settings.ALEMBIC_DATABASE_URL)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
