"""Generates Crypt Crawl's music loops (CC0, made for this game).

Run:  python3 tools/make_music.py   (needs numpy and ffmpeg)
Writes audio/music_dungeon.ogg and audio/music_boss.ogg. Each file loops seamlessly.
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


def dungeon():
    bpm = 84
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    buf = np.zeros(int(length * RATE))
    chords = [["A2", "E3", "A3", "C4"], ["F2", "C3", "F3", "A3"], ["D2", "A2", "D3", "F3"], ["E2", "B2", "E3", "G#3"]]
    arps = [["A3", "C4", "E4", "A4"], ["F3", "A3", "C4", "F4"], ["D3", "F3", "A3", "D4"], ["E3", "G#3", "B3", "E4"]]
    for bar in range(bars):
        c = (bar // 2) % 4
        t0 = bar * 4 * beat
        if bar % 2 == 0:
            add(buf, t0, pad([hz(n) for n in chords[c]], 8 * beat) * 0.55)
            add(buf, t0, sine(hz(chords[c][0]) / 2, int(8 * beat * RATE)) * env(int(8 * beat * RATE), 0.5, 1.0) * 0.35)
        for i in range(8):  # eighth-note arpeggio, quiet
            if bar < 2:
                break
            note = arps[c][[0, 1, 2, 3, 2, 1, 2, 3][i]]
            add(buf, t0 + i * beat / 2, pluck(hz(note)) * (0.22 if i % 2 == 0 else 0.15))
        if bar >= 4:
            add(buf, t0, kick() * 0.5)
            add(buf, t0 + 2 * beat, kick() * 0.35)
            for i in range(4):
                add(buf, t0 + i * beat + beat / 2, tick() * 0.05)
    melody = [("E5", 0), ("C5", 2), ("D5", 3), ("A4", 4), ("C5", 8), ("B4", 10), ("G#4", 12)]
    for start_bar in (8, 12):
        for n, b in melody:
            add(buf, start_bar * 4 * beat + b * beat * 0.5 * 2, bell(hz(n)) * 0.18)
    return reverb(buf, 0.3)


def boss():
    bpm = 138
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    buf = np.zeros(int(length * RATE))
    roots = ["D2", "D2", "A#1", "C2"]
    for bar in range(bars):
        t0 = bar * 4 * beat
        r = hz(roots[(bar // 2) % 4])
        for i in range(8):  # driving eighth-note bass
            m = int(beat / 2 * RATE)
            f = r * (2 if i in (3, 6) else 1)
            note = lowpass(lowpass(saw(f, m, 0.006), 900), 900) * env(m, 0.005, 0.08)
            add(buf, t0 + i * beat / 2, note * 0.5)
        for i in range(4):
            add(buf, t0 + i * beat, kick() * 0.6)
            add(buf, t0 + i * beat + beat / 2, tick() * 0.08)
        if bar % 2 == 1:
            add(buf, t0 + 3 * beat, tom(140, 0.3) * 0.4)
            add(buf, t0 + 3.5 * beat, tom(100, 0.3) * 0.4)
        if bar >= 4:  # stabs
            for b in (0, 1.5, 3):
                m = int(0.25 * RATE)
                chord = [r * 4, r * 4 * 1.189, r * 4 * 1.498]
                stab = sum(saw(f, m, 0.01) for f in chord) / 3
                add(buf, t0 + b * beat, lowpass(stab, 2200) * env(m, 0.005, 0.2) * 0.22)
    lead = ["D5", "F5", "E5", "C5", "D5", "A4", "A#4", "C5"]
    for bar in range(8, 16):
        n = lead[bar - 8]
        m = int(4 * beat * RATE)
        add(buf, bar * 4 * beat, lowpass(saw(hz(n), m, 0.003), 2500) * env(m, 0.05, 0.6) * 0.16)
    return reverb(buf, 0.18)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("music_dungeon", dungeon())
    write("music_boss", boss())
    print("done")
