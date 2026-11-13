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
## The room's mood (room_mood.gd): "plain", "shaft", "circle", "treasure", "champion",
## "approach" or "boss". `torch_k` dims the torches (the boss approach burns them low).
var mood := "plain"
var torch_k := 1.0

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
	var wall := _wall_material(look, U.mat(look.wall, 0.95))
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
	U.box(self, Vector3(HALF_W * 2 + t * 2, 0.5, t), _wall_material(look, _ledge_material(look)), Vector3(0, 0.25, HALF_L + t / 2))
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


static var _floor_shaders := {}

## Each crypt's floor is its own kind of place, drawn by one shader built a little
## differently for each ("floor_style" in Floors.THEMES, version 134):
## 0. Worn flagstones (the Drowned Vault, and the near ledge everywhere): uneven slabs in
##    staggered rows, grime in patches and along the walls, cracked and chipped slabs, now
##    and then an iron drain grate. A floor with "water" has shallow water in the low places
##    and the gaps, rippling and lit from below.
## 1. The Bone Crypt is an ossuary: polished dark stone panels framed by bands of bones laid
##    end to end like the links of a chain, a bone rosette where bands cross and a great
##    bone wheel in the middle of the room.
## 2. The Frozen Ossuary is thick dark ice in big plates with pale cracks between them,
##    frost drifting in from the walls, and old bones frozen deep inside, which slide as the
##    camera moves because they lie under the surface.
## 3. The Ember Catacomb stands on basalt: the tops of six-sided columns of black rock, each
##    at its own height, with fire glowing in the joints ("seams") where the rock is hot.
## 4. The Glowcap Grotto has no laid floor: dark earth under moss, with darker hollows, and
##    glowing fungus threads running through the ground with light pulsing along them, and
##    glowing caps in the moss ("spores").
## 5. The Blood Moon crypt (the event, events.gd): black marble diamonds with gold inlay,
##    veins of blood light throbbing with a heartbeat and the blood moon in the middle.
## Every style is darker by the walls, takes warm pools of light under the wall torches and
## a little in the middle, and deeper endless loops add blood. Everything is worked out from
## where the point is in the room, so there is no tiling pattern to spot.
static func _floor_material(look: Dictionary, style := -1) -> Material:
	if style < 0:
		style = int(look.get("floor_style", 0))
	if not _floor_shaders.has(style):
		var sh := Shader.new()
		sh.code = "shader_type spatial;\n#define STYLE %d\n" % style + FLOOR_CODE
		_floor_shaders[style] = sh
	var sm := ShaderMaterial.new()
	sm.shader = _floor_shaders[style]
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
	sm.set_shader_parameter("spores", look.get("spores", Color(0, 0, 0, 0)))
	sm.set_shader_parameter("spores2", look.get("spores2", Color(0.7, 1.0, 0.3)))
	sm.set_shader_parameter("half_size", Vector2(HALF_W, HALF_L))
	sm.set_shader_parameter("torch_glow", look.torch)
	sm.set_shader_parameter("torch_amount", look.get("pool", 1.5))
	return sm


