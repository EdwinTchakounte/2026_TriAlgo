"""Convert ok_logo_use.jpeg into a PNG with transparent black background.

The source logo has a near-black background. We threshold the brightness :
pixels below `threshold` become fully transparent, pixels above keep their
original color but with an alpha proportional to brightness for a smooth
edge (avoids a hard halo around glowing parts of the logo).
"""

from PIL import Image
import os

SRC = "/home/tchakounte/Desktop/TriAlgo/ok_logo_use.jpeg"
DST = "/home/tchakounte/Desktop/TriAlgo/trialgo_admin/assets/images/logo.png"

THRESHOLD = 28      # pixels darker than this -> fully transparent
SOFT_RANGE = 22     # smooth alpha ramp between threshold and threshold+range


def main() -> None:
    img = Image.open(SRC).convert("RGB")
    px = img.load()
    w, h = img.size

    out = Image.new("RGBA", (w, h))
    out_px = out.load()

    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            # Luminance perceptual approx.
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if lum <= THRESHOLD:
                out_px[x, y] = (0, 0, 0, 0)
            elif lum <= THRESHOLD + SOFT_RANGE:
                ratio = (lum - THRESHOLD) / SOFT_RANGE
                alpha = int(255 * ratio)
                out_px[x, y] = (r, g, b, alpha)
            else:
                out_px[x, y] = (r, g, b, 255)

    os.makedirs(os.path.dirname(DST), exist_ok=True)
    out.save(DST, format="PNG", optimize=True)
    print(f"Saved: {DST}  ({os.path.getsize(DST) // 1024} KB)")


if __name__ == "__main__":
    main()
