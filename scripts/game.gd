extends Node
## The game manager (loaded automatically as "Game"). Runs the title screen, the rooms of
## a floor, blessing picks, the boss, and the win/lose screens. It builds the whole world
## from code, so there is nothing to set up by hand.

enum State { TITLE, PLAYING, UPGRADE, TRANSITION, PAUSED, DEAD, VICTORY }

const EASY_ROOMS := 2
const MEDIUM_ROOMS := 2
const HARD_ROOMS := 1
const TUTORIAL_ROOMS := 2   # version 169: room 1 move and shoot, room 2 dash, then the boss
const SAVE_PATH := "user://save.cfg"
const SAVE_BACKUP := "user://save.cfg.bak"

const CAMERA_PITCH := 58.0
const CAMERA_FOV := 42.0

var state := State.TITLE
var world: Node3D
var hud: Hud
var hero: Hero
var boss: Enemy
var alive_enemies := 0
## Which floor of the crypt we're on. Each Skeleton King beaten takes you one floor deeper.
var floor_num := 1
## Coins kept between runs (spent in the Armory), and the ones picked up this run.
var coins := 0
var run_coins := 0
## Extra chance for skeletons to drop hearts, from the Armory's Lucky Bones.
var heart_bonus := 0.0

var _camera: Camera3D
var _cam_focus := Vector3.ZERO
## 0..1: how far the camera has moved in on the hero for the title screen's lobby.
var _lobby := 0.0
var _lobby_light: SpotLight3D
var _shake := 0.0
var shake_scale := 1.0   # the Screen shake setting
var flash_scale := 1.0   # v219: the Flashes setting (full, reduced to 0.3, off)
var light_dark := false  # v219: Darkness: Light (the Eclipse dims a third as much)
var vibration := true    # the Vibration setting
var colorblind := false  # the Colour-blind setting (attack warnings, version 148)
var _run: Array = []
## Version 171: which layout each room of _run came from ("E3", "M12 +rows M4 +right M7",
## "Boss"), for the stuck reports.
var _run_ids: Array = []
var _room_index := 0
var _taken := {}
var rerolls := 1
var _kills := 0
var _run_time := 0.0
var _state_time := 0.0
var _state_before_pause := State.PLAYING
## Set when the app loses focus (or Back is pressed) during a room fade or boss intro, which
## can't pause; the game pauses as soon as play starts instead of starting without the player.
var _pause_wanted := false
## Counts rooms loaded, so a wait that began in one room never acts in the next.
var _room_serial := 0
## Stuck-room watchdog: seconds since a skeleton was last hit or killed, and the room
## whose clear has already started (so the watchdog never clears a room twice).
var _stall_time := 0.0
var _stall_step := 0
var _cleared_serial := -1
var _no_enemies_time := 0.0
## The save already had stats when the game opened, so this isn't the very first launch.
var _hit_stop_left := 0.0
var _choices: Array = []
var _exit_arrow: Node3D
var _start_blessing := {}
## A Lucky Start (from a Bone Drop) given at the start of this run, for its banner.
var _lucky_blessing := {}
## Bone Drops earned this run (drops.gd: at most Drops.MAX_PER_RUN).
var _drops_run := 0
## Feats (feats.gd) already done, or found this run: each check is one look-up.
var _feats_got := {}
var _floor_hits := 0   # hits taken before this floor began (Flawless)
var _continued_floor := -1   # the floor a CONTINUE came back to (no Flawless there)
var _room_special := 0   # specials used before this room began (Specialist: in one boss fight)
var _top_chain_t := 0.0   # seconds the chain has stayed at x3 (Iron Chain)
var _best_chain_hold := 0.0
var _best_chain4 := 1.0   # the best chain on floor 4 or deeper (Chain Lord)
## Feats done during a fight: shown at once, written to the save when the room ends (or the
## game leaves the screen), so a kill never waits on a save file.
var _feats_unsaved: Array[String] = []
var _feats_run: Array[String] = []   # won this run, for the reveal after it
var _room_hits := 0    # ...and before this room began (Untouched, Clean Kill)
## Bone Road bones (bone_road.gd): not yet in the save, and earned since the last end
## screen (which shows them). They're saved with the coins (_save_coins, after every room),
## so leaving the game mid-run never loses them.
var _road_unsaved := 0
var _road_shown := 0
## Hero Mastery points (hero_mastery.gd), kept like the bones: not yet saved, earned since
## the last end screen, and earned this whole run (for the run report), for _mastery_hero.
var _mastery_unsaved := 0
var _mastery_shown := 0
var _mastery_run := 0
var _mastery_callout := ""   # a mid-run level-up, for the blessing screen to show
var _mastery_hero := ""
var _env: Environment
## Run report: numbers collected during a run so Jesse can paste them back for balancing.
const BUILD := "2026-11-24m"
var hit_source := ""
var _last_report := ""
var _rep := {}
var _fps_sum := 0.0
var _fps_n := 0
var _fps_low := 999.0
var _fps_t := 0.0
var _hitch_second := false   # a frame in this second took over 250 ms
## The longest single frame during play and where it was: a one-second "lowest" can't
## tell one long freeze from a slow second.
var _frame_us := 0
var _longest_ms := 0.0
var _longest_at := ""
var _longest_new := ""   # what appeared during the longest frame
var _added_now := {}
var _added_before := {}
var _spare_added := {}
var _high_graphics := true   # Medium or High: glow, outlines, colour grading
## Graphics: 3 High (everything), 2 Medium (no shadows or edge smoothing, a slightly smaller
## 3D picture), 1 Low (no glow or outlines either), 0 Low held at a steady 30 frames a second.
## A steady 30 looks smoother than a frame rate that jumps between 30 and 50.
const GRAPHICS_NAMES := ["Low · 30 FPS", "Low", "Medium", "High"]
var graphics_level := 3
## Every frame's length during play, in whole milliseconds,
## for the run report's "1% low": the frame rate of the slowest 1% of frames.
## (The last box holds 250 ms and longer.)
var _frame_hist := PackedInt32Array()
## The SPEED TEST is running (speed_test.gd): nothing is saved, so the test can't change
## coins, records, Mastery, the Bone Road or a saved run.
static var bench := false
var speed_card: Control   # the SPEED TEST's result card, while it shows
## Slow phones: until the player picks a graphics setting, the game watches the frame rate
## during play, and if it can't keep up it steps down a level by itself (and remembers it).
var _auto_graphics := false
var _auto_fps: Array[float] = []
var _auto_seen := 0
## The frame-rate check runs again for a minute after every 10 minutes of play, while the
## player hasn't chosen a setting: a phone that heats up in a long session slows down later.
var _auto_rewatch := false
var _auto_play_t := 0.0
## The robot's "slowphone" test sets this to pretend the phone is slow (-1 = really measure).
var fps_override := -1.0
## The opening animation while it plays.
var intro: Intro
var _back_ms := -10000   # when Back was last pressed on the title (twice to leave)
var _combo := 0
## Bone Chain: kills close together grow a multiplier on damage and coins.
## +0.1 per kill (+0.3 for elites), up to x3, gone after 2.5 s without a kill.
var chain := 1.0

func chain_max() -> float:
	return 4.0 if hero and hero.perks.has("marrow") else 3.0


## Version 220 (v219 review): a "full chain" for the special's refund and Blood Rush is x3 for
## every build (Marrow's x4 cap made them harder to reach with an epic card).
const CHAIN_FULL := 3.0


func chain_time() -> float:
	var t := 3.5 if hero and hero.perks.has("links") else 2.5
	if curses.has("longlinks"):
		t += 1.5
	if curses.has("fragile"):
		t *= 0.5
	if _hourglass_out:
		t *= 0.4
	if hero:
		t *= pow(1.1, int(hero.perks.get("deep_steady", 0)))   # v219: Steady Chain
	return t


## Damage gets a share of the chain's bonus: x1.7 at the cap (version 219, review 4 fix 30:
## was a quarter, x1.5, and the chain felt like a score meter more than a weapon).
func chain_damage() -> float:
	var d := 1.0 + (chain - 1.0) * 0.35
	if hero and hero.perks.has("last_stand") and hero.health < hero.max_health * 0.3:
		d *= 1.4   # Last Stand (a Vault card, v219)
	if chain >= 2.0 and hero and hero.perks.has("overcharge"):
		d *= 1.25   # Overcharge
	if surge > 0.5 and hero and hero.perks.has("eclipse_heart"):
		d *= 1.25   # Eclipse Heart (a Blood Moon blessing)
	return d


## Coins get the same quarter share of the chain: up to x1.5 (x1.75 with Marrow).
func chain_coins() -> float:
	return 1.0 + (chain - 1.0) * 0.25
var _combo_left := 0.0

## Run score: every kill is worth points times the full Bone Chain.
var score := 0
const KILL_POINTS := 10
const ELITE_POINTS := 30
const BOSS_POINTS := 500


## First run: each room adds one system (FTUE = first-time user experience).
## Room 1 just move and shoot, 2 dash, 3 the Bone Chain, 4 the special, 5 synergies, 6 boss.
var first_run := false
var _tutorial_requested := false

## Crypt Pass modes. `daily`: today's Daily Crypt. `curses`: curse ids active this run.
var daily := false
var curses: Array = []
var _score_mult := 1.0
var _daily_requested := false
## The free game ends after the boss of floor Store.FREE_FLOORS; this is that screen.
var _free_end := false
var _deal_checked := ""   # version 279: the deal pop-up already handled this session
## Version 280: the Free Dive. A player without the Crypt Pass can play floor 6 (the Drowned
## Vault, its own skeletons and the Tidecaller) once, at floor 3's strength and with
## DIVE_GIFTS blessings to start. It is used up once the Tidecaller's room is reached (a fall
## before that keeps it), and it never touches a saved run, records or the leaderboard.
var dive := false
var _dive_requested := false
var _dive_done := false   # the Tidecaller fell: the end screen offers the Pass, then the title
const DIVE_FLOOR := 6
const DIVE_STRENGTH := 3
const DIVE_GIFTS := 5
const DIVE_BOSS_HP := 0.85
## Version 309 (player panel fix 3, short sessions): a new run can start on a floor the player
## has already reached, every second floor (the Crypt Pass's floors with the Pass). The casual
## player quit when a fall on floor 3 sent them back to floor 1 room 1, ten minutes again.
## Starting deeper brings CATCHUP_GIFTS random blessings and one reroll for each floor skipped.
const CHECKPOINTS := [1, 3, 5, 7, 9]
const CATCHUP_GIFTS := 3
var start_floor := 1   # the floor this run began on
## Version 310 (short sessions, part 2): QUICK PLAY on the title. One short floor on a place
## already reached: QUICK_ROOMS rooms (an easy one, a medium one), then that place's boss, with
## QUICK_GIFTS blessings to start. About two minutes. Like the Free Dive it leaves a saved run,
## records and the leaderboard alone; coins, bones and Mastery count, and the day's first
## QUICK_DROPS wins pay a Bone Drop. A win's tap plays another one, on another place.
var quick := false
var _quick_requested := false
var _quick_done := false   # a Quick Play was won: the end screen offers another
const QUICK_GIFTS := 3
const QUICK_STRENGTH := 2   # skeletons and the boss as strong as floor 2's, on any place
const QUICK_BOSS_HP := 0.75
const QUICK_DROPS := 2
const QUICK_MAX_FLOOR := 10   # the ten places (the endless floors past it remix them)
const QUICK_SECTION := "quick"
## This run's hero when it isn't the chosen one: the Daily Crypt's hero, or a free trial.
var _run_hero_id := ""
## A locked hero picked on the Heroes screen for one free trial run, used by the next run.
var _trial_hero := ""
const TRIAL_SECTION := "trials"
## Daily Crypt: the day being played, whether it's a Practice run (the Official one is
## used up), and whether its last floor has been beaten.
var _daily_date := ""
var _daily_practice := false
var _daily_done := false
## Events (events.gd, version 134). `event` is "run" in the Blood Moon run (three floors of
## the event crypt, the Blood Moon Queen at the end), "hunt" in the Queen Hunt (her throne
## room only, on tier `event_tier`, 1-5), "" otherwise. Moon Shards earned this run wait
## in _shards_unsaved until a room clear or an end screen banks them. A Blood Moon run is saved
## at each room like a normal one (version 140), and dropped if the event has ended by the time
## it's continued. The Queen Hunt is one room, so it isn't.
var event := ""
var event_tier := 0
var _event_requested := ""
var _event_tier_requested := 0
var _event_done := false
## Version 221: the end of an event run was left by BACK TO EVENT: the title opens the event screen.
var _to_event := false
var _shards_unsaved := 0
var _shards_shown := 0
var _caskets_run := 0
## The Moon Surge (event crypt only): every SURGE_EVERY seconds of fighting the moon flares
## for SURGE_TIME seconds (after SURGE_WARN seconds of warning): skeletons run 40% faster,
## and each one killed in it is worth an extra Moon Shard. `surge` is 0..1, how strong it is.
var surge := 0.0
var _surge_t := 0.0
var _surge_on := false
var _flocking := false
var _moon_energy := 1.0
const SURGE_EVERY := 22.0
const SURGE_WARN := 1.8
const SURGE_TIME := 6.0
## Hourglass curse: seconds left in this room, and whether they've run out.
var _hourglass_left := 0.0
var _hourglass_out := false
## The bosses of this room still standing (two with Twin Wardens).
var _bosses: Array = []
## Twin Wardens: the health of bosses already beaten, so the shared bar keeps going down.
var _boss_lost := 0.0
## After a death on floor 3 or deeper, free players see one line about the Pass, once a session.
var _pass_note_shown := false
## Endless loops (Crypt Pass): the Omens taken so far ({id: stacks}), whether the end-of-loop
## choice (descend or bank) is showing, and the three Omens on offer.
var omens := {}
var _loop_choice := false
var _omen_choices: Array = []
## Blessings bought in the Armory's Vault, which can turn up in runs.
var vault: Array = []
## Doors (doors.gd): the two on offer after a blessing, and the one picked for the next room.
var _doors: Array = []
var _door := {}
## The blessing just picked, named on a banner once the door is chosen too.
var _picked := {}
## What the door before this room promised the blessing pick after it.
var _pick_family := ""
var _pick_better := false
## Version 242: a Dark Room was won, so one more blessing pick follows this one.
var _extra_pick := false
## In the Daily Crypt these are seeded, so everyone gets the same blessing cards (and
## rerolls), elites and waves; in other runs they're random (_pick_rng null).
var _pick_rng: RandomNumberGenerator
var _room_rng := RandomNumberGenerator.new()


## The Crypt Race (race.gd, version 153): `race` is on in a race; _race is the race itself
## (the rival, the clock, surges, the result). The clock (Race.Clock) runs on real time from
## GO (_race_live) to the finish, also over the blessing cards and the pause menu.
var race := false
var _race_requested := false
var _race: Race.Match
var _race_clock: Race.Clock
var _race_live := false
var _race_kills_room := 0
var _race_goal := 1
var _race_room_t := 0.0
var _race_note := ""
var _race_ghost: RivalGhost   # the rival, seen, while it's in your room (rival_ghost.gd)
var _race_lead := 0        # who leads on the track: 1 you, -1 the rival, 0 not yet said
var _race_lead_t := 0.0    # race time of the last lead callout
## Version 166 (Tweaks report #3): true while the phone has taken the screen (the notification
## shade, a call, the Play purchase sheet). The race clock stops; RESUME or focus back clears it.
var away := false
## Version 213: the clock node, asked again for Google's time each time the game comes back.
var _clock: TrustClock


## How many times Omen `id` has been taken this run.
func _omen(id: String) -> int:
	return int(omens.get(id, 0)) + (1 if _curse_omen == id else 0)


## Version 219 (review 4 fix 30): a Cursed Door's Omen, until the floor ends ("" for none).
var _curse_omen := ""


## True until the first run has ended. Older saves that already got somewhere count as done.
func first_run_pending() -> bool:
	var cfg := _load_save()
	if bool(cfg.get_value("stats", "first_run_done", false)):
		return false
	if int(cfg.get_value("stats", "tutorial_deaths", 0)) > 0:
		return true   # died in the tutorial once: it starts again
	return int(cfg.get_value("stats", "best_room", 0)) == 0 and int(cfg.get_value("stats", "wins", 0)) == 0


## Version 170 (teaching review, change 1): a one-line tip the first time something happens
## (the chain, the special move, a synergy card, each new skeleton). Each shows once ever,
## kept in the save's [taught] section. Waits (returns false) while another tip is up.
var _taught_cache: Dictionary = {}

func taught(key: String) -> bool:
	if _taught_cache.is_empty():
		var cfg := _load_save()
		_taught_cache["_"] = true
		if cfg.has_section("taught"):
			for k in cfg.get_section_keys("taught"):
				_taught_cache[k] = true
	return _taught_cache.has(key)


var _taught_unsaved: Array[String] = []


func mark_taught(key: String) -> void:
	if taught(key):
		return
	_taught_cache[key] = true
	if state == State.PLAYING:
		# Version 283 (Tweaks report #4): not a whole save in the middle of a fight; it goes
		# with the next one (_save_coins: the room's end, pause, death; or leaving the app).
		_taught_unsaved.append(key)
		return
	var cfg := _load_save()
	cfg.set_value("taught", key, true)
	write_save(cfg)


## Review fix 1 (build 295): a floor danger is explained once ever, in a long line at the
## bottom (saved, like the skeleton lines); after that only a one-word reminder at the hero,
## at most once a room for each danger (no more mid-screen sentences every room, or one for
## every plate of the Abyss).
var _danger_said := {}

## The floor's own danger (hard review fix 5, versions 284-293): quicksand, mine gas, rolling
## shelves, magnets, loose plates, black ice, fire seams, bounce caps or the tide.
func _lay_floor_danger(room: Room) -> void:
	_lay_danger_of(Floors.index(floor_num), room)
	# Version 299: from loop 3 a second place's danger joins (not in the boss room, where the
	# boss calls in only its own floor's).
	var partner := Floors.remix_partner(floor_num)
	if partner >= 0 and not _in_boss_room():
		var before := room.get_child_count()
		_lay_danger_of(partner, room)
		print("[run] remix danger %s laid %d" % [Floors.DANGER_WORD[partner], room.get_child_count() - before])


func _lay_danger_of(idx: int, room: Room) -> void:
	if idx == Floors.SANDFALL:
		Quicksand.lay(room)  # v284: the Sandfall Tomb's quicksand pits
	elif idx == Floors.MINE:
		MineGas.lay(room)    # v285: the Amethyst Mine's firedamp
	elif idx == Floors.LIBRARY:
		RollingStacks.lay(room)   # v286: the Whispering Library's rolling bookcases
	elif idx == Floors.FOUNDRY:
		ElectroMagnet.lay(room)   # v287: the Clockwork Foundry's magnets
	elif idx == Floors.ABYSS:
		FallingPlates.lay(room)   # v288: the Starfall Abyss's loose plates
	elif idx == 1 and not first_run:
		IcePatch.lay(room)   # v290: the Frozen Ossuary's black ice
	elif idx == 2 and event == "" and not first_run:
		FireSeam.lay(room)   # v291: the Ember Catacomb's fire seams
	elif idx == Floors.GROTTO and not first_run:
		BounceCap.lay(room)   # v292: the Glowcap Grotto's bounce caps
	elif idx == Floors.DROWNED:
		TideSurge.lay(room)   # v293: the Drowned Vault's tide


## Version 297 (deep review fix 5): each floor builds up. Its danger is gentle in the first
## room (step 0: fewer pieces, a slower beat), as before in the middle rooms (1), stronger
## in the last two (2), and the boss calls it in when it turns at half health (3).
var _boss_turned := false
var _boss_danger := false

func danger_step() -> int:
	if _in_boss_room():
		return 3 if _boss_turned else 2
	if _room_index == 0:
		return 0
	return 2 if _room_index >= _run.size() - 3 else 1


## How fast the danger's beat runs at this step (its waits between eruptions, waves, rolls).
func danger_pace() -> float:
	return float([0.75, 1.0, 1.15, 1.3][danger_step()])


## Whether `p` is within `r` metres of the hero (a danger laid mid-fight keeps clear of them).
func near_hero(p: Vector3, r: float) -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	var d := hero.global_position - p
	d.y = 0.0
	return d.length() < r


## A boss has reached half health (Enemy.phase_two): on floors with a danger of their own it
## calls it in, laid at full strength around the fight, so the last test of the floor uses
## what the floor has taught.
func boss_turned() -> void:
	if not _in_boss_room() or _boss_danger or race or Room.current == null:
		return
	_boss_turned = true
	_boss_danger = true
	_danger_said.clear()
	var before := Room.current.get_child_count()
	_lay_floor_danger(Room.current)
	if Room.current.get_child_count() > before:
		print("[run] the floor's danger joins the boss fight")
		# After the PHASE 2 banner has had its moment.
		get_tree().create_timer(1.6, false).timeout.connect(func():
			if state == State.PLAYING:
				hud.callout("THE FLOOR FIGHTS BACK!", Color(1.0, 0.75, 0.35)))


func danger_warn(key: String, word: String, lesson: String, col: Color) -> void:
	if state != State.PLAYING or _danger_said.has(key):
		return
	_danger_said[key] = true
	if not taught("danger_" + key) and not race:
		if hud.tip_busy():
			hud.tip("", 0.0)   # this matters more than a tip already showing
		mark_taught("danger_" + key)
		_tip_shown()   # (a danger is never held back, but the next tip waits after it)
		hud.tip(lesson, 5.0)
		print("[teach] " + lesson)
	hud.callout_at_hero(word, col)


## Version 298 (deep review fix 6, calmer second run): a new player's second run taught
## fifteen things in 99 seconds, five of them in one room. Now a tip waits TIP_GAP seconds of
## play after the last one, and a room gives at most ROOM_TIPS; the rest wait for later rooms
## (an elite keeps its name tag, a new skeleton stays in the queue, until its line is shown).
const TIP_GAP := 8.0
const ROOM_TIPS := 2
var _tip_clock := 0.0      # seconds of play, for the gap between tips
var _last_tip_at := -100.0
var _room_tips := 0


func _tip_room() -> bool:
	return _tip_clock - _last_tip_at >= TIP_GAP and _room_tips < ROOM_TIPS


func _tip_shown() -> void:
	_last_tip_at = _tip_clock
	_room_tips += 1


func _teach(key: String, text: String, seconds := 3.5) -> bool:
	if taught(key) or first_run or race or hud.tip_busy() or state != State.PLAYING or not _tip_room():
		return false
	mark_taught(key)
	_tip_shown()
	hud.tip(text, seconds)
	print("[teach] " + text)
	return true


## Version 170 (change 2): the first time each kind of skeleton shows up, one line on what it
## does and what to do about it (the tutorial's minions, warriors and archers are already
## taught there; bosses have their own title card).
const MEET_LINES := {
	"SkeletonArcher": "ARCHER: shoots arrows. Dash through them!",
	"BoneSpitter": "BONE SPITTER: spits shards. Hide behind pillars!",
	"SkeletonMage": "SKELETON MAGE: blows up circles. Keep moving!",
	"BoneSpider": "BONE SPIDER: pounces when its strip FILLS IN. Step aside!",
	"SkeletonBomber": "BOMBER: runs in and explodes. Kill it first!",
	"FrostWraith": "FROST WRAITH: fires an ice beam. Step off its line!",
	"CinderSkeleton": "CINDER SKELETON: leaves fire. Don't stand in it!",
	"DrownedSkeleton": "DROWNED SKELETON: bursts up in a circle. Step out!",
	"Sporeling": "SPORELING: bursts into spores. Step back after the kill!",
	"Rootbinder": "ROOTBINDER: roots crawl after you. Step aside!",
	"VoidWalker": "VOID WALKER: steps out of a rift by you. Get away from it!",
	"ClockworkSkeleton": "CLOCKWORK SKELETON: charges and bounces off a wall. Hit it when it runs down!",
	"HushKeeper": "HUSH KEEPER: its circle of letters silences your weapon. Step out to fight!",
	"GeodeGuard": "GEODE GUARD: its geode blocks shots from the front. Hit its side or back!",
	"TombMummy": "TOMB MUMMY: throws its bandage down the strip to reel you in. DASH to snap it!",
	"InkDouble": "INK DOUBLE: copies your steps like a mirror. Keep off the middle, and break it!",
	"Bloodbat": "BLOODBATS: swoop along a strip. Dash through!",
	"MoonHowler": "MOON HOWLER: pounces along a strip. Step aside!",
	# Version 278: Frostfall's own skeletons had no line (the Blood Moon's two did).
	"SnowRoller": "SNOW ROLLER: rolls a snowball down its strip. Step aside!",
	"BellRinger": "BELL RINGER: its bell sends out a ring of frost. Dash through it!",
	"GiftThief": "GIFT THIEF: runs off with gifts. Catch it before it vanishes!",
}
var _meet_queue: Array[String] = []

func _meet(e: Enemy) -> void:
	if first_run or race or e.is_boss:
		return
	var n := str(e.get_script().get_global_name())
	if MEET_LINES.has(n) and not taught("meet_" + n) and not _meet_queue.has(n):
		_meet_queue.append(n)


func _meet_tick() -> void:
	if _meet_queue.is_empty() or state != State.PLAYING or hud.tip_busy() or hud.banner_busy() or not _tip_room():
		return
	var n: String = _meet_queue.pop_front()
	if not taught("meet_" + n):
		mark_taught("meet_" + n)
		_tip_shown()
		hud.tip(MEET_LINES[n], 3.5)
		print("[teach] " + MEET_LINES[n])


## Version 170 (change 3): the death screen names what hurt most and gives one tip for it.
func death_tip() -> String:
	if _rep.is_empty() or (_rep.damage as Dictionary).is_empty():
		return ""
	var top := ""
	var most := 0.0
	for k in _rep.damage:
		if float(_rep.damage[k]) > most:
			most = float(_rep.damage[k])
			top = str(k)
	# Review fix 1 (build 295): the final blow names the lesson when there is one, so a
	# player the tide finished off on floor 6 learns about the tide, not floor 1's skeletons.
	var final_blow := str(_rep.get("killed_by", ""))
	var name := (final_blow if final_blow != "" and state == State.DEAD else top).replace("Elite ", "")
	var tip := "Keep moving. A mark on the floor hits when it FILLS IN: dash out."
	if name == "Other" or name == "":
		return tip
	if "Archer" in name or "Lich" in name or "Shade" in name:
		tip = "Dash through shots: you can't be hit mid-dash."
	elif "Spitter" in name:
		tip = "Hide behind pillars, or dash through the shards."
	elif "Mage" in name:
		tip = "Keep moving: its circles blow up where you stood."
	elif "Bomber" in name:
		tip = "Kill bombers first, or dash away when they stop."
	elif "Spider" in name or "Howler" in name or "bat" in name:
		tip = "Step off a strip before it FILLS IN."
	elif "Spike" in name or "fire" in name or "Spore" in name:
		tip = "Watch the floor: don't stand in traps or flames."
	elif "The tide" in name:
		tip = "When the tide rumbles, get right behind a pillar or crate, or dash through the wave."
	elif "Fire seam" in name:
		tip = "When a crack in the floor glows, a wall of fire is coming. Step off it, or dash through. The fire stops shots too."
	elif "Fall into the void" in name:
		tip = "Cracked plates with starlight in them fall away when stood on. Keep moving, or dash over the holes."
	elif "Magnet" in name:
		tip = "When a magnet hums, it is about to pull you in. Keep walking away from it, or dash."
	elif "Rolling shelves" in name:
		tip = "When a bookcase's books rattle, it rolls along its rails. Keep off the rails, or hide behind it."
	elif "Mine gas" in name:
		tip = "Mine gas blows up when a shot flies through it. Step out when it flares orange."
	elif "Quicksand" in name:
		tip = "Quicksand drags you in: walk or dash out, and lead skeletons across it."
	elif "Archivist" in name:
		tip = "Its words and footprints burn when they FILL IN. Keep moving, and don't turn back."
	elif "Ink Double" in name:
		tip = "Your double throws when you stand still. Break it, or keep moving."
	# Version 278: the places' own bosses and skeletons (versions 268 to 275) each get their
	# own lesson; they all fell to the general one, or to "a circle or strip".
	elif "Pharaoh" in name or "Mummy" in name:
		tip = "When a bandage catches you, DASH to snap it. Wade out of the sand fast."
	elif "Tyrant" in name:
		tip = "Crystals rise where their marks FILL IN. Step off the cart lanes."
	elif "Forgemaster" in name:
		tip = "Presses stamp one colour of tiles, then the other: step onto a stamped tile."
	elif "Star Eater" in name:
		tip = "Stand inside the constellation, not on its lines. Dash out of the star's pull."
	elif "Geode" in name:
		tip = "Its geode blocks shots from the front. Walk round it and hit its side or back."
	elif "Hush" in name:
		tip = "You can't attack inside its circle of letters. Step out first, then fight."
	elif "Clockwork" in name:
		tip = "It charges in a straight line. Step aside, then hit it while it winds down."
	elif "Void Walker" in name:
		tip = "It steps out of a rift beside you. When a rift opens, move away."
	elif "Wraith" in name:
		tip = "Its ice beam fills in along a line first. Step off the line."
	elif "Snow Roller" in name:
		tip = "Its snowball rolls down the strip it shows. Step off the strip."
	elif "Bell Ringer" in name:
		tip = "Its ring of frost can't be walked round. Dash through it, or get far away."
	elif "King" in name or "Warrior" in name or "Minion" in name or "Skeleton" in name:
		tip = "A circle or strip hits when it FILLS IN. Step or dash out."
	if final_blow != "" and state == State.DEAD:
		return "%s finished you.\n%s" % [name, tip]
	return "%s hurt you most.\n%s" % [name, tip]


## Version 170 (change 4): after the tutorial the title opens one thing at a time, by how
## many runs a player has started (the tutorial is run 1): Heroes and the Armory at once,
## the Bone Road from run 2, Modes, Records and events from run 3, the Crypt Pass from run 4.
## Saves from before the Records screen (records/since) and anyone with a floor boss beaten
## twice see everything.
func unlock_stage(cfg: ConfigFile = null) -> int:
	if first_run_pending():
		return 0
	if cfg == null:
		cfg = _load_save()
	if str(cfg.get_value(RECORDS, "since", "")) != "" or int(cfg.get_value("stats", "wins", 0)) >= 2:
		return 99
	return maxi(1, roundi(record(cfg, "runs")))


## Version 306 (player panel fix 1): the first two runs after install stay calm. No event
## splash or title banner, no reports question and no reminders question until the third run
## has begun (unlock_stage counts runs started, the tutorial included).
const CALM_RUNS := 3


## A gold title line the first time a new part opens (version 170).
func unlock_note(cfg: ConfigFile) -> String:
	var stage := unlock_stage(cfg)
	var seen := int(cfg.get_value("taught", "stage_seen", 1))
	if stage >= 99 or stage <= seen:
		return ""
	if stage >= 3 and seen < 3:
		return "NEW: MODES are open: try the Daily Crypt!"
	if stage >= 2 and seen < 2:
		return "NEW: the BONE ROAD: bones from every run earn rewards!"
	return ""


## Which room of the first run this is (1-6), or 99 outside the first run.
func ftue_room() -> int:
	return _room_index + 1 if first_run and floor_num == 1 else 99


func dash_unlocked() -> bool:
	return ftue_room() >= 2


func chain_unlocked() -> bool:
	return ftue_room() >= 3   # the tutorial's boss room (version 169)


func special_unlocked() -> bool:
	return ftue_room() >= 3


## A new player who dies in the tutorial gets it once more from room 1. A second death (or
## dying in a replay from Modes) ends it, and everything opens as after a win.
func _tutorial_retry() -> bool:
	var cfg := _load_save()
	if bool(cfg.get_value("stats", "first_run_done", false)):
		return false
	var deaths := int(cfg.get_value("stats", "tutorial_deaths", 0)) + 1
	cfg.set_value("stats", "tutorial_deaths", deaths)
	write_save(cfg)
	return deaths < 2


func _finish_first_run() -> void:
	if not first_run:
		return
	var cfg := _load_save()
	cfg.set_value("stats", "first_run_done", true)
	write_save(cfg)
	# Version 298: the tutorial already showed archers and the star button, so the next
	# run does not explain them again.
	for k in ["special", "meet_SkeletonArcher"]:
		mark_taught(k)


## Ends the chain. The spine shatters on screen if it had got anywhere.
func _break_chain() -> void:
	var was := chain
	_combo = 0
	chain = 1.0
	if hero and hero.perks.has("chain_echo") and was >= 1.5:
		# Chain Echo (a Vault card, v219): half of it stays, and starts its timer again.
		chain = 1.0 + (was - 1.0) * 0.5
		_combo_left = chain_time()
		hud.chain_broken(was)   # v220: it still breaks where you can see and hear it
		Sfx.play("crack", 0.4)
		hud.show_chain(chain)
		return
	if was > 1.01:
		hud.chain_broken(was)
		if was >= 2.0:
			Sfx.play("crack", 0.6)
