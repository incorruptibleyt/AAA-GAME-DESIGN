class_name HeroScreen
extends ColorRect
## The Heroes screen: one hero at a time on a turning pedestal, with their stats, their
## special and the three blessings only they can find. The arrows or the name tabs switch
## hero; the big button picks (or unlocks) the one on show.

signal pick(id: String)
signal trial(id: String)
signal mastery(id: String)
signal style(id: String)
signal feats(id: String)
signal closed

## The stat bars: [key in Heroes.LIST, name, how the number is shown].
const STATS := [["health", "Health", "%d"], ["damage", "Damage", "%d"], ["rate", "Attack speed", "%.1f/s"], ["move_speed", "Speed", "%.1f"]]
const TEXT := Color(0.85, 0.85, 0.9)
const DIM := Color(0.62, 0.6, 0.68)

## rows: [{id, name, badge, mastery, cost, unlocked, selected, trial, trying, def, points,
## frame}] from game.gd (def: the hero as they look, in their mastery color if it's on;
## points: Hero Mastery points; frame: a Master's gold frame).
var _rows: Array = []
var _coins := 0
var _index := 0
var _shown_id := ""
var _stage: HeroStage
var _tabs: Array[Button] = []
var _coin_label: Label
var _name: Label
## Version 129: who the hero is ("THE ROGUE · Quick, cheeky..."), and their speech bubble.
var _who: Label
var _bubble: SpeechBubble
var _spoke := ""
var _badge: Label
var _mastery_bar: MasteryBar
var _style_button: Button
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
var _col: VBoxContainer
var _stage_box: Control
## The pedestal's height; on short (16:9) screens it gives up what the rest needs, down to
## STAGE_MIN, so the buttons at the bottom always fit.
const STAGE_H := 250.0
const STAGE_MIN := 130.0


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 1.0)
	Hud.backdrop(self)
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
	# Version 125 (audit #8): clear of a notch, camera hole or rounded corners.
	visibility_changed.connect(func(): if visible: Hud.safe_pad(col))
	_col = col
	resized.connect(_fit)
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
		t.custom_minimum_size = Vector2(0, 64)   # A-11: easy to hit with a thumb
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(_switch.bind(i))
		tabs.add_child(t)
		_tabs.append(t)
	col.add_child(_build_stage())
	# Version 130: the pedestal stands in a lit archway, in the hero's own colour of light.
	MenuBackdrop.of(self).show_off(_stage_box, Vector2(0.5, 0.42), 0.86, 0.6)
	_name = Hud.label("", 36, Color.WHITE)
	col.add_child(_name)
	_who = Hud.label("", 16, TEXT)
	col.add_child(_who)
	_badge = Hud.label("", 16, Hud.GOLD)
	col.add_child(_badge)
	# Hero Mastery: tap for every level and the mastery color.
	var mrow := HBoxContainer.new()
	mrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mrow.add_theme_constant_override("separation", 6)
	col.add_child(mrow)
	_mastery_bar = MasteryBar.new()
	_mastery_bar.custom_minimum_size = Vector2(0, 76)
	_mastery_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mastery_bar.make_tappable()
	_mastery_bar.tapped.connect(func():
		Sfx.play("click")
		mastery.emit(_row().id))
	mrow.add_child(_mastery_bar)
	# The Style screen: outfits, hats, weapons, glows and auras unlocked by Mastery.
	_style_button = Hud.button("STYLE", 17)
	_style_button.custom_minimum_size = Vector2(90, 70)
	_style_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_button.pressed.connect(func():
		Sfx.play("click")
		style.emit(_row().id))
	mrow.add_child(_style_button)
	# Feats: the skill challenges and the looks they give (version 116: only on the Style
	# screen before, where few found them).
	var feats_b := Hud.button("FEATS", 17, Color(0.05, 0.16, 0.2, 0.97), Color(0.5, 0.95, 1.0))
	feats_b.custom_minimum_size = Vector2(86, 70)
	feats_b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feats_b.pressed.connect(func():
		Sfx.play("click")
		feats.emit(_row().id))
	mrow.add_child(feats_b)
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
	box.custom_minimum_size = Vector2(0, STAGE_H)
	_stage_box = box
	_stage = HeroStage.new(Vector2(504, STAGE_H))
	_stage.custom_minimum_size = Vector2.ZERO   # the box sets the size (_fit)
	Hud.full(_stage)
	box.add_child(_stage)
	for side in [-1, 1]:
		var b := Hud.button("<" if side < 0 else ">", 34, Color(0.1, 0.08, 0.14, 0.7), Color(1, 0.8, 0.45, 0.45))
		b.custom_minimum_size = Vector2(56, 84)
		b.anchor_left = 0.0 if side < 0 else 1.0
		b.anchor_right = b.anchor_left
		# Low on the pedestal picture (version 129), leaving the space beside the hero's face
		# for their speech bubble.
		b.anchor_top = 0.62
		b.anchor_bottom = 0.62
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
	Hud.squash(_action)
	row.add_child(_action)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 10)
	Hud.full(inner)
	inner.offset_bottom = -5   # centred on the face, above the button's lip
	_action.add_child(inner)
	_action_text = Hud.label("", 24, Color.WHITE)
	Hud.chunky(_action_text.label_settings)
	_action_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	inner.add_child(_action_text)
	_action_cost = Hud.coin_row(22, inner)
	# Each locked hero can be tried for one run, free.
	_try = Hud.button("TRY FREE", 18, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
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
		_spoke = ""
	visible = true
	_stage.set_active(true)
	_refresh()


## Fits again once the new text has been laid out. A label that was hidden (the gold
## "Locked" line) has no width yet when it first shows, so it measures one word per line,
## nearly 1,000 tall, and the hero used to shrink to the smallest pedestal for every locked hero.
func _fit_soon() -> void:
	_fit.call_deferred()
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self):
		_fit()


