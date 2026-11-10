class_name SpeedTest
extends Node
## SPEED TEST (Settings, on the title): one minute of busy fighting that plays itself, the
## same every time, so two builds (or two phones) can be compared fairly.
## Three 20-second rooms (the Bone Crypt, the Ember Catacomb and the Glowcap Grotto) keep
## about 14 skeletons up at once around the same room, with the hero on the title. The hero
## walks, stops to shoot, dashes and uses the special, takes hits but can't fall.
## Nothing is saved (Game.bench stops every save): coins, records, Mastery, the Bone Road and
## a saved run stay exactly as they were. The result shows on the title, goes to the reports
## when they're on, and is kept in user://speed_test.cfg so the next test can show it beside
## the new one. Robot: `-- autoplay speedtest [shots=DIR]` runs it, prints SPEEDTEST and quits.

const FLOORS := [1, 3, 4]
const SEGMENT := 20.0
## The first second of each room isn't counted (the fade and the room appearing).
const SETTLE := 1.0
const CROWD := 14
const KINDS := {1: ["m", "w", "a", "g", "m", "x", "w", "s"], 3: ["m", "w", "e", "a", "g", "e", "x", "w"],
	4: ["m", "p", "w", "r", "a", "p", "g", "w"]}
const HISTORY := "user://speed_test.cfg"
const SEED := 1337
## Where the hero walks: a slow loop around the near half of the room.
const SPOTS := [Vector3(-2.6, 0, 5.0), Vector3(2.6, 0, 5.0), Vector3(2.6, 0, 2.0), Vector3(-2.6, 0, 2.0)]

var _rng := RandomNumberGenerator.new()
var _seg := -1
var _t := 0.0
var _busy := false   # a room is loading, or the test is ending
var _done := false
var _walk_t := 0.0
var _spot := 0
var _dash_t := 3.0
var _last_us := 0
var _made := 0
## Measured frames (ms), and each room's frames and time.
var _frames := PackedFloat32Array()
var _seg_frames := [0, 0, 0]
var _seg_time := [0.0, 0.0, 0.0]
var _draws := 0.0
var _prims := 0.0
var _samples := 0
var _mem_peak := 0
var _video_peak := 0
var _mem_t := 0.0
var _vibration := true
var _stop: Button
var _ui: Control
var _robot := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # it notices a pause (and stops) even while paused
	_robot = "speedtest" in OS.get_cmdline_user_args()
	_rng.seed = SEED
	seed(SEED)
	_vibration = Game.vibration
	Game.vibration = false
	Game.bench_begin()
	_build_ui()
	Game.hud.tip("SPEED TEST: one minute, the game plays itself.\nNothing is saved.", 3.0, 0.6)
	_next_room()


