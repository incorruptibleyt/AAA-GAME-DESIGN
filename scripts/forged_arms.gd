class_name ForgedArms
## Version 228-229 (Jesse: "the mage weapons ... aren't they just reskins?"): they were, and
## so was every hero's Frostforged, Emberforged, Gilded and Voidsteel weapon: a weapon the
## hero already had, in a new colour (the LookFx.weapon finish). Each now has its own shape on
## top of its finish:
## - Mage: an ice crystal crown staff, a burning tome, a sun staff, a void scythe (v228).
## - Knight: an ice-cased sword with a frost-spiked shield, a burning greatsword, a gold
##   winged greatsword with a halo, a rift greatsword with shards circling the blade.
## - Rogue: a crossbow with ice limbs and an ice bolt, burning knives, a gold winged
##   crossbow, a void crossbow with a portal ring at its front.
## - Barbarian: ice-edged twin axes, a burning great axe, a great axe with gold ram's horns,
##   a moon axe with two crescent blades.
## Built in the weapon mesh's own space, so the shapes scale with the weapon in a run.

static var _mats := {}
## Which finish gives which shape, per weapon part (the weapon mesh's name in the hero model).
const SHAPES := {
	"2H_Staff": {"frost": "ice_staff", "gold": "sun_staff", "void": "scythe"},
	"Spellbook_open": {"ember": "fire_tome"},
	"1H_Sword": {"frost": "ice_sword"},
	"Badge_Shield": {"frost": "ice_shield"},
	"2H_Sword": {"ember": "flame_sword", "gold": "halo_sword", "void": "rift_sword"},
	"2H_Crossbow": {"frost": "ice_bow", "gold": "wing_bow", "void": "ring_bow"},
	"Knife": {"ember": "flame_knife"},
	"Knife_Offhand": {"ember": "flame_knife", "gold": "wing_knife", "void": "void_knife"},
	"1H_Axe": {"frost": "ice_axe"},
	"1H_Axe_Offhand": {"frost": "ice_axe"},
	"2H_Axe": {"ember": "flame_axe", "gold": "horn_axe", "void": "moon_axe"},
}


## Puts the shape for `finish` on weapon `mi`, or takes an old one off.
static func dress(mi: MeshInstance3D, finish: String) -> void:
	var want: String = SHAPES.get(str(mi.name), {}).get(finish, "")
	var old := mi.get_node_or_null("ForgedArms")
	if old:
		if str(old.get_meta("shape", "")) == want:
			return
		mi.remove_child(old)
		old.queue_free()
	if want == "":
		return
	var root := Node3D.new()
	root.name = "ForgedArms"
	root.set_meta("shape", want)
	mi.add_child(root)
	match want:
		"ice_staff":
			_ice(root)
		"sun_staff":
			_sun(root)
		"scythe":
			_scythe(root)
		"fire_tome":
			_fire(root)
		"ice_sword":
			_ice_sword(root)
		"ice_shield":
			_ice_shield(root)
		"flame_sword":
			_flame_sword(root)
		"halo_sword":
			_halo_sword(root)
		"rift_sword":
			_rift_sword(root)
		"ice_bow":
			_ice_bow(root)
		"wing_bow":
			_wing_bow(root)
		"ring_bow":
			_ring_bow(root)
		"flame_knife":
			_flame_knife(root)
		"wing_knife":
			_wing_knife(root)
		"void_knife":
			_void_knife(root)
		"ice_axe":
			_ice_axe(root)
		"flame_axe":
			_flame_axe(root)
		"horn_axe":
			_horn_axe(root)
		"moon_axe":
			_moon_axe(root)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.set_meta("fx", true)   # (the hit flash would turn them white)


# ---------------------------------------------------------------- Mage

const HEAD := Vector3(0, 1.12, 0)


