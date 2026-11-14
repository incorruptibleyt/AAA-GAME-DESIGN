class_name BloodQueen
extends Enemy
## The Blood Moon Queen (events.gd, version 134): the event's own boss, at the end of the
## Blood Moon run and alone in the Queen Hunt. A towering skeleton sorceress in blood-red
## robes wearing the Moon Crown, a blood moon blazing behind her head and a swarm of bats
## circling her. Every attack has a warning:
## - Crescent Blades: strips fan out from her, then spinning crescents fly out along them
##   and come back. Stand between the strips (and stay there until they're home).
## - Moonbeams: two (three when angry) beams of red light, shown first as strips, sweep
##   slowly round the room from her. Keep ahead of them, or dash through one.
## - Blood Rain: circles drop round you one after another; each bursts.
## - Bat Storm (every other round): a flock of Bloodbats.
## Below half health the moon goes black: ECLIPSE. The room darkens, she vanishes into the
## dark and three Shades of her (four on the Eclipse tier) appear round the room, firing
## slow blood orbs. Destroy them all and she falls out of the dark, stunned, taking half
## again as much damage for a few seconds. She does it again later in the fight.

const DISPLAY_NAME := "The Blood Moon Queen"
const RED := Color(1.0, 0.22, 0.18)
const GOLD := Color(1.0, 0.8, 0.42)
const STUN := 4.0

var _enraged := false
var _started := false
var _busy := false
var _eclipse := false
var _stunned := 0.0
var _halo: MeshInstance3D
var _bats: MultiMeshInstance3D
static var _halo_shader: Shader
static var _blade_shader: Shader


## The hunt's tier (the Blood Moon run's Queen fights like tier II).
func _tier() -> int:
	return Game.event_tier if Game.event == "hunt" else 2


func _setup() -> void:
	is_boss = true
	init_health(620.0)
	drop_chance = 0.0
	move_speed = 1.4
	contact_damage = 16.0
	radius = 1.1
	center_height = 1.9
	knockback_scale = 0.05
	var look := bones(Art.SKELETON_MAGE, 4.1, RED)
	look.rim = Color(1.0, 0.16, 0.12, 0.9)
	look.rim_power = 2.0
	look.accent = Color(0.38, 0.03, 0.07)
	look.weapon = "Skeleton_Staff"
	look.attack_anim = "Spellcast_Shoot"
	look.hide = ["Skeleton_Mage_Hat"]
	make_visual(look)
	_dress()


func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel and skel.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "head"
		# The Moon Crown of the event set, sized for a skeleton's big skull.
		var crown := FeatHeads.make("moon_crown", "mage", 0.9, false, {})
		crown.scale = Vector3.ONE * 1.3
		att.add_child(crown)
	# The blood moon behind her head (kept upright and behind her in _process).
	if _halo_shader == null:
		_halo_shader = Shader.new()
		_halo_shader.code = HALO
	var m := ShaderMaterial.new()
	m.shader = _halo_shader
	var q := QuadMesh.new()
	q.size = Vector2(3.4, 3.4)
	_halo = MeshInstance3D.new()
	_halo.mesh = q
	_halo.material_override = m
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.top_level = true
	add_child(_halo)
	_bats = Fx.bats(RED, 7, 2.3, 2.4, 0.42, 1.0)
	add_child(_bats)


func display_name() -> String:
	return DISPLAY_NAME


func can_be_hit() -> bool:
	return super.can_be_hit() and not _eclipse


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	super.take_damage(amount * (1.5 if _stunned > 0.0 else 1.0), direction, push, crit)


func _process(delta: float) -> void:
	super._process(delta)
	if _halo:
		_halo.global_position = global_position + Vector3(0, 3.5, -0.9)
		_halo.visible = not dead


