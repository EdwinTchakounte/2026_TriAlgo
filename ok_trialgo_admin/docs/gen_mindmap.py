"""Carte mentale  -  algorithme de generation d'arbre TRIALGO (v2 grid)."""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle

# -------- palette app --------
BG       = "#121419"
SURFACE  = "#1C1F26"
SURFACE2 = "#252932"
BORDER   = "#323845"
TEXT     = "#F3F5F9"
TEXT_DIM = "#9AA1AE"
BRAND    = "#FF6B35"
ING_A    = "#42A5F5"
ING_B    = "#AB47BC"
PROD     = "#66BB6A"
D_COL = {1: "#E53935", 2: "#FB8C00", 3: "#FDD835", 4: "#43A047", 5: "#1E88E5"}


def box(ax, x, y, w, h, text, *, fill=SURFACE, edge=BORDER, fc_text=TEXT,
        fs=10, fw="normal", lw=1.4, radius=0.22):
    p = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.02,rounding_size={radius}",
        linewidth=lw, edgecolor=edge, facecolor=fill,
    )
    ax.add_patch(p)
    ax.text(x + w / 2, y + h / 2, text,
            ha="center", va="center",
            color=fc_text, fontsize=fs, fontweight=fw)


def arrow(ax, x1, y1, x2, y2, color=BRAND, lw=1.8):
    a = FancyArrowPatch((x1, y1), (x2, y2),
                        arrowstyle="-|>", mutation_scale=14,
                        color=color, linewidth=lw)
    ax.add_patch(a)


def card(ax, x, y, w, h, label, color):
    p = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.02,rounding_size=0.11",
        linewidth=1.6, edgecolor=color, facecolor=color + "33",
    )
    ax.add_patch(p)
    ax.text(x + w / 2, y + h / 2, label,
            ha="center", va="center",
            color=color, fontsize=10, fontweight="bold")


def depth_badge(ax, cx, cy, d, r=0.27):
    c = Circle((cx, cy), r, facecolor=D_COL[d] + "33",
               edgecolor=D_COL[d], linewidth=1.8)
    ax.add_patch(c)
    ax.text(cx, cy, f"D{d}", ha="center", va="center",
            color=D_COL[d], fontsize=9, fontweight="bold")


def section_title(ax, x, y, text, color=BRAND):
    ax.text(x, y, text, color=color, fontsize=12.5,
            fontweight="bold", ha="left", va="center")


# ============================================================
fig = plt.figure(figsize=(20, 14), facecolor=BG)
ax = fig.add_subplot(111)
ax.set_xlim(0, 20)
ax.set_ylim(0, 14)
ax.set_aspect("equal")
ax.axis("off")
ax.set_facecolor(BG)

# ===== TITRE =====
ax.text(10, 13.45,
        "ALGORITHME DE GENERATION DE L'ARBRE TRIALGO",
        ha="center", va="center",
        color=TEXT, fontsize=18, fontweight="bold")
ax.text(10, 13.0,
        "Un arbre de syntheses construit par fusion injective de cartes",
        ha="center", va="center",
        color=TEXT_DIM, fontsize=11, fontstyle="italic")
ax.plot([1, 19], [12.65, 12.65], color=BORDER, lw=0.8)

# ============================================================
# ROW 1  -  POSTULAT  |  PROPRIETES
# ============================================================
# zone : y in [8.7, 12.3], left x in [0.6, 9.7], right x in [10.3, 19.4]

# ----- 1. POSTULAT -----
section_title(ax, 0.6, 12.15, "1.  POSTULAT  -  l'operation de base")

box(ax, 0.6, 9.6, 5.2, 2.05,
    "fuse(A, B)  =  C\n\nUne paire de cartes  A + B\nproduit DETERMINISTIQUEMENT\nune carte C",
    fill=SURFACE, fs=10)

# visuel fusion a cote
vx = 6.1
card(ax, vx,       10.5, 0.85, 0.7, "A", ING_A)
ax.text(vx + 1.05, 10.85, "+", color=TEXT, fontsize=14, fontweight="bold",
        ha="center", va="center")
