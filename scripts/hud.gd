class_name Hud
extends CanvasLayer
## Everything on screen that isn't the 3D world: the floating thumb joystick, health,
## room counter, boss bar, blessing cards, title and end screens, and fades.
## Laid out for a portrait phone.

signal card_picked(index: int)
signal screen_tapped

const STICK_RADIUS := 70.0

var joystick := Vector2.ZERO

var _safe: MarginContainer
var _hp_fill: ColorRect
var _hp_label: Label
var _room_label: Label
var _boss_box: Control
var _boss_fill: ColorRect
var _banner: Label
var _banner_time := 0.0
var _shown_hp := 1.0

var _stick: Joystick
var _stick_touch := -1
var _stick_origin := Vector2.ZERO

var _cards_box: Control
var _cards: Array[Button] = []
var _title_box: Control
var _title_best: Label
var _end_box: Control
var _end_title: Label
var _end_stats: Label
var _pause_box: Control
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_hud()
	_stick = Joystick.new()
	_stick.radius = STICK_RADIUS
	_stick.visible = false
	add_child(_stick)
	_build_cards()
	_build_title()
	_build_end()
	_build_pause()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


# ---------------------------------------------------------------- building

static func label(text: String, size: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = col
	s.outline_size = maxi(4, size / 8)
	s.outline_color = Color(0, 0, 0, 0.85)
	l.label_settings = s
	return l


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func overlay(dim: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = dim
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.visible = false
	return r


func _bar(parent: Control, fill_col: Color) -> ColorRect:
	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0.65)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(0.15, 0.05, 0.06, 0.9)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.offset_left = 3
	back.offset_top = 3
	back.offset_right = -3
	back.offset_bottom = -3
	var fill := ColorRect.new()
	fill.color = fill_col
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return fill


func _build_hud() -> void:
	_safe = MarginContainer.new()
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_safe)
	add_child(_safe)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(root)

	var hp := Control.new()
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.position = Vector2(16, 16)
	hp.size = Vector2(230, 30)
	root.add_child(hp)
	_hp_fill = _bar(hp, Color(0.85, 0.18, 0.22))
	_hp_label = label("100 / 100", 18)
	full(_hp_label)
	hp.add_child(_hp_label)

	_room_label = label("", 22, Color(0.9, 0.85, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	_room_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_room_label.offset_left = -216
	_room_label.offset_right = -16
	_room_label.offset_top = 12
	_room_label.offset_bottom = 48
	root.add_child(_room_label)

	_boss_box = Control.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_box.offset_left = 30
	_boss_box.offset_right = -30
	_boss_box.offset_top = 60
	_boss_box.offset_bottom = 112
	root.add_child(_boss_box)
	var bname := label(SkeletonKing.DISPLAY_NAME, 20, Color(1, 0.8, 0.6))
	bname.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bname.offset_bottom = 26
	_boss_box.add_child(bname)
	var bar_holder := Control.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_holder.offset_top = -22
	_boss_box.add_child(bar_holder)
	_boss_fill = _bar(bar_holder, Color(0.75, 0.1, 0.12))
	_boss_box.visible = false

	_banner = label("", 48, Color(1, 0.9, 0.7))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -260
	_banner.offset_right = 260
	_banner.offset_top = -250
	_banner.offset_bottom = -150
	_banner.modulate.a = 0.0
	root.add_child(_banner)


func _build_cards() -> void:
	_cards_box = overlay(Color(0.02, 0.01, 0.04, 0.85))
	add_child(_cards_box)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_cards_box.add_child(col)
	col.add_child(label("Choose a Blessing", 40, Color(1, 0.85, 0.55)))
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 120)
		b.focus_mode = Control.FOCUS_NONE
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.12, 0.1, 0.16, 0.98)
		normal.border_width_left = 10
		normal.corner_radius_top_left = 10
		normal.corner_radius_top_right = 10
		normal.corner_radius_bottom_left = 10
		normal.corner_radius_bottom_right = 10
		var pressed := normal.duplicate()
		pressed.bg_color = Color(0.2, 0.17, 0.26)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", normal)
		b.add_theme_stylebox_override("pressed", pressed)
		var t := label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		t.position = Vector2(28, 14)
		t.size = Vector2(440, 40)
		b.add_child(t)
		var d := label("", 18, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
		d.position = Vector2(28, 58)
		d.size = Vector2(440, 50)
		b.add_child(d)
		var idx := i
		b.pressed.connect(func(): _on_card(idx))
		col.add_child(b)
		_cards.append(b)


func _build_title() -> void:
	_title_box = overlay(Color(0.01, 0.01, 0.03, 0.55))
	add_child(_title_box)
	var col := VBoxContainer.new()
	full(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)
	_title_box.add_child(col)
	col.add_child(label("CRYPT CRAWL", 64, Color(1, 0.85, 0.55)))
	col.add_child(label("Drag to move. Stand still to shoot.", 20, Color(0.85, 0.85, 0.9)))
	_title_best = label("", 18, Color(0.7, 0.7, 0.8))
	col.add_child(_title_best)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 160)
	col.add_child(spacer)
	var tap := label("Tap to begin", 32)
	tap.set_script(Pulse)
	col.add_child(tap)


