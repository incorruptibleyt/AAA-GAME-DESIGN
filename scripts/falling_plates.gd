class_name FallingPlates
extends Node3D
## Version 288 (hard review fix 5, the Starfall Abyss's own danger): loose plates. Some of the
## moonstone plates of the Abyss's floor are cracked through, with starlight showing in the
## cracks. Step on one and it starts to give: it shakes and its cracks blaze, and a moment
## later it falls away into the void, leaving a hole full of stars for a few seconds before
## it floats back up. Whoever is on a plate as it falls, or walks into the hole, falls in:
## hurt, and climbing out at the edge. Skeletons fall too, and the void takes a third of their
## health. A dash carries you over a hole, and never makes a plate give.

const CELL := 1.25          # a plate's size
const GIVE := 0.75          # seconds from the first step to the fall
const GONE := 4.5           # seconds the hole stays open
const RISE := 0.6           # the plate floating back up
const DAMAGE := 4.5         # to the hero, before the floor's damage scale (about 22 on floor 10)
const FOE_SHARE := 0.35     # to skeletons: this share of their full health
const STAR := Color(0.75, 0.85, 1.0)

## Every plate in the room (the test robot keeps off them).
static var all: Array[FallingPlates] = []
static var _hole_mat: ShaderMaterial

var _plate: Node3D
var _crack_mat: StandardMaterial3D
var _hole: MeshInstance3D
var _state := 0             # 0 firm, 1 giving, 2 gone, 3 rising
var _t := 0.0
var _fell := {}             # actor -> seconds before it can fall again
var _said := false


## Lays loose plates on open floor in `room`: six to nine, alone or in pairs.
static func lay(room: Room) -> void:
	var want := randi_range(6, 9)
	var placed: Array[Vector3] = []
	for attempt in 120:
		if placed.size() >= want:
			break
		var p := Vector3(randi_range(-3, 3) * CELL, 0, randi_range(-5, 3) * CELL)
		if not _open(room, p, placed):
			continue
		placed.append(p)
		_add(room, p)
		# Sometimes a second plate beside it, so a crack runs across two.
		var q: Vector3 = p + [Vector3(CELL, 0, 0), Vector3(-CELL, 0, 0), Vector3(0, 0, CELL)][randi() % 3]
		if randf() < 0.4 and placed.size() < want and absf(q.x) < Room.HALF_W - 1.0 and _open(room, q, placed):
			placed.append(q)
			_add(room, q)


static func _add(room: Room, p: Vector3) -> void:
	var f := FallingPlates.new()
	f.name = "LoosePlate"
	room.add_child(f)
	f.position = p
	f._build()


static func _open(room: Room, p: Vector3, placed: Array[Vector3]) -> bool:
	for o: Dictionary in room.obstacles:
		if Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < float(o.r) + CELL:
			return false
	for s: Dictionary in room.spawns:
		if Vector2(p.x - s.pos.x, p.z - s.pos.z).length() < CELL:
			return false
	for q in placed:
		if q.distance_to(p) < CELL * 0.9:
			return false
	return true


## For the shader warm-up (warmup.gd): a plate and its hole that just sit there.
static func warm(parent: Node, at: Vector3) -> void:
	var f := FallingPlates.new()
	f.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(f)
	f.position = at
	f._build()
	f._hole.visible = true


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


## Whether `p` (a body `r` round) stands on this plate.
func covers(p: Vector3, r := 0.0) -> bool:
	var h := CELL * 0.5 + r
	return absf(p.x - global_position.x) < h and absf(p.z - global_position.z) < h


## Whether this plate is giving way or gone (for the test robot).
func unsafe() -> bool:
	return _state != 0


