class_name ChestShow
extends Reliquary
## The Bone Drop's chest with its full-screen opening, "The Gift" (DropScreen.style 1). The
## crypt goes black, the screen's writing fades away and the camera leaves its perch.
##
## The camera goes in close on the skull. Something inside punches the lid, once for each
## rarity, each blow harder and leaking the next colour. The chest shakes and strains, then
## the lid is blown away and a great bone hand shoots up out of it, turns over and opens:
## the prize stands on its palm, held out to you. The prize is what you won: a gold coin,
## your hero in the new look, a star for a Lucky Start, an arrow for an Armory level.
##
## It ends where the first opening does (the chest in its usual place), so the screen's
## writing comes back around it. Everything here is plain meshes and a few soft sprites:
## no screen-wide effects, so it runs on a cheap phone.

# ---------------------------------------------------------------- what the screen reads

## How dark the crypt around the chest should be (the drop screen dims itself by this).
var dark := 0.0
## How much of the screen's writing and buttons should show.
var ui := 1.0
## The burst of rays behind the prize (0 to 1), its colour, and where it is.
var sun := 0.0
var sun_col := Color.WHITE
## A shaft of light coming down onto the plinth: how strong, how wide (1 = full), its colour.
var shaft := 0.0
var shaft_wide := 1.0
var shaft_col := Color.WHITE
## Light leaking out from under the lid (The Gift), and its colour.
var leak := 0.0
var leak_col := Color.WHITE
## Set to ask for a white flash; the screen takes it and zeroes it.
var flash := 0.0
## The prize is out: the screen brings its writing back.
var revealed := false

const ARM := 2.0           # the hand is as wide as half the chest
const BEAT := 0.38         # seconds between the blows
const SHAFT_H := 14.0
const DRAWN := 0.42        # the chest strains this long before it bursts
const PRIZE_UP := 0.44     # how far above the palm the middle of the prize is
const HERO_TALL := 0.84    # a new look: how tall the hero wearing it stands on the palm

var _goal := 0
var _since_was := 0.0
var _beats_done := 0
var _prize := "coins"
var _shake := 0.0
var _stop := 0.0           # a held frame: seconds the blow still hangs
var _punch := 0.0          # The Gift: time since the last blow from inside (under 0: none yet)
var _punch_size := 0.0
var _show_col := Color.WHITE
var _strain := false       # the chest has begun to strain (this opening)
var _arrive := -1.0        # seconds since the next chest began to drop onto the plinth (under 0: it stands)
var _landed := false
var _cheered := false

var _floor: MeshInstance3D
var _floor_mat: ShaderMaterial
var _shaft: MeshInstance3D
var _shaft_mat: ShaderMaterial
var _sun: MeshInstance3D
var _sun_mat: ShaderMaterial
var _sun_spin := 0.0
var _waves: Array = []       # rings of light running out over the floor: {mi, mat, t, col}
var _motes: CPUParticles3D
var _mote_mat: StandardMaterial3D
var _forearm: Node3D
var _bronze: StandardMaterial3D
var _bright: StandardMaterial3D
var _lid_t := -1.0
var _lid_vel := Vector3.ZERO
var _lid_spin := Vector3.ZERO
var _token: Node3D
var _coin: Node3D
var _gem: MeshInstance3D
var _gem_own: StandardMaterial3D
var _star3: MeshInstance3D     # a Lucky Start
var _star_own: StandardMaterial3D
var _arrow: MeshInstance3D     # a free Armory level
var _hero_at: Node3D           # a new look: the hero wearing it stands here
var _hero: CharacterVisual
var _hero_id := ""
var _token_glow: MeshInstance3D
var _token_glow_mat: ShaderMaterial
var _token_light: OmniLight3D
var _eye_glow: Array[MeshInstance3D] = []
var _eye_glow_mat: ShaderMaterial
var _sparks: CPUParticles3D
var _spark_mat: StandardMaterial3D
var _arm: Node3D
var _hand: Node3D
var _fingers: Array = []     # each: [joint, joint, joint] (the thumb has two)


# ---------------------------------------------------------------- shaders

const SOFT_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float power = 1.0;
void vertex() {
	// Always facing the camera, at its own size.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float g = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	ALBEDO = mix(col.rgb, vec3(1.0), g * 0.6);
	ALPHA = clamp(g * power, 0.0, 1.0);
}
"""

## The crypt's floor around the plinth: flagstones in a pool of light, fading to nothing at
## its edge.
const FLOOR_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float show = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float lit = 0.5;
varying vec3 wp;
float h2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1.0, 0.0)), f.x), mix(h2(i + vec2(0.0, 1.0)), h2(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wp = VERTEX; }
void fragment() {
	float r = length(wp.xz);
	vec2 g = wp.xz * 1.35;
	g.x += 0.5 * mod(floor(g.y), 2.0);
	vec2 id = floor(g);
	vec2 f = fract(g);
	float gap = smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float n = h2(id) * 0.6 + n2(wp.xz * 9.0) * 0.4;
	vec3 stone = mix(vec3(0.07, 0.06, 0.085), vec3(0.2, 0.18, 0.23), n) * (0.45 + 0.55 * gap);
	float pool = exp(-r * r * 0.22);
	vec3 c = stone * (0.12 + lit * pool * 1.5) + stone * tint.rgb * pool * lit * 2.2;
	ALBEDO = c;
	ALPHA = show * smoothstep(5.6, 2.4, r);
}
"""

