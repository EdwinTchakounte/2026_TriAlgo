"""Coverage audit : every Supabase call by admin client mapped to a FastAPI endpoint.

Verdict per row :
  - DIRECT_MATCH : equivalent 1-to-1
  - IMPROVED     : equivalent + amelioration (multipart unique, refresh JWT, ...)
  - BONUS        : endpoint FastAPI sans equivalent Supabase (utile pour le futur)
"""

import os
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

BG       = "#121419"
SURFACE  = "#1C1F26"
SURFACE2 = "#252932"
BORDER   = "#323845"
TEXT     = "#F3F5F9"
TEXT_DIM = "#9AA1AE"
BRAND    = "#FF6B35"
GREEN    = "#66BB6A"
BLUE     = "#42A5F5"
PURPLE   = "#AB47BC"
YELLOW   = "#FDD835"
RED      = "#EF4444"

VERDICT = {
    "MATCH":    (GREEN,  "OK"),
    "IMPROVED": (BRAND,  "+"),
    "BONUS":    (BLUE,   "*"),
}


def box(ax, x, y, w, h, text, *, fill=SURFACE, edge=BORDER, fc_text=TEXT,
        fs=9, fw="normal", lw=1.4, radius=0.18, ha="center"):
    p = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.01,rounding_size={radius}",
        linewidth=lw, edgecolor=edge, facecolor=fill,
    )
    ax.add_patch(p)
    tx = x + w / 2 if ha == "center" else x + 0.15
    ax.text(tx, y + h / 2, text,
            ha=ha, va="center",
            color=fc_text, fontsize=fs, fontweight=fw)


def chip(ax, x, y, w, h, text, color):
    box(ax, x, y, w, h, text,
        fill=color + "26", edge=color, fc_text=color, fs=9, fw="bold",
        radius=0.22, lw=1.4)


def section_title(ax, x, y, text, color):
    ax.text(x, y, text, color=color, fontsize=13,
            fontweight="bold", ha="left", va="center")


# (section, color, [(supabase_call, fastapi_endpoint, verdict, note)])
GROUPS = [
    ("AUTH", BRAND, [
        ("auth.currentUser  +  user_profiles.select",
         "GET   /api/auth/me",
         "MATCH",
         "Profil + is_admin en 1 call (vs 2 cote Supabase)"),
        ("auth.signInWithPassword + user_profiles fetch",
         "POST  /api/auth/login  + GET /me",
         "MATCH",
         "Login + access/refresh JWT, gate admin cote app"),
        ("auth.signOut()",
         "(client-side : clear tokens)",
         "MATCH",
         "JWT stateless : pas besoin d'endpoint serveur"),
        ("- (creation manuelle SQL)",
         "POST  /api/auth/register",
         "BONUS",
         "1er user = admin auto, plus besoin de SQL"),
        ("- (re-login manuel a expiration)",
         "POST  /api/auth/refresh",
         "BONUS",
         "Renouvelle l'access sans demander mot de passe"),
    ]),
    ("GAMES", PURPLE, [
        ("games.select.order(created_at)",
         "GET   /api/games",
         "MATCH",
         "Liste tous les jeux"),
        ("games.insert.select.single",
         "POST  /api/games",
         "MATCH",
         "Cree + renvoie la ligne complete"),
        ("games.update.eq(id).select.single",
         "PATCH /api/games/{id}",
         "MATCH",
         "Update partiel ; champs vides = ignores"),
        ("- (pas dans le repo client)",
         "GET   /api/games/{id}",
         "BONUS",
         "Detail unique (utile pour deep-link)"),
        ("- (pas dans le repo client)",
         "DELETE /api/games/{id}",
         "BONUS",
         "Suppression + CASCADE cards/nodes"),
    ]),
    ("CARDS", BLUE, [
        ("cards.select.eq(game_id).order(label)",
         "GET   /api/games/{gid}/cards",
         "MATCH",
         "Liste + image_url pre-calculee"),
        ("storage.upload  +  cards.insert  (2 calls)",
         "POST  /api/games/{gid}/cards (multipart)",
         "IMPROVED",
         "1 transaction atomique (rollback si KO)"),
        ("cards.update.eq(id).select.single",
         "PATCH /api/cards/{id}",
         "MATCH",
         "Update label / type"),
        ("cards.delete + storage.remove (2 calls)",
         "DELETE /api/cards/{id}",
         "IMPROVED",
         "1 call ; serveur gere storage + DB"),
        ("storage.getPublicUrl",
         "(image_url dans CardOut)",
         "MATCH",
         "URL deja construite cote serveur"),
    ]),
    ("NODES (FUSIONS)", GREEN, [
        ("nodes.select.eq(game_id).order(node_index)",
         "GET   /api/games/{gid}/nodes",
         "MATCH",
         "Liste triee"),
        ("nodes.select(node_index).order.desc.limit(1)",
         "GET   /api/games/{gid}/nodes/next-index",
         "MATCH",
         "MAX+1 calcule serveur (1 call vs 1 query)"),
        ("nodes.insert.select.single",
         "POST  /api/games/{gid}/nodes",
         "IMPROVED",
         "Invariants Pydantic + xor parent/emettrice"),
        ("nodes.delete.eq(id)",
         "DELETE /api/nodes/{id}",
         "MATCH",
         "Cascade descendants via FK"),
        ("- (logique Dart cote app)",
         "POST  /api/games/{gid}/nodes/analyze",
         "BONUS",
         "Analyse 3 cartes (direct/chaine/none)"),
    ]),
]