## A crown of ice: one tall crystal, five leaning out round it, three shards circling.
static func _ice(root: Node3D) -> void:
	var ice := _mat("ice")
	var still := Node3D.new()
	still.name = "Still"
	root.add_child(still)
	_crystal(still, HEAD + Vector3(0, 0.05, 0), Vector3.UP, 0.17, 1.05, ice)
	for i in 5:
		var a := i / 5.0 * TAU + 0.3
		var out := Vector3(sin(a), 0, cos(a))
		var dir := (out * 0.8 + Vector3(0, 1, 0)).normalized()
		_crystal(still, HEAD + out * 0.12 - Vector3(0, 0.04, 0), dir, 0.1, 0.55 + 0.18 * float(i % 2), ice)
	FeatHeads.bake(still, "forged ice_staff")
	var ring := Spin.new()
	ring.speed = 1.7
	ring.position = HEAD + Vector3(0, 0.12, 0)
	root.add_child(ring)
	for i in 3:
		var a := i / 3.0 * TAU
		_crystal(ring, Vector3(sin(a), 0, cos(a)) * 0.58, Vector3(0, 1, 0), 0.07, 0.34, ice)
	_glow(root, HEAD + Vector3(0, 0.3, 0), 0.6, Color(0.35, 0.85, 1.0, 0.3))


## A sun staff: a white-hot orb in a gold ring with twelve rays, turning slowly.
static func _sun(root: Node3D) -> void:
	var gold := _mat("gold")
	var wheel := Spin.new()
	wheel.speed = 0.7
	wheel.position = HEAD
	root.add_child(wheel)
	var band := TorusMesh.new()
	band.inner_radius = 0.27
	band.outer_radius = 0.35
	band.rings = 24
	band.ring_segments = 6
	_part(wheel, band, gold, Vector3.ZERO)
	for i in 12:
		var a := i / 12.0 * TAU
		var out := Vector3(sin(a), 0, cos(a))
		var long := i % 2 == 0
		_cone(wheel, out * 0.34, out, 0.075 if long else 0.055, 0.34 if long else 0.2, gold)
	FeatHeads.bake(wheel, "forged sun_staff")
	var core := SphereMesh.new()
	core.radius = 0.17
	core.height = 0.34
	core.radial_segments = 12
	core.rings = 6
	_part(root, core, _mat("sun core"), HEAD)
	_glow(root, HEAD, 0.55, Color(1.0, 0.75, 0.25, 0.3))


## A void scythe: a long curved blade sweeping out and down from the head, a black orb where
## it meets the staff, and two violet motes circling the orb.
static func _scythe(root: Node3D) -> void:
	var blade := MeshInstance3D.new()
	blade.mesh = _crescent("scythe", Vector2(0.05, 1.12), 0.78, 0.15, 2.2, 0.3, 0.35, false, false)
	blade.material_override = _mat("void blade")
	root.add_child(blade)
	var edge := MeshInstance3D.new()
	edge.mesh = _crescent("scythe", Vector2(0.05, 1.12), 0.78, 0.15, 2.2, 0.3, 0.35, true, false)
	edge.material_override = _mat("void edge")
	root.add_child(edge)
	var orb := SphereMesh.new()
	orb.radius = 0.15
	orb.height = 0.3
	orb.radial_segments = 12
	orb.rings = 6
	_part(root, orb, _mat("void orb"), HEAD + Vector3(0, 0.08, 0))
	_glow(root, HEAD + Vector3(0, 0.08, 0), 0.34, Color(0.6, 0.25, 1.0, 0.4))
	var motes := Spin.new()
	motes.speed = -2.2
	motes.position = HEAD + Vector3(0, 0.08, 0)
	root.add_child(motes)
	for i in 2:
		var a := i * PI
		var m := SphereMesh.new()
		m.radius = 0.05
		m.height = 0.1
		m.radial_segments = 8
		m.rings = 4
		_part(motes, m, _mat("void mote"), Vector3(sin(a), 0.1 * (1 - 2 * i), cos(a)) * 0.3)


