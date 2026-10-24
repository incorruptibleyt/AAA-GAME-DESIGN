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
var _look: Node3D
var _pulse := 0.0

## Every undead shot shares one look so danger reads at a glance: a hot red-magenta
## core with a white-hot centre and a dark outline, a little bigger than it hits, pulsing.
const DANGER := Color(1.0, 0.12, 0.38)
static var _outline_mat: StandardMaterial3D
## Undead shots in flight, for Grave Dash to check against.
static var danger: Array[Projectile] = []


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
	if team != Actor.Team.HERO:
		danger.append(p)
		p.tree_exiting.connect(func(): danger.erase(p))
	p.rotation.y = atan2(-p.dir.x, -p.dir.z)
	if team == Actor.Team.HERO:
		p._hero_look(col, size)
	else:
		p._danger_look(size)
	return p


## Hero bolts are small and see-through so they never hide what is coming at you.
func _hero_look(col: Color, size: float) -> void:
	var core := U.sphere(self, size * 0.75, U.unlit(Color(col.r, col.g, col.b, 0.55)))
	core.scale = Vector3(1, 1, 2.6)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tail := U.sphere(self, size * 0.55, U.unlit(Color(col.r, col.g, col.b, 0.2)), Vector3(0, 0, size * 2.4))
	tail.scale = Vector3(0.7, 0.7, 4.0)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _danger_look(size: float) -> void:
	if _outline_mat == null:
		_outline_mat = StandardMaterial3D.new()
		_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_mat.albedo_color = Color(0.12, 0.0, 0.04)
	var r := maxf(size, 0.2) * 1.3
	_look = Node3D.new()
	add_child(_look)
	for part in [[r * 1.3, _outline_mat], [r, U.unlit(DANGER)], [r * 0.45, U.unlit(Color(1, 0.92, 0.95))]]:
		var m := U.sphere(_look, part[0], part[1])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tail := U.sphere(self, r * 0.7, U.unlit(Color(DANGER.r, DANGER.g, DANGER.b, 0.4)), Vector3(0, 0, r * 2.2))
	tail.scale = Vector3(0.7, 0.7, 3.0)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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


func _process(delta: float) -> void:
	life -= delta
	if _look:
		_pulse += delta * 14.0
		var k := 1.0 + 0.14 * sin(_pulse)
		_look.scale = Vector3(k, k, k)
	var next := global_position + dir * speed * delta
	if life <= 0.0 or (Room.current and Room.current.blocks_shot(next, radius * 0.5)):
		Fx.sparks(global_position, Color(1, 0.85, 0.5) if owner_team == Actor.Team.HERO else DANGER)
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
