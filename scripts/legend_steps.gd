class_name LegendSteps
extends Node3D
## Version 313 (Legend Vault, legends.gd): marks the hero leaves on the floor as they walk.
##   ember_steps: Ember Steps. Each step burns a footprint into the floor, white-hot in the
##                middle and orange to red at its edge, with three little flames rising off it
##                (version 317: it was one flat orange print, which read as mud); it cools from
##                white through orange to red and goes out in about two seconds, and the black
##                scorch fades after it. Version 326: each step cracks the floor, glowing
##                cracks of magma that split out from the print and cool with it; embers puff
##                up from every step and trail off the hero's boots; the steps are drawn
##                bigger in a run, and a dash leaves a line of fire.
##   star_steps:  Stardust Steps (version 322: it was five faint sparkles per step). Each step
##                drops a fat five-pointed star onto the floor (a white heart, a coloured
##                rim, a dark outline) that pops in with a flash of light and a ring of
##                stardust, and a line of light joins it to the step before, so the hero's
##                path is drawn behind them as a constellation; the stars twinkle, shed
##                motes and go out one by one. A dash leaves a streak of stardust.
## In a run the marks lie in the world (top_level) wherever the hero walked; on a pedestal a
## line of steps walks out from the hero's feet towards the camera, over and over, tipped up so
## the camera can see them.

var kind := "ember_steps"

const STRIDE := 0.62   # metres between two steps
const POOL := 18   # marks kept at once (the oldest is reused)
const FOOT_GAP := 0.17   # each foot this far from the middle of the path

var _anchor: Node3D
var _staged := false
var _last := Vector3.ZERO
var _walked := 0.0
var _foot := 1.0
var _marks: Array[Dictionary] = []
var _next := 0
var _stage_t := 0.0
var _stage_i := 0
var _prev_at := Vector3(INF, 0, 0)   # (the last star, for the line of light to the next)
var _dust: CPUParticles3D   # (Stardust Steps: the streak a dash leaves)
var _boots: CPUParticles3D  # (Ember Steps: embers trailing off the hero's boots in a run)
var _dashing := false

## Ember Steps are drawn this much bigger in a run (the camera is far above), more in a dash.
const EMBER_RUN := 1.7
const EMBER_DASH := 2.1

## Stardust Steps: the colours the stars take in turn (pale gold, ice blue, violet, sea green).
const STAR_COLS := [Color(1.0, 0.8, 0.35), Color(0.45, 0.75, 1.0), Color(0.72, 0.5, 1.0), Color(0.4, 0.95, 0.85)]


func _ready() -> void:
	_anchor = get_parent() as Node3D
	_staged = get_viewport() is SubViewport
	top_level = not _staged
	if not _staged:
		global_transform = Transform3D.IDENTITY
		_last = _anchor.global_position
	for i in POOL:
		_marks.append(_make_mark())
	if kind == "star_steps" and not _staged:
		_dust = _star_dust()
		add_child(_dust)
	if kind == "ember_steps" and not _staged:
		_boots = _ember_boots()
		add_child(_boots)


