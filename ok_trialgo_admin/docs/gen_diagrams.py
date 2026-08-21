# -*- coding: utf-8 -*-
# =============================================================
# gen_diagrams.py
# Genere les JPEG de modelisation + simulation de l'arbre TRIALGO.
# Palette alignee sur app_colors.dart.
# =============================================================
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import os

OUT = os.path.dirname(os.path.abspath(__file__))

# --- Palette (depuis app_colors.dart) ---
BRAND   = "#FF6B35"
EMET    = "#42A5F5"  # emettrice  - bleu
CABLE   = "#AB47BC"  # cable      - violet
RECEP   = "#66BB6A"  # receptrice - vert
BG      = "#FAFAFB"
INK     = "#23262B"
MUTE    = "#8A909A"

def box(ax, x, y, w, h, text, fc, ec=None, tc="white", fs=12, weight="bold", alpha=1.0):
    ec = ec or fc
    p = FancyBboxPatch((x, y), w, h,
                       boxstyle="round,pad=0.02,rounding_size=0.12",
                       linewidth=2, edgecolor=ec, facecolor=fc, alpha=alpha)
    ax.add_patch(p)
    ax.text(x + w/2, y + h/2, text, ha="center", va="center",
            color=tc, fontsize=fs, fontweight=weight, wrap=True)

def arrow(ax, x1, y1, x2, y2, color=INK, lw=2.2, style="-|>"):
    a = FancyArrowPatch((x1, y1), (x2, y2), arrowstyle=style,
                        mutation_scale=18, linewidth=lw, color=color)
    ax.add_patch(a)

def new_fig(w=12, h=7.5):
    fig, ax = plt.subplots(figsize=(w, h), dpi=150)
    ax.set_xlim(0, 12); ax.set_ylim(0, h)
    ax.axis("off")
    fig.patch.set_facecolor(BG); ax.set_facecolor(BG)
    return fig, ax

def save(fig, name):
    path = os.path.join(OUT, name)
    fig.savefig(path, format="jpeg", dpi=150, bbox_inches="tight",
                facecolor=fig.get_facecolor())
    plt.close(fig)
    print("wrote", path)

# =============================================================
# 1) REGLES : trio atomique + chainage
# =============================================================
fig, ax = new_fig(12, 7.5)
ax.text(6, 7.1, "TRIALGO  —  regle de modelisation", ha="center",
        fontsize=20, fontweight="bold", color=INK)

# -- trio atomique (gauche)
ax.text(3, 6.3, "1.  Le trio atomique", ha="center", fontsize=14,
        fontweight="bold", color=BRAND)
box(ax, 0.6, 5.0, 2.0, 0.8, "EMETTRICE\n(E)", EMET)
box(ax, 3.4, 5.0, 2.0, 0.8, "CABLE\n(C)", CABLE)
box(ax, 2.0, 3.4, 2.0, 0.8, "RECEPTRICE\n(R)", RECEP)
arrow(ax, 1.6, 5.0, 2.6, 4.2)
arrow(ax, 4.4, 5.0, 3.4, 4.2)
ax.text(3.0, 2.9, "E  +  C   =>   R", ha="center", fontsize=15,
        fontweight="bold", color=INK)

# -- chainage (droite)
ax.text(9, 6.3, "2.  Le chainage", ha="center", fontsize=14,
        fontweight="bold", color=BRAND)
box(ax, 7.0, 5.0, 4.0, 0.85, "node PARENT      E + C  =>  R(parent)", BRAND, fs=11)
arrow(ax, 9.0, 5.0, 9.0, 4.2, color=RECEP, lw=3)
ax.text(10.4, 4.55, "R du parent\n= E de l'enfant", ha="left", fontsize=9.5,
        color=RECEP, fontweight="bold")
box(ax, 7.0, 3.0, 4.0, 0.85, "node ENFANT   (E deduite) + C => R", RECEP, fs=11)
ax.text(9, 2.2,
        "L'emettrice de l'enfant n'est JAMAIS saisie :\n"
        "elle est deduite = receptrice du parent.\n"
        "Seule la racine (D1) porte une emettrice explicite.",
        ha="center", fontsize=10, color=MUTE)

# legende couleurs
for i,(lbl,c) in enumerate([("Emettrice",EMET),("Cable",CABLE),("Receptrice",RECEP)]):
    box(ax, 0.6 + i*2.0, 0.5, 0.35, 0.35, "", c)
    ax.text(1.05 + i*2.0, 0.67, lbl, ha="left", va="center", fontsize=10, color=INK)
