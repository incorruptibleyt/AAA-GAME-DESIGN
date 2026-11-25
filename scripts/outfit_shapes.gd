class_name OutfitShapes
extends RefCounted
## Version 353 (visual review fix 9, "outfits that change shape"): the outfits were one body
## recoloured. Each now adds its own shapes where the run camera (above and behind the hero)
## sees them: on the shoulders, round the collar and down the back. They take the outfit's
## own two colours (OUTFITS a and b in hero_style.gd), whatever the hero.

static var _mats := {}


## A material for an outfit's part: `tone` is "a" (its main colour), "b" (its trim), or a
## fixed one (gold, white...), lit a little so it reads from far above.
static func _m(outfit: String, tone: String, rough := 0.7, glow := 0.12) -> Material:
	var key := outfit + "/" + tone
	if not _mats.has(key):
		var o: Dictionary = HeroStyle.OUTFITS.get(outfit, {})
		var c: Color
		match tone:
			"a": c = o.get("a", Color.GRAY)
			"b": c = o.get("b", Color.WHITE)
			"a_dark": c = (o.get("a", Color.GRAY) as Color).darkened(0.35)
			"a_light": c = (o.get("a", Color.GRAY) as Color).lightened(0.3)
			"gold": c = Color(1.0, 0.78, 0.3)
			"silver": c = Color(0.85, 0.88, 0.95)
			"leaf_light": c = Color(0.45, 0.75, 0.3)
			"bark": c = Color(0.42, 0.28, 0.16)
			"ermine": c = Color(0.97, 0.96, 0.93)
			"black": c = Color(0.06, 0.06, 0.08)
			"coal": c = Color(0.12, 0.1, 0.1)
			"fire": c = Color(1.0, 0.55, 0.12)
			"fire_hot": c = Color(1.0, 0.85, 0.4)
			"ice": c = Color(0.65, 0.9, 1.0)
			"glacier": c = Color(0.18, 0.45, 0.95)   # (v354: pale ice vanished on the pale Frost outfit)
			"bone": c = Color(0.92, 0.88, 0.78)
			"shell": c = Color(0.97, 0.82, 0.7)
			"shell_in": c = Color(0.95, 0.5, 0.55)
			"diamond_deep": c = Color(0.35, 0.6, 1.0)
			_: c = Color.WHITE
		_mats[key] = U.mat(c, rough, glow)
	return _mats[key]


