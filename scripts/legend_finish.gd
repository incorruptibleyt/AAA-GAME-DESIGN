class_name LegendFinish
extends RefCounted
## Version 314 (Legend Vault, legends.gd): finishers, what happens when a skeleton falls.
##   gold_rush:    Gold Rush. A jackpot: a gold shockwave rings out across the floor and a
##                 star of light flashes where the skeleton fell; a dozen fat gold coins (a
##                 raised rim, a crowned skull stamped on each face) burst up out of it,
##                 spinning, bounce once on the floor with a glint, then zip into the hero one
##                 after another, each with a chink and a sparkle (version 320: they were flat
##                 yellow dots that fell and vanished); version 335: glints flash off the
##                 coins as they spin through the air. (Only a show: the coins it really drops
##                 are the usual ones.)
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
			_gold_rush(at, world, hero)
		"soul_harvest":
			if hero and _souls < MAX_SOULS:
				_soul(at, world, hero)


# ---------------------------------------------------------------- Gold Rush

static var _jackpots := 0
const MAX_JACKPOTS := 6   # (bursts on screen at once: a Bomber's blast can fell a crowd)


static func _gold_rush(at: Vector3, world: Node3D, hero: Node3D) -> void:
	# (At most three a frame, and six at once.)
	var f := Engine.get_process_frames()
	if f != _coin_frame:
		_coin_frame = f
		_coin_bursts = 0
	_coin_bursts += 1
	if _coin_bursts > 3 or _jackpots >= MAX_JACKPOTS:
		return
	var j := Jackpot.new()
	j.hero = hero
	world.add_child(j)
	var run := world == Game.world
	j.global_position = Vector3(at.x, 0.03 if run else world.global_position.y + 0.02, at.z)
	j.from_y = 0.7 if run else (at.y - world.global_position.y) + 0.25
	if run:
		Sfx.play("coin", 0.45, randf_range(0.95, 1.15))


static var _coin_mesh: Mesh
static var _coin_mat: StandardMaterial3D
static var _coin_tex: ImageTexture


## A fat gold coin standing up (faces towards +Z and -Z), its middle at the origin: a raised
## lip round each face, and the face itself stamped with a crowned skull (coin_face).
static func coin_mesh() -> Mesh:
	if _coin_mesh:
		return _coin_mesh
	var r := 0.15
	var h := 0.03   # half its thickness at the lip
	var inner := r * 0.8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 20
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var c0 := Vector2(cos(a0), sin(a0))
		var c1 := Vector2(cos(a1), sin(a1))
		for face in [1.0, -1.0]:
			var fz: float = face
			var zf := h * 0.7 * fz   # (the face sits a little below the lip)
			var zl := h * fz
			# The face, mapped to the whole stamp picture.
			var tri := [[Vector3.ZERO, Vector2(0.5, 0.5)], [Vector3(c1.x * inner, c1.y * inner, 0), c1], [Vector3(c0.x * inner, c0.y * inner, 0), c0]]
			if fz < 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for v in tri:
				var pv: Vector3 = v[0]
				var uvp: Vector2 = v[1]
				st.set_normal(Vector3(0, 0, fz))
				st.set_uv(Vector2(0.5, 0.5) if pv == Vector3.ZERO else Vector2(0.5 + uvp.x * 0.5 * fz, 0.5 - uvp.y * 0.5))
				st.add_vertex(pv + Vector3(0, 0, zf))
			# The lip: a ring sloping up from the face to the rim's top, plain gold.
			var i0 := Vector3(c0.x * inner, c0.y * inner, zf)
			var i1 := Vector3(c1.x * inner, c1.y * inner, zf)
			var o0 := Vector3(c0.x * r, c0.y * r, zl)
			var o1 := Vector3(c1.x * r, c1.y * r, zl)
			var quad := [i0, o1, o0, i0, i1, o1] if fz > 0.0 else [i0, o0, o1, i0, o1, i1]
			for v: Vector3 in quad:
				st.set_normal((Vector3(v.x, v.y, 0).normalized() * 0.6 + Vector3(0, 0, fz)).normalized())
				st.set_uv(Vector2(0.02, 0.02))
				st.add_vertex(v)
		# The rim round the edge.
		var e0 := Vector3(c0.x, c0.y, 0)
		var e1 := Vector3(c1.x, c1.y, 0)
		var p0 := e0 * r
		var p1 := e1 * r
		var zh := Vector3(0, 0, h)
		for q in [[p0 - zh, e0], [p0 + zh, e0], [p1 + zh, e1], [p0 - zh, e0], [p1 + zh, e1], [p1 - zh, e1]]:
			st.set_normal(q[1])
			st.set_uv(Vector2(0.02, 0.02))
			st.add_vertex(q[0])
	_coin_mesh = st.commit()
	return _coin_mesh


