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
var _chest: Reliquary
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
## Moon Caskets (events.gd, version 134) open here too, with the event's name and colours.
var casket := false


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
	_art.custom_minimum_size = Vector2(440, 420)
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_art)
	col.add_child(_art)
	# Version 116: a real 3D reliquary in the middle of the glow (it was drawn flat);
	# version 137: the chained bone reliquary (scripts/reliquary.gd), bigger.
	_chest = Reliquary.new()
	Hud.full(_chest)
	# Its picture reaches past the art box (the lid, the beam and the plinth's edge), so
	# nothing is cut off by a straight line.
	_chest.offset_top = -110
	_chest.offset_bottom = 30
	_chest.offset_left = -50
	_chest.offset_right = 50
	_art.add_child(_chest)
	_look = HeroStage.new(Vector2(320, 320))
	_look.custom_minimum_size = Vector2(440, 420)   # the chest's size, so nothing jumps
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
func open_screen(waiting: int, is_casket := false) -> void:
	casket = is_casket
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
		# Version 131: the new look is shown off (a spin, the camera in close on it, the
		# glow flaring), so a glow or a small hat can't go unnoticed.
		var look: Array = _result.get("look", [])
		if look.size() >= 2:
			_look.reveal(str(look[0]))


func _ready_next() -> void:
	_show_look(false)
	_wear.visible = false
	_odds_btn.visible = true
	_head.label_settings.font_color = Color(1, 0.85, 0.55)
	_chest.casket_look(casket)
	_chest.reset()
	_chest.check()
	_step = Step.CLOSED
	_t = 0.0
	_result = {}
	_shown_tier = 0
	_pop = 0.0
	_head.text = "MOON CASKET" if casket else "BONE DROP"
	_count.text = "%d waiting" % _left if _left > 1 else ("Won in the Blood Moon" if casket else "Earned by brave runs")
	if casket:
		_head.label_settings.font_color = Color(1.0, 0.42, 0.36)
		_odds_btn.visible = false
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
	_pity.text = "" if casket else Drops.pity_text(Game._load_save())


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
	_head.text = "MOON CASKET" if casket else "BONE DROP"
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


static var _soft: GradientTexture2D

## A soft round glow (bright middle, fading to nothing), drawn tinted.
static func _soft_glow() -> GradientTexture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 128
		_soft.height = 128
	return _soft


## Behind the 3D chest (version 137: soft light, not flat rings): a halo of the current
## colour that swells as the rarity climbs, and soft rays turning once it's open.
func _draw_art() -> void:
	var a := _art
	var c := a.size * 0.5 + Vector2(0, -10)
	var col := _tier_color()
	var open := _step == Step.OPEN
	var k := 1.0 + 0.18 * ease(_pop, 0.5)
	var glow := 0.3 + 0.12 * _shown_tier + 0.45 * _flash
	if _step == Step.CLOSED:
		glow = 0.16 + 0.04 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		col = Color(1.0, 0.3, 0.25) if casket else Color(0.6, 0.5, 1.0)
	var r := 210.0 * k
	a.draw_texture_rect(_soft_glow(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col, glow))
	if open:
		var spin := Time.get_ticks_msec() / 1000.0 * 0.35
		var tip := Color(col, 0.0)
		var base := Color(col.lightened(0.3), 0.3 + 0.3 * _flash)
		for i in 14:
			var ang := spin + TAU * i / 14.0
			var len := (230.0 if i % 2 == 0 else 170.0) * k
			var w := 0.07 if i % 2 == 0 else 0.05
			a.draw_polygon(PackedVector2Array([c, c + Vector2.from_angle(ang - w) * len, c + Vector2.from_angle(ang + w) * len]),
					PackedColorArray([base, tip, tip]))
	# The colour flashes as it climbs and opens.
	if _flash > 0.0:
		var fr := 240.0
		a.draw_texture_rect(_soft_glow(), Rect2(c - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(col.lightened(0.4), _flash * 0.6))


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
