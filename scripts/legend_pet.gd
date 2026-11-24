class_name LegendPet
extends Node3D
## Version 312 (Legend Vault, legends.gd): a pet that goes everywhere with the hero. Built from
## simple shapes, at a size the run camera far above can read (the hero is 2.1 m tall):
##   wisp:  Lantern Wisp. A little ghost with big eyes and a lantern swinging from its hand;
##          the lantern throws a warm pool of light on the floor under it.
##   raven: Crypt Raven. A blue-black raven with a violet sheen, a big bone-white bird skull
##          for a head (glowing violet eyes, a hooked beak that opens to caw, a ragged crest)
##          and wings of real feathers tipped in glowing violet (version 319: it was a dark
##          lump of boxes). It circles over the hero while there are skeletons about, a violet
##          pool following it on the floor and feathers falling from it, now and then dives
##          at the nearest skeleton and pecks it with a violet flash (only a show), and lands
##          on their shoulder to rest when the room is clear (and on the title).
##   mimic: Mimic. A treasure chest with fangs and a tongue. It hops after the hero, chomps
##          now and then, and snaps at the nearest skeleton.
##   wyrm:  Bone Wyrm (version 314). A tiny skeleton dragon with a violet soul fire in its
##          ribs, curled on the hero's shoulder. It breathes a stream of violet fire at a boss
##          (and a little puff at a skeleton now and then). It rides on the hero, so it is a
##          plain child of the hero's visual even in a run.
## In a run it moves through the world on its own (top_level) and trails the hero. On a
## pedestal (a HeroStage, drawn in its own SubViewport) it stays at the hero's side and turns
## with them. It is never outlined, tinted or flashed with the hero (CharacterVisual only
## touches its own model), and it never touches the fight.

var kind := "wisp"

## Where it waits beside a hero who stands still: their right, a little towards the camera.
const SIDE := Vector3(1.3, 0.0, 0.3)
## On a pedestal (in the hero's own space: their front faces the camera there).
const STAGE_SIDE := Vector3(-0.85, 0.0, -0.35)

var _anchor: Node3D
var _staged := false
var _body: Node3D
var _t := 0.0
var _last := Vector3.ZERO
var _vel := Vector3.ZERO
var _still := 0.0
var _placed := false
var _yaw := PI
var _look := 0.0   # (a timer for small idle moves)
var _base_scale := Vector3.ONE
## How much bigger each pet is drawn in a run than on a pedestal.
const RUN_SIZE := {"wisp": 1.45, "raven": 1.25, "mimic": 1.3, "wyrm": 1.85}

# Lantern Wisp
var _lantern: Node3D
var _tail: Node3D
var _pool_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D

# Crypt Raven
var _wing_l: Node3D
var _wing_r: Node3D
var _head: Node3D
var _orbit := 0.0
var _land := 0.0
var _beak: Node3D
var _pool: MeshInstance3D
var _shed: CPUParticles3D
var _dive_t := -1.0
var _dive_wait := 3.0
var _dive_prey: Node3D

# Mimic
var _lid: Node3D
var _tongue: Node3D
var _hop_t := -1.0
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
var _hop_len := 0.0
var _chomp := 0.0
var _chomp_wait := 1.5
var _prey: Node3D
var _prey_scan := 0.0
var _squash := 0.0

# Bone Wyrm
## Where it sits, in the hero visual's own space: out on the shoulder, clear of the big hood
## (the shoulder away from the raven's).
const PERCH := Vector3(-0.6, 1.0, 0.0)
var _neck: Node3D
var _jaw: Node3D
var _tail_bones: Array[Node3D] = []
var _flame: CPUParticles3D
var _heart_mat: StandardMaterial3D
var _breath := 0.0   # (seconds of fire left)
var _breath_wait := 2.0
var _breath_at := Vector3.ZERO   # (where the fire goes, in the world)
var _breath_big := false


func _ready() -> void:
	_anchor = get_parent() as Node3D
	_staged = get_viewport() is SubViewport
	top_level = not _staged and kind != "wyrm"
	_body = Node3D.new()
	add_child(_body)
	match kind:
		"raven":
			_build_raven()
		"mimic":
			_build_mimic()
		"wyrm":
			_build_wyrm()
		_:
			_build_wisp()
	if not _staged:
		# In a run the camera is far above: the pet is drawn bigger there than on a pedestal.
		_body.scale = Vector3.ONE * float(RUN_SIZE.get(kind, 1.3))
	elif kind == "wyrm":
		_body.scale = Vector3.ONE * 1.4   # (small beside the hero's big head otherwise)
	_base_scale = _body.scale
	_place_now()


func _place_now() -> void:
	if kind == "wyrm":
		position = PERCH
		_yaw = 0.0
	elif _staged:
		position = STAGE_SIDE if kind != "mimic" else Vector3(-0.66, 0.0, -0.05)
		_yaw = 0.0
	elif _anchor:
		_last = _anchor.global_position
		global_position = _anchor.global_position + SIDE
		_yaw = PI
	_placed = true


func _process(delta: float) -> void:
	if _anchor == null or not is_instance_valid(_anchor) or delta <= 0.0:
		return
	_t += delta
	if not _staged:
		var a := _anchor.global_position
		var v := (a - _last) / delta
		_last = a
		v.y = 0.0
		if v.length() > 40.0:
			v = Vector3.ZERO   # (a jump to a new room, not a walk)
		_vel = _vel.lerp(v, 1.0 - exp(-8.0 * delta))
		_still = _still + delta if _vel.length() < 0.5 else 0.0
		if kind != "wyrm" and global_position.distance_to(a) > 9.0:
			_place_now()   # a new room: it is there with the hero at once
	match kind:
		"raven":
			_raven(delta)
		"mimic":
			_mimic(delta)
		"wyrm":
			_wyrm(delta)
		_:
			_wisp(delta)


## Where a pet on the ground waits: beside the hero when they stand, behind them when they run.
func _home() -> Vector3:
	var a := _anchor.global_position
	var speed := _vel.length()
	if speed < 0.6:
		return a + SIDE
	var dir := _vel / speed
	return a - dir * 1.2 + Vector3(-dir.z, 0.0, dir.x) * 0.5


func _turn_to(yaw: float, delta: float, k := 6.0) -> void:
	_yaw = lerp_angle(_yaw, yaw, 1.0 - exp(-k * delta))
	_body.rotation.y = _yaw


static func _yaw_of(d: Vector3) -> float:
	return atan2(-d.x, -d.z)   # (a body's front is its -Z)


# ---------------------------------------------------------------- Lantern Wisp

func _build_wisp() -> void:
	var ghost := _mat("wisp_ghost", Color(0.86, 0.95, 1.0, 0.86), 0.5, Color(0.55, 0.8, 1.0), 0.55, true)
	var dark := _mat("wisp_eye", Color(0.04, 0.05, 0.12), 0.3)
	var shine := _mat("wisp_shine", Color(1, 1, 1), 0.3, Color(1, 1, 1), 1.2)
	var iron := _mat("wisp_iron", Color(0.16, 0.13, 0.12), 0.5)
	var brass := _mat("wisp_brass", Color(0.85, 0.6, 0.25), 0.35, Color(0.85, 0.55, 0.2), 0.25)
	var flame := _mat("wisp_flame", Color(1.0, 0.72, 0.3), 0.4, Color(1.0, 0.65, 0.2), 4.0)
	# The head: a big round ghost head, a little taller than wide.
	var head := _sphere(_body, 0.3, ghost, Vector3.ZERO)
	head.scale = Vector3(1.0, 1.08, 0.96)
	# The tail: it narrows to a curl and trails behind when the wisp flies.
	_tail = Node3D.new()
	_tail.position = Vector3(0, -0.12, 0.02)
	_body.add_child(_tail)
	_tube(_tail, 0.27, 0.17, 0.3, ghost, Vector3(0, -0.15, 0.02))
	var tip := Node3D.new()
	tip.position = Vector3(0, -0.3, 0.05)
	tip.rotation.x = -0.55
	_tail.add_child(tip)
	_tube(tip, 0.17, 0.02, 0.32, ghost, Vector3(0, -0.15, 0))
	# Big dark eyes with a white glint, and a small round mouth.
	for side in [-1.0, 1.0]:
		var e := _sphere(_body, 0.075, dark, Vector3(0.11 * side, 0.05, -0.26))
		e.scale = Vector3(0.85, 1.35, 0.55)
		_sphere(_body, 0.024, shine, Vector3(0.11 * side + 0.025, 0.1, -0.3))
		# little arms
		var arm := _sphere(_body, 0.08, ghost, Vector3(0.29 * side, -0.12, -0.04))
		arm.scale = Vector3(0.8, 1.2, 0.8)
	var mouth := _sphere(_body, 0.04, dark, Vector3(0, -0.09, -0.27))
	mouth.scale = Vector3(1.0, 0.8, 0.5)
	# The lantern hangs from the right hand on a short handle and swings as the wisp floats.
	_lantern = Node3D.new()
	_lantern.position = Vector3(0.33, -0.16, -0.06)
	_body.add_child(_lantern)
	U.box(_lantern, Vector3(0.02, 0.14, 0.02), iron, Vector3(0, -0.07, 0))
	var cap := _tube(_lantern, 0.02, 0.11, 0.08, iron, Vector3(0, -0.18, 0))
	cap.name = "Cap"
	_sphere(_lantern, 0.035, brass, Vector3(0, -0.13, 0))
	_sphere(_lantern, 0.11, flame, Vector3(0, -0.3, 0))
	for i in 4:
		var ang := TAU * i / 4.0 + PI / 4.0
		U.box(_lantern, Vector3(0.022, 0.2, 0.022), brass, Vector3(cos(ang) * 0.095, -0.3, sin(ang) * 0.095))
	_tube(_lantern, 0.11, 0.11, 0.035, iron, Vector3(0, -0.415, 0))
	# The lantern's glow: a soft halo around the flame, and a warm pool of light on the floor.
	_halo_mat = _add_mat(Color(1.0, 0.7, 0.3, 0.9), true)
	var halo := MeshInstance3D.new()
	halo.mesh = _quad(1.25)
	halo.material_override = _halo_mat
	halo.position = Vector3(0, -0.3, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern.add_child(halo)
	_pool_mat = _add_mat(Color(1.0, 0.62, 0.25, 0.6), false)
	var pool := U.floor_quad(self, Vector2(3.4, 3.4), _pool_mat, Vector3(0, 0.05, 0))
	pool.name = "Pool"
	# A cold ghost-light around the wisp itself.
	var aura := MeshInstance3D.new()
	aura.mesh = _quad(1.5)
	aura.material_override = _add_mat(Color(0.55, 0.8, 1.0, 0.4), true)
	aura.position = Vector3(0, -0.05, 0.05)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(aura)
	_body.position.y = 1.4 if not _staged else 1.25


func _wisp(delta: float) -> void:
	var bob := sin(_t * 2.1) * 0.09
	var speed := _vel.length()
	if _staged:
		_body.position.y = 1.25 + bob
		_turn_to(sin(_t * 0.6) * 0.25, delta, 3.0)
	else:
		var home := _home()
		position = position.lerp(home, 1.0 - exp(-3.2 * delta))
		_body.position.y = 1.4 + bob
		_turn_to(_yaw_of(_vel) if speed > 0.8 else PI, delta, 4.0)
	var blown := clampf(speed / 6.0, 0.0, 1.0)
	_tail.rotation.x = -0.45 * blown + sin(_t * 3.1) * 0.12
	_tail.rotation.z = sin(_t * 2.3) * 0.3
	_body.rotation.x = -0.18 * blown
	_lantern.rotation.z = sin(_t * 2.5) * 0.22
	_lantern.rotation.x = sin(_t * 1.7) * 0.12 - 0.35 * blown
	var flicker := 0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3)
	_halo_mat.albedo_color.a = 0.9 * flicker
	_pool_mat.albedo_color.a = 0.6 * flicker


