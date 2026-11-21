class_name Fx
## One-shot particle effects built in code: hit sparks, bone bursts, dust and magic.

static var _quad: QuadMesh
static var _shrink: Curve
## At most this many hit-spark and bone bursts start in one frame. A mass kill (Shatter,
## chained explosions) used to start 20 at once, a 93 ms hitch on a warm phone (Nov 1
## report); the extras in that frame are skipped, which nobody can see in the crowd. Other
## effects (spawn dust, beams, explosions) always show: they tell you what's coming.
const BURSTS_PER_FRAME := 8
static var _burst_frame := -1
static var _bursts_now := 0


## `shape`: "glow" (a soft light added to what's behind it), "soft" (a soft puff painted
## over it), "dot" (a crisp round spark) or "glint" (a four-pointed star). See _shaped.
static func _burst(pos: Vector3, count: int, color: Color, size: float, speed: float, life: float, gravity: float, capped := false, shape := "glow") -> void:
	var world := Game.world
	if world == null:
		return
	if capped:
		var frame := Engine.get_process_frames()
		if frame != _burst_frame:
			_burst_frame = frame
			_bursts_now = 0
		_bursts_now += 1
		if _bursts_now > BURSTS_PER_FRAME:
			return
	_burst_material()

	var p := _take_burst(world)
	p.mesh = _shaped(shape)
	p.amount = count
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8 * gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.scale_amount_curve = _shrink
	p.color = color
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.position = pos
	p.restart()


## Finished bursts wait here to be used again, instead of a new emitter (and a free a moment
## later) for every hit, kill and puff. Past POOL_MAX idle ones, extras are freed.
const POOL_MAX := 48
## Untyped on purpose: an emitter freed with its parent (the warm-up frees what it made)
## stays in the list as a freed object, and a typed read of one is a script error.
static var _free_bursts: Array = []


static func _take_burst(world: Node3D) -> CPUParticles3D:
	while not _free_bursts.is_empty():
		var old: Variant = _free_bursts.pop_back()
		if is_instance_valid(old) and (old as Node).get_parent() == world and not (old as Node).is_queued_for_deletion():
			return old as CPUParticles3D
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	world.add_child(p)
	p.finished.connect(_return_burst.bind(p))
	return p


static func _return_burst(p: CPUParticles3D) -> void:
	if not is_instance_valid(p):
		return
	if _free_bursts.size() >= POOL_MAX:
		p.queue_free()
	elif not _free_bursts.has(p):
		_free_bursts.append(p)


static func _burst_material() -> void:
	if _quad != null:
		return
	_shrink = Curve.new()   # every burst shrinks its particles the same way: one shared curve
	_shrink.add_point(Vector2(0, 1))
	_shrink.add_point(Vector2(1, 0))
	_quad = QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = U.soft_circle()
	_quad.material = m


static var _shapes := {}


## The quad a particle is drawn on. Each keeps its scale (billboard_keep_scale): without it
## every particle was drawn 1 m wide whatever size it was given (until version 102), which
## made sparks and magic into big soft blobs.
static func _shaped(shape: String) -> QuadMesh:
	_burst_material()
	if shape == "glow":
		return _quad
	if not _shapes.has(shape):
		var q := QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = {"soft": U.soft_circle(), "dot": U.dot(), "glint": U.glint()}.get(shape, U.soft_circle())
		q.material = m
		_shapes[shape] = q
	return _shapes[shape]


## A slow stream of gold sparkles for a Master hero (hero.gd _build_sparkles). They are
## left in the world (not carried along), so they mark the path the hero ran.
static func sparkle_trail(color: Color) -> CPUParticles3D:
	_burst_material()
	var p := CPUParticles3D.new()
	p.mesh = _shaped("glint")
	p.amount = 18
	p.lifetime = 1.2
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.65
	p.scale_amount_curve = _shrink
	p.color = color
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.65
	p.emission_ring_inner_radius = 0.45
	p.emission_ring_height = 0.1
	return p


