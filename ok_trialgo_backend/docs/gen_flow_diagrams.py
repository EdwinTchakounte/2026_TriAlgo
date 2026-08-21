"""Generate upload + retrieval flow diagrams matching the TRIALGO backend architecture.

Style aligned with the admin app (dark studio palette).
Outputs :
  - upload_flow.jpg
  - retrieval_flow.jpg
"""

import os
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle

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

OUT_DIR = "/home/tchakounte/Desktop/TriAlgo/ok_trialgo_backend/docs"


def box(ax, x, y, w, h, text, *, fill=SURFACE, edge=BORDER, fc_text=TEXT,
        fs=9.5, fw="normal", lw=1.4, radius=0.22):
    p = FancyBboxPatch(
        (x, y), w, h,
        boxstyle=f"round,pad=0.02,rounding_size={radius}",
        linewidth=lw, edgecolor=edge, facecolor=fill,
    )
    ax.add_patch(p)
    ax.text(x + w / 2, y + h / 2, text,
            ha="center", va="center",
            color=fc_text, fontsize=fs, fontweight=fw)


def arrow(ax, x1, y1, x2, y2, color=BRAND, lw=1.8, dashed=False):
    style = "->" if dashed else "-|>"
    ls = (0, (4, 3)) if dashed else "solid"
    a = FancyArrowPatch(
        (x1, y1), (x2, y2),
        arrowstyle="-|>", mutation_scale=14,
        color=color, linewidth=lw, linestyle=ls,
    )
    ax.add_patch(a)


def numbered_step(ax, cx, cy, n, r=0.22, color=BRAND):
    c = Circle((cx, cy), r, facecolor=color, edgecolor=color)
    ax.add_patch(c)
    ax.text(cx, cy, str(n), ha="center", va="center",
            color="white", fontsize=10, fontweight="bold")


def title(ax, x, y, t, sub=None):
    ax.text(x, y, t, color=TEXT, fontsize=17, fontweight="bold")
    if sub:
        ax.text(x, y - 0.45, sub, color=TEXT_DIM, fontsize=10.5,
                fontstyle="italic")


# =====================================================================
# 1. UPLOAD FLOW
# =====================================================================

