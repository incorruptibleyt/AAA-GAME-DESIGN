class_name Bloodbat
extends Enemy
## Blood Moon event only (events.gd, version 134). A bat with blood-red eyes and veined
## wings that come in flocks of three (Game.spawn_enemy). It flutters at you in a weaving
## line, hangs back a moment while a short strip shows its path, then swoops through you
## and flies off to come round again. One or two shots bring it down. Its touch only hurts
## in the swoop.

enum Mode { FLUTTER, AIM, SWOOP, AWAY }

const RED := Color(1.0, 0.22, 0.18)
const SWOOP_LEN := 6.0
const SWOOP_SPEED := 13.0

var _mode := Mode.FLUTTER
var _timer := 1.0
var _dir := Vector3.FORWARD
var _weave := randf() * TAU


func _setup() -> void:
	init_health(14.0)
	move_speed = 3.6
	contact_damage = 0.0
	drop_chance = 0.04
	radius = 0.42
	center_height = 1.1
	knockback_scale = 1.4
	var look := bones("", 1.0, RED)
	visual = BatVisual.new()
	visual.outline_me = false
	add_child(visual)
	visual.build(look)
	_add_blob()
	_timer = randf_range(0.8, 1.6)


func display_name() -> String:
	return "Bloodbat"


func coin_value() -> int:
	return 0 if randf() < 0.5 else super.coin_value()   # three of them: about the coins of one


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	_timer -= delta
	_weave += delta
	match _mode:
		Mode.FLUTTER:
			var side := to.normalized().cross(Vector3.UP) * sin(_weave * 3.1) * 0.8
			walk(to.normalized() + side, delta)
			if to.length() < 4.5 and _timer <= 0.0:
				_mode = Mode.AIM
				_timer = 0.55 if Game.surge < 0.5 else 0.42
				_dir = to.normalized()
				track(Telegraph.line(global_position, _dir, SWOOP_LEN, 0.8, _timer, Callable()))
				Sfx.play("wraith", 0.22, 2.0)
		Mode.AIM:
			stand(delta)
			face(_dir, 25.0, delta)
			if _timer <= 0.0:
				_mode = Mode.SWOOP
				_timer = SWOOP_LEN / SWOOP_SPEED
				contact_damage = 8.0 * elite_mult()
				visual.attack()
		Mode.SWOOP:
			move_by(_dir * SWOOP_SPEED * delta, delta)
			if _timer <= 0.0:
				_mode = Mode.AWAY
				_timer = 0.9
				contact_damage = 0.0
		Mode.AWAY:
			# Off to one side before coming round again.
			walk(_dir.cross(Vector3.UP) * (1.0 if int(_weave * 10.0) % 2 == 0 else -1.0) + _dir * 0.5, delta, 0.9)
			if _timer <= 0.0:
				_mode = Mode.FLUTTER
				_timer = randf_range(1.2, 2.0)


func _on_death() -> void:
	super._on_death()
	Fx.magic(center(), RED, 10)


## The bat itself: a dark body with ears and glowing eyes, and two wings made of veined
## membrane between finger bones, each on a pivot at the shoulder so it can beat.
class BatVisual extends CharacterVisual:
	var _wings: Array[Node3D] = []
	var _t := randf() * 10.0
	static var _wing_mesh: ArrayMesh
	static var _mats := {}

	func _placeholder(_look: Dictionary) -> Node3D:
		var root := Node3D.new()
		add_child(root)
		if _mats.is_empty():
			_mats.body = U.mat(Color(0.16, 0.06, 0.08), 0.7)
			_mats.wing = U.mat(Color(0.32, 0.05, 0.08), 0.6)
			(_mats.wing as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
			(_mats.wing as StandardMaterial3D).emission_enabled = true
			(_mats.wing as StandardMaterial3D).emission = Color(0.6, 0.05, 0.05)
			(_mats.wing as StandardMaterial3D).emission_energy_multiplier = 0.6
			(_mats.wing as StandardMaterial3D).rim_enabled = true
			(_mats.wing as StandardMaterial3D).rim = 0.8
			_mats.eye = U.unlit(Color(1.0, 0.25, 0.15) * 2.5)
		var body := U.sphere(root, 0.22, _mats.body, Vector3(0, 0, 0))
		body.scale = Vector3(0.9, 0.85, 1.3)
		var head := U.sphere(root, 0.16, _mats.body, Vector3(0, 0.06, -0.3))
		for sd in [-1.0, 1.0]:
			var ear := CylinderMesh.new()
			ear.top_radius = 0.0
			ear.bottom_radius = 0.06
			ear.height = 0.18
			ear.radial_segments = 4
			var em := MeshInstance3D.new()
			em.mesh = ear
			em.material_override = _mats.body
			em.position = Vector3(sd * 0.08, 0.2, -0.3)
			em.rotation.z = -sd * 0.3
			root.add_child(em)
			U.sphere(root, 0.04, _mats.eye, Vector3(sd * 0.06, 0.09, -0.44))
			var pivot := Node3D.new()
			pivot.position = Vector3(sd * 0.14, 0.05, -0.05)
			root.add_child(pivot)
			var wing := MeshInstance3D.new()
			wing.mesh = _wing()
			wing.material_override = _mats.wing
			wing.scale = Vector3(sd, 1, 1)
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(wing)
			pivot.set_meta("side", sd)
			_wings.append(pivot)
		return root

	## One wing (the right one; the left is mirrored): a flat membrane with a scalloped
	## trailing edge, from the shoulder out to the tip.
	static func _wing() -> ArrayMesh:
		if _wing_mesh:
			return _wing_mesh
		var pts := [Vector2(0, 0.08), Vector2(0.35, 0.22), Vector2(0.7, 0.18), Vector2(0.95, 0.02),
			Vector2(0.78, -0.1), Vector2(0.62, -0.02), Vector2(0.45, -0.16), Vector2(0.28, -0.06), Vector2(0.1, -0.16), Vector2(0, -0.1)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		for i in range(1, pts.size() - 1):
			for p: Vector2 in [pts[0], pts[i], pts[i + 1]]:
				st.add_vertex(Vector3(p.x, 0, -p.y))
		_wing_mesh = st.commit()
		return _wing_mesh

	func _process(delta: float) -> void:
		super._process(delta)
		if _dead or _model == null:
			return
		_t += delta
		var beat := sin(_t * 16.0)
		for w in _wings:
			var sd: float = w.get_meta("side")
			w.rotation.z = sd * (0.15 + 0.75 * beat)
		# Flying: held up off the floor, bobbing with the beat.
		_model.position.y += 0.95 + 0.06 * beat
