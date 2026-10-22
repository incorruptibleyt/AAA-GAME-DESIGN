class_name Enemy
extends Actor
## Shared skeleton behaviour: rising out of the floor, pushing apart from each other,
## contact damage, health bar and death. Each type overrides _setup() and _think().

var move_speed := 2.5
var contact_damage := 10.0
var knockback_scale := 1.0
## Chance of dropping a healing heart when destroyed.
var drop_chance := 0.18
## Bosses use the big bar at the top of the screen instead of a little one.
var is_boss := false
## Elite skeletons are golden, bigger and tougher, and drop more coins.
var elite := false

var _slow_left := 0.0

var _spawn_timer := 0.9
var _contact_cooldown := 0.0
var _bar: HealthBar
var _telegraphs: Array[Telegraph] = []


static func create(kind: String, parent: Node, pos: Vector3) -> Enemy:
	var e: Enemy
	match kind:
		"w": e = SkeletonWarrior.new()
		"a": e = SkeletonArcher.new()
		"g": e = SkeletonMage.new()
		"K": e = SkeletonKing.new()
		"L": e = Lich.new()
		"x": e = SkeletonBomber.new()
		"t": e = BoneSpitter.new()
		_: e = SkeletonMinion.new()
	e.team = Team.UNDEAD
	parent.add_child(e)
	e.global_position = pos
	e._setup()
	# Deeper floors make skeletons tougher and a little quicker.
	e.init_health(e.max_health * Game.health_scale())
	e.move_speed *= Game.speed_scale()
	e._bar = HealthBar.attach(e)
	Fx.dust(pos, 18)
	return e


func _setup() -> void:
	pass


func display_name() -> String:
	return "Skeleton"


## Turns this skeleton into a golden elite.
func make_elite() -> void:
	elite = true
	init_health(max_health * 2.2)
	contact_damage *= 1.3
	knockback_scale *= 0.5
	radius *= 1.15
	drop_chance = maxf(drop_chance, 0.5)
	visual.scale *= 1.22
	visual.set_tint(Color(0.32, 0.22, 0.0))
	var glow := U.floor_quad(self, Vector2(2.4, 2.4), U.unlit(Color(1, 0.75, 0.2, 0.45), U.soft_circle()), Vector3(0, 0.05, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _bar:
		_bar.queue_free()
		_bar = HealthBar.attach(self)


## Frost Bolts: walk slower for a moment.
func chill(seconds: float) -> void:
	if _slow_left <= 0.0:
		Fx.magic(center(), Color(0.6, 0.9, 1.0), 8)
	_slow_left = maxf(_slow_left, seconds)


## Coins dropped when destroyed. Deeper floors pay a little more.
func coin_value() -> int:
	if elite:
		return 6 + 2 * (Game.floor_num - 1)
	var base := 20 if is_boss else (1 if max_health < 30.0 * Game.health_scale() else 2)
	return base + (Game.floor_num - 1) * (5 if is_boss else 0) + (1 if not is_boss and randf() < 0.1 * (Game.floor_num - 1) else 0)


func _think(_hero: Hero, _delta: float) -> void:
	pass


static func bones(key: String, height: float, eyes: Color) -> Dictionary:
	return {"key": key, "height": height, "body": Color(0.88, 0.86, 0.78), "accent": Color(0.3, 0.27, 0.3), "eyes": eyes}


func ready_to_fight() -> bool:
	return _spawn_timer <= 0.0


## Can't be hit (or targeted) while still climbing out of the floor.
func can_be_hit() -> bool:
	return not dead and ready_to_fight()


func _process(delta: float) -> void:
	if dead:
		return
	if _spawn_timer > 0.0:
		_spawn_timer -= delta
		var k := 1.0 - clampf(_spawn_timer / 0.9, 0.0, 1.0)
		visual.position.y = -(1.0 - k) * 1.8
		return
	visual.position.y = 0.0
	_slow_left -= delta

	var hero := Game.hero
	if Game.state != Game.State.PLAYING or hero == null or hero.dead:
		stand(delta)
		return
	_think(hero, delta)
	_separate()
	_touch(hero, delta)


func _separate() -> void:
	for a in Actor.all:
		if a == self or a.team != team or a.dead:
			continue
		var d := global_position - a.global_position
		d.y = 0.0
		var m := radius + a.radius
		var sq := d.length_squared()
		if sq < m * m and sq > 0.0001:
			var len := sqrt(sq)
			var push_out := d / len * (m - len) * 0.5
			global_position = Room.current.resolve_move(global_position, push_out, radius) if Room.current else global_position + push_out


func _touch(hero: Hero, delta: float) -> void:
	_contact_cooldown -= delta
	if contact_damage <= 0.0 or _contact_cooldown > 0.0:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	var reach := radius + hero.radius + 0.1
	if d.length_squared() < reach * reach:
		_contact_cooldown = 0.8
		hero.take_damage(contact_damage, d, 9.0)


func walk(dir: Vector3, delta: float, speed_scale := 1.0) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		stand(delta)
		return
	dir = dir.normalized()
	if Room.current:
		dir = Room.current.steer(global_position, dir, radius)
	if _slow_left > 0.0:
		speed_scale *= 0.55
	move_by(dir * move_speed * speed_scale * delta, delta)
	face(dir, 10.0, delta)
	visual.set_moving(true)


func stand(delta: float) -> void:
	visual.set_moving(false)
	move_by(Vector3.ZERO, delta)


func track(t: Telegraph) -> Telegraph:
	_telegraphs = _telegraphs.filter(func(x): return is_instance_valid(x))
	_telegraphs.append(t)
	return t


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if not can_be_hit():
		return
	super.take_damage(amount, direction, push * knockback_scale, crit)
	if _bar:
		_bar.reveal()


func _on_death() -> void:
	for t in _telegraphs:
		if is_instance_valid(t):
			t.cancel()
	_telegraphs.clear()
	visual.die()
	Fx.bones(global_position)
	Sfx.play("die", 0.8)
	Game.hit_stop(0.035)
	Game.shake(0.12)
	if _bar:
		_bar.queue_free()
	if Game.hero:
		Game.hero.on_kill()
	if randf() < drop_chance + (Game.heart_bonus if drop_chance > 0.0 else 0.0):
		Pickup.drop(global_position)
	var coins := coin_value()
	if Game.hero and coins > 0:
		coins = roundi(coins * (1.0 + Game.hero.coin_bonus))
	Pickup.drop_coins(global_position, coins)
	Game.on_enemy_died(self)
	get_tree().create_timer(2.5, false).timeout.connect(queue_free)
