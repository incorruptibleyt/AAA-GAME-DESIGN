class_name CrystalSpire
extends Node3D
## A spire of amethyst the Crystal Tyrant (version 275, the Amethyst Mine's own boss) raises
## out of the rock. While it stands it is solid, as a pillar is (a Room obstacle): nobody
## walks through it, and shots, runaway carts and the Tyrant's crystal ripple break on it,
## so the hero can hide behind it as well as be hemmed in by it. After a while it cracks
## (strips warn where its shards will fly) and bursts.

const SOLID := 0.55   # how round it is, as an obstacle
const CRACK := 0.75   # seconds of warning before it bursts
const SHARD_LEN := 2.6
const SHARD_WIDTH := 0.75
const SHARD_DAMAGE := 12.0

## Every spire standing in the room (the test robot walks round them).
static var all: Array[CrystalSpire] = []
static var _meshes := {}

var source := ""
var life := 5.0        # seconds it stands before it cracks (INF: until told to)
var shards := 4        # how many shards fly when it bursts (0: it just breaks)
var size := 1.0        # the prison's pillars are bigger
var _age := 0.0
var _cracking := -1.0  # seconds into its crack, or -1
var _turn := 0.0       # which way its shards fly
var _ob := {}
var _room: Node
var _body: MeshInstance3D
var _foot: MeshInstance3D
var _gone := false


## Raises a spire at `at` straight away (call when its warning has filled in). Anyone
## standing on the spot is pushed out of it.
static func raise(at: Vector3, src: String, seconds: float, shard_count := 4, big := 1.0) -> CrystalSpire:
	var room: Node = Room.current
	if not is_instance_valid(room):
		return null
	var s := CrystalSpire.new()
	s.source = src
	s.life = seconds
	s.shards = shard_count
	s.size = big
	s._turn = randf() * TAU
	room.add_child(s)
	s.global_position = Vector3(at.x, 0.0, at.z)
	s._build()
	s._room = room
	s._ob = {"pos": s.global_position, "r": SOLID * big}
	room.obstacles.append(s._ob)
	_renav(room)
	s._push_out_all()
	return s


## For the shader warm-up (warmup.gd): a spire that just stands there, and one cracking.
static func warm(parent: Node, at: Vector3) -> void:
	for i in 2:
		var s := CrystalSpire.new()
		s.process_mode = Node.PROCESS_MODE_DISABLED
		parent.add_child(s)
		s.position = at + Vector3(i * 1.2, 0, 0)
		s._build()
		s._body.scale = Vector3.ONE
		if i == 1:
			s._body.material_override = mat("crack")


## The room's map of open squares is made again (skeletons find their way round it).
static func _renav(room: Node) -> void:
	if room.has_method("_nav_build"):
		room._nav_build()
		room._nav_goal = -1


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)
	_unblock()


func _unblock() -> void:
	if _ob.is_empty() or not is_instance_valid(_room):
		return
	var obs: Array = _room.obstacles
	for i in obs.size():
		if is_same(obs[i], _ob):
			obs.remove_at(i)
			break
	_ob = {}
	_renav(_room)


## Pushes the hero and any skeleton off the spot it rose on.
func _push_out_all() -> void:
	var hero := Game.hero
	if hero and not hero.dead and covers(hero.global_position, hero.radius):
		hero.global_position = _clear_spot(hero.global_position, hero.radius)
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and not en.dead and covers(en.global_position, en.radius):
			en.global_position = _clear_spot(en.global_position, en.radius)


## Where a body `r` round at `p` can stand clear of this spire and of everything else.
## Straight out of it when that is free; otherwise (squeezed between two spires, or a spire
## and a wall, it would be pushed from one into the other) the nearest free spot round it.
func _clear_spot(p: Vector3, r: float) -> Vector3:
	var room: Node = _room
	var q: Vector3 = room.resolve_move(p, Vector3.ZERO, r)
	if room.is_walkable(q, r + 0.12):
		return q
	var away := p - global_position
	away.y = 0.0
	var base := atan2(away.z, away.x) if away.length() > 0.01 else 0.0
	for k in 6:
		var dist := SOLID * size + r + 0.2 + k * 0.4
		for j in 16:
			var a := base + int((j + 1) / 2.0) * (TAU / 16.0) * (1.0 if j % 2 == 0 else -1.0)
			var c := global_position + Vector3(cos(a), 0.0, sin(a)) * dist
			if room.is_walkable(c, r + 0.12):
				return c
	return q


func covers(p: Vector3, r := 0.0) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= SOLID * size + r