save(fig, "modelisation_01_regles.jpg")

# =============================================================
# 2) ARBRE fidele a la base (savane demo)
# =============================================================
fig, ax = new_fig(12, 8.5)
ax.set_ylim(0, 8.5)
ax.text(6, 8.1, "TRIALGO Savane  —  arbre genere (modele de donnees)",
        ha="center", fontsize=17, fontweight="bold", color=INK)

def node(ax, x, y, idx, depth, parent, e, c, r, deduced=False):
    w, h = 3.4, 1.25
    ec = BRAND if depth == 1 else MUTE
    box(ax, x, y, w, h, "", "white", ec=ec, tc=INK)
    ax.text(x+0.15, y+h-0.22, f"node #{idx}  ·  depth {depth}  ·  parent {parent}",
            ha="left", fontsize=8.5, color=MUTE, fontweight="bold")
    etxt = f"E: ({e} deduite)" if deduced else f"E: {e}"
    ecol = RECEP if deduced else EMET
    ax.text(x+0.15, y+0.62, etxt, ha="left", fontsize=10, color=ecol, fontweight="bold")
    ax.text(x+0.15, y+0.36, f"C: {c}", ha="left", fontsize=10, color=CABLE, fontweight="bold")
    ax.text(x+0.15, y+0.12, f"R: {r}", ha="left", fontsize=10, color=RECEP, fontweight="bold")
    return (x+w/2, y, x+w/2, y+h)  # centre bas, centre haut

# D1 racine
n1 = node(ax, 4.3, 6.7, 1, 1, "NULL", "Lion", "Liane", "Gazelle")
# D2 gauche
n2 = node(ax, 1.2, 4.3, 2, 2, "#1", "Gazelle", "Riviere", "Elephant", deduced=True)
# D2 droite
n3 = node(ax, 7.4, 4.3, 3, 2, "#1", "Gazelle", "Liane", "Gazelle*", deduced=True)
# D3 sous n2
n4 = node(ax, 1.2, 1.9, 4, 3, "#2", "Elephant", "Liane", "Gazelle*", deduced=True)

# liens parent -> enfant (depuis bas du parent vers haut de l'enfant)
arrow(ax, n1[0], n1[1], n2[2], n2[3], color=RECEP, lw=2.4)
arrow(ax, n1[0], n1[1], n3[2], n3[3], color=RECEP, lw=2.4)
arrow(ax, n2[0], n2[1], n4[2], n4[3], color=RECEP, lw=2.4)

ax.text(6, 0.6, "* carte reutilisable dans plusieurs trios (seul le role compte).   "
        "Les fleches vertes = R(parent) injectee comme E(enfant).",
        ha="center", fontsize=9, color=MUTE)
save(fig, "modelisation_02_arbre.jpg")

# =============================================================
# 3) SIMULATION : catalogue de cartes (vignettes)
# =============================================================
fig, ax = new_fig(12, 5.5)
ax.set_ylim(0, 5.5)
ax.text(6, 5.1, "Simulation  —  catalogue de cartes (jeu de demo)",
        ha="center", fontsize=16, fontweight="bold", color=INK)
cards = [
    ("Lion", EMET, "Emettrice"), ("Zebre", EMET, "Emettrice"),
    ("Liane", CABLE, "Cable"), ("Riviere", CABLE, "Cable"),
    ("Gazelle", RECEP, "Receptrice"), ("Elephant", RECEP, "Receptrice"),
]
def card_tile(ax, x, y, label, color, role, w=1.7, h=2.0):
    # image (zone coloree) + bandeau label
    box(ax, x, y+0.5, w, h-0.5, "", color, ec=color, alpha=0.85)
    ax.text(x+w/2, y+0.5+(h-0.5)/2, label.upper(), ha="center", va="center",
            color="white", fontsize=12, fontweight="bold")
    box(ax, x, y, w, 0.5, role, "white", ec=color, tc=INK, fs=9)
for i,(lbl,col,role) in enumerate(cards):
    card_tile(ax, 0.6 + i*1.92, 1.6, lbl, col, role)
save(fig, "simulation_cartes.jpg")

# =============================================================
# 4) SIMULATION : arbre compose avec les vignettes
# =============================================================
fig, ax = new_fig(12, 9)
ax.set_ylim(0, 9)
ax.text(6, 8.6, "Simulation  —  arbre compose a partir des cartes",
        ha="center", fontsize=16, fontweight="bold", color=INK)

