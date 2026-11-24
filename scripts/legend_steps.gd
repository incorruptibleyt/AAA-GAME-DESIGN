class_name LegendSteps
extends Node3D
## Version 313 (Legend Vault, legends.gd): marks the hero leaves on the floor as they walk.
##   ember_steps: Ember Steps. Each step burns a footprint into the floor, white-hot in the
##                middle and orange to red at its edge, with three little flames rising off it
##                (version 317: it was one flat orange print, which read as mud); it cools from
##                white through orange to red and goes out in about two seconds, and the black
##                scorch fades after it.
##   star_steps:  Stardust Steps. Each step leaves a little constellation in the shape of a
##                footprint (five stars joined by faint lines) that twinkles and fades away.
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


func _ready() -> void:
	_anchor = get_parent() as Node3D
	_staged = get_viewport() is SubViewport
	top_level = not _staged
	if not _staged:
		global_transform = Transform3D.IDENTITY
		_last = _anchor.global_position
	for i in POOL:
		_marks.append(_make_mark())


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
	if _walked >= STRIDE and step.length() > 0.001:
		_walked = 0.0
		var dir := step.normalized()
		_foot = -_foot
		var side := Vector3(-dir.z, 0, dir.x) * FOOT_GAP * _foot
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
	n.visible = true
	m.age = 0.0
	m.seed = randf() * TAU
	_fade(m)


func _fade(m: Dictionary) -> void:
	var t: float = m.age
	var n: Node3D = m.node
	if kind == "star_steps":
		var life := 2.6
		if t >= life:
			n.visible = false
			m.age = -1.0
			return
		var k := 1.0 - smoothstep(life * 0.45, life, t)
		var mats: Array = m.mats
		for i in mats.size() - 1:
			var tw := 0.65 + 0.35 * sin(t * 9.0 + m.seed + i * 1.7)
			(mats[i] as StandardMaterial3D).albedo_color.a = k * tw * minf(1.0, t * 8.0)
		(mats[-1] as StandardMaterial3D).albedo_color.a = 0.6 * k * minf(1.0, t * 4.0)
		var stars: Array = m.stars
		for i in stars.size():
			var s := 1.0 + 0.25 * sin(t * 7.0 + i * 2.1 + m.seed)
			(stars[i] as Node3D).scale = Vector3(s, 1.0, s)
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
	(m.spark as Node3D).position.y = 0.05 + t * 0.5
	(m.spark_mat as StandardMaterial3D).albedo_color.a = fire * 0.9


func _make_mark() -> Dictionary:
	var n := Node3D.new()
	n.visible = false
	add_child(n)
	var m := {"node": n, "age": -1.0, "seed": 0.0}
	if kind == "star_steps":
		# Five stars where the heel, the arch, the ball and two toes of a foot would be.
		var spots := [Vector3(0, 0, 0.17), Vector3(0.02, 0, 0.03), Vector3(-0.01, 0, -0.1), Vector3(-0.05, 0, -0.21), Vector3(0.05, 0, -0.2)]
		var cols := [Color(0.85, 0.95, 1.0), Color(0.7, 0.85, 1.0), Color(1.0, 0.95, 0.75), Color(0.8, 0.75, 1.0), Color(0.85, 0.95, 1.0)]
		var mats: Array[StandardMaterial3D] = []
		var stars: Array[Node3D] = []
		for i in spots.size():
			var mat := _flat_mat(cols[i], U.glint())
			mats.append(mat)
			var q := U.floor_quad(n, Vector2.ONE * (0.4 if i != 1 else 0.28), mat, spots[i] * 1.25)
			stars.append(q)
		# The lines that join them, in one faint material.
		var line_mat := _flat_mat(Color(0.7, 0.85, 1.0), null)
		mats.append(line_mat)
		for pair in [[0, 1], [1, 2], [2, 3], [2, 4]]:
			var a: Vector3 = spots[pair[0]]
			var b: Vector3 = spots[pair[1]]
			a *= 1.25
			b *= 1.25
			var l := U.floor_quad(n, Vector2(0.02, a.distance_to(b)), line_mat, (a + b) * 0.5 - Vector3(0, 0.002, 0))
			l.rotation.y = atan2(b.x - a.x, b.z - a.z)
		m.mats = mats
		m.stars = stars
		return m
	# Ember Steps: a black scorch under a burning footprint, a haze of heat round it, three
	# little flames standing on it (at the toes, the ball and the heel) and a spark rising.
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
	var spark_mat := LegendPet._add_mat(Color(1.0, 0.7, 0.3, 0.9), true)
	var spark := MeshInstance3D.new()
	spark.mesh = LegendPet._quad(0.12)
	spark.material_override = spark_mat
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(spark)
	m.scorch = char_mat
	m.glow = glow_mat
	m.flame = flame_mat
	m.haze = haze_mat
	m.spark = spark
	m.spark_mat = spark_mat
	return m


static var _glow_shader: Shader
static var _flame_shader: Shader


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