## Shrinks the pedestal just enough for everything else to fit on screen.
func _fit() -> void:
	if not visible or _col == null:
		return
	_stage_box.custom_minimum_size.y = STAGE_H
	var over := _col.get_combined_minimum_size().y - (size.y - 32.0)
	_stage_box.custom_minimum_size.y = clampf(STAGE_H - over, STAGE_MIN, STAGE_H)


func close() -> void:
	visible = false
	_stage.set_active(false)
	if _bubble:
		_bubble.hide_now()


## Which hero is on show (the test robot pictures each one).
func show_index(i: int) -> void:
	_index = posmod(i, _rows.size())
	_refresh()


func _switch(i: int) -> void:
	Sfx.play("click")
	show_index(i)


## The backdrop's light for a hero's colour: their ring colour, a little softer.
static func _light(ring: Color) -> Color:
	return ring.lerp(Color(1.0, 0.9, 0.75), 0.2)


func _row() -> Dictionary:
	return _rows[_index]


func _refresh() -> void:
	if _rows.is_empty():
		return
	var r := _row()
	var def: Dictionary = r.get("def", Heroes.get_hero(r.id))
	var ring: Color = def.ring
	var frame := bool(r.get("frame", false))
	var frame_col: Color = r.get("frame_color", Color(1.0, 0.8, 0.3))
	# A new hero, or the same one in a new color or frame, goes back on the pedestal.
	var look_key := "%s %s %s %s" % [r.id, def.ring, frame, frame_col]
	if look_key != _shown_id:
		_shown_id = look_key
		_stage.show_hero(def, frame, frame_col)
	_coin_label.text = str(_coins)
	for i in _tabs.size():
		var t := _tabs[i]
		var on := i == _index
		Hud.paint(t, "gold" if on else "slate")
		var owned: bool = _rows[i].unlocked
		t.add_theme_color_override("font_color", Color.WHITE if on else (Color(1, 0.93, 0.8) if owned else DIM))
	MenuBackdrop.of(self).set_key(_light(ring), not visible)
	_name.text = Heroes.hero_name(def).to_upper()
	_name.label_settings.font_color = ring.lightened(0.25)
	_who.text = "THE %s  ·  %s" % [def.title.to_upper(), Heroes.get_hero(r.id).get("about", "")]
	_who.label_settings.font_color = ring.lightened(0.55)
	if _spoke != r.id:
		_spoke = r.id
		_greet.call_deferred(def)
	var bits := []
	var title := HeroMastery.title_for(HeroMastery.level_for(int(r.get("points", 0))))
	if title != "":
		bits.append(title)
	if r.badge != "":
		bits.append("Curse title: " + r.badge)
	if r.mastery > 0:
		bits.append("Best Curse Level beaten: %d" % r.mastery)
	if not r.unlocked:
		bits.append("Locked · or get every hero with the Crypt Pass")
	_badge.label_settings.font_color = Hud.GOLD
	_badge.text = "  ·  ".join(bits)
	_badge.visible = not bits.is_empty()
	_text.text = def.text
	_mastery_bar.set_points(r.id, def.title, ring, int(r.get("points", 0)))
	# New looks waiting: the Style button says so, in gold.
	var fresh := int(r.get("new_looks", 0))
	_style_button.text = "STYLE\n%d NEW" % fresh if fresh > 0 else "STYLE"
	_style_button.add_theme_font_size_override("font_size", 16 if fresh > 0 else 19)
	Hud.paint(_style_button, "gold" if fresh > 0 else "purple")
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
	_fit_soon()