# ---------------------------------------------------------------- Crypt Raven

func _build_raven() -> void:
	var bone := _mat("raven_bone", Color(0.95, 0.93, 0.87), 0.6)
	var black := _mat("raven_black", Color(0.05, 0.04, 0.07), 0.6)
	var violet := _mat("raven_eye", Color(0.85, 0.6, 1.0), 0.3, Color(0.75, 0.45, 1.0), 5.0)
	var plume := _raven_plume()
	# The body: blue-black feathers with a violet sheen at the edges (so a black bird still
	# reads on a dark floor), a rounder chest, and a ruff of ragged feathers at the neck.
	var body := _sphere(_body, 0.2, plume, Vector3(0, 0, 0.02))
	body.scale = Vector3(0.95, 0.88, 1.5)
	var chest := _sphere(_body, 0.16, plume, Vector3(0, -0.04, -0.17))
	chest.scale = Vector3(1.05, 1.0, 1.05)
	var ruff := MeshInstance3D.new()
	ruff.mesh = _raven_fan(7, 0.17, 0.045, -0.55, 0.55, Color(0.08, 0.07, 0.13), Color(0.35, 0.2, 0.6))
	ruff.material_override = _raven_feather_mat()
	ruff.position = Vector3(0, 0.07, -0.2)
	ruff.rotation.x = -0.35   # (the fan points back over the shoulders, a little up)
	_body.add_child(ruff)
	# The head: a big bird's skull, white bone (it is what the run camera sees best), deep
	# sockets with glowing violet eyes, a hooked black beak that opens to caw, and a crest of
	# three ragged feathers swept back.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.13, -0.3)
	_body.add_child(_head)
	var skull := _sphere(_head, 0.15, bone, Vector3.ZERO)
	skull.scale = Vector3(0.95, 0.92, 1.12)
	var brow := _sphere(_head, 0.1, bone, Vector3(0, 0.05, -0.08))
	brow.scale = Vector3(1.25, 0.6, 1.0)
	for side in [-1.0, 1.0]:
		var sock := _sphere(_head, 0.058, black, Vector3(0.085 * side, 0.015, -0.075))
		sock.scale = Vector3(0.9, 1.0, 0.7)
		_sphere(_head, 0.032, violet, Vector3(0.1 * side, 0.02, -0.095))
	var upper := _tube(_head, 0.06, 0.0, 0.27, black, Vector3.ZERO)
	upper.rotation.x = PI / 2.0 + 0.22   # (hooked: the tip turns down)
	upper.position = Vector3(0, -0.005, -0.26)
	upper.scale = Vector3(1.0, 1.0, 0.8)
	_beak = Node3D.new()
	_beak.position = Vector3(0, -0.04, -0.13)
	_head.add_child(_beak)
	var lower := _tube(_beak, 0.04, 0.0, 0.18, black, Vector3.ZERO)
	lower.rotation.x = PI / 2.0 - 0.1
	lower.position = Vector3(0, 0, -0.09)
	lower.scale = Vector3(1.0, 1.0, 0.6)
	var crest := MeshInstance3D.new()
	crest.mesh = _raven_fan(3, 0.2, 0.04, -0.3, 0.3, Color(0.08, 0.07, 0.13), Color(0.6, 0.35, 0.95))
	crest.material_override = _raven_feather_mat()
	crest.position = Vector3(0, 0.1, 0.05)
	crest.rotation.x = -0.6
	_head.add_child(crest)
	# Wings of real feathers: long black primaries tipped in glowing violet, a row of
	# secondaries behind the arm and coverts over them. Spread, the wings are 2 m across
	# (at the run's size), a big V the camera far above can read.
	_wing_l = _raven_wing(-1.0)
	_wing_r = _raven_wing(1.0)
	# A fan of five tail feathers, violet-tipped.
	var tail := MeshInstance3D.new()
	tail.mesh = _raven_fan(5, 0.34, 0.055, -0.45, 0.45, Color(0.07, 0.06, 0.12), Color(0.55, 0.3, 0.95))
	tail.material_override = _raven_feather_mat()
	tail.position = Vector3(0, 0.02, 0.22)
	tail.rotation.x = 0.15   # (the fan lies flat, pointing back and a little down)
	_body.add_child(tail)
	_tail = tail
	# Legs, for perching.
	for side in [-1.0, 1.0]:
		U.box(_body, Vector3(0.025, 0.14, 0.025), black, Vector3(0.06 * side, -0.2, -0.04))
	# A violet glow about it.
	var glow := MeshInstance3D.new()
	glow.mesh = _quad(1.5)
	glow.material_override = _add_mat(Color(0.55, 0.3, 1.0, 0.38), true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(glow)
	_body.position.y = 1.5
	# Under it on the floor, a soft violet pool that follows it about, so from far above the
	# eye finds where the bird is even over a dark floor.
	if not _staged:
		_pool_mat = _add_mat(Color(0.5, 0.28, 1.0, 0.0), false)
		_pool = U.floor_quad(self, Vector2.ONE * 1.6, _pool_mat)
		_pool.top_level = true
		_shed = CPUParticles3D.new()
		_shed.amount = 10
		_shed.lifetime = 1.0
		_shed.local_coords = false
		_shed.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_shed.emission_sphere_radius = 0.3
		_shed.direction = Vector3.DOWN
		_shed.spread = 60.0
		_shed.gravity = Vector3(0, -1.2, 0)
		_shed.initial_velocity_min = 0.2
		_shed.initial_velocity_max = 0.6
		_shed.angular_velocity_min = -200.0
		_shed.angular_velocity_max = 200.0
		_shed.angle_max = 360.0
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 0.2)
		_shed.mesh = q
		var sm := _add_mat(Color(0.65, 0.4, 1.0, 0.9), true)
		sm.vertex_color_use_as_albedo = true
		_shed.material_override = sm
		var g := Gradient.new()
		g.set_color(0, Color(0.8, 0.6, 1.0, 1.0))
		g.set_color(1, Color(0.4, 0.2, 0.9, 0.0))
		_shed.color_ramp = g
		_body.add_child(_shed)


static var _plume_mat: ShaderMaterial
static var _feather_mat: ShaderMaterial


## Blue-black plumage with a violet-to-teal sheen round its edges (like a real raven's).
static func _raven_plume() -> ShaderMaterial:
	if _plume_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 sheen = mix(vec3(0.45, 0.25, 0.95), vec3(0.2, 0.7, 0.85), clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0));
	ALBEDO = vec3(0.06, 0.055, 0.1) + sheen * fres * 0.35;
	ROUGHNESS = 0.4;
	EMISSION = sheen * fres * 0.55;
}
"""
		_plume_mat = ShaderMaterial.new()
		_plume_mat.shader = sh
	return _plume_mat


## The feathers (wings, tail, crest, ruff): their colour from the mesh (black at the root,
## violet at the tip), the tips glowing, a sheen at the edges.
static func _raven_feather_mat() -> ShaderMaterial:
	if _feather_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float tip = smoothstep(0.62, 1.0, UV.y);
	float edge = smoothstep(0.55, 1.0, abs(UV.x)) * 0.35;
	ALBEDO = COLOR.rgb + vec3(0.25, 0.15, 0.45) * edge;
	ROUGHNESS = 0.45;
	EMISSION = vec3(0.62, 0.32, 1.0) * tip * 1.4 + vec3(0.35, 0.25, 0.8) * fres * 0.3;
}
"""
		_feather_mat = ShaderMaterial.new()
		_feather_mat.shader = sh
	return _feather_mat


static var _raven_meshes := {}


