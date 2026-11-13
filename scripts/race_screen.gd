class_name RaceScreen
extends ColorRect
## The Crypt Race's screens (race.gd, version 153), one page at a time on a teal-lit crypt
## wall: the LOBBY (league badge, trophies, the next Race Road step, the day's first-win
## drop, RACE!), the rival SEARCH, the VS card (you and the rival, marked BOT, and the Race
## Kit), the RESULT (win or loss, trophies counting up or down, the league bar, coins and
## the drop) and the RACE ROAD (every step and its CLAIM button).
## Bar (at the bottom) is the race track on the left of the screen during a race.

signal race_pressed
signal go
signal again
signal claim(index: int)
signal closed
signal to_title

const TEAL := Color(0.3, 0.9, 1.0)
const YOU := Color(1.0, 0.8, 0.3)
const RIVAL := Color(1.0, 0.38, 0.32)
const TEXT := Color(0.9, 0.9, 0.95)
const DIM := Color(0.62, 0.62, 0.72)
const DONE := Color(0.45, 0.85, 0.5)
## The head in the hero pictures (art/ui/heroes), as a share of the picture.
const HEAD := Rect2(0.24, 0.06, 0.5, 0.5)

var _lobby: Control
var _search: Control
var _vs: Control
var _result: Control
var _road: Control
var _back: Button

# lobby
var _badge: Badge
var _l_league: Label
var _l_trophies: Label
var _l_bar: Meter
var _l_next: Label
var _l_road_btn: Button
var _l_road_pill: Label
var _l_road_line: Label
var _l_daily: Label
var _l_stats: Label
var _l_win: Label
var _l_note: Label
# search
var _spinner: Spinner
var _s_text: Label
var _s_t := 0.0
var _s_wait := 0.0
var _match: Race.Match
# vs
var _vs_me: Control
var _vs_them: Control
var _vs_kit: Label
var _vs_count: Label
var _vs_t := -1.0
# result
var _r_title: Label
var _r_sub: Label
var _r_badge: Badge
var _r_trophies: Label
var _r_delta: Label
var _r_bar: Meter
var _r_league: Label
var _r_rewards: Label
var _r_stats: Label
var _r_road: Button
var _r_buttons: Control
var _r_order: PanelContainer
var _shown_t := 0.0
# road
var _road_count: Label
var _road_sub: Label
var _road_scroll: ScrollContainer
var _road_list: VBoxContainer
var _road_from_result := false


func _init() -> void:
	color = Color(0.02, 0.04, 0.06, 0.97)
	Hud.backdrop(self, "teal")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS   # the result shows over a paused game
	visible = false
	_build_lobby()
	_build_search()
	_build_vs()
	_build_result()
	_build_road()
	_back = Hud.back_corner(Hud.button("BACK", 24))
	_back.pressed.connect(_on_back)
	add_child(_back)


func _page() -> VBoxContainer:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hud.full(holder)
	holder.visible = false
	add_child(holder)
	var col := VBoxContainer.new()
	Hud.full(col)
	col.offset_left = 22
	col.offset_right = -22
	col.offset_top = 30
	col.offset_bottom = -110
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	holder.add_child(col)
	visibility_changed.connect(func(): if visible: Hud.safe_pad(col))
	return col


func _show_page(p: Control, back := true) -> void:
	for c in [_lobby, _search, _vs, _result, _road]:
		c.visible = c == p
	_back.visible = back
	visible = true
	_shown_t = 0.0


static func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func _center(c: Control) -> Control:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return box


static func _panel(col: Color, bg := Color(0.05, 0.08, 0.12, 0.92)) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _pill(text: String, col: Color, size := 16) -> Label:
	var l := Hud.label(text, size, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.35)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l


# ---------------------------------------------------------------- lobby

