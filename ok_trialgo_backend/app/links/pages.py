# =============================================================
# FICHIER : app/links/pages.py
# ROLE    : Gabarits HTML des pages de rebond (mot de passe, email)
# =============================================================
#
# Pourquoi du HTML ecrit a la main plutot que Jinja2, deja present
# dans le projet pour les emails : l'environnement Jinja de
# app/mail est configure sur son propre repertoire de gabarits, et
# ces deux pages n'ont ni boucle, ni condition, ni heritage. Une
# f-string suffit et evite un second chargeur de gabarits.
#
# Contraintes de rendu volontaires :
#   - AUCUNE ressource externe (police, feuille de style, script).
#     Ces pages s'ouvrent souvent depuis le navigateur integre d'une
#     application de messagerie, sur un reseau mediocre. Tout est
#     inline, la page pese quelques kilo-octets.
#   - Rendu correct sans JavaScript. Le seul script present tente
#     d'ouvrir l'application ; s'il ne s'execute pas, le bouton
#     manuel reste la et fait exactement la meme chose.
# =============================================================

from html import escape

# Palette reprise du studio admin (app_colors.dart) pour que les
# pages ne paraissent pas etrangeres au produit.
_STYLE = """
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh;
    display: flex; align-items: center; justify-content: center;
    background: #121419; color: #F3F5F9;
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    padding: 24px; line-height: 1.55;
  }
  .carte {
    background: #1C1F26; border: 1px solid #323845; border-radius: 16px;
    padding: 32px 28px; max-width: 460px; width: 100%; text-align: center;
  }
  .pastille { font-size: 44px; line-height: 1; margin-bottom: 12px; }
  h1 { font-size: 21px; margin: 0 0 10px; }
  p { color: #9AA1AE; font-size: 15px; margin: 0 0 16px; }
  .bouton {
    display: inline-block; background: #FF6B35; color: #fff;
    text-decoration: none; padding: 13px 26px; border-radius: 10px;
    font-weight: 600; font-size: 15px; margin-top: 4px;
  }
  .discret { font-size: 13px; color: #6B7280; margin-top: 22px; }
  code {
    background: #252932; padding: 3px 7px; border-radius: 5px;
    font-size: 12px; word-break: break-all; color: #9AA1AE;
  }
  .succes { color: #10B981; } .echec { color: #EF4444; }
"""


def _page(*, titre: str, corps: str) -> str:
    """Enveloppe commune aux deux pages."""
    return (
        "<!doctype html><html lang=\"fr\"><head>"
        "<meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        f"<title>{escape(titre)}</title>"
        f"<style>{_STYLE}</style>"
        "</head><body><div class=\"carte\">"
        f"{corps}"
        "</div></body></html>"
    )


# -------------------------------------------------------------
# PAGE 1 : rebond vers l'application pour le mot de passe
# -------------------------------------------------------------
def page_reinitialisation(*, lien_application: str, jeton: str) -> str:
    """Page qui renvoie le porteur du jeton vers l'application.

    POURQUOI UNE PAGE INTERMEDIAIRE
    -------------------------------
    Le jeton doit atterrir dans l'application mobile, seul endroit
    ou le nouveau mot de passe peut etre saisi. Un lien
    `trialgo://...` place directement dans un courriel est peu
    fiable : beaucoup de clients de messagerie refusent d'afficher,
    voire suppriment, les liens dont le schema leur est inconnu.

    On envoie donc un lien https ordinaire, que tout client affiche,
    et c'est cette page qui effectue la bascule vers le schema
    applicatif -- automatiquement, puis manuellement si besoin.
    """
    lien = escape(lien_application, quote=True)
    return _page(
        titre="Reinitialisation du mot de passe - TRIALGO",
        corps=(
            "<div class=\"pastille\">&#128273;</div>"
            "<h1>Ouvrir TRIALGO</h1>"
            "<p>Nous allons ouvrir l'application pour que vous puissiez "
            "choisir un nouveau mot de passe.</p>"
            f"<a class=\"bouton\" href=\"{lien}\">Choisir un nouveau mot de passe</a>"
            "<p class=\"discret\">Si rien ne se passe, c'est que TRIALGO n'est "
            "pas installe sur cet appareil. Ouvrez ce lien depuis le telephone "
            "ou vous jouez.<br><br>"
            f"Votre code de reinitialisation :<br><code>{escape(jeton)}</code></p>"
            # La tentative automatique se fait apres l'affichage, pour
            # que le bouton soit deja visible si la bascule echoue.
            f"<script>setTimeout(function(){{location.href={lien_application!r}}},400)</script>"
        ),
    )


# -------------------------------------------------------------
# PAGE 2 : resultat de la confirmation d'adresse
# -------------------------------------------------------------
def page_confirmation(*, reussi: bool, message: str) -> str:
    """Page affichee apres consommation du jeton de confirmation."""
    if reussi:
        return _page(
            titre="Adresse confirmee - TRIALGO",
            corps=(
                "<div class=\"pastille succes\">&#10003;</div>"
                "<h1>Adresse confirmee</h1>"
                f"<p>{escape(message)}</p>"
                "<p class=\"discret\">Vous pouvez fermer cette page et "
                "retourner dans l'application.</p>"
            ),
        )
    return _page(
        titre="Lien invalide - TRIALGO",
        corps=(
            "<div class=\"pastille echec\">&#33;</div>"
            "<h1>Ce lien n'est plus valable</h1>"
            f"<p>{escape(message)}</p>"
            "<p class=\"discret\">Depuis l'application, demandez l'envoi "
            "d'un nouveau lien de confirmation.</p>"
        ),
    )