## A Master aura's trail of light (hero_style.gd), one small emitter like sparkle_trail:
## "wisps" (the Rogue: dark sparks left hanging behind as they run), "motes" (the Knight:
## specks of light rising straight up round them), "embers" (the Barbarian: sparks flung up
## and falling back), "stars" (the Mage: slow twinkles in a ring). They start outside the
## hero's body (from above, anything over the hero hides them), and are painted over the
## floor rather than added to it, so they keep their colour on bright floors and never
## pile up into a white blur.
static func motif(kind: String, color: Color, size := 1.0) -> CPUParticles3D:
	var p := sparkle_trail(color)
	# Round sparks for the Rogue's wisps and the Barbarian's embers, four-pointed glints for
	# the Knight's motes and the Mage's stars.
	var shape := "dot" if kind in ["wisps", "embers", "souls", "snow", "fireflies", "blades"] else ("soft" if kind == "bubbles" else "glint")
	p.mesh = _shaped(shape)
	p.color = Color(color, 0.85 if kind in ["wisps", "snow", "blades"] else (0.45 if kind == "souls" else (0.8 if kind == "bubbles" else 1.0)))
	var run := size > 1.2   # (hero.gd draws a run's aura at 1.4: seen from far above, kept fainter)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	match kind:
		"wisps":
			p.amount = 26
			p.lifetime = 0.9
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.3
			p.gravity = Vector3(0, 0.3, 0)
			p.scale_amount_min = 0.14
			p.scale_amount_max = 0.24
			p.emission_ring_radius = 0.72
			p.emission_ring_inner_radius = 0.55
			p.position = Vector3(0, 0.3, 0)
		"motes":
			p.amount = 18
			p.lifetime = 1.2
			p.spread = 5.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.1
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.45
			p.scale_amount_max = 0.7
			p.emission_ring_radius = 0.78
			p.emission_ring_inner_radius = 0.66
			p.position = Vector3(0, 0.05, 0)
		"embers":
			p.amount = 22
			p.lifetime = 0.8
			p.spread = 45.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 1.9
			p.gravity = Vector3(0, -2.0, 0)
			p.scale_amount_min = 0.14
			p.scale_amount_max = 0.24
			p.emission_ring_radius = 0.72
			p.emission_ring_inner_radius = 0.5
			p.position = Vector3(0, 0.3, 0)
		"regal":
			# The Crypt King: big gold glints rising slowly in a wide ring, and hanging behind.
			p.amount = 10   # (16, up to 0.95 before v142: a gold haze over the hero in fights)
			p.lifetime = 1.6
			p.spread = 12.0
			p.initial_velocity_min = 0.45
			p.initial_velocity_max = 0.8
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.6
			p.emission_ring_radius = 1.0
			p.emission_ring_inner_radius = 0.85
			p.position = Vector3(0, 0.05, 0)
		# Feat and Bone Drop auras (hero_style.gd EXTRA), for any hero:
		"quick":
			# Quickstep: quick bright streaks shooting up off the feet.
			p.amount = 24
			p.lifetime = 0.45
			p.spread = 15.0
			p.initial_velocity_min = 1.8
			p.initial_velocity_max = 2.6
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.42
			p.emission_ring_radius = 0.72
			p.emission_ring_inner_radius = 0.5
			p.position = Vector3(0, 0.1, 0)
		"storm":
			# Stormcaller: sparks crackling out in every direction.
			p.amount = 22
			p.lifetime = 0.3
			p.spread = 180.0
			p.initial_velocity_min = 1.6
			p.initial_velocity_max = 3.2
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.55
			p.emission_ring_radius = 0.55
			p.emission_ring_inner_radius = 0.3
			p.position = Vector3(0, 0.6, 0)
		"comet":
			# The Crypt Race's Comet auras: bright glints left streaming behind the hero as they
			# run (the trail stays where it was made), drifting up a little as they fade.
			p.amount = 30
			p.lifetime = 0.75
			p.spread = 180.0
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.25
			p.gravity = Vector3(0, 0.6, 0)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.55
			p.emission_ring_radius = 0.5
			p.emission_ring_inner_radius = 0.2
			p.position = Vector3(0, 0.6, 0)
		"souls":
			# Phantom: pale souls drifting slowly up and fading.
			p.amount = 12
			p.lifetime = 2.0
			p.spread = 15.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.5
			p.gravity = Vector3(0, 0.2, 0)
			# (Version 183: smaller and fainter. Big souls made a fog over the hero from above:
			# Golden Souls a yellow haze, Phantom a white one.)
			p.scale_amount_min = 0.26
			p.scale_amount_max = 0.42
			p.emission_ring_radius = 0.8
			p.emission_ring_inner_radius = 0.5
			p.position = Vector3(0, 0.1, 0)
		"sun":
			# Sunflare: big golden glints rising in a wide ring.
			p.amount = 20
			p.lifetime = 1.1
			p.spread = 30.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 1.4
			p.gravity = Vector3(0, 0.5, 0)
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.75
			p.emission_ring_radius = 1.0
			p.emission_ring_inner_radius = 0.8
			p.position = Vector3(0, 0.05, 0)
		"arcane":
			# Arcane: glints hanging in a ring at chest height.
			p.amount = 14
			p.lifetime = 1.6
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.25
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.45
			p.scale_amount_max = 0.7
			p.emission_ring_radius = 1.0
			p.emission_ring_inner_radius = 0.9
			p.position = Vector3(0, 0.7, 0)
		"snow":
			# Snowfall: small flakes drifting down in a ring round the hero. (Version 175:
			# they were big white balls falling from over the head, and sat on every hat.)
			p.amount = 30
			p.lifetime = 1.9
			p.direction = Vector3.DOWN
			p.spread = 18.0
			p.initial_velocity_min = 0.35
			p.initial_velocity_max = 0.6
			p.gravity = Vector3(0, -0.3, 0)
			p.scale_amount_min = 0.08
			p.scale_amount_max = 0.16
			p.emission_ring_radius = 1.1
			p.emission_ring_inner_radius = 0.7
			p.position = Vector3(0, 1.7, 0)
		"bubbles":
			# Bubbles: soft green bubbles wobbling up.
			p.amount = 20
			p.lifetime = 1.4
			p.spread = 20.0
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 0.7
			p.gravity = Vector3(0, 0.3, 0)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.55
			p.emission_ring_radius = 0.7
			p.emission_ring_inner_radius = 0.3
			p.position = Vector3(0, 0.1, 0)
		"fireflies":
			# Fireflies: little lights wandering round the hero, blinking.
			p.amount = 18
			p.lifetime = 2.2
			p.spread = 180.0
			p.initial_velocity_min = 0.15
			p.initial_velocity_max = 0.35
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.3   # (0.2 to 0.32 before version 176: they could hardly be seen)
			p.scale_amount_max = 0.46
			p.emission_ring_radius = 1.1
			p.emission_ring_inner_radius = 0.6
			p.position = Vector3(0, 0.6, 0)
			var blink := Gradient.new()
			blink.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.55, 0.75, 1.0])
			blink.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0.15), Color.WHITE, Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)])
			p.color_ramp = blink
		"bats":
			# Blood Moon (the event aura): blood sparks drifting up, and a swarm of little
			# bats circling the hero (Fx.bats) that rides along with the sparks.
			p.amount = 14
			p.lifetime = 1.0
			p.spread = 30.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.1
			p.gravity = Vector3(0, 0.4, 0)
			p.scale_amount_min = 0.16
			p.scale_amount_max = 0.26
			p.emission_ring_radius = 0.8
			p.emission_ring_inner_radius = 0.5
			p.position = Vector3(0, 0.1, 0)
			# (Version 200: night-indigo bats edged in the aura's gold, flying close round the
			# hero. Lemon-yellow bats a hero-width out read as coins or shots in a run.)
			p.add_child(bats(Color(0.2, 0.12, 0.42), 5, 0.85 * size, 0.6, 0.3 * size, 1.7, Color(color, 1.0)))
		"globe":
			# Frostfall's Snow Globe (version 244): tiny glints of snow settling round the
			# hero, and big snowflakes swirling round them as if the globe were shaken (Fx.flakes).
			p.amount = 16
			p.lifetime = 1.6
			p.direction = Vector3.DOWN
			p.spread = 25.0
			p.initial_velocity_min = 0.25
			p.initial_velocity_max = 0.5
			p.gravity = Vector3(0, -0.2, 0)
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.22
			p.emission_ring_radius = 0.95
			p.emission_ring_inner_radius = 0.55
			p.position = Vector3(0, 1.4, 0)
			p.add_child(flakes(Color(color, 1.0), 6, 0.9 * size, 0.9, 0.26 * size, 1.1, Color(0.35, 0.6, 1.0)))
		"aurora":
			# Polar Night (version 244): the northern lights hanging round the hero, slowly
			# drifting round (Fx.curtains), with a few stars twinkling in the night between.
			p.amount = 8
			p.lifetime = 1.8
			p.spread = 180.0
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.15
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.55
			p.emission_ring_radius = 1.0
			p.emission_ring_inner_radius = 0.8
			p.position = Vector3(0, 1.2, 0)
			p.add_child(curtains(Color(0.3, 1.0, 0.65), Color(0.7, 0.45, 1.0), 5, 0.95 * size, 1.25 * size))
		# Version 252 (whole-game review fix 6): the four level-20 Mastery auras, each a shape
		# of its own (until then all four were one orange-gold column of light).
		"blades":
			# Nightlord, the Rogue: three shadow daggers circling him, edged in silver, each
			# leaving two fading ghosts of itself (Fx.blades), over dark sparks hanging behind.
			p.amount = 14
			p.lifetime = 0.8
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.25
			p.gravity = Vector3(0, 0.25, 0)
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.2
			p.emission_ring_radius = 0.75
			p.emission_ring_inner_radius = 0.55
			p.position = Vector3(0, 0.3, 0)
			p.add_child(blades(Color(0.14, 0.06, 0.28), Color(color, 1.0), 3, 0.95 * size, 0.45, 0.62 * size, 2.4))
		"mane":
			# Lionheart, the Knight: a lion's mane of light, tongues of gold flame round his
			# head (Fx.mane), and gold glints rising.
			p.amount = 12
			p.lifetime = 1.0
			p.spread = 10.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 0.9
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.55
			p.emission_ring_radius = 0.8
			p.emission_ring_inner_radius = 0.6
			p.position = Vector3(0, 0.05, 0)
			p.add_child(mane(Color(1.0, 0.48, 0.08), Color(1.0, 0.93, 0.62), 0.95 * size, 1.35, 0.55 if run else 1.0))
		"lightning":
			# Worldbreaker, the Barbarian: lightning leaping off him to strike the floor round
			# him (Fx.lightning), and sparks crackling.
			p.amount = 14
			p.lifetime = 0.3
			p.spread = 180.0
			p.initial_velocity_min = 1.4
			p.initial_velocity_max = 2.8
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.45
			p.emission_ring_radius = 0.55
			p.emission_ring_inner_radius = 0.3
			p.position = Vector3(0, 0.6, 0)
			p.add_child(lightning(Color(0.88, 1.0, 1.0), Color(color, 1.0), Color(0.68, 0.42, 1.0), 4, 1.3 * size, 0.57, 0.75, 0.6 * size))
		"orrery":
			# Starsage, the Mage: gold stars running round two tilted rings that turn round
			# her, like the planets in an orrery (Fx.orrery).
			p.amount = 8
			p.lifetime = 1.4
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.3
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.6
			p.emission_ring_radius = 0.9
			p.emission_ring_inner_radius = 0.7
			p.position = Vector3(0, 0.9, 0)
			p.add_child(orrery(Color(0.25, 1.0, 0.6), Color(color, 1.0), 0.95 * size, 0.32 * size, 0.55 if run else 1.0))
		"stars":
			p.amount = 10
			p.lifetime = 1.4
			p.spread = 180.0
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.4
			p.gravity = Vector3.ZERO
			p.scale_amount_min = 0.6
			p.scale_amount_max = 0.9
			p.emission_ring_radius = 0.92
			p.emission_ring_inner_radius = 0.8
			p.position = Vector3(0, 0.4, 0)
	p.scale_amount_min *= size
	p.scale_amount_max *= size
	return p