static func coin_material() -> StandardMaterial3D:
	if _coin_mat:
		return _coin_mat
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.82, 0.3)
	m.albedo_texture = coin_face()
	m.metallic = 0.75
	m.roughness = 0.28
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.12)
	m.emission_energy_multiplier = 0.55
	m.rim_enabled = true
	m.rim = 0.5
	m.rim_tint = 0.2
	_coin_mat = m
	return m


## The coin's stamp: bright gold, with a crowned skull pressed into it in darker gold.
static func coin_face() -> ImageTexture:
	if _coin_tex:
		return _coin_tex
	var w := 64
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in w:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5) / w * 2.0 - Vector2.ONE   # (-1..1, y down)
			var v := 1.0
			# The skull: a round head, a jaw, two eye holes and a nose.
			var head := Vector2(p.x / 0.42, (p.y - 0.05) / 0.4).length()
			var jaw := Vector2(p.x / 0.26, (p.y - 0.42) / 0.16).length()
			if head < 1.0 or jaw < 1.0:
				v = 0.72
			for sx in [-1.0, 1.0]:
				if Vector2((p.x - 0.17 * sx) / 0.12, (p.y - 0.05) / 0.13).length() < 1.0:
					v = 0.42
			if Vector2(p.x / 0.06, (p.y - 0.25) / 0.07).length() < 1.0:
				v = 0.45
			# The crown on top of it: a band and three points.
			if p.y > -0.5 and p.y < -0.34 and absf(p.x) < 0.36:
				v = 0.68
			for k in 3:
				var cx := -0.26 + 0.26 * k
				if p.y <= -0.5 and p.y > -0.75 and absf(p.x - cx) < 0.09 * (p.y + 0.75) / 0.25 + 0.005:
					v = 0.68
			# A ring of dots near the edge.
			var d := p.length()
			if d > 0.82:
				v = 0.85
			img.set_pixel(x, y, Color(v, v * 0.97, v * 0.9))
	img.generate_mipmaps()
	_coin_tex = ImageTexture.create_from_image(img)
	return _coin_tex


