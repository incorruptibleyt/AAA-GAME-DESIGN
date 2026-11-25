class_name StarEater
extends Enemy
## The boss of the Starfall Abyss (floor 10, then every fifth floor below it), version 268.
## Until then the last floor of the game was guarded by the Sporemother from floor 4, a
## mushroom in a starry void (hard review of build 267, fix 2).
##
## A giant skeleton that swallowed a fallen star: the star burns in its open ribs, a collar
## of night sky rises behind its skull, meteor shards crown it and three little moons circle
## its head. The Lich floats and blinks, the Colossus burns the floor; the Star Eater bends
## the room round it. Every attack has a warning:
## - Constellation: stars fall on spots in a ring round the hero, then the lines that join
##   them strike. Inside the shape is safe; the lines are not.
## - Gravity Well: the star in its chest drags the hero towards it while a circle fills round
##   it, then bursts. Walk out against the pull, or dash (a dash is never pulled).
## - Moon Sweep: moons roll out of its chest and spiral out across the room. Slip between.
## - Starfall (phase 2's own move): stars rain on the whole room, every third on the hero.
## - Black Hole (its new attack when met again, floor 15 on): a hole in the night opens past
##   the hero and pulls for a while, as a constellation falls round them.
## Below half health its star burns violet: quicker, more stars, more moons, a longer pull.

const DISPLAY_NAME := "The Star Eater"
const STAR := Color(0.8, 0.87, 1.0)
const GOLD := Color(1.0, 0.82, 0.45)
const VIOLET := Color(0.72, 0.46, 1.0)
const MOON_R := 0.62

static var _meshes := {}

var _enraged := false
var _started := false
var _busy := false
var _t := 0.0
var _star: Node3D            # the star in its ribs: pulses, swells while it pulls
var _halo: MeshInstance3D    # its glow
var _moons: Node3D           # three little moons round the skull
var _pulling := false
var _sweep: Array[Node3D] = []
var _hole: Node3D


func _setup() -> void:
	is_boss = true
	roar_sound = "roar_star"
	init_health(620.0)
	drop_chance = 0.0
	move_speed = 1.35
	contact_damage = 16.0
	radius = 1.15
	center_height = 1.9
	knockback_scale = 0.05
	var look := bones(Art.SKELETON_WARRIOR, 4.4, STAR)
	look.accent = Color(0.14, 0.15, 0.3)
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Cloak"]
	look.overlay = _night_bones()   # bones gone dark as the night sky, stars twinkling in them
	look.shape = {"scale": {"chest": 0.95, "head": 0.85, "upperarm.l": 1.5, "upperarm.r": 1.5, "upperleg.l": 1.35, "upperleg.r": 1.35}}   # (v351: towering and lanky)
	look.parts = "planet"
	make_visual(look)
	_dress()


func display_name() -> String:
	return DISPLAY_NAME


# --- How it looks ----------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	var k := "star_eater_" + key
	if not _meshes.has(k):
		match key:
			"star": _meshes[k] = U.mat(Color(0.9, 0.93, 1.0), 0.3, 1.1)
			"eye": _meshes[k] = U.unlit(Color(0.75, 0.88, 1.0))
			"gold": _meshes[k] = U.mat(Color(1.0, 0.72, 0.25), 0.3, 1.4)
			"shard": _meshes[k] = U.mat(Color(0.35, 0.5, 1.0), 0.25, 1.1)
			"moon": _meshes[k] = U.mat(Color(0.78, 0.8, 0.88), 0.65, 0.2)
			"crater": _meshes[k] = U.mat(Color(0.55, 0.57, 0.66), 0.8)
			"silver": _meshes[k] = U.mat(Color(0.7, 0.74, 0.86), 0.3, 0.4)
			"void": _meshes[k] = U.unlit(Color(0.02, 0.0, 0.05, 0.92))
	return _meshes[k]


