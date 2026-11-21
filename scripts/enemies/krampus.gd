class_name Krampus
extends Enemy
## Krampus (version 243): the Frostfall event's own boss (events.gd), at the end of the
## Frostfall run and alone in the Krampus Hunt. A hulking horned demon of dark bone under a
## shaggy mantle of frosted fur, great curling ram horns, chains hung with gold bells across
## his chest, a birch switch in his fist and a sack of stolen gifts on his back (a small
## skull peering out of it). Nothing like the crowned King, the robed Queen or the burning
## Colossus. Every attack has a warning:
## - Chain Whirl: a ring marks how far his chain reaches, then he spins it round himself.
##   Get out of the ring. Angry, a second, wider whirl follows.
## - Chain Lash: a strip runs from him to you; the chain lashes along it and yanks whoever
##   it catches towards him. Step out of the strip.
## - Sack Throw: he hurls his sack at you; it bursts where it lands into Gift Thieves, who
##   run off with gifts (catch them first for snowflakes and coins).
## - Avalanche: he stamps, and snowballs roll down the hall in lanes from the far wall,
##   growing as they go and flattening anything in the way, skeletons too.
## Below half health: Krampusnacht. His eyes burn, the chains whirl twice and lash twice,
## and he calls the Blizzard down on the hall whenever he likes.
## The Krampus Hunt's tiers teach him more: from TIER III the Bell Toll (two rings of frost
## from his chest bells, dash through them), from TIER IV a second avalanche down the lanes
## the first left open, and in WHITEOUT the Blizzard blows every 16 seconds all fight long and
## Krampusnacht comes at 60% health.

const DISPLAY_NAME := "Krampus"
const ICE := Color(0.55, 0.9, 1.0)
const GOLD := Color(1.0, 0.8, 0.35)
const FUR := Color(0.17, 0.11, 0.075)
const WHIRL_R := 4.0
const WHIRL_R2 := 5.6
const LASH_LEN := 11.0
const LASH_W := 1.1

var _enraged := false
var _started := false
var _busy := false
var _storm_t := 8.0
var _chain: Node3D        # the whirling chain, shown only while it spins
var _eye_light: OmniLight3D


## The hunt's tier (the Frostfall run's Krampus fights like tier II).
func _tier() -> int:
	return Game.event_tier if Game.event == "hunt" else 2


func _setup() -> void:
	is_boss = true
	init_health(640.0)
	drop_chance = 0.0
	move_speed = 1.6
	contact_damage = 16.0
	radius = 1.2
	center_height = 1.9
	knockback_scale = 0.05
	var look := bones(Art.SKELETON_WARRIOR, 4.3, ICE)
	look.accent = Color(0.22, 0.14, 0.1)
	look.overlay = _frost_overlay()   # old, dark bone with frost on it
	look.attack_anim = "1H_Melee_Attack_Slice_Diagonal"
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Cloak"]
	make_visual(look)
	visual.scale.x *= 1.18   # hulking: broader than any skeleton
	visual.scale.z *= 1.12
	_dress()


func display_name() -> String:
	return DISPLAY_NAME


# ---------------------------------------------------------------- the look

func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("head") >= 0:
		var head := BoneAttachment3D.new()
		skel.add_child(head)
		head.bone_name = "head"
		var m := MeshInstance3D.new()
		m.mesh = _horns_mesh()
		head.add_child(m)
	if skel.find_bone("chest") >= 0:
		var chest := BoneAttachment3D.new()
		skel.add_child(chest)
		chest.bone_name = "chest"
		var m := MeshInstance3D.new()
		m.mesh = _body_mesh()
		chest.add_child(m)
	for leg in ["lowerleg.l", "lowerleg.r"]:
		if skel.find_bone(leg) >= 0:
			var att := BoneAttachment3D.new()
			skel.add_child(att)
			att.bone_name = leg
			var m := MeshInstance3D.new()
			m.mesh = _leg_mesh()
			att.add_child(m)
	if skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var m := MeshInstance3D.new()
		m.mesh = _switch_mesh()
		hand.add_child(m)
	# The whirling chain, hidden until he spins it (in the hall, not the model, so it keeps
	# its real length whatever his size).
	_chain = Node3D.new()
	_chain.visible = false
	add_child(_chain)
	var links := MeshInstance3D.new()
	links.mesh = _chain_mesh(WHIRL_R)
	links.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chain.add_child(links)


