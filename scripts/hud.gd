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
signal records_pressed
signal drops_pressed
signal road_pressed
signal road_claim(index: int)
signal road_closed
signal drops_closed
signal mastery_pressed(id: String)
signal style_pressed(id: String)
signal feats_pressed
signal found_wear(id: String, slot: String, key: String)
signal feats_hero_pressed(id: String)
signal see_looks(id: String, level: int)
signal style_wear(id: String, slot: String, key: String)
signal hero_pick(id: String)
signal copy_report_pressed
signal resume_pressed
signal quit_run_pressed
signal retry_pressed
signal music_toggled(on: bool)
signal sounds_toggled(on: bool)
signal graphics_toggled(high: bool)
signal shake_changed(level: int)
signal vibration_toggled(on: bool)
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
## The chunky cartoon font for titles, buttons and big numbers (fonts/OFL-LilitaOne.txt).
const UI_FONT := preload("res://fonts/LilitaOne-Regular.ttf")
## The dark outline round chunky text and buttons.
const INK := Color(0.1, 0.05, 0.14)
## Button colours by job: [face, dark edge]. green = go, gold = buy and rewards, blue = normal,
## purple = looks, slate = quiet choices (later, back to title), red = danger.
const ROLES := {
	"green": [Color(0.36, 0.76, 0.2), Color(0.1, 0.32, 0.05)],
	"gold": [Color(1.0, 0.7, 0.12), Color(0.48, 0.24, 0.02)],
	"blue": [Color(0.22, 0.5, 0.94), Color(0.06, 0.15, 0.42)],
	"purple": [Color(0.58, 0.32, 0.92), Color(0.22, 0.07, 0.42)],
	"slate": [Color(0.3, 0.31, 0.43), Color(0.1, 0.1, 0.17)],
	"red": [Color(0.88, 0.26, 0.2), Color(0.4, 0.06, 0.04)],
}
## The game's name on the title screen (and in the opening animation, which lands on it), drawn
## by tools/store/make_logo.py at twice the size it is shown, glow and edge included.
const LOGO := preload("res://art/ui/logo.png")
const LOGO_WIDTH := 490.0

const STICK_RADIUS := 70.0

var joystick := Vector2.ZERO
## Where the stick last pointed, and when (Time.get_ticks_msec()): DASH uses it for a moment
## after the thumb lifts, since one thumb can't hold the stick and tap the button.
var last_move := Vector2.ZERO
var last_move_ms := -100000

var _safe: MarginContainer
var _hp_shown := Vector2i(-1, -1)
var _hp_fill: Control
var _hp_label: Label
var _room_label: Label
var _boss_box: Control
var _boss_fill: Control
var _banner: Label
var _banner_w := 0.0   # the banner's text width, so its pop-in can stay on screen
var _wave_label: Label
var _banner_time := 0.0
var _shown_hp := 1.0

var _stick: Joystick
var _stick_touch := -1
var _stick_origin := Vector2.ZERO

var _cards_box: Control
var _cards_mastery: Label   # "WIZARD MASTERY 3!" over the cards after a mid-run level-up
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
var _pause_title: Label
var _resume_button: Button
## The pause menu opened from the title screen as Settings: BACK instead of RESUME, no Quit run.
var _settings_only := false
var _title_box: Control
var _title_logo: TextureRect
var _title_best: Label
## Gold lines under the best score: the Daily streak, today's coin bonus, the next goal.
var _title_goal: Label
var _end_box: Control
var _end_col: VBoxContainer
var _pause_build: Label
var _end_title: Label
var _end_stats: Label
## A gold line under the stats: the next goal after a death, the streak after the Daily.
var _end_goal: Label
var _pause_box: Control
var _pause_button: Button
var _danger: TextureRect
var _beat_phase := 0.0
var _hint: Label
var _end_tap: Label
var _boss_name: Label
var _boss_flash: ColorRect
var _phase_box: Control
var _phase_title: Label
var _phase_sub: Label
var _phase_tw: Tween
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
var _end_title_button: Control
var _end_title_btn: Button
var _music_button: Button
var _sounds_button: Button
var _music_on := true
var _sounds_on := true
var _graphics_button: Button
var _graphics_high := true
var _shake_button: Button
var _shake_level := 2
var _vibration_button: Button
var _vibration_on := true
var _reports_button: Button
var _fb_box: Control
var _fb_text: TextEdit
var _fb_note: Label
var _fb_send: Button
var _reports_on := false
var _hud_before_end := false
var _stick_start := Vector2.ZERO
## When the stick's touch began (Time.get_ticks_msec()). Real time, not game time: in slow
## motion a slow drag used to count as a quick flick and fire a dash (audit fix 2).
var _stick_start_ms := 0
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
## Version 122: the run's numbers fill in one line at a time after the score, each counting
## up with ticks and a little buzz, the way Archero and Brawl Stars hand out rewards.
var _tally: PackedStringArray = []
var _tally_i := -1          # the line counting up now (-1: not started or done)
var _tally_t := 0.0
var _tally_wait := false    # waiting for the score to finish counting
var _title_heroes: Control
var _title_armory: Control
var _title_lock: Label
var _title_shop_row: Control
var _title_pass_row: Control
var _title_modes_row: Control
var _title_modes_badge: Label
var _title_heroes_badge: Label
var _end_heroes_badge: Label   # the same tag on the end screen's HEROES button
var _modes_box: Control
var _records_box: Control
var _records_grid: GridContainer
var _records_note: Label
var _title_records: Control
var _title_settings: Control
var _title_drops: Button
var _end_drop: Button
var _end_looks: Button   # SEE 3 NEW LOOKS after a run that reached a Mastery level
var _end_looks_for := {}
var _end_mastery: MasteryBar
var _mastery: MasteryScreen
var _style: StyleScreen
var _drops: DropScreen
var _feats: FeatsScreen
var _toast: PanelContainer
var _toast_name: Label
var _toast_look: Label
var _toast_tween: Tween
var _title_road: RoadScreen.Bar
var _title_hint: Label
var _title_top: Control   # the words at the top of the title screen
var _title_bottom: Control   # the hero's name and the buttons at the bottom
var _title_gap: Control
var _road: RoadScreen
var _mode_daily_text: Label
var _mode_daily_tag: Label
var _mode_curses_tag: Label
var _modes_tutorial: Button
var _heroes_box: HeroScreen
var _end_offer: Control
var _pass_more: Label
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
var _pass_card: Control
var _pass_card_stage: HeroStage
var _pass_card_line: Label
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
	_build_rewards()
	_build_end()
	_build_pause()
	_build_feedback()
	_build_modes()
	_build_records()
	_build_armory()
	_build_heroes()
	_drops = DropScreen.new()
	add_child(_drops)
	_drops.closed.connect(func(): drops_closed.emit())
	_drops.wear.connect(func(id: String, slot: String, key: String): found_wear.emit(id, slot, key))
	_road = RoadScreen.new()
	add_child(_road)
	_road.claim.connect(func(i: int): road_claim.emit(i))
	_road.closed.connect(func(): road_closed.emit())
	_mastery = MasteryScreen.new()
	add_child(_mastery)
	_mastery.style.connect(func(id: String): style_pressed.emit(id))
	_style = StyleScreen.new()
	add_child(_style)
	_style.wear.connect(func(id: String, slot: String, key: String): style_wear.emit(id, slot, key))
	_style.get_pass.connect(func(): pass_pressed.emit())
	_style.feats.connect(func(): feats_pressed.emit())
	_feats = FeatsScreen.new()
	add_child(_feats)
	# Back on the Style screen after the Feats screen: its button no longer says NEW!.
	_feats.closed.connect(func():
		if _style.visible:
			_style.refresh_feats_button()
		refresh_rewards())
	_style.closed.connect(func():
		# The Heroes screen's pedestal draws again once the Style screen is gone.
		if _heroes_box.visible:
			_heroes_box._stage.set_active(true))
	_build_daily()
	_build_omens()
	_build_reports_ask()
	_build_pass()
	_build_boss_card()
	_build_phase_banner()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Big hits flash the edges of the screen, not the middle, so the hero never vanishes
	# in a white wash.
	var fsh := Shader.new()
	fsh.code = """
shader_type canvas_item;
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	COLOR.a *= mix(0.2, 1.0, smoothstep(0.35, 1.15, r));
}
"""
	var fm := ShaderMaterial.new()
	fm.shader = fsh
	_flash.material = fm
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
	if size >= 26:
		chunky(s)   # titles and big numbers: the cartoon font with a thick edge and a drop shadow
	l.label_settings = s
	return l


## Big text in the chunky look: the cartoon font, a thick dark edge and a soft drop shadow.
static func chunky(s: LabelSettings) -> void:
	s.font = UI_FONT
	s.outline_size = maxi(6, s.font_size / 5)
	s.outline_color = INK
	s.shadow_size = s.outline_size
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_offset = Vector2(0, maxf(2.0, s.font_size / 11.0))


## A deep blue-purple glow behind a full screen, instead of flat black.
static var _backdrop_tex: GradientTexture2D

static func backdrop(r: ColorRect) -> void:
	if _backdrop_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.22, 0.16, 0.4))
		g.set_color(1, Color(0.05, 0.035, 0.11))
		_backdrop_tex = GradientTexture2D.new()
		_backdrop_tex.gradient = g
		_backdrop_tex.fill = GradientTexture2D.FILL_RADIAL
		_backdrop_tex.fill_from = Vector2(0.5, 0.28)
		_backdrop_tex.fill_to = Vector2(1.15, 1.0)
		_backdrop_tex.width = 128
		_backdrop_tex.height = 256
	var t := TextureRect.new()
	t.texture = _backdrop_tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate.a = r.color.a
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(t)


## A soft dark panel behind teaching text, so it reads on any floor.
static func _text_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.01, 0.04, 0.62)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


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
	if dim.a > 0.69:   # (not 0.7: colours are stored as 32-bit floats)
		backdrop(r)
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
	var role := _role_for(text, bg, border)
	if role != "":
		# A chunky cartoon button: bright face, dark edge and lip, white outlined letters.
		b.add_theme_font_override("font", UI_FONT)
		b.add_theme_font_size_override("font_size", size + 2)
		b.add_theme_constant_override("outline_size", maxi(6, size / 4))
		b.add_theme_color_override("font_outline_color", INK)
		for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.85))
		paint(b, role)
		squash(b)
		return b
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


## Which colour job a button has, from the colours the screen asked for (rows and cards
## with their own content, "" or several lines on a dark box, keep their flat look).
static func _role_for(text: String, bg: Color, border: Color) -> String:
	if text == "" or ("\n" in text and bg.v < 0.25):
		return ""
	if bg.g > bg.r and bg.g > bg.b and bg.s > 0.3:
		return "green"
	if bg.r >= 0.28 and bg.b < 0.15 and bg.g >= 0.5 * bg.r:
		return "gold"
	if bg.r >= 0.3 and bg.g < 0.5 * bg.r:
		return "green"   # PLAY, TRY AGAIN, RESUME: the main way on
	if bg.b > bg.r and bg.r > bg.g and bg.s > 0.45:
		return "purple"
	if bg.v < 0.13 and border.v < 0.7:
		return "slate"
	return "blue"


## Gives button `b` the chunky look in colour `role` (see ROLES); used again to recolour
## tabs and the hero screen's action button.
static func paint(b: Button, role: String) -> void:
	var face: Color = ROLES[role][0]
	var edge: Color = ROLES[role][1]
	var normal := StyleBoxFlat.new()
	normal.bg_color = face
	normal.border_color = edge
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(3)
	normal.border_width_bottom = 9   # the lip under the face, like a thick toy button
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 4)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.anti_aliasing_size = 1.2
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = face.darkened(0.1)
	pressed.border_width_bottom = 4
	pressed.border_width_top = 7   # the face sinks into its lip
	pressed.shadow_offset = Vector2(0, 1)
	var off := normal.duplicate() as StyleBoxFlat
	off.bg_color = face.lerp(Color(0.35, 0.35, 0.4), 0.7)
	off.border_color = edge.lerp(Color(0.1, 0.1, 0.12), 0.6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# A soft shine across the top half of the face.
	var gloss := b.get_node_or_null("Gloss") as Panel
	if gloss == null:
		gloss = Panel.new()
		gloss.name = "Gloss"
		gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := StyleBoxFlat.new()
		g.bg_color = Color(1, 1, 1, 0.14)
		g.corner_radius_top_left = 14
		g.corner_radius_top_right = 14
		g.corner_radius_bottom_left = 6
		g.corner_radius_bottom_right = 6
		gloss.add_theme_stylebox_override("panel", g)
		gloss.anchor_right = 1.0
		gloss.anchor_bottom = 0.42
		gloss.offset_left = 6
		gloss.offset_top = 5
		gloss.offset_right = -6
		b.add_child(gloss, false, Node.INTERNAL_MODE_FRONT)
	if not b.has_meta("gloss_hooked"):
		b.set_meta("gloss_hooked", true)
		b.button_down.connect(func(): gloss.offset_top = 9)
		b.button_up.connect(func(): gloss.offset_top = 5)


## A quick squash when pressed and a bounce back on release.
static func squash(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(0.95, 0.93), 0.06))
	b.button_up.connect(func():
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))


