class_name LegendWings
extends Node3D
## Version 313 (Legend Vault, legends.gd): wings on the hero's back, held half folded and
## swept back, that spread wide and beat once when the hero dashes.
##   bone_wings:  Bone Wings. A bat's wing made of bones (arm, elbow, wrist and four long
##                finger bones) with torn dusk-violet skin stretched between them.
##   phoenix:     Phoenix Wings. Layers of long burning feathers, gold at the root and red at
##                the tips, shedding embers; a dash leaves a firebird of flame behind where it
##                started, which spreads its wings and fades.
## The wing's flat side leans back towards the run camera (above and behind the hero), so from
## up there it is seen spread, not edge on. On a pedestal they are shown spread and beating.

var kind := "bone_wings"

var _hero: Node3D   # (a Hero in a run; nothing on a pedestal)
var _l: Node3D
var _r: Node3D
var _t := 0.0
var _spread := 0.0   # 0 at rest (half folded, swept back), 1 spread wide
var _beat := 0.0
var _was_dashing := false
var _embers: CPUParticles3D

## The wing's shape, in its own flat plane (x out from the back, y up): the shoulder, the
## elbow, the wrist and the four finger tips; the skin runs from the shoulder round the
## fingers and back down to the hip.
const ELBOW := Vector2(0.42, 0.2)
const WRIST := Vector2(0.84, 0.36)
const FINGERS := [Vector2(1.42, 0.18), Vector2(1.32, -0.2), Vector2(1.06, -0.5), Vector2(0.64, -0.62)]
const HIP := Vector2(0.14, -0.42)


## Puts wings of `kind` on the hero inside CharacterVisual `visual`: on its upper back. (On the
## chest bone they hung from the waist and pointed at the floor: the KayKit chest bone is low
## and turned. The chunky heroes barely bend, so the wings sit on the visual itself.)
static func make(visual: Node3D, _model: Node3D, wing_kind: String) -> void:
	var w := LegendWings.new()
	w.kind = wing_kind
	w.name = "LegendWings"
	visual.add_child(w)
	w.position = Vector3(0, 1.22, 0.26)
	w.rotation.y = PI   # (the wings are made with the back towards their -Z)


func _ready() -> void:
	var p := get_parent()
	while p and not (p is CharacterVisual):
		p = p.get_parent()
	if p and p.get_parent() is Hero:
		_hero = p.get_parent() as Node3D
		scale = Vector3.ONE * 1.3   # (the run camera is far above: bigger there, as the pets)
	match kind:
		"phoenix":
			_l = _phoenix_wing(-1.0)
			_r = _phoenix_wing(1.0)
			_embers = _ember_fx()
			add_child(_embers)
		_:
			_l = _bone_wing(-1.0)
			_r = _bone_wing(1.0)
	_pose(0.0)


func _process(delta: float) -> void:
	_t += delta
	var dashing := _hero != null and is_instance_valid(_hero) and (_hero as Hero).is_dashing()
	if dashing and not _was_dashing:
		_beat = 1.0
		if kind == "phoenix" and _hero:
			_firebird()
	_was_dashing = dashing
	var want := 1.0 if (dashing or _beat > 0.0 or _hero == null) else 0.0
	_spread = move_toward(_spread, want, delta * (7.0 if want > _spread else 1.6))
	_beat = maxf(0.0, _beat - delta * 1.6)
	_pose(delta)


## The wings' pose: swept back and drooping at rest, breathing slowly; spread straight out to
## the sides and beating once in a dash.
func _pose(_delta: float) -> void:
	var s := smoothstep(0.0, 1.0, _spread)
	var breathe := sin(_t * 1.8) * 0.06
	var flap := sin((1.0 - _beat) * PI * 2.0) * 0.45 * _beat
	for side in [-1.0, 1.0]:
		var w: Node3D = _l if side < 0.0 else _r
		# y: swept back; z: raised; x: the flat side leaning back to face up and behind.
		if _hero == null:
			flap = sin(_t * 2.2) * 0.22   # (on a pedestal: slow, wide beats)
		w.rotation = Vector3(lerpf(-0.7, -0.4, s), side * lerpf(0.55, 0.12, s), side * (lerpf(0.28, 0.22, s) + breathe + flap))