## Camera close-ups: finishing blows and the boss entrance.
var _zoom := 0.0
var _zoom_hold := 0.0
var _zoom_point := Vector3.ZERO
var _intro_focus := false
## Waves: normal rooms send 2-3 waves; the next arrives when only a few are left.
var _waves_left := 0
var _wave_total := 1
var _wave_kinds: Array = []
var _wave_pending := false
var _moon: DirectionalLight3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	add_child(Sfx.new())
	add_child(Music.new())
	add_child(Ambience.new())
	add_child(Blizzard.new())   # version 243: Frostfall's rule
	var clock := TrustClock.new()   # version 212: Google's time for the event days
	_clock = clock
	add_child(clock)
	clock.synced.connect(func():
		if hud:
			hud.refresh_event_banner())
	add_child(Telemetry.new())
	add_child(Leaders.new())   # version 137: Google Play Games leaderboards
	add_child(UpdateGate.new())   # asks Google Play for a newer version straight away
	get_tree().node_added.connect(_count_added)
	add_child(Store.new())
	Store.instance.changed.connect(_on_store_changed)
	_setup_environment()
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.near = 0.3
	_camera.far = 120.0
	world.add_child(_camera)
	_camera.make_current()
	# A warm spotlight on the hero in the title screen's lobby.
	_lobby_light = SpotLight3D.new()
	_lobby_light.light_color = Color(1.0, 0.86, 0.62)
	_lobby_light.spot_range = 9.0
	_lobby_light.spot_angle = 26.0
	_lobby_light.spot_attenuation = 0.6
	_lobby_light.light_energy = 0.0
	_lobby_light.shadow_enabled = false
	_lobby_light.rotation = Vector3(-PI * 0.5, 0, 0)
	world.add_child(_lobby_light)

	hud = Hud.new()
	add_child(hud)
	hud.card_picked.connect(_on_card_picked)
	hud.reroll_pressed.connect(_on_reroll)
	hud.door_picked.connect(_on_door_picked)
	hud.special_pressed.connect(func(): if hero: hero.use_special())
	hud.dash_pressed.connect(_dash_from_button)
	hud.screen_tapped.connect(_on_screen_tapped)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.play_pressed.connect(_on_play_pressed)
	hud.tutorial_pressed.connect(func():
		if state == State.TITLE:
			_tutorial_requested = true
			_on_play_pressed())
	hud.armory_pressed.connect(_open_armory)
	hud.armory_buy.connect(_buy_upgrade)
	hud.bazaar_look.connect(_bazaar_preview)
	hud.bazaar_buy.connect(_bazaar_buy)
	hud.heroes_pressed.connect(_open_heroes)
	hud.records_pressed.connect(_open_records)
	hud.drops_pressed.connect(_open_drops)
	hud.drops_closed.connect(_drops_closed)
	hud.road_pressed.connect(_open_road)
	hud.road_claim.connect(_claim_road)
	hud.road_closed.connect(_drops_closed)
	hud.mastery_pressed.connect(_open_mastery)
	hud.mastery_train.connect(_train_hero)
	hud.style_pressed.connect(_open_style)
	hud.feats_pressed.connect(_open_feats)
	hud.feats_hero_pressed.connect(func(id: String): _open_feats(id))
	hud.see_looks.connect(func(id: String, lv: int):
		_open_style(id)
		hud.style_show_new(lv))
	hud.style_wear.connect(_wear_look)
	hud.style_closed.connect(func(id: String):
		var cfg := _load_save()
		HeroStyle.mark_seen(cfg, id)
		write_save(cfg)
		hud.refresh_looks_badge()
		if hud._heroes_box.visible:
			hud.show_heroes(true, _hero_rows(), coins))
	hud.found_wear.connect(_wear_found)
	hud.copy_report_pressed.connect(func():
		DisplayServer.clipboard_set(_last_report)
		Sfx.play("click"))
	hud.hero_pick.connect(_pick_hero)
	hud.resume_pressed.connect(func(): if state == State.PAUSED: _resume())
	hud.quit_run_pressed.connect(_quit_to_title)
	# Version 164: TRY AGAIN answers after 0.3 s (a tap anywhere else still waits 1 s), with a click.
	hud.retry_pressed.connect(func(): if state == State.DEAD and not race and _state_time > 0.3 and not hud.armory_visible() and not hud.heroes_visible():
		Sfx.play("click")
		_restart())
	hud.music_toggled.connect(_set_music)
	hud.sounds_toggled.connect(_set_sounds)
	hud.graphics_toggled.connect(_set_graphics)
	hud.speed_test_pressed.connect(start_speed_test)
	hud.shake_changed.connect(_set_shake)
	hud.flashes_changed.connect(_set_flashes)
	hud.left_hand_toggled.connect(_set_left_hand)
	hud.button_size_changed.connect(_set_button_size)
	hud.darkness_toggled.connect(_set_darkness)
	hud.pass_lost_restore.connect(func():
		Store.instance.restore()
		_open_pass())
	hud.vibration_toggled.connect(_set_vibration)
	hud.colorblind_toggled.connect(_set_colorblind)
	hud.reports_toggled.connect(_set_reports)
	hud.dash_flicked.connect(func(d: Vector2): if hero: hero.dash(Vector3(d.x, 0, d.y)))
	hud.pass_pressed.connect(_open_pass)
	hud.pass_buy.connect(func(): Sfx.play("click"); Store.instance.buy())
	hud.pass_restore.connect(func(): Sfx.play("click"); Store.instance.restore())
	hud.daily_pressed.connect(_open_daily)
	hud.daily_start.connect(func():
		if state == State.TITLE and Curses.can_play(Store.owned(), _load_save()):
			_daily_requested = true
			_on_play_pressed())
	hud.event_pressed.connect(_open_event)
	hud.race_pressed.connect(_open_race)
	hud.race_find.connect(_race_find)
	hud.race_go.connect(_race_go)
	hud.race_again.connect(_race_again)
	hud.race_claim.connect(_claim_race_road)
	hud.race_to_title.connect(_race_to_title)
	hud.race_surge_pressed.connect(race_fire_surge)
	_race_clock = Race.Clock.new()
	_race_clock.on_tick = _race_tick
	add_child(_race_clock)
	hud.event_run.connect(func(): start_event("run"))
	hud.event_hunt.connect(func(t: int): start_event("hunt", t))
	hud.event_claim.connect(_claim_event_road)
	hud.event_caskets.connect(_open_caskets)
	hud.event_closed.connect(func(): if state == State.TITLE and hud.title_visible(): hud.show_title(true, _best_text(), coins))
	hud.curses_pressed.connect(_open_curses)
	hud.curse_toggled.connect(_toggle_curse)
	hud.title_pressed.connect(_end_to_title)
	hud.pass_dive.connect(_start_dive)   # version 280: the Free Dive
	hud.continue_pressed.connect(_continue_run)
	hud.start_floor_pressed.connect(cycle_start_floor)   # version 309
	hud.quick_pressed.connect(start_quick)   # version 310
	hud.today_chest_pressed.connect(open_today_chest)   # version 311
	hud.hero_trial.connect(_try_hero)
	hud.share_pressed.connect(_share)
	hud.loop_deeper.connect(_open_omens)
	hud.loop_bank.connect(_bank_run)
	hud.omen_picked.connect(_pick_omen)
	hud.reminders_toggled.connect(_set_reminders)
	hud.reminders_answered.connect(func(on: bool):
		hud.show_reminders_ask(false)
		_set_reminders(on))
	hud.reports_answered.connect(func(on: bool):
		hud.show_reports_ask(false)
		_set_reports(on)
		if on:
			Telemetry.instance.daily_open()
		if on and state in [State.DEAD, State.VICTORY] and _last_report != "":
			# The run that brought the question up wasn't sent (reports were still off), and
			# many testers only ever play that one.
			Telemetry.instance.send("run", _last_report))

	var cfg := _load_save()
	coins = int(cfg.get_value("stats", "coins", 0))
	var spendable := RunSave.hold_replayed(coins)
	if spendable != coins:
		coins = spendable
		cfg.set_value("stats", "coins", coins)
	cfg.set_value("stats", "launches", int(cfg.get_value("stats", "launches", 0)) + 1)
	# Players from before Bone Drops find one waiting, so they see what the new button
	# does. (New players get their first for winning the tutorial.)
	if not cfg.has_section_key(Drops.SECTION, "gift"):
		cfg.set_value(Drops.SECTION, "gift", true)
		if bool(cfg.get_value("stats", "first_run_done", false)):
			Drops.add(cfg)
	# Hero Mastery levels reached in a run the app was closed during (points are saved after
	# every room, rewards at the end screen) are given now.
	for h: Dictionary in Heroes.LIST:
		var g := HeroMastery.grant(cfg, h.id)
		if int(g.coins) > 0:
			coins += int(g.coins)
			cfg.set_value("stats", "coins", coins)
		for l: Dictionary in g.levels:
			print("[mastery] %s level %d (on launch): %s" % [h.id, l.level, HeroMastery.level_text(l.level, h.id)])
	# A Crypt Race left by closing the game counts as a loss (so leaving can't dodge one).
	var left := Race.settle_left(cfg)
	if not left.is_empty():
		_race_note = "Your last Crypt Race was left before the end, so it counted as a loss%s." % \
			(" (%d trophies)" % int(left.delta) if int(left.delta) < 0 else "")
		print("[race] left race settled as a loss: %s" % left)
	write_save(cfg)
	_set_music(bool(cfg.get_value("settings", "music", true)), false)
	_set_sounds(bool(cfg.get_value("settings", "sounds", true)), false)
	_set_graphics(_saved_graphics(cfg), false)
	_set_shake(int(cfg.get_value("settings", "shake", 2)), false)
	# Flashes followed shake before v219: a player who turned shake down keeps fewer flashes,
	# and shake Off means Flashes Off (v219 review: it was Reduced, brighter than before).
	_set_flashes(clampi(int(cfg.get_value("settings", "flashes", int(cfg.get_value("settings", "shake", 2)))), 0, 2), false)
	_set_left_hand(bool(cfg.get_value("settings", "left_hand", false)), false)
	_set_button_size(int(cfg.get_value("settings", "button_size", 0)), false)
	_set_darkness(bool(cfg.get_value("settings", "darkness_light", false)), false)
	_set_vibration(bool(cfg.get_value("settings", "vibration", true)), false)
	_set_colorblind(bool(cfg.get_value("settings", "colorblind", false)), false)
	_auto_graphics = (bool(cfg.get_value("settings", "graphics_auto", false)) or not (cfg.has_section_key("settings", "graphics")
			or cfg.has_section_key("settings", "high_graphics"))) and not "autoplay" in OS.get_cmdline_user_args()
	_auto_rewatch = _auto_graphics
	hud.set_reports_label(bool(cfg.get_value("settings", "reports", false)), Telemetry.configured())
	_rem_blocked_said = PhoneReminders.blocked(cfg)   # (said only when it changes in a session)
	hud.set_reminders_label(PhoneReminders.on(cfg), _rem_blocked_said)
	PhoneReminders.refresh(cfg)
	if "reminders" in OS.get_cmdline_user_args():
		print("[reminders]\n" + PhoneReminders.describe(PhoneReminders.build(cfg, int(Time.get_unix_time_from_system()))))
	Telemetry.instance.daily_open()
	hud.set_coins(coins)

	Floors.lobby = Events.active() and not first_run_pending() and unlock_stage() >= 3
	_build_run()
	_load_room(0, false)
	hero.place_at(Vector3(0, 0, 2))
	_snap_camera()
	_set_state(State.TITLE)
	hud.show_hud(false)
	# While the screen is still black, before the title can be tapped. Version 165: a short
	# one for a new player (and on launches after this build's full one), see warmup.gd.
	var wcfg := _load_save()
	var short_warm := Warmup.core_only(wcfg)
	var warmed: bool = await Warmup.run(short_warm, 0 if short_warm else Warmup.resume_step(wcfg))
	if not short_warm:
		wcfg = _load_save()
		Warmup.mark_full(wcfg, warmed)   # v221: only a finished one; else where it stopped
		write_save(wcfg)
	hud.show_title(true, _best_text(), coins)
	Telemetry.step("title")   # (version 157: loading finished on a new install)
	_settle_events()
	_check_pass_lost()
	note_spot()
	_title_hero_line(hero.hero_id)
	_fade(1.0, 0.0, 0.6)
	var args := OS.get_cmdline_user_args()
	if not "autoplay" in args or "intro" in args:
		_play_intro()
		# Version 164: the whole opening plays on the first launch only; after that it goes
		# straight to its short glide onto the title.
		var first_launch := int(_load_save().get_value("stats", "launches", 1)) <= 1
		if not first_launch:
			intro.skip()
		# Version 168 (first 5 minutes): a brand-new player goes from the opening straight
		# into the tutorial. 10 new installs reached the title but only 3 pressed PLAY, and
		# the ones who did sat on the title for 45-77 s first.
		elif first_run_pending() and not "autoplay" in args:
			intro.finished.connect(_straight_to_tutorial)
		intro.finished.connect(_ask_reports_on_title)
		intro.finished.connect(func(): Telemetry.step("intro_end"))
		intro.finished.connect(_ask_reminders_on_title)
		intro.finished.connect(_maybe_event_splash.bind(false))
	else:
		Music.play("dungeon")
	if "speedtest" in args:
		get_tree().create_timer(1.0).timeout.connect(start_speed_test)
	elif "autoplay" in args:
		add_child(Autoplay.new())


## Version 168: the first launch's opening hands over to the tutorial's first room, after a
## short look at the title (PLAY still works if they tap it first).
func _straight_to_tutorial() -> void:
	await get_tree().create_timer(0.9).timeout
	if state == State.TITLE and first_run_pending() and hud.title_visible() and not hud.covers_world():
		print("[run] straight into the tutorial")
		_start_run()


## The opening scene, which hands over to the title screen (the music starts on its big hit).
func _play_intro() -> void:
	intro = Intro.new()
	intro.logo = hud.title_logo()
	intro.logo.modulate.a = 0.0
	intro.music.connect(func(): Music.play(title_track()))
	add_child(intro)


func _setup_environment() -> void:
	var env := Environment.new()
	_env = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.19, 0.28)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	# A touch more colour and contrast, so the brighter rooms stay rich, not milky.
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.12
	env.glow_enabled = true
	env.glow_intensity = GLOW
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	# Tight glow (the small levels) around bright things, and only a touch of the wide
	# level that used to spread a white haze over big moments.
	for i in 7:
		env.set_glow_level(i, [0.0, 0.5, 1.0, 0.0, 0.3, 0.0, 0.0][i])
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.06)
	env.fog_density = 0.008
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var moon := DirectionalLight3D.new()
	_moon = moon
	moon.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-35), 0)
	moon.light_color = Color(0.55, 0.6, 0.9)
	moon.light_energy = 0.5
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	world.add_child(moon)


# ---------------------------------------------------------------- per frame

## Counts what's added to the game during play, so the run report can say what appeared
## in the longest frame (a hitch the first time something is drawn names its culprit).
func _count_added(n: Node) -> void:
	if state != State.PLAYING:
		return
	var key := n.get_class()
	var s: Script = n.get_script()
	if s and s.resource_path != "":
		key = s.resource_path.get_file().get_basename()
	_added_now[key] = int(_added_now.get(key, 0)) + 1


## "projectile 3, CPUParticles3D 2" from the last two frames' additions, most first.
static func _added_text(a: Dictionary, b: Dictionary) -> String:
	var all := a.duplicate()
	for k in b:
		all[k] = int(all.get(k, 0)) + int(b[k])
	var keys := all.keys()
	keys.sort_custom(func(x, y): return all[x] > all[y])
	var parts := []
	for k in keys.slice(0, 5):
		parts.append("%s %d" % [k, all[k]])
	return ", ".join(parts)


func _process(delta: float) -> void:
	_state_time += delta
	# Version 279: the deal's pop-up waits for the bare title (Play's answer often comes while
	# the splash still shows).
	if state == State.TITLE and fmod(_state_time, 1.0) < delta and _deal_checked != _deal_key():
		_deal_pop()
	if state == State.PLAYING:
		_tip_clock += delta
	if not _meet_queue.is_empty():
		_meet_tick()   # version 170: one new-skeleton line at a time
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _frame_us) / 1000.0 if _frame_us > 0 else 0.0
	_frame_us = now
	var added := _added_now
	var added_before := _added_before
	_added_before = added
	# Version 163 (Tweaks report #11): three Dictionaries take turns instead of a new one each
	# frame (added_before is still read below this frame, so it is emptied next frame).
	_spare_added.clear()
	_added_now = _spare_added
	_spare_added = added_before
	if _pause_wanted:
		if state == State.PLAYING:
			_pause_wanted = false
			_pause()
		elif state not in [State.TRANSITION, State.UPGRADE]:
			_pause_wanted = false
	var cover := state != State.PLAYING and hud.covers_world()
	if get_viewport().disable_3d != cover:
		get_viewport().disable_3d = cover
	_update_surge(delta)
	if state == State.PLAYING:
		_run_time += delta
		record_add("time", delta)
		if curses.has("hourglass") and not _hourglass_out and alive_enemies > 0:
			_hourglass_left -= delta
			if _hourglass_left <= 0.0:
				_hourglass_out = true
				hud.callout("TIME'S UP!", Color(1, 0.4, 0.35))
				Sfx.play("warn")
			hud.set_timer(_hourglass_left)
		if frame_ms > _longest_ms and _state_time > 0.5:   # not the room's own loading
			_longest_ms = frame_ms
			_longest_at = "F%d R%d" % [floor_num, _room_index + 1]
			_longest_new = _added_text(added_before, added)
		_fps_t += delta
		_auto_play_t += delta
		if _auto_rewatch and not _auto_graphics and graphics_level > 0 and _auto_play_t >= 600.0:
			_auto_play_t = 0.0
			_auto_graphics = true
			_auto_seen = 120   # watch for one more minute
			_auto_fps.clear()
		if frame_ms > 250.0:
			_hitch_second = true
		if _state_time > 0.5 and _frame_hist.size() == 251:
			_frame_hist[mini(int(frame_ms), 250)] += 1
		if _fps_t >= 1.0:
			_fps_t = 0.0
			var f := Engine.get_frames_per_second() if fps_override < 0.0 else fps_override
			_fps_sum += f
			_fps_n += 1
			_fps_low = minf(_fps_low, f)
			# Not a room's first-draw hitches, and not a second with one long freeze in it: on a
			# new install a fast phone still prepares a few looks the first time they're drawn,
			# and that once switched a Galaxy S23 Ultra to Low graphics. A slow phone is slow
			# every second, with no single freeze needed.
			if _auto_graphics and _state_time >= 3.0 and (not _hitch_second or fps_override >= 0.0):
				_watch_frame_rate(f)
			_hitch_second = false
		if _combo_left > 0.0:
			_combo_left -= delta
			if _combo_left <= 0.0:
				_break_chain()
		_room_watchdog(delta)
		if chain >= 2.999:
			_top_chain_t += delta
			_best_chain_hold = maxf(_best_chain_hold, _top_chain_t)
			if _top_chain_t >= 30.0:
				_feat("linked")
		else:
			_top_chain_t = 0.0
	if _hit_stop_left > 0.0:
		_hit_stop_left -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop_left <= 0.0:
			Engine.time_scale = 0.12 if _lesson_left > 0.0 else 1.0
	_update_dash_lesson(delta / maxf(Engine.time_scale, 0.01))
	if _nudge_left > 0.0:
		_nudge_left = 0.0 if hero == null or hero.is_dashing() else _nudge_left - delta
	_update_glow(delta / maxf(Engine.time_scale, 0.01))
	_update_camera(delta / maxf(Engine.time_scale, 0.01))
	_update_exit_arrow()
	if state == State.TITLE and Engine.get_process_frames() % 60 == 0:
		_check_new_day()


## The Daily day turns over at 07:00 UTC, often while the game waits on the title or in the
## background. The title's gold lines (streak, today's coin bonus), the Daily's PLAYED or
## READY tag and an open Daily Crypt screen are worked out again for the new day; before,
## they said "played" and offered no START until the screen was opened again.
var _shown_day := ""


