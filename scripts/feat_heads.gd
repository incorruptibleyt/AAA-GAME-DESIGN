class_name FeatHeads
extends Node3D
## Headwear won by Feats or found in Bone Drops (hero_style.gd EXTRA "head"), built in the
## head bone's space like the crowns: the Storm Halo, Star Circlet, Flame Horns and Skull
## Helm (Feats), and Antlers, Phantom Horns and the Bone Mask (Legendary drops). Crowns are
## kept for the Crypt Pass and Mastery (version 116 turned the Flame Crown into horns and
## the Bone Crown into a mask). The halo and the circlet's stars turn.
##
## Each head is built from simple shapes, then baked (bake below) into one mesh with one
## surface per material, cached: version 115 drew each piece on its own (the Storm Halo was
## 59 draw calls).

var kind := ""
var _t := 0.0
var _spin: Node3D        # turned slowly (halo, circlet's stars)
var _stars: Array = []
var _orbit_r := 0.7

static var _flame_shader: Shader
static var _ghost_shader: Shader
static var _bone: StandardMaterial3D
static var _dark: StandardMaterial3D
static var _gold: StandardMaterial3D
static var _iron: StandardMaterial3D
static var _mats := {}
static var _baked := {}


static func make(what: String, id: String, y: float, hat: bool, style: Dictionary) -> FeatHeads:
	_materials()
	var h := FeatHeads.new()
	h.kind = what
	h.name = "FeatHead_" + what
	var eye: Color = style.get("eye", Color(0.6, 0.8, 1.0))
	var hat_h: float = style.get("hat_h", 0.45)
	var key := "%s %s %s %s" % [what, id, hat, eye.to_html()]
	match what:
		"storm_halo": h._storm_halo(y + (hat_h if hat else 0.22))
		"star_circlet": h._star_circlet(id, y, hat)
		"flame_crown": h._flame_horns(id, y, hat)
		"skull_helm": h._skull_helm(eye)
		"antlers": h._antlers(id, y, hat)
		"phantom_horns": h._phantom_horns(id, y, hat)
		"bone_crown": h._bone_mask(id, y, hat)
	bake(h, key)
	if h._spin:
		bake(h._spin, key + " spin")
	for i in h._stars.size():
		bake(h._stars[i], key + " star")
	return h


## Merges `root`'s own MeshInstance3D children into one mesh, one surface per material, and
## caches it under `key` (the next head of that kind and hero reuses it).
static func bake(root: Node3D, key: String) -> void:
	var parts: Array[MeshInstance3D] = []
	for c in root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			parts.append(c)
	if parts.size() <= 1:
		return
	var am: ArrayMesh = _baked.get(key)
	if am == null:
		var tools := {}
		var order := []
		for mi in parts:
			var mat := mi.material_override
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[mat] = st
				order.append(mat)
			(tools[mat] as SurfaceTool).append_from(mi.mesh, 0, mi.transform)
		am = ArrayMesh.new()
		for mat in order:
			(tools[mat] as SurfaceTool).commit(am)
			am.surface_set_material(am.get_surface_count() - 1, mat)
		_baked[key] = am
	for mi in parts:
		root.remove_child(mi)
		mi.free()
	var one := MeshInstance3D.new()
	one.name = "Baked"
	one.mesh = am
	one.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(one)


static func _materials() -> void:
	if _bone:
		return
	_bone = StandardMaterial3D.new()
	_bone.albedo_color = Color(0.93, 0.9, 0.8)
	_bone.roughness = 0.55
	_bone.rim_enabled = true
	_bone.rim = 0.4
	_dark = StandardMaterial3D.new()
	_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dark.albedo_color = Color(0.04, 0.03, 0.05)
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.8, 0.34)
	_gold.metallic = 0.7
	_gold.roughness = 0.25
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.72, 0.25)
	_gold.emission_energy_multiplier = 0.35
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.14, 0.11, 0.11)
	_iron.metallic = 0.6
	_iron.roughness = 0.35
	_iron.emission_enabled = true
	_iron.emission = Color(1.0, 0.45, 0.1)
	_iron.emission_energy_multiplier = 0.3
	_iron.rim_enabled = true
	_iron.rim = 0.5
	_flame_shader = Shader.new()
	_flame_shader.code = FLAME
	_ghost_shader = Shader.new()
	_ghost_shader.code = GHOST