## A chunky round button drawn on `c` (the DASH and special buttons): a darker lip under a
## coloured face, an ink edge and a shine on top. `lit` false draws it dark and quiet.
static func draw_round_button(c: CanvasItem, centre: Vector2, r: float, face: Color, lit: bool) -> void:
	var f := face if lit else Color(0.16, 0.13, 0.22, 0.85)
	var lip := f.darkened(0.45)
	lip.a = f.a
	c.draw_circle(centre + Vector2(0, 5), r + 3.0, Color(0, 0, 0, 0.3))   # shadow
	c.draw_circle(centre + Vector2(0, 4), r, lip)
	c.draw_circle(centre, r, f)
	# The shine: a soft lighter cap on the top half of the face.
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap.append(centre + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.72 - r * 0.02))
	c.draw_colored_polygon(cap, Color(1, 1, 1, 0.16 if lit else 0.06))
	c.draw_arc(centre, r, 0.0, TAU, 48, INK, 3.5, true)
	c.draw_arc(centre + Vector2(0, 4), r, 0.15, PI - 0.15, 32, INK, 3.5, true)


## A little gold coin drawn with a rounded box.
static func coin_icon(size: float) -> Control:
	var p := Control.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.draw.connect(func(): draw_coin(p, p.size * 0.5, minf(p.size.x, p.size.y) * 0.5))
	return p


## A shaded gold coin: an ink edge, a darker rim, a raised face with a ring pressed into it
## and a shine on its upper left.
static func draw_coin(c: CanvasItem, centre: Vector2, r: float) -> void:
	c.draw_circle(centre + Vector2(0, r * 0.12), r, Color(0, 0, 0, 0.35))
	c.draw_circle(centre, r, INK)
	c.draw_circle(centre, r * 0.86, Color(0.82, 0.5, 0.06))
	c.draw_circle(centre + Vector2(0, -r * 0.06), r * 0.72, GOLD)
	c.draw_arc(centre + Vector2(0, -r * 0.04), r * 0.5, 0.0, TAU, 24, Color(0.85, 0.55, 0.08), maxf(1.0, r * 0.1), true)
	c.draw_arc(centre, r * 0.62, PI * 1.05, PI * 1.6, 12, Color(1, 1, 0.9, 0.85), maxf(1.0, r * 0.13), true)


## A coin icon with a number next to it.
## A small "Privacy policy" button that opens the policy page in the browser.
static func privacy_button(text_size := 18) -> Button:
	var b := button("Privacy policy", text_size, Color(0.08, 0.07, 0.1, 0.85), Color(0.6, 0.55, 0.6, 0.4))
	b.add_theme_color_override("font_color", Color(0.75, 0.72, 0.78))
	b.custom_minimum_size = Vector2(200, 58)
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