func _process(delta: float) -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return
	for m: Dictionary in _marks:
		if m.age >= 0.0:
			m.age += delta
			_fade(m)
	if _staged:
		# A line of steps out from the hero's feet towards the camera, again and again.
		_stage_t += delta
		if _stage_t > 0.42:
			_stage_t = 0.0
			# (walking across the front of the pedestal, right to left on the screen)
			var n := _stage_i % 4
			_stage_i += 1
			_put(Vector3(-0.85 + 0.55 * n, 0.012, -0.72 + (0.13 if n % 2 == 0 else -0.13)), -PI / 2.0)
		return
	var a := _anchor.global_position
	var step := Vector3(a.x - _last.x, 0, a.z - _last.z)
	_last = a
	if step.length() > 3.0 or a.y > 0.5:
		return   # (a jump to a new room, or flung through the air)
	_walked += step.length()
	# A dash is 21 m/s; a run is 6.
	_dashing = step.length() > 12.0 * delta
	if _dust:
		# A dash streams stardust from the hero.
		_dust.global_position = a + Vector3(0, 0.5, 0)
		_dust.emitting = _dashing
	if _boots:
		_boots.global_position = a + Vector3(0, 0.12, 0)
		_boots.emitting = step.length() > 1.0 * delta
	# (Ember Steps in a dash: a line of fire, steps close together down the middle.)
	var stride := 0.34 if (_dashing and kind == "ember_steps") else STRIDE
	if _walked >= stride and step.length() > 0.001:
		_walked = 0.0
		var dir := step.normalized()
		_foot = -_foot
		var side := Vector3(-dir.z, 0, dir.x) * FOOT_GAP * _foot * (0.4 if _dashing else 1.0)
		_put(Vector3(a.x, 0.045, a.z) + side, atan2(-dir.x, -dir.z))


## The next mark from the pool, put down at `at` facing `yaw`.
func _put(at: Vector3, yaw: float) -> void:
	var m: Dictionary = _marks[_next]
	_next = (_next + 1) % POOL
	var n: Node3D = m.node
	n.position = at
	n.rotation = Vector3(0, yaw, 0)
	if _staged:
		# The pedestal is seen almost side on, where a mark flat on the floor is a thin line:
		# there the steps are drawn bigger and tipped up towards the camera, floating a little.
		n.basis = Basis(Vector3.RIGHT, -0.65) * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * 1.35)
		n.position.y = 0.16
		if n.has_node("Heat"):
			n.get_node("Heat").visible = false
	elif kind == "ember_steps":
		n.scale = Vector3.ONE * (EMBER_DASH if _dashing else EMBER_RUN)
		# Embers puff up off the step (it is the world's burst pool: only in a run).
		Fx._burst(at + Vector3(0, 0.15, 0), 7 if _dashing else 5, Color(1.0, 0.55, 0.15), 0.16, 1.6, 0.9, -0.15, true, "glow")
	n.visible = true
	m.age = 0.0
	m.seed = randf() * TAU
	if kind == "star_steps":
		_star_put(m, at)
	elif m.has("crack"):
		(m.crack as ShaderMaterial).set_shader_parameter("seed", randf() * 50.0)
	_fade(m)


func _fade(m: Dictionary) -> void:
	var t: float = m.age
	var n: Node3D = m.node
	if kind == "star_steps":
		_star_fade(m, t)
		return
	# Ember Steps: the fire flickers out in about two seconds; the scorch fades after it.
	var life_e := 4.0
	if t >= life_e:
		n.visible = false
		m.age = -1.0
		return
	var fire := 1.0 - smoothstep(0.2, 2.2, t)
	(m.glow as ShaderMaterial).set_shader_parameter("heat", fire)
	(m.flame as ShaderMaterial).set_shader_parameter("heat", pow(fire, 1.6))
	(m.haze as StandardMaterial3D).albedo_color.a = fire * 0.45
	(m.scorch as StandardMaterial3D).albedo_color.a = 0.75 * (1.0 - smoothstep(2.0, life_e, t))
	var crack := m.crack as ShaderMaterial
	crack.set_shader_parameter("heat", 1.0 - smoothstep(0.3, 3.2, t))
	crack.set_shader_parameter("grow", smoothstep(0.0, 0.16, t))


