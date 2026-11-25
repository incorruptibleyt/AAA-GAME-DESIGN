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
const LEDGE_DEPTH := 4.5   # v336: the near ledge, deep enough to fill the bottom of the screen
## Version 358: the near wall is a low parapet this tall and deep; the place goes on past it.
const PARAPET_H := 0.5
const PARAPET_D := 0.7
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


## The layout cell (column, row) a point stands in: the reverse of cell_to_world.
static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL + (Layouts.COLUMNS - 1) * 0.5), roundi(p.z / CELL + (Layouts.ROWS - 1) * 0.5))


static func cell_to_world(col: int, row: int) -> Vector3:
	return Vector3((col - (Layouts.COLUMNS - 1) * 0.5) * CELL, 0.0, (row - (Layouts.ROWS - 1) * 0.5) * CELL)


func player_start() -> Vector3:
	# A little up from the near wall, so the camera can keep the hero above the thumb.
	return Vector3(0, 0, HALF_L - 4.5)   # (v216: further in, so the hero is not under DASH)


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
	# Version 336 (visual review fix 1): the ledge runs 4.5 m deep toward the camera, so the
	# bottom of the phone shows the top of a thick stone wall instead of a black strip.
	# Version 358 (review of 357, fix 1): that ledge still read as a flat dark bar across the
	# bottom quarter of the phone. Now it is a low parapet, and past it the place carries on
	# (its own floor, a little darker, with its own things lying about: Props.dress_gallery),
	# so the bottom of the screen shows more of the place instead of a strip with no fight.
	U.box(self, Vector3(HALF_W * 2 + t * 2, PARAPET_H, PARAPET_D), _wall_material(look, _ledge_material(look)), Vector3(0, PARAPET_H / 2, HALF_L + PARAPET_D / 2))
	# A slim rim of the place's trim along its inner edge (all of the top in trim read as a
	# loud coloured bar).
	U.box(self, Vector3(HALF_W * 2 + t * 2, 0.07, 0.14), trim, Vector3(0, PARAPET_H + 0.035, HALF_L + 0.07))
	var gal := Vector2(HALF_W * 2 + t * 2, LEDGE_DEPTH)
	var gz := HALF_L + PARAPET_D + gal.y / 2 - 0.05
	U.floor_quad(self, gal, _gallery_material(look, gz), Vector3(0, 0, gz))
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
## 1. The Bone Crypt (version 277) is an old crypt: dark slate flagstones in courses, two
##    rows of carved grave slabs down the sides and, in the middle, the Bone Chain: a ring of
##    links made of bone round the Skeleton King's crowned skull, candlelight in its eyes.
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
## 6. Frostfall Hall (the winter event): dark timber planks instead of stone, snow drifted
##    in along the walls and a crimson runner with gold trim down the middle.
## 7. The Sandfall Tomb (floor 5): sandstone blocks carved with signs, a processional way
##    between turquoise borders, a winged sun inlaid in the middle and rippled sand dunes.
## 8. The Amethyst Mine (floor 7): bare rock slabs, gravel and dust, glowing amethyst veins
##    and glints, and mine-cart tracks on timber sleepers with a spur curving to the side.
## 9. The Whispering Library (floor 8): herringbone parquet, two worn rugs and a brass circle
##    of glowing letters set into the middle of the floor.
## 10. The Clockwork Foundry (floor 9): riveted iron plates, some with a diamond tread, rust
##    and oil, long grates with the furnaces glowing under them, and a great brass gear in
##    the middle turning two smaller ones.
## 11. The Starfall Abyss (floor 10): moonstone plates drifted apart over a starry void that
##    shows in every gap (and where plates by the walls have fallen away), and a star gate in
##    the middle: a window onto a turning spiral of stars under a silver seal.
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
	# Version 337 (visual review fix 2): dirt and soot patches at a bit over half their old
	# amount everywhere; they made every floor blotchy under the fight.
	sm.set_shader_parameter("grime_amount", float(look.get("grime_amount", 0.6)) * CALM_GRIME)
	sm.set_shader_parameter("blood", look.get("blood", 0.0))
	sm.set_shader_parameter("seam", look.get("seams", Color(0, 0, 0, 0)))
	sm.set_shader_parameter("water", look.get("water", Color(0, 0, 0, 0)))
	sm.set_shader_parameter("spores", look.get("spores", Color(0, 0, 0, 0)))
	sm.set_shader_parameter("spores2", look.get("spores2", Color(0.7, 1.0, 0.3)))
	sm.set_shader_parameter("half_size", Vector2(HALF_W, HALF_L))
	sm.set_shader_parameter("torch_glow", look.torch)
	sm.set_shader_parameter("torch_amount", look.get("pool", 1.5))
	# Version 337 (visual review fix 2): each floor style's own stone brightness, so its dark
	# lines and smudges can be softened towards it (the shader's calm_ uniforms).
	var tl: float = (look.floor as Color).get_luminance() if CALM_TINTED.has(style) else 1.0
	sm.set_shader_parameter("calm_mid", float(CALM_MID.get(style, 0.0)) * tl)
	sm.set_shader_parameter("calm_depth", float(look.get("calm_depth", CALM_DEPTH)))
	sm.set_shader_parameter("calm_sat", float(look.get("calm_sat", CALM_SAT)))
	return sm


## Version 337: the usual brightness of each floor style's stone (see the shader's first
## colour in each style), and the styles whose stone is multiplied by the place's floor tint.
const CALM_MID := {0: 0.34, 1: 0.2, 2: 0.157, 3: 0.196, 4: 0.14, 5: 0.103, 6: 0.17, 7: 0.23, 8: 0.25, 9: 0.19, 10: 0.22, 11: 0.27}
const CALM_TINTED := [0, 1, 5, 7, 8, 10, 11]
const CALM_DEPTH := 0.3
const CALM_GRIME := 0.55
const CALM_SAT := 0.72


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
// Version 358: the floor past the near parapet (the gallery) is its own quad: where its
// middle sits in the room, and how much darker it is than the room.
uniform vec2 shift = vec2(0.0);
uniform float dim = 1.0;
// Version 337: calmer floors. The floor stone's usual brightness (0 = leave as drawn), how
// deep darker marks may stay (share of their depth) and how much colour is kept.
uniform float calm_mid = 0.0;
uniform float calm_depth = 0.5;
uniform float calm_sat = 0.8;
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

// Distance from p to the segment a-b.
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
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

// A mine-cart track (the Amethyst Mine): tp.x across it (0 in the middle) and tp.y along it,
// in metres. Timber sleepers every 0.7 m and two iron rails with a bright worn top. Returns
// the colour and how much of the point it covers.
vec4 track(vec2 tp, float fine) {
	float au = abs(tp.x);
	float sv = (fract(tp.y / 0.7) - 0.5) * 0.7;
	float sw = fwidth(sv) + 0.004;
	float sleeper = (1.0 - smoothstep(0.11 - sw, 0.11 + sw, abs(sv))) * (1.0 - smoothstep(0.74, 0.78, au));
	vec3 col = vec3(0.22, 0.14, 0.085) * (0.75 + 0.45 * fine) * (0.8 + 0.35 * h(vec2(floor(tp.y / 0.7), 3.0)));
	col *= 0.8 + 0.25 * smoothstep(0.11, 0.0, abs(sv));
	float rd = abs(au - 0.48);
	float rw = fwidth(au) + 0.003;
	float rail = 1.0 - smoothstep(0.036 - rw, 0.036 + rw, rd);
	float shine = 1.0 - smoothstep(0.004, 0.016 + rw, rd);
	vec3 rc = mix(vec3(0.09, 0.085, 0.1), vec3(0.34, 0.33, 0.36), shine);
	// The rail's shadow on the sleeper beside it.
	col *= 1.0 - 0.45 * (1.0 - smoothstep(0.03, 0.07, au - 0.48)) * step(0.48, au);
	col = mix(col, rc, rail);
	return vec4(col, max(sleeper, rail));
}

#if STYLE == 1
// The Bone Crypt's carvings (floor style 1): a rounded box (p from its centre, b its half
// size, rr how round its corners are), a smooth join of two shapes, and a crown's point
// (base half width w at y = 0, tip at y = ht). Below 0 is inside.
float sd_box(vec2 p, vec2 b, float rr) {
	vec2 d = abs(p) - b + rr;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - rr;
}

float smin(float a, float b, float k) {
	float t = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, t) - k * t * (1.0 - t);
}

float spike(vec2 p, float w, float ht) {
	return max(-p.y, (abs(p.x) * ht + p.y * w - w * ht) / length(vec2(ht, w)));
}
#endif

