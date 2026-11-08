class_name HeroStage
extends TextureRect
## A hero standing on a lit pedestal, drawn in its own little 3D world for the Heroes
## screen. They sway gently to show off their model; drag sideways to turn them around.

## Drawn at twice the screen size, so the model stays sharp on big phones.
const RENDER_SCALE := 2.0
## Facing the camera, turned a little to the side.
const FRONT := PI - 0.35

var _vp: SubViewport
var _full_size: Vector2i
var _root: Node3D
var _pivot: Node3D
var _visual: CharacterVisual
var _ring_mat: StandardMaterial3D
var _gold_ring: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _back_light: OmniLight3D
var _time := 0.0
## Seconds left before a dragged hero eases back to the front.
var _hold := 0.0
## The hero on show (to put back after a rebuild) and whether the stage is drawing.
var _def := {}
var _gold := false
var _active := false
var _checking := false
var _rebuilds := 0   # at most 2 a session, so a phone that can't draw it never loops


func _init(stage_size: Vector2) -> void:
	custom_minimum_size = stage_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	_full_size = Vector2i(stage_size * RENDER_SCALE)
	_make_viewport()
	set_process(false)


func _make_viewport() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i.ONE   # full size only while the Heroes screen is open (set_active)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_build_scene()


func _ready() -> void:
	texture = _vp.get_texture()


var _cam: Camera3D


## A crowned hero stands taller: the camera steps back so the crown's points stay in view.
func _frame_camera(tall: bool) -> void:
	var eye := Vector3(0, 1.6, 6.0) if tall else Vector3(0, 1.45, 5.2)
	var at := Vector3(0, 1.1, 0) if tall else Vector3(0, 0.95, 0)
	_cam.transform = Transform3D(Basis.looking_at(at - eye), eye)


func _build_scene() -> void:
	var cam := Camera3D.new()
	cam.fov = 30.0
	_cam = cam
	_frame_camera(false)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.72)
	env.ambient_light_energy = 0.7
	cam.environment = env
	_vp.add_child(cam)
	_root = Node3D.new()
	_vp.add_child(_root)
	# A warm key light from the front left, and a coloured light behind in the hero's colour.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-30), 0)
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.93, 0.82)
	_root.add_child(key)
	_back_light = OmniLight3D.new()
	_back_light.position = Vector3(0, 2.2, -1.6)
	_back_light.omni_range = 5.0
	_back_light.light_energy = 2.5
	_root.add_child(_back_light)
	# The pedestal: a stone drum with a glowing ring and a soft pool of light on top.
	var drum := U.cylinder(_root, 1.15, 0.3, U.mat(Color(0.16, 0.15, 0.19), 0.9), Vector3(0, -0.3, 0))
	drum.mesh = drum.mesh.duplicate()   # U's meshes are shared: copy before changing it
	(drum.mesh as CylinderMesh).radial_segments = 48
	var torus := TorusMesh.new()
	torus.inner_radius = 1.08
	torus.outer_radius = 1.2
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	_ring_mat = U.unlit(Color.WHITE).duplicate()
	ring.material_override = _ring_mat
	ring.scale = Vector3(1, 0.4, 1)
	_root.add_child(ring)
	# Hero Mastery level 10: a gold frame round the pedestal.
	var gold := TorusMesh.new()
	gold.inner_radius = 1.22
	gold.outer_radius = 1.3
	_gold_ring = MeshInstance3D.new()
	_gold_ring.mesh = gold
	_gold_ring.material_override = U.unlit(Color(1.0, 0.8, 0.3))
	_gold_ring.scale = Vector3(1, 0.4, 1)
	_gold_ring.position = Vector3(0, -0.02, 0)
	_gold_ring.visible = false
	_root.add_child(_gold_ring)
	_glow_mat = U.unlit(Color.WHITE, U.soft_circle()).duplicate()
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	U.floor_quad(_root, Vector2(2.6, 2.6), _glow_mat, Vector3(0, 0.01, 0))
	_pivot = Node3D.new()
	_pivot.rotation.y = FRONT
	_root.add_child(_pivot)


