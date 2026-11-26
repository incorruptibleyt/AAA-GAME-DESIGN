class_name HeroTops
extends RefCounted
## Version 369 (visual review of 366, fix 3, "heroes you know from above"): the run camera
## looks down on the heroes from behind, and there the Barbarian was a brown fur cap and the
## Mage a dark hat disc: you knew the hero by colour, not by shape. Each hero's own look
## now has a top of its own shape:
##   Barbarian: an iron helm with two great horns over the bear hood, fur shoulder pads
##              with a bone spike;
##   Knight:    layered steel pauldrons edged with gold;
##   Rogue:     pointed blue leather shoulder guards;
##   Mage:      a gold band, a gold brim edge and gold stars on the hat (its brim hides
##              the shoulders).
## The shoulders are for the hero's own outfit (the other outfits bring their own shapes,
## OutfitShapes); the helm and the hat's gold stay under every outfit that has no hat
## shapes of its own. A Legend Vault grand set (own crown and mantle) takes it all off.

const STEEL := Color(0.62, 0.65, 0.74)
const IRON := Color(0.3, 0.31, 0.36)
const GOLD := Color(1.0, 0.78, 0.3)
const HORN := Color(0.9, 0.84, 0.68)
const HORN_TIP := Color(0.5, 0.4, 0.3)
const FUR := Color(0.8, 0.7, 0.52)


static func _clear(parent: Node) -> void:
	for n in parent.get_children():
		if str(n.name).begins_with("HeroTop"):
			parent.remove_child(n)
			n.queue_free()


static func _hat(skel: Skeleton3D, pattern: String) -> MeshInstance3D:
	for h in skel.find_children(pattern, "MeshInstance3D", true, false):
		return h
	return null


static func dress(skel: Skeleton3D, id: String, style: Dictionary) -> void:
	var chest := OutfitShapes._on(skel, "chest")
	if chest:
		_clear(chest)
	var bear := _hat(skel, "*Barbarian_Hat*")
	if bear:
		_clear(bear)
	var wizard := _hat(skel, "*Mage_Hat*")
	if wizard:
		_clear(wizard)
	var helmet := _hat(skel, "*Knight_Helmet*")
	if helmet:
		_clear(helmet)
	var legend: Dictionary = style.get("legend", {})
	if str(legend.get("grand", "")) != "":
		return
	var outfit: Dictionary = style.get("outfit", {})
	var own_hat := bool(style.get("hat", false)) and (style.get("borrow", []) as Array).is_empty()
	if id == "barbarian" and bear and bear.visible and own_hat:
		_helm(bear)
	if id == "mage" and wizard and wizard.visible and own_hat and not outfit.has("key"):
		_stars(wizard)
	if id == "knight" and helmet and helmet.visible and own_hat and not outfit.has("key"):
		_crest(helmet)
	if id == "rogue" and outfit.is_empty():
		_night_cape(skel)
	if chest and id == "rogue" and str(legend.get("wings", "")) == "":
		_quiver(chest)   # version 377: on every Rogue look, the shape that says "Rogue" from above
	if chest and outfit.is_empty() and str(legend.get("wings", "")) == "":
		match id:
			"knight": _pauldrons(chest)
			"barbarian": _fur_pads(chest)
			"rogue": _guards(chest)


## How far behind the chest bone the quiver hangs (the chest bone's -z is the back).
const QUIVER_BACK := -0.42
const QX := 15.0
const QZ := -20.0


