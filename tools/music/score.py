# The Bone Chain soundtrack: one tune (MEL in theme.py) in the spooky music-box style Jesse
# picked (option B), as seamless loops. Each crypt track has a second, in-sync "fight" layer
# (low strings, cello rhythm and war drums) that the game fades in while enemies are alive.
# Run: python3 tools/music/score.py OUT [track ...]
import sys, os, copy, subprocess
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from song import *
from theme import MEL, THEME_H, INTRO_H

R = 44100
# The middle section: the tune's answer, in the brighter relative major, leading back home.
MELB = [[("F4",1.5),("G4",.5),("A4",1),("C5",1)], [("Bb4",2),("A4",1),("G4",1)],
        [("A4",1.5),("G4",.5),("F4",1),("E4",1)], [("F4",3)],
        [("D5",1.5),("C5",.5),("Bb4",1),("A4",1)], [("G4",1),("A4",1),("Bb4",1),("G4",1)],
        [("A4",2),("E4",1),("C#4",1)], [("A3",1),("C#4",1),("E4",1),("G4",1)]]
B_H = [[("F",4)], [("Bb",4)], [("Am",4)], [("Dm",4)], [("Bb",4)], [("Gm",4)], [("A7",4)], [("A7",4)]]
TAG_H = [[("Dm",4)], [("Bb",4)], [("Gm",4)], [("A7",4)]]
TAGM = [[("D4",1),("F4",1),("E4",.5),("D4",.5),("C#4",1)], [("D4",3)], [], []]
SECT = {"intro": (INTRO_H, None), "A": (THEME_H, MEL), "B": (B_H, MELB), "A2": (THEME_H, MEL), "tag": (TAG_H, TAGM)}
FORM = ["intro", "A", "B", "A2", "tag"]


def plan(form):
    """Chords as (beat, chord, beats, section) and melody notes as (beat, pitch, beats, section)."""
    tl, mel, b = [], [], 0
    for sec in form:
        H, M = SECT[sec]
        for i, bar in enumerate(H):
            bb = b + 4 * i
            for ch, d in bar:
                tl.append((bb, ch, d, sec)); bb += d
        if M:
            for i, bar in enumerate(M):
                bb = b + 4 * i
                for p, d in bar:
                    mel.append((bb, p, d, sec)); bb += d
        b += 4 * len(H)
    return tl, mel, b


def lead(s, part, mel, secs, octv, vel, legato=0.95):
    for b, p, d, sec in mel:
        if sec in secs:
            s.note(part, b, n(p) + 12 * octv, d * legato, vel + (6 if d >= 2 else 0))


def bar_roots(tl):
    """The first chord of every bar."""
    return [(b, ch, sec) for b, ch, d, sec in tl if b % 4 == 0]


# ---------------- the calm layer, one recipe per place ----------------
def calm(cfg):
    s = Song(cfg["bpm"], cfg.get("seed", 5)); s.tr = cfg["tr"]
    tl, mel, L = plan(cfg.get("form", FORM))
    s.part("lead", 0, cfg["lead"], 110, 58, 70)
    s.part("dbl", 1, cfg["dbl"], 108, 74, 85)
    s.part("bass", 2, cfg.get("bass", 45), 80, 50, 50)
    s.part("pad", 3, cfg["pad"], 70, 64, 80, 40)
    s.part("arp", 4, cfg["arp"], 84, 82, 65)
    s.part("ctr", 5, cfg["ctr"], 86, 44, 55)
    s.part("spark", 6, cfg.get("spark", 9), 80, 90, 90)
    s.part("perc", 9, 0, 108, 64, 40)
    arp_div = cfg.get("arp_div", 2)
    for b, ch, d, sec in tl:
        s.chord("pad", b, voice(ch, "D3", "D4")[-3:], d, 48)
        r = root(ch, 2)
        if cfg.get("bass_style") == "soft":
            if b % 4 == 0: s.note("bass", b, r, 1.5, 70)
        else:
            for k in range(int(d)):
                s.note("bass", b + k, r if k % 2 == 0 else r + 7, .4, 78 if k % 2 == 0 else 60)
        if sec != "intro":
            arp = voice(ch, cfg.get("arp_lo", "A3"), cfg.get("arp_hi", "A5"))
            for k in range(int(d * arp_div)):
                s.note("arp", b + k / arp_div, arp[(k * 2) % len(arp)], 1.6 / arp_div, 46 + (8 if k % (2 * arp_div) == 0 else 0))
        perc(s, cfg.get("perc"), b, d, sec)
    lead(s, "lead", mel, ("A", "B", "A2", "tag"), 1, 88)
    lead(s, "dbl", mel, ("A2",), 2, 50)
    # A sneaky counter line under the second half of the tune and the middle section.
    for b, ch, sec in bar_roots(tl):
        if sec in ("B", "A2"):
            p = root(ch, 2) + (12 if root(ch, 2) < n("A1") + 12 else 0)
            s.note("ctr", b + 2, p, 1.8, 70); s.note("ctr", b + 3.5, p + 2 if ch != "A7" else p + 4, .45, 58)
    # A little sparkle at the top of each section.
    for b, ch, sec in bar_roots(tl):
        if b % 32 == 0:
            for k in range(4): s.note("spark", b + k * .5, voice(ch, "D5", "D6")[k % 3], .4, 60)
    return s, L


