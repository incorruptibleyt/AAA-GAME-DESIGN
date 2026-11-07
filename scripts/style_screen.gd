class_name StyleScreen
extends ColorRect
## A hero's Style screen (from the Heroes and Mastery screens): the hero on a pedestal, and
## tabs of looks to dress them in (hero_style.gd): outfits, headwear, weapons and glows.
## Tapping an unlocked look wears it straight away; tapping a locked one tries it on, so you
## can see what a Mastery level will bring, and says which level unlocks it.

signal wear(id: String, slot: String, key: String)
signal closed

const TABS := [["outfit", "OUTFIT"], ["head", "HEAD"], ["hold", "WEAPON"], ["glow", "GLOW"]]
const TEXT := Color(0.88, 0.87, 0.92)
const DIM := Color(0.6, 0.58, 0.66)
## The pedestal's height; on short (16:9) screens it shrinks so the looks keep their room.
const STAGE_H := 300.0
const STAGE_MIN := 190.0

var _id := ""
var _level := 1
var _base: Dictionary = {}
var _picks: Dictionary = {}
var _preview: Dictionary = {}
var _frame := false
var _slot := "outfit"
var _title: Label
var _stage: HeroStage
var _stage_box: Control
var _note: Label
var _tabs := {}
var _grid: GridContainer
var _scroll: ScrollContainer
var _down_at := 0   # where the list was when a card was touched


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 1.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	Hud.full(col)
	col.offset_left = 18
	col.offset_right = -18
	col.offset_top = 18
	col.offset_bottom = -18
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_title = Hud.label("STYLE", 34, Color(1, 0.85, 0.55))
	col.add_child(_title)
	_stage_box = Control.new()
	_stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.custom_minimum_size = Vector2(0, STAGE_H)
	col.add_child(_stage_box)
	_stage = HeroStage.new(Vector2(504, STAGE_H))
	_stage.custom_minimum_size = Vector2.ZERO
	Hud.full(_stage)
	_stage_box.add_child(_stage)
	_note = Hud.label("", 16, Hud.GOLD)
	col.add_child(_note)
	var tabs := HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	for t: Array in TABS:
		var b := Hud.button(t[1], 17)
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Sfx.play("click")
			_show_tab(t[0], true))
		tabs.add_child(b)
		_tabs[t[0]] = b
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	var back := Hud.button("BACK", 24)
	back.custom_minimum_size = Vector2(240, 66)
	back.pressed.connect(close)
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(back)
	col.add_child(box)
	resized.connect(_fit)


## Fills the screen for hero `id` (cfg = the save) and shows it. Opened again while showing
## the same hero (after a look is worn), it keeps the tab and scroll.
func open_hero(cfg: ConfigFile, id: String) -> void:
	var again := visible and id == _id
	_id = id
	_level = HeroMastery.level(cfg, id)
	_base = Heroes.get_hero(id)
	_picks = HeroStyle.picks(cfg, id)
	_preview = _picks.duplicate()
	_frame = HeroMastery.has_frame(cfg, id)
	if not again:
		_slot = "outfit"
	visible = true
	_stage.set_active(true)
	var def := HeroStyle.dressed(_base, _picks)
	_title.text = "%s STYLE" % str(_base.title).to_upper()
	_title.label_settings.font_color = Color(def.ring).lightened(0.25)
	_show_preview()
	_show_tab(_slot, not again)
	_fit.call_deferred()


## Straight after a Mastery level: the hero shown wearing the best of that level's new
## looks (an outfit first, then headwear, a weapon, a glow), on that look's tab.
func show_new(lv: int) -> void:
	var news := HeroStyle.level_items(_id, lv)
	if news.is_empty():
		return
	var best: Dictionary = news[0]
	for slot: String in ["glow", "hold", "head", "outfit"]:
		for it: Dictionary in news:
			if it.slot == slot:
				best = it
	_preview = _picks.duplicate()
	for it: Dictionary in news:
		if it.slot != best.slot:
			_preview[it.slot] = it.key   # all of the level's looks at once, where they fit
	_preview[best.slot] = best.key
	_show_preview()
	_note.text = "NEW at level %d: %s  ·  tap a card to wear it" % [lv, ", ".join(news.map(func(it): return it.name))]
	_note.label_settings.font_color = Hud.GOLD
	_show_tab(best.slot, true)


func close() -> void:
	if not visible:
		return
	Sfx.play("click")
	visible = false
	_stage.set_active(false)
	closed.emit()


## Shrinks the pedestal on short screens so at least two rows of looks show.
func _fit() -> void:
	if not visible:
		return
	_stage_box.custom_minimum_size.y = clampf(size.y - 690.0 + STAGE_H, STAGE_MIN, STAGE_H)


