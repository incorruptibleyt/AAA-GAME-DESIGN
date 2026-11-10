class_name HeroStage
extends TextureRect
## A hero standing on a lit pedestal, drawn in its own little 3D world for the Heroes
## screen. They sway gently to show off their model; drag sideways to turn them around.
## A newly won or tried-on look gets a reveal (version 131): see reveal().

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
var _key: DirectionalLight3D
var _env: Environment
var _sparks: CPUParticles3D
var _tall := false
var _time := 0.0
## The reveal under way: seconds into it (-1 for none), how long it lasts, and the slot.
var _reveal_t := -1.0
var _reveal_len := 2.8
var _reveal_slot := ""
var _emoted := false
## After a glow's reveal the stage stays a little darker and the glow a little brighter,
## so the glow keeps reading while the player decides to wear it.
var _settle := 0.0
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
	_tall = tall
	var f := _framing()
	_cam.transform = Transform3D(Basis.looking_at(f[1] - f[0]), f[0])


## The camera's usual place and the point it looks at.
func _framing() -> Array:
	if _tall:
		return [Vector3(0, 1.6, 6.0), Vector3(0, 1.1, 0)]
	return [Vector3(0, 1.45, 5.2), Vector3(0, 0.95, 0)]


## Where the camera moves in to during a reveal: up close on the head for headwear, on the
## hands for a weapon, nearer the whole hero for an outfit or glow, and further back and
## higher for an aura (its trail and the ring on the ground).
func _zoomed(slot: String) -> Array:
	match slot:
		"head":
			# (a crown, horns or a halo reach well above the head: frame those whole)
			var y := 1.85 if _tall else 1.6
			return [Vector3(0, y + 0.15, 4.3 if _tall else 3.9), Vector3(0, y, 0)]
		"hold":
			return [Vector3(0.25, 1.25, 3.9), Vector3(0, 1.0, 0)]
		"aura":
			return [Vector3(0, 2.0, 5.0), Vector3(0, 0.8, 0)]
	if _tall:
		return [Vector3(0, 1.55, 5.0), Vector3(0, 1.2, 0)]
	return [Vector3(0, 1.35, 4.6), Vector3(0, 1.0, 0)]


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
	_key = key
	_env = env
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
	# A reveal's burst of sparks, rising from the pedestal round the hero.
	_sparks = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var sm := U.unlit(Color.WHITE, U.soft_circle()).duplicate() as StandardMaterial3D
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.vertex_color_use_as_albedo = true
	q.material = sm
	_sparks.mesh = q
	_sparks.amount = 48
	_sparks.lifetime = 1.3
	_sparks.one_shot = true
	_sparks.explosiveness = 0.85
	_sparks.emitting = false
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_sparks.emission_ring_axis = Vector3.UP
	_sparks.emission_ring_radius = 1.0
	_sparks.emission_ring_inner_radius = 0.6
	_sparks.emission_ring_height = 0.1
	_sparks.direction = Vector3.UP
	_sparks.spread = 25.0
	_sparks.initial_velocity_min = 1.2
	_sparks.initial_velocity_max = 3.0
	_sparks.gravity = Vector3(0, -1.2, 0)
	_sparks.damping_min = 0.8
	_sparks.damping_max = 1.6
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.6
	_sparks.position = Vector3(0, 0.1, 0)
	_root.add_child(_sparks)


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
	_reveal_t = -1.0
	_settle = 0.0
	_light(0.0, 0.0)
	var col: Color = def.ring
	_ring_mat.albedo_color = col
	_glow_mat.albedo_color = Color(col, 0.45)
	_back_light.light_color = col


