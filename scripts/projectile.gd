class_name Projectile
extends Node3D
## Bolts and bone shards. Fly straight, hit the first actor of the other team they touch,
## and stop at walls and pillars.

var owner_team := Actor.Team.HERO
var damage := 10.0
var speed := 15.0
## Version 282 (Tweaks report #7): the longest step a shot flies in one frame.
const MAX_STEP := 0.05
var radius := 0.2
var pierce := 0
var push := 4.0
var crit_chance := 0.0
## How much a critical hit multiplies the damage.
var crit_mult := 2.0
var burn_dps := 0.0
var frost := false
## Mage orbs: on hitting something, also hurt everything nearby.
var splash := 0.0
## What fired it, for the run report ("Archer", "Lich"...).
var source := "Shot"
var life := 4.0
var dir := Vector3.FORWARD
var _hit := {}
var _first_frame := true
var _look: Node3D
var _glow: Node3D
var _glow_size := 1.0
var _age := 0.0
var _col := Color.WHITE
## The Barbarian's axe turns on this.
var spin: Node3D
## Version 234: the Barbarian's axes fly out this far (or until they run out of cuts or hit
## a wall), then turn and fly back to his hand, cutting again on the way. 0 = a normal shot.
var boomerang := 0.0
var _out := 0.0
var _back := false
var _blunt := false   # flying home with no cuts left
var _cuts := 0   # pierce at the throw: the cuts each way
var _back_t := 0.0
var _side := 1.0   # which way it swings round to come home
static var _flip := 1.0   # (axes take turns, so twin axes loop out to both sides)
## Version 235: the Mage's charged orb (0 = a plain one, up to 1): its blast booms.
var charged := 0.0
## Version 238: an undead shot that turns toward the hero, up to this many radians a second
## (the returning Lich's Seeking Souls). 0 flies straight.
var seek := 0.0
## Version 239 (whole-game review fix 8, hero blessings that change the attack):
## Ricochet: after its last hit the shot flies on at the nearest other skeleton, this many times.
var bounce := 0
const BOUNCE_RANGE := 7.0
## Version 307, Bouncing Shots: times a hero shot still bounces off a wall or pillar.
var wall_bounce := 0
## Shadow Quiver (version 308): seconds until this knife turns round and flies back to the
## hero, cutting again on the way (0 = it doesn't).
var recall := 0.0
const QUIVER_TURN_COL := Color(0.75, 0.5, 1.0)
var _recall_pierce := 0
## Buzzsaw: where an axe turns for home it first hangs this long, spinning and grinding
## every skeleton beside it (each tick a share of its damage).
var hang := 0.0
var _hang_left := 0.0
var _hang_from: Actor
var _grind_t := 0.0
const GRIND_EVERY := 0.15
const GRIND_SHARE := 0.3
const GRIND_R := 1.0

## Undead shots share one look on every floor (see ShotLook).
const DANGER := ShotLook.DANGER
## Undead shots in flight, for Grave Dash to check against.
static var danger: Array[Projectile] = []

## Version 126 (audit #5): a finished shot waits here, look and all, to be fired again
## instead of building a new one (a Mage with Fan of Shots fires dozens a second). Shots
## are pooled by look: team, style, colour and size.
static var _pool := {}
static var _pool_holder: Node3D
const POOL_CAP := 32   # finished shots kept per look
const POOL_TOTAL := 96   # and in all (kept small: low-memory phones)
static var _pooled := 0
var _key := ""
var _spent := false


