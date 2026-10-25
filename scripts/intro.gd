class_name Intro
extends CanvasLayer
## The opening scene when the game starts, about four seconds. In a dark crypt two torches
## catch, a skeleton warrior lifts its head, its eyes light up and it roars, and as its sword
## comes down BONE CHAIN slams onto the screen in a burst of embers. Then the words glide up
## onto the title screen's logo while the crypt fades into the title. A tap skips to the
## glide. The crypt is its own small 3D world, drawn as a picture under the words.

signal music      # the title music should start (as the sword lands, or on a skip)
signal handoff    # the glide to the title screen begins
signal finished

const BG := Color(0.094, 0.063, 0.149)   # Android's launch screen, which runs into this
const TORCH := Color(1.0, 0.6, 0.28)
const TAGLINE := "Dash. Chain. Descend."

# The beats, in seconds.
const TORCHES := [0.12, 0.36]
const AWAKEN := 0.6
const EYES := 1.0
const CHOP := 1.3       # the warrior leaps and chops; its sword lands 0.76 s in
const HIT := 2.06        # the sword lands and the words slam down
const SLAM_LEN := 0.14
const TAG := 2.4
const HANDOFF := 3.25
const SLOW_FROM := 1.58  # the top of the warrior's leap plays in slow motion, like a perfect dodge
const SLOW_TO := 1.84
const SLOW := 0.3
const GLINT := 2.5       # a glint of light sweeps across the letters
const GLINT_LEN := 0.45
## Lights up the gold of the letters (not their dark edge) where the glint passes.
const GLINT_SHADER := """
shader_type canvas_item;
uniform float sweep = -1.0;
void fragment() {
	float lum = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	float band = 1.0 - smoothstep(0.0, 0.09, abs(UV.x - sweep + (UV.y - 0.5) * 0.35));
	COLOR.rgb += vec3(1.0, 0.95, 0.8) * band * smoothstep(0.45, 0.8, lum) * 1.4;
}
"""
const HANDOFF_LEN := 0.55

## The title screen's logo, which the words land on.
var logo: Control
var t := 0.0
var _vp: SubViewport
var _view: TextureRect
var _canvas: Control
var _cam: Camera3D
var _anims: Array = []          # {player, cues: [[time, animation], ...], next}
var _torches: Array = []        # {light, flame, size, at}
var _eye_light: OmniLight3D
var _eye_mat: StandardMaterial3D
var _rim: OmniLight3D
var _key: OmniLight3D
var _impact: OmniLight3D        # flares from the floor where the sword lands
var _words: Control             # draws BONE CHAIN, through the glint shader
var _glint: ShaderMaterial
var _cracks: Array = []         # glowing cracks in the floor from the hit, as point lists
var _glow: GradientTexture2D
var _shade: GradientTexture2D
var _embers: Array = []         # {p, v, life, size}
var _shake := 0.0
var _flash := 0.0
var _ember_spawn := 0.0
var _music_sent := false
var _handed := false
var _off := Vector2.ZERO        # this frame's shake


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_glow = _radial()
	_shade = GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.75))
	_shade.gradient = g
	_shade.fill_from = Vector2(0.5, 0.0)
	_shade.fill_to = Vector2(0.5, 1.0)
	_build_crypt()
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	_glint = ShaderMaterial.new()
	_glint.shader = Shader.new()
	_glint.shader.code = GLINT_SHADER
	_words = Control.new()
	_words.set_anchors_preset(Control.PRESET_FULL_RECT)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_words.material = _glint
	_words.draw.connect(_draw_words)
	_canvas.add_child(_words)
	_step(0.0)


## Jump to the glide onto the title screen.
func skip() -> void:
	t = maxf(t, HANDOFF)


