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
			"basalt": _mats[key] = U.mat(Color(0.2, 0.15, 0.13), 0.9)   # (v405: the places' own plates)
			"glowcap": _mats[key] = U.mat(Color(0.35, 0.6, 1.0), 0.5, 0.9)
			"lapis": _mats[key] = U.mat(Color(0.15, 0.3, 0.85), 0.35, 0.25)
			"iron_dark": _mats[key] = U.mat(Color(0.14, 0.13, 0.14), 0.5)
			"rust": _mats[key] = U.mat(Color(0.55, 0.2, 0.12), 0.7)
			"dive_brass": _mats[key] = U.mat(Color(0.78, 0.46, 0.15), 0.35, 0.12)
			"dive_dark": _mats[key] = U.mat(Color(0.03, 0.08, 0.1), 0.2)
			"dive_eye": _mats[key] = U.unlit(Color(0.55, 1.0, 0.9))
			"anchor": _mats[key] = U.mat(Color(0.2, 0.22, 0.26), 0.5, 0.05)
			"leaf": _mats[key] = U.mat(Color(0.45, 0.85, 0.2), 0.7, 0.35)
			"leaf_pale": _mats[key] = U.mat(Color(0.75, 1.0, 0.35), 0.7, 0.6)
			"bark_light": _mats[key] = U.mat(Color(0.5, 0.33, 0.18), 0.9)
			"bone": _mats[key] = U.mat(Color(0.8, 0.76, 0.66), 0.75)   # (v367: a little darker, it blew out white)
			"horn": _mats[key] = U.mat(Color(0.2, 0.12, 0.13), 0.45)
			"horn_tip": _mats[key] = U.mat(Color(0.42, 0.24, 0.2), 0.4)
			"leather": _mats[key] = U.mat(Color(0.42, 0.26, 0.14), 0.85)
			"fletch": _mats[key] = U.mat(Color(1.0, 0.82, 0.2), 0.6, 0.6)
			"linen": _mats[key] = U.mat(Color(0.78, 0.7, 0.55), 0.95)   # (v367: aged wraps, not white)
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
			"flame": _mats[key] = U.unlit(Color(1.0, 0.55, 0.12))
			"flame_hot": _mats[key] = U.unlit(Color(1.0, 0.85, 0.35))
			"ice": _mats[key] = U.mat(Color(0.6, 0.9, 1.0), 0.1, 1.0)
			"ice_deep": _mats[key] = U.mat(Color(0.4, 0.7, 1.0), 0.15, 0.6)
			"cap_red": _mats[key] = U.mat(Color(0.85, 0.2, 0.2), 0.6, 0.15)
			"cap_spot": _mats[key] = U.mat(Color(1.0, 0.95, 0.85), 0.7)
			"stem": _mats[key] = U.mat(Color(0.9, 0.85, 0.72), 0.8)
			"bark": _mats[key] = U.mat(Color(0.5, 0.34, 0.2), 0.9)
			"bark_moss": _mats[key] = U.mat(Color(0.45, 0.6, 0.18), 0.85, 0.25)
			"rock": _mats[key] = U.mat(Color(0.3, 0.27, 0.32), 0.9)
			"fur_dark": _mats[key] = U.mat(Color(0.28, 0.07, 0.09), 0.9)
			"fur_red": _mats[key] = U.mat(Color(0.8, 0.12, 0.1), 0.8, 0.35)
			"wood": _mats[key] = U.mat(Color(0.45, 0.28, 0.16), 0.85)
			"bell_gold": _mats[key] = U.mat(Color(1.0, 0.78, 0.28), 0.25, 0.3)
			"snow": _mats[key] = U.mat(Color(0.93, 0.97, 1.0), 0.9, 0.15)
			"shade": _mats[key] = U.mat(Color(0.32, 0.02, 0.05), 0.7, 0.35)
			"shade_rim": _mats[key] = U.unlit(Color(1.0, 0.18, 0.15))
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
		"brute":
			_brute(skel)
			_place_helm(model, skel)
		"quiver": _quiver(skel)
		"robe": _robe(model, skel)
		"crest": _crest(skel)
		"imp": _imp(skel)
		"linen": _linen(skel)
		"geode": _geode(skel)
		"cogs": _cogs(skel)
		"voidtail": _voidtail(model, skel)
		"books": _books(skel)
		"seaweed": _seaweed(skel)
		"embers": _embers(skel)
		"icicles": _icicles(model, skel)
		"sprouts": _sprouts(skel)
		"roots": _roots(model, skel)
		"howl": _howl(skel)
		"yoke": _yoke(skel)
		"snowpack": _snowpack(skel)
		"ears": _ears(skel)
		"shade": _shade(model, skel)
		_: BossBodies.dress(model, skel, kind)