## A wing of feathers lying flat (x out to the `side`, z back, y up), from the shoulder at
## the origin: an arm to the wrist, long primaries fanning from the hand, secondaries behind
## the arm, coverts over them.
func _raven_wing(side: float) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.14 * side, 0.08, -0.06)
	_body.add_child(w)
	var key := int(side)
	if not _raven_meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var dark := Color(0.07, 0.065, 0.12)
		var mid := Color(0.22, 0.17, 0.36)   # (the coverts a little lighter: the camera above sees them)
		var tipc := Color(0.55, 0.3, 0.95)
		var wrist := Vector2(0.32, 0.02)
		# Primaries: from the hand, sweeping from out-and-forward to out-and-back.
		for i in 6:
			var f := float(i) / 5.0
			var root := wrist.lerp(Vector2(0.48, 0.05), f)
			_flat_feather(st, root, lerpf(-0.15, 0.75, f), lerpf(0.42, 0.3, f), 0.055, 0.08, 0.0, dark, tipc, side)
		# Secondaries: along the arm, pointing back.
		for i in 6:
			var f := float(i) / 5.0
			var root := Vector2(0.06, 0.0).lerp(wrist, f)
			_flat_feather(st, root, lerpf(1.45, 1.0, f), lerpf(0.25, 0.3, f), 0.055, 0.05, 0.0, dark, tipc.lerp(dark, 0.45), side)
		# Coverts over the roots, a little above.
		for i in 7:
			var f := float(i) / 6.0
			var root := Vector2(0.04, -0.01).lerp(Vector2(0.45, 0.04), f)
			_flat_feather(st, root, lerpf(1.3, 0.5, f), 0.15, 0.05, 0.03, 0.012, mid, mid.lerp(tipc, 0.3), side)
		_raven_meshes[key] = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _raven_meshes[key]
	mi.material_override = _raven_feather_mat()
	w.add_child(mi)
	return w


