class_name Burning
extends Node
## Damage over time from the Fire Bolts blessing.

var dps := 0.0
var remaining := 0.0
var _tick := 0.0


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