## A pillar of light standing on the plinth.
const SHAFT_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float power = 0.0;
void fragment() {
	float v = UV.y * 2.0;
	float edge = pow(abs(dot(NORMAL, VIEW)), 1.5);
	float a = UV.x * 6.2831853;
	float streak = 0.62 + 0.38 * (sin(a * 7.0 + TIME * 0.9) * 0.5 + 0.5) * (sin(a * 13.0 - TIME * 1.6) + 1.0);
	float foot = smoothstep(1.0, 0.94, v);
	ALBEDO = mix(col.rgb, vec3(1.0), 0.15);
	// (Its near wall is thin, so what stands inside it stays clear.)
	ALPHA = clamp(streak * power * (0.3 + 0.7 * v) * edge * foot, 0.0, 1.0) * (FRONT_FACING ? 0.3 : 1.0);
}
"""

## Rays turning behind the prize.
const SUN_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float power = 0.0;
uniform float spin = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float r1 = pow(sin((a + spin) * 6.0) * 0.5 + 0.5, 3.0);
	float r2 = pow(sin((a - spin * 0.6) * 10.0 + 1.0) * 0.5 + 0.5, 5.0);
	float rays = (r1 * 0.85 + r2 * 0.5) * smoothstep(1.0, 0.12, r);
	float core = pow(clamp(1.0 - r, 0.0, 1.0), 3.0);
	ALBEDO = mix(col.rgb, vec3(1.0), core * 0.75);
	ALPHA = clamp((rays * 0.6 + core) * power * smoothstep(1.0, 0.8, r), 0.0, 1.0);
}
"""


# ---------------------------------------------------------------- building

func _build() -> void:
	super._build()
	_stage()
	_build_token()
	_build_arm()


func _soft(parent: Node, size_v: float, pos: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size_v, size_v)
	var mi := _mesh(parent, q, _shader(SOFT_CODE), pos)
	mi.visible = false
	return mi


func _stage() -> void:
	# The floor (the plinth stands on it), shown only while the crypt is dark.
	var disc := PlaneMesh.new()
	disc.size = Vector2(12, 12)
	_floor_mat = _shader(FLOOR_CODE)
	_floor = _mesh(_vp, disc, _floor_mat, Vector3(0, -0.22, 0))
	_floor.visible = false
	# The pillar of light and the rays behind the prize.
	var sm := CylinderMesh.new()
	sm.top_radius = 0.5
	sm.bottom_radius = 0.86
	sm.height = SHAFT_H
	sm.cap_top = false
	sm.cap_bottom = false
	sm.radial_segments = 24
	sm.rings = 1
	_shaft_mat = _shader(SHAFT_CODE)
	_shaft = _mesh(_vp, sm, _shaft_mat, Vector3(0, SHAFT_H * 0.5 - 0.05, 0))
	_shaft.visible = false
	var sq := QuadMesh.new()
	_sun_mat = _shader(SUN_CODE)
	sq.size = Vector2(5.0, 5.0)
	_sun = _mesh(_vp, sq, _sun_mat, Vector3.ZERO)
	_sun.visible = false
	# Rings of light running out over the floor: thin, and gone before they reach the edge.
	var thin := TorusMesh.new()
	thin.inner_radius = 0.95
	thin.outer_radius = 1.0
	thin.rings = 48
	thin.ring_segments = 4
	for i in 3:
		var wm := _unlit()
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var wmi := _mesh(_vp, thin, wm, Vector3(0, -0.2, 0))
		wmi.visible = false
		_waves.append({"mi": wmi, "mat": wm, "t": -1.0, "col": Color.WHITE})
	# Motes drawn up the pillar of light.
	_motes = CPUParticles3D.new()
	_motes.emitting = false
	_motes.amount = 26
	_motes.lifetime = 1.1
	_motes.position = Vector3(0, 0.05, 0)
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3.UP
	_motes.emission_ring_radius = 0.75
	_motes.emission_ring_inner_radius = 0.1
	_motes.emission_ring_height = 0.02
	_motes.direction = Vector3.UP
	_motes.spread = 4.0
	_motes.gravity = Vector3(0, 6.0, 0)
	_motes.initial_velocity_min = 1.5
	_motes.initial_velocity_max = 4.0
	_motes.particle_flag_align_y = true
	var mc := Curve.new()
	mc.add_point(Vector2(0, 0.0))
	mc.add_point(Vector2(0.2, 1.0))
	mc.add_point(Vector2(1, 0.0))
	_motes.scale_amount_curve = mc
	var mote := BoxMesh.new()
	mote.size = Vector3(0.014, 0.22, 0.014)
	_mote_mat = _unlit()
	_mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mote_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mote.material = _mote_mat
	_motes.mesh = mote
	_vp.add_child(_motes)
	# A glow in each eye of the skull.
	_eye_glow_mat = _shader(SOFT_CODE)
	var sz := LID_R * 2.0 + 0.07
	for x in [-1.0, 1.0]:
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.2)
		var e := _mesh(_lid, q, _eye_glow_mat, Vector3(x * 0.058, 0.055, sz + 0.12))
		e.visible = false
		_eye_glow.append(e)
	# Sparks that streak as they fly (they point the way they are going).
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 0.95
	_sparks.amount = 46
	_sparks.lifetime = 0.75
	_sparks.direction = Vector3.UP
	_sparks.spread = 85.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 6.5
	_sparks.gravity = Vector3(0, -7.0, 0)
	_sparks.damping_min = 1.0
	_sparks.damping_max = 2.5
	_sparks.particle_flag_align_y = true
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.0))
	_sparks.scale_amount_curve = sc
	var streak := BoxMesh.new()
	streak.size = Vector3(0.013, 0.18, 0.013)
	_spark_mat = _unlit()
	streak.material = _spark_mat
	_sparks.mesh = streak
	_vp.add_child(_sparks)


