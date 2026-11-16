class_name LookFx
## Version 172, the cosmetics upgrade: the moving parts of a hero's looks.
##  - ring(): the Glow's ring of light on the floor (it was a flat coloured hoop). Every glow
##    has a soft halo and light running round it, and its own shape ("fx" in hero_style.gd):
##    flames, ice crystals, lightning, stars or runes.
##  - shell(): an Aura's column of light rising round the hero (an aura was a thin coloured
##    line and a few sparks).
##  - weapon(): a weapon's material: the Glow's colour running along it, or a finish (gold,
##    frost, ember, void: hero_style.gd "finish").
## Each is one small mesh and one shader, so a look costs a phone one or two draws.

const STYLES := {"flow": 0, "flame": 1, "frost": 2, "storm": 3, "stars": 4, "runes": 5}
const FINISHES := {"": 0, "gold": 1, "frost": 2, "ember": 3, "void": 4}

static var _ring_shader: Shader
static var _shell_shader: Shader
static var _weapon_shader: Shader
static var _weapon_mats := {}
static var _shell_mesh: CylinderMesh


## A glow's ring on the floor: `col` (and `col2`, which the light running round it turns
## to), drawn `radius` metres wide with the ring itself at `at` (0-1 of that).
static func ring(col: Color, col2: Variant, style: String, radius := 1.15, at := 0.48, power := 1.0) -> MeshInstance3D:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = RING
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	set_ring(m, col, col2, style)
	m.set_shader_parameter("r0", at)
	m.set_shader_parameter("power", power)
	var q := PlaneMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func set_ring(m: ShaderMaterial, col: Color, col2: Variant, style: String) -> void:
	var c2: Color = col2 if col2 is Color else col.lightened(0.45)
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("col2", c2)
	m.set_shader_parameter("style", int(STYLES.get(style, 0)))