## One feather lying flat (in the XZ plane, y `lift` above it), from `root` (x out, z back,
## made for the right side and mirrored for `side`) at the angle `ang` (0 points straight
## out, PI/2 straight back), tapering to a point that curls back by `curl`. UV.y 0 at the
## root to 1 at the tip, UV.x -1 to 1 across.
static func _flat_feather(st: SurfaceTool, root: Vector2, ang: float, length: float, half_w: float, curl: float, lift: float, c0: Color, c1: Color, side: float) -> void:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	var pt := 0.0
	for i in 8:
		var t := float(i) / 7.0
		var c := root + d * (t * length) + n * (curl * t * t)
		var hw := half_w * (0.45 * (1.0 - t) + 0.75 * sin(PI * pow(t, 0.6)))
		var l := Vector3((c.x - n.x * hw) * side, lift + 0.01 * t, c.y - n.y * hw)
		var r := Vector3((c.x + n.x * hw) * side, lift + 0.01 * t, c.y + n.y * hw)
		if i > 0:
			var a0 := c0.lerp(c1, pt * pt)
			var a1 := c0.lerp(c1, t * t)
			for v in [[pl, -1.0, pt, a0], [pr, 1.0, pt, a0], [r, 1.0, t, a1], [pl, -1.0, pt, a0], [r, 1.0, t, a1], [l, -1.0, t, a1]]:
				st.set_color(v[3])
				st.set_uv(Vector2(v[1], v[2]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
		pl = l
		pr = r
		pt = t


## A fan of `count` feathers from one point, spread from `a0` to `a1` (radians), lying flat
## (in the XZ plane) and pointing back along +Z (the caller turns it into place).
static func _raven_fan(count: int, length: float, half_w: float, a0: float, a1: float, c0: Color, c1: Color) -> Mesh:
	var key := "fan%d/%.2f/%.2f" % [count, length, a1]
	if _raven_meshes.has(key):
		return _raven_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var f := 0.5 if count == 1 else float(i) / (count - 1)
		var a := lerpf(a0, a1, f)
		# (_flat_feather lays feathers in XZ; a fan for the tail is turned by its holder)
		_flat_feather(st, Vector2.ZERO, PI / 2.0 + a, length * (1.0 - 0.12 * absf(f - 0.5) * 2.0), half_w, 0.0, 0.004 * i, c0, c1, 1.0)
	var m := st.commit()
	_raven_meshes[key] = m
	return m


func _raven(delta: float) -> void:
	var a := Vector3.ZERO if _staged else _anchor.global_position
	var hb := Basis.IDENTITY if _staged else _anchor.global_basis.orthonormalized()
	var shoulder := a + hb * Vector3(0.5, 1.38, 0.02)
	# It caws now and then: the beak snaps open and the head jerks up.
	var cw := fmod(_t + 1.3, 3.4)
	var caw := smoothstep(0.0, 0.06, cw) * (1.0 - smoothstep(0.25, 0.4, cw))
	_beak.rotation.x = 0.55 * caw
	_tail.rotation.z = sin(_t * 2.6) * 0.12
	if _staged:
		# On a pedestal it hovers beside the hero, turned to fly towards them and the camera,
		# so its wings beat up and down beside the hero (face on, they crossed the hero's face).
		position = Vector3(-0.8, 0, -0.45)   # (version 319: further in, it was cut off by the frame)
		_body.position = Vector3(0, 1.5 + sin(_t * 1.6) * 0.08, 0)
		_body.scale = Vector3.ONE * 0.95
		# (side on to the camera, its wings beating high in a V over its back, so their
		# feathers face the camera: flat out, or seen from the front, they are lines)
		_turn_to(-PI / 2.0 + 0.45 + sin(_t * 0.7) * 0.12, delta, 3.0)
		_body.rotation.x = 0.12
		_body.rotation.z = sin(_t * 0.9) * 0.1
		var hover := 0.65 + sin(_t * 6.0) * 0.55
		_wing_l.rotation = Vector3(0, 0.25, -hover)
		_wing_r.rotation = Vector3(0, -0.25, hover)
		_head.rotation.x = -0.25 * caw
		return
	elif _still > 1.0 and Game.alive_enemies <= 0:
		_land = move_toward(_land, 1.0, delta * 1.3)   # (in a fight the hero stands still to shoot)
	else:
		_land = move_toward(_land, 0.0, delta * 2.4)
	var k := smoothstep(0.0, 1.0, _land)
	# Flying: wide circles over the hero, rising and falling a little.
	_orbit += delta * 1.9
	var r := 1.5
	var fly := a + Vector3(cos(_orbit) * r, 2.5 + sin(_orbit * 2.0) * 0.18, sin(_orbit) * r)
	var tangent := Vector3(-sin(_orbit), 0, cos(_orbit))
	# On the way down it swoops in an arc rather than sliding.
	var p := fly.lerp(shoulder, k) + Vector3.UP * sin(k * PI) * 0.45
	# In a fight it dives at the nearest skeleton now and then, pecks it with a violet flash
	# and climbs back to its circle (only a show: it never hurts anything).
	if k < 0.05:
		if _dive_t < 0.0:
			_dive_wait -= delta
			if _dive_wait <= 0.0:
				_dive_wait = randf_range(3.5, 5.5)
				_dive_prey = _nearest_enemy(8.0)
				if _dive_prey:
					_dive_t = 0.0
		else:
			_dive_t += delta
	var dive := 0.0
	if _dive_t >= 0.0:
		if _dive_prey == null or not is_instance_valid(_dive_prey) or _dive_t > 1.0:
			_dive_t = -1.0
		else:
			dive = smoothstep(0.0, 1.0, sin(_dive_t * PI))
			var prey_at := _dive_prey.global_position + Vector3(0, 1.1, 0)
			p = p.lerp(prey_at, dive)
			if _dive_t - delta < 0.5 and _dive_t >= 0.5:
				Fx._burst(prey_at, 8, Color(0.75, 0.5, 1.0), 0.4, 2.6, 0.35, 0.0, true, "glint")
				caw = 1.0
				_beak.rotation.x = 0.55
			if _dive_t < 0.5:
				tangent = (prey_at - (a + _body.position)).normalized()
	position = a
	_body.position = p - a
	var face := _yaw_of(tangent) if k < 0.5 else hb.get_euler().y
	_turn_to(face, delta, (9.0 if dive > 0.0 else 5.0) if k < 0.5 else 8.0)
	_body.rotation.z = lerpf(0.38, 0.0, k) * (1.0 - dive)   # leaning into the turn
	_body.rotation.x = -0.6 * dive if _dive_t < 0.5 else 0.3 * dive   # (nose down into the dive)
	# Wings: flapping, with a glide now and then; tucked in a dive; folded along the back when
	# perched.
	var glide := smoothstep(0.3, 0.7, sin(_t * 0.9))
	var flap := sin(_t * 11.0) * lerpf(0.75, 0.12, glide) + 0.1 * glide
	var fold := maxf(k, dive * 0.55)
	if k > 0.95:
		_look += delta
		# Perched: now and then it stretches its wings, and it looks about.
		var stretch := smoothstep(0.0, 0.3, fmod(_look, 6.0) - 4.6) * (1.0 - smoothstep(0.0, 0.3, fmod(_look, 6.0) - 5.4))
		fold = 1.0 - stretch * 0.8
		flap = stretch * (0.4 + sin(_t * 9.0) * 0.25)
		_head.rotation.y = sin(_t * 1.1) * 0.55
		_head.rotation.x = sin(_t * 2.3) * 0.12 - 0.25 * caw
	else:
		_head.rotation = Vector3(-0.25 * caw, 0, 0)
	_wing_l.rotation = Vector3(0, 1.35 * fold, -flap * (1.0 - fold) - 0.3 * fold)
	_wing_r.rotation = Vector3(0, -1.35 * fold, flap * (1.0 - fold) + 0.3 * fold)
	for w: Node3D in [_wing_l, _wing_r]:
		w.scale.x = lerpf(1.0, 0.55, fold)   # (folded, the long feathers lie over each other)
	# The violet pool on the floor under it, and feathers shed as it flies.
	var bird := a + _body.position
	_pool.global_position = Vector3(bird.x, 0.06, bird.z)
	_pool_mat.albedo_color.a = lerpf(0.5, 0.2, k) + 0.25 * dive
	_shed.emitting = k < 0.5


# ---------------------------------------------------------------- Mimic

func _build_mimic() -> void:
	var wood := _mat("mimic_wood", Color(0.45, 0.26, 0.12), 0.85)
	var dark_wood := _mat("mimic_wood2", Color(0.3, 0.17, 0.08), 0.85)
	var gold := _mat("mimic_gold", Color(1.0, 0.76, 0.28), 0.35, Color(1.0, 0.7, 0.2), 0.3)
	var mouth := _mat("mimic_mouth", Color(0.32, 0.03, 0.06), 0.7, Color(0.4, 0.02, 0.06), 0.4)
	var tooth := _mat("mimic_tooth", Color(0.97, 0.95, 0.86), 0.4)
	var tongue := _mat("mimic_tongue", Color(0.92, 0.32, 0.42), 0.5)
	var eye := _mat("mimic_eye", Color(1.0, 0.85, 0.2), 0.3, Color(1.0, 0.8, 0.1), 4.0)
	var w := 0.72
	var d := 0.5
	var h := 0.34
	# The chest: wooden planks, gold bands and corners.
	U.box(_body, Vector3(w, h, d), wood, Vector3(0, h * 0.5, 0))
	for z in [-0.12, 0.12]:
		U.box(_body, Vector3(w + 0.02, h + 0.01, 0.05), gold, Vector3(0, h * 0.5, z))
	for x in [-1.0, 1.0]:
		U.box(_body, Vector3(0.05, h + 0.02, d + 0.02), dark_wood, Vector3(x * (w * 0.5 - 0.02), h * 0.5, 0))
	# The open mouth: dark red inside, a row of fangs along the front, and two eyes glowing at
	# the back of the dark.
	U.box(_body, Vector3(w - 0.08, 0.02, d - 0.08), mouth, Vector3(0, h + 0.005, 0))
	for i in 5:
		var x := -0.24 + i * 0.12
		var t := _tube(_body, 0.0, 0.035, 0.1, tooth, Vector3(x, h + 0.05, -d * 0.5 + 0.05))
		t.name = "Fang"
	for x in [-0.11, 0.11]:
		_sphere(_body, 0.05, eye, Vector3(x, h + 0.04, d * 0.5 - 0.12))
	_tongue = Node3D.new()
	_tongue.position = Vector3(0, h + 0.02, -0.02)
	_body.add_child(_tongue)
	var tg := _sphere(_tongue, 0.1, tongue, Vector3(0, 0, -0.22))
	tg.scale = Vector3(1.0, 0.35, 2.4)
	# The lid, hinged along the back: a rounded top, gold bands, a lock, and fangs hanging down.
	_lid = Node3D.new()
	_lid.position = Vector3(0, h, d * 0.5)
	_body.add_child(_lid)
	U.box(_lid, Vector3(w, 0.1, d), wood, Vector3(0, 0.05, -d * 0.5))
	var top := _tube(_lid, d * 0.5, d * 0.5, w, wood, Vector3.ZERO)
	top.rotation.z = PI / 2.0
	top.position = Vector3(0, 0.1, -d * 0.5)
	top.scale = Vector3(0.5, 1.0, 1.0)
	for z in [-0.12, 0.12]:
		var band := _tube(_lid, d * 0.5 + 0.012, d * 0.5 + 0.012, 0.05, gold, Vector3.ZERO)
		band.rotation.z = PI / 2.0
		band.position = Vector3(0, 0.1, -d * 0.5 + z)
		band.scale = Vector3(0.52, 1.0, 1.0)
	U.box(_lid, Vector3(0.12, 0.13, 0.04), gold, Vector3(0, 0.02, -d - 0.01))
	U.box(_lid, Vector3(w - 0.08, 0.02, d - 0.08), mouth, Vector3(0, -0.005, -d * 0.5))
	for i in 4:
		var x := -0.18 + i * 0.12
		var t := _tube(_lid, 0.035, 0.0, 0.1, tooth, Vector3(x, -0.1, -d + 0.05))
		t.name = "Fang"
	_body.position.y = 0.0


func _mimic(delta: float) -> void:
	# The skeleton nearest it, looked for a few times a second.
	_prey_scan -= delta
	if _prey_scan <= 0.0:
		_prey_scan = 0.25
		_prey = null if _staged else _nearest_enemy(4.5)
	var hunting := _prey != null and is_instance_valid(_prey)
	if not _staged:
		var home := _home()
		if _hop_t < 0.0:
			var gap := Vector3(home.x - position.x, 0, home.z - position.z)
			if gap.length() > 0.45:
				_hop_len = clampf(gap.length() * 0.7, 0.5, 2.6)
				_hop_from = position
				_hop_to = position + gap.limit_length(_hop_len)
				_hop_t = 0.0
		if _hop_t >= 0.0:
			_hop_t += delta / 0.36
			var s := minf(_hop_t, 1.0)
			position = _hop_from.lerp(_hop_to, s)
			_body.position.y = 4.0 * (0.25 + 0.1 * _hop_len) * s * (1.0 - s)
			_turn_to(_yaw_of(_hop_to - _hop_from), delta, 14.0)
			if _hop_t >= 1.0:
				_hop_t = -1.0
				_squash = 1.0
		elif hunting:
			_turn_to(_yaw_of(_prey.global_position - global_position), delta, 8.0)
		else:
			_turn_to(PI, delta, 3.0)
	else:
		_turn_to(sin(_t * 0.5) * 0.3, delta, 3.0)
	# The lid: a little open while it hops, a chomp now and then, fast snaps at a skeleton.
	_chomp_wait -= delta
	if _chomp_wait <= 0.0 and _chomp <= 0.0:
		_chomp = 1.0
		_chomp_wait = 0.45 if hunting else randf_range(1.6, 3.2)
	var open := 0.0
	if _chomp > 0.0:
		_chomp = maxf(0.0, _chomp - delta / (0.32 if hunting else 0.6))
		var c := 1.0 - _chomp
		open = (1.05 if hunting else 0.9) * (smoothstep(0.0, 0.55, c) if c < 0.7 else 1.0 - smoothstep(0.7, 0.85, c))
	if _hop_t >= 0.0:
		open = maxf(open, 0.35 * sin(_hop_t * PI))
	_lid.rotation.x = maxf(open, 0.14) * (1.0 + 0.04 * sin(_t * 20.0))   # (a little ajar: fangs and eyes peek out)
	_tongue.rotation.x = -0.3 + sin(_t * 5.0) * 0.1 + open * 0.25
	_tongue.rotation.y = sin(_t * 3.3) * 0.2
	_squash = maxf(0.0, _squash - delta * 4.0)
	_body.scale = _base_scale * Vector3(1.0 + 0.12 * _squash, 1.0 - 0.18 * _squash, 1.0 + 0.12 * _squash)


func _nearest_enemy(reach: float) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for e in Actor.all:   # (version 314: there is no "enemies" group, so the Mimic never found one)
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var dd := global_position.distance_to(en.global_position)
		if dd < best_d:
			best_d = dd
			best = en
	return best


# ---------------------------------------------------------------- Bone Wyrm

func _build_wyrm() -> void:
	var bone := _mat("wyrm_bone", Color(0.93, 0.9, 0.82), 0.7)
	var old := _mat("wyrm_bone2", Color(0.72, 0.68, 0.6), 0.8)
	var black := _mat("wyrm_black", Color(0.05, 0.03, 0.07), 0.6)
	var violet := _mat("wyrm_eye", Color(0.8, 0.5, 1.0), 0.3, Color(0.72, 0.4, 1.0), 4.5)
	_heart_mat = _mat("wyrm_heart%d" % get_instance_id(), Color(0.7, 0.4, 1.0), 0.3, Color(0.65, 0.3, 1.0), 3.0)
	var skin := StandardMaterial3D.new()   # (the wings' torn violet skin, lit from behind)
	skin.albedo_color = Color(0.42, 0.18, 0.62, 0.78)
	skin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.emission_enabled = true
	skin.emission = Color(0.5, 0.2, 0.85)
	skin.emission_energy_multiplier = 0.7
	skin.roughness = 0.8
	# The rib cage: a spine of knuckled bones over curved ribs, a violet soul fire inside.
	for i in 5:
		var z := -0.1 + i * 0.07
		_sphere(_body, 0.034 - i * 0.002, bone, Vector3(0, 0.22 - i * 0.008, z))
		if i < 4:
			for side in [-1.0, 1.0]:
				var rib := U.box(_body, Vector3(0.022, 0.15 - i * 0.015, 0.024), bone, Vector3(0.055 * side, 0.15, z + 0.02))
				rib.rotation = Vector3(0, 0, 0.42 * side)
				var low := U.box(_body, Vector3(0.02, 0.07, 0.022), old, Vector3(0.07 * side, 0.07, z + 0.02))
				low.rotation = Vector3(0, 0, -0.35 * side)
	var heart := _sphere(_body, 0.055, _heart_mat, Vector3(0, 0.13, 0.02))
	heart.scale = Vector3(1.0, 1.2, 1.3)
	# Four short legs with claws, gripping the shoulder.
	for side in [-1.0, 1.0]:
		for z in [-0.09, 0.14]:
			var leg := U.box(_body, Vector3(0.025, 0.11, 0.025), bone, Vector3(0.07 * side, 0.04, z))
			leg.rotation.z = -0.3 * side
			for c in 3:
				var claw := U.box(_body, Vector3(0.012, 0.012, 0.05), black, Vector3(0.09 * side + (c - 1) * 0.018, -0.01, z - 0.03))
				claw.rotation.x = 0.4
	# The neck: three bones curving up and forward to the head; it bends to aim the fire.
	_neck = Node3D.new()
	_neck.position = Vector3(0, 0.24, -0.13)
	_neck.rotation.x = 0.55
	_body.add_child(_neck)
	for i in 3:
		_sphere(_neck, 0.03 - i * 0.002, bone, Vector3(0, 0.0, -0.06 * i))
	# The head: a long dragon skull with swept-back horns, dark sockets and violet eyes.
	var head := Node3D.new()
	head.position = Vector3(0, 0.0, -0.19)
	head.rotation.x = -0.6
	_neck.add_child(head)
	_head = head
	var skull := _sphere(head, 0.072, bone, Vector3(0, 0.02, 0))
	skull.scale = Vector3(1.0, 0.85, 1.15)
	var snout := U.box(head, Vector3(0.075, 0.045, 0.13), bone, Vector3(0, 0.0, -0.11))
	snout.rotation.x = 0.08
	for side in [-1.0, 1.0]:
		_sphere(head, 0.03, black, Vector3(0.042 * side, 0.04, -0.04))
		_sphere(head, 0.017, violet, Vector3(0.05 * side, 0.045, -0.05))
		_sphere(head, 0.009, black, Vector3(0.02 * side, 0.016, -0.175))   # (nostrils)
		# Horns: two curving back from the brow, a small pair below them.
		var horn := Node3D.new()
		horn.position = Vector3(0.04 * side, 0.06, 0.03)
		horn.rotation = Vector3(1.2, 0, -0.35 * side)
		head.add_child(horn)
		_tube(horn, 0.0, 0.022, 0.14, old, Vector3(0, 0.07, 0))
		var tip := Node3D.new()
		tip.position = Vector3(0, 0.13, 0)
		tip.rotation.x = 0.5
		horn.add_child(tip)
		_tube(tip, 0.0, 0.01, 0.07, old, Vector3(0, 0.03, 0))
		var small := _tube(head, 0.0, 0.012, 0.07, old, Vector3(0.06 * side, 0.0, 0.05))
		small.rotation = Vector3(1.3, 0, -0.6 * side)
	# The jaw hinges at the back of the skull and drops open to breathe.
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.03, 0.02)
	head.add_child(_jaw)
	U.box(_jaw, Vector3(0.065, 0.022, 0.15), old, Vector3(0, -0.012, -0.1))
	for i in 3:
		for side in [-1.0, 1.0]:
			U.box(_jaw, Vector3(0.01, 0.022, 0.01), bone, Vector3(0.026 * side, 0.01, -0.06 - i * 0.04))
	# The wings: a bone arm with three long fingers and torn violet skin between them.
	_wing_l = _wyrm_wing(-1.0, bone, skin)
	_wing_r = _wyrm_wing(1.0, bone, skin)
	# The tail: six bones growing smaller, hanging down the hero's back, a violet barb at its end.
	var parent: Node3D = _body
	var at := Vector3(0, 0.19, 0.22)
	for i in 6:
		var seg := Node3D.new()
		seg.position = at
		parent.add_child(seg)
		_sphere(seg, 0.03 - i * 0.004, bone if i % 2 == 0 else old, Vector3.ZERO)
		_tail_bones.append(seg)
		parent = seg
		at = Vector3(0, -0.012, 0.065 - i * 0.003)
	var barb := U.box(parent, Vector3(0.07, 0.012, 0.07), violet, Vector3(0, 0, 0.05))
	barb.rotation.y = PI / 4.0
	# A faint violet light about it, so bone on a pale floor still stands out from above.
	var glow := MeshInstance3D.new()
	glow.mesh = _quad(1.1)
	glow.material_override = _add_mat(Color(0.6, 0.3, 1.0, 0.38 if _staged else 0.55), true)
	glow.position = Vector3(0, 0.18, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(glow)
	# Its fire: violet flame from the open jaws, left in the world as it flies.
	_flame = _wyrm_fire()
	_flame.position = Vector3(0, -0.01, -0.2)
	head.add_child(_flame)


func _wyrm_wing(side: float, bone: Material, skin: Material) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.05 * side, 0.25, -0.06)
	_body.add_child(w)
	var wrist := Vector2(0.17, 0.1)
	var tips: Array[Vector2] = [Vector2(0.34, 0.12), Vector2(0.33, -0.04), Vector2(0.24, -0.15)]
	LegendWings._bone(w, Vector2.ZERO, wrist, 0.016, bone, side)
	for tp in tips:
		LegendWings._bone(w, wrist, tp, 0.009, bone, side)
	var claw := U.box(w, Vector3(0.012, 0.04, 0.012), bone, LegendWings._v(wrist + Vector2(0.0, 0.03), side))
	claw.rotation.z = -0.4 * side
	var pts: Array[Vector2] = [Vector2.ZERO, wrist, tips[0], (tips[0] + tips[1]) * 0.5 + Vector2(-0.04, 0.0), tips[1],
		(tips[1] + tips[2]) * 0.5 + Vector2(-0.04, 0.02), tips[2], Vector2(0.06, -0.1)]
	var m := MeshInstance3D.new()
	m.mesh = LegendWings._fan(pts, side, "wyrm")
	m.material_override = skin
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(m)
	return w


func _wyrm_fire() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 72
	p.lifetime = 0.55
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.04
	p.direction = Vector3(0, 0, -1)
	p.spread = 11.0
	p.gravity = Vector3(0, 1.4, 0)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 5.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.85
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.45, 1.0))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	p.mesh = q
	var m := _add_mat(Color(1, 1, 1, 1), true)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.92, 1.0, 1.0), Color(0.82, 0.45, 1.0, 1.0), Color(0.42, 0.1, 0.8, 0.0)])
	p.color_ramp = g
	return p


