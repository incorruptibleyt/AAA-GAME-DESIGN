class_name Props
## Each floor has its own things in the corners and on the walls, so floors differ in shape
## and not just in colour: skull piles and candles in the Bone Crypt, icicles and ice
## crystals in the Frozen Ossuary, braziers and lava grates in the Ember Catacomb (on the
## walls, so they never look like fire on the floor), broken columns grown over with kelp
## and drains pouring water in the Drowned Vault, clumps of glowing mushrooms and shelf
## fungus in the Glowcap Grotto. The pieces are simple shapes baked
## into one mesh per material and add no lights, so they stay cheap on phones. A corner
## piece only goes where the room's layout leaves that corner empty.

const CORNERS := [Vector2i(0, 0), Vector2i(Layouts.COLUMNS - 1, 0), Vector2i(0, Layouts.ROWS - 1),
	Vector2i(Layouts.COLUMNS - 1, Layouts.ROWS - 1)]
## Spots along the side walls between the torches (which are at -6, 0 and 6).
const WALL_Z := [-3.0, 3.0]

static var _baked := {}


static func dress(room: Room, layout: Array) -> void:
	var kind: String = Floors.current().get("props", "")
	for c: Vector2i in CORNERS:
		var row: String = layout[c.y] if c.y < layout.size() else ""
		if c.x < row.length() and row[c.x] != ".":
			continue
		var p := Room.cell_to_world(c.x, c.y)
		p += Vector3(signf(p.x), 0, signf(p.z)) * 0.12   # snug into the corner
		var n := _place(room, p)
		match kind:
			"bone":
				_mesh(n, _skull_pile(true))
				var candle := Art.get_model("candle_triple")
				if candle:
					var at := p + Vector3(0, 0, -signf(p.z) * 0.7)
					Art.place_prop(candle, _place(room, at), 0.6)
					room._add_obstacle(at, 0.3)
			"ice":
				_mesh(n, _crystals())
			"ember":
				_mesh(n, _brazier())
				Fx.flame(n, Vector2(0.7, 0.95), Vector3(0, 0.8, 0))
				Fx.flame(n, Vector2(0.4, 0.6), Vector3(0.15, 0.8, 0.1))
			"water":
				_mesh(n, _kelp_column())
			"fungus":
				_mesh(n, _mushroom_clump())
				_glow_pool(n, 2.6)
		# The prop's collision is a circle centred on the room's true corner, so a push out of
		# it always points into the room (centred on the prop, it could push a skeleton out
		# through the walls, where nothing could reach it).
		var corner := Vector3(signf(p.x) * Room.HALF_W, 0, signf(p.z) * Room.HALF_L)
		room._add_obstacle(corner, 0.55 + Vector2(p.x - corner.x, p.z - corner.z).length())
	for side in [-1.0, 1.0]:
		for z in WALL_Z:
			match kind:
				"bone":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.3), 0, z))
					_mesh(n, _skull_pile(false))
				"ice":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.06), Room.WALL_H, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _icicles())
				"ember":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _grate())
				"water":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_add_spout(n)
				"fungus":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _shelf_fungus())
	_dress_kit(room, layout, kind)
	_scatter(room, layout, kind)
	# Two more on the far wall, either side of the door.
	for x in [-3.6, 3.6]:
		match kind:
			"ice":
				var n := _place(room, Vector3(x, Room.WALL_H, -Room.HALF_L + 0.06), false)
				n.rotation.y = -PI / 2
				_mesh(n, _icicles())
			"ember":
				var n := _place(room, Vector3(x, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_mesh(n, _grate())
			"water":
				var n := _place(room, Vector3(x, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_add_spout(n)
			"fungus":
				var n := _place(room, Vector3(x, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_mesh(n, _shelf_fungus())


## KayKit pieces along the walls (version 134): a banner either side of the door and a few
## things left against the side walls between the torches, different on every floor, so the
## edges of the room read as a real crypt and not a tiled box. Each sits tight to its wall
## with a small collision circle. [model, height] pairs; the sides take them in a different
## order, so the two walls don't mirror each other.
const KIT := {
	"bone": {"banner": "banner_patternA_red", "side": [["barrel_small", 0.8], ["box_small_decorated", 0.62], ["sword_shield_broken", 0.6], ["rubble_half", 0.5]]},
	"ice": {"banner": "banner_patternB_white", "side": [["box_small", 0.6], ["rubble_half", 0.5], ["barrel_small", 0.8], ["sword_shield_broken", 0.6]]},
	"ember": {"banner": "banner_patternC_red", "side": [["rubble_half", 0.55], ["barrel_small", 0.8], ["coin_stack_small", 0.35], ["box_small", 0.6]]},
	"water": {"banner": "banner_patternA_blue", "side": [["rubble_half", 0.5], ["barrel_small", 0.8], ["box_small", 0.6], ["bottle_A_green", 0.4]]},
	"fungus": {"banner": "banner_patternA_green", "side": [["rubble_half", 0.55], ["box_small", 0.6], ["barrel_small", 0.8], ["bottle_B_brown", 0.4]]},
}
const KIT_Z := [-7.8, -4.4, 1.7, 4.4]


static func _dress_kit(room: Room, layout: Array, kind: String) -> void:
	if not KIT.has(kind):
		return
	var kit: Dictionary = KIT[kind]
	var banner := Art.get_model(kit.banner)
	if banner:
		for x in [-2.5, 2.5]:
			var n := _place(room, Vector3(x, 0.75, -Room.HALF_L + 0.12), false)
			_no_shadow(Art.place_prop(banner, n, 1.75))
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var col := 0 if s == 0 else Layouts.COLUMNS - 1
		for i in KIT_Z.size():
			var z: float = KIT_Z[i]
			var row := roundi(z / Room.CELL + (Layouts.ROWS - 1) * 0.5)
			var line: String = layout[row] if row >= 0 and row < layout.size() else ""
			if col < line.length() and line[col] != ".":
				continue
			var pick: Array = kit.side[(i + s * 2) % kit.side.size()]
			var scene := Art.get_model(pick[0])
			if scene == null:
				continue
			var at := Vector3(side * (Room.HALF_W - 0.42), 0, z)
			_no_shadow(Art.place_prop(scene, _place(room, at), pick[1]))
			room._add_obstacle(Vector3(side * Room.HALF_W, 0, z), 0.7)


## Pieces flat against a wall cast no shadow worth its cost (a second draw each on High).
static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


## Little things lying on the floor (version 134): pebbles and broken stone everywhere,
## plus each crypt's own bits: bones and skulls in the Bone Crypt, ice shards in the
## Frozen Ossuary, charcoal and bones in the Ember Catacomb, shells in the Drowned Vault and
## tiny glowing mushrooms in the Glowcap Grotto. They lie in small clusters, more of them by
## the walls and at the feet of pillars, and are too low to block anyone. All of it is baked
## into one mesh (a draw or two per material) with no shadows, so it costs almost nothing.
const SCATTER_CLUSTERS := 22


static func _scatter(room: Room, layout: Array, kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(layout)) + Game.floor_num * 7919
	var look := Floors.current()
	var stone := U.mat((look.floor as Color) * Color(0.42, 0.4, 0.46), 0.95)
	var chip := U.mat((look.floor as Color) * Color(0.62, 0.6, 0.66), 0.9)
	var bone := U.mat(Color(0.82, 0.78, 0.66), 0.85)
	var dark := U.mat(Color(0.06, 0.05, 0.05), 1.0)
	var parts := []
	# Spots: the feet of pillars and other obstacles, the walls, and the open floor.
	var spots: Array[Vector3] = []
	for o: Dictionary in room.obstacles:
		var p: Vector3 = o.pos
		if absf(p.x) < Room.HALF_W - 0.8 and absf(p.z) < Room.HALF_L - 0.8:
			var a := rng.randf() * TAU
			spots.append(p + Vector3(cos(a), 0, sin(a)) * (float(o.r) + 0.15))
	while spots.size() < SCATTER_CLUSTERS:
		if rng.randf() < 0.45:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			spots.append(Vector3(side * (Room.HALF_W - rng.randf_range(0.25, 0.7)), 0, rng.randf_range(-Room.HALF_L + 1.0, Room.HALF_L - 1.5)))
		else:
			spots.append(Vector3(rng.randf_range(-Room.HALF_W + 1.0, Room.HALF_W - 1.0), 0, rng.randf_range(-Room.HALF_L + 1.5, Room.HALF_L - 2.0)))
	spots.shuffle()
	for i in mini(spots.size(), SCATTER_CLUSTERS + 4):
		var at: Vector3 = spots[i]
		var n := rng.randi_range(2, 5)
		for j in n:
			var p := at + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			var yaw := Basis(Vector3.UP, rng.randf() * TAU)
			var roll := rng.randf()
			if roll < 0.5:
				# Pebbles and broken stone.
				var sz := rng.randf_range(0.08, 0.17)
				var m := chip if rng.randf() < 0.4 else stone
				if rng.randf() < 0.5:
					parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.35, Vector3(sz, sz * 0.55, sz * 0.8), yaw), m])
				else:
					parts.append([_cube(), _xf(p + Vector3.UP * sz * 0.4, Vector3(sz * 1.6, sz, sz * 1.2), yaw * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))), m])
			else:
				_scatter_piece(parts, kind, p, yaw, rng, bone, dark)
	if parts.is_empty():
		return
	var mi := _mesh(_place(room, Vector3.ZERO, false), _bake(parts))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _scatter_piece(parts: Array, kind: String, p: Vector3, yaw: Basis, rng: RandomNumberGenerator, bone: Material, dark: Material) -> void:
	match kind:
		"bone", "ember":
			if kind == "ember" and rng.randf() < 0.5:
				# Charcoal.
				var sz := rng.randf_range(0.1, 0.18)
				parts.append([_cube(), _xf(p + Vector3.UP * sz * 0.35, Vector3(sz * 1.5, sz * 0.7, sz), yaw), dark])
			elif rng.randf() < 0.22:
				# A small skull, looking any way.
				var sz := 0.16
				parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.85, Vector3(sz, sz * 0.92, sz * 1.05), yaw), bone])
				parts.append([_cube(), _xf(p + Vector3.UP * sz * 0.3 + yaw * Vector3(0, 0, -sz * 0.4), Vector3(sz * 0.95, sz * 0.4, sz * 0.7), yaw), bone])
				for ex in [-0.38, 0.38]:
					parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.9 + yaw * Vector3(ex * sz, 0, -sz * 0.88), Vector3.ONE * sz * 0.26), dark])
			else:
				# A long bone with knobbed ends, lying flat.
				var bl := rng.randf_range(0.42, 0.7)
				var flat := yaw * Basis(Vector3.RIGHT, PI / 2)
				parts.append([_cone(0.04, 0.04, bl, 6), Transform3D(flat, p + Vector3.UP * 0.05), bone])
				for e in [-0.5, 0.5]:
					parts.append([_sphere(), _xf(p + Vector3.UP * 0.06 + yaw * Vector3(0, 0, e * bl), Vector3.ONE * 0.068), bone])
		"ice":
			# Frost-white shards lying almost flat (pale, so they never look like a Frost Wraith's bolt).
			var ice := U.mat(Color(0.82, 0.9, 0.97), 0.35)
			var h := rng.randf_range(0.16, 0.3)
			var tilt := yaw * Basis(Vector3.RIGHT, rng.randf_range(1.0, 1.35))
			parts.append([_cone(0.0, h * 0.3, h, 4), Transform3D(tilt, p + Vector3.UP * 0.05), ice])
		"water":
			# Shells: little pale fans.
			var sz := rng.randf_range(0.1, 0.16)
			parts.append([_cone(0.0, sz, sz * 0.5, 7), _xf(p + Vector3.UP * sz * 0.15, Vector3(1, 0.6, 1.3), yaw), bone])
		"fungus":
			# A tiny mushroom: a stalk and a glowing cap.
			var h := rng.randf_range(0.13, 0.24)
			parts.append([_cone(0.03, 0.038, h, 5), Transform3D(yaw, p + Vector3.UP * h * 0.5), bone])
			parts.append([_sphere(), _xf(p + Vector3.UP * h, Vector3(h * 0.55, h * 0.3, h * 0.55), yaw), _cap_mat(rng.randf() < 0.75)])
		_:
			pass