void vertex() {
	up = NORMAL.y;
	pos = ((ledge > 0.5 && abs(NORMAL.y) < 0.5) ? VERTEX.xy : VERTEX.xz) + shift;
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
	// Version 277 (hard review of build 267, fix 6): the Bone Crypt, the first place every
	// player sees, was the plainest floor in the game (3 m panels in a faint grid of bones
	// under a flat orange light). Now it is an old crypt floor: dark slate flagstones laid in
	// courses, two rows of carved grave slabs down the sides (a skull and crossbones, lines
	// of worn writing, some of them cracked), and in the middle the Bone Chain: a ring of
	// links made of bone round the Skeleton King's crowned skull, its crown inlaid in gold
	// and candlelight glowing in its eyes.
	// The flagstones: courses 1.05 m deep, slabs 1.1 to 1.7 m long, each course its own.
	const float ROW = 1.05;
	float rowi = floor(pos.y / ROW);
	float sw = 1.1 + 0.6 * h(vec2(rowi, 3.1));
	float sx = pos.x / sw + h(vec2(rowi, 8.3));
	vec2 cell = vec2(floor(sx), rowi);
	vec2 f = vec2(fract(sx) - 0.5, fract(pos.y / ROW) - 0.5);
	vec2 e = (0.5 - abs(f)) * vec2(sw, ROW);
	r = h(cell);
	float r2 = h(cell + 7.7);
	c = vec3(0.205, 0.2, 0.198) * (0.78 + 0.44 * r) * (0.9 + 0.2 * fine) * tint.rgb;
	// Old stone: a few slabs browner, a few greener.
	c *= mix(vec3(1.0), r2 > 0.5 ? vec3(1.07, 1.0, 0.9) : vec3(0.93, 1.0, 1.0), abs(r2 - 0.5) * 1.6);
	rough = 0.8;
	float ed = min(e.x, e.y);
	gap = 1.0 - smoothstep(0.012, 0.028 + fwidth(ed), ed);
	c *= 0.8 + 0.2 * smoothstep(0.0, 0.1, ed);   // worn, rounded edges
	float cn = texture(blobs_a, pos * 0.3 + vec2(r * 5.0, r2 * 3.0)).r;
	crack = step(0.72, r2) * (1.0 - smoothstep(0.0, 0.012 + fwidth(cn), abs(cn - 0.5))) * smoothstep(0.03, 0.1, ed);
	// Dust along the walls and in patches.
	float g = smoothstep(0.62, 0.9, big + (1.0 - smoothstep(0.0, 2.0, wall)) * 0.35) * grime_amount;
	c = mix(c, grime.rgb * (0.7 + 0.35 * fine), g * 0.5);
	rough = mix(rough, 0.92, g);
	vec2 bevel = sign(f) * (1.0 - smoothstep(0.0, 0.08, e)) * 0.5;
	n = normalize(vec3(bevel.x + (r - 0.5) * 0.08, 1.0, bevel.y + (r2 - 0.5) * 0.08));

	// The grave slabs: two rows, 3.05 m out from the middle, one every 3.3 m (now and then one
	// is missing), each sunk a little crooked. Their heads point away from the camera.
	float gk = clamp(floor(pos.y / 3.3 + 0.5), -2.0, 2.0);
	vec2 gid = vec2(sign(pos.x), gk);
	float gr = h(gid + 21.0);
	float gr2 = h(gid + 33.0);
	vec2 lp = vec2(abs(pos.x) - 3.05, pos.y - gk * 3.3 - (gr - 0.5) * 0.35);
	float ga = (gr2 - 0.5) * 0.07;
	lp = mat2(vec2(cos(ga), sin(ga)), vec2(-sin(ga), cos(ga))) * lp;
	const vec2 GH = vec2(0.6, 1.02);
	float gd = sd_box(lp, GH, 0.03);
	if (gr > 0.14 && gd < 0.05) {
		float gaa = fwidth(gd);
		float inside = 1.0 - smoothstep(-gaa, gaa, gd);
		float joint = 1.0 - smoothstep(0.0, 0.025 + gaa, abs(gd + 0.006));
		vec3 lime = vec3(0.33, 0.315, 0.29) * (0.86 + 0.22 * gr2) * (0.8 + 0.4 * fine) * (0.88 + 0.24 * big2);
		vec2 u = vec2(lp.x, -lp.y);
		// A border cut round it.
		float carve = 1.0 - smoothstep(0.008, 0.02 + gaa, abs(gd + 0.1));
		// A skull and crossbones at its head.
		vec2 sp = u - vec2(0.0, 0.56);
		float skull = smin(length(sp - vec2(0.0, 0.04)) - 0.15, sd_box(sp - vec2(0.0, -0.11), vec2(0.08, 0.05), 0.03), 0.05);
		vec2 b1 = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * sp;
		vec2 b2 = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * sp;
		float xb = min(bone(b1, 0.52, 0.026), bone(b2, 0.52, 0.026));
		float emblem = min(skull, xb);
		float saa = fwidth(emblem);
		carve = max(carve, 1.0 - smoothstep(0.006, 0.016 + saa, abs(emblem)));
		float sockets = min(length(vec2(abs(sp.x) - 0.06, sp.y - 0.03)) - 0.042, length(sp - vec2(0.0, -0.05)) - 0.02);
		float hollow = (1.0 - smoothstep(-saa, saa, sockets)) * (1.0 - smoothstep(-saa, saa, skull));
		float raised = 1.0 - smoothstep(-saa, saa, emblem);
		// Lines of worn writing: words cut in rows under the skull.
		float text = 0.0;
		for (int i = 0; i < 4; i++) {
			float ly = 0.16 - float(i) * 0.18;
			float hw = i == 3 ? 0.18 : 0.4 - 0.1 * h(gid + float(i) * 3.7);
			float row_in = (1.0 - smoothstep(0.024, 0.034, abs(u.y - ly))) * (1.0 - smoothstep(hw - 0.02, hw, abs(u.x)));
			float wx = u.x / 0.17 + h(gid + float(i));
			float wl = 0.55 + 0.3 * h(vec2(floor(wx), float(i) + gr * 9.0));
			text = max(text, row_in * (1.0 - smoothstep(wl - 0.06, wl, fract(wx))));
		}
		// A crack right across some of them.
		float gc = 0.0;
		if (gr2 > 0.6) {
			float wig = (texture(grain, lp * 0.8 + gr).r - 0.5) * 0.16;
			float cl = lp.y - (gr - 0.5) * 1.1 - lp.x * (gr2 - 0.8) * 1.6 + wig;
			gc = 1.0 - smoothstep(0.0, 0.012 + fwidth(cl), abs(cl));
		}
		vec3 gcol = lime * (1.0 + 0.1 * raised);
		gcol *= 1.0 - 0.32 * carve;
		gcol *= 1.0 - 0.38 * text;
		gcol *= 0.8 + 0.2 * smoothstep(0.0, 0.07, -gd);   // its edges worn round
		gcol = mix(gcol, vec3(0.05, 0.045, 0.045), hollow * 0.85);
		gcol *= 1.0 - 0.6 * gc;
		gcol = mix(gcol, grime.rgb * (0.7 + 0.35 * fine), g * 0.35);
		c = mix(c, gcol, inside);
		c = mix(c, grout.rgb * 0.7, joint);
		gap *= 1.0 - inside;
		crack *= 1.0 - inside;
		rough = mix(rough, 0.72, inside);
		n = normalize(mix(n, vec3((gr - 0.5) * 0.08, 1.0, (gr2 - 0.5) * 0.08), inside));
	}

	// The Bone Chain in the middle of the room: a round dais of dark polished stone edged in
	// brass, a ring of chain links made of bone (oval rings, and bones seen edge-on joining
	// them) and the Skeleton King's crowned skull in relief.
	float R = length(pos);
	if (R < 2.1) {
		float raa = fwidth(R);
		float dais = 1.0 - smoothstep(1.98 - raa, 1.98 + raa, R);
		c = mix(c, vec3(0.13, 0.122, 0.145) * (0.9 + 0.2 * fine), dais);
		gap *= 1.0 - dais;
		crack *= 1.0 - dais;
		n = normalize(mix(n, vec3(0.0, 1.0, 0.0), dais));
		rough = mix(rough, 0.42, dais);
		const vec3 GOLD = vec3(0.7, 0.52, 0.2);
		float brass = max(1.0 - smoothstep(0.012, 0.026 + raa, abs(R - 1.96)), 1.0 - smoothstep(0.01, 0.022 + raa, abs(R - 1.2)));
		c = mix(c, GOLD * 0.8 * (0.8 + 0.3 * fine), brass);
		rough = mix(rough, 0.3, brass);
		// The chain: 8 oval links and 8 bones in turn, round R = 1.58.
		float a = atan(pos.y, pos.x);
		const float ST = 6.2831853 / 8.0;
		float af = floor(a / ST + 0.5) * ST;
		float ae = (floor(a / ST) + 0.5) * ST;
		vec2 pf = vec2(R * sin(a - af), R * cos(a - af) - 1.58);
		vec2 pe = vec2(R * sin(a - ae), R * cos(a - ae) - 1.58);
		float fl = abs(length(vec2(max(abs(pf.x) - 0.17, 0.0), pf.y)) - 0.12) - 0.04;
		float el = bone(pe, 0.62, 0.047);
		float laa = fwidth(fl) + fwidth(el);
		vec3 ivory = vec3(0.6, 0.55, 0.44) * (0.9 + 0.2 * fine);
		c *= 1.0 - 0.55 * (1.0 - smoothstep(0.0, 0.07, min(fl, el))) * dais;
		float fm = 1.0 - smoothstep(-laa, laa, fl);
		c = mix(c, ivory * (0.68 + 0.42 * smoothstep(0.0, -0.03, fl)), fm);
		// The bones lie over the rings they join: a dark edge round them, then the bone.
		c *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.03, el)) * fm;
		float em_ = 1.0 - smoothstep(-laa, laa, el);
		c = mix(c, ivory * (0.68 + 0.42 * smoothstep(0.0, -0.035, el)), em_);
		rough = mix(rough, 0.6, max(fm, em_));
		// The crowned skull, carved in relief and a little raised, looking at the camera.
		vec2 u = vec2(pos.x, -pos.y) / 1.25 + vec2(0.0, 0.18);
		float sk = smin(length(u - vec2(0.0, 0.1)) - 0.36, sd_box(u - vec2(0.0, -0.25), vec2(0.21, 0.13), 0.06), 0.1);
		float eye = length(vec2(abs(u.x) - 0.145, u.y - 0.04)) - 0.095;
		float nose = sd_box(u - vec2(0.0, -0.12), vec2(0.03, 0.045), 0.02);
		float mouth = sd_box(u - vec2(0.0, -0.3), vec2(0.16, 0.045), 0.01);
		float teeth = (1.0 - smoothstep(0.004, 0.011, abs(fract(u.x / 0.064) - 0.5) * 0.064)) * (1.0 - smoothstep(-0.004, 0.004, mouth));
		vec2 cp = u - vec2(0.0, 0.47);
		float crown = min(sd_box(u - vec2(0.0, 0.43), vec2(0.33, 0.06), 0.012),
			min(spike(cp, 0.12, 0.32), spike(vec2(abs(cp.x) - 0.24, cp.y), 0.1, 0.24)));
		float gems = min(length(u - vec2(0.0, 0.81)) - 0.04, length(vec2(abs(u.x) - 0.24, u.y - 0.73)) - 0.034);
		float kaa = fwidth(sk) * 1.25;
		float skin = 1.0 - smoothstep(-kaa, kaa, sk);
		float holes = max(1.0 - smoothstep(-kaa, kaa, eye), 1.0 - smoothstep(-kaa, kaa, nose));
		float cin = 1.0 - smoothstep(-kaa, kaa, crown);
		float gin = 1.0 - smoothstep(-kaa, kaa, gems);
		c *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.05, min(sk, crown))) * (1.0 - max(skin, cin));
		c = mix(c, vec3(0.47, 0.43, 0.36) * (0.75 + 0.35 * smoothstep(0.0, -0.12, sk)) * (0.9 + 0.2 * fine), skin);
		c = mix(c, vec3(0.04, 0.035, 0.04), max(holes, teeth * 0.7) * skin);
		c = mix(c, GOLD * (0.75 + 0.4 * smoothstep(0.0, -0.04, crown)), cin);
		c = mix(c, vec3(0.45, 0.06, 0.05), gin);
		rough = mix(rough, 0.55, skin);
		rough = mix(rough, 0.25, cin);
		// Candlelight in its eyes, flickering, and a glint on its gems.
		float eg = (1.0 - smoothstep(-0.03, 0.03, eye + 0.03)) * skin;
		float flick = 0.75 + 0.25 * sin(TIME * 5.3) * sin(TIME * 2.1 + 1.3);
		em += vec3(1.0, 0.55, 0.18) * eg * flick * 0.7;
		em += vec3(0.9, 0.12, 0.08) * gin * 0.25;
		em += GOLD * cin * 0.06;
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
	// Version 216 (review fix #11): the theme's colours now reach this floor (it used fixed
	// colours, so the v213 darker slate never showed).
	c *= tint.rgb;
	// Pale cracks between the plates, with a little white shatter beside each.
	float crk = 1.0 - smoothstep(0.012, 0.026 + fwidth(pe), pe);
	float shat = (1.0 - smoothstep(0.0, 0.16, pe)) * 0.22;
	// Version 159: softer cracks (were 0.85 and 0.22), so the bright web stops fighting the
	// white frost bolts and warnings for attention.
	shat *= 0.55;
	c = mix(c, vec3(0.55, 0.65, 0.76) * tint.rgb, max(crk * 0.25, shat));
	// Frost drifts in from the walls and lies in patches.
	float g = clamp(smoothstep(0.55, 0.85, big2 * 0.85 + (1.0 - smoothstep(0.0, 2.2, wall)) * 0.45) * grime_amount * 1.8, 0.0, 1.0);
	c = mix(c, grime.rgb * (0.85 + 0.3 * fine), g);
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
	gap = 1.0 - smoothstep(0.016, 0.026 + fwidth(he), he);   // thinner joints (version 162)
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
	em += spores.rgb * (th * 0.5 + glow_band * 0.35) * flow * spores.a;   // softer (version 162)
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
	float inlay = 1.0 - smoothstep(0.015 - aa, 0.015 + aa, ded);   // v218: half as wide
	const vec3 GOLD = vec3(0.45, 0.33, 0.12);   // v218: darker (the grid was 6.5% bright yellow)
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
#elif STYLE == 6
	// Frostfall Hall (the winter event): no stone at all. A great hall of dark timber, long
	// planks running door to door, snow blown in under the walls and lying in drifts, and
	// a long pine-green carpet with gold and crimson borders down the middle, woven with
	// gold snowflakes and a great star at the centre of the room.
	const float PW = 0.46;
	float pl = floor(pos.x / PW);
	float px = fract(pos.x / PW);
	float plen = 2.2 + 1.8 * h(vec2(pl, 2.1));
	float py = pos.y / plen + h(vec2(pl, 5.3));
	float pid = floor(py);
	float pfy = fract(py);
	r = h(vec2(pl, pid));
	float gr = texture(grain, vec2(pos.x * 1.3 + r * 5.0, pos.y * 0.08)).r;
	float gr2 = texture(blobs_a, vec2(pos.x * 0.7 + r * 3.0, pos.y * 0.045)).r;
	c = vec3(0.25, 0.155, 0.09) * (0.7 + 0.5 * r) * (0.8 + 0.4 * gr);
	c *= 0.88 + 0.24 * smoothstep(0.3, 0.7, gr2);
	// Now and then a dark knot in a plank.
	vec2 kp = vec2((px - 0.5) * PW, (pfy - h(vec2(pl, pid + 9.1))) * plen);
	float knot = (1.0 - smoothstep(0.03, 0.075, length(kp * vec2(1.0, 0.55)))) * step(0.55, h(vec2(pl, pid + 3.3)));
	c = mix(c, vec3(0.08, 0.045, 0.03), knot * 0.8);
	float ex = min(px, 1.0 - px) * PW;
	float ey = min(pfy, 1.0 - pfy) * plen;
	gap = max(1.0 - smoothstep(0.011, 0.02 + fwidth(ex), ex), 1.0 - smoothstep(0.008, 0.018 + fwidth(ey), ey));
	// Each plank is a little rounded: lit along its far edge, darker along its near one.
	c *= 1.0 + 0.14 * (1.0 - smoothstep(0.0, 0.06, ex)) * step(px, 0.5) - 0.18 * (1.0 - smoothstep(0.0, 0.06, ex)) * step(0.5, px);
	c *= tint.rgb;
	rough = 0.72;
	// The carpet.
	const float CW = 1.05;
	float cxa = abs(pos.x);
	float caa = fwidth(cxa) + 0.004;
	float carpet = (1.0 - smoothstep(CW - caa, CW + caa, cxa)) * (1.0 - ledge);
	vec3 cc = vec3(0.06, 0.15, 0.1) * (0.85 + 0.3 * fine) * (0.9 + 0.2 * texture(grain, pos * 1.7).r);
	const vec3 CGOLD = vec3(0.55, 0.41, 0.16);
	const vec3 CRED = vec3(0.36, 0.05, 0.06);
	cc = mix(cc, CRED * (0.85 + 0.3 * fine), smoothstep(CW - 0.13 - caa, CW - 0.13 + caa, cxa));
	cc = mix(cc, CGOLD, 1.0 - smoothstep(0.018, 0.018 + caa, abs(cxa - (CW - 0.15))));
	cc = mix(cc, CGOLD * 0.8, 1.0 - smoothstep(0.008, 0.008 + caa, abs(cxa - (CW - 0.24))));
	// Gold snowflakes woven down the middle, and a great star at the centre of the room.
	float R0 = length(pos);
	float sy = (fract(pos.y / 1.9 + 0.5) - 0.5) * 1.9;
	vec2 fp = R0 < 1.6 ? pos : vec2(pos.x, sy);
	float fs = R0 < 1.6 ? 1.0 : 0.3;
	float flake = 9.0;
	if (carpet > 0.0 && length(fp) < fs * 0.8) {
		for (int k = 0; k < 6; k++) {
			float an = float(k) * 1.0471976;
			vec2 d = vec2(cos(an), sin(an));
			vec2 nn = vec2(-d.y, d.x);
			flake = min(flake, seg(fp, vec2(0.0), d * fs * 0.62) - fs * 0.035);
			vec2 bp = d * fs * 0.36;
			flake = min(flake, seg(fp, bp, bp + (d * 0.5 + nn * 0.866) * fs * 0.18) - fs * 0.028);
			flake = min(flake, seg(fp, bp, bp + (d * 0.5 - nn * 0.866) * fs * 0.18) - fs * 0.028);
		}
		flake = min(flake, length(fp) - fs * 0.09);
	}
	float faa = fwidth(flake) + 0.002;
	float woven = 1.0 - smoothstep(-faa, faa, flake);
	cc = mix(cc, CGOLD * (0.85 + 0.25 * fine), woven * (R0 < 1.6 ? 0.8 : 0.7));
	c = mix(c, cc, carpet);
	rough = mix(rough, 0.95, carpet);
	gap *= 1.0 - carpet;
	c = mix(c, grout.rgb, gap);
	// Snow: drifted deep under the walls with a wind-blown edge, and in a few patches (none
	// on the carpet, which is swept).
	// Version 243: kept off the middle of the hall and blue-grey there (white snow under the
	// fight hid the white skeletons); bright only in the drifts against the walls.
	float drift = 1.0 - smoothstep(0.2, 0.9 + 0.9 * big, wall);
	float patchy = smoothstep(0.74, 0.86, big2) * (1.0 - carpet);
	float snow = clamp(max(drift, patchy * 0.85) * grime_amount * 1.3, 0.0, 1.0);
	snow *= smoothstep(0.2, 0.5, snow + fine * 0.35);
	vec3 sc = grime.rgb * (0.86 + 0.28 * fine) * mix(0.62, 1.0, drift);
	c = mix(c, sc, snow);
	rough = mix(rough, 0.55, snow);
	gap *= 1.0 - snow;
	// A little greyer, so heroes, skeletons and their shots stand out.
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.88);
	n = normalize(vec3((r - 0.5) * 0.04, 1.0, (h(vec2(pl, pid + 1.7)) - 0.5) * 0.04));
