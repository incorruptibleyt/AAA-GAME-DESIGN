class_name GraveSpikes
extends Node3D
## The Omen of Graves (version 241, whole-game review fix 12): where a skeleton falls, its
## grave glows red and a moment later bone spikes burst out of it. Killing a skeleton right
## next to you is no longer free: step away from the bones, or lead skeletons over fresh
## graves, because the spikes hurt them as well.

const R := 1.15             # +0.25 for every extra Omen of Graves
const WARN := 0.85
const DAMAGE := 10.0        # to the hero, before the floor's damage scale
const FOE_SHARE := 0.25     # to skeletons: this share of their full health
const MAX_OPEN := 10        # a boss's swarm of minions can't carpet the room
const UP := 0.12
const HOLD := 0.35
const DOWN := 0.3
const BONE := Color(0.93, 0.9, 0.8)

static var _open := []

var _r := R
var _t := 0.0
var _spikes: Node3D


## A grave at `at`: the warning circle now, the spikes when it runs out.
static func mark(at: Vector3, stacks: int) -> void:
	_open = _open.filter(func(t): return is_instance_valid(t) and not t._fired)
	if _open.size() >= MAX_OPEN or Room.current == null:
		return
	var r := R + 0.25 * (stacks - 1)
	var spot := Vector3(at.x, 0.0, at.z)
	_open.append(Telegraph.circle(spot, r, WARN, func(): _burst(spot, r), 0.0))


static func _burst(at: Vector3, r: float) -> void:
	if Room.current == null or Game.state != Game.State.PLAYING:
		return
	var g := GraveSpikes.new()
	g._r = r
	Room.current.add_child(g)
	g.global_position = at
	g._build()
	Fx.dust(at, 12)
	Fx.shockwave(at, Color(1.0, 0.45, 0.35), r + 0.2)
	Sfx.play("slam", 0.4, randf_range(1.15, 1.35))
	var hero := Game.hero
	if hero and hero.can_be_hit():
		var d := hero.global_position - at
		d.y = 0.0
		if d.length() < r + hero.radius * 0.5:
			Game.hit_source = "Omen of Graves"
			hero.take_damage(DAMAGE, d.normalized() if d.length() > 0.05 else Vector3.BACK, 6.0)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and not (a as Enemy).is_boss and a.can_be_hit():
			var e := a.global_position - at
			e.y = 0.0
			if e.length() < r + a.radius * 0.6:
				a.take_damage(a.max_health * FOE_SHARE, e.normalized() if e.length() > 0.05 else Vector3.FORWARD, 4.0)


func _build() -> void:
	_spikes = Node3D.new()
	add_child(_spikes)
	# Bone white with a little glow of its own, so the spikes read under the Omen of Night too.
	var bone := U.mat(BONE, 0.5, 0.25)
	var n := 9
	for i in n + 1:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		var tall := randf_range(0.85, 1.25) if i < n else 1.6
		cone.bottom_radius = 0.15 if i < n else 0.22
		cone.height = tall
		cone.radial_segments = 5
		var m := MeshInstance3D.new()
		m.mesh = cone
		m.material_override = bone
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i < n:
			var a := TAU * i / n + randf() * 0.3
			var rr := _r * randf_range(0.4, 0.85)
			m.position = Vector3(cos(a) * rr, tall * 0.42, sin(a) * rr)
			m.rotation = Vector3(sin(a) * 0.45, 0.0, -cos(a) * 0.45)
		else:
			m.position = Vector3(0, tall * 0.5, 0)
		_spikes.add_child(m)
	# A dark broken patch of floor under them.
	var pit := U.floor_quad(self, Vector2(_r * 2.0, _r * 2.0), U.unlit(Color(0.05, 0.02, 0.03, 0.7), U.soft_circle()), Vector3(0, 0.03, 0))
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spikes.position.y = -1.6


func _process(delta: float) -> void:
	_t += delta
	if _t < UP:
		_spikes.position.y = lerpf(-1.6, 0.0, _t / UP)
	elif _t < UP + HOLD:
		_spikes.position.y = 0.0
	elif _t < UP + HOLD + DOWN:
		_spikes.position.y = lerpf(0.0, -1.6, (_t - UP - HOLD) / DOWN)
	else:
		queue_free()
