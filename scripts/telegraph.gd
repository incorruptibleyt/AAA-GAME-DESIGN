class_name Telegraph
extends Node3D
## A red marker on the floor that warns where an attack will land, then calls back.
## Fair warnings are what make dodging feel skilful instead of random.
## Every warning has a dark rim so it reads on any floor; on the red Ember floor its
## middle burns yellow-white. Dashing out of one as it lands is a perfect dodge (dodged()).

## How long after a warning lands it still counts for a perfect dodge (charges and
## lunges hit just after their strip fills).
const AFTER := 0.3

## Warnings on the floor right now, plus ones that landed in the last AFTER seconds.
static var active: Array[Telegraph] = []

var duration := 1.0
var elapsed := 0.0
var on_done: Callable
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _full: Vector3
var _is_line := false
var _radius := 0.0
var _width := 0.0
var _length := 0.0
var _fired := false


static func _parent() -> Node:
	return Room.current if Room.current else Game.world


## The middle of a warning: red, or yellow-white on the Ember floor where red would vanish.
static func _core(alpha: float) -> Color:
	return Color(1, 0.86, 0.5, alpha) if Floors.hot() else Color(1, 0.2, 0.1, alpha)


## Is `pos` (with radius `r`) inside a warning that lands within `window` seconds, or
## landed less than AFTER seconds ago? The hero's Grave Dash asks this.
static func dodged(pos: Vector3, r: float, window: float) -> bool:
	for t in active:
		if not is_instance_valid(t) or t.is_queued_for_deletion():
			continue
		var left := t.duration - t.elapsed
		if left <= window and left >= -AFTER and t._covers(pos, r):
			return true
	return false


func _covers(pos: Vector3, r: float) -> bool:
	var p := to_local(Vector3(pos.x, global_position.y, pos.z))
	if _is_line:
		return absf(p.x) <= _width * 0.5 + r and p.z <= r and p.z >= -_length - r
	return Vector2(p.x, p.z).length() <= _radius + r


func _enter_tree() -> void:
	active.append(self)


func _exit_tree() -> void:
	active.erase(self)


## A circle of `r` around a point.
static func circle(pos: Vector3, r: float, seconds: float, done: Callable) -> Telegraph:
	var t := Telegraph.new()
	_parent().add_child(t)
	t.global_position = Vector3(pos.x, 0.03, pos.z)
	t._radius = r
	U.floor_quad(t, Vector2(r * 2.3, r * 2.3), U.unlit(Color(0.04, 0.0, 0.0, 0.8), U.ring()), Vector3(0, -0.006, 0))
	U.floor_quad(t, Vector2(r * 2, r * 2), U.unlit(Color(1, 0.15, 0.1, 0.55), U.ring()))
	t._fill_mat = U.unlit(_core(0.7), U.soft_circle()).duplicate()
	t._fill = U.floor_quad(t, Vector2(r * 2, r * 2), t._fill_mat, Vector3(0, 0.01, 0))
	t._fill.scale = Vector3.ZERO
	t._full = Vector3.ONE
	t.duration = seconds
	t.on_done = done
	Sfx.play("warn", 0.6)
	return t


## A strip from `origin` going `length` along `direction` (charges, aimed shots).
static func line(origin: Vector3, direction: Vector3, length: float, width: float, seconds: float, done: Callable) -> Telegraph:
	var t := Telegraph.new()
	t._is_line = true
	_parent().add_child(t)
	direction.y = 0.0
	t.global_position = Vector3(origin.x, 0.03, origin.z)
	t.rotation.y = atan2(-direction.x, -direction.z)
	t._width = width
	t._length = length
	U.floor_quad(t, Vector2(width + 0.3, length + 0.3), U.unlit(Color(0.04, 0.0, 0.0, 0.55)), Vector3(0, -0.006, -length / 2))
	U.floor_quad(t, Vector2(width, length), U.unlit(Color(1, 0.15, 0.1, 0.25)), Vector3(0, 0, -length / 2))
	t._fill_mat = U.unlit(_core(0.6)).duplicate()
	t._fill = U.floor_quad(t, Vector2(width, length), t._fill_mat, Vector3(0, 0.01, 0))
	t._full = Vector3(1, 1, length)
	t._fill.scale = Vector3(1, 1, 0.001)
	t.duration = seconds
	t.on_done = done
	Sfx.play("warn", 0.6)
	return t


func _process(delta: float) -> void:
	elapsed += delta
	if _fired:
		if elapsed >= duration + AFTER:
			queue_free()
		return
	var k := clampf(elapsed / duration, 0.0, 1.0)
	if _is_line:
		_fill.scale = Vector3(1, 1, maxf(k, 0.001))
		_fill.position.z = -_full.z * k * 0.5
	else:
		_fill.scale = Vector3.ONE * k
	var pulse := 0.6 + 0.4 * sin(elapsed * lerpf(8.0, 30.0, k))
	_fill_mat.albedo_color.a = 0.45 + 0.4 * pulse * k
	if elapsed >= duration:
		# Hidden but kept a moment longer, so a dash just after it lands still counts.
		_fired = true
		visible = false
		var cb := on_done
		on_done = Callable()
		if cb.is_valid():
			cb.call()


## Remove without firing (for example when the caster dies).
func cancel() -> void:
	on_done = Callable()
	queue_free()