## The burning tome: three flames rising off the top of the open book and four embers
## circling them. The fire always rises straight up in the world, however the hand swings.
static func _fire(root: Node3D) -> void:
	# (The open book stands about 0.83 wide and 0.57 tall in its x-y plane, its pages facing
	# +z; the fire sits on its top edge.)
	var top := Vector3(0, 0.24, 0.03)
	var up := Upright.new()
	up.position = top
	root.add_child(up)
	for f: Array in [[Vector3(0, 0, 0), 0.2, 0.85], [Vector3(-0.24, 0, 0.02), 0.14, 0.55], [Vector3(0.24, 0, -0.02), 0.14, 0.62]]:
		_flame(up, f[0], f[1], f[2])
	_embers(up, Vector3(0, 0.45, 0), 4, 0.42, 0.08)
	_glow(up, Vector3(0, 0.3, 0), 0.42, Color(1.0, 0.5, 0.12, 0.26))


# ---------------------------------------------------------------- Knight
# 1H_Sword: blade up +y to 1.41, guard about 0.5 wide. Badge_Shield: 0.88 wide, 1.02 tall,
# its face toward +z. 2H_Sword: guard at y 0.3 (0.84 wide), blade to 1.96 about 0.28 wide.

## Frostforged sword: the blade cased in a long ice crystal, shards jutting off its edges.
static func _ice_sword(root: Node3D) -> void:
	var ice := _mat("ice")
	var still := Node3D.new()
	root.add_child(still)
	_crystal(still, Vector3(0, 0.12, 0), Vector3.UP, 0.15, 1.55, ice)
	for i in 3:
		for sd: float in [-1.0, 1.0]:
			_crystal(still, Vector3(sd * 0.07, 0.42 + i * 0.3, 0), Vector3(sd, 1.0, 0), 0.065, 0.36 - i * 0.06, ice)
	for sd: float in [-1.0, 1.0]:
		_crystal(still, Vector3(sd * 0.18, 0.04, 0), Vector3(sd, 0.35, 0), 0.07, 0.34, ice)
	FeatHeads.bake(still, "forged ice_sword")
	_glow(root, Vector3(0, 0.85, 0), 0.4, Color(0.35, 0.85, 1.0, 0.22))


## Frostforged shield: a ring of ice spikes round the rim like a snowflake and a crystal boss.
static func _ice_shield(root: Node3D) -> void:
	var ice := _mat("ice")
	var still := Node3D.new()
	root.add_child(still)
	var c := Vector3(0, -0.03, 0.02)
	for i in 10:
		var a := i / 10.0 * TAU
		var d := Vector3(sin(a), cos(a), 0)
		_crystal(still, c + Vector3(d.x * 0.38, d.y * 0.44, 0), d + Vector3(0, 0, 0.2), 0.075, 0.42 if i % 2 == 0 else 0.26, ice)
	_crystal(still, c + Vector3(0, 0, 0.06), Vector3(0, 0, 1), 0.15, 0.42, ice)
	FeatHeads.bake(still, "forged ice_shield")
	_glow(root, c + Vector3(0, 0, 0.12), 0.45, Color(0.35, 0.85, 1.0, 0.22))


## Emberforged greatsword: the blade burns, four flames rising off it whichever way it points.
static func _flame_sword(root: Node3D) -> void:
	for k in 4:
		var up := Upright.new()
		up.position = Vector3(0, 0.62 + k * 0.38, 0)
		root.add_child(up)
		_flame(up, Vector3.ZERO, 0.17, 0.62 - k * 0.06)
	var top := Upright.new()
	top.position = Vector3(0, 1.85, 0)
	root.add_child(top)
	_embers(top, Vector3(0, 0.2, 0), 4, 0.32, 0.07)
	_glow(root, Vector3(0, 1.25, 0), 0.55, Color(1.0, 0.5, 0.12, 0.22))


