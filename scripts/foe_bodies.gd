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
			"linen": _mats[key] = U.mat(Color(0.88, 0.84, 0.72), 0.95)
			"amethyst": _mats[key] = U.mat(Color(0.72, 0.42, 1.0), 0.25, 0.8)
			"amethyst_pale": _mats[key] = U.mat(Color(0.9, 0.75, 1.0), 0.2, 0.6)
			"brass": _mats[key] = U.mat(Color(1.0, 0.72, 0.3), 0.3, 0.25)
			"steel": _mats[key] = U.mat(Color(0.4, 0.4, 0.45), 0.35)
			"void": _mats[key] = U.mat(Color(0.12, 0.14, 0.35), 0.5, 0.6)
			"void_rim": _mats[key] = U.mat(Color(0.55, 0.65, 1.0), 0.3, 1.2)
			"book_a": _mats[key] = U.mat(Color(0.55, 0.12, 0.12), 0.8)
			"book_b": _mats[key] = U.mat(Color(0.12, 0.3, 0.35), 0.8)
			"book_c": _mats[key] = U.mat(Color(0.35, 0.22, 0.45), 0.8)
			"pages": _mats[key] = U.mat(Color(0.95, 0.9, 0.75), 0.9)
			"weed": _mats[key] = U.mat(Color(0.2, 0.5, 0.3), 0.7, 0.25)
			"weed_dark": _mats[key] = U.mat(Color(0.12, 0.32, 0.22), 0.8)
			"barnacle": _mats[key] = U.mat(Color(0.75, 0.75, 0.68), 0.9)
			"rock": _mats[key] = U.mat(Color(0.3, 0.27, 0.32), 0.9)
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
		"linen": _linen(skel)
		"geode": _geode(skel)
		"cogs": _cogs(skel)
		"voidtail": _voidtail(model, skel)
		"books": _books(skel)
		"seaweed": _seaweed(skel)


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


## The Tomb Mummy: long ends of linen hanging from its wrists as it reaches for you.
static func _linen(skel: Skeleton3D) -> void:
	for side in ["l", "r"]:
		var a := _on(skel, "lowerarm." + side)
		if a == null:
			continue
		for k in 2:
			var s := U.box(a, Vector3(0.1, 0.55 - 0.15 * k, 0.025), _m("linen"), Vector3.ZERO)
			s.position = Vector3(0.05 - 0.1 * k, 0.2, 0.06 * k)
			s.rotation = Vector3(PI * 0.5 + 0.2 * k, 0.3 * k, 0)
		FeatHeads.bake(a, "foe linen")


