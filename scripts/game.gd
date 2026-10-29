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
## The save already had stats when the game opened, so this isn't the very first launch.
var _returning := false
var _hit_stop_left := 0.0
var _choices: Array = []
var _exit_arrow: Node3D
var _start_blessing := {}
var _env: Environment
## Run report: numbers collected during a run so Jesse can paste them back for balancing.
const BUILD := "2026-10-29a"
var hit_source := ""
var _last_report := ""
var _rep := {}
var _fps_sum := 0.0
var _fps_n := 0
var _fps_low := 999.0
var _fps_t := 0.0
## The longest single frame during play and where it was: a one-second "lowest" can't
## tell one long freeze from a slow second.
var _frame_us := 0
var _longest_ms := 0.0
var _longest_at := ""
var _high_graphics := true
## Slow phones: until the player picks a graphics setting, the game watches the frame rate
## during play, and if it can't keep up it switches to Low by itself (and remembers it).
var _auto_graphics := false
var _auto_fps: Array[float] = []
var _auto_seen := 0
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
	add_child(Telemetry.new())
	add_child(Store.new())
	Store.instance.changed.connect(_on_store_changed)
	_setup_environment()
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.near = 0.3
	_camera.far = 120.0
	world.add_child(_camera)
	_camera.make_current()

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
	_returning = cfg.has_section("stats")   # the first launch writes stats, even mid-tutorial
	cfg.set_value("stats", "launches", int(cfg.get_value("stats", "launches", 0)) + 1)
	write_save(cfg)
	_set_music(bool(cfg.get_value("settings", "music", true)), false)
	_set_sounds(bool(cfg.get_value("settings", "sounds", true)), false)
	_set_graphics(bool(cfg.get_value("settings", "high_graphics", true)), false)
	_set_shake(int(cfg.get_value("settings", "shake", 2)), false)
	_set_vibration(bool(cfg.get_value("settings", "vibration", true)), false)
	_auto_graphics = not cfg.has_section_key("settings", "high_graphics") and not "autoplay" in OS.get_cmdline_user_args()
	hud.set_reports_label(bool(cfg.get_value("settings", "reports", false)), Telemetry.configured())
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
	hud.set_title_hero(Heroes.get_hero(hero.hero_id).title)
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
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = GLOW
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.06)
	env.fog_density = 0.012
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

