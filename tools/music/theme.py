# The Bone Chain theme, played in three styles so Jesse can pick one by ear.
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from song import *

MEL = [[("D4",1),("F4",1),("E4",.5),("D4",.5),("C#4",1)], [("D4",3),("A3",1)],
       [("Bb3",1),("D4",1),("F4",1),("G4",1)], [("A4",2),("G4",1),("F4",1)],
       [("E4",1),("F4",1),("G4",1),("A4",1)], [("Bb4",2),("A4",2)],
       [("G4",1),("F4",1),("E4",1),("C#4",1)], [("D4",4)]]
THEME_H = [[("Dm",2),("A",2)], [("Dm",4)], [("Bb",4)], [("F",4)], [("C",4)], [("Gm",2),("Dm",2)], [("A7",4)], [("Dm",4)]]
INTRO_H = [[("Dm",4)], [("Bb",4)], [("Gm",4)], [("A",4)]]
END_H = [[("Bb",2),("A7",2)], [("Dm",4)]]

def timeline(bars, start):
    out = []; b = start
    for bar in bars:
        for ch, d in bar: out.append((b, ch, d)); b += d
    return out, b

def chord_at(tl, beat):
    return [ch for b, ch, d in tl if b <= beat][-1]

def melody(s, part, start, octv=0, vel=88, legato=0.95):
    b = start
    for bar in MEL:
        for p, d in bar:
            s.note(part, b, n(p) + 12 * octv, d * legato, vel + (6 if d >= 2 else 0)); b += d

def layout():
    intro, b1 = timeline(INTRO_H, 0)
    t1, b2 = timeline(THEME_H, b1)
    t2, b3 = timeline(THEME_H, b2)
    end, b4 = timeline(END_H, b3)
    return intro, t1, t2, end, (0, b1, b2, b3, b4)

# ---------- A: dark orchestra ----------
def orchestra(seed=3):
    s = Song(88, seed)
    s.part("horn", 0, 60, 92, 70, 70); s.part("str", 1, 48, 127, 54, 75); s.part("vc", 2, 42, 124, 76, 55)
    s.part("cb", 3, 43, 104, 64, 50); s.part("timp", 4, 47, 127, 64, 60); s.part("choir", 5, 52, 112, 50, 90)
    s.part("hi", 6, 49, 100, 80, 80); s.part("perc", 9, 0, 108, 64, 60); s.part("cel", 7, 8, 100, 90, 95)
    intro, t1, t2, end, (_, b1, b2, b3, b4) = layout()
    for i, (b, ch, d) in enumerate(intro + t1 + t2 + end):
        hi = b >= b2
        s.chord("str", b, voice(ch, "D3", "A4")[-4:] if hi else voice(ch, "A2", "F4")[-3:], d, 62 if hi else 64)
        s.note("cb", b, root(ch, 2), d, 70)
        # cello ostinato: root, fifth, octave in eighths
        r = root(ch, 2); pat = [r, r + 7, r + 12, r + 7]
        if b >= b1 or b >= 8:
            for k in range(int(d * 2)): s.note("vc", b + k * .5, pat[k % 4], .45, 76 if k % 2 == 0 else 62)
        if b >= b1: s.note("timp", b, root(ch, 2), 1, 84 if hi else 68)
        if b >= b3 - 32 and ch in ("Dm", "Bb", "Gm", "F", "C", "A", "A7"):
            s.chord("choir", b, voice(ch, "A3", "D5")[-3:], d, 56)
    s.swell("str", 0, 8, 30, 120); s.swell("choir", b2, b2 + 8, 40, 120)
    melody(s, "horn", b1, 0, 84)
    melody(s, "hi", b2, 1, 80); melody(s, "horn", b2, 0, 80)
    for k in range(8): s.note("cel", b2 + k * 4 + 2.5, voice(chord_at(t2, b2 + k * 4 + 2.5), "D5", "D6")[k % 3], .5, 52)
    # war drums in the second half: taiko-style low toms
    for bar in range(8):
        bb = b2 + bar * 4
        for off, q, v in ((0, 41, 92), (1.5, 41, 70), (2, 43, 80), (3, 41, 66), (3.5, 43, 60)):
            s.note("perc", bb + off, q, .25, v)
    s.note("perc", b2 - 0.01, 49, 2, 60)            # soft crash into the big half
    for k in range(16): s.note("timp", b3 + 4 + k * .125, "D2", .12, 40 + k * 3)   # timpani roll
    s.note("timp", b4, "D2", 3, 100); s.chord("str", b4, voice("Dm", "D2", "D4"), 3, 70); s.note("cb", b4, "D1", 3, 90)
    return s, dict(room=0.85, level=0.7, damp=0.3)