static var _meshes := {}


static func _mat(key: String) -> Material:
	var k := "krampus_" + key
	if not _meshes.has(k):
		match key:
			"horn": _meshes[k] = U.mat(Color(0.2, 0.15, 0.12), 0.55)
			"tip": _meshes[k] = U.mat(Color(0.62, 0.56, 0.46), 0.5)
			"fur": _meshes[k] = U.mat(FUR, 0.95)
			"fur2": _meshes[k] = U.mat(FUR * 1.5, 0.95)
			"frost": _meshes[k] = U.mat(Color(0.82, 0.88, 0.96), 0.6)
			"iron": _meshes[k] = U.mat(Color(0.2, 0.2, 0.23), 0.35)
			"chain": _meshes[k] = U.mat(Color(0.55, 0.6, 0.68), 0.3, 0.6)
			"gold": _meshes[k] = U.mat(GOLD, 0.3, 1.2)
			"sack": _meshes[k] = U.mat(Color(0.4, 0.29, 0.17), 0.95)
			"rope": _meshes[k] = U.mat(Color(0.6, 0.5, 0.3), 0.9)
			"red": _meshes[k] = U.mat(Color(0.65, 0.07, 0.07), 0.6)
			"green": _meshes[k] = U.mat(Color(0.08, 0.36, 0.2), 0.6)
			"bone": _meshes[k] = U.mat(Color(0.86, 0.82, 0.7), 0.85)
			"dark": _meshes[k] = U.mat(Color(0.04, 0.03, 0.04), 1.0)
			"birch": _meshes[k] = U.mat(Color(0.75, 0.72, 0.66), 0.8)
			"tongue": _meshes[k] = U.mat(Color(0.7, 0.12, 0.15), 0.4)
	return _meshes[k]


## A segment from a to b of a cone, `ra` thick at a and `rb` at b.
static func _rod(a: Vector3, b: Vector3, ra: float, rb: float, sides := 7) -> Array:
	var d := b - a
	var c := Props._cone(rb, ra, d.length(), sides)
	var basis := Basis(Quaternion(Vector3.UP, d.normalized())) if d.normalized().cross(Vector3.UP).length() > 0.001 else Basis.IDENTITY
	return [c, Transform3D(basis, (a + b) * 0.5)]