func _show_preview() -> void:
	_stage.show_hero(HeroStyle.dressed(_base, _preview), _frame)
	for slot: String in HeroStyle.SLOTS:
		var key: String = _preview.get(slot, "")
		if key != _picks.get(slot, ""):
			var lv := HeroStyle.item_level(_id, slot, key)
			_note.text = "Trying on: %s  ·  Mastery level %d to wear it" % [HeroStyle.item_label(_id, slot, key), lv]
			_note.label_settings.font_color = Color(1.0, 0.72, 0.45)
			return
	var got := HeroStyle.items(_id).filter(func(it: Dictionary) -> bool: return it.key != "" and it.level <= _level).size()
	var all := HeroStyle.items(_id).size() - HeroStyle.SLOTS.size()
	_note.text = "Mastery level %d  ·  %d of %d looks unlocked" % [_level, got, all]
	_note.label_settings.font_color = Hud.GOLD


func _show_tab(slot: String, to_top := false) -> void:
	_slot = slot
	for k: String in _tabs:
		var b: Button = _tabs[k]
		var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		var on := k == slot
		sb.border_color = Hud.GOLD if on else Color(1, 0.8, 0.45, 0.35)
		sb.set_border_width_all(3 if on else 2)
		sb.bg_color = Color(0.24, 0.18, 0.1, 0.98) if on else Color(0.12, 0.1, 0.16, 0.9)
	var keep := _scroll.scroll_vertical
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for it: Dictionary in HeroStyle.items(_id):
		if it.slot == slot:
			_grid.add_child(_card(it))
	_scroll.scroll_vertical = 0 if to_top else keep
	if not to_top and keep > 0:
		_keep_scroll(keep)


