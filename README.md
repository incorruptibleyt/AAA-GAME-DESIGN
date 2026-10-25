# Bone Chain

A top-down dungeon action game for Android phones, built in **Godot 4.7**. Fight down through a crypt
one room at a time: drag your thumb to move, stand still to shoot, pick a blessing after every room,
and face the Skeleton King at the end of the floor.

**New here? Start with [SETUP.md](SETUP.md).** Everything works from a phone. You never need a computer.

## What's in this first playable slice

- **One floor:** 5 rooms (2 easy, 2 medium, 1 hard, picked at random from 36 hand-made rooms) plus a boss room. From floor 2 a room may take its right-hand side from another room (every room is drawn symmetric, so the result is lopsided and new), and from floor 3 the far half of one room may be joined to the near half of another. Floor 1 never has more than one skeleton mage in a wave.
- **Four heroes:** the Rogue (crossbow), plus the Knight (armoured sword waves), Barbarian (thrown axes, heals on kills) and Mage (exploding orbs), unlocked with coins from the HEROES screen. It shows one hero at a time turning on a pedestal (drag to spin them), with bars for health, damage, attack speed and speed, their special, and the three blessings only they can find.
- **Controls:** one-thumb floating joystick, auto-aim and auto-fire when standing still, a quick flick of the thumb or the DASH button (bottom right) to dash (untouchable while dashing), brief invulnerability after a hit.
- **Four skeletons.** The dangerous ones show a red warning before they attack:
  - *Minion*: rushes you in packs.
  - *Warrior*: shows a red strip, then lunges along it.
  - *Archer*: keeps its distance and fires aimed arrows.
  - *Mage*: marks a circle under you, then blows it up.
  - Each floor theme brings its own skeleton (from the second run): on Frozen Ossuary floors a *Frost Wraith* (a hooded ghost floating in a ragged cloak, ice shards circling it) wails, marks a line and fires an ice beam down it that slows you, and in the Ember Catacomb a *Cinder Skeleton* (charred bones with glowing cracks, black horns and a burning skull) runs at you leaving patches of fire behind.
- **The Skeleton King:** bone rings, a charge, meteor circles and summoning. He gets faster below half health.
- **Elite skeletons:** golden, bigger and tougher versions that drop extra coins, more common on deeper floors.
- **Endless descent:** beat the king and carry your blessings down to the next floor, where skeletons get about 55% more health and 35% more damage per floor, and bosses even more. Descending heals 30%.
- **Endless loops (Crypt Pass):** below floor 5 the crypt comes round again in loops of five floors, each one darker and redder. After each loop's last boss you choose: BANK AND LEAVE (the run ends and pays its coins again, plus 25% more for each Omen) or DESCEND DEEPER, which first has you pick one of three **Omens** (faster, tougher or harder-hitting skeletons, bigger waves, more golden elites, weaker hearts, or a faster-draining Bone Chain). Omens stack and each adds +25% score. Between loops you get full health and 2 more rerolls, and the run saves on the end-of-loop screen so CONTINUE comes back to that choice. See [scripts/loops.gd](scripts/loops.gd).
- **Coins and the Armory:** skeletons drop gold you keep between runs. Spend it on permanent upgrades (health, damage, attack speed, move speed, luckier hearts, a free blessing each run, and a once-per-run Second Wind). The Armory's **VAULT** tab sells six new blessings (2,850 coins in all): Soul Siphon, Frozen Ground, Executioner, Flashfire, Bone Splinters and Overcharge. Once bought, they can turn up in every run's blessing picks.
- **Music:** seven orchestral CC0 tracks from OpenGameArt, two for each floor theme (played one after the other) and a boss theme, credited in [audio/music/CREDITS.md](audio/music/CREDITS.md) and fetched by the Fetch CC0 music workflow. Music, Sounds and Graphics (High/Low) switches in the pause menu. Low graphics turns off shadows and glow, and keeps only 2 of the 6 torch lights for smoother play on older phones. Until a player picks a setting, the game switches itself to Low if it runs under 45 frames a second for 8 seconds (robot check: `slowphone`). The pause menu also shows the build, so testers can say which one they played.
- **Run report:** the end screen has a COPY RUN REPORT button. It copies the hero, damage taken from each enemy, blessings, room times and frame rate, to paste to Claude for balancing.
- **Grave Dash:** dash through a red enemy shot just before it hits for a PERFECT dodge: time slows, nearby shots shatter, the dash recharges and your hero fires a ring of 8 bolts back. Until you've landed 3 perfect dodges, the game slows down right before a shot hits and shows "DASH THROUGH IT!" (twice per run at most). Dash across a spike trap while it's armed and it fires on the skeletons around it instead.
- **Bone Chain:** kills close together build a multiplier (+0.1 per kill, +0.3 for elites, up to x3). It boosts coins and damage by +25% per full x1 (Marrow lets it climb to x4), and drains away 2.5 s after your last kill.
  The spine across the top lights one vertebra per +0.5 (bone-white, then gold, then red-hot), and shatters when the chain breaks.
