class_name Telegraph
extends Node3D
## A red marker on the floor that warns where an attack will land, then calls back.
## Fair warnings are what make dodging feel skilful instead of random.

var duration := 1.0
var elapsed := 0.0
var on_done: Callable
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _full: Vector3
var _is_line := false


static func _parent() -> Node:
	return Room.current if Room.current else Game.world


## A circle of `r` around a point.
static func circle(pos: Vector3, r: float, seconds: float, done: Callable) -> Telegraph:
	var t := Telegraph.new()
	_parent().add_child(t)
	t.global_position = Vector3(pos.x, 0.03, pos.z)
	U.floor_quad(t, Vector2(r * 2, r * 2), U.unlit(Color(1, 0.15, 0.1, 0.55), U.ring()))
	t._fill_mat = U.unlit(Color(1, 0.2, 0.1, 0.7), U.soft_circle()).duplicate()
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
	U.floor_quad(t, Vector2(width, length), U.unlit(Color(1, 0.15, 0.1, 0.25)), Vector3(0, 0, -length / 2))
	t._fill_mat = U.unlit(Color(1, 0.25, 0.1, 0.6)).duplicate()
	t._fill = U.floor_quad(t, Vector2(width, length), t._fill_mat, Vector3(0, 0.01, 0))
	t._full = Vector3(1, 1, length)
	t._fill.scale = Vector3(1, 1, 0.001)
	t.duration = seconds
	t.on_done = done
	Sfx.play("warn", 0.6)
	return t


func _process(delta: float) -> void:
	elapsed += delta
	var k := clampf(elapsed / duration, 0.0, 1.0)
	if _is_line:
		_fill.scale = Vector3(1, 1, maxf(k, 0.001))
		_fill.position.z = -_full.z * k * 0.5
	else:
		_fill.scale = Vector3.ONE * k
	var pulse := 0.6 + 0.4 * sin(elapsed * lerpf(8.0, 30.0, k))
	_fill_mat.albedo_color.a = 0.45 + 0.4 * pulse * k
	if elapsed >= duration:
		var cb := on_done
		on_done = Callable()
		queue_free()
		if cb.is_valid():
			cb.call()


## Remove without firing (for example when the caster dies).
func cancel() -> void:
	on_done = Callable()
	queue_free()
