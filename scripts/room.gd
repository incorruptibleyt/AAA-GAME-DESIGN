class_name Room
extends Node3D
## Builds one crypt room from a text layout (see layouts.gd) and answers the
## "can I stand here?" questions for movement and bolts. Collision is simple circles and
## a rectangle, which is fast and predictable on phones.
##
## The far end of the room (with the exit door) is towards -Z.

const CELL := 4.0 / 3.0
const HALF_W := Layouts.COLUMNS * CELL * 0.5   # 6
const HALF_L := Layouts.ROWS * CELL * 0.5      # 10
const WALL_H := 2.6
const DOOR_HALF := 1.2

static var current: Room

var obstacles: Array = []   # [{pos: Vector3, r: float}]
var spawns: Array = []      # [{kind: String, pos: Vector3}]
var door_open := false

var _portcullis: Node3D
var _exit_light: OmniLight3D
var _torch_lights: Array[OmniLight3D] = []
var _exit_glow: MeshInstance3D


static func build(parent: Node, layout: Array, label: String) -> Room:
	if current and is_instance_valid(current):
		current.queue_free()
	var room := Room.new()
	room.name = "Room %s" % label
	parent.add_child(room)
	current = room
	room._build_shell()
	room._read_layout(layout)
	Props.dress(room, layout)
	return room


static func cell_to_world(col: int, row: int) -> Vector3:
	return Vector3((col - (Layouts.COLUMNS - 1) * 0.5) * CELL, 0.0, (row - (Layouts.ROWS - 1) * 0.5) * CELL)


func player_start() -> Vector3:
	# A little up from the near wall, so the camera can keep the hero above the thumb.
	return Vector3(0, 0, HALF_L - 3.0)


# ---------------------------------------------------------------- building

func _build_shell() -> void:
	var look := Floors.current()
	var wall := U.mat(look.wall, 0.95)
	var trim := U.mat(look.trim, 0.85)
	var dark := U.mat(Color(0.02, 0.02, 0.04), 1.0)

	# Floor: textured flagstones, plus a dark surround so the room edges read clearly.
	var f := U.floor_quad(self, Vector2(HALF_W * 2, HALF_L * 2), _floor_material(look))
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.floor_quad(self, Vector2(70, 90), dark, Vector3(0, -0.05, 0))

	var t := 1.0
	U.box(self, Vector3(t, WALL_H, HALF_L * 2 + t * 2), wall, Vector3(-HALF_W - t / 2, WALL_H / 2, 0))
	U.box(self, Vector3(t, WALL_H, HALF_L * 2 + t * 2), wall, Vector3(HALF_W + t / 2, WALL_H / 2, 0))
	# The near wall is only a low ledge so it never hides the hero from the camera. It is
	# laid with darker stone than the floor, so the bottom of the screen reads as the top
	# of a wall instead of a flat coloured bar.
	U.box(self, Vector3(HALF_W * 2 + t * 2, 0.5, t), _ledge_material(look), Vector3(0, 0.25, HALF_L + t / 2))
	var side := HALF_W - DOOR_HALF
	U.box(self, Vector3(side, WALL_H, t), wall, Vector3(-DOOR_HALF - side / 2, WALL_H / 2, -HALF_L - t / 2))
	U.box(self, Vector3(side, WALL_H, t), wall, Vector3(DOOR_HALF + side / 2, WALL_H / 2, -HALF_L - t / 2))
	U.box(self, Vector3(1.2, 0.16, HALF_L * 2 + 2), trim, Vector3(-HALF_W - 0.5, WALL_H + 0.08, 0))
	U.box(self, Vector3(1.2, 0.16, HALF_L * 2 + 2), trim, Vector3(HALF_W + 0.5, WALL_H + 0.08, 0))

	_build_door(trim, dark)

	for z in [-6.0, 0.0, 6.0]:
		_add_torch(Vector3(-HALF_W + 0.05, 1.7, z), 1.0)
		_add_torch(Vector3(HALF_W - 0.05, 1.7, z), -1.0)
	apply_graphics(Game._high_graphics)