func _build_lobby() -> void:
	var col := _page()
	_lobby = col.get_parent()
	col.add_child(Hud.label("CRYPT RACE", 46, TEAL.lightened(0.3)))
	col.add_child(Hud.label("Race a rival through the same crypt.\nFirst to fell the boss wins!", 18, TEXT))
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	_badge = Badge.new()
	_badge.custom_minimum_size = Vector2(120, 132)
	top.add_child(_badge)
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size = Vector2(250, 0)
	right.add_theme_constant_override("separation", 2)
	top.add_child(right)
	_l_league = Hud.label("", 30, YOU, HORIZONTAL_ALIGNMENT_LEFT)
	_l_league.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.add_child(_l_league)
	var trow := HBoxContainer.new()
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_theme_constant_override("separation", 6)
	right.add_child(trow)
	var cup := TrophyIcon.new()
	cup.custom_minimum_size = Vector2(34, 36)
	trow.add_child(cup)
	_l_trophies = Hud.label("", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_l_trophies.autowrap_mode = TextServer.AUTOWRAP_OFF
	trow.add_child(_l_trophies)
	_l_bar = Meter.new()
	_l_bar.custom_minimum_size = Vector2(240, 22)
	right.add_child(_l_bar)
	_l_next = Hud.label("", 16, DIM, HORIZONTAL_ALIGNMENT_LEFT)
	right.add_child(_l_next)
	# The race button: big, gold, with what a win is worth under it.
	var race := Hud.button("RACE!", 34, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	race.custom_minimum_size = Vector2(320, 96)
	race.pressed.connect(func():
		Sfx.play("click")
		race_pressed.emit())
	col.add_child(_center(race))
	_l_win = Hud.label("", 17, YOU)
	col.add_child(_l_win)
	_l_daily = Hud.label("", 17, TEXT)
	col.add_child(_l_daily)
	# The Race Road: the next step, and a button to the whole road.
	var road := _panel(TEAL.darkened(0.2))
	col.add_child(road)
	var rh := HBoxContainer.new()
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rh.add_theme_constant_override("separation", 10)
	road.add_child(rh)
	var rt := VBoxContainer.new()
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_constant_override("separation", 0)
	rh.add_child(rt)
	var rtitle := Hud.label("RACE ROAD", 22, TEAL.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT)
	rt.add_child(rtitle)
	_l_road_line = Hud.label("", 16, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	rt.add_child(_l_road_line)
	_l_road_btn = Hud.button("ROAD", 20)
	_l_road_btn.custom_minimum_size = Vector2(124, 64)
	_l_road_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_l_road_btn.pressed.connect(func():
		Sfx.play("click")
		_road_from_result = false
		open_road(Game._load_save()))
	rh.add_child(_l_road_btn)
	_l_road_pill = _pill("CLAIM!", Hud.GOLD, 16)
	_l_road_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_l_road_pill.offset_left = -70
	_l_road_pill.offset_top = -12
	_l_road_pill.offset_right = 8
	_l_road_btn.add_child(_l_road_pill)
	# How it works, in three lines.
	var how := _panel(Color(0.3, 0.32, 0.42))
	col.add_child(how)
	var hv := VBoxContainer.new()
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_theme_constant_override("separation", 3)
	how.add_child(hv)
	for line: String in ["Same rooms, same cards, same Race Kit. No Armory: skill wins.",
			"Kills fill your SURGE. A full one stuns your rival.",
			"Fall and you get back up. Keep going!"]:
		hv.add_child(Hud.label("•  " + line, 16, TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_l_stats = Hud.label("", 16, DIM)
	col.add_child(_l_stats)
	col.add_child(Hud.label("Rivals are bots for now (marked BOT). Online races come next.", 16, DIM))
	_l_note = Hud.label("", 17, RIVAL)
	col.add_child(_l_note)


func open_lobby(cfg: ConfigFile, note := "") -> void:
	_show_page(_lobby)
	_l_note.text = note
	_l_note.visible = note != ""
	var t := Race.trophies(cfg)
	var li := Race.league_index(t)
	_badge.league = li
	_badge.queue_redraw()
	_l_league.text = "%s LEAGUE" % str(Race.LEAGUES[li].name)
	_l_league.label_settings.font_color = Race.LEAGUES[li].col
	_l_trophies.text = Hud.thousands(t)
	_l_bar.frac = Race.league_progress(t)
	_l_bar.col = Race.LEAGUES[mini(li + 1, Race.LEAGUES.size() - 1)].col
	_l_bar.queue_redraw()
	_l_next.text = Race.next_league_text(t)
	var streak := Race.stat(cfg, "streak")
	_l_win.text = "Win: +%d trophies%s" % [Race.win_trophies(cfg), "  ·  %d wins in a row!" % streak if streak >= 2 else ""]
	_l_daily.text = "First win today: +1 Bone Drop" if Race.first_win_ready(cfg) else "Today's first-win Bone Drop: won ✓  (more tomorrow)"
	_l_daily.label_settings.font_color = YOU if Race.first_win_ready(cfg) else DIM
	var ready := Race.road_ready(cfg)
	var ni := Race.road_next(cfg)
	_l_road_pill.visible = ready > 0
	if ready > 0:
		_l_road_line.text = "%d reward%s ready to claim!" % [ready, "" if ready == 1 else "s"]
	elif ni < Race.ROAD.size():
		_l_road_line.text = "Next at %d trophies: %s" % [int(Race.ROAD[ni].at), Race.road_text(Race.ROAD[ni])]
	else:
		_l_road_line.text = "Every step claimed. Champion!"
	var races := Race.stat(cfg, "races")
	_l_stats.text = "Races %d  ·  Wins %d  ·  Best %d trophies" % [races, Race.stat(cfg, "wins"), Race.best(cfg)] if races > 0 else "Your first race is waiting!"


# ---------------------------------------------------------------- search and VS

func _build_search() -> void:
	var col := _page()
	_search = col.get_parent()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(Hud.label("CRYPT RACE", 40, TEAL.lightened(0.3)))
	_spinner = Spinner.new()
	_spinner.custom_minimum_size = Vector2(170, 170)
	col.add_child(_center(_spinner))
	_s_text = Hud.label("Finding a rival...", 26, TEXT)
	col.add_child(_s_text)
	col.add_child(Hud.label("Offline for now: your rival is a bot.", 16, DIM))


## Shows the search for a moment, then the VS card for match `m`.
func start_search(m: Race.Match) -> void:
	_match = m
	_show_page(_search)
	_s_t = 0.0
	_s_wait = randf_range(1.3, 2.0)
	_s_text.text = "Finding a rival..."


func _build_vs() -> void:
	var col := _page()
	_vs = col.get_parent()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.add_child(Hud.label("RIVAL FOUND!", 38, TEAL.lightened(0.3)))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	_vs_me = Control.new()
	_vs_me.custom_minimum_size = Vector2(212, 330)
	_vs_me.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_vs_me)
	var vs := Hud.label("VS", 44, Color.WHITE)
	vs.custom_minimum_size = Vector2(70, 0)
	row.add_child(vs)
	_vs_them = Control.new()
	_vs_them.custom_minimum_size = Vector2(212, 330)
	_vs_them.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_vs_them)
	var kit := _panel(TEAL.darkened(0.15))
	col.add_child(kit)
	var kv := VBoxContainer.new()
	kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kv.add_theme_constant_override("separation", 2)
	kit.add_child(kv)
	kv.add_child(Hud.label("RACE KIT  ·  both racers start with", 16, DIM))
	_vs_kit = Hud.label("", 22, TEAL.lightened(0.35))
	kv.add_child(_vs_kit)
	kv.add_child(Hud.label("4 rooms, then the Skeleton King. No Armory.", 16, TEXT))
	_vs_count = Hud.label("", 30, YOU)
	col.add_child(_vs_count)


func _racer_card(holder: Control, title: String, sub: String, hero_id: String, trophies: int, col: Color, bot := "") -> void:
	for c in holder.get_children():
		c.queue_free()
	var p := _panel(col, Color(0.05, 0.07, 0.11, 0.95))
	Hud.full(p)
	holder.add_child(p)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var pic := TextureRect.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.custom_minimum_size = Vector2(0, 178)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://art/ui/heroes/%s.png" % hero_id
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	v.add_child(pic)
	var name_l := Hud.label(title, 24 if title.length() <= 12 else 19, col.lightened(0.2))
	v.add_child(name_l)
	v.add_child(Hud.label(sub, 16, TEXT))
	var tr := HBoxContainer.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.alignment = BoxContainer.ALIGNMENT_CENTER
	tr.add_theme_constant_override("separation", 4)
	v.add_child(tr)
	var cup := TrophyIcon.new()
	cup.custom_minimum_size = Vector2(22, 24)
	tr.add_child(cup)
	var tl := Hud.label("%d" % trophies, 20, Color.WHITE)
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tr.add_child(tl)
	if bot != "":
		v.add_child(_center(_pill(bot, Color(0.45, 0.47, 0.6))))


func _show_vs() -> void:
	var m := _match
	_show_page(_vs, false)
	Sfx.play("door", 0.8)
	var mine := Heroes.get_hero(m.hero_id)
	_racer_card(_vs_me, "YOU", Heroes.full_name(mine), m.hero_id, m.trophies, YOU)
	var theirs := Heroes.get_hero(m.rival.hero_id)
	_racer_card(_vs_them, m.rival.name, str(theirs.title), m.rival.hero_id, m.rival.trophies, RIVAL,
		"BOT  ·  " + str(Race.SKILLS[m.rival.skill].name))
	_vs_kit.text = Race.kit_text(m.kit)
	_vs_t = 0.0
	_vs_count.text = "GET READY!"


# ---------------------------------------------------------------- result

func _build_result() -> void:
	var col := _page()
	_result = col.get_parent()
	col.add_theme_constant_override("separation", 8)
	_r_title = Hud.label("", 56, YOU)
	col.add_child(_r_title)
	_r_sub = Hud.label("", 19, TEXT)
	col.add_child(_r_sub)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	_r_badge = Badge.new()
	_r_badge.custom_minimum_size = Vector2(110, 120)
	top.add_child(_r_badge)
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size = Vector2(250, 0)
	top.add_child(right)
	_r_league = Hud.label("", 24, YOU, HORIZONTAL_ALIGNMENT_LEFT)
	_r_league.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.add_child(_r_league)
	var trow := HBoxContainer.new()
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trow.add_theme_constant_override("separation", 6)
	right.add_child(trow)
	var cup := TrophyIcon.new()
	cup.custom_minimum_size = Vector2(34, 36)
	trow.add_child(cup)
	_r_trophies = Hud.label("", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	_r_trophies.autowrap_mode = TextServer.AUTOWRAP_OFF
	trow.add_child(_r_trophies)
	_r_delta = Hud.label("", 28, DONE, HORIZONTAL_ALIGNMENT_LEFT)
	_r_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	trow.add_child(_r_delta)
	_r_bar = Meter.new()
	_r_bar.custom_minimum_size = Vector2(240, 22)
	right.add_child(_r_bar)
	var rew := _panel(Hud.GOLD.darkened(0.3))
	col.add_child(rew)
	_r_rewards = Hud.label("", 20, TEXT)
	rew.add_child(_r_rewards)
	_r_stats = Hud.label("", 16, DIM)
	col.add_child(_r_stats)
	_r_order = _panel(Color(0.3, 0.32, 0.42))
	col.add_child(_r_order)
	_r_buttons = VBoxContainer.new()
	_r_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_r_buttons as VBoxContainer).add_theme_constant_override("separation", 10)
	col.add_child(_r_buttons)
	var again_b := Hud.button("RACE AGAIN", 30, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	again_b.custom_minimum_size = Vector2(330, 88)
	again_b.pressed.connect(func():
		if _shown_t < 0.6:
			return
		Sfx.play("click")
		again.emit())
	_r_buttons.add_child(_center(again_b))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_r_buttons.add_child(row)
	_r_road = Hud.button("RACE ROAD", 22)
	_r_road.custom_minimum_size = Vector2(200, 70)
	_r_road.pressed.connect(func():
		if _shown_t < 0.6:
			return
		Sfx.play("click")
		_road_from_result = true
		open_road(Game._load_save()))
	row.add_child(_r_road)
	var title_b := Hud.button("TITLE", 22)
	title_b.custom_minimum_size = Vector2(150, 70)
	title_b.pressed.connect(func():
		if _shown_t < 0.6:
			return
		Sfx.play("click")
		to_title.emit())
	row.add_child(title_b)


## The race's result. `res` comes from Race.record, with the race's own numbers added.
func show_result(res: Dictionary, m: Race.Match) -> void:
	_show_page(_result, false)
	_r_buttons.modulate.a = 0.0
	var won := bool(res.won)
	_r_title.text = "VICTORY!" if won else "DEFEAT"
	_r_title.label_settings.font_color = YOU if won else RIVAL
	_r_title.pivot_offset = Vector2(size.x * 0.5 - 22, 34)
	_r_title.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(_r_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_r_sub.text = str(res.get("line", ""))
	var before := int(res.before)
	var after := int(res.after)
	_r_trophies.text = Hud.thousands(before)
	var d := int(res.delta)
	_r_delta.text = ("+%d" % d) if d > 0 else ("%d" % d if d < 0 else "±0")
	_r_delta.label_settings.font_color = DONE if d > 0 else (RIVAL if d < 0 else DIM)
	_r_delta.modulate.a = 0.0
	var li := Race.league_index(before)
	_r_badge.league = li
	_r_badge.queue_redraw()
	_r_league.text = "%s LEAGUE" % str(Race.LEAGUES[li].name)
	_r_league.label_settings.font_color = Race.LEAGUES[li].col
	_r_bar.frac = Race.league_progress(before)
	_r_bar.col = Race.LEAGUES[mini(li + 1, Race.LEAGUES.size() - 1)].col
	_r_bar.queue_redraw()
	var lines := ["+%d coins" % int(res.coins)]
	if int(res.get("streak_bonus", 0)) > 0:
		lines.append("Win streak: +%d trophies" % int(res.streak_bonus))
	if bool(res.drop):
		lines.append("+1 Bone Drop  (first win today)")
	if bool(res.get("road_new", false)):
		lines.append("New Race Road reward to claim!")
	if not won and d == 0 and before < Race.SAFE_UNDER:
		lines.append("No trophies lost while you learn (under %d)" % Race.SAFE_UNDER)
	_r_rewards.text = "\n".join(lines)
	_r_stats.text = "Time %s  ·  Surges sent %d, got %d  ·  Falls %d" % [_clock(m.t), m.sent, m.got, m.falls]
	_fill_order(won, m)
	_r_road.text = "ROAD: CLAIM!" if Race.road_ready(Game._load_save()) > 0 else "RACE ROAD"
	# The trophies count to their new number, then the league bar fills (or empties).
	var tw2 := create_tween()
	tw2.tween_interval(0.5)
	tw2.tween_property(_r_delta, "modulate:a", 1.0, 0.2)
	tw2.tween_method(func(v: float):
		var n := roundi(v)
		_r_trophies.text = Hud.thousands(n)
		var lj := Race.league_index(n)
		_r_bar.frac = Race.league_progress(n)
		_r_bar.col = Race.LEAGUES[mini(lj + 1, Race.LEAGUES.size() - 1)].col
		_r_bar.queue_redraw()
		if lj != _r_badge.league:
			_r_badge.league = lj
			_r_badge.pop = 1.0
			_r_badge.queue_redraw()
			_r_league.text = "%s LEAGUE" % str(Race.LEAGUES[lj].name)
			_r_league.label_settings.font_color = Race.LEAGUES[lj].col
			Sfx.play("victory", 0.8)
		, float(before), float(after), 0.9 if before != after else 0.01)
	tw2.tween_callback(func():
		if d != 0:
			Sfx.play("coin" if d > 0 else "click", 0.8))
	tw2.tween_property(_r_buttons, "modulate:a", 1.0, 0.25)
	if bool(res.league_up):
		tw2.tween_callback(func(): Game.hud.callout("%s LEAGUE!" % str(Race.league(after).name), Race.league(after).col))


## The finish: who crossed the line, and where the other one was.
func _fill_order(won: bool, m: Race.Match) -> void:
	for c in _r_order.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	_r_order.add_child(v)
	var me_line := "Crossed the line  ·  %s" % _clock(m.t) if won else _where(m.me())
	var them_line := "Crossed the line  ·  %s" % _clock(m.t) if not won else _where(m.them())
	var rows := [["YOU", m.hero_id, me_line, YOU], [m.rival.name, m.rival.hero_id, them_line, RIVAL]]
	if not won:
		rows.reverse()
	for i in rows.size():
		var r: Array = rows[i]
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		var place := Hud.label("%d" % (i + 1), 30, Hud.GOLD if i == 0 else DIM)
		place.custom_minimum_size = Vector2(30, 0)
		h.add_child(place)
		var face := Face.new()
		face.custom_minimum_size = Vector2(52, 52)
		face.ring = r[3]
		face.set_hero(str(r[1]))
		h.add_child(face)
		var t := VBoxContainer.new()
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_theme_constant_override("separation", 0)
		h.add_child(t)
		var n := Hud.label(str(r[0]) + ("" if i == 0 or r[0] == "YOU" else ""), 20, Color(r[3]).lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT)
		t.add_child(n)
		t.add_child(Hud.label(str(r[2]), 16, TEXT if i == 0 else DIM, HORIZONTAL_ALIGNMENT_LEFT))
		if r[0] != "YOU":
			h.add_child(_pill("BOT", Color(0.45, 0.47, 0.6), 16))


static func _where(p: float) -> String:
	var leg := mini(int(p), Race.LEGS - 1)
	if leg >= Race.LEGS - 1:
		return "Fighting the boss  ·  %d%% done" % roundi((p - leg) * 100.0)
	return "In room %d of %d" % [leg + 1, Race.LEGS - 1]


static func _clock(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# ---------------------------------------------------------------- the Race Road

func _build_road() -> void:
	var col := _page()
	_road = col.get_parent()
	col.add_child(Hud.label("RACE ROAD", 44, TEAL.lightened(0.3)))
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	var cup := TrophyIcon.new()
	cup.custom_minimum_size = Vector2(30, 32)
	top.add_child(cup)
	_road_count = Hud.label("", 28, Color.WHITE)
	_road_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_road_count)
	_road_sub = Hud.label("", 16, TEXT)
	col.add_child(_road_sub)
	_road_scroll = ScrollContainer.new()
	_road_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_road_scroll)
	_road_list = VBoxContainer.new()
	_road_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_road_list.add_theme_constant_override("separation", 8)
	_road_scroll.add_child(_road_list)


func open_road(cfg: ConfigFile) -> void:
	var keep := _road.visible
	_show_page(_road)
	for c in _road_list.get_children():
		_road_list.remove_child(c)
		c.queue_free()
	var b := Race.best(cfg)
	_road_count.text = "Best %s" % Hud.thousands(b)
	var ready := Race.road_ready(cfg)
	_road_sub.text = ("%d reward%s ready to claim!" % [ready, "" if ready == 1 else "s"]) if ready > 0 \
		else "Steps open with your best trophies, and stay open\nif you drop. Six looks are found only here."
	var focus: Control = null
	var ni := Race.road_next(cfg)
	for i in Race.ROAD.size():
		var row := _road_row(cfg, i, b)
		_road_list.add_child(row)
		if focus == null and (i == ni or (b >= int(Race.ROAD[i].at) and not Race.road_claimed(cfg, i))):
			focus = row
	if focus and not keep:
		_scroll_to(focus)


func _scroll_to(row: Control) -> void:
	for i in 2:
		await get_tree().process_frame
	if is_instance_valid(row) and visible:
		_road_scroll.scroll_vertical = int(maxf(0.0, row.position.y - _road_scroll.size.y * 0.35))


func _road_row(cfg: ConfigFile, i: int, b: int) -> Control:
	var s: Dictionary = Race.ROAD[i]
	var reached := b >= int(s.at)
	var got := Race.road_claimed(cfg, i)
	var look := str(s.kind) == "look"
	var p := _panel(Hud.GOLD if reached and not got else (DONE.darkened(0.3) if got else (TEAL.darkened(0.45) if look else Color(0.28, 0.3, 0.38))),
		Color(0.22, 0.16, 0.05, 0.97) if reached and not got else Color(0.06, 0.08, 0.12, 0.95))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var at := Hud.label(str(int(s.at)), 22, Hud.GOLD if reached else DIM)
	at.custom_minimum_size = Vector2(62, 0)
	at.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(at)
	if look:
		var sw := Swatch.new()
		sw.slot = str(s.slot)
		sw.look = HeroStyle.extra(s.slot, s.key)
		sw.custom_minimum_size = Vector2(54, 54)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	texts.add_child(Hud.label(Race.road_text(s), 20, (TEAL.lightened(0.4) if look else TEXT) if reached or look else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var need := ("Claimed" + ("  ·  wear it in Style" if look else "") if got else "Ready!") if reached else "%d trophies to go" % (int(s.at) - b)
	if look and not reached:
		need += "  ·  race only"
	texts.add_child(Hud.label(need, 16, Hud.GOLD if reached and not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if reached and not got:
		var c := Hud.button("CLAIM", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
		c.custom_minimum_size = Vector2(112, 60)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.pressed.connect(func(): claim.emit(i))
		h.add_child(c)
	else:
		var tag := Hud.label("DONE" if got else "", 16, DONE)
		tag.custom_minimum_size = Vector2(70, 0)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(tag)
	return p


# ---------------------------------------------------------------- flow

func _on_back() -> void:
	Sfx.play("click")
	if _road.visible:
		if _road_from_result:
			_show_page(_result, false)
			_r_buttons.modulate.a = 1.0
			_r_road.text = "ROAD: CLAIM!" if Race.road_ready(Game._load_save()) > 0 else "RACE ROAD"
		else:
			open_lobby(Game._load_save())
		return
	if _search.visible:
		_match = null
		open_lobby(Game._load_save())
		return
	visible = false
	closed.emit()


## Android Back. Returns true if the screen took it.
func back_pressed() -> bool:
	if not visible:
		return false
	if _vs.visible:
		return true   # the race is about to start
	if _result.visible:
		if _shown_t > 0.6:
			to_title.emit()
		return true
	_on_back()
	return true


func close() -> void:
	visible = false
	_match = null
	_vs_t = -1.0


func _process(delta: float) -> void:
	if not visible:
		return
	_shown_t += delta
	if _search.visible and _match:
		_s_t += delta
		if _s_t >= _s_wait:
			_show_vs()
	elif _vs.visible and _vs_t >= 0.0:
		_vs_t += delta
		if _vs_t >= 2.8:
			_vs_t = -1.0
			go.emit()


func _gui_input(e: InputEvent) -> void:
	# A tap on the VS card starts the race at once.
	if _vs.visible and _vs_t > 0.8 and e is InputEventScreenTouch and e.pressed:
		_vs_t = 2.8


# ---------------------------------------------------------------- drawn pieces

## A league's badge: a six-sided crest in the league's colour with a gem, and a crown on top
## for the Bone King league. `pop` makes it swell for a moment (a new league).
class Badge extends Control:
	var league := 0
	var pop := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if pop > 0.0:
			pop = maxf(0.0, pop - delta * 1.6)
			queue_redraw()

	func _draw() -> void:
		var col: Color = Race.LEAGUES[league].col
		var c := size * 0.5 + Vector2(0, 6)
		var r := minf(size.x, size.y - 12.0) * 0.46 * (1.0 + 0.18 * pop)
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 6:
			var a := TAU * i / 6.0 - PI / 2.0
			outer.append(c + Vector2(cos(a), sin(a)) * r)
			inner.append(c + Vector2(cos(a), sin(a)) * r * 0.72)
		draw_colored_polygon(outer, Hud.INK)
		var mid := PackedVector2Array()
		for p in outer:
			mid.append(c + (p - c) * 0.9)
		draw_colored_polygon(mid, col.darkened(0.25))
		draw_colored_polygon(inner, col)
		# A gem in the middle, lit from the top-left.
		var g := r * 0.36
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -g), c + Vector2(g * 0.8, 0), c + Vector2(0, g), c + Vector2(-g * 0.8, 0)]), col.lightened(0.55))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -g), c + Vector2(g * 0.8, 0), c]), Color(1, 1, 1, 0.55))
		# Stars under the crest: one per league reached past Bronze.
		for i in league:
			var x := c.x + (i - (league - 1) * 0.5) * 16.0
			_star(Vector2(x, c.y + r + 2.0), 7.0, Hud.GOLD)
		if league == Race.LEAGUES.size() - 1:
			var cy := c.y - r - 2.0
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - 18, cy), Vector2(c.x - 18, cy - 14), Vector2(c.x - 9, cy - 6),
				Vector2(c.x, cy - 18), Vector2(c.x + 9, cy - 6), Vector2(c.x + 18, cy - 14), Vector2(c.x + 18, cy)]), Hud.GOLD)
		if pop > 0.0:
			draw_arc(c, r * (1.2 + (1.0 - pop) * 0.5), 0.0, TAU, 40, Color(col, pop), 4.0)

	func _star(p: Vector2, s: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a := TAU * i / 10.0 - PI / 2.0
			pts.append(p + Vector2(cos(a), sin(a)) * (s if i % 2 == 0 else s * 0.45))
		draw_colored_polygon(pts, col)


## A racer's face in a ring (the head of their hero picture).
class Face extends Control:
	var ring := Color.WHITE
	var _tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_hero(id: String) -> void:
		var path := "res://art/ui/heroes/%s.png" % id
		_tex = load(path) if ResourceLoader.exists(path) else null
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, r + 2.0, Hud.INK)
		draw_circle(c, r, ring)
		var ir := r - 3.0
		draw_circle(c, ir, Color(0.08, 0.07, 0.12))
		if _tex:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 28:
				var a := TAU * i / 28.0
				var d := Vector2(cos(a), sin(a))
				pts.append(c + d * ir)
				uvs.append(RaceScreen.HEAD.get_center() + d * RaceScreen.HEAD.size.x * 0.5)
			draw_colored_polygon(pts, Color.WHITE, uvs, _tex)