func _input(event: InputEvent) -> void:
	# Nothing underneath gets a touch while the intro plays; a tap skips it.
	var press := (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed()
	if press:
		skip()
	if press or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- the crypt

func _build_crypt() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = get_window().size
	_vp.msaa_3d = Viewport.MSAA_2X if Game._high_graphics else Viewport.MSAA_DISABLED
	_vp.scaling_3d_scale = 1.0 if Game._high_graphics else 0.6
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var world := Node3D.new()
	_vp.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.018, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.18, 0.3)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.02, 0.05)
	env.fog_density = 0.11
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var stone := StandardMaterial3D.new()
	stone.albedo_texture = U.stone()
	stone.albedo_color = Color(0.78, 0.74, 0.82)
	stone.roughness = 0.8
	stone.uv1_scale = Vector3(5, 5, 1)
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	U.floor_quad(world, Vector2(14, 14), stone)
	var wall_scene := Art.get_model("wall")
	for x in [-4.0, 0.0, 4.0]:
		var spot := Node3D.new()
		spot.position = Vector3(x, 0, -2.6)
		world.add_child(spot)
		if wall_scene:
			Art.place_prop(wall_scene, spot, 4.0)
		else:
			U.box(spot, Vector3(4, 4, 0.6), U.mat(Color(0.15, 0.14, 0.19), 0.95), Vector3(0, 2, 0))
	var torch_scene := Art.get_model(Art.TORCH)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var spot := Node3D.new()
		spot.position = Vector3(side * 1.55, 1.75, -2.25)
		spot.rotation.y = -PI * 0.5
		world.add_child(spot)
		if torch_scene:
			Art.place_prop(torch_scene, spot, 0.9)
		var flame := Fx.flame(world, Vector2(0.34, 0.52), Vector3(side * 1.55, 2.22, -2.0))
		flame.visible = false
		var light := OmniLight3D.new()
		light.light_color = TORCH
		light.omni_range = 5.0
		light.light_energy = 0.0
		light.position = Vector3(side * 1.55, 2.4, -1.6)
		world.add_child(light)
		_torches.append({"light": light, "flame": flame, "size": flame.scale, "at": TORCHES[i]})

	# The warrior in front, and two more of the dead behind it who wake a moment later.
	var warrior := _actor(world, "Skeleton_Warrior", Vector3(0, 0, 0), deg_to_rad(12.0), "Skeleton_Blade",
		[[0.0, "Skeleton_Inactive_Standing_Pose"], [AWAKEN, "Skeletons_Awaken_Standing"], [CHOP, "1H_Melee_Attack_Jump_Chop"], [CHOP + 1.4, "Idle_Combat"]])
	_actor(world, "Skeleton_Minion", Vector3(-1.25, 0, -1.6), deg_to_rad(18.0), "Skeleton_Axe",
		[[0.0, "Skeleton_Inactive_Standing_Pose"], [AWAKEN + 0.55, "Skeletons_Awaken_Standing"], [AWAKEN + 1.5, "Idle_Combat"]])
	_actor(world, "Skeleton_Rogue", Vector3(1.25, 0, -1.6), deg_to_rad(-18.0), "Skeleton_Crossbow",
		[[0.0, "Skeleton_Inactive_Standing_Pose"], [AWAKEN + 0.75, "Skeletons_Awaken_Standing"], [AWAKEN + 1.7, "Idle_Combat"]])
	_add_eyes(warrior)

	_rim = OmniLight3D.new()
	_rim.light_color = Color(0.55, 0.4, 1.0)
	_rim.omni_range = 2.4
	_rim.position = Vector3(0.3, 2.4, -0.6)
	world.add_child(_rim)
	_key = OmniLight3D.new()
	_key.light_color = Color(1.0, 0.82, 0.65)
	_key.omni_range = 7.0
	_key.position = Vector3(1.4, 2.2, 2.4)
	world.add_child(_key)
	_impact = OmniLight3D.new()
	_impact.light_color = Color(1.0, 0.55, 0.2)
	_impact.omni_range = 4.0
	_impact.light_energy = 0.0
	_impact.position = Vector3(0.2, 0.25, 1.3)
	world.add_child(_impact)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	world.add_child(_cam)


func _actor(world: Node3D, key: String, pos: Vector3, yaw: float, weapon: String, cues: Array) -> Node3D:
	var scene := Art.get_model(key)
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	Art.bind_skins(node)
	world.add_child(node)
	node.position = pos
	node.rotation.y = yaw
	Art.attach_to_bone(node, "handslot.r", weapon)
	var players := node.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap := players[0] as AnimationPlayer
		# Driven by the intro's own clock, so a slow frame never puts the sword out of step.
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anims.append({"player": ap, "cues": cues, "next": 0})
	return node


## Two glowing eyes (and the light they throw) on the warrior's head.
func _add_eyes(warrior: Node3D) -> void:
	if warrior == null:
		return
	var skel := Art._find_skeleton(warrior)
	if skel == null or skel.find_bone("head") < 0:
		return
	var head := BoneAttachment3D.new()
	skel.add_child(head)
	head.bone_name = "head"
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.albedo_color = Color(0, 0, 0)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.06
		m.height = 0.08
		eye.mesh = m
		eye.material_override = _eye_mat
		eye.position = Vector3(side * 0.16, 0.44, 0.36)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(eye)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = Color(1.0, 0.72, 0.25)
	_eye_light.omni_range = 1.1
	_eye_light.light_energy = 0.0
	_eye_light.position = Vector3(0, 0.42, 0.5)
	head.add_child(_eye_light)


