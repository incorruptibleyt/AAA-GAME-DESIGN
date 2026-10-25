class_name Autoplay
extends Node
## A simple robot player used to test the game without a person holding the phone.
## Start Godot with:  -- autoplay [god] [shop] [shots=<folder>]
## `shop` buys what it can afford in the Armory before the first run (`coins=N` gives it
## N coins first). `quittest` quits the first run from the pause menu and starts again.
## It walks through every room, picks the first blessing each time, and prints what happened.
## Crypt Pass: `pass` plays as if it were owned, `daily` starts the Daily Crypt, `curses=a,b`
## switches curses on, `passmenu` / `cursemenu` take pictures of those screens, and
## `freeend` buys the Pass on the end-of-free-game screen (try with `floor=5`).
## Saved runs: `killat=N` closes the game as room N starts (like Android killing it), and
## `continue` presses CONTINUE on the title screen. `trial=mage` plays a free trial run,
## `dailymenu` takes a picture of the Daily Crypt screen, and `share` prints the share text.
## Endless loops: at the end of a loop it descends and takes the first Omen while `runs` lasts,
## then banks. `bank` banks at once, and `loopquit` closes the game on the end-of-loop screen.
## `loopmenu` (with `floor=5 room=6 runs=2 shots=...`) fells the boss at once and takes
## pictures of the end-of-loop screen, the Omens and the first room of loop 2.
## `die` lets the hero fall a second into the run (for pictures of the end screens).

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
var _perfect_shots := 0
var _special_shots := 0
var _force_special := false
var _perks: PackedStringArray = []
var _card_shot := false
var _pass_menu := false
var _curse_menu := false
var _free_end_test := false
var _free_end_done := false
var _kill_at := 0
var _continue := false
var _trial := ""
var _daily_menu := false
var _share := false
var _bank := false
var _loop_quit := false
var _loop_menu := false
var _answering := false
var _die := false
## "icons": a picture of every blessing's badge, then quit.
var _icons := false


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
		elif a.begins_with("perks="):
			_perks = a.substr(6).split(",")
		elif a == "special":
			_force_special = true
		elif a == "gallery":
			gallery = true
		elif a == "pass":
			Store.test_owned = true
		elif a == "daily":
			Game._daily_requested = true
			_skip_first_run()
		elif a.begins_with("curses="):
			var cfg := Game._load_save()
			for id in a.substr(7).split(","):
				cfg.set_value(Curses.SAVE_SECTION, id, true)
			cfg.save(Game.SAVE_PATH)
			_skip_first_run()
		elif a == "passmenu":
			_pass_menu = true
		elif a == "cursemenu":
			_curse_menu = true
		elif a == "freeend":
			_free_end_test = true
		elif a.begins_with("killat="):
			_kill_at = int(a.substr(7))
		elif a == "continue":
			_continue = true
		elif a.begins_with("trial="):
			_trial = a.substr(6)
			_skip_first_run()
		elif a == "dailymenu":
			_daily_menu = true
			_skip_first_run()
		elif a == "share":
			_share = true
		elif a == "bank":
			_bank = true
		elif a == "loopquit":
			_loop_quit = true
		elif a == "loopmenu":
			_loop_menu = true
		elif a == "die":
			_die = true
		elif a == "icons":
			_icons = true
		elif a.begins_with("runs="):
			runs = int(a.substr(5))
		elif a.begins_with("room="):
			start_room = int(a.substr(5))
		elif a.begins_with("shots="):
			shots_dir = a.substr(6)
			DirAccess.make_dir_recursive_absolute(shots_dir)


## Daily Crypt and Curses aren't offered on the very first run.
func _skip_first_run() -> void:
	var cfg := Game._load_save()
	cfg.set_value("stats", "first_run_done", true)
	cfg.save(Game.SAVE_PATH)


