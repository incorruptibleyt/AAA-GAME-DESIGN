class_name CryptArms
## The Crypt King's arms (version 201, the Crypt King set's weapon, hero_style.gd PASS_HOLD):
## each hero's grandest weapon in obsidian (LookFx.weapon finish "crypt") wearing the set's
## crown. Gold crown points run along it, a soul gem burns teal at its heart and pommel,
## and the Mage's staff carries a small Crypt Crown with a soul flame inside. Version 198 was
## the plain weapon in obsidian and teal: critics called it a recolour that looked like ice.
## Built in the weapon mesh's own space (its long axis is y), so it scales with the weapon.

static var _gold: StandardMaterial3D
static var _soul: StandardMaterial3D
static var _halo: StandardMaterial3D
const DRESSED := ["2H_Sword", "2H_Axe", "2H_Staff", "2H_Crossbow", "Knife_Offhand"]


## Puts the crown points and soul gems on weapon `mi` (once), or takes them off when `on`
## is false.
static func dress(mi: MeshInstance3D, on: bool) -> void:
	var old := mi.get_node_or_null("CryptArms")
	if old:
		if on:
			return
		mi.remove_child(old)
		old.queue_free()
		return
	if not on or not str(mi.name) in DRESSED:
		return
	_materials()
	var root := Node3D.new()
	root.name = "CryptArms"
	mi.add_child(root)
	# Gold points and soul gems go in two groups, each baked into one cached mesh below.
	var gold := Node3D.new()
	gold.name = "Gold"
	root.add_child(gold)
	var soul := Node3D.new()
	soul.name = "Soul"
	root.add_child(soul)
	match str(mi.name):
		"2H_Sword":
			# A king's blade: three big crown points on each edge near a great winged gold
			# guard. (v201 had five pairs up the whole blade: from above it read as hazard tape.)
			for i in 3:
				var y := 0.55 + i * 0.2
				for s in [-1.0, 1.0]:
					_point(root, Vector3(s * 0.14, y, 0), Vector3(s, 0.8, 0), 0.09, 0.3 - i * 0.06)
			for s in [-1.0, 1.0]:
				_point(root, Vector3(s * 0.2, 0.3, 0), Vector3(s, 0.75, 0), 0.13, 0.62)
			_gem(root, Vector3(0, 0.32, 0), 0.14)
			_gem(root, Vector3(0, -0.38, 0), 0.05)
		"2H_Axe":
			# Crown points along both blades' outer edges and three standing on the head.
			for s in [-1.0, 1.0]:
				for i in 3:
					_point(root, Vector3(s * 0.58, 0.72 + i * 0.2, 0), Vector3(s, 0.25, 0), 0.07, 0.22)
			for i in 3:
				_point(root, Vector3((i - 1) * 0.16, 1.24, 0), Vector3(0, 1, 0), 0.07, 0.28 if i == 1 else 0.2)
			_gem(root, Vector3(0, 0.98, 0), 0.14)
			_gem(root, Vector3(0, -0.4, 0), 0.05)
		"2H_Staff":
			# A small Crypt Crown on the head of the staff, a soul flame burning inside it.
			var top := Vector3(0, 1.12, 0)
			var band := TorusMesh.new()
			band.inner_radius = 0.17
			band.outer_radius = 0.23
			band.rings = 16
			band.ring_segments = 6
			_mesh(gold, band, _gold, top)
			for i in 5:
				var a := i / 5.0 * TAU
				var d := Vector3(sin(a), 0, cos(a))
				_point(root, top + d * 0.2, d * 0.35 + Vector3(0, 1, 0), 0.06, 0.3 if i % 2 == 0 else 0.22)
			_gem(root, top + Vector3(0, 0.16, 0), 0.17)
			_gem(root, Vector3(0, -0.86, 0), 0.04)   # (small: two big orbs read as a dumbbell)
		"2H_Crossbow":
			# One great crown point at each limb tip, a gold crown standing over the bow and a
			# big soul gem loaded as the bolt. (v201's small points along the stock made it a
			# thin striped stick from above.)
			for s in [-1.0, 1.0]:
				_point(root, Vector3(s * 0.56, 0.0, 0.95), Vector3(s, 0, 0.5), 0.11, 0.42)
			for i in 3:
				_point(root, Vector3((i - 1) * 0.16, 0.12, 0.9), Vector3((i - 1) * 0.3, 1, 0), 0.08, 0.34 if i == 1 else 0.24)
			_gem(root, Vector3(0, 0.08, 1.2), 0.2)
		"Knife_Offhand":
			_gem(root, Vector3(0, -0.18, 0), 0.07)
	# (v202: one draw for the gold, one for the gems, instead of a node per point.)
	FeatHeads.bake(gold, "crypt_arms gold " + str(mi.name))
	FeatHeads.bake(soul, "crypt_arms soul " + str(mi.name))
	for c in soul.get_children():
		c.set_meta("fx", true)


static func _materials() -> void:
	if _gold:
		return
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.8, 0.32)
	_gold.metallic = 0.75
	_gold.roughness = 0.22
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.7, 0.22)
	_gold.emission_energy_multiplier = 0.55
	_soul = StandardMaterial3D.new()
	_soul.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_soul.albedo_color = Color(0.25, 1.0, 0.8) * 1.2
	_halo = U.unlit(Color(0.2, 1.0, 0.8, 0.35)).duplicate()
	_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


## A gold crown point standing at `at`, pointing along `dir`.
static func _point(root: Node3D, at: Vector3, dir: Vector3, r: float, h: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	var d := dir.normalized()
	var m := _mesh(root.get_node("Gold"), c, _gold, at + d * h * 0.5)
	m.quaternion = Quaternion(Vector3.UP, d)


## A teal soul gem with a soft glow round it.
static func _gem(root: Node3D, at: Vector3, r: float) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	_mesh(root.get_node("Soul"), s, _soul, at)
	var g := SphereMesh.new()
	g.radius = r * 1.7
	g.height = r * 3.4
	g.radial_segments = 10
	g.rings = 5
	_mesh(root.get_node("Soul"), g, _halo, at)


static func _mesh(root: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
