class_name HeroStage
extends TextureRect
## A hero standing on a lit pedestal, drawn in its own little 3D world for the Heroes
## screen. They sway gently to show off their model; drag sideways to turn them around.

## Drawn at twice the screen size, so the model stays sharp on big phones.
const RENDER_SCALE := 2.0
## Facing the camera, turned a little to the side.
const FRONT := PI - 0.35

var _vp: SubViewport
var _root: Node3D
var _pivot: Node3D
var _visual: CharacterVisual
var _ring_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _back_light: OmniLight3D
var _time := 0.0
## Seconds left before a dragged hero eases back to the front.
var _hold := 0.0


func _init(stage_size: Vector2) -> void:
	custom_minimum_size = stage_size
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.size = Vector2i(stage_size * RENDER_SCALE)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_build_scene()
	set_process(false)


func _ready() -> void:
	texture = _vp.get_texture()


func _build_scene() -> void:
	var cam := Camera3D.new()
	cam.fov = 30.0
	var eye := Vector3(0, 1.45, 5.2)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.95, 0) - eye), eye)
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
	_glow_mat = U.unlit(Color.WHITE, U.soft_circle()).duplicate()
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	U.floor_quad(_root, Vector2(2.6, 2.6), _glow_mat, Vector3(0, 0.01, 0))
	_pivot = Node3D.new()
	_pivot.rotation.y = FRONT
	_root.add_child(_pivot)


## Puts `def` (an entry of Heroes.LIST) on the pedestal, with a little flourish.
func show_hero(def: Dictionary) -> void:
	if _visual:
		_visual.queue_free()
	_visual = CharacterVisual.new()
	_pivot.add_child(_visual)
	_visual.build(Heroes.look(def))
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


## Only draws while the Heroes screen is open.
func set_active(on: bool) -> void:
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)


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
