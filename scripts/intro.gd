class_name Intro
extends CanvasLayer
## The opening scene when the game starts, about five seconds, and the game in miniature. In a
## dark crypt two torches catch and three skeletons wake; the warrior's eyes light up and it
## roars, then leaps high at you, sword overhead (the camera is the hero's eyes, looking up).
## Time slows at the top of the leap; you dodge as the blade comes down and smashes the floor
## where you stood, then your bolt bursts the warrior into bones and a burning chain lashes out
## from it to the other two skeletons, bursting each in turn. The chain hangs there burning a
## moment, then whips into the middle and snaps into BONE CHAIN as the words slam down, then
## they glide up onto the title screen's logo while the crypt fades into the title. A tap skips
## to the glide. The crypt is its own small 3D world, drawn as a picture under the words.

signal music      # the title music should start (as the words land, or on a skip)
signal handoff    # the glide to the title screen begins
signal finished

const BG := Color(0.094, 0.063, 0.149)   # Android's launch screen, which runs into this
const TORCH := Color(1.0, 0.6, 0.28)
const TAGLINE := "Dash. Chain. Descend."

# The beats, in seconds of the intro's own clock (which runs slow through the dodge).
const TORCHES := [0.12, 0.36]
const AWAKEN := 0.6
const EYES := 1.0
const CHOP := 1.3        # the warrior crouches and leaps at you (its jump chop)
const RISE := CHOP + 0.15   # its feet leave the floor
const DOWN := CHOP + 0.72   # and come down, its sword hitting the floor a moment later
const LAND := CHOP + 0.75
const LEAP_LEN := 1.9    # how far the leap carries it toward you
const LEAP_SIDE := 0.45  # and to the side, so the sword in its right hand comes down where you stand
const LEAP_ARC := 0.35   # and how much higher than the animation's own jump
const DODGE := CHOP + 0.58   # you dodge out from under the blade as it comes down
const DODGE_LEN := 0.2
const SHOT := LAND + 0.1     # then fire one bolt into the warrior
const BOLT_TIME := 0.06
const BURSTS := [2.21, 2.45, 2.69]   # the warrior, then the chain reaches the other two
const HOP := 0.16        # the chain takes this long to lash from one skeleton to the next
const SNAP := 2.99       # it hangs there burning a moment, then whips into the words
const SLAM_LEN := 0.14
const HIT := SNAP + SLAM_LEN   # the words land
const SLOW_FROM := 1.74  # the top of the leap plays in slow motion, like a perfect dodge in the game
const SLOW_TO := 1.96
const SLOW := 0.42
const TAG := HIT + 0.3
const GLINT := HIT + 0.35  # a glint of light sweeps across the letters
const GLINT_LEN := 0.45
const HANDOFF := HIT + 0.95
const WARRIOR_AT := Vector3(-0.2, 0, 0.0)
const WARRIOR_YAW := 0.15
# The camera is where you stand: low, looking up as the warrior leaps at you, then a dodge
# out to the right, from where you see the blade hit the floor and the whole chain.
const LEAP_FROM := Vector3(0.15, 1.0, 6.2)
const LEAP_AT := Vector3(-0.2, 1.5, 0.6)
const DODGE_FROM := Vector3(1.6, 2.1, 6.6)
const DODGE_AT := Vector3(-0.1, 0.6, -0.6)
const SLAM_AT := Vector3(0.0, 0.3, 3.0)   # about where the sword hits the floor
const FIGHT_FOV := 50.0
const BOLT := Color(0.55, 0.85, 1.0)
const LINK := Color(1.0, 0.6, 0.2)   # the burning chain, the gold and ember of the logo
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
var _head: Node3D               # follows the warrior's head
var _blade: Node3D              # the warrior's sword
var _eye_mat: StandardMaterial3D
var _rim: OmniLight3D
var _key: OmniLight3D
var _impact: OmniLight3D        # flares from the floor where the sword lands
var _words: Control             # draws BONE CHAIN, through the glint shader
var _glint: ShaderMaterial
var _cracks: Array = []         # glowing cracks in the floor from the hit, as point lists
var _world: Node3D
var _targets: Array = []        # the skeletons, in the order they burst: warrior, minion, archer
var _bolt: Node3D
var _links: Array = []          # the chain's links: {node, at, born, from}
var _link_mesh: TorusMesh
var _link_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D   # the fiery glow around each link
var _impact_at := -10.0         # when the floor light last flared
var _sprites: Array = []        # glowing puffs: {node, mat, vel, life, len, size, grow, col}
var _bones: Array = []          # flying bones: {node, vel, spin}
var _soft: Texture2D
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
	if PlayUpdate.instance and PlayUpdate.instance.showing():
		return   # except the UPDATE screen, which sits on top
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
	_world = world
	_soft = U.soft_circle()

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
	var warrior := _actor(world, "Skeleton_Warrior", WARRIOR_AT, WARRIOR_YAW, "Skeleton_Blade",
		[[0.0, "Skeleton_Inactive_Standing_Pose"], [AWAKEN, "Skeletons_Awaken_Standing"], [CHOP, "1H_Melee_Attack_Jump_Chop"]])
	var minion := _actor(world, "Skeleton_Minion", Vector3(-1.3, 0, -1.9), deg_to_rad(18.0), "Skeleton_Axe",
		[[0.0, "Skeleton_Inactive_Standing_Pose"], [AWAKEN + 0.55, "Skeletons_Awaken_Standing"], [AWAKEN + 1.5, "Idle_Combat"]])
	var archer := _actor(world, "Skeleton_Rogue", Vector3(1.0, 0, -2.3), deg_to_rad(-18.0), "Skeleton_Crossbow",
		[[0.0, "Skeleton_Inactive_Standing_Pose"], [AWAKEN + 0.75, "Skeletons_Awaken_Standing"], [AWAKEN + 1.7, "Idle_Combat"]])
	_add_eyes(warrior)
	if warrior:
		_blade = warrior.get_meta("weapon")
	_targets = [warrior, minion, archer]
	_bolt = Node3D.new()
	world.add_child(_bolt)
	var shaft := U.capsule(_bolt, 0.06, 0.7, _glow_mat(BOLT))
	shaft.rotation.x = PI * 0.5   # along -Z, the way look_at points it
	_bolt.visible = false
	_link_mesh = TorusMesh.new()
	_link_mesh.inner_radius = 0.09
	_link_mesh.outer_radius = 0.165
	_link_mesh.rings = 12
	_link_mesh.ring_segments = 6
	_link_mat = U.mat(LINK, 0.35, 2.6)   # solid, glowing metal
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.albedo_texture = _soft
	_halo_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.55)

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
	if weapon != "":
		node.set_meta("weapon", Art.attach_to_bone(node, "handslot.r", weapon))
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
	_head = head
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


