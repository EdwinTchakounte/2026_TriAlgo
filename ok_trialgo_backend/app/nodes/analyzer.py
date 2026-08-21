# =============================================================
# FICHIER : app/nodes/analyzer.py
# ROLE    : Port Python du FusionAnalyzer (logique deterministe)
# =============================================================
#
# Identique en esprit a Dart  trialgo_admin/lib/domain/services/
# fusion_analyzer.dart. Trois resultats possibles :
#
#   - DIRECT_LINK  : les 3 cartes forment exactement une fusion
#   - CHAINED_LINK : couvrent un chainage parent-enfant
#   - NO_LINK      : aucune relation
#
# La fonction est PURE (pas d'IO, pas de DB session) : on lui
# passe les nodes et cards deja chargees, elle calcule. Permet
# des tests unitaires sans Postgres.
# =============================================================

from dataclasses import dataclass
from uuid import UUID

from ..cards.models import Card
from .models import GameNode
from .schemas import AnalysisKind, AnalyzeOut


@dataclass(frozen=True)
class _NodeView:
    id: UUID
    a: UUID | None
    b: UUID
    c: UUID
    parent: UUID | None
    depth: int
    index: int


def _effective_a(node: _NodeView, nodes_by_id: dict[UUID, _NodeView]) -> UUID | None:
    """Recupere l'ingredient A 'effectif' : si null, deduit du parent."""
    if node.a is not None:
        return node.a
    if node.parent is None:
        return None
    parent = nodes_by_id.get(node.parent)
    return parent.c if parent else None


def _label_of(card_id: UUID, cards_by_id: dict[UUID, Card]) -> str:
    c = cards_by_id.get(card_id)
    return c.label if c else "?"


def _describe(node: _NodeView, cards_by_id: dict[UUID, Card]) -> str:
    a = "(deduit)" if node.a is None else _label_of(node.a, cards_by_id)
    return f"{a} + {_label_of(node.b, cards_by_id)} = {_label_of(node.c, cards_by_id)}"


def analyze_fusion(
    selected_ids: list[UUID],
    nodes: list[GameNode],
    cards: list[Card],
) -> AnalyzeOut:
    # Garde-fous d'entree (le schema garantit deja len == 3 cote API,
    # mais on protege la fonction si appelee programmatiquement).
    if len(selected_ids) != 3:
        return AnalyzeOut(
            kind=AnalysisKind.NO_LINK, involved_node_ids=[],
            summary="Selectionnez exactement 3 cartes",
        )
    selected_set = set(selected_ids)
    if len(selected_set) != 3:
        return AnalyzeOut(
            kind=AnalysisKind.NO_LINK, involved_node_ids=[],
            summary="Les cartes doivent etre distinctes",
        )

    nv = [
        _NodeView(
            id=n.id, a=n.emettrice_id, b=n.cable_id, c=n.receptrice_id,
            parent=n.parent_node_id, depth=n.depth, index=n.node_index,
        )
        for n in nodes
    ]
    nodes_by_id = {n.id: n for n in nv}
    cards_by_id = {c.id: c for c in cards}

    # ---- CAS 1 : fusion directe ----
    for n in nv:
        a_eff = _effective_a(n, nodes_by_id)
        if a_eff is None:
            continue
        s = {a_eff, n.b, n.c}
        if len(s) == 3 and s == selected_set:
            return AnalyzeOut(
                kind=AnalysisKind.DIRECT_LINK,
                involved_node_ids=[n.id],
                summary=f"Fusion directe trouvee : #{n.index} (D{n.depth})",
                detail=_describe(n, cards_by_id),
            )

    # ---- CAS 2 : chainage parent-enfant ----
    for child in nv:
        if child.parent is None:
            continue
        parent = nodes_by_id.get(child.parent)
        if parent is None:
            continue
        union = {
            *([_effective_a(parent, nodes_by_id)] or []),
            parent.b, parent.c,
            *([_effective_a(child, nodes_by_id)] or []),
            child.b, child.c,
        }
        union.discard(None)
        if selected_set.issubset(union):
            return AnalyzeOut(
                kind=AnalysisKind.CHAINED_LINK,
                involved_node_ids=[parent.id, child.id],
                summary=(
                    f"Chainage trouve : #{parent.index} (D{parent.depth}) -> "
                    f"#{child.index} (D{child.depth})"
                ),
                detail=(
                    f"{_describe(parent, cards_by_id)}\n"
                    f"chaine vers\n{_describe(child, cards_by_id)}"
                ),
            )

    # ---- CAS 3 : rien ----
    return AnalyzeOut(
        kind=AnalysisKind.NO_LINK,
        involved_node_ids=[],
        summary="Ces 3 cartes ne sont pas liees dans cet arbre",
    )