## Gilded greatsword: gold wings sweeping back from the guard (a paladin's winged hilt), a gold
## halo turning round the blade and a white-hot gem in the guard.
static func _halo_sword(root: Node3D) -> void:
	var gold := _mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	for sd: float in [-1.0, 1.0]:
		for k in 5:
			var ang := deg_to_rad(8.0 - k * 22.0)
			_feather(still, Vector3(sd * 0.3, 0.3, 0), Vector3(sd * cos(ang), sin(ang), 0), 0.98 - k * 0.1, 0.19, gold)
	FeatHeads.bake(still, "forged halo_sword")
	var halo := Spin.new()
	halo.speed = 1.2
	halo.position = Vector3(0, 1.35, 0)
	halo.rotation = Vector3(0.3, 0, 0.25)
	root.add_child(halo)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.36
	ring.outer_radius = 0.45
	ring.rings = 28
	ring.ring_segments = 6
	_part(halo, ring, gold, Vector3.ZERO)
	for i in 4:
		var a := i / 4.0 * TAU
		_crystal(halo, Vector3(sin(a), 0, cos(a)) * 0.405 - Vector3(0, 0.08, 0), Vector3.UP, 0.055, 0.18, _mat("sun core"))
	var gem := SphereMesh.new()
	gem.radius = 0.12
	gem.height = 0.24
	gem.radial_segments = 10
	gem.rings = 5
	_part(root, gem, _mat("sun core"), Vector3(0, 0.3, 0.05))
	_glow(root, Vector3(0, 1.35, 0), 0.5, Color(1.0, 0.75, 0.25, 0.2))


## Voidsteel greatsword: violet light along both edges, six shards circling the blade at three
## heights (each ring turning its own way) and a black star at the tip.
static func _rift_sword(root: Node3D) -> void:
	for sd: float in [-1.0, 1.0]:
		var strip := BoxMesh.new()
		strip.size = Vector3(0.035, 1.2, 0.07)
		_part(root, strip, _mat("void edge"), Vector3(sd * 0.135, 1.05, 0))
	for k in 3:
		var ring := Spin.new()
		ring.speed = 1.6 if k % 2 == 0 else -1.9
		ring.position = Vector3(0, 0.72 + k * 0.42, 0)
		root.add_child(ring)
		for j in 2:
			var a := j * PI + k * 0.9
			var out := Vector3(sin(a), 0, cos(a))
			_crystal(ring, out * 0.36 - Vector3(0, 0.15, 0), Vector3.UP + out * 0.25, 0.07, 0.38, _mat("void shard"))
	_orb(root, Vector3(0, 2.06, 0), 0.13)


# ---------------------------------------------------------------- Rogue
# 2H_Crossbow: the stock runs along +z (front at 1.16), the limbs reach x 0.61 near z 0.85,
# and the Rogue holds it pointing at the floor, so shapes rise along +y. Knife(_Offhand):
# blade up +y to 0.98.

## Frostforged crossbow: ice limbs reaching far past the bow's own, an ice-shard bolt and
## frost spikes along the stock.
static func _ice_bow(root: Node3D) -> void:
	var ice := _mat("ice")
	var still := Node3D.new()
	root.add_child(still)
	for sd: float in [-1.0, 1.0]:
		_crystal(still, Vector3(sd * 0.5, 0.06, 0.84), Vector3(sd, 0.35, -0.45), 0.1, 0.62, ice)
		_crystal(still, Vector3(sd * 0.5, 0.06, 0.84), Vector3(sd * 0.4, 1.0, -0.2), 0.07, 0.36, ice)
	_crystal(still, Vector3(0, 0.3, -0.05), Vector3(0, 0.05, 1), 0.075, 1.45, ice)
	for i in 3:
		_crystal(still, Vector3(0, 0.27, 0.15 + i * 0.25), Vector3(0, 1, -0.25), 0.055, 0.26 - i * 0.04, ice)
	FeatHeads.bake(still, "forged ice_bow")
	_glow(root, Vector3(0, 0.25, 0.7), 0.5, Color(0.35, 0.85, 1.0, 0.22))


## Gilded crossbow: gold wings spread from both limbs and a white-hot gem at the grip.
static func _wing_bow(root: Node3D) -> void:
	var gold := _mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	for sd: float in [-1.0, 1.0]:
		for k in 5:
			var ang := deg_to_rad(8.0 + k * 19.0)
			var d := Vector3(sd * cos(ang), sin(ang), -0.3)
			_feather(still, Vector3(sd * 0.45, 0.08, 0.82), d, 0.62 - k * 0.08, 0.15, gold)
	FeatHeads.bake(still, "forged wing_bow")
	var gem := SphereMesh.new()
	gem.radius = 0.1
	gem.height = 0.2
	gem.radial_segments = 10
	gem.rings = 5
	_part(root, gem, _mat("sun core"), Vector3(0, 0.3, 0.2))
	_glow(root, Vector3(0, 0.35, 0.6), 0.5, Color(1.0, 0.75, 0.25, 0.2))


