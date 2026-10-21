# Crypt Crawl

A top-down dungeon action game for phones, built in Unity. Fight down through a crypt one room
at a time: drag your thumb to move, stand still to shoot, pick a blessing after every room, and
face the Skeleton King at the end of the floor.

Art comes from Kay Lousberg's free CC0 **KayKit** packs, so every model shares one style.
Until those are imported, the game runs on built-in placeholder shapes.

**New here? Start with [SETUP.md](SETUP.md).** It takes you from installing Unity to playing on your phone.

## What's in this first playable slice

- **One floor:** 5 hand-built rooms (2 easy, 2 medium, 1 hard, shuffled each run) plus a boss room.
- **Hero:** one-thumb floating joystick, auto-aim and auto-fire when standing still, brief invulnerability after a hit.
- **Four skeletons.** The dangerous ones show a red warning before they attack:
  - *Minion*: rushes you in packs.
  - *Warrior*: shows a red strip, then lunges along it.
  - *Archer*: keeps its distance and fires aimed arrows.
  - *Mage*: marks a circle under you, then blows it up.
- **The Skeleton King:** four attack patterns (bone rings, charge, meteor circles, summoning), and he gets faster below half health.
- **11 blessings** (upgrades), such as multishot, piercing, fire, critical hits and healing on kills. Pick one of three after each room.
- **Game feel:** hit-stop, screen shake, hit flashes, knockback, damage numbers, particles and synthesised sound effects.
- **Phone-ready:** portrait layout for 1080x1920, notch-safe HUD, 60 fps target, auto-pause when the app is backgrounded.
- **One-click art hookup:** *Crypt Crawl → Link KayKit Assets* finds the models, sets up the rigs and builds the animator.

## How the project is organised

```
Assets/CryptCrawl/
  Scripts/
    Core/      GameManager (run flow), camera, input, materials, effects, sound
    World/     Room builder and the text-drawn room layouts
    Combat/    Health/damage base class, projectiles, attack warnings
    Player/    Hero and the blessing (upgrade) list
    Enemies/   Skeleton types and the boss
    UI/        HUD, joystick, cards, damage numbers
    Art/       KayKit model lookup and character animation
  Editor/      Project setup and the KayKit linker (menu: Crypt Crawl)
```

The whole scene is built from code when you press Play, so there are no prefabs or scene wiring to break.

## Roadmap

1. **Now:** playable slice (this).
2. **Next:** hero select (all five KayKit heroes, each with its own attack), a hub area, and real sound and music from free CC0 packs.
3. **Then:** floors 2 to 5 with new room sets and bosses, a meta-progression shop, URP post-processing (bloom, colour grading), and store builds.
