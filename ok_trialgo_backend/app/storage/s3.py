# =============================================================
# FICHIER : app/storage/s3.py
# ROLE    : Implementation CardStorage sur S3 / MinIO via aioboto3
# =============================================================
#
# Pourquoi aioboto3 : version async de boto3, compatible API S3
# standard (donc MinIO en dev + AWS / R2 / Wasabi en prod sans
# changer une ligne).
#
# Strategie URL :
#   - bucket public => on retourne juste l'URL HTTP non signee
#     (avec PUBLIC_ENDPOINT pour que le client externe puisse lire)
#   - bucket prive  => presigned_url() (uncomment ligne signee)
#
# Pour TRIALGO on choisit le bucket public read-only (anonymous
# download policy posee par create_bucket job dans docker-compose).
# C'est aligne avec "les cartes sont publiques en jeu".
# =============================================================

import uuid

import aioboto3

from ..config import settings
from .base import CardStorage


class S3CardStorage(CardStorage):
    def __init__(self) -> None:
        self._session = aioboto3.Session()

    def _client(self):
        # Context manager : aioboto3 attend qu'on entre/sorte.
        return self._session.client(
            "s3",
            endpoint_url=settings.S3_ENDPOINT_URL,
            aws_access_key_id=settings.S3_ACCESS_KEY,
            aws_secret_access_key=settings.S3_SECRET_KEY,
            region_name=settings.S3_REGION,
        )

    async def save(
        self,
        game_id: str,
        content: bytes,
        content_type: str,
        extension: str,
    ) -> str:
        key = f"{game_id}/{uuid.uuid4()}{extension}"
        async with self._client() as s3:
            await s3.put_object(
                Bucket=settings.S3_BUCKET,
                Key=key,
                Body=content,
                ContentType=content_type,
                # 1 an de cache : object_key unique = cache safe.
                CacheControl="public, max-age=31536000, immutable",
            )
        return key

    async def read(self, object_key: str) -> bytes:
        async with self._client() as s3:
            reponse = await s3.get_object(
                Bucket=settings.S3_BUCKET, Key=object_key
            )
            # Le corps est un flux : il faut le lire ET le fermer
            # avant de sortir du client, sinon la connexion reste
            # retenue jusqu'au ramasse-miettes.
            async with reponse["Body"] as flux:
                return await flux.read()

    async def delete(self, object_key: str) -> None:
        async with self._client() as s3:
            await s3.delete_object(Bucket=settings.S3_BUCKET, Key=object_key)

    async def public_url(self, object_key: str) -> str:
        # Bucket public : URL directe via le PUBLIC_ENDPOINT
        # (qui doit etre l'endpoint visible depuis l'exterieur,
        #  ex localhost:9000 en dev, https://files.trialgo.io en prod).
        return f"{settings.S3_PUBLIC_ENDPOINT_URL}/{settings.S3_BUCKET}/{object_key}"

        # Variante presignee si tu veux un acces controle :
        # async with self._client() as s3:
        #     return await s3.generate_presigned_url(
        #         "get_object",
        #         Params={"Bucket": settings.S3_BUCKET, "Key": object_key},
        #         ExpiresIn=3600,
        #     )
