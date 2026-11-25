class_name Forgemaster
extends Enemy
## The Clockwork Foundry's own boss (floor 9, version 281). Until then the Foundry ended with
## the Cinder Colossus, the boss of floor 3.
##
## The master smith of the works where the dead forge their iron: a giant of riveted iron
## bones with a furnace burning in its ribs, a welding mask with a glowing slit for a face,
## smokestacks on its shoulders, a great brass clock wheel turning behind its head and a forge
## hammer in its fist. The whole Foundry runs to its clock. Every attack has a warning:
## - Tick-Tock Press: round marks light up on a chequer of floor tiles round you, then iron
##   presses stamp down on them; the other tiles light next, then the first again, in time
##   with its clock. Step onto a tile that has just been stamped, or walk out of the chequer.
## - Saw Blades: strips run from it past you to the wall and off it, then spinning cog saws
##   come rolling along them and bounce off the wall. Step off both strips (cover breaks them).
## - Conveyor Belts: strips across the room turn into running belts that carry you along,
##   red-hot ingots riding them. Stand in the gaps between the belts, or cross between ingots.
## - Pendulum (phase 2's own move): strips across the room, then great pendulum blades swing
##   along them from wall to wall. Keep out of the strips until they stop.
## - Iron Casting (version 303, its encore in the endless loops): channels glow across the
##   floor and molten iron runs down them, burning whoever stands there; then the iron cools
##   and rises as walls, each with a gap, that stand for a while. The room changes shape:
##   walls stop saws, ingots and shots, yours and its, so use them.
## Below half health its furnace burns white-hot, its clock races, two Clockwork Skeletons
## march out of the walls, and it attacks harder: a beat more of presses, three saws, more
## belts, two pendulums.

const DISPLAY_NAME := "The Forgemaster"
const EMBER := Color(1.0, 0.5, 0.15)
const BRASS := Color(1.0, 0.72, 0.3)
const HOT := Color(1.0, 0.9, 0.65)

## Tick-Tock Press: the chequer's tiles, the presses' circles and how long each beat warns.
const CELL := 1.8
const PRESS_R := 1.08   # v283 (Tweaks report #6): was 0.82, which left the point between four tiles never hit
const PRESS_FIRST := 0.9
const PRESS_BEAT := 0.72
const PRESS_DAMAGE := 15.0
const PRESS_DROP := 0.2     # how long a press takes to shoot down
## Saw Blades.
const SAW_AIM := 0.95
const SAW_SPEED := 10.5
const SAW_R := 0.72
const SAW_WIDTH := 1.3
const SAW_Y := 0.55         # how high over the floor it skims
const SAW_DAMAGE := 17.0
## Conveyor Belts: their width and the gap between them, how fast they run, the ingots on them.
const BELT_W := 2.0
const BELT_STEP := 3.4
const BELT_AIM := 0.95
const BELT_RUN := 4.6
const BELT_PUSH := 2.7
const INGOT_SPEED := 3.4
const INGOT_EVERY := 1.15
const INGOT_DAMAGE := 14.0
## Pendulum: the pivot high over the room, the swing's reach and time, the strip it sweeps.
const PEND_PIVOT := 7.5
const PEND_LEN := 7.0
const PEND_REACH := 0.86     # radians each way, so the blade runs from wall to wall
const PEND_PERIOD := 2.5
const PEND_AIM := 1.05
const PEND_SWINGS := 3       # passes across the room
const PEND_WIDTH := 1.5
const PEND_DAMAGE := 18.0

## For the robot (autoplay.gd): the strips a pendulum is sweeping now, and the belts running
## (each {z, w, dir}).
static var swings: Array = []
static var belts: Array = []
static var _meshes := {}

var _enraged := false
var _started := false
var _busy := false
var _t := 0.0
var _face_to := Vector3.ZERO
var _clock: Node3D        # the clock wheel behind its head
var _hour: Node3D
var _minute: Node3D
var _clock_speed := 1.0
var _furnace: MeshInstance3D
var _furnace_glow: MeshInstance3D
var _furnace_light: OmniLight3D   # the furnace lights its own iron and the floor round it
var _slit: MeshInstance3D
var _hammer_face: MeshInstance3D
var _stacks: Array[Node3D] = []
var _puff := 0.0
var _saws: Array = []     # each {node, path: Array[Vector3], leg, at, hit}
var _belt_nodes: Array = []
var _ingots: Array = []   # each {node, z, dir, x, hit}
var _pendulums: Array = []
var _stamp_sound_at := -1   # one stamp sound for all the presses of a beat
var _hung: Array = []       # presses still waiting over their marks


func _setup() -> void:
	is_boss = true
	roar_sound = "roar_forge"
	init_health(870.0)
	drop_chance = 0.0
	move_speed = 1.3
	contact_damage = 16.0
	radius = 1.15
	center_height = 1.9
	knockback_scale = 0.05
	var look := bones(Art.SKELETON_WARRIOR, 4.5, EMBER)
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Cloak"]
	look.overlay = _iron_bones()
	look.shape = {"scale": {"chest": Vector3(1.5, 1.2, 1.3), "head": 0.68, "upperarm.l": 1.4, "upperarm.r": 1.4, "upperleg.l": 0.8, "upperleg.r": 0.8}}   # (v351: a hulking iron giant)
	look.parts = "forge"
	look.attack_anim = "2H_Melee_Attack_Chop"
	make_visual(look)
	_dress()


func display_name() -> String:
	return DISPLAY_NAME


# --- How it looks ----------------------------------------------------------------------------

## Bones plated in sooty iron: dark, banded with riveted seams, a forge-hot edge. Two passes
## over its bones (darken, then the edge and the rivets).
static func _iron_bones() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float band = fract(lp.y * 5.5);
	float seam = smoothstep(0.0, 0.07, band) * smoothstep(1.0, 0.93, band);
	ALBEDO = vec3(0.6, 0.56, 0.54) * mix(0.45, 1.0, seam);
}
"""
	var edge := Shader.new()
	edge.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.3);
	float band = fract(lp.y * 5.5);
	float around = fract(atan(lp.z, lp.x) * 1.91);
	float rivet = 1.0 - smoothstep(0.04, 0.09, length(vec2((around - 0.5) * 0.55, band - 0.14)));
	ALBEDO = vec3(1.0, 0.5, 0.16) * rim * 0.8 + vec3(1.0, 0.74, 0.34) * rivet * 0.5;
}
"""
	var m := ShaderMaterial.new()
	m.shader = dark
	var f := ShaderMaterial.new()
	f.shader = edge
	m.next_pass = f
	_meshes["overlay"] = m
	return m


static func _mat(key: String) -> Material:
	var k := "mat_" + key
	if not _meshes.has(k):
		match key:
			"iron": _meshes[k] = U.mat(Color(0.2, 0.2, 0.22), 0.5)
			"mask": _meshes[k] = U.mat(Color(0.34, 0.33, 0.35), 0.4)
			"dark": _meshes[k] = U.mat(Color(0.09, 0.085, 0.09), 0.6)
			"brass": _meshes[k] = U.mat(Color(0.95, 0.68, 0.28), 0.3, 0.3)
			"copper": _meshes[k] = U.mat(Color(0.8, 0.42, 0.22), 0.35, 0.15)
			"face": _meshes[k] = U.mat(Color(0.86, 0.8, 0.64), 0.7, 0.2)
			"leather": _meshes[k] = U.mat(Color(0.3, 0.18, 0.1), 0.9)
			"ember": _meshes[k] = U.mat(Color(1.0, 0.45, 0.1), 0.4, 2.8)
			"hot": _meshes[k] = U.mat(Color(1.0, 0.86, 0.6), 0.4, 4.0)
			"ingot": _meshes[k] = U.mat(Color(1.0, 0.52, 0.14), 0.4, 2.2)
			"strip":
				var st := StandardMaterial3D.new()
				st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				st.albedo_color = Color(1.0, 0.22, 0.1, 0.24)
				_meshes[k] = st
			"glow", "glow_hot":
				var g := StandardMaterial3D.new()
				g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				g.cull_mode = BaseMaterial3D.CULL_DISABLED
				g.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				g.billboard_keep_scale = true
				g.albedo_texture = U.soft_circle()
				g.albedo_color = Color(1.0, 0.5, 0.15, 0.6) if key == "glow" else Color(1.0, 0.85, 0.6, 0.75)
				_meshes[k] = g
	return _meshes[k]


