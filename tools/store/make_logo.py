"""Draws the BONE CHAIN logo as a picture, for the game and the store graphics.

    python3 tools/store/make_logo.py <font.ttf> <out.png> [stacked]

The letters get a gold-to-ember shine, a thick dark edge, a drop shadow and a warm glow.
One line (art/ui/logo.png, used by the opening and the title screen) is 920 pixels of
letters across, twice the size they are shown at, so they stay sharp on big phones.
`stacked` puts BONE over CHAIN instead, for the store banner.
"""
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

TOP = (255, 246, 214)
MID = (255, 214, 128)
LOW = (226, 128, 40)
EDGE = (42, 18, 6)
GLOW = (255, 110, 25)
TEXT_W = 920


def fit(font_path, text, width):
    """The font size that makes text the given width."""
    size = 400
    while size > 10:
        font = ImageFont.truetype(font_path, size)
        box = font.getbbox(text)
        if box[2] - box[0] <= width:
            return font
        size -= 2
    return ImageFont.truetype(font_path, size)


def shine(size, top, bottom):
    """The gold-to-ember fill, light at the top of the letters and warm at the bottom."""
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(size[1]):
        t = min(1.0, max(0.0, (y - top) / max(1, bottom - top)))
        a, b, k = (TOP, MID, t / 0.5) if t < 0.5 else (MID, LOW, (t - 0.5) / 0.5)
        d.line([(0, y), (size[0], y)], fill=tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)) + (255,))
    return img


def logo(font_path, lines):
    font = fit(font_path, max(lines, key=len), TEXT_W)
    size = font.size
    edge = max(8, size // 11)
    gap = int(size * 0.16)
    boxes = [font.getbbox(line) for line in lines]
    widths = [b[2] - b[0] for b in boxes]
    line_h = max(b[3] for b in boxes) - min(b[1] for b in boxes)
    pad = edge + 48
    w = max(widths) + pad * 2
    h = line_h * len(lines) + gap * (len(lines) - 1) + pad * 2
    letters = Image.new("L", (w, h), 0)
    edged = Image.new("L", (w, h), 0)
    tops = []
    for i, (line, box) in enumerate(zip(lines, boxes)):
        x = (w - widths[i]) // 2 - box[0]
        y = pad + i * (line_h + gap) - min(b[1] for b in boxes)
        ImageDraw.Draw(letters).text((x, y), line, font=font, fill=255)
        ImageDraw.Draw(edged).text((x, y), line, font=font, fill=255, stroke_width=edge, stroke_fill=255)
        tops.append((y + box[1], y + box[3]))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow = Image.new("RGBA", (w, h), GLOW + (0,))
    glow.putalpha(edged.filter(ImageFilter.GaussianBlur(24)).point(lambda v: int(v * 0.75)))
    out.alpha_composite(glow)
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 255), (0, int(size * 0.06)), edged.crop((0, 0, w, h - int(size * 0.06))))
    out.alpha_composite(shadow)
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rim.paste(EDGE + (255,), (0, 0), edged)
    out.alpha_composite(rim)
    fill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, (top, bottom) in enumerate(tops):
        band = Image.new("L", (w, h), 0)
        ImageDraw.Draw(band).rectangle((0, top - edge, w, bottom + edge), fill=255)
        mask = Image.composite(letters, Image.new("L", (w, h), 0), band)
        fill.paste(shine((w, h), top, bottom), (0, 0), mask)
    out.alpha_composite(fill)
    return out


def main():
    font_path, out = sys.argv[1], sys.argv[2]
    lines = ["BONE", "CHAIN"] if "stacked" in sys.argv[3:] else ["BONE CHAIN"]
    logo(font_path, lines).save(out)


if __name__ == "__main__":
    main()
