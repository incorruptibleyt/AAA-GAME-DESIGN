# The Bone Drop chest's own sounds (version 137), in three versions for Jesse to pick from:
#   A "heavy crypt"   deep chains, a heavy lid, slow coins
#   B "treasure"      brighter chains, a firm lid, coins with a sparkle (the one in the game)
#   C "soft"          the same moments, shorter, quieter and darker
# Sounds: chest_rattle (the chains straining while it shakes, 1.3 s), chest_snap (the chains
# breaking), chest_lid (the lid flung back), chest_coins (the gold pouring out), chest_tick
# (one coin landing in your purse).
# Needs numpy and ffmpeg, and the unzipped packs as for design.py.
#   python3 tools/audio/chest.py SND OUT_A OUT_B OUT_C
import sys, numpy as np
SNDDIR, OA, OB, OC = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
sys.argv = [sys.argv[0], SNDDIR, OB, "none"]
exec(open(sys.argv[0].replace("chest.py", "design.py")).read())
rng = np.random.default_rng(137)

CLINKS = ["k1/impact-sounds/impactMetal_light_00%d.ogg" % i for i in range(5)] + \
		["k1/rpg-audio/metalClick.ogg", "k1/rpg-audio/beltHandle1.ogg", "k1/rpg-audio/beltHandle2.ogg"]

def put(folder, a, name, db, cap=None):
	global OUT
	OUT = folder
	save(a, name, db, cap)

def soften(a, lp=4500.0, att=0.004):
	a = lowpass(lowpass(a, lp), lp)
	n = int(att * R); a[:n] *= np.linspace(0, 1, n) ** 2
	return a

def clink(speed, gain):
	return (load(CLINKS[rng.integers(len(CLINKS))], speed)[: int(0.18 * R)], gain)

def rattle(sec, rate0, rate1, sp0, sp1, rumble):
	# Chain links knocking, faster and louder as the chest strains.
	parts = []
	tt = 0.0
	while tt < sec - 0.05:
		f = tt / sec
		a, g = clink(rng.uniform(sp0, sp1), 0.25 + 0.75 * f ** 1.5)
		parts.append((a, tt, g * rng.uniform(0.6, 1.0)))
		tt += rng.exponential(1.0 / (rate0 + (rate1 - rate0) * f))
	n = int(sec * R)
	swell = lowpass(lowpass(rng.standard_normal(n), 160), 160) * np.linspace(0, 1, n) ** 2 * 6.0
	parts.append((swell, 0.0, rumble))
	return mix(*parts)

def scatter(count, spread, sp0, sp1, g0):
	# Links flying and landing: a burst of clinks thinning out.
	return [(clink(rng.uniform(sp0, sp1), 1.0)[0], 0.02 + spread * (k / count) ** 1.6, g0 * (1.0 - 0.7 * k / count))
			for k in range(count)]

def sparkle(sec, base):
	tt = t(sec)
	out = np.zeros(len(tt))
	for k in range(7):
		f = base * rng.choice([1.0, 1.25, 1.5, 2.0, 2.5])
		s = int(rng.uniform(0, sec * 0.6) * R)
		r = ring([(f, 1.0), (f * 2.76, 0.3)], sec - s / R, 0.12)
		out[s:s + len(r)] += r * 0.5
	return out

# ---- A: heavy crypt
put(OA, rattle(1.3, 6, 22, 0.9, 1.25, 0.9), "chest_rattle", -24.0, 1.35)
put(OA, mix((load("k1/impact-sounds/impactMetal_heavy_002.ogg", 0.85), 0, 1.0), (load("k1/rpg-audio/metalLatch.ogg", 0.9), 0, 0.7),
		(load("k1/rpg-audio/chop.ogg", 0.8), 0.01, 0.6), *scatter(7, 0.45, 0.9, 1.2, 0.5)), "chest_snap", -20.0, 0.75)
put(OA, mix((load("k1/rpg-audio/creak2.ogg", 1.1)[: int(0.3 * R)], 0, 0.5), (load("k1/impact-sounds/impactWood_heavy_001.ogg", 0.75), 0.14, 1.0),
		(thump(90, 45, 0.3), 0.14, 0.8)), "chest_lid", -21.0, 0.7)
put(OA, mix((load("k1/rpg-audio/handleCoins.ogg", 0.85), 0, 1.0), (load("k1/rpg-audio/handleCoins2.ogg", 0.8), 0.18, 0.7)), "chest_coins", -24.0, 1.1)
put(OA, soften(load("k1/impact-sounds/impactMetal_light_001.ogg", 2.0)[: int(0.08 * R)], 5000), "chest_tick", -30.0, 0.08)

# ---- B: treasure (in the game)
put(OB, rattle(1.3, 8, 30, 1.35, 1.9, 0.5), "chest_rattle", -25.0, 1.35)
put(OB, mix((load("k1/rpg-audio/metalLatch.ogg", 1.05), 0, 1.0), (load("k1/impact-sounds/impactMetal_medium_001.ogg", 1.1), 0, 0.8),
		(load("k1/rpg-audio/chop.ogg", 1.0), 0.01, 0.4), *scatter(9, 0.5, 1.3, 1.9, 0.45)), "chest_snap", -21.0, 0.7)
put(OB, mix((load("k1/rpg-audio/creak3.ogg", 1.3)[: int(0.22 * R)], 0, 0.4), (load("k1/impact-sounds/impactWood_medium_002.ogg", 0.9), 0.1, 1.0),
		(thump(120, 60, 0.22), 0.1, 0.6)), "chest_lid", -22.0, 0.55)
put(OB, mix((load("k1/rpg-audio/handleCoins.ogg", 1.0), 0, 1.0), (load("k1/rpg-audio/handleCoins2.ogg", 1.05), 0.15, 0.7),
		(sparkle(0.9, 1800), 0.05, 0.25)), "chest_coins", -23.0, 1.0)
tick = mix((ring([(2600, 1.0), (6200, 0.25)], 0.09, 0.025), 0, 1.0), (load("k1/impact-sounds/impactMetal_light_003.ogg", 2.4)[: int(0.05 * R)], 0, 0.3))
put(OB, soften(tick, 7000, 0.002), "chest_tick", -29.0, 0.09)

# ---- C: soft
put(OC, soften(rattle(1.2, 5, 16, 1.2, 1.6, 0.35), 2600), "chest_rattle", -28.0, 1.25)
put(OC, soften(mix((load("k1/rpg-audio/metalClick.ogg", 0.9), 0, 1.0), *scatter(5, 0.35, 1.2, 1.5, 0.4)), 2800), "chest_snap", -25.0, 0.5)
put(OC, soften(mix((thump(100, 55, 0.2), 0, 1.0), (load("k1/impact-sounds/impactSoft_medium_001.ogg", 0.9), 0, 0.6)), 1800), "chest_lid", -24.0, 0.35)
put(OC, soften(load("k1/rpg-audio/handleCoins2.ogg", 1.0), 3000), "chest_coins", -27.0, 0.7)
put(OC, soften(ring([(1900, 1.0)], 0.07, 0.02), 3500, 0.003), "chest_tick", -31.0, 0.07)