def perc(s, style, b, d, sec):
    if not style or sec == "intro":
        return
    for k in range(int(d * 2)):
        t = b + k * .5; pos = t % 4
        if style == "tiptoe":
            if sec in ("B", "A2", "tag"):
                s.note("perc", t, 70, .2, 50 if k % 2 else 64)
            if pos == 0: s.note("perc", t, 36, .3, 56)
            if sec == "B" and pos in (1, 3): s.note("perc", t, 37, .2, 40)
        elif style == "ice":
            if pos == 0 and t % 8 == 0: s.note("perc", t, 81, 2, 52)
            if sec == "A2" and k % 2 == 0: s.note("perc", t, 70, .2, 40)
        elif style == "ember":
            if pos == 0: s.note("perc", t, 45, .3, 62)
            if pos == 2.5: s.note("perc", t, 45, .3, 48)
            if sec in ("B", "A2"): s.note("perc", t, 70, .2, 46 if k % 2 else 58)
        elif style == "moon":
            # A slow heartbeat (lub-dub) and a far bell.
            if pos == 0: s.note("perc", t, 36, .3, 74)
            if pos == 0.5: s.note("perc", t, 36, .3, 54)
            if sec in ("B", "A2") and pos == 2: s.note("perc", t, 53, .4, 44)
        elif style == "grotto":
            if pos in (0, 2.5): s.note("perc", t, 77, .2, 64)
            if pos in (1, 3): s.note("perc", t, 76, .2, 50)
            if sec in ("B", "A2"): s.note("perc", t, 70, .2, 44 if k % 2 else 54)


# ---------------- the fight layer: same chords, low and driving ----------------
def fight(cfg):
    s = Song(cfg["bpm"], cfg.get("seed", 5) + 100); s.tr = cfg["tr"]
    tl, mel, L = plan(cfg.get("form", FORM))
    s.part("low", 0, 48, 112, 64, 50)
    s.part("vc", 1, 42, 120, 76, 45)
    s.part("timp", 2, 47, 124, 64, 55)
    s.part("perc", 9, 0, 116, 64, 45)
    for b, ch, d, sec in tl:
        r = root(ch, 2)
        s.chord("low", b, [r, r + 7, r + 12], d, 62)
        pat = [r, r + 7, r + 12, r + 7]
        for k in range(int(d * 2)):
            s.note("vc", b + k * .5, pat[k % 4], .45, 74 if k % 2 == 0 else 60)
        if b % 4 == 0:
            s.note("timp", b, r, 1, 80 if sec != "intro" else 64)
    for b, ch, sec in bar_roots(tl):
        if sec == "intro":
            continue
        for off, q, v in ((0, 41, 92), (1.5, 41, 70), (2, 43, 80), (3, 41, 66), (3.5, 43, 60)):
            s.note("perc", b + off, q, .25, v)
        if b % 32 == 0: s.note("perc", b, 49, 2, 56)
    return s, L


# ---------------- the boss: the music box tune with the orchestra's war drums ----------------
def boss(cfg):
    s = Song(cfg["bpm"], 11); s.tr = cfg["tr"]
    tl, mel, L = plan(FORM)
    s.part("lead", 0, cfg.get("lead", 8), 112, 58, 60); s.part("dbl", 1, cfg.get("dbl", 10), 100, 74, 70)
    s.part("str", 2, 48, 120, 54, 60); s.part("vc", 3, 42, 124, 76, 45); s.part("cb", 4, 43, 104, 64, 40)
    s.part("timp", 5, 47, 127, 64, 50); s.part("choir", 6, 52, 104, 50, 80); s.part("hi", 7, 49, 104, 80, 70)
    s.part("brass", 8, 61, 100, 70, 55); s.part("perc", 9, 0, 120, 64, 45)
    for b, ch, d, sec in tl:
        r = root(ch, 2)
        s.chord("str", b, voice(ch, "D3", "A4")[-4:], d, 58)
        s.note("cb", b, r, d, 72)
        pat = [r, r + 12, r + 7, r + 12]
        for k in range(int(d * 2)):
            s.note("vc", b + k * .5, pat[k % 4], .42, 78 if k % 2 == 0 else 62)
        if sec in ("B", "A2", "tag"):
            s.chord("choir", b, voice(ch, "A3", "D5")[-3:], d, 56)
        if sec == "B":
            s.chord("brass", b, voice(ch, "F3", "D4")[-3:], .9, 76); s.chord("brass", b + 2.5, voice(ch, "F3", "D4")[-3:], .4, 62)
    for b, ch, sec in bar_roots(tl):
        s.note("timp", b, root(ch, 2), 1, 90)
        pat = ((0, 41, 96), (.5, 41, 60), (1.5, 43, 84), (2, 41, 90), (3, 43, 74), (3.5, 45, 70)) if sec != "intro" else ((0, 41, 80), (2, 41, 64))
        for off, q, v in pat: s.note("perc", b + off, q, .25, v)
        if sec != "intro": s.note("perc", b + 1, 38, .2, 50); s.note("perc", b + 3, 38, .2, 56)
        if b % 32 == 0: s.note("perc", b, 49, 2, 70)
    lead(s, "lead", mel, ("A", "B", "A2", "tag"), 1, 96)
    lead(s, "dbl", mel, ("A", "A2"), 2, 54)
    lead(s, "hi", mel, ("A2",), 1, 84)
    return s, L


