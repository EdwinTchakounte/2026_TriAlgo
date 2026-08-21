# =============================================================
# FICHIER : app/core/startup_checks.py
# ROLE    : Detecter au demarrage une config de dev laissee en prod
# =============================================================
#
# POURQUOI CE FICHIER EXISTE
# --------------------------
# Certaines variables d'environnement ont une valeur par defaut qui
# fonctionne parfaitement en local et qui casse silencieusement en
# production. Le cas le plus vicieux est S3_PUBLIC_ENDPOINT_URL :
#
#   - En local il vaut "http://localhost:9000" et tout marche.
#   - Le backend l'insere TEL QUEL dans chaque `image_url` renvoyee
#     aux clients.
#   - Sur un telephone, "localhost" designe le telephone lui-meme.
#     Le mobile va donc chercher les cartes chez lui, ne trouve rien,
#     et affiche des images cassees.
#   - Cote serveur, aucune erreur : les logs sont vides, l'API repond
#     200 partout. Le bug est invisible depuis le backend.
#
# Une panne silencieuse coute beaucoup plus cher a diagnostiquer
# qu'un demarrage bruyant. Ce module transforme donc ces pieges en
# avertissements explicites dans les logs au boot.
#
# CHOIX : AVERTIR, PAS BLOQUER
# ----------------------------
# Ces controles n'empechent PAS l'app de demarrer. Bloquer casserait
# le dev local, les tests et la CI, qui utilisent legitimement ces
# valeurs. On emet des logs de niveau WARNING / CRITICAL, tres
# visibles, et on laisse tourner.
# =============================================================

import logging

from ..config import settings

# Logger dedie : les messages apparaissent prefixes par le nom du
# module, donc reperables dans les logs agreges (Docker, Loki...).
logger = logging.getLogger("trialgo.startup")


# Valeurs livrees dans .env.example. Les retrouver en production
# signifie que le fichier n'a pas ete adapte au deploiement.
_SECRETS_PAR_DEFAUT = {
    "JWT_SECRET": "change_me_with_a_long_random_string_at_least_48_chars",
    "S3_ACCESS_KEY": "minio_dev",
    "S3_SECRET_KEY": "minio_dev_secret_change_me",
}

# Hotes qui n'ont de sens que sur la machine du developpeur.
# 10.0.2.2 est l'alias que l'emulateur Android donne a son hote.
_HOTES_LOCAUX = ("localhost", "127.0.0.1", "0.0.0.0", "10.0.2.2", "minio:", "://minio")


def _est_local(url: str) -> bool:
    """Vrai si l'URL pointe vers la machine locale ou un hote Docker interne.

    On teste la presence d'un des marqueurs plutot qu'un parsing strict :
    l'objectif est de lever un doute, pas de valider une URL.
    """
    minuscule = url.lower()
    return any(marqueur in minuscule for marqueur in _HOTES_LOCAUX)


