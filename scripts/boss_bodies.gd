class_name BossBodies
extends RefCounted
## Version 348 (visual review fix 8, "bosses with their own bodies"): the bosses were the
## same four chibi bodies as their skeletons, only bigger and with a hat. Each boss's build
## (bones scaled, see BodyShape) is in its own script's _setup as look.shape, and these are
## its look.parts: big shapes that change its outline from the run camera high above.

static var _mats := {}


static func _m(key: String) -> Material:
	if not _mats.has(key):
		match key:
			"gold": _mats[key] = U.mat(Color(1.0, 0.76, 0.25), 0.25, 0.2)
			"velvet": _mats[key] = U.mat(Color(0.62, 0.06, 0.1), 0.8)
			"velvet_dark": _mats[key] = U.mat(Color(0.38, 0.03, 0.07), 0.85)
			"ermine": _mats[key] = U.mat(Color(0.96, 0.95, 0.92), 0.9)
			"ermine_spot": _mats[key] = U.mat(Color(0.08, 0.08, 0.1), 0.9)
			"lich_robe": _mats[key] = U.mat(Color(0.1, 0.12, 0.22), 0.85)
			"lich_hem": _mats[key] = U.mat(Color(0.3, 0.95, 1.0), 0.4, 0.9)
			"soul": _mats[key] = U.unlit(Color(0.55, 1.0, 1.0))
			"soul_glow":
				var g := U.unlit(Color(0.3, 0.9, 1.0, 0.5), U.soft_circle(), true).duplicate()
				g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_mats[key] = g
			"basalt": _mats[key] = U.mat(Color(0.16, 0.12, 0.11), 0.9)
			"lava": _mats[key] = U.unlit(Color(1.0, 0.5, 0.1))
			"lava_hot": _mats[key] = U.unlit(Color(1.0, 0.85, 0.35))
			"spore_cap": _mats[key] = U.mat(Color(1.0, 0.45, 0.75), 0.5, 0.9)
			"spore_gill": _mats[key] = U.mat(Color(0.95, 0.82, 0.86), 0.8, 0.2)
			"moss": _mats[key] = U.mat(Color(0.32, 0.48, 0.22), 0.9, 0.1)
			"water": _mats[key] = U.mat(Color(0.15, 0.6, 0.7), 0.15, 0.35)
			"foam": _mats[key] = U.mat(Color(0.85, 1.0, 1.0), 0.6, 0.5)
			"shell": _mats[key] = U.mat(Color(0.95, 0.75, 0.62), 0.5, 0.1)
			"shell_in": _mats[key] = U.mat(Color(0.95, 0.45, 0.5), 0.5, 0.15)
			"gown": _mats[key] = U.mat(Color(0.45, 0.02, 0.06), 0.7, 0.15)
			"gown_gold": _mats[key] = U.mat(Color(1.0, 0.7, 0.25), 0.3, 0.4)
			"wing": _mats[key] = U.mat(Color(0.22, 0.02, 0.05), 0.75, 0.1)
			"wing_rim": _mats[key] = U.unlit(Color(1.0, 0.2, 0.15))
			"kilt": _mats[key] = U.mat(Color(0.95, 0.92, 0.82), 0.85)
			"lapis": _mats[key] = U.mat(Color(0.12, 0.25, 0.75), 0.35, 0.25)
			"turq": _mats[key] = U.mat(Color(0.2, 0.8, 0.75), 0.35, 0.3)
			"fur": _mats[key] = U.mat(Color(0.25, 0.17, 0.12), 0.95)
			"fur_frost": _mats[key] = U.mat(Color(0.75, 0.85, 0.95), 0.9, 0.1)
			"hoof": _mats[key] = U.mat(Color(0.12, 0.1, 0.1), 0.5)
			"ink": _mats[key] = U.mat(Color(0.1, 0.14, 0.3), 0.8)
			"ink_rim": _mats[key] = U.mat(Color(0.3, 0.95, 0.85), 0.5, 0.6)
			"cover_a": _mats[key] = U.mat(Color(0.5, 0.12, 0.1), 0.8)
			"cover_b": _mats[key] = U.mat(Color(0.1, 0.3, 0.32), 0.8)
			"page_glow": _mats[key] = U.mat(Color(0.95, 0.95, 0.85), 0.8, 0.45)
			"iron": _mats[key] = U.mat(Color(0.26, 0.25, 0.27), 0.45)
			"smoke": _mats[key] = U.mat(Color(0.42, 0.4, 0.42), 1.0)
			"iron_dark": _mats[key] = U.mat(Color(0.12, 0.11, 0.12), 0.5)
			"ring": _mats[key] = U.mat(Color(0.75, 0.8, 1.0), 0.3, 0.8)
			"ring_dust": _mats[key] = U.unlit(Color(1.0, 0.95, 0.6))
			_: return FoeBodies._m(key)
	return _mats[key]