func _make_mark() -> Dictionary:
	var n := Node3D.new()
	n.visible = false
	add_child(n)
	var m := {"node": n, "age": -1.0, "seed": 0.0}
	if kind == "star_steps":
		_star_mark(n, m)
		return m
	# Ember Steps: a black scorch under a burning footprint, a haze of heat round it, glowing
	# cracks splitting the floor out from it, and three little flames standing on it (at the
	# toes, the ball and the heel).
	var char_mat := StandardMaterial3D.new()   # (the scorch)
	char_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	char_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	char_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	char_mat.albedo_color = Color(0.08, 0.04, 0.02, 0.75)
	char_mat.albedo_texture = footprint()
	U.floor_quad(n, Vector2(0.3, 0.46), char_mat, Vector3.ZERO)
	var haze_mat := _flat_mat(Color(1.0, 0.36, 0.06), null)
	var hot := U.floor_quad(n, Vector2(0.6, 0.85), haze_mat, Vector3(0, 0.002, 0))
	hot.name = "Heat"
	var glow_mat := _ember_glow_mat()
	glow_mat.set_shader_parameter("seed", randf() * 10.0)
	U.floor_quad(n, Vector2(0.28, 0.44), glow_mat, Vector3(0, 0.004, 0))
	var flame_mat := _ember_flame_mat()
	for at in [Vector3(-0.01, 0.13, -0.15), Vector3(0.03, 0.11, -0.03), Vector3(0.0, 0.1, 0.13)]:
		var f := MeshInstance3D.new()
		f.mesh = LegendPet._quad(0.28)
		f.material_override = flame_mat
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = at
		n.add_child(f)
	var crack_mat := _ember_crack_mat()
	U.floor_quad(n, Vector2(1.1, 1.1), crack_mat, Vector3(0, 0.003, 0))
	m.scorch = char_mat
	m.glow = glow_mat
	m.flame = flame_mat
	m.haze = haze_mat
	m.crack = crack_mat
	return m


# ---------------------------------------------------------------- Stardust Steps

static var _star_mesh: ArrayMesh
static var _star_shader: Shader
static var _ring_shader: Shader
static var _line_shader: Shader


## A step's star: a soft glow under it, the star itself, a ring of stardust that rings out,
## a flash of light over it and two motes that rise off it; the line of light back to the
## step before is its own (it lies between the two).
func _star_mark(n: Node3D, m: Dictionary) -> void:
	m.glow = _flat_mat(Color.WHITE, null)
	m.glow_q = U.floor_quad(n, Vector2.ONE * 1.0, m.glow, Vector3(0, 0.002, 0))
	m.ring = _star_mat("ring")
	U.floor_quad(n, Vector2.ONE * 1.7, m.ring, Vector3(0, 0.004, 0))
	m.star = _star_mat("star")
	var st := MeshInstance3D.new()
	st.mesh = _star_shape()
	st.material_override = m.star
	st.position = Vector3(0, 0.008, 0)
	st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(st)
	m.star_q = st
	m.flare = LegendPet._add_mat(Color.WHITE, true)
	m.flare.albedo_texture = U.glint()
	m.flare.render_priority = 3
	var fl := MeshInstance3D.new()
	fl.mesh = LegendPet._quad(1.0)
	fl.material_override = m.flare
	fl.position = Vector3(0, 0.18, 0)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(fl)
	m.flare_q = fl
	m.mote = LegendPet._add_mat(Color.WHITE, true)
	m.mote.albedo_texture = U.glint()
	var motes: Array[Node3D] = []
	for i in 2:
		var q := MeshInstance3D.new()
		q.mesh = LegendPet._quad(0.2)
		q.material_override = m.mote
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(q)
		motes.append(q)
	m.motes = motes
	m.line = _star_mat("line")
	var ln := U.floor_quad(self, Vector2(0.15, 1.0), m.line, Vector3.ZERO)
	ln.visible = false
	m.line_q = ln


