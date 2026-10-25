class_name Actor
extends Node3D
## Anything with health that can be hit: the hero, the skeletons and the boss.

enum Team { HERO, UNDEAD }

static var all: Array[Actor] = []

signal died(actor: Actor)

var team := Team.UNDEAD
var radius := 0.45
var max_health := 100.0
var health := 100.0
var dead := false
var visual: CharacterVisual
var knockback := Vector3.ZERO

## Height of the body centre, for aiming and effects.
var center_height := 0.8


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func init_health(m: float) -> void:
	max_health = m
	health = m


func center() -> Vector3:
	return global_position + Vector3.UP * center_height


func can_be_hit() -> bool:
	return not dead


func make_visual(look: Dictionary) -> CharacterVisual:
	visual = CharacterVisual.new()
	add_child(visual)
	visual.build(look)
	return visual


func take_damage(amount: float, direction: Vector3, push: float, crit := false) -> void:
	if not can_be_hit():
		return
	health -= amount
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		knockback += direction.normalized() * push
	DamageNumber.hit(self, amount, crit)
	Fx.sparks(center())
	if visual:
		visual.hit()
	_on_damaged()
	if health <= 0.0:
		health = 0.0
		dead = true
		_on_death()
		died.emit(self)


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)
	DamageNumber.healed(self, amount)


func _on_damaged() -> void:
	pass


func _on_death() -> void:
	pass


## Move with the room's collision and bleed off knockback.
func move_by(delta_move: Vector3, delta: float) -> void:
	delta_move += knockback * delta
	knockback = knockback.move_toward(Vector3.ZERO, 40.0 * delta)
	if Room.current:
		global_position = Room.current.resolve_move(global_position, delta_move, radius)
	else:
		global_position += delta_move


## Turn smoothly to face a direction on the floor.
func face(dir: Vector3, sharpness: float, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var goal := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, goal, 1.0 - exp(-sharpness * delta))


static func nearest(from: Vector3, t: int, max_dist := INF) -> Actor:
	var best: Actor = null
	var best_sq := max_dist * max_dist
	for a in all:
		if a.team != t or not a.can_be_hit():
			continue
		var sq := (a.global_position - from).length_squared()
		if sq < best_sq:
			best_sq = sq
			best = a
	return best
