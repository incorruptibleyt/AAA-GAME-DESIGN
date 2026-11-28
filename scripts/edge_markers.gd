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
var _buttons := Rect2()


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
	var at := mid + d * k
	# (never under DASH or the special: slid along the edge to clear them)
	if _buttons.size != Vector2.ZERO and _buttons.grow(18.0).has_point(at):
		if absf(at.y - inner.end.y) < 1.0:
			at.x = _buttons.position.x - 24.0
		else:
			at.y = _buttons.position.y - 24.0
	_arrows.append(at)
	_arrows.append(d.normalized())


func _find_arrows() -> void:
	var cam := Game._camera
	if cam == null or Room.current == null:
		return
	var view := get_viewport_rect().size
	# Version 166 (Tweaks report #8): the arrows stay clear of a camera hole or rounded corners.
	var s := Hud.safe_margins(get_viewport())   # left, top, right, bottom (0 off phones)
	var inner := Rect2(Vector2(MARGIN + s.x, MARGIN + s.y),
			view - Vector2(MARGIN * 2.0 + s.x + s.z, MARGIN * 2.0 + s.y + s.w))
	# Version 423 (re-review of v420, fix 2): under the top bar and the boss bar, not over
	# the room number ("F3 Room" had an arrow on it).
	var top := maxf(inner.position.y, Game.hud.fight_top() if Game.hud else 0.0)
	inner = Rect2(inner.position.x, top, inner.size.x, maxf(40.0, inner.end.y - top))
	_buttons = Game.hud.button_rect() if Game.hud else Rect2()
	var mid := inner.get_center()
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