func _wyrm(delta: float) -> void:
	# Looking for something to burn: a boss in reach, else now and then the nearest skeleton.
	_breath_wait -= delta
	if _breath <= 0.0 and _breath_wait <= 0.0:
		var target: Node3D = null
		_breath_big = false
		if not _staged:
			for b in Game._bosses:
				if is_instance_valid(b) and not (b as Actor).dead and global_position.distance_to((b as Node3D).global_position) < 12.0:
					target = b
					_breath_big = true
					break
			if target == null:
				target = _nearest_enemy(7.0)
		if target != null:
			_breath_at = target.global_position + Vector3(0, 1.0, 0)
			_breath = 1.1 if _breath_big else 0.45
			_breath_wait = 2.6 if _breath_big else randf_range(4.0, 7.0)
			# (at a boss a long roaring stream; at a skeleton a short puff)
			_flame.initial_velocity_min = 7.5 if _breath_big else 4.0
			_flame.initial_velocity_max = 9.5 if _breath_big else 5.0
		elif _staged:
			# On a pedestal: a breath out to the side, towards the camera, every few seconds.
			_breath_at = Vector3.ZERO
			_breath = 0.9
			_breath_wait = 3.2
			_flame.initial_velocity_min = 3.0
			_flame.initial_velocity_max = 4.2
		else:
			_breath_wait = 0.5
	var fire := _breath > 0.0
	_breath = maxf(0.0, _breath - delta)
	# It turns round on the shoulder to face what it burns, and the neck tips its head up or
	# down along the fire; at rest it looks about.
	var body_yaw := 0.55 if _staged else 0.0   # (on a pedestal turned a little to the side)
	var want := Vector3(sin(_t * 0.9) * 0.12, sin(_t * 0.55) * 0.5, 0.0)   # (x up and down, y left and right)
	if fire:
		if _staged:
			want = Vector3(0.05, 0.45, 0.0)   # (out past the hero's shoulder, towards the camera)
		else:
			var d := global_basis.orthonormalized().inverse() * (_breath_at - _neck.global_position)
			body_yaw = atan2(-d.x, -d.z)
			want = Vector3(clampf(atan2(d.y, Vector2(d.x, d.z).length()) + 0.05, -0.7, 0.5), 0.0, 0.0)
	_body.rotation.y = lerp_angle(_body.rotation.y, body_yaw, 1.0 - exp(-(12.0 if fire else 2.5) * delta))
	# The fire starts once it faces its target (the hero may be facing any way when it begins).
	_flame.emitting = fire and absf(angle_difference(_body.rotation.y, body_yaw)) < 0.35
	var k := 1.0 - exp(-(10.0 if fire else 3.0) * delta)
	var turn := Vector3(_neck.rotation.x - 0.55, _neck.rotation.y, 0.0).lerp(want, k)
	_neck.rotation = Vector3(0.55 + turn.x, turn.y, 0.0)
	_jaw.rotation.x = lerpf(_jaw.rotation.x, 0.55 if fire else 0.06 + 0.04 * sin(_t * 2.0), 1.0 - exp(-14.0 * delta))
	# The wings: half spread and slowly beating, wide open while it breathes (in a run held
	# open a little more, so the camera far above sees them past the hero's head).
	var open := 1.0 if fire else (0.0 if _staged else 0.45)
	var beat := sin(_t * (9.0 if fire else 2.2)) * (0.35 if fire else 0.15)
	for side in [-1.0, 1.0]:
		var w: Node3D = _wing_l if side < 0.0 else _wing_r
		w.rotation = Vector3(lerpf(-0.2, -0.05, open), side * lerpf(0.9, 0.25, open), side * (lerpf(0.35, 0.15, open) + beat))
	# The tail sways, each bone a little behind the one before.
	for i in _tail_bones.size():
		var tb := _tail_bones[i]
		tb.rotation = Vector3(0.32 + 0.04 * i, sin(_t * 1.7 - i * 0.6) * 0.22, 0.0)
	# The soul fire in its ribs pulses, and blazes as it breathes.
	_heart_mat.emission_energy_multiplier = (6.0 if fire else 2.5) + sin(_t * 4.0) * 0.8
	_body.position.y = sin(_t * 1.4) * 0.008

