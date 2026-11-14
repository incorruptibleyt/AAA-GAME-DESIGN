class_name Reliquary
extends SubViewportContainer
## The Bone Drop's chest (version 137, the chest redesign; it was DropScreen.Chest).
##
## A bone reliquary on a rune-cut stone plinth, bound shut by two iron chains with padlocks.
## Its front is a ribcage between femur corner posts; a horned skull is its lock: the skull's
## head is on the lid and its jaw on the body, so the mouth gapes when the lid opens.
## Closed, it hops now and then and its eyes breathe. Opening, it shakes harder, the chains
## strain and glow in the rarity's colour, cracks of light split the ribs and the runes
## brighten. Open, the chains snap (the links fly), the lid springs back, light pours up
## out of a pile of gold (and gems from Super Rare up) and coins fountain out.
##
## Built from merged meshes (one per material), so it stays about 30 draws on a phone.

var _vp: SubViewport
var _root: Node3D
var _lid: Node3D
## A Moon Casket (the Blood Moon event): black marble veined in gold, crimson, gold trim.
var moon := false

var _relic: ShaderMaterial      # the bone (or marble) of the body and lid
var _horn_mat: ShaderMaterial
var _velvet: StandardMaterial3D
var _trim: StandardMaterial3D
var _chain_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _seam: StandardMaterial3D
var _crack_mat: StandardMaterial3D
var _gem_mat: StandardMaterial3D
var _runes: ShaderMaterial
var _rays: ShaderMaterial
var _glow_mat: ShaderMaterial
var _gold: StandardMaterial3D

var _cracks: Array[MeshInstance3D] = []
var _links: MultiMeshInstance3D
var _link_rest: Array[Transform3D] = []
var _link_vel: Array[Vector3] = []
var _link_spin: Array[Vector3] = []
var _locks: Array[Node3D] = []
var _lock_rest: Array[Transform3D] = []
var _pile: Node3D
var _pile_gems: MultiMeshInstance3D
var _beam: MeshInstance3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _burst: CPUParticles3D
var _burst_mat: StandardMaterial3D
var _coins: CPUParticles3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D

var _open := 0.0
var _opened := false
var _snap := 0.0
var _lift := 0.0
var _lift_to := 0.0
var _tier := 0

const BODY := Vector3(1.16, 0.56, 0.74)   # the box: width, height, depth
const BASE_Y := 0.07                       # the box's bottom sits on its bone feet
const TOP_Y := BASE_Y + 0.56               # where the lid closes
const LID_R := 0.37                        # the lid is half a barrel this deep...
const LID_SQUASH := 0.62                   # ...and this much as tall
const LID_OPEN := -1.45                    # how far the lid swings back (radians)
const CHAIN_X := 0.36


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X if Game.msaa_ok() else Viewport.MSAA_DISABLED   # see Game.msaa_ok
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.42, 2.95)
	cam.fov = 46.0
	_vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.8, 0))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.42, 0.38, 0.55)
	env.environment.ambient_light_energy = 0.55
	_vp.add_child(env)
	# Warm torchlight from the upper left, a cool rim from behind, a soft fill from below right.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.75, 0.6, 0)
	key.light_color = Color(1.0, 0.86, 0.68)
	key.light_energy = 1.05
	_vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.7, 1.5, -1.3)
	rim.omni_range = 4.0
	rim.light_color = Color(0.55, 0.5, 1.0)
	rim.light_energy = 1.8
	_vp.add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.4, 0.3, 1.6)
	fill.omni_range = 4.0
	fill.light_color = Color(0.9, 0.55, 0.4)
	fill.light_energy = 0.45
	_vp.add_child(fill)
	_materials()
	_build()


# ---------------------------------------------------------------- materials

const RELIC_CODE := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base : source_color = vec3(0.86, 0.79, 0.66);
uniform vec3 deep : source_color = vec3(0.40, 0.31, 0.24);
uniform vec3 vein : source_color = vec3(1.0, 0.75, 0.3);
uniform float marble = 0.0;
uniform float grain = 1.0;
varying vec3 lp;
varying vec3 wp;
float h3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
			mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	lp = VERTEX;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float n = n3(lp * 7.0) * 0.6 + n3(lp * 19.0) * 0.4;
	float streak = n3(lp * 45.0);
	vec3 c = mix(deep, base, smoothstep(0.15, 0.75, n * 0.8 + 0.25));
	c *= 1.0 + (streak - 0.5) * 0.08 * grain;
	// Older and darker toward the floor, as if the crypt's damp has crept up it.
	c *= mix(0.55, 1.0, smoothstep(0.0, 0.45, wp.y));
	float v = 0.0;
	if (marble > 0.5) {
		float w = abs(sin(lp.x * 9.0 + lp.y * 5.0 + n * 7.0));
		v = smoothstep(0.06, 0.0, w);
		c = mix(c, vein, v);
	}
	ALBEDO = c;
	ROUGHNESS = mix(0.62, 0.18, marble) - v * 0.1;
	METALLIC = v * 0.8;
	SPECULAR = mix(0.35, 0.7, marble);
	RIM = 0.35;
	RIM_TINT = 0.6;
	EMISSION = vein * v * 0.35;
}
"""

const RUNE_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float glow = 0.3;
uniform float spin = 0.0;
float h1(float x) { return fract(sin(x * 91.17) * 4373.13); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) + spin;
	float lines = smoothstep(0.012, 0.0, abs(r - 0.70)) + smoothstep(0.012, 0.0, abs(r - 0.93));
	// A band of runes between the two circles: each cell a stroke and one of four marks.
	float cells = 28.0;
	float ca = a / 6.2831853 * cells;
	float id = floor(ca);
	float u = fract(ca) - 0.5;
	float v = (r - 0.815) / 0.09;
	float hv = h1(id);
	float rune = 0.0;
	if (abs(v) < 1.0) {
		rune += smoothstep(0.07, 0.0, abs(u + 0.12 * (hv - 0.5)));
		if (hv > 0.25) rune += smoothstep(0.08, 0.0, abs(v - (hv - 0.6) * 1.2)) * step(abs(u), 0.28);
		if (hv > 0.55) rune += smoothstep(0.07, 0.0, abs(u - v * 0.3 - 0.15)) * step(abs(v), 0.7);
		if (hv > 0.8) rune += smoothstep(0.1, 0.06, abs(length(vec2(u, v * 0.35)) - 0.18));
	}
	float halo = smoothstep(1.0, 0.65, r) * smoothstep(0.55, 0.8, r) * 0.25;
	ALBEDO = col.rgb;
	ALPHA = clamp(lines * 0.9 + clamp(rune, 0.0, 1.0) + halo, 0.0, 1.0) * glow;
}
"""

