#!/usr/bin/env python3
# =============================================================
# FICHIER : scripts/referentiel.py
# ROLE    : Valider et importer un referentiel de jeu MIXALGO
# =============================================================
#
# POURQUOI CE SCRIPT EXISTE
# -------------------------
# Le graphe d'un jeu etait jusqu'ici saisi a la main dans le studio,
# noeud par noeud, ou decrit dans un dictionnaire illustre. Les deux
# approches ont le meme defaut : elles repetent l'information.
#
# Le dictionnaire (dictionnaire/dictionnaire.jpeg) est un INDEX --
# chaque trio y figure une fois par carte concernee, donc 2 a 3 fois.
# Maintenu a la main, il a fini par se contredire : le meme couple de
# parents y donnait deux enfants differents a deux endroits, et deux
# couples y etaient ecrits dans les deux sens.
#
# Le referentiel YAML inverse le sens : il est la SOURCE, chaque trio
# n'y apparait qu'une fois, et le dictionnaire s'en deduit.
#
# CE QUE CE SCRIPT GARANTIT
# -------------------------
# `valider` refuse tout ce que la base ne pourrait pas savoir refuser
# elle-meme, ou qu'elle refuserait trop tard (a la 40e insertion, avec
# la moitie du graphe deja ecrite).
#
# `importer` calcule depth / parent_node_id / node_index -- jamais
# ecrits a la main -- et passe par l'API, donc les invariants du
# graphe sont verifies par le backend et non contournes par un INSERT
# direct.
#
# USAGE
# -----
#   python3 scripts/referentiel.py valider referentiels/mixalgo-savane.yml
#
#   python3 scripts/referentiel.py importer referentiels/mixalgo-savane.yml \
#       --api http://localhost:8000 \
#       --email admin@exemple.com \
#       --images /chemin/vers/les/images
#
#   python3 scripts/referentiel.py dictionnaire referentiels/mixalgo-savane.yml \
#       --sortie /tmp/dictionnaire.html
#
# Le mot de passe n'est JAMAIS passe en argument (il resterait dans
# l'historique du shell et dans la liste des processus) : il est
# demande au clavier, ou lu dans la variable TRIALGO_ADMIN_PASSWORD.
# =============================================================

from __future__ import annotations

import argparse
import getpass
import os
import sys
from collections import defaultdict
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit(
        "PyYAML est requis.\n"
        "  pip install pyyaml\n"
        "  (ou lancer depuis le conteneur : "
        "docker compose exec api python scripts/referentiel.py ...)"
    )


PROFONDEUR_MAX = 5


# =============================================================
# LECTURE
# =============================================================

class Referentiel:
    """Un referentiel charge, avec ses index deja construits."""

    def __init__(self, donnees: dict, chemin: Path):
        self.chemin = chemin
        self.jeu: str = donnees.get("jeu", "")
        self.libelle: str = donnees.get("libelle", self.jeu)
        self.version = donnees.get("version", 1)
        self.cartes: dict = donnees.get("cartes") or {}
        self.trios: list = donnees.get("trios") or []

        # Index : id de trio -> trio
        self.par_id: dict[str, dict] = {}
        for t in self.trios:
            if isinstance(t, dict) and "id" in t:
                self.par_id[str(t["id"])] = t

    @classmethod
    def charger(cls, chemin: Path) -> "Referentiel":
        with chemin.open(encoding="utf-8") as f:
            donnees = yaml.safe_load(f)
        if not isinstance(donnees, dict):
            raise SystemExit(f"{chemin} : le fichier doit contenir un mapping YAML")
        return cls(donnees, chemin)

    # ---------------------------------------------------------
    # Les trois cartes d'un trio.
    #
    # Pour une racine, elles sont ecrites. Pour un enfant, la
    # premiere est l'enfant du trio parent -- c'est tout le sens du
    # chainage : la receptrice d'un noeud devient l'emettrice du
    # suivant.
    # ---------------------------------------------------------
    def cartes_du_trio(self, trio: dict) -> tuple[str, str, str] | None:
        """(parent1, parent2, enfant), ou None si le trio est mal forme."""
        enfant = trio.get("enfant")
        if enfant is None:
            return None
        if "parents" in trio:
            parents = trio.get("parents")
            if not isinstance(parents, list) or len(parents) != 2:
                return None
            return (str(parents[0]), str(parents[1]), str(enfant))
        parent_id = trio.get("depuis")
        avec = trio.get("avec")
        if parent_id is None or avec is None:
            return None
        parent = self.par_id.get(str(parent_id))
        if parent is None:
            return None
        herite = parent.get("enfant")
        if herite is None:
            return None
        return (str(herite), str(avec), str(enfant))

    def profondeur(self, trio: dict, _vus: tuple = ()) -> int:
        """Profondeur du trio dans sa chaine (1 pour une racine)."""
        if "parents" in trio:
            return 1
        tid = str(trio.get("id"))
        if tid in _vus:
            raise ValueError(f"cycle de chainage : {' -> '.join(_vus + (tid,))}")
        parent = self.par_id.get(str(trio.get("depuis")))
        if parent is None:
            raise ValueError(f"{tid} : `depuis` pointe un trio inconnu")
        return 1 + self.profondeur(parent, _vus + (tid,))


