class_name FirePatch
extends Node3D
## A patch of fire on the floor, left by Cinder Skeletons. It flares up over half a
## second (so you can see it coming), then burns the hero while they stand in it.
## A charred dark rim and a pulsing yellow-white middle keep it readable on the red
## Ember floor, the same way enemy shots stand out.

const FLARE := 0.5

var radius := 0.9
var life := 3.0
var _age := 0.0
var _tick := 0.0
var _mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D


static func spawn(pos: Vector3, r: float, seconds: float) -> void:
	var parent: Node = Room.current if Room.current else Game.world
	if parent == null:
		return
	var f := FirePatch.new()
	f.radius = r
	f.life = seconds
	parent.add_child(f)
	f.global_position = Vector3(pos.x, 0.04, pos.z)
	f._rim_mat = U.unlit(Color(0.06, 0.01, 0.0, 0.0), U.ring()).duplicate()
	U.floor_quad(f, Vector2(r * 2.25, r * 2.25), f._rim_mat, Vector3(0, -0.004, 0))
	f._mat = U.unlit(Color(1, 0.38, 0.08, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(f, Vector2(r * 2.1, r * 2.1), f._mat)
	f._core_mat = U.unlit(Color(1, 0.9, 0.6, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(f, Vector2(r * 1.2, r * 1.2), f._core_mat, Vector3(0, 0.006, 0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	var k := minf(_age / FLARE, 1.0)
	var fade := clampf((life - _age) / 0.6, 0.0, 1.0)
	_mat.albedo_color.a = 0.8 * k * fade
	_rim_mat.albedo_color.a = 0.75 * k * fade
	_core_mat.albedo_color.a = (0.6 + 0.35 * sin(_age * 9.0)) * k * fade
	if randf() < delta * 5.0:
		Fx.magic(global_position + Vector3(randf_range(-radius, radius) * 0.6, 0.2, randf_range(-radius, radius) * 0.6), Color(1, 0.5, 0.15), 2)
	_tick -= delta
	var hero := Game.hero
	if k < 1.0 or _tick > 0.0 or hero == null or hero.dead or Game.state != Game.State.PLAYING:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	if d.length() < radius + hero.radius * 0.5:
		_tick = 0.5
		Game.hit_source = "Cinder fire"
		hero.take_damage(6.0, Vector3.ZERO, 0.0)