## The prize itself, standing on the open palm: a great gold coin with a skull and crossed
## bones struck on it (coins), a cut star (a Lucky Start), an arrow pointing up (a free
## Armory level), the hero wearing it (a new look), or a gem for anything else.
func _build_token() -> void:
	_token = Node3D.new()
	_token.visible = false
	_vp.add_child(_token)
	_coin = Node3D.new()
	_token.add_child(_coin)
	var rim_gold: StandardMaterial3D = _gold.duplicate()
	rim_gold.albedo_color = Color(1.0, 0.8, 0.3)
	rim_gold.emission = Color(0.6, 0.38, 0.06)
	_bronze = StandardMaterial3D.new()      # the coin's sunk face: deep gold
	_bronze.albedo_color = Color(0.95, 0.55, 0.1)
	_bronze.metallic = 0.85
	_bronze.roughness = 0.36
	_bronze.emission_enabled = true
	_bronze.emission = Color(0.34, 0.16, 0.01)
	_bright = _gold.duplicate()
	_bright.albedo_color = Color(1.0, 0.93, 0.62)
	_bright.emission = Color(0.85, 0.62, 0.2)
	var flat := Vector3(PI / 2.0, 0, 0)
	var st := _new_st()
	_add(st, _cyl(0.3, 0.3, 0.06, 32), _at(Vector3.ZERO, flat))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.262
	rim.outer_radius = 0.326
	rim.rings = 32
	rim.ring_segments = 8
	_add(st, rim, _at(Vector3.ZERO, flat))
	var face := _new_st()
	var sk := _new_st()
	var dk := _new_st()
	for sgn: float in [1.0, -1.0]:
		var z: float = 0.034 * sgn
		_add(face, _cyl(0.26, 0.26, 0.012, 28), _at(Vector3(0, 0, 0.028 * sgn), flat))
		for i in 18:   # a ring of studs round the edge of the face
			var a := TAU * i / 18.0
			_ball(sk, Vector3(cos(a) * 0.232, sin(a) * 0.232, z), 0.013, Vector3(1.0, 1.0, 0.6), 6)
		for sx: float in [-1.0, 1.0]:
			_tube(sk, PackedVector3Array([Vector3(-0.16 * sx, -0.155, z), Vector3(0.16 * sx, 0.0, z)]), PackedFloat32Array([0.021, 0.021]), 6)
			_ball(dk, Vector3(0.047 * sx, 0.05, z + 0.034 * sgn), 0.034, Vector3(1.0, 1.1, 0.4))
		_ball(sk, Vector3(0, 0.055, z), 0.118, Vector3(1.0, 0.95, 0.34), 12)       # the skull
		_ball(sk, Vector3(0, -0.062, z), 0.07, Vector3(1.0, 0.8, 0.36), 10)        # its jaw
		_ball(dk, Vector3(0, -0.012, z + 0.036 * sgn), 0.015, Vector3(1.0, 1.4, 0.4))
		for x: float in [-0.026, 0.0, 0.026]:
			_add(dk, _boxm(Vector3(0.007, 0.042, 0.012)), _at(Vector3(x, -0.086, z + 0.024 * sgn)))
	_put(_coin, st, rim_gold)
	_put(_coin, face, _bronze)
	_put(_coin, sk, _bright)
	_put(_coin, dk, _unlit(Color(0.3, 0.13, 0.02)))
	# A Lucky Start: a cut star, in the drop's own colour.
	var star := _new_st()
	var sp := PackedVector2Array()
	for i in 10:
		sp.append(Vector2.from_angle(PI / 2.0 + TAU * i / 10.0) * (0.36 if i % 2 == 0 else 0.155))
	_extrude(star, sp, Vector2.ZERO, 0.05, 0.1)
	_star_own = StandardMaterial3D.new()
	_star_own.metallic = 0.35
	_star_own.roughness = 0.16
	_star_own.emission_enabled = true
	_star_own.rim_enabled = true
	_star_own.rim = 0.8
	_star3 = _put(_token, star, _star_own)
	# A free Armory level: a gold arrow pointing up.
	var arrow := _new_st()
	var ap := PackedVector2Array([Vector2(0, 0.37), Vector2(0.31, 0.03), Vector2(0.13, 0.03), Vector2(0.13, -0.33),
			Vector2(-0.13, -0.33), Vector2(-0.13, 0.03), Vector2(-0.31, 0.03)])
	_extrude(arrow, ap, Vector2(0, 0.08), 0.055, 0.05)
	_arrow = _put(_token, arrow, rim_gold)
	# A new look: the hero wearing it (built at the tap, see begin).
	_hero_at = Node3D.new()
	_hero_at.position = Vector3(0, 0.07 - PRIZE_UP, 0)
	_hero_at.rotation.y = PI   # (a hero's own front is away from the camera)
	_hero_at.scale = Vector3.ONE * (HERO_TALL / 2.1)
	_token.add_child(_hero_at)
	var gm := SphereMesh.new()
	gm.radius = 0.24
	gm.height = 0.48
	gm.radial_segments = 6
	gm.rings = 2
	_gem_own = StandardMaterial3D.new()
	_gem_own.metallic = 0.3
	_gem_own.roughness = 0.08
	_gem_own.emission_enabled = true
	_gem_own.rim_enabled = true
	_gem_own.rim = 1.0
	_gem = _mesh(_token, gm, _gem_own, Vector3.ZERO)
	_gem.scale = Vector3(1.0, 1.45, 1.0)
	_token_glow = _soft(_vp, 2.2, Vector3.ZERO)
	_token_glow_mat = _token_glow.material_override
	_token_light = OmniLight3D.new()
	_token_light.omni_range = 3.0
	_token_light.light_energy = 0.0
	_vp.add_child(_token_light)


## Adds a flat shape (`pts`, going round `mid`) to `st` as a solid slab `half` thick each
## way, its two faces rising to a point `bulge` higher in the middle: a cut gem's facets.
static func _extrude(st: SurfaceTool, pts: PackedVector2Array, mid: Vector2, half: float, bulge: float) -> void:
	var n := pts.size()
	for sgn: float in [1.0, -1.0]:
		var top := Vector3(mid.x, mid.y, (half + bulge) * sgn)
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			_facet(st, top, Vector3(a.x, a.y, half * sgn), Vector3(b.x, b.y, half * sgn), Vector3(0, 0, sgn))
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var out := Vector3((a.x + b.x) * 0.5 - mid.x, (a.y + b.y) * 0.5 - mid.y, 0.0)
		_facet(st, Vector3(a.x, a.y, half), Vector3(b.x, b.y, half), Vector3(b.x, b.y, -half), out)
		_facet(st, Vector3(a.x, a.y, half), Vector3(b.x, b.y, -half), Vector3(a.x, a.y, -half), out)


## One flat triangle whose face looks towards `out`.
static func _facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var nrm := (b - a).cross(c - a).normalized()
	if nrm.dot(out) > 0.0:   # (a face is seen from the side its corners run clockwise)
		var k := b
		b = c
		c = k
	else:
		nrm = -nrm
	for v: Vector3 in [a, b, c]:
		st.set_normal(nrm)
		st.add_vertex(v)


