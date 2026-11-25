class_name SpecialButton
extends Control
## The round special-move button. A ring fills as you kill; when it's full the button
## glows and pulses, and a tap fires the hero's special move.

var _label: Label
var _hero_id := ""
## What the last drawing showed; the button redraws only when this changes (or while it pulses).
var _drawn := []


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
		if _hero_id != h.hero_id:   # look the name up only when the hero changes
			_hero_id = h.hero_id
			_label.text = Heroes.get_hero(h.hero_id).special
		var charged := h.special_ready()
		_label.modulate.a = 1.0 if charged else 0.75
		var now := [h.get_instance_id(), charged, snappedf(h.special_charge, 0.005), h.bolt_color, size]
		if charged or now != _drawn:   # a full button pulses, so it draws every frame
			_drawn = now
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
	# Version 338 (visual review fix 3): the button is the hero's own colour all the time
	# (it was a dark grey disc with a dim star until full), dark while it charges, with the
	# colour filling up from the bottom as you kill, and the hero's own move drawn on it.
	# Version 360 (review of 357, fix 3): it still read as a dark grey disc while charging
	# (the colour taken 70% to black). Now a deep tone of the hero's colour with the hero's
	# colour round it as a track the charge runs along, and a glow behind it once full.
	var dark := col.darkened(0.3)
	if charged:
		draw_circle(c, r * pulse + 16.0, Color(col, 0.16 + 0.08 * sin(Time.get_ticks_msec() * 0.01)))
	Hud.draw_round_button(self, c, r * pulse, col.darkened(0.05) if charged else Color(dark, 0.96), true)
	if not charged:
		draw_arc(c, r + 5.0, 0.0, TAU, 48, Color(col, 0.45), 6.0, true)
	if not charged and h.special_charge > 0.0:
		_draw_fill(c, r - 3.0, clampf(h.special_charge, 0.0, 1.0), Color(col.darkened(0.12), 0.9))
		draw_arc(c, r * pulse + 5.0, -PI / 2.0, -PI / 2.0 + TAU * h.special_charge, 48, col, 6.0, true)
	elif charged:
		draw_arc(c, r * pulse + 6.0, 0.0, TAU, 48, Color(1, 1, 1, 0.5 + 0.4 * sin(Time.get_ticks_msec() * 0.01)), 4.0, true)
	var ink := Color.WHITE if charged else Color(0.94, 0.94, 1.0, 0.88)
	_draw_move(_hero_id, c, r * pulse, ink)


## The charge, as colour filling the button from the bottom up to `k` (0..1).
func _draw_fill(c: Vector2, r: float, k: float, fill: Color) -> void:
	var level := c.y + r - 2.0 * r * k
	var dy := clampf((level - c.y) / r, -1.0, 1.0)
	var a0 := asin(dy)   # where the level meets the right side
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var a := lerpf(a0, PI - a0, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	if pts.size() >= 3:
		draw_colored_polygon(pts, fill)


## Each hero's special as a picture: the Knight's shield, the Barbarian's whirl, the
## Rogue's fan of bolts, the Mage's meteor (a star for anyone else).
func _draw_move(id: String, c: Vector2, r: float, ink: Color) -> void:
	var edge := Hud.INK
	match id:
		"knight":
			var w := r * 0.42
			var shield := PackedVector2Array([c + Vector2(-w, -r * 0.42), c + Vector2(w, -r * 0.42), c + Vector2(w, r * 0.02),
				c + Vector2(w * 0.55, r * 0.3), c + Vector2(0, r * 0.48), c + Vector2(-w * 0.55, r * 0.3), c + Vector2(-w, r * 0.02)])
			draw_colored_polygon(shield, ink)
			shield.append(shield[0])
			draw_polyline(shield, edge, 3.0, true)
			draw_line(c + Vector2(0, -r * 0.3), c + Vector2(0, r * 0.32), edge, 3.0, true)
			draw_line(c + Vector2(-w * 0.7, -r * 0.08), c + Vector2(w * 0.7, -r * 0.08), edge, 3.0, true)
		"barbarian":
			for i in 3:
				var a := TAU * i / 3.0
				draw_arc(c, r * (0.2 + 0.11 * i), a, a + PI * 1.25, 18, edge, 7.0, true)
				draw_arc(c, r * (0.2 + 0.11 * i), a, a + PI * 1.25, 18, ink, 4.0, true)
			draw_circle(c, r * 0.09, ink)
		"rogue":
			# Three bolts fanning up from one hand point, so they never cross.
			var base := c + Vector2(0, r * 0.46)
			for i in 3:
				var a := -PI / 2.0 + (i - 1) * 0.55
				var d := Vector2(cos(a), sin(a))
				var tail := base + d * r * 0.18
				var tip := base + d * r * 0.8
				draw_line(tail, tip, edge, 8.0, true)
				draw_line(tail, tip, ink, 4.0, true)
				var side := Vector2(-d.y, d.x) * r * 0.14
				var head := PackedVector2Array([tip + d * r * 0.12, tip - d * r * 0.12 + side, tip - d * r * 0.12 - side])
				draw_colored_polygon(head, ink)
				head.append(head[0])
				draw_polyline(head, edge, 2.5, true)
		"mage":
			# A big rock falling down-left with three tapering flame tails behind it.
			var rock := c + Vector2(-r * 0.2, r * 0.2)
			var back := Vector2(1, -1).normalized()
			var side := Vector2(back.y, -back.x)
			for i: int in [-1, 1, 0]:
				var root := rock + side * r * 0.15 * i
				var length := r * (0.95 if i == 0 else 0.72)
				var w := r * (0.2 if i == 0 else 0.13)
				var tail := PackedVector2Array([root + side * w, root + back * length + side * i * r * 0.06, root - side * w])
				draw_colored_polygon(tail, edge)
				var inner := PackedVector2Array([root + side * w * 0.6, root + back * (length - 5.0) + side * i * r * 0.06, root - side * w * 0.6])
				draw_colored_polygon(inner, ink)
			draw_circle(rock, r * 0.3, edge)
			draw_circle(rock, r * 0.25, ink)
			draw_circle(rock + Vector2(-r * 0.07, -r * 0.07), r * 0.07, Color(edge, 0.35))
		_:
			var star := PackedVector2Array()
			for i in 10:
				var rr := r * 0.46 if i % 2 == 0 else r * 0.21
				var a := TAU * i / 10.0 - PI / 2.0
				star.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(star, ink)
			star.append(star[0])
			draw_polyline(star, edge, 3.0, true)
