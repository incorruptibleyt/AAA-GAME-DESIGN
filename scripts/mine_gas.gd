class_name MineGas
extends Node3D
## Version 285 (hard review fix 5, the Amethyst Mine's own danger): firedamp. Cracks at the
## foot of the mine's walls breathe out clouds of pale green gas that drift slowly into the
## room. The gas does nothing on its own, but any shot that flies through it lights it: the
## cloud flares orange for a moment, then blows up, hurting everyone in it, hero and
## skeleton alike, and lighting any cloud next to it. So shoot the gas when skeletons crowd
## into it, keep out of it when skeleton archers are shooting your way, and step out of a
## cloud the moment it flares.
##
## One MineGas node per room keeps the vents; each cloud is a GasCloud child.

const GAS := Color(0.72, 0.86, 0.42)
const FLARE := Color(1.0, 0.55, 0.15)
const EVERY := 7.5          # seconds between a vent's breaths
const FIRST := 2.5          # the first breath, once the skeletons have climbed out
const PER_VENT := 2         # clouds of one vent alive at once
const CLOUD_R := 1.45
const LIFE := 10.0
const SWELL := 0.9          # can't be lit until it has swelled
const DRIFT := 0.32         # m/s into the room
const FUSE := 0.55          # the flare before the blast
const BLAST_R := 2.1
const DAMAGE := 6.0         # to the hero, before the floor's damage scale (x3.4 on floor 7: about 20)
const FOE_SHARE := 0.45     # to skeletons: this share of their full health
const CHAIN := 2.6          # a blast lights clouds this close

## Every cloud in the room (projectile.gd lights them; the test robot steps out of a flare).
static var all: Array[Dictionary] = []   # {node, age, fuse (-1 = unlit), vent}
static var _puff_mat_base: StandardMaterial3D

var _vents: Array[Dictionary] = []   # {pos: Vector3, out: Vector3, t: float, glow: StandardMaterial3D}
var _said := false


static func lay(room: Room) -> MineGas:
	var g := MineGas.new()
	g.name = "MineGas"
	room.add_child(g)
	g._build(room)
	return g


## For the shader warm-up (warmup.gd): a vent and a cloud that just sit there.
static func warm(parent: Node, at: Vector3) -> void:
	var g := MineGas.new()
	g.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(g)
	g.position = at
	g._vent_look(Vector3.ZERO, 1.0)
	g._cloud(Vector3(0, 0, 1.0), -1)


func _exit_tree() -> void:
	for c in all.duplicate():
		if not is_instance_valid(c.node) or (c.node as Node).get_parent() == self:
			all.erase(c)


func _build(room: Room) -> void:
	# Two vents on opposite walls, away from the door and the hero's way in.
	var sides := [-1.0, 1.0]
	sides.shuffle()
	for i in 2:
		var side: float = sides[i]
		var z := randf_range(-6.0, 3.0)
		for attempt in 12:
			var ok := true
			for o: Dictionary in room.obstacles:
				if Vector2(side * (Room.HALF_W - 0.3) - o.pos.x, z - o.pos.z).length() < float(o.r) + 1.0:
					ok = false
			if ok:
				break
			z = randf_range(-6.0, 3.0)
		var pos := Vector3(side * (Room.HALF_W - 0.15), 0, z)
		_vents.append({"pos": pos, "out": Vector3(-side, 0, randf_range(-0.25, 0.25)).normalized(),
			"t": EVERY - FIRST - i * 2.2, "glow": _vent_look(pos, side)})