func _build_end() -> void:
	_end_box = overlay(Color(0.02, 0, 0.02, 0.75))
	add_child(_end_box)
	var col := VBoxContainer.new()
	full(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 24)
	_end_box.add_child(col)
	_end_title = label("", 60)
	col.add_child(_end_title)
	_end_stats = label("", 22, Color(0.85, 0.85, 0.9))
	col.add_child(_end_stats)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 100)
	col.add_child(spacer)
	var tap := label("Tap to try again", 30)
	tap.set_script(Pulse)
	col.add_child(tap)


func _build_pause() -> void:
	_pause_box = overlay(Color(0, 0, 0, 0.6))
	add_child(_pause_box)
	var l := label("Paused\nTap to continue", 40)
	full(l)
	_pause_box.add_child(l)


func _apply_safe_area() -> void:
	# Keep the HUD clear of notches and rounded corners (phones only).
	if not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var vp := get_viewport().get_visible_rect().size
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return
	var sx := vp.x / win.x
	var sy := vp.y / win.y
	_safe.add_theme_constant_override("margin_left", maxi(0, int(safe.position.x * sx)))
	_safe.add_theme_constant_override("margin_top", maxi(0, int(safe.position.y * sy)))
	_safe.add_theme_constant_override("margin_right", maxi(0, int((win.x - safe.end.x) * sx)))
	_safe.add_theme_constant_override("margin_bottom", maxi(0, int((win.y - safe.end.y) * sy)))


# ---------------------------------------------------------------- input

func _overlay_open() -> bool:
	return _cards_box.visible or _title_box.visible or _end_box.visible or _pause_box.visible


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _title_box.visible or _end_box.visible or _pause_box.visible:
				screen_tapped.emit()
				return
			if _stick_touch == -1 and not _overlay_open() and Game.state == Game.State.PLAYING:
				_stick_touch = t.index
				_stick_origin = t.position
				_stick.visible = true
				_stick.position = _stick_origin
				_stick.knob = Vector2.ZERO
				joystick = Vector2.ZERO
		elif t.index == _stick_touch:
			_release_stick()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_touch:
			var delta := d.position - _stick_origin
			if delta.length() > STICK_RADIUS:
				# If the thumb drags past the edge, the stick follows it.
				_stick_origin += delta - delta.normalized() * STICK_RADIUS
				_stick.position = _stick_origin
				delta = delta.normalized() * STICK_RADIUS
			_stick.knob = delta
			var v := delta / STICK_RADIUS
			joystick = Vector2.ZERO if v.length() < 0.15 else v


func _release_stick() -> void:
	_stick_touch = -1
	_stick.visible = false
	joystick = Vector2.ZERO


func _on_card(i: int) -> void:
	if not _cards_box.visible:
		return
	_cards_box.visible = false
	card_picked.emit(i)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if Game.state != Game.State.PLAYING and _stick_touch != -1:
		_release_stick()
	var hero := Game.hero
	if hero:
		_shown_hp = move_toward(_shown_hp, hero.health / hero.max_health, delta * 1.5)
		_hp_fill.anchor_right = clampf(_shown_hp, 0.0, 1.0)
		_hp_label.text = "%d / %d" % [ceili(hero.health), roundi(hero.max_health)]
	var boss := Game.boss
	if boss and is_instance_valid(boss):
		_boss_fill.anchor_right = clampf(boss.health / boss.max_health, 0.0, 1.0)
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.4, 0.0, 1.0)
		var s := 1.0 + maxf(0.0, _banner_time - 1.6)
		_banner.scale = Vector2(s, s)
		_banner.pivot_offset = _banner.size / 2


# ---------------------------------------------------------------- API used by game.gd

func set_room(index: int, total: int, boss: bool) -> void:
	_room_label.text = "Boss" if boss else "Room %d / %d" % [index, total]
	_boss_box.visible = boss


func hide_boss() -> void:
	_boss_box.visible = false


func banner(text: String, col := Color(1, 0.9, 0.7)) -> void:
	_banner.text = text
	_banner.label_settings.font_color = col
	_banner_time = 2.0


func show_hud(v: bool) -> void:
	_safe.visible = v


func show_cards(choices: Array) -> void:
	for i in _cards.size():
		var b := _cards[i]
		b.visible = i < choices.size()
		if not b.visible:
			continue
		var u: Dictionary = choices[i]
		var labels := b.get_children()
		(labels[0] as Label).text = u.title
		(labels[0] as Label).label_settings.font_color = u.color
		(labels[1] as Label).text = u.text
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		sb.border_color = u.color
	_cards_box.visible = true


func show_title(v: bool, best := "") -> void:
	_title_box.visible = v
	_title_best.text = best


func show_end(v: bool, victory := false, stats := "") -> void:
	_end_box.visible = v
	if not v:
		return
	_end_title.text = "VICTORY" if victory else "YOU DIED"
	_end_title.label_settings.font_color = Color(1, 0.85, 0.4) if victory else Color(0.9, 0.2, 0.2)
	_end_stats.text = stats


func show_pause(v: bool) -> void:
	_pause_box.visible = v


func set_fade(a: float) -> void:
	_fade.color.a = a