static func _holder(parent: Node3D, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "HeroTop"
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	return root


## The Barbarian's horned helm, in the bear hood's own space (the hood is about 1.1 wide,
## its crown about 1.15 up from the neck).
static func _helm(hat: MeshInstance3D) -> void:
	var root := _holder(hat)
	var iron := U.mat(IRON, 0.45)
	var horn := U.mat(HORN, 0.6, 0.1)
	var tip := U.mat(HORN_TIP, 0.6)
	var green := U.mat(Heroes.get_hero("barbarian").ring.darkened(0.15), 0.5, 0.25)
	# An iron cap on the crown, with a ridge from brow to nape in the Barbarian's green.
	var cap := U.sphere(root, 0.5, iron, Vector3(0, 0.92, 0.04))
	cap.scale = Vector3(1.0, 0.62, 1.08)
	var band := U.cylinder(root, 0.53, 0.1, iron, Vector3(0, 0.84, 0.04))
	band.scale = Vector3(1.0, 1.0, 1.08)
	for k in 5:
		var a := -0.9 + 0.45 * k
		var r := U.box(root, Vector3(0.1, 0.07, 0.24), green, Vector3(0, 0.92 + cos(a) * 0.31, 0.04 + sin(a) * 0.55))
		r.rotation.x = a
	for k in 6:   # rivets round the band
		var a := TAU * (k + 0.5) / 6.0
		U.sphere(root, 0.05, U.mat(STEEL, 0.3), Vector3(cos(a) * 0.54, 0.89, 0.04 + sin(a) * 0.58))
	# Two great horns out of the sides, sweeping out, up and a little forward.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.46, 0.9, 0.02)
		OutfitShapes._ray(root, 0.2, 0.1, iron, at, Vector3(side, 0.2, 0), 0.2)
		var d1 := Vector3(side, 0.3, -0.05).normalized()
		OutfitShapes._ray(root, 0.17, 0.3, horn, at, d1, 0.14)
		var p2 := at + d1 * 0.28
		var d2 := Vector3(side * 0.7, 0.75, -0.15).normalized()
		OutfitShapes._ray(root, 0.14, 0.3, horn, p2, d2, 0.1)
		var p3 := p2 + d2 * 0.28
		var d3 := Vector3(side * 0.2, 1.0, -0.25).normalized()
		OutfitShapes._ray(root, 0.1, 0.34, tip, p3, d3, 0.0)
	FeatHeads.bake(root, "herotop helm")
	OutfitShapes._keep(root)


## v390 (review v388 fix 2): the Knight's helm gets a tall red crest from brow to nape, so
## from above the Knight is a red stripe over steel, not a grey dome among grey skulls. In
## the helmet's own space (about 1.14 wide, crown at about 1.25 up, front toward +z).
static func _crest(hat: MeshInstance3D) -> void:
	var root := _holder(hat)
	root.name = "HeroTopCrest"
	var red := U.mat(Color(0.72, 0.08, 0.13), 0.75)
	var deep := U.mat(Color(0.6, 0.06, 0.11), 0.8)
	var gold := U.mat(GOLD, 0.35, 0.3)
	var c := Vector3(0, 0.6, -0.04)
	var r := 0.64
	var n := 13
	# (fix 2 critic: it ran down the back like a red danger line; it stops at the nape now
	# and stands lower, a comb over the helm, not a rod)
	for k in n:
		var t := float(k) / (n - 1)
		var a := lerpf(-0.5, 1.15, t)
		var out := Vector3(0, cos(a), -sin(a))
		var tall := 0.3 - 0.12 * absf(t - 0.4)
		var fin := U.box(root, Vector3(0.26, tall, 0.2), red if k % 2 == 0 else deep, c + out * (r + tall * 0.4))
		fin.rotation.x = -a
	# the gold socket the crest stands in
	for k in 5:
		var a := lerpf(-0.45, 1.1, k / 4.0)
		var s := U.box(root, Vector3(0.3, 0.07, 0.26), gold, c + Vector3(0, cos(a), -sin(a)) * (r + 0.02))
		s.rotation.x = -a
	FeatHeads.bake(root, "herotop crest")
	OutfitShapes._keep(root)


## A cone from `from` along `dir`, pressed flat (to `flat` of its width) along `normal`.
static func _blade(root: Node3D, r: float, length: float, mat: Material, from: Vector3, dir: Vector3, normal: Vector3, flat: float) -> MeshInstance3D:
	var c := U.cone(root, r, length, mat)
	var y := dir.normalized()
	var x := y.cross(normal).normalized()
	var z := x.cross(y).normalized()
	c.transform = Transform3D(Basis(x, y, z * flat), from + y * length * 0.5)
	return c


## A flat five-point star lying on the brim (for the Mage's hat), turned by `turn`.
static func _star(root: Node3D, at: Vector3, size: float, mat: Material, turn: float) -> void:
	var hub := U.sphere(root, size * 0.36, mat, at)
	hub.scale = Vector3(1.0, 0.4, 1.0)
	for k in 5:
		var a := turn + TAU * k / 5.0
		_blade(root, size * 0.3, size, mat, at, Vector3(sin(a), 0.0, cos(a)), Vector3.UP, 0.35)


## The Mage's hat in gold: a band round the cone, a rim on the brim and stars on it (in the
## hat's own space: the brim is about 1.05 round, the tip about 1 up).
static func _stars(hat: MeshInstance3D) -> void:
	var root := _holder(hat)
	var gold := U.mat(GOLD, 0.35, 0.45)
	var band := TorusMesh.new()
	band.inner_radius = 0.52
	band.outer_radius = 0.66
	band.rings = 24
	band.ring_segments = 8
	var b := MeshInstance3D.new()
	b.mesh = band
	b.material_override = gold
	b.position = Vector3(0, 0.13, 0)
	b.scale = Vector3(1.0, 0.8, 1.0)
	root.add_child(b)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.98
	rim.outer_radius = 1.08
	rim.rings = 32
	rim.ring_segments = 6
	var r := MeshInstance3D.new()
	r.mesh = rim
	r.material_override = gold
	r.position = Vector3(0, 0.02, 0)
	r.scale = Vector3(1.0, 0.7, 1.0)
	root.add_child(r)
	# One big star on the back of the brim (what the run camera sees), smaller ones round it.
	for k in 5:
		var a := TAU * k / 5.0
		var big := k == 0
		_star(root, Vector3(sin(a) * 0.83, 0.07, cos(a) * 0.83), 0.36 if big else 0.2, gold, a)
	U.sphere(root, 0.1, gold, Vector3(0, 0.98, -0.2))
	FeatHeads.bake(root, "herotop stars")
	OutfitShapes._keep(root)


## The Knight: two layered steel plates on each shoulder, edged and ridged with his gold.
static func _pauldrons(chest: Node3D) -> void:
	var root := _holder(chest, 1.45)
	var steel := U.mat(STEEL, 0.35)
	var gold := U.mat(Heroes.get_hero("knight").ring, 0.35, 0.3)
	for side in [-1.0, 1.0]:
		var top := U.sphere(root, 0.25, steel, Vector3(side * 0.44, 0.15, 0.0))
		top.scale = Vector3(1.05, 0.55, 1.1)
		var edge := U.cylinder(root, 0.265, 0.045, gold, Vector3(side * 0.44, 0.1, 0.0))
		edge.scale = Vector3(1.05, 1.0, 1.1)
		edge.rotation.z = -side * 0.15
		var low := U.sphere(root, 0.2, steel, Vector3(side * 0.6, 0.06, 0.0))
		low.scale = Vector3(1.0, 0.5, 1.1)
		var edge2 := U.cylinder(root, 0.215, 0.04, gold, Vector3(side * 0.6, 0.02, 0.0))
		edge2.scale = Vector3(1.0, 1.0, 1.1)
		edge2.rotation.z = -side * 0.3
		# a gold ridge over the top plate, front to back, and a stud at its middle
		for k in 3:
			var a := -0.7 + 0.7 * k
			var r := U.box(root, Vector3(0.05, 0.035, 0.17), gold, Vector3(side * 0.44, 0.15 + cos(a) * 0.135, sin(a) * 0.26))
			r.rotation.x = a
		U.sphere(root, 0.06, gold, Vector3(side * 0.44, 0.3, 0.0))
	FeatHeads.bake(root, "herotop pauldrons")
	OutfitShapes._keep(root)


## The Barbarian: a ruff of pale fur on each shoulder under a riveted green iron plate, and
## a bone spike.
static func _fur_pads(chest: Node3D) -> void:
	var root := _holder(chest, 1.45)
	var fur := U.mat(FUR, 1.0)
	var green := U.mat(Heroes.get_hero("barbarian").ring.darkened(0.25), 0.5, 0.2)
	var iron := U.mat(IRON, 0.45)
	var rivet := U.mat(STEEL, 0.3)
	var horn := U.mat(HORN, 0.6, 0.1)
	for side in [-1.0, 1.0]:
		for k in 5:   # tufts round the pad
			var a := TAU * k / 5.0
			var tuft := U.sphere(root, 0.15, fur, Vector3(side * 0.47 + cos(a) * 0.17, 0.08, sin(a) * 0.19))
			tuft.scale = Vector3(1.0, 0.75, 1.0)
		U.cylinder(root, 0.215, 0.06, iron, Vector3(side * 0.47, 0.14, 0.0))
		var plate := U.sphere(root, 0.19, green, Vector3(side * 0.47, 0.2, 0.0))
		plate.scale = Vector3(1.0, 0.45, 1.0)
		for k in 4:
			var a := TAU * (k + 0.5) / 4.0
			U.sphere(root, 0.035, rivet, Vector3(side * 0.47 + cos(a) * 0.15, 0.24, sin(a) * 0.15))
		OutfitShapes._ray(root, 0.085, 0.36, horn, Vector3(side * 0.49, 0.24, 0.0), Vector3(side * 0.7, 0.7, 0.0))
	FeatHeads.bake(root, "herotop furpads")
	OutfitShapes._keep(root)


## The Rogue: layered leather guards that end in a point: dark under, pale steel-blue over
## (her hood is blue already: the same blue again was one blue lump), with a silver stud.
## Version 377: the classic Rogue's cape in deep navy, so the bright hood stands apart from
## it (both were the same blue: one egg from above). Outfits colour the cape themselves.
static var _cape_mat: StandardMaterial3D

static func _night_cape(skel: Skeleton3D) -> void:
	for c in skel.find_children("*_Cape", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.material_override != null and mi.material_override != _cape_mat:
			continue
		var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if src == null:
			continue
		if _cape_mat == null:
			_cape_mat = src.duplicate() as StandardMaterial3D
			_cape_mat.albedo_color = src.albedo_color * Color(0.42, 0.42, 0.55)
		mi.material_override = _cape_mat


## Version 377 (visual review of 375, fix 2): from above, the Rogue was one blue hood over
## a blue cape, a plain blue egg. A leather quiver now crosses his back, bolts with bright
## orange flights sticking up past his shoulder: a dark shape across the blue and a spot
## of warm colour that only the Rogue has, seen from behind as he runs up the screen.
static func _quiver(chest: Node3D) -> void:
	var root := _holder(chest, 1.45)
	root.name = "HeroTopQuiver"
	var leather := U.mat(Color(0.3, 0.17, 0.09), 0.75)
	var dark := U.mat(Color(0.13, 0.08, 0.05), 0.8)
	var gold := U.mat(Color(0.95, 0.72, 0.3), 0.35)
	var shaft := U.mat(Color(0.55, 0.42, 0.28), 0.7)
	var flight := U.mat(Color(1.0, 0.5, 0.12), 0.6, 0.35)
	var tube := root   # every piece straight under the holder, so they bake into one mesh
	tube.position = Vector3(0.22, 0.3, QUIVER_BACK)
	tube.rotation = Vector3(deg_to_rad(QX), 0.0, deg_to_rad(QZ))
	U.cylinder(tube, 0.16, 0.78, leather, Vector3(0, -0.4, 0))
	U.cylinder(tube, 0.175, 0.07, gold, Vector3(0, 0.3, 0))
	U.cylinder(tube, 0.175, 0.07, dark, Vector3(0, -0.36, 0))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var at := Vector3(cos(a) * 0.075, 0.38, sin(a) * 0.075)
		U.cylinder(tube, 0.022, 0.32 + 0.05 * (k % 2), shaft, at)
		var tip := at + Vector3(0, 0.3 + 0.05 * (k % 2), 0)
		for side in [-1.0, 1.0]:
			_blade(tube, 0.09, 0.28, flight, tip - Vector3(0, 0.24, 0), Vector3(side * 0.4, 1.0, 0.0), Vector3(0, 0, 1), 0.3)
	FeatHeads.bake(root, "herotop quiver")
	OutfitShapes._keep(root)
	# the strap across the chest
	var band := _holder(chest, 1.0)
	band.name = "HeroTopQuiverStrap"
	var strap := U.box(band, Vector3(0.08, 0.95, 0.05), dark, Vector3(0.0, 0.08, 0.0))
	strap.rotation.z = deg_to_rad(-34.0)
	OutfitShapes._keep(band)


static func _guards(chest: Node3D) -> void:
	var root := _holder(chest, 1.45)
	var pale := U.mat(Heroes.get_hero("rogue").ring.lightened(0.45), 0.45, 0.2)
	var navy := U.mat(Color(0.08, 0.14, 0.32), 0.7)
	var steel := U.mat(Color(0.85, 0.88, 0.95), 0.3)
	for side in [-1.0, 1.0]:
		var under := U.sphere(root, 0.23, navy, Vector3(side * 0.45, 0.1, 0.0))
		under.scale = Vector3(1.2, 0.5, 1.1)
		_blade(root, 0.17, 0.3, navy, Vector3(side * 0.56, 0.1, 0.0), Vector3(side, 0.05, 0.0), Vector3.UP, 0.4)
		var over := U.sphere(root, 0.17, pale, Vector3(side * 0.44, 0.18, 0.0))
		over.scale = Vector3(1.15, 0.5, 1.0)
		_blade(root, 0.11, 0.24, pale, Vector3(side * 0.54, 0.18, 0.0), Vector3(side, 0.1, 0.0), Vector3.UP, 0.4)
		U.sphere(root, 0.05, steel, Vector3(side * 0.42, 0.27, 0.0))
	FeatHeads.bake(root, "herotop guards")
	OutfitShapes._keep(root)
