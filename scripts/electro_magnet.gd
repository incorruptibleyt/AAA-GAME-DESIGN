class_name ElectroMagnet
extends Node3D
## Version 287 (hard review fix 5, the Clockwork Foundry's own danger): electromagnets. Two
## great copper coils stand against the side walls of the foundry's rooms and take turns
## switching on. A coil hums and flickers first; once it is on, it glows blue, crackles, and
## pulls on everything made of iron: shots curve towards it in flight (yours too, so a shot
## can bend round cover, or miss), and everyone in the room is dragged slowly towards it.
## Whoever is dragged right up to it is shocked: hurt and thrown back. Skeletons too.

const BLUE := Color(0.45, 0.75, 1.0)
const COPPER := Color(0.78, 0.42, 0.2)
const ON := 4.0            # seconds a coil stays on
const OFF := 3.0           # seconds between one coil switching off and the next switching on
const HUM := 0.9           # the warning before it switches on (inside OFF)
const FIRST := 3.0         # the first coil hums this long after the room starts
const PULL := 1.5          # m/s towards the coil, for the hero (at the far wall: half)
const FOE_PULL := 1.2
const BEND := 2.2          # how hard shots curve (radians per second, close to the coil)
const SHOCK_R := 1.25      # this close to it: shocked
const DAMAGE := 5.0        # to the hero, before the floor's damage scale (about 22 on floor 9)
const FOE_SHARE := 0.35    # to skeletons: this share of their full health

## The coil that is on, if any (projectile.gd bends shots towards it).
static var live: ElectroMagnet = null

var _coils: Array[Dictionary] = []   # {pos, glow, light, mat, ring}
var _which := 0
var _t := 0.0
var _on := false
var _shocked := {}
var _said := false


static func lay(room: Room) -> ElectroMagnet:
	var m := ElectroMagnet.new()
	m.name = "ElectroMagnet"
	room.add_child(m)
	m._build(room)
	return m


## For the shader warm-up (warmup.gd): a coil that just stands there, lit.
static func warm(parent: Node, at: Vector3) -> void:
	var m := ElectroMagnet.new()
	m.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(m)
	m.position = at
	var c := m._coil(Vector3.ZERO, 1.0)
	m._coils.append(c)
	(c.mat as StandardMaterial3D).albedo_color.a = 0.8


func _build(room: Room) -> void:
	# Two coils standing free on the floor, one on each side of the room, clear of cover, of
	# where the skeletons rise and of the hero's way in.
	for side: float in [-1.0, 1.0]:
		var spot := Vector3.INF
		for attempt in 30:
			var p := Vector3(side * randf_range(2.4, 4.2), 0, randf_range(-6.0, 3.0))
			var ok := true
			for o: Dictionary in room.obstacles:
				if Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < float(o.r) + 1.6:
					ok = false
			for sp: Dictionary in room.spawns:
				if Vector2(p.x - sp.pos.x, p.z - sp.pos.z).length() < 1.6:
					ok = false
			if ok:
				spot = p
				break
		if spot == Vector3.INF:
			continue
		room.obstacles.append({"pos": spot, "r": 0.5})
		_coils.append(_coil(spot, side))
	_which = randi() % maxi(_coils.size(), 1)
	_t = OFF - FIRST


func _exit_tree() -> void:
	if live == self:
		live = null


