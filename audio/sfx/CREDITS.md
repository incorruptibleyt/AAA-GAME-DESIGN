# Sound effect credits

Every sound here is CC0 (public domain): free to use, no credit required. Credited anyway.

- Kenney (kenney.nl): RPG Audio, Impact Sounds, Interface Sounds, UI Audio, Voiceover Pack
  Fighter (most sounds, fetched by `.github/workflows/fetch-audio.yml`), Sci-Fi Sounds
  (`boom_*`) and Music Jingles (`victory_*`). The warning bong (`warn_0`) is Interface
  Sounds' `bong_001`.
- rubberduck on OpenGameArt.org, "80 CC0 creature SFX" 1 and 2 (`roar_*`, pitched down a little;
  the Frost Wraith's cry `wraith_*` is its `howl` and `weird_02`, pitched down with an echo):
  https://opengameart.org/content/80-cc0-creature-sfx and
  https://opengameart.org/content/80-cc0-creture-sfx-2
- The Frost Wraith's ice beam (`beam_*`) mixes Kenney Sci-Fi Sounds' `laserLarge` and `forceField`.
- LEGIT Audio on OpenGameArt.org, "fire staff sound effects" (`ignite_*`, the Cinder Skeleton
  bursting into flame): https://opengameart.org/content/fire-staff-sound-effects

The extra packs are fetched by `.github/workflows/fetch-audio-extra.yml` to the
`audio-pack-2` release.
- Version 136: each hero's shot (`shoot_rogue_*`, `shoot_knight_*`, `shoot_barbarian_*`,
  `shoot_mage_*`) and the hit (`hit_*`) are made by `tools/audio/design.py`, layering Kenney's
  RPG Audio, Impact Sounds and Sci-Fi Sounds with made sounds. `splash`, `spore`, `roots`,
  `heart`, `tick`, `sting`, `shimmer` and `voice` are the game's own code-made sounds saved as
  files at 44.1 kHz. The shots and hits in the game are Jesse's picks: option B from
  `tools/audio/options.py` for rogue, knight, barbarian and the hit, and a quieter `soft.py` mage.
- Version 137: the Bone Drop chest (`chest_rattle_*`, `chest_snap_*`, `chest_lid_*`,
  `chest_coins_*`, `chest_tick_*`) is made by `tools/audio/chest.py` from Kenney's RPG Audio
  (metalLatch, metalClick, beltHandle, creak, chop, handleCoins) and Impact Sounds (metal and
  wood), with made rumbles, thumps and chimes. The game uses option B; A and C come from the
  same script.
- Version 251: each skeleton family's own death (`die_armour_*`, `die_archer_*`, `die_mage_*`,
  `die_spider_*`, `die_frost_*`, `die_cinder_*`, `die_drowned_*`, `die_spore_*`, `die_root_*`,
  `die_bat_*`, `die_howler_*`, `die_shade_*`, `die_snow_*`, `die_bell_*`, `die_thief_*`) and
  each boss's own roar (`roar_king_*`, `roar_lich_*`, `roar_colossus_*`, `roar_tide_*`,
  `roar_spore_*`, `roar_queen_*`, `roar_krampus_*`) are made by `tools/audio/voices.py`,
  layering the game's bone crunch and old roars, Kenney's Impact Sounds, RPG Audio and Sci-Fi
  Sounds, rubberduck's creature sounds and LEGIT Audio's fire staff with made sounds (ice
  tinkles, bubbles, embers, bat squeaks, a ghostly chord, a whale moan, little bells).
