class_name Warmup
## Phones turn each new look (a material on a kind of mesh, a particle effect, the damage
## numbers) into a graphics program the first time it's drawn, and with this game's
## renderer the game waits for it: the first hit, the first enemy shot and each new kind
## of skeleton, fire or floor froze play for up to a second (frame rate "lowest 9" in run
## reports). Godot keeps the programs in user://shader_cache, so it happened once per
## install or update, just when a new player is making up their mind. At launch, behind
## the black screen, this draws one of everything for a few frames and removes it all, so
## the wait happens there instead. The first launch after an install or update takes
## longest; run reports say how long the last one took ("warm-up").

const FOES := ["m", "w", "a", "g", "x", "t", "s", "f", "e", "d", "p", "r", "L", "K", "C", "T", "S", "b", "h", "Q", "q"]

static var last_ms := 0


static func run() -> void:
	var room := Room.current
	var hero: Hero = Game.hero
	if room == null or hero == null or Game.world == null:
		return
	var started := Time.get_ticks_msec()
	var bus := AudioServer.get_bus_index("Master")
	var muted := AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, true)   # warnings and pickups make sounds as they appear
	var old_room := _ids(room)
	var old_world := _ids(Game.world)
	var holder := Node3D.new()
	holder.name = "Warmup"
	room.add_child(holder)   # skeletons only stand still on the title screen
	var at := hero.global_position
	var spots: Array[Vector3] = []
	for i in 25:
		spots.append(at + Vector3((i % 5 - 2) * 1.3, 0, (i / 5 - 1) * 1.3))
	var tree := Game.get_tree()
	var made: Array = []
	# A few things a frame rather than everything at once: on a new install a slow phone can
	# take many seconds to prepare it all, and one frame that long looks frozen (Android may
	# even offer to close the app). Between batches a loading bar shows how far it has got.
	var bar := _Bar.new()
	Game.add_child(bar)
	var steps: Array[Callable] = []

	# Every kind of skeleton (and a golden elite) with its health bar and a damage number,
	# then every hero with its glow.
	var foes: Array[Enemy] = []
	for k in range(0, FOES.size(), 4):
		steps.append(func():
			for i in range(k, mini(k + 4, FOES.size())):
				var e := Enemy.create(FOES[i], holder, spots[i])
				e._spawn_timer = 0.0
				if FOES[i] == "w":
					e.make_elite()
				if e._bar:
					e._bar.reveal()
				DamageNumber.hit(e, 1234567890.0, FOES[i] == "K")
				foes.append(e))
	var heroes: Array[CharacterVisual] = []
	steps.append(func():
		for i in Heroes.LIST.size():
			var v := CharacterVisual.new()
			v.outline_me = true   # so the outline shader is ready before the first run
			holder.add_child(v)
			v.position = spots[FOES.size() + i]
			# (The first in an outfit, so the outfit shader is ready: hero_style.gd.)
			var picks := {"outfit": "crimson"} if i == 0 else {}
			if i == 1 and Store.owned():
				# A Pass owner's Crypt King set (its crown, gold outfit and sigil shaders).
				for slot: String in HeroStyle.PASS_SLOTS:
					picks[slot] = HeroStyle.pass_key(slot)
			var def := HeroStyle.dressed(Heroes.LIST[i], picks)
			v.build(Heroes.look(def))
			if def.has("aura") and def.aura.get("sigil", false):
				CryptSigil.make(v)
			heroes.append(v)
		DamageNumber.healed(hero, 9876543210.0))

	# Every Feat and Bone Drop look: the headwear's flame, ghost and glow materials, the
	# patterned outfits and the auras (version 115 left these out, so the first Legendary
	# reveal froze while its head was prepared). Two batches of a few heroes each.
	var keys := {}
	var most := 0
	for slot: String in ["head", "outfit", "glow", "aura"]:
		keys[slot] = HeroStyle.EXTRA[slot].keys()
		most = maxi(most, keys[slot].size())
	for half in 2:
		steps.append(func():
			for i in range(half * ceili(most / 2.0), mini(most, (half + 1) * ceili(most / 2.0))):
				var v := CharacterVisual.new()
				v.outline_me = true
				holder.add_child(v)
				v.position = spots[i % spots.size()] + Vector3(0, 0, 2.6)
				var picks := {}
				for slot: String in keys:
					picks[slot] = keys[slot][i % keys[slot].size()]
				v.build(Heroes.look(HeroStyle.dressed(Heroes.LIST[i % Heroes.LIST.size()], picks)))
			var g := Fx.aura_ground(Color.CYAN, Color.WHITE, 6)
			holder.add_child(g)
			g.position = at + Vector3(0, 0.04, 2.0))

	# The Heroes/Style pedestal and the Bone Drop chest: each has its own little 3D world with
	# its own lights, so their shaders differ from the room's (version 119: the first reveal
	# and the first chest could stall while these were prepared). Drawn behind the loading
	# screen, on a layer under it.
	steps.append(func():
		var layer := CanvasLayer.new()
		layer.layer = -1
		Game.add_child(layer)
		made.append(layer)
		var stage := HeroStage.new(Vector2(240, 300))
		layer.add_child(stage)
		var picks := {"head": "flame_crown", "outfit": "starweave", "glow": "aurora", "aura": "phantom"}
		stage.show_hero(HeroStyle.dressed(Heroes.LIST[0], picks))
		stage.set_active(true)
		stage.reveal("glow", true)   # its sparks (version 131)
		var chest := Reliquary.new()
		chest.size = Vector2(240, 240)
		chest.position = Vector2(250, 0)
		layer.add_child(chest)
		chest.reset()
		chest.open_up(Color(1.0, 0.8, 0.3), 2, true)
		# The lit wall behind the menus (version 130), with its torch and dust.
		var wall := ColorRect.new()
		wall.color = Color(0, 0, 0, 1)
		wall.size = Vector2(300, 300)
		wall.position = Vector2(0, 310)
		layer.add_child(wall)
		var bd := MenuBackdrop.add_to(wall)
		bd.show_off(stage, Vector2(0.5, 0.4), 0.8, 0.3)
		# the candle shrine under short lists (version 136)
		var shrine := MenuBackdrop._Shrine.new()
		shrine.visible = true
		wall.add_child(shrine)
		shrine.place(Rect2(0, 0, 300, 260), 240.0, Color.WHITE))

	# Shots, warnings, fire, pickups and every particle effect: a few at a time, so a slow
	# phone never spends long on one frame (Android closes an app that stops answering),
	# and a report from a phone that dies here names the very effect (Game.loading).
	steps.append(func():
		for i in 5:   # every hero's shot (the Barbarian's axe model loads here too)
			Projectile.fire(Actor.Team.HERO, at + Vector3(-1 - i * 0.4, 1, 1), Vector3.FORWARD, 0.0, 0.0, hero.bolt_color, 0.3, "Shot",
				["bolt", "wave", "axe", "orb", "shard"][i]))
	steps.append(func():
		Fx.impact(at + Vector3.UP, hero.bolt_color)
		Projectile.fire(Actor.Team.UNDEAD, at + Vector3(1, 1, 1), Vector3.FORWARD, 0.0, 0.0, Color.WHITE))
	steps.append(func():
		Telegraph.circle(at + Vector3(-1.5, 0, 0), 1.0, 9.0, func(): pass)
		Telegraph.line(at, Vector3.FORWARD, 3.0, 1.0, 9.0, func(): pass)
		FirePatch.spawn(at + Vector3(1.5, 0, 0), 1.0, 9.0)
		Pickup.drop(at + Vector3(0, 0, 1))
		Pickup.drop_coins(at + Vector3(0, 0, -1), 3))
	steps.append(func():
		Fx.sparks(at + Vector3.UP)
		Fx.bones(at))
	steps.append(func():
		Fx.dust(at)
		Fx.trail(at + Vector3.UP, Color(0.45, 0.8, 1.0)))
	steps.append(func():
		Fx.magic(at + Vector3.UP, Color(1, 0.6, 0.2))
		Fx.shockwave(at, Color(1, 0.9, 0.6), 2.0))
	steps.append(func():
		Fx.flame(holder, Vector2(0.5, 0.7), at + Vector3(0, 0, 0.6))
		Fx.wisps(holder, Color(0.6, 1.0, 0.85), 2, 1.0, 1.0))   # the room's wisps (version 136)

	# Each floor's own flagstones and props (the Frozen Ossuary's ice, the Ember
	# Catacomb's fire seams and braziers, the Drowned Vault's water and falling water), and
	# the Tidecaller's wave.
	steps.append(func():
		for i in Floors.THEMES.size():
			U.floor_quad(holder, Vector2(1, 1), Room._floor_material(Floors.THEMES[i]), spots[i] + Vector3(0, 0.02, 0.6))
			# Each crypt's own walls (version 134).
			U.box(holder, Vector3(0.6, 0.6, 0.6), Room._wall_material(Floors.THEMES[i], U.mat(Color.GRAY)), spots[i] + Vector3(0.6, 0.3, 0.6)))
	steps.append(func():
		var props := [Props._skull_pile(true), Props._skull_pile(false), Props._crystals(), Props._icicles(), Props._brazier(), Props._grate(),
			Props._kelp_column(), Props._spout()]
		for i in props.size():
			Props._mesh(holder, props[i]).position = spots[5 + i] + Vector3(0, 0, -0.6)
		U.floor_quad(holder, Vector2(1, 1), Props._splash_mat(), spots[14] + Vector3(0, 0.03, 0))
		U.floor_quad(holder, Vector2(1, 1), Props._foam_mat(), spots[16] + Vector3(0, 0.03, 0))
		U.box(holder, Vector3(1, 0.6, 0.3), Tidecaller._foam_material(), spots[15] + Vector3(0, 0.3, 0)))
	# The Glowcap Grotto (version 128): its mushrooms and shelf fungus, the glow under them,
	# a spore cloud, crawling roots and the Sporemother's pod.
	steps.append(func():
		Props._mesh(holder, Props._mushroom_clump()).position = spots[21]
		Props._mesh(holder, Props._shelf_fungus()).position = spots[22]
		Props._glow_pool(holder, 1.0)
		SporeCloud.spawn(spots[23], 1.0, 0.5)
		RootCrawl._burst(spots[23] + Vector3(0.5, 0, 0), 1.0, 0.2)
		var pod := U.sphere(holder, 0.28, U.mat(Color(1.0, 0.42, 0.82), 0.4, 0.7))
		pod.position = spots[24] + Vector3(0, 1, 0))

	# Draw each batch for two frames. Frames, not frame_post_draw: that signal never comes
	# without a screen (robot test runs).
	for n in steps.size():
		Game.loading = "loading %d/%d" % [n + 1, steps.size()]
		Game.note_spot()   # if a phone dies while loading, the report says at which step
		steps[n].call()
		# Shots, warnings, fire and pickups land in the room: they mustn't hurt or be collected.
		for c in _new(room, old_room) + _new(Game.world, old_world):
			if not made.has(c):
				made.append(c)
				if c.get_parent() == room and c != holder:
					c.process_mode = Node.PROCESS_MODE_DISABLED
		bar.progress((n + 1.0) / (steps.size() + 1.0), Time.get_ticks_msec() - started)
		for i in 2:
			await tree.process_frame

	# Then every character being hit (white flash).
	for e in foes:
		e.take_damage(1.0, Vector3.ZERO, 0.0)
		if e._bar:
			# Half-empty and low enough to be in view (they float above tall skeletons).
			e._bar.process_mode = Node.PROCESS_MODE_DISABLED
			e._bar.visible = true
			e._bar.global_position = e.global_position + Vector3(0, 1.0, 0.5)
			e._bar._fill.scale = Vector3(0.5, 1, 1)
	for i in heroes.size():
		heroes[i].soft_flash = i == 1   # so a boss's softer flash is ready too
		heroes[i].hit()
	made += _new(Game.world, old_world).filter(func(c): return not made.has(c))
	for i in 3:
		await tree.process_frame
	bar.progress(1.0, Time.get_ticks_msec() - started)
	Game.loading = ""

	for c in made:
		if is_instance_valid(c):
			c.queue_free()
	bar.queue_free()
	AudioServer.set_bus_mute(bus, muted)
	last_ms = Time.get_ticks_msec() - started
	print("[warmup] %d ms" % last_ms)