def mini(ax, x, y, label, color, w=1.25, h=0.95):
    box(ax, x, y, w, h, label, color, ec=color, fs=9.5, alpha=0.9)
    return (x+w/2, y, x+w/2, y+h)

def trio_block(ax, cx, cy, e, ec_col, c, r, title, deduced=False):
    # ligne E + C => R, centree sur cx, sommet a cy
    gap = 0.18
    w = 1.25
    bx = cx - (1.5*w + gap)
    e_anchor = mini(ax, bx, cy, e, ec_col)
    mini(ax, bx+w+gap, cy, c, CABLE)
    ax.text(bx+2*w+1.4*gap, cy+0.45, "=>", fontsize=14, fontweight="bold", color=INK)
    r_anchor = mini(ax, bx+2*w+3*gap+0.4, cy, r, RECEP)
    ax.text(cx, cy+1.05, title, ha="center", fontsize=9.5, color=MUTE, fontweight="bold")
    # retourne ancre E (haut) et ancre R (bas) pour chainer
    return (e_anchor[2], e_anchor[3]), (r_anchor[0], r_anchor[1])

# D1
d1_e, d1_r = trio_block(ax, 6.0, 6.9, "Lion", EMET, "Liane", "Gazelle",
                        "node #1  ·  D1 racine  (E explicite)")
# D2 gauche : E = Gazelle (deduite)
d2_e, d2_r = trio_block(ax, 3.0, 4.4, "Gazelle", RECEP, "Riviere", "Elephant",
                        "node #2  ·  D2  (E deduite = R#1)", deduced=True)
# D2 droite : E = Gazelle (deduite)
d3_e, d3_r = trio_block(ax, 9.0, 4.4, "Gazelle", RECEP, "Liane", "Gazelle",
                        "node #3  ·  D2  (E deduite = R#1)", deduced=True)
# D3 sous D2 gauche : E = Elephant (deduite)
d4_e, d4_r = trio_block(ax, 3.0, 1.9, "Elephant", RECEP, "Liane", "Gazelle",
                        "node #4  ·  D3  (E deduite = R#2)", deduced=True)

# chainage : R(parent) -> E(enfant)
arrow(ax, d1_r[0], d1_r[1], d2_e[0], d2_e[1], color=RECEP, lw=2.6)
arrow(ax, d1_r[0], d1_r[1], d3_e[0], d3_e[1], color=RECEP, lw=2.6)
arrow(ax, d2_r[0], d2_r[1], d4_e[0], d4_e[1], color=RECEP, lw=2.6)

ax.text(6, 0.7, "Fleche verte = la receptrice du parent devient l'emettrice de l'enfant.",
        ha="center", fontsize=9.5, color=RECEP, fontweight="bold")
save(fig, "simulation_arbre.jpg")

# =============================================================
# Helpers partages pour les nouvelles figures
# =============================================================
def vignette(ax, x, y, label, color, role=None, w=1.5, h=1.8, correct=False, sub=None):
    """Carte facon UI : zone image coloree + bandeau role optionnel.
    correct=True -> ring orange + coche (bonne reponse de la grille)."""
    if correct:
        ring = FancyBboxPatch((x-0.10, y-0.10), w+0.20, h+0.20,
                              boxstyle="round,pad=0.02,rounding_size=0.14",
                              linewidth=4, edgecolor=BRAND, facecolor="none")
        ax.add_patch(ring)
    band = 0.42 if role else 0.0
    box(ax, x, y+band, w, h-band, "", color, ec=color, alpha=0.92)
    ax.text(x+w/2, y+band+(h-band)/2, label.upper(), ha="center", va="center",
            color="white", fontsize=10.5, fontweight="bold")
    if role:
        box(ax, x, y, w, band, role, "white", ec=color, tc=INK, fs=8)
    if sub:
        ax.text(x+w/2, y+h+0.14, sub, ha="center", va="bottom",
                color=INK, fontsize=9.5, fontweight="bold")
    if correct:
        ax.text(x+w-0.12, y+h-0.06, "✓", ha="right", va="top",
                color=BRAND, fontsize=15, fontweight="bold")
    return (x+w/2, y, x+w/2, y+h)

def unknown(ax, x, y, w=1.5, h=1.8):
    """Carte inconnue (la reponse a trouver) : cadre pointille + ?."""
    p = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.12",
                       linewidth=2.6, edgecolor=BRAND, facecolor="white",
                       linestyle=(0, (4, 3)))
    ax.add_patch(p)
    ax.text(x+w/2, y+h/2, "?", ha="center", va="center",
            color=BRAND, fontsize=30, fontweight="bold")
    return (x+w/2, y, x+w/2, y+h)

