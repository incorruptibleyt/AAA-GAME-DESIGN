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
var _kills := 0
var _run_time := 0.0
var _state_time := 0.0
var _state_before_pause := State.PLAYING
var _hit_stop_left := 0.0
var _choices: Array = []
var _exit_arrow: Node3D
var _start_blessing := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	add_child(Sfx.new())
	add_child(Music.new())
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
	hud.screen_tapped.connect(_on_screen_tapped)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.play_pressed.connect(_on_play_pressed)
	hud.armory_pressed.connect(_open_armory)
	hud.armory_buy.connect(_buy_upgrade)
	hud.resume_pressed.connect(func(): if state == State.PAUSED: _resume())
	hud.quit_run_pressed.connect(_quit_to_title)
	hud.retry_pressed.connect(func(): if state == State.DEAD and not hud.armory_visible(): _on_screen_tapped())
	hud.music_toggled.connect(_set_music)
	hud.sounds_toggled.connect(_set_sounds)

	var cfg := _load_save()
	coins = int(cfg.get_value("stats", "coins", 0))
	_set_music(bool(cfg.get_value("settings", "music", true)), false)
	_set_sounds(bool(cfg.get_value("settings", "sounds", true)), false)
	hud.set_coins(coins)

	_build_run()
	_load_room(0, false)
	hero.place_at(Vector3(0, 0, 2))
	_snap_camera()
	_set_state(State.TITLE)
	hud.show_hud(false)
	hud.show_title(true, _best_text(), coins)
	Music.play("dungeon")
	_fade(1.0, 0.0, 0.6)
	if "autoplay" in OS.get_cmdline_user_args():
		add_child(Autoplay.new())


func _setup_environment() -> void:
	var env := Environment.new()
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
	if _hit_stop_left > 0.0:
		_hit_stop_left -= delta / maxf(Engine.time_scale, 0.01)
		if _hit_stop_left <= 0.0:
			Engine.time_scale = 1.0
	_update_camera(delta / maxf(Engine.time_scale, 0.01))
	_update_exit_arrow()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state == State.PLAYING:
			_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android's back button pauses the game; from the pause or title screen it leaves.
		if hud.armory_visible():
			hud.show_armory(false)
			return
		match state:
			State.PLAYING:
				_pause()
			State.PAUSED, State.TITLE, State.DEAD, State.VICTORY:
				get_tree().quit()


## How much tougher skeletons are on the current floor.
func health_scale() -> float:
	return 1.0 + 0.5 * (floor_num - 1)


func damage_scale() -> float:
	return 1.0 + 0.25 * (floor_num - 1)


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

func _cam_distance() -> float:
	# Pick a distance where the full room width fits on screen, whatever the phone's shape.
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_h := atan(tan(deg_to_rad(CAMERA_FOV) * 0.5) * aspect)
	return maxf(15.0, (Room.HALF_W + 0.4) / tan(half_h))


func _focus_goal() -> Vector3:
	if hero == null:
		return Vector3.ZERO
	# Keep the near wall at the bottom of the screen and the door in view at the top.
	# On a tall phone the whole room fits, so the camera just stays centred.
	var p := deg_to_rad(CAMERA_PITCH)
	var half_v := deg_to_rad(CAMERA_FOV) * 0.5
	var d := _cam_distance()
	var bottom := d * (cos(p) - sin(p) / tan(p + half_v))
	var top := d * (cos(p) - sin(p) / tan(p - half_v))
	var hi := Room.HALF_L + 0.6 - bottom
	var lo := -Room.HALF_L - 2.5 - top
	if lo > hi:
		return Vector3(0, 0, (lo + hi) * 0.5)
	return Vector3(0, 0, clampf(hero.global_position.z - 1.5, lo, hi))


func _place_camera() -> void:
	var p := deg_to_rad(CAMERA_PITCH)
	_camera.rotation = Vector3(-p, 0, 0)
	var pos := _cam_focus + Vector3(0, sin(p), cos(p)) * _cam_distance()
	if _shake > 0.001:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_camera.global_position = pos


func _snap_camera() -> void:
	_cam_focus = _focus_goal()
	_place_camera()


func _update_camera(real_delta: float) -> void:
	_cam_focus = _cam_focus.lerp(_focus_goal(), 1.0 - exp(-8.0 * real_delta))
	_shake = move_toward(_shake, 0.0, real_delta * 2.5)
	_place_camera()


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
	hud.show_title(false)
	hud.show_armory(false)
	hud.show_hud(true)
	_reset_run_stats()
	_apply_armory()
	_go_to_room(0)


