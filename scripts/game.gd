extends Node
## The game manager (loaded automatically as "Game"). Runs the title screen, the rooms of
## a floor, blessing picks, the boss, and the win/lose screens. It builds the whole world
## from code, so there is nothing to set up by hand.

enum State { TITLE, PLAYING, UPGRADE, TRANSITION, PAUSED, DEAD, VICTORY }

const EASY_ROOMS := 2
const MEDIUM_ROOMS := 2
const HARD_ROOMS := 1
const SAVE_PATH := "user://save.cfg"

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
var _run: Array = []
var _room_index := 0
var _taken := {}
var rerolls := 1
var _kills := 0
var _run_time := 0.0
var _state_time := 0.0
var _state_before_pause := State.PLAYING
var _hit_stop_left := 0.0
var _choices: Array = []
var _exit_arrow: Node3D
var _start_blessing := {}
var _env: Environment
## Run report: numbers collected during a run so Jesse can paste them back for balancing.
const BUILD := "2026-10-25m"
var hit_source := ""
var _last_report := ""
var _rep := {}
var _fps_sum := 0.0
var _fps_n := 0
var _fps_low := 999.0
var _fps_t := 0.0
var _high_graphics := true
var _combo := 0
## Bone Chain: kills close together grow a multiplier on damage and coins.
## +0.1 per kill (+0.3 for elites), up to x3, gone after 2.5 s without a kill.
var chain := 1.0

func chain_max() -> float:
	return 4.0 if hero and hero.perks.has("marrow") else 3.0


func chain_time() -> float:
	return 3.5 if hero and hero.perks.has("links") else 2.5


## Damage gets a quarter of the chain's bonus (x1.5 at the cap) so a long chain doesn't trivialise rooms.
func chain_damage() -> float:
	return 1.0 + (chain - 1.0) * 0.25


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


## True until the first run has ended. Older saves that already got somewhere count as done.
func first_run_pending() -> bool:
	var cfg := _load_save()
	if bool(cfg.get_value("stats", "first_run_done", false)):
		return false
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


