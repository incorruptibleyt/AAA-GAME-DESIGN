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
static var _danger_mats := {}

## Version 370 (visual review fix 4): what sits in the middle of an undead shot. Every one
## keeps the pink edge, glow and floor light, so danger still reads at a glance; the middle
## and the tail tell you what was shot. The numbers are the shader's `kind`.
const SHOT_KIND := {"arrow": 1, "bone": 2, "ice": 3, "fire": 4, "water": 5, "spore": 6, "moon": 7, "sand": 8,
	"crystal": 9, "ink": 10, "gear": 11, "star": 12, "dart": 13, "snow": 14,
	# Version 371: each boss its own.
	"crown": 15, "magma": 16, "skull": 17, "hex": 18, "wisp": 19, "trident": 20, "bat": 21, "quill": 22}
## The comet tail behind each (the plain orb's is the danger pink).
const SHOT_TAIL := {"arrow": Color(1.0, 0.45, 0.55), "bone": Color(1.0, 0.5, 0.6), "ice": Color(0.4, 0.75, 1.0),
	"fire": Color(1.0, 0.45, 0.1), "water": Color(0.15, 0.8, 0.9), "spore": Color(0.55, 1.0, 0.25),
	"moon": Color(1.0, 0.2, 0.15), "sand": Color(1.0, 0.72, 0.3), "crystal": Color(0.7, 0.4, 1.0),
	"ink": Color(0.5, 0.35, 1.0), "gear": Color(1.0, 0.6, 0.2), "star": Color(0.75, 0.8, 1.0),
	"dart": Color(1.0, 0.75, 0.35), "snow": Color(0.7, 0.9, 1.0),
	"crown": Color(1.0, 0.7, 0.2), "magma": Color(1.0, 0.4, 0.05), "skull": Color(0.45, 1.0, 0.8),
	"hex": Color(0.7, 0.4, 1.0), "wisp": Color(0.3, 0.85, 1.0), "trident": Color(0.2, 0.85, 0.85),
	"bat": Color(1.0, 0.15, 0.2), "quill": Color(0.6, 0.5, 1.0)}
## What a Bone Spitter spits in each place (in the order of Floors.THEMES).
## Shots that are fire and fly as streaks of flame.
const FLAMING := ["fire", "magma"]
const PLACE_SHOT := ["bone", "ice", "fire", "water", "spore", "moon", "snow", "sand", "crystal", "ink", "gear", "star"]


## The shot of the place the run is in.
static func place_shot() -> String:
	return PLACE_SHOT[clampi(Floors.index(Game.floor_num), 0, PLACE_SHOT.size() - 1)]