## Two great horns: up and out from the top of the skull, sweeping back and curling round
## in a plane tipped towards the camera, so from above (where the camera sees him) they make
## two big curls either side of the head. Ridged, with pale tips; long goat ears under
## them, a shaggy crest of fur on the skull and a long red tongue.
static func _horns_mesh() -> ArrayMesh:
	if _meshes.has("horns"):
		return _meshes["horns"]
	var parts := []
	const N := 20
	for side in [-1.0, 1.0]:
		var u := Vector3(side * 0.9, 0.45, 0.1).normalized()    # out (and a little up)
		var v := Vector3(0.0, 0.35, -0.94).normalized()           # back
		var c := Vector3(side * 0.78, 1.0, -0.2)
		var pts: Array[Vector3] = []
		for i in N + 1:
			var t := float(i) / N
			var ang := PI + t * 1.3 * TAU
			var r := lerpf(0.5, 0.14, t)
			pts.append(c + (u * cos(ang) + v * sin(ang)) * r + u * 0.18 * t)
		parts.append(_rod(Vector3(side * 0.22, 0.82, 0.02), pts[0], 0.19, 0.18) + [_mat("horn")])
		for i in N:
			var t := float(i) / N
			var ra := lerpf(0.18, 0.035, t)
			var rb := lerpf(0.18, 0.035, t + 1.0 / N)
			parts.append(_rod(pts[i], pts[i + 1], ra, rb) + [_mat("tip" if t > 0.82 else "horn")])
			if i % 2 == 0 and t < 0.82:
				parts.append([Props._sphere(), Props._xf(pts[i], Vector3.ONE * ra * 1.1), _mat("horn")])
		# A long goat ear under each horn.
		parts.append(_rod(Vector3(side * 0.38, 0.52, 0.0), Vector3(side * 0.85, 0.36, 0.08), 0.08, 0.02, 5) + [_mat("fur2")])
	# A shaggy crest of fur over the skull, between the horns.
	var rng := RandomNumberGenerator.new()
	rng.seed = 45
	for i in 9:
		var x := (i - 4) * 0.07
		var base := Vector3(x, 0.84, -0.05 - absf(x) * 0.3)
		parts.append(_rod(base, base + Vector3(x * 0.6, rng.randf_range(0.2, 0.32), -rng.randf_range(0.15, 0.3)), 0.09, 0.01, 5) + [_mat("fur" if i % 2 else "fur2")])
	# A long red tongue lolling from the jaw.
	parts.append(_rod(Vector3(0.0, 0.08, 0.34), Vector3(0.04, -0.32, 0.46), 0.06, 0.035, 6) + [_mat("tongue")])
	_meshes["horns"] = Props._bake(parts)
	return _meshes["horns"]