## Puts the parts named `kind` on `model` (a KayKit character); false if it isn't a boss's.
static func dress(model: Node3D, skel: Skeleton3D, kind: String) -> bool:
	match kind:
		"king": _king(skel)
		"lich": _lich(model, skel)
		"magma": _magma(skel)
		"fungal": _fungal(model, skel)
		"tide": _tide(model, skel)
		"queen": _queen(model, skel)
		"pharaoh": _pharaoh(skel)
		"tyrant": _tyrant(skel)
		"goat": _goat(skel)
		"scholar": _scholar(skel)
		"forge": _forge(skel)
		"planet": _planet(skel)
		_: return false
	return true


## The Skeleton King: great gold pauldrons spiked with bone, and a long red royal cape
## trimmed with ermine, spreading out behind him to the floor.
static func _king(skel: Skeleton3D) -> void:
	var c := FoeBodies._on(skel, "chest")
	if c == null:
		return
	for side in [-1.0, 1.0]:
		var p := U.sphere(c, 0.25, _m("gold"), Vector3(side * 0.5, 0.16, 0.0))
		p.scale = Vector3(1.1, 0.85, 1.1)
		var rim := U.sphere(c, 0.27, _m("velvet_dark"), Vector3(side * 0.5, 0.1, 0.0))
		rim.scale = Vector3(1.1, 0.4, 1.1)
		for k in 3:
			var s := U.cone(c, 0.08, 0.45 - 0.08 * absf(k - 1), _m("bone"), Vector3(side * (0.52 + 0.05 * k), 0.3, -0.15 + 0.15 * k))
			s.rotation = Vector3(0.3 - 0.3 * k, 0, -side * 0.5)
	# the cape: wide at the floor, from the shoulders down behind him
	var cape := U.cone(c, 0.78, 1.05, _m("velvet"), Vector3(0, -0.85, -0.3), 0.36)
	cape.scale = Vector3(1.0, 1.0, 0.16)   # (flat: a cape, not a drum)
	var collar := U.cylinder(c, 0.44, 0.14, _m("ermine"), Vector3(0, 0.14, -0.12))
	collar.scale = Vector3(1.0, 1.0, 0.75)
	var hem := U.cylinder(c, 0.8, 0.08, _m("ermine"), Vector3(0, -0.87, -0.3))
	hem.scale = Vector3(1.0, 1.0, 0.18)
	for i in 6:
		var ang := PI * (0.12 + 0.76 * i / 5.0)
		U.sphere(c, 0.03, _m("ermine_spot"), Vector3(cos(ang) * 0.4, 0.29, -0.12 - sin(ang) * 0.3))
	FeatHeads.bake(c, "boss king")


