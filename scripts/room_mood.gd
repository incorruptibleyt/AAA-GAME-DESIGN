class_name RoomMood
## Version 143 (review change 5): rooms on one floor stop looking alike. Each crypt keeps its
## own floor, walls and props (room.gd, props.gd); on top of that every room gets a mood:
##   - "treasure" (after the Treasure Room door): gold light, a gold pool on the floor and
##     coin stacks along the walls, so the promise of the door is something you see.
##   - "champion" (after the Champion's Door): a red rune ring on the floor, a red-violet
##     light and red banners on the side walls. The elite's arena.
##   - "approach" (the last room before the boss): the torches burn low and the boss gate is
##     lit by two braziers and a red glow, so the floor builds up to the boss.
##   - plain rooms take turns: as built, a cold shaft of light falling on the floor, or a
##     ritual circle ringed with candles.
## Everything is floor quads, a few small props and at most one extra light, so it costs
## about what one torch does.

const GOLD := Color(1.0, 0.78, 0.32)
const RED := Color(1.0, 0.32, 0.14)

static var _ring: GradientTexture2D
static var _mats := {}


## Which mood room `index` of a run of `count` rooms gets. `door` is the door picked before
## it ({} when none). Plain rooms cycle so two in a row never match.
static func pick(index: int, count: int, door: Dictionary, floor_num: int) -> String:
	if index >= count - 1:
		return "boss"
	match str(door.get("kind", "")):
		"treasure":
			return "treasure"
		"champion":
			return "champion"
	if count >= 3 and index == count - 2:
		return "approach"
	return ["plain", "shaft", "circle"][(index + floor_num) % 3]


static func apply(room: Room, mood: String, layout: Array) -> void:
	room.mood = mood
	var torch: Color = Floors.current().torch
	match mood:
		"treasure":
			_pool(room, Vector3.ZERO, Vector2(7.5, 7.5), Color(GOLD, 0.22), false)
			_pool(room, Vector3.ZERO, Vector2(5.0, 5.0), Color(GOLD, 0.45), true)
			_light(room, Vector3(0, 2.6, 0), GOLD, 1.3, 8.5)
			var coins := Art.get_model("coin_stack_small")
			var chest := Art.get_model("chest")
			var spots := [Vector2i(0, 5), Vector2i(8, 5), Vector2i(0, 9), Vector2i(8, 9), Vector2i(1, 7), Vector2i(7, 7)]
			for i in spots.size():
				var c: Vector2i = spots[i]
				if not _free(layout, c):
					continue
				var p := Room.cell_to_world(c.x, c.y)
				p.x = signf(p.x) * (Room.HALF_W - 0.45) if c.x in [0, 8] else p.x
				var scene := chest if i == 4 and chest else coins
				if scene == null:
					continue
				var n := _place(room, p, signf(p.x) * PI / 2.0 if scene == chest else randf() * TAU)
				Art.place_prop(scene, n, 0.7 if scene == chest else 0.38)
				# Against a wall the circle sits on the wall line (as props.gd does), so a push out of
				# it always points into the room and never towards the wall behind it.
				if c.x in [0, 8]:
					room._add_obstacle(Vector3(signf(p.x) * Room.HALF_W, 0, p.z), 0.75)
				else:
					room._add_obstacle(p, 0.45 if scene == chest else 0.3)
			for l in room._torch_lights:
				l.light_color = torch.lerp(GOLD, 0.5)
		"champion":
			_pool(room, Vector3.ZERO, Vector2(6.0, 6.0), Color(RED, 0.8), true)
			_pool(room, Vector3.ZERO, Vector2(4.2, 4.2), Color(0.75, 0.2, 1.0, 0.2), false)
			_light(room, Vector3(0, 2.4, 0), Color(1.0, 0.35, 0.45), 1.1, 7.5)
			var banner := Art.get_model("banner_patternC_red")
			if banner:
				for side in [-1.0, 1.0]:
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.12), 0.75, -1.0), -side * PI / 2.0)
					Props._no_shadow(Art.place_prop(banner, n, 1.75))
		"approach":
			room.torch_k = 0.55
			room.apply_graphics(Game._high_graphics)
			var door_z := -Room.HALF_L
			# A shadow over the whole floor (drawn before every other see-through thing, so
			# warnings and shots stay bright), then the red light at the gate on top.
			var dark := U.unlit(Color(0, 0, 0, 0.34)).duplicate() as StandardMaterial3D
			dark.render_priority = -2
			U.floor_quad(room, Vector2(Room.HALF_W * 2, Room.HALF_L * 2), dark, Vector3(0, 0.02, 0))
			_pool(room, Vector3(0, 0, door_z + 1.6), Vector2(4.6, 3.6), Color(RED, 0.35), false)
			_light(room, Vector3(0, 1.8, door_z + 1.3), Color(1.0, 0.45, 0.2), 1.8, 6.5)
			for side in [-1.0, 1.0]:
				var p := Vector3(side * (Room.DOOR_HALF + 1.1), 0, door_z + 0.6)
				if not _free(layout, Vector2i(2 if side < 0 else 6, 0)):
					continue   # a pillar, trap or skeleton already stands there
				var n := _place(room, p, 0.0)
				Props._mesh(n, Props._brazier())
				Fx.flame(n, Vector2(0.7, 0.95), Vector3(0, 0.8, 0))
				Fx.flame(n, Vector2(0.4, 0.6), Vector3(0.12, 0.8, 0.1))
				room._add_obstacle(Vector3(p.x, 0, door_z), 1.0)   # on the wall line (see above)
		"shaft":
			# A cold light falling through a crack in the ceiling, off to one side.
			var x := -2.2 if randf() < 0.5 else 2.2
			_pool(room, Vector3(x, 0, -1.5), Vector2(4.4, 4.4), Color(0.6, 0.75, 1.0, 0.2), false)
			_pool(room, Vector3(x, 0, -1.5), Vector2(2.4, 2.4), Color(0.75, 0.85, 1.0, 0.2), false)
		"circle":
			_pool(room, Vector3(0, 0, -0.7), Vector2(5.2, 5.2), Color(torch, 0.45), true)
			var candle := Art.get_model("candle_triple")
			if candle:
				for c: Vector2i in [Vector2i(4, 4), Vector2i(2, 6), Vector2i(6, 6), Vector2i(4, 8)]:
					var p := Room.cell_to_world(c.x, c.y)
					if not _free(layout, c) or not room.is_walkable(p, 0.6):
						continue
					Art.place_prop(candle, _place(room, p, randf() * TAU), 0.55)
					room._add_obstacle(p, 0.3)


