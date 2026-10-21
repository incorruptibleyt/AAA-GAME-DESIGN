class_name Fx
## One-shot particle effects built in code: hit sparks, bone bursts, dust and magic.

static var _quad: QuadMesh


static func _burst(pos: Vector3, count: int, color: Color, size: float, speed: float, life: float, gravity: float) -> void:
	var world := Game.world
	if world == null:
		return
	if _quad == null:
		_quad = QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = U.soft_circle()
		_quad.material = m

	var p := CPUParticles3D.new()
	p.mesh = _quad
	p.one_shot = true
	p.explosiveness = 1.0
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
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = color
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.position = pos
	world.add_child(p)
	p.emitting = true
	p.get_tree().create_timer(life + 0.2).timeout.connect(p.queue_free)


static func sparks(pos: Vector3, color := Color(1.0, 0.85, 0.5)) -> void:
	_burst(pos, 10, color, 0.25, 7.0, 0.35, 0.5)


static func bones(pos: Vector3) -> void:
	_burst(pos + Vector3.UP * 0.6, 22, Color(0.95, 0.92, 0.82), 0.35, 6.0, 0.8, 2.0)


static func dust(pos: Vector3, count := 14) -> void:
	_burst(pos + Vector3.UP * 0.2, count, Color(0.55, 0.5, 0.62, 0.5), 0.8, 1.6, 0.9, -0.05)


static func magic(pos: Vector3, color: Color, count := 18) -> void:
	_burst(pos, count, color, 0.35, 4.0, 0.6, -0.2)