## Voidsteel crossbow: a violet portal ring stands at its front for the bolts to fly through,
## motes circling it, and a black star loaded on the stock.
static func _ring_bow(root: Node3D) -> void:
	var gate := Spin.new()
	gate.axis = Vector3(0, 0, 1)
	gate.speed = 1.5
	gate.position = Vector3(0, 0.12, 1.12)
	root.add_child(gate)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.37
	ring.rings = 28
	ring.ring_segments = 6
	var r := _part(gate, ring, _mat("void edge"), Vector3.ZERO)
	r.rotation = Vector3(PI / 2, 0, 0)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.31
	disc.bottom_radius = 0.31
	disc.height = 0.02
	disc.radial_segments = 20
	var d := _part(gate, disc, _mat("void veil"), Vector3.ZERO)
	d.rotation = Vector3(PI / 2, 0, 0)
	for i in 3:
		var a := i / 3.0 * TAU
		var m := SphereMesh.new()
		m.radius = 0.055
		m.height = 0.11
		m.radial_segments = 8
		m.rings = 4
		_part(gate, m, _mat("void mote"), Vector3(sin(a), cos(a), 0) * 0.5)
	_orb(root, Vector3(0, 0.32, 0.4), 0.11)


## Emberforged knife: the blade burns, two flames rising off it and embers at the tip.
static func _flame_knife(root: Node3D) -> void:
	for k in 2:
		var up := Upright.new()
		up.position = Vector3(0, 0.42 + k * 0.36, 0)
		root.add_child(up)
		_flame(up, Vector3.ZERO, 0.12, 0.46 - k * 0.08)
	var top := Upright.new()
	top.position = Vector3(0, 0.95, 0)
	root.add_child(top)
	_embers(top, Vector3(0, 0.12, 0), 3, 0.22, 0.06)
	_glow(root, Vector3(0, 0.7, 0), 0.32, Color(1.0, 0.5, 0.12, 0.22))


## The Gilded off-hand knife: small gold wings at its guard.
static func _wing_knife(root: Node3D) -> void:
	var still := Node3D.new()
	root.add_child(still)
	for sd: float in [-1.0, 1.0]:
		for k in 3:
			var ang := deg_to_rad(15.0 + k * 22.0)
			_feather(still, Vector3(sd * 0.05, 0.03, 0), Vector3(sd * cos(ang), sin(ang), 0), 0.36 - k * 0.06, 0.09, _mat("gold"))
	FeatHeads.bake(still, "forged wing_knife")


## The Voidsteel off-hand knife: a black star at its pommel with motes circling it.
static func _void_knife(root: Node3D) -> void:
	_orb(root, Vector3(0, -0.2, 0), 0.08)


# ---------------------------------------------------------------- Barbarian
# 1H_Axe(_Offhand): handle up +y to 0.97, the blade out to x -0.59 near the top.
# 2H_Axe: two blades out to x 0.62 between y 0.72 and 1.29.

## Frostforged axe: ice crystals growing out of the blade's edge and a spike on top.
static func _ice_axe(root: Node3D) -> void:
	var ice := _mat("ice")
	var still := Node3D.new()
	root.add_child(still)
	for i in 4:
		var y := 0.56 + i * 0.13
		_crystal(still, Vector3(-0.5, y, 0), Vector3(-1, (i - 1.5) * 0.4, 0), 0.075, 0.34 if i == 1 or i == 2 else 0.26, ice)
	_crystal(still, Vector3(-0.08, 0.9, 0), Vector3(0.15, 1, 0), 0.07, 0.42, ice)
	_crystal(still, Vector3(0.06, 0.76, 0), Vector3(1, 0.4, 0), 0.06, 0.3, ice)
	FeatHeads.bake(still, "forged ice_axe")
	_glow(root, Vector3(-0.45, 0.78, 0), 0.38, Color(0.35, 0.85, 1.0, 0.22))


