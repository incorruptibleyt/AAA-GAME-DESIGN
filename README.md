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
- **15 blessings** (upgrades) such as multishot, piercing, fire, frost, critical hits, a hit-blocking Bone Ward and healing on kills.
- **Elite skeletons:** golden, bigger and tougher versions that drop extra coins, more common on deeper floors.
- **Endless descent:** beat the king and carry your blessings down to the next floor, where skeletons are tougher.
- **Coins and the Armory:** skeletons drop gold you keep between runs. Spend it on permanent upgrades (health, damage, attack speed, move speed, luckier hearts, a free blessing each run, and a once-per-run Second Wind).
- **Music:** a calm dungeon theme and a faster boss theme (made by [tools/make_music.py](tools/make_music.py)), with Music, Sounds and Graphics (High/Low) switches in the pause menu. Low graphics turns off shadows and glow for smoother play on older phones.
- **Healing hearts** that skeletons sometimes drop, a beginner hint in room 1, and a golden arrow pointing to the open door.
- **Game feel:** slow-motion close-up on the last kill of each room, kill combos (x5 and up drop bonus coins), a boss entrance with a title card, drifting embers, hit-stop, screen shake, hit flashes, knockback, damage numbers, particles and synthesised sounds.
- **Phone-ready:** portrait layout, notch-safe HUD, pause button, Android back pauses, low-health warning and vibration, best floor saved.

## Art

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
  fx.gd, sfx.gd       particles and generated sound effects
  art.gd              finds KayKit models if they're present
  autoplay.gd         the test robot used by the cloud build
build/debug.keystore  shared debug signing key, so new builds install over old ones
```

The robot can be run locally with
`godot --headless -- autoplay god` (add `room=6` to jump to the boss, `shots=<folder>` for screenshots, `shop` to buy Armory upgrades first, `quittest` to test quitting a run, `gallery elites` for a line-up screenshot).