# ---------------------------------------------------------------- Bone Wings

func _bone_wing(side: float) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.1 * side, 0, 0)
	add_child(w)
	var bone := LegendPet._mat("wing_bone", Color(0.92, 0.89, 0.8), 0.7)
	var knob := LegendPet._mat("wing_knob", Color(0.85, 0.8, 0.7), 0.7)
	var skin := LegendPet._mat("wing_skin", Color(0.32, 0.12, 0.42, 0.82), 0.6, Color(0.45, 0.15, 0.6), 0.5, true)
	# The skin first (it sits a hair behind the bones).
	var pts: Array[Vector2] = [Vector2.ZERO, ELBOW, WRIST]
	for i in FINGERS.size():
		var tip: Vector2 = FINGERS[i]
		pts.append(tip)
		var nxt: Vector2 = FINGERS[i + 1] if i + 1 < FINGERS.size() else HIP
		# Between two fingers the skin sags in towards the wrist, torn at the edge.
		var mid := (tip + nxt) * 0.5
		pts.append(mid.lerp(WRIST, 0.32 + 0.08 * (i % 2)))
	pts.append(HIP)
	var m := MeshInstance3D.new()
	m.mesh = _fan(pts, side, "bone")
	m.material_override = skin
	m.position.z = -0.01
	w.add_child(m)
	# The bones: arm, forearm and fingers, with round knuckles.
	_bone(w, Vector2.ZERO, ELBOW, 0.04, bone, side)
	_bone(w, ELBOW, WRIST, 0.035, bone, side)
	U.sphere(w, 0.06, knob, _v(ELBOW, side))
	U.sphere(w, 0.065, knob, _v(WRIST, side))
	for tip: Vector2 in FINGERS:
		_bone(w, WRIST, tip, 0.022, bone, side)
		var claw := LegendPet._tube(w, 0.0, 0.03, 0.1, bone, _v(tip, side))
		claw.rotation.z = atan2(tip.y - WRIST.y, (tip.x - WRIST.x) * side) - PI / 2.0
	# A hooked thumb claw at the wrist.
	var thumb := LegendPet._tube(w, 0.0, 0.035, 0.16, knob, _v(WRIST + Vector2(0.02, 0.1), side))
	thumb.rotation.z = -0.4 * side
	return w


static func _v(p: Vector2, side: float) -> Vector3:
	return Vector3(p.x * side, p.y, 0)


## A round bone from `a` to `b` in the wing's plane.
static func _bone(w: Node3D, a: Vector2, b: Vector2, r: float, m: Material, side: float) -> void:
	var from := _v(a, side)
	var to := _v(b, side)
	var len := from.distance_to(to)
	var t := LegendPet._tube(w, r, r * 0.8, len, m, (from + to) * 0.5)
	var d := (to - from).normalized()
	t.rotation.z = atan2(-d.x, d.y)


## A flat fan of triangles from the first point round the others, drawn on both sides.
static var _fans := {}


