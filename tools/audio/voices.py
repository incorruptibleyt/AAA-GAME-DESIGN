# Version 251 (whole-game review fix 11): every skeleton family dies with a sound of its own
# and every boss roars in its own voice, where before all of them shared one bone crunch
# ("die") and one roar ("roar"). Each sound layers the CC0 recordings already credited in
# audio/sfx/CREDITS.md (Kenney's packs and rubberduck's creature sounds) with sounds worked
# out here (ice tinkles, bubbles, hissing embers, bat squeaks, a ghostly chord, bells).
#
# Needs numpy and ffmpeg. SND holds the unzipped packs from the repo's releases:
# k1/ = audio-pack (kenney-audio.zip), k2/ = audio-pack-2 (cc0-audio-2.zip).
#   python3 tools/audio/voices.py SND audio/sfx [all|die|roar]
import numpy as np, subprocess, sys, os
R = 44100
SND = sys.argv[1]; OUT = sys.argv[2]
WHICH = sys.argv[3] if len(sys.argv) > 3 else "all"
SFX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "audio", "sfx")
rng = np.random.default_rng(251)


def load(p, speed=1.0, keep=None):
    """A recording as mono floats. speed > 1 plays it faster and higher; keep cuts it."""
    path = p if os.path.isabs(p) else os.path.join(SND, p)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(R), "-"],
                         capture_output=True).stdout
    a = np.frombuffer(raw, np.float32).astype(np.float64)
    if speed != 1.0:
        idx = np.arange(0, len(a) - 1, speed)
        a = np.interp(idx, np.arange(len(a)), a)
    a = trim(a)
    if keep and len(a) > keep * R:
        a = a[: int(keep * R)].copy(); n = int(0.05 * R); a[-n:] *= np.linspace(1, 0, n) ** 2
    return a / (np.max(np.abs(a)) or 1.0)


def game(name, speed=1.0, keep=None):
    """One of the game's own sounds (audio/sfx), e.g. the bone crunch die_2."""
    return load(os.path.join(SFX, name + ".ogg"), speed, keep)


def trim(a, th=0.003):
    nz = np.where(np.abs(a) > th)[0]
    return a[nz[0]:nz[-1] + 1] if len(nz) else a


def save(a, name, mean_db=-17.5, cap=None):
    a = a - np.mean(a)
    if cap and len(a) > cap * R:
        a = a[: int(cap * R)]; n = int(0.08 * R); a[-n:] *= np.linspace(1, 0, n) ** 2
    # Levelled by loudness to sit with the old crunch (about -17 dB) and roars (about -14 dB),
    # the peak kept under -1 dBFS.
    rms = np.sqrt(np.mean(trim(a) ** 2)) or 1.0
    a = a * (10 ** (mean_db / 20) / rms)
    if np.max(np.abs(a)) > 0.89:
        a = limit(a)
    n = min(len(a), int(0.004 * R)); a[-n:] *= np.linspace(1, 0, n)
    p = subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f64le", "-ar", str(R), "-ac", "1", "-i", "-",
                        "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT, name + ".ogg")], input=a.tobytes())
    assert p.returncode == 0
    print(name, "%.2f s" % (len(a) / R))


def limit(a, ceil=0.89):
    """A peak limiter (3 ms look-ahead, 60 ms release): loud peaks are turned down on their
    own, so a sound with one sharp crack isn't made quiet all through."""
    w = int(0.003 * R)
    held = np.lib.stride_tricks.sliding_window_view(np.concatenate([np.abs(a), np.zeros(w)]), w + 1).max(axis=1)[: len(a)]
    g = np.minimum(1.0, ceil / np.maximum(held, 1e-9))
    out = np.empty_like(g); s = 1.0; rel = np.exp(-1.0 / (0.06 * R))
    for i in range(len(g)):
        s = g[i] if g[i] < s else g[i] + (s - g[i]) * rel
        out[i] = s
    return np.clip(a * out, -ceil, ceil)


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