## A gold trophy cup.
class TrophyIcon extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		RaceScreen.draw_trophy(self, size * 0.5, minf(size.x, size.y) * 0.5)


static func draw_trophy(ci: CanvasItem, c: Vector2, s: float) -> void:
	var gold := Hud.GOLD
	var cup := PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.85), c + Vector2(s * 0.7, -s * 0.85), c + Vector2(s * 0.5, -s * 0.05),
		c + Vector2(s * 0.12, s * 0.25), c + Vector2(-s * 0.12, s * 0.25), c + Vector2(-s * 0.5, -s * 0.05)])
	ci.draw_arc(c + Vector2(-s * 0.62, -s * 0.45), s * 0.3, PI * 0.5, PI * 1.5, 10, Hud.INK, s * 0.26)
	ci.draw_arc(c + Vector2(s * 0.62, -s * 0.45), s * 0.3, -PI * 0.5, PI * 0.5, 10, Hud.INK, s * 0.26)
	ci.draw_arc(c + Vector2(-s * 0.62, -s * 0.45), s * 0.3, PI * 0.5, PI * 1.5, 10, gold.darkened(0.2), s * 0.13)
	ci.draw_arc(c + Vector2(s * 0.62, -s * 0.45), s * 0.3, -PI * 0.5, PI * 0.5, 10, gold.darkened(0.2), s * 0.13)
	var edge := PackedVector2Array()
	for p in cup:
		edge.append(c + (p - c) * 1.12)
	ci.draw_colored_polygon(edge, Hud.INK)
	ci.draw_colored_polygon(cup, gold)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.12, s * 0.2), Vector2(s * 0.24, s * 0.4)), gold.darkened(0.15))
	ci.draw_rect(Rect2(c + Vector2(-s * 0.5, s * 0.58), Vector2(s, s * 0.3)), Hud.INK)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.42, s * 0.62), Vector2(s * 0.84, s * 0.2)), gold.darkened(0.1))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.75), c + Vector2(-s * 0.2, -s * 0.75), c + Vector2(-s * 0.3, -s * 0.1)]), Color(1, 1, 1, 0.5))


