class_name LegendPet
extends Node3D
## Version 312 (Legend Vault, legends.gd): a pet that goes everywhere with the hero. Built from
## simple shapes, at a size the run camera far above can read (the hero is 2.1 m tall):
##   wisp:  Lantern Wisp. A little ghost with big eyes and a lantern swinging from its hand;
##          the lantern throws a warm pool of light on the floor under it.
##   raven: Crypt Raven. A black raven with a bone-white bird skull for a head, violet eyes
##          and violet-tipped wings. It circles over the hero while there are skeletons about
##          and lands on their shoulder to rest when the room is clear (and on the title).
##   mimic: Mimic. A treasure chest with fangs and a tongue. It hops after the hero, chomps
##          now and then, and snaps at the nearest skeleton.
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
const RUN_SIZE := {"wisp": 1.45, "raven": 1.2, "mimic": 1.3}

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


func _ready() -> void:
	_anchor = get_parent() as Node3D
	_staged = get_viewport() is SubViewport
	top_level = not _staged
	_body = Node3D.new()
	add_child(_body)
	match kind:
		"raven":
			_build_raven()
		"mimic":
			_build_mimic()
		_:
			_build_wisp()
	if not _staged:
		# In a run the camera is far above: the pet is drawn bigger there than on a pedestal.
		_body.scale = Vector3.ONE * float(RUN_SIZE.get(kind, 1.3))
	_base_scale = _body.scale
	_place_now()


func _place_now() -> void:
	if _staged:
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
		if global_position.distance_to(a) > 9.0:
			_place_now()   # a new room: it is there with the hero at once
	match kind:
		"raven":
			_raven(delta)
		"mimic":
			_mimic(delta)
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
	var bone := _mat("raven_bone", Color(0.94, 0.92, 0.86), 0.7)
	var feather := _mat("raven_feather", Color(0.09, 0.08, 0.12), 0.45)
	var sheen := _mat("raven_sheen", Color(0.2, 0.15, 0.3), 0.4)
	var black := _mat("raven_black", Color(0.05, 0.04, 0.06), 0.6)
	var violet := _mat("raven_eye", Color(0.75, 0.45, 1.0), 0.3, Color(0.7, 0.4, 1.0), 4.0)
	var tip := _mat("raven_tip", Color(0.6, 0.35, 0.95), 0.4, Color(0.55, 0.3, 0.95), 1.6)
	var body := _sphere(_body, 0.19, feather, Vector3(0, 0, 0.02))
	body.scale = Vector3(0.95, 0.9, 1.55)
	var chest := _sphere(_body, 0.15, sheen, Vector3(0, -0.03, -0.17))
	chest.scale = Vector3(1.0, 1.0, 1.1)
	# A ruff of ragged neck feathers where the skull meets the body.
	for i in 5:
		var a := -0.9 + i * 0.45
		var r := U.box(_body, Vector3(0.07, 0.03, 0.14), feather, Vector3(sin(a) * 0.12, 0.1, -0.2 + cos(a) * 0.03))
		r.rotation = Vector3(-0.5, a, 0)
	# The head is a bird's skull: white bone, dark sockets with violet eyes, a black beak.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.12, -0.3)
	_body.add_child(_head)
	var skull := _sphere(_head, 0.13, bone, Vector3.ZERO)
	skull.scale = Vector3(0.95, 0.95, 1.15)
	for side in [-1.0, 1.0]:
		_sphere(_head, 0.05, black, Vector3(0.075 * side, 0.025, -0.06))
		_sphere(_head, 0.026, violet, Vector3(0.09 * side, 0.03, -0.075))
	var beak := _tube(_head, 0.055, 0.0, 0.24, black, Vector3.ZERO)
	beak.rotation.x = PI / 2.0
	beak.position = Vector3(0, -0.015, -0.24)
	beak.scale = Vector3(1.0, 1.0, 0.75)
	# Wings: a long bone-white arm of feathers with black finger feathers at the tip.
	_wing_l = _wing(-1.0, feather, sheen, tip)
	_wing_r = _wing(1.0, feather, sheen, tip)
	# A fan of tail feathers, black-tipped.
	for i in 3:
		var f := Node3D.new()
		f.position = Vector3(0, 0.02, 0.24)
		f.rotation.y = (i - 1) * 0.32
		_body.add_child(f)
		U.box(f, Vector3(0.09, 0.025, 0.24), feather, Vector3(0, 0, 0.12))
		U.box(f, Vector3(0.08, 0.026, 0.09), tip, Vector3(0, 0, 0.27))
	# Legs, for perching.
	for side in [-1.0, 1.0]:
		U.box(_body, Vector3(0.025, 0.14, 0.025), black, Vector3(0.06 * side, -0.2, -0.04))
	# A faint violet light about it, so a black bird still stands out on a dark floor.
	var glow := MeshInstance3D.new()
	glow.mesh = _quad(1.3)
	glow.material_override = _add_mat(Color(0.55, 0.3, 1.0, 0.32), true)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(glow)
	_body.position.y = 1.5


