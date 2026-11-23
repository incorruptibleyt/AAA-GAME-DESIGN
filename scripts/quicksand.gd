class_name Quicksand
extends Node3D
## Version 284 (hard review fix 5, the Sandfall Tomb's own danger): pits of quicksand in the
## tomb's rooms. The sand turns slowly round its pit and drags everything standing in it
## towards the middle. Walk out (the pull is weaker than walking) or dash across: a dash is
## never caught. Whoever reaches the middle sinks, gets hurt and is thrown back out. That is
## true of skeletons too, so a skeleton led across a pit is dragged in and half drowned.

const SAND := Color(0.86, 0.66, 0.4)
const RADIUS := 1.75
const CORE := 0.6          # the middle that swallows
const PULL := 2.6          # m/s towards the middle at the middle, for the hero
const FOE_PULL := 2.2      # the same for skeletons
const SINK := 0.45         # seconds in the middle before it swallows
const DAMAGE := 9.0        # to the hero, before the floor's damage scale
const FOE_SHARE := 0.3     # to skeletons: this share of their full health
const DELAY := 1.2         # the sand only starts to pull once the skeletons have climbed out

## Every pit in the room (the test robot walks out of them).
static var all: Array[Quicksand] = []
static var _mat: ShaderMaterial

var _age := 0.0
var _sunk := {}            # actor -> seconds in the middle
var _relics: Node3D        # the bones turning round in the sand
var _said := false


## Lays two (sometimes three) pits on open floor in `room`, clear of cover, of where the
## skeletons rise, of the door and of where the hero walks in.
static func lay(room: Room) -> void:
	# Version 297 (deep review fix 5): one pit in the floor's first room, more later.
	var count: int = [1, 3 if randf() < 0.3 else 2, 3][mini(Game.danger_step(), 2)]
	var placed: Array[Vector3] = []
	for attempt in 80:
		if placed.size() >= count:
			break
		var p := Vector3(randf_range(-Room.HALF_W + RADIUS + 0.4, Room.HALF_W - RADIUS - 0.4), 0.0, randf_range(-6.8, 4.4))
		if Game.near_hero(p, Quicksand.RADIUS + 1.2):   # v297: may be laid mid-fight (a boss's phase 2)
			continue
		if not _open(room, p, placed):
			continue
		placed.append(p)
		var q := Quicksand.new()
		q.name = "Quicksand"
		room.add_child(q)
		q.position = p
		q._build()


static func _open(room: Room, p: Vector3, placed: Array[Vector3]) -> bool:
	for o: Dictionary in room.obstacles:
		if Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < RADIUS + float(o.r) + 0.7:
			return false
	for s: Dictionary in room.spawns:
		if Vector2(p.x - s.pos.x, p.z - s.pos.z).length() < RADIUS + 0.5:
			return false
	for q in placed:
		if q.distance_to(p) < RADIUS * 2.0 + 2.2:
			return false
	return true


## For the shader warm-up (warmup.gd): a pit that just sits there.
static func warm(parent: Node, at: Vector3) -> void:
	var q := Quicksand.new()
	q.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(q)
	q.position = at
	q._build()


## Whether `p` (a body `r` round) is standing in the pit.
func covers(p: Vector3, r := 0.0) -> bool:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= RADIUS * 0.95 + r


