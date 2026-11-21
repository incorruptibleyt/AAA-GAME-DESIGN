class_name Snowball
extends Node3D
## A great snowball rolling down the hall (version 243, the Frostfall event): Krampus's
## Avalanche and the Snow Roller send them. It grows as it rolls, with bones rolled up in it,
## flattens the hero and any skeleton in its way (each only once) and bursts into snow at the
## wall or the end of its run. Not an Actor: nothing can stop it but getting out of the way.

const SNOW := Color(0.86, 0.9, 0.97)
const SKELETON_SHARE := 0.4   # of a skeleton's full health

var dir := Vector3.BACK
var speed := 8.0
var r0 := 0.45
var r1 := 0.9
var length := 10.0
var damage := 16.0
var source := "Snowball"
var _gone := 0.0
var _ball: Node3D
var _hit := {}


static var _mesh_cache: ArrayMesh


## Rolls a snowball from `from` along `d` for `run` metres, growing from radius `a` to `b`.
static func roll(from: Vector3, d: Vector3, spd: float, a: float, b: float, run: float, dmg: float, src: String) -> Snowball:
	if Room.current == null or Game.state != Game.State.PLAYING:
		return null
	var s := Snowball.new()
	s.dir = Vector3(d.x, 0, d.z).normalized()
	s.speed = spd
	s.r0 = a
	s.r1 = b
	s.length = run
	s.damage = dmg
	s.source = src
	Room.current.add_child(s)
	s.global_position = Vector3(from.x, 0, from.z)
	s._build()
	Sfx.play("slam", 0.35, 0.7)
	return s


func _build() -> void:
	_ball = Node3D.new()
	add_child(_ball)
	var m := MeshInstance3D.new()
	m.mesh = _mesh()
	_ball.add_child(m)
	var shadow := U.floor_quad(self, Vector2(2.2, 2.2), U.unlit(Color(0.0, 0.0, 0.05, 0.4), U.soft_circle()), Vector3(0, 0.04, 0))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_size(r0)


## A ball of snow (radius 1) with bones and a skull rolled up in it.
static func _mesh() -> ArrayMesh:
	if _mesh_cache:
		return _mesh_cache
	var snow := U.mat(SNOW, 0.6)
	var bone := U.mat(Color(0.84, 0.8, 0.68), 0.85)
	var dark := U.mat(Color(0.05, 0.04, 0.05), 1.0)
	var parts := []
	parts.append([Props._sphere(), Props._xf(Vector3.ZERO, Vector3.ONE), snow])
	# Lumps, so it rolls visibly.
	for i in 7:
		var a := Vector3(cos(i * 2.4), sin(i * 1.7) * 0.8, sin(i * 2.4)).normalized()
		parts.append([Props._sphere(), Props._xf(a * 0.82, Vector3.ONE * 0.35), snow])
	for i in 4:
		var a := Vector3(cos(i * 1.9 + 0.5), cos(i * 2.7), sin(i * 1.9 + 0.5)).normalized()
		var basis := Basis(Quaternion(Vector3.UP, a.cross(Vector3.RIGHT).normalized())) if a.cross(Vector3.RIGHT).length() > 0.01 else Basis.IDENTITY
		parts.append([Props._cone(0.06, 0.06, 0.7, 6), Transform3D(basis, a * 0.93), bone])
	var sk := Vector3(0.3, 0.5, 0.8).normalized() * 0.92
	parts.append([Props._sphere(), Props._xf(sk, Vector3.ONE * 0.22), bone])
	for ex in [-0.08, 0.08]:
		parts.append([Props._sphere(), Props._xf(sk * 1.18 + Vector3(ex, 0.03, 0), Vector3.ONE * 0.055), dark])
	_mesh_cache = Props._bake(parts)
	return _mesh_cache


func _set_size(r: float) -> void:
	_ball.scale = Vector3.ONE * r
	_ball.position.y = r


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	if Game.state != Game.State.PLAYING:
		_burst()
		return
	var step := speed * delta
	_gone += step
	var k := clampf(_gone / maxf(length, 0.1), 0.0, 1.0)
	var r := lerpf(r0, r1, k)
	_set_size(r)
	position += dir * step
	# Rolling: turn about the axis across the way it goes.
	var axis := dir.cross(Vector3.UP).normalized()
	_ball.rotate(-axis, step / maxf(r, 0.1))
	if randf() < delta * 14.0:
		Fx.dust(global_position + dir * r * 0.6, 3)
	_strike(r)
	var out := absf(position.x) > Room.HALF_W - r * 0.6 or absf(position.z) > Room.HALF_L - r * 0.4
	if _gone >= length or out:
		_burst()


func _strike(r: float) -> void:
	var hero := Game.hero
	if hero and not _hit.has(hero) and hero.can_be_hit():
		var d := hero.global_position - global_position
		d.y = 0.0
		if d.length() < r + hero.radius * 0.6:
			_hit[hero] = true
			Game.hit_source = source
			var side := d - dir * d.dot(dir)
			hero.take_damage(damage, (dir + side.normalized() * 0.8).normalized() if side.length() > 0.05 else dir, 9.0)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and not _hit.has(a) and not (a as Enemy).is_boss and a.can_be_hit():
			var e := a.global_position - global_position
			e.y = 0.0
			if e.length() < r + a.radius * 0.7:
				_hit[a] = true
				a.take_damage(a.max_health * SKELETON_SHARE, (dir + e.normalized()).normalized(), 7.0)


func _burst() -> void:
	if is_queued_for_deletion():
		return
	var r := _ball.scale.x if _ball else r0
	Fx.dust(global_position, 26)
	Fx.shockwave(global_position + Vector3.UP * 0.2, SNOW, r + 1.2)
	Fx.magic(global_position + Vector3.UP * r, SNOW, 14)
	Sfx.play("pff", 0.6, 0.8)
	queue_free()
