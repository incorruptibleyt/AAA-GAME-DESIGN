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
##   wyrm:  Bone Wyrm (version 321: it was a tiny dragon on the shoulder, lost from the run
##          camera). A great skeleton serpent with bat wings that coils round the hero in the
##          air: its spine is a chain of vertebrae that follows the path its skull flew, like
##          a real snake, ribs round a violet soul fire, a glowing soul thread running through
##          its bones to a crystal barb, a horned skull whose jaw drops to roar. It breathes a
##          stream of violet fire at a boss (and a puff at a skeleton now and then).
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
const RUN_SIZE := {"wisp": 1.45, "raven": 1.25, "mimic": 1.3, "wyrm": 1.7}

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
var _jaw: Node3D
var _segs: Array[Node3D] = []
var _seg_size := PackedFloat32Array()   # (each vertebra's size)
var _seg_at := PackedFloat32Array()     # (how far behind the skull each sits, at size 1)
var _trail := PackedVector3Array()      # (where the skull has been, newest first)
var _thread: ImmediateMesh
var _flame: CPUParticles3D
var _core: CPUParticles3D
var _heart_mat: StandardMaterial3D
var _mouth_mat: StandardMaterial3D
var _breath := 0.0   # (seconds of fire left)
var _breath_wait := 2.0
var _breath_at := Vector3.ZERO   # (where the fire goes)
var _breath_big := false
var _coil := 0.0      # (the skull's way round the hero)
var _head_at := Vector3.ZERO
var _head_dir := Vector3.FORWARD
var _wsize := 1.0     # (bigger in a run)
var _roar := -1.0
var _roar_wait := 4.0
var _hit_wait := 0.0


func _ready() -> void:
	_anchor = get_parent() as Node3D
	_staged = get_viewport() is SubViewport
	top_level = not _staged
	if kind == "wyrm" and top_level:
		global_transform = Transform3D.IDENTITY   # (its bones are placed in the world itself)
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
	if kind == "wyrm":
		pass   # (its bones are placed one by one, at its own size: _wsize)
	elif not _staged:
		# In a run the camera is far above: the pet is drawn bigger there than on a pedestal.
		_body.scale = Vector3.ONE * float(RUN_SIZE.get(kind, 1.3))
	_base_scale = _body.scale
	_place_now()


func _place_now() -> void:
	if kind == "wyrm":
		_wyrm_lay()
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

## Its vertebrae, from the neck to the tail: their sizes (3 neck, 4 with ribs, 9 tail).
const WYRM_SIZES := [0.72, 0.8, 0.88, 1.0, 1.08, 1.08, 1.0, 0.92, 0.84, 0.76, 0.68, 0.6, 0.52, 0.45, 0.39, 0.34]
const WYRM_CHEST := 3   # (the first vertebra with ribs; the wings grow from it)
const WYRM_BONE := Color(0.93, 0.9, 0.82)
const WYRM_OLD := Color(0.7, 0.65, 0.56)
const WYRM_DARK := Color(0.05, 0.025, 0.08)
static var _wyrm_meshes := {}
static var _wyrm_bone_mat: ShaderMaterial
static var _wyrm_skin_mat: ShaderMaterial
static var _wyrm_thread_mat: ShaderMaterial


