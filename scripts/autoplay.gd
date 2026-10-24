class_name Autoplay
extends Node
## A simple robot player used to test the game without a person holding the phone.
## Start Godot with:  -- autoplay [god] [shop] [shots=<folder>]
## `shop` buys what it can afford in the Armory before the first run (`coins=N` gives it
## N coins first). `quittest` quits the first run from the pause menu and starts again.
## It walks through every room, picks the first blessing each time, and prints what happened.

var god := false
var start_room := 1
var runs := 1
var gallery := false
var elites := false
var hero_lineup := false
var hero_menu := false
var spider_shot := false
var _hero_choice := ""
var shop := false
var quit_test := false
var _quit_done := false
var _shopped := false
var _gallery_t := -1.0
var _paused_once := false
var _dumped_room := -1
var shots_dir := ""
var _t := 0.0
var _next_shot := 1.0
var _shot_n := 0
var _dodge := Vector3.ZERO
var _last_state := -1
var _dashes := 0
var _card_shot := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "god":
			god = true
		elif a.begins_with("floor="):
			Game.floor_num = int(a.substr(6))
		elif a == "shop":
			shop = true
		elif a == "quittest":
			quit_test = true
		elif a.begins_with("coins="):
			Game.coins = int(a.substr(6))
		elif a == "elites":
			elites = true
		elif a == "spiderroom":
			# Test the spider rooms: make the first rooms the spider nest and spider hall.
			Game._run[0] = Layouts.MEDIUM[0]
			Game._run[1] = Layouts.HARD[0]
		elif a == "spiders":
			spider_shot = true
		elif a == "heromenu":
			hero_menu = true
		elif a == "heroes":
			hero_lineup = true
		elif a.begins_with("hero="):
			_hero_choice = a.substr(5)
		elif a == "gallery":
			gallery = true
		elif a.begins_with("runs="):
			runs = int(a.substr(5))
		elif a.begins_with("room="):
			start_room = int(a.substr(5))
		elif a.begins_with("shots="):
			shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(shots_dir)


func _process(delta: float) -> void:
	if _hero_choice != "" and Game.hero:
		# Pick (and if needed unlock) a hero before the first run.
		Game.coins += Heroes.get_hero(_hero_choice).cost
		Game._pick_hero(_hero_choice)
		Game.hud.show_heroes(false)
		print("[autoplay] hero %s hp=%d" % [Game.hero.hero_id, Game.hero.max_health])
		_hero_choice = ""
	_t += delta
	if Game.state != _last_state:
		_last_state = Game.state
		print("[autoplay] t=%.1f state=%s room=%d hp=%s" % [_t, Game.State.keys()[Game.state], Game._room_index + 1, str(Game.hero.health) if Game.hero else "-"])
		if shots_dir != "" and Game.state in [Game.State.UPGRADE, Game.State.VICTORY, Game.State.DEAD, Game.State.PAUSED]:
			_shot.call_deferred()
		if shots_dir != "" and Game.state == Game.State.PLAYING and Room.current and Room.current.door_open:
			_next_shot = _t + 0.3   # catch the exit arrow right after a blessing
	if shots_dir != "" and _t > _next_shot and Game.state == Game.State.PLAYING:
		_next_shot = _t + 4.0
		_shot()

	if shots_dir != "" and not _card_shot and Game.hud._boss_card.visible and Game.hud._boss_card.modulate.a > 0.95:
		_card_shot = true
		_shot()

	match Game.state:
		Game.State.TITLE:
			if shots_dir != "" and _shot_n == 0 and _t > 1.0:
				_shot_n = -1
				_shot()
			if hero_menu and _t > 1.2 and not _shopped:
				_shopped = true
				Game._open_heroes()
				await get_tree().create_timer(0.5).timeout
				_shot()
				await get_tree().create_timer(0.5).timeout
				get_tree().quit()
				return
			if hero_menu:
				return
			if shop and not _shopped and _t > 1.2:
				_shopped = true
				Game._open_armory()
				for u: Dictionary in Armory.LIST:
					Game._buy_upgrade(u.id)
				print("[autoplay] shop: coins left %d, hero hp before run %d" % [Game.coins, Game.hero.max_health])
				if shots_dir != "":
					_shot()
			if shop and _t < 3.0:
				return
			if Game.hud.armory_visible():
				Game.hud.show_armory(false)
			if _t > 1.5:
				if start_room > 1 or Game.floor_num > 1:
					Game.hud.show_title(false)
					Game.hud.show_hud(true)
					Game._go_to_room(start_room - 1)
				else:
					Game._on_screen_tapped()
		Game.State.UPGRADE:
			Game.hud._on_card(0)
		Game.State.DEAD, Game.State.VICTORY:
			if Game._state_time > 2.5:
				print("[autoplay] END objects=%d nodes=%d state=%s floor=%d room=%d kills=%d time=%.1f" % [Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Game.State.keys()[Game.state], Game.floor_num, Game._room_index + 1, Game._kills, Game._run_time])
				runs -= 1
				if runs <= 0:
					get_tree().quit()
				else:
					Game._on_screen_tapped()   # try again
		Game.State.PAUSED:
			if Game._state_time > 1.0:
				if quit_test and not _quit_done:
					_quit_done = true
					print("[autoplay] quit run test")
					_t = 0.0
					Game._quit_to_title()
				else:
					Game._on_screen_tapped()

		Game.State.PLAYING when gallery:
			_gallery_step(delta)
		Game.State.TRANSITION when gallery and _gallery_t >= 0.0:
			_gallery_step(delta)
		Game.State.PLAYING:
			if not _paused_once and Game._room_index == 1 and Game._state_time > 2.0:
				_paused_once = true
				print("[autoplay] pause test")
				Game._on_pause_pressed()
				return
			if Game._state_time > 60.0 and _dumped_room != Game._room_index:
				_dumped_room = Game._room_index
				print("[autoplay] SLOW time_scale=%.2f dashes=%d room=%d alive_enemies=%d door=%s" % [Engine.time_scale, _dashes, Game._room_index + 1, Game.alive_enemies, Room.current.door_open])
				for a: Actor in Actor.all:
					print("   ", a.get_script().get_global_name(), " pos=", a.global_position, " hp=", a.health)
			_drive(delta)
	if _t > 600.0:
		print("[autoplay] TIMEOUT room=%d hero=%s" % [Game._room_index + 1, Game.hero.global_position])
		for a: Actor in Actor.all:
			print("   ", a.name, " ", a.get_script().get_global_name(), " pos=", a.global_position, " hp=", a.health, " dead=", a.dead)
		get_tree().quit(1)


