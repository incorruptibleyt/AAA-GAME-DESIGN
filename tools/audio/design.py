# Sound design for Bone Chain (version 136): each hero's own shot and a punchier hit, made by
# layering Kenney's CC0 recordings with sounds worked out here (a plucked crossbow string,
# whooshes, a bell-like chime, a low thump), levelled to sit with the game's other sounds.
#
# Needs numpy and ffmpeg. SND is a folder holding the unzipped packs from the repo's
# releases: k1/ = audio-pack (kenney-audio.zip), k2/ = audio-pack-2 (cc0-audio-2.zip).
#   python3 tools/audio/design.py SND audio/sfx [all|shots|hits]
import numpy as np, subprocess, sys, os
R = 44100
SND = sys.argv[1]; OUT = sys.argv[2]
rng = np.random.default_rng(134)

def load(p, speed=1.0):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", os.path.join(SND, p), "-f", "f32le", "-ac", "1", "-ar", str(R), "-"], capture_output=True).stdout
    a = np.frombuffer(raw, np.float32).astype(np.float64)
    if speed != 1.0:
        idx = np.arange(0, len(a) - 1, speed)
        a = np.interp(idx, np.arange(len(a)), a)
    return trim(a)

def trim(a, th=0.003):
    nz = np.where(np.abs(a) > th)[0]
    return a[nz[0]:nz[-1] + 1] if len(nz) else a

def save(a, name, mean_db=-21.0, cap=None):
    a = a - np.mean(a)
    if cap:
        a = a[: int(cap * R)]; n = int(0.06 * R); a[-n:] *= np.linspace(1, 0, n) ** 2
    # Level by loudness (mean, as ffmpeg's volumedetect measures it) to sit with the old
    # sounds, with the peak kept under -1 dBFS.
    rms = np.sqrt(np.mean(a ** 2)) or 1.0
    a = a * (10 ** (mean_db / 20) / rms)
    pk = np.max(np.abs(a))
    if pk > 0.89:
        a = np.tanh(a / 0.89 * 1.2) / np.tanh(1.2) * 0.89 if pk < 1.6 else a / pk * 0.89
    n = min(len(a), int(0.004 * R)); a[-n:] *= np.linspace(1, 0, n)
    p = subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f64le", "-ar", str(R), "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT, name + ".ogg")], input=a.astype(np.float64).tobytes())
    assert p.returncode == 0

def t(sec): return np.arange(int(sec * R)) / R

def env(n, att, dec):
    tt = np.arange(n) / R
    return np.minimum(tt / max(att, 1e-4), 1.0) * np.exp(-tt / dec)

def mix(*parts):
    n = max(len(p) + int(o * R) for p, o, g in parts)
    out = np.zeros(n)
    for p, o, g in parts:
        s = int(o * R); out[s:s + len(p)] += p * g
    return out

def biquad_bp(x, f, q):
    # band-pass with a centre that may move (f: array or float)
    f = np.broadcast_to(np.asarray(f, float), x.shape)
    y = np.zeros_like(x); x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        w = 2 * np.pi * f[i] / R; al = np.sin(w) / (2 * q); c = np.cos(w)
        b0 = al; b2 = -al; a0 = 1 + al; a1 = -2 * c; a2 = 1 - al
        yi = (b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]; y2, y1 = y1, yi; y[i] = yi
    return y

def lowpass(x, f):
    a = np.exp(-2 * np.pi * f / R); y = np.zeros_like(x); s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s; y[i] = s
    return y

def highpass(x, f): return x - lowpass(x, f)

def whoosh(sec, f0, f1, q=1.2, att=0.03):
    n = int(sec * R); noise = rng.standard_normal(n)
    f = np.geomspace(f0, f1, n)
    w = biquad_bp(noise, f, q)
    tt = np.arange(n) / R
    e = np.minimum(tt / att, 1) * np.clip(1 - (tt - att) / (sec - att), 0, 1) ** 2
    return w * e

def string(f, sec, damp=0.996):
    # Karplus-Strong plucked string (the crossbow's string).
    n = int(sec * R); p = int(R / f)
    buf = rng.uniform(-1, 1, p); out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = damp * 0.5 * (buf[i % p] + buf[(i + 1) % p])
    return out * env(n, 0.001, sec / 3)

