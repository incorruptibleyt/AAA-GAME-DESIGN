"""Generates Crypt Crawl's music loops (CC0, made for this game).

Run:  python3 tools/make_music.py   (needs numpy and ffmpeg)
Writes audio/music_dungeon.ogg and audio/music_boss.ogg. Each file loops seamlessly.
(The game now plays the CC0 orchestral tracks in audio/music instead; this is kept for reference.)
"""
import os
import subprocess
import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name):
    """'A3' -> frequency."""
    n, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[n] + 12 * (octave + 1) - 69) / 12)


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    try:
        from scipy.signal import lfilter
        return lfilter([1 - a], [1, -a], x)
    except ImportError:
        pass
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def env(n, attack, release, sustain_level=1.0):
    t = np.arange(n) / RATE
    e = np.minimum(1.0, t / max(attack, 1e-4)) * sustain_level
    tail = np.clip((n / RATE - t) / max(release, 1e-4), 0, 1)
    return e * tail


def saw(f, n, detune=0.0):
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for d in (-detune, 0.0, detune):
        ph = (t * f * (1 + d)) % 1.0
        out += 2 * ph - 1
    return out / 3


def sine(f, n):
    return np.sin(2 * np.pi * f * np.arange(n) / RATE)


def tri(f, n):
    ph = (np.arange(n) / RATE * f) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def add(buf, start_s, sig):
    i = int(start_s * RATE) % len(buf)
    end = i + len(sig)
    if end <= len(buf):
        buf[i:end] += sig
    else:  # wrap round so the loop stays seamless
        k = len(buf) - i
        buf[i:] += sig[:k]
        buf[: len(sig) - k] += sig[k:]


def reverb(x, mix=0.25):
    out = x.copy()
    for d, g in ((0.031, 0.5), (0.047, 0.45), (0.071, 0.4), (0.113, 0.35), (0.173, 0.3), (0.263, 0.25)):
        k = int(d * RATE)
        wet = np.zeros_like(x)
        src = x.copy()
        for _ in range(4):
            src = np.roll(src, k) * g
            wet += src
        out += wet * mix
    return out


def kick(n=0.35):
    m = int(n * RATE)
    t = np.arange(m) / RATE
    f = 45 + 90 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 9)


def tom(freq, n=0.4):
    m = int(n * RATE)
    t = np.arange(m) / RATE
    f = freq * (1 + 0.6 * np.exp(-t * 20))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 7) + rng.normal(0, 0.05, m) * np.exp(-t * 30)


def tick(n=0.05):
    m = int(n * RATE)
    return rng.normal(0, 1, m) * np.exp(-np.arange(m) / RATE * 80)


def pluck(f, n=0.9):
    m = int(n * RATE)
    t = np.arange(m) / RATE
    s = tri(f, m) * 0.6 + sine(f * 2, m) * 0.25
    return s * np.exp(-t * 4.5)


def bell(f, n=2.5):
    m = int(n * RATE)
    t = np.arange(m) / RATE
    s = sine(f, m) + 0.5 * sine(f * 2.76, m) * np.exp(-t * 3) + 0.25 * sine(f * 5.4, m) * np.exp(-t * 6)
    return s * np.exp(-t * 1.6)


def pad(freqs, n):
    m = int(n * RATE)
    s = sum(saw(f, m, 0.004) for f in freqs) / len(freqs)
    return lowpass(lowpass(s, 600), 600) * env(m, 1.2, 1.2)


def write(name, buf):
    buf = buf / (np.max(np.abs(buf)) + 1e-9) * 0.85
    pcm = (buf * 32767).astype(np.int16)
    wav = os.path.join(OUT, name + ".wav")
    import wave
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)


CHORDS = {
    "Am": (["A2", "E3", "A3", "C4"], ["A3", "C4", "E4", "A4"]),
    "F": (["F2", "C3", "F3", "A3"], ["F3", "A3", "C4", "F4"]),
    "Dm": (["D2", "A2", "D3", "F3"], ["D3", "F3", "A3", "D4"]),
    "E": (["E2", "B2", "E3", "G#3"], ["E3", "G#3", "B3", "E4"]),
    "G": (["G2", "D3", "G3", "B3"], ["G3", "B3", "D4", "G4"]),
    "C": (["C3", "G3", "C4", "E4"], ["C4", "E4", "G4", "C5"]),
}


