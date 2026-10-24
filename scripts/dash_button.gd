class_name DashButton
extends Control
## A small round DASH button above the special button, for players who haven't found
## the flick yet. It dims while the dash recharges and pulses during a dash lesson.

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Hud.label("Dash", 15, Color(0.85, 0.95, 1.0))
	_label.position = Vector2(-20, 80)
	_label.size = Vector2(120, 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)


func _process(_delta: float) -> void:
	visible = Game.hero != null and Game.state in [Game.State.PLAYING, Game.State.PAUSED, Game.State.UPGRADE]
	if visible:
		queue_redraw()


func _draw() -> void:
	var h := Game.hero
	if h == null:
		return
	var c := size / 2.0
	var r := size.x / 2.0 - 3.0
	var ready := h.dash_ready()
	var lesson := Game.dash_lesson_active()
	var pulse := 1.0 + (0.12 * sin(Time.get_ticks_msec() * 0.02) if lesson else 0.0)
	var col := Color(0.45, 0.8, 1.0)
	draw_circle(c, r * pulse, Color(col.r, col.g, col.b, 0.75) if lesson else Color(0.08, 0.06, 0.1, 0.7))
	var charge := 1.0 - clampf(h._dash_cooldown / Hero.DASH_COOLDOWN, 0.0, 1.0)
	draw_arc(c, r * pulse, -PI / 2.0, -PI / 2.0 + TAU * charge, 40, col if ready else Color(col.r, col.g, col.b, 0.4), 5.0)
	# Two chevrons pointing up: ">>" turned on its side.
	var ink := Color(0.05, 0.05, 0.1) if lesson else (col if ready else Color(col.r, col.g, col.b, 0.4))
	for k in 2:
		var y := c.y + 8.0 - k * 12.0
		draw_polyline(PackedVector2Array([Vector2(c.x - 11, y + 6), Vector2(c.x, y - 5), Vector2(c.x + 11, y + 6)]), ink, 4.0)
