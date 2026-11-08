class_name CryptCrown
extends Node3D
## The Crypt Crown (the Crypt King set, hero_style.gd): a tall crown of polished gold and
## obsidian that floats just over the hero's head and turns slowly, bobbing. Six points, the
## tall ones tipped with glowing soul gems (sea green: never red-pink, which means danger),
## and a soft gold glow ring under it. It's the only look that moves on its own.

const SPIN := 0.7   # radians a second
const BOB := 0.04   # metres

var _t := 0.0
var _base_y := 0.0

static var _gold: StandardMaterial3D
static var _dark: StandardMaterial3D
static var _gem: StandardMaterial3D
static var _glow: StandardMaterial3D


## The crown for hero `id`, whose head top is at `y` (in the head bone's space), over the
## hero's hat or helmet when `hat`.
static func make(id: String, y: float, hat: bool) -> CryptCrown:
	_materials()
	var c := CryptCrown.new()
	c.name = "CryptCrown"
	var r := 0.38
	var lift := 0.06
	if hat:
		match id:
			"knight":
				r = 0.5
				lift = 0.12
			"barbarian":
				r = 0.5
				lift = 0.14
			"mage":
				r = 0.36
				lift = 0.58   # over the point of the wizard's hat
	c._base_y = y + lift
	c.position = Vector3(0, c._base_y, 0)
	c._build(r)
	return c


static func _materials() -> void:
	if _gold:
		return
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color(1.0, 0.8, 0.32)
	_gold.metallic = 0.75
	_gold.roughness = 0.22
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.7, 0.22)
	_gold.emission_energy_multiplier = 0.45
	_gold.rim_enabled = true
	_gold.rim = 0.8
	_gold.rim_tint = 0.6
	_dark = StandardMaterial3D.new()
	_dark.cull_mode = BaseMaterial3D.CULL_DISABLED   # the open band is seen from inside too
	_dark.albedo_color = Color(0.08, 0.06, 0.12)
	_dark.metallic = 0.4
	_dark.roughness = 0.25
	_gem = StandardMaterial3D.new()
	_gem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gem.albedo_color = Color(0.45, 1.0, 0.85) * 1.5
	_glow = U.unlit(Color(1.0, 0.82, 0.35, 0.55)).duplicate()
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


func _build(r: float) -> void:
	# The band: obsidian inside, a flared gold rim top and bottom.
	var band := CylinderMesh.new()
	band.top_radius = r * 1.12
	band.bottom_radius = r
	band.height = 0.22
	band.radial_segments = 24
	band.cap_top = false   # open, like a real crown: from above the hero's head shows through
	band.cap_bottom = false
	_mesh(band, _dark, Vector3(0, 0.11, 0))
	for yy in [0.0, 0.22]:
		var lip := TorusMesh.new()
		lip.inner_radius = (r if yy == 0.0 else r * 1.12) - 0.03
		lip.outer_radius = (r if yy == 0.0 else r * 1.12) + 0.04
		lip.rings = 24
		lip.ring_segments = 6
		_mesh(lip, _gold, Vector3(0, yy, 0))
	# Six points, tall and short in turn; gems on the tall ones and round the band.
	for i in 6:
		var a := i / 6.0 * TAU
		var dir := Vector3(sin(a), 0, cos(a))
		var tall := i % 2 == 0
		var h := 0.42 if tall else 0.26
		var point := CylinderMesh.new()
		point.top_radius = 0.0
		point.bottom_radius = 0.11 if tall else 0.09
		point.height = h
		point.radial_segments = 6
		var pm := _mesh(point, _gold, Vector3(0, 0.22 + h * 0.5, 0) + dir * r * 1.12)
		pm.rotation = Vector3(0.18 * dir.z, 0, -0.18 * dir.x)   # leaning out
		if tall:
			var tip := Vector3(0, 0.22 + h + 0.02, 0) + dir * r * 1.2
			var gem := SphereMesh.new()
			gem.radius = 0.075
			gem.height = 0.17
			gem.radial_segments = 8
			gem.rings = 4
			_mesh(gem, _gem, tip)
		var b := a + TAU / 12.0
		var stud := SphereMesh.new()
		stud.radius = 0.05
		stud.height = 0.1
		stud.radial_segments = 8
		stud.rings = 4
		_mesh(stud, _gem if tall else _gold, Vector3(0, 0.11, 0) + Vector3(sin(b), 0, cos(b)) * r * 1.07)
	# Version 116: a gold cap fills the band's hollow middle (from the game camera above, the
	# open crown read as a ring with a hole), with a soul gem at its top.
	var cap := SphereMesh.new()
	cap.radius = r * 1.02
	cap.height = r * 2.04
	cap.radial_segments = 20
	cap.rings = 8
	cap.is_hemisphere = true
	var cm := _mesh(cap, _gold, Vector3(0, 0.1, 0))
	cm.scale = Vector3(1, 0.5, 1)
	var top := SphereMesh.new()
	top.radius = 0.09
	top.height = 0.18
	top.radial_segments = 10
	top.rings = 5
	_mesh(top, _gem, Vector3(0, 0.1 + r * 0.5 + 0.04, 0))
	# A soft gold glow round its base, like a halo it stands on.
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.95
	ring.outer_radius = r * 1.45
	ring.rings = 24
	ring.ring_segments = 4
	var rm := _mesh(ring, _glow, Vector3(0, -0.02, 0))
	rm.scale = Vector3(1, 0.1, 1)
	FeatHeads.bake(self, "crypt_crown %.2f" % r)


func _mesh(m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	rotation.y = _t * SPIN
	position.y = _base_y + sin(_t * 2.2) * BOB