TRACKS = {
    # name: (recipe, settings)
    "title": ("calm", dict(bpm=80, tr=0, lead=10, dbl=8, pad=89, arp=46, ctr=71, arp_div=1, bass_style="soft",
                           perc=None, form=["intro", "A", "B", "A2"], seed=2)),
    "crypt": ("calm", dict(bpm=96, tr=0, lead=8, dbl=10, pad=89, arp=46, ctr=70, perc="tiptoe", seed=5)),
    "ice": ("calm", dict(bpm=84, tr=2, lead=8, dbl=11, pad=94, arp=46, ctr=73, perc="ice", arp_div=1,
                         bass_style="soft", spark=14, seed=8)),
    "ember": ("calm", dict(bpm=108, tr=-2, lead=12, dbl=10, pad=89, arp=45, ctr=70, perc="ember", arp_lo="D3", arp_hi="D5", seed=9)),
    "drowned": ("calm", dict(bpm=78, tr=-3, lead=11, dbl=88, pad=91, arp=46, ctr=71, perc="ice", arp_div=1,
                             bass_style="soft", spark=14, seed=12)),
    "grotto": ("calm", dict(bpm=100, tr=-5, lead=108, dbl=79, pad=88, arp=12, ctr=70, perc="grotto", seed=10)),
    "boss": ("boss", dict(bpm=126, tr=0)),
    # The Blood Moon event (version 134): the tune slower and lower, a choir for the pad, a
    # heartbeat for the drums; and the Blood Moon Queen's theme on a church organ.
    "moon": ("calm", dict(bpm=88, tr=-1, lead=10, dbl=73, pad=52, arp=46, ctr=42, perc="moon",
                          bass_style="soft", spark=14, seed=13)),
    "queen": ("boss", dict(bpm=132, tr=-1, lead=19, dbl=10)),
}
REVERB = dict(room=0.7, level=0.55, damp=0.45)


def stem(song, L, path):
    """Render the piece twice through and keep the second pass, so the reverb tail of the
    end flows into the start and the loop has no seam."""
    s2 = copy.deepcopy(song)
    for p in s2.parts.values():
        p["ev"] += [(b + L, q, d, v) for b, q, d, v in p["ev"]]
        p["cc"] += [(b + L, num, val) for b, num, val in p["cc"]]
    s2.save(path + ".mid"); render(path + ".mid", path + ".wav", **REVERB)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path + ".wav", "-f", "f32le", "-ac", "2", "-ar", str(R), "-"],
                         capture_output=True).stdout
    x = np.frombuffer(raw, np.float32).reshape(-1, 2)
    a = int(round(L * 60 / song.bpm * R))
    return x[a:2 * a].copy()


def mean_db(x): return 10 * np.log10(np.mean(x.astype(np.float64) ** 2) + 1e-12)


def soft_clip(x, knee=0.8):
    y = x.copy(); m = np.abs(y) > knee
    y[m] = np.sign(y[m]) * (knee + (1 - knee) * np.tanh((np.abs(y[m]) - knee) / (1 - knee)))
    return y


def write(x, path):
    br = ["-c:a", "libmp3lame", "-b:a", "128k"] if path.endswith(".mp3") else ["-c:a", "libvorbis", "-q:a", "4"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(R), "-ac", "2", "-i", "-"] + br + [path],
                   input=x.astype(np.float32).tobytes(), check=True)


def build(name, out):
    kind, cfg = TRACKS[name]
    s, L = (calm if kind == "calm" else boss)(cfg)
    base = stem(s, L, os.path.join(out, name))
    if kind == "calm" and name != "title":
        fl, _ = fight(cfg)
        layer = stem(fl, L, os.path.join(out, name + "_fight")) * 0.7   # sits under the tune, not on top
        # One gain for both layers so the balance between them stays as written: together
        # they sit at the old music's loudness, the calm layer alone a little under it.
        g = 10 ** ((-19.5 - mean_db(base + layer)) / 20)
        base, layer = soft_clip(base * g), soft_clip(layer * g)
        write(layer, os.path.join(out, name + "_fight.ogg"))
        write(soft_clip(base + layer), os.path.join(out, name + "_both.mp3"))
    else:
        g = 10 ** (((-21.0 if name == "title" else -19.0) - mean_db(base)) / 20)
        base = soft_clip(base * g)
    write(base, os.path.join(out, name + ".ogg"))
    write(base, os.path.join(out, name + ".mp3"))
    print(name, "%.1fs" % (len(base) / R), "calm %.1f dB" % mean_db(base))


if __name__ == "__main__":
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for name in sys.argv[2:] or list(TRACKS):
        build(name, out)