func def_for(r: Dictionary) -> Dictionary:
	return r.get("def", Heroes.get_hero(r.id))


## A hero says hello when they step onto the pedestal: one of their lines in a speech bubble
## beside their head, and their emote (version 129).
func _greet(def: Dictionary) -> void:
	if not visible:
		return
	if _bubble == null:
		_bubble = SpeechBubble.new()
		_bubble.side = SpeechBubble.Side.RIGHT
		_bubble.max_width = 150.0
		_bubble.text_size = 19
		add_child(_bubble)
	var h := Heroes.get_hero(str(def.id))
	_stage.emote(h.get("emote", []))
	_bubble.say(str(h.get("name", def.title)), Heroes.line(def, "pick"), def.ring, float(h.get("voice", 1.0)))
	_place_bubble()


func _place_bubble() -> void:
	if _bubble == null:
		return
	var box := _stage_box.get_global_rect()
	var mine := get_global_rect()
	# Just left of the hero's face (near the top of the pedestal picture), above the < button
	# (which sits low for this), the tail pointing at the face.
	_bubble.point_at(box.position - mine.position + Vector2(box.size.x * 0.5 - 50.0, box.size.y * 0.27))


func _process(_delta: float) -> void:
	if visible and _bubble and _bubble.talking():
		_place_bubble()


## How full a stat bar is: the weakest hero gets a third of a bar, the strongest a full one.
func _share(key: String, value: float) -> float:
	var lo := INF
	var hi := -INF
	for h: Dictionary in Heroes.LIST:
		lo = minf(lo, h[key])
		hi = maxf(hi, h[key])
	return lerpf(0.33, 1.0, (value - lo) / maxf(hi - lo, 0.001))


func _fill_action(r: Dictionary, ring: Color) -> void:
	var afford: bool = r.unlocked or r.cost <= _coins
	_action_cost.get_parent().visible = not r.unlocked and not r.trying
	_action_cost.text = str(r.cost)
	_action_cost.label_settings.font_color = Hud.GOLD if afford else DIM
	_try.visible = r.trial and not r.trying
	var text_col := Color.WHITE
	var role := "slate"
	if r.trying:
		_action_text.text = "FREE TRIAL"
		role = "gold"
	elif r.selected:
		_action_text.text = "CHOSEN"
		text_col = ring.lightened(0.45)
	elif r.unlocked:
		_action_text.text = "PLAY AS " + Heroes.hero_name(def_for(r)).to_upper()
		role = "green"
	else:
		_action_text.text = "UNLOCK"
		role = "gold" if afford else "slate"
		text_col = Color.WHITE if afford else DIM
	Hud.paint(_action, role)
	_action_text.label_settings.font_color = text_col


func _on_action() -> void:
	var r := _row()
	if r.selected or r.trying:
		return
	if not r.unlocked and r.cost > _coins:
		_need_coins(r)
	pick.emit(r.id)


## UNLOCK without enough coins: say how many more are needed, and the other ways in.
func _need_coins(r: Dictionary) -> void:
	_badge.text = "You need %d more coins. Runs earn coins%s, or the Crypt Pass unlocks every hero." % [
		r.cost - _coins, ", or TRY FREE first" if r.trial else ""]
	_badge.label_settings.font_color = Color(1, 0.55, 0.45)
	_badge.visible = true
	var x := _action.position.x
	var tw := create_tween()
	for dx in [10.0, -8.0, 6.0, -3.0, 0.0]:
		tw.tween_property(_action, "position:x", x + dx, 0.04)
	var id: String = r.id
	get_tree().create_timer(3.5).timeout.connect(func():
		if visible and _row().id == id:
			_badge.label_settings.font_color = Hud.GOLD
			_refresh())
