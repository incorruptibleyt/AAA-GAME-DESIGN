class_name HealthBar
extends Node3D
## A small health bar that floats over an enemy for a few seconds after it is hurt.

var _owner_actor: Actor
var _fill: MeshInstance3D
var _width := 1.0
var _timer := 0.0


static func attach(a: Actor) -> HealthBar:
	if a is Enemy and (a as Enemy).is_boss:
		return null   # the boss uses the big bar at the top of the screen
	var bar := HealthBar.new()
	bar._owner_actor = a
	bar._width = clampf(a.radius * 2.4, 0.9, 1.6)
	a.add_child(bar)
	# Top-level so the bar ignores the skeleton's turning; we follow it in _process.
	bar.top_level = true
	_quad(bar, Vector2(bar._width + 0.08, 0.2), Color(0, 0, 0, 0.7))
	bar._fill = _quad(bar, Vector2(bar._width, 0.12), Color(0.9, 0.2, 0.2))
	# Pivot the fill on its left edge so it shrinks towards the left.
	(bar._fill.mesh as QuadMesh).center_offset = Vector3(bar._width * 0.5, 0, 0)
	bar._fill.position.x = -bar._width * 0.5
	bar._fill.sorting_offset = 1.0
	bar.visible = false
	return bar


static func _quad(parent: Node3D, size: Vector2, col: Color) -> MeshInstance3D:
	var m := QuadMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = U.unlit(col, null, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func reveal() -> void:
	_timer = 3.0


func _process(delta: float) -> void:
	_timer -= delta
	visible = _timer > 0.0
	if not visible:
		return
	global_position = _owner_actor.global_position + Vector3.UP * (_owner_actor.center_height * 2.0 + 0.5)
	var k := clampf(_owner_actor.health / _owner_actor.max_health, 0.0, 1.0)
	_fill.scale = Vector3(maxf(k, 0.001), 1, 1)