# ---------------------------------------------------------------- the bolt and the chain

## Lights nothing and adds to whatever is behind it, like the game's bolts.
func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.r * 3.0, col.g * 3.0, col.b * 3.0)
	return m


## The warrior turns square on to you as it crouches, and its leap carries it high and most of
## the way to you.
func _place_warrior() -> void:
	var warrior := _targets[0] as Node3D
	if warrior == null:
		return
	var to_you := LEAP_FROM - WARRIOR_AT
	to_you.y = 0.0
	warrior.rotation.y = lerp_angle(WARRIOR_YAW, atan2(to_you.x, to_you.z), smoothstep(CHOP - 0.15, CHOP + 0.05, t))
	var air := clampf((t - RISE) / (DOWN - RISE), 0.0, 1.0)
	warrior.position = WARRIOR_AT + (to_you.normalized() * LEAP_LEN + Vector3(LEAP_SIDE, 0, 0)) * smoothstep(0.0, 1.0, air) + Vector3(0, LEAP_ARC * sin(air * PI), 0)


static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


## The middle of a skeleton's chest.
func _target_at(i: int) -> Vector3:
	var target := _targets[i] as Node3D
	return (target.position if target else Vector3.ZERO) + Vector3(0, 1.1, 0)


## The bolt flies from the crossbow into the warrior in BOLT_TIME, trailing light.
func _fly_bolt() -> void:
	var k := (t - SHOT) / BOLT_TIME
	_bolt.visible = k >= 0.0 and k <= 1.0
	if not _bolt.visible:
		return
	var from := _hand()
	var to := _target_at(0)
	var at := from.lerp(to, k)
	_bolt.position = at
	if not at.is_equal_approx(to):
		_bolt.look_at(to, Vector3.UP)
	for j in 3:
		_puff(at.lerp(from, randf() * 0.25), Vector3.ZERO, Color(BOLT.r, BOLT.g, BOLT.b, 0.8), 0.15, -0.5, 0.2)


