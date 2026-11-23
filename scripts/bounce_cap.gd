class_name BounceCap
extends Node3D
## Version 292 (the Glowcap Grotto's own danger): bounce caps. Great springy glowcaps grow
## flat on the grotto's floor, three or four to a room, each with glowing arrows in its gills
## showing which way it throws. Step on one and it squashes and flings you through the air
## the way its arrows point: you can't steer or shoot while you fly, skeleton shots pass
## under you, and you come down where it aims, which may be in the middle of the skeletons
## (the landing stamps the floor and knocks the ones right there back). A skeleton that
## blunders onto one is thrown and lands hard. A dash skims over a cap without setting it off.

const PINK := Color(1.0, 0.36, 0.78)
const LIME := Color(0.72, 1.0, 0.3)
const R := 0.78              # the cap's size; standing this close to its middle sets it off
const TRIGGER := 0.62
const THROW := 5.0           # metres the hero is thrown
const FLY := 0.6             # seconds in the air
const HEIGHT := 1.6          # metres high at the top of the throw
const REST := 1.4            # seconds before a cap can throw again
const STAMP_R := 1.5         # skeletons this close to where the hero lands are knocked back
const STAMP_SHARE := 0.12    # and lose this share of their full health
const FOE_SHARE := 0.2       # a skeleton thrown by a cap loses this share when it lands
const FOE_THROW := 18.0      # the speed a skeleton is thrown at (about 4 m)

## Every cap in the room.
static var all: Array[BounceCap] = []
static var _said := false

var aim := Vector3.FORWARD
var _rest := 0.0
var _cap: Node3D
var _glow: StandardMaterial3D


## Grows three or four caps on open floor in `room`, each aimed at open floor inside the room.
static func lay(room: Room) -> void:
	_said = false
	# Version 297 (deep review fix 5): two caps in the floor's first room, more later.
	var count: int = [2, 4 if randf() < 0.4 else 3, 4][mini(Game.danger_step(), 2)]
	var placed: Array[Vector3] = []
	var lands: Array[Vector3] = []   # where each placed cap throws to
	for attempt in 120:
		if placed.size() >= count:
			break
		var p := Vector3(randf_range(-3.2, 3.2), 0, randf_range(-6.5, 3.0))
		if Game.near_hero(p, 2.0):   # v297: may be laid mid-fight (a boss's phase 2)
			continue
		if not _clear(room, p, 1.1):
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 2.6:
				ok = false
		# Review fix 1 (build 295): no cap may throw the hero onto another cap, or two caps
		# would bounce them back and forth, out of reach and unable to shoot.
		for l in lands:
			if l.distance_to(p) < TRIGGER + 1.2:
				ok = false
		if not ok:
			continue
		# Aim it at open floor: try a few headings, keep the first that lands clear.
		var found := false
		var dir := Vector3.FORWARD
		for k in 10:
			var a := randf() * TAU
			dir = Vector3(sin(a), 0, cos(a))
			var land := p + dir * THROW
			if absf(land.x) > Room.HALF_W - 0.9 or land.z < -8.0 or land.z > 4.5:
				continue
			if not _clear(room, land, 0.9) or not _clear(room, p + dir * THROW * 0.5, 0.3):
				continue
			var onto := false
			for q in placed:
				if q.distance_to(land) < TRIGGER + 1.2:
					onto = true
			if onto:
				continue
			found = true
			break
		if not found:
			continue
		placed.append(p)
		lands.append(p + dir * THROW)
		var c := BounceCap.new()
		c.name = "BounceCap"
		c.aim = dir
		room.add_child(c)
		c.position = p
		c._build()


static func _clear(room: Room, p: Vector3, gap: float) -> bool:
	for o: Dictionary in room.obstacles:
		if Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < float(o.r) + gap:
			return false
	for sp: Dictionary in room.spawns:
		if Vector2(p.x - sp.pos.x, p.z - sp.pos.z).length() < 1.0:
			return false
	return true


## For the shader warm-up (warmup.gd).
static func warm(parent: Node, at: Vector3) -> void:
	var c := BounceCap.new()
	c.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(c)
	c.position = at
	c._build()


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


