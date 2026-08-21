"""Generate a diagram of email flows : welcome+confirm, reset password.

Shows the actors (client app, backend, DB, Brevo) and the sequence
of messages with rough timings.
"""

import os
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

# ---- palette (same as endpoints_overview) ----
BG       = "#121419"
SURFACE  = "#1C1F26"
BORDER   = "#323845"
TEXT     = "#F3F5F9"
TEXT_DIM = "#9AA1AE"
BRAND    = "#FF6B35"
CYAN     = "#7FDCFF"
GREEN    = "#66BB6A"
PINK     = "#EC407A"


def box(ax, x, y, w, h, text, *, fill=SURFACE, edge=BORDER, fc_text=TEXT,
        fs=10, fw="normal", lw=1.4, radius=0.18, ha="center"):
    p = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.01,rounding_size={radius}",
        linewidth=lw, edgecolor=edge, facecolor=fill,
    )
    ax.add_patch(p)
    tx = x + w / 2 if ha == "center" else x + 0.2
    ax.text(tx, y + h / 2, text,
            ha=ha, va="center", color=fc_text, fontsize=fs, fontweight=fw)


def arrow(ax, x1, y, x2, label, color=TEXT_DIM, dashed=False):
    style = "dashed" if dashed else "solid"
    a = FancyArrowPatch(
        (x1, y), (x2, y),
        arrowstyle="-|>", mutation_scale=14,
        color=color, lw=1.5, linestyle=style,
    )
    ax.add_patch(a)
    ax.text((x1 + x2) / 2, y + 0.16, label,
            ha="center", va="bottom", color=color, fontsize=9)


def lifeline(ax, x, label, color, h_top, h_bot):
    """Vertical lane for an actor."""
    box(ax, x - 1.0, h_top - 0.4, 2.0, 0.5, label,
        fill=color + "26", edge=color, fc_text=color, fw="bold", fs=11)
    ax.plot([x, x], [h_top - 0.4, h_bot], color=BORDER, lw=0.7, linestyle="dashed")


# ============================================================
# RENDER
# ============================================================
fig = plt.figure(figsize=(18, 14), facecolor=BG)
ax = fig.add_subplot(111)
ax.set_xlim(0, 18)
ax.set_ylim(0, 14)
ax.set_aspect("equal")
ax.axis("off")
ax.set_facecolor(BG)

# Title
ax.text(9, 13.5, "TRIALGO - Email Flows (Brevo)",
        ha="center", va="center", color=TEXT, fontsize=18, fontweight="bold")
ax.text(9, 13.05,
        "Welcome+Confirm  |  Password Reset  |  Notifications transactionnelles",
        ha="center", va="center", color=TEXT_DIM, fontsize=11, fontstyle="italic")
ax.plot([1, 17], [12.7, 12.7], color=BORDER, lw=0.7)

# Lanes (actors)
CLIENT_X  = 3
API_X     = 7
DB_X      = 11
BREVO_X   = 15

# -------- Flow 1 : WELCOME + CONFIRM --------
ax.text(9, 12.3, "1. WELCOME + CONFIRM EMAIL (a l'inscription)",
        ha="center", va="center", color=CYAN, fontsize=13, fontweight="bold")

top1, bot1 = 12.0, 8.0
lifeline(ax, CLIENT_X, "Client (Flutter)", CYAN, top1, bot1)
lifeline(ax, API_X, "Backend FastAPI", BRAND, top1, bot1)
lifeline(ax, DB_X, "Postgres", GREEN, top1, bot1)
lifeline(ax, BREVO_X, "Brevo API", PINK, top1, bot1)

arrow(ax, CLIENT_X, 11.4, API_X, "POST /register {email,password}")
arrow(ax, API_X,    11.0, DB_X,  "INSERT users + email_preferences")
arrow(ax, API_X,    10.6, DB_X,  "INSERT email_tokens (purpose=confirm)")
arrow(ax, API_X,    10.2, CLIENT_X, "201 {user, tokens}  -> auto-login", color=GREEN)
arrow(ax, API_X,     9.8, BREVO_X, "POST /v3/smtp/email (welcome_confirm)", color=PINK, dashed=True)
arrow(ax, BREVO_X,   9.4, API_X,   "200 messageId", color=PINK, dashed=True)
ax.text(API_X + 0.1, 9.05, "(BackgroundTasks)", color=TEXT_DIM, fontsize=8, style="italic")