def lowpass(x, f):
    a = np.exp(-2 * np.pi * f / R); y = np.zeros_like(x); s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s; y[i] = s
    return y


def highpass(x, f, order=1):
    for _ in range(order):
        x = x - lowpass(x, f)
    return x


def bandpass(x, f, q):
    # A band-pass whose centre may move (f: an array or a number).
    f = np.broadcast_to(np.asarray(f, float), x.shape)
    y = np.zeros_like(x); x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        w = 2 * np.pi * f[i] / R; al = np.sin(w) / (2 * q); c = np.cos(w)
        a0 = 1 + al
        yi = (al * x[i] - al * x2 + 2 * c * y1 - (1 - al) * y2) / a0
        x2, x1 = x1, x[i]; y2, y1 = y1, yi; y[i] = yi
    return y


def fade(a, to=0.2):
    return a * np.linspace(1, to, len(a))


def noise(sec): return rng.standard_normal(int(sec * R))


def glide(f0, f1, sec, curve=1.0):
    tt = t(sec); f = f0 + (f1 - f0) * (tt / sec) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / R)


def thump(f0, f1, sec):
    tt = t(sec); ph = 2 * np.pi * np.cumsum(np.geomspace(f0, f1, len(tt))) / R
    return np.sin(ph) * env(len(tt), 0.002, sec / 3)


def whoosh(sec, f0, f1, q=1.2, att=0.03):
    w = bandpass(noise(sec), np.geomspace(f0, f1, int(sec * R)), q)
    tt = t(sec)
    return w * np.minimum(tt / att, 1) * np.clip(1 - (tt - att) / (sec - att), 0, 1) ** 2


def verb(a, sec=0.9, wet=0.4, tone=3000):
    """A dark room echo: the sound convolved with fading noise."""
    ir = lowpass(noise(sec), tone) * np.exp(-t(sec) / (sec / 5))
    ir /= np.sqrt(np.sum(ir ** 2))
    n = len(a) + len(ir)
    w = np.fft.irfft(np.fft.rfft(a, n) * np.fft.rfft(ir, n), n)
    out = np.zeros(n); out[: len(a)] += a * (1 - wet * 0.5)
    return out + w * wet


def chorus(a, speeds):
    """Several copies a hair apart in pitch: one voice becomes a choir of ghosts."""
    return mix(*[(load_arr(a, s), i * 0.012, 1.0 / len(speeds)) for i, s in enumerate(speeds)])


def load_arr(a, speed):
    idx = np.arange(0, len(a) - 1, speed)
    return np.interp(idx, np.arange(len(a)), a)


def tinkle(sec, n, lo, hi, dec=0.12):
    """Little glassy pings scattered over `sec`: ice falling to pieces."""
    out = np.zeros(int(sec * R) + int(0.6 * R))
    for _ in range(n):
        f = rng.uniform(lo, hi); at = rng.uniform(0, sec) ** 1.6 / sec ** 0.6
        tt = t(0.5)
        p = (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.76 * tt)) * np.exp(-tt / dec)
        s = int(at * R); out[s:s + len(p)] += p * rng.uniform(0.3, 1.0)
    return out


def bubbles(sec, n, lo=260, hi=700):
    """Rising little blips: bubbles breaking the surface."""
    out = np.zeros(int(sec * R) + int(0.1 * R))
    for _ in range(n):
        f = rng.uniform(lo, hi); d = rng.uniform(0.025, 0.06)
        p = glide(f, f * 2.2, d, 2.0) * np.sin(np.pi * t(d) / d)
        s = int(rng.uniform(0, sec) * R); out[s:s + len(p)] += p * rng.uniform(0.4, 1.0)
    return out


def crackle(sec, rate, dec=0.25):
    """Embers popping, thinning out as they cool."""
    out = np.zeros(int(sec * R))
    k = 0.0
    while True:
        k += rng.exponential(1.0 / rate)
        if k >= sec:
            break
        p = highpass(noise(0.006), 1500) * np.exp(-t(0.006) / 0.0015)
        s = int(k * R); out[s:s + len(p)] += p[: len(out) - s] * np.exp(-k / dec) * rng.uniform(0.3, 1.0)
    return out