card(ax, vx + 1.25, 10.5, 0.85, 0.7, "B", ING_B)
arrow(ax, vx + 2.18, 10.85, vx + 2.78, 10.85)
card(ax, vx + 2.9, 10.5, 0.85, 0.7, "C", PROD)
ax.text(vx + 0.42, 10.35, "ingredient", color=ING_A, fontsize=8, ha="center")
ax.text(vx + 1.67, 10.35, "ingredient", color=ING_B, fontsize=8, ha="center")
ax.text(vx + 3.32, 10.35, "produit",    color=PROD,  fontsize=8, ha="center")
ax.text(vx + 1.87, 9.95, "fusion", color=TEXT_DIM, fontsize=9, ha="center",
        style="italic")

# ----- 2. PROPRIETES -----
section_title(ax, 10.3, 12.15, "2.  PROPRIETES  -  ce qui force l'arbre")

box(ax, 10.3, 11.30, 9.1, 0.55,
    "DETERMINISME :  meme (A,B)  =>  meme C  toujours",
    fill=SURFACE, fs=9.5)

box(ax, 10.3, 10.65, 9.1, 0.55,
    "INJECTIVITE :  un produit C  =>  une seule recette (A,B)",
    fill=SURFACE, fs=9.5)

box(ax, 10.3, 10.00, 9.1, 0.55,
    "REUTILISABILITE :  un produit peut etre l'ingredient suivant",
    fill=SURFACE, fs=9.5)

ax.text(10.3, 9.65, "consequence directe :",
        color=BRAND, fontsize=9, fontstyle="italic")

box(ax, 10.3, 8.85, 9.1, 0.7,
    "chaque produit a AU PLUS UN parent  =>  la structure est un ARBRE",
    fill=BRAND + "22", edge=BRAND, fc_text=BRAND, fs=10, fw="bold")

# ============================================================
# ROW 2  -  CHAINAGE  |  PROFONDEURS
# ============================================================
# zone : y in [4.8, 8.4]

# ----- 3. CHAINAGE -----
section_title(ax, 0.6, 8.4, "3.  CHAINAGE  -  composer les fusions")

# Parent : X + Y = Z
y_p = 7.4
card(ax, 0.8, y_p, 0.7, 0.55, "X", ING_A)
ax.text(1.6, y_p + 0.28, "+", color=TEXT, fontsize=12, fontweight="bold",
        ha="center", va="center")
card(ax, 1.7, y_p, 0.7, 0.55, "Y", ING_B)
arrow(ax, 2.45, y_p + 0.28, 3.05, y_p + 0.28, color=PROD)
card(ax, 3.15, y_p, 0.7, 0.55, "Z", PROD)
depth_badge(ax, 4.3, y_p + 0.28, 1, r=0.25)
ax.text(4.75, y_p + 0.28, "parent",
        color=TEXT_DIM, fontsize=9, va="center")

# fleche reutilisation Z -> ingredient enfant
arrow(ax, 3.5, y_p - 0.05, 1.15, y_p - 0.85, color=BRAND)
ax.text(2.2, y_p - 0.45, "Z reutilise",
        color=BRAND, fontsize=8.5, style="italic")

# Enfant : Z + W = V
y_c = 6.05
card(ax, 0.8, y_c, 0.7, 0.55, "Z", ING_A)
ax.text(1.6, y_c + 0.28, "+", color=TEXT, fontsize=12, fontweight="bold",
        ha="center", va="center")
card(ax, 1.7, y_c, 0.7, 0.55, "W", ING_B)
arrow(ax, 2.45, y_c + 0.28, 3.05, y_c + 0.28, color=PROD)
card(ax, 3.15, y_c, 0.7, 0.55, "V", PROD)
depth_badge(ax, 4.3, y_c + 0.28, 2, r=0.25)
ax.text(4.75, y_c + 0.28, "enfant",
        color=TEXT_DIM, fontsize=9, va="center")

# bandeau explication
box(ax, 0.6, 4.95, 9.1, 0.85,
    "l'enfant n'a PAS besoin de stocker Z  -  on le deduit du parent\n"
    "(emettriceId = NULL si parentNodeId != NULL)",
    fill=SURFACE2, fs=9, fc_text=TEXT_DIM, lw=1)

# ----- 4. PROFONDEURS -----
section_title(ax, 10.3, 8.4, "4.  PROFONDEURS  -  longueur de la chaine")