## The Geode Guard: amethyst crystals grown out of its back and shoulders, on rock.
static func _geode(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	var rock := U.sphere(a, 0.3, _m("rock"), Vector3(0, 0.25, -0.22))
	rock.scale = Vector3(1.5, 0.8, 0.9)
	var spots := [Vector3(-0.38, 0.38, -0.12), Vector3(0.4, 0.42, -0.1), Vector3(-0.15, 0.42, -0.35), Vector3(0.18, 0.5, -0.32), Vector3(0.0, 0.32, -0.42), Vector3(0.45, 0.28, -0.3)]
	var tilt := [Vector3(-0.3, 0, 0.6), Vector3(-0.2, 0, -0.7), Vector3(-0.7, 0, 0.2), Vector3(-0.6, 0, -0.3), Vector3(-1.0, 0, 0), Vector3(-0.5, 0, -0.9)]
	for i in spots.size():
		var h := 0.62 if i < 2 else 0.5
		var c := U.cone(a, 0.15, h, _m("amethyst" if i % 2 == 0 else "amethyst_pale"), Vector3.ZERO)
		c.position = spots[i]
		c.rotation = tilt[i]
	FeatHeads.bake(a, "foe geode")
	for c in a.get_children():
		c.set_meta("fx", true)   # (its dusty overlay would dull the crystals)


## The Clockwork Skeleton: a big brass cog turning on each shoulder, past its head on
## either side, so its outline is a machine's from above too.
static func _cogs(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	for side in [-1.0, 1.0]:
		var spin := Spin.new()
		spin.speed = 1.6 * side
		spin.position = Vector3(side * 0.5, 0.22, 0.0)
		spin.rotation.z = PI * 0.5
		a.add_child(spin)
		U.cylinder(spin, 0.3, 0.08, _m("brass"), Vector3(0, -0.04, 0))
		U.cylinder(spin, 0.1, 0.16, _m("steel"), Vector3(0, -0.08, 0))
		for k in 8:
			var ang := TAU * k / 8.0
			var tooth := U.box(spin, Vector3(0.12, 0.08, 0.12), _m("brass"), Vector3(cos(ang) * 0.34, -0.04, sin(ang) * 0.34))
			tooth.rotation.y = -ang
		FeatHeads.bake(spin, "foe cog")


## The Void Walker: no legs, a long tail of the starry void trailing to a point under it.
static func _voidtail(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Warrior_LegLeft", "Skeleton_Warrior_LegRight"])
	var a := _on(skel, "hips")
	if a == null:
		return
	var top := U.cone(a, 0.1, 0.75, _m("void"), Vector3(0, -0.72, 0), 0.38)
	top.name = "Tail"
	var tip := U.cone(a, 0.1, 0.4, _m("void"), Vector3.ZERO)
	tip.position = Vector3(0, -0.72, 0.02)
	tip.rotation = Vector3(PI - 0.6, 0, 0)
	var band := U.cylinder(a, 0.37, 0.05, _m("void_rim"), Vector3(0, -0.02, 0))
	band.name = "Band"
	for i in 3:   # wisps
		var ang := TAU * i / 3.0 + 0.4
		var w := U.cone(a, 0.08, 0.35, _m("void_rim"), Vector3.ZERO)
		w.position = Vector3(cos(ang) * 0.3, -0.42, sin(ang) * 0.3)
		w.rotation = Vector3(PI - 0.5 * sin(ang), 0, 0.5 * cos(ang))
	FeatHeads.bake(a, "foe voidtail")


## The Hush Keeper: a tall stack of old books strapped to its bent back, above its head.
static func _books(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	var y := 0.1
	var sizes := [Vector3(0.72, 0.22, 0.5), Vector3(0.64, 0.2, 0.46), Vector3(0.7, 0.24, 0.5), Vector3(0.58, 0.18, 0.44), Vector3(0.66, 0.22, 0.48), Vector3(0.5, 0.16, 0.4)]
	var mats := ["book_a", "book_b", "book_c", "book_b", "book_a", "book_c"]
	for i in sizes.size():
		var s: Vector3 = sizes[i]
		var x := 0.05 * ((i % 2) * 2 - 1)
		var b := U.box(a, s, _m(mats[i]), Vector3(x, y + s.y * 0.5, -0.5))
		b.rotation.y = 0.18 * ((i % 3) - 1)
		var p := U.box(a, Vector3(s.x - 0.08, s.y - 0.05, 0.04), _m("pages"), Vector3(x, y + s.y * 0.5, -0.5 + s.z * 0.5))
		p.rotation.y = b.rotation.y
		y += s.y
	var strap := U.box(a, Vector3(0.08, y, 0.56), _m("leather"), Vector3(0, y * 0.5 + 0.05, -0.47))
	strap.name = "Strap"
	FeatHeads.bake(a, "foe books")
	for c in a.get_children():
		c.set_meta("fx", true)   # (its see-through script overlay would hide the covers)


## The Drowned Skeleton: weed hanging from its skull and shoulders, barnacles on its bones.
static func _seaweed(skel: Skeleton3D) -> void:
	var h := _on(skel, "head")
	if h:
		for i in 5:
			var ang := -1.2 + 0.6 * i
			var s := U.box(h, Vector3(0.09, 0.6 - 0.08 * (i % 2), 0.02), _m("weed" if i % 2 == 0 else "weed_dark"), Vector3.ZERO)
			s.position = Vector3(sin(ang) * 0.42, 0.55, cos(ang) * 0.3 - 0.1)
			s.rotation = Vector3(0.25, ang, 0.15 * sin(ang))
		for i in 3:
			U.sphere(h, 0.07, _m("barnacle"), Vector3(-0.25 + 0.22 * i, 0.9, 0.1 * (i - 1)))
		FeatHeads.bake(h, "foe weed head")
	var c := _on(skel, "chest")
	if c:
		for side in [-1.0, 1.0]:
			for k in 2:
				var s := U.box(c, Vector3(0.1, 0.55, 0.02), _m("weed" if k == 0 else "weed_dark"), Vector3.ZERO)
				s.position = Vector3(side * (0.3 + 0.08 * k), 0.05, 0.05 - 0.12 * k)
				s.rotation = Vector3(0.1, 0, side * 0.25)
		FeatHeads.bake(c, "foe weed chest")


## A part turning round and round (the clockwork's cogs).
class Spin extends Node3D:
	var speed := 1.0

	func _process(delta: float) -> void:
		rotate_object_local(Vector3.UP, speed * delta)


## Two orbs going round and round (the mage).
class Orbit extends Node3D:
	var _t := randf() * TAU

	func _process(delta: float) -> void:
		_t += delta * 2.4
		rotation.y = _t
		position.y = 0.75 + sin(_t * 1.3) * 0.1