def hiss(sec, dec, f=4000):
    return highpass(noise(sec), f) * env(int(sec * R), 0.01, dec)


def squeak(f0, f1, sec):
    """A bat's chirp: a quick high sweep with a buzzy edge."""
    s = glide(f0, f1, sec, 0.7)
    return (s + 0.3 * np.sign(s) * 0.5) * np.sin(np.pi * t(sec) / sec) ** 0.6


def flutter(sec, rate=24):
    w = bandpass(noise(sec), 900, 0.8)
    return w * (0.5 + 0.5 * np.abs(np.sin(np.pi * rate * t(sec)))) ** 3 * env(int(sec * R), 0.01, sec / 2)


def sleigh(sec, rate=11):
    """Little jingle bells shaken: bright, inharmonic rings in quick bursts."""
    out = np.zeros(int(sec * R) + int(0.3 * R))
    k = 0.0
    while k < sec:
        for _ in range(3):
            f = rng.uniform(3200, 5200); tt = t(0.25)
            p = (np.sin(2 * np.pi * f * tt) + 0.6 * np.sin(2 * np.pi * f * 1.47 * tt)) * np.exp(-tt / 0.05)
            s = int((k + rng.uniform(0, 0.02)) * R); out[s:s + len(p)] += p * rng.uniform(0.2, 0.6)
        k += 1.0 / rate * rng.uniform(0.8, 1.2)
    return out * np.concatenate([np.exp(-t(sec) / (sec * 0.6)), np.zeros(len(out) - int(sec * R))])


CRUNCH = ["die_%d" % i for i in range(5)]   # the game's bone crunch, which the rest build on