static var _floor_shader: Shader

## Worn flagstones in the floor's colour, drawn by one shader for every theme: uneven slabs
## laid in staggered rows, grime that gathers in big patches and along the walls (moss and
## dirt, frost, soot), a second kind of patch (damp stone, glassy ice, ash), a few cracked
## slabs and darker floor by the walls. A floor with "seams" (the Ember Catacomb) has fire
## glowing in the gaps and cracks, hot in some places and cooled in others. A floor with
## "water" (the Drowned Vault) has shallow water in the low places and the gaps, rippling,
## glossy and lit from below by moving light. Deeper endless loops add blood. Everything is worked out from where the point is in the room, so there
## is no tiling pattern to spot.
static func _floor_material(look: Dictionary) -> Material:
	if _floor_shader == null:
		_floor_shader = Shader.new()
		_floor_shader.code = """
shader_type spatial;
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
uniform sampler2D blobs_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D blobs_b : repeat_enable, filter_linear_mipmap;
// Colours go straight to ALBEDO with no sRGB step, as the old flagstone texture did, so
// the floor keeps the brightness the fights were tuned on.
uniform vec4 tint = vec4(1.0);
uniform vec4 grout = vec4(0.07, 0.06, 0.07, 1.0);
uniform vec4 grime = vec4(0.2, 0.19, 0.13, 1.0);
uniform float grime_amount = 0.6;
uniform vec4 patch_tint = vec4(0.75, 0.76, 0.82, 1.0);
uniform float patch_rough = 0.3;
uniform float blood = 0.0;
uniform vec4 seam : source_color = vec4(0.0);
// Shallow water's colour; alpha is how much of the floor it covers (0 = dry).
uniform vec4 water = vec4(0.0);
uniform vec2 half_size = vec2(6.0, 10.0);
// 1 on the near ledge's box: its front face takes the pattern from its own plane and
// keeps its real normal.
uniform float ledge = 0.0;
varying vec2 pos;
varying float up;

float h(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	up = NORMAL.y;
	pos = (ledge > 0.5 && abs(NORMAL.y) < 0.5) ? VERTEX.xy : VERTEX.xz;
}

void fragment() {
	// Slabs 1.5 m wide and 1.1 m deep, each row shifted sideways by its own amount.
	const vec2 SLAB = vec2(1.5, 1.1);
	float row = floor(pos.y / SLAB.y);
	vec2 s = vec2(pos.x / SLAB.x + h(vec2(row, 3.7)), pos.y / SLAB.y);
	vec2 cell = floor(s);
	vec2 f = fract(s) - 0.5;            // -0.5 .. 0.5 across the slab
	vec2 e = (0.5 - abs(f)) * SLAB;     // metres to the slab's edges
	float edge = min(e.x, e.y);
	float r = h(cell);
	float r2 = h(cell + 13.7);

	float fine = texture(grain, pos * 0.23).r;
	float big = texture(blobs_a, pos * 0.05 + vec2(0.37, 0.11)).r;
	float big2 = texture(blobs_b, pos * 0.065 + vec2(0.71, 0.53)).r;

	// Stone: every slab a little lighter or darker, some warmer, all mottled.
	vec3 c = vec3(0.37, 0.34, 0.39) * (0.84 + 0.3 * r) * (0.72 + 0.56 * fine);
	c *= mix(vec3(1.0), vec3(1.07, 1.0, 0.9), step(0.6, r2));
	c *= tint.rgb;

	// Darker by the walls (light does not reach the corners), a little by the low near ledge.
	float wall = min(half_size.x - abs(pos.x), pos.y + half_size.y);
	float shade = mix(0.62, 1.0, smoothstep(0.0, 1.3, wall)) * mix(0.85, 1.0, smoothstep(0.0, 0.8, half_size.y - pos.y));

	// Grime gathers in big patches and along the walls.
	float g = smoothstep(0.58, 0.85, big + (1.0 - smoothstep(0.0, 2.0, wall)) * 0.25) * grime_amount;
	c = mix(c, grime.rgb * (0.8 + 0.4 * fine), g);

	// The second kind of patch changes colour and shine (wet stone and ice catch the torches).
	float p = smoothstep(0.6, 0.72, big2);
	c *= mix(vec3(1.0), patch_tint.rgb, p);
	float rough = mix(0.82, patch_rough, p);

	if (blood > 0.0) {
		float b = smoothstep(0.7, 0.78, texture(grain, pos * 0.07 + vec2(0.5, 0.2)).r) * blood;
		c = mix(c, vec3(0.3, 0.03, 0.03), b);
		rough = mix(rough, 0.35, b);
	}

	// Gaps between slabs, kept smooth at any distance.
	float aa = fwidth(edge);
	float gap = 1.0 - smoothstep(0.022 - aa, 0.022 + aa, edge);

	// About one slab in six has a crack: a wobbly line across its middle.
	float a = r2 * 3.1416;
	vec2 dir = vec2(cos(a), sin(a));
	float off = dot(f, vec2(-dir.y, dir.x)) + 0.035 * sin(dot(f, dir) * 13.0 + r * 30.0);
	float crack = (1.0 - smoothstep(0.0, 0.014 + fwidth(off), abs(off))) * step(0.84, r)
		* (1.0 - smoothstep(0.25, 0.45, abs(dot(f, dir))));

	c = mix(c, grout.rgb, gap);
	c *= (1.0 - crack * 0.55) * shade;
	rough = mix(rough, 0.95, max(gap, crack));

	// Slab edges are worn round and every slab sits a little crooked, so torchlight picks
	// out each one.
	vec2 bevel = sign(f) * (1.0 - smoothstep(0.0, 0.09, e)) * 0.6;
	vec3 n = normalize(vec3(bevel.x + (r - 0.5) * 0.1, 1.0, bevel.y + (r2 - 0.5) * 0.1));

	if (water.a > 0.0) {
		// Pools where the second patch lies, water standing in every gap and crack, and the
		// rest of the stone just wet. Two sets of ripples cross; light from the surface
		// moves over the bottom of the pools.
		float pool = max(smoothstep(0.57, 0.6, big2), max(gap, crack) * 0.9) * water.a;
		// Deeper (darker) towards the middle of a pool, with a pale wet line at its edge.
		float deep = smoothstep(0.6, 0.8, big2);
		float rim = smoothstep(0.555, 0.57, big2) * (1.0 - smoothstep(0.575, 0.59, big2));
		vec2 q = pos * 1.6;
		vec2 rip = vec2(sin(q.x * 2.3 + TIME * 1.4 + sin(q.y * 1.4 + TIME * 0.6)),
			sin(q.y * 2.1 - TIME * 1.2 + sin(q.x * 1.6 - TIME * 0.5)));
		float light = pow(0.5 + 0.5 * sin(q.x * 3.1 + rip.y * 1.6 + TIME * 0.9) * sin(q.y * 2.9 + rip.x * 1.6 - TIME * 0.7), 9.0);
		vec3 wet = water.rgb * mix(1.3, 0.8, deep) * (0.85 + 0.3 * fine);
		c = mix(c * mix(1.0, 0.82, water.a), wet, pool * 0.9);
		c += vec3(0.32, 0.45, 0.42) * rim * water.a * 0.3;
		rough = mix(mix(rough, 0.5, water.a * 0.6), 0.03, pool);
		n = normalize(n * (1.0 - pool) + vec3(rip.x * 0.12, 1.0, rip.y * 0.12) * pool);
		EMISSION = water.rgb * light * pool * (1.0 - deep * 0.5) * 0.5 * shade;
	}

	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = rough;
	if (up > 0.5) {
		NORMAL = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * n);
	}

	if (seam.a > 0.0) {
		float heat = smoothstep(0.56, 0.76, texture(blobs_b, pos * 0.05 + vec2(TIME * 0.006, 0.6)).r);
		float pulse = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(TIME * 1.3 + r * 6.283 + pos.x * 0.6 + pos.y * 0.35), 2.0);
		EMISSION = seam.rgb * max(gap, crack) * pulse * mix(0.6, 1.2, r) * mix(0.05, 1.25, heat);
	}
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _floor_shader
	sm.set_shader_parameter("grain", U.noise_tex(0.045, 11, 4))
	sm.set_shader_parameter("blobs_a", U.noise_tex(0.016, 23))
	sm.set_shader_parameter("blobs_b", U.noise_tex(0.018, 37))
	sm.set_shader_parameter("tint", look.floor)
	for key in ["grout", "grime", "grime_amount", "patch_tint", "patch_rough"]:
		if look.has(key):
			sm.set_shader_parameter(key, look[key])
	sm.set_shader_parameter("blood", look.get("blood", 0.0))
	sm.set_shader_parameter("seam", look.get("seams", Color(0, 0, 0, 0)))
	sm.set_shader_parameter("water", look.get("water", Color(0, 0, 0, 0)))
	sm.set_shader_parameter("half_size", Vector2(HALF_W, HALF_L))
	return sm


## The low near ledge: the floor's stone, darker, without the floor's fire, water or blood.
static func _ledge_material(look: Dictionary) -> Material:
	var m := _floor_material(look) as ShaderMaterial
	m.set_shader_parameter("tint", (look.floor as Color) * 0.6)
	m.set_shader_parameter("grime_amount", 0.0)
	m.set_shader_parameter("blood", 0.0)
	m.set_shader_parameter("seam", Color(0, 0, 0, 0))
	m.set_shader_parameter("water", Color(0, 0, 0, 0))
	m.set_shader_parameter("half_size", Vector2(100, 100))
	m.set_shader_parameter("ledge", 1.0)
	return m


## Every light costs a lot on phones, so High keeps the far and near pairs of torch
## lights (with a longer reach to cover the middle) and Low keeps only the middle pair.
## The torch flames themselves always show.
func apply_graphics(high: bool) -> void:
	for i in _torch_lights.size():
		var keep := (i != 2 and i != 3) if high else (i == 2 or i == 3)
		_torch_lights[i].visible = keep
		_torch_lights[i].omni_range = 9.5 if high else 11.0
		_torch_lights[i].light_energy = Floors.current().torch_energy * (1.0 if high else 1.2)


func _build_door(trim: Material, dark: Material) -> void:
	var door := Node3D.new()
	door.position = Vector3(0, 0, -HALF_L)
	add_child(door)
	U.box(door, Vector3(0.5, 3.2, 1.3), trim, Vector3(-DOOR_HALF - 0.2, 1.6, -0.4))
	U.box(door, Vector3(0.5, 3.2, 1.3), trim, Vector3(DOOR_HALF + 0.2, 1.6, -0.4))
	U.box(door, Vector3(DOOR_HALF * 2 + 0.9, 0.5, 1.3), trim, Vector3(0, 3.2, -0.4))
	U.box(door, Vector3(DOOR_HALF * 2, 2.8, 0.2), dark, Vector3(0, 1.4, -2.2))
	_exit_glow = U.box(door, Vector3(DOOR_HALF * 2, 2.8, 0.05), U.mat(Color(0.25, 0.45, 1.0), 1.0, 2.0), Vector3(0, 1.4, -2.0))
	_exit_glow.visible = false

	_portcullis = Node3D.new()
	_portcullis.position = Vector3(0, 0, -0.1)
	door.add_child(_portcullis)
	var iron := U.mat(Color(0.17, 0.17, 0.2), 0.4)
	for i in 6:
		var x := lerpf(-DOOR_HALF + 0.15, DOOR_HALF - 0.15, i / 5.0)
		U.box(_portcullis, Vector3(0.1, 2.9, 0.1), iron, Vector3(x, 1.45, 0))
	U.box(_portcullis, Vector3(DOOR_HALF * 2, 0.1, 0.12), iron, Vector3(0, 1.0, 0))
	U.box(_portcullis, Vector3(DOOR_HALF * 2, 0.1, 0.12), iron, Vector3(0, 2.1, 0))

	_exit_light = OmniLight3D.new()
	_exit_light.light_color = Color(0.4, 0.6, 1.0)
	_exit_light.omni_range = 6.0
	_exit_light.light_energy = 0.0
	_exit_light.visible = false   # a light at zero energy still costs a pass on phones
	_exit_light.position = Vector3(0, 1.5, 0.8)
	door.add_child(_exit_light)


func _add_torch(pos: Vector3, facing: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var prefab := Art.get_model(Art.TORCH)
	if prefab:
		Art.place_prop(prefab, root, 0.9)
	else:
		U.box(root, Vector3(0.3, 0.12, 0.12), U.mat(Color(0.2, 0.18, 0.16), 0.5), Vector3(0.15 * facing, -0.15, 0))
		U.box(root, Vector3(0.1, 0.4, 0.1), U.mat(Color(0.35, 0.22, 0.12)), Vector3(0.25 * facing, 0, 0))
		var flame := U.sphere(root, 0.13, U.mat(Color(1.0, 0.6, 0.2), 1.0, 4.0), Vector3(0.25 * facing, 0.28, 0))
		flame.scale = Vector3(1, 1.5, 1)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := Flicker.new()
	light.light_color = Floors.current().torch
	light.omni_range = 7.0
	light.light_energy = 1.4
	light.position = Vector3(0.8 * facing, 0.4, 0)
	root.add_child(light)
	_torch_lights.append(light)


func _read_layout(layout: Array) -> void:
	var stone := U.mat(Color(0.44, 0.42, 0.48), 0.9)
	var wood := U.mat(Color(0.47, 0.3, 0.16), 0.85)
	var iron := U.mat(Color(0.2, 0.2, 0.22), 0.4)
	for row in mini(Layouts.ROWS, layout.size()):
		var line: String = layout[row]
		for col in mini(Layouts.COLUMNS, line.length()):
			var ch := line[col]
			var p := cell_to_world(col, row)
			match ch:
				"#":
					_add_obstacle(p, 0.6)
					var prefab := Art.get_model(Art.PILLAR)
					if prefab:
						Art.place_prop(prefab, _anchor(p), WALL_H + 0.4)
					else:
						U.box(self, Vector3(1.2, 0.3, 1.2), stone, p + Vector3.UP * 0.15)
						U.cylinder(self, 0.45, WALL_H + 0.4, stone, p)
						U.box(self, Vector3(1.1, 0.25, 1.1), stone, p + Vector3.UP * (WALL_H + 0.4))
				"b":
					_add_obstacle(p, 0.45)
					var prefab := Art.get_model(Art.BARREL)
					if prefab:
						Art.place_prop(prefab, _anchor(p), 1.0)
					else:
						U.cylinder(self, 0.4, 0.95, wood, p)
						U.cylinder(self, 0.42, 0.06, iron, p + Vector3.UP * 0.2)
						U.cylinder(self, 0.42, 0.06, iron, p + Vector3.UP * 0.7)
				"c":
					_add_obstacle(p, 0.6)
					var prefab := Art.get_model(Art.CRATES)
					if prefab:
						Art.place_prop(prefab, _anchor(p), 1.4)
					else:
						var a := U.box(self, Vector3.ONE * 0.9, wood, p + Vector3.UP * 0.45)
						a.rotation.y = randf_range(-0.3, 0.3)
						var b := U.box(self, Vector3.ONE * 0.55, wood, p + Vector3(0.1, 1.175, 0.05))
						b.rotation.y = randf_range(0.3, 0.9)
				"^":
					var trap := SpikeTrap.new()
					add_child(trap)
					trap.position = p
				"m", "w", "a", "g", "K", "L", "x", "t", "s":
					spawns.append({"kind": ch, "pos": p})


func _anchor(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = randf() * TAU
	add_child(n)
	return n


func _add_obstacle(p: Vector3, r: float) -> void:
	obstacles.append({"pos": p, "r": r})


# ---------------------------------------------------------------- queries

## Moves a circle of radius `r` by `delta`, sliding along walls and around obstacles.
func resolve_move(pos: Vector3, delta: Vector3, r: float) -> Vector3:
	var p := pos + delta
	p.y = 0.0
	var min_z := -HALF_L + r
	if door_open and absf(p.x) < DOOR_HALF - r * 0.5:
		min_z = -HALF_L - 1.2
	p.x = clampf(p.x, -HALF_W + r, HALF_W - r)
	p.z = clampf(p.z, min_z, HALF_L - r)
	if p.z < -HALF_L + r:
		p.x = clampf(p.x, -DOOR_HALF + r, DOOR_HALF - r)
	for o in obstacles:
		var d: Vector3 = p - o.pos
		d.y = 0.0
		var m: float = o.r + r
		if d.length_squared() < m * m:
			var len := d.length()
			p = o.pos + (d / len * m if len > 0.0001 else Vector3.RIGHT * m)
			p.y = 0.0
	return p


## Bends a walking direction around any pillar or barrel straight ahead, so skeletons
## don't get stuck pushing into one.
func steer(pos: Vector3, dir: Vector3, r: float) -> Vector3:
	for o in obstacles:
		var to: Vector3 = o.pos - pos
		to.y = 0.0
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > o.r + r + 1.2:
			continue
		var side := to - dir * ahead
		if side.length() >= o.r + r:
			continue
		var tangent := dir.cross(Vector3.UP)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		elif side.length_squared() < 0.0001 and fmod(pos.x + pos.z, 2.0) < 1.0:
			tangent = -tangent
		# A pillar next to a wall: go round the open side instead of pushing into the wall.
		var probe: Vector3 = pos + tangent * (o.r + r + 0.4)
		if absf(probe.x) > HALF_W - r or absf(probe.z) > HALF_L - r:
			tangent = -tangent
		return (dir + tangent * 1.5).normalized()
	return dir


func blocks_shot(p: Vector3, r: float) -> bool:
	if absf(p.x) > HALF_W - r or absf(p.z) > HALF_L - r:
		return true
	for o in obstacles:
		var d: Vector3 = p - o.pos
		d.y = 0.0
		if d.length_squared() < (o.r + r) * (o.r + r):
			return true
	return false


## True when a bolt could fly from `a` to `b` without hitting a pillar or barrel.
func clear_shot(a: Vector3, b: Vector3) -> bool:
	var steps := int(a.distance_to(b) / 0.4) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		for o in obstacles:
			var d: Vector3 = p - o.pos
			d.y = 0.0
			var m: float = o.r + 0.15   # a bolt's own size, as in blocks_shot
			if d.length_squared() < m * m:
				return false
	return true


func is_at_exit(p: Vector3) -> bool:
	return door_open and p.z < -HALF_L + 0.2


func open_door() -> void:
	if door_open:
		return
	door_open = true
	Sfx.play("door")
	Game.shake(0.15)
	Fx.dust(Vector3(0, 0, -HALF_L), 30)
	_exit_glow.visible = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_portcullis, "position:y", 2.9, 0.9).set_trans(Tween.TRANS_SINE)
	_exit_light.visible = true
	tw.tween_property(_exit_light, "light_energy", 2.5, 0.9)