## A segment from a to b of a cone, `ra` thick at a and `rb` at b.
static func _rod(a: Vector3, b: Vector3, ra: float, rb: float, sides := 6) -> Array:
	var d := b - a
	var c := Props._cone(rb, ra, d.length(), sides)
	var basis := Basis(Quaternion(Vector3.UP, d.normalized())) if d.normalized().cross(Vector3.UP).length() > 0.001 else Basis.IDENTITY
	return [c, Transform3D(basis, (a + b) * 0.5)]


## A five-pointed star with fat points (thin ones read as spider legs), facing +Z, white with
## a gold heart: the one in its ribs, and the ones that fall.
static func _star_mesh() -> ArrayMesh:
	if _meshes.has("star"):
		return _meshes["star"]
	var parts := []
	parts.append([Props._sphere(), Props._xf(Vector3.ZERO, Vector3(0.15, 0.15, 0.1)), _mat("star")])
	parts.append([Props._knob(), Props._xf(Vector3(0, 0, 0.06), Vector3.ONE * 0.07), _mat("gold")])
	for i in 5:
		var a := PI * 0.5 + TAU * i / 5.0
		var out := Vector3(cos(a), sin(a), 0.0)
		parts.append(_rod(out * 0.08, out * 0.36, 0.1, 0.0, 4) + [_mat("star")])
	_meshes["star"] = Props._bake(parts)
	return _meshes["star"]


## A crown of meteor shards round the top of the skull, blue and gold, the tallest in front.
static func _crown_mesh() -> ArrayMesh:
	if _meshes.has("crown"):
		return _meshes["crown"]
	var parts := []
	for i in 7:
		var a := TAU * i / 7.0 + PI * 0.5   # i = 0 at the front (+Z)
		var out := Vector3(cos(a), 0.0, sin(a))
		var tall := 0.52 if i == 0 else (0.4 if i == 1 or i == 6 else 0.3)
		var base := out * 0.3 + Vector3(0, 0.93, 0)
		var tip := base + out * 0.16 + Vector3(0, tall, 0)
		parts.append(_rod(base, tip, 0.085, 0.0, 4) + [_mat("gold" if i % 2 == 0 else "shard")])
	# A thin silver band, open on top (a solid cap read as a white dome from above).
	var band := TorusMesh.new()
	band.inner_radius = 0.29
	band.outer_radius = 0.36
	band.rings = 16
	band.ring_segments = 6
	parts.append([band, Props._xf(Vector3(0, 0.95, 0), Vector3(1, 0.7, 1)), _mat("silver")])
	_meshes["crown"] = Props._bake(parts)
	return _meshes["crown"]


## A moon with craters (one sphere's worth across, `r`).
static func _moon_mesh(r: float) -> ArrayMesh:
	var k := "moon_%.2f" % r
	if _meshes.has(k):
		return _meshes[k]
	var parts := []
	parts.append([Props._sphere(), Props._xf(Vector3.ZERO, Vector3.ONE * r), _mat("moon")])
	var spots := [Vector3(0.5, 0.6, 0.62), Vector3(-0.7, 0.2, 0.68), Vector3(0.1, -0.5, 0.86), Vector3(0.2, 0.95, -0.1), Vector3(-0.4, 0.7, -0.55)]
	for s: Vector3 in spots:
		var n := s.normalized()
		parts.append([Props._knob(), Props._xf(n * r * 0.93, Vector3.ONE * r * 0.26, Basis(Quaternion(Vector3.UP, n)) * Basis.from_scale(Vector3(1, 0.35, 1))), _mat("crater")])
	_meshes[k] = Props._bake(parts)
	return _meshes[k]


## Three little moons on a ring (they turn round the skull).
static func _little_moons() -> ArrayMesh:
	if _meshes.has("little_moons"):
		return _meshes["little_moons"]
	var parts := []
	for i in 3:
		var a := TAU * i / 3.0
		parts.append([Props._sphere(), Props._xf(Vector3(cos(a) * 0.62, 0.06 * i, sin(a) * 0.62), Vector3.ONE * 0.075), _mat("moon")])
	_meshes["little_moons"] = Props._bake(parts)
	return _meshes["little_moons"]