#elif STYLE == 7
	// The Sandfall Tomb (floor 5, version 247): great squared blocks of sandstone, every
	// other column shifted by half a block, about one in four carved with a sign (an eye, a
	// sun, water, a beetle), some of them still painted turquoise. A processional way of
	// darker, redder stone runs down the middle between two inlaid borders of turquoise and
	// lapis triangles, and a winged sun is inlaid at the centre of the room. Sand has blown
	// in: rippled dunes along the walls, fans of it where it pours in through the cracks (the
	// side walls, see props.gd) and grit in the joints.
	const vec3 TURQ = vec3(0.1, 0.33, 0.31);
	const vec3 LAPIS = vec3(0.06, 0.09, 0.22);
	const vec3 GOLD = vec3(0.42, 0.31, 0.12);
	const float WAY = 1.38;
	const float BW = 1.46;
	float ax = abs(pos.x);
	vec2 bsz = vec2(BW);
	vec2 s;
	if (ax < WAY) {
		bsz = vec2(WAY, 0.72);
		s = vec2((pos.x + WAY) / WAY, pos.y / 0.72 + 0.5 * step(0.0, pos.x));
	} else {
		float colx = (ax - 1.62) / BW;
		s = vec2(colx, pos.y / BW + 0.5 * mod(floor(colx), 2.0) + 0.25);
	}
	vec2 cell = floor(s) + vec2(step(pos.x, 0.0) * step(WAY, ax) * 20.0, 0.0);
	vec2 f = fract(s) - 0.5;
	vec2 e = (0.5 - abs(f)) * bsz;
	float edge = min(e.x, e.y);
	r = h(cell);
	float r2 = h(cell + 13.7);
	vec3 stone = ax < WAY ? vec3(0.27, 0.18, 0.13) : vec3(0.34, 0.27, 0.19);
	stone *= mix(vec3(1.0), vec3(1.07, 0.96, 0.9), step(0.6, r2));
	c = stone * (0.8 + 0.3 * r) * (0.9 + 0.2 * fine) * tint.rgb;
	c *= mix(1.0, 1.07, smoothstep(0.55, 0.85, big));
	rough = 0.8;
	float aa = fwidth(edge);
	gap = 1.0 - smoothstep(0.02 - aa, 0.02 + aa, edge);
	float a = r2 * 3.1416;
	vec2 dir = vec2(cos(a), sin(a));
	float off = dot(f, vec2(-dir.y, dir.x)) + 0.035 * sin(dot(f, dir) * 13.0 + r * 30.0);
	crack = (1.0 - smoothstep(0.0, 0.01 + fwidth(off), abs(off))) * step(0.86, r) * step(WAY, ax)
		* (1.0 - smoothstep(0.25, 0.45, abs(dot(f, dir))));
	float rim_hi = max((1.0 - smoothstep(0.03, 0.1, e.y)) * step(f.y, 0.0), (1.0 - smoothstep(0.03, 0.1, e.x)) * step(f.x, 0.0));
	float rim_lo = max((1.0 - smoothstep(0.03, 0.12, e.y)) * step(0.0, f.y), (1.0 - smoothstep(0.03, 0.12, e.x)) * step(0.0, f.x));
	c *= 1.0 + 0.2 * rim_hi - 0.26 * rim_lo;
	vec2 bevel = sign(f) * (1.0 - smoothstep(0.0, 0.08, e)) * 0.6;
	n = normalize(vec3(bevel.x + (r - 0.5) * 0.08, 1.0, bevel.y + (r2 - 0.5) * 0.08));
	bool middle = ax < 3.4 && abs(pos.y) < 1.15;
	// A carved sign in about one block in four (none on the way or round the winged sun).
	if (ax >= 1.62 && !middle && h(cell + 31.0) > 0.74) {
		vec2 g = f * bsz;
		float kind = floor(h(cell + 47.0) * 4.0);
		float d = 9.0;
		if (kind < 1.0) {
			// An eye: an almond outline, the pupil, and a curl below.
			float lid = max(length(g - vec2(0.0, 0.19)) - 0.26, length(g + vec2(0.0, 0.19)) - 0.26);
			d = min(abs(lid) - 0.018, length(g) - 0.055);
			d = min(d, seg(g, vec2(0.02, 0.07), vec2(-0.03, 0.2)) - 0.016);
		} else if (kind < 2.0) {
			// A sun: a disc in a ring, with eight short rays.
			float R = length(g);
			d = min(abs(R - 0.13) - 0.018, R - 0.06);
			float an = atan(g.y, g.x);
			float k8 = round(an / 0.7853982) * 0.7853982;
			vec2 gr = vec2(cos(-k8) * g.x - sin(-k8) * g.y, sin(-k8) * g.x + cos(-k8) * g.y);
			d = min(d, seg(gr, vec2(0.18, 0.0), vec2(0.27, 0.0)) - 0.016);
		} else if (kind < 3.0) {
			// Water: three zigzag lines.
			for (int k = 0; k < 3; k++) {
				float yv = float(k - 1) * 0.1 + 0.035 * (abs(fract(g.x * 5.0) - 0.5) * 4.0 - 1.0);
				d = min(d, max(abs(g.y - yv) - 0.014, abs(g.x) - 0.24));
			}
		} else {
			// A beetle: a round body split down the back, a head and six legs.
			vec2 gb = vec2(abs(g.x), g.y);
			d = abs(length(g / vec2(0.13, 0.16)) - 1.0) * 0.13 - 0.014;
			d = min(d, max(abs(g.x) - 0.012, abs(g.y - 0.0) - 0.15));
			d = min(d, length(g + vec2(0.0, 0.21)) - 0.055);
			for (int k = 0; k < 3; k++) {
				float ly = float(k - 1) * 0.09;
				d = min(d, seg(gb, vec2(0.12, ly), vec2(0.21, ly + 0.05 * float(k - 1) - 0.03)) - 0.012);
			}
		}
		float ad = fwidth(d) + 0.002;
		float carve = 1.0 - smoothstep(-ad, ad, d);
		vec3 deep = h(cell + 5.0) > 0.5 ? TURQ * 0.85 : c * 0.45;
		c = mix(c, deep, carve);
		rough = mix(rough, 0.95, carve);
		crack *= 1.0 - carve;
	}
	// The borders of the way: lapis triangles on turquoise between thin gold lines.
	if (ax >= WAY && ax < 1.62) {
		float bx = ax - 1.5;
		float tri = abs(fract(pos.y / 0.24) - 0.5) * 2.0;
		float ba = fwidth(bx) + 0.003;
		float inner = 1.0 - smoothstep(-ba, ba, (bx + 0.085) / 0.17 - (1.0 - tri));
		vec3 bc = mix(TURQ * (0.9 + 0.2 * fine), LAPIS, inner);
		bc = mix(bc, GOLD, 1.0 - smoothstep(0.01, 0.01 + ba, abs(abs(bx) - 0.1)));
		bc = mix(bc, grout.rgb, 1.0 - smoothstep(0.0, ba * 2.0, 0.12 - abs(bx)));
		c = bc;
		gap = 0.0;
		crack = 0.0;
		rough = 0.5;
		n = vec3(0.0, 1.0, 0.0);
	}
	// The winged sun at the middle of the room: a gold disc in a ring, and two great wings
	// of gold, turquoise and lapis feathers spread towards the side walls.
	if (middle) {
		float R = length(pos);
		float aR = fwidth(R) + 0.004;
		float disc = 1.0 - smoothstep(0.5 - aR, 0.5 + aR, R);
		float ring = 1.0 - smoothstep(0.03, 0.03 + aR, abs(R - 0.58));
		float u = clamp((ax - 0.66) / 2.6, 0.0, 1.0);
		float yc = -0.24 * sin(u * 3.1416) + 0.04;
		float hw = 0.42 * pow(1.0 - u, 0.6) + 0.05;
		float yy = pos.y - yc;
		float tips = 0.06 * abs(sin(ax * 9.4248));
		float wd = max(-hw - yy, yy - hw + tips);
		float wa = fwidth(wd) + 0.003;
		float wing = step(0.66, ax) * (1.0 - smoothstep(-wa, wa, wd)) * (1.0 - smoothstep(3.2, 3.26, ax));
		float v = clamp((yy + hw) / (2.0 * hw), 0.0, 1.0);
		vec3 wc = v < 0.3 ? GOLD * (0.85 + 0.3 * step(0.5, fract(ax * 7.0))) : (v < 0.52 ? TURQ : LAPIS);
		float quill = (1.0 - smoothstep(0.02, 0.05, abs(fract(ax * 5.0) - 0.5) * 0.4)) * step(0.52, v);
		wc = mix(wc, TURQ * 1.1, quill);
		wc = mix(wc, GOLD * 1.15, 1.0 - smoothstep(0.0, wa * 2.0, -wd - 0.025));
		c = mix(c, wc * (0.92 + 0.16 * fine), wing);
		c = mix(c, GOLD * (0.85 + 0.3 * texture(blobs_a, pos * 0.5).r), disc);
		c = mix(c, LAPIS, disc * (1.0 - smoothstep(0.02, 0.02 + aR, abs(R - 0.3))));
		c = mix(c, GOLD * 1.25, ring);
		float inl = max(max(wing, disc), ring);
		rough = mix(rough, 0.42, inl);
		gap *= 1.0 - inl;
		crack *= 1.0 - inl;
		em += GOLD * ring * 0.15;
	}
	// Sand: dunes along the walls, fans under the cracks it pours from, a few patches, and
	// grit in the joints. Rippled by the wind; bright only by the walls, so skeletons still
	// stand out on it in the middle of the room.
	float drift = 1.0 - smoothstep(0.25, 0.9 + 1.3 * big, wall);
	vec2 fp = vec2(ax - (half_size.x - 0.35), abs(pos.y) - 3.0);
	float fan = 1.0 - smoothstep(0.15, 1.1 + 0.8 * big2, length(fp * vec2(1.0, 0.7)));
	float patchy = smoothstep(0.78, 0.9, big2) * 0.75 * (1.0 - step(ax, 3.4) * step(abs(pos.y), 1.15));
	float sand = clamp(max(max(drift, fan), patchy) * grime_amount * 1.25, 0.0, 1.0);
	sand *= smoothstep(0.15, 0.45, sand + fine * 0.3);
	float rip = sin((wall + big * 0.7) * 22.0 + fine * 2.0);
	vec3 sc = grime.rgb * (0.88 + 0.2 * fine) * (0.92 + 0.1 * rip) * mix(0.72, 1.0, max(drift, fan));
	c = mix(c, mix(grout.rgb, grime.rgb * 0.6, smoothstep(0.35, 0.75, big2 + fine * 0.3)), gap);
	c = mix(c, sc, sand);
	rough = mix(rough, 0.95, sand);
	gap *= 1.0 - sand;
	crack *= 1.0 - sand;
	c *= 1.0 - crack * 0.5;
	n = normalize(mix(n, vec3(rip * 0.12, 1.0, 0.0), sand));
	// Greyer and darker, so heroes, skeletons and their shots stand out (the first try was
	// twice as bright as the other floors and glowed orange).
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.72) * 0.8;
#elif STYLE == 8
	// The Amethyst Mine (floor 7, version 248): no laid floor but the bare rock of a mine,
	// broken into rough slabs worn smooth, gravel and dust between them and in drifts, thin
	// veins of amethyst glowing in the rock and crystal glints by the walls, and the tracks of
	// the mine carts: iron rails on timber sleepers down the middle of the room, and a spur
	// curving away to a buffer by the right-hand wall.
	vec2 id;
	vec2 vd = cells(pos / 1.6, id);
	r = h(id);
	float pe = (vd.y - vd.x) * 1.6;
	c = vec3(0.25, 0.245, 0.255) * (0.8 + 0.35 * r) * (0.9 + 0.2 * fine) * tint.rgb;
	c *= mix(vec3(1.0), vec3(1.08, 1.02, 0.92), step(0.6, h(id + 4.0)));
	c *= 0.86 + 0.22 * smoothstep(0.0, 0.5, pe);
	float ga = fwidth(pe);
	gap = 1.0 - smoothstep(0.03 - ga, 0.06 + ga, pe);
	rough = 0.85;
	float dust = smoothstep(0.62, 0.85, big2) * grime_amount + (1.0 - smoothstep(0.3, 1.4 + big, wall)) * 0.8;
	vec3 grav = grime.rgb * (0.7 + 0.55 * texture(grain, pos * 1.3).r);
	c = mix(c, grav, clamp(max(gap * 0.85, dust * 0.75), 0.0, 1.0));
	rough = mix(rough, 0.95, dust);
	// Amethyst veins in a few places, glowing softly and slowly.
	float vn = texture(blobs_a, pos * 0.09 + vec2(0.3, 0.7)).r;
	float vein = (1.0 - smoothstep(0.0, 0.008 + fwidth(vn), abs(vn - 0.5))) * smoothstep(0.66, 0.78, big) * (1.0 - dust * 0.8);
	c = mix(c, spores.rgb * 0.3, vein * 0.8);
	em += spores.rgb * vein * (0.25 + 0.2 * sin(TIME * 0.9 + pos.x * 0.7 + pos.y * 0.3)) * spores.a;
	// Crystal glints in the gravel by the walls.
	vec2 gq = pos * 2.4;
	vec2 gqc = floor(gq);
	float gs = h(gqc + 2.7);
	float gd = length(gq - gqc - 0.5 - (vec2(h(gqc + 1.3), h(gqc + 8.1)) - 0.5) * 0.6);
	float glint = (1.0 - smoothstep(0.05, 0.1 + fwidth(gd), gd)) * step(0.82, gs) * (1.0 - smoothstep(0.6, 1.8, wall));
	c = mix(c, spores.rgb * 0.6, glint);
	em += spores.rgb * glint * (0.6 + 0.4 * sin(TIME * (1.5 + gs * 2.0) + gs * 40.0)) * spores.a;
	// The tracks: the main line, and the spur round a circle (centre C, radius 4.1) from the
	// main line at z = -3 to its buffer by the right-hand wall.
	vec4 tk = vec4(0.0);
	float ballast = 0.0;
	if (abs(pos.x) < 1.1) {
		tk = track(pos, fine);
		ballast = 1.0 - smoothstep(0.85, 1.05, abs(pos.x));
	}
	vec2 sc0 = pos - vec2(4.6, -3.0);
	float sR = length(sc0);
	if (sc0.y > -0.1 && sc0.x < 0.3 && abs(sR - 4.1) < 1.1) {
		float th = atan(sc0.y, sc0.x);
		vec4 t2 = track(vec2(sR - 4.1, (3.1415927 - th) * 4.1), fine);
		t2.a *= step(-0.1, sc0.y);
		ballast = max(ballast, (1.0 - smoothstep(0.85, 1.05, abs(sR - 4.1))) * step(0.0, sc0.y));
		if (t2.a > tk.a) tk = t2;
		// The buffer at its end: a heavy timber beam across the track.
		float endb = step(0.12, sc0.x) * (1.0 - step(0.34, sc0.x)) * (1.0 - smoothstep(0.82, 0.86, abs(sR - 4.1)));
		vec3 bw = vec3(0.26, 0.16, 0.09) * (0.8 + 0.4 * fine) * (0.8 + 0.4 * smoothstep(0.34, 0.2, sc0.x));
		tk = mix(tk, vec4(bw, 1.0), endb);
		tk.a *= 1.0 - step(0.34, sc0.x);
	}
	c = mix(c, grav * 0.75, ballast * 0.7);
	c = mix(c, tk.rgb, tk.a);
	rough = mix(rough, 0.55, tk.a);
	gap *= 1.0 - max(ballast, tk.a);
	dust *= 1.0 - tk.a;
	n = normalize(vec3((r - 0.5) * 0.12, 1.0, (h(id + 1.7) - 0.5) * 0.12));
	// A little greyer and darker, so heroes, skeletons and their shots stand out.
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.7);
#elif STYLE == 9
	// The Whispering Library (floor 8, version 249): a floor of oak blocks laid in
	// herringbone, darkened and worn, two old rugs (oxblood with a navy border and a
	// medallion) and, in the middle of the room, a brass circle set into the wood: two rings
	// with letters between them that glow and fade as if the words were being whispered,
	// round an eight-pointed star.
	// Blocks 0.15 m wide and four times as long, at 45 degrees to the room. In the blocks'
	// own grid each diagonal band of 2N squares holds a staircase of N-long blocks lying
	// one way and N-long blocks standing the other.
	const float PW = 0.15;
	const float PN = 4.0;
	vec2 q = vec2(pos.x + pos.y, pos.y - pos.x) * 0.70710678 / PW;
	vec2 qi = floor(q);
	float kb = floor((qi.y - qi.x + PN - 1.0) / (2.0 * PN));
	float qy = q.y - 2.0 * PN * kb;
	float jj = qi.y - 2.0 * PN * kb;
	float along;
	float across;
	vec2 pid;
	bool lying = jj - qi.x <= 0.0;
	if (lying) {
		along = q.x - jj;
		across = qy - jj;
		pid = vec2(jj, kb * 2.0);
	} else {
		along = qy - qi.x - 1.0;
		across = q.x - qi.x;
		pid = vec2(qi.x, kb * 2.0 + 1.0);
	}
	r = h(pid);
	float r2 = h(pid + 13.7);
	vec2 gp = lying ? vec2(q.x * 0.1, q.y * 1.2) : vec2(q.x * 1.2, q.y * 0.1);
	float gr = texture(grain, gp + vec2(r * 7.0, r2 * 5.0)).r;
	c = mix(vec3(0.23, 0.135, 0.07), vec3(0.36, 0.215, 0.115), r) * (0.78 + 0.42 * gr);
	c *= mix(vec3(1.0), vec3(0.92, 0.95, 1.05), step(0.7, r2));
	c *= tint.rgb;
	float ex = min(across, 1.0 - across) * PW;
	float ey = min(along, PN - along) * PW;
	float eaa = fwidth(ex) + fwidth(ey) * 0.5;
	gap = 1.0 - smoothstep(0.004, 0.009 + eaa, min(ex, ey));
	// Each block a little bevelled: its far edges catch the light.
	c *= 1.0 + 0.12 * (1.0 - smoothstep(0.0, 0.03, min(ex, ey)));
	rough = 0.55;
	// Worn and dull in patches, dusty by the walls.
	float wear = smoothstep(0.6, 0.85, big2);
	c = mix(c, c * vec3(1.1, 1.05, 0.95) + 0.025, wear * 0.5);
	rough = mix(rough, 0.85, wear);
	float dusty = (1.0 - smoothstep(0.2, 1.6 + big, wall)) * grime_amount;
	c = mix(c, grime.rgb * (0.8 + 0.4 * fine), dusty * 0.6);
	c = mix(c, grout.rgb, gap);
	// The rugs: one in each half of the room, across it.
	for (int k = 0; k < 2; k++) {
		vec2 rc = vec2(0.0, k == 0 ? -5.7 : 5.5);
		vec2 rp = pos - rc;
		vec2 ra = abs(rp);
		const vec2 RH = vec2(2.35, 1.45);
		float fringe = step(RH.x, ra.x) * (1.0 - step(RH.x + 0.11, ra.x)) * step(ra.y, RH.y - 0.04);
		float tassel = fringe * step(0.45, fract(rp.y / 0.06 + 0.25)) * (1.0 - smoothstep(0.07, 0.11, ra.x - RH.x + 0.03 * fine));
		float inside = step(ra.x, RH.x) * step(ra.y, RH.y);
		if (inside > 0.5) {
			float eb = min(RH.x - ra.x, RH.y - ra.y);
			float baa = fwidth(eb) + 0.003;
			const vec3 OX = vec3(0.26, 0.07, 0.06);
			const vec3 NAVY = vec3(0.05, 0.07, 0.15);
			const vec3 GOLD = vec3(0.5, 0.37, 0.14);
			const vec3 CREAM = vec3(0.55, 0.48, 0.36);
			vec3 rcol = OX * (0.85 + 0.3 * fine);
			// A small woven lattice of diamonds in the field.
			vec2 lp = rp / 0.22;
			float lat = abs(fract(lp.x + lp.y) - 0.5) + abs(fract(lp.x - lp.y) - 0.5);
			rcol *= 0.95 + 0.09 * smoothstep(0.42, 0.5, lat);
			// The medallion: a navy lozenge outlined in gold with a cream rosette inside.
			float lz = ra.x / 1.25 + ra.y / 0.8;
			float laa = fwidth(lz) + 0.004;
			rcol = mix(rcol, NAVY * (0.85 + 0.3 * fine), 1.0 - smoothstep(1.0 - laa, 1.0 + laa, lz));
			rcol = mix(rcol, GOLD, 1.0 - smoothstep(0.02, 0.02 + laa, abs(lz - 1.0)));
			rcol = mix(rcol, GOLD * 0.9, 1.0 - smoothstep(0.015, 0.015 + laa, abs(lz - 0.62)));
			float ros = length(rp * vec2(1.0, 1.25));
			float pet = ros - 0.22 - 0.06 * cos(atan(rp.y, rp.x) * 8.0);
			rcol = mix(rcol, CREAM * (0.85 + 0.3 * fine), 1.0 - smoothstep(-0.01, 0.01, pet));
			rcol = mix(rcol, OX, 1.0 - smoothstep(0.05, 0.07, ros));
			// Corner pieces: a quarter lozenge in each corner of the field.
			vec2 cq = vec2(RH.x - 0.3 - ra.x, RH.y - 0.3 - ra.y);
			float cl = cq.x / 0.8 + cq.y / 0.5;
			rcol = mix(rcol, NAVY * (0.85 + 0.3 * fine), (1.0 - smoothstep(1.0 - laa, 1.0 + laa, cl)) * step(0.0, cq.x) * step(0.0, cq.y));
			// The border: navy with a gold line either side and a row of cream dots.
			float bd = 1.0 - smoothstep(0.3 - baa, 0.3 + baa, eb);
			vec3 bcol = NAVY * (0.85 + 0.3 * fine);
			float along_b = ra.x > RH.x - 0.3 && RH.x - ra.x < RH.y - ra.y ? rp.y : rp.x;
			float dot_b = length(vec2((fract(along_b / 0.16) - 0.5) * 0.16, eb - 0.15)) - 0.035;
			bcol = mix(bcol, CREAM, 1.0 - smoothstep(-0.006, 0.006, dot_b));
			rcol = mix(rcol, bcol, bd);
			rcol = mix(rcol, GOLD, 1.0 - smoothstep(0.012, 0.012 + baa, abs(eb - 0.3)));
			rcol = mix(rcol, GOLD * 0.8, 1.0 - smoothstep(0.01, 0.01 + baa, abs(eb - 0.04)));
			// Worn thin in places, the weave showing pale.
			rcol = mix(rcol, CREAM * 0.55, smoothstep(0.68, 0.8, texture(blobs_a, pos * 0.11 + vec2(0.2 * float(k), 0.4)).r) * 0.5);
			c = mix(c, rcol, inside);
			rough = mix(rough, 0.95, inside);
			gap *= 1.0 - inside;
		}
		c = mix(c, vec3(0.5, 0.45, 0.36) * (0.8 + 0.3 * fine), tassel);
	}
	// The brass circle in the middle: rings at 1.62 and 1.36 m, letters between them, and an
	// eight-pointed star inside, all brass set into the wood.
	float R0 = length(pos);
	if (R0 < 1.75) {
		const vec3 BRASS = vec3(0.55, 0.41, 0.17);
		float raa = fwidth(R0) + 0.003;
		float ring = max(1.0 - smoothstep(0.028, 0.028 + raa, abs(R0 - 1.62)), 1.0 - smoothstep(0.018, 0.018 + raa, abs(R0 - 1.36)));
		ring = max(ring, 1.0 - smoothstep(0.014, 0.014 + raa, abs(R0 - 0.55)));
		// The star: eight points, the long ones on the room's axes.
		float an = atan(pos.y, pos.x);
		float sa = abs(fract(an / 0.78539816 + 0.5) - 0.5) * 0.78539816;
		float tip = mod(floor(an / 0.78539816 + 0.5), 2.0) < 0.5 ? 1.3 : 0.9;
		vec2 sp = vec2(cos(sa), sin(sa)) * R0;
		float star = seg(sp, vec2(0.0), vec2(tip, 0.0)) - 0.012 - 0.1 * max(0.0, 1.0 - sp.x / tip) * step(sp.x, tip);
		float spoke = 1.0 - smoothstep(-0.004, 0.004 + raa, abs(star + 0.012) - 0.012);
		float starfill = 1.0 - smoothstep(-0.004, 0.004 + raa, star);
		c = mix(c, c * 0.72, starfill * (1.0 - spoke));
		// The letters: 36 marks round the band, each a few short strokes of its own.
		float cell = floor((an + 3.1415927) / 6.2831853 * 36.0);
		float ca = (cell + 0.5) / 36.0 * 6.2831853 - 3.1415927;
		vec2 cdir = vec2(cos(ca), sin(ca));
		vec2 cp = vec2(dot(pos, vec2(-cdir.y, cdir.x)), R0 - 1.49);
		float glyph = 9.0;
		for (int g = 0; g < 3; g++) {
			float hg = h(vec2(cell, float(g) + 3.0));
			vec2 a0 = (vec2(h(vec2(cell, float(g))), hg) - 0.5) * vec2(0.13, 0.16);
			vec2 a1 = a0 + vec2(cos(hg * 6.28), sin(hg * 6.28)) * 0.09;
			glyph = min(glyph, seg(cp, a0, a1) - 0.011);
		}
		float letter = (1.0 - smoothstep(-0.003, 0.003 + raa, glyph)) * step(abs(cp.y), 0.11);
		// A whisper runs round the ring, lighting the letters as it passes.
		float wave = pow(0.5 + 0.5 * sin(an * 2.0 - TIME * 0.9), 6.0) + 0.25;
		float brass = max(max(ring, spoke), letter);
		c = mix(c, BRASS * (0.8 + 0.4 * fine), brass);
		rough = mix(rough, 0.35, brass);
		gap *= 1.0 - brass;
		em += spores.rgb * letter * wave * 0.55 * spores.a;
		c = mix(c, mix(BRASS, spores.rgb, 0.5), letter * wave * 0.5);
	}
	n = normalize(vec3((r - 0.5) * 0.05, 1.0, (r2 - 0.5) * 0.05));
	// A little greyer and darker, so heroes, skeletons and their shots stand out.
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.78) * 0.92;
#elif STYLE == 10
	// The Clockwork Foundry (floor 9, version 250): a floor of iron plates 2 m by 1.5 m in
	// staggered rows, riveted along their edges, one in three with a raised diamond tread;
	// rust in patches and dark oil stains. Long grates run down both sides with the furnaces
	// glowing and flickering under them. In the middle a great brass gear is set into the
	// floor, turning slowly, and two copper gears either side of it turn the other way.
	const vec2 PL = vec2(2.0, 1.5);
	float prow = floor(pos.y / PL.y);
	vec2 ps2 = vec2(pos.x / PL.x + 0.5 * mod(prow, 2.0), pos.y / PL.y);
	vec2 pc = floor(ps2);
	vec2 pf = fract(ps2) - 0.5;
	vec2 pe = (0.5 - abs(pf)) * PL;
	float pedge = min(pe.x, pe.y);
	r = h(pc);
	float r2 = h(pc + 13.7);
	c = vec3(0.21, 0.22, 0.24) * (0.82 + 0.3 * r) * (0.88 + 0.24 * fine) * tint.rgb;
	if (r2 > 0.66) {
		// Tread plate: raised diamonds, each row turned the other way.
		vec2 tq = pos / vec2(0.12, 0.12);
		vec2 tr = fract(tq) - 0.5;
		float odd = mod(floor(tq.x) + floor(tq.y), 2.0);
		vec2 tl = odd > 0.5 ? vec2(tr.x + tr.y, tr.x - tr.y) : vec2(tr.x - tr.y, tr.x + tr.y);
		float bump = 1.0 - smoothstep(0.06, 0.1, length(vec2(tl.x * 0.3, tl.y)));
		c *= 0.92 + 0.32 * bump;
	}
	float paa = fwidth(pedge);
	gap = 1.0 - smoothstep(0.012 - paa, 0.02 + paa, pedge);
	c *= 1.0 + 0.14 * (1.0 - smoothstep(0.02, 0.07, pedge));
	float rx = (fract(pos.x / 0.25) - 0.5) * 0.25;
	float ry = (fract(pos.y / 0.25) - 0.5) * 0.25;
	float rv1 = length(vec2(rx, pe.y - 0.08));
	float rv2 = length(vec2(ry, pe.x - 0.08));
	float rvd = min(rv1 + step(pe.x, 0.12) * 9.0, rv2 + step(pe.y, 0.12) * 9.0);
	float rivet = 1.0 - smoothstep(0.022, 0.03, rvd);
	c = mix(c, vec3(0.3, 0.31, 0.33) * (1.0 + 0.4 * smoothstep(0.025, 0.0, rvd)), rivet);
	rough = 0.5;
	// Rust and oil.
	float rust = smoothstep(0.6, 0.82, big) * grime_amount * (0.6 + 0.6 * fine);
	c = mix(c, grime.rgb * (0.7 + 0.5 * fine), clamp(rust, 0.0, 0.7));
	rough = mix(rough, 0.9, rust);
	float oil = smoothstep(0.81, 0.84, big2 + fine * 0.04);
	float sheen = 0.5 + 0.5 * sin(big2 * 140.0 + fine * 6.0);
	c = mix(c, mix(vec3(0.07, 0.06, 0.06), vec3(0.16, 0.13, 0.2), sheen * 0.5), oil * 0.6);
	rough = mix(rough, 0.15, oil);
	// Darker and sooty by the walls.
	c *= mix(0.75, 1.0, smoothstep(0.0, 1.8, wall));
	c = mix(c, grout.rgb, gap);
	// The grates down both sides: iron bars over a pit with the fire glowing in it.
	float gx = abs(pos.x) - 4.25;
	if (abs(gx) < 0.45 && abs(pos.y) < 7.2) {
		float ge = min(0.45 - abs(gx), 7.2 - abs(pos.y));
		float frame = 1.0 - smoothstep(0.06, 0.075, ge);
		float bx = abs(fract(pos.y / 0.14) - 0.5);
		bar = (1.0 - smoothstep(0.16, 0.22, bx)) * (1.0 - frame);
		pit = 1.0 - frame;
		float heat = 0.55 + 0.45 * sin(TIME * 2.3 + pos.y * 0.8) * sin(TIME * 1.1 + pos.y * 0.37);
		vec3 deep = mix(vec3(0.03, 0.015, 0.01), spores.rgb * 0.5, 0.6 + 0.4 * heat);
		c = mix(c, deep, pit * (1.0 - bar));
		c = mix(c, vec3(0.12, 0.12, 0.13) * (0.8 + 0.4 * fine), bar);
		c = mix(c, vec3(0.24, 0.24, 0.26) * (0.85 + 0.3 * fine), frame);
		em += spores.rgb * pit * (1.0 - bar) * (0.35 + 0.5 * heat) * spores.a;
		em += spores.rgb * bar * 0.06 * heat;
		gap = 0.0;
	}
	// The gears: a great brass one in the middle (24 teeth) and a copper one either side
	// (10 teeth) meshing with it, turning the other way, 2.4 times as fast (24 / 10).
	float spin = TIME * 0.12;
	for (int gi = 0; gi < 3; gi++) {
		vec2 gcen = gi == 0 ? vec2(0.0) : vec2(gi == 1 ? -2.22 : 2.22, 0.0);
		float GR = gi == 0 ? 1.5 : 0.62;
		float NT = gi == 0 ? 24.0 : 10.0;
		float ga = gi == 0 ? spin : -spin * 2.4 + 3.1415927 / NT;
		vec2 gp2 = pos - gcen;
		float gr = length(gp2);
		if (gr > GR + 0.3) {
			continue;
		}
		float gan = atan(gp2.y, gp2.x) - ga;
		float tooth = clamp(cos(gan * NT) * 2.6 + 0.2, 0.0, 1.0);
		float outer = GR + 0.12 * tooth;
		float gaa = fwidth(gr) + 0.004;
		float body = 1.0 - smoothstep(outer - gaa, outer + gaa, gr);
		// The rim, the spokes and the hub; the holes between the spokes show the dark pit.
		float rim = smoothstep(GR * 0.72 - gaa, GR * 0.72 + gaa, gr);
		float spokes = gi == 0 ? 6.0 : 4.0;
		float sp = abs(fract(gan * spokes / 6.2831853 + 0.5) - 0.5) * 6.2831853 / spokes * gr;
		float spoke = 1.0 - smoothstep(GR * 0.09 - gaa, GR * 0.09 + gaa, sp);
		float hub = 1.0 - smoothstep(GR * 0.24 - gaa, GR * 0.24 + gaa, gr);
		float metal = body * max(max(rim, spoke), hub);
		float axle = 1.0 - smoothstep(GR * 0.08 - gaa, GR * 0.08 + gaa, gr);
		vec3 gcol = gi == 0 ? vec3(0.56, 0.41, 0.17) : vec3(0.5, 0.26, 0.13);
		gcol *= 0.8 + 0.3 * fine;
		// Lit along the rim's edges and the hub's ring.
		gcol *= 1.0 + 0.25 * (1.0 - smoothstep(0.0, 0.05, abs(gr - GR * 0.72))) + 0.25 * (1.0 - smoothstep(0.0, 0.04, abs(gr - GR * 0.24)));
		// The slot it turns in.
		float slot = 1.0 - smoothstep(GR + 0.2 - gaa, GR + 0.2 + gaa, gr);
		c = mix(c, vec3(0.03, 0.03, 0.035), slot * (1.0 - metal));
		c = mix(c, gcol, metal);
		c = mix(c, vec3(0.1, 0.1, 0.11), axle);
		rough = mix(rough, 0.35, metal);
		gap *= 1.0 - slot;
	}
	n = normalize(vec3((r - 0.5) * 0.04, 1.0, (r2 - 0.5) * 0.04));
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.85);
#elif STYLE == 11
	// The Starfall Abyss (floor 10, version 255): the floor is pale moonstone broken into
	// plates that have drifted a little apart, wider and wider towards the walls where the
	// floor crumbles, and through every gap the abyss shows far below: blue dark, a slow
	// nebula and stars, sliding as the view moves because they are deep down. Starlight
	// from below catches the plates' edges. In the middle a star gate is set into the floor:
	// a dark stone ring with twelve silver stars, a window onto a slowly turning spiral of
	// stars, and a silver seal of twelve points drawn across it.
	vec2 id;
	const float PS = 1.45;
	vec2 vd = cells(pos / PS, id);
	r = h(id);
	float r2 = h(id + 13.7);
	float pe = (vd.y - vd.x) * PS * 0.5;
	// How far the plates have drifted apart here: a little in the middle, more by the walls.
	float crumble = 1.0 - smoothstep(0.3, 2.6, wall);
	float gw = 0.05 + 0.035 * smoothstep(0.45, 0.85, big2) + 0.2 * crumble * (0.6 + 0.6 * big);
	vec3 wv = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec2 par = -wv.xz / max(wv.y, 0.3);
	// The abyss: blue dark, a nebula drifting far down and two layers of stars.
	vec2 np = pos + par * 6.0;
	float neb = texture(blobs_a, np * 0.035 + vec2(TIME * 0.004, 0.2)).r;
	float neb2 = texture(blobs_b, np * 0.05 + vec2(0.4, TIME * 0.003)).r;
	vec3 abyss = vec3(0.004, 0.006, 0.02);
	vec3 abyss_em = vec3(0.01, 0.016, 0.05) + spores.rgb * 0.35 * smoothstep(0.4, 0.85, neb) + vec3(0.3, 0.12, 0.42) * 0.25 * smoothstep(0.5, 0.9, neb2);
	for (int k = 0; k < 2; k++) {
		float depth = k == 0 ? 2.0 : 5.0;
		float cs = k == 0 ? 0.3 : 0.2;
		vec2 sp = (pos + par * depth) / cs + vec2(float(k) * 5.3, float(k) * 2.7);
		vec2 sc = floor(sp);
		vec2 sf = (fract(sp) - 0.5 - (vec2(h(sc + 1.3), h(sc + 2.9)) - 0.5) * 0.6) * cs;
		float on = step(k == 0 ? 0.45 : 0.35, h(sc + 7.1));
		float tw = 0.55 + 0.45 * sin(TIME * (1.0 + 2.5 * h(sc + 3.3)) + h(sc) * 6.283);
		float sz = (k == 0 ? 0.034 : 0.02) * (0.6 + 0.8 * h(sc + 5.5));
		float star = on * tw * (1.0 - smoothstep(0.0, sz, length(sf)));
		vec3 scol = h(sc + 8.8) > 0.85 ? spores2.rgb : vec3(0.85, 0.9, 1.0);
		abyss_em += scol * star * (k == 0 ? 2.4 : 1.3);
	}
	// The plates: pale moonstone, each its own shade, with faint silver veins.
	float vn = texture(grain, pos * 0.08 + vec2(r * 3.0, r2)).r;
	float vein = 1.0 - smoothstep(0.0, 0.025 + fwidth(vn), abs(vn - 0.5));
	c = vec3(0.265, 0.27, 0.295) * (0.84 + 0.26 * r) * (0.9 + 0.18 * fine) * tint.rgb;
	c = mix(c, vec3(0.38, 0.39, 0.43), vein * 0.15);
	rough = 0.7;
	float g = smoothstep(0.62, 0.9, big + crumble * 0.3) * grime_amount;
	c = mix(c, grime.rgb * (0.8 + 0.4 * fine), g * 0.7);
	rough = mix(rough, 0.9, g);
	// Each plate sinks a little towards its edge, and the edge itself catches starlight.
	c *= 0.82 + 0.18 * smoothstep(gw, gw + 0.25, pe);
	float paa = fwidth(pe) + 0.003;
	float hole = 1.0 - smoothstep(gw - paa, gw + paa, pe);
	float lip = (1.0 - smoothstep(gw, gw + 0.035, pe)) * (1.0 - hole);
	em += spores.rgb * lip * 0.16;
	// A few plates near the walls have fallen away altogether.
	float gone = step(0.72, h(id + 21.7)) * step(wall, 1.1) * step(0.5, half_size.y - abs(pos.y) - 1.2);
	hole = max(hole, gone);
	// The star gate in the middle of the room.
	float gr = length(pos);
	if (gr < 1.95) {
		float gaa = fwidth(gr) + 0.004;
		float disc = 1.0 - smoothstep(1.85 - gaa, 1.85 + gaa, gr);
		vec3 ring = vec3(0.13, 0.13, 0.17) * (0.85 + 0.3 * fine);
		c = mix(c, ring, disc);
		hole *= 1.0 - disc;
		lip *= 1.0 - disc;
		rough = mix(rough, 0.45, disc);
		float silver_l = max(1.0 - smoothstep(0.012, 0.012 + gaa, abs(gr - 1.78)), 1.0 - smoothstep(0.016, 0.016 + gaa, abs(gr - 1.26)));
		float ang = atan(pos.y, pos.x);
		// Twelve stars round the ring, each a four-pointed sparkle, and a tick between each.
		float sa = (fract(ang * 12.0 / 6.2831853 + 0.5) - 0.5) * 6.2831853 / 12.0;
		vec2 sl = vec2(sa * gr, gr - 1.52);
		float spark = min(abs(sl.x) * 4.0 + abs(sl.y), abs(sl.y) * 4.0 + abs(sl.x));
		float sstar = 1.0 - smoothstep(0.075, 0.075 + gaa * 3.0, spark);
		float tick_a = (fract(ang * 12.0 / 6.2831853) - 0.5) * 6.2831853 / 12.0 * gr;
		float tick = (1.0 - smoothstep(0.008, 0.008 + gaa, abs(tick_a))) * step(1.62, gr) * step(gr, 1.74);
		vec3 silver = vec3(0.62, 0.66, 0.78);
		c = mix(c, silver, max(silver_l, tick) * disc);
		c = mix(c, vec3(0.9, 0.92, 1.0), sstar);
		em += spores.rgb * sstar * 0.5 * (0.75 + 0.25 * sin(TIME * 1.5 + ang * 3.0));
		em += spores.rgb * silver_l * 0.06;
		// The window: the abyss under glass, with a spiral of stars turning slowly in it.
		float win = 1.0 - smoothstep(1.22 - gaa, 1.22 + gaa, gr);
		if (win > 0.0) {
			float sa2 = ang + TIME * 0.06;
			float arms = pow(0.5 + 0.5 * sin(2.0 * sa2 - log(max(gr, 0.05)) * 4.5), 3.0);
			float fall = exp(-gr * 1.6);
			vec3 gal = (mix(spores.rgb, vec3(0.75, 0.45, 1.0), 0.35) * arms * fall * 1.1 + vec3(1.0, 0.92, 0.8) * exp(-gr * gr * 10.0) * 0.7);
			float dust = smoothstep(0.55, 0.95, texture(grain, vec2(gr * 0.6, sa2 * 0.5) + par * 0.05).r) * arms * fall;
			gal += vec3(0.9, 0.92, 1.0) * dust * 0.9;
			c = mix(c, abyss, win);
			em += (gal + abyss_em * 0.5) * win;
			rough = mix(rough, 0.08, win);
			// The seal: a twelve-pointed star of silver lines across the glass.
			float seal = 8.0;
			for (int si = 0; si < 12; si++) {
				float a0 = float(si) * 0.5235988;
				float a1 = a0 + 5.0 * 0.5235988;
				seal = min(seal, seg(pos, vec2(cos(a0), sin(a0)) * 1.2, vec2(cos(a1), sin(a1)) * 1.2));
			}
			float sline = (1.0 - smoothstep(0.01, 0.01 + gaa, seal)) * win;
			c = mix(c, silver * 0.8, sline);
			em = mix(em, spores.rgb * 0.15, sline);
		}
	}
	c = mix(c, abyss, hole);
	em = em * (1.0 - hole) + abyss_em * hole;
	rough = mix(rough, 0.95, hole);
	gap = 0.0;
	n = normalize(vec3((r - 0.5) * 0.07, 1.0, (r2 - 0.5) * 0.07));
	c = mix(vec3(dot(c, vec3(0.3, 0.59, 0.11))), c, 0.85);
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
	// Version 337 (visual review fix 2, calmer floors): the floors were busy, with dark lines
	// between the stones, smudges and dirt everywhere, and one strong colour edge to edge, so
	// the ground fought the fighters for attention. Anything darker than the floor's own stone
	// is lifted halfway back towards it (grout, cracks, grime: the lines stay, softer), and the
	// colour is taken down a little. Glowing seams, water light and spores are EMISSION, so
	// they keep their full strength.
	if (calm_mid > 0.0) {
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		float floor_lum = calm_mid;
		if (lum < floor_lum) {
			float lifted = floor_lum - (floor_lum - lum) * calm_depth;
			c = mix(vec3(lifted), c * (lifted / max(lum, 0.004)), clamp(lum / floor_lum * 1.4, 0.0, 1.0));
		}
		// Pale patches (ash, dust) far brighter than the stone come part way down too.
		float lum2 = dot(c, vec3(0.299, 0.587, 0.114));
		float hi = calm_mid * 1.45;
		if (lum2 > hi) {
			c *= (hi + (lum2 - hi) * 0.5) / lum2;
		}
		c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, calm_sat);
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

	ALBEDO = clamp(c * dim, 0.0, 1.0);
	ROUGHNESS = rough;
	if (up > 0.5) {
		NORMAL = normalize(mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) * n);
	}
	if (seam.a > 0.0) {
		// Version 162: fire only in a few hot patches (was 0.56-0.76 with a glow everywhere),
		// so the Ember floor stops glowing orange edge to edge under the fight.
		float heat = smoothstep(0.62, 0.8, texture(blobs_b, pos * 0.05 + vec2(TIME * 0.006, 0.6)).r);
		float sp2 = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(TIME * 1.3 + r * 6.283 + pos.x * 0.6 + pos.y * 0.35), 2.0);
		em += seam.rgb * max(gap, crack) * sp2 * mix(0.6, 1.2, r) * mix(0.0, 1.1, heat);
		em += seam.rgb * pit * (1.0 - bar) * (0.7 + 0.3 * sp2) * 0.2;
	}
	EMISSION = em * shade * dim;
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
## 6. Frostfall Hall (the winter event): dark timber boards with frost on the beams and
##    snow banked at the foot.
## 7. The Sandfall Tomb (floor 5): sandstone courses, a painted frieze of carved signs in
##    gold on turquoise, and sand banked at the foot.
## 8. The Amethyst Mine (floor 7): rough rock with glowing amethyst veins, timber posts and
##    beams, gravel at the foot.
## 9. The Whispering Library (floor 8): bookcases from the floor to the cornice, full of old
##    books, a few of them glowing as they whisper.
## 10. The Clockwork Foundry (floor 9): riveted iron plates streaked with rust, copper pipes
##    on brackets, gauges, and a brass band at the top.
## 11. The Starfall Abyss (floor 10): dark moonstone blocks split by cracks with stars in
##    them, under a frieze of silver constellations.
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
#elif STYLE == 6
	// Frostfall Hall: walls of dark logs laid one on another, snow piled at the foot and on
	// top, and a pine garland hung with little warm lights running round the hall.
	const float LOG = 0.34;
	float lrow = floor(uv.y / LOG);
	float ly = fract(uv.y / LOG);
	float hl = h(vec2(lrow, 4.2));
	float lg = texture(grain, vec2(uv.x * 0.08 + hl * 3.0, uv.y * 1.4)).r;
	c = vec3(0.2, 0.125, 0.075) * (0.75 + 0.4 * hl) * (0.8 + 0.4 * lg);
	// Round: lit along the top of each log, dark in the crease under it.
	c *= (0.55 + 0.6 * sin(ly * 3.1416)) * (1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.12, ly)));
	if (top > 0.5) {
		c = vec3(0.5, 0.55, 0.62) * (0.85 + 0.3 * fine);
	}
	// Snow banked against the foot of the wall.
	float bank = clamp(1.0 - smoothstep(0.0, 0.45 + 0.35 * texture(blobs, vec2(uv.x * 0.25, 0.3)).r, height), 0.0, 1.0) * (1.0 - top);
	c = mix(c, vec3(0.55, 0.6, 0.68) * (0.85 + 0.3 * fine), bank);
	// The garland: a fuzzy band of dark pine sagging between hooks, with lights along it.
	float sag = 1.62 - 0.12 * sin(fract(uv.x / 1.6) * 3.1416);
	float gd = abs(height - sag);
	float pine = (1.0 - smoothstep(0.07, 0.11, gd + (texture(grain, uv * 2.2).r - 0.5) * 0.08)) * (1.0 - top);
	c = mix(c, vec3(0.04, 0.12, 0.07) * (0.7 + 0.6 * texture(grain, uv * 3.1).r), pine);
	float bi = floor(uv.x / 0.4);
	vec2 bl = vec2((fract(uv.x / 0.4) - 0.5) * 0.4, height - sag + 0.02 * sin(bi * 2.1));
	float bulb = (1.0 - smoothstep(0.022, 0.04, length(bl))) * (1.0 - top);
	float hb = h(vec2(bi, 7.7));
	vec3 bcol = hb < 0.6 ? vec3(1.0, 0.72, 0.35) : (hb < 0.82 ? vec3(1.0, 0.25, 0.18) : vec3(0.45, 0.9, 1.0));
	float tw = 0.65 + 0.35 * sin(TIME * (1.3 + hb) + hb * 40.0);
	c = mix(c, bcol, bulb);
	em += bcol * bulb * tw * 1.4 + bcol * (1.0 - smoothstep(0.0, 0.14, length(bl))) * (1.0 - top) * 0.12 * tw;
	rough = mix(0.8, 0.6, bank);