## A slim bar: how far through the league.
class Meter extends Control:
	var frac := 0.0
	var col := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.08, 0.14)
		bg.border_color = Hud.INK
		bg.set_border_width_all(3)
		bg.set_corner_radius_all(10)
		draw_style_box(bg, r)
		var w := (size.x - 6.0) * clampf(frac, 0.0, 1.0)
		if w > 6.0:
			var f := StyleBoxFlat.new()
			f.bg_color = col
			f.set_corner_radius_all(8)
			draw_style_box(f, Rect2(3, 3, w, size.y - 6.0))
			draw_rect(Rect2(6, 5, maxf(0.0, w - 6.0), (size.y - 6.0) * 0.3), Color(1, 1, 1, 0.25))


## The rival search's spinner: a ring of bones going round.
class Spinner extends Control:
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.4
		draw_arc(c, r, 0.0, TAU, 48, Color(RaceScreen.TEAL, 0.15), 10.0)
		for i in 10:
			var a := _t * 4.0 - i * 0.32
			var p := c + Vector2(cos(a), sin(a)) * r
			draw_circle(p, 9.0 - i * 0.7, Color(RaceScreen.TEAL.lightened(0.3), 1.0 - i * 0.09))
		RaceScreen.draw_trophy(self, c, r * 0.42)


