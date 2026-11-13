# The Crypt Race's own sounds (version 155, Supercell review fix 4), in three versions for
# Jesse to pick from. All are made here from tones and noise (no recordings needed):
#   A "arcade"       bright, clean beeps, a rising horn at GO, a quick major fanfare
#   B "crypt bells"  bell tones and a deep gong, the crypt's own church-bell feel
#   C "war drums"    low drum hits for the count, a brass horn at GO, a drum-roll finish
# Sounds: race_count (each of 3-2-1), race_go (GO!), race_lead (you took the lead),
# race_lost (the rival took it), race_surge (SURGE fired), race_hit (a rival surge lands),
# race_final (a racer reached the boss: the last leg), race_win (across the line first),
# race_lose (the rival got there first).
# Needs numpy and ffmpeg.
#   python3 tools/audio/race.py OUT_A OUT_B OUT_C
import sys, os, numpy as np
OA, OB, OC = sys.argv[1], sys.argv[2], sys.argv[3]
sys.argv = [sys.argv[0], "/nonexistent", OA, "none"]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "design.py")).read())
rng = np.random.default_rng(155)


def put(folder, a, name, db, cap=None):
	global OUT
	OUT = folder
	save(a, name, db, cap)


def soften(a, lp=6000.0, att=0.003):
	a = lowpass(a, lp)
	n = int(att * R); a[:n] *= np.linspace(0, 1, n) ** 2
	return a


def tone(f, sec, dec, harm=((1, 1.0), (2, 0.35), (3, 0.15)), att=0.004):
	# A clean tone with a few harmonics (arcade beeps, horn notes).
	tt = t(sec)
	return sum(np.sin(2 * np.pi * f * h * tt) * g for h, g in harm) * env(len(tt), att, dec)


def bell(f, sec, dec=0.6):
	# Inharmonic partials: a struck bell.
	return ring([(f, 1.0), (f * 2.0, 0.55), (f * 2.76, 0.4), (f * 5.4, 0.18), (f * 0.5, 0.3)], sec, dec) * env(int(sec * R), 0.002, 99)


def horn(f, sec, swell=0.06, bright=0.6):
	# A brass-like note: FM with a quick swell and a little vibrato.
	tt = t(sec)
	vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * tt) * np.minimum(tt / 0.25, 1.0)
	ph = 2 * np.pi * np.cumsum(f * vib) / R
	idx = bright * 3.0 * np.minimum(tt / swell, 1.0)
	a = np.sin(ph + idx * np.sin(ph))
	e = np.minimum(tt / swell, 1.0) * np.clip(1.0 - (tt - (sec - 0.12)) / 0.12, 0.0, 1.0)
	return a * e


def drum(f0, f1, sec, noise=0.35):
	n = int(sec * R)
	body = thump(f0, f1, sec)
	hit = lowpass(rng.standard_normal(n), 2500) * env(n, 0.001, 0.03) * noise
	return body + hit


def roll(sec, f, rate0=10.0, rate1=26.0):
	parts = []
	tt = 0.0
	while tt < sec:
		k = tt / sec
		parts.append((drum(f * rng.uniform(0.95, 1.05), f * 0.7, 0.18, 0.5), tt, 0.35 + 0.65 * k))
		tt += 1.0 / (rate0 + (rate1 - rate0) * k)
	return mix(*parts)


def seq(notes, maker, gap):
	return mix(*[(maker(f), i * gap, g) for i, (f, g) in enumerate(notes)])


C5, E5, G5, C6, E6, G6 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0
G4, A4, B4, D5 = 392.0, 440.0, 493.88, 587.33

# ---------------------------------------------------------------- A: arcade
put(OA, soften(tone(G5, 0.18, 0.06)), "race_count", -20.0)
put(OA, soften(mix((tone(C6, 0.55, 0.22), 0, 1.0), (tone(G5, 0.55, 0.22), 0, 0.6), (whoosh(0.3, 900, 5000, 1.0, 0.02), 0, 0.25))), "race_go", -18.0)
put(OA, soften(seq([(E6, 1.0), (G6, 1.0)], lambda f: tone(f, 0.16, 0.06), 0.08)), "race_lead", -21.0)
put(OA, soften(seq([(E5, 1.0), (C5 * 0.84, 1.0)], lambda f: tone(f, 0.2, 0.08, ((1, 1.0), (3, 0.3))), 0.1)), "race_lost", -22.0)
put(OA, soften(mix((whoosh(0.35, 400, 6000, 2.0, 0.01), 0, 1.0), (tone(1200, 0.3, 0.08, ((1, 1.0), (1.5, 0.5))), 0.02, 0.6))), "race_surge", -20.0)
put(OA, soften(mix((whoosh(0.3, 5000, 500, 2.0, 0.01), 0, 0.8), (tone(220, 0.3, 0.1, ((1, 1.0), (1.5, 0.4))), 0.0, 0.7))), "race_hit", -21.0)
put(OA, soften(seq([(G5, 0.8), (G5, 0.8), (D5 * 2, 1.0)], lambda f: tone(f, 0.14, 0.05), 0.11)), "race_final", -21.0)
put(OA, soften(mix((seq([(C5, 0.9), (E5, 0.9), (G5, 0.9), (C6, 1.0)], lambda f: tone(f, 0.22, 0.09), 0.09), 0, 1.0),
	(mix((tone(C6, 0.9, 0.35), 0, 1.0), (tone(E6, 0.9, 0.35), 0, 0.6), (tone(G5, 0.9, 0.35), 0, 0.6)), 0.36, 0.9))), "race_win", -18.0)