## Version 116: an aura's own shape on the floor round the hero, so it reads from the game
## camera even when the outline is a few pixels wide: a turning ring of `marks` dashes
## (stars, sparks, souls...) in the aura's two colours. One quad, one small shader.
static var _ground_shader: Shader

static func aura_ground(ink: Color, ink2: Color, marks: int, radius := 1.25) -> MeshInstance3D:
	if _ground_shader == null:
		_ground_shader = Shader.new()
		_ground_shader.code = AURA_GROUND
	var m := ShaderMaterial.new()
	m.shader = _ground_shader
	m.set_shader_parameter("ink", ink)
	m.set_shader_parameter("ink2", ink2)
	m.set_shader_parameter("marks", float(marks))
	var q := PlaneMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.035, 0)
	return mi


const AURA_GROUND := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 ink : source_color = vec4(1.0);
uniform vec4 ink2 : source_color = vec4(1.0);
uniform float marks = 6.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float turn = fract(a + TIME * 0.08);
	// a thin ring, with marks that brighten one after another round it
	float ring = smoothstep(0.035, 0.0, abs(r - 0.78));
	float seg = fract(turn * marks);
	float mark = smoothstep(0.09, 0.0, abs(r - 0.9)) * step(seg, 0.32);
	float wave = 0.5 + 0.5 * sin(TIME * 3.0 - floor(turn * marks) * 1.3);
	vec3 c = mix(ink.rgb, ink2.rgb, wave);
	float alpha = ring * 0.55 + mark * (0.4 + 0.5 * wave);
	alpha *= smoothstep(1.0, 0.92, r);
	ALBEDO = c * 1.3;
	ALPHA = clamp(alpha, 0.0, 0.85);
}
"""


static func sparks(pos: Vector3, color := Color(1.0, 0.85, 0.5)) -> void:
	_burst(pos, 10, color, 0.4, 7.0, 0.35, 0.5, true, "dot")


static func bones(pos: Vector3) -> void:
	_burst(pos + Vector3.UP * 0.6, 22, Color(0.95, 0.92, 0.82), 0.42, 6.0, 0.8, 2.0, true, "dot")


static func dust(pos: Vector3, count := 14) -> void:
	_burst(pos + Vector3.UP * 0.2, count, Color(0.62, 0.58, 0.68, 0.5), 1.4, 1.6, 0.9, -0.05, false, "soft")


## A quick flash of light where a shot lands: pops big, then shrinks away (0.14 s).
static func impact(pos: Vector3, color: Color, size := 1.0) -> void:
	var world := Game.world
	if world == null:
		return
	var key := Engine.get_process_frames()
	if key != _impact_frame:
		_impact_frame = key
		_impacts_now = 0
	_impacts_now += 1
	if _impacts_now > BURSTS_PER_FRAME:
		return
	# At most MAX_IMPACTS on screen: a Mage with Twin Shots, Fan of Shots and Piercing Shot
	# lands a dozen hits a frame, and each flash is one more thing to draw. Version 126
	# (audit #12): the flashes are made once and reused; a hidden one is free.
	var f: MeshInstance3D = null
	for n in _impacts:
		if is_instance_valid(n) and not (n as MeshInstance3D).visible:
			f = n
			break
	if f == null:
		_impacts = _impacts.filter(func(n): return is_instance_valid(n))
		if _impacts.size() >= MAX_IMPACTS:
			return
		if _impact_quad == null:
			_impact_quad = QuadMesh.new()
		f = MeshInstance3D.new()
		f.mesh = _impact_quad
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(f)
		_impacts.append(f)
	f.material_override = ShotLook.hero_mat(ShotLook.K_GLOW, Color(color.r, color.g, color.b, 1.0), true)
	f.visible = true
	f.global_position = pos
	f.scale = Vector3(size * 0.4, size * 0.4, 1.0)
	var old: Tween = f.get_meta("tw") if f.has_meta("tw") else null
	if old and old.is_valid():
		old.kill()
	var tw := f.create_tween()
	f.set_meta("tw", tw)
	tw.tween_property(f, "scale", Vector3(size, size, 1.0), 0.05).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "scale", Vector3(0.01, 0.01, 1.0), 0.09).set_ease(Tween.EASE_IN)
	tw.tween_callback(f.hide)

static var _impact_quad: QuadMesh
static var _impacts: Array = []   # every hit flash made, shown or waiting
const MAX_IMPACTS := 10
static var _impact_frame := -1
static var _impacts_now := 0


## A glowing after-image left behind by the dash.
static func trail(pos: Vector3, color: Color) -> void:
	_burst(pos, 6, color, 1.2, 0.6, 0.35, 0.0)


static var _rings := {}


## A ring of light that rushes outwards (the finishing blow of a room).
static func shockwave(pos: Vector3, color: Color, radius := 6.0) -> void:
	var world := Game.world
	if world == null:
		return
	# Screen shake Off also calms the big rings (accessibility review 6: reduce motion).
	radius *= lerpf(0.6, 1.0, minf(1.0, Game.shake_scale / 0.35))
	var ring := MeshInstance3D.new()
	# A crisp ring: thin (about 40 cm across at full size, however wide it grows), so it
	# never turns into a haze over the room. One mesh per ring thickness, shared by every
	# ring of that size (there are only a handful).
	var inner := snappedf(1.0 - minf(0.15, 0.4 / maxf(radius, 0.1)), 0.01)
	if not _rings.has(inner):
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = 1.0
		torus.rings = 40
		torus.ring_segments = 6
		_rings[inner] = torus
	ring.mesh = _rings[inner]
	# Its own material (the shared one from U.unlit used to be faded to nothing by the
	# first ring, so later rings of the same colour never showed). Drawn over the floor,
	# not added to it, so a gold ring stays gold on a bright floor.
	var m := U.unlit(Color(color.r, color.g, color.b, 0.85)).duplicate() as StandardMaterial3D
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.3
	ring.scale = Vector3(0.3, 0.3, 0.3)
	var tw := ring.create_tween().set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)


## Slowly drifting embers and dust in the air of a room.
## Drifting motes that give each floor its mood: embers rise, frost flakes fall.
static func ambience(parent: Node3D, half_w: float, half_l: float, amount := 36,
		colors: Array = [Color(1.0, 0.55, 0.2, 0.9), Color(0.7, 0.6, 1.0, 0.35)], fall := false, size := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _shaped("dot")
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.direction = Vector3.DOWN if fall else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0.12, -0.15, 0.05) if fall else Vector3(0.05, 0.02, 0)
	p.scale_amount_min = 0.1 * size
	p.scale_amount_max = 0.2 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[1])
	p.color_initial_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(half_w, 1.2, half_l)
	p.position = Vector3(0, 2.6 if fall else 1.4, 0)
	parent.add_child(p)
	return p


static var _wisp_mats := {}
static var _wisp_shader: Shader

## Glowing wisps (since version 136): soft lights that wander slowly through the air of a
## room, each with a faint pool of its colour on the floor below it. All the movement is in
## the shader, and every wisp of a room is one draw for the lights and one for the pools.
static func wisps(parent: Node3D, color: Color, count: int, half_w: float, half_l: float) -> void:
	if count <= 0:
		return
	for pool in [false, true]:
		var key := "%s/%s" % [color.to_html(), pool]
		if not _wisp_mats.has(key):
			if _wisp_shader == null:
				_wisp_shader = Shader.new()
				_wisp_shader.code = WISP_CODE
			var m := ShaderMaterial.new()
			m.shader = _wisp_shader
			m.set_shader_parameter("tint", color)
			m.set_shader_parameter("pool", 1.0 if pool else 0.0)
			m.set_shader_parameter("size", 3.0 if pool else 1.1)
			_wisp_mats[key] = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if pool:
			var plane := PlaneMesh.new()
			plane.size = Vector2.ONE
			mm.mesh = plane
		else:
			var q := QuadMesh.new()
			q.size = Vector2.ONE
			mm.mesh = q
		mm.instance_count = count
		var rng := RandomNumberGenerator.new()
		rng.seed = count * 31 + int(half_w * 10)
		for i in count:
			# Spread out: one in each slice of the room's length, at a random side and height.
			var z := lerpf(-half_l, half_l, (i + 0.5) / count) * 0.75
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf_range(-half_w, half_w) * 0.6, rng.randf_range(2.6, 3.2), z)))   # above shot height (was 1.3-1.9 m)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = _wisp_mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 6.0
		parent.add_child(mi)


## A swarm of `count` bats circling their parent at `radius` and `height`, wings beating:
## one MultiMesh, drawn and moved by its shader (BAT_CODE), each bat its own speed and
## phase (instance custom data). The Blood Moon aura, the Queen's swarm, the event title.
static var _bat_shader: Shader


static func bats(color: Color, count: int, radius: float, height: float, size: float, speed := 1.2, edge := Color(0, 0, 0, 0)) -> MultiMeshInstance3D:
	if _bat_shader == null:
		_bat_shader = Shader.new()
		_bat_shader.code = BAT_CODE
	var m := ShaderMaterial.new()
	m.shader = _bat_shader
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("edge", edge)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D())
		# phase, radius, height, angular speed (every other one the other way round)
		var sp := speed * (0.8 + 0.4 * fmod(i * 0.618, 1.0)) * (1.0 if i % 3 != 2 else -1.0)
		mm.set_instance_custom_data(i, Color(float(i) / count, radius * (0.8 + 0.35 * fmod(i * 0.37, 1.0)), height * (0.7 + 0.6 * fmod(i * 0.53, 1.0)), sp))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = radius + 2.0
	return mi


## Version 244, the Snow Globe aura: `count` big snowflakes swirling round the hero like the
## snow in a shaken globe, each spinning as it rides round and bobs up and down (one quad
## each, drawn by FLAKE_CODE; `edge` is the line round each flake).
static var _flake_shader: Shader
static func flakes(color: Color, count: int, radius: float, height: float, size: float, speed := 1.0, edge := Color(0.4, 0.6, 1.0)) -> MultiMeshInstance3D:
	if _flake_shader == null:
		_flake_shader = Shader.new()
		_flake_shader.code = FLAKE_CODE
	var m := ShaderMaterial.new()
	m.shader = _flake_shader
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("edge", edge)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D())
		var sp := speed * (0.75 + 0.5 * fmod(i * 0.618, 1.0))
		mm.set_instance_custom_data(i, Color(float(i) / count, radius * (0.75 + 0.4 * fmod(i * 0.37, 1.0)), height * (0.5 + 0.9 * fmod(i * 0.53, 1.0)), sp))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = radius + 2.0
	return mi


## Version 244, the Polar Night aura: `count` curtains of the northern lights hanging round
## the hero, `top` colour above `foot`, drifting slowly round (CURTAIN_CODE). Each turns to
## face the camera round the upright, so from above they show as folds of light.
static var _curtain_shader: Shader
static func curtains(foot: Color, top: Color, count: int, radius: float, height: float) -> MultiMeshInstance3D:
	if _curtain_shader == null:
		_curtain_shader = Shader.new()
		_curtain_shader.code = CURTAIN_CODE
	var m := ShaderMaterial.new()
	m.shader = _curtain_shader
	m.set_shader_parameter("foot", foot)
	m.set_shader_parameter("top", top)
	m.set_shader_parameter("tall", height)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D())
		mm.set_instance_custom_data(i, Color(float(i) / count, radius * (0.9 + 0.2 * fmod(i * 0.37, 1.0)), 0.55 + 0.35 * fmod(i * 0.53, 1.0), 0.18 * (1.0 if i % 2 == 0 else -0.7)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = radius + height + 2.0
	return mi


## Version 252, the Nightlord aura: `count` curved shadow daggers circling the hero at
## `radius` and `height`, each pointing the way it flies and edged in `edge`, with two fading
## ghosts of itself behind (BLADE_CODE). One MultiMesh.
static var _blade_shader: Shader
static func blades(body: Color, edge: Color, count: int, radius: float, height: float, size: float, speed := 2.4) -> MultiMeshInstance3D:
	if _blade_shader == null:
		_blade_shader = Shader.new()
		_blade_shader.code = BLADE_CODE
	var m := ShaderMaterial.new()
	m.shader = _blade_shader
	m.set_shader_parameter("tint", body)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("size", size)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count * 3
	for i in count * 3:
		var b := i % count
		var ghost := i / count   # 0 the blade, 1 and 2 its fading ghosts
		mm.set_instance_transform(i, Transform3D())
		# phase, radius, height + ghost * 10 (read back in the shader), angular speed
		mm.set_instance_custom_data(i, Color(float(b) / count, radius, height + 0.12 * (b % 2) + ghost * 10.0, speed))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = radius + 2.0
	return mi


## Version 252, the Lionheart aura: a lion's mane of light, two layers of flame tongues
## (`root` colour at the hero, `tip` at their points) round the hero's head, always facing
## the camera and set back behind the hero so the hero stands in front of it (MANE_CODE).
static var _mane_shader: Shader
static func mane(tip: Color, root: Color, radius: float, height: float, power := 1.0) -> MeshInstance3D:
	if _mane_shader == null:
		_mane_shader = Shader.new()
		_mane_shader.code = MANE_CODE
	var m := ShaderMaterial.new()
	m.shader = _mane_shader
	m.set_shader_parameter("tip", tip)
	m.set_shader_parameter("root", root)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("power", power)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = radius * 2.0 + height + 2.0
	return mi


## Version 252, the Worldbreaker aura: `count` bolts of lightning, each leaping from the
## hero (`rise` above its parent) to strike the floor (`drop` below it) up to `reach` out,
## a few times a second each and somewhere new each time, forking on the way (BOLT_CODE).
static var _bolt_shader: Shader
static func lightning(core: Color, glow: Color, fork: Color, count: int, reach: float, drop: float, rise: float, width: float) -> MultiMeshInstance3D:
	if _bolt_shader == null:
		_bolt_shader = Shader.new()
		_bolt_shader.code = BOLT_CODE
	var m := ShaderMaterial.new()
	m.shader = _bolt_shader
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("fork", fork)
	m.set_shader_parameter("reach", reach)
	m.set_shader_parameter("drop", drop)
	m.set_shader_parameter("rise", rise)
	m.set_shader_parameter("width", width)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D())
		mm.set_instance_custom_data(i, Color(float(i) / count, 0.0, 0.0, 1.7 + 0.45 * i))   # own offset, strikes a second
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = reach + 2.0
	return mi


## Version 252, the Starsage aura: two thin rings tilted different ways round the hero,
## turning slowly round them like the paths of planets, with `star` coloured stars running
## along them (ORBIT_CODE, ORBIT_STAR_CODE). Two ring meshes and one MultiMesh.
const ORBITS := [[0.55, 0.32, 1.0], [-0.75, -0.24, 1.28]]   # tilt, turn speed, radius (x radius)
static var _orbit_shader: Shader
static var _orbit_star_shader: Shader
static func orrery(ring: Color, star: Color, radius: float, size: float, power := 1.0) -> Node3D:
	if _orbit_shader == null:
		_orbit_shader = Shader.new()
		_orbit_shader.code = ORBIT_CODE
		_orbit_star_shader = Shader.new()
		_orbit_star_shader.code = ORBIT_STAR_CODE
	var root := Node3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.97
	t.outer_radius = 1.03
	t.rings = 64
	t.ring_segments = 6
	for o: Array in ORBITS:
		var m := ShaderMaterial.new()
		m.shader = _orbit_shader
		m.set_shader_parameter("col", Color(ring, 0.8 * power))
		m.set_shader_parameter("orbit", Vector3(o[0], o[1], o[2] * radius))
		var mi := MeshInstance3D.new()
		mi.mesh = t
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = radius * 1.5 + 2.0
		root.add_child(mi)
	var sm := ShaderMaterial.new()
	sm.shader = _orbit_star_shader
	sm.set_shader_parameter("tint", star)
	sm.set_shader_parameter("size", size)
	sm.set_shader_parameter("orbit0", Vector3(ORBITS[0][0], ORBITS[0][1], ORBITS[0][2] * radius))
	sm.set_shader_parameter("orbit1", Vector3(ORBITS[1][0], ORBITS[1][1], ORBITS[1][2] * radius))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = 6
	for i in 6:
		mm.set_instance_transform(i, Transform3D())
		var which := i % 2
		# phase round its ring, which ring, speed along it, how big
		mm.set_instance_custom_data(i, Color(float(i / 2) / 3.0 + 0.17 * which, float(which), 1.25 if which == 0 else -0.95, 1.0 if i < 2 else 0.7))
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = mm
	smi.material_override = sm
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.extra_cull_margin = radius * 1.5 + 2.0
	root.add_child(smi)
	return root


const BLADE_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.14, 0.06, 0.28, 1.0);
uniform vec4 edge : source_color = vec4(0.9, 0.9, 1.0, 1.0);
uniform float size = 0.5;
varying vec2 dir2;
varying float glint;
varying float ghost;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	ghost = floor(c.z / 10.0);
	float h = c.z - ghost * 10.0;
	float ang = TIME * c.w + c.x * 6.2831853 - ghost * 0.2 * sign(c.w);
	float r = c.y * (1.0 + 0.08 * sin(TIME * 1.7 + c.x * 9.0));
	vec3 at = MODEL_MATRIX[3].xyz + vec3(cos(ang) * r, h + 0.1 * sin(TIME * 2.1 + c.x * 7.0), sin(ang) * r);
	// the way it flies, as the camera sees it: the blade points along it
	vec3 tng = vec3(-sin(ang), 0.0, cos(ang)) * sign(c.w);
	vec2 s = (VIEW_MATRIX * vec4(tng, 0.0)).xy;
	dir2 = length(s) > 0.0001 ? normalize(s) : vec2(1.0, 0.0);
	glint = pow(0.5 + 0.5 * sin(TIME * 3.0 + c.x * 13.0), 8.0);
	vec2 v = VERTEX.xy * (1.0 - 0.12 * ghost);
	vec3 w = at + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * size;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
// A curved dagger pointing along +x: the point at x = 0.95, a cross-guard and grip behind.
float blade(vec2 q, float g) {
	float x = q.x;
	float cy = 0.22 * (x - 0.2) * (x - 0.2) - 0.1;
	float t = clamp((x + 0.35) / 1.3, 0.0, 1.0);
	float hw = 0.19 * (1.0 - t * t) + g;
	float body = (1.0 - smoothstep(hw - 0.025, hw, abs(q.y - cy))) * step(-0.35 - g, x) * step(x, 0.95 + g);
	float guard = step(abs(x + 0.4), 0.045 + g) * step(abs(q.y), 0.22 + g);
	float grip = step(-0.72 - g, x) * step(x, -0.4) * step(abs(q.y), 0.045 + g);
	return max(body, max(guard, grip));
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	vec2 q = vec2(dot(p, dir2), dot(p, vec2(-dir2.y, dir2.x)));
	float outer = blade(q, 0.05);
	if (outer < 0.05) { discard; }
	float inner = blade(q, 0.0);
	if (ghost > 0.5) {
		// the ghosts: only the silver edge's light, fading
		ALBEDO = edge.rgb;
		ALPHA = outer * (ghost > 1.5 ? 0.18 : 0.38);
	} else {
		float shine = smoothstep(0.45, 0.95, q.x) * glint;
		ALBEDO = mix(edge.rgb * 1.25, tint.rgb + edge.rgb * 0.1, inner) + edge.rgb * shine * 0.8;
		ALPHA = outer;
	}
}
"""


