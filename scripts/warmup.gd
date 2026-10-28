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

const FOES := ["m", "w", "a", "g", "x", "t", "s", "f", "e", "L", "K"]

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
	for i in 15:
		spots.append(at + Vector3((i % 5 - 2) * 1.3, 0, (i / 5 - 1) * 1.3))

	# Every kind of skeleton (and a golden elite) with its health bar and a damage number,
	# then every hero with its glow.
	var foes: Array[Enemy] = []
	for i in FOES.size():
		var e := Enemy.create(FOES[i], holder, spots[i])
		e._spawn_timer = 0.0
		if FOES[i] == "w":
			e.make_elite()
		if e._bar:
			e._bar.reveal()
		DamageNumber.hit(e, 1234567890.0, FOES[i] == "K")
		foes.append(e)
	var heroes: Array[CharacterVisual] = []
	for i in Heroes.LIST.size():
		var v := CharacterVisual.new()
		holder.add_child(v)
		v.position = spots[FOES.size() + i]
		v.build(Heroes.look(Heroes.LIST[i]))
		heroes.append(v)
	DamageNumber.healed(hero, 9876543210.0)

	# Shots, warnings, fire, pickups and every particle effect.
	Projectile.fire(Actor.Team.HERO, at + Vector3(-1, 1, 1), Vector3.FORWARD, 0.0, 0.0, hero.bolt_color)
	Projectile.fire(Actor.Team.UNDEAD, at + Vector3(1, 1, 1), Vector3.FORWARD, 0.0, 0.0, Color.WHITE)
	Telegraph.circle(at + Vector3(-1.5, 0, 0), 1.0, 9.0, func(): pass)
	Telegraph.line(at, Vector3.FORWARD, 3.0, 1.0, 9.0, func(): pass)
	FirePatch.spawn(at + Vector3(1.5, 0, 0), 1.0, 9.0)
	Pickup.drop(at + Vector3(0, 0, 1))
	Pickup.drop_coins(at + Vector3(0, 0, -1), 3)
	Fx.sparks(at + Vector3.UP)
	Fx.bones(at)
	Fx.dust(at)
	Fx.trail(at + Vector3.UP, Color(0.45, 0.8, 1.0))
	Fx.magic(at + Vector3.UP, Color(1, 0.6, 0.2))
	Fx.shockwave(at, Color(1, 0.9, 0.6), 2.0)
	Fx.flame(holder, Vector2(0.5, 0.7), at + Vector3(0, 0, 0.6))

	# Each floor's own flagstones and props (the Frozen Ossuary's ice, the Ember Catacomb's
	# fire seams and braziers).
	for i in Floors.THEMES.size():
		U.floor_quad(holder, Vector2(1, 1), Room._floor_material(Floors.THEMES[i]), spots[i] + Vector3(0, 0.02, 0.6))
	var props := [Props._skull_pile(true), Props._skull_pile(false), Props._crystals(), Props._icicles(), Props._brazier(), Props._grate()]
	for i in props.size():
		Props._mesh(holder, props[i]).position = spots[5 + i] + Vector3(0, 0, -0.6)

	# Shots, warnings, fire and pickups land in the room: they mustn't hurt or be collected.
	var made := _new(room, old_room) + _new(Game.world, old_world)
	for c in made:
		if c.get_parent() == room and c != holder:
			c.process_mode = Node.PROCESS_MODE_DISABLED

	# Draw it all as it is, then with every character being hit (white flash). Frames, not
	# frame_post_draw: that signal never comes without a screen (robot test runs).
	var tree := Game.get_tree()
	for i in 3:
		await tree.process_frame
	for e in foes:
		e.take_damage(1.0, Vector3.ZERO, 0.0)
		if e._bar:
			# Half-empty and low enough to be in view (they float above tall skeletons).
			e._bar.process_mode = Node.PROCESS_MODE_DISABLED
			e._bar.visible = true
			e._bar.global_position = e.global_position + Vector3(0, 1.0, 0.5)
			e._bar._fill.scale = Vector3(0.5, 1, 1)
	for v in heroes:
		v.hit()
	made += _new(Game.world, old_world).filter(func(c): return not made.has(c))
	for i in 3:
		await tree.process_frame

	for c in made:
		if is_instance_valid(c):
			c.queue_free()
	AudioServer.set_bus_mute(bus, muted)
	last_ms = Time.get_ticks_msec() - started
	print("[warmup] %d ms" % last_ms)


## What was added under `parent` since the warm-up began (only that is removed afterwards).
static func _new(parent: Node, old: Dictionary) -> Array:
	return parent.get_children().filter(func(c): return not old.has(c.get_instance_id()))


static func _ids(parent: Node) -> Dictionary:
	var ids := {}
	for c in parent.get_children():
		ids[c.get_instance_id()] = true
	return ids
