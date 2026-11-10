extends Node
## The game manager (loaded automatically as "Game"). Runs the title screen, the rooms of
## a floor, blessing picks, the boss, and the win/lose screens. It builds the whole world
## from code, so there is nothing to set up by hand.

enum State { TITLE, PLAYING, UPGRADE, TRANSITION, PAUSED, DEAD, VICTORY }

const EASY_ROOMS := 2
const MEDIUM_ROOMS := 2
const HARD_ROOMS := 1
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
var vibration := true    # the Vibration setting
var _run: Array = []
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
const BUILD := "2026-11-10b"
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
var _high_graphics := true
## Slow phones: until the player picks a graphics setting, the game watches the frame rate
## during play, and if it can't keep up it switches to Low by itself (and remembers it).
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
var _combo := 0
## Bone Chain: kills close together grow a multiplier on damage and coins.
## +0.1 per kill (+0.3 for elites), up to x3, gone after 2.5 s without a kill.
var chain := 1.0

func chain_max() -> float:
	return 4.0 if hero and hero.perks.has("marrow") else 3.0


func chain_time() -> float:
	var t := 3.5 if hero and hero.perks.has("links") else 2.5
	if curses.has("longlinks"):
		t += 1.5
	if curses.has("fragile"):
		t *= 0.5
	if _hourglass_out:
		t *= 0.4
	return t * pow(0.75, _omen("night"))


## Damage gets a quarter of the chain's bonus (x1.5 at the cap) so a long chain doesn't trivialise rooms.
func chain_damage() -> float:
	var d := 1.0 + (chain - 1.0) * 0.25
	if chain >= 2.0 and hero and hero.perks.has("overcharge"):
		d *= 1.25   # Overcharge
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
## In the Daily Crypt these are seeded, so everyone gets the same blessing cards (and
## rerolls), elites and waves; in other runs they're random (_pick_rng null).
var _pick_rng: RandomNumberGenerator
var _room_rng := RandomNumberGenerator.new()


## How many times Omen `id` has been taken this run.
func _omen(id: String) -> int:
	return int(omens.get(id, 0))


## True until the first run has ended. Older saves that already got somewhere count as done.
func first_run_pending() -> bool:
	var cfg := _load_save()
	if bool(cfg.get_value("stats", "first_run_done", false)):
		return false
	if int(cfg.get_value("stats", "tutorial_deaths", 0)) > 0:
		return true   # died in the tutorial once: it starts again
	return int(cfg.get_value("stats", "best_room", 0)) == 0 and int(cfg.get_value("stats", "wins", 0)) == 0


## Which room of the first run this is (1-6), or 99 outside the first run.
func ftue_room() -> int:
	return _room_index + 1 if first_run and floor_num == 1 else 99


func dash_unlocked() -> bool:
	return ftue_room() >= 2


func chain_unlocked() -> bool:
	return ftue_room() >= 3


func special_unlocked() -> bool:
	return ftue_room() >= 4


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


## Ends the chain. The spine shatters on screen if it had got anywhere.
func _break_chain() -> void:
	var was := chain
	_combo = 0
	chain = 1.0
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
	add_child(Telemetry.new())
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
	hud.heroes_pressed.connect(_open_heroes)
	hud.records_pressed.connect(_open_records)
	hud.drops_pressed.connect(_open_drops)
	hud.drops_closed.connect(_drops_closed)
	hud.road_pressed.connect(_open_road)
	hud.road_claim.connect(_claim_road)
	hud.road_closed.connect(_drops_closed)
	hud.mastery_pressed.connect(_open_mastery)
	hud.style_pressed.connect(_open_style)
	hud.feats_pressed.connect(_open_feats)
	hud.feats_hero_pressed.connect(func(id: String): _open_feats(id))
	hud.see_looks.connect(func(id: String, lv: int):
		_open_style(id)
		hud.style_show_new(lv))
	hud.style_wear.connect(_wear_look)
	hud.found_wear.connect(_wear_found)
	hud.copy_report_pressed.connect(func():
		DisplayServer.clipboard_set(_last_report)
		Sfx.play("click"))
	hud.hero_pick.connect(_pick_hero)
	hud.resume_pressed.connect(func(): if state == State.PAUSED: _resume())
	hud.quit_run_pressed.connect(_quit_to_title)
	hud.retry_pressed.connect(func(): if state == State.DEAD and not hud.armory_visible() and not hud.heroes_visible(): _on_screen_tapped())
	hud.music_toggled.connect(_set_music)
	hud.sounds_toggled.connect(_set_sounds)
	hud.graphics_toggled.connect(_set_graphics)
	hud.shake_changed.connect(_set_shake)
	hud.vibration_toggled.connect(_set_vibration)
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
	hud.curses_pressed.connect(_open_curses)
	hud.curse_toggled.connect(_toggle_curse)
	hud.title_pressed.connect(_end_to_title)
	hud.continue_pressed.connect(_continue_run)
	hud.hero_trial.connect(_try_hero)
	hud.share_pressed.connect(_share)
	hud.loop_deeper.connect(_open_omens)
	hud.loop_bank.connect(_bank_run)
	hud.omen_picked.connect(_pick_omen)
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
	write_save(cfg)
	_set_music(bool(cfg.get_value("settings", "music", true)), false)
	_set_sounds(bool(cfg.get_value("settings", "sounds", true)), false)
	_set_graphics(bool(cfg.get_value("settings", "high_graphics", not low_memory_phone())), false)
	_set_shake(int(cfg.get_value("settings", "shake", 2)), false)
	_set_vibration(bool(cfg.get_value("settings", "vibration", true)), false)
	_auto_graphics = not cfg.has_section_key("settings", "high_graphics") and not "autoplay" in OS.get_cmdline_user_args()
	_auto_rewatch = _auto_graphics
	hud.set_reports_label(bool(cfg.get_value("settings", "reports", false)), Telemetry.configured())
	Telemetry.instance.daily_open()
	Engine.max_fps = 60   # no need to drain the battery past what phones show
	hud.set_coins(coins)

	_build_run()
	_load_room(0, false)
	hero.place_at(Vector3(0, 0, 2))
	_snap_camera()
	_set_state(State.TITLE)
	hud.show_hud(false)
	await Warmup.run()   # while the screen is still black, before the title can be tapped
	hud.show_title(true, _best_text(), coins)
	note_spot()
	_title_hero_line(hero.hero_id)
	_fade(1.0, 0.0, 0.6)
	var args := OS.get_cmdline_user_args()
	if not "autoplay" in args or "intro" in args:
		_play_intro()
		intro.finished.connect(_ask_reports_on_title)
	else:
		Music.play("dungeon")
	if "autoplay" in args:
		add_child(Autoplay.new())