## A race look's colour chip on the Race Road: the glow's ring, the outfit's two colours,
## or the aura's light.
class Swatch extends Control:
	var slot := ""
	var look := {}
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.45
		draw_circle(c, r + 2.0, Hud.INK)
		match slot:
			"outfit":
				draw_circle(c, r, look.get("a", Color.GRAY))
				for i in 3:
					var y := fmod(_t * 30.0 + i * r * 0.7, r * 2.0) - r
					var half := sqrt(maxf(0.0, r * r - y * y)) * 0.85
					draw_line(c + Vector2(-half, y), c + Vector2(half * 0.3, y - r * 0.2), look.get("b", Color.WHITE), 3.0)
			"glow":
				var ring: Color = look.get("ring", Color.WHITE)
				var ring2: Color = look.get("ring2", ring)
				draw_circle(c, r, Color(0.06, 0.06, 0.1))
				draw_arc(c, r * 0.62, 0.0, TAU, 32, ring.lerp(ring2, 0.5 + 0.5 * sin(_t * 3.0)), 6.0)
				draw_circle(c, r * 0.22, look.get("bolt", Color.WHITE))
			_:
				var ink: Color = look.get("ink", Color.WHITE)
				draw_circle(c, r, Color(0.06, 0.06, 0.1))
				for i in 6:
					var a := _t * 2.4 + TAU * i / 6.0
					draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.6, 3.0 + 2.0 * float(i % 2), look.get("spark", ink))
				draw_arc(c, r * 0.85, 0.0, TAU, 32, ink, 3.0)