if WHICH in ("all", "die"):
    # Skeleton Warrior: the bones go and his armour falls after them, plate and shield.
    for i in range(3):
        a = mix((game(CRUNCH[i]), 0, 0.85),
                (load("k1/impact-sounds/impactPlate_light_00%d.ogg" % i, 0.95), 0.05, 0.75),
                (load("k1/impact-sounds/impactMetal_light_00%d.ogg" % (i + 1), 0.85), 0.2, 0.55),
                (load("k1/impact-sounds/impactTin_medium_00%d.ogg" % (i + 2), 1.1), 0.34, 0.3))
        save(a, "die_armour_%d" % i, cap=0.9)
    # Skeleton Archer: the bowstring snaps (a bright twang that drops away) as it falls apart.
    for i, f in enumerate([392, 349, 440]):
        tw = glide(f, f * 0.55, 0.32, 0.5) * env(int(0.32 * R), 0.001, 0.07)
        tw = tw + 0.4 * glide(f * 2, f * 1.1, 0.32, 0.5) * env(int(0.32 * R), 0.001, 0.04)
        a = mix((game(CRUNCH[i + 1]), 0.02, 0.8), (tw, 0, 0.55),
                (load("k1/impact-sounds/impactWood_light_00%d.ogg" % i, 1.2), 0.0, 0.5))
        save(a, "die_archer_%d" % i, cap=0.8)
    # Skeleton Mage: its magic fizzles out of it in a falling chime and a last ghostly breath.
    for i, (f, src) in enumerate([(1320, "breath"), (1175, "breath"), (1480, "weird_04")]):
        tt = t(0.7)
        chime = (glide(f, f / 2, 0.7, 0.6) + 0.5 * glide(f * 1.5, f * 0.75, 0.7, 0.6)) * np.exp(-tt / 0.22)
        a = mix((game(CRUNCH[(i + 2) % 5]), 0, 0.7), (chime, 0.03, 0.3),
                (fade(load("k2/sci-fi-sounds/forceField_00%d.ogg" % i, 0.7, 0.6)), 0.0, 0.45),
                (lowpass(load("k2/creatures-1/%s.ogg" % src, 1.15, 0.5), 2500), 0.08, 0.4))
        save(verb(highpass(a, 220, 3), 0.6, 0.3), "die_mage_%d" % i, cap=1.0)
    # Bone Spider: a dry insect chitter and legs snapping, quick and high.
    for i, src in enumerate(["k2/creatures-1/bug_03", "k2/creatures-2/bug_05", "k2/creatures-2/bug_09"]):
        a = mix((load(src + ".ogg", 1.15, 0.4), 0, 0.8), (game(CRUNCH[(i + 3) % 5], 1.35), 0.04, 0.6),
                (crackle(0.25, 70, 0.1), 0.05, 0.35))
        save(a, "die_spider_%d" % i, cap=0.7)
    # Frost Wraith: no bones to break; it shatters like ice, the pieces tinkling down, and a
    # last cold breath of wind.
    for i in range(3):
        a = mix((load("k1/impact-sounds/impactGlass_heavy_00%d.ogg" % i), 0, 0.9),
                (load("k1/impact-sounds/impactGlass_light_00%d.ogg" % (i + 2), 1.1), 0.09, 0.5),
                (tinkle(0.55, 14, 2400, 6200), 0.04, 0.32),
                (whoosh(0.7, 2600, 500, 1.0, 0.05), 0.02, 0.35))
        save(a, "die_frost_%d" % i, cap=1.0)
    # Cinder Skeleton: charred bones crumble (the crunch, lower and duller), the fire in it
    # hisses out and the embers pop as they cool.
    for i in range(3):
        a = mix((lowpass(game(CRUNCH[i + 2], 0.85), 2200), 0, 0.8), (hiss(0.7, 0.16, 3500), 0.03, 0.22),
                (crackle(0.9, 40, 0.3), 0.02, 0.7), (thump(110, 50, 0.25), 0, 0.35))
        save(a, "die_cinder_%d" % i, cap=1.0)
    # Drowned Skeleton: the crunch under water (muffled), a gurgle and bubbles rising.
    for i, src in enumerate(["k2/creatures-1/burble_01", "k2/creatures-1/burble_02", "k2/creatures-2/slime_05"]):
        a = mix((lowpass(game(CRUNCH[i]), 900), 0, 0.85), (load(src + ".ogg", 1.0, 0.6), 0.04, 0.55),
                (bubbles(0.5, 9), 0.08, 0.3), (load("k2/sci-fi-sounds/slime_00%d.ogg" % (i % 2), 0.9, 0.4), 0.0, 0.35))
        save(a, "die_drowned_%d" % i, cap=0.9)
    # Sporeling: it's a mushroom, not bones: a wet squelch and a soft pop (its spore cloud
    # has its own "spore" puff).
    for i, src in enumerate(["slime_01", "slime_03", "slime_07"]):
        pop = mix((thump(420, 140, 0.12), 0, 1.0), (highpass(noise(0.01), 2000) * np.exp(-t(0.01) / 0.002), 0, 0.6))
        a = mix((load("k2/creatures-2/%s.ogg" % src, 1.1, 0.4), 0, 0.85), (pop, 0.02, 0.6))
        save(a, "die_spore_%d" % i, mean_db=-19.0, cap=0.6)
    # Rootbinder: wood splitting and a long creak as its roots let go, leaves rustling.
    for i in range(3):
        a = mix((load("k1/impact-sounds/impactWood_heavy_00%d.ogg" % i), 0, 0.9),
                (load("k1/rpg-audio/creak%d.ogg" % (i + 1), 1.25, 0.6), 0.06, 0.55),
                (game(CRUNCH[(i + 4) % 5]), 0.02, 0.35),
                (load("k1/rpg-audio/cloth%d.ogg" % (i + 1), 1.2), 0.1, 0.3))
        save(a, "die_root_%d" % i, cap=1.0)
    # Event skeletons.
    # Bloodbat: two squeaks and its wings flapping away to nothing.
    for i, (f0, f1) in enumerate([(5200, 2600), (4700, 2300), (5600, 3000)]):
        a = mix((squeak(f0, f1, 0.07), 0, 0.5), (squeak(f0 * 0.9, f1 * 0.8, 0.1), 0.09, 0.45),
                (flutter(0.35), 0.03, 0.7), (game(CRUNCH[i], 1.4), 0.05, 0.3))
        save(a, "die_bat_%d" % i, mean_db=-19.0, cap=0.6)
    # Moon Howler: a howl cut off into a whimper.
    for i, sp in enumerate([1.35, 1.45, 1.25]):
        h = load("k2/creatures-1/howl.ogg", sp, 0.45)
        h *= np.linspace(1, 0.15, len(h)) ** 1.5
        a = mix((h, 0, 0.75), (game(CRUNCH[(i + 1) % 5]), 0.18, 0.7))
        save(a, "die_howler_%d" % i, cap=0.9)
    # Queen Shade: a ghost's sigh, fading into a long echo.
    for i, (src, sp) in enumerate([("k2/creatures-1/weird_05", 0.8), ("k2/creatures-2/weird_06", 0.85), ("k2/creatures-1/breath", 0.7)]):
        a = mix((load(src + ".ogg", sp, 0.8), 0, 0.7), (whoosh(0.8, 300, 2200, 0.9, 0.5), 0, 0.3))
        save(highpass(verb(lowpass(a, 3500), 1.2, 0.55), 280, 3), "die_shade_%d" % i, cap=1.4)
    # Snow Roller: packed snow bursting, three crunches and a soft thump.
    for i in range(3):
        a = mix((load("k1/impact-sounds/footstep_snow_00%d.ogg" % i, 0.8), 0, 0.8),
                (load("k1/impact-sounds/footstep_snow_00%d.ogg" % (i + 1), 0.9), 0.07, 0.7),
                (load("k1/impact-sounds/footstep_snow_00%d.ogg" % (i + 2), 1.0), 0.15, 0.5),
                (load("k1/impact-sounds/impactSoft_heavy_00%d.ogg" % i), 0.0, 0.8))
        save(a, "die_snow_%d" % i, cap=0.8)
    # Bell Ringer: its bell hits the floor with a clang that rings on under the crunch.
    for i in range(3):
        a = mix((load("k1/impact-sounds/impactBell_heavy_00%d.ogg" % i), 0, 0.75), (game(CRUNCH[i]), 0.0, 0.7))
        save(a, "die_bell_%d" % i, cap=1.4)
    # Gift Thief: the sack bursts: coins and a shake of little bells (the coin sound plays too).
    for i in range(3):
        a = mix((load("k1/rpg-audio/handleCoins%s.ogg" % ("" if i % 2 == 0 else "2"), 1.1), 0, 0.6),
                (sleigh(0.4, 14), 0.02, 0.45), (game(CRUNCH[i + 1]), 0.0, 0.6))
        save(a, "die_thief_%d" % i, cap=0.9)

