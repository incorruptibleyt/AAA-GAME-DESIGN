class_name ForgedArms
## Version 228-229 (Jesse: "the mage weapons ... aren't they just reskins?"): they were, and
## so was every hero's Frostforged, Emberforged, Gilded and Voidsteel weapon: a weapon the
## hero already had, in a new colour (the LookFx.weapon finish). Each now has its own shape on
## top of its finish:
## - Mage: an ice crystal crown staff, a burning tome, a sun staff, a void scythe (v228).
## - Knight: an ice-cased sword with a frost-spiked shield, and in place of the greatsword
##   (v230): a magma cleaver, a gold sun hammer with a halo, a shattered rift blade.
## - Rogue: a crossbow with ice limbs and an ice bolt, burning knives, a gold winged
##   crossbow, a void crossbow with a portal ring at its front.
## - Barbarian: ice-edged twin axes, and in place of the great axe (v230): a magma maul, a
##   gold ram-headed mace, a moon axe with two crescent blades.
## Built in the weapon mesh's own space, so the shapes scale with the weapon in a run.
## Version 230 (critique of v229: "add-ons glued on the same weapon"): the Knight's and the
## Barbarian's grand looks are whole new weapons. The weapon they were built on is hidden
## (render layers 0) and a weapon of its own is built in its place. So are the Mage's four
## (Jesse: "make sure you're happy with the mage weapons too"): a glacier staff, a sun
## scepter, a reaper's scythe and a burning grimoire. Fire is soft flickering flame (Fx.flame)
## instead of hard cones, which read as yellow spikes, and glows are soft light, not glass balls.

static var _mats := {}
## Which finish gives which shape, per weapon part (the weapon mesh's name in the hero model).
const SHAPES := {
	"2H_Staff": {"frost": "ice_staff", "gold": "sun_staff", "void": "scythe"},
	"Spellbook_open": {"ember": "fire_tome"},
	"1H_Wand": {"ember": "fire_wand"},
	"1H_Sword": {"frost": "ice_sword"},
	"Badge_Shield": {"frost": "ice_shield"},
	"2H_Sword": {"ember": "magma_cleaver", "gold": "sun_hammer", "void": "rift_blade"},
	"2H_Crossbow": {"frost": "ice_bow", "gold": "wing_bow", "void": "ring_bow"},
	"Knife": {"ember": "flame_knife"},
	"Knife_Offhand": {"ember": "flame_knife", "gold": "wing_knife", "void": "void_knife"},
	"1H_Axe": {"frost": "ice_axe"},
	"1H_Axe_Offhand": {"frost": "ice_axe"},
	"2H_Axe": {"ember": "magma_maul", "gold": "ram_mace", "void": "moon_axe"},
}
## Shapes that are a whole weapon: the weapon they are built on is hidden.
const REPLACES := ["ice_staff", "sun_staff", "scythe", "fire_tome",
	"magma_cleaver", "sun_hammer", "rift_blade", "magma_maul", "ram_mace", "moon_axe"]


## Puts the shape for `finish` on weapon `mi`, or takes an old one off.
static func dress(mi: MeshInstance3D, finish: String) -> void:
	var want: String = SHAPES.get(str(mi.name), {}).get(finish, "")
	if SHAPES.has(str(mi.name)):
		mi.layers = 0 if want in REPLACES else 1   # (a whole new weapon hides the one it replaces)
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
		"fire_wand":
			_fire_wand(root)
		"ice_sword":
			_ice_sword(root)
		"ice_shield":
			_ice_shield(root)
		"magma_cleaver":
			_magma_cleaver(root)
		"sun_hammer":
			_sun_hammer(root)
		"rift_blade":
			_rift_blade(root)
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
		"magma_maul":
			_magma_maul(root)
		"ram_mace":
			_ram_mace(root)
		"moon_axe":
			_moon_axe(root)
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.set_meta("fx", true)   # (the hit flash would turn them white)


# ---------------------------------------------------------------- Mage

const HEAD := Vector3(0, 1.12, 0)
## (The Classic staff runs from y -0.9 to 1.25 in its own space, its head at about 1.12.)