func _check_new_day() -> void:
	var day := Curses.today()
	if day == _shown_day or hud == null:
		return
	var first := _shown_day == ""
	_shown_day = day
	if first or state != State.TITLE:
		return
	print("[run] a new Daily day: %s" % day)
	if hud.title_visible():
		hud.show_title(true, _best_text(), coins)
	if hud.modes_visible():
		hud.show_modes(true)
	if hud.daily_visible():
		_show_daily()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		away = true
		if what == NOTIFICATION_APPLICATION_PAUSED:
			_report_left()
			PhoneReminders.refresh(_load_save())
			if not _feats_unsaved.is_empty() or not _taught_unsaved.is_empty():
				var fcfg := _load_save()
				_flush_feats(fcfg)
				write_save(fcfg)
		if state == State.PLAYING:
			_pause()
		elif state == State.TRANSITION:
			_pause_wanted = true
		if Telemetry.instance:
			Telemetry.instance.set_away(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		away = false
		if Telemetry.instance:
			Telemetry.instance.set_away(false)
		if Store.instance:
			Store.instance.recheck()
		if what == NOTIFICATION_APPLICATION_RESUMED and _clock:
			_clock.ask()   # version 213: Google's time again after the phone slept
		_check_new_day()
		_check_reminders_allowed()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		PhoneReminders.refresh(_load_save())
		if Telemetry.instance:
			Telemetry.instance.session_open(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android's back button pauses the game and resumes it again; from the end screens it
		# goes to the title, and from the title it leaves.
		if UpdateGate.instance and UpdateGate.instance.showing():
			if not UpdateGate.instance.forced():
				UpdateGate.instance.later()   # the update can still wait: back is LATER
				return
			if Telemetry.instance:
				Telemetry.instance.session_open(false)
			get_tree().quit()   # a version days out of date can't be played, so back leaves
			return
		if hud.feedback_visible():
			hud.show_feedback(false)
			return
		if hud.race_screen.back_pressed():
			return
		if hud.leaders_visible():
			hud.close_leaders()
			return
		if is_instance_valid(speed_card):
			speed_card.queue_free()
			speed_card = null
			return
		if hud.reminders_ask_visible():
			hud.show_reminders_ask(false)
			_set_reminders(false)   # backing out is a no
			return
		if hud.reports_ask_visible():
			hud.show_reports_ask(false)
			_set_reports(false)   # backing out of the question is a no
			return
		if hud.armory_visible():
			hud.show_armory(false)
			return
		if hud.pass_visible():
			hud.show_pass(false)
			return
		if hud.daily_visible():
			hud.show_daily(false)
			return
		if hud.omens_visible():
			hud.show_omens(false)
			return
		if hud.feats_visible():
			hud.close_feats()
			return
		if hud.style_visible():
			hud.close_style()
			return
		if hud.mastery_visible():
			hud.close_mastery()
			return
		if hud.heroes_visible():
			hud.show_heroes(false)
			return
		if hud.modes_visible():
			hud.show_modes(false)
			return
		if hud.drops_visible():
			hud.close_drops()
			return
		if hud.splash_visible():
			hud.hide_event_splash()
			return
		if hud.event_visible():
			hud.event_back()
			return
		if hud.road_visible():
			hud.close_road()
			return
		if hud.records_visible():
			hud.show_records(false)
			return
		if hud.today_visible():
			hud.show_today(false)   # version 311
			return
		if hud.rewards_visible():
			hud.show_rewards(false)
			return
		if hud.settings_visible():
			hud.show_settings(false)
			return
		match state:
			State.PLAYING:
				_pause()
			State.TRANSITION:
				_pause_wanted = true
			State.PAUSED:
				_resume()
			State.UPGRADE:
				# Version 211 (Tweaks report #4): Back on the blessing cards or the doors did nothing.
				hud.tip("Pick a card to go on", 1.5)
			State.DEAD, State.VICTORY:
				_end_to_title()
			State.TITLE:
				# Version 164: Back skips the intro, and the title needs Back twice to leave
				# (one stray Back used to close the game).
				if is_instance_valid(intro):
					intro.skip()
					return
				if Time.get_ticks_msec() - _back_ms > 2000:
					_back_ms = Time.get_ticks_msec()
					hud.tip("Press Back again to leave", 2.0)
					return
				if Telemetry.instance:
					Telemetry.instance.session_open(false)
				get_tree().quit()


## Testers often leave mid-run (Home, or another app), and a run report only went out
## when a run ended, so those runs never showed. Once a run, leaving the game during it
## sends the run so far (if they come back and finish, the end report follows as usual).
func _report_left() -> void:
	if not (state in [State.PLAYING, State.PAUSED, State.UPGRADE, State.TRANSITION]) or hero == null or hero.dead \
			or _rep.get("left", false) or Telemetry.instance == null:
		return
	_rep["left"] = true
	if first_run:
		Telemetry.step("left_" + _step_room())
	Telemetry.instance.send("run", run_report("Left the game on floor %d, room %d" % [floor_num, _room_index + 1]))


## The room for a first-week step (version 157): "room1" to "room5", or "boss".
func _step_room() -> String:
	return "boss" if _in_boss_room() else "room%d" % (_room_index + 1)


## The privacy policy (the same pinned page as the Play listing), opened from the pause
## menu, the reports question and the Crypt Pass screen.
const PRIVACY_URL := "https://github.com/incorruptibleyt/AAA-GAME-DESIGN/blob/7cdb36b0a00628e55a4e0840fb0c3ec21900221b/PRIVACY.md"


## The game's Google Play page, for the share text.
const PLAY_URL := "https://play.google.com/store/apps/details?id=com.Bone_Chain_Dungeon_Roguelite.myapp"

## The first run each Daily day (from 07:00 UTC) to end pays this much more of its coins:
## a death, a cleared Daily Crypt, the end of the free floors, or BANK AND LEAVE.
const DAY_BONUS := 0.5
## Normal runs show SHARE RESULT too when a floor's boss falls for the first time ("boss")
## or a death sets a new best score ("best"). Set on each end screen; empty for none.
var _share_reason := ""
## Floors shown on the share card of a normal run (the last ones reached).
const SHARE_FLOORS := 3


## How much tougher skeletons are on the current floor.
## Skeleton health grows 55% per floor (compounding), so it keeps pace with a hero whose
## blessings stack up. Floor 4 skeletons have about 3.7x their floor 1 health.
## Floor 5 adds 60%, because a hero that deep is very strong. The endless loops below it
## add 45% a floor to floor 10, then 25% a floor, and each Omen of Bones 25%.
## (Version 124, audit fix 1: the damage blessings stop at 10 picks each, so a hero's damage
## stops growing around floor 13; at 45% a floor forever, floor 20 skeletons took 13 s each.)
func health_scale() -> float:
	var f := strength_floor()
	return heroic_mult() * pow(1.55, mini(f, 4) - 1) * pow(1.6, clampi(f - 4, 0, 1)) \
		* pow(1.45, clampi(f - 5, 0, 5)) * pow(1.25, clampi(f - 10, 0, 5)) \
		* pow(1.12, maxi(f - 15, 0)) * pow(1.25, _omen("bones"))
	# (v219 fix 30 made it 35% a floor past 15. Version 283, Tweaks report #2: with the damage
	# cards maxed by then, that made floor 20 skeletons take 21 s each, a slog, not a danger.
	# Now 12% a floor, and damage_scale makes them hit harder instead.)


## The floor whose strength skeletons, bosses and coins have: the floor itself, or floor 3
## in the Free Dive (version 280), whose floor 6 is a taste, not a wall. Quick Play (version
## 310) is floor 2's strength on every place: three blessings and two picks don't make a
## floor-5 hero, and the robot's mage took over a minute on the Sand Pharaoh alone.
func strength_floor() -> int:
	return DIVE_STRENGTH if dive else (mini(floor_num, QUICK_STRENGTH) if quick else floor_num)


## Skeletons hit 35% harder per floor, and 50% per floor below floor 5 (the endless loops).
## When the Hourglass runs out they hit 25% harder still, and each Omen of Blades adds 25%.
## (Floor 5 used to jump by 50% too, and the free game ended on a wall of King hits.)
## The very first run's floor hits a quarter softer: a brand-new player who hadn't found
## the dash yet could fall in the first room in 17 seconds.
func damage_scale() -> float:
	var f := strength_floor()
	# (Version 283, Tweaks report #2: +30% a floor more past floor 15, so the deep end stays
	# deadly through danger instead of long fights.)
	return (1.0 + 0.35 * (f - 1) + 0.15 * maxi(f - 5, 0) + 0.3 * maxi(f - 15, 0)) * (1.25 if _hourglass_out else 1.0) \
		* pow(1.25, _omen("blades")) * newcomer_mult() * heroic_mult()


## Heroic (a free curse after the floor 5 boss, version 151): skeletons and bosses have 35%
## more health and hit 35% harder, and coins come 50% faster.
const HEROIC_MULT := 1.35
const HEROIC_COINS := 1.5


func heroic_mult() -> float:
	return HEROIC_MULT if curses.has("heroic") else 1.0


## "  (Heroic +50%)" after the run's coins on the end screens.
func _heroic_tag() -> String:
	return "  (Heroic +50%%)" if curses.has("heroic") else ""


## Version 152 (Heroic polish): is Heroic switched on for the next run? (The title's PLAY
## pill.) And has it opened but not been looked at yet? (The MODES pill and the Curses card.)
func heroic_on() -> bool:
	var cfg := _load_save()
	return Curses.chosen(cfg, Store.owned()).has("heroic")


func heroic_new() -> bool:
	var cfg := _load_save()
	return Curses.unlocked("heroic", cfg) and not bool(cfg.get_value(Curses.SAVE_SECTION, "heroic_seen", false))


## Version 147 (hard review of v143, item 2): a new tester fell in the tutorial's first room
## in 49 s. The tutorial's first room now hits at half strength (the rest of the tutorial
## floor 0.75, as before).
## Version 149 (difficulty review, fix 1): the help after the tutorial lasts until a player
## has beaten floor 1 twice (the tutorial counts), not just their first runs: 23 of 30 deaths
## of players with a small Armory were on floor 1, some long after their 4th run. Two floor-1
## falls in a row make floor 1 softer still, with more hearts, until it's beaten.
## Never in the Daily Crypt or the event, so those stay the same for everyone.
const NEWCOMER_CLEARS := 2   # floor-1 wins before the help ends
const NEWCOMER_MULT := 0.85
const STRUGGLE_FALLS := 2    # floor-1 falls in a row before the extra help
const STRUGGLE_MULT := 0.75
const STRUGGLE_HEARTS := 1.5
const ASSIST := "assist"
var _newcomer := false
var _struggling := false


## Version 169: the tutorial is now 3 rooms, so a player who goes straight on to floor 2
## has 2 blessings instead of 5. They get the 3 missing ones as they go down (_tutorial_gifts),
## and that floor hits a little softer, like a newcomer's floor 1.
var _after_tutorial := false

func newcomer_mult() -> float:
	if floor_num == 2 and _after_tutorial and not daily and event == "":
		return NEWCOMER_MULT
	if floor_num != 1:
		return 1.0
	if first_run:
		return 0.5 if _room_index == 0 else 0.75
	if daily or event != "":
		return 1.0
	return STRUGGLE_MULT if _struggling else (NEWCOMER_MULT if _newcomer else 1.0)


## Hearts drop this much more often while the extra floor-1 help is on.
func assist_hearts() -> float:
	return STRUGGLE_HEARTS if _struggling and floor_num == 1 and not first_run and not daily and event == "" else 1.0


## Floor-1 wins so far. Saves from before version 149 didn't count them: a player whose
## best boss is floor 2 or deeper has plainly beaten floor 1 enough, and one whose best is
## floor 1 has won there as often as they've won at all.
func f1_clears(cfg: ConfigFile) -> int:
	if cfg.has_section_key(ASSIST, "f1_clears"):
		return int(cfg.get_value(ASSIST, "f1_clears"))
	var best := _best_boss(cfg)
	if best >= 2:
		return NEWCOMER_CLEARS
	return mini(int(cfg.get_value("stats", "wins", 0)), NEWCOMER_CLEARS) if best == 1 else 0


## Is the run starting now one that gets the floor-1 help?
func _check_newcomer() -> void:
	var cfg := _load_save()
	_newcomer = f1_clears(cfg) < NEWCOMER_CLEARS
	_struggling = int(cfg.get_value(ASSIST, "f1_falls", 0)) >= STRUGGLE_FALLS


## Version 150 (coins review, fix 2): a floor-1 death in rooms 1-2 paid about 10 coins, so
## the players who most need the Armory could barely buy it. While the floor-1 help is on, a
## floor-1 death pays at least BRAVE_BASE coins plus BRAVE_ROOM for each room cleared (the
## run's own coins count toward it). It ends with the help, after two floor-1 wins.
const BRAVE_BASE := 30
const BRAVE_ROOM := 10


func _brave_coins() -> int:
	if floor_num != 1 or first_run or daily or event != "" or not (_newcomer or _struggling):
		return 0
	return maxi(0, BRAVE_BASE + BRAVE_ROOM * _room_index - run_coins)


## Counts a floor-1 win or fall (not the Daily Crypt or the event). `cfg` is written by the caller.
func _note_floor_one(cfg: ConfigFile, won: bool) -> void:
	if floor_num != 1 or daily or event != "":
		return
	if won:
		cfg.set_value(ASSIST, "f1_clears", mini(f1_clears(cfg) + 1, 99))
		cfg.set_value(ASSIST, "f1_falls", 0)
	elif not first_run:
		cfg.set_value(ASSIST, "f1_falls", int(cfg.get_value(ASSIST, "f1_falls", 0)) + 1)


func speed_scale() -> float:
	return minf(1.3, 1.0 + 0.05 * (strength_floor() - 1)) * (1.2 if curses.has("restless") else 1.0) * (1.25 if curses.has("frenzy") else 1.0)


## Daily Crypt rules and Omens that change coins and hearts.
func coin_mult() -> float:
	var treasure := 1.0 + Doors.TREASURE_COINS if _door.get("kind", "") == "treasure" else 1.0
	return (1.5 if curses.has("rich") else 1.0) * (HEROIC_COINS if curses.has("heroic") else 1.0) * pow(1.5, _omen("gold")) * treasure \
		* (1.0 + Doors.CURSED_COINS if _curse_omen != "" else 1.0)


## Hearts heal 20% more per floor, so they keep up with skeletons that hit harder deeper
## down (a flat 12 healed nearly every hit on floor 1 and barely dented floor 5).
## How much hearts and Vitality grow with the floor: +20% a floor up to floor 5 (the tuned
## early game, unchanged), then +35% a floor, like enemy hits, so deep floors stay fair.
func heal_scale() -> float:
	# Version 282 (Tweaks report #3): the strength floor, like health and damage, so the Free
	# Dive's floor 6 heals like the floor 3 its skeletons are (it healed like floor 6).
	var f := strength_floor()
	return 1.0 + 0.2 * (mini(f, 5) - 1) + 0.35 * maxi(f - 5, 0)


func heart_mult() -> float:
	return heal_scale() * (2.0 if curses.has("hearty") else 1.0)


## A golden arrow at the hero's feet pointing to the open door, so nobody gets lost.
func _update_exit_arrow() -> void:
	var show := state == State.PLAYING and hero != null and Room.current != null and Room.current.door_open
	if not show:
		if _exit_arrow:
			_exit_arrow.visible = false
		return
	if _exit_arrow == null:
		_exit_arrow = Node3D.new()
		world.add_child(_exit_arrow)
		var tri := CylinderMesh.new()
		tri.radial_segments = 3
		tri.rings = 1
		tri.top_radius = 0.38
		tri.bottom_radius = 0.38
		tri.height = 0.04
		var m := MeshInstance3D.new()
		m.mesh = tri
		m.material_override = U.unlit(Color(1.0, 0.8, 0.3, 0.85))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.scale = Vector3(0.7, 1, 1.2)
		m.rotation.y = PI   # put one corner of the triangle at -Z (forward)
		_exit_arrow.add_child(m)
	var door := Vector3(0, 0, -Room.HALF_L)
	var to := door - hero.global_position
	to.y = 0.0
	if to.length() < 2.0:
		_exit_arrow.visible = false
		return
	var d := to.normalized()
	var pulse := 1.3 + sin(Time.get_ticks_msec() * 0.008) * 0.2
	_exit_arrow.visible = true
	_exit_arrow.global_position = hero.global_position + d * pulse + Vector3.UP * 0.06
	_exit_arrow.rotation = Vector3(0, atan2(-d.x, -d.z), 0)


func _unhandled_input(event: InputEvent) -> void:
	# Space dashes on a keyboard (handy when testing on a computer).
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and hero:
		hero.use_special()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE and hero:
		var m := keyboard_move()
		var d := Vector3(m.x, 0, m.y) if m != Vector2.ZERO else -hero.global_transform.basis.z
		hero.dash(d)


func keyboard_move() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	return v.normalized()


# ---------------------------------------------------------------- camera and juice

## How much of the room's width the camera shows (the room is 12 wide). Showing about two
## thirds of it keeps the skeletons big on a phone; the camera follows the hero instead.
const VIEW_HALF_WIDTH := 4.4
## The hero sits this far above the middle of the screen, away from the thumb.
const HERO_ABOVE_CENTRE := 0.9
## Version 220: share of the screen at the top the hero is kept out of (the top HUD).
const TOP_SAFE := 0.22
const NEAR_EXTRA := 2.3   # v219 (review 4 fix 20): was 1.5; feet by the near wall stay clear
## The title screen's lobby camera looks down at this angle (the fight camera is steeper),
## so the hero is seen from the front, and makes the hero this tall (a share of the free space).
const LOBBY_PITCH := 24.0
const LOBBY_FILL := 0.8


## Where the lobby camera stands (looking down at `pitch` radians) so the hero, facing it,
## fills the free space between the title's words and its buttons (Hud.title_hero_space).
func _lobby_camera_position(pitch: float) -> Vector3:
	var vp := get_viewport().get_visible_rect().size
	var space: Rect2 = hud.title_hero_space()
	var tan_half := tan(deg_to_rad(CAMERA_FOV) * 0.5)
	var px := clampf(space.size.y * LOBBY_FILL, vp.y * 0.16, vp.y * 0.42)
	var d := 1.9 * cos(pitch) * vp.y / (2.0 * tan_half * px)
	var b := Basis.from_euler(Vector3(-pitch, 0, 0))
	var centre := hero.global_position + Vector3(0, 0.95, 0)
	var below := (space.get_center().y - vp.y * 0.5) / vp.y * 2.0 * d * tan_half
	return centre + b.z * d + b.y * below


func _cam_distance() -> float:
	# The same visible width on every phone shape, so characters are the same size.
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_h := atan(tan(deg_to_rad(CAMERA_FOV) * 0.5) * aspect)
	return VIEW_HALF_WIDTH / tan(half_h) * _boss_pull


func _focus_goal() -> Vector3:
	if hero == null:
		return Vector3.ZERO
	if _intro_focus and is_instance_valid(boss):
		return Vector3(boss.global_position.x * 0.5, 0, boss.global_position.z + 1.5)
	var goal := _room_focus()
	if _zoom_hold > 0.0:
		goal = goal.lerp(Vector3(_zoom_point.x * 0.6, 0, _zoom_point.z), 0.7)
		goal = _keep_hero(goal, 1.0 - 0.32 * maxf(_zoom, shake_scale))
	return goal


## Version 219 (review 4 fix 20): moves the camera's aim `goal` sideways just enough that the
## hero stays 12% of the screen inside each edge. The width seen at the hero's own screen row
## counts (rows nearer the camera see less), and `near` is the close-up's distance factor.
func _keep_hero(goal: Vector3, near := 1.0) -> Vector3:
	var p := deg_to_rad(CAMERA_PITCH)
	var d := _cam_distance() * near
	var depth := d + (goal.z - hero.global_position.z) * cos(p)
	var room := maxf(0.0, VIEW_HALF_WIDTH * near * depth / d * 0.76)
	goal.x = clampf(goal.x, hero.global_position.x - room, hero.global_position.x + room)
	return goal


func _room_focus() -> Vector3:
	# Follow the hero, but never show past the walls: no empty black space at the edges.
	var p := deg_to_rad(CAMERA_PITCH)
	var half_v := deg_to_rad(CAMERA_FOV) * 0.5
	var d := _cam_distance()
	var bottom := d * (cos(p) - sin(p) / tan(p + half_v))
	var top := d * (cos(p) - sin(p) / tan(p - half_v))
	# Version 142: the camera follows 1.5 m further toward the near wall, so a hero standing
	# against it sits above the DASH and special buttons instead of under them.
	var hi := Room.HALF_L + 0.6 + NEAR_EXTRA - bottom
	var lo := -Room.HALF_L - 2.5 - top
	var z := (lo + hi) * 0.5 if lo > hi else clampf(hero.global_position.z + HERO_ABOVE_CENTRE, lo, hi)
	# Version 220 (v219 review): the wall clamp let a hero by the far wall sit under the top
	# HUD (health, boss bar) in boss fights. The camera now follows far enough that the hero
	# stays below the top 22% of the screen, even if a strip past the far wall shows.
	var a_min := p - atan((0.5 - TOP_SAFE) * 2.0 * tan(half_v))
	z = minf(z, hero.global_position.z - (d * cos(p) - d * sin(p) / tan(a_min)))
	# Version 296 (deep review fix 4): in a boss fight the camera also leans towards the boss,
	# so its body stays below the top bar (it stood under the score and its own health bar),
	# as long as the hero stays above the bottom 26% of the screen (DASH and the special).
	var far_boss := INF
	for b in _bosses:
		if is_instance_valid(b) and not b.dead:
			far_boss = minf(far_boss, b.global_position.z - 2.0)   # its head and shoulders too
	if far_boss != INF and not _intro_focus:
		var a_bot := p + atan((0.74 - 0.5) * 2.0 * tan(half_v))
		var keep_hero := hero.global_position.z - (d * cos(p) - d * sin(p) / tan(a_bot))
		z = maxf(minf(z, far_boss - (d * cos(p) - d * sin(p) / tan(a_min))), minf(z, keep_hero))
	var x_room := maxf(0.0, Room.HALF_W + 0.6 - VIEW_HALF_WIDTH)
	# Version 219 (review 4 fix 20): the wall clamp used the width seen at the middle of the
	# screen, but rows nearer the camera see less, so a hero in a near corner sat half off the
	# edge. Keeping the hero in view now wins over hiding the wall.
	return _keep_hero(Vector3(clampf(hero.global_position.x, -x_room, x_room), 0, z))


func _place_camera() -> void:
	var p := deg_to_rad(CAMERA_PITCH)
	_camera.rotation = Vector3(-p, 0, 0)
	var pos := _cam_focus + Vector3(0, sin(p), cos(p)) * _cam_distance() * (1.0 - 0.32 * _zoom)
	if _lobby > 0.0:
		# The title screen's lobby: lower and in close, the hero filling the space between
		# the words at the top and the buttons at the bottom.
		var lp := deg_to_rad(LOBBY_PITCH)
		pos = pos.lerp(_lobby_camera_position(lp), _lobby)
		_camera.rotation = Vector3(-lerpf(p, lp, _lobby), 0, 0)
	if _shake > 0.001:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_camera.global_position = pos


func _snap_camera() -> void:
	_cam_focus = _focus_goal()
	_place_camera()


## Version 305 (Supercell review fix 2): in a boss fight the camera stands 12% further back,
## so the boss, the hero and the warnings fit together under the top bars (eased in and out).
const BOSS_PULL := 1.12
var _boss_pull := 1.0


func _update_camera(real_delta: float) -> void:
	var pull_goal := BOSS_PULL if state == State.PLAYING and boss_fight_on() else 1.0
	_boss_pull = lerpf(_boss_pull, pull_goal, 1.0 - exp(-2.5 * real_delta))
	var lobby := state == State.TITLE and hud.title_visible() and hero != null
	_lobby = lerpf(_lobby, 1.0 if lobby else 0.0, 1.0 - exp(-5.0 * real_delta))
	if _lobby < 0.002:
		_lobby = 0.0
	_lobby_light.visible = _lobby > 0.0
	if _lobby_light.visible:
		_lobby_light.light_energy = 5.0 * _lobby
		_lobby_light.global_position = hero.global_position + Vector3(0, 6.5, 0.4)
	if lobby:
		hero.rotation.y = lerp_angle(hero.rotation.y, PI, 1.0 - exp(-6.0 * real_delta))   # turned to face us
	_zoom_hold -= real_delta
	# The close-up punch follows the Screen shake setting (the boss intro's camera move doesn't).
	var zoom_goal := shake_scale if _zoom_hold > 0.0 else (0.5 if _intro_focus else 0.0)
	_zoom = lerpf(_zoom, zoom_goal, 1.0 - exp(-(10.0 if zoom_goal > _zoom else 4.0) * real_delta))
	_cam_focus = _cam_focus.lerp(_focus_goal(), 1.0 - exp(-8.0 * real_delta))
	_shake = move_toward(_shake, 0.0, real_delta * 2.5)
	_place_camera()


## Slow motion and a close-up on the last kill of a room. Time runs at `time_scale`
## for `seconds` of real time.
func finisher(pos: Vector3, time_scale: float, seconds: float, col := Color(1, 0.85, 0.5), flash := 0.35) -> void:
	Engine.time_scale = time_scale
	_hit_stop_left = maxf(_hit_stop_left, seconds)
	_zoom_point = pos
	_zoom_hold = seconds + 0.25
	Fx.shockwave(pos, col)
	hud.flash(Color(1, 0.85, 0.6), flash * 0.5)   # version 213: half as strong, warm (it hid the hero)
	Sfx.play("slam", 0.8)
	shake(0.35)


## Grave Dash landed: a short slow-motion beat, a callout and a bone crack.
## `big`: the full slow-motion (shots, lunges, blasts, bosses); a lighter one for an elite's swipe.
func perfect_dodge(pos: Vector3, big := true) -> void:
	Engine.time_scale = 0.3 if big else 0.55
	_hit_stop_left = maxf(_hit_stop_left, 0.4 if big else 0.18)
	Fx.shockwave(pos, Color(0.6, 0.95, 1.0), 2.5 if big else 1.6)
	hud.flash(Color(0.7, 0.95, 1.0), 0.25 if big else 0.12)
	hud.callout_at_hero("PERFECT!")
	Sfx.play("crack", 0.9)
	shake(0.2)
	report_event("perfect")
	# A perfect dodge feeds the chain and resets its timer.
	if chain_unlocked():
		var before := chain
		chain = minf(chain_max(), chain + (0.5 if big else 0.25))
		_combo_left = chain_time()
		hud.show_chain(chain)
		if before < chain_max() and chain >= chain_max():
			Sfx.play("vo_combo", 0.8)
		if not _rep.is_empty():
			_rep.best_chain = maxf(_rep.best_chain, chain)
			_rep.room_chain = maxf(_rep.room_chain, chain)
	if _perfect_total < 0:
		_perfect_total = int(_load_save().get_value("stats", "perfect_total", 0))
	_perfect_total += 1   # saved with the coins (_save_coins), not on every dodge


## The DASH button dashes the way you're moving (or were moving a moment ago, before the
## thumb left the stick to tap it). Standing still, it dashes the way you last moved, or
## (after a while) straight back from the skeleton you're shooting. It used to go the way
## the hero faced, which while shooting is right into that skeleton.
func _dash_from_button() -> void:
	if hero == null:
		return
	var m := hud.joystick + keyboard_move()
	var since := Time.get_ticks_msec() - hud.last_move_ms
	if m.length() <= 0.2 and since < 2000 and hud.last_move.length() > 0.2:
		m = hud.last_move
	if m.length() > 0.2:
		hero.dash(Vector3(m.x, 0, m.y))
	else:
		# Shooting, the hero faces its target: dash away from it. Otherwise the way it faces.
		var back := is_instance_valid(hero._target) and alive_enemies > 0
		hero.dash(hero.global_transform.basis.z * (1.0 if back else -1.0))


## Dash lessons: until you've pulled off a few perfect dodges, a shot about to hit you
## freezes time for a moment and the game tells you to dash through it.
var _lesson_left := 0.0
var _lessons_this_run := 0
var _perfect_total := -1
var _save_fell_back := false


func dash_lesson_active() -> bool:
	return _lesson_left > 0.0


func _update_dash_lesson(real_delta: float) -> void:
	if _lesson_left > 0.0:
		_lesson_left -= real_delta
		if _lesson_left <= 0.0 or state != State.PLAYING or hero == null or hero.is_dashing():
			_end_dash_lesson()
		return
	if state != State.PLAYING or hero == null or not hero.dash_ready() or _lessons_this_run >= 1 or _hit_stop_left > 0.0 or not dash_unlocked():
		return
	if _perfect_total < 0:
		_perfect_total = int(_load_save().get_value("stats", "perfect_total", 0))
	if _perfect_total >= 3:
		return
	for p in Projectile.danger:
		if is_instance_valid(p) and p.time_to_hit(hero.global_position, hero.radius + 0.15) < 0.5:
			_lessons_this_run += 1
			_lesson_left = 1.8
			Engine.time_scale = 0.12
			# Version 219 (review 4 fix 15): no "DASH THROUGH IT!" callout any more. With the
			# NEW: DASH card and this tip it made three messages at once.
			# Version 217 (review 3 fix #9): the how-to line in the tip slot at the top. The
			# bottom hint box (moved up in v216) sat on the hero mid-room, over the very dodge
			# it teaches.
			hud.tip("Flick your thumb or tap DASH!", 2.5)
			return


## Version 149 (difficulty review, fix 2): 9 of 23 floor-1 deaths dashed once or never.
## Four hits in one room without a single dash makes the DASH button pulse with a short
## reminder. Once a run at most, and never again after DASH_NUDGES runs that showed it.
const DASH_NUDGE_HITS := 4
const DASH_NUDGES := 3
const DASH_NUDGE_TIME := 4.0
var _room_dashes := 0
var _nudged_run := false
var _nudge_left := 0.0
const TUTORIAL_DASH_PULSE := 8.0   # version 169: the DASH button pulses as the dash room starts


func dash_nudge_active() -> bool:
	return _nudge_left > 0.0


func _dash_nudge_check() -> void:
	if _nudged_run or first_run or hero == null or hero.dead or not dash_unlocked() or state != State.PLAYING:
		return
	if int(_rep.hits) - _room_hits < DASH_NUDGE_HITS or int(_rep.dash) > _room_dashes:
		return
	_nudged_run = true
	var cfg := _load_save()
	var shown := int(cfg.get_value("tips", "dash_nudges", 0))
	if shown >= DASH_NUDGES:
		return
	cfg.set_value("tips", "dash_nudges", shown + 1)
	write_save(cfg)
	_nudge_left = DASH_NUDGE_TIME
	hud.tip("Tap DASH to dodge!\nYou can't be hit mid-dash.", DASH_NUDGE_TIME)


func _end_dash_lesson() -> void:
	_lesson_left = 0.0
	hud.show_hint("")
	if _hit_stop_left <= 0.0:
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount * shake_scale)


## Each floor's light (floors.gd): its own colours, made brighter and a little warmer so
## the arena reads like a lit stage. The sun is the strong light, so characters keep their
## shadows and shape.
const SUN_WARM := Color(1.0, 0.86, 0.68)


func _light_room(look: Dictionary) -> void:
	var light: Array = look.get("light", [1.0, 0.5, 0.0, 0.0])
	var amb: Color = look.ambient
	var lum := amb.get_luminance()
	_env.ambient_light_color = amb.lerp(Color(lum * 1.15, lum, lum * 0.85), light[3])
	_env.ambient_light_energy = light[0]
	_env.fog_light_color = look.fog
	_env.background_color = look.background
	_moon.light_color = (look.moon as Color).lerp(SUN_WARM, light[2])
	_moon.light_energy = light[1]
	_moon_energy = light[1]
	if _eclipse_tw:
		_eclipse_tw.kill()   # v218: a half-done Eclipse never re-dims the new room
	_eclipse_k = 0.0
	_eclipse_eff = 0.0


## Specials fill the screen with bright bolts and shockwaves; for a moment the bloom is
## turned down so the hero doesn't vanish in a white blur.
const GLOW := 0.6
const GLOW_CALM := 0.25
var _glow_calm_left := 0.0


func calm_glow(seconds: float) -> void:
	_glow_calm_left = maxf(_glow_calm_left, seconds)


func _update_glow(delta: float) -> void:
	if _env == null or not _env.glow_enabled:
		return
	_glow_calm_left -= delta
	var target := GLOW_CALM if _glow_calm_left > 0.0 else GLOW
	_env.glow_intensity = move_toward(_env.glow_intensity, target, delta * (3.0 if target < _env.glow_intensity else 0.6))


## A tiny freeze when something is hit hard. Small touches like this make combat feel good.
func hit_stop(seconds: float) -> void:
	if state != State.PLAYING:
		return
	# A longer slow motion is already running (a PERFECT: 30% speed for 0.4 s). Keep it: a kill
	# inside it used to drop the rest of it to 5%, a near freeze (audit fix 1).
	if _hit_stop_left > seconds and Engine.time_scale > 0.05:
		return
	Engine.time_scale = 0.05
	_hit_stop_left = maxf(_hit_stop_left, seconds)


# ---------------------------------------------------------------- run flow

## Rooms are dealt like cards: one played this run doesn't come back until its pile
## runs out (after floor 5), so the first five floors never repeat a room.
## Each entry is "<pile>:<index>", for example "1:4" for the fifth medium room.
var _seen_rooms: Array = []


func _build_run() -> void:
	_run.clear()
	_run_ids.clear()
	if event == "hunt":
		floor_num = int(Events.tiers()[event_tier - 1].floor)
		_run.append(Layouts.BOSS)
		_run_ids.append("Boss")
		return
	if floor_num <= 1:
		_seen_rooms.clear()
	# The Daily Crypt picks the same rooms for everyone that day.
	var rng := Curses.daily_rng(100 + floor_num, _daily_date) if daily or race else null
	var piles := [[Layouts.EASY, EASY_ROOMS], [Layouts.MEDIUM, MEDIUM_ROOMS], [Layouts.HARD, HARD_ROOMS]]
	if race:
		piles = [[Layouts.EASY, Race.ROOMS[0]], [Layouts.MEDIUM, Race.ROOMS[1]], [Layouts.HARD, Race.ROOMS[2]]]
	if first_run:
		# Version 169 (teaching review, change 1): the tutorial is two easy rooms and the boss
		# (move, dash, boss). Real new players needed 5 to 9 minutes for 5 rooms and a boss.
		piles = [[Layouts.EASY, TUTORIAL_ROOMS], [Layouts.MEDIUM, 0], [Layouts.HARD, 0]]
	elif quick:
		piles = [[Layouts.EASY, 1], [Layouts.MEDIUM, 1], [Layouts.HARD, 0]]   # version 310: Quick Play
	for p in piles.size():
		var all: Array = piles[p][0]
		var count: int = piles[p][1]
		var left: Array = []
		for i in all.size():
			if not _seen_rooms.has("%d:%d" % [p, i]):
				left.append(i)
		if left.size() < count:
			# This pile is used up: shuffle it back in.
			_seen_rooms = _seen_rooms.filter(func(k): return not (k as String).begins_with("%d:" % p))
			left = range(all.size())
		if rng:
			for i in range(left.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp = left[i]
				left[i] = left[j]
				left[j] = tmp
		else:
			left.shuffle()
		for i in mini(count, left.size()):
			_seen_rooms.append("%d:%d" % [p, left[i]])
			_twist_id = "EMH"[p] + str(left[i])
			_run.append(_twist_room(all[left[i]], all, rng))
			_run_ids.append(_twist_id)
	_run.append(Layouts.BOSS)
	_run_ids.append("Boss")


## Who rules this floor: the Ember Catacomb (floor 3, then every Ember floor) has the
## Cinder Colossus, the Drowned Vault (floor 6, 11, 16...) the Tidecaller, the Glowcap
## Grotto (floor 4) the Sporemother, the Starfall Abyss (floor 10, 15...; its "boss" key) the
## Star Eater (version 268; it had the Sporemother before), the Sandfall Tomb (floor 5) the
## Sand Pharaoh (version 274; the King and the Lich together before), the Amethyst Mine
## (floor 7) the Crystal Tyrant (version 275; the King before), the Whispering Library
## (floor 8) the Archivist (version 276; the Lich before), the Clockwork Foundry (floor 9)
## the Forgemaster (version 281; the Cinder Colossus before);
## elsewhere the Skeleton King and the Lich take turns (the King on odd floors).
func boss_kind() -> String:
	# An event: its own boss on floor 3 and alone in its hunt (the Blood Moon Queen, Krampus);
	# two of the crypt's bosses guard floors 1 and 2 (events.gd "guards").
	if event == "hunt" or (event == "run" and floor_num >= Events.RUN_FLOORS):
		return str(Events.ev().get("boss", "Q"))
	if event == "run":
		return str(Events.ev().get("guards", "KL"))[clampi(floor_num - 1, 0, 1)]
	# Version 250: a place can name its own boss ("boss" in Floors.THEMES): the Clockwork
	# Foundry (floor 9) was the Cinder Colossus's, as the Ember Catacomb relit was before it;
	# from version 281 it has its own, the Forgemaster.
	var own := str(Floors.current().get("boss", ""))
	if own != "" and not first_run:
		return own
	if Floors.ember() and not first_run:
		return "C"
	if floor_num > Floors.REMIX_FROM and Floors.index(floor_num) == 1:
		return "L"   # v299: the Frozen Ossuary back in the remix brings its own Lich
	if floor_num > Floors.REMIX_FROM and Floors.index(floor_num) == 0:
		return "K"   # v304: the Bone Crypt back in the remix brings the Skeleton King (King's Leap)
	if Floors.drowned() and not first_run:
		return "T"
	if Floors.grotto() and not first_run:
		return "S"
	return "L" if floor_num % 2 == 0 else "K"


## The skeletons only this floor's theme has, one letter each: Frost Wraiths on the Frozen
## Ossuary ("f"), Cinder Skeletons in the Ember Catacomb ("e"), Drowned Skeletons in the
## Drowned Vault ("d"), Sporelings and Rootbinders in the Glowcap Grotto ("pr"), none in
## the Bone Crypt. The events' crypts: Bloodbats and Moon Howlers ("bh"); in Frostfall Hall
## Snow Rollers, Bell Ringers and a Gift Thief ("noi"). The places past floor 4 name theirs
## ("guests", floors.gd): the Sandfall Tomb (floor 5) its own Tomb Mummies (version 273) and
## floor 5's Frost Wraiths (its spirits; from version 247 they took turns with scorched Cinder
## Skeletons, both borrowed), the Amethyst Mine its own Geode
## Guards (version 272) and the Drowned Skeletons (from its flooded shafts; until then beside
## the Rootbinders its floor had before), the Whispering Library its own
## Hush Keepers (version 271) and the Frost Wraiths (the ghosts of its readers; until then
## beside Cinder Skeletons, book burners, both borrowed), and the
## Clockwork Foundry its own Clockwork Skeletons (version 270) and the Cinder Skeletons (its
## stokers; until then beside the Sporelings its floor had before),
## and the Starfall Abyss its own Void Walkers (version 269; from version 255 it borrowed the
## Sporelings and Rootbinders of the Grotto it replaced).
func theme_enemy() -> String:
	if first_run:
		return ""
	if Floors.remixed(floor_num):
		return str(Floors.PASS_REMIX[Floors.index(floor_num)].guests)   # v219: the Pass's own mix
	return str(Floors.current().get("guests", ["", "f", "e", "d", "pr", "bh", "noi", "fe"][mini(Floors.index(floor_num), 7)]))


## Deeper floors don't replay rooms exactly: from floor 2 a room may take its right-hand side
## from another room, and from floor 3 its far half may be joined to the near half of another
## room from the same pool.
var _twist_id := ""


func _twist_room(layout: Array, pool: Array, rng: RandomNumberGenerator) -> Array:
	var roll := func() -> float: return rng.randf() if rng else randf()
	var out := layout.duplicate()
	if floor_num >= 3 and pool.size() > 1 and roll.call() < 0.35:
		var other: Array = pool[(pool.find(layout) + 1 + int(roll.call() * (pool.size() - 1))) % pool.size()]
		if other != layout:
			_twist_id += " +rows " + _twist_id.left(1) + str(pool.find(other))
			for row in range(7, Layouts.ROWS):
				out[row] = other[row]
	# Every room is drawn the same on both sides, so a plain mirror would change nothing:
	# instead the right-hand side comes from another room, making a lopsided new one.
	if floor_num >= 2 and pool.size() > 1 and roll.call() < 0.5:
		var right: Array = pool[(pool.find(layout) + 1 + int(roll.call() * (pool.size() - 1))) % pool.size()]
		if right != layout:
			_twist_id += " +right " + _twist_id.left(1) + str(pool.find(right))
			for row in out.size():
				out[row] = (out[row] as String).substr(0, 5) + (right[row] as String).substr(5)
	return out


func _combat_rooms() -> int:
	return _run.size() - 1


func _in_boss_room() -> bool:
	return _room_index == _run.size() - 1


## A boss is up and fighting (version 305: the HUD drops the chain and score, the camera
## stands back).
func boss_fight_on() -> bool:
	for b in _bosses:
		if is_instance_valid(b) and not b.dead:
			return true
	return false


func _on_screen_tapped() -> void:
	if race and state != State.PAUSED:
		return   # a race's result has its own buttons
	match state:
		State.TITLE:
			_start_run()
		State.DEAD:
			if _state_time > 1.0:
				_restart()
		State.VICTORY:
			if _state_time > 1.5 and not _loop_choice and not _celebrating:   # the end of a loop has its own buttons
				Sfx.play("click")
				if _dive_done:
					# Version 280: the Free Dive's win has the offer's own buttons; once the Pass is
					# bought there, a tap goes back to the title.
					if Store.owned():
						_back_to_title(true)
				elif _quick_done:
					_restart()   # version 310: another Quick Play, on another place
				elif _daily_done or _event_done:
					_to_event = _event_done and Events.active()   # v221: BACK TO EVENT
					_back_to_title()
				else:
					_descend()
		State.PAUSED:
			_resume()


func _on_play_pressed() -> void:
	if state == State.TITLE:
		Sfx.play("click")
		_start_run()


## The title's music: the Blood Moon's while the event is on.
func title_track() -> String:
	if Floors.lobby:
		return "frost" if Events.frost() else "moon"
	return "title"


func _start_run() -> void:
	Floors.lobby = false
	race = _race_requested and _race != null and not first_run_pending()
	_race_requested = false
	dive = _dive_requested and not race and not first_run_pending()
	_dive_requested = false
	if dive:
		_count_dive_try()
	_dive_done = false
	quick = _quick_requested and not race and not dive and not first_run_pending()
	_quick_requested = false
	_quick_done = false
	if not race and not _side_run():   # (a Crypt Race, the Free Dive or Quick Play leaves a saved run alone: CONTINUE is still there after it)
		var held := RunSave.held()
		if held > 0:
			coins += held   # giving up the saved run gives its held-back coins back
			hud.set_coins(coins)
			_save_coins()
		RunSave.clear()   # starting something new gives up a saved run
	first_run = (first_run_pending() or _tutorial_requested) and not race
	_best_floor_seen = -1
	_tutorial_requested = false
	_after_tutorial = false
	_gift_names = []
	var stage_now := unlock_stage()
	if stage_now < 99 and stage_now > int(_load_save().get_value("taught", "stage_seen", 1)):
		var scfg := _load_save()
		scfg.set_value("taught", "stage_seen", mini(stage_now, 3))
		write_save(scfg)
	daily = _daily_requested and Curses.can_play(Store.owned(), _load_save()) and not first_run and not _side_run()
	_daily_requested = false
	_daily_done = false
	event = _event_requested if not first_run and not _side_run() and Events.active() else ""
	event_tier = clampi(_event_tier_requested, 1, Events.tiers().size())
	_event_requested = ""
	_event_done = false
	if event != "" or race:
		daily = false
	if race:
		event = ""
		_daily_date = _race.date   # the race's seed: the same rooms, cards and doors for both
	_run_hero_id = ""
	if daily:
		_begin_daily()
	elif _trial_hero != "" and not first_run and not race and not _side_run():
		_run_hero_id = _trial_hero
		var cfg := _load_save()
		cfg.set_value(TRIAL_SECTION, _trial_hero, true)
		write_save(cfg)
		_trial_hero = ""
	hud.show_title(false)
	hud.show_armory(false)
	hud.show_pass(false)
	hud.show_daily(false)
	hud.show_hud(true)
	_reset_run_stats()
	if dive:
		floor_num = DIVE_FLOOR
		Telemetry.step("dive_start")
	if quick:
		floor_num = quick_floor()
		Telemetry.step("quick_start")
	start_floor = chosen_start() if _normal_run() else 1
	if start_floor > 1:
		floor_num = start_floor
	record_add("runs", 1)
	if race:
		Telemetry.step("race1")
	elif not first_run:
		Telemetry.step("run2")   # the first run after the tutorial (version 157)
	_check_newcomer()
	if race:
		_newcomer = false   # the same crypt for both racers: no floor-1 help
		_struggling = false
	_pick_curses()
	# Version 169: the tutorial too. The run built for the title had 5 rooms (medium and hard
	# ones too), so a first launch played that instead of the tutorial's own easy rooms.
	if daily or event != "" or race or first_run or _side_run() or start_floor > 1:
		_build_run()   # the day's rooms; the event's crypt or the Queen's throne room; the race crypt; the tutorial; the Drowned Vault or Quick Play; a deeper start
	_use_run_hero()
	_apply_armory()
	_catch_up()
	_go_to_room(0)
	_mode_banner()


## Today's Daily Crypt: its date and hero, and whether this is the day's Official run
## (one a day counts for the day's best; after that it's Practice).
func _begin_daily() -> void:
	_daily_date = Curses.today()
	var cfg := _load_save()
	_daily_practice = Curses.official_used(cfg, _daily_date)
	if not _daily_practice:
		Curses.use_official(cfg, _daily_date)
		# Streak rewards: coins on day 3 and every 7th day, paid as the day's run starts.
		var day := Curses.streak(cfg)
		var gift := Curses.streak_reward(day)
		if gift > 0 and not bool(cfg.get_value("daily", _daily_date + "_streak_paid", false)):
			cfg.set_value("daily", _daily_date + "_streak_paid", true)
			coins += gift
			cfg.set_value("stats", "coins", coins)
			var line := "Daily streak day %d: +%d coins!" % [day, gift]
			get_tree().create_timer(2.6, false).timeout.connect(func():
				hud.banner(line, Color(1.0, 0.82, 0.3))
				Sfx.play("coin", 0.9))
		write_save(cfg)
	_run_hero_id = Curses.daily_hero(_daily_date)
	_daily_done = false


## Swaps the hero standing on the title screen for this run's hero, if that's a different one.
func _use_run_hero() -> void:
	_swap_hero(_run_hero_id if _run_hero_id != "" else Heroes.selected(_load_save()))


## Puts hero `id` where the current hero stands. Returns false if it's already that hero.
func _swap_hero(id: String, again := false) -> bool:
	if hero and hero.hero_id == id and not again:
		return false
	var at := hero.global_position if hero else Vector3.ZERO
	if hero:
		hero.queue_free()
	hero = Hero.spawn(world, at, id)
	return true


## Curses chosen on the Curses screen, or the day's rules in the Daily Crypt.
func _pick_curses() -> void:
	if first_run or event != "" or race or _side_run():
		curses = []
	elif daily:
		curses = Curses.daily_rules(_daily_date)
	else:
		curses = Curses.chosen(_load_save(), Store.owned())
	_update_score_mult()


## Curses (or the day's rules) and Omens both raise the score.
func _update_score_mult() -> void:
	_score_mult = Curses.score_mult(curses) + Loops.OMEN_SCORE * Loops.total(omens)


func _mode_banner() -> void:
	if race:
		hud.tip("CRYPT RACE  ·  vs %s\nRace Kit: %s" % [_race.rival.name, Race.kit_text(_race.kit)], 4.0, 0.3)
	elif event == "run":
		if Floors.frostfall():
			hud.tip("FROSTFALL  ·  %s\nKill skeletons in a Blizzard for bonus snowflakes.\nStand in a brazier's ring to stay warm!" % str(Events.chapter_info().name), 5.5, 1.8)
		else:
			hud.tip("BLOOD MOON  ·  %s\nKill skeletons during a Moon Surge for bonus shards!" % str(Events.chapter_info().name), 5.0, 1.8)
	elif event == "hunt":
		hud.tip("%s  ·  %s\n%d blessings to start. %s" % [Events.word("hunt").to_upper(), str(Events.tiers()[event_tier - 1].name), int(Events.tiers()[event_tier - 1].gifts), Events.word("down")], 4.5, 1.8)
	elif daily:
		hud.tip("DAILY CRYPT #%d%s  ·  Score x%s\n%s" % [Curses.day_number(_daily_date), "  ·  Practice" if _daily_practice else "",
			_mult_text(_score_mult), Curses.names(curses)], 5.0, 1.8)
	elif not curses.is_empty():
		var others := curses.filter(func(c): return c != "heroic")
		hud.tip("%sCURSE LEVEL %d  ·  Score x%s\n%s" % ["HEROIC  ·  " if curses.has("heroic") else "", Curses.level_of(curses), _mult_text(_score_mult),
			Curses.names(others) if others else "Tougher skeletons, +50% coins"], 4.0, 1.8)
	elif dive:
		hud.tip("FREE DIVE  ·  THE DROWNED VAULT\n%d blessings to start. Find the Tidecaller!" % DIVE_GIFTS, 4.5, 1.8)
	elif quick:
		hud.tip("QUICK PLAY  ·  %s\n%d blessings to start. %d rooms, then the boss!" % [str(Floors.current().get("name", "Floor %d" % floor_num)).to_upper(),
			QUICK_GIFTS, _combat_rooms()], 4.5, 1.8)
	elif _run_hero_id != "":
		hud.tip("FREE TRIAL RUN  ·  %s" % Heroes.full_name(Heroes.get_hero(_run_hero_id)), 4.0, 1.8)


## 1.3 -> "1.3", 1.45 -> "1.45"
static func _mult_text(m: float) -> String:
	return str(snappedf(m, 0.01))


func _reset_report() -> void:
	_rep = {"damage": {}, "hits": 0, "healed": 0.0, "dash": 0, "ward": 0, "second_wind": 0,
		"best_combo": 0, "best_chain": 1.0, "perfect": 0, "special": 0, "rooms": [], "room_start": 0.0, "killed_by": "",
		"chains": [], "room_chain": 1.0, "stuck": [], "stuck_n": 0}
	_fps_sum = 0.0
	_fps_n = 0
	_fps_low = 999.0
	_longest_ms = 0.0
	_longest_at = ""
	_longest_new = ""


func report_damage(amount: float) -> void:
	if _rep.is_empty() or amount <= 0.0:
		return
	var src := hit_source if hit_source != "" else "Other"
	hit_source = ""
	_rep.damage[src] = _rep.damage.get(src, 0.0) + amount
	_rep.hits += 1
	_rep.killed_by = src
	_dash_nudge_check()


## Version 171: the stuck watch (enemy.gd _stuck_watch, and the room watchdog) found a
## skeleton that couldn't reach the hero. The run report keeps the first STUCK_KEEP of them
## as "Stuck:" lines (floor, room, layout, who, where it stood, where the hero stood), so
## the report sheet shows which rooms trap skeletons.
const STUCK_KEEP := 6

func report_stuck(e: Enemy, h: Hero, moved: float, freed: bool, how := "") -> void:
	if _rep.is_empty() or not _rep.has("stuck"):
		return
	var room_id := str(_run_ids[_room_index]) if _room_index < _run_ids.size() else "?"
	var cell := Room.cell_of(e.global_position)
	var line := "F%d R%d %s | %s at (%.1f, %.1f) cell %d,%d | hero at (%.1f, %.1f) | %s" % [floor_num,
		_room_index + 1, room_id, e.kind_name() + (" (boss)" if e.is_boss else ""), e.global_position.x, e.global_position.z,
		cell.x, cell.y, h.global_position.x if h else 0.0, h.global_position.z if h else 0.0,
		how if how != "" else ("moved %.1f m in %d s%s" % [moved, int(Enemy.STUCK_WINDOW), ", freed" if freed else ""])]
	_rep.stuck_n += 1
	print("[stuck] " + line)
	if (_rep.stuck as Array).size() < STUCK_KEEP:
		_rep.stuck.append(line)


func report_event(what: String, amount := 1.0) -> void:
	if _rep.is_empty() or not _rep.has(what):
		return
	_rep[what] += amount
	if what == "special" and not bench:
		Today.add("specials")   # version 311
	if what == "perfect" or what == "special":
		_feat_check()


func _report_room_done(label: String) -> void:
	if _rep.is_empty():
		return
	_rep.rooms.append("%s %s" % [label, _format_time(_run_time - _rep.room_start)])
	if not bench:
		Today.add("rooms")   # version 311
	_rep.chains.append(_rep.room_chain)


## The text that the COPY REPORT button puts on the clipboard.
## `was_first`: the run that just won the tutorial floor (first_run is already cleared then).
func run_report(result: String, was_first := false) -> String:
	var cfg := _load_save()
	var lines := []
	lines.append("Bone Chain run report (build %s, install %s)" % [BUILD, Telemetry.install_id(cfg)])
	lines.append("Hero: %s | %s | Time %s" % [Heroes.get_hero(hero.hero_id).title if hero else "?", result, _format_time(_run_time)])
	lines.append("Score %d | First run %s | Floor-1 help %s" % [score, "yes" if first_run or was_first else "no",
		"tutorial" if first_run or was_first else ("extra" if _struggling else ("yes" if _newcomer else "no"))])
	lines.append("Bone Road %d bones (%d to claim) | Bone Drops waiting %d, opened %d, this run %d | Lucky Starts %d" % [BoneRoad.bones(cfg),
		BoneRoad.ready_count(cfg), Drops.waiting(cfg), int(cfg.get_value(Drops.SECTION, "opened", 0)), _drops_run, Drops.lucky(cfg)])
	var masteries := []
	for h: Dictionary in Heroes.LIST:
		var p := HeroMastery.points(cfg, h.id) + (_mastery_unsaved if h.id == _mastery_hero else 0)
		if p > 0:
			masteries.append("%s %d (%d)" % [h.title, HeroMastery.level_for(p), p])
	lines.append("Hero Mastery +%d this run | %s" % [_mastery_run, ", ".join(masteries) if masteries else "none yet"])
	if hero:
		var p := HeroStyle.picks(cfg, hero.hero_id)
		var worn := HeroStyle.SLOTS.map(func(slot: String) -> String: return str(p[slot]) if p[slot] != "" else "-")
		lines.append("Look %s (outfit/head/weapon/glow/aura)" % "/".join(worn))
	if race and _race:
		lines.append("Mode: Crypt Race vs %s (bot, %s) | trophies %d | kit %s | t %.1f s | rival at %.2f | surges sent %d got %d | falls %d (rival %d)" % [
			_race.rival.name, _race.rival.skill, _race.trophies, Race.kit_text(_race.kit), _race.t, _race.them(), _race.sent, _race.got, _race.falls, _race.rival.falls])
	if daily or not curses.is_empty():
		lines.append("Mode: %s | %s: %s (Curse Level %d, score x%s)" % ["Daily Crypt #%d %s%s" % [Curses.day_number(_daily_date), _daily_date, " practice" if _daily_practice else ""] if daily else "Normal",
			"Rules" if daily else "Curses", Curses.names(curses) if curses else "none", Curses.level_of(curses), _mult_text(_score_mult)])
	if floor_num > Loops.FLOORS or not omens.is_empty():
		lines.append("Loop %d | Omens: %s" % [Loops.loop_of(floor_num), Loops.names(omens) if omens else "none"])
	lines.append("Kills %d | Coins +%d | Best combo x%d | Health %d/%d" % [_kills, run_coins, _rep.get("best_combo", 0),
		ceili(hero.health) if hero else 0, roundi(hero.max_health) if hero else 0])
	var dmg: Dictionary = _rep.get("damage", {})
	var srcs := dmg.keys()
	srcs.sort_custom(func(a, b): return dmg[a] > dmg[b])
	var parts := []
	var total := 0.0
	for k in srcs:
		parts.append("%s %d" % [k, roundi(dmg[k])])
		total += dmg[k]
	lines.append("Damage taken %d in %d hits: %s" % [roundi(total), _rep.get("hits", 0), ", ".join(parts) if parts else "none"])
	if _rep.get("killed_by", "") != "" and state == State.DEAD:
		lines.append("Final blow: " + _rep.killed_by)
	lines.append("Healed %d | Dashes %d | Perfect dodges %d | Specials %d | Best chain x%.1f | Ward blocks %d | Second Wind used %d" % [roundi(_rep.get("healed", 0.0)), _rep.get("dash", 0), _rep.get("perfect", 0), _rep.get("special", 0), _rep.get("best_chain", 1.0), _rep.get("ward", 0), _rep.get("second_wind", 0)])
	var bl := []
	for id in _taken:
		var u := Upgrades.get_def(id)
		if not u.is_empty():
			bl.append(u.title + ("" if _taken[id] == 1 else " x%d" % _taken[id]))
	lines.append("Blessings: " + (", ".join(bl) if bl else "none"))
	var arm := []
	for u in Armory.LIST:
		var lv := Armory.level(cfg, u.id)
		if lv > 0:
			arm.append("%s %d" % [u.title, lv])
	lines.append("Armory: " + (", ".join(arm) if arm else "none"))
	lines.append("Rooms: " + ", ".join(_rep.get("rooms", [])))
	if int(_rep.get("stuck_n", 0)) > 0:
		var more := int(_rep.stuck_n) - (_rep.stuck as Array).size()
		lines.append("Stuck: %d time%s%s" % [int(_rep.stuck_n), "" if int(_rep.stuck_n) == 1 else "s", " (first %d below)" % STUCK_KEEP if more > 0 else ""])
		for l in _rep.stuck:
			lines.append("Stuck: " + str(l))
	lines.append("Graphics %s (3D %s) | FPS avg %d, lowest %d, 1%% low %d, steady %d%% | longest frame %d ms%s | warm-up %d ms" % [GRAPHICS_NAMES[graphics_level], _draw_size_text(),
		roundi(_fps_sum / maxf(1.0, _fps_n)), roundi(_fps_low if _fps_low < 999.0 else 0.0), roundi(one_percent_low(_frame_hist)),
		roundi(steady_share(_frame_hist) * 100.0), roundi(_longest_ms),
		(" (%s%s)" % [_longest_at, "; added " + _longest_new if _longest_new != "" else ""]) if _longest_at != "" else "", Warmup.last_ms])
	lines.append("Memory: most %d MB (graphics %d MB) | phone RAM %s" % [_mem_peak, _mem_peak_video, ram_text()])
	if int(cfg.get_value("stats", "review_n", 0)) > 0:
		lines.append("Rating card: asked %d time%s, last on build %s | Play said: %s" % [int(cfg.get_value("stats", "review_n", 0)),
			"" if int(cfg.get_value("stats", "review_n", 0)) == 1 else "s", str(cfg.get_value("stats", "review_build", "before 2026-11-16")),
			str(cfg.get_value("stats", "review_result", "nothing yet"))])
	return "\n".join(lines)


func _reset_run_stats() -> void:
	_reset_report()
	Upgrades.resting.clear()
	# Version 218: dying in the Queen's Eclipse left its dark veil up on TRY AGAIN (her move
	# stops when the hero dies, before it turns the Eclipse off).
	if _eclipse_tw:
		_eclipse_tw.kill()
	_eclipse_k = 0.0
	_eclipse_eff = 0.0
	hud.set_surge(0.0, false, true)
	_shards_shown = 0
	_caskets_run = 0
	_surge_t = 0.0
	surge = 0.0
	_surge_on = false
	hud.set_shards(0 if event != "" else -1)
	_frame_hist = PackedInt32Array()
	_frame_hist.resize(251)
	_feats_got.clear()
	_feats_unsaved.clear()
	_feats_run.clear()
	var fcfg := _load_save()
	for f: Dictionary in Feats.LIST:
		if Feats.done(fcfg, f.id):
			_feats_got[f.id] = true
	_floor_hits = 0
	_continued_floor = -1
	_room_special = 0
	_top_chain_t = 0.0
	_best_chain_hold = 0.0
	_best_chain4 = 1.0
	_room_hits = 0
	_room_dashes = 0
	_nudged_run = false
	_swipe_tips = 0
	_run_time = 0.0
	_kills = 0
	run_coins = 0
	_drops_run = 0
	_road_shown = 0
	_mastery_shown = 0
	_mastery_run = 0
	_mastery_callout = ""
	_combo = 0
	chain = 1.0
	score = 0
	hud.show_chain(1.0)
	_lessons_this_run = 0
	floor_num = 1
	_taken.clear()
	rerolls = 1
	omens.clear()
	_curse_omen = ""
	_loop_choice = false
	_omen_choices = []
	_doors = []
	_door = {}
	_picked = {}
	_pick_family = ""
	_pick_better = false
	_extra_pick = false


## Gives the hero everything bought in the Armory. Called once at the start of each run.
func _apply_armory() -> void:
	var cfg := _load_save()
	if race:
		# The Crypt Race leaves the Armory, the Vault and Lucky Starts at home: both racers start
		# the same, with the race's two-blessing Race Kit.
		vault = []
		heart_bonus = 0.0
		for id: String in _race.kit:
			_taken[id] = _taken.get(id, 0) + 1
			Upgrades.apply(id, hero)
		return
	vault = Armory.vault_owned(cfg)
	Armory.apply_to_hero(cfg, hero)
	heart_bonus = Armory.heart_bonus(cfg)
	# The Daily Crypt's own gifts come first, so the Armory's Blessed Start below can't roll a
	# blessing the day already gives (Marrow twice on a Marrow Monday was one wasted).
	if daily:
		var gifts := []
		if curses.has("blessed"):
			gifts.append(Curses.daily_blessing(_daily_date).id)
		if Curses.theme(_daily_date).has("perk"):
			gifts.append(Curses.theme(_daily_date).perk)
		for id in gifts:
			_taken[id] = _taken.get(id, 0) + 1
			Upgrades.apply(id, hero)
	# The Queen Hunt starts with a handful of blessings, more on higher tiers.
	if event == "hunt" or _side_run():
		var names := []
		for i in (DIVE_GIFTS if dive else (QUICK_GIFTS if quick else int(Events.tiers()[event_tier - 1].gifts))):
			var g := Upgrades.roll(_taken, 4, false, "", false, null).filter(func(x: Dictionary):
				return x.rarity != "synergy" and not str(x.id) in Events.HUNT_NO_GIFT)
			if g.is_empty():
				continue
			var u: Dictionary = g[0]
			_taken[u.id] = _taken.get(u.id, 0) + 1
			Upgrades.apply(u.id, hero)
			names.append(str(u.title))
		if not names.is_empty():
			var line := "Blessed: " + ", ".join(names)
			get_tree().create_timer(1.4, false).timeout.connect(func(): hud.banner(line, Color(1.0, 0.55, 0.45)))
	if Armory.level(cfg, "blessed") > 0:
		# (Two rolled, so a synergy the day's gifts complete can't be the start blessing.)
		var pick := Upgrades.roll(_taken, 2, false, "", false, Curses.daily_rng(499, _daily_date) if daily else null) \
				.filter(func(x: Dictionary): return x.rarity != "synergy")
		if not pick.is_empty():
			var u: Dictionary = pick[0]
			_taken[u.id] = _taken.get(u.id, 0) + 1
			Upgrades.apply(u.id, hero)
			_start_blessing = u
	# A Lucky Start from a Bone Drop: one more blessing, in the next normal run.
	if not daily and not first_run and not _side_run() and Drops.lucky(cfg) > 0:
		var lucky := Upgrades.roll(_taken, 2, false, "", false, null) \
				.filter(func(x: Dictionary): return x.rarity != "synergy")
		if not lucky.is_empty():
			var u: Dictionary = lucky[0]
			_taken[u.id] = _taken.get(u.id, 0) + 1
			Upgrades.apply(u.id, hero)
			_lucky_blessing = u
			Drops.use_lucky(cfg)
			write_save(cfg)
	if curses.has("brittle"):
		hero.max_health = roundf(hero.max_health * 0.5)
		hero.health = minf(hero.health, hero.max_health)
	if curses.has("glass"):
		hero.damage *= 1.5
		hero.max_health = roundf(hero.max_health * 0.7)
		hero.health = minf(hero.health, hero.max_health)
	if curses.has("dice"):
		rerolls = 3
	if curses.has("narrow"):
		rerolls = 0


func _restart() -> void:
	if dive and not dive_ready():
		_back_to_title(true)   # version 280: the Free Dive is used up, so no second one
		return
	_after_tutorial = false
	_gift_names = []
	_set_state(State.TRANSITION)
	# Version 164: a tutorial retry starts in the room the player fell in, with the same rooms
	# and the blessings they had, instead of from room 1 again.
	var fell_room := _room_index
	var fell_taken := _taken.duplicate()
	var fell_run := _run.duplicate(true)
	var fell_ids := _run_ids.duplicate()
	var again_floor := _retry_floor()   # (before the run's numbers are reset)
	var again_quick := floor_num
	await _fade(0.0, 1.0, 0.4)
	hud.show_end(false)
	if hero:
		hero.queue_free()
		hero = null
	_reset_run_stats()
	if dive:
		floor_num = DIVE_FLOOR   # the Free Dive again (the Tidecaller wasn't reached)
		_count_dive_try()
	if quick:
		# Version 310: after a fall, the same place again; after a win, another place.
		floor_num = quick_floor() if _quick_done else again_quick
		_quick_done = false
		Telemetry.step("quick_start")
	record_add("runs", 1)
	if event != "" and not Events.active():
		event = ""   # the event ended while on the end screen: a normal run
	_event_done = false
	if daily and _daily_date != Curses.today():
		# A new day started while on the end screen: retry on today's Daily Crypt.
		daily = Curses.can_play(Store.owned(), _load_save())
		if daily:
			_begin_daily()
		else:
			_run_hero_id = ""
	elif daily and not Store.owned():
		# Practice runs come with the Crypt Pass, so TRY AGAIN starts a normal run.
		daily = false
		_run_hero_id = ""
	elif daily:
		_daily_practice = true   # the Official run is used up
		_daily_done = false
	else:
		_run_hero_id = ""   # a free trial is one run
	first_run = first_run_pending()   # true only after a first death in the tutorial
	var again_at := fell_room if first_run and fell_room > 0 and fell_room < fell_run.size() else 0
	start_floor = again_floor if _normal_run() else 1
	if start_floor > 1:
		floor_num = start_floor
		_save_start_floor(start_floor)
	_check_newcomer()
	_build_run()
	if again_at > 0:
		_run = fell_run
		_run_ids = fell_ids
	_pick_curses()
	hud.show_hud(true)
	_load_room(0, false)
	_apply_armory()
	_catch_up()
	if again_at > 0:
		# Only the blessings the Armory didn't just give back.
		for id in fell_taken:
			for k in int(fell_taken[id]) - int(_taken.get(id, 0)):
				_taken[id] = _taken.get(id, 0) + 1
				Upgrades.apply(id, hero)
	_load_room(again_at, true)
	await _fade(1.0, 0.0, 0.4)
	_mode_banner()


## From the pause menu: give up this run and go back to the title (coins are kept).
func _quit_to_title() -> void:
	if state != State.PAUSED:
		return
	hud.show_pause(false)
	get_tree().paused = false
	if race:
		_race_end(false, true)   # leaving a race is a loss
		_back_to_title(true)
		hud.tip("You left the Crypt Race: it counted as a loss.", 4.0, 1.0)
		return
	if first_run:
		Telemetry.step("quit_" + _step_room())
	Telemetry.instance.send("run", run_report("Quit on floor %d, room %d" % [floor_num, _room_index + 1]))
	_back_to_title()   # (its _save_coins keeps the Bone Road bones)


# ---------------------------------------------------------------- speed test

## SPEED TEST (title Settings): one minute of fighting that plays itself (speed_test.gd).
func start_speed_test() -> void:
	if state != State.TITLE or bench or get_node_or_null("SpeedTest"):
		return
	hud.show_settings(false)
	var t := SpeedTest.new()
	t.name = "SpeedTest"
	add_child(t)


## The test's start: like a run's, but with nothing from the Armory, no curses or saved-run
## changes, and the hero that's on the title. Feats are counted as already earned, so none
## is announced (or saved) during the test.
func bench_begin() -> void:
	bench = true
	first_run = false
	daily = false
	_trial_hero = ""
	_run_hero_id = ""
	hud.show_title(false)
	hud.show_armory(false)
	hud.show_pass(false)
	hud.show_daily(false)
	hud.show_hud(true)
	_reset_run_stats()
	curses = []
	_update_score_mult()
	_start_blessing = {}
	_lucky_blessing = {}
	_door = {}
	for f: Dictionary in Feats.LIST:
		_feats_got[f.id] = true


## One of the test's rooms: the same room (the spider nest) on floor `f`, with no skeletons
## of its own (the test brings them). Returns once the room is showing.
func bench_room(f: int) -> void:
	_set_state(State.TRANSITION)
	if Room.current:
		await _fade(0.0, 1.0, 0.25)
	_clear_enemy_attacks()
	floor_num = f
	_build_run()
	_run[0] = Layouts.MEDIUM[0]
	_run_ids[0] = "M0"
	_load_room(0, false)
	_wave_total = 1
	_waves_left = 0
	_wave_pending = false
	hud.set_room(1, 1, false, floor_num)
	hud.set_wave(1, 1)
	hud.banner("Speed test · " + str(Floors.current().name))
	Music.play("dungeon")
	_set_state(State.PLAYING)
	await _fade(1.0, 0.0, 0.25)


## The test's end: back to the title with nothing kept. Coins, records, Mastery points and
## Bone Road bones picked up in the test are dropped, and the save is read again.
func bench_end() -> void:
	if get_tree().paused:
		hud.show_pause(false)
		get_tree().paused = false
	run_coins = 0
	_road_unsaved = 0
	_mastery_unsaved = 0
	_mastery_run = 0
	_mastery_hero = ""
	_feats_unsaved.clear()
	_perfect_total = -1
	coins = int(_load_save().get_value("stats", "coins", coins))
	await _back_to_title()
	_rec_add.clear()
	_rec_max.clear()
	coins = int(_load_save().get_value("stats", "coins", coins))
	hud.set_coins(coins)
	bench = false


## TITLE (or Android Back) on the end screens. A won run stays saved, so CONTINUE on the
## title picks it up again.
func _end_to_title() -> void:
	if not hud.end_visible():
		return
	if state == State.DEAD:
		_back_to_title()
	elif state == State.VICTORY:
		_back_to_title(true)


func _back_to_title(keep_run := false) -> void:
	_set_state(State.TRANSITION)
	_save_coins()
	var mastery_note := _give_mastery_on_title()   # before the hero is made again, in a new color
	if not keep_run and not _side_run():
		RunSave.clear()
	_free_end = false
	await _fade(0.0, 1.0, 0.4)
	hud.show_end(false)
	hud.show_pass(false)
	hud.show_omens(false)
	daily = false
	_daily_done = false
	event = ""
	_event_done = false
	race = false
	dive = false
	_dive_done = false
	quick = false
	_quick_done = false
	_race = null
	_race_live = false
	hud.race_bar.visible = false
	hud.race_surge.visible = false
	_end_surge()
	omens.clear()
	_loop_choice = false
	_omen_choices = []
	_run_hero_id = ""
	_trial_hero = ""
	curses = []
	_score_mult = 1.0
	_hourglass_out = false
	_clear_enemy_attacks()
	if hero:
		hero.queue_free()
		hero = null
	floor_num = 1
	Floors.lobby = Events.active() and not first_run_pending() and unlock_stage() >= 3
	_build_run()
	_load_room(0, false)
	hero.place_at(Vector3(0, 0, 2))
	_snap_camera()
	# Version 165: after the tutorial, while the screen is black, the rest of the warm-up
	# that a new player's first launch left out (every floor, skeleton and look).
	# Version 221 (v219 review): only when this session hasn't shown the full one yet. After
	# an update a slow phone showed it again after each run (up to 3 times); now the next
	# launch carries on from where it stopped.
	if not Warmup.core_only(_load_save()) and not Warmup.full_tried:
		var warmed: bool = await Warmup.run(false, Warmup.resume_step(_load_save()))
		var wcfg := _load_save()
		Warmup.mark_full(wcfg, warmed)
		write_save(wcfg)
	_title_hero_line(hero.hero_id)
	hud.show_hud(false)
	hud.hide_boss()
	hud.show_hint("")
	hud.show_title(true, _best_text(), coins)
	if mastery_note != "":
		hud.set_drops(Drops.waiting(_load_save()))
		hud.tip(mastery_note, 4.5, 0.5)
	Music.play(title_track())
	_set_state(State.TITLE)
	_check_pass_lost()
	_settle_events()
	if _to_event:
		_to_event = false
		_open_event()
	await _fade(1.0, 0.0, 0.4)
	_maybe_event_splash()
	_ask_reminders_on_title()


## After beating the king: keep your blessings and go one floor deeper, where it's harder.
## Every new floor brings a free reroll; a new loop gives full health and two more.
func _descend() -> void:
	if _free_end or _dive_done or _quick_done:
		return
	_set_state(State.TRANSITION)
	await _fade(0.0, 1.0, 0.5)
	hud.show_end(false)
	floor_num += 1
	_curse_omen = ""   # a Cursed Door lasts its own floor
	if _door.get("kind", "") != "path":
		_door = {}   # a treasure door before the boss paid out in the boss room
	var new_loop := Loops.loop_end(floor_num - 1)
	if new_loop:
		hero.heal(hero.max_health)
		if not curses.has("narrow"):   # Narrow Path means no rerolls at all
			rerolls += Loops.LOOP_REROLLS
	else:
		# 30% back, and never fewer than 60% to start the floor: a hero who scraped past the
		# boss used to walk into a harder floor's first room on a sliver and die there
		# (run reports: Rogue 25/100 after the Lich, dead in floor 3's first room).
		hero.heal(maxf(hero.max_health * 0.3, hero.max_health * 0.6 - hero.health))
		if not curses.has("narrow"):
			rerolls += 1
	_build_run()
	_load_room(0, true)
	_show_gifts()
	var loop := Loops.loop_of(floor_num)
	hud.banner(("Loop %d · " % loop if loop > 1 else "") + "Floor %d: %s" % [floor_num, Floors.current().name], Floors.current().banner)
	var partner := Floors.remix_partner(floor_num)
	if partner >= 0:
		# Version 299: the remix names the danger that has come along.
		print("[run] remix: %s + %s" % [Floors.current().name, Floors.DANGER_WORD[partner]])
		get_tree().create_timer(2.2, false).timeout.connect(func():
			if state == State.PLAYING:
				hud.callout("+ " + str(Floors.DANGER_WORD[partner]).to_upper() + "!", Color(1.0, 0.6, 0.3)))
	if new_loop and not omens.is_empty():
		hud.tip("LOOP %d  ·  Score x%s\nOmens: %s" % [loop, _mult_text(_score_mult), Loops.names(omens)], 4.0, 1.8)
	await _fade(1.0, 0.0, 0.5)


## A plain run: not the tutorial, a Daily Crypt, an event, a Crypt Race, the Free Dive or the
## speed test. Only these can start deeper (version 309).
func _normal_run() -> bool:
	return not (first_run or daily or event != "" or race or _side_run() or bench)


## The start floors this save has opened: floor 1, and every checkpoint floor already reached
## (floors past the free crypt only with the Crypt Pass).
func start_checkpoints(cfg: ConfigFile = null) -> Array:
	if cfg == null:
		cfg = _load_save()
	var best := int(cfg.get_value("stats", "best_floor", 1))
	var out := []
	for f: int in CHECKPOINTS:
		if f == 1 or (f <= best and (f <= Store.FREE_FLOORS or Store.owned(cfg))):
			out.append(f)
	return out


## The start floor picked on the title (the deepest open one at or above it).
func chosen_start(cfg: ConfigFile = null) -> int:
	if cfg == null:
		cfg = _load_save()
	var want := int(cfg.get_value("settings", "start_floor", 1))
	var out := 1
	for f: int in start_checkpoints(cfg):
		if f <= want:
			out = f
	return out


func _save_start_floor(f: int) -> void:
	var cfg := _load_save()
	cfg.set_value("settings", "start_floor", f)
	write_save(cfg)


## The title's start-floor button: "" while only floor 1 is open.
func start_text() -> String:
	if first_run_pending() or start_checkpoints().size() <= 1:
		return ""
	return "START ON FLOOR %d  >" % chosen_start()


## A tap on the start-floor button: the next open floor (back to 1 after the deepest).
func cycle_start_floor() -> void:
	if state != State.TITLE:
		return
	var open := start_checkpoints()
	var i := open.find(chosen_start())
	var next: int = open[(i + 1) % open.size()]
	_save_start_floor(next)
	Sfx.play("click")
	hud.show_title(true, _best_text(), coins)


## TRY AGAIN after a fall: the deepest open start floor at or above the floor of the fall,
## so a fall on floor 4 tries again from floor 3, not floor 1.
func _retry_floor() -> int:
	if not _normal_run():
		return 1
	var out := 1
	for f: int in start_checkpoints():
		if f <= floor_num:
			out = f
	return out


## A deeper start's blessings: CATCHUP_GIFTS random ones and a reroll for each floor skipped,
## and full health (the skipped floors' gifts and hearts).
func _catch_up() -> void:
	if floor_num <= 1 or not _normal_run() or hero == null:
		return
	var skipped := floor_num - 1
	var names := []
	for i in skipped * CATCHUP_GIFTS:
		var g := Upgrades.roll(_taken, 4, false, "", false, null).filter(func(x: Dictionary) -> bool:
			return x.rarity != "synergy" and not x.get("endless", false))
		if g.is_empty():
			break
		var u: Dictionary = g[0]
		_taken[u.id] = _taken.get(u.id, 0) + 1
		Upgrades.apply(u.id, hero)
		names.append(str(u.title))
	if not curses.has("narrow"):
		rerolls += skipped
	hero.heal(hero.max_health)
	print("[run] start on floor %d: %s" % [floor_num, ", ".join(names)])
	var line := "Floor %d start: %d blessings for the road" % [floor_num, names.size()]
	get_tree().create_timer(2.4, false).timeout.connect(func(): hud.banner(line, Color(1.0, 0.82, 0.3)))


## A run that leaves a saved run, the records and the leaderboard alone: the Free Dive
## (version 280) and Quick Play (version 310).
func _side_run() -> bool:
	return dive or quick


## Version 310: Quick Play opens with the second run (unlock stage 2), as the Pass row does.
func quick_open(cfg: ConfigFile = null) -> bool:
	return not first_run_pending() and unlock_stage(cfg) >= 2


## The title's QUICK PLAY button starts one.
func start_quick() -> void:
	if state != State.TITLE or not quick_open():
		return
	Sfx.play("click")
	_quick_requested = true
	_start_run()


## A place already reached (the ten places at most; the Crypt Pass's floors with the Pass),
## never the one played last, so Quick Play after Quick Play moves around the crypt.
func quick_floor(cfg: ConfigFile = null) -> int:
	if cfg == null:
		cfg = _load_save()
	var best := int(cfg.get_value("stats", "best_floor", 1))
	var top := mini(best, QUICK_MAX_FLOOR)
	if not Store.owned(cfg):
		top = mini(top, Store.FREE_FLOORS)
	top = maxi(top, 1)
	var last := int(cfg.get_value(QUICK_SECTION, "last_floor", 0))
	var f := randi_range(1, top)
	if top > 1 and f == last:
		f = (f % top) + 1
	cfg.set_value(QUICK_SECTION, "last_floor", f)
	write_save(cfg)
	return f


## Today's Quick Play wins so far, and whether this win still pays a Bone Drop (the day's
## first QUICK_DROPS do). Counts the win either way (the caller saves `cfg`).
func _quick_drop(cfg: ConfigFile) -> bool:
	var day := Curses.today()
	var wins := quick_wins(cfg) if str(cfg.get_value(QUICK_SECTION, "day", "")) == day else 0
	cfg.set_value(QUICK_SECTION, "day", day)
	cfg.set_value(QUICK_SECTION, "wins", wins + 1)
	cfg.set_value(QUICK_SECTION, "total", int(cfg.get_value(QUICK_SECTION, "total", 0)) + 1)
	return wins < QUICK_DROPS


func quick_wins(cfg: ConfigFile = null) -> int:
	if cfg == null:
		cfg = _load_save()
	if str(cfg.get_value(QUICK_SECTION, "day", "")) != Curses.today():
		return 0
	return int(cfg.get_value(QUICK_SECTION, "wins", 0))


## The win screen's line: whether this win paid one of the day's Bone Drops.
func _quick_text(cfg: ConfigFile) -> String:
	var wins := quick_wins(cfg)
	if wins <= QUICK_DROPS:
		return "+1 Bone Drop  (Quick Play drop %d of %d today)" % [wins, QUICK_DROPS]
	return "Coins, bones and Mastery count.\nQuick Play's Bone Drops come back tomorrow."


## Version 311: today's goals (today.gd). Goals finished since the last end screen, for its lines.
var _today_done: Array = []


## Banks today's goal progress into `cfg` (called by _save_coins, which saves it): each goal
## just finished pays Today.GOAL_COINS and gets a banner (and a line on the next end screen).
func _bank_today(cfg: ConfigFile) -> void:
	if bench:
		Today.pending.clear()
		return
	if not _rep.is_empty():
		Today.best("chain", roundi(float(_rep.get("best_chain", 1.0)) * 10.0))
	if first_run_pending():
		return   # (kept in `pending` until the tutorial is won: the goals show from then)
	var done: Array = Today.bank(cfg)
	if done.is_empty():
		return
	coins += Today.GOAL_COINS * done.size()
	hud.set_coins(coins)
	_today_done.append_array(done)
	var all: bool = Today.done_count(cfg) >= Today.COUNT
	for g: Dictionary in done:
		print("[today] goal done: %s (+%d coins)%s" % [g.text, Today.GOAL_COINS, "  ALL DONE: chest ready" if all else ""])
	if state == State.PLAYING or state == State.UPGRADE or state == State.TRANSITION:
		var line := "TODAY'S GOAL DONE!  %s  +%d coins" % [str(done[0].text), Today.GOAL_COINS]
		if all:
			line += "\nAll 3 done: the Today Chest is waiting in REWARDS"
		hud.banner(line, Color(0.55, 1.0, 0.6))
		Sfx.play("coin", 1.2)


## The end screen's lines for the goals finished this time, then cleared.
func _today_lines() -> String:
	if _today_done.is_empty():
		return ""
	var out := ""
	for g: Dictionary in _today_done:
		out += "\nToday's goal done: %s  +%d coins" % [str(g.text), Today.GOAL_COINS]
	_today_done.clear()
	var cfg := _load_save()
	if Today.chest_ready(cfg):
		out += "\nAll 3 done: open the Today Chest in REWARDS!"
	return out


## REWARDS > TODAY'S GOALS > OPEN THE CHEST.
func open_today_chest() -> void:
	var cfg := _load_save()
	if not Today.open_chest(cfg):
		return
	coins += Today.CHEST_COINS
	cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	hud.set_coins(coins)
	Sfx.play("victory")
	print("[today] chest opened: +%d coins, +1 Bone Drop" % Today.CHEST_COINS)
	hud.today_opened(Today.CHEST_COINS)


## Version 169: the 3-room tutorial gives 2 blessings where the old 5 rooms gave 5. Going
## on to floor 2 straight after it adds the 3 missing ones, so floor 2 isn't harder than before.
const TUTORIAL_GIFTS := 3
## The gifts' names, for floor 2's banner (saved with the run, so CONTINUE shows it too).
var _gift_names: Array = []

## Given on the tutorial's win screen (version 211; it was on the way down to floor 2, so a
## player who went to the title first never got them).
func _tutorial_gifts() -> void:
	if not _after_tutorial or hero == null:
		return
	var names: Array[String] = []
	# Version 306: three different cards that change how the hero fights (Upgrades.roll_gifts),
	# not three random ones (mostly number cards, sometimes one twice).
	for u: Dictionary in Upgrades.roll_gifts(_taken, TUTORIAL_GIFTS):
		_taken[u.id] = _taken.get(u.id, 0) + 1
		Upgrades.apply(u.id, hero)
		names.append(str(u.title))
	hero.heal(hero.max_health)   # and a full heal: the old tutorial's 5 rooms dropped more hearts
	_gift_names = names.duplicate()
	if not names.is_empty():
		print("[run] Gifts for the road: " + ", ".join(names))


## The gifts' banner as floor 2 starts (straight down, or by CONTINUE).
func _show_gifts() -> void:
	if floor_num != 2 or _gift_names.is_empty():
		_gift_names = []
		return
	var line := "Gifts for the road: " + ", ".join(_gift_names)
	_gift_names = []
	get_tree().create_timer(1.6, false).timeout.connect(func(): hud.banner(line, Color(1.0, 0.82, 0.3)))


## The coins BANK AND LEAVE pays on top of the run's own.
func _bank_bonus() -> int:
	return roundi(run_coins * (Loops.BANK_BONUS + Loops.OMEN_BANK * Loops.total(omens)))


## BANK AND LEAVE at the end of a loop: the run ends here, paying its coins again (and a
## quarter more for each Omen).
func _bank_run() -> void:
	if state != State.VICTORY or not _loop_choice:
		return
	var bonus := _bank_bonus()
	_loop_choice = false
	_claim_day_bonus()   # before the bank adds to this run's coins
	add_coins(bonus)
	Sfx.play("upgrade")
	print("[run] banked after loop %d: +%d coins, %d in all" % [Loops.loop_of(floor_num), bonus, coins])
	_back_to_title()


## DESCEND DEEPER at the end of a loop: first pick one of three Omens.
func _open_omens() -> void:
	if state != State.VICTORY or not _loop_choice:
		return
	Sfx.play("click")
	if _omen_choices.is_empty():
		_omen_choices = Loops.choices()   # kept if the player backs out, so BACK can't reroll them
	hud.show_omens(true, _omen_choices, Loops.loop_of(floor_num) + 1, Loops.names(omens))


func _pick_omen(id: String) -> void:
	if state != State.VICTORY or not _loop_choice or Loops.get_omen(id).is_empty():
		return
	Sfx.play("upgrade")
	omens[id] = int(omens.get(id, 0)) + 1   # v219 review: a Cursed Door's Omen is not saved into the loop's
	_omen_choices = []
	_loop_choice = false
	_update_score_mult()
	hud.show_omens(false)
	print("[run] omen %s, now %s, score x%s" % [id, Loops.names(omens), _mult_text(_score_mult)])
	_descend()


## A run saved on the end-of-loop screen comes back to that screen.
func _resume_loop_end() -> void:
	_load_room(_run.size() - 1, false)
	_set_state(State.VICTORY)
	if not Store.owned() and floor_num >= Store.FREE_FLOORS:
		# Floor 5 cleared without the Crypt Pass: its offer again; buying it carries on.
		_free_end = true
		hud.show_end(true, true, "Run continued.\n\n" + _free_end_text(),
			"", false, score, int(_load_save().get_value("stats", "best_score", 0)), true)
		return
	_loop_choice = true
	hud.show_end(true, true, "Run continued.\n\n" + _loop_text(), "", false, score, int(_load_save().get_value("stats", "best_score", 0)))
	hud.show_end_loop(true, _bank_bonus(), Loops.loop_of(floor_num) + 1)


func _free_end_text() -> String:
	return "You beat the free crypt!\nBelow lies the Drowned Vault.\nThe Crypt Pass opens floor %d and beyond.\nThis run stays saved until you get it." % (floor_num + 1)


## Version 280: true while this save can still take its one Free Dive (no Crypt Pass, past
## the first runs, and the Tidecaller's room not reached in a dive yet).
func dive_ready(cfg: ConfigFile = null) -> bool:
	if cfg == null:
		cfg = _load_save()
	return not Store.owned(cfg) and unlock_stage(cfg) >= 2 and not bool(cfg.get_value("pass", "dive_used", false)) \
		and dive_tries_left(cfg) > 0


## Review fix 1 (build 295): a fall before the Tidecaller used to leave the Free Dive for
## another go, as often as you liked, and the coins from it were kept (a free floor-6 farm).
## Now it has three tries.
const DIVE_TRIES := 3

func _count_dive_try() -> void:
	var cfg := _load_save()
	cfg.set_value("pass", "dive_tries", int(cfg.get_value("pass", "dive_tries", 0)) + 1)
	write_save(cfg)


func dive_tries_left(cfg: ConfigFile = null) -> int:
	if cfg == null:
		cfg = _load_save()
	return maxi(DIVE_TRIES - int(cfg.get_value("pass", "dive_tries", 0)), 0)


## FREE DIVE on the Crypt Pass screen (or on the title's Pass button's card): floor 6 now.
func _start_dive() -> void:
	if state != State.TITLE or not dive_ready():
		return
	hud.show_pass(false)
	_dive_requested = true
	_start_run()


## The Tidecaller's room uses the Free Dive up (a fall before it leaves it for another go).
func _use_dive() -> void:
	var cfg := _load_save()
	if bool(cfg.get_value("pass", "dive_used", false)):
		return
	cfg.set_value("pass", "dive_used", true)
	write_save(cfg)
	Telemetry.step("dive_boss")


## The Free Dive's end-screen words: after the Tidecaller fell (`won`), or after a fall.
func _dive_text(won: bool) -> String:
	if won:
		return "The Tidecaller has fallen!\nThat was the Drowned Vault, floor 6.\nThe Crypt Pass opens it for good,\nand 4 more places, each with its own boss."
	if dive_ready():
		var left := dive_tries_left()
		return "Your Free Dive is still there:\n%d %s left to reach the Tidecaller." % [left, "try" if left == 1 else "tries"]
	return "That was your Free Dive.\nThe Crypt Pass opens the Drowned Vault\nfor good, plus 4 more places and bosses."


func _loop_text() -> String:
	var loop := Loops.loop_of(floor_num)
	return "Loop %d cleared! Bank the run for +%d coins,\nor descend into loop %d." % [loop, _bank_bonus(), loop + 1]


func enter_next_room() -> void:
	if state != State.PLAYING:
		return
	_go_to_room(_room_index + 1)


func _go_to_room(index: int) -> void:
	_set_state(State.TRANSITION)
	if index > 0:
		await _fade(0.0, 1.0, 0.35)
	_load_room(index, true)
	await _fade(1.0, 0.0, 0.35)


func _load_room(index: int, spawn_enemies: bool) -> void:
	_room_index = index
	_room_serial += 1
	if spawn_enemies and hero and hero.perks.has("opening_volley"):
		hero.special_charge = 1.0   # Opening Volley (a Vault card, v219)
	if daily or race:
		_room_rng = Curses.daily_rng(700 + floor_num * 10 + index, _daily_date)
	else:
		_room_rng.randomize()
	alive_enemies = 0
	_stall_time = 0.0
	_stall_step = 0
	_no_enemies_time = 0.0
	boss = null
	_bosses.clear()
	_boss_lost = 0.0
	_hourglass_out = false
	_hourglass_left = Curses.HOURGLASS_BOSS if index == _run.size() - 1 else Curses.HOURGLASS_ROOM
	hud.set_timer(_hourglass_left if spawn_enemies and curses.has("hourglass") else -1.0)
	var room := Room.build(world, _run[index], "Boss" if _in_boss_room() else str(index + 1))
	if event != "" and Floors.frostfall():
		Blizzard.dress(room)   # version 243: two braziers against the Blizzard
	var look := Floors.current()
	_light_room(look)
	# Version 143: every room gets its own mood (gold treasure, the champion's ring, the lit
	# boss gate, light shafts and ritual circles), so a floor's rooms stop looking alike.
	var mood := RoomMood.pick(index, _run.size(), _door, floor_num)
	RoomMood.apply(room, mood, _run[index])
	if mood == "approach":
		_env.ambient_light_energy *= 0.6
	Fx.ambience(room, Room.HALF_W - 0.5, Room.HALF_L - 0.5, [14, 14, 24, 36][graphics_level], look.motes, look.motes_fall, look.get("motes_size", 1.0))
	Fx.wisps(room, look.get("wisp", Color(0.6, 1.0, 0.85)), [2, 3, 4, 5][graphics_level], Room.HALF_W - 0.8, Room.HALF_L - 0.8)
	if hero == null:
		hero = Hero.spawn(world, room.player_start(), _run_hero_id if _run_hero_id != "" else Heroes.selected(_load_save()))
	hero.place_at(room.player_start())
	hero.new_room()
	_night_light()
	_snap_camera()
	if not spawn_enemies:
		return
	hud.set_room(index + 1, _combat_rooms(), _in_boss_room(), 1 if event == "hunt" else floor_num)   # (the hunt has no floors)
	if first_run and floor_num == 1:
		Telemetry.step(_step_room())   # version 157: how far new players get
	elif index == 0 and floor_num == 2 and not race and event == "":
		Telemetry.step("floor2")
	if not _rep.is_empty():
		_rep.room_start = _run_time
		_rep.room_chain = chain
		_room_hits = int(_rep.hits)
		_room_dashes = int(_rep.dash)
		_room_special = int(_rep.special)
		if index == 0:
			_floor_hits = int(_rep.hits)
	if not _in_boss_room() and not (race and index == 0):   # (a race's first room has its 3-2-1)
		hud.banner("Room %d" % (index + 1))
	# A new run (not the tutorial): the hero says something as they step in (version 129).
	# (Version 211, Tweaks report #3: no "hello" line in room 1 any more. Its speech card sat
	# right over the first wave; the hero still speaks on the title.)
	if Doors.room_tip(_door) != "":
		hud.tip(Doors.room_tip(_door), 3.5, 1.4)
	if first_run:
		hud.show_hint("Drag to move. Lift to shoot." if index == 0 else "")
		_ftue_room_intro()
	else:
		# Version 148: only in a player's first few runs (it showed on every floor 1 forever).
		hud.show_hint("Drag to move. Lift to shoot.\nFlick your thumb to dash!" if floor_num == 1 and index == 0 and _newcomer else "")
	var boss_track := Events.word("music") if event != "" and boss_kind() == str(Events.ev().get("boss", "Q")) else "boss"
	Music.play((boss_track if Music.TRACKS.has(boss_track) else "boss") if _in_boss_room() else "dungeon")
	if race and _race and not _race.over and _in_boss_room():
		Sfx.play("race_final", 0.9)   # the last leg (version 155)
	if not _start_blessing.is_empty():
		var u := _start_blessing
		_start_blessing = {}
		get_tree().create_timer(1.6, false).timeout.connect(func(): hud.banner("Blessed: " + u.title, Upgrades.color(u)))
	if not _lucky_blessing.is_empty():
		var u := _lucky_blessing
		_lucky_blessing = {}
		get_tree().create_timer(3.4, false).timeout.connect(func(): hud.banner("Lucky Start: " + u.title, Upgrades.color(u)))
	_wave_kinds.clear()
	_wave_elites = 0
	_room_tips = 0
	var mages := 0
	var spitters := 0
	var theme_kind := theme_enemy()
	# With two kinds (the Glowcap Grotto), every other room puts the second one first, so a
	# room with a single minion still meets both over a floor.
	if theme_kind.length() > 1 and index % 2 == 1:
		theme_kind = theme_kind.reverse()
	# The Sandfall Tomb's two took turns, one a room (version 247), as floor 5 had one before.
	# Version 273: its own Tomb Mummy comes to every room, its Frost Wraiths every other one.
	if Floors.sandfall() and index % 2 == 0:
		theme_kind = theme_kind.left(1)
	# The tutorial teaches the basics first: bone spiders and bombers wait for floor 2. They
	# are left out (they used to turn into extra minions, a bigger pack for a new player),
	# unless that would leave fewer than two skeletons in the room.
	var plain := 0
	for s in room.spawns:
		if s.kind != "s" and s.kind != "x":
			plain += 1
	# Version 295 (deep review fix 3): the floor's own skeletons used to replace minions only,
	# and 7 of the 11 hard rooms have none, so the floor's own skeleton was missing from about
	# two rooms in three. Now every room gets each of them: a minion changes first, then a
	# warrior, archer, mage, spitter or spider (never the boss or a bomber).
	var swap := {}
	var taken := {}
	for k in theme_kind:
		var got := -1
		for want: String in ["m", "w", "a", "g", "t", "s"]:
			for i in room.spawns.size():
				if not taken.has(i) and str(room.spawns[i].kind) == want:
					got = i
					break
			if got >= 0:
				break
		if got >= 0:
			taken[got] = true
			swap[got] = k
	var spawn_i := -1
	for s in room.spawns:
		spawn_i += 1
		var kind: String = s.kind
		if first_run and (kind == "s" or kind == "x"):
			if plain >= 2:
				continue
			kind = "m"
		# Version 149 (difficulty review, fix 3): nothing shoots in the tutorial's first room.
		# Arrows and shards arrive in room 2, with the dash lesson.
		if ftue_room() == 1 and (kind == "a" or kind == "t"):
			kind = "m"
		# Version 169: the dash room always has an archer to dash through.
		if ftue_room() == 2 and kind == "m" and not _wave_kinds.has("a"):
			kind = "a"
		if first_run and kind == "t":
			spitters += 1
			if spitters > 1:
				kind = "m"
		# Each themed floor swaps one skeleton in every room for each of its own (see swap).
		if swap.has(spawn_i):
			kind = swap[spawn_i]
		if kind == "K":
			kind = boss_kind()
		# Floor 1 is for learning: never more than one skeleton mage in a wave.
		if kind == "g" and floor_num == 1:
			mages += 1
			if mages > 1:
				kind = "m"
		var e := spawn_enemy(kind, s.pos)
		if _roll_elite(e, index):
			e.make_elite()
		_wave_kinds.append(kind)
		# Twin Wardens: a second boss beside the first, each with 35% less health.
		# Version 164: the last free floor ends with the King and the Lich together (floor 5
		# had the same theme and boss as floor 1 and 2), the same way. Since version 274 the
		# Sandfall Tomb has its own boss (the Sand Pharaoh), so this is only for a floor 5
		# without a place's own boss.
		var duo := e.is_boss and kind == "K" and floor_num == Store.FREE_FLOORS and not first_run \
			and event == "" and not race and not daily and not curses.has("twin")
		if e.is_boss and (curses.has("twin") or duo):
			var twin := spawn_enemy("L" if duo else kind, s.pos + Vector3(2.4, 0, 0))
			e.global_position = s.pos - Vector3(2.4, 0, 0)
			for b: Enemy in [e, twin]:
				b.max_health *= 0.65
				b.health = b.max_health
	# The Queen Hunt's tiers: the Queen's health by tier (her toughness by floor is already in).
	if event == "hunt" and is_instance_valid(boss):
		boss.max_health *= float(Events.tiers()[event_tier - 1].hp)
		boss.health = boss.max_health
	# Version 280: the Free Dive's Tidecaller has 85% of its health (as the Hunt's Tier II), so a
	# player who got there has a fair go: the robot won its first dive with 15 health of 100.
	if dive and is_instance_valid(boss):
		boss.max_health *= DIVE_BOSS_HP
		boss.health = boss.max_health
	if quick and is_instance_valid(boss):
		boss.max_health *= QUICK_BOSS_HP   # version 310: a two-minute run's boss
		boss.health = boss.max_health
	# Champion's Door: a purple elite is waiting.
	if _door.get("kind", "") == "champion":
		for a: Actor in Actor.all:
			if a is Enemy and not (a as Enemy).elite and not (a as Enemy).is_boss and not (a is SkeletonBomber) and not a.dead:
				(a as Enemy).make_elite()
				break
	# Swarm, and each Omen of the Horde: the first wave gets its extra skeletons too.
	var extras := (1 if curses.has("swarm") else 0) + _omen("horde")
	if extras > 0 and not _in_boss_room() and not _wave_kinds.is_empty():
		var spots := _wave_spots(extras)
		for i in spots.size():
			var extra := spawn_enemy(_wave_kinds[i % _wave_kinds.size()], spots[i])
			extra.rotation.y = PI
	_wave_pending = false
	if _in_boss_room() or _wave_kinds.is_empty():
		_wave_total = 1
	else:
		# The first room is gentle (the tutorial's first room is a single wave, so a new
		# player isn't swarmed before the dash lesson); later and deeper rooms get three waves.
		if first_run and index == 0:
			_wave_total = 1
		else:
			_wave_total = 2 if first_run or (index == 0 and floor_num == 1) else (3 if index >= 2 or floor_num > 1 else 2)
	_waves_left = _wave_total - 1
	hud.set_wave(1, _wave_total)
	if is_instance_valid(boss):
		_boss_intro()
	else:
		_set_state(State.PLAYING)
	if alive_enemies == 0:
		room.open_door()
	if race:
		# For the race track: about how many skeletons this room holds (later waves bring one more).
		_race_kills_room = 0
		_race_room_t = 0.0
		_race_goal = maxi(1, alive_enemies * _wave_total + _wave_total - 1)
	if _omen("stalker") > 0 and alive_enemies > 0:
		Stalker.rise_in(room, _omen("stalker"), _in_boss_room())   # v241: the Omen of the Stalker
	_danger_said.clear()
	_boss_turned = false
	_boss_danger = false
	if _door.get("kind", "") == "traps" and alive_enemies > 0:
		TrapHall.lay(room)   # v242: the Trap Hall door
	elif not _in_boss_room() and alive_enemies > 0:
		_lay_floor_danger(room)
	if dive and _in_boss_room():
		_use_dive()
	_checkpoint()
	note_spot()


## Saves the run as it is at the start of this room (or of the next floor, after a boss),
## so it can be continued if the game is closed. Not during the first run or the Queen Hunt.
## `loop_end`: saved on the end-of-loop screen, which CONTINUE comes back to.
func _checkpoint(next_floor := false, loop_end := false) -> void:
	if first_run or race or _side_run() or event == "hunt" or hero == null or hero.dead:
		return
	var h := RunSave.hero_state(hero)
	if next_floor:
		# As _descend heals: 30% back and at least 60% to start the floor (a full heal at the end
		# of a loop). Before, only the 30% was saved, so a closed and continued game started the
		# floor weaker than one played straight through.
		var back := hero.max_health if Loops.loop_end(floor_num) else maxf(hero.max_health * 0.3, hero.max_health * 0.6 - hero.health)
		h.health = minf(hero.max_health, hero.health + back)
	RunSave.write({"floor": floor_num + (1 if next_floor else 0), "room": 0 if next_floor else _room_index,
		"hero_id": hero.hero_id, "hero": h, "taken": _taken.duplicate(), "score": score,
		"rerolls": rerolls + (1 if next_floor and not curses.has("narrow") else 0),   # as _descend adds
		"run_coins": run_coins, "banked": run_coins, "kills": _kills, "time": _run_time, "curses": curses.duplicate(),
		"daily": daily, "daily_date": _daily_date, "practice": _daily_practice, "run_hero": _run_hero_id,
		"heart_bonus": heart_bonus, "omens": omens.duplicate(), "loop_end": loop_end, "seen_rooms": _seen_rooms.duplicate(), "balance": 2,
		"feat_counts": {} if _rep.is_empty() else {"perfect": int(_rep.perfect), "special": int(_rep.special),
			"best_chain": float(_rep.best_chain), "hits": int(_rep.hits),
			# version 158: the run report after CONTINUE kept the hit count but lost the damage
			# and room times ("94 damage in 27 hits"); they carry on now too
			"damage": (_rep.damage as Dictionary).duplicate(), "room_times": (_rep.rooms as Array).duplicate(),
			"dash": int(_rep.dash), "healed": float(_rep.healed)},
		"rooms": [] if next_floor or loop_end else _run.duplicate(true),   # this floor's rooms, to come back to
		"door": _door.duplicate() if not (next_floor or loop_end) or _door.get("kind", "") == "path" else {},
		"curse": "" if next_floor or loop_end else _curse_omen,
		"event": event, "event_id": str(Events.current().get("id", "")) if event != "" else "",
		# version 211: the softer floor 2 after the tutorial, and its gifts' banner, survive CONTINUE
		"after_tutorial": _after_tutorial, "gifts": _gift_names.duplicate()})


## "Floor 3 · Room 2" for the CONTINUE button, or "" when there's no saved run.
func continue_text() -> String:
	var s := RunSave.read()
	if s.is_empty():
		return ""
	if _event_save_stale(s):
		return ""   # a Blood Moon run whose event has ended (the next run replaces it)
	var where := "Floor %d · %s" % [s.floor, "Boss" if s.room >= EASY_ROOMS + MEDIUM_ROOMS + HARD_ROOMS else "Room %d" % (s.room + 1)]
	if s.get("loop_end", false):
		where = "Loop %d cleared" % Loops.loop_of(int(s.floor))
		if not Store.owned() and int(s.floor) <= Store.FREE_FLOORS:
			where = "Floor %d cleared" % int(s.floor)
	if _save_needs_pass(s):
		where += " · Crypt Pass"
	if str(s.get("event", "")) != "":
		return str(Events.ev().name).capitalize() + " · " + where
	return ("Daily Crypt · " if s.daily else "") + where


## A saved Blood Moon run from an event that has since ended.
func _event_save_stale(s: Dictionary) -> bool:
	return str(s.get("event", "")) != "" and (not Events.active()
			or str(Events.current().get("id", "")) != str(s.get("event_id", "")))


## A saved run only the Crypt Pass can carry on (past the free floors, a practice Daily or
## a Pass-only curse). After a refund, CONTINUE opens the Pass screen instead of resuming it.
func _save_needs_pass(s: Dictionary) -> bool:
	if Store.owned() or str(s.get("event", "")) != "":
		return false
	if bool(s.daily):
		return bool(s.practice)
	if s.get("loop_end", false) and int(s.floor) <= Store.FREE_FLOORS:
		return false   # the free end: CONTINUE shows it again, with its Pass offer
	if int(s.floor) > Store.FREE_FLOORS:
		return true
	for c in s.curses:
		if not Curses.available(str(c), false):
			return true
	return false


## CONTINUE on the title screen: back into the saved run, at the start of its room.
func _continue_run() -> void:
	var s := RunSave.read()
	if s.is_empty() or state != State.TITLE:
		return
	if _save_needs_pass(s):
		_open_pass()
		return
	var ev := str(s.get("event", ""))
	if _event_save_stale(s):
		# The event ended while the title was up: its run can't go on.
		RunSave.clear()
		hud._title_continue.visible = false
		hud.tip("%s That run ended with the event." % Events.word("over"), 4.0)
		return
	Sfx.play("click")
	Floors.lobby = false
	first_run = false
	_tutorial_requested = false
	_daily_requested = false
	hud.show_title(false)
	hud.show_armory(false)
	hud.show_pass(false)
	hud.show_daily(false)
	hud.show_hud(true)
	event = ev   # before the run's counters reset, so the Moon Shard counter shows
	event_tier = 1
	_event_done = false
	_reset_run_stats()
	floor_num = int(s.floor)
	_taken = (s.taken as Dictionary).duplicate()
	rerolls = int(s.rerolls)
	score = int(s.score)
	run_coins = int(s.run_coins)
	_kills = int(s.kills)
	_run_time = float(s.time)
	curses = (s.curses as Array).duplicate()
	daily = bool(s.daily)
	_daily_date = str(s.daily_date)
	_daily_practice = bool(s.practice)
	_daily_done = false
	_run_hero_id = str(s.run_hero)
	omens = (s.get("omens", {}) as Dictionary).duplicate()
	_door = (s.get("door", {}) as Dictionary).duplicate()
	_curse_omen = str(s.get("curse", ""))
	# v241: a run saved before the rule Omens may hold Haste or Ash, which are gone.
	for id in omens.keys():
		if Loops.get_omen(str(id)).is_empty():
			omens.erase(id)
	if _curse_omen != "" and Loops.get_omen(_curse_omen).is_empty():
		_curse_omen = "blades"
	vault = Armory.vault_owned(_load_save())
	_update_score_mult()
	heart_bonus = float(s.get("heart_bonus", Armory.heart_bonus(_load_save())))
	# (Coins from the room being replayed were held back when the game started: RunSave.hold_replayed.)
	if hero:
		hero.queue_free()
		hero = null
	_swap_hero(str(s.hero_id))
	RunSave.apply_hero(hero, s.hero)
	if int(s.get("balance", 1)) < 2 and hero.perks.has("multishot"):
		hero.damage /= pow(0.9, hero.perks.multishot)   # Twin Shots used to cut damage 10% a pick
	_seen_rooms = (s.get("seen_rooms", []) as Array).duplicate()
	# The run's PERFECT dodges, specials, best chain and hits carry on, so counted Feats keep
	# their progress. Flawless can't be won on a continued floor: hits taken before the game
	# was closed were never saved.
	var fc: Dictionary = s.get("feat_counts", {})
	if not _rep.is_empty() and not fc.is_empty():
		_rep.perfect = int(fc.get("perfect", 0))
		_rep.special = int(fc.get("special", 0))
		_rep.best_chain = float(fc.get("best_chain", 1.0))
		_rep.hits = int(fc.get("hits", 0))
		_rep.damage = (fc.get("damage", {}) as Dictionary).duplicate()
		_rep.rooms = (fc.get("room_times", []) as Array).duplicate()
		_rep.dash = int(fc.get("dash", 0))
		_rep.healed = float(fc.get("healed", 0.0))
	_continued_floor = floor_num
	_after_tutorial = bool(s.get("after_tutorial", false))
	_gift_names = (s.get("gifts", []) as Array).duplicate()
	# The same rooms as before the game was closed. Building new ones would change the rest
	# of the floor (and of a Daily Crypt) and use up five more rooms each time.
	var rooms: Array = s.get("rooms", [])
	if rooms.size() == EASY_ROOMS + MEDIUM_ROOMS + HARD_ROOMS + 1 and int(s.room) < rooms.size():
		_run = rooms.duplicate(true)
	else:
		_build_run()
	if s.get("loop_end", false):
		_resume_loop_end()
	else:
		_go_to_room(int(s.room))
		_show_gifts()
		hud.tip(((str(Events.ev().name).capitalize() + " run continued: floor %d") if event != "" else "Run continued: floor %d") % floor_num, 3.0, 1.2)
	print("[run] continued floor %d room %d hp %d/%d score %d omens %s door %s" % [floor_num, int(s.room) + 1, hero.health, hero.max_health, score, Loops.names(omens), Doors.describe(_door).get("title", "none")])


## The tutorial explains a skeleton's red swipe circle the first time one shows: step out
## of it in room 1 (before the dash is taught), then once more with the dash. It waits
## while another tip is up, so the room's own lesson isn't covered.
var _swipe_tips := 0

func on_swipe_warning() -> void:
	if not first_run or floor_num != 1 or hud.tip_busy():
		return
	if dash_unlocked():
		if _swipe_tips < 2:
			_swipe_tips = 2
			# version 212 (critic fix #4): a Warrior's red strip often shows at the same time
			hud.tip("Mark filling in? DASH out!", 3.0)
	elif _swipe_tips < 1:
		_swipe_tips = 1
		hud.tip("Mark filling in? Step out!", 3.0)


## The one new thing each first-run room teaches.
func _ftue_room_intro() -> void:
	match ftue_room():
		# Version 169 (teaching review, changes 3 and 4): one short line a room, and the
		# button itself pulses. Room 2 is the dash room: slow arrows, the slow-motion lesson,
		# and the hero can't fall anywhere in the tutorial.
		2:
			hud.tip("NEW: DASH! Flick or tap DASH.", 4.0, 1.8)
			_nudge_left = TUTORIAL_DASH_PULSE
		3:
			hero.special_charge = 1.0
			hud.tip("Star button = special move!", 4.0, 3.5)
		_: hud.tip("", 0.0)


## The camera swings to the boss, which roars, and its name slams onto the screen.
func _boss_intro() -> void:
	_set_state(State.TRANSITION)
	_intro_focus = true
	var b := boss
	await get_tree().create_timer(0.6, true, false, true).timeout
	if not is_instance_valid(b) or state != State.TRANSITION:
		_intro_focus = false
		return
	Sfx.play(b.roar_sound)   # each boss in its own voice (version 251)
	Sfx.play("slam")
	get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): Sfx.play("vo_prepare", 0.8))
	shake(0.5)
	hud.flash(Color(1, 0.3, 0.2), 0.3)
	# Version 278: the card names the boss's place too, now that each place has its own.
	var sub := "Ruler of the %s  ·  floor %d" % [str(Floors.current().get("name", "Crypt")), floor_num]
	if event == "hunt":
		sub = "%s  ·  %s" % [Events.word("hunt"), str(Events.tiers()[event_tier - 1].name)]
	elif event != "":
		sub = Events.word("ruler") if boss_kind() == str(Events.ev().get("boss", "Q")) else Events.word("guardian")
	# Version 238: a boss met again brings an attack it never used before, and says so.
	if b.encore_name() != "":
		sub = "Back with a new attack: %s" % b.encore_name()
	var title := b.display_name()
	if _bosses.size() > 1 and not curses.has("twin"):
		var other: Enemy = _bosses[1] if _bosses[0] == b else _bosses[0]
		if is_instance_valid(other):
			title = "%s & %s" % [b.display_name(), other.display_name()]
			sub = "Together, on floor %d" % floor_num
			if b.encore_name() != "":
				sub = "Together  ·  new attack: %s" % b.encore_name()
			hud.set_boss_name(title)
	hud.show_boss_card(title, sub)
	await get_tree().create_timer(1.8, true, false, true).timeout
	hud.hide_boss_card()
	_intro_focus = false
	await get_tree().create_timer(0.35, true, false, true).timeout
	if state == State.TRANSITION:
		_set_state(State.PLAYING)