## A crack at the foot of the wall, glowing a sickly green, with a heap of broken rock.
func _vent_look(pos: Vector3, side: float) -> StandardMaterial3D:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = pos
	var rock := U.mat(Color(0.3, 0.29, 0.32), 0.95)
	for k in 4:
		var s := U.sphere(holder, randf_range(0.16, 0.26), rock, Vector3(-side * randf_range(0.1, 0.35), 0.08, randf_range(-0.55, 0.55)))
		s.scale.y = 0.6
	var glow := U.unlit(Color(GAS.r, GAS.g, GAS.b, 0.55), U.soft_circle()).duplicate() as StandardMaterial3D
	var pool := U.floor_quad(holder, Vector2(1.3, 1.6), glow, Vector3(-side * 0.35, 0.03, 0))
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var crack := U.box(holder, Vector3(0.08, 0.9, 0.7), U.unlit(Color(0.8, 1.0, 0.5)), Vector3(0, 0.45, 0))
	crack.rotation.x = 0.15
	# A miner's warning sign, nailed up beside it: a yellow diamond.
	var sign := U.box(holder, Vector3(0.04, 0.32, 0.32), U.mat(Color(0.95, 0.78, 0.15), 0.6, 0.15), Vector3(-side * 0.05, 1.35, 0.75))
	sign.rotation.x = PI / 4.0
	U.box(holder, Vector3(0.05, 0.1, 0.1), U.mat(Color(0.1, 0.1, 0.1), 0.6), Vector3(-side * 0.07, 1.35, 0.75))
	return glow


func _cloud(at: Vector3, vent: int) -> void:
	if _puff_mat_base == null:
		_puff_mat_base = U.unlit(Color(GAS.r, GAS.g, GAS.b, 0.0), U.soft_circle(), true).duplicate()
	var node := Node3D.new()
	add_child(node)
	node.position = at
	var floor_mat := U.unlit(Color(GAS.r * 0.7, GAS.g * 0.8, GAS.b * 0.5, 0.0), U.soft_circle()).duplicate() as StandardMaterial3D
	U.floor_quad(node, Vector2(CLOUD_R * 2.3, CLOUD_R * 2.3), floor_mat, Vector3(0, 0.035, 0))
	# A dark green rim on the floor shows its edge (where its blast reaches) on any floor.
	var rim_mat := U.unlit(Color(0.12, 0.2, 0.04, 0.0), U.ring()).duplicate() as StandardMaterial3D
	U.floor_quad(node, Vector2(BLAST_R * 2.1, BLAST_R * 2.1), rim_mat, Vector3(0, 0.03, 0))
	var puff_mat := _puff_mat_base.duplicate() as StandardMaterial3D
	var puffs: Array[MeshInstance3D] = []
	for i in 6:
		var a := TAU * i / 6.0 + randf() * 0.5
		var d := CLOUD_R * (0.1 if i == 0 else randf_range(0.35, 0.65))
		var q := QuadMesh.new()
		var s := CLOUD_R * randf_range(0.85, 1.15)
		q.size = Vector2(s, s)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = puff_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * d, 0.5 + randf() * 0.4, sin(a) * d)
		node.add_child(mi)
		puffs.append(mi)
	all.append({"node": node, "age": 0.0, "fuse": -1.0, "vent": vent, "floor": floor_mat, "puff": puff_mat, "rim": rim_mat,
		"puffs": puffs, "seed": randf() * TAU})


## A shot at `p` lights any cloud it is in (projectile.gd calls this while clouds exist).
static func touch(p: Vector3) -> void:
	for c in all:
		if c.fuse < 0.0 and c.age > SWELL and is_instance_valid(c.node):
			var n: Node3D = c.node
			if Vector2(p.x - n.global_position.x, p.z - n.global_position.z).length() < CLOUD_R * 0.9:
				c.fuse = FUSE
				Sfx.play("ignite", 0.5)   # a whoosh as it catches