## Glacier staff (v230): a six-sided shaft of clear ice with frost spikes at its foot, three ice
## claws at the top holding a great crystal that turns slowly, and three shards circling it.
static func _ice(root: Node3D) -> void:
	var ice := _mat("ice")
	var clear := _mat("ice shaft")
	var still := Node3D.new()
	still.name = "Still"
	root.add_child(still)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.05
	shaft.bottom_radius = 0.06
	shaft.height = 1.8
	shaft.radial_segments = 6
	shaft.rings = 1
	_part(still, shaft, clear, Vector3(0, 0.0, 0))
	_crystal(still, Vector3(0, -0.86, 0), Vector3.DOWN, 0.07, 0.3, ice)
	for i in 3:
		var a := i / 3.0 * TAU
		var out := Vector3(sin(a), 0, cos(a))
		_crystal(still, Vector3(0, -0.72, 0) + out * 0.04, (out - Vector3(0, 0.9, 0)).normalized(), 0.045, 0.24, ice)
		_crystal(still, Vector3(0, 0.25 + 0.12 * i, 0) + out * 0.04, (out + Vector3(0, 0.6, 0)).normalized(), 0.035, 0.16, ice)
		# a claw: out and up from the top of the shaft, then curling in over the crystal
		var c0 := Vector3(0, 0.88, 0)
		var c1 := Vector3(0, 1.1, 0) + out * 0.24
		var c2 := Vector3(0, 1.42, 0) + out * 0.2
		var c3 := Vector3(0, 1.6, 0) + out * 0.08
		_rod(still, c0, c1, 0.05, 0.045, ice)
		_rod(still, c1, c2, 0.045, 0.035, ice)
		_cone(still, c2, c3 - c2, 0.035, c2.distance_to(c3), ice)
	var collar := TorusMesh.new()
	collar.inner_radius = 0.05
	collar.outer_radius = 0.1
	collar.rings = 12
	collar.ring_segments = 6
	_part(still, collar, ice, Vector3(0, 0.9, 0))
	FeatHeads.bake(still, "forged glacier_staff")
	var heart := Spin.new()
	heart.speed = 0.9
	heart.position = Vector3(0, 1.3, 0)
	root.add_child(heart)
	_crystal(heart, Vector3(0, -0.28, 0), Vector3.UP, 0.13, 0.62, ice)
	var ring := Spin.new()
	ring.speed = -1.7
	ring.position = Vector3(0, 1.3, 0)
	root.add_child(ring)
	for i in 3:
		var a := i / 3.0 * TAU
		_crystal(ring, Vector3(sin(a), 0, cos(a)) * 0.46, Vector3(0, 1, 0), 0.06, 0.28, ice)
	_glow(root, Vector3(0, 1.3, 0), 0.55, Color(0.35, 0.85, 1.0, 0.45))


## Sun scepter (v230): a gold shaft with three bands and a gold ball at its foot, a gold cup
## at the top with a crown of points, and above it a white-hot sun in a ring of twelve rays.
static func _sun(root: Node3D) -> void:
	var gold := _mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.045
	shaft.bottom_radius = 0.05
	shaft.height = 1.82
	shaft.radial_segments = 8
	shaft.rings = 1
	_part(still, shaft, _mat("white gold"), Vector3(0, 0.01, 0))
	for y: float in [-0.55, 0.05, 0.62]:
		var band := TorusMesh.new()
		band.inner_radius = 0.04
		band.outer_radius = 0.085
		band.rings = 12
		band.ring_segments = 6
		_part(still, band, gold, Vector3(0, y, 0))
	var foot := SphereMesh.new()
	foot.radius = 0.1
	foot.height = 0.2
	foot.radial_segments = 10
	foot.rings = 5
	_part(still, foot, gold, Vector3(0, -0.92, 0))
	var cup := CylinderMesh.new()
	cup.top_radius = 0.22
	cup.bottom_radius = 0.06
	cup.height = 0.24
	cup.radial_segments = 10
	cup.rings = 1
	_part(still, cup, gold, Vector3(0, 1.0, 0))
	for i in 6:
		var a := i / 6.0 * TAU
		var out := Vector3(sin(a), 0, cos(a))
		_cone(still, Vector3(0, 1.1, 0) + out * 0.2, (out * 0.5 + Vector3.UP).normalized(), 0.05, 0.2, gold)
	FeatHeads.bake(still, "forged sun_scepter")
	var at := Vector3(0, 1.38, 0)
	var wheel := Spin.new()
	wheel.speed = 0.7
	wheel.position = at
	root.add_child(wheel)
	var band := TorusMesh.new()
	band.inner_radius = 0.24
	band.outer_radius = 0.31
	band.rings = 24
	band.ring_segments = 6
	_part(wheel, band, gold, Vector3.ZERO)
	for i in 12:
		var a := i / 12.0 * TAU
		var out := Vector3(sin(a), 0, cos(a))
		var long := i % 2 == 0
		_cone(wheel, out * 0.3, out, 0.07 if long else 0.05, 0.3 if long else 0.18, gold)
	FeatHeads.bake(wheel, "forged sun_staff")
	var core := SphereMesh.new()
	core.radius = 0.16
	core.height = 0.32
	core.radial_segments = 12
	core.rings = 6
	_part(root, core, _mat("sun core"), at)
	_glow(root, at, 0.6, Color(1.0, 0.75, 0.25, 0.5))


