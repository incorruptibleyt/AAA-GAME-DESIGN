class_name Projectile
extends Node3D
## Bolts and bone shards. Fly straight, hit the first actor of the other team they touch,
## and stop at walls and pillars.

var owner_team := Actor.Team.HERO
var damage := 10.0
var speed := 15.0
var radius := 0.2
var pierce := 0
var push := 4.0
var crit_chance := 0.0
## How much a critical hit multiplies the damage (Backstab makes it 3).
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
static func fire(team: int, origin: Vector3, direction: Vector3, dmg: float, spd: float, col: Color, size := 0.22, src := "Shot", style := "") -> Projectile:
	var hero_shot := team == Actor.Team.HERO
	if hero_shot and style == "":
		style = ShotLook.HERO_KIND.get(Game.hero.hero_id if Game.hero else "", "bolt")
	# Undead orbs put their floor glow at the height they were fired from.
	var key := "h%s|%s|%.3f" % [style, col.to_html(), size] if hero_shot else "u%.3f|%.1f" % [size, origin.y]
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
			p._look = ShotLook.danger(p, maxf(size, 0.2) * 1.3, origin.y)
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
	var next := global_position + dir * speed * delta
	# Hero bolts check the whole stretch they flew this frame. The first frame starts back at
	# the hero (bolts appear a little in front), so a skeleton pressed right up against the
	# hero is hit too instead of being shot past.
	var from := global_position
	if _first_frame and owner_team == Actor.Team.HERO:
		from -= dir * 0.6
	_first_frame = false
	if life <= 0.0 or (Room.current and Room.current.blocks_shot(next, radius * 0.5)):
		Fx.sparks(global_position, Color(1, 0.85, 0.5) if owner_team == Actor.Team.HERO else DANGER)
		Fx.impact(global_position, _col, radius * 3.0)
		finish()
		return
	global_position = next

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
		_hit[a] = true
		var crit := randf() < crit_chance
		Fx.impact(Vector3(next.x, global_position.y, next.z), Color.WHITE.lerp(_col, 0.5) if crit else _col, radius * (6.0 if crit else 4.0))
		if a is Hero:
			Game.hit_source = source
		a.take_damage(damage * crit_mult if crit else damage, dir, push, crit)
		if burn_dps > 0.0 and not a.dead:
			Burning.apply(a, burn_dps, 2.5)
		elif crit and owner_team == Actor.Team.HERO and not a.dead and Game.hero and Game.hero.perks.has("flashfire"):
			Burning.apply(a, 8.0, 2.5)   # Flashfire
		if frost and not a.dead and a is Enemy:
			(a as Enemy).chill(Game.hero.frost_time if Game.hero else 1.5)
		if splash > 0.0:
			_explode(next, target, a)
		if owner_team == Actor.Team.HERO:
			Sfx.play("hit", 0.6)
		# Deadeye: critical hits keep flying through.
		if not (crit and owner_team == Actor.Team.HERO and Game.hero and Game.hero.perks.has("deadeye")):
			pierce -= 1
		if pierce < 0:
			finish()
			return


func _touches(a: Actor, target: int, from: Vector3, next: Vector3) -> bool:
	if a.team != target or not a.can_be_hit() or _hit.has(a):
		return false
	var reach := a.radius + radius
	var dist_sq := _flat_dist_sq(a.global_position, from, next) if owner_team == Actor.Team.HERO \
			else Vector2(a.global_position.x - next.x, a.global_position.z - next.z).length_squared()
	return dist_sq <= reach * reach


func _explode(at: Vector3, target: int, already: Actor) -> void:
	Fx.magic(at + Vector3.UP * 0.4, Color(0.8, 0.45, 1.0), 22)
	Fx.shockwave(at, Color(0.7, 0.4, 1.0), splash)
	for a: Actor in Actor.all.duplicate():
		if a == already or a.team != target or not a.can_be_hit():
			continue
		var d := a.global_position - at
		d.y = 0.0
		if d.length() < splash + a.radius:
			a.take_damage(damage * 0.6, d, push * 0.5)