const RAYS_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float power = 0.0;
void fragment() {
	float a = UV.x * 6.2831853;
	float rays = pow(sin(a * 5.0 + TIME * 0.7) * 0.5 + 0.5, 4.0) * 0.8
			+ pow(sin(a * 9.0 - TIME * 1.1 + 1.3) * 0.5 + 0.5, 6.0) * 0.6 + 0.12;
	float up = 1.0 - UV.y;
	float fade = pow(1.0 - up, 1.6) * smoothstep(0.0, 0.08, 1.0 - UV.y);
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = col.rgb * (1.0 + 0.6 * smoothstep(0.6, 1.0, UV.y));
	ALPHA = clamp(rays * fade * edge * power, 0.0, 1.0);
}
"""

const GLOW_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float power = 0.0;
uniform float dark = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float g = pow(clamp(1.0 - r, 0.0, 1.0), 1.8);
	ALBEDO = mix(col.rgb, vec3(1.0), g * 0.25);
	ALPHA = g * g * power;
}
"""

const SHADOW_CODE := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	ALBEDO = vec3(0.0);
	ALPHA = smoothstep(1.0, 0.35, length(p)) * 0.7;
}
"""

const STONE_CODE := """
shader_type spatial;
varying vec3 lp;
float h3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
			mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { lp = VERTEX; }
