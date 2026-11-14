# The sounds in the game (version 136, second take after Jesse found the first slightly
# annoying). Uses design.py's helpers; run: python3 tools/audio/soft.py SND audio/sfx
# Softer second take: shots you hear hundreds of times a run must be short, round and
# gentle: no hiss above ~5 kHz, no metal ring, soft attack, a little pitch variety.
import sys, numpy as np
sys.argv = [sys.argv[0], sys.argv[1], sys.argv[2], "none"]
exec(open(sys.argv[0].replace("soft.py", "design.py")).read())

def soften(a, lp=4500.0, att=0.006):
    a = lowpass(lowpass(a, lp), lp)            # two passes: a gentler top end
    n = int(att * R); a[:n] *= np.linspace(0, 1, n) ** 2
    return a

def blip(f0, f1, sec, dec):
    # A rounded tone gliding from f0 to f1 (a soft "pew"/"bloop"), sine only.
    tt = t(sec); ph = 2 * np.pi * np.cumsum(np.geomspace(f0, f1, len(tt))) / R
    return np.sin(ph) * env(len(tt), 0.004, dec)

# Rogue: a soft "thwip": a short low-passed air puff and a muted wooden tick.
for i, (f, sp) in enumerate([(1, 1.25), (2, 1.35), (0, 1.3)]):
    a = mix((whoosh(0.11, 2200, 900, 1.3, 0.008), 0, 1.0),
            (load("k1/impact-sounds/impactWood_light_00%d.ogg" % f, sp)[: int(0.06 * R)], 0, 0.35),
            (blip(520, 300, 0.07, 0.025), 0, 0.25))
    save(soften(a, 3800), "shoot_rogue_%d" % i, -24.0, 0.16)
# Knight: a soft sword swish: a wide low whoosh and a faint, low-passed blade.
for i, (src, sp) in enumerate([("knifeSlice.ogg", 0.9), ("knifeSlice2.ogg", 0.85), ("knifeSlice.ogg", 0.8)]):
    a = mix((whoosh(0.2, 1300, 450, 0.9, 0.03), 0, 1.0), (load("k1/rpg-audio/" + src, sp), 0, 0.3))
    save(soften(a, 3200), "shoot_knight_%d" % i, -24.0, 0.22)
# Barbarian: a deep "whum" of a heavy axe leaving the hand.
for i, f0 in enumerate([600, 540, 660]):
    a = mix((whoosh(0.22, f0, 220, 0.8, 0.035), 0, 1.0), (thump(120, 65, 0.1), 0, 0.45))
    save(soften(a, 2500), "shoot_barbarian_%d" % i, -23.0, 0.24)
# Mage: a soft magic "bloop": a pure rising tone with a quiet fifth above and a breath of air.
for i, f in enumerate([440, 494, 415]):
    a = mix((blip(f, f * 1.5, 0.16, 0.06), 0, 0.8), (blip(f * 1.5, f * 2.25, 0.12, 0.04), 0.012, 0.25),
            (whoosh(0.1, 1800, 800, 1.0, 0.01), 0, 0.35))
    save(soften(a, 4000), "shoot_mage_%d" % i, -30.0, 0.2)  # Jesse: "a quieter version of A"
# Hit: keep the punch and thump, a softer crack, nothing above ~6 kHz.
for i in range(5):
    a = mix((load("k1/impact-sounds/impactPunch_medium_00%d.ogg" % i), 0, 0.8),
            (load("k1/impact-sounds/impactWood_light_00%d.ogg" % i, 1.2), 0.0, 0.45),
            (thump(140, 60, 0.09), 0, 0.55))
    save(soften(a, 5500, 0.002), "hit_%d" % i, -21.0, 0.25)