static func _on(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	return HeroStyle._attachment(skel, bone) if skel.find_bone(bone) >= 0 else null


## A fresh holder for an outfit's parts on `att` (one dressed before is taken off first).
static func _root(att: Node3D) -> Node3D:
	for n in att.get_children():
		if str(n.name).begins_with("OutfitShape"):
			att.remove_child(n)
			n.queue_free()
	var root := Node3D.new()
	root.name = "OutfitShape"
	root.scale = Vector3.ONE * 1.45   # (the heroes' big heads hide anything smaller from above)
	att.add_child(root)
	return root


## A cone (a spike, a flame, a strip) from `from` pointing along `dir`. (U.cone turns
## round its middle: this one grows out of where it starts.)
static func _ray(parent: Node3D, r: float, length: float, mat: Material, from: Vector3, dir: Vector3, top := 0.0) -> MeshInstance3D:
	var c := U.cone(parent, r, length, mat, Vector3.ZERO, top)
	var d := dir.normalized()
	var b := Basis(Vector3.RIGHT, PI) if d.dot(Vector3.UP) < -0.999 else Basis(Quaternion(Vector3.UP, d))
	c.transform = Transform3D(b, from + d * length * 0.5)
	return c


## The outfit's parts keep their own colours: the hero's outfit pattern, glow line and hit
## flash (CharacterVisual) leave them alone.
static func _keep(root: Node3D) -> void:
	for n in root.get_children():
		n.set_meta("fx", true)
		n.set_meta("mark", true)   # (but they hide the hero's body: see CharacterVisual._marked)


## The outfits whose shapes are switched on (the rest come one build at a time).
const READY := ["crimson", "forest", "midnight", "ivory", "shadow", "royal", "ember", "frost",
	"rose", "sea", "gold", "bone"]


## Puts outfit `key`'s shapes on a hero's skeleton. `wings`: the hero wears Legend wings
## (nothing hangs down the back then: it would go through them).
static func dress(skel: Skeleton3D, key: String, wings := false) -> void:
	if key not in READY:
		return
	match key:
		"crimson": _velvet(skel, key, wings)
		"forest": _forest(skel, key)
		"midnight": _midnight(skel, key, wings)
		"ivory": _ivory(skel, key)
		"shadow": _shadow(skel, key)
		"royal": _royal(skel, key, wings)
		"ember": _ember(skel, key)
		"frost": _frost(skel, key)
		"rose": _lilac(skel, key)
		"sea": _sea(skel, key)
		"gold": _gilded(skel, key, wings)
		"bone": _bone(skel, key)
		"diamond": _diamond(skel, key)
		"mythic": _mythic(skel, key)
		"legend": _legend(skel, key)
	_hat(skel, key)


## The wizard's hat (the Mage's own, or one borrowed): its brim hides the shoulders from the
## camera above, so the outfit dresses the hat too. Parts sit in the hat mesh's own space
## (brim about 1.05 round, the tip about 1 up), so they follow the brim when it narrows in a run.
static func _wizard_hat(skel: Skeleton3D) -> MeshInstance3D:
	for h in skel.find_children("*Mage_Hat*", "MeshInstance3D", true, false):
		if (h as MeshInstance3D).visible:
			return h
	return null


static func _hat(skel: Skeleton3D, o: String) -> void:
	var hat := _wizard_hat(skel)
	if hat == null:
		return
	for n in hat.get_children():
		if str(n.name).begins_with("OutfitHat"):
			hat.remove_child(n)
			n.queue_free()
	var root := Node3D.new()
	root.name = "OutfitHat"
	hat.add_child(root)
	match o:
		"crimson":   # a cavalier's hat: puffed, slashed band and a great gold plume
			for k in 7:
				var a := TAU * k / 7.0
				var at := Vector3(cos(a) * 0.64, 0.14, sin(a) * 0.64)
				var puff := U.sphere(root, 0.2, _m(o, "a_light"), at)
				puff.scale = Vector3(1.0, 0.75, 1.0)
				var sl := U.box(root, Vector3(0.06, 0.08, 0.3), _m(o, "b", 0.4, 0.4), at + Vector3(0, 0.13, 0))
				sl.rotation.y = -a
			for k in 3:
				var pl := U.sphere(root, 0.26, _m(o, "gold" if k != 1 else "b", 0.5, 0.3), Vector3.ZERO)
				pl.scale = Vector3(0.8, 0.3, 3.4 - 0.6 * k)
				pl.position = Vector3(0.38 + 0.16 * k, 0.4 + 0.05 * k, -0.45 - 0.08 * k)
				pl.rotation = Vector3(0.25, -0.65 - 0.3 * k, 0.25)
		"forest":   # leaves all round the brim and a sprig at the tip
			for k in 12:
				var a := TAU * k / 12.0
				var leaf := U.sphere(root, 0.2, _m(o, "a" if k % 2 == 0 else "leaf_light"), Vector3.ZERO)
				leaf.scale = Vector3(0.6, 0.14, 1.6)
				leaf.position = Vector3(cos(a), 0.04, sin(a)) * Vector3(1.02, 1.0, 1.02)
				leaf.rotation = Vector3(-0.15, PI * 0.5 - a, 0.0)
				var vein := U.box(root, Vector3(0.025, 0.025, 0.5), _m(o, "bark"), leaf.position + Vector3(0, 0.035, 0))
				vein.rotation = leaf.rotation
			for k in 3:
				var a := TAU * k / 3.0
				var sp := U.sphere(root, 0.15, _m(o, "leaf_light" if k == 1 else "a"), Vector3(cos(a) * 0.14, 0.95, -0.22 + sin(a) * 0.14))
				sp.scale = Vector3(0.6, 0.18, 1.4)
				sp.rotation = Vector3(-0.5, PI * 0.5 - a, 0.0)
		"midnight":   # silver stars round the brim and a crescent moon on the tip
			for k in 7:
				var a := TAU * k / 7.0 + 0.3
				var at := Vector3(cos(a) * 0.76, 0.08, sin(a) * 0.76)
				for t in 2:
					var arm := U.box(root, Vector3(0.24, 0.04, 0.06), _m(o, "silver", 0.3, 0.9), at)
					arm.rotation.y = a + PI * 0.25 + PI * 0.5 * t
			var moon := U.cylinder(root, 0.3, 0.06, _m(o, "silver", 0.3, 0.9), Vector3(0, 0.94, -0.2))
			moon.rotation.x = 0.2
			var bite := U.cylinder(root, 0.26, 0.08, _m(o, "a"), Vector3(0.12, 0.95, -0.12))
			bite.rotation.x = 0.2
		"ivory":   # a plated brim: rounded ivory scales, blue trim, gold studs, gold knob
			for k in 10:
				var a := TAU * k / 10.0
				var at := Vector3(cos(a) * 0.92, 0.06, sin(a) * 0.92)
				var plate := U.sphere(root, 0.24, _m(o, "a", 0.35, 0.1), at)
				plate.scale = Vector3(1.0, 0.32, 1.0)
				var trim := U.sphere(root, 0.255, _m(o, "b", 0.4, 0.35), at - Vector3(0, 0.02, 0))
				trim.scale = Vector3(1.0, 0.14, 1.0)
				U.sphere(root, 0.055, _m(o, "gold", 0.3, 0.3), at * 0.78 + Vector3(0, 0.1, 0))
			U.sphere(root, 0.13, _m(o, "gold", 0.3, 0.3), Vector3(0, 1.0, -0.22))
		"shadow":   # a brim torn into ragged strips, violet-tipped, wisps rising off the tip
			for k in 11:
				var a := TAU * k / 11.0
				var out := Vector3(cos(a), 0.0, sin(a))
				_ray(root, 0.13, 0.42 + 0.12 * (k % 2), _m(o, "a" if k % 2 == 0 else "b", 0.6, 0.0 if k % 2 == 0 else 0.6), out * 0.88 + Vector3(0, 0.03, 0), out + Vector3(0, -0.45, 0))
			for k in 3:
				_ray(root, 0.08, 0.5 + 0.12 * (k % 2), _m(o, "b", 0.4, 0.8), Vector3(0, 0.9, -0.2), Vector3(0.6 * (k - 1), 1.0, -0.5))
		"royal":   # an ermine trim all round the brim and a small gold crown on the tip
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.84
			torus.outer_radius = 1.12
			ring.mesh = torus
			ring.material_override = _m(o, "ermine", 0.9, 0.1)
			ring.position = Vector3(0, 0.02, 0)
			ring.scale = Vector3(1.0, 0.6, 1.0)
			root.add_child(ring)
			for k in 14:
				var a := TAU * k / 14.0
				var sp := U.sphere(root, 0.04, _m(o, "black"), Vector3(cos(a) * 0.98, 0.11, sin(a) * 0.98))
				sp.scale = Vector3(1.0, 0.6, 1.8)
				sp.rotation.y = -a
			U.cylinder(root, 0.22, 0.1, _m(o, "gold", 0.3, 0.35), Vector3(0, 0.82, -0.18))
			for k in 5:
				var a := TAU * k / 5.0
				U.cone(root, 0.06, 0.2, _m(o, "gold", 0.3, 0.35), Vector3(cos(a) * 0.2, 0.86, -0.18 + sin(a) * 0.2))
				U.sphere(root, 0.04, _m(o, "a_light", 0.3, 0.5), Vector3(cos(a) * 0.2, 1.08, -0.18 + sin(a) * 0.2))
		"ember":   # lumps of glowing coal on the brim, flames licking up, a flame for a tip
			for k in 7:
				var a := TAU * k / 7.0 + 0.2
				var at := Vector3(cos(a) * 0.82, 0.08, sin(a) * 0.82)
				var lump := U.sphere(root, 0.17, _m(o, "coal", 0.9, 0.0), at)
				lump.scale = Vector3(1.2, 0.7, 1.0)
				lump.rotation.y = a
				var crack := U.box(root, Vector3(0.28, 0.03, 0.04), _m(o, "fire", 0.4, 1.4), at + Vector3(0, 0.1, 0))
				crack.rotation.y = -a + 0.6
				if k % 2 == 0:
					U.cone(root, 0.09, 0.32, _m(o, "fire_hot" if k % 4 == 0 else "fire", 0.4, 1.6), at + Vector3(0, 0.1, 0))
			U.cone(root, 0.14, 0.45, _m(o, "fire", 0.4, 1.6), Vector3(0, 0.85, -0.2))
			U.cone(root, 0.08, 0.32, _m(o, "fire_hot", 0.4, 1.8), Vector3(0, 0.9, -0.2))
		"frost":   # a white fur band, ice crystals on the brim, icicles hanging from its edge
			U.cylinder(root, 0.55, 0.2, _m(o, "ermine", 0.95, 0.1), Vector3(0, 0.14, 0))
			for k in 6:
				var a := TAU * k / 6.0 + 0.5
				var at := Vector3(cos(a) * 0.78, 0.05, sin(a) * 0.78)
				var out := Vector3(cos(a), 0.0, sin(a))
				_ray(root, 0.1, 0.45, _m(o, "glacier", 0.2, 0.6), at, out * 0.5 + Vector3(0, 1.0, 0))
				_ray(root, 0.07, 0.3, _m(o, "ice", 0.2, 0.6), at, out + Vector3(0.4, 0.6, 0))
			for k in 12:
				var a := TAU * k / 12.0
				_ray(root, 0.06, 0.22 + 0.1 * (k % 2), _m(o, "ice", 0.2, 0.6), Vector3(cos(a), -0.02, sin(a)) * Vector3(0.98, 1.0, 0.98), Vector3.DOWN)
		"rose":   # the brim opens into a lilac flower, a little flower on the tip
			for k in 10:
				var a := TAU * k / 10.0
				var petal := U.sphere(root, 0.26, _m(o, "a" if k % 2 == 0 else "b", 0.6, 0.15), Vector3.ZERO)
				petal.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, -0.35) * Basis.from_scale(Vector3(0.8, 0.12, 1.3)), Vector3(cos(a), 0.1, sin(a)) * Vector3(0.95, 1.0, 0.95))
			for k in 5:
				var a := TAU * k / 5.0
				var pt := U.sphere(root, 0.12, _m(o, "a_light", 0.6, 0.2), Vector3.ZERO)
				pt.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, -0.6) * Basis.from_scale(Vector3(0.8, 0.2, 1.4)), Vector3(cos(a) * 0.14, 0.9, -0.2 + sin(a) * 0.14))
			U.sphere(root, 0.08, _m(o, "gold", 0.4, 0.4), Vector3(0, 0.95, -0.2))
		"sea":   # a spiral shell and a starfish on the brim, fins round its edge
			for k in 4:
				var sh := U.sphere(root, 0.26 - 0.05 * k, _m(o, "shell" if k % 2 == 0 else "a", 0.5, 0.1), Vector3(-0.62 + 0.03 * k, 0.12 + 0.12 * k, -0.35 - 0.02 * k))
				sh.scale = Vector3(1.0, 0.75, 1.0)
			_ray(root, 0.07, 0.3, _m(o, "shell", 0.5, 0.1), Vector3(-0.58, 0.5, -0.4), Vector3(-0.3, 1.0, -0.2))
			for k in 8:
				var a := TAU * k / 8.0 + 0.4
				var out := Vector3(cos(a), 0.0, sin(a))
				_ray(root, 0.09, 0.36, _m(o, "a", 0.4, 0.3), out * 0.9 + Vector3(0, 0.03, 0), out + Vector3(0, 0.15, 0))
			for i in 5:
				var ang := TAU * i / 5.0
				var arm := U.box(root, Vector3(0.1, 0.05, 0.3), _m(o, "b", 0.4, 0.4), Vector3(0.55 + cos(ang) * 0.13, 0.1, -0.45 + sin(ang) * 0.13))
				arm.rotation.y = -ang + PI * 0.5
		"gold":   # a sunburst: white and gold rays all round the brim
			for k in 14:
				var a := TAU * k / 14.0
				var out := Vector3(cos(a), 0.0, sin(a))
				_ray(root, 0.1 if k % 2 == 0 else 0.07, 0.5 if k % 2 == 0 else 0.34, _m(o, "b" if k % 2 == 0 else "gold", 0.3, 0.5), out * 0.92 + Vector3(0, 0.03, 0), out + Vector3(0, 0.1, 0))
			U.cylinder(root, 0.58, 0.12, _m(o, "gold", 0.25, 0.4), Vector3(0, 0.12, 0))
		"bone":   # bone spikes standing round the brim, a skull on the back of the hat
			for k in 9:
				var a := TAU * k / 9.0
				var out := Vector3(cos(a), 0.0, sin(a))
				_ray(root, 0.08, 0.34 + 0.1 * (k % 2), _m(o, "bone", 0.7, 0.1), out * 0.86 + Vector3(0, 0.04, 0), out * 0.5 + Vector3(0, 1.0, 0))
			var skull := U.sphere(root, 0.2, _m(o, "bone", 0.7, 0.1), Vector3(0, 0.32, -0.55))
			skull.scale = Vector3(1.0, 0.9, 0.9)
			for e in [-1.0, 1.0]:
				U.sphere(root, 0.05, _m(o, "black"), Vector3(e * 0.075, 0.35, -0.72))
			U.box(root, Vector3(0.14, 0.05, 0.08), _m(o, "black"), Vector3(0, 0.22, -0.68))
	if root.get_child_count() == 0:
		hat.remove_child(root)
		root.free()
		return
	FeatHeads.bake(root, "outfit hat %s" % o)
	_keep(root)


