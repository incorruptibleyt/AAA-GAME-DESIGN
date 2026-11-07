class_name SpecialButton
extends Control
## The round special-move button. A ring fills as you kill; when it's full the button
## glows and pulses, and a tap fires the hero's special move.

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Hud.label("", 16, Color(1, 0.95, 0.85))
	Hud.chunky(_label.label_settings)
	_label.label_settings.outline_size = 5
	_label.position = Vector2(-20, 106)
	_label.size = Vector2(140, 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)


func _process(_delta: float) -> void:
	var h := Game.hero
	visible = h != null and Game.state in [Game.State.PLAYING, Game.State.PAUSED, Game.State.UPGRADE] and Game.special_unlocked()
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
	var charged := h.special_ready()
	var col := h.bolt_color.lerp(Color.WHITE, 0.25)
	var pulse := 1.0 + (0.06 * sin(Time.get_ticks_msec() * 0.01) if charged else 0.0)
	Hud.draw_round_button(self, c, r * pulse, col.darkened(0.1), charged)
	if not charged and h.special_charge > 0.0:
		draw_arc(c, r * pulse + 5.0, -PI / 2.0, -PI / 2.0 + TAU * h.special_charge, 48, col, 6.0, true)
	elif charged:
		draw_arc(c, r * pulse + 6.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.01)), 4.0, true)
	# A star in the middle so it reads as "power": white with an ink edge once ready.
	var star := PackedVector2Array()
	for i in 10:
		var rr := (r * 0.46 if i % 2 == 0 else r * 0.21) * pulse
		var a := TAU * i / 10.0 - PI / 2.0
		star.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(star, Color.WHITE if charged else Color(col.r, col.g, col.b, 0.55))
	star.append(star[0])
	draw_polyline(star, Hud.INK, 3.0, true)
