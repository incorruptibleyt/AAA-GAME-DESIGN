class_name VoidWalker
extends Enemy
## The Starfall Abyss's own skeleton (floor 10, version 269; hard review of build 267, fix 3).
## Until then the Abyss borrowed the Grotto's Sporelings and Rootbinders.
##
## A thin skeleton of night-sky bone, like the Star Eater's, in a cape of stars, carrying a
## crescent-moon blade. It walks the edge of the void and steps through it: it sinks into a
## rift at its feet, a second rift opens on the floor right next to you (the warning), and a
## second later it rises out of that rift swinging its blade. Walk or dash away from the new
## rift. Walls and cover don't stop it, so hiding behind a pillar is no answer to it. While it
## is in the void it can't be hit.

const SINK := 0.45       # seconds to sink into the rift
const WARN := 1.0        # seconds the exit rift shows before it steps out
const REACH := 1.6       # how far its swing reaches from the exit rift
const SKY := Color(0.62, 0.72, 1.0)

static var _meshes := {}

var _timer := randf_range(2.2, 3.4)
var _mode := "walk"      # walk, sink, void, rise
var _left := 0.0
var _depth := 0.0        # how far the model has sunk into the floor
var _contact := 0.0
var _rift_in: Node3D
var _rift_out: Node3D
var _orbit: Node3D
var _float := randf() * TAU


func _setup() -> void:
	die_sound = "die_void"
	init_health(46.0)
	move_speed = 2.3
	contact_damage = 9.0
	_contact = contact_damage
	radius = 0.5
	center_height = 1.0
	var look := bones(Art.SKELETON_WARRIOR, 2.15, SKY)
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Cloak"]
	look.overlay = _overlay()
	# Version 344 (visual review fix 7): a gaunt spectre: no legs, a tail of the void
	# trailing under it, long thin arms, floating.
	look.height = 2.4
	look.shape = {"scale": {"chest": 0.85, "head": 0.95, "upperarm.l": 1.45, "upperarm.r": 1.45}, "lift": 0.3,
		"turn": {"spine": Vector3(10, 0, 0)}}
	look.parts = "voidtail"
	make_visual(look)
	# Version 405 (re-review of v400, fix 5): a light rim round its dark void body, which was a black
	# blob on the dark floors (its face and arms didn't read).
	visual.set_rim(Color(1.1, 1.2, 1.5, 1.0), 1.15)
	_dress()


func display_name() -> String:
	return "Void Walker"


# --- How it looks ----------------------------------------------------------------------------

static func _mat(key: String) -> Material:
	var k := "void_walker_" + key
	if not _meshes.has(k):
		match key:
			"blade": _meshes[k] = U.mat(Color(0.85, 0.9, 1.0), 0.25, 1.3)
			"edge": _meshes[k] = U.mat(Color(0.55, 0.7, 1.0), 0.2, 2.2)
			"grip": _meshes[k] = U.mat(Color(0.2, 0.2, 0.35), 0.6)
			"star": _meshes[k] = U.unlit(Color(0.9, 0.94, 1.0))
	return _meshes[k]


## Its bones are night sky like the Star Eater's, but lighter and bluer with a bright edge,
## so a small one still stands out from above on the Abyss's dark star gate.
static func _overlay() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
void fragment() {
	ALBEDO = vec3(0.5, 0.55, 0.92);
}
"""
	var glow := Shader.new()
	glow.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
varying vec3 lp;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec3 q = lp * 9.0;
	float h = hash(floor(q));
	float d = length(fract(q) - 0.5);
	float s = step(0.78, h) * smoothstep(0.2, 0.0, d) * (0.5 + 0.5 * sin(TIME * 3.0 + h * 50.0));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = vec3(0.06, 0.08, 0.22) + vec3(0.85, 0.9, 1.0) * s * 1.4 + vec3(0.45, 0.6, 1.0) * rim * 1.3;
}
"""
	var m := ShaderMaterial.new()
	m.shader = dark
	var f := ShaderMaterial.new()
	f.shader = glow
	m.next_pass = f
	_meshes["overlay"] = m
	return m


## A crescent moon, lying flat, opening along +X.
static func _crescent() -> Array:
	var poly := []
	var n := 12
	for i in n + 1:   # the outer edge of the crescent
		var a := -PI * 0.55 + PI * 1.1 * i / n
		poly.append(Vector2(cos(a) * 0.62, sin(a) * 0.62))
	for i in n + 1:   # the inner edge, back the other way, from a circle moved out
		var a := PI * 0.5 - PI * 1.0 * i / n
		poly.append(Vector2(0.24 + cos(a) * 0.5, sin(a) * 0.5))
	return poly


