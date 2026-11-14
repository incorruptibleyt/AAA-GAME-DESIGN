class_name SporeCloud
extends Node3D
## A cloud of glowing spores hanging over the floor (Glowcap Grotto): a Sporeling bursts
## into one when it dies, and the Sporemother's pods leave them where they land. It puffs
## up over SWELL seconds first, so there's time to see it and step away, then it hurts
## the hero while they stand in it. A dark violet rim on the floor shows its edge on any
## floor; soft pink puffs drift and bob above it.

const SWELL := 0.6
const PINK := Color(1.0, 0.42, 0.82)

var radius := 1.3
var life := 3.0
var damage := 5.0
var _age := 0.0
var _tick := 0.0
var _floor_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _puff_mat: StandardMaterial3D
var _puffs: Array[MeshInstance3D] = []
var _seeds: Array[float] = []

## Every cloud on the floor (the test robot steps out of them).
static var all: Array[SporeCloud] = []


static func spawn(pos: Vector3, r: float, seconds: float, hurt := 5.0) -> SporeCloud:
	var parent: Node = Room.current if Room.current else Game.world
	if parent == null:
		return null
	var c := SporeCloud.new()
	c.radius = r
	c.life = seconds
	c.damage = hurt
	parent.add_child(c)
	c.global_position = Vector3(pos.x, 0.04, pos.z)
	c._build()
	return c


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _build() -> void:
	_rim_mat = U.unlit(Color(0.16, 0.03, 0.2, 0.0), U.ring()).duplicate()
	U.floor_quad(self, Vector2(radius * 2.25, radius * 2.25), _rim_mat, Vector3(0, -0.004, 0))
	_floor_mat = U.unlit(Color(PINK.r, PINK.g, PINK.b, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(self, Vector2(radius * 2.1, radius * 2.1), _floor_mat)
	# The puffs: soft round billboards, added so overlapping ones glow brighter in the middle.
	_puff_mat = U.unlit(Color(1.0, 0.55, 0.88, 0.0), U.soft_circle(), true).duplicate()
	_puff_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var count := 5 if radius >= 1.2 else 4
	for i in count:
		var a := i / float(count) * TAU + randf() * 0.5
		var d := radius * (0.15 if i == 0 else randf_range(0.35, 0.6))
		var q := QuadMesh.new()
		var s := radius * randf_range(0.9, 1.2)
		q.size = Vector2(s, s)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = _puff_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * d, 0.45, sin(a) * d)
		mi.scale = Vector3.ONE * 0.2
		add_child(mi)
		_puffs.append(mi)
		_seeds.append(randf() * TAU)


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	var k := minf(_age / SWELL, 1.0)
	var fade := clampf((life - _age) / 0.6, 0.0, 1.0)
	_floor_mat.albedo_color.a = 0.42 * k * fade
	_rim_mat.albedo_color.a = 0.8 * k * fade
	_puff_mat.albedo_color.a = 0.32 * k * fade
	var grow := ease(k, 0.4)
	for i in _puffs.size():
		var p := _puffs[i]
		p.scale = Vector3.ONE * (0.2 + 0.8 * grow) * (1.0 + 0.08 * sin(_age * 2.2 + _seeds[i]))
		p.position.y = 0.45 + 0.12 * sin(_age * 1.7 + _seeds[i])
	if randf() < delta * 6.0:
		Fx.magic(global_position + Vector3(randf_range(-radius, radius) * 0.6, 0.3, randf_range(-radius, radius) * 0.6), PINK, 2)
	_tick -= delta
	var hero := Game.hero
	if k < 1.0 or _tick > 0.0 or hero == null or hero.dead or Game.state != Game.State.PLAYING:
		return
	var d := hero.global_position - global_position
	d.y = 0.0
	if d.length() < radius + hero.radius * 0.4:
		_tick = 0.5
		Game.hit_source = "Spore cloud"
		hero.take_damage(damage, Vector3.ZERO, 0.0)


## True while `pos` is inside a cloud (or one about to puff up), with `margin` to spare.
static func covers(pos: Vector3, margin := 0.3) -> SporeCloud:
	for c in all:
		if is_instance_valid(c) and Vector2(pos.x - c.global_position.x, pos.z - c.global_position.z).length() < c.radius + margin:
			return c
	return null