func _think(hero: Hero, delta: float) -> void:
	if not _started:
		_started = true
		Sfx.play("roar")
		Sfx.play("wraith", 0.6, 0.6)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.2
		phase_two(RED, "eclipse", "Eclipse")
	_stunned -= delta
	if randf() < delta * 3.0 and not _eclipse:
		Fx.magic(center() + Vector3(randf_range(-0.9, 0.9), randf_range(0.0, 1.8), randf_range(-0.9, 0.9)), RED if randf() < 0.7 else GOLD, 2)
	if _busy or _eclipse or _stunned > 0.0:
		stand(delta)
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	if to.length() > 6.0:
		walk(to, delta)
	elif to.length() < 3.2:
		walk(-to, delta, 0.8)
	else:
		stand(delta)
		face(to, 6.0, delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _alive() -> bool:
	return is_instance_valid(self) and not dead and Game.state == Game.State.PLAYING


func _brain() -> void:
	await _wait(1.2)
	var bags := 0
	while _alive():
		await roar_done()
		if not _alive():
			break
		while _stunned > 0.0 and _alive():
			await _wait(0.2)
		_busy = true
		var moves := ["crescents", "beams", "rain"]
		if bags % 2 == 0:
			moves.append("bats")
		if _enraged:
			moves.append("eclipse")
		var m := next_move(moves)
		if _bag.is_empty():
			bags += 1
		match m:
			"crescents": await _crescents()
			"beams": await _beams()
			"rain": await _rain()
			"bats": await _bat_storm()
			"eclipse": await _eclipse_move()
		_busy = false
		await _wait(0.8 if _enraged else 1.3)


func _to_hero() -> Vector3:
	var hero := Game.hero
	if hero == null:
		return Vector3.FORWARD
	var to := hero.global_position - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3.FORWARD


# ---------------------------------------------------------------- Crescent Blades

func _crescents() -> void:
	var to := _to_hero()
	face(to, 30.0, 0.1)
	visual.attack(true)
	var n := 5 if _enraged or _tier() >= 4 else 3
	var spread := 0.32 if n == 5 else 0.45
	var dirs := []
	for i in n:
		dirs.append(to.rotated(Vector3.UP, (i - (n - 1) * 0.5) * spread))
	for d: Vector3 in dirs:
		track(Telegraph.line(global_position, d, 8.5, 0.9, 0.75, Callable()))
	Sfx.play("shimmer", 0.8, 0.8)
	await _wait(0.75)
	if not _alive():
		return
	Sfx.play("dash", 0.7, 0.7)
	for d: Vector3 in dirs:
		_blade(d)
	await _wait(1.9)


func _blade(d: Vector3) -> void:
	if _blade_shader == null:
		_blade_shader = Shader.new()
		_blade_shader.code = BLADE
	var b := Blade.new()
	b.owner_queen = self
	b.dir = d
	b.start = global_position + Vector3.UP * 1.0
	var m := ShaderMaterial.new()
	m.shader = _blade_shader
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.5, 1.5)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(mi)
	var parent: Node = Room.current if Room.current else Game.world
	parent.add_child(b)
	b.global_position = b.start


## A crescent: out along its strip, then home to the Queen, spinning. It hurts once on the
## way out and once on the way back.
class Blade extends Node3D:
	var owner_queen: Node3D
	var dir := Vector3.FORWARD
	var start := Vector3.ZERO
	var _t := 0.0
	var _hit_out := false
	var _hit_back := false
	const OUT := 0.55
	const BACK := 0.75
	const LEN := 8.5

	func _process(delta: float) -> void:
		_t += delta
		rotation.y += delta * 16.0
		var home: Vector3 = owner_queen.global_position + Vector3.UP * 1.0 if is_instance_valid(owner_queen) else start
		var far := start + dir * LEN
		if _t < OUT:
			var k := _t / OUT
			global_position = start.lerp(far, 1.0 - (1.0 - k) * (1.0 - k))
		elif _t < OUT + BACK:
			var k := (_t - OUT) / BACK
			global_position = far.lerp(home, k * k)
		else:
			queue_free()
			return
		var hero := Game.hero
		if hero == null or hero.dead or not is_instance_valid(owner_queen) or (owner_queen as Enemy).dead:
			return
		var d := hero.global_position - global_position
		d.y = 0.0
		if d.length() < 0.75 + hero.radius * 0.5:
			var back := _t >= OUT
			if (back and not _hit_back) or (not back and not _hit_out):
				if back:
					_hit_back = true
				else:
					_hit_out = true
				Game.hit_source = BloodQueen.DISPLAY_NAME
				hero.take_damage(12.0, d, 6.0)


# ---------------------------------------------------------------- Moonbeams

func _beams() -> void:
	var n := 3 if _enraged else 2
	var to := _to_hero()
	var base := atan2(to.x, to.z) + PI / n * 0.5   # the beams start beside the hero, not on them
	var turn := 1.0 if randf() < 0.5 else -1.0
	var sweep := 2.1
	var secs := 2.4 if _enraged else 2.9
	visual.attack(true)
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	for i in n:
		var a := base + i * TAU / n
		track(Telegraph.line(global_position, Vector3(sin(a), 0, cos(a)), 11.0, 0.8, 0.95, Callable()))
	Sfx.play("shimmer", 0.9, 0.6)
	await _wait(0.95)
	if not _alive():
		return
	Sfx.play("beam", 0.8, 0.8)
	var beam := Beams.new()
	beam.queen = self
	beam.count = n
	beam.base = base
	beam.turn = turn * sweep / secs
	beam.life = secs
	var parent: Node = Room.current if Room.current else Game.world
	parent.add_child(beam)
	beam.global_position = global_position + Vector3.UP * 0.05
	await _wait(secs + 0.2)