func _reset_run_stats() -> void:
	_run_time = 0.0
	_kills = 0
	run_coins = 0
	floor_num = 1
	_taken.clear()


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
	hero.heal(hero.max_health * 0.5)
	_build_run()
	_load_room(0, true)
	hud.banner("Floor %d" % floor_num, Color(1, 0.7, 0.4))
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
	if hero == null:
		hero = Hero.spawn(world, room.player_start())
	hero.place_at(room.player_start())
	_snap_camera()
	if not spawn_enemies:
		return
	hud.set_room(index + 1, _combat_rooms(), _in_boss_room(), floor_num)
	hud.banner("The Throne Room" if _in_boss_room() else "Room %d" % (index + 1))
	hud.show_hint("Drag to move  ·  Let go to shoot" if floor_num == 1 and index == 0 else "")
	Music.play("boss" if _in_boss_room() else "dungeon")
	if not _start_blessing.is_empty():
		var u := _start_blessing
		_start_blessing = {}
		get_tree().create_timer(1.6, false).timeout.connect(func(): hud.banner("Blessed: " + u.title, u.color))
	for s in room.spawns:
		var kind: String = s.kind
		if kind == "K" and floor_num % 2 == 0:
			kind = "L"   # every second floor is ruled by the Lich instead
		spawn_enemy(kind, s.pos)
	_set_state(State.PLAYING)
	if alive_enemies == 0:
		room.open_door()


func spawn_enemy(kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.create(kind, Room.current, pos)
	alive_enemies += 1
	if e.is_boss:
		boss = e
		hud.set_boss_name(e.display_name())
	return e


func on_enemy_died(e: Enemy) -> void:
	alive_enemies = maxi(0, alive_enemies - 1)
	_kills += 1
	hud.show_hint("")
	if state != State.PLAYING:
		return
	if e == boss:
		# Any minions left crumble with their master.
		for a: Actor in Actor.all.duplicate():
			if a != e and a.team == Actor.Team.UNDEAD and not a.dead and a.can_be_hit():
				a.take_damage(9999.0, Vector3.ZERO, 0.0)
		_win()
	elif alive_enemies == 0 and not _in_boss_room():
		_clear_enemy_attacks()
		Pickup.collect_all()
		_room_cleared()


func _room_cleared() -> void:
	_save_coins()
	hud.banner("Room Cleared")
	await get_tree().create_timer(0.9, false).timeout
	if state != State.PLAYING:
		return
	_choices = Upgrades.roll(_taken)
	if _choices.is_empty():
		Room.current.open_door()
		return
	_set_state(State.UPGRADE)
	get_tree().paused = true
	hud.show_cards(_choices)


func _on_card_picked(i: int) -> void:
	if state != State.UPGRADE or i >= _choices.size():
		return
	var u: Dictionary = _choices[i]
	_taken[u.id] = _taken.get(u.id, 0) + 1
	Upgrades.apply(u.id, hero)
	get_tree().paused = false
	_set_state(State.PLAYING)
	Sfx.play("upgrade")
	Fx.magic(hero.center(), u.color, 30)
	Room.current.open_door()
	hud.banner(u.title, u.color)


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
	_set_state(State.VICTORY)
	_clear_enemy_attacks()
	Pickup.collect_all()
	hud.hide_boss()
	await get_tree().create_timer(1.2, true, false, true).timeout
	Sfx.play("victory")
	var cfg := _load_save()
	cfg.set_value("stats", "wins", int(cfg.get_value("stats", "wins", 0)) + 1)
	_save_best(cfg, _run.size())
	Music.play("dungeon")
	hud.show_end(true, true, "%s of floor %d has fallen.\n\nTime  %s\nSkeletons destroyed  %d\nCoins this run  %d" % [boss_name, floor_num, _format_time(_run_time), _kills, run_coins],
		"Tap to descend to floor %d" % (floor_num + 1))
	_state_time = 0.0


func on_hero_died() -> void:
	if state == State.DEAD or state == State.VICTORY:
		return
	_set_state(State.DEAD)
	await get_tree().create_timer(1.4, true, false, true).timeout
	_save_best(_load_save(), _room_index + 1)
	var where := "the throne room" if _in_boss_room() else "room %d of %d" % [_room_index + 1, _combat_rooms()]
	if floor_num > 1:
		where += " on floor %d" % floor_num
	hud.show_end(true, false, "You fell in %s.\n\nTime  %s\nSkeletons destroyed  %d\nCoins kept  %d  (spend them in the Armory)" % [where, _format_time(_run_time), _kills, run_coins],
		"", true)
	_state_time = 0.0


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


# ---------------------------------------------------------------- armory

func _open_armory() -> void:
	if state != State.TITLE and state != State.DEAD:
		return
	Sfx.play("click")
	hud.show_armory(true, _armory_rows(), coins)


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
	if wins > 0:
		return "Bosses defeated: %d  ·  Deepest floor: %d" % [wins, deepest]
	if best > 0:
		return "Deepest room reached: %d" % best
	return ""


static func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