## How full the boss health bar is (both bosses together with Twin Wardens).
func boss_bar() -> float:
	var hp := 0.0
	var top := _boss_lost
	for b in _bosses:
		if is_instance_valid(b):
			hp += maxf(0.0, b.health)
			top += b.max_health
	return clampf(hp / top, 0.0, 1.0) if top > 0.0 else 0.0


func spawn_enemy(kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.create(kind, Room.current, pos)
	alive_enemies += 1
	_meet(e)
	# Bloodbats come in flocks of three: two more beside the first.
	if kind == "b" and not _flocking:
		_flocking = true
		for i in 2:
			var off := Vector3(1.1 if i == 0 else -1.1, 0, 0.8)
			var at := Room.current.resolve_move(pos + off, Vector3.ZERO, 0.4) if Room.current else pos + off
			spawn_enemy("b", at)
		_flocking = false
	if e.is_boss:
		_bosses.append(e)
		if not is_instance_valid(boss):
			boss = e
			hud.set_boss_name(e.display_name())
	return e


## Now and then a skeleton is a purple elite. Never in the very first room, and more
## often the deeper you go.
var _wave_elites := 0   # elites rolled in the wave being spawned

var _best_floor_seen := -1

func _roll_elite(e: Enemy, room_index: int) -> bool:
	if e.is_boss or e is SkeletonBomber or (floor_num == 1 and room_index == 0):
		return false
	# Version 298 (deep review fix 6): floor 1 has no surprise elites until the player has
	# reached floor 3 once; a Champion's Door still brings its own.
	if floor_num == 1 and not (curses.has("gilded") or curses.has("hunt")):
		if _best_floor_seen < 0:
			_best_floor_seen = int(_load_save().get_value("stats", "best_floor", 1))
		if _best_floor_seen < 3:
			return false
	# Version 295 (deep review fix 2): it was up to 30% (27% on floor 5), so a deep wave was
	# often half purple and an elite stopped being special. Now 5% on floor 1 up to 12%, and
	# never more than two elites in one wave.
	if _wave_elites >= 2 and not (curses.has("gilded") or curses.has("hunt")):
		return false
	var chance := minf(0.12, 0.05 + 0.0175 * (strength_floor() - 1))
	if curses.has("gilded") or curses.has("hunt"):
		chance *= 2.0
	var yes := _room_rng.randf() < minf(0.6, chance * pow(2.0, _omen("gold")))
	if yes:
		_wave_elites += 1
	return yes


## Points for a kill, before the chain and curse multipliers.
func _kill_points(e: Enemy) -> float:
	var p := float(BOSS_POINTS if e.is_boss else (ELITE_POINTS * (3 if curses.has("hunt") else 1) if e.elite else KILL_POINTS))
	if curses.has("frenzy"):
		p *= 2.0
	if curses.has("swarm"):
		p *= 1.5
	return p


## A skeleton that got away (a Gift Thief): the room stops waiting for it, but it is no kill.
## (Version 244: and the next wave comes, or the room clears, as after a kill. A thief that
## got away last left the room waiting for the watchdog, 1.5 s later.)
func enemy_escaped(e: Enemy) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	note_progress()
	print("[run] %s got away, %d left" % [e.kind_name(), alive_enemies])
	if state != State.PLAYING or _in_boss_room():
		return
	if _waves_left > 0 and not _wave_pending and alive_enemies <= (1 if _wave_kinds.size() <= 4 else 2):
		_wave_pending = true
		_next_wave()
	elif alive_enemies == 0 and _waves_left == 0 and not _wave_pending:
		_finish_room(e.global_position)


func on_enemy_died(e: Enemy) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	note_progress()
	_kills += 1
	record_add("kills", 1)
	if not bench:
		Today.add("kills")   # version 311: today's goals
		if e.elite:
			Today.add("elites")
	if _kills == 1 and first_run:
		Telemetry.step("kill1")
	hud.show_hint("")
	if hero and hero.finisher != "" and not e.is_boss:
		LegendFinish.play(hero.finisher, e.global_position, world, hero)   # version 314: Legend Vault
	if state != State.PLAYING:
		return
	if _omen("graves") > 0 and not e.is_boss:
		GraveSpikes.mark(e.global_position, _omen("graves"))   # v241: the Omen of Graves
	if race and not e.is_boss:
		_race_kill(e)
	if event != "" and e is GiftThief:
		_add_shards(GiftThief.SHARDS)   # its sack of stolen gifts (Frostfall)
		EventArt.shard_pop(e.global_position + Vector3(0, 1.2, 0), GiftThief.SHARDS)
	if event != "" and not e.is_boss:
		var in_surge := surge > 0.5 or Blizzard.blowing()   # v243: a Blizzard pays like a Surge
		var n := (Events.ELITE_SHARDS if e.elite else 0) + (Events.SURGE_SHARDS if in_surge else 0)
		if in_surge and hero and (hero.perks.has("shardhunter") or hero.perks.has("gifthunter")):
			n += 2   # Shard Hunter, Gift Hunter (Frostfall)
		if in_surge and hero and hero.perks.has("eclipse_heart") and not hero.dead:
			hero.heal(1.0)   # Eclipse Heart
		if n > 0:
			_add_shards(n)
			EventArt.shard_pop(e.global_position + Vector3(0, 1.2, 0), n)
	# Kills close together build a combo, and the combo feeds the Bone Chain.
	if _combo_left <= 0.0:
		_combo = 0
		chain = 1.0
	_combo += 1
	record_max("best_combo", _combo)
	_combo_left = chain_time()
	if hero and not hero.dead and hero.perks.has("blood_rush") and chain >= CHAIN_FULL - 0.01:
		hero.heal(hero.max_health * 0.01)   # Blood Rush (a Vault card, v219)
	var before := chain
	# Grave Pact: only kills right after a dash grow the chain (others still keep it alive).
	if chain_unlocked() and (not curses.has("gravepact") or (hero and hero.dashed_recently())):
		chain = minf(chain_max(), chain + (0.3 if e.elite else 0.1))
	score += roundi(_kill_points(e) * chain * _score_mult)
	_feat_check()
	# Ossuary: hitting Chain x2 recharges a Bone Ward.
	if before < 2.0 and chain >= 2.0 and hero and hero.perks.has("ossuary") and hero.ward < hero.ward_max:
		hero.ward += 1
		Fx.magic(hero.center(), Color(0.8, 0.9, 1.0), 20)
		hud.callout("WARD!", Color(0.85, 0.92, 1.0), true)
	hud.show_chain(chain)
	if hero:
		hero.add_charge(0.3 if e.elite else 0.1)
	if chain >= 1.5 and chain_unlocked():
		_teach("chain", "CHAIN! Kill fast to hit harder.")
	if hero and special_unlocked() and hero.special_ready():
		_teach("special", "Star button ready: tap it for a special move!")
	if before < chain_max() and chain >= chain_max():
		Sfx.play("vo_combo", 0.8)
	if not _rep.is_empty():
		_rep.best_combo = maxi(_rep.best_combo, _combo)
		_rep.best_chain = maxf(_rep.best_chain, chain)
		_rep.room_chain = maxf(_rep.room_chain, chain)
	if e.is_boss:
		_bosses.erase(e)
		_boss_lost += e.max_health
		_bosses = _bosses.filter(func(b): return is_instance_valid(b) and not b.dead)
		if not _bosses.is_empty():
			# Twin Wardens: one down, one to go.
			boss = _bosses[0]
			hud.set_boss_name(boss.display_name())
			hud.callout("ONE DOWN!", Color(1, 0.6, 0.4), true)
			print("[run] one boss down, %d to go" % _bosses.size())
			return
		# Any minions left crumble with their master, even ones still climbing out of the floor
		# or swimming under the water (those used to be left standing on the victory screen).
		for a: Actor in Actor.all.duplicate():
			if a != e and a is Enemy and not a.dead:
				(a as Enemy).crumble()
		_win()
	elif not _in_boss_room() and _waves_left > 0 and not _wave_pending and alive_enemies <= (1 if _wave_kinds.size() <= 4 else 2):
		_wave_pending = true
		_next_wave()
	elif alive_enemies == 0 and not _in_boss_room() and _waves_left == 0 and not _wave_pending:
		_finish_room(e.global_position)


func _finish_room(at: Vector3) -> void:
	if bench:
		return   # the SPEED TEST's room never ends
	if _cleared_serial == _room_serial:
		return
	_cleared_serial = _room_serial
	finisher(at, 0.25, 0.6)
	_clear_enemy_attacks()
	Pickup.collect_all()
	_room_cleared()


## A skeleton was hit or killed: the room is moving.
func note_progress() -> void:
	_stall_time = 0.0
	_stall_step = 0


## Where a skeleton that ended up out of reach climbs back in: the free wave spot nearest
## to where it was (still well away from the hero).
func rescue_spot(from: Vector3, in_sight := false) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for p in _wave_spots(40):
		if in_sight and hero and not Room.current.clear_shot(hero.global_position, p):
			continue   # version 180: a skeleton moved out of cover must be one the hero can shoot
		var d: float = from.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best


## Makes sure every fight room can end. If a wave was never sent or the last skeleton died
## without clearing the room, it does so. If nothing has been hit for 20 seconds, any
## skeleton the hero can't reach is moved into the open; after 40 seconds the rest crumble.
func _room_watchdog(delta: float) -> void:
	if Room.current == null or Room.current.door_open or _in_boss_room() or _cleared_serial == _room_serial or _wave_total == 0:
		return
	if alive_enemies <= 0 and not _wave_pending:
		_no_enemies_time += delta
		if _no_enemies_time > 1.5:
			_no_enemies_time = 0.0
			if _waves_left > 0:
				print("[watchdog] wave %d was never sent; sending it" % (_wave_total - _waves_left + 1))
				_wave_pending = true
				_next_wave()
			else:
				print("[watchdog] room had no skeletons left but never cleared; clearing it")
				_finish_room(hero.global_position if hero else Vector3.ZERO)
		return
	_no_enemies_time = 0.0
	# Version 163 (Tweaks report #4): only a hero who stands (and so shoots) and still hits
	# nothing counts as stuck. Heroes don't shoot while moving, so one who kept running got
	# the room crumbled for them after 40 s, with full coins.
	if hero == null or not hero._moving:
		_stall_time += delta
	if _stall_time > 20.0 and _stall_step == 0:
		_stall_step = 1
		for a: Actor in Actor.all.duplicate():
			if a is Enemy and not a.dead and not (a as Enemy).is_boss and not _reachable(a as Enemy):
				print("[watchdog] %s out of reach for 20 s; moving it" % (a as Enemy).kind_name())
				report_stuck(a as Enemy, hero, 0.0, true, "out of reach 20 s, moved")
				a.global_position = rescue_spot(a.global_position)
	elif _stall_time > 40.0 and _stall_step == 1:
		_stall_step = 2
		var n := 0
		for a: Actor in Actor.all.duplicate():
			if a is Enemy and not a.dead and not (a as Enemy).is_boss:
				if n == 0:
					report_stuck(a as Enemy, hero, 0.0, true, "nothing hit for 40 s, room crumbled")
				(a as Enemy).crumble()
				n += 1
		print("[watchdog] nothing hit for 40 s; %d skeletons crumbled" % n)
		if n == 0:
			# The count of living skeletons drifted from the real number: end the room anyway.
			alive_enemies = 0
			if _waves_left <= 0:
				_finish_room(hero.global_position if hero else Vector3.ZERO)


## True when the hero could shoot this skeleton from somewhere: it stands in the open,
## inside the walls and clear of pillars.
func _reachable(e: Enemy) -> bool:
	return Room.current.is_walkable(e.global_position, e.radius)


## The next wave climbs out of the floor away from the hero, after a short warning.
func _next_wave() -> void:
	var wave := _wave_total - _waves_left + 1
	hud.banner("Wave %d" % wave, Color(1, 0.55, 0.4))
	hud.set_wave(wave, _wave_total)   # the counter agrees with the banner at once
	Sfx.play("warn")
	_wave_elites = 0
	var kinds := _wave_kinds.duplicate()
	U.shuffle(kinds, _room_rng)
	# Later waves bring one extra skeleton (two with the Swarm rule, and one per Omen of the Horde).
	# Version 168: not in the tutorial, where new players took 1-3 minutes a room.
	if not first_run:
		kinds.append(kinds[0])
	if curses.has("swarm"):
		kinds.append(kinds[1 % kinds.size()])
	for i in _omen("horde"):
		kinds.append(kinds[(2 + i) % kinds.size()])
	# First run, room 2: there's always an archer, so the dash lesson has arrows to teach with.
	if ftue_room() == 2 and not kinds.has("a"):
		kinds[0] = "a"
	_one_spitter(kinds)
	if floor_num == 1:
		var first := kinds.find("g")
		for i in kinds.size():
			if kinds[i] == "g" and i != first:
				kinds[i] = "m"
	var spots := _wave_spots(kinds.size())
	for p in spots:
		Fx.dust(p, 10)
	await get_tree().create_timer(0.8, false).timeout
	if state != State.PLAYING or Room.current == null:
		_wave_pending = false
		return
	# One skeleton a frame: each is a full 3D model, and building a whole wave in one frame
	# was a visible hitch on phones. They still climb out of the floor together.
	var serial := _room_serial
	for i in mini(kinds.size(), spots.size()):
		if i > 0:
			await get_tree().process_frame
			if state == State.DEAD or _room_serial != serial or not is_instance_valid(Room.current):
				break
		var e := spawn_enemy(kinds[i], spots[i])
		if _roll_elite(e, _room_index):
			e.make_elite()
	_waves_left -= 1
	_wave_pending = false
	hud.set_wave(wave, _wave_total)


## Free floor spots at least 4.5 away from the hero, spread around the room.
## Version 168: Bone Spitters dealt the most damage in the tutorial deaths of real new
## players (75 and 68 of their health). The tutorial has at most one a wave.
func _one_spitter(kinds: Array) -> void:
	if not first_run:
		return
	var first := kinds.find("t")
	for i in kinds.size():
		if kinds[i] == "t" and i != first:
			kinds[i] = "m"


func _wave_spots(count: int) -> Array:
	var room := Room.current
	var spots := []
	for row in Layouts.ROWS:
		for col in Layouts.COLUMNS:
			var p := Room.cell_to_world(col, row)
			if absf(p.x) > Room.HALF_W - 1.0 or absf(p.z) > Room.HALF_L - 1.2:
				continue
			if room.blocks_shot(p, 0.7):
				continue
			if hero and p.distance_to(hero.global_position) < 4.5:
				continue
			spots.append(p)
	spots.shuffle()
	return spots.slice(0, count)


func _room_cleared() -> void:
	if not _rep.is_empty() and floor_num >= 2:
		if _run_time - float(_rep.room_start) < 10.0:
			_feat("rusher")
		if int(_rep.hits) == _room_hits:
			_feat("untouched")
	_report_room_done("F%dR%d" % [floor_num, _room_index + 1])
	if race and _race and not _race.over:
		_race.legs = _room_index + 1
		_race.leg_frac = 0.0
	_add_bones(BoneRoad.ROOM_BONES)
	_add_shards(Events.ROOM_SHARDS)
	_add_mastery(HeroMastery.ROOM_POINTS, true)
	_save_coins()
	hud.set_wave(0, 0)
	# Straight to the blessing cards once the slow-motion finish has played. The wait stops
	# while the game is paused, so pausing here (II, Back, leaving the app) only delays the
	# cards instead of losing them.
	var serial := _room_serial
	await get_tree().create_timer(0.75, false, false, true).timeout
	if state != State.PLAYING or serial != _room_serial:
		return
	var step := ftue_room()
	# The door picked before this room shapes the blessings after it.
	_pick_family = str(_door.get("family", ""))
	_pick_better = _door.get("kind", "") == "champion"
	# Version 242: the room doors pay out once their room is won.
	match str(_door.get("kind", "")):
		"traps":
			if hero and not hero.dead:
				print("[run] trap hall won: full heal from %d" % roundi(hero.health))
				hero.heal(hero.max_health)
				Fx.magic(hero.center(), Color(0.5, 1.0, 0.6), 30)
				if _mastery_callout == "":
					_mastery_callout = "TRAP HALL WON: full heal!"
		"dark":
			_extra_pick = true
			if _mastery_callout == "":
				_mastery_callout = "DARK ROOM WON: pick two blessings!"
	_door = {}
	_pick_rng = Curses.daily_rng(500 + floor_num * 10 + _room_index, _daily_date) if daily or race else null
	_choices = Upgrades.roll_first(_taken) if step == 1 else Upgrades.roll(_taken, 2 if curses.has("narrow") else 3, step == 4, _pick_family, _pick_better, _pick_rng)
	var lv_line := _mastery_callout
	_mastery_callout = ""
	# Version 170: the first gold card says what a synergy is.
	if lv_line == "" and not first_run and not taught("synergy") and _choices.any(func(c): return str(c.get("rarity", "")) == "synergy"):
		mark_taught("synergy")
		lv_line = "GOLD CARD: two of your blessings join into a SYNERGY!"
		print("[teach] " + lv_line)
	if _choices.is_empty():
		Pickup.grant_all()
		_save_coins()
		enter_next_room()
		if lv_line != "":
			hud.banner(lv_line.get_slice("\n", 0), Color(1.0, 0.82, 0.3))
		return
	_set_state(State.UPGRADE)
	get_tree().paused = true
	hud.clear_banner()
	hud.show_cards(_choices, rerolls if step >= 3 else 0, step >= 2, lv_line, _taken)


## One free reroll per run swaps all three cards.
func _on_reroll() -> void:
	if state != State.UPGRADE or rerolls <= 0 or ftue_room() < 3:
		return
	rerolls -= 1
	if _pick_rng == null:
		Upgrades.note_reroll(_choices)
	_choices = Upgrades.roll(_taken, 2 if curses.has("narrow") else 3, false, _pick_family, _pick_better, _pick_rng)
	Sfx.play("click")
	hud.show_cards(_choices, rerolls, true, null, _taken)


func _on_card_picked(i: int) -> void:
	if state != State.UPGRADE or i >= _choices.size():
		return
	var u: Dictionary = _choices[i]
	Upgrades.note_pick(_choices, u)   # v219 (review 4 fix 33): passed-over commons rest
	_taken[u.id] = _taken.get(u.id, 0) + 1
	Upgrades.apply(u.id, hero)
	_feat_check()
	_pick_family = ""
	_pick_better = false
	_picked = u
	Sfx.play("upgrade")
	# Version 242: a won Dark Room gives a second pick straight after the first.
	if _extra_pick:
		_extra_pick = false
		_choices = Upgrades.roll(_taken, 2 if curses.has("narrow") else 3, false, "", false, _pick_rng)
		if not _choices.is_empty():
			print("[run] dark room: second pick after %s" % u.id)
			hud.show_cards(_choices, rerolls, true, "DARK ROOM: pick one more blessing!", _taken)
			return
	# Then two doors to the next room (still paused), except in the first run.
	_doors = _door_offer()
	if not _doors.is_empty():
		hud.show_doors(_doors.map(func(d): return Doors.describe(d, rerolls)), _room_index + 2 >= _run.size())
		return
	_leave_room()


## The two doors after this room's blessing. The Daily Crypt offers everyone the same ones.
func _door_offer() -> Array:
	if first_run or _room_index + 1 >= _run.size():
		return []
	var rng := RandomNumberGenerator.new()
	if daily or race:
		rng = Curses.daily_rng(300 + floor_num * 10 + _room_index, _daily_date)
	else:
		rng.randomize()
	var full := not (daily or race) and hero != null and hero.health >= hero.max_health * 0.9
	return Doors.offer(rng, _room_index + 2 >= _run.size(), not curses.has("narrow"), _taken, full)


func _on_door_picked(i: int) -> void:
	if state != State.UPGRADE or i >= _doors.size():
		return
	_door = _doors[i]
	_doors = []
	Sfx.play("door", 0.7)
	match str(_door.kind):
		"spring":
			hero.heal(hero.max_health * Doors.SPRING_HEAL)
		"shrine":
			rerolls += 1
		"cursed":
			_curse_omen = str(_door.get("omen", "blades"))
	print("[run] door: %s%s" % [Doors.describe(_door).title, (" (%s)" % _curse_omen) if _curse_omen != "" else ""])
	_leave_room()


## After the blessing (and the door): anything left on the floor is picked up and the
## next room starts. No walk to the door.
func _leave_room() -> void:
	get_tree().paused = false
	_set_state(State.PLAYING)
	if not _picked.is_empty():
		Fx.magic(hero.center(), Upgrades.color(_picked), 30)
		hud.banner(_picked.title, Upgrades.color(_picked))
		_picked = {}
	var before := coins
	Pickup.grant_all()
	# The room clear already saved; save again only if coins were still on the floor (or
	# Bone Road / Mastery points came in since). Saves are slow on cheap phones' storage.
	if coins != before or _road_unsaved > 0 or _mastery_unsaved > 0:
		_save_coins()
	enter_next_room()


## Removes skeleton arrows and warning markers still in the air once a fight is over.
func _clear_enemy_attacks() -> void:
	if Room.current == null:
		return
	for n in Room.current.get_children():
		if n is Projectile and (n as Projectile).owner_team == Actor.Team.UNDEAD:
			(n as Projectile).finish()   # back to the shot pool (version 126)
		elif n is FirePatch:
			n.queue_free()
		elif n is Telegraph:
			(n as Telegraph).cancel()


## After the slow-motion finish on a boss: the camera moves in on the hero, who celebrates in
## their own way (their emote, a burst in their colour) and says one of their "win" lines
## (version 129; from version 122 to 128 everyone did the same cheer, mostly hidden by the
## end screen a moment later). The end screen waits CELEBRATE seconds for it.
const CELEBRATE := 1.8
## True from the boss's fall until the end screen shows: taps don't descend yet.
var _celebrating := false

func _celebrate() -> void:
	if hero == null or not is_instance_valid(hero) or hero.dead or state != State.VICTORY:
		return
	var h := Heroes.get_hero(hero.hero_id)
	if hero.visual:
		hero.visual.emote(h.get("emote", ["Cheer"]))
	Fx.magic(hero.center() + Vector3.UP * 0.6, h.ring, 18)
	Fx.shockwave(hero.global_position, h.ring, 2.2)
	_zoom_point = hero.global_position
	_zoom_hold = CELEBRATE + 0.4
	hud.hero_says("win")


func _win() -> void:
	if race:
		_race_finish_line()
		return
	var boss_name := boss.display_name() if is_instance_valid(boss) else "The boss"
	var where := boss.global_position if is_instance_valid(boss) else hero.global_position
	_boss_feats()
	_report_room_done("F%d Boss" % floor_num)
	Today.add("bosses")   # version 311 (banked with the coins just below)
	if quick:
		Today.add("quick")
	_set_state(State.VICTORY)
	finisher(where, 0.2, 1.0, Color(1, 0.5, 0.3))
	_clear_enemy_attacks()
	Pickup.collect_all()
	hud.hide_boss()
	_celebrating = true
	await get_tree().create_timer(1.0, true, false, true).timeout
	_celebrate()
	await get_tree().create_timer(0.2, true, false, true).timeout
	Pickup.grant_all()   # coins still flying to the hero count, and are saved
	_save_coins()
	Sfx.play("victory")
	Sfx.play("vo_win", 0.8)
	# The hero's moment before the end screen covers them (version 129).
	await get_tree().create_timer(CELEBRATE - 0.2, true, false, true).timeout
	var cfg := _load_save()
	# A floor's boss beaten for the first time (not in the Daily Crypt): worth sharing,
	# unless it's the tutorial.
	var prev_boss := _best_boss(cfg)
	_share_reason = "boss" if not daily and event == "" and not first_run and not _side_run() and floor_num > prev_boss else ""
	_note_floor_one(cfg, true)
	if not daily and event == "" and not _side_run() and floor_num > prev_boss:
		cfg.set_value("stats", "best_boss", floor_num)
	# The event: shards for the boss, the Queen's fall counted, a hunt's win saved (the day's
	# first on a tier pays a Moon Casket too), and a casket for every Blood Moon run cleared.
	var hunt := {}
	_event_done = event == "hunt" or (event == "run" and floor_num >= Events.RUN_FLOORS)
	if event != "":
		if boss_kind() == str(Events.ev().get("boss", "Q")):
			cfg.set_value(Events.section(), "queen_kills", Events.queen_kills(cfg) + 1)
		if event == "hunt":
			hunt = Events.record_hunt(cfg, event_tier)
			_add_shards(int(hunt.shards))
			var el: Array = Events.top_look()
			if event_tier == Events.tiers().size() and not Events.has_look(cfg, el[0], el[1]):
				Events.give_look(cfg, el[0], el[1])
				hunt.eclipse_look = true
			if hunt.casket:
				_caskets_run += 1
		elif _event_done:
			_add_shards(Events.QUEEN_SHARDS)
			if Events.claim_run_casket(cfg):   # version 216: once a day
				_caskets_run += 1
		else:
			_add_shards(Events.BOSS_SHARDS)
	var shards := _bank_shards(cfg)
	cfg.set_value("stats", "wins", int(cfg.get_value("stats", "wins", 0)) + 1)
	# Version 217 (review 3 fix #2): in the Queen Hunt only the day's first win (the one with
	# the Hunt casket) pays a Bone Drop; it paid one per 1-2 minute fight with no cap.
	# Version 310: Quick Play pays one on the day's first QUICK_DROPS wins only (a two-minute
	# win every time would be the fastest Bone Drops in the game).
	if quick:
		if _quick_drop(cfg):
			_earn_drop(cfg)
	elif event != "hunt" or bool(hunt.get("casket", false)):
		_earn_drop(cfg)   # every boss beaten, the tutorial's too (saved just below)
	# Version 218: a repeat Hunt win (no casket) pays a third of the bones and Mastery too;
	# both ladders pay Bone Drops, so full pay kept the drop farm open.
	var repeat_hunt := event == "hunt" and not bool(hunt.get("casket", false))
	_add_bones(roundi(BoneRoad.BOSS_BONES / 3.0) if repeat_hunt else BoneRoad.BOSS_BONES)
	var boss_points := roundi(HeroMastery.BOSS_POINTS / 3.0) if repeat_hunt else HeroMastery.BOSS_POINTS
	# Version 306 (player panel fix 1): the tutorial win promises Mastery level 2, but its two
	# rooms and the boss came to 14 of the 20 points. The tutorial boss tops the hero up to level 2.
	if first_run and hero:
		var have := HeroMastery.points(cfg, hero.hero_id) + _mastery_unsaved
		boss_points = maxi(boss_points, int(HeroMastery.LEVELS[1]) - have)
	_add_mastery(boss_points)
	var bones := _bank_bones(cfg)
	var mastery := _bank_mastery(cfg)
	var best := _save_score(cfg)
	_save_best(cfg, _run.size())
	var heroic_new := prev_boss < Curses.unlock_boss("heroic") and Curses.unlocked("heroic", cfg)
	# The floor-1 win that opens the Crypt Race says so, once.
	var race_new := floor_num == 1 and not race and not daily and event == "" and Race.unlocked(cfg) \
		and Race.stat(cfg, "races") == 0 and not bool(cfg.get_value(Race.SECTION, "told", false))
	if race_new:
		cfg.set_value(Race.SECTION, "told", true)
	# Curse mastery: beating the floor 5 boss (or a deeper one) at a Curse Level.
	var rewards := []
	if not daily and event == "" and floor_num >= Store.FREE_FLOORS and Curses.level_of(curses) > 0 and hero:
		rewards = Curses.record_mastery(cfg, hero.hero_id, Curses.level_of(curses))
	write_save(cfg)
	var was_first := first_run
	if was_first:
		Telemetry.step("won")
		_after_tutorial = true
		# Version 211 (Tweaks report #1): the gifts are given here, before _checkpoint(true)
		# saves the run, so a player who goes to the title and presses CONTINUE keeps them too.
		_tutorial_gifts()
	_finish_first_run()
	first_run = false   # from here it's a normal run: saved, with doors and each floor's own skeletons
	Music.play("dungeon")
	_daily_done = daily and floor_num >= Curses.DAILY_FLOORS
	_free_end = not daily and event == "" and not _side_run() and floor_num >= Store.FREE_FLOORS and not Store.owned()
	if _free_end:
		Telemetry.step("free_end_seen")   # v219 (review 4 fix 22): how many reach the Pass offer
	_dive_done = dive
	if _dive_done:
		Telemetry.step("dive_won")
	_quick_done = quick
	_loop_choice = not daily and event == "" and not _side_run() and not _free_end and Loops.loop_end(floor_num)
	if _side_run():
		pass   # the Free Dive and Quick Play save nothing, and a saved run stays as it was
	elif _daily_done or _event_done:
		RunSave.clear()
	elif _loop_choice or _free_end:
		# At the free end the run is kept too: a Pass bought later (a pending payment, or
		# after going back to the title) carries it on from here.
		_checkpoint(false, true)
	else:
		_checkpoint(true)
	var day_bonus := _claim_day_bonus() if _daily_done or _free_end else 0
	var extra := "  (+%d first run today)" % day_bonus if day_bonus > 0 else ""
	if was_first:
		extra += "\n\nHeroes and the Armory are open:\nfind them on the title screen."
	elif _daily_done:
		extra += "\n\nDaily Crypt #%d cleared!%s" % [Curses.day_number(_daily_date), " (Practice)" if _daily_practice else ""]
	elif event == "hunt":
		extra += "\n\n%s %s won!%s" % [Events.word("hunt"), str(Events.tiers()[event_tier - 1].name), ("  +1 %s (today's Hunt %s)" % [Events.word("casket"), Events.word("casket").get_slice(" ", 1).to_lower()]) if hunt.get("casket", false) else ""]
		if hunt.get("eclipse_look", false):
			extra += "\nNew glow: %s! Wear it in Style." % Events.word("top")
	elif _event_done:
		extra += "\n\n" + Events.word("fallen") + (("  +1 %s (today's)" % Events.word("casket")) if _caskets_run > 0 else "")
	elif _loop_choice:
		extra += "\n\n" + _loop_text()
	elif _quick_done:
		extra += "\n\n" + _quick_text(cfg)
	extra += _today_lines()
	for m: Dictionary in rewards:
		extra += "\n\nNew reward for the %s: %s!" % [Heroes.get_hero(hero.hero_id).title, m.title]
	if race_new:
		extra += "\n\nCRYPT RACE unlocked! Race a rival through the same crypt.\nFind it in MODES."
	if heroic_new:
		extra += "\n\nHEROIC unlocked! Harder runs, +50% coins.\nTurn it on in MODES, then CURSES."
	_celebrating = false
	hud.hero_quiet()   # the bubble would show through the end screen
	var tap := "Tap to return to the title" if _daily_done or _event_done or _dive_done else "Tap to descend to floor %d" % (floor_num + 1)
	if _quick_done:
		tap = "Tap for another Quick Play"
	if _event_done and Events.active():
		tap = Hud.EVENT_TAP   # v221: a green BACK TO EVENT (the road and the next Hunt)
	if shards > 0:
		extra = "\n%s  +%d" % [Events.word("shards"), shards] + extra
	var fallen := "%s has fallen." % boss_name if event == "hunt" or quick else "%s of floor %d has fallen." % [boss_name, floor_num]
	if quick:
		fallen = "QUICK PLAY WON!\n" + fallen
	# Version 213 (hardest review fix #18): at the end of the free game, what the Pass opens
	# comes first (it was the last line, ~3.6 s after the counts).
	if _free_end:
		fallen = _free_end_text() + "\n\n" + fallen
	elif _dive_done:
		fallen = _dive_text(true)
	var offer := _free_end or (_dive_done and not Store.owned())
	hud.end_hide_best = _side_run()
	hud.show_end(true, true, "%s\n\nTime  %s\nSkeletons destroyed  %d\nCoins this run  %d%s\nBone Road  +%d bones%s" % [fallen, _format_time(_run_time), _kills, run_coins, _heroic_tag(), bones, extra],
		tap, false, score, best, offer)
	if _dive_done:
		hud.set_offer_back("BACK TO TITLE")   # (nothing of the dive is saved)
	# The hero and the rings at their feet would show between the end screen's buttons
	# (as YOU DIED hides them); they come back as the next room starts (place_at).
	if hero:
		hero.visible = false
	hud.show_mastery(mastery)
	# Version 122: once, after the first boss win past the tutorial, the Pass card shows the
	# hero in the Crypt King set (a win is when the set means most).
	# Version 213 (hardest review fix #18): the end of the free game always shows the card (it
	# was hidden exactly there).
	if _free_end or (_dive_done and not Store.owned()):
		hud.show_pass_card(true, pass_hero_def())
	elif not Store.owned() and not was_first and not daily and event == "":
		var pcfg := _load_save()
		if not bool(pcfg.get_value("shown", "pass_card_win", false)):
			pcfg.set_value("shown", "pass_card_win", true)
			write_save(pcfg)
			hud.show_pass_card(true, pass_hero_def())
	hud.show_end_title(not _daily_done and not _free_end and not _event_done and not _dive_done, "TITLE" if quick else "TITLE  (RUN SAVED)")
	hud.show_end_loop(_loop_choice, _bank_bonus(), Loops.loop_of(floor_num) + 1)
	if _daily_done:
		hud.set_end_goal(_daily_goal())
	elif event != "":
		hud.set_end_goal(_event_goal())
	hud.set_drops(Drops.waiting(_load_save()))
	_show_share_card()
	_state_time = 0.0
	var won := "Beat floor %d%s" % [floor_num, " (end of the free game)" if _free_end else (" (Daily Crypt cleared)" if _daily_done else (" (the Free Dive)" if dive else (" (Quick Play)" if quick else "")))]
	if event == "hunt":
		won = "Won the %s %s (event day %d)" % [Events.word("hunt"), str(Events.tiers()[event_tier - 1].name), Events.day()]
	elif event != "":
		won = "%s run: beat floor %d of %d (event day %d)" % [str(Events.ev().name).capitalize(), floor_num, Events.RUN_FLOORS, Events.day()]
	_last_report = run_report(won, was_first)
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)
	_reveal_feats_soon()
	# Version 142 (review fix 10): not on the tutorial's win screen; the title asks at the
	# next launch instead (_ask_reports_on_title), once the first win is behind them.
	if not was_first:
		_ask_reports()
	_ask_review(was_first)


