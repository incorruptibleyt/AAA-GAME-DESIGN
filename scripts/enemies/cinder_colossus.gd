class_name CinderColossus
extends Enemy
## The boss of the Ember Catacomb (floor 3, then every third floor), in place of the King
## or the Lich: a giant charred skeleton with two axes and a burning skull. Where the King
## fights with shots and charges, it fills the floor with fire. Every attack has a warning:
## - Eruption: circles open at you and around you, then burst and leave fire behind.
## - Burning Rush: a long line shows where it will run; the path it ran stays on fire.
## - Fire Nova: a circle around it fills, it leaps and slams, and rings of slow fireballs
##   roll out with gaps to slip through.
## - Kindle (every other round; a second rush in between): a Cinder Skeleton climbs out of
##   the floor beside it, two when it is angry. They shield it, so not too many.
## Below half health it gets angrier: faster, more of everything, and fire under its feet.

const DISPLAY_NAME := "The Cinder Colossus"
## Its fire (sparks, bursts). Its fireballs are brighter, so they stand out on the Ember floor.
const FIRE := Color(1.0, 0.5, 0.15)
const SHOT := Color(1.0, 0.78, 0.32)

var _enraged := false
var _started := false
var _busy := false
var _trail := 0.0
var _flame: MeshInstance3D


func _setup() -> void:
	is_boss = true
	init_health(540.0)
	drop_chance = 0.0
	move_speed = 1.6
	contact_damage = 18.0
	radius = 1.2
	center_height = 1.9
	knockback_scale = 0.06
	var look := bones(Art.SKELETON_WARRIOR, 4.3, Color(1.0, 0.65, 0.15))
	look.overlay = CinderSkeleton._charred(true)   # lighter, with a glowing rim: readable on lava
	look.accent = Color(0.5, 0.2, 0.1)
	look.horns = true
	look.weapon = "Skeleton_Axe"
	look.offhand = "Skeleton_Axe"
	look.attack_anim = "Dualwield_Melee_Attack_Chop"
	look.hide = ["Skeleton_Warrior_Cloak"]
	make_visual(look)
	_dress()


## Black horns and a crown of fire on its skull (like its Cinder Skeletons, but bigger).
func _dress() -> void:
	var skel := Art._find_skeleton(visual)
	if skel == null or skel.find_bone("head") < 0:
		return
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = "head"
	var horn_mat := U.mat(Color(0.1, 0.07, 0.06), 0.6)
	for side in [-1.0, 1.0]:
		var horn := U.capsule(att, 0.07, 0.55, horn_mat, Vector3(side * 0.43, 0.9, -0.05))
		horn.rotation.z = -side * 0.6
	# (sizes here grow with the model, which is 2.5 times a Cinder Skeleton)
	_flame = Fx.flame(att, Vector2(0.45, 0.65), Vector3(0, 0.8, 0))


func display_name() -> String:
	return DISPLAY_NAME


func _think(hero: Hero, delta: float) -> void:
	if not _started:
		_started = true
		Sfx.play("roar")
		Sfx.play("ignite", 0.8)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.35
		Sfx.play("roar")
		Sfx.play("ignite", 0.9)
		Game.shake(0.4)
		Fx.magic(center(), FIRE, 40)
		Fx.shockwave(global_position, FIRE, 4.0)
		if _flame:
			_flame.create_tween().tween_property(_flame, "scale", Vector3.ONE * 1.4, 0.4)
	if randf() < delta * 3.0:
		Fx.magic(center() + Vector3(randf_range(-0.8, 0.8), randf_range(0.0, 1.5), randf_range(-0.8, 0.8)), FIRE, 2)
	if _busy:
		return
	var to := hero.global_position - global_position
	if to.length() > 3.0:
		walk(to, delta)
		# Angry, it leaves fire where it walks.
		if _enraged:
			_trail -= delta
			if _trail <= 0.0:
				_trail = 1.2
				FirePatch.spawn(global_position, 0.9, 2.5)
	else:
		stand(delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _alive() -> bool:
	return is_instance_valid(self) and not dead and Game.state == Game.State.PLAYING


func _brain() -> void:
	await _wait(1.2)
	var step := 0
	while _alive():
		_busy = true
		match step % 4:
			0: await _eruption()
			1: await _rush()
			2: await _nova()
			3:
				if step % 8 == 3:
					await _kindle()
				else:
					await _rush()
		_busy = false
		step += 1
		await _wait(1.0 if _enraged else 1.6)


## Circles at the hero and around them that burst into lingering fire.
func _eruption() -> void:
	var hero := Game.hero
	if hero == null:
		return
	if not visual.play_named("Spellcast_Raise"):
		visual.attack(true)
	Sfx.play("ignite", 0.7)
	var n := 6 if _enraged else 4
	var source := kind_name()
	for i in n:
		if not _alive() or Game.hero == null:
			return
		var spot := Game.hero.global_position
		if i > 0:
			spot += Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5))
		spot = Room.current.resolve_move(spot, Vector3.ZERO, 0.5)
		track(Telegraph.circle(spot, 1.7, 1.1, func(): _burst(spot, 1.7, 18.0, source)))
		await _wait(0.3)
	await _wait(1.0)


