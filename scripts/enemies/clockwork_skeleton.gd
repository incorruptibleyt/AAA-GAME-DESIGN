class_name ClockworkSkeleton
extends Enemy
## The Clockwork Foundry's own skeleton (floor 9, version 270; hard review of build 267,
## fix 3). Until then the Foundry borrowed the Grotto's Sporelings beside its Cinder
## Skeletons (its stokers, who stay).
##
## A skeleton of brass-capped bones with a big wind-up key in its back, a cog on its chest
## and a little smokestack on its skull. It stops, the key whirs round and its path lights
## up: a strip to the hero that runs on to the wall, then bounces off it. Then it charges the
## whole path, bounce and all. Step off both strips. When it has run down it stands unwound
## for a moment, key still, taking half as much again from every hit: that is the time to
## punish it.

const WIND := 1.1        # seconds of winding (the warning)
const SPEED := 13.0      # how fast it charges, m/s
const UNWOUND := 1.7     # seconds it stands run down after a charge
const BRASS := Color(1.0, 0.72, 0.3)

enum Mode { APPROACH, WIND, CHARGE, UNWOUND }

static var _meshes := {}

var _mode := Mode.APPROACH
var _timer := randf_range(1.2, 2.2)
var _path: Array[Vector3] = []   # the points it charges through, after its own spot
var _leg := 0
var _key: Node3D
var _stack: Node3D
var _key_speed := 2.0
var _base_contact := 10.0


func _setup() -> void:
	die_sound = "die_clock"
	init_health(64.0)
	move_speed = 2.0
	contact_damage = _base_contact
	radius = 0.55
	center_height = 1.1
	knockback_scale = 0.5
	var look := bones(Art.SKELETON_WARRIOR, 2.2, Color(1.0, 0.6, 0.2))
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Cloak"]
	look.overlay = _brass()
	make_visual(look)
	_dress()


func display_name() -> String:
	return "Clockwork Skeleton"


# --- How it looks ----------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	var k := "clockwork_" + key
	if not _meshes.has(k):
		match key:
			"brass": _meshes[k] = U.mat(Color(0.95, 0.68, 0.28), 0.3, 0.25)
			"copper": _meshes[k] = U.mat(Color(0.78, 0.4, 0.22), 0.35, 0.1)
			"iron": _meshes[k] = U.mat(Color(0.22, 0.22, 0.25), 0.55)
			"glow": _meshes[k] = U.mat(Color(1.0, 0.55, 0.15), 0.4, 2.4)
	return _meshes[k]


## Bone gone dark as old iron, with a brass-hot edge, so the bright brass key, cog and
## smokestack stand out on it (drawn over the whole skeleton: darken, then the edge).
static func _brass() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
void fragment() {
	ALBEDO = vec3(0.5, 0.46, 0.42);
}
"""
	var edge := Shader.new()
	edge.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = vec3(1.0, 0.62, 0.2) * rim * 0.55;
}
"""
	var m := ShaderMaterial.new()
	m.shader = dark
	var f := ShaderMaterial.new()
	f.shader = edge
	m.next_pass = f
	_meshes["overlay"] = m
	return m


## A segment from a to b of a cone, `ra` thick at a and `rb` at b.
static func _rod(a: Vector3, b: Vector3, ra: float, rb: float, sides := 8) -> Array:
	var d := b - a
	var c := Props._cone(rb, ra, d.length(), sides)
	var basis := Basis(Quaternion(Vector3.UP, d.normalized())) if d.normalized().cross(Vector3.UP).length() > 0.001 else Basis.IDENTITY
	return [c, Transform3D(basis, (a + b) * 0.5)]


## A flat cog, lying in the XZ plane: `teeth` teeth round a rim of radius `r`.
static func _cog_slab(r: float, teeth: int, thick: float) -> ArrayMesh:
	var poly := []
	for i in teeth:
		var a0 := TAU * i / teeth
		var w := TAU / teeth
		for p in [[0.0, r], [0.18, r], [0.28, r * 1.28], [0.62, r * 1.28], [0.72, r], [1.0, r]]:
			var a: float = a0 + w * float(p[0])
			poly.append(Vector2(cos(a), sin(a)) * float(p[1]))
	return Props._poly_slab(poly, -thick * 0.5, thick * 0.5)


