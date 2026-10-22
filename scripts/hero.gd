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
## From the Armory: survive one killing blow per run.
var second_wind := false
## Blessings that aren't plain numbers.
var frost := false
var magnet := 1.0
var coin_bonus := 0.0
## Bone Ward: hits blocked per room, and how many are left in this room.
var ward_max := 0
var ward := 0
var _ward_bubble: MeshInstance3D

## Dash: flick your thumb (or press Space) to zip a short way, untouchable while dashing.
const DASH_SPEED := 21.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 1.1
var _dash_left := 0.0
var _dash_cooldown := 0.0
var _dash_dir := Vector3.ZERO
var _trail_t := 0.0

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
	lantern.light_energy = 0.9
	lantern.omni_range = 8.0
	lantern.position = Vector3(0, 3.6, 0.6)   # high and slightly behind, so the hood isn't blown out
	h.add_child(lantern)
	return h


func place_at(pos: Vector3) -> void:
	global_position = pos
	rotation = Vector3.ZERO
	knockback = Vector3.ZERO
	_shot_timer = 0.4


func can_be_hit() -> bool:
	return not dead and _invulnerable <= 0.0 and _dash_left <= 0.0 and Game.state == Game.State.PLAYING


func dash_ready() -> bool:
	return _dash_cooldown <= 0.0


## Start a dash along `dir` (on the floor). Does nothing while it's recharging.
func dash(dir: Vector3) -> void:
	dir.y = 0.0
	if dead or not dash_ready() or dir.length_squared() < 0.01 or Game.state != Game.State.PLAYING:
		return
	_dash_dir = dir.normalized()
	_dash_left = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	_trail_t = 0.0
	knockback = Vector3.ZERO
	rotation.y = atan2(-_dash_dir.x, -_dash_dir.z)
	Sfx.play("dash", 0.7)
	Fx.dust(global_position, 10)


func on_kill() -> void:
	if heal_on_kill > 0.0:
		heal(heal_on_kill)


func _process(delta: float) -> void:
	if dead:
		return
	_update_ward_bubble()
	_dash_cooldown -= delta
	if _dash_left > 0.0:
		_dash_left -= delta
		move_by(_dash_dir * DASH_SPEED * delta, delta)
		visual.set_moving(true)
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.025
			Fx.trail(center(), Color(0.45, 0.8, 1.0))
		_shot_timer = maxf(_shot_timer, 0.1)
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
	p.frost = frost


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if not can_be_hit():
		return
	if ward > 0:
		ward -= 1
		_invulnerable = 0.7
		Fx.magic(center(), Color(0.8, 0.9, 1.0), 24)
		Sfx.play("upgrade", 0.6)
		Game.shake(0.2)
		return
	if second_wind and amount * Game.damage_scale() >= health:
		second_wind = false
		health = max_health * 0.5
		_invulnerable = 2.0
		Fx.magic(center(), Color(1, 0.9, 0.5), 50)
		Sfx.play("victory", 0.6)
		Game.shake(0.4)
		Game.hud.banner("Second Wind!", Color(1, 0.9, 0.5))
		return
	super.take_damage(amount * Game.damage_scale(), direction, push, crit)
	if dead:
		return
	Sfx.play("hurt")
	Input.vibrate_handheld(45)
	Game.shake(0.35)
	Game.hit_stop(0.06)
	_invulnerable = 0.7


## Refills Bone Ward at the start of each room.
func new_room() -> void:
	ward = ward_max


## A faint bubble around the hero while Bone Ward is up.
func _update_ward_bubble() -> void:
	if ward <= 0 or dead:
		if _ward_bubble:
			_ward_bubble.visible = false
		return
	if _ward_bubble == null:
		var mat := U.unlit(Color(0.7, 0.85, 1.0, 0.18))
		_ward_bubble = U.sphere(self, 0.95, mat, Vector3(0, 1.0, 0))
		_ward_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ward_bubble.visible = true
	var s := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.04
	_ward_bubble.scale = Vector3(s, s, s)


func _on_death() -> void:
	visual.set_visible_blink(true)
	visual.die()
	Sfx.play("hurt")
	Game.shake(0.6)
	Game.on_hero_died()