## A crescent moon on a short grip: the blade it swings (in the hand slot, pointing up).
static func _blade_mesh() -> ArrayMesh:
	if _meshes.has("blade"):
		return _meshes["blade"]
	var poly := _crescent()
	var parts := []
	# Lying flat the crescent opens along +X; stood up (x stays, z goes up) it is a blade
	# curving round in front of the hand.
	var up := Basis(Vector3.RIGHT, -PI * 0.5)
	parts.append([Props._poly_slab(poly, -0.03, 0.03), Transform3D(up, Vector3(-0.3, 0.75, 0)), _mat("blade")])
	parts.append([Props._cone(0.035, 0.035, 0.55, 6), Props._xf(Vector3(0, 0.25, 0), Vector3.ONE), _mat("grip")])
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.0, 0), Vector3.ONE * 0.06), _mat("edge")])
	_meshes["blade"] = Props._bake(parts)
	return _meshes["blade"]


## The crescent over its head: horns up, facing forward.
static func _halo_mesh() -> ArrayMesh:
	if _meshes.has("halo"):
		return _meshes["halo"]
	# Lying flat it opens along +X; turned so it opens upward and stood up facing forward.
	var b := Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5)
	var parts := [[Props._poly_slab(_crescent(), -0.035, 0.035), Transform3D(b * Basis.from_scale(Vector3.ONE * 0.62), Vector3.ZERO), _mat("edge")]]
	_meshes["halo"] = Props._bake(parts)
	return _meshes["halo"]


## A ragged cape of night sky hanging from its shoulders.
static func _cape_mesh() -> ArrayMesh:
	if _meshes.has("cape"):
		return _meshes["cape"]
	var poly := [Vector2(-0.3, 0.05), Vector2(0.3, 0.05)]
	var pts := 7
	for i in pts + 1:   # the hem, right to left, every other point hanging lower
		var x := 0.5 - 1.0 * i / pts
		poly.append(Vector2(x, -1.05 if i % 2 == 0 else -0.85))
	var flat := Props._poly_slab(poly, -0.02, 0.02)
	_meshes["cape"] = flat
	return flat


## A rift in the floor: a disc of night sky with a pale rim.
static func _rift_mesh() -> CylinderMesh:
	if not _meshes.has("rift"):
		var c := CylinderMesh.new()
		c.top_radius = 0.95
		c.bottom_radius = 0.95
		c.height = 0.02
		c.radial_segments = 24
		c.rings = 1
		_meshes["rift"] = c
	return _meshes["rift"]


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		var cape := MeshInstance3D.new()
		cape.mesh = _cape_mesh()
		cape.material_override = StarEater._sky_mat()
		# Stood up behind the back, hem down (lying flat, -Y of the polygon is the hem).
		cape.transform = Transform3D(Basis(Vector3.RIGHT, 0.18) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.4, -0.24))
		chest.add_child(cape)
	if skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var blade := MeshInstance3D.new()
		blade.mesh = _blade_mesh()
		hand.add_child(blade)
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		# A pale crescent moon floating over its skull, horns up: the shape that tells it
		# apart from above.
		var moon := MeshInstance3D.new()
		moon.mesh = _halo_mesh()
		moon.position = Vector3(0, 1.5, -0.05)
		moon.rotation.x = -0.75   # tipped back to face the camera above the hero
		head.add_child(moon)
		# Two little stars circling its head.
		_orbit = Node3D.new()
		_orbit.position = Vector3(0, 0.75, 0)
		head.add_child(_orbit)
		for i in 2:
			var s := MeshInstance3D.new()
			s.mesh = StarEater._star_mesh()
			s.material_override = _mat("star")
			s.scale = Vector3.ONE * 0.4
			s.position = Vector3(cos(i * PI) * 0.6, 0.08 * i, sin(i * PI) * 0.6)
			_orbit.add_child(s)


