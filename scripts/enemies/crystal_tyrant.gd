class_name CrystalTyrant
extends Enemy
## The Amethyst Mine's own boss (floor 7, version 275; hard review of build 267, fix 11).
## Until then the Mine ended with the Skeleton King, the boss of floor 1.
##
## The skeleton that dug too deep: amethyst has grown through its bones, a crown of crystals
## has burst from its skull, a ridge of great crystals stands along its back, and its right
## fist is a lump of raw crystal. The mine's crystals grow at its call. Every attack has a
## warning:
## - Crystal Garden: circles mark the floor on you and round you, then spires of amethyst
##   burst up out of them. While they stand they are solid: they hem you in, but they stop
##   shots, carts and ripples too, so hide behind one. Each cracks after a few seconds and
##   its shards fly out along strips.
## - Runaway Carts: strips run across the room, then mine carts heaped with crystal come
##   thundering out of the side tunnels along them. Step between the strips, or behind cover
##   (a cart smashes on it).
## - Crystal Ripple: it raises its fist, a ring of crystals round its feet, and slams the
##   floor: the ring runs out across the room, crystals bursting up as it goes. Stand in one
##   of its gaps, dash through it, or keep a pillar between you and it.
## - Crystal Prison (phase 2's own move): pillars of crystal rise round you one by one,
##   closing towards the last gap. Get out before it shuts: then the prison bursts inwards.
## - Rolling Geode (version 301, its encore in the endless loops): it hurls a great geode
##   bristling with amethyst that rolls after you, slowly turning your way and bouncing off
##   the walls. Lead it into a pillar or a crystal spire, or dash aside: it smashes on cover,
##   on you, or after its third bounce, and bursts into shards along strips.
## Below half health its crystals grow and blaze, two Geode Guards climb out of the rock, and
## it attacks harder: more spires, a second wave of carts, a second ring.

const DISPLAY_NAME := "The Crystal Tyrant"
const AMETHYST := Color(0.72, 0.42, 1.0)
const PALE := Color(0.88, 0.7, 1.0)
const DEEP := Color(0.42, 0.16, 0.8)

## Crystal Garden: each spire's warning circle, how long it takes to burst up, how long it stands.
const GARDEN_R := 0.85
const GARDEN_TIME := 1.0
const SPIRE_LIFE := 5.5
const GARDEN_DAMAGE := 14.0
const MAX_SPIRES := 12
## Runaway Carts: the strips across the room, the carts' speed and size, and the gap between
## lanes.
const LANE_GAP := 3.2
const LANE_WIDTH := 1.35
const CART_AIM := 1.05
const CART_SPEED := 11.5
const CART_HALF_W := 0.6
const CART_HALF_L := 0.8
const CART_DAMAGE := 18.0
const CART_SCALE := 1.5
## Crystal Ripple: the ring's angles, how fast it runs, its gaps.
const RING_N := 96
const RING_SPEED := 5.5
const RING_BAND := 0.45
const RING_GAPS := 3
const RING_GAP := 0.52      # radians wide, each
const RING_AIM := 0.95
const RING_DAMAGE := 16.0
const RING_MAX := 14.0
const RING_START := 2.3     # the ring stands round it this far out while it winds up
## Crystal Prison.
const PRISON_N := 10
const PRISON_R := 2.6
const PRISON_WARN := 0.5
const PRISON_STEP := 0.24
const PRISON_DAMAGE := 20.0
const PILLAR_DAMAGE := 10.0

static var _meshes := {}

var _enraged := false
var _started := false
var _busy := false
var _t := 0.0
var _face_to := Vector3.ZERO   # while it aims, it faces this way
var _crown: Node3D
var _ridge: Node3D
var _fist: Node3D
var _carts: Array = []         # each {node, x, z, end, hit, spark}
var _rings: Array = []         # each {at, r, gap: PackedByteArray, stop: PackedFloat32Array, hit, live}
var _spikes: MultiMeshInstance3D


func _setup() -> void:
	is_boss = true
	roar_sound = "roar_tyrant"
	init_health(860.0)
	drop_chance = 0.0
	move_speed = 1.25
	contact_damage = 16.0
	radius = 1.15
	center_height = 1.9
	knockback_scale = 0.05
	var look := bones(Art.SKELETON_MINION, 4.5, AMETHYST)
	look.hide = ["Skeleton_Minion_Cloak"]
	look.overlay = _crystal_bones()
	look.shape = {"scale": {"chest": 1.45, "head": 0.72, "upperarm.l": 1.3, "upperarm.r": 1.6, "upperleg.l": 0.8, "upperleg.r": 0.8},
		"turn": {"spine": Vector3(15, 0, 0), "head": Vector3(-12, 0, 0)}}   # (v350: a hulk, its crystal fist long)
	look.parts = "tyrant"
	look.attack_anim = "1H_Melee_Attack_Chop"
	make_visual(look)
	_dress()


func display_name() -> String:
	return DISPLAY_NAME


# --- How it looks ----------------------------------------------------------------------------

## Amethyst grown through its bones: faceted crystal in patches all over, thickest on its
## legs and arms, bone showing between. One see-through pass over its bones.
static func _crystal_bones() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode depth_draw_never, cull_back;
varying vec3 lp;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
vec3 hash3(vec3 p) {
	return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}
