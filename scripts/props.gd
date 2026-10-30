class_name Props
## Each floor has its own things in the corners and on the walls, so floors differ in shape
## and not just in colour: skull piles and candles in the Bone Crypt, icicles and ice
## crystals in the Frozen Ossuary, braziers and lava grates in the Ember Catacomb (on the
## walls, so they never look like fire on the floor). The pieces are simple shapes baked
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
		room._add_obstacle(p, 0.55)
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
		var len := rng.randf_range(0.35, 1.0) * (1.3 if i == 3 else 1.0)
		var z := (i - 3) * 0.2 + rng.randf_range(-0.05, 0.05)
		parts.append([_cone(0.08, 0.0, len, 6), _xf(Vector3(0.08, -len * 0.5, z), Vector3.ONE), _ice()])
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
