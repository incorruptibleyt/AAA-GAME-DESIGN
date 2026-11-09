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
## Repairs tried since the screen last opened (at most 3 per opening, 12 a session, so a
## phone that can't draw it never loops).
var _tries := 0
var _redressed := false   # this opening: the hero was put on again
var _rebuilt := false     # this opening: the stage was built again
static var _session_tries := 0
static var _drawn_ok := false   # a stage has once passed both looks this session
static var _after_run_checked := false   # checked once after a death or win this session
## Version 120: once a phone has drawn a stage with no see-through parts working, every
## stage after that draws on a solid backdrop instead (see _set_solid).
static var solid := false
var _solid_mat: ShaderMaterial


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
	_vp.transparent_bg = not solid
	# Version 120: no MSAA. The stage is drawn at twice its size and shrunk, which already
	# smooths the edges; MSAA on top of that was the one unusual thing about this little
	# picture on a phone's graphics chip, and the preview going blank came with it.
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_build_scene()
	if solid:
		_set_solid()


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
	_visual.build(Heroes.look(def, true))
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
	# On High the picture keeps its size while closed (about 5 MB), so it is never made
	# again from nothing each time the screen opens; Low still frees it.
	if on:
		_vp.size = Vector2i(_full_size * 0.75) if low else _full_size
		_tries = 0
		_redressed = false
		_rebuilt = false
	elif low:
		_vp.size = Vector2i.ONE
	# Drawn 30 times a second (_process), not every frame: a slow turn looks the same.
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE if on else SubViewport.UPDATE_DISABLED
	_draw_t = 0.0
	set_process(on)
	_active = on
	if on:
		texture = _vp.get_texture()
		# Version 121: reading the picture back stalls the phone's graphics for a moment, so
		# it is only checked until it has once come out right this session, or while a repair
		# is under way. Version 126 (audit #13): after a death or a finished run (where the
		# blank stage was seen) only the first opening a session is checked, unless this
		# session has already needed a repair.
		var after_run := Game.state in [Game.State.DEAD, Game.State.VICTORY]
		if not _drawn_ok or _tries > 0 or (after_run and (not _after_run_checked or _session_tries > 0)):
			if after_run:
				_after_run_checked = true
			_check_drawn()


## A phone showed an empty stage (no hero, or no hero and no pedestal) on the Heroes and
## Style screens, mostly when HEROES was tapped on the death screen. A moment after the
## stage starts drawing, and again half a second later, look at its picture and repair
## what's missing, a step further each time:
##   the pedestal drew but not the hero: put the hero on again;
##   nothing drew: build the little 3D world again from scratch;
##   still nothing, or it drew but nothing in it is solid: draw on a solid backdrop
##   from now on (for every stage this session), ignoring see-through-ness altogether.
func _check_drawn() -> void:
	if _checking or DisplayServer.get_name() == "headless":
		return
	_checking = true
	for wait in [3, 30]:
		for i in wait:
			await RenderingServer.frame_post_draw
		if not _active or not is_inside_tree():
			_checking = false
			return
		var seen := _look_at()
		if seen == "ok":
			continue
		if _tries >= 3 or _session_tries >= 12:
			_checking = false
			return   # out of repairs: keep checking on later openings
		_tries += 1
		_session_tries += 1
		_checking = false
		_repair(seen)
		return
	_checking = false
	if _active and is_inside_tree():
		_drawn_ok = true


## What the picture shows: "ok", "no hero" (pedestal only), "empty", or "clear" (colours
## were drawn but every pixel is see-through, so the screen shows nothing).
func _look_at() -> String:
	var img := _vp.get_texture().get_image()
	if img == null or img.is_empty():
		return "empty"
	var w := img.get_width()
	var h := img.get_height()
	var solid_px := 0
	var colour_px := 0
	var hero_px := 0
	for y in range(h / 8, h, 10):
		for x in range(0, w, 10):
			var c := img.get_pixel(x, y)
			var lit := c.r + c.g + c.b > 0.12
			if c.a > 0.3 or (solid and lit):
				solid_px += 1
				# The hero stands in the middle third, above the pedestal's top.
				if x > w / 3 and x < w * 2 / 3 and y < h * 0.7:
					hero_px += 1
			elif lit:
				colour_px += 1
	if solid:
		# A solid backdrop is lit everywhere: look for the hero against it instead.
		return "ok" if _hero_against_backdrop(img) else "empty"
	if solid_px == 0:
		return "clear" if colour_px > 20 else "empty"
	return "ok" if hero_px > 6 else "no hero"


## On the solid backdrop: something in the hero's spot differs from the backdrop colour.
func _hero_against_backdrop(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var n := 0
	for y in range(h / 8, int(h * 0.7), 10):
		for x in range(w / 3, w * 2 / 3, 10):
			var c := img.get_pixel(x, y)
			if absf(c.r - BACKDROP.r) + absf(c.g - BACKDROP.g) + absf(c.b - BACKDROP.b) > 0.15:
				n += 1
	return n > 6


func _repair(seen: String) -> void:
	var was := _vp.size
	var step := "rebuilt the stage"
	if seen == "no hero" and not _redressed and not _def.is_empty():
		_redressed = true
		step = "put the hero on again"
		show_hero(_def, _gold)
	else:
		if (seen == "clear" or _rebuilt) and not solid:
			solid = true
			step = "switched to a solid backdrop"
		_rebuilt = true
		_vp.queue_free()
		_visual = null
		_make_viewport()
		if not _def.is_empty():
			show_hero(_def, _gold)
	push_error("Hero preview showed %s (%s, try %d, %s, graphics %d MB); %s" % [seen, was, _session_tries,
			Game.State.keys()[Game.state],
			int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), step])
	var keep := [_tries, _redressed, _rebuilt]
	set_active(true)
	# set_active starts the count again for a fresh opening: keep this opening's
	_tries = keep[0]
	_redressed = keep[1]
	_rebuilt = keep[2]


## The backdrop the stage is drawn on once see-through pictures fail: the Heroes and Style
## screens' purple at the pedestal's height, faded out at the edges so it has no hard box.
const BACKDROP := Color(0.17, 0.12, 0.31)

func _set_solid() -> void:
	_vp.transparent_bg = false
	_cam.environment.background_mode = Environment.BG_COLOR
	_cam.environment.background_color = BACKDROP
	if _solid_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float m = (1.0 - smoothstep(0.7, 1.0, d.x)) * (1.0 - smoothstep(0.88, 1.0, d.y));
	COLOR = vec4(texture(TEXTURE, UV).rgb, m);
}"""
		_solid_mat = ShaderMaterial.new()
		_solid_mat.shader = sh
	material = _solid_mat


func _notification(what: int) -> void:
	# Coming back to the game while the stage is open: make sure it still draws.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _active:
		_check_drawn.call_deferred()


var _draw_t := 0.0

func _process(delta: float) -> void:
	_time += delta
	_draw_t += delta
	if _draw_t >= 1.0 / 30.0:
		_draw_t = 0.0
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
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