# ============================================================
fig = plt.figure(figsize=(22, 19), facecolor=BG)
ax = fig.add_subplot(111)
ax.set_xlim(0, 22)
ax.set_ylim(0, 19)
ax.set_aspect("equal")
ax.axis("off")
ax.set_facecolor(BG)

ax.text(11, 18.4,
        "AUDIT COUVERTURE  -  Admin (Supabase actuel)  ->  FastAPI backend",
        ha="center", va="center",
        color=TEXT, fontsize=17, fontweight="bold")
ax.text(11, 17.95,
        "Verifie que chaque appel cote client trouve son equivalent serveur",
        ha="center", va="center",
        color=TEXT_DIM, fontsize=10.5, fontstyle="italic")
ax.plot([0.6, 21.4], [17.55, 17.55], color=BORDER, lw=0.7)

# Header
header_y = 16.95
box(ax, 0.6,  header_y - 0.3, 0.7, 0.55, "OK",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold")
box(ax, 1.4,  header_y - 0.3, 9.5, 0.55, "APPEL CLIENT (Supabase impl)",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold", ha="left")
box(ax, 11.0, header_y - 0.3, 6.0, 0.55, "ENDPOINT FASTAPI",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold", ha="left")
box(ax, 17.1, header_y - 0.3, 4.3, 0.55, "NOTES",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold", ha="left")

# Rows
y = 16.2
for name, color, rows in GROUPS:
    section_title(ax, 0.6, y, name, color)
    ax.text(21.0, y, f"{len(rows)} actions",
            color=TEXT_DIM, fontsize=9.5, ha="right",
            fontweight="bold", style="italic")
    y -= 0.45

    for sup, api, verdict, note in rows:
        v_color, v_label = VERDICT[verdict]
        chip(ax, 0.6, y - 0.25, 0.7, 0.5, v_label, v_color)
        box(ax, 1.4, y - 0.25, 9.5, 0.5, sup,
            fill=SURFACE, edge=BORDER, fs=9, fw="normal", ha="left")
        box(ax, 11.0, y - 0.25, 6.0, 0.5, api,
            fill=SURFACE, edge=v_color, fs=9, fw="bold", ha="left",
            fc_text=v_color)
        box(ax, 17.1, y - 0.25, 4.3, 0.5, note,
            fill=SURFACE, edge=BORDER, fs=8.7, ha="left", fc_text=TEXT_DIM)
        y -= 0.6

    y -= 0.1
    ax.plot([0.6, 21.4], [y, y], color=BORDER, lw=0.5, linestyle="dashed")
    y -= 0.3

# Legend
y_legend = 1.0
box(ax, 0.6, y_legend, 6.8, 1.7,
    "LEGENDE\n\n"
    "OK   - equivalent direct du call client\n"
    "+    - equivalent + ameliore (multipart unique, transaction, ...)\n"
    "*    - endpoint en plus, dispo pour le futur (refresh, register, delete...)",
    fill=SURFACE, edge=BORDER, fs=9, fw="normal", ha="left", lw=1.2)

box(ax, 7.6, y_legend, 13.8, 1.7,
    "VERDICT FINAL\n\n"
    "Tous les appels du client admin (Supabase) ont leur equivalent FastAPI.\n"
    "5 endpoints BONUS apportent : register sans SQL, refresh JWT, detail game, suppression game, analyse fusion serveur.\n"
    "2 endpoints AMELIORES : upload carte (multipart unique transactionnel), delete carte (1 call vs 2).",
    fill=BRAND + "1A", edge=BRAND, fs=10, fw="bold", ha="left", lw=1.4)

plt.tight_layout(pad=0.3)
out = "/home/tchakounte/Desktop/TriAlgo/ok_trialgo_backend/docs/coverage_audit.jpg"
plt.savefig(out, dpi=170, facecolor=BG, bbox_inches="tight",
            pad_inches=0.2, format="jpg")
plt.close(fig)
print("Saved:", out)
