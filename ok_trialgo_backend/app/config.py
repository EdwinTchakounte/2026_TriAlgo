# =============================================================
# FICHIER : app/config.py
# ROLE    : Centraliser la configuration via Pydantic Settings
# =============================================================
#
# Pydantic-Settings lit automatiquement :
#   1. Variables d'environnement (cas dans Docker)
#   2. Fichier .env a la racine (cas dev local)
#
# L'avantage face a `os.environ.get(...)` :
#   - Typage automatique (int, bool, str, list[str]...)
#   - Validation au demarrage (echec rapide si var manque)
#   - Une seule source de verite pour la config
#
# Utilisation : on importe `settings = Settings()` une fois et
# on accede via `settings.JWT_SECRET`, `settings.DATABASE_URL` etc.
# =============================================================

from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Pydantic-Settings : ou chercher la config + format.
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # ---- API ----
    PUBLIC_BASE_URL: str = "http://localhost:8000"

    # ---- DB ----
    DATABASE_URL: str         # asyncpg
    ALEMBIC_DATABASE_URL: str # psycopg2 sync

    # ---- JWT ----
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 1440
    JWT_REFRESH_EXPIRE_DAYS: int = 30

    # ---- Storage ----
    STORAGE_BACKEND: Literal["local", "s3"] = "s3"
    LOCAL_STORAGE_DIR: str = "/data/cards"

    # ---- S3 / MinIO ----
    S3_ENDPOINT_URL: str = "http://minio:9000"
    S3_PUBLIC_ENDPOINT_URL: str = "http://localhost:9000"
    S3_ACCESS_KEY: str = "minio_dev"
    S3_SECRET_KEY: str = "minio_dev_secret_change_me"
    S3_BUCKET: str = "trialgo-cards"
    S3_REGION: str = "us-east-1"

    # ---- Upload limits ----
    MAX_UPLOAD_BYTES: int = 5 * 1024 * 1024
    ALLOWED_MIME: str = "image/jpeg,image/png,image/webp"
    IMAGE_MAX_DIMENSION: int = 1024
    IMAGE_JPEG_QUALITY: int = 85

    # ---- Limitation de debit ----
    # Voir app/core/rate_limit.py. Desactivable pour les tests, jamais
    # en production : c'est la seule protection contre la force brute
    # sur les mots de passe et l'enumeration des codes de vente.
    RATE_LIMIT_ENABLED: bool = True

    # Derriere un reverse proxy (Caddy en production), l'IP vue par
    # l'API est celle du proxy : sans ce drapeau, tous les clients
    # partagent le meme compteur et le premier a depasser la limite
    # bloque tous les autres.
    #
    # A laisser sur False en dev (acces direct), et a passer a True
    # des qu'un proxy est devant. startup_checks.py signale l'oubli.
    TRUST_PROXY_HEADERS: bool = False

    # ---- CORS ----
    CORS_ALLOWED_ORIGINS: str = "http://localhost:5173,http://localhost:8080"

    # ---- Email (Brevo / API REST) ----
    # Si BREVO_API_KEY est vide, l'envoi est court-circuite (log
    # only) : utile en dev local sans cle. En prod, la cle est
    # obligatoire et un envoi log-only doit etre detecte.
    BREVO_API_KEY: str = ""
    BREVO_SENDER_EMAIL: str = "noreply@trialgo.app"
    BREVO_SENDER_NAME: str = "TRIALGO"
    # URL frontale (app web/landing) servant a construire les
    # liens reset/confirm dans les emails. En dev : localhost.
    APP_FRONTEND_URL: str = "http://localhost:5173"

    # Schema d'URL propre a l'application mobile, utilise par la page
    # de rebond /reset-password pour rendre la main a l'app :
    #     trialgo://reset-password?token=...
    # Doit rester aligne sur le schema declare cote Flutter
    # (deep_link_service.dart) et dans les manifestes Android/iOS.
    APP_DEEP_LINK_SCHEME: str = "trialgo"
    # TTL des tokens email (confirm/reset). 1h pour reset (best
    # practice secu) ; 48h pour confirm (un user peut tarder).
    EMAIL_TOKEN_TTL_RESET_MINUTES: int = 60
    EMAIL_TOKEN_TTL_CONFIRM_MINUTES: int = 60 * 48

    # ---- Helpers derivés ----
    @property
    def allowed_mime_set(self) -> set[str]:
        return {m.strip() for m in self.ALLOWED_MIME.split(",") if m.strip()}

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.CORS_ALLOWED_ORIGINS.split(",") if o.strip()]


# Cache : on instancie Settings UNE FOIS au boot.
# Si on relit .env il faut redemarrer le process (intentionnel).
@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]


# Acces direct depuis le reste du code.
settings = get_settings()
