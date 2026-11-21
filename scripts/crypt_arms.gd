class_name CryptArms
## The Crypt King's arms, the Crypt King set's weapon (hero_style.gd PASS_HOLD, finish "crypt").
## Version 253 (whole-game review fix 10): whole new weapons from the Bone King's crypt, in
## obsidian, bone and gold with teal soul fire, built in place of the hero's grand weapon
## (ForgedArms.dress hides that one and calls build). Versions 201-203 were the grand weapon
## itself in obsidian with gold crown points and soul gems glued on, plainer than the free
## Gilded and Voidsteel weapons, which had become whole new weapons in version 231.
## - Knight: the Kingsbane, a greatsword split down its middle by a channel of soul fire, its
##   tip a gold crown, a crowned skull for its guard between gold rib wings, a vertebra grip.
## - Barbarian: the Skull Crusher, a crowned skull for an axe head with soul fire in its eyes,
##   two jagged obsidian blades edged in soul fire.
## - Mage: the Spine, a staff of stacked vertebrae with soul fire running up its core, a bone
##   hand holding a soul flame, and the Crypt Crown floating over it, turning.
## - Rogue: a ribcage crossbow (three pairs of gold-tipped ribs for limbs, a skull at its nose,
##   a soul-fire bolt, a crown by the hand) and the Crown Fang, a curved obsidian fang rising
##   out of a gold crown.
## Built in the weapon mesh's own space like ForgedArms (its long axis is y), with its parts.

static var _mats := {}
const SOUL := Color(0.25, 1.0, 0.82)


## Builds whole weapon `shape` (one of ForgedArms.SHAPES' "king_" shapes) under `root`.
static func build(root: Node3D, shape: String) -> void:
	match shape:
		"king_blade":
			_blade(root)
		"king_axe":
			_axe(root)
		"king_staff":
			_staff(root)
		"king_bow":
			_bow(root)
		"king_knife":
			_fang(root)


# ---------------------------------------------------------------- Knight

## The Kingsbane (2H_Sword: grip -0.42 to 0.3, blade up +y).
static func _blade(root: Node3D) -> void:
	var gold := ForgedArms._mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	_spine(still, -0.42, 0.22, 0.062, 4)
	ForgedArms._cone(still, Vector3(0, -0.44, 0), Vector3.DOWN, 0.07, 0.18, gold)
	# the blade: two obsidian rails round a channel of soul fire, meeting at the tip
	for sd: float in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(0.07, 0.46), Vector2(0.23, 0.46), Vector2(0.28, 1.0),
			Vector2(0.24, 1.55), Vector2(0.0, 1.98), Vector2(0.0, 1.76), Vector2(0.07, 1.62)])
		for i in pts.size():
			pts[i].x *= sd
		ForgedArms._slab_part(still, "kingsbane rail %d" % int(sd), pts, 0.045, _mat("obsidian"))
		var edge := [Vector2(0.23, 0.46), Vector2(0.28, 1.0), Vector2(0.24, 1.55), Vector2(0.0, 1.98)]
		for i in edge.size() - 1:
			ForgedArms._rod(still, Vector3(edge[i].x * sd * 1.03, edge[i].y, 0), Vector3(edge[i + 1].x * sd * 1.03, edge[i + 1].y, 0), 0.028, 0.022, gold)
		# gold rib wings sweeping up from the guard
		for k in 2:
			var rib := MeshInstance3D.new()
			rib.mesh = ForgedArms._crescent("kingsbane rib %d" % k, Vector2(0.0, 0.3 + k * 0.04), 0.5 - k * 0.15, 2.3, 0.55,
				0.1 - k * 0.02, 0.6, false, sd < 0.0)
			rib.material_override = gold
			still.add_child(rib)
	# the crown at the tip: three gold points fanning out
	for d: Vector3 in [Vector3(-0.55, 1, 0), Vector3(0, 1, 0), Vector3(0.55, 1, 0)]:
		ForgedArms._cone(still, Vector3(0, 1.9, 0), d, 0.05, 0.3 if d.x == 0.0 else 0.22, gold)
	# the channel's fire: a little thicker than the blade, so it burns through on both faces
	ForgedArms._rod(still, Vector3(0, 0.48, 0), Vector3(0, 1.7, 0), 0.06, 0.05, _mat("soul"))
	FeatHeads.bake(still, "crypt kingsbane")
	_skull(root, Vector3(0, 0.36, 0), 0.15, true)
	_soul_fire(root, Vector3(0, 1.96, 0), 0.07, 0.3)
	for y: float in [0.75, 1.3]:
		ForgedArms._glow(root, Vector3(0, y, 0), 0.4, Color(SOUL, 0.3))


