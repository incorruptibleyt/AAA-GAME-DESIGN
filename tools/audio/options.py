# Option B (in the game for rogue, knight, barbarian and the hit, Jesse's pick Nov 10) and
# option C. Mage stays option A from soft.py, made quieter. Run: python3 tools/audio/options.py SND OUT_B OUT_C
import sys, numpy as np
SNDDIR, OB, OC = sys.argv[1], sys.argv[2], sys.argv[3]
sys.argv = [sys.argv[0], SNDDIR, OB, "none"]
exec(open(sys.argv[0].replace("options.py", "design.py")).read())
import os
def soften(a, lp=4500.0, att=0.006):
    a = lowpass(lowpass(a, lp), lp)
    n = int(att * R); a[:n] *= np.linspace(0, 1, n) ** 2
    return a
def blip(f0, f1, sec, dec):
    tt = t(sec); ph = 2 * np.pi * np.cumsum(np.geomspace(f0, f1, len(tt))) / R
    return np.sin(ph) * env(len(tt), 0.004, dec)
def put(folder, a, name, db, cap):
    global OUT
    OUT = folder; save(a, name, db, cap)

for i in range(3):
    sp = [1.0, 1.08, 0.94][i]
    # Rogue B: a short wooden "tock" (real recording) with a breath of air.
    a = mix((load("k1/impact-sounds/impactWood_light_00%d.ogg" % i, 1.5 * sp), 0, 1.0), (whoosh(0.08, 1800, 900, 1.2, 0.005), 0, 0.3))
    put(OB, soften(a, 3500), "shoot_rogue_%d" % i, -25.0, 0.12)
    # Rogue C: a soft low bow-string pluck.
    a = string(150 * sp, 0.2, 0.99)
    put(OC, soften(a, 1800, 0.003), "shoot_rogue_%d" % i, -25.0, 0.16)
    # Knight B: a cloth swish (real recording), low-passed.
    a = load("k1/rpg-audio/cloth%d.ogg" % (i + 1), 1.15 * sp)
    put(OB, soften(a, 3000), "shoot_knight_%d" % i, -25.0, 0.2)
    # Knight C: a low airy sweep and a tiny soft bell-like tink.
    a = mix((whoosh(0.18, 900, 380, 0.9, 0.03), 0, 1.0), (blip(1320 * sp, 1250 * sp, 0.12, 0.03), 0.02, 0.12))
    put(OC, soften(a, 3000), "shoot_knight_%d" % i, -25.0, 0.2)
    # Barbarian B: a heavy cloth throw (real recording), pitched down.
    a = load("k1/rpg-audio/cloth%d.ogg" % (i + 2), 0.75 * sp)
    put(OB, soften(a, 2200), "shoot_barbarian_%d" % i, -24.0, 0.24)
    # Barbarian C: just a soft low thud.
    a = mix((thump(110 * sp, 55, 0.14), 0, 1.0), (whoosh(0.1, 500, 250, 0.8, 0.01), 0, 0.3))
    put(OC, soften(a, 1500), "shoot_barbarian_%d" % i, -24.0, 0.16)
    # Mage B: a muffled magic "fwoom" (force field recording, pitched down and dark).
    ff = load("k2/sci-fi-sounds/forceField_00%d.ogg" % i, 0.8 * sp)[: int(0.22 * R)]
    put(OB, soften(ff * env(len(ff), 0.01, 0.07), 2500), "shoot_mage_%d" % i, -25.0, 0.2)
    # Mage C: a soft bell, one pure note that rings briefly.
    f = [523.0, 587.0, 494.0][i]
    a = mix((fm(f, 2.0, 0.6, 0.3, 0.08), 0, 1.0), (blip(f * 2, f * 2, 0.15, 0.04), 0, 0.15))
    put(OC, soften(a, 2800, 0.004), "shoot_mage_%d" % i, -26.0, 0.25)
for i in range(5):
    # Hit B: the punch recording alone, a little darker.
    a = load("k1/impact-sounds/impactPunch_medium_00%d.ogg" % i)
    put(OB, soften(a, 5000, 0.002), "hit_%d" % i, -21.0, 0.25)
    # Hit C: a soft, round thud.
    a = mix((load("k1/impact-sounds/impactSoft_medium_00%d.ogg" % i), 0, 1.0), (thump(130, 60, 0.08), 0, 0.4))
    put(OC, soften(a, 4000, 0.002), "hit_%d" % i, -21.0, 0.25)