def make_upload_flow():
    fig = plt.figure(figsize=(20, 13), facecolor=BG)
    ax = fig.add_subplot(111)
    ax.set_xlim(0, 20)
    ax.set_ylim(0, 13)
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_facecolor(BG)

    title(ax, 1, 12.4,
          "FLUX D'UPLOAD - Cree une carte (image + metadata)",
          "POST /api/games/{gid}/cards   |   multipart/form-data   |   transaction unique")
    ax.plot([1, 19], [11.55, 11.55], color=BORDER, lw=0.7)

    # -------- CLIENT (gauche) --------
    box(ax, 0.6, 9.0, 4.5, 2.0,
        "FLUTTER ADMIN APP\n\n"
        "ImagePicker -> Uint8List\n"
        "Form : label, card_type, file",
        fill=SURFACE, edge=BORDER, fs=10, fw="bold")
    ax.text(2.85, 8.75, "1. compose la requete multipart",
            color=BRAND, fontsize=9, ha="center", style="italic")

    # Fleche client -> api (avec headers)
    arrow(ax, 5.2, 10.0, 7.8, 10.0)
    ax.text(6.5, 10.45,
            "POST + Authorization: Bearer <JWT>",
            color=TEXT_DIM, fontsize=8.5, ha="center")
    ax.text(6.5, 10.25,
            "Content-Type: multipart/form-data",
            color=TEXT_DIM, fontsize=8.5, ha="center")

    # -------- API (centre) --------
    box(ax, 7.9, 8.7, 5.0, 2.55,
        "FastAPI\nPOST /api/games/{gid}/cards",
        fill=SURFACE2, edge=BRAND, fs=11, fw="bold", lw=1.8)

    # 6 etapes a l'interieur du flow API
    y0 = 7.7
    steps = [
        ("get_current_admin (JWT + is_admin check)",        BLUE),
        ("Game.exists ?  +  cards limit (<=5 MB)",          PURPLE),
        ("detect_mime (magic bytes, anti spoof)",           YELLOW),
        ("Pillow : strip EXIF, resize <=1024, JPEG q=85",   GREEN),
        ("storage.save(game_id, bytes) -> object_key",      BRAND),
        ("INSERT cards  +  COMMIT  (sinon rollback + delete)", BRAND),
    ]
    for i, (label, color) in enumerate(steps):
        yy = y0 - i * 0.7
        numbered_step(ax, 1.4, yy, i + 2, r=0.22, color=color)
        box(ax, 1.85, yy - 0.30, 9.4, 0.6, label,
            fill=SURFACE, edge=color, fs=10, fw="normal")

    # Fleche de l'API vers le storage en bas-droite
    arrow(ax, 13.0, 9.4, 15.4, 7.7)

    # -------- STORAGE (droite) --------
    box(ax, 15.0, 8.7, 4.5, 2.55,
        "STORAGE  (CardStorage)\n\n"
        "Local FS  ou  MinIO/S3\n"
        "Layout : <game_id>/<uuid>.jpg",
        fill=SURFACE, edge=GREEN, fs=10, fw="bold", lw=1.6)
    ax.text(17.25, 8.45,
            "object_key opaque -> agnostique du backend",
            color=TEXT_DIM, fontsize=8.5, ha="center", style="italic")

    # -------- DB (bas-centre) --------
    box(ax, 7.9, 2.3, 5.0, 1.55,
        "POSTGRES (table cards)\n\n"
        "id  |  game_id  |  label  |  object_key\n"
        "  |  content_type  |  card_type  |  created_at",
        fill=SURFACE, edge=BLUE, fs=9.5, fw="bold")

    # API -> DB
    arrow(ax, 10.4, 8.65, 10.4, 3.9, color=BLUE)
    ax.text(10.6, 6.2, "INSERT", color=BLUE, fontsize=9.5,
            fontweight="bold", rotation=90)

    # ----- Bandeau cohérence -----
    box(ax, 0.6, 0.7, 18.7, 1.0,
        "GARANTIE DE COHERENCE  :  Le upload storage se fait AVANT le INSERT DB.\n"
        "Si COMMIT echoue (contrainte UNIQUE, FK invalide...)  ->  rollback DB + storage.delete(object_key)  =  aucune image orpheline",
        fill=BRAND + "1A", edge=BRAND, fc_text=TEXT, fs=11, fw="bold",
        radius=0.3, lw=1.6)

    # ----- Bloc resultat (cote droit bas) -----
    box(ax, 14.0, 4.1, 5.6, 3.3,
        "REPONSE 201 Created\n\n"
        '{\n'
        '  "id": "uuid...",\n'
        '  "label": "Lion",\n'
        '  "card_type": "emettrice",\n'
        '  "object_key": "uuid.jpg",\n'
        '  "image_url": "<URL publique>"\n'
        '}',
        fill=SURFACE2, edge=GREEN, fs=10, fw="normal", lw=1.4)

    arrow(ax, 12.9, 4.0, 14.0, 5.5, color=GREEN)
    ax.text(13.5, 4.4, "response", color=GREEN, fontsize=9, style="italic",
            fontweight="bold")

    # Fleche retour vers client (en haut)
    arrow(ax, 14.0, 7.4, 5.2, 9.0, color=GREEN, dashed=True)

    plt.tight_layout(pad=0.3)
    out = f"{OUT_DIR}/upload_flow.jpg"
    plt.savefig(out, dpi=170, facecolor=BG, bbox_inches="tight",
                pad_inches=0.2, format="jpg")
    plt.close(fig)
    print("Saved:", out)


# =====================================================================
# 2. RETRIEVAL FLOW
# =====================================================================