## The chest: a shaggy mantle of fur over the shoulders with frost on it, a chain across the
## chest hung with gold bells, and the sack on his back with gifts and a little skull in it.
static func _body_mesh() -> ArrayMesh:
	if _meshes.has("body"):
		return _meshes["body"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var parts := []
	# The mantle: two rings of fur tufts pointing out and down.
	for ring in 2:
		var n := 18 if ring == 0 else 14
		var y := 0.42 if ring == 0 else 0.12
		var rr := 0.5 if ring == 0 else 0.56
		for i in n:
			var a := TAU * i / n + ring * 0.2
			var out := Vector3(cos(a), 0, sin(a))
			var base := Vector3(cos(a) * rr * 0.6, y, sin(a) * rr * 0.6 * 0.85)
			var tip := base + out * rng.randf_range(0.32, 0.46) + Vector3(0, -rng.randf_range(0.22, 0.38), 0)
			parts.append(_rod(base, tip, 0.13, 0.01, 5) + [_mat("fur" if i % 3 else "fur2")])
	# Frost lying on the shoulders.
	for side in [-1.0, 1.0]:
		parts.append([Props._sphere(), Props._xf(Vector3(side * 0.34, 0.56, -0.04), Vector3(0.22, 0.07, 0.2)), _mat("frost")])
	# The chain across the chest, shoulder to hip, with three bells.
	var a0 := Vector3(0.42, 0.42, 0.26)
	var a1 := Vector3(-0.38, -0.42, 0.3)
	for i in 11:
		var t := i / 10.0
		var p := a0.lerp(a1, t) + Vector3(0, 0, 0.06 * sin(t * PI))
		var link := TorusMesh.new()
		link.inner_radius = 0.035
		link.outer_radius = 0.065
		link.rings = 8
		link.ring_segments = 5
		var b := Basis(Quaternion(Vector3.UP, (a1 - a0).normalized())) * Basis(Vector3.UP, PI / 2 * (i % 2))
		parts.append([link, Props._xf(p, Vector3(1, 1.6, 1), b), _mat("iron")])
		if i in [3, 6, 9]:
			parts.append([Props._cone(0.03, 0.085, 0.11, 8), Props._xf(p + Vector3(0, -0.12, 0.05), Vector3.ONE), _mat("gold")])
			parts.append([Props._sphere(), Props._xf(p + Vector3(0, -0.18, 0.05), Vector3.ONE * 0.03), _mat("gold")])
	# The sack.
	parts.append([Props._sphere(), Props._xf(Vector3(0, 0.12, -0.62), Vector3(0.5, 0.6, 0.42)), _mat("sack")])
	parts.append([Props._cone(0.06, 0.16, 0.18, 7), Props._xf(Vector3(0, 0.74, -0.66), Vector3.ONE), _mat("sack")])
	parts.append([Props._cone(0.08, 0.08, 0.05, 7), Props._xf(Vector3(0, 0.7, -0.66), Vector3.ONE), _mat("rope")])
	for side in [-1.0, 1.0]:
		parts.append(_rod(Vector3(side * 0.3, 0.45, -0.1), Vector3(side * 0.22, 0.62, -0.58), 0.025, 0.025, 5) + [_mat("rope")])
	# Gifts and a skull poking out of the top.
	parts.append([Props._cube(), Props._xf(Vector3(0.15, 0.86, -0.62), Vector3(0.2, 0.2, 0.2), Basis(Vector3(0.3, 1, 0.2).normalized(), 0.5)), _mat("red")])
	parts.append([Props._cube(), Props._xf(Vector3(0.15, 0.86, -0.62), Vector3(0.05, 0.21, 0.21), Basis(Vector3(0.3, 1, 0.2).normalized(), 0.5)), _mat("gold")])
	parts.append([Props._cube(), Props._xf(Vector3(-0.02, 0.9, -0.74), Vector3(0.16, 0.18, 0.16), Basis(Vector3(1, 0.4, 0).normalized(), 0.4)), _mat("green")])
	parts.append([Props._sphere(), Props._xf(Vector3(-0.17, 0.84, -0.54), Vector3(0.12, 0.11, 0.12)), _mat("bone")])
	for ex in [-0.045, 0.045]:
		parts.append([Props._sphere(), Props._xf(Vector3(-0.17 + ex, 0.86, -0.43), Vector3.ONE * 0.028), _mat("dark")])
	_meshes["body"] = Props._bake(parts)
	return _meshes["body"]


## Shaggy fur round each shin and a black cloven hoof below it: goat's legs.
static func _leg_mesh() -> ArrayMesh:
	if _meshes.has("leg"):
		return _meshes["leg"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var parts := []
	for i in 10:
		var a := TAU * i / 10.0
		var base := Vector3(cos(a) * 0.08, 0.32, sin(a) * 0.08)
		var tip := Vector3(cos(a) * 0.22, rng.randf_range(0.02, 0.12), sin(a) * 0.22)
		parts.append(_rod(base, tip, 0.1, 0.01, 5) + [_mat("fur" if i % 2 else "fur2")])
	parts.append([Props._cone(0.13, 0.16, 0.14, 8), Props._xf(Vector3(0, -0.02, 0.03), Vector3.ONE), _mat("dark")])
	_meshes["leg"] = Props._bake(parts)
	return _meshes["leg"]


## A bundle of birch twigs tied with a red ribbon, held like a club.
static func _switch_mesh() -> ArrayMesh:
	if _meshes.has("switch"):
		return _meshes["switch"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var parts := []
	for i in 9:
		var a := TAU * i / 9.0
		var spread := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.08, 0.16)
		parts.append(_rod(Vector3(cos(a) * 0.025, -0.15, sin(a) * 0.025), spread + Vector3(0, 1.05 + rng.randf_range(-0.12, 0.1), 0), 0.018, 0.006, 4) + [_mat("birch")])
	parts.append([Props._cone(0.055, 0.055, 0.12, 8), Props._xf(Vector3(0, 0.12, 0), Vector3.ONE), _mat("red")])
	_meshes["switch"] = Props._bake(parts)
	return _meshes["switch"]


## The whirling chain: links from his hand out to `reach`, with a big gold bell on the end.
static func _chain_mesh(reach: float) -> ArrayMesh:
	var key := "chain_%d" % int(reach * 10)
	if _meshes.has(key):
		return _meshes[key]
	var parts := []
	var n := int((reach - 0.8) / 0.26)
	for i in n:
		var link := TorusMesh.new()
		link.inner_radius = 0.09
		link.outer_radius = 0.16
		link.rings = 8
		link.ring_segments = 5
		var b := Basis(Vector3.FORWARD, PI / 2) * Basis(Vector3.UP, PI / 2 * (i % 2))
		parts.append([link, Props._xf(Vector3(0.8 + i * 0.26, 1.2, 0), Vector3(1.4, 1, 1), b), _mat("chain")])
	parts.append([Props._cone(0.08, 0.3, 0.38, 10), Props._xf(Vector3(reach - 0.05, 1.05, 0), Vector3.ONE), _mat("gold")])
	parts.append([Props._sphere(), Props._xf(Vector3(reach - 0.05, 0.84, 0), Vector3.ONE * 0.09), _mat("gold")])
	_meshes[key] = Props._bake(parts)
	return _meshes[key]


## Drawn over his whole body: his bones darkened to an old grey-brown, then frost on every
## surface that faces up (lit cold blue from above) and an icy edge, so he reads on the dark
## wood and doesn't glare white like a common skeleton.
static func _frost_overlay() -> ShaderMaterial:
	if _meshes.has("overlay"):
		return _meshes["overlay"]
	var dark := Shader.new()
	dark.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_back;
void fragment() {
	ALBEDO = vec3(0.56, 0.52, 0.52);
}
"""
	var frost := Shader.new()
	frost.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
varying vec3 wn;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float top = smoothstep(0.45, 0.85, wn.y);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	ALBEDO = vec3(0.34, 0.44, 0.55) * top * 0.8 + vec3(0.35, 0.65, 0.85) * rim * 0.5;
}
"""
	var m := ShaderMaterial.new()
	m.shader = dark
	var f := ShaderMaterial.new()
	f.shader = frost
	m.next_pass = f
	_meshes["overlay"] = m
	return m


# ---------------------------------------------------------------- the fight

func _think(hero: Hero, delta: float) -> void:
	if not _started:
		_started = true
		Sfx.play("roar", 1.0, 0.8)
		Game.shake(0.5)
		_brain()
	# WHITEOUT, the Hunt's top tier: the storm blows all fight long, and he turns sooner.
	if _tier() >= 5 and _alive():
		_storm_t += delta
		if _storm_t >= 16.0:
			_storm_t = 0.0
			Blizzard.call_now()
	if not _enraged and health < max_health * (0.6 if _tier() >= 5 else 0.5):
		_enraged = true
		move_speed *= 1.25
		visual.set_tint(Color(0.1, 0.25, 0.4))
		phase_two(ICE, "blizzard", "Krampusnacht")
	if randf() < delta * 2.0:
		Fx.magic(center() + Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 2.2), randf_range(-1.0, 1.0)), ICE if randf() < 0.7 else GOLD, 2)
	if _busy:
		stand(delta)
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > 3.2:
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
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["whirl", "lash", "sack", "avalanche"]
		if _tier() >= 3:
			moves.append("toll")   # the Krampus Hunt from TIER III
		if _enraged:
			moves.append("blizzard")
		match next_move(moves):
			"whirl": await _whirl()
			"lash": await _lash()
			"sack": await _sack_throw()
			"avalanche": await _avalanche()
			"blizzard": await _call_blizzard()
			"toll": await _bell_toll()
		_busy = false
		await _wait(0.8 if _enraged else 1.3)