func _process(delta: float) -> void:
	_state_time += delta
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _frame_us) / 1000.0 if _frame_us > 0 else 0.0
	_frame_us = now
	if _pause_wanted:
		if state == State.PLAYING:
			_pause_wanted = false
			_pause()
		elif state not in [State.TRANSITION, State.UPGRADE]:
			_pause_wanted = false
	if state == State.PLAYING:
		_run_time += delta
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
		_fps_t += delta
		if _fps_t >= 1.0:
			_fps_t = 0.0
			var f := Engine.get_frames_per_second() if fps_override < 0.0 else fps_override
			_fps_sum += f
			_fps_n += 1
			_fps_low = minf(_fps_low, f)
			if _auto_graphics:
				_watch_frame_rate(f)
		if _combo_left > 0.0:
			_combo_left -= delta
			if _combo_left <= 0.0:
				_break_chain()
	if _hit_stop_left > 0.0:
		_hit_stop_left -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop_left <= 0.0:
			Engine.time_scale = 0.12 if _lesson_left > 0.0 else 1.0
	_update_dash_lesson(delta / maxf(Engine.time_scale, 0.01))
	_update_glow(delta / maxf(Engine.time_scale, 0.01))
	_update_camera(delta / maxf(Engine.time_scale, 0.01))
	_update_exit_arrow()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state == State.PLAYING:
			_pause()
		elif state == State.TRANSITION:
			_pause_wanted = true
		if Telemetry.instance:
			Telemetry.instance.session_open(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if Telemetry.instance:
			Telemetry.instance.session_open(true)
		if Store.instance:
			Store.instance.recheck()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Telemetry.instance:
			Telemetry.instance.session_open(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android's back button pauses the game and resumes it again; from the end screens it
		# goes to the title, and from the title it leaves.
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
		if hud.heroes_visible():
			hud.show_heroes(false)
			return
		if hud.modes_visible():
			hud.show_modes(false)
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


## The privacy policy (the same pinned page as the Play listing), opened from the pause
## menu, the reports question and the Crypt Pass screen.
const PRIVACY_URL := "https://github.com/incorruptibleyt/AAA-GAME-DESIGN/blob/5073bc2077949486e4176015113c8b7ea59d3d19/PRIVACY.md"


## The game's Google Play page, for the Daily Crypt share text.
const PLAY_URL := "https://play.google.com/store/apps/details?id=com.Bone_Chain_Dungeon_Roguelite.myapp"


## How much tougher skeletons are on the current floor.
## Skeleton health grows 55% per floor (compounding), so it keeps pace with a hero whose
## blessings stack up. Floor 4 skeletons have about 3.7x their floor 1 health.
## Floor 5 adds 70%, because a hero that deep is very strong. The endless loops below it
## add 45% a floor, and each Omen of Bones 25%.
func health_scale() -> float:
	return pow(1.55, mini(floor_num, 4) - 1) * pow(1.7, clampi(floor_num - 4, 0, 1)) \
		* pow(1.45, maxi(floor_num - 5, 0)) * pow(1.25, _omen("bones"))


## Skeletons hit 35% harder per floor, and 50% per floor from floor 5 on.
## When the Hourglass runs out they hit 25% harder still, and each Omen of Blades adds 25%.
func damage_scale() -> float:
	return (1.0 + 0.35 * (floor_num - 1) + 0.15 * maxi(floor_num - 4, 0)) * (1.25 if _hourglass_out else 1.0) \
		* pow(1.25, _omen("blades"))


func speed_scale() -> float:
	return minf(1.3, 1.0 + 0.05 * (floor_num - 1)) * (1.2 if curses.has("restless") else 1.0) * (1.25 if curses.has("frenzy") else 1.0) \
		* pow(1.1, _omen("haste"))


## Daily Crypt rules and Omens that change coins and hearts.
func coin_mult() -> float:
	var treasure := 1.0 + Doors.TREASURE_COINS if _door.get("kind", "") == "treasure" else 1.0
	return (1.5 if curses.has("rich") else 1.0) * pow(1.5, _omen("gold")) * treasure


func heart_mult() -> float:
	return (2.0 if curses.has("hearty") else 1.0) * pow(0.7, _omen("ash"))


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
	if _shake > 0.001:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_camera.global_position = pos


func _snap_camera() -> void:
	_cam_focus = _focus_goal()
	_place_camera()


func _update_camera(real_delta: float) -> void:
	_zoom_hold -= real_delta
	var zoom_goal := 1.0 if _zoom_hold > 0.0 else (0.5 if _intro_focus else 0.0)
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
func perfect_dodge(pos: Vector3) -> void:
	Engine.time_scale = 0.3
	_hit_stop_left = maxf(_hit_stop_left, 0.4)
	Fx.shockwave(pos, Color(0.6, 0.95, 1.0), 2.5)
	hud.flash(Color(0.7, 0.95, 1.0), 0.25)
	hud.callout("PERFECT!")
	Sfx.play("crack", 0.9)
	shake(0.2)
	report_event("perfect")
	# A perfect dodge feeds the chain and resets its timer.
	if chain_unlocked():
		var before := chain
		chain = minf(chain_max(), chain + 0.5)
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
			hud.show_hint("Flick your thumb, or tap DASH")
			return


func _end_dash_lesson() -> void:
	_lesson_left = 0.0
	hud.show_hint("")
	if _hit_stop_left <= 0.0:
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount * shake_scale)


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


## The skeleton only this floor's theme has: Frost Wraiths on the Frozen Ossuary ("f"),
## Cinder Skeletons in the Ember Catacomb ("e"), none in the Bone Crypt.
func theme_enemy() -> String:
	if first_run:
		return ""
	return ["", "f", "e"][(maxi(floor_num, 1) - 1) % 3]


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
			if _state_time > 1.5 and not _loop_choice:   # the end of a loop has its own buttons
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
		write_save(cfg)
	_run_hero_id = Curses.daily_hero(_daily_date)
	_daily_done = false


## Swaps the hero standing on the title screen for this run's hero, if that's a different one.
func _use_run_hero() -> void:
	_swap_hero(_run_hero_id if _run_hero_id != "" else Heroes.selected(_load_save()))


## Puts hero `id` where the current hero stands. Returns false if it's already that hero.
func _swap_hero(id: String) -> bool:
	if hero and hero.hero_id == id:
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
		hud.tip("FREE TRIAL RUN  ·  %s" % Heroes.get_hero(_run_hero_id).title, 4.0, 1.8)


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
	lines.append("Graphics %s | FPS avg %d, lowest %d | longest frame %d ms%s | warm-up %d ms" % ["High" if _high_graphics else "Low",
		roundi(_fps_sum / maxf(1.0, _fps_n)), roundi(_fps_low if _fps_low < 999.0 else 0.0), roundi(_longest_ms),
		(" (%s)" % _longest_at) if _longest_at != "" else "", Warmup.last_ms])
	return "\n".join(lines)


func _reset_run_stats() -> void:
	_reset_report()
	_run_time = 0.0
	_kills = 0
	run_coins = 0
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
	if Armory.level(cfg, "blessed") > 0:
		var pick := Upgrades.roll(_taken, 1)
		if not pick.is_empty():
			var u: Dictionary = pick[0]
			_taken[u.id] = 1
			Upgrades.apply(u.id, hero)
			_start_blessing = u
	if daily:
		var gifts := []
		if curses.has("blessed"):
			gifts.append(Curses.daily_blessing(_daily_date).id)
		if Curses.theme(_daily_date).has("perk"):
			gifts.append(Curses.theme(_daily_date).perk)
		for id in gifts:
			_taken[id] = _taken.get(id, 0) + 1
			Upgrades.apply(id, hero)
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
	_build_run()
	first_run = first_run_pending()   # true only after a first death in the tutorial
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
	_back_to_title()


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
	hud.set_title_hero(Heroes.get_hero(hero.hero_id).title)
	hud.show_hud(false)
	hud.hide_boss()
	hud.show_hint("")
	hud.show_title(true, _best_text(), coins)
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
		hero.heal(hero.max_health * 0.3)
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
	return "You beat the free crypt!\nThe Crypt Pass opens floor %d and beyond.\nThis run stays saved until you get it." % (floor_num + 1)


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
	alive_enemies = 0
	boss = null
	_bosses.clear()
	_boss_lost = 0.0
	_hourglass_out = false
	_hourglass_left = Curses.HOURGLASS_BOSS if index == _run.size() - 1 else Curses.HOURGLASS_ROOM
	hud.set_timer(_hourglass_left if spawn_enemies and curses.has("hourglass") else -1.0)
	var room := Room.build(world, _run[index], "Boss" if _in_boss_room() else str(index + 1))
	var look := Floors.current()
	_env.ambient_light_color = look.ambient
	_env.fog_light_color = look.fog
	_env.background_color = look.background
	_moon.light_color = look.moon
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
	if not _in_boss_room():
		hud.banner("Room %d" % (index + 1))
	if Doors.room_tip(_door) != "":
		hud.tip(Doors.room_tip(_door), 3.5, 1.4)
	if first_run:
		hud.show_hint("Drag to move  ·  Let go to shoot" if index == 0 else "")
		_ftue_room_intro()
	else:
		hud.show_hint("Drag to move  ·  Let go to shoot\nFlick your thumb to dash" if floor_num == 1 and index == 0 else "")
	Music.play("boss" if _in_boss_room() else "dungeon")
	if not _start_blessing.is_empty():
		var u := _start_blessing
		_start_blessing = {}
		get_tree().create_timer(1.6, false).timeout.connect(func(): hud.banner("Blessed: " + u.title, Upgrades.color(u)))
	_wave_kinds.clear()
	var mages := 0
	var theme_kind := theme_enemy()
	for s in room.spawns:
		var kind: String = s.kind
		# Ice and fire floors swap one minion in every room for their own skeleton.
		if kind == "m" and theme_kind != "" and not _wave_kinds.has(theme_kind):
			kind = theme_kind
		if kind == "K" and floor_num % 2 == 0:
			kind = "L"   # every second floor is ruled by the Lich instead
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
	# Champion's Door: a golden elite is waiting.
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
		# The first room is gentle; later and deeper rooms get three waves.
		_wave_total = 2 if (index == 0 and floor_num == 1) else (3 if index >= 2 or floor_num > 1 else 2)
	_waves_left = _wave_total - 1
	hud.set_wave(1, _wave_total)
	if is_instance_valid(boss):
		_boss_intro()
	else:
		_set_state(State.PLAYING)
	if alive_enemies == 0:
		room.open_door()
	_checkpoint()


## Saves the run as it is at the start of this room (or of the next floor, after a boss),
## so it can be continued if the game is closed. Not during the first run.
## `loop_end`: saved on the end-of-loop screen, which CONTINUE comes back to.
func _checkpoint(next_floor := false, loop_end := false) -> void:
	if first_run or hero == null or hero.dead:
		return
	var h := RunSave.hero_state(hero)
	if next_floor:
		h.health = minf(hero.max_health, hero.health + hero.max_health * 0.3)   # as _descend heals
	RunSave.write({"floor": floor_num + (1 if next_floor else 0), "room": 0 if next_floor else _room_index,
		"hero_id": hero.hero_id, "hero": h, "taken": _taken.duplicate(), "score": score,
		"rerolls": rerolls + (1 if next_floor and not curses.has("narrow") else 0),   # as _descend adds
		"run_coins": run_coins, "banked": run_coins, "kills": _kills, "time": _run_time, "curses": curses.duplicate(),
		"daily": daily, "daily_date": _daily_date, "practice": _daily_practice, "run_hero": _run_hero_id,
		"heart_bonus": heart_bonus, "omens": omens.duplicate(), "loop_end": loop_end, "seen_rooms": _seen_rooms.duplicate(),
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
	_seen_rooms = (s.get("seen_rooms", []) as Array).duplicate()
	_build_run()
	if s.get("loop_end", false):
		_resume_loop_end()
	else:
		_go_to_room(int(s.room))
		hud.tip("Run continued: floor %d" % floor_num, 3.0, 1.2)
	print("[run] continued floor %d room %d hp %d/%d score %d omens %s door %s" % [floor_num, int(s.room) + 1, hero.health, hero.max_health, score, Loops.names(omens), Doors.describe(_door).get("title", "none")])


## The one new thing each first-run room teaches.
func _ftue_room_intro() -> void:
	match ftue_room():
		2: hud.tip("New: DASH. Flick your thumb, or tap DASH,\nto dodge right through arrows", 6.0, 1.8)
		3:
			hud.tip("Kill fast. Your chain grows.", 6.0, 1.8)
			Sfx.play("upgrade", 0.5)
		4:
			hero.special_charge = 1.0
			hud.tip("Your special is ready. Tap to unleash!", 999.0, 1.8)
		5: hud.tip("Two matching blessings make a gold SYNERGY card", 5.0, 1.8)
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


## Now and then a skeleton is a golden elite. Never in the very first room, and more
## often the deeper you go.
func _roll_elite(e: Enemy, room_index: int) -> bool:
	if e.is_boss or e is SkeletonBomber or (floor_num == 1 and room_index == 0):
		return false
	var chance := minf(0.3, 0.07 + 0.05 * (floor_num - 1))
	if curses.has("gilded") or curses.has("hunt"):
		chance *= 2.0
	return randf() < minf(0.6, chance * pow(2.0, _omen("gold")))


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
	_kills += 1
	hud.show_hint("")
	if state != State.PLAYING:
		return
	# Kills close together build a combo, and the combo feeds the Bone Chain.
	if _combo_left <= 0.0:
		_combo = 0
		chain = 1.0
	_combo += 1
	_combo_left = chain_time()
	var before := chain
	# Grave Pact: only kills right after a dash grow the chain (others still keep it alive).
	if chain_unlocked() and (not curses.has("gravepact") or (hero and hero.dashed_recently())):
		chain = minf(chain_max(), chain + (0.3 if e.elite else 0.1))
	score += roundi(_kill_points(e) * chain * _score_mult)
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
		# Any minions left crumble with their master.
		for a: Actor in Actor.all.duplicate():
			if a != e and a.team == Actor.Team.UNDEAD and not a.dead and a.can_be_hit():
				a.take_damage(9999.0, Vector3.ZERO, 0.0)
		_win()
	elif not _in_boss_room() and _waves_left > 0 and not _wave_pending and alive_enemies <= (1 if _wave_kinds.size() <= 4 else 2):
		_wave_pending = true
		_next_wave()
	elif alive_enemies == 0 and not _in_boss_room() and _waves_left == 0 and not _wave_pending:
		finisher(e.global_position, 0.25, 0.6)
		_clear_enemy_attacks()
		Pickup.collect_all()
		_room_cleared()


## The next wave climbs out of the floor away from the hero, after a short warning.
func _next_wave() -> void:
	var wave := _wave_total - _waves_left + 1
	hud.banner("Wave %d" % wave, Color(1, 0.55, 0.4))
	Sfx.play("warn")
	var kinds := _wave_kinds.duplicate()
	kinds.shuffle()
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
	for i in mini(kinds.size(), spots.size()):
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
	_report_room_done("F%dR%d" % [floor_num, _room_index + 1])
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
	_choices = Upgrades.roll_commons(_taken) if step == 1 else Upgrades.roll(_taken, 2 if curses.has("narrow") else 3, step == 4, _pick_family, _pick_better)
	if _choices.is_empty():
		Pickup.grant_all()
		_save_coins()
		enter_next_room()
		return
	_set_state(State.UPGRADE)
	get_tree().paused = true
	hud.clear_banner()
	hud.show_cards(_choices, rerolls if step >= 3 else 0, step >= 2)


## One free reroll per run swaps all three cards.
func _on_reroll() -> void:
	if state != State.UPGRADE or rerolls <= 0 or ftue_room() < 3:
		return
	rerolls -= 1
	_choices = Upgrades.roll(_taken, 2 if curses.has("narrow") else 3, false, _pick_family, _pick_better)
	Sfx.play("click")
	hud.show_cards(_choices, rerolls, true)


func _on_card_picked(i: int) -> void:
	if state != State.UPGRADE or i >= _choices.size():
		return
	var u: Dictionary = _choices[i]
	_taken[u.id] = _taken.get(u.id, 0) + 1
	Upgrades.apply(u.id, hero)
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
	return Doors.offer(rng, _room_index + 2 >= _run.size(), not curses.has("narrow"))


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
	Pickup.grant_all()
	_save_coins()
	enter_next_room()


## Removes skeleton arrows and warning markers still in the air once a fight is over.
func _clear_enemy_attacks() -> void:
	if Room.current == null:
		return
	for n in Room.current.get_children():
		if (n is Projectile and (n as Projectile).owner_team == Actor.Team.UNDEAD) or n is FirePatch:
			n.queue_free()
		elif n is Telegraph:
			(n as Telegraph).cancel()


func _win() -> void:
	var boss_name := boss.display_name() if is_instance_valid(boss) else "The boss"
	var where := boss.global_position if is_instance_valid(boss) else hero.global_position
	_report_room_done("F%d Boss" % floor_num)
	_set_state(State.VICTORY)
	finisher(where, 0.2, 1.0, Color(1, 0.5, 0.3))
	_clear_enemy_attacks()
	Pickup.collect_all()
	hud.hide_boss()
	await get_tree().create_timer(1.2, true, false, true).timeout
	Pickup.grant_all()   # coins still flying to the hero count, and are saved
	_save_coins()
	Sfx.play("victory")
	Sfx.play("vo_win", 0.8)
	var cfg := _load_save()
	cfg.set_value("stats", "wins", int(cfg.get_value("stats", "wins", 0)) + 1)
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
	var extra := ""
	if was_first:
		extra = "\n\nHeroes and the Armory are open:\nfind them on the title screen."
	elif _daily_done:
		extra = "\n\nDaily Crypt #%d cleared!%s" % [Curses.day_number(_daily_date), " (Practice)" if _daily_practice else ""]
	elif _free_end:
		extra = "\n\n" + _free_end_text()
	elif _loop_choice:
		extra = "\n\n" + _loop_text()
	for m: Dictionary in rewards:
		extra += "\n\nNew reward for the %s: %s!" % [Heroes.get_hero(hero.hero_id).title, m.title]
	var tap := "Tap to return to the title" if _daily_done else "Tap to descend to floor %d" % (floor_num + 1)
	hud.show_end(true, true, "%s of floor %d has fallen.\n\nTime  %s\nSkeletons destroyed  %d\nCoins this run  %d%s" % [boss_name, floor_num, _format_time(_run_time), _kills, run_coins, extra],
		tap, false, score, best, _free_end)
	hud.show_end_title(not _daily_done and not _free_end, "TITLE  (RUN SAVED)")
	hud.show_end_loop(_loop_choice, _bank_bonus(), Loops.loop_of(floor_num) + 1)
	_show_share_card()
	_state_time = 0.0
	_last_report = run_report("Beat floor %d%s" % [floor_num, " (end of the free game)" if _free_end else (" (Daily Crypt cleared)" if _daily_done else "")], was_first)
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)
	_ask_reports()


func on_hero_died() -> void:
	if state == State.DEAD or state == State.VICTORY:
		return
	_set_state(State.DEAD)
	RunSave.clear()
	_save_coins()
	Sfx.play("vo_lose", 0.8)
	await get_tree().create_timer(1.4, true, false, true).timeout
	var cfg := _load_save()
	var best := _save_score(cfg)
	_save_best(cfg, _room_index + 1)
	var was_first := first_run
	var tutorial_again := first_run and _tutorial_retry()
	if not tutorial_again:
		_finish_first_run()
	var where := "the throne room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]
	if floor_num > 1:
		where += " on floor %d" % floor_num
	var coin_line := "You earned %d coins.\nSpend them in the Armory!" % run_coins if was_first else "Coins kept  %d  (spend them in the Armory)" % run_coins
	if tutorial_again:
		coin_line = "You keep the %d coins for the Armory,\nwhich opens after the tutorial.\nThe tutorial starts again from room 1." % run_coins
	# Free players who got deep hear about the Pass once a session, never mid-run.
	var note := not Store.owned() and floor_num >= 3 and not _pass_note_shown
	if note:
		_pass_note_shown = true
		coin_line += "\n\nThe Crypt Pass opens endless floors,\nevery hero, Daily practice and Curses."
	hud.show_end(true, false, "You fell in %s.\n\nTime  %s\nSkeletons destroyed  %d\n%s" % [where, _format_time(_run_time), _kills, coin_line],
		"Tap to try again", not tutorial_again, score, best)
	hud.show_end_title(true)
	_show_share_card()
	hud.show_end_pass(note)
	_state_time = 0.0
	_last_report = run_report("Died on floor %d, %s" % [floor_num, "boss room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]])
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)
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
	var tmp := SAVE_PATH + ".tmp"
	if cfg.save(tmp) != OK:
		push_error("couldn't write " + tmp)
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(SAVE_PATH, SAVE_BACKUP)
	DirAccess.rename_absolute(tmp, SAVE_PATH)


func add_coins(n: int) -> void:
	coins += n
	run_coins += n
	hud.set_coins(coins)


func _save_coins() -> void:
	var cfg := _load_save()
	cfg.set_value("stats", "coins", coins)
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
func _set_vibration(on: bool, save := true) -> void:
	vibration = on
	hud.set_vibration_label(on)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "vibration", on)
		write_save(cfg)


## High looks best; Low turns off shadows and glow and draws the 3D world at a lower
## resolution, for smoother play on older phones.
func _set_reports(on: bool) -> void:
	var cfg := _load_save()
	cfg.set_value("settings", "reports", on)
	write_save(cfg)
	hud.set_reports_label(on, Telemetry.configured())
	if not on and Telemetry.instance:
		Telemetry.instance.clear_queue()   # nothing waiting goes out after a no
	Sfx.play("click")


## Reports are off until the player says yes. The game asks once, a moment after a run
## ends (normally the tutorial run), or on the title from the second launch on (below),
## unless they've already chosen in the pause menu.
func _ask_reports() -> void:
	if not Telemetry.configured() or _load_save().has_section_key("settings", "reports"):
		return
	await get_tree().create_timer(1.6, true, false, true).timeout
	if state in [State.DEAD, State.VICTORY] and not hud.armory_visible() and not hud.pass_visible() and not hud.heroes_visible() \
			and not _load_save().has_section_key("settings", "reports"):
		hud.show_reports_ask(true)


## Players who leave in the middle of a run never see the end-of-run question, so once the
## opening scene hands over to the title, a returning player is asked there instead.
func _ask_reports_on_title() -> void:
	var cfg := _load_save()
	if not Telemetry.configured() or cfg.has_section_key("settings", "reports"):
		return
	if not _returning:
		return   # the very first launch goes straight to the tutorial
	await get_tree().create_timer(0.6, true, false, true).timeout
	if state == State.TITLE and hud.title_visible() and not hud.armory_visible() and not hud.pass_visible() \
			and not hud.heroes_visible() and not hud.daily_visible() and not hud.modes_visible() \
			and not _load_save().has_section_key("settings", "reports"):
		hud.show_reports_ask(true)


## A short "where are we" line for error and crash reports.
func where_text() -> String:
	return "%s, floor %d room %d, %s, %s into the run" % [State.keys()[state], floor_num, _room_index + 1,
		hero.hero_id if hero else "no hero", _format_time(_run_time)]


## Called once a second of play. Eight slow seconds in a row (under 45 frames a second on
## average) turn on Low graphics; three good minutes and it stops watching until next time.
func _watch_frame_rate(fps: float) -> void:
	_auto_fps.append(fps)
	if _auto_fps.size() > 8:
		_auto_fps.pop_front()
	_auto_seen += 1
	if _auto_fps.size() == 8 and _high_graphics:
		var avg := 0.0
		for v in _auto_fps:
			avg += v
		if avg / 8.0 < 45.0:
			_auto_graphics = false
			_set_graphics(false)
			if not first_run:
				hud.tip("Low graphics on, for a smoother game. Change it in Pause.", 4.0)
			return
	if _auto_seen >= 180:
		_auto_graphics = false


func _set_graphics(high: bool, save := true) -> void:
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = 0.85 if high else 0.7
	_env.glow_enabled = high
	_moon.shadow_enabled = high
	_high_graphics = high
	if Room.current:
		Room.current.apply_graphics(high)
	hud.set_graphics_label(high)
	if save:
		_auto_graphics = false   # the player (or the check above) has chosen
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
			"trying": h.id == _trial_hero})
	return rows


