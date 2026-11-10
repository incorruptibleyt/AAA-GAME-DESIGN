class_name Tidecaller
extends Enemy
## The boss of the Drowned Vault (floor 6, then every fifth floor; Crypt Pass only): a huge
## hooded skeleton with a staff, grown over with weed, that commands the water. Where the
## Cinder Colossus fills the floor with fire, it moves the water itself. Every attack has
## a warning:
## - Spray: fans of water bolts aimed at you.
## - Tidal Wave: the whole room lights up except one lane, then a wave sweeps from the far
##   wall to the near one. Stand in the lane (or dash through the wave).
## - Dive: it sinks out of reach and swims at you as a big ripple, then a circle marks where
##   it bursts up, throwing a ring of water bolts.
## - Call (every other round; a second spray in between): Drowned Skeletons climb out
##   beside it, two when it is angry. They shield it, so not too many.
## Below half health it gets angrier: quicker waves with a narrower lane, more bolts.

const DISPLAY_NAME := "The Tidecaller"
const WATER := Color(0.5, 1.0, 0.92)
## Its bolts: pale and bright, so they stand out on the dark water.
const SHOT := Color(0.75, 1.0, 1.0)
const DEPTH := 4.5

var _enraged := false
var _started := false
var _busy := false
## Under water: can't be hit, no touch damage, body hidden.
var _under := false
## How far it has sunk: 0 standing, 1 out of sight (set every frame in _think, because the
## shared skeleton code puts the body back on the floor each frame).
var _depth := 0.0
var _staff_glow: MeshInstance3D


func _setup() -> void:
	is_boss = true
	init_health(820.0)
	drop_chance = 0.0
	move_speed = 1.5
	contact_damage = 16.0
	radius = 1.15
	center_height = 1.8
	knockback_scale = 0.06
	var look := bones(Art.SKELETON_ROGUE, 4.1, Color(0.45, 1.0, 0.9))
	look.overlay = WetLook.overlay(0.3)
	look.accent = Color(0.1, 0.24, 0.2)
	look.weapon = "Skeleton_Staff"
	look.attack_anim = "Spellcast_Shoot"
	make_visual(look)
	_dress()


## Long strands of weed hanging from its head and a pale light on its staff.
func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null:
		return
	if skel.find_bone("head") >= 0:
		var att := BoneAttachment3D.new()
		skel.add_child(att)
		att.bone_name = "head"
		var weed := U.mat(Color(0.1, 0.3, 0.15), 0.55, 0.2)
		for i in 5:
			var side := (i - 2) * 0.22
			var strand := U.capsule(att, 0.05, 0.55 + 0.15 * (2 - absi(i - 2)), weed, Vector3(side, 0.55, 0.25 - absf(side) * 0.3))
			strand.rotation.x = 0.35
	if skel.find_bone("handslot.r") >= 0:
		var hand := BoneAttachment3D.new()
		skel.add_child(hand)
		hand.bone_name = "handslot.r"
		var glow := U.unlit(Color(0.55, 1.0, 0.95, 0.85), U.soft_circle(), true).duplicate()
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_staff_glow = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.9)
		_staff_glow.mesh = q
		_staff_glow.material_override = glow
		_staff_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(_staff_glow)
		_staff_glow.position = Vector3(0, 1.2, 0)


func display_name() -> String:
	return DISPLAY_NAME


func can_be_hit() -> bool:
	return super.can_be_hit() and not _under


func _think(hero: Hero, delta: float) -> void:
	if not _started:
		_started = true
		Sfx.play("roar")
		Sfx.play("splash", 0.9, 0.7)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.3
		Sfx.play("splash", 1.0, 0.8)
		phase_two(WATER, "riptide", "Riptide")
		if _staff_glow:
			_staff_glow.create_tween().tween_property(_staff_glow, "scale", Vector3.ONE * 1.6, 0.4)
	visual.position.y = -DEPTH * _depth
	if _under:
		return
	if randf() < delta * 3.0:
		Fx.magic(center() + Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 1.2), randf_range(-0.8, 0.8)), WATER, 2)
	if _busy:
		return
	# It keeps a middle distance: close enough to reach, far enough to shoot.
	var to := hero.global_position - global_position
	if to.length() > 5.0:
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
	var bags := 0
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["spray", "wave", "dive", "spray"]
		if bags % 2 == 0:   # every other round of moves, about as often as before
			moves.append("call")
		if _enraged:
			moves.append("riptide")   # phase 2's own move
		var m := next_move(moves)
		if _bag.is_empty():
			bags += 1
		match m:
			"spray": await _spray()
			"wave": await _wave()
			"dive": await _dive()
			"call":
				await _call()
			"riptide": await _riptide()
		_busy = false
		await _wait(0.9 if _enraged else 1.4)