## The race track on the left of the screen in a race: the finish (the boss's crown) at the
## top, a mark at the end of each room, you (gold) and the rival (red) climbing it, the
## race clock above, and the SURGE meter and the gap to the rival below.
class Bar extends Control:
	var me := 0.0
	var them := 0.0
	var surge := 0.0
	var t := 0.0
	var gap := 0.0
	var stunned := false
	var down := false
	var me_down := false
	var _me_tex: Texture2D
	var _them_tex: Texture2D
	var _flash_me := 0.0
	var _flash_them := 0.0
	var _clock: Label
	var _gap: Label
	var _name: Label
	var _pulse := 0.0
	const TRACK_TOP := 54.0
	const TRACK_BOTTOM := 300.0
	const W := 92.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(W, 420)
		custom_minimum_size = size
		_clock = Hud.label("0:00", 20, Color.WHITE)
		Hud.chunky(_clock.label_settings)
		_clock.label_settings.outline_size = 5
		_clock.position = Vector2(0, 0)
		_clock.size = Vector2(W, 26)
		add_child(_clock)
		_gap = Hud.label("", 16, Color.WHITE)
		_gap.label_settings.outline_size = 5
		_gap.position = Vector2(-10, TRACK_BOTTOM + 86)
		_gap.size = Vector2(W + 20, 24)
		add_child(_gap)
		_name = Hud.label("", 16, RaceScreen.RIVAL, HORIZONTAL_ALIGNMENT_LEFT)
		_name.label_settings.outline_size = 5
		_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		_name.position = Vector2(6, TRACK_BOTTOM + 108)
		_name.size = Vector2(150, 22)
		add_child(_name)

	func setup(my_hero: String, rival_hero: String, rival_name: String) -> void:
		_me_tex = _tex(my_hero)
		_them_tex = _tex(rival_hero)
		_name.text = rival_name
		me = 0.0
		them = 0.0
		surge = 0.0
		t = 0.0
		queue_redraw()

	static func _tex(id: String) -> Texture2D:
		var path := "res://art/ui/heroes/%s.png" % id
		return load(path) if ResourceLoader.exists(path) else null

	func sent() -> void:
		_flash_them = 1.0

	func got() -> void:
		_flash_me = 1.0

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_flash_me = maxf(0.0, _flash_me - delta * 1.5)
		_flash_them = maxf(0.0, _flash_them - delta * 1.5)
		_pulse += delta
		_clock.text = RaceScreen._clock(t)
		if absf(gap) < 0.5:
			_gap.text = "NECK & NECK"
			_gap.label_settings.font_color = Color.WHITE
		else:
			_gap.text = ("AHEAD %ds" if gap > 0.0 else "BEHIND %ds") % roundi(absf(gap))
			_gap.label_settings.font_color = RaceScreen.TEAL if gap > 0.0 else RaceScreen.RIVAL
		queue_redraw()

	func _y(p: float) -> float:
		return lerpf(TRACK_BOTTOM, TRACK_TOP, clampf(p / Race.LEGS, 0.0, 1.0))

	func _draw() -> void:
		var cx := W * 0.5
		# A soft dark panel behind it all, so it reads on any floor.
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.02, 0.01, 0.05, 0.42)
		bg.set_corner_radius_all(16)
		draw_style_box(bg, Rect2(4, 0, W - 8.0, TRACK_BOTTOM + 132))
		# The track: a dark groove, lit teal up to you.
		var top := TRACK_TOP
		var bot := TRACK_BOTTOM
		draw_rect(Rect2(cx - 9, top - 4, 18, bot - top + 8), Hud.INK)
		draw_rect(Rect2(cx - 6, top, 12, bot - top), Color(0.1, 0.12, 0.18, 0.9))
		var my := _y(me)
		draw_rect(Rect2(cx - 6, my, 12, bot - my), Color(RaceScreen.TEAL, 0.75))
		# A notch at the end of each room, and the boss's crown at the finish.
		for i in range(1, Race.LEGS):
			var y := _y(i)
			draw_rect(Rect2(cx - 14, y - 2, 28, 4), Hud.INK)
			draw_rect(Rect2(cx - 12, y - 1, 24, 2), Color(0.85, 0.85, 0.95, 0.8))
		var cy := top - 12.0
		draw_circle(Vector2(cx, cy), 17.0, Hud.INK)
		draw_circle(Vector2(cx, cy), 14.0, Color(0.32, 0.08, 0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 10, cy + 6), Vector2(cx - 10, cy - 5), Vector2(cx - 5, cy),
			Vector2(cx, cy - 9), Vector2(cx + 5, cy), Vector2(cx + 10, cy - 5), Vector2(cx + 10, cy + 6)]), Hud.GOLD)
		# The racers: the rival on the right of the track, you on the left (on top).
		var ty := _y(them)
		_marker(Vector2(cx + 20, ty), _them_tex, RaceScreen.RIVAL, _flash_them, stunned, down)
		_marker(Vector2(cx - 20, my), _me_tex, RaceScreen.YOU, _flash_me, false, me_down)
		# SURGE: a ring that fills with kills, bright when nearly full.
		var sc := Vector2(cx, bot + 44)
		draw_circle(sc, 26.0, Hud.INK)
		draw_circle(sc, 22.0, Color(0.06, 0.08, 0.12))
		var f := clampf(surge, 0.0, 1.0)
		if f > 0.0:
			var glow := 0.75 + 0.25 * sin(_pulse * 10.0) if f > 0.75 else 1.0
			draw_arc(sc, 17.0, -PI / 2.0, -PI / 2.0 + TAU * f, 32, Color(RaceScreen.TEAL, glow), 8.0)
		# A lightning bolt in the ring.
		draw_colored_polygon(PackedVector2Array([sc + Vector2(3, -12), sc + Vector2(-6, 2), sc + Vector2(0, 2),
			sc + Vector2(-3, 12), sc + Vector2(6, -2), sc + Vector2(0, -2)]), RaceScreen.TEAL.lightened(0.4) if f > 0.0 else Color(0.4, 0.42, 0.5))
		var font := Hud.UI_FONT
		draw_string_outline(font, Vector2(cx - 26, bot + 84), "SURGE", HORIZONTAL_ALIGNMENT_CENTER, 52, 16, 6, Hud.INK)
		draw_string(font, Vector2(cx - 26, bot + 84), "SURGE", HORIZONTAL_ALIGNMENT_CENTER, 52, 16, RaceScreen.TEAL.lightened(0.3))

	func _marker(p: Vector2, tex: Texture2D, col: Color, flash: float, stun: bool, is_down: bool) -> void:
		var r := 17.0 + 5.0 * flash
		draw_circle(p, r + 3.0, Hud.INK)
		draw_circle(p, r, col.lerp(Color.WHITE, flash * 0.7))
		var ir := r - 3.0
		if tex:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				var d := Vector2(cos(a), sin(a))
				pts.append(p + d * ir)
				uvs.append(RaceScreen.HEAD.get_center() + d * RaceScreen.HEAD.size.x * 0.5)
			var tint := Color(0.45, 0.45, 0.5) if is_down else Color.WHITE
			draw_colored_polygon(pts, tint, uvs, tex)
		else:
			draw_circle(p, ir, col.darkened(0.4))
		if stun:
			# Stunned by your surge: crackling teal sparks round the rival.
			for i in 4:
				var a := _pulse * 9.0 + TAU * i / 4.0
				draw_line(p + Vector2(cos(a), sin(a)) * (r + 2.0), p + Vector2(cos(a + 0.4), sin(a + 0.4)) * (r + 8.0), RaceScreen.TEAL, 3.0)
		if is_down:
			var font := Hud.UI_FONT
			draw_string_outline(font, p + Vector2(-16, -r - 2.0), "Zz", HORIZONTAL_ALIGNMENT_CENTER, 32, 16, 5, Hud.INK)
			draw_string(font, p + Vector2(-16, -r - 2.0), "Zz", HORIZONTAL_ALIGNMENT_CENTER, 32, 16, Color.WHITE)