## Where a crown sits: [height of its base, radius], over the hero's own hat or helmet when
## `hat` (round the Mage's hat, just above the brim), as hero_style.gd _crown.
static func _fit(id: String, y: float, hat: bool) -> Vector2:
	if hat:
		match id:
			"knight": return Vector2(y + 0.02, 0.56)
			"barbarian": return Vector2(y + 0.06, 0.56)
			"mage": return Vector2(y + 0.16, 0.4)
	return Vector2(y - 0.08, 0.5)


func _mi(m: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


## Shared by colour, so a head's pieces bake into few surfaces.
func _glow_mat(c: Color) -> StandardMaterial3D:
	var k := "glow " + str(c)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		_mats[k] = m
	return _mats[k]


func _add_mat(c: Color) -> StandardMaterial3D:
	var k := "add " + str(c)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[k] = m
	return _mats[k]


func _flame_mat(hot: Color, core: Color) -> ShaderMaterial:
	var k := "flame %s %s" % [hot, core]
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _flame_shader
		m.set_shader_parameter("hot", hot)
		m.set_shader_parameter("core", core)
		_mats[k] = m
	return _mats[k]


func _torus(inner: float, outer: float, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 28
	t.ring_segments = 8
	return _mi(t, mat, pos, parent)


## A tapered rod from `a` to `b` (a cone when r2 is 0).
func _rod(a: Vector3, b: Vector3, r1: float, r2: float, mat: Material, parent: Node3D = null, seg := 8) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r1
	c.top_radius = r2
	c.height = a.distance_to(b)
	c.radial_segments = seg
	c.rings = 1
	var mi := _mi(c, mat, (a + b) * 0.5, parent)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	mi.basis = Basis(side, up, side.cross(up)).orthonormalized()
	return mi


func _sphere(r: float, mat: Material, pos: Vector3, scale_by := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	var mi := _mi(s, mat, pos, parent)
	mi.scale = scale_by
	return mi


## A flame: a cone that sways and flickers (FLAME). Baked heads keep it alive: the shader
## reads how far up the flame a point is from the mesh's UV, not from the flame's centre.
func _flame(base: Vector3, h: float, r: float, hot: Color, core: Color) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 4
	_mi(c, _flame_mat(hot, core), base + Vector3(0, h * 0.5, 0))


# ---------------------------------------------------------------- Storm Halo

## A clean ring of storm light with three bolts standing off it (version 115's twenty-eight
## jittering rods read as a scribble from the game camera).
func _storm_halo(top: float) -> void:
	_spin = Node3D.new()
	_spin.position = Vector3(0, top, 0)
	add_child(_spin)
	var core := _glow_mat(Color(0.8, 0.93, 1.0) * 2.0)
	var ring := _torus(0.42, 0.53, core, Vector3.ZERO, _spin)
	ring.scale = Vector3(1, 0.6, 1)
	var dark := _torus(0.52, 0.58, _glow_mat(Color(0.1, 0.2, 0.52)), Vector3(0, -0.012, 0), _spin)
	dark.scale = Vector3(1, 0.45, 1)
	var halo := _torus(0.38, 0.6, _add_mat(Color(0.35, 0.6, 1.0, 0.3)), Vector3.ZERO, _spin)
	halo.scale = Vector3(1, 0.1, 1)
	# Three zigzag bolts, a third of the way round from each other, rising and leaning out.
	var bolt := _glow_mat(Color(0.9, 0.97, 1.0) * 2.4)
	var glow := _add_mat(Color(0.45, 0.7, 1.0, 0.35))
	for i in 3:
		var ang := TAU * i / 3.0
		var out := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		var pts := [out * 0.48, out * 0.52 + Vector3.UP * 0.12 + side * 0.06, out * 0.5 + Vector3.UP * 0.2 - side * 0.05,
			out * 0.56 + Vector3.UP * 0.34 + side * 0.03]
		for k in pts.size() - 1:
			_rod(pts[k], pts[k + 1], 0.032, 0.026, bolt, _spin, 5)
			_rod(pts[k], pts[k + 1], 0.07, 0.06, glow, _spin, 5)
		_sphere(0.045, bolt, pts[3], Vector3.ONE, _spin)


# ---------------------------------------------------------------- Star Circlet

func _star_circlet(id: String, y: float, hat: bool) -> void:
	var f := _fit(id, y, hat)
	var band_y := f.x + 0.06
	var band_r := f.y * 1.02
	# The stars circle above the head, not round the face (one passing in front of it
	# flared over the eyes in version 115).
	_orbit_r = 0.62
	var orbit_y := y + 0.22
	if hat and id == "mage":
		_orbit_r = 0.75
		orbit_y = y + 0.62
	elif not hat:
		band_y = y - 0.3
		band_r = 0.56
		orbit_y = y + 0.12
	# A thin gold band (version 116: no glowing gem at the front, which flared over the face).
	var band := _torus(band_r - 0.025, band_r + 0.03, _gold, Vector3(0, band_y, 0))
	band.scale = Vector3(1, 0.7, 1)
	# Three stars orbiting, each with a soft glow.
	_spin = Node3D.new()
	_spin.position = Vector3(0, orbit_y, 0)
	add_child(_spin)
	var star := _glow_mat(Color(1.0, 0.95, 0.75) * 1.8)
	var glow := _add_mat(Color(1.0, 0.85, 0.45, 0.4))
	for i in 3:
		var st := Node3D.new()
		var ang := TAU * i / 3.0
		st.position = Vector3(sin(ang), 0.08 * sin(ang * 2.0), cos(ang)) * _orbit_r
		_spin.add_child(st)
		for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var long := 0.23 if absf(d.y) > 0.5 else 0.16
			_rod(d * 0.02, d * long, 0.065, 0.0, star, st, 4)
		_sphere(0.06, star, Vector3.ZERO, Vector3.ONE, st)
		_sphere(0.11, glow, Vector3.ZERO, Vector3.ONE, st)
		_stars.append(st)


# ---------------------------------------------------------------- Flame Horns

## Two black-iron horns with glowing seams, curling up and back, each burning at its tip
## (version 116: was the Flame Crown; crowns now belong to the Crypt Pass and Mastery).
func _flame_horns(id: String, y: float, hat: bool) -> void:
	var k := 1.0
	if hat and id != "rogue":
		y += 0.12
	if hat and id == "mage":
		k = 1.5   # clear of the wide brim from above
		y += 0.14
	var hot := Color(1.0, 0.55, 0.12)
	var core := Color(1.0, 0.95, 0.6)
	var seam := _glow_mat(Color(1.0, 0.5, 0.12) * 1.5)
	for sd in [-1.0, 1.0]:
		var pts := [Vector3(sd * 0.3, y - 0.2, 0.04), Vector3(sd * 0.52, y + 0.02, -0.02), Vector3(sd * 0.66, y + 0.3, -0.12),
			Vector3(sd * 0.66, y + 0.56, -0.26), Vector3(sd * 0.56, y + 0.76, -0.34)]
		for i in pts.size():
			pts[i] = Vector3(pts[i].x * k, y + (pts[i].y - y) * k, pts[i].z * k)
		for i in pts.size() - 1:
			_rod(pts[i], pts[i + 1], (0.12 - i * 0.025) * k, (0.095 - i * 0.024) * k, _iron, null, 10)
			# a glowing ring at each joint
			var t := _torus((0.1 - i * 0.024) * k, (0.125 - i * 0.024) * k, seam, pts[i + 1])
			var up: Vector3 = (pts[i + 1] - pts[i]).normalized()
			var side := up.cross(Vector3.FORWARD).normalized()
			t.basis = Basis(side, up, side.cross(up)).orthonormalized()
		_flame(pts[4] - Vector3(0, 0.04, 0), 0.42 * k, 0.11 * k, hot, core)
		_flame(pts[4] + Vector3(sd * 0.05, -0.02, 0.04) * k, 0.26 * k, 0.07 * k, hot, core)


# ---------------------------------------------------------------- Skull Helm

## The hero's head is hidden (hero_style.gd "hide_head"): the skull is their head now, with
## their glow colour burning in its eyes.
func _skull_helm(eye: Color) -> void:
	_sphere(0.6, _bone, Vector3(0, 0.24, -0.06), Vector3(0.98, 0.92, 1.06))   # the cranium
	_sphere(0.4, _bone, Vector3(0, -0.12, 0.1), Vector3(0.9, 0.62, 0.95))     # the jaw
	for s in [-1.0, 1.0]:
		_sphere(0.15, _bone, Vector3(s * 0.33, 0.02, 0.36))                     # cheekbones
		_sphere(0.17, _dark, Vector3(s * 0.21, 0.2, 0.47), Vector3(1.0, 0.85, 0.6))   # eye sockets
		_sphere(0.065, _glow_mat(eye.lightened(0.3) * 1.7), Vector3(s * 0.21, 0.19, 0.53))
		_sphere(0.12, _add_mat(Color(eye, 0.45)), Vector3(s * 0.21, 0.19, 0.55))
	# The nose: a dark upside-down heart.
	for s in [-1.0, 1.0]:
		_sphere(0.05, _dark, Vector3(s * 0.035, 0.03, 0.57), Vector3(0.8, 1.3, 0.6))
	# Teeth: a dark line with bone teeth over it.
	var gap := BoxMesh.new()
	gap.size = Vector3(0.36, 0.035, 0.05)
	_mi(gap, _dark, Vector3(0, -0.11, 0.47))
	for i in 6:
		var t := BoxMesh.new()
		t.size = Vector3(0.05, 0.09, 0.05)
		_mi(t, _bone, Vector3(-0.15 + i * 0.06, -0.09, 0.485))
	# A crest of three bone spikes, and a crack over one eye.
	for i in 3:
		var z := -0.3 + i * 0.22
		_rod(Vector3(0, 0.74 - absf(z + 0.08) * 0.25, z), Vector3(0, 0.98 - i * 0.05, z - 0.12), 0.07, 0.0, _bone)
	var crack := BoxMesh.new()
	crack.size = Vector3(0.025, 0.2, 0.02)
	var cm := _mi(crack, _dark, Vector3(0.12, 0.45, 0.5))
	cm.rotation = Vector3(-0.5, 0, 0.35)


# ---------------------------------------------------------------- Antlers

static var _horn_mat: StandardMaterial3D   # one for every build (it was a new one each time)

func _antlers(id: String, y: float, hat: bool) -> void:
	# Over a helmet or hat they sit higher and wider (version 115 had them inside the
	# Knight's helmet and the Mage's hat).
	var k := 1.0
	if hat:
		match id:
			"knight": 
				y += 0.12
				k = 1.12
			"barbarian":
				y += 0.1
				k = 1.1
			"mage":
				y += 0.2
				k = 1.45
			"rogue":
				y += 0.08
				k = 1.12
	elif id == "rogue":
		# The Rogue's own hood: wide enough that the beams cleared it only from the front.
		y += 0.06
		k = 1.1
	if _horn_mat == null:
		_horn_mat = StandardMaterial3D.new()
		_horn_mat.albedo_color = Color(0.82, 0.72, 0.56)
		_horn_mat.roughness = 0.6
		_horn_mat.rim_enabled = true
		_horn_mat.rim = 0.3
	var horn: StandardMaterial3D = _horn_mat
	var tip := _glow_mat(Color(0.55, 1.0, 0.85) * 1.6)
	var tip_glow := _add_mat(Color(0.4, 1.0, 0.8, 0.4))
	var kk := Vector3(k, 1, k)
	for sd in [-1.0, 1.0]:
		# The main beam curves out, up and back; tines reach up and forward from it.
		var pts := [Vector3(sd * 0.26, y - 0.08, -0.04), Vector3(sd * 0.46, y + 0.18, -0.1),
			Vector3(sd * 0.62, y + 0.5, -0.2), Vector3(sd * 0.7, y + 0.82, -0.34), Vector3(sd * 0.66, y + 1.06, -0.5)]
		for i in pts.size():
			pts[i] = pts[i] * kk
		for i in pts.size() - 1:
			_rod(pts[i], pts[i + 1], 0.075 - i * 0.012, 0.065 - i * 0.012, horn)
			_sphere(0.068 - i * 0.012, horn, pts[i + 1])
		var tines := [[1, Vector3(sd * 0.62, y + 0.5, 0.18) * kk], [2, Vector3(sd * 0.95, y + 0.78, -0.12) * kk], [3, Vector3(sd * 0.84, y + 1.08, -0.18) * kk]]
		for t: Array in tines:
			var from: Vector3 = pts[t[0]]
			_rod(from, t[1], 0.05, 0.02, horn)
			_sphere(0.04, tip, t[1])
			_sphere(0.09, tip_glow, t[1])
		_sphere(0.04, tip, pts[4])
		_sphere(0.09, tip_glow, pts[4])


# ---------------------------------------------------------------- Phantom Horns

func _phantom_horns(id: String, y: float, hat: bool) -> void:
	var k := 1.0
	if hat and id != "rogue":
		y += 0.12
	if hat and id == "mage":
		k = 1.6   # clear of the wide brim from above
		y += 0.12
	var m: ShaderMaterial = _mats.get("ghost")
	if m == null:
		m = ShaderMaterial.new()
		m.shader = _ghost_shader
		_mats["ghost"] = m
	for sd in [-1.0, 1.0]:
		# Big ram-like horns sweeping out, back and curling up at the ends.
		var pts := [Vector3(sd * 0.34, y - 0.22, 0.02), Vector3(sd * 0.62, y - 0.02, -0.12), Vector3(sd * 0.86, y + 0.2, -0.32),
			Vector3(sd * 0.98, y + 0.48, -0.5), Vector3(sd * 0.92, y + 0.74, -0.6)]
		for i in pts.size() - 1:
			var a: Vector3 = pts[i] * Vector3(k, 1, k)
			var b: Vector3 = pts[i + 1] * Vector3(k, 1, k)
			a.y = y + (pts[i].y - y) * k
			b.y = y + (pts[i + 1].y - y) * k
			_rod(a, b, (0.13 - i * 0.028) * k, (0.105 - i * 0.026) * k, m, null, 10)


# ---------------------------------------------------------------- Bone Mask

## A bone war-mask over the brow and eyes, two short horns rising from it, green soul light
## in the eye holes (version 116: was the Bone Crown).
func _bone_mask(id: String, y: float, hat: bool) -> void:
	var soul := Color(0.35, 1.0, 0.55)
	var fwd := 0.5
	var hy := y - 0.42   # eye height
	if hat:
		match id:
			"knight": fwd = 0.6
			"barbarian": fwd = 0.56
			"mage": fwd = 0.52
	# The plate: a shallow shell over the upper face (a flattened ball, its front just
	# proud of the face).
	var plate := SphereMesh.new()
	plate.radius = 0.45
	plate.height = 0.9
	plate.radial_segments = 20
	plate.rings = 10
	_mi(plate, _bone, Vector3(0, hy + 0.05, fwd - 0.1)).scale = Vector3(1.0, 0.6, 0.3)
	# Brow ridge, cheek guards and the eye holes with soul light.
	_rod(Vector3(-0.42, hy + 0.2, fwd - 0.05), Vector3(0.42, hy + 0.2, fwd - 0.05), 0.075, 0.075, _bone, null, 8)
	for sd in [-1.0, 1.0]:
		_sphere(0.1, _bone, Vector3(sd * 0.36, hy - 0.08, fwd - 0.12), Vector3(1.0, 1.2, 0.6))
		_sphere(0.1, _dark, Vector3(sd * 0.17, hy + 0.06, fwd + 0.02), Vector3(1.2, 0.8, 0.5))
		_sphere(0.045, _glow_mat(soul * 1.6), Vector3(sd * 0.17, hy + 0.06, fwd + 0.07))
		_sphere(0.09, _add_mat(Color(soul, 0.45)), Vector3(sd * 0.17, hy + 0.06, fwd + 0.08))
		# A short curved horn from each side of the brow, up and back: from the camera above
		# these are what reads first.
		var hp := [Vector3(sd * 0.36, hy + 0.22, fwd - 0.12), Vector3(sd * 0.46, hy + 0.48, fwd - 0.2),
			Vector3(sd * 0.44, hy + 0.72, fwd - 0.36), Vector3(sd * 0.36, hy + 0.86, fwd - 0.52)]
		if hat:
			for i in hp.size():
				hp[i].y += 0.12 if id != "mage" else 0.3
				hp[i].x *= 1.15 if id != "mage" else 1.5
		for i in hp.size() - 1:
			_rod(hp[i], hp[i + 1], 0.085 - i * 0.022, 0.065 - i * 0.022, _bone, null, 8)
		_flame(hp[3] + Vector3(0, -0.02, 0), 0.22, 0.06, soul, Color(0.85, 1.0, 0.85))
	# A dark nose slit down the middle.
	_sphere(0.035, _dark, Vector3(0, hy - 0.06, fwd + 0.03), Vector3(0.8, 1.6, 0.5))


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"storm_halo":
			_spin.rotation.y += delta * 0.8
			_spin.position.y += sin(_t * 2.0) * 0.0006
		"star_circlet":
			_spin.rotation.y += delta * 1.1
			for st: Node3D in _stars:
				st.rotate_y(delta * 2.5)
				st.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 4.0 + st.position.x * 3.0))
		_:
			set_process(false)


const FLAME := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 hot : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.95, 0.6, 1.0);
varying float up;
varying float seed;
void vertex() {
	// How far up its flame a point is (a cone's UV runs from its tip to its base), and a seed
	// from where the flame stands on the head, so baked flames still move apart.
	up = clamp(1.0 - UV.y, 0.0, 1.0);
	seed = floor(VERTEX.x * 6.0) * 1.7 + floor(VERTEX.z * 6.0) * 2.3;
	float sway = up * up;
	VERTEX.x += sin(TIME * 8.0 + seed * 7.0 + up * 4.0) * 0.05 * sway;
	VERTEX.z += cos(TIME * 6.5 + seed * 5.0 + up * 3.0) * 0.05 * sway;
}
void fragment() {
	float fl = 0.75 + 0.25 * sin(TIME * 13.0 + seed * 11.0);
	vec3 c = mix(core.rgb, hot.rgb, smoothstep(0.1, 0.7, up));
	ALBEDO = c * (1.0 - up * 0.65) * fl * 1.6;
}
"""

const GHOST := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	// Ghost light: bright at the edges and pulsing, violet shading to cyan.
	float edge = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float p = 0.75 + 0.25 * sin(TIME * 3.0);
	vec3 c = mix(vec3(0.55, 0.35, 1.0), vec3(0.4, 1.0, 0.95), 0.5 + 0.5 * sin(TIME * 1.3 + UV.y * 4.0));
	ALBEDO = c * (0.35 + edge * 1.4) * p;
}
"""
