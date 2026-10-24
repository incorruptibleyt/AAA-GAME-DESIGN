class_name Hud
extends CanvasLayer
## Everything on screen that isn't the 3D world: the floating thumb joystick, health,
## room counter, boss bar, blessing cards, title and end screens, and fades.
## Laid out for a portrait phone.

signal card_picked(index: int)
signal reroll_pressed
signal special_pressed
signal dash_pressed
signal screen_tapped
signal pause_pressed
signal play_pressed
signal armory_pressed
signal armory_buy(id: String)
signal heroes_pressed
signal hero_pick(id: String)
signal copy_report_pressed
signal resume_pressed
signal quit_run_pressed
signal retry_pressed
signal music_toggled(on: bool)
signal sounds_toggled(on: bool)
signal graphics_toggled(high: bool)
signal dash_flicked(dir: Vector2)

## A quick flick of the thumb (short and fast) is a dash rather than a step.
const FLICK_TIME := 0.22
const FLICK_DISTANCE := 45.0

const GOLD := Color(1.0, 0.8, 0.3)

const STICK_RADIUS := 70.0

var joystick := Vector2.ZERO

var _safe: MarginContainer
var _hp_fill: ColorRect
var _hp_label: Label
var _room_label: Label
var _boss_box: Control
var _boss_fill: ColorRect
var _banner: Label
var _wave_label: Label
var _banner_time := 0.0
var _shown_hp := 1.0

var _stick: Joystick
var _stick_touch := -1
var _stick_origin := Vector2.ZERO

var _cards_box: Control
var _cards: Array[Button] = []
var _reroll_button: Button
var _special: SpecialButton
var _dash_button: DashButton
var _quit_button: Button
var _quit_armed := false
var _title_box: Control
var _title_best: Label
var _end_box: Control
var _end_title: Label
var _end_stats: Label
var _pause_box: Control
var _pause_button: Button
var _danger: TextureRect
var _hint: Label
var _end_tap: Label
var _boss_name: Label
var _cards_age := 0.0
var _fade: ColorRect
var _coin_label: Label
var _title_coins: Label
var _armory_box: Control
var _armory_coins: Label
var _armory_rows: VBoxContainer
var _shop_heroes := false
var _shop_title: Label
var _shop_sub: Label
var _title_hero: Label
var _copy_button: Button
var _end_buttons: Control
var _music_button: Button
var _sounds_button: Button
var _music_on := true
var _sounds_on := true
var _graphics_button: Button
var _graphics_high := true
var _stick_start := Vector2.ZERO
var _stick_age := 0.0
var _chain_box: Control
var _chain_label: Label
var _chain_fill: ColorRect
var _chain_pop := 0.0
var _callout: Label
var _callout_time := 0.0
var _boss_card: Control
var _boss_card_title: Label
var _boss_card_sub: Label
var _flash: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_danger()
	_build_hud()
	_stick = Joystick.new()
	_stick.radius = STICK_RADIUS
	_stick.visible = false
	add_child(_stick)
	_build_cards()
	_build_title()
	_build_end()
	_build_pause()
	_build_armory()
	_build_boss_card()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
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