const FLOOR_CODE := """
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
// Glowing fungus (the Glowcap Grotto): its colour (alpha = 0 for none) and the rarer second.
uniform vec4 spores = vec4(0.0);
uniform vec4 spores2 = vec4(0.7, 1.0, 0.3, 1.0);
uniform vec2 half_size = vec2(6.0, 10.0);
// The wall torches' warm light on the floor (no real light needed): their colour, and how
// strong (0 on the near ledge).
uniform vec4 torch_glow = vec4(1.0, 0.6, 0.3, 1.0);
uniform float torch_amount = 0.0;
// 1 on the near ledge's box: its front face takes the pattern from its own plane and
// keeps its real normal.
uniform float ledge = 0.0;
varying vec2 pos;
varying float up;

float h(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

// A bone lying along x, centred on the point: a shaft `len` long and `w` thick with a pair
// of knobs at each end. Below 0 is inside.
float bone(vec2 p, float len, float w) {
	float shaft = length(vec2(max(abs(p.x) - len * 0.5, 0.0), p.y)) - w;
	float knob = length(vec2(abs(p.x) - len * 0.5, abs(p.y) - w * 0.9)) - w * 1.3;
	return min(shaft, knob);
}

// The nearest hexagon (inner radius 0.5): xy = the point from its centre, zw = its id.
vec4 hex(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 c = floor(vec4(p, p - vec2(0.5, 1.0)) / s.xyxy) + 0.5;
	vec4 d = vec4(p - c.xy * s, p - (c.zw + 0.5) * s);
	return dot(d.xy, d.xy) < dot(d.zw, d.zw) ? vec4(d.xy, c.xy) : vec4(d.zw, c.zw + 0.5);
}

float hex_edge(vec2 d) {
	d = abs(d);
	return 0.5 - max(dot(d, vec2(0.5, 0.8660254)), d.x);
}

// Points scattered one per square: the distance to the nearest and the second nearest, and
// the nearest one's square.
vec2 cells(vec2 p, out vec2 id) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	id = i;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(h(i + g), h(i + g + 17.3)) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2);
}

void vertex() {
	up = NORMAL.y;
	pos = (ledge > 0.5 && abs(NORMAL.y) < 0.5) ? VERTEX.xy : VERTEX.xz;
}

void fragment() {
	float fine = texture(grain, pos * 0.23).r;
	float big = texture(blobs_a, pos * 0.05 + vec2(0.37, 0.11)).r;
	float big2 = texture(blobs_b, pos * 0.065 + vec2(0.71, 0.53)).r;
	// Darker by the walls (light does not reach the corners), a little by the low near ledge.
	float wall = min(half_size.x - abs(pos.x), pos.y + half_size.y);
	float shade = mix(0.5, 1.0, smoothstep(0.0, 2.4, wall)) * mix(0.8, 1.0, smoothstep(0.0, 1.2, half_size.y - pos.y));

	vec3 c = vec3(0.3);
	float rough = 0.85;
	vec3 n = vec3(0.0, 1.0, 0.0);
	float gap = 0.0;
	float crack = 0.0;
	float pit = 0.0;
	float bar = 0.0;
	float r = 0.0;
	vec3 em = vec3(0.0);

#if STYLE == 1
	const float P = 3.0;
	const float BW = 0.19;
	const vec3 MORTAR = vec3(0.1, 0.085, 0.08);
	const vec3 BRASS = vec3(0.5, 0.4, 0.25);
	vec2 q = pos / P + 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	vec2 e = (0.5 - abs(f)) * P;
	r = h(cell);
	// Polished stone with faint pale veins, each panel a little different.
	float vn = texture(grain, pos * 0.09 + vec2(r * 3.0, r)).r;
	float vein = 1.0 - smoothstep(0.0, 0.03 + fwidth(vn), abs(vn - 0.5));
	c = vec3(0.25, 0.235, 0.27) * (0.9 + 0.2 * r) * (0.95 + 0.1 * fine);
	c = mix(c, vec3(0.38, 0.36, 0.4), vein * 0.22);
	rough = 0.62;
	// Dust along the walls and in patches.
	float g = smoothstep(0.62, 0.9, big + (1.0 - smoothstep(0.0, 2.0, wall)) * 0.35) * grime_amount;
	c = mix(c, grime.rgb * (0.8 + 0.4 * fine), g * 0.6);
	rough = mix(rough, 0.9, g);
	// The bands of bones between the panels, sunk a little (a dark lip on the panel).
	float ed = min(e.x, e.y);
	float al = e.y < e.x ? pos.x : pos.y;
	float band = 1.0 - smoothstep(BW - 0.01, BW + 0.01, ed);
	c *= 1.0 - 0.3 * (1.0 - smoothstep(BW, BW + 0.09, ed));
	float slot = floor(al / 0.5);
	float bd = bone(vec2((fract(al / 0.5) - 0.5) * 0.5, ed), 0.31, 0.04);
	float bone_in = (1.0 - smoothstep(-0.006, 0.006, bd)) * band;
	vec3 ivory = vec3(0.66, 0.6, 0.49) * (0.86 + 0.22 * h(vec2(slot, cell.x * 3.0 + cell.y)));
	ivory *= 0.72 + 0.38 * smoothstep(0.0, -0.035, bd);
	float trim = 1.0 - smoothstep(0.01, 0.02, abs(ed - BW + 0.015));
	c = mix(c, MORTAR, band);
	c = mix(c, ivory, bone_in);
	c = mix(c, BRASS, trim);
	rough = mix(rough, 0.75, band);
	rough = mix(rough, 0.3, trim);
	// A rosette where four panels meet: a brass ring round a bone disc.
	vec2 lc = (q - floor(q + 0.5)) * P;
	float rd = length(lc);
	float aa = fwidth(rd);
	c = mix(c, MORTAR, 1.0 - smoothstep(0.3, 0.3 + aa, rd));
	c = mix(c, BRASS, 1.0 - smoothstep(0.012, 0.024, abs(rd - 0.27)));
	c = mix(c, vec3(0.66, 0.6, 0.49) * (0.7 + 0.4 * smoothstep(0.2, 0.0, rd)), 1.0 - smoothstep(0.17, 0.17 + aa, rd));
	c = mix(c, MORTAR, 1.0 - smoothstep(0.05, 0.05 + aa, rd));
	// The great wheel of bones in the middle of the room.
	float R = length(pos);
	if (R < 1.3) {
		float a = atan(pos.y, pos.x);
		const float N = 18.0;
		float sa = (fract(a / 6.2831853 * N) - 0.5) * 6.2831853 / N;
		float wb = bone(vec2(R - 0.9, R * sa), 0.34, 0.038);
		float ring = smoothstep(0.6, 0.61, R) * (1.0 - smoothstep(1.2, 1.21, R));
		c = mix(c, MORTAR, ring);
		c = mix(c, vec3(0.66, 0.6, 0.49) * (0.72 + 0.38 * smoothstep(0.0, -0.035, wb)), (1.0 - smoothstep(-0.006, 0.006, wb)) * ring);
		c = mix(c, BRASS, max(1.0 - smoothstep(0.012, 0.024, abs(R - 1.22)), 1.0 - smoothstep(0.012, 0.024, abs(R - 0.6))));
		c = mix(c, BRASS, (1.0 - smoothstep(0.01, 0.02, abs(R - 0.32))) * 0.8);
		rough = mix(rough, 0.7, ring);
	}
#elif STYLE == 2
	vec2 id;
	vec2 vd = cells(pos / 2.3, id);
	r = h(id);
	float pe = (vd.y - vd.x) * 2.3;
	c = vec3(0.1, 0.17, 0.25) * (0.88 + 0.24 * r) * (0.96 + 0.08 * fine);
	c = mix(c, vec3(0.2, 0.29, 0.37), smoothstep(0.35, 0.75, big) * 0.55);
	// Bones under the ice, seen through the surface: they slide as the view moves.
	vec3 wv = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec2 par = -wv.xz / max(wv.y, 0.3);
	float bones = 0.0;
	for (int k = 0; k < 2; k++) {
		float depth = k == 0 ? 0.3 : 0.75;
		float cs = k == 0 ? 1.6 : 2.2;
		vec2 bp = (pos + par * depth) / cs + vec2(float(k) * 7.3, float(k) * 3.1);
		vec2 bc = floor(bp);
		vec2 bl = (fract(bp) - 0.5) * cs - (vec2(h(bc + 1.1), h(bc + 2.2)) - 0.5) * 0.5;
		float ang = h(bc + 4.4) * 3.1416;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 lp = vec2(dot(bl, dir), dot(bl, vec2(-dir.y, dir.x)));
		float d = bone(lp, mix(0.35, 0.7, h(bc + 6.6)), 0.05);
		float soft = k == 0 ? 0.025 : 0.07;
		bones = max(bones, (1.0 - smoothstep(-soft, soft, d)) * step(0.5, h(bc + float(k) * 9.0)) * (k == 0 ? 0.45 : 0.25));
	}
	c = mix(c, vec3(0.42, 0.52, 0.6), bones);
	// Pale cracks between the plates, with a little white shatter beside each.
	float crk = 1.0 - smoothstep(0.012, 0.026 + fwidth(pe), pe);
	float shat = (1.0 - smoothstep(0.0, 0.16, pe)) * 0.22;
	c = mix(c, vec3(0.62, 0.72, 0.82), max(crk * 0.85, shat));
	// Frost drifts in from the walls and lies in patches.
	float g = clamp(smoothstep(0.55, 0.85, big2 * 0.85 + (1.0 - smoothstep(0.0, 2.2, wall)) * 0.45) * grime_amount * 1.8, 0.0, 1.0);
	c = mix(c, vec3(0.52, 0.58, 0.66) * (0.85 + 0.3 * fine), g);
	rough = mix(mix(0.07, 0.85, g), 0.6, crk);
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.82);
	n = normalize(vec3((r - 0.5) * 0.08, 1.0, (h(id + 3.0) - 0.5) * 0.08));
#elif STYLE == 3
	vec4 hx = hex(pos / 0.85);
	r = h(hx.zw);
	float he = hex_edge(hx.xy) * 0.85;
	float ht = h(hx.zw + 2.7);
	c = vec3(0.21, 0.19, 0.19) * (0.72 + 0.56 * ht) * (0.92 + 0.16 * fine);
	// Pale ash on some columns, soot along the walls.
	c = mix(c, vec3(0.44, 0.41, 0.39) * (0.85 + 0.3 * fine), smoothstep(0.62, 0.8, big2) * 0.55);
	float g = smoothstep(0.6, 0.88, big + (1.0 - smoothstep(0.0, 2.0, wall)) * 0.3) * grime_amount;
	c = mix(c, grime.rgb, g * 0.8);
	// Each column's top edge: the far and left sides catch the light, the others fall away.
	float rim = 1.0 - smoothstep(0.02, 0.1, he);
	c *= 1.0 + rim * mix(-0.32, 0.26, step(hx.y + hx.x * 0.4, 0.0));
	gap = 1.0 - smoothstep(0.022, 0.032 + fwidth(he), he);
	c = mix(c, grout.rgb, gap);
	rough = mix(0.88 - 0.3 * ht, 0.95, gap);
	n = normalize(vec3(0.0, 1.0, 0.0) + vec3(hx.x, 0.0, hx.y) * 1.6 * rim);
#elif STYLE == 4
	// Dark earth under moss.
	float moss = smoothstep(0.4, 0.62, big + 0.12 * fine);
	c = mix(vec3(0.15, 0.12, 0.1), vec3(0.12, 0.18, 0.1), moss) * (0.85 + 0.3 * fine);
	rough = 0.95;
	// Roots and darker hollows in the earth.
	float hollow = smoothstep(0.6, 0.85, big2);
	c *= 1.0 - 0.35 * hollow;
	float stone = 0.0;
	// Fungus threads where two slow noises cross their middle, with light running along them.
	// Only where the ground is mossy enough, so they wind in a few long strands.
	float t1 = texture(blobs_b, pos * 0.045 + vec2(0.2, 0.4)).r;
	float th = (1.0 - smoothstep(0.0, 0.012 + fwidth(t1), abs(t1 - 0.5)));
	float glow_band = (1.0 - smoothstep(0.0, 0.06, abs(t1 - 0.5))) * 0.25;
	th *= (1.0 - stone) * smoothstep(0.3, 0.6, big);
	glow_band *= (1.0 - stone) * smoothstep(0.3, 0.6, big);
	float flow = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TIME * 1.4 - t1 * 60.0 - pos.x * 0.3), 4.0);
	c = mix(c, spores.rgb * 0.45, th * 0.7);
	c = mix(c, c * vec3(1.0, 0.8, 1.0) + spores.rgb * 0.05, glow_band);
	em += spores.rgb * (th * 0.7 + glow_band * 0.5) * flow * spores.a;
	// Glowing caps in the moss, each pulsing at its own pace, with a soft halo.
	vec2 sq = pos * 1.9;
	vec2 sqc = floor(sq);
	float spr = h(sqc + 7.1);
	vec2 sp = sqc + 0.5 + (vec2(h(sqc + 3.3), h(sqc + 5.9)) - 0.5) * 0.6;
	float sd = length(sq - sp);
	float lit = step(0.75, spr) * moss;
	float cap = (1.0 - smoothstep(0.07, 0.13 + fwidth(sd), sd)) * lit;
	float halo = (1.0 - smoothstep(0.0, 0.45, sd)) * lit * 0.18;
	float pulse = 0.6 + 0.4 * sin(TIME * (1.1 + spr) + spr * 31.0);
	vec3 col = mix(spores.rgb, spores2.rgb, step(0.9, spr));
	c = mix(c, col * 0.5, cap);
	em += col * (cap * 1.3 + halo) * pulse * spores.a;
#elif STYLE == 5
	// The Blood Moon crypt (the event, version 134): polished black marble laid in great
	// diamonds with gold inlay between them, pale veins through the stone, thin veins of
	// blood light throbbing with a heartbeat (two beats, a rest), and the blood moon itself
	// inlaid in the middle of the room: a crescent in a gold ring with twelve rays.
	const float D = 2.2;
	vec2 dq = vec2(pos.x + pos.y, pos.y - pos.x) * 0.70710678 / D;
	vec2 dcell = floor(dq);
	vec2 df = fract(dq) - 0.5;
	vec2 de = (0.5 - abs(df)) * D;
	float ded = min(de.x, de.y);
	r = h(dcell);
	float vn = texture(grain, pos * 0.07 + vec2(r * 3.0, r * 1.7)).r;
	float vein = 1.0 - smoothstep(0.0, 0.025 + fwidth(vn), abs(vn - 0.5));
	float vn2 = texture(blobs_b, pos * 0.11 + vec2(r, 0.3)).r;
	float bvein = 1.0 - smoothstep(0.0, 0.01 + fwidth(vn2), abs(vn2 - 0.5));
	// Cool black (a touch of blue), so the warm torchlight and the red moon don't turn it red.
	c = vec3(0.1, 0.1, 0.135) * (0.85 + 0.3 * r) * (0.95 + 0.1 * fine) * tint.rgb;
	c = mix(c, vec3(0.5, 0.5, 0.56), vein * 0.3);
	rough = 0.22;
	float g = smoothstep(0.62, 0.9, big + (1.0 - smoothstep(0.0, 2.0, wall)) * 0.35) * grime_amount;
	c = mix(c, grime.rgb * (0.8 + 0.4 * fine), g * 0.6);
	rough = mix(rough, 0.8, g);
	float aa = fwidth(ded);
	float inlay = 1.0 - smoothstep(0.03 - aa, 0.03 + aa, ded);
	const vec3 GOLD = vec3(0.78, 0.58, 0.24);
	c = mix(c, GOLD, inlay);
	rough = mix(rough, 0.35, inlay);
	float bt = fract(TIME * 0.9);
	float beat = exp(-bt * 9.0) + 0.6 * exp(-max(bt - 0.22, 0.0) * 9.0) * step(0.22, bt);
	// Only a few slabs carry a blood vein (one in four), thin, so the marble stays black.
	bvein *= step(0.75, r) * (1.0 - inlay);
	c = mix(c, seam.rgb * 0.25, bvein * 0.6);
	em += seam.rgb * bvein * (0.15 + 0.55 * beat) * seam.a;
	float R = length(pos);
	if (R < 2.0) {
		float aR = fwidth(R);
		float disc = 1.0 - smoothstep(1.2 - aR, 1.2 + aR, R);
		float dark = 1.0 - smoothstep(1.05 - aR, 1.05 + aR, length(pos - vec2(0.45, -0.3)));
		float ring = 1.0 - smoothstep(0.02, 0.035 + aR, abs(R - 1.42));
		float ring2 = 1.0 - smoothstep(0.012, 0.024 + aR, abs(R - 1.72));
		float a = atan(pos.y, pos.x);
		float ray = (1.0 - smoothstep(0.03, 0.06, abs(fract(a / 6.2831853 * 12.0) - 0.5) * 0.5)) * step(1.45, R) * (1.0 - step(1.7, R));
		// Dark gold, still: a red, throbbing disc read as a danger circle (version 140).
		vec3 moon = vec3(0.3, 0.2, 0.08) * (0.85 + 0.3 * texture(blobs_a, pos * 0.4).r);
		c = mix(c, moon, disc);
		c = mix(c, vec3(0.06, 0.02, 0.03), disc * dark * 0.85);
		c = mix(c, GOLD * 1.2, max(max(ring, ring2), ray));
		rough = mix(rough, 0.3, disc);
		em += vec3(1.0, 0.7, 0.3) * max(ring, ray) * 0.15;
	}
	n = normalize(vec3((r - 0.5) * 0.05, 1.0, (h(dcell + 3.0) - 0.5) * 0.05));
#else
	// Slabs 1.8 m wide and 1.3 m deep, each row shifted sideways by its own amount.
	const vec2 SLAB = vec2(1.8, 1.3);
	float row = floor(pos.y / SLAB.y);
	vec2 s = vec2(pos.x / SLAB.x + h(vec2(row, 3.7)), pos.y / SLAB.y);
	vec2 cell = floor(s);
	vec2 f = fract(s) - 0.5;
	vec2 e = (0.5 - abs(f)) * SLAB;
	float edge = min(e.x, e.y);
	r = h(cell);
	float r2 = h(cell + 13.7);
	c = vec3(0.37, 0.34, 0.39) * (0.86 + 0.26 * r) * (0.92 + 0.16 * fine);
	c *= mix(vec3(1.0), vec3(1.07, 1.0, 0.9), step(0.6, r2));
	c *= tint.rgb;
	float g = smoothstep(0.6, 0.9, big + (1.0 - smoothstep(0.0, 2.0, wall)) * 0.3) * grime_amount;
	c = mix(c, grime.rgb * (0.8 + 0.4 * fine), g);
	float p = smoothstep(0.62, 0.82, big2);
	c *= mix(vec3(1.0), patch_tint.rgb, p * 0.7);
	rough = mix(0.82, patch_rough, p);
	float aa = fwidth(edge);
	gap = 1.0 - smoothstep(0.022 - aa, 0.022 + aa, edge);
	// About one slab in three has a crack: a wobbly line across its middle.
	float a = r2 * 3.1416;
	vec2 dir = vec2(cos(a), sin(a));
	float off = dot(f, vec2(-dir.y, dir.x)) + 0.035 * sin(dot(f, dir) * 13.0 + r * 30.0);
	crack = (1.0 - smoothstep(0.0, 0.014 + fwidth(off), abs(off))) * step(0.66, r)
		* (1.0 - smoothstep(0.25, 0.45, abs(dot(f, dir))));
	// Far and left edges catch the light, near and right fall into shadow.
	float rim_hi = max((1.0 - smoothstep(0.03, 0.11, e.y)) * step(f.y, 0.0), (1.0 - smoothstep(0.03, 0.11, e.x)) * step(f.x, 0.0));
	float rim_lo = max((1.0 - smoothstep(0.03, 0.13, e.y)) * step(0.0, f.y), (1.0 - smoothstep(0.03, 0.13, e.x)) * step(0.0, f.x));
	c *= 1.0 + 0.22 * rim_hi - 0.28 * rim_lo;
	// About one slab in thirty is an iron drain grate.
	float grate = step(0.967, h(cell * vec2(1.73, 2.31) + vec2(41.3, 7.9))) * step(1.5, wall) * (1.0 - ledge);
	if (grate > 0.5) {
		vec2 inset = e - vec2(0.3, 0.26);
		pit = smoothstep(-0.01, 0.01, min(inset.x, inset.y));
		float lip = smoothstep(-0.07, -0.05, min(inset.x, inset.y)) * (1.0 - pit);
		float bx = abs(fract(f.x * SLAB.x / 0.24) - 0.5);
		bar = (1.0 - smoothstep(0.17, 0.23, bx)) * pit;
		c = mix(c, vec3(0.16, 0.15, 0.17), lip * 0.6);
		c = mix(c, vec3(0.03, 0.025, 0.03), pit);
		c = mix(c, vec3(0.32, 0.31, 0.34) * (0.8 + 0.4 * fine), bar);
		crack = 0.0;
	}
	// Chipped slabs: about two in five have lost a corner.
	if (step(0.6, h(cell + 5.5)) > 0.5 && grate < 0.5) {
		vec2 cf = vec2(r2 > 0.5 ? 0.5 : -0.5, r > 0.5 ? 0.5 : -0.5);
		vec2 dc = abs(f - cf) * SLAB;
		float size = 0.16 + 0.14 * h(cell + 9.1);
		float notch = 1.0 - smoothstep(size - 0.015, size + 0.015, dc.x + dc.y);
		float brk = (1.0 - smoothstep(0.0, 0.04, abs(dc.x + dc.y - size - 0.03))) * (1.0 - notch);
		c = mix(c, c * 0.45, notch);
		c *= 1.0 + 0.25 * brk;
	}
	vec3 gap_col = mix(grout.rgb, grime.rgb * 0.9, smoothstep(0.15, 0.6, g) * 0.85);
	c = mix(c, gap_col, gap);
	c *= 1.0 - crack * 0.6;
	// A little greyer and darker, so heroes, skeletons and their shots stand out.
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.78) * 0.88;
	rough = mix(rough, 0.95, max(gap, crack));
	vec2 bevel = sign(f) * (1.0 - smoothstep(0.0, 0.09, e)) * 0.6;
	n = normalize(vec3(bevel.x + (r - 0.5) * 0.1, 1.0, bevel.y + (r2 - 0.5) * 0.1));
	if (water.a > 0.0) {
		float wpool = max(smoothstep(0.57, 0.6, big2), max(gap, crack) * 0.9) * water.a;
		float deep = smoothstep(0.6, 0.8, big2);
		float wrim = smoothstep(0.555, 0.57, big2) * (1.0 - smoothstep(0.575, 0.59, big2));
		vec2 wq = pos * 1.6;
		vec2 rip = vec2(sin(wq.x * 2.3 + TIME * 1.4 + sin(wq.y * 1.4 + TIME * 0.6)),
			sin(wq.y * 2.1 - TIME * 1.2 + sin(wq.x * 1.6 - TIME * 0.5)));
		float wl = pow(0.5 + 0.5 * sin(wq.x * 3.1 + rip.y * 1.6 + TIME * 0.9) * sin(wq.y * 2.9 + rip.x * 1.6 - TIME * 0.7), 9.0);
		vec3 wet = water.rgb * mix(1.3, 0.8, deep) * (0.85 + 0.3 * fine);
		c = mix(c * mix(1.0, 0.82, water.a), wet, wpool * 0.9);
		c += vec3(0.32, 0.45, 0.42) * wrim * water.a * 0.3;
		rough = mix(mix(rough, 0.5, water.a * 0.6), 0.03, wpool);
		n = normalize(n * (1.0 - wpool) + vec3(rip.x * 0.12, 1.0, rip.y * 0.12) * wpool);
		em += water.rgb * wl * wpool * (1.0 - deep * 0.5) * 0.5;
	}
#endif

	if (blood > 0.0) {
		float b = smoothstep(0.7, 0.78, texture(grain, pos * 0.07 + vec2(0.5, 0.2)).r) * blood;
		c = mix(c, vec3(0.3, 0.03, 0.03), b);
		rough = mix(rough, 0.35, b);
	}
	c *= shade;
	// A soft lighter middle, as if light falls into the room from above.
	c *= 1.0 + 0.1 * (1.0 - smoothstep(1.0, 8.0, length(pos * vec2(1.0, 0.55))));
	// Warm pools of torchlight on the floor under the six wall torches, flickering.
	if (torch_amount > 0.0) {
		float tpool = 0.0;
		for (int i = 0; i < 6; i++) {
			vec2 tp = vec2(i % 2 == 0 ? -half_size.x : half_size.x, -6.0 + 6.0 * float(i / 2));
			float d = length((pos - tp) * vec2(1.0, 0.8));
			float fl = 0.85 + 0.15 * sin(TIME * 6.3 + float(i) * 1.7) * sin(TIME * 2.9 + float(i) * 4.1);
			tpool += (1.0 - smoothstep(0.0, 4.2, d)) * fl;
		}
		c *= 1.0 + torch_glow.rgb * tpool * torch_amount;
	}

	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = rough;
	if (up > 0.5) {
		NORMAL = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * n);
	}
	if (seam.a > 0.0) {
		float heat = smoothstep(0.56, 0.76, texture(blobs_b, pos * 0.05 + vec2(TIME * 0.006, 0.6)).r);
		float sp2 = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(TIME * 1.3 + r * 6.283 + pos.x * 0.6 + pos.y * 0.35), 2.0);
		em += seam.rgb * max(gap, crack) * sp2 * mix(0.6, 1.2, r) * mix(0.05, 1.25, heat);
		em += seam.rgb * pit * (1.0 - bar) * (0.7 + 0.3 * sp2) * 0.2;
	}
	EMISSION = em * shade;
}
"""