## Reaper's scythe (v230): a crooked black shaft with violet bands and a void spike at its
## foot, a great curved blade sweeping out from the top with a glowing edge, a hook spike on
## the back, and a black orb where blade meets shaft with two motes circling it.
static func _scythe(root: Node3D) -> void:
	var dark := _mat("void blade")
	var still := Node3D.new()
	root.add_child(still)
	var bend := [Vector3(0, -0.88, 0), Vector3(0.05, -0.2, 0), Vector3(-0.03, 0.5, 0), Vector3(0.02, 1.16, 0)]
	for i in bend.size() - 1:
		_rod(still, bend[i], bend[i + 1], 0.055, 0.05, dark)
	for y: float in [-0.5, 0.15, 0.8]:
		var band := CylinderMesh.new()
		band.top_radius = 0.07
		band.bottom_radius = 0.07
		band.height = 0.06
		band.radial_segments = 8
		band.rings = 1
		_part(still, band, _mat("void edge"), Vector3(0.01 if y < 0.0 else -0.01, y, 0))
	_cone(still, Vector3(0, -0.86, 0), Vector3.DOWN, 0.06, 0.26, _mat("void shard"))
	_cone(still, Vector3(0.0, 1.12, 0), Vector3(-1, 0.35, 0), 0.06, 0.32, _mat("void shard"))
	FeatHeads.bake(still, "forged reaper_scythe")
	# (The blade is turned an eighth round the shaft, so it shows its face both on the Style
	# stage and from the run camera above; flat on, one of the two saw only its edge.)
	var turn := Node3D.new()
	turn.rotation = Vector3(0, PI / 4, 0)
	root.add_child(turn)
	var blade := MeshInstance3D.new()
	blade.mesh = _crescent("reaper", Vector2(0.06, 1.1), 0.92, 0.12, 2.25, 0.36, 0.3, false, false)
	blade.material_override = _mat("reaper blade")
	turn.add_child(blade)
	var edge := MeshInstance3D.new()
	edge.mesh = _crescent("reaper", Vector2(0.06, 1.1), 0.92, 0.12, 2.25, 0.36, 0.3, true, false)
	edge.material_override = _mat("void edge")
	turn.add_child(edge)
	var orb := SphereMesh.new()
	orb.radius = 0.14
	orb.height = 0.28
	orb.radial_segments = 12
	orb.rings = 6
	_part(root, orb, _mat("void orb"), Vector3(0.02, 1.18, 0))
	_glow(root, Vector3(0.3, 1.2, 0), 0.7, Color(0.6, 0.25, 1.0, 0.4))
	var motes := Spin.new()
	motes.speed = -2.2
	motes.position = Vector3(0.02, 1.18, 0)
	root.add_child(motes)
	for i in 2:
		var a := i * PI
		var m := SphereMesh.new()
		m.radius = 0.05
		m.height = 0.1
		m.radial_segments = 8
		m.rings = 4
		_part(motes, m, _mat("void mote"), Vector3(sin(a), 0.1 * (1 - 2 * i), cos(a)) * 0.3)


