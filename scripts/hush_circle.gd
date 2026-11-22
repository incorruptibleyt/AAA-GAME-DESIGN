class_name HushCircle
extends Node3D
## The Hush Keeper's spell (version 271, the Whispering Library's own skeleton). A circle of
## glowing letters writes itself round the floor where the hero stood, one letter after
## another, a bright pen racing round ahead of them: that is the warning. When the ring
## closes the floor inside goes dark as spilt ink and a low curtain of teal light rises from
## the letters. While the hero stands inside, their weapon is silent (Hero.hush): step out to
## fight again. It fades after a few seconds, or at once when its Hush Keeper dies. It never
## hurts anyone.

const TEAL := Color(0.35, 1.0, 0.82)
const RADIUS := 2.1
## Seconds for the ring of letters to close (the warning), and how long it silences after.
const WRITE := 1.0
const HOLD := 4.0
const FADE := 0.4
const WALL := 0.75

## Every circle on the floor (the test robot steps out of them).
static var all: Array[HushCircle] = []
static var _shader: Shader
static var _wall_shader: Shader
static var _wall_mesh: CylinderMesh

var radius := RADIUS
var keeper: Enemy
var _age := 0.0
var _fade := -1.0
var _sealed := false
var _mat: ShaderMaterial
var _wall: MeshInstance3D
var _wall_mat: ShaderMaterial


static func spawn(at: Vector3, by: Enemy) -> HushCircle:
	var parent := Telegraph._parent()
	if parent == null:
		return null
	var c := HushCircle.new()
	c.keeper = by
	parent.add_child(c)
	c.global_position = Vector3(at.x, 0.035, at.z)
	c._build()
	Sfx.play("warn", 0.5)
	Sfx.play("quill", 0.7)
	return c


## For the shader warm-up (warmup.gd): a sealed circle that just sits there, no sound, no
## fading, so both its shaders are ready before the first Hush Keeper writes one.
static func warm(parent: Node, at: Vector3) -> void:
	var c := HushCircle.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(c)
	c.position = at
	c._build()
	c._wall.visible = true
	c._mat.set_shader_parameter("k", 1.0)
	c._mat.set_shader_parameter("on", 1.0)
	c._wall_mat.set_shader_parameter("a", 1.0)


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


## Silencing the hero right now (the ring is closed and not yet fading).
func sealed() -> bool:
	return _sealed and _fade < 0.0


## Whether `p` (a body `r` round) is inside the circle.
func covers(p: Vector3, r := 0.0) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= radius + r


func _build() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_wall_shader = Shader.new()
		_wall_shader.code = WALL_SHADER
		_wall_mesh = CylinderMesh.new()
		_wall_mesh.top_radius = RADIUS - 0.05
		_wall_mesh.bottom_radius = RADIUS - 0.05
		_wall_mesh.height = WALL
		_wall_mesh.radial_segments = 40
		_wall_mesh.rings = 1
		_wall_mesh.cap_top = false
		_wall_mesh.cap_bottom = false
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("R", radius)
	_mat.set_shader_parameter("teal", TEAL)
	_mat.set_shader_parameter("seed", randf() * 50.0)
	U.floor_quad(self, Vector2(radius * 2 + 0.6, radius * 2 + 0.6), _mat)
	_wall_mat = ShaderMaterial.new()
	_wall_mat.shader = _wall_shader
	_wall_mat.set_shader_parameter("teal", TEAL)
	_wall = MeshInstance3D.new()
	_wall.mesh = _wall_mesh
	_wall.material_override = _wall_mat
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.position.y = WALL * 0.5
	_wall.visible = false
	add_child(_wall)


func _process(delta: float) -> void:
	_age += delta
	var keeper_gone := not is_instance_valid(keeper) or keeper.dead
	if _fade < 0.0 and (_age >= WRITE + HOLD or keeper_gone):
		_fade = 0.0
	if _fade >= 0.0:
		_fade += delta
		var left := 1.0 - _fade / FADE
		if left <= 0.0:
			queue_free()
			return
		_mat.set_shader_parameter("fade", left)
		_wall_mat.set_shader_parameter("a", left * (1.0 if _sealed else 0.0))
		return
	_mat.set_shader_parameter("k", clampf(_age / WRITE, 0.0, 1.0))
	if _age >= WRITE and not _sealed:
		_sealed = true
		_wall.visible = true
		Sfx.play("hush", 0.8)
		Fx.magic(global_position + Vector3.UP * 0.3, TEAL, 16)
	if _sealed:
		var on := clampf((_age - WRITE) / 0.18, 0.0, 1.0)
		_mat.set_shader_parameter("on", on)
		_wall_mat.set_shader_parameter("a", on)
		var hero := Game.hero
		if hero and not hero.dead and Game.state == Game.State.PLAYING and covers(hero.global_position):
			hero.hush(0.15)