func _process(delta: float) -> void:
	if _hero_choice != "" and Game.hero:
		# Pick (and if needed unlock) a hero before the first run.
		Game.coins += Heroes.get_hero(_hero_choice).cost
		Game._pick_hero(_hero_choice)
		Game.hud.show_heroes(false)
		print("[autoplay] hero %s hp=%d" % [Game.hero.hero_id, Game.hero.max_health])
		_hero_choice = ""
	_t += delta
	if _icons and _t > 0.5:
		_icons = false
		await _icon_sheet()
		get_tree().quit()
		return
	if Game.hud.reports_ask_visible() and not _answering:
		# The once-only "send reports?" question after a run: picture it, then say no.
		_answering = true
		print("[autoplay] reports question shown after a run")
		if shots_dir != "":
			await _shot()
		Game.hud.reports_answered.emit(false)
		_answering = false
		return
	if not _perks.is_empty() and Game.state == Game.State.PLAYING and Game.hero:
		for id in _perks:
			Game._taken[id] = Game._taken.get(id, 0) + 1
			Upgrades.apply(id, Game.hero)
		print("[autoplay] perks %s" % ", ".join(_perks))
		_perks = []
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

	if shots_dir != "" and _perfect_shots < 2 and Game.hud._callout_time > 0.85:
		_perfect_shots += 1
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
			if (_pass_menu or _curse_menu) and _t > 1.2 and not _shopped:
				_shopped = true
				if _pass_menu:
					Game._open_pass()
				else:
					Game._open_curses()
				await get_tree().create_timer(0.5).timeout
				_shot()
				await get_tree().create_timer(0.3).timeout
				if _pass_menu:
					Game.hud.pass_buy.emit()
				else:
					Game.hud.curse_toggled.emit(Curses.LIST[2].id)
				await get_tree().create_timer(0.5).timeout
				_shot()
				print("[autoplay] pass owned=%s curses=%s" % [Store.owned(), Curses.chosen(Game._load_save())])
				if _pass_menu:
					Game.hud.show_pass(false)
					await get_tree().create_timer(0.3).timeout
					_shot()   # the title with Daily Crypt and Curses
				get_tree().quit()
				return
			if _pass_menu or _curse_menu:
				return
			if _daily_menu and _t > 1.2 and not _shopped:
				_shopped = true
				Game._open_daily()
				await get_tree().create_timer(0.5).timeout
				_shot()
				print("[autoplay] daily #%d %s hero=%s rules=%s" % [Curses.day_number(), Curses.theme().name, Curses.daily_hero(), Curses.daily_rules()])
				await get_tree().create_timer(0.3).timeout
				get_tree().quit()
				return
			if _daily_menu:
				return
			if _continue and _t > 1.2:
				_continue = false
				print("[autoplay] title says CONTINUE %s" % Game.continue_text())
				if shots_dir != "":
					_shot()
					await get_tree().create_timer(0.3).timeout
				Game.hud.continue_pressed.emit()
				return
			if _trial != "" and _t > 1.2:
				Game._try_hero(_trial)
				print("[autoplay] trying %s for free: %s" % [_trial, Game._trial_hero])
				_trial = ""
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
					Game._pick_curses()
					Game._apply_armory()
					Game._go_to_room(start_room - 1)
					Game._mode_banner()
				else:
					Game._on_screen_tapped()
		Game.State.UPGRADE:
			if Game.rerolls > 0 and Game.hud._cards_age >= 0.45:
				print("[autoplay] reroll: %s" % ", ".join(Game._choices.map(func(u): return u.title)))
				Game._on_reroll()
				print("[autoplay] rerolled: %s" % ", ".join(Game._choices.map(func(u): return u.title)))
				Game.hud._cards_age = 0.45
			Game.hud._on_card(0)
		Game.State.VICTORY when Game._free_end:
			if Game._state_time > 2.5 and not _free_end_done:
				_free_end_done = true
				print("[autoplay] free game over on floor %d" % Game.floor_num)
				if shots_dir != "":
					_shot()
				if _free_end_test:
					Game.hud.pass_pressed.emit()
					Game.hud.pass_buy.emit()
					Game.hud.show_pass(false)
					print("[autoplay] bought the Pass: owned=%s free_end=%s" % [Store.owned(), Game._free_end])
				else:
					get_tree().quit()
		Game.State.VICTORY when Game._loop_choice:
			if Game.hud.omens_visible():
				if Game._state_time > 3.5:
					if shots_dir != "":
						_shot()
					var pick: Dictionary = Game._omen_choices[0]
					print("[autoplay] omen picked: %s (of %s)" % [pick.title, ", ".join(Game._omen_choices.map(func(o): return o.title))])
					Game.hud.omen_picked.emit(pick.id)
			elif Game._state_time > 2.5:
				print("[autoplay] loop %d cleared on floor %d: score %d, run coins %d, bank bonus %d" % [Loops.loop_of(Game.floor_num), Game.floor_num, Game.score, Game.run_coins, Game._bank_bonus()])
				if shots_dir != "":
					_shot()
				if _loop_quit:
					_loop_quit = false
					print("[autoplay] closing the game on the end-of-loop screen")
					get_tree().quit()
				elif _bank or runs <= 1:
					var before := Game.coins
					Game.hud.loop_bank.emit()
					print("[autoplay] banked: coins %d -> %d" % [before, Game.coins])
					get_tree().create_timer(1.5).timeout.connect(func():
						print("[autoplay] after bank: state=%s saved run=%s coins in save=%d" % [Game.State.keys()[Game.state], not RunSave.read().is_empty(), int(Game._load_save().get_value("stats", "coins", 0))])
						get_tree().quit())
					set_process(false)
				else:
					runs -= 1
					Game.hud.loop_deeper.emit()
		Game.State.DEAD, Game.State.VICTORY:
			if _share and Game.daily and (Game._daily_done or Game.state == Game.State.DEAD) and Game._state_time > 2.0:
				_share = false
				print("[autoplay] share text:\n" + Game._share_text())
			if Game._state_time > 2.5:
				print("[autoplay] END objects=%d nodes=%d state=%s floor=%d room=%d kills=%d time=%.1f perfect=%d chain=%.1f" % [Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Game.State.keys()[Game.state], Game.floor_num, Game._room_index + 1, Game._kills, Game._run_time, Game._rep.get("perfect", 0), Game._rep.get("best_chain", 1.0)])
				runs -= 1
				if runs <= 0:
					get_tree().quit()
				else:
					Game._on_screen_tapped()   # try again
		Game.State.PAUSED:
			if Game._state_time > 1.0:
				if quit_test and not _quit_done:
					_quit_done = true
					_t = 0.0
					Game.hud._on_quit_pressed()
					print("[autoplay] quit run test: first tap %s" % ("asks" if Game.state == Game.State.PAUSED else "QUIT TOO EARLY"))
					Game.hud._on_quit_pressed()
				else:
					Game._on_screen_tapped()

		Game.State.PLAYING when gallery:
			_gallery_step(delta)
		Game.State.TRANSITION when gallery and _gallery_t >= 0.0:
			_gallery_step(delta)
		Game.State.PLAYING when _die:
			if Game._state_time > 1.0:
				_die = false
				Game.hero.take_damage(1e9, Vector3.ZERO, 0.0)
		Game.State.PLAYING when _loop_menu:
			if is_instance_valid(Game.boss) and not Game.boss.dead and Game._state_time > 1.0:
				Game.boss.take_damage(1e9, Vector3.ZERO, 0.0)
			elif Loops.loop_of(Game.floor_num) > 1 and Game._state_time > 2.5:
				_loop_menu = false
				await _shot()
				get_tree().quit()
		Game.State.PLAYING:
			if _kill_at > 0 and Game._room_index == _kill_at - 1 and Game._state_time > 1.0:
				print("[autoplay] closing the game on floor %d room %d: hp %d/%d score %d coins %d run coins %d" % [Game.floor_num, Game._room_index + 1, Game.hero.health, Game.hero.max_health, Game.score, Game.coins, Game.run_coins])
				get_tree().quit()
				return
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
	if _force_special and Game.alive_enemies >= 4 and Game._state_time > 2.0:
		_force_special = false
		hero.special_charge = 1.0
	if hero.special_ready() and Game.alive_enemies >= 3:
		hero.use_special()
		if shots_dir != "" and _special_shots < 2:
			_special_shots += 1
			get_tree().create_timer(0.35, true, false, true).timeout.connect(_shot)
	# Grave Dash: dash sideways through a shot that is about to land.
	if hero.dash_ready():
		for p in Projectile.danger:
			if is_instance_valid(p) and p.time_to_hit(hero.global_position, hero.radius + 0.15) < 0.12:
				hero.dash(p.dir.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0))
				break
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


## Every blessing's badge on one page, with its name, to check the pictures.
func _icon_sheet() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var all: Array = Upgrades.LIST + Upgrades.SYNERGIES
	for i in all.size():
		var u: Dictionary = all[i]
		var icon := BlessingIcon.new()
		icon.position = Vector2(30 + (i % 4) * 128, 20 + (i / 4) * 132)
		icon.scale = Vector2(1.4, 1.4)
		bg.add_child(icon)
		icon.show_for(u)
		var l := Hud.label(u.title, 15)
		l.position = icon.position + Vector2(-20, 92)
		l.size = Vector2(130, 20)
		bg.add_child(l)
	for f in 6:
		await get_tree().process_frame
	if shots_dir != "":
		await _shot()


func _shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	_shot_n += 1
	var path := shots_dir.path_join("shot_%02d_%s.png" % [_shot_n, Game.State.keys()[Game.state].to_lower()])
	img.save_png(path)
	print("[autoplay] screenshot ", path)