## Velvet: big puffed and slashed sleeves at the shoulders, gold showing through the slashes,
## and a tailcoat's two long tails behind.
static func _velvet(skel: Skeleton3D, o: String, wings: bool) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		var puff := U.sphere(root, 0.24, _m(o, "a"), Vector3(side * 0.46, 0.16, 0.0))
		puff.scale = Vector3(1.0, 0.85, 1.0)
		for k in 3:   # gold slashes round the puff
			var ang := -0.9 + 0.9 * k
			var sl := U.box(root, Vector3(0.05, 0.3, 0.05), _m(o, "b", 0.4, 0.3), Vector3(side * (0.46 + sin(ang) * 0.02), 0.18, cos(ang) * 0.22))
			sl.position = Vector3(side * 0.46, 0.16, 0) + Vector3(side * 0.2 * cos(ang * 0.6), 0.02, 0.2 * sin(ang))
			sl.rotation = Vector3(0, 0, side * 0.5)
		var cuff := U.cylinder(root, 0.2, 0.06, _m(o, "b", 0.4, 0.3), Vector3(side * 0.48, -0.04, 0.0))
		cuff.rotation.z = side * 0.35
	if not wings:
		for side in [-1.0, 1.0]:
			var t := U.box(root, Vector3(0.22, 0.48, 0.05), _m(o, "a_dark"), Vector3(side * 0.12, -0.42, -0.24))
			t.rotation = Vector3(0.22, 0, side * 0.12)
			var e := U.box(root, Vector3(0.23, 0.06, 0.06), _m(o, "b", 0.4, 0.3), Vector3(side * 0.15, -0.65, -0.29))
			e.rotation = Vector3(0.22, 0, side * 0.12)
	FeatHeads.bake(root, "outfit velvet %s" % wings)
	_keep(root)


