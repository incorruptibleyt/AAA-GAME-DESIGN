class_name Props
## Each floor has its own things in the corners and on the walls, so floors differ in shape
## and not just in colour: skull piles and candles in the Bone Crypt, icicles and ice
## crystals in the Frozen Ossuary, braziers and lava grates in the Ember Catacomb (on the
## walls, so they never look like fire on the floor), broken columns grown over with kelp
## and drains pouring water in the Drowned Vault. The pieces are simple shapes baked
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