## The opening scene, which hands over to the title screen (the music starts on its big hit).
func _play_intro() -> void:
	intro = Intro.new()
	intro.logo = hud.title_logo()
	intro.logo.modulate.a = 0.0
	intro.music.connect(func(): Music.play("dungeon"))
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
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _frame_us) / 1000.0 if _frame_us > 0 else 0.0
	_frame_us = now
	var added := _added_now
	var added_before := _added_before
	_added_before = added
	_added_now = {}
	if _pause_wanted:
		if state == State.PLAYING:
			_pause_wanted = false
			_pause()
		elif state not in [State.TRANSITION, State.UPGRADE]:
			_pause_wanted = false
	var cover := state != State.PLAYING and hud.covers_world()
	if get_viewport().disable_3d != cover:
		get_viewport().disable_3d = cover
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
		if _auto_rewatch and not _auto_graphics and _high_graphics and _auto_play_t >= 600.0:
			_auto_play_t = 0.0
			_auto_graphics = true
			_auto_seen = 120   # watch for one more minute
			_auto_fps.clear()
		if frame_ms > 250.0:
			_hitch_second = true
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
		if what == NOTIFICATION_APPLICATION_PAUSED:
			_report_left()
			if not _feats_unsaved.is_empty():
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
		if Telemetry.instance:
			Telemetry.instance.set_away(false)
		if Store.instance:
			Store.instance.recheck()
		_check_new_day()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
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
		if hud.road_visible():
			hud.close_road()
			return
		if hud.records_visible():
			hud.show_records(false)
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
			State.DEAD, State.VICTORY:
				_end_to_title()
			State.TITLE:
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
	Telemetry.instance.send("run", run_report("Left the game on floor %d, room %d" % [floor_num, _room_index + 1]))


## The privacy policy (the same pinned page as the Play listing), opened from the pause
## menu, the reports question and the Crypt Pass screen.
const PRIVACY_URL := "https://github.com/incorruptibleyt/AAA-GAME-DESIGN/blob/c18f8d0cecd4889723f0cc5d8c67b3f4e9c658e9/PRIVACY.md"


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
	return pow(1.55, mini(floor_num, 4) - 1) * pow(1.6, clampi(floor_num - 4, 0, 1)) \
		* pow(1.45, clampi(floor_num - 5, 0, 5)) * pow(1.25, maxi(floor_num - 10, 0)) * pow(1.25, _omen("bones"))


## Skeletons hit 35% harder per floor, and 50% per floor below floor 5 (the endless loops).
## When the Hourglass runs out they hit 25% harder still, and each Omen of Blades adds 25%.
## (Floor 5 used to jump by 50% too, and the free game ended on a wall of King hits.)
## The very first run's floor hits a quarter softer: a brand-new player who hadn't found
## the dash yet could fall in the first room in 17 seconds.
func damage_scale() -> float:
	return (1.0 + 0.35 * (floor_num - 1) + 0.15 * maxi(floor_num - 5, 0)) * (1.25 if _hourglass_out else 1.0) \
		* pow(1.25, _omen("blades")) * (0.75 if first_run and floor_num == 1 else 1.0)


func speed_scale() -> float:
	return minf(1.3, 1.0 + 0.05 * (floor_num - 1)) * (1.2 if curses.has("restless") else 1.0) * (1.25 if curses.has("frenzy") else 1.0) \
		* pow(1.1, _omen("haste"))


## Daily Crypt rules and Omens that change coins and hearts.
func coin_mult() -> float:
	var treasure := 1.0 + Doors.TREASURE_COINS if _door.get("kind", "") == "treasure" else 1.0
	return (1.5 if curses.has("rich") else 1.0) * pow(1.5, _omen("gold")) * treasure


## Hearts heal 20% more per floor, so they keep up with skeletons that hit harder deeper
## down (a flat 12 healed nearly every hit on floor 1 and barely dented floor 5).
## How much hearts and Vitality grow with the floor: +20% a floor up to floor 5 (the tuned
## early game, unchanged), then +35% a floor, like enemy hits, so deep floors stay fair.
func heal_scale() -> float:
	return 1.0 + 0.2 * (mini(floor_num, 5) - 1) + 0.35 * maxi(floor_num - 5, 0)


func heart_mult() -> float:
	return heal_scale() * (2.0 if curses.has("hearty") else 1.0) * pow(0.7, _omen("ash"))


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
	return VIEW_HALF_WIDTH / tan(half_h)


func _focus_goal() -> Vector3:
	if hero == null:
		return Vector3.ZERO
	if _intro_focus and is_instance_valid(boss):
		return Vector3(boss.global_position.x * 0.5, 0, boss.global_position.z + 1.5)
	var goal := _room_focus()
	if _zoom_hold > 0.0:
		goal = goal.lerp(Vector3(_zoom_point.x * 0.6, 0, _zoom_point.z), 0.7)
	return goal


func _room_focus() -> Vector3:
	# Follow the hero, but never show past the walls: no empty black space at the edges.
	var p := deg_to_rad(CAMERA_PITCH)
	var half_v := deg_to_rad(CAMERA_FOV) * 0.5
	var d := _cam_distance()
	var bottom := d * (cos(p) - sin(p) / tan(p + half_v))
	var top := d * (cos(p) - sin(p) / tan(p - half_v))
	var hi := Room.HALF_L + 0.6 - bottom
	var lo := -Room.HALF_L - 2.5 - top
	var z := (lo + hi) * 0.5 if lo > hi else clampf(hero.global_position.z + HERO_ABOVE_CENTRE, lo, hi)
	var x_room := maxf(0.0, Room.HALF_W + 0.6 - VIEW_HALF_WIDTH)
	return Vector3(clampf(hero.global_position.x, -x_room, x_room), 0, z)


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


func _update_camera(real_delta: float) -> void:
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
	hud.flash(Color(1, 0.95, 0.85), flash)
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
## thumb left the stick to tap it), or the way you face if you've been still.
func _dash_from_button() -> void:
	if hero == null:
		return
	var m := hud.joystick + keyboard_move()
	if m.length() <= 0.2 and Time.get_ticks_msec() - hud.last_move_ms < 450:
		m = hud.last_move
	hero.dash(Vector3(m.x, 0, m.y) if m.length() > 0.2 else -hero.global_transform.basis.z)


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
			hud.callout("DASH THROUGH IT!", Color(0.6, 0.9, 1.0))
			# One message at a time: the room tip goes so the lesson isn't buried in text.
			hud.tip("", 0.0)
			hud.show_hint("Flick your thumb\nor tap DASH!")
			return


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
	if floor_num <= 1:
		_seen_rooms.clear()
	# The Daily Crypt picks the same rooms for everyone that day.
	var rng := Curses.daily_rng(100 + floor_num, _daily_date) if daily else null
	var piles := [[Layouts.EASY, EASY_ROOMS], [Layouts.MEDIUM, MEDIUM_ROOMS], [Layouts.HARD, HARD_ROOMS]]
	if first_run:
		piles = [[Layouts.EASY, EASY_ROOMS + HARD_ROOMS], [Layouts.MEDIUM, MEDIUM_ROOMS], [Layouts.HARD, 0]]   # no hard room in the tutorial
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
			_run.append(_twist_room(all[left[i]], all, rng))
	_run.append(Layouts.BOSS)