func _to_hero() -> Vector3:
	var hero := Game.hero
	if hero == null:
		return Vector3.FORWARD
	var to := hero.global_position - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3.FORWARD


## Chain Whirl: a ring shows the chain's reach, then he spins it once round himself.
func _whirl() -> void:
	for k in (2 if _enraged else 1):
		if not _alive():
			return
		var reach := WHIRL_R if k == 0 else WHIRL_R2
		var warn := 1.0 if k == 0 else 0.8
		visual.attack(true)
		Sfx.play("warn", 0.5, 0.8)
		track(Telegraph.circle(global_position, reach, warn, Callable()))
		await _wait(warn)
		if not _alive():
			return
		var links := _chain.get_child(0) as MeshInstance3D
		links.mesh = _chain_mesh(reach)
		_chain.visible = true
		visual.attack()
		Sfx.play("swing", 0.9, 0.6)
		_strike_ring(reach)
		var t := 0.0
		var a0 := atan2(_to_hero().x, _to_hero().z)
		while t < 0.45:
			if not _alive():
				_chain.visible = false
				return
			_chain.rotation.y = a0 + t / 0.45 * TAU
			await get_tree().process_frame
			t += get_process_delta_time()
		_chain.visible = false
		Fx.shockwave(global_position, ICE, reach)
		Game.shake(0.3)
		await _wait(0.35)


