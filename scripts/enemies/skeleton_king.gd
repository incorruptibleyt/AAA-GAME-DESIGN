class_name SkeletonKing
extends Enemy
## The boss at the end of the floor. Four attacks in a shuffled order, each with a clear
## warning; below half health it gets faster and adds the Royal Rush (three charges and a ring).

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
	look.weapon = "Skeleton_Axe"
	look.offhand = "Skeleton_Shield_Large_A"
	look.attack_anim = "1H_Melee_Attack_Chop"
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
		phase_two(Color(1, 0.3, 0.2), "rush", "Royal Rush")
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
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["ring", "charge", "meteors", "summon"]
		if _enraged:
			moves.append("rush")   # phase 2's own move
		match next_move(moves):
			"ring": await _bone_ring()
			"charge": await _charge()
			"meteors": await _meteors()
			"summon": await _summon()
			"rush": await _royal_rush()
		_busy = false
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
			Projectile.fire(Team.UNDEAD, global_position + Vector3.UP + d * 1.1, d, 12.0, 6.5, Color(1, 0.35, 0.25), 0.28, DISPLAY_NAME)
		Sfx.play("shoot", 0.8)
		await _wait(0.45)


## Phase 2: three charges back to back, each aimed again, the last one ending in a ring.
## In the tutorial (version 121) it is two slower charges and no ring, so a new player
## sees the idea without being overwhelmed.
## Version 149 (difficulty review, fix 5): every King fight shows this move since version
## 147, and the King lands the most final blows. A longer breath between charges (0.35 s,
## was 0.15) means the dash (1.1 s to recharge) is always back for the next one, and each
## charge in the Rush hits for 20 (a single charge still hits for 24).
const RUSH_REST := 0.35
const RUSH_HIT := 20.0
func _royal_rush() -> void:
	Sfx.play("roar", 0.7)
	var tutorial: bool = Game.first_run and Game.floor_num == 1
	for i in (2 if tutorial else 3):
		if not _alive():
			return
		await _charge(0.8 if tutorial else 0.55, 0.45 if tutorial else RUSH_REST, RUSH_HIT)
	if _alive() and not tutorial:
		await _bone_ring_once()


## One quick ring of bones (the end of the Royal Rush).
func _bone_ring_once() -> void:
	var count := 18
	for i in count:
		var d := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / count)
		Projectile.fire(Team.UNDEAD, global_position + Vector3.UP + d * 1.1, d, 12.0, 6.5, Color(1, 0.35, 0.25), 0.28, DISPLAY_NAME)
	Sfx.play("shoot", 0.8)
	await _wait(0.6)


func _charge(wind_time := -1.0, rest := 0.7, hit := 24.0) -> void:
	var hero := Game.hero
	if hero == null:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	d = d.normalized()
	var wind := wind_time if wind_time > 0.0 else (0.6 if _enraged else 0.85)
	track(Telegraph.line(global_position, d, 11.0, radius * 2.2, wind, Callable()))
	var t := 0.0
	while t < wind:
		if not _alive():
			return
		face(d, 20.0, get_process_delta_time())
		await get_tree().process_frame
		t += get_process_delta_time()
	visual.attack()
	contact_damage = hit   # 24 (was 28): on floor 5 one rush took 45% of a Mage's health
	t = 0.0
	while t < 0.6:
		if not _alive():
			contact_damage = 18.0   # a pause mid-rush must not leave the charge's touch damage on
			return
		var dt := get_process_delta_time()
		move_by(d * 17.0 * dt, dt)
		await get_tree().process_frame
		t += dt
	contact_damage = 18.0
	Game.shake(0.3)
	Fx.dust(global_position, 25)
	await _wait(rest)


func _meteors() -> void:
	var hero := Game.hero
	if hero == null:
		return
	visual.attack(true)
	var n := 4 if _enraged else 3
	var source := kind_name()   # reported as the King's damage, not a skeleton mage's
	for i in n:
		if not _alive():
			return
		var spot := hero.global_position
		if i > 0:
			spot += Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		spot = Room.current.resolve_move(spot, Vector3.ZERO, 0.5)
		track(Telegraph.circle(spot, 1.9, 1.1, func(): SkeletonMage.explode(spot, 1.9, 20.0, source)))
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