void vertex() { lp = VERTEX; }
void fragment() {
	// Cells of crystal (the nearest of a few scattered points): each a facet of its own shade.
	vec3 q = lp * 6.5;
	vec3 base = floor(q - 0.5);
	float d1 = 9.0;
	float d2 = 9.0;
	vec3 best = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec3 g = base + vec3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1));
		float d = length(q - g - hash3(g));
		if (d < d1) { d2 = d1; d1 = d; best = g; } else if (d < d2) { d2 = d; }
	}
	float h = hash(best);
	float chance = mix(0.86, 0.14, smoothstep(0.2, 1.65, lp.y));   // legs crystal, skull bone
	float crystal = step(h, chance);
	float edge = 1.0 - smoothstep(0.0, 0.07, d2 - d1);
	vec3 facet = mix(vec3(0.36, 0.11, 0.68), vec3(0.86, 0.64, 1.0), fract(h * 7.31));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	ALBEDO = facet;
	ROUGHNESS = 0.16;
	METALLIC = 0.25;
	SPECULAR = 0.9;
	EMISSION = facet * 0.32 + vec3(0.92, 0.75, 1.0) * edge * 0.55 + vec3(0.72, 0.42, 1.0) * rim * 0.45;
	ALPHA = crystal * 0.96;
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
			"crystal": _meshes[k] = U.mat(Color(0.6, 0.27, 0.98), 0.15, 1.2)
			"pale": _meshes[k] = U.mat(Color(0.78, 0.56, 1.0), 0.15, 0.8)
			"deep": _meshes[k] = U.mat(Color(0.3, 0.1, 0.58), 0.2, 0.6)
			"rock": _meshes[k] = U.mat(Color(0.2, 0.18, 0.22), 0.95)
			"eye": _meshes[k] = U.unlit(Color(0.9, 0.55, 1.0))
			"glow":
				var g := StandardMaterial3D.new()
				g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				g.cull_mode = BaseMaterial3D.CULL_DISABLED
				g.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				g.billboard_keep_scale = true
				g.albedo_texture = U.soft_circle()
				g.albedo_color = Color(0.8, 0.5, 1.0, 0.55)
				_meshes[k] = g
	return _meshes[k]


## The crown (head-bone space, +Z the face; the skull reaches 0.92 up): crystals bursting
## out of the top of its skull in a ring, leaning out, the one over its brow the tallest.
static func _crown_mesh() -> ArrayMesh:
	if _meshes.has("crown"):
		return _meshes["crown"]
	var parts := []
	for i in 7:
		var a := PI * 0.5 + TAU * i / 7.0   # i = 0 over the brow (+Z)
		var out := Vector3(cos(a), 0.0, sin(a))
		var front := 0.5 + 0.5 * out.z
		var base := Vector3(0, 0.76, -0.02) + out * 0.27
		var ln := 0.2 + 0.24 * front
		Props._prism(parts, base, out * 0.6 + Vector3.UP, ln, 0.06 + 0.025 * front, _mat("pale" if i % 2 == 0 else "crystal"))
	# A short one straight up in the middle.
	Props._prism(parts, Vector3(0, 0.84, -0.04), Vector3(0.05, 1, -0.1), 0.24, 0.07, _mat("crystal"))
	_meshes["crown"] = Props._bake(parts)
	return _meshes["crown"]


## The ridge on its back (chest-bone space, +Z its front, its back at z -0.36): great
## crystals fanning up and back from between its shoulders, the middle one the tallest,
## smaller ones round their roots, and two jutting from each shoulder.
static func _ridge_mesh() -> ArrayMesh:
	if _meshes.has("ridge"):
		return _meshes["ridge"]
	var parts := []
	var big := [[0.0, 0.6, 0.095], [0.18, 0.48, 0.085], [-0.18, 0.5, 0.085], [0.34, 0.34, 0.07], [-0.34, 0.36, 0.07]]
	for b: Array in big:
		var x: float = b[0]
		Props._prism(parts, Vector3(x, 0.24, -0.3), Vector3(x * 1.4, 1.0, -0.7), b[1], b[2], _mat("crystal" if absf(x) < 0.25 else "deep"))
	for i in 6:
		var x := -0.4 + i * 0.16
		Props._prism(parts, Vector3(x, 0.1, -0.33), Vector3(x * 1.8, 0.5, -1.0), 0.16, 0.045, _mat("pale"))
	for sd in [-1.0, 1.0]:
		Props._prism(parts, Vector3(sd * 0.36, 0.38, -0.02), Vector3(sd * 1.0, 1.0, -0.2), 0.24, 0.06, _mat("crystal"))
		Props._prism(parts, Vector3(sd * 0.4, 0.32, 0.1), Vector3(sd * 1.0, 0.45, 0.35), 0.16, 0.045, _mat("pale"))
	_meshes["ridge"] = Props._bake(parts)
	return _meshes["ridge"]


## Its right fist, a lump of raw amethyst: crystals jutting every way out of a knot of rock.
static func _fist_mesh() -> ArrayMesh:
	if _meshes.has("fist"):
		return _meshes["fist"]
	var parts := []
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.05, 0), Vector3(0.22, 0.2, 0.22)), _mat("rock")])
	var dirs := [Vector3(0, 1, 0), Vector3(1, 0.4, 0.2), Vector3(-1, 0.5, 0.1), Vector3(0.2, 0.3, 1), Vector3(-0.3, 0.2, -1),
		Vector3(0.7, -0.6, 0.5), Vector3(-0.6, -0.7, -0.4), Vector3(0.6, 0.8, -0.6)]
	for i in dirs.size():
		var d: Vector3 = dirs[i].normalized()
		Props._prism(parts, Vector3(0, 0.05, 0) + d * 0.12, d, 0.22 + 0.14 * float(i % 3 == 0), 0.07 + 0.02 * float(i % 2 == 0), _mat("crystal" if i % 2 == 0 else "pale"))
	_meshes["fist"] = Props._bake(parts)
	return _meshes["fist"]