func _build() -> void:
	if _hole_mat == null:
		var sh := Shader.new()
		sh.code = HOLE
		_hole_mat = ShaderMaterial.new()
		_hole_mat.shader = sh
	# The hole under it: the void, full of stars, seen through the floor.
	_hole = U.floor_quad(self, Vector2(CELL * 0.98, CELL * 0.98), _hole_mat, Vector3(0, 0.012, 0))
	_hole.visible = false
	_plate = Node3D.new()
	add_child(_plate)
	var stone := U.mat(Color(0.3, 0.3, 0.4), 0.6)
	var slab := U.box(_plate, Vector3(CELL * 0.96, 0.08, CELL * 0.96), stone, Vector3(0, 0.0, 0))
	slab.rotation.y = randf_range(-0.04, 0.04)
	# Cracks of starlight across it: a few thin glowing bars, crossed.
	_crack_mat = U.unlit(Color(STAR.r, STAR.g, STAR.b, 0.8)).duplicate() as StandardMaterial3D
	_crack_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var a0 := randf() * PI
	for k in 3:
		var bar := U.box(_plate, Vector3(CELL * randf_range(0.55, 0.95), 0.012, 0.06), _crack_mat, Vector3(randf_range(-0.2, 0.2), 0.046, randf_range(-0.2, 0.2)))
		bar.rotation.y = a0 + k * randf_range(0.7, 1.3)
	# A dark edge all round, where it has come loose from its neighbours.
	var edge := U.mat(Color(0.05, 0.06, 0.1), 0.9)
	for s: float in [-1.0, 1.0]:
		U.box(_plate, Vector3(CELL, 0.02, 0.05), edge, Vector3(0, 0.035, s * CELL * 0.49))
		U.box(_plate, Vector3(0.05, 0.02, CELL), edge, Vector3(s * CELL * 0.49, 0.035, 0))


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	delta = minf(delta, Actor.MAX_STEP)
	for a in _fell.keys():
		_fell[a] -= delta
		if _fell[a] <= 0.0:
			_fell.erase(a)
	var playing := Game.state == Game.State.PLAYING
	match _state:
		0:
			_crack_mat.albedo_color.a = 0.7 + 0.2 * sin(Time.get_ticks_msec() * 0.002 + position.x)
			if playing and Game.fight_on() and _stepped():
				_state = 1
				_t = 0.0
				Sfx.play("crack", 0.45, 0.7)
				if not _said and Game.hero and covers(Game.hero.global_position, Game.hero.radius * 0.3):
					_said = true
					Game.hud.callout("THE FLOOR IS GIVING WAY! MOVE!", STAR, true)
		1:
			_t += delta
			var k := _t / GIVE
			_plate.position = Vector3(randf_range(-1, 1) * 0.03 * k, -0.04 * k, randf_range(-1, 1) * 0.03 * k)
			_crack_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.6 + 0.4 * k)
			if _t >= GIVE:
				_state = 2
				_t = 0.0
				_hole.visible = true
				Fx.dust(global_position, 16)
				Sfx.play("shatter", 0.5, 0.8)
				var tw := create_tween()
				tw.tween_property(_plate, "position", Vector3(0, -3.0, 0), 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				tw.parallel().tween_property(_plate, "rotation", Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), 0.5)
		2:
			_t += delta
			if playing:
				_swallow()
			if _t >= GONE:
				_state = 3
				_t = 0.0
				_plate.rotation = Vector3.ZERO
				_crack_mat.albedo_color = Color(STAR.r, STAR.g, STAR.b, 0.9)
		3:
			_t += delta
			var k := minf(_t / RISE, 1.0)
			_plate.position = Vector3(0, lerpf(-1.2, 0.0, ease(k, 0.4)), 0)
			if playing:
				_swallow()   # still a hole until it is back up
			if k >= 1.0:
				_state = 0
				_hole.visible = false
				_plate.position = Vector3.ZERO


## Someone (not dashing) is standing on the plate.
func _stepped() -> bool:
	var hero := Game.hero
	if hero and not hero.dead and not hero.is_dashing() and covers(hero.global_position, hero.radius * 0.3):
		return true
	for a: Actor in Actor.all:
		if a is Enemy and not (a as Enemy).is_boss and not a.dead and covers(a.global_position, -0.1):
			return true
	return false


## Everyone standing in the open hole falls in (a dash carries the hero over it).
func _swallow() -> void:
	for a: Actor in Actor.all.duplicate():
		if a.dead or _fell.has(a) or (a is Enemy and (a as Enemy).is_boss):
			continue
		if a is Hero and ((a as Hero).is_dashing() or not a.can_be_hit()):
			continue
		if not covers(a.global_position, -a.radius * 0.4):
			continue
		_fell[a] = 1.0
		# Out at the nearest edge, away from the middle of the hole.
		var d := a.global_position - global_position
		d.y = 0.0
		var out := Vector3(signf(d.x + 0.001), 0, 0) if absf(d.x) > absf(d.z) else Vector3(0, 0, signf(d.z + 0.001))
		var edge := global_position + out * (CELL * 0.5 + a.radius + 0.15)
		edge.x = a.global_position.x if out.x == 0.0 else edge.x
		edge.z = a.global_position.z if out.z == 0.0 else edge.z
		Fx.magic(a.center(), STAR, 14)
		if Room.current:
			a.global_position = Room.current.resolve_move(a.global_position, edge - a.global_position, a.radius)
		else:
			a.global_position = edge
		if a is Hero:
			Game.hit_source = "Fall into the void"
			a.take_damage(DAMAGE, out, 4.0)
			Game.buzz(60)
		else:
			a.take_damage(a.max_health * FOE_SHARE, out, 4.0)


## The void seen through a hole in the floor: deep blue-black, stars drifting, brighter
## towards the middle as if far below.
const HOLE := """
shader_type spatial;
render_mode unshaded, cull_back;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 q = UV * 14.0 + vec2(TIME * 0.15, TIME * 0.05);
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash(cell);
	float star = step(0.86, h) * smoothstep(0.18, 0.0, length(f - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6));
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	vec3 deep = mix(vec3(0.0, 0.0, 0.02), vec3(0.08, 0.06, 0.2), smoothstep(0.0, 0.5, edge));
	ALBEDO = deep + vec3(0.8, 0.88, 1.0) * star * (0.6 + 0.4 * sin(TIME * 3.0 + h * 40.0));
}
"""