## TRY FREE on a locked hero: the next run is played as them, once.
func _try_hero(id: String) -> void:
	var cfg := _load_save()
	if state != State.TITLE or Heroes.unlocked(cfg, id) or bool(cfg.get_value(TRIAL_SECTION, id, false)):
		return
	Sfx.play("upgrade")
	_trial_hero = id
	var def := Heroes.get_hero(id)
	hud.set_title_hero(def.title + " (free trial run)")
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
	hud.set_title_hero(def.title)
	hud.show_heroes(true, _hero_rows(), coins)
	# On the title screen, swap the hero standing in the room straight away.
	if state == State.TITLE and _swap_hero(id):
		Fx.magic(hero.center(), def.bolt_color, 30)


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
	var status := "Your Official run is ready. Only that one counts, so make it good!"
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


## The Daily Crypt result as text to paste anywhere: one square per room.
## The Daily Crypt result to paste anywhere: the result first, then one square per room
## (coloured by the chain, a skull per boss), the streak and where to get the game.
func _share_text() -> String:
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
	var about := [Heroes.get_hero(hero.hero_id).title if hero else "", Curses.theme(_daily_date).name]
	var days := Curses.streak(_load_save())
	if days >= 2:
		about.append("🔥 %d days in a row" % days)
	return "%s\n%s points · best chain x%.1f\n%s\n%s\nPlay: %s" % [head, Hud.thousands(score), _rep.get("best_chain", 1.0),
		ShareCard.emoji(_share_rows()), " · ".join(about.filter(func(s): return s != "")), PLAY_URL]