static var _wall_shaders := {}

## The walls match each crypt's floor (version 134), drawn by one shader built a little
## differently for each floor_style (0 keeps the plain coloured walls):
## 1. Bone Crypt: a catacomb wall of skulls in rows, between bands of stacked bone ends.
## 2. Frozen Ossuary: dark ice with pale streaks running down it and frost at the foot.
## 3. Ember Catacomb: upright basalt columns with fire glowing low in the joints.
## 4. Glowcap Grotto: dark earth wall hung with roots, moss at the foot and a few glowing
##    fungus threads.
## 5. Blood Moon (the event): black marble blocks, gold joints, throbbing blood veins and a
##    frieze of gold crescent moons.
## The pattern follows where the point is in the world, so walls built from several boxes
## join up, and a box's top takes the pattern seen from above.
static func _wall_material(look: Dictionary, base: Material) -> Material:
	var style := int(look.get("floor_style", 0))
	if style == 0:
		return base
	if not _wall_shaders.has(style):
		var sh := Shader.new()
		sh.code = "shader_type spatial;\n#define STYLE %d\n" % style + WALL_CODE
		_wall_shaders[style] = sh
	var sm := ShaderMaterial.new()
	sm.shader = _wall_shaders[style]
	sm.set_shader_parameter("grain", U.noise_tex(0.045, 11, 4))
	sm.set_shader_parameter("blobs", U.noise_tex(0.018, 37))
	sm.set_shader_parameter("seam", look.get("seams", Color(0, 0, 0, 0)))
	sm.set_shader_parameter("spores", look.get("spores", Color(0, 0, 0, 0)))
	return sm