## Who rules this floor: the Ember Catacomb (floor 3, then every Ember floor) has the
## Cinder Colossus, the Drowned Vault (floor 6, 11, 16...) the Tidecaller, the Glowcap
## Grotto (floor 4, 10, 15...) the Sporemother; elsewhere the Skeleton King and the Lich
## take turns (the King on odd floors).
func boss_kind() -> String:
	if Floors.hot() and not first_run:
		return "C"
	if Floors.drowned() and not first_run:
		return "T"
	if Floors.grotto() and not first_run:
		return "S"
	return "L" if floor_num % 2 == 0 else "K"


## The skeletons only this floor's theme has, one letter each: Frost Wraiths on the Frozen
## Ossuary ("f"), Cinder Skeletons in the Ember Catacomb ("e"), Drowned Skeletons in the
## Drowned Vault ("d"), Sporelings and Rootbinders in the Glowcap Grotto ("pr"), none in
## the Bone Crypt.
func theme_enemy() -> String:
	if first_run:
		return ""
	return ["", "f", "e", "d", "pr"][Floors.index(floor_num)]


## Deeper floors don't replay rooms exactly: from floor 2 a room may take its right-hand side
## from another room, and from floor 3 its far half may be joined to the near half of another
## room from the same pool.
func _twist_room(layout: Array, pool: Array, rng: RandomNumberGenerator) -> Array:
	var roll := func() -> float: return rng.randf() if rng else randf()
	var out := layout.duplicate()
	if floor_num >= 3 and pool.size() > 1 and roll.call() < 0.35:
		var other: Array = pool[(pool.find(layout) + 1 + int(roll.call() * (pool.size() - 1))) % pool.size()]
		if other != layout:
			for row in range(7, Layouts.ROWS):
				out[row] = other[row]
	# Every room is drawn the same on both sides, so a plain mirror would change nothing:
	# instead the right-hand side comes from another room, making a lopsided new one.
	if floor_num >= 2 and pool.size() > 1 and roll.call() < 0.5:
		var right: Array = pool[(pool.find(layout) + 1 + int(roll.call() * (pool.size() - 1))) % pool.size()]
		if right != layout:
			for row in out.size():
				out[row] = (out[row] as String).substr(0, 5) + (right[row] as String).substr(5)
	return out


func _combat_rooms() -> int:
	return _run.size() - 1


func _in_boss_room() -> bool:
	return _room_index == _run.size() - 1


func _on_screen_tapped() -> void:
	match state:
		State.TITLE:
			_start_run()
		State.DEAD:
			if _state_time > 1.0:
				_restart()
		State.VICTORY:
			if _state_time > 1.5 and not _loop_choice and not _celebrating:   # the end of a loop has its own buttons
				if _daily_done:
					_back_to_title()
				else:
					_descend()
		State.PAUSED:
			_resume()


func _on_play_pressed() -> void:
	if state == State.TITLE:
		Sfx.play("click")
		_start_run()


func _start_run() -> void:
	var held := RunSave.held()
	if held > 0:
		coins += held   # giving up the saved run gives its held-back coins back
		hud.set_coins(coins)
		_save_coins()
	RunSave.clear()   # starting something new gives up a saved run
	first_run = first_run_pending() or _tutorial_requested
	_tutorial_requested = false
	daily = _daily_requested and Curses.can_play(Store.owned(), _load_save()) and not first_run
	_daily_requested = false
	_daily_done = false
	_run_hero_id = ""
	if daily:
		_begin_daily()
	elif _trial_hero != "" and not first_run:
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
	record_add("runs", 1)
	_pick_curses()
	if daily:
		_build_run()   # the day's rooms
	_use_run_hero()
	_apply_armory()
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
	if first_run:
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
	if daily:
		hud.tip("DAILY CRYPT #%d%s  ·  Score x%s\n%s" % [Curses.day_number(_daily_date), "  ·  Practice" if _daily_practice else "",
			_mult_text(_score_mult), Curses.names(curses)], 5.0, 1.8)
	elif not curses.is_empty():
		hud.tip("CURSE LEVEL %d  ·  Score x%s\n%s" % [Curses.level_of(curses), _mult_text(_score_mult), Curses.names(curses)], 4.0, 1.8)
	elif _run_hero_id != "":
		hud.tip("FREE TRIAL RUN  ·  %s" % Heroes.full_name(Heroes.get_hero(_run_hero_id)), 4.0, 1.8)


## 1.3 -> "1.3", 1.45 -> "1.45"
static func _mult_text(m: float) -> String:
	return str(snappedf(m, 0.01))


func _reset_report() -> void:
	_rep = {"damage": {}, "hits": 0, "healed": 0.0, "dash": 0, "ward": 0, "second_wind": 0,
		"best_combo": 0, "best_chain": 1.0, "perfect": 0, "special": 0, "rooms": [], "room_start": 0.0, "killed_by": "",
		"chains": [], "room_chain": 1.0}
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


func report_event(what: String, amount := 1.0) -> void:
	if _rep.is_empty() or not _rep.has(what):
		return
	_rep[what] += amount
	if what == "perfect" or what == "special":
		_feat_check()


func _report_room_done(label: String) -> void:
	if _rep.is_empty():
		return
	_rep.rooms.append("%s %s" % [label, _format_time(_run_time - _rep.room_start)])
	_rep.chains.append(_rep.room_chain)


## The text that the COPY REPORT button puts on the clipboard.
## `was_first`: the run that just won the tutorial floor (first_run is already cleared then).
func run_report(result: String, was_first := false) -> String:
	var cfg := _load_save()
	var lines := []
	lines.append("Bone Chain run report (build %s, install %s)" % [BUILD, Telemetry.install_id(cfg)])
	lines.append("Hero: %s | %s | Time %s" % [Heroes.get_hero(hero.hero_id).title if hero else "?", result, _format_time(_run_time)])
	lines.append("Score %d | First run %s" % [score, "yes" if first_run or was_first else "no"])
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
	lines.append("Graphics %s (3D %s) | FPS avg %d, lowest %d | longest frame %d ms%s | warm-up %d ms" % ["High" if _high_graphics else "Low", _draw_size_text(),
		roundi(_fps_sum / maxf(1.0, _fps_n)), roundi(_fps_low if _fps_low < 999.0 else 0.0), roundi(_longest_ms),
		(" (%s%s)" % [_longest_at, "; added " + _longest_new if _longest_new != "" else ""]) if _longest_at != "" else "", Warmup.last_ms])
	lines.append("Memory: most %d MB (graphics %d MB) | phone RAM %s" % [_mem_peak, _mem_peak_video, ram_text()])
	return "\n".join(lines)