## The lowest point of the warrior's sword: its tip, as it comes down.
func _blade_tip() -> Vector3:
	var low := Vector3(0, INF, 0)
	if _blade:
		for mi: MeshInstance3D in _blade.find_children("*", "MeshInstance3D", true, false):
			var box := mi.mesh.get_aabb() if mi.mesh else AABB()
			for e in 8:
				var p := mi.global_transform * box.get_endpoint(e)
				if p.y < low.y:
					low = p
	if low.y == INF:
		low = _target_at(0) + (LEAP_FROM - WARRIOR_AT).normalized() * 1.2
	return low


## Your crossbow, just below and to the right of the middle of the picture.
func _hand() -> Vector3:
	return _cam.global_transform * Vector3(0.25, -0.35, -1.3)


## A soft puff of light or dust that drifts, grows (or shrinks) and fades.
func _puff(pos: Vector3, vel: Vector3, col: Color, size: float, grow: float, life: float, glow := true) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _soft
	m.albedo_color = col
	var q := QuadMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * size
	_world.add_child(mi)
	_sprites.append({"node": mi, "mat": m, "vel": vel, "life": life, "len": life, "size": size, "grow": grow, "col": col})


func _update_sprites(dt: float) -> void:
	for s in _sprites:
		s.life -= dt
		var node := s.node as MeshInstance3D
		node.position += s.vel * dt
		s.vel *= 1.0 - minf(dt * 3.0, 0.9)
		var k := clampf(1.0 - s.life / s.len, 0.0, 1.0)
		node.scale = Vector3.ONE * maxf(0.01, s.size * (1.0 + s.grow * k))
		var c: Color = s.col
		(s.mat as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, c.a * (1.0 - k))
		if s.life <= 0.0:
			node.queue_free()
	_sprites = _sprites.filter(func(s): return s.life > 0.0)


