class_name FoeBodies
extends RefCounted
## Version 343 (visual review fix 7): the parts that give a skeleton kind its own outline,
## seen from the run camera high above: a brute's spiked shoulder plates, an archer's quiver
## of arrows, a mage's hanging robe in place of legs with two orbs circling it, a spitter's
## crest of bone spikes. Each kind's build (bones scaled, see BodyShape) is in its own
## script's _setup, as look.shape; these are look.parts.

static var _mats := {}


static func _m(key: String) -> Material:
	if not _mats.has(key):
		match key:
			"iron_light": _mats[key] = U.mat(Color(0.55, 0.56, 0.62), 0.35)
			"rust": _mats[key] = U.mat(Color(0.55, 0.2, 0.12), 0.7)
			"bone": _mats[key] = U.mat(Color(0.92, 0.88, 0.78), 0.75)
			"leather": _mats[key] = U.mat(Color(0.42, 0.26, 0.14), 0.85)
			"fletch": _mats[key] = U.mat(Color(1.0, 0.82, 0.2), 0.6, 0.6)
			"robe": _mats[key] = U.mat(Color(0.3, 0.16, 0.44), 0.85)
			"robe_hem": _mats[key] = U.mat(Color(0.55, 0.3, 0.85), 0.6, 0.5)
			"orb": _mats[key] = U.unlit(Color(0.85, 0.6, 1.0))
			"orb_glow":
				var g := U.unlit(Color(0.7, 0.35, 1.0, 0.5), U.soft_circle(), true).duplicate()
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_mats[key] = g
	return _mats[key]


static func _on(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	if skel.find_bone(bone) < 0:
		return null
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = bone
	return att


## Puts the parts named `kind` on `model` (a KayKit character).
static func dress(model: Node3D, kind: String) -> void:
	var skel := Art._find_skeleton(model)
	if skel == null:
		return
	match kind:
		"brute": _brute(skel)
		"quiver": _quiver(skel)
		"robe": _robe(model, skel)
		"crest": _crest(skel)


## The Skeleton Warrior: a big round iron plate on each shoulder, wider than its head, with
## two bone spikes standing up from each (they sit on the chest, so they show from above).
static func _brute(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	for side in [-1.0, 1.0]:
		var plate := U.sphere(a, 0.27, _m("iron_light"), Vector3(side * 0.4, 0.2, 0.0))
		plate.scale = Vector3(1.1, 0.7, 1.0)
		var rim := U.sphere(a, 0.29, _m("rust"), Vector3(side * 0.4, 0.15, 0.0))
		rim.scale = Vector3(1.1, 0.35, 1.0)
		for k in 2:
			var s := U.cone(a, 0.1, 0.55, _m("bone"), Vector3.ZERO)
			s.position = Vector3(side * (0.42 + 0.06 * k), 0.3, -0.1 + 0.2 * k)
			s.rotation = Vector3(0.25 - 0.5 * k, 0, -side * 0.45)
	FeatHeads.bake(a, "foe brute")   # one mesh: a room of warriors stays cheap to draw


## The Skeleton Archer: a leather quiver slung across the back, its arrows' yellow feathers
## standing up by the right shoulder, where they show from above.
static func _quiver(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	var q := Node3D.new()
	a.add_child(q)
	q.position = Vector3(0.18, 0.12, -0.3)
	q.rotation = Vector3(-0.2, 0, -0.75)
	U.cylinder(q, 0.15, 0.8, _m("leather"), Vector3(0, -0.4, 0))
	U.cylinder(q, 0.165, 0.08, _m("rust"), Vector3(0, 0.34, 0))
	for i in 4:
		var x := -0.08 + 0.055 * i
		var z := 0.04 * ((i % 2) * 2 - 1)
		U.box(q, Vector3(0.04, 0.4, 0.04), _m("bone"), Vector3(x, 0.55, z))
		var f := U.box(q, Vector3(0.15, 0.22, 0.03), _m("fletch"), Vector3(x, 0.74 + 0.04 * (i % 2), z))
		f.rotation.y = 0.8 * i
	FeatHeads.bake(q, "foe quiver")


## The Skeleton Mage: no legs, a long ragged robe hanging from the hips, hovering, and two
## violet orbs circling it, out past its hat's brim.
static func _robe(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"])
	var a := _on(skel, "hips")
	if a == null:
		return
	var r := U.cone(a, 0.5, 0.62, _m("robe"), Vector3(0, -0.6, 0), 0.3)
	r.name = "Robe"
	var hem := U.cone(a, 0.54, 0.08, _m("robe_hem"), Vector3(0, -0.64, 0), 0.51)
	hem.name = "Hem"
	for i in 7:   # ragged tails at the hem
		var ang := TAU * i / 7.0
		var t := U.cone(a, 0.12, 0.3, _m("robe"), Vector3.ZERO)
		t.position = Vector3(cos(ang) * 0.42, -0.7, sin(ang) * 0.42)
		t.rotation = Vector3(PI, 0, 0)
	FeatHeads.bake(a, "foe robe")
	var orbit := Orbit.new()
	a.add_child(orbit)
	for i in 2:
		var o := U.sphere(orbit, 0.15, _m("orb"), Vector3(cos(PI * i) * 1.0, 0, sin(PI * i) * 1.0))
		o.name = "Orb%d" % i
		var halo := U.sphere(o, 0.26, _m("orb_glow"))
		halo.name = "Halo"
		halo.set_meta("fx", true)   # (a glow: the hit flash leaves it alone)


## The Bone Spitter: a crest of bone spikes along the top of its huge skull, like a lizard's.
static func _crest(skel: Skeleton3D) -> void:
	var a := _on(skel, "head")
	if a == null:
		return
	for i in 5:
		var f := (i - 2) / 2.0
		var s := U.cone(a, 0.13, 0.58 - absf(f) * 0.16, _m("bone"), Vector3.ZERO)
		s.position = Vector3(0.0, 0.92 - f * f * 0.14, f * 0.3)
		s.rotation = Vector3(-0.35 + f * 0.25, 0, 0)
	FeatHeads.bake(a, "foe crest")


## Two orbs going round and round (the mage).
class Orbit extends Node3D:
	var _t := randf() * TAU

	func _process(delta: float) -> void:
		_t += delta * 2.4
		rotation.y = _t
		position.y = 0.75 + sin(_t * 1.3) * 0.1
