class_name MageArms
## Version 228 (Jesse: "the mage weapons ... aren't they just reskins?"): they were. The
## Frostforged staff, Gilded arms and Voidsteel arms were the Mage's plain staff in ice, gold
## and violet, and the Emberforged tome was the open spellbook in orange. Each now has its
## own shape on top of its finish:
## - Frostforged staff: a crown of ice crystals with three shards circling it.
## - Gilded arms: a sun staff, a turning gold sun wheel round a white-hot orb.
## - Voidsteel arms: a void scythe, a curved violet blade with a black orb and two motes.
## - Emberforged tome: the open book burns, flames rising off its pages with embers circling.
## Built in the weapon mesh's own space (the staff's long axis is y, its head near y 1.1), so
## the shapes scale with the weapon in a run.

static var _mats := {}
const STAFF := "2H_Staff"
const BOOK := "Spellbook_open"
## Which finish gives which shape, per weapon part.
const SHAPES := {STAFF: {"frost": "ice", "gold": "sun", "void": "scythe"}, BOOK: {"ember": "fire"}}


## Puts the shape for `finish` on weapon `mi`, or takes an old one off.
static func dress(mi: MeshInstance3D, finish: String) -> void:
	var want: String = SHAPES.get(str(mi.name), {}).get(finish, "")
	var old := mi.get_node_or_null("MageArms")
	if old:
		if str(old.get_meta("shape", "")) == want:
			return
		mi.remove_child(old)
		old.queue_free()
	if want == "":
		return
	var root := Node3D.new()
	root.name = "MageArms"
	root.set_meta("shape", want)
	mi.add_child(root)
	match want:
		"ice":
			_ice(root)
		"sun":
			_sun(root)
		"scythe":
			_scythe(root)
		"fire":
			_fire(root)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.set_meta("fx", true)   # (the hit flash would turn them white)


# ---------------------------------------------------------------- the four shapes

const HEAD := Vector3(0, 1.12, 0)


## A crown of ice: one tall crystal, five leaning out round it, three shards circling.
static func _ice(root: Node3D) -> void:
	var ice := _mat("ice")
	var still := Node3D.new()
	still.name = "Still"
	root.add_child(still)
	_crystal(still, HEAD + Vector3(0, 0.05, 0), Vector3.UP, 0.17, 1.05, ice)
	for i in 5:
		var a := i / 5.0 * TAU + 0.3
		var out := Vector3(sin(a), 0, cos(a))
		var dir := (out * 0.8 + Vector3(0, 1, 0)).normalized()
		_crystal(still, HEAD + out * 0.12 - Vector3(0, 0.04, 0), dir, 0.1, 0.55 + 0.18 * float(i % 2), ice)
	FeatHeads.bake(still, "mage_arms ice")
	var ring := Spin.new()
	ring.speed = 1.7
	ring.position = HEAD + Vector3(0, 0.12, 0)
	root.add_child(ring)
	for i in 3:
		var a := i / 3.0 * TAU
		_crystal(ring, Vector3(sin(a), 0, cos(a)) * 0.58, Vector3(0, 1, 0), 0.07, 0.34, ice)
	_glow(root, HEAD + Vector3(0, 0.3, 0), 0.6, Color(0.35, 0.85, 1.0, 0.3))


## A sun staff: a white-hot orb in a gold ring with twelve rays, turning slowly.
static func _sun(root: Node3D) -> void:
	var gold := _mat("gold")
	var wheel := Spin.new()
	wheel.speed = 0.7
	wheel.position = HEAD
	root.add_child(wheel)
	var band := TorusMesh.new()
	band.inner_radius = 0.27
	band.outer_radius = 0.35
	band.rings = 24
	band.ring_segments = 6
	_part(wheel, band, gold, Vector3.ZERO)
	for i in 12:
		var a := i / 12.0 * TAU
		var out := Vector3(sin(a), 0, cos(a))
		var long := i % 2 == 0
		_cone(wheel, out * 0.34, out, 0.075 if long else 0.055, 0.34 if long else 0.2, gold)
	FeatHeads.bake(wheel, "mage_arms sun")
	var core := SphereMesh.new()
	core.radius = 0.17
	core.height = 0.34
	core.radial_segments = 12
	core.rings = 6
	_part(root, core, _mat("sun core"), HEAD)
	_glow(root, HEAD, 0.55, Color(1.0, 0.75, 0.25, 0.3))