# ---------------------------------------------------------------- the clock

func _process(delta: float) -> void:
	_step(minf(delta, 1.0 / 30.0))   # a slow frame slows the intro instead of skipping part of it


func _step(dt: float) -> void:
	var was := t
	var step := dt * _speed()
	t += step
	if t < HANDOFF:
		for at: float in TORCHES:
			if _crossed(was, at):
				Sfx.play("ignite", 0.55)
		if _crossed(was, AWAKEN):
			Sfx.play("crack", 0.6)
		if _crossed(was, EYES):
			Sfx.play("roar", 0.85)
		if _crossed(was, SLOW_FROM - 0.06):
			Sfx.play("dash", 0.7)
		if _crossed(was, HIT):
			Sfx.play("slam")
			Sfx.play("boom", 0.6)
			_shake = 16.0
			_flash = 0.22
			_burst()
			_crack()
	if t >= HIT and not _music_sent:
		_music_sent = true
		music.emit()
	if t >= HANDOFF and not _handed:
		_handed = true
		handoff.emit()
	_animate(step)
	_light_up()
	_move_camera()
	_shake = move_toward(_shake, 0.0, dt * 50.0)
	_flash = move_toward(_flash, 0.0, dt * 2.2)
	_update_embers(step)
	_glint.set_shader_parameter("sweep", lerpf(-0.25, 1.25, (t - GLINT) / GLINT_LEN) if t > GLINT and t < GLINT + GLINT_LEN else -1.0)
	if logo:
		logo.modulate.a = 0.0
	_view.modulate.a = 1.0 - _glide()
	_canvas.queue_redraw()
	_words.queue_redraw()
	if t >= HANDOFF + HANDOFF_LEN:
		# The words now sit exactly on the title's own logo (the same picture, size and place),
		# so it takes over from them without a seam.
		if logo:
			logo.modulate.a = 1.0
		finished.emit()
		queue_free()


func _crossed(was: float, at: float) -> bool:
	return was < at and t >= at


## How fast the clock runs: slow at the top of the leap, then full speed into the hit.
func _speed() -> float:
	return lerpf(1.0, SLOW, _slowness())


func _slowness() -> float:
	return smoothstep(SLOW_FROM - 0.08, SLOW_FROM, t) * (1.0 - smoothstep(SLOW_TO - 0.04, SLOW_TO + 0.04, t))


func _animate(dt: float) -> void:
	for a in _anims:
		var ap: AnimationPlayer = a.player
		var cues: Array = a.cues
		while a.next < cues.size() and t >= cues[a.next][0]:
			var anim: String = cues[a.next][1]
			if ap.has_animation(anim):
				ap.play(anim, 0.0 if a.next == 0 else 0.12)
			a.next += 1
		ap.advance(dt)


func _light_up() -> void:
	var hit := clampf(1.0 - (t - HIT) / 0.5, 0.0, 1.0) * float(t >= HIT)
	for tr in _torches:
		var since: float = t - tr.at
		var on := 0.0
		if since > 0.0:
			# Flares up as it catches, then settles to a flicker.
			on = minf(since / 0.06, 1.0) * (1.0 + 0.7 * exp(-since * 6.0))
		var flicker := 0.88 + sin(t * 9.0 + tr.at * 40.0) * 0.07 + sin(t * 23.0 + tr.at * 90.0) * 0.05
		(tr.light as OmniLight3D).light_energy = 1.9 * on * flicker * (1.0 + hit * 0.8)
		var flame := tr.flame as MeshInstance3D
		flame.visible = on > 0.0
		flame.scale = (tr.size as Vector3) * (0.6 + 0.4 * minf(on, 1.6)) * (1.0 + hit * 0.3)
	_rim.light_energy = 2.2 * clampf((t - 0.1) / 0.6, 0.0, 1.0)
	_impact.light_energy = 6.0 * hit * hit
	_key.light_energy = 0.75 * clampf((t - TORCHES[0]) / 0.5, 0.0, 1.0)
	var eyes := 0.0
	var since_eyes := t - EYES
	if since_eyes > 0.0:
		eyes = minf(since_eyes / 0.1, 1.0)
		if since_eyes < 0.3:
			eyes *= 0.5 + 0.5 * signf(sin(since_eyes * 90.0))   # they catch with a flicker
		eyes *= 0.9 + 0.1 * sin(t * 15.0)
	if _eye_mat:
		_eye_mat.albedo_color = Color(0.05, 0.03, 0.0).lerp(Color(4.0, 2.6, 0.7), eyes)
		_eye_light.light_energy = eyes * (0.7 + hit * 0.8)