## `style` picks a hero shot's look ("shard" for bone shards); empty means the hero's own.
## For an undead shot it picks what is in the orb's middle (ShotLook.SHOT_KIND, version 370).
static func fire(team: int, origin: Vector3, direction: Vector3, dmg: float, spd: float, col: Color, size := 0.22, src := "Shot", style := "") -> Projectile:
	var hero_shot := team == Actor.Team.HERO
	if hero_shot and style == "":
		style = ShotLook.HERO_KIND.get(Game.hero.hero_id if Game.hero else "", "bolt")
	# Undead orbs put their floor glow at the height they were fired from.
	var key := "h%s|%s|%.3f" % [style, col.to_html(), size] if hero_shot else "u%s|%.3f|%.1f" % [style, size, origin.y]
	var p := _take(key)
	var fresh := p == null
	if fresh:
		p = Projectile.new()
		p._key = key
		p.tree_exiting.connect(func(): danger.erase(p))
	p.source = src
	direction.y = 0.0
	p.dir = direction.normalized()
	p.owner_team = team
	p.damage = dmg
	p.speed = spd
	p.radius = size
	var parent: Node = Room.current if Room.current else Game.world
	parent.add_child(p)
	p.global_position = origin
	if not hero_shot:
		danger.append(p)
	p.rotation.y = atan2(-p.dir.x, -p.dir.z)
	p._col = col if hero_shot else DANGER
	if fresh:
		if hero_shot:
			p._glow = ShotLook.hero(p, style, col, size, origin.y)
			if p._glow:
				p._glow_size = p._glow.scale.x
		else:
			p._look = ShotLook.danger(p, maxf(size, 0.2) * 1.3, origin.y, style)
	if p._glow:
		p._glow.scale = Vector3(p._glow_size * 2.2, p._glow_size * 2.2, 1.0)   # muzzle flash: starts big, settles
	if p._look:
		p._look.scale = Vector3.ONE * 0.3
	return p


## A finished shot with this look, made ready to fly again, or null.
static func _take(key: String) -> Projectile:
	var list: Array = _pool.get(key, [])
	while not list.is_empty():
		var p: Variant = list.pop_back()
		_pooled -= 1
		if is_instance_valid(p):
			var q := p as Projectile
			q._pool_holder_leave()
			q._reset()
			return q
	return null


func _pool_holder_leave() -> void:
	if get_parent():
		get_parent().remove_child(self)


## Back to a new shot's numbers (what fire() and the shooter set again are left as is).
func _reset() -> void:
	pierce = 0
	push = 4.0
	crit_chance = 0.0
	crit_mult = 2.0
	burn_dps = 0.0
	frost = false
	splash = 0.0
	life = 4.0
	boomerang = 0.0
	charged = 0.0
	seek = 0.0
	bounce = 0
	wall_bounce = 0
	recall = 0.0
	hang = 0.0
	_hang_left = 0.0
	_hang_from = null
	_out = 0.0
	_back = false
	_blunt = false
	_hit.clear()
	_first_frame = true
	_age = 0.0
	_spent = false
	visible = true
	set_process(true)


## Done flying: hidden at once, and put away for the next shot of this look at the end of
## the frame (or freed if enough of them are waiting already).
func finish() -> void:
	if _spent:
		return
	_spent = true
	danger.erase(self)
	visible = false
	set_process(false)
	_put_away.call_deferred()


func _put_away() -> void:
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	if _key == "" or Game.world == null:
		queue_free()
		return
	var list: Array = _pool.get(_key, [])
	if list.size() >= POOL_CAP or _pooled >= POOL_TOTAL:
		queue_free()
		return
	if not is_instance_valid(_pool_holder):
		_pool_holder = Node3D.new()   # hidden and still, under the world (freed with it)
		_pool_holder.name = "ShotPool"
		_pool_holder.visible = false
		_pool_holder.process_mode = Node.PROCESS_MODE_DISABLED
		Game.world.add_child(_pool_holder)
	if get_parent():
		get_parent().remove_child(self)
	_pool_holder.add_child(self)
	list.append(self)
	_pool[_key] = list
	_pooled += 1


## Seconds until this shot would reach `pos` (a body of radius `r`), or INF if it will miss.
func time_to_hit(pos: Vector3, r: float) -> float:
	var rel := pos - global_position
	rel.y = 0.0
	var along := rel.dot(dir)
	if along < -r:
		return INF
	var side := (rel - dir * along).length()
	if side > radius + r:
		return INF
	return maxf(0.0, along - (radius + r)) / maxf(speed, 0.01)