func _reset_run_stats() -> void:
	_reset_report()
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
	_loop_choice = false
	_omen_choices = []
	_doors = []
	_door = {}
	_picked = {}
	_pick_family = ""
	_pick_better = false


## Gives the hero everything bought in the Armory. Called once at the start of each run.
func _apply_armory() -> void:
	var cfg := _load_save()
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
	if not daily and not first_run and Drops.lucky(cfg) > 0:
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
	_set_state(State.TRANSITION)
	await _fade(0.0, 1.0, 0.4)
	hud.show_end(false)
	if hero:
		hero.queue_free()
		hero = null
	_reset_run_stats()
	record_add("runs", 1)
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
	_build_run()
	_pick_curses()
	hud.show_hud(true)
	_load_room(0, false)
	_apply_armory()
	_load_room(0, true)
	await _fade(1.0, 0.0, 0.4)
	_mode_banner()


## From the pause menu: give up this run and go back to the title (coins are kept).
func _quit_to_title() -> void:
	if state != State.PAUSED:
		return
	hud.show_pause(false)
	get_tree().paused = false
	Telemetry.instance.send("run", run_report("Quit on floor %d, room %d" % [floor_num, _room_index + 1]))
	_back_to_title()   # (its _save_coins keeps the Bone Road bones)


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
	if not keep_run:
		RunSave.clear()
	_free_end = false
	await _fade(0.0, 1.0, 0.4)
	hud.show_end(false)
	hud.show_pass(false)
	hud.show_omens(false)
	daily = false
	_daily_done = false
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
	_build_run()
	_load_room(0, false)
	hero.place_at(Vector3(0, 0, 2))
	_snap_camera()
	_title_hero_line(hero.hero_id)
	hud.show_hud(false)
	hud.hide_boss()
	hud.show_hint("")
	hud.show_title(true, _best_text(), coins)
	if mastery_note != "":
		hud.set_drops(Drops.waiting(_load_save()))
		hud.tip(mastery_note, 4.5, 0.5)
	Music.play("dungeon")
	_set_state(State.TITLE)
	await _fade(1.0, 0.0, 0.4)


## After beating the king: keep your blessings and go one floor deeper, where it's harder.
## Every new floor brings a free reroll; a new loop gives full health and two more.
func _descend() -> void:
	if _free_end:
		return
	_set_state(State.TRANSITION)
	await _fade(0.0, 1.0, 0.5)
	hud.show_end(false)
	floor_num += 1
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
	var loop := Loops.loop_of(floor_num)
	hud.banner(("Loop %d · " % loop if loop > 1 else "") + "Floor %d: %s" % [floor_num, Floors.current().name], Floors.current().banner)
	if new_loop and not omens.is_empty():
		hud.tip("LOOP %d  ·  Score x%s\nOmens: %s" % [loop, _mult_text(_score_mult), Loops.names(omens)], 4.0, 1.8)
	await _fade(1.0, 0.0, 0.5)


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
	omens[id] = _omen(id) + 1
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
	if daily:
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
	var look := Floors.current()
	_light_room(look)
	Fx.ambience(room, Room.HALF_W - 0.5, Room.HALF_L - 0.5, 36 if _high_graphics else 14, look.motes, look.motes_fall, look.get("motes_size", 1.0))
	if hero == null:
		hero = Hero.spawn(world, room.player_start(), _run_hero_id if _run_hero_id != "" else Heroes.selected(_load_save()))
	hero.place_at(room.player_start())
	hero.new_room()
	_snap_camera()
	if not spawn_enemies:
		return
	hud.set_room(index + 1, _combat_rooms(), _in_boss_room(), floor_num)
	if not _rep.is_empty():
		_rep.room_start = _run_time
		_rep.room_chain = chain
		_room_hits = int(_rep.hits)
		_room_special = int(_rep.special)
		if index == 0:
			_floor_hits = int(_rep.hits)
	if not _in_boss_room():
		hud.banner("Room %d" % (index + 1))
	# A new run (not the tutorial): the hero says something as they step in (version 129).
	if index == 0 and _run_time < 1.0 and not first_run:
		_hello_soon()
	if Doors.room_tip(_door) != "":
		hud.tip(Doors.room_tip(_door), 3.5, 1.4)
	if first_run:
		hud.show_hint("Drag your thumb to move.\nLift it to shoot!" if index == 0 else "")
		_ftue_room_intro()
	else:
		hud.show_hint("Drag to move. Lift to shoot.\nFlick your thumb to dash!" if floor_num == 1 and index == 0 else "")
	Music.play("boss" if _in_boss_room() else "dungeon")
	if not _start_blessing.is_empty():
		var u := _start_blessing
		_start_blessing = {}
		get_tree().create_timer(1.6, false).timeout.connect(func(): hud.banner("Blessed: " + u.title, Upgrades.color(u)))
	if not _lucky_blessing.is_empty():
		var u := _lucky_blessing
		_lucky_blessing = {}
		get_tree().create_timer(3.4, false).timeout.connect(func(): hud.banner("Lucky Start: " + u.title, Upgrades.color(u)))
	_wave_kinds.clear()
	var mages := 0
	var theme_kind := theme_enemy()
	# With two kinds (the Glowcap Grotto), every other room puts the second one first, so a
	# room with a single minion still meets both over a floor.
	if theme_kind.length() > 1 and index % 2 == 1:
		theme_kind = theme_kind.reverse()
	# The tutorial teaches the basics first: bone spiders and bombers wait for floor 2. They
	# are left out (they used to turn into extra minions, a bigger pack for a new player),
	# unless that would leave fewer than two skeletons in the room.
	var plain := 0
	for s in room.spawns:
		if s.kind != "s" and s.kind != "x":
			plain += 1
	for s in room.spawns:
		var kind: String = s.kind
		if first_run and (kind == "s" or kind == "x"):
			if plain >= 2:
				continue
			kind = "m"
		# Each themed floor swaps one minion in every room for each of its own skeletons
		# (the Glowcap Grotto has two kinds, so two minions change if the room has them).
		if kind == "m":
			for k in theme_kind:
				if not _wave_kinds.has(k):
					kind = k
					break
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
		if e.is_boss and curses.has("twin"):
			var twin := spawn_enemy(kind, s.pos + Vector3(2.4, 0, 0))
			e.global_position = s.pos - Vector3(2.4, 0, 0)
			for b: Enemy in [e, twin]:
				b.max_health *= 0.65
				b.health = b.max_health
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
	_checkpoint()
	note_spot()


## Saves the run as it is at the start of this room (or of the next floor, after a boss),
## so it can be continued if the game is closed. Not during the first run.
## `loop_end`: saved on the end-of-loop screen, which CONTINUE comes back to.
func _checkpoint(next_floor := false, loop_end := false) -> void:
	if first_run or hero == null or hero.dead:
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
			"best_chain": float(_rep.best_chain), "hits": int(_rep.hits)},
		"rooms": [] if next_floor or loop_end else _run.duplicate(true),   # this floor's rooms, to come back to
		"door": _door.duplicate() if not (next_floor or loop_end) or _door.get("kind", "") == "path" else {}})


