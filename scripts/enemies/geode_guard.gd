class_name GeodeGuard
extends Enemy
## The Amethyst Mine's own skeleton (floor 7, version 272; hard review of build 267, fix 3).
## Until then the Mine borrowed the Drowned Vault's Drowned Skeletons and the Glowcap
## Grotto's Rootbinders.
##
## A big miner skeleton, its bones dusted with rock and flecked with amethyst, a miner's
## helmet with a lamp on its skull and a pick in its hand. On its arm it carries half a great
## geode, the crystals inside turned outwards: shots that hit it from the front clink off
## (Projectile and the Knight's sword ask blocks_shot). It turns slowly, and its lamp lights
## the floor the way it faces, so walk round it and hit its side or back. Up close it raises
## its pick and slams it down: crystals burst out of the floor along a strip in front of it.
## Then the pick sticks in the floor and the geode swings aside for a moment: it is open
## from every side and takes more from every hit.

enum Mode { APPROACH, WINDUP, STUCK }

const AMETHYST := Color(0.72, 0.42, 1.0)
const LAMP := Color(1.0, 0.8, 0.45)
## How slowly it turns (Actor.face sharpness): circling it gets you to its side.
const TURN := 1.2
## Shots travelling at it within this cosine of straight on hit the geode (about 55 degrees
## either side of its front).
const GUARD_COS := 0.57
const WINDUP := 0.85
const STUCK_TIME := 1.5
const SLAM_LEN := 3.6
const SLAM_WIDTH := 1.4
const OPEN_DAMAGE := 1.3

static var _meshes := {}

var mode := Mode.APPROACH
var _timer := randf_range(1.0, 2.0)
var _left := 0.0
var _geode: Node3D
var _cone: MeshInstance3D
var _open := 0.0          # 0 = geode in front, 1 = swung aside
var _blocks := 0


func _setup() -> void:
	die_sound = "die_geode"
	init_health(52.0)
	move_speed = 1.7
	contact_damage = 10.0
	radius = 0.6
	center_height = 1.1
	knockback_scale = 0.4
	var look := bones(Art.SKELETON_WARRIOR, 2.3, AMETHYST)
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Cloak"]
	look.overlay = _dusty_bones()
	look.attack_anim = "2H_Melee_Attack_Chop"
	# Version 343 (visual review fix 7): a stocky miner, broad and short-legged, with
	# amethyst growing out of its back and shoulders.
	look.height = 2.45
	look.shape = {"scale": {"chest": 1.25, "head": 0.86, "upperarm.l": 1.15, "upperarm.r": 1.15, "upperleg.l": 0.72, "upperleg.r": 0.72},
		"turn": {"spine": Vector3(8, 0, 0)}}
	look.parts = "geode"
	make_visual(look)
	_dress()


func display_name() -> String:
	return "Geode Guard"


# --- How it looks ----------------------------------------------------------------------------

