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
| bc_moon.ogg | Blood Moon event (crypt and title): music box and flute over a choir, cello counter line, heartbeat drum |
| bc_queen.ogg | The Blood Moon Queen: the boss arrangement led by a church organ |
| bc_frost.ogg | Frostfall event (hall and title): glockenspiel and celesta over slow strings, harp, a tuba counter line, sleigh bells |
| bc_krampus.ogg | Krampus: the boss arrangement led by French horns, tubular bells doubling the tune |
| bc_tomb.ogg | Sandfall Tomb (floor 5): shehnai and oboe tune, sitar broken chords, slow strings, clarinet counter line, kalimba, hand drums and tambourine |
| bc_mine.ogg | Amethyst Mine (floor 7): harmonica and banjo tune, nylon guitar broken chords, halo pad, tuba counter line, xylophone, pick clinks and low toms |
| bc_library.ogg | Whispering Library (floor 8): harpsichord and flute tune, harp broken chords, soft voices, cello counter line, vibraphone, a ticking clock |
| bc_foundry.ogg | Clockwork Foundry (floor 9): clavinet and muted trumpet tune, tinkling bell broken chords, sweep pad, trombone counter line, steel drum sparks, a hammer kick, clanks and an anvil-bright triangle |
| bc_abyss.ogg | Starfall Abyss (floor 10): crystal-glass tune with a far-off pan flute, celesta broken chords, new-age pad, French horn counter line, glockenspiel sparks, a deep far boom, star-chime triangle and a soft shaker of star dust |
| bc_*_fight.ogg | Each crypt's fight layer (low strings, cello rhythm, war drums), in sync with its track; the game fades it in while enemies are alive |

Every file is a seamless loop: the piece is rendered twice through and the second pass kept,
so the end's echo flows into the start.