## Shatters the shot, for a perfect dodge.
func shatter() -> void:
	Fx.sparks(global_position, Color(1, 0.95, 0.95))
	Fx.bones(global_position)
	finish()


## Squared distance on the floor from `p` to the line from `a` to `b`.
static func _flat_dist_sq(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * t).length_squared()


func _process(delta: float) -> void:
	delta = minf(delta, MAX_STEP)   # v282 (Tweaks report #7): a long frame is a short slow-down, never a jump
	if _spent:
		return
	life -= delta
	if _age < 0.12:
		_age += delta
		var k := minf(_age / 0.12, 1.0)
		if _look:
			_look.scale = Vector3.ONE * lerpf(0.3, 1.0, k)   # undead orbs swell into being
		elif _glow:
			var g := lerpf(_glow_size * 2.2, _glow_size, k)
			_glow.scale = Vector3(g, g, 1.0)
	if spin:
		spin.rotation.y -= delta * 22.0
	if _hang_left > 0.0:
		_grind(delta)
		return
	if recall > 0.0:
		recall -= delta
		if recall <= 0.0 and not _recall_home():
			return
	if _back and not _home():
		return
	if seek > 0.0 and Game.hero and not Game.hero.dead:
		var to := Game.hero.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.04:
			var turn := dir.signed_angle_to(to.normalized(), Vector3.UP)
			dir = dir.rotated(Vector3.UP, clampf(turn, -seek * delta, seek * delta))
			rotation.y = atan2(-dir.x, -dir.z)
	if ElectroMagnet.live != null and owner_team == Actor.Team.HERO:
		# v287: the Clockwork Foundry's magnet that is on bends every shot towards it.
		dir = ElectroMagnet.bend(global_position, dir, delta)
		rotation.y = atan2(-dir.x, -dir.z)
	var next := global_position + dir * speed * delta
	# Hero bolts check the whole stretch they flew this frame. The first frame starts back at
	# the hero (bolts appear a little in front), so a skeleton pressed right up against the
	# hero is hit too instead of being shot past.
	var from := global_position
	if _first_frame and owner_team == Actor.Team.HERO:
		from -= dir * 0.6
	_first_frame = false
	if boomerang > 0.0 and not _back:
		_out += speed * delta
		if _out >= boomerang or (Room.current and Room.current.blocks_shot(next, radius * 0.5)):
			if _out < boomerang:
				Fx.sparks(global_position, Color(1, 0.85, 0.5))   # off the wall and back
			_turn(null)
			return
	# Version 282 (Tweaks report #7): the whole stretch flown this frame is checked against
	# cover, not only where it ends, so a shot can't skip through a pillar on a stutter.
	if life > 0.0 and wall_bounce > 0 and not _back and boomerang <= 0.0 and Room.current \
			and (Room.current.blocks_shot(next, radius * 0.5) or not Room.current.clear_shot(global_position, next)):
		_bounce_off(next)
		return
	if life <= 0.0 or (not _back and Room.current and (Room.current.blocks_shot(next, radius * 0.5) \
			or not Room.current.clear_shot(global_position, next))):
		Fx.sparks(global_position, Color(1, 0.85, 0.5) if owner_team == Actor.Team.HERO else DANGER)
		Fx.impact(global_position, _col, radius * 3.0)
		finish()
		return
	if not FireSeam.all.is_empty() and FireSeam.burns(global_position, next):
		# v291: a wall of fire in the Ember Catacomb burns up every shot that flies into it.
		Fx.sparks(global_position, FireSeam.HOT)
		finish()
		return
	global_position = next
	if not MineGas.all.is_empty():
		MineGas.touch(next)   # v285: a shot through the Amethyst Mine's gas lights it

	var target := Actor.Team.UNDEAD if owner_team == Actor.Team.HERO else Actor.Team.HERO
	# Version 126 (audit #4): an undead shot can only hit the hero, so it checks just the
	# hero instead of every skeleton in the room.
	var hits: Array = []
	if target == Actor.Team.HERO:
		var h := Game.hero
		if h == null or not is_instance_valid(h) or not _touches(h, target, from, next):
			return
		hits = [h]
	else:
		# Most frames hit nothing: check first without copying the list (a hit can change it).
		var touching := false
		for a: Actor in Actor.all:
			if _touches(a, target, from, next):
				touching = true
				break
		if not touching:
			return
		hits = Actor.all.duplicate()
	for a: Actor in hits:
		if not _touches(a, target, from, next):
			continue
		# Version 233: the Knight's shield stops a shot from the front while he stands still.
		if a is Hero and (a as Hero).blocks_shot(dir):
			(a as Hero).on_block(Vector3(next.x, global_position.y, next.z))
			finish()
			return
		# Version 272: a Geode Guard's shield stops a shot that hits it from the front (the
		# way the shot is going this frame, so an axe on its way back can cut its back).
		if a is Enemy and (a as Enemy).blocks_shot(next - from):
			(a as Enemy).on_block(Vector3(next.x, global_position.y, next.z))
			finish()
			return
		_hit[a] = true
		var crit := randf() < crit_chance
		Fx.impact(Vector3(next.x, global_position.y, next.z), Color.WHITE.lerp(_col, 0.5) if crit else _col, radius * (6.0 if crit else 4.0))
		if a is Hero:
			Game.hit_source = source
		if _back:
			# On the way back the axe cuts from behind: a small knock away from the hero, not
			# a shove into his arms.
			var away := a.global_position - global_position if not Game.hero else a.global_position - Game.hero.global_position
			away.y = 0.0
			a.take_damage(damage * crit_mult if crit else damage, away.normalized() if away.length_squared() > 0.01 else -dir, push * 0.3, crit)
			Game._teach("barbarian_axe", "AXES: they fly back and cut again!")
		else:
			a.take_damage(damage * crit_mult if crit else damage, dir, push, crit)
		if burn_dps > 0.0 and not a.dead:
			Burning.apply(a, burn_dps, 2.5)
		elif crit and owner_team == Actor.Team.HERO and not a.dead and Game.hero and Game.hero.perks.has("flashfire"):
			Burning.apply(a, 8.0, 2.5)   # Flashfire
		if (frost or (owner_team == Actor.Team.HERO and Blizzard.heart_chill())) and not a.dead and a is Enemy:
			(a as Enemy).frost_hit(Game.hero.frost_time if Game.hero else 1.5, Game.hero)
		if owner_team == Actor.Team.HERO and Game.hero and a is Enemy:
			Game.hero.spark_from(a)   # Static Shots (version 307)
		if splash > 0.0:
			_explode(next, target, a)
		if owner_team == Actor.Team.HERO:
			Sfx.play("hit", 0.6)
		# Deadeye: critical hits keep flying through.
		if not (crit and owner_team == Actor.Team.HERO and Game.hero and Game.hero.perks.has("deadeye")):
			pierce -= 1
		if pierce < 0:
			if boomerang <= 0.0:
				if bounce > 0 and _ricochet(a):
					return
				finish()
				return
			if _back:
				_blunt = true   # out of cuts: just flies home
				return
			_turn(a)   # bounces off the last skeleton it cut and comes back
			return


