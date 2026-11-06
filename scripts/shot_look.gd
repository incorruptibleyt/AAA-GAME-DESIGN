class_name ShotLook
## How shots look, drawn by the graphics card on a few flat cards instead of stacks of
## spheres (cheaper, and much more glow).
##
## Undead shots: one look on every floor so danger reads at a glance. A glowing red-magenta
## orb with a white-hot middle, a near-black edge so it shows on bright floors, a soft halo,
## a comet tail and a patch of red light on the floor under it.
##
## Hero shots match the hero: the Rogue's crossbow bolts, the Knight's sword waves, the
## Barbarian's spinning axes and the Mage's swirling orbs (bone shards from blessings are
## thin white darts). They add light instead of covering things, so they never hide what is
## coming at you.

const DANGER := Color(1.0, 0.12, 0.38)

## Which hero shot each hero throws.
const HERO_KIND := {"rogue": "bolt", "knight": "wave", "barbarian": "axe", "mage": "orb"}
const K_BOLT := 0
const K_WAVE := 1
const K_AXE := 2
const K_ORB := 3
const K_GLOW := 4
const K_TAIL := 5

static var _hero_shader: Shader
static var _danger_shader: Shader
static var _mats := {}
static var _flat: QuadMesh
static var _card: QuadMesh
static var _danger_mat: ShaderMaterial
static var _floor_mats := {}


static func _shaders() -> void:
	if _hero_shader != null:
		return
	_flat = QuadMesh.new()
	_flat.size = Vector2.ONE
	_flat.orientation = PlaneMesh.FACE_Y
	_card = QuadMesh.new()
	_card.size = Vector2.ONE
	_hero_shader = Shader.new()
	_hero_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform int kind = 0;
uniform bool bill = false;
varying vec2 q;
void vertex() {
	if (bill) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
		q = VERTEX.xy * 2.0;
	} else {
		q = VERTEX.xz * 2.0;
	}
}
float sat(float x) { return clamp(x, 0.0, 1.0); }
void fragment() {
	vec2 p = q;   // -1..1; on flat cards -y is the way the shot flies
	vec3 hot = mix(col.rgb, vec3(1.0), 0.8);
	vec3 c = vec3(0.0);
	if (kind == 0) {
		// Bolt: a bright dart with a white edge and a tail that thins and fades.
		float t = sat((p.y + 0.82) / 1.82);
		float w = mix(0.34, 0.03, t);
		float ax = abs(p.x);
		float core = 1.0 - smoothstep(w * 0.16, w * 0.42, ax);
		float glow = 1.0 - smoothstep(w * 0.25, w * 1.5 + 0.06, ax);
		float fade = pow(1.0 - t, 1.4) * smoothstep(-1.0, -0.8, p.y);
		c = (col.rgb * glow + hot * core * 1.2) * fade;
	} else if (kind == 1) {
		// Sword wave: a crescent bowed forward, white on its leading edge, with a soft wake.
		float d = length(p - vec2(0.0, 1.25));
		float R = 2.0;
		float tips = 1.0 - smoothstep(0.35, 0.98, abs(p.x));
		float edge = 1.0 - smoothstep(0.0, 0.28, abs(d - R));
		float line = 1.0 - smoothstep(0.0, 0.08, abs(d - R + 0.04));
		float wake = smoothstep(R - 1.3, R, d) * step(d, R) * 0.6;
		c = (col.rgb * (edge * 0.9 + wake) + hot * line * 1.2) * tips;
	} else if (kind == 2) {
		// Blur ring around a spinning axe.
		float rr = length(p);
		float sw = 0.6 + 0.4 * sin(atan(p.y, p.x) * 2.0 - TIME * 30.0);
		c = col.rgb * ((1.0 - smoothstep(0.0, 0.16, abs(rr - 0.78))) * 0.55 * sw + (1.0 - smoothstep(0.2, 0.95, rr)) * 0.22);
	} else if (kind == 3) {
		// Magic orb: a white heart in a swirling glow.
		float r = length(p);
		float ang = atan(p.y, p.x);
		float sw = 0.5 + 0.5 * sin(ang * 3.0 + TIME * 9.0 - r * 8.0);
		float body = 1.0 - smoothstep(0.32, 0.5, r);
		float core = 1.0 - smoothstep(0.0, 0.3, r);
		float halo = (1.0 - smoothstep(0.35, 1.0, r)) * (0.25 + 0.4 * sw);
		c = col.rgb * (body * (0.55 + 0.45 * sw) + halo) + hot * core * 1.2;
	} else if (kind == 4) {
		// Soft glow: the head of a shot, a flash where it lands.
		float g = 1.0 - smoothstep(0.0, 1.0, length(p));
		c = col.rgb * g * g + hot * pow(g, 5.0) * 0.9;
	} else {
		// Comet tail: wide at the front, thin and gone at the back.
		float t = sat((p.y + 1.0) / 2.0);
		float w = mix(0.75, 0.08, t);
		float g = 1.0 - smoothstep(0.0, w, abs(p.x));
		c = col.rgb * g * pow(1.0 - t, 1.5);
	}
	ALBEDO = c * col.a;
}
"""
	_danger_shader = Shader.new()
	_danger_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0, 0.12, 0.38, 1.0);
varying vec2 q;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	q = VERTEX.xy * 2.0;
}
void fragment() {
	float r = length(q) / (1.0 + 0.07 * sin(TIME * 14.0));
	float ang = atan(q.y, q.x);
	float sw = 0.5 + 0.5 * sin(ang * 2.0 - TIME * 10.0 + r * 10.0);
	float core = 1.0 - smoothstep(0.1, 0.34, r);
	float inner = 1.0 - smoothstep(0.54, 0.58, r);
	float ring = 1.0 - smoothstep(0.66, 0.70, r);
	float g = 1.0 - smoothstep(0.62, 1.0, r);
	vec3 body = mix(col.rgb, vec3(1.0, 0.62, 0.78), sw * 0.45 * (1.0 - smoothstep(0.2, 0.55, r)));
	body = mix(body, vec3(1.0, 0.97, 0.98), core);
	vec3 c = mix(vec3(0.05, 0.0, 0.03), body, inner);
	ALBEDO = mix(col.rgb, c, ring);
	ALPHA = max(ring, g * g * 0.65);
}
"""
	_danger_mat = ShaderMaterial.new()
	_danger_mat.shader = _danger_shader
	_danger_mat.set_shader_parameter("col", DANGER)
	_danger_mat.render_priority = 1