func _enter_tree() -> void:
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _build() -> void:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	var disc := U.floor_quad(self, Vector2(RADIUS * 2.3, RADIUS * 2.3), _mat, Vector3(0, 0.025, 0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A broken ring of sandstone kerb round the rim, so a pit reads as a pit at a glance.
	var kerb := U.mat(Color(0.55, 0.42, 0.28), 0.9)
	var n := 11
	for i in n:
		if i % 4 == 3:
			continue   # gaps, crumbled away
		var a := TAU * (i + randf_range(-0.15, 0.15)) / n
		var b := U.box(self, Vector3(0.62, 0.12, 0.22), kerb, Vector3(sin(a), 0.06, cos(a)) * (RADIUS * 1.06))
		b.rotation.y = a + randf_range(-0.12, 0.12)
		b.rotation.z = randf_range(-0.12, 0.12)
	# Bones half sunk in the sand, turning slowly round towards the middle: the pull, shown.
	_relics = Node3D.new()
	add_child(_relics)
	var bone := U.mat(Color(0.86, 0.82, 0.7), 0.7)
	for i in 3:
		var a := TAU * i / 3.0 + randf() * 0.6
		var r := RADIUS * (0.45 + 0.17 * i)
		var holder := Node3D.new()
		holder.position = Vector3(sin(a), 0, cos(a)) * r
		holder.scale = Vector3.ONE * 1.5
		_relics.add_child(holder)
		if i == 0:
			var skull := U.sphere(holder, 0.17, bone, Vector3(0, 0.04, 0))
			skull.scale = Vector3(1.0, 0.85, 1.15)
			var eye := U.mat(Color(0.08, 0.06, 0.05), 1.0)
			for s: float in [-1.0, 1.0]:
				U.sphere(holder, 0.045, eye, Vector3(s * 0.065, 0.08, 0.14))
		else:
			var c := U.cylinder(holder, 0.04, 0.5, bone, Vector3(0, 0.08, 0))
			c.rotation = Vector3(randf_range(0.9, 1.3), randf() * TAU, 0)


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	delta = minf(delta, Actor.MAX_STEP)
	_age += delta
	_relics.rotation.y -= delta * 0.5
	for c: Node3D in _relics.get_children():
		c.rotation.y += delta * 0.3
	if _age < DELAY or Game.state != Game.State.PLAYING:
		return
	var hero := Game.hero
	if hero and not hero.dead and not hero.is_dashing():
		_drag(hero, PULL, delta)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and not (a as Enemy).is_boss and not a.dead:
			_drag(a, FOE_PULL, delta)


func _drag(a: Actor, pull: float, delta: float) -> void:
	var d := global_position - a.global_position
	d.y = 0.0
	var dist := d.length()
	if dist > RADIUS:
		_sunk.erase(a)
		return
	if a is Hero and not _said:
		_said = true
		Game.danger_warn("quicksand", "QUICKSAND!", "QUICKSAND pulls you to its middle, and the middle hurts. Walk out, or dash across. Lead skeletons into it!", SAND)
	if dist > 0.05:
		# Strongest near the middle, so the edge is a stumble and the middle a trap.
		var k := 0.45 + 0.55 * (1.0 - dist / RADIUS)
		a.move_by(d / dist * minf(pull * k * delta, dist), delta)
	if dist > CORE:
		_sunk.erase(a)
		return
	var t: float = _sunk.get(a, 0.0) + delta
	_sunk[a] = t
	if t < SINK or not a.can_be_hit():
		return
	_sunk.erase(a)
	var out := -d / dist if dist > 0.05 else Vector3.BACK
	Fx.impact(global_position + Vector3.UP * 0.2, SAND, 1.4)
	Fx.dust(global_position, 18)
	Sfx.play("sandfall", 0.5, 1.3)
	if a is Hero:
		Game.hit_source = "Quicksand"
		a.take_damage(DAMAGE, out, 11.0)
		Game.buzz(40)
	else:
		a.take_damage(a.max_health * FOE_SHARE, out, 9.0)


## Wet dark sand turning round a sinking middle: ripples run in a spiral, lightest at the
## rim, falling to near black in the throat, and a dark wet line just inside the kerb.
const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 q = (UV - 0.5) * 2.3;           // pit radius = 1.0
	float r = length(q);
	float a = atan(q.y, q.x);
	// Ridges wound in a spiral that turns inwards, so the sand is seen to drain.
	float spiral = sin(a * 3.0 + log(max(r, 0.02)) * 6.0 + TIME * 1.8);
	float ridge = smoothstep(0.2, 0.9, spiral);
	float grain = hash(floor(q * 70.0));
	vec3 sand = vec3(0.6, 0.44, 0.26) * (0.72 + 0.3 * ridge) * (0.92 + 0.08 * grain);
	sand = mix(vec3(0.12, 0.07, 0.03), sand, smoothstep(0.08, 0.7, r));      // the dark throat
	sand = mix(sand, vec3(0.3, 0.2, 0.11), smoothstep(0.84, 0.95, r) * 0.8);  // wet rim
	ALBEDO = sand;
	ROUGHNESS = 0.95;
	ALPHA = 1.0 - smoothstep(0.97, 1.07, r);
	EMISSION = vec3(1.0, 0.8, 0.45) * step(0.99, grain) * 0.15 * step(r, 0.9);
}
"""
