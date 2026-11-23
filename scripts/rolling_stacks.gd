class_name RollingStacks
extends Node3D
## Version 286 (hard review fix 5, the Whispering Library's own danger): rolling stacks. One
## of the library's free-standing bookcases (or two, in a long room) stands on brass rails that
## cross the room from wall to wall. It waits at one wall, its books rattle and glowing arrows
## run along the rails the way it will go, then it rolls across to the other wall. It is
## moving cover: it stops shots, yours and the skeletons', wherever it is. Anything in its way
## is pushed ahead of it, and whoever it pins against the wall is crushed (hurt and thrown out
## of the rails). That is true of skeletons too.

const SPEED := 2.3          # m/s while rolling
const REST := 2.6           # seconds at each wall
const RATTLE := 0.8         # the warning before it rolls (inside REST)
const R := 0.6              # as wide as a pillar (room obstacle radius)
const DAMAGE := 10.0        # to the hero, before the floor's damage scale
const FOE_SHARE := 0.4      # to skeletons: this share of their full health
const BRASS := Color(0.85, 0.66, 0.3)
const GLOW := Color(1.0, 0.82, 0.45)
const DELAY := 1.0          # the first rest is this much longer, while the skeletons climb out

var _ob: Dictionary         # the room obstacle this bookcase is: moved with it
var _case: Node3D
var _arrows: Array[MeshInstance3D] = []
var _arrow_mat: StandardMaterial3D
var _z := 0.0
var _x := 0.0
var _dir := 1.0             # the way it rolls next
var _t := 0.0
var _rolling := false
var _crushed := {}          # actor -> seconds it can't be crushed again
var _said := false


## Lays rolling stacks across open rows of `room` (rows clear of cover and of where the
## skeletons rise).
static func lay(room: Room) -> void:
	var lanes: Array[float] = []
	var cands: Array[float] = []
	var z := -4.5
	while z <= 3.8:
		cands.append(z)
		z += 0.5
	cands.shuffle()
	for c in cands:
		if lanes.size() >= (2 if randf() < 0.4 else 1):
			break
		if _lane_open(room, c, lanes):
			lanes.append(c)
	for l in lanes:
		var s := RollingStacks.new()
		s.name = "RollingStacks"
		room.add_child(s)
		s._build(room, l)


static func _lane_open(room: Room, z: float, lanes: Array[float]) -> bool:
	for o: Dictionary in room.obstacles:
		if absf(float(o.pos.z) - z) < float(o.r) + R + 0.5:
			return false
	for s: Dictionary in room.spawns:
		if absf(float(s.pos.z) - z) < 1.1:
			return false
	for l in lanes:
		if absf(l - z) < 4.0:
			return false
	return true


## For the shader warm-up (warmup.gd): a bookcase on its rails that just stands there.
static func warm(parent: Node, at: Vector3) -> void:
	var s := RollingStacks.new()
	s.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(s)
	s.position = at
	s._look(3.0)


func _build(room: Room, z: float) -> void:
	_z = z
	_dir = 1.0 if randf() < 0.5 else -1.0
	_x = -_dir * _end()
	_t = -DELAY
	_look(Room.HALF_W * 2.0)
	_case.position = Vector3(_x, 0, _z)
	_ob = {"pos": Vector3(_x, 0, _z), "r": R}
	room.obstacles.append(_ob)


func _end() -> float:
	return Room.HALF_W - R - 0.05