## Lays a step's star at `at`: its colour, a turn of its own, and the line of light from the
## step before (none after a jump to a new room).
func _star_put(m: Dictionary, at: Vector3) -> void:
	var col: Color = STAR_COLS[_next % STAR_COLS.size()]
	m.col = col
	m.glow.albedo_color = Color(col, 0.0)
	m.mote.albedo_color = Color(col.lightened(0.4), 0.0)
	m.flare.albedo_color = Color(col.lightened(0.6), 0.0)
	for k in ["ring", "star", "line"]:
		(m[k] as ShaderMaterial).set_shader_parameter("col", col)
	(m.star_q as Node3D).rotation.y = randf() * TAU
	var ln: MeshInstance3D = m.line_q
	var d := at - _prev_at
	d.y = 0.0
	ln.visible = d.length() > 0.2 and d.length() < 1.6
	if ln.visible:
		var mid := (at + _prev_at) * 0.5
		var b := Basis(Vector3.UP, atan2(d.x, d.z)) * Basis.from_scale(Vector3(1.0, 1.0, d.length()))
		if _staged:
			b = Basis(Vector3.RIGHT, -0.65) * b * Basis.from_scale(Vector3(1.35, 1.0, 1.0))
			mid.y = 0.16
		ln.transform = Transform3D(b, mid + Vector3(0, 0.003, 0))
	_prev_at = at


func _star_fade(m: Dictionary, t: float) -> void:
	var n: Node3D = m.node
	var life := 3.0
	var ln: MeshInstance3D = m.line_q
	if t >= life:
		n.visible = false
		ln.visible = false
		m.age = -1.0
		return
	var out := 1.0 - smoothstep(life * 0.55, life, t)
	# The star pops in (overshooting), twinkles, and shrinks away at the end.
	var pop := minf(1.0, t / 0.1)
	var s := pop * (1.0 + 0.45 * sin(minf(t / 0.32, 1.0) * PI) ) * (0.25 + 0.75 * out)
	s *= 1.0 + 0.08 * sin(t * 9.0 + m.seed)
	(m.star_q as Node3D).scale = Vector3.ONE * (0.15 if _staged else 0.3) * s
	(m.star_q as Node3D).rotation.y += 0.01
	(m.star as ShaderMaterial).set_shader_parameter("alpha", minf(1.0, t * 12.0) * minf(1.0, out * 1.6))
	(m.glow as StandardMaterial3D).albedo_color.a = (0.55 + 0.25 * sin(t * 6.0 + m.seed)) * out * pop + 0.5 * (1.0 - smoothstep(0.0, 0.3, t))
	(m.glow_q as Node3D).scale = Vector3.ONE * (0.7 + 0.3 * out)
	# A flash of light as it lands, then a small twinkle over it now and then.
	var flash := 1.0 - smoothstep(0.0, 0.35, t)
	var tw := pow(maxf(0.0, sin(t * 4.5 + m.seed)), 8.0) * 0.6 * out
	(m.flare as StandardMaterial3D).albedo_color.a = maxf(flash, tw)
	(m.flare_q as Node3D).scale = Vector3.ONE * (0.35 + 1.0 * flash + 0.25 * tw)
	(m.ring as ShaderMaterial).set_shader_parameter("t", clampf(t / 0.55, 0.0, 1.0))
	# The line of light draws itself from the step before to this one, then fades first.
	(m.line as ShaderMaterial).set_shader_parameter("grow", clampf(t / 0.16, 0.0, 1.0))
	(m.line as ShaderMaterial).set_shader_parameter("alpha", 1.0 - smoothstep(life * 0.4, life * 0.85, t))
	# Two motes rise off it, drifting and fading.
	var motes: Array = m.motes
	for i in motes.size():
		var k := fmod(t * 0.8 + i * 0.5, 1.0)
		var q: Node3D = motes[i]
		q.position = Vector3(sin(m.seed + i * 2.6) * 0.14, 0.1 + k * 0.9, cos(m.seed + i * 2.6) * 0.14)
		q.scale = Vector3.ONE * (1.0 - k * 0.6)
	(m.mote as StandardMaterial3D).albedo_color.a = 0.9 * out * minf(1.0, t * 3.0)


