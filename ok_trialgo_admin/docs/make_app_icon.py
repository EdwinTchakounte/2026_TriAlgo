"""Generate a 1024x1024 launcher icon for TRIALGO admin.

Layout :
  - Dark anthracite background (#121419) matching app canvas
  - Centered logo (PNG with transparency) scaled to fit a safe zone
  - Soft orange brand glow behind the logo for that "neon studio" feel

Output : assets/icon/icon.png (consumed by flutter_launcher_icons).
"""

from PIL import Image, ImageDraw, ImageFilter
import os

LOGO = '/home/tchakounte/Desktop/TriAlgo/trialgo_admin/assets/images/logo.png'
OUT  = '/home/tchakounte/Desktop/TriAlgo/trialgo_admin/assets/icon/icon.png'
SIZE = 1024
SAFE_RATIO = 0.78        # logo occupies ~78% of icon (Android safe zone)
BG = (18, 20, 25, 255)   # #121419
BRAND = (255, 107, 53)


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)

    canvas = Image.new('RGBA', (SIZE, SIZE), BG)

    # Soft brand glow : draw a radial-ish glow by stacking blurred orange
    # ellipses, then composite under the logo.
    glow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    # Main glow blob.
    cx, cy = SIZE // 2, SIZE // 2
    for r, alpha in [(SIZE // 2, 60), (SIZE // 2 - 80, 100), (SIZE // 2 - 180, 140)]:
        draw.ellipse(
            (cx - r, cy - r, cx + r, cy + r),
            fill=(*BRAND, alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=90))

    canvas = Image.alpha_composite(canvas, glow)

    # Logo : load + scale to safe zone keeping aspect.
    logo = Image.open(LOGO).convert('RGBA')
    lw, lh = logo.size
    max_w = int(SIZE * SAFE_RATIO)
    max_h = int(SIZE * SAFE_RATIO)
    ratio = min(max_w / lw, max_h / lh)
    nw, nh = int(lw * ratio), int(lh * ratio)
    logo = logo.resize((nw, nh), Image.LANCZOS)

    # Paste centered.
    pos = ((SIZE - nw) // 2, (SIZE - nh) // 2)
    canvas.alpha_composite(logo, dest=pos)

    canvas.save(OUT, format='PNG', optimize=True)
    print(f'Saved: {OUT}  ({os.path.getsize(OUT) // 1024} KB)')


if __name__ == '__main__':
    main()