static func hero_mat(kind: int, col: Color, bill := false) -> ShaderMaterial:
	_shaders()
	var key := "%d%s%s" % [kind, col.to_html(), bill]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = _hero_shader
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("bill", bill)
	_mats[key] = m
	return m


## A soft pool of coloured light on the floor under a shot.
static func floor_mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if _floor_mats.has(key):
		return _floor_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = U.soft_circle()
	m.albedo_color = col
	_floor_mats[key] = m
	return m


static func _put(parent: Node3D, mesh: Mesh, mat: Material, size: Vector3, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = size
	mi.position = pos
	parent.add_child(mi)
	return mi


## Builds an undead orb on `p` (which faces the way it flies). `r` is about the size it
## hits. Returns the node that grows in when the shot appears.
static func danger(p: Projectile, r: float, height: float) -> Node3D:
	_shaders()
	var look := Node3D.new()
	p.add_child(look)
	var d := r * 1.35 / 0.70 * 2.0   # the dark edge sits a little outside what it hits
	_put(look, _card, _danger_mat, Vector3(d, d, 1.0))
	_put(p, _flat, hero_mat(K_TAIL, Color(DANGER.r, DANGER.g, DANGER.b, 0.85)), Vector3(r * 1.9, 1.0, r * 6.5), Vector3(0, 0, r * 3.0))
	_put(p, _flat, floor_mat(Color(1.0, 0.15, 0.4, 0.55)), Vector3(r * 5.0, 1.0, r * 5.0), Vector3(0, 0.05 - height, 0))
	return look


## Builds a hero shot on `p`. `kind` is "bolt", "wave", "axe", "orb" or "shard".
## Returns the glow that flashes big as the shot leaves (a muzzle flash) and settles.
static func hero(p: Projectile, kind: String, col: Color, size: float, height: float) -> Node3D:
	_shaders()
	var glow_col := Color(col.r, col.g, col.b, 0.75)
	var glow := 3.2
	match kind:
		"wave":
			col = col.lerp(Color(1.0, 0.78, 0.3), 0.55)   # a golden sword wave
			glow_col = Color(col.r, col.g, col.b, 0.6)
			_put(p, _flat, hero_mat(K_WAVE, col), Vector3(size * 7.0, 1.0, size * 3.4), Vector3(0, 0, size * 0.9))
			glow = 2.6
		"axe":
			_axe(p, size * 3.6)
			_put(p, _flat, hero_mat(K_AXE, Color(col.r, col.g, col.b, 0.9)), Vector3(size * 3.6, 1.0, size * 3.6))
			_put(p, _flat, hero_mat(K_TAIL, Color(col.r, col.g, col.b, 0.45)), Vector3(size * 2.6, 1.0, size * 6.0), Vector3(0, 0, size * 3.4))
			glow = 2.2
		"orb":
			_put(p, _card, hero_mat(K_ORB, col, true), Vector3(size * 4.4, size * 4.4, 1.0))
			_put(p, _flat, hero_mat(K_TAIL, Color(col.r, col.g, col.b, 0.7)), Vector3(size * 2.6, 1.0, size * 7.0), Vector3(0, 0, size * 3.6))
			glow = 0.0
		"shard":
			_put(p, _flat, hero_mat(K_BOLT, col), Vector3(size * 1.6, 1.0, size * 6.0), Vector3(0, 0, size * 6.0 * 0.41))
			glow = 2.0
		_:
			_put(p, _flat, hero_mat(K_BOLT, col), Vector3(size * 2.4, 1.0, size * 9.0), Vector3(0, 0, size * 9.0 * 0.41))
	_put(p, _flat, floor_mat(Color(col.r, col.g, col.b, 0.3)), Vector3(size * 5.0, 1.0, size * 5.0), Vector3(0, 0.05 - height, 0))
	if glow <= 0.0:
		return null
	return _put(p, _card, hero_mat(K_GLOW, glow_col, true), Vector3(size * glow, size * glow, 1.0))


static var _axe_scene: PackedScene
static var _axe_checked := false

## The Barbarian's real axe, laid flat and spinning (the shot turns `p.spin`).
static func _axe(p: Projectile, length: float) -> void:
	if not _axe_checked:
		_axe_checked = true
		_axe_scene = Art.get_model("Skeleton_Axe")
	if _axe_scene == null:
		return
	var spin := Node3D.new()
	p.add_child(spin)
	var lay := Node3D.new()
	lay.rotation.x = -PI / 2.0   # handle along the floor
	spin.add_child(lay)
	var axe := Art.place_prop(_axe_scene, lay, length)
	axe.position.y -= length * 0.6   # turn around a point near the head, like a real throw
	for m in axe.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.spin = spin