## A wide pink glowcap squatting on a stubby pale stalk, pale spots on top, and lime arrows
## glowing on the floor ahead of it the way it throws.
func _build() -> void:
	# The glow on the floor under it.
	var pool := U.unlit(Color(PINK.r, PINK.g, PINK.b, 0.4), U.soft_circle()).duplicate() as StandardMaterial3D
	pool.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	U.floor_quad(self, Vector2(R * 3.2, R * 3.2), pool, Vector3(0, 0.03, 0))
	_cap = Node3D.new()
	add_child(_cap)
	var stalk := U.mat(Color(0.88, 0.85, 0.75), 0.7)
	U.cylinder(_cap, 0.32, 0.22, stalk, Vector3.ZERO)
	# A deep magenta rim under a brighter pink crown, so it reads as a dome from above.
	var rim := U.mat(Color(0.62, 0.1, 0.42), 0.45, 0.25)
	var rim_m := U.sphere(_cap, R, rim, Vector3(0, 0.2, 0))
	rim_m.scale = Vector3(1.0, 0.42, 1.0)
	var crown := U.mat(PINK, 0.35, 0.35)
	var top := U.sphere(_cap, R * 0.72, crown, Vector3(0, 0.36, 0))
	top.scale = Vector3(1.0, 0.45, 1.0)
	var gill := U.mat(Color(0.35, 0.08, 0.25), 0.9)
	var under := U.cylinder(_cap, R * 0.92, 0.04, gill, Vector3(0, 0.16, 0))
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spot := U.mat(Color(0.85, 1.0, 0.6), 0.6, 0.6)
	for i in 6:
		var a := TAU * i / 6.0 + randf() * 0.5
		var r := randf_range(0.25, 0.55)
		var s := U.sphere(_cap, randf_range(0.09, 0.13), spot, Vector3(cos(a) * r, 0.5 - r * 0.35, sin(a) * r))
		s.scale.y = 0.4
	# The arrows: three lime chevrons on the floor pointing the way it throws.
	var holder := Node3D.new()
	add_child(holder)
	holder.rotation.y = atan2(aim.x, aim.z)
	_glow = U.unlit(Color(LIME.r, LIME.g, LIME.b, 0.85)).duplicate() as StandardMaterial3D
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for k in 3:
		var z := R + 0.25 + k * 0.42
		for side: float in [-1.0, 1.0]:
			var bar := U.box(holder, Vector3(0.08, 0.02, 0.36), _glow, Vector3(side * 0.13, 0.04, z))
			bar.rotation.y = side * 0.75
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	delta = minf(delta, Actor.MAX_STEP)
	var t := Time.get_ticks_msec() / 1000.0
	if _rest > 0.0:
		_rest -= delta
		_glow.albedo_color.a = 0.2
		return
	# The arrows run towards where it throws.
	_glow.albedo_color.a = 0.55 + 0.35 * sin(t * 5.0)
	if not (Game.state == Game.State.PLAYING and Game.fight_on()):
		return
	for a: Actor in Actor.all:
		if a.dead:
			continue
		var d := a.global_position - global_position
		d.y = 0.0
		if d.length() > TRIGGER:
			continue
		if a is Hero:
			var h := a as Hero
			if h.is_dashing() or h.fling_left > 0.0:
				continue
			_spring()
			if not _said:
				_said = true
				Game.danger_warn("caps", "BOING!", "BOUNCE CAPS throw you where their arrows point, and you land with a stamp. A dash skims over them.", PINK)
			h.global_position = Vector3(global_position.x, h.global_position.y, global_position.z)
			h.fling(aim * THROW / FLY, FLY)
			return
		if a is Enemy and not (a as Enemy).is_boss and a.can_be_hit():
			_spring()
			a.take_damage(a.max_health * FOE_SHARE, aim, 0.0)
			a.knockback = aim * FOE_THROW
			return


## Squashes and springs back, with a puff of spores.
func _spring() -> void:
	_rest = REST
	Sfx.play("slam", 0.45, 1.8)
	Fx.magic(global_position + Vector3.UP * 0.4, PINK, 14)
	Fx.magic(global_position + Vector3.UP * 0.3, LIME, 8)
	var tw := create_tween()
	_cap.scale = Vector3(1.25, 0.45, 1.25)
	tw.tween_property(_cap, "scale", Vector3(0.9, 1.25, 0.9), 0.12)
	tw.tween_property(_cap, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The hero comes down (hero.gd): a stamp that knocks back the skeletons right there.
static func land(h: Hero) -> void:
	var p := h.global_position
	Fx.shockwave(p, PINK, STAMP_R)
	Fx.dust(p, 16)
	Sfx.play("slam", 0.5, 1.2)
	Game.buzz(30)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and not a.dead and not (a as Enemy).is_boss and a.can_be_hit():
			var d := a.global_position - p
			d.y = 0.0
			if d.length() < STAMP_R:
				a.take_damage(a.max_health * STAMP_SHARE, d.normalized() if d.length() > 0.05 else Vector3.BACK, 9.0)


## The cap under or right next to `p`, if it is ready to throw (for the test robot).
static func near(p: Vector3, reach: float) -> BounceCap:
	for c in all:
		if is_instance_valid(c) and c._rest <= 0.0:
			var d := p - c.global_position
			d.y = 0.0
			if d.length() < reach:
				return c
	return null