def make_retrieval_flow():
    fig = plt.figure(figsize=(20, 13), facecolor=BG)
    ax = fig.add_subplot(111)
    ax.set_xlim(0, 20)
    ax.set_ylim(0, 13)
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_facecolor(BG)

    title(ax, 1, 12.4,
          "FLUX DE RECUPERATION - Charger l'image d'une carte",
          "Deux chemins selon STORAGE_BACKEND  :  local (FastAPI sert)  |  s3 (URL directe MinIO/S3)")
    ax.plot([1, 19], [11.55, 11.55], color=BORDER, lw=0.7)

    # -------- CLIENT (gauche) --------
    box(ax, 0.6, 9.0, 4.5, 2.0,
        "CLIENT\n(Flutter admin OU jeu)\n\nCardThumbnail / Image.network\n"
        "rend la carte avec image_url",
        fill=SURFACE, edge=BORDER, fs=10, fw="bold")

    # GET /api/games/{gid}/cards
    arrow(ax, 5.2, 10.4, 7.8, 10.4)
    ax.text(6.5, 10.65, "GET cards (liste)",
            color=TEXT_DIM, fontsize=9, ha="center", fontweight="bold")

    # FastAPI
    box(ax, 7.9, 9.3, 5.0, 1.85,
        "FastAPI\nGET /api/games/{gid}/cards\n\n"
        "construit CardOut + image_url",
        fill=SURFACE2, edge=BRAND, fs=10, fw="bold")

    # Reponse JSON contenant image_url
    arrow(ax, 7.8, 9.7, 5.2, 9.3, color=GREEN, dashed=True)
    ax.text(6.5, 9.0, '{ ..., "image_url": "..." }',
            color=GREEN, fontsize=8.5, ha="center", style="italic")

    # Separateur "Apres reception URL, le client doit charger l'image"
    ax.plot([1, 19], [7.5, 7.5], color=BORDER, lw=0.6, linestyle="dashed")
    ax.text(10, 7.65, "Le client a maintenant l'URL et doit telecharger le binaire",
            color=TEXT_DIM, fontsize=10, ha="center", fontweight="bold",
            style="italic")

    # ============================================
    # PATH A  :  STORAGE_BACKEND = local
    # ============================================
    box(ax, 0.6, 5.6, 9.0, 1.0,
        "MODE A  -  STORAGE_BACKEND = local",
        fill=BLUE + "22", edge=BLUE, fc_text=BLUE, fs=12, fw="bold", lw=1.6)

    # client
    box(ax, 0.6, 3.5, 2.5, 1.4, "CLIENT", fill=SURFACE, edge=BORDER, fs=10, fw="bold")

    # GET image to FastAPI
    arrow(ax, 3.2, 4.2, 5.8, 4.2, color=BLUE)
    ax.text(4.5, 4.5, "GET /api/cards/file/<key>",
            color=BLUE, fontsize=9, ha="center", fontweight="bold")

    # FastAPI streams from disk
    box(ax, 5.9, 3.5, 3.5, 1.4,
        "FastAPI\nFileResponse(\n  /data/cards/<key>\n)",
        fill=SURFACE2, edge=BRAND, fs=9.5, fw="normal")

    # API check : path traversal protect + cache-control
    box(ax, 0.6, 1.8, 9.0, 1.3,
        "API verifie : path reste dans /data  +  ajoute Cache-Control: public, immutable, max-age=1y\n"
        "Inconvenient : FastAPI consomme du CPU/bande passante a chaque requete",
        fill=SURFACE, edge=BLUE, fs=9.5, fc_text=TEXT_DIM, lw=1.2)

    # ============================================
    # PATH B  :  STORAGE_BACKEND = s3 (recommande)
    # ============================================
    box(ax, 10.4, 5.6, 9.0, 1.0,
        "MODE B  -  STORAGE_BACKEND = s3   (recommande prod)",
        fill=GREEN + "22", edge=GREEN, fc_text=GREEN, fs=12, fw="bold", lw=1.6)

    # client
    box(ax, 10.4, 3.5, 2.5, 1.4, "CLIENT", fill=SURFACE, edge=BORDER, fs=10, fw="bold")

    # GET image DIRECT to MinIO
    arrow(ax, 13.0, 4.2, 15.8, 4.2, color=GREEN)
    ax.text(14.4, 4.5,
            "GET http://minio:9000/<bucket>/<key>",
            color=GREEN, fontsize=9, ha="center", fontweight="bold")

    # MinIO
    box(ax, 15.9, 3.5, 3.5, 1.4,
        "MINIO / S3\nbucket trialgo-cards\n(anonymous download)",
        fill=SURFACE2, edge=GREEN, fs=9.5, fw="normal")

    box(ax, 10.4, 1.8, 9.0, 1.3,
        "FastAPI ne participe PAS au telechargement  =  scaling horizontal gratuit\n"
        "Cache CDN-friendly (object_key UUID = immutable)  -  switch prod vers AWS S3/R2 sans changer le code",
        fill=SURFACE, edge=GREEN, fs=9.5, fc_text=TEXT_DIM, lw=1.2)

    # Bandeau bas
    box(ax, 0.6, 0.35, 18.7, 1.0,
        "AGNOSTIQUE DU BACKEND  :  CardStorage.public_url(object_key) calcule l'URL\n"
        "selon le mode  ->  le client n'a JAMAIS a connaitre la difference local vs s3",
        fill=BRAND + "1A", edge=BRAND, fc_text=TEXT, fs=11, fw="bold",
        radius=0.3, lw=1.6)

    plt.tight_layout(pad=0.3)
    out = f"{OUT_DIR}/retrieval_flow.jpg"
    plt.savefig(out, dpi=170, facecolor=BG, bbox_inches="tight",
                pad_inches=0.2, format="jpg")
    plt.close(fig)
    print("Saved:", out)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    make_upload_flow()
    make_retrieval_flow()