## The sweeping beams: long strips of red light turning round the Queen; they hurt where
## they cross the hero (at most once every 0.7 s).
class Beams extends Node3D:
	var queen: Node3D
	var count := 2
	var base := 0.0
	var turn := 0.7
	var life := 2.8
	var _t := 0.0
	var _cool := 0.0
	var _arms: Array[Node3D] = []
	const LEN := 11.0
	const WIDTH := 0.7

	func _ready() -> void:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.25, 0.18, 0.85)
		m.albedo_texture = U.soft_circle()
		var core := StandardMaterial3D.new()
		core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core.albedo_color = Color(1.0, 0.85, 0.7)
		for i in count:
			var arm := Node3D.new()
			add_child(arm)
			var glow := MeshInstance3D.new()
			var q := PlaneMesh.new()
			q.size = Vector2(WIDTH * 2.2, LEN)
			glow.mesh = q
			glow.material_override = m
			glow.position = Vector3(0, 0.6, LEN * 0.5)
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arm.add_child(glow)
			var c := MeshInstance3D.new()
			var cq := BoxMesh.new()
			cq.size = Vector3(0.14, 0.14, LEN)
			c.mesh = cq
			c.material_override = core
			c.position = Vector3(0, 0.7, LEN * 0.5)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			arm.add_child(c)
			_arms.append(arm)
		_place()

	func _place() -> void:
		for i in _arms.size():
			_arms[i].rotation.y = base + turn * _t + i * TAU / count

	func _process(delta: float) -> void:
		_t += delta
		_cool -= delta
		if is_instance_valid(queen):
			global_position = Vector3(queen.global_position.x, 0.05, queen.global_position.z)
		var fade := clampf(minf(_t / 0.15, (life - _t) / 0.25), 0.0, 1.0)
		scale = Vector3(fade, 1.0, 1.0)
		_place()
		if _t >= life or not is_instance_valid(queen) or (queen as Enemy).dead:
			queue_free()
			return
		var hero := Game.hero
		if hero == null or hero.dead or _cool > 0.0 or fade < 0.6:
			return
		var p := hero.global_position - global_position
		p.y = 0.0
		for arm in _arms:
			var d := Vector3(sin(arm.rotation.y), 0, cos(arm.rotation.y))
			var along := p.dot(d)
			if along < 0.0 or along > LEN:
				continue
			var off := (p - d * along).length()
			if off < WIDTH * 0.5 + hero.radius * 0.5:
				_cool = 0.7
				Game.hit_source = BloodQueen.DISPLAY_NAME
				hero.take_damage(14.0, p, 5.0)
				Fx.magic(hero.center(), Color(1.0, 0.3, 0.2), 10)
				break


# ---------------------------------------------------------------- Blood Rain

func _rain() -> void:
	var hero := Game.hero
	if hero == null:
		return
	visual.attack(true)
	Sfx.play("roar", 0.4, 1.4)
	var count := 8 if _enraged else 6
	for i in count:
		if not _alive() or Game.hero == null:
			return
		var spot := Game.hero.global_position
		if i > 0:
			spot += Vector3(randf_range(-2.4, 2.4), 0, randf_range(-2.4, 2.4))
		spot.x = clampf(spot.x, -Room.HALF_W + 0.8, Room.HALF_W - 0.8)
		spot.z = clampf(spot.z, -Room.HALF_L + 0.8, Room.HALF_L - 0.8)
		var at := spot
		track(Telegraph.circle(at, 1.15, 0.9, func(): _rain_hit(at), 0.45 if i == 0 else 0.0))
		await _wait(0.2)
	await _wait(1.0)


func _rain_hit(at: Vector3) -> void:
	Sfx.play("splash", 0.5, randf_range(0.7, 0.9))
	Fx.magic(at + Vector3.UP * 0.3, RED, 14)
	Fx.shockwave(at, RED, 1.5)
	var hero := Game.hero
	if hero == null or dead:
		return
	var d := hero.global_position - at
	d.y = 0.0
	if d.length() < 1.15 + hero.radius * 0.5:
		Game.hit_source = DISPLAY_NAME
		hero.take_damage(13.0, d, 6.0)


# ---------------------------------------------------------------- Bat Storm