## A void scythe: a long curved blade sweeping out and down from the head, a black orb where
## it meets the staff, and two violet motes circling the orb.
static func _scythe(root: Node3D) -> void:
	var blade := MeshInstance3D.new()
	blade.mesh = _blade_mesh()
	blade.material_override = _mat("void blade")
	root.add_child(blade)
	var edge := MeshInstance3D.new()
	edge.mesh = _blade_mesh(true)
	edge.material_override = _mat("void edge")
	root.add_child(edge)
	var orb := SphereMesh.new()
	orb.radius = 0.15
	orb.height = 0.3
	orb.radial_segments = 12
	orb.rings = 6
	_part(root, orb, _mat("void orb"), HEAD + Vector3(0, 0.08, 0))
	_glow(root, HEAD + Vector3(0, 0.08, 0), 0.34, Color(0.6, 0.25, 1.0, 0.4))
	var motes := Spin.new()
	motes.speed = -2.2
	motes.position = HEAD + Vector3(0, 0.08, 0)
	root.add_child(motes)
	for i in 2:
		var a := i * PI
		var m := SphereMesh.new()
		m.radius = 0.05
		m.height = 0.1
		m.radial_segments = 8
		m.rings = 4
		_part(motes, m, _mat("void mote"), Vector3(sin(a), 0.1 * (1 - 2 * i), cos(a)) * 0.3)


## The burning tome: three flames rising off the top of the open book and four embers
## circling them. The fire always rises straight up in the world, however the hand swings.
static func _fire(root: Node3D) -> void:
	# (The open book stands about 0.83 wide and 0.57 tall in its x-y plane, its pages facing
	# +z; the fire sits on its top edge.)
	var top := Vector3(0, 0.24, 0.03)
	var up := Upright.new()
	up.position = top
	root.add_child(up)
	var flames := Lick.new()
	up.add_child(flames)
	for f: Array in [[Vector3(0, 0, 0), 0.2, 0.85], [Vector3(-0.24, 0, 0.02), 0.14, 0.55], [Vector3(0.24, 0, -0.02), 0.14, 0.62]]:
		_cone(flames, f[0], Vector3.UP, f[1], f[2], _mat("flame"))
		_cone(flames, f[0] + Vector3(0, 0.02, 0), Vector3.UP, f[1] * 0.55, f[2] * 0.7, _mat("flame core"))
	var embers := Spin.new()
	embers.speed = 2.0
	embers.position = Vector3(0, 0.45, 0)
	up.add_child(embers)
	for i in 4:
		var a := i / 4.0 * TAU
		var e := BoxMesh.new()
		e.size = Vector3(0.08, 0.08, 0.08)
		_part(embers, e, _mat("flame core"), Vector3(sin(a), 0.12 * sin(a * 2.0), cos(a)) * 0.42)
	_glow(up, Vector3(0, 0.3, 0), 0.42, Color(1.0, 0.5, 0.12, 0.26))


# ---------------------------------------------------------------- parts

## A long crystal (two pyramids base to base), from `at` along `dir`.
static func _crystal(root: Node3D, at: Vector3, dir: Vector3, r: float, h: float, mat: Material) -> void:
	var d := dir.normalized()
	_cone(root, at + d * h * 0.25, d, r, h * 0.75, mat)
	_cone(root, at + d * h * 0.25, -d, r, h * 0.25, mat)


