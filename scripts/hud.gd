class_name Hud
extends CanvasLayer
## Everything on screen that isn't the 3D world: the floating thumb joystick, health,
## room counter, boss bar, blessing cards, title and end screens, and fades.
## Laid out for a portrait phone.

signal tutorial_pressed
signal card_picked(index: int)
signal reroll_pressed
signal door_picked(index: int)
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
signal reports_toggled(on: bool)
signal dash_flicked(dir: Vector2)
signal pass_pressed
signal pass_buy
signal pass_restore
signal daily_pressed
signal curses_pressed
signal curse_toggled(id: String)
signal title_pressed
signal daily_start
signal continue_pressed
signal hero_trial(id: String)
signal share_pressed
signal loop_deeper
signal loop_bank
signal omen_picked(id: String)
signal reports_answered(on: bool)

## A quick flick of the thumb (short and fast) is a dash rather than a step.
const FLICK_TIME := 0.22
const FLICK_DISTANCE := 45.0

const GOLD := Color(1.0, 0.8, 0.3)
## The game's name on the title screen (and in the opening animation, which lands on it), drawn
## by tools/store/make_logo.py at twice the size it is shown, glow and edge included.
const LOGO := preload("res://art/ui/logo.png")
const LOGO_WIDTH := 490.0

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
## Doors (doors.gd): two to pick from after a blessing.
var _doors_box: Control
var _door_buttons: Array[Button] = []
var _doors_next: Label
var _doors_age := 0.0
var _special: SpecialButton
var _dash_button: DashButton
var _quit_button: Button
var _quit_armed := false
var _title_box: Control
var _title_logo: TextureRect
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
var _shop_title: Label
var _shop_sub: Label
## The Armory's two tabs: UPGRADES and the VAULT (new blessings), and the rows last shown.
var _armory_tabs: Control
var _tab_buttons := {}
var _armory_tab := "upgrades"
var _shop_rows: Array = []
var _shop_coins := 0
var _title_hero: Label
var _copy_button: Button
var _end_buttons: Control
var _music_button: Button
var _sounds_button: Button
var _music_on := true
var _sounds_on := true
var _graphics_button: Button
var _graphics_high := true
var _reports_button: Button
var _reports_on := false
var _hud_before_end := false
var _stick_start := Vector2.ZERO
var _stick_age := 0.0
var _chain_box: Control
var _chain_label: Label
var _chain_pop := 0.0
var _spine: ChainSpine
var _score_label: Label
var _broken_label: Label
var _broken_time := 0.0
var _tip: Label
var _tip_time := 0.0
var _tip_delay := 0.0
var _shown_score := 0.0
var _end_score: Label
var _end_best: Label
var _end_target := 0
var _end_count := -1.0
var _end_best_value := 0
var _title_heroes: Control
var _title_armory: Control
var _title_lock: Label
var _title_shop_row: Control
var _title_pass_row: Control
var _title_modes_row: Control
var _title_modes_badge: Label
var _modes_box: Control
var _mode_daily_text: Label
var _mode_daily_tag: Label
var _mode_curses_tag: Label
var _modes_tutorial: Button
var _heroes_box: HeroScreen
var _end_offer: Control
var _pass_box: Control
var _pass_buy: Button
var _pass_status: Label
var _pass_restore: Button
var _shop_curses := false
var _title_free: Label
var _title_play: Button
var _title_continue: Control
var _continue_where: Label
var _title_spacer: Control
var _timer_label: Label
var _share_button: Button
var _share_card: ShareCard
var _end_pass: Control
var _end_spacer: Control
var _daily_box: Control
var _daily_title: Label
var _daily_theme: Label
var _daily_info: Label
var _daily_rules: VBoxContainer
var _daily_status: Label
var _daily_go: Button
var _daily_next: Label
var _daily_open := false
var _pass_tiles: Array[Label] = []
var _pass_dev: Label
var _pass_back: Button
var _end_loop: Control
var _loop_deeper_button: Button
var _loop_bank_button: Button
var _omen_box: Control
var _ask_box: Control
var _omen_info: Label
var _omen_rows: VBoxContainer
var _omen_have: Label
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
	_build_doors()
	_build_title()
	_build_end()
	_build_pause()
	_build_modes()
	_build_armory()
	_build_heroes()
	_build_daily()
	_build_omens()
	_build_reports_ask()
	_build_pass()
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


## The logo picture's size on screen.
static func logo_size() -> Vector2:
	return Vector2(LOGO_WIDTH, LOGO_WIDTH * LOGO.get_height() / LOGO.get_width())