# ---------------------------------------------------------------- Barbarian

## The Skull Crusher (2H_Axe: haft from -0.45, head about y 1.0).
static func _axe(root: Node3D) -> void:
	var gold := ForgedArms._mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	ForgedArms._handle(still, -0.45, 0.86, _mat("obsidian"))
	for y: float in [-0.38, 0.2, 0.7]:
		var band := CylinderMesh.new()
		band.top_radius = 0.075
		band.bottom_radius = 0.075
		band.height = 0.07
		band.radial_segments = 10
		band.rings = 1
		ForgedArms._part(still, band, gold, Vector3(0, y, 0))
	ForgedArms._cone(still, Vector3(0, -0.47, 0), Vector3.DOWN, 0.075, 0.2, gold)
	# two jagged blades, their outer edges cut into teeth and lined with soul fire
	var outline := [Vector2(0.2, 0.84), Vector2(0.5, 0.62), Vector2(0.64, 0.8), Vector2(0.56, 0.9), Vector2(0.72, 1.0),
		Vector2(0.6, 1.1), Vector2(0.74, 1.22), Vector2(0.6, 1.33), Vector2(0.5, 1.5), Vector2(0.2, 1.26)]
	for sd: float in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for q: Vector2 in outline:
			pts.append(Vector2(q.x * sd, q.y))
		ForgedArms._slab_part(still, "skull crusher blade %d" % int(sd), pts, 0.045, _mat("obsidian"))
		for i in range(1, outline.size() - 2):
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[i + 1]
			ForgedArms._rod(still, Vector3(a.x * sd * 1.02, a.y, 0), Vector3(b.x * sd * 1.02, b.y, 0), 0.024, 0.024, _mat("soul"))
	FeatHeads.bake(still, "crypt skull_crusher")
	_skull(root, Vector3(0, 1.05, 0), 0.27, true)
	for x: float in [-0.1, 0.1]:
		_soul_fire(root, Vector3(x, 1.38, 0), 0.07, 0.3)
	ForgedArms._glow(root, Vector3(0, 1.05, 0), 0.7, Color(SOUL, 0.3))


# ---------------------------------------------------------------- Mage