## A runaway cart (rolling along +Z, its length, its lantern at the front): the mine's own
## cart, its heap of crystals glowing.
static func _cart_node() -> Node3D:
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	m.mesh = Props._mine_cart()
	# The cart's mesh stands along X, a little off its middle (Props._mine_cart): turn it to
	# roll along Z and centre it.
	m.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.1, 0, 0.35))
	n.add_child(m)
	# A lantern swinging on its front, and the glow of its heap of crystal, so it reads from
	# above as it comes.
	var lamp := MeshInstance3D.new()
	lamp.mesh = Props._sphere()
	lamp.material_override = Props._mine_mat("lamp")
	lamp.scale = Vector3.ONE * 0.13
	lamp.position = Vector3(0, 0.95, 0.5)
	n.add_child(lamp)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.9, 1.9)
	glow.mesh = q
	glow.material_override = _mat("glow")
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, 0.9, 0)
	n.add_child(glow)
	n.scale = Vector3.ONE * CART_SCALE
	return n


## One crystal of the ripple (its point up +Y).
static func _spike_mesh() -> ArrayMesh:
	if _meshes.has("spike"):
		return _meshes["spike"]
	var parts := []
	Props._prism(parts, Vector3(0, -0.2, 0), Vector3.UP, 0.9, 0.2, CrystalSpire.mat("spire"))
	Props._prism(parts, Vector3(0.15, -0.2, 0.06), Vector3(0.5, 1, 0.1), 0.5, 0.13, CrystalSpire.mat("spire"))
	_meshes["spike"] = Props._bake(parts)
	return _meshes["spike"]


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel and skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		_crown = Node3D.new()
		head.add_child(_crown)
		var crown := MeshInstance3D.new()
		crown.mesh = _crown_mesh()
		_crown.add_child(crown)
		# Violet eyes over the rig's own yellow ones.
		for sx in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			eye.mesh = Props._sphere()
			eye.material_override = _mat("eye")
			eye.scale = Vector3(0.085, 0.065, 0.03)
			eye.position = Vector3(sx * 0.16, 0.49, 0.43)
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			head.add_child(eye)
	if skel and skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		_ridge = Node3D.new()
		chest.add_child(_ridge)
		var ridge := MeshInstance3D.new()
		ridge.mesh = _ridge_mesh()
		_ridge.add_child(ridge)
	if skel and skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		_fist = Node3D.new()
		hand.add_child(_fist)
		var fist := MeshInstance3D.new()
		fist.mesh = _fist_mesh()
		fist.scale = Vector3.ONE * 0.8
		_fist.add_child(fist)
	# The ripple's crystals: one mesh drawn many times, in the room's space.
	_spikes = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _spike_mesh()
	mm.instance_count = RING_N * 4
	mm.visible_instance_count = 0
	_spikes.multimesh = mm
	_spikes.top_level = true
	_spikes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spikes.custom_aabb = AABB(Vector3(-16, -1, -16), Vector3(32, 4, 32))
	add_child(_spikes)


## For the shader warm-up (warmup.gd): spires (standing and cracking), a crystal of the
## ripple, and a cart.
static func warm(parent: Node3D, at: Vector3) -> void:
	CrystalSpire.warm(parent, at)
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _spike_mesh()
	mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	mmi.multimesh = mm
	parent.add_child(mmi)
	mmi.position = at + Vector3(0, 0, 1.0)
	var cart := _cart_node()
	parent.add_child(cart)
	cart.position = at + Vector3(-1.2, 0, 0)


## Phase 2: its crystals grow and blaze.
func _blaze() -> void:
	for n: Node3D in [_crown, _ridge, _fist]:
		if n:
			n.create_tween().tween_property(n, "scale", n.scale * 1.25, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- How it fights ---------------------------------------------------------------------------

func _think(hero: Hero, delta: float) -> void:
	_t += delta
	if not _started:
		_started = true
		Sfx.play(roar_sound)
		Sfx.play("crystal_rise", 0.7, 0.8)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.25
		phase_two(AMETHYST, "prison", "Crystal Prison")
		_blaze()
		_raise_guards()
	if randf() < delta * 2.5:
		# Crystal dust glitters off it.
		Fx.magic(center() + Vector3(randf_range(-0.9, 0.9), randf_range(-0.4, 1.6), randf_range(-0.9, 0.9)), PALE if randf() < 0.5 else AMETHYST, 2)
	if _busy:
		stand(delta)
		if _face_to != Vector3.ZERO:
			face(_face_to, 12.0, delta)
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > 4.5:
		walk(to, delta)
	else:
		stand(delta)
		face(to, 6.0, delta)


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
		var moves := ["garden", "carts", "ripple", "garden"]
		if _enraged:
			moves.append("prison")   # phase 2's own move
		if returning():
			moves.append("encore")   # Rolling Geode (version 301)
		match next_move(moves):
			"garden": await _garden()
			"carts": await _run_carts()
			"ripple": await _ripple()
			"prison": await _prison()
			"encore": await _geode()
		_busy = false
		_face_to = Vector3.ZERO
		await _wait(1.0 if _enraged else 1.5)


func _room() -> Node:
	return Room.current if is_instance_valid(Room.current) else get_parent()


func _in_room(p: Vector3, r := 0.6) -> Vector3:
	p.x = clampf(p.x, -Room.HALF_W + r + 0.4, Room.HALF_W - r - 0.4)
	p.z = clampf(p.z, -Room.HALF_L + r + 0.4, Room.HALF_L - r - 0.4)
	p.y = 0.0
	return Room.current.resolve_move(p, Vector3.ZERO, r) if is_instance_valid(Room.current) else p


func _cast() -> void:
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)


## Whether a spire may rise at `p`: clear of the Tyrant, of other skeletons, and of the
## other spots chosen.
func _spire_room(p: Vector3, taken: Array[Vector3]) -> bool:
	if Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + CrystalSpire.SOLID + 0.6:
		return false
	for q in taken:
		if p.distance_to(q) < 1.4:
			return false
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en and en != self and not en.dead and Vector2(p.x - en.global_position.x, p.z - en.global_position.z).length() < en.radius + CrystalSpire.SOLID + 0.2:
			return false
	return true


