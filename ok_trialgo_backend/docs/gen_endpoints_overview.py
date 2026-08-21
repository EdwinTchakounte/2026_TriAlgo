"""Generate an overview diagram of all backend endpoints implemented.

Groups by domain (Meta, Auth, Public, Games, Cards, Nodes, Profile,
Codes, UserGames, Sessions, Deck, PlayedNodes, Stars, Collective,
Leaderboard, AdminUsers) with columns : method | path | auth required | notes.

Re-run with `python docs/gen_endpoints_overview.py` whenever new
endpoints are added so the diagram stays in sync.
"""

import os
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

# ------ palette ------
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
CYAN     = "#7FDCFF"
PINK     = "#EC407A"
GOLD     = "#FFB300"

METHOD_COLORS = {
    "GET":    BLUE,
    "POST":   GREEN,
    "PATCH":  YELLOW,
    "DELETE": RED,
}

AUTH_COLORS = {
    "-":          TEXT_DIM,
    "user":       BLUE,
    "admin":      BRAND,
    "hybrid":     PURPLE,
    "refresh JWT": CYAN,
}


def box(ax, x, y, w, h, text, *, fill=SURFACE, edge=BORDER, fc_text=TEXT,
        fs=9.5, fw="normal", lw=1.4, radius=0.18, ha="center"):
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
    ax.text(x, y, text, color=color, fontsize=13.5,
            fontweight="bold", ha="left", va="center")