## Skeleton i bursts: its skull, jaw and weapon fly off whole, with a spray of
## loose bones, bone dust and sparks. Each burst down the chain is a little bigger.
func _shatter(i: int) -> void:
	var target := _targets[i] as Node3D
	if target == null or not target.visible:
		return
	var chest := _target_at(i)
	var from := _hand() if i == 0 else _target_at(i - 1)
	var along := (chest - from)
	along.y = 0.0
	along = along.normalized()
	var power := 1.0 + i * 0.25
	for mi: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.material_override == _eye_mat or not _rigid(mi):
			continue
		# A loose copy of the part, spinning about its own middle.
		var middle := mi.global_transform * mi.mesh.get_aabb().get_center()
		var piece := Node3D.new()
		_world.add_child(piece)
		piece.global_position = middle
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		copy.material_override = mi.material_override
		for k in mi.get_surface_override_material_count():
			copy.set_surface_override_material(k, mi.get_surface_override_material(k))
		piece.add_child(copy)
		copy.global_transform = mi.global_transform
		_fling(piece, middle - chest, along, power)
		if mi.mesh.get_aabb().get_longest_axis_size() > 0.5:
			# A skull or weapon is big: fling it straight out of the picture (up and away from
			# the middle), so it doesn't hang there as a pale lump.
			var screen := _cam.unproject_position(middle) / Vector2(_vp.size) - Vector2(0.5, 0.5)
			var out2 := Vector2(screen.x, minf(screen.y, -0.2)).normalized()
			var basis := _cam.global_transform.basis
			_bones[-1].vel = (basis.x * out2.x - basis.y * out2.y) * 9.0 + along * 1.5
			_bones[-1].big = true
	for _j in 9:
		var bone := _loose_bone()
		bone.position = chest + Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.4), randf_range(-0.2, 0.2))
		bone.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		_fling(bone, bone.position - chest, along, power)
	target.visible = false
	for _j in 14:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized()
		_puff(chest + dir * 0.2, dir * randf_range(1.0, 3.0) * power, Color(0.8, 0.75, 0.68, 0.35), 0.5, 2.4, 0.8, false)
	for _j in 16:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-1, 1)).normalized()
		_puff(chest, dir * randf_range(4.0, 9.0) * power, Color(1.0, 0.75, 0.4, 0.95), 0.1, -0.6, randf_range(0.25, 0.5))
	_puff(chest, Vector3.ZERO, Color(LINK.r, LINK.g, LINK.b, 0.6), 0.9 * power, 1.0, 0.2)
	_impact.position = chest
	_impact_at = t
	Sfx.play("crack", 0.8, 0.9 + i * 0.15)
	Sfx.play("hit", 0.9, 0.9 + i * 0.2)
	_shake = maxf(_shake, 6.0 + i * 2.0)


## The parts that keep their shape when they come loose: the skull, jaw, eyes and weapon. The
## arms, legs and body would come loose stiff and posed, and a flying helmet or hood is just a
## dark lump, so they don't.
static func _rigid(mi: MeshInstance3D) -> bool:
	for end in ["_Helmet", "_Hood", "_Cape", "_Cloak"]:
		if mi.name.ends_with(end):
			return false
	if mi.skin == null and mi.skeleton == NodePath(""):
		return true
	for end in ["_Head", "_Jaw", "_Eyes"]:
		if mi.name.ends_with(end):
			return true
	return false


## A plain bone, a shaft with a knob at each end.
func _loose_bone() -> Node3D:
	var bone := Node3D.new()
	_world.add_child(bone)
	var m := U.mat(Color(0.9, 0.86, 0.76), 0.75)
	var length := randf_range(0.26, 0.42)
	U.capsule(bone, 0.045, length, m)
	for end: float in [-0.5, 0.5]:
		U.sphere(bone, 0.065, m, Vector3(0.04, length * end, 0))
		U.sphere(bone, 0.065, m, Vector3(-0.04, length * end, 0))
	bone.scale = Vector3.ONE * randf_range(0.8, 1.2)
	return bone


## Sends a piece flying: on along the hit, out from the middle of the burst (never back at
## the camera, where it would fill the picture), and up.
func _fling(piece: Node3D, out: Vector3, along: Vector3, power: float) -> void:
	out.y = 0.0
	out = out.normalized() if out.length() > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var away := piece.position - _cam.position
	away.y = 0.0
	out = (out + away.normalized()).normalized()
	var vel := (along * randf_range(1.0, 2.5) + out * randf_range(1.5, 3.0)) * power
	vel.y = randf_range(2.0, 4.0)
	_bones.append({"node": piece, "vel": vel, "spin": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 12.0, "big": false})