const WALL_CODE := """
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
uniform sampler2D blobs : repeat_enable, filter_linear_mipmap;
uniform vec4 seam : source_color = vec4(0.0);
uniform vec4 spores = vec4(0.0);
varying vec2 uv;
varying float height;
varying float top;

float h(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	height = wp.y;
	top = step(0.5, abs(wn.y));
	uv = top > 0.5 ? wp.xz : (abs(wn.z) > 0.5 ? vec2(wp.x, wp.y) : vec2(wp.z, wp.y));
}

void fragment() {
	float fine = texture(grain, uv * 0.3).r;
	vec3 c = vec3(0.1);
	float rough = 0.9;
	vec3 em = vec3(0.0);
#if STYLE == 1
	const vec3 GAP = vec3(0.05, 0.045, 0.045);
	vec3 ivory = vec3(0.5, 0.45, 0.37);
	float row = floor(uv.y / 0.42);
	bool skulls = top < 0.5 && mod(row, 2.0) < 1.0;
	c = GAP;
	if (skulls) {
		float cx = floor(uv.x / 0.36 + row * 0.5);
		vec2 lp = vec2((fract(uv.x / 0.36 + row * 0.5) - 0.5) * 0.36, (fract(uv.y / 0.42) - 0.5) * 0.42);
		lp.x += (h(vec2(cx, row)) - 0.5) * 0.03;
		float head = length(lp * vec2(1.0, 1.1) - vec2(0.0, 0.025)) - 0.14;
		float jaw = length(max(abs(lp - vec2(0.0, -0.1)) - vec2(0.06, 0.03), 0.0)) - 0.02;
		float skull = min(head, jaw);
		float eyes = length(vec2(abs(lp.x) - 0.055, lp.y - 0.0)) - 0.038;
		float nose = length(lp - vec2(0.0, -0.055)) - 0.018;
		float aa = fwidth(skull);
		float inside = 1.0 - smoothstep(-aa, aa, skull);
		vec3 sk = ivory * (0.82 + 0.28 * h(vec2(cx, row + 3.0))) * (0.6 + 0.5 * smoothstep(0.0, -0.08, skull));
		c = mix(c, sk, inside);
		c = mix(c, GAP, (1.0 - smoothstep(-0.006, 0.006, min(eyes, nose))) * inside);
	} else if (top > 0.5) {
		// Seen from above: dark stone laid with rows of bones, like the floor's bands.
		c = vec3(0.2, 0.19, 0.21) * (0.9 + 0.2 * fine);
		vec2 lp = vec2((fract(uv.x / 0.5) - 0.5) * 0.5, (fract(uv.y / 0.5) - 0.5) * 0.5);
		float bs = length(vec2(max(abs(lp.x) - 0.155, 0.0), lp.y)) - 0.04;
		bs = min(bs, length(vec2(abs(lp.x) - 0.155, abs(lp.y) - 0.036)) - 0.052);
		float inside = 1.0 - smoothstep(-0.006, 0.006, bs);
		c = mix(c, ivory * (0.6 + 0.3 * smoothstep(0.0, -0.035, bs)), inside);
	} else {
		// The ends of long bones stacked tight, each with a darker hollow.
		vec2 q = uv / 0.13;
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 lp = (fract(q) - 0.5) * 0.13;
		float d = length(lp);
		float r0 = 0.055 + 0.008 * h(floor(q));
		float inside = 1.0 - smoothstep(r0 - 0.005, r0 + 0.005, d);
		vec3 bc = ivory * (0.72 + 0.3 * h(floor(q) + 4.0)) * (0.7 + 0.4 * smoothstep(r0, 0.0, d));
		c = mix(c, bc, inside);
		c = mix(c, bc * 0.45, 1.0 - smoothstep(0.016, 0.024, d));
	}
	c *= 0.88 + 0.24 * fine;
	rough = 0.8;
#elif STYLE == 2
	float streak = texture(blobs, vec2(uv.x * 0.9, uv.y * 0.08)).r;
	c = vec3(0.07, 0.13, 0.21) * (0.85 + 0.3 * fine);
	c = mix(c, vec3(0.3, 0.42, 0.55), smoothstep(0.55, 0.8, streak) * 0.6);
	float crack = 1.0 - smoothstep(0.0, 0.02 + fwidth(streak), abs(streak - 0.42));
	c = mix(c, vec3(0.55, 0.66, 0.78), crack * 0.6);
	float frost = 1.0 - smoothstep(0.0, 0.7, height) + top;
	c = mix(c, vec3(0.45, 0.52, 0.6) * (0.85 + 0.3 * fine), clamp(frost, 0.0, 1.0) * 0.7);
	rough = mix(0.1, 0.85, clamp(frost, 0.0, 1.0));
#elif STYLE == 3
	const float w = 0.38;
	float col = floor(uv.x / w);
	float fx = fract(uv.x / w);
	float ch = h(vec2(col, 1.3));
	float seg = 0.7 + 0.6 * h(vec2(col, 8.1));
	float fy = fract(uv.y / seg + ch);
	c = vec3(0.16, 0.14, 0.14) * (0.7 + 0.6 * ch) * (0.9 + 0.2 * fine);
	// Each column is rounded a little: lit on its left, dark on its right.
	c *= 0.75 + 0.45 * smoothstep(1.0, 0.0, fx) * smoothstep(0.0, 0.2, fx);
	float joint = max(1.0 - smoothstep(0.0, 0.05, min(fx, 1.0 - fx)), (1.0 - smoothstep(0.0, 0.03, min(fy, 1.0 - fy))) * (1.0 - top));
	c = mix(c, vec3(0.03, 0.02, 0.02), joint);
	float low = 1.0 - smoothstep(0.0, 1.1, height);
	em += seam.rgb * joint * low * (0.45 + 0.35 * sin(TIME * 1.3 + col * 2.1)) * (1.0 - top);
	rough = 0.85;
#elif STYLE == 4
	float rt = texture(blobs, vec2(uv.x * 0.35, uv.y * 0.06)).r;
	c = vec3(0.12, 0.1, 0.08) * (0.8 + 0.4 * fine);
	float root = 1.0 - smoothstep(0.0, 0.025 + fwidth(rt), abs(rt - 0.5));
	float root2 = 1.0 - smoothstep(0.0, 0.02 + fwidth(rt), abs(rt - 0.35));
	c = mix(c, vec3(0.26, 0.2, 0.14), max(root, root2 * 0.7));
	float moss = clamp(1.0 - smoothstep(0.0, 0.9, height + (fine - 0.5) * 0.6) + top, 0.0, 1.0);
	c = mix(c, vec3(0.1, 0.16, 0.08) * (0.8 + 0.4 * fine), moss);
	float thread = (1.0 - smoothstep(0.0, 0.012 + fwidth(rt), abs(rt - 0.62))) * (1.0 - top);
	c = mix(c, spores.rgb * 0.4, thread * 0.6);
	em += spores.rgb * thread * (0.4 + 0.6 * pow(0.5 + 0.5 * sin(TIME * 1.4 - uv.y * 4.0 + uv.x), 4.0)) * 0.6;
#elif STYLE == 5
	// Blood Moon: black marble blocks with gold joints, blood veins in the stone throbbing
	// with the floor's heartbeat, and a frieze of gold crescent moons at shoulder height.
	float row = floor(uv.y / 0.55);
	float bx = uv.x / 1.1 + mod(row, 2.0) * 0.5;
	float bc = floor(bx);
	vec2 bf = vec2(fract(bx), fract(uv.y / 0.55));
	float hb = h(vec2(bc, row));
	c = vec3(0.1, 0.1, 0.13) * (0.8 + 0.4 * hb) * (0.9 + 0.2 * fine);
	float joint = (1.0 - smoothstep(0.0, 0.025, min(min(bf.x, 1.0 - bf.x) * 1.1, min(bf.y, 1.0 - bf.y) * 0.55))) * (1.0 - top);
	c = mix(c, vec3(0.5, 0.36, 0.16), joint);
	float vn = texture(blobs, uv * 0.35 + vec2(hb, 0.0)).r;
	float vein = (1.0 - smoothstep(0.0, 0.012 + fwidth(vn), abs(vn - 0.5))) * step(0.7, hb) * (1.0 - joint);
	float bt = fract(TIME * 0.9);
	float beat = exp(-bt * 9.0) + 0.6 * exp(-max(bt - 0.22, 0.0) * 9.0) * step(0.22, bt);
	c = mix(c, seam.rgb * 0.3, vein * 0.6);
	em += seam.rgb * vein * (0.2 + 0.6 * beat) * seam.a;
	if (top < 0.5 && height > 1.15 && height < 1.45) {
		vec2 lp = vec2((fract(uv.x / 0.7) - 0.5) * 0.7, height - 1.3);
		float moon = (1.0 - smoothstep(0.1, 0.115, length(lp))) * smoothstep(0.085, 0.1, length(lp - vec2(0.045, 0.035)));
		c = mix(vec3(0.07, 0.03, 0.04), vec3(0.75, 0.55, 0.25), moon);
		em += vec3(1.0, 0.7, 0.3) * moon * 0.25;
	}
	rough = mix(0.25, 0.4, joint);
#endif
	// Darker at the foot of the wall, where the floor meets it.
	float foot = mix(0.55, 1.0, smoothstep(0.0, 0.7, height));
	ALBEDO = c * foot;
	ROUGHNESS = rough;
	EMISSION = em;
}
"""