# =============================================================
# VALIDATION
# =============================================================
# Chaque controle repond a une facon concrete de se tromper. On les
# accumule tous avant de rendre la main : corriger une erreur a la
# fois sur 46 trios serait interminable.
# =============================================================

def valider(ref: Referentiel) -> tuple[list[str], list[str]]:
    """Retourne (erreurs, avertissements)."""
    erreurs: list[str] = []
    alertes: list[str] = []

    if not ref.jeu:
        erreurs.append("le champ `jeu` est absent")
    if not ref.cartes:
        erreurs.append("aucune carte declaree")
    if not ref.trios:
        erreurs.append("aucun trio declare")

    # ---- 1. Identifiants de trios : presents et uniques ----
    vus: set[str] = set()
    for i, t in enumerate(ref.trios, start=1):
        if not isinstance(t, dict):
            erreurs.append(f"trio #{i} : ce n'est pas un mapping")
            continue
        tid = t.get("id")
        if tid is None:
            erreurs.append(f"trio #{i} : champ `id` manquant")
            continue
        tid = str(tid)
        if tid in vus:
            erreurs.append(f"trio `{tid}` : identifiant en double")
        vus.add(tid)

    # ---- 2. Forme : racine XOR enfant ----
    # Meme regle que la contrainte CHECK de la table nodes :
    #   (emettrice_id IS NULL) = (parent_node_id IS NOT NULL)
    # On la verifie ici pour donner un message lisible, plutot que
    # de laisser Postgres refuser l'insertion en cours d'import.
    for t in ref.trios:
        if not isinstance(t, dict):
            continue
        tid = t.get("id", "?")
        racine = "parents" in t
        enfant = "depuis" in t or "avec" in t
        if racine and enfant:
            erreurs.append(
                f"trio `{tid}` : `parents` et `depuis`/`avec` ensemble -- "
                "un trio est soit une racine, soit un enfant, jamais les deux"
            )
        elif not racine and not enfant:
            erreurs.append(
                f"trio `{tid}` : ni `parents` ni `depuis`/`avec`"
            )
        elif enfant and ("depuis" not in t or "avec" not in t):
            erreurs.append(
                f"trio `{tid}` : un enfant exige `depuis` ET `avec`"
            )
        if "enfant" not in t:
            erreurs.append(f"trio `{tid}` : champ `enfant` manquant")

    if erreurs:
        return erreurs, alertes          # inutile d'aller plus loin

    # ---- 3. Toutes les cartes citees sont declarees ----
    utilisees: set[str] = set()
    for t in ref.trios:
        trio = ref.cartes_du_trio(t)
        if trio is None:
            erreurs.append(f"trio `{t.get('id')}` : structure illisible")
            continue
        for code in trio:
            utilisees.add(code)
            if code not in ref.cartes:
                erreurs.append(
                    f"trio `{t.get('id')}` : carte `{code}` non declaree "
                    "dans la section `cartes`"
                )

    inutilisees = sorted(set(ref.cartes) - utilisees)
    if inutilisees:
        alertes.append(
            f"{len(inutilisees)} carte(s) declaree(s) mais utilisee(s) dans "
            f"aucun trio : {', '.join(inutilisees)}"
        )

    # ---- 4. |T| = 3 : les trois cartes doivent etre DISTINCTES ----
    # Une carte est neutre, donc rien n'interdit qu'un meme cable
    # serve dans deux noeuds d'une chaine -- c'est meme attendu. Mais
    # a l'interieur d'UN trio, deux slots pointant la meme carte
    # produisent une question ou le joueur voit deux fois la meme
    # image, ou doit deviner une carte deja visible a l'ecran.
    for t in ref.trios:
        trio = ref.cartes_du_trio(t)
        if trio and len(set(trio)) != 3:
            erreurs.append(
                f"trio `{t.get('id')}` : {' + '.join(trio[:2])} = {trio[2]} "
                "-- les trois cartes doivent etre distinctes (regle |T| = 3)"
            )

    # ---- 5. Pas de trio en double ----
    # L'ordre des deux parents ne porte pas de sens pour la fusion :
    # [C9, D8] et [D8, C9] sont le meme trio. On dedoublonne donc sur
    # le couple NON ordonne, sinon le meme trio serait importe deux
    # fois et le joueur le verrait deux fois dans la meme partie.
    par_signature: dict[tuple, list[str]] = defaultdict(list)
    for t in ref.trios:
        trio = ref.cartes_du_trio(t)
        if trio:
            par_signature[(frozenset(trio[:2]), trio[2])].append(str(t.get("id")))
    for (paire, enfant), ids in sorted(
        par_signature.items(), key=lambda x: str(x[1])
    ):
        if len(ids) > 1:
            a, b = sorted(paire)
            erreurs.append(
                f"trios {', '.join(ids)} : {a} + {b} = {enfant} est declare "
                f"{len(ids)} fois (l'ordre des parents ne les distingue pas)"
            )

    # ---- 6. Chainage : cible existante, pas de cycle, profondeur ----
    for t in ref.trios:
        tid = str(t.get("id"))
        if "depuis" in t:
            cible = str(t["depuis"])
            if cible not in ref.par_id:
                erreurs.append(f"trio `{tid}` : `depuis: {cible}` inconnu")
                continue
            if cible == tid:
                erreurs.append(f"trio `{tid}` : se chaine sur lui-meme")
                continue
        try:
            profondeur = ref.profondeur(t)
        except ValueError as e:
            erreurs.append(f"trio `{tid}` : {e}")
            continue
        if profondeur > PROFONDEUR_MAX:
            erreurs.append(
                f"trio `{tid}` : profondeur D{profondeur} -- la base "
                f"n'accepte que D1 a D{PROFONDEUR_MAX}"
            )

    # ---- 7. Alerte : un couple qui engendre plusieurs enfants ----
    # Ce n'est PAS une erreur : la fusion est une relation, un meme
    # couple peut avoir plusieurs enfants, et le jeu sait desormais
    # accepter chacun d'eux comme reponse juste. Mais c'est assez
    # inhabituel pour meriter d'etre signale -- une faute de frappe y
    # ressemble beaucoup.
    enfants_par_couple: dict[frozenset, set[str]] = defaultdict(set)
    for t in ref.trios:
        trio = ref.cartes_du_trio(t)
        if trio:
            enfants_par_couple[frozenset(trio[:2])].add(trio[2])
    for paire, enfants in enfants_par_couple.items():
        if len(enfants) > 1:
            a, b = sorted(paire)
            alertes.append(
                f"{a} + {b} engendre {len(enfants)} enfants "
                f"({', '.join(sorted(enfants))}) -- volontaire ? "
                "les deux seront acceptes comme reponses justes"
            )

    # ---- 8. Alerte : une chaine dont les cartes se repetent ----
    # Pour une chaine de k noeuds, le jeu attend 2k+1 elements
    # DISTINCTS : {E1} u {C1..Ck} u {R1..Rk}. Rien n'interdit qu'une
    # carte y revienne -- elle est neutre, et un cable "miroir" a
    # vocation a servir plusieurs fois. Mais chaque repetition retire
    # des trios generables, car la regle |T| = 3 elimine ceux ou deux
    # slots pointent la meme carte.
    #
    # Cas extreme rencontre dans le dictionnaire d'origine :
    #     M8 + E4 = B9   puis   B9 + M8 = E4
    # La chaine se referme sur elle-meme (E4 -> B9 -> E4) et ne
    # compte que 3 cartes au lieu de 5 : elle ne produit AUCUN trio
    # D2, alors que la table en attend 5. Le niveau se vide sans que
    # rien ne le signale.
    for t in ref.trios:
        if "parents" in t:
            continue                      # une racine n'est pas une chaine
        # Remonter la chaine complete jusqu'a la racine.
        elements: list[str] = []
        courant: dict | None = t
        maillons = 0
        while courant is not None:
            cartes = ref.cartes_du_trio(courant)
            if cartes is None:
                break
            maillons += 1
            elements.extend([cartes[1], cartes[2]])       # cable, receptrice
            if "parents" in courant:
                elements.append(cartes[0])                # emettrice de la racine
                break
            courant = ref.par_id.get(str(courant.get("depuis")))
        attendus = 2 * maillons + 1
        distincts = len(set(elements))
        if distincts < attendus:
            alertes.append(
                f"trio `{t.get('id')}` : la chaine D{maillons} qui y mene ne "
                f"compte que {distincts} cartes distinctes au lieu de "
                f"{attendus} -- elle produira moins de questions que la "
                f"table D{maillons} n'en attend"
            )

    return erreurs, alertes


