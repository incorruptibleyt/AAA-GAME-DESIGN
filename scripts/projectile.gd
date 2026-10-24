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
var burn_dps := 0.0
var frost := false
## Mage orbs: on hitting something, also hurt everything nearby.
var splash := 0.0
## What fired it, for the run report ("Archer", "Lich"...).
var source := "Shot"
var life := 4.0
var dir := Vector3.FORWARD
var _hit := {}


static func fire(team: int, origin: Vector3, direction: Vector3, dmg: float, spd: float, col: Color, size := 0.22, src := "Shot") -> Projectile:
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
	p.rotation.y = atan2(-p.dir.x, -p.dir.z)
	var core := U.sphere(p, size, U.mat(col, 0.5, 4.0))
	core.scale = Vector3(1, 1, 2.6 if team == Actor.Team.HERO else 1.4)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A short glowing streak behind the bolt.
	var tail := U.sphere(p, size * 0.8, U.unlit(Color(col.r, col.g, col.b, 0.35)), Vector3(0, 0, size * 3.0))
	tail.scale = Vector3(0.7, 0.7, 4.0)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _process(delta: float) -> void:
	life -= delta
	var next := global_position + dir * speed * delta
	if life <= 0.0 or (Room.current and Room.current.blocks_shot(next, radius * 0.5)):
		Fx.sparks(global_position, Color(1, 0.85, 0.5) if owner_team == Actor.Team.HERO else Color(0.8, 0.5, 1.0))
		queue_free()
		return
	global_position = next

	var target := Actor.Team.UNDEAD if owner_team == Actor.Team.HERO else Actor.Team.HERO
	for a: Actor in Actor.all.duplicate():
		if a.team != target or not a.can_be_hit() or _hit.has(a):
			continue
		var d := a.global_position - next
		d.y = 0.0
		var reach := a.radius + radius
		if d.length_squared() > reach * reach:
			continue
		_hit[a] = true
		var crit := randf() < crit_chance
		if a is Hero:
			Game.hit_source = source
		a.take_damage(damage * 2.0 if crit else damage, dir, push, crit)
		if burn_dps > 0.0 and not a.dead:
			Burning.apply(a, burn_dps, 2.5)
		if frost and not a.dead and a is Enemy:
			(a as Enemy).chill(1.5)
		if splash > 0.0:
			_explode(next, target, a)
		if owner_team == Actor.Team.HERO:
			Sfx.play("hit", 0.6)
		pierce -= 1
		if pierce < 0:
			queue_free()
			return


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
