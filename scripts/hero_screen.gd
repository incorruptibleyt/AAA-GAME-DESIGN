class_name HeroScreen
extends ColorRect
## The Heroes screen: one hero at a time on a turning pedestal, with their stats, their
## special and the three blessings only they can find. The arrows or the name tabs switch
## hero; the big button picks (or unlocks) the one on show.

signal pick(id: String)
signal trial(id: String)
signal closed

## The stat bars: [key in Heroes.LIST, name, how the number is shown].
const STATS := [["health", "Health", "%d"], ["damage", "Damage", "%d"], ["rate", "Attack speed", "%.1f/s"], ["move_speed", "Speed", "%.1f"]]
const TEXT := Color(0.85, 0.85, 0.9)
const DIM := Color(0.62, 0.6, 0.68)

## rows: [{id, name, badge, mastery, cost, unlocked, selected, trial, trying}] from game.gd.
var _rows: Array = []
var _coins := 0
var _index := 0
var _shown_id := ""
var _stage: HeroStage
var _tabs: Array[Button] = []
var _coin_label: Label
var _name: Label
var _badge: Label
var _text: Label
var _fills: Array[ColorRect] = []
var _values: Array[Label] = []
var _special_box: StyleBoxFlat
var _special_title: Label
var _special_text: Label
var _only: Label
var _icons: Array[BlessingIcon] = []
var _icon_names: Array[Label] = []
var _action: Button
var _action_text: Label
var _action_cost: Label
var _try: Button


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 1.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 18
	col.offset_right = -18
	col.offset_top = 16
	col.offset_bottom = -16
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	# HEROES, and your coins.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var title := Hud.label("HEROES", 40, Color(1, 0.85, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_coin_label = Hud.coin_row(28, head)
	# One tab per hero.
	var tabs := HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for i in Heroes.LIST.size():
		var t := Hud.button(Heroes.LIST[i].title, 17)
		t.custom_minimum_size = Vector2(0, 46)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(_switch.bind(i))
		tabs.add_child(t)
		_tabs.append(t)
	col.add_child(_build_stage())
	_name = Hud.label("", 36, Color.WHITE)
	col.add_child(_name)
	_badge = Hud.label("", 16, Hud.GOLD)
	col.add_child(_badge)
	_text = Hud.label("", 17, TEXT)
	col.add_child(_text)
	col.add_child(_build_stats())
	col.add_child(_build_special())
	_only = Hud.label("", 15, DIM)
	col.add_child(_only)
	col.add_child(_build_blessings())
	col.add_child(_build_buttons())


func _build_stage() -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(0, 250)
	_stage = HeroStage.new(Vector2(504, 250))
	Hud.full(_stage)
	box.add_child(_stage)
	for side in [-1, 1]:
		var b := Hud.button("<" if side < 0 else ">", 34, Color(0.1, 0.08, 0.14, 0.7), Color(1, 0.8, 0.45, 0.45))
		b.custom_minimum_size = Vector2(56, 84)
		b.anchor_left = 0.0 if side < 0 else 1.0
		b.anchor_right = b.anchor_left
		b.anchor_top = 0.5
		b.anchor_bottom = 0.5
		b.offset_left = 0.0 if side < 0 else -56.0
		b.offset_right = b.offset_left + 56.0
		b.offset_top = -42.0
		b.offset_bottom = 42.0
		b.pressed.connect(func(): _switch(_index + side))
		box.add_child(b)
	return box