# ============================================================
# DATA  -  tous les endpoints implementes
# ============================================================
GROUPS = [
    ("META", TEXT_DIM, [
        ("GET", "/healthz", "-", "Sonde docker / load balancer"),
        ("GET", "/docs",    "-", "OpenAPI auto (FastAPI Swagger)"),
    ]),
    ("AUTH", BRAND, [
        ("POST", "/api/auth/register",              "-",           "1er = admin, auto-login + mail welcome"),
        ("POST", "/api/auth/login",                 "-",           "Renvoie (access, refresh) JWT"),
        ("POST", "/api/auth/refresh",               "refresh JWT", "Rafraichit l'access"),
        ("GET",  "/api/auth/me",                    "user",        "Profil minimal (id, email, is_admin)"),
        ("POST", "/api/auth/confirm-email",         "-",           "Consomme token + mail welcome final"),
        ("POST", "/api/auth/resend-confirmation",   "-",           "Renvoie mail confirm (anti-enum)"),
        ("POST", "/api/auth/forgot-password",       "-",           "Envoie mail reset (anti-enum 200)"),
        ("POST", "/api/auth/reset-password",        "-",           "Change mdp + mail notif securite"),
    ]),
    ("PUBLIC (no auth)", CYAN, [
        ("GET", "/api/public/games",             "-", "Games is_active=true uniquement"),
        ("GET", "/api/public/games/{id}",        "-", "Detail game actif"),
        ("GET", "/api/public/games/{id}/cards",  "-", "Cartes (sans card_type leak)"),
    ]),
    ("GAMES (admin + hybrid)", PURPLE, [
        ("GET",    "/api/games",         "hybrid", "Admin: tous ; user: actifs"),
        ("POST",   "/api/games",         "admin",  "Cree un nouveau jeu"),
        ("GET",    "/api/games/{id}",    "hybrid", "Idem hybrid sur is_active"),
        ("PATCH",  "/api/games/{id}",    "admin",  "Update partiel"),
        ("DELETE", "/api/games/{id}",    "admin",  "Supprime + cascade"),
    ]),
    ("CARDS", BLUE, [
        ("GET",    "/api/games/{gid}/cards",         "-",     "Liste cartes + image_url"),
        ("POST",   "/api/games/{gid}/cards",         "admin", "Multipart : label + type + file"),
        ("PATCH",  "/api/cards/{id}",                "admin", "Update label/type"),
        ("DELETE", "/api/cards/{id}",                "admin", "Supprime carte + fichier"),
        ("GET",    "/api/cards/file/{key:path}",     "-",     "Sert le binaire (mode LOCAL)"),
    ]),
    ("NODES (fusions) - admin only", GREEN, [
        ("GET",    "/api/games/{gid}/nodes",              "admin", "Liste fusions (revele les reponses)"),
        ("GET",    "/api/games/{gid}/nodes/next-index",   "admin", "MAX+1 (wizard admin)"),
        ("POST",   "/api/games/{gid}/nodes",              "admin", "Cree fusion + valide invariants"),
        ("DELETE", "/api/nodes/{id}",                     "admin", "Supprime + cascade descendants"),
        ("POST",   "/api/games/{gid}/nodes/analyze",      "admin", "Analyse 3 cartes (admin only)"),
    ]),
    ("PROFILE joueur", PINK, [
        ("GET",   "/api/me/profile",  "user", "username + avatar + selected_game + wallet"),
        ("PATCH", "/api/me/profile",  "user", "Update username/avatar/selected_game"),
    ]),
    ("ACTIVATION CODES (joueur + admin)", GOLD, [
        ("POST",   "/api/codes/activate",                "user",  "5 cas : success + 4 erreurs (invalid/blocked/...)"),
        ("GET",    "/api/admin/codes",                   "admin", "Liste paginated"),
        ("POST",   "/api/admin/codes",                   "admin", "Cree un code"),
        ("GET",    "/api/admin/codes/{code}",            "admin", "Detail"),
        ("PATCH",  "/api/admin/codes/{code}",            "admin", "is_active / reset_assignment (SAV)"),
        ("DELETE", "/api/admin/codes/{code}",            "admin", "Supprime"),
    ]),
    ("USER GAMES (etat par jeu)", BLUE, [
        ("GET", "/api/me/games",          "user", "Liste de tous les jeux actives (refill applique)"),
        ("GET", "/api/me/games/{gid}",    "user", "Detail d'un jeu (vies + level + score)"),
    ]),
    ("SESSIONS HISTORY (parties)", GREEN, [
        ("POST", "/api/me/sessions", "user", "INSERT partie + UPDATE total_score/level/lives"),
        ("GET",  "/api/me/sessions", "user", "Historique paginated (filtre game_id ok)"),
    ]),
    ("DECK (galerie)", PURPLE, [
        ("POST", "/api/me/unlocked-cards",   "user", "Unlock carte (idempotent)"),
        ("GET",  "/api/me/unlocked-cards",   "user", "Deck par game_id (label + image)"),
    ]),
    ("PLAYED NODES (anti-doublon)", YELLOW, [
        ("POST",   "/api/me/played-nodes",   "user", "Marque tracking_key (idempotent)"),
        ("GET",    "/api/me/played-nodes",   "user", "Liste tracking_keys jouees"),
        ("DELETE", "/api/me/played-nodes",   "user", "Reset pour ce jeu"),
    ]),
    ("STARS (wallet economie)", GOLD, [
        ("GET",  "/api/me/stars",                       "user", "Wallet apres regen (1 etoile / 5min)"),
        ("POST", "/api/me/stars/exchange-for-life",     "user", "10 etoiles -> 1 vie (atomique)"),
    ]),
    ("COLLECTIVE (mode anim)", CYAN, [
        ("POST", "/api/games/{gid}/verify-collective", "user", "Verifie un node_index + resout labels"),
    ]),
    ("LEADERBOARD + STATS", PINK, [
        ("GET", "/api/games/{gid}/leaderboard", "user", "Top users sur user_games.total_score"),
        ("GET", "/api/me/stats",                "user", "Agregats perso (best, completed, etc.)"),
    ]),
    ("ADMIN USERS", BRAND, [
        ("GET",   "/api/admin/users",                  "admin", "Liste paginated"),
        ("GET",   "/api/admin/users/{id}",             "admin", "Detail"),
        ("POST",  "/api/admin/users/{id}/promote",     "admin", "Toggle is_admin + mail"),
        ("PATCH", "/api/admin/users/{id}",             "admin", "Active/desactive + mail si off"),
    ]),
]


# ============================================================
# RENDER
# ============================================================
total_rows = sum(len(rows) for _, _, rows in GROUPS)
height = 5.0 + total_rows * 0.6 + len(GROUPS) * 0.8 + 3.5

fig = plt.figure(figsize=(20, height), facecolor=BG)
ax = fig.add_subplot(111)
ax.set_xlim(0, 20)
ax.set_ylim(0, height)
ax.set_aspect("equal")
ax.axis("off")
ax.set_facecolor(BG)

top = height - 0.6
ax.text(10, top, "BACKEND TRIALGO  -  Vue d'ensemble des endpoints",
        ha="center", va="center",
        color=TEXT, fontsize=18, fontweight="bold")