func _finish_first_run() -> void:
	if not first_run:
		return
	var cfg := _load_save()
	cfg.set_value("stats", "first_run_done", true)
	cfg.save(SAVE_PATH)


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
	hud.retry_pressed.connect(func(): if state == State.DEAD and not hud.armory_visible(): _on_screen_tapped())
	hud.music_toggled.connect(_set_music)
	hud.sounds_toggled.connect(_set_sounds)
	hud.graphics_toggled.connect(_set_graphics)
	hud.reports_toggled.connect(_set_reports)
	hud.dash_flicked.connect(func(d: Vector2): if hero: hero.dash(Vector3(d.x, 0, d.y)))

	var cfg := _load_save()
	coins = int(cfg.get_value("stats", "coins", 0))
	_set_music(bool(cfg.get_value("settings", "music", true)), false)
	_set_sounds(bool(cfg.get_value("settings", "sounds", true)), false)
	_set_graphics(bool(cfg.get_value("settings", "high_graphics", true)), false)
	hud.set_reports_label(bool(cfg.get_value("settings", "reports", true)), Telemetry.configured())
	Engine.max_fps = 60   # no need to drain the battery past what phones show
	hud.set_coins(coins)

	_build_run()
	_load_room(0, false)
	hero.place_at(Vector3(0, 0, 2))
	_snap_camera()
	_set_state(State.TITLE)
	hud.show_hud(false)
	hud.show_title(true, _best_text(), coins)
	hud.set_title_hero(Heroes.get_hero(hero.hero_id).title)
	Music.play("dungeon")
	_fade(1.0, 0.0, 0.6)
	if "autoplay" in OS.get_cmdline_user_args():
		add_child(Autoplay.new())


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
	env.glow_intensity = 0.6
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
	if state == State.PLAYING:
		_run_time += delta
		_fps_t += delta
		if _fps_t >= 1.0:
			_fps_t = 0.0
			var f := Engine.get_frames_per_second()
			_fps_sum += f
			_fps_n += 1
			_fps_low = minf(_fps_low, f)
		if _combo_left > 0.0:
			_combo_left -= delta
			if _combo_left <= 0.0:
				_break_chain()
	if _hit_stop_left > 0.0:
		_hit_stop_left -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop_left <= 0.0:
			Engine.time_scale = 0.12 if _lesson_left > 0.0 else 1.0
	_update_dash_lesson(delta / maxf(Engine.time_scale, 0.01))
	_update_camera(delta / maxf(Engine.time_scale, 0.01))
	_update_exit_arrow()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state == State.PLAYING:
			_pause()
		if Telemetry.instance:
			Telemetry.instance.session_open(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if Telemetry.instance:
			Telemetry.instance.session_open(true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Telemetry.instance:
			Telemetry.instance.session_open(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android's back button pauses the game; from the pause or title screen it leaves.
		if hud.armory_visible():
			hud.show_armory(false)
			return
		match state:
			State.PLAYING:
				_pause()
			State.PAUSED, State.TITLE, State.DEAD, State.VICTORY:
				if Telemetry.instance:
					Telemetry.instance.session_open(false)
				get_tree().quit()


## How much tougher skeletons are on the current floor.
## Skeleton health grows 55% per floor (compounding), so it keeps pace with a hero whose
## blessings stack up. Floor 4 skeletons have about 3.7x their floor 1 health.
## From floor 5 on it grows 70% per floor, because a hero that deep is very strong.
func health_scale() -> float:
	return pow(1.55, mini(floor_num, 4) - 1) * pow(1.7, maxi(floor_num - 4, 0))


## Skeletons hit 35% harder per floor, and 50% per floor from floor 5 on.
func damage_scale() -> float:
	return 1.0 + 0.35 * (floor_num - 1) + 0.15 * maxi(floor_num - 4, 0)


func speed_scale() -> float:
	return minf(1.3, 1.0 + 0.05 * (floor_num - 1))


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
func finisher(pos: Vector3, time_scale: float, seconds: float, col := Color(1, 0.85, 0.5)) -> void:
	Engine.time_scale = time_scale
	_hit_stop_left = maxf(_hit_stop_left, seconds)
	_zoom_point = pos
	_zoom_hold = seconds + 0.25
	Fx.shockwave(pos, col)
	hud.flash(Color(1, 0.95, 0.85), 0.35)
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
	var cfg := _load_save()
	_perfect_total = int(cfg.get_value("stats", "perfect_total", 0)) + 1
	cfg.set_value("stats", "perfect_total", _perfect_total)
	cfg.save(SAVE_PATH)


## The DASH button dashes the way you're moving, or the way you face if you're still.
func _dash_from_button() -> void:
	if hero == null:
		return
	var m := hud.joystick + keyboard_move()
	hero.dash(Vector3(m.x, 0, m.y) if m.length() > 0.2 else -hero.global_transform.basis.z)


## Dash lessons: until you've pulled off a few perfect dodges, a shot about to hit you
## freezes time for a moment and the game tells you to dash through it.
var _lesson_left := 0.0
var _lessons_this_run := 0
var _perfect_total := -1


func dash_lesson_active() -> bool:
	return _lesson_left > 0.0


func _update_dash_lesson(real_delta: float) -> void:
	if _lesson_left > 0.0:
		_lesson_left -= real_delta
		if _lesson_left <= 0.0 or state != State.PLAYING or hero == null or hero.is_dashing():
			_end_dash_lesson()
		return
	if state != State.PLAYING or hero == null or not hero.dash_ready() or _lessons_this_run >= 2 or _hit_stop_left > 0.0 or not dash_unlocked():
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
	_shake = maxf(_shake, amount)


## A tiny freeze when something is hit hard. Small touches like this make combat feel good.
func hit_stop(seconds: float) -> void:
	if state != State.PLAYING:
		return
	Engine.time_scale = 0.05
	_hit_stop_left = maxf(_hit_stop_left, seconds)


# ---------------------------------------------------------------- run flow

func _build_run() -> void:
	_run.clear()
	for pair in [[Layouts.EASY, EASY_ROOMS], [Layouts.MEDIUM, MEDIUM_ROOMS], [Layouts.HARD, HARD_ROOMS]]:
		var pool: Array = (pair[0] as Array).duplicate()
		pool.shuffle()
		for i in mini(pair[1], pool.size()):
			_run.append(pool[i])
	_run.append(Layouts.BOSS)


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
			if _state_time > 1.5:
				_descend()
		State.PAUSED:
			_resume()


func _on_play_pressed() -> void:
	if state == State.TITLE:
		Sfx.play("click")
		_start_run()


func _start_run() -> void:
	first_run = first_run_pending() or _tutorial_requested
	_tutorial_requested = false
	hud.show_title(false)
	hud.show_armory(false)
	hud.show_hud(true)
	_reset_run_stats()
	_apply_armory()
	_go_to_room(0)


func _reset_report() -> void:
	_rep = {"damage": {}, "hits": 0, "healed": 0.0, "dash": 0, "ward": 0, "second_wind": 0,
		"best_combo": 0, "best_chain": 1.0, "perfect": 0, "special": 0, "rooms": [], "room_start": 0.0, "killed_by": ""}
	_fps_sum = 0.0
	_fps_n = 0
	_fps_low = 999.0


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


## The text that the COPY RUN REPORT button puts on the clipboard.
func run_report(result: String) -> String:
	var cfg := _load_save()
	var lines := []
	lines.append("Bone Chain run report (build %s, install %s)" % [BUILD, Telemetry.install_id(cfg)])
	lines.append("Hero: %s | %s | Time %s" % [Heroes.get_hero(hero.hero_id).title if hero else "?", result, _format_time(_run_time)])
	lines.append("Score %d | First run %s" % [score, "yes" if first_run else "no"])
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
	lines.append("Graphics %s | FPS avg %d, lowest %d" % ["High" if _high_graphics else "Low",
		roundi(_fps_sum / maxf(1.0, _fps_n)), roundi(_fps_low if _fps_low < 999.0 else 0.0)])
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


## Gives the hero everything bought in the Armory. Called once at the start of each run.
func _apply_armory() -> void:
	var cfg := _load_save()
	Armory.apply_to_hero(cfg, hero)
	heart_bonus = Armory.heart_bonus(cfg)
	if Armory.level(cfg, "blessed") > 0:
		var pick := Upgrades.roll(_taken, 1)
		if not pick.is_empty():
			var u: Dictionary = pick[0]
			_taken[u.id] = 1
			Upgrades.apply(u.id, hero)
			_start_blessing = u


func _restart() -> void:
	_set_state(State.TRANSITION)
	await _fade(0.0, 1.0, 0.4)
	hud.show_end(false)
	if hero:
		hero.queue_free()
		hero = null
	_build_run()
	_reset_run_stats()
	first_run = false
	hud.show_hud(true)
	_load_room(0, false)
	_apply_armory()
	_load_room(0, true)
	await _fade(1.0, 0.0, 0.4)


## From the pause menu: give up this run and go back to the title (coins are kept).
func _quit_to_title() -> void:
	if state != State.PAUSED:
		return
	hud.show_pause(false)
	get_tree().paused = false
	Telemetry.instance.send("run", run_report("Quit on floor %d, room %d" % [floor_num, _room_index + 1]))
	_set_state(State.TRANSITION)
	_save_coins()
	await _fade(0.0, 1.0, 0.4)
	_clear_enemy_attacks()
	if hero:
		hero.queue_free()
		hero = null
	_build_run()
	floor_num = 1
	_load_room(0, false)
	hero.place_at(Vector3(0, 0, 2))
	_snap_camera()
	hud.show_hud(false)
	hud.hide_boss()
	hud.show_hint("")
	hud.show_title(true, _best_text(), coins)
	Music.play("dungeon")
	_set_state(State.TITLE)
	await _fade(1.0, 0.0, 0.4)


## After beating the king: keep your blessings and go one floor deeper, where it's harder.
func _descend() -> void:
	_set_state(State.TRANSITION)
	await _fade(0.0, 1.0, 0.5)
	hud.show_end(false)
	floor_num += 1
	hero.heal(hero.max_health * 0.3)
	_build_run()
	_load_room(0, true)
	hud.banner("Floor %d: %s" % [floor_num, Floors.current().name], Floors.current().banner)
	await _fade(1.0, 0.0, 0.5)


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
	alive_enemies = 0
	boss = null
	var room := Room.build(world, _run[index], "Boss" if _in_boss_room() else str(index + 1))
	var look := Floors.current()
	_env.ambient_light_color = look.ambient
	_env.fog_light_color = look.fog
	_env.background_color = look.background
	_moon.light_color = look.moon
	Fx.ambience(room, Room.HALF_W - 0.5, Room.HALF_L - 0.5, 36 if _high_graphics else 14, look.motes, look.motes_fall)
	if hero == null:
		hero = Hero.spawn(world, room.player_start(), Heroes.selected(_load_save()))
	hero.place_at(room.player_start())
	hero.new_room()
	_snap_camera()
	if not spawn_enemies:
		return
	hud.set_room(index + 1, _combat_rooms(), _in_boss_room(), floor_num)
	if not _rep.is_empty():
		_rep.room_start = _run_time
	if not _in_boss_room():
		hud.banner("Room %d" % (index + 1))
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
	for s in room.spawns:
		var kind: String = s.kind
		if kind == "K" and floor_num % 2 == 0:
			kind = "L"   # every second floor is ruled by the Lich instead
		var e := spawn_enemy(kind, s.pos)
		if _roll_elite(e, index):
			e.make_elite()
		_wave_kinds.append(kind)
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


func spawn_enemy(kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.create(kind, Room.current, pos)
	alive_enemies += 1
	if e.is_boss:
		boss = e
		hud.set_boss_name(e.display_name())
	return e


## Now and then a skeleton is a golden elite. Never in the very first room, and more
## often the deeper you go.
func _roll_elite(e: Enemy, room_index: int) -> bool:
	if e.is_boss or e is SkeletonBomber or (floor_num == 1 and room_index == 0):
		return false
	return randf() < minf(0.3, 0.07 + 0.05 * (floor_num - 1))


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
	if chain_unlocked():
		chain = minf(chain_max(), chain + (0.3 if e.elite else 0.1))
	score += roundi((BOSS_POINTS if e == boss else (ELITE_POINTS if e.elite else KILL_POINTS)) * chain)
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
	if e == boss:
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
	# Later waves bring one extra skeleton.
	kinds.append(kinds[0])
	# First run, room 2: there's always an archer, so the dash lesson has arrows to teach with.
	if ftue_room() == 2 and not kinds.has("a"):
		kinds[0] = "a"
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
	# Straight to the blessing cards once the slow-motion finish has played.
	await get_tree().create_timer(0.75, true, false, true).timeout
	if state != State.PLAYING:
		return
	var step := ftue_room()
	_choices = Upgrades.roll_commons(_taken) if step == 1 else Upgrades.roll(_taken, 3, step == 4)
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
	_choices = Upgrades.roll(_taken)
	Sfx.play("click")
	hud.show_cards(_choices, rerolls, true)


func _on_card_picked(i: int) -> void:
	if state != State.UPGRADE or i >= _choices.size():
		return
	var u: Dictionary = _choices[i]
	_taken[u.id] = _taken.get(u.id, 0) + 1
	Upgrades.apply(u.id, hero)
	get_tree().paused = false
	_set_state(State.PLAYING)
	Sfx.play("upgrade")
	Fx.magic(hero.center(), Upgrades.color(u), 30)
	hud.banner(u.title, Upgrades.color(u))
	# No walk to the door: anything left on the floor is picked up and the next room starts.
	Pickup.grant_all()
	_save_coins()
	enter_next_room()


## Removes skeleton arrows and warning markers still in the air once a fight is over.
func _clear_enemy_attacks() -> void:
	if Room.current == null:
		return
	for n in Room.current.get_children():
		if n is Projectile and (n as Projectile).owner_team == Actor.Team.UNDEAD:
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
	var was_first := first_run
	_finish_first_run()
	Music.play("dungeon")
	hud.show_end(true, true, "%s of floor %d has fallen.\n\nTime  %s\nSkeletons destroyed  %d\nCoins this run  %d%s" % [boss_name, floor_num, _format_time(_run_time), _kills, run_coins,
		"\n\nHeroes and the Armory are open!" if was_first else ""],
		"Tap to descend to floor %d" % (floor_num + 1), false, score, best)
	_state_time = 0.0
	_last_report = run_report("Beat floor %d" % floor_num)
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)


func on_hero_died() -> void:
	if state == State.DEAD or state == State.VICTORY:
		return
	_set_state(State.DEAD)
	_save_coins()
	Sfx.play("vo_lose", 0.8)
	await get_tree().create_timer(1.4, true, false, true).timeout
	var cfg := _load_save()
	var best := _save_score(cfg)
	_save_best(cfg, _room_index + 1)
	var was_first := first_run
	_finish_first_run()
	var where := "the throne room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]
	if floor_num > 1:
		where += " on floor %d" % floor_num
	var coin_line := "You earned %d coins.\nSpend them in the Armory!" % run_coins if was_first else "Coins kept  %d  (spend them in the Armory)" % run_coins
	hud.show_end(true, false, "You fell in %s.\n\nTime  %s\nSkeletons destroyed  %d\n%s" % [where, _format_time(_run_time), _kills, coin_line],
		"", true, score, best)
	_state_time = 0.0
	_last_report = run_report("Died on floor %d, %s" % [floor_num, "boss room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]])
	print("[report]\n" + _last_report)
	Telemetry.instance.send("run", _last_report)


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
	cfg.load(SAVE_PATH)
	return cfg


func add_coins(n: int) -> void:
	coins += n
	run_coins += n
	hud.set_coins(coins)


func _save_coins() -> void:
	var cfg := _load_save()
	cfg.set_value("stats", "coins", coins)
	cfg.save(SAVE_PATH)


func _set_music(on: bool, save := true) -> void:
	Music.set_enabled(on)
	hud.set_toggles(Music.enabled, Sfx.enabled)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "music", on)
		cfg.save(SAVE_PATH)


func _set_sounds(on: bool, save := true) -> void:
	Sfx.enabled = on
	hud.set_toggles(Music.enabled, Sfx.enabled)
	if save:
		var cfg := _load_save()
		cfg.set_value("settings", "sounds", on)
		cfg.save(SAVE_PATH)


## High looks best; Low turns off shadows and glow and draws the 3D world at a lower
## resolution, for smoother play on older phones.
func _set_reports(on: bool) -> void:
	var cfg := _load_save()
	cfg.set_value("settings", "reports", on)
	cfg.save(SAVE_PATH)
	hud.set_reports_label(on, Telemetry.configured())
	Sfx.play("click")


## A short "where are we" line for error and crash reports.
func where_text() -> String:
	return "%s, floor %d room %d, %s, %s into the run" % [State.keys()[state], floor_num, _room_index + 1,
		hero.hero_id if hero else "no hero", _format_time(_run_time)]


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
		var cfg := _load_save()
		cfg.set_value("settings", "high_graphics", high)
		cfg.save(SAVE_PATH)


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
		rows.append({"id": h.id, "title": h.title, "text": "%s Special: %s." % [h.text, h.special], "cost": h.cost,
			"unlocked": Heroes.unlocked(cfg, h.id), "selected": h.id == chosen})
	return rows


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
	cfg.save(SAVE_PATH)
	hud.set_title_hero(def.title)
	hud.show_heroes(true, _hero_rows(), coins)
	# On the title screen, swap the hero standing in the room straight away.
	if state == State.TITLE and hero and hero.hero_id != id:
		var at := hero.global_position
		hero.queue_free()
		hero = Hero.spawn(world, at, id)
		Fx.magic(hero.center(), def.bolt_color, 30)


func _armory_rows() -> Array:
	var cfg := _load_save()
	var rows := []
	for u: Dictionary in Armory.LIST:
		rows.append({"id": u.id, "title": u.title, "text": u.text, "level": Armory.level(cfg, u.id),
			"max": u.max, "cost": Armory.next_cost(cfg, u)})
	return rows


func _buy_upgrade(id: String) -> void:
	var cfg := _load_save()
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
		cfg.save(SAVE_PATH)
		Sfx.play("upgrade")
		hud.set_coins(coins)
		hud.show_armory(true, _armory_rows(), coins)
		hud.show_title(hud.title_visible(), _best_text(), coins)
		return


## Saves the best score and returns the best from before this run.
func _save_score(cfg: ConfigFile) -> int:
	var best := int(cfg.get_value("stats", "best_score", 0))
	if score > best:
		cfg.set_value("stats", "best_score", score)
	return best


func _save_best(cfg: ConfigFile, room_reached: int) -> void:
	if floor_num > int(cfg.get_value("stats", "best_floor", 1)):
		cfg.set_value("stats", "best_floor", floor_num)
	if room_reached > int(cfg.get_value("stats", "best_room", 0)):
		cfg.set_value("stats", "best_room", room_reached)
	cfg.save(SAVE_PATH)


func _best_text() -> String:
	var cfg := _load_save()
	var wins := int(cfg.get_value("stats", "wins", 0))
	var best := int(cfg.get_value("stats", "best_room", 0))
	var deepest := int(cfg.get_value("stats", "best_floor", 1))
	var top := int(cfg.get_value("stats", "best_score", 0))
	if top > 0:
		return "Best score %s  ·  Deepest floor %d" % [Hud.thousands(top), deepest]
	if wins > 0:
		return "Bosses defeated: %d  ·  Deepest floor: %d" % [wins, deepest]
	if best > 0:
		return "Deepest room reached: %d" % best
	return ""


static func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
