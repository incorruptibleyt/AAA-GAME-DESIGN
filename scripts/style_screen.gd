class_name StyleScreen
extends ColorRect
## A hero's Style screen (from the Heroes and Mastery screens): the hero on a pedestal, and
## tabs of looks to dress them in (hero_style.gd): outfits, headwear, weapons, glows and Master auras.
## Tapping an unlocked look wears it straight away; tapping a locked one tries it on, so you
## can see what a Mastery level will bring, and says which level unlocks it.

signal wear(id: String, slot: String, key: String)
signal closed
signal get_pass   # GET THE CRYPT PASS, under a Crypt King look being tried on
signal feats      # the FEATS button: the Feats screen (feats_screen.gd)

const TABS := [["outfit", "OUTFIT"], ["head", "HEAD"], ["hold", "WEAPON"], ["glow", "GLOW"], ["aura", "AURA"]]
const TEXT := Color(0.88, 0.87, 0.92)
const DIM := Color(0.6, 0.58, 0.66)
const BAZAAR := Color(1.0, 0.62, 0.3)   # Bone Bazaar looks (version 152)
const RACE := Color(0.4, 0.92, 1.0)   # Crypt Race looks (version 153)
const ROAD := Color(1.0, 0.85, 0.55)   # the Bone Road's last prize (version 254)
## The pedestal's height; on short (16:9) screens it shrinks so the looks keep their room.
const STAGE_H := 300.0
const PIC_H := 92.0   # v340: a card's picture (was a 58 px drawn symbol)
const STAGE_MIN := 190.0

var _id := ""
var _level := 1
var _base: Dictionary = {}
var _picks: Dictionary = {}
var _preview: Dictionary = {}
var _frame := false
var _owned := false   # the Crypt Pass, which gives the Crypt King set
var _cfg: ConfigFile   # for Feat and Bone Drop looks (HeroStyle.has_look)
var _feats_btn: Button
var _pass_btn: Button
var _set_offer := false   # the button reads WEAR THE FULL CRYPT KING SET (a Pass owner wearing part of it)
var _slot := "outfit"
var _new := {}   # "slot/key" of the looks won since this hero's Style screen was last open
var _new_tab: Button
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
	Hud.backdrop(self, "keep")
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
	# Version 125 (audit #8): clear of a notch, camera hole or rounded corners.
	visibility_changed.connect(func(): if visible: Hud.safe_pad(col))
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
	MenuBackdrop.of(self).show_off(_stage_box, Vector2(0.5, 0.42), 0.86, 0.6)
	_note = Hud.label("", 16, Hud.GOLD)
	col.add_child(_note)
	_pass_btn = Hud.button("GET THE CRYPT PASS", 22, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_pass_btn.custom_minimum_size = Vector2(340, 60)
	_pass_btn.pressed.connect(func():
		Sfx.play("click")
		if _set_offer:
			wear.emit(_id, "set", HeroStyle.PASS_KEY)   # the whole Crypt King set at once
		else:
			get_pass.emit())
	_pass_btn.visible = false
	var pbox := CenterContainer.new()
	pbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbox.add_child(_pass_btn)
	col.add_child(pbox)
	var tabs := HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_theme_constant_override("separation", 6)
	col.add_child(tabs)
	# Version 185: a NEW tab, first in the row, while the hero has looks not yet seen. It
	# lists them all, whatever slot they are for.
	_new_tab = Hud.button("NEW", 17)
	_new_tab.custom_minimum_size = Vector2(0, 64)
	_new_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_tab.pressed.connect(func():
		Sfx.play("click")
		_show_tab("new", true))
	_new_tab.visible = false
	tabs.add_child(_new_tab)
	_tabs["new"] = _new_tab
	for t: Array in TABS:
		var b := Hud.button(t[1], 17)
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Sfx.play("click")
			_show_tab(t[0], true))
		tabs.add_child(b)
		_tabs[t[0]] = b
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(Hud.scroll_window(_scroll))   # version 227: the same window as the Armory
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	# Version 122: BACK bottom-left, the other action on the right, as on every screen.
	var back := Hud.button("BACK", 24)
	back.custom_minimum_size = Vector2(180, 72)
	back.pressed.connect(close)
	_feats_btn = Hud.button("FEATS", 22, Color(0.06, 0.2, 0.26, 0.97), Color(0.45, 0.95, 1.0))
	_feats_btn.custom_minimum_size = Vector2(200, 72)
	_feats_btn.pressed.connect(func():
		Sfx.play("click")
		feats.emit())
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	box.add_child(back)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	box.add_child(_feats_btn)
	col.add_child(box)
	resized.connect(_fit)


## Fills the screen for hero `id` (cfg = the save) and shows it. Opened again while showing
## the same hero (after a look is worn), it keeps the tab and scroll.
func hero_id() -> String:
	return _id


## "FEATS 7/20", or "FEATS NEW!" until the Feats screen has been opened.
func refresh_feats_button() -> void:
	var cfg := Game._load_save()
	var nf := Feats.count(cfg)
	_feats_btn.text = "FEATS  %d/%d" % [nf, Feats.LIST.size()]
	if bool(cfg.get_value(Feats.SECTION, "new", false)):
		_feats_btn.text = "FEATS  NEW!"


func open_hero(cfg: ConfigFile, id: String) -> void:
	var again := visible and id == _id
	_id = id
	_level = HeroMastery.level(cfg, id)
	_base = Heroes.get_hero(id)
	_picks = HeroStyle.picks(cfg, id)
	_preview = _picks.duplicate()
	_frame = HeroMastery.has_frame(cfg, id)
	_owned = Store.owned(cfg)
	_cfg = cfg
	refresh_feats_button()
	if not again:
		_new = {}
	# (Version 186: also when the screen opens again while showing, so a look won with it
	# open, such as the Crypt King set bought from here, gets its NEW tag too.)
	for it: Dictionary in HeroStyle.new_looks(cfg, id):
		_new["%s/%s" % [it.slot, it.key]] = true
	if not again:
		_slot = "new" if not _new.is_empty() else "outfit"
	_new_tab.visible = not _new.is_empty()
	_new_tab.text = "NEW\n%d" % _new.size()
	# Six tabs fit the row at a smaller size; a slot with new looks has a gold name.
	for k: String in _tabs:
		var n := 0
		for nk: String in _new:
			if nk.begins_with(k + "/"):
				n += 1
		var tb: Button = _tabs[k]
		tb.add_theme_font_size_override("font_size", 16 if _new_tab.visible else 19)   # v221: 16 px at least (was 15)
		tb.set_meta("fresh", n > 0 or k == "new")
	visible = true
	_stage.set_active(true)
	var def := HeroStyle.dressed(_base, _picks)
	_title.text = "%s STYLE" % str(_base.title).to_upper()
	MenuBackdrop.of(self).set_key(HeroScreen._light(Color(def.ring)), not again)
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
	for slot: String in ["glow", "hold", "head", "outfit", "aura"]:
		for it: Dictionary in news:
			if it.slot == slot:
				best = it
	_preview = _picks.duplicate()
	for it: Dictionary in news:
		if it.slot != best.slot:
			_preview[it.slot] = it.key   # all of the level's looks at once, where they fit
	_preview[best.slot] = best.key
	_show_preview()
	_stage.reveal(best.slot)
	_note.text = "NEW at level %d: %s  ·  tap a card to wear it" % [lv, ", ".join(news.map(func(it): return it.name))]
	_note.label_settings.font_color = Hud.GOLD
	_show_tab("new" if not _new.is_empty() else best.slot, true)


func set_note(text: String) -> void:
	_note.text = text
	_note.label_settings.font_color = Color(0.6, 1.0, 0.65)


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
	_stage.show_hero(HeroStyle.dressed(_base, _preview), _frame, HeroMastery.frame_color(_level))
	_pass_btn.visible = false
	# Version 176: a Pass owner wearing some of the Crypt King set, but not all of it, gets
	# one button that puts on the rest.
	var worn_set := 0
	for slot: String in HeroStyle.PASS_SLOTS:
		if _picks.get(slot, "") == HeroStyle.pass_key(slot):
			worn_set += 1
	_set_offer = _owned and worn_set > 0 and worn_set < HeroStyle.PASS_SLOTS.size()
	_pass_btn.text = "WEAR THE FULL CRYPT KING SET" if _set_offer else "GET THE CRYPT PASS"
	_pass_btn.visible = _set_offer
	for slot: String in HeroStyle.SLOTS:
		var key: String = _preview.get(slot, "")
		if key != _picks.get(slot, ""):
			if HeroStyle.is_pass(key):
				_note.text = "Trying on: the Crypt King set  ·  only with the Crypt Pass"
				_note.label_settings.font_color = Hud.GOLD
				_pass_btn.visible = not _owned
				return
			var x := HeroStyle.extra(slot, key)
			if x.has("feat"):
				_note.text = "Trying on: %s  ·  Feat: %s" % [HeroStyle.item_label(_id, slot, key), Feats.get_feat(x.feat).text]
				_note.label_settings.font_color = Color(0.5, 0.95, 1.0)
				return
			if x.has("event"):
				# (Version 244: in the words of the look's own event, Blood Moon or Frostfall.)
				var e := Events.by_id(str(x.event))
				var how := "%s set: win it on the event road" % str(e.name).capitalize()
				if x.get("hunt", false):
					how = "%s: beat the %s's %s tier" % [str(e.name).capitalize(), Events.word("hunt", e), str(Events.tiers(e)[-1].name)]
				elif x.get("passroad", false):
					how = "%s: the event road's Crypt Pass row" % Events.word("pass_set", e)
				_note.text = "Trying on: %s  ·  %s" % [HeroStyle.item_label(_id, slot, key), how]
				_note.label_settings.font_color = (e.color as Color).lerp(Color.WHITE, 0.25)
				return
			if x.has("road"):
				_note.text = "Trying on: %s  ·  the Bone Road's last prize, at %s bones" % [HeroStyle.item_label(_id, slot, key), Hud.thousands(int(BoneRoad.STEPS[-1].at))]
				_note.label_settings.font_color = ROAD
				return
			if x.has("race"):
				_note.text = "Trying on: %s  ·  Crypt Race: Race Road at %d trophies" % [HeroStyle.item_label(_id, slot, key), int(x.race)]
				_note.label_settings.font_color = RACE
				return
			if x.has("bazaar"):
				_note.text = "Trying on: %s  ·  sometimes sold in the Bone Bazaar (Armory)" % HeroStyle.item_label(_id, slot, key)
				_note.label_settings.font_color = BAZAAR
				return
			if x.has("drop"):
				_note.text = "Trying on: %s  ·  found in %s Bone Drops or the Bazaar" % [HeroStyle.item_label(_id, slot, key), str(Drops.TIERS[int(x.drop)].name).capitalize()]
				_note.label_settings.font_color = Drops.TIERS[int(x.drop)].color.lightened(0.3)
				return
			var lv := HeroStyle.item_level(_id, slot, key)
			_note.text = "Trying on: %s  ·  Mastery level %d to wear it" % [HeroStyle.item_label(_id, slot, key), lv]
			_note.label_settings.font_color = Color(1.0, 0.72, 0.45)
			return
	var mastery := HeroStyle.items(_id).filter(func(it: Dictionary) -> bool: return HeroStyle.is_mastery(it))
	var got := mastery.filter(func(it: Dictionary) -> bool: return it.level <= _level).size()
	var all := mastery.size()
	# ("Mastery looks": Feat, Bone Drop, Bazaar and Pass looks are not in this count, and
	# "40 of 40 looks unlocked" stood over locked cards.)
	_note.text = "Mastery level %d  ·  %d of %d Mastery looks" % [_level, got, all]
	if not _new.is_empty():
		_note.text = "%d NEW %s!  Tap one to wear it" % [_new.size(), "LOOK" if _new.size() == 1 else "LOOKS"]
	_note.label_settings.font_color = Hud.GOLD