## The Spine (2H_Staff: -0.9 to 1.25, its head at about 1.12).
static func _staff(root: Node3D) -> void:
	var gold := ForgedArms._mat("gold")
	var bone := _mat("bone")
	var still := Node3D.new()
	root.add_child(still)
	_spine(still, -0.78, 0.84, 0.068, 12)
	ForgedArms._cone(still, Vector3(0, -0.8, 0), Vector3.DOWN, 0.06, 0.22, gold)
	# a bone hand at the top, its four fingers and thumb curling round a soul flame
	var wrist := CylinderMesh.new()
	wrist.top_radius = 0.09
	wrist.bottom_radius = 0.06
	wrist.height = 0.1
	wrist.radial_segments = 10
	wrist.rings = 1
	ForgedArms._part(still, wrist, gold, Vector3(0, 0.9, 0))
	for i in 5:
		var a := i / 5.0 * TAU + 0.3
		var out := Vector3(sin(a), 0, cos(a))
		var f0 := Vector3(0, 0.95, 0) + out * 0.08
		var f1 := Vector3(0, 1.08, 0) + out * 0.18
		var f2 := Vector3(0, 1.25, 0) + out * 0.17
		var f3 := Vector3(0, 1.34, 0) + out * 0.08
		ForgedArms._rod(still, f0, f1, 0.032, 0.028, bone)
		ForgedArms._rod(still, f1, f2, 0.028, 0.024, bone)
		ForgedArms._cone(still, f2, f3 - f2, 0.024, f2.distance_to(f3), bone)
		for k: Vector3 in [f1, f2]:   # gold knuckles
			var kn := SphereMesh.new()
			kn.radius = 0.036
			kn.height = 0.072
			kn.radial_segments = 8
			kn.rings = 4
			ForgedArms._part(still, kn, gold, k)
	FeatHeads.bake(still, "crypt spine_staff")
	var orb := SphereMesh.new()
	orb.radius = 0.1
	orb.height = 0.2
	orb.radial_segments = 12
	orb.rings = 6
	ForgedArms._part(root, orb, _mat("soul"), Vector3(0, 1.16, 0))
	_soul_fire(root, Vector3(0, 1.12, 0), 0.09, 0.4)
	ForgedArms._glow(root, Vector3(0, 1.18, 0), 0.5, Color(SOUL, 0.45))
	# the Crypt Crown floating over the hand, turning
	var crown := ForgedArms.Spin.new()
	crown.speed = 0.8
	crown.position = Vector3(0, 1.62, 0)
	crown.rotation = Vector3(0.18, 0, -0.12)
	root.add_child(crown)
	_crown(crown, 0.22, 7)


# ---------------------------------------------------------------- Rogue
# 2H_Crossbow: the stock runs along +z (front at 1.16) and the Rogue holds it pointing at the
# floor, so shapes rise along +y. Knife_Offhand: blade up +y to 0.98.

## The ribcage crossbow.
static func _bow(root: Node3D) -> void:
	var gold := ForgedArms._mat("gold")
	var bone := _mat("bone")
	var still := Node3D.new()
	root.add_child(still)
	ForgedArms._stock(still, -0.26, 1.0, _mat("obsidian"), _mat("obsidian"))
	for z: float in [-0.2, 0.32]:
		ForgedArms._rod(still, Vector3(0, 0.06, z), Vector3(0, 0.06, z + 0.06), 0.09, 0.09, gold)
	# three pairs of ribs arching up and back, the front pair the widest (the limbs)
	for k in 3:
		var z := 0.86 - k * 0.2
		var span := 0.64 - k * 0.14
		for sd: float in [-1.0, 1.0]:
			var p0 := Vector3(sd * 0.05, 0.08, z)
			var p1 := Vector3(sd * span * 0.5, 0.3 - k * 0.04, z + 0.03)
			var p2 := Vector3(sd * span * 0.92, 0.24 - k * 0.04, z - 0.1)
			var p3 := Vector3(sd * span, 0.08, z - 0.24)
			ForgedArms._rod(still, p0, p1, 0.04 - k * 0.006, 0.034 - k * 0.006, bone)
			ForgedArms._rod(still, p1, p2, 0.034 - k * 0.006, 0.028 - k * 0.006, bone)
			ForgedArms._cone(still, p2, p3 - p2, 0.03 - k * 0.005, p2.distance_to(p3) + 0.04, gold)
	FeatHeads.bake(still, "crypt rib_bow")
	# the string, the soul-fire bolt and the skull at its nose
	for sd: float in [-1.0, 1.0]:
		ForgedArms._rod(root, Vector3(sd * 0.62, 0.1, 0.64), Vector3(0, 0.16, 0.34), 0.012, 0.012, _mat("soul"))
	ForgedArms._rod(root, Vector3(0, 0.17, 0.3), Vector3(0, 0.17, 1.12), 0.026, 0.026, _mat("soul"))
	ForgedArms._cone(root, Vector3(0, 0.17, 1.12), Vector3(0, 0, 1), 0.065, 0.2, _mat("soul"))
	_skull(root, Vector3(0, 0.1, 1.02), 0.11, false)
	ForgedArms._glow(root, Vector3(0, 0.25, 0.75), 0.6, Color(SOUL, 0.35))
	# the crown by the hand, where it is always seen (v203: points at the limb tips sank into
	# the floor, the way the Rogue holds it)
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.2, 0.16)
	root.add_child(crown)
	_crown(crown, 0.12, 5)