## Emberforged great axe: both blades burn and fire rises off the top of the head.
static func _flame_axe(root: Node3D) -> void:
	for f: Array in [[Vector3(-0.42, 1.12, 0), 0.15, 0.45], [Vector3(0, 1.28, 0), 0.18, 0.6], [Vector3(0.42, 1.12, 0), 0.15, 0.45]]:
		var up := Upright.new()
		up.position = f[0]
		root.add_child(up)
		_flame(up, Vector3.ZERO, f[1], f[2])
	var core := SphereMesh.new()
	core.radius = 0.13
	core.height = 0.26
	core.radial_segments = 10
	core.rings = 5
	_part(root, core, _mat("flame core"), Vector3(0, 0.98, 0.06))
	var top := Upright.new()
	top.position = Vector3(0, 1.3, 0)
	root.add_child(top)
	_embers(top, Vector3(0, 0.35, 0), 4, 0.42, 0.08)
	_glow(root, Vector3(0, 1.15, 0), 0.55, Color(1.0, 0.5, 0.12, 0.22))


## Gilded great axe: a ram's two curled gold horns over the head and a white-hot gem.
static func _horn_axe(root: Node3D) -> void:
	var gold := _mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	for sd: float in [-1.0, 1.0]:
		var pts := []
		var n := 16
		for i in n + 1:
			var t := i / float(n)
			var th := t * PI * 1.55
			var rr := 0.36 * (1.0 - 0.55 * t)
			pts.append(Vector3(sd * (0.46 - rr * cos(th)), 1.16 + rr * sin(th), 0.08 + 0.1 * t))
		for i in n:
			var t := i / float(n)
			_rod(still, pts[i], pts[i + 1], lerpf(0.11, 0.04, t), lerpf(0.11, 0.04, t + 1.0 / n), gold)
	FeatHeads.bake(still, "forged horn_axe")
	var gem := SphereMesh.new()
	gem.radius = 0.12
	gem.height = 0.24
	gem.radial_segments = 10
	gem.rings = 5
	_part(root, gem, _mat("sun core"), Vector3(0, 1.0, 0.08))
	_glow(root, Vector3(0, 1.1, 0), 0.55, Color(1.0, 0.75, 0.25, 0.2))


## Voidsteel great axe: two great crescent blades like a split moon, a black star between.
static func _moon_axe(root: Node3D) -> void:
	for flip: bool in [false, true]:
		var blade := MeshInstance3D.new()
		blade.mesh = _crescent("moon", Vector2(0.27, 1.0), 0.7, 0.55, 2.59, 0.34, 0.0, false, flip)
		blade.material_override = _mat("void blade")
		root.add_child(blade)
		var edge := MeshInstance3D.new()
		edge.mesh = _crescent("moon", Vector2(0.27, 1.0), 0.7, 0.55, 2.59, 0.34, 0.0, true, flip)
		edge.material_override = _mat("void edge")
		root.add_child(edge)
	_orb(root, Vector3(0, 1.02, 0.08), 0.14)


# ---------------------------------------------------------------- parts

## A licking flame (a cone and a bright core) standing at `at` in an upright node.
static func _flame(root: Node3D, at: Vector3, r: float, h: float) -> void:
	var fl := Lick.new()
	fl.position = at
	root.add_child(fl)
	_cone(fl, Vector3.ZERO, Vector3.UP, r, h, _mat("flame"))
	_cone(fl, Vector3(0, 0.02, 0), Vector3.UP, r * 0.55, h * 0.7, _mat("flame core"))


## `n` embers circling at `at`.
static func _embers(root: Node3D, at: Vector3, n: int, radius: float, size: float) -> void:
	var spin := Spin.new()
	spin.speed = 2.0
	spin.position = at
	root.add_child(spin)
	for i in n:
		var a := i / float(n) * TAU
		var e := BoxMesh.new()
		e.size = Vector3(size, size, size)
		_part(spin, e, _mat("flame core"), Vector3(sin(a), 0.12 * sin(a * 2.0), cos(a)) * radius)