func _show_tab(slot: String, to_top := false) -> void:
	_slot = slot
	for k: String in _tabs:
		var b: Button = _tabs[k]
		Hud.paint(b, "gold" if k == slot else "slate")
		# A tab holding new looks has a gold name (every state's colour: Hud.button sets them all).
		var ink := Hud.GOLD if k != slot and b.get_meta("fresh", false) else Color.WHITE
		for c in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, ink)
	var keep := _scroll.scroll_vertical
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	# Version 121: the looks you own first (worn among them, so wearing one never moves the
	# cards), then the Crypt King set, then Feat and Bone Drop looks to try on, then the
	# Mastery looks still locked. Before, eight locked cards sat above an owned one.
	# Blood Moon looks show while the event is on (or coming), and for good once won.
	var event_on := Events.active() or not Events.coming().is_empty()
	var list := HeroStyle.items(_id).filter(func(it: Dictionary) -> bool:
		if slot == "new":
			return _is_new(it)
		return it.slot == slot and (not it.has("event") or (event_on and str(it.event) == str(Events.ev().id)) or _got(it)))
	var order := {}
	for i in list.size():
		var it: Dictionary = list[i]
		var rank := 3
		if _is_new(it):
			rank = -1   # new looks first on their own slot's tab too
		elif _got(it):
			rank = 0
		elif it.get("pass", false):
			rank = 1
		elif HeroStyle.is_special(it):
			rank = 2
		order[it.key] = rank * 1000 + i
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return order[x.key] < order[y.key])
	for it: Dictionary in list:
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


func _is_new(it: Dictionary) -> bool:
	return it.key != "" and _new.has("%s/%s" % [it.slot, it.key])


func _got(it: Dictionary) -> bool:
	if HeroStyle.is_special(it):
		return _cfg != null and HeroStyle.has_look(_cfg, _id, it.slot, it.key)
	return _owned if it.get("pass", false) else it.level <= _level


func _card(it: Dictionary) -> Button:
	var got := _got(it)
	var paid: bool = it.get("pass", false)
	var worn: bool = _picks.get(it.slot, "") == it.key
	var trying: bool = not worn and _preview.get(it.slot, "") == it.key
	var bg := Color(0.13, 0.1, 0.17, 0.97) if got else Color(0.08, 0.07, 0.1, 0.95)
	var edge := Hud.GOLD if worn else (Color(1.0, 0.72, 0.45) if trying else (Color(1, 0.8, 0.45, 0.45) if got else Color(0.3, 0.28, 0.36)))
	if paid:
		bg = Color(0.24, 0.16, 0.04, 0.98)   # the Crypt King looks: gold cards, always bright
		edge = Hud.GOLD if worn or trying else Color(1.0, 0.8, 0.35, 0.8)
	var b := Hud.button("", 16, bg, edge)
	b.custom_minimum_size = Vector2(0, 180)   # room for the picture and three tag lines (v121, v340)
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
	var fresh := _is_new(it)
	if fresh:
		# A gold NEW tag on the corner, and which slot it is for (the NEW tab mixes them).
		var tag := Hud.label("NEW", 14, Color(0.1, 0.06, 0.02))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Hud.GOLD
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		tag.add_theme_stylebox_override("normal", sb)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.position = Vector2(6, 6)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
		if not worn and not trying:
			(b.get_theme_stylebox("normal") as StyleBoxFlat).border_color = Hud.GOLD
	var sw := Swatch.new()
	sw.custom_minimum_size = Vector2(0, PIC_H)
	sw.pic_grow = Vector2(12, 6)   # the picture reaches up under the NEW tag's row
	sw.setup(_id, it.slot, it.key, _base)
	# (Special looks stay bright when locked: they are what the player is working toward.)
	# v375: a look not owned yet is its real picture, darker, with a padlock (a Crypt King
	# look keeps all its light: its gold card is the offer).
	if not got:
		sw.set_locked(true, 1.0 if paid else (0.85 if HeroStyle.is_special(it) else 0.5))
	v.add_child(sw)
	var name_l := Hud.label(it.name, 16, Color(1.0, 0.9, 0.6) if paid else (TEXT if got or HeroStyle.is_special(it) else DIM))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_l)
	if _slot == "new":
		for t: Array in TABS:
			if t[0] == it.slot:
				v.add_child(Hud.label(str(t[1]), 13, DIM))
	if it.get("only", false):
		# A Master aura: only this hero has it.
		v.add_child(Hud.label("%s ONLY" % str(_base.title).to_upper(), 14, Color(_base.ring).lightened(0.3) if got else DIM))
	if paid:
		v.add_child(Hud.label("CRYPT PASS", 14, Hud.GOLD))
	var special: bool = HeroStyle.is_special(it)
	if it.has("event"):
		if HeroStyle.extra(it.slot, it.key).get("passroad", false):
			v.add_child(Hud.label("PASS · EVENT", 14, Color(0.8, 0.88, 1.0)))
		else:
			var ev := Events.by_id(str(it.event))
			v.add_child(Hud.label(str(ev.name), 14, (ev.color as Color).lerp(Color.WHITE, 0.2)))
	elif it.has("feat"):
		v.add_child(Hud.label("FEAT", 14, Color(0.5, 0.95, 1.0)))
	elif it.has("drop"):
		v.add_child(Hud.label("BONE DROP", 14, Drops.TIERS[int(it.drop)].color.lightened(0.2)))
	elif it.has("bazaar"):
		# With its price (version 175), so the player knows what to save for.
		v.add_child(Hud.label("BAZAAR" if got else "BAZAAR  ·  %d" % int(it.bazaar), 14, BAZAAR))
	elif it.has("race"):
		v.add_child(Hud.label("CRYPT RACE", 14, RACE))
	elif it.has("road"):
		v.add_child(Hud.label("BONE ROAD", 14, ROAD))
	var state := "WEARING" if worn else ("TAP TO WEAR" if got else ("TAP TO TRY ON" if paid or special else "LEVEL %d" % it.level))
	v.add_child(Hud.label(state, 15, Hud.GOLD if worn else (Color(0.45, 0.85, 0.5) if got else (Color(1.0, 0.8, 0.5) if paid else DIM))))
	# Version 226: a card with more lines than fit grows taller instead of letting the last
	# line fall out below it (a long name on two lines, or several tags).
	v.minimum_size_changed.connect(func():
		b.custom_minimum_size.y = maxf(180.0, v.get_combined_minimum_size().y + 12.0))
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
	var got := _got(it)
	if got:
		if _picks.get(it.slot, "") != it.key:
			wear.emit(_id, it.slot, it.key)   # the game saves it and opens the screen again
		else:
			_preview = _picks.duplicate()
			_show_preview()
			_show_tab(_slot)
		return
	# A locked look: try it on. A Crypt King look is tried on as the whole set.
	_preview = _picks.duplicate()
	if it.get("pass", false):
		for slot: String in HeroStyle.PASS_SLOTS:
			_preview[slot] = HeroStyle.pass_key(slot)
	_preview[it.slot] = it.key
	_show_preview()
	_stage.reveal(it.slot, true)   # version 131: a quick show-off of the look tried on
	_show_tab(_slot)


## The little picture on a look's card: the outfit's colours, the glow's ring, or a simple
## drawing of the hat or weapon.
## Version 375: the padlock on a look (or a prize) not owned yet: a gold lock on a dark
## round badge with an ink edge, drawn to fill this control.
class Padlock extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(22, 22)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, r * 0.12), r, Color(0, 0, 0, 0.4))
		draw_circle(c, r, Hud.INK)
		draw_circle(c, r - 2.0, Color(0.17, 0.13, 0.25))
		draw_arc(c, r - 2.0, 0.0, TAU, 28, Color(1.0, 0.82, 0.5, 0.55), 1.2, true)
		var steel := Color(0.86, 0.87, 0.95)
		var gold := Color(1.0, 0.78, 0.3)
		# the shackle: two legs and the bow over them
		var sw := r * 0.3
		var top := c + Vector2(0, -r * 0.22)
		draw_arc(top, sw, PI, TAU, 12, steel, r * 0.17, true)
		for sx: float in [-1.0, 1.0]:
			draw_line(top + Vector2(sx * sw, 0), top + Vector2(sx * sw, r * 0.24), steel, r * 0.17, true)
		# the body, with a darker lip and a keyhole
		var body := Rect2(c + Vector2(-r * 0.5, -r * 0.06), Vector2(r, r * 0.66))
		var sb := StyleBoxFlat.new()
		sb.bg_color = gold
		sb.border_color = gold.darkened(0.35)
		sb.border_width_bottom = maxi(1, roundi(r * 0.12))
		sb.set_corner_radius_all(maxi(2, roundi(r * 0.16)))
		sb.anti_aliasing_size = 1.0
		draw_style_box(sb, body)
		var kc := body.get_center() + Vector2(0, -r * 0.05)
		draw_circle(kc, r * 0.11, Hud.INK)
		draw_line(kc, kc + Vector2(0, r * 0.2), Hud.INK, r * 0.1, true)