def resume(ref: Referentiel) -> str:
    """Compte-rendu lisible d'un referentiel valide."""
    par_profondeur: dict[int, int] = defaultdict(int)
    for t in ref.trios:
        par_profondeur[ref.profondeur(t)] += 1
    lignes = [
        f"  jeu           : {ref.jeu} (version {ref.version})",
        f"  cartes        : {len(ref.cartes)}",
        f"  trios         : {len(ref.trios)}",
    ]
    for d in sorted(par_profondeur):
        lignes.append(f"    D{d} : {par_profondeur[d]:3d} noeuds")
    return "\n".join(lignes)


# =============================================================
# IMPORT
# =============================================================

def importer(ref: Referentiel, args) -> int:
    try:
        import httpx
    except ImportError:
        sys.exit("httpx est requis pour l'import.  pip install httpx")

    base = args.api.rstrip("/")
    mot_de_passe = os.environ.get("TRIALGO_ADMIN_PASSWORD") or getpass.getpass(
        f"Mot de passe de {args.email} : "
    )

    with httpx.Client(base_url=base, timeout=60.0) as client:
        # ---- Authentification ----
        # login renvoie les jetons A PLAT (register les imbrique sous
        # `tokens`) -- les deux formes coexistent dans l'API.
        r = client.post(
            "/api/auth/login",
            json={"email": args.email, "password": mot_de_passe},
        )
        if r.status_code != 200:
            print(f"Authentification refusee ({r.status_code}) : {r.text}")
            return 1
        jeton = r.json()["access_token"]
        client.headers["Authorization"] = f"Bearer {jeton}"

        # ---- Jeu : reutiliser ou creer ----
        if args.jeu_id:
            jeu_id = args.jeu_id
            print(f"Jeu existant : {jeu_id}")
        else:
            r = client.get("/api/games")
            r.raise_for_status()
            existant = next(
                (g for g in r.json() if g.get("name") == ref.libelle), None
            )
            if existant:
                jeu_id = existant["id"]
                print(f"Jeu deja present, reutilise : {ref.libelle} ({jeu_id})")
            else:
                r = client.post(
                    "/api/games",
                    json={"name": ref.libelle, "description": f"Importe depuis {ref.chemin.name}"},
                )
                r.raise_for_status()
                jeu_id = r.json()["id"]
                print(f"Jeu cree : {ref.libelle} ({jeu_id})")

        # ---- Cartes ----
        # On releve d'abord ce qui existe deja : l'import doit pouvoir
        # etre relance sans creer 76 doublons.
        r = client.get(f"/api/games/{jeu_id}/cards")
        r.raise_for_status()
        deja = {c["label"]: c["id"] for c in r.json()}

        ids_cartes: dict[str, str] = {}
        crees = 0
        for code, meta in sorted(ref.cartes.items()):
            meta = meta or {}
            libelle = str(meta.get("libelle") or code)
            if libelle in deja:
                ids_cartes[code] = deja[libelle]
                continue
            if not args.images:
                print(
                    f"  ! carte `{code}` absente et --images non fourni : "
                    "import du graphe impossible"
                )
                return 1
            chemin = Path(args.images) / str(meta.get("image") or f"{code}.jpg")
            if not chemin.is_file():
                print(f"  ! image introuvable : {chemin}")
                return 1
            with chemin.open("rb") as f:
                r = client.post(
                    f"/api/games/{jeu_id}/cards",
                    data={
                        "label": libelle,
                        # `card_type` est un reliquat : une carte est
                        # NEUTRE, son role vient de sa position dans
                        # un noeud. La valeur n'est pas exploitee par
                        # le gameplay, on pose donc une constante.
                        "card_type": str(meta.get("type") or "emettrice"),
                    },
                    files={"file": (chemin.name, f, "image/jpeg")},
                )
            if r.status_code != 201:
                print(f"  ! carte `{code}` refusee ({r.status_code}) : {r.text}")
                return 1
            ids_cartes[code] = r.json()["id"]
            crees += 1
        print(f"Cartes : {crees} creee(s), {len(ids_cartes) - crees} deja presente(s)")

        # ---- Noeuds : refuser d'ecrire par-dessus ----
        # Contrairement aux cartes, qu'on retrouve par leur libelle,
        # un noeud n'a aucune cle naturelle : rien ne permet de dire
        # "ce trio existe deja". Relancer betement l'import creerait
        # donc 46 noeuds SUPPLEMENTAIRES.
        #
        # Ce ne serait pas un simple doublon. Le `node_index` est le
        # numero qu'un animateur annonce a voix haute en mode
        # collectif, et il est attribue dans l'ordre d'insertion :
        # un second import decalerait tous les numeros, et les cartes
        # deja imprimees ne designeraient plus les bons trios.
        #
        # On s'arrete donc, sauf demande explicite.
        r = client.get(f"/api/games/{jeu_id}/nodes")
        r.raise_for_status()
        existants = r.json()
        if existants:
            if not args.remplacer:
                print(
                    f"\n  ! Ce jeu contient deja {len(existants)} noeud(s).\n"
                    "    Les reimporter decalerait les node_index, donc les\n"
                    "    numeros annonces en mode collectif.\n"
                    "    Relancer avec --remplacer pour les supprimer d'abord,\n"
                    "    ou viser un autre jeu."
                )
                return 1
            # Supprimer les racines suffit : la cle etrangere
            # parent_node_id est en ON DELETE CASCADE, les enfants
            # partent avec. On evite ainsi de supprimer un parent
            # avant ses enfants et de recevoir un 404 sur ces derniers.
            racines = [n for n in existants if n.get("parent_node_id") is None]
            for n in racines:
                rd = client.delete(f"/api/games/{jeu_id}/nodes/{n['id']}")
                if rd.status_code not in (200, 204):
                    print(f"  ! suppression du noeud {n['node_index']} refusee "
                          f"({rd.status_code}) : {rd.text}")
                    return 1
            print(f"Noeuds : {len(existants)} supprime(s) avant reimport")

        # Ordre imperatif : un enfant ne peut etre cree qu'apres son
        # parent, dont il a besoin de l'UUID. On trie donc par
        # profondeur croissante -- les racines d'abord.
        ordonnes = sorted(ref.trios, key=lambda t: ref.profondeur(t))
        ids_noeuds: dict[str, str] = {}
        for t in ordonnes:
            tid = str(t["id"])
            cartes = ref.cartes_du_trio(t)
            assert cartes is not None          # garanti par la validation
            _, parent2, enfant = cartes

            corps = {
                "cable_id": ids_cartes[parent2],
                "receptrice_id": ids_cartes[enfant],
                "depth": ref.profondeur(t),
            }
            if "parents" in t:
                corps["emettrice_id"] = ids_cartes[cartes[0]]
            else:
                corps["parent_node_id"] = ids_noeuds[str(t["depuis"])]

            r = client.post(f"/api/games/{jeu_id}/nodes", json=corps)
            if r.status_code != 201:
                print(f"  ! trio `{tid}` refuse ({r.status_code}) : {r.text}")
                return 1
            ids_noeuds[tid] = r.json()["id"]

        print(f"Trios : {len(ids_noeuds)} noeud(s) cree(s)")
        print(f"\nImport termine. Jeu {jeu_id}")
    return 0


