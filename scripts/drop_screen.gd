class_name DropScreen
extends ColorRect
## Opening Bone Drops (drops.gd): a bone reliquary sits in the middle of the screen. A tap
## shakes it while its glow climbs the colours (grey, green, blue, purple, gold) up to
## what's inside, then the lid flies off and the prize shows. Unopened drops stay saved.

signal closed

## Opens one drop and returns what was inside (Drops.open's result, or {} if none).
var opener: Callable

enum Step { CLOSED, OPENING, OPEN }

## When the glow climbs to the next colour, in seconds into the opening.
const CLIMB := [0.35, 0.62, 0.86, 1.06]
const OPEN_AT := 1.3

var _step := Step.CLOSED
var _t := 0.0
var _left := 0
var _result := {}
var _shown_tier := 0
var _flash := 0.0
var _pop := 0.0
var _art: Control
var _look: HeroStage   # a drop-only look found: the hero wearing it, in place of the box
var _chest: Chest
var _wear: Button
## Feats won this run, shown one by one like a found look (reveal_feats): [{name, look, hero}].
var _feat_queue: Array = []
var _feat_mode := false
## Wear a found look: (hero id, slot, key).
signal wear(id: String, slot: String, key: String)
var _head: Label
var _count: Label
var _rarity: Label
var _prize: Label
var _action: Button
var _later: Button
var _pity: Label
var _odds_btn: Button
var _odds: PanelContainer
var _odds_text: Label
var _odds_grid: GridContainer
var _odds_dim: ColorRect   # darkens the chest and its text behind the odds (version 119)


func _init() -> void:
	color = Color(0.02, 0.01, 0.04, 0.96)
	Hud.backdrop(self, "gold")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var col := VBoxContainer.new()
	Hud.full(col)
	col.offset_left = 20
	col.offset_right = -20
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	_head = Hud.label("BONE DROP", 46, Color(1, 0.85, 0.55))
	col.add_child(_head)
	_count = Hud.label("", 19, Color(0.8, 0.78, 0.85))
	col.add_child(_count)
	_pity = Hud.label("", 18, Color(0.55, 0.95, 1.0))
	col.add_child(_pity)
	_art = Control.new()
	_art.custom_minimum_size = Vector2(320, 320)
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	col.add_child(_art)
	# Version 116: a real 3D reliquary in the middle of the glow (it was drawn flat).
	_chest = Chest.new()
	Hud.full(_chest)
	_art.add_child(_chest)
	_look = HeroStage.new(Vector2(320, 320))
	_look.custom_minimum_size = Vector2(320, 320)
	_look.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_look.visible = false
	col.add_child(_look)
	MenuBackdrop.of(self).show_off([_art, _look], Vector2(0.5, 0.5), 0.8, 0.82)
	_rarity = Hud.label("", 34, Color.WHITE)
	col.add_child(_rarity)
	_prize = Hud.label("", 28, Hud.GOLD)
	_prize.custom_minimum_size = Vector2(0, 70)   # was 110: the rarity and prize read as one
	col.add_child(_prize)
	_action = Hud.button("TAP TO OPEN", 30, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_action.custom_minimum_size = Vector2(340, 86)
	_action.pressed.connect(_tap)
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_action)
	# WEAR IT is the big button above NEXT when a look is shown (version 119: it was the
	# smaller one underneath, so the action players want most came second).
	_wear = Hud.button("WEAR IT", 30, Color(0.05, 0.24, 0.12, 0.97), Color(0.5, 1.0, 0.65))
	_wear.custom_minimum_size = Vector2(340, 86)
	_wear.visible = false
	_wear.pressed.connect(_on_wear)
	_wear.visibility_changed.connect(func():
		_action.custom_minimum_size = Vector2(260, 64) if _wear.visible else Vector2(340, 86))
	var wbox := CenterContainer.new()
	wbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wbox.add_child(_wear)
	col.add_child(wbox)
	col.add_child(box)
	_later = Hud.button("LATER", 20, Color(0.1, 0.08, 0.12, 0.9), Color(0.6, 0.55, 0.6, 0.5))
	_later.custom_minimum_size = Vector2(200, 62)
	_later.pressed.connect(close)
	var box2 := CenterContainer.new()
	box2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box2.add_child(_later)
	col.add_child(box2)
	# "?": the odds of each kind, and the look guarantee.
	_odds_btn = Hud.button("?", 26, Color(0.12, 0.1, 0.16, 0.95), Color(0.6, 0.55, 0.7, 0.8))
	_odds_btn.custom_minimum_size = Vector2(64, 64)
	_odds_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_odds_btn.position = Vector2(-84, 24)
	_odds_btn.pressed.connect(func(): _show_odds(not _odds.visible))
	add_child(_odds_btn)
	# Version 125 (audit #8): the column and the "?" keep clear of a notch or camera hole.
	visibility_changed.connect(func():
		if visible:
			Hud.safe_pad(col)
			Hud.safe_pad(_odds_btn))
	_odds = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.09, 0.98)
	sb.border_color = Color(0.6, 0.55, 0.7, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	_odds.add_theme_stylebox_override("panel", sb)
	_odds.set_anchors_preset(Control.PRESET_CENTER)
	_odds.visible = false
	_odds.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_show_odds(false))
	_odds_text = Hud.label("", 16, Color(0.8, 0.78, 0.86), HORIZONTAL_ALIGNMENT_LEFT)
	_odds_text.custom_minimum_size = Vector2(400, 0)
	var odds_col := VBoxContainer.new()
	odds_col.add_theme_constant_override("separation", 14)
	var odds_head := Hud.label("WHAT'S INSIDE A BONE DROP", 22, Color(1, 0.85, 0.55))
	odds_head.autowrap_mode = TextServer.AUTOWRAP_OFF   # a wrapping label with no width grows one letter per line
	odds_col.add_child(odds_head)
	# Version 121: the odds as a table, each kind in its own colour (it was a wall of text).
	_odds_grid = GridContainer.new()
	_odds_grid.columns = 4
	_odds_grid.add_theme_constant_override("h_separation", 18)
	_odds_grid.add_theme_constant_override("v_separation", 8)
	odds_col.add_child(_odds_grid)
	odds_col.add_child(_odds_text)
	var close_b := Hud.button("CLOSE", 20)
	close_b.custom_minimum_size = Vector2(160, 60)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(func(): _show_odds(false))
	odds_col.add_child(close_b)
	_odds.add_child(odds_col)
	_odds_dim = ColorRect.new()
	_odds_dim.color = Color(0.0, 0.0, 0.02, 0.8)
	_odds_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_odds_dim.visible = false
	_odds_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_show_odds(false))
	add_child(_odds_dim)
	add_child(_odds)
	gui_input.connect(func(e: InputEvent):
		# (Touches arrive as mouse clicks too: Godot's emulate-mouse-from-touch.)
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_tap())


