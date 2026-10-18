"""ZOKY-113: generate versioned ZOKY web icons and iOS launch images.

Usage (from web/): python3 -I tools/zoky113_generate_web_icons.py <icon-1024.png> <wordmark.png> <old-splash-dir> <out-dir>
Sources (docs/zoky-foundation):
  design-reference/zoky/zoky-app-icon-1024.png  (Founder-chosen full-bleed icon)
  zoky_app/assets/images/zoky_wordmark.png      (original transparent wordmark)
"""
import sys
from pathlib import Path

from PIL import Image

icon_src, wordmark_src, old_splash_dir, out_dir = map(Path, sys.argv[1:5])
out_dir.mkdir(parents=True, exist_ok=True)
(out_dir / "splash").mkdir(exist_ok=True)

icon = Image.open(icon_src).convert("RGB")
wordmark = Image.open(wordmark_src).convert("RGBA")
wordmark = wordmark.crop(wordmark.getbbox())


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def vertical_gradient(width, height, stops):
    """stops: [(offset 0..1, '#RRGGBB'), ...] top to bottom."""
    column = Image.new("RGB", (1, height))
    px = column.load()
    stops = [(o, hex_rgb(c)) for o, c in stops]
    for y in range(height):
        t = y / max(1, height - 1)
        for (o0, c0), (o1, c1) in zip(stops, stops[1:]):
            if o0 <= t <= o1:
                f = 0 if o1 == o0 else (t - o0) / (o1 - o0)
                px[0, y] = tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
                break
    return column.resize((width, height), Image.NEAREST)


def paste_wordmark(canvas, width_px, center):
    ratio = width_px / wordmark.width
    mark = wordmark.resize((round(wordmark.width * ratio), round(wordmark.height * ratio)), Image.LANCZOS)
    canvas.paste(mark, (round(center[0] - mark.width / 2), round(center[1] - mark.height / 2)), mark)


# Square icons: the approved full-bleed artwork, resized only.
for size, name in [(32, "icon-32-v1.png"), (192, "icon-192-v1.png"), (512, "icon-512-v1.png"),
                   (180, "apple-touch-icon-180-v1.png")]:
    icon.resize((size, size), Image.LANCZOS).save(out_dir / name, optimize=True)

# Maskable: same background gradient as the logo, wordmark inside the 80% safe circle.
LOGO_BG = [(0, "#FF5AA8"), (0.35, "#F7287A"), (1, "#F21967")]
maskable = vertical_gradient(512, 512, LOGO_BG)
paste_wordmark(maskable, 320, (256, 256))
maskable.save(out_dir / "icon-512-maskable-v1.png", optimize=True)

# White wordmark for the in-app splash (200 CSS px wide, 3x).
w = 600
wordmark.resize((w, round(wordmark.height * w / wordmark.width)), Image.LANCZOS).save(
    out_dir / "wordmark-white-v1.png", optimize=True)

# iOS launch images: flat status-bar strip (height taken from the previous
# launch image of the same size) + header gradient, wordmark centred below
# the strip where the in-app splash lands.
HEADER = [(0, "#F93384"), (0.35, "#F72C7E"), (1, "#EE226E")]
SIZES = [
    (440, 956, 3), (430, 932, 3), (428, 926, 3), (420, 912, 3), (414, 896, 3), (414, 896, 2),
    (414, 736, 3), (402, 874, 3), (393, 852, 3), (390, 844, 3), (375, 812, 3), (360, 780, 3), (375, 667, 2), (320, 568, 2),
    (1024, 1366, 2), (834, 1194, 2), (820, 1180, 2), (810, 1080, 2), (744, 1133, 2),
]
for css_w, css_h, dpr in SIZES:
    pw, ph = css_w * dpr, css_h * dpr
    old = Image.open(old_splash_dir / f"launch-{pw}x{ph}.png").convert("RGB")
    column = [old.getpixel((pw // 2, y)) for y in range(ph)]
    strip = 0
    while strip < ph and column[strip] == column[0]:
        strip += 1
    canvas = Image.new("RGB", (pw, ph), hex_rgb(HEADER[0][1]))
    canvas.paste(vertical_gradient(pw, ph - strip, HEADER), (0, strip))
    paste_wordmark(canvas, 200 * dpr, (pw / 2, strip + (ph - strip) / 2))
    canvas.save(out_dir / "splash" / f"launch-{pw}x{ph}.png", optimize=True)
    print(f"launch-{pw}x{ph}.png strip={strip}")
