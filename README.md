# Crypt Crawl

A top-down dungeon action game for Android phones, built in **Godot 4.5**. Fight down through a crypt
one room at a time: drag your thumb to move, stand still to shoot, pick a blessing after every room,
and face the Skeleton King at the end of the floor.

**New here? Start with [SETUP.md](SETUP.md).** Everything works from a phone. You never need a computer.

## What's in this first playable slice

- **One floor:** 5 rooms (2 easy, 2 medium, 1 hard, picked at random each run) plus a boss room.
- **Hero:** one-thumb floating joystick, auto-aim and auto-fire when standing still, brief invulnerability after a hit.
- **Four skeletons.** The dangerous ones show a red warning before they attack:
  - *Minion*: rushes you in packs.
  - *Warrior*: shows a red strip, then lunges along it.
  - *Archer*: keeps its distance and fires aimed arrows.
  - *Mage*: marks a circle under you, then blows it up.
- **The Skeleton King:** bone rings, a charge, meteor circles and summoning. He gets faster below half health.
- **11 blessings** (upgrades) such as multishot, piercing, fire, critical hits and healing on kills.
- **Game feel:** hit-stop, screen shake, hit flashes, knockback, damage numbers, particles and synthesised sounds.
- **Phone-ready:** portrait layout, notch-safe HUD, auto-pause when you leave the app, best run saved.

## Art

Everything is built from code, so the game runs with simple placeholder shapes out of the box.
Drop Kay Lousberg's free CC0 **KayKit** packs (glTF versions) into [ArtZips](ArtZips/) and the next
build swaps in the real knight, skeletons, pillars, barrels and torches automatically.

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
  enemies/            minion, warrior, archer, mage, Skeleton King
  hud.gd, joystick.gd on-screen controls and menus
  fx.gd, sfx.gd       particles and generated sound effects
  art.gd              finds KayKit models if they're present
  autoplay.gd         the test robot used by the cloud build
build/debug.keystore  shared debug signing key, so new builds install over old ones
```

The robot can be run locally with
`godot --headless -- autoplay god` (add `room=6` to jump to the boss, `shots=<folder>` for screenshots).