## The orb's card for a style ("" = the plain orb).
static func danger_mat(style: String) -> ShaderMaterial:
	_shaders()
	if not SHOT_KIND.has(style):
		return _danger_mat
	if not _danger_mats.has(style):
		var m := ShaderMaterial.new()
		m.shader = _danger_shader
		m.set_shader_parameter("col", DANGER)
		m.set_shader_parameter("kind", SHOT_KIND[style])
		m.set_shader_parameter("glowc", SHOT_TAIL.get(style, DANGER))
		m.render_priority = 1
		_danger_mats[style] = m
	return _danger_mats[style]
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
uniform vec4 glowc : source_color = vec4(1.0, 0.12, 0.38, 1.0);
uniform int kind = 0;
varying vec2 q;
varying vec2 fdir;
void vertex() {
	// (which way the shot flies, as the screen sees it, so its shape points that way)
	vec3 f = (VIEW_MATRIX * vec4(-MODEL_MATRIX[2].xyz, 0.0)).xyz;
	fdir = normalize(f.xy + vec2(0.0, 0.0001));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	q = VERTEX.xy * 2.0;
}
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}
vec2 turn(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}
void fragment() {
	float r = length(q) / (1.0 + 0.07 * sin(TIME * 14.0));
	float inner = 1.0 - smoothstep(0.54, 0.58, r);
	float ring = 1.0 - smoothstep(0.66, 0.70, r);
	float g = 1.0 - smoothstep(0.62, 1.0, r);
	vec3 dark = vec3(0.05, 0.0, 0.03);
	if (kind == 0) {
		float ang0 = atan(q.y, q.x);
		float sw = 0.5 + 0.5 * sin(ang0 * 2.0 - TIME * 10.0 + r * 10.0);
		float core = 1.0 - smoothstep(0.1, 0.34, r);
		vec3 body = mix(col.rgb, vec3(1.0, 0.62, 0.78), sw * 0.45 * (1.0 - smoothstep(0.2, 0.55, r)));
		body = mix(body, vec3(1.0, 0.97, 0.98), core);
		vec3 c0 = mix(dark, body, inner);
		ALBEDO = mix(col.rgb, c0, ring);
		ALPHA = max(ring, g * g * 0.65);
	} else {
		// Version 370: the pink edge stays, the middle is the shot's own shape. `u` is
		// the card turned so +y is the way the shot flies; `d` is how far outside the
		// shape a point is, `mc` the shape's colour and `bg` the middle behind it.
		vec2 Q = q * 0.82;
		vec2 u = vec2(Q.x * fdir.y - Q.y * fdir.x, dot(Q, fdir));
		float rr = length(u);
		float ang = atan(u.y, u.x);
		float d = 1.0;
		vec3 mc = vec3(1.0);
		vec3 bg = vec3(0.16, 0.0, 0.07);
		if (kind == 1) {
			// Arrow: shaft, steel head, pink feathers. Longer than the orb.
			float shaft = seg(u, vec2(0.0, -0.8), vec2(0.0, 0.5)) - 0.05;
			float head = max((abs(u.x) - 0.3 * (0.98 - u.y) / 0.5) * 0.85, 0.48 - u.y);
			vec2 fa = vec2(abs(u.x), u.y);
			float fl = min(seg(fa, vec2(0.0, -0.44), vec2(0.2, -0.66)), seg(fa, vec2(0.0, -0.66), vec2(0.2, -0.88))) - 0.045;
			d = min(shaft, min(head, fl));
			mc = head <= d ? vec3(0.9, 0.96, 1.0) : (fl <= d ? vec3(1.0, 0.5, 0.68) : vec3(1.0, 0.84, 0.5));
		} else if (kind == 2) {
			// Bone: a little bone, tumbling.
			vec2 b = turn(u, TIME * 7.0);
			d = seg(b, vec2(-0.24, 0.0), vec2(0.24, 0.0)) - 0.08;
			d = min(d, length(vec2(abs(b.x) - 0.3, abs(b.y) - 0.1)) - 0.125);
			mc = vec3(1.0, 0.94, 0.78);
			bg = vec3(0.2, 0.01, 0.1);
		} else if (kind == 3) {
			// Ice: a long shard with two small ones beside it.
			d = (abs(u.x) / 0.2 + abs(u.y - 0.04) / 0.5 - 1.0) * 0.18;
			d = min(d, (abs(abs(u.x) - 0.31) / 0.1 + abs(u.y + 0.14) / 0.26 - 1.0) * 0.09);
			mc = u.x > 0.0 ? vec3(0.95, 1.0, 1.0) : vec3(0.4, 0.78, 1.0);
			bg = vec3(0.01, 0.06, 0.3);
		} else if (kind == 4) {
			// Fire (Version 379): a blazing head trailing a long licking flame, not a badge.
			vec2 h = u - vec2(0.0, 0.32);
			float t = clamp(-h.y / 1.05, 0.0, 1.0);
			float wob = (sin(u.y * 11.0 + TIME * 22.0) * 0.06 + sin(u.y * 23.0 - TIME * 31.0) * 0.025) * t;
			d = h.y > 0.0 ? length(h) - 0.27 : abs(u.x + wob) - 0.27 * (1.0 - t) * (1.0 - 0.35 * t);
			d = max(d, -0.8 - u.y);
			mc = mix(vec3(1.0, 0.97, 0.7), vec3(1.0, 0.55, 0.06), smoothstep(0.02, 0.3, length(h * vec2(1.3, 0.55))));
			mc = mix(mc, vec3(0.85, 0.12, 0.02), smoothstep(0.45, 1.0, t));
			bg = vec3(0.26, 0.01, 0.0);
		} else if (kind == 5) {
			// Water: a drop with a glint and two small bubbles behind.
			d = length(u - vec2(0.0, 0.1)) - 0.3;
			d = min(d, length(u - vec2(-0.2, -0.36)) - 0.09);
			d = min(d, length(u - vec2(0.17, -0.42)) - 0.06);
			mc = mix(vec3(0.85, 1.0, 1.0), vec3(0.05, 0.75, 0.95), smoothstep(0.06, 0.12, length(u - vec2(-0.1, 0.2))));
			bg = vec3(0.0, 0.07, 0.22);
		} else if (kind == 6) {
			// Spore: a puff with six seeds going round it.
			vec2 sp = turn(u, TIME * 2.0);
			float a6 = mod(atan(sp.y, sp.x), TAU / 6.0) - TAU / 12.0;
			d = min(rr - 0.2, length(rr * vec2(cos(a6), sin(a6)) - vec2(0.38, 0.0)) - 0.085);
			mc = vec3(0.66, 1.0, 0.2);
			bg = vec3(0.02, 0.14, 0.04);
		} else if (kind == 7) {
			// Moon: a crescent, horns behind.
			d = max(rr - 0.42, 0.34 - length(u - vec2(0.0, -0.2)));
			mc = vec3(1.0, 0.93, 0.76);
			bg = vec3(0.3, 0.0, 0.02);
		} else if (kind == 8) {
			// Sand: a turning swirl.
			float sw8 = sin(ang * 2.0 + rr * 12.0 - TIME * 7.0);
			d = min(max(rr - 0.5, (0.15 - sw8) * 0.08), rr - 0.1);
			mc = vec3(1.0, 0.78, 0.3);
			bg = vec3(0.22, 0.1, 0.01);
		} else if (kind == 9) {
			// Crystal: a cut gem.
			vec2 a9 = abs(vec2(u.x, u.y * 0.78));
			d = max(a9.x, a9.x * 0.5 + a9.y * 0.866) - 0.3;
			mc = mix(vec3(0.6, 0.32, 1.0), vec3(1.0, 0.9, 1.0), step(0.0, u.x) * 0.55 + step(0.1, u.y) * 0.45);
			bg = vec3(0.1, 0.01, 0.24);
		} else if (kind == 10) {
			// Ink: a black blot on a round of parchment.
			d = rr - (0.25 + 0.08 * sin(ang * 5.0 + TIME * 3.0) + 0.04 * sin(ang * 9.0 - TIME * 5.0));
			d = min(d, length(u - vec2(0.3, -0.28)) - 0.06);
			d = min(d, length(u - vec2(-0.33, 0.2)) - 0.05);
			mc = mix(vec3(0.015, 0.0, 0.05), vec3(0.4, 0.25, 0.9), 1.0 - smoothstep(0.0, 0.1, length(u - vec2(-0.08, 0.1))));
			bg = vec3(0.86, 0.72, 0.45);
		} else if (kind == 11) {
			// Gear: a brass cog, turning.
			vec2 gq = turn(u, TIME * 4.0);
			d = max(rr - (0.32 + 0.1 * smoothstep(-0.3, 0.3, sin(atan(gq.y, gq.x) * 8.0))), 0.11 - rr);
			mc = vec3(1.0, 0.66, 0.18);
			bg = vec3(0.1, 0.05, 0.01);
		} else if (kind == 12) {
			// Star: four points, slowly turning.
			vec2 a12 = abs(turn(u, TIME * 1.5)) + 0.0001;
			d = (pow(a12.x, 0.6) + pow(a12.y, 0.6) - pow(0.52, 0.6)) * 0.4;
			mc = vec3(1.0, 0.98, 0.72);
			bg = vec3(0.07, 0.0, 0.16);
		} else if (kind == 13) {
			// Bone dart: one long spike.
			float w = u.y > 0.35 ? 0.2 * (0.98 - u.y) / 0.63 : 0.2 * (u.y + 0.9) / 1.25;
			d = (abs(u.x) - w) * 0.9;
			mc = mix(vec3(1.0, 0.8, 0.36), vec3(1.0, 1.0, 0.88), 1.0 - smoothstep(0.0, 0.07, abs(u.x)));
			bg = vec3(0.2, 0.07, 0.0);
		} else if (kind == 14) {
			// Snow: a six-armed flake, slowly turning.
			vec2 sn = turn(u, TIME * 1.2);
			float a14 = mod(atan(sn.y, sn.x) + TAU / 12.0, TAU / 6.0) - TAU / 12.0;
			vec2 fs = rr * vec2(cos(a14), abs(sin(a14)));
			d = min(seg(fs, vec2(0.0), vec2(0.46, 0.0)) - 0.045, seg(fs, vec2(0.27, 0.0), vec2(0.39, 0.11)) - 0.035);
			mc = vec3(0.95, 1.0, 1.0);
			bg = vec3(0.03, 0.22, 0.5);
		} else if (kind == 15) {
			// Version 371, the bosses. Crown (the Skeleton King): a gold band, three points, a
			// red gem. Upright on the screen whichever way it flies.
			float top = 0.34 - 1.4 * abs(mod(Q.x + 0.15, 0.3) - 0.15);
			d = max(max(abs(Q.x) - 0.34, -0.28 - Q.y), (Q.y - top) * 0.55);
			mc = mix(vec3(1.0, 0.1, 0.12), vec3(1.0, 0.78, 0.2), smoothstep(0.05, 0.08, length(Q - vec2(0.0, -0.14))));
			bg = vec3(0.16, 0.0, 0.1);
		} else if (kind == 16) {
			// Magma (the Cinder Colossus): a lump of black rock with glowing cracks.
			d = rr - 0.43 - 0.035 * sin(ang * 5.0 + 1.0);
			float crack = min(abs(sin(u.x * 5.0 + sin(u.y * 6.0) * 1.3 + 0.5)), abs(sin(u.y * 4.5 + sin(u.x * 7.0) * 1.1 + 1.2)));
			mc = mix(vec3(1.0, 0.75, 0.15), vec3(0.2, 0.09, 0.06), smoothstep(0.06, 0.2, crack));
			bg = vec3(0.55, 0.1, 0.0);
		} else if (kind == 17) {
			// Skull (the Lich's souls): upright on the screen whichever way it drifts.
			d = min(length(Q - vec2(0.0, 0.08)) - 0.3, max(abs(Q.x) - 0.17, max(Q.y - 0.0, -0.36 - Q.y)));
			float eyes = min(length(vec2(abs(Q.x) - 0.12, Q.y - 0.05)) - 0.085, max(abs(Q.x) - 0.025, abs(Q.y + 0.13) - 0.05));
			eyes = min(eyes, max(abs(abs(Q.x) - 0.075) - 0.012, abs(Q.y + 0.3) - 0.06));
			mc = mix(vec3(0.02, 0.1, 0.1), vec3(0.8, 1.0, 0.9), smoothstep(-0.01, 0.015, eyes));
			bg = vec3(0.0, 0.14, 0.13);
		} else if (kind == 18) {
			// Hex (the Lich's bolts): a violet eye with a slit, across the way it flies.
			d = max(length(u - vec2(0.0, 0.3)), length(u + vec2(0.0, 0.3))) - 0.52;
			mc = mix(vec3(0.03, 0.0, 0.08), mix(vec3(1.0, 0.92, 1.0), vec3(0.72, 0.38, 1.0), smoothstep(0.08, 0.2, rr)),
				smoothstep(0.035, 0.06, max(abs(u.x), abs(u.y) - 0.13)));
			bg = vec3(0.1, 0.0, 0.2);
		} else if (kind == 19) {
			// Wisp (the Lich's spirals): a cold ghost flame with two eyes.
			vec2 hw = u - vec2(0.0, 0.14);
			float tw = clamp(-hw.y / 0.66, 0.0, 1.0);
			float wobw = sin(u.y * 11.0 + TIME * 14.0) * 0.08 * tw;
			d = hw.y > 0.0 ? length(hw) - 0.3 : abs(u.x + wobw) - 0.3 * (1.0 - tw * tw);
			d = max(d, -0.54 - u.y);
			mc = mix(vec3(0.0, 0.08, 0.14), mix(vec3(0.9, 1.0, 1.0), vec3(0.2, 0.85, 1.0), smoothstep(0.0, 0.5, -hw.y + 0.1)),
				smoothstep(0.065, 0.09, length(vec2(abs(u.x) - 0.12, u.y - 0.2))));
			bg = vec3(0.0, 0.08, 0.18);
		} else if (kind == 20) {
			// Trident (the Tidecaller): three prongs first.
			vec2 ta = vec2(abs(u.x), u.y);
			d = min(seg(u, vec2(0.0, -0.5), vec2(0.0, 0.52)), min(seg(ta, vec2(0.27, 0.0), vec2(0.27, 0.42)), seg(ta, vec2(0.0, 0.0), vec2(0.27, 0.0)))) - 0.06;
			mc = vec3(0.65, 1.0, 0.92);
			bg = vec3(0.0, 0.1, 0.24);
		} else if (kind == 21) {
			// Bat (the Blood Moon Queen): black wings across a pale moon.
			float ba = abs(u.x);
			d = max(ba - 0.5, max(u.y - (0.2 - 0.3 * ba), (-0.2 + 0.5 * ba + 0.1 * abs(sin(ba * TAU * 2.0)) - u.y)) * 0.8);
			d = min(d, min(length(u - vec2(0.0, 0.14)) - 0.12, length(vec2(ba - 0.08, u.y - 0.27)) - 0.05));
			mc = mix(vec3(1.0, 0.1, 0.1), vec3(0.03, 0.0, 0.02), smoothstep(0.02, 0.035, length(vec2(ba - 0.05, u.y - 0.15))));
			bg = vec3(0.8, 0.5, 0.42);
		} else {
			// Quill (the Ink Double): a white feather, black nib first. Longer than the orb.
			float tq = clamp((u.y + 0.85) / 1.25, 0.0, 1.0);
			float feather = max(abs(u.x) - 0.24 * sin(tq * PI) * (0.55 + 0.45 * tq), max(-0.85 - u.y, u.y - 0.4));
			float nib = max((abs(u.x) - 0.09 * (0.95 - u.y) / 0.55) * 0.9, 0.4 - u.y);
			d = min(feather, nib);
			mc = nib <= d ? vec3(0.02, 0.0, 0.06) : mix(vec3(0.55, 0.4, 0.95), vec3(0.96, 0.96, 1.0), smoothstep(0.015, 0.04, abs(u.x)));
			bg = vec3(0.07, 0.03, 0.2);
		}
		// Version 379 (visual review of 375, fix 4): no round badge behind it any more, so it
		// reads as a thing flying, not a menu icon. The shape keeps a dark line, then a band of
		// the danger pink that hugs the shape, then a glow in the shot's own colour.
		float fill = 1.0 - smoothstep(-0.012, 0.012, d);
		float line = 1.0 - smoothstep(0.03, 0.05, d);
		float rim = 1.0 - smoothstep(0.1, 0.125, d);
		float edge = 1.0 - smoothstep(0.8, 1.0, length(q));
		float halo = exp(-max(d, 0.0) * 7.0) * 0.85 * edge;
		vec3 c = mix(glowc.rgb, col.rgb, rim);
		c = mix(c, dark, line);
		ALBEDO = mix(c, mc, fill);
		ALPHA = max(max(rim, halo), fill) * edge;
	}
}
"""
	_danger_mat = ShaderMaterial.new()
	_danger_mat.shader = _danger_shader
	_danger_mat.set_shader_parameter("col", DANGER)
	_danger_mat.render_priority = 1


static var _volley_shader: Shader
static var _volley_mats := {}

## The dark blade inside a Shadow Volley knife (drawn over the glow, not added to it).
static func _volley_mat(col: Color) -> ShaderMaterial:
	var key := col.to_html()
	if _volley_mats.has(key):
		return _volley_mats[key]
	if _volley_shader == null:
		_volley_shader = Shader.new()
		_volley_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 rim : source_color = vec4(0.8, 0.5, 1.0, 1.0);
varying vec2 q;
void vertex() { q = VERTEX.xz * 2.0; }
void fragment() {
	vec2 p = q;   // -y is the way it flies: the point is at the front
	float y = p.y;
	float w = y < -0.3 ? 0.9 * (y + 1.0) / 0.7 : 0.9 * (0.75 - y) / 1.05;
	w = max(w, 0.0);
	float ax = abs(p.x);
	float inside = 1.0 - smoothstep(w - 0.12, w, ax);
	float deep = smoothstep(0.1, 0.65, (w - ax) / max(w, 0.01));
	vec3 dark = vec3(0.17, 0.04, 0.3);
	vec3 edge = mix(rim.rgb, vec3(1.0), 0.35);
	ALBEDO = mix(edge, dark, deep);
	ALPHA = inside * step(-1.0, y) * step(y, 0.75);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _volley_shader
	m.set_shader_parameter("rim", col)
	m.render_priority = 2
	_volley_mats[key] = m
	return m


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
## hits, `style` what is in its middle (see SHOT_KIND; "" = the plain orb). Returns the node that grows in when the shot appears.
static func danger(p: Projectile, r: float, height: float, style := "") -> Node3D:
	_shaders()
	var look := Node3D.new()
	p.add_child(look)
	var d := r * 1.35 / 0.70 * 2.0   # the dark edge sits a little outside what it hits
	_put(look, _card, danger_mat(style), Vector3(d, d, 1.0))
	var tail: Color = SHOT_TAIL.get(style, DANGER)
	if style in FLAMING:
		# Version 379: fire flies as a streak of flame, a long bright trail and a glow round
		# its head that lights what it passes, instead of a little picture.
		_put(p, _flat, hero_mat(K_TAIL, Color(tail.r, tail.g, tail.b, 1.0)), Vector3(r * 2.4, 1.0, r * 10.0), Vector3(0, 0, r * 4.6))
		_put(p, _flat, hero_mat(K_TAIL, Color(1.0, 0.85, 0.4, 0.8)), Vector3(r * 1.0, 1.0, r * 6.0), Vector3(0, 0, r * 2.6))
		_put(look, _card, hero_mat(K_GLOW, Color(tail.r, tail.g * 0.8, tail.b, 0.7), true), Vector3(d * 1.25, d * 1.25, 1.0))
	else:
		_put(p, _flat, hero_mat(K_TAIL, Color(tail.r, tail.g, tail.b, 0.85)), Vector3(r * 1.9, 1.0, r * 6.5), Vector3(0, 0, r * 3.0))
	_put(p, _flat, floor_mat(Color(1.0, 0.15, 0.4, 0.55)), Vector3(r * 5.0, 1.0, r * 5.0), Vector3(0, 0.05 - height, 0))
	return look


## Builds a hero shot on `p`. `kind` is "bolt", "wave", "axe", "orb" or "shard".
## Returns the glow that flashes big as the shot leaves (a muzzle flash) and settles.
static func hero(p: Projectile, kind: String, col: Color, size: float, _height: float) -> Node3D:
	_shaders()
	var glow_col := Color(col.r, col.g, col.b, 0.75)
	var glow := 3.2
	match kind:
		"wave":
			# (The Knight's own bolt colour is the gold of the wave: a mastery color shows as is.)
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
		"volley":
			# Version 386 (visual review of v383, fix 5): Shadow Volley's knives were all white
			# light. Now each is a dark purple blade with a bright violet edge, flying inside
			# the glow of the Rogue's colour, so a ring of them reads as knives, not sparks.
			_put(p, _flat, hero_mat(K_BOLT, col), Vector3(size * 3.0, 1.0, size * 9.0), Vector3(0, 0, size * 9.0 * 0.41))
			_put(p, _flat, _volley_mat(col), Vector3(size * 1.9, 1.0, size * 4.6))
			glow = 2.4
		_:
			_put(p, _flat, hero_mat(K_BOLT, col), Vector3(size * 2.4, 1.0, size * 9.0), Vector3(0, 0, size * 9.0 * 0.41))
	# (No pool of light on the floor under hero shots: a Mage with Twin Shots and Fan of Shots
	# has dozens in the air, and each pool was one more thing to draw. Undead shots keep theirs.)
	if glow <= 0.0:
		return null
	return _put(p, _card, hero_mat(K_GLOW, glow_col, true), Vector3(size * glow, size * glow, 1.0))


static var _axe_scene: PackedScene
static var _axe_checked := false
## One axe built (and sized to 1 m) the first time, then copied for every throw. Making a
## fresh model from the scene each shot was the Barbarian's slowest per-shot cost.
static var _axe_proto: Node3D
static var _axe_holder: Node3D

## The Barbarian's real axe, laid flat and spinning (the shot turns `p.spin`).
static func _axe(p: Projectile, length: float) -> void:
	if not _axe_checked:
		_axe_checked = true
		_axe_scene = Art.get_model("Skeleton_Axe")
		if _axe_scene != null:
			_axe_holder = Node3D.new()   # kept hidden under Game, so it's freed with the game
			_axe_holder.name = "AxeProto"
			_axe_holder.visible = false
			Game.add_child(_axe_holder)
			_axe_proto = Art.place_prop(_axe_scene, _axe_holder, 1.0)
			for m in _axe_proto.find_children("*", "GeometryInstance3D", true, false):
				(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _axe_proto == null:
		return
	var spin := Node3D.new()
	p.add_child(spin)
	var lay := Node3D.new()
	lay.rotation.x = -PI / 2.0   # handle along the floor
	spin.add_child(lay)
	var axe := _axe_proto.duplicate() as Node3D
	lay.add_child(axe)
	axe.scale = _axe_proto.scale * length
	axe.position = _axe_proto.position * length
	axe.position.y -= length * 0.6   # turn around a point near the head, like a real throw
	p.spin = spin
