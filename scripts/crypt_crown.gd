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
static var _velvet: StandardMaterial3D
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
				r = 0.44
				lift = 0.6   # over the point of the wizard's hat
	c._base_y = y + lift
	c.position = Vector3(0, c._base_y, 0)
	c._build(r)
	c._own(id, r)
	c.scale = Vector3.ONE * 1.05   # (v198 made it 1.18: then the crown was all you saw of the hero)
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
	# Version 189: the cap is royal purple velvet. Gold (v116) made the set one gold blob from
	# the camera above and obsidian (v181) looked like a hole in the hero's head.
	_velvet = StandardMaterial3D.new()
	# Version 198: the cap is a pool of teal soul light. From the run camera the purple was a
	# dull dot under a white flame; now the crown is a gold ring full of teal fire.
	_velvet.albedo_color = Color(0.04, 0.5, 0.42)
	_velvet.roughness = 0.6
	_velvet.emission_enabled = true
	_velvet.emission = Color(0.05, 0.85, 0.66)
	_velvet.emission_energy_multiplier = 0.55
	_gem = StandardMaterial3D.new()
	_gem.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gem.albedo_color = Color(0.25, 1.0, 0.8) * 1.15
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
	# (Version 181: the cap is obsidian. From the game camera above, a gold cap under gold
	# arches made the whole set read as one gold blob; now it is a black dome crossed by gold.)
	var cm := _mesh(cap, _velvet, Vector3(0, 0.1, 0))
	cm.scale = Vector3(1, 0.5, 1)
	var top := SphereMesh.new()
	top.radius = 0.09
	top.height = 0.18
	top.radial_segments = 10
	top.rings = 5
	_mesh(top, _gem, Vector3(0, 0.1 + r * 0.5 + 0.04, 0))
	# Version 177: an emperor's crown. Four beaded gold arches rise from the rim and meet
	# over the middle, holding up a great soul gem in a glow of its own. No free crown, horn
	# or helm in the game has this shape, on the pedestal or from the camera above.
	var apex := 0.22 + 0.5
	for q in 4:
		var qa := q / 4.0 * TAU + TAU / 12.0
		var qd := Vector3(sin(qa), 0, cos(qa))
		for j in 7:
			var u := (j + 0.5) / 7.0 * PI * 0.5
			var bead := SphereMesh.new()
			bead.radius = 0.05 - 0.012 * (j / 6.0)
			bead.height = bead.radius * 2.0
			bead.radial_segments = 6
			bead.rings = 3
			_mesh(bead, _gold, qd * (r * 1.1 * cos(u)) + Vector3(0, 0.22 + (apex - 0.22) * sin(u), 0))
	var great := SphereMesh.new()
	great.radius = 0.13
	great.height = 0.3
	great.radial_segments = 10
	great.rings = 5
	var late: Array[MeshInstance3D] = [_mesh(great, _gem, Vector3(0, apex + 0.1, 0))]   # kept out of the bake (see below)
	var aura := SphereMesh.new()
	aura.radius = 0.24
	aura.height = 0.48
	aura.radial_segments = 10
	aura.rings = 5
	var soul := U.unlit(Color(0.2, 1.0, 0.8, 0.2)).duplicate() as StandardMaterial3D
	soul.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	late.append(_mesh(aura, soul, Vector3(0, apex + 0.1, 0)))
	for mi in late:
		remove_child(mi)
	# Version 187: a tall soul flame burns over the great gem. From the camera above, the
	# free Crown is a gold ring with gems; this is a gold ring with a teal fire in it, so the
	# paid crown is told apart at a glance in a run.
	# A soft gold glow round its base, like a halo it stands on.
	var ring := TorusMesh.new()
	ring.inner_radius = r * 0.95
	ring.outer_radius = r * 1.45
	ring.rings = 24
	ring.ring_segments = 4
	var rm := _mesh(ring, _glow, Vector3(0, -0.02, 0))
	rm.scale = Vector3(1, 0.1, 1)
	# (Version 200: from the side this glow was a brim, and the crown a peaked cap. Gone.)
	remove_child(rm)
	rm.free()
	FeatHeads.bake(self, "crypt_crown6 %.2f" % r)
	# (Version 189: the great gem, its soul light and the flames are kept out of the bake and marked "fx", so the hero's rim
	# light and gold aura are not drawn over them. On a thin cone the rim covered all of it
	# and the teal flame went white in the full set.)
	var fl := CylinderMesh.new()
	fl.top_radius = 0.0
	fl.bottom_radius = 0.17
	fl.height = 0.38
	fl.radial_segments = 8
	fl.rings = 4
	fl.cap_bottom = false   # (an extra see-through disc from the camera above)
	var f1 := _mesh(fl, FeatHeads._flame_mat(Color(0.1, 0.95, 0.72), Color(0.45, 1.0, 0.85)), Vector3(0, apex + 0.16 + 0.19, 0))
	var fl2 := CylinderMesh.new()
	fl2.top_radius = 0.0
	fl2.bottom_radius = 0.2
	fl2.height = 0.26
	fl2.radial_segments = 8
	fl2.rings = 4
	fl2.cap_bottom = false
	var f2 := _mesh(fl2, FeatHeads._flame_mat(Color(0.04, 0.6, 0.55), Color(0.15, 0.95, 0.75)), Vector3(0, apex + 0.1 + 0.13, 0))
	late.append(f1)
	late.append(f2)
	for mi in late:
		if mi.get_parent() == null:
			add_child(mi)
		mi.set_meta("fx", true)


