class_name TombMummy
extends Enemy
## The Sandfall Tomb's own skeleton (floor 5, version 273; hard review of build 267, fix 3, the
## last of the new places). Until then the Tomb borrowed the Frozen Ossuary's Frost Wraiths
## and the Ember Catacomb's Cinder Skeletons, one a room.
##
## A skeleton wound in old linen from skull to toe, strips torn away here and there to the
## bone and loose ends trailing, a gold circlet on its brow, a broad collar of turquoise and
## gold on its shoulders, a glowing turquoise scarab on its chest and a roll of bandage in its
## hand. It shambles after you and throws the loose end
## of its bandage: a strip on the floor shows where (the warning), then the bandage lashes
## out along it. Step off the strip. If it catches you, the bandage holds you on a leash that
## it reels in, and when it has you close it strikes. Dash to snap the bandage: it tears, and
## the mummy staggers back.

enum Mode { APPROACH, AIM, LASH, REEL, STAGGER }

const LINEN := Color(0.76, 0.68, 0.54)
const TURQUOISE := Color(0.3, 0.95, 0.85)
const GOLD := Color(1.0, 0.76, 0.3)
const LAPIS := Color(0.1, 0.2, 0.58)
const AIM_TIME := 0.8
const LASH_LEN := 8.0
const LASH_WIDTH := 1.0
const LASH_SPEED := 17.0
## How fast it reels the leash in (metres a second), how long it can hold on, and how close
## it reels you before it strikes.
const REEL_SPEED := 3.0
const REEL_TIME := 2.6
const GRAB := 1.5
const STRIKE := 12.0
const STAGGER_TIME := 1.1

static var _meshes := {}
static var _said := -100000

var mode := Mode.APPROACH
var _timer := randf_range(1.6, 2.6)
var _left := 0.0
var _dir := Vector3.FORWARD
var _from := Vector3.ZERO   # where the lash was thrown from
var _reach := 0.0           # how far out the bandage's end is
var _back := false          # pulling a missed lash back in
var _leash := 0.0
var _t := 0.0
var _roll: Node3D
var _rope: MeshInstance3D
var _knot: MeshInstance3D
var _tails: Array[Node3D] = []
var _torn := -1.0          # the snapped bandage falling: its seconds so far
var _tear := Vector3.ZERO  # where it tore


func _setup() -> void:
	die_sound = "die_mummy"
	init_health(42.0)
	move_speed = 1.6
	contact_damage = 8.0
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_ROGUE, 2.05, TURQUOISE)
	look.hide = ["Skeleton_Rogue_Hood", "Skeleton_Rogue_Cape"]
	look.overlay = _wrapped_bones()
	look.attack_anim = "1H_Melee_Attack_Chop"
	# Version 343 (visual review fix 7): a mummy's walk: bent forward, arms out in front,
	# long linen ends hanging from its wrists.
	look.shape = {"scale": {"upperarm.l": 1.15, "upperarm.r": 1.15, "upperleg.l": 0.9, "upperleg.r": 0.9},
		"turn": {"spine": Vector3(20, 0, 0), "head": Vector3(-14, 0, 6)},
		"aim": {"upperarm.l": Vector3(-70, 0, 0), "upperarm.r": Vector3(-70, 0, 0)}}
	look.parts = "linen"
	make_visual(look)
	_dress()


func display_name() -> String:
	return "Tomb Mummy"


## Holding the hero on its bandage right now (the test robot dashes to snap it).
func holding() -> bool:
	return mode == Mode.REEL and not dead


# --- How it looks ----------------------------------------------------------------------------