## Forest: a mantle of big leaves laid over the shoulders and down the back, light and dark.
static func _forest(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		for k in 4:
			var leaf := U.sphere(root, 0.2, _m(o, "a" if k % 2 == 0 else "leaf_light"), Vector3.ZERO)
			leaf.scale = Vector3(0.55, 0.12, 1.25)   # a flat, long leaf
			leaf.position = Vector3(side * (0.36 + 0.07 * k), 0.24 - 0.05 * k, 0.18 - 0.16 * k)
			leaf.rotation = Vector3(0.2 * k, side * (0.5 + 0.25 * k), -side * (0.45 + 0.12 * k))
			var vein := U.box(root, Vector3(0.02, 0.02, 0.38), _m(o, "bark"), Vector3.ZERO)
			vein.position = leaf.position + Vector3(0, 0.03, 0)
			vein.rotation = leaf.rotation
	for k in 3:   # and down the back
		var leaf := U.sphere(root, 0.22, _m(o, "a" if k != 1 else "leaf_light"), Vector3(0.12 * (k - 1), 0.05 - 0.18 * k, -0.34 - 0.02 * k))
		leaf.scale = Vector3(1.0, 1.35, 0.14)
		leaf.rotation.z = 0.4 * (k - 1)
	FeatHeads.bake(root, "outfit forest")
	_keep(root)


## Midnight: a tall stiff collar standing up behind the head, starred in silver, a silver
## crescent at its top.
static func _midnight(skel: Skeleton3D, o: String, wings: bool) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	var hat := _wizard_hat(skel) != null   # (the tall collar would stick up through its brim)
	for side in ([] if hat else [-1.0, 1.0]):
		var panel := U.box(root, Vector3(0.5, 0.75, 0.05), _m(o, "a"), Vector3(side * 0.26, 0.5, -0.28))
		panel.rotation = Vector3(-0.35, side * 0.55, -side * 0.28)
		var edge := U.box(root, Vector3(0.52, 0.05, 0.06), _m(o, "b", 0.3, 0.5), Vector3(side * 0.31, 0.86, -0.4))
		edge.rotation = Vector3(-0.35, side * 0.55, -side * 0.28)
		for k in 3:
			var st := U.sphere(root, 0.04, _m(o, "silver", 0.3, 0.9), Vector3(side * (0.18 + 0.1 * k), 0.4 + 0.13 * k, -0.33 - 0.04 * k))
			st.scale = Vector3(1.0, 1.0, 0.5)
	if not hat:
		var moon := U.cylinder(root, 0.11, 0.04, _m(o, "silver", 0.3, 0.9), Vector3(0, 0.98, -0.5))
		moon.rotation.x = PI * 0.5 - 0.35
	if not wings:   # a short shoulder cape, its hem silver
		var cape := U.cone(root, 0.55, 0.5, _m(o, "a_dark"), Vector3(0, -0.35, -0.12), 0.38)
		cape.scale = Vector3(1.0, 1.0, 0.72)
		var hem := U.cylinder(root, 0.56, 0.04, _m(o, "b", 0.3, 0.5), Vector3(0, -0.37, -0.12))
		hem.scale = Vector3(1.0, 1.0, 0.73)
	FeatHeads.bake(root, "outfit midnight %s %s" % [wings, hat])
	_keep(root)


## Ivory: a paladin's great rounded pauldrons, three plates stacked down each shoulder,
## trimmed in the outfit's blue, gold studs.
static func _ivory(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		for k in 3:
			var r := 0.27 - 0.03 * k
			var y := 0.2 - 0.11 * k
			var x := 0.44 + 0.05 * k
			var plate := U.sphere(root, r, _m(o, "a", 0.35, 0.1), Vector3(side * x, y, 0.0))
			plate.scale = Vector3(1.05, 0.55, 1.1)
			var trim := U.sphere(root, r + 0.015, _m(o, "b", 0.4, 0.35), Vector3(side * x, y - 0.03, 0.0))
			trim.scale = Vector3(1.05, 0.22, 1.1)
		U.sphere(root, 0.055, _m(o, "gold", 0.3, 0.3), Vector3(side * 0.47, 0.35, 0.0))
		var crest := U.cone(root, 0.06, 0.28, _m(o, "b", 0.4, 0.35), Vector3(side * 0.46, 0.33, -0.05))
		crest.rotation.z = -side * 0.25
	FeatHeads.bake(root, "outfit ivory")
	_keep(root)


## Version 354 (part 2). Shadow: a mantle torn into ragged strips hanging off the shoulders,
## their tips glowing violet, and wisps of shadow rising off the back.
static func _shadow(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		for k in 4:   # strips fanning down and out over the arm, front to back
			var base := Vector3(side * 0.4, 0.22, 0.2 - 0.14 * k)
			var len := 0.55 - 0.08 * (k % 2)
			var dir := Vector3(side * 0.6, -0.8, 0.1 * (k - 1.5))
			_ray(root, 0.11, len, _m(o, "a" if k % 2 == 0 else "b", 0.6, 0.0 if k % 2 == 0 else 0.6), base, dir)
	for k in 3:   # wisps rising behind
		_ray(root, 0.09, 0.55 + 0.1 * (k % 2), _m(o, "b", 0.4, 0.8), Vector3(0.2 * (k - 1), 0.2, -0.3), Vector3(0.4 * (k - 1), 1.0, -0.6))
	FeatHeads.bake(root, "outfit shadow")
	_keep(root)


## Royal: an ermine collar round the shoulders (white, spotted black) and a royal mantle down
## the back, gold edged.
static func _royal(skel: Skeleton3D, o: String, wings: bool) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	var collar := U.cylinder(root, 0.52, 0.16, _m(o, "ermine", 0.9, 0.1), Vector3(0, 0.12, -0.02))
	collar.scale = Vector3(1.0, 1.0, 0.82)
	for i in 10:
		var ang := TAU * i / 10.0
		var sp := U.sphere(root, 0.035, _m(o, "black"), Vector3(cos(ang) * 0.5, 0.25, sin(ang) * 0.41))
		sp.scale = Vector3(1.0, 1.8, 1.0)
	for side in [-1.0, 1.0]:   # gold clasps
		U.sphere(root, 0.07, _m(o, "gold", 0.3, 0.3), Vector3(side * 0.22, 0.2, 0.4))
	if not wings:
		var cape := U.cone(root, 0.62, 0.62, _m(o, "a"), Vector3(0, -0.52, -0.2), 0.45)
		cape.scale = Vector3(1.0, 1.0, 0.45)
		var hem := U.cylinder(root, 0.63, 0.05, _m(o, "b", 0.3, 0.3), Vector3(0, -0.54, -0.2))
		hem.scale = Vector3(1.0, 1.0, 0.46)
	FeatHeads.bake(root, "outfit royal %s" % wings)
	_keep(root)


## Ember: lumps of coal on the shoulders, cracked and glowing, little flames licking up.
static func _ember(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		var lump := U.sphere(root, 0.25, _m(o, "coal", 0.9, 0.0), Vector3(side * 0.46, 0.14, 0.0))
		lump.scale = Vector3(1.1, 0.75, 1.0)
		for k in 3:   # glowing cracks
			var cr := U.box(root, Vector3(0.025, 0.03, 0.38), _m(o, "fire", 0.5, 1.6), Vector3(side * (0.4 + 0.07 * k), 0.29 - 0.03 * k, 0.0))
			cr.rotation = Vector3(0, 0.6 * (k - 1), -side * 0.3)
		for k in 3:   # flames
			_ray(root, 0.08 - 0.015 * k, 0.42 - 0.08 * k, _m(o, "fire" if k != 1 else "fire_hot", 0.5, 2.0), Vector3(side * (0.4 + 0.08 * k), 0.24, -0.1 + 0.1 * k), Vector3(side * 0.3, 1.0, 0.0))
	FeatHeads.bake(root, "outfit ember")
	_keep(root)


## Frost: clusters of ice crystals on the shoulders, icicles hanging under them, a white fur
## collar.
static func _frost(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	var fur := U.cylinder(root, 0.42, 0.12, _m(o, "b", 0.95, 0.1), Vector3(0, 0.12, -0.02))
	fur.scale = Vector3(1.0, 1.0, 0.85)
	for side in [-1.0, 1.0]:
		for k in 4:
			_ray(root, 0.1 - 0.012 * k, 0.55 - 0.08 * k, _m(o, "glacier" if k % 2 == 0 else "ice", 0.15, 0.6), Vector3(side * (0.4 + 0.04 * k), 0.2, -0.15 + 0.12 * k), Vector3(side * (0.5 + 0.3 * k), 1.0, -0.4 + 0.3 * k))
		for k in 3:
			_ray(root, 0.04, 0.2 - 0.04 * (k % 2), _m(o, "ice", 0.15, 0.6), Vector3(side * (0.4 + 0.07 * k), 0.1, -0.08 + 0.1 * k), Vector3.DOWN)
	FeatHeads.bake(root, "outfit frost")
	_keep(root)


## Version 355 (part 3). Lilac: a ruff of big petals round the neck, opening out like a flower
## (from above, the hero's head sits in a lilac bloom), and a flower on each shoulder.
static func _lilac(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for i in 10:
		var ang := TAU * i / 10.0
		var d := Vector3(cos(ang), 0.0, sin(ang) * 0.85)
		var petal := U.sphere(root, 0.22, _m(o, "a" if i % 2 == 0 else "b", 0.6, 0.15), Vector3.ZERO)
		petal.transform = Transform3D(Basis(Vector3.UP, -ang + PI * 0.5) * Basis(Vector3.RIGHT, -0.5) * Basis.from_scale(Vector3(0.75, 0.12, 1.3)), d * 0.5 + Vector3(0, 0.2, 0))
	for side in [-1.0, 1.0]:
		for k in 5:
			var ang := TAU * k / 5.0
			var p2 := U.sphere(root, 0.13, _m(o, "a", 0.6, 0.15), Vector3(side * 0.52 + cos(ang) * 0.14, 0.3, sin(ang) * 0.14))
			p2.scale = Vector3(1.0, 0.35, 1.0)
		U.sphere(root, 0.08, _m(o, "gold", 0.4, 0.4), Vector3(side * 0.52, 0.34, 0.0))
	for k in 6:   # (v355: and a big bloom pinned on the back, where the camera looks)
		var ang := TAU * k / 6.0
		var pt := U.sphere(root, 0.17, _m(o, "a" if k % 2 == 0 else "b", 0.6, 0.15), Vector3.ZERO)
		pt.transform = Transform3D(Basis(Vector3.BACK, ang) * Basis.from_scale(Vector3(0.75, 1.3, 0.15)), Vector3(-sin(ang) * 0.2, -0.02 + cos(ang) * 0.2, -0.42))
	U.sphere(root, 0.09, _m(o, "gold", 0.4, 0.4), Vector3(0, -0.02, -0.46))
	FeatHeads.bake(root, "outfit lilac")
	_keep(root)


## Sea: a spiral shell on each shoulder and a gold starfish pinned on the back.
static func _sea(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		for k in 4:
			var r := 0.24 - 0.05 * k
			var sh := U.sphere(root, r, _m(o, "shell" if k % 2 == 0 else "a", 0.5, 0.1), Vector3(side * (0.44 + 0.03 * k), 0.14 + 0.1 * k, -0.03 * k))
			sh.scale = Vector3(1.0, 0.72, 1.0)
		_ray(root, 0.06, 0.3, _m(o, "shell", 0.5, 0.1), Vector3(side * 0.5, 0.5, -0.1), Vector3(side * 0.3, 1.0, -0.2))
		for k in 3:   # a fan of fins
			_ray(root, 0.07, 0.4, _m(o, "a", 0.4, 0.3), Vector3(side * 0.5, 0.1, 0.12 - 0.12 * k), Vector3(side * 1.0, 0.15, 0.4 * (1 - k)))
	for i in 5:   # the starfish
		var ang := TAU * i / 5.0 + PI * 0.5
		var arm := U.box(root, Vector3(0.07, 0.2, 0.04), _m(o, "b", 0.4, 0.4), Vector3(cos(ang) * 0.1, 0.05 + sin(ang) * 0.1, -0.4))
		arm.rotation.z = ang - PI * 0.5
	FeatHeads.bake(root, "outfit sea")
	_keep(root)


## Gilded: a great gold sunburst standing behind the shoulders, rays all round it (above
## the head from behind), gold shoulder plates.
static func _gilded(skel: Skeleton3D, o: String, wings: bool) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		var p := U.sphere(root, 0.23, _m(o, "gold", 0.3, 0.3), Vector3(side * 0.45, 0.15, 0.0))
		p.scale = Vector3(1.1, 0.6, 1.1)
		U.sphere(root, 0.06, _m(o, "b", 0.3, 0.5), Vector3(side * 0.5, 0.27, 0.0))
	if not wings:
		var disc := U.cylinder(root, 0.32, 0.05, _m(o, "b", 0.3, 0.6), Vector3.ZERO)   # (white: the gold outfit is gold already)
		disc.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.3), Vector3(0, 0.55, -0.42))
		for i in 12:
			var ang := TAU * i / 12.0
			var d := Vector3(cos(ang), sin(ang), 0.0)
			var len := 0.36 if i % 2 == 0 else 0.22
			var ray := _ray(root, 0.06, len, _m(o, "gold", 0.3, 0.45), Vector3.ZERO, d)
			ray.transform = Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(0, 0.55, -0.42)) * ray.transform.translated(d * 0.3)
	FeatHeads.bake(root, "outfit gilded %s" % wings)
	_keep(root)


## Bone: ribs curving over each shoulder, bone spikes standing up from them, a little skull
## on each.
static func _bone(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		for k in 3:   # ribs
			var rib := U.box(root, Vector3(0.36, 0.06, 0.07), _m(o, "bone", 0.7, 0.1), Vector3(side * 0.42, 0.18 - 0.05 * k, 0.14 - 0.14 * k))
			rib.rotation.z = -side * 0.45
		for k in 3:
			_ray(root, 0.07, 0.45 - 0.08 * absf(k - 1), _m(o, "bone", 0.7, 0.1), Vector3(side * 0.5, 0.28, 0.14 - 0.14 * k), Vector3(side * 0.6, 1.0, 0.2 * (1 - k)))
		var skull := U.sphere(root, 0.12, _m(o, "bone", 0.7, 0.1), Vector3(side * 0.55, 0.16, 0.18))
		skull.scale = Vector3(1.0, 0.9, 1.0)
		for e in [-1.0, 1.0]:
			U.sphere(root, 0.03, _m(o, "black"), Vector3(side * 0.55 + e * 0.045, 0.18, 0.29))
	FeatHeads.bake(root, "outfit bone")
	_keep(root)


## Version 356 (part 4, the Legend road's three). Diamond: diamonds floating round the
## shoulders, turning slowly.
static func _diamond(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	var spin := FoeBodies.Spin.new()
	spin.speed = 0.8
	root.add_child(spin)
	for i in 6:
		var ang := TAU * i / 6.0
		var g := Node3D.new()
		spin.add_child(g)
		g.position = Vector3(cos(ang) * 0.6, 0.3 + 0.08 * (i % 2), sin(ang) * 0.55)
		var k := 1.6 if i % 2 == 0 else 1.2
		U.cone(g, 0.1 * k, 0.12 * k, _m(o, "ice", 0.1, 0.9), Vector3(0, 0.0, 0))
		var low := U.cone(g, 0.1 * k, 0.2 * k, _m(o, "diamond_deep", 0.1, 0.9), Vector3.ZERO)
		low.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.1 * k, 0))
		FeatHeads.bake(g, "outfit diamond %d" % (i % 2))
		_keep(g)


## Mythic: two rings of glowing runes circling the hero, tilted, turning opposite ways.
static func _mythic(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for r in 2:
		var tilt := Node3D.new()
		root.add_child(tilt)
		tilt.position = Vector3(0, 0.15 - 0.45 * r, 0)
		tilt.rotation = Vector3(0.25 * (1 - 2 * r), 0, 0.15)
		var spin := FoeBodies.Spin.new()
		spin.speed = 1.1 * (1 - 2 * r)
		tilt.add_child(spin)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.66 - 0.06 * r
		tm.outer_radius = 0.7 - 0.06 * r
		tm.rings = 32
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = _m(o, "b", 0.3, 1.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.set_meta("fx", true)
		spin.add_child(ring)
		for i in 8:   # runes on it
			var ang := TAU * i / 8.0
			var rune := U.box(spin, Vector3(0.05, 0.12, 0.02), _m(o, "b", 0.3, 1.4), Vector3(cos(ang) * (0.68 - 0.06 * r), 0.0, sin(ang) * (0.68 - 0.06 * r)))
			rune.rotation.y = -ang + PI * 0.5
			rune.set_meta("fx", true)


## Legend: tall flames of gold rising off the shoulders, as if the hero burned.
static func _legend(skel: Skeleton3D, o: String) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	var root := _root(c)
	for side in [-1.0, 1.0]:
		var p := U.sphere(root, 0.22, _m(o, "a", 0.5, 0.15), Vector3(side * 0.44, 0.14, 0.0))
		p.scale = Vector3(1.1, 0.65, 1.1)
		for k in 4:
			var tone := "b" if k % 2 == 0 else "fire"
			_ray(root, 0.1 - 0.012 * k, 0.6 - 0.08 * k, _m(o, tone, 0.5, 1.6), Vector3(side * (0.38 + 0.06 * k), 0.24, -0.15 + 0.1 * k), Vector3(side * (0.15 + 0.12 * k), 1.0, -0.25))
	FeatHeads.bake(root, "outfit legend")
	_keep(root)