## A tall copper coil wound round an iron core on an iron plinth, a polished iron cap on top,
## a blue glow on the floor round it and a light that comes on with it.
func _coil(pos: Vector3, side: float) -> Dictionary:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = pos
	var iron := U.mat(Color(0.22, 0.22, 0.25), 0.45)
	iron.metallic = 0.7
	var copper := U.mat(COPPER, 0.35)
	copper.metallic = 0.85
	U.cylinder(holder, 0.55, 0.3, iron, Vector3.ZERO)
	U.cylinder(holder, 0.24, 1.9, iron, Vector3(0, 0.3, 0))
	for k in 9:
		U.cylinder(holder, 0.4, 0.09, copper, Vector3(0, 0.45 + k * 0.13, 0))
	U.cylinder(holder, 0.46, 0.12, U.mat(Color(0.6, 0.62, 0.68), 0.2), Vector3(0, 1.72, 0))
	U.sphere(holder, 0.2, U.mat(Color(0.6, 0.62, 0.68), 0.2), Vector3(0, 1.95, 0))
	var mat := U.unlit(Color(BLUE.r, BLUE.g, BLUE.b, 0.0), U.soft_circle()).duplicate() as StandardMaterial3D
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var glow := U.floor_quad(holder, Vector2(SHOCK_R * 2.6, SHOCK_R * 2.6), mat, Vector3(0, 0.04, 0))
	# A ring on the floor where it shocks: dark at rest, blue when on.
	var ring_mat := U.unlit(Color(0.1, 0.18, 0.3, 0.6), U.ring()).duplicate() as StandardMaterial3D
	U.floor_quad(holder, Vector2(SHOCK_R * 2.1, SHOCK_R * 2.1), ring_mat, Vector3(0, 0.035, 0))
	var light := OmniLight3D.new()
	light.light_color = BLUE
	light.omni_range = 4.0
	light.light_energy = 0.0
	light.position = Vector3(0, 1.6, 0)
	holder.add_child(light)
	return {"pos": pos, "mat": mat, "ring": ring_mat, "light": light, "glow": glow}


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED or _coils.is_empty() or _which >= _coils.size():
		return
	delta = minf(delta, Actor.MAX_STEP)
	for a in _shocked.keys():
		_shocked[a] -= delta
		if _shocked[a] <= 0.0:
			_shocked.erase(a)
	var c: Dictionary = _coils[_which]
	var mat: StandardMaterial3D = c.mat
	var light: OmniLight3D = c.light
	if not (Game.state == Game.State.PLAYING and Game.fight_on()):
		_switch_off(c)
		return
	_t += delta
	if not _on:
		var warn := _t - (OFF - HUM)
		if warn > 0.0:
			# Humming: it flickers, faster and faster.
			var f := 0.5 + 0.5 * sin(_t * (20.0 + warn * 40.0))
			mat.albedo_color.a = 0.25 * f
			light.light_energy = 0.6 * f
			if warn <= delta:
				Sfx.play("beam", 0.3, 0.6)
				if not _said:
					_said = true
					Game.hud.callout("MAGNET! IT BENDS SHOTS AND PULLS YOU IN!", BLUE, true)
		if _t >= OFF:
			_t = 0.0
			_on = true
			live = self
			Sfx.play("crack", 0.5, 1.5)
		return
	mat.albedo_color.a = 0.55 + 0.15 * sin(_t * 30.0)
	(c.ring as StandardMaterial3D).albedo_color = Color(BLUE.r, BLUE.g, BLUE.b, 0.9)
	light.light_energy = 2.2 + 0.6 * sin(_t * 23.0)
	if randf() < delta * 10.0:
		Fx.sparks((c.pos as Vector3) + Vector3(randf_range(-0.4, 0.4), 0.6 + randf() * 1.2, randf_range(-0.4, 0.4)), BLUE)
	_pull(c, delta)
	if _t >= ON:
		_switch_off(c)
		_which = (_which + 1) % _coils.size()
		_t = 0.0


func _switch_off(c: Dictionary) -> void:
	if _on:
		_on = false
		Sfx.play("door", 0.3, 1.4)
	if live == self:
		live = null
	(c.mat as StandardMaterial3D).albedo_color.a = 0.0
	(c.ring as StandardMaterial3D).albedo_color = Color(0.1, 0.18, 0.3, 0.6)
	(c.light as OmniLight3D).light_energy = 0.0


## Drags everyone towards the coil that is on; whoever reaches it is shocked.
func _pull(c: Dictionary, delta: float) -> void:
	var front: Vector3 = c.pos
	for a: Actor in Actor.all.duplicate():
		if a.dead or (a is Enemy and (a as Enemy).is_boss):
			continue
		if a is Hero and (a as Hero).is_dashing():
			continue
		var d := front - a.global_position
		d.y = 0.0
		var dist := d.length()
		if dist < SHOCK_R:
			if not _shocked.has(a) and a.can_be_hit():
				_shock(a, -d / maxf(dist, 0.05) if dist > 0.05 else Vector3.BACK)
			continue
		var k := clampf(1.0 - dist / (Room.HALF_W * 2.5), 0.5, 1.0)
		var pull := PULL if a is Hero else FOE_PULL
		a.move_by(d / dist * pull * k * delta, delta)


func _shock(a: Actor, out: Vector3) -> void:
	_shocked[a] = 1.2
	Fx.shockwave(a.global_position, BLUE, 1.6)
	Fx.magic(a.center(), BLUE, 16)
	Sfx.play("crack", 0.7, 1.8)
	if a is Hero:
		Game.hit_source = "Magnet"
		a.take_damage(DAMAGE, out, 12.0)
		Game.buzz(60)
	else:
		a.take_damage(a.max_health * FOE_SHARE, out, 10.0)


## Turns `dir` (a shot flying at `p`) towards the coil that is on (projectile.gd).
static func bend(p: Vector3, dir: Vector3, delta: float) -> Vector3:
	if live == null or not is_instance_valid(live) or not live._on:
		return dir
	var c: Dictionary = live._coils[live._which]
	var to: Vector3 = (c.pos as Vector3) - p
	to.y = 0.0
	var dist := to.length()
	if dist < 0.3:
		return dir
	var k := clampf(1.6 - dist / 8.0, 0.25, 1.0)
	var turn := dir.signed_angle_to(to / dist, Vector3.UP)
	return dir.rotated(Vector3.UP, clampf(turn, -BEND * k * delta, BEND * k * delta))


## Whether a coil is on or about to be, and `p` is close to it (for the test robot).
static func near(p: Vector3) -> Vector3:
	if live == null or not is_instance_valid(live):
		return Vector3.ZERO
	var c: Dictionary = live._coils[live._which]
	var d := p - (c.pos as Vector3)
	d.y = 0.0
	return d if d.length() < 3.0 else Vector3.ZERO