func _build_stats() -> Control:
	var panel := _panel(Color(0.1, 0.08, 0.13, 0.98))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	for s: Array in STATS:
		var n := Hud.label(s[1], 16, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		n.custom_minimum_size = Vector2(118, 0)
		grid.add_child(n)
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.55)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.custom_minimum_size = Vector2(0, 14)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.anchor_bottom = 1.0
		bar.add_child(fill)
		_fills.append(fill)
		var v := Hud.label("", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.custom_minimum_size = Vector2(62, 0)
		grid.add_child(v)
		_values.append(v)
	return panel


func _build_special() -> Control:
	var panel := _panel(Color(0.12, 0.1, 0.16, 0.98))
	_special_box = panel.get_theme_stylebox("panel") as StyleBoxFlat
	_special_box.border_width_left = 8
	_special_box.content_margin_left = 18
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)
	_special_title = Hud.label("", 20, Hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(_special_title)
	_special_text = Hud.label("", 16, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(_special_text)
	return panel


func _build_blessings() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	for i in 3:
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.custom_minimum_size = Vector2(160, 0)
		v.add_theme_constant_override("separation", 0)
		row.add_child(v)
		var icon := BlessingIcon.new()
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		_icons.append(icon)
		var n := Hud.label("", 14, TEXT)
		n.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(n)
		_icon_names.append(n)
	return row


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var back := Hud.button("BACK", 24)
	back.custom_minimum_size = Vector2(124, 72)
	back.pressed.connect(func(): closed.emit())
	row.add_child(back)
	_action = Hud.button("", 24)
	_action.custom_minimum_size = Vector2(210, 72)
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action.pressed.connect(_on_action)
	row.add_child(_action)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 10)
	Hud.full(inner)
	_action.add_child(inner)
	_action_text = Hud.label("", 22, Color(1, 0.93, 0.8))
	_action_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	inner.add_child(_action_text)
	_action_cost = Hud.coin_row(22, inner)
	# Each locked hero can be tried for one run, free.
	_try = Hud.button("TRY FREE", 18, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_try.add_theme_color_override("font_color", Hud.GOLD)
	_try.custom_minimum_size = Vector2(124, 72)
	_try.pressed.connect(func(): trial.emit(_row().id))
	row.add_child(_try)
	return row


func _panel(bg: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	return panel


## Opens on your hero, or fills in new numbers if it's already open (after unlocking one).
func open(rows: Array, coins: int) -> void:
	_rows = rows
	_coins = coins
	if not visible:
		_index = 0
		for i in rows.size():
			if rows[i].selected or rows[i].trying:
				_index = i
		_shown_id = ""
	visible = true
	_stage.set_active(true)
	_refresh()


func close() -> void:
	visible = false
	_stage.set_active(false)


## Which hero is on show (the test robot pictures each one).
func show_index(i: int) -> void:
	_index = posmod(i, _rows.size())
	_refresh()


func _switch(i: int) -> void:
	Sfx.play("click")
	show_index(i)


func _row() -> Dictionary:
	return _rows[_index]


func _refresh() -> void:
	if _rows.is_empty():
		return
	var r := _row()
	var def := Heroes.get_hero(r.id)
	var ring: Color = def.ring
	if r.id != _shown_id:
		_shown_id = r.id
		_stage.show_hero(def)
	_coin_label.text = str(_coins)
	for i in _tabs.size():
		var t := _tabs[i]
		var on := i == _index
		var sb := t.get_theme_stylebox("normal") as StyleBoxFlat
		var col: Color = Heroes.LIST[i].ring
		sb.border_color = col if on else Color(col, 0.35)
		sb.set_border_width_all(3 if on else 2)
		sb.bg_color = Color(0.2, 0.16, 0.26, 0.98) if on else Color(0.12, 0.1, 0.16, 0.9)
		var owned: bool = _rows[i].unlocked
		t.add_theme_color_override("font_color", Color.WHITE if on else (Color(1, 0.93, 0.8) if owned else DIM))
	_name.text = def.title.to_upper()
	_name.label_settings.font_color = ring.lightened(0.25)
	var bits := []
	if r.badge != "":
		bits.append(r.badge)
	if r.mastery > 0:
		bits.append("Best Curse Level beaten: %d" % r.mastery)
	if not r.unlocked:
		bits.append("Locked · or get every hero with the Crypt Pass")
	_badge.text = "  ·  ".join(bits)
	_badge.visible = not bits.is_empty()
	_text.text = def.text
	for i in STATS.size():
		var key: String = STATS[i][0]
		_values[i].text = STATS[i][2] % def[key]
		_fills[i].color = ring
		var tw := create_tween()
		tw.tween_property(_fills[i], "anchor_right", _share(key, def[key]), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_special_box.border_color = ring
	_special_title.text = "SPECIAL  ·  " + def.special
	_special_text.text = def.special_text
	_only.text = "Only the %s can find these blessings:" % def.title
	var own := Upgrades.LIST.filter(func(u: Dictionary): return u.get("hero", "") == r.id)
	for i in _icons.size():
		var has := i < own.size()
		_icons[i].visible = has
		_icon_names[i].visible = has
		if has:
			_icons[i].show_for(own[i])
			_icon_names[i].text = own[i].title
	_fill_action(r, ring)


## How full a stat bar is: the weakest hero gets a third of a bar, the strongest a full one.
func _share(key: String, value: float) -> float:
	var lo := INF
	var hi := -INF
	for h: Dictionary in Heroes.LIST:
		lo = minf(lo, h[key])
		hi = maxf(hi, h[key])
	return lerpf(0.33, 1.0, (value - lo) / maxf(hi - lo, 0.001))


func _fill_action(r: Dictionary, ring: Color) -> void:
	var sb := _action.get_theme_stylebox("normal") as StyleBoxFlat
	var pressed := _action.get_theme_stylebox("pressed") as StyleBoxFlat
	var afford: bool = r.unlocked or r.cost <= _coins
	_action_cost.get_parent().visible = not r.unlocked and not r.trying
	_action_cost.text = str(r.cost)
	_action_cost.label_settings.font_color = Hud.GOLD if afford else DIM
	_try.visible = r.trial and not r.trying
	var text_col := Color(1, 0.93, 0.8)
	if r.trying:
		_action_text.text = "FREE TRIAL"
		sb.bg_color = Color(0.3, 0.2, 0.06, 0.97)
		sb.border_color = Hud.GOLD
		text_col = Hud.GOLD
	elif r.selected:
		_action_text.text = "CHOSEN"
		sb.bg_color = Color(0.12, 0.1, 0.16, 0.98)
		sb.border_color = ring
		text_col = ring.lightened(0.3)
	elif r.unlocked:
		_action_text.text = "PLAY AS " + Heroes.get_hero(r.id).title.to_upper()
		sb.bg_color = Color(0.12, 0.3, 0.16, 0.97)
		sb.border_color = Color(0.6, 1, 0.6)
	else:
		_action_text.text = "UNLOCK"
		sb.bg_color = Color(0.45, 0.3, 0.08, 0.98) if afford else Color(0.14, 0.12, 0.17, 0.95)
		sb.border_color = Hud.GOLD if afford else Color(0.4, 0.35, 0.45, 0.6)
		text_col = Color(1, 0.93, 0.8) if afford else DIM
	sb.set_border_width_all(4 if r.selected else 2)
	pressed.bg_color = sb.bg_color.lightened(0.2)
	pressed.border_color = sb.border_color
	_action_text.label_settings.font_color = text_col


func _on_action() -> void:
	var r := _row()
	if r.selected or r.trying:
		return
	pick.emit(r.id)