## The chain's sweep: the hero and skeletons within `reach` (and outside his own body) are
## struck and thrown outwards.
func _strike_ring(reach: float) -> void:
	var hero := Game.hero
	if hero and hero.can_be_hit():
		var d := hero.global_position - global_position
		d.y = 0.0
		if d.length() < reach + hero.radius * 0.5:
			Game.hit_source = DISPLAY_NAME
			hero.take_damage(18.0, d.normalized() if d.length() > 0.05 else Vector3.BACK, 10.0)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and a != self and not (a as Enemy).is_boss and a.can_be_hit():
			var e := a.global_position - global_position
			e.y = 0.0
			if e.length() < reach:
				a.take_damage(a.max_health * 0.3, e.normalized() if e.length() > 0.05 else Vector3.FORWARD, 8.0)


## Chain Lash: a strip from him towards you; the chain cracks along it and yanks whoever
## it catches in towards him.
func _lash() -> void:
	for k in (2 if _enraged else 1):
		if not _alive():
			return
		var d := _to_hero()
		var warn := 0.9 if k == 0 else 0.7
		visual.attack(true)
		Sfx.play("warn", 0.4, 1.1)
		var from := global_position + d * 0.8
		track(Telegraph.line(from, d, LASH_LEN, LASH_W, warn, Callable()))
		var t := 0.0
		while t < warn:
			if not _alive():
				return
			face(d, 20.0, get_process_delta_time())
			await get_tree().process_frame
			t += get_process_delta_time()
		visual.attack()
		Sfx.play("crack", 0.8, 0.8)
		Game.shake(0.25)
		for i in 6:
			Fx.sparks(from + d * (1.0 + i * 1.8) + Vector3.UP * 0.6, GOLD)
		var hero := Game.hero
		if hero and hero.can_be_hit() and in_strip(hero.global_position, from, d, LASH_LEN, LASH_W, hero.radius * 0.5):
			Game.hit_source = DISPLAY_NAME
			# Pulled in: the push points back along the strip, at him.
			hero.take_damage(12.0, -d, 16.0)
			Fx.impact(hero.center(), GOLD, 1.2)
		await _wait(0.45)
	await _wait(0.3)


## Sack Throw: the sack flies at you and bursts where it lands, letting out Gift Thieves.
func _sack_throw() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var spot: Vector3 = Room.current.resolve_move(hero.global_position, Vector3.ZERO, 0.6) if Room.current else hero.global_position
	visual.attack(true)
	Sfx.play("swing", 0.7, 0.7)
	var flight := 1.0
	track(Telegraph.circle(spot, 1.7, flight, func(): _sack_lands(spot)))
	var sack := MeshInstance3D.new()
	sack.mesh = SphereMesh.new()
	(sack.mesh as SphereMesh).radius = 0.55
	(sack.mesh as SphereMesh).height = 1.2
	sack.material_override = _mat("sack")
	sack.top_level = true
	add_child(sack)
	var from := global_position + Vector3.UP * 3.0
	var t := 0.0
	while t < flight:
		if not is_instance_valid(sack):
			return
		var k := t / flight
		sack.global_position = from.lerp(spot, k) + Vector3.UP * sin(k * PI) * 4.0
		sack.rotation.x += get_process_delta_time() * 6.0
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(sack):
		sack.queue_free()
	await _wait(0.6)