void fragment() {
	float n = n3(lp * 6.0) * 0.6 + n3(lp * 17.0) * 0.4;
	vec3 c = mix(vec3(0.09, 0.08, 0.11), vec3(0.27, 0.25, 0.3), n);
	// The top's worn edge catches the light.
	c += vec3(0.12, 0.1, 0.12) * smoothstep(0.85, 1.0, NORMAL.y) * smoothstep(0.86, 1.0, length(lp.xz));
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
"""


func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _unlit(c := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _materials() -> void:
	_relic = _shader(RELIC_CODE)
	_horn_mat = _shader(RELIC_CODE)
	_horn_mat.set_shader_parameter("base", Color(0.32, 0.27, 0.25))
	_horn_mat.set_shader_parameter("deep", Color(0.08, 0.06, 0.07))
	_horn_mat.set_shader_parameter("grain", 2.5)
	_velvet = StandardMaterial3D.new()
	_velvet.albedo_color = Color(0.2, 0.03, 0.06)
	_velvet.roughness = 1.0
	_velvet.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trim = StandardMaterial3D.new()
	_trim.albedo_color = Color(0.3, 0.27, 0.3)
	_trim.metallic = 0.85
	_trim.roughness = 0.28
	_trim.rim_enabled = true
	_trim.rim = 0.3
	_chain_mat = StandardMaterial3D.new()
	_chain_mat.albedo_color = Color(0.2, 0.18, 0.22)
	_chain_mat.metallic = 0.9
	_chain_mat.roughness = 0.32
	_chain_mat.emission_enabled = true
	_chain_mat.emission = Color.BLACK
	_eye_mat = _unlit(Color(0.6, 0.5, 1.0))
	_seam = _unlit()
	_crack_mat = _unlit()
	_gem_mat = StandardMaterial3D.new()
	_gem_mat.albedo_color = Color.WHITE
	_gem_mat.metallic = 0.3
	_gem_mat.roughness = 0.08
	_gem_mat.emission_enabled = true
	_gem_mat.rim_enabled = true
	_gem_mat.rim = 1.0
	_gem_mat.rim_tint = 0.0
	_runes = _shader(RUNE_CODE)
	_rays = _shader(RAYS_CODE)
	_glow_mat = _shader(GLOW_CODE)
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.74, 0.24)
	_gold.metallic = 0.9
	_gold.roughness = 0.28
	_gold.emission_enabled = true
	_gold.emission = Color(0.55, 0.32, 0.05)
	_gold.rim_enabled = true
	_gold.rim = 0.5


# ---------------------------------------------------------------- meshes

## Adds a tube along `pts` (a bone, a rib or a horn) to `st`, `rad` wide at each point.
static func _tube(st: SurfaceTool, pts: PackedVector3Array, rad: PackedFloat32Array, sides := 8) -> void:
	var n := pts.size()
	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var prev_side := Vector3.ZERO
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side: Vector3
		if i == 0:
			var up := Vector3.UP if absf(t.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			side = up.cross(t).normalized()
		else:
			side = (prev_side - t * prev_side.dot(t)).normalized()   # carried along, so it never twists
		prev_side = side
		var up2 := t.cross(side)
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for s in sides:
			var a := TAU * s / sides
			var d := side * cos(a) + up2 * sin(a)
			ring.append(pts[i] + d * rad[i])
			nr.append(d)
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			for k in [[i, s], [i + 1, s], [i + 1, s2], [i, s], [i + 1, s2], [i, s2]]:
				st.set_normal(norms[k[0]][k[1]])
				st.add_vertex(rings[k[0]][k[1]])
	# Round knobs on both ends.
	_ball(st, pts[0], rad[0] * 1.05)
	_ball(st, pts[n - 1], rad[n - 1] * 1.05)


## Adds a low-poly ball to `st` (stretched by `sc`).
static func _ball(st: SurfaceTool, c: Vector3, r: float, sc := Vector3.ONE, seg := 8) -> void:
	var rows := seg / 2 + 1
	for y in rows - 1:
		for x in seg:
			var q := [[y, x], [y + 1, x], [y + 1, x + 1], [y, x], [y + 1, x + 1], [y, x + 1]]
			for k in q:
				var th := PI * float(k[0]) / float(rows - 1)
				var ph := TAU * float(k[1]) / float(seg)
				var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				st.set_normal((d / sc).normalized())
				st.add_vertex(c + d * r * sc)


## Adds a ready-made shape (a box, a coin...) to `st` as plain points and normals, like the
## hand-made tubes and balls (mixed into one SurfaceTool, append_from dropped them).
static func _add(st: SurfaceTool, m: PrimitiveMesh, xf: Transform3D) -> void:
	var arr := m.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var nb := xf.basis.inverse().transposed()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_normal((nb * nr[i]).normalized())
		st.add_vertex(xf * v[i])


static func _boxm(size_v: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size_v
	return b


static func _at(pos: Vector3, rot := Vector3.ZERO, sc := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(sc), pos)


func _put(parent: Node, st: SurfaceTool, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _mesh(parent: Node, m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _build() -> void:
	_root = Node3D.new()
	_vp.add_child(_root)
	_plinth()
	_body()
	_lid_build()
	_chains()
	_treasure()
	_effects()


## The rune-cut stone plinth under it, and its shadow.
func _plinth() -> void:
	var stone := CylinderMesh.new()
	stone.top_radius = 0.9
	stone.bottom_radius = 0.98
	stone.height = 0.22
	stone.radial_segments = 8
	stone.rings = 1
	var p := _mesh(_vp, stone, _shader(STONE_CODE), Vector3(0, -0.11, 0))
	p.rotation.y = PI / 8.0
	var runes := PlaneMesh.new()
	runes.size = Vector2(1.84, 1.84)
	_mesh(_vp, runes, _runes, Vector3(0, 0.004, 0))
	var sh := PlaneMesh.new()
	sh.size = Vector2(1.7, 1.25)
	_mesh(_root, sh, _shader(SHADOW_CODE), Vector3(0, 0.008, 0))


## The box: bone walls, velvet inside, femur posts at the corners with knobbed ends, a
## ribcage on the front, crossed bones on the sides, trim bands with studs, and the jaw.
func _body() -> void:
	var w := BODY.x
	var h := BODY.y
	var d := BODY.z
	var cy := BASE_Y + h * 0.5
	var t := 0.06
	var bone := _new_st()
	_add(bone, _boxm(Vector3(w, t, d)), _at(Vector3(0, BASE_Y + t * 0.5, 0)))
	_add(bone, _boxm(Vector3(w, h, t)), _at(Vector3(0, cy, d * 0.5 - t * 0.5)))
	_add(bone, _boxm(Vector3(w, h, t)), _at(Vector3(0, cy, -d * 0.5 + t * 0.5)))
	_add(bone, _boxm(Vector3(t, h, d)), _at(Vector3(w * 0.5 - t * 0.5, cy, 0)))
	_add(bone, _boxm(Vector3(t, h, d)), _at(Vector3(-w * 0.5 + t * 0.5, cy, 0)))
	# Femur posts: a shaft with a double knuckle at each end; the bottom knuckles are its feet.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var px: float = x * (w * 0.5 + 0.01)
			var pz: float = z * (d * 0.5 + 0.01)
			_tube(bone, PackedVector3Array([Vector3(px, BASE_Y - 0.02, pz), Vector3(px, cy, pz), Vector3(px, TOP_Y + 0.02, pz)]),
					PackedFloat32Array([0.05, 0.04, 0.05]), 10)
			for yy in [BASE_Y - 0.03, TOP_Y + 0.03]:
				for s in [-1.0, 1.0]:
					_ball(bone, Vector3(px + s * 0.03 * x, yy, pz - s * 0.03 * z), 0.05)
	# The ribcage: a breastbone and three pairs of ribs curving out and down from it.
	var fz := d * 0.5 + 0.02
	_tube(bone, PackedVector3Array([Vector3(0, BASE_Y + 0.08, fz), Vector3(0, BASE_Y + 0.3, fz + 0.015), Vector3(0, TOP_Y - 0.12, fz)]),
			PackedFloat32Array([0.03, 0.036, 0.032]), 8)
	for i in 3:
		var y0 := TOP_Y - 0.17 - i * 0.12
		for s in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			for k in 7:
				var f := k / 6.0
				pts.append(Vector3(s * (0.04 + f * (0.38 - i * 0.03)), y0 + 0.03 - f * f * 0.1 - sin(f * PI) * -0.025, fz + sin(f * PI) * 0.03))
				rad.append(lerpf(0.026, 0.017, f))
			_tube(bone, pts, rad, 7)
	# Crossed bones on each side.
	for x in [-1.0, 1.0]:
		var sx: float = x * (w * 0.5 + 0.02)
		for s in [-1.0, 1.0]:
			_tube(bone, PackedVector3Array([Vector3(sx, cy - 0.17, s * 0.24), Vector3(sx, cy + 0.17, -s * 0.24)]),
					PackedFloat32Array([0.026, 0.026]), 7)
			for e in [-1.0, 1.0]:
				for o in [-1.0, 1.0]:
					_ball(bone, Vector3(sx, cy + e * 0.17 + o * 0.025, -e * s * 0.24 + o * 0.02 * s), 0.032)
	# The skull's jaw, hanging under the lid's skull, with a row of teeth along its top.
	var jaw_z := d * 0.5 + 0.06
	_ball(bone, Vector3(0, TOP_Y - 0.06, jaw_z - 0.02), 0.1, Vector3(1.15, 0.55, 0.7))
	for i in 6:
		_add(bone, _boxm(Vector3(0.026, 0.04, 0.025)), _at(Vector3(-0.07 + i * 0.028, TOP_Y - 0.02, jaw_z + 0.035)))
	_put(_root, bone, _relic)
	# Velvet inside (seen once it opens).
	var vel := _new_st()
	var iw := w - t * 2.0 - 0.004
	var idp := d - t * 2.0 - 0.004
	_add(vel, PlaneMesh.new(), _at(Vector3(0, BASE_Y + t + 0.002, 0), Vector3.ZERO, Vector3(iw * 0.5, 1, idp * 0.5)))
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_add(vel, q, _at(Vector3(0, cy, -idp * 0.5), Vector3.ZERO, Vector3(iw, h, 1)))
	_add(vel, q, _at(Vector3(0, cy, idp * 0.5), Vector3(0, PI, 0), Vector3(iw, h, 1)))
	_add(vel, q, _at(Vector3(-iw * 0.5, cy, 0), Vector3(0, PI / 2, 0), Vector3(idp, h, 1)))
	_add(vel, q, _at(Vector3(iw * 0.5, cy, 0), Vector3(0, -PI / 2, 0), Vector3(idp, h, 1)))
	_put(_root, vel, _velvet)
	# Iron (gold, as the rarity climbs) bands round the bottom and the rim, studded.
	var tr := _new_st()
	_add(tr, _boxm(Vector3(w + 0.03, 0.06, d + 0.03)), _at(Vector3(0, BASE_Y + 0.05, 0)))
	_add(tr, _boxm(Vector3(w + 0.03, 0.05, d + 0.03)), _at(Vector3(0, TOP_Y - 0.03, 0)))
	for y in [BASE_Y + 0.05, TOP_Y - 0.03]:
		for i in 7:
			var sx := -w * 0.42 + i * w * 0.14
			if absf(sx) < 0.1 and y > cy:
				continue   # the jaw sits there
			_ball(tr, Vector3(sx, y, d * 0.5 + 0.02), 0.022, Vector3(1, 1, 0.6), 6)
	_put(_root, tr, _trim)
	# The glowing seam under the lid, and cracks of light across the ribs (one per step up).
	# (a frame round the rim, not a slab, so the open chest shows its gold, not a white lid)
	var sm := _new_st()
	for zz in [-1.0, 1.0]:
		_add(sm, _boxm(Vector3(w - 0.02, 0.03, 0.035)), _at(Vector3(0, TOP_Y + 0.004, zz * (d * 0.5 - 0.03))))
	for xx in [-1.0, 1.0]:
		_add(sm, _boxm(Vector3(0.035, 0.03, d - 0.02)), _at(Vector3(xx * (w * 0.5 - 0.03), TOP_Y + 0.004, 0)))
	_put(_root, sm, _seam)
	var crack_at := [Vector3(-0.22, BASE_Y + 0.2, fz + 0.035), Vector3(0.26, BASE_Y + 0.33, fz + 0.035),
			Vector3(-0.3, BASE_Y + 0.38, fz + 0.035), Vector3(0.2, BASE_Y + 0.14, fz + 0.035)]
	for i in crack_at.size():
		var c := _new_st()
		var p0: Vector3 = crack_at[i]
		var zig := PackedVector3Array([p0 + Vector3(-0.05, -0.08, 0), p0 + Vector3(0.01, -0.02, 0), p0 + Vector3(-0.02, 0.03, 0), p0 + Vector3(0.05, 0.09, 0)])
		for k in 3:
			var a := zig[k]
			var b := zig[k + 1]
			var mid := (a + b) * 0.5
			var dirv := b - a
			_add(c, _boxm(Vector3(0.012, dirv.length() + 0.01, 0.01)), _at(mid, Vector3(0, 0, -atan2(dirv.x, dirv.y))))
		var mi := _put(_root, c, _crack_mat)
		mi.visible = false
		_cracks.append(mi)


## Half a barrel of bone, hinged at the back: three bone hoops over it, metal edges, velvet
## inside, a gem in a claw mount on top, and the horned skull on the front.
func _lid_build() -> void:
	_lid = Node3D.new()
	_lid.position = Vector3(0, TOP_Y, -LID_R)
	_root.add_child(_lid)
	var w := BODY.x + 0.02
	var seg := 18
	var outer := _new_st()
	var inner := _new_st()
	for i in seg:
		var a0 := PI * i / seg
		var a1 := PI * (i + 1) / seg
		var p0 := Vector3(0, sin(a0) * LID_R * LID_SQUASH, LID_R + cos(a0) * LID_R)
		var p1 := Vector3(0, sin(a1) * LID_R * LID_SQUASH, LID_R + cos(a1) * LID_R)
		var n0 := Vector3(0, sin(a0) / LID_SQUASH, cos(a0)).normalized()
		var n1 := Vector3(0, sin(a1) / LID_SQUASH, cos(a1)).normalized()
		var hx := w * 0.5
		for k in [[-hx, p0, n0], [hx, p1, n1], [hx, p0, n0], [-hx, p0, n0], [-hx, p1, n1], [hx, p1, n1]]:
			outer.set_normal(k[2])
			outer.add_vertex(Vector3(k[0], k[1].y, k[1].z))
		for k in [[-hx, p0, n0], [hx, p0, n0], [hx, p1, n1], [-hx, p0, n0], [hx, p1, n1], [-hx, p1, n1]]:
			inner.set_normal(-k[2])
			inner.add_vertex(Vector3(k[0], k[1].y * 0.92, LID_R + (k[1].z - LID_R) * 0.94))
		# The end caps (half discs).
		for sx in [-hx, hx]:
			var nn := Vector3(signf(sx), 0, 0)
			var tri := [Vector3(sx, 0, LID_R), Vector3(sx, p0.y, p0.z), Vector3(sx, p1.y, p1.z)]
			if sx < 0.0:
				tri.reverse()   # clockwise from outside, so it's lit as a front face
			for v in tri:
				outer.set_normal(nn)
				outer.add_vertex(v)
	# Three bone hoops over the barrel (ribs again), with knobs where they meet the rim.
	for x in [-0.42, 0.0, 0.42]:
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for k in 13:
			var a := PI * k / 12.0
			pts.append(Vector3(x, sin(a) * (LID_R * LID_SQUASH + 0.025), LID_R + cos(a) * (LID_R + 0.025)))
			rad.append(0.032 if x != 0.0 else 0.026)
		_tube(outer, pts, rad, 7)
	_put(_lid, outer, _relic)
	_put(_lid, inner, _velvet)
	# Metal edges along the lid's front and back rims, and its gem mount.
	var tr := _new_st()
	_add(tr, _boxm(Vector3(w + 0.03, 0.04, 0.045)), _at(Vector3(0, 0.02, LID_R * 2.0 + 0.005)))
	_add(tr, _boxm(Vector3(w + 0.03, 0.04, 0.045)), _at(Vector3(0, 0.02, -0.005)))
	var top := LID_R * LID_SQUASH
	_add(tr, _cyl(0.07, 0.09, 0.05, 8), _at(Vector3(0, top + 0.03, LID_R)))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_tube(tr, PackedVector3Array([Vector3(cos(a) * 0.07, top + 0.04, LID_R + sin(a) * 0.07),
				Vector3(cos(a) * 0.075, top + 0.11, LID_R + sin(a) * 0.075), Vector3(cos(a) * 0.045, top + 0.16, LID_R + sin(a) * 0.045)]),
				PackedFloat32Array([0.014, 0.012, 0.008]), 5)
	_put(_lid, tr, _trim)
	var gem := SphereMesh.new()
	gem.radius = 0.075
	gem.height = 0.15
	gem.radial_segments = 6
	gem.rings = 2
	_mesh(_lid, gem, _gem_mat, Vector3(0, top + 0.12, LID_R)).scale = Vector3(1.0, 1.45, 1.0)
	# The skull: a cranium with brow and cheekbones, deep sockets and glowing eyes, upper
	# teeth, and two curling horns. Its jaw is on the body, so it gapes when the lid opens.
	var sz := LID_R * 2.0 + 0.07
	var sk := _new_st()
	_ball(sk, Vector3(0, 0.07, sz - 0.03), 0.16, Vector3(1.0, 0.9, 0.72), 12)
	_ball(sk, Vector3(0, 0.1, sz + 0.06), 0.1, Vector3(1.25, 0.32, 0.4), 8)        # brow
	for x in [-1.0, 1.0]:
		_ball(sk, Vector3(x * 0.085, 0.0, sz + 0.05), 0.05, Vector3(1.0, 0.75, 0.7))  # cheek
	for i in 6:
		_add(sk, _boxm(Vector3(0.026, 0.045, 0.025)), _at(Vector3(-0.07 + i * 0.028, -0.045, sz + 0.065)))
	_put(_lid, sk, _relic)
	var dark := _new_st()
	for x in [-1.0, 1.0]:
		_ball(dark, Vector3(x * 0.058, 0.055, sz + 0.065), 0.045, Vector3(1.0, 0.85, 0.5))
	_ball(dark, Vector3(0, -0.008, sz + 0.085), 0.02, Vector3(1.0, 1.3, 0.5))      # nose
	_put(_lid, dark, _unlit(Color(0.03, 0.01, 0.03)))
	var eyes := _new_st()
	for x in [-1.0, 1.0]:
		_ball(eyes, Vector3(x * 0.058, 0.055, sz + 0.085), 0.02)
	_put(_lid, eyes, _eye_mat)
	var horns := _new_st()
	for x in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for k in 9:
			var f := k / 8.0
			pts.append(Vector3(x * (0.11 + 0.2 * sin(f * 1.9)), 0.1 + 0.27 * f - 0.05 * sin(f * PI), sz - 0.04 + 0.08 * f * f - 0.06 * sin(f * PI)))
			rad.append(lerpf(0.045, 0.006, f))
		_tube(horns, pts, rad, 8)
	_put(_lid, horns, _horn_mat)


static func _cyl(top: float, bottom: float, h: float, sides: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


## Two chains over the lid and down the front, each to a padlock: links of one MultiMesh.
func _chains() -> void:
	var path_for := func(x: float) -> PackedVector3Array:
		var p := PackedVector3Array()
		var bz := -BODY.z * 0.5 - 0.035
		p.append(Vector3(x, BASE_Y + 0.12, bz))
		p.append(Vector3(x, TOP_Y, bz))
		for k in 15:
			var a := PI * (1.0 - k / 14.0)
			p.append(Vector3(x, TOP_Y + sin(a) * (LID_R * LID_SQUASH + 0.05), cos(a) * (LID_R + 0.05)))
		p.append(Vector3(x, TOP_Y - 0.12, BODY.z * 0.5 + 0.06))
		return p
	var xfs: Array[Transform3D] = []
	for x in [-CHAIN_X, CHAIN_X]:
		var path: PackedVector3Array = path_for.call(x)
		# Walk the path a link at a time.
		var step := 0.062
		var seg_i := 0
		var seg_pos := 0.0
		var n := 0
		while seg_i < path.size() - 1:
			var a := path[seg_i]
			var b := path[seg_i + 1]
			var l := a.distance_to(b)
			if seg_pos > l:
				seg_pos -= l
				seg_i += 1
				continue
			var p := a.lerp(b, seg_pos / l)
			var t := (b - a).normalized()
			var side := Vector3.RIGHT
			var up := t.cross(side).normalized()
			side = up.cross(t).normalized()
			# TorusMesh lies flat in XZ: long along Z (stretched), its hole facing Y, which
			# turns a quarter each link so they hook through each other.
			var basis := Basis(side, up, t) if n % 2 == 0 else Basis(up, -side, t)
			xfs.append(Transform3D(basis * Basis.from_scale(Vector3(1.0, 1.0, 1.55)), p))
			seg_pos += step
			n += 1
		# The padlock where the chain ends on the front.
		var lock := Node3D.new()
		lock.position = path[path.size() - 1] + Vector3(0, -0.09, 0.02)
		_root.add_child(lock)
		var st := _new_st()
		_add(st, _boxm(Vector3(0.12, 0.1, 0.045)), _at(Vector3.ZERO))
		var sh := TorusMesh.new()
		sh.inner_radius = 0.03
		sh.outer_radius = 0.045
		sh.rings = 12
		sh.ring_segments = 5
		_add(st, sh, _at(Vector3(0, 0.055, 0), Vector3(PI / 2, 0, 0)))
		_put(lock, st, _trim)
		_mesh(lock, _boxm(Vector3(0.018, 0.035, 0.01)), _unlit(Color(0.03, 0.01, 0.03)), Vector3(0, -0.01, 0.024))
		_locks.append(lock)
		_lock_rest.append(lock.transform)
	var link := TorusMesh.new()
	link.inner_radius = 0.017
	link.outer_radius = 0.03
	link.rings = 10
	link.ring_segments = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = link
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	_link_rest = xfs
	_links = MultiMeshInstance3D.new()
	_links.multimesh = mm
	_links.material_override = _chain_mat
	_links.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(_links)


## The gold inside (and gems from Super Rare up), with the light pouring out of it.
func _treasure() -> void:
	_pile = Node3D.new()
	_pile.visible = false
	_root.add_child(_pile)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var coin := _cyl(0.065, 0.065, 0.016, 12)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = coin
	mm.instance_count = 110
	for i in 110:
		var x := rng.randf_range(-0.5, 0.5)
		var z := rng.randf_range(-0.27, 0.27)
		var hump := clampf(1.0 - pow(x / 0.5, 2) - pow(z / 0.3, 2), 0.0, 1.0)
		var y := TOP_Y - 0.06 + 0.2 * hump + rng.randf_range(-0.02, 0.02)
		mm.set_instance_transform(i, _at(Vector3(x, y, z), Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _gold
	_pile.add_child(mi)
	var gem := SphereMesh.new()
	gem.radius = 0.06
	gem.height = 0.12
	gem.radial_segments = 6
	gem.rings = 2
	var gm := MultiMesh.new()
	gm.transform_format = MultiMesh.TRANSFORM_3D
	gm.mesh = gem
	gm.instance_count = 4
	for i in 4:
		var p: Vector3 = [Vector3(-0.2, TOP_Y + 0.06, 0.05), Vector3(0.22, TOP_Y + 0.05, -0.04), Vector3(0.02, TOP_Y + 0.1, -0.08), Vector3(-0.32, TOP_Y + 0.0, -0.1)][i]
		gm.set_instance_transform(i, _at(p, Vector3(rng.randf(), rng.randf() * TAU, rng.randf()), Vector3(1, 1.4, 1)))
	_pile_gems = MultiMeshInstance3D.new()
	_pile_gems.multimesh = gm
	_pile_gems.material_override = _gem_mat
	_pile.add_child(_pile_gems)
	# A glow lying over the gold, and the light it throws.
	var g := PlaneMesh.new()
	g.size = Vector2(1.5, 1.1)
	_glow = _mesh(_root, g, _glow_mat, Vector3(0, TOP_Y + 0.05, 0))
	_glow.visible = false
	_light = OmniLight3D.new()
	_light.position = Vector3(0, TOP_Y + 0.35, 0.25)
	_light.omni_range = 3.2
	_light.light_energy = 0.0
	_root.add_child(_light)


func _effects() -> void:
	# Rays of light rising out of it once it opens.
	var bm := CylinderMesh.new()
	bm.top_radius = 1.2
	bm.bottom_radius = 0.5
	bm.height = 2.6
	bm.cap_top = false
	bm.cap_bottom = false
	bm.radial_segments = 32
	bm.rings = 1
	_beam = _mesh(_root, bm, _rays, Vector3(0, TOP_Y + 1.3, 0))
	_beam.visible = false
	# Sparks of the rarity's colour.
	_burst = CPUParticles3D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 0.95
	_burst.amount = 60
	_burst.lifetime = 1.2
	_burst.position = Vector3(0, TOP_Y + 0.1, 0)
	_burst.direction = Vector3.UP
	_burst.spread = 70.0
	_burst.initial_velocity_min = 2.5
	_burst.initial_velocity_max = 5.0
	_burst.gravity = Vector3(0, -6.0, 0)
	_burst.scale_amount_min = 0.4
	_burst.scale_amount_max = 1.1
	var spark := SphereMesh.new()
	spark.radius = 0.03
	spark.height = 0.06
	spark.radial_segments = 6
	spark.rings = 3
	_burst_mat = _unlit()
	spark.material = _burst_mat
	_burst.mesh = spark
	_root.add_child(_burst)
	# Gold coins thrown up and out, tumbling.
	_coins = CPUParticles3D.new()
	_coins.emitting = false
	_coins.one_shot = true
	_coins.explosiveness = 0.85
	_coins.amount = 22
	_coins.lifetime = 1.5
	_coins.position = Vector3(0, TOP_Y + 0.12, 0.05)
	_coins.direction = Vector3(0, 1, 0.25)
	_coins.spread = 38.0
	_coins.initial_velocity_min = 2.6
	_coins.initial_velocity_max = 4.2
	_coins.gravity = Vector3(0, -8.5, 0)
	_coins.angle_min = 0.0
	_coins.angle_max = 360.0
	_coins.angular_velocity_min = -540.0
	_coins.angular_velocity_max = 540.0
	_coins.particle_flag_rotate_y = true
	var cm := _cyl(0.055, 0.055, 0.014, 10)
	cm.material = _gold
	_coins.mesh = cm
	_root.add_child(_coins)
	# A ring of light racing out over the plinth.
	_ring_mat = _unlit()
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	_ring = _mesh(_root, ring, _ring_mat, Vector3(0, 0.05, 0))
	_ring.scale = Vector3(1, 0.2, 1)
	_ring.visible = false


# ---------------------------------------------------------------- the solid check

## Like the hero preview (version 121): a moment after it first shows, look at the
## picture. If nothing in it is solid (this phone draws see-through pictures wrong), draw
## the chest on the screen's own dark colour from then on, and say so in the reports.
static var _seen_ok := false
static var _solid := false
var _checking := false

func check() -> void:
	if _seen_ok or _checking or DisplayServer.get_name() == "headless":
		return
	_checking = true
	for i in 20:
		await RenderingServer.frame_post_draw
	_checking = false
	if not is_inside_tree() or not is_visible_in_tree():
		return
	var img := _vp.get_texture().get_image()
	var solid_px := 0
	var lit_px := 0
	if img and not img.is_empty():
		var w := img.get_width()
		var h := img.get_height()
		for y in range(h / 4, h, 8):
			for x in range(w / 4, w * 3 / 4, 8):
				var c := img.get_pixel(x, y)
				if c.a > 0.3:
					solid_px += 1
				elif c.r + c.g + c.b > 0.12:
					lit_px += 1
	if solid_px > 6:
		_seen_ok = true
		return
	if not _solid:
		_solid = true
		_use_solid()
	push_error("Bone Drop chest showed %s (%s); switched to a solid backdrop" % ["clear" if lit_px > 6 else "empty", _vp.size])


func _use_solid() -> void:
	_vp.transparent_bg = false
	for n in _vp.get_children():
		if n is WorldEnvironment:
			n.environment.background_mode = Environment.BG_COLOR
			n.environment.background_color = Color(0.02, 0.01, 0.04)


# ---------------------------------------------------------------- the moment

func casket_look(on: bool) -> void:
	moon = on
	_relic.set_shader_parameter("base", Color(0.16, 0.13, 0.19) if on else Color(0.86, 0.79, 0.66))
	_relic.set_shader_parameter("deep", Color(0.04, 0.03, 0.06) if on else Color(0.4, 0.31, 0.24))
	_relic.set_shader_parameter("marble", 1.0 if on else 0.0)
	_horn_mat.set_shader_parameter("base", Color(0.55, 0.06, 0.08) if on else Color(0.32, 0.27, 0.25))
	_horn_mat.set_shader_parameter("deep", Color(0.18, 0.01, 0.03) if on else Color(0.08, 0.06, 0.07))
	_velvet.albedo_color = Color(0.3, 0.02, 0.05) if on else Color(0.2, 0.03, 0.06)
	_chain_mat.albedo_color = Color(0.85, 0.6, 0.2) if on else Color(0.2, 0.18, 0.22)


func reset() -> void:
	if _solid and _vp.transparent_bg:
		_use_solid()
	_lift = 0.0
	_lift_to = 0.0
	_opened = false
	_open = 0.0
	_snap = 0.0
	_tier = 0
	_lid.rotation = Vector3.ZERO
	_lid.position = Vector3(0, TOP_Y, -LID_R)
	_beam.visible = false
	_glow.visible = false
	_pile.visible = false
	_light.light_energy = 0.0
	for c in _cracks:
		c.visible = false
	_ring.visible = false
	_links.visible = true
	for i in _link_rest.size():
		_links.multimesh.set_instance_transform(i, _link_rest[i])
	for i in _locks.size():
		_locks[i].transform = _lock_rest[i]
		_locks[i].visible = true
	_root.rotation = Vector3(0, -0.38, 0)
	_root.position = Vector3.ZERO
	_root.scale = Vector3.ONE


func open_up(col: Color, tier := 0, silent := false) -> void:
	_opened = true
	_open = 0.0
	_snap = 0.0
	_tier = tier
	_lift_to = 0.1 if tier >= 3 else 0.0
	_beam.visible = true
	_glow.visible = true
	_pile.visible = true
	_pile_gems.visible = tier >= 2
	_rays.set_shader_parameter("col", col.lightened(0.25))
	_glow_mat.set_shader_parameter("col", col.lightened(0.3))
	# The chains snap: every link flies off, spinning, and the padlocks drop away.
	var rng := RandomNumberGenerator.new()
	_link_vel.clear()
	_link_spin.clear()
	for xf in _link_rest:
		var out := Vector3(xf.origin.x, 0, xf.origin.z).normalized()
		_link_vel.append(out * rng.randf_range(1.2, 2.6) + Vector3(0, rng.randf_range(1.0, 3.0), 0))
		_link_spin.append(Vector3(rng.randf_range(-12, 12), rng.randf_range(-12, 12), rng.randf_range(-12, 12)))
	if not silent:
		Sfx.play("chest_snap" if Sfx.has("chest_snap") else "crack", 0.9)   # the chains snapping
	for wave in ([0.35, 0.7] if tier >= 4 else ([0.35] if tier >= 3 else [])):
		get_tree().create_timer(wave).timeout.connect(func():
			if _opened and is_inside_tree():
				_burst.restart()
				_burst.emitting = true
				_coins.restart()
				_coins.emitting = true
				_ring.visible = true
				_ring.scale = Vector3(0.3, 0.2, 0.3))
	_light.light_color = col.lightened(0.2)
	_light.light_energy = 3.0
	_burst_mat.albedo_color = col.lightened(0.35) * 1.6
	_burst.restart()
	_burst.emitting = true
	_coins.amount = 16 + 6 * tier
	_coins.restart()
	_coins.emitting = true
	_ring.visible = true
	_ring.scale = Vector3(0.3, 0.2, 0.3)
	_ring_mat.albedo_color = Color(col, 0.8)


func animate(step: int, k: float, col: Color, tier: int, delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var hot := col.lightened(0.3)
	_seam.albedo_color = hot * (1.0 + 0.6 * float(tier))
	_crack_mat.albedo_color = col.lightened(0.45) * 1.7
	_gem_mat.albedo_color = col.lightened(0.15)
	_gem_mat.emission = col * (0.6 + 0.35 * float(tier) + 0.25 * sin(t * 3.0))
	# Iron at Common, turning gold as the rarity climbs.
	var gold := Color(1.0, 0.76, 0.28)
	_trim.albedo_color = gold if moon else Color(0.3, 0.27, 0.3).lerp(gold, clampf(float(tier) / 4.0, 0.0, 1.0))
	_runes.set_shader_parameter("col", Color(1.0, 0.25, 0.2) if moon and step == 0 else hot)
	_runes.set_shader_parameter("spin", t * (0.12 if step == 0 else 0.6))
	_root.position = Vector3.ZERO
	_root.rotation = Vector3(0, -0.38 + sin(t * 0.6) * 0.1, 0)
	_root.scale = Vector3.ONE
	if step == 0:   # closed: eyes breathing, a hop now and then
		var breathe := 0.55 + 0.45 * sin(t * 2.2)
		var eye := Color(1.0, 0.25, 0.2) if moon else Color(0.62, 0.52, 1.0)
		_eye_mat.albedo_color = eye.darkened(0.35 * (1.0 - breathe))
		_gem_mat.albedo_color = eye
		_gem_mat.emission = eye * (0.4 + 0.3 * breathe)
		_runes.set_shader_parameter("glow", 0.25 + 0.15 * breathe)
		_chain_mat.emission = Color.BLACK
		var hop := fmod(t, 2.4)
		if hop < 0.4:
			var f := hop / 0.4
			_root.position.y = sin(f * PI) * 0.1
			_root.scale = Vector3(1.0 + 0.05 * sin(f * TAU), 1.0 - 0.05 * sin(f * TAU), 1.0 + 0.05 * sin(f * TAU))
	elif step == 1:   # opening: shaking harder, chains straining, cracks appearing
		var kk := clampf(k, 0.0, 1.0)
		var amp := 0.015 + 0.06 * kk
		_root.rotation.z = sin(t * 52.0) * amp * 2.0
		_root.position.x = sin(t * 61.0) * amp
		_root.scale = Vector3(1.0 + 0.04 * kk, 1.0 - 0.03 * kk, 1.0 + 0.04 * kk)
		_lid.rotation.x = -absf(sin(t * 30.0)) * amp * 1.6
		for i in _cracks.size():
			_cracks[i].visible = i < tier
		_eye_mat.albedo_color = hot
		_chain_mat.emission = col * (0.3 + 1.6 * kk) * (0.8 + 0.2 * sin(t * 40.0))
		_runes.set_shader_parameter("glow", 0.5 + 0.5 * kk)
		_light.light_color = col
		_light.light_energy = 0.3 * float(tier) + 0.5 * kk
	elif _opened:
		_open = minf(1.0, _open + delta / 0.9)
		_snap += delta
		# The lid springs back past open and settles.
		var e := 1.0 - exp(-7.0 * _open) * cos(13.0 * _open)
		_lid.rotation.x = LID_OPEN * e
		_lid.position = Vector3(0, TOP_Y + 0.05 * minf(1.0, _open * 4.0), -LID_R - 0.06 * e)
		# A squash as it bursts, then it stands tall.
		var pop := exp(-6.0 * _snap) * sin(_snap * 18.0)
		_root.scale = Vector3(1.0 - 0.06 * pop, 1.0 + 0.08 * pop, 1.0 - 0.06 * pop)
		_beam.scale = Vector3(1, 0.15 + 0.85 * ease(_open, 0.4), 1)
		_rays.set_shader_parameter("power", (0.7 + 0.15 * float(tier)) * (0.85 + 0.15 * sin(t * 3.0)))
		_glow_mat.set_shader_parameter("power", 0.5 + 0.08 * sin(t * 5.0))
		_light.light_energy = lerpf(_light.light_energy, 1.6 + 0.25 * float(tier), delta * 3.0)
		_eye_mat.albedo_color = hot
		_runes.set_shader_parameter("glow", 0.6 + 0.3 * exp(-2.0 * _snap))
		_chain_mat.emission = col * maxf(0.0, 1.8 - _snap * 1.5)
		# Links and padlocks flying.
		if _links.visible:
			var g := Vector3(0, -7.0, 0)
			var s := clampf(1.0 - (_snap - 0.6) / 0.6, 0.0, 1.0)
			for i in _link_rest.size():
				var r := _link_rest[i]
				var p := r.origin + _link_vel[i] * _snap + g * 0.5 * _snap * _snap
				var b := r.basis.rotated(_link_spin[i].normalized(), _link_spin[i].length() * _snap * 0.3)
				_links.multimesh.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * s) if s < 1.0 else b, p))
			for i in _locks.size():
				var lr := _lock_rest[i]
				var lx := signf(lr.origin.x)
				_locks[i].transform = Transform3D(lr.basis.rotated(Vector3.FORWARD, lx * _snap * 5.0),
						lr.origin + Vector3(lx * 1.2 * _snap, 1.2 * _snap - 3.5 * _snap * _snap, 0.9 * _snap))
				_locks[i].visible = s > 0.0
			if s <= 0.0:
				_links.visible = false
		if _ring.visible:
			var rs := _ring.scale.x + delta * 6.0
			_ring.scale = Vector3(rs, 0.2, rs)
			_ring_mat.albedo_color = Color(col, maxf(0.0, 0.8 - (rs - 0.3) * 0.25))
			if rs > 3.6:
				_ring.visible = false
		for c in _cracks:
			c.visible = true
		_lift = move_toward(_lift, _lift_to, delta * 1.2)
		_root.position.y += _lift