func on_hero_died() -> void:
	if state == State.DEAD or state == State.VICTORY:
		return
	if race:
		_race_end(false)   # (a racer is knocked down, not killed: this is only a safety net)
		return
	_set_state(State.DEAD)
	if not _side_run():
		RunSave.clear()
	var brave := _brave_coins()
	if brave > 0:
		add_coins(brave)
		hud.set_coins(coins)
	_save_coins()
	Sfx.play("vo_lose", 0.8)
	await get_tree().create_timer(0.9, true, false, true).timeout   # (1.4 s before version 164)
	var cfg := _load_save()
	# A Bone Drop for getting somewhere: room 3 or further, or any deeper floor. Not in the
	# tutorial (its win gives the first one). Never for losing a Queen Hunt (version 218: the
	# Hunt sets floor_num to its tier's floor, so every quick loss paid a drop).
	# (Version 280: in the Free Dive only room 3 or further, or a fall in room 1 paid one each time.)
	if not first_run and event != "hunt" and not quick and (_room_index >= 2 or (floor_num > 1 and not dive)):
		_earn_drop(cfg)   # (version 310: never for a Quick Play fall, only its wins)
	var bones := _bank_bones(cfg)
	var shards := _bank_shards(cfg)
	var mastery := _bank_mastery(cfg)
	var best := _save_score(cfg)
	_note_floor_one(cfg, false)
	_save_best(cfg, _room_index + 1)
	write_save(cfg)
	var was_first := first_run
	if was_first and not bool(cfg.get_value("stats", "first_run_done", false)):
		Telemetry.step("died%d_%s" % [int(cfg.get_value("stats", "tutorial_deaths", 0)) + 1, _step_room()])
	_share_reason = "best" if not daily and event == "" and not _side_run() and not was_first and score > best and score > 0 else ""
	var day_bonus := _claim_day_bonus()
	var tutorial_again := first_run and _tutorial_retry()
	if not tutorial_again:
		_finish_first_run()
	var where := "the throne room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]
	if quick:
		where = "Quick Play, " + where
	if event == "hunt":
		where = "the %s (%s)" % [Events.word("hunt"), str(Events.tiers()[event_tier - 1].name).capitalize()]
	elif floor_num > 1:
		where += " on floor %d" % floor_num
	# (The brave-try top-up has its own line below, so "Coins kept" is what the run found.)
	var coin_line := "You earned %d coins.\nSpend them in the Armory!" % run_coins if was_first else "Coins kept  %d%s" % [run_coins - brave, _heroic_tag()]
	if day_bonus > 0:
		coin_line += "  (+%d first run today)" % day_bonus
	if brave > 0:
		coin_line += "\nBrave try  +%d coins" % brave
	if bones > 0:
		coin_line += "\nBone Road  +%d bones" % bones
	if shards > 0:
		coin_line += "\n%s  +%d" % [Events.word("shards"), shards]
	coin_line += _today_lines()
	if tutorial_again:
		coin_line = "You keep the %d coins for the Armory,\nwhich opens after the tutorial.\nYou start again in this room." % run_coins
	# Free players who got deep hear about the Pass once a session, never mid-run.
	var note := not Store.owned() and floor_num >= 3 and event == "" and (not _pass_note_shown or dive)
	if note:
		_pass_note_shown = true
	var why := death_tip()
	print("[death tip] " + why.replace("\n", " / "))
	if why != "":
		why = "\n\n" + why
	var again := not tutorial_again
	if dive:
		why = "\n\n" + _dive_text(false) + why
		again = dive_ready()   # TRY AGAIN only while the Free Dive is still there
	hud.end_hide_best = _side_run()
	hud.show_end(true, false, "You fell in %s.%s\n\nTime  %s\nSkeletons destroyed  %d\n%s" % [where, why, _format_time(_run_time), _kills, coin_line],
		"Tap to try again" if again or not dive else "Tap to return to the title", again, score, best)
	hud.show_mastery(mastery)
	hud.set_retry_floor(_retry_floor() if again else 1)
	if again and _retry_floor() > 1:
		_save_start_floor(_retry_floor())   # the title starts there next time too (its button can change it)
	hud.show_end_title(true)
	hud.set_end_goal(_daily_goal() if daily else (_event_goal() if event != "" else next_goal()))
	hud.set_drops(Drops.waiting(_load_save()))
	_show_share_card()
	if note:
		hud.show_pass_card(true, pass_hero_def())   # version 122: a card with the hero in the set
	_state_time = 0.0
	_last_report = run_report("Died on floor %d, %s" % [floor_num, "boss room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]])
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)
	_reveal_feats_soon()
	_ask_reports()


func _on_pause_pressed() -> void:
	if state == State.PLAYING:
		_pause()


func _pause() -> void:
	_save_coins()
	_state_before_pause = state
	_set_state(State.PAUSED)
	get_tree().paused = true
	hud.show_pause(true)


func _resume() -> void:
	away = false   # (a safety net: a tap on RESUME means the player is here)
	hud.show_pause(false)
	get_tree().paused = false
	_set_state(_state_before_pause)


func _set_state(s: int) -> void:
	state = s
	_state_time = 0.0
	if hud and (s == State.DEAD or s == State.TITLE):
		hud.hero_quiet()
	if s != State.PLAYING:
		Engine.time_scale = 1.0
		_hit_stop_left = 0.0


func _fade(from: float, to: float, seconds: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_method(hud.set_fade, from, to, seconds)
	await tw.finished


# ---------------------------------------------------------------- saving

func _load_save() -> ConfigFile:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err == OK and cfg.has_section_key("saved", "complete"):
		return cfg
	# save.cfg is missing its end mark (cut off mid-write, or written by an older version)
	# or unreadable: the last good copy is the better bet, if there is one.
	var bak := ConfigFile.new()
	if FileAccess.file_exists(SAVE_BACKUP) and bak.load(SAVE_BACKUP) == OK:
		if not _save_fell_back:
			_save_fell_back = true
			print("[save] save.cfg unreadable or cut off (error %d): using save.cfg.bak" % err)
			if Telemetry.instance:
				Telemetry.instance.catch_error("save.cfg was cut off (error %d); restored the backup" % err)
		return bak
	return cfg


## Writes save.cfg safely: the new file is written beside it and then swapped in, keeping
## the last good one as save.cfg.bak, so a crash or a flat battery mid-write can't wipe
## coins, heroes or the Armory. The "saved" section goes last and marks a complete file.
static func write_save(cfg: ConfigFile) -> void:
	if bench:
		return   # the SPEED TEST changes nothing
	if cfg.has_section("saved"):
		cfg.erase_section("saved")
	cfg.set_value("saved", "complete", true)
	_merge_records(cfg)
	TrustClock.note(cfg, Curses.day_start_now())
	var tmp := SAVE_PATH + ".tmp"
	if cfg.save(tmp) != OK:
		push_error("couldn't write " + tmp)
		return
	_rec_add.clear()
	_rec_max.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(SAVE_PATH, SAVE_BACKUP)
	DirAccess.rename_absolute(tmp, SAVE_PATH)
	Store.note_saved(cfg)


# ---------------------------------------------------------------- records

## Lifetime records for the RECORDS screen (runs, skeletons, time played, best combo...).
## They're counted as they happen and added to the save with its next write, so a busy
## room never writes the save on every kill.
const RECORDS := "records"
static var _rec_add := {}
static var _rec_max := {}


static func record_add(key: String, n: float) -> void:
	_rec_add[key] = float(_rec_add.get(key, 0.0)) + n


static func record_max(key: String, v: int) -> void:
	if v > int(_rec_max.get(key, 0)):
		_rec_max[key] = v


## A record as saved plus what's counted since the last write.
static func record(cfg: ConfigFile, key: String) -> float:
	return float(cfg.get_value(RECORDS, key, 0.0)) + float(_rec_add.get(key, 0.0))


static func record_best(cfg: ConfigFile, key: String) -> int:
	return maxi(int(cfg.get_value(RECORDS, key, 0)), int(_rec_max.get(key, 0)))


static func _merge_records(cfg: ConfigFile) -> void:
	if not cfg.has_section_key(RECORDS, "since"):
		# Saves from before version 79 played without counting: the screen says from when.
		var played := int(cfg.get_value("stats", "best_room", 0)) > 0 or int(cfg.get_value("stats", "wins", 0)) > 0
		cfg.set_value(RECORDS, "since", Time.get_date_string_from_system() if played else "")
	for k: String in _rec_add:
		cfg.set_value(RECORDS, k, float(cfg.get_value(RECORDS, k, 0.0)) + float(_rec_add[k]))
	for k: String in _rec_max:
		cfg.set_value(RECORDS, k, maxi(int(cfg.get_value(RECORDS, k, 0)), int(_rec_max[k])))


func _open_records() -> void:
	if state != State.TITLE:
		return
	Sfx.play("click")
	var cfg := _load_save()
	var perfect := _perfect_total if _perfect_total >= 0 else int(cfg.get_value("stats", "perfect_total", 0))
	var dailies := 0
	if cfg.has_section("daily"):
		for k: String in cfg.get_section_keys("daily"):
			if k.ends_with("_official"):
				dailies += 1
	# A fresh save shows "-" for the floor and the combo, not "1" and "x0".
	var played := roundi(record(cfg, "runs")) > 0 or int(cfg.get_value("stats", "best_score", 0)) > 0
	var combo := record_best(cfg, "best_combo")
	var rows := [
		["Best score", Hud.thousands(int(cfg.get_value("stats", "best_score", 0)))],
		["Deepest floor", str(int(cfg.get_value("stats", "best_floor", 1))) if played else "-"],
		["Bosses defeated", Hud.thousands(int(cfg.get_value("stats", "wins", 0)))],
		["Runs played", Hud.thousands(roundi(record(cfg, "runs")))],
		["Skeletons destroyed", Hud.thousands(roundi(record(cfg, "kills")))],
		["Time in the crypt", _long_time(record(cfg, "time"))],
		["Best combo", "x%d" % combo if combo > 0 else "-"],
		["Perfect dodges", Hud.thousands(perfect)],
		["Coins found", Hud.thousands(roundi(record(cfg, "coins")))],
		["Daily Crypts played", str(dailies)],
		["Bone Drops opened", Hud.thousands(int(cfg.get_value(Drops.SECTION, "opened", 0)))],
		["Daily Crypt streak", "%d day%s" % [Curses.streak(cfg), "" if Curses.streak(cfg) == 1 else "s"]],
	]
	var since := str(cfg.get_value(RECORDS, "since", ""))
	var note := ""
	if since.length() == 10:
		const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		var m := clampi(since.substr(5, 2).to_int(), 1, 12)
		note = "Runs, skeletons, time, combo and coins\nare counted from %s %d, %s." % [MONTHS[m - 1], since.substr(8, 2).to_int(), since.substr(0, 4)]
	hud.show_records(true, rows, note)


## "2h 05m" or "12m 30s".
static func _long_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%dm %02ds" % [s / 60, s % 60]


## One Bone Drop earned, into `cfg` (the caller saves it). At most Drops.MAX_PER_RUN a run.
func _earn_drop(cfg: ConfigFile) -> void:
	if _drops_run >= Drops.MAX_PER_RUN:
		return
	_drops_run += 1
	Drops.add(cfg)


func _add_bones(n: int) -> void:
	_road_unsaved += n
	_road_shown += n


## Unsaved Bone Road bones into `cfg` (the caller saves it). Returns the bones earned since
## the last end screen, for this one to show.
func _bank_bones(cfg: ConfigFile) -> int:
	BoneRoad.add(cfg, _road_unsaved)
	_road_unsaved = 0
	var n := _road_shown
	_road_shown = 0
	return n


## Moon Shards (events.gd), boosted on double days and with the Crypt Pass. Shown on the
## HUD as they come in.
func _add_shards(n: int) -> void:
	if event == "" or n <= 0 or bench:
		return
	var k := Events.boosted(n, Store.owned())
	_shards_unsaved += k
	_shards_shown += k
	hud.set_shards(_shards_shown)


## Unsaved Moon Shards into `cfg` (the caller saves it). Returns the shards since the last
## end screen.
func _bank_shards(cfg: ConfigFile) -> int:
	Events.add_shards(cfg, _shards_unsaved)
	_shards_unsaved = 0
	var n := _shards_shown
	_shards_shown = 0
	return n


## The gold line on an event's end screens: how far to the next event road prize.
func _event_goal() -> String:
	var cfg := _load_save()
	var i := Events.next_index(cfg)
	if Events.ready_count(cfg) > 0:
		return "Event road: %d prize%s to claim!" % [Events.ready_count(cfg), "" if Events.ready_count(cfg) == 1 else "s"]
	if i >= Events.road().size():
		var bl := Events.bonus_line(cfg)   # v218: says "tomorrow" once today's is paid
		return "Event road complete! " + bl.left(1).to_upper() + bl.substr(1)
	return "Event road: %d more %s to %s" % [int(Events.road()[i].at) - Events.shards(cfg), Events.word("unit"), Events.step_text(Events.road()[i])]


## Starts the Blood Moon run ("run") or the Queen Hunt ("hunt") on tier `tier`, from the
## event screen.
func start_event(kind: String, tier := 1) -> void:
	if state != State.TITLE or not Events.active():
		return
	_event_requested = kind
	_event_tier_requested = tier
	hud.show_event(false)
	_start_run()


## Version 135: the big splash, once when an event begins and once at each new chapter,
## shown on the title a moment after it appears (and not over another screen).
func _maybe_event_splash(force := false) -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	var e := Events.current()
	# Version 306 (player panel fix 1): not before the third run (it was the first title after
	# the tutorial, a full-screen story before the player had seen floor 2).
	if e.is_empty() or unlock_stage() < CALM_RUNS or state != State.TITLE or not hud.title_visible() or hud.covers_world():
		return
	var cfg := _load_save()
	var c := Events.chapter(e)
	var seen := int(cfg.get_value(Events.section(e), "splash", 0))
	if seen >= c + 1 and not force:
		return
	cfg.set_value(Events.section(e), "splash", c + 1)
	write_save(cfg)
	var ch: Dictionary = Events.chapter_info(e)
	var clock := "Ends in %s" % Events.time_text(Events.seconds_left(e))
	if seen == 0:
		# The event's first splash: its name, the story, and the chapter on now.
		hud.show_event_splash("THE EVENT HAS BEGUN", str(e.name), "CHAPTER %d  ·  %s\n%s" % [c + 1, ch.name, ch.text],
				str(e.story), "%d days  ·  %s" % [int(e.days), clock], Events.eclipse(e))
	else:
		hud.show_event_splash("%s  ·  CHAPTER %d" % [e.name, c + 1], str(ch.name), str(ch.text), "", clock, Events.eclipse(e))


## Version 135: an event that ended pays out what was left on it, with a note on the title.
func _settle_events() -> void:
	var cfg := _load_save()
	var r := Events.settle(cfg)
	if r.is_empty():
		return
	coins += int(r.coins)
	cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	record_add("coins", r.coins)
	hud.set_coins(coins)
	var parts := []
	if int(r.prizes) > 0:
		parts.append("%d road prize%s" % [r.prizes, "" if int(r.prizes) == 1 else "s"])
	if int(r.caskets) > 0:
		parts.append("%d %s" % [r.caskets, r.casket if int(r.caskets) == 1 else r.casket_n])
	hud.tip("The %s is over.\nYou hadn't claimed %s: +%d coins" % [str(r.name).capitalize(), " and ".join(parts), int(r.coins)], 6.0, 1.2)
	hud.set_drops(Drops.waiting(_load_save()))


func _open_event() -> void:
	if state == State.TITLE and (Events.active() or not Events.coming().is_empty()):
		hud.show_event(true)


## Claims event road step `i` (events.gd), like the Bone Road's.
func _claim_event_road(i: int) -> void:
	var cfg := _load_save()
	# v219 (review 4 fix 26): the road's Crypt Pass row (EventScreen.PASS_INDEX + step)
	var on_pass := i >= EventScreen.PASS_INDEX
	var s := Events.claim_pass(cfg, i - EventScreen.PASS_INDEX) if on_pass else Events.claim(cfg, i)
	if s.is_empty():
		return
	if s.kind == "coins":
		coins += int(s.n)
		cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	if s.kind == "coins":
		record_add("coins", s.n)
	hud.set_coins(coins)
	Sfx.play("upgrade")
	if s.kind == "look":
		Sfx.play("sting", 0.9)
		hud.callout("%s: %s!" % [Events.word("pass_set" if on_pass else "set").to_upper(), Events.step_text(s)], Color(0.8, 0.88, 1.0) if on_pass else Events.ev().color.lightened(0.15))
		hud.refresh_looks_badge()   # (Version 192: the new look shows on the Style button)
	else:
		Sfx.play("coin", 0.6, 1.2)
	print("[event road] claimed %d: %s" % [i, Events.step_text(s)])
	hud.set_drops(Drops.waiting(_load_save()))
	hud.refresh_event()


func _open_caskets() -> void:
	if state in [State.TITLE, State.DEAD, State.VICTORY]:
		var n := Events.caskets(_load_save())
		if n > 0:
			Sfx.play("click")
			hud.open_caskets(n, _open_one_casket)


## Opens one Moon Casket and gives what's inside (the drop screen shows it).
func _open_one_casket() -> Dictionary:
	var cfg := _load_save()
	var r := Events.open_casket(cfg)
	if r.is_empty():
		return r
	if int(r.coins) > 0:
		coins += int(r.coins)
		cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	if int(r.coins) > 0:
		record_add("coins", r.coins)
	hud.set_coins(coins)
	print("[casket] %s %s" % [r.name, str(r.text).replace("\n", " ")])
	hud.refresh_looks_badge.call_deferred()
	return r


## The Moon Surge, run every frame (_process).
func _update_surge(delta: float) -> void:
	var fighting := event != "" and Floors.blood_moon() and state == State.PLAYING and not _in_boss_room() and alive_enemies > 0
	if not fighting:
		if surge > 0.0 or _surge_on:
			surge = move_toward(surge, 0.0, delta * 1.5)
			if surge <= 0.0:
				_surge_on = false
			_show_surge(false)
		return
	_surge_t += delta
	var t := fmod(_surge_t, SURGE_EVERY + SURGE_TIME)
	var on := t >= SURGE_EVERY
	var warn := t >= SURGE_EVERY - SURGE_WARN and not on
	if on and not _surge_on:
		_surge_on = true
		hud.callout("BLOOD MOON SURGE!", Color(1.0, 0.3, 0.25))
		Sfx.play("roar", 0.7)
		shake(0.35)
		buzz(60)
	elif not on:
		_surge_on = false
	surge = move_toward(surge, 1.0 if on else 0.0, delta * (2.5 if on else 1.2))
	_show_surge(warn)


func _show_surge(warn: bool) -> void:
	hud.set_surge(surge, warn)
	if _moon:
		_moon.light_energy = _moon_energy * (1.0 + 0.7 * surge)


func _end_surge() -> void:
	surge = 0.0
	_surge_t = 0.0
	_surge_on = false
	if hud:
		hud.set_surge(0.0, false)
		hud.set_surge(0.0, false, true)
		hud.set_shards(-1)


## True while the room's fight is still on: skeletons standing, or waves still to come.
func fight_on() -> bool:
	return alive_enemies > 0 or _waves_left > 0 or _wave_pending


## Version 241 (whole-game review fix 12), the Omen of Night (and from version 242 the Dark
## Room door): the room's own light nearly goes out and the hero's lantern becomes the light of the room, so skeletons come out of the
## dark (their eyes, shots and every warning on the floor still glow). Darkness: Light (the
## comfort setting) keeps more of the room's light.
const NIGHT_AMBIENT := 0.08
const NIGHT_SUN := 0.05
const NIGHT_LANTERN := 2.4
const NIGHT_RANGE := 6.0   # it hangs 3.6 m up, so it lights about 4.8 m of floor round the hero


func _night_light() -> void:
	var night: bool = _omen("night") > 0 or _door.get("kind", "") == "dark"   # v242: the Dark Room
	if hero and hero.lantern:
		hero.lantern.light_energy = NIGHT_LANTERN if night else Hero.LANTERN_ENERGY
		hero.lantern.omni_range = NIGHT_RANGE if night else Hero.LANTERN_RANGE
	if not night or _env == null:
		return
	var keep := 2.0 if light_dark else 1.0
	_env.ambient_light_energy *= minf(1.0, NIGHT_AMBIENT * keep)
	_moon_energy *= minf(1.0, NIGHT_SUN * keep)
	if _moon:
		_moon.light_energy = _moon_energy


## The Blood Moon Queen's Eclipse: the moon goes dark (the room's light dims) and comes back.
const ECLIPSE_AMBIENT := 0.2   # v219 review: 0.35 + the darker v219 floor grid made it -58%
var _eclipse_k := 0.0
var _eclipse_eff := 0.0   # v219: how dark it really is (Darkness: Light dims a third as much)
var _eclipse_tw: Tween


func set_eclipse(on: bool) -> void:
	if _eclipse_tw:
		_eclipse_tw.kill()
	# Version 217 (review 3 fix #7): a lighter Eclipse (ambient -35%, moon -70%; it was -55%
	# and -85% under a 0.35 black veil, and the room went nearly black in every Queen fight).
	var amb := _env.ambient_light_energy / maxf(1.0 - ECLIPSE_AMBIENT * _eclipse_eff, 0.01)
	_eclipse_tw = create_tween()
	var dim := 0.33 if light_dark else 1.0   # v219: Darkness: Light
	_eclipse_tw.tween_method(func(k: float):
		_eclipse_k = k
		k *= dim
		_eclipse_eff = k
		if _moon:
			_moon.light_energy = _moon_energy * (1.0 - 0.45 * k)   # v219 review: was 0.7
		_env.ambient_light_energy = amb * (1.0 - ECLIPSE_AMBIENT * k)
		hud.set_surge(k * 0.7, false, true), _eclipse_k, 1.0 if on else 0.0, 0.6)


## Skeletons walk faster in a Moon Surge (enemy.gd walk).
func surge_mult() -> float:
	return 1.0 + 0.4 * surge


## Hero Mastery points for this run's hero, saved with the coins like the bones.
func _add_mastery(n: int, callout := false) -> void:
	if hero == null:
		return
	if hero.hero_id != _mastery_hero and _mastery_unsaved > 0:
		_save_coins()   # (never happens mid-run, but points always go to the hero who earned them)
	_mastery_hero = hero.hero_id
	var before := HeroMastery.points(_load_save(), hero.hero_id) + _mastery_unsaved
	_mastery_unsaved += n
	_mastery_shown += n
	_mastery_run += n
	# A level reached in the middle of a run gets its moment straight away: a gold burst and a
	# chime as the room ends, then a gold line over the blessing cards (the rewards themselves
	# come with the end screen). A boss's level-up is the end screen's to show.
	var lv := HeroMastery.level_for(before + n)
	if callout and lv > HeroMastery.level_for(before):
		_mastery_callout = "%s MASTERY %d!\n%s" % [str(Heroes.get_hero(hero.hero_id).title).to_upper(), lv,
			HeroMastery.level_text(lv, hero.hero_id)]
		Sfx.play("upgrade", 0.8, 1.0 + 0.04 * lv)
		Fx.magic(hero.center(), Color(1.0, 0.82, 0.3), 30)


## Saves this run's unsaved mastery points into `cfg`, gives the rewards of any level reached
## (coins straight into the purse) and returns what the end screen shows: {id, name, color,
## before, after, gained, levels} (see Hud.show_mastery), or {} with no hero.
func _bank_mastery(cfg: ConfigFile) -> Dictionary:
	var id := _mastery_hero if _mastery_hero != "" else (hero.hero_id if hero else "")
	if id == "":
		return {}
	HeroMastery.add(cfg, id, _mastery_unsaved)
	_mastery_unsaved = 0
	var gained := _mastery_shown
	_mastery_shown = 0
	var after := HeroMastery.points(cfg, id)
	var g := _give_mastery(cfg, id)
	var def := HeroStyle.styled(cfg, Heroes.get_hero(id))
	return {"id": id, "name": def.title, "color": def.ring, "before": after - gained, "after": after, "gained": gained, "levels": g.levels}


## Gives the rewards of levels reached since the last time into `cfg` (the caller saves it).
func _give_mastery(cfg: ConfigFile, id: String) -> Dictionary:
	var g := HeroMastery.grant(cfg, id)
	if int(g.coins) > 0:
		coins += int(g.coins)
		cfg.set_value("stats", "coins", coins)
		record_add("coins", g.coins)
		hud.set_coins(coins)
	for l: Dictionary in g.levels:
		print("[mastery] %s level %d: %s" % [id, l.level, HeroMastery.level_text(l.level, id)])
	return g


## Back on the title after leaving a run mid-way (or the end screen): levels reached on the
## way that weren't given yet are given here. Returns the note to show on the title ("").
func _give_mastery_on_title() -> String:
	_mastery_shown = 0
	if _mastery_hero == "":
		return ""
	var cfg := _load_save()
	var g := _give_mastery(cfg, _mastery_hero)
	if g.levels.is_empty():
		return ""
	write_save(cfg)
	var last: Dictionary = g.levels[-1]
	return "%s MASTERY %d!\n%s" % [Heroes.get_hero(_mastery_hero).title.to_upper(), last.level,
		" + ".join(g.levels.map(func(l): return HeroMastery.level_text(l.level, _mastery_hero)))]


func _title_hero_line(id: String, trial := false) -> void:
	var cfg := _load_save()
	hud.set_title_hero(Heroes.full_name(Heroes.get_hero(id)) + (" (free trial run)" if trial else ""), HeroMastery.level(cfg, id), HeroMastery.has_frame(cfg, id))


func _open_road() -> void:
	if state == State.TITLE:
		Sfx.play("click")
		hud.open_road(_load_save())


func _claim_road(i: int) -> void:
	var cfg := _load_save()
	var s := BoneRoad.claim(cfg, i)
	if s.is_empty():
		return
	if s.kind == "coins":
		coins += int(s.n)
		cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	if s.kind == "coins":
		record_add("coins", s.n)
	hud.set_coins(coins)
	Sfx.play("upgrade")
	Sfx.play("coin", 0.6, 1.2)
	if s.has("prize"):   # (v254: the road's last prize, a look found nowhere else)
		hud.callout("NEW %s AURA!" % str(HeroStyle.extra(s.prize[0], s.prize[1]).name).to_upper(), Color(1.0, 0.85, 0.55))
	print("[road] claimed %d: %s" % [i, BoneRoad.reward_text(s)])
	hud.open_road(_load_save())


func _open_drops() -> void:
	if state in [State.TITLE, State.DEAD, State.VICTORY]:
		Sfx.play("click")
		hud.open_drops(Drops.waiting(_load_save()), _open_one_drop)


## Opens one waiting Bone Drop and gives what's inside (the drop screen shows it).
func _open_one_drop() -> Dictionary:
	var cfg := _load_save()
	var r := Drops.open(cfg)
	if r.is_empty():
		return r
	if int(r.coins) > 0:
		coins += int(r.coins)
		cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	if int(r.coins) > 0:
		record_add("coins", r.coins)
	hud.set_coins(coins)
	print("[drop] %s %s" % [r.name, str(r.text).replace("\n", " ")])
	return r


func _drops_closed() -> void:
	hud.set_drops(Drops.waiting(_load_save()))
	hud.refresh_event()
	if state == State.TITLE and hud.title_visible():
		hud.show_title(true, _best_text(), coins)


func add_coins(n: int) -> void:
	coins += n
	run_coins += n
	record_add("coins", n)
	if not bench:
		Today.add("coins", n)   # version 311
	hud.set_coins(coins)


# ---------------------------------------------------------------- Feats

## Feats that can happen any moment in a run: counted in one run (perfect dodges, specials,
## kills, the chain, blessings, the score).
func _feat_check() -> void:
	if first_run or _rep.is_empty():
		return
	# Version 218: the floor Feats need a real floor. The Queen Hunt sets floor_num to its
	# tier's floor (2-6), so Quick Feet and Chain Lord came from one Hunt fight.
	# (Version 280: the Free Dive's floor 6 counts as the floor 3 it is as strong as.)
	var fl := strength_floor() if event == "" else 0
	if int(_rep.perfect) >= 15 and fl >= 3:
		_feat("dodger")
	if int(_rep.perfect) >= 40:
		_feat("perfectionist")
	if _kills >= 150:
		_feat("centurion")
	if fl >= 4:
		_best_chain4 = maxf(_best_chain4, chain)
		if chain >= 2.999:
			_feat("chainlord")
	if score >= 20000:
		_feat("highscore")
	var held := 0
	for k in _taken:
		held += int(_taken[k])
	if held >= 12:
		_feat("blessed")


## Feats for a boss beaten (called before anything else in _win).
func _boss_feats() -> void:
	if first_run or _rep.is_empty() or not hero:
		return
	var cfg := _load_save()
	var no_hit := int(_rep.hits) == _room_hits
	# Version 217 (review 3 fix #3): the floor Feats need a normal run. The Queen Hunt sets
	# floor_num to its tier's floor, so one Hunt fight gave "Beat the boss of floor 5".
	var normal := event == "" and not _side_run()   # (v280: the Free Dive's floor 6 isn't one reached; v310 nor Quick Play's)
	if normal and floor_num >= 3 and _run_time - float(_rep.room_start) < 30.0:
		_feat("bossbreaker", cfg)
	var specials := int(_rep.special) - _room_special
	Feats.note_best(cfg, "boss_special", specials)
	if specials >= 4:
		_feat("specialist", cfg)
	if no_hit:
		_feat("cleankill", cfg)
	if normal and floor_num != _continued_floor and int(_rep.hits) == _floor_hits:
		_feat("flawless", cfg)
	if hero.health <= hero.max_health * 0.15:
		_feat("laststand", cfg)
	if normal and floor_num >= 3 and not daily:
		_feat("halfway", cfg)
	if normal and floor_num >= 5 and not daily:
		_feat("conqueror", cfg)
	if daily and not _daily_practice and floor_num >= Curses.DAILY_FLOORS:
		_feat("dailywin", cfg)
	cfg.set_value(Feats.SECTION, "won_" + hero.hero_id, true)
	_feat_account(cfg)
	write_save(cfg)


## Feats kept across runs (the Daily streak, a boss with every hero, Mastery 10), and the
## best counts towards the counted Feats, for the Feats screen. Into `cfg` (saved by the caller).
func _feat_bests(cfg: ConfigFile) -> void:
	if not _rep.is_empty() and not first_run:
		var fl := strength_floor() if event == "" else 0   # v218 (and v280's Free Dive): see _feat_check
		Feats.note_best(cfg, "perfect", int(_rep.perfect))
		if fl >= 3:
			Feats.note_best(cfg, "perfect3", int(_rep.perfect))
		Feats.note_best(cfg, "chain_hold", int(_best_chain_hold))
		if fl >= 4:
			Feats.note_best(cfg, "chain4", roundi(_best_chain4 * 10.0))
		Feats.note_best(cfg, "special", int(_rep.special))
		Feats.note_best(cfg, "kills", _kills)
		Feats.note_best(cfg, "chain", roundi(maxf(float(_rep.best_chain), chain) * 10.0))
		Feats.note_best(cfg, "score", score)
		var held := 0
		for k in _taken:
			held += int(_taken[k])
		Feats.note_best(cfg, "blessings", held)
	_feat_account(cfg)


func _feat_account(cfg: ConfigFile) -> void:
	var streak := Curses.streak(cfg)
	Feats.note_best(cfg, "streak", streak)
	if streak >= 7:
		_feat("faithful", cfg)
	var won := 0
	var top := 0
	for h: Dictionary in Heroes.LIST:
		if bool(cfg.get_value(Feats.SECTION, "won_" + str(h.id), false)):
			won += 1
		top = maxi(top, HeroMastery.level(cfg, h.id))
	Feats.note_best(cfg, "heroes", won)
	Feats.note_best(cfg, "mastery", top)
	if won >= 4:
		_feat("fourheroes", cfg)
	if top >= 10:
		_feat("legend", cfg)


## Feat `id` done: saved (into `cfg` when given, the caller saves; otherwise now), with a
## gold toast naming the look it gave.
func _feat(id: String, cfg: ConfigFile = null) -> void:
	if _feats_got.get(id, false) or (first_run and state != State.TITLE):
		return
	_feats_got[id] = true
	var f: Dictionary
	if cfg == null and state == State.PLAYING:
		# Mid-fight: the toast now, the save at the end of the room (_save_coins). Feats already
		# won were put in _feats_got at the run's start, so no save file is read on a kill frame.
		f = Feats.get_feat(id)
		_feats_unsaved.append(id)
	else:
		var own := cfg == null
		if own:
			cfg = _load_save()
		f = Feats.complete(cfg, id)
		if f.is_empty():
			return
		if own:
			write_save(cfg)
	if state != State.TITLE:
		_feats_run.append(id)
	report_event("feat")
	hud.feat_toast(str(f.name), Feats.reward_label(f))
	if vibration:
		Input.vibrate_handheld(40)


## Feats done mid-fight go into `cfg` (the caller saves).
func _flush_feats(cfg: ConfigFile) -> void:
	for id in _feats_unsaved:
		Feats.complete(cfg, id)
	_feats_unsaved.clear()
	for k in _taught_unsaved:   # (version 283: tips learned mid-fight, mark_taught)
		cfg.set_value("taught", k, true)
	_taught_unsaved.clear()


func _save_coins() -> void:
	var cfg := _load_save()
	_bank_today(cfg)   # version 311: before the coins, which a finished goal adds to
	cfg.set_value("stats", "coins", coins)
	_flush_feats(cfg)
	BoneRoad.add(cfg, _road_unsaved)
	_road_unsaved = 0
	Events.add_shards(cfg, _shards_unsaved)   # (the end screen shows _shards_shown)
	_shards_unsaved = 0
	HeroMastery.add(cfg, _mastery_hero, _mastery_unsaved)
	_mastery_unsaved = 0
	_feat_bests(cfg)   # after the Mastery points, so Legend sees the new level
	if _perfect_total >= 0:
		cfg.set_value("stats", "perfect_total", _perfect_total)
	write_save(cfg)
	if state != State.TITLE and not race and not _side_run():
		RunSave.bank(run_coins)   # (v280: a race or the Free Dive set a saved run's coins to its own)


func _set_music(on: bool, save := true) -> void:
	Music.set_enabled(on)
	hud.set_toggles(Music.enabled, Sfx.enabled)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "music", on)
		write_save(cfg)


func _set_sounds(on: bool, save := true) -> void:
	Sfx.enabled = on
	hud.set_toggles(Music.enabled, Sfx.enabled)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "sounds", on)
		write_save(cfg)


