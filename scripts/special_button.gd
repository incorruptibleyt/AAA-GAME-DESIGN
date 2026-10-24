class_name SpecialButton
extends Control
## The round special-move button. A ring fills as you kill; when it's full the button
## glows and pulses, and a tap fires the hero's special move.

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Hud.label("", 15, Color(1, 0.95, 0.85))
	_label.position = Vector2(-20, 102)
	_label.size = Vector2(140, 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)


func _process(_delta: float) -> void:
	var h := Game.hero
	visible = h != null and Game.state in [Game.State.PLAYING, Game.State.PAUSED, Game.State.UPGRADE]
	if visible:
		_label.text = Heroes.get_hero(h.hero_id).special
		_label.modulate.a = 1.0 if h.special_ready() else 0.6
		queue_redraw()


func _draw() -> void:
	var h := Game.hero
	if h == null:
		return
	var c := size / 2.0
	var r := size.x / 2.0 - 4.0
	var ready := h.special_ready()
	var col := h.bolt_color.lerp(Color.WHITE, 0.25)
	var pulse := 1.0 + (0.06 * sin(Time.get_ticks_msec() * 0.01) if ready else 0.0)
	draw_circle(c, r * pulse, Color(col.r, col.g, col.b, 0.85) if ready else Color(0.08, 0.06, 0.1, 0.7))
	draw_arc(c, r * pulse, 0.0, TAU, 48, Color(0, 0, 0, 0.6), 6.0)
	if h.special_charge > 0.0:
		draw_arc(c, r * pulse, -PI / 2.0, -PI / 2.0 + TAU * h.special_charge, 48, col if not ready else Color.WHITE, 6.0)
	# A simple star in the middle so it reads as "power".
	var star := PackedVector2Array()
	for i in 10:
		var rr := (r * 0.45 if i % 2 == 0 else r * 0.2) * pulse
		var a := TAU * i / 10.0 - PI / 2.0
		star.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(star, Color(0.1, 0.06, 0.12) if ready else Color(col.r, col.g, col.b, 0.5))