#elif STYLE == 7
	// The Sandfall Tomb: courses of great sandstone blocks, a painted frieze at shoulder
	// height (carved signs in gold on a turquoise band between gold lines, a band of lapis
	// triangles under it) and sand banked against the foot.
	const float BH = 0.62;
	float row = floor(uv.y / BH);
	float bx = uv.x / 1.3 + mod(row, 2.0) * 0.5;
	float bc = floor(bx);
	vec2 bf = vec2(fract(bx), fract(uv.y / BH));
	float hb = h(vec2(bc, row));
	c = vec3(0.36, 0.255, 0.16) * (0.8 + 0.35 * hb) * (0.88 + 0.24 * fine);
	c *= mix(1.0, 1.08, step(0.6, h(vec2(bc, row + 9.0))));
	float joint = (1.0 - smoothstep(0.0, 0.02, min(min(bf.x, 1.0 - bf.x) * 1.3, min(bf.y, 1.0 - bf.y) * BH))) * (1.0 - top);
	c *= 1.0 + 0.12 * smoothstep(0.85, 1.0, bf.y) - 0.16 * (1.0 - smoothstep(0.0, 0.14, bf.y));
	c = mix(c, vec3(0.07, 0.045, 0.03), joint * 0.85);
	if (top < 0.5 && height > 1.08 && height < 1.66) {
		float fy = height - 1.4;
		vec3 fc = vec3(0.09, 0.3, 0.28) * (0.9 + 0.2 * fine);
		vec2 g = vec2((fract(uv.x / 0.5) - 0.5) * 0.5, fy);
		float gi = floor(uv.x / 0.5);
		float kind = mod(gi, 4.0);
		float d = 9.0;
		if (kind < 1.0) {
			float lid = max(length(g - vec2(0.0, 0.1)) - 0.14, length(g + vec2(0.0, 0.1)) - 0.14);
			d = min(abs(lid) - 0.011, length(g) - 0.03);
		} else if (kind < 2.0) {
			float R = length(g);
			d = min(abs(R - 0.075) - 0.011, R - 0.035);
			float an = atan(g.y, g.x);
			d = min(d, max(abs(fract(an / 0.7853982 + 0.5) - 0.5) * R * 0.785 - 0.009, abs(R - 0.13) - 0.03));
		} else if (kind < 3.0) {
			for (int k = 0; k < 2; k++) {
				float yv = float(k) * 0.08 - 0.04 + 0.025 * (abs(fract(g.x * 8.0) - 0.5) * 4.0 - 1.0);
				d = min(d, max(abs(g.y - yv) - 0.01, abs(g.x) - 0.15));
			}
		} else {
			d = abs(length(g / vec2(0.07, 0.09)) - 1.0) * 0.07 - 0.009;
			d = min(d, length(g - vec2(0.0, 0.12)) - 0.03);
			d = min(d, max(abs(abs(g.x) - 0.1) - 0.008, abs(g.y) - 0.06));
		}
		float ad = fwidth(d) + 0.002;
		fc = mix(fc, vec3(0.55, 0.41, 0.17), 1.0 - smoothstep(-ad, ad, d));
		// Gold lines above and below, lapis triangles under the lower one.
		float gl = 1.0 - smoothstep(0.012, 0.02, abs(abs(fy) - 0.2));
		if (abs(fy) > 0.2) {
			float tri = abs(fract(uv.x / 0.16) - 0.5) * 2.0;
			fc = fy < 0.0 ? mix(vec3(0.36, 0.255, 0.16) * 0.9, vec3(0.07, 0.1, 0.24), step((-fy - 0.2) / 0.06, 1.0 - tri)) : vec3(0.36, 0.255, 0.16) * 0.95;
		}
		fc = mix(fc, vec3(0.55, 0.41, 0.17), gl);
		c = mix(c, fc * (0.9 + 0.15 * hb), 1.0 - smoothstep(0.24, 0.27, abs(fy)));
		em += vec3(0.55, 0.41, 0.17) * gl * 0.06;
	}
	if (top > 0.5) {
		c = vec3(0.4, 0.3, 0.19) * (0.85 + 0.3 * fine);
	}
	// Sand banked against the foot of the wall.
	float bank = clamp(1.0 - smoothstep(0.0, 0.3 + 0.45 * texture(blobs, vec2(uv.x * 0.25, 0.3)).r, height), 0.0, 1.0) * (1.0 - top);
	c = mix(c, vec3(0.56, 0.43, 0.27) * (0.85 + 0.3 * fine), bank);
	rough = mix(0.85, 0.95, bank);
