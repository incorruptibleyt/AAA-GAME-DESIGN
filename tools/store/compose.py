"""Builds the Google Play graphics for Bone Chain from the renders.

    python3 tools/store/compose.py <render folder> <output folder> dodge=<file> ember=<file> ...

The render folder holds icon3d.png and banner3d.png (from render_art.gd; leave them out
to make only the screenshots) and the screenshots (1080 x 1920, from the autoplay robot),
passed as key=file for each key in SHOTS, e.g. dodge=shot_07_playing.png.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import make_logo

FONT = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
FONT_BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
LOGO_FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fonts", "Fruktur-Regular.ttf")
BONE = (240, 226, 196)
GOLD = (255, 205, 110)
EMBER = (255, 120, 40)
NIGHT = (24, 16, 38)

# (screenshot, caption, sub-caption)
SHOTS = [
    ("dodge", "DASH THROUGH DANGER", "Perfect dodges slow time and shatter shots"),
    ("ember", "CHAIN YOUR KILLS", "The higher the chain, the harder you hit"),
    ("doors", "CHOOSE YOUR PATH", "Pick a door after every room"),
    ("blessings", "A NEW BUILD EVERY RUN", "Fire, frost, bolts and bone blessings"),
    ("heroes", "FOUR HEROES", "Each with their own special move"),
    ("daily", "A NEW CRYPT EVERY DAY", "The same rooms for everyone, then share"),
]


def radial(size, inner, outer, center=(0.5, 0.5), radius=0.75):
    w, h = size
    img = Image.new("RGB", size, outer)
    px = img.load()
    cx, cy = center[0] * w, center[1] * h
    r = radius * max(w, h)
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - cx, y - cy) / r)
            t = t * t * (3 - 2 * t)
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return img


def glow_text(img, xy, text, font, fill, glow=(0, 0, 0), glow_radius=10, anchor="la", stroke=0):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text(xy, text, font=font, fill=glow + (255,), anchor=anchor, stroke_width=stroke + 6, stroke_fill=glow + (255,))
    layer = layer.filter(ImageFilter.GaussianBlur(glow_radius))
    img.alpha_composite(layer)
    d = ImageDraw.Draw(img)
    d.text(xy, text, font=font, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=(20, 12, 28))


def chain_ring(size, center, radius, links, color, width):
    """A ring of oval chain links, like the Bone Chain."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(links):
        a = 2 * math.pi * i / links
        x, y = center[0] + math.cos(a) * radius, center[1] + math.sin(a) * radius
        ln = 2 * math.pi * radius / links * 0.62
        wd = ln * 0.55 if i % 2 == 0 else ln * 0.28
        # an oval along the ring's tangent
        pts = []
        for k in range(24):
            t = 2 * math.pi * k / 24
            u, v = math.cos(t) * ln, math.sin(t) * wd
            ta = a + math.pi / 2
            pts.append((x + u * math.cos(ta) - v * math.sin(ta), y + u * math.sin(ta) + v * math.cos(ta)))
        d.line(pts + [pts[0]], fill=(30, 18, 30, 255), width=width + 10, joint="curve")
        d.line(pts + [pts[0]], fill=color, width=width, joint="curve")
    return layer


def icon(src, out):
    s = 1024
    img = radial((s, s), (120, 52, 40), NIGHT, center=(0.5, 0.42), radius=0.62).convert("RGBA")
    ring = chain_ring((s, s), (s / 2, s * 0.47), s * 0.40, 12, (214, 196, 160, 255), 26)
    ring.putalpha(ring.getchannel("A").point(lambda a: int(a * 0.8)))
    img.alpha_composite(ring)
    ch = Image.open(os.path.join(src, "icon3d.png")).convert("RGBA")
    shadow = Image.new("RGBA", ch.size, (255, 120, 40, 0))
    shadow.putalpha(ch.getchannel("A").filter(ImageFilter.GaussianBlur(28)).point(lambda a: int(a * 0.8)))
    img.alpha_composite(shadow, (0, 0))
    img.alpha_composite(ch, (0, 0))
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(out, "icon-512.png"))
    img.convert("RGB").save(os.path.join(out, "icon-1024.png"))


def banner(src, shots, out):
    w, h = 2048, 1000
    bg = Image.open(shots["dodge"]).convert("RGB")
    bg = bg.resize((w, int(bg.height * w / bg.width))).crop((0, 900, w, 900 + h))
    bg = bg.filter(ImageFilter.GaussianBlur(12))
    img = Image.blend(bg, radial((w, h), (70, 30, 50), NIGHT, center=(0.3, 0.5), radius=0.8), 0.72).convert("RGBA")
    ch = Image.open(os.path.join(src, "banner3d.png")).convert("RGBA")
    ch = ch.resize((int(ch.width * 0.9), int(ch.height * 0.9)), Image.LANCZOS)
    glow = Image.new("RGBA", ch.size, EMBER + (0,))
    glow.putalpha(ch.getchannel("A").filter(ImageFilter.GaussianBlur(30)).point(lambda a: int(a * 0.55)))
    img.alpha_composite(glow, (500, 90))
    img.alpha_composite(ch, (500, 90))
    # The game's logo, with BONE over CHAIN.
    title = make_logo.logo(LOGO_FONT, ["BONE", "CHAIN"])
    title = title.resize((int(title.width * 430 / title.height), 430), Image.LANCZOS)
    img.alpha_composite(title, (100, 200))
    sub = ImageFont.truetype(FONT_BOLD, 64)
    glow_text(img, (156, 720), "Dash. Chain. Descend.", sub, (235, 230, 245), glow_radius=8, anchor="ls")
    img.convert("RGB").resize((1024, 500), Image.LANCZOS).save(os.path.join(out, "feature-1024x500.png"))


def screenshot(path, caption, subcap, out):
    w, h = 1080, 1920
    img = radial((w, h), (88, 40, 60), NIGHT, center=(0.5, 0.0), radius=1.0).convert("RGBA")
    shot = Image.open(path).convert("RGBA")
    sw = 860
    shot = shot.resize((sw, int(shot.height * sw / shot.width)), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width, shot.height), 44, fill=255)
    top = 330
    frame = Image.new("RGBA", (shot.width + 16, shot.height + 16), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width - 1, frame.height - 1), 52, fill=GOLD + (255,))
    img.alpha_composite(frame, ((w - frame.width) // 2, top - 8))
    img.paste(shot, ((w - sw) // 2, top), mask)
    cap = ImageFont.truetype(FONT, 84 if len(caption) <= 18 else 72)
    sub = ImageFont.truetype(FONT_BOLD, 44)
    glow_text(img, (w // 2, 160), caption, cap, GOLD, glow=(110, 30, 10), glow_radius=14, anchor="mm", stroke=3)
    glow_text(img, (w // 2, 255), subcap, sub, (235, 230, 245), glow_radius=6, anchor="mm")
    img.convert("RGB").save(out)


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    picks = dict(arg.split("=", 1) for arg in sys.argv[3:])
    shots = {k: os.path.join(src, picks[k]) for k, _, _ in SHOTS}
    # The icon and banner need the 3D renders; without them only the screenshots are made.
    if os.path.exists(os.path.join(src, "icon3d.png")):
        icon(src, out)
        banner(src, shots, out)
    for i, (k, cap, sub) in enumerate(SHOTS, 1):
        screenshot(shots[k], cap, sub, os.path.join(out, "screenshot-%d.png" % i))


if __name__ == "__main__":
    main()
