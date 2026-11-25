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
const DAMAGE := 6.0         # to the hero, before the floor's damage scale (about 22 on floor 8)
const FOE_SHARE := 0.4      # to skeletons: this share of their full health
const BRASS := Color(0.85, 0.66, 0.3)
const GLOW := Color(1.0, 0.82, 0.45)
const DELAY := 1.0          # the first rest is this much longer, while the skeletons climb out
## Version 306: the shortest stretch of rails worth laying when no row crosses the whole room.
const MIN_STRETCH := 3.5

var _ob: Dictionary         # the room obstacle this bookcase is: moved with it
var _case: Node3D
var _arrows: Array[MeshInstance3D] = []
var _arrow_mat: StandardMaterial3D
var _z := 0.0
var _x := 0.0
var _lo := 0.0              # where the bookcase stops at each end (its centre); v306: a short
var _hi := 0.0              # stretch may end at a pillar instead of the wall
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
		if lanes.size() >= int([1, 2 if randf() < 0.4 else 1, 2][mini(Game.danger_step(), 2)]):   # v297
			break
		if _lane_open(room, c, lanes):
			lanes.append(c)
	# Review fix 1 (build 295): a room whose rows were all near a skeleton's rising place got
	# no bookcase at all (floor 8 then had no danger). Then the lane may pass a rising place.
	if lanes.is_empty():
		for c in cands:
			if _lane_open(room, c, lanes, false):
				lanes.append(c)
				break
	# Version 306 (player panel fix 1): a room with cover in every row (the Bone Crypt's
	# graves, with the shelves as its guest danger past floor 10) still laid none, under a
	# "+ ROLLING SHELVES!" banner. Then the rails run along the longest open stretch of a
	# row, from a pillar to the wall or between two pillars.
	if lanes.is_empty():
		var best := Vector3(0, 0, 0)   # (z, lo, hi)
		for c in cands:
			var seg := _open_stretch(room, c)
			if seg.y - seg.x > best.z - best.y:
				best = Vector3(c, seg.x, seg.y)
		if best.z - best.y >= MIN_STRETCH:
			var s := RollingStacks.new()
			s.name = "RollingStacks"
			room.add_child(s)
			s._build(room, best.x, best.y, best.z)
		return
	for l in lanes:
		var s := RollingStacks.new()
		s.name = "RollingStacks"
		room.add_child(s)
		s._build(room, l)


## The longest stretch of the row at `z` that the bookcase can roll along without passing
## through cover: Vector2(lo, hi), the furthest its centre goes each way.
static func _open_stretch(room: Room, z: float) -> Vector2:
	var end := Room.HALF_W - R - 0.05
	var blocks: Array[Vector2] = []
	for o: Dictionary in room.obstacles:
		var r := float(o.r)
		if absf(float(o.pos.z) - z) < r + R + 0.3:
			blocks.append(Vector2(float(o.pos.x) - r - R - 0.1, float(o.pos.x) + r + R + 0.1))
	blocks.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var best := Vector2.ZERO
	var from := -end
	for b in blocks:
		if b.x > from and minf(b.x, end) - from > best.y - best.x:
			best = Vector2(from, minf(b.x, end))
		from = maxf(from, b.y)
	if end - from > best.y - best.x:
		best = Vector2(from, end)
	return best


static func _lane_open(room: Room, z: float, lanes: Array[float], mind_spawns := true) -> bool:
	for o: Dictionary in room.obstacles:
		if absf(float(o.pos.z) - z) < float(o.r) + R + 0.5:
			return false
	for s: Dictionary in room.spawns:
		if mind_spawns and absf(float(s.pos.z) - z) < 1.1:
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


func _build(room: Room, z: float, lo := -INF, hi := INF) -> void:
	_z = z
	_lo = maxf(lo, -_end())
	_hi = minf(hi, _end())
	_dir = 1.0 if randf() < 0.5 else -1.0
	_x = _lo if _dir > 0.0 else _hi
	_t = -DELAY
	_look(_hi - _lo + 2.0 * R + 0.1, (_lo + _hi) * 0.5)
	_case.position = Vector3(_x, 0, _z)
	_ob = {"pos": Vector3(_x, 0, _z), "r": R}
	room.obstacles.append(_ob)


func _end() -> float:
	return Room.HALF_W - R - 0.05


## Two brass rails across the room with sleepers between, a row of arrows between them, and
## the bookcase on iron wheels.
func _look(width: float, cx := 0.0) -> void:
	var brass := U.mat(BRASS, 0.35, 0.05)
	brass.metallic = 0.8
	for side: float in [-0.42, 0.42]:
		U.box(self, Vector3(width, 0.05, 0.07), brass, Vector3(cx, 0.025, _z + side))
	var dark := U.mat(Color(0.22, 0.14, 0.09), 0.9)
	var n := int(width / 0.7)
	for i in n:
		U.box(self, Vector3(0.12, 0.03, 1.05), dark, Vector3(cx - width * 0.5 + 0.35 + i * 0.7, 0.012, _z))
	_arrow_mat = U.unlit(Color(GLOW.r, GLOW.g, GLOW.b, 0.0)).duplicate() as StandardMaterial3D
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.36, 0.3, 0.02)
	var steps := int(width / 1.1)
	for i in steps:
		var mi := MeshInstance3D.new()
		mi.mesh = arrow
		mi.material_override = _arrow_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cx - width * 0.5 + 0.55 + i * 1.1, 0.04, _z)
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
		_t += delta * Game.danger_pace()   # v297: quicker later in the floor
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
				Game.danger_warn("shelves", "SHELVES!", "ROLLING SHELVES: they roll down the rails. Keep off!", GLOW)
		if _t >= REST:
			_t = 0.0
			_rolling = true
			_case.rotation.z = 0.0
			Sfx.play("slam", 0.35, 0.55)
		return
	_arrow_mat.albedo_color.a = 0.5
	var step := _dir * SPEED * delta
	var goal := _hi if _dir > 0.0 else _lo
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
		var face := (_hi if _dir > 0.0 else _lo) + _dir * (R + 0.05)   # the wall (or pillar) it stops at
		if ahead and _dir * (_ob.pos.x + _dir * m) > _dir * face - a.radius - 0.02:
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