## Puts `def` (an entry of Heroes.LIST) on the pedestal, with a little flourish; `gold` adds
## a Master's gold frame round it.
func show_hero(def: Dictionary, gold := false) -> void:
	_def = def
	_gold = gold
	_gold_ring.visible = gold
	if _visual:
		_visual.queue_free()
	var extras: Array = def.get("style", {}).get("extras", [])
	var tall := false
	for x in ["crown", "crypt_crown", "storm_halo", "flame_crown", "antlers", "phantom_horns", "bone_crown", "star_circlet"]:
		tall = tall or extras.has(x)
	_frame_camera(tall)
	_visual = CharacterVisual.new()
	_visual.outline_me = true
	_visual.aura_boost = 1.8   # the hero is drawn big here: a Master aura's line grows to match
	_pivot.add_child(_visual)
	_visual.build(Heroes.look(def))
	if def.has("aura"):
		_visual.add_child(Fx.motif(str(def.aura.get("motif", "wisps")), def.aura.get("spark", Color.WHITE)))   # a Master aura's trail of light
		if def.aura.get("sigil", false):
			CryptSigil.make(_visual, 2.6, 1.2)   # the Crypt King's sigil on the pedestal
	_visual.attack(def.id == "mage")
	if _visual._anim:
		_visual._anim.advance(0.0)   # pose them now, so they never flash up in a T-pose
	_pivot.rotation.y = FRONT
	_hold = 0.0
	_time = 0.0
	var col: Color = def.ring
	_ring_mat.albedo_color = col
	_glow_mat.albedo_color = Color(col, 0.45)
	_back_light.light_color = col


## Only draws while the Heroes screen is open. Closed, its picture shrinks to 1 pixel, so the
## big smoothed (4x) picture doesn't hold graphics memory the rest of the time.
## On Low graphics it's drawn at 1.5x with 2x smoothing: about a quarter of the memory.
func set_active(on: bool) -> void:
	var low := not Game._high_graphics
	_vp.msaa_3d = Viewport.MSAA_2X if low else Viewport.MSAA_4X
	_vp.size = (Vector2i(_full_size * 0.75) if low else _full_size) if on else Vector2i.ONE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)
	_active = on
	if on:
		texture = _vp.get_texture()
		_check_drawn()


## A phone once showed an empty stage (no hero, no pedestal) on the Heroes and Style screens
## until the game was restarted. A moment after the stage starts drawing, look at its
## picture; if nothing was drawn, build the little 3D world again from scratch.
func _check_drawn() -> void:
	if _checking or DisplayServer.get_name() == "headless":
		return
	_checking = true
	for i in 3:
		await RenderingServer.frame_post_draw
	_checking = false
	if not _active or not is_inside_tree():
		return
	if _drawn() or _rebuilds >= 2:
		return
	_rebuilds += 1
	push_error("Hero preview drew nothing (%s); rebuilt it" % [_vp.size])
	_vp.queue_free()
	_visual = null
	_make_viewport()
	if not _def.is_empty():
		show_hero(_def, _gold)
	set_active(true)


## True when some of the stage's picture is not see-through (the pedestal alone is enough).
func _drawn() -> bool:
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		return false
	var w := img.get_width()
	var h := img.get_height()
	for y in range(h / 3, h, 12):
		for x in range(0, w, 12):
			if img.get_pixel(x, y).a > 0.3:
				return true
	return false


func _notification(what: int) -> void:
	# Coming back to the game while the stage is open: make sure it still draws.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _active:
		_check_drawn.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if _hold > 0.0:
		_hold -= delta
		return
	var target := FRONT + sin(_time * 0.6) * 0.4
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, target, minf(1.0, delta * 2.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_pivot.rotation.y += (event as InputEventScreenDrag).relative.x * 0.012
		_hold = 2.5
		accept_event()