## The Gift's arm: two long forearm bones, a wrist, a palm, four fingers and a thumb, every
## finger bone on its own joint so the fist can open.
func _build_arm() -> void:
	_arm = Node3D.new()
	_arm.visible = false
	_arm.scale = Vector3.ONE * ARM
	_vp.add_child(_arm)
	# The forearm is one unit long, hanging down from the wrist: it is stretched to reach
	# from the wrist to the chest's floor, however far the hand is out.
	_forearm = Node3D.new()
	_arm.add_child(_forearm)
	var fa := _new_st()
	for x in [-0.055, 0.06]:
		_tube(fa, PackedVector3Array([Vector3(x * 1.3, -1.0, 0), Vector3(x * 1.1, -0.8, 0), Vector3(x, -0.25, 0), Vector3(x * 1.15, -0.03, 0)]),
				PackedFloat32Array([0.05, 0.036, 0.034, 0.05]), 8)
	_put(_forearm, fa, _relic)
	var st := _new_st()
	for p: Vector3 in [Vector3(-0.07, 0.0, 0), Vector3(0.0, 0.015, 0.01), Vector3(0.07, 0.0, 0), Vector3(-0.035, 0.05, 0), Vector3(0.04, 0.05, 0)]:
		_ball(st, p, 0.042, Vector3(1.1, 0.85, 0.8))
	_put(_arm, st, _relic)
	_hand = Node3D.new()
	_hand.position = Vector3(0, 0.05, 0)
	_arm.add_child(_hand)
	var palm := _new_st()
	# x across the hand, where the knuckle is, how far it leans out, and its three bones.
	var spec := [[-0.135, 0.25, 0.16, [0.15, 0.1, 0.085]], [-0.045, 0.275, 0.05, [0.165, 0.11, 0.09]],
			[0.045, 0.262, -0.05, [0.155, 0.1, 0.085]], [0.135, 0.225, -0.17, [0.12, 0.08, 0.07]]]
	_fingers.clear()
	for f: Array in spec:
		var kx: float = f[0]
		var ky: float = f[1]
		_tube(palm, PackedVector3Array([Vector3(kx * 0.45, 0.0, 0), Vector3(kx, ky, 0)]), PackedFloat32Array([0.03, 0.03]), 7)
		var parent: Node3D = _hand
		var at := Vector3(kx, ky, 0)
		var joints := []
		var lens: Array = f[3]
		for b in lens.size():
			var j := Node3D.new()
			j.position = at
			if b == 0:
				j.rotation.z = f[2]
			parent.add_child(j)
			_finger_bone(j, float(lens[b]), 0.029 - 0.003 * b, b == lens.size() - 1)
			joints.append(j)
			parent = j
			at = Vector3(0, float(lens[b]), 0)
		_fingers.append(joints)
	# The thumb, set low on the side and turned to close across the palm.
	_tube(palm, PackedVector3Array([Vector3(-0.06, 0.0, 0.0), Vector3(-0.17, 0.06, 0.03)]), PackedFloat32Array([0.032, 0.032]), 7)
	_put(_hand, palm, _relic)
	var tb := Node3D.new()
	tb.position = Vector3(-0.17, 0.06, 0.03)
	tb.rotation = Vector3(0, 0.9, 0.85)
	_hand.add_child(tb)
	var tj := []
	var tparent: Node3D = tb
	var tat := Vector3.ZERO
	for b in 2:
		var j := Node3D.new()
		j.position = tat
		tparent.add_child(j)
		var l: float = [0.13, 0.1][b]
		_finger_bone(j, l, 0.031 - 0.003 * b, b == 1)
		tj.append(j)
		tparent = j
		tat = Vector3(0, l, 0)
	_fingers.append(tj)


func _finger_bone(joint: Node3D, l: float, r: float, tip: bool) -> void:
	var st := _new_st()
	if tip:   # the last bone tapers to a claw
		_tube(st, PackedVector3Array([Vector3.ZERO, Vector3(0, l * 0.3, 0), Vector3(0, l * 0.75, 0), Vector3(0, l * 1.15, 0.01)]),
				PackedFloat32Array([r * 1.2, r * 0.85, r * 0.6, r * 0.18]), 7)
	else:
		_tube(st, PackedVector3Array([Vector3.ZERO, Vector3(0, l * 0.25, 0), Vector3(0, l * 0.75, 0), Vector3(0, l, 0)]),
				PackedFloat32Array([r * 1.25, r * 0.85, r * 0.8, r * 1.15]), 7)
	_put(joint, st, _relic)


## Closes (`k` 1) or opens (0) the hand: a fist, or an open palm with the fingers curling
## up round what stands on it.
func _grip(k: float, t: float) -> void:
	var fist := [1.5, 1.75, 1.25]
	var claw := [0.22, 0.46, 0.5]
	for i in _fingers.size():
		var joints: Array = _fingers[i]
		var lag := clampf(k * 1.25 - 0.06 * i, 0.0, 1.0)   # the fingers open one after another
		var idle := 0.05 * sin(t * 2.3 + i * 0.9) * (1.0 - lag)
		if i == 4:
			(joints[0] as Node3D).rotation.x = lerpf(0.2, 0.95, lag) + idle
			(joints[1] as Node3D).rotation.x = lerpf(0.45, 1.1, lag) + idle
			continue
		for b in joints.size():
			(joints[b] as Node3D).rotation.x = lerpf(float(claw[b]), float(fist[b]), lag) + idle


# ---------------------------------------------------------------- the beats

## When each step up in rarity lands (seconds after the tap), when the chest bursts, and
## how long after that the prize is out, for a drop of rarity `goal`.
static func plan(goal: int) -> Dictionary:
	var beats := []
	for k in 4:
		beats.append(0.55 + BEAT * (k + 1))
	return {"beats": beats, "open": 0.55 + BEAT * goal + 0.36 + DRAWN, "reveal": 0.62}