## The Crown Fang: a curved obsidian fang edged in soul fire, rising out of a gold crown.
static func _fang(root: Node3D) -> void:
	var gold := ForgedArms._mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	_spine(still, -0.24, 0.02, 0.045, 3)
	var fang := PackedVector2Array([Vector2(-0.07, 0.08), Vector2(0.08, 0.08), Vector2(0.15, 0.4), Vector2(0.13, 0.7),
		Vector2(0.03, 1.0), Vector2(0.01, 0.72), Vector2(-0.03, 0.42)])
	ForgedArms._slab_part(still, "crown fang", fang, 0.03, _mat("obsidian"))
	var edge := [Vector2(0.08, 0.1), Vector2(0.15, 0.4), Vector2(0.13, 0.7), Vector2(0.03, 1.0)]
	for i in edge.size() - 1:
		ForgedArms._rod(still, Vector3(edge[i].x + 0.012, edge[i].y, 0), Vector3(edge[i + 1].x + 0.012, edge[i + 1].y, 0), 0.018, 0.014, _mat("soul"))
	ForgedArms._cone(still, Vector3(0, -0.26, 0), Vector3.DOWN, 0.05, 0.12, gold)
	FeatHeads.bake(still, "crypt crown_fang")
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.06, 0)
	root.add_child(crown)
	_crown(crown, 0.12, 5)


# ---------------------------------------------------------------- parts

## A gold crown ring of radius `r` lying flat, `n` points standing on it (tall and short in
## turn) with a soul gem on each tall point.
static func _crown(root: Node3D, r: float, n: int) -> void:
	var gold := ForgedArms._mat("gold")
	var band := TorusMesh.new()
	band.inner_radius = r * 0.78
	band.outer_radius = r
	band.rings = 20
	band.ring_segments = 6
	ForgedArms._part(root, band, gold, Vector3.ZERO)
	for i in n:
		var a := i / float(n) * TAU
		var out := Vector3(sin(a), 0, cos(a))
		var tall := i % 2 == 0
		var h := r * (1.3 if tall else 0.9)
		ForgedArms._cone(root, out * r * 0.9, Vector3(0, 1, 0) + out * 0.18, r * 0.2, h, gold)
		if tall:
			var gem := SphereMesh.new()
			gem.radius = r * 0.13
			gem.height = r * 0.26
			gem.radial_segments = 8
			gem.rings = 4
			ForgedArms._part(root, gem, _mat("soul"), out * r * 1.02 + Vector3(0, h * 0.95, 0))
	ForgedArms._glow(root, Vector3(0, r * 0.4, 0), r * 1.5, Color(1.0, 0.75, 0.3, 0.18))


