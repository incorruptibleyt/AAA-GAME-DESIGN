class_name HealthBar
extends Node3D
## A small health bar that floats over an enemy for a few seconds after it is hurt.

var _owner_actor: Actor
var _fill: MeshInstance3D
var _width := 1.0
var _timer := 0.0
var _keep := 1.0


static func attach(a: Actor) -> HealthBar:
	if a is Enemy and (a as Enemy).is_boss:
		return null   # the boss uses the big bar at the top of the screen
	var bar := HealthBar.new()
	bar._owner_actor = a
	bar._width = clampf(a.radius * 2.4, 0.9, 1.6)
	a.add_child(bar)
	# Top-level so the bar ignores the skeleton's turning; we follow it in _process.
	bar.top_level = true
	# A slim bar: a thin ink frame around a bright fill. Version 358 (review of 357, fix 2):
	# half as tall (0.26 m frame, 0.14 m fill read as blocks over every hurt skeleton).
	_quad(bar, Vector2(bar._width + 0.08, 0.15), Color(0.07, 0.035, 0.1, 0.85))
	bar._fill = _quad(bar, Vector2(bar._width, 0.085), Color(1.0, 0.25, 0.22))
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
	# (Version 386: its own copy, so a bar by the hero can fade on its own; the Compatibility
	# renderer ignores GeometryInstance3D.transparency.)
	mi.material_override = U.unlit(col, null, true).duplicate()
	mi.set_meta("a", col.a)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func reveal() -> void:
	_timer = 3.0


## Version 386 (visual review of v383, fix 3: always find your hero): how much a floating
## mark at `pos` (a skeleton's bar, number or name) should step back because it would sit
## over the hero: 1 right beside them, 0 from 2.6 m away. In a close fight the bars, tags
## and numbers of the skeletons around the hero stacked over them and hid them.
static func near_hero(pos: Vector3) -> float:
	var h := Game.hero
	if h == null or not is_instance_valid(h) or h.dead:
		return 0.0
	var d := Vector2(pos.x - h.global_position.x, pos.z - h.global_position.z).length()
	return 1.0 - smoothstep(1.2, 2.6, d)


func _process(delta: float) -> void:
	_timer -= delta
	visible = _timer > 0.0
	if not visible:
		return
	global_position = _owner_actor.global_position + Vector3.UP * (_owner_actor.center_height * 2.0 + 0.5)
	var keep := 1.0 - 0.75 * near_hero(_owner_actor.global_position)
	if absf(keep - _keep) > 0.02:
		_keep = keep
		for c in get_children():
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			m.albedo_color.a = float(c.get_meta("a", 1.0)) * keep
	var k := clampf(_owner_actor.health / _owner_actor.max_health, 0.0, 1.0)
	_fill.scale = Vector3(maxf(k, 0.001), 1, 1)