## A thin bone-white bar low on the black launch screen. It stays hidden on a quick launch
## (most launches take under a second) and appears once the wait passes 0.4 seconds.
class _Bar extends CanvasLayer:
	var _fill: ColorRect
	var _box: Control

	func _init() -> void:
		layer = 11   # above the HUD's black fade, below the opening animation
		_box = Control.new()
		_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.visible = false
		add_child(_box)
		var label := Label.new()
		label.text = "Waking the dead..."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(0.93, 0.89, 0.82, 0.85))
		label.anchor_left = 0.0
		label.anchor_right = 1.0
		label.anchor_top = 0.62
		label.anchor_bottom = 0.62
		label.offset_top = -50
		label.offset_bottom = -12
		_box.add_child(label)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, 0.12)
		track.anchor_left = 0.25
		track.anchor_right = 0.75
		track.anchor_top = 0.62
		track.anchor_bottom = 0.62
		track.offset_bottom = 6
		_box.add_child(track)
		_fill = ColorRect.new()
		_fill.color = Color(0.95, 0.72, 0.42)
		_fill.anchor_bottom = 1.0
		_fill.anchor_right = 0.0
		track.add_child(_fill)

	func progress(done: float, ms: int) -> void:
		if ms > 400:
			_box.visible = true
		_fill.anchor_right = clampf(done, 0.0, 1.0)


## What was added under `parent` since the warm-up began (only that is removed afterwards).
static func _new(parent: Node, old: Dictionary) -> Array:
	return parent.get_children().filter(func(c): return not old.has(c.get_instance_id()))


static func _ids(parent: Node) -> Dictionary:
	var ids := {}
	for c in parent.get_children():
		ids[c.get_instance_id()] = true
	return ids
