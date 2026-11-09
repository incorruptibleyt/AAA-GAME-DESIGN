class_name FeatsScreen
extends ColorRect
## The Feats screen (from the Style screen): all twenty Feats (feats.gd) with the look each
## one wins and how close the counted ones are, then the looks only found in Bone Drops.
## Every one of these looks can be worn by any hero.

signal closed

const CYAN := Color(0.5, 0.95, 1.0)
const TEXT := Color(0.88, 0.87, 0.92)
const DIM := Color(0.6, 0.58, 0.66)

var _head: Label
var _sub: Label
var _list: VBoxContainer
var _scroll: ScrollContainer


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 1.0)
	Hud.backdrop(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	Hud.full(col)
	col.offset_left = 16
	col.offset_right = -16
	col.offset_top = 18
	col.offset_bottom = -18
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	# Version 125 (audit #8): clear of a notch, camera hole or rounded corners.
	visibility_changed.connect(func(): if visible: Hud.safe_pad(col))
	_head = Hud.label("FEATS", 44, CYAN)
	col.add_child(_head)
	_sub = Hud.label("", 17, TEXT)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_sub)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	var back := Hud.button("BACK", 24)
	back.custom_minimum_size = Vector2(180, 72)   # version 122: BACK in the same corner on every screen
	back.pressed.connect(close)
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(back)
	col.add_child(box)


## Fills the screen from the save `cfg`, the looks drawn for hero `id`.
func open_screen(cfg: ConfigFile, id: String) -> void:
	for c in _list.get_children():
		c.free()
	var base := Heroes.get_hero(id)
	var n := Feats.count(cfg)
	_sub.text = "%d of %d done  ·  each Feat wins a look every hero can wear" % [n, Feats.LIST.size()]
	# Done ones last, so the next ones to go for are on top.
	var todo := Feats.LIST.filter(func(f: Dictionary) -> bool: return not Feats.done(cfg, f.id))
	var done := Feats.LIST.filter(func(f: Dictionary) -> bool: return Feats.done(cfg, f.id))
	for f: Dictionary in todo + done:
		var got := Feats.done(cfg, f.id)
		var lines := [[str(f.text), 16, TEXT if not got else DIM]]
		var prog := Feats.progress(cfg, f) if not got else ""
		if prog != "":
			lines.append([prog, 15, Color(1.0, 0.82, 0.45)])
		lines.append(["Wins: " + Feats.reward_label(f), 15, CYAN if got else Color(0.62, 0.85, 0.9)])
		_list.add_child(_row(id, base, f.look, str(f.name), lines, got, CYAN))
	# The Bone Drop looks.
	var found := Drops.found_looks(cfg)
	var h := Hud.label("BONE DROP LOOKS  ·  %d of %d found" % [found, Drops.all_looks()], 24, Color(1, 0.85, 0.55))
	h.custom_minimum_size = Vector2(0, 64)
	h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_list.add_child(h)
	for slot: String in HeroStyle.EXTRA:
		for key: String in HeroStyle.EXTRA[slot]:
			var e: Dictionary = HeroStyle.EXTRA[slot][key]
			if not e.has("drop"):
				continue
			var tier: Dictionary = Drops.TIERS[int(e.drop)]
			var got := Drops.has_look(cfg, slot, key)
			var lines := [["%s Bone Drop" % str(tier.name).capitalize(), 16, Color(tier.color).lightened(0.25)],
				["Found! Wear it on the Style screen." if got else "Not found yet", 15, TEXT if got else DIM]]
			_list.add_child(_row(id, base, [slot, key], HeroStyle.item_label(id, slot, key), lines, got, tier.color))
	visible = true
	_scroll.scroll_vertical = 0


func _row(id: String, base: Dictionary, look: Array, title: String, lines: Array, got: bool, accent: Color) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.16, 0.97) if got else Color(0.08, 0.07, 0.11, 0.95)
	sb.border_color = Color(accent, 0.9 if got else 0.35)
	sb.set_border_width_all(3 if got else 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 10)
	panel.add_child(hb)
	var sw := StyleScreen.Swatch.new()
	sw.custom_minimum_size = Vector2(78, 78)
	sw.setup(id, str(look[0]), str(look[1]), base)
	sw.modulate = Color.WHITE if got else Color(1, 1, 1, 0.55)
	hb.add_child(sw)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	hb.add_child(v)
	var t := Hud.label(title, 21, Color(1.0, 0.9, 0.6) if got else TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	for l: Array in lines:
		var lb := Hud.label(str(l[0]), int(l[1]), l[2], HORIZONTAL_ALIGNMENT_LEFT)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(lb)
	if got:
		var tick := Hud.label("DONE", 16, Color(0.5, 1.0, 0.55))
		tick.custom_minimum_size = Vector2(64, 0)
		hb.add_child(tick)
	return panel


func close() -> void:
	if not visible:
		return
	Sfx.play("click")
	visible = false
	closed.emit()
