class_name DashButton
extends Control
## A small round DASH button above the special button, for players who haven't found
## the flick yet. It dims while the dash recharges and pulses during a dash lesson.

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Hud.label("DASH", 16, Color(0.9, 0.97, 1.0))
	Hud.chunky(_label.label_settings)
	_label.label_settings.outline_size = 5
	_label.position = Vector2(-20, 84)
	_label.size = Vector2(120, 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)


## What the last drawing showed; redraw only when it changes.
var _drawn := []


func _process(_delta: float) -> void:
	visible = Game.hero != null and Game.state in [Game.State.PLAYING, Game.State.PAUSED, Game.State.UPGRADE] and Game.dash_unlocked()
	if visible:
		var h := Game.hero
		var lesson := Game.dash_lesson_active()
		var now := [h.get_instance_id(), lesson, h.dash_ready(), snappedf(clampf(h._dash_cooldown / h.dash_cooldown_time, 0.0, 1.0), 0.005), size]
		if lesson or now != _drawn:   # the lesson pulse animates; otherwise redraw on change
			_drawn = now
			queue_redraw()


func _draw() -> void:
	var h := Game.hero
	if h == null:
		return
	var c := size / 2.0
	var r := size.x / 2.0 - 3.0
	var can_dash := h.dash_ready()
	var lesson := Game.dash_lesson_active()
	var pulse := 1.0 + (0.12 * sin(Time.get_ticks_msec() * 0.02) if lesson else 0.0)
	var col := Color(0.25, 0.62, 1.0)
	Hud.draw_round_button(self, c, r * pulse, col, can_dash or lesson)
	var charge := 1.0 - clampf(h._dash_cooldown / h.dash_cooldown_time, 0.0, 1.0)
	if charge < 1.0:
		draw_arc(c, r * pulse + 5.0, -PI / 2.0, -PI / 2.0 + TAU * charge, 40, Color(0.55, 0.85, 1.0), 5.0, true)
	# Two chevrons pointing up: ">>" turned on its side, white with an ink edge.
	var ink := Color.WHITE if can_dash or lesson else Color(0.6, 0.7, 0.85, 0.6)
	for k in 2:
		var y := c.y + 9.0 - k * 13.0
		var pts := PackedVector2Array([Vector2(c.x - 12, y + 6), Vector2(c.x, y - 6), Vector2(c.x + 12, y + 6)])
		draw_polyline(pts, Hud.INK, 9.0, true)
		draw_polyline(pts, ink, 5.0, true)