## The tap: a drop of rarity `goal` holding `kind` ("coins", "look"...) starts to open.
## `preview`: for a new look, the hero wearing it (HeroStyle.dressed).
func begin(goal: int, kind: String, preview := {}) -> void:
	_goal = goal
	_prize = kind
	_since_was = 0.0
	_beats_done = 0
	_punch = -1.0
	_strain = false
	_cheered = false
	_arrive = -1.0
	revealed = false
	_drop_hero()
	if style > 0 and kind == "look" and preview.has("key"):
		# Built now, while the camera is on its way in, so nothing stutters at the burst.
		_hero = CharacterVisual.new()
		_hero.outline_me = true
		_hero_at.add_child(_hero)
		_hero.build(Heroes.look(preview, true))
		if preview.has("aura"):
			_hero.add_child(Fx.motif(str(preview.aura.get("motif", "wisps")), preview.aura.get("spark", Color.WHITE)))
			_hero.add_child(LookFx.aura_fx(preview.aura, true))
		if _hero._anim:
			_hero._anim.advance(0.0)   # posed now, so they never flash up in a T-pose
		_hero_id = str(preview.get("id", ""))
	_token.visible = false


func _drop_hero() -> void:
	if _hero != null and is_instance_valid(_hero):
		_hero.queue_free()
	_hero = null


## The hand holds the hero out wearing the new look (so the screen needn't show them).
func holds_look() -> bool:
	return style > 0 and _prize == "look" and _hero != null


## For the loading screen's warm-up: everything the opening draws is on show at once, so
## nothing is prepared for the first time in the middle of the first chest.
func warm() -> void:
	_floor.visible = true
	_floor_mat.set_shader_parameter("show", 1.0)
	_shaft.visible = true
	_shaft_mat.set_shader_parameter("power", 0.4)
	_sun.visible = true
	_sun.position = Vector3(0, 1.2, -0.5)
	_sun_mat.set_shader_parameter("power", 0.4)
	_token.visible = true
	_token.position = Vector3(0, 1.3, 0)
	for n: Node3D in [_coin, _star3, _arrow, _gem]:
		n.visible = true
	_token_glow.visible = true
	_token_glow.position = _token.position
	_token_glow_mat.set_shader_parameter("power", 0.3)
	_token_light.light_energy = 0.5
	_arm.visible = true
	for w: Dictionary in _waves:
		(w.mi as MeshInstance3D).visible = true
	for e in _eye_glow:
		e.visible = true
	_sparks.emitting = true
	_motes.emitting = true


## The next chest drops onto the plinth (OPEN NEXT).
func arrive() -> void:
	_arrive = 0.0
	_landed = false
	_root.position.y = 3.0   # (up out of the picture from this very frame)


func reset() -> void:
	super.reset()
	dark = 0.0
	ui = 1.0
	sun = 0.0
	shaft = 0.0
	shaft_wide = 1.0
	leak = 0.0
	flash = 0.0
	revealed = false
	_shake = 0.0
	_stop = 0.0
	_punch = -1.0
	_lid_t = -1.0
	_strain = false
	_arrive = -1.0
	light_cap = 1.0
	_drop_hero()
	_rays.set_shader_parameter("front", 1.0 if style == 0 else 0.22)
	# Nothing of the last opening is left in the air. (Setting the count again empties them;
	# restart() would send a fresh burst out over the new chest.)
	for p: CPUParticles3D in [_coins, _burst, _sparks, _dust, _motes]:
		p.emitting = false
		var count := p.amount
		p.amount = count
	for w: Dictionary in _waves:
		w.t = -1.0
		w.wait = false
		(w.mi as MeshInstance3D).visible = false
	_root.visible = true
	_lid.visible = true
	_lid.scale = Vector3.ONE
	_floor.visible = false
	_floor_mat.set_shader_parameter("show", 0.0)
	_shaft.visible = false
	_sun.visible = false
	_token.visible = false
	_token_glow.visible = false
	_token_light.light_energy = 0.0
	_arm.visible = false
	for e in _eye_glow:
		e.visible = false


func open_up(col: Color, tier := 0, silent := false) -> void:
	super.open_up(col, tier, silent)
	if style == 0:
		return
	_show_col = col
	_stop = 0.07
	_shake = 1.2
	flash = 0.3
	# (Held back until the held frame lets go; and coins only fly when coins were won.)
	for p: CPUParticles3D in [_burst, _coins]:
		p.emitting = false
		var count := p.amount
		p.amount = count
	_spark_mat.albedo_color = col.lightened(0.5) * 1.8
	_sparks.position = Vector3(0, TOP_Y * 0.6, 0)
	_sparks.amount = 30 + 8 * tier
	_motes.emitting = false
	# The lid is blown clean off.
	_lid_t = 0.0
	light_cap = 0.38
	_light.light_energy = 1.2
	_lid_vel = Vector3(-5.6, 3.2, -1.8)    # off to the side, out of the picture
	_lid_spin = Vector3(5.0, 3.0, -12.0)
	_arm.visible = true
	_wave(col, 0.0)
	if tier >= 3:
		_wave(col, -0.14)
	sun_col = col
	_token_glow_mat.set_shader_parameter("col", col.lightened(0.2))
	_token_light.light_color = col.lightened(0.5)
	# What the hand holds out is what was won.
	_coin.visible = _prize == "coins"
	_star3.visible = _prize == "lucky"
	_arrow.visible = _prize == "armory"
	_hero_at.visible = _prize == "look" and _hero != null
	_gem.visible = not (_coin.visible or _star3.visible or _arrow.visible or _hero_at.visible)
	_gem_own.albedo_color = col.lightened(0.2)
	_gem_own.emission = col * 0.9
	_star_own.albedo_color = Color.WHITE.lerp(col, 0.45)
	_star_own.emission = col.lightened(0.15) * 0.75


## A ring of light runs out over the floor from the plinth (`head_start` under 0: later).
func _wave(col: Color, head_start: float) -> void:
	var pick: Dictionary = _waves[0]
	for w: Dictionary in _waves:
		if float(w.t) < -0.5:
			pick = w
			break
		if float(w.t) > float(pick.t):
			pick = w
	pick.t = head_start if head_start < 0.0 else 0.0
	pick.col = col
	pick.wait = head_start < 0.0