## The low near ledge: the floor's stone, darker, without the floor's fire, water or blood.
static func _ledge_material(look: Dictionary) -> Material:
	var m := _floor_material(look, 0) as ShaderMaterial
	m.set_shader_parameter("tint", (look.floor as Color) * 0.6)
	m.set_shader_parameter("grime_amount", 0.0)
	m.set_shader_parameter("blood", 0.0)
	m.set_shader_parameter("seam", Color(0, 0, 0, 0))
	m.set_shader_parameter("water", Color(0, 0, 0, 0))
	m.set_shader_parameter("spores", Color(0, 0, 0, 0))
	m.set_shader_parameter("half_size", Vector2(100, 100))
	m.set_shader_parameter("ledge", 1.0)
	m.set_shader_parameter("torch_amount", 0.0)
	return m


## Every light costs a lot on phones, so High keeps the far and near pairs of torch
## lights (with a longer reach to cover the middle) and Low keeps only the middle pair.
## The torch flames themselves always show.
func apply_graphics(high: bool) -> void:
	for i in _torch_lights.size():
		var keep := (i != 2 and i != 3) if high else (i == 2 or i == 3)
		_torch_lights[i].visible = keep
		_torch_lights[i].omni_range = 9.5 if high else 11.0
		_torch_lights[i].light_energy = Floors.current().torch_energy * (1.0 if high else 1.2) * torch_k


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
					# Each crypt has its own pillars (version 134).
					var prefab := Art.get_model(str(Floors.current().get("pillar", Art.PILLAR)))
					if prefab == null:
						prefab = Art.get_model(Art.PILLAR)
					if prefab:
						var pillar := Art.place_prop(prefab, _anchor(p), WALL_H + 0.4)
						# Some crypt pillars are chunky: keep them no wider than the old one, so
						# what you see matches what blocks you.
						var wide := Art.width_of(pillar)
						if wide > 1.25:
							pillar.scale.x *= 1.25 / wide
							pillar.scale.z *= 1.25 / wide
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
					if Game.ftue_room() != 1:   # no spikes in the tutorial's first room (version 149)
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
## The walls always win: a push out of a pillar or a corner prop never ends outside the room
## (it used to, and a skeleton stuck past a corner could never be hit, so its room never
## cleared). Where the straight push would cross a wall, the circle slides along the wall.
func resolve_move(pos: Vector3, delta: Vector3, r: float) -> Vector3:
	var p := _clamp_walls(pos + delta, r)
	for i in 2:
		var moved := false
		for o in obstacles:
			var d: Vector3 = p - o.pos
			d.y = 0.0
			var m: float = o.r + r
			if d.length_squared() < m * m:
				p = _push_out(p, o.pos, m, r)
				moved = true
		if not moved:
			break
	return p