## The burning chain. It lashes from each burst skeleton to the next (link by link, sagging a
## little like a real chain), then every link whips into the middle of the picture, where the
## words land.
func _update_chain() -> void:
	for i in BURSTS.size() - 1:
		var start: float = BURSTS[i] + 0.05
		var a := _target_at(i)
		var b := _target_at(i + 1)
		var count := maxi(4, int(a.distance_to(b) / 0.3))
		var reach := clampf((t - start) / HOP, 0.0, 1.0)
		var made := _links.filter(func(l): return l.hop == i).size()
		while t >= start and t < SNAP and made < count and float(made) / count <= reach:
			var k := float(made) / (count - 1)
			var at := a.lerp(b, k) + Vector3(0, -sin(k * PI) * 0.3, 0)
			var next := a.lerp(b, k + 0.01) + Vector3(0, -sin((k + 0.01) * PI) * 0.3, 0)
			var link := MeshInstance3D.new()
			link.mesh = _link_mesh
			link.material_override = _link_mat
			link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(link)
			link.look_at_from_position(at, next, Vector3.UP)
			link.rotate_object_local(Vector3(0, 0, 1), PI * 0.5 * (made % 2))
			link.scale = Vector3(1.0, 1.0, 1.7)
			var halo := MeshInstance3D.new()
			halo.mesh = QuadMesh.new()
			halo.material_override = _halo_mat
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			halo.position = at
			halo.scale = Vector3.ONE * 0.7
			_world.add_child(halo)
			_links.append({"node": link, "halo": halo, "hop": i, "from": at, "born": t, "k": i + k})
			_puff(at, Vector3.ZERO, Color(LINK.r, LINK.g, LINK.b, 0.45), 0.35, 0.6, 0.2)
			made += 1
	# Burning: it flickers, and once it reaches the last skeleton a pulse of heat runs along it.
	_link_mat.emission_energy_multiplier = 2.6 + 0.6 * sin(t * 47.0) * sin(t * 19.0)
	var taut: float = BURSTS[-1] + 0.05
	if t < SNAP:
		for l in _links:
			var node := l.node as Node3D
			var pulse := 0.0
			if t > taut:
				var wave := (t - taut) / (SNAP - taut) * 2.4   # runs from the warrior's end (0) past the archer's (2)
				pulse = maxf(0.0, 1.0 - absf(l.k - wave) / 0.4)
			node.scale = Vector3(1.0, 1.0, 1.7) * (1.0 + 0.5 * exp(-(t - l.born) * 20.0) + 0.35 * pulse)
			(l.halo as Node3D).scale = Vector3.ONE * (0.7 + 0.6 * pulse)
		return
	# Whip into the words: the far end of the chain goes first.
	var to := _cam.project_position(_words_center() * (Vector2(_vp.size) / _canvas.size), 2.5)
	for j in _links.size():
		var l: Dictionary = _links[j]
		var node := l.node as Node3D
		var k := clampf((t - SNAP - 0.04 * (1.0 - float(j) / _links.size())) / (SLAM_LEN - 0.04), 0.0, 1.0)
		node.visible = k < 1.0
		node.position = (l.from as Vector3).lerp(to, k * k)
		node.scale = Vector3(1.0, 1.0, 1.7) * (1.0 - 0.6 * k)
		var halo := l.halo as Node3D
		halo.visible = node.visible
		halo.position = node.position