arrow(ax, BREVO_X, 8.65, CLIENT_X, "Email contenant le lien /confirm-email?token=...", color=CYAN)
arrow(ax, CLIENT_X, 8.25, API_X,   "POST /confirm-email {token}")
arrow(ax, API_X,    8.15, DB_X,    "verify_and_consume", color=GREEN)

# -------- Flow 2 : PASSWORD RESET --------
ax.text(9, 7.6, "2. PASSWORD RESET (oubli mot de passe)",
        ha="center", va="center", color=BRAND, fontsize=13, fontweight="bold")

top2, bot2 = 7.3, 3.5
lifeline(ax, CLIENT_X, "Client (Flutter)", CYAN, top2, bot2)
lifeline(ax, API_X, "Backend FastAPI", BRAND, top2, bot2)
lifeline(ax, DB_X, "Postgres", GREEN, top2, bot2)
lifeline(ax, BREVO_X, "Brevo API", PINK, top2, bot2)

arrow(ax, CLIENT_X, 6.7, API_X,  "POST /forgot-password {email}")
arrow(ax, API_X,    6.3, DB_X,   "SELECT user (404? ne fuit pas)", color=GREEN)
arrow(ax, API_X,    5.9, DB_X,   "INSERT email_tokens (purpose=reset, TTL 1h)")
arrow(ax, API_X,    5.5, CLIENT_X, "200 {ok:true}  (toujours, anti-enum)", color=GREEN)
arrow(ax, API_X,    5.1, BREVO_X, "POST /v3/smtp/email (password_reset)", color=PINK, dashed=True)

arrow(ax, BREVO_X, 4.5, CLIENT_X, "Email avec lien /reset-password?token=...", color=CYAN)
arrow(ax, CLIENT_X, 4.1, API_X,   "POST /reset-password {token, new_password}")
arrow(ax, API_X,    3.85, DB_X,   "verify_and_consume + UPDATE users.password_hash", color=GREEN)
arrow(ax, API_X,    3.6, BREVO_X, "POST password_changed mail (notif securite)", color=PINK, dashed=True)

# -------- Notes box --------
box(ax, 1.0, 0.4, 16.0, 2.8,
    "SECURITE & DESIGN\n\n"
    "- Tokens : 32 bytes urlsafe (secrets.token_urlsafe). Stockes en SHA-256 (jamais le clair en DB).\n"
    "- Single-use : used_at marque la consommation, replay impossible.\n"
    "- TTL : 48h pour confirm (user peut tarder), 60min pour reset (best practice secu).\n"
    "- Anti-enumeration : /forgot-password et /resend-confirmation renvoient toujours 200 (qu'on trouve\n"
    "  l'email ou pas), pour ne pas permettre a un attaquant de deviner les comptes existants.\n"
    "- BackgroundTasks : l'envoi mail ne bloque jamais la reponse HTTP. Si Brevo down, register reussit\n"
    "  quand meme ; le user pourra demander un /resend-confirmation plus tard.\n"
    "- DRY_RUN : si BREVO_API_KEY est vide, on log-only (utile en dev sans credentials).",
    fill=SURFACE, edge=BRAND, fs=10, fw="normal", ha="left", lw=1.4)

plt.tight_layout(pad=0.4)
out = "/home/tchakounte/Desktop/TriAlgo/ok_trialgo_backend/docs/mail_flows.jpg"
os.makedirs(os.path.dirname(out), exist_ok=True)
plt.savefig(out, dpi=170, facecolor=BG, bbox_inches="tight",
            pad_inches=0.2, format="jpg")
plt.close(fig)
print("Saved:", out)