## Strips of old linen wound round and round the bones (the skull too), a little slanted,
## each strip its own shade, thin seams between them, a few stains of resin, and here and
## there a strip torn away to the bone. One see-through pass (see HushKeeper._script_bones for
## why), lit so the wraps keep their shape.
static func _wrapped_bones() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode depth_draw_never, cull_back;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	float wind = lp.y * 12.0 + (lp.x * 0.9 - lp.z * 0.55) * 3.0;
	float band = floor(wind);
	float fr = fract(wind);
	float seam = 1.0 - smoothstep(0.0, 0.06, fr) * (1.0 - smoothstep(0.9, 0.98, fr));
	float ang = atan(lp.z, lp.x);
	float torn = step(0.86, hash(vec2(band, floor(ang * 1.6 + band * 0.7))));
	float stain = smoothstep(0.65, 0.98, hash(floor(lp.xz * 6.0) + band * 0.13));
	// (Version 367: aged, darker linen with inked edges; the bright wraps blew out white.)
	vec3 linen = vec3(0.8, 0.72, 0.57) * (0.88 + 0.12 * hash(vec2(band, 1.0)));
	linen = mix(linen, vec3(0.62, 0.5, 0.34), stain * 0.4);
	vec3 col = mix(linen, vec3(0.36, 0.27, 0.18), seam * 0.7);
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(edge, 2.6);
	col *= 1.0 - 0.5 * smoothstep(0.5, 0.95, edge);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	EMISSION = vec3(0.3, 0.95, 0.85) * rim * 0.3;
	ALPHA = (1.0 - torn) * 0.97;
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
			"gold": _meshes[k] = U.mat(GOLD, 0.3, 0.25)
			"turquoise": _meshes[k] = U.mat(TURQUOISE, 0.35, 0.9)
			"lapis": _meshes[k] = U.mat(LAPIS, 0.4, 0.15)
			"linen": _meshes[k] = U.mat(LINEN, 0.95, 0.1)
			"eye": _meshes[k] = U.unlit(Color(0.55, 1.0, 0.92))
			"glow":
				var g := U.unlit(Color(TURQUOISE.r, TURQUOISE.g, TURQUOISE.b, 0.55), U.soft_circle(), true).duplicate()
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_meshes[k] = g
			"rope":
				# The thrown bandage: linen with seams across it and a glowing turquoise edge
				# (the curse in it), so it reads over any floor.
				var sh := Shader.new()
				sh.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float f = fract(UV.y);
	float seam = smoothstep(0.8, 0.9, f) * (1.0 - smoothstep(0.92, 1.0, f));
	float edge = smoothstep(0.34, 0.48, abs(UV.x - 0.5));
	ALBEDO = mix(vec3(0.9, 0.86, 0.74), vec3(0.3, 0.22, 0.14), seam * 0.75);
	ROUGHNESS = 0.9;
	EMISSION = vec3(0.3, 0.95, 0.85) * (edge * 1.4 + 0.12);
}
"""
				var m := ShaderMaterial.new()
				m.shader = sh
				_meshes[k] = m
	return _meshes[k]


## A gold circlet round the wrapped skull (head-bone space, +Z the face), with a turquoise
## scarab on the brow.
static func _circlet_mesh() -> ArrayMesh:
	if _meshes.has("circlet"):
		return _meshes["circlet"]
	var parts := []
	var band := TorusMesh.new()
	band.inner_radius = 0.5
	band.outer_radius = 0.58
	band.rings = 20
	band.ring_segments = 6
	parts.append([band, Props._xf(Vector3.ZERO, Vector3(1.0, 0.8, 1.02)), _mat("gold")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.04, 0.58), Vector3(0.1, 0.12, 0.06)), _mat("turquoise")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.15, 0.56), Vector3(0.05, 0.045, 0.04)), _mat("gold")])
	for sd in [-1.0, 1.0]:
		parts.append([Props._sphere(), Props._xf(Vector3(sd * 0.1, 0.02, 0.56), Vector3(0.07, 0.03, 0.03), Basis(Vector3.BACK, sd * 0.5)), _mat("gold")])
	_meshes["circlet"] = Props._bake(parts)
	return _meshes["circlet"]


## A big scarab of turquoise in a gold setting, its wings spread (lying in XZ, its head to -Z).
static func _scarab_mesh() -> ArrayMesh:
	if _meshes.has("scarab"):
		return _meshes["scarab"]
	var parts := []
	var sp := Props._sphere()
	parts.append([sp, Props._xf(Vector3(0, 0, 0.02), Vector3(0.15, 0.06, 0.19)), _mat("turquoise")])
	parts.append([sp, Props._xf(Vector3(0, 0.01, -0.17), Vector3(0.08, 0.05, 0.06)), _mat("turquoise")])
	parts.append([Props._cube(), Props._xf(Vector3(0, 0.05, 0.02), Vector3(0.012, 0.02, 0.3)), _mat("gold")])
	for sd in [-1.0, 1.0]:
		# Spread wings of gold.
		var wing := [Vector2(0.0, -0.06), Vector2(0.34, -0.16), Vector2(0.4, -0.08), Vector2(0.3, 0.05), Vector2(0.0, 0.08)]
		var pts := []
		for p: Vector2 in wing:
			pts.append(Vector2(p.x * sd, p.y))
		parts.append([Props._poly_slab(pts, -0.012, 0.012), Transform3D(Basis.IDENTITY, Vector3(sd * 0.08, -0.01, 0)), _mat("gold")])
	parts.append([Props._cone(0.21, 0.23, 0.03, 18), Props._xf(Vector3(0, -0.03, 0), Vector3(1.0, 1.0, 1.1)), _mat("gold")])
	_meshes["scarab"] = Props._bake(parts)
	return _meshes["scarab"]


## The broad collar, lying round the neck on the shoulders (chest-bone space): rings of gold,
## turquoise and lapis, and a fringe of gold drops round its edge.
static func _collar_mesh() -> ArrayMesh:
	if _meshes.has("collar"):
		return _meshes["collar"]
	var parts := []
	var rings := [[0.18, 0.27, "gold"], [0.27, 0.36, "turquoise"], [0.36, 0.43, "lapis"], [0.43, 0.5, "turquoise"]]
	for r in rings:
		var t := TorusMesh.new()
		t.inner_radius = r[0]
		t.outer_radius = r[1]
		t.rings = 22
		t.ring_segments = 5
		parts.append([t, Props._xf(Vector3.ZERO, Vector3(1.0, 0.35, 0.82)), _mat(r[2])])
	for i in 12:
		var a := i * TAU / 12.0
		parts.append([Props._sphere(), Props._xf(Vector3(cos(a) * 0.53, -0.02, sin(a) * 0.53 * 0.82), Vector3(0.045, 0.06, 0.045)), _mat("gold")])
	_meshes["collar"] = Props._bake(parts)
	return _meshes["collar"]


## A roll of bandage, held across the hand, its loose end hanging.
static func _roll_mesh() -> ArrayMesh:
	if _meshes.has("roll"):
		return _meshes["roll"]
	var parts := []
	var side := Basis(Vector3.FORWARD, PI * 0.5)
	parts.append([Props._cone(0.11, 0.11, 0.22, 12), Transform3D(side, Vector3.ZERO), _mat("linen")])
	parts.append([Props._cone(0.04, 0.04, 0.23, 8), Transform3D(side, Vector3.ZERO), _mat("gold")])
	parts.append([Props._cube(), Props._xf(Vector3(0.02, -0.2, 0.1), Vector3(0.15, 0.34, 0.012)), _mat("linen")])
	_meshes["roll"] = Props._bake(parts)
	return _meshes["roll"]


## A loose strip of linen trailing from the body, swaying (its top at the origin, hanging
## down -Y).
static func _tail_mesh() -> ArrayMesh:
	if _meshes.has("tail"):
		return _meshes["tail"]
	var parts := []
	var poly := [Vector2(-0.06, 0.0), Vector2(0.06, 0.0), Vector2(0.07, -0.7), Vector2(0.0, -0.8), Vector2(-0.05, -0.64)]
	parts.append([Props._poly_slab(poly, -0.01, 0.01), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), _mat("linen")])
	_meshes["tail"] = Props._bake(parts)
	return _meshes["tail"]


func _add_tail(parent: Node3D, at: Vector3, length: float) -> void:
	var tail := Node3D.new()
	tail.position = at
	parent.add_child(tail)
	var tm := MeshInstance3D.new()
	tm.mesh = _tail_mesh()
	tm.scale = Vector3(1.0, length, 1.0)
	tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tail.add_child(tm)
	_tails.append(tail)


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel and skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		var circlet := MeshInstance3D.new()
		circlet.mesh = _circlet_mesh()
		circlet.position = Vector3(0, 0.6, 0.02)
		circlet.rotation.x = -0.12
		head.add_child(circlet)
		# Its eyes, two turquoise lights deep in the wrappings.
		for sx in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			eye.mesh = Props._sphere()
			eye.material_override = _mat("eye")
			eye.scale = Vector3.ONE * 0.06
			eye.position = Vector3(sx * 0.14, 0.42, 0.38)
			eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			head.add_child(eye)
		# A loose end of the wrappings trailing from the back of the skull.
		_add_tail(head, Vector3(0.12, 0.7, -0.35), 1.2)
	if skel and skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		var collar := MeshInstance3D.new()
		collar.mesh = _collar_mesh()
		collar.position = Vector3(0, 0.26, 0.04)
		collar.rotation.x = 0.42
		collar.scale = Vector3(1.2, 1.0, 1.1)
		chest.add_child(collar)
		# The scarab on its chest, tipped up to face the camera above the hero.
		var scarab := MeshInstance3D.new()
		scarab.mesh = _scarab_mesh()
		scarab.position = Vector3(0, 0.0, 0.36)
		scarab.rotation.x = PI * 0.5 - 0.75
		scarab.scale = Vector3.ONE * 1.1
		chest.add_child(scarab)
		var glow := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(0.9, 0.9)
		glow.mesh = gq
		glow.material_override = _mat("glow")
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = Vector3(0, 0.0, 0.42)
		glow.rotation.x = -0.75
		chest.add_child(glow)
	# Loose ends trailing from its hips.
	_add_tail(visual, Vector3(-0.3, 1.0, -0.18), 1.0)
	_add_tail(visual, Vector3(0.28, 0.95, 0.05), 0.85)
	if skel and skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		_roll = Node3D.new()
		hand.add_child(_roll)
		var r := MeshInstance3D.new()
		r.mesh = _roll_mesh()
		_roll.add_child(r)
		# A scrap of the thrown bandage's own material inside the roll, too small to see, so its
		# shader is ready (warm-up) before the first throw.
		var scrap := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(0.02, 0.02)
		scrap.mesh = sq
		scrap.material_override = _mat("rope")
		scrap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_roll.add_child(scrap)
	# The thrown bandage, drawn in the room's space each frame.
	_rope = MeshInstance3D.new()
	_rope.mesh = ImmediateMesh.new()
	_rope.top_level = true
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rope.extra_cull_margin = 16.0
	add_child(_rope)
	_knot = MeshInstance3D.new()
	_knot.mesh = Props._sphere()
	_knot.material_override = _mat("linen")
	_knot.scale = Vector3(0.2, 0.14, 0.2)
	_knot.top_level = true
	_knot.visible = false
	add_child(_knot)


func _hand() -> Vector3:
	return _roll.global_position if is_instance_valid(_roll) else center()


## Draws the bandage from `a` to `b` as a ribbon lying flat to the camera above, sagging and
## rippling, twisting a little along its length.
func _draw_rope(a: Vector3, b: Vector3, slack: float) -> void:
	TombMummy.ribbon(_rope.mesh as ImmediateMesh, a, b, slack, _t)


## The bandage ribbon itself (the Sand Pharaoh throws them too): `t` drives its ripple.
static func ribbon(im: ImmediateMesh, a: Vector3, b: Vector3, slack: float, t: float, half_width := 0.15) -> void:
	im.clear_surfaces()
	var axis := b - a
	var length := axis.length()
	if length < 0.05:
		return
	var side := axis.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var n := 16
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat("rope"))
	for i in n + 1:
		var k := float(i) / n
		var p := a.lerp(b, k)
		p.y -= slack * 4.0 * k * (1.0 - k)
		p += side * sin(k * PI * 3.0 - t * 9.0) * 0.08 * (1.0 - k * 0.6)
		var w := side.rotated(axis / length, sin(k * 5.0 + t * 2.0) * 0.2) * half_width
		im.surface_set_normal(Vector3.UP)
		im.surface_set_uv(Vector2(0.0, k * length / 0.32))
		im.surface_add_vertex(p - w)
		im.surface_set_normal(Vector3.UP)
		im.surface_set_uv(Vector2(1.0, k * length / 0.32))
		im.surface_add_vertex(p + w)
	im.surface_end()


func _clear_rope() -> void:
	if _rope:
		(_rope.mesh as ImmediateMesh).clear_surfaces()
	if _knot:
		_knot.visible = false


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	if dead:
		return
	for i in _tails.size():
		_tails[i].rotation.x = 0.25 + sin(_t * 2.3 + i * 1.7) * 0.18
		_tails[i].rotation.z = sin(_t * 1.7 + i) * 0.12
	if is_instance_valid(_roll):
		# The roll turns as it pays out or reels in.
		var spin := 0.0
		if mode == Mode.AIM:
			spin = 4.0
		elif mode == Mode.LASH:
			spin = -14.0 if not _back else 14.0
		elif mode == Mode.REEL:
			spin = 10.0
		_roll.rotation.x += spin * delta
	match mode:
		Mode.LASH:
			_lash_tick(delta)
		Mode.REEL:
			_reel_tick(delta)
	if _torn >= 0.0:
		_torn_tick(delta)


# --- How it fights ---------------------------------------------------------------------------

func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	match mode:
		Mode.AIM:
			stand(delta)
			face(_dir, 20.0, delta)
			_left -= delta
			if _left <= 0.0:
				_throw()
		Mode.LASH:
			stand(delta)
			face(_dir, 20.0, delta)
		Mode.REEL:
			stand(delta)
			face(to, 10.0, delta)
		Mode.STAGGER:
			stand(delta)
			_left -= delta
			if _left <= 0.0:
				mode = Mode.APPROACH
				_timer = randf_range(2.2, 3.0)
		_:
			if to.length() > 2.2:
				walk(to, delta)
			else:
				stand(delta)
				face(to, 8.0, delta)
			_timer -= delta
			var d := to.length()
			if _timer <= 0.0 and d > 2.8 and d < LASH_LEN - 0.6 and hero.can_be_hit() \
					and (Room.current == null or Room.current.clear_shot(global_position, hero.global_position)):
				_aim(to)


## Raises the roll: the strip on the floor where the bandage will lash out.
func _aim(to: Vector3) -> void:
	mode = Mode.AIM
	_left = AIM_TIME
	_dir = to.normalized()
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	track(Telegraph.line(global_position, _dir, LASH_LEN, LASH_WIDTH, AIM_TIME, Callable()))
	if is_instance_valid(_roll):
		Fx.magic(_hand(), TURQUOISE, 6)


## Throws the loose end of the bandage along the strip.
func _throw() -> void:
	mode = Mode.LASH
	_back = false
	_reach = 0.4
	_from = global_position + Vector3.UP * 1.0
	if not visual.play_named("1H_Ranged_Shoot"):
		visual.attack(true)
	Sfx.play("lash", 0.7, randf_range(0.95, 1.08))


func _lash_tick(delta: float) -> void:
	var hero := Game.hero
	if _back:
		_reach -= LASH_SPEED * 1.4 * delta
		if _reach <= 0.4:
			_clear_rope()
			mode = Mode.APPROACH
			_timer = randf_range(3.8, 4.8)
			return
	else:
		var was := _reach
		_reach = minf(_reach + LASH_SPEED * delta, LASH_LEN)
		var end := _from + _dir * _reach
		if _reach >= LASH_LEN or (Room.current and Room.current.blocks_shot(end, 0.15)):
			_back = true
		elif hero and not hero.dead and Game.state == Game.State.PLAYING:
			# Caught along the stretch the end crossed this frame.
			var h := hero.global_position
			var rel := Vector3(h.x - _from.x, 0.0, h.z - _from.z)
			var along := rel.dot(_dir)
			var across := (rel - _dir * along).length()
			if along > was - hero.radius and along < _reach + hero.radius and across < LASH_WIDTH * 0.5 + hero.radius * 0.6:
				if hero.blocks_shot(_dir):
					hero.on_block(end)
					_back = true
				elif hero.can_be_hit():
					_catch(hero)
					return
	var tip := _from + _dir * _reach
	_draw_rope(_hand(), tip, 0.25)
	_knot.visible = true
	_knot.global_position = tip
	_knot.rotation.y += delta * 9.0


## Caught: the bandage wraps round the hero, and the leash is as long as the gap between them.
func _catch(hero: Hero) -> void:
	mode = Mode.REEL
	_left = REEL_TIME
	_knot.visible = false
	var d := hero.global_position - global_position
	d.y = 0.0
	_leash = maxf(d.length(), GRAB)
	Game.hit_source = "Tomb Mummy"
	hero.take_damage(4.0 * elite_mult(), _dir, 0.0)
	Fx.magic(hero.global_position + Vector3.UP * 0.9, TURQUOISE, 12)
	Sfx.play("lash", 0.6, 0.75)
	if Time.get_ticks_msec() - _said > 3000:
		_said = Time.get_ticks_msec()
		Game.hud.status_at_hero("CAUGHT! DASH TO SNAP IT!", TURQUOISE)


## Reels the leash in. A dash snaps it; close enough, it strikes.
func _reel_tick(delta: float) -> void:
	var hero := Game.hero
	if hero == null or hero.dead or Game.state != Game.State.PLAYING:
		_let_go()
		return
	if hero.is_dashing():
		_snap(hero)
		return
	_left -= delta
	if _left <= 0.0:
		_let_go()
		return
	_leash = maxf(GRAB, _leash - REEL_SPEED * delta)
	var d := hero.global_position - global_position
	d.y = 0.0
	var dist := d.length()
	if dist > _leash and dist > 0.01:
		var step := -d / dist * (dist - _leash)
		hero.global_position = Room.current.resolve_move(hero.global_position, step, hero.radius) if is_instance_valid(Room.current) else hero.global_position + step
		dist = _leash
	if dist <= GRAB + 0.1:
		_strike(hero)
		return
	_draw_rope(_hand(), hero.global_position + Vector3.UP * 0.8, 0.05)


## Close enough: it strikes, and lets the bandage drop.
func _strike(hero: Hero) -> void:
	var d := hero.global_position - global_position
	d.y = 0.0
	face(d, 40.0, 0.1)
	visual.attack(true)
	Game.hit_source = "Tomb Mummy"
	hero.take_damage(STRIKE * elite_mult(), d.normalized() if d.length() > 0.01 else _dir, 7.0)
	Sfx.play("lash", 0.5, 0.65)
	_clear_rope()
	mode = Mode.APPROACH
	_timer = randf_range(3.6, 4.4)


## The hero dashed: the bandage tears, and the mummy staggers back.
func _snap(hero: Hero) -> void:
	var mid := (_hand() + hero.global_position + Vector3.UP * 0.8) * 0.5
	Fx.impact(mid, TURQUOISE, 0.8)
	Fx.magic(mid, LINEN, 22)
	Fx.magic(mid, TURQUOISE, 10)
	Sfx.play("snap", 0.8, randf_range(0.94, 1.06))
	_clear_rope()
	_torn = 0.0
	_tear = mid
	_knot.visible = true
	_knot.global_position = mid
	mode = Mode.STAGGER
	_left = STAGGER_TIME
	if not visual.play_named("Hit_A"):
		_flinch_left = 0.4
	Game._teach("mummy_snap", "SNAPPED! A dash tears a Tomb Mummy's bandage.")


## The torn end of the bandage drops and is pulled back to the roll, while the other end
## flutters to the floor.
func _torn_tick(delta: float) -> void:
	_torn += delta
	var k := _torn / 0.45
	if k >= 1.0 or dead:
		_torn = -1.0
		_clear_rope()
		return
	var end := _tear.lerp(_hand(), k * k)
	end.y = lerpf(_tear.y, 0.1, minf(k * 1.6, 1.0))
	_draw_rope(_hand(), end, 0.4 * (1.0 - k))
	_knot.global_position = Vector3(_tear.x, maxf(_tear.y - 9.0 * _torn * _torn, 0.06), _tear.z)
	_knot.rotation.z += delta * 12.0


## Held too long, or the room changed: the bandage slips off.
func _let_go() -> void:
	_clear_rope()
	mode = Mode.APPROACH
	_timer = randf_range(3.0, 4.0)


func _on_death() -> void:
	super._on_death()
	_clear_rope()
	Fx.dust(global_position, 18)
	Fx.magic(center(), LINEN, 14)
	Fx.magic(center(), TURQUOISE, 8)