## Screen shake: 2 full, 1 reduced (a third as strong), 0 off.
func _set_shake(level: int, save := true) -> void:
	level = clampi(level, 0, 2)
	shake_scale = [0.0, 0.35, 1.0][level]
	hud.set_shake_label(level)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "shake", level)
		write_save(cfg)


## Version 219 (review 4 fix 32): the comfort settings.
func _set_flashes(level: int, save := true) -> void:
	level = clampi(level, 0, 2)
	flash_scale = [0.0, 0.3, 1.0][level]
	hud.set_flashes_label(level)
	_save_setting("flashes", level, save)


func _set_left_hand(on: bool, save := true) -> void:
	hud.set_left_hand(on)
	_save_setting("left_hand", on, save)


func _set_button_size(level: int, save := true) -> void:
	level = clampi(level, 0, 2)
	hud.set_button_size(level)
	_save_setting("button_size", level, save)


func _set_darkness(light: bool, save := true) -> void:
	light_dark = light
	hud.set_darkness_label(light)
	if _eclipse_k > 0.0 and save:
		set_eclipse(true)   # v220: changed mid-Eclipse, it takes effect now
	_save_setting("darkness_light", light, save)


func _save_setting(key: String, value: Variant, save: bool) -> void:
	if save:
		Sfx.play("click")
		var cfg := _load_save()
		cfg.set_value("settings", key, value)
		write_save(cfg)