def collecter_problemes_de_configuration() -> list[str]:
    """Retourne la liste des problemes de config detectes.

    Fonction pure (elle ne logue rien, ne leve rien) : elle est donc
    directement testable, et reutilisable par un futur endpoint de
    diagnostic reserve aux admins.
    """
    problemes: list[str] = []

    # ---- 1. Secrets laisses a leur valeur d'exemple ----
    for nom, valeur_exemple in _SECRETS_PAR_DEFAUT.items():
        if getattr(settings, nom, None) == valeur_exemple:
            problemes.append(
                f"{nom} a encore sa valeur d'exemple. "
                f"A regenerer avant toute mise en ligne."
            )

    # ---- 2. URL publique du stockage des cartes ----
    # C'est le point le plus important : cette valeur voyage jusque
    # dans les clients mobiles via chaque champ image_url.
    if settings.STORAGE_BACKEND == "s3" and _est_local(settings.S3_PUBLIC_ENDPOINT_URL):
        problemes.append(
            f"S3_PUBLIC_ENDPOINT_URL vaut '{settings.S3_PUBLIC_ENDPOINT_URL}', "
            f"une adresse locale. Elle est recopiee dans chaque image_url "
            f"renvoyee aux clients : les mobiles ne pourront PAS charger les "
            f"cartes. Attendu en production : une URL publique en https."
        )

    # ---- 2bis. Barre oblique finale sur l'URL publique du stockage ----
    # public_url() construit chaque URL par simple concatenation :
    #
    #     f"{S3_PUBLIC_ENDPOINT_URL}/{S3_BUCKET}/{object_key}"
    #
    # Une barre finale dans la variable produit donc un double
    # separateur ("https://.../files//trialgo-cards/..."). Certains
    # frontaux normalisent, d'autres non, et MinIO interprete le
    # segment vide comme un nom de bucket : les images repondent 404
    # alors que tout le reste fonctionne. Erreur de saisie facile,
    # symptome deroutant, donc detection explicite.
    if settings.S3_PUBLIC_ENDPOINT_URL.endswith("/"):
        problemes.append(
            f"S3_PUBLIC_ENDPOINT_URL vaut '{settings.S3_PUBLIC_ENDPOINT_URL}' "
            f"et se termine par une barre oblique. Chaque image_url "
            f"contiendra un double separateur et les cartes ne se "
            f"chargeront pas. Retirer la barre finale."
        )

    # ---- 3. URL publique de l'API (utilisee en STORAGE_BACKEND=local) ----
    if settings.STORAGE_BACKEND == "local" and _est_local(settings.PUBLIC_BASE_URL):
        problemes.append(
            f"PUBLIC_BASE_URL vaut '{settings.PUBLIC_BASE_URL}', une adresse "
            f"locale. En STORAGE_BACKEND=local c'est elle qui construit les "
            f"image_url servies aux clients."
        )

    # ---- 4. Origines CORS ----
    # Sans l'origine exacte du front web dans cette liste, le navigateur
    # rejette les requetes des la phase preflight (reponse 400).
    if all(_est_local(origine) for origine in settings.cors_origins_list):
        problemes.append(
            "CORS_ALLOWED_ORIGINS ne contient que des origines locales. "
            "L'app web deployee recevra un echec au preflight. Ajouter "
            "l'origine exacte du front (schema + domaine + port)."
        )

    # ---- 5. Liens de rebond des emails (reset / confirmation) ----
    # Depuis l'ajout de app/links/, ces deux liens sont bati sur
    # PUBLIC_BASE_URL et non plus sur APP_FRONTEND_URL : les pages
    # qui les traitent sont servies par l'API elle-meme. C'est donc
    # PUBLIC_BASE_URL qu'il faut controler ici, quel que soit le
    # backend de stockage (le controle 3 ne la verifie qu'en mode
    # local).
    if _est_local(settings.PUBLIC_BASE_URL):
        problemes.append(
            f"PUBLIC_BASE_URL vaut '{settings.PUBLIC_BASE_URL}'. C'est elle "
            f"qui construit les liens de confirmation d'adresse et de "
            f"reinitialisation de mot de passe : ils seront inutilisables "
            f"pour les destinataires."
        )

    # ---- 5bis. Liens de navigation des emails ----
    # APP_FRONTEND_URL sert encore aux liens non critiques (classement,
    # jeu, administration). Une valeur locale les rend inertes, sans
    # bloquer aucun parcours : avertissement de moindre gravite.
    if _est_local(settings.APP_FRONTEND_URL):
        problemes.append(
            f"APP_FRONTEND_URL vaut '{settings.APP_FRONTEND_URL}'. Les liens "
            f"de navigation des emails (classement, jeu) pointeront vers une "
            f"adresse locale. Sans effet sur la connexion ni sur la "
            f"reinitialisation de mot de passe, qui passent par "
            f"PUBLIC_BASE_URL."
        )

    # ---- 6. Envoi d'emails desactive ----
    if not settings.BREVO_API_KEY:
        problemes.append(
            "BREVO_API_KEY est vide : les emails ne sont pas envoyes, "
            "seulement journalises (mode DRY_RUN). Confirmation de compte et "
            "reinitialisation de mot de passe seront inoperantes."
        )

    return problemes


def journaliser_controles_de_demarrage() -> None:
    """Ecrit le resultat des controles dans les logs, au boot.

    Appelee depuis le lifespan de l'app (app/main.py).
    """
    problemes = collecter_problemes_de_configuration()

    if not problemes:
        logger.info("Controles de configuration : aucun probleme detecte.")
        return

    # On encadre le bloc pour qu'il soit impossible a rater dans un flot
    # de logs de demarrage.
    logger.critical("=" * 70)
    logger.critical(
        "CONFIGURATION INCOMPLETE POUR LA PRODUCTION (%d point(s))", len(problemes)
    )
    logger.critical("=" * 70)
    for index, probleme in enumerate(problemes, start=1):
        logger.critical("  %d. %s", index, probleme)
    logger.critical("=" * 70)
    logger.critical(
        "Normal en developpement local. En production, corriger le .env "
        "puis redemarrer le conteneur."
    )