const MANE_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tip : source_color = vec4(1.0, 0.48, 0.08, 1.0);
uniform vec4 root : source_color = vec4(1.0, 0.93, 0.62, 1.0);
uniform float radius = 1.0;
uniform float height = 1.35;
uniform float power = 1.0;
void vertex() {
	// round the head, facing the camera, set back behind the hero
	vec3 at = MODEL_MATRIX[3].xyz + vec3(0.0, height, 0.0) - INV_VIEW_MATRIX[2].xyz * 0.6;
	vec2 v = VERTEX.xy * 2.0 * radius;
	vec3 w = at + INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
// One ring of flame tongues: n of them reaching from r0 out to about len (0-1 of the
// quad's half width), each swaying and flickering. x: how much, y: how far out.
vec2 tongues(float r, float a, float n, float len, float off, float sd) {
	float cell = a / 6.2831853 * n + off;
	float id = floor(cell);
	float f = fract(cell) - 0.5;
	float l = len * (0.82 + 0.18 * h1(id + sd)) + 0.05 * sin(TIME * 3.3 + id * 1.9 + sd);
	float r0 = 0.3;
	float t = (r - r0) / (l - r0);
	float sway = 0.2 * sin(TIME * 2.6 + id * 2.3 + r * 7.0) * t;
	float w = 0.5 * (1.0 - t * t);
	float m = step(0.0, t) * step(t, 1.0) * (1.0 - smoothstep(w - 0.14, w, abs(f + sway)));
	return vec2(m, t);
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float r = length(p);
	float a = atan(p.y, p.x) + 0.1 * sin(TIME * 0.7);
	vec2 back = tongues(r, a, 11.0, 0.98, 0.5, 31.0);   // the long outer tongues
	vec2 front = tongues(r, a, 15.0, 0.74, 0.0, 7.0);   // the shorter, brighter inner ones
	vec3 col = mix(root.rgb, tip.rgb, smoothstep(0.15, 0.95, back.y)) * 0.95;
	float alpha = back.x * 0.75 * (1.0 - 0.5 * smoothstep(0.7, 1.0, back.y));
	vec3 fc = mix(root.rgb * 1.1, tip.rgb, smoothstep(0.3, 1.0, front.y));
	float fa = front.x * (1.0 - 0.4 * smoothstep(0.7, 1.0, front.y));
	col = mix(col, fc, fa);
	alpha = max(alpha, fa);
	float glow = exp(-pow((r - 0.42) / 0.2, 2.0)) * 0.3;
	ALBEDO = col * 1.2 + root.rgb * glow * (1.0 - alpha);
	ALPHA = clamp(alpha + glow, 0.0, 1.0) * power;
}
"""


const BOLT_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(0.88, 1.0, 1.0, 1.0);
uniform vec4 glow : source_color = vec4(0.3, 0.95, 1.0, 1.0);
uniform vec4 fork : source_color = vec4(0.68, 0.42, 1.0, 1.0);
uniform float reach = 1.3;
uniform float drop = 0.57;
uniform float rise = 0.55;
uniform float width = 0.55;
// (flat: one bolt per instance. Blended between corners, each pixel drew a bolt of its own.)
varying flat float seed;
varying flat float live;
float h1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float k = TIME * c.w + c.x * 5.0;
	float strike = mod(floor(k), 61.0);   // kept small: the hash goes coarse on big numbers
	float ph = fract(k);
	seed = strike * 1.37 + c.x * 17.0;
	// on for the first part of each strike, flickering
	live = (1.0 - smoothstep(0.32, 0.45, ph)) * (0.65 + 0.35 * step(0.5, fract(TIME * 23.0 + c.x * 3.0)));
	float ang = h1(seed) * 6.2831853;
	vec3 d = vec3(cos(ang), 0.0, sin(ang));
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 A = o + vec3(0.0, rise, 0.0) + d * 0.25;
	vec3 B = o + vec3(0.0, 0.03 - drop, 0.0) + d * reach * (0.7 + 0.3 * h1(seed + 3.1));
	vec3 ax = B - A;
	vec3 side = cross(ax, INV_VIEW_MATRIX[2].xyz);
	side = length(side) > 0.0001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
	vec3 w = (A + B) * 0.5 + ax * VERTEX.x + side * VERTEX.y * width;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
// The bolt's line across the ribbon (-1 to 1) at u along it: jagged, pinned at both ends.
float path(float u, float s) {
	float x = u * 7.0;
	float i = floor(x);
	float f = fract(x);
	float y0 = (h1(s + i) - 0.5) * (i < 0.5 ? 0.0 : 1.0);
	float y1 = (h1(s + i + 1.0) - 0.5) * (i > 5.5 ? 0.0 : 1.0);
	return mix(y0, y1, f) * 0.8;
}
void fragment() {
	if (live < 0.02) { discard; }
	float u = UV.x;
	float y = 1.0 - UV.y * 2.0;
	float d1 = abs(y - path(u, seed * 7.3));
	float side = h1(seed + 5.0) > 0.5 ? 1.0 : -1.0;
	float yf = path(u, seed * 3.1 + 9.0) * 0.5 + max(u - 0.38, 0.0) * 1.1 * side;
	float d2 = abs(y - yf) + (1.0 - step(0.38, u)) * 9.0;
	float main_l = 1.0 - smoothstep(0.06, 0.12, d1);
	float fork_l = (1.0 - smoothstep(0.04, 0.085, d2)) * (1.0 - smoothstep(0.7, 0.9, u));
	float halo = exp(-min(d1, d2) * 6.0) * 0.7;
	float hit = smoothstep(0.84, 1.0, u) * exp(-abs(y) * 2.5) * 0.8;   // the flash where it strikes
	vec3 col = mix(glow.rgb, core.rgb, main_l);
	col = mix(col, mix(fork.rgb, core.rgb, 0.35), fork_l * (1.0 - main_l));
	ALBEDO = col * 1.5 + glow.rgb * hit;
	ALPHA = clamp(max(main_l, fork_l) + halo + hit, 0.0, 1.0) * live;
}
"""


const ORBIT_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.25, 1.0, 0.6, 0.8);
uniform vec3 orbit = vec3(0.55, 0.32, 1.0);   // tilt, turn speed, radius
varying float ang;
void vertex() {
	vec3 v = VERTEX;   // a ring of radius 1 lying flat
	ang = atan(v.z, v.x);
	float c = cos(orbit.x);
	float s = sin(orbit.x);
	v = vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
	float pr = TIME * orbit.y;
	v = vec3(v.x * cos(pr) + v.z * sin(pr), v.y, -v.x * sin(pr) + v.z * cos(pr));
	VERTEX = (inverse(MODEL_MATRIX) * vec4(MODEL_MATRIX[3].xyz + v * orbit.z, 1.0)).xyz;
}
void fragment() {
	// dashes running round it
	float dash = 0.35 + 0.65 * smoothstep(0.25, 0.6, abs(fract(ang / 6.2831853 * 18.0 - TIME * 0.6) - 0.5) * 2.0);
	ALBEDO = col.rgb * 1.3;
	ALPHA = col.a * dash;
}
"""


const ORBIT_STAR_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.88, 0.5, 1.0);
uniform float size = 0.32;
uniform vec3 orbit0 = vec3(0.55, 0.32, 1.0);
uniform vec3 orbit1 = vec3(-0.75, -0.24, 1.28);
varying float tw;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;   // phase, which ring, speed along it, how big
	vec3 o = c.y < 0.5 ? orbit0 : orbit1;
	float th = TIME * c.z + c.x * 6.2831853;
	vec3 v = vec3(cos(th), 0.0, sin(th));
	float cs = cos(o.x);
	float sn = sin(o.x);
	v = vec3(v.x, v.y * cs - v.z * sn, v.y * sn + v.z * cs);
	float pr = TIME * o.y;
	v = vec3(v.x * cos(pr) + v.z * sin(pr), v.y, -v.x * sin(pr) + v.z * cos(pr));
	vec3 at = MODEL_MATRIX[3].xyz + v * o.z;
	tw = 0.75 + 0.25 * sin(TIME * 5.0 + c.x * 19.0);
	vec2 q = VERTEX.xy * size * c.w * (0.85 + 0.3 * tw);
	vec3 w = at + INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float star = exp(-abs(p.x) * 14.0) * exp(-abs(p.y) * 2.2) + exp(-abs(p.y) * 14.0) * exp(-abs(p.x) * 2.2);
	float core = exp(-length(p) * 6.0);
	float m = clamp(star + core * 1.2, 0.0, 1.0);
	if (m < 0.03) { discard; }
	ALBEDO = mix(tint.rgb, vec3(1.0), core * 0.7) * 1.4 * tw;
	ALPHA = m;
}
"""


