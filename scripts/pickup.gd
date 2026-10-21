class_name Pickup
extends Node3D
## A glowing heart some skeletons drop. Walk near it to heal. Once a room is cleared,
## any hearts left on the floor fly to the hero by themselves.

const HEAL := 15.0
const MAGNET_RANGE := 2.6

static var all: Array[Pickup] = []

var _t := 0.0
var _gem: Node3D
var _homing := false
var _speed := 0.0


static func drop(pos: Vector3) -> void:
	if Room.current == null:
		return
	var p := Pickup.new()
	Room.current.add_child(p)
	p.global_position = Vector3(pos.x, 0.0, pos.z)


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _ready() -> void:
	_gem = Node3D.new()
	add_child(_gem)
	var red := U.mat(Color(1.0, 0.2, 0.3), 0.3, 2.2)
	# Two bumps and a point: a little heart.
	U.sphere(_gem, 0.17, red, Vector3(-0.12, 0.08, 0))
	U.sphere(_gem, 0.17, red, Vector3(0.12, 0.08, 0))
	var tip := U.box(_gem, Vector3(0.27, 0.27, 0.2), red, Vector3(0, -0.07, 0))
	tip.rotation.z = PI / 4
	var glow := U.floor_quad(self, Vector2(1.3, 1.3), U.unlit(Color(1, 0.25, 0.35, 0.5), U.soft_circle()), Vector3(0, 0.04, 0))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Fx.magic(global_position + Vector3.UP * 0.6, Color(1, 0.3, 0.4), 8)


## Called when a room is cleared: every heart left flies to the hero.
static func collect_all() -> void:
	for p in all:
		p._homing = true


func _process(delta: float) -> void:
	_t += delta
	_gem.position.y = 0.75 + sin(_t * 3.0) * 0.12
	_gem.rotation.y = _t * 2.0
	var hero := Game.hero
	if hero == null or hero.dead:
		return
	var to := hero.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var wanted := hero.health < hero.max_health
	if _homing or (wanted and dist < MAGNET_RANGE):
		_speed = minf(_speed + 30.0 * delta, 16.0)
		global_position += to.normalized() * minf(_speed * delta, dist)
	if dist < hero.radius + 0.35 and (wanted or _homing):
		hero.heal(HEAL)
		Sfx.play("upgrade", 0.35)
		Fx.magic(hero.center(), Color(1, 0.35, 0.45), 14)
		queue_free()