## "Floor 3 · Room 2" for the CONTINUE button, or "" when there's no saved run.
func continue_text() -> String:
	var s := RunSave.read()
	if s.is_empty():
		return ""
	var where := "Floor %d · %s" % [s.floor, "Boss" if s.room >= EASY_ROOMS + MEDIUM_ROOMS + HARD_ROOMS else "Room %d" % (s.room + 1)]
	if s.get("loop_end", false):
		where = "Loop %d cleared" % Loops.loop_of(int(s.floor))
		if not Store.owned() and int(s.floor) <= Store.FREE_FLOORS:
			where = "Floor %d cleared" % int(s.floor)
	if _save_needs_pass(s):
		where += " · Crypt Pass"
	return ("Daily Crypt · " if s.daily else "") + where


## A saved run only the Crypt Pass can carry on (past the free floors, a practice Daily or
## a Pass-only curse). After a refund, CONTINUE opens the Pass screen instead of resuming it.
func _save_needs_pass(s: Dictionary) -> bool:
	if Store.owned():
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
	Sfx.play("click")
	first_run = false
	_tutorial_requested = false
	_daily_requested = false
	hud.show_title(false)
	hud.show_armory(false)
	hud.show_pass(false)
	hud.show_daily(false)
	hud.show_hud(true)
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
	_continued_floor = floor_num
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
		hud.tip("Run continued: floor %d" % floor_num, 3.0, 1.2)
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
			hud.tip("Red circle? A hit is coming!\nFlick your thumb to DASH out.", 4.0)
	elif _swipe_tips < 1:
		_swipe_tips = 1
		hud.tip("Red circle? A hit is coming!\nStep out of it!", 4.0)


## The one new thing each first-run room teaches.
func _ftue_room_intro() -> void:
	match ftue_room():
		2: hud.tip("NEW: DASH!\nFlick your thumb or tap DASH\nto zip through arrows.", 6.0, 1.8)
		3:
			hud.tip("Quick kills grow your chain.\nA big chain hits harder!", 6.0, 1.8)
			Sfx.play("upgrade", 0.5)
		4:
			hero.special_charge = 1.0
			hud.tip("Your special move is ready!\nTap the star button to use it.", 999.0, 1.8)
		5: hud.tip("Pick two blessings that match\nto get a gold SYNERGY card!", 5.0, 1.8)
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
	Sfx.play("roar")
	Sfx.play("slam")
	get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): Sfx.play("vo_prepare", 0.8))
	shake(0.5)
	hud.flash(Color(1, 0.3, 0.2), 0.3)
	hud.show_boss_card(b.display_name(), "Ruler of floor %d" % floor_num)
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
	if e.is_boss:
		_bosses.append(e)
		if not is_instance_valid(boss):
			boss = e
			hud.set_boss_name(e.display_name())
	return e


## Now and then a skeleton is a purple elite. Never in the very first room, and more
## often the deeper you go.
func _roll_elite(e: Enemy, room_index: int) -> bool:
	if e.is_boss or e is SkeletonBomber or (floor_num == 1 and room_index == 0):
		return false
	var chance := minf(0.3, 0.07 + 0.05 * (floor_num - 1))
	if curses.has("gilded") or curses.has("hunt"):
		chance *= 2.0
	return _room_rng.randf() < minf(0.6, chance * pow(2.0, _omen("gold")))


## Points for a kill, before the chain and curse multipliers.
func _kill_points(e: Enemy) -> float:
	var p := float(BOSS_POINTS if e.is_boss else (ELITE_POINTS * (3 if curses.has("hunt") else 1) if e.elite else KILL_POINTS))
	if curses.has("frenzy"):
		p *= 2.0
	if curses.has("swarm"):
		p *= 1.5
	return p