## The short buzz when the hero is hit.
## A short buzz when Vibration is on (version 122: PERFECT, Phase 2, level ups, rewards).
func buzz(ms: int) -> void:
	if Game.vibration:
		Input.vibrate_handheld(ms)


func _set_colorblind(on: bool, save := true) -> void:
	colorblind = on
	hud.set_colorblind_label(on)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "colorblind", on)
		write_save(cfg)


func _set_vibration(on: bool, save := true) -> void:
	vibration = on
	hud.set_vibration_label(on)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "vibration", on)
		write_save(cfg)


## Send reports on or off, from Settings or the pause menu. Off also deletes any reports
## still waiting on the phone.
func _set_reports(on: bool) -> void:
	var cfg := _load_save()
	cfg.set_value("settings", "reports", on)
	write_save(cfg)
	hud.set_reports_label(on, Telemetry.configured())
	if not on and Telemetry.instance:
		Telemetry.instance.clear_queue()   # nothing waiting goes out after a no
	Sfx.play("click")


## Version 143: phone reminders (PhoneReminders), off until the player says yes.
func _set_reminders(on: bool) -> void:
	var cfg := _load_save()
	if on:
		PhoneReminders.enable(cfg)
	else:
		PhoneReminders.disable(cfg)
	write_save(cfg)
	PhoneReminders.refresh(cfg)
	hud.set_reminders_label(on)
	if on:
		hud.tip("Reminders on: at most one a day, in the evening.", 3.0, 0.3)
	Sfx.play("click")


## Back in the game (after Android's notification question, or the phone's settings): say
## so if reminders are on but the phone blocks them, once per change.
var _rem_blocked_said := false
func _check_reminders_allowed() -> void:
	var cfg := _load_save()
	var blocked := PhoneReminders.blocked(cfg)
	hud.set_reminders_label(PhoneReminders.on(cfg), blocked)
	if blocked and not _rem_blocked_said and state != State.PLAYING:
		hud.tip("Your phone is blocking Bone Chain's reminders. Allow notifications for Bone Chain in the phone's Settings.", 5.0, 0.3)
	_rem_blocked_said = blocked


## Asked once, on the title after a boss win that wasn't the tutorial's (the player knows
## the game by then), or from the third run while an event is near (v306). Never on
## top of the reports question, a splash or a menu.
func _ask_reminders_on_title() -> void:
	var cfg := _load_save()
	if PhoneReminders.asked(cfg) or first_run_pending():
		return
	var wins := int(cfg.get_value("stats", "wins", 0))
	var event_near := not Events.current().is_empty() or not Events.coming().is_empty()
	if wins < 2 and not (event_near and wins >= 1 and unlock_stage(cfg) >= CALM_RUNS) and not "remindask" in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(2.2, true, false, true).timeout
	if state != State.TITLE or not hud.title_visible() or hud.covers_world() or hud.reports_ask_visible() \
			or hud.settings_visible() or hud.feedback_visible() or _load_save().has_section_key("settings", PhoneReminders.KEY):
		return
	if Telemetry.configured() and not _load_save().has_section_key("settings", "reports"):
		return   # the reports question comes first; this one waits for the next title
	cfg = _load_save()
	cfg.set_value("settings", PhoneReminders.ASKED, true)   # asked once, whatever the answer
	write_save(cfg)
	var e := Events.current() if not Events.current().is_empty() else Events.coming()
	hud.show_reminders_ask(true, "" if e.is_empty() else str(e.name).capitalize())


## Reports are off until the player says yes. The game asks once: on the title after the
## opening scene (below), or a moment after a run ends if that question was skipped by
## starting a run, unless they've already chosen in the pause menu.
func _ask_reports() -> void:
	if not Telemetry.configured() or _load_save().has_section_key("settings", "reports"):
		return
	# Version 116: not before the first boss win (a new player's first screen used to be an
	# 80-word data question). After that, any run's end can ask. Version 306: and not before
	# the third run either (it came at the end of the first run after the tutorial).
	if int(_load_save().get_value("stats", "wins", 0)) <= 0 or unlock_stage() < CALM_RUNS:
		return
	await get_tree().create_timer(1.6, true, false, true).timeout
	if state in [State.DEAD, State.VICTORY] and not hud.armory_visible() and not hud.pass_visible() and not hud.heroes_visible() \
			and not hud.drops_visible() and not _load_save().has_section_key("settings", "reports"):
		hud.show_reports_ask(true)


## Google Play's rating card: a moment after a boss win past the tutorial (a happy moment,
## never after a death). Not while the reports question is still waiting, so the two never
## pile up; the next boss win asks instead.
## Version 171: asked up to REVIEW_MAX times, at least REVIEW_GAP_DAYS apart (it used to be
## once ever, so everyone asked during open testing, when reviews stay private, would never
## be asked again after the public launch). Google still decides whether the card shows.
const REVIEW_MAX := 3
const REVIEW_GAP_DAYS := 21

func _ask_review(was_first: bool) -> void:
	var cfg := _load_save()
	# Version 217 (review 3 fix #5): never at the end of the free floors, where the Crypt
	# Pass offer is (a star rating asked at the paywall invites angry reviews).
	if was_first or _free_end or not _review_due(cfg):
		return
	if Telemetry.configured() and not cfg.has_section_key("settings", "reports"):
		return
	await get_tree().create_timer(2.5, true, false, true).timeout
	if state != State.VICTORY or (UpdateGate.instance and UpdateGate.instance.showing()):
		return
	if "autoplay" in OS.get_cmdline_user_args():
		print("[review] would ask for a rating now (floor %d, ask %d)" % [floor_num, int(cfg.get_value("stats", "review_n", 0)) + 1])
		return
	if UpdateGate.ask_review():
		cfg = _load_save()
		cfg.set_value("stats", "review_asked", true)
		cfg.set_value("stats", "review_n", int(cfg.get_value("stats", "review_n", 0)) + 1)
		cfg.set_value("stats", "review_at", int(Time.get_unix_time_from_system()))
		cfg.set_value("stats", "review_build", BUILD)
		write_save(cfg)


## Whether a boss win now may bring up the rating card.
static func _review_due(cfg: ConfigFile) -> bool:
	var n := int(cfg.get_value("stats", "review_n", 0))
	if n == 0 and bool(cfg.get_value("stats", "review_asked", false)):
		# Asked once before version 171 (on a test build): count that ask from now, so the
		# next one comes REVIEW_GAP_DAYS later.
		n = 1
		cfg.set_value("stats", "review_n", 1)
		cfg.set_value("stats", "review_at", int(Time.get_unix_time_from_system()))
		write_save(cfg)
	if n >= REVIEW_MAX:
		return false
	return n == 0 or Time.get_unix_time_from_system() - float(cfg.get_value("stats", "review_at", 0)) >= REVIEW_GAP_DAYS * 86400.0


## What Google Play said after the rating card was asked for (play_update.gd), for the
## run report. Google never says whether the card showed or what was rated.
func note_review(ok: int, detail: String) -> void:
	var cfg := _load_save()
	cfg.set_value("stats", "review_result", ("done" if ok == 1 else "failed: ") + ("" if ok == 1 else detail.left(80)))
	write_save(cfg)


## Asked as soon as the opening scene hands over to the title, from the very first launch:
## testers often open the game without finishing a run, so the end-of-run question alone
## left almost everyone unasked.
func _ask_reports_on_title() -> void:
	var cfg := _load_save()
	if not Telemetry.configured() or cfg.has_section_key("settings", "reports"):
		return
	if int(cfg.get_value("stats", "wins", 0)) <= 0 or unlock_stage(cfg) < CALM_RUNS:
		return   # asked after the first boss win instead (_ask_reports)
	await get_tree().create_timer(0.6, true, false, true).timeout
	if state == State.TITLE and hud.title_visible() and not hud.armory_visible() and not hud.pass_visible() \
			and not hud.heroes_visible() and not hud.daily_visible() and not hud.modes_visible() and not hud.records_visible() \
			and not _load_save().has_section_key("settings", "reports"):
		hud.show_reports_ask(true)


## The note sent once a day when the game opens (with reports on), so the developer can
## see who is playing even when nobody finishes a run.
func open_text() -> String:
	var cfg := _load_save()
	return "Opened the game (launch %d) | Runs started %d | Tutorial done %s | Best floor %d | Wins %d | Crypt Pass %s | Hero %s" % [
		int(cfg.get_value("stats", "launches", 1)), roundi(record(cfg, "runs")), "no" if first_run_pending() else "yes",
		int(cfg.get_value("stats", "best_floor", 1)), int(cfg.get_value("stats", "wins", 0)),
		"yes" if Store.owned(cfg) else "no", Heroes.get_hero(Heroes.selected(cfg)).title]


## A short "where are we" line for error and crash reports.
func where_text() -> String:
	return "%s%s, floor %d room %d, %s, %s into the run | %d s after launch, %s" % [State.keys()[state],
		" (" + loading + ")" if loading != "" else "", floor_num, _room_index + 1,
		hero.hero_id if hero else "no hero", _format_time(_run_time), Time.get_ticks_msec() / 1000, memory_text()]


## Saves where the game is now, so if it crashes the next launch's report says where (only
## with reports on). Called at launch, during loading, on the title and as each room starts.
func note_spot() -> void:
	_note_memory()
	if Telemetry.instance:
		Telemetry.instance.session_open(true)


# ---------------------------------------------------------------- memory

## Phones with less memory than this start on Low graphics, which needs less graphics memory
## (no glow, shadows or smoothing, and a smaller 3D picture). On version 59 a vivo Y27 crashed
## when its graphics driver ran out of memory. Players can still pick High in Pause.
const LOW_MEMORY_GB := 5.0
## What the loading screen is doing ("loading 3/6"), for crash reports.
var loading := ""
var _mem_peak := 0
var _mem_peak_video := 0
static var _ram_gb := -2.0


## The phone's memory in GB (-1 if unknown).
static func ram_gb() -> float:
	if _ram_gb > -2.0:
		return _ram_gb
	var bytes := float(OS.get_memory_info().get("physical", -1))
	if bytes <= 0.0:
		bytes = _proc_kb("/proc/meminfo", "MemTotal:") * 1024.0
	_ram_gb = bytes / 1073741824.0 if bytes > 0.0 else -1.0
	return _ram_gb


static func ram_text() -> String:
	var gb := ram_gb()
	return "%.1f GB" % gb if gb > 0.0 else "unknown"


static func low_memory_phone() -> bool:
	var gb := ram_gb()
	return gb > 0.0 and gb < LOW_MEMORY_GB


## Memory the game is using right now, as Android counts it, and the graphics part.
static func memory_text() -> String:
	return "memory %d MB (graphics %d MB)" % [_proc_kb("/proc/self/status", "VmRSS:") / 1024, _video_mb()]


static func _video_mb() -> int:
	return int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)


func _note_memory() -> void:
	_mem_peak = maxi(_mem_peak, _proc_kb("/proc/self/status", "VmRSS:") / 1024)
	_mem_peak_video = maxi(_mem_peak_video, _video_mb())


## A number (in kB) from a /proc file line such as "VmRSS:   123456 kB"; 0 if unreadable.
static func _proc_kb(path: String, key: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	for i in 80:
		var line := f.get_line()
		if line.begins_with(key):
			return int(line.substr(key.length()).strip_edges().get_slice(" ", 0))
		if f.eof_reached():
			break
	return 0


## Called once a second of play, after a room's first 3 seconds. When most of the last eight
## seconds ran under 45 frames a second (the median, so one hitch can't do it), graphics step
## down one level (High, Medium, Low); on Low, under 38 holds the game at a steady 30. It
## keeps watching after a step, and three good minutes and it stops until next time.
func _watch_frame_rate(fps: float) -> void:
	_auto_fps.append(fps)
	if _auto_fps.size() > 8:
		_auto_fps.pop_front()
	_auto_seen += 1
	if _auto_fps.size() == 8 and graphics_level > 0:
		var sorted := _auto_fps.duplicate()
		sorted.sort()
		if sorted[4] < (45.0 if graphics_level > 1 else 38.0):
			var first := graphics_level == 3 or not bool(_load_save().get_value("settings", "graphics_auto", false))
			# Version 165: far too slow (under 28) goes straight to Low · 30 FPS.
			_set_graphics(0 if sorted[4] < 28.0 else graphics_level - 1, true, true)
			_auto_fps.clear()
			_auto_seen = 0
			print("[graphics] frame rate %d: stepped down to %s" % [roundi(sorted[4]), GRAPHICS_NAMES[graphics_level]])
			if not first_run and first:
				hud.tip("Graphics set to %s, for a smoother game. Change it in Settings." % GRAPHICS_NAMES[graphics_level], 4.0)
			return
	if _auto_seen >= 180:
		_auto_graphics = false


## Graphics level from the save: the new setting, or the old High/Low one (version 132 and
## before). Phones with little memory start on Low.
static func _saved_graphics(cfg: ConfigFile) -> int:
	if cfg.has_section_key("settings", "graphics"):
		return clampi(int(cfg.get_value("settings", "graphics", 3)), 0, 3)
	if cfg.has_section_key("settings", "high_graphics"):
		return 3 if bool(cfg.get_value("settings", "high_graphics", true)) else 1
	if weak_gpu():
		return 0   # version 165: Low · 30 FPS (a Nokia G310 ran Medium at 20 FPS, Low · 30 steady)
	return 1 if low_memory_phone() else 3


## Version 165: graphics chips too slow for this game's High or Medium, so a new install
## starts on Low · 30 FPS (the frame-rate watch can't be relied on to get there: a Nokia G310
## with an Adreno 619 played its whole tutorial on Medium at 20 FPS). Older and budget
## Adreno (600 to 619 and the 500s), Mali G31 to G57 and T-series, PowerVR and software ones.
static func weak_gpu(gpu := "") -> bool:
	if gpu == "":
		gpu = RenderingServer.get_video_adapter_name()
	var g := gpu.to_lower()
	if g.contains("swiftshader") or g.contains("llvmpipe") or g.contains("powervr"):
		return OS.has_feature("mobile")
	var adreno := g.find("adreno")
	if adreno >= 0:
		var digits := ""
		for ch in g.substr(adreno):
			if ch >= "0" and ch <= "9":
				digits += ch
			elif digits != "":
				break
		var n := int(digits) if digits != "" else 0
		return n > 0 and n <= 619
	for m in ["mali-g31", "mali-g51", "mali-g52", "mali-g57", "mali-t"]:
		if g.contains(m):
			return true
	return false


## The frame rate of the slowest 1% of frames, from a run's frame-length counts (0 if none).
static func one_percent_low(hist: PackedInt32Array) -> float:
	var n := 0
	for c in hist:
		n += c
	if n == 0:
		return 0.0
	var left := maxi(1, n / 100)
	for ms in range(hist.size() - 1, -1, -1):
		left -= hist[ms]
		if left <= 0:
			return 1000.0 / maxf(1.0, ms + 0.5)
	return 0.0


## The share of frames that came on time (within a quarter of the frame-rate limit's frame):
## 1.0 = perfectly steady.
static func steady_share(hist: PackedInt32Array) -> float:
	var n := 0
	var ok := 0
	var limit := 1000.0 / maxf(1.0, Engine.max_fps) * 1.25
	for ms in hist.size():
		n += hist[ms]
		if ms + 0.5 <= limit:
			ok += hist[ms]
	return float(ok) / n if n > 0 else 0.0


## How sharp the 3D world is drawn: 0.85 of the screen on High (0.7 on Low), but never more
## than about 1.9 million pixels (1.2 on Low). A phone set to its sharpest screen mode (a
## Galaxy S23 Ultra at 1440 x 3088 has 4.4 million pixels) would otherwise draw almost twice
## as much as at its usual 1080 x 2316, for a difference too small to see on a phone.
## Medium sits between: 1.55 million pixels, at most 0.78 of the screen.
const PIXELS_HIGH := 1.9e6
const PIXELS_MEDIUM := 1.55e6
const PIXELS_LOW := 1.2e6

## 3D edge smoothing (MSAA) only off phones. Version 141: on a phone, Godot 4.7's
## Compatibility renderer makes a new framebuffer EVERY frame when MSAA is used with a
## smaller-than-screen 3D picture (the "render to texture" path in
## RenderSceneBuffersGLES3::_check_render_buffers never counts as set up), and never frees
## them. After some play there are tens of thousands; changing Graphics then deletes the
## picture they all point at, and on Jesse's Galaxy S23 Ultra (Adreno 740) the screen broke:
## v139 drew the world small in the top-left corner (High to Medium mid-run), v140 (MSAA kept
## on) froze the screen after switching to Low. Without MSAA nothing piles up.
static func msaa_ok() -> bool:
	return not OS.has_feature("mobile")


func _scale_3d(level: int) -> float:
	var win := get_window().size
	var px := maxf(1.0, float(win.x) * float(win.y))
	var budget: float = [PIXELS_LOW, PIXELS_LOW, PIXELS_MEDIUM, PIXELS_HIGH][level]
	return clampf(sqrt(budget / px), 0.5, [0.7, 0.7, 0.78, 0.85][level])


## The size the 3D world is drawn at, and the screen's, for run reports ("918x1969 of 1080x2316").
func _draw_size_text() -> String:
	var win := get_window().size
	var k := get_viewport().scaling_3d_scale
	return "%dx%d of %dx%d" % [roundi(win.x * k), roundi(win.y * k), win.x, win.y]


## High looks best. Medium drops the moon's shadows (soft shadow discs stand in) and (off
## phones) edge smoothing and draws a little smaller; Low also turns off glow, outlines and colour grading
## and draws the 3D world smaller still, for smoother play on older phones. The lowest level
## holds the game at 30 frames a second.
func _set_graphics(level: int, save := true, by_watch := false) -> void:
	level = clampi(level, 0, 3)
	var high := level >= 2
	graphics_level = level
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if level == 3 and msaa_ok() else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = _scale_3d(level)
	_env.glow_enabled = high
	_env.adjustment_enabled = high   # an extra full-screen pass; Low skips it
	_moon.shadow_enabled = level == 3
	_high_graphics = high
	Engine.max_fps = 30 if level == 0 else 60   # no need to drain the battery past what phones show
	Actor.show_blobs(level < 3)
	CharacterVisual.outlines = high
	MenuBackdrop.set_cheap(not high)
	for a: Actor in Actor.all:
		if is_instance_valid(a) and a.visual:
			a.visual.refresh_outline()
	if Room.current:
		Room.current.apply_graphics(high)
	hud.set_graphics_label(level)
	if save:
		if not by_watch:
			_auto_graphics = false   # the player has chosen
			_auto_rewatch = false
		var cfg := _load_save()
		cfg.set_value("settings", "graphics", level)
		cfg.set_value("settings", "graphics_auto", by_watch)
		if cfg.has_section_key("settings", "high_graphics"):
			cfg.erase_section_key("settings", "high_graphics")
		write_save(cfg)


# ---------------------------------------------------------------- armory

func _open_armory() -> void:
	if state != State.TITLE and state != State.DEAD:
		return
	Sfx.play("click")
	hud.show_armory(true, _armory_rows(), coins)


func _open_heroes() -> void:
	if state != State.TITLE and state != State.DEAD:
		return
	Sfx.play("click")
	hud.show_heroes(true, _hero_rows(), coins)


func _hero_rows() -> Array:
	var cfg := _load_save()
	var chosen := Heroes.selected(cfg)
	var rows := []
	for h: Dictionary in Heroes.LIST:
		var m := Curses.mastery(cfg, h.id)
		var badge := Curses.mastery_title(m)
		var unlocked := Heroes.unlocked(cfg, h.id)
		rows.append({"id": h.id, "name": h.title, "badge": badge, "mastery": m, "cost": h.cost,
			"unlocked": unlocked, "selected": h.id == chosen and _trial_hero == "",
			"trial": state == State.TITLE and not unlocked and not bool(cfg.get_value(TRIAL_SECTION, h.id, false)),
			"trying": h.id == _trial_hero, "def": HeroStyle.styled(cfg, h), "points": HeroMastery.points(cfg, h.id),
			"frame": HeroMastery.has_frame(cfg, h.id), "frame_color": HeroMastery.frame_color(HeroMastery.level(cfg, h.id)),
			"new_looks": HeroStyle.unseen(cfg, h.id) if unlocked else 0})   # a locked hero's tab doesn't count looks
	return rows


## The Mastery screen for hero `id` (from the Heroes screen).
func _open_mastery(id: String) -> void:
	hud.open_mastery(_load_save(), id, coins if state == State.TITLE else -1)


## Training (version 132): HeroMastery.TRAIN_COST coins buy hero `id` TRAIN_POINTS mastery
## points, TRAIN_PER_DAY times a day, on the title only. Levels reached give their rewards
## at once, as after a run.
func _train_hero(id: String) -> void:
	var cfg := _load_save()
	var today := Curses.today()
	if state != State.TITLE or not Heroes.unlocked(cfg, id) or HeroMastery.level(cfg, id) >= HeroMastery.MAX_LEVEL \
			or HeroMastery.train_left(cfg, today) <= 0 or coins < HeroMastery.TRAIN_COST:
		Sfx.play("hurt")
		return
	var before := HeroMastery.points(cfg, id)
	coins -= HeroMastery.TRAIN_COST
	cfg.set_value("stats", "coins", coins)
	HeroMastery.train(cfg, id, today)
	var g := _give_mastery(cfg, id)
	write_save(cfg)
	hud.set_coins(coins)
	Sfx.play("coin", 0.7, 0.9)
	Sfx.play("upgrade", 0.6)
	buzz(25)
	print("[train] %s +%d points for %d coins (%d left today)" % [id, HeroMastery.TRAIN_POINTS, HeroMastery.TRAIN_COST, HeroMastery.train_left(cfg, today)])
	hud.mastery_trained(cfg, id, before, coins, g.levels)
	# The hero on the title: its Mastery line, and its frame in the new rank's colour.
	if hero and hero.hero_id == id and _trial_hero == "":
		_title_hero_line(id)
		if not g.levels.is_empty():
			_swap_hero(id, true)
	if hud.heroes_visible():
		hud.show_heroes(true, _hero_rows(), coins)
	hud.show_title(hud.title_visible(), _best_text(), coins)


## The Feats screen (from the Style screen); opening it clears the NEW tag.
func _open_feats(for_hero := "") -> void:
	var cfg := _load_save()
	cfg.set_value(Feats.SECTION, "new", false)
	write_save(cfg)
	var id := for_hero if for_hero != "" else hud.style_hero()
	hud.open_feats(cfg, id if id != "" else str(cfg.get_value("heroes", "selected", "rogue")))


## The Style screen for hero `id` (from the Heroes or Mastery screen).
func _open_style(id: String) -> void:
	# (Version 185: the new looks stay NEW while the Style screen shows them, on their own
	# NEW tab and with a NEW tag on each card; they are marked seen when it closes.)
	var cfg := _load_save()
	hud.open_style(cfg, id)
	if hud._heroes_box.visible:
		hud.show_heroes(true, _hero_rows(), coins)


## A look picked on the Style screen: worn from now on, and on the hero on the title too.
func _wear_look(id: String, slot: String, key: String) -> void:
	var cfg := _load_save()
	if slot == "set":
		# WEAR THE FULL CRYPT KING SET (the Style screen, Pass owners).
		if not Store.owned(cfg):
			return
		for s: String in HeroStyle.PASS_SLOTS:
			HeroStyle.wear(cfg, id, s, HeroStyle.pass_key(s))
	else:
		if not HeroStyle.has_look(cfg, id, slot, key):
			return
		HeroStyle.wear(cfg, id, slot, key)
	write_save(cfg)
	hud.open_style(cfg, id)
	if state != State.TITLE:
		hud.style_note("Saved: your hero wears it from the next run")   # the hero in a run keeps its look
	if hud._heroes_box.visible:
		hud.show_heroes(true, _hero_rows(), coins)
	if state == State.TITLE and hero and hero.hero_id == id and _swap_hero(id, true):
		Fx.magic(hero.center(), hero.bolt_color, 24)


## WEAR IT on a found or earned look (the drop screen): worn from now on (from the next run
## when one is on), without leaving the screen.
func _wear_found(id: String, slot: String, key: String) -> void:
	if slot == "legend":
		_legend_wear(key)
		return
	if id == "":
		id = str(_load_save().get_value("heroes", "selected", "rogue"))
	var cfg := _load_save()
	if not HeroStyle.has_look(cfg, id, slot, key):
		_flush_feats(cfg)   # a Feat won this run is saved by now, but make sure
		if not HeroStyle.has_look(cfg, id, slot, key):
			return
	HeroStyle.wear(cfg, id, slot, key)
	write_save(cfg)
	print("[style] %s wears %s %s" % [id, slot, key])
	if state == State.TITLE and hero and hero.hero_id == id:
		_swap_hero(id, true)


## After a run's end screen: each Feat won in it gets the big reveal, with WEAR IT.
func _reveal_feats_soon() -> void:
	if _feats_run.is_empty() or first_run:
		return
	var ids := _feats_run.duplicate()
	_feats_run.clear()
	# Version 218 (review 4): at the end of the free game the Feat screen never covers the
	# Crypt Pass offer (v216 waited 4.5 s, then covered it). It waits until the offer is
	# gone: shown on the title, or over the loop choice once the Pass is bought.
	var from_offer := _free_end
	if from_offer:
		while (_free_end and state == State.VICTORY) or state == State.TRANSITION:
			await get_tree().create_timer(0.3, true, false, true).timeout
	await get_tree().create_timer(1.1, true, false, true).timeout
	while hud.drops_visible() and state in [State.DEAD, State.VICTORY, State.TITLE]:
		await get_tree().create_timer(0.3, true, false, true).timeout   # a drop opening now: after it
	if state not in [State.DEAD, State.VICTORY] and not (from_offer and state == State.TITLE):
		return
	var cfg := _load_save()
	var id := hero.hero_id if hero else str(cfg.get_value("heroes", "selected", "rogue"))
	var list := []
	for fid: String in ids:
		var f := Feats.get_feat(fid)
		if f.is_empty():
			continue
		var picks := HeroStyle.picks(cfg, id)
		for slot: String in HeroStyle.PASS_SLOTS:
			if picks.get(slot, "") == HeroStyle.pass_key(slot):
				picks[slot] = ""
		picks[str(f.look[0])] = str(f.look[1])
		list.append({"name": f.name, "text": f.text, "look": f.look, "hero": id, "label": Feats.reward_label(f),
			"preview": HeroStyle.dressed(Heroes.get_hero(id), picks)})
	hud.reveal_feats(list)


## Bought the Crypt Pass on the Style screen: that hero puts on the whole Crypt King set
## (once; after that the screen just shows the set as theirs).
func _dress_crypt_king(id: String) -> void:
	var cfg := _load_save()
	if Store.owned(cfg) and not bool(cfg.get_value(HeroStyle.SECTION, "crypt_dressed", false)):
		cfg.set_value(HeroStyle.SECTION, "crypt_dressed", true)
		for slot: String in HeroStyle.PASS_SLOTS:
			HeroStyle.wear(cfg, id, slot, HeroStyle.pass_key(slot))
		write_save(cfg)
		if state == State.TITLE and hero and hero.hero_id == id:
			_swap_hero(id, true)
	hud.open_style(cfg, id)


## TRY FREE on a locked hero: the next run is played as them, once.
func _try_hero(id: String) -> void:
	var cfg := _load_save()
	if state != State.TITLE or Heroes.unlocked(cfg, id) or bool(cfg.get_value(TRIAL_SECTION, id, false)):
		return
	Sfx.play("upgrade")
	_trial_hero = id
	var def := Heroes.get_hero(id)
	_title_hero_line(id, true)
	hud.show_heroes(false)
	if _swap_hero(id):
		Fx.magic(hero.center(), def.bolt_color, 30)


## Tap a hero: unlock it if you can afford it, then make it your hero.
func _pick_hero(id: String) -> void:
	var cfg := _load_save()
	var def := Heroes.get_hero(id)
	if not Heroes.unlocked(cfg, id):
		if def.cost > coins:
			Sfx.play("hurt")
			return
		coins -= def.cost
		cfg.set_value("stats", "coins", coins)
		cfg.set_value(Heroes.SAVE_SECTION, id, true)
		Sfx.play("victory", 0.7)
		hud.set_coins(coins)
	else:
		Sfx.play("upgrade")
	cfg.set_value(Heroes.SAVE_SECTION, "selected", id)
	write_save(cfg)
	_trial_hero = ""
	_title_hero_line(id)
	hud.show_heroes(true, _hero_rows(), coins)
	# On the title screen, swap the hero standing in the room straight away.
	if state == State.TITLE and _swap_hero(id):
		Fx.magic(hero.center(), hero.bolt_color, 30)   # (in the mastery color if worn)


## The chosen hero dressed in the whole Crypt King set, for the Pass card.
func pass_hero_def() -> Dictionary:
	var cfg := _load_save()
	var id := hero.hero_id if hero else Heroes.selected(cfg)
	var p := HeroStyle.picks(cfg, id)
	for slot: String in HeroStyle.PASS_SLOTS:
		p[slot] = HeroStyle.pass_key(slot)
	return HeroStyle.dressed(Heroes.get_hero(id), p)


## Version 279: the Early Access Deal opens the Pass screen by itself once when it starts and
## once more on its last day: only over the bare title, and only for a player who has
## already been shown the Pass button (never in the first runs).
func _deal_pop() -> void:
	var key := _deal_key()
	if key == "" or key == _deal_checked or state != State.TITLE or not hud.title_visible() or hud.title_covered():
		return
	_deal_checked = key   # (the save is read once per key and launch, not every second)
	var cfg := _load_save()
	if unlock_stage(cfg) < 2:
		return
	if bool(cfg.get_value("shown", key, false)):
		return
	cfg.set_value("shown", key, true)
	write_save(cfg)
	_open_pass()


## The save key of the deal's next pop-up ("" without a deal): one for its start, one for its
## last day.
func _deal_key() -> String:
	var d := Store.deal_now()
	if d.is_empty():
		return ""
	var end := int(d.get("end_ms", 0))
	var last := end > 0 and float(end) - Time.get_unix_time_from_system() * 1000.0 < 86400000.0
	return "deal_%d%s" % [end, "_last" if last else ""]


func _open_pass() -> void:
	if state != State.TITLE and state != State.DEAD and state != State.VICTORY:
		return
	Sfx.play("click")
	Store.instance.refresh()
	if not Store.owned():
		Telemetry.step("pass_open")   # v219 (review 4 fix 22): opened the Crypt Pass card
	hud.show_pass(true, Store.owned(), Store.instance.price, Store.instance.status)


func _open_curses() -> void:
	if state != State.TITLE:
		return
	Sfx.play("click")
	_show_curses()


## The Curses screen: each curse with its level, the Curse Level they add up to, and the
## next reward the chosen hero can earn with them.
func _show_curses() -> void:
	var cfg := _load_save()
	if Curses.unlocked("heroic", cfg) and not bool(cfg.get_value(Curses.SAVE_SECTION, "heroic_seen", false)):
		cfg.set_value(Curses.SAVE_SECTION, "heroic_seen", true)
		write_save(cfg)
	var owned := Store.owned()
	var on := Curses.chosen(cfg, owned)
	var rows := []
	for c: Dictionary in Curses.LIST:
		var shut := not Curses.unlocked(c.id, cfg)
		rows.append({"id": c.id, "title": c.title, "text": "Beat the floor %d boss to open it" % Curses.unlock_boss(c.id) if shut else c.text,
			"level": c.level, "on": on.has(c.id), "locked": shut or not Curses.available(c.id, owned),
			"lock": "LOCKED" if shut else "PASS", "gold": c.id == "heroic"})
	var hero_id := _trial_hero if _trial_hero != "" else Heroes.selected(cfg)
	var m := Curses.mastery(cfg, hero_id)
	var next := Curses.next_reward(m)
	var goal := "%s: best Curse Level beaten %d." % [Heroes.get_hero(hero_id).title, m]
	goal += ("\nBeat the floor %d boss at Curse Level %d to earn %s." % [Store.FREE_FLOORS, next.level, next.title]) if not next.is_empty() else "\nEvery reward earned!"
	# version 227: with none on, the head says how to turn one on (the rows only said OFF)
	var head := "CURSE LEVEL %d  ·  Score x%s" % [Curses.level_of(on), _mult_text(Curses.score_mult(on))]
	if on.is_empty():
		head = "No curses on.  Tap one to turn it on."
	hud.show_curses(true, rows, head, goal)


func _toggle_curse(id: String) -> void:
	if not Curses.unlocked(id, _load_save()):
		Sfx.play("click")   # its row already says how to open it
		return
	if not Curses.available(id, Store.owned()):
		_open_pass()
		return
	var cfg := _load_save()
	var on := not bool(cfg.get_value(Curses.SAVE_SECTION, id, false))
	cfg.set_value(Curses.SAVE_SECTION, id, on)
	write_save(cfg)
	Sfx.play("hurt" if on else "click", 0.6)
	_show_curses()


## The Daily Crypt screen: today's theme, hero and rules, and START (or how to get it).
# ---------------------------------------------------------------- the Crypt Race (race.gd)

## CRYPT RACE on the MODES screen: the race lobby, once floor 1 is won twice.
func _open_race() -> void:
	if state != State.TITLE:
		return
	var cfg := _load_save()
	Sfx.play("click")
	if not Race.unlocked(cfg):
		hud.tip("The Crypt Race opens after %d floor 1 wins.\nYou have %d so far." % [Race.UNLOCK_CLEARS, mini(f1_clears(cfg), Race.UNLOCK_CLEARS)], 3.5)
		return
	hud.race_screen.open_lobby(cfg, _race_note)
	_race_note = ""


## RACE!: a rival is found (a bot, in part A) and the VS card shows.
func _race_find() -> void:
	if state != State.TITLE:
		return
	var cfg := _load_save()
	_race = Race.new_match(cfg)
	write_save(cfg)   # (the rival's name, so the next one is someone else)
	print("[race] vs %s (%s, %s) kit %s, rival legs %s, falls at %s" % [_race.rival.name, _race.rival.skill, _race.rival.hero_id,
		Race.kit_text(_race.kit), _race.rival.ends.map(func(x: float) -> String: return "%.1f" % x), _race.rival.downs])
	hud.race_screen.start_search(_race)


## The VS card is done: into the race crypt, a 3-2-1 countdown, and GO.
func _race_go() -> void:
	if state != State.TITLE or _race == null:
		return
	hud.race_screen.close()
	hud.show_modes(false)
	var cfg := _load_save()
	Race.mark_running(cfg, true)   # closing the game from here on counts as a loss
	write_save(cfg)
	hud.set_fade(1.0)
	_race_requested = true
	_start_run()
	if not race:
		return
	_set_state(State.TRANSITION)   # nobody moves until GO
	hud.race_bar.setup(hero.hero_id, _race.rival.hero_id, _race.rival.name)
	hud.race_bar.visible = true
	_race_tick(0.0)
	await _fade(1.0, 0.0, 0.4)
	var m := _race
	_race_lead = 0
	_race_lead_t = 0.0
	Sfx.play("vo_prepare", 0.8)
	for n: String in ["3", "2", "1"]:
		if _race != m:
			return
		hud.callout(n, Color.WHITE)
		Sfx.play("race_count")
		if vibration:
			Input.vibrate_handheld(30)
		await get_tree().create_timer(0.7).timeout
	if _race != m or state != State.TRANSITION:
		return
	hud.callout("GO!", RaceScreen.TEAL.lightened(0.3))
	Sfx.play("race_go")
	Sfx.play("door", 0.7)
	Sfx.play("vo_combo", 0.6)
	_race_live = true
	_set_state(State.PLAYING)


## Every frame of a race, on real time (Race.Clock): the rival's run, surges, the track.
func _race_tick(dt: float) -> void:
	if not race or _race == null or _race.over:
		return
	var r := _race.rival
	if _race_live:
		_race.t += dt
		_race_room_t += dt
		match r.tick(dt * _race.pull()):   # v218: kept close until the boss
			"down":
				if state == State.PLAYING:
					hud.banner("%s FELL!" % r.name.to_upper(), RaceScreen.TEAL)
				_race_quip(["Ouch!", "Oof!", "My bones!"], true)
			"surge":
				_race_incoming()
			"boss":
				if state == State.PLAYING and _race.legs < Race.LEGS - 1:
					hud.banner("%s REACHED THE BOSS!" % r.name.to_upper(), RaceScreen.RIVAL)
					Sfx.play("race_final", 0.9)
					_race_quip(["Boss time!", "Nearly there!"], true)
			"finish":
				_race_end(false)
				return
		if _race.queued > 0 and _race_room_t > 2.0 and _race_can_spawn():
			_race.queued -= 1
			_race_spawn()
		_race_ghost_check()
	# Where the player is on the track: rooms cleared, and how far through this one.
	if _race.legs <= _room_index:
		if _in_boss_room():
			_race.leg_frac = 1.0 - boss_bar() if not _bosses.is_empty() else 0.0
		else:
			_race.leg_frac = float(_race_kills_room) / float(_race_goal)
	else:
		_race.leg_frac = 0.0
	var b := hud.race_bar
	b.me = _race.me()
	b.them = r.progress()
	b.t = _race.t
	b.surge = _race.surge / Race.SURGE_POINTS
	var sb := hud.race_surge
	sb.visible = _race_live and state in [State.PLAYING, State.UPGRADE, State.PAUSED]
	sb.fill = b.surge
	sb.big = r.room() >= Race.LEGS - 1 and not r.done()
	b.gap = _race.gap()
	b.stunned = r.stun > 0.0
	b.down = r.down > 0.0
	b.me_down = hero != null and hero.down_left > 0.0
	# Version 156 (deeper review fix 3): the cards say the clock is running.
	if _race_live and state == State.UPGRADE:
		var g := _race.gap()
		var who := "" if absf(g) < 1.0 else ("  ·  %s %ds" % ["AHEAD" if g > 0.0 else "BEHIND", roundi(absf(g))])
		hud.set_cards_clock("RACE CLOCK RUNNING  %s%s" % [RaceScreen._clock(_race.t), who])
	else:
		hud.set_cards_clock("")
	_race_lead_check()


## The rival's ghost: shown while the rival is in the room you're in, gone out of the far
## door when it moves on. It comes in at the entrance when it has only just reached the room.
func _race_ghost_check() -> void:
	var r := _race.rival
	var here := not r.done() and r.room() == _room_index and Room.current != null
	if is_instance_valid(_race_ghost):
		if _race_ghost.get_parent() != Room.current:
			_race_ghost = null   # (an old room's, freed with it)
		elif not here:
			_race_ghost.leave()
			_race_ghost = null
		return
	if here and state == State.PLAYING:
		_race_ghost = RivalGhost.make(r, _room_index, r.progress() - _room_index < 0.12)
		print("[race] ghost of %s in room %d at %.2f" % [r.name, _room_index, r.progress()])


## A lead change on the track gets called out: "YOU TOOK THE LEAD!" / "RORY TOOK THE LEAD!".
## Two seconds either way before it counts, and at most one call every eight seconds.
func _race_lead_check() -> void:
	if not _race_live or state != State.PLAYING or _race.t < 6.0 or _race.t - _race_lead_t < 8.0:
		return
	var g := _race.gap()
	var now := 1 if g > 2.0 else (-1 if g < -2.0 else 0)
	if now == 0 or now == _race_lead or hud._banner_time > 0.4:
		return
	var first := _race_lead == 0
	_race_lead = now
	_race_lead_t = _race.t
	if first and now == 1:
		return   # ahead from the start: nothing has changed yet
	if now == 1:
		hud.banner("YOU TOOK THE LEAD!", RaceScreen.TEAL.lightened(0.3))
		Sfx.play("race_lead")
		_race_quip(["Hey!", "Not for long!", "Lucky..."], true)
	else:
		hud.banner("%s TOOK THE LEAD!" % _race.rival.name.to_upper(), RaceScreen.RIVAL)
		Sfx.play("race_lost")
		_race_quip(["Catch me!", "See ya!", "Too slow!"], true)


## The rival's chatter by its marker on the track (a bot, so a few short canned lines).
func _race_quip(lines: Array, force := false) -> void:
	if race and _race and not _race.over:
		hud.race_bar.quip(str(lines.pick_random()), force)


## A skeleton killed in a race fills the SURGE meter (an elite 3, double at Chain x2 or more);
## a full meter stuns the rival.
func _race_kill(e: Enemy) -> void:
	_race_kills_room += 1
	if _race.over:
		return
	var pts := 3.0 if e.elite else 1.0
	if chain >= 2.0:
		pts *= 2.0
	# Version 155 (Supercell review fix 3): a full meter waits for you to press SURGE, and
	# while it waits, kills fill nothing.
	var was := _race.surge
	_race.surge = minf(Race.SURGE_POINTS, _race.surge + pts)
	if was < Race.SURGE_POINTS and _race.surge >= Race.SURGE_POINTS:
		hud.callout_at_hero("SURGE READY!", RaceScreen.TEAL.lightened(0.3))
		Sfx.play("upgrade", 0.45, 1.6)
		if vibration:
			Input.vibrate_handheld(25)


## SURGE pressed: the rival is stunned (half as long again while it fights its boss).
func race_fire_surge() -> void:
	if not race or _race == null or _race.over or not _race_live or state != State.PLAYING or _race.surge < Race.SURGE_POINTS:
		return
	_race.surge = 0.0
	_race.sent += 1
	var big := _race.rival.room() >= Race.LEGS - 1
	_race.rival.stun += Race.SURGE_STUN * (Race.BIG_SURGE if big else 1.0)
	hud.race_bar.sent()
	_race_quip(["Argh!", "Zapped!", "No fair!"] if not big else ["NOT NOW!", "My boss!", "Argh!"], true)
	hud.callout_at_hero("BIG SURGE!" if big else "SURGE!", Color(1.0, 0.85, 0.4) if big else RaceScreen.TEAL.lightened(0.3))
	Sfx.play("race_surge", 1.0, 0.9 if big else 1.0)
	if vibration:
		Input.vibrate_handheld(60)
	if hero:
		Fx.magic(hero.center(), RaceScreen.TEAL, 24)
		Fx.shockwave(hero.global_position, RaceScreen.TEAL, 3.0)


## The rival's surge: skeletons thrown into this room now, or at the next fight.
func _race_incoming() -> void:
	_race.got += 1
	hud.race_bar.got()
	_race_quip(["Incoming!", "Surprise!", "Have some!"])
	if _race_can_spawn():
		_race_spawn()
	else:
		_race.queued = mini(_race.queued + 1, 2)


func _race_can_spawn() -> bool:
	return state == State.PLAYING and alive_enemies > 0 and _cleared_serial != _room_serial and Room.current != null \
		and hero != null and hero.down_left <= 0.0


func _race_spawn() -> void:
	var n := 1 if _in_boss_room() else Race.SURGE_FOES
	var spots := _wave_spots(n)
	hud.banner("%s SENT A SURGE!" % _race.rival.name.to_upper(), RaceScreen.RIVAL)
	Sfx.play("race_hit")
	if vibration:
		Input.vibrate_handheld(50)
	for p: Vector3 in spots:
		Fx.dust(p, 14)
		Fx.magic(p + Vector3.UP * 0.5, RaceScreen.RIVAL, 16)
	var serial := _room_serial
	await get_tree().create_timer(0.6, false).timeout
	if not race or _race == null or _race.over or state != State.PLAYING or serial != _room_serial or _cleared_serial == _room_serial:
		return
	var kinds := ["m", "a"]
	for i in spots.size():
		spawn_enemy(kinds[i % kinds.size()], spots[i])
		_race_goal += 1


## Knocked down (hero.gd _knock_down): the rival keeps going.
func race_knocked_down() -> void:
	if _race == null:
		return
	_race.falls += 1
	report_event("knocked_down")
	hud.callout("KNOCKED DOWN!", RaceScreen.RIVAL)
	hud.banner("Up in %d..." % int(Race.DOWN_TIME), Color(1, 0.8, 0.75))
	if vibration:
		Input.vibrate_handheld(80)


func race_down_tick(left: int) -> void:
	if race and _race and not _race.over:
		hud.banner("Up in %d..." % left, Color(1, 0.8, 0.75))


func race_got_up() -> void:
	if race and _race and not _race.over:
		hud.banner("BACK UP! GO!", RaceScreen.TEAL.lightened(0.3))


## The boss fell in a race: across the line first.
func _race_finish_line() -> void:
	var where := boss.global_position if is_instance_valid(boss) else hero.global_position
	_race.legs = Race.LEGS
	_race.leg_frac = 0.0
	_boss_feats()
	_report_room_done("Race boss")
	_set_state(State.VICTORY)
	finisher(where, 0.2, 1.0, RaceScreen.TEAL)
	_clear_enemy_attacks()
	Pickup.collect_all()
	hud.hide_boss()
	_race_end(true)
	Sfx.play("race_win")
	Sfx.play("vo_win", 0.8)
	await get_tree().create_timer(1.0, true, false, true).timeout
	_celebrate()
	await get_tree().create_timer(0.2, true, false, true).timeout
	Pickup.grant_all()
	_save_coins()


## The race is over: the result is saved, the fight stops, and the result screen follows.
## `left`: the player left from the pause menu (no result screen; the title follows).
func _race_end(won: bool, left := false) -> void:
	if _race == null or _race.over:
		return
	var m := _race
	m.over = true
	m.won = won
	_race_live = false
	hud.race_surge.visible = false
	hud.set_cards_clock("")
	if is_instance_valid(_race_ghost):
		_race_ghost.leave()
	_race_ghost = null
	# Version 156: a race win pays the Bone Road like a boss win (rooms already pay theirs).
	if won:
		_add_bones(BoneRoad.BOSS_BONES)
	var bones := _road_shown
	_road_shown = 0
	_save_coins()
	var cfg := _load_save()
	# This race's pace (projected to the line when the rival got there first) sets how quick
	# the next rivals are. A race left from the pause menu says nothing about it.
	var pace := 0.0 if left else (m.t if won else Race.pace_of(m.t, m.me()))
	var res := Race.record(cfg, won, pace, left)
	res.bones = bones
	coins += int(res.coins)
	cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	record_add("coins", int(res.coins))
	hud.set_coins(coins)
	var r := m.rival
	var ahead := maxf(0.0, r.ends[Race.LEGS - 1] - r.clock) + r.stun + maxf(0.0, r.down)
	if won:
		res.line = "You crossed the line %s ahead of %s!" % ["%.1f s" % ahead if ahead < 10.0 else "%d s" % roundi(ahead), r.name] if ahead >= 0.5 \
			else "A photo finish! You beat %s by a hair." % r.name
	else:
		var close := m.me() >= Race.LEGS - 0.15
		var where := "fighting the boss" if m.legs >= Race.LEGS - 1 else "in room %d of %d" % [m.legs + 1, Race.LEGS - 1]
		res.line = ("So close! %s crossed the line first." % r.name) if close else ("%s crossed the line first.\nYou were %s." % [r.name, where])
		if left:
			res.line = "You left the race."
	_last_report = run_report("Crypt Race %s vs %s (%s): %s, trophies %d -> %d" % ["WON" if won else ("LEFT" if left else "LOST"), r.name, r.skill,
		res.line.replace("\n", " "), int(res.before), int(res.after)])
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)
	print("[race] %s in %.1f s (sent %d, got %d, falls %d; rival falls %d, at %.2f), trophies %d -> %d" % ["won" if won else "lost",
		m.t, m.sent, m.got, m.falls, r.falls, r.progress(), int(res.before), int(res.after)])
	if left:
		return
	if state == State.UPGRADE:
		hud.hide_choices()
	if state == State.PAUSED:
		hud.show_pause(false)
	get_tree().paused = false
	if not won:
		_set_state(State.DEAD)
		for a: Actor in Actor.all.duplicate():
			if a is Enemy and not a.dead:
				(a as Enemy).crumble()
		_clear_enemy_attacks()
		hud.hide_boss()
		hud.callout("%s WINS" % r.name.to_upper(), RaceScreen.RIVAL)
		if not left:
			Sfx.play("race_lose")
		Sfx.play("vo_lose", 0.8)
	_reveal_feats_soon()
	await get_tree().create_timer(2.6 if won else 2.0).timeout
	if _race != m:
		return
	hud.race_bar.visible = false
	hud.race_surge.visible = false
	hud.race_screen.show_result(res, m)