# ---------- B: crypt music box ----------
def musicbox(seed=5):
    s = Song(96, seed)
    s.part("cel", 0, 8, 110, 58, 70); s.part("box", 1, 10, 112, 74, 85); s.part("pizz", 2, 45, 80, 50, 50)
    s.part("pad", 3, 89, 70, 64, 80, 40); s.part("harp", 4, 46, 84, 82, 65); s.part("bsn", 5, 70, 86, 44, 55)
    s.part("glk", 6, 9, 80, 90, 90); s.part("perc", 9, 0, 108, 64, 40)
    intro, t1, t2, end, (_, b1, b2, b3, b4) = layout()
    for b, ch, d in intro + t1 + t2 + end:
        s.chord("pad", b, voice(ch, "D3", "D4")[-3:], d, 48)
        r = root(ch, 2)
        for k in range(int(d)):        # pizzicato "oom-pah" bass
            s.note("pizz", b + k, r if k % 2 == 0 else r + 7, .4, 78 if k % 2 == 0 else 60)
        if b >= b1:
            arp = voice(ch, "A3", "A5")
            for k in range(int(d * 2)): s.note("harp", b + k * .5, arp[(k * 2) % len(arp)], .9, 46 + (8 if k % 4 == 0 else 0))
        if b >= b2:   # tiptoe percussion: soft kick + shaker
            for k in range(int(d * 2)):
                s.note("perc", b + k * .5, 70, .2, 50 if k % 2 else 64)
                if k % 4 == 0: s.note("perc", b + k * .5, 36, .3, 56)
    melody(s, "cel", b1, 1, 86)
    melody(s, "cel", b2, 1, 90); melody(s, "box", b2, 2, 50)
    # sneaky bassoon counter-line in the second half
    line = ["D3","A2","Bb2","F2","C3","G2","A2","D3"]
    for k, p in enumerate(line): s.note("bsn", b2 + k * 4 + 2, p, 1.8, 70); s.note("bsn", b2 + k * 4 + 3.5, n(p) + 2, .45, 58)
    for k in range(4): s.note("glk", b1 - 4 + k, voice("Dm", "D5", "D6")[k % 3], .4, 60)
    s.chord("cel", b4, ["D4","F4","A4","D5"], 3, 70, strum=0.08); s.note("pizz", b4, "D2", 1, 80)
    return s, dict(room=0.65, level=0.55, damp=0.5)

# ---------- C: folk adventure ----------
def folk(seed=7):
    s = Song(100, seed)
    s.part("flute", 0, 73, 96, 70, 65); s.part("harp", 1, 46, 92, 50, 60); s.part("vc", 2, 42, 92, 74, 60)
    s.part("gtr", 3, 24, 86, 40, 50); s.part("clar", 4, 71, 84, 86, 60); s.part("str", 5, 49, 74, 64, 75)
    s.part("perc", 9, 0, 116, 64, 40)
    intro, t1, t2, end, (_, b1, b2, b3, b4) = layout()
    for b, ch, d in intro + t1 + t2 + end:
        s.note("vc", b, root(ch, 2), d, 66)
        arp = voice(ch, "D3", "D5"); pat = [0, 2, 4, 2, 3, 5, 4, 2]
        for k in range(int(d * 2)): s.note("harp", b + k * .5, arp[pat[k % 8] % len(arp)], .8, 58 if k % 4 == 0 else 48)
        if b >= b2:
            s.chord("str", b, voice(ch, "F3", "F4")[-3:], d, 46)
            for k in range(int(d)):      # guitar strums on every beat, down-up feel
                s.chord("gtr", b + k, voice(ch, "D3", "E4")[-4:], .45, 60 if k % 2 == 0 else 46, strum=0.025)
        if b >= b1:                      # hand drums: low conga, high conga, tambourine
            for k in range(int(d * 2)):
                pos = (b + k * .5) % 4
                if pos == 0: s.note("perc", b + k * .5, 64, .2, 80)
                elif pos == 1.5: s.note("perc", b + k * .5, 63, .2, 62)
                elif pos == 2.5: s.note("perc", b + k * .5, 64, .2, 66)
                elif pos == 3: s.note("perc", b + k * .5, 63, .2, 56)
                if b >= b2 and pos in (1, 3): s.note("perc", b + k * .5, 54, .2, 46)
    melody(s, "flute", b1, 1, 84)
    melody(s, "flute", b2, 1, 90); melody(s, "clar", b2, 0, 64)
    s.note("perc", b4, 64, .3, 90); s.chord("harp", b4, ["D3","A3","D4","F4","A4","D5"], 3, 70, strum=0.06)
    s.note("vc", b4, "D2", 3, 74)
    return s, dict(room=0.6, level=0.5, damp=0.4)

if __name__ == "__main__":
    out = sys.argv[1]; os.makedirs(out, exist_ok=True)
    for name, fn in (("theme_a", orchestra), ("theme_b", musicbox), ("theme_c", folk)):
        s, rv = fn(); mid = os.path.join(out, name + ".mid"); wav = os.path.join(out, name + ".wav")
        s.save(mid); render(mid, wav, **rv)
        master(wav, os.path.join(out, name + ".mp3"), -20.0, 0, 2.5)
        print(name, "done")