# Crystal Garden ---------------------------------------------------------------------------------

## Circles mark the floor on the hero and round them; spires of amethyst burst up out of them.
func _garden() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_cast()
	Sfx.play(roar_sound, 0.45, 1.2)
	var n := 5 if _enraged else 4
	var c := hero.global_position
	var start := randf() * TAU
	var spots: Array[Vector3] = [c]
	for i in n - 1:
		var a := start + TAU * i / (n - 1) + randf_range(-0.3, 0.3)
		var r := randf_range(2.2, 2.9)
		spots.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
	var source := kind_name()
	var taken: Array[Vector3] = []
	for p in spots:
		if not _alive():
			return
		if CrystalSpire.all.size() + taken.size() >= MAX_SPIRES:
			break
		p = _in_room(p, 0.8)
		if not _spire_room(p, taken):
			continue
		taken.append(p)
		track(Telegraph.circle(p, GARDEN_R, GARDEN_TIME, _erupt.bind(p, source), 0.6 if taken.size() == 1 else 0.0))
		await _wait(0.12)
	await _wait(GARDEN_TIME + 0.3)


func _erupt(spot: Vector3, source: String) -> void:
	if not _alive():
		return
	var hero := Game.hero
	if hero and hero.can_be_hit():
		var d := hero.global_position - spot
		d.y = 0.0
		if d.length() < GARDEN_R + hero.radius * 0.5:
			Game.hit_source = source
			hero.take_damage(GARDEN_DAMAGE, d if d.length() > 0.05 else Vector3.BACK, 7.0)
	CrystalSpire.raise(spot, source, SPIRE_LIFE + randf_range(-0.3, 0.3))
	Fx._burst(spot + Vector3.UP * 0.4, 16, Color(0.78, 0.5, 1.0, 0.85), 0.32, 3.4, 0.6, 8.0)
	Fx.dust(spot, 12)
	Sfx.play("crystal_rise", 0.55, randf_range(0.9, 1.1))
	Game.shake(0.1)


# Runaway Carts ----------------------------------------------------------------------------------

## Up to three lanes across the room (`LANE_GAP` apart, one on the hero), each from the side
## wall that gives its cart the longer run past the hero: {start, dir, run}. A lane that cover
## blocks right by the wall gives way to the next one out. Cover between a cart and the hero
## stops it: the hero hides behind cover, the carts don't.
func _lanes(z0: float, hx: float) -> Array:
	var lim := Room.HALF_L - 1.0
	z0 = clampf(z0, -lim, lim)
	var zs: Array[float] = []
	for k in range(-3, 4):
		var z := z0 + k * LANE_GAP
		if absf(z) <= lim:
			zs.append(z)
	zs.sort_custom(func(a: float, b: float) -> bool: return absf(a - z0) < absf(b - z0))
	var out: Array = []
	for z in zs:
		var lane := _lane(z, hx)
		if float(lane.run) >= 3.0:
			out.append(lane)
		if out.size() >= 3:
			break
	return out


func _lane(z: float, hx: float) -> Dictionary:
	var best := {}
	for sd: float in [-1.0, 1.0]:   # from the left wall (rolling +X) or the right (rolling -X)
		var start := Vector3(sd * (Room.HALF_W - 0.9), 0.0, z)
		var dir := Vector3(-sd, 0.0, 0.0)
		var run := _run_length(start, dir)
		var reaches := (start.x + dir.x * run - hx) * dir.x >= 0.0   # it gets past the hero's column
		var score := run + (100.0 if reaches else 0.0) + randf() * 0.5
		if best.is_empty() or score > float(best.score):
			best = {"start": start, "dir": dir, "run": run, "score": score}
	return best


## How far a cart rolls from `start` along `dir` before cover (or the far wall) stops it.
func _run_length(start: Vector3, dir: Vector3) -> float:
	var run := 0.0
	while run < Room.HALF_W * 2.0:
		var p := start + dir * (run + CART_HALF_L + 0.2)
		if is_instance_valid(Room.current) and Room.current.blocks_shot(p, CART_HALF_W * 0.8):
			break
		run += 0.25
	return run


## Strips run across the room, then mine carts come thundering out of the side tunnels along
## them.
func _run_carts() -> void:
	var hero := Game.hero
	if hero == null:
		return
	_cast()
	Sfx.play(roar_sound, 0.5, 1.1)
	var waves := 2 if _enraged else 1
	var side := 1.0 if randf() < 0.5 else -1.0
	var source := kind_name()
	for w in waves:
		if not _alive() or Game.hero == null:
			return
		var h := Game.hero.global_position
		var lanes := _lanes(h.z + (LANE_GAP * 0.5 * side if w == 1 else 0.0), h.x)
		for i in lanes.size():
			var l: Dictionary = lanes[i]
			var dir: Vector3 = l.dir
			var start: Vector3 = l.start
			track(Telegraph.line(start - dir * CART_HALF_L, dir, float(l.run) + CART_HALF_L * 2.0, LANE_WIDTH, CART_AIM, Callable(), 0.6 if i == 0 else 0.0))
		Sfx.play("cart", 0.45, 0.8)
		await _wait(CART_AIM)
		if not _alive():
			return
		Sfx.play("cart", 0.9, randf_range(0.95, 1.05))
		Game.shake(0.15)
		for l: Dictionary in lanes:
			var dir: Vector3 = l.dir
			var n := _cart_node()
			_room().add_child(n)
			n.global_position = l.start
			n.rotation.y = atan2(dir.x, dir.z)
			Fx.dust(n.global_position, 10)
			_carts.append({"node": n, "start": l.start, "dir": dir, "s": 0.0, "run": l.run, "hit": false, "spark": 0.0})
		if w == 0 and waves > 1:
			# The second wave's strips come while the first is rolling.
			var t := 0.0
			while t < 0.45 and _alive():
				t += get_process_delta_time()
				_roll(get_process_delta_time(), source)
				await frame()
	var guard := 0.0
	while _alive() and not _carts.is_empty() and guard < 4.0:
		var dt := get_process_delta_time()
		guard += dt
		_roll(dt, source)
		await frame()
	_clear_carts()
	await _wait(0.2)