# =============================================================
# REGENERATION DU DICTIONNAIRE
# =============================================================
# Le dictionnaire redevient ce qu'il aurait toujours du etre : une
# VUE. On le regenere depuis la source, donc il ne peut plus diverger.
# =============================================================

def dictionnaire(ref: Referentiel, sortie: Path) -> None:
    # Index : pour chaque carte, tous les trios ou elle apparait.
    par_carte: dict[str, list[tuple[str, str, str]]] = defaultdict(list)
    for t in ref.trios:
        trio = ref.cartes_du_trio(t)
        if not trio:
            continue
        for code in set(trio):
            par_carte[code].append(trio)

    def lib(code: str) -> str:
        meta = ref.cartes.get(code) or {}
        return str(meta.get("libelle") or code)

    html = [
        "<!doctype html><meta charset='utf-8'>",
        f"<title>{ref.libelle} — dictionnaire</title>",
        "<style>",
        "body{font:14px system-ui,sans-serif;background:#0b1a2b;color:#dce8f5;",
        "margin:0;padding:24px}",
        "h1{font-size:20px;color:#4fc3f7;border-bottom:1px solid #1e3a55;",
        "padding-bottom:8px}",
        ".g{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));",
        "gap:10px;margin-top:16px}",
        ".c{border:1px solid #1e3a55;border-radius:6px;padding:8px 10px}",
        ".k{color:#4fc3f7;font-weight:700}",
        ".t{font-family:ui-monospace,monospace;font-size:12px;margin:3px 0}",
        ".p{color:#ffd54f}",
        "footer{margin-top:24px;color:#7a95ad;font-size:12px}",
        "</style>",
        f"<h1>{ref.libelle} — dictionnaire des cartes et de leurs relations</h1>",
        "<div class='g'>",
    ]
    for code in sorted(par_carte):
        html.append(f"<div class='c'><div class='k'>{code} — {lib(code)}</div>")
        for p1, p2, enfant in sorted(par_carte[code]):
            html.append(
                f"<div class='t'>{p1} + {p2} = <span class='p'>{enfant}</span></div>"
            )
        html.append("</div>")
    html.append("</div>")
    html.append(
        f"<footer>Genere depuis {ref.chemin.name} (version {ref.version}) — "
        f"{len(ref.trios)} trios, {len(ref.cartes)} cartes. "
        "Ne pas modifier ce fichier : editer le referentiel.</footer>"
    )
    sortie.write_text("\n".join(html), encoding="utf-8")
    print(f"Dictionnaire ecrit : {sortie}")