func on_enemy_died(e: Enemy) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	note_progress()
	_kills += 1
	record_add("kills", 1)
	hud.show_hint("")
	if state != State.PLAYING:
		return
	# Kills close together build a combo, and the combo feeds the Bone Chain.
	if _combo_left <= 0.0:
		_combo = 0
		chain = 1.0
	_combo += 1
	record_max("best_combo", _combo)
	_combo_left = chain_time()
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
		hud.callout("WARD!", Color(0.85, 0.92, 1.0))
	hud.show_chain(chain)
	if hero:
		hero.add_charge(0.3 if e.elite else 0.1)
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
			hud.callout("ONE DOWN!", Color(1, 0.6, 0.4))
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
func rescue_spot(from: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for p in _wave_spots(40):
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
	_stall_time += delta
	if _stall_time > 20.0 and _stall_step == 0:
		_stall_step = 1
		for a: Actor in Actor.all.duplicate():
			if a is Enemy and not a.dead and not (a as Enemy).is_boss and not _reachable(a as Enemy):
				print("[watchdog] %s out of reach for 20 s; moving it" % (a as Enemy).kind_name())
				a.global_position = rescue_spot(a.global_position)
	elif _stall_time > 40.0 and _stall_step == 1:
		_stall_step = 2
		var n := 0
		for a: Actor in Actor.all.duplicate():
			if a is Enemy and not a.dead and not (a as Enemy).is_boss:
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
	var kinds := _wave_kinds.duplicate()
	U.shuffle(kinds, _room_rng)
	# Later waves bring one extra skeleton (two with the Swarm rule, and one per Omen of the Horde).
	kinds.append(kinds[0])
	if curses.has("swarm"):
		kinds.append(kinds[1 % kinds.size()])
	for i in _omen("horde"):
		kinds.append(kinds[(2 + i) % kinds.size()])
	# First run, room 2: there's always an archer, so the dash lesson has arrows to teach with.
	if ftue_room() == 2 and not kinds.has("a"):
		kinds[0] = "a"
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
	_add_bones(BoneRoad.ROOM_BONES)
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
	_door = {}
	_pick_rng = Curses.daily_rng(500 + floor_num * 10 + _room_index, _daily_date) if daily else null
	_choices = Upgrades.roll_commons(_taken) if step == 1 else Upgrades.roll(_taken, 2 if curses.has("narrow") else 3, step == 4, _pick_family, _pick_better, _pick_rng)
	var lv_line := _mastery_callout
	_mastery_callout = ""
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
	hud.show_cards(_choices, rerolls if step >= 3 else 0, step >= 2, lv_line)


## One free reroll per run swaps all three cards.
func _on_reroll() -> void:
	if state != State.UPGRADE or rerolls <= 0 or ftue_room() < 3:
		return
	rerolls -= 1
	_choices = Upgrades.roll(_taken, 2 if curses.has("narrow") else 3, false, _pick_family, _pick_better, _pick_rng)
	Sfx.play("click")
	hud.show_cards(_choices, rerolls, true)


func _on_card_picked(i: int) -> void:
	if state != State.UPGRADE or i >= _choices.size():
		return
	var u: Dictionary = _choices[i]
	_taken[u.id] = _taken.get(u.id, 0) + 1
	Upgrades.apply(u.id, hero)
	_feat_check()
	_pick_family = ""
	_pick_better = false
	_picked = u
	Sfx.play("upgrade")
	# Then two doors to the next room (still paused), except in the first run.
	_doors = _door_offer()
	if not _doors.is_empty():
		hud.show_doors(_doors.map(func(d): return Doors.describe(d)), _room_index + 2 >= _run.size())
		return
	_leave_room()


## The two doors after this room's blessing. The Daily Crypt offers everyone the same ones.
func _door_offer() -> Array:
	if first_run or _room_index + 1 >= _run.size():
		return []
	var rng := RandomNumberGenerator.new()
	if daily:
		rng = Curses.daily_rng(300 + floor_num * 10 + _room_index, _daily_date)
	else:
		rng.randomize()
	return Doors.offer(rng, _room_index + 2 >= _run.size(), not curses.has("narrow"), _taken)


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
	print("[run] door: %s" % Doors.describe(_door).title)
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


## The run-start line, once the room is under way (the floor's banner can hold the start
## back a moment), and only while still in that first room.
func _hello_soon() -> void:
	var floor_at := floor_num
	for i in 14:
		await get_tree().create_timer(0.3, false).timeout
		if floor_num != floor_at or _room_index != 0:
			return
		if state == State.PLAYING and _state_time > 0.6:
			hud.hero_says("hello")
			return


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
	var boss_name := boss.display_name() if is_instance_valid(boss) else "The boss"
	var where := boss.global_position if is_instance_valid(boss) else hero.global_position
	_boss_feats()
	_report_room_done("F%d Boss" % floor_num)
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
	_share_reason = "boss" if not daily and not first_run and floor_num > prev_boss else ""
	if not daily and floor_num > prev_boss:
		cfg.set_value("stats", "best_boss", floor_num)
	cfg.set_value("stats", "wins", int(cfg.get_value("stats", "wins", 0)) + 1)
	_earn_drop(cfg)   # every boss beaten, the tutorial's too (saved just below)
	_add_bones(BoneRoad.BOSS_BONES)
	_add_mastery(HeroMastery.BOSS_POINTS)
	var bones := _bank_bones(cfg)
	var mastery := _bank_mastery(cfg)
	var best := _save_score(cfg)
	_save_best(cfg, _run.size())
	# Curse mastery: beating the floor 5 boss (or a deeper one) at a Curse Level.
	var rewards := []
	if not daily and floor_num >= Store.FREE_FLOORS and Curses.level_of(curses) > 0 and hero:
		rewards = Curses.record_mastery(cfg, hero.hero_id, Curses.level_of(curses))
		write_save(cfg)
	var was_first := first_run
	_finish_first_run()
	first_run = false   # from here it's a normal run: saved, with doors and each floor's own skeletons
	Music.play("dungeon")
	_daily_done = daily and floor_num >= Curses.DAILY_FLOORS
	_free_end = not daily and floor_num >= Store.FREE_FLOORS and not Store.owned()
	_loop_choice = not daily and not _free_end and Loops.loop_end(floor_num)
	if _daily_done:
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
	elif _free_end:
		extra += "\n\n" + _free_end_text()
	elif _loop_choice:
		extra += "\n\n" + _loop_text()
	for m: Dictionary in rewards:
		extra += "\n\nNew reward for the %s: %s!" % [Heroes.get_hero(hero.hero_id).title, m.title]
	_celebrating = false
	hud.hero_quiet()   # the bubble would show through the end screen
	var tap := "Tap to return to the title" if _daily_done else "Tap to descend to floor %d" % (floor_num + 1)
	hud.show_end(true, true, "%s of floor %d has fallen.\n\nTime  %s\nSkeletons destroyed  %d\nCoins this run  %d\nBone Road  +%d bones%s" % [boss_name, floor_num, _format_time(_run_time), _kills, run_coins, bones, extra],
		tap, false, score, best, _free_end)
	# The hero and the rings at their feet would show between the end screen's buttons
	# (as YOU DIED hides them); they come back as the next room starts (place_at).
	if hero:
		hero.visible = false
	hud.show_mastery(mastery)
	# Version 122: once, after the first boss win past the tutorial, the Pass card shows the
	# hero in the Crypt King set (a win is when the set means most).
	if not Store.owned() and not was_first and not daily and not _free_end:
		var pcfg := _load_save()
		if not bool(pcfg.get_value("shown", "pass_card_win", false)):
			pcfg.set_value("shown", "pass_card_win", true)
			write_save(pcfg)
			hud.show_pass_card(true, pass_hero_def())
	hud.show_end_title(not _daily_done and not _free_end, "TITLE  (RUN SAVED)")
	hud.show_end_loop(_loop_choice, _bank_bonus(), Loops.loop_of(floor_num) + 1)
	if _daily_done:
		hud.set_end_goal(_daily_goal())
	hud.set_drops(Drops.waiting(_load_save()))
	_show_share_card()
	_state_time = 0.0
	_last_report = run_report("Beat floor %d%s" % [floor_num, " (end of the free game)" if _free_end else (" (Daily Crypt cleared)" if _daily_done else "")], was_first)
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)
	_reveal_feats_soon()
	_ask_reports()
	_ask_review(was_first)


func on_hero_died() -> void:
	if state == State.DEAD or state == State.VICTORY:
		return
	_set_state(State.DEAD)
	RunSave.clear()
	_save_coins()
	Sfx.play("vo_lose", 0.8)
	await get_tree().create_timer(1.4, true, false, true).timeout
	var cfg := _load_save()
	# A Bone Drop for getting somewhere: room 3 or further, or any deeper floor. Not in the
	# tutorial (its win gives the first one).
	if not first_run and (_room_index >= 2 or floor_num > 1):
		_earn_drop(cfg)
	var bones := _bank_bones(cfg)
	var mastery := _bank_mastery(cfg)
	var best := _save_score(cfg)
	_save_best(cfg, _room_index + 1)
	var was_first := first_run
	_share_reason = "best" if not daily and not was_first and score > best and score > 0 else ""
	var day_bonus := _claim_day_bonus()
	var tutorial_again := first_run and _tutorial_retry()
	if not tutorial_again:
		_finish_first_run()
	var where := "the throne room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]
	if floor_num > 1:
		where += " on floor %d" % floor_num
	var coin_line := "You earned %d coins.\nSpend them in the Armory!" % run_coins if was_first else "Coins kept  %d" % run_coins
	if day_bonus > 0:
		coin_line += "  (+%d first run today)" % day_bonus
	if bones > 0:
		coin_line += "\nBone Road  +%d bones" % bones
	if tutorial_again:
		coin_line = "You keep the %d coins for the Armory,\nwhich opens after the tutorial.\nThe tutorial starts again from room 1." % run_coins
	# Free players who got deep hear about the Pass once a session, never mid-run.
	var note := not Store.owned() and floor_num >= 3 and not _pass_note_shown
	if note:
		_pass_note_shown = true
	hud.show_end(true, false, "You fell in %s.\n\nTime  %s\nSkeletons destroyed  %d\n%s" % [where, _format_time(_run_time), _kills, coin_line],
		"Tap to try again", not tutorial_again, score, best)
	hud.show_mastery(mastery)
	hud.show_end_title(true)
	hud.set_end_goal(_daily_goal() if daily else next_goal())
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
	if cfg.has_section("saved"):
		cfg.erase_section("saved")
	cfg.set_value("saved", "complete", true)
	_merge_records(cfg)
	var tmp := SAVE_PATH + ".tmp"
	if cfg.save(tmp) != OK:
		push_error("couldn't write " + tmp)
		return
	_rec_add.clear()
	_rec_max.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(SAVE_PATH, SAVE_BACKUP)
	DirAccess.rename_absolute(tmp, SAVE_PATH)


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
	if state == State.TITLE and hud.title_visible():
		hud.show_title(true, _best_text(), coins)