const FLAKE_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float size = 0.3;
uniform vec4 edge : source_color = vec4(0.4, 0.6, 1.0, 1.0);
varying float spin;
varying float glint;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float ang = TIME * c.w + c.x * 6.2831853;
	float r = c.y * (1.0 + 0.18 * sin(TIME * 0.9 + c.x * 11.0));
	vec3 at = MODEL_MATRIX[3].xyz + vec3(cos(ang) * r, c.z + 0.3 * sin(TIME * 0.8 + c.x * 7.0), sin(ang) * r);
	spin = TIME * (1.2 + c.x) + c.x * 9.0;
	glint = pow(0.5 + 0.5 * sin(TIME * 2.2 + c.x * 17.0), 6.0);
	vec2 v = VERTEX.xy;
	vec3 w = at + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * size;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
float flake(vec2 p) {
	float r = length(p);
	float a = atan(p.y, p.x) + spin;
	float s6 = 1.0471976;
	float cell = fract(a / s6) - 0.5;
	vec2 g = vec2(r * cos(cell * s6), r * sin(cell * s6));
	float arm = (1.0 - smoothstep(0.06, 0.1, abs(g.y))) * step(g.x, 0.92);
	float twig = (1.0 - smoothstep(0.05, 0.09, abs(abs(g.y) - (g.x - 0.45) * 0.75))) * step(0.45, g.x) * step(g.x, 0.75);
	float hub = 1.0 - smoothstep(0.16, 0.2, r);
	return clamp(max(max(arm, twig), hub), 0.0, 1.0);
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float outer = flake(p * 0.86);
	if (outer < 0.05) { discard; }
	float inner = flake(p);
	ALBEDO = mix(edge.rgb, tint.rgb * (1.15 + 0.6 * glint), inner);
	ALPHA = outer * tint.a;
}
"""


const CURTAIN_CODE := """
shader_type spatial;
// (as alpha, not added light: on the Style pedestal's see-through picture added black
// painted a dark box behind the hero)
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 foot : source_color = vec4(0.3, 1.0, 0.65, 1.0);
uniform vec4 top : source_color = vec4(0.7, 0.45, 1.0, 1.0);
uniform float tall = 1.2;
varying float seed;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	seed = c.x;
	float ang = TIME * c.w + c.x * 6.2831853;
	vec3 at = MODEL_MATRIX[3].xyz + vec3(cos(ang) * c.y, c.z * tall, sin(ang) * c.y);
	// face the camera round the upright only, like a hanging curtain
	vec3 side = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 w = at + side * VERTEX.x * 0.9 + vec3(0.0, 1.0, 0.0) * VERTEX.y * tall;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