## A black void orb with a violet glow and two motes circling it.
static func _orb(root: Node3D, at: Vector3, r: float) -> void:
	var orb := SphereMesh.new()
	orb.radius = r
	orb.height = r * 2.0
	orb.radial_segments = 12
	orb.rings = 6
	_part(root, orb, _mat("void orb"), at)
	_glow(root, at, r * 2.3, Color(0.6, 0.25, 1.0, 0.4))
	var motes := Spin.new()
	motes.speed = -2.2
	motes.position = at
	root.add_child(motes)
	for i in 2:
		var a := i * PI
		var m := SphereMesh.new()
		m.radius = r * 0.35
		m.height = r * 0.7
		m.radial_segments = 8
		m.rings = 4
		_part(motes, m, _mat("void mote"), Vector3(sin(a), 0.1 * (1 - 2 * i), cos(a)) * r * 2.0)


## A feather (a flat oval) from `at` along `dir`, lying in the plane facing `flat`.
static func _feather(root: Node3D, at: Vector3, dir: Vector3, length: float, w: float, mat: Material, flat := Vector3(0, 0, 1)) -> void:
	var y := dir.normalized()
	var x := y.cross(flat).normalized()
	var z := x.cross(y).normalized()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 10
	s.rings = 5
	var mi := _part(root, s, mat, at + y * length * 0.5)
	mi.basis = Basis(x * w, y * length, z * w * 0.3)