func add_coins(n: int) -> void:
	coins += n
	run_coins += n
	record_add("coins", n)
	hud.set_coins(coins)


# ---------------------------------------------------------------- Feats

## Feats that can happen any moment in a run: counted in one run (perfect dodges, specials,
## kills, the chain, blessings, the score).
func _feat_check() -> void:
	if first_run or _rep.is_empty():
		return
	if int(_rep.perfect) >= 15 and floor_num >= 3:
		_feat("dodger")
	if int(_rep.perfect) >= 40:
		_feat("perfectionist")
	if _kills >= 150:
		_feat("centurion")
	if floor_num >= 4:
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
	if floor_num >= 3 and _run_time - float(_rep.room_start) < 30.0:
		_feat("bossbreaker", cfg)
	var specials := int(_rep.special) - _room_special
	Feats.note_best(cfg, "boss_special", specials)
	if specials >= 4:
		_feat("specialist", cfg)
	if no_hit:
		_feat("cleankill", cfg)
	if floor_num != _continued_floor and int(_rep.hits) == _floor_hits:
		_feat("flawless", cfg)
	if hero.health <= hero.max_health * 0.15:
		_feat("laststand", cfg)
	if floor_num >= 3 and not daily:
		_feat("halfway", cfg)
	if floor_num >= 5 and not daily:
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
		Feats.note_best(cfg, "perfect", int(_rep.perfect))
		if floor_num >= 3:
			Feats.note_best(cfg, "perfect3", int(_rep.perfect))
		Feats.note_best(cfg, "chain_hold", int(_best_chain_hold))
		if floor_num >= 4:
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


func _save_coins() -> void:
	var cfg := _load_save()
	cfg.set_value("stats", "coins", coins)
	_flush_feats(cfg)
	BoneRoad.add(cfg, _road_unsaved)
	_road_unsaved = 0
	HeroMastery.add(cfg, _mastery_hero, _mastery_unsaved)
	_mastery_unsaved = 0
	_feat_bests(cfg)   # after the Mastery points, so Legend sees the new level
	if _perfect_total >= 0:
		cfg.set_value("stats", "perfect_total", _perfect_total)
	write_save(cfg)
	if state != State.TITLE:
		RunSave.bank(run_coins)


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


## The short buzz when the hero is hit.
## A short buzz when Vibration is on (version 122: PERFECT, Phase 2, level ups, rewards).
func buzz(ms: int) -> void:
	if Game.vibration:
		Input.vibrate_handheld(ms)


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


## Reports are off until the player says yes. The game asks once: on the title after the
## opening scene (below), or a moment after a run ends if that question was skipped by
## starting a run, unless they've already chosen in the pause menu.
func _ask_reports() -> void:
	if not Telemetry.configured() or _load_save().has_section_key("settings", "reports"):
		return
	# Version 116: not before the first boss win (a new player's first screen used to be an
	# 80-word data question). After that, any run's end can ask.
	if int(_load_save().get_value("stats", "wins", 0)) <= 0:
		return
	await get_tree().create_timer(1.6, true, false, true).timeout
	if state in [State.DEAD, State.VICTORY] and not hud.armory_visible() and not hud.pass_visible() and not hud.heroes_visible() \
			and not hud.drops_visible() and not _load_save().has_section_key("settings", "reports"):
		hud.show_reports_ask(true)


## Google Play's rating card, asked once: a moment after the first boss a player beats
## after the tutorial (a happy moment, never after a death). Not while the reports question
## is still waiting, so the two never pile up; the next boss win asks instead.
func _ask_review(was_first: bool) -> void:
	var cfg := _load_save()
	if was_first or cfg.get_value("stats", "review_asked", false):
		return
	if Telemetry.configured() and not cfg.has_section_key("settings", "reports"):
		return
	await get_tree().create_timer(2.5, true, false, true).timeout
	if state != State.VICTORY or (UpdateGate.instance and UpdateGate.instance.showing()):
		return
	if "autoplay" in OS.get_cmdline_user_args():
		print("[review] would ask for a rating now (floor %d)" % floor_num)
		return
	if UpdateGate.ask_review():
		cfg = _load_save()
		cfg.set_value("stats", "review_asked", true)
		write_save(cfg)


## Asked as soon as the opening scene hands over to the title, from the very first launch:
## testers often open the game without finishing a run, so the end-of-run question alone
## left almost everyone unasked.
func _ask_reports_on_title() -> void:
	var cfg := _load_save()
	if not Telemetry.configured() or cfg.has_section_key("settings", "reports"):
		return
	if int(cfg.get_value("stats", "wins", 0)) <= 0:
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
## seconds ran under 45 frames a second (the median, so one hitch can't do it), Low graphics
## goes on; three good minutes and it stops watching until next time.
func _watch_frame_rate(fps: float) -> void:
	_auto_fps.append(fps)
	if _auto_fps.size() > 8:
		_auto_fps.pop_front()
	_auto_seen += 1
	if _auto_fps.size() == 8 and _high_graphics:
		var sorted := _auto_fps.duplicate()
		sorted.sort()
		if sorted[4] < 45.0:
			_auto_graphics = false
			_set_graphics(false)
			if not first_run:
				hud.tip("Low graphics on, for a smoother game. Change it in Pause.", 4.0)
			return
	if _auto_seen >= 180:
		_auto_graphics = false


## How sharp the 3D world is drawn: 0.85 of the screen on High (0.7 on Low), but never more
## than about 1.9 million pixels (1.2 on Low). A phone set to its sharpest screen mode (a
## Galaxy S23 Ultra at 1440 x 3088 has 4.4 million pixels) would otherwise draw almost twice
## as much as at its usual 1080 x 2316, for a difference too small to see on a phone.
const PIXELS_HIGH := 1.9e6
const PIXELS_LOW := 1.2e6