## Two brass rails across the room with sleepers between, a row of arrows between them, and
## the bookcase on iron wheels.
func _look(width: float) -> void:
	var brass := U.mat(BRASS, 0.35, 0.05)
	brass.metallic = 0.8
	for side: float in [-0.42, 0.42]:
		U.box(self, Vector3(width, 0.05, 0.07), brass, Vector3(0, 0.025, _z + side))
	var dark := U.mat(Color(0.22, 0.14, 0.09), 0.9)
	var n := int(width / 0.7)
	for i in n:
		U.box(self, Vector3(0.12, 0.03, 1.05), dark, Vector3(-width * 0.5 + 0.35 + i * 0.7, 0.012, _z))
	_arrow_mat = U.unlit(Color(GLOW.r, GLOW.g, GLOW.b, 0.0)).duplicate() as StandardMaterial3D
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.36, 0.3, 0.02)
	var steps := int(width / 1.1)
	for i in steps:
		var mi := MeshInstance3D.new()
		mi.mesh = arrow
		mi.material_override = _arrow_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(-width * 0.5 + 0.55 + i * 1.1, 0.04, _z)
		mi.rotation = Vector3(-PI / 2, 0, -PI / 2)   # lying flat, pointing +X
		add_child(mi)
		_arrows.append(mi)
	_case = Node3D.new()
	add_child(_case)
	_case.position = Vector3(0, 0, _z)
	var body := MeshInstance3D.new()
	body.mesh = Props.bookcase_column()
	body.position.y = 0.12
	body.scale = Vector3(1.0, 0.92, 1.0)
	_case.add_child(body)
	var iron := U.mat(Color(0.15, 0.14, 0.15), 0.5)
	for x: float in [-0.36, 0.36]:
		for zz: float in [-0.42, 0.42]:
			var w := U.cylinder(_case, 0.11, 0.06, iron, Vector3(x, 0.11, zz))
			w.rotation.x = PI / 2


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED or _ob.is_empty():
		return
	delta = minf(delta, Actor.MAX_STEP)
	for a in _crushed.keys():
		_crushed[a] -= delta
		if _crushed[a] <= 0.0:
			_crushed.erase(a)
	if not (Game.state == Game.State.PLAYING and Game.fight_on()):
		_arrow_mat.albedo_color.a = move_toward(_arrow_mat.albedo_color.a, 0.12, delta * 2.0)
		_case.rotation.z = 0.0
		return
	if not _rolling:
		_t += delta
		var warn := _t - (REST - RATTLE)
		_arrow_mat.albedo_color.a = 0.15
		if warn > 0.0:
			if warn <= delta:
				Sfx.play("door", 0.35, 0.6)   # the books rattle
			# Its books rattle, and arrows light along the rails the way it will go.
			_case.rotation.z = sin(_t * 60.0) * 0.012
			_arrow_mat.albedo_color.a = 0.35 + 0.35 * sin(_t * 18.0)
			for m in _arrows:
				m.rotation.z = -PI / 2 if _dir > 0.0 else PI / 2
			if not _said:
				_said = true
				Game.hud.callout("THE SHELVES ROLL! KEEP OFF THE RAILS!", GLOW, true)
		if _t >= REST:
			_t = 0.0
			_rolling = true
			_case.rotation.z = 0.0
			Sfx.play("slam", 0.35, 0.55)
		return
	_arrow_mat.albedo_color.a = 0.5
	var step := _dir * SPEED * delta
	var goal := _dir * _end()
	var nx := move_toward(_x, goal, absf(step))
	var moved := nx - _x
	_x = nx
	_case.position.x = _x
	_ob.pos = Vector3(_x, 0, _z)
	_shove(moved)
	if is_equal_approx(_x, goal):
		_rolling = false
		_dir = -_dir
		Sfx.play("slam", 0.5, 0.7)
		Game.shake(0.12)


## Pushes everything it rolls into ahead of it; whoever is pinned on the wall is crushed.
func _shove(moved: float) -> void:
	if Room.current == null:
		return
	for a: Actor in Actor.all.duplicate():
		if a.dead or (a is Enemy and (a as Enemy).is_boss):
			continue
		var d: Vector3 = a.global_position - _ob.pos
		d.y = 0.0
		var m := R + a.radius
		if d.length_squared() >= m * m:
			continue
		# Only what is in front of it is pushed (what is beside the rails slides off).
		if d.x * _dir < -0.05 and absf(d.z) < m * 0.8:
			continue
		var ahead := absf(d.z) < m * 0.75
		if ahead and absf(_ob.pos.x + _dir * m) > Room.HALF_W - a.radius - 0.02:
			# Nowhere left to go: pinned on the wall.
			if not _crushed.has(a) and a.can_be_hit():
				_crush(a)
			else:
				a.global_position = Room.current.resolve_move(a.global_position, Vector3(0, 0, signf(d.z + 0.001)) * 0.3, a.radius)
			continue
		var to := Vector3(_ob.pos.x + _dir * (m + 0.02), 0, a.global_position.z) if ahead else a.global_position
		a.global_position = Room.current.resolve_move(a.global_position, to - a.global_position, a.radius)


func _crush(a: Actor) -> void:
	_crushed[a] = 1.0
	var out := Vector3(0, 0, signf(a.global_position.z - _z + 0.001))
	a.global_position = Room.current.resolve_move(a.global_position, out * (R + a.radius + 0.5), a.radius)
	Fx.impact(a.global_position + Vector3.UP, GLOW, 1.5)
	Sfx.play("crack", 0.7, 0.8)
	if a is Hero:
		Game.hit_source = "Rolling shelves"
		a.take_damage(DAMAGE, out, 8.0)
		Game.buzz(50)
	else:
		a.take_damage(a.max_health * FOE_SHARE, out, 6.0)


## Whether `p` is on the rails of a bookcase about to roll or rolling (for the test robot).
static func danger_at(p: Vector3) -> RollingStacks:
	if Room.current == null:
		return null
	for c in Room.current.get_children():
		if c is RollingStacks:
			var s := c as RollingStacks
			if (s._rolling or s._t > REST - RATTLE) and absf(p.z - s._z) < R + 0.8:
				return s
	return null