func _roll(dt: float, source: String) -> void:
	var h := Game.hero
	var keep: Array = []
	for c: Dictionary in _carts:
		var n: Node3D = c.node
		if not is_instance_valid(n):
			continue
		c.s = float(c.s) + CART_SPEED * dt
		var dir: Vector3 = c.dir
		var p: Vector3 = c.start + dir * float(c.s)
		n.global_position = p + Vector3.UP * absf(sin(float(c.s) * 2.3)) * 0.05
		n.rotation.x = sin(float(c.s) * 1.7) * 0.04
		c.spark = float(c.spark) - dt
		if float(c.spark) <= 0.0:
			c.spark = 0.08
			Fx.sparks(p - dir * 0.6 + dir.cross(Vector3.UP) * randf_range(-0.5, 0.5) + Vector3.UP * 0.15, Color(1.0, 0.75, 0.45))
			if randf() < 0.5:
				Fx.dust(p - dir * 0.9, 3)
		if not bool(c.hit) and h and h.can_be_hit():
			var off := h.global_position - p
			off.y = 0.0
			var across := off.dot(dir.cross(Vector3.UP))
			if absf(off.dot(dir)) < CART_HALF_L + h.radius * 0.6 and absf(across) < CART_HALF_W + h.radius * 0.6:
				c.hit = true
				Game.hit_source = source
				h.take_damage(CART_DAMAGE, (dir + dir.cross(Vector3.UP) * signf(across) * 0.6).normalized(), 10.0)
				Fx.impact(h.global_position + Vector3.UP * 0.8, AMETHYST, 1.0)
				Game.shake(0.2)
		if float(c.s) >= float(c.run):
			_wreck(n, dir)
			continue
		keep.append(c)
	_carts = keep


## A cart smashes on cover or the far wall: it tips over in a burst of crystal and is gone.
func _wreck(n: Node3D, dir: Vector3) -> void:
	var at := n.global_position
	Sfx.play("shatter", 0.6, randf_range(0.75, 0.85))
	Fx.impact(at + Vector3.UP * 0.6, AMETHYST, 1.1)
	Fx._burst(at + Vector3.UP * 0.7, 18, Color(0.8, 0.55, 1.0, 0.9), 0.3, 4.2, 0.6, 9.0)
	Fx.dust(at, 14)
	Game.shake(0.12)
	var tw := n.create_tween().set_parallel()
	tw.tween_property(n, "rotation:x", 1.2, 0.3)
	tw.tween_property(n, "global_position", at + dir * 0.6 + Vector3.UP * 0.3, 0.3)
	tw.chain().tween_property(n, "scale", Vector3.ZERO, 0.25)
	tw.chain().tween_callback(n.queue_free)


func _clear_carts() -> void:
	for c: Dictionary in _carts:
		if is_instance_valid(c.node):
			(c.node as Node).queue_free()
	_carts.clear()


# Rolling Geode ----------------------------------------------------------------------------------

const GEODE_R := 0.8
const GEODE_SPEED := 4.0       # the hero runs at 5.2
const GEODE_SPEED_MAD := 4.6
const GEODE_TURN := 1.0        # radians a second towards the hero
const GEODE_BOUNCES := 3
const GEODE_LIFE := 8.0
const GEODE_DAMAGE := 20.0
const SHARD_DAMAGE := 10.0
var _geode_node: Node3D