## The logo picture, at its size on screen.
static func logo_rect() -> TextureRect:
	var r := TextureRect.new()
	r.texture = LOGO
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = logo_size()
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func title_logo() -> Control:
	return _title_logo


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
## A small "Privacy policy" button that opens the policy page in the browser.
static func privacy_button() -> Button:
	var b := button("Privacy policy", 18, Color(0.08, 0.07, 0.1, 0.85), Color(0.6, 0.55, 0.6, 0.4))
	b.add_theme_color_override("font_color", Color(0.75, 0.72, 0.78))
	b.custom_minimum_size = Vector2(200, 48)
	b.pressed.connect(func(): OS.shell_open(Game.PRIVACY_URL))
	return b


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

	# The Hourglass curse's countdown, under the wave counter.
	_timer_label = label("", 20, Color(1, 0.75, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.offset_left = -276
	_timer_label.offset_right = -76
	_timer_label.offset_top = 72
	_timer_label.offset_bottom = 100
	_timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_timer_label.visible = false
	root.add_child(_timer_label)

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

	# Bone Chain: a spine of six vertebrae across the top, the multiplier under it, and
	# the run score under that. The cord behind the bones drains until the next kill.
	_chain_box = Control.new()
	_chain_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_chain_box.offset_left = -160
	_chain_box.offset_right = 160
	_chain_box.offset_top = 88
	_chain_box.offset_bottom = 210
	_chain_box.modulate.a = 0.0
	root.add_child(_chain_box)
	_spine = ChainSpine.new()
	_spine.position = Vector2(10, 0)
	_spine.size = Vector2(300, 46)
	_chain_box.add_child(_spine)
	_chain_label = label("x1.0", 46, ChainSpine.BONE)
	_chain_label.position = Vector2(0, 42)
	_chain_label.size = Vector2(320, 54)
	_chain_label.pivot_offset = Vector2(160, 27)
	_chain_box.add_child(_chain_label)
	_score_label = label("", 18, Color(0.85, 0.82, 0.75))
	_score_label.position = Vector2(0, 94)
	_score_label.size = Vector2(320, 24)
	_chain_box.add_child(_score_label)
	_broken_label = label("", 30, Color(1, 0.35, 0.3))
	_broken_label.position = Vector2(-40, 44)
	_broken_label.size = Vector2(400, 44)
	_broken_label.modulate.a = 0.0
	_chain_box.add_child(_broken_label)

	# First-run tips ("Kill fast. Your chain grows.") sit just under the chain meter.
	_tip = label("", 22, Color(1, 0.95, 0.8))
	_tip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tip.offset_left = -240
	_tip.offset_right = 240
	_tip.offset_top = 214
	_tip.offset_bottom = 274
	_tip.label_settings.outline_size = 6
	_tip.label_settings.outline_color = Color(0, 0, 0, 0.85)
	_tip.visible = false
	root.add_child(_tip)

	_callout = label("", 46, Color(0.6, 0.95, 1.0))
	_callout.set_anchors_preset(Control.PRESET_CENTER)
	_callout.offset_left = -220
	_callout.offset_right = 220
	_callout.offset_top = -190
	_callout.offset_bottom = -130
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


## Two tall arched doors side by side, each with a picture, a name and what it promises.
func _build_doors() -> void:
	_doors_box = overlay(Color(0.02, 0.01, 0.04, 0.9))
	add_child(_doors_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(col)
	col.offset_left = 20
	col.offset_right = -20
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	_doors_box.add_child(col)
	col.add_child(label("Choose your door", 40, Color(1, 0.85, 0.55)))
	_doors_next = label("", 18, Color(0.78, 0.78, 0.86))
	col.add_child(_doors_next)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	for i in 2:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(232, 380)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.09, 0.07, 0.12, 0.98)
		normal.corner_radius_top_left = 116
		normal.corner_radius_top_right = 116
		normal.corner_radius_bottom_left = 6
		normal.corner_radius_bottom_right = 6
		normal.set_border_width_all(5)
		normal.shadow_color = Color(0, 0, 0, 0.5)
		normal.shadow_size = 8
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.2, 0.17, 0.26)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", normal)
		b.add_theme_stylebox_override("pressed", pressed)
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		full(inner)
		inner.offset_left = 14
		inner.offset_right = -14
		inner.offset_top = 44
		inner.offset_bottom = -20
		inner.add_theme_constant_override("separation", 16)
		b.add_child(inner)
		# A darker doorway inside the frame.
		var way := Panel.new()
		way.mouse_filter = Control.MOUSE_FILTER_IGNORE
		full(way)
		way.offset_left = 16
		way.offset_right = -16
		way.offset_top = 16
		var way_sb := StyleBoxFlat.new()
		way_sb.bg_color = Color(0.03, 0.02, 0.05, 0.95)
		way_sb.corner_radius_top_left = 100
		way_sb.corner_radius_top_right = 100
		way_sb.set_border_width_all(2)
		way.add_theme_stylebox_override("panel", way_sb)
		b.add_child(way)
		b.move_child(way, 0)
		var icon := BlessingIcon.new()
		icon.zoom = 1.6
		inner.add_child(_centered(icon))
		inner.add_child(label("", 25, Color.WHITE))
		inner.add_child(label("", 18, Color(0.85, 0.85, 0.9)))
		var idx := i
		b.pressed.connect(func(): _on_door(idx))
		row.add_child(b)
		_door_buttons.append(b)


## doors: Doors.describe() of each door. `boss_next`: the boss waits behind them.
func show_doors(doors: Array, boss_next := false) -> void:
	_doors_next.text = "The boss waits beyond either one" if boss_next else "Both lead on to the next room"
	for i in _door_buttons.size():
		var b := _door_buttons[i]
		b.visible = i < doors.size()
		if not b.visible:
			continue
		var d: Dictionary = doors[i]
		var inner := b.get_child(1)
		((b.get_child(0) as Panel).get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(d.color, 0.35)
		(inner.get_child(0).get_child(0) as BlessingIcon).show_icon(d.icon, d.family, d.color)
		var t := inner.get_child(1) as Label
		t.text = d.title
		t.label_settings.font_color = d.color
		(inner.get_child(2) as Label).text = d.text
		for sb_name in ["normal", "pressed"]:
			(b.get_theme_stylebox(sb_name) as StyleBoxFlat).border_color = d.color
	_doors_box.visible = true
	_doors_age = 0.0


func doors_visible() -> bool:
	return _doors_box.visible


func _on_door(i: int) -> void:
	# The same short guard as the blessing cards, so a moving thumb doesn't pick by accident.
	if not _doors_box.visible or _doors_age < 0.45:
		return
	_doors_box.visible = false
	door_picked.emit(i)


func _build_title() -> void:
	_title_box = overlay(Color(0.01, 0.01, 0.03, 0.55))
	add_child(_title_box)
	# The hero stands in the middle of the screen, so the words sit above them (anchored
	# to the top) and the buttons below (anchored to the bottom), on any phone shape.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(holder)
	_title_box.add_child(holder)
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 30
	top.add_theme_constant_override("separation", 10)
	holder.add_child(top)
	_title_coins = coin_row(26, top)
	(_title_coins.get_parent() as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	top.add_child(gap)
	_title_logo = logo_rect()
	top.add_child(_title_logo)
	top.add_child(label("Drag to move. Stand still to shoot.", 20, Color(0.85, 0.85, 0.9)))
	# Said up front, so nobody is surprised when the free floors end.
	_title_free = label("Free to try: floors 1-%d. The Crypt Pass opens the rest." % Store.FREE_FLOORS, 17, Color(0.95, 0.78, 0.45))
	top.add_child(_title_free)
	_title_best = label("", 18, Color(0.7, 0.7, 0.8))
	top.add_child(_title_best)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_top = -40
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 14)
	holder.add_child(col)
	_title_hero = label("", 20, Color(0.75, 0.85, 1.0))
	col.add_child(_title_hero)
	_title_spacer = Control.new()
	_title_spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(_title_spacer)
	# A saved run (run_save.gd) can be picked up again.
	var cont_col := VBoxContainer.new()
	cont_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_col.add_theme_constant_override("separation", 2)
	var cont := button("CONTINUE", 36, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	cont.add_theme_color_override("font_color", GOLD)
	cont.custom_minimum_size = Vector2(300, 86)
	cont.pressed.connect(func(): continue_pressed.emit())
	cont_col.add_child(_centered(cont))
	_continue_where = label("", 17, Color(0.95, 0.85, 0.6))
	cont_col.add_child(_continue_where)
	_title_continue = cont_col
	col.add_child(cont_col)
	var play := button("PLAY", 38, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	play.custom_minimum_size = Vector2(300, 92)
	play.pressed.connect(func(): _guarded(play, play_pressed))
	_title_play = play
	col.add_child(_centered(play))
	var heroes := button("HEROES", 26)
	heroes.custom_minimum_size = Vector2(222, 74)
	heroes.pressed.connect(func(): heroes_pressed.emit())
	_title_heroes = heroes
	var armory := button("ARMORY", 26)
	armory.custom_minimum_size = Vector2(222, 74)
	armory.pressed.connect(func(): armory_pressed.emit())
	_title_armory = armory
	_title_shop_row = _pair(heroes, armory)
	col.add_child(_title_shop_row)
	# MODES holds the Daily Crypt, Curses and the tutorial run; then the Crypt Pass.
	var modes := button("MODES", 26)
	modes.custom_minimum_size = Vector2(222, 74)
	modes.pressed.connect(func(): show_modes(true))
	# A little gold tag when today's Daily Crypt is waiting.
	_title_modes_badge = label("DAILY READY", 13, Color(0.12, 0.08, 0.02))
	_title_modes_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title_modes_badge.label_settings.outline_size = 0
	var pill := StyleBoxFlat.new()
	pill.bg_color = GOLD
	pill.set_corner_radius_all(9)
	pill.content_margin_left = 8
	pill.content_margin_right = 8
	_title_modes_badge.add_theme_stylebox_override("normal", pill)
	_title_modes_badge.anchor_left = 1.0
	_title_modes_badge.anchor_right = 1.0
	_title_modes_badge.offset_left = -104
	_title_modes_badge.offset_right = 4
	_title_modes_badge.offset_top = -10
	_title_modes_badge.offset_bottom = 10
	modes.add_child(_title_modes_badge)
	var pass_button := button("CRYPT PASS", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	pass_button.custom_minimum_size = Vector2(222, 74)
	pass_button.add_theme_color_override("font_color", GOLD)
	pass_button.pressed.connect(func(): pass_pressed.emit())
	_title_pass_row = pass_button
	_title_modes_row = _pair(modes, pass_button)
	col.add_child(_title_modes_row)
	_title_lock = label("Heroes and the Armory open\nafter your first run", 20, Color(0.7, 0.68, 0.62))
	col.add_child(_title_lock)


## Daily Crypt, Curses and the tutorial run, all behind MODES on the title screen.
## The screens they open sit on top, so BACK from them lands here again.
func _build_modes() -> void:
	_modes_box = overlay(Color(0.03, 0.02, 0.05, 0.95))
	add_child(_modes_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 20
	col.offset_right = -20
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_modes_box.add_child(col)
	col.add_child(label("MODES", 46, Color(1, 0.85, 0.55)))
	col.add_child(label("More ways to run the crypt.", 18, Color(0.8, 0.8, 0.85)))
	var daily := _mode_card("daily", "DAILY CRYPT", GOLD, func(): daily_pressed.emit())
	col.add_child(daily[0])
	_mode_daily_text = daily[1]
	_mode_daily_tag = daily[2]
	var curses := _mode_card("curses", "CURSES", Color(0.95, 0.35, 0.4), func(): curses_pressed.emit())
	col.add_child(curses[0])
	(curses[1] as Label).text = "Turn on curses for harder runs, more score\nand rewards for your hero."
	_mode_curses_tag = curses[2]
	_modes_tutorial = button("Tutorial run", 20, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_modes_tutorial.custom_minimum_size = Vector2(260, 62)
	_modes_tutorial.pressed.connect(func(): _guarded(_modes_tutorial, tutorial_pressed))
	col.add_child(_centered(_modes_tutorial))
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_modes(false))
	col.add_child(_centered(back))


## A big mode button: a picture (art/ui/pass_<pic>.png), the name, a line about it and a tag.
## Returns [button, line, tag].
func _mode_card(pic: String, title: String, col: Color, on_press: Callable) -> Array:
	var b := button("", 20, Color(0.12, 0.1, 0.16, 0.98), Color(col, 0.75))
	b.custom_minimum_size = Vector2(0, 228)
	for state in ["normal", "pressed"]:
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		sb.set_border_width_all(3)
	b.pressed.connect(on_press)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	full(m)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	var img := TextureRect.new()
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.custom_minimum_size = Vector2(0, 112)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path := "res://art/ui/pass_%s.png" % pic
	if ResourceLoader.exists(path):
		img.texture = load(path)
	v.add_child(img)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var t := label(title, 26, col.lightened(0.15), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var line := label("", 15, Color(0.8, 0.8, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	texts.add_child(line)
	var tag := label("", 18, col)
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tag)
	return [b, line, tag]


func show_modes(v: bool) -> void:
	if v and not _modes_box.visible:
		Sfx.play("click")
	_modes_box.visible = v
	# The title's own buttons would show faintly through; hide them while MODES is open.
	_title_box.get_child(0).visible = not v
	if not v:
		_disarm(_modes_tutorial)
		return
	var owned := Store.owned()
	var cfg := Game._load_save()
	var theme := Curses.theme()
	_mode_daily_text.text = "%s: %s.\nThe same crypt for everyone, once a day." % [theme.name, theme.text]
	_mode_daily_tag.text = "PLAYED" if Curses.official_used(cfg) else "READY"
	var level := Curses.level_of(Curses.chosen(cfg, owned))
	_mode_curses_tag.text = "LEVEL %d" % level if level > 0 else "OFF"


func modes_visible() -> bool:
	return _modes_box.visible


## The Heroes screen (hero_screen.gd).
func _build_heroes() -> void:
	_heroes_box = HeroScreen.new()
	add_child(_heroes_box)
	_heroes_box.pick.connect(func(id: String): hero_pick.emit(id))
	_heroes_box.trial.connect(func(id: String): hero_trial.emit(id))
	_heroes_box.closed.connect(func(): show_heroes(false))


## With a saved run waiting, starting a new one asks first: the first tap warns, and a
## second tap within 3 seconds starts it (giving up the saved run).
func _guarded(b: Button, sig: Signal) -> void:
	if not _title_continue.visible or b.has_meta("armed"):
		_disarm(b)
		sig.emit()
		return
	b.set_meta("armed", [b.text, b.get_theme_font_size("font_size")])
	b.text = "Tap again: new run"
	b.add_theme_font_size_override("font_size", 20)
	get_tree().create_timer(3.0, true, false, true).timeout.connect(_disarm.bind(b))


## Puts a `_guarded` button's own text and size back.
func _disarm(b: Button) -> void:
	if b.has_meta("armed"):
		var was: Array = b.get_meta("armed")
		b.text = was[0]
		b.add_theme_font_size_override("font_size", was[1])
		b.remove_meta("armed")


## Two buttons side by side, centred.
func _pair(a: Control, b: Control) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(a)
	row.add_child(b)
	return row


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
	_end_score = label("", 40, Color(1, 0.85, 0.45))
	col.add_child(_end_score)
	_end_best = label("", 20, Color(0.8, 0.78, 0.7))
	col.add_child(_end_best)
	_end_stats = label("", 22, Color(0.85, 0.85, 0.9))
	col.add_child(_end_stats)
	# Daily Crypt: the result card, and the same as text to paste anywhere.
	_share_card = ShareCard.new()
	_share_card.visible = false
	col.add_child(_share_card)
	_share_button = button("SHARE RESULT", 20, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	_share_button.add_theme_color_override("font_color", GOLD)
	_share_button.custom_minimum_size = Vector2(240, 56)
	_share_button.pressed.connect(func():
		_share_button.disabled = true
		share_pressed.emit())
	# Copies a detailed report of the run, to paste to Claude for balancing.
	_copy_button = button("COPY RUN REPORT", 20, Color(0.1, 0.12, 0.18, 0.95), Color(0.5, 0.75, 1.0, 0.7))
	_copy_button.custom_minimum_size = Vector2(240, 56)
	_copy_button.pressed.connect(func():
		_copy_button.text = "Copied! Paste it to Claude"
		copy_report_pressed.emit())
	col.add_child(_pair(_share_button, _copy_button))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 100)
	_end_spacer = spacer
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
	heroes.custom_minimum_size = Vector2(222, 74)
	heroes.pressed.connect(func(): heroes_pressed.emit())
	var armory := button("ARMORY", 26)
	armory.custom_minimum_size = Vector2(222, 74)
	armory.pressed.connect(func(): armory_pressed.emit())
	buttons.add_child(_pair(heroes, armory))
	var end_pass := button("CRYPT PASS", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	end_pass.add_theme_color_override("font_color", GOLD)
	end_pass.pressed.connect(func(): pass_pressed.emit())
	_end_pass = _centered(end_pass)
	_end_pass.visible = false
	buttons.add_child(_end_pass)
	_end_buttons = buttons
	# After the last free floor: the Crypt Pass, or back to the title.
	var offer := VBoxContainer.new()
	offer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offer.add_theme_constant_override("separation", 18)
	col.add_child(offer)
	var get_pass := button("GET THE CRYPT PASS", 28, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	get_pass.add_theme_color_override("font_color", GOLD)
	get_pass.custom_minimum_size = Vector2(340, 86)
	get_pass.pressed.connect(func(): pass_pressed.emit())
	offer.add_child(_centered(get_pass))
	var to_title := button("BACK TO TITLE", 24, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	to_title.pressed.connect(func(): title_pressed.emit())
	offer.add_child(_centered(to_title))
	_end_offer = offer
	# End of an endless loop: go deeper, or leave with a coin bonus.
	var loop := VBoxContainer.new()
	loop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loop.add_theme_constant_override("separation", 18)
	col.add_child(loop)
	_loop_deeper_button = button("DESCEND DEEPER", 28, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	_loop_deeper_button.custom_minimum_size = Vector2(380, 86)
	_loop_deeper_button.pressed.connect(func(): loop_deeper.emit())
	loop.add_child(_centered(_loop_deeper_button))
	_loop_bank_button = button("BANK AND LEAVE", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	_loop_bank_button.add_theme_color_override("font_color", GOLD)
	_loop_bank_button.custom_minimum_size = Vector2(380, 74)
	_loop_bank_button.pressed.connect(func(): loop_bank.emit())
	loop.add_child(_centered(_loop_bank_button))
	_end_loop = loop
	_end_loop.visible = false


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
	_reports_button = button("Send reports: Off", 22)
	_reports_button.pressed.connect(func(): reports_toggled.emit(not _reports_on))
	col.add_child(_centered(_reports_button))
	col.add_child(_centered(privacy_button()))
	_quit_button = button("Quit run", 24, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_quit_button.pressed.connect(_on_quit_pressed)
	col.add_child(_centered(_quit_button))
	# Testers can say which build they were playing.
	col.add_child(label("Build " + Game.BUILD, 16, Color(0.6, 0.57, 0.65)))


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
	var tabs := []
	for tab in [["upgrades", "UPGRADES"], ["vault", "VAULT"]]:
		var tb := button(tab[1], 20)
		tb.custom_minimum_size = Vector2(200, 52)
		var id: String = tab[0]
		tb.pressed.connect(func():
			Sfx.play("click")
			_armory_tab = id
			_fill_shop(_shop_rows, _shop_coins))
		_tab_buttons[id] = tb
		tabs.append(tb)
	_armory_tabs = _pair(tabs[0], tabs[1])
	col.add_child(_armory_tabs)
	_armory_coins = coin_row(30, col, true)
	_armory_rows = VBoxContainer.new()
	_armory_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_armory_rows.add_theme_constant_override("separation", 8)
	col.add_child(_armory_rows)
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_armory(false))
	col.add_child(_centered(back))


## The Crypt Pass screen: four picture tiles for what it gives, the price, and buy / restore.
## The pictures are in art/ui (taken from the game by the test robot).
func _build_pass() -> void:
	_pass_box = overlay(Color(0.03, 0.02, 0.05, 0.97))
	add_child(_pass_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 16
	col.offset_bottom = -16
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_pass_box.add_child(col)
	col.add_child(label("CRYPT PASS", 50, GOLD))
	col.add_child(label("One-time purchase. No ads. No subscription.\nYours forever.", 18, Color(0.88, 0.85, 0.78)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(_centered(grid))
	for tile in [["floors", "Endless loops"], ["heroes", "All 4 heroes now"], ["daily", "Daily practice"], ["curses", "10 Curses"]]:
		grid.add_child(_pass_tile(tile[0], tile[1]))
	_pass_buy = button("UNLOCK", 32, Color(0.45, 0.3, 0.08, 0.98), GOLD)
	_pass_buy.custom_minimum_size = Vector2(320, 86)
	_pass_buy.pressed.connect(func(): pass_buy.emit())
	col.add_child(_centered(_pass_buy))
	_pass_status = label("", 18, Color(1, 0.75, 0.6))
	col.add_child(_pass_status)
	_pass_dev = label("Bone Chain is made by one developer.\nThank you for keeping it going!", 15, Color(0.7, 0.68, 0.74))
	col.add_child(_pass_dev)
	_pass_back = button("NOT NOW", 26)
	_pass_back.custom_minimum_size = Vector2(320, 70)
	_pass_back.pressed.connect(func(): show_pass(false))
	_pass_restore = button("Restore purchase", 18, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_pass_restore.custom_minimum_size = Vector2(220, 50)
	_pass_restore.pressed.connect(func(): pass_restore.emit())
	col.add_child(_centered(_pass_back))
	col.add_child(_pair(_pass_restore, privacy_button()))


## One picture tile: the picture, a title and a line of text (filled in by show_pass).
func _pass_tile(pic: String, title: String) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(246, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.08, 0.13, 1)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 0.8, 0.3, 0.45)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var img := TextureRect.new()
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.custom_minimum_size = Vector2(234, 112)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path := "res://art/ui/pass_%s.png" % pic
	if ResourceLoader.exists(path):
		img.texture = load(path)
	v.add_child(img)
	var t := label(title, 20, Color(1, 0.93, 0.8))
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	var d := label("", 14, Color(0.78, 0.78, 0.84))
	d.custom_minimum_size = Vector2(234, 0)
	v.add_child(d)
	_pass_tiles.append(d)
	return panel


## `price` is Google Play's price text ("" until it arrives), `status` a line under the button.
func show_pass(v: bool, owned := false, price := "", status := "") -> void:
	_pass_box.visible = v
	if not v:
		return
	var coins_of_heroes := 0
	for h: Dictionary in Heroes.LIST:
		coins_of_heroes += int(h.cost)
	_pass_tiles[0].text = "Floor %d and as deep\nas you dare" % (Store.FREE_FLOORS + 1)
	_pass_tiles[1].text = "Knight, Barbarian and Mage,\nno coins needed (%d)" % coins_of_heroes
	_pass_tiles[2].text = "Replay today's Daily\nCrypt as often as you like"
	_pass_tiles[3].text = "Curse Level up to %d,\nplus hero rewards" % Curses.max_level()
	_pass_buy.disabled = owned
	_pass_buy.text = "OWNED - THANK YOU!" if owned else "UNLOCK  " + (price if price != "" else Store.FALLBACK_PRICE)
	_pass_buy.add_theme_font_size_override("font_size", 26 if owned else 32)
	_pass_status.text = status
	_pass_status.visible = status != ""
	_pass_dev.visible = not owned
	_pass_back.text = "BACK" if owned else "NOT NOW"
	_pass_restore.visible = not owned


## The Daily Crypt screen: today's theme, hero and three rules, and START.
func _build_daily() -> void:
	_daily_box = overlay(Color(0.03, 0.02, 0.05, 0.96))
	add_child(_daily_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22
	col.offset_right = -22
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	_daily_box.add_child(col)
	_daily_title = label("DAILY CRYPT", 46, GOLD)
	col.add_child(_daily_title)
	_daily_theme = label("", 24, Color(1, 0.93, 0.8))
	col.add_child(_daily_theme)
	_daily_info = label("", 18, Color(0.8, 0.8, 0.86))
	col.add_child(_daily_info)
	_daily_rules = VBoxContainer.new()
	_daily_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_daily_rules.add_theme_constant_override("separation", 8)
	col.add_child(_daily_rules)
	_daily_status = label("", 18, Color(1, 0.8, 0.6))
	col.add_child(_daily_status)
	_daily_go = button("START", 30, Color(0.45, 0.3, 0.08, 0.98), GOLD)
	_daily_go.custom_minimum_size = Vector2(340, 86)
	_daily_go.pressed.connect(func():
		if _daily_open:
			_guarded(_daily_go, daily_start)
		else:
			pass_pressed.emit())
	col.add_child(_centered(_daily_go))
	_daily_next = label("", 16, Color(0.65, 0.63, 0.7))
	col.add_child(_daily_next)
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_daily(false))
	col.add_child(_centered(back))


## info: {title, theme, theme_text, hero, mult, rules: [{title, text, kind}], status, open, practice, next}
func show_daily(v: bool, info := {}) -> void:
	_daily_box.visible = v
	if not v:
		return
	_daily_open = info.open
	_daily_title.text = info.title
	_daily_theme.text = "%s\n%s" % [info.theme, info.theme_text]
	_daily_info.text = "Hero: %s  ·  %d floors  ·  Score x%s" % [info.hero, Curses.DAILY_FLOORS, info.mult]
	for c in _daily_rules.get_children():
		c.queue_free()
	for r: Dictionary in info.rules:
		_daily_rules.add_child(_rule_row(r))
	_daily_status.text = info.status
	_daily_go.text = ("PLAY PRACTICE" if info.practice else "START OFFICIAL RUN") if info.open else "GET THE CRYPT PASS"
	_daily_go.add_theme_font_size_override("font_size", 26)
	_daily_next.text = info.next


func daily_visible() -> bool:
	return _daily_box.visible


# ---------------------------------------------------------------- Omens

func _build_omens() -> void:
	_omen_box = overlay(Color(0.03, 0.01, 0.03, 0.96))
	add_child(_omen_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 22
	col.offset_right = -22
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_omen_box.add_child(col)
	col.add_child(label("CHOOSE AN OMEN", 44, Color(0.95, 0.4, 0.42)))
	_omen_info = label("", 20, Color(1, 0.9, 0.8))
	col.add_child(_omen_info)
	_omen_rows = VBoxContainer.new()
	_omen_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_omen_rows.add_theme_constant_override("separation", 12)
	col.add_child(_omen_rows)
	_omen_have = label("", 17, Color(0.75, 0.72, 0.8))
	col.add_child(_omen_have)
	var back := button("BACK", 24)
	back.pressed.connect(func(): show_omens(false))
	col.add_child(_centered(back))


## choices: three Omens ({id, title, text}); `have` lists the Omens already in play.
func show_omens(v: bool, choices := [], next_loop := 2, have := "") -> void:
	_omen_box.visible = v
	if not v:
		return
	_omen_info.text = "Loop %d. Omens stack, and each adds +%d%% score.\nIn between loops: full health and +%d rerolls." % [next_loop,
		roundi(Loops.OMEN_SCORE * 100.0), Loops.LOOP_REROLLS]
	for c in _omen_rows.get_children():
		c.queue_free()
	for o: Dictionary in choices:
		var b := button("%s  ·  +%d%% score\n%s" % [o.title, roundi(Loops.OMEN_SCORE * 100.0), o.text], 22, Color(0.16, 0.06, 0.09, 0.98), Color(0.95, 0.4, 0.42, 0.8))
		b.custom_minimum_size = Vector2(0, 92)
		b.pressed.connect(func(): omen_picked.emit(o.id))
		_omen_rows.add_child(b)
	_omen_have.text = "Your Omens: " + have if have != "" else "No Omens yet"


func omens_visible() -> bool:
	return _omen_box.visible


# ---------------------------------------------------------------- Reports question

## Asked once, at the end of a run: reports stay off unless the player says yes.
func _build_reports_ask() -> void:
	_ask_box = overlay(Color(0.02, 0.01, 0.03, 1.0))
	add_child(_ask_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_ask_box.add_child(col)
	col.add_child(label("HELP FIX BUGS?", 40, GOLD))
	var text := label("Send anonymous run and crash reports to the developer?\n\nNo account, name or ad ID. Just the run summary, the phone model and any error messages.\n\nYou can change this any time in the pause menu.", 19, Color(0.9, 0.88, 0.84))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var yes := button("YES, SEND REPORTS", 26, Color(0.2, 0.32, 0.18, 0.97), Color(0.6, 0.95, 0.55))
	yes.custom_minimum_size = Vector2(360, 80)
	yes.pressed.connect(func(): reports_answered.emit(true))
	col.add_child(_centered(yes))
	var no := button("NO THANKS", 24)
	no.custom_minimum_size = Vector2(360, 70)
	no.pressed.connect(func(): reports_answered.emit(false))
	col.add_child(_centered(no))
	col.add_child(_centered(privacy_button()))


func show_reports_ask(v: bool) -> void:
	_ask_box.visible = v


func reports_ask_visible() -> bool:
	return _ask_box.visible


## A daily rule: green helps, red is a curse, gold is a trade-off.
func _rule_row(r: Dictionary) -> Control:
	var kinds := {"help": ["HELP", Color(0.5, 0.95, 0.55)], "harm": ["CURSE", Color(0.95, 0.4, 0.42)], "trade": ["TRADE", GOLD]}
	var k: Array = kinds.get(r.kind, kinds.harm)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.16, 0.98)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 8
	sb.border_color = k[1]
	sb.content_margin_left = 18
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var t := label(r.title, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	texts.add_child(label(r.text, 16, Color(0.78, 0.78, 0.84), HORIZONTAL_ALIGNMENT_LEFT))
	var tag := label(k[0], 18, k[1])
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(tag)
	return panel


func pass_visible() -> bool:
	return _pass_box.visible


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
	return _cards_box.visible or _doors_box.visible or _title_box.visible or _end_box.visible or _pause_box.visible or _armory_box.visible or _pass_box.visible \
		or _daily_box.visible or _omen_box.visible or _ask_box.visible or _modes_box.visible or _heroes_box.visible


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _end_box.visible and not _end_buttons.visible and not _end_offer.visible and not _end_loop.visible \
					and not _armory_box.visible and not _pass_box.visible and not _omen_box.visible and not _ask_box.visible \
					and not _heroes_box.visible \
					and not _copy_button.get_global_rect().has_point(t.position) \
					and not (_share_button.visible and _share_button.get_global_rect().has_point(t.position)):
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
	_doors_age += delta
	# The title's words and buttons would show faintly through the screens opened over it.
	if _title_box.visible:
		_title_box.get_child(0).visible = not (_modes_box.visible or _daily_box.visible or _armory_box.visible \
			or _pass_box.visible or _heroes_box.visible)
	_stick_age += delta
	if _flash.color.a > 0.0:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	_chain_box.offset_top = 122.0 if _boss_box.visible else 88.0
	_chain_box.offset_bottom = _chain_box.offset_top + 122.0
	# Hidden behind the pause menu, where it would cross "Paused".
	var meter := Game.chain_unlocked() and Game.state in [Game.State.PLAYING, Game.State.UPGRADE]
	var want := (1.0 if Game.chain > 1.01 or _broken_time > 0.0 else 0.6) if meter else 0.0
	_chain_box.modulate.a = move_toward(_chain_box.modulate.a, want, delta * (8.0 if want > 0.0 else 3.0))
	_spine.drain = clampf(Game._combo_left / Game.chain_time(), 0.0, 1.0) if Game.chain > 1.01 else 0.0
	_chain_pop = move_toward(_chain_pop, 0.0, delta * 3.0)
	var pulse := 1.0 + _chain_pop * 0.5 + (0.05 * sin(Time.get_ticks_msec() * 0.012) if Game.chain >= Game.chain_max() else 0.0)
	_chain_label.scale = Vector2(pulse, pulse)
	_shown_score = move_toward(_shown_score, Game.score, maxf(40.0, absf(Game.score - _shown_score) * 8.0) * delta)
	_score_label.text = "SCORE  " + Hud.thousands(roundi(_shown_score))
	if _broken_time > 0.0:
		_broken_time -= delta
		_broken_label.modulate.a = clampf(_broken_time / 0.4, 0.0, 1.0)
		_chain_label.modulate.a = 1.0 - _broken_label.modulate.a
	# Tips, hints and callouts belong to the action: hide them while a menu or the
	# blessing cards cover it, so they never show through ("PERFECT!" over the cards).
	var covered := 0.0 if _overlay_open() else 1.0
	_tip.self_modulate.a = covered
	_hint.self_modulate.a = covered
	_callout.self_modulate.a = covered
	if _tip_delay > 0.0:
		_tip_delay -= delta
		_tip.visible = _tip_delay <= 0.0
	elif _tip_time > 0.0:
		_tip_time -= delta
		_tip.modulate.a = clampf(_tip_time / 0.4, 0.0, 1.0)
		if _tip_time <= 0.0:
			_tip.visible = false
	_update_end_count(delta)
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
		_boss_fill.anchor_right = Game.boss_bar()
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


## The Hourglass countdown. Below zero hides it.
func set_timer(seconds: float) -> void:
	_timer_label.visible = seconds > -0.5 and Game.curses.has("hourglass")
	if not _timer_label.visible:
		return
	if seconds <= 0.0:
		_timer_label.text = "TIME'S UP"
		_timer_label.label_settings.font_color = Color(1, 0.35, 0.3)
	else:
		_timer_label.text = "Time %d:%02d" % [int(seconds) / 60, int(seconds) % 60]
		_timer_label.label_settings.font_color = Color(1, 0.45, 0.35) if seconds < 10.0 else Color(1, 0.75, 0.5)


func clear_banner() -> void:
	_banner_time = 0.0
	_banner.modulate.a = 0.0


func banner(text: String, col := Color(1, 0.9, 0.7)) -> void:
	_banner.text = text
	_banner.label_settings.font_color = col
	_banner.label_settings.font_size = 48 if text.length() <= 16 else 38
	_banner_time = 2.0


## Updates the spine and the big "x2.4" under it. Each step up punches the number.
func show_chain(mult: float) -> void:
	if Game.score == 0:
		_shown_score = 0.0   # a new run starts from zero instead of counting down
	var col := ChainSpine.color_for(mult)
	if mult > _spine.mult + 0.01:
		_chain_pop = 0.35 if mult < Game.chain_max() else 0.6
	_spine.set_chain(mult)
	_chain_label.text = "x%.1f" % mult
	_chain_label.label_settings.font_color = col


## The chain ran out: the spine shatters and the number it reached flashes in red.
func chain_broken(was: float) -> void:
	_spine.shatter()
	_chain_label.text = "x1.0"
	_chain_label.label_settings.font_color = ChainSpine.BONE
	if was >= 2.0:
		_broken_label.text = "CHAIN BROKEN  x%.1f" % was
		_broken_time = 1.3


## A short line under the chain meter, for teaching the first run. 0 seconds clears it.
## `delay` waits for the room banner to clear first, so the two don't overlap.
func tip(text: String, seconds := 5.0, delay := 0.0) -> void:
	_tip.text = text
	_tip_delay = delay if text != "" and seconds > 0.0 else 0.0
	_tip.visible = text != "" and seconds > 0.0 and _tip_delay <= 0.0
	_tip.modulate.a = 1.0
	_tip_time = seconds if text != "" else 0.0


## 12345 -> "12,345"
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


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
	clear_banner()   # a blessing banner from the last pick would sit on top of the card
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


## How far down the screen the top bar reaches (health, coins, room counter, chain and
## score), so damage numbers can keep below it.
func top_band() -> float:
	return float(_safe.get_theme_constant("margin_top")) + 225.0


## Each card shows the family icon, the title in the family colour, and the rarity
## as a tag and border colour. `rerolls` is how many free rerolls are left.
func show_cards(choices: Array, rerolls := 0, tags := true) -> void:
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
		var kind: String = Heroes.get_hero(u.hero).title.to_upper() if u.has("hero") else Upgrades.FAMILIES[u.family].name.to_upper()
		(labels[3] as Label).text = "%s · %s" % [kind, rar.name] if tags else kind
		(labels[3] as Label).label_settings.font_color = rar.color
		for sb_name in ["normal", "pressed"]:
			var sb := b.get_theme_stylebox(sb_name) as StyleBoxFlat
			sb.border_color = rar.color
			var edge := 0 if u.rarity == "common" or not tags else (2 if u.rarity == "rare" else 3)
			sb.border_width_top = edge
			sb.border_width_right = edge
			sb.border_width_bottom = edge
	_reroll_button.visible = rerolls > 0
	_reroll_button.text = "Reroll (%d left)" % rerolls
	_cards_box.visible = true
	_cards_age = 0.0


func show_title(v: bool, best := "", coins := 0) -> void:
	_title_box.visible = v
	var locked := Game.first_run_pending()
	var has_pass := Store.owned()
	_title_shop_row.visible = not locked
	_title_pass_row.visible = not locked and not has_pass
	_title_modes_row.visible = not locked
	_title_modes_badge.visible = not Curses.official_used(Game._load_save())
	_title_lock.visible = locked
	if not v:
		show_modes(false)
	_title_free.visible = not has_pass and not locked   # not before the tutorial run is done
	_title_best.text = best
	_title_coins.text = str(coins)
	var where := Game.continue_text()
	_title_continue.visible = where != "" and not locked
	_continue_where.text = where
	_title_spacer.visible = not _title_continue.visible
	_title_play.text = "NEW RUN" if _title_continue.visible else "PLAY"
	_title_play.add_theme_font_size_override("font_size", 32 if _title_continue.visible else 38)
	_title_play.remove_meta("armed")


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


## Anonymous run and crash reports (see telemetry.gd). Hidden if no form is set up.
func set_reports_label(on: bool, available: bool) -> void:
	_reports_on = on
	_reports_button.text = "Send reports: On" if on else "Send reports: Off"
	_reports_button.get_parent().visible = available


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
	_shop_curses = false
	_shop_title.text = "Armory"
	_fill_shop(rows, coins)


## rows: [{id, name, badge, mastery, cost, unlocked, selected, trial, trying}]
func show_heroes(v: bool, rows := [], coins := 0) -> void:
	if v:
		_heroes_box.open(rows, coins)
	else:
		_heroes_box.close()


func heroes_visible() -> bool:
	return _heroes_box.visible


## rows: [{id, title, text, level, on, locked}]. `info` is the Curse Level line, `goal` the
## next hero reward.
func show_curses(v: bool, rows := [], info := "", goal := "") -> void:
	_armory_box.visible = v
	if not v:
		return
	_shop_curses = true
	_shop_title.text = "Curses"
	_shop_sub.text = "%s\n%s" % [info, goal]
	_armory_tabs.visible = false
	_armory_coins.get_parent().visible = false
	for c in _armory_rows.get_children():
		c.queue_free()
	for r: Dictionary in rows:
		_armory_rows.add_child(_curse_row(r))


func set_title_hero(hero_name: String) -> void:
	_title_hero.text = "Playing as the " + hero_name


## Shows the rows of the open tab: Armory upgrades, or the Vault's blessings.
func _fill_shop(rows: Array, coins: int) -> void:
	_shop_rows = rows
	_shop_coins = coins
	var vault := _armory_tab == "vault"
	_shop_sub.text = "New blessings. Buy one once and it can\nturn up in all your runs." if vault else "Upgrades bought here last forever."
	_armory_tabs.visible = true
	for id: String in _tab_buttons:
		var on := id == _armory_tab
		var sb := _tab_buttons[id].get_theme_stylebox("normal") as StyleBoxFlat
		sb.bg_color = Color(0.32, 0.22, 0.08, 0.98) if on else Color(0.12, 0.1, 0.16, 0.95)
		sb.border_color = GOLD if on else Color(0.45, 0.4, 0.5, 0.6)
	_armory_coins.get_parent().visible = true
	_armory_coins.text = str(coins)
	for c in _armory_rows.get_children():
		c.queue_free()
	for r: Dictionary in rows:
		if r.has("vault") == vault:
			_armory_rows.add_child(_armory_row(r, coins))


func _curse_row(r: Dictionary) -> Button:
	var on: bool = r.on
	var locked: bool = r.get("locked", false)
	var red := Color(0.95, 0.35, 0.4)
	var b := button("", 20, Color(0.2, 0.06, 0.09, 0.98) if on else Color(0.12, 0.1, 0.16, 0.98), red if on else Color(0.4, 0.35, 0.45, 0.6))
	b.custom_minimum_size = Vector2(0, 60)
	if on:
		(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(4)
	b.pressed.connect(func(): curse_toggled.emit(r.id))
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
	var t := label("%s   Lv %d" % [r.title, r.level], 20, red.lightened(0.3) if on else (Color(0.6, 0.58, 0.62) if locked else Color.WHITE), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var d := label(r.text, 15, Color(0.78, 0.78, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	d.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(d)
	var tag := label("PASS" if locked else ("ON" if on else "OFF"), 20, GOLD.darkened(0.2) if locked else (red if on else Color(0.6, 0.58, 0.62)))
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(tag)
	return b


func _armory_row(r: Dictionary, coins: int) -> Button:
	var maxed: bool = r.cost < 0
	var afford: bool = not maxed and r.cost <= coins
	var b := button("", 20, Color(0.12, 0.1, 0.16, 0.98), GOLD if afford else Color(0.4, 0.35, 0.45, 0.6))
	var blessing: Dictionary = r.get("vault", {})
	b.custom_minimum_size = Vector2(0, 70 if blessing.is_empty() else 78)
	b.pressed.connect(func(): armory_buy.emit(r.id))
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 16)
	full(m)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)
	if not blessing.is_empty():
		# Vault rows show the blessing's own badge, as on its card.
		var icon := BlessingIcon.new()
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.show_for(blessing)
		h.add_child(icon)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var pips := "" if r.max <= 1 else "   " + "■".repeat(r.level) + "□".repeat(r.max - r.level)
	var title_col := Upgrades.color(blessing) if not blessing.is_empty() else Color.WHITE
	var t := label(r.title + pips, 22, title_col if not maxed or not blessing.is_empty() else Color(0.7, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(t)
	var d := label(r.text, 15 if not blessing.is_empty() else 16, Color(0.78, 0.78, 0.84), HORIZONTAL_ALIGNMENT_LEFT)
	if blessing.is_empty():
		d.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(d)
	if maxed:
		var done := "IN RUNS" if not blessing.is_empty() else ("OWNED" if r.max <= 1 else "MAX")
		var tag := label(done, 20 if not blessing.is_empty() else 22, Color(0.6, 1, 0.6))
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


func show_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


## `score` counts up from zero on the end screen; `best` is the best score before this run.
## `offer` swaps the tap line for the Crypt Pass offer (after the last free floor).
func show_end(v: bool, victory := false, stats := "", tap_text := "Tap to try again", buttons := false, score := -1, best := 0, offer := false) -> void:
	# The run's top bar would show through the end screen: hide it while it's up.
	if v and not _end_box.visible:
		_hud_before_end = _safe.visible
		_safe.visible = false
	elif not v and _end_box.visible:
		_safe.visible = _hud_before_end
	_end_box.visible = v
	_end_offer.visible = v and offer
	_end_loop.visible = false
	if not v:
		return
	_end_score.visible = score >= 0
	_end_best.visible = score >= 0
	_end_target = maxi(score, 0)
	_end_best_value = best
	_end_count = 0.0 if score >= 0 else -1.0
	_end_score.text = "SCORE  0"
	_end_best.text = ""
	_end_tap.text = tap_text
	_copy_button.text = "COPY RUN REPORT"
	# A tool for balancing the game, only for players who chose to send reports.
	_copy_button.visible = _reports_on
	_end_tap.visible = not buttons and not offer
	_end_buttons.visible = buttons
	_end_pass.visible = false
	_share_button.visible = false
	_share_card.visible = false
	_end_spacer.custom_minimum_size.y = 100.0 if not buttons else 24.0
	_end_title.text = "VICTORY" if victory else "YOU DIED"
	_end_title.label_settings.font_color = Color(1, 0.85, 0.4) if victory else Color(0.9, 0.2, 0.2)
	_end_stats.text = stats


func _update_end_count(delta: float) -> void:
	if _end_count < 0.0 or not _end_box.visible:
		return
	var was := _end_count
	_end_count = minf(1.0, _end_count + delta / 1.4)
	var shown := roundi(_end_target * ease(_end_count, 0.4))
	_end_score.text = "SCORE  " + thousands(shown)
	if int(was * 20.0) != int(_end_count * 20.0) and _end_count < 1.0:
		Sfx.play("coin", 0.35)
	if _end_count >= 1.0:
		_end_count = -1.0
		if _end_target > _end_best_value and _end_target > 0:
			_end_best.text = "NEW BEST!"
			_end_best.label_settings.font_color = Color(1, 0.8, 0.3)
			Sfx.play("upgrade", 0.6)
		else:
			_end_best.text = "Best  " + thousands(_end_best_value)
			_end_best.label_settings.font_color = Color(0.8, 0.78, 0.7)


## Daily Crypt runs get their result card (rows of ShareCard codes) and a SHARE RESULT
## button on the end screen.
## After SHARE RESULT: the share menu opened (the words are copied too), or they were copied.
func share_done(opened: bool) -> void:
	_share_button.disabled = false
	_share_button.text = "Shared! The words are copied too" if opened else "Copied! Paste it anywhere"
	_share_button.add_theme_font_size_override("font_size", 15 if opened else 16)


func show_share(v: bool, rows := [], caption := "") -> void:
	_share_button.visible = v
	_share_card.visible = v and not rows.is_empty()
	if _share_card.visible:
		_share_card.show_rows(rows, caption)
	_share_button.text = "SHARE RESULT"
	_share_button.add_theme_font_size_override("font_size", 20)
	_copy_button.custom_minimum_size.x = 240.0 if v else 300.0


## A CRYPT PASS button among the death-screen buttons (after a deep death, once a session).
func show_end_pass(v: bool) -> void:
	_end_pass.visible = v


## The end of a loop: DESCEND DEEPER into `next_loop`, or BANK AND LEAVE with `bonus` coins.
func show_end_loop(v: bool, bonus := 0, next_loop := 2) -> void:
	_end_loop.visible = v
	if not v:
		return
	_end_offer.visible = false
	_end_tap.visible = false
	_end_spacer.custom_minimum_size.y = 24.0
	_loop_deeper_button.text = "DESCEND INTO LOOP %d" % next_loop
	_loop_bank_button.text = "BANK AND LEAVE  (+%d coins)" % bonus


## The Pass was bought on the end screen: carry on deeper instead.
func end_offer_done(tap_text: String) -> void:
	_end_offer.visible = false
	_end_tap.text = tap_text
	_end_tap.visible = true


func show_pause(v: bool) -> void:
	_pause_box.visible = v
	if _quit_armed:
		_disarm_quit()


func set_fade(a: float) -> void:
	_fade.color.a = a