func recall_after(seconds: float) -> void:
	recall = seconds
	_recall_pierce = pierce


## The knife turns for the hero and flies straight back; it may cut every skeleton again
## and is gone when it reaches the hero. False if it was put away instead.
func _recall_home() -> bool:
	var h := Game.hero
	if h == null or not is_instance_valid(h) or h.dead:
		finish()
		return false
	var to := h.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < 1.0:
		finish()
		return false
	dir = to / d
	rotation.y = atan2(-dir.x, -dir.z)
	_hit.clear()
	pierce = _recall_pierce
	life = d / maxf(speed, 1.0)
	Fx.impact(global_position, QUIVER_TURN_COL, 0.9)   # a violet pop where each knife turns
	Fx.sparks(global_position, QUIVER_TURN_COL)
	return true


## Bouncing Shots (version 307): off the wall (the room is a box) or the pillar it ran into,
## and it may hit every skeleton again.
func _bounce_off(next: Vector3) -> void:
	wall_bounce -= 1
	if owner_team == Actor.Team.HERO and Game.hero:
		Game.hero.storm_bounce(global_position)   # Storm Bounce (version 308)
	var n := Vector3.ZERO
	var half_w := Room.HALF_W - radius * 0.5
	var half_l := Room.HALF_L - radius * 0.5
	if absf(next.x) > half_w:
		n.x = -signf(next.x)
	if absf(next.z) > half_l:
		n.z = -signf(next.z)
	if n == Vector3.ZERO:
		var best := INF
		for o in Room.current.obstacles:
			var d: Vector3 = next - o.pos
			d.y = 0.0
			var gap: float = d.length() - float(o.r)
			if gap < best:
				best = gap
				n = d
	n.y = 0.0
	if n.length_squared() < 0.0001:
		n = -dir
	dir = dir.bounce(n.normalized())
	dir.y = 0.0
	dir = dir.normalized()
	rotation.y = atan2(-dir.x, -dir.z)
	_hit.clear()
	Fx.sparks(global_position, Color(1, 0.85, 0.5))
	Sfx.play("block", 0.15, 1.6)