## Whether layout cell `c` is open floor (no pillar, barrel, trap or spawn).
static func _free(layout: Array, c: Vector2i) -> bool:
	if c.y < 0 or c.y >= layout.size():
		return false
	var line: String = layout[c.y]
	return c.x >= 0 and c.x < line.length() and line[c.x] == "."


static func _place(room: Room, p: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	room.add_child(n)
	return n


## A glowing shape on the floor: a soft pool, or (`ring`) a thin rune ring.
static func _pool(room: Room, p: Vector3, size: Vector2, color: Color, ring: bool) -> void:
	var key := ("ring " if ring else "pool ") + color.to_html()
	if not _mats.has(key):
		var m := U.unlit(color, _ring_tex() if ring else U.soft_circle()).duplicate() as StandardMaterial3D
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.render_priority = -1   # under warnings, shots and pickups
		_mats[key] = m
	var q := U.floor_quad(room, size, _mats[key], p + Vector3(0, 0.03, 0))
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _light(room: Room, p: Vector3, color: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	l.position = p
	room.add_child(l)


## Two thin bright rings with a faint band between them, like a circle cut in the floor.
static func _ring_tex() -> GradientTexture2D:
	if _ring:
		return _ring
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.66, 0.72, 0.76, 0.86, 0.9, 0.94, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.12),
		Color(1, 1, 1, 0.12), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_ring = GradientTexture2D.new()
	_ring.gradient = g
	_ring.width = 256
	_ring.height = 256
	_ring.fill = GradientTexture2D.FILL_RADIAL
	_ring.fill_from = Vector2(0.5, 0.5)
	_ring.fill_to = Vector2(1.0, 0.5)
	return _ring