## Burning grimoire (v230): in place of the open book, a thick black-red grimoire, its covers
## open in a V with gold corners and a gold clasp, a glowing rune ring on each page, and soft
## fire rising off its pages with embers circling above.
static func _fire(root: Node3D) -> void:
	# (The open book it replaces stands about 0.83 wide and 0.57 tall in its x-y plane, its
	# pages facing +z.)
	var hide := _mat("hide")
	var gold := _mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	for side: float in [-1.0, 1.0]:
		var half := Node3D.new()
		half.position = Vector3(0.0, 0.0, -0.04)
		half.rotation = Vector3(0, -side * 0.32, 0)
		still.add_child(half)
		var cover := BoxMesh.new()
		cover.size = Vector3(0.5, 0.76, 0.05)
		_part(half, cover, hide, Vector3(side * 0.25, 0, 0))
		var pages := BoxMesh.new()
		pages.size = Vector3(0.38, 0.6, 0.08)
		_part(half, pages, _mat("page"), Vector3(side * 0.2, 0, 0.06))
		for y: float in [-0.34, 0.34]:
			var corner := BoxMesh.new()
			corner.size = Vector3(0.11, 0.11, 0.09)
			_part(half, corner, gold, Vector3(side * 0.46, y, 0.01))
		var rune := TorusMesh.new()
		rune.inner_radius = 0.085
		rune.outer_radius = 0.11
		rune.rings = 16
		rune.ring_segments = 4
		var r := _part(half, rune, _mat("magma"), Vector3(side * 0.2, -0.02, 0.105))
		r.rotation = Vector3(PI / 2, 0, 0)
		_rod(half, Vector3(side * 0.2, -0.13, 0.105), Vector3(side * 0.2, 0.09, 0.105), 0.012, 0.012, _mat("magma"))
		FeatHeads.bake(half, "forged grimoire %s" % side)
	var spine := CylinderMesh.new()
	spine.top_radius = 0.06
	spine.bottom_radius = 0.06
	spine.height = 0.68
	spine.radial_segments = 8
	spine.rings = 1
	_part(still, spine, hide, Vector3(0, 0, -0.06))
	var clasp := SphereMesh.new()
	clasp.radius = 0.07
	clasp.height = 0.14
	clasp.radial_segments = 8
	clasp.rings = 4
	_part(still, clasp, gold, Vector3(0, 0.0, -0.1))
	var top := Vector3(0, 0.22, 0.06)
	var up := Upright.new()
	up.position = top
	root.add_child(up)
	for f: Array in [[Vector3(0, 0, 0), 0.2, 0.85], [Vector3(-0.22, -0.04, 0.02), 0.14, 0.55], [Vector3(0.22, -0.04, -0.02), 0.14, 0.62]]:
		_flame(up, f[0], f[1], f[2])
	_embers(up, Vector3(0, 0.45, 0), 4, 0.42, 0.07)
	_glow(up, Vector3(0, 0.25, 0), 0.5, Color(1.0, 0.5, 0.12, 0.45))


## The Emberforged wand: a small soft flame burning at its tip.
static func _fire_wand(root: Node3D) -> void:
	var up := Upright.new()
	up.position = Vector3(0, 0.66, 0)
	root.add_child(up)
	_flame(up, Vector3.ZERO, 0.09, 0.32)


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


