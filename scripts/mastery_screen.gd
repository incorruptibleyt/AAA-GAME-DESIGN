class_name MasteryScreen
extends ColorRect
## A hero's Mastery screen (from the Heroes screen): their mastery bar, all ten levels with
## what each gives and the looks it unlocks (earned ones ticked, the next one lit), and the
## way to the Style screen.

signal style(id: String)
signal closed

const DIM := Color(0.6, 0.58, 0.66)
const TEXT := Color(0.88, 0.87, 0.92)
const DONE := Color(0.45, 0.85, 0.5)

var _id := ""
var _title: Label
var _bar: MasteryBar
var _how: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _style_row: PanelContainer
var _style_text: Label


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 1.0)
	Hud.backdrop(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	Hud.full(col)
	col.offset_left = 18
	col.offset_right = -18
	col.offset_top = 22
	col.offset_bottom = -22
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	_title = Hud.label("MASTERY", 38, Color(1, 0.85, 0.55))
	col.add_child(_title)
	_bar = MasteryBar.new()
	_bar.custom_minimum_size = Vector2(0, 92)
	col.add_child(_bar)
	_how = Hud.label("Every room cleared with this hero gives %d mastery points, every boss %d. Points are never lost." % [HeroMastery.ROOM_POINTS, HeroMastery.BOSS_POINTS], 16, DIM)
	col.add_child(_how)
	_style_row = _build_style_row()
	col.add_child(_style_row)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	var back := Hud.button("BACK", 24)
	back.custom_minimum_size = Vector2(240, 70)
	back.pressed.connect(func():
		visible = false
		closed.emit())
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(back)
	col.add_child(box)


func _build_style_row() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.13, 0.95)
	sb.border_color = Color(1, 0.8, 0.45, 0.6)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	_style_text = Hud.label("", 17, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_style_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_style_text)
	var b := Hud.button("STYLE", 22)
	b.custom_minimum_size = Vector2(150, 58)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		Sfx.play("click")
		style.emit(_id))
	h.add_child(b)
	return panel


## Fills the screen for hero `id` (cfg = the save) and shows it, scrolled to the next level.
func open_hero(cfg: ConfigFile, id: String) -> void:
	_id = id
	visible = true
	var def := HeroStyle.styled(cfg, Heroes.get_hero(id))
	var p := HeroMastery.points(cfg, id)
	var lv := HeroMastery.level_for(p)
	_title.text = "%s MASTERY" % str(def.title).to_upper()
	_title.label_settings.font_color = Color(def.ring).lightened(0.25)
	var rank := HeroMastery.rank(lv)
	var t := HeroMastery.title_for(lv)
	_bar.set_points(id, def.title, def.ring, p, "%s RANK%s" % [str(rank.name).to_upper(), "  ·  " + t.to_upper() if t != "" else ""])
	var got := HeroStyle.items(id).filter(func(it: Dictionary) -> bool: return it.key != "" and it.level <= lv).size()
	var all := HeroStyle.items(id).size() - HeroStyle.SLOTS.size()
	_style_text.text = "%d of %d looks unlocked\nPick outfits, hats, weapons, glows and auras" % [got, all]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var focus: Control = null
	for l in range(1, HeroMastery.MAX_LEVEL + 1):
		var row := _row(id, l, lv, p)
		_list.add_child(row)
		if l == lv + 1:
			focus = row
	_scroll_to(focus)


## Scrolls so the next level sits a third of the way down, once the list is laid out
## (as the Bone Road screen does).
func _scroll_to(row: Control) -> void:
	for i in 2:
		await get_tree().process_frame
	if not visible:
		return
	if row == null or not is_instance_valid(row):
		_scroll.scroll_vertical = 100000
		return
	_scroll.scroll_vertical = int(maxf(0.0, row.position.y - _scroll.size.y * 0.35))


func _row(id: String, l: int, lv: int, p: int) -> Control:
	var got := l <= lv
	var next := l == lv + 1
	var rank := HeroMastery.rank(l)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.15, 0.06, 0.97) if next else Color(0.1, 0.08, 0.13, 0.95)
	sb.border_color = Hud.GOLD if next else (DONE.darkened(0.3) if got else Color(0.3, 0.28, 0.36))
	sb.set_border_width_all(3 if next else 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var badge := MasteryBar.Badge.new()
	badge.custom_minimum_size = Vector2(50, 54)
	badge.set_level(l, rank.color if got or next else rank.color.darkened(0.45), false)
	badge.modulate = Color.WHITE if got or next else Color(1, 1, 1, 0.75)
	badge.tick = got
	h.add_child(badge)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var what := HeroMastery.level_text(l, id, false) if l > 1 else "Where every hero starts"
	texts.add_child(Hud.label(what, 20, TEXT if got or next else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var looks := HeroStyle.level_items(id, l).map(func(it: Dictionary) -> String: return HeroStyle.item_label(id, it.slot, it.key))
	if not looks.is_empty():
		texts.add_child(Hud.label("Looks: " + ", ".join(looks), 14, TEXT if got or next else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var need: String
	if got:
		need = "Earned"
	else:
		need = "%d points to go" % (int(HeroMastery.LEVELS[l - 1]) - p)
	need = "%s  ·  %s" % [rank.name, need]
	for r: Dictionary in HeroMastery.REWARDS.get(l, []):
		if r.kind == "lucky":
			need += "  ·  free blessings"
	texts.add_child(Hud.label(need, 14, Hud.GOLD if next else (DONE if got else DIM), HORIZONTAL_ALIGNMENT_LEFT))
	return panel
