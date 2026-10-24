class_name EdgeMarkers
extends Control
## Small red arrows on the screen edge pointing at undead and warning markers that are
## just off-screen, so the closer camera never hides an attack that is on its way.

const MARGIN := 22.0
const RED := Color(1.0, 0.18, 0.32)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := Game._camera
	if Game.state != Game.State.PLAYING or cam == null or Room.current == null:
		return
	var points: Array[Vector3] = []
	for a: Actor in Actor.all:
		if a.team == Actor.Team.UNDEAD and not a.dead:
			points.append(a.global_position)
	for t in Room.current.get_children():
		if t is Telegraph:
			points.append((t as Telegraph).global_position)
	var view := get_viewport_rect().size
	var mid := view / 2.0
	var inner := Rect2(Vector2(MARGIN, MARGIN), view - Vector2(MARGIN, MARGIN) * 2.0)
	for p in points:
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		if Rect2(Vector2.ZERO, view).has_point(s):
			continue
		# Walk from the screen middle towards the point and stop at the margin.
		var d := (s - mid)
		var k := minf(absf((inner.size.x / 2.0) / d.x) if d.x != 0.0 else INF,
				absf((inner.size.y / 2.0) / d.y) if d.y != 0.0 else INF)
		var at := mid + d * k
		var n := d.normalized()
		var side := Vector2(-n.y, n.x)
		var tip := at + n * 10.0
		draw_colored_polygon(PackedVector2Array([tip, at - n * 8.0 + side * 10.0, at - n * 8.0 - side * 10.0]), RED)
		draw_polyline(PackedVector2Array([tip, at - n * 8.0 + side * 10.0, at - n * 8.0 - side * 10.0, tip]), Color(0.1, 0, 0.03), 2.0)
