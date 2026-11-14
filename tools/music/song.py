# Tiny composing kit: write parts as notes in beats, save MIDI, render with FluidSynth.
import mido, random, subprocess, os
TPB = 480
NAMES = {"C":0,"C#":1,"Db":1,"D":2,"D#":3,"Eb":3,"E":4,"F":5,"F#":6,"Gb":6,"G":7,"G#":8,"Ab":8,"A":9,"A#":10,"Bb":10,"B":11}
def n(s):
    if isinstance(s, int): return s
    name, octv = (s[:2], s[2:]) if len(s) > 2 and s[1] in "#b" else (s[:1], s[1:])
    return 12 * (int(octv) + 1) + NAMES[name]
CHORDS = {"Dm":["D","F","A"],"Bb":["Bb","D","F"],"F":["F","A","C"],"C":["C","E","G"],"Gm":["G","Bb","D"],
          "A7":["A","C#","E","G"],"A":["A","C#","E"],"Am":["A","C","E"],"Eb":["Eb","G","Bb"],"Edim":["E","G","Bb"],
          "D":["D","F#","A"],"Cm":["C","Eb","G"],"Ab":["Ab","C","Eb"],"Fm":["F","Ab","C"],"G":["G","B","D"]}
def pcs(ch): return [NAMES[x] for x in CHORDS[ch]]
def voice(ch, lo, hi):
    """Every chord tone between lo and hi (midi numbers)."""
    return [p for p in range(n(lo), n(hi) + 1) if p % 12 in pcs(ch)]
def root(ch, octv): return n(CHORDS[ch][0] + str(octv))

class Song:
    def __init__(self, bpm, seed=1):
        self.bpm = bpm; self.parts = {}; self.rng = random.Random(seed); self.tr = 0
    def part(self, name, ch, prog, vol=100, pan=64, rev=50, cho=0):
        self.parts[name] = dict(ch=ch, prog=prog, vol=vol, pan=pan, rev=rev, cho=cho, ev=[], cc=[])
    def note(self, name, beat, pitch, dur, vel=80, hum=True):
        p = self.parts[name]; r = self.rng
        j = r.uniform(-0.012, 0.012) if hum and p["ch"] != 9 else 0
        v = max(1, min(127, int(vel + (r.uniform(-6, 6) if hum else 0))))
        q = n(pitch) + (self.tr if p["ch"] != 9 else 0)
        p["ev"].append((max(0, beat + j), q, dur, v))
    def chord(self, name, beat, pitches, dur, vel=70, strum=0.0):
        for i, q in enumerate(pitches): self.note(name, beat + i * strum, q, dur, vel)
    def cc(self, name, beat, num, val):
        self.parts[name]["cc"].append((beat, num, val))
    def swell(self, name, b0, b1, v0, v1, num=11):
        steps = max(2, int((b1 - b0) * 4))
        for i in range(steps + 1):
            self.cc(name, b0 + (b1 - b0) * i / steps, num, int(v0 + (v1 - v0) * i / steps))
    def save(self, path):
        mid = mido.MidiFile(ticks_per_beat=TPB)
        t0 = mido.MidiTrack(); mid.tracks.append(t0)
        t0.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm)))
        for name, p in self.parts.items():
            tr = mido.MidiTrack(); mid.tracks.append(tr); ch = p["ch"]
            msgs = [(0, 0, mido.Message("program_change", channel=ch, program=p["prog"]))]
            for num, val in ((7, p["vol"]), (10, p["pan"]), (91, p["rev"]), (93, p["cho"]), (11, 127)):
                msgs.append((0, 1, mido.Message("control_change", channel=ch, control=num, value=val)))
            for b, num, val in p["cc"]:
                msgs.append((int(b * TPB), 1, mido.Message("control_change", channel=ch, control=num, value=val)))
            for b, q, d, v in p["ev"]:
                msgs.append((int(b * TPB), 3, mido.Message("note_on", channel=ch, note=q, velocity=v)))
                msgs.append((int((b + d) * TPB) - 2, 2, mido.Message("note_off", channel=ch, note=q, velocity=0)))
            msgs.sort(key=lambda m: (m[0], m[1]))
            last = 0
            for t, _, m in msgs:
                tr.append(m.copy(time=t - last)); last = t
        mid.save(path)

def render(mid, wav, sf="/usr/share/sounds/sf2/FluidR3_GM.sf2", room=0.75, level=0.6, width=0.9, damp=0.35, gain=0.6):
    subprocess.run(["fluidsynth", "-ni", "-q", "-g", str(gain), "-r", "44100",
                    "-o", "synth.reverb.room-size=%s" % room, "-o", "synth.reverb.level=%s" % level,
                    "-o", "synth.reverb.width=%s" % width, "-o", "synth.reverb.damp=%s" % damp,
                    "-F", wav, sf, mid], check=True, stdout=subprocess.DEVNULL)

def mean_db(path, af=None):
    cmd = ["ffmpeg", "-i", path] + (["-af", af + ",volumedetect"] if af else ["-af", "volumedetect"]) + ["-f", "null", "-"]
    err = subprocess.run(cmd, capture_output=True, text=True).stderr
    return float(err.split("mean_volume:")[1].split("dB")[0])

def master(wav, out, mean=-20.0, fade_in=0.0, fade_out=3.0, br="160k"):
    """Gentle glue compression, then one fixed gain so the whole piece sits at the game's music
    loudness (no automatic gain riding, so crescendos stay), a peak limiter and fades."""
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", wav],
                               capture_output=True, text=True).stdout)
    comp = "acompressor=threshold=-20dB:ratio=2:attack=30:release=300"
    gain = mean - mean_db(wav, comp)
    af = comp + ",volume=%.2fdB,alimiter=limit=0.8:attack=5:release=80:level=false" % gain
    if fade_in: af += ",afade=t=in:d=%s" % fade_in
    if fade_out: af += ",afade=t=out:st=%s:d=%s" % (dur - fade_out, fade_out)
    codec = ["-c:a", "libmp3lame", "-b:a", br] if out.endswith(".mp3") else ["-c:a", "libvorbis", "-q:a", "5"]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", af, "-ar", "44100"] + codec + [out], check=True)
