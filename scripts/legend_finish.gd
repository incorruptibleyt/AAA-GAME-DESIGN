class_name LegendFinish
extends RefCounted
## Version 314 (Legend Vault, legends.gd): finishers, what happens when a skeleton falls.
##   gold_rush:    Gold Rush. The skeleton bursts into a fountain of gold coins that spin up
##                 out of it and rain down around it, with a glint and a chink. (Only a show:
##                 the coins it really drops are the usual ones.)
##   soul_harvest: Soul Harvest. A rune ring flares on the floor where the skeleton fell and a
##                 pillar of pale light stands up out of it; the skeleton's ghost is torn out of
##                 the bones, wailing (a real ghost: a round head, big eyes, an open mouth,
##                 little arms and a tail that whips), turns towards the hero, then streaks into
##                 them along a ribbon of light, and a ring of blue fire flares at their feet
##                 (version 318: it was a faint glow with dots for eyes).
## Game.on_enemy_died calls `play` for the finisher the hero wears (Hero.finisher). On a
## pedestal a Show plays it over and over beside the hero, on a little skull that pops.

const MAX_SOULS := 10   # ghosts in the air at once (a crowd falling at once sends the first ten)
static var _souls := 0
static var _coin_frame := -1
static var _coin_bursts := 0


static func play(kind: String, at: Vector3, world: Node3D, hero: Node3D) -> void:
	if world == null:
		return
	match kind:
		"gold_rush":
			_gold_rush(at, world)
		"soul_harvest":
			if hero and _souls < MAX_SOULS:
				_soul(at, world, hero)


# ---------------------------------------------------------------- Gold Rush

static var _coin_pool: Array = []


static func _gold_rush(at: Vector3, world: Node3D) -> void:
	# (At most three fountains a frame: a Bomber's blast can fell a whole crowd at once.)
	var f := Engine.get_process_frames()
	if f != _coin_frame:
		_coin_frame = f
		_coin_bursts = 0
	_coin_bursts += 1
	if _coin_bursts > 3:
		return
	var p: CPUParticles3D = null
	while not _coin_pool.is_empty():
		var old: Variant = _coin_pool.pop_back()
		if is_instance_valid(old) and (old as Node).get_parent() == world:
			p = old
			break
	if p == null:
		p = _coin_fountain()
		world.add_child(p)
		p.finished.connect(func():
			if is_instance_valid(p) and _coin_pool.size() < 12:
				_coin_pool.append(p)
			elif is_instance_valid(p):
				p.queue_free())
	var run := world == Game.world
	# In a run, a tall fountain the camera far above can see; on a pedestal, a small one beside
	# the hero.
	p.initial_velocity_min = 4.2 if run else 2.6
	p.initial_velocity_max = 6.5 if run else 3.6
	p.gravity = Vector3(0, -13.0 if run else -9.0, 0)
	p.scale_amount_min = 1.1 if run else 0.9
	p.scale_amount_max = 1.5 if run else 1.15
	p.global_position = at + Vector3(0, 0.6 if run else 0.25, 0)
	p.restart()
	if run:   # (not on a pedestal: Fx bursts belong to the run's world)
		Fx._burst(at + Vector3(0, 0.8, 0), 10, Color(1.0, 0.85, 0.35), 0.5, 3.0, 0.5, 0.0, true, "glint")
		Sfx.play("coin", 0.35, randf_range(0.95, 1.25))


static var _coin_mesh: Mesh


## A fountain of gold coins that spring up out of the skeleton and rain down around it, each
## one standing on its edge and spinning, so it flashes face on and edge on as it flies.
static func _coin_fountain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 16
	p.lifetime = 1.15
	p.explosiveness = 0.8
	p.direction = Vector3.UP
	p.spread = 26.0
	p.particle_flag_rotate_y = true
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	if _coin_mesh == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.78, 0.25)
		m.metallic = 0.6
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = Color(1.0, 0.62, 0.12)
		m.emission_energy_multiplier = 1.1
		_coin_mesh = _coin_disc(0.13, 0.035, m)
	p.mesh = _coin_mesh
	return p


## A coin standing up: a disc facing +Z and -Z with a rim, its middle at the origin.
static func _coin_disc(r: float, thick: float, m: Material) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var h := thick * 0.5
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0) * r, sin(a0) * r, 0)
		var p1 := Vector3(cos(a1) * r, sin(a1) * r, 0)
		for face in [1.0, -1.0]:
			var z := Vector3(0, 0, h * face)
			var tri := [z, p1 + z, p0 + z] if face > 0.0 else [z, p0 + z, p1 + z]   # (front faces turn clockwise)
			for v: Vector3 in tri:
				st.set_normal(Vector3(0, 0, face))
				st.add_vertex(v)
		var e0 := Vector3(cos(a0), sin(a0), 0)
		var e1 := Vector3(cos(a1), sin(a1), 0)
		var zf := Vector3(0, 0, h)
		for q in [[p0 - zf, e0], [p0 + zf, e0], [p1 + zf, e1], [p0 - zf, e0], [p1 + zf, e1], [p1 - zf, e1]]:
			st.set_normal(q[1])
			st.add_vertex(q[0])
	var mesh := st.commit()
	mesh.surface_set_material(0, m)
	return mesh