- **Score:** every kill is worth points (10, elites 30, the boss 500) times the full chain. Specials also hit with the full chain, and a perfect dodge adds +0.5 and resets the timer. The best score is saved.
- **First run:** each room teaches one thing: move and shoot, then dash, then the Bone Chain, then the special (which starts full), then a synergy card, then the boss. Heroes and the Armory open once the first run ends. "Tutorial run" in MODES replays it.
- **Title screen:** PLAY, then HEROES and ARMORY, then MODES (the Daily Crypt, Curses and the tutorial run, with a DAILY READY tag when today's Daily Crypt is waiting) and the CRYPT PASS.
- **Special moves:** kills fill a ring on the star button (bottom right). When it's full, tap it: the Rogue fires three rings of bolts (Shadow Volley), the Knight stuns everything nearby (Shield Slam), the Barbarian spins and heals (Whirlwind), and the Mage drops five meteors (Meteor). Perfect dodges and elites charge it faster. Press E on a keyboard.
- **Floor themes:** each floor has its own look and its own props: the Bone Crypt (floor 1, skull piles and candles), the Frozen Ossuary (floor 2, blue torches, falling frost, icicles and ice crystals) and the Ember Catacomb (floor 3, charcoal slabs with fire glowing in the cracks, braziers and lava grates in the walls), then round again. See [scripts/floors.gd](scripts/floors.gd) and [scripts/props.gd](scripts/props.gd).
- **Blessings:** 21 shared blessings in four families (Shot, Flame, Frost, Bone) plus 3 for each hero (like Backstab for the Rogue or Meteor Storm for the Mage), each with its own icon and a rarity (common, rare, epic). Some only appear once you own the blessing they build on (Kindling and Pyre need Fire Shots). Owning both halves of a synergy brings its gold card: Shatter (Fire + Frost), Bone Storm (Fan + Pierce), Ossuary (Ward + Vitality), Wildfire (Fire + Twin Shots: burning spreads), Glacier (Frost + Ward: a blocked hit freezes skeletons nearby) and Deadeye (Keen Eye + Pierce: critical hits fly through everything). One free reroll per run, plus one more on each new floor.
- **Doors:** after each blessing (not in the first run) you pick one of two doors to the next room (see [scripts/doors.gd](scripts/doors.gd)): a family path (2 of the next 3 blessings are that family), a Healing Spring (heal 30%), a Treasure Room (+60% coins), a Shrine (+1 reroll) or a Champion's Door (a golden elite waits, and the blessing after is rare or better; never right before the boss). The Daily Crypt offers everyone the same doors.
- **Waves:** normal rooms come in 2–3 waves (the next one arrives when only a few skeletons are left). After the last kill the blessing cards show at once, and picking one goes straight to the next room.
- **Readable danger:** the camera sits close and follows the hero, red arrows on the screen edge point at enemies and warnings just off-screen, every enemy shot is hot pink-red with a dark ring and a pulse, and your own shots are small and see-through.
- **Healing hearts** (12 health) that skeletons sometimes drop and a beginner hint in room 1.
- **Game feel:** slow-motion close-up on the last kill of each room, a boss entrance with a title card, drifting embers, hit-stop, screen shake, hit flashes, knockback, damage numbers, particles, and real sound effects plus an announcer voice from Kenney's CC0 packs (fetched by the Fetch Kenney audio workflow into audio/sfx).
- **Crypt Pass ($4.99, one purchase through Google Play):** the free game ends after the floor 5 boss with an offer screen, and the title screen says "Free to try: floors 1-5". The Pass opens endless loops with Omens, **Daily Crypt** practice runs and **Curses**, and unlocks every hero. The game checks with Google Play again whenever it comes back to the front.
  - **Daily Crypt:** 3 floors with the same rooms, hero and three rules for everyone (one that helps, one curse, one trade-off), a theme for each weekday, one Official run a day plus Practice runs, and a result card to share: the result first, one square per room coloured by how high the Bone Chain climbed (a skull for each boss beaten, a cross where you fell), your days-in-a-row streak and the Google Play link. SHARE RESULT opens the phone's share menu with the card as a picture and the result as text (the text is copied too). It turns over at 07:00 UTC. Everyone gets the day's Official run free; Practice runs after it come with the Crypt Pass.
  - **Curses:** 10 curses, each with a level; switched-on curses add up to a Curse Level (+15% score per level, up to 17). Beating the floor 5 boss at a Curse Level earns that hero titles and looks (red lantern, red aura, gold bolts). Restless Dead is free for everyone.
  - **Free tastes:** each locked hero can be played once for free, and free players hear about the Pass once a session after reaching floor 3.
- **Continue:** the run is saved at the start of every room (scripts/run_save.gd), so if Android closes the game, CONTINUE on the title screen picks it up at the start of that room. Purchases use the official Godot Google Play Billing plugin in addons/ (Play build only); the product ID in Play Console must be `crypt_pass`.
- **Opening animation** ([scripts/intro.gd](scripts/intro.gd)): the game in miniature, in a small 3D crypt built from the game's own models. Two torches catch and three skeletons wake. The camera rushes in as the warrior's eyes light up and it roars, then the camera becomes your eyes: the warrior leaps high at you with its sword overhead, time slows at the top of the leap, you dodge as the blade smashes the floor where you stood, and your bolt bursts it into its own skull, jaw, weapon and loose bones. A burning chain lashes from it to the other two skeletons, bursting each in turn, hangs there burning a moment, then whips into the middle and snaps into BONE CHAIN as the words slam down with a shockwave and glowing cracks. A glint runs across the letters before they glide up onto the title screen's logo. About five seconds; a tap skips it. Robot check: `intro` (with `shots=` and `intromarks=` for pictures) and `introskip`.
- **Phone-ready:** portrait layout, notch-safe HUD, pause button, Android back pauses, low-health warning and vibration, best floor saved.

## Art

The **Bone Spider** is our own model: [tools/blender/bone_spider.py](tools/blender/bone_spider.py) builds and animates it in Blender from code (run it with the `bpy` Python module) and writes `art/original/Bone_Spider.glb`.


The characters, weapons and dungeon props are Kay Lousberg's free CC0 **KayKit** packs
(Adventurers, Skeletons, Dungeon Remastered), kept in [art/kaykit](art/kaykit/). The
[Fetch KayKit art](.github/workflows/fetch-art.yml) workflow downloads them from the official
repositories. If a model is missing, the game falls back to simple placeholder shapes.

The logo lettering is **Fruktur** by The Fruktur Project Authors (SIL Open Font License, [fonts/OFL.txt](fonts/OFL.txt)). [tools/store/make_logo.py](tools/store/make_logo.py) draws it with its gold shine, dark edge and glow into [art/ui/logo.png](art/ui/logo.png), which the opening, the title screen and the share picture use, and the store banner gets a two-line version from the same script.

## How it's built

Every push runs [.github/workflows/android-build.yml](.github/workflows/android-build.yml), which:
1. unpacks any KayKit zips,
2. lets a robot play a full run (it must beat the boss with no script errors),
3. exports a test app (`crypt-crawl.apk`) and checks it targets Android API 36 and is 16 KB page aligned,
4. builds the signed Google Play release (`crypt-crawl.aab`) with Gradle, using the upload key
   (locked in `signing/upload-keystore.p12.enc`, unlocked by the `ANDROID_UPLOAD_PASSWORD` secret;
   without that secret the Play build is only a test and isn't published),
5. posts both on the
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
  chain_spine.gd      the Bone Chain spine meter at the top
  telemetry.gd        anonymous run/error/crash reports to a Google Form (opt-in: asked once after a run; pause menu switch)
  store.gd            the Crypt Pass purchase through Google Play (buy, restore, offline cache)
  curses.gd           Curses, Curse Levels, hero rewards and the Daily Crypt (day, theme, rules)
  run_save.gd         saves the run at every room for CONTINUE
  heroes.gd           the playable heroes and their stats
  hero_screen.gd      the Heroes screen; hero_stage.gd draws the turning 3D hero on it
  share_card.gd       the Daily Crypt result card (squares on the end screen, emoji to share)
  share.gd            SHARE RESULT: the share picture and Android's share menu
  props.gd            each floor's own props (skulls, icicles, braziers, lava grates)
  pickup.gd           hearts and coins
  music.gd            background music (tracks in audio/)
  enemies/            minion, warrior, archer, mage, spider, bomber, spitter, Frost Wraith, Cinder Skeleton, Lich, Skeleton King
  hud.gd, joystick.gd on-screen controls and menus
  fx.gd, sfx.gd       particles and sound effects (files in audio/sfx)
  art.gd              finds KayKit models if they're present
  autoplay.gd         the test robot used by the cloud build
addons/GodotGooglePlayBilling/  official Google Play Billing plugin (MIT), used by store.gd
build/debug.keystore  shared debug signing key, so new builds install over old ones
```

The robot can be run locally with
`godot --headless -- autoplay god` (add `room=6` to jump to the boss, `shots=<folder>` for screenshots, `shop` to buy Armory upgrades first, `quittest` to test quitting a run, `gallery elites` for a line-up screenshot, `pass` to play with the Crypt Pass, `daily` for the Daily Crypt, `curses=brittle,famine` to switch curses on, `passmenu`/`cursemenu` for screenshots of those screens, `freeend floor=5` to test the end of the free game, `runs=3` to keep playing after a win, `killat=3` to close the game as room 3 starts and `continue` to press CONTINUE next time, `trial=mage` for a free hero trial, `dailymenu` for a Daily Crypt screenshot, `share` to print the Daily Crypt share text, `icons` for a picture of every blessing icon, `cards=backstab,nimble,quiver` to offer exactly those cards first, `vault` to own every Vault blessing, `heromenu` to picture every hero on the Heroes screen, `modesmenu` for the Modes screen, `newfoes floor=2 god` for the Frost Wraith and Cinder Skeleton up close, `props floor=3 god` for a floor's props, and `daily share die floor=2 room=3 chains=1.2,2,3` to picture the share card and save the share picture).
