# Crypt Crawl

A top-down dungeon action game for Android phones, built in **Godot 4.5**. Fight down through a crypt
one room at a time: drag your thumb to move, stand still to shoot, pick a blessing after every room,
and face the Skeleton King at the end of the floor.

**New here? Start with [SETUP.md](SETUP.md).** Everything works from a phone. You never need a computer.

## What's in this first playable slice

- **One floor:** 5 rooms (2 easy, 2 medium, 1 hard, picked at random each run) plus a boss room.
- **Four heroes:** the Rogue (crossbow), plus the Knight (armoured sword waves), Barbarian (thrown axes, heals on kills) and Mage (exploding orbs), unlocked with coins from the HEROES screen.
- **Controls:** one-thumb floating joystick, auto-aim and auto-fire when standing still, a quick flick of the thumb to dash (untouchable while dashing), brief invulnerability after a hit.
- **Four skeletons.** The dangerous ones show a red warning before they attack:
  - *Minion*: rushes you in packs.
  - *Warrior*: shows a red strip, then lunges along it.
  - *Archer*: keeps its distance and fires aimed arrows.
  - *Mage*: marks a circle under you, then blows it up.
- **The Skeleton King:** bone rings, a charge, meteor circles and summoning. He gets faster below half health.
- **Elite skeletons:** golden, bigger and tougher versions that drop extra coins, more common on deeper floors.
- **Endless descent:** beat the king and carry your blessings down to the next floor, where skeletons are tougher.
- **Coins and the Armory:** skeletons drop gold you keep between runs. Spend it on permanent upgrades (health, damage, attack speed, move speed, luckier hearts, a free blessing each run, and a once-per-run Second Wind).
- **Music:** two-minute dungeon and boss themes with several sections each (made by [tools/make_music.py](tools/make_music.py)), with Music, Sounds and Graphics (High/Low) switches in the pause menu. Low graphics turns off shadows and glow, and keeps only 2 of the 6 torch lights for smoother play on older phones.
- **Run report:** the end screen has a COPY RUN REPORT button. It copies the hero, damage taken from each enemy, blessings, room times and frame rate, to paste to Claude for balancing.
- **Grave Dash:** dash through a red enemy shot just before it hits for a PERFECT dodge: time slows, nearby shots shatter, the dash recharges and your hero fires a ring of 8 bolts back. Dash across a spike trap while it's armed and it fires on the skeletons around it instead.
- **Bone Chain:** kills close together build a multiplier (+0.1 per kill, +0.3 for elites, up to x3). It multiplies coins, boosts damage (up to x2), and drains away 2.5 s after your last kill.
- **Special moves:** kills fill a ring on the star button (bottom right). When it's full, tap it: the Rogue fires three rings of bolts (Shadow Volley), the Knight stuns everything nearby (Shield Slam), the Barbarian spins and heals (Whirlwind), and the Mage drops five meteors (Meteor). Perfect dodges and elites charge it faster. Press E on a keyboard.
- **Blessings:** 21 blessings in four families (Bolt, Flame, Frost, Bone), each with an icon and a rarity (common, rare, epic). Some only appear once you own the blessing they build on (Kindling and Pyre need Fire Bolts). Owning both halves of a synergy brings its gold card: Shatter (Fire + Frost), Bone Storm (Fan + Pierce) and Ossuary (Ward + Vitality). One free reroll per run.
- **Waves:** normal rooms come in 2–3 waves (the next one arrives when only a few skeletons are left). After the last kill the blessing cards show at once, and picking one goes straight to the next room.
- **Readable danger:** the camera sits close and follows the hero, red arrows on the screen edge point at enemies and warnings just off-screen, every enemy shot is hot pink-red with a dark ring and a pulse, and your own shots are small and see-through.
- **Healing hearts** that skeletons sometimes drop and a beginner hint in room 1.
- **Game feel:** slow-motion close-up on the last kill of each room, a boss entrance with a title card, drifting embers, hit-stop, screen shake, hit flashes, knockback, damage numbers, particles, and real sound effects plus an announcer voice from Kenney's CC0 packs (fetched by the Fetch Kenney audio workflow into audio/sfx).
- **Phone-ready:** portrait layout, notch-safe HUD, pause button, Android back pauses, low-health warning and vibration, best floor saved.

## Art

The **Bone Spider** is our own model: [tools/blender/bone_spider.py](tools/blender/bone_spider.py) builds and animates it in Blender from code (run it with the `bpy` Python module) and writes `art/original/Bone_Spider.glb`.


The characters, weapons and dungeon props are Kay Lousberg's free CC0 **KayKit** packs
(Adventurers, Skeletons, Dungeon Remastered), kept in [art/kaykit](art/kaykit/). The
[Fetch KayKit art](.github/workflows/fetch-art.yml) workflow downloads them from the official
repositories. If a model is missing, the game falls back to simple placeholder shapes.

## How it's built

Every push runs [.github/workflows/android-build.yml](.github/workflows/android-build.yml), which:
1. unpacks any KayKit zips,
2. lets a robot play a full run (it must beat the boss with no script errors),
3. exports the Android app and posts it on the
   [latest-build release](https://github.com/incorruptibleyt/AAA-GAME-DESIGN/releases/tag/latest-build).

## How the project is organised

```
project.godot         Godot settings (portrait, mobile renderer)
scenes/main.tscn      empty start scene; scripts/game.gd builds everything
scripts/
  game.gd             the run: rooms, camera, saving, win/lose
  room.gd, layouts.gd room building and the text room layouts
  hero.gd, upgrades.gd
  armory.gd           permanent upgrades bought with coins
  heroes.gd           the playable heroes and their stats
  pickup.gd           hearts and coins
  music.gd            background music (tracks in audio/)
  enemies/            minion, warrior, archer, mage, Skeleton King
  hud.gd, joystick.gd on-screen controls and menus
  fx.gd, sfx.gd       particles and sound effects (files in audio/sfx)
  art.gd              finds KayKit models if they're present
  autoplay.gd         the test robot used by the cloud build
build/debug.keystore  shared debug signing key, so new builds install over old ones
```

The robot can be run locally with
`godot --headless -- autoplay god` (add `room=6` to jump to the boss, `shots=<folder>` for screenshots, `shop` to buy Armory upgrades first, `quittest` to test quitting a run, `gallery elites` for a line-up screenshot).