static func _rod(a: Vector3, b: Vector3, ra: float, rb: float, mat: Material, sides := 8) -> Array:
	return ClockworkSkeleton._rod(a, b, ra, rb, sides) + [mat]


## A cog standing up in the XY plane (facing +Z).
static func _cog_up(r: float, teeth: int, thick: float) -> Array:
	return [ClockworkSkeleton._cog_slab(r, teeth, thick), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)]


## The clock wheel (chest-bone space is where it hangs; built facing +Z): a great brass cog
## with a cream clock face, twelve iron hour marks and a brass hub. The hands are their own
## nodes so they can turn.
static func _clock_mesh() -> ArrayMesh:
	if _meshes.has("clock"):
		return _meshes["clock"]
	var parts := []
	parts.append(_cog_up(0.6, 18, 0.07) + [_mat("brass")])
	var face := Props._cone(0.47, 0.47, 0.03, 24)
	parts.append([face, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.045)), _mat("face")])
	var rim := TorusMesh.new()
	rim.inner_radius = 0.45
	rim.outer_radius = 0.51
	rim.rings = 24
	rim.ring_segments = 4
	parts.append([rim, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.05)), _mat("iron")])
	for i in 12:
		var a := TAU * i / 12.0
		var big := i % 3 == 0
		var at := Vector3(sin(a), cos(a), 0) * (0.37 if big else 0.39)
		parts.append([Props._cube(), Props._xf(at + Vector3(0, 0, 0.065), Vector3(0.05 if big else 0.03, 0.12 if big else 0.07, 0.02), Basis(Vector3.BACK, -a)), _mat("dark")])
	parts.append([Props._cone(0.07, 0.07, 0.06, 12), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.09)), _mat("brass")])
	_meshes["clock"] = Props._bake(parts)
	return _meshes["clock"]


## A clock hand pointing up +Y from the hub, `ln` long, with a glowing tip.
static func _hand_mesh(ln: float, w: float) -> ArrayMesh:
	var key := "hand%.2f" % ln
	if _meshes.has(key):
		return _meshes[key]
	var parts := []
	parts.append([Props._cube(), Props._xf(Vector3(0, ln * 0.45, 0), Vector3(w, ln * 0.9, 0.025)), _mat("dark")])
	parts.append([Props._cube(), Props._xf(Vector3(0, ln * 0.92, 0), Vector3(w * 1.9, w * 1.9, 0.03), Basis(Vector3.BACK, PI * 0.25)), _mat("ember")])
	_meshes[key] = Props._bake(parts)
	return _meshes[key]


## The welding mask over its face (head-bone space, +Z the face; eyes about y 0.45, z 0.42):
## a dark iron plate with brass rivets and a strap round the skull. The slit is its own node.
static func _mask_mesh() -> ArrayMesh:
	if _meshes.has("mask"):
		return _meshes["mask"]
	var parts := []
	var tilt := Basis(Vector3.RIGHT, -0.12)
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.46, 0.47), Vector3(0.62, 0.5, 0.07), tilt), _mat("mask")])
	# A brass frame round the slit.
	for sy in [-1.0, 1.0]:
		parts.append([Props._cube(), Props._xf(Vector3(0, 0.5 + sy * 0.055, 0.505 - sy * 0.007), Vector3(0.54, 0.035, 0.03), tilt), _mat("brass")])
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.25, 0.46), Vector3(0.5, 0.08, 0.08), tilt), _mat("dark")])
	for sx in [-1.0, 1.0]:
		parts.append([Props._cube(), Props._xf(Vector3(sx * 0.32, 0.46, 0.42), Vector3(0.05, 0.5, 0.12), tilt), _mat("dark")])
		for sy in [-1.0, 1.0]:
			parts.append([Props._knob(), Props._xf(Vector3(sx * 0.24, 0.46 + sy * 0.17, 0.515), Vector3.ONE * 0.035), _mat("brass")])
		# The hinge bolts on each side of the skull.
		parts.append([Props._cone(0.07, 0.07, 0.06, 10), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * 0.4, 0.5, 0.25)), _mat("brass")])
	var strap := TorusMesh.new()
	strap.inner_radius = 0.37
	strap.outer_radius = 0.43
	strap.rings = 20
	strap.ring_segments = 4
	parts.append([strap, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.6, 0.06)), _mat("leather")])
	_meshes["mask"] = Props._bake(parts)
	return _meshes["mask"]


## The furnace in its ribs (chest-bone space, +Z the front): a round iron fire door, open,
## the fire behind a grate of three bars. The fire is its own node (it turns white-hot).
static func _grate_mesh() -> ArrayMesh:
	if _meshes.has("grate"):
		return _meshes["grate"]
	var parts := []
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.22
	ring.rings = 18
	ring.ring_segments = 5
	parts.append([ring, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0)), _mat("iron")])
	for i in 3:
		var x := (i - 1) * 0.09
		parts.append([Props._cube(), Props._xf(Vector3(x, 0, 0.02), Vector3(0.025, 0.34, 0.025)), _mat("dark")])
	# The open door, swung out to the side on its hinge.
	parts.append([Props._cone(0.2, 0.2, 0.03, 14), Transform3D(Basis(Vector3.UP, 1.1) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.3, 0, 0.12)), _mat("iron")])
	_meshes["grate"] = Props._bake(parts)
	return _meshes["grate"]


## A smokestack on its shoulder: an iron chimney with a copper band and a glowing mouth.
static func _stack_mesh() -> ArrayMesh:
	if _meshes.has("stack"):
		return _meshes["stack"]
	var parts := []
	parts.append([Props._cone(0.08, 0.1, 0.6, 10), Props._xf(Vector3(0, 0.3, 0), Vector3.ONE), _mat("iron")])
	parts.append([Props._cone(0.13, 0.09, 0.1, 10), Props._xf(Vector3(0, 0.63, 0), Vector3.ONE), _mat("iron")])
	parts.append([Props._cone(0.11, 0.11, 0.06, 10), Props._xf(Vector3(0, 0.18, 0), Vector3.ONE), _mat("copper")])
	parts.append([Props._cone(0.1, 0.1, 0.012, 10), Props._xf(Vector3(0, 0.685, 0), Vector3.ONE), _mat("ember")])
	_meshes["stack"] = Props._bake(parts)
	return _meshes["stack"]