static func button(text: String, size := 28, bg := Color(0.16, 0.12, 0.2, 0.95), border := Color(1, 0.8, 0.45, 0.6)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 74)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(1, 0.93, 0.8))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 0.93, 0.8))
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(14)
	normal.set_border_width_all(2)
	normal.border_color = border
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.lightened(0.2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	return b


## A little gold coin drawn with a rounded box.
static func coin_icon(size: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD
	sb.set_corner_radius_all(int(size / 2))
	sb.set_border_width_all(maxi(2, int(size / 8)))
	sb.border_color = Color(0.65, 0.42, 0.08)
	p.add_theme_stylebox_override("panel", sb)
	return p


## A coin icon with a number next to it.
static func coin_row(text_size: int, parent: Control, centered := false) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	if centered:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(row)
	var icon := coin_icon(text_size * 0.9)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l := label("0", text_size, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	return l


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
	add_child(EdgeMarkers.new())
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

	var coins := Control.new()
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins.position = Vector2(18, 52)
	coins.size = Vector2(200, 30)
	root.add_child(coins)
	_coin_label = coin_row(22, coins)

	_room_label = label("", 22, Color(0.9, 0.85, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	_room_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_room_label.offset_left = -276
	_room_label.offset_right = -76
	_room_label.offset_top = 12
	_room_label.offset_bottom = 48
	root.add_child(_room_label)

	_wave_label = label("", 20, Color(1, 0.62, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
	_wave_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_label.offset_left = -276
	_wave_label.offset_right = -76
	_wave_label.offset_top = 44
	_wave_label.offset_bottom = 74
	_wave_label.visible = false
	root.add_child(_wave_label)

	_special = SpecialButton.new()
	_special.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_special.offset_left = -124
	_special.offset_right = -24
	_special.offset_top = -260
	_special.offset_bottom = -160
	root.add_child(_special)

	_dash_button = DashButton.new()
	_dash_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dash_button.offset_left = -114
	_dash_button.offset_right = -34
	_dash_button.offset_top = -380
	_dash_button.offset_bottom = -300
	root.add_child(_dash_button)

	_pause_button = Button.new()
	_pause_button.text = "II"
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.add_theme_font_size_override("font_size", 22)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(0, 0, 0, 0.45)
	pb.set_corner_radius_all(26)
	_pause_button.add_theme_stylebox_override("normal", pb)
	_pause_button.add_theme_stylebox_override("hover", pb)
	_pause_button.add_theme_stylebox_override("pressed", pb)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_left = -66
	_pause_button.offset_right = -14
	_pause_button.offset_top = 6
	_pause_button.offset_bottom = 58
	_pause_button.pressed.connect(func(): pause_pressed.emit())
	root.add_child(_pause_button)

	# A tip in the empty space at the bottom of the screen during the first room.
	_hint = label("", 24, Color(1, 0.92, 0.75))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -150
	_hint.offset_bottom = -90
	_hint.set_script(Pulse)
	_hint.visible = false
	root.add_child(_hint)

	_boss_box = Control.new()
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_box.offset_left = 30
	_boss_box.offset_right = -30
	_boss_box.offset_top = 60
	_boss_box.offset_bottom = 112
	root.add_child(_boss_box)
	_boss_name = label(SkeletonKing.DISPLAY_NAME, 20, Color(1, 0.8, 0.6))
	_boss_name.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name.offset_bottom = 26
	_boss_box.add_child(_boss_name)
	var bar_holder := Control.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_holder.offset_top = -22
	_boss_box.add_child(bar_holder)
	_boss_fill = _bar(bar_holder, Color(0.75, 0.1, 0.12))
	_boss_box.visible = false

	# The kill combo counter, under the room label on the right.
	# Bone Chain: a big multiplier at the top with a bar that drains until the next kill.
	_chain_box = Control.new()
	_chain_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chain_box.offset_left = -130
	_chain_box.offset_right = 130
	_chain_box.offset_top = 92
	_chain_box.offset_bottom = 158
	_chain_box.modulate.a = 0.0
	root.add_child(_chain_box)
	_chain_label = label("", 40, Color(1, 0.85, 0.4))
	_chain_label.size = Vector2(260, 52)
	_chain_label.pivot_offset = Vector2(130, 26)
	_chain_box.add_child(_chain_label)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.55)
	bar_bg.position = Vector2(55, 54)
	bar_bg.size = Vector2(150, 7)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_box.add_child(bar_bg)
	_chain_fill = ColorRect.new()
	_chain_fill.position = Vector2(55, 54)
	_chain_fill.size = Vector2(150, 7)
	_chain_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_box.add_child(_chain_fill)

	_callout = label("", 46, Color(0.6, 0.95, 1.0))
	_callout.set_anchors_preset(Control.PRESET_CENTER)
	_callout.offset_left = -220
	_callout.offset_right = 220
	_callout.offset_top = -330
	_callout.offset_bottom = -270
	_callout.modulate.a = 0.0
	root.add_child(_callout)

	_banner = label("", 48, Color(1, 0.9, 0.7))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -260
	_banner.offset_right = 260
	_banner.offset_top = -250
	_banner.offset_bottom = -150
	_banner.modulate.a = 0.0
	root.add_child(_banner)


## The big title card when a boss appears: black bars, the name, and a line under it.
func _build_boss_card() -> void:
	_boss_card = Control.new()
	_boss_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_boss_card)
	_boss_card.visible = false
	add_child(_boss_card)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.85)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			bar.offset_bottom = 110
		else:
			bar.offset_top = -110
		_boss_card.add_child(bar)
	var stripe := ColorRect.new()
	stripe.color = Color(0, 0, 0, 0.6)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.set_anchors_preset(Control.PRESET_CENTER)
	stripe.offset_left = -400
	stripe.offset_right = 400
	stripe.offset_top = 130
	stripe.offset_bottom = 250
	_boss_card.add_child(stripe)
	_boss_card_title = label("", 46, Color(1, 0.35, 0.25))
	_boss_card_title.set_anchors_preset(Control.PRESET_CENTER)
	_boss_card_title.offset_left = -270
	_boss_card_title.offset_right = 270
	_boss_card_title.offset_top = 136
	_boss_card_title.offset_bottom = 200
	_boss_card.add_child(_boss_card_title)
	_boss_card_sub = label("", 20, Color(0.9, 0.85, 0.8))
	_boss_card_sub.set_anchors_preset(Control.PRESET_CENTER)
	_boss_card_sub.offset_left = -270
	_boss_card_sub.offset_right = 270
	_boss_card_sub.offset_top = 200
	_boss_card_sub.offset_bottom = 240
	_boss_card.add_child(_boss_card_sub)


## A red glow around the screen edges when health is low.
func _build_danger() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0, 0, 0))
	g.set_color(1, Color(0.7, 0, 0, 0.75))
	g.add_point(0.6, Color(0.7, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 128
	tex.height = 128
	_danger = TextureRect.new()
	_danger.texture = tex
	_danger.stretch_mode = TextureRect.STRETCH_SCALE
	_danger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_danger)
	_danger.modulate.a = 0.0
	add_child(_danger)


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
		t.position = Vector2(96, 12)
		t.size = Vector2(250, 40)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_child(t)
		var d := label("", 18, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
		d.position = Vector2(96, 54)
		d.size = Vector2(370, 56)
		b.add_child(d)
		var icon := BlessingIcon.new()
		icon.position = Vector2(22, 28)
		b.add_child(icon)
		var r := label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		r.anchor_left = 1.0
		r.anchor_right = 1.0
		r.offset_left = -130
		r.offset_right = -14
		r.offset_top = 10
		r.offset_bottom = 30
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_child(r)
		var idx := i
		b.pressed.connect(func(): _on_card(idx))
		col.add_child(b)
		_cards.append(b)
	_reroll_button = button("Reroll", 22)
	_reroll_button.custom_minimum_size = Vector2(220, 60)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.pressed.connect(func():
		if _cards_age >= 0.45:
			reroll_pressed.emit())
	col.add_child(_reroll_button)


func _build_title() -> void:
	_title_box = overlay(Color(0.01, 0.01, 0.03, 0.55))
	add_child(_title_box)
	var col := VBoxContainer.new()
	full(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)
	_title_box.add_child(col)
	col.add_child(label("BONE CHAIN", 64, Color(1, 0.85, 0.55)))
	col.add_child(label("Drag to move. Stand still to shoot.", 20, Color(0.85, 0.85, 0.9)))
	_title_best = label("", 18, Color(0.7, 0.7, 0.8))
	col.add_child(_title_best)
	_title_coins = coin_row(26, col, true)
	_title_hero = label("", 20, Color(0.75, 0.85, 1.0))
	col.add_child(_title_hero)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)
	var play := button("PLAY", 38, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	play.custom_minimum_size = Vector2(300, 92)
	play.pressed.connect(func(): play_pressed.emit())
	col.add_child(_centered(play))
	var heroes := button("HEROES", 28)
	heroes.pressed.connect(func(): heroes_pressed.emit())
	col.add_child(_centered(heroes))
	var armory := button("ARMORY", 28)
	armory.pressed.connect(func(): armory_pressed.emit())
	col.add_child(_centered(armory))


func _centered(c: Control) -> Control:
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return box


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
	# Copies a detailed report of the run, to paste to Claude for balancing.
	_copy_button = button("COPY RUN REPORT", 20, Color(0.1, 0.12, 0.18, 0.95), Color(0.5, 0.75, 1.0, 0.7))
	_copy_button.custom_minimum_size = Vector2(300, 56)
	_copy_button.pressed.connect(func():
		_copy_button.text = "Copied! Paste it to Claude"
		copy_report_pressed.emit())
	col.add_child(_centered(_copy_button))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 100)
	col.add_child(spacer)
	_end_tap = label("Tap to try again", 30)
	_end_tap.set_script(Pulse)
	col.add_child(_end_tap)
	var buttons := VBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 18)
	col.add_child(buttons)
	var retry := button("TRY AGAIN", 32, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	retry.custom_minimum_size = Vector2(300, 86)
	retry.pressed.connect(func(): retry_pressed.emit())
	buttons.add_child(_centered(retry))
	var heroes := button("HEROES", 26)
	heroes.pressed.connect(func(): heroes_pressed.emit())
	buttons.add_child(_centered(heroes))
	var armory := button("ARMORY", 26)
	armory.pressed.connect(func(): armory_pressed.emit())
	buttons.add_child(_centered(armory))
	_end_buttons = buttons


func _build_pause() -> void:
	_pause_box = overlay(Color(0, 0, 0, 0.7))
	add_child(_pause_box)
	var col := VBoxContainer.new()
	full(col)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_pause_box.add_child(col)
	col.add_child(label("Paused", 52, Color(1, 0.85, 0.55)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	col.add_child(gap)
	var resume := button("RESUME", 32, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	resume.custom_minimum_size = Vector2(300, 86)
	resume.pressed.connect(func(): resume_pressed.emit())
	col.add_child(_centered(resume))
	_music_button = button("Music: On", 26)
	_music_button.pressed.connect(func(): music_toggled.emit(not _music_on))
	col.add_child(_centered(_music_button))
	_sounds_button = button("Sounds: On", 26)
	_sounds_button.pressed.connect(func(): sounds_toggled.emit(not _sounds_on))
	col.add_child(_centered(_sounds_button))
	_graphics_button = button("Graphics: High", 26)
	_graphics_button.pressed.connect(func(): graphics_toggled.emit(not _graphics_high))
	col.add_child(_centered(_graphics_button))
	_quit_button = button("Quit run", 24, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_quit_button.pressed.connect(_on_quit_pressed)
	col.add_child(_centered(_quit_button))


## Quitting loses the run, so the first tap only asks; a second tap within 3 s quits.
func _on_quit_pressed() -> void:
	if _quit_armed:
		_disarm_quit()
		quit_run_pressed.emit()
		return
	_quit_armed = true
	_quit_button.text = "Tap again to quit"
	_quit_button.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	get_tree().create_timer(3.0, true, false, true).timeout.connect(_disarm_quit)


func _disarm_quit() -> void:
	_quit_armed = false
	_quit_button.text = "Quit run"
	_quit_button.add_theme_color_override("font_color", Color(1, 0.93, 0.8))


## The shop for permanent upgrades, opened from the title or death screen.
func _build_armory() -> void:
	_armory_box = overlay(Color(0.03, 0.02, 0.05, 0.94))
	add_child(_armory_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_armory_box.add_child(col)
	_shop_title = label("Armory", 46, Color(1, 0.85, 0.55))
	col.add_child(_shop_title)
	_shop_sub = label("Upgrades bought here last forever.", 18, Color(0.8, 0.8, 0.85))
	col.add_child(_shop_sub)
	_armory_coins = coin_row(30, col, true)
	_armory_rows = VBoxContainer.new()
	_armory_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armory_rows.add_theme_constant_override("separation", 8)
	col.add_child(_armory_rows)
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_armory(false))
	col.add_child(_centered(back))


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
	return _cards_box.visible or _title_box.visible or _end_box.visible or _pause_box.visible or _armory_box.visible


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _end_box.visible and not _end_buttons.visible and not _armory_box.visible \
					and not _copy_button.get_global_rect().has_point(t.position):
				screen_tapped.emit()
				return
			if _safe.visible and _pause_button.get_global_rect().has_point(t.position):
				return
			if _safe.visible and _special.visible and not _overlay_open() \
					and _special.get_global_rect().grow(12.0).has_point(t.position):
				special_pressed.emit()
				return
			if _safe.visible and _dash_button.visible and not _overlay_open() \
					and _dash_button.get_global_rect().grow(12.0).has_point(t.position):
				dash_pressed.emit()
				return
			if _stick_touch == -1 and not _overlay_open() and Game.state == Game.State.PLAYING:
				_stick_touch = t.index
				_stick_origin = t.position
				_stick_start = t.position
				_stick_age = 0.0
				_stick.visible = true
				_stick.position = _stick_origin
				_stick.knob = Vector2.ZERO
				joystick = Vector2.ZERO
		elif t.index == _stick_touch:
			var flick := t.position - _stick_start
			if _stick_age < FLICK_TIME and flick.length() > FLICK_DISTANCE:
				dash_flicked.emit(flick.normalized())
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
	# Ignore taps in the first moment so a thumb that was moving doesn't pick by accident.
	if not _cards_box.visible or _cards_age < 0.45:
		return
	_cards_box.visible = false
	card_picked.emit(i)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_cards_age += delta
	_stick_age += delta
	if _flash.color.a > 0.0:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	var chained := Game.chain > 1.01 and Game.state == Game.State.PLAYING
	_chain_box.modulate.a = move_toward(_chain_box.modulate.a, 1.0 if chained else 0.0, delta * (8.0 if chained else 3.0))
	if chained:
		_chain_fill.size.x = 150.0 * clampf(Game._combo_left / Game.chain_time(), 0.0, 1.0)
	_chain_pop = move_toward(_chain_pop, 0.0, delta * 3.0)
	var pulse := 1.0 + _chain_pop * 0.5 + (0.04 * sin(Time.get_ticks_msec() * 0.012) if Game.chain >= Game.chain_max() else 0.0)
	_chain_label.scale = Vector2(pulse, pulse)
	if _callout_time > 0.0:
		_callout_time -= delta
		_callout.modulate.a = clampf(_callout_time / 0.3, 0.0, 1.0)
		var cs := 1.0 + maxf(0.0, _callout_time - 0.8) * 3.0
		# Never let the pop grow past the screen edges (long callouts on narrow phones).
		cs = minf(cs, maxf(1.0, (get_viewport().get_visible_rect().size.x - 24.0) / maxf(_callout.size.x, 1.0)))
		_callout.pivot_offset = _callout.size / 2
		_callout.scale = Vector2(cs, cs)
	if Game.state != Game.State.PLAYING and _stick_touch != -1:
		_release_stick()
	var hero := Game.hero
	if hero:
		_shown_hp = move_toward(_shown_hp, hero.health / hero.max_health, delta * 1.5)
		_hp_fill.anchor_right = clampf(_shown_hp, 0.0, 1.0)
		_hp_label.text = "%d / %d" % [ceili(hero.health), roundi(hero.max_health)]
		var low := 1.0 - clampf(hero.health / hero.max_health / 0.35, 0.0, 1.0)
		if hero.dead or not _safe.visible:
			low = 0.0
		var beat := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		_danger.modulate.a = move_toward(_danger.modulate.a, low * beat, delta * 3.0)
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

func set_room(index: int, total: int, boss: bool, floor_num := 1) -> void:
	_room_label.text = "Boss" if boss else "Room %d / %d" % [index, total]
	if floor_num > 1:
		_room_label.text = "F%d · %s" % [floor_num, _room_label.text]
	_boss_box.visible = boss


func set_boss_name(n: String) -> void:
	_boss_name.text = n


func hide_boss() -> void:
	_boss_box.visible = false


## "Wave 2 / 3" under the room name; hidden in one-wave rooms.
func set_wave(wave: int, total: int) -> void:
	_wave_label.visible = total > 1
	_wave_label.text = "Wave %d / %d" % [wave, total]


func clear_banner() -> void:
	_banner_time = 0.0
	_banner.modulate.a = 0.0


func banner(text: String, col := Color(1, 0.9, 0.7)) -> void:
	_banner.text = text
	_banner.label_settings.font_color = col
	_banner.label_settings.font_size = 48 if text.length() <= 16 else 38
	_banner_time = 2.0


## Shows "CHAIN x1.8". Gold, then orange from x2, then white-hot and pulsing at x3.
func show_chain(mult: float) -> void:
	if mult <= 1.01:
		return
	_chain_label.text = "CHAIN x%.1f" % mult
	var col := Color(1, 0.85, 0.4) if mult < 2.0 else (Color(1, 0.55, 0.2) if mult < Game.chain_max() else Color(1, 0.97, 0.85))
	_chain_label.label_settings.font_color = col
	_chain_fill.color = col
	_chain_pop = 0.35 if mult < Game.chain_max() else 0.6


## A short punchy word over the action, like "PERFECT!".
func callout(text: String, col := Color(0.6, 0.95, 1.0)) -> void:
	_callout.text = text
	_callout.label_settings.font_color = col
	_callout.label_settings.font_size = 46 if text.length() <= 10 else 34
	_callout_time = 1.1


## A quick white (or coloured) flash over the whole screen.
func flash(col := Color(1, 1, 1), strength := 0.6) -> void:
	_flash.color = Color(col.r, col.g, col.b, strength)


func show_boss_card(title: String, subtitle: String) -> void:
	_boss_card_title.text = title.to_upper()
	_boss_card_sub.text = subtitle
	_boss_card.visible = true
	_boss_card.modulate.a = 0.0
	_boss_card_title.scale = Vector2(1.6, 1.6)
	_boss_card_title.pivot_offset = _boss_card_title.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(_boss_card, "modulate:a", 1.0, 0.25)
	tw.tween_property(_boss_card_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_boss_card() -> void:
	if not _boss_card.visible:
		return
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_boss_card, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): _boss_card.visible = false)


func show_hud(v: bool) -> void:
	_safe.visible = v


## Each card shows the family icon, the title in the family colour, and the rarity
## as a tag and border colour. `rerolls` is how many free rerolls are left.
func show_cards(choices: Array, rerolls := 0) -> void:
	for i in _cards.size():
		var b := _cards[i]
		b.visible = i < choices.size()
		if not b.visible:
			continue
		var u: Dictionary = choices[i]
		var rar: Dictionary = Upgrades.RARITIES[u.rarity]
		var labels := b.get_children()
		(labels[0] as Label).text = u.title
		(labels[0] as Label).label_settings.font_color = Upgrades.color(u)
		(labels[1] as Label).text = u.text
		(labels[2] as BlessingIcon).show_for(u)
		(labels[3] as Label).text = "%s · %s" % [Upgrades.FAMILIES[u.family].name.to_upper(), rar.name]
		(labels[3] as Label).label_settings.font_color = rar.color
		for sb_name in ["normal", "pressed"]:
			var sb := b.get_theme_stylebox(sb_name) as StyleBoxFlat
			sb.border_color = rar.color
			var edge := 0 if u.rarity == "common" else (2 if u.rarity == "rare" else 3)
			sb.border_width_top = edge
			sb.border_width_right = edge
			sb.border_width_bottom = edge
	_reroll_button.visible = rerolls > 0
	_reroll_button.text = "Reroll (%d left)" % rerolls
	_cards_box.visible = true
	_cards_age = 0.0


func show_title(v: bool, best := "", coins := 0) -> void:
	_title_box.visible = v
	_title_best.text = best
	_title_coins.text = str(coins)


func title_visible() -> bool:
	return _title_box.visible


func set_coins(n: int) -> void:
	_coin_label.text = str(n)
	_title_coins.text = str(n)


func set_toggles(music: bool, sounds: bool) -> void:
	_music_on = music
	_sounds_on = sounds
	_music_button.text = "Music: On" if music else "Music: Off"
	_sounds_button.text = "Sounds: On" if sounds else "Sounds: Off"


func set_graphics_label(high: bool) -> void:
	_graphics_high = high
	_graphics_button.text = "Graphics: High" if high else "Graphics: Low"


func armory_visible() -> bool:
	return _armory_box.visible


## rows: [{id, title, text, level, max, cost}] where cost is -1 once maxed out.
func show_armory(v: bool, rows := [], coins := 0) -> void:
	_armory_box.visible = v
	if not v:
		return
	_shop_heroes = false
	_shop_title.text = "Armory"
	_shop_sub.text = "Upgrades bought here last forever."
	_fill_shop(rows, coins)


## rows: [{id, title, text, cost, unlocked, selected}]
func show_heroes(v: bool, rows := [], coins := 0) -> void:
	_armory_box.visible = v
	if not v:
		return
	_shop_heroes = true
	_shop_title.text = "Heroes"
	_shop_sub.text = "Tap a hero to play as them. Unlock new ones with coins."
	_fill_shop(rows, coins)


func set_title_hero(hero_name: String) -> void:
	_title_hero.text = "Playing as the " + hero_name


func _fill_shop(rows: Array, coins: int) -> void:
	_armory_coins.text = str(coins)
	for c in _armory_rows.get_children():
		c.queue_free()
	for r: Dictionary in rows:
		_armory_rows.add_child(_hero_row(r, coins) if _shop_heroes else _armory_row(r, coins))


func _hero_row(r: Dictionary, coins: int) -> Button:
	var owned: bool = r.unlocked
	var afford: bool = owned or r.cost <= coins
	var border := Color(0.5, 0.85, 1.0) if r.selected else (GOLD if afford else Color(0.4, 0.35, 0.45, 0.6))
	var b := button("", 20, Color(0.12, 0.1, 0.16, 0.98), border)
	b.custom_minimum_size = Vector2(0, 104)
	if r.selected:
		(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(4)
	b.pressed.connect(func(): hero_pick.emit(r.id))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	full(m)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	m.add_child(h)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	h.add_child(texts)
	var t := label(r.title, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var d := label(r.text, 16, Color(0.78, 0.78, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	d.custom_minimum_size = Vector2(300, 0)
	texts.add_child(d)
	if r.selected or owned:
		var tag := label("CHOSEN" if r.selected else "PICK", 20 if r.selected else 22, Color(0.5, 0.85, 1.0) if r.selected else Color(0.6, 1, 0.6))
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(tag)
	else:
		var price := HBoxContainer.new()
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(price)
		var cost_label := coin_row(24, price)
		cost_label.text = str(r.cost)
		if not afford:
			cost_label.label_settings.font_color = Color(0.6, 0.55, 0.5)
	return b


func _armory_row(r: Dictionary, coins: int) -> Button:
	var maxed: bool = r.cost < 0
	var afford: bool = not maxed and r.cost <= coins
	var b := button("", 20, Color(0.12, 0.1, 0.16, 0.98), GOLD if afford else Color(0.4, 0.35, 0.45, 0.6))
	b.custom_minimum_size = Vector2(0, 76)
	b.pressed.connect(func(): armory_buy.emit(r.id))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	full(m)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var pips := "" if r.max <= 1 else "   " + "■".repeat(r.level) + "□".repeat(r.max - r.level)
	var t := label(r.title + pips, 22, Color.WHITE if not maxed else Color(0.7, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var d := label(r.text, 16, Color(0.78, 0.78, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(d)
	if maxed:
		h.add_child(label("OWNED" if r.max <= 1 else "MAX", 22, Color(0.6, 1, 0.6)))
	else:
		var price := HBoxContainer.new()
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(price)
		var cost_label := coin_row(24, price)
		cost_label.text = str(r.cost)
		if not afford:
			cost_label.label_settings.font_color = Color(0.6, 0.55, 0.5)
	return b


func show_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


func show_end(v: bool, victory := false, stats := "", tap_text := "Tap to try again", buttons := false) -> void:
	_end_box.visible = v
	if not v:
		return
	_end_tap.text = tap_text
	_copy_button.text = "COPY RUN REPORT"
	_end_tap.visible = not buttons
	_end_buttons.visible = buttons
	_end_title.text = "VICTORY" if victory else "YOU DIED"
	_end_title.label_settings.font_color = Color(1, 0.85, 0.4) if victory else Color(0.9, 0.2, 0.2)
	_end_stats.text = stats


func show_pause(v: bool) -> void:
	_pause_box.visible = v
	if _quit_armed:
		_disarm_quit()


func set_fade(a: float) -> void:
	_fade.color.a = a