# =============================================================
# FIXTURE DE TEST
# =============================================================
# Produit le JSON que trialgo/test/contenu_reel_test.dart consomme
# pour faire tourner le gameplay sur le vrai contenu du jeu.
#
# Les identifiants y sont les CODES du dictionnaire (A3, K4, M8...)
# et non des UUID : une fixture doit rester lisible, et les UUID
# d'un import local ne veulent rien dire sur une autre machine.
# La structure du graphe, elle, est identique a celle que l'import
# ecrit en base -- meme ordre, memes profondeurs, memes node_index.
# =============================================================

def fixture(ref: Referentiel, sortie: Path) -> None:
    import json

    # Meme ordre qu'a l'import : les racines d'abord, car un enfant
    # ne peut etre cree qu'apres son parent.
    ordonnes = sorted(ref.trios, key=lambda t: ref.profondeur(t))
    index = {str(t["id"]): i + 1 for i, t in enumerate(ordonnes)}

    noeuds = []
    for t in ordonnes:
        cartes = ref.cartes_du_trio(t)
        assert cartes is not None
        p1, p2, enfant = cartes
        noeuds.append(
            {
                "id": str(t["id"]),
                "node_index": index[str(t["id"])],
                "emettrice_id": p1 if "parents" in t else None,
                "parent_node_id": None if "parents" in t else str(t["depuis"]),
                "cable_id": p2,
                "receptrice_id": enfant,
                "depth": ref.profondeur(t),
            }
        )

    donnees = {
        "_source": f"{ref.chemin.name} (version {ref.version})",
        "cards": [
            {"id": code, "label": str((meta or {}).get("libelle") or code)}
            for code, meta in sorted(ref.cartes.items())
        ],
        "nodes": noeuds,
    }
    sortie.write_text(
        json.dumps(donnees, indent=1, ensure_ascii=False), encoding="utf-8"
    )
    print(f"Fixture ecrite : {sortie}")
    print(f"  {len(donnees['cards'])} cartes, {len(noeuds)} noeuds")