## A chunky bar (the hero's health, a boss's health): a dark rounded trough with an ink
## edge, a glossy fill with a darker lip under it. Returns the fill; its anchor_right is
## how full the bar is.
func _bar(parent: Control, fill_col: Color) -> Control:
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.12, 0.08, 0.16, 0.92)
	fb.border_color = INK
	fb.set_border_width_all(3)
	fb.set_corner_radius_all(10)
	fb.shadow_color = Color(0, 0, 0, 0.35)
	fb.shadow_size = 2
	fb.shadow_offset = Vector2(0, 3)
	frame.add_theme_stylebox_override("panel", fb)
	parent.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var trough := Control.new()
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.clip_contents = true
	frame.add_child(trough)
	trough.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trough.offset_left = 4
	trough.offset_top = 4
	trough.offset_right = -4
	trough.offset_bottom = -4
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.border_color = fill_col.darkened(0.35)
	sb.border_width_bottom = 4   # the darker lip
	sb.set_corner_radius_all(6)
	fill.add_theme_stylebox_override("panel", sb)
	trough.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shine := ColorRect.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.color = Color(1, 1, 1, 0.22)
	fill.add_child(shine)
	shine.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shine.offset_left = 4
	shine.offset_right = -4
	shine.offset_top = 2
	shine.offset_bottom = 5
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
	hp.position = Vector2(14, 14)
	hp.size = Vector2(240, 36)
	root.add_child(hp)
	_hp_fill = _bar(hp, Color(0.92, 0.2, 0.24))
	_hp_label = label("100 / 100", 20)
	chunky(_hp_label.label_settings)
	_hp_label.label_settings.outline_size = 5
	_hp_label.label_settings.shadow_size = 0
	full(_hp_label)
	hp.add_child(_hp_label)

	var coins := Control.new()
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins.position = Vector2(18, 56)
	coins.size = Vector2(200, 30)
	root.add_child(coins)
	_coin_label = coin_row(24, coins)
	chunky(_coin_label.label_settings)
	_coin_label.label_settings.outline_size = 6

	_room_label = label("", 22, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	chunky(_room_label.label_settings)
	_room_label.label_settings.outline_size = 6
	_room_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_room_label.offset_left = -284
	_room_label.offset_right = -84
	_room_label.offset_top = 12
	_room_label.offset_bottom = 48
	root.add_child(_room_label)

	_wave_label = label("", 20, Color(1, 0.62, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
	chunky(_wave_label.label_settings)
	_wave_label.label_settings.outline_size = 5
	_wave_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_label.offset_left = -284
	_wave_label.offset_right = -84
	_wave_label.offset_top = 44
	_wave_label.offset_bottom = 74
	_wave_label.visible = false
	root.add_child(_wave_label)

	# The Hourglass curse's countdown, under the wave counter.
	_timer_label = label("", 20, Color(1, 0.75, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.offset_left = -284
	_timer_label.offset_right = -84
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
	_pause_button.add_theme_font_override("font", UI_FONT)
	_pause_button.add_theme_constant_override("outline_size", 6)
	_pause_button.add_theme_color_override("font_outline_color", INK)
	paint(_pause_button, "slate")
	for st in ["normal", "hover", "pressed"]:
		var pb := _pause_button.get_theme_stylebox(st).duplicate() as StyleBoxFlat
		pb.set_corner_radius_all(16)
		pb.content_margin_left = 0
		pb.content_margin_right = 0
		_pause_button.add_theme_stylebox_override(st, pb)
	squash(_pause_button)
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.offset_left = -74   # 60 x 60 (version 125, audit #9): a thumb-sized target
	_pause_button.offset_right = -14
	_pause_button.offset_top = 6
	_pause_button.offset_bottom = 66
	_pause_button.pressed.connect(func(): pause_pressed.emit())
	root.add_child(_pause_button)

	# A tip in the empty space at the bottom of the screen during the first room.
	_hint = label("", 27, Color(1, 0.94, 0.78))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -210
	_hint.offset_right = 210
	_hint.offset_top = -128
	_hint.offset_bottom = -88
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN   # two lines grow up, never off the bottom
	_hint.label_settings.outline_size = 7
	_hint.add_theme_stylebox_override("normal", _text_panel())
	_hint.set_script(Pulse)
	_hint.set("low", 0.75)   # a lesson must stay readable at every point of the pulse
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
	chunky(_boss_name.label_settings)
	_boss_name.label_settings.outline_size = 5
	_boss_name.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name.offset_bottom = 26
	_boss_box.add_child(_boss_name)
	var bar_holder := Control.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_holder.offset_top = -26
	_boss_box.add_child(bar_holder)
	_boss_fill = _bar(bar_holder, Color(0.75, 0.1, 0.12))
	# Version 121: a notch at half health shows from the start where Phase 2 begins, and a
	# white flash lights the bar when it does.
	var notch := ColorRect.new()
	notch.color = Color(1.0, 0.92, 0.75, 0.9)
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notch.anchor_left = 0.5
	notch.anchor_right = 0.5
	notch.anchor_bottom = 1.0
	notch.offset_left = -2
	notch.offset_right = 2
	notch.offset_top = 1
	notch.offset_bottom = -1
	bar_holder.add_child(notch)
	_boss_flash = ColorRect.new()
	_boss_flash.color = Color(1, 1, 1, 0)
	_boss_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(_boss_flash)
	bar_holder.add_child(_boss_flash)
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
	chunky(_score_label.label_settings)
	_score_label.label_settings.outline_size = 5
	_score_label.position = Vector2(0, 94)
	_score_label.size = Vector2(320, 24)
	_chain_box.add_child(_score_label)
	_broken_label = label("", 30, Color(1, 0.35, 0.3))
	_broken_label.position = Vector2(-40, 44)
	_broken_label.size = Vector2(400, 44)
	_broken_label.modulate.a = 0.0
	_chain_box.add_child(_broken_label)

	# First-run tips ("Kill fast. Your chain grows.") sit just under the chain meter.
	# Big, short and on a dark panel, so young players and anyone on a small screen can
	# read them over the fight.
	_tip = label("", 27, Color(1, 0.96, 0.84))
	_tip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tip.offset_left = -250
	_tip.offset_right = 250
	_tip.offset_top = 214
	_tip.offset_bottom = 254
	_tip.grow_vertical = Control.GROW_DIRECTION_END   # longer tips grow down, clear of the chain meter
	_tip.label_settings.outline_size = 7
	_tip.label_settings.outline_color = Color(0, 0, 0, 0.9)
	_tip.add_theme_stylebox_override("normal", _text_panel())
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


## Version 121: Phase 2 gets its own banner across the screen, on a dark plate so it reads
## over bullet rings and the lava floor (it used to share the small callout with the tutorial).
func _build_phase_banner() -> void:
	_phase_box = Control.new()
	_phase_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_box.set_anchors_preset(Control.PRESET_CENTER)
	_phase_box.offset_left = -340
	_phase_box.offset_right = 340
	_phase_box.offset_top = -330
	_phase_box.offset_bottom = -190
	_phase_box.pivot_offset = Vector2(340, 70)
	_phase_box.visible = false
	add_child(_phase_box)
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.7)
	sb.set_corner_radius_all(18)
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(1.0, 0.3, 0.2)
	plate.add_theme_stylebox_override("panel", sb)
	full(plate)
	_phase_box.add_child(plate)
	_phase_title = label("PHASE 2", 64, Color.WHITE)
	chunky(_phase_title.label_settings)
	_phase_title.label_settings.outline_size = 12
	_phase_title.label_settings.outline_color = Color(0.55, 0.05, 0.05)
	_phase_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_phase_title.offset_top = 6
	_phase_title.offset_bottom = 92
	_phase_box.add_child(_phase_title)
	_phase_sub = label("", 24, Color(1.0, 0.85, 0.6))
	chunky(_phase_sub.label_settings)
	_phase_sub.label_settings.outline_size = 6
	_phase_sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_phase_sub.offset_top = -48
	_phase_sub.offset_bottom = -10
	_phase_box.add_child(_phase_sub)


## The boss reached half health: the banner pops in (scale 1.6 to 1.0), holds, and fades;
## the boss bar flashes white and the boss's name turns red for the rest of the fight.
## `move` names the new attack that comes next.
func phase_banner(move: String, col := Color(1.0, 0.3, 0.2)) -> void:
	_callout_time = 0.0
	_callout.modulate.a = 0.0
	_phase_sub.text = ("NEW ATTACK: " + move.to_upper()) if move != "" else ""
	(_phase_box.get_child(0).get_theme_stylebox("panel") as StyleBoxFlat).border_color = col
	_phase_title.label_settings.outline_color = col.darkened(0.55)
	_phase_box.visible = true
	_phase_box.modulate.a = 1.0
	_phase_box.scale = Vector2(1.6, 1.6)
	if _phase_tw:
		_phase_tw.kill()
	_phase_tw = create_tween()
	_phase_tw.tween_property(_phase_box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_phase_tw.tween_interval(1.4)
	_phase_tw.tween_property(_phase_box, "modulate:a", 0.0, 0.3)
	_phase_tw.tween_callback(func(): _phase_box.visible = false)
	_boss_flash.color.a = 0.85
	create_tween().tween_property(_boss_flash, "color:a", 0.0, 0.25)
	_boss_name.label_settings.font_color = Color(1.0, 0.35, 0.3)


## A soft dark vignette round the screen edges, under everything else on the HUD (it
## frames the crypt like a lantern's reach), then a red glow there when health is low.
func _build_danger() -> void:
	var v := Gradient.new()
	v.set_color(0, Color(0, 0, 0, 0))
	v.set_color(1, Color(0, 0, 0, 0.5))
	v.add_point(0.55, Color(0, 0, 0, 0))
	v.add_point(0.8, Color(0, 0, 0, 0.16))
	var vt := GradientTexture2D.new()
	vt.gradient = v
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.97, 0.97)
	vt.width = 128
	vt.height = 128
	var vig := TextureRect.new()
	vig.texture = vt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full(vig)
	add_child(vig)
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
	_cards_mastery = label("", 28, GOLD)
	_cards_mastery.visible = false
	col.add_child(_cards_mastery)
	col.add_child(label("CHOOSE A BLESSING", 40, Color(1, 0.85, 0.55)))
	for i in 3:
		# A chunky card: a frame and a thick lip in the blessing's rarity colour (painted in
		# show_cards), a band of that colour across the top, the badge on the left, the name
		# in the cartoon font and the rarity on a ribbon. Rare ones and up get a shine.
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 132)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", StyleBoxFlat.new())
		b.add_theme_stylebox_override("hover", StyleBoxFlat.new())
		b.add_theme_stylebox_override("pressed", StyleBoxFlat.new())
		b.add_theme_stylebox_override("hover_pressed", StyleBoxFlat.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var band := Panel.new()
		band.name = "Band"
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.anchor_right = 1.0
		band.offset_left = 4
		band.offset_top = 4
		band.offset_right = -4
		band.offset_bottom = 48
		b.add_child(band, false, Node.INTERNAL_MODE_FRONT)
		var t := label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		t.position = Vector2(104, 6)
		t.size = Vector2(250, 44)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_child(t)
		var d := label("", 18, Color(0.88, 0.86, 0.94), HORIZONTAL_ALIGNMENT_LEFT)
		d.position = Vector2(104, 52)
		d.size = Vector2(362, 62)
		b.add_child(d)
		var icon := BlessingIcon.new()
		icon.zoom = 1.25
		icon.position = Vector2(14, 22)
		b.add_child(icon)
		var r := label("", 13, INK, HORIZONTAL_ALIGNMENT_CENTER)
		r.anchor_left = 1.0
		r.anchor_right = 1.0
		r.offset_left = -150
		r.offset_right = -12
		r.offset_top = 12
		r.offset_bottom = 34
		r.autowrap_mode = TextServer.AUTOWRAP_OFF
		r.label_settings.outline_size = 0
		r.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		var pill := StyleBoxFlat.new()
		pill.set_corner_radius_all(11)
		pill.content_margin_left = 9
		pill.content_margin_right = 9
		r.add_theme_stylebox_override("normal", pill)
		b.add_child(r)
		var shine := Panel.new()
		shine.name = "Shine"
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ss := StyleBoxFlat.new()
		ss.bg_color = Color(1, 1, 1, 0.22)
		ss.skew = Vector2(-0.6, 0)
		shine.add_theme_stylebox_override("panel", ss)
		shine.size = Vector2(46, 150)
		shine.position = Vector2(-120, -8)
		shine.visible = false
		var clip := Control.new()   # keeps the glint inside the card
		clip.name = "ShineClip"
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		clip.anchor_right = 1.0
		clip.anchor_bottom = 1.0
		clip.offset_left = 4
		clip.offset_top = 4
		clip.offset_right = -4
		clip.offset_bottom = -10
		clip.add_child(shine)
		b.add_child(clip, false, Node.INTERNAL_MODE_BACK)
		b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
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
	col.add_child(label("CHOOSE YOUR DOOR", 40, Color(1, 0.85, 0.55)))
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
	DamageNumber.clear_all()
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
	# Sound, screen shake, vibration and reports can be set before the first run too.
	var settings := button("SETTINGS", 18)
	settings.custom_minimum_size = Vector2(150, 66)
	settings.position = Vector2(20, 20)
	settings.pressed.connect(func(): show_settings(true))
	holder.add_child(settings)
	# REWARDS (version 116): the Bone Road, Bone Drops, Feats and Records in one place, so
	# the returning title has 7 buttons, not 9.
	var records := button("REWARDS", 18, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	records.custom_minimum_size = Vector2(150, 66)
	records.position = Vector2(184, 20)
	records.pressed.connect(func(): show_rewards(true))
	holder.add_child(records)
	_rewards_badge = _badge_pill("")
	_rewards_badge.offset_left = -84
	records.add_child(_rewards_badge)
	_title_records = records
	_title_settings = settings
	_place_title_buttons()
	var top := VBoxContainer.new()
	_title_top = top
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
	_title_gap = gap
	_title_logo = logo_rect()
	top.add_child(_title_logo)
	_title_hint = label("Drag to move. Lift to shoot.", 20, Color(0.85, 0.85, 0.9))
	top.add_child(_title_hint)
	# Said up front, so nobody is surprised when the free floors end.
	_title_free = label("Free to try: floors 1-%d. The Crypt Pass opens the rest." % Store.FREE_FLOORS, 17, Color(0.95, 0.78, 0.45))
	top.add_child(_title_free)
	_title_best = label("", 18, Color(0.7, 0.7, 0.8))
	top.add_child(_title_best)
	# The Bone Road's bar (bone_road.gd): bones so far, and the next reward.
	# Side by side, so the hero below stays in view on short phones.
	_title_road = RoadScreen.Bar.new()
	_title_road.custom_minimum_size = Vector2(250, 58)
	_title_road.pressed.connect(func(): road_pressed.emit())
	# Bone Drops waiting to be opened (drops.gd).
	_title_drops = _drop_button()
	_title_drops.custom_minimum_size = Vector2(240, 58)
	_title_drops.add_theme_font_size_override("font_size", 17)
	var row := _pair(_title_road, _title_drops)
	(row as HBoxContainer).add_theme_constant_override("separation", 10)
	row.visible = false   # (in the REWARDS screen now)
	_title_rewards_row = row
	top.add_child(row)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_top = -40
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", 14)
	holder.add_child(col)
	_title_bottom = col
	# Gold lines under the hero, just above PLAY: why to play today and what's next.
	_title_goal = label("", 18, Color(1.0, 0.82, 0.42))
	col.add_child(_title_goal)
	_title_hero = label("", 26, Color(0.75, 0.85, 1.0))
	col.add_child(_title_hero)
	_title_spacer = Control.new()
	_title_spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(_title_spacer)
	# A saved run (run_save.gd) can be picked up again.
	var cont_col := VBoxContainer.new()
	cont_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont_col.add_theme_constant_override("separation", 2)
	var cont := button("CONTINUE", 36, Color(0.3, 0.2, 0.06, 0.97), GOLD)
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
	# A gold tag when a hero has new looks to try on the Style screen.
	_title_heroes_badge = _badge_pill("NEW LOOKS")
	heroes.add_child(_title_heroes_badge)
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
	_title_modes_badge = _badge_pill("DAILY READY")
	modes.add_child(_title_modes_badge)
	var pass_button := button("CRYPT PASS", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	pass_button.custom_minimum_size = Vector2(222, 74)
	pass_button.pressed.connect(func(): pass_pressed.emit())
	_title_pass_row = pass_button
	_title_modes_row = _pair(modes, pass_button)
	col.add_child(_title_modes_row)
	_title_lock = label("Finish the tutorial to open\nHeroes and the Armory", 20, Color(0.7, 0.68, 0.62))
	col.add_child(_title_lock)


## The gold OPEN BONE DROP button (title and end screens), hidden until one is earned.
func _drop_button() -> Button:
	var b := button("OPEN BONE DROP", 22, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	b.custom_minimum_size = Vector2(320, 64)
	b.visible = false
	b.pressed.connect(func(): drops_pressed.emit())
	return b


## Shows or hides the OPEN BONE DROP buttons for `n` waiting drops.
func set_drops(n: int) -> void:
	for b in [_title_drops, _end_drop]:
		b.visible = n > 0
		b.text = "OPEN BONE DROP" if n == 1 else "OPEN %d BONE DROPS" % n
	if _rewards_box and (_rewards_box.visible or _title_box.visible):
		refresh_rewards()
	_fit_end_soon()


## The Bone Drop screen (drop_screen.gd); `opener` opens one and returns what was inside.
func open_drops(n: int, opener: Callable) -> void:
	_drops.opener = opener
	_drops.open_screen(n)


## The Bone Road screen (road_screen.gd), filled from `cfg`.
func open_road(cfg: ConfigFile) -> void:
	_road.open_road(cfg)


func close_road() -> void:
	if _road.visible:
		_road.visible = false
		road_closed.emit()


func road_visible() -> bool:
	return _road.visible


func close_drops() -> void:
	_drops.close()


func drops_visible() -> bool:
	return _drops.visible


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
	_frame(_modes_box, col, back)


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


## RECORDS on the title: lifetime bests and totals (rows of [name, value] from game.gd).
func _build_records() -> void:
	_records_box = overlay(Color(0.03, 0.02, 0.05, 0.95))
	add_child(_records_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 28
	col.offset_right = -28
	col.offset_top = 24
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	_records_box.add_child(col)
	col.add_child(label("RECORDS", 46, Color(1, 0.85, 0.55)))
	col.add_child(label("Everything you've done in the crypt.", 18, Color(0.8, 0.8, 0.85)))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.13, 0.95)
	sb.border_color = Color(GOLD, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)
	_records_grid = GridContainer.new()
	_records_grid.columns = 2
	_records_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_records_grid.add_theme_constant_override("h_separation", 12)
	_records_grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(_records_grid)
	_records_note = label("", 15, Color(0.65, 0.63, 0.7))
	col.add_child(_records_note)
	var back := button("BACK", 26)
	back.pressed.connect(func(): show_records(false))
	_frame(_records_box, col, back)


func show_records(v: bool, rows := [], note := "") -> void:
	_records_box.visible = v   # (_process hides the title's buttons behind it)
	if not v:
		return
	for c in _records_grid.get_children():
		c.free()
	for r: Array in rows:
		var what := label(str(r[0]), 21, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.autowrap_mode = TextServer.AUTOWRAP_OFF
		_records_grid.add_child(what)
		var value := label(str(r[1]), 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		_records_grid.add_child(value)
	_records_note.text = note
	_records_note.visible = note != ""


func records_visible() -> bool:
	return _records_box.visible


func modes_visible() -> bool:
	return _modes_box.visible


## The Heroes screen (hero_screen.gd).
func _build_heroes() -> void:
	_heroes_box = HeroScreen.new()
	add_child(_heroes_box)
	_heroes_box.pick.connect(func(id: String): hero_pick.emit(id))
	_heroes_box.trial.connect(func(id: String): hero_trial.emit(id))
	_heroes_box.closed.connect(func(): show_heroes(false))
	_heroes_box.mastery.connect(func(id: String): mastery_pressed.emit(id))
	_heroes_box.style.connect(func(id: String): style_pressed.emit(id))
	_heroes_box.feats.connect(func(id: String): feats_hero_pressed.emit(id))


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
	_end_col = col
	_end_box.resized.connect(_fit_end)
	_end_title = label("", 60)
	col.add_child(_end_title)
	_end_score = label("", 40, Color(1, 0.85, 0.45))
	col.add_child(_end_score)
	_end_best = label("", 20, Color(0.8, 0.78, 0.7))
	col.add_child(_end_best)
	_end_stats = label("", 22, Color(0.85, 0.85, 0.9))
	col.add_child(_end_stats)
	# Hero Mastery: the run's points filling the hero's bar (mastery_bar.gd).
	_end_mastery = MasteryBar.new()
	_end_mastery.custom_minimum_size = Vector2(470, 84)
	_end_mastery.visible = false
	col.add_child(_centered(_end_mastery))
	_end_looks = button("SEE 3 NEW LOOKS", 20, Color(0.22, 0.14, 0.3, 0.97), GOLD)
	_end_looks.custom_minimum_size = Vector2(300, 60)
	_end_looks.visible = false
	_end_looks.pressed.connect(func():
		if not _end_looks_for.is_empty():
			see_looks.emit(str(_end_looks_for.id), int(_end_looks_for.level)))
	col.add_child(_centered(_end_looks))
	_end_goal = label("", 22, Color(1.0, 0.82, 0.42))
	_end_goal.visible = false
	col.add_child(_end_goal)
	_end_drop = _drop_button()
	col.add_child(_centered(_end_drop))
	_build_pass_card(col)
	# Daily Crypt: the result card, and the same as text to paste anywhere.
	_share_card = ShareCard.new()
	_share_card.visible = false
	col.add_child(_share_card)
	_share_button = button("SHARE RESULT", 20, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	_share_button.custom_minimum_size = Vector2(240, 60)
	_share_button.pressed.connect(func():
		_share_button.disabled = true
		share_pressed.emit())
	# Copies a detailed report of the run (with the install number the privacy policy asks
	# for), for players who send reports and want to share one.
	_copy_button = button("COPY REPORT", 20, Color(0.1, 0.12, 0.18, 0.95), Color(0.5, 0.75, 1.0, 0.7))
	_copy_button.custom_minimum_size = Vector2(240, 60)
	_copy_button.pressed.connect(func():
		_copy_button.text = "Copied!"
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
	_end_heroes_badge = _badge_pill("NEW LOOKS")
	heroes.add_child(_end_heroes_badge)
	var armory := button("ARMORY", 26)
	armory.custom_minimum_size = Vector2(222, 74)
	armory.pressed.connect(func(): armory_pressed.emit())
	buttons.add_child(_pair(heroes, armory))
	var end_pass := button("CRYPT PASS", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	end_pass.pressed.connect(func(): pass_pressed.emit())
	_end_pass = _centered(end_pass)
	_end_pass.visible = false
	buttons.add_child(_end_pass)
	_end_buttons = buttons
	# Back to the title from the death screen, or after a win (the run stays saved).
	_end_title_btn = button("TITLE", 22, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_end_title_btn.custom_minimum_size = Vector2(222, 66)
	_end_title_btn.pressed.connect(func(): title_pressed.emit())
	_end_title_button = _centered(_end_title_btn)
	_end_title_button.visible = false
	col.add_child(_end_title_button)
	# After the last free floor: the Crypt Pass, or back to the title.
	var offer := VBoxContainer.new()
	offer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offer.add_theme_constant_override("separation", 18)
	col.add_child(offer)
	var get_pass := button("GET THE CRYPT PASS", 28, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	get_pass.custom_minimum_size = Vector2(340, 86)
	get_pass.pressed.connect(func(): pass_pressed.emit())
	offer.add_child(_centered(get_pass))
	var to_title := button("BACK TO TITLE  (RUN SAVED)", 22, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
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
	# Tight enough that the whole menu fits a 16:9 phone.
	col.add_theme_constant_override("separation", 12)
	_pause_box.add_child(col)
	_pause_title = label("PAUSED", 52, Color(1, 0.85, 0.55))
	col.add_child(_pause_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	var resume := button("RESUME", 32, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	resume.custom_minimum_size = Vector2(300, 86)
	resume.pressed.connect(_on_resume_pressed)
	_resume_button = resume
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
	# Full, Reduced, Off, then back to Full.
	_shake_button = button("Screen shake: Full", 22)
	_shake_button.pressed.connect(func(): shake_changed.emit((_shake_level + 2) % 3))
	col.add_child(_centered(_shake_button))
	_vibration_button = button("Vibration: On", 22)
	_vibration_button.pressed.connect(func(): vibration_toggled.emit(not _vibration_on))
	col.add_child(_centered(_vibration_button))
	_reports_button = button("Send reports: Off", 22)
	_reports_button.pressed.connect(func(): reports_toggled.emit(not _reports_on))
	col.add_child(_centered(_reports_button))
	# Three small buttons side by side, so the menu still fits a 16:9 phone.
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation", 8)
	small.add_child(privacy_button(16))
	var fb := button("Send feedback", 16, Color(0.08, 0.07, 0.1, 0.85), Color(1, 0.8, 0.45, 0.5))
	fb.add_theme_color_override("font_color", Color(1, 0.88, 0.62))
	fb.custom_minimum_size = Vector2(160, 58)
	fb.pressed.connect(show_feedback.bind(true))
	small.add_child(fb)
	# Rate us: opens the game's Google Play page (the in-app rating card is only for happy moments).
	var rate := button("Rate us", 16, Color(0.08, 0.07, 0.1, 0.85), Color(1, 0.8, 0.45, 0.5))
	rate.add_theme_color_override("font_color", Color(1, 0.88, 0.62))
	rate.custom_minimum_size = Vector2(150, 58)
	rate.pressed.connect(func():
		Sfx.play("click")
		UpdateGate.open_store_page())
	small.add_child(rate)
	(small.get_child(0) as Control).custom_minimum_size = Vector2(160, 58)
	col.add_child(small)
	_quit_button = button("Quit run", 24, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_quit_button.pressed.connect(_on_quit_pressed)
	col.add_child(_centered(_quit_button))
	# Testers can say which build they were playing; the install number is what the privacy
	# policy asks for to delete someone's reports (shown even with reports off).
	_pause_build = label("Build " + Game.BUILD, 16, Color(0.6, 0.57, 0.65))
	col.add_child(_pause_build)


## SEND FEEDBACK (pause menu and settings): testers type a note that goes to the
## developer's reports sheet with the build, phone and where they are in the game.
## It sits near the top so the phone's keyboard doesn't cover the box.
const FEEDBACK_MAX := 1500


func _build_feedback() -> void:
	_fb_box = overlay(Color(0.03, 0.02, 0.05, 0.96))
	_fb_box.visible = false
	add_child(_fb_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	col.offset_left = 24
	col.offset_right = -24
	col.offset_top = 56
	col.add_theme_constant_override("separation", 12)
	_fb_box.add_child(col)
	col.add_child(label("SEND FEEDBACK", 40, Color(1, 0.85, 0.55)))
	col.add_child(label("What did you enjoy? What felt too hard, unfair or broken? Every note is read.", 19, Color(0.85, 0.83, 0.9)))
	_fb_text = TextEdit.new()
	_fb_text.custom_minimum_size = Vector2(0, 210)
	_fb_text.placeholder_text = "Type your note here..."
	_fb_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_fb_text.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.13)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 0.8, 0.45, 0.5)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	_fb_text.add_theme_stylebox_override("normal", sb)
	_fb_text.add_theme_stylebox_override("focus", sb)
	_fb_text.text_changed.connect(_on_feedback_changed)
	col.add_child(_fb_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var cancel := button("CANCEL", 24)
	cancel.custom_minimum_size = Vector2(190, 72)
	cancel.pressed.connect(show_feedback.bind(false))
	row.add_child(cancel)
	_fb_send = button("SEND", 26, Color(0.45, 0.16, 0.12, 0.97), Color(1, 0.75, 0.4))
	_fb_send.custom_minimum_size = Vector2(190, 72)
	_fb_send.pressed.connect(_on_feedback_send)
	row.add_child(_fb_send)
	col.add_child(row)
	_fb_note = label("", 16, Color(0.65, 0.62, 0.7))
	col.add_child(_fb_note)


const FEEDBACK_NOTE := "Sent with the build, your phone model and where you are in the game, even with reports off. No name or account, so please leave out personal details."


func show_feedback(on: bool) -> void:
	_fb_box.visible = on
	if on:
		_fb_note.text = FEEDBACK_NOTE
		_fb_note.label_settings.font_color = Color(0.65, 0.62, 0.7)
		_on_feedback_changed()
		_fb_text.grab_focus()
	else:
		_fb_text.release_focus()
		DisplayServer.virtual_keyboard_hide()


func feedback_visible() -> bool:
	return _fb_box.visible


func _on_feedback_changed() -> void:
	if _fb_text.text.length() > FEEDBACK_MAX:
		_fb_text.text = _fb_text.text.left(FEEDBACK_MAX)
		_fb_text.set_caret_line(_fb_text.get_line_count() - 1)
		_fb_text.set_caret_column(_fb_text.get_line(_fb_text.get_line_count() - 1).length())
	_fb_send.disabled = _fb_text.text.strip_edges().length() < 3


func _on_feedback_send() -> void:
	var note := _fb_text.text.strip_edges()
	if note.length() < 3:
		return
	if Telemetry.instance == null or not Telemetry.instance.send_feedback(note):
		_fb_note.text = "Feedback can only be sent from the Google Play version of the game."
		_fb_note.label_settings.font_color = Color(1, 0.6, 0.5)
		return
	_fb_text.text = ""
	_fb_send.disabled = true
	_fb_text.release_focus()
	DisplayServer.virtual_keyboard_hide()
	_fb_note.text = "Thanks! Your note is on its way (it waits on your phone if you're offline)."
	_fb_note.label_settings.font_color = Color(0.6, 1, 0.65)
	get_tree().create_timer(1.8, true, false, true).timeout.connect(func():
		if _fb_text.text == "":
			show_feedback(false))


func _on_resume_pressed() -> void:
	if _settings_only:
		show_settings(false)
	else:
		resume_pressed.emit()


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
	_shop_title = label("ARMORY", 46, Color(1, 0.85, 0.55))
	col.add_child(_shop_title)
	_shop_sub = label("Upgrades bought here last forever.", 18, Color(0.8, 0.8, 0.85))
	col.add_child(_shop_sub)
	var tabs := []
	for tab in [["upgrades", "UPGRADES"], ["vault", "VAULT"]]:
		var tb := button(tab[1], 20)
		tb.custom_minimum_size = Vector2(200, 60)
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
	_frame(_armory_box, col, back)


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
	# The Crypt King set first: the one thing you can see on your hero, everywhere.
	for tile in [["looks", "Crypt King set"], ["floors", "The Drowned Vault"], ["daily", "Daily practice"], ["curses", "All 10 Curses"]]:
		grid.add_child(_pass_tile(tile[0], tile[1]))
	_pass_more = label("", 16, Color(0.88, 0.85, 0.78))
	col.add_child(_pass_more)
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
	_pass_restore.custom_minimum_size = Vector2(220, 58)
	_pass_restore.pressed.connect(func(): pass_restore.emit())
	col.add_child(_centered(_pass_back))
	col.add_child(_pair(_pass_restore, privacy_button()))


## Version 122: the Crypt Pass on the end screen is a card with your own hero wearing the
## Crypt King set on a little pedestal (it was two grey lines of text).
func _build_pass_card(col: Control) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.04, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 8
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(1.0, 0.75, 0.25, 0.3)
	sb.shadow_size = 10
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	_pass_card_stage = HeroStage.new(Vector2(170, 196))
	_pass_card_stage.custom_minimum_size = Vector2(170, 196)
	_pass_card_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pass_card_stage)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)
	var t := label("CRYPT PASS", 30, GOLD)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(t)
	_pass_card_line = label("", 16, Color(0.95, 0.9, 0.8))
	_pass_card_line.custom_minimum_size = Vector2(250, 0)
	v.add_child(_pass_card_line)
	var b := button("SEE THE PASS", 22, Color(0.45, 0.3, 0.08, 0.98), GOLD)
	b.custom_minimum_size = Vector2(240, 60)
	b.pressed.connect(func(): pass_pressed.emit())
	v.add_child(_centered(b))
	_pass_card = _centered(panel)
	_pass_card.visible = false
	col.add_child(_pass_card)


## Shows the card with `def` (the hero dressed in the set), or hides it.
func show_pass_card(v: bool, def := {}) -> void:
	_pass_card.visible = v and not def.is_empty()
	_pass_card_stage.set_active(_pass_card.visible)
	if _pass_card.visible:
		_pass_card_stage.show_hero(def)
		_pass_card_line.text = "Your %s in the\nCrypt King set.\nEndless floors, every\nhero and more." % str(def.title)
	_fit_end_soon()


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
		if Store.instance:
			Store.instance.cancel_wait()
		return
	var coins_of_heroes := 0
	for h: Dictionary in Heroes.LIST:
		coins_of_heroes += int(h.cost)
	_pass_tiles[0].text = "The grandest looks, for\nevery hero: try them on!"
	_pass_tiles[1].text = "A flooded floor and its boss,\nthen endless loops"
	_pass_tiles[2].text = "Replay today's Daily\nCrypt as often as you like"
	_pass_tiles[3].text = "Curse Level up to %d,\nplus hero rewards" % Curses.max_level()
	_pass_more.text = "Plus all 4 heroes now (no need to spend %d coins)." % coins_of_heroes
	_pass_buy.disabled = owned
	# On a Play install the button waits for Play's price in the player's own currency;
	# elsewhere (the test build, which can't buy) it shows the US price.
	var shown_price := price if price != "" else ("" if Store.can_buy() else Store.FALLBACK_PRICE)
	_pass_buy.text = "OWNED - THANK YOU!" if owned else ("UNLOCK  " + shown_price).strip_edges()
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
	_frame(_daily_box, col, back)


## info: {title, theme, theme_text, hero, mult, rules: [{title, text, kind}], status, open, practice, next}
func show_daily(v: bool, info := {}) -> void:
	_daily_box.visible = v
	_disarm(_daily_go)   # a first tap from before (then BACK) mustn't make the next tap start
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
	_frame(_omen_box, col, back)


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
	var text := label("Send anonymous crash and run reports?\nNo name, account or ad ID. Change it any time in Settings.", 21, Color(0.9, 0.88, 0.84))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	# The full list, for anyone who wants it, one tap away.
	var more := label("Sent: a run summary, a short daily note, a random install number, your phone model, Android version and memory, and error messages with the game's recent log.", 16, Color(0.7, 0.68, 0.66))
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	more.visible = false
	var what := button("WHAT'S SENT?", 18, Color(0.08, 0.07, 0.1, 0.9), Color(0.5, 0.48, 0.5, 0.6))
	what.custom_minimum_size = Vector2(240, 60)
	what.pressed.connect(func():
		more.visible = not more.visible
		Sfx.play("click"))
	col.add_child(_centered(what))
	col.add_child(more)
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


## Test hook: pretend the phone has these notch margins (left, top, right, bottom, UI units).
static var fake_safe := Vector4.ZERO


## The space a notch, camera hole or rounded corners take on each side, in UI units:
## x = left, y = top, z = right, w = bottom. Zero off phones.
static func safe_margins(vp: Viewport) -> Vector4:
	if fake_safe != Vector4.ZERO:
		return fake_safe
	if not OS.has_feature("mobile") or vp == null:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var size := vp.get_visible_rect().size
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var sx := size.x / win.x
	var sy := size.y / win.y
	return Vector4(maxf(0.0, safe.position.x * sx), maxf(0.0, safe.position.y * sy),
		maxf(0.0, (win.x - safe.end.x) * sx), maxf(0.0, (win.y - safe.end.y) * sy))


## Version 125 (audit #8): moves a control's edges in by the safe margins. The first call
## remembers the control's own offsets, so it can run every time a screen opens. An edge
## anchored to the left or top moves right or down, one anchored right or bottom moves back.
static func safe_pad(c: Control) -> void:
	if c == null or not c.is_inside_tree():
		return
	if not c.has_meta("safe_base"):
		c.set_meta("safe_base", Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom))
	var b: Vector4 = c.get_meta("safe_base")
	var m := safe_margins(c.get_viewport())
	c.offset_left = b.x + (m.x if c.anchor_left < 0.5 else -m.z)
	c.offset_right = b.z + (m.x if c.anchor_right < 0.5 else -m.z)
	c.offset_top = b.y + (m.y if c.anchor_top < 0.5 else -m.w)
	c.offset_bottom = b.w + (m.y if c.anchor_bottom < 0.5 else -m.w)


func _apply_safe_area() -> void:
	# Keep the HUD clear of notches and rounded corners (phones only).
	var m := safe_margins(get_viewport())
	if m == Vector4.ZERO and not OS.has_feature("mobile"):
		return
	_safe.add_theme_constant_override("margin_left", int(m.x))
	_safe.add_theme_constant_override("margin_top", int(m.y))
	_safe.add_theme_constant_override("margin_right", int(m.z))
	_safe.add_theme_constant_override("margin_bottom", int(m.w))
	_place_title_buttons()
	# Version 123: the framed menus (title at the top, BACK in the corner) keep clear of a
	# camera hole or rounded corners too; they used to sit in the middle, away from the edges.
	var top := float(_safe.get_theme_constant("margin_top"))
	var bottom := float(_safe.get_theme_constant("margin_bottom"))
	var left := float(_safe.get_theme_constant("margin_left"))
	for f: Array in _framed:
		var col: Control = f[0]
		var back: Control = f[1]
		col.offset_top = FRAME_TOP + top
		col.offset_bottom = -FRAME_BOTTOM - bottom
		back.offset_left = 24 + left
		back.offset_right = 204 + left
		back.offset_top = -96 - bottom
		back.offset_bottom = -24 - bottom


## The title's SETTINGS and RECORDS sit in the top corner, so they move below a notch or
## camera hole (the game runs full screen; the margins are 0 off phones).
func _place_title_buttons() -> void:
	if _safe == null or _title_settings == null or not is_instance_valid(_title_settings):
		return
	var left := float(_safe.get_theme_constant("margin_left"))
	var top := float(_safe.get_theme_constant("margin_top"))
	_title_settings.position = Vector2(20 + left, 20 + top)
	if is_instance_valid(_title_records):
		_title_records.position = Vector2(184 + left, 20 + top)
	# Version 125: the coins, logo and the button column keep clear of the notch and the
	# gesture bar too (the corner buttons above already did).
	if is_instance_valid(_title_top):
		safe_pad(_title_top)
	if is_instance_valid(_title_bottom):
		safe_pad(_title_bottom)


# ---------------------------------------------------------------- input

func _overlay_open() -> bool:
	return _cards_box.visible or _doors_box.visible or _title_box.visible or _end_box.visible or _pause_box.visible or _armory_box.visible or _pass_box.visible \
		or _daily_box.visible or _omen_box.visible or _ask_box.visible or _modes_box.visible or _heroes_box.visible \
		or _fb_box.visible or _records_box.visible or _drops.visible or _road.visible or _mastery.visible or _style.visible \
		or _rewards_box.visible or _feats.visible


func _input(event: InputEvent) -> void:
	if UpdateGate.instance and UpdateGate.instance.showing():
		return   # the UPDATE screen covers everything
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _end_box.visible and not _end_buttons.visible and not _end_offer.visible and not _end_loop.visible \
					and not _armory_box.visible and not _pass_box.visible and not _omen_box.visible and not _ask_box.visible \
					and not _heroes_box.visible and not _drops.visible \
					and not (_end_drop.visible and _end_drop.get_global_rect().has_point(t.position)) \
					and not (_end_looks.visible and _end_looks.get_global_rect().has_point(t.position)) and not _style.visible \
					and not _copy_button.get_global_rect().has_point(t.position) \
					and not (_end_title_button.visible and _end_title_btn.get_global_rect().has_point(t.position)) \
					and not (_share_button.visible and _share_button.get_global_rect().has_point(t.position)):
				screen_tapped.emit()
				return
			# The pause button looks small but answers a little way around it too.
			if _safe.visible and _pause_button.get_global_rect().grow(12.0).has_point(t.position):
				if not _pause_button.get_global_rect().has_point(t.position) and _pause_button.is_visible_in_tree() and not _overlay_open():
					pause_pressed.emit()
				return
			if _safe.visible and _special.visible and not _overlay_open() \
					and _special.get_global_rect().grow(4.0).has_point(t.position):
				special_pressed.emit()
				return
			if _safe.visible and _dash_button.visible and not _overlay_open() \
					and _dash_button.get_global_rect().grow(4.0).has_point(t.position):
				dash_pressed.emit()
				return
			if _stick_touch == -1 and not _overlay_open() and Game.state == Game.State.PLAYING:
				_stick_touch = t.index
				_stick_origin = t.position
				_stick_start = t.position
				_stick_start_ms = Time.get_ticks_msec()
				_stick.visible = true
				_stick.position = _stick_origin
				_stick.knob = Vector2.ZERO
				joystick = Vector2.ZERO
		elif t.index == _stick_touch:
			var flick := t.position - _stick_start
			if Time.get_ticks_msec() - _stick_start_ms < int(FLICK_TIME * 1000.0) and flick.length() > FLICK_DISTANCE:
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
			if joystick != Vector2.ZERO:
				last_move = joystick.normalized()
				last_move_ms = Time.get_ticks_msec()


func _release_stick() -> void:
	if joystick != Vector2.ZERO:
		last_move_ms = Time.get_ticks_msec()
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
			or _pass_box.visible or _heroes_box.visible or _records_box.visible or _omen_box.visible or _drops.visible or _road.visible \
			or (_settings_only and _pause_box.visible))
	# The OPEN BONE DROP buttons glow gently, so a drop waiting isn't missed.
	if _title_drops.is_visible_in_tree() or _end_drop.is_visible_in_tree():
		var glow := 1.0 + 0.16 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.2))
		_title_drops.modulate = Color(glow, glow, glow)
		_end_drop.modulate = Color(glow, glow, glow)
	if _flash.color.a > 0.0:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.5)
	_see_through(delta)
	_chain_box.offset_top = 122.0 if _boss_box.visible else 88.0
	_chain_box.offset_bottom = _chain_box.offset_top + 122.0
	# Hidden behind the pause menu, where it would cross "Paused".
	var meter := Game.chain_unlocked() and Game.state in [Game.State.PLAYING, Game.State.UPGRADE]
	# With no chain going it stays faint (it sits over the far end of the room).
	var want := (1.0 if Game.chain > 1.01 or _broken_time > 0.0 else 0.45) if meter else 0.0
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
	_update_tally(delta)
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
		var hp_text := Vector2i(ceili(hero.health), roundi(hero.max_health))
		if hp_text != _hp_shown:   # format the text only when the numbers change
			_hp_shown = hp_text
			_hp_label.text = "%d / %d" % [hp_text.x, hp_text.y]
		var low := 1.0 - clampf(hero.health / hero.max_health / 0.35, 0.0, 1.0)
		if hero.dead or not _safe.visible:
			low = 0.0
		var beat := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		_danger.modulate.a = move_toward(_danger.modulate.a, low * beat, delta * 3.0)
		# Below about a fifth of health a quiet heartbeat keeps time with the red glow.
		var phase := fmod(Time.get_ticks_msec() * 0.008 / TAU, 1.0)
		if low > 0.4 and Game.state == Game.State.PLAYING and phase < _beat_phase:
			Sfx.play("heart", 0.35 + 0.4 * low)
		_beat_phase = phase
	var boss := Game.boss
	if boss and is_instance_valid(boss):
		_boss_fill.anchor_right = Game.boss_bar()
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.4, 0.0, 1.0)
		var s := 1.0 + maxf(0.0, _banner_time - 1.6)
		# The pop-in never pushes a wide banner off the screen edges.
		s = minf(s, maxf(1.0, (get_viewport().get_visible_rect().size.x - 24.0) / maxf(_banner_w, 1.0)))
		_banner.scale = Vector2(s, s)
		_banner.pivot_offset = _banner.size / 2


## A-8: the DASH and special buttons and the boss bar sit over the arena. When the hero or
## an enemy goes behind one, it turns see-through so the fight under it stays readable.
## The buttons still answer taps.
func _see_through(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var fighting := Game.state == Game.State.PLAYING and cam != null
	for c: Control in [_special, _dash_button, _boss_box]:
		var want := 1.0
		if fighting and c.visible:
			var r := c.get_global_rect().grow(14.0)
			for a in Actor.all:
				if is_instance_valid(a) and not a.dead and not cam.is_position_behind(a.center()) \
						and r.has_point(cam.unproject_position(a.center())):
					want = 0.35
					break
		c.modulate.a = move_toward(c.modulate.a, want, delta * 5.0)


# ---------------------------------------------------------------- API used by game.gd

func set_room(index: int, total: int, boss: bool, floor_num := 1) -> void:
	_room_label.text = "Boss" if boss else "Room %d / %d" % [index, total]
	if floor_num > 1:
		_room_label.text = "F%d · %s" % [floor_num, _room_label.text]
	_boss_box.visible = boss


func set_boss_name(n: String) -> void:
	_boss_name.text = n
	_boss_name.label_settings.font_color = Color(1, 0.8, 0.6)


func hide_boss() -> void:
	_boss_box.visible = false
	_hide_phase()


## Version 123: the Phase 2 banner is drawn above the pause menu and the end screen, so it
## goes at once when either opens (it stayed up to 2 s over YOU DIED or PAUSED).
func _hide_phase() -> void:
	if _phase_tw:
		_phase_tw.kill()
	_phase_box.visible = false


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
	# A-7: the banner takes the spot, so a callout still showing there fades out now.
	_callout_time = minf(_callout_time, 0.25)
	_banner.text = text
	_banner.label_settings.font_color = col
	var fs := 48 if text.length() <= 16 else 38
	# Long banners ("Loop 2 · Floor 6: Drowned Vault") shrink until they fit the screen.
	var room := get_viewport().get_visible_rect().size.x - 40.0
	var font: Font = _banner.label_settings.font if _banner.label_settings.font else ThemeDB.fallback_font
	var outline := _banner.label_settings.outline_size
	while fs > 22 and font and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + outline > room:
		fs -= 2
	_banner.label_settings.font_size = fs
	_banner_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + outline if font else 0.0
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


## A tip is showing, or waiting to show.
func tip_busy() -> bool:
	return _tip_time > 0.0 or _tip_delay > 0.0


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
	# A-7: while a room banner shows, the callout drops just below it instead of on it.
	var drop := 60.0 if _banner_time > 0.3 else 0.0
	_callout.offset_top = -190.0 + drop
	_callout.offset_bottom = -130.0 + drop
	_callout_time = 1.1


## PERFECT! just above the hero's head, where the eye already is (it used to show at the top
## of the screen, over the gold hero and the pink shots).
var _perfect_lbl: Label
var _perfect_tw: Tween

func callout_at_hero(text: String, col := Color(0.6, 0.95, 1.0)) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.hero == null:
		callout(text, col)
		return
	if _perfect_lbl == null:
		_perfect_lbl = label("", 40, col)
		_perfect_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		_perfect_lbl.label_settings.outline_size = 10
		_perfect_lbl.label_settings.outline_color = Color(0.02, 0.05, 0.12)
		_perfect_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_perfect_lbl)
	_perfect_lbl.text = text
	_perfect_lbl.label_settings.font_color = col
	_perfect_lbl.reset_size()
	_perfect_lbl.pivot_offset = _perfect_lbl.size * 0.5
	_place_perfect(0.0)
	_perfect_lbl.visible = true
	_perfect_lbl.modulate.a = 1.0
	_perfect_lbl.scale = Vector2(1.5, 1.5)
	if _perfect_tw:
		_perfect_tw.kill()
	_perfect_tw = create_tween().set_ignore_time_scale(true)
	_perfect_tw.tween_property(_perfect_lbl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# It rides above the hero as they dash (version 119: it was left behind at the old spot).
	_perfect_tw.parallel().tween_method(_place_perfect, 0.0, 40.0, 0.9)
	_perfect_tw.tween_property(_perfect_lbl, "modulate:a", 0.0, 0.25)
	_perfect_tw.tween_callback(func(): _perfect_lbl.visible = false)


func _place_perfect(rise: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.hero == null or not is_instance_valid(Game.hero) or _perfect_lbl == null:
		return
	var at := cam.unproject_position(Game.hero.global_position + Vector3.UP * 2.3)
	_perfect_lbl.position = at - Vector2(_perfect_lbl.size.x * 0.5, _perfect_lbl.size.y + rise)


## A quick white (or coloured) flash over the whole screen.
## Flashes are softer with Screen shake reduced or off, for anyone who finds them too much.
func flash(col := Color(1, 1, 1), strength := 0.6) -> void:
	_flash.color = Color(col.r, col.g, col.b, strength * lerpf(0.3, 1.0, Game.shake_scale))


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
## `mastery` is a mid-run Hero Mastery level-up line to show over the cards ("" for none;
## null keeps what shows, for a reroll).
func show_cards(choices: Array, rerolls := 0, tags := true, mastery: Variant = null) -> void:
	DamageNumber.clear_all()
	if mastery != null:
		_cards_mastery.text = str(mastery)
		_cards_mastery.visible = str(mastery) != ""
		if _cards_mastery.visible:
			_cards_mastery.pivot_offset = Vector2(_cards_mastery.size.x * 0.5, 34)
			_cards_mastery.scale = Vector2(1.35, 1.35)
			var tw := _cards_mastery.create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(_cards_mastery, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
		(labels[1] as Label).text = Upgrades.card_text(u)
		(labels[2] as BlessingIcon).show_for(u)
		var kind: String = Heroes.get_hero(u.hero).title.to_upper() if u.has("hero") else Upgrades.FAMILIES[u.family].name.to_upper()
		(labels[3] as Label).text = "%s · %s" % [kind, rar.name] if tags else kind
		var col: Color = rar.color if tags else Color(0.62, 0.64, 0.7)
		_paint_card(b, col, tags and u.rarity != "common")
		# Dealt in one after another, each card flipping over from edge on.
		b.scale = Vector2(0.0, 0.92)
		b.modulate.a = 0.0
		var tw := b.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.07 * i)
		tw.tween_property(b, "modulate:a", 1.0, 0.05)
		tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var tag := labels[3] as Label
		tag.offset_left = tag.offset_right - tag.get_minimum_size().x   # the ribbon fits its words
		var shine := b.get_node("ShineClip/Shine") as Panel
		shine.visible = tags and u.rarity != "common"
		if shine.visible:
			# A glint sweeps across rare, epic and synergy cards as they land.
			shine.position.x = -120
			tw.tween_property(shine, "position:x", 560.0, 0.45).set_ease(Tween.EASE_IN_OUT)
	_reroll_button.visible = rerolls > 0
	_reroll_button.text = "Reroll (%d left)" % rerolls
	_cards_box.visible = true
	_cards_age = 0.0


## A blessing card in its rarity colour: the frame and the thick lip under it, a band across
## the top, the ribbon. `bright` (rare and up) gets a deeper tint and a stronger band.
func _paint_card(b: Button, col: Color, bright: bool) -> void:
	var face := Color(0.13, 0.1, 0.19).lerp(col.darkened(0.6), 0.32 if bright else 0.14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = face
	normal.border_color = col if bright else col.darkened(0.15)
	normal.set_border_width_all(4)
	normal.border_width_bottom = 10   # the card's thick lip
	normal.set_corner_radius_all(18)
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0, 5)
	normal.anti_aliasing_size = 1.2
	var lip := normal.duplicate() as StyleBoxFlat
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = face.lightened(0.08)
	pressed.border_width_bottom = 5
	pressed.border_width_top = 9
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", lip)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	var band := StyleBoxFlat.new()
	band.bg_color = Color(col, 0.26 if bright else 0.12)
	band.corner_radius_top_left = 14
	band.corner_radius_top_right = 14
	(b.get_node("Band") as Panel).add_theme_stylebox_override("panel", band)
	var r := b.get_child(3) as Label
	(r.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = col


## A little gold tag for the top right corner of a title button.
func _badge_pill(text: String) -> Label:
	var l := label(text, 13, Color(0.12, 0.08, 0.02))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.label_settings.outline_size = 0
	var pill := StyleBoxFlat.new()
	pill.bg_color = GOLD
	pill.set_corner_radius_all(9)
	pill.content_margin_left = 8
	pill.content_margin_right = 8
	l.add_theme_stylebox_override("normal", pill)
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.offset_left = -104
	l.offset_right = 4
	l.offset_top = -10
	l.offset_bottom = 10
	return l


## The title's NEW LOOKS tag: shown while any hero has looks the Style screen hasn't shown.
func refresh_looks_badge() -> void:
	var cfg := Game._load_save()
	var n := 0
	for h: Dictionary in Heroes.LIST:
		n += HeroStyle.unseen(cfg, h.id)
	_title_heroes_badge.visible = n > 0
	_end_heroes_badge.visible = n > 0


var _rewards_box: ColorRect
var _rewards_badge: Label
var _title_rewards_row: Control
var _rw_road: RoadScreen.Bar
var _rw_drops: Button
var _rw_feats: Button
var _rw_drops_sub: Label
var _rw_feats_sub: Label
var _rw_road_sub: Label


func _build_rewards() -> void:
	_rewards_box = overlay(Color(0.03, 0.02, 0.05, 1.0))
	backdrop(_rewards_box)
	add_child(_rewards_box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 30
	col.offset_right = -30
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_rewards_box.add_child(col)
	col.add_child(label("REWARDS", 46, GOLD))
	col.add_child(label("Everything you've earned, all free.", 19, Color(0.8, 0.78, 0.85)))
	_rw_road = RoadScreen.Bar.new()
	_rw_road.custom_minimum_size = Vector2(420, 70)
	_rw_road.pressed.connect(func(): road_pressed.emit())
	# Version 121: every row says where it stands in a line under it ("2 waiting",
	# "140/180 bones", "6/20 done"), and all rows share one size.
	col.add_child(_reward_row(_rw_road, null))
	_rw_road_sub = col.get_child(col.get_child_count() - 1).get_child(1)
	_rw_drops = button("BONE DROPS", 24, Color(0.3, 0.2, 0.06, 0.97), GOLD)
	_rw_drops.pressed.connect(func(): drops_pressed.emit())
	col.add_child(_reward_row(_rw_drops, null))
	_rw_drops_sub = col.get_child(col.get_child_count() - 1).get_child(1)
	_rw_feats = button("FEATS", 24, Color(0.05, 0.16, 0.2, 0.97), Color(0.5, 0.95, 1.0))
	_rw_feats.pressed.connect(func(): feats_pressed.emit())
	col.add_child(_reward_row(_rw_feats, null))
	_rw_feats_sub = col.get_child(col.get_child_count() - 1).get_child(1)
	var rec := button("RECORDS", 24)
	rec.pressed.connect(func(): records_pressed.emit())
	col.add_child(_reward_row(rec, "Best runs, bosses beaten and totals"))
	# The same blue BACK as the Feats, Mastery and Armory screens (version 119: it was grey).
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var close := button("BACK", 26)
	close.pressed.connect(func(): show_rewards(false))
	_frame(_rewards_box, col, close)
	_rewards_box.visible = false


## Version 122: one screen frame for the menus. The title sits at the top (44 px gold
## capitals), the list starts under it, and BACK is always the same 180 x 72 button,
## 24 px from the bottom-left corner (it used to be in four different places).
const FRAME_TOP := 40.0
const FRAME_BOTTOM := 112.0

var _framed: Array = []   # [col, back] of each framed screen, moved clear of a notch

func _frame(box: Control, col: VBoxContainer, back: Button) -> void:
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.offset_top = FRAME_TOP
	col.offset_bottom = -FRAME_BOTTOM
	_framed.append([col, back])
	var title := col.get_child(0) as Label
	if title:
		title.text = title.text.to_upper()
		title.label_settings.font_size = 44
	box.add_child(back_corner(back))


## `back` in the bottom-left corner of a full-screen box.
static func back_corner(back: Button) -> Button:
	back.custom_minimum_size = Vector2(180, 72)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 24
	back.offset_right = 204
	back.offset_top = -96
	back.offset_bottom = -24
	return back


## One REWARDS row: the 420 x 78 button and a small status line under it.
func _reward_row(b: Control, sub: Variant) -> Control:
	b.custom_minimum_size = Vector2(420, 78)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	v.add_child(b)
	var l := label(str(sub) if sub != null else "", 17, Color(0.78, 0.75, 0.84))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(l)
	return v


func show_rewards(v: bool) -> void:
	if v:
		Sfx.play("click")
		refresh_rewards()
	_rewards_box.visible = v


func rewards_visible() -> bool:
	return _rewards_box.visible


## The REWARDS screen's rows and the title button's badge ("CLAIM", "2 DROPS", "NEW").
func refresh_rewards() -> void:
	var cfg := Game._load_save()
	var ni := BoneRoad.next_index(cfg)
	_rw_road.set_road(BoneRoad.bones(cfg), int(BoneRoad.STEPS[ni].at) if ni < BoneRoad.STEPS.size() else 0,
			BoneRoad.progress(cfg), BoneRoad.ready_count(cfg))
	var n := Drops.waiting(cfg)
	_rw_drops.text = ("OPEN BONE DROP" if n == 1 else "OPEN %d BONE DROPS" % n) if n > 0 else "BONE DROPS  ·  looks %d/%d" % [Drops.found_looks(cfg), Drops.all_looks()]
	_rw_drops.disabled = n <= 0
	var fnew := bool(cfg.get_value(Feats.SECTION, "new", false))
	_rw_feats.text = "FEATS  %d/%d%s" % [Feats.count(cfg), Feats.LIST.size(), "  NEW!" if fnew else ""]
	var ready := BoneRoad.ready_count(cfg)
	if ready > 0:
		_rw_road_sub.text = "%d reward%s ready to claim" % [ready, "" if ready == 1 else "s"]
	elif ni < BoneRoad.STEPS.size():
		_rw_road_sub.text = "%d / %d bones to the next reward" % [BoneRoad.bones(cfg), int(BoneRoad.STEPS[ni].at)]
	else:
		_rw_road_sub.text = "Every reward claimed"
	var pity := Drops.pity_text(cfg)
	_rw_drops_sub.text = ("%d waiting" % n if n > 0 else "None waiting: win runs to earn more") + ("  ·  " + pity if pity != "" and n > 0 else "")
	_rw_feats_sub.text = "%d of %d done  ·  each one wins a look" % [Feats.count(cfg), Feats.LIST.size()]
	var badge := ""
	if BoneRoad.ready_count(cfg) > 0:
		badge = "CLAIM"
	elif n > 0:
		badge = "%d DROP%s" % [n, "" if n == 1 else "S"]
	elif fnew:
		badge = "NEW"
	_rewards_badge.text = badge
	_rewards_badge.visible = badge != ""


func show_title(v: bool, best := "", coins := 0) -> void:
	_title_box.visible = v
	var locked := Game.first_run_pending()
	var has_pass := Store.owned()
	_title_shop_row.visible = not locked
	_title_pass_row.visible = not locked and not has_pass
	_title_modes_row.visible = not locked
	_title_records.visible = not locked
	_title_road.visible = not locked
	if v:
		var cfg := Game._load_save()
		set_drops(0 if locked else Drops.waiting(cfg))
		refresh_rewards()
		var ni := BoneRoad.next_index(cfg)
		_title_road.set_road(BoneRoad.bones(cfg), int(BoneRoad.STEPS[ni].at) if ni < BoneRoad.STEPS.size() else 0,
				BoneRoad.progress(cfg), BoneRoad.ready_count(cfg))
	_title_modes_badge.visible = not Curses.official_used(Game._load_save())
	refresh_looks_badge()
	_title_lock.visible = locked
	if not v:
		show_modes(false)
		show_records(false)
		_rewards_box.visible = false
		_road.visible = false
		if not _end_box.visible:
			_drops.visible = false
	_title_free.visible = not has_pass and not locked   # not before the tutorial run is done
	_title_best.text = best
	_title_coins.text = str(coins)
	var where := Game.continue_text()
	_title_continue.visible = where != "" and not locked
	# On short screens a saved run's CONTINUE button leaves room for one gold line only.
	var goal := Game.title_goal() if v else ""
	var view := get_viewport().get_visible_rect().size
	if _title_continue.visible and view.y < view.x * 1.9:
		goal = goal.get_slice("\n", 0)
	_title_goal.text = goal
	_title_goal.visible = goal != ""
	# Short screens: the how-to line makes room for the Bone Road row, so the hero shows.
	var tight := view.y < view.x * 1.9 and _title_rewards_row.visible
	_title_hint.visible = locked and not tight   # the lobby keeps words few once the tutorial is done
	_title_best.visible = not tight   # (the Records screen has it)
	_title_gap.custom_minimum_size.y = 14.0 if tight else 40.0
	_continue_where.text = where
	_title_spacer.visible = not _title_continue.visible
	_title_play.text = "NEW RUN" if _title_continue.visible else "PLAY"
	_title_play.add_theme_font_size_override("font_size", 32 if _title_continue.visible else 38)
	_title_play.remove_meta("armed")


func title_visible() -> bool:
	return _title_box.visible


## The free space on the title screen between the words at the top and the buttons at the
## bottom, where the lobby camera puts the hero (in the viewport's pixels).
func title_hero_space() -> Rect2:
	var top := _title_top.get_global_rect().end.y + 10.0
	var bottom := _title_bottom.get_global_rect().position.y - 4.0
	var w := get_viewport().get_visible_rect().size.x
	return Rect2(0, top, w, maxf(bottom - top, 1.0))


func set_coins(n: int) -> void:
	_coin_target = n
	_coin_label.text = str(n - _coins_flying)
	_title_coins.text = str(n)


var _coin_target := 0
var _coins_flying := 0
var _flights := 0
const MAX_FLIGHTS := 14


## A coin picked up in the room flies up to the coin counter, and the counter ticks up and
## bounces when it lands. Call before the coins are added (Game.add_coins).
func fly_coin(world_pos: Vector3, value: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not visible or _flights >= MAX_FLIGHTS or cam.is_position_behind(world_pos):
		return
	var from := cam.unproject_position(world_pos)
	var to: Vector2 = (_coin_label.get_parent() as Control).get_global_rect().position + Vector2(11, 14)
	var dot := Control.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size = Vector2(32, 32)
	dot.pivot_offset = dot.size * 0.5
	dot.draw.connect(func(): draw_coin(dot, dot.size * 0.5, 15.0))
	add_child(dot)
	dot.position = from - dot.size * 0.5
	_flights += 1
	_coins_flying += value
	# Up and to the side first, then a swoop into the counter.
	var mid := from.lerp(to, 0.35) + Vector2(randf_range(-60.0, 60.0), -50.0)
	var tw := dot.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		dot.position = a.lerp(b, t) - dot.size * 0.5
		dot.scale = Vector2.ONE * lerpf(1.25, 0.8, t), 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		dot.queue_free()
		_flights -= 1
		_coins_flying = maxi(0, _coins_flying - value)
		_coin_label.text = str(_coin_target - _coins_flying)
		_bump_coins())


func _bump_coins() -> void:
	var row := _coin_label.get_parent() as Control
	row.pivot_offset = Vector2(14, 15)
	var tw := row.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(row, "scale", Vector2(1.25, 1.25), 0.05)
	tw.tween_property(row, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


## Screen shake level: 2 full, 1 reduced, 0 off.
func set_shake_label(level: int) -> void:
	_shake_level = level
	_shake_button.text = "Screen shake: " + ["Off", "Reduced", "Full"][clampi(level, 0, 2)]


func set_vibration_label(on: bool) -> void:
	_vibration_on = on
	_vibration_button.text = "Vibration: On" if on else "Vibration: Off"


func armory_visible() -> bool:
	return _armory_box.visible


## rows: [{id, title, text, level, max, cost}] where cost is -1 once maxed out.
func show_armory(v: bool, rows := [], coins := 0) -> void:
	_armory_box.visible = v
	if not v:
		return
	_shop_curses = false
	_shop_title.text = "ARMORY"
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
	_shop_title.text = "CURSES"
	_shop_sub.text = "%s\n%s" % [info, goal]
	_armory_tabs.visible = false
	_armory_coins.get_parent().visible = false
	for c in _armory_rows.get_children():
		c.queue_free()
	for r: Dictionary in rows:
		_armory_rows.add_child(_curse_row(r))


## "Playing as the Mage  ·  Mastery 4" (in gold once they're a Master, at level 10).
func set_title_hero(hero_name: String, mastery := 0, master := false) -> void:
	_title_hero.text = hero_name.to_upper() + ("  ·  MASTERY %d" % mastery if mastery > 1 else "")
	_title_hero.label_settings.font_color = GOLD if master else Color(0.75, 0.85, 1.0)


## Shows the rows of the open tab: Armory upgrades, or the Vault's blessings.
func _fill_shop(rows: Array, coins: int) -> void:
	_shop_rows = rows
	_shop_coins = coins
	var vault := _armory_tab == "vault"
	_shop_sub.text = "New blessings. Buy one once and it can\nturn up in all your runs." if vault else "Upgrades bought here last forever."
	_armory_tabs.visible = true
	for id: String in _tab_buttons:
		paint(_tab_buttons[id], "gold" if id == _armory_tab else "slate")
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
		var done: String = r.get("done", "IN RUNS" if not blessing.is_empty() else ("OWNED" if r.max <= 1 else "MAX"))
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
	if v:
		_hide_phase()
	_end_offer.visible = v and offer
	_end_loop.visible = false
	if not v:
		_drops.visible = false   # (never left over a run that's starting)
		if _pass_card.visible:
			show_pass_card(false)
		return
	_end_score.visible = score >= 0
	_end_best.visible = score >= 0
	_end_target = maxi(score, 0)
	_end_best_value = best
	_end_count = 0.0 if score >= 0 else -1.0
	_end_score.text = "SCORE  0"
	_end_best.text = ""
	_set_end_tap(tap_text)
	_copy_button.text = "COPY REPORT"
	# A tool for balancing the game, only for players who chose to send reports.
	_copy_button.visible = _reports_on
	_end_tap.visible = not buttons and not offer
	_end_buttons.visible = buttons
	if v and buttons:
		refresh_looks_badge.call_deferred()   # (after the run's mastery is saved)
	_end_title_button.visible = false
	_end_pass.visible = false
	if _pass_card.visible:
		show_pass_card(false)
	_share_button.visible = false
	_share_card.visible = false
	_end_spacer.custom_minimum_size.y = 100.0 if not buttons else 24.0
	_end_title.text = "VICTORY" if victory else "YOU DIED"
	_end_title.label_settings.font_color = Color(1, 0.85, 0.4) if victory else Color(0.9, 0.2, 0.2)
	_start_tally(stats, score >= 0)
	_end_goal.visible = false
	_end_mastery.visible = false
	_end_looks.visible = false
	_fit_end_soon()


## The end screen's "tap anywhere" line. Going deeper after a win is the main way on, so it
## looks like a bright button (DESCEND TO FLOOR 3) instead of a faint line; any tap still works.
func _set_end_tap(tap_text: String) -> void:
	var deeper := tap_text.begins_with("Tap to descend")
	_end_tap.text = tap_text.replace("Tap to descend", "DESCEND").to_upper() if deeper else tap_text
	(_end_tap as Pulse).low = 0.85 if deeper else 0.1
	_end_tap.label_settings.font_size = 30
	_end_tap.autowrap_mode = TextServer.AUTOWRAP_OFF if deeper else TextServer.AUTOWRAP_WORD_SMART
	_end_tap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if deeper else Control.SIZE_FILL
	if deeper:
		var sb := StyleBoxFlat.new()   # the chunky green "go" look of the buttons (paint)
		sb.bg_color = ROLES.green[0]
		sb.border_color = ROLES.green[1]
		sb.set_corner_radius_all(18)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 9
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(0, 4)
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		_end_tap.add_theme_stylebox_override("normal", sb)
	else:
		_end_tap.remove_theme_stylebox_override("normal")


## The end screen's Hero Mastery bar, filling with this run's points (`info` from
## Game._bank_mastery; {} hides it).
func show_mastery(info: Dictionary) -> void:
	_end_mastery.visible = not info.is_empty() and _end_box.visible
	if _end_mastery.visible:
		_end_mastery.play(info)
	# A level reached this run: a button that shows the hero wearing what it unlocked.
	_end_looks_for = {}
	if _end_mastery.visible:
		for l: Dictionary in info.get("levels", []):
			var n := HeroStyle.level_items(str(info.id), int(l.level)).size()
			if n > 0:
				_end_looks_for = {"id": info.id, "level": int(l.level), "n": n}
	_end_looks.visible = not _end_looks_for.is_empty()
	if _end_looks.visible:
		var n := int(_end_looks_for.n)
		_end_looks.text = "SEE %d NEW LOOK%s" % [n, "" if n == 1 else "S"]
	_fit_end_soon()


## The Mastery screen for hero `id` (mastery_screen.gd), filled from `cfg`.
func open_mastery(cfg: ConfigFile, id: String) -> void:
	_mastery.open_hero(cfg, id)


## The Feats screen (feats_screen.gd), over the Style screen.
## The big reveal for Feats won this run (drop_screen.gd reveal_feats).
func reveal_feats(list: Array) -> void:
	_drops.reveal_feats(list)


func open_feats(cfg: ConfigFile, id: String) -> void:
	_feats.open_screen(cfg, id)


## True while a full-screen, opaque menu covers the dungeon (Style, Feats, Mastery, Bone
## Drops, Heroes): the game then stops drawing the 3D world behind it (battery and heat).
func covers_world() -> bool:
	return _style.visible or _feats.visible or _mastery.visible or _drops.visible or _heroes_box.visible \
			or (_rewards_box != null and _rewards_box.visible) or _armory_box.visible or _records_box.visible \
			or _pass_box.visible


func feats_visible() -> bool:
	return _feats.visible


func close_feats() -> void:
	_feats.close()


## The hero the Style screen is open for ("" when it's closed).
func style_hero() -> String:
	return _style.hero_id() if _style.visible else ""


## A Feat just done: a gold and cyan card drops in at the top, names it and the look it won,
## and goes after a few seconds (it never stops play).
## Feats done close together (a boss kill can finish four at once) wait their turn: one
## toast and one sound each, about 2.5 seconds apart.
var _toast_queue: Array = []
var _toast_busy := false


func feat_toast(feat_name: String, look: String) -> void:
	_toast_queue.append([feat_name, look])
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	# Version 121: in a fight the toast waits for the room to be cleared (the Feat is only
	# saved then anyway), so it never covers the boss or the hero mid-dodge.
	while Game.state in [Game.State.PLAYING, Game.State.PAUSED] and Game.alive_enemies > 0:
		await get_tree().create_timer(0.3, false).timeout
	var item: Array = _toast_queue.pop_front()
	_show_toast(str(item[0]), str(item[1]))
	Sfx.play("victory", 0.6, 1.2)


func _show_toast(feat_name: String, look: String) -> void:
	if _toast == null:
		_toast = PanelContainer.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.12, 0.16, 0.94)
		sb.border_color = Color(0.5, 0.95, 1.0)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 8
		sb.content_margin_bottom = 10
		sb.shadow_color = Color(0.3, 0.9, 1.0, 0.35)
		sb.shadow_size = 12
		_toast.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		_toast.add_child(v)
		v.add_child(label("FEAT DONE!", 18, Color(0.5, 0.95, 1.0)))
		_toast_name = label("", 32, GOLD)
		v.add_child(_toast_name)
		_toast_look = label("", 19, Color(0.9, 0.95, 1.0))
		v.add_child(_toast_look)
		# One line each (wrapping labels have no width of their own and would stretch it).
		for l: Label in v.get_children():
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
		_toast.custom_minimum_size = Vector2(400, 0)
		add_child(_toast)
	_toast_name.text = feat_name
	_toast_look.text = "New look: " + look
	var vw := get_viewport().get_visible_rect().size.x
	_toast.custom_minimum_size.x = minf(400.0, vw - 32.0)
	_toast.size = Vector2.ZERO
	_toast.reset_size()
	# Version 121: it slides down from the top edge to just under the corner buttons (title)
	# or the room name and boss bar (a run), never over the hero's face.
	var top := float(_safe.get_theme_constant("margin_top")) if _safe else 0.0
	var y := top + (96.0 if Game.state == Game.State.TITLE else 150.0)
	_toast.position = Vector2((vw - _toast.size.x) * 0.5, -_toast.size.y - 8.0)
	_toast.pivot_offset = _toast.size * 0.5
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.scale = Vector2.ONE
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween().set_ignore_time_scale(true)
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.parallel().tween_property(_toast, "position:y", y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(2.4 if _toast_queue.is_empty() else 1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func():
		_toast.visible = false
		_next_toast())


func close_mastery() -> void:
	_mastery.visible = false


## The Style screen for hero `id` (style_screen.gd). The Heroes screen's pedestal stops
## drawing underneath it.
func open_style(cfg: ConfigFile, id: String) -> void:
	if _heroes_box.visible:
		_heroes_box._stage.set_active(false)
	_style.open_hero(cfg, id)
	refresh_looks_badge()


func style_show_new(lv: int) -> void:
	_style.show_new(lv)


func style_note(text: String) -> void:
	_style.set_note(text)


func close_style() -> void:
	_style.close()


func style_visible() -> bool:
	return _style.visible


func mastery_visible() -> bool:
	return _mastery.visible


## The gold line under the end screen's stats (hidden when empty).
func set_end_goal(text: String) -> void:
	_end_goal.text = text
	_end_goal.visible = text != "" and _end_box.visible
	_fit_end_soon()


## Fits now and again two frames later: a wrapping label that was hidden has no width when it
## first shows and measures one word per line, which shrank the whole end screen for a frame or more.
func _fit_end_soon() -> void:
	_fit_end.call_deferred()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		_fit_end()


## Short screens (16:9 phones, tablets): the end screen tightens its gaps and, if it still
## doesn't fit, shrinks as a whole so the last button stays on screen.
func _fit_end() -> void:
	if not _end_box.visible:
		return
	# Fill the box again first. Moving the column (below) fixes its size at whatever it was
	# then, so after one tall end screen the next ones stayed stretched past the bottom and
	# their buttons were centred off the screen.
	_end_col.scale = Vector2.ONE
	_end_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shown := 0
	for c in _end_col.get_children():
		if (c as Control).visible:
			shown += 1
	var room := _end_box.size.y - 32.0
	var need := _end_col.get_combined_minimum_size().y - float(_end_col.get_theme_constant("separation")) * (shown - 1)
	var gap := 24.0 if need + 24.0 * (shown - 1) <= room else 10.0
	_end_col.add_theme_constant_override("separation", int(gap))
	need += gap * (shown - 1)
	var k := minf(1.0, room / maxf(need, 1.0))
	_end_col.pivot_offset = Vector2(_end_box.size.x * 0.5, 0.0)
	_end_col.scale = Vector2(k, k)
	_end_col.position.y = 16.0 if k < 1.0 else 0.0


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
		if _tally_wait:
			_tally_wait = false
			_tally_i = 0
			_tally_t = 0.0
		if _end_target > _end_best_value and _end_target > 0:
			_end_best.text = "NEW BEST!"
			_end_best.label_settings.font_color = Color(1, 0.8, 0.3)
			Sfx.play("upgrade", 0.6)
		else:
			_end_best.text = "Best  " + thousands(_end_best_value)
			_end_best.label_settings.font_color = Color(0.8, 0.78, 0.7)
		_fit_end.call_deferred()   # the best line has words in it now


func _start_tally(stats: String, after_score: bool) -> void:
	_tally = stats.split("\n")
	_tally_wait = after_score
	_tally_i = -1 if after_score else 0
	_tally_t = 0.0
	_end_stats.text = _tally_text(-1, 0.0)


## A line like "Coins this run  45" or "Bone Road  +12 bones" counts up; text lines (and
## times, like "1:23") just appear.
static func _tally_number(line: String) -> RegExMatch:
	# The first gap, not the last (version 123): "Coins kept  45  (+50 first run today)"
	# counted the 50 and left the 45 still.
	var cut := line.find("  ")
	if cut < 0 or line.substr(cut).contains(":"):
		return null
	var re := RegEx.create_from_string("\\d[\\d,]*")
	return re.search(line, cut)


## The stats with lines before `upto` in full, line `upto` counted `k` (0..1) of the way,
## and the rest blank (they keep their space, so nothing below jumps).
func _tally_text(upto: int, k: float) -> String:
	var out := []
	for i in _tally.size():
		var line: String = _tally[i]
		if i < upto or upto >= _tally.size():
			out.append(line)
		elif i == upto:
			var m := _tally_number(line)
			if m == null:
				out.append(line)
			else:
				var full := int(m.get_string().replace(",", ""))
				var n := roundi(full * ease(k, 0.5))
				out.append(line.substr(0, m.get_start()) + (thousands(n) if m.get_string().contains(",") else str(n)) + line.substr(m.get_end()))
		else:
			out.append("")
	return "\n".join(out)


func _update_tally(delta: float) -> void:
	if _tally_i < 0 or not _end_box.visible:
		return
	while _tally_i < _tally.size() and _tally[_tally_i].strip_edges() == "":
		_tally_i += 1   # blank lines take no time
	if _tally_i >= _tally.size():
		_end_stats.text = "\n".join(_tally)
		_tally_i = -1
		_fit_end.call_deferred()   # a long line that wraps once shown can make it taller
		return
	var counts := _tally_number(_tally[_tally_i]) != null
	var dur := 0.5 if counts else 0.12
	var was := _tally_t
	_tally_t += delta
	if counts and int(was * 16.0) != int(_tally_t * 16.0) and _tally_t < dur:
		Sfx.play("tick", 0.35, 1.0 + _tally_t)
	if _tally_t >= dur:
		_end_stats.text = _tally_text(_tally_i + 1, 0.0)
		if counts:
			Sfx.play("coin", 0.5, 1.25)
			if Game.vibration:
				Input.vibrate_handheld(15)
		_tally_i += 1
		_tally_t = 0.0
	else:
		_end_stats.text = _tally_text(_tally_i, _tally_t / dur)


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
	_fit_end_soon()


## A CRYPT PASS button among the death-screen buttons (after a deep death, once a session).
func show_end_pass(v: bool) -> void:
	_end_pass.visible = v
	_fit_end_soon()


## The end of a loop: DESCEND DEEPER into `next_loop`, or BANK AND LEAVE with `bonus` coins.
## The TITLE button under the end screen's other buttons.
func show_end_title(v: bool, text := "TITLE") -> void:
	_end_title_btn.text = text
	_end_title_button.visible = v and _end_box.visible
	_fit_end_soon()


func end_visible() -> bool:
	return _end_box.visible


func show_end_loop(v: bool, bonus := 0, next_loop := 2) -> void:
	_end_loop.visible = v
	if not v:
		return
	_end_title_button.visible = false
	_end_offer.visible = false
	_end_tap.visible = false
	_end_spacer.custom_minimum_size.y = 24.0
	_loop_deeper_button.text = "DESCEND INTO LOOP %d" % next_loop
	_loop_bank_button.text = "BANK AND LEAVE  (+%d coins)" % bonus
	_fit_end_soon()


## Replaces the end screen's middle text (after buying the Pass at the free end).
func set_end_stats(text: String) -> void:
	_tally_i = -1
	_tally_wait = false
	_end_stats.text = text
	_fit_end_soon()


## The Pass was bought on the end screen: carry on deeper instead.
func end_offer_done(tap_text: String) -> void:
	_end_offer.visible = false
	_set_end_tap(tap_text)
	_end_tap.visible = true
	_fit_end_soon()


func show_pause(v: bool, settings_only := false) -> void:
	if v:
		_hide_phase()
	_settings_only = v and settings_only
	_pause_title.text = "SETTINGS" if _settings_only else "PAUSED"
	_resume_button.text = "BACK" if _settings_only else "RESUME"
	_quit_button.visible = not _settings_only
	# Darker over the busy title screen than over a paused room.
	(_pause_box as ColorRect).color.a = 0.9 if _settings_only else 0.7
	_pause_box.visible = v
	if v:
		_pause_build.text = "Build %s  ·  Install %s" % [Game.BUILD, Telemetry.install_id(Game._load_save())]
	if _quit_armed:
		_disarm_quit()


## The pause menu's settings, from the SETTINGS button on the title screen.
func show_settings(v: bool) -> void:
	show_pause(v, true)


func settings_visible() -> bool:
	return _settings_only and _pause_box.visible


func set_fade(a: float) -> void:
	_fade.color.a = a