class Swatch extends Control:
	var slot := ""
	var key := ""
	var a := Color.WHITE
	var b := Color.WHITE
	var shape := ""
	var aura := {}
	var shine := false   # a Crypt King look: a glint runs across its picture
	var pat := 0   # a Feat or drop outfit's pattern, drawn on its swatch
	var finish := ""   # a weapon finish (gold, frost, ember, void)
	var forged := false   # v229: a non-Mage forged, gilded or void weapon's own shape is drawn on it
	var tier := 0   # how grand a glow's ring is (HeroStyle.glow_tier)
	var fx := ""   # a glow's ring shape (flame, frost, storm, stars, runes)
	var a2 = null   # a Legend road glow's second colour (it shimmers between the two)
	var picture := false   # v340: a real picture of the look covers this; draw only a soft spot under it
	var _t := 0.0
	var _dim := Color.WHITE   # v375: a look not owned yet is darker (set_locked)
	var _lock: Padlock

	## Version 375 (visual review of 366, fix 8): a look not owned yet keeps its real picture,
	## darker and cooler, with a padlock on its corner. It was faded to half see-through
	## before, which read as a ghost of the look and let the card show through it.
	## `bright`: how much of its light it keeps (1 = as an owned one, only the padlock).
	func set_locked(on: bool, bright := 0.5) -> void:
		_dim = Color(bright, bright * 0.97, minf(1.0, bright * 1.12)) if on else Color.WHITE
		modulate = Color.WHITE
		self_modulate = _dim
		if _pic:
			_pic.modulate = _dim
		if on and _lock == null:
			_lock = Padlock.new()
			add_child(_lock)
			resized.connect(_place_lock)
		if _lock:
			_lock.visible = on
			_place_lock()

	func _place_lock() -> void:
		if _lock == null:
			return
		var r := minf(size.x, size.y + pic_grow.x + pic_grow.y) * 0.5
		var d := clampf(r * 0.46, 20.0, 28.0)
		_lock.size = Vector2(d, d)
		# (v407: out in the corner, off the prize: it sat on the weapon it locked)
		_lock.position = size * 0.5 + Vector2(r * 0.88, r * 0.66) - _lock.size * 0.5
		move_child(_lock, -1)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(id: String, s: String, k: String, base: Dictionary) -> void:
		slot = s
		key = k
		match s:
			"outfit" when HeroStyle.is_pass(k):
				var on: String = HeroStyle.PASS_OUTFIT.gold_on.get(id, "a")
				a = HeroStyle.PASS_OUTFIT.gold if on == "a" else HeroStyle.PASS_OUTFIT.obsidian
				b = HeroStyle.PASS_OUTFIT.gold if on == "b" else HeroStyle.PASS_OUTFIT.obsidian
				shine = true
			"outfit" when not HeroStyle.extra(s, k).is_empty():
				a = HeroStyle.extra(s, k).a
				b = HeroStyle.extra(s, k).b
				pat = int(HeroStyle.extra(s, k).get("pat", 0))
				shape = "pattern"
			"outfit":
				var o: Dictionary = HeroStyle.OUTFITS.get(k, {})
				a = o.get("a", HeroStyle.CLASSIC_OUTFIT.get(id, Color.GRAY))
				var bb = o.get("armor") if id == "knight" else (o.get("leather") if id == "rogue" else o.get("b"))
				b = bb if bb != null else HeroStyle.CLASSIC_TRIM.get(id, Color.GRAY)
				pat = int(o.get("pat", 0))   # the Legend road outfits (Diamond, Mythic, Legend)
				if pat > 0:
					shape = "pattern"
			"glow":
				var gl: Dictionary = HeroStyle.PASS_GLOW if HeroStyle.is_pass(k) else HeroStyle.GLOWS.get(k, HeroStyle.extra(s, k))
				a = gl.get("ring", base.ring)
				b = gl.get("bolt", a)
				a2 = gl.get("ring2")
				fx = str(gl.get("fx", ""))
				tier = HeroStyle.glow_tier(gl)
				shine = HeroStyle.is_pass(k)
			"aura":
				aura = HeroStyle.PASS_AURA if HeroStyle.is_pass(k) else HeroStyle.AURAS.get(id, {}).get(k, HeroStyle.extra(s, k))
				a = aura.get("ink", Color(0.35, 0.32, 0.4))
				b = aura.get("spark", Color(0.5, 0.48, 0.55))
			"head":
				shape = k if k != "" else {"rogue": "hood", "knight": "helm", "barbarian": "bear", "mage": "wizard"}.get(id, "hood")
			"hold":
				shape = k if k != "" else {"rogue": "crossbow", "knight": "sword_shield", "barbarian": "axe", "mage": "staff"}.get(id, "")
				# A weapon finish (version 172): the weapon it is worn on, in the finish's colours.
				var h: Dictionary = HeroStyle.HOLDS.get(id, {}).get(k, HeroStyle.extra(s, k))
				if HeroStyle.is_pass(k):
					h = HeroStyle.PASS_HOLD
					shine = true
				finish = str(h.get("finish", ""))
				if finish != "":
					var grand := {"rogue": "heavy", "knight": "greatsword", "barbarian": "great_axe", "mage": "staff"}
					var by := {"frostforged": {"rogue": "heavy", "knight": "badge", "barbarian": "twin_axes", "mage": "staff"},
						"emberforged": {"rogue": "twin_knives", "knight": "greatsword", "barbarian": "great_axe", "mage": "open_tome"}}
					shape = str(by.get(k, grand).get(id, ""))
					# v228: the Mage's forged, gilded and void weapons have their own shapes (ForgedArms).
					if id == "mage":
						shape = str({"frost": "ice_staff", "gold": "sun_staff", "void": "scythe", "ember": "fire_tome", "crypt": "king_staff"}.get(finish, shape))
					else:
						forged = finish in ["frost", "ember", "gold", "void"]   # (ForgedArms, v229)
					# v230: the Knight's and Barbarian's grand looks are whole new weapons.
					if shape == "greatsword":
						shape = str({"ember": "magma_cleaver", "gold": "sun_hammer", "void": "rift_blade", "crypt": "king_blade"}.get(finish, shape))
					elif shape == "great_axe":
						shape = str({"ember": "magma_maul", "gold": "ram_mace", "void": "moon_axe", "crypt": "king_axe"}.get(finish, shape))
					elif shape == "heavy" and finish == "crypt":
						shape = "king_bow"   # (v253: the Crypt King's arms are whole weapons, CryptArms)
		queue_redraw()
		_ask_picture(id)

	## Version 340-341 (visual review fix 5): a real 3D picture of the look (LookShots) over
	## the drawn symbol, wherever a look is shown: Style cards, the event road, Feats, the
	## Bone Bazaar. The symbol shows until the picture is ready, or if it can't be taken.
	## `pic_grow`: extra room the picture may use above (x) and below (y) the swatch.
	var pic_grow := Vector2.ZERO
	var _pic: TextureRect
	var _asked := ""

	func _ask_picture(id: String) -> void:
		if id == "":
			return
		if _pic == null:
			_pic = TextureRect.new()
			_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_pic.material = HeroStage._see_through()
			_pic.modulate = _dim
			add_child(_pic)
			_place_lock()
		_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pic.offset_top = -pic_grow.x
		_pic.offset_bottom = pic_grow.y
		_pic.offset_left = 0
		_pic.offset_right = 0
		_pic.texture = null
		picture = false
		var me := LookShots.shot_key(id, slot, key)
		_asked = me
		LookShots.want(id, slot, key, func(tex: Texture2D):
			if _asked == me and _pic:
				_pic.texture = tex
				picture = true
				set_process(false)
				queue_redraw())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		if picture:
			# Under the picture: a soft round spot of light in the look's own colour.
			var tint := a if slot in ["outfit", "glow", "aura"] else Color(0.75, 0.7, 0.9)
			for i in 6:
				var k := 1.0 - i / 6.0
				draw_circle(c + Vector2(0, 4), r * (0.55 + 0.6 * k), Color(tint, 0.05))
			return
		match slot:
			"outfit":
				draw_circle(c, r, b)
				# The cloth colour fills the top two thirds.
				var pts := PackedVector2Array()
				for i in 33:
					var t := PI * 0.85 + (TAU - PI * 0.7) * i / 32.0
					pts.append(c + Vector2(cos(t), sin(t)) * r)
				draw_colored_polygon(pts, a)
				# A brighter rim on very dark outfits (Shadow, Midnight) so they don't vanish on the card.
				var rim := 0.7 if a.get_luminance() < 0.2 else 0.35
				draw_circle(c, r, Color(1, 1, 1, rim), false, 2.0, true)
				if shape == "pattern":
					_pattern(c, r)
			"glow":
				draw_circle(c, r, Color(a, 0.18))
				draw_circle(c, r * 0.72, a, false, r * 0.22, true)
				if a2 != null:
					# The second colour runs round the ring, as it shimmers on the hero.
					var at := _t * 1.6
					draw_arc(c, r * 0.72, at, at + PI * 0.9, 20, a2, r * 0.22, true)
				draw_circle(c, r * 0.72, Color(1, 1, 1, 0.6), false, 2.0, true)
				if b != a:
					# Its shots' colour, when they differ from the ring.
					draw_circle(c, r * 0.3, b)
				_ring_marks(c, r)
			"aura":
				_aura(c, r)
			"head":
				_head(c, r)
			"hold":
				_hold(c, r)
		if shine or shape == "crypt_crown" or aura.get("sigil", false):
			_glint(c, r)

	## A glow's ring shape in small (version 173), as LookFx.ring draws it at the hero's feet:
	## flames, ice crystals, lightning, stars or runes round the ring.
	func _ring_marks(c: Vector2, r: float) -> void:
		var lit: Color = (a2 if a2 != null else a).lerp(Color.WHITE, 0.45)
		var r0 := r * 0.86
		if tier >= 1:
			draw_circle(c, r * 0.5, Color(lit, 0.8), false, 1.5, true)
		if tier >= 2:
			for i in 4:
				var t := TAU * i / 4.0 + _t * 0.5
				draw_arc(c, r * 1.12, t, t + 0.8, 6, Color(lit, 0.9), 2.0, true)
		match fx:
			"rays", "crown":
				var n := 12 if fx == "rays" else 8
				for i in n:
					var t := TAU * i / n + _t * 0.15
					var out := Vector2(cos(t), sin(t))
					var side := Vector2(-out.y, out.x)
					var h := r * (0.2 if fx == "rays" else 0.3)
					draw_colored_polygon(PackedVector2Array([c + out * r0 - side * r * 0.08, c + out * (r0 + h), c + out * r0 + side * r * 0.08]), Color(lit, 0.95))
					if fx == "crown":
						draw_circle(c + out * (r0 + h), r * 0.05, Color.WHITE)
			"beads":
				for i in 10:
					var t := TAU * i / 10.0 + _t * 0.5
					draw_circle(c + Vector2(cos(t), sin(t)) * (r0 + r * 0.12), r * 0.06 * (0.7 + 0.3 * sin(_t * 3.0 - i * 1.26)), lit)
			"wave":
				var pts := PackedVector2Array()
				for i in 49:
					var t := TAU * i / 48.0
					pts.append(c + Vector2(cos(t), sin(t)) * (r0 + r * (0.12 + 0.06 * sin(t * 8.0 + _t * 3.0))))
				draw_polyline(pts, lit, 2.0, true)
			"eclipse":
				var t0 := _t * 0.8
				for i in 12:
					var t := t0 - 1.1 + 2.2 * i / 11.0
					var k := cos((t - t0) * 0.7)
					draw_circle(c + Vector2(cos(t), sin(t)) * (r0 + r * 0.08 * k), r * 0.1 * k * k, lit)
			"flame":
				for i in 8:
					var t := TAU * i / 8.0
					var out := Vector2(cos(t), sin(t))
					var side := Vector2(-out.y, out.x)
					var h := r * (0.2 + 0.1 * sin(_t * 5.0 + i * 2.3))
					draw_colored_polygon(PackedVector2Array([c + out * r0 - side * r * 0.11, c + out * (r0 + h) + side * r * 0.05, c + out * r0 + side * r * 0.11]), Color(lit, 0.95))
			"frost":
				for i in 8:
					var t := TAU * i / 8.0 + PI / 8.0
					var out := Vector2(cos(t), sin(t))
					var side := Vector2(-out.y, out.x)
					var h := r * (0.26 if i % 2 == 0 else 0.15)
					draw_colored_polygon(PackedVector2Array([c + out * r0 - side * r * 0.06, c + out * (r0 + h), c + out * r0 + side * r * 0.06]), Color(1, 1, 1, 0.75 + 0.25 * sin(_t * 2.6 + i * 1.7)))
			"storm":
				for i in 3:
					var t0 := TAU * i / 3.0 + floorf(_t * 6.0) * 0.9
					var pts := PackedVector2Array()
					for j in 6:
						var t := t0 + j * 0.16
						pts.append(c + Vector2(cos(t), sin(t)) * (r0 + r * (0.16 if j % 2 == 0 else 0.04)))
					draw_polyline(pts, lit, 2.0, true)
			"stars":
				for i in 6:
					var t := TAU * i / 6.0 + _t * 0.4
					var at := c + Vector2(cos(t), sin(t)) * (r0 + r * 0.1)
					var k := r * 0.12 * (0.6 + 0.4 * sin(_t * 4.0 + i * 2.1))
					draw_line(at - Vector2(k, 0), at + Vector2(k, 0), lit, 2.0, true)
					draw_line(at - Vector2(0, k), at + Vector2(0, k), lit, 2.0, true)
			"runes":
				for i in 10:
					var t := TAU * i / 10.0 - _t * 0.3
					draw_arc(c, r0 + r * 0.12, t, t + (0.14 if i % 3 else 0.3), 4, Color(lit, 0.9), 2.5, true)
			"snowflake":   # Frostfall (v244): six little snowflakes turning round the ring
				for i in 6:
					var t := TAU * i / 6.0 + _t * 0.3
					var at := c + Vector2(cos(t), sin(t)) * (r0 + r * 0.12)
					for k in 3:
						var ang := _t * 1.2 + k * PI / 3.0 + i
						var d := Vector2(cos(ang), sin(ang)) * r * 0.12
						draw_line(at - d, at + d, Color.WHITE, 1.6, true)
			"aurora":   # curtains of light hanging off the ring, green to violet
				for i in 16:
					var t := TAU * i / 16.0 + _t * 0.12
					var out := Vector2(cos(t), sin(t))
					var h := r * (0.12 + 0.12 * (0.5 + 0.5 * sin(_t * 1.3 + i * 1.7)))
					draw_line(c + out * r0, c + out * (r0 + h), Color(0.4, 1.0, 0.65, 0.85), r * 0.1, true)
					draw_line(c + out * (r0 + h * 0.6), c + out * (r0 + h), Color(0.72, 0.48, 1.0, 0.8), r * 0.1, true)
			"whirl":   # a blizzard whirling round the ring
				for i in 5:
					var t0 := TAU * i / 5.0 - _t * 1.6
					var pts := PackedVector2Array()
					for j in 8:
						var t := t0 + j * 0.12
						pts.append(c + Vector2(cos(t), sin(t)) * (r0 + r * (0.22 - j * 0.022)))
					draw_polyline(pts, Color(1, 1, 1, 0.9), 2.0, true)

	## A Feat or drop outfit's own pattern in small (version 116: they all showed the same
	## glints, so the swatches looked alike): wisps, cracks, stars, facets, lightning,
	## runes, flames, bubbles, colour bands or deep-sea lights.
	func _pattern(c: Vector2, r: float) -> void:
		var lit := b.lerp(Color.WHITE, 0.55)
		var pulse := 0.6 + 0.4 * sin(_t * 3.0)
		match pat:
			1:   # Ghostwalk: wisps rising
				for i in 3:
					var x := c.x + (i - 1) * r * 0.42
					var y0 := c.y + r * 0.5 - fmod(_t * 18.0 + i * 13.0, r * 1.1)
					draw_line(Vector2(x, y0), Vector2(x + sin(_t * 2.0 + i) * r * 0.1, y0 - r * 0.35), Color(lit, 0.8 * pulse), r * 0.12, true)
			2:   # Cinder Ice: cracks
				var pts := PackedVector2Array([c + Vector2(-0.7, -0.2) * r, c + Vector2(-0.3, 0.1) * r, c + Vector2(0.05, -0.25) * r,
					c + Vector2(0.35, 0.2) * r, c + Vector2(0.7, -0.05) * r])
				draw_polyline(pts, Color(lit, pulse), r * 0.1, true)
				draw_line(c + Vector2(-0.3, 0.1) * r, c + Vector2(-0.2, 0.55) * r, Color(lit, pulse * 0.8), r * 0.07, true)
			3:   # Starweave: stars
				for i in 5:
					var p := c + Vector2(cos(i * 2.4) * 0.55, sin(i * 2.4) * 0.5 - 0.1) * r
					var tw := 0.5 + 0.5 * sin(_t * 4.0 + i * 1.9)
					draw_line(p - Vector2(r * 0.12, 0), p + Vector2(r * 0.12, 0), Color(lit, tw), 2.0, true)
					draw_line(p - Vector2(0, r * 0.12), p + Vector2(0, r * 0.12), Color(lit, tw), 2.0, true)
			4:   # Frostbite: a diamond lattice
				for i in 3:
					var x := c.x + (i - 1) * r * 0.5
					draw_line(Vector2(x - r * 0.3, c.y - r * 0.5), Vector2(x + r * 0.3, c.y + r * 0.3), Color(lit, 0.7), 2.0, true)
					draw_line(Vector2(x + r * 0.3, c.y - r * 0.5), Vector2(x - r * 0.3, c.y + r * 0.3), Color(lit, 0.7), 2.0, true)
			5:   # Thunder: a bolt
				var flash := pow(maxf(0.0, sin(_t * 3.3)), 6.0)
				var pts := PackedVector2Array([c + Vector2(0.15, -0.7) * r, c + Vector2(-0.2, -0.05) * r, c + Vector2(0.12, -0.02) * r, c + Vector2(-0.15, 0.6) * r])
				draw_polyline(pts, Color(lit, 0.6 + 0.4 * flash), r * 0.14, true)
			6:   # Bonecarved: carved bands with strokes
				for i in 2:
					var y := c.y + (i - 0.5) * r * 0.6
					draw_line(Vector2(c.x - r * 0.7, y), Vector2(c.x + r * 0.7, y), Color(lit, pulse), r * 0.09, true)
					for j in 4:
						var x := c.x + (j - 1.5) * r * 0.32
						draw_line(Vector2(x, y - r * 0.14), Vector2(x, y + r * 0.14), Color(lit, pulse), r * 0.06, true)
			7:   # Shadowflame: flames
				for i in 3:
					var x := c.x + (i - 1) * r * 0.45
					var h := r * (0.5 + 0.12 * sin(_t * 6.0 + i * 2.0))
					draw_colored_polygon(PackedVector2Array([Vector2(x - r * 0.15, c.y + r * 0.4), Vector2(x + r * 0.15, c.y + r * 0.4), Vector2(x, c.y + r * 0.4 - h)]), Color(lit, 0.85))
			8:   # Toxic: bubbles
				for i in 4:
					var ph := fmod(_t * 0.5 + i * 0.25, 1.0)
					var p := c + Vector2((i - 1.5) * 0.35, 0.4 - ph * 0.9) * r
					draw_circle(p, r * (0.06 + 0.1 * ph), Color(lit, 1.0 - ph), false, 2.0, true)
			9:   # Prism: colour bands
				for i in 4:
					var col := Color.from_hsv(fmod(0.13 + 0.15 * i + _t * 0.1, 1.0), 0.55, 1.0, 0.75)
					var y := c.y + (i - 1.5) * r * 0.32
					draw_line(Vector2(c.x - r * 0.75, y), Vector2(c.x + r * 0.75, y), col, r * 0.14, true)
			10:   # Abyssal: lights drifting in the deep
				for i in 5:
					var p := c + Vector2(cos(_t * 0.4 + i * 1.3) * 0.5, sin(_t * 0.5 + i * 2.1) * 0.45) * r
					draw_circle(p, r * 0.08, Color(lit, 0.5 + 0.5 * sin(_t * 2.0 + i)))
			11:   # Diamond: gem facets in rainbow fire, a glint
				var gem := PackedVector2Array([c + Vector2(0, -0.55) * r, c + Vector2(0.45, -0.1) * r, c + Vector2(0, 0.55) * r, c + Vector2(-0.45, -0.1) * r, c + Vector2(0, -0.55) * r])
				draw_polyline(gem, Color.from_hsv(fmod(_t * 0.15, 1.0), 0.4, 1.0, 0.95), r * 0.08, true)
				draw_line(c + Vector2(-0.45, -0.1) * r, c + Vector2(0.45, -0.1) * r, Color(1, 1, 1, 0.7), 2.0, true)
				var tw := pow(maxf(0.0, sin(_t * 2.5)), 8.0)
				draw_line(c + Vector2(0.3, -0.5) * r - Vector2(r * 0.16, 0), c + Vector2(0.3, -0.5) * r + Vector2(r * 0.16, 0), Color(1, 1, 1, tw), 2.0, true)
				draw_line(c + Vector2(0.3, -0.5) * r - Vector2(0, r * 0.16), c + Vector2(0.3, -0.5) * r + Vector2(0, r * 0.16), Color(1, 1, 1, tw), 2.0, true)
			12:   # Mythic: rune rings rising in violet and cyan
				for i in 3:
					var y := c.y + r * 0.55 - fmod(_t * 14.0 + i * r * 0.4, r * 1.2)
					var col := Color(0.62, 0.3, 1.0).lerp(Color(0.3, 0.9, 1.0), 0.5 + 0.5 * sin(_t + i))
					draw_line(Vector2(c.x - r * 0.6, y), Vector2(c.x + r * 0.6, y), Color(col, 0.9), r * 0.08, true)
					for j in 3:
						draw_rect(Rect2(c.x + (j - 1) * r * 0.35 - r * 0.05, y - r * 0.14, r * 0.1, r * 0.1), Color(col, 0.8))
			13:   # Legend: a red-gold sun's rays turning
				for i in 6:
					var ang := _t * 0.8 + i * TAU / 6.0
					draw_line(c + Vector2(cos(ang), sin(ang)) * r * 0.18, c + Vector2(cos(ang), sin(ang)) * r * 0.62, Color(1.0, 0.62, 0.2, 0.9), r * 0.1, true)
				draw_circle(c, r * 0.2, Color(1.0, 0.86, 0.45))
			21, 26:   # Crimson's gold lattice, Royal's gold pinstripes (version 172)
				var gold := Color(1.0, 0.8, 0.34, 0.9)
				for i in 3:
					var x := c.x + (i - 1) * r * 0.42
					if pat == 26:
						draw_line(Vector2(x, c.y - r * 0.6), Vector2(x, c.y + r * 0.35), gold, r * 0.09, true)
					else:
						draw_line(Vector2(x - r * 0.3, c.y - r * 0.5), Vector2(x + r * 0.3, c.y + r * 0.2), gold, r * 0.06, true)
						draw_line(Vector2(x + r * 0.3, c.y - r * 0.5), Vector2(x - r * 0.3, c.y + r * 0.2), gold, r * 0.06, true)
			23, 28, 31:   # Midnight's stars, Frost's glints, Gilded's sparkles
				for i in 4:
					var p := c + Vector2(cos(i * 2.1 + 0.4) * 0.5, sin(i * 2.1 + 0.4) * 0.45 - 0.12) * r
					var tw := 0.45 + 0.55 * sin(_t * 3.5 + i * 1.7)
					draw_line(p - Vector2(r * 0.13, 0), p + Vector2(r * 0.13, 0), Color(1, 1, 1, tw), 2.0, true)
					draw_line(p - Vector2(0, r * 0.13), p + Vector2(0, r * 0.13), Color(1, 1, 1, tw), 2.0, true)
			22, 29, 32:   # Forest's leaf scales, Rose's petals, Bone's plates
				for i in 5:
					var p := c + Vector2((i % 3 - 1) * 0.42 + (0.21 if i > 2 else 0.0), -0.38 if i < 3 else 0.02) * r
					draw_arc(p, r * 0.2, 0.0, PI, 10, Color(lit, 0.85), r * 0.07, true)
			24, 30:   # Ivory's filigree bands, Sea's waves
				for i in 2:
					var y := c.y - r * 0.4 + i * r * 0.4
					var pts := PackedVector2Array()
					for k in 9:
						pts.append(Vector2(c.x - r * 0.65 + k * r * 0.1625, y + sin(k * 1.6 + _t * 2.0 * float(pat == 30)) * r * 0.08))
					draw_polyline(pts, Color(lit, 0.9), r * 0.08, true)
			37:   # Yule Knit: a cream zigzag band with fairy lights, a snowflake
				var cream := b
				draw_rect(Rect2(c.x - r * 0.75, c.y + r * 0.08, r * 1.5, r * 0.34), Color(cream, 0.95))
				var zz := PackedVector2Array()
				for k in 9:
					zz.append(Vector2(c.x - r * 0.72 + k * r * 0.18, c.y + r * (0.14 if k % 2 == 0 else 0.34)))
				draw_polyline(zz, a, r * 0.06, true)
				for k in 4:
					var on := fmod(_t * 0.7 - k / 4.0, 1.0) > 0.4
					var col: Color = [Color(1.0, 0.78, 0.3), Color(0.45, 0.82, 1.0), Color(1.0, 0.95, 0.82), Color(1.0, 0.78, 0.3)][k]
					draw_circle(Vector2(c.x - r * 0.54 + k * r * 0.36, c.y + r * 0.25), r * (0.08 if on else 0.05), col if on else col.darkened(0.5))
				for k in 3:
					var ang := k * PI / 3.0
					var d := Vector2(cos(ang), sin(ang)) * r * 0.22
					draw_line(c + Vector2(0, -r * 0.32) - d, c + Vector2(0, -r * 0.32) + d, Color(cream, 0.6 + 0.4 * pulse), r * 0.06, true)
			38:   # Polar Night: the northern lights rippling, stars
				for i in 3:
					var pts := PackedVector2Array()
					for k in 9:
						pts.append(Vector2(c.x - r * 0.7 + k * r * 0.175, c.y + r * (0.3 - i * 0.28) + sin(k * 1.1 + _t * 1.5 + i) * r * 0.08))
					draw_polyline(pts, Color(0.35, 1.0, 0.65).lerp(Color(0.72, 0.45, 1.0), i / 2.0), r * 0.1, true)
				for i in 3:
					var p := c + Vector2(cos(i * 2.3 + 0.5) * 0.5, -0.5 + 0.1 * i) * r
					draw_circle(p, r * 0.04 * (0.6 + 0.4 * sin(_t * 4.0 + i * 2.0)), Color.WHITE)
			25, 27:   # Shadow's smoke, Ember's coals
				for i in 3:
					var p := c + Vector2((i - 1) * 0.4, -0.15 + 0.12 * sin(_t * 2.0 + i * 2.0)) * r
					draw_circle(p, r * 0.16, Color(lit, 0.45 + 0.3 * pulse))

	## A Crypt King look's picture: a white glint sweeps across it every two seconds.
	func _glint(c: Vector2, r: float) -> void:
		var f := fmod(_t * 0.5, 1.0) * 3.0 - 1.0   # -1..2: across, then a pause
		if f > 1.0:
			return
		var x := c.x + f * r * 1.2
		# (Version 175: a thin warm glint. The wide white one looked like a grey scratch
		# across the picture.)
		var pts := PackedVector2Array([Vector2(x - r * 0.05, c.y - r), Vector2(x + r * 0.05, c.y - r),
			Vector2(x - r * 0.25, c.y + r), Vector2(x - r * 0.35, c.y + r)])
		draw_colored_polygon(pts, Color(1.0, 0.95, 0.75, 0.3 * (1.0 - absf(f))))

	func _process(delta: float) -> void:
		if picture or not (aura.get("cycle", false) or aura.has("ink2") or shine or a2 != null or shape in ["crypt_crown", "pattern", "storm_halo", "star_circlet", "flame_crown", "candle_crown"]):
			set_process(false)   # only a pulsing aura's swatch is redrawn every frame
			return
		_t += delta
		queue_redraw()

	## A Master aura's swatch: a hero's shape drawn as a glowing outline in the aura's
	## colour (as it pulses), with its sparks around it. No aura: a plain dark figure.
	func _aura(c: Vector2, r: float) -> void:
		var ink := HeroStyle.aura_ink(aura, _t) if not aura.is_empty() else a
		var body := Color(0.16, 0.14, 0.2)
		if not aura.is_empty():
			draw_circle(c, r, Color(ink, 0.2))
		if aura.get("sigil", false):
			# The Crypt King's sigil: two gold rings turning under the figure.
			var gold := Color(1.0, 0.8, 0.3)
			for i in 8:
				var s0 := _t * 0.9 + i * TAU / 8.0
				draw_arc(c + Vector2(0, r * 0.62), r * 0.85, s0, s0 + 0.45, 6, gold, 2.5, true)
			draw_arc(c + Vector2(0, r * 0.62), r * 0.62, 0, TAU, 32, Color(gold, 0.7), 2.0, true)
		var head := c + Vector2(0, -r * 0.42)
		var torso := PackedVector2Array([c + Vector2(-r * 0.42, r * 0.75), c + Vector2(-r * 0.3, -r * 0.08), c + Vector2(r * 0.3, -r * 0.08), c + Vector2(r * 0.42, r * 0.75)])
		var w := r * 0.2 if not aura.is_empty() else 2.0
		draw_circle(head, r * 0.28 + w * 0.5, ink)
		var fat := PackedVector2Array()
		for p: Vector2 in torso:
			fat.append(c + (p - c) * 1.0 + (p - c).normalized() * w * 0.7)
		draw_colored_polygon(fat, ink)
		draw_circle(head, r * 0.28, body)
		draw_colored_polygon(torso, body)
		if str(aura.get("motif", "")) == "bonechain":
			# v254: the Bone Chain's links circling the figure, lighting up one by one
			var lit := fmod(_t * 0.2, 1.0) * 1.4
			for i in 10:
				var ang := _t * 0.5 + i * TAU / 10.0
				var at := c + Vector2(cos(ang), sin(ang) * 0.45) * r * 0.92 + Vector2(0, r * 0.2)
				var col := Color(0.95, 0.9, 0.78).lerp(Color(1.0, 0.72, 0.25), clampf(lit * 10.0 - i, 0.0, 1.0))
				var nn := Vector2(-cos(ang) * 0.45, -sin(ang)).normalized()
				draw_line(at - nn * r * 0.13, at + nn * r * 0.13, col, r * 0.05)
				draw_circle(at, r * 0.075, col)
		elif not aura.is_empty():
			for i in 5:
				var ang := _t * 0.8 + i * TAU / 5.0
				draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.86, r * (0.07 + 0.03 * sin(_t * 3.0 + i)), b)

	func _head(c: Vector2, r: float) -> void:
		var gold := Color(1.0, 0.8, 0.3)
		var steel := Color(0.72, 0.75, 0.82)
		var skin := Color(0.95, 0.72, 0.55)
		match shape:
			"crypt_crown":
				var dark := Color(0.1, 0.075, 0.14)
				var gem := Color(0.45, 1.0, 0.85)
				var bob := sin(_t * 2.2) * r * 0.06
				var o := c + Vector2(0, bob)
				draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 0.9, r * 0.55), o + Vector2(-r * 0.95, -r * 0.35), o + Vector2(-r * 0.6, r * 0.05),
					o + Vector2(-r * 0.3, -r * 0.6), o + Vector2(0, r * 0.0), o + Vector2(r * 0.3, -r * 0.6), o + Vector2(r * 0.6, r * 0.05),
					o + Vector2(r * 0.95, -r * 0.35), o + Vector2(r * 0.9, r * 0.55)]), gold)
				draw_rect(Rect2(o + Vector2(-r * 0.8, r * 0.18), Vector2(r * 1.6, r * 0.24)), dark)
				for gx in [-0.95, -0.3, 0.3, 0.95]:
					draw_circle(o + Vector2(r * gx, -r * (0.35 if absf(gx) > 0.5 else 0.6) - r * 0.12), r * 0.12, gem)
				draw_circle(o + Vector2(0, r * 0.3), r * 0.1, gem)
				draw_arc(c + Vector2(0, r * 0.85), r * 0.7, PI * 1.1, PI * 1.9, 20, Color(1.0, 0.82, 0.35, 0.6), r * 0.08, true)
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
			"shadow_hood":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.85, r * 0.75), c + Vector2(-r * 0.7, -r * 0.4),
					c + Vector2(0, -r * 0.95), c + Vector2(r * 0.7, -r * 0.4), c + Vector2(r * 0.85, r * 0.75)]), Color(0.42, 0.36, 0.68))
				draw_circle(c + Vector2(0, r * 0.12), r * 0.5, Color(0.95, 0.62, 0.28))
				draw_circle(c + Vector2(0, r * 0.12), r * 0.42, Color(0.03, 0.02, 0.05))
				for s in [-1.0, 1.0]:
					draw_circle(c + Vector2(s * r * 0.17, r * 0.05), r * 0.08, Color(0.6, 0.85, 1.0))
			"storm_halo":
				# (Version 191: drawn inside the card. The ring and its bolts stood above the top
				# edge and pushed the card's name down a line.)
				draw_circle(c + Vector2(0, r * 0.5), r * 0.45, skin)
				draw_arc(c + Vector2(0, -r * 0.2), r * 0.52, 0, TAU, 32, Color(0.75, 0.9, 1.0), r * 0.15, true)
				for i in 3:
					var ang := _t * 2.0 + i * 2.1
					var p := c + Vector2(cos(ang) * r * 0.55, -r * 0.2 + sin(ang) * r * 0.15)
					draw_polyline(PackedVector2Array([p, p + Vector2(r * 0.1, -r * 0.12), p + Vector2(0, -r * 0.18), p + Vector2(r * 0.12, -r * 0.3)]), Color(0.85, 0.95, 1.0), 2.0, true)
			"candle_crown":
				# Frostfall (v244): a pine wreath with berries, five candles burning on it.
				var pine := Color(0.12, 0.42, 0.2)
				draw_rect(Rect2(c + Vector2(-r * 0.85, r * 0.22), Vector2(r * 1.7, r * 0.3)), pine)
				for i in 7:
					draw_circle(c + Vector2(-r * 0.78 + i * r * 0.26, r * 0.22), r * 0.12, pine.lightened(0.12))
				for i in 3:
					draw_circle(c + Vector2(-r * 0.52 + i * r * 0.52, r * 0.48), r * 0.07, Color(0.72, 0.1, 0.14))
				for i in 5:
					var x := -0.64 + i * 0.32
					var h := 0.55 + (0.1 if i == 2 else 0.0)
					draw_rect(Rect2(c + Vector2((x - 0.07) * r, (0.22 - h) * r), Vector2(r * 0.14, h * r)), Color(0.98, 0.94, 0.84))
					var fl := r * (0.2 + 0.04 * sin(_t * 9.0 + i * 2.0))
					var top := c + Vector2(x * r, (0.22 - h) * r)
					draw_colored_polygon(PackedVector2Array([top + Vector2(-r * 0.07, 0), top + Vector2(0, -fl), top + Vector2(r * 0.07, 0)]), Color(1.0, 0.72, 0.25))
					draw_circle(top + Vector2(0, -r * 0.04), r * 0.035, Color(1.0, 0.97, 0.75))
			"moon_crown":
				# (Version 191: this card had no picture at all.) A dark band with spikes, a white
				# crescent moon lying over it.
				var iron := Color(0.3, 0.3, 0.42)
				draw_rect(Rect2(c + Vector2(-r * 0.8, r * 0.3), Vector2(r * 1.6, r * 0.28)), iron)
				for sx in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([c + Vector2(sx * r * 0.8, r * 0.3), c + Vector2(sx * r * 0.55, r * 0.3), c + Vector2(sx * r * 0.85, -r * 0.35)]), iron)
					draw_circle(c + Vector2(sx * r * 0.85, -r * 0.42), r * 0.09, gold)
				draw_circle(c + Vector2(0, -r * 0.05), r * 0.5, Color(0.97, 0.97, 1.0))
				draw_circle(c + Vector2(0, -r * 0.3), r * 0.46, Color(0.13, 0.1, 0.17))
			"star_circlet":
				draw_circle(c + Vector2(0, r * 0.2), r * 0.6, skin)
				draw_arc(c + Vector2(0, -r * 0.05), r * 0.62, PI * 0.95, PI * 2.05, 20, gold, r * 0.1, true)
				for i in 3:
					var ang := _t * 1.2 + i * TAU / 3.0
					var p := c + Vector2(cos(ang) * r * 0.95, -r * 0.1 + sin(ang) * r * 0.25)
					_star(p, r * 0.2, Color(1.0, 0.95, 0.75))
			"flame_crown":
				draw_rect(Rect2(c + Vector2(-r * 0.8, r * 0.2), Vector2(r * 1.6, r * 0.3)), Color(0.15, 0.12, 0.12))
				for i in 5:
					var x := -0.64 + i * 0.32
					var h := (0.9 if i % 2 == 0 else 0.6) * (1.0 + 0.1 * sin(_t * 9.0 + i))
					draw_colored_polygon(PackedVector2Array([c + Vector2((x - 0.14) * r, r * 0.2), c + Vector2((x + 0.14) * r, r * 0.2), c + Vector2(x * r, (0.2 - h) * r)]), Color(1.0, 0.55, 0.12))
					draw_colored_polygon(PackedVector2Array([c + Vector2((x - 0.07) * r, r * 0.2), c + Vector2((x + 0.07) * r, r * 0.2), c + Vector2(x * r, (0.2 - h * 0.55) * r)]), Color(1.0, 0.95, 0.6))
			"skull_helm":
				var bone := Color(0.93, 0.9, 0.8)
				draw_circle(c + Vector2(0, -r * 0.1), r * 0.78, bone)
				draw_rect(Rect2(c + Vector2(-r * 0.42, r * 0.35), Vector2(r * 0.84, r * 0.4)), bone)
				for sx in [-1.0, 1.0]:
					draw_circle(c + Vector2(sx * r * 0.3, 0), r * 0.2, Color(0.04, 0.03, 0.05))
					draw_circle(c + Vector2(sx * r * 0.3, 0), r * 0.08, Color(0.5, 0.9, 1.0))
				for i in 4:
					draw_line(c + Vector2((-0.27 + i * 0.18) * r, r * 0.42), c + Vector2((-0.27 + i * 0.18) * r, r * 0.72), Color(0.04, 0.03, 0.05), 2.0)
			"antlers":
				draw_circle(c + Vector2(0, r * 0.45), r * 0.45, skin)
				var horn := Color(0.82, 0.72, 0.56)
				for sx in [-1.0, 1.0]:
					var pts := PackedVector2Array([c + Vector2(sx * r * 0.25, r * 0.1), c + Vector2(sx * r * 0.55, -r * 0.3), c + Vector2(sx * r * 0.7, -r * 0.95)])
					draw_polyline(pts, horn, r * 0.13, true)
					draw_line(pts[1], pts[1] + Vector2(-sx * r * 0.05, -r * 0.45), horn, r * 0.09, true)
					draw_line(pts[1], pts[1] + Vector2(sx * r * 0.4, -r * 0.3), horn, r * 0.09, true)
					draw_circle(pts[2], r * 0.08, Color(0.55, 1.0, 0.85))
			"phantom_horns":
				draw_circle(c + Vector2(0, r * 0.35), r * 0.5, skin)
				for sx in [-1.0, 1.0]:
					draw_polyline(PackedVector2Array([c + Vector2(sx * r * 0.35, r * 0.1), c + Vector2(sx * r * 0.8, -r * 0.1), c + Vector2(sx * r * 0.95, -r * 0.55), c + Vector2(sx * r * 0.8, -r * 0.9)]), Color(0.6, 0.5, 1.0, 0.9), r * 0.18, true)
					draw_polyline(PackedVector2Array([c + Vector2(sx * r * 0.35, r * 0.1), c + Vector2(sx * r * 0.8, -r * 0.1), c + Vector2(sx * r * 0.95, -r * 0.55), c + Vector2(sx * r * 0.8, -r * 0.9)]), Color(0.6, 1.0, 0.95, 0.9), r * 0.06, true)
			"bone_crown":
				var bone := Color(0.93, 0.9, 0.8)
				draw_rect(Rect2(c + Vector2(-r * 0.85, r * 0.15), Vector2(r * 1.7, r * 0.3)), bone)
				for i in 5:
					var x := -0.68 + i * 0.34
					var h := 0.85 if i % 2 == 0 else 0.55
					draw_colored_polygon(PackedVector2Array([c + Vector2((x - 0.1) * r, r * 0.15), c + Vector2((x + 0.1) * r, r * 0.15), c + Vector2(x * r, (0.15 - h) * r)]), bone)
					if i % 2 == 0:
						draw_circle(c + Vector2(x * r, (0.05 - h) * r), r * 0.1, Color(0.35, 1.0, 0.55))
			"hood":
				draw_circle(c, r * 0.8, Color(0.25, 0.45, 0.95))
				draw_circle(c + Vector2(0, r * 0.15), r * 0.48, skin)

	func _star(p: Vector2, s: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 8:
			pts.append(p + Vector2.from_angle(-PI / 2 + TAU * i / 8.0) * (s if i % 2 == 0 else s * 0.35))
		draw_colored_polygon(pts, col)

	## v229: the Knight's, Rogue's and Barbarian's forged, gilded and void weapons have their
	## own shapes (ForgedArms); this draws them over the weapon they are built on.
	func _forged(c: Vector2, r: float) -> void:
		var ice := Color(0.82, 0.96, 1.0)
		var gold := Color(1.0, 0.84, 0.4)
		var violet := Color(0.68, 0.45, 1.0)
		var rim := Color(0.9, 0.75, 1.0)
		match shape:
			"badge":
				# ice cased sword, a snowflake of ice spikes round the shield
				_shard(c + Vector2(-r * 0.35, r * 0.45), Vector2.UP, r * 1.35, r * 0.17, ice)
				var sh := c + Vector2(r * 0.35, r * 0.05)
				for i in 10:
					var d := Vector2.from_angle(TAU * i / 10.0)
					_shard(sh + d * r * 0.48, d, r * (0.32 if i % 2 == 0 else 0.2), r * 0.08, ice)
			"heavy":
				var tips := [c + Vector2(-r * 0.89, -r * 0.55), c + Vector2(r * 0.89, -r * 0.55)]
				if finish == "frost":
					for i in 2:
						var sd := -1.0 if i == 0 else 1.0
						_shard(tips[i], Vector2(sd, -0.35), r * 0.45, r * 0.1, ice)
					_shard(c + Vector2(0, r * 0.3), Vector2.UP, r * 1.25, r * 0.08, ice)
				elif finish == "gold":
					# Version 278: the sun wings fan out from the front of the stock, as on the
					# crossbow itself, inside the swatch (they sat on the old limb tips and spilled
					# out of the card as two gold blobs).
					var front := c + Vector2(0, -r * 0.5)
					draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, -r * 0.62), Color(1.0, 0.95, 0.78), r * 0.15)
					for i in 2:
						var sd := -1.0 if i == 0 else 1.0
						for k in 4:
							_leaf(front + Vector2(sd * r * 0.06, 0), Vector2(sd, 0).rotated(-sd * deg_to_rad(8.0 + k * 20.0)), r * (0.74 - k * 0.1), r * 0.12, gold.lerp(Color(1.0, 0.97, 0.85), k * 0.12))
					draw_line(c + Vector2(0, r * 0.55), c + Vector2(0, -r * 0.95), gold, r * 0.06)
					draw_circle(front, r * 0.13, Color(1.0, 0.97, 0.85))
				elif finish == "void":
					var g := c + Vector2(0, -r * 0.82)
					draw_circle(g, r * 0.3, Color(0.4, 0.15, 0.7, 0.55))
					draw_arc(g, r * 0.3, 0.0, TAU, 24, rim, r * 0.09, true)
					_orb_icon(c + Vector2(0, -r * 0.2), r * 0.12)
			"twin_knives":
				for sd: float in [-1.0, 1.0]:
					_flame_icon(c + Vector2(sd * r * 0.45, -r * 0.05), r * 0.62)
			"twin_axes":
				for sd: float in [-1.0, 1.0]:
					var o := c + Vector2(-r * 0.35 if sd < 0 else r * 0.35, 0)
					var w := r * 0.45
					for y: float in [-0.8, -0.5, -0.2]:
						_shard(o + Vector2(w, r * y), Vector2(1.0, (y + 0.5) * 0.9), r * 0.3, r * 0.07, ice)
					_shard(o + Vector2(0, -r * 0.8), Vector2.UP, r * 0.3, r * 0.07, ice)

	## v230: the Knight's and Barbarian's grand looks, each a whole weapon of its own.
	func _whole(p: String, c: Vector2, r: float) -> void:
		var obsidian := Color(0.16, 0.13, 0.22)
		var bone := Color(0.93, 0.88, 0.76)
		var soul := Color(0.3, 1.0, 0.82)
		var iron := Color(0.22, 0.19, 0.2)
		var magma := Color(1.0, 0.5, 0.12)
		var gold := Color(1.0, 0.84, 0.4)
		var violet := Color(0.68, 0.45, 1.0)
		var rim := Color(0.9, 0.75, 1.0)
		var wood := Color(0.45, 0.28, 0.16)
		match p:
			"magma_cleaver":
				draw_line(c + Vector2(0, r), c + Vector2(0, r * 0.45), iron, r * 0.13)
				draw_circle(c + Vector2(0, r), r * 0.1, magma)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.42, r * 0.5), c + Vector2(-r * 0.5, r * 0.3),
					c + Vector2(r * 0.5, r * 0.3), c + Vector2(r * 0.42, r * 0.5)]), iron)
				var blade := PackedVector2Array([c + Vector2(-r * 0.15, r * 0.32), c + Vector2(-r * 0.2, -r * 0.88),
					c + Vector2(r * 0.18, -r * 0.98), c + Vector2(r * 0.5, -r * 0.96), c + Vector2(r * 0.42, -r * 0.4),
					c + Vector2(r * 0.15, r * 0.32)])
				draw_colored_polygon(blade, iron)
				draw_polyline(PackedVector2Array([blade[5], blade[4], blade[3]]), magma, r * 0.07, true)
				draw_polyline(PackedVector2Array([c + Vector2(0, r * 0.2), c + Vector2(r * 0.1, -r * 0.2),
					c + Vector2(-r * 0.02, -r * 0.5), c + Vector2(r * 0.12, -r * 0.8)]), magma, r * 0.04, true)
				_flame_icon(c + Vector2(r * 0.3, -r * 0.95), r * 0.42)
			"sun_hammer":
				draw_line(c + Vector2(0, r), c + Vector2(0, -r * 0.45), wood, r * 0.12)
				for y: float in [0.8, 0.2]:
					draw_line(c + Vector2(-r * 0.09, r * y), c + Vector2(r * 0.09, r * y), gold, r * 0.1)
				draw_rect(Rect2(c + Vector2(-r * 0.56, -r * 0.98), Vector2(r * 1.12, r * 0.52)), gold)
				draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 1.0), Vector2(r * 0.14, r * 0.56)), Color(0.85, 0.6, 0.2))
				draw_rect(Rect2(c + Vector2(r * 0.52, -r * 1.0), Vector2(r * 0.14, r * 0.56)), Color(0.85, 0.6, 0.2))
				draw_circle(c + Vector2(0, -r * 0.72), r * 0.15, Color(1.0, 0.97, 0.85))
				_ring(c + Vector2(0, -r * 0.72), r * 0.85, r * 0.2, Color(1.0, 0.92, 0.6))
			"rift_blade":
				draw_line(c + Vector2(0, r), c + Vector2(0, r * 0.55), iron, r * 0.13)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.42, r * 0.55), c + Vector2(0, r * 0.42),
					c + Vector2(r * 0.42, r * 0.55), c + Vector2(0, r * 0.66)]), violet)
				for k in 4:
					var y0 := r * (0.35 - k * 0.36)
					var dx := r * (0.06 if k % 2 == 0 else -0.06)
					var piece := PackedVector2Array([c + Vector2(dx - r * 0.16, y0), c + Vector2(dx + r * 0.16, y0),
						c + Vector2(dx + r * 0.13, y0 - r * 0.26), c + Vector2(dx - r * 0.13, y0 - r * 0.26)])
					if k == 3:
						piece = PackedVector2Array([c + Vector2(dx - r * 0.16, y0), c + Vector2(dx + r * 0.16, y0), c + Vector2(dx, y0 - r * 0.42)])
					draw_colored_polygon(piece, Color(0.3, 0.16, 0.5))
					piece.append(piece[0])
					draw_polyline(piece, rim, 1.5, true)
				_orb_icon(c + Vector2(0, -r * 1.0), r * 0.1)
			"magma_maul":
				draw_line(c + Vector2(0, r), c + Vector2(0, -r * 0.3), iron, r * 0.13)
				var h := c + Vector2(0, -r * 0.55)
				for b: Array in [[-0.28, 0.08, 0.26], [0.26, 0.04, 0.27], [0.0, -0.26, 0.28], [-0.12, 0.22, 0.22], [0.16, 0.24, 0.2]]:
					draw_circle(h + Vector2(r * b[0], r * b[1]), r * b[2], Color(0.26, 0.17, 0.14))
				draw_polyline(PackedVector2Array([h + Vector2(-r * 0.4, 0), h + Vector2(-r * 0.12, -r * 0.08),
					h + Vector2(r * 0.05, r * 0.12), h + Vector2(r * 0.38, -r * 0.05)]), magma, r * 0.06, true)
				draw_line(h + Vector2(0, -r * 0.4), h + Vector2(-r * 0.05, r * 0.3), magma, r * 0.05)
				_flame_icon(h + Vector2(-r * 0.05, -r * 0.4), r * 0.5)
			"ram_mace":
				draw_line(c + Vector2(0, r), c + Vector2(0, -r * 0.35), wood, r * 0.12)
				draw_line(c + Vector2(-r * 0.09, r * 0.5), c + Vector2(r * 0.09, r * 0.5), gold, r * 0.1)
				var h := c + Vector2(0, -r * 0.6)
				for sd: float in [-1.0, 1.0]:
					var pts := PackedVector2Array()
					for i in 17:
						var t := i / 16.0
						var th := t * PI * 1.55
						var rr := r * 0.42 * (1.0 - 0.55 * t)
						pts.append(h + Vector2(sd * (r * 0.42 - rr * cos(th)), r * 0.1 - rr * sin(th)))
					draw_polyline(pts, Color(0.85, 0.62, 0.2), r * 0.13, true)
				for i in 8:
					var d := Vector2.from_angle(TAU * i / 8.0)
					_shard(h + d * r * 0.18, d, r * 0.24, r * 0.06, gold)
				draw_circle(h, r * 0.26, gold)
				draw_circle(h, r * 0.1, Color(1.0, 0.97, 0.85))
			"moon_axe":
				draw_line(c + Vector2(0, r), c + Vector2(0, -r * 0.8), iron, r * 0.12)
				for sd: float in [-1.0, 1.0]:
					var o := c + Vector2(-sd * r * 0.2, -r * 0.35)
					var a0 := 0.0 if sd > 0 else PI
					var outer := PackedVector2Array()
					var inner := PackedVector2Array()
					for i in 13:
						var t := i / 12.0
						var d := Vector2.from_angle(a0 + lerpf(-1.1, 1.1, t))
						outer.append(o + d * r * 0.7)
						inner.append(o + d * r * 0.7 * (0.96 - 0.42 * sin(PI * t)))
					draw_polyline(outer, rim, 2.0)
					inner.reverse()
					outer.append_array(inner)
					draw_colored_polygon(outer, Color(0.36, 0.18, 0.62))
				_shard(c + Vector2(0, -r * 0.75), Vector2.UP, r * 0.32, r * 0.08, violet)
				_orb_icon(c + Vector2(0, -r * 0.35), r * 0.12)
			# Version 253: the Crypt King's arms, whole weapons of obsidian, bone and gold with
			# teal soul fire (CryptArms).
			"king_blade":
				# the Kingsbane: obsidian rails round a channel of soul fire, a gold crown tip,
				# a crowned skull for its guard between gold rib wings, a bone grip
				draw_line(c + Vector2(0, r), c + Vector2(0, r * 0.5), bone, r * 0.12)
				for y: float in [0.88, 0.72]:
					draw_line(c + Vector2(-r * 0.09, r * y), c + Vector2(r * 0.09, r * y), gold, r * 0.04)
				for sd: float in [-1.0, 1.0]:
					var a0 := 0.35 * PI if sd > 0 else 0.65 * PI
					var a1 := -0.3 * PI if sd > 0 else 1.3 * PI
					for rr: float in [0.42, 0.3]:
						draw_arc(c + Vector2(0, r * 0.42), r * rr, a0, a1, 14, gold, r * 0.06, true)
					var rail := PackedVector2Array([c + Vector2(sd * r * 0.06, r * 0.38), c + Vector2(sd * r * 0.22, r * 0.38),
						c + Vector2(sd * r * 0.26, -r * 0.1), c + Vector2(sd * r * 0.22, -r * 0.6), c + Vector2(0, -r * 0.95),
						c + Vector2(0, -r * 0.76), c + Vector2(sd * r * 0.06, -r * 0.64)])
					draw_colored_polygon(rail, obsidian)
					draw_polyline(PackedVector2Array([rail[1], rail[2], rail[3], rail[4]]), gold, 2.0, true)
				draw_line(c + Vector2(0, r * 0.36), c + Vector2(0, -r * 0.7), soul, r * 0.1)
				for d: Vector2 in [Vector2(-0.55, -1.0), Vector2(0, -1.0), Vector2(0.55, -1.0)]:
					_shard(c + Vector2(0, -r * 0.9), d, r * (0.3 if d.x == 0.0 else 0.22), r * 0.06, gold)
				_skull_icon(c + Vector2(0, r * 0.42), r * 0.15)
			"king_axe":
				# the Skull Crusher: a crowned skull for a head, jagged blades lined with soul fire
				draw_line(c + Vector2(0, r), c + Vector2(0, -r * 0.3), obsidian.lightened(0.15), r * 0.12)
				for y: float in [0.8, 0.3]:
					draw_line(c + Vector2(-r * 0.09, r * y), c + Vector2(r * 0.09, r * y), gold, r * 0.08)
				var h := c + Vector2(0, -r * 0.45)
				var teeth := [Vector2(0.2, 0.84), Vector2(0.5, 0.62), Vector2(0.64, 0.8), Vector2(0.56, 0.9), Vector2(0.72, 1.0),
					Vector2(0.6, 1.1), Vector2(0.74, 1.22), Vector2(0.6, 1.33), Vector2(0.5, 1.5), Vector2(0.2, 1.26)]
				for sd: float in [-1.0, 1.0]:
					var pts := PackedVector2Array()
					for q: Vector2 in teeth:
						pts.append(h + Vector2(sd * q.x, -(q.y - 1.05)) * r * 0.95)
					draw_colored_polygon(pts, obsidian)
					draw_polyline(pts.slice(1, pts.size() - 1), soul, 2.0, true)
				_skull_icon(h, r * 0.27)
			"king_staff":
				# the Spine: stacked vertebrae round soul fire, a soul flame held up, and the
				# Crypt Crown floating over it
				var b0 := c + Vector2(-r * 0.2, r)
				var b1 := c + Vector2(r * 0.16, -r * 0.48)
				draw_line(b0, b1, soul, r * 0.05)
				for i in 9:
					draw_circle(b0.lerp(b1, (i + 0.5) / 9.0), r * 0.075, bone)
				var h := c + Vector2(r * 0.2, -r * 0.62)
				draw_circle(h, r * 0.22, Color(soul, 0.3))
				draw_circle(h, r * 0.12, soul)
				draw_arc(h, r * 0.17, PI * 0.15, PI * 0.85, 10, bone, r * 0.05, true)
				_crown_icon(h + Vector2(0, -r * 0.42), r * 0.56)
			"king_bow":
				# the ribcage crossbow: three pairs of gold-tipped ribs, a skull at its nose, a
				# soul-fire bolt and a crown by the hand
				draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, -r * 0.5), obsidian.lightened(0.15), r * 0.14)
				draw_line(c + Vector2(0, r * 0.25), c + Vector2(0, -r * 0.5), soul, r * 0.05)
				for k in 3:
					var y := -r * 0.32 + k * r * 0.24
					var span := r * (0.88 - k * 0.2)
					for sd: float in [-1.0, 1.0]:
						var rib := PackedVector2Array([c + Vector2(sd * r * 0.05, y), c + Vector2(sd * span * 0.5, y - r * 0.16),
							c + Vector2(sd * span * 0.92, y - r * 0.06), c + Vector2(sd * span, y + r * 0.1)])
						draw_polyline(rib, bone, r * 0.07, true)
						_shard(rib[3], Vector2(sd * 0.3, 1.0), r * 0.14, r * 0.04, gold)
				_skull_icon(c + Vector2(0, -r * 0.62), r * 0.14)
				_crown_icon(c + Vector2(0, r * 0.58), r * 0.32)

	## v253: a bone skull with soul-fire eyes wearing a gold crown (CryptArms' skulls).
	func _skull_icon(o: Vector2, sz: float) -> void:
		draw_circle(o, sz, Color(0.93, 0.88, 0.76))
		draw_rect(Rect2(o + Vector2(-sz * 0.55, sz * 0.45), Vector2(sz * 1.1, sz * 0.55)), Color(0.93, 0.88, 0.76))
		for sd: float in [-1.0, 1.0]:
			draw_circle(o + Vector2(sd * sz * 0.38, sz * 0.05), sz * 0.28, Color(0.03, 0.03, 0.05))
			draw_circle(o + Vector2(sd * sz * 0.38, sz * 0.05), sz * 0.13, Color(0.3, 1.0, 0.82))
		draw_colored_polygon(PackedVector2Array([o + Vector2(-sz * 0.1, sz * 0.5), o + Vector2(0, sz * 0.32), o + Vector2(sz * 0.1, sz * 0.5)]), Color(0.03, 0.03, 0.05))
		_crown_icon(o + Vector2(0, -sz * 0.72), sz * 1.5)

	## v253: the Crypt Crown, `w` wide: a gold band, five points, soul gems on the tall ones.
	func _crown_icon(o: Vector2, w: float) -> void:
		var gold := Color(1.0, 0.82, 0.35)
		draw_rect(Rect2(o + Vector2(-w * 0.5, -w * 0.02), Vector2(w, w * 0.2)), gold)
		for i in 5:
			var x := (i - 2) * w * 0.22
			var tall := i % 2 == 0
			var h := w * (0.48 if tall else 0.3)
			draw_colored_polygon(PackedVector2Array([o + Vector2(x - w * 0.09, 0), o + Vector2(x, -h), o + Vector2(x + w * 0.09, 0)]), gold)
			if tall:
				draw_circle(o + Vector2(x, -h), w * 0.06, Color(0.3, 1.0, 0.82))

	## A crystal or blade shard: a long diamond from `p` along `d`.
	func _shard(p: Vector2, d: Vector2, length: float, w: float, col: Color) -> void:
		var dd := d.normalized()
		var n := Vector2(-dd.y, dd.x) * w
		draw_colored_polygon(PackedVector2Array([p - dd * length * 0.2, p + n, p + dd * length, p - n]), col)

	## A feather: a pointed leaf from `p` along `d`.
	func _leaf(p: Vector2, d: Vector2, length: float, w: float, col: Color) -> void:
		var dd := d.normalized()
		var n := Vector2(-dd.y, dd.x)
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(p + dd * length * t + n * w * sin(t * PI))
		for i in range(7, 0, -1):
			var t := i / 8.0
			pts.append(p + dd * length * t - n * w * sin(t * PI))
		draw_colored_polygon(pts, col)

	## A flame standing on `p`, `h` tall.
	func _flame_icon(p: Vector2, h: float) -> void:
		draw_colored_polygon(PackedVector2Array([p + Vector2(-h * 0.3, 0), p + Vector2(0, -h), p + Vector2(h * 0.3, 0)]), Color(1.0, 0.5, 0.12))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-h * 0.15, 0), p + Vector2(0, -h * 0.6), p + Vector2(h * 0.15, 0)]), Color(1.0, 0.92, 0.45))

	## A flat ring seen from the side (a halo).
	func _ring(o: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 25:
			var ang := TAU * i / 24.0
			pts.append(o + Vector2(cos(ang) * rx, sin(ang) * ry))
		draw_polyline(pts, col, 2.5, true)

	## A black void orb with a violet glow.
	func _orb_icon(o: Vector2, rr: float) -> void:
		draw_circle(o, rr * 1.7, Color(0.6, 0.25, 1.0, 0.35))
		draw_circle(o, rr, Color(0.08, 0.03, 0.14))
		draw_circle(o + Vector2(-rr * 0.3, -rr * 0.3), rr * 0.3, Color(0.85, 0.65, 1.0))

	func _hold(c: Vector2, r: float) -> void:
		var steel := Color(0.78, 0.8, 0.86)
		var wood := Color(0.6, 0.4, 0.25)
		match finish:
			"gold":
				steel = Color(1.0, 0.84, 0.4)
				wood = Color(0.75, 0.5, 0.14)
			"frost":
				steel = Color(0.78, 0.95, 1.0)
				wood = Color(0.3, 0.6, 0.95)
			"ember":
				steel = Color(1.0, 0.55, 0.15)
				wood = Color(0.2, 0.15, 0.16)
			"void":
				steel = Color(0.66, 0.42, 1.0)
				wood = Color(0.2, 0.12, 0.38)
			"crypt":
				steel = Color(0.16, 0.13, 0.22)   # obsidian
				wood = Color(1.0, 0.8, 0.3)
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
			"tome", "open_tome", "fire_tome":
				parts = ["wand", shape]
			"ice_staff", "sun_staff", "scythe":
				parts = [shape]
			"magma_cleaver", "sun_hammer", "rift_blade", "magma_maul", "ram_mace", "moon_axe", "king_blade", "king_axe", "king_staff", "king_bow":
				parts = [shape]
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
				"tome", "open_tome", "fire_tome":
					var o := c + Vector2(r * 0.35, 0)
					if p == "fire_tome":
						# The burning grimoire (v230): dark red covers open in a V, gold corners,
						# a glowing rune on each page and fire rising off it.
						o.y += r * 0.32
						for sd: float in [-1.0, 1.0]:
							var cov := PackedVector2Array([o + Vector2(0, -r * 0.34), o + Vector2(sd * r * 0.66, -r * 0.42),
								o + Vector2(sd * r * 0.66, r * 0.36), o + Vector2(0, r * 0.42)])
							draw_colored_polygon(cov, Color(0.32, 0.07, 0.06))
							var pg := PackedVector2Array([o + Vector2(sd * r * 0.04, -r * 0.27), o + Vector2(sd * r * 0.54, -r * 0.33),
								o + Vector2(sd * r * 0.54, r * 0.27), o + Vector2(sd * r * 0.04, r * 0.33)])
							draw_colored_polygon(pg, Color(0.88, 0.64, 0.4))
							draw_arc(o + Vector2(sd * r * 0.29, 0), r * 0.13, 0, TAU, 16, Color(1.0, 0.5, 0.12), 2.0, true)
							for y: float in [-0.4, 0.36]:
								draw_rect(Rect2(o + Vector2(sd * r * 0.66 - r * 0.07, r * y - r * 0.06), Vector2(r * 0.14, r * 0.12)), Color(1.0, 0.82, 0.35))
						for f: Array in [[0.0, 0.95], [-0.3, 0.6], [0.3, 0.68]]:
							_flame_icon(o + Vector2(r * f[0], -r * 0.34), r * f[1])
					elif p == "tome":
						draw_rect(Rect2(o - Vector2(r * 0.38, r * 0.5), Vector2(r * 0.76, r)), Color(0.7, 0.2, 0.3))
					else:
						draw_rect(Rect2(o - Vector2(r * 0.6, r * 0.38), Vector2(r * 1.2, r * 0.76)), Color(0.95, 0.92, 0.85))
						draw_line(o + Vector2(0, -r * 0.38), o + Vector2(0, r * 0.38), Color(0.6, 0.5, 0.4), 2.0)
				"ice_staff", "sun_staff", "scythe":
					var h := c + Vector2(r * 0.24, -r * 0.72)
					if p == "ice_staff":
						# The glacier staff (v230): a shaft of ice, three ice claws round a great crystal.
						draw_line(c + Vector2(-r * 0.2, r), c + Vector2(r * 0.2, -r * 0.6), Color(0.5, 0.8, 0.97), r * 0.13)
						_shard(c + Vector2(-r * 0.2, r * 0.95), Vector2(-0.4, 1.0), r * 0.3, r * 0.07, steel)
						var ax := (h - (c + Vector2(-r * 0.2, r))).normalized()
						var nx := Vector2(-ax.y, ax.x)
						for sd: float in [-1.0, 0.0, 1.0]:
							var cl := PackedVector2Array([h - ax * r * 0.1, h + nx * sd * r * 0.32 + ax * r * 0.1,
								h + nx * sd * r * 0.28 + ax * r * 0.42, h + nx * sd * r * 0.1 + ax * r * 0.6])
							draw_polyline(cl, steel, r * 0.08, true)
						_shard(h + ax * r * 0.05, ax, r * 0.62, r * 0.14, Color(0.9, 0.98, 1.0))
						draw_line(h + ax * r * 0.05, h + ax * r * 0.5, Color.WHITE, 1.5)
					elif p == "sun_staff":
						# The sun scepter (v230): a white-gold shaft with gold bands, a gold cup, a sun.
						draw_line(c + Vector2(-r * 0.2, r), c + Vector2(r * 0.2, -r * 0.6), Color(1.0, 0.93, 0.75), r * 0.12)
						for t: float in [0.2, 0.5, 0.8]:
							draw_circle(c + Vector2(-r * 0.2, r).lerp(Vector2(r * 0.2, -r * 0.6), t), r * 0.09, steel)
						draw_circle(c + Vector2(-r * 0.2, r), r * 0.1, steel)
						h = c + Vector2(r * 0.3, -r * 0.82)
						for i in 12:
							var d := Vector2.from_angle(TAU * i / 12.0)
							var n := Vector2(-d.y, d.x) * r * 0.07
							var ray := r * (0.48 if i % 2 == 0 else 0.36)
							draw_colored_polygon(PackedVector2Array([h + d * r * 0.18 + n, h + d * ray, h + d * r * 0.18 - n]), steel)
						draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.05, -r * 0.5), c + Vector2(r * 0.42, -r * 0.62),
							c + Vector2(r * 0.3, -r * 0.42), c + Vector2(r * 0.17, -r * 0.38)]), steel)
						draw_arc(h, r * 0.22, 0, TAU, 20, wood, r * 0.07, true)
						draw_circle(h, r * 0.15, Color(1.0, 0.97, 0.85))
					else:
						# The reaper's scythe (v230): a crooked black shaft and a great curved blade.
						var sh := PackedVector2Array([c + Vector2(-r * 0.2, r), c + Vector2(-r * 0.05, r * 0.4),
							c + Vector2(r * 0.02, -r * 0.1), c + Vector2(r * 0.24, -r * 0.72)])
						draw_polyline(sh, Color(0.16, 0.09, 0.26), r * 0.13, true)
						for t: int in [1, 2]:
							draw_circle(sh[t], r * 0.08, Color(0.85, 0.7, 1.0))
						_shard(h, Vector2(1.0, 0.25), r * 0.3, r * 0.07, steel)
						var o := h + Vector2(-r * 0.62, r * 0.4)
						var pts := PackedVector2Array()
						var inner := PackedVector2Array()
						for i in 13:
							var t := i / 12.0
							var d := Vector2.from_angle(lerpf(-PI * 0.22, -PI * 0.98, t))
							pts.append(o + d * r * 0.8)
							inner.append(o + d * r * 0.8 * (0.96 - 0.36 * sin(PI * t)))
							if i > 0:
								draw_line(pts[i - 1], pts[i], Color(0.85, 0.7, 1.0), 2.0)
						inner.reverse()
						pts.append_array(inner)
						draw_colored_polygon(pts, Color(0.42, 0.24, 0.7))
						draw_circle(h, r * 0.15, Color(0.1, 0.05, 0.18))
						draw_circle(h, r * 0.07, Color(0.8, 0.6, 1.0))
				"magma_cleaver", "sun_hammer", "rift_blade", "magma_maul", "ram_mace", "moon_axe", "king_blade", "king_axe", "king_staff", "king_bow":
					_whole(p, c, r)
				"crossbow", "heavy":
					var w := r * (1.0 if p == "heavy" else 0.75)
					draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, -r * 0.6), wood, r * 0.14)
					if not (p == "heavy" and finish in ["gold", "void"]):   # (v231: wings or a portal for limbs)
						draw_arc(c + Vector2(0, -r * 0.1), w, PI * 1.15, PI * 1.85, 16, steel, r * 0.12, true)
				"knife", "knife2":
					var o := c + Vector2(r * 0.45 if p == "knife" else -r * 0.45, 0)
					draw_line(o + Vector2(0, r * 0.6), o + Vector2(0, -r * 0.5), steel, r * 0.14)
					draw_line(o + Vector2(-r * 0.18, r * 0.25), o + Vector2(r * 0.18, r * 0.25), wood, r * 0.1)
		if forged:
			_forged(c, r)