## The wind-up key: a shaft into its back and a bow of two big loops, standing up.
static func _key_mesh() -> ArrayMesh:
	if _meshes.has("key"):
		return _meshes["key"]
	var parts := []
	# The shaft runs back along -Z from the spine; the bow turns round that axis.
	parts.append(_rod(Vector3(0, 0, 0.1), Vector3(0, 0, -0.5), 0.07, 0.07) + [_mat("brass")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0, -0.5), Vector3.ONE * 0.11), _mat("brass")])
	for side in [-1.0, 1.0]:
		var loop := TorusMesh.new()
		loop.inner_radius = 0.17
		loop.outer_radius = 0.29
		loop.rings = 16
		loop.ring_segments = 6
		# Each loop stands in the XY plane (a torus lies in XZ, so tip it up about X).
		parts.append([loop, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 0.33, 0, -0.53)), _mat("brass")])
	_meshes["key"] = Props._bake(parts)
	return _meshes["key"]


## A little smokestack on its skull, with a copper band and a glowing mouth.
static func _stack_mesh() -> ArrayMesh:
	if _meshes.has("stack"):
		return _meshes["stack"]
	var parts := []
	parts.append([Props._cone(0.1, 0.13, 0.42, 10), Props._xf(Vector3(0, 0.21, 0), Vector3.ONE), _mat("iron")])
	parts.append([Props._cone(0.16, 0.11, 0.1, 10), Props._xf(Vector3(0, 0.45, 0), Vector3.ONE), _mat("iron")])
	parts.append([Props._cone(0.135, 0.135, 0.06, 10), Props._xf(Vector3(0, 0.12, 0), Vector3.ONE), _mat("copper")])
	parts.append([Props._cone(0.12, 0.12, 0.012, 10), Props._xf(Vector3(0, 0.5, 0), Vector3.ONE), _mat("glow")])
	_meshes["stack"] = Props._bake(parts)
	return _meshes["stack"]


## A brass cog on its chest with a glowing hub.
static func _chest_cog() -> ArrayMesh:
	if _meshes.has("cog"):
		return _meshes["cog"]
	var parts := []
	# Stood up facing forward (+Z): the slab lies in XZ, so turn it about X.
	parts.append([_cog_slab(0.19, 9, 0.05), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), _mat("brass")])
	parts.append([Props._cone(0.07, 0.07, 0.07, 10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.02)), _mat("glow")])
	_meshes["cog"] = Props._bake(parts)
	return _meshes["cog"]


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		_key = Node3D.new()
		_key.position = Vector3(0, 0.42, -0.3)
		chest.add_child(_key)
		var key := MeshInstance3D.new()
		key.mesh = _key_mesh()
		_key.add_child(key)
		var cog := MeshInstance3D.new()
		cog.mesh = _chest_cog()
		cog.position = Vector3(0, 0.3, 0.33)
		chest.add_child(cog)
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		_stack = MeshInstance3D.new()
		(_stack as MeshInstance3D).mesh = _stack_mesh()
		_stack.position = Vector3(0.08, 0.82, -0.05)
		_stack.rotation.z = -0.18
		head.add_child(_stack)


# --- How it fights ---------------------------------------------------------------------------

## Unwound, it takes half as much again from every hit.
func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if _mode == Mode.UNWOUND:
		amount *= 1.5
	super.take_damage(amount, direction, push, crit)


func _process(delta: float) -> void:
	super._process(delta)
	if dead or _key == null:
		return
	var want := 2.0
	match _mode:
		Mode.WIND: want = 16.0
		Mode.CHARGE: want = 9.0
		Mode.UNWOUND: want = 0.0
	_key_speed = lerpf(_key_speed, want, 1.0 - exp(-5.0 * delta))
	_key.rotation.z += _key_speed * delta


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	_timer -= delta
	match _mode:
		Mode.APPROACH:
			if to.length() > 5.5:
				walk(to, delta)
			else:
				stand(delta)
				face(to, 8.0, delta)
			if _timer <= 0.0 and to.length() < 8.0:
				_wind(to)
		Mode.WIND:
			stand(delta)
			if not _path.is_empty():
				face(_path[0] - global_position, 20.0, delta)
			if randf() < delta * 8.0 and _stack:
				Fx.dust(_stack.global_position + Vector3.UP * 0.3, 1)
			if _timer <= 0.0:
				_mode = Mode.CHARGE
				_leg = 0
				_timer = 2.5   # never charges forever
				visual.attack()
				contact_damage = 18.0 * elite_mult()
				swipe_time = 0.0   # the strips were the warning: touching it hurts at once
				Sfx.play("dash", 0.9, 0.7)
		Mode.CHARGE:
			_charge(delta)
		Mode.UNWOUND:
			stand(delta)
			# Run down: steam sighs out of its smokestack and sparks fizz off it.
			if randf() < delta * 7.0 and _stack:
				Fx.dust(_stack.global_position + Vector3.UP * 0.35, 1)
			if randf() < delta * 3.0:
				Fx.magic(center() + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), randf_range(-0.4, 0.4)), BRASS, 2)
			if _timer <= 0.0:
				_mode = Mode.APPROACH
				_timer = randf_range(1.6, 2.4)