#elif STYLE == 8
	// The Amethyst Mine: rough rock hewn by picks, streaked, with veins of amethyst glowing
	// in it; timber props every three metres (posts under a beam), so the wall torches hang
	// on posts; gravel heaped at the foot.
	float rk = texture(blobs, uv * vec2(0.6, 0.9)).r;
	c = vec3(0.18, 0.175, 0.19) * (0.7 + 0.55 * rk) * (0.85 + 0.3 * fine);
	float pm = fract(uv.x * 2.6 + uv.y * 1.5 + rk * 2.0);
	c *= 0.88 + 0.16 * smoothstep(0.3, 0.45, pm) * (1.0 - smoothstep(0.45, 0.6, pm));
	float vn = texture(blobs, uv * 0.5 + vec2(3.1, 0.0)).r;
	float vein = (1.0 - smoothstep(0.0, 0.012 + fwidth(vn), abs(vn - 0.5))) * step(0.62, rk) * (1.0 - top);
	c = mix(c, spores.rgb * 0.4, vein);
	em += spores.rgb * vein * (0.35 + 0.2 * sin(TIME * 1.1 + uv.x * 1.7)) * spores.a;
	float px = (fract(uv.x / 3.0 + 0.5) - 0.5) * 3.0;
	float post = (1.0 - smoothstep(0.12, 0.14, abs(px))) * (1.0 - top);
	float beam = smoothstep(2.12, 2.14, height) * (1.0 - smoothstep(2.42, 2.44, height)) * (1.0 - top);
	float gr = texture(grain, vec2(uv.x * 0.25, uv.y * 2.2) + vec2(0.0, px)).r;
	vec3 wood = vec3(0.25, 0.155, 0.09) * (0.75 + 0.45 * gr);
	wood *= mix(1.0, 0.75 + 0.35 * smoothstep(0.13, 0.0, abs(px)), post);
	wood *= mix(1.0, 0.75 + 0.3 * smoothstep(2.12, 2.3, height), beam * (1.0 - post));
	c = mix(c, wood, max(post, beam));
	if (top > 0.5) {
		c = vec3(0.15, 0.13, 0.16) * (0.8 + 0.4 * fine);
	}
	float heap = clamp(1.0 - smoothstep(0.0, 0.25 + 0.35 * texture(blobs, vec2(uv.x * 0.3, 0.6)).r, height), 0.0, 1.0) * (1.0 - top) * (1.0 - post);
	c = mix(c, vec3(0.3, 0.27, 0.29) * (0.7 + 0.5 * fine), heap);
	rough = 0.9;