## The axe turns for home: every skeleton can be cut once more (but not the one it just
## bounced off), with as many cuts as it was thrown with.
func _turn(bounced: Actor) -> void:
	if hang > 0.0:
		# Buzzsaw: hang here first (_grind turns it for home after).
		_hang_left = hang
		hang = 0.0
		_hang_from = bounced
		_grind_t = 0.0
		Sfx.play("swing", 0.35, 0.7)
		return
	_back = true
	_back_t = 0.0
	_flip = -_flip
	_side = _flip
	_hit.clear()
	if bounced:
		_hit[bounced] = true
	pierce = _cuts
	speed *= 1.2


## Buzzsaw: the axe hangs where it turned, spinning hard, and cuts every skeleton beside it
## a few times before it flies home.
func _grind(delta: float) -> void:
	_hang_left -= delta
	if spin:
		spin.rotation.y -= delta * 26.0   # (on top of its usual spin: a blur)
	_grind_t -= delta
	if _grind_t <= 0.0:
		_grind_t = GRIND_EVERY
		var hits := 0
		for a: Actor in Actor.all.duplicate():
			if a.team != Actor.Team.UNDEAD or not a.can_be_hit():
				continue
			var d := a.global_position - global_position
			d.y = 0.0
			if d.length() > GRIND_R + a.radius:
				continue
			var crit := randf() < crit_chance
			a.take_damage(damage * GRIND_SHARE * (crit_mult if crit else 1.0), d.normalized() if d.length_squared() > 0.01 else dir, push * 0.15, crit)
			if burn_dps > 0.0 and not a.dead:
				Burning.apply(a, burn_dps, 2.5)
			if (frost or (owner_team == Actor.Team.HERO and Blizzard.heart_chill())) and not a.dead and a is Enemy:
				(a as Enemy).chill(Game.hero.frost_time if Game.hero else 1.5)
			hits += 1
		if hits > 0:
			Fx.sparks(global_position, Color(1.0, 0.85, 0.55))
			Sfx.play("hit", 0.4, 1.25)
		else:
			Fx.sparks(global_position, Color(1.0, 0.75, 0.45) if randf() < 0.5 else _col)
	if _hang_left <= 0.0:
		_hang_left = 0.0
		var from: Actor = _hang_from if is_instance_valid(_hang_from) else null
		_hang_from = null
		_turn(from)