## The star: five fat points round a white heart, rim in the mark's colour (`col`), with a
## dark outline round it so it stands off any floor. UV.x: 0 at the heart to 1 at the rim;
## UV.y 1 on the outline.
static func _star_shape() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		var big := 1.2 if layer == 0 else 1.0
		var y := 0.0 if layer == 0 else 0.004
		var pts: Array[Vector3] = []
		for i in 10:
			var a := TAU * i / 10.0
			var r := (1.0 if i % 2 == 0 else 0.5) * big
			pts.append(Vector3(sin(a) * r, y, -cos(a) * r))
		for i in 10:
			for v in [[Vector3(0, y + 0.03, 0), 0.0], [pts[i], 1.0], [pts[(i + 1) % 10], 1.0]]:
				st.set_uv(Vector2(v[1], 1.0 - layer))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	_star_mesh = st.commit()
	return _star_mesh


## Each mark's own material for its star, its ring of stardust or its line of light.
static func _star_mat(which: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	match which:
		"star":
			if _star_shader == null:
				_star_shader = Shader.new()
				_star_shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float alpha = 0.0;
void fragment() {
	vec3 c = mix(vec3(1.0, 1.0, 0.95), col.rgb, smoothstep(0.25, 0.85, UV.x));
	c = mix(c, col.rgb * 0.22, UV.y);
	ALBEDO = c;
	ALPHA = alpha;
}
"""
			m.shader = _star_shader
			m.render_priority = 2
		"ring":
			if _ring_shader == null:
				_ring_shader = Shader.new()
				_ring_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float t = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float at = 0.15 + t * 0.8;
	float band = 1.0 - smoothstep(0.0, 0.07 + 0.05 * t, abs(r - at));
	float cell = floor(a * 4.0);
	float dots = smoothstep(0.55, 0.95, fract(sin(cell * 12.9898) * 43758.5453)) * (1.0 - smoothstep(0.0, 0.05, abs(r - at - 0.04)));
	ALBEDO = (col.rgb * band + vec3(1.0) * dots) * (1.0 - t) * 1.3;
	// (added light writes its own alpha: over a see-through pedestal picture an
	// unwritten alpha of 1 drew a black box wherever the quad lay)
	float glow_a = max(max(ALBEDO.r, ALBEDO.g), ALBEDO.b);
	ALBEDO /= max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
}
"""
			m.shader = _ring_shader
			m.render_priority = 1
		"line":
			if _line_shader == null:
				_line_shader = Shader.new()
				_line_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float grow = 0.0;
uniform float alpha = 0.0;
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float along = UV.y;
	float shown = step(along, grow);
	float spark = exp(-pow((along - fract(TIME * 0.9 + col.r * 3.0)) * 9.0, 2.0));
	float ends = smoothstep(0.0, 0.12, along) * smoothstep(0.0, 0.12, 1.0 - along);
	ALBEDO = (col.rgb * across * across * 0.9 + vec3(1.0) * spark * across * 0.8) * shown * ends * alpha;
	// (added light writes its own alpha: over a see-through pedestal picture an
	// unwritten alpha of 1 drew a black box wherever the quad lay)
	float glow_a = max(max(ALBEDO.r, ALBEDO.g), ALBEDO.b);
	ALBEDO /= max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
}
"""
			m.shader = _line_shader
			m.render_priority = 1
	return m


## The streak a dash leaves: glints in the stars' colours that hang in the air and fade.
static func _star_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.9
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3(0, -0.4, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.45
	p.mesh = q
	var m := LegendPet._add_mat(Color(1, 1, 1, 1), true)
	m.albedo_texture = U.glint()
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.95, 0.8, 1.0), Color(1.0, 0.8, 0.35, 0.9), Color(0.5, 0.75, 1.0, 0.7), Color(0.72, 0.5, 1.0, 0.0)])
	p.color_ramp = g
	return p


static var _glow_shader: Shader
static var _flame_shader: Shader
static var _crack_shader: Shader


## Version 326: glowing cracks that split the floor out from a burning step: six jagged lines
## from the print's edge, thick at the root and thin at the tip, that run out as the foot
## lands (`grow` 0 to 1) and cool from white-gold through orange to dull red (`heat` 1 to 0).
static func _ember_crack_mat() -> ShaderMaterial:
	if _crack_shader == null:
		_crack_shader = Shader.new()
		_crack_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float heat = 0.0;
uniform float grow = 1.0;
uniform float seed = 0.0;
float h1(float n) {
	return fract(sin(n * 91.7 + seed * 13.1) * 43758.5);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float on = 0.0;
	float reach = 1.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float ca = fi / 6.0 * 6.2832 + (h1(fi) - 0.5) * 0.8;
		float len = 0.5 + 0.45 * h1(fi + 7.0);
		float jag = sin(r * 23.0 + fi * 3.1 + seed) * 0.13 + sin(r * 51.0 + fi * 1.7) * 0.05;
		float da = abs(mod(a - ca - jag + 3.1416, 6.2832) - 3.1416);
		float d = da * r;
		float k = clamp(r / len, 0.0, 1.0);
		float w = mix(0.065, 0.014, k);
		float c = (1.0 - smoothstep(w * 0.45, w, d)) * step(r, len * grow);
		if (c > on) {
			on = c;
			reach = k;
		}
	}
	on *= smoothstep(0.12, 0.2, r);
	float h = heat * (1.0 - 0.55 * reach);
	vec3 col = mix(vec3(0.9, 0.14, 0.0), vec3(1.0, 0.5, 0.06), smoothstep(0.1, 0.5, h));
	col = mix(col, vec3(1.0, 0.92, 0.6), smoothstep(0.65, 1.0, h));
	vec3 c = col * on * clamp(heat * 1.6, 0.0, 1.0);
	c += vec3(1.0, 0.38, 0.04) * pow(max(0.0, 1.0 - r * 2.4), 2.0) * 0.4 * heat;
	float glow_a = max(max(c.r, c.g), c.b);
	ALBEDO = c / max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _crack_shader
	m.render_priority = 1
	return m


## Ember Steps in a run: embers trailing off the hero's boots as they walk.
static func _ember_boots() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = Fx._shaped("glow")
	p.amount = 16
	p.lifetime = 0.8
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.25, 0.04, 0.25)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0, 0.9, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.scale_amount_min = 0.07
	p.scale_amount_max = 0.14
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.4, 0.08, 0.8), Color(0.6, 0.1, 0.0, 0.0)])
	p.color_ramp = g
	return p


## The burning footprint (one per mark, to cool it): white-hot where the print is deepest (the
## middle of the heel, the ball and each toe), orange, then red at its edge; `heat` 1 to 0.
static func _ember_glow_mat() -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D foot : filter_linear;
uniform float heat = 0.0;
uniform float seed = 0.0;
void fragment() {
	float v = texture(foot, UV).r;
	float fl = 0.88 + 0.12 * sin(TIME * 21.0 + seed) * sin(TIME * 13.0 + seed * 2.0);
	float h = heat * fl;
	float x = clamp(v * 1.5 * h + h * 0.15, 0.0, 1.0);
	vec3 c = mix(vec3(0.6, 0.06, 0.0), vec3(1.0, 0.46, 0.06), smoothstep(0.05, 0.5, x));
	c = mix(c, vec3(1.0, 0.93, 0.62), smoothstep(0.55, 0.95, x));
	float a = smoothstep(0.0, 0.12, v) * clamp(h * 1.4, 0.0, 1.0);
	ALBEDO = c * a;
	// (added light writes its own alpha: over a see-through pedestal picture an
	// unwritten alpha of 1 drew a black box wherever the quad lay)
	float glow_a = max(max(ALBEDO.r, ALBEDO.g), ALBEDO.b);
	ALBEDO /= max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	m.set_shader_parameter("foot", footprint_depth())
	m.render_priority = 1   # (drawn over its own scorch, whichever is nearer the camera)
	return m


## A little flame standing on the print, always facing the camera; it shrinks as it cools.
static func _ember_flame_mat() -> ShaderMaterial:
	if _flame_shader == null:
		_flame_shader = Shader.new()
		_flame_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float heat = 0.0;
varying float sd;
void vertex() {
	sd = MODEL_MATRIX[3].x * 7.13 + MODEL_MATRIX[3].z * 3.71;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float h = clamp(heat, 0.0, 1.0);
	float yy = p.y / max(h, 0.05);
	p.x += sin(yy * 5.0 - TIME * 7.0 - sd) * 0.12 * yy;
	float w = 0.5 * pow(max(1.0 - yy, 0.0), 0.75) * smoothstep(0.0, 0.2, yy);
	float inside = (1.0 - smoothstep(w * 0.45, w + 0.001, abs(p.x))) * step(yy, 1.0);
	float hot = (1.0 - smoothstep(0.0, w * 0.6 + 0.001, abs(p.x))) * (1.0 - yy);
	vec3 c = mix(vec3(1.0, 0.32, 0.04), vec3(1.0, 0.88, 0.5), hot);
	ALBEDO = c * inside * smoothstep(0.0, 0.25, h);
	// (added light writes its own alpha: over a see-through pedestal picture an
	// unwritten alpha of 1 drew a black box wherever the quad lay)
	float glow_a = max(max(ALBEDO.r, ALBEDO.g), ALBEDO.b);
	ALBEDO /= max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _flame_shader
	m.render_priority = 2
	return m


## A flat glowing mark on the floor, added over it (each mark has its own, to fade it).
static func _flat_mat(col: Color, tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col, 0.0)
	m.albedo_texture = tex if tex else U.soft_circle()
	return m


static var _foot_tex: ImageTexture

## The parts of a footprint on its 40 x 64 picture: centre and size of the heel, the arch, the
## ball and the five toes.
const FOOT_BLOBS := [
	[Vector2(20, 50), Vector2(9, 11)],   # heel
	[Vector2(21, 37), Vector2(8, 9)],    # arch
	[Vector2(20, 24), Vector2(12, 11)],  # ball
	[Vector2(9, 10), Vector2(4.5, 5)],
	[Vector2(16, 7), Vector2(4, 4.5)],
	[Vector2(23, 6), Vector2(3.6, 4)],
	[Vector2(29, 8), Vector2(3.2, 3.6)],
	[Vector2(34, 12), Vector2(3, 3.2)],
]


## A footprint, drawn once: a heel, a sole and five toes, toes at the top (towards -Z on the
## floor, the way the foot walks).
static func footprint() -> ImageTexture:
	if _foot_tex:
		return _foot_tex
	var w := 40
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var blobs := FOOT_BLOBS
	for y in h:
		for x in w:
			var a := 0.0
			for b in blobs:
				var c: Vector2 = b[0]
				var r: Vector2 = b[1]
				var d := Vector2((x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y).length()
				a = maxf(a, 1.0 - smoothstep(0.75, 1.0, d))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_foot_tex = ImageTexture.create_from_image(img)
	return _foot_tex


static var _depth_tex: ImageTexture


## The same footprint as footprint(), but deepest (1) in the middle of each part of the foot
## and 0 at its edge, for the burning print's colours.
static func footprint_depth() -> ImageTexture:
	if _depth_tex:
		return _depth_tex
	var w := 40
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var a := 0.0
			for b in FOOT_BLOBS:
				var c: Vector2 = b[0]
				var r: Vector2 = b[1]
				var d := Vector2((x + 0.5 - c.x) / r.x, (y + 0.5 - c.y) / r.y).length()
				a = maxf(a, clampf(1.0 - d, 0.0, 1.0))
			img.set_pixel(x, y, Color(a, a, a, 1.0))
	_depth_tex = ImageTexture.create_from_image(img)
	return _depth_tex