def choice_grid(ax, cx, ytop, items, w=1.45, h=1.5, hgap=0.4, vgap=0.7, cols=3):
    """Grille de choix 3x2 : items = [(label, color, correct), ...]."""
    total_w = cols*w + (cols-1)*hgap
    x0 = cx - total_w/2
    for i, (lbl, col, correct) in enumerate(items):
        r = i // cols; c = i % cols
        x = x0 + c*(w+hgap); y = ytop - h - r*(h+vgap)
        vignette(ax, x, y, lbl, col, w=w, h=h, correct=correct)

# =============================================================
# 5) MODELISATION COMPLETE : arbre riche + lecture D1 / D2
# =============================================================
fig, ax = new_fig(16, 11)
ax.set_xlim(0, 16); ax.set_ylim(0, 11)
ax.text(8, 10.6, "TRIALGO  —  modele complet : arbre de nodes + distances de jeu",
        ha="center", fontsize=19, fontweight="bold", color=INK)

def cnode(ax, cx, ytop, idx, depth, parent, e, c, r, deduced=False):
    w, h = 3.05, 1.12
    x = cx - w/2; y = ytop - h
    ec = BRAND if depth == 1 else MUTE
    box(ax, x, y, w, h, "", "white", ec=ec, tc=INK)
    ax.text(x+0.12, y+h-0.18, f"#{idx} · D{depth} · parent {parent}",
            ha="left", fontsize=7.8, color=MUTE, fontweight="bold")
    etxt = f"E:({e})" if deduced else f"E:{e}"
    ax.text(x+0.12, y+0.55, etxt, ha="left", fontsize=9,
            color=(RECEP if deduced else EMET), fontweight="bold")
    ax.text(x+0.12, y+0.32, f"C:{c}", ha="left", fontsize=9, color=CABLE, fontweight="bold")
    ax.text(x+0.12, y+0.10, f"R:{r}", ha="left", fontsize=9, color=RECEP, fontweight="bold")
    return (cx, y, cx, ytop)

n1 = cnode(ax, 8.0, 10.0, 1, 1, "NULL", "Lion", "Liane", "Gazelle")
n2 = cnode(ax, 4.0, 7.6, 2, 2, "#1", "Gazelle", "Riviere", "Elephant", deduced=True)
n3 = cnode(ax, 12.0, 7.6, 3, 2, "#1", "Gazelle", "Rocher", "Girafe", deduced=True)
n4 = cnode(ax, 1.9, 5.2, 4, 3, "#2", "Elephant", "Liane", "Antilope", deduced=True)
n5 = cnode(ax, 6.3, 5.2, 5, 3, "#2", "Elephant", "Rocher", "Buffle", deduced=True)
n6 = cnode(ax, 12.0, 5.2, 6, 3, "#3", "Girafe", "Riviere", "Hippo", deduced=True)
n7 = cnode(ax, 1.9, 2.8, 7, 4, "#4", "Antilope", "Riviere", "Gazelle", deduced=True)

for p, ch in [(n1,n2),(n1,n3),(n2,n4),(n2,n5),(n3,n6),(n4,n7)]:
    arrow(ax, p[0], p[1], ch[2], ch[3], color=RECEP, lw=2.2)

# encadres de lecture D1 / D2
box(ax, 8.6, 2.7, 6.8, 0.95, "", "white", ec=EMET, tc=INK)
ax.text(8.8, 3.42, "Lecture D1  (niveaux 1-6)", ha="left", fontsize=10.5,
        color=EMET, fontweight="bold")
ax.text(8.8, 2.95, "un node SEUL : on montre E + C, le joueur trouve R.",
        ha="left", fontsize=9.5, color=INK)
box(ax, 8.6, 1.45, 6.8, 0.95, "", "white", ec=RECEP, tc=INK)
ax.text(8.8, 2.17, "Lecture D2  (niveaux 7+)", ha="left", fontsize=10.5,
        color=RECEP, fontweight="bold")
ax.text(8.8, 1.70, "une ARETE parent->enfant : on montre (R1, C2), trouve R4.",
        ha="left", fontsize=9.5, color=INK)

ax.text(8, 0.55,
        "Bordure orange = racine (D1, emettrice explicite).  Fleche verte = R(parent) injectee comme E(enfant).  "
        "Profondeur bornee 1->5.",
        ha="center", fontsize=8.8, color=MUTE)
