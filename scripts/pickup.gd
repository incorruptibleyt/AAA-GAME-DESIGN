class_name Pickup
extends Node3D
## Things skeletons drop: glowing hearts that heal, and gold coins you keep between runs
## (spend them in the Armory). Walk near to collect. Once a room is cleared, anything
## left on the floor flies to the hero by itself.

const HEAL := 15.0
const MAGNET_RANGE := 2.6
const COIN_MAGNET_RANGE := 3.6

static var all: Array[Pickup] = []

var coin := false
var value := 1
var _t := 0.0
var _gem: Node3D
var _homing := false
var _speed := 0.0
var _vel := Vector3.ZERO


static func drop(pos: Vector3) -> void:
	if Room.current == null:
		return
	var p := Pickup.new()
	Room.current.add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)


## Scatter `total` coins' worth around a spot, in a few pieces.
static func drop_coins(pos: Vector3, total: int) -> void:
	if Room.current == null or total <= 0:
		return
	var pieces := clampi(total, 1, 4)
	for i in pieces:
		var p := Pickup.new()
		p.coin = true
		p.value = total / pieces + (1 if i < total % pieces else 0)
		Room.current.add_child(p)
		p.global_position = Vector3(pos.x, 0.0, pos.z)
		p._vel = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.5, 3.5)


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _ready() -> void:
	_gem = Node3D.new()
	add_child(_gem)
	if coin:
		var gold := U.mat(Color(1.0, 0.78, 0.2), 0.25, 1.2)
		var c := U.cylinder(_gem, 0.22, 0.06, gold, Vector3(0, -0.03, 0))
		c.rotation.x = PI / 2
		var glow := U.floor_quad(self, Vector2(0.8, 0.8), U.unlit(Color(1, 0.8, 0.3, 0.4), U.soft_circle()), Vector3(0, 0.04, 0))
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	var red := U.mat(Color(1.0, 0.2, 0.3), 0.3, 2.2)
	# Two bumps and a point: a little heart.
	U.sphere(_gem, 0.17, red, Vector3(-0.12, 0.08, 0))
	U.sphere(_gem, 0.17, red, Vector3(0.12, 0.08, 0))
	var tip := U.box(_gem, Vector3(0.27, 0.27, 0.2), red, Vector3(0, -0.07, 0))
	tip.rotation.z = PI / 4
	var glow := U.floor_quad(self, Vector2(1.3, 1.3), U.unlit(Color(1, 0.25, 0.35, 0.5), U.soft_circle()), Vector3(0, 0.04, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Fx.magic(global_position + Vector3.UP * 0.6, Color(1, 0.3, 0.4), 8)


## Called when a room is cleared: everything left flies to the hero.
static func collect_all() -> void:
	for p in all:
		p._homing = true


func _process(delta: float) -> void:
	_t += delta
	_gem.position.y = (0.55 if coin else 0.75) + sin(_t * 3.0) * 0.12
	_gem.rotation.y = _t * (5.0 if coin else 2.0)
	if _vel.length_squared() > 0.01:
		# Coins skid out a little when they drop.
		var p := global_position + _vel * delta
		if Room.current:
			p = Room.current.resolve_move(global_position, _vel * delta, 0.2)
		global_position = p
		_vel = _vel.move_toward(Vector3.ZERO, 8.0 * delta)
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var wanted := coin or hero.health < hero.max_health
	var magnet := (COIN_MAGNET_RANGE if coin else MAGNET_RANGE) * (hero.magnet if hero else 1.0)
	if _homing or (wanted and dist < magnet):
		_speed = minf(_speed + 30.0 * delta, 16.0)
		global_position += to.normalized() * minf(_speed * delta, dist)
	if dist < hero.radius + 0.35 and (wanted or _homing):
		if coin:
			Game.add_coins(value)
			Sfx.play("coin", 0.45)
		else:
			hero.heal(HEAL)
			Sfx.play("upgrade", 0.35)
			Fx.magic(hero.center(), Color(1, 0.35, 0.45), 14)
		queue_free()