## The same result for the share picture: [text, size, colour] lines under the game's name.
func _share_lines() -> Array:
	var num := Curses.day_number(_daily_date)
	var result := "Fell on floor %d" % floor_num
	var col := Color(1.0, 0.55, 0.45)
	if _daily_done:
		result = "CLEARED!"
		col = Color(0.55, 1.0, 0.6)
	elif state == State.VICTORY:
		result = "Floor %d of %d beaten" % [floor_num, Curses.DAILY_FLOORS]
		col = Color(1.0, 0.85, 0.45)
	var about := [Heroes.get_hero(hero.hero_id).title if hero else "", Curses.theme(_daily_date).name]
	return [["Daily Crypt #%d%s" % [num, " (practice)" if _daily_practice else ""], 34, Color(0.95, 0.9, 0.8)],
		[result, 50, col],
		["%s points · best chain x%.1f" % [Hud.thousands(score), _rep.get("best_chain", 1.0)], 28, Hud.GOLD],
		[" · ".join(about.filter(func(t): return t != "")), 24, Color(0.8, 0.78, 0.9)]]


## SHARE RESULT: the phone's share menu with the result as words and as a picture.
func _share() -> void:
	Sfx.play("click")
	var picture: Image = await Share.picture(hud, _share_lines(), _share_rows(), _share_caption())
	hud.share_done(Share.send(_share_text(), picture))