func _sack_lands(spot: Vector3) -> void:
	SkeletonMage.explode(spot, 1.7, 14.0, DISPLAY_NAME)
	Fx.dust(spot, 24)
	Sfx.play("slam", 0.7, 1.2)
	for i in (3 if _enraged else 2):
		if Game.alive_enemies >= 8:
			break
		var off := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 3.0 + randf()) * 0.8
		Game.spawn_enemy("i", Room.current.resolve_move(spot + off, Vector3.ZERO, 0.4) if Room.current else spot + off)


## Avalanche: he stamps, and snowballs roll down the hall from the far wall in lanes,
## growing as they come. The lanes leave gaps to stand in.
func _avalanche() -> void:
	visual.attack(true)
	Sfx.play("roar", 0.6, 0.9)
	await _wait(0.5)
	if not _alive():
		return
	Sfx.play("slam", 0.9, 0.8)
	Game.shake(0.45)
	Fx.dust(global_position, 30)
	var lanes := 4 if _enraged else 3
	var w := Room.HALF_W * 2.0
	var gap := randi() % (lanes + 1)
	var xs: Array[float] = []
	for i in lanes + 1:
		if i != gap:
			xs.append(-Room.HALF_W + w * (i + 0.5) / (lanes + 1))
	_lanes(xs)
	await _wait(1.9)
	# From the Hunt's TIER IV, a second wave down the lanes the first one left open.
	if _tier() >= 4 and _alive():
		var gap2 := (gap + 1 + randi() % lanes) % (lanes + 1)
		var xs2: Array[float] = []
		for i in lanes + 1:
			if i != gap2:
				xs2.append(-Room.HALF_W + w * (i + 0.5) / (lanes + 1))
		Sfx.play("slam", 0.8, 0.9)
		Game.shake(0.3)
		_lanes(xs2)
		await _wait(1.9)


func _lanes(xs: Array[float]) -> void:
	for x in xs:
		var o := Vector3(x, 0, -Room.HALF_L + 0.8)
		track(Telegraph.line(o, Vector3.BACK, Room.HALF_L * 2.0 - 1.6, 1.5, 1.1, func(): Snowball.roll(o, Vector3.BACK, 9.0, 0.45, 0.85, Room.HALF_L * 2.0 - 1.4, 16.0, DISPLAY_NAME), 0.6 if x == xs[0] else 0.0))


## Bell Toll (the Krampus Hunt from TIER III): he shakes the bells on his chest and two
## rings of frost spread out from him, one after the other. Dash through each as it passes.
func _bell_toll() -> void:
	visual.attack(true)
	for k in 2:
		if not _alive():
			return
		Sfx.play("shimmer", 0.7, 0.7)
		Fx.magic(center() + Vector3.UP * 0.8, GOLD, 14)
		await _wait(0.7)
		if not _alive():
			return
		Game.shake(0.2)
		FrostRing.ring(global_position, ICE, DISPLAY_NAME)
		await _wait(0.5)
	await _wait(0.6)


## Krampusnacht's own move: he howls and the Blizzard sweeps the hall straight away.
func _call_blizzard() -> void:
	visual.attack(true)
	Sfx.play("roar", 0.8, 0.7)
	Game.shake(0.4)
	Fx.shockwave(global_position, ICE, 7.0)
	Blizzard.call_now()
	await _wait(0.8)
	if _alive():
		await _whirl()


func _on_death() -> void:
	Sfx.play("roar", 0.8, 0.7)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	for i in 6:
		Fx.bones(global_position + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2)))
	Fx.magic(center(), GOLD, 40)
	super._on_death()