if WHICH in ("all", "roar"):
    # The Skeleton King: his old roar with his armour and crown clanging and his bones rattling.
    for i in range(3):
        rattle = mix(*[(load("k1/impact-sounds/impactWood_light_00%d.ogg" % (k % 5), 1.6), 0.04 + k * 0.045, 0.35) for k in range(6)])
        a = mix((game("roar_%d" % i), 0, 1.0), (load("k1/impact-sounds/impactPlate_heavy_00%d.ogg" % i, 0.9), 0.0, 0.55),
                (thump(85, 42, 0.5), 0.0, 0.5), (rattle, 0.05, 0.6))
        save(a, "roar_king_%d" % i, mean_db=-14.0, cap=1.4)
    # The Lich: not a beast's roar but a wail: whispers swell up into a choir of ghostly
    # voices over a cold, high chord, all in a long echo.
    for i, (src, sp) in enumerate([("k2/creatures-1/monster_03", 1.15), ("k2/creatures-1/alien_02", 0.95), ("k2/creatures-2/monster_18", 1.1)]):
        v = load(src + ".ogg", sp, 1.0)
        choir = chorus(v, [0.97, 1.0, 1.04])
        tt = t(1.4)
        chord = sum(np.sin(2 * np.pi * f * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * tt + k)) * tt) * g
                    for k, (f, g) in enumerate([(587, 0.5), (880, 0.4), (1245, 0.3)])) * env(len(tt), 0.25, 0.5)
        wh = whoosh(0.45, 2500, 6000, 1.2, 0.4)
        a = mix((wh, 0, 0.5), (choir, 0.3, 1.0), (chord, 0.3, 0.18))
        save(verb(a, 1.4, 0.5, 4500), "roar_lich_%d" % i, mean_db=-14.0, cap=2.0)
    # The Cinder Colossus: a huge, slowed-down roar inside a furnace: fire roaring up,
    # stone grinding and a low boom.
    for i, (src, sp) in enumerate([("k2/creatures-2/roar_05", 0.62), ("k2/creatures-2/roar_06", 0.6), ("k2/creatures-2/roar_04", 0.64)]):
        fire = load("k2/fire-staff/LEGIT_FIR_Fire_Staff %d-Audio.wav" % (i + 1), 0.7, 1.2)
        grind = mix(*[(load("k1/impact-sounds/impactMining_00%d.ogg" % ((i + k) % 5), 0.55), 0.1 + k * 0.22, 0.35) for k in range(4)])
        a = mix((lowpass(load(src + ".ogg", sp), 2500), 0, 1.0), (fire, 0.05, 0.55), (grind, 0.0, 0.6),
                (load("k2/sci-fi-sounds/lowFrequency_explosion_00%d.ogg" % (i % 2), 0.9), 0.0, 0.5))
        save(a, "roar_colossus_%d" % i, mean_db=-13.5, cap=2.0)
    # The Tidecaller: a deep moan like a whale under the sea, a gurgle and a wave crashing.
    for i, (f0, src) in enumerate([(120, "burble_01"), (105, "burble_02"), (135, "burble_01")]):
        tt = t(1.5)
        f = f0 * (1 + 0.35 * np.sin(np.pi * tt / 1.5) ** 2) * (1 + 0.01 * np.sin(2 * np.pi * 4 * tt))
        saw = 2 * ((np.cumsum(f) / R) % 1.0) - 1
        moan = (bandpass(saw, 420 + 260 * np.sin(np.pi * tt / 1.5), 2.5) * 2.5 + lowpass(saw, 300) * 0.5) * env(len(tt), 0.2, 0.7)
        wave = whoosh(0.9, 250, 2600, 0.7, 0.35) + whoosh(0.9, 3000, 400, 0.7, 0.1) * 0.6
        a = mix((moan, 0, 1.0), (load("k2/creatures-1/%s.ogg" % src, 0.7), 0.1, 0.45), (wave, 0.7, 0.55),
                (bubbles(1.0, 14, 180, 500), 0.2, 0.25))
        save(verb(a, 0.9, 0.3), "roar_tide_%d" % i, mean_db=-14.0, cap=2.0)
    # The Sporemother: a wet, croaking bellow, squelching, and a great puff of spores.
    for i, (src, sl) in enumerate([("troll_02", "slime_01"), ("troll_01", "slime_05"), ("grunt_01", "slime_03")]):
        tr = load("k2/creatures-1/%s.ogg" % src, 0.75)
        tr *= 1.0 + 0.35 * np.sin(2 * np.pi * 13 * t(len(tr) / R))
        puff = highpass(noise(0.7), 600) * (1 - np.exp(-t(0.7) / 0.03)) * np.exp(-t(0.7) / 0.18)
        a = mix((tr, 0, 1.0), (load("k2/creatures-2/%s.ogg" % sl, 0.8), 0.05, 0.6), (puff, 0.55, 0.45),
                (game("spore_0", 0.8), 0.6, 0.5))
        save(a, "roar_spore_%d" % i, mean_db=-14.0, cap=1.7)
    # The Blood Queen: a shriek, sharp and high, with bats' wings beating behind it.
    for i, (src, sp) in enumerate([("scream_01", 1.05), ("scream_02", 1.1), ("scream_01", 0.95)]):
        a = mix((load("k2/creatures-1/%s.ogg" % src, sp), 0, 1.0), (flutter(0.9, 20), 0.15, 0.5),
                (squeak(4800, 2400, 0.12), 0.05, 0.2), (squeak(4300, 2000, 0.12), 0.35, 0.2))
        save(verb(a, 0.8, 0.3), "roar_queen_%d" % i, mean_db=-14.0, cap=1.6)
    # Krampus: a goat's bleating bellow, his chains rattling and his bells jangling.
    for i, (src, sp) in enumerate([("troll_02", 0.85), ("grunt_01", 0.8), ("troll_01", 0.82)]):
        g = load("k2/creatures-1/%s.ogg" % src, sp)
        g *= 0.55 + 0.45 * np.sin(2 * np.pi * 7.5 * t(len(g) / R)) ** 2
        chains = mix((load("k1/rpg-audio/handleCoins.ogg", 0.7), 0, 0.6), (load("k1/rpg-audio/metalLatch.ogg", 0.8), 0.12, 0.5),
                     (load("k1/rpg-audio/beltHandle%d.ogg" % (i % 2 + 1), 0.8), 0.25, 0.5))
        a = mix((g, 0, 1.0), (chains, 0.05, 0.6), (sleigh(0.8, 9), 0.1, 0.35))
        save(a, "roar_krampus_%d" % i, mean_db=-14.0, cap=1.6)