exprs = [
    (1, "fuse(a, b) = c",                    "fusion simple"),
    (2, "fuse( fuse(a,b), d) = e",           "compose 1 fois"),
    (3, "fuse( fuse(fuse(a,b),d), f) = g",   "compose 2 fois"),
]
for i, (d, expr, lbl) in enumerate(exprs):
    yy = 7.7 - i * 0.75
    depth_badge(ax, 10.65, yy, d, r=0.26)
    box(ax, 11.20, yy - 0.30, 5.4, 0.6,
        expr, fill=SURFACE, fs=10)
    ax.text(16.80, yy, lbl, color=TEXT_DIM, fontsize=9, va="center")

box(ax, 10.3, 4.95, 9.1, 0.85,
    "Dn  =  profondeur d'imbrication des fusions\n"
    "(borne dure dans le code : depth <= 5)",
    fill=BRAND + "1A", edge=BRAND, fc_text=BRAND, fs=10, fw="bold")

# ============================================================
# ROW 3  -  STRUCTURE  |  FLOW
# ============================================================
# zone : y in [1.6, 4.45]

# ----- 5. STRUCTURE -----
section_title(ax, 0.6, 4.45, "5.  STRUCTURE  -  un noeud en memoire")

box(ax, 0.6, 1.7, 9.1, 2.55, "", fill=SURFACE, lw=1.4)

fields = [
    ("id",            "uuid unique",                                 TEXT),
    ("nodeIndex",     "MAX(node_index) + 1 par jeu",                 TEXT_DIM),
    ("emettriceId",   "ingredient A  -  NULL si parent",             ING_A),
    ("cableId",       "ingredient B  -  toujours present",           ING_B),
    ("receptriceId",  "produit C  -  toujours present",              PROD),
    ("parentNodeId",  "NULL = racine D1 ; sinon FK -> parent",       BRAND),
    ("depth",         "(parent.depth ?? 0) + 1  -  max 5",           TEXT_DIM),
]
for i, (k, v, col) in enumerate(fields):
    yy = 4.0 - i * 0.32
    ax.text(0.9, yy, k, color=col, fontsize=10, fontweight="bold", va="center")
    ax.text(3.3, yy, v, color=TEXT_DIM, fontsize=9.5, va="center")

ax.text(0.85, 1.85,
        "parentNodeId est l'UNIQUE lien structurel",
        color=BRAND, fontsize=9, fontstyle="italic")

# ----- 6. FLOW -----
section_title(ax, 10.3, 4.45, "6.  FLOW  -  comment on cree un noeud")

steps = [
    ("choisir le parent ?",
     "non = racine D1  /  oui = chainage Dn"),
    ("si racine :  choisir A (ingredient explicite)",
     "si enfant : A est DEDUIT (= produit du parent)"),
    ("choisir B (ingredient explicite)",
     "le 'cable' dans le code legacy"),
    ("choisir C (produit explicite)",
     "le 'recepteur' dans le code legacy"),
    ("garde-fous",
     "depth <= 5  ;  parent eligible si depth < 5"),
    ("INSERT  +  refresh provider",
     "graphview recalcule l'arbre automatiquement"),
]
sx = 10.3
for i, (head, sub) in enumerate(steps):
    yy = 4.10 - i * 0.42
    c = Circle((sx + 0.20, yy), 0.16,
               facecolor=BRAND, edgecolor=BRAND)
    ax.add_patch(c)
    ax.text(sx + 0.20, yy, str(i + 1),
            ha="center", va="center",
            color="white", fontsize=8.5, fontweight="bold")
    ax.text(sx + 0.55, yy + 0.09, head,
            color=TEXT, fontsize=9.7, fontweight="bold", va="center")
    ax.text(sx + 0.55, yy - 0.11, sub,
            color=TEXT_DIM, fontsize=8.5, va="center", fontstyle="italic")

# ============================================================
# BANDEAU BAS
# ============================================================
box(ax, 0.6, 0.35, 18.8, 1.05,
    "EN UNE PHRASE  :  l'arbre TRIALGO est le graphe des syntheses ou chaque noeud est une equation\n"
    "fuse(A,B) = C  -  l'injectivite de fuse force la structure arbre  -  parentNodeId = la fleche structurelle",
    fill=BRAND + "1A", edge=BRAND, fc_text=TEXT, fs=11, fw="bold", radius=0.28)

# ============================================================
plt.tight_layout(pad=0.4)
out = "/home/tchakounte/Desktop/TriAlgo/trialgo_admin/docs/mindmap_arbre_algo.jpg"
plt.savefig(out, dpi=170, facecolor=BG, bbox_inches="tight",
            pad_inches=0.2, format="jpg")
plt.close(fig)
print("Saved:", out)