func _bat_storm() -> void:
	if not visual.play_named("Spellcast_Summon"):
		visual.attack(true)
	Sfx.play("wraith", 0.7, 1.6)
	Game.shake(0.25)
	Fx.shockwave(global_position, RED, 2.6)
	if Game.alive_enemies <= 3:
		var off := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 2.6
		var spot: Vector3 = Room.current.resolve_move(global_position + off, Vector3.ZERO, 0.4) if Room.current else global_position + off
		Game.spawn_enemy("b", spot)   # a flock of three
	await _wait(1.0)


# ---------------------------------------------------------------- Eclipse

func _eclipse_move() -> void:
	_eclipse = true
	contact_damage = 0.0
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	Sfx.play("roar", 0.9, 0.7)
	Game.shake(0.4)
	Game.set_eclipse(true)
	Game.hud.callout("ECLIPSE!", Color(1.0, 0.35, 0.3))
	Fx.magic(center(), RED, 40)
	var tw := visual.create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.45).set_ease(Tween.EASE_IN)
	if _bats:
		_bats.visible = false
	await _wait(0.5)
	if not _alive():
		return
	# Her Shades, round the middle of the room.
	var shades: Array[Enemy] = []
	var n := 4 if _tier() >= 5 else 3
	var turn := randf() * TAU
	for i in n:
		var a := turn + i * TAU / n
		var spot := Vector3(sin(a) * 3.4, 0, cos(a) * 4.6)
		if Room.current:
			spot = Room.current.resolve_move(spot, Vector3.ZERO, 0.6)
		Fx.shockwave(spot, RED, 1.6)
		shades.append(Game.spawn_enemy("q", spot))
	var left := 14.0
	while left > 0.0 and _alive() and shades.any(func(s): return is_instance_valid(s) and not s.dead):
		await _wait(0.2)
		left -= 0.2
	for s in shades:
		if is_instance_valid(s) and not s.dead:
			s.crumble()
	if not _alive():
		return
	# Back out of the dark in the middle of the room, stunned.
	var mid := Vector3(0, 0, -1.5)
	if Room.current:
		mid = Room.current.resolve_move(mid, Vector3.ZERO, radius)
	global_position = mid
	Game.set_eclipse(false)
	_eclipse = false
	_stunned = STUN
	contact_damage = 16.0
	if _bats:
		_bats.visible = true
	var back := visual.create_tween()
	back.tween_property(visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.shockwave(global_position, GOLD, 4.0)
	Fx.magic(center(), GOLD, 30)
	Sfx.play("slam", 0.8)
	Game.hud.callout("STUNNED! HIT HER!", GOLD)
	await _wait(STUN)


func _on_death() -> void:
	Sfx.play("roar", 0.8, 0.8)
	Sfx.play("wraith", 0.8, 0.5)
	Game.set_eclipse(false)
	Game.hit_stop(0.3)
	Game.shake(0.9)
	if _halo:
		_halo.create_tween().tween_property(_halo, "scale", Vector3.ONE * 2.5, 0.6)
	if _bats:
		_bats.visible = false
	Fx.magic(center(), RED, 70)
	Fx.magic(center(), GOLD, 30)
	Fx.shockwave(global_position, RED, 6.0)
	Fx.shockwave(global_position, GOLD, 3.5)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()


## The blood moon behind her: a glowing red disc with dark seas on it and a corona, always
## facing the camera; it throbs with the heartbeat of the crypt's floor.
const HALO := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = fract(TIME * 0.9);
	float beat = exp(-t * 9.0) + 0.6 * exp(-max(t - 0.22, 0.0) * 9.0) * step(0.22, t);
	float disc = 1.0 - smoothstep(0.5, 0.53, r);
	float seas = smoothstep(0.35, 0.65, sin(p.x * 7.0 + 1.3) * sin(p.y * 6.0 - 0.7) * 0.5 + 0.5);
	float corona = (1.0 - smoothstep(0.5, 1.0, r)) * (1.0 - disc);
	vec3 c = mix(vec3(1.0, 0.22, 0.12), vec3(0.55, 0.05, 0.04), seas * 0.7) * disc * (1.0 + 0.25 * beat);
	c += vec3(1.0, 0.18, 0.1) * corona * corona * (0.9 + 0.5 * beat);
	ALBEDO = c;
}
"""

## A crescent blade lying flat: a sharp moon-gold crescent with a blood-red glow round it.
const BLADE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 1.0 - smoothstep(0.62, 0.68, length(p));
	float b = 1.0 - smoothstep(0.5, 0.56, length(p - vec2(0.24, 0.16)));
	float moon = a * (1.0 - b);
	float glow = (1.0 - smoothstep(0.3, 1.0, length(p))) * 0.35;
	ALBEDO = vec3(1.0, 0.85, 0.55) * moon * 1.6 + vec3(1.0, 0.2, 0.12) * glow;
}
"""
