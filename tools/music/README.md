# Bone Chain music tools

The game's own music is written as code and rendered with FluidSynth and the FluidR3 GM
soundfont (MIT licence), so every track can share one tune and stay in one style.

- `song.py`: a tiny composing kit (notes in beats → MIDI → FluidSynth → mastered ogg/mp3).
- `theme.py`: the Bone Chain tune in three styles (A dark orchestra, B spooky music box,
  C folk adventure). `python3 tools/music/theme.py OUT`
- `stems.py`: renders each part alone and prints its loudness in both halves, to check the mix
  (Claude can't hear, so the mix is balanced by numbers and Jesse's ears decide).

Needs: `apt-get install fluidsynth fluid-soundfont-gm`, `pip install mido numpy`, ffmpeg.