def dungeon():
    """About 2 minutes 17 seconds in five parts, so it takes a while to notice the loop:
    a quiet intro, the main groove, a melody, a drum-less breakdown, and a brighter reprise."""
    bpm = 84
    beat = 60 / bpm
    bar_s = 4 * beat
    # (chord for each 2-bar step, arp density 0-2, drums 0-2, toms)
    parts = [
        (["Am", "F", "Dm", "E"], 0, 0, False),              # bars 0-7: intro
        (["Am", "F", "Dm", "E"] * 2, 2, 2, False),          # bars 8-23: groove
        (["Dm", "Am", "E", "Am"], 1, 0, True),              # bars 24-31: breakdown
        (["Am", "G", "F", "E", "Am", "G", "C", "E"], 2, 2, False),  # bars 32-47: reprise
    ]
    bars = sum(len(p[0]) * 2 for p in parts)
    buf = np.zeros(int(bars * bar_s * RATE))
    bar = 0
    for chords, arp, drums, toms in parts:
        for name in chords:
            low, up = CHORDS[name]
            for half in range(2):
                t0 = (bar + half) * bar_s
                if half == 0:
                    add(buf, t0, pad([hz(n) for n in low], 2 * bar_s) * 0.55)
                    m = int(2 * bar_s * RATE)
                    add(buf, t0, sine(hz(low[0]) / 2, m) * env(m, 0.5, 1.0) * 0.35)
                if arp:
                    order = [0, 1, 2, 3, 2, 1, 2, 3] if half == 0 else [0, 2, 1, 3, 2, 3, 1, 2]
                    for i in range(8):
                        if arp == 1 and i % 2:
                            continue
                        add(buf, t0 + i * beat / 2, pluck(hz(up[order[i]])) * (0.22 if i % 2 == 0 else 0.15))
                if drums:
                    add(buf, t0, kick() * 0.5)
                    add(buf, t0 + 2 * beat, kick() * 0.35)
                    if drums == 2 and half == 1:
                        add(buf, t0 + 3.5 * beat, kick() * 0.25)
                    for i in range(4):
                        add(buf, t0 + i * beat + beat / 2, tick() * 0.05)
                if toms and half == 1:
                    add(buf, t0 + 3 * beat, tom(110, 0.4) * 0.3)
            bar += 2
    # Bell melodies over the groove and the reprise, a low one in the breakdown.
    m1 = [("E5", 0), ("C5", 2), ("D5", 3), ("A4", 4), ("C5", 8), ("B4", 10), ("G#4", 12)]
    m2 = [("A4", 0), ("F4", 2), ("A4", 4), ("D5", 6), ("C5", 8), ("B4", 11), ("E4", 12), ("A4", 14)]
    m3 = [("C5", 0), ("E5", 1), ("D5", 2), ("B4", 4), ("A4", 6), ("C5", 8), ("A4", 10), ("G#4", 12), ("B4", 14)]
    for start, mel, vol, octave in ((16, m1, 0.18, 1), (20, m2, 0.15, 1), (24, m2, 0.16, 0.5), (36, m3, 0.17, 1), (44, m1, 0.18, 1)):
        for n, b in mel:
            add(buf, start * bar_s + b * beat, bell(hz(n) * octave) * vol)
    return reverb(buf, 0.3)


def boss():
    """About 2 minutes 5 seconds: a bass-and-drums intro, two driving sections with a
    lead, a half-time breakdown, a faster climb, and a tom-roll build back to the top."""
    bpm = 138
    beat = 60 / bpm
    bar_s = 4 * beat
    r1 = ["D2", "D2", "A#1", "C2"]
    r2 = ["G1", "G1", "A#1", "A1"]
    # (roots, bars, stabs, lead notes (one per bar) or None, mode)
    parts = [
        (r1, 8, False, None, "intro"),
        (r1, 16, True, [None] * 8 + ["D5", "F5", "E5", "C5", "D5", "A4", "A#4", "C5"], "drive"),
        (r2, 16, True, ["G4", "A#4", "A4", "F4", "G4", "D5", "C5", "A4"] * 2, "drive"),
        (r1, 8, False, ["D5", "D5", "C5", "C5", "A#4", "A#4", "A4", "A4"], "half"),
        (r1, 16, True, ["D6", "F6", "E6", "C6", "D6", "A5", "A#5", "C6"] * 2, "fast"),
        (r2, 8, True, ["G5", "A#5", "A5", "F5", "G5", "A#5", "C6", "A5"], "build"),
    ]
    bars = sum(p[1] for p in parts)
    buf = np.zeros(int(bars * bar_s * RATE))
    bar = 0
    for roots, count, stabs, lead, mode in parts:
        for k in range(count):
            t0 = bar * bar_s
            r = hz(roots[(k // 2) % 4])
            for i in range(8):  # driving eighth-note bass
                if mode == "half" and i % 2:
                    continue
                m = int(beat / 2 * RATE)
                f = r * (2 if i in (3, 6) else 1)
                note = lowpass(lowpass(saw(f, m, 0.006), 900), 900) * env(m, 0.005, 0.08)
                add(buf, t0 + i * beat / 2, note * 0.5)
            for i in range(4):
                if mode == "half" and i % 2:
                    continue
                add(buf, t0 + i * beat, kick() * 0.6)
                add(buf, t0 + i * beat + beat / 2, tick() * 0.08)
                if mode == "fast":
                    add(buf, t0 + i * beat + beat / 4, tick() * 0.04)
                    add(buf, t0 + i * beat + 3 * beat / 4, tick() * 0.04)
            if mode == "half" and k % 2 == 0:
                add(buf, t0, pad([r * 2, r * 2 * 1.189, r * 2 * 1.498], 2 * bar_s) * 0.4)
            if k % 2 == 1 or mode == "build":
                add(buf, t0 + 3 * beat, tom(140, 0.3) * 0.4)
                add(buf, t0 + 3.5 * beat, tom(100, 0.3) * 0.4)
            if mode == "build" and k >= count - 2:
                for i in range(8):
                    add(buf, t0 + i * beat / 2, tom(160 - i * 8, 0.25) * 0.3)
            if stabs:
                for b in (0, 1.5, 3):
                    m = int(0.25 * RATE)
                    chord = [r * 4, r * 4 * 1.189, r * 4 * 1.498]
                    stab = sum(saw(f, m, 0.01) for f in chord) / 3
                    add(buf, t0 + b * beat, lowpass(stab, 2200) * env(m, 0.005, 0.2) * 0.22)
            if lead and lead[k % len(lead)]:
                m = int(bar_s * RATE)
                add(buf, t0, lowpass(saw(hz(lead[k % len(lead)]), m, 0.003), 2500) * env(m, 0.05, 0.6) * 0.16)
            bar += 1
    return reverb(buf, 0.18)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("music_dungeon", dungeon())
    write("music_boss", boss())
    print("done")