## A rod from `a` to `b`, `r0` thick at a and `r1` at b.
static func _rod(root: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = a.distance_to(b) + minf(r0, r1)   # (a little overlap, so the joints close)
	c.radial_segments = 8
	c.rings = 1
	var mi := _part(root, c, mat, (a + b) * 0.5)
	mi.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

## A long crystal (two pyramids base to base), from `at` along `dir`.
static func _crystal(root: Node3D, at: Vector3, dir: Vector3, r: float, h: float, mat: Material) -> void:
	var d := dir.normalized()
	_cone(root, at + d * h * 0.25, d, r, h * 0.75, mat)
	_cone(root, at + d * h * 0.25, -d, r, h * 0.25, mat)


## A four-sided point standing at `at` (its base), pointing along `dir`.
static func _cone(root: Node3D, at: Vector3, dir: Vector3, r: float, h: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 4 if mat == _mat("ice") else 6
	c.rings = 1
	var d := dir.normalized()
	var m := _part(root, c, mat, at + d * h * 0.5)
	m.quaternion = Quaternion(Vector3.UP, d)


static func _part(root: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
	return mi


## A soft round glow (additive), so the shape reads against a dark floor.
static func _glow(root: Node3D, at: Vector3, r: float, col: Color) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	var key := "glow %s" % col
	if not _mats.has(key):
		var m := U.unlit(col).duplicate() as StandardMaterial3D
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	_part(root, s, _mats[key], at)


static var _meshes := {}

## A crescent blade in the weapon's x-y plane: its outer edge an arc round `c` of radius `r`
## from angle `a0` to `a1` (0 = straight up, PI/2 = out to +x), widest (`w`) in the middle and
## pointed at both ends (`taper` thins the far end more), thick enough to read from any side.
## `rim`: a thin glowing strip along its outer edge instead. `flip`: mirrored to -x.
static func _crescent(key: String, c: Vector2, r: float, a0: float, a1: float, w: float, taper: float, rim: bool, flip: bool) -> ArrayMesh:
	var k := "%s %s %s" % [key, rim, flip]
	if _meshes.has(k):
		return _meshes[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	var outer := []
	var inner := []
	var fx := -1.0 if flip else 1.0
	for i in steps + 1:
		var t := i / float(steps)
		var a := lerpf(a0, a1, t)
		var n := Vector2(sin(a), cos(a))
		var o := c + n * r
		var wide := sin(clampf(t * 1.05, 0.0, 1.0) * PI) * w * (1.0 - t * taper)
		if rim:
			outer.append(o + n * 0.025)
			inner.append(o - n * 0.035)
		else:
			outer.append(o)
			inner.append(o - n * (wide + 0.01))
	for i in steps + 1:
		outer[i] = Vector2(outer[i].x * fx, outer[i].y)
		inner[i] = Vector2(inner[i].x * fx, inner[i].y)
	var half := 0.045 if rim else 0.035
	for i in steps:
		for side: float in [-half, half]:
			var p0 := Vector3(outer[i].x, outer[i].y, side)
			var p1 := Vector3(outer[i + 1].x, outer[i + 1].y, side)
			var q0 := Vector3(inner[i].x, inner[i].y, side)
			var q1 := Vector3(inner[i + 1].x, inner[i + 1].y, side)
			for v in [p0, p1, q1, p0, q1, q0]:
				st.set_normal(Vector3(0, 0, signf(side)))
				st.add_vertex(v)
		# the outer and inner edges
		for e: Array in [[outer[i], outer[i + 1]], [inner[i], inner[i + 1]]]:
			var e0 := Vector3(e[0].x, e[0].y, -half)
			var e1 := Vector3(e[1].x, e[1].y, -half)
			var f0 := Vector3(e[0].x, e[0].y, half)
			var f1 := Vector3(e[1].x, e[1].y, half)
			var nrm := Vector3(e[1].y - e[0].y, e[0].x - e[1].x, 0).normalized() * fx
			for v in [e0, e1, f1, e0, f1, f0]:
				st.set_normal(nrm)
				st.add_vertex(v)
	var am := st.commit()
	_meshes[k] = am
	return am


static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		"ice":
			m.albedo_color = Color(0.72, 0.94, 1.0)
			m.metallic = 0.3
			m.roughness = 0.08
			m.emission_enabled = true
			m.emission = Color(0.35, 0.8, 1.0)
			m.emission_energy_multiplier = 0.75
		"gold":
			m.albedo_color = Color(1.0, 0.8, 0.3)
			m.metallic = 0.8
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(1.0, 0.68, 0.18)
			m.emission_energy_multiplier = 0.7
		"sun core":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.95, 0.75) * 1.3
		"void blade":
			m.albedo_color = Color(0.13, 0.07, 0.22)
			m.metallic = 0.85
			m.roughness = 0.25
			m.emission_enabled = true
			m.emission = Color(0.35, 0.12, 0.6)
			m.emission_energy_multiplier = 0.5
		"void edge":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.82, 0.55, 1.0) * 1.2
		"void orb":
			m.albedo_color = Color(0.03, 0.01, 0.06)
			m.metallic = 0.4
			m.roughness = 0.1
			m.emission_enabled = true
			m.emission = Color(0.3, 0.05, 0.5)
			m.emission_energy_multiplier = 0.4
		"void shard":
			m.albedo_color = Color(0.62, 0.38, 1.0)
			m.metallic = 0.5
			m.roughness = 0.15
			m.emission_enabled = true
			m.emission = Color(0.55, 0.25, 1.0)
			m.emission_energy_multiplier = 1.1
		"void veil":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.35, 0.12, 0.6, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"void mote":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.85, 0.6, 1.0) * 1.3
		"flame":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.42, 0.08, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		"flame core":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.85, 0.35) * 1.2
	_mats[kind] = m
	return m


## Turns round `axis` (in its own space) at `speed` radians a second.
class Spin extends Node3D:
	var speed := 1.0
	var axis := Vector3.UP

	func _process(delta: float) -> void:
		rotate_object_local(axis, speed * delta)


## Keeps its children level with the world (same size, no tilt), so fire rises straight up.
class Upright extends Node3D:
	func _process(_delta: float) -> void:
		global_basis = Basis.from_scale(global_basis.get_scale())


## Flames that lick up and down.
class Lick extends Node3D:
	var _t := randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta
		var k := 1.0 + 0.16 * sin(_t * 11.0) + 0.08 * sin(_t * 23.0)
		scale = Vector3(1.0 - (k - 1.0) * 0.4, k, 1.0 - (k - 1.0) * 0.4)