## An aura's column of light: `kind` 0 = flames of light rising, 1 = bands winding up.
static func shell(ink: Color, ink2: Color, power := 1.0, kind := 0, radius := 0.82, height := 2.5) -> MeshInstance3D:
	if _shell_shader == null:
		_shell_shader = Shader.new()
		_shell_shader.code = SHELL
		_shell_mesh = CylinderMesh.new()
		_shell_mesh.top_radius = 0.72
		_shell_mesh.bottom_radius = 1.0
		_shell_mesh.height = 1.0
		_shell_mesh.radial_segments = 20
		_shell_mesh.rings = 1
		_shell_mesh.cap_top = false
		_shell_mesh.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = _shell_shader
	m.set_shader_parameter("ink", ink)
	m.set_shader_parameter("ink2", ink2)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("kind", kind)
	var mi := MeshInstance3D.new()
	mi.mesh = _shell_mesh
	mi.material_override = m
	mi.scale = Vector3(radius, height, radius)
	mi.position = Vector3(0, height * 0.5 + 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## How strong and which kind of column an aura gets: grander with the Mastery level it comes
## at; the Crypt King's, the event's and the top Race aura's are the strongest.
static func shell_for(aura: Dictionary) -> Array:
	var lv := int(aura.get("level", 12))
	var power := clampf(0.55 + (lv - 8) * 0.04, 0.55, 1.0)
	if aura.get("shine", false) or aura.get("sigil", false):
		power = 1.0
	var kind := 1 if str(aura.get("motif", "")) in ["stars", "arcane", "regal", "snow", "motes", "souls"] else 0
	return [power, kind]


## A weapon's material, from its own (`src`): `finish` ("" = as painted) and, when a Glow
## is worn, its colour running along the weapon.
static func weapon(src: BaseMaterial3D, finish: String, glow: Variant) -> ShaderMaterial:
	var key := "%s %s %s" % [src.get_instance_id(), finish, glow]
	if _weapon_mats.has(key):
		return _weapon_mats[key]
	if _weapon_shader == null:
		_weapon_shader = Shader.new()
		_weapon_shader.code = WEAPON
	var m := ShaderMaterial.new()
	m.shader = _weapon_shader
	m.set_shader_parameter("tex", src.albedo_texture)
	m.set_shader_parameter("finish", int(FINISHES.get(finish, 0)))
	var g: Color = glow if glow is Color else Color.BLACK
	m.set_shader_parameter("glow", Color(g.r, g.g, g.b, 1.0 if glow is Color else 0.0))
	_weapon_mats[key] = m
	return m


const NOISE := """
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
// (wraps every `wrap` cells along x, so a ring or a column has no seam)
float vnoise2(vec2 p, float wrap) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, wrap);
	float x1 = mod(i.x + 1.0, wrap);
	return mix(mix(hash2(vec2(x0, i.y)), hash2(vec2(x1, i.y)), f.x),
		mix(hash2(vec2(x0, i.y + 1.0)), hash2(vec2(x1, i.y + 1.0)), f.x), f.y);
}
"""

const RING := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform vec4 col2 : source_color = vec4(1.0);
uniform int style = 0;
uniform float r0 = 0.48;
uniform float power = 1.0;
""" + NOISE + """
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float a = ang / 6.2831853 + 0.5;
	float t = TIME;
	// The ring, a soft halo either side of it, and two arcs of brighter light running round.
	float flow = pow(0.5 + 0.5 * sin(ang * 2.0 - t * 2.4), 3.0);
	float core = smoothstep(0.05, 0.02, abs(r - r0));
	float halo = exp(-abs(r - r0) * 10.0) * 0.5;
	float fill = (1.0 - smoothstep(0.0, r0, r)) * 0.0 + smoothstep(r0, r0 * 0.35, r) * 0.0;
	vec3 c = mix(col.rgb, col2.rgb, flow * 0.8);
	float alpha = core * (0.82 + 0.18 * flow) + halo * (0.45 + 0.55 * flow) + fill;
	float extra = 0.0;
	vec3 ec = col2.rgb;
	float d = r - r0;
	if (style == 0) {
		// Light: a thin second ring just outside, breathing.
		extra = smoothstep(0.018, 0.0, abs(d - 0.13)) * (0.35 + 0.3 * sin(t * 2.0));
	} else if (style == 1) {
		// Flames licking outward.
		float h = vnoise2(vec2(a * 16.0, t * 1.7), 16.0) * 0.65 + vnoise2(vec2(a * 32.0, t * 2.9 + 7.0), 32.0) * 0.35;
		h = 0.08 + h * 0.36;
		float k = clamp(d / h, 0.0, 1.0);
		extra = step(0.0, d) * (1.0 - smoothstep(0.55, 1.0, k));
		ec = mix(col2.rgb * 1.15, col.rgb, k);
	} else if (style == 2) {
		// Ice: crystals standing out of the ring, glinting one after another.
		float n = 11.0;
		float id = floor(a * n);
		float seg = fract(a * n);
		float len = 0.12 + 0.2 * hash2(vec2(id, 3.0));
		float w = 1.0 - abs(seg - 0.5) * 2.0;
		float k = d / len;
		extra = step(0.0, d) * step(k, w) * (0.7 + 0.3 * sin(t * 2.6 + id * 1.7));
		ec = mix(vec3(1.0), col.rgb, clamp(k, 0.0, 1.0) * 0.8);
	} else if (style == 3) {
		// Lightning: arcs jumping round the outside.
		float tick = floor(t * 12.0);
		float j = vnoise2(vec2(a * 44.0, tick), 44.0) - 0.5;
		float on = step(0.5, vnoise2(vec2(a * 6.0, floor(t * 6.0)), 6.0));
		extra = smoothstep(0.028, 0.0, abs(d - 0.13 - j * 0.14)) * on;
		ec = mix(col2.rgb, vec3(1.0), 0.55);
	} else if (style == 4) {
		// Stars: six glints circling the ring, twinkling.
		float n = 6.0;
		float s = fract(a * n + t * 0.07);
		float id = floor(a * n + t * 0.07);
		float x = (s - 0.5) * 6.2831853 / n * r;
		float y = d - 0.19;
		float g = exp(-abs(x) * 60.0) * exp(-abs(y) * 14.0) + exp(-abs(y) * 60.0) * exp(-abs(x) * 14.0);
		extra = clamp(g * 1.6, 0.0, 1.0) * (0.55 + 0.45 * sin(t * 4.0 + id * 2.1));
		ec = mix(col2.rgb, vec3(1.0), 0.5);
	} else {
		// Runes: a ring of marks turning the other way inside a thin outer line.
		float seg = fract(a * 14.0 + t * 0.05);
		float id = floor(a * 14.0 + t * 0.05);
		float mark = smoothstep(0.05, 0.03, abs(d - 0.16)) * step(seg, 0.3 + 0.4 * hash2(vec2(id, 1.0)));
		extra = mark * (0.6 + 0.4 * sin(t * 2.0 + id)) + smoothstep(0.014, 0.0, abs(d - 0.27)) * 0.6;
	}
	alpha *= 1.0 - extra * 0.0;
	float total = clamp(alpha + extra * 0.9, 0.0, 0.96);
	ALBEDO = mix(c, ec, clamp(extra / max(alpha + extra, 0.001), 0.0, 1.0)) * 1.2;
	ALPHA = total * power * smoothstep(1.0, 0.92, r);
}
"""

const SHELL := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 ink : source_color = vec4(1.0);
uniform vec4 ink2 : source_color = vec4(1.0);
uniform float power = 1.0;
uniform int kind = 0;
""" + NOISE + """
void fragment() {
	// Bright where the column turns away from the eye (its edges), faint where it faces it,
	// so the hero inside is never covered.
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	float y = clamp(1.0 - UV.y * 2.0, 0.0, 1.0);   // 0 at the floor, 1 at the top
	float t = TIME;
	float a = 0.0;
	if (kind == 0) {
		float n = vnoise2(vec2(UV.x * 12.0, y * 3.2 - t * 1.5), 12.0) * 0.6 + vnoise2(vec2(UV.x * 24.0, y * 6.5 - t * 2.4), 24.0) * 0.4;
		a = smoothstep(0.3, 0.75, n + (1.0 - y) * 0.42) * (1.0 - smoothstep(0.35, 1.0, y + (1.0 - n) * 0.45));
	} else {
		float band = pow(0.5 + 0.5 * sin((UV.x * 3.0 + y * 1.6) * 6.2831853 - t * 2.2), 5.0);
		float n = vnoise2(vec2(UV.x * 16.0, y * 4.0 - t * 0.8), 16.0);
		a = (band * 0.85 + n * 0.25) * (1.0 - smoothstep(0.45, 1.0, y));
	}
	a *= smoothstep(0.0, 0.06, y);
	vec3 c = mix(ink.rgb, ink2.rgb, clamp(y * 1.3, 0.0, 1.0));
	// (As alpha, not as a darker colour: on the pedestal's see-through picture a black pixel
	// with full alpha would paint a dark box behind the hero.)
	ALBEDO = c;
	ALPHA = clamp(a * (0.28 + 0.9 * fres) * power * 1.9, 0.0, 1.0);
}
"""

