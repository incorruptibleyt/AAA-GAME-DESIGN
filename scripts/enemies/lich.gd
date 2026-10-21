class_name Lich
extends Enemy
## The boss of every second floor. A floating sorcerer who never walks: it spins spirals
## of bolts, teleports (a red circle shows where it will appear), fires aimed volleys
## and raises archers. Faster and nastier below half health.

const DISPLAY_NAME := "The Lich"

var _enraged := false
var _started := false
var _float_t := 0.0
var _hidden := false


func _setup() -> void:
	is_boss = true
	init_health(650.0)
	move_speed = 0.0
	contact_damage = 14.0
	radius = 1.0
	center_height = 1.8
	knockback_scale = 0.0
	drop_chance = 0.0
	var look := bones(Art.SKELETON_MAGE, 3.6, Color(0.4, 0.9, 1.0))
	look.hat = true
	look.crown = true
	look.accent = Color(0.18, 0.12, 0.32)
	look.weapon = "Skeleton_Staff"
	make_visual(look)


func can_be_hit() -> bool:
	return super.can_be_hit() and not _hidden


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
		Sfx.play("roar")
		Game.shake(0.4)
		Fx.magic(center(), Color(0.4, 0.9, 1.0), 40)
	_float_t += delta
	visual.position.y = 0.35 + sin(_float_t * 2.0) * 0.15
	var to := hero.global_position - global_position
	face(to, 4.0, delta)
	stand(delta)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func _alive() -> bool:
	return is_instance_valid(self) and not dead and Game.state == Game.State.PLAYING


func _brain() -> void:
	await _wait(1.2)
	var step := 0
	while _alive():
		match step % 4:
			0: await _spiral()
			1: await _teleport()
			2: await _volleys()
			3: await _raise()
		step += 1
		await _wait(0.9 if _enraged else 1.4)


func _spiral() -> void:
	visual.attack(true)
	var arms := 3 if _enraged else 2
	var spin := 0.0
	var shots := 24
	for i in shots:
		if not _alive():
			return
		for a in arms:
			var d := Vector3.FORWARD.rotated(Vector3.UP, spin + a * TAU / arms)
			Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 1.2 + d * 1.0, d, 11.0, 6.0, Color(0.4, 0.9, 1.0), 0.25)
		spin += 0.33
		if i % 3 == 0:
			Sfx.play("shoot", 0.5)
		await _wait(0.12)


func _teleport() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var spot := global_position
	for tries in 12:
		var c := Vector3(randf_range(-Room.HALF_W + 1.5, Room.HALF_W - 1.5), 0, randf_range(-Room.HALF_L + 2.0, Room.HALF_L - 3.0))
		c = Room.current.resolve_move(c, Vector3.ZERO, radius)
		if c.distance_to(hero.global_position) > 4.5:
			spot = c
			break
	track(Telegraph.circle(spot, 1.6, 0.8, Callable()))
	Fx.magic(center(), Color(0.4, 0.9, 1.0), 25)
	visual.visible = false
	_hidden = true
	await _wait(0.8)
	_hidden = false
	if not _alive():
		return
	global_position = spot
	visual.visible = true
	Fx.magic(center(), Color(0.4, 0.9, 1.0), 25)
	Sfx.play("boom", 0.6)
	var count := 14 if _enraged else 10
	for i in count:
		var d := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / count)
		Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 1.2 + d * 1.0, d, 11.0, 7.0, Color(0.5, 0.95, 1.0), 0.25)
	await _wait(0.5)


func _volleys() -> void:
	var rounds := 4 if _enraged else 3
	for r in rounds:
		var hero := Game.hero
		if not _alive() or hero == null:
			return
		visual.attack(true)
		var d := hero.global_position - global_position
		d.y = 0.0
		d = d.normalized()
		for angle in [-0.36, -0.18, 0.0, 0.18, 0.36]:
			var dir := d.rotated(Vector3.UP, angle)
			Projectile.fire(Team.UNDEAD, global_position + Vector3.UP * 1.2 + dir * 1.0, dir, 12.0, 9.0, Color(0.7, 0.5, 1.0), 0.24)
		Sfx.play("shoot", 0.8)
		await _wait(0.55)


func _raise() -> void:
	visual.attack(true)
	Sfx.play("roar", 0.6)
	var kinds := ["a", "m", "m"] if _enraged else ["a", "m"]
	for i in kinds.size():
		if Game.alive_enemies >= 7:
			break
		var off := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / kinds.size() + randf_range(-0.4, 0.4)) * 3.0
		var spot := Room.current.resolve_move(global_position + off, Vector3.ZERO, 0.5)
		Game.spawn_enemy(kinds[i], spot)
	await _wait(1.0)


func _on_death() -> void:
	visual.visible = true
	Sfx.play("roar", 0.8)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	Fx.magic(center(), Color(0.4, 0.9, 1.0), 60)
	super._on_death()