## Emberforged (v230): a magma cleaver. A broad black-iron blade that widens to a hooked,
## chopped tip, molten cracks and a glowing edge, horned guard, fire licking off its top.
static func _magma_cleaver(root: Node3D) -> void:
	var iron := _mat("iron")
	var magma := _mat("magma")
	var still := Node3D.new()
	root.add_child(still)
	_handle(still, -0.42, 0.3, iron)
	var guard := PackedVector2Array([Vector2(-0.38, 0.28), Vector2(-0.46, 0.5), Vector2(-0.3, 0.4), Vector2(-0.12, 0.42),
		Vector2(0.12, 0.42), Vector2(0.3, 0.4), Vector2(0.46, 0.5), Vector2(0.38, 0.28), Vector2(0.1, 0.22), Vector2(-0.1, 0.22)])
	_slab_part(still, "cleaver guard", guard, 0.07, iron)
	# a broad blade, wider than its guard, flaring to a hooked top
	var blade := PackedVector2Array([Vector2(-0.14, 0.42), Vector2(-0.2, 0.95), Vector2(-0.12, 1.03), Vector2(-0.24, 1.12),
		Vector2(-0.28, 1.55), Vector2(-0.18, 1.63), Vector2(-0.3, 1.72), Vector2(-0.24, 2.02), Vector2(0.22, 2.1),
		Vector2(0.32, 1.96), Vector2(0.64, 2.04), Vector2(0.6, 1.62), Vector2(0.48, 1.1), Vector2(0.3, 0.62), Vector2(0.16, 0.42)])
	_slab_part(still, "cleaver blade", blade, 0.045, _mat("hot iron"))
	# the glowing edge and a crack running up both faces
	var edge := [Vector2(0.16, 0.44), Vector2(0.3, 0.62), Vector2(0.48, 1.1), Vector2(0.6, 1.62), Vector2(0.64, 2.02)]
	for i in edge.size() - 1:
		_rod(still, Vector3(edge[i].x + 0.01, edge[i].y, 0), Vector3(edge[i + 1].x + 0.01, edge[i + 1].y, 0), 0.04, 0.04, magma)
	var crack := [Vector2(0.0, 0.5), Vector2(0.12, 0.85), Vector2(0.0, 1.2), Vector2(0.2, 1.55), Vector2(0.06, 1.9)]
	for z: float in [-0.05, 0.05]:
		for i in crack.size() - 1:
			_rod(still, Vector3(crack[i].x, crack[i].y, z), Vector3(crack[i + 1].x, crack[i + 1].y, z), 0.032, 0.024, magma)
	var pommel := SphereMesh.new()
	pommel.radius = 0.09
	pommel.height = 0.18
	pommel.radial_segments = 8
	pommel.rings = 4
	_part(still, pommel, magma, Vector3(0, -0.46, 0))
	FeatHeads.bake(still, "forged magma_cleaver")
	for f: Array in [[Vector3(0.36, 1.98, 0), 0.15, 0.6], [Vector3(0.06, 2.02, 0), 0.13, 0.48], [Vector3(0.44, 1.5, 0), 0.11, 0.38]]:
		_flame(root, f[0], f[1], f[2])
	_glow(root, Vector3(0.18, 1.5, 0), 0.6, Color(1.0, 0.45, 0.1, 0.2))


