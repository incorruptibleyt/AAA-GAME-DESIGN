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


## `style` picks a hero shot's look ("shard" for bone shards); empty means the hero's own.
static func fire(team: int, origin: Vector3, direction: Vector3, dmg: float, spd: float, col: Color, size := 0.22, src := "Shot", style := "") -> Projectile:
	var p := Projectile.new()
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
	if team != Actor.Team.HERO:
		danger.append(p)
		p.tree_exiting.connect(func(): danger.erase(p))
	p.rotation.y = atan2(-p.dir.x, -p.dir.z)
	p._col = col if team == Actor.Team.HERO else DANGER
	if team == Actor.Team.HERO:
		if style == "":
			style = ShotLook.HERO_KIND.get(Game.hero.hero_id if Game.hero else "", "bolt")
		p._glow = ShotLook.hero(p, style, col, size, origin.y)
		if p._glow:
			p._glow_size = p._glow.scale.x
			p._glow.scale = Vector3(p._glow_size * 2.2, p._glow_size * 2.2, 1.0)   # muzzle flash: starts big, settles
	else:
		p._look = ShotLook.danger(p, maxf(size, 0.2) * 1.3, origin.y)
		p._look.scale = Vector3.ONE * 0.3
	return p


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
	queue_free()


## Squared distance on the floor from `p` to the line from `a` to `b`.
static func _flat_dist_sq(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * t).length_squared()


func _process(delta: float) -> void:
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
		queue_free()
		return
	global_position = next

	var target := Actor.Team.UNDEAD if owner_team == Actor.Team.HERO else Actor.Team.HERO
	# Most frames hit nothing: check first without copying the list (a hit can change it).
	var touching := false
	for a: Actor in Actor.all:
		if _touches(a, target, from, next):
			touching = true
			break
	if not touching:
		return
	for a: Actor in Actor.all.duplicate():
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
			queue_free()
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