## Phase 2: a wave sweeps the room, and the Tidecaller fires its fans while you are still
## dodging it.
func _riptide() -> void:
	await _wave()
	if _alive():
		await _spray()


## Fans of water bolts aimed at the hero.
func _spray() -> void:
	var fans := 4 if _enraged else 3
	var count := 7 if _enraged else 5
	for f in fans:
		if not _alive() or Game.hero == null:
			return
		var d := Game.hero.global_position - global_position
		d.y = 0.0
		d = d.normalized()
		face(d, 30.0, 0.1)
		visual.attack(true)
		var spread := deg_to_rad(52.0)
		for i in count:
			var dir := d.rotated(Vector3.UP, -spread * 0.5 + spread * i / (count - 1))
			Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 1.4 + dir * 1.3, dir, 10.0, 8.0, SHOT, 0.3, DISPLAY_NAME)
		Sfx.play("shoot", 0.8, 0.8)
		Sfx.play("splash", 0.3, 1.4)
		await _wait(0.5)
	await _wait(0.5)


## The whole room is warned except one lane; then a wave sweeps from the far wall to the near
## one. Its lane is never right against a wall, and never where the hero already stands
## (so they have to move).
func _wave() -> void:
	var hero := Game.hero
	if hero == null:
		return
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	Sfx.play("roar", 0.5, 0.8)
	var gap := 2.0 if _enraged else 2.6
	var wind := 1.15 if _enraged else 1.45
	var w := Room.HALF_W
	var lane := randf_range(-w + gap, w - gap)
	if absf(lane - hero.global_position.x) < gap:
		lane = clampf(lane + signf(lane - hero.global_position.x + 0.01) * gap * 1.5, -w + gap, w - gap)
	var far := -Room.HALF_L
	var left := (lane - gap * 0.5) + w
	var right := w - (lane + gap * 0.5)
	if left > 0.1:
		track(Telegraph.line(Vector3(-w + left * 0.5, 0, far), Vector3.BACK, Room.HALF_L * 2.0, left, wind, Callable()))
	if right > 0.1:
		track(Telegraph.line(Vector3(w - right * 0.5, 0, far), Vector3.BACK, Room.HALF_L * 2.0, right, wind, Callable()))
	await _wait(wind)
	if not _alive():
		return
	await _sweep(lane, gap)
	await _wait(0.4)