## Gilded (v230): a gold sun hammer. A long haft with gold bands, a great gold hammer head
## with sun gems on both faces and a spike on top, and a halo turning round the head.
static func _sun_hammer(root: Node3D) -> void:
	var gold := _mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	_handle(still, -0.45, 1.42, _mat("wood"))
	for y: float in [-0.4, 0.3, 1.0]:
		var band := CylinderMesh.new()
		band.top_radius = 0.075
		band.bottom_radius = 0.075
		band.height = 0.08
		band.radial_segments = 10
		band.rings = 1
		_part(still, band, gold, Vector3(0, y, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.72, 0.4, 0.4)
	_part(still, head, gold, Vector3(0, 1.58, 0))
	for sd: float in [-1.0, 1.0]:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.24
		cap.bottom_radius = 0.24
		cap.height = 0.14
		cap.radial_segments = 12
		cap.rings = 1
		var c := _part(still, cap, gold, Vector3(sd * 0.42, 1.58, 0))
		c.rotation = Vector3(0, 0, PI / 2)
	_cone(still, Vector3(0, 1.77, 0), Vector3.UP, 0.1, 0.38, gold)
	FeatHeads.bake(still, "forged sun_hammer")
	for sd: float in [-1.0, 1.0]:
		var gem := SphereMesh.new()
		gem.radius = 0.11
		gem.height = 0.22
		gem.radial_segments = 10
		gem.rings = 5
		_part(root, gem, _mat("sun core"), Vector3(0, 1.58, sd * 0.21))
	var halo := Spin.new()
	halo.speed = 1.1
	halo.position = Vector3(0, 1.6, 0)
	halo.rotation = Vector3(0.25, 0, 0.15)
	root.add_child(halo)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.54
	ring.outer_radius = 0.62
	ring.rings = 32
	ring.ring_segments = 6
	_part(halo, ring, gold, Vector3.ZERO)
	for i in 4:
		var a := i / 4.0 * TAU
		_crystal(halo, Vector3(sin(a), 0, cos(a)) * 0.58 - Vector3(0, 0.08, 0), Vector3.UP, 0.06, 0.2, _mat("sun core"))
	_glow(root, Vector3(0, 1.6, 0), 0.65, Color(1.0, 0.75, 0.25, 0.2))


## Voidsteel (v230): a shattered rift blade. The blade is broken into five floating pieces
## held together by violet light, each rimmed in glowing violet, a black star past the tip.
static func _rift_blade(root: Node3D) -> void:
	var still := Node3D.new()
	root.add_child(still)
	_handle(still, -0.42, 0.3, _mat("iron"))
	var guard := PackedVector2Array([Vector2(-0.5, 0.42), Vector2(-0.3, 0.3), Vector2(-0.1, 0.26), Vector2(0.1, 0.26),
		Vector2(0.3, 0.3), Vector2(0.5, 0.42), Vector2(0.28, 0.38), Vector2(0.0, 0.36), Vector2(-0.28, 0.38)])
	_slab_part(still, "rift guard", guard, 0.06, _mat("void blade"))
	FeatHeads.bake(still, "forged rift_blade")
	var y := 0.44
	for i in 5:
		var h := 0.3 - i * 0.02
		var w0 := 0.2 - i * 0.025
		var w1 := 0.2 - (i + 1) * 0.025
		var top := 0.0 if i == 4 else w1
		var piece := Node3D.new()
		piece.position = Vector3(0.03 * (1 - 2 * (i % 2)), y, 0)
		piece.rotation.z = 0.06 * (1 - 2 * (i % 2))
		root.add_child(piece)
		var pts := PackedVector2Array([Vector2(-w0, 0), Vector2(w0, 0), Vector2(top, h), Vector2(-top, h)]) if i < 4 \
			else PackedVector2Array([Vector2(-w0, 0), Vector2(w0, 0), Vector2(0, h + 0.2)])
		var rim := PackedVector2Array()
		for q in pts:
			rim.append(q * 1.18 + Vector2(0, -0.02))
		_slab_part(piece, "rift rim %d" % i, rim, 0.03, _mat("void edge"))
		_slab_part(piece, "rift piece %d" % i, pts, 0.045, _mat("void blade"))
		_glow(root, Vector3(0, y - 0.04, 0), 0.12, Color(0.65, 0.3, 1.0, 0.5))
		y += h + 0.09
	var ring := Spin.new()
	ring.speed = 1.6
	ring.position = Vector3(0, 1.2, 0)
	root.add_child(ring)
	for j in 3:
		var a := j / 3.0 * TAU
		var out := Vector3(sin(a), 0, cos(a))
		_crystal(ring, out * 0.42 - Vector3(0, 0.15, 0), Vector3.UP + out * 0.25, 0.07, 0.36, _mat("void shard"))
	_orb(root, Vector3(0, y + 0.22, 0), 0.13)
	_orb(root, Vector3(0, -0.5, 0), 0.07)


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


## Emberforged (v230): a magma maul. A great lump of black rock split by glowing magma on
## a long iron haft, fire rising off the top and embers circling it.
static func _magma_maul(root: Node3D) -> void:
	var still := Node3D.new()
	root.add_child(still)
	_handle(still, -0.45, 0.95, _mat("iron"))
	var core := SphereMesh.new()
	core.radius = 0.3
	core.height = 0.6
	core.radial_segments = 10
	core.rings = 5
	_part(still, core, _mat("magma"), Vector3(0, 1.12, 0))
	for r: Array in [[Vector3(-0.24, 1.05, 0.04), 0.26], [Vector3(0.22, 1.1, -0.04), 0.27], [Vector3(-0.05, 1.32, 0.02), 0.24],
			[Vector3(0.05, 0.9, 0.02), 0.22], [Vector3(-0.12, 1.15, 0.2), 0.2], [Vector3(0.12, 1.12, -0.2), 0.2]]:
		var rock := SphereMesh.new()
		rock.radius = r[1]
		rock.height = r[1] * 1.7
		rock.radial_segments = 6
		rock.rings = 3
		var m := _part(still, rock, _mat("rock"), r[0])
		m.rotation = Vector3(r[0].x * 3.0, r[0].y * 2.0, r[0].z * 4.0)
	FeatHeads.bake(still, "forged magma_maul")
	for f: Array in [[Vector3(-0.1, 1.45, 0), 0.17, 0.62], [Vector3(0.18, 1.38, 0), 0.13, 0.45]]:
		_flame(root, f[0], f[1], f[2])
	var top := Upright.new()
	top.position = Vector3(0, 1.4, 0)
	root.add_child(top)
	_embers(top, Vector3(0, 0.3, 0), 4, 0.45, 0.08)
	_glow(root, Vector3(0, 1.15, 0), 0.6, Color(1.0, 0.45, 0.1, 0.22))


## Gilded (v230): a gold ram-headed mace. A spiked gold ball on a banded haft with two
## ram's horns curling down its sides and a white-hot gem on its brow.
static func _ram_mace(root: Node3D) -> void:
	var gold := _mat("gold")
	var still := Node3D.new()
	root.add_child(still)
	_handle(still, -0.45, 0.95, _mat("wood"))
	for y: float in [-0.38, 0.35, 0.9]:
		var band := CylinderMesh.new()
		band.top_radius = 0.08
		band.bottom_radius = 0.08
		band.height = 0.08
		band.radial_segments = 10
		band.rings = 1
		_part(still, band, gold, Vector3(0, y, 0))
	var c := Vector3(0, 1.18, 0)
	var ball := SphereMesh.new()
	ball.radius = 0.28
	ball.height = 0.56
	ball.radial_segments = 12
	ball.rings = 6
	_part(still, ball, gold, c)
	for i in 6:
		var a := i / 6.0 * TAU
		_cone(still, c + Vector3(sin(a), 0, cos(a)) * 0.24, Vector3(sin(a), 0.25, cos(a)), 0.07, 0.22, gold)
	_cone(still, c + Vector3(0, 0.25, 0), Vector3.UP, 0.08, 0.3, gold)
	for sd: float in [-1.0, 1.0]:
		var pts := []
		var n := 14
		for i in n + 1:
			var t := i / float(n)
			var th := t * PI * 1.6
			var rr := 0.26 * (1.0 - 0.5 * t)
			pts.append(c + Vector3(sd * (0.3 + rr * sin(th)), 0.06 + rr * cos(th) - 0.26 * (1.0 - cos(th * 0.5)) * 0.0, 0.06 + 0.12 * t))
		for i in n:
			var t := i / float(n)
			_rod(still, pts[i], pts[i + 1], lerpf(0.09, 0.035, t), lerpf(0.09, 0.035, t + 1.0 / n), gold)
	FeatHeads.bake(still, "forged ram_mace")
	var gem := SphereMesh.new()
	gem.radius = 0.1
	gem.height = 0.2
	gem.radial_segments = 10
	gem.rings = 5
	_part(root, gem, _mat("sun core"), c + Vector3(0, 0.02, 0.27))
	_glow(root, c, 0.55, Color(1.0, 0.75, 0.25, 0.2))


## Voidsteel: a moon axe. Two great crescent blades like a split moon on a dark haft, a void
## shard for a spear tip and a black star between the blades (v230: its own weapon).
static func _moon_axe(root: Node3D) -> void:
	var still := Node3D.new()
	root.add_child(still)
	_handle(still, -0.45, 1.35, _mat("iron"))
	FeatHeads.bake(still, "forged moon_axe")
	for flip: bool in [false, true]:
		var blade := MeshInstance3D.new()
		blade.mesh = _crescent("moon", Vector2(0.27, 1.0), 0.7, 0.55, 2.59, 0.34, 0.0, false, flip)
		blade.material_override = _mat("void blade")
		root.add_child(blade)
		var edge := MeshInstance3D.new()
		edge.mesh = _crescent("moon", Vector2(0.27, 1.0), 0.7, 0.55, 2.59, 0.34, 0.0, true, flip)
		edge.material_override = _mat("void edge")
		root.add_child(edge)
	_crystal(root, Vector3(0, 1.32, 0), Vector3.UP, 0.08, 0.5, _mat("void shard"))
	_orb(root, Vector3(0, 1.02, 0.08), 0.14)


# ---------------------------------------------------------------- parts

## A soft flickering flame (Fx.flame, the torches' flame) standing on `at`, about `h` tall.
## (v230: hard cones read as yellow spikes in a still picture.)
static func _flame(root: Node3D, at: Vector3, r: float, h: float) -> void:
	Fx.flame(root, Vector2(r * 3.4, h * 1.4), at)


## A haft from `y0` to `y1` up the weapon's own axis.
static func _handle(root: Node3D, y0: float, y1: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.055
	c.bottom_radius = 0.06
	c.height = y1 - y0
	c.radial_segments = 8
	c.rings = 1
	_part(root, c, mat, Vector3(0, (y0 + y1) * 0.5, 0))


## A flat shape cut from outline `pts` (in the weapon's x-y plane), `half` thick each side.
static func _slab_part(root: Node3D, key: String, pts: PackedVector2Array, half: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _slab(key, pts, half)
	mi.material_override = mat
	root.add_child(mi)
	return mi


static func _slab(key: String, pts: PackedVector2Array, half: float) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var area := 0.0
	for i in pts.size():
		var q0 := pts[i]
		var q1 := pts[(i + 1) % pts.size()]
		area += q0.x * q1.y - q1.x * q0.y
	if area < 0.0:   # counter-clockwise outline, so (dy, -dx) points out of every side
		pts = pts.duplicate()
		pts.reverse()
	var idx := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-half, half]:
		for i in range(0, idx.size(), 3):
			_tri(st, Vector3(pts[idx[i]].x, pts[idx[i]].y, side), Vector3(pts[idx[i + 1]].x, pts[idx[i + 1]].y, side),
					Vector3(pts[idx[i + 2]].x, pts[idx[i + 2]].y, side), Vector3(0, 0, signf(side)))
	var n := pts.size()
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var nrm := Vector3(p1.y - p0.y, p0.x - p1.x, 0).normalized()
		_tri(st, Vector3(p0.x, p0.y, -half), Vector3(p1.x, p1.y, -half), Vector3(p1.x, p1.y, half), nrm)
		_tri(st, Vector3(p0.x, p0.y, -half), Vector3(p1.x, p1.y, half), Vector3(p0.x, p0.y, half), nrm)
	st.index()   # FeatHeads.bake drops vertices that have no index list
	var am := st.commit()
	_meshes[key] = am
	return am


## One flat triangle facing `out` (Godot draws the side its corners run clockwise).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) > 0.0:
		var k := b
		b = c
		c = k
	for v: Vector3 in [a, b, c]:
		st.set_normal(out)
		st.add_vertex(v)


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


## A soft round glow (v230: light that fades out from its middle, always facing the camera;
## it was a see-through ball, which read as glass), so the shape reads against a dark floor.
static func _glow(root: Node3D, at: Vector3, r: float, col: Color) -> void:
	var key := "glow %s" % col
	if not _mats.has(key):
		if _glow_shader == null:
			_glow_shader = Shader.new()
			_glow_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float d = clamp(1.0 - length(UV * 2.0 - 1.0), 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = d * d * tint.a;
}
"""
		var m := ShaderMaterial.new()
		m.shader = _glow_shader
		m.set_shader_parameter("tint", col)
		_mats[key] = m
	var q := QuadMesh.new()
	q.size = Vector2.ONE * r * 2.6
	_part(root, q, _mats[key], at)


static var _glow_shader: Shader


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
	st.index()
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
		"iron":
			m.albedo_color = Color(0.17, 0.15, 0.16)
			m.metallic = 0.75
			m.roughness = 0.35
		"wood":
			m.albedo_color = Color(0.36, 0.22, 0.13)
			m.roughness = 0.7
		"hot iron":
			m.albedo_color = Color(0.32, 0.22, 0.2)
			m.metallic = 0.7
			m.roughness = 0.3
			m.emission_enabled = true
			m.emission = Color(0.55, 0.13, 0.03)
			m.emission_energy_multiplier = 0.6
		"reaper blade":
			m.albedo_color = Color(0.3, 0.17, 0.5)
			m.metallic = 0.8
			m.roughness = 0.2
			m.emission_enabled = true
			m.emission = Color(0.42, 0.16, 0.75)
			m.emission_energy_multiplier = 0.9
		"page":
			m.albedo_color = Color(0.85, 0.62, 0.4)
			m.roughness = 0.8
			m.emission_enabled = true
			m.emission = Color(1.0, 0.45, 0.12)
			m.emission_energy_multiplier = 0.35
		"ice shaft":
			m.albedo_color = Color(0.5, 0.78, 0.95)
			m.metallic = 0.35
			m.roughness = 0.12
			m.emission_enabled = true
			m.emission = Color(0.2, 0.5, 0.8)
			m.emission_energy_multiplier = 0.4
		"white gold":
			m.albedo_color = Color(1.0, 0.93, 0.75)
			m.metallic = 0.7
			m.roughness = 0.25
		"hide":
			m.albedo_color = Color(0.22, 0.06, 0.05)
			m.roughness = 0.6
			m.emission_enabled = true
			m.emission = Color(0.35, 0.06, 0.02)
			m.emission_energy_multiplier = 0.3

		"rock":
			m.albedo_color = Color(0.13, 0.1, 0.1)
			m.roughness = 0.85
			m.emission_enabled = true
			m.emission = Color(0.5, 0.12, 0.02)
			m.emission_energy_multiplier = 0.35
		"magma":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.48, 0.1) * 1.25
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