func _rift(at: Vector3) -> Node3D:
	var r := MeshInstance3D.new()
	r.mesh = _rift_mesh()
	r.material_override = StarEater._sky_mat()
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Telegraph._parent().add_child(r)
	r.global_position = at + Vector3.UP * 0.03
	r.scale = Vector3(0.05, 1, 0.05)
	r.create_tween().tween_property(r, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return r


## Shut a rift (it may already be gone: freed with the room).
func _close(r: Variant) -> void:
	if not is_instance_valid(r):
		return
	var n: Node3D = r
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(0.02, 1, 0.02), 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


# --- How it fights ---------------------------------------------------------------------------

## Can't be hit (or aimed at) while it is in the void.
func can_be_hit() -> bool:
	return super.can_be_hit() and _mode != "void" and _depth < 1.2


func _process(delta: float) -> void:
	super._process(delta)
	if dead:
		return
	# Enemy._process puts the model back on the floor each frame; sink it into the rift.
	visual.position.y -= _depth
	_float += delta * 2.0
	if _orbit:
		_orbit.rotation.y += delta * 2.6
		_orbit.position.y = 0.75 + sin(_float) * 0.06


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	match _mode:
		"sink":
			stand(delta)
			_left -= delta
			_depth = lerpf(2.4, 0.0, clampf(_left / SINK, 0.0, 1.0))
			if _left <= 0.0:
				_enter_void(hero)
		"void":
			stand(delta)
		"rise":
			stand(delta)
			face(to, 12.0, delta)
			_left -= delta
			_depth = lerpf(0.0, 2.4, clampf(_left / 0.22, 0.0, 1.0))
			if _left <= 0.0:
				_depth = 0.0
				_mode = "walk"
		_:
			if to.length() > 1.6:
				walk(to, delta)
			else:
				stand(delta)
				face(to, 8.0, delta)
			_timer -= delta
			if _timer <= 0.0 and to.length() > 2.2:
				_sink()


## Into the rift at its feet.
func _sink() -> void:
	_mode = "sink"
	_left = SINK
	contact_damage = 0.0
	_rift_in = _rift(global_position)
	Sfx.play("shimmer", 0.6, 0.6)
	Fx.magic(center(), SKY, 8)


## Gone: a rift opens right next to the hero and it steps out of it a second later.
func _enter_void(hero: Hero) -> void:
	_mode = "void"
	_depth = 2.4
	visual.visible = false
	_close(_rift_in)
	# Beside the hero, on the far side from where it went in (it comes through), turned a
	# little either way, kept inside the room.
	var through := hero.global_position - global_position
	through.y = 0.0
	through = through.normalized() if through.length() > 0.1 else Vector3.FORWARD
	through = through.rotated(Vector3.UP, randf_range(-0.9, 0.9))
	var spot := hero.global_position + through * 1.4
	spot.x = clampf(spot.x, -Room.HALF_W + 0.8, Room.HALF_W - 0.8)
	spot.z = clampf(spot.z, -Room.HALF_L + 0.8, Room.HALF_L - 0.8)
	if Room.current:
		spot = Room.current.resolve_move(spot, Vector3.ZERO, radius)
	spot.y = global_position.y
	_rift_out = _rift(spot)
	Sfx.play("warn", 0.6, 1.3)
	# A bound method, not a lambda: if it is gone before the rift opens, nothing is called.
	track(Telegraph.circle(spot, REACH, WARN, _step_out.bind(spot)))


## Out of the rift, swinging.
func _step_out(spot: Vector3) -> void:
	if dead:
		return
	global_position = spot
	visual.visible = true
	_mode = "rise"
	_left = 0.22
	contact_damage = _contact
	_timer = randf_range(3.6, 4.6)
	_close(_rift_out)
	visual.attack(true)
	Sfx.play("swing", 0.9, 0.8)
	Fx.magic(spot + Vector3.UP * 0.8, SKY, 14)
	Fx.shockwave(spot, SKY, REACH)
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	var d := hero.global_position - spot
	d.y = 0.0
	if d.length() <= REACH + hero.radius * 0.5:
		Game.hit_source = "Void Walker"
		hero.take_damage(12.0, d.normalized() if d.length() > 0.05 else Vector3.FORWARD, 7.0)


func _on_death() -> void:
	super._on_death()
	if _orbit:
		_orbit.visible = false
	_close(_rift_in)
	_close(_rift_out)
	Fx.magic(center(), SKY, 18)


func _exit_tree() -> void:
	for r in [_rift_in, _rift_out]:
		if is_instance_valid(r):
			r.queue_free()
	super._exit_tree()   # Actor: off the list of the living