# ---------------------------------------------------------------- Soul Harvest

static func _soul(at: Vector3, world: Node3D, hero: Node3D) -> void:
	var run := world == Game.world
	var big := 1.6 if run else 1.0
	var mark := Flare.new()
	mark.size = big
	world.add_child(mark)
	mark.global_position = Vector3(at.x, (0.03 if run else world.global_position.y + 0.02), at.z)
	var s := Soul.new()
	s.target = hero
	world.add_child(s)
	s.global_position = at + Vector3(0, 0.45 if run else 0.2, 0)


const SOUL_TINT := Color(0.55, 0.9, 1.0)

static var _ghost_mesh: Mesh
static var _ghost_shader: Shader


## The ghost's body, turned on a lathe round Y: a round head on top (y 0), the body below it,
## then a tail tapering to a point at y -0.8. UV.y runs 0 at the top to 1 at the tail's tip.
static func ghost_mesh() -> Mesh:
	if _ghost_mesh:
		return _ghost_mesh
	var rows := 16
	var segs := 18
	var prof: Array[Vector2] = []   # (radius, y) from the top down
	for i in rows + 1:
		var k := float(i) / rows
		var y := -0.8 * k
		var r := 0.0
		if y > -0.24:
			r = sqrt(maxf(0.0, 0.24 * 0.24 - pow(y + 0.24, 2.0)))
		elif y > -0.42:
			r = lerpf(0.24, 0.21, (-0.24 - y) / 0.18)
		else:
			r = 0.21 * pow(1.0 - (-0.42 - y) / 0.38, 1.3)
		prof.append(Vector2(r, y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows:
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			var q := [[i, a0], [i, a1], [i + 1, a1], [i, a0], [i + 1, a1], [i + 1, a0]]
			for c in q:
				var pr: Vector2 = prof[c[0]]
				var ang: float = c[1]
				var v := Vector3(sin(ang) * pr.x, pr.y, cos(ang) * pr.x)
				var nrm := Vector3(sin(ang), 0.0, cos(ang))
				if pr.y > -0.24:
					nrm = (v - Vector3(0, -0.24, 0)).normalized()
				st.set_normal(nrm)
				st.set_uv(Vector2(ang / TAU, float(c[0]) / rows))
				st.add_vertex(v)
	_ghost_mesh = st.commit()
	return _ghost_mesh


static func ghost_material() -> ShaderMaterial:
	if _ghost_shader == null:
		_ghost_shader = Shader.new()
		_ghost_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float alpha = 1.0;
uniform vec3 tint = vec3(0.55, 0.9, 1.0);
uniform float whip = 1.0;
void vertex() {
	float k = UV.y;
	float w = k * k;
	VERTEX.x += sin(TIME * 9.0 - k * 6.0) * 0.13 * w * whip;
	VERTEX.z += cos(TIME * 7.0 - k * 5.0) * 0.06 * w * whip;
}
void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float body = 0.32 + 0.75 * fres;
	float tail = 1.0 - smoothstep(0.55, 1.0, UV.y);
	ALBEDO = tint * body * (0.45 + 0.55 * tail) * alpha;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _ghost_shader
	return m


## A ghost: the glowing body, and a face on its front (+Z): big dark eyes with bright pupils,
## an open wailing mouth, and two little arms raised. Used by the Soul and the card picture.
static func ghost(parent: Node3D, mat: ShaderMaterial) -> Node3D:
	var g := Node3D.new()
	parent.add_child(g)
	var body := MeshInstance3D.new()
	body.mesh = ghost_mesh()
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(body)
	var dark := LegendPet._mat("soul_eye", Color(0.03, 0.07, 0.16), 0.5)
	var lit := LegendPet._mat("soul_pupil", Color(0.75, 0.97, 1.0), 0.5, Color(0.6, 0.95, 1.0), 3.0)
	for side in [-1.0, 1.0]:
		var e := U.sphere(g, 0.07, dark, Vector3(0.085 * side, -0.1, 0.19))
		e.scale = Vector3(0.85, 1.25, 0.45)
		var pu := U.sphere(g, 0.025, lit, Vector3(0.08 * side + 0.012, -0.08, 0.215))
		pu.scale = Vector3(1.0, 1.0, 0.5)
		# The little arms, raised as it wails.
		var arm := U.sphere(g, 0.075, LegendPet._mat("soul_arm", Color(0.5, 0.85, 1.0), 0.5, Color(0.45, 0.85, 1.0), 1.6), Vector3(0.25 * side, -0.3, 0.04))
		arm.scale = Vector3(0.75, 1.3, 0.75)
		arm.rotation.z = -0.6 * side
	var mouth := U.sphere(g, 0.05, dark, Vector3(0, -0.24, 0.195))
	mouth.scale = Vector3(0.8, 1.15, 0.45)
	return g


## The ghost torn out of a fallen skeleton: it rises, wailing and swaying, turns towards the
## hero (a beat's pause), then streaks into them along a ribbon of light.
class Soul extends Node3D:
	var target: Node3D
	var _t := 0.0
	var _from := Vector3.ZERO
	var _mat: ShaderMaterial
	var _ghost: Node3D
	var _ribbon: MeshInstance3D
	var _im: ImmediateMesh
	var _trail: Array[Vector3] = []
	var _size := 1.0
	var _run := false

	const RISE := 0.55
	const TURN := 0.15
	const FLY := 0.4

	func _ready() -> void:
		LegendFinish._souls += 1
		_run = get_parent() == Game.world
		_size = 1.8 if _run else 0.9   # (seen from far above in a run)
		_mat = LegendFinish.ghost_material()
		_ghost = LegendFinish.ghost(self, _mat)
		_ghost.scale = Vector3.ONE * 0.01
		_im = ImmediateMesh.new()
		_ribbon = MeshInstance3D.new()
		_ribbon.mesh = _im
		_ribbon.top_level = true
		_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		rm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		rm.vertex_color_use_as_albedo = true
		_ribbon.material_override = rm
		add_child(_ribbon)

	func _exit_tree() -> void:
		LegendFinish._souls -= 1

	func _process(delta: float) -> void:
		_t += delta
		var pop := 1.0
		if _t < RISE:
			# Torn out of the bones: it springs up to full size (overshooting a little) and
			# rises, swaying.
			pop = 1.0 + 0.25 * sin(minf(_t / 0.22, 1.0) * PI) if _t < 0.22 else 1.0
			pop *= smoothstep(0.0, 0.12, _t)
			position += Vector3(sin(_t * 12.0) * 0.5 * delta, 2.2 * delta * (1.0 - _t / RISE), 0) * _size
			_from = global_position
		elif _t < RISE + TURN:
			# A beat in the air, squashing down before it shoots off.
			var k := (_t - RISE) / TURN
			pop = 1.0 - 0.15 * sin(k * PI)
			_from = global_position
		else:
			if target == null or not is_instance_valid(target):
				queue_free()
				return
			var goal := target.global_position + Vector3(0, 1.0 if _run else 0.75, 0)
			var k := minf(1.0, (_t - RISE - TURN) / FLY)
			var arc := Vector3.UP * sin(k * PI) * 0.6 * _size
			global_position = _from.lerp(goal, k * k) + arc
			pop = 1.0 - 0.35 * k * k
			if k >= 1.0:
				_arrive(goal)
				return
		var cam := get_viewport().get_camera_3d()
		var face := Vector3(0, 0, 1)
		if cam:
			face = (cam.global_position - global_position).normalized()
		_ghost.look_at(_ghost.global_position - face, Vector3.UP)
		_ghost.scale = Vector3.ONE * _size * pop   # (after look_at, which resets it)
		_mat.set_shader_parameter("alpha", minf(1.0, _t * 8.0))
		_mat.set_shader_parameter("whip", 1.0 + (1.5 if _t > RISE + TURN else 0.0))
		_trail.push_front(global_position + Vector3(0, -0.25 * _size, 0))
		if _trail.size() > 14:
			_trail.pop_back()
		_draw_ribbon(face)

	## The ribbon of light behind it: a strip through its last places, facing the camera,
	## widest at the ghost and fading to nothing.
	func _draw_ribbon(face: Vector3) -> void:
		_im.clear_surfaces()
		if _trail.size() < 3:
			return
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var n := _trail.size()
		for i in n:
			var p: Vector3 = _trail[i]
			var nxt: Vector3 = _trail[mini(i + 1, n - 1)]
			var prv: Vector3 = _trail[maxi(i - 1, 0)]
			var dir := prv - nxt
			if dir.length() < 0.0001:
				dir = Vector3.UP
			var side := face.cross(dir.normalized()).normalized() * 0.2 * _size * (1.0 - float(i) / n)
			var c := Color(LegendFinish.SOUL_TINT, 0.75 * (1.0 - float(i) / n))
			_im.surface_set_color(c)
			_im.surface_add_vertex(p - side)
			_im.surface_set_color(c)
			_im.surface_add_vertex(p + side)
		_im.surface_end()

	func _arrive(at: Vector3) -> void:
		var ring := Flare.new()
		ring.size = _size
		ring.burst_only = true
		get_parent().add_child(ring)
		var feet := target.global_position
		ring.global_position = Vector3(feet.x, (0.03 if _run else feet.y + 0.02), feet.z)
		if _run:
			Fx.magic(at, Color(0.6, 0.9, 1.0), 12)
		queue_free()


## On the floor: a rune ring that flares open and fades, and (unless `burst_only`) a pillar of
## pale light standing up out of it for a moment.
class Flare extends Node3D:
	var size := 1.0
	var burst_only := false
	var _t := 0.0
	var _ring: MeshInstance3D
	var _ring_mat: StandardMaterial3D
	var _inner: MeshInstance3D
	var _pillar: MeshInstance3D
	var _pillar_mat: StandardMaterial3D

	func _ready() -> void:
		_ring_mat = _flat(U.ring())
		_ring = U.floor_quad(self, Vector2.ONE * 1.4, _ring_mat)
		_inner = U.floor_quad(self, Vector2.ONE * 0.8, _ring_mat, Vector3(0, 0.005, 0))
		if not burst_only:
			_pillar_mat = _flat(U.soft_circle())
			_pillar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			_pillar_mat.billboard_keep_scale = true
			_pillar = MeshInstance3D.new()
			_pillar.mesh = LegendPet._quad(1.0)
			_pillar.material_override = _pillar_mat
			_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_pillar)

	static func _flat(tex: Texture2D) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.albedo_texture = tex
		m.albedo_color = Color(LegendFinish.SOUL_TINT, 0.0)
		return m

	func _process(delta: float) -> void:
		_t += delta
		var life := 0.7
		if _t >= life:
			queue_free()
			return
		var k := _t / life
		var open := 1.0 - pow(1.0 - minf(1.0, _t / 0.25), 3.0)
		_ring.scale = Vector3.ONE * size * (0.35 + 0.85 * open)
		_ring.rotation.y = _t * 2.5
		_inner.scale = Vector3.ONE * size * (0.3 + 0.5 * open)
		_inner.rotation.y = -_t * 4.0
		_ring_mat.albedo_color.a = 0.95 * (1.0 - smoothstep(0.35, 1.0, k))
		if _pillar:
			_pillar.position.y = 1.0 * size * open
			_pillar.scale = Vector3(0.55 * size * (1.0 - k * 0.6), 2.2 * size * open, 1.0)
			_pillar_mat.albedo_color.a = 0.7 * (1.0 - smoothstep(0.2, 0.8, k))


# ---------------------------------------------------------------- on a pedestal

## The finisher shown over and over beside the hero on a pedestal: a skull pops, then the
## finisher plays on it.
class Show extends Node3D:
	var kind := ""
	var _t := 1.0
	var _skull: Node3D
	var _hero: Node3D

	func _ready() -> void:
		_hero = get_parent() as Node3D
		_skull = Node3D.new()
		add_child(_skull)
		var bone := LegendPet._mat("show_skull", Color(0.92, 0.9, 0.82), 0.7)
		var dark := LegendPet._mat("show_eye", Color(0.1, 0.06, 0.08), 0.7)
		var head := U.sphere(_skull, 0.2, bone, Vector3.ZERO)
		head.scale = Vector3(1.0, 0.95, 1.05)
		U.box(_skull, Vector3(0.2, 0.1, 0.12), bone, Vector3(0, -0.15, -0.08))
		for side in [-1.0, 1.0]:
			U.sphere(_skull, 0.055, dark, Vector3(0.075 * side, 0.0, -0.17))
		_skull.position = Vector3(-0.95, 0.25, -0.35)

	func _process(delta: float) -> void:
		_t += delta
		var cycle := 2.2
		var k := fmod(_t, cycle)
		# The skull bobs, then shrinks to nothing as the finisher bursts out of it.
		_skull.scale = Vector3.ONE * (1.0 if k < 0.9 else maxf(0.0, 1.0 - (k - 0.9) * 8.0)) if k < 1.4 else Vector3.ONE * smoothstep(1.4, 2.2, k)
		_skull.position.y = 0.25 + sin(_t * 3.0) * 0.04
		if k - delta < 0.95 and k >= 0.95:
			LegendFinish.play(kind, _skull.global_position - Vector3(0, 0.3, 0), get_parent().get_parent() as Node3D, _hero)