static func _fan(pts: Array[Vector2], side: float, key: String) -> Mesh:
	var k := "%s%d" % [key, int(side)]
	if _fans.has(k):
		return _fans[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3.ZERO
	for p: Vector2 in pts:
		c += _v(p, side)
	c /= pts.size()
	for i in pts.size():
		var a := _v(pts[i], side)
		var b := _v(pts[(i + 1) % pts.size()], side)
		for tri in [[c, a, b], [c, b, a]]:
			for v: Vector3 in tri:
				st.set_normal(Vector3(0, 0, 1))
				st.set_uv(Vector2(v.x * side / 1.5, -v.y))
				st.add_vertex(v)
	var mesh := st.commit()
	_fans[k] = mesh
	return mesh


# ---------------------------------------------------------------- Phoenix Wings

func _phoenix_wing(side: float) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.1 * side, 0, 0)
	add_child(w)
	var gold := LegendPet._mat("phx_gold", Color(1.0, 0.82, 0.35), 0.4, Color(1.0, 0.7, 0.2), 2.2)
	var orange := LegendPet._mat("phx_orange", Color(1.0, 0.5, 0.12), 0.4, Color(1.0, 0.42, 0.08), 2.6)
	var red := LegendPet._mat("phx_red", Color(0.9, 0.16, 0.06), 0.4, Color(1.0, 0.2, 0.05), 2.2)
	# A row of long flight feathers fanning out from the arm (red-tipped), a row of shorter
	# orange coverts over their roots, and gold down along the arm.
	for i in 9:
		var f := float(i) / 8.0
		var root := _v(Vector2(0.12 + 0.72 * f, 0.18 + 0.16 * f), side)
		var ang := lerpf(-1.3, 0.3, f)   # (from pointing down to pointing out and up)
		var length := lerpf(0.65, 1.05, f)
		var feather := Node3D.new()
		feather.position = root
		w.add_child(feather)
		var d := Vector3(side * cos(ang), sin(ang), 0)
		feather.rotation = Vector3(0, 0, atan2(-d.x, d.y) + PI)
		U.box(feather, Vector3(0.17, length * 0.7, 0.02), orange, Vector3(0, -length * 0.35, 0))
		var tipf := U.box(feather, Vector3(0.14, length * 0.34, 0.022), red, Vector3(0, -length * 0.83, 0))
		tipf.rotation.z = 0.12 * side   # (the tips curl a little, like flames)
	for i in 6:
		var f := float(i) / 5.0
		var root := _v(Vector2(0.1 + 0.7 * f, 0.22 + 0.15 * f), side)
		var c := U.box(w, Vector3(0.13, 0.3, 0.025), gold, root + Vector3(0, -0.1, 0.012))
		c.rotation.z = side * lerpf(0.5, -0.3, f)
	_bone(w, Vector2.ZERO, ELBOW, 0.05, gold, side)
	_bone(w, ELBOW, WRIST, 0.045, gold, side)
	# A soft fire-glow over the whole wing.
	var glow := MeshInstance3D.new()
	glow.mesh = LegendPet._quad(2.3)
	glow.material_override = LegendPet._add_mat(Color(1.0, 0.5, 0.15, 0.6), true)
	glow.position = _v(Vector2(0.75, 0.0), side)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(glow)
	return w


func _ember_fx() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 1.1
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.0, 0.3, 0.1)
	p.position = Vector3(0, -0.1, -0.05)
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	p.mesh = q
	var m := LegendPet._add_mat(Color(1.0, 0.6, 0.2, 1.0), true)
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.4, 1))
	g.set_color(1, Color(1, 0.2, 0.05, 0))
	p.color_ramp = g
	return p


## A dash leaves a firebird where it started: the spread wings drawn in flame, which rise,
## grow and fade over most of a second.
func _firebird() -> void:
	var world := _hero.get_parent() as Node3D
	if world == null:
		return
	var bird := Node3D.new()
	world.add_child(bird)
	bird.global_transform = global_transform
	bird.global_position = _hero.global_position + Vector3(0, 1.3, 0)
	var mats: Array[StandardMaterial3D] = []
	for side in [-1.0, 1.0]:
		var mat := LegendPet._add_mat(Color(1.0, 0.55, 0.15, 0.95), false)
		mats.append(mat)
		for i in 5:
			var f := float(i) / 4.0
			var q := MeshInstance3D.new()
			q.mesh = LegendPet._quad(0.7)
			q.material_override = mat
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.position = Vector3(side * (0.35 + 0.75 * f), 0.15 + 0.25 * sin(f * PI) - 0.2 * f, 0)
			q.scale = Vector3(1.0, 1.0 - 0.5 * f, 1.0)
			bird.add_child(q)
	var body := MeshInstance3D.new()
	body.mesh = LegendPet._quad(0.9)
	var bm := LegendPet._add_mat(Color(1.0, 0.8, 0.4, 1.0), false)
	mats.append(bm)
	body.material_override = bm
	body.scale = Vector3(0.6, 1.4, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bird.add_child(body)
	var tw := bird.create_tween().set_parallel(true)
	tw.tween_property(bird, "scale", Vector3.ONE * 1.5, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(bird, "global_position", bird.global_position + Vector3(0, 1.0, 0), 0.8)
	for m in mats:
		tw.tween_property(m, "albedo_color:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(bird.queue_free)
