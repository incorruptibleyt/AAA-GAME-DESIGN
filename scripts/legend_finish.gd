class_name LegendFinish
extends RefCounted
## Version 314 (Legend Vault, legends.gd): finishers, what happens when a skeleton falls.
##   gold_rush:    Gold Rush. The skeleton bursts into a fountain of gold coins that spin up
##                 out of it and rain down around it, with a glint and a chink. (Only a show:
##                 the coins it really drops are the usual ones.)
##   soul_harvest: Soul Harvest. A little ghost rises out of the skeleton, hangs for a moment,
##                 then flies into the hero, who flashes pale blue as it arrives.
## Game.on_enemy_died calls `play` for the finisher the hero wears (Hero.finisher). On a
## pedestal a Show plays it over and over beside the hero, on a little skull that pops.

const MAX_SOULS := 10   # ghosts in the air at once (a crowd falling at once sends the first ten)
static var _souls := 0
static var _coin_frame := -1
static var _coin_bursts := 0


static func play(kind: String, at: Vector3, world: Node3D, hero: Node3D) -> void:
	if world == null:
		return
	match kind:
		"gold_rush":
			_gold_rush(at, world)
		"soul_harvest":
			if hero and _souls < MAX_SOULS:
				_soul(at, world, hero)


# ---------------------------------------------------------------- Gold Rush

static var _coin_pool: Array = []


static func _gold_rush(at: Vector3, world: Node3D) -> void:
	# (At most three fountains a frame: a Bomber's blast can fell a whole crowd at once.)
	var f := Engine.get_process_frames()
	if f != _coin_frame:
		_coin_frame = f
		_coin_bursts = 0
	_coin_bursts += 1
	if _coin_bursts > 3:
		return
	var p: CPUParticles3D = null
	while not _coin_pool.is_empty():
		var old: Variant = _coin_pool.pop_back()
		if is_instance_valid(old) and (old as Node).get_parent() == world:
			p = old
			break
	if p == null:
		p = _coin_fountain()
		world.add_child(p)
		p.finished.connect(func():
			if is_instance_valid(p) and _coin_pool.size() < 12:
				_coin_pool.append(p)
			elif is_instance_valid(p):
				p.queue_free())
	p.global_position = at + Vector3(0, 0.6, 0)
	p.restart()
	if world == Game.world:   # (not on a pedestal: Fx bursts belong to the run's world)
		Fx._burst(at + Vector3(0, 0.8, 0), 10, Color(1.0, 0.85, 0.35), 0.5, 3.0, 0.5, 0.0, true, "glint")
		Sfx.play("coin", 0.35, randf_range(0.95, 1.25))


static var _coin_mesh: Mesh


## A fountain of gold coins: flat discs that spring up out of the skeleton, spinning, and rain
## down around it.
static func _coin_fountain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 16
	p.lifetime = 1.15
	p.explosiveness = 0.8
	p.direction = Vector3.UP
	p.spread = 24.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -13.0, 0)
	p.particle_flag_rotate_y = true
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	if _coin_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.11
		c.bottom_radius = 0.11
		c.height = 0.03
		c.radial_segments = 12
		c.rings = 1
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.78, 0.25)
		m.metallic = 0.7
		m.roughness = 0.3
		m.emission_enabled = true
		m.emission = Color(1.0, 0.65, 0.15)
		m.emission_energy_multiplier = 0.9
		c.material = m
		_coin_mesh = c
	p.mesh = _coin_mesh
	# (tipped a little, so they flash as they spin)
	p.rotation = Vector3(0.35, 0, 0.2)
	return p


# ---------------------------------------------------------------- Soul Harvest

static func _soul(at: Vector3, world: Node3D, hero: Node3D) -> void:
	var s := Soul.new()
	s.target = hero
	world.add_child(s)
	s.global_position = at + Vector3(0, 0.7, 0)