save(fig, "modelisation_03_complet.jpg")

# =============================================================
# 6) SIMULATION D1 : question simple E + C => ?
# =============================================================
fig, ax = new_fig(12, 9.5)
ax.set_ylim(0, 9.5)
ax.text(6, 9.05, "Simulation de jeu  —  Distance D1  (niveaux 1-6)",
        ha="center", fontsize=17, fontweight="bold", color=INK)
ax.text(6, 8.55, "On montre l'emettrice et le cable ; le joueur cherche la receptrice.",
        ha="center", fontsize=11, color=MUTE)

# enonce : E + C => ?
vignette(ax, 1.6, 6.3, "Lion", EMET, role="Emettrice", w=1.7, h=2.0)
ax.text(3.7, 7.1, "+", ha="center", fontsize=24, fontweight="bold", color=INK)
vignette(ax, 4.3, 6.3, "Liane", CABLE, role="Cable", w=1.7, h=2.0)
ax.text(6.55, 7.1, "=>", ha="center", fontsize=22, fontweight="bold", color=INK)
unknown(ax, 7.5, 6.3, w=1.7, h=2.0)

ax.text(6, 5.45, "Grille de choix  (3 x 2)  —  1 bonne reponse + 5 distracteurs",
        ha="center", fontsize=11.5, fontweight="bold", color=BRAND)
choice_grid(ax, 6.0, 5.0, [
    ("Gazelle", RECEP, True),  ("Elephant", RECEP, False), ("Girafe", RECEP, False),
    ("Antilope", RECEP, False),("Buffle", RECEP, False),   ("Hippo", RECEP, False),
])
ax.text(6, 0.4, "Bonne reponse cerclee : Gazelle = R du node (Lion + Liane => Gazelle).",
        ha="center", fontsize=9.5, color=MUTE)
save(fig, "simulation_D1.jpg")

# =============================================================
# 7) SIMULATION D2 : chainage (R1, C2) => ?
# =============================================================
fig, ax = new_fig(13, 10.5)
ax.set_xlim(0, 13); ax.set_ylim(0, 10.5)
ax.text(6.5, 10.05, "Simulation de jeu  —  Distance D2  (niveaux 7+)",
        ha="center", fontsize=17, fontweight="bold", color=INK)
ax.text(6.5, 9.55, "Chainage : la receptrice du 1er trio devient l'emettrice du 2e.",
        ha="center", fontsize=11, color=MUTE)

# Node1 complet (contexte) : Lion + Liane => Gazelle (R1)
ax.text(3.0, 8.9, "node #1", ha="center", fontsize=9.5, color=MUTE, fontweight="bold")
vignette(ax, 0.5, 7.0, "Lion", EMET, role="Emettrice", w=1.35, h=1.7)
ax.text(2.05, 7.7, "+", ha="center", fontsize=18, fontweight="bold", color=INK)
vignette(ax, 2.3, 7.0, "Liane", CABLE, role="Cable", w=1.35, h=1.7)
ax.text(3.85, 7.7, "=>", ha="center", fontsize=16, fontweight="bold", color=INK)
r1 = vignette(ax, 4.3, 7.0, "Gazelle", RECEP, role="R1", w=1.35, h=1.7)

# fleche de chainage R1 -> E du node2
arrow(ax, r1[0], r1[1], 2.0, 5.6, color=RECEP, lw=2.8)
ax.text(7.0, 6.55, "R1 devient l'EMETTRICE\ndu trio suivant", ha="left",
        fontsize=10, color=RECEP, fontweight="bold")

# Node2 presente au joueur : (Gazelle = R1) + Riviere => ?
ax.text(3.0, 5.5, "node #2  (presente au joueur)", ha="center",
        fontsize=9.5, color=MUTE, fontweight="bold")
vignette(ax, 0.5, 3.6, "Gazelle", RECEP, role="E = R1", w=1.35, h=1.7)
ax.text(2.05, 4.3, "+", ha="center", fontsize=18, fontweight="bold", color=INK)
vignette(ax, 2.3, 3.6, "Riviere", CABLE, role="Cable", w=1.35, h=1.7)
ax.text(3.85, 4.3, "=>", ha="center", fontsize=16, fontweight="bold", color=INK)
unknown(ax, 4.3, 3.6, w=1.35, h=1.7)