## A geode rolls after the hero until it smashes: on cover, on the hero, or after its bounces.
func _geode() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.1 else Vector3.BACK
	_face_to = dir
	_cast()
	Sfx.play(roar_sound, 0.5, 1.1)
	var at := _in_room(global_position + dir * (radius + GEODE_R + 0.3), GEODE_R)
	track(Telegraph.line(at, dir, 6.0, GEODE_R * 2.0, 0.8, Callable()))
	_geode_node = _geode_mesh()
	_room().add_child(_geode_node)
	_geode_node.global_position = at + Vector3.UP * GEODE_R
	_geode_node.scale = Vector3.ONE * 0.2
	_geode_node.create_tween().tween_property(_geode_node, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.magic(at + Vector3.UP, AMETHYST, 20)
	await _wait(0.8)
	if not _alive():
		_drop_geode()
		return
	_busy = false   # it walks again while the geode rolls
	Sfx.play("cart", 0.7, 0.7)
	var source := kind_name()
	var speed := GEODE_SPEED_MAD if _enraged else GEODE_SPEED
	var bounces := 0
	var t := 0.0
	var pos := at
	while _alive() and is_instance_valid(_geode_node):
		var dt := get_physics_process_delta_time()
		await get_tree().physics_frame
		if not _alive() or not is_instance_valid(_geode_node):
			break
		t += dt
		hero = Game.hero
		# Turn slowly towards the hero.
		if hero and not hero.dead:
			var want := hero.global_position - pos
			want.y = 0.0
			if want.length() > 0.2:
				var ang := dir.signed_angle_to(want.normalized(), Vector3.UP)
				dir = dir.rotated(Vector3.UP, clampf(ang, -GEODE_TURN * dt, GEODE_TURN * dt))
		pos += dir * speed * dt
		# Walls: bounce back off them.
		var hit_wall := false
		var lim := Vector2(Room.HALF_W - GEODE_R - 0.2, Room.HALF_L - GEODE_R - 0.2)
		if absf(pos.x) > lim.x:
			pos.x = signf(pos.x) * lim.x
			dir.x = -dir.x
			hit_wall = true
		if absf(pos.z) > lim.y:
			pos.z = signf(pos.z) * lim.y
			dir.z = -dir.z
			hit_wall = true
		if hit_wall:
			bounces += 1
			Sfx.play("crack", 0.5, 0.8)
			Fx.dust(pos, 10)
			Game.shake(0.1)
			if bounces >= GEODE_BOUNCES:
				_burst_geode(pos, dir, source)
				break
		# Cover (pillars, crystal spires) smashes it.
		var smashed := false
		if is_instance_valid(Room.current):
			for o: Dictionary in Room.current.obstacles:
				var d: Vector3 = pos - (o.pos as Vector3)
				d.y = 0.0
				if d.length() < GEODE_R + float(o.r):
					smashed = true
					break
		if smashed or t > GEODE_LIFE:
			_burst_geode(pos, dir, source)
			break
		# The hero: struck and thrown.
		if hero and hero.can_be_hit():
			var d := hero.global_position - pos
			d.y = 0.0
			if d.length() < GEODE_R + hero.radius * 0.8:
				Game.hit_source = source
				hero.take_damage(GEODE_DAMAGE, d if d.length() > 0.05 else dir, 9.0)
				_burst_geode(pos, dir, source)
				break
		# Skeletons in its way are bowled aside.
		for a: Actor in Actor.all:
			if a is Enemy and a != self and not (a as Enemy).is_boss and not a.dead:
				var d := a.global_position - pos
				d.y = 0.0
				if d.length() < GEODE_R + a.radius:
					a.global_position += d.normalized() * 0.15
		_geode_node.global_position = pos + Vector3.UP * GEODE_R
		var axis := Vector3.UP.cross(dir).normalized()
		_geode_node.rotate(axis, speed * dt / GEODE_R)
		if randf() < dt * 6.0:
			Fx.dust(pos, 3)
	_busy = true


## It cracks open: shards fly out along six strips.
func _burst_geode(at: Vector3, dir: Vector3, source: String) -> void:
	Sfx.play("shatter", 0.8, 0.8)
	Fx.impact(at + Vector3.UP * 0.8, AMETHYST, 1.4)
	Fx._burst(at + Vector3.UP * 0.8, 30, Color(0.8, 0.55, 1.0, 0.9), 0.35, 5.0, 0.7, 9.0)
	Fx.shockwave(at, AMETHYST, 2.2)
	Game.shake(0.25)
	_drop_geode()
	var n := 8 if _enraged else 6
	var start := atan2(dir.x, dir.z) + PI / n
	for i in n:
		var a := start + TAU * i / n
		var d := Vector3(sin(a), 0.0, cos(a))
		var o := at
		track(Telegraph.line(o, d, 4.2, 0.6, 0.6, func():
			Fx._burst(o + d * 2.0 + Vector3.UP * 0.4, 8, Color(0.8, 0.55, 1.0, 0.9), 0.2, 3.0, 0.4, 6.0)
			Enemy.strike_strip(o, d, 4.2, 0.6, SHARD_DAMAGE, source), 0.0 if i > 0 else 0.5))


func _drop_geode() -> void:
	if is_instance_valid(_geode_node):
		_geode_node.queue_free()
	_geode_node = null


## A round grey stone, split to show the amethyst inside, bristling with crystals.
func _geode_mesh() -> Node3D:
	var n := Node3D.new()
	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = GEODE_R
	sm.height = GEODE_R * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	rock.mesh = sm
	rock.material_override = _mat("rock")
	n.add_child(rock)
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = GEODE_R * 0.86
	cm.height = GEODE_R * 1.72
	core.mesh = cm
	core.material_override = _mat("crystal")
	core.scale = Vector3(1.08, 1.08, 1.08)
	core.position = Vector3(0, 0, 0)
	# The crystal shows through a wide band round the middle.
	core.scale = Vector3(1.05, 0.55, 1.05)
	n.add_child(core)
	for i in 9:
		var s := MeshInstance3D.new()
		s.mesh = _spike_mesh()
		var a := TAU * i / 9.0
		var up := Vector3(cos(a), (float(i % 3) - 1.0) * 0.6, sin(a)).normalized()
		s.position = up * GEODE_R * 0.7
		s.basis = Basis(Quaternion(Vector3.UP, up))
		s.scale = Vector3.ONE * 0.75
		n.add_child(s)
	var glow := OmniLight3D.new()
	glow.light_color = AMETHYST
	glow.light_energy = 1.4
	glow.omni_range = 3.0
	glow.shadow_enabled = false
	n.add_child(glow)
	return n


# Crystal Ripple ---------------------------------------------------------------------------------

## A ring of crystals runs out from it across the room, with gaps, cover stopping it.
func _new_ring(at: Vector3, gap_at: float) -> Dictionary:
	var gap := PackedByteArray()
	gap.resize(RING_N)
	var stop := PackedFloat32Array()
	stop.resize(RING_N)
	for i in RING_N:
		var a := TAU * i / RING_N
		var g := 0
		for k in RING_GAPS:
			var centre := gap_at + TAU * k / RING_GAPS
			if absf(wrapf(a - centre, -PI, PI)) < RING_GAP * 0.5:
				g = 1
		gap[i] = g
		stop[i] = _ray_stop(at, Vector3(cos(a), 0.0, sin(a)))
	return {"at": at, "r": RING_START, "gap": gap, "stop": stop, "hit": false, "live": false}


## How far the ring runs out along `d` before a wall, a pillar or a spire stops it (a ray
## against each, worked out once for each of its angles).
func _ray_stop(at: Vector3, d: Vector3) -> float:
	var best := RING_MAX
	if absf(d.x) > 0.001:
		best = minf(best, ((Room.HALF_W - 0.15) * signf(d.x) - at.x) / d.x)
	if absf(d.z) > 0.001:
		best = minf(best, ((Room.HALF_L - 0.15) * signf(d.z) - at.z) / d.z)
	if is_instance_valid(Room.current):
		for o: Dictionary in Room.current.obstacles:
			var oc: Vector3 = o.pos - at
			oc.y = 0.0
			var rr: float = float(o.r) + 0.15
			var b := oc.dot(d)
			var disc := b * b - (oc.length_squared() - rr * rr)
			if b <= 0.0 or disc < 0.0:
				continue
			var hit := b - sqrt(disc)
			if hit > 0.0:
				best = minf(best, hit)
	return maxf(best - 0.3, 1.2)


func _ripple() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var here := global_position
	var to := hero.global_position - here
	to.y = 0.0
	_face_to = to
	var ha := atan2(to.z, to.x)
	# One gap near the hero, but a step or two to the side.
	var gap_at := ha + randf_range(0.36, 0.62) * (1.0 if randf() < 0.5 else -1.0)
	_rings = [_new_ring(here, gap_at)]
	if _enraged:
		_rings.append(_new_ring(here, gap_at + 0.55 * (1.0 if randf() < 0.5 else -1.0)))
	_cast()
	Sfx.play(roar_sound, 0.5, 0.95)
	Sfx.play("crystal_rise", 0.5, 0.7)
	# The wind-up: the first ring stands round its feet, gaps and all, growing.
	var t := 0.0
	while t < RING_AIM and _alive():
		t += get_process_delta_time()
		_rings[0].r = RING_START
		_draw_rings(minf(t / RING_AIM, 1.0))
		if _fist and randf() < 0.4:
			Fx.magic(_fist.global_position, PALE, 2)
		await frame()
	if not _alive():
		_clear_rings()
		return
	if not visual.play_named("1H_Melee_Attack_Jump_Chop"):
		visual.attack(false)
	await _wait(0.25)
	if not _alive():
		_clear_rings()
		return
	Sfx.play("shatter", 0.9, 0.6)
	Sfx.play("crystal_rise", 0.8, 0.85)
	Game.shake(0.35)
	Fx.shockwave(here, AMETHYST, 3.0)
	_rings[0].live = true
	var source := kind_name()
	var since := 0.0
	var crackle := 0.0
	while _alive():
		var dt := get_process_delta_time()
		since += dt
		if _rings.size() > 1 and not bool(_rings[1].live) and since >= 0.9:
			_rings[1].live = true
			Sfx.play("crystal_rise", 0.7, 0.9)
			Game.shake(0.2)
		var any := false
		for ring: Dictionary in _rings:
			if not bool(ring.live):
				any = true
				continue
			ring.r = float(ring.r) + RING_SPEED * dt
			if float(ring.r) < RING_MAX:
				any = true
				_ring_hit(ring, source)
		crackle -= dt
		if crackle <= 0.0:
			crackle = 0.22
			Sfx.play("crystal_rise", 0.3, randf_range(1.2, 1.4))
		_draw_rings(1.0)
		if not any:
			break
		await frame()
	_clear_rings()
	await _wait(0.3)


func _ring_hit(ring: Dictionary, source: String) -> void:
	var h := Game.hero
	if bool(ring.hit) or h == null or not h.can_be_hit():
		return
	var at: Vector3 = ring.at
	var off := h.global_position - at
	off.y = 0.0
	var dist := off.length()
	var r: float = ring.r
	if absf(dist - r) > RING_BAND + h.radius * 0.5:
		return
	var i := posmod(int(round(atan2(off.z, off.x) / TAU * RING_N)), RING_N)
	var gap: PackedByteArray = ring.gap
	var stop: PackedFloat32Array = ring.stop
	if gap[i] == 1 or dist > stop[i] + 0.2:
		return
	ring.hit = true
	Game.hit_source = source
	h.take_damage(RING_DAMAGE, off.normalized() if dist > 0.05 else Vector3.BACK, 8.0)
	Fx.impact(h.global_position + Vector3.UP * 0.6, AMETHYST, 1.0)


func _draw_rings(grow: float) -> void:
	if _spikes == null:
		return
	_spikes.global_transform = Transform3D.IDENTITY
	var mm := _spikes.multimesh
	var n := 0
	for k in _rings.size():
		var ring: Dictionary = _rings[k]
		if k > 0 and not bool(ring.live):
			continue   # the second ring shows once it is on its way
		var at: Vector3 = ring.at
		var r: float = ring.r
		var gap: PackedByteArray = ring.gap
		var stop: PackedFloat32Array = ring.stop
		for i in RING_N:
			if gap[i] == 1:
				continue
			var a := TAU * i / RING_N
			var d := Vector3(cos(a), 0.0, sin(a))
			var j := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
			var small := clampf(r / 3.5, 0.6, 1.0) * grow
			for row in 2:
				var rr := r - row * 0.55
				if rr < 1.2 or rr > stop[i] or n >= mm.instance_count:
					continue
				var s := (1.0 - row * 0.45) * small * (0.75 + 0.5 * j)
				var tilt := Basis(d.cross(Vector3.UP).normalized(), -0.35 - 0.2 * j)
				var b := (tilt * Basis(Vector3.UP, j * TAU)).scaled(Vector3.ONE * s)
				mm.set_instance_transform(n, Transform3D(b, Vector3(at.x, 0.0, at.z) + d * rr))
				n += 1
	mm.visible_instance_count = n


func _clear_rings() -> void:
	_rings.clear()
	if _spikes:
		_spikes.multimesh.visible_instance_count = 0


# Crystal Prison ---------------------------------------------------------------------------------

## Phase 2's own move: pillars rise round the hero one by one, closing towards the last gap;
## once shut, the prison bursts inwards.
func _prison() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var c := _in_room(hero.global_position, 0.4)
	# The way out: a direction with open floor beyond it, not into the Tyrant.
	var gap_at := randf() * TAU
	var room := Room.current
	for tries in 12:
		var a := randf() * TAU
		var out := c + Vector3(cos(a), 0.0, sin(a)) * (PRISON_R + 1.3)
		var me := global_position - c
		if room and room.is_walkable(out, 0.5) and Vector3(cos(a), 0, sin(a)).dot(me.normalized()) < 0.5:
			gap_at = a
			break
	_face_to = c - global_position
	_cast()
	Sfx.play(roar_sound, 0.6, 0.9)
	var source := kind_name()
	# Opposite the gap first, then pair by pair round both sides, the gap last.
	var half := int(PRISON_N * 0.5)
	var order: Array = [[half]]
	for k in range(half - 1, 0, -1):
		order.append([k, PRISON_N - k])
	order.append([0])
	var pillars: Array = []
	var marks := 0
	for group: Array in order:
		if not _alive():
			return
		for i: int in group:
			var a := gap_at + TAU * i / PRISON_N
			var p := c + Vector3(cos(a), 0.0, sin(a)) * PRISON_R
			if room and not room.is_walkable(p, 0.3):
				continue   # a wall or cover there already closes it
			if Vector2(p.x - global_position.x, p.z - global_position.z).length() < radius + 0.9:
				continue
			marks += 1
			track(Telegraph.circle(p, 0.62, PRISON_WARN, _pillar.bind(p, source, pillars), 0.5 if marks == 1 else 0.0))
		Sfx.play("crystal_rise", 0.35, 1.3 + marks * 0.02)
		await _wait(PRISON_STEP)
	await _wait(PRISON_WARN + 0.35)
	if not _alive():
		return
	track(Telegraph.circle(c, PRISON_R - 0.35, 0.85, _shut.bind(c, source, pillars)))
	await _wait(1.2)


func _pillar(spot: Vector3, source: String, pillars: Array) -> void:
	if not _alive():
		return
	var hero := Game.hero
	if hero and hero.can_be_hit():
		var d := hero.global_position - spot
		d.y = 0.0
		if d.length() < 0.62 + hero.radius * 0.5:
			Game.hit_source = source
			hero.take_damage(PILLAR_DAMAGE, d if d.length() > 0.05 else Vector3.BACK, 4.0)
	var s := CrystalSpire.raise(spot, source, PRISON_WARN + PRISON_N * PRISON_STEP + 4.0, 0, 1.3)   # (review fix 1: never forever, so a cancelled prison can't seal the hero in)
	if s:
		pillars.append(s)
	Fx.dust(spot, 10)
	Sfx.play("crystal_rise", 0.5, randf_range(1.0, 1.15))
	Game.shake(0.06)


## The prison bursts inwards: everyone still inside is struck.
func _shut(c: Vector3, source: String, pillars: Array) -> void:
	Sfx.play("shatter", 1.0, 0.7)
	Game.shake(0.4)
	Fx.shockwave(c, AMETHYST, PRISON_R)
	Fx._burst(c + Vector3.UP * 0.8, 40, Color(0.8, 0.55, 1.0, 0.9), 0.4, 5.0, 0.7, 8.0)
	for s in pillars:
		if is_instance_valid(s):
			(s as CrystalSpire).burst(false)
	var hero := Game.hero
	if hero and hero.can_be_hit():
		var d := hero.global_position - c
		d.y = 0.0
		if d.length() < PRISON_R - 0.35 + hero.radius * 0.5:
			Game.hit_source = source
			hero.take_damage(PRISON_DAMAGE, d if d.length() > 0.05 else Vector3.BACK, 6.0)


# Phase 2 ---------------------------------------------------------------------------------------

## Two Geode Guards climb out of the rock beside it (after its roar).
func _raise_guards() -> void:
	await _wait(1.0)
	for i in 2:
		if not _alive() or Game.alive_enemies >= 6:
			return
		var spot := _open_spot(global_transform.basis.x * (1.0 if i == 0 else -1.0))
		Fx.dust(spot, 20)
		Fx._burst(spot + Vector3.UP * 0.3, 18, Color(0.78, 0.5, 1.0, 0.8), 0.4, 2.6, 0.7, 5.0)
		Sfx.play("crystal_rise", 0.5, 0.9)
		Game.spawn_enemy("z", spot)
		await _wait(0.3)


## Open floor about three metres from it, `side` first (clear of pillars, spires and walls,
## so a Geode Guard climbing out there is never wedged).
func _open_spot(side: Vector3) -> Vector3:
	var room := Room.current
	var base := atan2(side.z, side.x)
	for k in 12:
		var a := base + int((k + 1) / 2.0) * (TAU / 12.0) * (1.0 if k % 2 == 0 else -1.0)
		var p := global_position + Vector3(cos(a), 0.0, sin(a)) * 3.0
		p.y = 0.0
		if room == null or room.is_walkable(p, 1.3):
			return p
	return _in_room(global_position + side * 3.0, 0.7)


func _clear_all() -> void:
	_clear_carts()
	_clear_rings()
	_drop_geode()


func _exit_tree() -> void:
	_clear_all()
	super._exit_tree()


func _on_death() -> void:
	_clear_all()
	CrystalSpire.break_all()
	Sfx.play(roar_sound, 0.8, 0.85)
	Sfx.play("shatter", 1.0, 0.65)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	for n: Node3D in [_crown, _ridge, _fist]:
		if n:
			var tw := n.create_tween()
			tw.tween_property(n, "scale", n.scale * 1.4, 0.2)
			tw.tween_property(n, "scale", Vector3.ZERO, 0.35)
	Fx._burst(center(), 60, Color(0.8, 0.55, 1.0, 0.9), 0.45, 5.0, 1.0, 6.0)
	Fx.magic(center(), PALE, 40)
	Fx.shockwave(global_position, AMETHYST, 5.5)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