## The Lich: no legs, floating on a long tattered robe with a soul-light hem; a mantle of
## bone spikes on its shoulders and three souls circling it.
static func _lich(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"])
	var h := FoeBodies._on(skel, "hips")
	if h:
		U.cone(h, 0.62, 0.78, _m("lich_robe"), Vector3(0, -0.76, 0), 0.32)
		U.cone(h, 0.66, 0.07, _m("lich_hem"), Vector3(0, -0.79, 0), 0.62)
		for i in 9:
			var ang := TAU * i / 9.0
			var t := U.cone(h, 0.14, 0.42 - 0.12 * (i % 2), _m("lich_robe"), Vector3.ZERO)
			t.position = Vector3(cos(ang) * 0.52, -0.8, sin(ang) * 0.52)
			t.rotation = Vector3(PI, 0, 0)
		FeatHeads.bake(h, "boss lich robe")
		var orbit := FoeBodies.Orbit.new()
		h.add_child(orbit)
		for i in 3:
			var ang := TAU * i / 3.0
			var o := U.sphere(orbit, 0.16, _m("soul"), Vector3(cos(ang) * 1.25, 0.2, sin(ang) * 1.25))
			o.name = "Soul%d" % i
			var halo := U.sphere(o, 0.3, _m("soul_glow"))
			halo.set_meta("fx", true)
			o.set_meta("fx", true)
	var c := FoeBodies._on(skel, "chest")
	if c:
		for side in [-1.0, 1.0]:
			for k in 4:
				var s := U.cone(c, 0.12 - 0.012 * k, 0.95 - 0.12 * k, _m("bone"), Vector3(side * (0.45 + 0.06 * k), 0.2 - 0.04 * k, -0.24 + 0.1 * k))
				s.rotation = Vector3(-0.35 + 0.12 * k, 0, -side * (0.75 + 0.22 * k))
		for side in [-1.0, 1.0]:   # a high stiff collar standing up behind its skull
			var panel := U.box(c, Vector3(0.55, 1.0, 0.06), _m("lich_robe"), Vector3(side * 0.3, 0.62, -0.28))
			panel.rotation = Vector3(-0.25, side * 0.45, -side * 0.3)
			var lining := U.box(c, Vector3(0.45, 0.88, 0.02), _m("lich_hem"), Vector3(side * 0.29, 0.6, -0.24))
			lining.rotation = Vector3(-0.25, side * 0.45, -side * 0.3)
		FeatHeads.bake(c, "boss lich mantle")


## The Cinder Colossus: hunched like an ape under a back of black basalt, cracked open in
## vents that glow with lava, the biggest on its shoulders.
static func _magma(skel: Skeleton3D) -> void:
	var c := FoeBodies._on(skel, "chest")
	if c == null:
		return
	var spots := [Vector3(-0.58, 0.12, 0.0), Vector3(0.58, 0.12, 0.0), Vector3(-0.32, 0.05, -0.4), Vector3(0.32, 0.05, -0.4), Vector3(0.0, -0.1, -0.5), Vector3(0.0, 0.25, -0.3)]
	var tilt := [Vector3(-0.1, 0, 0.5), Vector3(-0.1, 0, -0.5), Vector3(-0.8, 0, 0.35), Vector3(-0.8, 0, -0.35), Vector3(-1.1, 0, 0), Vector3(-0.5, 0, 0)]
	var size := [0.75, 0.75, 0.6, 0.6, 0.55, 0.5]   # (the chest is scaled 1.5: so are these)
	for i in spots.size():
		var k: float = size[i]
		var b := Node3D.new()
		c.add_child(b)
		b.position = spots[i]
		b.rotation = tilt[i]
		U.cone(b, 0.3 * k, 0.5 * k, _m("basalt"), Vector3.ZERO, 0.12 * k)   # a vent: a cut-off cone
		U.cylinder(b, 0.13 * k, 0.05, _m("lava_hot"), Vector3(0, 0.48 * k, 0))
		U.cone(b, 0.14 * k, 0.5 * k, _m("lava"), Vector3(0, 0.5 * k, 0))   # (v352: taller, it read black on lava)
		U.cone(b, 0.07 * k, 0.3 * k, _m("lava_hot"), Vector3(0, 0.52 * k, 0))
		FeatHeads.bake(b, "boss magma %d" % i)
		for n in b.get_children():
			n.set_meta("fx", true)   # (its charring overlay and the hit flash leave the lava bright)


## Version 349 (part 2). The Sporemother: no legs; she grows out of a huge frilled
## mushroom skirt, and a ring of tall glowing toadstools stands round her (seen from above,
## a fairy ring that walks with her).
static func _fungal(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"])
	var h := FoeBodies._on(skel, "hips")
	if h == null:
		return
	U.cone(h, 0.42, 0.62, _m("moss"), Vector3(0, -0.6, 0), 0.3)   # the stalk
	var gills := U.cone(h, 0.78, 0.14, _m("spore_gill"), Vector3(0, -0.2, 0), 0.25)
	gills.name = "Gills"
	var dome := U.sphere(h, 0.82, _m("spore_cap"), Vector3(0, -0.08, 0))   # a toadstool's cap for a skirt
	dome.scale = Vector3(1.0, 0.32, 1.0)
	for i in 6:
		var ang := TAU * i / 6.0 + 0.5
		U.sphere(h, 0.07, _m("cap_spot"), Vector3(cos(ang) * 0.6, 0.08, sin(ang) * 0.6))
	for i in 7:   # the ring of toadstools at her feet
		var ang := TAU * i / 7.0 + 0.2
		var k := 1.0 + 0.35 * float(i % 2)
		var base := Vector3(cos(ang) * 1.08, -0.64, sin(ang) * 1.08)
		U.cylinder(h, 0.07 * k, 0.2 * k, _m("stem"), base)
		var cap := U.sphere(h, 0.24 * k, _m("spore_cap"), base + Vector3(0, 0.22 * k, 0))
		cap.scale = Vector3(1.0, 0.55, 1.0)
		U.sphere(h, 0.05 * k, _m("cap_spot"), base + Vector3(0.1 * k, 0.32 * k, 0.04))
	FeatHeads.bake(h, "boss fungal")
	for n in h.get_children():
		n.set_meta("fx", true)   # (her pale fungal overlay would wash the glowing caps out)


## The Tidecaller: hulking, its legs gone into a whirlpool of water that turns round it,
## spiral shells on its shoulders.
static func _tide(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Rogue_LegLeft", "Skeleton_Rogue_LegRight"])
	var h := FoeBodies._on(skel, "hips")
	if h:
		U.cone(h, 0.75, 0.72, _m("water"), Vector3(0, -0.66, 0), 0.32)
		U.cylinder(h, 0.8, 0.05, _m("foam"), Vector3(0, -0.66, 0))
		FeatHeads.bake(h, "boss tide column")
		var spin := FoeBodies.Spin.new()
		spin.speed = 2.2
		h.add_child(spin)
		for i in 4:   # wave crests curling round it
			var ang := TAU * i / 4.0
			var w := Node3D.new()
			spin.add_child(w)
			w.position = Vector3(cos(ang) * 0.72, -0.45, sin(ang) * 0.72)
			w.rotation = Vector3(0, -ang, 0)
			var crest := U.cone(w, 0.17, 0.62, _m("water"), Vector3.ZERO)
			crest.rotation = Vector3(0, 0, -0.9)
			var tip := U.cone(w, 0.1, 0.3, _m("foam"), Vector3(0.48, 0.38, 0))
			tip.rotation = Vector3(0, 0, -2.0)
	var c := FoeBodies._on(skel, "chest")
	if c:
		for side in [-1.0, 1.0]:   # a spiral shell on each shoulder, past its hood
			for k in 4:
				var r := 0.26 - 0.055 * k
				var sh := U.sphere(c, r, _m("shell" if k % 2 == 0 else "shell_in"), Vector3(side * (0.56 + 0.04 * k), 0.16 + 0.11 * k, -0.04 * k))
				sh.scale = Vector3(1.0, 0.75, 1.0)
			var horn := U.cone(c, 0.07, 0.36, _m("shell"), Vector3(side * 0.7, 0.55, -0.15))
			horn.rotation = Vector3(-0.3, 0, -side * 0.4)
		FeatHeads.bake(c, "boss tide shells")


## The Blood Moon Queen: floating in a great red ball gown hemmed with gold, and a bat's
## wings spread from her back, wider than she is (from above too).
static func _queen(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"])
	var h := FoeBodies._on(skel, "hips")
	if h:
		U.cone(h, 0.82, 0.74, _m("gown"), Vector3(0, -0.72, 0), 0.3)
		U.cone(h, 0.86, 0.08, _m("gown_gold"), Vector3(0, -0.75, 0), 0.82)
		U.cone(h, 0.5, 0.06, _m("gown_gold"), Vector3(0, -0.2, 0), 0.47)   # a gold band round her waist-high skirt
		FeatHeads.bake(h, "boss queen gown")
	var c := FoeBodies._on(skel, "chest")
	if c == null:
		return
	for side in [-1.0, 1.0]:
		var w := Node3D.new()
		c.add_child(w)
		w.position = Vector3(side * 0.22, 0.22, -0.3)
		w.rotation = Vector3(-0.45, side * -0.3, 0)
		w.scale = Vector3(side, 1.0, 1.0)   # (the left wing is the right one mirrored)
		var angles := [55.0, 25.0, -5.0]
		var lengths := [1.25, 1.4, 1.1]
		var tips := []
		for k in 3:
			var a := deg_to_rad(angles[k])
			tips.append(Vector2(cos(a), sin(a)) * float(lengths[k]))
			var bone := U.cone(w, 0.05, lengths[k], _m("bone"), Vector3.ZERO)
			bone.rotation = Vector3(0, 0, a - PI * 0.5)
		var poly := [Vector2(0.05, 0.0), Vector2(0.2, 0.6), tips[0], (tips[0] + tips[1]) * 0.36, tips[1], (tips[1] + tips[2]) * 0.36, tips[2], Vector2(0.45, -0.32)]
		var mem := MeshInstance3D.new()
		mem.mesh = Props._poly_slab(poly, -0.015, 0.015)
		mem.material_override = _m("wing")
		mem.rotation = Vector3(-PI * 0.5, 0, 0)   # (the slab is made flat: stand it up)
		w.add_child(mem)
		FeatHeads.bake(w, "boss queen wing")


## Version 350 (part 3). The Sand Pharaoh: a pleated kilt banded in gold, and a falcon's
## wings of gold and lapis folded down its back, their tips flaring out past its shoulders.
static func _pharaoh(skel: Skeleton3D) -> void:
	var h := FoeBodies._on(skel, "hips")
	if h:
		U.cone(h, 0.5, 0.42, _m("kilt"), Vector3(0, -0.36, 0), 0.32)
		U.cylinder(h, 0.34, 0.08, _m("gold"), Vector3(0, 0.0, 0))
		var apron := U.box(h, Vector3(0.22, 0.4, 0.05), _m("gold"), Vector3(0, -0.2, 0.42))
		apron.rotation.x = -0.35
		for i in 3:
			U.box(h, Vector3(0.23, 0.04, 0.06), _m("lapis"), Vector3(0, -0.08 - 0.12 * i, 0.43 - 0.04 * i))
		FeatHeads.bake(h, "boss pharaoh kilt")
	var c := FoeBodies._on(skel, "chest")
	if c == null:
		return
	for side in [-1.0, 1.0]:
		var w := Node3D.new()
		c.add_child(w)
		w.position = Vector3(side * 0.25, 0.2, -0.32)
		w.rotation = Vector3(-0.3, side * -0.25, 0)
		w.scale = Vector3(side, 1.0, 1.0)
		U.box(w, Vector3(0.75, 0.16, 0.08), _m("gold"), Vector3(0.36, 0.12, 0)).rotation.z = 0.35
		for k in 5:   # long feathers hanging from the wing's arm, lapis and turquoise by turns
			var x := 0.12 + 0.15 * k
			var len := 0.6 + 0.12 * k
			var f := U.box(w, Vector3(0.2, len, 0.05), _m("lapis" if k % 2 == 0 else "turq"), Vector3(x + 0.08 * k, 0.08 + 0.05 * k - len * 0.5, -0.01))
			f.rotation.z = 0.3 + 0.08 * k
			U.box(w, Vector3(0.21, 0.06, 0.055), _m("gold"), Vector3(x + 0.08 * k + 0.02 * k, 0.1 + 0.05 * k, -0.01)).rotation.z = 0.3 + 0.08 * k
		FeatHeads.bake(w, "boss pharaoh wing")
		for n in w.get_children():
			n.set_meta("fx", true)   # (its linen wraps overlay would stripe the feathers)


## The Crystal Tyrant: clusters of amethyst burst from both shoulders, wider than its skull.
static func _tyrant(skel: Skeleton3D) -> void:
	var c := FoeBodies._on(skel, "chest")
	if c == null:
		return
	for side in [-1.0, 1.0]:
		for k in 4:
			var s := U.cone(c, 0.16 - 0.025 * k, 0.8 - 0.14 * k, FoeBodies._m("amethyst" if k % 2 == 0 else "amethyst_pale"), Vector3(side * (0.48 + 0.06 * k), 0.12, -0.2 + 0.14 * k))
			s.rotation = Vector3(-0.35 + 0.2 * k, 0.3 * k, -side * (0.45 + 0.2 * k))
	FeatHeads.bake(c, "boss tyrant shoulders")
	for n in c.get_children():
		n.set_meta("fx", true)


## Krampus: a goat's shaggy legs ending in black hooves, and a long tufted tail.
static func _goat(skel: Skeleton3D) -> void:
	for side in ["l", "r"]:
		var up := FoeBodies._on(skel, "upperleg." + side)
		if up:
			U.cone(up, 0.24, 0.42, _m("fur"), Vector3(0, 0.0, 0), 0.2)
			U.cone(up, 0.26, 0.12, _m("fur_frost"), Vector3(0, 0.36, 0), 0.22)
			FeatHeads.bake(up, "boss goat thigh")
		var low := FoeBodies._on(skel, "lowerleg." + side)
		if low:
			U.cone(low, 0.2, 0.3, _m("fur"), Vector3(0, 0.0, 0), 0.14)
			FeatHeads.bake(low, "boss goat shin")
		var foot := FoeBodies._on(skel, "foot." + side)
		if foot:
			var hoof := U.cylinder(foot, 0.16, 0.14, _m("hoof"), Vector3(0, -0.06, 0.04))
			hoof.scale = Vector3(1.0, 1.0, 1.3)
			U.box(foot, Vector3(0.03, 0.15, 0.3), _m("fur"), Vector3(0, 0.0, 0.08))
			FeatHeads.bake(foot, "boss goat hoof")
	var h := FoeBodies._on(skel, "hips")
	if h:
		var t := U.cone(h, 0.07, 1.1, _m("fur"), Vector3(0, 0.0, -0.25))
		t.rotation = Vector3(-2.2, 0, 0)
		var tuft := U.sphere(h, 0.17, _m("fur_frost"), Vector3(0, -0.65, -1.0))
		tuft.scale = Vector3(1.0, 1.4, 1.0)
		FeatHeads.bake(h, "boss goat tail")


## Version 351 (part 4). The Archivist: a scholar's long coat tails hanging behind it to
## the floor, and four open books flying round it, their pages glowing.
static func _scholar(skel: Skeleton3D) -> void:
	var c := FoeBodies._on(skel, "chest")
	if c:
		for side in [-1.0, 1.0]:
			var t := U.box(c, Vector3(0.34, 1.2, 0.05), _m("ink"), Vector3(side * 0.2, -0.75, -0.3))
			t.rotation = Vector3(0.12, 0, side * 0.1)
			var r := U.box(c, Vector3(0.36, 0.06, 0.06), _m("ink_rim"), Vector3(side * 0.26, -1.34, -0.37))
			r.rotation = Vector3(0.12, 0, side * 0.1)
		FeatHeads.bake(c, "boss scholar coat")
	var h := FoeBodies._on(skel, "hips")
	if h == null:
		return
	var orbit := FoeBodies.Orbit.new()
	h.add_child(orbit)
	for i in 4:
		var ang := TAU * i / 4.0
		var b := Node3D.new()
		orbit.add_child(b)
		b.position = Vector3(cos(ang) * 1.35, 0.45 + 0.15 * (i % 2), sin(ang) * 1.35)
		b.rotation = Vector3(0, -ang, 0)
		b.scale = Vector3.ONE * 1.6
		for side in [-1.0, 1.0]:   # open: two covers in a V, pages on them
			var cv := U.box(b, Vector3(0.05, 0.3, 0.36), _m("cover_a" if i % 2 == 0 else "cover_b"), Vector3(0, 0, side * 0.17))
			cv.rotation.x = side * 0.5
			var pg := U.box(b, Vector3(0.06, 0.27, 0.32), _m("page_glow"), Vector3(0.02, 0.02, side * 0.16))
			pg.rotation.x = side * 0.5
		FeatHeads.bake(b, "boss scholar book %d" % (i % 2))
		for n in b.get_children():
			n.set_meta("fx", true)


## The Forgemaster: two iron smokestacks rising from its back, their mouths glowing.
static func _forge(skel: Skeleton3D) -> void:
	var c := FoeBodies._on(skel, "chest")
	if c == null:
		return
	for side in [-1.0, 1.0]:
		var st := Node3D.new()
		c.add_child(st)
		st.position = Vector3(side * 0.55, 0.1, -0.32)   # (v352: out past its clock gear)
		st.rotation = Vector3(-0.1, 0, -side * 0.22)
		U.cylinder(st, 0.11, 0.9, _m("iron"), Vector3.ZERO)
		U.cylinder(st, 0.15, 0.1, _m("iron_dark"), Vector3(0, 0.86, 0))
		U.cylinder(st, 0.13, 0.05, _m("iron_dark"), Vector3(0, 0.4, 0))
		U.cylinder(st, 0.1, 0.02, _m("lava_hot"), Vector3(0, 0.965, 0))
		var g := U.cone(st, 0.09, 0.22, _m("lava"), Vector3(0, 0.95, 0))
		g.name = "Glow"
		FeatHeads.bake(st, "boss forge stack")
		var smoke := Node3D.new()   # (a puff of smoke above it: its own, the iron look leaves it alone)
		st.add_child(smoke)
		for k in 3:
			U.sphere(smoke, 0.12 + 0.04 * k, _m("smoke"), Vector3(0.05 * k, 1.2 + 0.22 * k, -0.04 * k))
		FeatHeads.bake(smoke, "boss forge smoke")
		for n in smoke.get_children():
			n.set_meta("fx", true)


## The Star Eater: a ring like a planet's circling it at the waist, tilted, turning slowly,
## grains of starlight on it.
static func _planet(skel: Skeleton3D) -> void:
	var h := FoeBodies._on(skel, "hips")
	if h == null:
		return
	var tilt := Node3D.new()
	h.add_child(tilt)
	tilt.position = Vector3(0, 0.25, 0)
	tilt.rotation = Vector3(0.3, 0, 0.12)
	var spin := FoeBodies.Spin.new()
	spin.speed = 0.6
	tilt.add_child(spin)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.28
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = _m("ring")
	ring.scale = Vector3(1.0, 0.18, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta("fx", true)
	spin.add_child(ring)
	for i in 9:
		var ang := TAU * i / 9.0
		var d := U.sphere(spin, 0.05 + 0.03 * (i % 3), _m("ring_dust"), Vector3(cos(ang) * 1.14, 0.03, sin(ang) * 1.14))
		d.set_meta("fx", true)
