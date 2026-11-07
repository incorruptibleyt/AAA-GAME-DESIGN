class_name DropScreen
extends ColorRect
## Opening Bone Drops (drops.gd): a bone reliquary sits in the middle of the screen. A tap
## shakes it while its glow climbs the colours (grey, green, blue, purple, gold) up to
## what's inside, then the lid flies off and the prize shows. Unopened drops stay saved.

signal closed

## Opens one drop and returns what was inside (Drops.open's result, or {} if none).
var opener: Callable

enum Step { CLOSED, OPENING, OPEN }

## When the glow climbs to the next colour, in seconds into the opening.
const CLIMB := [0.35, 0.62, 0.86, 1.06]
const OPEN_AT := 1.3

var _step := Step.CLOSED
var _t := 0.0
var _left := 0
var _result := {}
var _shown_tier := 0
var _flash := 0.0
var _pop := 0.0
var _art: Control
var _head: Label
var _count: Label
var _rarity: Label
var _prize: Label
var _action: Button
var _later: Button


func _init() -> void:
	color = Color(0.02, 0.01, 0.04, 0.96)
	Hud.backdrop(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	Hud.full(col)
	col.offset_left = 20
	col.offset_right = -20
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	_head = Hud.label("BONE DROP", 46, Color(1, 0.85, 0.55))
	col.add_child(_head)
	_count = Hud.label("", 19, Color(0.8, 0.78, 0.85))
	col.add_child(_count)
	_art = Control.new()
	_art.custom_minimum_size = Vector2(320, 320)
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	col.add_child(_art)
	_rarity = Hud.label("", 34, Color.WHITE)
	col.add_child(_rarity)
	_prize = Hud.label("", 28, Hud.GOLD)
	_prize.custom_minimum_size = Vector2(0, 110)
	col.add_child(_prize)
	_action = Hud.button("TAP TO OPEN", 30, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_action.custom_minimum_size = Vector2(340, 86)
	_action.pressed.connect(_tap)
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_action)
	col.add_child(box)
	_later = Hud.button("LATER", 20, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_later.custom_minimum_size = Vector2(200, 62)
	_later.pressed.connect(close)
	var box2 := CenterContainer.new()
	box2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box2.add_child(_later)
	col.add_child(box2)
	gui_input.connect(func(e: InputEvent):
		# (Touches arrive as mouse clicks too: Godot's emulate-mouse-from-touch.)
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_tap())


## Shows the screen with `waiting` drops to open.
func open_screen(waiting: int) -> void:
	_left = waiting
	visible = waiting > 0
	if visible:
		_ready_next()


func close() -> void:
	if not visible:
		return
	if _step == Step.OPENING:
		_finish()   # the prize was already given; show it before leaving
		return
	visible = false
	closed.emit()


func _ready_next() -> void:
	_step = Step.CLOSED
	_t = 0.0
	_result = {}
	_shown_tier = 0
	_pop = 0.0
	_head.text = "BONE DROP"
	_count.text = "%d waiting" % _left if _left > 1 else "Earned by brave runs"
	_rarity.text = ""
	_prize.text = "What's inside?\nTap to find out."
	_prize.label_settings.font_color = Color(0.8, 0.78, 0.85)
	_prize.label_settings.font_size = 22
	_action.text = "TAP TO OPEN"
	_later.visible = true
	_art.queue_redraw()


func _tap() -> void:
	match _step:
		Step.CLOSED:
			_result = opener.call() if opener.is_valid() else {}
			if _result.is_empty():
				visible = false
				closed.emit()
				return
			_left -= 1
			_step = Step.OPENING
			_t = 0.0
			_later.visible = false
			_action.text = "..."
			_prize.text = ""
			Sfx.play("click")
		Step.OPENING:
			if _t > 0.2:
				_finish()   # a second tap skips to the prize
		Step.OPEN:
			if _t < 0.35:
				return   # a quick double tap shouldn't open the next one by mistake
			if _left > 0:
				_ready_next()
			else:
				close()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	_pop = move_toward(_pop, 0.0, delta * 2.5)
	if _step == Step.OPENING:
		var goal: int = _result.get("tier", 0)
		var reach := 0
		for at: float in CLIMB:
			if _t >= at:
				reach += 1
		reach = mini(reach, goal)
		if reach > _shown_tier:
			_shown_tier = reach
			_flash = 0.6
			Sfx.play("upgrade", 0.5, 0.8 + 0.15 * reach)
			if Game.vibration:
				Input.vibrate_handheld(25)
		if _t >= OPEN_AT:
			_finish()
	_art.queue_redraw()


func _finish() -> void:
	_step = Step.OPEN
	_t = 0.0
	_shown_tier = _result.get("tier", 0)
	_flash = 1.0
	_pop = 1.0
	var c: Color = _result.get("color", Color.WHITE)
	_head.text = "BONE DROP"
	_rarity.text = str(_result.get("name", ""))
	_rarity.label_settings.font_color = c
	_prize.text = str(_result.get("text", ""))
	_prize.label_settings.font_color = Hud.GOLD if _result.get("kind", "") == "coins" else c.lightened(0.35)
	_prize.label_settings.font_size = 34 if _result.get("kind", "") == "coins" else 22
	_count.text = "%d more waiting" % _left if _left > 0 else "All opened!"
	_action.text = "OPEN NEXT" if _left > 0 else "DONE"
	_later.visible = _left > 0
	Sfx.play("victory" if _shown_tier >= 3 else ("upgrade" if _shown_tier >= 1 else "coin"), 0.8)
	if _result.get("kind", "") == "coins":
		Sfx.play("coin", 0.6, 1.2)
	if Game.vibration:
		Input.vibrate_handheld(60 if _shown_tier >= 3 else 35)


# ---------------------------------------------------------------- the reliquary

func _tier_color() -> Color:
	return Drops.TIERS[clampi(_shown_tier, 0, Drops.TIERS.size() - 1)].color


func _draw_art() -> void:
	var a := _art
	var c := a.size * 0.5
	var col := _tier_color()
	var open := _step == Step.OPEN
	var shake := Vector2.ZERO
	var tilt := 0.0
	if _step == Step.OPENING:
		var amp := 3.0 + 12.0 * clampf(_t / OPEN_AT, 0.0, 1.0)
		shake = Vector2(sin(_t * 55.0) * amp, cos(_t * 41.0) * amp * 0.4)
		tilt = sin(_t * 47.0) * 0.06 * amp / 15.0
	elif _step == Step.CLOSED:
		# A little hop now and then, asking to be opened.
		var hop := fmod(Time.get_ticks_msec() / 1000.0, 2.2)
		if hop < 0.35:
			shake.y = -sin(hop / 0.35 * PI) * 10.0
	var k := 1.0 + 0.18 * ease(_pop, 0.5)
	# Glow: soft rings of the current colour (brighter as it climbs, and on each step).
	var glow := 0.18 + 0.1 * _shown_tier + 0.4 * _flash
	if _step == Step.CLOSED:
		glow = 0.12
	for i in 7:
		var r := (150.0 - i * 16.0) * k
		var g := col
		g.a = glow * (0.12 + 0.1 * i)
		a.draw_circle(c, r, g)
	# Rays once it's open, turning slowly.
	if open:
		var spin := Time.get_ticks_msec() / 1000.0 * 0.5
		var ray := col
		ray.a = 0.22 + 0.25 * _flash
		for i in 12:
			var ang := spin + TAU * i / 12.0
			var d1 := Vector2.from_angle(ang - 0.09)
			var d2 := Vector2.from_angle(ang + 0.09)
			a.draw_colored_polygon(PackedVector2Array([c, c + d1 * 165.0 * k, c + d2 * 165.0 * k]), ray)
	a.draw_set_transform(c + shake, tilt, Vector2(k, k))
	var bone := Color(0.9, 0.87, 0.78)
	var dark := Color(0.16, 0.12, 0.14)
	# Two crossed bones behind the box.
	for s in [-1.0, 1.0]:
		var dir := Vector2(s, -0.75).normalized()
		var p1 := dir * -112.0 + Vector2(0, 30)
		var p2 := dir * 112.0 + Vector2(0, 30)
		a.draw_line(p1, p2, bone.darkened(0.15), 16.0)
		for p in [p1, p2]:
			var side := Vector2(-dir.y, dir.x) * 8.0
			a.draw_circle(p + side, 12.0, bone.darkened(0.15))
			a.draw_circle(p - side, 12.0, bone.darkened(0.15))
	# The box.
	var body := Rect2(-86, -18, 172, 104)
	_box(a, body, dark, col, 14)
	# Light pouring out of the open box.
	if open:
		var beam := col.lightened(0.4)
		beam.a = 0.55
		a.draw_colored_polygon(PackedVector2Array([Vector2(-70, -18), Vector2(70, -18), Vector2(110, -150), Vector2(-110, -150)]), Color(beam, 0.18))
		a.draw_rect(Rect2(-74, -24, 148, 10), beam)
		# The inside glows, with what was found sitting in it.
		var inner := col.lightened(0.15)
		inner.a = 0.55
		var isb := StyleBoxFlat.new()
		isb.bg_color = inner
		isb.set_corner_radius_all(8)
		a.draw_style_box(isb, Rect2(-66, -6, 132, 80))
		_prize_icon(a, Vector2(0, 34), str(_result.get("kind", "coins")), col)
	# The lid: on top while closed; once open it has flown up and tipped back.
	var lid_off := Vector2(0, -36)
	var lid_rot := 0.0
	if open:
		var fly := 1.0 - _pop
		lid_off = Vector2(50 + 26 * fly, -84 - 10 * fly)
		lid_rot = 0.5
	a.draw_set_transform(c + shake + (lid_off + Vector2(0, 0)).rotated(tilt) * k, tilt + lid_rot, Vector2(k, k))
	_box(a, Rect2(-94, -20, 188, 40), dark.lightened(0.05), col, 12)
	# The skull on the lid.
	a.draw_circle(Vector2(0, -2), 26.0, bone)
	a.draw_rect(Rect2(-14, 10, 28, 16), bone)
	a.draw_circle(Vector2(-10, -4), 7.0, dark)
	a.draw_circle(Vector2(10, -4), 7.0, dark)
	a.draw_colored_polygon(PackedVector2Array([Vector2(0, 4), Vector2(-4, 11), Vector2(4, 11)]), dark)
	for x in [-8, 0, 8]:
		a.draw_line(Vector2(x, 18), Vector2(x, 26), dark, 2.0)
	a.draw_set_transform(c + shake, tilt, Vector2(k, k))
	# A question mark on the front while closed; a sparkle once open.
	if not open:
		var f := ThemeDB.fallback_font
		a.draw_string_outline(f, Vector2(-20, 66), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 54, 8, Color(0, 0, 0, 0.8))
		a.draw_string(f, Vector2(-20, 66), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 54, col.lightened(0.3))
	a.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The whole screen flashes the colour as it climbs and opens.
	if _flash > 0.0:
		var fl := col
		fl.a = _flash * 0.35
		a.draw_circle(c, 170.0, fl)


## A pile of coins, a star (Lucky Start) or an arrow (a free Armory level).
func _prize_icon(a: Control, p: Vector2, kind: String, col: Color) -> void:
	var gold := Color(1.0, 0.8, 0.3)
	var edge := Color(0.55, 0.36, 0.08)
	match kind:
		"lucky":
			var pts := PackedVector2Array()
			for i in 10:
				var r := 30.0 if i % 2 == 0 else 13.0
				pts.append(p + Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * r)
			a.draw_colored_polygon(pts, Color.WHITE.lerp(col, 0.25))
			pts.append(pts[0])
			a.draw_polyline(pts, col.darkened(0.5), 3.0)
		"armory":
			var arrow := PackedVector2Array([p + Vector2(0, -30), p + Vector2(26, -2), p + Vector2(11, -2),
					p + Vector2(11, 28), p + Vector2(-11, 28), p + Vector2(-11, -2), p + Vector2(-26, -2)])
			a.draw_colored_polygon(arrow, gold)
			arrow.append(arrow[0])
			a.draw_polyline(arrow, edge, 3.0)
		_:
			for c: Vector2 in [Vector2(-22, 12), Vector2(22, 12), Vector2(0, -6)]:
				a.draw_circle(p + c, 19.0, edge)
				a.draw_circle(p + c, 16.0, gold)
				a.draw_circle(p + c, 9.0, gold.lightened(0.3))


func _box(a: Control, r: Rect2, fill: Color, edge: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(radius)
	a.draw_style_box(sb, r)
	# Bone-coloured corner studs.
	for p in [r.position + Vector2(14, 14), r.position + Vector2(r.size.x - 14, 14),
			r.position + Vector2(14, r.size.y - 14), r.position + r.size - Vector2(14, 14)]:
		a.draw_circle(p, 5.0, edge.lightened(0.25))
