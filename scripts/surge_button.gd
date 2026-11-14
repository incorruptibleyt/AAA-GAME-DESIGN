class_name SurgeButton
extends Control
## The Crypt Race's SURGE button (version 155, Supercell review fix 3), next to the special.
## Kills fill its ring; once full it glows, and a tap stuns the rival. You choose when: a
## surge saved for the rival's boss fight stuns it half as long again (BIG SURGE), but
## while the meter is full your kills fill nothing.

var fill := 0.0          # 0..1
var big := false         # the rival is at its boss: a surge now is a big one
var _label: Label
var _drawn := []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Hud.label("SURGE", 16, RaceScreen.TEAL.lightened(0.35))
	Hud.chunky(_label.label_settings)
	_label.label_settings.outline_size = 5
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)
	_place_label()
	resized.connect(_place_label)


func _place_label() -> void:
	_label.position = Vector2(-30, size.y + 2.0)
	_label.size = Vector2(size.x + 60.0, 22)


func ready_now() -> bool:
	return fill >= 1.0


func _process(_delta: float) -> void:
	if not visible:
		return
	var full := ready_now()
	_label.text = "BIG SURGE!" if full and big else ("SURGE!" if full else "SURGE")
	_label.label_settings.font_color = (Color(1.0, 0.85, 0.4) if big else RaceScreen.TEAL.lightened(0.35)) if full else RaceScreen.TEAL.lightened(0.1)
	_label.modulate.a = 1.0 if full else 0.65
	var now := [snappedf(fill, 0.01), full, big, size]
	if full or now != _drawn:   # a full button pulses, so it draws every frame
		_drawn = now
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := size.x / 2.0 - 4.0
	var full := ready_now()
	var t := Time.get_ticks_msec() * 0.01
	var pulse := 1.0 + (0.07 * sin(t) if full else 0.0)
	var col := Color(1.0, 0.8, 0.3) if (full and big) else RaceScreen.TEAL
	Hud.draw_round_button(self, c, r * pulse, col.darkened(0.15) if full else Color(0.1, 0.16, 0.2), full)
	if not full and fill > 0.0:
		draw_arc(c, r + 5.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 48, col, 6.0, true)
	elif full:
		draw_arc(c, r * pulse + 6.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5 + 0.4 * sin(t)), 4.0, true)
	# A lightning bolt: white with an ink edge once it's ready.
	var k := r * 0.042 * pulse
	var bolt := PackedVector2Array([c + Vector2(3, -13) * k * 1.6, c + Vector2(-7, 2) * k * 1.6, c + Vector2(0, 2) * k * 1.6,
		c + Vector2(-3, 13) * k * 1.6, c + Vector2(7, -2) * k * 1.6, c + Vector2(0, -2) * k * 1.6])
	draw_colored_polygon(bolt, Color.WHITE if full else Color(col.r, col.g, col.b, 0.6))
	bolt.append(bolt[0])
	draw_polyline(bolt, Hud.INK, 3.0, true)
