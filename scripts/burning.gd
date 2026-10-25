class_name Burning
extends Node
## Damage over time from the Fire Shots blessing.

var dps := 0.0
var remaining := 0.0
var _tick := 0.0
## Wildfire: once a second the fire jumps to the nearest skeleton that isn't burning.
var _spread := 1.0


static func apply(a: Actor, damage_per_second: float, seconds: float) -> void:
	var b: Burning = a.get_node_or_null("Burning")
	if b == null:
		b = Burning.new()
		b.name = "Burning"
		a.add_child(b)
	b.dps = maxf(b.dps, damage_per_second)
	b.remaining = seconds


func _process(delta: float) -> void:
	var a := get_parent() as Actor
	remaining -= delta
	_tick -= delta
	if a == null or a.dead or remaining <= 0.0:
		queue_free()
		return
	if _tick <= 0.0:
		_tick = 0.5
		Fx.magic(a.center(), Color(1, 0.5, 0.1), 6)
		a.take_damage(dps * 0.5, Vector3.ZERO, 0.0)
	_spread -= delta
	if _spread <= 0.0 and a is Enemy and Game.hero and Game.hero.perks.has("wildfire"):
		_spread = 1.0
		_jump(a)


func _jump(from: Actor) -> void:
	var best: Actor = null
	var best_d := 3.0
	for o: Actor in Actor.all:
		if o == from or o.team != from.team or not o.can_be_hit() or o.get_node_or_null("Burning"):
			continue
		var d := o.global_position.distance_to(from.global_position)
		if d < best_d:
			best_d = d
			best = o
	if best:
		Fx.trail(best.center(), Color(1, 0.55, 0.15))
		Burning.apply(best, dps, 2.5)