## The Skeleton Warrior: a big round iron plate on each shoulder, wider than its head, with
## two bone spikes standing up from each (they sit on the chest, so they show from above).
## Version 405 (re-review of v400, fix 5): the grunt and the brute were the same two bodies
## on eight floors. Each place now makes the plates and spikes of its own stuff and adds
## one shape it grows (see PLACE_LOOK and _place_brute).
static func _brute(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	var place := place_key()
	var look: Dictionary = PLACE_LOOK.get(place, PLACE_LOOK[""])
	for side in [-1.0, 1.0]:
		var plate := U.sphere(a, 0.27, _m(look.plate), Vector3(side * 0.4, 0.2, 0.0))
		plate.scale = Vector3(1.1, 0.7, 1.0)
		var rim := U.sphere(a, 0.29, _m(look.rim), Vector3(side * 0.4, 0.15, 0.0))
		rim.scale = Vector3(1.1, 0.35, 1.0)
		if not look.get("no_spikes", false):
			for k in 2:
				var s := U.cone(a, 0.1, 0.55, _m(look.spike), Vector3.ZERO)
				s.position = Vector3(side * (0.42 + 0.06 * k), 0.3, -0.1 + 0.2 * k)
				s.rotation = Vector3(0.25 - 0.5 * k, 0, -side * 0.45)
		_place_brute(a, place, side)
	FeatHeads.bake(a, "foe brute " + place)   # one mesh: a room of warriors stays cheap to draw


## Which place's dress the grunt and brute wear ("" = the Bone Crypt's own, floor 1).
static func place_key() -> String:
	if Floors.lobby:
		return ""
	if Game.daily:
		return "daily"
	match Floors.index(Game.floor_num):
		1: return "frost"
		2: return "ember"
		Floors.DROWNED: return "drowned"
		Floors.GROTTO: return "grotto"
		Floors.BLOOD_MOON: return "blood"
		Floors.FROSTFALL: return "snow"
		Floors.SANDFALL: return "sand"
		Floors.MINE: return "mine"
		Floors.LIBRARY: return "library"
		Floors.FOUNDRY: return "foundry"
		Floors.ABYSS: return "abyss"
	return ""


## Per place: the brute's plate, its rim and its spikes; the grunt's horns and horn tips.
const PLACE_LOOK := {
	"": {"plate": "iron_light", "rim": "rust", "spike": "bone", "horn": "horn", "tip": "horn_tip"},
	"frost": {"plate": "ice_deep", "rim": "snow", "spike": "ice", "horn": "ice_deep", "tip": "ice"},
	"ember": {"plate": "basalt", "rim": "flame", "spike": "flame_hot", "horn": "basalt", "tip": "flame_hot", "no_spikes": true},
	"drowned": {"plate": "anchor", "rim": "weed", "spike": "barnacle", "horn": "weed_dark", "tip": "barnacle"},
	"grotto": {"plate": "glowcap", "rim": "stem", "spike": "cap_spot", "horn": "horn", "tip": "glowcap", "no_spikes": true},
	"blood": {"plate": "fur_dark", "rim": "shade_rim", "spike": "bone", "horn": "fur_dark", "tip": "shade_rim"},
	"snow": {"plate": "iron_light", "rim": "snow", "spike": "ice", "horn": "horn", "tip": "snow"},
	"sand": {"plate": "bell_gold", "rim": "lapis", "spike": "linen", "horn": "lapis", "tip": "bell_gold", "no_spikes": true},
	"mine": {"plate": "rock", "rim": "amethyst", "spike": "amethyst", "horn": "amethyst", "tip": "amethyst_pale", "no_spikes": true},
	"library": {"plate": "book_a", "rim": "pages", "spike": "brass", "horn": "horn", "tip": "horn_tip", "no_spikes": true},
	"foundry": {"plate": "brass", "rim": "steel", "spike": "steel", "horn": "brass", "tip": "steel", "no_spikes": true},
	"abyss": {"plate": "void", "rim": "void_rim", "spike": "void_rim", "horn": "void", "tip": "void_rim"},
	"daily": {"plate": "bell_gold", "rim": "rust", "spike": "bone", "horn": "horn", "tip": "bell_gold", "no_spikes": true},
}


## Version 405 (fix 5): from the run camera the brute is mostly its brown horned helmet, the
## same on every floor. Most places swap it for a helmet of their own.
static func _place_helm(model: Node3D, skel: Skeleton3D) -> void:
	var place := place_key()
	if not place in ["frost", "ember", "grotto", "sand", "mine", "library", "foundry", "abyss"]:
		return
	var h := _on(skel, "head")
	if h == null:
		return
	Art.hide_parts(model, ["Skeleton_Warrior_Helmet"])
	match place:
		"frost":   # a crown of ice spikes on an ice cap
			var cap := U.sphere(h, 0.5, _m("ice_deep"), Vector3(0, 0.66, 0))
			cap.scale = Vector3(1.0, 0.72, 1.0)
			for k in 5:
				var ang := PI * (0.1 + 0.8 * k / 4.0)
				var sp := U.cone(h, 0.09, 0.5 - 0.12 * absf(k - 2) * 0.5, _m("ice"), Vector3(cos(ang) * 0.36, 0.86, -sin(ang) * 0.2 + 0.05))
				sp.rotation = Vector3(-0.2, 0, -cos(ang) * 0.5)
		"ember":   # a black basalt dome with a crest of flame from front to back
			var dome := U.sphere(h, 0.5, _m("basalt"), Vector3(0, 0.64, 0))
			dome.scale = Vector3(1.0, 0.75, 1.05)
			for k in 4:
				var f := U.cone(h, 0.12 - 0.015 * k, 0.48 - 0.06 * absf(k - 1.5), _m("flame_hot" if k % 2 == 0 else "flame"), Vector3(0, 0.95, 0.25 - 0.17 * k))
				f.rotation = Vector3(-0.35, 0, 0)
		"grotto":   # a broad glowing mushroom cap for a hat, pale spots on it
			var cap := U.sphere(h, 0.7, _m("glowcap"), Vector3(0, 0.88, 0))
			cap.scale = Vector3(1.0, 0.42, 1.0)
			U.cylinder(h, 0.46, 0.06, _m("stem"), Vector3(0, 0.66, 0))
			for k in 5:
				var ang := TAU * k / 5.0
				U.sphere(h, 0.08, _m("cap_spot"), Vector3(cos(ang) * 0.4, 1.05, sin(ang) * 0.4))
		"sand":   # a striped royal headcloth, gold and lapis, a cobra at the brow
			var dome := U.sphere(h, 0.5, _m("bell_gold"), Vector3(0, 0.62, -0.02))
			dome.scale = Vector3(1.05, 0.8, 1.0)
			for k in 3:
				var band := U.cylinder(h, 0.52 - 0.06 * k, 0.05, _m("lapis"), Vector3(0, 0.62 + 0.14 * k, -0.02))
				band.scale = Vector3(1.0, 1.0, 0.98)
			for side in [-1.0, 1.0]:
				var lap := U.box(h, Vector3(0.16, 0.55, 0.3), _m("bell_gold"), Vector3(side * 0.5, 0.35, 0.02))
				lap.rotation = Vector3(0, 0, side * 0.12)
				var _r1 := U.box(h, Vector3(0.17, 0.06, 0.31), _m("lapis"), Vector3(side * 0.5, 0.42, 0.02))
				_r1.rotation = lap.rotation
			U.cone(h, 0.07, 0.22, _m("bell_gold"), Vector3(0, 0.9, 0.42))
		"mine":   # a miner's helmet: a dome and brim, a burning lamp in front, crystals grown on top
			var dome := U.sphere(h, 0.48, _m("rock"), Vector3(0, 0.66, 0))
			dome.scale = Vector3(1.0, 0.75, 1.0)
			U.cylinder(h, 0.6, 0.05, _m("rock"), Vector3(0, 0.62, 0))
			var _r2 := U.cylinder(h, 0.11, 0.12, _m("brass"), Vector3(0, 0.78, 0.42))
			_r2.rotation = Vector3(PI * 0.5, 0, 0)
			U.sphere(h, 0.09, _m("flame_hot"), Vector3(0, 0.78, 0.55))
			for k in 2:
				var c := U.cone(h, 0.1, 0.42 - 0.1 * k, _m("amethyst" if k == 0 else "amethyst_pale"), Vector3(-0.1 + 0.22 * k, 0.94, -0.12), 0.02)
				c.rotation = Vector3(-0.25, 0, 0.3 - 0.6 * k)
		"library":   # a scholar's tall pointed cap of old leather, a fat lit candle stuck to its brim
			var brim := U.cylinder(h, 0.62, 0.06, _m("book_b"), Vector3(0, 0.66, 0))
			brim.scale = Vector3(1.0, 1.0, 0.9)
			var cap := U.cone(h, 0.42, 0.95, _m("book_a"), Vector3(0, 0.68, 0))
			cap.rotation = Vector3(-0.35, 0, 0.12)
			U.cylinder(h, 0.44, 0.07, _m("pages"), Vector3(0, 0.72, 0))   # a band of pages
			U.cylinder(h, 0.11, 0.42, _m("stem"), Vector3(0.42, 0.7, 0.18))
			U.cone(h, 0.12, 0.32, _m("flame_hot"), Vector3(0.42, 1.12, 0.18))
			U.cone(h, 0.07, 0.2, _m("flame"), Vector3(0.42, 1.14, 0.18))
		"foundry":   # a dark riveted welder's helmet with two big glowing brass goggles
			var dome := U.sphere(h, 0.5, _m("iron_dark"), Vector3(0, 0.64, 0))
			dome.scale = Vector3(1.0, 0.8, 1.05)
			U.box(h, Vector3(0.12, 0.08, 0.95), _m("brass"), Vector3(0, 1.02, 0))   # a brass ridge, front to back
			for side in [-1.0, 1.0]:
				var g := U.cylinder(h, 0.17, 0.12, _m("brass"), Vector3(side * 0.19, 0.66, 0.4))
				g.rotation = Vector3(PI * 0.5 - 0.5, 0, 0)
				var lens := U.cylinder(h, 0.12, 0.13, _m("flame_hot"), Vector3(side * 0.19, 0.66, 0.41))
				lens.rotation = g.rotation
			for k in 6:
				var ang := TAU * k / 6.0
				U.sphere(h, 0.045, _m("brass"), Vector3(cos(ang) * 0.5, 0.55, sin(ang) * 0.5))
		"abyss":   # a dark hood drawn up into a point, one great four-pointed star burning above it
			var hood := U.cone(h, 0.56, 0.9, _m("void"), Vector3(0, 0.5, -0.06))
			hood.rotation = Vector3(-0.3, 0, 0)
			for k in 4:
				var pt := U.cone(h, 0.09, 0.42, _m("void_rim"), Vector3(0, 1.45, -0.25))
				pt.rotation = Vector3(0, 0, PI * 0.5 * k)
				pt.scale = Vector3(1.0, 1.0, 0.4)
			U.sphere(h, 0.12, _m("void_rim"), Vector3(0, 1.45, -0.25))
	FeatHeads.bake(h, "foe helm " + place)


## The one shape each place grows on the brute's shoulder plate (on `side`).
static func _place_brute(a: Node3D, place: String, side: float) -> void:
	var x := side * 0.4
	match place:
		"frost":   # icicles hanging under the plate's edge
			for k in 3:
				var il := 0.32 - 0.07 * absf(k - 1)
				var ic := U.cone(a, 0.06, il, _m("ice"), Vector3(x + side * 0.18, 0.08 - il, -0.18 + 0.18 * k))
				ic.rotation = Vector3(PI, 0, 0)
		"ember":   # three tongues of flame standing up from a basalt plate
			for k in 3:
				var f := U.cone(a, 0.1 - 0.02 * absf(k - 1), 0.5 + 0.12 * (1 - absf(k - 1)), _m("flame" if k != 1 else "flame_hot"), Vector3(x + side * 0.05 * k, 0.3, -0.15 + 0.15 * k))
				f.rotation = Vector3(0.15 - 0.15 * k, 0, -side * 0.25)
		"drowned":   # a crust of barnacles and a strand of weed hanging off
			for k in 4:
				U.sphere(a, 0.07, _m("barnacle"), Vector3(x + side * (0.05 * (k % 2)), 0.36, -0.15 + 0.1 * k))
			var w := U.cylinder(a, 0.035, 0.5, _m("weed"), Vector3(x + side * 0.24, -0.3, 0.05))
			w.rotation = Vector3(0, 0, side * 0.15)
		"grotto":   # the plate is a glowing mushroom cap, with pale spots, on a stem
			U.cylinder(a, 0.08, 0.2, _m("stem"), Vector3(x, 0.15, 0))
			var cap := U.sphere(a, 0.3, _m("glowcap"), Vector3(x, 0.38, 0))
			cap.scale = Vector3(1.15, 0.5, 1.15)
			for k in 3:
				U.sphere(a, 0.05, _m("cap_spot"), Vector3(x + side * (0.08 * k - 0.06), 0.52, -0.1 + 0.1 * k))
		"blood":   # a ragged red-edged fur collar standing up behind the plates
			var cf := U.cone(a, 0.14, 0.4, _m("fur_red"), Vector3(x * 0.7, 0.3, -0.2))
			cf.rotation = Vector3(-0.5, 0, -side * 0.3)
		"snow":   # a heap of snow on the plate
			var sn := U.sphere(a, 0.24, _m("snow"), Vector3(x, 0.36, 0.0))
			sn.scale = Vector3(1.0, 0.55, 1.0)
		"sand":   # a gold scarab plate with lapis bands and a tall gold-capped obelisk spike
			for k in 2:
				var band := U.box(a, Vector3(0.5, 0.04, 0.06), _m("lapis"), Vector3(x, 0.4, -0.1 + 0.2 * k))
				band.rotation = Vector3(0, 0, -side * 0.15)
			var ob := U.box(a, Vector3(0.1, 0.42, 0.1), _m("linen"), Vector3(x + side * 0.12, 0.55, -0.05))
			ob.rotation = Vector3(0, 0, -side * 0.3)
			var obt := U.cone(a, 0.07, 0.14, _m("bell_gold"), Vector3(x + side * 0.24, 0.74, -0.05))
			obt.rotation = Vector3(0, 0, -side * 0.3)
		"mine":   # a cluster of amethyst crystals grown out of the rock plate
			for k in 3:
				var c := U.cone(a, 0.09, 0.5 - 0.1 * absf(k - 1), _m("amethyst" if k != 1 else "amethyst_pale"), Vector3(x + side * 0.05 * k, 0.28, -0.14 + 0.14 * k), 0.02)
				c.rotation = Vector3(0.35 - 0.35 * k, 0, -side * (0.3 + 0.12 * k))
		"library":   # the plates are two closed books, pages out, with a lit candle stub
			var bk := U.box(a, Vector3(0.46, 0.14, 0.4), _m("book_b" if side > 0 else "book_a"), Vector3(x, 0.36, 0))
			bk.rotation = Vector3(0, side * 0.3, -side * 0.2)
			var pg := U.box(a, Vector3(0.42, 0.1, 0.36), _m("pages"), Vector3(x + side * 0.02, 0.36, 0.0))
			pg.rotation = bk.rotation
			U.cylinder(a, 0.05, 0.2, _m("stem"), Vector3(x - side * 0.05, 0.43, -0.1))
			U.cone(a, 0.04, 0.12, _m("flame_hot"), Vector3(x - side * 0.05, 0.63, -0.1))
		"foundry":   # a brass smokestack on each plate, with an iron cap
			U.cylinder(a, 0.07, 0.42, _m("brass"), Vector3(x + side * 0.05, 0.3, -0.12))
			U.cylinder(a, 0.1, 0.07, _m("iron_dark"), Vector3(x + side * 0.05, 0.72, -0.12))
			for k in 3:
				U.sphere(a, 0.035, _m("steel"), Vector3(x + side * (0.08 * k - 0.08), 0.4, 0.14))
		"abyss":   # a star shard floating above each plate
			var st := U.cone(a, 0.09, 0.4, _m("void_rim"), Vector3(x, 0.45, 0))
			st.rotation = Vector3(0, 0, -side * 0.2)
			var st2 := U.cone(a, 0.09, 0.2, _m("void_rim"), Vector3(x, 0.47, 0))
			st2.rotation = Vector3(PI, 0, -side * 0.2)
		"daily":   # a bronze sun disc with rays
			var d := U.cylinder(a, 0.2, 0.05, _m("bell_gold"), Vector3(x, 0.38, 0))
			d.rotation = Vector3(0.3, 0, -side * 0.25)
			for k in 6:
				var ang := TAU * k / 6.0
				var r := U.cone(a, 0.04, 0.14, _m("bell_gold"), Vector3(x + cos(ang) * 0.22, 0.4, sin(ang) * 0.22))
				r.rotation = Vector3(sin(ang) * 1.4, 0, -cos(ang) * 1.4)


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


## Version 384 (visual review of v383, fix 1): the Skeleton Minion, the most common foe, was
## a bare round skull: from the run camera a crowd of them read as buns. Two dark horn stubs
## curl up and back from the crown, so from above it is a little horned imp's skull.
static func _imp(skel: Skeleton3D) -> void:
	var a := _on(skel, "head")
	if a == null:
		return
	var place := place_key()
	var look: Dictionary = PLACE_LOOK.get(place, PLACE_LOOK[""])
	for side in [-1.0, 1.0]:
		var h := U.cone(a, 0.12, 0.42, _m(look.horn), Vector3.ZERO)
		h.position = Vector3(0.3 * side, 0.86, -0.04)
		h.rotation = Vector3(-0.42, 0.0, -0.62 * side)
		var t := U.cone(a, 0.06, 0.2, _m(look.tip), Vector3.ZERO)
		t.position = Vector3(0.43 * side, 1.08, -0.13)
		t.rotation = Vector3(-0.9, 0.0, -0.95 * side)
	# Version 405 (fix 5): a hat of the place on its crown, between the horns.
	match place:
		"frost":   # three ice spikes
			for k in 3:
				var c := U.cone(a, 0.08, 0.42 - 0.1 * absf(k - 1), _m("ice"), Vector3((k - 1) * 0.14, 0.86, -0.05))
				c.rotation = Vector3(-0.25, 0, -(k - 1) * 0.35)
		"ember":   # a crest of fire
			U.cone(a, 0.16, 0.5, _m("flame"), Vector3(0, 0.84, -0.05))
			U.cone(a, 0.09, 0.36, _m("flame_hot"), Vector3(0, 0.88, 0.0))
		"drowned":
			U.sphere(a, 0.08, _m("barnacle"), Vector3(0.08, 0.92, 0.05))
			var w := U.cylinder(a, 0.035, 0.42, _m("weed"), Vector3(-0.2, 0.55, 0.1))
			w.rotation = Vector3(0.2, 0, -0.3)
		"grotto":   # a little glowing mushroom for a hat
			U.cylinder(a, 0.06, 0.18, _m("stem"), Vector3(0, 0.84, 0))
			var cap := U.sphere(a, 0.34, _m("glowcap"), Vector3(0, 1.04, 0))
			cap.scale = Vector3(1.0, 0.45, 1.0)
			U.sphere(a, 0.06, _m("cap_spot"), Vector3(0.12, 1.16, 0.05))
		"sand":   # a gold band with a lapis stripe and a cobra at the brow
			U.cylinder(a, 0.44, 0.09, _m("bell_gold"), Vector3(0, 0.6, 0))
			U.cylinder(a, 0.45, 0.04, _m("lapis"), Vector3(0, 0.66, 0))
			U.cone(a, 0.06, 0.2, _m("bell_gold"), Vector3(0, 0.66, 0.42))
		"mine":   # a miner's lamp on a strap, a crystal behind
			U.cylinder(a, 0.45, 0.06, _m("leather"), Vector3(0, 0.62, 0))
			U.sphere(a, 0.1, _m("flame_hot"), Vector3(0, 0.68, 0.46))
			var c2 := U.cone(a, 0.09, 0.36, _m("amethyst_pale"), Vector3(0, 0.86, -0.08), 0.02)
			c2.rotation = Vector3(-0.3, 0, 0.15)
		"library":   # a fat candle stuck on its skull
			U.cylinder(a, 0.09, 0.3, _m("stem"), Vector3(0, 0.84, 0))
			U.cone(a, 0.08, 0.22, _m("flame_hot"), Vector3(0, 1.14, 0))
		"foundry":   # a little brass pot hat
			U.cylinder(a, 0.3, 0.22, _m("brass"), Vector3(0, 0.82, 0))
			U.cylinder(a, 0.38, 0.04, _m("steel"), Vector3(0, 0.82, 0))
		"abyss":   # a halo of star points
			for k in 5:
				var ang := TAU * k / 5.0
				var st := U.cone(a, 0.05, 0.22, _m("void_rim"), Vector3(cos(ang) * 0.3, 0.95, sin(ang) * 0.3))
				st.rotation = Vector3(sin(ang) * 0.6, 0, -cos(ang) * 0.6)
		"snow":
			var sn := U.sphere(a, 0.2, _m("snow"), Vector3(0, 0.88, 0))
			sn.scale = Vector3(1.0, 0.45, 1.0)
	FeatHeads.bake(a, "foe imp horns " + place)


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
	# Version 395 (visual review of v388, fix 8): it was a flat blue Warrior. Now it wears a
	# wide mantle of night sky that flares out past its shoulders, ragged at the hem with a
	# pale edge, under two tall wing-points: from above a dark star shape, not a skeleton.
	var c := _on(skel, "chest")
	if c:
		# (Black starry sky, out of its blue overlay: all in blue it was a blob the size and
		# colour of the Rogue's hood.)
		var sky := StarEater._sky_mat()
		U.cone(c, 0.62, 0.56, sky, Vector3(0, -0.3, -0.05), 0.22)
		U.cone(c, 0.7, 0.1, _m("void_rim"), Vector3(0, -0.34, -0.05), 0.6)
		for i in 8:
			var ang := TAU * i / 8.0
			var t := U.cone(c, 0.16, 0.36 if i % 2 == 0 else 0.24, sky, Vector3.ZERO)
			t.position = Vector3(cos(ang) * 0.52, -0.36, sin(ang) * 0.52 - 0.05)
			t.rotation = Vector3(PI - 0.9 * sin(ang), 0, 0.9 * cos(ang))   # points out and down
		for side in [-1.0, 1.0]:
			var w := U.cone(c, 0.17, 0.85, sky, Vector3.ZERO)
			w.position = Vector3(side * 0.44, 0.44, -0.22)
			w.rotation = Vector3(-0.3, 0, -side * 0.55)
			w.scale = Vector3(1.0, 1.0, 0.35)
			var wt := U.cone(c, 0.1, 0.4, _m("void_rim"), Vector3.ZERO)
			wt.position = Vector3(side * 0.72, 0.88, -0.36)
			wt.rotation = Vector3(-0.3, 0, -side * 0.55)
		FeatHeads.bake(c, "foe void mantle")
		for n in c.get_children():
			n.set_meta("fx", true)


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
	# (v395: the weed and barnacles on its skull went; they poked through the diving helmet
	# as dark blotches.)
	var c := _on(skel, "chest")
	if c:
		for side in [-1.0, 1.0]:
			for k in 2:
				var s := U.box(c, Vector3(0.1, 0.55, 0.02), _m("weed" if k == 0 else "weed_dark"), Vector3.ZERO)
				s.position = Vector3(side * (0.3 + 0.08 * k), 0.05, 0.05 - 0.12 * k)
				s.rotation = Vector3(0.1, 0, side * 0.25)
		FeatHeads.bake(c, "foe weed chest")
	# Version 395 (visual review of v388, fix 8): the Drowned was a teal Rogue skeleton with
	# a few weeds. Now it is a drowned diver: a big brass diving helmet with a dark glass
	# port its eyes glow through, and a ship's anchor chained to its back, its arms sticking
	# out past its shoulders. Brass on the dark water, a shape no other skeleton has.
	var hh := _on(skel, "head")
	if hh:
		var dome := U.sphere(hh, 0.52, _m("dive_brass"), Vector3(0, 0.46, 0.0))
		dome.scale = Vector3(1.0, 0.95, 1.0)
		U.cylinder(hh, 0.5, 0.12, _m("dive_brass"), Vector3(0, 0.0, 0))   # the collar on its shoulders
		var port := U.cylinder(hh, 0.27, 0.1, _m("dive_brass"), Vector3.ZERO)
		port.position = Vector3(0, 0.46, 0.47)
		port.rotation.x = PI * 0.5
		var glass := U.cylinder(hh, 0.2, 0.12, _m("dive_dark"), Vector3.ZERO)
		glass.position = Vector3(0, 0.46, 0.48)
		glass.rotation.x = PI * 0.5
		for side in [-1.0, 1.0]:
			var sp := U.cylinder(hh, 0.14, 0.08, _m("dive_dark"), Vector3.ZERO)   # side ports
			sp.position = Vector3(side * 0.49, 0.5, 0.05)
			sp.rotation.z = PI * 0.5
		var tp := U.cylinder(hh, 0.16, 0.08, _m("dive_dark"), Vector3(0, 0.93, 0.0))   # the top port
		tp.name = "TopPort"
		U.cylinder(hh, 0.07, 0.18, _m("dive_brass"), Vector3(0.0, 0.86, -0.3))   # air valve
		for i in 6:
			var ang := TAU * i / 6.0
			U.sphere(hh, 0.045, _m("dive_dark"), Vector3(cos(ang) * 0.48, 0.1, sin(ang) * 0.48))   # bolts
		FeatHeads.bake(hh, "foe dive helmet")
		for n in hh.get_children():
			n.set_meta("fx", true)   # (brass stays brass under the wet overlay)
		for side in [-1.0, 1.0]:
			var eye := U.sphere(hh, 0.055, _m("dive_eye"), Vector3(side * 0.08, 0.47, 0.54))
			eye.set_meta("fx", true)
	var back := _on(skel, "chest")
	if back:
		var an := Node3D.new()
		back.add_child(an)
		an.position = Vector3(0, 0.1, -0.34)
		an.rotation = Vector3(0.3, 0, 0.35)
		U.box(an, Vector3(0.09, 1.1, 0.09), _m("anchor"), Vector3(0, 0.1, 0))   # shank
		U.box(an, Vector3(0.6, 0.08, 0.08), _m("anchor"), Vector3(0, 0.52, 0))   # stock
		for side in [-1.0, 1.0]:   # the two arms curving up to their flukes
			var arm := U.box(an, Vector3(0.42, 0.1, 0.1), _m("anchor"), Vector3(side * 0.19, -0.38, 0))
			arm.rotation.z = side * 0.55
			var fl := U.cone(an, 0.13, 0.26, _m("anchor"), Vector3.ZERO)
			fl.position = Vector3(side * 0.4, -0.16, 0)
			fl.rotation.z = -side * 0.35
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.07
		tm.outer_radius = 0.13
		tm.rings = 10
		tm.ring_segments = 5
		ring.mesh = tm
		ring.material_override = _m("anchor")
		ring.position = Vector3(0, 0.74, 0)
		ring.rotation.x = PI * 0.5
		an.add_child(ring)
		FeatHeads.bake(an, "foe dive anchor")
		for n in an.get_children():
			n.set_meta("fx", true)


## The Cinder Skeleton: tongues of flame standing up along its back and shoulders.
static func _embers(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	# (wider than the skull, which hides anything near the neck from above)
	var spots := [Vector3(-0.5, 0.18, 0.0), Vector3(0.5, 0.18, 0.0), Vector3(-0.42, 0.0, -0.3), Vector3(0.42, 0.0, -0.3), Vector3(0, -0.05, -0.45)]
	var tilt := [Vector3(-0.1, 0, 0.55), Vector3(-0.1, 0, -0.55), Vector3(-0.7, 0, 0.5), Vector3(-0.7, 0, -0.5), Vector3(-1.1, 0, 0)]
	for i in spots.size():
		var h := 0.75 if i < 2 else 0.6
		var f := U.cone(a, 0.17, h, _m("flame"), Vector3.ZERO)
		f.position = spots[i]
		f.rotation = tilt[i]
		var core := U.cone(a, 0.09, h * 0.7, _m("flame_hot"), Vector3.ZERO)
		core.position = spots[i] + Vector3(0, -0.02, 0.05)
		core.rotation = tilt[i]
	FeatHeads.bake(a, "foe embers")
	for c in a.get_children():
		c.set_meta("fx", true)   # (fire: its charring overlay and the hit flash leave it alone)


## The Frost Wraith: a collar of ice spikes on its shoulders, icicles hanging under it.
static func _icicles(model: Node3D, skel: Skeleton3D) -> void:
	var c := _on(skel, "chest")
	if c:
		for side in [-1.0, 1.0]:   # a cluster of ice spikes on each shoulder, past the skull
			for k in 3:
				var s := U.cone(c, 0.13 - 0.02 * k, 0.75 - 0.15 * k, _m("ice" if k != 1 else "ice_deep"), Vector3.ZERO)
				s.position = Vector3(side * (0.5 + 0.06 * k), 0.12, -0.15 + 0.15 * k)
				s.rotation = Vector3(-0.4 + 0.35 * k, 0, -side * (0.7 + 0.15 * k))
		FeatHeads.bake(c, "foe ice collar")
	var h := _on(skel, "hips")
	if h:
		var robe := U.cone(h, 0.42, 0.5, _m("ice_deep"), Vector3(0, -0.5, 0), 0.3)
		robe.name = "Robe"
		for i in 6:
			var ang := TAU * i / 6.0
			var s := U.cone(h, 0.08, 0.38 - 0.1 * (i % 2), _m("ice"), Vector3.ZERO)
			s.position = Vector3(cos(ang) * 0.34, -0.52, sin(ang) * 0.34)
			s.rotation = Vector3(PI, 0, 0)
		FeatHeads.bake(h, "foe icicles")


## The Sporeling: little red-capped mushrooms sprouting from its shoulders and back.
static func _sprouts(skel: Skeleton3D) -> void:
	var a := _on(skel, "chest")
	if a == null:
		return
	var spots := [Vector3(-0.46, 0.05, 0.0), Vector3(0.48, 0.0, -0.08), Vector3(0.1, -0.1, -0.42), Vector3(-0.3, -0.2, -0.36)]
	var size := [1.5, 1.2, 1.35, 1.0]
	for i in spots.size():
		var k: float = size[i]
		var base: Vector3 = spots[i]
		U.cylinder(a, 0.04 * k, 0.22 * k, _m("stem"), base)
		var cap := U.sphere(a, 0.16 * k, _m("cap_red"), base + Vector3(0, 0.24 * k, 0))
		cap.scale = Vector3(1.0, 0.6, 1.0)
		U.sphere(a, 0.035 * k, _m("cap_spot"), base + Vector3(0.06 * k, 0.32 * k, 0.04 * k))
	FeatHeads.bake(a, "foe sprouts")
	var h := _on(skel, "head")   # and a ring of little ones round its big cap, seen from above
	if h:
		for i in 4:
			var ang := PI * (0.15 + 0.7 * i / 3.0)
			var base := Vector3(cos(ang) * 0.5, 0.55, -sin(ang) * 0.42)
			var k := 1.1 - 0.15 * (i % 2)
			U.cylinder(h, 0.04 * k, 0.24 * k, _m("stem"), base)
			var cap := U.sphere(h, 0.17 * k, _m("cap_red"), base + Vector3(0, 0.26 * k, 0))
			cap.scale = Vector3(1.0, 0.6, 1.0)
		FeatHeads.bake(h, "foe sprouts head")


## The Rootbinder: no legs; a trunk of bark from its hips to the floor and roots spreading
## out over it (they show from above), moss on them.
static func _roots(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"])
	var a := _on(skel, "hips")
	if a == null:
		return
	U.cone(a, 0.36, 0.5, _m("bark"), Vector3(0, -0.45, 0), 0.24)
	for i in 6:
		var ang := TAU * i / 6.0 + 0.3
		var r := U.cone(a, 0.19, 1.0, _m("bark" if i % 2 == 0 else "bark_moss"), Vector3.ZERO)
		r.position = Vector3(cos(ang) * 0.62, -0.38, sin(ang) * 0.62)
		r.rotation = Vector3(0, -ang, 0)
		r.rotate_object_local(Vector3.FORWARD, PI * 0.5 - 0.25)   # lying out along the floor, pointing away
	FeatHeads.bake(a, "foe roots")
	# Version 395 (visual review of v388, fix 8): it was a murky green skeleton. Now it has a
	# stag's antlers of pale branches with bright leaves at their ends, and a mossy log
	# across its shoulders: a walking tree from above, bright on the dark Grotto floor.
	var h := _on(skel, "head")
	if h:
		for side in [-1.0, 1.0]:
			var root := Vector3(side * 0.28, 0.72, -0.05)
			var d1 := Vector3(side * 0.75, 0.66, -0.1).normalized()
			OutfitShapes._ray(h, 0.085, 0.75, _m("bark_light"), root, d1, 0.05)
			var mid := root + d1 * 0.4
			var end := root + d1 * 0.75
			OutfitShapes._ray(h, 0.06, 0.42, _m("bark_light"), mid, Vector3(side * 0.2, 0.9, 0.35), 0.03)
			OutfitShapes._ray(h, 0.055, 0.36, _m("bark_light"), end, Vector3(side * 0.9, 0.3, -0.35), 0.03)
			for q: Array in [[end + Vector3(side * 0.34, 0.14, -0.13), 0.2], [mid + Vector3(side * 0.09, 0.42, 0.16), 0.17], [end + Vector3(0, 0.1, 0), 0.15]]:
				var lf := U.sphere(h, q[1], _m("leaf" if q[1] > 0.16 else "leaf_pale"), q[0])
				lf.scale = Vector3(1.4, 0.34, 1.0)   # (flat, like leaves: round they were lollipops)
				lf.rotation = Vector3(0.3 * side, 0.8 * q[1] * 10.0, 0.25 * side)
		FeatHeads.bake(h, "foe root antlers")
		for n in h.get_children():
			n.set_meta("fx", true)   # (the leaves stay bright under the fungal overlay)
	var c := _on(skel, "chest")
	if c:
		var lg := U.cylinder(c, 0.17, 1.15, _m("bark_light"), Vector3.ZERO)
		lg.position = Vector3(0, 0.3, -0.2)
		lg.rotation.z = PI * 0.5
		for side in [-1.0, 1.0]:
			var cap := U.cylinder(c, 0.14, 0.02, _m("leaf_pale"), Vector3.ZERO)
			cap.position = Vector3(side * 0.58, 0.3, -0.2)
			cap.rotation.z = PI * 0.5
			var ms := U.sphere(c, 0.16, _m("leaf"), Vector3(side * 0.28, 0.44, -0.2))
			ms.scale = Vector3(1.3, 0.5, 1.0)
		FeatHeads.bake(c, "foe root log")
		for n in c.get_children():
			n.set_meta("fx", true)


## Version 347 (part 5, the event foes).
## The Moon Howler: a wolf's tall ears on its skull, a red mane bristling on its shoulders
## and a bushy tail behind it.
static func _howl(skel: Skeleton3D) -> void:
	var h := _on(skel, "head")
	if h:
		for side in [-1.0, 1.0]:
			var e := U.cone(h, 0.17, 0.62, _m("fur_dark"), Vector3(side * 0.3, 0.78, -0.05))
			e.rotation = Vector3(-0.2, 0, -side * 0.35)
			var inner := U.cone(h, 0.09, 0.45, _m("fur_red"), Vector3(side * 0.3, 0.8, 0.04))
			inner.rotation = Vector3(-0.2, 0, -side * 0.35)
		FeatHeads.bake(h, "foe howl ears")
	var c := _on(skel, "chest")
	if c:
		var spots := [Vector3(-0.48, 0.15, -0.05), Vector3(0.48, 0.15, -0.05), Vector3(-0.32, 0.12, -0.32), Vector3(0.32, 0.12, -0.32), Vector3(0.0, 0.05, -0.45)]
		var tilt := [Vector3(-0.5, 0, 0.6), Vector3(-0.5, 0, -0.6), Vector3(-0.9, 0, 0.4), Vector3(-0.9, 0, -0.4), Vector3(-1.1, 0, 0)]
		for i in spots.size():
			for k in 2:
				var m := U.cone(c, 0.15 - 0.05 * k, 0.6 - 0.15 * k, _m("fur_dark" if k == 0 else "fur_red"), spots[i] + Vector3(0, 0.02 * k, 0.04 * k))
				m.rotation = tilt[i]
		FeatHeads.bake(c, "foe howl mane")
	var hp := _on(skel, "hips")
	if hp:
		var t := U.cone(hp, 0.27, 0.85, _m("fur_dark"), Vector3(0, 0.05, -0.2))
		t.rotation = Vector3(-1.05, 0, 0)
		var tip := U.cone(hp, 0.17, 0.35, _m("fur_red"), Vector3(0, 0.45, -0.88))
		tip.rotation = Vector3(-1.05, 0, 0)
		FeatHeads.bake(hp, "foe howl tail")


## The Bell Ringer: a wooden yoke across its shoulders, a gold bell hanging from each end.
static func _yoke(skel: Skeleton3D) -> void:
	var c := _on(skel, "chest")
	if c == null:
		return
	# (high and wide, so it shows past the hood from above)
	U.box(c, Vector3(2.0, 0.1, 0.12), _m("wood"), Vector3(0, 0.5, -0.22))
	for side in [-1.0, 1.0]:
		var x: float = side * 0.92
		U.cylinder(c, 0.025, 0.2, _m("wood"), Vector3(x, 0.32, -0.22))
		U.cone(c, 0.27, 0.36, _m("bell_gold"), Vector3(x, -0.06, -0.22), 0.1)
		U.cylinder(c, 0.29, 0.05, _m("bell_gold"), Vector3(x, -0.08, -0.22))
		U.sphere(c, 0.08, _m("iron_light"), Vector3(x, -0.12, -0.22))
		U.sphere(c, 0.09, _m("bell_gold"), Vector3(x, 0.32, -0.22))
		U.box(c, Vector3(0.16, 0.16, 0.16), _m("bell_gold"), Vector3(x * 0.98, 0.5, -0.22))
	FeatHeads.bake(c, "foe yoke")


## The Snow Roller: drifts of snow heaped on its broad shoulders and helmet.
static func _snowpack(skel: Skeleton3D) -> void:
	var c := _on(skel, "chest")
	if c:
		for side in [-1.0, 1.0]:
			var a := U.sphere(c, 0.3, _m("snow"), Vector3(side * 0.52, 0.2, -0.02))
			a.scale = Vector3(1.0, 0.75, 1.0)
			var b := U.sphere(c, 0.2, _m("snow"), Vector3(side * 0.6, 0.34, -0.15))
			b.scale = Vector3(1.0, 0.8, 1.0)
			U.sphere(c, 0.17, _m("snow"), Vector3(side * 0.38, 0.28, -0.25))
			for k in 3:   # icicles hanging off the drift
				var ic := U.cone(c, 0.05, 0.24 - 0.05 * (k % 2), _m("ice"), Vector3(side * (0.4 + 0.13 * k), 0.02, 0.18))
				ic.rotation = Vector3(PI, 0, 0)
		FeatHeads.bake(c, "foe snowpack")
	var h := _on(skel, "head")
	if h:
		var cap := U.sphere(h, 0.34, _m("snow"), Vector3(0.05, 0.9, -0.05))
		cap.scale = Vector3(1.15, 0.5, 1.0)
		U.sphere(h, 0.18, _m("snow"), Vector3(-0.12, 1.02, 0.02))
		FeatHeads.bake(h, "foe snowcap")


## The Gift Thief: long pointed imp's ears sticking out sideways from under its cap.
static func _ears(skel: Skeleton3D) -> void:
	var h := _on(skel, "head")
	if h == null:
		return
	for side in [-1.0, 1.0]:
		var e := U.cone(h, 0.17, 0.85, _m("bone"), Vector3(side * 0.45, 0.45, -0.05))
		e.rotation = Vector3(-0.2, 0, -side * 0.8)
		var inner := U.cone(h, 0.1, 0.6, _m("cap_red"), Vector3(side * 0.47, 0.47, 0.03))
		inner.rotation = Vector3(-0.2, 0, -side * 0.8)
	FeatHeads.bake(h, "foe ears")


## The Queen's Shade: no legs, a long dark red gown trailing ragged tails, and the Queen's
## high fan collar of spikes behind its skull.
static func _shade(model: Node3D, skel: Skeleton3D) -> void:
	Art.hide_parts(model, ["Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"])
	var hp := _on(skel, "hips")
	if hp:
		U.cone(hp, 0.55, 0.7, _m("shade"), Vector3(0, -0.68, 0), 0.3)
		U.cone(hp, 0.58, 0.06, _m("shade_rim"), Vector3(0, -0.7, 0), 0.56)
		for i in 8:
			var ang := TAU * i / 8.0
			var t := U.cone(hp, 0.13, 0.36 - 0.1 * (i % 2), _m("shade"), Vector3.ZERO)
			t.position = Vector3(cos(ang) * 0.46, -0.72, sin(ang) * 0.46)
			t.rotation = Vector3(PI, 0, 0)
		FeatHeads.bake(hp, "foe shade gown")
	var c := _on(skel, "chest")
	if c:
		for i in 7:
			var f := (i - 3) / 3.0
			var ang := f * 1.25
			var base := Vector3(sin(ang) * 0.42, 0.25, -cos(ang) * 0.25 - 0.08)
			var s := U.cone(c, 0.11, 0.85 - absf(f) * 0.25, _m("shade"), base)
			s.rotation = Vector3(-0.35, 0, -f * 0.9)
			var r := U.cone(c, 0.05, 0.7 - absf(f) * 0.2, _m("shade_rim"), base + Vector3(0, 0.03, -0.03))
			r.rotation = Vector3(-0.35, 0, -f * 0.9)
		FeatHeads.bake(c, "foe shade collar")
		for n in c.get_children():
			n.set_meta("fx", true)


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