# =============================================================
# POINT D'ENTREE
# =============================================================

def main() -> int:
    p = argparse.ArgumentParser(
        description="Valide et importe un referentiel de jeu MIXALGO.",
    )
    sous = p.add_subparsers(dest="commande", required=True)

    pv = sous.add_parser("valider", help="controle le fichier sans rien ecrire")
    pv.add_argument("fichier", type=Path)

    pi = sous.add_parser("importer", help="cree cartes et noeuds via l'API")
    pi.add_argument("fichier", type=Path)
    pi.add_argument("--api", default="http://localhost:8000")
    pi.add_argument("--email", required=True, help="compte administrateur")
    pi.add_argument("--images", help="dossier contenant les images des cartes")
    pi.add_argument("--jeu-id", help="importer dans un jeu existant (UUID)")
    pi.add_argument(
        "--remplacer",
        action="store_true",
        help="supprimer les noeuds existants avant de reimporter "
             "(ATTENTION : renumerote les trios du mode collectif)",
    )

    pd = sous.add_parser("dictionnaire", help="regenere l'index illustre")
    pd.add_argument("fichier", type=Path)
    pd.add_argument("--sortie", type=Path, default=Path("dictionnaire.html"))

    pf = sous.add_parser("fixture", help="regenere la fixture des tests Flutter")
    pf.add_argument("fichier", type=Path)
    pf.add_argument(
        "--sortie",
        type=Path,
        default=Path("../trialgo/test/fixtures/mixalgo_savane.json"),
    )

    args = p.parse_args()

    if not args.fichier.is_file():
        print(f"Fichier introuvable : {args.fichier}")
        return 1

    ref = Referentiel.charger(args.fichier)
    erreurs, alertes = valider(ref)

    for a in alertes:
        print(f"  ~ {a}")
    if erreurs:
        print(f"\n{len(erreurs)} erreur(s) :")
        for e in erreurs:
            print(f"  x {e}")
        return 1

    if args.commande == "valider":
        print(f"\n{args.fichier} : referentiel valide.")
        print(resume(ref))
        return 0

    if args.commande == "dictionnaire":
        dictionnaire(ref, args.sortie)
        return 0

    if args.commande == "fixture":
        fixture(ref, args.sortie)
        return 0

    print(f"\n{args.fichier} : referentiel valide.")
    print(resume(ref))
    print()
    return importer(ref, args)


if __name__ == "__main__":
    sys.exit(main())
