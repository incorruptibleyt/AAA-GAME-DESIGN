class_name DamageNumber
extends Label3D
## Numbers that pop out of whatever got hit and float away. Quick hits on the same target
## add up into one number, which sits up and to the side so it never hides the skeleton.

const LIFE := 0.75
## A hit this soon after the last one joins its number instead of making a new one.
const MERGE := 0.4
## Where numbers sit, from the middle of whatever was hit: above it and to the right.
const OFFSET := Vector3(0.75, 0.8, 0)

var _age := 0.0
var _size := 1.0
var _total := 0.0
var _prefix := ""
var _rise := 0.0
var _lift := 0.0
var _follow: Actor
var _base := Vector3.ZERO
## The number still adding up for each target ("<id>hit" / "<id>heal").
static var _live := {}


## Damage taken by `who`. Hits on the hero are red; crits turn the number gold and bigger.
static func hit(who: Actor, amount: float, crit: bool) -> void:
	_add(who, "hit", amount, Color(1, 0.35, 0.35) if who.team == Actor.Team.HERO else Color.WHITE, "", crit)


static func healed(who: Actor, amount: float) -> void:
	_add(who, "heal", amount, Color(0.4, 1, 0.5), "+", false)


static func _add(who: Actor, kind: String, amount: float, col: Color, prefix: String, crit: bool) -> void:
	if Game.world == null:
		return
	var key := "%d%s" % [who.get_instance_id(), kind]
	var n: DamageNumber = _live.get(key)
	if is_instance_valid(n) and n._age < MERGE:
		n._total += amount
		n._age = 0.0
		n._size = minf(n._size + 0.06, 1.8)
	else:
		n = DamageNumber.new()
		n.modulate = col
		n.outline_modulate = Color(0, 0, 0, 0.85)
		n.outline_size = 10
		n.font_size = 64
		n.pixel_size = 0.009
		n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		n.no_depth_test = true
		n.fixed_size = false
		n._follow = who
		n._prefix = prefix
		n._total = amount
		n._base = who.center()
		n._lift = _free_lift(n._base + OFFSET)
		n.position = n._base + OFFSET + Vector3(0, n._lift, 0)
		Game.world.add_child(n)
		_live[key] = n
		n.tree_exiting.connect(func(): if _live.get(key) == n: _live.erase(key))
	if crit:
		n.modulate = Color(1, 0.85, 0.2)
		n._size = maxf(n._size, 1.5)
	n.text = n._prefix + str(maxi(1, roundi(n._total)))


## How far to raise a new number so it doesn't sit on top of one already showing
## (skeletons crowded together).
static func _free_lift(at: Vector3) -> float:
	var lift := 0.0
	for i in 4:
		var clear := true
		for o in _live.values():
			if is_instance_valid(o) and o.position.distance_to(at + Vector3(0, lift, 0)) < 0.55:
				clear = false
				break
		if clear:
			break
		lift += 0.55
	return lift


func _process(delta: float) -> void:
	_age += delta
	var k := _age / LIFE
	if k >= 1.0:
		queue_free()
		return
	if is_instance_valid(_follow):
		_base = _follow.center()
	_rise = minf(_rise + delta * 1.4, 0.9)
	position = _base + OFFSET + Vector3(0, _rise + _lift, 0)
	var pop := lerpf(1.5, 1.0, k / 0.15) if k < 0.15 else 1.0
	scale = Vector3.ONE * _size * pop
	modulate.a = 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
	outline_modulate.a = modulate.a * 0.85