func _run_waves(delta: float) -> void:
	for w: Dictionary in _waves:
		var mi: MeshInstance3D = w.mi
		if float(w.t) < -0.5 and not w.get("wait", false):
			mi.visible = false
			continue
		w.t += delta
		if float(w.t) < 0.0:
			mi.visible = false
			continue
		w.wait = false
		var rs := 1.0 + float(w.t) * 5.5
		mi.visible = true
		mi.scale = Vector3(rs, 0.3, rs)
		(w.mat as StandardMaterial3D).albedo_color = Color(w.col, 0.6 * pow(clampf(1.0 - (rs - 1.0) / 3.4, 0.0, 1.0), 1.6))
		if rs > 4.4:
			mi.visible = false
			w.t = -1.0


func _fly_lid(delta: float) -> void:
	if _lid_t < 0.0:
		return
	_lid_t += delta
	var t := _lid_t
	_lid.position = Vector3(0, TOP_Y + 0.05, -LID_R) + _lid_vel * t + Vector3(0, -8.0, 0) * 0.5 * t * t
	_lid.rotation = _lid_spin * t
	if t > 0.7:
		_lid.visible = false
		_lid_t = -1.0


# ---------------------------------------------------------------- each frame

static func _mix(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	return {"eye": (a.eye as Vector3).lerp(b.eye, f), "at": (a.at as Vector3).lerp(b.at, f),
			"zoom": lerpf(a.zoom, b.zoom, f), "free": lerpf(a.free, b.free, f)}


func _aim(p: Dictionary) -> void:
	cam_eye = p.eye
	cam_at = p.at
	cam_zoom = p.zoom
	cam_free = p.free


func animate(step: int, k: float, col: Color, tier: int, delta: float, since := 0.0, left := 0.0) -> void:
	if style == 0 or step == 0:
		super.animate(step, k, col, tier, delta, since, left)
		for e in _eye_glow:
			e.visible = false
		if _arrive >= 0.0 and step == 0:
			_drop_in(delta)
		return
	# A held frame: the blow hangs for a moment before everything flies.
	if _stop > 0.0:
		_stop -= delta
		delta = 0.0
		if _stop <= 0.0:
			_burst.restart()
			_burst.emitting = true
			if _prize == "coins":
				_coins.restart()
				_coins.emitting = true
			_sparks.restart()
			_sparks.emitting = true
	_clock += delta
	var t := _clock
	_root.position = Vector3.ZERO
	_root.rotation = Vector3(0, _yaw + sin(t * 0.6) * 0.1 * _sway, 0)
	_root.scale = Vector3.ONE
	cam_roll = 0.0
	_sun.position = Vector3(0, -50, 0)
	_gift(step, col, tier, delta, since, left)
	_since_was = since
	_tint(step, col, tier, delta)
	_fly_chains(delta)
	_fly_lid(delta)
	_run_waves(delta)
	# The camera's shake dies away.
	_shake *= exp(-delta * 6.5)
	cam_at += Vector3(sin(t * 71.0), cos(t * 83.0), 0.0) * 0.07 * _shake
	cam_roll += sin(t * 59.0) * 0.022 * _shake
	_place_camera()
	# The stage and its lights.
	_shaft.visible = shaft > 0.01
	_shaft.scale = Vector3(shaft_wide, 1.0, shaft_wide)
	_shaft_mat.set_shader_parameter("col", shaft_col.lightened(0.15))
	_shaft_mat.set_shader_parameter("power", shaft)
	_sun.visible = sun > 0.01
	_sun_spin += delta * 0.35
	_sun_mat.set_shader_parameter("col", sun_col.lightened(0.2))
	_sun_mat.set_shader_parameter("power", sun * (0.7 + 0.05 * sin(t * 4.0)))
	_sun_mat.set_shader_parameter("spin", _sun_spin)
	_floor.visible = dark > 0.02
	_floor_mat.set_shader_parameter("show", smoothstep(0.25, 0.85, dark))
	var eye_c: Color = _eye_mat.albedo_color
	_eye_glow_mat.set_shader_parameter("col", eye_c)
	_eye_glow_mat.set_shader_parameter("power", 0.75)
	for e in _eye_glow:
		e.visible = _lid.visible and _lid_t < 0.0


## The next chest falls onto the plinth, squashes and settles.
func _drop_in(delta: float) -> void:
	_arrive += delta
	var fall := 0.2
	if _arrive < fall:
		var f := _arrive / fall
		_root.position.y = 3.0 * (1.0 - f * f)
		_root.scale = Vector3(0.93, 1.12, 0.93)
		return
	if not _landed:
		_landed = true
		_dust.restart()
		_dust.emitting = true
		Sfx.play("slam", 0.5, 0.7)
		if Game.vibration:
			Input.vibrate_handheld(25)
	var u := _arrive - fall
	var sq := exp(-8.0 * u) * cos(u * 22.0)
	_root.position.y = 0.0
	_root.scale = Vector3(1.0 + 0.12 * sq, 1.0 - 0.16 * sq, 1.0 + 0.12 * sq)
	if u > 0.7:
		_arrive = -1.0


## Where the prize is (in the chest's world).
func prize_at() -> Vector3:
	return _token.position


## The prize hanging in its light, turning; `s` is seconds since it came out.
func _show_token(at: Vector3, s: float, grow: float, glow := 0.5) -> void:
	var t := _clock
	_token.visible = grow > 0.01
	_token_glow.visible = grow > 0.01
	_token.position = at + Vector3(0, 0.03 * sin(t * 2.4), 0)
	_token.scale = Vector3.ONE * grow
	# A fast spin as it comes out, slowing to face you and rock gently.
	var spin := 13.0 * exp(-3.2 * maxf(s, 0.0))
	_token.rotation = Vector3(0, spin + 0.4 * sin(t * 1.3) * (1.0 - exp(-2.0 * maxf(s, 0.0))), 0)
	_token_glow.position = _token.position
	_token_glow_mat.set_shader_parameter("power", (glow + 0.06 * sin(t * 5.0)) * grow)
	_token_light.position = _token.position + Vector3(0, 0.2, 0.9)
	_token_light.light_energy = 1.3 * grow
	# The rays turn behind it (and behind whatever holds it).
	_sun.position = _token.position + Vector3(0, 0, -0.85)


const HOME_POSE := {"eye": Vector3(0, 1.42, 2.95), "at": Vector3(0, 0.8, 0), "zoom": 1.0, "free": 0.0}

## The drop screen calls this as the rarity climbs a step.
func hit() -> void:
	if style == 0:
		super.hit()   # (The Gift times its own blows)


# ---------------------------------------------------------------- The Gift

const FACE_POSE := {"eye": Vector3(0.62, 0.98, 2.3), "at": Vector3(0.0, 0.66, 0.1), "zoom": 1.28, "free": 1.0}
const RISE_POSE := {"eye": Vector3(0.38, 0.55, 2.7), "at": Vector3(0.0, 1.12, 0.0), "zoom": 1.12, "free": 1.0}
const GIFT_POSE := {"eye": Vector3(0, 1.42, 3.2), "at": Vector3(0, 0.8, 0), "zoom": 0.95, "free": 0.0}
## A new look: the camera comes in on the hero standing on the palm (they end up where the
## chest's picture is in the screen's layout, above the writing).
const LOOK_POSE := {"eye": Vector3(0.3, 1.7, 2.5), "at": Vector3(0.0, 1.56, -0.1), "zoom": 1.32, "free": 0.0}
const WRIST_IN := 0.2      # the wrist's height while the fist waits inside
const INSIDE := 0.62       # the fist is this much smaller while it is shut in the chest
## Where the wrist ends up, how far the arm has turned (the hand is seen from its side) and
## how far the hand is tipped back at the wrist (palm up, held out): the open palm then
## lies over the middle of the chest.
const WRIST := Vector3(-0.24, 0.74, 0.2)
const ARM_YAW := -0.75
const PALM_TILT := -1.02

## Puts the wrist at `at` (the forearm reaches from there down to the chest's floor).
func _set_arm(at: Vector3, big := 1.0) -> void:
	var sc := ARM * big
	_arm.visible = true
	_arm.position = at
	_arm.scale = Vector3.ONE * sc
	_forearm.scale = Vector3(1.0, clampf((at.y - 0.14) / sc, 0.02, 1.0), 1.0)


func _gift(step: int, col: Color, tier: int, delta: float, since: float, left: float) -> void:
	var t := _clock
	var hot := col.lightened(0.3)
	if step == 1:
		ui = clampf(1.0 - since / 0.15, 0.0, 1.0)
		dark = clampf(since / 0.3, 0.0, 1.0)
		rune_rate = 0.5
		_sway = move_toward(_sway, 0.0, delta * 5.0)
		_yaw = lerpf(_yaw, -0.26, clampf(delta * 4.0, 0.0, 1.0))
		# A blow from inside on each beat: the first in the chest's own colour, then one
		# for every step up in rarity.
		var beat_at := 0.55 + BEAT * _beats_done
		if _beats_done <= _goal and since >= beat_at:
			_punch = 0.0
			_punch_size = 0.26 + 0.075 * _beats_done
			_shake = 0.45 + 0.14 * _beats_done
			if _goal > 0 and _beats_done == _goal - 1:
				snap_chain(0)
			elif _goal > 0 and _beats_done == _goal:
				snap_chain(1)
			Sfx.play("slam", 0.55 + 0.08 * _beats_done, 0.8 + 0.12 * _beats_done)
			if Game.vibration:
				Input.vibrate_handheld(20 + 6 * _beats_done)
			_beats_done += 1
			_wave(col, 0.0)
		var pop := 0.0
		if _punch >= 0.0:
			_punch += delta
			# The lid jumps and slams back, then rattles.
			if _punch < 0.17:
				pop = sin(_punch / 0.17 * PI)
			else:
				pop = 0.22 * exp(-9.0 * (_punch - 0.17)) * absf(sin((_punch - 0.17) * 26.0))
		# The last blow has landed: the chest strains, harder and harder, light pouring
		# from under the lid, until it can't hold.
		var drawn := clampf(1.0 - left / DRAWN, 0.0, 1.0) if left < DRAWN else 0.0
		var strain := drawn * drawn
		if drawn > 0.0 and not _strain:
			_strain = true
			if Sfx.has("chest_rattle"):
				Sfx.play("chest_rattle", 0.9, 1.35)
			if Game.vibration:
				Input.vibrate_handheld(180)
		var lift := pop * _punch_size + (0.03 + 0.07 * strain) * drawn * absf(sin(t * 34.0))
		_lid.rotation.x = -lift
		var kick := pop if _punch < 0.17 else 0.0
		_root.position.y = 0.09 * kick * (_punch_size / 0.3)
		_root.position.x = sin(t * 61.0) * 0.014 * strain
		_root.scale = Vector3(1.0 + 0.05 * kick + 0.05 * strain, 1.0 + 0.08 * kick - 0.07 * strain, 1.0 + 0.05 * kick + 0.05 * strain)
		_root.rotation.z = sin(t * 55.0) * (0.006 + 0.012 * float(tier) + 0.05 * strain)
		# The light that gets out, the fist that struck.
		leak = clampf(pop * 1.2 + 0.9 * drawn * (0.7 + 0.3 * sin(t * 30.0)), 0.0, 1.2)
		leak_col = col
		_glow.visible = true
		_glow_mat.set_shader_parameter("col", hot)
		_glow_mat.set_shader_parameter("power", 0.9 * leak)
		_light.light_color = col
		_light.light_energy = 0.35 * float(tier) + 3.0 * leak
		shaft = 0.15 * strain
		shaft_wide = 0.8
		shaft_col = col
		_set_arm(Vector3(0.0, WRIST_IN + 0.22 * kick * (_punch_size / 0.3), 0.06), INSIDE)
		_arm.rotation = Vector3.ZERO
		_hand.rotation = Vector3(0.1, 0, 0)
		_grip(1.0, t)
		for i in _cracks.size():
			_cracks[i].visible = i < tier
		_eye_mat.albedo_color = hot.lerp(Color.WHITE, clampf(pop + strain, 0.0, 1.0))
		_chain_mat.emission = col * (0.4 + 0.5 * float(tier) + 2.5 * pop)
		_runes.set_shader_parameter("glow", 0.5 + 0.1 * float(tier) + 0.7 * pop + 0.6 * strain)
		_floor_mat.set_shader_parameter("tint", col)
		_floor_mat.set_shader_parameter("lit", 0.4 + 0.08 * float(tier) + 0.9 * pop + 0.5 * strain)
		var pose := _mix(HOME_POSE, FACE_POSE, smoothstep(0.0, 0.5, since))
		pose.zoom *= 1.0 + 0.07 * kick + 0.07 * drawn   # (it creeps in as the chest strains)
		pose.eye += Vector3(-0.12 * since, 0.0, 0.0)
		_aim(pose)
		return
	# Burst (the drop screen has called open_up).
	_snap += delta
	_open = minf(1.0, _open + delta / 0.9)
	var s := _snap
	var sq := exp(-6.0 * s) * sin(s * 18.0)
	_root.scale = Vector3(1.0 - 0.08 * sq, 1.0 + 0.1 * sq, 1.0 - 0.08 * sq)
	_yaw = lerpf(_yaw, -0.3, clampf(delta * 3.0, 0.0, 1.0))
	_sway = move_toward(_sway, 0.5, delta * 0.8)
	_runes.set_shader_parameter("glow", 0.6 + 1.0 * exp(-3.0 * s))
	_open_glow(col, tier, delta)
	_rays.set_shader_parameter("power", 0.3 + 0.06 * float(tier))   # (the open palm is in this light: kept soft)
	_ground_shadow()
	rune_rate = 0.6
	leak = 0.0
	shaft = 0.6 * exp(-2.2 * s) + 0.12
	shaft_wide = 1.0
	shaft_col = _show_col
	_floor_mat.set_shader_parameter("tint", _show_col)
	_floor_mat.set_shader_parameter("lit", 0.6 + 1.0 * exp(-3.0 * s))
	dark = lerpf(1.0, 0.88, smoothstep(0.4, 1.5, s))
	# The arm shoots up out of the chest as a fist, a little too far, and settles. Then it
	# turns over and tips back at the wrist, and the fingers open: a palm held out to you,
	# with the prize standing on it.
	var up := clampf(s / 0.26, 0.0, 1.0) - 1.0
	var out := 1.0 + up * up * (3.4 * up + 2.4)
	var turn := smoothstep(0.36, 0.7, s)
	var open := clampf((s - 0.54) / 0.26, 0.0, 1.0)
	var oe := open - 1.0
	var spread := 1.0 + oe * oe * (2.4 * oe + 1.4)
	var wrist := Vector3(0.0, lerpf(WRIST_IN, WRIST.y + 0.05, out), lerpf(0.06, 0.1, clampf(s / 0.2, 0.0, 1.0)))
	wrist = wrist.lerp(WRIST, turn) + Vector3(0, 0.02 * sin(t * 1.7), 0)
	_set_arm(wrist, lerpf(INSIDE, 1.0, smoothstep(0.0, 0.2, s)))
	_arm.rotation = Vector3(0.03 * sin(t * 1.1), lerpf(0.5, ARM_YAW, turn) + 0.04 * sin(t * 0.9),
			0.04 * sin(t * 1.3) * turn + 0.05 * exp(-9.0 * s) * sin(s * 30.0))
	_hand.rotation = Vector3(lerpf(0.15, PALM_TILT, turn) + 0.025 * sin(t * 1.5) * turn, 0, 0)
	_grip(1.0 - spread, t)
	# The prize: a glow shut in the fist until the fingers open, then it stands on the palm.
	var held: Vector3 = _hand.global_transform * Vector3(0.0, 0.2, 0.12)
	var palm: Vector3 = _hand.global_transform * Vector3(0.0, 0.15, 0.02)
	var at := held.lerp(palm + Vector3(0, PRIZE_UP, 0), clampf(spread, 0.0, 1.0))
	var lit := clampf(s / 0.2, 0.0, 1.0)
	_show_token(at, s - 0.54, clampf(spread, 0.0, 1.12), 0.3)
	_token_glow.visible = true
	_token_glow_mat.set_shader_parameter("power", lerpf(0.4, 0.1 + 0.02 * sin(t * 5.0), clampf(open, 0.0, 1.0)) * lit)
	_token_glow.position = at + Vector3(0, 0.12, 0) * clampf(spread, 0.0, 1.0)
	_token_light.position = at + Vector3(0, 0.5, 0.9)
	_token_light.light_energy = lerpf(0.75, 0.5, clampf(open, 0.0, 1.0)) * lit
	if open > 0.0 and not revealed:
		revealed = true
		flash = 0.26
		_shake = maxf(_shake, 0.45)
		_sparks.position = at
		_sparks.restart()
		_sparks.emitting = true
	# A new look: the hero wearing it turns to show it off, then cheers.
	var looking := 0.0
	if _hero_at.visible:
		looking = smoothstep(0.6, 1.25, s)
		if not _cheered and s > 1.35 and _hero != null and is_instance_valid(_hero):
			_cheered = true
			_hero.emote(Heroes.get_hero(_hero_id).get("emote", []))
	# The camera drops back and looks up as the arm comes out, then settles (on the hero,
	# for a new look).
	var pose := _mix(FACE_POSE, RISE_POSE, 1.0 - pow(1.0 - clampf(s / 0.3, 0.0, 1.0), 3.0))
	pose = _mix(pose, GIFT_POSE, smoothstep(0.46, 1.1, s))
	_aim(_mix(pose, LOOK_POSE, looking))
	# Rays behind the fist from the moment it is out, so even a black marble hand stands
	# clear of the dark; they flare when it opens.
	_sun.position = at + Vector3(0, 0.05, -0.85)
	sun = 0.4 * smoothstep(0.05, 0.3, s) + 0.4 * smoothstep(0.54, 0.9, s)
	ui = smoothstep(0.66, 0.96, s)