## Shows the screen with `waiting` drops to open.
func open_screen(waiting: int) -> void:
	_feat_mode = false
	_feat_queue.clear()
	_left = waiting
	visible = waiting > 0
	if visible:
		_ready_next()


func close() -> void:
	if not visible:
		return
	if _step == Step.OPENING:
		_finish()   # the prize was already given; show it before leaving
		return
	_show_look(false)
	_feat_mode = false
	_feat_queue.clear()
	visible = false
	closed.emit()


func _on_wear() -> void:
	var look: Array = _result.get("look", [])
	if look.size() < 2:
		return
	wear.emit(str(_result.get("hero", "")), str(look[0]), str(look[1]))
	_wear.text = "WEARING!"
	_wear.disabled = true
	Sfx.play("upgrade")


## A Feat's look gets the same big reveal as a lucky drop (version 116: it was a small
## toast only): the hero wearing it on the pedestal, its name, WEAR IT and NEXT.
func reveal_feats(list: Array) -> void:
	if list.is_empty():
		return
	_feat_queue = list.duplicate()
	_feat_mode = true
	visible = true
	_next_feat()


func _next_feat() -> void:
	var f: Dictionary = _feat_queue.pop_front()
	_result = {"kind": "look", "look": f.look, "hero": f.hero, "preview": f.preview, "tier": 4, "color": Color(0.5, 0.95, 1.0)}
	_step = Step.OPEN
	_t = 0.0
	_flash = 1.0
	_pop = 1.0
	_head.text = "FEAT DONE!"
	_head.label_settings.font_color = Color(0.5, 0.95, 1.0)
	_count.text = str(f.text)
	_pity.text = ""
	_rarity.text = str(f.name).to_upper()
	_rarity.label_settings.font_color = Hud.GOLD
	_prize.text = "NEW LOOK: %s\nEarned, never sold. Every hero can wear it." % str(f.label)
	_prize.label_settings.font_color = Color(0.75, 0.97, 1.0)
	_prize.label_settings.font_size = 22
	_show_look(true)
	_wear.visible = true
	_wear.disabled = false
	_wear.text = "WEAR IT"
	_action.text = "NEXT" if not _feat_queue.is_empty() else "DONE"
	_show_later(false)
	_odds_btn.visible = false
	Sfx.play("victory", 0.8)
	if Game.vibration:
		Input.vibrate_handheld(60)