## Back to where the list was once the new cards are laid out (until then the list is too
## short to scroll, so it would jump to the top whenever a look is tapped).
func _keep_scroll(to: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = to


func _card(it: Dictionary) -> Button:
	var got: bool = it.level <= _level
	var worn: bool = _picks.get(it.slot, "") == it.key
	var trying: bool = not worn and _preview.get(it.slot, "") == it.key
	var b := Hud.button("", 16, Color(0.13, 0.1, 0.17, 0.97) if got else Color(0.08, 0.07, 0.1, 0.95),
		Hud.GOLD if worn else (Color(1.0, 0.72, 0.45) if trying else (Color(1, 0.8, 0.45, 0.45) if got else Color(0.3, 0.28, 0.36))))
	b.custom_minimum_size = Vector2(0, 132)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(3 if worn or trying else 2)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hud.full(v)
	v.offset_top = 6
	v.offset_bottom = -6
	v.offset_left = 4
	v.offset_right = -4
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var sw := Swatch.new()
	sw.custom_minimum_size = Vector2(0, 58)
	sw.setup(_id, it.slot, it.key, _base)
	sw.modulate = Color.WHITE if got else Color(1, 1, 1, 0.45)
	v.add_child(sw)
	var name_l := Hud.label(it.name, 16, TEXT if got else DIM)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	var state := "WEARING" if worn else ("TAP TO WEAR" if got else "LEVEL %d" % it.level)
	v.add_child(Hud.label(state, 13, Hud.GOLD if worn else (Color(0.45, 0.85, 0.5) if got else DIM)))
	# The finger can drag the list from on top of a card (PASS lets the list see the drag),
	# and a card the list was dragged on isn't worn when the finger lifts.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.button_down.connect(func(): _down_at = _scroll.scroll_vertical)
	b.pressed.connect(func():
		if absi(_scroll.scroll_vertical - _down_at) <= 6:
			_tap(it))
	return b


func _tap(it: Dictionary) -> void:
	Sfx.play("click")
	var got: bool = it.level <= _level
	if got:
		if _picks.get(it.slot, "") != it.key:
			wear.emit(_id, it.slot, it.key)   # the game saves it and opens the screen again
		else:
			_preview = _picks.duplicate()
			_show_preview()
			_show_tab(_slot)
		return
	# A locked look: try it on.
	_preview = _picks.duplicate()
	_preview[it.slot] = it.key
	_show_preview()
	_show_tab(_slot)


## The little picture on a look's card: the outfit's colours, the glow's ring, or a simple
## drawing of the hat or weapon.
class Swatch extends Control:
	var slot := ""
	var key := ""
	var a := Color.WHITE
	var b := Color.WHITE
	var shape := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(id: String, s: String, k: String, base: Dictionary) -> void:
		slot = s
		key = k
		match s:
			"outfit":
				var o: Dictionary = HeroStyle.OUTFITS.get(k, {})
				a = o.get("a", HeroStyle.CLASSIC_OUTFIT.get(id, Color.GRAY))
				var bb = o.get("armor") if id == "knight" else (o.get("leather") if id == "rogue" else o.get("b"))
				b = bb if bb != null else HeroStyle.CLASSIC_TRIM.get(id, Color.GRAY)
			"glow":
				a = HeroStyle.GLOWS.get(k, {}).get("ring", base.ring)
			"head":
				shape = k if k != "" else {"rogue": "hood", "knight": "helm", "barbarian": "bear", "mage": "wizard"}.get(id, "hood")
			"hold":
				shape = k if k != "" else {"rogue": "crossbow", "knight": "sword_shield", "barbarian": "axe", "mage": "staff"}.get(id, "")
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		match slot:
			"outfit":
				draw_circle(c, r, b)
				# The cloth colour fills the top two thirds.
				var pts := PackedVector2Array()
				for i in 33:
					var t := PI * 0.85 + (TAU - PI * 0.7) * i / 32.0
					pts.append(c + Vector2(cos(t), sin(t)) * r)
				draw_colored_polygon(pts, a)
				draw_circle(c, r, Color(1, 1, 1, 0.35), false, 2.0, true)
			"glow":
				draw_circle(c, r, Color(a, 0.18))
				draw_circle(c, r * 0.72, a, false, r * 0.22, true)
				draw_circle(c, r * 0.72, Color(1, 1, 1, 0.6), false, 2.0, true)
			"head":
				_head(c, r)
			"hold":
				_hold(c, r)

	func _head(c: Vector2, r: float) -> void:
		var gold := Color(1.0, 0.8, 0.3)
		var steel := Color(0.72, 0.75, 0.82)
		var skin := Color(0.95, 0.72, 0.55)
		match shape:
			"crown":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.5), c + Vector2(-r, -r * 0.5), c + Vector2(-r * 0.5, 0),
					c + Vector2(0, -r * 0.7), c + Vector2(r * 0.5, 0), c + Vector2(r, -r * 0.5), c + Vector2(r, r * 0.5)]), gold)
				draw_circle(c + Vector2(0, r * 0.2), r * 0.16, Color(0.9, 0.2, 0.35))
			"halo":
				draw_circle(c + Vector2(0, r * 0.35), r * 0.55, skin)
				draw_arc(c + Vector2(0, -r * 0.55), r * 0.7, 0, TAU, 32, gold, r * 0.16, true)
			"horns", "horned_hat":
				draw_circle(c + Vector2(0, r * 0.25), r * 0.6, steel if shape == "horned_hat" else skin)
				for s in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([c + Vector2(s * r * 0.45, -r * 0.05), c + Vector2(s * r * 0.75, r * 0.15),
						c + Vector2(s * r * 1.0, -r * 0.9)]), Color(0.92, 0.88, 0.78))
			"wizard":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(r, r * 0.6), c + Vector2(r * 0.1, -r)]), Color(0.5, 0.4, 0.85))
				draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.25), Vector2(r, r * 0.22)), Color(0.95, 0.55, 0.25))
			"helm":
				draw_circle(c, r * 0.8, steel)
				draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.08), Vector2(r * 1.1, r * 0.18)), Color(0.15, 0.15, 0.2))
			"bear":
				for s in [-1.0, 1.0]:
					draw_circle(c + Vector2(s * r * 0.6, -r * 0.55), r * 0.28, Color(0.45, 0.32, 0.22))
				draw_circle(c, r * 0.75, Color(0.5, 0.36, 0.25))
				draw_circle(c + Vector2(0, r * 0.25), r * 0.25, Color(0.2, 0.15, 0.12))
			"bare":
				draw_circle(c, r * 0.75, skin)
			"hood":
				draw_circle(c, r * 0.8, Color(0.25, 0.45, 0.95))
				draw_circle(c + Vector2(0, r * 0.15), r * 0.48, skin)

	func _hold(c: Vector2, r: float) -> void:
		var steel := Color(0.78, 0.8, 0.86)
		var wood := Color(0.6, 0.4, 0.25)
		var parts := []
		match shape:
			"sword_shield":
				parts = ["sword", "shield"]
			"badge", "spike", "tower":
				parts = ["sword", shape]
			"twin_swords":
				parts = ["sword", "sword2"]
			"greatsword":
				parts = ["greatsword"]
			"axe":
				parts = ["axe"]
			"twin_axes":
				parts = ["axe", "axe2"]
			"axe_shield":
				parts = ["axe", "shield"]
			"great_axe":
				parts = ["great_axe"]
			"tankard":
				parts = ["axe", "mug"]
			"staff":
				parts = ["staff"]
			"wand":
				parts = ["wand"]
			"tome", "open_tome":
				parts = ["wand", shape]
			"crossbow", "heavy":
				parts = [shape]
			"knife":
				parts = ["crossbow", "knife"]
			"twin_knives":
				parts = ["knife2", "knife"]
		for p: String in parts:
			match p:
				"sword", "sword2":
					var o := c + Vector2(-r * 0.35 if p == "sword" else r * 0.35, 0)
					draw_line(o + Vector2(0, r * 0.8), o + Vector2(0, -r * 0.9), steel, r * 0.16)
					draw_line(o + Vector2(-r * 0.3, r * 0.4), o + Vector2(r * 0.3, r * 0.4), wood, r * 0.12)
				"greatsword":
					draw_line(c + Vector2(0, r), c + Vector2(0, -r), steel, r * 0.24)
					draw_line(c + Vector2(-r * 0.45, r * 0.5), c + Vector2(r * 0.45, r * 0.5), wood, r * 0.14)
				"shield", "badge", "spike", "tower":
					var o := c + Vector2(r * 0.35, r * 0.05)
					if p == "tower":
						draw_rect(Rect2(o - Vector2(r * 0.42, r * 0.7), Vector2(r * 0.84, r * 1.4)), steel)
					else:
						draw_circle(o, r * 0.55, steel)
						draw_circle(o, r * 0.2, Color(0.9, 0.3, 0.3) if p == "badge" else wood)
					if p == "spike":
						draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 0.12, -r * 0.1), o + Vector2(r * 0.12, -r * 0.1), o + Vector2(0, -r * 0.7)]), Color.WHITE)
				"axe", "axe2", "great_axe":
					var o := c + Vector2(-r * 0.35 if p != "axe2" else r * 0.35, 0)
					if p == "great_axe":
						o = c
					draw_line(o + Vector2(0, r * 0.9), o + Vector2(0, -r * 0.8), wood, r * 0.14)
					var w := r * (0.7 if p == "great_axe" else 0.45)
					draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r * 0.8), o + Vector2(w, -r * 0.95), o + Vector2(w, -r * 0.1), o + Vector2(0, -r * 0.3)]), steel)
					if p == "great_axe":
						draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r * 0.8), o + Vector2(-w, -r * 0.95), o + Vector2(-w, -r * 0.1), o + Vector2(0, -r * 0.3)]), steel)
				"mug":
					var o := c + Vector2(r * 0.4, r * 0.2)
					draw_rect(Rect2(o - Vector2(r * 0.3, r * 0.4), Vector2(r * 0.6, r * 0.8)), wood)
					draw_rect(Rect2(o - Vector2(r * 0.3, r * 0.5), Vector2(r * 0.6, r * 0.2)), Color(1, 1, 0.9))
				"staff":
					draw_line(c + Vector2(-r * 0.2, r), c + Vector2(r * 0.2, -r * 0.6), wood, r * 0.14)
					draw_circle(c + Vector2(r * 0.24, -r * 0.72), r * 0.26, Color(0.6, 1.0, 0.4))
				"wand":
					var o := c + Vector2(-r * 0.4, 0)
					draw_line(o + Vector2(0, r * 0.8), o + Vector2(0, -r * 0.6), wood, r * 0.1)
					draw_circle(o + Vector2(0, -r * 0.7), r * 0.16, Color(0.5, 0.9, 1.0))
				"tome", "open_tome":
					var o := c + Vector2(r * 0.35, 0)
					if p == "tome":
						draw_rect(Rect2(o - Vector2(r * 0.38, r * 0.5), Vector2(r * 0.76, r)), Color(0.7, 0.2, 0.3))
					else:
						draw_rect(Rect2(o - Vector2(r * 0.6, r * 0.38), Vector2(r * 1.2, r * 0.76)), Color(0.95, 0.92, 0.85))
						draw_line(o + Vector2(0, -r * 0.38), o + Vector2(0, r * 0.38), Color(0.6, 0.5, 0.4), 2.0)
				"crossbow", "heavy":
					var w := r * (1.0 if p == "heavy" else 0.75)
					draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, -r * 0.6), wood, r * 0.14)
					draw_arc(c + Vector2(0, -r * 0.1), w, PI * 1.15, PI * 1.85, 16, steel, r * 0.12, true)
				"knife", "knife2":
					var o := c + Vector2(r * 0.45 if p == "knife" else -r * 0.45, 0)
					draw_line(o + Vector2(0, r * 0.6), o + Vector2(0, -r * 0.5), steel, r * 0.14)
					draw_line(o + Vector2(-r * 0.18, r * 0.25), o + Vector2(r * 0.18, r * 0.25), wood, r * 0.1)
