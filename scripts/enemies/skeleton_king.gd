class_name SkeletonKing
extends Enemy
## The boss at the end of the floor. Four attacks in a shuffled order, each with a clear
## warning; below half health it gets faster and adds the Royal Rush (three charges and a ring).

const DISPLAY_NAME := "The Skeleton King"
const KEEP_X := 3.4

var _enraged := false
var _started := false
var _busy := false
## How high the body is in the air (the King's Leap); _think puts it there each frame.
var _hop := 0.0


func _setup() -> void:
	is_boss = true
	roar_sound = "roar_king"
	init_health(750.0)
	drop_chance = 0.0
	move_speed = 1.8
	contact_damage = 18.0
	radius = 1.15
	center_height = 2.3   # (v405: he is taller now; the camera keeps his head under the top bar)
	knockback_scale = 0.08
	var key := Art.SKELETON_GOLEM if Art.has_model(Art.SKELETON_GOLEM) else Art.SKELETON_WARRIOR
	var look := bones(key, 4.7, Color(1.0, 0.25, 0.15))   # (v405: 4.0; he was barely bigger than the hero)
	look.crown = true
	look.horns = true
	# Version 405 (re-review of v400, fix 5): he was the brute grown big with a crown (the
	# brute's axe and shield). His own greatsword now (BossBodies._king), held high, and a
	# tall crown, so his outline from above is a king's.
	look.hide = ["Skeleton_Warrior_Helmet", "Skeleton_Warrior_Eyes"]   # (the brute's horned helmet: the crown alone on his skull)
	look.crown_y = 0.92
	look.crown_s = 0.85
	look.crown_tall = 1.6
	look.attack_anim = "2H_Melee_Attack_Chop"
	look.shape = {"scale": {"chest": Vector3(1.35, 1.1, 1.2), "head": 0.9, "upperarm.l": 1.25, "upperarm.r": 1.25, "upperleg.l": 0.9, "upperleg.r": 0.9}}   # (v348: a broad king)
	look.parts = "king"
	make_visual(look)


func display_name() -> String:
	return DISPLAY_NAME


func _think(hero: Hero, delta: float) -> void:
	visual.position.y = _hop
	if not _started:
		_started = true
		Sfx.play(roar_sound)
		Game.shake(0.5)
		_brain()
	if not _enraged and health < max_health * 0.5:
		_enraged = true
		move_speed *= 1.35
		phase_two(Color(1, 0.3, 0.2), "rush", "Royal Rush")
	if not _busy:
		# (v405: he walks back toward the middle, never far to the side, where the camera
		# lost half of him off the screen's edge)
		var goal := hero.global_position
		goal.x = clampf(goal.x, -KEEP_X, KEEP_X)
		var to := goal - global_position
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
	encore_first()
	while _alive():
		await roar_done()
		if not _alive():
			break
		_busy = true
		var moves := ["ring", "charge", "meteors", "summon"]
		if _enraged:
			moves.append("rush")   # phase 2's own move
		if returning():
			moves.append("encore")   # King's Leap (version 238)
		match next_move(moves):
			"ring": await _bone_ring()
			"charge": await _charge()
			"meteors": await _meteors()
			"summon": await _summon()
			"rush": await _royal_rush()
			"encore": await _kings_leap()
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
			Projectile.fire(Team.UNDEAD, global_position + Vector3.UP + d * 1.1, d, 12.0, 6.5, Color(1, 0.35, 0.25), 0.28, DISPLAY_NAME, "crown")
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
	Sfx.play(roar_sound, 0.7)
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
		Projectile.fire(Team.UNDEAD, global_position + Vector3.UP + d * 1.1, d, 12.0, 6.5, Color(1, 0.35, 0.25), 0.28, DISPLAY_NAME, "crown")
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
		await frame()
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
		await frame()
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
	Sfx.play(roar_sound, 0.6)
	var n := 4 if _enraged else 2
	for i in n:
		if Game.alive_enemies >= 7:
			break
		var off := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / n + randf_range(-0.3, 0.3)) * 3.0
		var spot := Room.current.resolve_move(global_position + off, Vector3.ZERO, 0.4)
		Game.spawn_enemy("m", spot)
	await _wait(1.0)


## Version 238, the returning King's own attack: a circle marks where he will land, he leaps
## over everything onto it and slams, and bone spikes burst out of the floor in a cross from
## where he landed (one arm at the hero). Angry, a second cross follows, turned halfway.
const LEAP_R := 2.3
const LEAP_AIR := 0.5
const SPIKE_LEN := 9.0
const SPIKE_W := 1.0
func _kings_leap() -> void:
	var hero := Game.hero
	if hero == null:
		return
	var spot: Vector3 = Room.current.resolve_move(hero.global_position, Vector3.ZERO, radius) if Room.current else hero.global_position
	var warn := 0.85 if _enraged else 1.05
	visual.attack(true)
	Sfx.play(roar_sound, 0.5, 1.25)
	track(Telegraph.circle(spot, LEAP_R, warn, Callable()))
	var from := global_position
	var t := 0.0
	while t < warn:
		if not _alive():
			_hop = 0.0
			return
		var dt := get_process_delta_time()
		var k := clampf((t - (warn - LEAP_AIR)) / LEAP_AIR, 0.0, 1.0)
		if k > 0.0:
			contact_damage = 0.0   # in the air: only the landing hurts
			global_position = from.lerp(spot, k)
			_hop = sin(k * PI) * 3.2
		face(spot - from, 12.0, dt)
		await frame()
		t += dt
	global_position = spot
	_hop = 0.0
	contact_damage = 18.0
	SkeletonMage.explode(spot, LEAP_R, 22.0, DISPLAY_NAME)
	Sfx.play("slam", 0.9)
	Game.shake(0.5)
	Fx.dust(spot, 30)
	Fx.shockwave(spot, Color(1, 0.85, 0.6), LEAP_R + 1.0)
	await _wait(0.15)
	var aim := Vector3.FORWARD
	if Game.hero:
		aim = Game.hero.global_position - spot
		aim.y = 0.0
		aim = aim.normalized() if aim.length_squared() > 0.01 else Vector3.FORWARD
	for cross in (2 if _enraged else 1):
		if not _alive():
			return
		for i in 4:
			var d := aim.rotated(Vector3.UP, i * PI / 2.0 + cross * PI / 4.0)
			var o := spot + d * 0.6
			track(Telegraph.line(o, d, SPIKE_LEN, SPIKE_W, 0.65, func(): _spikes(o, d), 0.6 if i == 0 else 0.0))
		await _wait(0.4)
	await _wait(0.9)


## Bone spikes burst along a strip.
func _spikes(o: Vector3, d: Vector3) -> void:
	SkeletonKing.strike_strip(o, d, SPIKE_LEN, SPIKE_W, 16.0, DISPLAY_NAME)
	for i in 4:
		Fx.bones(o + d * (1.2 + i * 2.2))
	Sfx.play("crack", 0.35)


func _on_death() -> void:
	Sfx.play(roar_sound, 0.8)
	Game.hit_stop(0.25)
	Game.shake(0.8)
	for i in 4:
		Fx.bones(global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	super._on_death()
