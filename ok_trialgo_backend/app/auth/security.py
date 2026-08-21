# =============================================================
# FICHIER : app/auth/security.py
# ROLE    : Hash / verification mot de passe (bcrypt via passlib)
# =============================================================
#
# Pourquoi bcrypt :
#   - Resistant aux GPU/ASIC (work factor ajustable)
#   - Salt automatique inclus dans le hash
#   - Standard mature, audite
#
# On expose deux fonctions :
#   - hash_password(plain)    -> "$2b$12$..."  (60 chars)
#   - verify_password(plain, hash) -> bool
# =============================================================

from passlib.context import CryptContext

# rounds=12 : bon compromis (sur Pi 4 ~150ms par hash).
_pwd_ctx = CryptContext(schemes=["bcrypt"], bcrypt__rounds=12, deprecated="auto")


def hash_password(plain: str) -> str:
    return _pwd_ctx.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return _pwd_ctx.verify(plain, hashed)