func _scale_3d(high: bool) -> float:
	var win := get_window().size
	var px := maxf(1.0, float(win.x) * float(win.y))
	return clampf(sqrt((PIXELS_HIGH if high else PIXELS_LOW) / px), 0.5, 0.85 if high else 0.7)


## The size the 3D world is drawn at, and the screen's, for run reports ("918x1969 of 1080x2316").
func _draw_size_text() -> String:
	var win := get_window().size
	var k := get_viewport().scaling_3d_scale
	return "%dx%d of %dx%d" % [roundi(win.x * k), roundi(win.y * k), win.x, win.y]


## High looks best; Low turns off shadows and glow and draws the 3D world at a lower
## resolution, for smoother play on older phones.
func _set_graphics(high: bool, save := true) -> void:
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = _scale_3d(high)
	_env.glow_enabled = high
	_env.adjustment_enabled = high   # an extra full-screen pass; Low skips it
	_moon.shadow_enabled = high
	_high_graphics = high
	Actor.show_blobs(not high)
	CharacterVisual.outlines = high
	for a: Actor in Actor.all:
		if is_instance_valid(a) and a.visual:
			a.visual.refresh_outline()
	if Room.current:
		Room.current.apply_graphics(high)
	hud.set_graphics_label(high)
	if save:
		_auto_graphics = false   # the player (or the check above) has chosen
		_auto_rewatch = false
		var cfg := _load_save()
		cfg.set_value("settings", "high_graphics", high)
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
			"frame": HeroMastery.has_frame(cfg, h.id), "new_looks": HeroStyle.unseen(cfg, h.id)})
	return rows


## The Mastery screen for hero `id` (from the Heroes screen).
func _open_mastery(id: String) -> void:
	hud.open_mastery(_load_save(), id)


## The Feats screen (from the Style screen); opening it clears the NEW tag.
func _open_feats(for_hero := "") -> void:
	var cfg := _load_save()
	cfg.set_value(Feats.SECTION, "new", false)
	write_save(cfg)
	var id := for_hero if for_hero != "" else hud.style_hero()
	hud.open_feats(cfg, id if id != "" else str(cfg.get_value("heroes", "selected", "rogue")))


## The Style screen for hero `id` (from the Heroes or Mastery screen).
func _open_style(id: String) -> void:
	var cfg := _load_save()
	HeroStyle.mark_seen(cfg, id)
	write_save(cfg)
	hud.open_style(cfg, id)
	if hud._heroes_box.visible:
		hud.show_heroes(true, _hero_rows(), coins)


## A look picked on the Style screen: worn from now on, and on the hero on the title too.
func _wear_look(id: String, slot: String, key: String) -> void:
	var cfg := _load_save()
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
	await get_tree().create_timer(1.1, true, false, true).timeout
	while hud.drops_visible() and state in [State.DEAD, State.VICTORY]:
		await get_tree().create_timer(0.3, true, false, true).timeout   # a drop opening now: after it
	if state not in [State.DEAD, State.VICTORY]:
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


func _open_pass() -> void:
	if state != State.TITLE and state != State.DEAD and state != State.VICTORY:
		return
	Sfx.play("click")
	Store.instance.refresh()
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
	var owned := Store.owned()
	var on := Curses.chosen(cfg, owned)
	var rows := []
	for c: Dictionary in Curses.LIST:
		rows.append({"id": c.id, "title": c.title, "text": c.text, "level": c.level, "on": on.has(c.id),
			"locked": not Curses.available(c.id, owned)})
	var hero_id := _trial_hero if _trial_hero != "" else Heroes.selected(cfg)
	var m := Curses.mastery(cfg, hero_id)
	var next := Curses.next_reward(m)
	var goal := "%s: best Curse Level beaten %d." % [Heroes.get_hero(hero_id).title, m]
	goal += ("\nBeat the floor %d boss at Curse Level %d to earn %s." % [Store.FREE_FLOORS, next.level, next.title]) if not next.is_empty() else "\nEvery reward earned!"
	hud.show_curses(true, rows, "CURSE LEVEL %d  ·  Score x%s" % [Curses.level_of(on), _mult_text(Curses.score_mult(on))], goal)


func _toggle_curse(id: String) -> void:
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
	if Store.owned() and hud.end_visible():
		hud.show_pass_card(false)   # version 123: bought from the card, it no longer offers the Pass
	if Store.owned() and _free_end and state == State.VICTORY:
		_free_end = false
		if Loops.loop_end(floor_num):
			_loop_choice = true
			_checkpoint(false, true)
			hud.set_end_stats("Crypt Pass unlocked. Thank you!\n\n" + _loop_text())
			hud.show_end_loop(true, _bank_bonus(), Loops.loop_of(floor_num) + 1)
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
	return rows


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
		return day_best
	var best := int(cfg.get_value("stats", "best_score", 0))
	if score > best:
		cfg.set_value("stats", "best_score", score)
	return best


func _save_best(cfg: ConfigFile, room_reached: int) -> void:
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


## True while today's first-run coin bonus (DAY_BONUS) is still to be had.
func day_bonus_ready() -> bool:
	return str(_load_save().get_value("stats", "bonus_day", "")) != Curses.today()


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
## floor or the best score. Empty until the tutorial is done.
func next_goal() -> String:
	if first_run_pending():
		return ""
	var cfg := _load_save()
	var cheapest := {}
	for u: Dictionary in Armory.LIST:
		var cost := Armory.next_cost(cfg, u)
		if cost > 0 and (cheapest.is_empty() or cost < int(cheapest.cost)):
			var named: String = u.title if int(u.max) == 1 else "%s level %d" % [u.title, Armory.level(cfg, u.id) + 1]
			cheapest = {"name": named, "cost": cost}
	for v: Dictionary in Armory.VAULT:
		if not Armory.vault_has(cfg, v.id) and (cheapest.is_empty() or int(v.cost) < int(cheapest.cost)):
			cheapest = {"name": str(Upgrades.get_def(v.id).get("title", v.id)), "cost": int(v.cost)}
	if not cheapest.is_empty() and coins >= int(cheapest.cost):
		return "NEXT: buy %s in the Armory" % cheapest.name
	var beaten := _best_boss(cfg)
	if beaten < Store.FREE_FLOORS:
		return "NEXT: beat the floor %d boss" % (beaten + 1)
	# The hero's next Curse reward (the free curse earns the first one; the Crypt Pass opens
	# the rest). With the Pass it takes turns with the other goals, run by run.
	var reward := Curses.next_reward(Curses.mastery(cfg, Heroes.selected(cfg)))
	if not reward.is_empty() and (Store.owned() or int(reward.level) <= 1) \
			and (not Store.owned() or roundi(record(cfg, "runs")) % 2 == 0):
		return "NEXT: Curse Level %d on the floor %d boss: %s" % [int(reward.level), Store.FREE_FLOORS, reward.title]
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
