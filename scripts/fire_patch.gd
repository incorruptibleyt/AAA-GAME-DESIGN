class_name FirePatch
extends Node3D
## A patch of fire on the floor, left by Cinder Skeletons. It flares up over half a
## second (so you can see it coming), then burns the hero while they stand in it.
## A charred dark rim and a pulsing yellow-white middle keep it readable on the red
## Ember floor, the same way enemy shots stand out.

const FLARE := 0.5

var radius := 0.9
var life := 3.0
var _age := 0.0
var _tick := 0.0
var _mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
## Version 239 (the Mage's Burning Ground): a patch of the hero's fire. It burns skeletons,
## never the hero, and wears the Mage's violet at its edge so it can't be read as danger.
var friendly := false
var burn := 0.0
var _spark := Color(1, 0.5, 0.15)
const HERO_RIM := Color(0.62, 0.3, 1.0)


static func spawn(pos: Vector3, r: float, seconds: float) -> void:
	var parent: Node = Room.current if Room.current else Game.world
	if parent == null:
		return
	var f := FirePatch.new()
	f.radius = r
	f.life = seconds
	parent.add_child(f)
	f.global_position = Vector3(pos.x, 0.04, pos.z)
	f._rim_mat = U.unlit(Color(0.06, 0.01, 0.0, 0.0), U.ring()).duplicate()
	U.floor_quad(f, Vector2(r * 2.25, r * 2.25), f._rim_mat, Vector3(0, -0.004, 0))
	f._mat = U.unlit(Color(1, 0.38, 0.08, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(f, Vector2(r * 2.1, r * 2.1), f._mat)
	f._core_mat = U.unlit(Color(1, 0.9, 0.6, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(f, Vector2(r * 1.2, r * 1.2), f._core_mat, Vector3(0, 0.006, 0))


## The Mage's Burning Ground: burns skeletons standing in it at `dps` (and for a second after
## they step out). A violet edge and violet sparks, no charred rim.
static func spawn_hero(pos: Vector3, r: float, seconds: float, dps: float) -> void:
	var parent: Node = Room.current if Room.current else Game.world
	if parent == null:
		return
	var f := FirePatch.new()
	f.radius = r
	f.life = seconds
	f.friendly = true
	f.burn = dps
	f._spark = Color(0.85, 0.5, 1.0)
	parent.add_child(f)
	f.global_position = Vector3(pos.x, 0.04, pos.z)
	f._rim_mat = U.unlit(Color(HERO_RIM.r, HERO_RIM.g, HERO_RIM.b, 0.0), U.ring()).duplicate()
	U.floor_quad(f, Vector2(r * 2.25, r * 2.25), f._rim_mat, Vector3(0, -0.004, 0))
	f._mat = U.unlit(Color(1, 0.45, 0.3, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(f, Vector2(r * 2.0, r * 2.0), f._mat)
	f._core_mat = U.unlit(Color(1, 0.85, 0.7, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(f, Vector2(r * 1.1, r * 1.1), f._core_mat, Vector3(0, 0.006, 0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	var k := minf(_age / FLARE, 1.0)
	var fade := clampf((life - _age) / 0.6, 0.0, 1.0)
	_mat.albedo_color.a = 0.8 * k * fade
	_rim_mat.albedo_color.a = (0.9 if friendly else 0.75) * k * fade
	_core_mat.albedo_color.a = (0.6 + 0.35 * sin(_age * 9.0)) * k * fade
	if randf() < delta * (8.0 if friendly else 5.0):
		Fx.magic(global_position + Vector3(randf_range(-radius, radius) * 0.6, 0.2, randf_range(-radius, radius) * 0.6), _spark if friendly and randf() < 0.5 else Color(1, 0.5, 0.15), 2)
	_tick -= delta
	if friendly:
		_burn_foes()
		return
	var hero := Game.hero
	if k < 1.0 or _tick > 0.0 or hero == null or hero.dead or Game.state != Game.State.PLAYING:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	if d.length() < radius + hero.radius * 0.5:
		_tick = 0.5
		Game.hit_source = "Cinder fire"
		hero.take_damage(6.0, Vector3.ZERO, 0.0)


## Burning Ground: every skeleton standing in the patch catches fire (checked a few times
## a second; the fire keeps burning for a second after it steps out).
func _burn_foes() -> void:
	if _tick > 0.0 or _age < FLARE * 0.5 or Game.state != Game.State.PLAYING:
		return
	_tick = 0.3
	for a: Actor in Actor.all:
		if a.team != Actor.Team.UNDEAD or not a.can_be_hit():
			continue
		var d := a.global_position - global_position
		d.y = 0.0
		if d.length() < radius + a.radius * 0.6:
			Burning.apply(a, burn, 1.2)