## Lines up one of every skeleton type for a close look, takes a picture and quits.
func _gallery_step(delta: float) -> void:
	if _gallery_t < 0.0:
		_gallery_t = 0.0
		for a: Actor in Actor.all.duplicate():
			if a is Enemy:
				a.queue_free()
		if hero_lineup:
			var ids := ["rogue", "knight", "barbarian", "mage"]
			for i in ids.size():
				var h := Hero.spawn(Room.current, Vector3(-4.5 + i * 3.0, 0, 3.0), ids[i])
				h.rotation.y = PI
			Game.hero.place_at(Vector3(0, 0, 30))
			Game.state = Game.State.TRANSITION
			return
		if spider_shot:
			for i in 3:
				var sp := Game.spawn_enemy("s", Vector3(-2.5 + i * 2.5, 0, 4.0 - absf(i - 1) * 1.0))
				sp.rotation.y = PI
			Game.spawn_enemy("w", Vector3(0, 0, 0.5))
			Game.hero.place_at(Vector3(0, 0, 8.0))
			Game.state = Game.State.TRANSITION
			for a in Actor.all:
				a.rotation.y = PI
			return
		var kinds := ["m", "w", "a", "g", "x", "t"]
		for i in kinds.size():
			var e := Game.spawn_enemy(kinds[i], Vector3(-4.0 + (i % 3) * 4.0, 0, 1.5 + (i / 3) * 3.0))
			if elites and i < 3:
				e.make_elite()
		if elites:
			Game.hero.ward = 1
		Game.spawn_enemy("K", Vector3(-3, 0, -5))
		Game.spawn_enemy("L", Vector3(3, 0, -5))
		Game.hero.place_at(Vector3(0, 0, 7.5))
		Game.state = Game.State.TRANSITION   # everyone stands still
		for a: Actor in Actor.all:
			a.rotation.y = PI   # face the camera
		return
	_gallery_t += delta
	if _gallery_t > 2.0 and _gallery_t < 100.0:
		_gallery_t = 100.0
		_shot()
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()


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
				if d.length() < 1.6 and hero.dash_ready():
					hero.dash(d if d.length() > 0.1 else Vector3.RIGHT)
					_dashes += 1
					if _dashes == 1:
						print("[autoplay] first dash")
		for a: Actor in Actor.all:
			if a.team == Actor.Team.UNDEAD and not a.dead:
				var d := hero.global_position - a.global_position
				d.y = 0
				if d.length() < 2.2:
					move += d.normalized() * (2.2 - d.length())
		# Drift back towards the middle when idle so the hero doesn't get cornered.
		if move.length() > 0.05:
			move += (Vector3(0, 0, 4) - hero.global_position) * 0.08
	if move.length() < 0.05 and not room.door_open:
		# No clear shot at anything? Walk towards the target until there is one.
		var target := hero._pick_target()
		if target and not room.clear_shot(hero.global_position, target.global_position):
			move = target.global_position - hero.global_position
			move.y = 0.0
	if move.length() > 0.05:
		move = room.steer(hero.global_position, move.normalized(), hero.radius)
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