## Ricochet: the shot turns to the nearest other skeleton it can see (within BOUNCE_RANGE)
## instead of stopping. False if there is none.
func _ricochet(from: Actor) -> bool:
	var near: Array = []
	for b: Actor in Actor.all:
		if b == from or b.team != Actor.Team.UNDEAD or not b.can_be_hit() or _hit.has(b):
			continue
		var d2 := Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z).length_squared()
		if d2 < BOUNCE_RANGE * BOUNCE_RANGE:
			near.append([d2, b])
	if near.is_empty():
		return false
	near.sort_custom(func(x, y): return x[0] < y[0])
	var to_b: Actor = null
	for i in mini(near.size(), 3):
		if Room.current == null or Room.current.clear_shot(global_position, near[i][1].global_position):
			to_b = near[i][1]
			break
	if to_b == null:
		return false
	bounce -= 1
	pierce = 0
	var to := to_b.global_position - global_position
	to.y = 0.0
	dir = to.normalized()
	rotation.y = atan2(-dir.x, -dir.z)
	life = maxf(life, 1.2)
	Fx.sparks(global_position, _col.lerp(Color.WHITE, 0.4))
	Sfx.play("block", 0.18, 1.6)
	Game._teach("rogue_ricochet", "RICOCHET: shots bounce to the next skeleton!")
	return true


## Steers a returning axe at the Barbarian's hand; false once it is caught (or he is gone).
## It can't turn on the spot: it swings round in a tight loop (to its own side) and comes
## home along a curve, so the way back sweeps a lane beside the way out, like a boomerang.
## The turn tightens the longer it flies, so it can't circle him for ever.
func _home() -> bool:
	var h := Game.hero
	if h == null or not is_instance_valid(h) or h.dead:
		finish()
		return false
	var delta := get_process_delta_time()
	var to := h.global_position + Vector3.UP * 1.1 - global_position
	to.y = 0.0
	if to.length() < maxf(0.75, speed * delta):
		h.catch_axe(global_position)
		finish()
		return false
	_back_t += delta
	var turn := (17.0 + 20.0 * _back_t) * delta
	var ang := dir.signed_angle_to(to.normalized(), Vector3.UP)
	if absf(ang) > PI - 0.35:
		ang = PI * _side   # still heading away: keep swinging round on this axe's side
	dir = dir.rotated(Vector3.UP, clampf(ang, -turn, turn)).normalized()
	rotation.y = atan2(-dir.x, -dir.z)
	return true


func _touches(a: Actor, target: int, from: Vector3, next: Vector3) -> bool:
	if _blunt or a.team != target or not a.can_be_hit() or _hit.has(a):
		return false
	var reach := a.radius + radius
	var dist_sq := _flat_dist_sq(a.global_position, from, next) if owner_team == Actor.Team.HERO \
			else Vector2(a.global_position.x - next.x, a.global_position.z - next.z).length_squared()
	return dist_sq <= reach * reach


func _explode(at: Vector3, target: int, already: Actor) -> void:
	Fx.magic(at + Vector3.UP * 0.4, Color(0.8, 0.45, 1.0), 22)
	Fx.shockwave(at, Color(0.7, 0.4, 1.0), splash)
	if charged > 0.0:
		Sfx.play("boom", 0.3 + 0.35 * charged)
		Game.shake(0.06 + 0.1 * charged)
		Fx.magic(at + Vector3.UP * 0.6, Color(1.0, 0.85, 1.0), int(10 + 16 * charged))
		var h := Game.hero
		if owner_team == Actor.Team.HERO and h and h.perks.has("burning_ground"):
			# Version 239: Burning Ground. A bigger charge leaves a wider pool.
			FirePatch.spawn_hero(at, 1.0 + 0.8 * charged, 3.0, maxf(h.burn_dps, 6.0 + h.damage * 0.4))
			Sfx.play("ignite", 0.35)
			Game._teach("mage_ground", "BURNING GROUND: charged orbs leave fire!")
	for a: Actor in Actor.all.duplicate():
		if a == already or a.team != target or not a.can_be_hit():
			continue
		var d := a.global_position - at
		d.y = 0.0
		if d.length() < splash + a.radius:
			a.take_damage(damage * 0.6, d, push * 0.5)
