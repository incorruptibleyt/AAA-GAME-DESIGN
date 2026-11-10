# Music

Bone Chain's own soundtrack (version 136): one Bone Chain tune played as a spooky music box,
arranged differently for the title, each crypt and the boss. Written as code in
`tools/music/score.py` and rendered with FluidSynth and the FluidR3 GM soundfont (MIT licence,
by Frank Wen), so there is nothing to credit beyond that.

| File | What |
|---|---|
| bc_title.ogg | Title theme: music box and harp, slow and gentle |
| bc_crypt.ogg | Bone Crypt: celesta tune, plucked strings, harp, bassoon, tiptoe shaker |
| bc_ice.ogg | Frozen crypt: slower, celesta and vibraphone, halo pad, triangle |
| bc_ember.ogg | Ember crypt: faster and lower, marimba tune, plucked strings, low toms |
| bc_drowned.ogg | Drowned Vault: slowest, vibraphone, choir pad, glassy bells |
| bc_grotto.ogg | Glowcap Grotto: kalimba tune with ocarina, marimba, wood blocks |
| bc_boss.ogg | Boss: the tune over war drums, timpani, choir, cellos and brass |
| bc_*_fight.ogg | Each crypt's fight layer (low strings, cello rhythm, war drums), in sync with its track; the game fades it in while enemies are alive |

Every file is a seamless loop: the piece is rendered twice through and the second pass kept,
so the end's echo flows into the start.