if WHICH in ("all", "star"):
    # The Star Eater (version 268, the Starfall Abyss's boss): a roar from very far away,
    # slowed and hollow, over a deep humming chord like the void itself, a falling star's
    # whoosh and glassy chimes of starlight, all in a long echo. (python3 ... star)
    for i, (src, sp) in enumerate([("k2/creatures-2/roar_04", 0.55), ("k2/creatures-2/roar_06", 0.52), ("k2/creatures-2/roar_05", 0.58)]):
        v = lowpass(load(src + ".ogg", sp), 1600)
        tt = t(1.9)
        hum = sum(np.sin(2 * np.pi * f * tt + 0.4 * np.sin(2 * np.pi * 0.6 * tt + k)) * g
                  for k, (f, g) in enumerate([(55, 0.6), (82.5, 0.45), (110, 0.3), (164.8, 0.18)])) * env(len(tt), 0.35, 0.9)
        fall = whoosh(1.0, 7000, 700, 1.0, 0.55)
        a = mix((hum, 0, 0.55), (fall, 0.0, 0.4), (v, 0.15, 1.0), (tinkle(1.3, 12, 1700, 4300, 0.35), 0.45, 0.22))
        save(verb(a, 1.7, 0.5, 5200), "roar_star_%d" % i, mean_db=-14.0, cap=2.3)
if WHICH in ("all", "void"):
    # The Void Walker (version 269, the Starfall Abyss's own skeleton): its night-sky bones
    # crunch, then the void sucks the pieces back in (a whoosh played backwards, rising to a
    # stop) with a last glint of starlight, in a short echo. (python3 ... void)
    for i in range(3):
        suck = whoosh(0.55, 700 + 150 * i, 5200, 1.0, 0.05)[::-1].copy()
        a = mix((lowpass(game(CRUNCH[i + 1], 0.95), 3000), 0, 0.7), (suck, 0.03, 0.5),
                (tinkle(0.5, 7, 2600, 6200, 0.25), 0.5, 0.25))
        save(verb(a, 0.9, 0.35, 6000), "die_void_%d" % i, cap=1.2)