# ---------------------------------------------------------------- shapes and materials

static var _mats := {}


## A lit material, kept for every pet of its kind (nothing changes it afterwards).
static func _mat(key: String, col: Color, rough: float, glow := Color.BLACK, energy := 0.0, see_through := false) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = glow
		m.emission_energy_multiplier = energy
	if see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.rim_enabled = true
		m.rim = 0.7
		m.rim_tint = 0.2
	_mats[key] = m
	return m


## A soft glowing spot added over what is behind it: this pet's own (its brightness flickers).
static func _add_mat(col: Color, billboard: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = col
	m.albedo_texture = U.soft_circle()
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m


static func _quad(size: float) -> Mesh:
	return U._cached("petquad%.3f" % size, func():
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		return q)


static func _sphere(parent: Node3D, r: float, m: Material, pos: Vector3) -> MeshInstance3D:
	return U.sphere(parent, r, m, pos)


## A tube centred at `pos`: `top` radius above, `bottom` below (0 makes a point).
static func _tube(parent: Node3D, top: float, bottom: float, h: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := U._cached("pettube%.3f/%.3f/%.3f" % [top, bottom, h], func():
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = 14
		c.rings = 1
		return c)
	return U._place(parent, mesh, m, pos)


# ---------------------------------------------------------------- the Legend Vault's pictures

## A Legend Vault card's picture (hud.gd), drawn in 2D and gently moving: the pet itself for
## the looks that are built, a dark shape of its kind for the ones still to come.
class Icon extends Control:
	var kind := ""
	var slot := ""
	var locked := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var k := minf(size.x, size.y) / 116.0
		draw_set_transform(c, 0.0, Vector2(k, k))
		# A round gold-edged frame behind every picture.
		draw_circle(Vector2.ZERO, 54, Color(0.1, 0.07, 0.04) if not locked else Color(0.08, 0.07, 0.1))
		draw_arc(Vector2.ZERO, 54, 0, TAU, 48, Color(1.0, 0.8, 0.3, 0.9) if not locked else Color(0.35, 0.32, 0.4), 3.0, true)
		if locked:
			_shadow()
			return
		match kind:
			"wisp":
				_wisp()
			"raven":
				_raven()
			"mimic":
				_mimic()
			"bone_wings":
				_bone_wings()
			"phoenix":
				_phoenix()
			"ember_steps":
				_steps(false)
			"star_steps":
				_steps(true)
			"gold_rush":
				_gold_rush()
			"soul_harvest":
				_soul_harvest()
			"wyrm":
				_wyrm()
			"starfall":
				_starfall()
			"emperor":
				_emperor()

	func _glow(p: Vector2, r: float, col: Color) -> void:
		for i in 5:
			var f := 1.0 - i / 5.0
			draw_circle(p, r * (0.35 + 0.65 * f), Color(col, col.a * 0.25))

	func _ellipse(p: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)

	func _wisp() -> void:
		var y := sin(_t * 2.0) * 3.0
		var ghost := Color(0.86, 0.95, 1.0)
		var sway := sin(_t * 2.5) * 0.25
		var lamp := Vector2(24, 18 + y) + Vector2(sin(sway), cos(sway)) * 16.0 - Vector2(0, 16)
		_glow(lamp + Vector2(0, 14), 34, Color(1.0, 0.65, 0.25, 0.8))
		var h := Vector2(-6, -12 + y)
		var w := sin(_t * 3.0) * 4.0
		draw_colored_polygon(PackedVector2Array([h + Vector2(-25, 2), h + Vector2(25, 2), h + Vector2(16, 30),
			h + Vector2(14 + w, 50), h + Vector2(2 + w, 38), h + Vector2(-16, 26)]), ghost)
		draw_circle(h, 26, ghost)
		for s in [-1.0, 1.0]:
			_ellipse(h + Vector2(9 * s, 2), 5.5, 8.0, Color(0.04, 0.05, 0.12))
			draw_circle(h + Vector2(9 * s + 2, -2), 2.0, Color.WHITE)
		_ellipse(h + Vector2(0, 14), 3.5, 2.5, Color(0.04, 0.05, 0.12))
		draw_line(h + Vector2(24, 10), lamp, Color(0.2, 0.16, 0.14), 2.5)
		draw_colored_polygon(PackedVector2Array([lamp + Vector2(-8, 4), lamp + Vector2(8, 4), lamp + Vector2(0, -3)]), Color(0.2, 0.16, 0.14))
		draw_rect(Rect2(lamp + Vector2(-7, 4), Vector2(14, 18)), Color(0.85, 0.6, 0.25))
		draw_rect(Rect2(lamp + Vector2(-5, 6), Vector2(10, 14)), Color(1.0, 0.8, 0.4))
		draw_circle(lamp + Vector2(0, 13), 4.0, Color(1.0, 0.95, 0.75))

	func _raven() -> void:
		var y := sin(_t * 1.6) * 3.0
		var f := sin(_t * 7.0) * 10.0
		var bone := Color(0.94, 0.92, 0.86)
		var black := Color(0.05, 0.04, 0.06)
		var feather := Color(0.13, 0.11, 0.18)
		var tipc := Color(0.65, 0.4, 1.0)
		_glow(Vector2(0, -16 + y), 26, Color(0.6, 0.35, 1.0, 0.5))
		for s in [-1.0, 1.0]:
			# (version 319) the wing as real feathers: an arm, then four long finger feathers
			# fanning from the wrist, each tipped in glowing violet.
			var wrist := Vector2(26 * s, -8 + y - f * 0.6)
			draw_colored_polygon(PackedVector2Array([Vector2(4 * s, -6 + y), wrist, Vector2(28 * s, 2 + y - f * 0.5), Vector2(6 * s, 10 + y)]), feather)
			for i in 4:
				var ang := -0.5 + i * 0.32
				var d := Vector2(cos(ang) * s, sin(ang))
				var tip := wrist + d * (26.0 - i * 3.0) + Vector2(0, -f * 0.4)
				var nrm := Vector2(-d.y, d.x) * 3.2
				draw_colored_polygon(PackedVector2Array([wrist + nrm, tip, wrist - nrm]), feather)
				draw_colored_polygon(PackedVector2Array([wrist.lerp(tip, 0.65) + nrm * 0.6, tip, wrist.lerp(tip, 0.65) - nrm * 0.6]), tipc)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 18 + y), Vector2(8, 18 + y), Vector2(12, 36 + y), Vector2(-12, 36 + y)]), feather)
		_ellipse(Vector2(0, 6 + y), 11, 20, feather)
		# a ragged crest swept back over the skull
		for i in 3:
			draw_colored_polygon(PackedVector2Array([Vector2(-4 + i * 4, -24 + y), Vector2(-8 + i * 8, -36 + y), Vector2(i * 4, -24 + y)]), feather)
		draw_circle(Vector2(0, -16 + y), 12, bone)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -12 + y), Vector2(5, -12 + y), Vector2(2, 6 + y), Vector2(-1, 4 + y)]), black)
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(5.5 * s, -19 + y), 4.0, black)
			draw_circle(Vector2(5.5 * s, -19 + y), 2.2, Color(0.85, 0.6, 1.0))

	func _mimic() -> void:
		var bite := maxf(0.0, sin(_t * 2.2)) * 10.0
		var wood := Color(0.45, 0.26, 0.12)
		var gold := Color(1.0, 0.76, 0.28)
		var mouth := Color(0.32, 0.03, 0.06)
		var top := -26.0 - bite
		draw_rect(Rect2(-34, top + 20, 68, -16.0 - top), mouth)
		draw_rect(Rect2(-34, top, 68, 20), wood)
		draw_rect(Rect2(-36, top - 6, 72, 8), wood.darkened(0.1))
		for x in [-18.0, 14.0]:
			draw_rect(Rect2(x, top - 6, 5, 26), gold)
		for i in 5:
			var x := -28.0 + i * 13.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, top + 20), Vector2(x + 8, top + 20), Vector2(x + 4, top + 29)]), Color(0.97, 0.95, 0.86))
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(12 * s, top + 26), 3.5, Color(1.0, 0.85, 0.2))
		draw_rect(Rect2(-34, 4, 68, 30), wood)
		for x in [-18.0, 14.0]:
			draw_rect(Rect2(x, 4, 5, 30), gold)
		draw_rect(Rect2(-4, 4, 8, 10), gold)
		for i in 5:
			var x := -30.0 + i * 13.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x + 8, 4), Vector2(x + 4, -5)]), Color(0.97, 0.95, 0.86))
		_ellipse(Vector2(8, 16 + sin(_t * 4.0) * 2.0), 7, 12, Color(0.92, 0.32, 0.42))

	func _bone_wings() -> void:
		var f := sin(_t * 1.8) * 3.0
		var bone := Color(0.93, 0.9, 0.82)
		var skin := Color(0.4, 0.16, 0.52)
		for s in [-1.0, 1.0]:
			var sh := Vector2(4 * s, -4)
			var el := Vector2(20 * s, -16 + f)
			var wr := Vector2(36 * s, -22 + f)
			var tips := [Vector2(50 * s, -26 + f), Vector2(50 * s, -6 + f), Vector2(42 * s, 12 + f), Vector2(26 * s, 22 + f)]
			var poly := PackedVector2Array([sh, el, wr])
			for i in tips.size():
				poly.append(tips[i])
				var nxt: Vector2 = tips[i + 1] if i + 1 < tips.size() else Vector2(6 * s, 18)
				poly.append(((tips[i] + nxt) * 0.5).lerp(wr, 0.3))
			poly.append(Vector2(6 * s, 18))
			draw_colored_polygon(poly, skin)
			draw_line(sh, el, bone, 4.0)
			draw_line(el, wr, bone, 3.5)
			for tp: Vector2 in tips:
				draw_line(wr, tp, bone, 2.2)
			draw_circle(el, 3.5, bone)
			draw_circle(wr, 4.0, bone)
		draw_circle(Vector2(0, -2), 5, Color(0.25, 0.2, 0.3))

	func _phoenix() -> void:
		var f := sin(_t * 2.0) * 3.0
		_glow(Vector2(0, 0), 52, Color(1.0, 0.5, 0.15, 0.7))
		for s in [-1.0, 1.0]:
			for i in 6:
				var k := i / 5.0
				var root := Vector2((4 + 26 * k) * s, -8 - 6 * k + f * k)
				var ang := lerpf(1.9, 0.2, k)
				var d := Vector2(cos(ang) * s, -sin(ang) + 0.6)
				var tip := root + d.normalized() * lerpf(26, 36, k)
				var n := Vector2(-d.y, d.x).normalized() * 4.5
				draw_colored_polygon(PackedVector2Array([root - n, tip, root + n]), Color(1.0, 0.45, 0.1))
				draw_colored_polygon(PackedVector2Array([root.lerp(tip, 0.65) - n * 0.6, tip, root.lerp(tip, 0.65) + n * 0.6]), Color(0.9, 0.15, 0.05))
			draw_line(Vector2(4 * s, -8), Vector2(30 * s, -14 + f), Color(1.0, 0.85, 0.4), 4.0)
		for i in 5:
			var p := Vector2(sin(_t * 1.3 + i * 2.1) * 30, 30 - fmod(_t * 18.0 + i * 13.0, 60.0))
			draw_circle(p, 2.0, Color(1.0, 0.8, 0.3, 0.8))

	func _steps(stars: bool) -> void:
		for j in 2:
			var s := -1.0 if j == 0 else 1.0
			var c := Vector2(14 * s, 14 if j == 0 else -16)
			var age := fmod(_t * 0.7 + j * 0.5, 1.0)
			if stars:
				var pts := [c + Vector2(0, 16), c + Vector2(1, 3), c + Vector2(-1, -8), c + Vector2(-5, -18), c + Vector2(5, -17)]
				var a := 1.0 - age * 0.6
				for pr in [[0, 1], [1, 2], [2, 3], [2, 4]]:
					draw_line(pts[pr[0]], pts[pr[1]], Color(0.7, 0.85, 1.0, 0.45 * a), 1.5)
				for i in pts.size():
					var tw := 0.6 + 0.4 * sin(_t * 6.0 + i * 1.9 + j)
					_glow(pts[i], 10, Color(0.75, 0.85, 1.0, 0.7 * a * tw))
					draw_circle(pts[i], 2.4, Color(1, 1, 1, a))
			else:
				var fire := 1.0 - age
				_ellipse(c + Vector2(0, 6), 9, 13, Color(0.12, 0.06, 0.03))
				for i in 5:
					draw_circle(c + Vector2(-8 + i * 4, -12 + abs(i - 2) * 1.5), 2.6, Color(0.12, 0.06, 0.03))
				var hot := Color(1.0, 0.5 + 0.2 * fire, 0.1, 0.35 + 0.65 * fire)
				_glow(c + Vector2(0, 2), 22, Color(1.0, 0.45, 0.1, 0.6 * fire))
				_ellipse(c + Vector2(0, 6), 6.5, 10, hot)
				for i in 5:
					draw_circle(c + Vector2(-8 + i * 4, -12 + abs(i - 2) * 1.5), 1.6, hot)
				draw_circle(c + Vector2(sin(_t * 3.0 + j) * 3, -4 - age * 26), 1.8, Color(1, 0.75, 0.3, fire))

	## A little skull at the bottom, the start of everything a finisher does.
	func _skull(p: Vector2, r: float, a := 1.0) -> void:
		var bone := Color(0.92, 0.9, 0.82, a)
		draw_circle(p, r, bone)
		draw_rect(Rect2(p + Vector2(-r * 0.55, r * 0.6), Vector2(r * 1.1, r * 0.55)), bone)
		for s in [-1.0, 1.0]:
			draw_circle(p + Vector2(r * 0.4 * s, 0.0), r * 0.28, Color(0.1, 0.06, 0.08, a))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.12, r * 0.45), p + Vector2(r * 0.12, r * 0.45), p + Vector2(0, r * 0.25)]), Color(0.1, 0.06, 0.08, a))

	func _gold_rush() -> void:
		var cycle := fmod(_t, 1.6) / 1.6
		_glow(Vector2(0, 8), 40, Color(1.0, 0.75, 0.25, 0.55 * (1.0 - cycle)))
		_skull(Vector2(0, 30), 13.0, 1.0 - smoothstep(0.0, 0.25, cycle) * 0.6)
		# Coins spring up out of the skull and rain down to both sides, spinning as they go.
		for i in 9:
			var k := fmod(cycle + i * 0.11, 1.0)
			var side := -1.0 if i % 2 == 0 else 1.0
			var vx := side * (10.0 + (i % 4) * 9.0)
			var p := Vector2(vx * k * 1.4, 26.0 - 150.0 * k + 150.0 * k * k)
			var spin := absf(cos(_t * 9.0 + i * 1.3))
			var w := 6.5 * maxf(0.2, spin)
			_ellipse(p, w, 6.5, Color(0.85, 0.55, 0.12))
			_ellipse(p, w * 0.75, 5.0, Color(1.0, 0.8, 0.3))
			if spin > 0.9:
				draw_circle(p + Vector2(-2, -2), 1.6, Color(1, 1, 0.85))
		# A glint over the top.
		var g := 0.5 + 0.5 * sin(_t * 5.0)
		var gp := Vector2(-18, -30)
		draw_line(gp - Vector2(7 * g, 0), gp + Vector2(7 * g, 0), Color(1, 0.95, 0.7), 2.0)
		draw_line(gp - Vector2(0, 7 * g), gp + Vector2(0, 7 * g), Color(1, 0.95, 0.7), 2.0)

	func _soul_harvest() -> void:
		var cycle := fmod(_t, 2.0) / 2.0
		# The rune ring flaring under the fallen skull (version 318).
		var ro := minf(1.0, cycle * 5.0)
		_glow(Vector2(-14, 36), 30, Color(0.55, 0.9, 1.0, 0.45 * (1.0 - cycle)))
		draw_arc(Vector2(-14, 36), 8.0 + 16.0 * ro, 0.0, TAU, 32, Color(0.6, 0.92, 1.0, 0.9 * (1.0 - cycle)), 2.5)
		_skull(Vector2(-14, 30), 12.0)
		# The ghost rises out of the skull, then sweeps up and over in an arc.
		var path := func(q: float) -> Vector2:
			return Vector2(-14 + 44 * q * q + sin(q * 9.0) * 4.0 * (1.0 - q), 22 - 70 * sin(q * PI * 0.6))
		var k := cycle
		var a := minf(1.0, k * 6.0) * (1.0 - smoothstep(0.85, 1.0, k))
		for i in 5:
			var tk := maxf(0.0, k - 0.05 * (i + 1))
			var tp: Vector2 = path.call(tk)
			draw_circle(tp, 9.0 - i * 1.5, Color(0.7, 0.92, 1.0, 0.3 * a * (1.0 - i / 5.0)))
		var p: Vector2 = path.call(k)
		_glow(p, 26, Color(0.6, 0.9, 1.0, 0.6 * a))
		var ghost := Color(0.85, 0.96, 1.0, a)
		draw_circle(p, 12.0, ghost)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0), p + Vector2(12, 0), p + Vector2(6, 18), p + Vector2(0, 13), p + Vector2(-6, 19)]), ghost)
		for s in [-1.0, 1.0]:
			_ellipse(p + Vector2(4.5 * s, -1), 2.8, 4.2, Color(0.05, 0.1, 0.2, a))
			draw_circle(p + Vector2(4.5 * s + 0.8, -2), 1.1, Color(0.8, 1.0, 1.0, a))
			# little arms raised as it wails
			_ellipse(p + Vector2(13.0 * s, 4), 2.6, 4.2, Color(0.75, 0.93, 1.0, a))
		_ellipse(p + Vector2(0, 6), 2.2, 3.0, Color(0.05, 0.1, 0.2, a))   # (its open mouth)
		# The hero's side of it: a pale blue flash where the souls arrive.
		var f := smoothstep(0.75, 0.9, k) * (1.0 - smoothstep(0.9, 1.0, k))
		_glow(Vector2(30, -38), 30, Color(0.6, 0.9, 1.0, 0.8 * f + 0.15))

	func _wyrm() -> void:
		var y := sin(_t * 1.4) * 2.0
		var bone := Color(0.93, 0.9, 0.82)
		var old := Color(0.72, 0.68, 0.6)
		var dark := Color(0.08, 0.05, 0.1)
		var breath := fmod(_t, 3.0) < 1.1
		# A wing raised behind it: bone fingers and torn violet skin.
		var f := sin(_t * (8.0 if breath else 2.0)) * (6.0 if breath else 3.0)
		var sh := Vector2(4, -6 + y)
		var wr := Vector2(18, -34 + y - f)
		var tips := [Vector2(44, -40 + y - f), Vector2(46, -20 + y - f * 0.6), Vector2(34, -6 + y)]
		var poly := PackedVector2Array([sh, wr])
		for tp: Vector2 in tips:
			poly.append(tp)
		draw_colored_polygon(poly, Color(0.45, 0.2, 0.68, 0.85))
		draw_line(sh, wr, bone, 3.0)
		for tp: Vector2 in tips:
			draw_line(wr, tp, bone, 1.8)
		# Body: a spine and ribs around a violet soul fire; a tail curling down and away.
		_glow(Vector2(4, 4 + y), 18, Color(0.7, 0.35, 1.0, 0.7))
		draw_line(Vector2(-14, -8 + y), Vector2(20, 0 + y), bone, 4.0)
		for i in 4:
			var x := -8.0 + i * 8.0
			draw_arc(Vector2(x, 6 + y), 9.0, -PI * 0.9, -PI * 0.1 + PI, 10, bone, 2.0)
		draw_circle(Vector2(4, 6 + y), 5.0, Color(0.8, 0.5, 1.0))
		var tail := PackedVector2Array()
		for i in 8:
			var k := i / 7.0
			tail.append(Vector2(20 + 22 * k, 0 + y + 26 * k * k + sin(_t * 2.0 + k * 3.0) * 3.0 * k))
		draw_polyline(tail, old, 3.0)
		var tip := tail[tail.size() - 1]
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, 0), tip + Vector2(0, -5), tip + Vector2(6, 2), tip + Vector2(0, 6)]), Color(0.75, 0.45, 1.0))
		# Legs.
		for x in [-8.0, 14.0]:
			draw_line(Vector2(x, 12 + y), Vector2(x - 3, 24 + y), bone, 2.5)
		# Neck up to the skull: a long snout, horns swept back, a violet eye; the jaw drops to breathe.
		var head := Vector2(-28, -18 + y)
		draw_line(Vector2(-14, -8 + y), head + Vector2(6, 4), bone, 4.0)
		var jaw := 0.5 if breath else 0.08
		draw_colored_polygon(PackedVector2Array([head + Vector2(4, 2), head + Vector2(-20, 4 + jaw * 14), head + Vector2(-20, 7 + jaw * 14), head + Vector2(2, 8)]), old)
		draw_circle(head, 9.0, bone)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-4, -6), head + Vector2(-22, -1), head + Vector2(-22, 4), head + Vector2(-2, 5)]), bone)
		draw_circle(head + Vector2(-2, -2), 3.4, dark)
		draw_circle(head + Vector2(-2, -2), 1.8, Color(0.85, 0.55, 1.0))
		for i in 2:
			draw_line(head + Vector2(4 - i * 4, -6), head + Vector2(18 - i * 6, -18 + i * 3), old, 2.6 - i * 0.6)
		if breath:
			# Violet fire pouring from the jaws.
			for i in 7:
				var k := fmod(_t * 2.5 + i / 7.0, 1.0)
				var p := head + Vector2(-24 - 34 * k, 6 + 10 * k * k + sin(i * 2.3) * 6.0 * k)
				var r := 3.0 + 9.0 * k
				draw_circle(p, r, Color(0.75, 0.45, 1.0, 0.55 * (1.0 - k)))
				draw_circle(p, r * 0.5, Color(0.95, 0.85, 1.0, 0.7 * (1.0 - k)))

	func _starfall() -> void:
		var night := Color(0.05, 0.05, 0.16)
		var silver := Color(0.86, 0.9, 1.0)
		# The mantle: wide at the hem, cut in points, a window of night sky with twinkling stars.
		var sway := sin(_t * 1.5) * 2.0
		var poly := PackedVector2Array([Vector2(-16, -12), Vector2(16, -12)])
		for i in 11:
			var u := 1.0 - i / 10.0
			var x := lerpf(-38.0, 38.0, u) + sway
			var y := 40.0 - (8.0 if i % 2 == 1 else 0.0)
			poly.append(Vector2(x, y))
		draw_colored_polygon(poly, night)
		var edge := poly.duplicate()
		edge.append(poly[0])
		draw_polyline(edge, silver, 2.0, true)
		for i in 14:
			var p := Vector2(-30 + fmod(i * 37.0, 60.0), -4 + fmod(i * 23.0, 40.0))
			if Geometry2D.is_point_in_polygon(p, poly):
				var tw := 0.5 + 0.5 * sin(_t * 3.0 + i * 1.9)
				draw_circle(p, 1.0 + tw * (1.4 if i % 4 == 0 else 0.6), Color(0.85, 0.9, 1.0, 0.5 + 0.5 * tw))
		# A shooting star across it now and then.
		var ph := fmod(_t, 2.5) / 2.5
		if ph < 0.35:
			var hp := Vector2(-24, 2).lerp(Vector2(22, 28), ph / 0.35)
			draw_line(hp, hp - Vector2(10, 6), Color(1, 1, 1, 0.8), 1.6)
		# The tall collar standing up behind the head, flaring out each side.
		for sd in [-1.0, 1.0]:
			var cl := PackedVector2Array([Vector2(-6 * sd, -12), Vector2(-17 * sd, -12), Vector2(-29 * sd, -33), Vector2(-21 * sd, -36), Vector2(-12 * sd, -24)])
			draw_colored_polygon(cl, night)
			var cle := cl.duplicate()
			cle.append(cl[0])
			draw_polyline(cle, silver, 1.6, true)
			draw_circle(Vector2(-23 * sd, -26), 1.2, Color(0.85, 0.9, 1.0, 0.6 + 0.4 * sin(_t * 2.5 + sd)))
		# The crown: dark points with bright stars at their tips, and a comet going round.
		var cy := -24.0
		draw_rect(Rect2(-17, cy - 3, 34, 8), night)
		draw_line(Vector2(-17, cy - 3), Vector2(17, cy - 3), silver, 1.6)
		draw_line(Vector2(-17, cy + 5), Vector2(17, cy + 5), silver, 1.6)
		for i in 5:
			var x := -14.0 + i * 7.0
			var h := 16.0 if i == 2 else 11.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5, cy - 3), Vector2(x + 3.5, cy - 3), Vector2(x, cy - 3 - h)]), night)
			var tp := Vector2(x, cy - 5 - h)
			_glow(tp, 7.0, Color(0.85, 0.9, 1.0, 0.7))
			draw_circle(tp, 1.8, Color(1.0, 0.97, 0.85))
		var ca := _t * 2.2
		var cp := Vector2(cos(ca) * 30.0, cy - 10.0 + sin(ca) * 7.0)
		for i in 5:
			var b := ca - 0.18 * (i + 1)
			draw_circle(Vector2(cos(b) * 30.0, cy - 10.0 + sin(b) * 7.0), 2.6 - i * 0.4, Color(0.7, 0.8, 1.0, 0.6 - i * 0.1))
		_glow(cp, 9.0, Color(0.9, 0.95, 1.0, 0.9))
		draw_circle(cp, 2.4, Color.WHITE)

	func _emperor() -> void:
		var bone := Color(0.93, 0.88, 0.76)
		var gold := Color(1.0, 0.78, 0.3)
		var velvet := Color(0.36, 0.1, 0.44)
		var ember := Color(1.0, 0.62, 0.16, 0.6 + 0.4 * sin(_t * 4.0))
		# The throne: a fan of long bones topped with skulls behind a velvet back, gold-framed.
		for i in 5:
			var k := (i - 2) / 2.0
			var top := Vector2(k * 34.0, -38.0 + absf(k) * 10.0)
			draw_line(Vector2(k * 10.0, 32), top, bone, 4.0, true)
			_skull(top, 6.5 if i == 2 else 5.0)
		draw_rect(Rect2(-20, -16, 40, 48), velvet)
		draw_rect(Rect2(-20, -16, 40, 48), gold, false, 2.0)
		draw_rect(Rect2(-30, 30, 60, 6), Color(0.2, 0.15, 0.18))
		draw_line(Vector2(-30, 30), Vector2(30, 30), gold, 2.0)
		# The crown of skulls in front: a velvet cap crossed by gold arches, a gold band set
		# with skulls whose eyes burn, gold spikes between them.
		var cy := 10.0
		draw_circle(Vector2(0, cy - 4), 17.0, velvet)
		draw_arc(Vector2(0, cy - 4), 17.0, PI, TAU, 16, gold, 2.2, true)
		draw_line(Vector2(0, cy - 21), Vector2(0, cy - 2), gold, 2.2)
		_skull(Vector2(0, cy - 25), 4.0)
		for i in 4:
			var x := -13.0 + i * 8.67
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, cy), Vector2(x + 2.5, cy), Vector2(x, cy - 10)]), gold)
		draw_rect(Rect2(-19, cy - 1, 38, 9), gold)
		for i in 3:
			var p := Vector2(-11.0 + i * 11.0, cy + 4)
			_skull(p, 4.4 if i == 1 else 3.6)
			for sd in [-1.0, 1.0]:
				draw_circle(p + Vector2(1.6 * sd * (1.2 if i == 1 else 1.0), 0), 1.0, ember)

	## A dark shape of the look's kind, for the looks still to come.
	func _shadow() -> void:
		var col := Color(0.34, 0.31, 0.4)
		match slot:
			"steps":
				for s in [-1.0, 1.0]:
					_ellipse(Vector2(12 * s, 6 * s), 9, 15, col)
					_ellipse(Vector2(12 * s, 6 * s + 20), 6, 5, col)
			"wings":
				for s in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([Vector2(4 * s, 0), Vector2(44 * s, -26), Vector2(38 * s, 4), Vector2(26 * s, 22), Vector2(6 * s, 14)]), col)
			"finisher":
				var pts := PackedVector2Array()
				for i in 16:
					var r := 38.0 if i % 2 == 0 else 15.0
					var a := TAU * i / 16.0
					pts.append(Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(pts, col)
			"grand":
				draw_colored_polygon(PackedVector2Array([Vector2(-34, 18), Vector2(-34, -16), Vector2(-17, 0), Vector2(0, -28),
					Vector2(17, 0), Vector2(34, -16), Vector2(34, 18)]), col)
			_:
				draw_circle(Vector2(0, -4), 26, col)
				_ellipse(Vector2(0, 22), 20, 10, col)
		draw_string(ThemeDB.fallback_font, Vector2(-9, 15), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color(0.75, 0.7, 0.8))