func _build_wyrm() -> void:
	# In a run it is drawn big, for the camera far above (the hero is 2.1 m tall there).
	_wsize = float(RUN_SIZE.wyrm) if not _staged else 1.0
	var bone := _wyrm_bone()
	var violet := _mat("wyrm_eye", Color(0.85, 0.6, 1.0), 0.3, Color(0.75, 0.42, 1.0), 5.0)
	_heart_mat = _mat("wyrm_heart%d" % get_instance_id(), Color(0.7, 0.4, 1.0), 0.3, Color(0.65, 0.3, 1.0), 3.0)
	# The skull: long and horned, deep sockets with violet eyes, teeth along both jaws.
	_head = Node3D.new()
	_body.add_child(_head)
	_wyrm_mesh(_head, "skull", bone)
	for side in [-1.0, 1.0]:
		_sphere(_head, 0.026, violet, Vector3(0.105 * side, 0.05, -0.05))
		var eg := MeshInstance3D.new()
		eg.mesh = _quad(0.2)
		eg.material_override = _add_mat(Color(0.75, 0.45, 1.0, 0.9), true)
		eg.position = Vector3(0.11 * side, 0.055, -0.05)
		eg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head.add_child(eg)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, -0.035, 0.08)
	_head.add_child(_jaw)
	_wyrm_mesh(_jaw, "jaw", bone)
	# A violet glow in its throat that blazes when the jaw drops.
	var mouth := MeshInstance3D.new()
	mouth.mesh = _quad(0.5)
	_mouth_mat = _add_mat(Color(0.8, 0.5, 1.0, 0.0), true)
	mouth.material_override = _mouth_mat
	mouth.position = Vector3(0, -0.04, -0.2)
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.add_child(mouth)
	# Its fire: a violet stream from the open jaws with a white-hot core, left in the world.
	_flame = _wyrm_fire(0.62, Color(0.82, 0.45, 1.0), 80)
	_flame.position = Vector3(0, -0.04, -0.32)
	_head.add_child(_flame)
	_core = _wyrm_fire(0.3, Color(1.0, 0.92, 1.0), 40)
	_core.position = _flame.position
	_head.add_child(_core)
	# The spine: a chain of vertebrae, ribs round the chest, a crystal barb at the tail's end.
	var at := 0.2   # (the neck starts behind the skull)
	for i in WYRM_SIZES.size():
		var sz: float = WYRM_SIZES[i]
		if i > 0:
			at += 0.1 * (sz + float(WYRM_SIZES[i - 1])) * 0.5
		_seg_at.append(at)
		_seg_size.append(sz)
		var seg := Node3D.new()
		_body.add_child(seg)
		_segs.append(seg)
		var shape := "neck" if i < WYRM_CHEST else ("ribs" if i < WYRM_CHEST + 4 else "tail")
		_wyrm_mesh(seg, shape, bone)
	var tip := _segs[_segs.size() - 1]
	var barb := MeshInstance3D.new()
	barb.mesh = _wyrm_barb()
	barb.material_override = violet
	tip.add_child(barb)
	var bg := MeshInstance3D.new()
	bg.mesh = _quad(0.7)
	bg.material_override = _add_mat(Color(0.7, 0.4, 1.0, 0.7), true)
	bg.position = Vector3(0, 0, 0.15)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tip.add_child(bg)
	# The soul fire in its ribs, and the glow it throws (so bone reads on a pale floor too).
	var chest := _segs[WYRM_CHEST + 1]
	var heart := _sphere(chest, 0.07, _heart_mat, Vector3(0, -0.11, 0.05))
	heart.scale = Vector3(1.0, 1.1, 1.4)
	var hg := MeshInstance3D.new()
	hg.mesh = _quad(0.9)
	hg.material_override = _add_mat(Color(0.65, 0.35, 1.0, 0.75), true)
	hg.position = Vector3(0, -0.1, 0.05)
	hg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chest.add_child(hg)
	# Violet embers falling from the ribs.
	var em := CPUParticles3D.new()
	em.amount = 12
	em.lifetime = 1.3
	em.local_coords = false
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	em.emission_sphere_radius = 0.12
	em.position = Vector3(0, -0.12, 0.05)
	em.direction = Vector3.DOWN
	em.spread = 40.0
	em.gravity = Vector3(0, -0.5, 0)
	em.initial_velocity_min = 0.1
	em.initial_velocity_max = 0.4
	var eq := QuadMesh.new()
	eq.size = Vector2.ONE * 0.09 * _wsize
	em.mesh = eq
	var emm := _add_mat(Color(1, 1, 1, 1), true)
	emm.vertex_color_use_as_albedo = true
	emm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	em.material_override = emm
	var eg2 := Gradient.new()
	eg2.set_color(0, Color(0.95, 0.8, 1.0, 1.0))
	eg2.set_color(1, Color(0.5, 0.2, 1.0, 0.0))
	em.color_ramp = eg2
	chest.add_child(em)
	# Bat wings from the chest: bone fingers and a torn membrane with glowing veins.
	_wing_l = _wyrm_wing(-1.0, _segs[WYRM_CHEST], bone)
	_wing_r = _wyrm_wing(1.0, _segs[WYRM_CHEST], bone)
	# The soul thread: a violet light running down the spine through every bone.
	_thread = ImmediateMesh.new()
	var th := MeshInstance3D.new()
	th.mesh = _thread
	th.material_override = _wyrm_thread()
	th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	th.extra_cull_margin = 16384.0   # (its mesh is drawn anew every frame, wherever the wyrm is)
	_body.add_child(th)


## One of its baked shapes (skull, jaw, neck, ribs, tail), as a child of `parent`.
func _wyrm_mesh(parent: Node3D, shape: String, m: Material) -> MeshInstance3D:
	if not _wyrm_meshes.has(shape):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match shape:
			"skull":
				_wyrm_skull(st)
			"jaw":
				_wyrm_jaw(st)
			_:
				_wyrm_vertebra(st, shape)
		_wyrm_meshes[shape] = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _wyrm_meshes[shape]
	mi.material_override = m
	parent.add_child(mi)
	return mi