## Its forge hammer (handslot.r space, the handle up +Y): a long iron-bound handle and a huge
## head, brass bands round it, a cog on the back end. The hot face is its own node.
static func _hammer_mesh() -> ArrayMesh:
	if _meshes.has("hammer"):
		return _meshes["hammer"]
	var parts := []
	parts.append(_rod(Vector3(0, -0.25, 0), Vector3(0, 1.0, 0), 0.05, 0.045, _mat("leather")))
	for y in [-0.2, 0.3, 0.75]:
		parts.append([Props._cone(0.06, 0.06, 0.06, 8), Props._xf(Vector3(0, y, 0), Vector3.ONE), _mat("iron")])
	parts.append([Props._cube(), Props._xf(Vector3(0.04, 1.12, 0), Vector3(0.62, 0.32, 0.32)), _mat("iron")])
	for x in [-0.14, 0.2]:
		parts.append([Props._cube(), Props._xf(Vector3(x, 1.12, 0), Vector3(0.05, 0.35, 0.35)), _mat("brass")])
	# The back end: a brass cog, turned to face out along -X.
	parts.append([ClockworkSkeleton._cog_slab(0.15, 9, 0.06), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.3, 1.12, 0)), _mat("brass")])
	_meshes["hammer"] = Props._bake(parts)
	return _meshes["hammer"]


## A press (its round iron die lying flat, the piston rod up out of sight): it hangs over a
## warning, then stamps.
static func _press_mesh() -> ArrayMesh:
	if _meshes.has("press"):
		return _meshes["press"]
	var parts := []
	parts.append([Props._cone(PRESS_R - 0.04, PRESS_R, 0.34, 18), Props._xf(Vector3(0, 0.17, 0), Vector3.ONE), _mat("iron")])
	parts.append([ClockworkSkeleton._cog_slab(PRESS_R * 0.78, 14, 0.12), Props._xf(Vector3(0, 0.4, 0), Vector3.ONE), _mat("brass")])
	parts.append([Props._cone(0.34, 0.4, 0.16, 12), Props._xf(Vector3(0, 0.52, 0), Vector3.ONE), _mat("dark")])
	for i in 6:
		var a := TAU * i / 6.0
		parts.append([Props._knob(), Props._xf(Vector3(cos(a) * 0.5, 0.48, sin(a) * 0.5), Vector3.ONE * 0.06), _mat("brass")])
	parts.append([Props._cone(0.15, 0.15, 2.0, 10), Props._xf(Vector3(0, 1.6, 0), Vector3.ONE), _mat("iron")])
	parts.append([Props._cone(0.21, 0.21, 0.16, 10), Props._xf(Vector3(0, 0.75, 0), Vector3.ONE), _mat("copper")])
	_meshes["press"] = Props._bake(parts)
	return _meshes["press"]


## A saw blade: a brass cog with a red-hot rim and an iron hub, lying flat and spinning as it
## skims along a hand above the floor (flat, so it reads from above whichever way it flies).
static func _saw_mesh() -> ArrayMesh:
	if _meshes.has("saw"):
		return _meshes["saw"]
	var parts := []
	parts.append([ClockworkSkeleton._cog_slab(SAW_R * 0.74, 12, 0.09), Transform3D.IDENTITY, _mat("brass")])
	var rim := TorusMesh.new()
	rim.inner_radius = SAW_R * 0.66
	rim.outer_radius = SAW_R * 0.78
	rim.rings = 20
	rim.ring_segments = 4
	parts.append([rim, Transform3D.IDENTITY, _mat("ember")])
	parts.append([Props._cone(0.13, 0.13, 0.16, 10), Transform3D.IDENTITY, _mat("iron")])
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		parts.append([Props._cube(), Props._xf(Vector3(cos(a), 0, sin(a)) * 0.26, Vector3(0.24, 0.11, 0.06), Basis(Vector3.UP, -a)), _mat("iron")])
	_meshes["saw"] = Props._bake(parts)
	return _meshes["saw"]


## A red-hot ingot (lying along X).
static func _ingot_mesh() -> ArrayMesh:
	if _meshes.has("ingot"):
		return _meshes["ingot"]
	var parts := []
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.17, 0), Vector3(0.95, 0.3, 0.5)), _mat("ingot")])
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.34, 0), Vector3(0.75, 0.06, 0.34)), _mat("hot")])
	_meshes["ingot"] = Props._bake(parts)
	return _meshes["ingot"]


## The pendulum (pivot space, hanging down -Y): a long iron rod, a brass cog where it meets
## the blade, and the blade itself, a great iron crescent with a red-hot edge, swinging in the
## XY plane.
static func _pendulum_mesh() -> ArrayMesh:
	if _meshes.has("pendulum"):
		return _meshes["pendulum"]
	var parts := []
	var bob := Vector3(0, -PEND_LEN + 1.05, 0)
	parts.append(_rod(Vector3(0, 0.5, 0), bob, 0.08, 0.08, _mat("iron")))
	parts.append(_rod(bob + Vector3(0, 1.6, 0), bob + Vector3(0, 1.3, 0), 0.13, 0.13, _mat("copper")))
	parts.append([ClockworkSkeleton._cog_slab(0.34, 10, 0.14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), bob), _mat("brass")])
	# The crescent, hanging below the bob: its body between two arcs, its red-hot edge a
	# thinner band round the outside.
	var c := Vector2(0, 0.5)
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	var rim_in: Array[Vector2] = []
	var rim_out: Array[Vector2] = []
	var n := 16
	for i in n + 1:
		var k := float(i) / n
		var a := lerpf(PI * 1.18, PI * 1.82, k)
		var d := Vector2(cos(a), sin(a))
		outer.append(c + d * 1.5)
		rim_in.append(c + d * 1.47)
		rim_out.append(c + d * 1.7)
		inner.append(Vector2(0, 0.95) + d * (1.25 + 0.3 * sin(PI * k)))
	parts.append([_band(outer, inner, 0.06), Transform3D(Basis.IDENTITY, bob), _mat("iron")])
	parts.append([_band(rim_out, rim_in, 0.04), Transform3D(Basis.IDENTITY, bob), _mat("ember")])
	_meshes["pendulum"] = Props._bake(parts)
	return _meshes["pendulum"]