## The wave itself: two walls of foam with the lane between them, rolling towards the camera.
func _sweep(lane: float, gap: float) -> void:
	var w := Room.HALF_W
	var parent: Node = Room.current if Room.current else Game.world
	var wave := Node3D.new()
	parent.add_child(wave)
	var foam := _foam_material()
	for side: float in [-1.0, 1.0]:
		var inner := lane + side * gap * 0.5
		var outer := side * w
		var width := absf(outer - inner)
		if width < 0.1:
			continue
		var mi := U.box(wave, Vector3(width, 1.3, 0.7), foam, Vector3((inner + outer) * 0.5, 0.65, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Sfx.play("splash", 1.0, 0.6)
	Game.shake(0.25)
	var speed := 11.0 if _enraged else 9.0
	var z := -Room.HALF_L
	var hit := false
	var spray := 0.0
	while z < Room.HALF_L + 0.5:
		if not _alive():
			break
		var dt := get_process_delta_time()
		z += speed * dt
		wave.global_position = Vector3(0, 0, z)
		spray -= dt
		if spray <= 0.0:
			spray = 0.08
			var x := randf_range(-w, w)
			if absf(x - lane) > gap * 0.5:
				Fx.magic(Vector3(x, 1.2, z), WATER, 3)
		var hero := Game.hero
		if not hit and hero and absf(hero.global_position.z - z) < 0.35 + hero.radius \
				and absf(hero.global_position.x - lane) > gap * 0.5 - hero.radius * 0.5:
			if hero.can_be_hit():
				hit = true
				Game.hit_source = DISPLAY_NAME
				hero.take_damage(16.0, Vector3.BACK, 11.0)
		await get_tree().process_frame
	wave.queue_free()


static var _foam: ShaderMaterial

## Running white water: streaks rolling over the top of the wave.
static func _foam_material() -> ShaderMaterial:
	if _foam:
		return _foam
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.45, 0.95, 0.9, 1.0);
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float h(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}
void fragment() {
	float lane = floor(wp.x * 6.0);
	float s = fract(wp.y * 1.2 - TIME * (2.5 + h(lane)) + h(lane + 5.0));
	float top = smoothstep(0.6, 1.3, wp.y);
	ALBEDO = col.rgb * (0.35 + 0.45 * smoothstep(0.2, 0.9, s) + 0.6 * top);
}
"""
	_foam = ShaderMaterial.new()
	_foam.shader = sh
	return _foam


## Sinks out of reach, swims at the hero as a big ripple, then bursts up where the circle
## shows, throwing a ring of water bolts.
func _dive() -> void:
	Sfx.play("splash", 0.9, 0.7)
	Fx.magic(global_position + Vector3.UP * 0.5, WATER, 30)
	Fx.shockwave(global_position, WATER, 3.0)
	var tw := create_tween()
	tw.tween_property(self, "_depth", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _wait(0.55)
	if not _alive():
		return
	_under = true
	contact_damage = 0.0
	visual.visible = false
	var t := 0.0
	var ripple := 0.0
	while t < 1.5:
		if not _alive() or Game.hero == null:
			_surface()
			return
		var dt := get_process_delta_time()
		var to := Game.hero.global_position - global_position
		to.y = 0.0
		if to.length() > 0.6:
			move_by(to.normalized() * 6.0 * dt, dt)
		ripple -= dt
		if ripple <= 0.0:
			ripple = 0.16
			Fx.shockwave(global_position, WATER, 1.8)
			Fx.magic(global_position + Vector3.UP * 0.2, WATER, 4)
		await get_tree().process_frame
		t += dt
	var at := global_position
	var r := 2.3
	var source := DISPLAY_NAME
	track(Telegraph.circle(at, r, 0.75 if _enraged else 0.9, func(): _erupt(at, r, source)))
	await _wait(0.75 if _enraged else 0.9)
	if not _alive():
		_surface()
		return
	# The ring of bolts, after the eruption.
	var count := 16 if _enraged else 12
	var turn := randf() * TAU
	for i in count:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, turn + i * TAU / count)
		Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 1.0 + dir * 1.4, dir, 10.0, 6.0, SHOT, 0.32, DISPLAY_NAME)
	Sfx.play("shoot", 0.8, 0.7)
	await _wait(0.9)


func _surface() -> void:
	_under = false
	_depth = 0.0
	contact_damage = 16.0
	if is_instance_valid(visual):
		visual.visible = true
		visual.position.y = 0.0


func _erupt(at: Vector3, r: float, source: String) -> void:
	_surface()
	visual.attack(true)
	Game.shake(0.45)
	Sfx.play("splash", 1.0, 0.75)
	Sfx.play("boom", 0.6, 0.8)
	Fx.shockwave(at, WATER, r)
	Fx.magic(at + Vector3.UP * 0.6, WATER, 40)
	var hero := Game.hero
	if hero == null or not _alive():
		return
	var d := hero.global_position - at
	d.y = 0.0
	if d.length() < r + hero.radius * 0.5:
		Game.hit_source = source
		hero.take_damage(18.0, d, 12.0)


## Drowned Skeletons climb out beside it.
func _call() -> void:
	if not visual.play_named("Spellcast_Summon"):
		visual.attack(true)
	Sfx.play("roar", 0.6)
	Sfx.play("splash", 0.8)
	var n := 2 if _enraged else 1
	for i in n:
		if Game.alive_enemies >= 3:   # itself and at most two Drowned Skeletons
			break
		var off := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / n + randf_range(-0.3, 0.3)) * 3.2
		var spot := Room.current.resolve_move(global_position + off, Vector3.ZERO, 0.4)
		Fx.shockwave(spot, WATER, 1.4)
		Game.spawn_enemy("d", spot)
	await _wait(1.0)


func _on_death() -> void:
	_surface()
	Sfx.play("roar", 0.8)
	Sfx.play("splash", 1.0, 0.6)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	if _staff_glow:
		_staff_glow.create_tween().tween_property(_staff_glow, "scale", Vector3.ZERO, 0.6)
	Fx.magic(center(), WATER, 50)
	Fx.shockwave(global_position, WATER, 5.0)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