#elif STYLE == 9
	// The Whispering Library: every wall a bookcase. Dark oak uprights every 1.1 m, five
	// shelves from a plinth at the foot to a cornice at the top, and on them old books of
	// every size and colour in leather, some with gold bands, a few gaps, and here and there
	// a book whose spine glows teal and fades (the whispering ones).
	vec3 oak = vec3(0.2, 0.115, 0.06) * (0.8 + 0.35 * fine);
	c = oak;
	rough = 0.6;
	if (top > 0.5) {
		c = vec3(0.15, 0.085, 0.045) * (0.85 + 0.3 * fine);
	} else {
		float ux = (fract(uv.x / 1.1 + 0.5) - 0.5) * 1.1;
		float upright = 1.0 - smoothstep(0.045, 0.055, abs(ux));
		float sy = height - 0.18;
		float si = floor(sy / 0.44);
		float sv = sy - si * 0.44;
		if (sy > 0.0 && si < 5.0 && upright < 0.99) {
			// The dark back of the case.
			c = vec3(0.035, 0.022, 0.016);
			// The books: slots 0.12 m wide, each one thick book or two thinner ones.
			float bx = uv.x + si * 3.7;
			float sl = floor(bx / 0.12);
			float sf = fract(bx / 0.12);
			float hs = h(vec2(sl, si));
			float split = hs < 0.4 ? 1.0 : 0.32 + 0.36 * h(vec2(sl, si + 7.0));
			float bk = sf < split ? 0.0 : 1.0;
			float b0 = bk < 0.5 ? 0.0 : split;
			float b1 = bk < 0.5 ? split : 1.0;
			float lx = (sf - b0) / (b1 - b0);
			vec2 bid = vec2(sl * 2.0 + bk, si);
			float bh = 0.25 + 0.13 * h(bid + 3.1);
			float by = sv - 0.04;
			float missing = step(0.93, h(bid + 5.5));
			if (by > 0.0 && by < bh && missing < 0.5) {
				float pick = h(bid + 1.3);
				vec3 bc = pick < 0.22 ? vec3(0.34, 0.07, 0.06) : pick < 0.4 ? vec3(0.07, 0.2, 0.12) : pick < 0.56 ? vec3(0.08, 0.11, 0.25)
					: pick < 0.7 ? vec3(0.4, 0.28, 0.12) : pick < 0.84 ? vec3(0.25, 0.14, 0.075) : pick < 0.93 ? vec3(0.24, 0.08, 0.2) : vec3(0.06, 0.055, 0.05);
				bc *= 0.75 + 0.45 * h(bid + 2.2);
				// Round spines: lit across the middle, dark at the edges.
				bc *= 0.55 + 0.5 * sin(3.1415927 * clamp(lx, 0.0, 1.0));
				// Gold bands near the top and the foot of half the books, and a label on some.
				float yb = by / bh;
				float gold = step(0.5, h(bid + 4.4)) * max(step(0.1, yb) * step(yb, 0.14), step(0.84, yb) * step(yb, 0.88));
				bc = mix(bc, vec3(0.55, 0.42, 0.17) * (0.6 + 0.5 * sin(3.1415927 * lx)), gold);
				float label = step(0.7, h(bid + 6.6)) * step(0.55, yb) * step(yb, 0.72) * step(0.22, lx) * step(lx, 0.78);
				bc = mix(bc, vec3(0.5, 0.45, 0.35) * 0.7, label);
				c = bc * (0.85 + 0.3 * fine);
				// The whispering books: their spines glow and fade, each at its own pace.
				float whisper = step(0.965, h(bid + 9.9));
				float pulse = pow(0.5 + 0.5 * sin(TIME * (0.6 + h(bid + 8.0)) + h(bid) * 30.0), 3.0);
				c = mix(c, spores.rgb * 0.5, whisper * 0.6);
				em += spores.rgb * whisper * (0.2 + 0.8 * pulse) * 0.7 * spores.a * (0.5 + 0.5 * sin(3.1415927 * lx));
			}
			// The shelf's front edge.
			float board = 1.0 - smoothstep(0.035, 0.042, sv);
			c = mix(c, oak * (1.05 + 0.25 * (1.0 - smoothstep(0.0, 0.035, sv))), board);
		}
		// The uprights, with a bead down their middle.
		c = mix(c, oak * (0.85 + 0.3 * smoothstep(0.05, 0.0, abs(ux))), upright);
		// The cornice (mouldings) and the plinth.
		if (height > 2.38) {
			float mo = fract((height - 2.38) / 0.11);
			c = oak * (0.75 + 0.4 * smoothstep(0.0, 0.5, mo) * (1.0 - smoothstep(0.6, 1.0, mo)));
		} else if (height < 0.18) {
			c = oak * 0.7 * (0.85 + 0.3 * smoothstep(0.1, 0.16, height));
		}
	}