## A tall collar of night sky behind the skull, its edge cut into rays like a star's.
static func _collar_mesh() -> ArrayMesh:
	if _meshes.has("collar"):
		return _meshes["collar"]
	var poly := [Vector2(-0.5, -0.05)]
	for i in 13:
		var a := PI - PI * i / 12.0
		var r := 0.95 if i % 2 == 0 else 0.66
		poly.append(Vector2(cos(a) * r, sin(a) * r * 0.95 + 0.05))
	poly.append(Vector2(0.5, -0.05))
	# Lying flat its rays point along +Z; stood up they point up.
	var slab := Props._poly_slab(poly, -0.025, 0.025)
	_meshes["collar"] = slab
	return slab


## Its bones gone dark as the night sky, with stars twinkling in them and a pale blue edge,
## so it reads as made of the Abyss (drawn over the whole skeleton: dark, then the stars).
static func _night_bones() -> ShaderMaterial:
	if _meshes.has("night"):
		return _meshes["night"]
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
void fragment() {
	ALBEDO = vec3(0.4, 0.43, 0.7);
}
"""
	var stars := Shader.new()
	stars.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
varying vec3 lp;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 q = lp * 7.0;
	vec3 cell = floor(q);
	float h = hash(cell);
	float d = length(fract(q) - 0.5);
	float tw = 0.5 + 0.5 * sin(TIME * 2.6 + h * 50.0);
	float s = step(0.72, h) * smoothstep(0.2, 0.0, d) * tw;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	ALBEDO = vec3(0.05, 0.07, 0.2) + vec3(0.85, 0.9, 1.0) * s * 1.6 + vec3(0.35, 0.5, 1.0) * rim * 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = dark
	var f := ShaderMaterial.new()
	f.shader = stars
	m.next_pass = f
	_meshes["night"] = m
	return m


static func _sky_mat() -> ShaderMaterial:
	if not _meshes.has("sky"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep : source_color = vec3(0.035, 0.04, 0.14);
uniform vec3 band : source_color = vec3(0.28, 0.14, 0.5);
uniform vec3 star : source_color = vec3(0.88, 0.92, 1.0);
uniform vec3 edge : source_color = vec3(0.62, 0.7, 1.0);
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 q = lp.xz * 9.0;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = hash(cell);
	vec2 off = vec2(hash(cell + 1.3), hash(cell + 7.1)) - 0.5;
	float d = length(f - off * 0.6);
	float tw = 0.55 + 0.45 * sin(TIME * 2.2 + h * 40.0);
	float s = step(0.7, h) * smoothstep(0.16, 0.0, d) * tw;
	float r = length(lp.xz);
	float b = smoothstep(0.22, 0.0, abs(r - 0.55)) * 0.7;
	float rim = smoothstep(0.62, 0.9, r);
	ALBEDO = deep + band * b;
	ROUGHNESS = 0.9;
	EMISSION = star * s * 3.0 + band * b * 0.6 + edge * rim * 0.9;
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_meshes["sky"] = m
	return _meshes["sky"]


func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = U.soft_circle()
	m.albedo_color = col
	return m


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		var collar := MeshInstance3D.new()
		collar.mesh = _collar_mesh()
		collar.material_override = _sky_mat()
		# Stood up (its rays point up) behind the neck, leaning back a little.
		collar.transform = Transform3D(Basis(Vector3.RIGHT, -0.32) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.42, -0.26))
		chest.add_child(collar)
		_star = Node3D.new()
		_star.position = Vector3(0, 0.22, 0.46)
		# Tipped up to face the camera above the hero (facing straight ahead it showed edge-on).
		_star.rotation.x = -0.75
		_star.scale = Vector3.ONE * 1.35
		chest.add_child(_star)
		var core := MeshInstance3D.new()
		core.mesh = _star_mesh()
		_star.add_child(core)
		_halo = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		_halo.mesh = q
		_halo.material_override = _glow_mat(Color(0.5, 0.65, 1.0, 0.35))
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_star.add_child(_halo)
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		var crown := MeshInstance3D.new()
		crown.mesh = _crown_mesh()
		head.add_child(crown)
		# Two cold star-points for eyes (the night-dark skull hid the sockets).
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.065
			sm.height = 0.13
			sm.radial_segments = 8
			sm.rings = 4
			eye.mesh = sm
			eye.material_override = _mat("eye")
			eye.position = Vector3(side * 0.14, 0.42, 0.4)
			head.add_child(eye)
		_moons = Node3D.new()
		_moons.position = Vector3(0, 0.95, 0)
		head.add_child(_moons)
		var m := MeshInstance3D.new()
		m.mesh = _little_moons()
		_moons.add_child(m)


## Phase 2: the star in its ribs burns violet.
func _turn_violet() -> void:
	if _halo:
		(_halo.material_override as StandardMaterial3D).albedo_color = Color(0.75, 0.4, 1.0, 0.7)
	if _star:
		_star.create_tween().tween_property(_star, "scale", Vector3.ONE * 1.9, 0.3)


# --- How it fights ---------------------------------------------------------------------------

func _think(hero: Hero, delta: float) -> void:
	_t += delta
	if not _started:
		_started = true
		Sfx.play(roar_sound)
		Sfx.play("shimmer", 0.8, 0.7)
		Game.shake(0.5)
		_brain()
	if _moons:
		_moons.rotation.y += delta * (2.4 if _enraged else 1.4)
	if _star:
		var k := 1.35 * (1.0 + 0.08 * sin(_t * 3.0)) * (1.45 if _pulling else 1.0) * (1.15 if _enraged else 1.0)
		_star.scale = _star.scale.lerp(Vector3.ONE * k, 1.0 - exp(-6.0 * delta))
		_star.rotation.z += delta * (1.6 if _pulling else 0.35)
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.3
		Sfx.play("shimmer", 0.9, 0.55)
		phase_two(VIOLET, "starfall", "Starfall")
		_turn_violet()
	if randf() < delta * 2.5:
		Fx.magic(center() + Vector3(randf_range(-0.9, 0.9), randf_range(-0.3, 1.5), randf_range(-0.9, 0.9)), VIOLET if _enraged else STAR, 2)
	if _busy:
		return
	var to := hero.global_position - global_position
	if to.length() > 4.0:
		walk(to, delta)
	else:
		stand(delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _alive() -> bool:
	return is_instance_valid(self) and not dead and Game.state == Game.State.PLAYING


func _brain() -> void:
	await _wait(1.2)
	encore_first()
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["constellation", "well", "moons", "constellation"]
		if _enraged:
			moves.append("starfall")   # phase 2's own move
		if returning():
			moves.append("encore")     # Black Hole, when met again
		match next_move(moves):
			"constellation": await _constellation()
			"well": await _gravity_well()
			"moons": await _moon_sweep()
			"starfall": await _starfall()
			"encore": await _black_hole()
		_busy = false
		await _wait(1.0 if _enraged else 1.5)


func _room() -> Node:
	return Room.current if is_instance_valid(Room.current) else get_parent()


func _in_room(p: Vector3, r := 0.6) -> Vector3:
	p.x = clampf(p.x, -Room.HALF_W + r + 0.4, Room.HALF_W - r - 0.4)
	p.z = clampf(p.z, -Room.HALF_L + r + 0.4, Room.HALF_L - r - 0.4)
	p.y = 0.0
	return Room.current.resolve_move(p, Vector3.ZERO, r) if is_instance_valid(Room.current) else p


## A star falls from high up onto `spot`, landing in `seconds` (when its warning fills).
func _falling_star(spot: Vector3, seconds: float) -> void:
	var s := MeshInstance3D.new()
	s.mesh = _star_mesh()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_room().add_child(s)
	var from := spot + Vector3(randf_range(-2.5, 2.5), 11.0, -4.0)
	s.global_position = from
	s.scale = Vector3.ONE * 1.6
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "global_position", spot + Vector3.UP * 0.4, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "rotation:z", TAU * 1.5, seconds)
	tw.chain().tween_callback(s.queue_free)


## A star lands: a flash and a ring, and the hero is hit if under it.
static func _star_lands(spot: Vector3, r: float, dmg: float, source: String, col: Color) -> void:
	Fx.impact(spot + Vector3.UP * 0.3, col, 1.2)
	Fx.shockwave(spot, col, r)
	Fx.magic(spot + Vector3.UP * 0.4, col, 14)
	Sfx.play("boom", 0.45, 1.25)
	Game.shake(0.1)
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - spot
	d.y = 0.0
	if d.length() < r + hero.radius * 0.5:
		Game.hit_source = source
		hero.take_damage(dmg, d, 8.0)


## A line of starlight between two fallen stars, flashing as it strikes.
func _beam(a: Vector3, b: Vector3, col: Color) -> void:
	var d := b - a
	d.y = 0.0
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.08, d.length())
	m.mesh = box
	var mat := U.unlit(Color(col.r, col.g, col.b, 0.9)).duplicate() as StandardMaterial3D
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_room().add_child(m)
	m.global_position = (a + b) * 0.5 + Vector3.UP * 0.25
	m.look_at(m.global_position + d, Vector3.UP)
	var tw := m.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(m.queue_free)


## Constellation: stars fall round the hero, then the lines between them strike.
func _constellation(count := 0) -> void:
	var hero := Game.hero
	if hero == null:
		return
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	Sfx.play("shimmer", 0.7)
	var n := count if count > 0 else (6 if _enraged else 5)
	var c := hero.global_position
	var start := randf() * TAU
	var pts: Array[Vector3] = []
	for i in n:
		var a := start + TAU * i / n + randf_range(-0.2, 0.2)
		var r := randf_range(2.7, 3.5)
		pts.append(_in_room(c + Vector3(cos(a) * r, 0.0, sin(a) * r)))
	var source := kind_name()
	var col := VIOLET if _enraged else STAR
	for p in pts:
		if not _alive():
			return
		_falling_star(p, 0.9)
		track(Telegraph.circle(p, 1.0, 0.9, func(): StarEater._star_lands(p, 1.0, 14.0, source, col)))
		await _wait(0.12)
	await _wait(0.85)
	if not _alive():
		return
	Sfx.play("beam", 0.6)
	for i in n:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		var d := b - a
		d.y = 0.0
		var length := d.length()
		if length < 0.6:
			continue
		var dir := d / length
		track(Telegraph.line(a, dir, length, 0.85, 0.8, func(): _line_strikes(a, b, dir, length, source, col), 0.5 if i == 0 else 0.0))
	await _wait(1.0)


func _line_strikes(a: Vector3, b: Vector3, dir: Vector3, length: float, source: String, col: Color) -> void:
	if not _alive():
		return
	_beam(a, b, col)
	Enemy.strike_strip(a, dir, length, 0.85, 14.0, source)


## Gravity Well: the star pulls the hero in while a circle fills round it, then bursts.
func _gravity_well() -> void:
	if Game.hero == null:
		return
	var here := global_position
	var r := 3.6 if _enraged else 3.2
	var hold := 2.8 if _enraged else 2.3
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	Sfx.play(roar_sound, 0.5, 0.85)
	Sfx.play("shimmer", 0.8, 0.5)
	var source := kind_name()
	var col := VIOLET if _enraged else STAR
	track(Telegraph.circle(here, r, hold, func(): _well_burst(here, r, source, col)))
	_pulling = true
	var t := 0.0
	var mote := 0.0
	while t < hold:
		if not _alive():
			_pulling = false
			return
		var dt := get_process_delta_time()
		_pull(here, (2.5 if _enraged else 2.1), 11.0, dt)
		mote -= dt
		if mote <= 0.0:
			mote = 0.05
			_mote_in(here + Vector3.UP * center_height, r + 1.5, col)
		await frame()
		t += dt
	_pulling = false
	await _wait(0.6)


## Drags the hero towards `to` at `speed` (metres a second) from up to `reach` away. A dash
## is never pulled, and the room's walls and pillars still stop the hero.
static func _pull(to: Vector3, speed: float, reach: float, dt: float) -> void:
	var h := Game.hero
	if h == null or h.dead or h.is_dashing():
		return
	var d := to - h.global_position
	d.y = 0.0
	var dist := d.length()
	if dist < 0.5 or dist > reach:
		return
	var step := d / dist * minf(speed * dt, dist - 0.5)
	h.global_position = Room.current.resolve_move(h.global_position, step, h.radius) if is_instance_valid(Room.current) else h.global_position + step


## A spark of starlight drawn in from the edge of the well to the star.
func _mote_in(to: Vector3, from_r: float, col: Color) -> void:
	var a := randf() * TAU
	var m := MeshInstance3D.new()
	m.mesh = _star_mesh()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_room().add_child(m)
	m.global_position = Vector3(to.x + cos(a) * from_r, randf_range(0.4, 1.6), to.z + sin(a) * from_r)
	m.scale = Vector3.ONE * 0.45
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "global_position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "scale", Vector3.ONE * 0.12, 0.5)
	tw.chain().tween_callback(m.queue_free)


func _well_burst(here: Vector3, r: float, source: String, col: Color) -> void:
	Game.shake(0.45)
	Game.hit_stop(0.06)
	Sfx.play("boom", 0.9, 0.8)
	Fx.shockwave(here, col, r)
	Fx.magic(here + Vector3.UP * 1.5, col, 40)
	var hero := Game.hero
	if hero == null or not _alive():
		return
	var d := hero.global_position - here
	d.y = 0.0
	if d.length() < r + hero.radius * 0.5:
		Game.hit_source = source
		hero.take_damage(20.0, d, 14.0)


## Moon Sweep: moons rise out of its chest, then spiral out across the room.
func _moon_sweep() -> void:
	var here := global_position
	var n := 5 if _enraged else 3
	var way := 1.0 if randf() < 0.5 else -1.0
	var start := randf() * TAU
	if Game.hero:
		var to := Game.hero.global_position - here
		start = atan2(to.z, to.x) + PI / n   # the hero starts in a gap, not under a moon
	visual.attack(true)
	Sfx.play("shimmer", 0.9, 0.8)
	_clear_moons()
	for i in n:
		var m := MeshInstance3D.new()
		m.mesh = _moon_mesh(MOON_R)
		_room().add_child(m)
		m.global_position = here + Vector3.UP * center_height
		_sweep.append(m)
	var source := kind_name()
	var rise := 0.9
	var dur := 3.6 if not _enraged else 3.2
	var t := 0.0
	var hit := {}
	while t < rise + dur:
		if not _alive():
			break
		var dt := get_process_delta_time()
		t += dt
		var r: float
		var y: float
		if t < rise:
			r = lerpf(0.3, 1.9, t / rise)
			y = lerpf(center_height, 0.75, t / rise)
		else:
			r = lerpf(1.9, 8.5, (t - rise) / dur)
			y = 0.75
		var ang := start + way * maxf(0.0, t - rise) * (1.05 if _enraged else 0.85)
		var fade := clampf((rise + dur - t) / 0.4, 0.0, 1.0)
		for i in _sweep.size():
			var m := _sweep[i]
			if not is_instance_valid(m):
				continue
			var a := ang + TAU * i / n
			var p := here + Vector3(cos(a) * r, y, sin(a) * r)
			m.global_position = p
			m.rotation.y += dt * 2.0
			m.scale = Vector3.ONE * fade
			var h := Game.hero
			if t >= rise and fade > 0.5 and not hit.has(i) and h and h.can_be_hit():
				var d := h.global_position - Vector3(p.x, h.global_position.y, p.z)
				if d.length() < MOON_R + h.radius * 0.6:
					hit[i] = true
					Game.hit_source = source
					h.take_damage(16.0, d, 10.0)
					Fx.impact(p, STAR, 1.0)
		await frame()
	_clear_moons()
	await _wait(0.4)


func _clear_moons() -> void:
	for m in _sweep:
		if is_instance_valid(m):
			m.queue_free()
	_sweep.clear()


## Starfall (phase 2's own move): stars rain on the whole room, every third on the hero.
func _starfall() -> void:
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	Sfx.play(roar_sound, 0.6)
	var source := kind_name()
	for i in 12:
		if not _alive() or Game.hero == null:
			return
		var spot := Game.hero.global_position
		if i % 3 != 0:
			spot += Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
		spot = _in_room(spot)
		_falling_star(spot, 1.0)
		track(Telegraph.circle(spot, 1.3, 1.0, func(): StarEater._star_lands(spot, 1.3, 15.0, source, VIOLET)))
		await _wait(0.22)
	await _wait(1.1)


## Black Hole (its new attack when met again): a hole in the night opens past the hero and
## pulls for a while, as a constellation falls round them.
func _black_hole() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var away := hero.global_position - global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.BACK
	var spot := _in_room(hero.global_position + away * 3.5, 1.2)
	Sfx.play(roar_sound, 0.7, 0.8)
	track(Telegraph.circle(spot, 1.2, 1.0, Callable()))
	await _wait(1.0)
	if not _alive():
		return
	_open_hole(spot, 6.0)
	await _constellation(4)


func _open_hole(spot: Vector3, seconds: float) -> void:
	if is_instance_valid(_hole):
		_hole.queue_free()
	var hole := Node3D.new()
	_room().add_child(hole)
	hole.global_position = spot + Vector3.UP * 0.05
	_hole = hole
	var disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	q.orientation = PlaneMesh.FACE_Y
	disc.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = U.soft_circle()
	m.albedo_color = Color(0.02, 0.0, 0.06, 1.0)
	disc.material_override = m
	hole.add_child(disc)
	var ring := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(3.2, 3.2)
	q2.orientation = PlaneMesh.FACE_Y
	ring.mesh = q2
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_texture = U.ring()
	rm.albedo_color = VIOLET
	ring.material_override = rm
	ring.position.y = 0.02
	hole.add_child(ring)
	Sfx.play("shimmer", 0.9, 0.45)
	var source := kind_name()
	var t := 0.0
	var bite := 0.0
	var mote := 0.0
	while t < seconds and is_instance_valid(hole) and _alive():
		var dt := get_process_delta_time()
		t += dt
		ring.rotation.y += dt * 2.5
		hole.scale = Vector3.ONE * minf(1.0, t * 3.0) * clampf((seconds - t) * 2.0, 0.0, 1.0)
		StarEater._pull(spot, 1.7, 8.0, dt)
		mote -= dt
		if mote <= 0.0:
			mote = 0.08
			_mote_in(spot + Vector3.UP * 0.3, 2.6, VIOLET)
		bite -= dt
		var h := Game.hero
		if bite <= 0.0 and h and h.can_be_hit():
			var d := h.global_position - spot
			d.y = 0.0
			if d.length() < 1.0 + h.radius * 0.5:
				bite = 0.8
				Game.hit_source = source
				h.take_damage(10.0, d, 12.0)
		await frame()
	if is_instance_valid(hole):
		hole.queue_free()


func _exit_tree() -> void:
	_clear_moons()
	if is_instance_valid(_hole):
		_hole.queue_free()
	super._exit_tree()


func _on_death() -> void:
	_pulling = false
	_clear_moons()
	if is_instance_valid(_hole):
		_hole.queue_free()
	Sfx.play(roar_sound, 0.8)
	Sfx.play("shimmer", 1.0, 0.6)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	if _star:
		var tw := _star.create_tween()
		tw.tween_property(_star, "scale", Vector3.ONE * 2.6, 0.25)
		tw.tween_property(_star, "scale", Vector3.ZERO, 0.4)
	Fx.magic(center(), STAR, 60)
	Fx.shockwave(global_position, STAR, 5.5)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