## A four-sided point standing at `at` (its base), pointing along `dir`.
static func _cone(root: Node3D, at: Vector3, dir: Vector3, r: float, h: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 4 if mat == _mat("ice") else 6
	c.rings = 1
	var d := dir.normalized()
	var m := _part(root, c, mat, at + d * h * 0.5)
	m.quaternion = Quaternion(Vector3.UP, d)


static func _part(root: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
	return mi


## A soft round glow (additive), so the shape reads against a dark floor.
static func _glow(root: Node3D, at: Vector3, r: float, col: Color) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	var key := "glow %s" % col
	if not _mats.has(key):
		var m := U.unlit(col).duplicate() as StandardMaterial3D
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	_part(root, s, _mats[key], at)


static var _blades := {}

## The scythe blade: a crescent in the staff's x-y plane, from the head out to the right and
## curving down to a point, thick enough to read from any side. `rim`: a thin glowing strip
## along its outer edge instead.
static func _blade_mesh(rim := false) -> ArrayMesh:
	if _blades.has(rim):
		return _blades[rim]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	var outer := []
	var inner := []
	for i in steps + 1:
		var t := i / float(steps)
		# outer arc: from above the head, round to the right and down to the tip
		var a := lerpf(0.15, 2.2, t)
		var o := Vector2(0.05, 1.12) + Vector2(sin(a), cos(a)) * 0.78
		# the blade is widest a third of the way along and comes to a point at the tip
		var w := sin(clampf(t * 1.05, 0.0, 1.0) * PI) * 0.3 * (1.0 - t * 0.35)
		var n := Vector2(sin(a), cos(a))
		outer.append(o)
		inner.append(o - n * (0.035 if rim else w + 0.01))
	if rim:
		for i in outer.size():
			outer[i] = (outer[i] as Vector2) + Vector2(sin(lerpf(0.15, 2.2, i / float(steps))), cos(lerpf(0.15, 2.2, i / float(steps)))) * 0.025
	var half := 0.035 if not rim else 0.045
	for i in steps:
		for side: float in [-half, half]:
			var p0 := Vector3(outer[i].x, outer[i].y, side)
			var p1 := Vector3(outer[i + 1].x, outer[i + 1].y, side)
			var q0 := Vector3(inner[i].x, inner[i].y, side)
			var q1 := Vector3(inner[i + 1].x, inner[i + 1].y, side)
			for v in [p0, p1, q1, p0, q1, q0]:
				st.set_normal(Vector3(0, 0, signf(side)))
				st.add_vertex(v)
		# the outer and inner edges
		for e: Array in [[outer[i], outer[i + 1]], [inner[i], inner[i + 1]]]:
			var a0 := Vector3(e[0].x, e[0].y, -half)
			var a1 := Vector3(e[1].x, e[1].y, -half)
			var b0 := Vector3(e[0].x, e[0].y, half)
			var b1 := Vector3(e[1].x, e[1].y, half)
			var nrm := Vector3(e[1].y - e[0].y, e[0].x - e[1].x, 0).normalized()
			for v in [a0, a1, b1, a0, b1, b0]:
				st.set_normal(nrm)
				st.add_vertex(v)
	var am := st.commit()
	_blades[rim] = am
	return am


static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"ice":
			m.albedo_color = Color(0.72, 0.94, 1.0)
			m.metallic = 0.3
			m.roughness = 0.08
			m.emission_enabled = true
			m.emission = Color(0.35, 0.8, 1.0)
			m.emission_energy_multiplier = 0.75
		"gold":
			m.albedo_color = Color(1.0, 0.8, 0.3)
			m.metallic = 0.8
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(1.0, 0.68, 0.18)
			m.emission_energy_multiplier = 0.7
		"sun core":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.95, 0.75) * 1.3
		"void blade":
			m.albedo_color = Color(0.13, 0.07, 0.22)
			m.metallic = 0.85
			m.roughness = 0.25
			m.emission_enabled = true
			m.emission = Color(0.35, 0.12, 0.6)
			m.emission_energy_multiplier = 0.5
		"void edge":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.82, 0.55, 1.0) * 1.2
		"void orb":
			m.albedo_color = Color(0.03, 0.01, 0.06)
			m.metallic = 0.4
			m.roughness = 0.1
			m.emission_enabled = true
			m.emission = Color(0.3, 0.05, 0.5)
			m.emission_energy_multiplier = 0.4
		"void mote":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.85, 0.6, 1.0) * 1.3
		"flame":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.42, 0.08, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		"flame core":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.85, 0.35) * 1.2
	_mats[kind] = m
	return m


## Turns round `axis` (in its own space) at `speed` radians a second.
class Spin extends Node3D:
	var speed := 1.0
	var axis := Vector3.UP

	func _process(delta: float) -> void:
		rotate_object_local(axis, speed * delta)


## Keeps its children level with the world (same size, no tilt), so fire rises straight up.
class Upright extends Node3D:
	func _process(_delta: float) -> void:
		global_basis = Basis.from_scale(global_basis.get_scale())


## Flames that lick up and down.
class Lick extends Node3D:
	var _t := randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta
		var k := 1.0 + 0.16 * sin(_t * 11.0) + 0.08 * sin(_t * 23.0)
		scale = Vector3(1.0 - (k - 1.0) * 0.4, k, 1.0 - (k - 1.0) * 0.4)
