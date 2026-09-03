# =============================================================
# Dockerfile  -  image de production pour l'API TRIALGO
# =============================================================
# Multi-stage : on installe les deps dans un stage builder puis
# on copie uniquement les wheels dans l'image finale. Resultat :
# image legere (~200 MB) sans gcc/headers.
#
# python:3.12-slim suffit (debian-based). On exclu python-magic
# qui necessite libmagic1 (-> apt install dans final stage).
# =============================================================

# ---------- STAGE 1 : build wheels ----------
FROM python:3.12-slim AS builder

# build-essential : compile asyncpg + bcrypt en wheel C natif
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY pyproject.toml .
# Genere requirements.txt depuis pyproject.toml (sans dev-deps).
RUN pip install --no-cache-dir pip-tools \
    && pip-compile --quiet --output-file requirements.txt pyproject.toml \
    && pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---------- STAGE 2 : runtime ----------
FROM python:3.12-slim

# libmagic1 : requis par python-magic (detection MIME des images).
# libpq5    : runtime postgres (asyncpg n'en a pas besoin mais alembic via psycopg2 oui).
RUN apt-get update && apt-get install -y --no-install-recommends \
        libmagic1 \
        libpq5 \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/*.whl \
    && rm -rf /wheels

COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini ./
# Scripts d'exploitation lances via `docker compose exec api`
# (generation des vignettes, import de referentiel). Ils importent
# `app`, donc ils ont besoin de l'environnement Python de l'image.
COPY scripts/ ./scripts/

# Utilisateur non-root (defense en profondeur).
RUN useradd --create-home --uid 1001 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsSL http://localhost:8000/healthz || exit 1

# Production : uvicorn workers selon CPU count. En dev, le compose
# overrides cette commande avec --reload pour le hot-reload.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