## A curved band standing in the XY plane between the arcs `a` and `b` (as many points each),
## `thick` through, faced front and back, its outer edge walled.
static func _band(a: Array[Vector2], b: Array[Vector2], thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thick * 0.5
	for i in a.size() - 1:
		var a0 := Vector3(a[i].x, a[i].y, 0)
		var a1 := Vector3(a[i + 1].x, a[i + 1].y, 0)
		var b0 := Vector3(b[i].x, b[i].y, 0)
		var b1 := Vector3(b[i + 1].x, b[i + 1].y, 0)
		var f := Vector3(0, 0, h)
		Props._quad(st, a0 + f, a1 + f, b1 + f, b0 + f, Vector3.BACK)
		Props._quad(st, a0 - f, a1 - f, b1 - f, b0 - f, Vector3.FORWARD)
		var out := Vector3(a1.y - a0.y, a0.x - a1.x, 0).normalized()
		if out.dot(a0 - b0) < 0.0:
			out = -out
		Props._quad(st, a0 - f, a1 - f, a1 + f, a0 + f, out)
	st.index()
	return st.commit()


static func _belt_mat(dir: float) -> ShaderMaterial:
	var key := "belt%d" % int(dir)
	if not _meshes.has(key + "_shader"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float dir = 1.0;
uniform float speed = 2.7;
uniform float fade = 1.0;
uniform float len = 12.0;
void fragment() {
	// UV.x runs along the belt (`len` metres), UV.y across it.
	float x = UV.x * len;
	float across = abs(UV.y - 0.5) * 2.0;
	float s = fract((x - TIME * speed * dir) * 2.0);
	float slat = smoothstep(0.0, 0.1, s) * smoothstep(1.0, 0.88, s);
	float side = smoothstep(0.82, 0.88, across);
	float cv = fract(x * 0.45 + across * 0.32 * dir - TIME * speed * dir * 0.45);
	float chev = smoothstep(0.0, 0.05, cv) * smoothstep(0.26, 0.2, cv) * (1.0 - side);
	vec3 base = mix(vec3(0.06, 0.055, 0.05), vec3(0.15, 0.13, 0.11), slat);
	base = mix(base, vec3(0.36, 0.27, 0.13), side);
	ALBEDO = base;
	ROUGHNESS = 0.6;
	EMISSION = vec3(1.0, 0.48, 0.1) * chev * 0.75 + vec3(0.6, 0.4, 0.15) * side * 0.15;
	ALPHA = fade * smoothstep(0.0, 0.015, UV.x) * smoothstep(1.0, 0.985, UV.x);
}
"""
		_meshes[key + "_shader"] = sh
	var m := ShaderMaterial.new()
	m.shader = _meshes[key + "_shader"]
	m.set_shader_parameter("dir", dir)
	m.set_shader_parameter("speed", BELT_PUSH)
	m.set_shader_parameter("len", Room.HALF_W * 2.0)
	return m


func _glow(parent: Node3D, size: float, hot := false) -> MeshInstance3D:
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	g.mesh = q
	g.material_override = _mat("glow_hot" if hot else "glow")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(g)
	return g


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		var mask := MeshInstance3D.new()
		mask.mesh = _mask_mesh()
		head.add_child(mask)
		_slit = MeshInstance3D.new()
		_slit.mesh = Props._cube()
		_slit.material_override = _mat("ember")
		_slit.scale = Vector3(0.46, 0.06, 0.03)
		_slit.position = Vector3(0, 0.5, 0.515)
		_slit.rotation.x = -0.12
		_slit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(_slit)
		var sg := _glow(head, 0.9)
		sg.position = Vector3(0, 0.5, 0.56)
	if skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		_clock = Node3D.new()
		_clock.position = Vector3(0, 0.95, -0.42)
		_clock.rotation.x = -0.6   # tipped back to face up at the camera
		chest.add_child(_clock)
		var wheel := MeshInstance3D.new()
		wheel.mesh = _clock_mesh()
		_clock.add_child(wheel)
		_hour = MeshInstance3D.new()
		(_hour as MeshInstance3D).mesh = _hand_mesh(0.26, 0.05)
		_hour.position = Vector3(0, 0, 0.085)
		_clock.add_child(_hour)
		_minute = MeshInstance3D.new()
		(_minute as MeshInstance3D).mesh = _hand_mesh(0.4, 0.035)
		_minute.position = Vector3(0, 0, 0.1)
		_clock.add_child(_minute)
		var grate := MeshInstance3D.new()
		grate.mesh = _grate_mesh()
		grate.position = Vector3(0, 0.2, 0.3)
		chest.add_child(grate)
		_furnace = MeshInstance3D.new()
		_furnace.mesh = Props._sphere()
		_furnace.material_override = _mat("ember")
		_furnace.scale = Vector3(0.17, 0.17, 0.1)
		_furnace.position = Vector3(0, 0.2, 0.25)
		_furnace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chest.add_child(_furnace)
		_furnace_glow = _glow(chest, 1.5)
		_furnace_glow.position = Vector3(0, 0.2, 0.42)
		_furnace_light = OmniLight3D.new()
		_furnace_light.light_color = Color(1.0, 0.55, 0.2)
		_furnace_light.light_energy = 2.2
		_furnace_light.omni_range = 4.0
		_furnace_light.shadow_enabled = false
		add_child(_furnace_light)
		_furnace_light.position = Vector3(0, 1.9, 0)
		for sx in [-1.0, 1.0]:
			var st := MeshInstance3D.new()
			st.mesh = _stack_mesh()
			st.position = Vector3(sx * 0.4, 0.42, -0.2)
			st.rotation = Vector3(-0.2, 0, -sx * 0.5)
			chest.add_child(st)
			_stacks.append(st)
	if skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var hammer := MeshInstance3D.new()
		hammer.mesh = _hammer_mesh()
		hand.add_child(hammer)
		_hammer_face = MeshInstance3D.new()
		_hammer_face.mesh = Props._cube()
		_hammer_face.material_override = _mat("ember")
		_hammer_face.scale = Vector3(0.04, 0.27, 0.27)
		_hammer_face.position = Vector3(0.36, 1.12, 0)
		hand.add_child(_hammer_face)


## For the shader warm-up (warmup.gd): a press, a saw, an ingot, a belt and a pendulum.
static func warm(parent: Node3D, at: Vector3) -> void:
	var press := MeshInstance3D.new()
	press.mesh = _press_mesh()
	parent.add_child(press)
	press.position = at + Vector3(-1.2, 0, 0)
	var saw := MeshInstance3D.new()
	saw.mesh = _saw_mesh()
	parent.add_child(saw)
	saw.position = at + Vector3(1.2, 0.6, 0)
	var ingot := MeshInstance3D.new()
	ingot.mesh = _ingot_mesh()
	parent.add_child(ingot)
	ingot.position = at + Vector3(0, 0, 1.2)
	var belt := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2.0, 1.0)
	belt.mesh = q
	belt.material_override = _belt_mat(1.0)
	parent.add_child(belt)
	belt.position = at + Vector3(0, 0.04, -1.2)
	var pend := MeshInstance3D.new()
	pend.mesh = _pendulum_mesh()
	parent.add_child(pend)
	pend.position = at + Vector3(0, PEND_LEN, -2.0)


func _process(delta: float) -> void:
	super._process(delta)
	if dead:
		return
	# The clock: the minute hand sweeps round, the hour hand creeps, faster when it is angry
	# or busy; the whole wheel ticks round a notch at a time.
	var want := (3.2 if _enraged else 1.6) * (1.6 if _busy else 1.0)
	_clock_speed = lerpf(_clock_speed, want, 1.0 - exp(-4.0 * delta))
	if _minute:
		_minute.rotation.z -= delta * _clock_speed * 2.2
	if _hour:
		_hour.rotation.z -= delta * _clock_speed * 0.35
	if _clock:
		var tick := floorf(_t * (2.0 if _enraged else 1.0))
		_clock.get_child(0).rotation.z = lerp_angle(_clock.get_child(0).rotation.z, -tick * TAU / 18.0, 1.0 - exp(-18.0 * delta))
	if _furnace_glow:
		var f := 1.0 + 0.12 * sin(_t * 9.0) + 0.08 * sin(_t * 23.0)
		_furnace_glow.scale = Vector3.ONE * f * (1.35 if _enraged else 1.0)
		if _furnace_light:
			_furnace_light.global_position = _furnace.global_position + global_basis.z * -0.9 + Vector3.UP * 0.2
			_furnace_light.light_energy = (2.2 if not _enraged else 3.0) * f
	_puff -= delta
	if _puff <= 0.0 and not _stacks.is_empty():
		_puff = randf_range(0.25, 0.5) / (1.6 if _enraged else 1.0)
		var st: Node3D = _stacks[randi() % _stacks.size()]
		var top := st.global_position + st.global_basis.y * 1.4
		Fx._burst(top, 3, Color(0.5, 0.47, 0.45, 0.45), 0.6, 0.8, 1.1, -1.2)
		if randf() < 0.4:
			Fx.sparks(top, EMBER)


## Phase 2: the furnace, the slit of its mask and its hammer burn white-hot.
func _white_hot() -> void:
	for m: MeshInstance3D in [_furnace, _slit, _hammer_face]:
		if m:
			m.material_override = _mat("hot")
	if _furnace_glow:
		_furnace_glow.material_override = _mat("glow_hot")
	if _furnace_light:
		_furnace_light.light_color = Color(1.0, 0.82, 0.6)
	if _clock:
		_clock.create_tween().tween_property(_clock, "scale", Vector3.ONE * 1.12, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- How it fights ---------------------------------------------------------------------------

func _think(hero: Hero, delta: float) -> void:
	_t += delta
	if not _started:
		_started = true
		Sfx.play(roar_sound)
		Sfx.play("press", 0.6, 0.8)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.25
		phase_two(HOT, "pendulum", "Pendulum")
		_white_hot()
		_call_clockworks()
	if _busy:
		stand(delta)
		if _face_to != Vector3.ZERO:
			face(_face_to, 12.0, delta)
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > 4.5:
		walk(to, delta)
	else:
		stand(delta)
		face(to, 6.0, delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _alive() -> bool:
	return is_instance_valid(self) and not dead and Game.state == Game.State.PLAYING


func _brain() -> void:
	await _wait(1.2)
	encore_first()
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["presses", "saws", "belts", "saws"]
		if _enraged:
			moves.append("pendulum")   # phase 2's own move
		if returning() and _casts.is_empty():
			moves.append("encore")   # Iron Casting (version 303)
		match next_move(moves):
			"presses": await _presses()
			"saws": await _throw_saws()
			"belts": await _run_belts()
			"pendulum": await _pendulum()
			"encore": await _iron_casting()
		_busy = false
		_face_to = Vector3.ZERO
		await _wait(1.0 if _enraged else 1.5)


func _room() -> Node:
	return Room.current if is_instance_valid(Room.current) else get_parent()


func _cast() -> void:
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)


func _slam() -> void:
	if not visual.play_named("1H_Melee_Attack_Jump_Chop"):
		visual.attack(false)


func _hit(dmg: float, dir: Vector3, push: float, source: String) -> void:
	var h := Game.hero
	if h == null or not h.can_be_hit():
		return
	Game.hit_source = source
	h.take_damage(dmg, dir if dir.length() > 0.05 else Vector3.BACK, push)
	Fx.impact(h.global_position + Vector3.UP * 0.7, EMBER, 1.0)


# Tick-Tock Press ---------------------------------------------------------------------------------

## A chequer of tiles round the hero; the tiles of one colour light and are stamped, then the
## other colour's, beat after beat in time with its clock.
func _presses() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_face_to = hero.global_position - global_position
	_slam()
	Sfx.play(roar_sound, 0.45, 1.2)
	var c := hero.global_position
	var room := Room.current
	var tiles: Array = [[], []]   # the two colours: each a list of spots
	for i in range(-2, 3):
		for j in range(-2, 3):
			var p := Vector3(c.x + i * CELL, 0.0, c.z + j * CELL)
			if absf(p.x) > Room.HALF_W - 0.7 or absf(p.z) > Room.HALF_L - 0.7:
				continue
			if room and not room.is_walkable(p, 0.4):
				continue
			if Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + PRESS_R + 0.3:
				continue
			(tiles[posmod(i + j, 2)] as Array).append(p)
	var beats := 4 if _enraged else 3
	var source := kind_name()
	for b in beats:
		if not _alive():
			return
		var spots: Array = tiles[b % 2]
		var warn := PRESS_FIRST if b == 0 else PRESS_BEAT
		for k in spots.size():
			var p: Vector3 = spots[k]
			var press := _hang_press(p, warn)
			track(Telegraph.circle(p, PRESS_R, warn, _stamp.bind(p, press, source), 0.6 if k == 0 else 0.0))
		Sfx.play("tick", 0.8, 1.0 if b % 2 == 0 else 0.8)
		await _wait(warn)
	await _wait(0.5)


## A press over a warning: out of sight until the warning is nearly full, then it shoots
## down out of the dark and lands as the warning does (only the marks show while you choose
## where to step).
func _hang_press(p: Vector3, warn: float) -> Node3D:
	var n := MeshInstance3D.new()
	n.mesh = _press_mesh()
	n.visible = false
	_room().add_child(n)
	n.global_position = p + Vector3.UP * 7.0
	n.rotation.y = randf() * TAU
	# Its whole life is its own tween (down, a moment on the floor, back up and gone), so no
	# press is ever left behind; the stamp itself (_stamp) only hurts.
	var tw := n.create_tween()
	tw.tween_interval(maxf(warn - PRESS_DROP, 0.0))
	tw.tween_callback(n.show)
	tw.tween_property(n, "global_position:y", 0.0, PRESS_DROP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.24)
	tw.tween_property(n, "global_position:y", 3.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(n, "scale", Vector3.ONE * 0.05, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)
	_hung.append(n)
	return n


func _stamp(spot: Vector3, press: Node3D, source: String) -> void:
	_hung = _hung.filter(func(x): return is_instance_valid(x) and x != press)
	if not _alive():
		return
	var h := Game.hero
	if h:
		var d := h.global_position - spot
		d.y = 0.0
		if d.length() < PRESS_R + h.radius * 0.5:
			_hit(PRESS_DAMAGE, d, 6.0, source)
	Fx.dust(spot, 8)
	if randf() < 0.5:
		Fx.sparks(spot + Vector3.UP * 0.2, BRASS)
	if _stamp_sound_at != Engine.get_process_frames():
		_stamp_sound_at = Engine.get_process_frames()
		Sfx.play("press", 0.8, randf_range(0.95, 1.05))
		Game.shake(0.12)



# Saw Blades ----------------------------------------------------------------------------------

## A saw's path from `from` along `dir`: on to the wall, then once off it (cover breaks it).
func _saw_path(from: Vector3, dir: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = [from]
	var p := from
	var d := dir
	for leg in 2:
		var gone := 0.0
		var stopped_by_cover := false
		while gone < 26.0:
			var n := p + d * 0.2
			if absf(n.x) > Room.HALF_W - SAW_R - 0.1 or absf(n.z) > Room.HALF_L - SAW_R - 0.1:
				break
			if is_instance_valid(Room.current) and Room.current.blocks_shot(n, SAW_R * 0.7):
				stopped_by_cover = true
				break
			p = n
			gone += 0.2
		path.append(p)
		if stopped_by_cover or leg == 1:
			break
		# Off the wall it hit: the blocked side turns round.
		if absf(p.x + d.x * 0.3) > Room.HALF_W - SAW_R - 0.1:
			d.x = -d.x
		if absf(p.z + d.z * 0.3) > Room.HALF_L - SAW_R - 0.1:
			d.z = -d.z
	return path


func _throw_saws() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	_face_to = to
	var base := atan2(to.z, to.x)
	var n := 3 if _enraged else 2
	var spread := 0.42 if _enraged else 0.26
	var source := kind_name()
	_cast()
	Sfx.play(roar_sound, 0.5, 1.1)
	_saws.clear()
	for i in n:
		var a := base + (i - (n - 1) * 0.5) * spread * (2.0 if n == 2 else 1.0)
		var d := Vector3(cos(a), 0.0, sin(a))
		var start := global_position + d * (radius + 0.4)
		start.y = 0.0
		var path := _saw_path(start, d)
		for k in path.size() - 1:
			var seg := path[k + 1] - path[k]
			if seg.length() > 0.3:
				track(Telegraph.line(path[k], seg.normalized(), seg.length() + SAW_R, SAW_WIDTH, SAW_AIM, Callable(), 0.6 if i == 0 and k == 0 else 0.0))
		var node := Node3D.new()
		var m := MeshInstance3D.new()
		m.mesh = _saw_mesh()
		node.add_child(m)
		_glow(node, SAW_R * 2.6)
		_room().add_child(node)
		node.global_position = start + Vector3.UP * SAW_Y
		node.scale = Vector3.ONE * 0.01
		node.create_tween().tween_property(node, "scale", Vector3.ONE, SAW_AIM * 0.6)
		_saws.append({"node": node, "blade": m, "path": path, "leg": 0, "hit": false})
	Sfx.play("saw", 0.6, 0.8)
	# While the strips warn, the blades spin up in front of it.
	var t := 0.0
	while t < SAW_AIM and _alive():
		var dt := get_process_delta_time()
		t += dt
		for s: Dictionary in _saws:
			var blade: Node3D = s.blade
			if is_instance_valid(blade):
				blade.rotation.y -= dt * (6.0 + 30.0 * t / SAW_AIM)
		await frame()
	if not _alive():
		_clear_saws()
		return
	_slam()
	Sfx.play("saw", 1.0, randf_range(0.95, 1.05))
	Game.shake(0.15)
	var guard := 0.0
	while _alive() and not _saws.is_empty() and guard < 5.0:
		var dt := get_process_delta_time()
		guard += dt
		_roll_saws(dt, source)
		await frame()
	_clear_saws()
	await _wait(0.2)


func _roll_saws(dt: float, source: String) -> void:
	var h := Game.hero
	var keep: Array = []
	for s: Dictionary in _saws:
		var node: Node3D = s.node
		if not is_instance_valid(node):
			continue
		var path: Array[Vector3] = s.path
		var leg: int = s.leg
		var at := Vector3(node.global_position.x, 0.0, node.global_position.z)
		var goal: Vector3 = path[leg + 1]
		var to := goal - at
		var step := SAW_SPEED * dt
		if to.length() <= step:
			at = goal
			leg += 1
			s.leg = leg
			if leg >= path.size() - 1:
				_saw_breaks(node)
				continue
			Sfx.play("slam", 0.55, randf_range(1.4, 1.6))
			Fx.impact(at + Vector3.UP * 0.5, BRASS, 0.9)
			Game.shake(0.1)
		else:
			at += to.normalized() * step
		node.global_position = at + Vector3.UP * SAW_Y
		var dir := (path[mini(leg + 1, path.size() - 1)] - at)
		dir.y = 0.0
		var blade: Node3D = s.blade
		if is_instance_valid(blade):
			blade.rotation.y -= dt * SAW_SPEED / SAW_R
		# Version 282 (Tweaks report #5): on a timer, not once a frame (twice as many on a
		# 120 Hz phone), like the Crystal Tyrant's carts.
		s.spark = float(s.get("spark", 0.0)) - dt
		if float(s.spark) <= 0.0:
			s.spark = 0.06
			Fx.sparks(at + Vector3.UP * 0.05, Color(1.0, 0.75, 0.4))
		if not bool(s.hit) and h and h.can_be_hit():
			var off := h.global_position - at
			off.y = 0.0
			if off.length() < SAW_R + h.radius * 0.6:
				s.hit = true
				var side := dir.normalized().cross(Vector3.UP)
				_hit(SAW_DAMAGE, (dir.normalized() + side * signf(off.dot(side) + 0.01) * 0.7).normalized(), 9.0, source)
				Game.shake(0.18)
		keep.append(s)
	_saws = keep


func _saw_breaks(node: Node3D) -> void:
	var at := node.global_position
	Sfx.play("slam", 0.6, randf_range(0.8, 0.9))
	Fx.impact(at, BRASS, 1.1)
	Fx._burst(at, 14, Color(1.0, 0.7, 0.35, 0.9), 0.25, 4.0, 0.5, 9.0)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(node.queue_free)


func _clear_saws() -> void:
	for s: Dictionary in _saws:
		if is_instance_valid(s.node):
			(s.node as Node).queue_free()
	_saws.clear()


# Conveyor Belts ------------------------------------------------------------------------------

func _run_belts() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_face_to = hero.global_position - global_position
	_cast()
	Sfx.play(roar_sound, 0.5, 1.0)
	var lim := Room.HALF_L - BELT_W * 0.5 - 0.2
	var z0 := clampf(hero.global_position.z, -lim, lim)
	var ks := [-2, -1, 0, 1, 2] if _enraged else [-1, 0, 1]
	var first_dir := 1.0 if randf() < 0.5 else -1.0
	var lanes: Array = []
	for k: int in ks:
		var z := z0 + k * BELT_STEP
		if absf(z) > lim:
			continue
		lanes.append({"z": z, "w": BELT_W, "dir": first_dir * (1.0 if posmod(k, 2) == 0 else -1.0)})
	for i in lanes.size():
		var l: Dictionary = lanes[i]
		var d := float(l.dir)
		track(Telegraph.line(Vector3(-d * (Room.HALF_W - 0.1), 0.0, float(l.z)), Vector3(d, 0, 0), Room.HALF_W * 2.0 - 0.2, BELT_W, BELT_AIM, Callable(), 0.6 if i == 0 else 0.0))
	await _wait(BELT_AIM)
	if not _alive():
		return
	Sfx.play("belt", 0.9, 1.0)
	Game.shake(0.12)
	var room := _room()
	for l: Dictionary in lanes:
		var q := PlaneMesh.new()
		q.size = Vector2(Room.HALF_W * 2.0, BELT_W)
		var b := MeshInstance3D.new()
		b.mesh = q
		var mat := _belt_mat(float(l.dir))
		mat.set_shader_parameter("fade", 0.0)
		b.material_override = mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		room.add_child(b)
		b.global_position = Vector3(0, 0.04, float(l.z))
		b.create_tween().tween_method(func(v: float): mat.set_shader_parameter("fade", v), 0.0, 1.0, 0.25)
		_belt_nodes.append(b)
	belts = lanes
	var source := kind_name()
	var since: Array[float] = []
	for i in lanes.size():
		since.append(INGOT_EVERY * (0.85 - 0.3 * (i % 2)))   # the first ingots come at once, staggered
	var t := 0.0
	var clatter := 0.0
	while t < BELT_RUN and _alive():
		var dt := get_process_delta_time()
		t += dt
		for i in lanes.size():
			since[i] += dt
			if since[i] >= INGOT_EVERY and t < BELT_RUN - 1.2:
				since[i] = randf_range(-0.25, 0.1)
				_drop_ingot(lanes[i])
		_carry(dt)
		_ride_ingots(dt, source)
		clatter -= dt
		if clatter <= 0.0:
			clatter = 0.9
			Sfx.play("belt", 0.35, randf_range(1.05, 1.15))
		await frame()
	# The belts run down; the ingots still on them roll off the end.
	belts = []
	for b in _belt_nodes:
		if is_instance_valid(b):
			var mat: ShaderMaterial = (b as MeshInstance3D).material_override
			var tw := (b as Node).create_tween()
			tw.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.3)
			tw.tween_callback((b as Node).queue_free)
	_belt_nodes.clear()
	var guard := 0.0
	while _alive() and not _ingots.is_empty() and guard < 1.0:
		var dt := get_process_delta_time()
		guard += dt
		_ride_ingots(dt, source)
		await frame()
	_clear_ingots()


func _drop_ingot(lane: Dictionary) -> void:
	var d := float(lane.dir)
	var n := MeshInstance3D.new()
	n.mesh = _ingot_mesh()
	_room().add_child(n)
	var x := -d * (Room.HALF_W - 0.6)
	n.global_position = Vector3(x, 0.05, float(lane.z) + randf_range(-0.25, 0.25))
	n.rotation.y = randf_range(-0.12, 0.12)
	_ingots.append({"node": n, "dir": d, "x": x, "z": n.global_position.z, "hit": false})
	Fx.sparks(n.global_position + Vector3.UP * 0.3, EMBER)


## The belts carry the hero along (never while dashing).
func _carry(dt: float) -> void:
	var h := Game.hero
	if h == null or h.dead or h.is_dashing():
		return
	for l: Dictionary in belts:
		if absf(h.global_position.z - float(l.z)) < float(l.w) * 0.5:
			var step := Vector3(float(l.dir) * BELT_PUSH * dt, 0, 0)
			h.global_position = Room.current.resolve_move(h.global_position, step, h.radius) if is_instance_valid(Room.current) else h.global_position + step
			return


func _ride_ingots(dt: float, source: String) -> void:
	var h := Game.hero
	var keep: Array = []
	for g: Dictionary in _ingots:
		var n: Node3D = g.node
		if not is_instance_valid(n):
			continue
		var d := float(g.dir)
		var x := float(g.x) + d * INGOT_SPEED * dt
		g.x = x
		var p := Vector3(x, 0.05, float(g.z))
		n.global_position = p
		if absf(x) > Room.HALF_W - 0.4 or (is_instance_valid(Room.current) and Room.current.blocks_shot(p, 0.35)):
			# Off the end of the belt (or into cover): it tips over in a hiss of sparks.
			Fx.sparks(p + Vector3.UP * 0.3, EMBER)
			Fx._burst(p + Vector3.UP * 0.3, 6, Color(0.6, 0.58, 0.56, 0.4), 0.5, 1.0, 0.8, -1.0)
			n.queue_free()
			continue
		if not bool(g.hit) and h and h.can_be_hit():
			var off := h.global_position - p
			if absf(off.x) < 0.48 + h.radius * 0.6 and absf(off.z) < 0.25 + h.radius * 0.6:
				g.hit = true
				_hit(INGOT_DAMAGE, Vector3(d, 0, signf(off.z + 0.01) * 0.8).normalized(), 7.0, source)
		keep.append(g)
	_ingots = keep


func _clear_ingots() -> void:
	for g: Dictionary in _ingots:
		if is_instance_valid(g.node):
			(g.node as Node).queue_free()
	_ingots.clear()


func _clear_belts() -> void:
	belts = []
	for b in _belt_nodes:
		if is_instance_valid(b):
			(b as Node).queue_free()
	_belt_nodes.clear()
	_clear_ingots()


# Pendulum ------------------------------------------------------------------------------------

## Phase 2's own move: strips across the room, then great blades swing along them, wall to
## wall, a few times over.
func _pendulum() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_face_to = hero.global_position - global_position
	_cast()
	Sfx.play(roar_sound, 0.6, 0.9)
	var lim := Room.HALF_L - 1.2
	var zs: Array[float] = [clampf(hero.global_position.z, -lim, lim)]
	if _enraged:
		var other := zs[0] + 3.6 * (1.0 if zs[0] < 0.0 else -1.0)
		zs.append(clampf(other, -lim, lim))
	var room := _room()
	_pendulums.clear()
	for i in zs.size():
		var z := zs[i]
		track(Telegraph.line(Vector3(-(Room.HALF_W - 0.1), 0, z), Vector3.RIGHT, Room.HALF_W * 2.0 - 0.2, PEND_WIDTH, PEND_AIM, Callable(), 0.6 if i == 0 else 0.0))
		var pivot := Node3D.new()
		room.add_child(pivot)
		pivot.global_position = Vector3(0, PEND_PIVOT, z)
		var m := MeshInstance3D.new()
		m.mesh = _pendulum_mesh()
		pivot.add_child(m)
		var side := 1.0 if i % 2 == 0 else -1.0
		pivot.rotation.z = side * PEND_REACH * 1.1   # pulled back at the side while it warns
		_pendulums.append({"pivot": pivot, "z": z, "side": side, "last": side, "hit": false, "strip": null})
	Sfx.play("pendulum", 0.6, 0.8)
	await _wait(PEND_AIM)
	if not _alive():
		_clear_pendulums()
		return
	swings = zs.duplicate()
	# While they swing, their strips stay marked on the floor (a dim red band).
	for p: Dictionary in _pendulums:
		var strip := U.floor_quad(room, Vector2(Room.HALF_W * 2.0 - 0.2, PEND_WIDTH), _mat("strip"), Vector3(0, 0.035, float(p.z)))
		p.strip = strip
	var source := kind_name()
	var t := 0.0
	var run := PEND_PERIOD * 0.5 * PEND_SWINGS
	while t < run and _alive():
		var dt := get_process_delta_time()
		t += dt
		for p: Dictionary in _pendulums:
			_swing(p, t, source)
		await frame()
	swings = []
	# The blades swing back up out of the way.
	for p: Dictionary in _pendulums:
		if is_instance_valid(p.strip):
			(p.strip as Node).queue_free()
		var pivot: Node3D = p.pivot
		if is_instance_valid(pivot):
			var tw := pivot.create_tween()
			tw.tween_property(pivot, "global_position:y", PEND_PIVOT + 8.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(pivot.queue_free)
	_pendulums.clear()
	await _wait(0.3)


func _swing(p: Dictionary, t: float, source: String) -> void:
	var pivot: Node3D = p.pivot
	if not is_instance_valid(pivot):
		return
	var side := float(p.side)
	var a := side * PEND_REACH * 1.1 * cos(TAU * t / PEND_PERIOD)
	pivot.rotation.z = a
	var bx := pivot.global_position.x + PEND_LEN * sin(a)
	var z := float(p.z)
	# A whoosh each time it passes the middle.
	var now := signf(a)
	if now != float(p.last):
		p.last = now
		p.hit = false
		Sfx.play("pendulum", 0.7, randf_range(0.95, 1.05))
		Fx.sparks(Vector3(bx, 0.6, z), EMBER)
	var h := Game.hero
	if not bool(p.hit) and h and h.can_be_hit():
		var off := h.global_position - Vector3(bx, 0, z)
		if absf(off.z) < PEND_WIDTH * 0.5 + h.radius * 0.3 and absf(off.x) < 1.2 + h.radius * 0.4:
			p.hit = true
			var swing_dir := signf(-side * sin(TAU * t / PEND_PERIOD))   # which way the blade moves now
			_hit(PEND_DAMAGE, Vector3(swing_dir if swing_dir != 0.0 else 1.0, 0, signf(off.z + 0.01) * 0.6).normalized(), 10.0, source)
			Game.shake(0.2)


func _clear_pendulums() -> void:
	swings = []
	for p: Dictionary in _pendulums:
		if is_instance_valid(p.strip):
			(p.strip as Node).queue_free()
		if is_instance_valid(p.pivot):
			(p.pivot as Node).queue_free()
	_pendulums.clear()


# Phase 2 ---------------------------------------------------------------------------------------

## Two Clockwork Skeletons march out of the side walls (after its roar).
func _call_clockworks() -> void:
	await _wait(1.0)
	for i in 2:
		if not _alive() or Game.alive_enemies >= 6:
			return
		var spot := _open_spot(global_transform.basis.x * (1.0 if i == 0 else -1.0))
		Fx._burst(spot + Vector3.UP * 0.5, 14, Color(0.75, 0.73, 0.7, 0.5), 0.6, 1.6, 1.0, -1.0)
		Fx._burst(spot + Vector3.UP * 0.4, 16, Color(1.0, 0.7, 0.35, 0.9), 0.25, 3.0, 0.5, 8.0)
		Sfx.play("tick", 0.8, 1.2)
		Game.spawn_enemy("u", spot)
		await _wait(0.3)


## Open floor about three metres from it, `side` first.
func _open_spot(side: Vector3) -> Vector3:
	var room := Room.current
	var base := atan2(side.z, side.x)
	for k in 12:
		var a := base + int((k + 1) / 2.0) * (TAU / 12.0) * (1.0 if k % 2 == 0 else -1.0)
		var p := global_position + Vector3(cos(a), 0.0, sin(a)) * 3.0
		p.y = 0.0
		if room == null or room.is_walkable(p, 1.0):
			return p
	var q := global_position + side * 3.0
	q.x = clampf(q.x, -Room.HALF_W + 1.0, Room.HALF_W - 1.0)
	q.z = clampf(q.z, -Room.HALF_L + 1.0, Room.HALF_L - 1.0)
	q.y = 0.0
	return q


# Iron Casting -----------------------------------------------------------------------------------

const CAST_WARN := 1.3
const CAST_WIDTH := 0.9
const CAST_DAMAGE := 16.0
const CAST_GAP := 2.4         # each wall's way through
const CAST_STAND := 8.0       # seconds the walls stand
var _casts: Array = []        # [{node, obstacles}]

## Molten iron runs down channels across the room, then cools into walls with a gap each.
func _iron_casting() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_slam()
	Sfx.play(roar_sound, 0.5, 1.1)
	var n := 3 if _enraged else 2
	# One channel through the hero, the others 3.5 m either side, kept off the boss.
	var zs: Array[float] = []
	var hz := clampf(hero.global_position.z, -Room.HALF_L + 1.5, Room.HALF_L - 1.5)
	for cand in [hz, hz - 3.5, hz + 3.5, hz - 7.0, hz + 7.0]:
		if zs.size() >= n:
			break
		if absf(cand) > Room.HALF_L - 1.2 or absf(cand - global_position.z) < radius + 1.0:
			continue
		zs.append(cand)
	var source := kind_name()
	for z in zs:
		var gap := randf_range(-Room.HALF_W + 1.6, Room.HALF_W - 1.6)
		if absf(z - hz) < 0.1 and absf(gap - hero.global_position.x) < 1.6:
			gap = clampf(gap + 3.0 * (1.0 if gap < 0.0 else -1.0), -Room.HALF_W + 1.6, Room.HALF_W - 1.6)
		for side in [-1.0, 1.0]:
			# Each half of the channel, from the gap out to the wall.
			var a: float = gap + side * CAST_GAP * 0.5
			var b: float = side * Room.HALF_W
			var length := absf(b - a)
			if length < 0.6:
				continue
			var from := Vector3(a, 0.0, z)
			var dir := Vector3(float(side), 0.0, 0.0)
			track(Telegraph.line(from, dir, length, CAST_WIDTH, CAST_WARN, _pour_iron.bind(from, dir, length, source), 0.6))
	Sfx.play("belt", 0.6, 0.6)
	await _wait(CAST_WARN + 0.5)


## The iron runs: it burns along the channel, then cools into a wall.
func _pour_iron(from: Vector3, dir: Vector3, length: float, source: String) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	Sfx.play("press", 0.6, 0.7)
	for i in int(length / 0.7) + 1:
		Fx._burst(from + dir * (i * 0.7) + Vector3.UP * 0.2, 4, Color(1.0, 0.55, 0.15, 0.9), 0.2, 2.4, 0.4, 5.0)
	var h := Game.hero
	if h and h.can_be_hit() and Enemy.in_strip(h.global_position, from, dir, length, CAST_WIDTH, h.radius * 0.6):
		_hit(CAST_DAMAGE, Vector3(0, 0, 1.0 if h.global_position.z > from.z else -1.0), 7.0, source)
	var wall := Node3D.new()
	_room().add_child(wall)
	wall.global_position = from + dir * length * 0.5
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 1.1, 0.55)
	box.mesh = bm
	box.material_override = _mat("ingot")
	box.position.y = 0.55
	wall.add_child(box)
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(length, 0.12, 0.7)
	cap.mesh = cm
	cap.material_override = _mat("iron")
	cap.position.y = 1.12
	wall.add_child(cap)
	wall.scale = Vector3(1.0, 0.05, 1.0)
	var tw := wall.create_tween()
	tw.tween_property(wall, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# It cools from orange-hot to iron.
	var cool := StandardMaterial3D.new()
	cool.albedo_color = Color(1.0, 0.52, 0.14)
	cool.emission_enabled = true
	cool.emission = Color(1.0, 0.45, 0.1)
	cool.emission_energy_multiplier = 2.2
	cool.roughness = 0.5
	box.material_override = cool
	tw.tween_property(cool, "albedo_color", Color(0.34, 0.3, 0.28), 2.0)
	tw.parallel().tween_property(cool, "emission_energy_multiplier", 0.45, 2.0)
	# Solid: a row of circles along it, as the room's cover.
	var obs: Array = []
	if is_instance_valid(Room.current):
		var k := int(ceil(length / 0.55))
		for i in k + 1:
			var o := {"pos": from + dir * minf(i * 0.55, length), "r": 0.32}
			Room.current.obstacles.append(o)
			obs.append(o)
	# Whoever is standing where it rises is shoved out of it.
	for a: Actor in Actor.all:
		if a.dead or (a is Enemy and (a as Enemy).is_boss):
			continue
		var d := a.global_position - from
		var along := d.dot(dir)
		if along > -0.3 and along < length + 0.3 and absf(d.z) < 0.6 + a.radius:
			a.global_position.z = from.z + (0.7 + a.radius) * (1.0 if d.z >= 0.0 else -1.0)
	var entry := {"node": wall, "obstacles": obs}
	_casts.append(entry)
	get_tree().create_timer(CAST_STAND, false).timeout.connect(_sink_cast.bind(entry))


func _sink_cast(entry: Dictionary) -> void:
	if is_instance_valid(Room.current):
		for o in entry.obstacles:
			Room.current.obstacles.erase(o)
	entry.obstacles = []
	var w: Node3D = entry.node
	if is_instance_valid(w):
		var tw := w.create_tween()
		tw.tween_property(w, "scale", Vector3(1.0, 0.02, 1.0), 0.5)
		tw.tween_callback(w.queue_free)
	_casts.erase(entry)


func _clear_casts() -> void:
	for e in _casts.duplicate():
		_sink_cast(e)
	_casts.clear()


func _clear_all() -> void:
	_clear_casts()
	# Presses not yet down go with it (one already falling finishes on its own).
	for n in _hung:
		if is_instance_valid(n) and not (n as Node3D).visible:
			(n as Node).queue_free()
	_hung.clear()
	_clear_saws()
	_clear_belts()
	_clear_pendulums()


func _exit_tree() -> void:
	_clear_all()
	super._exit_tree()


func _on_death() -> void:
	_clear_all()
	if _furnace_light:
		_furnace_light.create_tween().tween_property(_furnace_light, "light_energy", 0.0, 0.8)
	Sfx.play(roar_sound, 0.8, 0.85)
	Sfx.play("press", 1.0, 0.7)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	if _clock:
		var tw := _clock.create_tween()
		tw.tween_property(_clock, "scale", _clock.scale * 1.3, 0.2)
		tw.tween_property(_clock, "scale", Vector3.ZERO, 0.4)
	Fx._burst(center(), 50, Color(1.0, 0.65, 0.3, 0.9), 0.35, 5.0, 0.9, 8.0)
	Fx._burst(center() + Vector3.UP * 1.0, 30, Color(0.7, 0.68, 0.66, 0.5), 0.9, 2.0, 1.5, -1.5)
	Fx.magic(center(), BRASS, 30)
	Fx.shockwave(global_position, EMBER, 5.5)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
