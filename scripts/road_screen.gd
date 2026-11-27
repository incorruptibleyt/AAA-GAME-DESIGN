class_name RoadScreen
extends ColorRect
## The Bone Road screen (bone_road.gd): every step from the start to the last, the bones
## each needs and its reward. Steps reached show a gold CLAIM button.

signal claim(index: int)
## Version 399: every ready reward at once (a veteran had 32 CLAIM buttons to press).
signal claim_all
signal closed

const DIM := Color(0.6, 0.58, 0.66)
const TEXT := Color(0.88, 0.87, 0.92)
const DONE := Color(0.45, 0.85, 0.5)

var _count: Label
var _sub: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _prize_stage: HeroStage
var _prize_state: Label
var _all: Button


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 0.97)
	Hud.backdrop(self, "bone")
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
	# Version 125 (audit #8): clear of a notch, camera hole or rounded corners.
	visibility_changed.connect(func(): if visible: Hud.safe_pad(col))
	col.add_child(Hud.label("BONE ROAD", 44, Color(1, 0.85, 0.55)))
	_count = Hud.label("", 30, Hud.GOLD)
	col.add_child(_count)
	_sub = Hud.label("", 17, TEXT)
	col.add_child(_sub)
	col.add_child(_prize_panel())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(Hud.scroll_window(_scroll))   # version 227: the same window as the Armory
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)
	var back := Hud.button("BACK", 24)
	back.custom_minimum_size = Vector2(180, 72)   # version 122: BACK in the same corner on every screen
	back.pressed.connect(func():
		visible = false
		closed.emit())
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 12)
	box.add_child(back)
	_all = Hud.button("CLAIM ALL", 24, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_all.custom_minimum_size = Vector2(0, 72)
	_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_all.visible = false
	_all.pressed.connect(func(): claim_all.emit())
	box.add_child(_all)
	col.add_child(box)


## Version 254 (whole-game review fix 14): the road's last prize at the top, on a turning hero.
## The road used to end in 1,000 coins, with nothing to walk it for.
func _prize_panel() -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.05, 0.96)
	sb.border_color = Hud.GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 6
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	_prize_stage = HeroStage.new(Vector2(170, 196))
	_prize_stage.custom_minimum_size = Vector2(170, 196)
	_prize_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_prize_stage)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var pname := str(HeroStyle.extra(BoneRoad.prize()[0], BoneRoad.prize()[1]).name)
	v.add_child(Hud.label("FINAL PRIZE", 16, Hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(Hud.label("%s aura" % pname, 28, Color(1, 0.9, 0.7), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(Hud.label("Only on the Bone Road. In a run its bones burn gold, then red-hot, as your Bone Chain grows.", 15, TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_prize_state = Hud.label("", 16, Hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(_prize_state)
	visibility_changed.connect(func(): _prize_stage.set_active(visible))
	return panel


## Fills the screen from the save and shows it, scrolled to the first step to claim (or the
## next one to reach), also after a claim.
func open_road(cfg: ConfigFile) -> void:
	visible = true
	var last := int(BoneRoad.STEPS[-1].at)
	var b0 := BoneRoad.bones(cfg)
	_prize_state.text = "Yours! Wear it on the Style screen." if BoneRoad.has_prize(cfg) else \
		("Ready to claim!" if b0 >= last else "At %s bones  ·  %s to go" % [Hud.thousands(last), Hud.thousands(last - b0)])
	_prize_stage.show_hero(HeroStyle.dressed(Heroes.get_hero(Heroes.selected(cfg)), {"aura": BoneRoad.prize()[1]}))
	_prize_stage.set_active(true)
	# (queue_free: this runs inside a CLAIM button's own press, which must not be freed then)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var b := BoneRoad.bones(cfg)
	_count.text = "%s bones" % Hud.thousands(b)
	var ni := BoneRoad.next_index(cfg)
	var claimable := BoneRoad.ready_count(cfg)
	_all.visible = claimable >= 2
	_all.text = "CLAIM ALL %d" % claimable
	if claimable > 0:
		_sub.text = "%d reward%s ready to claim!" % [claimable, "" if claimable == 1 else "s"]
	elif ni < BoneRoad.STEPS.size():
		_sub.text = "Every room cleared adds a bone, a boss adds %d more.\nBones are never lost. Next reward at %d." % [BoneRoad.BOSS_BONES, int(BoneRoad.STEPS[ni].at)]
	else:
		_sub.text = "You walked the whole Bone Road!"
	var focus: Control = null
	for i in BoneRoad.STEPS.size():
		var row := _row(cfg, i, b)
		_list.add_child(row)
		if focus == null and (i == ni or (b >= int(BoneRoad.STEPS[i].at) and not BoneRoad.claimed(cfg, i))):
			focus = row
	if focus:
		_scroll_to(focus)


var _scroll_ask := 0


## Scrolls so `row` sits a third of the way down. Waits for the list to be laid out first:
## until then the rows' word-wrapped labels are taller than they will be, and the list
## scrolled far past the step it meant to show.
func _scroll_to(row: Control) -> void:
	_scroll_ask += 1
	var ask := _scroll_ask
	for i in 2:
		await get_tree().process_frame
	if ask != _scroll_ask or not is_instance_valid(row) or not visible:
		return
	_scroll.scroll_vertical = int(maxf(0.0, row.position.y - _scroll.size.y * 0.35))


func _row(cfg: ConfigFile, i: int, b: int) -> Control:
	var s: Dictionary = BoneRoad.STEPS[i]
	var reached := b >= int(s.at)
	var got := BoneRoad.claimed(cfg, i)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.13, 0.95) if not reached or got else Color(0.22, 0.16, 0.05, 0.97)
	sb.border_color = Hud.GOLD if reached and not got else (DONE.darkened(0.3) if got else Color(0.3, 0.28, 0.36))
	sb.set_border_width_all(3 if reached and not got else 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	# Version 363 (visual review v357 fix 5): a picture of the prize, not just its name.
	h.add_child(LookShots.prize_rect({"drop": "drop", "lucky": "lucky"}.get(str(s.kind), "coins"), 62, not reached))
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var what := Hud.label(BoneRoad.reward_text(s), 22, TEXT if reached else DIM, HORIZONTAL_ALIGNMENT_LEFT)
	texts.add_child(what)
	var need := ("Claimed" if got else "Ready!") if reached else "%d bones to go" % (int(s.at) - b)
	if s.kind == "lucky":
		# (Version 400: "890 bones to go Free blessing" ran together and wrapped.)
		need = (need + " Free blessing") if reached else "%d to go  ·  free blessing" % (int(s.at) - b)
	texts.add_child(Hud.label(need, 14, Hud.GOLD if reached and not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if reached and not got:
		var c := Hud.button("CLAIM", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
		c.custom_minimum_size = Vector2(100, 60)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.pressed.connect(func(): claim.emit(i))
		h.add_child(c)
	else:
		var tag := Hud.label("DONE" if got else "", 16, DONE)
		tag.custom_minimum_size = Vector2(70, 0)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(tag)
	# Version 398 (visual review of 388, fix 10, "the Bone Road is a plain list of coin
	# rows"): the road itself runs down the left, winding from stop to stop, walked in gold
	# as far as the bones reach; each stop's reward is a signpost beside it.
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 6)
	var stop := Stop.new()
	stop.index = i
	stop.bones = b
	stop.got = got
	line.add_child(stop)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(panel)
	return line


## One stop on the road and the stretch of road either side of it (half way to the stop
## before and the stop after; the next row draws the other half, so the road joins up).
class Stop extends Control:
	var index := 0
	var bones := 0
	var got := false
	const W := 86.0
	const GAP := 8.0   # the list's own gap between rows
	const ROAD := Color(0.24, 0.22, 0.3)
	const EDGE := Color(0.05, 0.04, 0.08)
	const WALKED := Color(0.95, 0.76, 0.3)
	var _num: Label

	func _init() -> void:
		custom_minimum_size = Vector2(W, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		var at := int(BoneRoad.STEPS[index].at)
		_num = Hud.label(str(at), 19 if at < 1000 else 16, Color.WHITE)
		_num.autowrap_mode = TextServer.AUTOWRAP_OFF
		_num.size = Vector2(60, 30)
		add_child(_num)
		resized.connect(_place)
		_place()

	static func _x(i: int) -> float:
		return 30.0 if i % 2 == 0 else W - 30.0

	func _place() -> void:
		_num.position = Vector2(_x(index) - 30.0, size.y * 0.5 - 16.0)
		queue_redraw()

	## How much of the road from stop `i` to the next one is walked (0 to 1).
	func _walked(i: int) -> float:
		var from := 0 if i < 0 else int(BoneRoad.STEPS[i].at)
		if i + 1 >= BoneRoad.STEPS.size():
			return 0.0
		var to := int(BoneRoad.STEPS[i + 1].at)
		return clampf(float(bones - from) / float(maxi(to - from, 1)), 0.0, 1.0)

	## A stretch of road through `pts`, the first `share` of it in gold.
	func _stretch(pts: PackedVector2Array, share: float) -> void:
		draw_polyline(pts, EDGE, 26.0, true)
		draw_polyline(pts, ROAD, 18.0, true)
		for k in range(1, pts.size(), 2):   # (pale stones down the middle)
			draw_circle(pts[k], 2.2, Color(0.5, 0.48, 0.58, 0.8))
		if share <= 0.0:
			return
		var gold := PackedVector2Array()
		var upto := share * float(pts.size() - 1)
		for k in pts.size():
			if float(k) <= upto:
				gold.append(pts[k])
			else:
				gold.append(pts[k - 1].lerp(pts[k], upto - float(k - 1)))
				break
		if gold.size() >= 2:
			draw_polyline(gold, WALKED.darkened(0.45), 18.0, true)
			draw_polyline(gold, WALKED, 10.0, true)
		if share < 1.0:   # (where you stand now: a bright marker)
			draw_circle(gold[-1], 9.0, EDGE)
			draw_circle(gold[-1], 6.5, Color(1.0, 0.97, 0.85))

	func _draw() -> void:
		var here := Vector2(_x(index), size.y * 0.5)
		var last := BoneRoad.STEPS.size() - 1
		# The road in: from half way down from the stop before (the very start for the first).
		var into := PackedVector2Array()
		var before := _walked(index - 1)
		for k in 9:
			var t := k / 8.0
			var sx := smoothstep(0.0, 1.0, 0.5 + 0.5 * t) if index > 0 else 1.0
			into.append(Vector2(lerpf(_x(index - 1), here.x, sx), lerpf(-GAP * 0.5, here.y, t)))
		_stretch(into, clampf(before * 2.0 - 1.0, 0.0, 1.0) if index > 0 else before)
		# The road out: half way to the next stop.
		if index < last:
			var out := PackedVector2Array()
			for k in 9:
				var t := k / 8.0
				out.append(Vector2(lerpf(here.x, _x(index + 1), smoothstep(0.0, 1.0, 0.5 * t)), lerpf(here.y, size.y + GAP * 0.5, t)))
			_stretch(out, clampf(_walked(index) * 2.0, 0.0, 1.0))
		# The stop itself: gold once reached, green once claimed.
		var reached := bones >= int(BoneRoad.STEPS[index].at)
		var face := (RoadScreen.DONE.darkened(0.35) if got else WALKED.darkened(0.2)) if reached else Color(0.2, 0.18, 0.26)
		if reached and not got:
			draw_circle(here, 31.0, Color(1.0, 0.85, 0.4, 0.3))
		draw_circle(here, 27.0, EDGE)
		draw_circle(here, 23.5, (RoadScreen.DONE if got else WALKED) if reached else Color(0.42, 0.4, 0.5))
		draw_circle(here, 20.0, face)
		if _num:
			_num.label_settings.font_color = Color.WHITE if reached else RoadScreen.DIM


## The Bone Road bar on the title: bones so far and how far to the next reward.
class Bar extends Button:
	var frac := 0.0
	var waiting := 0
	var _text: Label

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		flat = true
		# The words are a label on top (a button draws its own text under _draw's fill).
		_text = Hud.label("", 19, Color.WHITE)
		Hud.chunky(_text.label_settings)
		Hud.full(_text)
		_text.offset_bottom = -5   # centred on the face, above the lip
		add_child(_text)
		Hud.squash(self)

	## Version 399: the REWARDS screen's bar speaks as loud as the buttons around it.
	func big(px: int) -> void:
		_text.label_settings.font_size = px

	func set_road(bones: int, next_at: int, f: float, ready_n: int) -> void:
		frac = f
		waiting = ready_n
		if ready_n > 0:
			_text.text = "BONE ROAD: CLAIM!"
		elif next_at > 0:
			_text.text = "BONE ROAD  %d / %d" % [bones, next_at]
		else:
			_text.text = "BONE ROAD: DONE!"
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# A chunky dark trough with a lip (like the buttons), filled with bone-gold.
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.13, 0.1, 0.22)
		bg.border_color = Hud.ROLES.gold[1] if waiting > 0 else Hud.INK
		bg.set_border_width_all(3)
		bg.border_width_bottom = 8
		bg.set_corner_radius_all(18)
		bg.shadow_color = Color(0, 0, 0, 0.35)
		bg.shadow_size = 2
		bg.shadow_offset = Vector2(0, 4)
		draw_style_box(bg, r)
		var fill := StyleBoxFlat.new()
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0) if waiting > 0 else 0.0
		fill.bg_color = Hud.ROLES.gold[0].lightened(0.15 * pulse)
		fill.set_corner_radius_all(14)
		var inner := Rect2(4, 4, r.size.x - 8.0, r.size.y - 13.0)
		var w := inner.size.x * (1.0 if waiting > 0 else frac)
		if w > 8.0:
			draw_style_box(fill, Rect2(inner.position, Vector2(w, inner.size.y)))
			var shine := StyleBoxFlat.new()
			shine.bg_color = Color(1, 1, 1, 0.18)
			shine.set_corner_radius_all(10)
			draw_style_box(shine, Rect2(inner.position + Vector2(4, 3), Vector2(maxf(w - 8.0, 0.0), inner.size.y * 0.38)))

	func _process(_d: float) -> void:
		if waiting > 0 and is_visible_in_tree():
			queue_redraw()