## Whether `p` is inside a cloud that is about to blow up (for the test robot).
static func flaring(p: Vector3, margin := 0.4) -> Node3D:
	for c in all:
		if c.fuse >= 0.0 and is_instance_valid(c.node):
			var n: Node3D = c.node
			if Vector2(p.x - n.global_position.x, p.z - n.global_position.z).length() < BLAST_R + margin:
				return n
	return null


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	delta = minf(delta, Actor.MAX_STEP)
	var fighting := Game.state == Game.State.PLAYING and Game.fight_on()
	for i in _vents.size():
		var v: Dictionary = _vents[i]
		var glow: StandardMaterial3D = v.glow
		glow.albedo_color.a = 0.4 + 0.15 * sin(Time.get_ticks_msec() * 0.003 + i)
		if not fighting:
			continue
		v.t += delta
		if v.t >= EVERY:
			v.t = 0.0
			var mine := 0
			for c in all:
				if c.vent == i and is_instance_valid(c.node) and (c.node as Node).get_parent() == self:
					mine += 1
			if mine < PER_VENT:
				_cloud(v.pos + v.out * 1.3, i)
				Sfx.play("splash", 0.25, 0.5)   # a low hiss
				if not _said:
					_said = true
					Game.hud.callout("MINE GAS! A SHOT LIGHTS IT!", GAS, true)
	for c in all.duplicate():
		if not is_instance_valid(c.node) or (c.node as Node).get_parent() != self:
			continue
		var n: Node3D = c.node
		c.age += delta
		var vent: Dictionary = _vents[c.vent] if c.vent >= 0 else {}
		if not vent.is_empty():
			var to := Vector3(0, 0, -1.0) - n.position
			to.y = 0.0
			var way: Vector3 = (vent.out as Vector3) * 0.6 + to.normalized() * 0.4
			n.position += way.normalized() * DRIFT * delta
		var k := minf(c.age / SWELL, 1.0)
		var fade := clampf((LIFE - c.age) / 1.0, 0.0, 1.0)
		var flare := 0.0
		if c.fuse >= 0.0:
			c.fuse -= delta
			flare = 1.0 - c.fuse / FUSE
			if c.fuse <= 0.0:
				_blast(c)
				continue
		else:
			if not fighting:
				c.age = maxf(c.age, LIFE - 1.0)   # the fight is over: the gas thins away
			if c.age >= LIFE:
				all.erase(c)
				n.queue_free()
				continue
		var col := GAS.lerp(FLARE, flare)
		var fm: StandardMaterial3D = c.floor
		fm.albedo_color = Color(col.r * 0.8, col.g * 0.8, col.b * 0.6, (0.45 + 0.4 * flare) * k * fade)
		var pm: StandardMaterial3D = c.puff
		pm.albedo_color = Color(col.r, col.g, col.b, (0.5 + 0.35 * flare) * k * fade)
		var rm: StandardMaterial3D = c.rim
		rm.albedo_color = Color(0.12 + 0.6 * flare, 0.2 + 0.1 * flare, 0.04, 0.75 * k * fade)
		var puffs: Array = c.puffs
		for j in puffs.size():
			var p: MeshInstance3D = puffs[j]
			var s: float = (0.3 + 0.7 * ease(k, 0.4)) * (1.0 + 0.1 * sin(c.age * 1.6 + c.seed + j)) * (1.0 + 0.35 * flare)
			p.scale = Vector3.ONE * s


func _blast(c: Dictionary) -> void:
	all.erase(c)
	var n: Node3D = c.node
	var at := n.global_position
	n.queue_free()
	Fx.shockwave(at, FLARE, BLAST_R + 0.6)
	Fx.impact(at + Vector3.UP * 0.6, FLARE, 3.0)
	Sfx.play("boom", 0.8)
	Game.shake(0.25)
	var hero := Game.hero
	if hero and hero.can_be_hit():
		var d := hero.global_position - at
		d.y = 0.0
		if d.length() < BLAST_R + hero.radius * 0.5:
			Game.hit_source = "Mine gas"
			hero.take_damage(DAMAGE, d.normalized() if d.length() > 0.05 else Vector3.BACK, 8.0)
	for a: Actor in Actor.all.duplicate():
		if a is Enemy and not (a as Enemy).is_boss and a.can_be_hit():
			var e := a.global_position - at
			e.y = 0.0
			if e.length() < BLAST_R + a.radius * 0.5:
				a.take_damage(a.max_health * FOE_SHARE, e.normalized() if e.length() > 0.05 else Vector3.BACK, 7.0)
	# A blast lights the clouds next to it.
	for o in all:
		if o.fuse < 0.0 and o.age > SWELL * 0.5 and is_instance_valid(o.node):
			if (o.node as Node3D).global_position.distance_to(at) < CHAIN + CLOUD_R:
				o.fuse = FUSE * 0.6