func _move_camera() -> void:
	# A slow push in on the warrior from just below its eye line, rushing in close on its face as
	# the eyes light up, then back out for the leap.
	var k := smoothstep(0.0, 1.0, clampf(t / HANDOFF, 0.0, 1.0))
	var from := Vector3(0.5, 1.05, 7.6).lerp(Vector3(0.12, 1.2, 6.2), k)
	var at := Vector3(0.0, 0.65, 0.0).lerp(Vector3(0.0, 0.85, 0.0), k)
	var close := smoothstep(EYES - 0.2, EYES + 0.1, t) * (1.0 - smoothstep(CHOP + 0.05, CHOP + 0.4, t))
	from = from.lerp(Vector3(0.1, 1.6, 3.7), close)
	at = at.lerp(Vector3(0.0, 1.45, 0.0), close)
	_cam.look_at_from_position(from, at)
	var shake := _shake / 600.0
	_cam.h_offset = randf_range(-1, 1) * shake
	_cam.v_offset = randf_range(-1, 1) * shake


# ---------------------------------------------------------------- embers and words

func _update_embers(dt: float) -> void:
	if t > TORCHES[0] and t < HANDOFF:
		_ember_spawn += dt * (10.0 if t < HIT else 20.0)
		var vp := _canvas.size
		while _ember_spawn >= 1.0:
			_ember_spawn -= 1.0
			_embers.append({"p": Vector2(randf() * vp.x, vp.y + 10), "v": Vector2(randf_range(-20, 20), randf_range(-170, -70)),
				"life": randf_range(1.2, 2.6), "size": randf_range(1.5, 3.5)})
	for e in _embers:
		if e.v.length() > 200.0:
			e.v *= 1.0 - minf(dt * 2.5, 0.5)
		e.v.y -= 40.0 * dt
		e.p += e.v * dt
		e.life -= dt
	_embers = _embers.filter(func(e): return e.life > 0.0)


func _burst() -> void:
	var c := _words_center()
	var w := Hud.logo_size().x * 0.85 * 1.12   # the letters, not the glow around them
	for i in 50:
		var p := c + Vector2(randf_range(-w * 0.5, w * 0.5), randf_range(-18, 18))
		var dir := (p - c + Vector2(0, randf_range(-30, 10))).normalized()
		_embers.append({"p": p, "v": dir * randf_range(180, 560) + Vector2(0, -80),
			"life": randf_range(0.5, 1.1), "size": randf_range(2.0, 4.5)})


## Glowing cracks that run out across the floor from where the words land, flattened as if
## seen at an angle.
func _crack() -> void:
	_cracks.clear()
	for i in 11:
		var a := TAU * (i + randf_range(-0.3, 0.3)) / 11.0
		var reach := randf_range(150.0, 300.0)
		var p := Vector2.ZERO
		var pts := PackedVector2Array([p])
		for _j in 6:
			p += Vector2.from_angle(a + randf_range(-0.5, 0.5)) * reach / 6.0
			pts.append(Vector2(p.x, p.y * 0.32))
		_cracks.append(pts)


## 0 to 1 over the glide to the title screen.
func _glide() -> float:
	return smoothstep(0.0, 1.0, clampf((t - HANDOFF) / HANDOFF_LEN, 0.0, 1.0))


func _words_center() -> Vector2:
	return Vector2(_canvas.size.x * 0.5, _canvas.size.y * 0.74)


func _paint() -> void:
	var vp := _canvas.size
	var glide := _glide()
	var fade := clampf(1.0 - glide * 2.5, 0.0, 1.0)
	# From the launch screen's purple into the dark crypt.
	var open := clampf(1.0 - t / 0.35, 0.0, 1.0)
	if open > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(BG.r, BG.g, BG.b, open))
	# Darken the bottom of the picture so the words stand out.
	_canvas.draw_texture_rect(_shade, Rect2(0, vp.y * 0.5, vp.x, vp.y * 0.5), false, Color(1, 1, 1, fade))
	# A cold tint while time slows.
	var slow := _slowness()
	if slow > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.25, 0.35, 0.85, 0.2 * slow))
	_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_canvas.draw_set_transform(_off)
	_draw_impact(fade)
	_draw_words_glow(glide)
	var tag_a := clampf((t - TAG) / 0.3, 0.0, 1.0) * fade
	if tag_a > 0.0:
		var f := ThemeDB.fallback_font
		var ts := 22
		var tw := f.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		var tp := _words_center() + Vector2(-tw * 0.5, 74)
		_canvas.draw_string_outline(f, tp, TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, 5, Color(0, 0, 0, 0.8 * tag_a))
		_canvas.draw_string(f, tp, TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.88, 0.84, 0.92, tag_a))
	for e in _embers:
		var a := clampf(e.life * 1.5, 0.0, 1.0) * (1.0 - glide)
		_canvas.draw_texture_rect(_glow, Rect2(e.p - Vector2(e.size, e.size) * 3.0, Vector2(e.size, e.size) * 6.0), false, Color(1.0, 0.45, 0.1, a * 0.5))
		_canvas.draw_circle(e.p, e.size * 0.6, Color(1.0, 0.85, 0.4, a), true, -1.0, true)
	_canvas.draw_set_transform(Vector2.ZERO)
	if _flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(1.0, 0.85, 0.65, _flash))