## Shows off the look in `slot` that the hero on the pedestal has just won or is trying on
## (version 131): the lights go down, the pedestal flares in the look's colour with a burst
## of sparks, the camera moves in on it (the head for headwear, the hands for a weapon...)
## while the hero spins round once, then they cheer and the camera eases back. A glow or
## aura shines brighter through all of it. `quick`: a shorter one, for trying looks on.
func reveal(slot: String, quick := false) -> void:
	if _visual == null:
		return
	_reveal_slot = slot
	_reveal_t = 0.0
	_reveal_len = 1.8 if quick else 2.9
	_emoted = quick
	_hold = 0.0
	var col: Color = _def.get("ring", Color.WHITE)
	if slot == "aura" and _def.has("aura"):
		col = _def.aura.get("spark", col)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.25, Color(col.lightened(0.3), 1.0))
	g.set_color(g.get_point_count() - 1, Color(col, 0.0))
	_sparks.color_ramp = g
	_sparks.amount = 30 if quick else 48
	_sparks.restart()
	_sparks.emitting = true
	if not quick:
		Sfx.play("shimmer", 0.8)


func revealing() -> bool:
	return _reveal_t >= 0.0


## The stage's lights for `dim` (0 normal, 1 down for a reveal) and the look's `flare`.
func _light(dim: float, flare: float) -> void:
	_key.light_energy = lerpf(1.3, 0.55, dim)
	_env.ambient_light_energy = lerpf(0.7, 0.34, dim)
	_back_light.light_energy = 2.5 + 1.5 * dim + 5.0 * flare
	var c := _glow_mat.albedo_color
	c.a = clampf(0.45 + 0.3 * dim + 0.55 * flare, 0.0, 1.0)
	_glow_mat.albedo_color = c
	if _visual:
		_visual.rim_boost(1.0 + 0.9 * dim + 2.2 * flare)


func _update_reveal(delta: float) -> void:
	_reveal_t += delta
	var x := clampf(_reveal_t / _reveal_len, 0.0, 1.0)
	# One full turn, fast at first and slowing to a stop facing the front.
	var s := clampf(_reveal_t / (_reveal_len * 0.55), 0.0, 1.0)
	_pivot.rotation.y = FRONT + TAU * (1.0 - pow(1.0 - s, 3.0))
	# In, hold, back out.
	var z := smoothstep(0.0, 0.18, x) * (1.0 - smoothstep(0.8, 1.0, x))
	var a := _framing()
	var b := _zoomed(_reveal_slot)
	var eye: Vector3 = a[0].lerp(b[0], z)
	var at: Vector3 = a[1].lerp(b[1], z)
	_cam.transform = Transform3D(Basis.looking_at(at - eye), eye)
	var glowing := _reveal_slot == "glow" or _reveal_slot == "aura"
	var flare := exp(-pow((x - 0.1) / 0.07, 2.0)) * (1.0 if glowing else 0.55)
	_settle = 0.55 if _reveal_slot == "glow" else 0.0
	_light(maxf(z * (1.0 if glowing else 0.7), _settle * smoothstep(0.7, 1.0, x)), flare)
	if not _emoted and x >= 0.55:
		_emoted = true
		var h := Heroes.get_hero(str(_def.get("id", "")))
		_visual.emote(h.get("emote", []))
	if x >= 1.0:
		_reveal_t = -1.0
		_time = 0.0   # the sway starts again from the front
		_frame_camera(_tall)
		_light(_settle, 0.0)


## The hero on the pedestal plays their emote (version 129).
func emote(names: Array) -> void:
	if _visual:
		_visual.emote(names)


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
	if _reveal_t >= 0.0:
		_update_reveal(delta)
		return
	if _hold > 0.0:
		_hold -= delta
		return
	var target := FRONT + sin(_time * 0.6) * 0.4
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, target, minf(1.0, delta * 2.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if _reveal_t >= 0.0:
			# Turning the hero yourself ends a reveal (the camera eases back at once).
			_reveal_t = -1.0
			_frame_camera(_tall)
			_light(_settle, 0.0)
		_pivot.rotation.y += (event as InputEventScreenDrag).relative.x * 0.012
		_hold = 2.5
		accept_event()