func _build_ui() -> void:
	_ui = Control.new()
	Hud.full(_ui)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.hud.add_child(_ui)
	# One small button in the bottom-left corner (the DASH and special buttons are on the
	# right): the time left, and a tap stops the test.
	_stop = Hud.button("STOP TEST  1:00", 18, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_stop.anchor_left = 0.0
	_stop.anchor_right = 0.0
	_stop.anchor_top = 1.0
	_stop.anchor_bottom = 1.0
	_stop.offset_left = 20
	_stop.offset_right = 220
	_stop.offset_top = -92
	_stop.offset_bottom = -36
	_stop.pressed.connect(func(): _finish(true))
	_ui.add_child(_stop)


func _next_room() -> void:
	_seg += 1
	if _seg >= FLOORS.size():
		_finish(false)
		return
	_busy = true
	_t = 0.0
	await Game.bench_room(FLOORS[_seg])
	if _done:
		return
	_last_us = 0
	_busy = false


func _process(delta: float) -> void:
	if _done or _busy:
		_last_us = 0
		return
	# A pause (the pause button, Android Back, or the app sent to the background) stops it.
	if Game.state != Game.State.PLAYING or get_tree().paused:
		_finish(true)
		return
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	_t += delta
	if _t >= SETTLE and ms > 0.0:
		_frames.append(ms)
		_seg_frames[_seg] += 1
		_seg_time[_seg] += ms / 1000.0
		_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		_samples += 1
	_mem_t -= delta
	if _mem_t <= 0.0:
		_mem_t = 1.0
		_mem_peak = maxi(_mem_peak, Game._proc_kb("/proc/self/status", "VmRSS:") / 1024)
		_video_peak = maxi(_video_peak, Game._video_mb())
	var left := maxf(0.0, SEGMENT * (FLOORS.size() - _seg) - _t)
	_stop.text = "STOP TEST  %d:%02d" % [int(ceil(left)) / 60, int(ceil(left)) % 60]
	_crowd()
	_drive(delta)
	if _robot and _t >= 9.0 and _t - delta < 9.0:
		_robot_shot("speedtest_%d.png" % _seg)
		if "speedstop" in OS.get_cmdline_user_args():
			_finish(true)   # (robot: STOP TEST)
	if _t >= SEGMENT:
		_next_room()


## Keeps about CROWD skeletons up, a few new ones a frame, in the far half of the room.
func _crowd() -> void:
	var room := Room.current
	var hero := Game.hero
	if room == null or hero == null:
		return
	var kinds: Array = KINDS[FLOORS[_seg]]
	var n := 0
	while Game.alive_enemies < CROWD and n < 3:
		n += 1
		for i in 12:
			var p := Vector3(_rng.randf_range(-Room.HALF_W + 1.2, Room.HALF_W - 1.2), 0, _rng.randf_range(-Room.HALF_L + 2.0, 0.5))
			if room.is_walkable(p, 0.7) and p.distance_to(hero.global_position) > 4.5:
				Game.spawn_enemy(kinds[_made % kinds.size()], p)
				_made += 1
				break


## The hero walks to the next spot for under a second, then stands and shoots for two;
## dashes every 6 seconds and uses the special when it's ready.
func _drive(delta: float) -> void:
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	hero.health = hero.max_health
	_walk_t += delta
	var stick := Vector2.ZERO
	if fmod(_walk_t, 3.0) < 0.8:
		var to: Vector3 = SPOTS[_spot] - hero.global_position
		to.y = 0.0
		if to.length() > 0.4:
			stick = Vector2(to.x, to.z).normalized()
	elif fmod(_walk_t, 3.0) < 0.8 + delta * 1.5:
		_spot = (_spot + 1) % SPOTS.size()
	Game.hud.joystick = stick
	_dash_t -= delta
	if _dash_t <= 0.0 and hero.dash_ready():
		_dash_t = 6.0
		hero.dash(Vector3(1 if _rng.randf() < 0.5 else -1, 0, 0))
	if hero.special_ready() and Game.alive_enemies >= 6:
		hero.use_special()


func _finish(stopped: bool) -> void:
	if _done:
		return
	_done = true
	Game.hud.joystick = Vector2.ZERO
	var r := _result(stopped)
	if _ui:
		_ui.queue_free()
	Game.vibration = _vibration
	await Game.bench_end()
	if _robot:
		print("[speedtest] back on the title, saving again: %s" % (not Game.bench))
	var before := _history()
	if not stopped:
		_keep(r)
		var body := _report_text(r, before)
		print("SPEEDTEST " + body.replace("\n", " | "))
		if Telemetry.instance:
			Telemetry.instance.send("bench", body)
	_show(r, before)
	if _robot:
		await get_tree().create_timer(1.0).timeout
		_robot_shot("speedtest_result.png")
		get_tree().quit()
	queue_free()


## Robot runs with shots=DIR: a picture of the screen.
func _robot_shot(file: String) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shots="):
			DirAccess.make_dir_recursive_absolute(a.substr(6))
			get_viewport().get_texture().get_image().save_png(a.substr(6).path_join(file))


func _result(stopped: bool) -> Dictionary:
	var r := {"stopped": stopped, "build": Game.BUILD, "graphics": Game.GRAPHICS_NAMES[Game.graphics_level],
		"cap": Engine.max_fps, "date": Time.get_date_string_from_system()}
	var n := _frames.size()
	if n == 0:
		r.fps = 0
		return r
	var total := 0.0
	for ms in _frames:
		total += ms
	var sorted := _frames.duplicate()
	sorted.sort()
	r.fps = n / maxf(0.001, total / 1000.0)
	r.low1 = 1000.0 / maxf(1.0, sorted[mini(n - 1, int(n * 0.99))])
	r.worst = sorted[n - 1]
	var limit := 1000.0 / maxf(1.0, Engine.max_fps) * 1.25
	var ok := 0
	for ms in _frames:
		if ms <= limit:
			ok += 1
	r.steady = float(ok) / n
	r.rooms = []
	for i in FLOORS.size():
		r.rooms.append(roundi(_seg_frames[i] / _seg_time[i]) if _seg_time[i] > 0.0 else 0)
	r.draws = roundi(_draws / maxf(1, _samples))
	r.tris = roundi(_prims / maxf(1, _samples) / 1000.0)
	r.mem = _mem_peak
	r.video = _video_peak
	r.size = Game._draw_size_text()
	return r


## How it felt, in words, from the share of frames on time.
static func verdict(r: Dictionary) -> String:
	var s: float = r.get("steady", 0.0)
	if s >= 0.95:
		return "Silky smooth"
	if s >= 0.85:
		return "Smooth"
	if s >= 0.65:
		return "A little choppy"
	return "Choppy"


static func _report_text(r: Dictionary, before: Dictionary) -> String:
	var lines := []
	lines.append("Speed test: %s | FPS avg %d, 1%% low %d, steady %d%%, worst frame %d ms | limit %d" % [verdict(r),
		roundi(r.fps), roundi(r.low1), roundi(r.steady * 100.0), roundi(r.worst), r.cap])
	lines.append("Rooms: Bone Crypt %d, Ember Catacomb %d, Glowcap Grotto %d FPS" % r.rooms)
	lines.append("Graphics %s (3D %s) | draws %d, triangles %dk | memory %d MB (graphics %d MB) | phone RAM %s" % [r.graphics, r.size,
		r.draws, r.tris, r.mem, r.video, Game.ram_text()])
	if not before.is_empty():
		lines.append("Last test: build %s, %s, FPS avg %d, 1%% low %d, steady %d%%" % [before.build, before.graphics,
			roundi(before.fps), roundi(before.low1), roundi(before.steady * 100.0)])
	return "\n".join(lines)


func _history() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(HISTORY) != OK:
		return {}
	var d = cfg.get_value("tests", "last", {})
	return d if d is Dictionary and d.has("fps") else {}


func _keep(r: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(HISTORY)
	cfg.set_value("tests", "last", r)
	cfg.save(HISTORY)


## The result card on the title.
func _show(r: Dictionary, before: Dictionary) -> void:
	var box := Hud.overlay(Color(0.03, 0.02, 0.05, 0.94))
	box.visible = true
	Game.hud.add_child(box)
	Game.speed_card = box   # Android Back closes it
	var col := VBoxContainer.new()
	Hud.full(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	col.add_child(Hud.label("SPEED TEST", 44, Color(1, 0.85, 0.55)))
	if r.get("stopped", false) or r.fps <= 0:
		col.add_child(Hud.label("Stopped early, so there's no result.", 22, Color(0.85, 0.8, 0.9)))
	else:
		var good: bool = r.steady >= 0.85
		col.add_child(Hud.label("%d FPS" % roundi(r.fps), 64, Color(0.55, 1.0, 0.6) if good else Color(1, 0.75, 0.4)))
		col.add_child(Hud.label(verdict(r), 30, Color(1, 0.93, 0.8)))
		var lines := [
			"Slowest 1%% of frames: %d FPS" % roundi(r.low1),
			"Frames on time: %d%%" % roundi(r.steady * 100.0),
			"Bone Crypt %d · Ember %d · Glowcap %d FPS" % r.rooms,
			"Graphics: %s · memory %d MB" % [r.graphics, r.mem],
		]
		if not before.is_empty():
			lines.append("Last test (build %s, %s): %d FPS" % [before.build, before.graphics, roundi(before.fps)])
		for t in lines:
			col.add_child(Hud.label(t, 20, Color(0.85, 0.8, 0.9)))
		if not good and Game.graphics_level > 0:
			col.add_child(Hud.label("Tip: Graphics: %s may feel smoother." % Game.GRAPHICS_NAMES[Game.graphics_level - 1], 20, Color(1, 0.8, 0.45)))
		if Telemetry.instance and Telemetry.instance.enabled():
			col.add_child(Hud.label("Sent with your reports.", 16, Color(0.6, 0.57, 0.65)))
	var ok := Hud.button("OK", 28)
	ok.custom_minimum_size = Vector2(220, 74)
	ok.pressed.connect(func():
		Sfx.play("click")
		box.queue_free())
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ok)
	col.add_child(c)