void fragment() {
	float x = UV.x;
	float y = 1.0 - UV.y;   // 0 at the foot
	float t = TIME;
	float wave = 0.12 * sin(x * 7.0 + t * 1.3 + seed * 20.0) + 0.06 * sin(x * 17.0 - t * 2.1);
	float foot_line = 0.18 + wave;
	float rays = 0.55 + 0.45 * sin(x * 60.0 + sin(x * 9.0 + t) * 3.0 + seed * 40.0);
	float body = smoothstep(foot_line - 0.04, foot_line + 0.06, y) * (1.0 - smoothstep(0.35, 1.0, y));
	float sides = smoothstep(0.0, 0.25, x) * smoothstep(1.0, 0.75, x);
	float pulse = 0.7 + 0.3 * sin(t * 0.9 + seed * 13.0);
	vec3 col = mix(foot.rgb, top.rgb, smoothstep(0.25, 0.8, y));
	float bright = smoothstep(0.06, 0.0, abs(y - foot_line - 0.05)) * 0.35;
	ALBEDO = col * 1.25;
	ALPHA = clamp((body * (0.25 + rays * 0.5) + bright) * sides * pulse, 0.0, 1.0);
}
"""


const BAT_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.2, 0.15, 1.0);
uniform float size = 0.3;
uniform vec4 edge : source_color = vec4(0.0);   // an outline colour (alpha 0: none)
varying float flap;
void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float ang = TIME * c.w + c.x * 6.2831853;
	float r = c.y * (1.0 + 0.15 * sin(TIME * 1.3 + c.x * 9.0));
	vec3 at = MODEL_MATRIX[3].xyz + vec3(cos(ang) * r, c.z + 0.2 * sin(TIME * 2.3 + c.x * 7.0), sin(ang) * r);
	flap = sin(TIME * 15.0 + c.x * 20.0);
	vec2 v = VERTEX.xy;
	v.x *= 2.0 * (0.45 + 0.55 * abs(flap));   // wide wings, beating
	vec3 w = at + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * size;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}
float bat(vec2 p) {
	float ax = abs(p.x);
	float body = 1.0 - smoothstep(0.42, 0.5, length(vec2(p.x * 3.0, p.y * 1.6 + 0.1)));
	float head = 1.0 - smoothstep(0.12, 0.16, length(vec2(p.x * 1.1, p.y - 0.36)));
	float ear = step(0.4, p.y) * step(p.y, 0.68) * step(abs(ax - 0.08), 0.06 * (0.68 - p.y) / 0.28);
	float top = 0.35 - 0.55 * (ax - 0.1) + 0.15 * sin(ax * 3.14);
	float bottom = -0.25 + 0.3 * ax + 0.12 * abs(sin(ax * 9.42));
	float wing = step(0.08, ax) * step(ax, 0.97) * smoothstep(bottom, bottom + 0.04, p.y) * (1.0 - smoothstep(top - 0.04, top, p.y));
	return clamp(body + head + ear + wing, 0.0, 1.0);
}
void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float m = bat(p);
	if (m < 0.05) { discard; }
	if (edge.a > 0.5) {
		// A dark bat with a bright edge: the inside is the same bat drawn a little smaller.
		float inner = bat(p * vec2(1.16, 1.3) + vec2(0.0, 0.02));
		ALBEDO = mix(edge.rgb * (1.1 + 0.3 * abs(flap)), tint.rgb, inner);
	} else {
		ALBEDO = tint.rgb * (1.3 + 0.5 * abs(flap));
	}
	ALPHA = m * tint.a;
}
"""


