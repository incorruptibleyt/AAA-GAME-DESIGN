class_name EdgeMarkers
extends Control
## Small red arrows on the screen edge pointing at undead and warning markers that are
## just off-screen, so the closer camera never hides an attack that is on its way.

const MARGIN := 30.0
const RED := Color(1.0, 0.18, 0.32)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Each arrow is two entries: where it sits on the margin, and the way it points.
var _arrows := PackedVector2Array()
var _had_arrows := false


func _process(_delta: float) -> void:
	# Version 147: the arrows are worked out here into one reused list, and the screen is
	# only redrawn while there are arrows (or to clear the last ones), not every frame.
	_arrows.clear()
	if Game.state == Game.State.PLAYING:
		_find_arrows()
	var has := not _arrows.is_empty()
	if has or _had_arrows:
		queue_redraw()
	_had_arrows = has


func _add_point(cam: Camera3D, p: Vector3, view: Vector2, mid: Vector2, inner: Rect2) -> void:
	if cam.is_position_behind(p):
		return
	var s := cam.unproject_position(p)
	if Rect2(Vector2.ZERO, view).has_point(s):
		return
	# Walk from the screen middle towards the point and stop at the margin.
	var d := (s - mid)
	var k := minf(absf((inner.size.x / 2.0) / d.x) if d.x != 0.0 else INF,
			absf((inner.size.y / 2.0) / d.y) if d.y != 0.0 else INF)
	_arrows.append(mid + d * k)
	_arrows.append(d.normalized())


func _find_arrows() -> void:
	var cam := Game._camera
	if cam == null or Room.current == null:
		return
	var view := get_viewport_rect().size
	var mid := view / 2.0
	var inner := Rect2(Vector2(MARGIN, MARGIN), view - Vector2(MARGIN, MARGIN) * 2.0)
	for a: Actor in Actor.all:
		if a.team == Actor.Team.UNDEAD and not a.dead:
			_add_point(cam, a.global_position, view, mid, inner)
	for t: Telegraph in Telegraph.active:
		if is_instance_valid(t):
			_add_point(cam, t.global_position, view, mid, inner)


func _draw() -> void:
	# Version 147 (accessibility review item 3): bigger arrows (about 1.6x) with a white edge,
	# so they read on any floor and not only by their red colour.
	for i in range(0, _arrows.size(), 2):
		var at := _arrows[i]
		var n := _arrows[i + 1]
		var side := Vector2(-n.y, n.x)
		var tip := at + n * 16.0
		var tri := PackedVector2Array([tip, at - n * 13.0 + side * 16.0, at - n * 13.0 - side * 16.0])
		draw_colored_polygon(tri, RED)
		tri.append(tip)
		draw_polyline(tri, Color(0.1, 0, 0.03), 6.0)
		draw_polyline(tri, Color.WHITE, 3.0)