func _clamp_walls(p: Vector3, r: float) -> Vector3:
	p.y = 0.0
	var min_z := -HALF_L + r
	if door_open and absf(p.x) < DOOR_HALF - r * 0.5:
		min_z = -HALF_L - 1.2
	p.x = clampf(p.x, -HALF_W + r, HALF_W - r)
	p.z = clampf(p.z, min_z, HALF_L - r)
	if p.z < -HALF_L + r:
		p.x = clampf(p.x, -DOOR_HALF + r, DOOR_HALF - r)
	return p


## `p` pushed out of the circle at `c` (radius `m`, already including the mover's own),
## staying inside the walls: straight out if that's inside, else sliding along one axis.
func _push_out(p: Vector3, c: Vector3, m: float, r: float) -> Vector3:
	var d := Vector3(p.x - c.x, 0.0, p.z - c.z)
	var dist := d.length()
	var out := c + (d / dist * m if dist > 0.0001 else Vector3(-signf(c.x) if c.x != 0.0 else 1.0, 0, 0) * m)
	out.y = 0.0
	var fixed := _clamp_walls(out, r)
	if fixed.distance_squared_to(out) < 0.0001:
		return out
	# Straight out crosses a wall: try sliding along x or along z, nearest first.
	var best := fixed
	var best_d := INF
	var dz := p.z - c.z
	var dx := p.x - c.x
	for k in 4:
		var q := p
		if k < 2:
			if absf(dz) >= m:
				continue
			q.x = c.x + (1.0 if k == 0 else -1.0) * sqrt(m * m - dz * dz)
		else:
			if absf(dx) >= m:
				continue
			q.z = c.z + (1.0 if k == 2 else -1.0) * sqrt(m * m - dx * dx)
		if _clamp_walls(q, r).distance_squared_to(q) > 0.0001:
			continue
		var dd := q.distance_squared_to(p)
		if dd < best_d:
			best_d = dd
			best = q
	return best


## True when a circle of radius `r` at `p` is inside the walls and not inside an obstacle,
## where hero bolts can reach it.
func is_walkable(p: Vector3, r: float) -> bool:
	if absf(p.x) > HALF_W - r + 0.05 or p.z > HALF_L - r + 0.05 or p.z < -HALF_L + r - 0.05:
		return false
	for o in obstacles:
		var d: Vector3 = p - o.pos
		d.y = 0.0
		if d.length_squared() < (o.r + r - 0.1) * (o.r + r - 0.1):
			return false
	return true


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
		# The gap is measured from the pillar itself. It used to be measured from the skeleton,
		# so one a little to the side of a pillar one column in from the wall (where there is
		# room to pass) flipped its mind every frame and stood there pushing into the pillar.
		var probe: Vector3 = o.pos + tangent * (o.r + r + 0.1)
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
