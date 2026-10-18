# =============================================================
# FICHIER : app/site/schemas.py
# ROLE    : Forme du document "accueil" de la vitrine
# =============================================================
#
# TOUS LES CHAMPS SONT OPTIONNELS
# -------------------------------
# La vitrine embarque son contenu dans le HTML statique : c'est ce
# que voient un robot d'indexation, un visiteur sans JavaScript, ou
# tout le monde si l'API est injoignable. Le document publie ici ne
# fait que REMPLACER ce qu'il renseigne. Un champ absent ou vide =
# le texte du HTML reste en place. On peut donc publier un document
# partiel sans jamais "vider" la page.
#
# extra="forbid" PARTOUT
# ----------------------
# Une faute de frappe dans une cle ("titre_acent") serait sinon
# acceptee puis ignoree par la vitrine : l'administrateur verrait
# "publie" et rien ne changerait a l'ecran, sans aucun indice. Le
# refus (422) rend l'erreur visible au moment ou elle est commise.
#
# LES LONGUEURS MAXIMALES
# -----------------------
# Ce ne sont pas des limites techniques mais des garde-fous de mise
# en page : un titre de hero de 2 000 caracteres casserait l'ecran
# d'accueil sur telephone. Elles sont reprises a l'identique par le
# studio, qui les affiche en compteur sous chaque champ.
# =============================================================

from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, HttpUrl, field_validator


class _Strict(BaseModel):
    """Base commune : refuse toute cle inconnue."""

    model_config = ConfigDict(extra="forbid")


class HeroContent(_Strict):
    surtitre: str | None = Field(default=None, max_length=80)
    titre: str | None = Field(default=None, max_length=120)
    titre_accent: str | None = Field(default=None, max_length=120)
    accroche: str | None = Field(default=None, max_length=400)
    bouton_principal: str | None = Field(default=None, max_length=40)
    bouton_secondaire: str | None = Field(default=None, max_length=40)


class GalleryItem(_Strict):
    # HttpUrl refuse javascript:, data: et les chemins relatifs : la
    # vitrine pose cette valeur dans un <img src>, elle doit etre une
    # vraie URL http(s). Elle est stockee sous sa forme normalisee
    # (model_dump en mode json la rend en chaine).
    image_url: Annotated[HttpUrl, Field(max_length=500)]
    nom: str | None = Field(default=None, max_length=40)
    code: str | None = Field(default=None, max_length=8)


class SectionContent(_Strict):
    titre: str | None = Field(default=None, max_length=120)
    texte: str | None = Field(default=None, max_length=600)


class SectionsContent(_Strict):
    # Liste FERMEE des sections editables : ce sont celles dont la
    # vitrine sait remplacer le titre et le texte. En ajouter une ici
    # sans l'ajouter dans la page n'aurait aucun effet visible.
    demo: SectionContent | None = None
    regle: SectionContent | None = None
    deck: SectionContent | None = None
    collectif: SectionContent | None = None
    telecharger: SectionContent | None = None


class AccueilContent(_Strict):
    hero: HeroContent | None = None
    # [0..2] = l'eventail du hero ; la totalite = bandeau + grille.
    galerie: list[GalleryItem] | None = Field(default=None, max_length=24)
    sections: SectionsContent | None = None

    @field_validator("galerie")
    @classmethod
    def _galerie_non_vide_ou_absente(
        cls, v: list[GalleryItem] | None
    ) -> list[GalleryItem] | None:
        # Une liste vide est ramenee a "absente" : la vitrine garde
        # alors ses cartes statiques au lieu d'afficher un trou.
        return v or None


class SiteContentIn(_Strict):
    """Corps du PUT."""

    contenu: AccueilContent


class SiteContentOut(BaseModel):
    """Reponse de tous les GET et du PUT."""

    contenu: dict
    maj_le: datetime | None


class SiteImageOut(BaseModel):
    object_key: str
    url: str