func _update_bones(dt: float) -> void:
	for b in _bones:
		var node := b.node as Node3D
		b.vel.y -= 16.0 * dt
		node.position += b.vel * dt
		node.rotation += b.spin * dt
		if b.big and not _cam.is_position_in_frustum(node.position):
			node.visible = false   # gone for good, rather than falling back into the picture
		if node.position.y < 0.12 and b.vel.y < 0.0:
			node.position.y = 0.12
			b.vel = Vector3(b.vel.x * 0.6, -b.vel.y * 0.3, b.vel.z * 0.6)
			b.spin *= 0.5


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
		if _crossed(was, CHOP + 0.15):
			Sfx.play("dash", 0.8, 0.7)   # the warrior launches itself at you
		if _crossed(was, RISE):
			Sfx.play("roar", 0.75, 0.75)   # a war cry as it leaves the floor
		if _crossed(was, DODGE):
			# Like a perfect dodge in the game: a slowed whoosh and a bone crack.
			Sfx.play("dash", 0.9, 0.7)
			Sfx.play("crack", 0.6, 1.2)
		if _crossed(was, LAND):
			# The blade bites into the floor where you stood a moment ago, in a spray of sparks.
			Sfx.play("slam", 0.95)
			Sfx.play("crack", 0.7, 0.8)
			_shake = 11.0
			var at := _blade_tip()
			at.y = 0.1
			for i in 10:
				_puff(at + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.2, 0.2)),
					Vector3(randf_range(-2.5, 2.5), randf_range(0.3, 1.4), randf_range(-1, 1.5)), Color(0.6, 0.55, 0.65, 0.4), 0.6, 2.2, 0.7, false)
			for i in 18:
				var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)).normalized()
				_puff(at, dir * randf_range(3.0, 7.0), Color(1.0, 0.7, 0.35, 0.95), 0.08, -0.5, randf_range(0.25, 0.5))
			_puff(at, Vector3.ZERO, Color(1.0, 0.6, 0.25, 0.7), 1.2, 0.8, 0.25)
			_impact.position = at + Vector3(0, 0.3, 0)
			_impact_at = t
		if _crossed(was, SHOT):
			Sfx.play("shoot", 0.8)
		for i in BURSTS.size():
			if _crossed(was, BURSTS[i]):
				_shatter(i)
			if i > 0 and _crossed(was, BURSTS[i - 1] + 0.05):
				Sfx.play("dash", 0.6, 1.3 + i * 0.15)   # the chain lashing out
		if _crossed(was, BURSTS[-1] + 0.05):
			Sfx.play("ignite", 0.9, 0.8)   # the whole chain flares up
		if _crossed(was, SNAP):
			Sfx.play("dash", 0.9, 0.8)
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
	_place_warrior()
	_fly_bolt()
	_update_chain()
	_update_sprites(step)
	_update_bones(step)
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
	var flare := clampf(1.0 - (t - _impact_at) / 0.35, 0.0, 1.0)
	_impact.light_energy = 6.0 * flare * flare
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
	# the eyes light up, then back to where you stand as it leaps at you, and a dodge up and to
	# the side (with a lean) as the blade comes down.
	var k := smoothstep(0.0, 1.0, clampf(t / HANDOFF, 0.0, 1.0))
	var from := Vector3(0.5, 1.05, 7.6).lerp(Vector3(0.1, 1.3, 6.6), k)
	var at := Vector3(0.0, 0.65, 0.0).lerp(Vector3(0.0, 0.9, 0.4), k)
	var close := smoothstep(EYES - 0.2, EYES + 0.1, t) * (1.0 - smoothstep(CHOP - 0.1, CHOP + 0.15, t))
	from = from.lerp(Vector3(0.1, 1.6, 3.7), close) + WARRIOR_AT
	at = at.lerp(Vector3(0.0, 1.45, 0.0), close) + WARRIOR_AT
	var leap := smoothstep(CHOP - 0.1, CHOP + 0.15, t)
	from = from.lerp(LEAP_FROM, leap)
	# Your eyes follow it up into the air.
	var look := LEAP_AT
	if _head and _blade:
		look = LEAP_AT.lerp(_head.global_position.lerp(_blade.global_position, 0.35), 0.6)
	at = at.lerp(look, leap)
	var dodge := _ease_out(clampf((t - DODGE) / DODGE_LEN, 0.0, 1.0))
	var push := smoothstep(DODGE + DODGE_LEN, HANDOFF, t)
	from = from.lerp(DODGE_FROM + Vector3(-0.2, -0.2, -0.6) * push, dodge)
	at = at.lerp(DODGE_AT, dodge)
	# A glance down at the sword as it bites into the floor, then over to the chain.
	at = at.lerp(SLAM_AT, 0.4 * smoothstep(DODGE, LAND, t) * (1.0 - smoothstep(SHOT, BURSTS[1], t)))
	_cam.fov = lerpf(40.0, FIGHT_FOV, leap)
	_cam.look_at_from_position(from, at)
	_cam.rotate_object_local(Vector3(0, 0, 1), -sin(dodge * PI) * 0.14)
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
		_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.25, 0.35, 0.85, 0.12 * slow))
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
