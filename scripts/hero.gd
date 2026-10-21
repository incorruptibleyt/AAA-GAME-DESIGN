class_name Hero
extends Actor
## The player's hero. Drag your thumb to move; stand still and the hero automatically
## fires at the nearest skeleton.

# Starting numbers. Blessings (upgrades.gd) change these during a run.
var move_speed := 5.2
var damage := 12.0
var shots_per_second := 1.8
var bolt_speed := 17.0
var front_bolts := 1
var diagonal_bolts := 0
var rear_bolts := 0
var pierce := 0
var crit_chance := 0.05
var burn_dps := 0.0
var heal_on_kill := 0.0

var _shot_timer := 0.4
var _invulnerable := 0.0
var _moving := false


static func spawn(parent: Node, pos: Vector3) -> Hero:
	var h := Hero.new()
	h.name = "Hero"
	h.team = Team.HERO
	h.radius = 0.45
	h.center_height = 1.0
	h.init_health(100.0)
	parent.add_child(h)
	h.global_position = pos
	h.make_visual({"key": Art.ROGUE, "height": 2.1, "body": Color(0.25, 0.45, 0.78), "accent": Color(0.85, 0.75, 0.5), "eyes": Color(0.6, 0.9, 1.0), "hood": true,
		"hide": ["Knife", "Knife_Offhand", "2H_Crossbow", "Throwable"], "attack_anim": "1H_Ranged_Shoot"})
	# A soft light that travels with the hero so they never get lost in the dark.
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(0.75, 0.85, 1.0)
	lantern.light_energy = 1.0
	lantern.omni_range = 7.0
	lantern.position = Vector3(0, 2.2, 0)
	h.add_child(lantern)
	return h


func place_at(pos: Vector3) -> void:
	global_position = pos
	rotation = Vector3.ZERO
	knockback = Vector3.ZERO
	_shot_timer = 0.4


func can_be_hit() -> bool:
	return not dead and _invulnerable <= 0.0 and Game.state == Game.State.PLAYING


func on_kill() -> void:
	if heal_on_kill > 0.0:
		heal(heal_on_kill)


func _process(delta: float) -> void:
	if dead:
		return
	if _invulnerable > 0.0:
		_invulnerable -= delta
		visual.set_visible_blink(_invulnerable <= 0.0 or fmod(_invulnerable, 0.12) > 0.05)

	var playing := Game.state == Game.State.PLAYING
	var stick := Vector2.ZERO
	if playing:
		stick = Game.hud.joystick + Game.keyboard_move()
		stick = stick.limit_length(1.0)
	var move := Vector3(stick.x, 0, stick.y)
	_moving = move.length_squared() > 0.02
	visual.set_moving(_moving)

	if _moving:
		move_by(move * move_speed * delta, delta)
		face(move, 18.0, delta)
		_shot_timer = maxf(_shot_timer, 0.12)   # firing resumes shortly after you stop
	else:
		move_by(Vector3.ZERO, delta)
		if playing:
			_auto_attack(delta)

	if playing and Room.current and Room.current.is_at_exit(global_position):
		Game.enter_next_room()


func _auto_attack(delta: float) -> void:
	_shot_timer -= delta
	var target := _pick_target()
	if target == null:
		return
	var to := target.global_position - global_position
	face(to, 30.0, delta)
	if _shot_timer > 0.0:
		return
	_shot_timer = 1.0 / shots_per_second
	_shoot(to.normalized())


## The nearest skeleton the hero can actually hit; if every one is behind cover, just the nearest.
func _pick_target() -> Actor:
	var best: Actor = null
	var best_sq := INF
	for a: Actor in Actor.all:
		if a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		var sq := (a.global_position - global_position).length_squared()
		if Room.current and not Room.current.clear_shot(global_position, a.global_position):
			sq += 10000.0
		if sq < best_sq:
			best_sq = sq
			best = a
	return best


func _shoot(fwd: Vector3) -> void:
	visual.attack()
	Sfx.play("shoot", 0.5)
	var right := fwd.cross(Vector3.UP).normalized()
	var origin := global_position + Vector3.UP * 1.1 + fwd * 0.6
	var col := Color(1.0, 0.55, 0.2) if burn_dps > 0.0 else Color(0.55, 0.85, 1.0)
	for i in front_bolts:
		var offset := (i - (front_bolts - 1) * 0.5) * 0.35
		_fire(origin + right * offset, fwd, col)
	for i in diagonal_bolts:
		var angle := deg_to_rad(30.0 + i * 15.0)
		_fire(origin, fwd.rotated(Vector3.UP, angle), col)
		_fire(origin, fwd.rotated(Vector3.UP, -angle), col)
	for i in rear_bolts:
		_fire(global_position + Vector3.UP * 1.1 - fwd * 0.6, -fwd, col)


func _fire(origin: Vector3, d: Vector3, col: Color) -> void:
	var p := Projectile.fire(Team.HERO, origin, d, damage, bolt_speed, col)
	p.pierce = pierce
	p.crit_chance = crit_chance
	p.burn_dps = burn_dps


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if not can_be_hit():
		return
	super.take_damage(amount * Game.damage_scale(), direction, push, crit)
	if dead:
		return
	Sfx.play("hurt")
	Input.vibrate_handheld(45)
	Game.shake(0.35)
	Game.hit_stop(0.06)
	_invulnerable = 0.7


func _on_death() -> void:
	visual.set_visible_blink(true)
	visual.die()
	Sfx.play("hurt")
	Game.shake(0.6)
	Game.on_hero_died()