## The shockwave and the glowing cracks where the words hit the floor.
func _draw_impact(fade: float) -> void:
	var since := t - HIT
	if since <= 0.0 or fade <= 0.0:
		return
	var floor_at := _words_center() + Vector2(0, 30) + _off
	var ring := clampf(since / 0.5, 0.0, 1.0)
	if ring < 1.0:
		_canvas.draw_set_transform(floor_at, 0.0, Vector2(1.0, 0.3))
		var r := 60.0 + 400.0 * (1.0 - pow(1.0 - ring, 3.0))
		_canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(1.0, 0.8, 0.55, 0.7 * (1.0 - ring) * fade), 14.0 * (1.0 - ring) + 2.0, true)
	_canvas.draw_set_transform(floor_at)
	var grow := clampf(since / 0.15, 0.0, 1.0)
	var heat := clampf(1.0 - since / 1.0, 0.0, 1.0) * fade
	for pts: PackedVector2Array in _cracks:
		var part := pts.slice(0, maxi(2, ceili(pts.size() * grow)))
		_canvas.draw_polyline(part, Color(1.0, 0.4, 0.1, 0.35 * heat), 9.0, true)
		_canvas.draw_polyline(part, Color(1.0, 0.82, 0.5, 0.9 * heat), 2.5, true)
	_canvas.draw_set_transform(_off)


## Where BONE CHAIN is and how big: it slams down from big, then glides up onto the title
## screen's logo. [centre, scale, alpha, hot]
func _words_place(glide: float) -> Array:
	var slam := HIT - SLAM_LEN
	var k := clampf((t - slam) / SLAM_LEN, 0.0, 1.0)
	var scale := lerpf(2.6, 1.12, k * k)
	if t > HIT:
		scale = 1.12 * (1.0 - 0.05 * exp(-(t - HIT) * 9.0) * cos((t - HIT) * 30.0))
	var centre := _words_center()
	if glide > 0.0 and logo:
		centre = centre.lerp(logo.get_global_rect().get_center(), glide)
		scale = lerpf(1.12, 1.0, glide)
	var hot := clampf(1.0 - (t - HIT) / 0.4, 0.0, 1.0) * float(t > HIT)
	return [centre, scale, maxf(k, glide), hot]


## The warm glow behind the words.
func _draw_words_glow(glide: float) -> void:
	var place := _words_place(glide)
	var centre: Vector2 = place[0]
	var scale: float = place[1]
	var alpha: float = place[2]
	var hot: float = place[3]
	if alpha <= 0.0:
		return
	var gw := Hud.logo_size().x * 0.65 * scale
	_canvas.draw_texture_rect(_glow, Rect2(centre - Vector2(gw, 80 * scale), Vector2(gw, 80 * scale) * 2.0), false,
		Color(1.0, 0.4, 0.1, (0.15 + hot * 0.45) * alpha * (1.0 - glide)))


## BONE CHAIN itself, the same picture as the title screen's logo.
func _draw_words() -> void:
	var place := _words_place(_glide())
	var centre: Vector2 = place[0]
	var scale: float = place[1]
	var alpha: float = place[2]
	var hot: float = place[3]
	if alpha <= 0.0:
		return
	var ls := Hud.logo_size()
	# Drawn around the middle of the words, so they grow and shrink in place.
	_words.draw_set_transform(centre + _off, 0.0, Vector2(scale, scale))
	# White-hot for a moment as the letters land.
	var heat := 1.0 + hot * 0.9
	_words.draw_texture_rect(Hud.LOGO, Rect2(-ls * 0.5, ls), false, Color(heat, heat, 1.0 + hot * 0.7, alpha))


static func _radial() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.4, Color(1, 1, 1, 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex
