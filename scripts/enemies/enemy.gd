class_name Enemy
extends Actor
## Shared skeleton behaviour: rising out of the floor, pushing apart from each other,
## contact damage, health bar and death. Each type overrides _setup() and _think().

var move_speed := 2.5
var contact_damage := 10.0
var knockback_scale := 1.0
## Chance of dropping a healing heart when destroyed.
var drop_chance := 0.09
## Bosses use the big bar at the top of the screen instead of a little one.
var is_boss := false
## Elite skeletons are purple, bigger and tougher, and drop more coins.
var elite := false

var _slow_left := 0.0

## Seconds a melee skeleton winds up a swipe before its touch hurts: a small warning circle
## fills in front of it, so a step aside or a Grave Dash answers it (and dashing out of it
## is a PERFECT). 0 = the old instant touch, for attacks that have their own warning
## (a warrior's lunge, a spider's leap, a boss's rush, a Drowned Skeleton's burst).
var swipe_time := 0.0
## A swipe starts this much further out than the touch itself.
const SWIPE_REACH := 0.35
const SWIPE_RADIUS := 0.75
var _swipe: Telegraph
## A big hit staggers a skeleton briefly: it stands still and starts no new attack.
const FLINCH_TIME := 0.12
var _flinch_left := 0.0
var _swipe_dir := Vector3.FORWARD

var _spawn_timer := 0.9
var _contact_cooldown := 0.0
var _bar: HealthBar
var _telegraphs: Array[Telegraph] = []
## Seconds spent somewhere the hero's shots can't reach (past a wall or inside a pillar).
var _out_time := 0.0


## Bosses wear the cartoon outline, like the hero (character_visual.gd).
func wants_outline() -> bool:
	return is_boss


static func create(kind: String, parent: Node, pos: Vector3) -> Enemy:
	var e: Enemy
	match kind:
		"w": e = SkeletonWarrior.new()
		"a": e = SkeletonArcher.new()
		"g": e = SkeletonMage.new()
		"K": e = SkeletonKing.new()
		"L": e = Lich.new()
		"C": e = CinderColossus.new()
		"x": e = SkeletonBomber.new()
		"t": e = BoneSpitter.new()
		"s": e = BoneSpider.new()
		"f": e = FrostWraith.new()
		"e": e = CinderSkeleton.new()
		"d": e = DrownedSkeleton.new()
		"T": e = Tidecaller.new()
		_: e = SkeletonMinion.new()
	e.team = Team.UNDEAD
	parent.add_child(e)
	e.global_position = pos
	e._setup()
	# Deeper floors make skeletons tougher and a little quicker.
	# Bosses get an extra 30% per floor on top, so deep bosses are a real fight. The tutorial's
	# King has 70%.
	var boss_scale := (1.0 + 0.3 * (Game.floor_num - 1)) * (0.7 if Game.first_run else 1.0)
	e.init_health(e.max_health * Game.health_scale() * (boss_scale if e.is_boss else 1.0))
	e.move_speed *= Game.speed_scale()
	e._bar = HealthBar.attach(e)
	Fx.dust(pos, 18)
	return e


func _setup() -> void:
	pass


func display_name() -> String:
	return "Skeleton"


## A readable name for this kind of skeleton, e.g. "Skeleton Warrior" (for the run report).
func kind_name() -> String:
	if is_boss:
		return display_name()
	var n := str(get_script().get_global_name())
	var out := ""
	for i in n.length():
		if i > 0 and n[i] == n[i].to_upper() and n[i] != n[i].to_lower():
			out += " "
		out += n[i]
	return ("Elite " if elite else "") + out