## The Daily Crypt as ShareCard codes: one row per floor, one code per room.
func _share_rows() -> Array:
	var per_floor := _run.size()
	var cleared := (floor_num - 1) * per_floor + _room_index + (1 if state == State.VICTORY else 0)
	var chains: Array = _rep.get("chains", [])
	var first := cleared - chains.size()   # rooms before a continued run have no chain on record
	var rows := []
	for f in Curses.DAILY_FLOORS:
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


## Daily Crypt end screens show the result card and SHARE RESULT.
func _show_share_card() -> void:
	if not daily:
		hud.show_share(false)
		return
	hud.show_share(true, _share_rows(), _share_caption())


func _share_caption() -> String:
	var days := Curses.streak(_load_save())
	return "%d days in a row!" % days if days >= 2 else "Play tomorrow to start a streak"


## The Pass was bought, restored or refunded, or Google Play sent the price.
func _on_store_changed() -> void:
	if hud.pass_visible():
		hud.show_pass(true, Store.owned(), Store.instance.price, Store.instance.status)
	if hud.title_visible():
		hud.show_title(true, _best_text(), coins)
	if hud.heroes_visible():
		hud.show_heroes(true, _hero_rows(), coins)
	if hud.armory_visible() and hud._shop_curses:
		_show_curses()
	if hud.daily_visible():
		_show_daily()
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
	for v: Dictionary in Armory.VAULT:
		var u := Upgrades.get_def(v.id)
		var has := Armory.vault_has(cfg, v.id)
		rows.append({"id": v.id, "title": u.title, "text": u.text, "level": 1 if has else 0, "max": 1,
			"cost": -1 if has else int(v.cost), "vault": u})
	return rows


func _buy_upgrade(id: String) -> void:
	var cfg := _load_save()
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
		return


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


func _best_text() -> String:
	var cfg := _load_save()
	var wins := int(cfg.get_value("stats", "wins", 0))
	var best := int(cfg.get_value("stats", "best_room", 0))
	var deepest := int(cfg.get_value("stats", "best_floor", 1))
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