static func _cap_mat(pink: bool) -> Material:
	var key := "cap_pink" if pink else "cap_lime"
	if not _baked.has(key):
		var col := Color(0.85, 0.42, 0.66) if pink else Color(0.6, 0.78, 0.35)
		_baked[key] = U.mat(col.lerp(Color(0.45, 0.4, 0.4), 0.45), 0.7)   # dull, unlit: glowing pink means spores
	return _baked[key]


static func _place(room: Room, p: Vector3, turn := true) -> Node3D:
	var n := Node3D.new()
	n.position = p
	if turn:
		n.rotation.y = randf() * TAU
	room.add_child(n)
	return n


static func _mesh(parent: Node3D, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


## Several simple shapes baked into one mesh, one surface per material.
## parts: [[mesh, transform, material], ...]
static func _bake(parts: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	var groups := {}
	for part in parts:
		if not groups.has(part[2]):
			groups[part[2]] = []
		groups[part[2]].append(part)
	for m: Material in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[m]:
			st.append_from(part[0], 0, part[1])
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, m)
	return out


static func _sphere() -> SphereMesh:
	if not _baked.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 12
		s.rings = 6
		_baked["sphere"] = s
	return _baked["sphere"]


static func _cube() -> BoxMesh:
	if not _baked.has("cube"):
		_baked["cube"] = BoxMesh.new()
	return _baked["cube"]


## A cone or prism, `top` and `bottom` radii, `h` tall, centred on its middle.
static func _cone(top: float, bottom: float, h: float, sides := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


static func _xf(at: Vector3, scale: Vector3, basis := Basis.IDENTITY) -> Transform3D:
	return Transform3D(basis * Basis.from_scale(scale), at)


## Skulls heaped up, each looking outwards, with a few long bones (a small one for walls).
static func _skull_pile(big: bool) -> ArrayMesh:
	var key := "skulls_big" if big else "skulls"
	if _baked.has(key):
		return _baked[key]
	var bone := U.mat(Color(0.86, 0.82, 0.7), 0.85)
	var dark := U.mat(Color(0.07, 0.05, 0.06), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if big else 23
	var parts := []
	var count := 7 if big else 3
	for i in count:
		var a := rng.randf() * TAU
		var r := 0.0 if (big and i == 0) else rng.randf_range(0.22, 0.42) if big else rng.randf_range(0.0, 0.22)
		var s := rng.randf_range(0.17, 0.23)
		var at := Vector3(cos(a) * r, s * 0.9 + (0.24 if big and i == 0 else 0.0), sin(a) * r)
		var look := Vector3(cos(a), 0.15, sin(a)) if r > 0.05 else Vector3(0, 0.15, 1)
		var b := Basis.looking_at(look, Vector3.UP)   # the face is -Z
		parts.append([_sphere(), _xf(at, Vector3(s, s * 0.92, s * 1.05), b), bone])
		parts.append([_cube(), _xf(at + b * Vector3(0, -s * 0.62, -s * 0.38), Vector3(s * 0.95, s * 0.4, s * 0.7), b), bone])
		for ex in [-0.38, 0.38]:
			parts.append([_sphere(), _xf(at + b * Vector3(ex * s, s * 0.05, -s * 0.88), Vector3.ONE * s * 0.26), dark])
	var long := _cone(0.045, 0.045, 0.6, 6)
	for i in (4 if big else 1):
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2)
		var a := rng.randf() * TAU
		parts.append([long, Transform3D(b, Vector3(cos(a) * 0.45, 0.05, sin(a) * 0.45)), bone])
	_baked[key] = _bake(parts)
	return _baked[key]


static func _ice() -> StandardMaterial3D:
	if not _baked.has("ice_mat"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.85, 1.0)
		m.roughness = 0.12
		m.metallic_specular = 0.9
		m.emission_enabled = true
		m.emission = Color(0.25, 0.55, 0.85)
		m.emission_energy_multiplier = 0.7
		_baked["ice_mat"] = m
	return _baked["ice_mat"]


## Ice crystals growing out of a corner, leaning outwards.
static func _crystals() -> ArrayMesh:
	if _baked.has("crystals"):
		return _baked["crystals"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var parts := []
	for i in 6:
		var h := rng.randf_range(0.55, 1.35) if i > 0 else 1.5
		var a := i / 6.0 * TAU + rng.randf() * 0.5
		var lean := 0.0 if i == 0 else rng.randf_range(0.25, 0.55)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, lean)
		var at := Vector3(cos(a), 0, sin(a)) * (0.0 if i == 0 else 0.25)
		parts.append([_cone(0.03, 0.15 * h, h, 6), Transform3D(b, at + b * Vector3(0, h * 0.5, 0)), _ice()])
	_baked["crystals"] = _bake(parts)
	return _baked["crystals"]


## Icicles hanging from the top of a wall; +X points out of the wall.
static func _icicles() -> ArrayMesh:
	if _baked.has("icicles"):
		return _baked["icicles"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var parts := []
	for i in 7:
		var length := rng.randf_range(0.35, 1.0) * (1.3 if i == 3 else 1.0)
		var z := (i - 3) * 0.2 + rng.randf_range(-0.05, 0.05)
		parts.append([_cone(0.08, 0.0, length, 6), _xf(Vector3(0.08, -length * 0.5, z), Vector3.ONE), _ice()])
	parts.append([_cube(), _xf(Vector3(0.05, -0.04, 0), Vector3(0.12, 0.1, 1.5)), _ice()])
	_baked["icicles"] = _bake(parts)
	return _baked["icicles"]


## An iron brazier on three legs, full of glowing coals (the flames are added separately).
static func _brazier() -> ArrayMesh:
	if _baked.has("brazier"):
		return _baked["brazier"]
	var iron := U.mat(Color(0.13, 0.11, 0.11), 0.45)
	var coals := U.mat(Color(1.0, 0.38, 0.08), 0.9, 2.5)
	var parts := []
	parts.append([_cone(0.44, 0.22, 0.3, 12), _xf(Vector3(0, 0.7, 0), Vector3.ONE), iron])
	parts.append([_cone(0.48, 0.48, 0.06, 12), _xf(Vector3(0, 0.86, 0), Vector3.ONE), iron])
	for i in 3:
		var a := i / 3.0 * TAU
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.3)
		parts.append([_cube(), _xf(Vector3(cos(a) * 0.24, 0.3, sin(a) * 0.24), Vector3(0.07, 0.65, 0.07), b), iron])
	parts.append([_sphere(), _xf(Vector3(0, 0.84, 0), Vector3(0.4, 0.12, 0.4)), coals])
	_baked["brazier"] = _bake(parts)
	return _baked["brazier"]


## Lava glowing behind an iron grate set into a wall; +X points out of the wall.
static func _grate() -> ArrayMesh:
	if _baked.has("grate"):
		return _baked["grate"]
	var iron := U.mat(Color(0.1, 0.08, 0.08), 0.5)
	var lava := U.mat(Color(1.0, 0.42, 0.08), 0.9, 3.0)
	var parts := []
	parts.append([_cube(), _xf(Vector3(0.02, 0.9, 0), Vector3(0.04, 0.9, 1.1)), lava])
	parts.append([_cube(), _xf(Vector3(0.05, 0.4, 0), Vector3(0.1, 0.1, 1.3)), iron])
	parts.append([_cube(), _xf(Vector3(0.05, 1.4, 0), Vector3(0.1, 0.1, 1.3)), iron])
	for i in 5:
		parts.append([_cube(), _xf(Vector3(0.07, 0.9, (i - 2) * 0.25), Vector3(0.06, 1.0, 0.06)), iron])
	for z in [-0.6, 0.6]:
		parts.append([_cube(), _xf(Vector3(0.05, 0.9, z), Vector3(0.1, 1.1, 0.1)), iron])
	_baked["grate"] = _bake(parts)
	return _baked["grate"]


## A broken column in the corner, slick and green, with kelp growing up around it.
static func _kelp_column() -> ArrayMesh:
	if _baked.has("kelp_column"):
		return _baked["kelp_column"]
	var stone := U.mat(Color(0.36, 0.46, 0.44), 0.35)
	var moss := U.mat(Color(0.14, 0.32, 0.18), 0.8)
	var kelp := U.mat(Color(0.2, 0.52, 0.26), 0.55, 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var parts := []
	parts.append([_cone(0.36, 0.42, 0.9, 10), _xf(Vector3(0, 0.45, 0), Vector3.ONE), stone])
	parts.append([_cone(0.44, 0.48, 0.14, 10), _xf(Vector3(0, 0.07, 0), Vector3.ONE), stone])
	# The broken-off top, lying against the stump.
	parts.append([_cone(0.3, 0.33, 0.55, 10), _xf(Vector3(0.45, 0.28, 0.2), Vector3.ONE, Basis(Vector3.FORWARD, 1.35)), stone])
	parts.append([_sphere(), _xf(Vector3(0, 0.88, 0), Vector3(0.37, 0.07, 0.37)), moss])
	for i in 7:
		var a := i / 7.0 * TAU + rng.randf() * 0.6
		var h := rng.randf_range(0.8, 1.7)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, rng.randf_range(0.1, 0.35))
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.42, 0.62)
		parts.append([_cone(0.0, 0.06, h, 5), Transform3D(b * Basis.from_scale(Vector3(1.0, 1.0, 0.4)), at + b * Vector3(0, h * 0.5, 0)), kelp])
	_baked["kelp_column"] = _bake(parts)
	return _baked["kelp_column"]


## A stone drain in the wall pouring a thin fall of water into a splash; +X points out of
## the wall. The falling water is drawn by a little shader, so it runs.
static func _add_spout(n: Node3D) -> void:
	_mesh(n, _spout())
	var splash := U.floor_quad(n, Vector2(1.3, 1.3), _splash_mat(), Vector3(0.4, 0.03, 0))
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foam := U.floor_quad(n, Vector2(0.9, 0.9), _foam_mat(), Vector3(0.4, 0.04, 0))
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _spout() -> ArrayMesh:
	if _baked.has("spout"):
		return _baked["spout"]
	var stone := U.mat(Color(0.34, 0.44, 0.43), 0.5)
	var dark := U.mat(Color(0.02, 0.04, 0.05), 1.0)
	var parts := []
	parts.append([_cube(), _xf(Vector3(0.05, 1.75, 0), Vector3(0.1, 0.7, 0.7)), stone])
	parts.append([_cube(), _xf(Vector3(0.22, 1.62, 0), Vector3(0.36, 0.12, 0.3)), stone])
	parts.append([_cube(), _xf(Vector3(0.11, 1.8, 0), Vector3(0.04, 0.3, 0.36)), dark])
	parts.append([_cube(), _xf(Vector3(0.38, 0.8, 0), Vector3(0.22, 1.6, 0.34)), _falling_water()])
	_baked["spout"] = _bake(parts)
	return _baked["spout"]


static func _falling_water() -> ShaderMaterial:
	if _baked.has("fall_mat"):
		return _baked["fall_mat"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.45, 0.95, 0.85, 1.0);
varying vec3 p;
void vertex() {
	p = VERTEX;
}
float h(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}
void fragment() {
	// Streaks that run down at slightly different speeds, brighter where they land.
	float lane = floor(p.z * 30.0 + p.x * 20.0);
	float s = fract(p.y * 1.4 + TIME * (1.8 + h(lane)) + h(lane + 3.0));
	float streak = smoothstep(0.0, 0.6, s) * (0.4 + 0.6 * h(lane + 7.0));
	float foot = 1.0 - smoothstep(0.0, 0.5, p.y);
	ALBEDO = col.rgb * (0.06 + 0.4 * streak + 0.45 * foot);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_baked["fall_mat"] = m
	return m


static func _foam_mat() -> StandardMaterial3D:
	if not _baked.has("foam_mat"):
		var m := U.unlit(Color(0.7, 1.0, 0.95, 0.4), U.soft_circle()).duplicate()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_baked["foam_mat"] = m
	return _baked["foam_mat"]


static func _splash_mat() -> StandardMaterial3D:
	if not _baked.has("splash_mat"):
		var m := U.unlit(Color(0.55, 1.0, 0.9, 0.35), U.ring()).duplicate()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_baked["splash_mat"] = m
	return _baked["splash_mat"]


## A clump of mushrooms in a corner: one tall glowing toadstool leaning out of the corner,
## two middling ones and a few buttons around their feet, on a mound of dark moss.
static func _mushroom_clump() -> ArrayMesh:
	if _baked.has("mushrooms"):
		return _baked["mushrooms"]
	var moss := U.mat(Color(0.12, 0.13, 0.1), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var parts := []
	parts.append([_sphere(), _xf(Vector3(0, 0.0, 0), Vector3(0.75, 0.22, 0.75)), moss])
	# [height, cap radius, lean, distance out, angle]
	var plan := [[1.75, 0.62, 0.12, 0.0, 0.0], [1.05, 0.4, 0.38, 0.45, 2.2], [0.8, 0.32, 0.45, 0.48, 4.1],
		[0.38, 0.17, 0.3, 0.62, 1.0], [0.3, 0.14, 0.5, 0.6, 3.2], [0.42, 0.18, 0.25, 0.55, 5.3]]
	for m in plan:
		var a: float = m[4] + rng.randf() * 0.4
		var at := Vector3(cos(a), 0, sin(a)) * float(m[3])
		parts.append_array(FungalLook.mushroom_parts(m[0], m[1], m[2], at, -a, 6 if m[1] > 0.3 else 3))
	_baked["mushrooms"] = _bake(parts)
	return _baked["mushrooms"]


## Shelf fungus growing out of a wall in three tiers, glowing at the rim, with a pale stalk
## of tiny mushrooms below; +X points out of the wall.
static func _shelf_fungus() -> ArrayMesh:
	if _baked.has("shelf"):
		return _baked["shelf"]
	var mats := FungalLook.cap_materials()
	var parts := []
	var half := SphereMesh.new()
	half.radius = 1.0
	half.height = 1.0
	half.is_hemisphere = true
	half.radial_segments = 12
	half.rings = 3
	var tiers := [[1.55, 0.42, 0.0], [1.1, 0.32, 0.28], [0.75, 0.24, -0.22]]
	for t in tiers:
		var r: float = t[1]
		# A flattened half-dome stuck to the wall: wide along the wall, shallow out of it.
		parts.append([half, _xf(Vector3(0.0, t[0], t[2]), Vector3(r * 0.9, r * 0.32, r * 1.3)), mats[0]])
		parts.append([_cone(r * 0.85, r * 0.85, 0.05, 12), _xf(Vector3(0.0, t[0] - 0.02, t[2]), Vector3(1.0, 1.0, 1.5)), mats[1]])
		for k in 3:
			var z: float = t[2] + (k - 1) * r * 0.55
			parts.append([_sphere(), _xf(Vector3(r * 0.45, t[0] + r * 0.2, z), Vector3.ONE * r * 0.12), mats[2]])
	for k in 3:
		parts.append_array(FungalLook.mushroom_parts(0.22 + 0.06 * k, 0.09 + 0.02 * k, 0.4, Vector3(0.18, 0, (k - 1) * 0.22), 0.0, 3))
	_baked["shelf"] = _bake(parts)
	return _baked["shelf"]


## The soft pink light a clump of glowcaps throws on the floor around it (no real light:
## lights cost a lot on phones).
static func _glow_pool(n: Node3D, size: float) -> void:
	if not _baked.has("glow_pool"):
		var m := U.unlit(Color(1.0, 0.4, 0.82, 0.32), U.soft_circle()).duplicate()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_baked["glow_pool"] = m
	var q := U.floor_quad(n, Vector2(size, size), _baked["glow_pool"], Vector3(0, 0.035, 0))
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
