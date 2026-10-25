class_name Fx
## One-shot particle effects built in code: hit sparks, bone bursts, dust and magic.

static var _quad: QuadMesh


static func _burst(pos: Vector3, count: int, color: Color, size: float, speed: float, life: float, gravity: float) -> void:
	var world := Game.world
	if world == null:
		return
	_burst_material()

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


static func _burst_material() -> void:
	if _quad != null:
		return
	_quad = QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = U.soft_circle()
	_quad.material = m


static func sparks(pos: Vector3, color := Color(1.0, 0.85, 0.5)) -> void:
	_burst(pos, 10, color, 0.25, 7.0, 0.35, 0.5)


static func bones(pos: Vector3) -> void:
	_burst(pos + Vector3.UP * 0.6, 22, Color(0.95, 0.92, 0.82), 0.35, 6.0, 0.8, 2.0)


static func dust(pos: Vector3, count := 14) -> void:
	_burst(pos + Vector3.UP * 0.2, count, Color(0.55, 0.5, 0.62, 0.5), 0.8, 1.6, 0.9, -0.05)


## A glowing after-image left behind by the dash.
static func trail(pos: Vector3, color: Color) -> void:
	_burst(pos, 6, color, 0.7, 0.6, 0.35, 0.0)


## A ring of light that rushes outwards (the finishing blow of a room).
static func shockwave(pos: Vector3, color: Color, radius := 6.0) -> void:
	var world := Game.world
	if world == null:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var m := U.unlit(color)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
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
	_burst_material()
	var p := CPUParticles3D.new()
	p.mesh = _quad
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.direction = Vector3.DOWN if fall else Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0.12, -0.15, 0.05) if fall else Vector3(0.05, 0.02, 0)
	p.scale_amount_min = 0.04 * size
	p.scale_amount_max = 0.11 * size
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


static func magic(pos: Vector3, color: Color, count := 18) -> void:
	_burst(pos, count, color, 0.35, 4.0, 0.6, -0.2)


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
	ALBEDO = mix(hot.rgb, cool.rgb, smoothstep(0.1, 0.8, t)) * inside * (1.2 - t * 0.5);
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
