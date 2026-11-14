import sys, theme, copy, subprocess, numpy as np
from song import *
def rms(wav, a, b):
    raw = subprocess.run(["ffmpeg","-v","error","-i",wav,"-ss",str(a),"-to",str(b),"-f","f32le","-ac","1","-"],capture_output=True).stdout
    x = np.frombuffer(raw, np.float32); return 20*np.log10(np.sqrt(np.mean(x**2))+1e-9)
for fn in sys.argv[1:]:
    s, rv = getattr(theme, fn)(); spb = 60 / s.bpm; row = []
    for name in list(s.parts) + ["ALL"]:
        t = copy.deepcopy(s)
        if name != "ALL": t.parts = {name: s.parts[name]}
        t.save("/tmp/p.mid"); render("/tmp/p.mid", "/tmp/p.wav", **rv)
        row.append("%s %.0f/%.0f" % (name, rms("/tmp/p.wav", 16*spb+1, 48*spb), rms("/tmp/p.wav", 48*spb+1, 80*spb)))
    print(fn, " | ".join(row))