func _wing(side: float, feather: Material, sheen: Material, tip: Material) -> Node3D:
	var w := Node3D.new()
	w.position = Vector3(0.13 * side, 0.07, -0.08)
	_body.add_child(w)
	U.box(w, Vector3(0.36, 0.05, 0.26), feather, Vector3(0.18 * side, 0, 0.02))
	U.box(w, Vector3(0.34, 0.055, 0.08), sheen, Vector3(0.18 * side, 0.004, -0.09))   # (the leading edge)
	var outer := Node3D.new()
	outer.position = Vector3(0.34 * side, 0, 0.0)
	outer.rotation.y = -0.25 * side
	w.add_child(outer)
	U.box(outer, Vector3(0.26, 0.045, 0.22), feather, Vector3(0.13 * side, 0, 0.03))
	# Long finger feathers, black with glowing violet tips.
	for i in 4:
		var f := U.box(outer, Vector3(0.22, 0.035, 0.06), feather, Vector3((0.3 + 0.02 * i) * side, 0, -0.06 + i * 0.065))
		f.rotation.y = (0.12 - 0.18 * i) * side
		U.box(f, Vector3(0.07, 0.04, 0.062), tip, Vector3(0.12 * side, 0, 0))
	return w


func _raven(delta: float) -> void:
	var a := Vector3.ZERO if _staged else _anchor.global_position
	var hb := Basis.IDENTITY if _staged else _anchor.global_basis.orthonormalized()
	var shoulder := a + hb * Vector3(0.5, 1.38, 0.02)
	if _staged:
		# On a pedestal it hovers beside the hero, turned to fly towards them and the camera,
		# so its wings beat up and down beside the hero (face on, they crossed the hero's face).
		position = Vector3(-1.05, 0, -0.35)
		_body.position = Vector3(0, 1.5 + sin(_t * 1.6) * 0.08, 0)
		_body.scale = Vector3.ONE * 1.15
		_turn_to(-PI / 2.0 + 0.55 + sin(_t * 0.7) * 0.15, delta, 3.0)
		_body.rotation.x = 0.1
		_body.rotation.z = sin(_t * 0.9) * 0.1
		var hover := sin(_t * 6.0) * 0.7
		_wing_l.rotation = Vector3(0, 0, -hover)
		_wing_r.rotation = Vector3(0, 0, hover)
		return
	elif _still > 1.0 and Game.alive_enemies <= 0:
		_land = move_toward(_land, 1.0, delta * 1.3)   # (in a fight the hero stands still to shoot)
	else:
		_land = move_toward(_land, 0.0, delta * 2.4)
	var k := smoothstep(0.0, 1.0, _land)
	# Flying: wide circles over the hero, rising and falling a little.
	var speed_turn := 1.9
	_orbit += delta * speed_turn
	var r := 1.35
	var fly := a + Vector3(cos(_orbit) * r, 2.5 + sin(_orbit * 2.0) * 0.18, sin(_orbit) * r)
	var tangent := Vector3(-sin(_orbit), 0, cos(_orbit))
	# On the way down it swoops in an arc rather than sliding.
	var p := fly.lerp(shoulder, k) + Vector3.UP * sin(k * PI) * 0.45
	position = a
	_body.position = p - a
	var face := _yaw_of(tangent) if k < 0.5 else hb.get_euler().y
	_turn_to(face, delta, 5.0 if k < 0.5 else 8.0)
	_body.rotation.z = lerpf(0.38, 0.0, k)   # leaning into the turn
	# Wings: flapping, with a glide now and then; folded along the back when perched.
	var glide := smoothstep(0.3, 0.7, sin(_t * 0.9))
	var flap := sin(_t * 11.0) * lerpf(0.75, 0.12, glide) + 0.1 * glide
	var fold := k
	if fold > 0.95:
		_look += delta
		# Perched: now and then it stretches its wings, and it looks about.
		var stretch := smoothstep(0.0, 0.3, fmod(_look, 6.0) - 4.6) * (1.0 - smoothstep(0.0, 0.3, fmod(_look, 6.0) - 5.4))
		fold = 1.0 - stretch * 0.8
		flap = stretch * (0.4 + sin(_t * 9.0) * 0.25)
		_head.rotation.y = sin(_t * 1.1) * 0.55
		_head.rotation.x = sin(_t * 2.3) * 0.12
	else:
		_head.rotation = Vector3.ZERO
	_wing_l.rotation = Vector3(0, 1.35 * fold, -flap * (1.0 - fold) - 0.3 * fold)
	_wing_r.rotation = Vector3(0, -1.35 * fold, flap * (1.0 - fold) + 0.3 * fold)
	for w: Node3D in [_wing_l, _wing_r]:
		w.scale.x = lerpf(1.0, 0.5, fold)   # (folded, the long feathers lie over each other)


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
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en.dead:
			continue
		var dd := global_position.distance_to(en.global_position)
		if dd < best_d:
			best_d = dd
			best = en
	return best


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
			var tip := Vector2(48 * s, -14 + y - f)
			draw_colored_polygon(PackedVector2Array([Vector2(4 * s, -6 + y), tip, Vector2(40 * s, 4 + y - f * 0.6), Vector2(6 * s, 10 + y)]), feather)
			draw_colored_polygon(PackedVector2Array([tip, Vector2(36 * s, -8 + y - f * 0.85), Vector2(42 * s, 0 + y - f * 0.7)]), tipc)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 18 + y), Vector2(8, 18 + y), Vector2(12, 36 + y), Vector2(-12, 36 + y)]), feather)
		_ellipse(Vector2(0, 6 + y), 11, 20, feather)
		draw_circle(Vector2(0, -16 + y), 11, bone)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -12 + y), Vector2(4, -12 + y), Vector2(0, 4 + y)]), black)
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(5 * s, -19 + y), 3.5, black)
			draw_circle(Vector2(5 * s, -19 + y), 1.8, Color(0.8, 0.5, 1.0))

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