func _build() -> void:
	_body = MeshInstance3D.new()
	_body.mesh = spire_mesh()
	_body.material_override = mat("spire")
	_body.scale = Vector3(size, 0.05, size)
	_body.rotation.y = randf() * TAU
	add_child(_body)
	_foot = MeshInstance3D.new()
	_foot.mesh = _rubble_mesh()
	_foot.scale = Vector3.ONE * size
	_foot.rotation.y = randf() * TAU
	add_child(_foot)
	var tw := _body.create_tween()
	tw.tween_property(_body, "scale", Vector3.ONE * size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _gone:
		return
	_age += delta
	if _cracking < 0.0 and _age >= life:
		crack()
	if _cracking >= 0.0:
		_cracking += delta
		# It shivers as it cracks.
		_body.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.03 * size
		if _cracking >= CRACK:
			burst(true)


## Starts its crack: the shards' strips are shown, then it bursts.
func crack() -> void:
	if _cracking >= 0.0 or _gone:
		return
	_cracking = 0.0
	_body.material_override = mat("crack")
	Sfx.play("shatter", 0.35, 1.5)
	for i in shards:
		var a := _turn + TAU * i / shards
		var d := Vector3(cos(a), 0.0, sin(a))
		Telegraph.line(global_position + d * SOLID * size, d, SHARD_LEN, SHARD_WIDTH, CRACK, Callable(), 0.4 if i == 0 else 0.0)


## Bursts: its shards fly out along their strips (hurting the hero on one when `harm`),
## and it is gone.
func burst(harm := true) -> void:
	if _gone:
		return
	_gone = true
	_unblock()
	var here := global_position
	Sfx.play("shatter", 0.6, randf_range(0.92, 1.1))
	Fx._burst(here + Vector3.UP * 1.0 * size, 22, Color(0.78, 0.5, 1.0, 0.9), 0.35, 4.0, 0.6, 9.0)
	Fx.dust(here, 10)
	if harm and _cracking >= 0.0:
		for i in shards:
			var a := _turn + TAU * i / shards
			var d := Vector3(cos(a), 0.0, sin(a))
			Enemy.strike_strip(here + d * SOLID * size, d, SHARD_LEN, SHARD_WIDTH, SHARD_DAMAGE, source)
			_fly_shard(here + d * 0.4 + Vector3.UP * 0.6, d)
	queue_free()


## A shard of it flying out along `d` (drawn in the room, it outlives the spire).
func _fly_shard(from: Vector3, d: Vector3) -> void:
	var room: Node = _room if is_instance_valid(_room) else get_parent()
	if room == null:
		return
	var s := MeshInstance3D.new()
	s.mesh = shard_mesh()
	s.material_override = mat("spire")
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(s)
	s.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5), from)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "global_position", from + d * SHARD_LEN + Vector3.DOWN * 0.45, 0.22)
	tw.chain().tween_property(s, "scale", Vector3.ZERO, 0.15)
	tw.chain().tween_callback(s.queue_free)


## Breaks every spire in the room at once, harmlessly (the Tyrant has fallen).
static func break_all() -> void:
	for s in all.duplicate():
		if is_instance_valid(s):
			(s as CrystalSpire).burst(false)


# --- How it looks ----------------------------------------------------------------------------

static func mat(key: String) -> Material:
	var k := "mat_" + key
	if not _meshes.has(k):
		var sh := Shader.new()
		sh.code = SHADER if key == "spire" else SHADER.replace("render_mode", "#define CRACKING\nrender_mode")
		var m := ShaderMaterial.new()
		m.shader = sh
		_meshes[k] = m
	return _meshes[k]


## The spire (its foot at 0, up +Y): one tall six-sided crystal with a point, leaning a
## little, and three smaller ones round its foot, as amethyst grows.
static func spire_mesh() -> ArrayMesh:
	if _meshes.has("spire"):
		return _meshes["spire"]
	var parts := []
	var m := mat("spire")
	Props._prism(parts, Vector3(0, -0.1, 0), Vector3(0.06, 1, 0.04), 1.75, 0.3, m)
	Props._prism(parts, Vector3(0.28, -0.1, 0.12), Vector3(0.55, 1, 0.2), 0.95, 0.19, m)
	Props._prism(parts, Vector3(-0.22, -0.1, 0.2), Vector3(-0.5, 1, 0.45), 0.75, 0.16, m)
	Props._prism(parts, Vector3(-0.05, -0.1, -0.3), Vector3(-0.1, 1, -0.6), 0.85, 0.17, m)
	_meshes["spire"] = Props._bake(parts)
	return _meshes["spire"]


## A crystal shard (its point up +Y).
static func shard_mesh() -> ArrayMesh:
	if _meshes.has("shard"):
		return _meshes["shard"]
	var parts := []
	Props._prism(parts, Vector3(0, -0.25, 0), Vector3.UP, 0.4, 0.09, mat("spire"))
	_meshes["shard"] = Props._bake(parts)
	return _meshes["shard"]


## Broken rock heaved up round its foot.
static func _rubble_mesh() -> ArrayMesh:
	if _meshes.has("rubble"):
		return _meshes["rubble"]
	var parts := []
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var r := 0.48 + 0.08 * (i % 2)
		parts.append([Props._sphere(), Props._xf(Vector3(cos(a) * r, 0.04, sin(a) * r), Vector3(0.2, 0.12, 0.16), Basis(Vector3.UP, a)), Props._mine_mat("rock" if i % 2 == 0 else "rock_dark")])
	_meshes["rubble"] = Props._bake(parts)
	return _meshes["rubble"]


## Glassy amethyst: deep violet at the foot, paler and brighter up to the point, light
## caught on its edges. Cracking, white cracks flicker across it.
const SHADER := """
shader_type spatial;
render_mode cull_back;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float up = clamp(lp.y / 1.9, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 deep = vec3(0.3, 0.09, 0.58);
	vec3 pale = vec3(0.88, 0.7, 1.0);
	float band = 0.5 + 0.5 * sin(lp.y * 9.0 + lp.x * 3.0);
	vec3 col = mix(deep, pale, up * 0.65 + rim * 0.35) * (0.9 + 0.1 * band);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.15;
	SPECULAR = 0.9;
	EMISSION = col * (0.3 + 0.5 * up) + vec3(0.85, 0.65, 1.0) * rim * 0.5;
#ifdef CRACKING
	float c = abs(sin(lp.x * 23.0 + lp.y * 7.0) * sin(lp.z * 19.0 - lp.y * 11.0));
	float crack = 1.0 - smoothstep(0.0, 0.12, c);
	float flick = 0.6 + 0.4 * sin(TIME * 40.0);
	EMISSION += vec3(1.0, 0.9, 1.0) * crack * 2.2 * flick;
#endif
}
"""