## A skull of radius `s` at `at`, looking along +z (and along -z too when `both`, so the
## pedestal and the run camera each see a face): bone, soul fire in its eyes, a gold crown.
static func _skull(root: Node3D, at: Vector3, s: float, both: bool) -> void:
	var bone := _mat("bone")
	var part := Node3D.new()
	part.position = at
	root.add_child(part)
	var head := SphereMesh.new()
	head.radius = s
	head.height = s * 1.9
	head.radial_segments = 14
	head.rings = 7
	ForgedArms._part(part, head, bone, Vector3.ZERO)
	var jaw := BoxMesh.new()
	jaw.size = Vector3(s * 1.2, s * 0.55, s * (1.5 if both else 1.2))
	ForgedArms._part(part, jaw, bone, Vector3(0, -s * 0.78, 0 if both else s * 0.15))
	for f: float in ([1.0, -1.0] if both else [1.0]):
		for sd: float in [-1.0, 1.0]:
			var hole := SphereMesh.new()
			hole.radius = s * 0.27
			hole.height = s * 0.5
			hole.radial_segments = 10
			hole.rings = 5
			ForgedArms._part(part, hole, _mat("eye"), Vector3(sd * s * 0.38, -s * 0.12, f * s * 0.74))
			var eye := SphereMesh.new()
			eye.radius = s * 0.13
			eye.height = s * 0.26
			eye.radial_segments = 8
			eye.rings = 4
			ForgedArms._part(part, eye, _mat("soul"), Vector3(sd * s * 0.38, -s * 0.12, f * s * 0.9))
		ForgedArms._cone(part, Vector3(0, -s * 0.36, f * s * 0.9), Vector3.DOWN, s * 0.12, s * 0.2, _mat("eye"))
		for t in 4:   # teeth
			var tooth := BoxMesh.new()
			tooth.size = Vector3(s * 0.16, s * 0.2, s * 0.08)
			ForgedArms._part(part, tooth, bone, Vector3((t - 1.5) * s * 0.22, -s * 0.62, f * (s * (0.76 if both else 0.76))))
	FeatHeads.bake(part, "crypt skull %s %s" % [s, both])
	var crown := Node3D.new()
	crown.position = at + Vector3(0, s * 0.55, 0)
	root.add_child(crown)
	_crown(crown, s * 0.82, 5)


## A grip or shaft of `n` bone vertebrae from `y0` to `y1` round a core of soul fire.
static func _spine(root: Node3D, y0: float, y1: float, r: float, n: int) -> void:
	var bone := _mat("bone")
	ForgedArms._rod(root, Vector3(0, y0, 0), Vector3(0, y1, 0), r * 0.45, r * 0.45, _mat("soul"))
	var step := (y1 - y0) / n
	for i in n:
		var y := y0 + step * (i + 0.5)
		var v := CylinderMesh.new()
		v.top_radius = r
		v.bottom_radius = r * 0.85
		v.height = step * 0.62
		v.radial_segments = 10
		v.rings = 1
		ForgedArms._part(root, v, bone, Vector3(0, y, 0))
		for sd: float in [-1.0, 1.0]:   # the vertebra's wings
			ForgedArms._cone(root, Vector3(sd * r * 0.8, y, 0), Vector3(sd, -0.25, 0), r * 0.32, r * 0.75, bone)
		ForgedArms._cone(root, Vector3(0, y, -r * 0.8), Vector3(0, -0.4, -1), r * 0.3, r * 0.7, bone)


## Soft teal soul fire (Fx.flame) standing on `at`, about `h` tall.
static func _soul_fire(root: Node3D, at: Vector3, r: float, h: float) -> void:
	Fx.flame(root, Vector2(r * 3.4, h * 1.4), at, true)


static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"obsidian":
			m.albedo_color = Color(0.1, 0.08, 0.13)
			m.metallic = 0.85
			m.roughness = 0.18
			m.emission_enabled = true   # (a teal sheen, so it doesn't vanish on a dark floor)
			m.emission = Color(0.05, 0.28, 0.24)
			m.emission_energy_multiplier = 0.4
		"bone":
			m.albedo_color = Color(0.93, 0.88, 0.76)
			m.roughness = 0.55
			m.emission_enabled = true
			m.emission = Color(0.5, 0.45, 0.35)
			m.emission_energy_multiplier = 0.15
		"soul":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = SOUL * 1.25
		"eye":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.02, 0.03, 0.04)
	_mats[kind] = m
	return m