## Bones dusted grey with rock, flecked with glinting amethyst. One see-through pass (see
## HushKeeper._script_bones for why).
static func _dusty_bones() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_back;
varying vec3 lp;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 q = lp * 11.0;
	float h = hash(floor(q));
	float d = length(fract(q) - 0.5);
	float fleck = step(0.8, h) * (1.0 - smoothstep(0.12, 0.22, d)) * (0.7 + 0.3 * sin(TIME * 2.0 + h * 40.0));
	float dust = 0.3 + 0.15 * hash(floor(lp * 30.0));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	ALBEDO = mix(vec3(0.42, 0.4, 0.44), vec3(0.85, 0.55, 1.0) * 1.4, clamp(fleck + rim * 0.6, 0.0, 1.0));
	ALPHA = clamp(dust + fleck + rim * 0.35, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_meshes["overlay"] = m
	return m


static func _mat(key: String) -> Material:
	var k := "mat_" + key
	if not _meshes.has(k):
		match key:
			"shell": _meshes[k] = U.mat(Color(0.3, 0.28, 0.32), 0.95)
			"shell_dark": _meshes[k] = U.mat(Color(0.17, 0.15, 0.19), 0.95)
			"band": _meshes[k] = U.mat(Color(0.82, 0.8, 0.86), 0.7)
			"crystal": _meshes[k] = U.mat(Color(0.62, 0.3, 0.98), 0.2, 1.35)
			"crystal_pale": _meshes[k] = U.mat(Color(0.85, 0.66, 1.0), 0.2, 0.9)
			"helmet": _meshes[k] = U.mat(Color(0.5, 0.38, 0.17), 0.45)
			"lamp": _meshes[k] = U.mat(LAMP, 0.4, 3.0)
			"wood": _meshes[k] = U.mat(Color(0.3, 0.19, 0.1), 0.85)
			"iron": _meshes[k] = U.mat(Color(0.2, 0.2, 0.23), 0.4)
			"cone":
				# A wedge of lamplight on the floor, widening away from it.
				var sh := Shader.new()
				sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float d = 1.6 - lp.y;
	float hw = 0.2 + d * 0.32;
	float a = (1.0 - smoothstep(hw * 0.55, hw, abs(lp.x))) * (1.0 - smoothstep(2.2, 3.2, d)) * smoothstep(0.0, 0.5, d);
	ALBEDO = vec3(1.0, 0.78, 0.45) * a * 0.32;
}
"""
				var m := ShaderMaterial.new()
				m.shader = sh
				_meshes[k] = m
	return _meshes[k]


## Half a great geode, its cut face turned to -Z (the way it faces): a rough shell of rock
## with a pale band of agate inside its rim, and amethyst crystals packed in the hollow,
## pointing out.
static func _geode_mesh() -> ArrayMesh:
	if _meshes.has("geode"):
		return _meshes["geode"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	var parts := []
	var sp := Props._sphere()
	# The shell: a squashed ball, its back half (it hides the rest behind the crystals).
	parts.append([sp, Props._xf(Vector3(0, 0, 0.1), Vector3(0.5, 0.5, 0.26)), _mat("shell")])
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		parts.append([sp, Props._xf(Vector3(cos(a) * 0.36, sin(a) * 0.36, 0.08), Vector3(0.16, 0.16, 0.12)), _mat("shell_dark" if i % 2 == 0 else "shell")])
	# The agate band round the rim.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.38
	ring.outer_radius = 0.47
	ring.rings = 18
	ring.ring_segments = 6
	parts.append([ring, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.08)), _mat("band")])
	# The crystals: a big one in the middle and rings of smaller ones, all pointing out (-Z)
	# and a little away from the middle.
	Props._prism(parts, Vector3(0, 0, -0.02), Vector3(0, 0, -1), 0.3, 0.09, _mat("crystal_pale"))
	for i in 7:
		var a := i * TAU / 7.0
		var r := 0.17
		Props._prism(parts, Vector3(cos(a) * r, sin(a) * r, -0.02), Vector3(cos(a) * 0.35, sin(a) * 0.35, -1), rng.randf_range(0.17, 0.25), 0.065, _mat("crystal"))
	for i in 11:
		var a := i * TAU / 11.0 + 0.2
		var r := 0.31
		Props._prism(parts, Vector3(cos(a) * r, sin(a) * r, -0.04), Vector3(cos(a) * 0.7, sin(a) * 0.7, -1), rng.randf_range(0.08, 0.14), 0.05, _mat("crystal" if i % 3 else "crystal_pale"))
	_meshes["geode"] = Props._bake(parts)
	return _meshes["geode"]


## A miner's helmet: a brass dome with a brim, and its lamp at the front (+Z on the head bone).
static func _helmet_mesh() -> ArrayMesh:
	if _meshes.has("helmet"):
		return _meshes["helmet"]
	var parts := []
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 14
	dome.rings = 5
	parts.append([dome, Props._xf(Vector3.ZERO, Vector3(0.5, 0.42, 0.52)), _mat("helmet")])
	parts.append([Props._cone(0.6, 0.62, 0.04, 16), Props._xf(Vector3(0, 0.01, 0.02), Vector3.ONE), _mat("helmet")])
	parts.append([Props._cone(0.5, 0.5, 0.05, 14), Props._xf(Vector3(0, 0.1, 0), Vector3(1.01, 1, 1.01)), _mat("iron")])
	# The lamp on the front.
	var front := Basis(Vector3.RIGHT, PI * 0.5)
	parts.append([Props._cone(0.13, 0.11, 0.1, 12), Transform3D(front, Vector3(0, 0.22, 0.47)), _mat("iron")])
	parts.append([Props._cone(0.1, 0.1, 0.02, 12), Transform3D(front, Vector3(0, 0.22, 0.53)), _mat("lamp")])
	_meshes["helmet"] = Props._bake(parts)
	return _meshes["helmet"]


## A miner's pick, held at the bottom of its handle (+Y up the handle): an iron head with
## a crystal set in it.
static func _pick_mesh() -> ArrayMesh:
	if _meshes.has("pick"):
		return _meshes["pick"]
	var parts := []
	parts.append([Props._cone(0.035, 0.045, 1.0, 6), Props._xf(Vector3(0, 0.4, 0), Vector3.ONE), _mat("wood")])
	var top := Vector3(0, 0.88, 0)
	for sd in [-1.0, 1.0]:
		parts.append([Props._cone(0.012, 0.06, 0.42, 6), Transform3D(Basis(Vector3.FORWARD, sd * PI * 0.44), top + Vector3(sd * 0.2, -0.03, 0)), _mat("iron")])
	parts.append([Props._sphere(), Props._xf(top, Vector3(0.09, 0.08, 0.08)), _mat("iron")])
	Props._prism(parts, top + Vector3(0, 0.02, 0), Vector3.UP, 0.12, 0.045, _mat("crystal"))
	_meshes["pick"] = Props._bake(parts)
	return _meshes["pick"]


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel and skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		var helmet := MeshInstance3D.new()
		helmet.mesh = _helmet_mesh()
		helmet.position = Vector3(0, 0.62, 0.02)
		helmet.scale = Vector3.ONE * 0.88
		head.add_child(helmet)
	if skel and skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var pick := MeshInstance3D.new()
		pick.mesh = _pick_mesh()
		pick.position = Vector3(0, -0.15, 0)
		hand.add_child(pick)
	# The geode, held before its left side (the visual's -Z is the way it faces). It hangs
	# from the body rather than the hand, so it always covers the front.
	_geode = Node3D.new()
	_geode.position = Vector3(-0.15, 1.05, -0.62)
	visual.add_child(_geode)
	var g := MeshInstance3D.new()
	g.mesh = _geode_mesh()
	g.scale = Vector3.ONE * 1.7
	g.rotation.x = 0.35   # its crystals tipped up a little, towards the camera above
	_geode.add_child(g)
	# Its lamp's light on the floor ahead: which way it faces, so which way is guarded.
	_cone = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2.4, 3.2)
	_cone.mesh = q
	_cone.material_override = _mat("cone")
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position = Vector3(0, 0.04, -2.0)
	visual.add_child(_cone)


# --- How it fights ---------------------------------------------------------------------------

## Shots coming at its front hit the geode, unless it is swung aside.
func blocks_shot(dir: Vector3) -> bool:
	if dead or _open > 0.5 or not ready_to_fight():
		return false
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return false
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	return dir.normalized().dot(fwd.normalized()) < -GUARD_COS


func on_block(at: Vector3) -> void:
	_blocks += 1
	Fx.sparks(at, AMETHYST)
	Sfx.play("clink", 0.7, randf_range(0.94, 1.1))
	if _geode:
		_geode.scale = Vector3.ONE * 1.08
		_geode.create_tween().tween_property(_geode, "scale", Vector3.ONE, 0.12)
	Game._teach("geode_block", "BLOCKED! Walk round the Geode Guard and hit its side or back!")


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if mode == Mode.STUCK:
		amount *= OPEN_DAMAGE
	super.take_damage(amount, direction, push, crit)


func _process(delta: float) -> void:
	super._process(delta)
	if dead or _geode == null:
		return
	var want := 1.0 if mode == Mode.STUCK else 0.0
	_open = move_toward(_open, want, delta * (5.0 if want > _open else 3.0))
	# Swung aside: out to its left and turned edge on.
	_geode.position = Vector3(-0.15 - 0.75 * _open, 1.05 - 0.25 * _open, -0.62 + 0.45 * _open)
	_geode.rotation.y = -1.25 * _open
	_cone.visible = mode != Mode.STUCK


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	match mode:
		Mode.WINDUP:
			stand(delta)
			_left -= delta
			if _left <= 0.0:
				_slam()
		Mode.STUCK:
			stand(delta)
			_left -= delta
			if _left <= 0.0:
				mode = Mode.APPROACH
				_timer = randf_range(1.6, 2.4)
		_:
			# It walks at you but turns slowly, so circling it gets you to its side.
			var r := rotation.y
			if to.length() > 1.6:
				walk(to, delta)
			else:
				stand(delta)
			rotation.y = r
			face(to, TURN, delta)
			_timer -= delta
			var fwd := -global_transform.basis.z
			if _timer <= 0.0 and to.length() < SLAM_LEN - 0.4 and fwd.dot(to.normalized()) > 0.8:
				_windup()


## Raises its pick: the strip in front of it where crystals will burst out.
func _windup() -> void:
	mode = Mode.WINDUP
	_left = WINDUP
	visual.attack(true)
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	track(Telegraph.line(global_position, fwd.normalized(), SLAM_LEN, SLAM_WIDTH, WINDUP, Callable()))


## The pick comes down: crystals burst out of the floor along the strip, then it sticks.
func _slam() -> void:
	mode = Mode.STUCK
	_left = STUCK_TIME
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	Sfx.play("slam", 0.8, 0.9)
	Sfx.play("clink", 0.6, 0.7)
	Game.shake(0.12)
	for i in 5:
		var at := global_position + fwd * (0.6 + i * 0.7)
		_burst(at, i * 0.05)
	var hero := Game.hero
	if hero and not hero.dead:
		var d := hero.global_position - global_position
		d.y = 0.0
		var along := d.dot(fwd)
		var across := absf(d.dot(fwd.cross(Vector3.UP)))
		if along > 0.0 and along < SLAM_LEN + hero.radius and across < SLAM_WIDTH * 0.5 + hero.radius:
			Game.hit_source = "Geode Guard"
			hero.take_damage(16.0 * elite_mult(), fwd, 6.0)


## A spray of crystals bursting up out of the floor, then sinking back.
func _burst(at: Vector3, wait: float) -> void:
	var parent := Telegraph._parent()
	if parent == null:
		return
	var n := MeshInstance3D.new()
	n.mesh = _burst_mesh()
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	n.global_position = Vector3(at.x, 0.0, at.z)
	n.rotation.y = randf() * TAU
	n.scale = Vector3(1.5, 0.05, 1.5)
	var tw := n.create_tween()
	tw.tween_interval(wait)
	tw.tween_property(n, "scale", Vector3.ONE * 1.5, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Fx.sparks(at + Vector3.UP * 0.3, AMETHYST))
	tw.tween_interval(0.6)
	tw.tween_property(n, "scale", Vector3(1.5, 0.02, 1.5), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


static func _burst_mesh() -> ArrayMesh:
	if _meshes.has("burst"):
		return _meshes["burst"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var parts := []
	Props._prism(parts, Vector3.ZERO, Vector3(0, 1, 0), 0.55, 0.11, _mat("crystal"))
	for i in 5:
		var a := i * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
		Props._prism(parts, Vector3(cos(a) * 0.12, 0, sin(a) * 0.12), Vector3(cos(a) * 0.6, 1, sin(a) * 0.6), rng.randf_range(0.25, 0.4), 0.07, _mat("crystal_pale" if i % 2 else "crystal"))
	_meshes["burst"] = Props._bake(parts)
	return _meshes["burst"]


func _on_death() -> void:
	super._on_death()
	if _geode:
		var tw := _geode.create_tween()
		tw.tween_property(_geode, "position:y", 0.3, 0.35).set_ease(Tween.EASE_IN)
	if _cone:
		_cone.visible = false
	Fx.sparks(center(), AMETHYST)
	Fx.magic(center(), AMETHYST, 14)