# grille de choix a droite
ax.text(9.7, 5.5, "Grille de choix (3 x 2)", ha="center", fontsize=11,
        fontweight="bold", color=BRAND)
choice_grid(ax, 9.7, 5.1, [
    ("Elephant", RECEP, True), ("Girafe", RECEP, False), ("Gazelle", RECEP, False),
    ("Antilope", RECEP, False),("Buffle", RECEP, False), ("Hippo", RECEP, False),
], w=1.25, h=1.3, hgap=0.3, vgap=0.55)

ax.text(6.5, 0.5,
        "Bonne reponse cerclee : Elephant = R4 du node #2 (Gazelle + Riviere => Elephant). "
        "Le joueur doit suivre la chaine.",
        ha="center", fontsize=9.3, color=MUTE)
save(fig, "simulation_D2.jpg")

# =============================================================
# 8) SIMULATION D3 : chaine a 3 maillons (R1 -> R4 -> R7)
# =============================================================
fig, ax = new_fig(14, 12)
ax.set_xlim(0, 14); ax.set_ylim(0, 12)
ax.text(7, 11.5, "Simulation de jeu  —  Distance D3  (chaine a 3 maillons)",
        ha="center", fontsize=17, fontweight="bold", color=INK)
ax.text(7, 11.0, "Chaque receptrice nourrit le trio suivant : R1 -> E2 puis R4 -> E3.",
        ha="center", fontsize=11, color=MUTE)

def trio(ax, ytop, e, ecol, erole, c, r, rrole, unknown_r=False):
    """Un trio E + C => R, ancre en haut a gauche (x=0.5)."""
    w, h = 1.3, 1.7
    y = ytop - h
    e_a = vignette(ax, 0.5, y, e, ecol, role=erole, w=w, h=h)
    ax.text(2.05, y+h/2, "+", ha="center", fontsize=18, fontweight="bold", color=INK)
    vignette(ax, 2.3, y, c, CABLE, role="Cable", w=w, h=h)
    ax.text(3.85, y+h/2, "=>", ha="center", fontsize=16, fontweight="bold", color=INK)
    if unknown_r:
        r_a = unknown(ax, 4.3, y, w=w, h=h)
    else:
        r_a = vignette(ax, 4.3, y, r, RECEP, role=rrole, w=w, h=h)
    return e_a, r_a  # ancres (cx,ybot,cx,ytop)

ax.text(3.0, 10.3, "node #1", ha="center", fontsize=10, color=MUTE, fontweight="bold")
e1, r1 = trio(ax, 10.1, "Lion", EMET, "Emettrice", "Liane", "Gazelle", "R1")

ax.text(3.0, 7.3, "node #2", ha="center", fontsize=10, color=MUTE, fontweight="bold")
e2, r2 = trio(ax, 7.1, "Gazelle", RECEP, "E = R1", "Riviere", "Elephant", "R4")

ax.text(3.4, 4.3, "node #3  (presente au joueur)", ha="center", fontsize=10,
        color=MUTE, fontweight="bold")
e3, r3 = trio(ax, 4.1, "Elephant", RECEP, "E = R4", "Rocher", None, None, unknown_r=True)

# chainage R1 -> E2, R4 -> E3
arrow(ax, r1[0], r1[1], e2[2], e2[3], color=RECEP, lw=2.8)
arrow(ax, r2[0], r2[1], e3[2], e3[3], color=RECEP, lw=2.8)
ax.text(6.1, 8.05, "R1 -> E2", ha="left", fontsize=10, color=RECEP, fontweight="bold")
ax.text(6.1, 5.05, "R4 -> E3", ha="left", fontsize=10, color=RECEP, fontweight="bold")

# grille de choix (droite)
ax.text(10.3, 8.6, "Grille de choix (3 x 2)", ha="center", fontsize=11.5,
        fontweight="bold", color=BRAND)
choice_grid(ax, 10.3, 8.1, [
    ("Girafe", RECEP, True),  ("Elephant", RECEP, False), ("Gazelle", RECEP, False),
    ("Antilope", RECEP, False),("Buffle", RECEP, False),  ("Hippo", RECEP, False),
], w=1.3, h=1.35, hgap=0.35, vgap=0.6)

ax.text(7, 0.6,
        "Bonne reponse cerclee : Girafe = R7 du node #3 (Elephant + Rocher => Girafe). "
        "Le joueur remonte 3 maillons.",
        ha="center", fontsize=9.3, color=MUTE)
save(fig, "simulation_D3.jpg")

print("DONE")