#elif STYLE == 10
	// The Clockwork Foundry: walls of iron plate 1.5 m by 0.85 m, riveted at the edges and
	// streaked with rust running down, two runs of copper pipe on brackets (a thick one low,
	// a thin one high), an iron pipe standing every 4 m, pressure gauges on a few plates
	// (their needles trembling) and a brass band along the top.
	float pr = floor(height / 0.85);
	vec2 pq = vec2(uv.x / 1.5 + 0.5 * mod(pr, 2.0), height / 0.85);
	vec2 pci = floor(pq);
	vec2 pfr = fract(pq) - 0.5;
	vec2 pee = (0.5 - abs(pfr)) * vec2(1.5, 0.85);
	float rp = h(pci);
	c = vec3(0.15, 0.16, 0.18) * (0.8 + 0.35 * rp) * (0.85 + 0.3 * fine);
	float streak = smoothstep(0.55, 0.8, texture(blobs, vec2(uv.x * 1.6, height * 0.12)).r) * smoothstep(0.0, 0.3, 0.5 - pfr.y);
	c = mix(c, vec3(0.28, 0.13, 0.06) * (0.7 + 0.5 * fine), streak * 0.7);
	float pg = min(pee.x, pee.y);
	c *= 1.0 - 0.55 * (1.0 - smoothstep(0.008, 0.02, pg));
	c *= 1.0 + 0.12 * (1.0 - smoothstep(0.02, 0.06, pg));
	float rvx = (fract(uv.x / 0.2) - 0.5) * 0.2;
	float rvd2 = length(vec2(rvx, pee.y - 0.06));
	float riv = (1.0 - smoothstep(0.018, 0.026, rvd2)) * step(0.1, pee.x);
	c = mix(c, vec3(0.28, 0.29, 0.31), riv);
	if (top > 0.5) {
		c = vec3(0.12, 0.12, 0.13) * (0.85 + 0.3 * fine);
	} else {
		// Gauges on about one plate in five, at chest height.
		vec2 gq = vec2((pfr.x) * 1.5, height - (pr + 0.5) * 0.85);
		if (step(0.8, h(pci + 3.3)) > 0.5 && pr == 1.0) {
			float gd = length(gq);
			float ring = (1.0 - smoothstep(0.1, 0.11, gd)) * smoothstep(0.08, 0.09, gd);
			float face = 1.0 - smoothstep(0.08, 0.085, gd);
			float na = 0.6 + 0.08 * sin(TIME * 7.0 + rp * 20.0) + rp;
			vec2 nd = vec2(sin(na), cos(na));
			float needle = (1.0 - smoothstep(0.006, 0.012, abs(dot(gq, vec2(nd.y, -nd.x))))) * step(0.0, dot(gq, nd)) * step(gd, 0.07);
			c = mix(c, vec3(0.6, 0.56, 0.45), face);
			c = mix(c, vec3(0.55, 0.4, 0.16), ring);
			c = mix(c, vec3(0.5, 0.06, 0.04), needle);
		}
		// The pipes: round, lit along their tops.
		for (int pi = 0; pi < 2; pi++) {
			float py = pi == 0 ? 0.42 : 1.95;
			float prad = pi == 0 ? 0.085 : 0.055;
			float pd = (height - py) / prad;
			if (abs(pd) < 1.0) {
				float round_ = sqrt(1.0 - pd * pd);
				vec3 pcol = vec3(0.48, 0.25, 0.13) * (0.35 + 0.75 * round_ * (0.6 + 0.4 * smoothstep(-1.0, 0.6, pd)));
				pcol += vec3(0.25, 0.18, 0.1) * pow(max(0.0, 1.0 - abs(pd - 0.45) * 4.0), 3.0);
				// Brackets every 1.5 m.
				float bk = 1.0 - smoothstep(0.03, 0.04, abs((fract(uv.x / 1.5 + 0.25) - 0.5) * 1.5));
				pcol = mix(pcol, vec3(0.08, 0.08, 0.09) * (0.6 + 0.6 * round_), bk);
				c = pcol;
			}
		}
		float vpx = (fract(uv.x / 4.0 + 0.13) - 0.5) * 4.0;
		if (abs(vpx) < 0.07) {
			float vr = sqrt(1.0 - pow(vpx / 0.07, 2.0));
			c = vec3(0.17, 0.17, 0.19) * (0.4 + 0.8 * vr);
		}
		if (height > 2.42) {
			c = vec3(0.5, 0.37, 0.15) * (0.7 + 0.45 * smoothstep(2.42, 2.52, height) * (1.0 - smoothstep(2.52, 2.6, height)));
		}
	}
	rough = 0.5;