const WISP_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color;
uniform float pool = 0.0;
uniform float size = 0.5;
varying float fade;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float seed = o.x * 1.7 + o.z * 3.1;
	float t = TIME * 0.28 + seed;
	vec3 off = vec3(sin(t) * 1.5 + sin(t * 2.3 + 1.0) * 0.45, sin(t * 1.7 + seed) * 0.3, cos(t * 0.8) * 1.3 + sin(t * 1.9) * 0.4);
	fade = 0.7 + 0.3 * sin(TIME * 2.1 + seed * 5.0);
	if (pool > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), vec4(o.x + off.x, 0.035, o.z + off.z, 1.0));
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, vec4(o + off, 1.0));
	}
}
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	if (pool > 0.5) {
		ALBEDO = tint.rgb;
		ALPHA = pow(max(0.0, 1.0 - d), 2.0) * 0.32 * fade;
	} else {
		// A soft glow with no hard white middle, so it never reads as a shot (version 140).
		float halo = pow(max(0.0, 1.0 - d), 2.2);
		ALBEDO = tint.rgb;
		ALPHA = clamp(halo * 0.9, 0.0, 1.0) * fade;
	}
}
"""


static func magic(pos: Vector3, color: Color, count := 18) -> void:
	_burst(pos, count, color, 1.0, 4.0, 0.6, -0.2, false, "glint")


static var _flame_mat: ShaderMaterial

## A flickering flame that always faces the camera, drawn by the graphics card (no script,
## no light): `size` is its width and height in metres, standing on `pos`.
static func flame(parent: Node3D, size: Vector2, pos := Vector3.ZERO) -> MeshInstance3D:
	if _flame_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 hot : source_color = vec4(1.0, 0.85, 0.4, 1.0);
uniform vec4 cool : source_color = vec4(1.0, 0.3, 0.04, 1.0);
varying float seed;
void vertex() {
	seed = MODEL_MATRIX[3].x * 3.7 + MODEL_MATRIX[3].z * 1.3;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float k = sin(TIME * 13.0 + seed) * 0.12 + sin(TIME * 7.3 + seed * 2.0) * 0.08;
	VERTEX.y = (VERTEX.y + 0.5) * (1.0 + k) - 0.5;
	VERTEX.x *= 1.0 - k * 0.5;
}
void fragment() {
	float t = 1.0 - UV.y;
	float x = abs(UV.x * 2.0 - 1.0);
	float w = 0.85 * (1.0 - t) * smoothstep(0.0, 0.3, t) + 0.03;
	float inside = (1.0 - smoothstep(w * 0.45, w, x)) * smoothstep(0.0, 0.12, t);
	ALBEDO = mix(hot.rgb, cool.rgb, smoothstep(0.1, 0.8, t)) * (1.2 - t * 0.5);
	ALPHA = inside;   // (v230) only the flame itself counts, so a see-through picture gets no black box
}
"""
		_flame_mat = ShaderMaterial.new()
		_flame_mat.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var f := MeshInstance3D.new()
	f.mesh = q
	f.material_override = _flame_mat
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.scale = Vector3(size.x, size.y, 1.0)
	f.position = pos + Vector3.UP * size.y * 0.5
	parent.add_child(f)
	return f
