"""Builds Bone Chain's app icon from a render_icon.gd picture.

    python3 tools/store/icon_compose.py <render.png> <style> <output folder> [chain=<chain.png>] [sparks]

style picks the background: ember (hot orange), frost (teal) or royal (purple).
chain= is the same render with only the chain (render_icon.gd only=chain): the parts of it
that show in the full picture get a fiery glow. sparks scatters glowing embers behind.
Writes icon-1024.png and icon-512.png (Google Play), and the Android launcher layers:
icon-192.png, adaptive-fg-432.png (the picture, shrunk into the part a phone shows),
adaptive-bg-432.png and adaptive-mono-432.png (a one-colour shape for themed icons).
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

STYLES = {
    # centre colour, middle colour, edge colour, ray colour
    "ember": ((255, 176, 70), (214, 62, 28), (92, 14, 22), (255, 214, 140)),
    "frost": ((120, 240, 235), (22, 150, 175), (8, 46, 74), (200, 255, 250)),
    "royal": ((214, 120, 255), (112, 40, 196), (36, 10, 72), (240, 200, 255)),
}
OUTLINE = (22, 10, 26)


def backdrop(size, style):
    c0, c1, c2, ray = STYLES[style]
    w = h = size
    img = Image.new("RGB", (w, h))
    px = img.load()
    cx, cy = w * 0.5, h * 0.42
    r = w * 0.78
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - cx, y - cy) / r)
            if t < 0.45:
                k = t / 0.45
                k = k * k * (3 - 2 * k)
                col = [c0[i] + (c1[i] - c0[i]) * k for i in range(3)]
            else:
                k = (t - 0.45) / 0.55
                k = k * k * (3 - 2 * k)
                col = [c1[i] + (c2[i] - c1[i]) * k for i in range(3)]
            px[x, y] = tuple(int(v) for v in col)
    # Soft sun rays from behind the head.
    rays = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(rays)
    n = 14
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = a0 + math.pi / n
        far = w * 1.5
        d.polygon([(cx, cy), (cx + math.cos(a0) * far, cy + math.sin(a0) * far), (cx + math.cos(a1) * far, cy + math.sin(a1) * far)], fill=40)
    fade = Image.new("L", (w, h), 0)
    fp = fade.load()
    for y in range(h):
        for x in range(w):
            t = min(1.0, math.hypot(x - cx, y - cy) / (w * 0.7))
            fp[x, y] = int(255 * (1 - t))
    rays = ImageChops.multiply(rays, fade).filter(ImageFilter.GaussianBlur(3))
    img = Image.composite(Image.new("RGB", (w, h), ray), img, rays)
    return img.convert("RGBA")


def outlined(ch, px):
    """The picture with a thick dark outline and a soft shadow round it."""
    a = ch.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    grown = a
    step = 9
    for _ in range(max(1, px // (step // 2))):
        grown = grown.filter(ImageFilter.MaxFilter(step))
    grown = grown.filter(ImageFilter.GaussianBlur(1.5))
    out = Image.new("RGBA", ch.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", ch.size, (0, 0, 0, 0))
    shadow.putalpha(grown.filter(ImageFilter.GaussianBlur(px * 1.6)).point(lambda v: int(v * 0.7)))
    out.alpha_composite(shadow, (0, int(px * 0.6)))
    line = Image.new("RGBA", ch.size, OUTLINE + (255,))
    line.putalpha(grown)
    out.alpha_composite(line)
    out.alpha_composite(ch)
    return out


def sparks(size, style, seed=7):
    """Small glowing embers drifting up behind the figure."""
    rnd = random.Random(seed)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    ray = STYLES[style][3]
    for _ in range(26):
        x, y = rnd.uniform(0, size), rnd.uniform(size * 0.15, size)
        r = rnd.uniform(4, 11)
        col = (255, 190, 80) if rnd.random() < 0.7 else ray
        d.ellipse((x - r, y - r, x + r, y + r), fill=col + (int(rnd.uniform(140, 255)),))
    glow = layer.filter(ImageFilter.GaussianBlur(10))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(glow)
    out.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.2)))
    return out


def chain_glow(ch, chain_path, s):
    """An ember glow on the parts of the chain that show (where the chain-only render matches
    the full one)."""
    only = Image.open(chain_path).convert("RGBA").resize((s, s), Image.LANCZOS)
    diff = ImageChops.difference(only.convert("RGB"), ch.convert("RGB")).convert("L")
    seen = ImageChops.multiply(only.getchannel("A"), diff.point(lambda v: 255 if v < 24 else 0))
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    for radius, strength, col in ((6, 0.9, (255, 200, 90)), (22, 0.8, (255, 120, 40))):
        g = Image.new("RGBA", (s, s), col + (0,))
        g.putalpha(seen.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(255, int(v * strength))))
        out.alpha_composite(g)
    return out


def build(render, style, out, chain=None, embers=False):
    os.makedirs(out, exist_ok=True)
    s = 1024
    ch = Image.open(render).convert("RGBA").resize((s, s), Image.LANCZOS)
    fig = outlined(ch, 14)
    img = backdrop(s, style)
    if embers:
        img.alpha_composite(sparks(s, style))
    img.alpha_composite(fig)
    if chain:
        img.alpha_composite(chain_glow(ch, chain, s))
        # The chain itself back on top of its glow, so the links stay crisp.
        only = Image.open(chain).convert("RGBA").resize((s, s), Image.LANCZOS)
        diff = ImageChops.difference(only.convert("RGB"), ch.convert("RGB")).convert("L")
        seen = ImageChops.multiply(only.getchannel("A"), diff.point(lambda v: 255 if v < 24 else 0))
        crisp = ch.copy()
        crisp.putalpha(seen)
        img.alpha_composite(crisp)
    # Bloom on the glowing eyes, so they still burn at thumbnail size.
    r, g, b, al = ch.split()
    hot = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 225 else 0), g.point(lambda v: 255 if v > 215 else 0)), b.point(lambda v: 255 if v < 170 else 0))
    for radius, strength in ((10, 1.0), (28, 0.8)):
        glow = Image.new("RGBA", (s, s), (255, 236, 120, 0))
        glow.putalpha(hot.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(255, int(v * 3 * strength))))
        img.alpha_composite(glow)
    # A dark rim so the icon holds its shape on a white page.
    vign = Image.new("L", (s, s), 0)
    ImageDraw.Draw(vign).rectangle((0, 0, s - 1, s - 1), outline=255, width=6)
    vign = vign.filter(ImageFilter.GaussianBlur(30)).point(lambda v: int(v * 0.6))
    img = Image.composite(Image.new("RGBA", (s, s), (10, 4, 14, 255)), img, vign)
    img.convert("RGB").save(os.path.join(out, "icon-1024.png"))
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save(os.path.join(out, "icon-512.png"))
    img.convert("RGB").resize((192, 192), Image.LANCZOS).save(os.path.join(out, "icon-192.png"))
    # Android adaptive icon: a 108-unit square of which a phone shows the middle 72, so the
    # whole design goes in the middle two thirds and the background colour fills the rest.
    a = 432
    inner = 288
    fg = Image.new("RGBA", (a, a), (0, 0, 0, 0))
    fg.alpha_composite(img.resize((inner, inner), Image.LANCZOS), ((a - inner) // 2, (a - inner) // 2))
    fg.save(os.path.join(out, "adaptive-fg-432.png"))
    edge = STYLES[style][2]
    Image.new("RGB", (a, a), edge).save(os.path.join(out, "adaptive-bg-432.png"))
    # Themed (one-colour) icon: the figure's shape with its eyes and mouth cut out, and a
    # thin gap where gold (the crown) meets bone, so it still reads as a face.
    shape = fig.getchannel("A").point(lambda v: 255 if v > 128 else 0)
    r, g, b, al = ch.split()
    eyes = ImageChops.multiply(ImageChops.multiply(r.point(lambda v: 255 if v > 225 else 0), g.point(lambda v: 255 if v > 215 else 0)), b.point(lambda v: 255 if v < 170 else 0))
    eyes = eyes.filter(ImageFilter.MaxFilter(9))
    lum = ch.convert("L")
    mouth = ImageChops.multiply(lum.point(lambda v: 255 if v < 26 else 0), al.point(lambda v: 255 if v > 200 else 0))
    mouth = mouth.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(7))
    hsv = ch.convert("RGB").convert("HSV")
    hh, ss, vv = hsv.split()
    gold = ImageChops.multiply(ImageChops.multiply(hh.point(lambda v: 255 if 14 <= v <= 40 else 0), ss.point(lambda v: 255 if v > 150 else 0)), vv.point(lambda v: 255 if v > 90 else 0))
    gold = ImageChops.multiply(gold, al.point(lambda v: 255 if v > 200 else 0)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    seam = ImageChops.subtract(gold.filter(ImageFilter.MaxFilter(13)), gold)
    top = Image.new("L", (s, s), 0)
    ImageDraw.Draw(top).rectangle((0, 0, s, int(s * 0.5)), fill=255)
    seam = ImageChops.multiply(seam, top)   # the crown only, not the chain
    holes = ImageChops.lighter(ImageChops.lighter(eyes, mouth), seam)
    shape = ImageChops.subtract(shape, holes)
    mono = Image.new("RGBA", (a, a), (0, 0, 0, 0))
    m = 264   # the safe zone: 66 of the 108 units
    shape = shape.resize((m, m), Image.LANCZOS).point(lambda v: 255 if v > 128 else 0)
    white = Image.new("RGBA", (m, m), (255, 255, 255, 255))
    white.putalpha(shape)
    mono.alpha_composite(white, ((a - m) // 2, (a - m) // 2))
    mono.save(os.path.join(out, "adaptive-mono-432.png"))


if __name__ == "__main__":
    opts = dict(a.split("=", 1) for a in sys.argv[4:] if "=" in a)
    build(sys.argv[1], sys.argv[2], sys.argv[3], chain=opts.get("chain"), embers="sparks" in sys.argv[4:])