const WEAPON := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform int finish = 0;
uniform vec4 glow : source_color = vec4(0.0);
varying vec3 mpos;

void vertex() {
	mpos = VERTEX;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float twinkle(vec3 p, float rare, float speed) {
	vec3 cell = floor(p);
	float h = hash3(cell);
	float d = length(fract(p) - 0.5);
	return step(1.0 - rare, h) * (1.0 - smoothstep(0.0, 0.26, d)) * (0.45 + 0.55 * sin(TIME * speed + h * 40.0));
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// A gleam running along the weapon every couple of seconds.
	float along = mpos.y + mpos.z * 0.6 + mpos.x * 0.3;
	float sweep = pow(max(0.0, sin(along * 2.2 - TIME * 2.6)), 16.0);
	vec3 al = c;
	vec3 em = vec3(0.0);
	float ro = 0.5;
	float me = 0.0;
	if (finish == 1) {
		// Gilded: polished gold, a warm edge and a white gleam.
		al = mix(vec3(0.6, 0.36, 0.08), vec3(1.0, 0.84, 0.4), smoothstep(0.1, 0.75, lum));
		me = 0.75;
		ro = 0.24;
		em = vec3(1.0, 0.72, 0.26) * (0.16 + edge * 0.7) + vec3(1.0, 0.96, 0.8) * (sweep * 1.1 + twinkle(mpos * 7.0 + floor(TIME * 2.0) * 0.31, 0.07, 6.0) * 2.0);
	} else if (finish == 2) {
		// Frostforged: clear blue ice, cut in facets, frost light at the edges and glints.
		vec3 r = mpos * 5.0;
		float facet = abs(fract(r.x + r.y * 0.57) - 0.5) + abs(fract(r.y - r.z * 0.57) - 0.5);
		float line = 1.0 - smoothstep(0.03, 0.1, abs(facet - 0.5));
		al = mix(vec3(0.2, 0.48, 0.85), vec3(0.88, 0.97, 1.0), smoothstep(0.1, 0.75, lum));
		al = mix(al, vec3(1.0), line * 0.45);
		me = 0.25;
		ro = 0.14;
		em = vec3(0.35, 0.78, 1.0) * (0.22 + edge * 1.0 + line * 0.25) + vec3(1.0) * (twinkle(mpos * 9.0 + floor(TIME * 2.0) * 0.37, 0.09, 6.0) * 2.4 + sweep * 0.6);
	} else if (finish == 3) {
		// Emberforged: black iron split by cracks of molten light that breathe.
		float n = vnoise(mpos * 5.5) * 0.65 + vnoise(mpos * 11.0) * 0.35;
		float crack = 1.0 - smoothstep(0.015, 0.06, abs(n - 0.5));
		float pulse = 0.75 + 0.25 * sin(TIME * 2.4 + along * 3.0);
		al = mix(vec3(0.05, 0.04, 0.05), vec3(0.26, 0.2, 0.2), lum);
		al = mix(al, vec3(1.0, 0.45, 0.1), crack * 0.85);
		me = 0.55;
		ro = 0.38;
		em = vec3(1.0, 0.36, 0.04) * (crack * 1.5 * pulse + edge * 0.55) + vec3(1.0, 0.85, 0.5) * sweep * 0.5;
	} else if (finish == 4) {
		// Voidsteel: night-violet metal with stars inside it and a violet edge.
		float n = vnoise(mpos * 2.4 + vec3(TIME * 0.08, 0.0, 0.0));
		vec3 neb = mix(vec3(0.3, 0.12, 0.6), vec3(0.12, 0.4, 0.8), n);
		float st = twinkle(mpos * 8.0, 0.2, 3.0) + twinkle(mpos * 13.0 + 3.1, 0.12, 4.5) * 0.7;
		al = mix(vec3(0.05, 0.03, 0.12), vec3(0.3, 0.17, 0.52), lum) + neb * 0.2;
		me = 0.5;
		ro = 0.26;
		em = neb * 0.3 + vec3(0.62, 0.34, 1.0) * edge * 1.1 + vec3(1.0, 0.95, 0.9) * st * 2.6 + vec3(0.8, 0.6, 1.0) * sweep * 0.6;
	}
	if (glow.a > 0.5) {
		// The Glow worn: its colour at the weapon's edges and in the gleam.
		float k = finish == 0 ? 1.0 : 0.35;
		em += glow.rgb * (0.07 + edge * 0.95 + sweep * 0.9) * k;
	}
	ALBEDO = al;
	ROUGHNESS = ro;
	METALLIC = me;
	EMISSION = em;
}
"""