## One Gold Rush: the shockwave and flash on the floor, and the coins.
class Jackpot extends Node3D:
	var hero: Node3D
	var from_y := 0.7
	var _t := 0.0
	var _run := false
	var _size := 1.0
	var _coins: Array[Dictionary] = []
	var _ring: MeshInstance3D
	var _ring_mat: StandardMaterial3D
	var _star: MeshInstance3D
	var _star_mat: StandardMaterial3D
	var _sparks: CPUParticles3D   # (version 335: glints flashing off the coins as they fly)

	const COUNT := 12
	const BOUNCE_UNTIL := 0.6
	const ZIP := 0.3

	func _ready() -> void:
		LegendFinish._jackpots += 1
		_run = get_parent() == Game.world
		_size = 1.35 if _run else 0.75
		_ring_mat = LegendFinish.Flare._flat(U.ring())
		_ring_mat.albedo_color = Color(1.0, 0.8, 0.3, 0.0)
		_ring = U.floor_quad(self, Vector2.ONE * 1.6, _ring_mat, Vector3(0, 0.01, 0))
		_star_mat = LegendFinish.Flare._flat(U.glint())
		_star_mat.albedo_color = Color(1.0, 0.9, 0.55, 0.0)
		_star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_star_mat.billboard_keep_scale = true
		_star = MeshInstance3D.new()
		_star.mesh = LegendPet._quad(1.0)
		_star.material_override = _star_mat
		_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_star.position = Vector3(0, from_y, 0)
		add_child(_star)
		# Glints that flash off the coins as they spin through the air: one emitter, moved from
		# coin to coin each frame, its sparks left hanging where they caught the light.
		_sparks = CPUParticles3D.new()
		_sparks.mesh = Fx._shaped("glint")
		_sparks.amount = 36
		_sparks.lifetime = 0.4
		_sparks.local_coords = false
		_sparks.direction = Vector3.UP
		_sparks.spread = 180.0
		_sparks.gravity = Vector3.ZERO
		_sparks.initial_velocity_min = 0.0
		_sparks.initial_velocity_max = 0.3
		_sparks.scale_amount_min = 0.5 * _size
		_sparks.scale_amount_max = 0.85 * _size
		var sc := Curve.new()
		sc.add_point(Vector2(0.0, 0.2))
		sc.add_point(Vector2(0.3, 1.0))
		sc.add_point(Vector2(1.0, 0.0))
		_sparks.scale_amount_curve = sc
		var sg := Gradient.new()
		sg.set_color(0, Color(1.0, 1.0, 0.92, 1.0))
		sg.set_color(1, Color(1.0, 0.8, 0.3, 0.0))
		_sparks.color_ramp = sg
		_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_sparks)
		_sparks.position = Vector3(0, from_y, 0)
		for i in COUNT:
			var c := MeshInstance3D.new()
			c.mesh = LegendFinish.coin_mesh()
			c.material_override = LegendFinish.coin_material()
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.top_level = true
			add_child(c)
			var ang := TAU * (float(i) + randf() * 0.6) / COUNT
			var out := randf_range(1.2, 2.4) * _size
			var up := randf_range(4.2, 6.0) * (_size if _run else 0.8)
			_coins.append({"node": c, "pos": Vector3(0, from_y, 0), "vel": Vector3(cos(ang) * out, up, sin(ang) * out),
				"spin": randf_range(10.0, 16.0) * (1.0 if randf() < 0.5 else -1.0), "yaw": randf() * TAU,
				"bounced": false, "zip_at": BOUNCE_UNTIL + i * 0.035, "home": false})

	func _exit_tree() -> void:
		LegendFinish._jackpots -= 1

	func _process(delta: float) -> void:
		_t += delta
		# The shockwave and the flash.
		var open := 1.0 - pow(1.0 - minf(1.0, _t / 0.3), 3.0)
		_ring.scale = Vector3.ONE * _size * (0.3 + 1.4 * open)
		_ring_mat.albedo_color.a = 0.95 * (1.0 - smoothstep(0.1, 0.45, _t))
		var flash := 1.0 - smoothstep(0.0, 0.3, _t)
		_star.scale = Vector3.ONE * _size * (0.6 + 1.6 * minf(1.0, _t / 0.08)) * (0.4 + 0.6 * flash)
		_star.rotation.z = _t * 3.0
		_star_mat.albedo_color.a = flash
		var g := -16.0 * (_size if _run else 0.8)
		var done := true
		var goal := Vector3.ZERO
		var have_hero := hero != null and is_instance_valid(hero)
		if have_hero:
			goal = hero.global_position + Vector3(0, (1.0 if _run else 0.7), 0)
		for c: Dictionary in _coins:
			if c.home:
				continue
			done = false
			var node: MeshInstance3D = c.node
			var p: Vector3 = c.pos
			if _t < c.zip_at or not have_hero:
				# Burst out and up, spinning; bounce once on the floor, then sit and wobble.
				var v: Vector3 = c.vel
				v.y += g * delta
				p += v * delta
				if p.y < 0.12 * _size:
					p.y = 0.12 * _size
					if not c.bounced:
						c.bounced = true
						v = Vector3(v.x * 0.35, absf(v.y) * 0.35, v.z * 0.35)
					else:
						v = Vector3(v.x * 0.8, 0.0, v.z * 0.8)
				c.vel = v
				c.pos = p
				c.yaw += c.spin * delta
				node.global_position = global_position + p
				node.global_basis = (Basis(Vector3.UP, c.yaw) * Basis(Vector3.RIGHT, -0.55)).scaled(Vector3.ONE * _size)   # (tipped back: the camera above sees its face)
				if _t > 1.6:
					c.home = true
					node.visible = false
			else:
				# Zip into the hero, faster and faster, shrinking as it arrives.
				if not c.has("zip_from"):
					c.zip_from = global_position + p
				var k := minf(1.0, (_t - c.zip_at) / ZIP)
				var from: Vector3 = c.zip_from
				var at := from.lerp(goal, k * k) + Vector3.UP * sin(k * PI) * 0.9 * _size
				node.global_position = at
				c.yaw += c.spin * 1.6 * delta
				node.global_basis = (Basis(Vector3.UP, c.yaw) * Basis(Vector3.RIGHT, -0.55)).scaled(Vector3.ONE * _size * (1.0 - 0.5 * k * k))
				if k >= 1.0:
					c.home = true
					node.visible = false
					if _run:
						Fx._burst(goal, 3, Color(1.0, 0.88, 0.4), 0.3, 2.0, 0.25, 0.0, true, "glint")
						Sfx.play("coin", 0.18, randf_range(1.2, 1.6))
		# The glints: on a coin still in the air, picked afresh each frame.
		var flying: Array[Node3D] = []
		for c: Dictionary in _coins:
			if not c.home and (c.node as Node3D).visible:
				flying.append(c.node)
		_sparks.emitting = _t < 1.25 and not flying.is_empty()
		if _sparks.emitting:
			_sparks.global_position = flying[randi() % flying.size()].global_position
		if done and _t > 0.5:
			queue_free()


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
	// (added light writes its own alpha: over a see-through pedestal picture an
	// unwritten alpha of 1 drew a black box wherever the quad lay)
	float glow_a = max(max(ALBEDO.r, ALBEDO.g), ALBEDO.b);
	ALBEDO /= max(glow_a, 0.001);
	ALPHA = clamp(glow_a, 0.0, 1.0);
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

