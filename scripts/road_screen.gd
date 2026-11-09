class_name RoadScreen
extends ColorRect
## The Bone Road screen (bone_road.gd): every step from the start to the last, the bones
## each needs and its reward. Steps reached show a gold CLAIM button.

signal claim(index: int)
signal closed

const DIM := Color(0.6, 0.58, 0.66)
const TEXT := Color(0.88, 0.87, 0.92)
const DONE := Color(0.45, 0.85, 0.5)

var _count: Label
var _sub: Label
var _scroll: ScrollContainer
var _list: VBoxContainer


func _init() -> void:
	color = Color(0.03, 0.02, 0.05, 0.97)
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
	col.add_child(Hud.label("BONE ROAD", 44, Color(1, 0.85, 0.55)))
	_count = Hud.label("", 30, Hud.GOLD)
	col.add_child(_count)
	_sub = Hud.label("", 17, TEXT)
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
	back.pressed.connect(func():
		visible = false
		closed.emit())
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(back)
	col.add_child(box)


## Fills the screen from the save and shows it, scrolled to the first step to claim (or the
## next one to reach), also after a claim.
func open_road(cfg: ConfigFile) -> void:
	visible = true
	# (queue_free: this runs inside a CLAIM button's own press, which must not be freed then)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var b := BoneRoad.bones(cfg)
	_count.text = "%s bones" % Hud.thousands(b)
	var ni := BoneRoad.next_index(cfg)
	var claimable := BoneRoad.ready_count(cfg)
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
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var at := Hud.label(str(int(s.at)), 24, Hud.GOLD if reached else DIM)
	at.custom_minimum_size = Vector2(64, 0)
	at.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(at)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	h.add_child(texts)
	var what := Hud.label(BoneRoad.reward_text(s), 22, TEXT if reached else DIM, HORIZONTAL_ALIGNMENT_LEFT)
	texts.add_child(what)
	var need := ("Claimed" if got else "Ready!") if reached else "%d bones to go" % (int(s.at) - b)
	if s.kind == "lucky":
		need += "  ·  free blessing"
	texts.add_child(Hud.label(need, 14, Hud.GOLD if reached and not got else DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if reached and not got:
		var c := Hud.button("CLAIM", 20, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
		c.custom_minimum_size = Vector2(118, 56)
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.pressed.connect(func(): claim.emit(i))
		h.add_child(c)
	else:
		var tag := Hud.label("DONE" if got else "", 16, DONE)
		tag.custom_minimum_size = Vector2(118, 0)
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(tag)
	return panel


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