const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float R = 2.1;
uniform vec4 teal : source_color = vec4(0.35, 1.0, 0.82, 1.0);
// How far round the letters are written (0..1), how sealed it is, and its fade out.
uniform float k = 0.0;
uniform float on = 0.0;
uniform float fade = 1.0;
uniform float seed = 0.0;
varying vec2 lp;

void vertex() {
	lp = VERTEX.xz;
}

float h1(vec2 p) { return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453); }

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * t);
}

void over(inout vec4 acc, vec3 c, float a) {
	acc.rgb = c * a + acc.rgb * (1.0 - a);
	acc.a = a + acc.a * (1.0 - a);
}

void fragment() {
	float d = length(lp);
	float aa = fwidth(d) + 0.003;
	float an = atan(lp.y, lp.x);
	// Where round the ring this point is (0..1), the way the pen writes; once sealed the
	// letters turn slowly.
	float u0 = fract((an + 3.14159265) / 6.2831853);
	float spin = TIME * 0.04 * on;
	float mid = R - 0.22;
	float N = floor(6.2831853 * mid / 0.27);
	float cell = floor(fract(u0 + spin) * N);
	float cu = (cell + 0.5) / N;
	float ca = (cu - spin) * 6.2831853 - 3.14159265;
	vec2 cdir = vec2(cos(ca), sin(ca));
	vec2 cp = vec2(dot(lp, vec2(-cdir.y, cdir.x)), d - mid);
	// Each letter a few strokes of its own.
	float glyph = 9.0;
	for (int g = 0; g < 3; g++) {
		float hg = h1(vec2(cell, float(g) + 3.0));
		vec2 a0 = (vec2(h1(vec2(cell, float(g))), hg) - 0.5) * vec2(0.13, 0.17);
		vec2 a1 = a0 + vec2(cos(hg * 6.28), sin(hg * 6.28)) * 0.11;
		glyph = min(glyph, seg(cp, a0, a1) - 0.02);
	}
	float letter = (1.0 - smoothstep(-0.004, 0.004 + aa, glyph)) * step(abs(cp.y), 0.15);
	float written = on > 0.0 ? 1.0 : step(cu, k);
	float fresh = (1.0 - smoothstep(0.0, 0.1, k - cu)) * written * (1.0 - on);
	float inside = 1.0 - smoothstep(R - aa, R + aa, d);
	float rims = max(1.0 - smoothstep(0.028, 0.028 + aa, abs(d - R + 0.03)), 1.0 - smoothstep(0.018, 0.018 + aa, abs(d - R + 0.42)));
	float drawn = on > 0.0 ? 1.0 : step(u0, k);
	// The pen racing round ahead of the letters.
	float pa = k * 6.2831853 - 3.14159265;
	float pen = (1.0 - smoothstep(0.05, 0.2, length(lp - mid * vec2(cos(pa), sin(pa))))) * step(k, 0.999) * (1.0 - on);

	vec4 acc = vec4(0.0);
	// A dark edge outside, so it reads on any floor.
	over(acc, vec3(0.0, 0.03, 0.03), (1.0 - smoothstep(0.0, 0.14, d - R)) * (1.0 - inside) * 0.75 * max(drawn, on));
	// While it is written: a faint wash showing where it will close. Sealed: spilt ink,
	// glowing a little at its edge.
	over(acc, teal.rgb * 0.6, inside * 0.12 * (1.0 - on));
	over(acc, vec3(0.012, 0.035, 0.045), inside * 0.66 * on);
	over(acc, teal.rgb * 0.7, inside * smoothstep(R - 1.1, R - 0.42, d) * 0.3 * on);
	over(acc, teal.rgb, rims * drawn * (0.65 + 0.35 * on));
	over(acc, mix(teal.rgb, vec3(1.0), fresh * 0.7), letter * written);
	over(acc, vec3(1.0, 1.0, 0.95), pen);
	float bright = 1.0 + 0.7 * letter * written + 0.8 * pen + 0.3 * rims * on;
	ALBEDO = acc.rgb / max(acc.a, 0.001) * bright;
	ALPHA = acc.a * fade;
}
"""


const WALL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 teal : source_color = vec4(0.35, 1.0, 0.82, 1.0);
uniform float a = 0.0;
varying float y;
varying float an;

void vertex() {
	y = VERTEX.y / 0.75 + 0.5;
	an = atan(VERTEX.z, VERTEX.x);
}

void fragment() {
	// Brightest at the letters, fading upwards, in columns that drift up like rising words.
	float cols = 0.55 + 0.45 * sin(an * 26.0) * sin(an * 9.0 + TIME * 0.7);
	float rise = 0.7 + 0.3 * sin(y * 18.0 - TIME * 4.0);
	float fall = pow(1.0 - clamp(y, 0.0, 1.0), 2.2);
	ALBEDO = teal.rgb * fall * cols * rise * 0.55 * a;
}
"""