## RACE AGAIN: back to the title, and straight on to the next rival.
func _race_again() -> void:
	if not race:
		return
	hud.race_screen.close()
	await _back_to_title(true)
	if state == State.TITLE:
		_race_find()


func _race_to_title() -> void:
	if not race:
		return
	hud.race_screen.close()
	_back_to_title(true)


func _claim_race_road(i: int) -> void:
	var cfg := _load_save()
	var s := Race.claim(cfg, i)
	if s.is_empty():
		return
	if s.kind == "coins":
		coins += int(s.n)
		cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	if s.kind == "coins":
		record_add("coins", s.n)
	hud.set_coins(coins)
	Sfx.play("upgrade")
	Sfx.play("coin", 0.6, 1.2)
	if s.kind == "look":
		hud.callout("NEW %s!" % str(HeroStyle.extra(s.slot, s.key).name).to_upper(), RaceScreen.TEAL.lightened(0.3))
	print("[race] claimed road %d: %s" % [i, Race.road_text(s)])
	hud.race_screen.open_road(_load_save())
	hud.set_drops(Drops.waiting(_load_save()))


func _open_daily() -> void:
	if state != State.TITLE:
		return
	Sfx.play("click")
	_show_daily()


func _show_daily() -> void:
	var cfg := _load_save()
	var owned := Store.owned()
	var rules := []
	for id in Curses.daily_rules():
		var r := Curses.get_curse(id)
		rules.append({"title": r.title, "text": r.text, "kind": r.get("kind", "harm")})
	var used := Curses.official_used(cfg)
	var best := Curses.daily_best(cfg)
	var status := "Your Official run is ready.\nOnly that one counts!"
	var gift := Curses.streak_reward(Curses.streak(cfg) + 1)
	if not used and gift > 0:
		status += "\nPlaying it today: streak day %d, +%d coins!" % [Curses.streak(cfg) + 1, gift]
	var best_text := "  ·  best " + Hud.thousands(best) if best > 0 else ""
	if used and not owned:
		status = "Official run done%s.\nCome back tomorrow, or get the Crypt Pass\nfor practice runs." % best_text
	elif used:
		status = "Official run done%s.\nPlay again for practice." % best_text
	var left := Curses.seconds_left()
	var t := Curses.theme()
	hud.show_daily(true, {"title": "DAILY CRYPT #%d" % Curses.day_number(), "theme": t.name, "theme_text": t.text,
		"hero": Heroes.get_hero(Curses.daily_hero()).title, "mult": _mult_text(Curses.score_mult(Curses.daily_rules())),
		"rules": rules, "status": status, "open": Curses.can_play(owned, cfg), "practice": used,
		"next": "Next Daily Crypt in %dh %02dm" % [left / 3600, (left % 3600) / 60]})


## The result to paste anywhere: the result first, then one square per room (coloured by
## the chain, a skull per boss), the streak and where to get the game.
func _share_text() -> String:
	if not daily:
		return _run_share_text()
	var num := Curses.day_number(_daily_date)
	var head := ""
	if _daily_done:
		head = "🏆 Bone Chain Daily #%d: CLEARED!" % num
	elif state == State.VICTORY:
		head = "⚔️ Bone Chain Daily #%d: floor %d of %d beaten" % [num, floor_num, Curses.DAILY_FLOORS]
	else:
		head = "☠️ Bone Chain Daily #%d: fell on floor %d" % [num, floor_num]
	if _daily_practice:
		head += " (practice)"
	var about := [_share_hero(), Curses.theme(_daily_date).name]
	var days := Curses.streak(_load_save())
	if days >= 2:
		about.append("🔥 %d-day streak" % days)
	return "%s\n%s points · best chain x%.1f\n%s\n%s\nPlay: %s" % [head, Hud.thousands(score), _rep.get("best_chain", 1.0),
		ShareCard.emoji(_share_rows()), " · ".join(about.filter(func(s): return s != "")), PLAY_URL]


## The hero's name for a share, with their Hero Mastery title ("Master Knight").
func _share_hero() -> String:
	if hero == null:
		return ""
	var hero_title: String = Heroes.get_hero(hero.hero_id).title
	var t := HeroMastery.title(_load_save(), hero.hero_id)
	return hero_title if t == "" else "%s %s" % [t, hero_title]


## A normal run's share text: a floor's boss beaten for the first time, or a new best score.
func _run_share_text() -> String:
	var head := "🏆 Bone Chain: beat the floor %d boss for the first time!" % floor_num
	if _share_reason == "best":
		head = "⭐ Bone Chain: new best score! (fell on floor %d)" % floor_num
	var about := [_share_hero(), Floors.current().name]
	return "%s\n%s points · best chain x%.1f\n%s\n%s\nPlay: %s" % [head, Hud.thousands(score), _rep.get("best_chain", 1.0),
		ShareCard.emoji(_share_rows()), " · ".join(about.filter(func(t): return t != "")), PLAY_URL]


## The same result for the share picture: [text, size, colour] lines under the game's name.
func _share_lines() -> Array:
	if not daily:
		var hero_name: String = _share_hero()
		var head := ["Floor %d boss beaten!" % floor_num, 46, Color(1.0, 0.85, 0.45)]
		if _share_reason == "best":
			head = ["New best score!", 50, Color(0.55, 1.0, 0.6)]
		var top_col := Hud.GOLD if hero and hero._master else Color(0.95, 0.9, 0.8)   # a Master shows in gold
		return [[" · ".join([hero_name, Floors.current().name].filter(func(t): return t != "")), 30, top_col],
			head,
			["%s points · best chain x%.1f" % [Hud.thousands(score), _rep.get("best_chain", 1.0)], 28, Hud.GOLD]]
	var num := Curses.day_number(_daily_date)
	var result := "Fell on floor %d" % floor_num
	var col := Color(1.0, 0.55, 0.45)
	if _daily_done:
		result = "CLEARED!"
		col = Color(0.55, 1.0, 0.6)
	elif state == State.VICTORY:
		result = "Floor %d of %d beaten" % [floor_num, Curses.DAILY_FLOORS]
		col = Color(1.0, 0.85, 0.45)
	var about := [_share_hero(), Curses.theme(_daily_date).name]
	return [["Daily Crypt #%d%s" % [num, " (practice)" if _daily_practice else ""], 34, Color(0.95, 0.9, 0.8)],
		[result, 50, col],
		["%s points · best chain x%.1f" % [Hud.thousands(score), _rep.get("best_chain", 1.0)], 28, Hud.GOLD],
		[" · ".join(about.filter(func(t): return t != "")), 24, Color(0.8, 0.78, 0.9)]]


## SHARE RESULT: the phone's share menu with the result as words and as a picture.
func _share() -> void:
	Sfx.play("click")
	var picture: Image = await Share.picture(hud, _share_lines(), _share_rows(), _share_caption())
	hud.share_done(Share.send(_share_text(), picture, "Share your Daily Crypt" if daily else "Share your run"))


## The run as ShareCard codes: one row per floor, one code per room. The Daily Crypt shows
## all its floors; a normal run the last SHARE_FLOORS it reached.
func _share_rows() -> Array:
	var per_floor := _run.size()
	var cleared := (floor_num - 1) * per_floor + _room_index + (1 if state == State.VICTORY else 0)
	var chains: Array = _rep.get("chains", [])
	var first := cleared - chains.size()   # rooms before a continued run have no chain on record
	var rows := []
	var last := Curses.DAILY_FLOORS if daily else floor_num
	for f in range(maxi(0, last - (Curses.DAILY_FLOORS if daily else SHARE_FLOORS)), last):
		var row := []
		for r in per_floor:
			var i := f * per_floor + r
			if i < cleared:
				row.append(ShareCard.BOSS if r == per_floor - 1 else ShareCard.bucket(chains[i - first] if i >= first else 1.0, chain_max()))
			elif i == cleared and state == State.DEAD:
				row.append(ShareCard.FELL)
			else:
				row.append(ShareCard.DARK)
		rows.append(row)
	return rows


## End screens show the result card and SHARE RESULT: every Daily Crypt one, and normal
## runs that beat a floor's boss for the first time or died with a new best score.
func _show_share_card() -> void:
	if not daily and _share_reason == "":
		hud.show_share(false)
		return
	hud.show_share(true, _share_rows(), _share_caption())


func _share_caption() -> String:
	var days := Curses.streak(_load_save())
	if days >= 2:
		return "%d-day Daily streak!" % days
	return "Play tomorrow to start a streak" if daily else ""


## The Pass was bought, restored or refunded, or Google Play sent the price.
func _on_store_changed() -> void:
	_check_pass_lost()
	if hud.pass_visible():
		hud.show_pass(true, Store.owned(), Store.instance.price, Store.instance.status)
	if hud.title_visible():
		hud.show_title(true, _best_text(), coins)
	if hud.heroes_visible():
		hud.show_heroes(true, _hero_rows(), coins)
	if hud.style_visible():
		_dress_crypt_king(hud._style._id)
	if hud.armory_visible() and hud._shop_curses:
		_show_curses()
	if hud.daily_visible():
		_show_daily()
	_deal_pop.call_deferred()
	# v219 review: bought from the event road's PASS button, the event screen shows the Pass row as owned.
	hud.refresh_event()
	if Store.owned() and hud.end_visible():
		hud.show_pass_card(false)   # version 123: bought from the card, it no longer offers the Pass
	if Store.owned() and _dive_done and state == State.VICTORY:
		hud.set_end_stats("Crypt Pass unlocked. Thank you!\n\nThe Drowned Vault and 4 more places are open:\nfind them below floor 5.")
		hud.end_offer_done("Tap to return to the title")
	if Store.owned() and _free_end and state == State.VICTORY:
		_free_end = false
		if Loops.loop_end(floor_num):
			_loop_choice = true
			_checkpoint(false, true)
			hud.set_end_stats("Crypt Pass unlocked. Thank you!\n\nThe Drowned Vault waits below.")
			hud.show_end_loop(true, _bank_bonus(), Loops.loop_of(floor_num) + 1, true)
		else:
			hud.set_end_stats("Crypt Pass unlocked. Thank you!")
			hud.end_offer_done("Tap to descend to floor %d" % (floor_num + 1))


func _armory_rows() -> Array:
	var cfg := _load_save()
	var rows := []
	for u: Dictionary in Armory.LIST:
		rows.append({"id": u.id, "title": u.title, "text": u.text, "level": Armory.level(cfg, u.id),
			"max": u.max, "cost": Armory.next_cost(cfg, u)})
	if Drops.armory_full(cfg):
		var left := Drops.buys_left(cfg, Curses.today())
		rows.append({"id": "buy_drop", "title": "Bone Drop", "text": "Spare coins buy a drop  ·  %d left today" % left,
			"level": 0, "max": 1, "cost": Drops.BUY_COST if left > 0 and Drops.waiting(cfg) < Drops.MAX_WAITING else -1,
			"done": "TOMORROW" if left <= 0 else "FULL"})
	for v: Dictionary in Armory.VAULT:
		var u := Upgrades.get_def(v.id)
		var has := Armory.vault_has(cfg, v.id)
		rows.append({"id": v.id, "title": u.title, "text": u.text, "level": 1 if has else 0, "max": 1,
			"cost": -1 if has else int(v.cost), "vault": u})
	# The Bone Bazaar (version 152): today's three looks.
	var day := str(cfg.get_value(Bazaar.SECTION, "day", ""))
	var offer := Bazaar.today(cfg)
	if day != Curses.today():
		write_save(cfg)   # the day's looks are picked once and kept
	var hero_id := Heroes.selected(cfg)
	for l: Array in offer:
		var slot: String = l[0]
		var key: String = l[1]
		rows.append({"id": "bazaar", "look": l, "title": HeroStyle.item_name(hero_id, slot, key),
			"text": "%s  ·  every hero" % Bazaar.slot_name(slot), "level": 0, "max": 1,
			"cost": -1 if Bazaar.has(cfg, slot, key) else Bazaar.price(slot, key),
			"hero": hero_id, "base": Heroes.get_hero(hero_id)})
		var e := HeroStyle.extra(slot, key)
		if e.has("drop"):
			var tier: Dictionary = Drops.TIERS[int(e.drop)]
			rows[-1].from = "Bone Drop look  ·  %s" % str(tier.name).capitalize()
			rows[-1].from_color = Color(tier.color).lightened(0.25)
		else:
			rows[-1].from = "Only in the Bazaar"
			rows[-1].from_color = Color(1.0, 0.75, 0.45)
	# The Legend Vault (version 312): the dearest looks, for players with everything else.
	for d: Dictionary in Legends.LIST:
		rows.append({"id": "legend", "legend": d.id, "title": d.name, "text": d.text, "slot": d.slot,
			"cost": -1 if Legends.owns(cfg, d.id) else int(d.price), "ready": bool(d.ready),
			"worn": Legends.is_worn(cfg, d.id), "level": 0, "max": 1})
	return rows


## The Bone Bazaar: a look on show, worn by the chosen hero, with its price and BUY.
func _bazaar_preview(slot: String, key: String) -> void:
	if slot == "legend":
		_legend_preview(key)
		return
	var cfg := _load_save()
	var id := Heroes.selected(cfg)
	var picks := HeroStyle.picks(cfg, id)
	for s: String in HeroStyle.PASS_SLOTS:
		if picks.get(s, "") == HeroStyle.pass_key(s):
			picks[s] = ""
	# Version 175: the look for sale is the star. The hero's own Glow and Aura are taken off
	# for the picture (they flooded the hero with light, and the weapon or hat for sale
	# could hardly be seen).
	for s: String in ["glow", "aura"]:
		if s != slot:
			picks[s] = ""
	picks[slot] = key
	var price := Bazaar.price(slot, key)
	hud.show_offer({"name": HeroStyle.item_name(id, slot, key), "kind": Bazaar.slot_name(slot), "look": [slot, key],
		"hero": id, "preview": HeroStyle.dressed(Heroes.get_hero(id), picks), "price": price,
		"owned": Bazaar.has(cfg, slot, key), "afford": coins >= price})


## Version 312: a Legend Vault look on show: the chosen hero with it (and nothing else from
## the vault), its kind and its huge price, with BUY, or WEAR IT / TAKE OFF once it is yours.
func _legend_preview(id: String) -> void:
	var d := Legends.def(id)
	if d.is_empty() or not d.ready:
		return
	var cfg := _load_save()
	var hero_id := Heroes.selected(cfg)
	var legend := {str(d.slot): id}
	var picks := HeroStyle.grand_head(HeroStyle.picks(cfg, hero_id), legend)
	for s: String in ["glow", "aura"]:
		picks[s] = ""   # (as in the Bazaar: the look for sale is the star)
	var def := HeroStyle.dressed(Heroes.get_hero(hero_id), picks)
	def.style.legend = legend
	HeroStyle.crown_grand(def, legend)   # (version 315: a grand set's crown)
	var price := int(d.price)
	hud.show_offer({"name": d.name, "kind": str(Legends.SLOT_NAMES.get(str(d.slot), "")).capitalize(),
		"look": ["legend", id], "hero": hero_id, "preview": def, "price": price, "legend": true,
		"worn": Legends.is_worn(cfg, id), "owned": Legends.owns(cfg, id), "afford": coins >= price})


func _legend_buy(id: String) -> void:
	var cfg := _load_save()
	var d := Legends.def(id)
	var price := int(d.get("price", 0))
	if d.is_empty() or not d.ready or Legends.owns(cfg, id) or coins < price:
		Sfx.play("hurt")
		return
	coins -= price
	cfg.set_value("stats", "coins", coins)
	Legends.give(cfg, id)
	Legends.wear(cfg, id)   # (bought for a fortune: worn at once)
	write_save(cfg)
	print("[legend] bought %s for %d" % [id, price])
	Telemetry.step("legend_" + id)
	hud.set_coins(coins)
	hud.offer_bought(coins)
	hud.show_armory(true, _armory_rows(), coins)
	hud.show_title(hud.title_visible(), _best_text(), coins)
	_refresh_end_goal()
	if state == State.TITLE and hero:
		_swap_hero(hero.hero_id, true)


## WEAR IT on a Legend Vault look that is yours: wears it, or takes it off if it was worn.
func _legend_wear(id: String) -> void:
	var cfg := _load_save()
	if not Legends.owns(cfg, id):
		return
	Legends.toggle(cfg, id)
	write_save(cfg)
	print("[legend] %s %s" % ["wears" if Legends.is_worn(cfg, id) else "took off", id])
	hud.show_armory(true, _armory_rows(), coins)
	if state == State.TITLE and hero:
		_swap_hero(hero.hero_id, true)


func _bazaar_buy(slot: String, key: String) -> void:
	if slot == "legend":
		_legend_buy(key)
		return
	var cfg := _load_save()
	var price := Bazaar.price(slot, key)
	if price <= 0 or Bazaar.has(cfg, slot, key) or coins < price or not Bazaar.today(cfg).has([slot, key]):
		Sfx.play("hurt")
		return
	coins -= price
	cfg.set_value("stats", "coins", coins)
	Bazaar.give(cfg, slot, key)
	write_save(cfg)
	print("[bazaar] bought %s/%s for %d" % [slot, key, price])
	hud.set_coins(coins)
	hud.offer_bought(coins)
	hud.show_armory(true, _armory_rows(), coins)
	hud.show_title(hud.title_visible(), _best_text(), coins)
	_refresh_end_goal()


func _buy_upgrade(id: String) -> void:
	var cfg := _load_save()
	if id == "buy_drop":
		if Drops.buys_left(cfg, Curses.today()) <= 0 or coins < Drops.BUY_COST or Drops.waiting(cfg) >= Drops.MAX_WAITING:
			Sfx.play("hurt")
			return
		coins -= Drops.BUY_COST
		cfg.set_value("stats", "coins", coins)
		Drops.buy(cfg, Curses.today())
		write_save(cfg)
		Sfx.play("upgrade")
		hud.set_coins(coins)
		hud.set_drops(Drops.waiting(cfg))
		hud.show_armory(true, _armory_rows(), coins)
		hud.show_title(hud.title_visible(), _best_text(), coins)
		print("[drop] bought one for %d coins" % Drops.BUY_COST)
		return
	# The Vault: a new blessing, bought once.
	var price := Armory.vault_cost(id)
	if price > 0:
		if Armory.vault_has(cfg, id) or price > coins:
			Sfx.play("hurt")
			return
		coins -= price
		cfg.set_value("stats", "coins", coins)
		cfg.set_value(Armory.VAULT_SECTION, id, true)
		write_save(cfg)
		Sfx.play("victory", 0.6)
		hud.set_coins(coins)
		hud.show_armory(true, _armory_rows(), coins)
		hud.show_title(hud.title_visible(), _best_text(), coins)
		_refresh_end_goal()
		return
	for u: Dictionary in Armory.LIST:
		if u.id != id:
			continue
		var cost := Armory.next_cost(cfg, u)
		if cost < 0 or cost > coins:
			Sfx.play("hurt")
			return
		coins -= cost
		cfg.set_value("stats", "coins", coins)
		cfg.set_value(Armory.SAVE_SECTION, id, Armory.level(cfg, id) + 1)
		write_save(cfg)
		Sfx.play("upgrade")
		hud.set_coins(coins)
		hud.show_armory(true, _armory_rows(), coins)
		hud.show_title(hud.title_visible(), _best_text(), coins)
		_refresh_end_goal()
		return


## After shopping from the death screen, its NEXT line moves on too.
func _refresh_end_goal() -> void:
	if state == State.DEAD and not daily:
		hud.set_end_goal(next_goal())


## Saves the best score and returns the best from before this run.
## The Daily Crypt keeps its own best for each day.
func _save_score(cfg: ConfigFile) -> int:
	if daily:
		var day_best := Curses.daily_best(cfg, _daily_date)
		if _daily_practice:
			return maxi(day_best, score)   # Practice never counts, so it's never a new best
		if score > day_best:
			cfg.set_value("daily", _daily_date, score)
		if _daily_date == Curses.today():   # a run that went past midnight missed its day's board
			_submit_score("daily")
		return day_best
	var best := int(cfg.get_value("stats", "best_score", 0))
	if _side_run():
		return best   # version 280: the Free Dive's score is no best and goes on no board (v310: nor Quick Play's)
	if event == "" and not first_run:
		_submit_score("best")
	if score > best:
		cfg.set_value("stats", "best_score", score)
	return best


## Version 137: puts the run's score on the Google Play leaderboard (kept until it can be sent).
## Robot runs never send.
func _submit_score(key: String) -> void:
	if Leaders.instance and not "autoplay" in OS.get_cmdline_user_args():
		Leaders.instance.submit.call_deferred(key, score)


func _save_best(cfg: ConfigFile, room_reached: int) -> void:
	if _side_run():
		write_save(cfg)   # version 280: the Free Dive's floor 6 is no record (v310: nor Quick Play's floor)
		return
	if floor_num > int(cfg.get_value("stats", "best_floor", 1)):
		cfg.set_value("stats", "best_floor", floor_num)
	if room_reached > int(cfg.get_value("stats", "best_room", 0)):
		cfg.set_value("stats", "best_room", room_reached)
	write_save(cfg)


## The deepest floor whose boss has fallen outside the Daily Crypt. Saves from before
## version 76 don't have it, so the floor before the deepest one reached stands in.
func _best_boss(cfg: ConfigFile) -> int:
	if cfg.has_section_key("stats", "best_boss"):
		return int(cfg.get_value("stats", "best_boss"))
	if int(cfg.get_value("stats", "wins", 0)) <= 0:
		return 0
	return maxi(0, int(cfg.get_value("stats", "best_floor", 1)) - 1)


## Version 213 (hardest review fix #14): on the title, once, after the Pass was taken away.
func _check_pass_lost() -> void:
	if not hud.title_visible() or hud.pass_lost_visible():
		return
	var cfg := _load_save()
	if Store.owned(cfg) or not bool(cfg.get_value("pass", "removed_note", false)):
		return
	cfg.erase_section_key("pass", "removed_note")
	write_save(cfg)
	hud.show_pass_lost(true)


## True while today's first-run coin bonus (DAY_BONUS) is still to be had.
## Version 213 (hardest review fix #1): only a day later than the last one paid counts, so
## moving the date back and forth can't pay it twice.
func day_bonus_ready() -> bool:
	return Curses.today() > str(_load_save().get_value("stats", "bonus_day", ""))


## Pays today's first-run bonus on the coins this run picked up, once per Daily day. The
## tutorial doesn't use it up. Returns the coins added (0 if there were none to add).
func _claim_day_bonus() -> int:
	if first_run or run_coins <= 0 or not day_bonus_ready():
		return 0
	var bonus := ceili(run_coins * DAY_BONUS)
	coins += bonus
	var cfg := _load_save()
	cfg.set_value("stats", "bonus_day", Curses.today())
	cfg.set_value("stats", "coins", coins)
	write_save(cfg)
	hud.set_coins(coins)
	print("[run] first run today: +%d coins" % bonus)
	return bonus


## The closest thing to work toward, in one line, for the death screen and the title:
## something the coins can buy in the Armory now, else the next floor's boss (up to the
## end of the free floors), else what the cheapest upgrade still needs, else a deeper
## Version 150 (coins review, fix 4): with the Armory and the Vault full, the NEXT line points
## to where spare coins go: Training the chosen hero, or a Bone Drop from the Armory.
func _spare_coins_goal(cfg: ConfigFile) -> String:
	var today := Curses.today()
	var id := Heroes.selected(cfg)
	if coins >= HeroMastery.TRAIN_COST and HeroMastery.train_left(cfg, today) > 0 \
			and HeroMastery.level(cfg, id) < HeroMastery.MAX_LEVEL:
		return "NEXT: train %s on the Heroes screen (%d coins)" % [Heroes.hero_name(Heroes.get_hero(id)), HeroMastery.TRAIN_COST]
	if coins >= Drops.BUY_COST and Drops.buys_left(cfg, today) > 0 and Drops.waiting(cfg) < Drops.MAX_WAITING:
		return "NEXT: buy a Bone Drop in the Armory (%d coins)" % Drops.BUY_COST
	return ""


## The cheapest Armory upgrade or Vault blessing still to buy: {name, cost}, or {} if all bought.
func _cheapest_upgrade(cfg: ConfigFile) -> Dictionary:
	var cheapest := {}
	for u: Dictionary in Armory.LIST:
		var cost := Armory.next_cost(cfg, u)
		if cost > 0 and (cheapest.is_empty() or cost < int(cheapest.cost)):
			var named: String = u.title if int(u.max) == 1 else "%s level %d" % [u.title, Armory.level(cfg, u.id) + 1]
			cheapest = {"name": named, "cost": cost}
	for v: Dictionary in Armory.VAULT:
		if not Armory.vault_has(cfg, v.id) and (cheapest.is_empty() or int(v.cost) < int(cheapest.cost)):
			cheapest = {"name": str(Upgrades.get_def(v.id).get("title", v.id)), "cost": int(v.cost)}
	return cheapest


## True when the player can afford something in the Armory (the UPGRADE tag). Never during
## the tutorial, while the Armory is still closed.
func armory_ready() -> bool:
	if first_run_pending():
		return false
	var cheapest := _cheapest_upgrade(_load_save())
	return not cheapest.is_empty() and coins >= int(cheapest.cost)


## floor or the best score. Empty until the tutorial is done.
func next_goal() -> String:
	if first_run_pending():
		return ""
	var cfg := _load_save()
	var cheapest := _cheapest_upgrade(cfg)
	if not cheapest.is_empty() and coins >= int(cheapest.cost):
		return "NEXT: buy %s in the Armory" % cheapest.name
	if cheapest.is_empty():
		var spare := _spare_coins_goal(cfg)
		if spare != "":
			return spare
	var beaten := _best_boss(cfg)
	if beaten < Store.FREE_FLOORS:
		return "NEXT: beat the floor %d boss" % (beaten + 1)
	# The hero's next Curse reward (the free curse earns the first one; the Crypt Pass opens
	# the rest). With the Pass it takes turns with the other goals, run by run.
	var reward := Curses.next_reward(Curses.mastery(cfg, Heroes.selected(cfg)))
	if not reward.is_empty() and (Store.owned() or int(reward.level) <= 1) \
			and (not Store.owned() or roundi(record(cfg, "runs")) % 2 == 0):
		# Version 306 (player panel fix 1): plain words. It read "NEXT: Curse Level 1 on the
		# floor 5 boss: Cursed", which a returning player couldn't follow.
		var prize := ("the title " + str(reward.title)) if str(reward.text).begins_with("Title") else str(reward.title)
		# (Two lines of its own: as one line it wrapped edge to edge.)
		var first := "turn on a Curse in MODES" if int(reward.level) <= 1 \
			else "turn on Curses up to level %d in MODES" % int(reward.level)
		return "NEXT: %s,\nthen beat the floor %d boss to win %s" % [first, Store.FREE_FLOORS, prize]
	if not cheapest.is_empty():
		return "NEXT: %d more coins for %s" % [int(cheapest.cost) - coins, cheapest.name]
	if Store.owned():
		return "NEXT: beat the floor %d boss" % (beaten + 1)
	var top := int(cfg.get_value("stats", "best_score", 0))
	return "NEXT: beat your best score of %s" % Hud.thousands(top) if top > 0 else ""


## The title's gold lines (two at most): the Daily streak while today's run is still to
## play (or once it's two days or more), today's first-run coin bonus, then the next goal.
func title_goal() -> String:
	if first_run_pending():
		return ""
	var cfg := _load_save()
	var lines := []
	var fresh := unlock_note(cfg)
	if fresh != "":
		lines.append(fresh)
	var days := Curses.streak(cfg)
	var played := Curses.official_used(cfg)
	if days >= 1 and not played:
		var gift := Curses.streak_reward(days + 1)
		lines.append(("Daily streak %d · play today's Daily for +%d coins" % [days, gift]) if gift > 0 \
			else "Daily streak %d · play today's Daily to keep it" % days)
	elif days >= 2:
		lines.append("Daily streak: %d days" % days)
	if day_bonus_ready():
		lines.append("Today's first run: +%d%% coins" % roundi(DAY_BONUS * 100))
	if lines.size() < 2:
		var goal := next_goal()
		if goal != "":
			lines.append(goal)
	return "\n".join(lines)


## After the Daily Crypt: the streak and when the next one opens.
func _daily_goal() -> String:
	var left := Curses.seconds_left()
	var days := Curses.streak(_load_save())
	var streak_text := "Daily streak: %d day%s" % [days, "" if days == 1 else "s"] if days >= 1 else ""
	var next_text := "Next Daily Crypt in %dh %02dm" % [left / 3600, (left % 3600) / 60]
	return streak_text + ("  ·  " if streak_text != "" else "") + next_text


func _best_text() -> String:
	var cfg := _load_save()
	var wins := int(cfg.get_value("stats", "wins", 0))
	var best := int(cfg.get_value("stats", "best_room", 0))
	var deepest := int(cfg.get_value("stats", "best_floor", 1))
	# A saved run counts too, so the line never says floor 1 next to CONTINUE Floor 2.
	var saved := RunSave.read()
	if not saved.is_empty() and not bool(saved.get("daily", false)):
		deepest = maxi(deepest, int(saved.get("floor", 1)))
	var top := int(cfg.get_value("stats", "best_score", 0))
	if Curses.daily_best(cfg) > 0:
		return "Best score %s  ·  Deepest floor %d\nToday's Daily Crypt best %s" % [Hud.thousands(top), deepest, Hud.thousands(Curses.daily_best(cfg))]
	if top > 0:
		return "Best score %s  ·  Deepest floor %d" % [Hud.thousands(top), deepest]
	if wins > 0:
		return "Bosses defeated: %d  ·  Deepest floor: %d" % [wins, deepest]
	if best > 0:
		return "Deepest room reached: %d" % best
	return ""


static func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