## A closed tube through `pts`, `rx` wide and `ry` tall at each (0 makes a point), coloured
## `cols`. Its rings stand square to the line; `up` says which way their "tall" faces.
static func _loft(st: SurfaceTool, pts: Array, rx: Array, ry: Array, cols: Array, n := 10, up := Vector3.UP) -> void:
	var rings := []
	var m := pts.size()
	for i in m:
		var t: Vector3 = (pts[mini(i + 1, m - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var u := up
		if absf(t.dot(u)) > 0.95:
			u = Vector3.BACK if absf(t.dot(Vector3.BACK)) < 0.95 else Vector3.RIGHT
		var x := u.cross(t).normalized()
		var y := t.cross(x).normalized()
		var a_rx: float = rx[i]
		var a_ry: float = ry[i]
		var ring := []
		for j in n + 1:
			var a := TAU * j / n
			var off := x * cos(a) * a_rx + y * sin(a) * a_ry
			var nrm := (x * cos(a) / maxf(a_rx, 0.002) + y * sin(a) / maxf(a_ry, 0.002)).normalized()
			if a_rx < 0.001 and a_ry < 0.001:
				nrm = t * (1.0 if i == m - 1 else -1.0)
			ring.append([pts[i] + off, nrm, cols[mini(i, cols.size() - 1)]])
		rings.append(ring)
	for i in m - 1:
		for j in n:
			for c in [rings[i][j], rings[i + 1][j], rings[i + 1][j + 1], rings[i][j], rings[i + 1][j + 1], rings[i][j + 1]]:
				st.set_color(c[2])
				st.set_normal(c[1])
				st.add_vertex(c[0])


## A ball `r` wide (x, y, z) at `c`.
static func _ball(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, n := 8) -> void:
	var pts := []
	var rx := []
	var ry := []
	for i in n + 1:
		var k := -1.0 + 2.0 * i / n
		var w := sqrt(maxf(0.0, 1.0 - k * k))
		pts.append(c + Vector3(0, 0, k * r.z))
		rx.append(w * r.x)
		ry.append(w * r.y)
	_loft(st, pts, rx, ry, [col], 10)


## A horn, tooth or spike: from `a` along a curve to `b`, bent by `bend` at its middle,
## `r` thick at the root to a point.
static func _spike(st: SurfaceTool, a: Vector3, b: Vector3, bend: Vector3, r: float, c0: Color, c1: Color, n := 5) -> void:
	var pts := []
	var rs := []
	var cs := []
	for i in n + 1:
		var k := float(i) / n
		pts.append(a.lerp(b, k) + bend * sin(PI * k))
		rs.append(r * pow(1.0 - k, 0.8) + (0.0 if i == n else 0.002))
		cs.append(c0.lerp(c1, k * k))
	_loft(st, pts, rs, rs, cs, 7)


## The skull (its front is -Z): a long head over a long snout, a heavy brow over deep sockets,
## two great horns swept back and up, two small ones, a crest of spikes, and teeth.
static func _wyrm_skull(st: SurfaceTool) -> void:
	var prof := [   # [z, y, half width, half height]
		[0.16, 0.04, 0.0, 0.0], [0.15, 0.04, 0.06, 0.055], [0.11, 0.045, 0.11, 0.09], [0.05, 0.045, 0.13, 0.1],
		[-0.02, 0.035, 0.12, 0.085], [-0.08, 0.02, 0.09, 0.065], [-0.15, 0.01, 0.075, 0.052],
		[-0.22, 0.005, 0.07, 0.048], [-0.27, 0.0, 0.066, 0.045], [-0.31, -0.005, 0.046, 0.034], [-0.33, -0.01, 0.0, 0.0]]
	var pts := []
	var rx := []
	var ry := []
	for p in prof:
		pts.append(Vector3(0, p[1], p[0]))
		rx.append(p[2])
		ry.append(p[3])
	_loft(st, pts, rx, ry, [WYRM_BONE], 14)
	for side in [-1.0, 1.0]:
		# The sockets, dark and deep, under a heavy brow ridge.
		_ball(st, Vector3(0.09 * side, 0.045, -0.045), Vector3(0.05, 0.042, 0.055), WYRM_DARK)
		_spike(st, Vector3(0.05 * side, 0.105, 0.03), Vector3(0.115 * side, 0.09, -0.085), Vector3(0.0, 0.012, 0.0), 0.032, WYRM_BONE, WYRM_OLD)
		# Nostrils.
		_ball(st, Vector3(0.03 * side, 0.035, -0.29), Vector3(0.016, 0.012, 0.02), WYRM_DARK, 6)
		# The great horns, back and curling up; the small ones back and out.
		_spike(st, Vector3(0.07 * side, 0.1, 0.08), Vector3(0.13 * side, 0.2, 0.42), Vector3(0.02 * side, -0.07, 0.0), 0.04, WYRM_BONE, WYRM_DARK.lerp(WYRM_OLD, 0.4), 7)
		_spike(st, Vector3(0.11 * side, 0.01, 0.07), Vector3(0.22 * side, -0.02, 0.24), Vector3(0, 0.02, 0), 0.024, WYRM_BONE, WYRM_OLD)
		# Cheek spurs below the eyes.
		_spike(st, Vector3(0.1 * side, -0.02, -0.02), Vector3(0.17 * side, -0.05, 0.05), Vector3.ZERO, 0.016, WYRM_BONE, WYRM_OLD, 3)
		# Upper teeth, a long fang among them.
		for i in 6:
			var z := -0.07 - i * 0.042
			var fang := i == 4
			_spike(st, Vector3((0.058 - i * 0.003) * side, -0.025, z), Vector3((0.056 - i * 0.003) * side, -0.07 if fang else -0.05, z - 0.006), Vector3.ZERO, 0.016 if fang else 0.011, WYRM_BONE, Color(1, 0.98, 0.94), 3)
	# A crest of spikes down the middle of the head.
	for i in 3:
		var z := 0.12 - i * 0.055
		_spike(st, Vector3(0, 0.12 - i * 0.008, z), Vector3(0, 0.2 - i * 0.025, z + 0.07), Vector3.ZERO, 0.024 - i * 0.004, WYRM_BONE, WYRM_OLD, 3)


## The lower jaw (from its hinge at the origin), with teeth pointing up.
static func _wyrm_jaw(st: SurfaceTool) -> void:
	var prof := [[0.03, -0.012, 0.0, 0.0], [0.01, -0.015, 0.09, 0.03], [-0.1, -0.028, 0.082, 0.028],
		[-0.2, -0.033, 0.066, 0.024], [-0.3, -0.032, 0.05, 0.02], [-0.37, -0.028, 0.0, 0.0]]
	var pts := []
	var rx := []
	var ry := []
	for p in prof:
		pts.append(Vector3(0, p[1], p[0]))
		rx.append(p[2])
		ry.append(p[3])
	_loft(st, pts, rx, ry, [WYRM_OLD.lerp(WYRM_BONE, 0.5)], 12)
	for side in [-1.0, 1.0]:
		for i in 5:
			var z := -0.1 - i * 0.045
			_spike(st, Vector3((0.05 - i * 0.004) * side, -0.012, z), Vector3((0.048 - i * 0.004) * side, 0.028, z - 0.005), Vector3.ZERO, 0.01, WYRM_BONE, Color(1, 0.98, 0.94), 3)


## A vertebra (its front, towards the head, is -Z): a spool of bone with a spine fin on top
## and spurs out to the sides; "ribs" adds a pair of curved ribs round the soul fire.
static func _wyrm_vertebra(st: SurfaceTool, shape: String) -> void:
	var pts := []
	var rs := []
	for p in [[-0.05, 0.0], [-0.047, 0.046], [-0.035, 0.058], [0.0, 0.047], [0.035, 0.058], [0.047, 0.046], [0.05, 0.0]]:
		pts.append(Vector3(0, 0, p[0]))
		rs.append(p[1])
	_loft(st, pts, rs, rs, [WYRM_BONE], 10)
	var fin := 0.08 if shape == "neck" else (0.12 if shape == "ribs" else 0.1)
	_spike(st, Vector3(0, 0.04, 0.0), Vector3(0, 0.04 + fin, 0.06), Vector3(0, 0, -0.01), 0.032, WYRM_BONE, WYRM_OLD, 4)
	for side in [-1.0, 1.0]:
		_spike(st, Vector3(0.04 * side, 0.0, 0.0), Vector3(0.095 * side, 0.012, 0.03), Vector3.ZERO, 0.022, WYRM_BONE, WYRM_OLD, 3)
		if shape == "ribs":
			# A rib: out, down and back in under the spine, swept a little back.
			var rib := [Vector3(0.04 * side, -0.005, 0.0), Vector3(0.11 * side, -0.03, 0.015), Vector3(0.15 * side, -0.1, 0.03),
				Vector3(0.135 * side, -0.19, 0.04), Vector3(0.075 * side, -0.245, 0.042), Vector3(0.025 * side, -0.26, 0.04)]
			var rr := []
			var rc := []
			for i in rib.size():
				rr.append(0.022 - i * 0.002 if i < rib.size() - 1 else 0.006)
				rc.append(WYRM_BONE.lerp(WYRM_OLD, float(i) / rib.size()))
			_loft(st, rib, rr, rr, rc, 7)


## The crystal barb at the end of the tail: a flat violet blade pointing back.
static func _wyrm_barb() -> Mesh:
	if _wyrm_meshes.has("barb"):
		return _wyrm_meshes.barb
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color.WHITE
	_loft(st, [Vector3(0, 0, 0.02), Vector3(0, 0, 0.08), Vector3(0, 0, 0.16), Vector3(0, 0, 0.28)],
		[0.0, 0.12, 0.08, 0.0], [0.0, 0.03, 0.022, 0.0], [c], 8)
	_spike(st, Vector3(0.08, 0, 0.08), Vector3(0.17, 0, 0.0), Vector3.ZERO, 0.022, c, c, 3)
	_spike(st, Vector3(-0.08, 0, 0.08), Vector3(-0.17, 0, 0.0), Vector3.ZERO, 0.022, c, c, 3)
	var m := st.commit()
	_wyrm_meshes.barb = m
	return m


## A bat wing from the chest vertebra `seg` (x out to the `side`, z back): an arm to the
## wrist, four long fingers, a hooked thumb, and a torn membrane between them.
func _wyrm_wing(side: float, seg: Node3D, bone: Material) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.05 * side, 0.03, -0.01)
	w.scale = Vector3.ONE * 1.0
	seg.add_child(w)
	var key := "wing%d" % int(side)
	if not _wyrm_meshes.has(key):
		var S := Vector2(0.0, 0.0)
		var E := Vector2(0.2, -0.08)
		var W := Vector2(0.4, -0.05)
		var tips: Array[Vector2] = [Vector2(0.8, 0.02), Vector2(0.74, 0.3), Vector2(0.56, 0.5), Vector2(0.3, 0.56)]
		var B := Vector2(0.03, 0.46)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var v3 := func(p: Vector2) -> Vector3: return Vector3(p.x * side, 0.0, p.y)
		_spike(st, v3.call(S), v3.call(E), Vector3.ZERO, 0.026, WYRM_BONE, WYRM_BONE, 3)
		_spike(st, v3.call(E), v3.call(W), Vector3.ZERO, 0.022, WYRM_BONE, WYRM_BONE, 3)
		_ball(st, v3.call(E), Vector3.ONE * 0.026, WYRM_BONE, 6)
		_ball(st, v3.call(W), Vector3.ONE * 0.03, WYRM_BONE, 6)
		for tp in tips:
			var bend := (tp - W).orthogonal().normalized() * -0.03 * side
			_spike(st, v3.call(W), v3.call(tp), Vector3(bend.x, 0.015, bend.y), 0.015, WYRM_BONE, WYRM_OLD, 5)
		_spike(st, v3.call(W), v3.call(W + Vector2(0.05, -0.12)), Vector3(0, 0.02, 0), 0.018, WYRM_BONE, WYRM_DARK.lerp(WYRM_OLD, 0.3), 4)
		_wyrm_meshes[key] = st.commit()
		# The membrane: a panel between each pair of fingers, and one from the arm back to the
		# body, its trailing edge scalloped. UV.x counts the panels (whole numbers on the
		# fingers, where the veins run), UV.y 0 at the wrist to 1 at the edge.
		var ms := SurfaceTool.new()
		ms.begin(Mesh.PRIMITIVE_TRIANGLES)
		var panels := [[W, tips[0], W, tips[1]], [W, tips[1], W, tips[2]], [W, tips[2], W, tips[3]], [W, tips[3], S, B]]
		var nu := 5
		var nv := 6
		for k in panels.size():
			var pn: Array = panels[k]
			var grid := []
			for iu in nu + 1:
				var u := float(iu) / nu
				var col := []
				for iv in nv + 1:
					var v := float(iv) / nv
					var a: Vector2 = (pn[0] as Vector2).lerp(pn[1], v)
					var b: Vector2 = (pn[2] as Vector2).lerp(pn[3], v)
					var p := a.lerp(b, u)
					# (the edge between two finger tips curves in towards the wrist)
					var root: Vector2 = (pn[0] as Vector2).lerp(pn[2], u)
					p = p.lerp(root, 0.22 * sin(PI * u) * v * v)
					col.append([Vector3(p.x * side, -0.004, p.y), Vector2(k + u, v)])
				grid.append(col)
			for iu in nu:
				for iv in nv:
					for c in [grid[iu][iv], grid[iu][iv + 1], grid[iu + 1][iv + 1], grid[iu][iv], grid[iu + 1][iv + 1], grid[iu + 1][iv]]:
						ms.set_uv(c[1])
						ms.set_normal(Vector3.UP)
						ms.add_vertex(c[0])
		_wyrm_meshes[key + "skin"] = ms.commit()
	var bm := MeshInstance3D.new()
	bm.mesh = _wyrm_meshes[key]
	bm.material_override = bone
	w.add_child(bm)
	var sm := MeshInstance3D.new()
	sm.mesh = _wyrm_meshes[key + "skin"]
	sm.material_override = _wyrm_skin()
	w.add_child(sm)
	return w


## Bone: its colour from the mesh, a violet rim of soul light round its edges so the white
## bone stands off any floor.
static func _wyrm_bone() -> ShaderMaterial:
	if _wyrm_bone_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float lit = step(0.25, COLOR.r);
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.62;
	EMISSION = vec3(0.55, 0.25, 1.0) * fres * 0.7 * lit + COLOR.rgb * 0.06 * lit;
}
"""
		_wyrm_bone_mat = ShaderMaterial.new()
		_wyrm_bone_mat.shader = sh
	return _wyrm_bone_mat


## The wing membrane: dark violet skin, glowing veins along the fingers, a glowing torn
## edge, and pulses of soul light running out to it.
static func _wyrm_skin() -> ShaderMaterial:
	if _wyrm_skin_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float k = UV.x;
	float v = UV.y;
	float cell = floor(k * 4.0);
	float h = fract(sin(cell * 91.7 + 3.1) * 4375.85);
	if (v > 0.8 + 0.22 * h && abs(fract(k * 4.0) - 0.5) < 0.2 + 0.1 * h) {
		discard;
	}
	float f = fract(k);
	float vein = 1.0 - smoothstep(0.0, 0.07, min(f, 1.0 - f));
	float fine = (1.0 - smoothstep(0.0, 0.05, abs(fract(k * 3.0 + v * 0.4) - 0.5) - 0.42)) * smoothstep(0.15, 0.6, v) * 0.35;
	float edge = smoothstep(0.72, 0.98, v);
	float pulse = pow(max(0.0, sin(v * 9.0 - TIME * 3.0)), 6.0) * smoothstep(0.1, 0.4, v);
	ALBEDO = vec3(0.13, 0.05, 0.22);
	ROUGHNESS = 0.8;
	EMISSION = vec3(0.62, 0.3, 1.0) * (0.16 + vein * 0.9 + fine + edge * 0.75 + pulse * 0.45);
}
"""
		_wyrm_skin_mat = ShaderMaterial.new()
		_wyrm_skin_mat.shader = sh
	return _wyrm_skin_mat


## The soul thread down its spine: brightest on the line, soft at its sides, pulses flowing
## from the skull to the tail.
static func _wyrm_thread() -> ShaderMaterial:
	if _wyrm_thread_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float flow = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(UV.y * 9.0 - TIME * 7.0), 3.0);
	ALBEDO = vec3(0.62, 0.32, 1.0) * across * across * flow * COLOR.a;
}
"""
		_wyrm_thread_mat = ShaderMaterial.new()
		_wyrm_thread_mat.shader = sh
	return _wyrm_thread_mat


func _wyrm_fire(size: float, col: Color, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.55
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.04 * _wsize
	p.direction = Vector3(0, 0, -1)
	p.spread = 10.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 5.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.85
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.45, 1.0))
	curve.add_point(Vector2(1.0, 1.15))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size * _wsize
	p.mesh = q
	var m := _add_mat(Color(1, 1, 1, 1), true)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.95, 1.0, 1.0), col, Color(col.r * 0.5, col.g * 0.2, col.b, 0.0)])
	p.color_ramp = g
	return p


## Where the skull flies at the turn `c` of its coil: on a pedestal a tilted ring round the
## hero (high behind their head, low in front of their knees); in a run wide loops over the
## hero, rising and falling so the body snakes.
func _wyrm_path(c: float) -> Vector3:
	if _staged:
		return Vector3(sin(c) * 0.8, 1.4 + 0.72 * cos(c), cos(c) * 0.5)
	# (its ring is pushed 0.6 m towards the camera: the camera looks down from behind at 58
	# degrees, so a skull 2 m up on the near side was drawn over the hero's body)
	var a := _anchor.global_position
	return a + Vector3(cos(c) * 1.7, 2.0 + 0.4 * sin(c * 2.0 + 0.7), 0.6 + sin(c) * 1.5)


## Lays the whole wyrm along its path at once (when it is made, and in a new room).
func _wyrm_lay() -> void:
	_trail.clear()
	for j in 80:
		_trail.append(_wyrm_path(_coil - j * 0.05 * (1.0 if _staged else 0.5)))
	_head_at = _trail[0]
	_head_dir = (_trail[0] - _trail[1]).normalized()
	_wyrm_place()


func _wyrm(delta: float) -> void:
	if not _staged and _head_at.distance_to(_anchor.global_position) > 9.0:
		_wyrm_lay()   # (a new room: it is there with the hero at once)
	# Looking for something to burn: a boss in reach, else now and then the nearest skeleton.
	_breath_wait -= delta
	if _breath <= 0.0 and _breath_wait <= 0.0:
		var target: Node3D = null
		_breath_big = false
		if not _staged:
			for b in Game._bosses:
				if is_instance_valid(b) and not (b as Actor).dead and _head_at.distance_to((b as Node3D).global_position) < 12.0:
					target = b
					_breath_big = true
					break
			if target == null:
				target = _nearest_enemy(7.0)
			if target != null:
				_breath_at = target.global_position + Vector3(0, 1.0, 0)
				_breath = 1.4 if _breath_big else 0.5
				_breath_wait = 2.4 if _breath_big else randf_range(3.5, 6.0)
			else:
				_breath_wait = 0.5
		elif absf(sin(_coil)) > 0.97:
			# On a pedestal: out past the hero's side, towards the camera, every few seconds.
			_breath_at = _head_at + Vector3(signf(sin(_coil)) * 0.7, -0.1, -1.0)
			_breath = 1.0
			_breath_wait = 3.8
		var big := _breath_big or _staged
		var sp := (5.5 if big else 3.0) * _wsize
		_flame.initial_velocity_min = sp
		_flame.initial_velocity_max = sp * 1.2
		_core.initial_velocity_min = sp * 1.1
		_core.initial_velocity_max = sp * 1.3
	var fire := _breath > 0.0
	_breath = maxf(0.0, _breath - delta)
	# Now and then, with nothing to burn, it rears and roars.
	_roar_wait -= delta
	if _roar < 0.0 and not fire and _roar_wait <= 0.0:
		_roar = 0.0
		_roar_wait = randf_range(6.0, 9.0)
	var roar := 0.0
	if _roar >= 0.0:
		_roar += delta
		roar = sin(clampf(_roar / 1.2, 0.0, 1.0) * PI)
		if _roar > 1.2:
			_roar = -1.0
	# The skull flies its coil (slowly while it breathes), or to a spot beside the hero facing
	# what it burns, and the body follows the path it flew.
	_coil += delta * ((0.12 if _staged else 0.35) if fire else (0.85 if _staged else 1.15))
	var want := _wyrm_path(_coil)
	if fire and not _staged:
		var a := _anchor.global_position
		var to := _breath_at - a
		to.y = 0.0
		if to.length() > 0.1:
			want = a + to.normalized() * 1.2 + Vector3(0, 2.2, 0.5)
	var prev := _head_at
	_head_at = _head_at.lerp(want, 1.0 - exp(-(7.0 if not _staged else 30.0) * delta))
	var vel := (_head_at - prev) / delta
	var look := _head_dir
	if fire:
		look = (_breath_at - _head_at).normalized()
	elif vel.length() > 0.15:
		look = vel.normalized()
	look = (look + Vector3.UP * (0.9 * roar) + Vector3.DOWN * 0.12).normalized()
	_head_dir = _head_dir.slerp(look, 1.0 - exp(-(9.0 if fire else 5.0) * delta)).normalized()
	if _trail.is_empty() or _head_at.distance_to(_trail[0]) > 0.035 * _wsize:
		_trail.insert(0, _head_at)
		if _trail.size() > 160:
			_trail.resize(160)
	# The fire starts once it faces its target (a breath with no target, as the warm-up asks
	# for, goes at once).
	var aim := (_breath_at - _head_at).normalized()
	var facing := _staged or _breath_at == Vector3.ZERO or _head_dir.dot(aim) > 0.9
	_flame.emitting = fire and facing
	_core.emitting = _flame.emitting
	if _flame.emitting and _breath_big and not _staged:
		_hit_wait -= delta
		if _hit_wait <= 0.0:
			_hit_wait = 0.25
			Fx._burst(_breath_at, 8, Color(0.75, 0.45, 1.0), 0.45, 2.8, 0.35, 0.0, true, "glint")
	var open := 0.62 if fire else 0.08 + 0.04 * sin(_t * 2.0)
	open = maxf(open, 0.8 * roar)
	_jaw.rotation.x = lerpf(_jaw.rotation.x, -open, 1.0 - exp(-14.0 * delta))
	_mouth_mat.albedo_color.a = clampf(-_jaw.rotation.x * 1.6, 0.0, 1.0)
	# The soul fire in its ribs pulses, and blazes as it breathes or roars.
	_heart_mat.emission_energy_multiplier = (6.0 if fire else 2.5 + 3.0 * roar) + sin(_t * 4.0) * 0.8
	_wyrm_place()
	# The wings: slow, heavy beats; spread wide and quick as it hovers to breathe or roars.
	var spread := maxf(1.0 if fire else 0.0, roar)
	var beat := sin(_t * lerpf(3.4, 6.5, spread))
	for side in [-1.0, 1.0]:
		var w: Node3D = _wing_l if side < 0.0 else _wing_r
		w.rotation = Vector3(0.0, side * lerpf(-0.35, -0.1, spread), side * (lerpf(0.15, 0.3, spread) + beat * lerpf(0.5, 0.65, spread)))


## Puts the skull at its place and every vertebra along the path behind it, each turned to
## look at the one before, and draws the soul thread through them.
func _wyrm_place() -> void:
	var up := Vector3.UP
	_head.transform = Transform3D(_wyrm_basis(_head_dir, up).scaled(Vector3.ONE * _wsize * 1.15), _head_at)
	# One walk down the trail, finding each vertebra's spot.
	var path := PackedVector3Array([_head_at])
	path.append_array(_trail)
	var j := 0
	var walked := 0.0
	var spots := PackedVector3Array()
	for i in _segs.size():
		var want := _seg_at[i] * _wsize
		while j < path.size() - 1:
			var step := path[j].distance_to(path[j + 1])
			if walked + step >= want:
				break
			walked += step
			j += 1
		var p: Vector3
		if j < path.size() - 1:
			var step2 := path[j].distance_to(path[j + 1])
			p = path[j].lerp(path[j + 1], clampf((want - walked) / maxf(step2, 0.0001), 0.0, 1.0))
		else:
			p = path[path.size() - 1] - _head_dir * (want - walked)
		spots.append(p)
	var before := _head_at
	for i in _segs.size():
		var p := spots[i]
		var fwd := before - p
		if fwd.length() < 0.0001:
			fwd = _head_dir
		_segs[i].transform = Transform3D(_wyrm_basis(fwd.normalized(), up).scaled(Vector3.ONE * _seg_size[i] * _wsize), p)
		before = p
	# The thread: a cross of two soft ribbons (one lying flat for the camera above, one
	# standing for the pedestal's), from the back of the skull to the barb.
	_thread.clear_surfaces()
	_thread.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var line := PackedVector3Array([_head_at + _head_dir * -0.05 * _wsize])
	line.append_array(spots)
	line.append(spots[spots.size() - 1] + (spots[spots.size() - 1] - spots[spots.size() - 2]).normalized() * 0.2 * _wsize)
	var along := 0.0
	for k in 2:
		along = 0.0
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			var t := (a - b).normalized()
			var sz_a := (1.0 if i == 0 else _seg_size[mini(i - 1, _seg_size.size() - 1)]) * _wsize
			var sz_b := _seg_size[mini(i, _seg_size.size() - 1)] * _wsize
			var side := t.cross(up).normalized() if k == 0 else up
			if side.length() < 0.5:
				side = Vector3.RIGHT
			var wa := side * 0.15 * sz_a
			var wb := side * 0.15 * sz_b
			var la := along
			along += a.distance_to(b) / _wsize
			var fade_a := 1.0 - float(i) / line.size() * 0.5
			var fade_b := 1.0 - float(i + 1) / line.size() * 0.5
			for v in [[a - wa, 0.0, la, fade_a], [b - wb, 0.0, along, fade_b], [b + wb, 1.0, along, fade_b],
					[a - wa, 0.0, la, fade_a], [b + wb, 1.0, along, fade_b], [a + wa, 1.0, la, fade_a]]:
				_thread.surface_set_color(Color(1, 1, 1, v[3]))
				_thread.surface_set_uv(Vector2(v[1], v[2]))
				_thread.surface_add_vertex(v[0])
	_thread.surface_end()


static func _wyrm_basis(fwd: Vector3, up: Vector3) -> Basis:
	if absf(fwd.dot(up)) > 0.98:
		up = Vector3.BACK
	return Basis.looking_at(fwd, up)


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
		# (version 320) the gold shockwave ringing out from the skull
		draw_arc(Vector2(0, 34), 6.0 + 34.0 * minf(1.0, cycle * 3.0), 0.0, TAU, 40, Color(1.0, 0.82, 0.35, 0.9 * (1.0 - minf(1.0, cycle * 2.2))), 3.0)
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
		var bone := Color(0.93, 0.9, 0.82)
		var old := Color(0.72, 0.67, 0.58)
		var dark := Color(0.06, 0.03, 0.09)
		var vio := Color(0.75, 0.45, 1.0)
		var breath := fmod(_t, 3.2) < 1.2
		# The spine: a snaking chain of vertebrae from the skull (top left) to the crystal barb
		# (bottom right), a violet soul thread glowing through it.
		var sp := PackedVector2Array()
		for i in 17:
			var k := i / 16.0
			sp.append(Vector2(-16.0 + 58.0 * k, -12.0 + 40.0 * k + sin(k * 6.0 + 0.5 - _t * 1.8) * 9.0 * (0.35 + k)))
		# A bat wing raised from the chest: bone fingers, a dark membrane with glowing veins.
		var ch := sp[4]
		var f := sin(_t * (7.0 if breath else 2.2)) * (5.0 if breath else 3.0)
		var wr := ch + Vector2(8, -26 - f)
		var tips := [ch + Vector2(32, -40 - f), ch + Vector2(42, -20 - f * 0.6), ch + Vector2(30, -4)]
		var poly := PackedVector2Array([ch, wr])
		for tp: Vector2 in tips:
			poly.append(tp)
		draw_colored_polygon(poly, Color(0.3, 0.1, 0.46, 0.92))
		for i in tips.size() - 1:
			draw_line(tips[i], tips[i + 1], Color(vio, 0.8), 1.6)
		draw_line(ch, wr, bone, 3.0)
		for tp: Vector2 in tips:
			draw_line(wr, tp, bone, 1.8)
			draw_line(wr, tp, Color(vio, 0.5), 4.0)
		_glow(sp[5] + Vector2(0, 7), 20, Color(0.7, 0.35, 1.0, 0.8))
		draw_polyline(sp, Color(vio, 0.45), 8.0)
		draw_polyline(sp, Color(0.85, 0.65, 1.0, 0.8), 2.5)
		for i in range(3, 7):
			var p := sp[i]
			draw_arc(p + Vector2(0, 7), 8.0, -0.2, PI + 0.2, 8, bone, 2.0)
		draw_circle(sp[5] + Vector2(0, 8), 4.5, Color(0.85, 0.6, 1.0))
		for i in range(16, -1, -1):
			var r := 4.2 - 2.6 * i / 16.0
			if i < 3:
				r = 3.0
			draw_circle(sp[i], r, bone if i % 2 == 0 else old)
			draw_line(sp[i], sp[i] + Vector2(1.5, -r - 2.5), old, 1.4)
		var end := sp[16]
		var dir := (sp[16] - sp[15]).normalized()
		var nrm := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([end, end + nrm * 6 + dir * 4, end + dir * 12, end - nrm * 6 + dir * 4]), vio)
		_glow(end + dir * 5, 10, Color(vio, 0.7))
		# The skull: a long horned head facing left, a violet eye in a dark socket; the jaw
		# drops to breathe.
		var head := sp[0] + Vector2(-6, -6)
		var jaw := 0.6 if breath else 0.08
		for i in 2:
			draw_line(head + Vector2(2 - i * 2, -6 + i * 3), head + Vector2(20 - i * 3, -20 + i * 8), old, 3.0 - i)
		draw_colored_polygon(PackedVector2Array([head + Vector2(4, 3), head + Vector2(-22, 4 + jaw * 16), head + Vector2(-22, 8 + jaw * 16), head + Vector2(2, 9)]), old)
		draw_circle(head, 9.5, bone)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-3, -7), head + Vector2(-24, -1), head + Vector2(-25, 4), head + Vector2(-2, 6)]), bone)
		for i in 3:
			draw_line(head + Vector2(-8 - i * 5, 4), head + Vector2(-8 - i * 5, 7), Color(1, 1, 1), 1.4)
		draw_circle(head + Vector2(-3, -2), 3.8, dark)
		draw_circle(head + Vector2(-3, -2), 2.0, Color(0.9, 0.65, 1.0))
		_glow(head + Vector2(-3, -2), 6, Color(vio, 0.8))
		if breath:
			# Violet fire pouring from the jaws, a white-hot core in it.
			for i in 8:
				var k := fmod(_t * 2.5 + i / 8.0, 1.0)
				var p := head + Vector2(-26 - 30 * k, 6 + 16 * k + sin(i * 2.3) * 5.0 * k)
				var r := 3.0 + 9.0 * k
				draw_circle(p, r, Color(0.75, 0.45, 1.0, 0.55 * (1.0 - k)))
				draw_circle(p, r * 0.5, Color(0.97, 0.9, 1.0, 0.75 * (1.0 - k)))

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
