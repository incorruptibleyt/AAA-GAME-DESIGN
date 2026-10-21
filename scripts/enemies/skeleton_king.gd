class_name SkeletonKing
extends Enemy
## The boss at the end of the floor. Cycles through four attacks, each with a clear
## warning, and gets faster and angrier below half health.

const DISPLAY_NAME := "The Skeleton King"

var _enraged := false
var _started := false
var _busy := false


func _setup() -> void:
	is_boss = true
	init_health(750.0)
	drop_chance = 0.0
	move_speed = 1.8
	contact_damage = 18.0
	radius = 1.15
	center_height = 1.8
	knockback_scale = 0.08
	var key := Art.SKELETON_GOLEM if Art.has_model(Art.SKELETON_GOLEM) else Art.SKELETON_WARRIOR
	var look := bones(key, 4.0, Color(1.0, 0.25, 0.15))
	look.crown = true
	look.horns = true
	make_visual(look)


func display_name() -> String:
	return DISPLAY_NAME


func _think(hero: Hero, delta: float) -> void:
	if not _started:
		_started = true
		Sfx.play("roar")
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.35
		Sfx.play("roar")
		Game.shake(0.4)
		Fx.magic(center(), Color(1, 0.3, 0.2), 40)
	if not _busy:
		var to := hero.global_position - global_position
		if to.length() > 2.5:
			walk(to, delta)
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
			0: await _bone_ring()
			1: await _charge()
			2: await _meteors()
			3: await _summon()
		_busy = false
		step += 1
		await _wait(1.0 if _enraged else 1.6)


func _bone_ring() -> void:
	visual.attack(true)
	Fx.magic(center(), Color(1, 0.3, 0.2), 20)
	await _wait(0.6)
	var waves := 4 if _enraged else 3
	var count := 20 if _enraged else 16
	for w in waves:
		if not _alive():
			return
		var offset := w * (PI / count)
		for i in count:
			var d := Vector3.FORWARD.rotated(Vector3.UP, offset + i * TAU / count)
			Projectile.fire(Team.UNDEAD, global_position + Vector3.UP + d * 1.1, d, 12.0, 6.5, Color(1, 0.35, 0.25), 0.28)
		Sfx.play("shoot", 0.8)
		await _wait(0.45)


func _charge() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	d = d.normalized()
	track(Telegraph.line(global_position, d, 11.0, radius * 2.2, 0.6 if _enraged else 0.85, Callable()))
	var t := 0.0
	var wind := 0.6 if _enraged else 0.85
	while t < wind:
		if not _alive():
			return
		face(d, 20.0, get_process_delta_time())
		await get_tree().process_frame
		t += get_process_delta_time()
	visual.attack()
	contact_damage = 28.0
	t = 0.0
	while t < 0.6:
		if not _alive():
			return
		var dt := get_process_delta_time()
		move_by(d * 17.0 * dt, dt)
		await get_tree().process_frame
		t += dt
	contact_damage = 18.0
	Game.shake(0.3)
	Fx.dust(global_position, 25)
	await _wait(0.7)


func _meteors() -> void:
	var hero := Game.hero
	if hero == null:
		return
	visual.attack(true)
	var n := 5 if _enraged else 3
	for i in n:
		if not _alive():
			return
		var spot := hero.global_position
		if i > 0:
			spot += Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		spot = Room.current.resolve_move(spot, Vector3.ZERO, 0.5)
		track(Telegraph.circle(spot, 1.9, 1.1, func(): SkeletonMage.explode(spot, 1.9, 20.0)))
		await _wait(0.25)
	await _wait(0.9)


func _summon() -> void:
	visual.attack(true)
	Sfx.play("roar", 0.6)
	var n := 4 if _enraged else 2
	for i in n:
		if Game.alive_enemies >= 7:
			break
		var off := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / n + randf_range(-0.3, 0.3)) * 3.0
		var spot := Room.current.resolve_move(global_position + off, Vector3.ZERO, 0.4)
		Game.spawn_enemy("m", spot)
	await _wait(1.0)


func _on_death() -> void:
	Sfx.play("roar", 0.8)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