## LATER fades out instead of leaving the layout (version 121: hiding it made the whole
## column drop 30 px the moment you tapped open).
func _show_later(on: bool) -> void:
	_later.modulate.a = 1.0 if on else 0.0
	_later.disabled = not on
	_later.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _show_look(on: bool) -> void:
	_look.visible = on
	_art.visible = not on
	_look.set_active(on)
	if on:
		_look.show_hero(_result.preview, false)


func _ready_next() -> void:
	_show_look(false)
	_wear.visible = false
	_odds_btn.visible = true
	_head.label_settings.font_color = Color(1, 0.85, 0.55)
	_chest.reset()
	_chest.check()
	_step = Step.CLOSED
	_t = 0.0
	_result = {}
	_shown_tier = 0
	_pop = 0.0
	_head.text = "BONE DROP"
	_count.text = "%d waiting" % _left if _left > 1 else "Earned by brave runs"
	_rarity.text = ""
	_prize.text = "What's inside?\nTap to find out."
	_prize.label_settings.font_color = Color(0.8, 0.78, 0.85)
	_prize.label_settings.font_size = 22
	_action.text = "TAP TO OPEN"
	_show_later(true)
	_update_pity()
	_art.queue_redraw()


func _show_odds(on: bool) -> void:
	_odds.visible = on
	_odds_dim.visible = on
	if on:
		var cfg := Game._load_save()
		_odds_text.text = Drops.odds_notes(cfg)
		for c in _odds_grid.get_children():
			_odds_grid.remove_child(c)
			c.queue_free()
		for h in ["KIND", "CHANCE", "COINS", "NEW LOOK"]:
			_odds_grid.add_child(Hud.label(h, 14, Color(0.6, 0.56, 0.68), HORIZONTAL_ALIGNMENT_LEFT if h == "KIND" else HORIZONTAL_ALIGNMENT_RIGHT))
		for r: Dictionary in Drops.odds_rows(cfg):
			var col: Color = r.color
			var name_l := Hud.label(str(r.name), 19, col, HORIZONTAL_ALIGNMENT_LEFT)
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_odds_grid.add_child(name_l)
			_odds_grid.add_child(Hud.label("%d%%" % int(r.chance), 19, Color(0.92, 0.9, 0.96), HORIZONTAL_ALIGNMENT_RIGHT))
			_odds_grid.add_child(Hud.label(str(r.coins), 19, Hud.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
			_odds_grid.add_child(Hud.label("%d%%" % int(r.look) if int(r.look) >= 0 else "-", 19, col.lightened(0.2) if int(r.look) >= 0 else Color(0.45, 0.42, 0.5), HORIZONTAL_ALIGNMENT_RIGHT))
		for c: Label in _odds_grid.get_children():
			c.autowrap_mode = TextServer.AUTOWRAP_OFF   # one line each, so the columns line up
		var vw := get_viewport_rect().size.x
		_odds_text.custom_minimum_size.x = minf(440.0, vw - 76.0)
		_odds.reset_size()
		_odds.position = (get_viewport_rect().size - _odds.size) * 0.5
		_place_odds.call_deferred()
	Sfx.play("click")


## The table's labels only know their size once laid out: size and centre the panel again
## a frame later, or it keeps the tall size it had while they were still wrapping.
func _place_odds() -> void:
	await get_tree().process_frame
	if not _odds.visible:
		return
	_odds.size = Vector2.ZERO
	_odds.reset_size()
	_odds.position = (get_viewport_rect().size - _odds.size) * 0.5


func _update_pity() -> void:
	_pity.text = Drops.pity_text(Game._load_save())


func _tap() -> void:
	if _odds.visible:
		_show_odds(false)
		return
	match _step:
		Step.CLOSED:
			_result = opener.call() if opener.is_valid() else {}
			if _result.is_empty():
				visible = false
				closed.emit()
				return
			_left -= 1
			_step = Step.OPENING
			_t = 0.0
			_show_later(false)
			_action.text = "OPENING"
			_action.modulate = Color(0.65, 0.65, 0.7)
			_prize.text = ""
			Sfx.play("click")
		Step.OPENING:
			if _t > 0.2:
				_finish()   # a second tap skips to the prize
		Step.OPEN:
			if _t < 0.35:
				return   # a quick double tap shouldn't open the next one by mistake
			if _feat_mode:
				if not _feat_queue.is_empty():
					_next_feat()
				else:
					_feat_mode = false
					close()
				return
			if _left > 0:
				_ready_next()
			else:
				close()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	_pop = move_toward(_pop, 0.0, delta * 2.5)
	if _step == Step.OPENING:
		var goal: int = _result.get("tier", 0)
		var reach := 0
		for at: float in CLIMB:
			if _t >= at:
				reach += 1
		reach = mini(reach, goal)
		if reach > _shown_tier:
			_shown_tier = reach
			_flash = 0.6
			Sfx.play("upgrade", 0.5, 0.8 + 0.15 * reach)
			if Game.vibration:
				Input.vibrate_handheld(25)
		if _t >= OPEN_AT:
			_finish()
	_chest.animate(_step, _t / OPEN_AT, _tier_color(), _shown_tier, delta)
	_art.queue_redraw()


func _finish() -> void:
	_step = Step.OPEN
	_action.modulate = Color.WHITE
	_t = 0.0
	_shown_tier = _result.get("tier", 0)
	_flash = 1.0
	_pop = 1.0
	var c: Color = _result.get("color", Color.WHITE)
	_head.text = "BONE DROP"
	_rarity.text = str(_result.get("name", ""))
	_rarity.label_settings.font_color = c
	_prize.text = str(_result.get("text", ""))
	_prize.label_settings.font_color = Hud.GOLD if _result.get("kind", "") == "coins" else c.lightened(0.35)
	_prize.label_settings.font_size = 34 if _result.get("kind", "") == "coins" else 22
	_chest.open_up(c, _shown_tier)
	# Version 122: Epic and Legendary get a bigger moment: the chest lifts and bursts twice
	# (three times for Legendary) under a beam, the screen flashes white, and a sting plays.
	if _shown_tier >= 3:
		_white_flash(0.85 if _shown_tier >= 4 else 0.5)
		Sfx.play("sting", 0.9)
	if _result.get("kind", "") == "look":
		_head.text = "NEW LOOK!"
		if _shown_tier >= 3:
			# Let the chest's moment play before the hero steps out wearing the look.
			var r := _result
			get_tree().create_timer(0.8).timeout.connect(func():
				if _step == Step.OPEN and _result == r and visible:
					_show_look(true))
		else:
			_show_look(true)
		_wear.visible = true
		_wear.disabled = false
		_wear.text = "WEAR IT"
	_count.text = "%d more waiting" % _left if _left > 0 else "All opened!"
	_update_pity()
	_action.text = "OPEN NEXT" if _left > 0 else "DONE"
	_show_later(_left > 0)
	Sfx.play("victory" if _shown_tier >= 3 else ("upgrade" if _shown_tier >= 1 else "coin"), 0.8)
	if _result.get("kind", "") == "coins":
		Sfx.play("coin", 0.6, 1.2)
	if Game.vibration:
		Input.vibrate_handheld(90 if _shown_tier >= 4 else (60 if _shown_tier >= 3 else 35))


var _white: ColorRect

func _white_flash(strength: float) -> void:
	if _white == null:
		_white = ColorRect.new()
		_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Hud.full(_white)
		add_child(_white)
	move_child(_white, get_child_count() - 1)
	_white.color = Color(1, 1, 1, strength)
	create_tween().tween_property(_white, "color:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- the reliquary

func _tier_color() -> Color:
	return Drops.TIERS[clampi(_shown_tier, 0, Drops.TIERS.size() - 1)].color


func _draw_art() -> void:
	var a := _art
	var c := a.size * 0.5
	var col := _tier_color()
	var open := _step == Step.OPEN
	var shake := Vector2.ZERO
	var tilt := 0.0
	if _step == Step.OPENING:
		var amp := 3.0 + 12.0 * clampf(_t / OPEN_AT, 0.0, 1.0)
		shake = Vector2(sin(_t * 55.0) * amp, cos(_t * 41.0) * amp * 0.4)
		tilt = sin(_t * 47.0) * 0.06 * amp / 15.0
	elif _step == Step.CLOSED:
		# A little hop now and then, asking to be opened.
		var hop := fmod(Time.get_ticks_msec() / 1000.0, 2.2)
		if hop < 0.35:
			shake.y = -sin(hop / 0.35 * PI) * 10.0
	var k := 1.0 + 0.18 * ease(_pop, 0.5)
	# Glow: soft rings of the current colour (brighter as it climbs, and on each step).
	var glow := 0.18 + 0.1 * _shown_tier + 0.4 * _flash
	if _step == Step.CLOSED:
		glow = 0.12
	for i in 7:
		var r := (150.0 - i * 16.0) * k
		var g := col
		g.a = glow * (0.12 + 0.1 * i)
		a.draw_circle(c, r, g)
	# Rays once it's open, turning slowly.
	if open:
		var spin := Time.get_ticks_msec() / 1000.0 * 0.5
		var ray := col
		ray.a = 0.22 + 0.25 * _flash
		for i in 12:
			var ang := spin + TAU * i / 12.0
			var d1 := Vector2.from_angle(ang - 0.09)
			var d2 := Vector2.from_angle(ang + 0.09)
			a.draw_colored_polygon(PackedVector2Array([c, c + d1 * 165.0 * k, c + d2 * 165.0 * k]), ray)
	# (The reliquary itself is the 3D Chest below, version 116.)
	var _unused := shake + Vector2(tilt, 0)
	# The whole screen flashes the colour as it climbs and opens.
	if _flash > 0.0:
		var fl := col
		fl.a = _flash * 0.35
		a.draw_circle(c, 170.0, fl)


## A pile of coins, a star (Lucky Start) or an arrow (a free Armory level).
func _prize_icon(a: Control, p: Vector2, kind: String, col: Color) -> void:
	var gold := Color(1.0, 0.8, 0.3)
	var edge := Color(0.55, 0.36, 0.08)
	match kind:
		"lucky":
			var pts := PackedVector2Array()
			for i in 10:
				var r := 30.0 if i % 2 == 0 else 13.0
				pts.append(p + Vector2.from_angle(-PI / 2 + TAU * i / 10.0) * r)
			a.draw_colored_polygon(pts, Color.WHITE.lerp(col, 0.25))
			pts.append(pts[0])
			a.draw_polyline(pts, col.darkened(0.5), 3.0)
		"armory":
			var arrow := PackedVector2Array([p + Vector2(0, -30), p + Vector2(26, -2), p + Vector2(11, -2),
					p + Vector2(11, 28), p + Vector2(-11, 28), p + Vector2(-11, -2), p + Vector2(-26, -2)])
			a.draw_colored_polygon(arrow, gold)
			arrow.append(arrow[0])
			a.draw_polyline(arrow, edge, 3.0)
		_:
			for c: Vector2 in [Vector2(-22, 12), Vector2(22, 12), Vector2(0, -6)]:
				a.draw_circle(p + c, 19.0, edge)
				a.draw_circle(p + c, 16.0, gold)
				a.draw_circle(p + c, 9.0, gold.lightened(0.3))


func _box(a: Control, r: Rect2, fill: Color, edge: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(radius)
	a.draw_style_box(sb, r)
	# Bone-coloured corner studs.
	for p in [r.position + Vector2(14, 14), r.position + Vector2(r.size.x - 14, 14),
			r.position + Vector2(14, r.size.y - 14), r.position + r.size - Vector2(14, 14)]:
		a.draw_circle(p, 5.0, edge.lightened(0.25))


# ---------------------------------------------------------------- the 3D reliquary

## The Bone Drop's reliquary in 3D: a bone chest with iron bands and a skull on the front.
## Closed, it hops now and then; opening, it shakes harder as cracks of light in the
## rarity's colour split it; open, the lid flies back and a beam of that colour rises.
class Chest extends SubViewportContainer:
	var _vp: SubViewport
	var _root: Node3D
	var _lid: Node3D
	var _seam: StandardMaterial3D
	var _crack_mat: StandardMaterial3D
	var _cracks: Array[MeshInstance3D] = []
	var _beam: MeshInstance3D
	var _beam_mat: StandardMaterial3D
	var _light: OmniLight3D
	var _trim: StandardMaterial3D
	var _gem_mat: StandardMaterial3D
	var _burst: CPUParticles3D
	var _burst_mat: StandardMaterial3D
	var _ring: MeshInstance3D
	var _ring_mat: StandardMaterial3D
	var _open := 0.0
	var _opened := false
	var _hop := 0.0

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.msaa_3d = Viewport.MSAA_2X
		_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		add_child(_vp)
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.55, 2.7)
		cam.fov = 40.0
		_vp.add_child(cam)
		cam.look_at_from_position(cam.position, Vector3(0, 0.72, 0))   # the chest a little lower, room for the lid (and the Epic lift)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.5, 0)
		sun.light_energy = 0.9
		_vp.add_child(sun)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.5, 0.45, 0.6)
		env.environment.ambient_light_energy = 0.7
		_vp.add_child(env)
		_build()

	func _build() -> void:
		# Version 119: a modelled reliquary (domed lid, rib bones, iron corner caps, a skull
		# with eyes and a gem in the drop's colour, gold trim at higher rarity) instead of
		# plain boxes; a rim light from behind and a burst of sparks when it opens.
		_root = Node3D.new()
		_vp.add_child(_root)
		var bone := StandardMaterial3D.new()
		bone.albedo_color = Color(0.8, 0.73, 0.6)
		bone.roughness = 0.65
		bone.rim_enabled = true
		bone.rim = 0.25
		bone.rim_tint = 0.7
		var bone_dark := bone.duplicate() as StandardMaterial3D
		bone_dark.albedo_color = Color(0.36, 0.3, 0.26)
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.17, 0.14, 0.18)
		iron.metallic = 0.7
		iron.roughness = 0.3
		_trim = StandardMaterial3D.new()
		_trim.albedo_color = Color(0.3, 0.27, 0.3)
		_trim.metallic = 0.85
		_trim.roughness = 0.25
		var dark := StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.albedo_color = Color(0.04, 0.03, 0.05)
		_seam = StandardMaterial3D.new()
		_seam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_seam.albedo_color = Color.WHITE
		_crack_mat = _seam.duplicate()
		_gem_mat = _seam.duplicate()
		# A stepped iron plinth, then the bone body with a darker inset panel.
		_box(_root, Vector3(1.36, 0.1, 0.92), iron, Vector3(0, 0.05, 0))
		_box(_root, Vector3(1.2, 0.58, 0.78), bone, Vector3(0, 0.39, 0))
		_box(_root, Vector3(0.98, 0.42, 0.02), bone_dark, Vector3(0, 0.39, 0.392))
		# Rib bones across the front, like a ribcage.
		var rib := CapsuleMesh.new()
		rib.radius = 0.03
		rib.height = 0.5
		for i in 3:
			for sd in [-1.0, 1.0]:
				var r := _mesh(_root, rib, bone, Vector3(sd * 0.3, 0.25 + i * 0.13, 0.405))
				r.rotation = Vector3(0, 0, sd * (1.25 - i * 0.12))
		# Iron corner caps and gold-able trim bands.
		for x in [-0.58, 0.58]:
			for z in [-0.37, 0.37]:
				_box(_root, Vector3(0.1, 0.62, 0.1), iron, Vector3(x, 0.39, z))
				var stud := SphereMesh.new()
				stud.radius = 0.05
				stud.height = 0.1
				_mesh(_root, stud, _trim, Vector3(x * 1.02, 0.68, z * 1.02))
		_box(_root, Vector3(1.24, 0.05, 0.82), _trim, Vector3(0, 0.12, 0))
		# The skull on the front: cranium, jaw, glowing eyes and a gem on the brow.
		var cranium := SphereMesh.new()
		cranium.radius = 0.17
		cranium.height = 0.32
		_mesh(_root, cranium, bone, Vector3(0, 0.44, 0.43)).scale = Vector3(1.0, 0.95, 0.7)
		_box(_root, Vector3(0.18, 0.08, 0.1), bone, Vector3(0, 0.3, 0.45))
		var eye := SphereMesh.new()
		eye.radius = 0.05
		eye.height = 0.1
		for x in [-0.065, 0.065]:
			_mesh(_root, eye, dark, Vector3(x, 0.44, 0.535))
			_mesh(_root, eye, _crack_mat, Vector3(x, 0.44, 0.56)).scale = Vector3(0.45, 0.45, 0.45)
		var gem := SphereMesh.new()
		gem.radius = 0.07
		gem.height = 0.14
		gem.radial_segments = 6
		gem.rings = 2
		_mesh(_root, gem, _gem_mat, Vector3(0, 0.6, 0.5)).scale = Vector3(1.0, 1.3, 0.6)
		# The glowing seam under the lid.
		_box(_root, Vector3(1.22, 0.035, 0.8), _seam, Vector3(0, 0.675, 0))
		# Cracks of light on the front, one more for each step up in rarity.
		var crack_at := [Vector3(-0.38, 0.3, 0.41), Vector3(0.38, 0.5, 0.41), Vector3(-0.38, 0.55, 0.41), Vector3(0.38, 0.22, 0.41)]
		for i in crack_at.size():
			var c := _box(_root, Vector3(0.025, 0.22, 0.01), _crack_mat, crack_at[i])
			c.rotation.z = [0.6, -0.5, -0.9, 0.8][i]
			c.visible = false
			_cracks.append(c)
		# The domed lid, hinged at the back: half a barrel of bone with iron hoops and a
		# skull-knob handle.
		_lid = Node3D.new()
		_lid.position = Vector3(0, 0.68, -0.4)
		_root.add_child(_lid)
		var dome := CylinderMesh.new()
		dome.top_radius = 0.4
		dome.bottom_radius = 0.4
		dome.height = 1.24
		dome.radial_segments = 20
		var d := _mesh(_lid, dome, bone, Vector3(0, 0.0, 0.4))
		d.rotation.z = PI * 0.5
		d.scale = Vector3(0.55, 1.0, 1.0)
		for x in [-0.42, 0.0, 0.42]:
			var hoop := CylinderMesh.new()
			hoop.top_radius = 0.42
			hoop.bottom_radius = 0.42
			hoop.height = 0.07
			hoop.radial_segments = 20
			var h := _mesh(_lid, hoop, _trim if x == 0.0 else iron, Vector3(x, 0.0, 0.4))
			h.rotation.z = PI * 0.5
			h.scale = Vector3(0.57, 1.0, 1.02)
		var knob := SphereMesh.new()
		knob.radius = 0.1
		knob.height = 0.2
		_mesh(_lid, knob, bone, Vector3(0, 0.26, 0.4))
		# The beam of light, shown once it opens.
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var bm := CylinderMesh.new()
		bm.top_radius = 0.75
		bm.bottom_radius = 0.48
		bm.height = 2.4
		bm.cap_top = false
		bm.cap_bottom = false
		_beam = _mesh(_root, bm, _beam_mat, Vector3(0, 1.85, 0))
		_beam.visible = false
		_light = OmniLight3D.new()
		_light.position = Vector3(0, 0.9, 0.6)
		_light.omni_range = 3.0
		_light.light_energy = 0.0
		_root.add_child(_light)
		# A cool rim light from behind, so the chest stands out from the dark.
		var rim := OmniLight3D.new()
		rim.position = Vector3(0.6, 1.4, -1.4)
		rim.omni_range = 4.0
		rim.light_color = Color(0.6, 0.5, 1.0)
		rim.light_energy = 1.4
		_vp.add_child(rim)
		# The burst: sparks thrown up and out when the lid flies off.
		_burst = CPUParticles3D.new()
		_burst.emitting = false
		_burst.one_shot = true
		_burst.explosiveness = 0.95
		_burst.amount = 60
		_burst.lifetime = 1.1
		_burst.position = Vector3(0, 0.75, 0)
		_burst.direction = Vector3.UP
		_burst.spread = 70.0
		_burst.initial_velocity_min = 2.5
		_burst.initial_velocity_max = 5.0
		_burst.gravity = Vector3(0, -6.0, 0)
		_burst.scale_amount_min = 0.5
		_burst.scale_amount_max = 1.2
		var spark := SphereMesh.new()
		spark.radius = 0.035
		spark.height = 0.07
		spark.radial_segments = 6
		spark.rings = 3
		_burst_mat = _seam.duplicate()
		spark.material = _burst_mat
		_burst.mesh = spark
		_root.add_child(_burst)
		# A ring of light on the floor that races outward on opening.
		_ring_mat = _beam_mat.duplicate()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.9
		ring.outer_radius = 1.0
		ring.rings = 32
		ring.ring_segments = 6
		_ring = _mesh(_root, ring, _ring_mat, Vector3(0, 0.05, 0))
		_ring.scale = Vector3(1, 0.2, 1)
		_ring.visible = false

	func _box(parent: Node3D, size_v: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
		var b := BoxMesh.new()
		b.size = size_v
		return _mesh(parent, b, mat, pos)

	func _mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = pos
		parent.add_child(mi)
		return mi

	## Like the hero preview (version 121): a moment after it first shows, look at the
	## picture. If nothing in it is solid (this phone draws see-through pictures wrong), draw
	## the chest on the screen's own dark colour from then on, and say so in the reports.
	static var _seen_ok := false
	static var _solid := false
	var _checking := false

	func check() -> void:
		if _seen_ok or _checking or DisplayServer.get_name() == "headless":
			return
		_checking = true
		for i in 20:
			await RenderingServer.frame_post_draw
		_checking = false
		if not is_inside_tree() or not is_visible_in_tree():
			return
		var img := _vp.get_texture().get_image()
		var solid_px := 0
		var lit_px := 0
		if img and not img.is_empty():
			var w := img.get_width()
			var h := img.get_height()
			for y in range(h / 4, h, 8):
				for x in range(w / 4, w * 3 / 4, 8):
					var c := img.get_pixel(x, y)
					if c.a > 0.3:
						solid_px += 1
					elif c.r + c.g + c.b > 0.12:
						lit_px += 1
		if solid_px > 6:
			_seen_ok = true
			return
		if not _solid:
			_solid = true
			_use_solid()
		push_error("Bone Drop chest showed %s (%s); switched to a solid backdrop" % ["clear" if lit_px > 6 else "empty", _vp.size])

	func _use_solid() -> void:
		_vp.transparent_bg = false
		for n in _vp.get_children():
			if n is WorldEnvironment:
				n.environment.background_mode = Environment.BG_COLOR
				n.environment.background_color = Color(0.02, 0.01, 0.04)

	func reset() -> void:
		if _solid and _vp.transparent_bg:
			_use_solid()
		_lift = 0.0
		_lift_to = 0.0
		_opened = false
		_open = 0.0
		_lid.rotation = Vector3.ZERO
		_lid.position = Vector3(0, 0.68, -0.4)
		_beam.visible = false
		_light.light_energy = 0.0
		for c in _cracks:
			c.visible = false
		_ring.visible = false
		_root.rotation = Vector3(0, -0.35, 0)
		_root.position = Vector3.ZERO

	var _lift := 0.0
	var _lift_to := 0.0

	func open_up(col: Color, tier := 0) -> void:
		_opened = true
		_open = 0.0
		_lift_to = 0.12 if tier >= 3 else 0.0
		_beam.visible = true
		_beam_mat.albedo_color = Color(col, 0.35)
		for wave in ([0.35, 0.7] if tier >= 4 else ([0.35] if tier >= 3 else [])):
			get_tree().create_timer(wave).timeout.connect(func():
				if _opened and is_inside_tree():
					_burst.restart()
					_burst.emitting = true
					_ring.visible = true
					_ring.scale = Vector3(0.3, 0.2, 0.3))
		_light.light_color = col
		_light.light_energy = 1.5
		_burst_mat.albedo_color = col.lightened(0.35) * 1.6
		_burst.restart()
		_burst.emitting = true
		_ring.visible = true
		_ring.scale = Vector3(0.3, 0.2, 0.3)
		_ring_mat.albedo_color = Color(col, 0.8)

	func animate(step: int, k: float, col: Color, tier: int, delta: float) -> void:
		_seam.albedo_color = col.lightened(0.3) * (1.0 + 0.6 * float(tier))
		_crack_mat.albedo_color = col.lightened(0.4) * 1.6
		_gem_mat.albedo_color = col.lightened(0.2) * (1.2 + 0.3 * float(tier))
		# Iron trim at Common, turning gold as the rarity climbs.
		_trim.albedo_color = Color(0.3, 0.27, 0.3).lerp(Color(1.0, 0.78, 0.3), clampf(float(tier) / 4.0, 0.0, 1.0))
		var t := Time.get_ticks_msec() / 1000.0
		_root.position = Vector3.ZERO
		_root.rotation = Vector3(0, -0.35 + sin(t * 0.6) * 0.12, 0)
		if step == 0:   # closed: a hop now and then
			var hop := fmod(t, 2.2)
			if hop < 0.35:
				_root.position.y = sin(hop / 0.35 * PI) * 0.12
		elif step == 1:   # opening: shaking harder, cracks appearing
			var amp := 0.02 + 0.07 * clampf(k, 0.0, 1.0)
			_root.rotation.z = sin(t * 52.0) * amp * 2.0
			_root.position.x = sin(t * 61.0) * amp
			_lid.rotation.x = -absf(sin(t * 30.0)) * amp * 2.0
			for i in _cracks.size():
				_cracks[i].visible = i < tier
			_light.light_color = col
			_light.light_energy = 0.4 * float(tier)
		elif _opened:
			_open = minf(1.0, _open + delta * 3.0)
			var e := ease(_open, 0.4)
			# Version 121: a smaller swing and rise, so the open lid stays inside the picture.
			_lid.rotation.x = -1.35 * e
			_lid.position = Vector3(0, 0.68 + 0.12 * e, -0.4 - 0.15 * e)
			_beam.scale = Vector3(1, 0.2 + 0.8 * e, 1)
			_beam_mat.albedo_color = Color(col, 0.22 + 0.1 * sin(t * 4.0))
			if _ring.visible:
				var rs := _ring.scale.x + delta * 6.0
				_ring.scale = Vector3(rs, 0.2, rs)
				_ring_mat.albedo_color = Color(col, maxf(0.0, 0.8 - (rs - 0.3) * 0.25))
				if rs > 3.6:
					_ring.visible = false
			for c in _cracks:
				c.visible = true
			_lift = move_toward(_lift, _lift_to, delta * 1.2)
			_root.position.y += _lift