put(OA, soften(seq([(G4, 1.0), (G4 * 0.94, 0.9), (G4 * 0.84, 0.8)], lambda f: tone(f, 0.32, 0.14, ((1, 1.0), (3, 0.25))), 0.18), 3500), "race_lose", -21.0)

# ---------------------------------------------------------------- B: crypt bells
put(OB, soften(bell(880, 0.6, 0.18), 7000), "race_count", -21.0)
put(OB, soften(mix((bell(220, 1.6, 0.7), 0, 1.0), (bell(440, 1.2, 0.45), 0.0, 0.6), (thump(110, 45, 0.5), 0, 0.8)), 6000), "race_go", -18.0)
put(OB, soften(seq([(1046.5, 0.9), (1318.5, 1.0)], lambda f: bell(f, 0.5, 0.16), 0.09), 8000), "race_lead", -22.0)
put(OB, soften(seq([(659.25, 1.0), (493.88, 1.0)], lambda f: bell(f, 0.6, 0.2), 0.12), 5000), "race_lost", -22.0)
put(OB, soften(mix((whoosh(0.4, 300, 4500, 1.6, 0.01), 0, 0.9), (bell(1568, 0.6, 0.15), 0.05, 0.7)), 7000), "race_surge", -20.0)
put(OB, soften(mix((whoosh(0.35, 4000, 400, 1.6, 0.01), 0, 0.8), (bell(185, 0.7, 0.25), 0.02, 0.8)), 5000), "race_hit", -21.0)
put(OB, soften(seq([(392, 1.0), (392, 1.0), (392, 1.0)], lambda f: bell(f, 0.8, 0.3), 0.32), 6000), "race_final", -21.0)
put(OB, soften(mix((seq([(523.25, 0.9), (659.25, 0.9), (783.99, 0.9), (1046.5, 1.0)], lambda f: bell(f, 1.0, 0.35), 0.13), 0, 1.0),
	(bell(261.6, 2.0, 0.9), 0.52, 0.8)), 7000), "race_win", -18.0)
put(OB, soften(mix((bell(146.8, 1.6, 0.7), 0, 1.0), (bell(138.6, 1.6, 0.7), 0.25, 0.7)), 3000), "race_lose", -21.0)

# ---------------------------------------------------------------- C: war drums
put(OC, soften(drum(150, 70, 0.3, 0.4), 4000), "race_count", -19.0)
put(OC, soften(mix((drum(110, 45, 0.6, 0.5), 0, 1.0), (horn(233.1, 0.75), 0.03, 0.55), (horn(349.2, 0.75), 0.03, 0.4)), 4500), "race_go", -18.0)
put(OC, soften(seq([(349.2, 1.0), (466.2, 1.0)], lambda f: horn(f, 0.22, 0.03, 0.5), 0.12), 5000), "race_lead", -21.0)
put(OC, soften(seq([(311.1, 1.0), (233.1, 1.0)], lambda f: horn(f, 0.28, 0.04, 0.4), 0.14), 3500), "race_lost", -22.0)
put(OC, soften(mix((drum(90, 40, 0.4, 0.6), 0, 1.0), (whoosh(0.35, 400, 5000, 1.6, 0.01), 0, 0.6)), 5000), "race_surge", -20.0)
put(OC, soften(mix((drum(70, 35, 0.45, 0.6), 0, 1.0), (whoosh(0.3, 4000, 400, 1.6, 0.01), 0, 0.5)), 4000), "race_hit", -20.0)
put(OC, soften(mix((drum(120, 60, 0.25), 0, 1.0), (drum(120, 60, 0.25), 0.18, 1.0), (drum(90, 45, 0.4), 0.36, 1.0)), 4000), "race_final", -20.0)
put(OC, soften(mix((roll(0.7, 160), 0, 0.8), (drum(100, 40, 0.6, 0.6), 0.72, 1.0), (horn(349.2, 0.9), 0.72, 0.5), (horn(466.2, 0.9), 0.72, 0.4), (horn(587.3, 0.9), 0.72, 0.35)), 5000), "race_win", -18.0)
put(OC, soften(mix((drum(80, 35, 0.6, 0.4), 0, 1.0), (horn(155.6, 0.9, 0.08, 0.3), 0.1, 0.5)), 2500), "race_lose", -21.0)
print("race sounds A, B and C written")