## The finisher shown over and over beside the hero on a pedestal.
## Version 397 (visual review of 388, fix 7): on a real skeleton. It stands beside the hero,
## is struck and falls, the finisher bursts out of it (coins for Gold Rush, its ghost for
## Soul Harvest), and it sinks into the floor and climbs out again for the next round. It
## was a small bobbing skull, and the two finishers' pictures looked alike.
class Show extends Node3D:
	var kind := ""
	var _t := 1.0
	var _skull: Node3D   # (where the finisher bursts: the skeleton's feet)
	var _foe: CharacterVisual
	var _hero: Node3D
	const CYCLE := 3.0
	const AT := Vector3(-1.3, 0.0, 0.4)
	const FALL := 1.45

	func _ready() -> void:
		_hero = get_parent() as Node3D
		_skull = Node3D.new()
		add_child(_skull)
		_skull.position = AT + Vector3(0, 0.3, 0)
		_foe = CharacterVisual.new()
		add_child(_foe)
		_foe.build(Enemy.bones(Art.SKELETON_MINION, 2.0, Color(1.0, 0.75, 0.3) if kind == "gold_rush" else Color(0.5, 0.9, 1.0)))
		_foe.position = AT
		_foe.basis = Basis(Vector3.UP, -0.7)   # (half towards the hero, half towards the camera)

	func _process(delta: float) -> void:
		_t += delta
		var k := fmod(_t, CYCLE)
		var was := k - delta
		if was < 0.75 and k >= 0.75:
			_foe.hit()
		if was < 0.95 and k >= 0.95:
			LegendFinish.play(kind, _skull.global_position - Vector3(0, 0.3, 0), get_parent().get_parent() as Node3D, _hero)
		# It falls on its back where it stood while the finisher plays, crumbles away, and
		# a new one pops up. (Its own death throws it a metre back, out of the picture.)
		var flat := smoothstep(0.95, 1.12, k) * (0.0 if k >= 2.35 else 1.0)
		# (on its side, away from the hero, its skull and ribs to the camera; on its back
		# only the soles of its feet showed)
		_foe.basis = Basis(Vector3(0, 0, 1), FALL * flat) * Basis(Vector3.UP, -0.7)
		var size := 1.0 - smoothstep(2.0, 2.3, k)
		if k >= 2.35:
			var up := smoothstep(2.42, 2.7, k)
			size = up * (1.0 + 0.18 * sin(up * PI))   # (pops in a little too big, then settles)
		_foe.scale = Vector3.ONE * maxf(size, 0.001)
		_foe.visible = size > 0.02
