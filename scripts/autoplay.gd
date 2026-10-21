class_name Autoplay
extends Node
## A simple robot player used to test the game without a person holding the phone.
## Start Godot with:  -- autoplay [god] [shots=<folder>]
## It walks through every room, picks the first blessing each time, and prints what happened.

var god := false
var start_room := 1
var runs := 1
var _paused_once := false
var _dumped_room := -1
var shots_dir := ""
var _t := 0.0
var _next_shot := 1.0
var _shot_n := 0
var _dodge := Vector3.ZERO
var _last_state := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "god":
			god = true
		elif a.begins_with("runs="):
			runs = int(a.substr(5))
		elif a.begins_with("room="):
			start_room = int(a.substr(5))
		elif a.begins_with("shots="):
			shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(shots_dir)


func _process(delta: float) -> void:
	_t += delta
	if Game.state != _last_state:
		_last_state = Game.state
		print("[autoplay] t=%.1f state=%s room=%d hp=%s" % [_t, Game.State.keys()[Game.state], Game._room_index + 1, str(Game.hero.health) if Game.hero else "-"])
		if shots_dir != "" and Game.state in [Game.State.UPGRADE, Game.State.VICTORY, Game.State.DEAD]:
			_shot.call_deferred()
	if shots_dir != "" and _t > _next_shot and Game.state == Game.State.PLAYING:
		_next_shot = _t + 4.0
		_shot()

	match Game.state:
		Game.State.TITLE:
			if shots_dir != "" and _shot_n == 0 and _t > 1.0:
				_shot_n = -1
				_shot()
			if _t > 1.5:
				if start_room > 1:
					Game.hud.show_title(false)
					Game.hud.show_hud(true)
					Game._go_to_room(start_room - 1)
				else:
					Game._on_screen_tapped()
		Game.State.UPGRADE:
			Game.hud._on_card(0)
		Game.State.DEAD, Game.State.VICTORY:
			if Game._state_time > 2.5:
				print("[autoplay] END state=%s room=%d kills=%d time=%.1f" % [Game.State.keys()[Game.state], Game._room_index + 1, Game._kills, Game._run_time])
				runs -= 1
				if runs <= 0:
					get_tree().quit()
				else:
					Game._on_screen_tapped()   # try again
		Game.State.PAUSED:
			if Game._state_time > 1.0:
				Game._on_screen_tapped()

		Game.State.PLAYING:
			if not _paused_once and Game._room_index == 1 and Game._state_time > 2.0:
				_paused_once = true
				print("[autoplay] pause test")
				Game._on_pause_pressed()
				return
			if Game._state_time > 60.0 and _dumped_room != Game._room_index:
				_dumped_room = Game._room_index
				print("[autoplay] SLOW room=%d" % (Game._room_index + 1))
				for a: Actor in Actor.all:
					print("   ", a.get_script().get_global_name(), " pos=", a.global_position, " hp=", a.health)
			_drive(delta)
	if _t > 600.0:
		print("[autoplay] TIMEOUT room=%d hero=%s" % [Game._room_index + 1, Game.hero.global_position])
		for a: Actor in Actor.all:
			print("   ", a.name, " ", a.get_script().get_global_name(), " pos=", a.global_position, " hp=", a.health, " dead=", a.dead)
		get_tree().quit(1)


func _drive(delta: float) -> void:
	var hero := Game.hero
	if hero == null:
		return
	if god:
		hero.health = hero.max_health
	var move := Vector3.ZERO
	var room := Room.current
	if room.door_open:
		move = Vector3(0, 0, -Room.HALF_L - 1.0) - hero.global_position
		if absf(hero.global_position.x) > 0.6 and hero.global_position.z < -Room.HALF_L + 2.0:
			move = Vector3(-hero.global_position.x, 0, 0.3)
	elif not god:
		# Step out of any warning marker, and keep away from skeletons that get close.
		for t in room.get_children():
			if t is Telegraph:
				var d: Vector3 = hero.global_position - (t as Telegraph).global_position
				d.y = 0
				if d.length() < 2.4:
					move += d.normalized() * (2.4 - d.length())
		for a: Actor in Actor.all:
			if a.team == Actor.Team.UNDEAD and not a.dead:
				var d := hero.global_position - a.global_position
				d.y = 0
				if d.length() < 2.2:
					move += d.normalized() * (2.2 - d.length())
		# Drift back towards the middle when idle so the hero doesn't get cornered.
		if move.length() > 0.05:
			move += (Vector3(0, 0, 4) - hero.global_position) * 0.08
	var stick := Vector2(move.x, move.z)
	Game.hud.joystick = stick.normalized() if stick.length() > 0.05 else Vector2.ZERO


func _shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	_shot_n += 1
	var path := shots_dir.path_join("shot_%02d_%s.png" % [_shot_n, Game.State.keys()[Game.state].to_lower()])
	img.save_png(path)
	print("[autoplay] screenshot ", path)