## A little ghost that rises out of a fallen skeleton, then flies into the hero.
class Soul extends Node3D:
	var target: Node3D
	var _t := 0.0
	var _from := Vector3.ZERO
	var _mat: StandardMaterial3D
	var _tail: Array[Node3D] = []
	var _trail: Array[Vector3] = []

	func _ready() -> void:
		LegendFinish._souls += 1
		_mat = LegendPet._add_mat(Color(0.7, 0.92, 1.0, 0.95), true)
		var body := MeshInstance3D.new()
		body.mesh = LegendPet._quad(0.75)
		body.material_override = _mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
		var core := MeshInstance3D.new()
		core.mesh = LegendPet._quad(0.32)
		core.material_override = _mat
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(core)
		# A face: two dark eyes, so it reads as a ghost and not a spark.
		var dark := LegendPet._mat("soul_eye", Color(0.05, 0.1, 0.2), 0.5)
		for side in [-1.0, 1.0]:
			var e := U.sphere(self, 0.045, dark, Vector3(0.07 * side, 0.03, 0.12))
			e.scale = Vector3(0.8, 1.3, 0.5)
		for i in 4:
			var q := MeshInstance3D.new()
			q.mesh = LegendPet._quad(0.5 - i * 0.09)
			q.material_override = _mat
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.top_level = true
			add_child(q)
			_tail.append(q)

	func _exit_tree() -> void:
		LegendFinish._souls -= 1

	func _process(delta: float) -> void:
		_t += delta
		if _t < 0.5:
			# Rising, swaying, out of the bones.
			position += Vector3(sin(_t * 14.0) * 0.6 * delta, 2.4 * delta * (1.0 - _t), 0)
			_from = global_position
		else:
			if target == null or not is_instance_valid(target):
				queue_free()
				return
			var goal := target.global_position + Vector3(0, 1.1, 0)
			var k := minf(1.0, (_t - 0.5) / 0.5)
			var arc := Vector3.UP * sin(k * PI) * 0.8
			global_position = _from.lerp(goal, k * k) + arc
			if k >= 1.0:
				if get_parent() == Game.world:
					Fx.magic(goal, Color(0.6, 0.9, 1.0), 10)
				queue_free()
				return
		var face := Vector3(0, 0, 1)
		var cam := get_viewport().get_camera_3d()
		if cam:
			face = (cam.global_position - global_position).normalized()
		look_at(global_position - face, Vector3.UP)
		_trail.push_front(global_position)
		if _trail.size() > 12:
			_trail.pop_back()
		for i in _tail.size():
			_tail[i].global_position = _trail[mini(_trail.size() - 1, 2 + i * 3)]
		_mat.albedo_color.a = 0.95 * minf(1.0, _t * 6.0)


# ---------------------------------------------------------------- on a pedestal

## The finisher shown over and over beside the hero on a pedestal: a skull pops, then the
## finisher plays on it.
class Show extends Node3D:
	var kind := ""
	var _t := 1.0
	var _skull: Node3D
	var _hero: Node3D

	func _ready() -> void:
		_hero = get_parent() as Node3D
		_skull = Node3D.new()
		add_child(_skull)
		var bone := LegendPet._mat("show_skull", Color(0.92, 0.9, 0.82), 0.7)
		var dark := LegendPet._mat("show_eye", Color(0.1, 0.06, 0.08), 0.7)
		var head := U.sphere(_skull, 0.2, bone, Vector3.ZERO)
		head.scale = Vector3(1.0, 0.95, 1.05)
		U.box(_skull, Vector3(0.2, 0.1, 0.12), bone, Vector3(0, -0.15, -0.08))
		for side in [-1.0, 1.0]:
			U.sphere(_skull, 0.055, dark, Vector3(0.075 * side, 0.0, -0.17))
		_skull.position = Vector3(-0.95, 0.25, -0.35)

	func _process(delta: float) -> void:
		_t += delta
		var cycle := 2.2
		var k := fmod(_t, cycle)
		# The skull bobs, then shrinks to nothing as the finisher bursts out of it.
		_skull.scale = Vector3.ONE * (1.0 if k < 0.9 else maxf(0.0, 1.0 - (k - 0.9) * 8.0)) if k < 1.4 else Vector3.ONE * smoothstep(1.4, 2.2, k)
		_skull.position.y = 0.25 + sin(_t * 3.0) * 0.04
		if k - delta < 0.95 and k >= 0.95:
			LegendFinish.play(kind, _skull.global_position - Vector3(0, 0.3, 0), get_parent().get_parent() as Node3D, _hero)