## Version 397 (visual review of 388, fix 7): the crown was the same on all four heroes.
## Each hero's crown now has a part only theirs has, which stays facing the way the hero
## faces while the crown turns: the Knight's two gold wings, the Barbarian's two great
## obsidian horns, the Rogue's fan of blades standing behind it, and the Mage's two gold
## rings turning round it with soul gems on them.
var _still: Node3D
var _rings: Node3D

func _own(id: String, r: float) -> void:
	_still = Node3D.new()
	_still.name = "Own"
	add_child(_still)
	match id:
		"knight":
			for side in [-1.0, 1.0]:
				for k in 4:   # feathers, the longest highest and furthest back
					var from := Vector3(side * r * 1.1, 0.1 + 0.03 * k, -0.06 * k)
					var dir := Vector3(side * (1.0 - 0.14 * k), 0.75 + 0.3 * k, -0.35 - 0.12 * k)
					var f := OutfitShapes._ray(_still, 0.1, 0.5 + 0.13 * k, _gold, from, dir)
					f.scale = Vector3(1.0, 1.0, 0.4)
				U.sphere(_still, 0.1, _gem, Vector3(side * r * 1.14, 0.12, 0.0))
		"barbarian":
			for side in [-1.0, 1.0]:
				var p0 := Vector3(side * r * 0.95, 0.1, 0.0)
				var d0 := Vector3(side, 0.25, 0.0).normalized()
				var p1 := p0 + d0 * 0.36
				var d1 := Vector3(side * 0.55, 0.85, 0.1).normalized()
				var p2 := p1 + d1 * 0.36
				var d2 := Vector3(-side * 0.15, 1.0, 0.12).normalized()
				OutfitShapes._ray(_still, 0.17, 0.4, _dark, p0, d0, 0.14)
				OutfitShapes._ray(_still, 0.14, 0.4, _dark, p1, d1, 0.09)
				OutfitShapes._ray(_still, 0.09, 0.42, _gold, p2, d2)
				U.sphere(_still, 0.15, _gold, p1).scale = Vector3(1.0, 0.6, 1.0)
				U.sphere(_still, 0.17, _gold, p0 + d0 * 0.04).scale = Vector3(0.6, 1.0, 1.0)
		"rogue":
			for k in 5:   # a fan of blades behind the crown
				var x := (k - 2) * 0.25
				var tall := 0.95 - 0.1 * absf(k - 2.0)
				var from := Vector3(x, 0.14, -r * 0.9)
				var dir := Vector3(x * 1.5, 1.0, -0.3)
				var blade := OutfitShapes._ray(_still, 0.09, tall, _dark, from, dir)
				blade.scale = Vector3(1.0, 1.0, 0.3)
				var edge := OutfitShapes._ray(_still, 0.04, tall * 1.04, _gold, from + Vector3(0, 0, -0.03), dir)
				edge.scale = Vector3(1.0, 1.0, 0.3)
			var drop := OutfitShapes._ray(_still, 0.07, 0.2, _gem, Vector3(0, 0.02, r * 1.12), Vector3.DOWN)   # a gem hanging over the brow
			drop.scale = Vector3(1.0, 1.0, 0.6)
		"mage":
			_rings = Node3D.new()
			add_child(_rings)
			for k in 2:
				var hoop := TorusMesh.new()
				hoop.inner_radius = r * 1.62
				hoop.outer_radius = r * 1.74
				hoop.rings = 28
				hoop.ring_segments = 5
				var h := _mesh(hoop, _gold, Vector3(0, 0.3, 0))
				remove_child(h)
				_rings.add_child(h)
				h.rotation = Vector3(0.5 if k == 0 else -0.5, 0, 0.35 if k == 0 else -0.3)
				for g in 2:
					var ga := PI * g + k * 1.4
					var gem := U.sphere(_rings, 0.085, _gem, Vector3.ZERO)
					gem.position = h.transform * Vector3(cos(ga) * r * 1.68, 0, sin(ga) * r * 1.68)
					gem.set_meta("fx", true)
	if _still.get_child_count() > 0:
		FeatHeads.bake(_still, "crypt_crown own %s %.2f" % [id, r])
	for n in _still.get_children():
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	if _still:
		_still.rotation.y = -rotation.y   # (each hero's own part keeps facing the hero's way)
	if _rings:
		_rings.rotation.y = _t * 0.9
	position.y = _base_y + sin(_t * 2.2) * BOB