static func _burst(spot: Vector3, r: float, dmg: float, source: String) -> void:
	Fx.magic(spot + Vector3.UP * 0.3, FIRE, 30)
	Fx.shockwave(spot, FIRE, r)
	Sfx.play("boom", 0.7)
	Game.shake(0.15)
	FirePatch.spawn(spot, r * 0.65, 3.0)
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - spot
	d.y = 0.0
	if d.length() < r + hero.radius * 0.5:
		Game.hit_source = source
		hero.take_damage(dmg, d, 8.0)


## A long run at the hero that leaves its path on fire.
func _rush() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	d = d.normalized()
	var wind := 0.65 if _enraged else 0.9
	track(Telegraph.line(global_position, d, 12.0, radius * 2.2, wind, Callable()))
	Sfx.play("roar", 0.5)
	var t := 0.0
	while t < wind:
		if not _alive():
			return
		face(d, 20.0, get_process_delta_time())
		await get_tree().process_frame
		t += get_process_delta_time()
	visual.attack()
	contact_damage = 22.0
	t = 0.0
	var drop := 0.0
	while t < 0.75:
		if not _alive():
			contact_damage = 18.0   # a pause mid-rush must not leave the rush's touch damage on
			return
		var dt := get_process_delta_time()
		move_by(d * 15.0 * dt, dt)
		drop -= dt
		if drop <= 0.0:
			drop = 0.11
			FirePatch.spawn(global_position, 0.85, 3.5 if _enraged else 2.5)
		await get_tree().process_frame
		t += dt
	contact_damage = 18.0
	Game.shake(0.3)
	Fx.dust(global_position, 25)
	await _wait(0.7)


## A circle fills around it, it slams the floor, and rings of slow fireballs roll outward.
func _nova() -> void:
	var source := kind_name()
	var here := global_position
	var r := 3.2
	track(Telegraph.circle(here, r, 0.95, func(): _slam(here, r, source)))
	if not visual.play_named("1H_Melee_Attack_Jump_Chop"):
		visual.attack()
	await _wait(1.0)
	var waves := 3 if _enraged else 2
	var count := 18 if _enraged else 14
	for w in waves:
		if not _alive():
			return
		var offset := w * (PI / count) + randf() * 0.3
		for i in count:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, offset + i * TAU / count)
			Projectile.fire(Team.UNDEAD, global_position + Vector3.UP + dir * 1.2, dir, 11.0, 5.5, SHOT, 0.34, DISPLAY_NAME)
		Sfx.play("shoot", 0.8)
		await _wait(0.55)
	await _wait(0.6)


func _slam(at: Vector3, r: float, source: String) -> void:
	Game.shake(0.45)
	Sfx.play("boom", 0.9)
	Fx.shockwave(at, FIRE, r)
	Fx.dust(at, 30)
	Fx.magic(at + Vector3.UP * 0.4, FIRE, 30)
	var hero := Game.hero
	if hero == null or not _alive():
		return
	var d := hero.global_position - at
	d.y = 0.0
	if d.length() < r + hero.radius * 0.5:
		Game.hit_source = source
		hero.take_damage(16.0, d, 12.0)


## Cinder Skeletons climb out of the floor beside it.
func _kindle() -> void:
	if not visual.play_named("Spellcast_Summon"):
		visual.attack(true)
	Sfx.play("roar", 0.6)
	Sfx.play("ignite", 0.7)
	var n := 2 if _enraged else 1
	for i in n:
		if Game.alive_enemies >= 3:   # itself and at most two Cinder Skeletons
			break
		var off := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / n + randf_range(-0.3, 0.3)) * 3.2
		var spot := Room.current.resolve_move(global_position + off, Vector3.ZERO, 0.4)
		FirePatch.spawn(spot, 0.7, 1.5)
		Game.spawn_enemy("e", spot)
	await _wait(1.0)


func _on_death() -> void:
	Sfx.play("roar", 0.8)
	Sfx.play("ignite", 0.9)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	if _flame:
		_flame.create_tween().tween_property(_flame, "scale", Vector3.ZERO, 0.6)
	Fx.magic(center(), FIRE, 50)
	Fx.shockwave(global_position, FIRE, 5.0)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