## Turns this skeleton into a purple elite (gold until version 116, the colour of coins and
## of the Crypt Pass hero).
func make_elite() -> void:
	elite = true
	init_health(max_health * 2.2)
	contact_damage *= 1.3
	knockback_scale *= 0.5
	radius *= 1.15
	drop_chance = maxf(drop_chance, 0.5)
	visual.scale *= 1.22
	visual.set_tint(Color(0.22, 0.04, 0.32))
	var glow := U.floor_quad(self, Vector2(2.4, 2.4), U.unlit(Color(0.7, 0.3, 1.0, 0.5), U.soft_circle()), Vector3(0, 0.05, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _bar:
		_bar.queue_free()
		_bar = HealthBar.attach(self)


## Elites hit 30% harder (make_elite). Skeletons that change their touch damage mid-fight
## (a pounce, a lunge, coming up out of the water) multiply by this so elites keep it.
func elite_mult() -> float:
	return 1.3 if elite else 1.0


## Its boss has fallen: it crumbles at once, even while still climbing out of the floor
## (or, for a Drowned Skeleton, under the water), when it can't otherwise be hit.
func crumble() -> void:
	if dead:
		return
	_spawn_timer = 0.0
	visual.position.y = 0.0
	_surface()
	take_damage(Actor.KILL, Vector3.ZERO, 0.0)


## Back up where it can be hit (only Drowned Skeletons ever go under).
func _surface() -> void:
	pass


## Pyre and Shatter: burning or chilled skeletons take their neighbours with them.
func _death_burst(h: Hero) -> void:
	var burning := get_node_or_null("Burning") != null
	var pyre := burning and h.perks.has("pyre")
	var shatter := _slow_left > 0.0 and h.perks.has("shatter")
	if not pyre and not shatter:
		return
	var at := global_position
	var col := Color(1, 0.5, 0.15) if pyre else Color(0.6, 0.92, 1.0)
	Fx.shockwave(at, col, 2.4)
	Fx.magic(center(), col, 18)
	Sfx.play("boom" if pyre else "crack", 0.5)
	for a: Actor in Actor.all.duplicate():
		if a == self or a.team != Team.UNDEAD or not a.can_be_hit():
			continue
		var d := a.global_position - at
		d.y = 0.0
		if d.length() > 2.4 + a.radius:
			continue
		a.take_damage(15.0 + h.damage * 0.8, d, 3.0)
		if a.dead:
			continue
		if pyre:
			Burning.apply(a, h.burn_dps, 2.5)
		if shatter and a is Enemy:
			(a as Enemy).chill(h.frost_time)


## Bone Splinters: three bone shards fly out of a destroyed skeleton.
func _splinters(h: Hero) -> void:
	var turn := randf() * TAU
	for i in 3:
		var d := Vector3.FORWARD.rotated(Vector3.UP, turn + TAU * i / 3.0)
		var p := Projectile.fire(Team.HERO, global_position + Vector3.UP * 0.9 + d * 0.4, d, h.damage * 0.6 * Game.chain_damage(),
			h.bolt_speed * 0.8, Color(0.95, 0.92, 0.8), h.bolt_size * 0.8, "Shot", "shard")
		p.pierce = 1


## Frost Shots: walk slower for a moment.
func chill(seconds: float) -> void:
	if _slow_left <= 0.0:
		Fx.magic(center(), Color(0.6, 0.9, 1.0), 8)
	_slow_left = maxf(_slow_left, seconds)


## Every drop is cut to 60%, rounded up or down at random so a single coin keeps its
## worth on average. Before, one full run of floors 1-5 bought the whole Armory.
const COIN_RATE := 0.6
## The tutorial drops hearts a third more often (as every floor did before the Nov 2 update).
const FIRST_RUN_HEARTS := 4.0 / 3.0


## Coins dropped when destroyed. Deeper floors pay a little more.
func coin_value() -> int:
	if elite:
		return 4 + Game.floor_num
	if is_boss:
		return 15 + 5 * (Game.floor_num - 1)
	return 1


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
	if _flinch_left > 0.0:
		_flinch_left -= delta
		stand(delta)
	elif is_instance_valid(_swipe):
		# Rooted while the swipe winds up, facing where it will land.
		stand(delta)
		face(_swipe_dir, 20.0, delta)
	else:
		_think(hero, delta)
	_separate()
	_touch(hero, delta)
	_check_reach(delta)


## Bosses (version 119): the next move comes from a shuffled bag instead of a fixed loop,
## so the order changes every fight, and never the same move twice in a row.
var _bag: Array = []
var _last_move := ""


func next_move(moves: Array) -> String:
	if _bag.is_empty():
		_bag = moves.duplicate()
		for tries in 12:   # a few shuffles until no move follows itself
			_bag.shuffle()
			var ok: bool = _bag[0] != _last_move
			for i in _bag.size() - 1:
				if _bag[i] == _bag[i + 1]:
					ok = false
			if ok:
				break
	_last_move = str(_bag.pop_front())
	return _last_move


## Half health: the boss's second phase begins. A big red call, a shockwave and a roar, so
## the player knows a new attack is coming.
func phase_two(col: Color) -> void:
	_bag.clear()   # the new move joins at once
	Sfx.play("roar")
	Game.shake(0.5)
	Game.hit_stop(0.12)
	Fx.magic(center(), col, 40)
	Fx.shockwave(global_position, col, 3.5)
	Game.hud.callout("PHASE 2!", Color(1.0, 0.4, 0.3))


## Watchdog: a skeleton that ends up past a wall or inside a pillar for over a second climbs
## back out at a free spot in the room, so a room can always be cleared.
func _check_reach(delta: float) -> void:
	var room := Room.current
	if room == null or room.is_walkable(global_position, radius):
		_out_time = 0.0
		return
	_out_time += delta
	if _out_time > 1.0:
		_out_time = 0.0
		var spot: Vector3 = Game.rescue_spot(global_position)
		print("[watchdog] %s moved from (%.2f, %.2f) back into the room" % [kind_name(), global_position.x, global_position.z])
		global_position = spot
		knockback = Vector3.ZERO
		_cancel_attacks()   # its warning would stay at the old spot
		Fx.dust(spot, 10)


func _cancel_attacks() -> void:
	for t in _telegraphs:
		if is_instance_valid(t):
			t.cancel()
	_telegraphs.clear()
	if _swipe != null and is_instance_valid(_swipe):
		_swipe.cancel()
	_swipe = null


func _separate() -> void:
	# Add up the push from every overlapping ally, then check the walls once (a pile of 6
	# used to run the wall check 5 times per enemy per frame).
	var push := Vector3.ZERO
	for a in Actor.all:
		if a == self or a.team != team or a.dead:
			continue
		var d := global_position - a.global_position
		d.y = 0.0
		var m := radius + a.radius
		var sq := d.length_squared()
		if sq < m * m and sq > 0.0001:
			var dist := sqrt(sq)
			push += d / dist * (m - dist) * 0.5
	if push != Vector3.ZERO:
		global_position = Room.current.resolve_move(global_position, push, radius) if Room.current else global_position + push


func _touch(hero: Hero, delta: float) -> void:
	_contact_cooldown -= delta
	if contact_damage <= 0.0 or _contact_cooldown > 0.0 or is_instance_valid(_swipe) or _flinch_left > 0.0:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	var reach := radius + hero.radius + 0.1
	if swipe_time > 0.0:
		if d.length_squared() < (reach + SWIPE_REACH) * (reach + SWIPE_REACH):
			_start_swipe(d)
		return
	if d.length_squared() < reach * reach:
		_contact_cooldown = 0.8
		Game.hit_source = kind_name()
		hero.take_damage(contact_damage, d, 9.0)


func _start_swipe(d: Vector3) -> void:
	_swipe_dir = d.normalized() if d.length_squared() > 0.0001 else -global_basis.z
	var at := global_position + _swipe_dir * (radius + 0.3)
	_swipe = track(Telegraph.circle(at, SWIPE_RADIUS, swipe_time, _land_swipe, 0.22))
	_swipe.perfectable = elite or is_boss
	_swipe.light = not is_boss
	visual.attack()
	Game.on_swipe_warning()


## The swipe lands where its circle was: only a hero still inside it is hurt.
func _land_swipe() -> void:
	var t := _swipe
	_swipe = null
	_contact_cooldown = 0.8
	var hero := Game.hero
	if dead or hero == null or hero.dead or not is_instance_valid(t):
		return
	if t._covers(hero.global_position, hero.radius * 0.6):
		Game.hit_source = kind_name()
		hero.take_damage(contact_damage, _swipe_dir, 9.0)


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
	if _slow_left > 0.0 and Game.hero and Game.hero.perks.has("deepfreeze"):
		amount *= 1.3
	if health < max_health * 0.3 and Game.hero and Game.hero.perks.has("executioner"):
		amount *= 1.5
	super.take_damage(amount, direction, push * knockback_scale, crit)
	Game.note_progress()
	if _bar:
		_bar.reveal()
	# A hit worth a quarter of its health staggers it and breaks a swing still winding up.
	# Bosses never flinch, and fast weak shots can't lock a skeleton in place.
	if not dead and not is_boss and amount >= max_health * 0.25:
		_flinch_left = FLINCH_TIME
		if is_instance_valid(_swipe):
			_swipe.cancel()
			_swipe = null
			_contact_cooldown = 0.4


func _on_death() -> void:
	for t in _telegraphs:
		if is_instance_valid(t):
			t.cancel()
	_telegraphs.clear()
	visual.die()
	Fx.bones(global_position)
	# The crunch climbs as the chain grows (x3 is about two semitones up), so a good streak
	# sounds like one.
	Sfx.play("die", 0.8, 1.0 + 0.065 * clampf(Game.chain - 1.0, 0.0, 3.0))
	Game.hit_stop(0.035)
	Game.shake(0.12)
	if _bar:
		_bar.queue_free()
	if Game.hero:
		Game.hero.on_kill()
		_death_burst(Game.hero)
		if Game.hero.perks.has("splinters"):
			_splinters(Game.hero)
	var hearts := FIRST_RUN_HEARTS if Game.first_run else 1.0
	if randf() < drop_chance * hearts + (Game.heart_bonus if drop_chance > 0.0 else 0.0) and not Game.curses.has("famine"):
		Pickup.drop(global_position)
	var coins := coin_value()
	if Game.hero and coins > 0:
		coins = U.round_random(coins * COIN_RATE * (1.0 + Game.hero.coin_bonus) * Game.chain_coins() * Game.coin_mult())
	Pickup.drop_coins(global_position, coins)
	Game.on_enemy_died(self)
	get_tree().create_timer(2.5, false).timeout.connect(queue_free)