#elif STYLE == 11
	// The Starfall Abyss: great blocks of dark moonstone, split by cracks that open onto the
	// abyss behind (stars glint in them), and a frieze of silver constellations along the
	// top, the stars joined by fine lines.
	float br = floor(height / 0.62);
	vec2 bq = vec2(uv.x / 1.3 + 0.5 * mod(br, 2.0), height / 0.62);
	vec2 bci = floor(bq);
	vec2 bfr = fract(bq) - 0.5;
	vec2 bee = (0.5 - abs(bfr)) * vec2(1.3, 0.62);
	float rb = h(bci);
	c = vec3(0.13, 0.135, 0.17) * (0.8 + 0.35 * rb) * (0.85 + 0.3 * fine);
	float bg = min(bee.x, bee.y);
	c *= 1.0 - 0.6 * (1.0 - smoothstep(0.008, 0.022, bg));
	c *= 1.0 + 0.1 * (1.0 - smoothstep(0.02, 0.06, bg));
	rough = 0.7;
	if (top > 0.5) {
		c = vec3(0.1, 0.1, 0.13) * (0.85 + 0.3 * fine);
	} else {
		// A wandering crack down about one block in three, with stars glinting inside.
		if (h(bci + 4.4) > 0.66) {
			float cx = (bfr.x + (h(bci + 6.1) - 0.5) * 0.5) * 1.3 + 0.05 * sin(height * 23.0 + rb * 9.0) + 0.03 * sin(height * 57.0);
			float cw = 0.012 + 0.02 * (0.5 + 0.5 * sin(height * 7.0 + rb * 5.0));
			float crk = 1.0 - smoothstep(cw, cw + 0.008, abs(cx));
			float tw = h(floor(vec2(uv.x * 30.0, height * 30.0)));
			float glint = step(0.93, tw) * (0.5 + 0.5 * sin(TIME * 2.0 + tw * 40.0));
			c = mix(c, vec3(0.005, 0.007, 0.02), crk);
			em += (spores.rgb * 0.25 + vec3(0.9, 0.92, 1.0) * glint * 1.2) * crk;
		}
		// The frieze: a dark band with silver stars joined into constellations.
		if (height > 2.05 && height < 2.5) {
			float fy = height - 2.275;
			c = vec3(0.07, 0.07, 0.1) * (0.85 + 0.3 * fine);
			float edge_l = (1.0 - smoothstep(0.01, 0.018, abs(abs(fy) - 0.2)));
			c = mix(c, vec3(0.55, 0.58, 0.7), edge_l);
			float cell = floor(uv.x / 0.55);
			float best = 8.0;
			float lines = 8.0;
			vec2 prev = vec2(0.0);
			for (int k = -1; k <= 2; k++) {
				float ck = cell + float(k);
				vec2 sp = vec2((ck + 0.2 + 0.6 * h(vec2(ck, 1.7))) * 0.55, 2.275 + (h(vec2(ck, 3.1)) - 0.5) * 0.26);
				vec2 d = vec2(uv.x, height) - sp;
				best = min(best, length(d) / (0.6 + 0.8 * h(vec2(ck, 5.3))));
				if (k > -1 && h(vec2(ck, 7.7)) > 0.25) {
					vec2 pa = vec2(uv.x, height) - prev;
					vec2 ba = sp - prev;
					lines = min(lines, length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)));
				}
				prev = sp;
			}
			float st = 1.0 - smoothstep(0.018, 0.03, best);
			float ln = (1.0 - smoothstep(0.003, 0.007, lines)) * 0.6;
			c = mix(c, vec3(0.6, 0.64, 0.78), max(ln, st));
			em += spores.rgb * st * (0.45 + 0.25 * sin(TIME * 1.7 + uv.x * 3.0)) + spores.rgb * ln * 0.05;
		}
	}
#endif
	// Darker at the foot of the wall, where the floor meets it.
	float foot = mix(0.55, 1.0, smoothstep(0.0, 0.7, height));
	// Version 162: the tops of the walls sit darker (the near wall's top is the strip along
	// the bottom of the screen, and it was brighter than the floor it frames).
	ALBEDO = c * foot * mix(1.0, 0.68, top);
	ROUGHNESS = rough;
	EMISSION = em;
}
"""


## The low near ledge: the floor's stone, darker, without the floor's fire, water or blood.
static func _ledge_material(look: Dictionary) -> Material:
	var m := _floor_material(look, 0) as ShaderMaterial
	m.set_shader_parameter("tint", (look.floor as Color) * 0.5)
	m.set_shader_parameter("grime_amount", 0.0)
	m.set_shader_parameter("blood", 0.0)
	m.set_shader_parameter("seam", Color(0, 0, 0, 0))
	m.set_shader_parameter("water", Color(0, 0, 0, 0))
	m.set_shader_parameter("spores", Color(0, 0, 0, 0))
	m.set_shader_parameter("half_size", Vector2(100, 100))
	m.set_shader_parameter("ledge", 1.0)
	m.set_shader_parameter("torch_amount", 0.0)
	return m


## Version 358: the place's own floor carried on past the near parapet, a little darker
## (out of the fight), without blood or torchlight.
static func _gallery_material(look: Dictionary, centre_z: float) -> Material:
	var m := _floor_material(look) as ShaderMaterial
	m.set_shader_parameter("shift", Vector2(0, centre_z))
	m.set_shader_parameter("dim", GALLERY_DIM)
	m.set_shader_parameter("blood", 0.0)
	m.set_shader_parameter("torch_amount", 0.0)
	return m


const GALLERY_DIM := 0.72


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
					# Each crypt has its own pillars (version 134); Frostfall Hall's timber posts,
					# the Sandfall Tomb's lotus columns, the Amethyst Mine's rock columns, the
					# Whispering Library's bookcases, the Clockwork Foundry's iron columns and the
					# Starfall Abyss's broken floating columns are made in code (props.gd).
					var kind := str(Floors.current().get("pillar", ""))
					if kind == "iron":
						Props.add_iron_column(_anchor(p))
					elif kind == "drift":
						Props.add_drift_column(_anchor(p))
					elif kind == "timber" or kind == "lotus" or kind == "rock" or kind == "shelf":
						var post := MeshInstance3D.new()
						match kind:
							"timber": post.mesh = Props.timber_post()
							"lotus": post.mesh = Props.lotus_column()
							"rock": post.mesh = Props.rock_column()
							_: post.mesh = Props.bookcase_column()
						var anchor := _anchor(p)
						anchor.add_child(post)
						if kind == "shelf":
							anchor.rotation.y = PI / 2 * randi_range(0, 3)   # (square: kept square to the room)
					else:
						_add_pillar(p, stone)
				"b":
					_add_obstacle(p, 0.45)
					var prefab := Art.get_model(Art.BARREL)
					if Props.add_cover(_anchor(p), "b"):   # (version 256: the floor's own cover)
						pass
					elif prefab:
						Art.place_prop(prefab, _anchor(p), 1.0)
					else:
						U.cylinder(self, 0.4, 0.95, wood, p)
						U.cylinder(self, 0.42, 0.06, iron, p + Vector3.UP * 0.2)
						U.cylinder(self, 0.42, 0.06, iron, p + Vector3.UP * 0.7)
				"c":
					_add_obstacle(p, 0.6)
					var prefab := Art.get_model(Art.CRATES)
					if Props.add_cover(_anchor(p), "c"):   # (version 256: the floor's own cover)
						pass
					elif prefab:
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


func _add_pillar(p: Vector3, stone: Material) -> void:
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
## don't get stuck pushing into one. Version 164: it looks at the nearest thing in the way
## (not the first in the list), and only turns towards a side that is open, trying wider
## turns when two props stand close (two crates and a candle used to make a pocket that
## skeletons rocked in, unable to choose a side).
func steer(pos: Vector3, dir: Vector3, r: float) -> Vector3:
	var o = _blocker(pos, dir, r)
	if o == null:
		return dir
	var to: Vector3 = o.pos - pos
	to.y = 0.0
	var side := to - dir * to.dot(dir)
	var tangent := dir.cross(Vector3.UP)
	if side.dot(tangent) > 0.0:
		tangent = -tangent
	elif side.length_squared() < 0.0001 and fmod(pos.x + pos.z, 2.0) < 1.0:
		tangent = -tangent
	# A pillar next to a wall: go round the open side instead of pushing into the wall.
	# The gap is measured from the pillar itself (measured from the skeleton, one a little
	# to the side of a pillar one column in from the wall flipped its mind every frame).
	var probe: Vector3 = o.pos + tangent * (o.r + r + 0.1)
	if absf(probe.x) > HALF_W - r or absf(probe.z) > HALF_L - r:
		tangent = -tangent
	var bent := (dir + tangent * 1.5).normalized()
	if _blocker(pos, bent, r) == null:
		return bent
	# The usual turn runs into something else: the first open direction, nearest the
	# way it wanted to go, on its chosen side first.
	var lean := 1.0 if dir.cross(bent).y > 0.0 else -1.0
	for ang in [0.6, 1.0, 1.35, 1.75, 2.2]:
		for s in [lean, -lean]:
			var c := dir.rotated(Vector3.UP, s * ang)
			if _blocker(pos, c, r) == null and _clamp_walls(pos + c * (r + 0.4), r).distance_squared_to(pos + c * (r + 0.4)) < 0.0001:
				return c
	return bent


## The nearest obstacle a circle of radius `r` would walk into going along `dir`, or null.
func _blocker(pos: Vector3, dir: Vector3, r: float):
	var best = null
	var best_ahead := INF
	for o in obstacles:
		var to: Vector3 = o.pos - pos
		to.y = 0.0
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > o.r + r + 1.2 or ahead >= best_ahead:
			continue
		if (to - dir * ahead).length() >= o.r + r:
			continue
		best = o
		best_ahead = ahead
	return best


## True when a prop of radius `r` at `p` leaves room for a big skeleton to walk past it: it
## either touches each pillar, crate or other prop (so they block as one) or leaves a gap
## of at least `gap` metres. (A candle between two crates once closed the gap.)
func leaves_gap(p: Vector3, r: float, gap := 1.4) -> bool:
	for o in obstacles:
		var d: Vector3 = p - o.pos
		d.y = 0.0
		var free: float = d.length() - o.r - r
		if free > 0.0 and free < gap:
			return false
	return true


# ---------------------------------------------------------------- finding a way round

## Version 165: skeletons who can't walk straight to the hero follow a small map of the room
## (half-metre squares) round crates, pillars and props, so two props close together can
## never trap one. The map of open squares is made once a room; the way to the hero is
## worked out again only when the hero has moved to another square (and at most four times
## a second).
const NAV := 0.5
const NAV_W := int(HALF_W * 2.0 / NAV)   # 24
const NAV_L := int(HALF_L * 2.0 / NAV)   # 40
const NAV_CLEAR := 0.5                   # room a skeleton needs round its middle

## Whether the last route() call found the straight line clear (steer() then still bends
## round anything small; when it wasn't clear, the route already goes round it).
var last_clear := true
var _nav_open := PackedByteArray()
var _nav_dist := PackedInt32Array()
var _nav_goal := -1
var _nav_ms := -100000


func _nav_cell(p: Vector3) -> int:
	var cx := clampi(int((p.x + HALF_W) / NAV), 0, NAV_W - 1)
	var cz := clampi(int((p.z + HALF_L) / NAV), 0, NAV_L - 1)
	return cz * NAV_W + cx


func _nav_center(i: int) -> Vector3:
	return Vector3(-HALF_W + (i % NAV_W + 0.5) * NAV, 0.0, -HALF_L + (i / NAV_W + 0.5) * NAV)


func _nav_build() -> void:
	_nav_open.resize(NAV_W * NAV_L)
	for i in NAV_W * NAV_L:
		_nav_open[i] = 1 if is_walkable(_nav_center(i), NAV_CLEAR) else 0


func _nav_flood(goal: int) -> void:
	_nav_goal = goal
	_nav_ms = Time.get_ticks_msec()
	_nav_dist.resize(NAV_W * NAV_L)
	_nav_dist.fill(-1)
	_nav_dist[goal] = 0
	var queue := PackedInt32Array([goal])
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var x := c % NAV_W
		var z := c / NAV_W
		var d := _nav_dist[c] + 1
		for k in 4:
			var nx := x + (1 if k == 0 else (-1 if k == 1 else 0))
			var nz := z + (1 if k == 2 else (-1 if k == 3 else 0))
			if nx < 0 or nz < 0 or nx >= NAV_W or nz >= NAV_L:
				continue
			var n := nz * NAV_W + nx
			if _nav_dist[n] != -1 or _nav_open[n] == 0:
				continue
			_nav_dist[n] = d
			queue.append(n)


## True when a circle of radius `r` can walk the straight line from `a` to `b` without
## touching an obstacle.
func clear_walk(a: Vector3, b: Vector3, r: float) -> bool:
	var ab := b - a
	ab.y = 0.0
	var len2 := ab.length_squared()
	for o in obstacles:
		var ao: Vector3 = o.pos - a
		ao.y = 0.0
		var t := clampf(ao.dot(ab) / len2, 0.0, 1.0) if len2 > 0.0001 else 0.0
		var m: float = o.r + r
		if (ao - ab * t).length_squared() < m * m:
			return false
	return true


## The way to walk from `pos` towards `goal` round anything in between: straight at it
## when the line is clear, else towards the next open square on the shortest way round.
func route(pos: Vector3, goal: Vector3, r: float) -> Vector3:
	var to := goal - pos
	to.y = 0.0
	last_clear = clear_walk(pos, goal, r * 0.9)
	if last_clear:
		return to.normalized()
	if _nav_open.is_empty():
		_nav_build()
	var g := _nav_cell(goal)
	if g != _nav_goal and Time.get_ticks_msec() - _nav_ms > 250:
		_nav_flood(g)
	if _nav_dist.is_empty():
		return to.normalized()
	var here := _nav_cell(pos)
	var best := -1
	var best_d := _nav_dist[here] if _nav_dist[here] >= 0 else 1 << 30
	var x := here % NAV_W
	var z := here / NAV_W
	# Looks a few squares ahead along the way and walks at the farthest one in clear sight,
	# so the path is smooth rather than square by square.
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var nx := x + dx
			var nz := z + dz
			if nx < 0 or nz < 0 or nx >= NAV_W or nz >= NAV_L:
				continue
			var n := nz * NAV_W + nx
			var nd := _nav_dist[n]
			if nd < 0 or nd >= best_d:
				continue
			if not clear_walk(pos, _nav_center(n), r * 0.9):
				continue
			best = n
			best_d = nd
	if best == -1:
		return to.normalized()
	var way := _nav_center(best) - pos
	way.y = 0.0
	return way.normalized() if way.length_squared() > 0.0001 else to.normalized()


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
