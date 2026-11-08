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


func _init() -> void:
	color = Color(0.02, 0.01, 0.04, 0.96)
	Hud.backdrop(self)
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
	_rarity = Hud.label("", 34, Color.WHITE)
	col.add_child(_rarity)
	_prize = Hud.label("", 28, Hud.GOLD)
	_prize.custom_minimum_size = Vector2(0, 110)
	col.add_child(_prize)
	_action = Hud.button("TAP TO OPEN", 30, Color(0.3, 0.2, 0.06, 0.97), Hud.GOLD)
	_action.custom_minimum_size = Vector2(340, 86)
	_action.pressed.connect(_tap)
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_action)
	col.add_child(box)
	_wear = Hud.button("WEAR IT", 24, Color(0.05, 0.2, 0.12, 0.97), Color(0.5, 1.0, 0.65))
	_wear.custom_minimum_size = Vector2(260, 70)
	_wear.visible = false
	_wear.pressed.connect(_on_wear)
	var wbox := CenterContainer.new()
	wbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wbox.add_child(_wear)
	col.add_child(wbox)
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
	_odds_text = Hud.label("", 18, Color(0.9, 0.88, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_odds_text.custom_minimum_size = Vector2(400, 0)
	_odds.add_child(_odds_text)
	add_child(_odds)
	gui_input.connect(func(e: InputEvent):
		# (Touches arrive as mouse clicks too: Godot's emulate-mouse-from-touch.)
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_tap())


## Shows the screen with `waiting` drops to open.
func open_screen(waiting: int) -> void:
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
	_later.visible = false
	_odds_btn.visible = false
	Sfx.play("victory", 0.8)
	if Game.vibration:
		Input.vibrate_handheld(60)


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
	_later.visible = true
	_update_pity()
	_art.queue_redraw()


func _show_odds(on: bool) -> void:
	_odds.visible = on
	if on:
		_odds_text.text = Drops.odds_text(Game._load_save())
		var vw := get_viewport_rect().size.x
		_odds_text.custom_minimum_size.x = minf(440.0, vw - 76.0)
		_odds.reset_size()
		_odds.position = (get_viewport_rect().size - _odds.size) * 0.5
	Sfx.play("click")


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
			_later.visible = false
			_action.text = "..."
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
	_chest.open_up(c)
	if _result.get("kind", "") == "look":
		_head.text = "NEW LOOK!"
		_show_look(true)
		_wear.visible = true
		_wear.disabled = false
		_wear.text = "WEAR IT"
	_count.text = "%d more waiting" % _left if _left > 0 else "All opened!"
	_update_pity()
	_action.text = "OPEN NEXT" if _left > 0 else "DONE"
	_later.visible = _left > 0
	Sfx.play("victory" if _shown_tier >= 3 else ("upgrade" if _shown_tier >= 1 else "coin"), 0.8)
	if _result.get("kind", "") == "coins":
		Sfx.play("coin", 0.6, 1.2)
	if Game.vibration:
		Input.vibrate_handheld(60 if _shown_tier >= 3 else 35)


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
		cam.look_at_from_position(cam.position, Vector3(0, 0.45, 0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.5, 0)
		sun.light_energy = 1.1
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
		_root = Node3D.new()
		_vp.add_child(_root)
		var bone := StandardMaterial3D.new()
		bone.albedo_color = Color(0.9, 0.86, 0.76)
		bone.roughness = 0.6
		bone.rim_enabled = true
		bone.rim = 0.3
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.16, 0.13, 0.16)
		iron.metallic = 0.6
		iron.roughness = 0.35
		var dark := StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.albedo_color = Color(0.04, 0.03, 0.05)
		_seam = StandardMaterial3D.new()
		_seam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_seam.albedo_color = Color.WHITE
		_crack_mat = _seam.duplicate()
		# Body, two iron bands, iron feet.
		_box(_root, Vector3(1.2, 0.62, 0.78), bone, Vector3(0, 0.35, 0))
		for x in [-0.36, 0.36]:
			_box(_root, Vector3(0.1, 0.66, 0.82), iron, Vector3(x, 0.35, 0))
		for x in [-0.52, 0.52]:
			for z in [-0.3, 0.3]:
				_box(_root, Vector3(0.16, 0.08, 0.16), iron, Vector3(x, 0.03, z))
		# The skull on the front, with its two dark eyes.
		var skull := SphereMesh.new()
		skull.radius = 0.16
		skull.height = 0.32
		_mesh(_root, skull, bone, Vector3(0, 0.4, 0.4)).scale = Vector3(1, 1, 0.6)
		var eye := SphereMesh.new()
		eye.radius = 0.045
		eye.height = 0.09
		for x in [-0.06, 0.06]:
			_mesh(_root, eye, dark, Vector3(x, 0.42, 0.49))
		# The glowing seam under the lid.
		_box(_root, Vector3(1.22, 0.035, 0.8), _seam, Vector3(0, 0.665, 0))
		# Cracks of light on the front, one more for each step up in rarity.
		var crack_at := [Vector3(-0.2, 0.3, 0.392), Vector3(0.18, 0.5, 0.392), Vector3(-0.15, 0.55, 0.392), Vector3(0.2, 0.2, 0.392)]
		for i in crack_at.size():
			var c := _box(_root, Vector3(0.025, 0.24, 0.01), _crack_mat, crack_at[i])
			c.rotation.z = [0.6, -0.5, -0.9, 0.8][i]
			c.visible = false
			_cracks.append(c)
		# The lid, hinged at the back.
		_lid = Node3D.new()
		_lid.position = Vector3(0, 0.68, -0.4)
		_root.add_child(_lid)
		_box(_lid, Vector3(1.28, 0.2, 0.84), bone, Vector3(0, 0.1, 0.4))
		for x in [-0.36, 0.36]:
			_box(_lid, Vector3(0.1, 0.24, 0.88), iron, Vector3(x, 0.1, 0.4))
		var knob := SphereMesh.new()
		knob.radius = 0.09
		knob.height = 0.18
		_mesh(_lid, knob, iron, Vector3(0, 0.24, 0.4))
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

	func reset() -> void:
		_opened = false
		_open = 0.0
		_lid.rotation = Vector3.ZERO
		_lid.position = Vector3(0, 0.68, -0.4)
		_beam.visible = false
		_light.light_energy = 0.0
		for c in _cracks:
			c.visible = false
		_root.rotation = Vector3(0, -0.35, 0)
		_root.position = Vector3.ZERO

	func open_up(col: Color) -> void:
		_opened = true
		_open = 0.0
		_beam.visible = true
		_beam_mat.albedo_color = Color(col, 0.35)
		_light.light_color = col
		_light.light_energy = 2.5

	func animate(step: int, k: float, col: Color, tier: int, delta: float) -> void:
		_seam.albedo_color = col.lightened(0.3) * (1.0 + 0.6 * float(tier))
		_crack_mat.albedo_color = col.lightened(0.4) * 1.6
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
			_lid.rotation.x = -1.9 * e
			_lid.position = Vector3(0, 0.68 + 0.25 * e, -0.4 - 0.2 * e)
			_beam.scale = Vector3(1, 0.2 + 0.8 * e, 1)
			_beam_mat.albedo_color = Color(col, 0.22 + 0.1 * sin(t * 4.0))
			for c in _cracks:
				c.visible = true