ax.text(10, top - 0.45,
        "ok_trialgo_backend  |  FastAPI + Postgres + MinIO + Brevo  |  Auth JWT  |  Joueur porte depuis Supabase",
        ha="center", va="center",
        color=TEXT_DIM, fontsize=11, fontstyle="italic")
ax.plot([1, 19], [top - 0.85, top - 0.85], color=BORDER, lw=0.7)

header_y = top - 1.4
box(ax, 1.0,  header_y - 0.3, 1.2, 0.55, "METHODE",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold")
box(ax, 2.3,  header_y - 0.3, 9.5, 0.55, "PATH",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold", ha="left")
box(ax, 11.9, header_y - 0.3, 1.7, 0.55, "AUTH",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold")
box(ax, 13.7, header_y - 0.3, 5.4, 0.55, "NOTES",
    fill=SURFACE2, edge=BORDER, fs=9.5, fw="bold", ha="left")

y = header_y - 0.8
for name, color, rows in GROUPS:
    section_title(ax, 1.0, y, name, color)
    ax.text(19.0, y, f"{len(rows)} endpoints",
            color=TEXT_DIM, fontsize=9.5, ha="right",
            fontweight="bold", style="italic")
    y -= 0.45

    for method, path, auth, note in rows:
        chip(ax, 1.0, y - 0.27, 1.2, 0.5, method, METHOD_COLORS[method])
        box(ax, 2.3, y - 0.27, 9.5, 0.5, path,
            fill=SURFACE, edge=BORDER, fs=10, fw="normal", ha="left")
        auth_key = auth if auth in AUTH_COLORS else "user"
        chip(ax, 11.9, y - 0.27, 1.7, 0.5, auth, AUTH_COLORS[auth_key])
        box(ax, 13.7, y - 0.27, 5.4, 0.5, note,
            fill=SURFACE, edge=BORDER, fc_text=TEXT_DIM, fs=9.5, ha="left")
        y -= 0.6

    y -= 0.1
    ax.plot([1, 19], [y, y], color=BORDER, lw=0.5, linestyle="dashed")
    y -= 0.35

# Footer
y_box = 0.4

box(ax, 1.0, y_box, 5.8, 2.8,
    "INVARIANTS DB\n\n"
    "- depth in [1..5]\n"
    "- (emettrice IS NULL) XOR (parent IS NULL)\n"
    "- node_index unique par game\n"
    "- CASCADE games -> cards/nodes/sessions/codes\n"
    "- CHECK lives 0..max_lives + stars 0..stars_max\n"
    "- UNIQUE (assigned_to, game_id) sur codes",
    fill=SURFACE, edge=BRAND, fs=9, fw="normal", ha="left", lw=1.4)

box(ax, 7.1, y_box, 5.8, 2.8,
    "ECONOMIE JOUEUR\n\n"
    "- Refill vies : 1 / 30 min, plafond max_lives\n"
    "- Regen etoiles : 1 / 5 min, plafond 50\n"
    "- Exchange : 10 etoiles = 1 vie (atomique)\n"
    "- Score session : passed -> level+1 ; sinon lives-1\n"
    "- Stars 0-3 fin de partie = cosmetique (vs wallet)\n"
    "- Activation code : 3 changements device max",
    fill=SURFACE, edge=GREEN, fs=9, fw="normal", ha="left", lw=1.4)

box(ax, 13.2, y_box, 5.9, 2.8,
    "EMAIL (Brevo) + STORAGE\n\n"
    "- httpx async + DRY_RUN si BREVO_API_KEY vide\n"
    "- 8 templates : welcome, confirm, reset, password_changed,\n"
    "  session_summary, new_game, admin_promoted, account_deactivated\n"
    "- Tokens email : SHA-256 + TTL (60min reset / 48h confirm)\n"
    "- Storage cartes : MinIO/S3 (POST multipart atomique)\n"
    "- Pillow : strip EXIF + resize 1024 + JPEG q85",
    fill=SURFACE, edge=CYAN, fs=9, fw="normal", ha="left", lw=1.4)

plt.tight_layout(pad=0.4)
out = "/home/tchakounte/Desktop/TriAlgo/ok_trialgo_backend/docs/endpoints_overview.jpg"
os.makedirs(os.path.dirname(out), exist_ok=True)
plt.savefig(out, dpi=170, facecolor=BG, bbox_inches="tight",
            pad_inches=0.2, format="jpg")
plt.close(fig)
print("Saved:", out)