## Stop, wind the key and light up the path: to the hero, on to the wall, and off it.
func _wind(to: Vector3) -> void:
	_mode = Mode.WIND
	_timer = WIND
	contact_damage = 0.0
	var d := to.normalized() if to.length() > 0.1 else Vector3.FORWARD
	var a := global_position
	var b := _march(a, d, 11.0)
	_path = [b]
	var d2 := _bounce(b, d)
	var c := _march(b, d2, 6.0)
	if c.distance_to(b) > 0.8:
		_path.append(c)
	var from := a
	var dir := d
	for p in _path:
		var seg := p - from
		seg.y = 0.0
		if seg.length() > 0.2:
			track(Telegraph.line(from, seg.normalized(), seg.length() + 0.5, 1.1, WIND, Callable(), 0.5 if from == a else 0.0))
		from = p
	Sfx.play("tick", 0.8, 1.4)
	Fx.magic(center() + Vector3.UP * 0.4, BRASS, 6)


## How far it can run from `from` along `dir` before a wall or a pillar stops it.
func _march(from: Vector3, dir: Vector3, most: float) -> Vector3:
	var room := Room.current
	var p := from
	var step := 0.25
	var gone := 0.0
	while gone < most:
		var n := p + dir * step
		if room and not room.is_walkable(n, radius):
			break
		p = n
		gone += step
	return p


## Which way it goes on after hitting what stopped it: the blocked side turns round.
func _bounce(at: Vector3, d: Vector3) -> Vector3:
	var room := Room.current
	if room == null:
		return -d
	var bx := not room.is_walkable(at + Vector3(signf(d.x) * 0.3, 0, 0), radius)
	var bz := not room.is_walkable(at + Vector3(0, 0, signf(d.z) * 0.3), radius)
	var out := d
	if bx:
		out.x = -out.x
	if bz:
		out.z = -out.z
	if not bx and not bz:
		out = -d
	return out.normalized()


func _charge(delta: float) -> void:
	if _leg >= _path.size() or _timer <= 0.0:
		_run_down()
		return
	var goal := _path[_leg]
	var to := goal - global_position
	to.y = 0.0
	var step := SPEED * delta
	if to.length() <= step + 0.05:
		var before := global_position
		move_by(to, delta)
		_leg += 1
		if _leg < _path.size():
			# It hits the wall and bounces: a clang and sparks.
			Sfx.play("slam", 0.5, 1.5)
			Fx.impact(goal + Vector3.UP * 0.8, BRASS)
			Game.shake(0.12)
		elif (global_position - before).length() < 0.01:
			_run_down()
		return
	var before := global_position
	move_by(to.normalized() * step, delta)
	face(to, 30.0, delta)
	visual.set_moving(true)
	if (global_position - before).length() < step * 0.2:
		_leg += 1   # something in the way (another skeleton): on to the next leg


## Run down: it stands unwound for a moment, the key still.
func _run_down() -> void:
	_mode = Mode.UNWOUND
	_timer = UNWOUND
	contact_damage = _base_contact * elite_mult()
	swipe_time = 0.55
	_path.clear()
	visual.set_moving(false)
	Fx.dust(global_position, 10)
	Sfx.play("tick", 0.5, 0.6)


func _on_death() -> void:
	super._on_death()
	Fx.impact(center(), BRASS)
	Fx.magic(center(), BRASS, 12)
