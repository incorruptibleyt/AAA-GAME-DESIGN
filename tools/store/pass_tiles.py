"""Puts the Crypt Pass tile renders (render_art.gd shot=tile_*) on glowing backgrounds.

    python3 tools/store/pass_tiles.py <render folder> <output folder, usually art/ui>
"""
import sys
from PIL import Image, ImageDraw, ImageFilter
src, out = sys.argv[1], sys.argv[2]
W, H = 936, 448
TINTS = {  # inner glow, outer
    "floors": ((25, 115, 110), (8, 16, 22)),   # the Drowned Vault's sea-green
    "heroes": ((50, 70, 150), (14, 12, 30)),
    "daily": ((150, 105, 30), (20, 14, 18)),
    "curses": ((150, 20, 30), (18, 8, 16)),
    "race": ((20, 110, 135), (6, 14, 22)),   # the Crypt Race's teal (version 153)
}
if len(sys.argv) > 3:   # only some: pass_tiles.py <render> <out> race
    TINTS = {k: v for k, v in TINTS.items() if k in sys.argv[3:]}
for name, (inner, outer) in TINTS.items():
    glow = Image.new("RGB", (W, H), outer)
    d = ImageDraw.Draw(glow)
    for i in range(40, 0, -1):
        t = i / 40
        c = tuple(int(outer[k] + (inner[k] - outer[k]) * (1 - t)) for k in range(3))
        d.ellipse((W / 2 - W * 0.55 * t, H * 0.5 - H * 0.75 * t, W / 2 + W * 0.55 * t, H * 0.5 + H * 0.75 * t), fill=c)
    bg = glow.filter(ImageFilter.GaussianBlur(30))
    # A soft floor shadow under the figures.
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).ellipse((W * 0.12, H * 0.82, W * 0.88, H * 1.08), fill=150)
    sh = sh.filter(ImageFilter.GaussianBlur(25))
    bg.paste((0, 0, 0), (0, 0), sh)
    fg = Image.open(f"{src}/tile_{name}.png").convert("RGBA")
    bg = bg.convert("RGBA")
    bg.alpha_composite(fg)
    bg.convert("RGB").resize((468, 224), Image.LANCZOS).save(f"{out}/pass_{name}.png", optimize=True)