def ring(freqs, sec, dec):
    tt = t(sec); return sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * g for f, g in freqs) * np.exp(-tt / dec)

def fm(fc, ratio, index, sec, dec):
    tt = t(sec); idx = index * np.exp(-tt / (dec * 0.6))
    return np.sin(2 * np.pi * fc * tt + idx * np.sin(2 * np.pi * fc * ratio * tt)) * env(len(tt), 0.004, dec)

def thump(f0, f1, sec):
    tt = t(sec); ph = 2 * np.pi * np.cumsum(np.geomspace(f0, f1, len(tt))) / R
    return np.sin(ph) * env(len(tt), 0.002, sec / 3)

which = sys.argv[3] if len(sys.argv) > 3 else "all"

if which in ("all", "shots"):
    # Rogue: crossbow. Trigger click, the string's twang, a thin fast whoosh.
    for i, (f, sp) in enumerate([(196, 1.25), (220, 1.35), (185, 1.3)]):
        a = mix((load("k1/rpg-audio/metalClick.ogg", sp), 0, 0.45),
                (highpass(string(f, 0.28), 120), 0.004, 0.9),
                (whoosh(0.13, 4200, 1500, 1.4, 0.01), 0.01, 0.55))
        save(a, "shoot_rogue_%d" % i)
    # Knight: a sword wave. A blade's shing (knife slice and a bright metal ring) on a low sweep.
    for i, (src, sp) in enumerate([("knifeSlice.ogg", 1.0), ("knifeSlice2.ogg", 0.95), ("drawKnife1.ogg", 1.1)]):
        a = mix((load("k1/rpg-audio/" + src, sp), 0, 0.8),
                (ring([(2350, 0.5), (3520, 0.35), (5200, 0.2)], 0.4, 0.09), 0.01, 0.22),
                (whoosh(0.3, 900, 320, 1.0, 0.05), 0.0, 0.8))
        save(a, "shoot_knight_%d" % i)
    # Barbarian: a heavy axe thrown, spinning (the whoosh throbs), with a short grunt of cloth.
    for i, (spin, f0) in enumerate([(17, 700), (20, 620), (15, 760)]):
        w = whoosh(0.36, f0, 210, 0.9, 0.06)
        w *= 0.55 + 0.45 * np.abs(np.sin(np.pi * spin * np.arange(len(w)) / R))
        a = mix((w, 0, 1.0), (load("k1/rpg-audio/cloth%d.ogg" % (i % 4 + 1), 0.8), 0, 0.5),
                (thump(140, 70, 0.08), 0, 0.35))
        save(a, "shoot_barbarian_%d" % i, -21.0, 0.42)
    # Mage: a magic orb. A bell-like chime, a shimmer of force field and a soft airy rush.
    for i, (fc, sp) in enumerate([(880, 1.5), (988, 1.6), (831, 1.45)]):
        ff = load("k2/sci-fi-sounds/forceField_00%d.ogg" % (i % 4), sp)[: int(0.3 * R)]
        ff *= env(len(ff), 0.005, 0.1)
        a = mix((fm(fc, 1.5, 3.0, 0.45, 0.14), 0, 0.5), (fm(fc * 2, 2.01, 1.2, 0.3, 0.07), 0.01, 0.2),
                (ff, 0, 0.6), (whoosh(0.22, 2600, 900, 1.1, 0.02), 0, 0.5))
        save(a, "shoot_mage_%d" % i)

if which in ("all", "hits"):
    # A hit on a skeleton: the punch's body, a bony crack on top and a low thump under it.
    for i in range(5):
        a = mix((load("k1/impact-sounds/impactPunch_medium_00%d.ogg" % (i % 5)), 0, 0.75),
                (load("k1/impact-sounds/impactWood_light_00%d.ogg" % (i % 5), 1.35), 0.0, 0.8),
                (highpass(load("k1/impact-sounds/impactGeneric_light_00%d.ogg" % (i % 5), 1.6), 1500), 0.003, 0.35),
                (thump(150, 60, 0.09), 0, 0.5))
        save(a, "hit_%d" % i, -20.0)
