class_name Props
## Each floor has its own things in the corners and on the walls, so floors differ in shape
## and not just in colour: skull piles and candles in the Bone Crypt, icicles and ice
## crystals in the Frozen Ossuary, braziers and lava grates in the Ember Catacomb (on the
## walls, so they never look like fire on the floor), broken columns grown over with kelp
## and drains pouring water in the Drowned Vault, clumps of glowing mushrooms and shelf
## fungus in the Glowcap Grotto, obelisks, jars, painted coffins and sand pouring in through
## cracks in the walls in the Sandfall Tomb, crystals, carts and boarded tunnels in the
## Amethyst Mine, and lecterns with flying pages, piled books, ladders, a clock and a globe
## in the Whispering Library, boilers, gears turning on the walls and pumping pistons in the
## Clockwork Foundry. The pieces are simple shapes baked
## into one mesh per material and add no lights, so they stay cheap on phones. A corner
## piece only goes where the room's layout leaves that corner empty.

const CORNERS := [Vector2i(0, 0), Vector2i(Layouts.COLUMNS - 1, 0), Vector2i(0, Layouts.ROWS - 1),
	Vector2i(Layouts.COLUMNS - 1, Layouts.ROWS - 1)]
## Spots along the side walls between the torches (which are at -6, 0 and 6).
const WALL_Z := [-3.0, 3.0]

static var _baked := {}


static func dress(room: Room, layout: Array) -> void:
	var kind: String = Floors.current().get("props", "")
	# The Blood Moon crypt (the event) is dressed like the Bone Crypt, with its own banners
	# and a pool of blood light round each corner's candles.
	var moon := kind == "moon"
	if moon:
		kind = "bone"
	for c: Vector2i in CORNERS:
		var row: String = layout[c.y] if c.y < layout.size() else ""
		if c.x < row.length() and row[c.x] != ".":
			continue
		var p := Room.cell_to_world(c.x, c.y)
		p += Vector3(signf(p.x), 0, signf(p.z)) * 0.12   # snug into the corner
		var n := _place(room, p)
		match kind:
			"bone":
				_mesh(n, _skull_pile(true))
				var candle := Art.get_model("candle_triple")
				if candle:
					var at := p + Vector3(0, 0, -signf(p.z) * 0.7)
					if room.leaves_gap(at, 0.3):
						Art.place_prop(candle, _place(room, at), 0.6)
						room._add_obstacle(at, 0.3)
			"ice":
				_mesh(n, _crystals())
			"ember":
				_mesh(n, _brazier())
				Fx.flame(n, Vector2(0.7, 0.95), Vector3(0, 0.8, 0))
				Fx.flame(n, Vector2(0.4, 0.6), Vector3(0.15, 0.8, 0.1))
			"water":
				_mesh(n, _kelp_column())
			"fungus":
				_mesh(n, _mushroom_clump())
				_glow_pool(n, 2.6)
			"yule":
				# Turned so its gifts face the middle of the room. Pine trees in the far
				# corners; in the near ones (by the camera) a low snowman with a skull for a head.
				n.rotation.y = atan2(-signf(p.x), -signf(p.z)) - PI / 4
				_mesh(n, _pine_tree() if p.z < 0.0 else _snowman())
				_glow_pool(n, 2.4, Color(1.0, 0.7, 0.35, 0.2))
			"sand":
				# An obelisk in each far corner; in the near ones (by the camera) a low heap
				# of jars, one tipped over and spilling sand. Both look into the room.
				n.rotation.y = atan2(-signf(p.x), -signf(p.z)) - PI / 4
				_mesh(n, _obelisk() if p.z < 0.0 else _jars())
			"mine":
				# A great amethyst cluster glowing in each far corner; in the near ones a mine
				# cart heaped with crystals (low, so it never hides the hero).
				n.rotation.y = atan2(-signf(p.x), -signf(p.z)) - PI / 4
				if p.z < 0.0:
					_mesh(n, _crystal_cluster())
					_glow_pool(n, 2.8, Color(0.7, 0.35, 1.0, 0.24))
				else:
					_mesh(n, _mine_cart())
			"library":
				# A lectern in each far corner, its pages flying round it; in the near ones
				# (by the camera) books piled up with candles burning on them.
				n.rotation.y = atan2(-signf(p.x), -signf(p.z)) - PI / 4
				if p.z < 0.0:
					_mesh(n, _lectern())
					_add_pages(n, Vector3(0.45, 0, 0.45))
					_glow_pool(n, 2.6, Color(0.35, 1.0, 0.82, 0.16))
				else:
					_mesh(n, _book_pile())
			"foundry":
				# A boiler with its fire door open in each far corner; in the near ones (by the
				# camera) gears and parts heaped up.
				n.rotation.y = atan2(-signf(p.x), -signf(p.z)) - PI / 4
				if p.z < 0.0:
					_mesh(n, _boiler())
					_glow_pool(n, 2.8, Color(1.0, 0.45, 0.15, 0.2))
				else:
					_mesh(n, _cog_pile())
			"abyss":
				# A brazier of cold star fire in each far corner, rocks circling over it; in the
				# near ones (by the camera) a low heap of broken moonstone round a fallen star.
				n.rotation.y = atan2(-signf(p.x), -signf(p.z)) - PI / 4
				if p.z < 0.0:
					_add_star_brazier(n)
					_glow_pool(n, 2.8, Color(0.55, 0.6, 1.0, 0.2))
				else:
					_mesh(n, _star_rubble())
					_glow_pool(n, 1.6, Color(1.0, 0.8, 0.45, 0.16))
		if moon:
			_glow_pool(n, 3.0, Color(1.0, 0.15, 0.1, 0.18))
		# The prop's collision is a circle centred on the room's true corner, so a push out of
		# it always points into the room (centred on the prop, it could push a skeleton out
		# through the walls, where nothing could reach it).
		var corner := Vector3(signf(p.x) * Room.HALF_W, 0, signf(p.z) * Room.HALF_L)
		room._add_obstacle(corner, 0.55 + Vector2(p.x - corner.x, p.z - corner.z).length())
	for side in [-1.0, 1.0]:
		for z in WALL_Z:
			match kind:
				"bone":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.3), 0, z))
					_mesh(n, _skull_pile(false))
				"ice":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.06), Room.WALL_H, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _icicles())
				"ember":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _grate())
				"water":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_add_spout(n)
				"fungus":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _shelf_fungus())
				"yule":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 1.0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _wreath())
				"sand":
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_add_sandfall(n)
				"mine":
					# Crystals breaking out of the rock between the timber posts (which stand
					# every 3 m, under the torches).
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z * 1.5), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_mesh(n, _wall_crystals())
				"library":
					# A ladder leaning on the shelves.
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_no_shadow(_mesh(n, _ladder()))
				"foundry":
					# Gears turning on an iron plate.
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_add_wall_gears(n)
				"abyss":
					# A great chain hung down the wall from the dark above to a ring at its foot.
					var n := _place(room, Vector3(side * (Room.HALF_W - 0.02), 0, z), false)
					n.rotation.y = 0.0 if side < 0 else PI
					_no_shadow(_mesh(n, _great_chain()))
	_dress_kit(room, layout, "moon" if moon else kind)
	_scatter(room, layout, kind)
	# Two more on the far wall, either side of the door.
	for x in [-3.6, 3.6]:
		match kind:
			"ice":
				var n := _place(room, Vector3(x, Room.WALL_H, -Room.HALF_L + 0.06), false)
				n.rotation.y = -PI / 2
				_mesh(n, _icicles())
			"ember":
				var n := _place(room, Vector3(x, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_mesh(n, _grate())
			"water":
				var n := _place(room, Vector3(x, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_add_spout(n)
			"fungus":
				var n := _place(room, Vector3(x, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_mesh(n, _shelf_fungus())
			"yule":
				var n := _place(room, Vector3(x * 0.62, 1.35, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_mesh(n, _wreath())
			"sand":
				# A painted coffin standing guard either side of the door.
				var n := _place(room, Vector3(x * 0.75, 0, -Room.HALF_L + 0.05), false)
				n.rotation.y = -PI / 2
				_mesh(n, _sarcophagus())
				room._add_obstacle(Vector3(x * 0.75, 0, -Room.HALF_L), 0.5)
			"mine":
				# Old tunnels, boarded up, a lantern hung on each frame.
				var n := _place(room, Vector3(x * 1.22, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_mesh(n, _boarded_tunnel())
			"library":
				# A tall clock on one side of the door and a great globe on the other.
				var n := _place(room, Vector3(x * 1.2, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_mesh(n, _clock() if x < 0.0 else _globe())
				room._add_obstacle(Vector3(x * 1.2, 0, -Room.HALF_L + (0.25 if x < 0.0 else 0.5)), 0.45)
			"foundry":
				# A piston pumping either side of the door.
				var n := _place(room, Vector3(x * 1.2, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_add_piston(n)
				room._add_obstacle(Vector3(x * 1.2, 0, -Room.HALF_L + 0.3), 0.45)
			"abyss":
				# A standing stone carved with a constellation either side of the door, its
				# broken top floating above it.
				var n := _place(room, Vector3(x * 1.2, 0, -Room.HALF_L + 0.02), false)
				n.rotation.y = -PI / 2
				_add_monolith(n)
				room._add_obstacle(Vector3(x * 1.2, 0, -Room.HALF_L + 0.3), 0.45)


## KayKit pieces along the walls (version 134): a banner either side of the door and a few
## things left against the side walls between the torches, different on every floor, so the
## edges of the room read as a real crypt and not a tiled box. Each sits tight to its wall
## with a small collision circle. [model, height] pairs; the sides take them in a different
## order, so the two walls don't mirror each other.
const KIT := {
	"bone": {"banner": "banner_patternA_red", "side": [["barrel_small", 0.8], ["box_small_decorated", 0.62], ["sword_shield_broken", 0.6], ["rubble_half", 0.5]]},
	"ice": {"banner": "banner_patternB_white", "side": [["box_small", 0.6], ["rubble_half", 0.5], ["barrel_small", 0.8], ["sword_shield_broken", 0.6]]},
	"ember": {"banner": "banner_patternC_red", "side": [["rubble_half", 0.55], ["barrel_small", 0.8], ["coin_stack_small", 0.35], ["box_small", 0.6]]},
	"water": {"banner": "banner_patternA_blue", "side": [["rubble_half", 0.5], ["barrel_small", 0.8], ["box_small", 0.6], ["bottle_A_green", 0.4]]},
	"moon": {"banner": "banner_patternC_red", "side": [["box_small_decorated", 0.62], ["rubble_half", 0.5], ["sword_shield_broken", 0.6], ["barrel_small", 0.8]]},
	"fungus": {"banner": "banner_patternA_green", "side": [["rubble_half", 0.55], ["box_small", 0.6], ["barrel_small", 0.8], ["bottle_B_brown", 0.4]]},
	"yule": {"banner": "banner_patternA_red", "side": [["keg", 0.75], ["box_small_decorated", 0.62], ["candle_triple", 0.6], ["barrel_small", 0.8]]},
	# The Sandfall Tomb: no KayKit banners; its own jars ("@jar", made below) and fallen stone.
	"sand": {"banner": "", "side": [["@jar", 0.0], ["rubble_half", 0.5], ["@jar", 0.0], ["rubble_half", 0.55]]},
	"mine": {"banner": "", "side": [["box_small", 0.6], ["@ore", 0.0], ["barrel_small", 0.8], ["@ore", 0.0]]},
	"library": {"banner": "", "side": [["@books", 0.0], ["candle_triple", 0.6], ["@books", 0.0], ["box_small_decorated", 0.62]]},
	"foundry": {"banner": "", "side": [["@cogs", 0.0], ["barrel_small", 0.8], ["@cogs", 0.0], ["box_small", 0.6]]},
	"abyss": {"banner": "", "side": [["@float", 0.0], ["rubble_half", 0.5], ["@star", 0.0], ["rubble_half", 0.55]]},
}
const KIT_Z := [-7.8, -4.4, 1.7, 4.4]


static func _dress_kit(room: Room, layout: Array, kind: String) -> void:
	if not KIT.has(kind):
		return
	var kit: Dictionary = KIT[kind]
	var banner := Art.get_model(kit.banner) if kit.banner != "" else null
	if banner:
		for x in [-2.5, 2.5]:
			var n := _place(room, Vector3(x, 0.75, -Room.HALF_L + 0.12), false)
			_no_shadow(Art.place_prop(banner, n, 1.75))
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var col := 0 if s == 0 else Layouts.COLUMNS - 1
		for i in KIT_Z.size():
			var z: float = KIT_Z[i]
			var row := roundi(z / Room.CELL + (Layouts.ROWS - 1) * 0.5)
			var line: String = layout[row] if row >= 0 and row < layout.size() else ""
			if col < line.length() and line[col] != ".":
				continue
			var pick: Array = kit.side[(i + s * 2) % kit.side.size()]
			var own := str(pick[0]).begins_with("@")
			var scene: PackedScene = null if own else Art.get_model(pick[0])
			if scene == null and not own:
				continue
			var at := Vector3(side * (Room.HALF_W - 0.42), 0, z)
			# Version 165: not where it would narrow the way past a pillar one column in from
			# the wall (that made pockets a skeleton couldn't reach, or get out of).
			if not room.leaves_gap(Vector3(side * Room.HALF_W, 0, z), 0.7):
				continue
			if own:
				var own_mesh: ArrayMesh
				match str(pick[0]):
					"@jar": own_mesh = _jar()
					"@ore": own_mesh = _ore_pile()
					"@books": own_mesh = _wall_books()
					"@float": own_mesh = _floating_rocks()
					"@star": own_mesh = _fallen_star()
					_: own_mesh = _wall_cogs()
				_no_shadow(_mesh(_place(room, at), own_mesh))
			else:
				_no_shadow(Art.place_prop(scene, _place(room, at), pick[1]))
			room._add_obstacle(Vector3(side * Room.HALF_W, 0, z), 0.7)


## Pieces flat against a wall cast no shadow worth its cost (a second draw each on High).
static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


## Little things lying on the floor (version 134): pebbles and broken stone everywhere,
## plus each crypt's own bits: bones and skulls in the Bone Crypt, ice shards in the
## Frozen Ossuary, charcoal and bones in the Ember Catacomb, shells in the Drowned Vault and
## tiny glowing mushrooms in the Glowcap Grotto. They lie in small clusters, more of them by
## the walls and at the feet of pillars, and are too low to block anyone. Kept few, so the
## floors themselves carry each crypt's look. All of it is baked
## into one mesh (a draw or two per material) with no shadows, so it costs almost nothing.
const SCATTER_CLUSTERS := 10


static func _scatter(room: Room, layout: Array, kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(layout)) + Game.floor_num * 7919
	var look := Floors.current()
	var pebble: Color = look.get("pebble", look.floor)
	var stone := U.mat(pebble * Color(0.42, 0.4, 0.46), 0.95)
	var chip := U.mat(pebble * Color(0.62, 0.6, 0.66), 0.9)
	var bone := U.mat(Color(0.82, 0.78, 0.66), 0.85)
	var dark := U.mat(Color(0.06, 0.05, 0.05), 1.0)
	var parts := []
	# Spots: the feet of pillars and other obstacles, the walls, and the open floor.
	var spots: Array[Vector3] = []
	for o: Dictionary in room.obstacles:
		var p: Vector3 = o.pos
		if absf(p.x) < Room.HALF_W - 0.8 and absf(p.z) < Room.HALF_L - 0.8:
			var a := rng.randf() * TAU
			spots.append(p + Vector3(cos(a), 0, sin(a)) * (float(o.r) + 0.15))
	while spots.size() < SCATTER_CLUSTERS:
		if rng.randf() < 0.45:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			spots.append(Vector3(side * (Room.HALF_W - rng.randf_range(0.25, 0.7)), 0, rng.randf_range(-Room.HALF_L + 1.0, Room.HALF_L - 1.5)))
		else:
			spots.append(Vector3(rng.randf_range(-Room.HALF_W + 1.0, Room.HALF_W - 1.0), 0, rng.randf_range(-Room.HALF_L + 1.5, Room.HALF_L - 2.0)))
	spots.shuffle()
	for i in mini(spots.size(), SCATTER_CLUSTERS):
		var at: Vector3 = spots[i]
		var n := rng.randi_range(1, 3)
		for j in n:
			var p := at + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			var yaw := Basis(Vector3.UP, rng.randf() * TAU)
			var roll := rng.randf()
			if roll < 0.5 and kind != "library" and kind != "foundry":   # (no stones on parquet or iron)
				# Pebbles and broken stone.
				var sz := rng.randf_range(0.08, 0.17)
				var m := chip if rng.randf() < 0.4 else stone
				if rng.randf() < 0.5:
					parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.35, Vector3(sz, sz * 0.55, sz * 0.8), yaw), m])
				else:
					parts.append([_cube(), _xf(p + Vector3.UP * sz * 0.4, Vector3(sz * 1.6, sz, sz * 1.2), yaw * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))), m])
			else:
				_scatter_piece(parts, kind, p, yaw, rng, bone, dark)
	if parts.is_empty():
		return
	var mi := _mesh(_place(room, Vector3.ZERO, false), _bake(parts))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _scatter_piece(parts: Array, kind: String, p: Vector3, yaw: Basis, rng: RandomNumberGenerator, bone: Material, dark: Material) -> void:
	match kind:
		"bone", "ember":
			if kind == "ember" and rng.randf() < 0.5:
				# Charcoal.
				var sz := rng.randf_range(0.1, 0.18)
				parts.append([_cube(), _xf(p + Vector3.UP * sz * 0.35, Vector3(sz * 1.5, sz * 0.7, sz), yaw), dark])
			elif rng.randf() < 0.22:
				# A small skull, looking any way.
				var sz := 0.16
				parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.85, Vector3(sz, sz * 0.92, sz * 1.05), yaw), bone])
				parts.append([_cube(), _xf(p + Vector3.UP * sz * 0.3 + yaw * Vector3(0, 0, -sz * 0.4), Vector3(sz * 0.95, sz * 0.4, sz * 0.7), yaw), bone])
				for ex in [-0.38, 0.38]:
					parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.9 + yaw * Vector3(ex * sz, 0, -sz * 0.88), Vector3.ONE * sz * 0.26), dark])
			else:
				# A long bone with knobbed ends, lying flat.
				var bl := rng.randf_range(0.42, 0.7)
				var flat := yaw * Basis(Vector3.RIGHT, PI / 2)
				parts.append([_cone(0.04, 0.04, bl, 6), Transform3D(flat, p + Vector3.UP * 0.05), bone])
				for e in [-0.5, 0.5]:
					parts.append([_sphere(), _xf(p + Vector3.UP * 0.06 + yaw * Vector3(0, 0, e * bl), Vector3.ONE * 0.068), bone])
		"ice":
			# Frost-white shards lying almost flat (pale, so they never look like a Frost Wraith's bolt).
			var ice := U.mat(Color(0.82, 0.9, 0.97), 0.35)
			var h := rng.randf_range(0.16, 0.3)
			var tilt := yaw * Basis(Vector3.RIGHT, rng.randf_range(1.0, 1.35))
			parts.append([_cone(0.0, h * 0.3, h, 4), Transform3D(tilt, p + Vector3.UP * 0.05), ice])
		"water":
			# Shells: little pale fans.
			var sz := rng.randf_range(0.1, 0.16)
			parts.append([_cone(0.0, sz, sz * 0.5, 7), _xf(p + Vector3.UP * sz * 0.15, Vector3(1, 0.6, 1.3), yaw), bone])
		"yule":
			var roll := rng.randf()
			if roll < 0.5:
				# A clump of snow.
				var sz := rng.randf_range(0.12, 0.26)
				parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.12, Vector3(sz, sz * 0.32, sz * 0.8), yaw), _snow_mat()])
			elif roll < 0.8:
				# A pine cone.
				var sz := rng.randf_range(0.06, 0.09)
				parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.8, Vector3(sz, sz * 0.85, sz * 1.6), yaw * Basis(Vector3.RIGHT, 1.3)), _yule_mat("cone")])
			else:
				# A sprig of holly: two dark leaves and three red berries.
				for side in [-1.0, 1.0]:
					parts.append([_sphere(), _xf(p + Vector3.UP * 0.03 + yaw * Vector3(side * 0.07, 0, 0), Vector3(0.08, 0.02, 0.035), yaw * Basis(Vector3.UP, side * 0.5)), _yule_mat("pine")])
				for k in 3:
					parts.append([_sphere(), _xf(p + Vector3(0, 0.05, 0) + yaw * Vector3((k - 1) * 0.025, 0, 0.02 * (k % 2)), Vector3.ONE * 0.026), _yule_mat("berry")])
		"sand":
			var roll := rng.randf()
			if roll < 0.4:
				# A little mound of sand.
				var sz := rng.randf_range(0.16, 0.32)
				parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.08, Vector3(sz, sz * 0.25, sz * 0.75), yaw), _tomb_mat("sand")])
			elif roll < 0.7:
				# Shards of a broken jar: curved bits of red clay, one painted.
				for k in 2:
					var sz := rng.randf_range(0.07, 0.12)
					var at := p + yaw * Vector3(k * 0.13, 0, k * 0.05)
					parts.append([_cube(), _xf(at + Vector3.UP * 0.02, Vector3(sz * 1.4, 0.025, sz), yaw * Basis(Vector3.UP, k * 1.3) * Basis(Vector3.RIGHT, 0.2)), _tomb_mat("clay" if k == 0 else "turq")])
			elif roll < 0.85:
				# A beetle: a dark shell, a head, sitting very still.
				parts.append([_sphere(), _xf(p + Vector3.UP * 0.035, Vector3(0.05, 0.035, 0.065), yaw), _tomb_mat("beetle")])
				parts.append([_sphere(), _xf(p + Vector3.UP * 0.03 + yaw * Vector3(0, 0, -0.07), Vector3(0.028, 0.022, 0.022), yaw), _tomb_mat("dark")])
			else:
				# A long bone half buried in the sand.
				var bl := rng.randf_range(0.4, 0.6)
				var flat := yaw * Basis(Vector3.RIGHT, PI / 2)
				parts.append([_cone(0.04, 0.04, bl, 6), Transform3D(flat, p + Vector3.UP * 0.03), bone])
				parts.append([_sphere(), _xf(p + Vector3.UP * 0.04 + yaw * Vector3(0, 0, -0.5 * bl), Vector3.ONE * 0.068), bone])
				parts.append([_sphere(), _xf(p + Vector3.UP * 0.02 + yaw * Vector3(0, 0, 0.42 * bl), Vector3(0.16, 0.05, 0.12), yaw), _tomb_mat("sand")])
		"mine":
			var roll := rng.randf()
			if roll < 0.45:
				# A shard of amethyst lying in the gravel (dim, so it never looks like a pickup).
				var ln := rng.randf_range(0.12, 0.22)
				var tilt := yaw * Basis(Vector3.RIGHT, rng.randf_range(1.1, 1.45))
				parts.append([_cone(0.035, 0.035, ln, 6), Transform3D(tilt, p + Vector3.UP * 0.04), _mine_mat("crystal_dim")])
				parts.append([_cone(0.0, 0.035, 0.06, 6), Transform3D(tilt, p + Vector3.UP * 0.04 + tilt * Vector3(0, ln * 0.5 + 0.03, 0)), _mine_mat("crystal_dim")])
			elif roll < 0.8:
				# A lump of ore: dark rock with violet specks.
				var sz := rng.randf_range(0.09, 0.16)
				parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.5, Vector3(sz, sz * 0.75, sz * 0.9), yaw), _mine_mat("rock_dark")])
				for k in 3:
					var a := k * 2.1 + rng.randf()
					parts.append([_sphere(), _xf(p + Vector3(cos(a) * sz * 0.8, sz * 0.7, sin(a) * sz * 0.8), Vector3.ONE * 0.022), _mine_mat("crystal_dim")])
			else:
				# A pick someone dropped.
				var flat := yaw * Basis(Vector3.RIGHT, PI / 2)
				parts.append([_cone(0.018, 0.022, 0.62, 6), Transform3D(flat, p + Vector3.UP * 0.03), _mine_mat("wood")])
				var head := p + Vector3.UP * 0.04 + yaw * Vector3(0, 0, -0.31)
				for sd in [-1.0, 1.0]:
					parts.append([_cone(0.004, 0.025, 0.24, 5), Transform3D(yaw * Basis(Vector3.FORWARD, sd * PI / 2 * 0.85), head + yaw * Vector3(sd * 0.11, 0, 0)), _mine_mat("iron")])
		"library":
			var roll := rng.randf()
			if roll < 0.5:
				# A loose page, lying almost flat.
				parts.append([_cube(), Transform3D(yaw * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis.from_scale(Vector3(0.17, 0.004, 0.22)), p + Vector3.UP * 0.012), _lib_mat("paper")])
			elif roll < 0.8:
				# A book dropped on the floor.
				_book(parts, p, Vector3(0.28, 0.06, 0.21), yaw, BOOK_COLOURS[rng.randi() % 4])
			else:
				# An ink pot and its quill.
				parts.append([_cone(0.028, 0.04, 0.06, 8), Transform3D(yaw, p + Vector3.UP * 0.03), _lib_mat("dark")])
				parts.append([_sphere(), _xf(p + Vector3.UP * 0.1 + yaw * Vector3(0.03, 0, 0), Vector3(0.012, 0.11, 0.03), yaw * Basis(Vector3.FORWARD, 0.4)), _lib_mat("paper")])
		"foundry":
			var roll := rng.randf()
			if roll < 0.4:
				# A nut: a little six-sided ring of iron.
				parts.append([_cone(0.035, 0.035, 0.025, 6), Transform3D(yaw, p + Vector3.UP * 0.013), _iron_mat("iron")])
			elif roll < 0.65:
				# A bolt lying on its side.
				var flat := yaw * Basis(Vector3.RIGHT, PI / 2)
				parts.append([_cone(0.012, 0.012, 0.12, 6), Transform3D(flat, p + Vector3.UP * 0.014), _iron_mat("iron")])
				parts.append([_cone(0.026, 0.026, 0.02, 6), Transform3D(flat, p + Vector3.UP * 0.026 + yaw * Vector3(0, 0, -0.07)), _iron_mat("iron")])
			elif roll < 0.85:
				# A small gear, dropped.
				_gear_parts(parts, p + Vector3.UP * 0.015, yaw, rng.randf_range(0.07, 0.12), 8, 0.025, _iron_mat("brass" if rng.randf() < 0.5 else "copper"))
			else:
				# A lump of coal.
				var sz := rng.randf_range(0.06, 0.11)
				parts.append([_sphere(), _xf(p + Vector3.UP * sz * 0.5, Vector3(sz, sz * 0.7, sz * 0.9), yaw), _iron_mat("coal")])
		"abyss":
			if rng.randf() < 0.65:
				# A splinter of fallen star, glowing, half sunk in the floor.
				var sz := rng.randf_range(0.04, 0.08)
				var tilt := yaw * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
				parts.append([_cone(0.0, sz, sz * 2.6, 4), Transform3D(tilt, p + Vector3.UP * sz * 0.9), _abyss_mat("gold" if rng.randf() < 0.3 else "star")])
			else:
				# A chip of moonstone.
				var sz := rng.randf_range(0.07, 0.14)
				parts.append([_cube(), _xf(p + Vector3.UP * sz * 0.35, Vector3(sz * 1.5, sz * 0.7, sz), yaw * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))), _abyss_mat("stone")])
		"fungus":
			# A tiny mushroom: a stalk and a glowing cap.
			var h := rng.randf_range(0.13, 0.24)
			parts.append([_cone(0.03, 0.038, h, 5), Transform3D(yaw, p + Vector3.UP * h * 0.5), bone])
			parts.append([_sphere(), _xf(p + Vector3.UP * h, Vector3(h * 0.55, h * 0.3, h * 0.55), yaw), _cap_mat(rng.randf() < 0.75)])
		_:
			pass


static func _cap_mat(pink: bool) -> Material:
	var key := "cap_pink" if pink else "cap_lime"
	if not _baked.has(key):
		var col := Color(0.85, 0.42, 0.66) if pink else Color(0.6, 0.78, 0.35)
		_baked[key] = U.mat(col.lerp(Color(0.45, 0.4, 0.4), 0.45), 0.7)   # dull, unlit: glowing pink means spores
	return _baked[key]


static func _place(room: Room, p: Vector3, turn := true) -> Node3D:
	var n := Node3D.new()
	n.position = p
	if turn:
		n.rotation.y = randf() * TAU
	room.add_child(n)
	return n


static func _mesh(parent: Node3D, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


## Several simple shapes baked into one mesh, one surface per material.
## parts: [[mesh, transform, material], ...]
static func _bake(parts: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	var groups := {}
	for part in parts:
		if not groups.has(part[2]):
			groups[part[2]] = []
		groups[part[2]].append(part)
	for m: Material in groups:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[m]:
			st.append_from(part[0], 0, part[1])
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, m)
	return out


static func _sphere() -> SphereMesh:
	if not _baked.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 12
		s.rings = 6
		_baked["sphere"] = s
	return _baked["sphere"]


static func _cube() -> BoxMesh:
	if not _baked.has("cube"):
		_baked["cube"] = BoxMesh.new()
	return _baked["cube"]


## A cone or prism, `top` and `bottom` radii, `h` tall, centred on its middle.
static func _cone(top: float, bottom: float, h: float, sides := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


static func _xf(at: Vector3, scale: Vector3, basis := Basis.IDENTITY) -> Transform3D:
	return Transform3D(basis * Basis.from_scale(scale), at)


## Skulls heaped up, each looking outwards, with a few long bones (a small one for walls).
static func _skull_pile(big: bool) -> ArrayMesh:
	var key := "skulls_big" if big else "skulls"
	if _baked.has(key):
		return _baked[key]
	var bone := U.mat(Color(0.86, 0.82, 0.7), 0.85)
	var dark := U.mat(Color(0.07, 0.05, 0.06), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if big else 23
	var parts := []
	var count := 7 if big else 3
	for i in count:
		var a := rng.randf() * TAU
		var r := 0.0 if (big and i == 0) else rng.randf_range(0.22, 0.42) if big else rng.randf_range(0.0, 0.22)
		var s := rng.randf_range(0.17, 0.23)
		var at := Vector3(cos(a) * r, s * 0.9 + (0.24 if big and i == 0 else 0.0), sin(a) * r)
		var look := Vector3(cos(a), 0.15, sin(a)) if r > 0.05 else Vector3(0, 0.15, 1)
		var b := Basis.looking_at(look, Vector3.UP)   # the face is -Z
		parts.append([_sphere(), _xf(at, Vector3(s, s * 0.92, s * 1.05), b), bone])
		parts.append([_cube(), _xf(at + b * Vector3(0, -s * 0.62, -s * 0.38), Vector3(s * 0.95, s * 0.4, s * 0.7), b), bone])
		for ex in [-0.38, 0.38]:
			parts.append([_sphere(), _xf(at + b * Vector3(ex * s, s * 0.05, -s * 0.88), Vector3.ONE * s * 0.26), dark])
	var long := _cone(0.045, 0.045, 0.6, 6)
	for i in (4 if big else 1):
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI / 2)
		var a := rng.randf() * TAU
		parts.append([long, Transform3D(b, Vector3(cos(a) * 0.45, 0.05, sin(a) * 0.45)), bone])
	_baked[key] = _bake(parts)
	return _baked[key]


static func _ice() -> StandardMaterial3D:
	if not _baked.has("ice_mat"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.85, 1.0)
		m.roughness = 0.12
		m.metallic_specular = 0.9
		m.emission_enabled = true
		m.emission = Color(0.25, 0.55, 0.85)
		m.emission_energy_multiplier = 0.7
		_baked["ice_mat"] = m
	return _baked["ice_mat"]


## Ice crystals growing out of a corner, leaning outwards.
static func _crystals() -> ArrayMesh:
	if _baked.has("crystals"):
		return _baked["crystals"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var parts := []
	for i in 6:
		var h := rng.randf_range(0.55, 1.35) if i > 0 else 1.5
		var a := i / 6.0 * TAU + rng.randf() * 0.5
		var lean := 0.0 if i == 0 else rng.randf_range(0.25, 0.55)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, lean)
		var at := Vector3(cos(a), 0, sin(a)) * (0.0 if i == 0 else 0.25)
		parts.append([_cone(0.03, 0.15 * h, h, 6), Transform3D(b, at + b * Vector3(0, h * 0.5, 0)), _ice()])
	_baked["crystals"] = _bake(parts)
	return _baked["crystals"]


## Icicles hanging from the top of a wall; +X points out of the wall.
static func _icicles() -> ArrayMesh:
	if _baked.has("icicles"):
		return _baked["icicles"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var parts := []
	for i in 7:
		var length := rng.randf_range(0.35, 1.0) * (1.3 if i == 3 else 1.0)
		var z := (i - 3) * 0.2 + rng.randf_range(-0.05, 0.05)
		parts.append([_cone(0.08, 0.0, length, 6), _xf(Vector3(0.08, -length * 0.5, z), Vector3.ONE), _ice()])
	parts.append([_cube(), _xf(Vector3(0.05, -0.04, 0), Vector3(0.12, 0.1, 1.5)), _ice()])
	_baked["icicles"] = _bake(parts)
	return _baked["icicles"]


## An iron brazier on three legs, full of glowing coals (the flames are added separately).
static func _brazier() -> ArrayMesh:
	if _baked.has("brazier"):
		return _baked["brazier"]
	var iron := U.mat(Color(0.13, 0.11, 0.11), 0.45)
	var coals := U.mat(Color(1.0, 0.38, 0.08), 0.9, 2.5)
	var parts := []
	parts.append([_cone(0.44, 0.22, 0.3, 12), _xf(Vector3(0, 0.7, 0), Vector3.ONE), iron])
	parts.append([_cone(0.48, 0.48, 0.06, 12), _xf(Vector3(0, 0.86, 0), Vector3.ONE), iron])
	for i in 3:
		var a := i / 3.0 * TAU
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.3)
		parts.append([_cube(), _xf(Vector3(cos(a) * 0.24, 0.3, sin(a) * 0.24), Vector3(0.07, 0.65, 0.07), b), iron])
	parts.append([_sphere(), _xf(Vector3(0, 0.84, 0), Vector3(0.4, 0.12, 0.4)), coals])
	_baked["brazier"] = _bake(parts)
	return _baked["brazier"]


## Lava glowing behind an iron grate set into a wall; +X points out of the wall.
static func _grate() -> ArrayMesh:
	if _baked.has("grate"):
		return _baked["grate"]
	var iron := U.mat(Color(0.1, 0.08, 0.08), 0.5)
	var lava := U.mat(Color(1.0, 0.42, 0.08), 0.9, 3.0)
	var parts := []
	parts.append([_cube(), _xf(Vector3(0.02, 0.9, 0), Vector3(0.04, 0.9, 1.1)), lava])
	parts.append([_cube(), _xf(Vector3(0.05, 0.4, 0), Vector3(0.1, 0.1, 1.3)), iron])
	parts.append([_cube(), _xf(Vector3(0.05, 1.4, 0), Vector3(0.1, 0.1, 1.3)), iron])
	for i in 5:
		parts.append([_cube(), _xf(Vector3(0.07, 0.9, (i - 2) * 0.25), Vector3(0.06, 1.0, 0.06)), iron])
	for z in [-0.6, 0.6]:
		parts.append([_cube(), _xf(Vector3(0.05, 0.9, z), Vector3(0.1, 1.1, 0.1)), iron])
	_baked["grate"] = _bake(parts)
	return _baked["grate"]


## A broken column in the corner, slick and green, with kelp growing up around it.
static func _kelp_column() -> ArrayMesh:
	if _baked.has("kelp_column"):
		return _baked["kelp_column"]
	var stone := U.mat(Color(0.36, 0.46, 0.44), 0.35)
	var moss := U.mat(Color(0.14, 0.32, 0.18), 0.8)
	var kelp := U.mat(Color(0.2, 0.52, 0.26), 0.55, 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var parts := []
	parts.append([_cone(0.36, 0.42, 0.9, 10), _xf(Vector3(0, 0.45, 0), Vector3.ONE), stone])
	parts.append([_cone(0.44, 0.48, 0.14, 10), _xf(Vector3(0, 0.07, 0), Vector3.ONE), stone])
	# The broken-off top, lying against the stump.
	parts.append([_cone(0.3, 0.33, 0.55, 10), _xf(Vector3(0.45, 0.28, 0.2), Vector3.ONE, Basis(Vector3.FORWARD, 1.35)), stone])
	parts.append([_sphere(), _xf(Vector3(0, 0.88, 0), Vector3(0.37, 0.07, 0.37)), moss])
	for i in 7:
		var a := i / 7.0 * TAU + rng.randf() * 0.6
		var h := rng.randf_range(0.8, 1.7)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, rng.randf_range(0.1, 0.35))
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.42, 0.62)
		parts.append([_cone(0.0, 0.06, h, 5), Transform3D(b * Basis.from_scale(Vector3(1.0, 1.0, 0.4)), at + b * Vector3(0, h * 0.5, 0)), kelp])
	_baked["kelp_column"] = _bake(parts)
	return _baked["kelp_column"]


## A stone drain in the wall pouring a thin fall of water into a splash; +X points out of
## the wall. The falling water is drawn by a little shader, so it runs.
static func _add_spout(n: Node3D) -> void:
	_mesh(n, _spout())
	var splash := U.floor_quad(n, Vector2(1.3, 1.3), _splash_mat(), Vector3(0.4, 0.03, 0))
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foam := U.floor_quad(n, Vector2(0.9, 0.9), _foam_mat(), Vector3(0.4, 0.04, 0))
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _spout() -> ArrayMesh:
	if _baked.has("spout"):
		return _baked["spout"]
	var stone := U.mat(Color(0.34, 0.44, 0.43), 0.5)
	var dark := U.mat(Color(0.02, 0.04, 0.05), 1.0)
	var parts := []
	parts.append([_cube(), _xf(Vector3(0.05, 1.75, 0), Vector3(0.1, 0.7, 0.7)), stone])
	parts.append([_cube(), _xf(Vector3(0.22, 1.62, 0), Vector3(0.36, 0.12, 0.3)), stone])
	parts.append([_cube(), _xf(Vector3(0.11, 1.8, 0), Vector3(0.04, 0.3, 0.36)), dark])
	parts.append([_cube(), _xf(Vector3(0.38, 0.8, 0), Vector3(0.22, 1.6, 0.34)), _falling_water()])
	_baked["spout"] = _bake(parts)
	return _baked["spout"]


static func _falling_water() -> ShaderMaterial:
	if _baked.has("fall_mat"):
		return _baked["fall_mat"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.45, 0.95, 0.85, 1.0);
varying vec3 p;
void vertex() {
	p = VERTEX;
}
float h(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}
void fragment() {
	// Streaks that run down at slightly different speeds, brighter where they land.
	float lane = floor(p.z * 30.0 + p.x * 20.0);
	float s = fract(p.y * 1.4 + TIME * (1.8 + h(lane)) + h(lane + 3.0));
	float streak = smoothstep(0.0, 0.6, s) * (0.4 + 0.6 * h(lane + 7.0));
	float foot = 1.0 - smoothstep(0.0, 0.5, p.y);
	ALBEDO = col.rgb * (0.06 + 0.4 * streak + 0.45 * foot);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_baked["fall_mat"] = m
	return m


static func _foam_mat() -> StandardMaterial3D:
	if not _baked.has("foam_mat"):
		var m := U.unlit(Color(0.7, 1.0, 0.95, 0.4), U.soft_circle()).duplicate()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_baked["foam_mat"] = m
	return _baked["foam_mat"]


static func _splash_mat() -> StandardMaterial3D:
	if not _baked.has("splash_mat"):
		var m := U.unlit(Color(0.55, 1.0, 0.9, 0.35), U.ring()).duplicate()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_baked["splash_mat"] = m
	return _baked["splash_mat"]


## A clump of mushrooms in a corner: one tall glowing toadstool leaning out of the corner,
## two middling ones and a few buttons around their feet, on a mound of dark moss.
static func _mushroom_clump() -> ArrayMesh:
	if _baked.has("mushrooms"):
		return _baked["mushrooms"]
	var moss := U.mat(Color(0.12, 0.13, 0.1), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var parts := []
	parts.append([_sphere(), _xf(Vector3(0, 0.0, 0), Vector3(0.75, 0.22, 0.75)), moss])
	# [height, cap radius, lean, distance out, angle]
	var plan := [[1.75, 0.62, 0.12, 0.0, 0.0], [1.05, 0.4, 0.38, 0.45, 2.2], [0.8, 0.32, 0.45, 0.48, 4.1],
		[0.38, 0.17, 0.3, 0.62, 1.0], [0.3, 0.14, 0.5, 0.6, 3.2], [0.42, 0.18, 0.25, 0.55, 5.3]]
	for m in plan:
		var a: float = m[4] + rng.randf() * 0.4
		var at := Vector3(cos(a), 0, sin(a)) * float(m[3])
		parts.append_array(FungalLook.mushroom_parts(m[0], m[1], m[2], at, -a, 6 if m[1] > 0.3 else 3))
	_baked["mushrooms"] = _bake(parts)
	return _baked["mushrooms"]


## Shelf fungus growing out of a wall in three tiers, glowing at the rim, with a pale stalk
## of tiny mushrooms below; +X points out of the wall.
static func _shelf_fungus() -> ArrayMesh:
	if _baked.has("shelf"):
		return _baked["shelf"]
	var mats := FungalLook.cap_materials()
	var parts := []
	var half := SphereMesh.new()
	half.radius = 1.0
	half.height = 1.0
	half.is_hemisphere = true
	half.radial_segments = 12
	half.rings = 3
	var tiers := [[1.55, 0.42, 0.0], [1.1, 0.32, 0.28], [0.75, 0.24, -0.22]]
	for t in tiers:
		var r: float = t[1]
		# A flattened half-dome stuck to the wall: wide along the wall, shallow out of it.
		parts.append([half, _xf(Vector3(0.0, t[0], t[2]), Vector3(r * 0.9, r * 0.32, r * 1.3)), mats[0]])
		parts.append([_cone(r * 0.85, r * 0.85, 0.05, 12), _xf(Vector3(0.0, t[0] - 0.02, t[2]), Vector3(1.0, 1.0, 1.5)), mats[1]])
		for k in 3:
			var z: float = t[2] + (k - 1) * r * 0.55
			parts.append([_sphere(), _xf(Vector3(r * 0.45, t[0] + r * 0.2, z), Vector3.ONE * r * 0.12), mats[2]])
	for k in 3:
		parts.append_array(FungalLook.mushroom_parts(0.22 + 0.06 * k, 0.09 + 0.02 * k, 0.4, Vector3(0.18, 0, (k - 1) * 0.22), 0.0, 3))
	_baked["shelf"] = _bake(parts)
	return _baked["shelf"]


## The soft pink light a clump of glowcaps throws on the floor around it (no real light:
## lights cost a lot on phones).
static func _glow_pool(n: Node3D, size: float, color := Color(1.0, 0.4, 0.82, 0.32)) -> void:
	var key := "glow_pool " + color.to_html()
	if not _baked.has(key):
		var m := U.unlit(color, U.soft_circle()).duplicate()
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_baked[key] = m
	var q := U.floor_quad(n, Vector2(size, size), _baked[key], Vector3(0, 0.035, 0))
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- Frostfall Hall

## The winter event's materials, made once: pine, snow, bark, gold, ribbons, lights.
static func _yule_mat(key: String) -> Material:
	var k := "yule_" + key
	if not _baked.has(k):
		match key:
			"pine": _baked[k] = U.mat(Color(0.06, 0.19, 0.1), 0.9)
			"bark": _baked[k] = U.mat(Color(0.2, 0.12, 0.07), 0.95)
			"cone": _baked[k] = U.mat(Color(0.3, 0.18, 0.09), 0.9)
			"berry": _baked[k] = U.mat(Color(0.75, 0.06, 0.06), 0.4)
			"gold": _baked[k] = U.mat(Color(1.0, 0.78, 0.3), 0.35, 1.8)
			"red": _baked[k] = U.mat(Color(0.62, 0.06, 0.07), 0.6)
			"green": _baked[k] = U.mat(Color(0.08, 0.34, 0.2), 0.6)
			"white": _baked[k] = U.mat(Color(0.82, 0.86, 0.92), 0.6)
			"ribbon": _baked[k] = U.mat(Color(0.95, 0.75, 0.3), 0.3)
			"lamp_warm": _baked[k] = U.mat(Color(1.0, 0.72, 0.38), 0.5, 3.0)
			"lamp_red": _baked[k] = U.mat(Color(1.0, 0.28, 0.2), 0.5, 3.0)
			"lamp_blue": _baked[k] = U.mat(Color(0.5, 0.85, 1.0), 0.5, 3.0)
	return _baked[k]


static func _snow_mat() -> Material:
	if not _baked.has("snow_mat"):
		_baked["snow_mat"] = U.mat(Color(0.86, 0.9, 0.97), 0.55)
	return _baked["snow_mat"]


## A pine tree in a corner, snow on every tier, little lights in its branches, a gold star
## on top and a pile of gifts at its foot.
static func _pine_tree() -> ArrayMesh:
	if _baked.has("pine_tree"):
		return _baked["pine_tree"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var parts := []
	parts.append([_cone(0.11, 0.14, 0.5, 8), _xf(Vector3(0, 0.25, 0), Vector3.ONE), _yule_mat("bark")])
	var tiers := [[0.95, 0.75, 0.42], [0.78, 0.68, 0.88], [0.6, 0.62, 1.3], [0.42, 0.56, 1.68], [0.24, 0.46, 2.0]]
	var lamps := ["lamp_warm", "lamp_warm", "lamp_red", "lamp_warm", "lamp_blue"]
	for i in tiers.size():
		var t: Array = tiers[i]
		var r: float = t[0]
		var h: float = t[1]
		var y: float = t[2]
		parts.append([_cone(0.0, r, h, 9), _xf(Vector3(0, y + h * 0.5, 0), Vector3.ONE, Basis(Vector3.UP, i * 0.35)), _yule_mat("pine")])
		# Snow lying on the tier, seen from above as a white ring.
		parts.append([_cone(r * 0.25, r * 0.82, h * 0.22, 9), _xf(Vector3(0, y + h * 0.42, 0), Vector3.ONE, Basis(Vector3.UP, i * 0.35)), _snow_mat()])
		var n := 3 + (tiers.size() - i)
		for j in n:
			var a := TAU * j / n + i * 0.9 + rng.randf() * 0.4
			var rr := r * 0.78
			parts.append([_sphere(), _xf(Vector3(cos(a) * rr, y + h * 0.12, sin(a) * rr), Vector3.ONE * 0.05), _yule_mat(lamps[(i + j) % lamps.size()])])
	# The star.
	for b in [Basis.IDENTITY, Basis(Vector3.UP, PI / 4)]:
		parts.append([_cone(0.0, 0.17, 0.2, 4), _xf(Vector3(0, 2.6, 0), Vector3.ONE, b), _yule_mat("gold")])
		parts.append([_cone(0.17, 0.0, 0.2, 4), _xf(Vector3(0, 2.4, 0), Vector3.ONE, b), _yule_mat("gold")])
	_add_gifts(parts, rng)
	_baked["pine_tree"] = _bake(parts)
	return _baked["pine_tree"]


## A wreath of pine with a red bow and berries, hung on a wall; +X points out of the wall.
static func _wreath() -> ArrayMesh:
	if _baked.has("wreath"):
		return _baked["wreath"]
	var parts := []
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.36
	ring.rings = 16
	ring.ring_segments = 8
	var face := Basis(Vector3.FORWARD, PI / 2)
	parts.append([ring, _xf(Vector3(0.1, 0, 0), Vector3(1.0, 1.0, 1.0), face), _yule_mat("pine")])
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		parts.append([_sphere(), _xf(Vector3(0.18, sin(a) * 0.28, cos(a) * 0.28), Vector3.ONE * 0.035), _yule_mat("berry")])
	for side in [-1.0, 1.0]:
		parts.append([_sphere(), _xf(Vector3(0.18, -0.26, side * 0.1), Vector3(0.05, 0.07, 0.11), Basis(Vector3.RIGHT, side * 0.5)), _yule_mat("red")])
		parts.append([_cube(), _xf(Vector3(0.17, -0.4, side * 0.05), Vector3(0.03, 0.2, 0.05), Basis(Vector3.RIGHT, side * 0.35)), _yule_mat("red")])
	parts.append([_sphere(), _xf(Vector3(0.2, -0.26, 0), Vector3.ONE * 0.045), _yule_mat("red")])
	_baked["wreath"] = _bake(parts)
	return _baked["wreath"]


## Three wrapped gifts at the foot of a corner piece, on its room side (+X and +Z).
static func _add_gifts(parts: Array, rng: RandomNumberGenerator) -> void:
	var gifts := [[Vector3(0.62, 0, 0.18), 0.42, "red"], [Vector3(0.25, 0, 0.66), 0.34, "green"], [Vector3(0.72, 0, 0.66), 0.28, "white"]]
	for g: Array in gifts:
		var at: Vector3 = g[0]
		var sz: float = g[1]
		var yaw := Basis(Vector3.UP, rng.randf_range(-0.5, 0.5))
		parts.append([_cube(), _xf(at + Vector3.UP * sz * 0.425, Vector3(sz, sz * 0.85, sz), yaw), _yule_mat(g[2])])
		parts.append([_cube(), _xf(at + Vector3.UP * sz * 0.425, Vector3(sz * 0.16, sz * 0.87, sz * 1.02), yaw), _yule_mat("ribbon")])
		parts.append([_cube(), _xf(at + Vector3.UP * sz * 0.425, Vector3(sz * 1.02, sz * 0.87, sz * 0.16), yaw), _yule_mat("ribbon")])
		for side in [-1.0, 1.0]:
			parts.append([_sphere(), _xf(at + Vector3.UP * sz * 0.9 + yaw * Vector3(side * sz * 0.13, 0, 0), Vector3(sz * 0.15, sz * 0.09, sz * 0.08), yaw), _yule_mat("ribbon")])


## A snowman with a skull for a head, coal buttons, stick arms and a red scarf (the near
## corners: low, so it never hides the hero from the camera).
static func _snowman() -> ArrayMesh:
	if _baked.has("snowman"):
		return _baked["snowman"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var parts := []
	var snow := _snow_mat()
	var bone := U.mat(Color(0.86, 0.82, 0.7), 0.85)
	var dark := U.mat(Color(0.05, 0.04, 0.045), 1.0)
	parts.append([_sphere(), _xf(Vector3(0, 0.36, 0), Vector3(0.45, 0.4, 0.45)), snow])
	parts.append([_sphere(), _xf(Vector3(0, 0.88, 0), Vector3(0.32, 0.3, 0.32)), snow])
	# The skull.
	parts.append([_sphere(), _xf(Vector3(0, 1.3, 0), Vector3(0.2, 0.19, 0.21)), bone])
	parts.append([_cube(), _xf(Vector3(0.0, 1.17, 0.1), Vector3(0.2, 0.08, 0.14)), bone])
	for ex in [-0.075, 0.075]:
		parts.append([_sphere(), _xf(Vector3(ex, 1.31, 0.17), Vector3.ONE * 0.05), dark])
	parts.append([_sphere(), _xf(Vector3(0, 1.24, 0.19), Vector3(0.02, 0.03, 0.02)), dark])
	# Coal buttons down the front (+Z) and the red scarf.
	for k in 3:
		parts.append([_sphere(), _xf(Vector3(0, 0.98 - k * 0.13 - (0.2 if k == 2 else 0.0), 0.3 - k * 0.01 + (0.1 if k == 2 else 0.0)), Vector3.ONE * 0.04), dark])
	parts.append([_cone(0.24, 0.27, 0.09, 12), _xf(Vector3(0, 1.1, 0), Vector3.ONE), _yule_mat("red")])
	parts.append([_cube(), _xf(Vector3(0.12, 0.95, 0.22), Vector3(0.09, 0.3, 0.03), Basis(Vector3.FORWARD, 0.15)), _yule_mat("red")])
	# Stick arms.
	for side in [-1.0, 1.0]:
		var arm := Basis(Vector3.FORWARD, side * 1.0)
		parts.append([_cone(0.015, 0.025, 0.6, 5), _xf(Vector3(side * 0.48, 1.0, 0), Vector3.ONE, arm), _yule_mat("bark")])
	# Turned to look out along the corner's diagonal, into the room.
	var turn := Transform3D(Basis(Vector3.UP, PI / 4), Vector3.ZERO)
	for part: Array in parts:
		part[1] = turn * part[1]
	_add_gifts(parts, rng)
	_baked["snowman"] = _bake(parts)
	return _baked["snowman"]


## Frostfall Hall's pillars: a great timber post on a stone foot, bound with iron, a collar
## of pine with a red bow and snow on top. As wide as the stone pillars it stands in for.
static func timber_post() -> ArrayMesh:
	if _baked.has("timber_post"):
		return _baked["timber_post"]
	var wood := U.mat(Color(0.24, 0.15, 0.09), 0.85)
	var stone := U.mat(Color(0.2, 0.2, 0.24), 0.9)
	var iron := U.mat(Color(0.12, 0.11, 0.12), 0.45)
	var h := Room.WALL_H + 0.4
	var parts := []
	parts.append([_cube(), _xf(Vector3(0, 0.15, 0), Vector3(1.15, 0.3, 1.15)), stone])
	parts.append([_cube(), _xf(Vector3(0, 0.34, 0), Vector3(0.95, 0.1, 0.95)), stone])
	parts.append([_cone(0.36, 0.38, h - 0.3, 8), _xf(Vector3(0, 0.3 + (h - 0.3) * 0.5, 0), Vector3.ONE, Basis(Vector3.UP, PI / 8)), wood])
	for y in [0.75, h - 0.45]:
		parts.append([_cone(0.4, 0.4, 0.1, 8), _xf(Vector3(0, y, 0), Vector3.ONE, Basis(Vector3.UP, PI / 8)), iron])
	# The pine collar with lights and a bow.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.33
	ring.outer_radius = 0.55
	ring.rings = 16
	ring.ring_segments = 8
	parts.append([ring, _xf(Vector3(0, 1.9, 0), Vector3(1.0, 0.8, 1.0)), _yule_mat("pine")])
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		parts.append([_sphere(), _xf(Vector3(cos(a) * 0.5, 1.95, sin(a) * 0.5), Vector3.ONE * 0.045), _yule_mat(["lamp_warm", "lamp_red", "lamp_warm", "lamp_blue"][i % 4])])
	parts.append([_sphere(), _xf(Vector3(0, 1.85, 0.52), Vector3(0.12, 0.08, 0.06)), _yule_mat("red")])
	# Snow on top: a cap seen from above.
	parts.append([_cone(0.3, 0.42, 0.14, 8), _xf(Vector3(0, h + 0.07, 0), Vector3.ONE), _snow_mat()])
	_baked["timber_post"] = _bake(parts)
	return _baked["timber_post"]




# ---------------------------------------------------------------- the Sandfall Tomb (v247)

static func _tomb_mat(key: String) -> Material:
	var k := "tomb_" + key
	if not _baked.has(k):
		match key:
			"stone": _baked[k] = U.mat(Color(0.5, 0.37, 0.24), 0.9)
			"stone_dark": _baked[k] = U.mat(Color(0.34, 0.24, 0.15), 0.9)
			"sand": _baked[k] = U.mat(Color(0.5, 0.39, 0.26), 0.95)
			"clay": _baked[k] = U.mat(Color(0.5, 0.25, 0.14), 0.8)
			"turq": _baked[k] = U.mat(Color(0.1, 0.44, 0.41), 0.5)
			"lapis": _baked[k] = U.mat(Color(0.08, 0.12, 0.33), 0.45)
			"gold": _baked[k] = U.mat(Color(0.78, 0.58, 0.22), 0.3)
			"ochre": _baked[k] = U.mat(Color(0.52, 0.37, 0.14), 0.5)
			"dark": _baked[k] = U.mat(Color(0.04, 0.03, 0.03), 1.0)
			"beetle": _baked[k] = U.mat(Color(0.05, 0.16, 0.14), 0.3)
	return _baked[k]


## A ring round a shape: a short wide cylinder, `r` across, `h` tall, at height `y`.
static func _band(parts: Array, r: float, h: float, y: float, mat: Material, sides := 12, at := Vector3.ZERO, scale := Vector3.ONE) -> void:
	parts.append([_cone(r, r, h, sides), _xf(at + Vector3(0, y, 0), scale), mat])


## An obelisk on a stepped plinth: a tall four-sided shaft of sandstone narrowing to a gold
## cap, a carved strip of signs down each face, and a dune of sand banked at its foot on the
## room side (+X and +Z). About as tall as the walls.
static func _obelisk() -> ArrayMesh:
	if _baked.has("obelisk"):
		return _baked["obelisk"]
	var parts := []
	var stone := _tomb_mat("stone")
	parts.append([_cube(), _xf(Vector3(0, 0.12, 0), Vector3(0.95, 0.24, 0.95)), _tomb_mat("stone_dark")])
	parts.append([_cube(), _xf(Vector3(0, 0.3, 0), Vector3(0.72, 0.14, 0.72)), stone])
	var h := 2.3
	var turn := Basis(Vector3.UP, PI / 4)
	parts.append([_cone(0.19, 0.3, h, 4), _xf(Vector3(0, 0.37 + h * 0.5, 0), Vector3.ONE, turn), stone])
	parts.append([_cone(0.0, 0.2, 0.34, 4), _xf(Vector3(0, 0.37 + h + 0.16, 0), Vector3.ONE, turn), _tomb_mat("gold")])
	# A narrow lapis channel down each face that looks into the room, inlaid with gold signs,
	# and a turquoise band low on the shaft.
	for face in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var across := Vector3(0, 0, 1) if face.x > 0.0 else Vector3(1, 0, 0)
		var lean := Basis(across, (-0.11 / h) * (1.0 if face.x > 0.0 else -1.0) * -1.0)
		var mid := 0.75 + 0.85
		var at_mid: Vector3 = face * ((0.3 - (mid - 0.37) / h * 0.11) * 0.7071 + 0.004) + Vector3.UP * mid
		var strip := Vector3(0.012, 1.7, 0.07) if face.x > 0.0 else Vector3(0.07, 1.7, 0.012)
		parts.append([_cube(), _xf(at_mid, strip, lean), _tomb_mat("lapis")])
		for k in 6:
			var y := 0.88 + k * 0.29
			var at: Vector3 = face * ((0.3 - (y - 0.37) / h * 0.11) * 0.7071 + 0.009) + Vector3.UP * y
			var mark := Vector3(0.012, 0.035 + 0.03 * (k % 2), 0.04) if face.x > 0.0 else Vector3(0.04, 0.035 + 0.03 * (k % 2), 0.012)
			parts.append([_cube(), _xf(at, mark, lean), _tomb_mat("gold")])
	_band(parts, 0.305, 0.06, 0.6, _tomb_mat("turq"), 4, Vector3.ZERO, Vector3.ONE)
	parts[parts.size() - 1][1] = Transform3D(turn, Vector3(0, 0.6, 0))
	# The dune at its foot.
	parts.append([_sphere(), _xf(Vector3(0.55, 0.02, 0.55), Vector3(0.6, 0.2, 0.42), Basis(Vector3.UP, -PI / 4)), _tomb_mat("sand")])
	parts.append([_sphere(), _xf(Vector3(0.2, 0.18, 0.62), Vector3(0.3, 0.14, 0.24)), _tomb_mat("sand")])
	_baked["obelisk"] = _bake(parts)
	return _baked["obelisk"]


## One canopic jar: a round clay belly with a turquoise band, a narrow neck and a lid
## carved as a little head, painted gold.
static func _jar_parts(parts: Array, at: Vector3, sz: float, basis := Basis.IDENTITY) -> void:
	var b := basis
	parts.append([_sphere(), Transform3D(b * Basis.from_scale(Vector3(0.26, 0.3, 0.26) * sz), at + b * Vector3(0, 0.3 * sz, 0)), _tomb_mat("clay")])
	parts.append([_cone(0.2 * sz, 0.27 * sz, 0.08 * sz, 12), Transform3D(b, at + b * Vector3(0, 0.36 * sz, 0)), _tomb_mat("turq")])
	parts.append([_cone(0.13 * sz, 0.17 * sz, 0.12 * sz, 10), Transform3D(b, at + b * Vector3(0, 0.6 * sz, 0)), _tomb_mat("clay")])
	parts.append([_sphere(), Transform3D(b * Basis.from_scale(Vector3(0.12, 0.13, 0.12) * sz), at + b * Vector3(0, 0.74 * sz, 0)), _tomb_mat("gold")])


## Three jars and a tipped one spilling sand, for the near corners (all low, so they never
## hide the hero from the camera).
static func _jars() -> ArrayMesh:
	if _baked.has("jars"):
		return _baked["jars"]
	var parts := []
	_jar_parts(parts, Vector3(0.05, 0, 0.05), 1.25)
	_jar_parts(parts, Vector3(0.55, 0, 0.0), 0.95)
	_jar_parts(parts, Vector3(0.0, 0, 0.52), 0.8)
	# On its side, mouth to the room, with sand run out of it.
	_jar_parts(parts, Vector3(0.48, 0.2, 0.5), 0.8, Basis(Vector3(1, 0, -1).normalized(), PI / 2))
	parts.append([_sphere(), _xf(Vector3(0.88, 0.02, 0.9), Vector3(0.42, 0.12, 0.3), Basis(Vector3.UP, -PI / 4)), _tomb_mat("sand")])
	parts.append([_sphere(), _xf(Vector3(0.3, 0.02, 0.3), Vector3(0.62, 0.14, 0.5), Basis(Vector3.UP, -PI / 4)), _tomb_mat("sand")])
	_baked["jars"] = _bake(parts)
	return _baked["jars"]


## A single jar standing against a side wall.
static func _jar() -> ArrayMesh:
	if _baked.has("jar"):
		return _baked["jar"]
	var parts := []
	_jar_parts(parts, Vector3.ZERO, 1.1)
	_jar_parts(parts, Vector3(0.12, 0, 0.36), 0.7)
	_baked["jar"] = _bake(parts)
	return _baked["jar"]


## A painted coffin standing on end against the far wall, its face out of the wall (+X):
## a gold body banded in turquoise and lapis, a striped lapis-and-gold headdress, a gold
## face and crossed arms.
static func _sarcophagus() -> ArrayMesh:
	if _baked.has("sarcophagus"):
		return _baked["sarcophagus"]
	var parts := []
	var flat := Vector3(0.62, 1.0, 1.0)
	parts.append([_cube(), _xf(Vector3(0.05, 0.08, 0), Vector3(0.5, 0.16, 0.8)), _tomb_mat("stone_dark")])
	parts.append([_cone(0.3, 0.26, 1.5, 12), _xf(Vector3(0.05, 0.9, 0), flat), _tomb_mat("ochre")])
	for k in 4:
		var y := 0.32 + k * 0.24
		var rr := 0.26 + (y - 0.15) / 1.5 * 0.04 + 0.012
		_band(parts, rr, 0.07, y, _tomb_mat("turq" if k % 2 == 0 else "lapis"), 12, Vector3(0.05, 0, 0), flat)
	# Crossed arms over the chest.
	for side in [-1.0, 1.0]:
		parts.append([_cone(0.035, 0.045, 0.5, 6), _xf(Vector3(0.24, 1.3, 0), Vector3.ONE, Basis(Vector3.RIGHT, side * 0.95)), _tomb_mat("gold")])
	# The headdress, falling to the shoulders in stripes, and the face.
	parts.append([_cone(0.22, 0.34, 0.55, 12), _xf(Vector3(0.03, 1.72, 0), flat), _tomb_mat("lapis")])
	for k in 3:
		_band(parts, 0.268 + k * 0.026, 0.04, 1.82 - k * 0.12, _tomb_mat("gold"), 12, Vector3(0.03, 0, 0), flat)
	parts.append([_sphere(), _xf(Vector3(0.03, 2.02, 0), Vector3(0.18, 0.2, 0.24)), _tomb_mat("lapis")])
	parts.append([_sphere(), _xf(Vector3(0.16, 1.88, 0), Vector3(0.1, 0.15, 0.13)), _tomb_mat("gold")])
	for ez in [-0.05, 0.05]:
		parts.append([_sphere(), _xf(Vector3(0.25, 1.92, ez), Vector3(0.02, 0.016, 0.03)), _tomb_mat("dark")])
	parts.append([_cube(), _xf(Vector3(0.24, 1.72, 0), Vector3(0.03, 0.1, 0.035)), _tomb_mat("gold")])
	_baked["sarcophagus"] = _bake(parts)
	return _baked["sarcophagus"]


## The Sandfall Tomb's pillars: a lotus column. A stepped foot, a round shaft of sandstone,
## painted bands under a capital that opens like a flower, and a square block on top. As
## wide as the stone pillars it stands in for.
static func lotus_column() -> ArrayMesh:
	if _baked.has("lotus"):
		return _baked["lotus"]
	var parts := []
	var stone := _tomb_mat("stone")
	var h := Room.WALL_H + 0.4
	parts.append([_cube(), _xf(Vector3(0, 0.12, 0), Vector3(1.15, 0.24, 1.15)), _tomb_mat("stone_dark")])
	parts.append([_cone(0.5, 0.52, 0.16, 16), _xf(Vector3(0, 0.32, 0), Vector3.ONE), stone])
	parts.append([_cone(0.36, 0.42, h - 1.1, 16), _xf(Vector3(0, 0.4 + (h - 1.1) * 0.5, 0), Vector3.ONE), stone])
	# Carved rings low on the shaft, then the painted bands under the capital.
	for k in 3:
		_band(parts, 0.425 - k * 0.004, 0.035, 0.62 + k * 0.1, _tomb_mat("stone_dark"), 16)
	var top := 0.4 + h - 1.1
	_band(parts, 0.375, 0.08, top - 0.3, _tomb_mat("turq"), 16)
	_band(parts, 0.375, 0.05, top - 0.22, _tomb_mat("gold"), 16)
	_band(parts, 0.375, 0.08, top - 0.15, _tomb_mat("lapis"), 16)
	_band(parts, 0.375, 0.05, top - 0.08, _tomb_mat("gold"), 16)
	# The flower: a bell of sandstone, eight turquoise petals around it.
	parts.append([_cone(0.58, 0.37, 0.55, 16), _xf(Vector3(0, top + 0.27, 0), Vector3.ONE), stone])
	for i in 8:
		var a := TAU * i / 8.0
		var out := Vector3(cos(a), 0, sin(a))
		var tilt := Basis(out.cross(Vector3.UP).normalized(), -0.42)
		parts.append([_cone(0.0, 0.1, 0.5, 4), _xf(Vector3(0, top + 0.26, 0) + out * 0.47, Vector3(1, 1, 0.35), tilt * Basis(Vector3.UP, -a)), _tomb_mat("turq")])
	parts.append([_cube(), _xf(Vector3(0, h - 0.05, 0), Vector3(1.0, 0.22, 1.0)), stone])
	_baked["lotus"] = _bake(parts)
	return _baked["lotus"]


## Sand pouring in through a crack high in a side wall: the dark crack, a stream of sand
## running down (a little shader, so it moves) and a cone of sand heaped where it lands.
## +X points out of the wall.
static func _add_sandfall(n: Node3D) -> void:
	_mesh(n, _sandfall())
	var heap := _mesh(n, _sand_heap())
	heap.position = Vector3(0.42, 0, 0)
	var dust := U.floor_quad(n, Vector2(1.5, 1.5), _sand_dust_mat(), Vector3(0.45, 0.05, 0))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _sandfall() -> ArrayMesh:
	if _baked.has("sandfall"):
		return _baked["sandfall"]
	var parts := []
	var wh := Room.WALL_H
	parts.append([_cube(), _xf(Vector3(0.02, wh - 0.25, 0), Vector3(0.05, 0.5, 0.12), Basis(Vector3.RIGHT, 0.2)), _tomb_mat("dark")])
	parts.append([_cube(), _xf(Vector3(0.02, wh - 0.6, 0.04), Vector3(0.04, 0.3, 0.07), Basis(Vector3.RIGHT, -0.3)), _tomb_mat("dark")])
	# A lip of sand spilling out of the crack, then the stream: a narrow cone of falling sand
	# that spreads as it falls.
	parts.append([_sphere(), _xf(Vector3(0.07, wh - 0.08, 0), Vector3(0.09, 0.05, 0.12)), _tomb_mat("sand")])
	parts.append([_cone(0.035, 0.17, wh - 0.12, 10), _xf(Vector3(0.3, (wh - 0.12) * 0.5 + 0.02, 0), Vector3.ONE), _falling_sand()])
	_baked["sandfall"] = _bake(parts)
	return _baked["sandfall"]


## A soft cloud of dust where the sand lands.
static func _sand_dust_mat() -> StandardMaterial3D:
	if not _baked.has("sand_dust"):
		var m := U.unlit(Color(0.62, 0.5, 0.34, 0.2), U.soft_circle()).duplicate()
		_baked["sand_dust"] = m
	return _baked["sand_dust"]


static func _sand_heap() -> ArrayMesh:
	if _baked.has("sand_heap"):
		return _baked["sand_heap"]
	var parts := []
	parts.append([_cone(0.04, 0.62, 0.3, 14), _xf(Vector3(0, 0.15, 0), Vector3(1.0, 1.0, 1.2)), _tomb_mat("sand")])
	parts.append([_sphere(), _xf(Vector3(0.35, 0.02, 0.1), Vector3(0.5, 0.1, 0.6)), _tomb_mat("sand")])
	_baked["sand_heap"] = _bake(parts)
	return _baked["sand_heap"]


## The stream of sand: grains running down in strands at slightly different speeds, thinner
## and broken up near the top, spreading and denser where it lands.
static func _falling_sand() -> ShaderMaterial:
	if _baked.has("sand_fall_mat"):
		return _baked["sand_fall_mat"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.86, 0.67, 0.42, 1.0);
varying vec3 p;
void vertex() {
	p = VERTEX;
}
float h(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}
void fragment() {
	// Strands of sand round the cone, each running down at its own speed, with grains
	// glinting in them; soft at the cone's edges, so it reads as a stream, not a pole.
	float lane = floor(atan(p.z, p.x - 0.3) * 4.0);
	float s = fract(p.y * 1.8 + TIME * (1.6 + 0.7 * h(lane)) + h(lane + 3.0));
	float strand = smoothstep(0.0, 0.5, s) * (0.45 + 0.55 * h(lane + 7.0));
	float grain = step(0.6, fract(sin(dot(floor(vec2(atan(p.z, p.x - 0.3) * 12.0, p.y * 30.0 + TIME * 55.0)), vec2(12.9898, 78.233))) * 43758.5453));
	float foot = 1.0 - smoothstep(0.0, 0.5, p.y);
	float edge = smoothstep(0.05, 0.55, abs(dot(NORMAL, VIEW)));
	ALBEDO = col.rgb * (0.75 + 0.25 * strand + 0.15 * grain);
	float top = smoothstep(2.5, 1.6, p.y);
	ALPHA = clamp((0.15 + 0.5 * strand + 0.25 * grain + 0.25 * foot) * edge * mix(0.55, 1.0, top), 0.0, 0.85);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_baked["sand_fall_mat"] = m
	return m



# ---------------------------------------------------------------- the Amethyst Mine (v248)

static func _mine_mat(key: String) -> Material:
	var k := "mine_" + key
	if not _baked.has(k):
		match key:
			"rock": _baked[k] = U.mat(Color(0.21, 0.19, 0.23), 0.95)
			"rock_dark": _baked[k] = U.mat(Color(0.13, 0.12, 0.15), 0.95)
			"wood": _baked[k] = U.mat(Color(0.27, 0.17, 0.095), 0.85)
			"iron": _baked[k] = U.mat(Color(0.15, 0.15, 0.17), 0.4)
			"crystal": _baked[k] = U.mat(Color(0.55, 0.22, 0.92), 0.2, 1.0)
			"crystal_pale": _baked[k] = U.mat(Color(0.74, 0.48, 1.0), 0.2, 0.6)
			"crystal_dim": _baked[k] = U.mat(Color(0.34, 0.15, 0.52), 0.3, 0.35)
			"lamp": _baked[k] = U.mat(Color(1.0, 0.7, 0.35), 0.5, 3.0)
			"hole": _baked[k] = U.mat(Color(0.018, 0.014, 0.024), 1.0)
			"shell": _baked[k] = U.mat(Color(0.42, 0.38, 0.4), 0.95)
	return _baked[k]


## One crystal: a six-sided prism `ln` long and `r` thick with a pointed tip, growing from
## `base` along `dir`.
static func _prism(parts: Array, base: Vector3, dir: Vector3, ln: float, r: float, mat: Material) -> void:
	var up := dir.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var b := Basis(side, up, side.cross(up)).orthonormalized()
	parts.append([_cone(r, r * 1.05, ln, 6), Transform3D(b, base + up * ln * 0.5), mat])
	parts.append([_cone(0.0, r, r * 1.8, 6), Transform3D(b, base + up * (ln + r * 0.9)), mat])


## A great cluster of amethyst in a far corner: crystals of every size bursting out of a
## heap of dark rock, leaning out into the room (+X and +Z), the biggest taller than a man.
static func _crystal_cluster() -> ArrayMesh:
	if _baked.has("crystal_cluster"):
		return _baked["crystal_cluster"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var parts := []
	for k in 4:
		var a := k * 1.7
		parts.append([_sphere(), _xf(Vector3(cos(a) * 0.3, 0.15, sin(a) * 0.3), Vector3(0.45, 0.32, 0.4), Basis(Vector3.UP, a)), _mine_mat("rock" if k % 2 == 0 else "rock_dark")])
	var big := [[Vector3(0, 0.2, 0), Vector3(0.15, 1, 0.15), 1.6, 0.17], [Vector3(0.2, 0.2, -0.1), Vector3(0.6, 1, 0.1), 1.1, 0.13],
		[Vector3(-0.1, 0.2, 0.25), Vector3(0.1, 1, 0.6), 1.15, 0.13], [Vector3(0.3, 0.15, 0.3), Vector3(0.7, 0.8, 0.7), 0.8, 0.11],
		[Vector3(-0.2, 0.2, -0.2), Vector3(-0.2, 1, -0.1), 0.95, 0.12]]
	for c: Array in big:
		_prism(parts, c[0], c[1], c[2], c[3], _mine_mat("crystal"))
	for i in 7:
		var a := rng.randf_range(-0.3, 1.9)
		var base := Vector3(cos(a) * 0.5, 0.08, sin(a) * 0.5)
		_prism(parts, base, Vector3(cos(a) * 1.2, rng.randf_range(0.5, 1.0), sin(a) * 1.2), rng.randf_range(0.2, 0.45), rng.randf_range(0.04, 0.07), _mine_mat("crystal_pale" if i % 3 == 0 else "crystal"))
	_baked["crystal_cluster"] = _bake(parts)
	return _baked["crystal_cluster"]


## A mine cart on its wheels, heaped with crystals and ore, standing along the wall.
static func _mine_cart() -> ArrayMesh:
	if _baked.has("mine_cart"):
		return _baked["mine_cart"]
	var parts := []
	var at := Vector3(0.35, 0, 0.1)
	parts.append([_cube(), _xf(at + Vector3(0, 0.5, 0), Vector3(0.95, 0.42, 0.62)), _mine_mat("wood")])
	for y in [0.32, 0.68]:
		parts.append([_cube(), _xf(at + Vector3(0, y, 0), Vector3(0.98, 0.06, 0.65)), _mine_mat("iron")])
	for x in [-0.47, 0.47]:
		parts.append([_cube(), _xf(at + Vector3(x, 0.5, 0), Vector3(0.05, 0.44, 0.66)), _mine_mat("iron")])
	parts.append([_cube(), _xf(at + Vector3(0, 0.3, 0), Vector3(0.7, 0.08, 0.5)), _mine_mat("iron")])
	for x in [-0.3, 0.3]:
		for z in [-0.33, 0.33]:
			parts.append([_cone(0.13, 0.13, 0.07, 10), _xf(at + Vector3(x, 0.14, z), Vector3.ONE, Basis(Vector3.RIGHT, PI / 2)), _mine_mat("iron")])
	parts.append([_sphere(), _xf(at + Vector3(0, 0.72, 0), Vector3(0.44, 0.14, 0.28)), _mine_mat("rock_dark")])
	var tips := [[Vector3(-0.2, 0.7, 0.05), Vector3(-0.3, 1, 0.1), 0.35], [Vector3(0.1, 0.72, -0.05), Vector3(0.1, 1, -0.2), 0.42],
		[Vector3(0.25, 0.7, 0.1), Vector3(0.4, 1, 0.3), 0.3], [Vector3(-0.05, 0.72, 0.15), Vector3(0, 1, 0.5), 0.26]]
	for t: Array in tips:
		_prism(parts, at + t[0], t[1], t[2], 0.06, _mine_mat("crystal"))
	# A pick leaning on it.
	parts.append([_cone(0.02, 0.024, 0.85, 6), _xf(at + Vector3(0.62, 0.42, 0.2), Vector3.ONE, Basis(Vector3.FORWARD, 0.35)), _mine_mat("wood")])
	for sd in [-1.0, 1.0]:
		parts.append([_cone(0.005, 0.028, 0.26, 5), _xf(at + Vector3(0.48 + sd * 0.12, 0.82 - sd * 0.04, 0.2), Vector3.ONE, Basis(Vector3.FORWARD, sd * 1.2)), _mine_mat("iron")])
	_baked["mine_cart"] = _bake(parts)
	return _baked["mine_cart"]


## Crystals breaking out of a side wall over a fall of rock; +X points out of the wall.
static func _wall_crystals() -> ArrayMesh:
	if _baked.has("wall_crystals"):
		return _baked["wall_crystals"]
	var parts := []
	parts.append([_sphere(), _xf(Vector3(0.1, 0.12, 0), Vector3(0.35, 0.22, 0.6)), _mine_mat("rock_dark")])
	parts.append([_sphere(), _xf(Vector3(0.05, 0.75, 0.05), Vector3(0.2, 0.35, 0.42)), _mine_mat("rock")])
	var cs := [[Vector3(0.1, 0.8, 0), Vector3(1, 0.5, 0), 0.55, 0.1], [Vector3(0.1, 0.7, 0.2), Vector3(1, 0.2, 0.6), 0.4, 0.08],
		[Vector3(0.1, 0.9, -0.2), Vector3(1, 0.9, -0.5), 0.45, 0.08], [Vector3(0.15, 0.2, 0.15), Vector3(0.8, 1, 0.3), 0.35, 0.07],
		[Vector3(0.12, 0.2, -0.2), Vector3(0.7, 1, -0.4), 0.28, 0.06]]
	for c: Array in cs:
		_prism(parts, c[0], c[1], c[2], c[3], _mine_mat("crystal" if c[3] > 0.07 else "crystal_pale"))
	_baked["wall_crystals"] = _bake(parts)
	return _baked["wall_crystals"]


## An old tunnel in the far wall, boarded up: a black opening in a timber frame, planks
## nailed across it and a lantern on a hook; +X points out of the wall.
static func _boarded_tunnel() -> ArrayMesh:
	if _baked.has("boarded_tunnel"):
		return _baked["boarded_tunnel"]
	var parts := []
	parts.append([_cube(), _xf(Vector3(0.02, 0.85, 0), Vector3(0.03, 1.7, 1.2)), _mine_mat("hole")])
	for z in [-0.66, 0.66]:
		parts.append([_cube(), _xf(Vector3(0.08, 0.92, z), Vector3(0.14, 1.84, 0.14)), _mine_mat("wood")])
	parts.append([_cube(), _xf(Vector3(0.09, 1.86, 0), Vector3(0.16, 0.16, 1.6)), _mine_mat("wood")])
	var planks := [[0.45, 0.18], [0.95, -0.12], [1.38, 0.22]]
	for pl: Array in planks:
		parts.append([_cube(), _xf(Vector3(0.1, pl[0], 0), Vector3(0.04, 0.17, 1.42), Basis(Vector3.RIGHT, pl[1])), _mine_mat("wood")])
	# The lantern: an iron cage round a warm light.
	parts.append([_cube(), _xf(Vector3(0.22, 1.73, 0.66), Vector3(0.16, 0.025, 0.025)), _mine_mat("iron")])
	parts.append([_sphere(), _xf(Vector3(0.32, 1.48, 0.66), Vector3(0.11, 0.14, 0.11)), _mine_mat("lamp")])
	parts.append([_cone(0.08, 0.13, 0.07, 6), _xf(Vector3(0.32, 1.65, 0.66), Vector3.ONE), _mine_mat("iron")])
	parts.append([_cone(0.13, 0.1, 0.05, 6), _xf(Vector3(0.32, 1.32, 0.66), Vector3.ONE), _mine_mat("iron")])
	for k in 3:
		var a := TAU * k / 3.0
		parts.append([_cube(), _xf(Vector3(0.32 + cos(a) * 0.11, 1.48, 0.66 + sin(a) * 0.11), Vector3(0.018, 0.3, 0.018)), _mine_mat("iron")])
	_baked["boarded_tunnel"] = _bake(parts)
	return _baked["boarded_tunnel"]


## A pile of ore against a side wall, a few crystals in it.
static func _ore_pile() -> ArrayMesh:
	if _baked.has("ore_pile"):
		return _baked["ore_pile"]
	var parts := []
	var rocks := [[Vector3(0, 0.14, 0), 0.26], [Vector3(0.22, 0.1, 0.2), 0.18], [Vector3(-0.15, 0.1, 0.25), 0.16], [Vector3(0.05, 0.32, 0.08), 0.16]]
	for i in rocks.size():
		var rk: Array = rocks[i]
		parts.append([_sphere(), _xf(rk[0], Vector3(1.0, 0.75, 0.9) * float(rk[1]), Basis(Vector3.UP, i * 1.3)), _mine_mat("rock" if i % 2 == 0 else "rock_dark")])
	_prism(parts, Vector3(0.05, 0.3, 0.1), Vector3(0.3, 1, 0.4), 0.22, 0.05, _mine_mat("crystal"))
	_prism(parts, Vector3(0.2, 0.15, 0.25), Vector3(0.8, 0.7, 0.5), 0.14, 0.04, _mine_mat("crystal_pale"))
	_baked["ore_pile"] = _bake(parts)
	return _baked["ore_pile"]


## The Amethyst Mine's pillars: a column of raw rock left standing to hold the roof, ragged
## and uneven, with amethyst growing out of it. As wide as the stone pillars it stands in for.
static func rock_column() -> ArrayMesh:
	if _baked.has("rock_column"):
		return _baked["rock_column"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var parts := []
	var h := Room.WALL_H + 0.4
	# A ragged core, flaring at the foot and where it meets the roof, knobbed with lumps.
	parts.append([_cone(0.42, 0.46, h, 7), _xf(Vector3(0, h * 0.5, 0), Vector3.ONE), _mine_mat("rock_dark")])
	parts.append([_cone(0.48, 0.62, 0.45, 7), _xf(Vector3(0, 0.22, 0), Vector3.ONE, Basis(Vector3.UP, 0.4)), _mine_mat("rock")])
	parts.append([_cone(0.6, 0.44, 0.5, 7), _xf(Vector3(0, h - 0.25, 0), Vector3.ONE, Basis(Vector3.UP, 0.9)), _mine_mat("rock")])
	for i in 11:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.35, h - 0.35)
		var sz := rng.randf_range(0.2, 0.34)
		parts.append([_sphere(), _xf(Vector3(cos(a) * 0.36, y, sin(a) * 0.36), Vector3(sz, sz * rng.randf_range(0.9, 1.5), sz), Basis(Vector3.UP, a)), _mine_mat("rock" if i % 2 == 0 else "rock_dark")])
	var cs := [[Vector3(0.42, 1.0, 0.2), Vector3(1, 0.6, 0.4), 0.55, 0.09], [Vector3(0.38, 0.95, -0.22), Vector3(0.8, 0.9, -0.6), 0.42, 0.08],
		[Vector3(-0.42, 0.35, 0.3), Vector3(-0.7, 0.8, 0.7), 0.45, 0.08], [Vector3(0.12, 1.85, 0.44), Vector3(0.2, 0.5, 1), 0.4, 0.07],
		[Vector3(0.46, 1.1, 0.0), Vector3(1, 0.3, 0.0), 0.3, 0.06]]
	for c: Array in cs:
		_prism(parts, c[0], c[1], c[2], c[3], _mine_mat("crystal"))
	_baked["rock_column"] = _bake(parts)
	return _baked["rock_column"]


# ---------------------------------------------------------------- the Whispering Library

## The Whispering Library's materials (floor 8, version 249), made once.
static func _lib_mat(key: String) -> Material:
	var k := "lib_" + key
	if not _baked.has(k):
		match key:
			"oak": _baked[k] = U.mat(Color(0.26, 0.15, 0.08), 0.6)
			"oak_dark": _baked[k] = U.mat(Color(0.13, 0.075, 0.04), 0.7)
			"brass": _baked[k] = U.mat(Color(0.66, 0.5, 0.22), 0.35)
			"paper": _baked[k] = U.mat(Color(0.8, 0.75, 0.62), 0.9)
			"wax": _baked[k] = U.mat(Color(0.86, 0.82, 0.68), 0.7)
			"flame": _baked[k] = U.mat(Color(1.0, 0.72, 0.35), 0.5, 3.0)
			"red": _baked[k] = U.mat(Color(0.36, 0.075, 0.065), 0.7)
			"green": _baked[k] = U.mat(Color(0.07, 0.2, 0.12), 0.7)
			"navy": _baked[k] = U.mat(Color(0.08, 0.11, 0.26), 0.7)
			"tan": _baked[k] = U.mat(Color(0.4, 0.28, 0.12), 0.7)
			"ghost": _baked[k] = U.mat(Color(0.3, 0.95, 0.78), 0.4, 1.2)
			"face": _baked[k] = U.mat(Color(0.78, 0.73, 0.58), 0.6)
			"dark": _baked[k] = U.mat(Color(0.03, 0.025, 0.02), 1.0)
			"sea": _baked[k] = U.mat(Color(0.1, 0.22, 0.27), 0.5)
			"land": _baked[k] = U.mat(Color(0.5, 0.41, 0.24), 0.7)
			"bone": _baked[k] = U.mat(Color(0.8, 0.76, 0.64), 0.85)
	return _baked[k]


const BOOK_COLOURS := ["red", "green", "navy", "tan"]


## Makes every part `k` times bigger, from the piece's origin.
static func _grow(parts: Array, k: float) -> void:
	var g := Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO)
	for part: Array in parts:
		part[1] = g * (part[1] as Transform3D)


## A closed book lying flat: its cover (`size` = width, thickness, depth) and the pages
## showing along three edges.
static func _book(parts: Array, at: Vector3, size: Vector3, basis: Basis, cover: String) -> void:
	parts.append([_cube(), Transform3D(basis * Basis.from_scale(size), at + basis * Vector3(0, size.y * 0.5, 0)), _lib_mat(cover)])
	parts.append([_cube(), Transform3D(basis * Basis.from_scale(Vector3(size.x - 0.012, size.y * 0.72, size.z - 0.014)),
		at + basis * Vector3(0.009, size.y * 0.5, 0)), _lib_mat("paper")])


## A stack of `count` books, each a little turned, from `at` up; returns the height of its top.
static func _book_stack(parts: Array, at: Vector3, count: int, rng: RandomNumberGenerator, big := 1.0) -> float:
	var y := 0.0
	for i in count:
		var sz := Vector3(rng.randf_range(0.26, 0.36), rng.randf_range(0.05, 0.09), rng.randf_range(0.2, 0.27)) * big
		var b := Basis(Vector3.UP, rng.randf_range(-0.35, 0.35))
		_book(parts, at + Vector3(rng.randf_range(-0.02, 0.02), y, rng.randf_range(-0.02, 0.02)), sz, b, BOOK_COLOURS[rng.randi() % 4])
		y += sz.y
	return y


## A candle standing at `at`: wax, a drip, a wick and its flame (no light: the flame glows).
static func _candle(parts: Array, at: Vector3, h: float) -> void:
	parts.append([_cone(0.032, 0.036, h, 8), _xf(at + Vector3(0, h * 0.5, 0), Vector3.ONE), _lib_mat("wax")])
	parts.append([_sphere(), _xf(at + Vector3(0.025, h * 0.7, 0.01), Vector3(0.018, 0.04, 0.018)), _lib_mat("wax")])
	parts.append([_sphere(), _xf(at + Vector3(0, h + 0.045, 0), Vector3(0.02, 0.045, 0.02)), _lib_mat("flame")])


## A tall lectern in a far corner, leaning its great open book towards the room (+X and +Z),
## a candle on an arm and books piled at its foot. Its pages fly round it (_add_pages).
static func _lectern() -> ArrayMesh:
	if _baked.has("lectern"):
		return _baked["lectern"]
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var at := Vector3(0.3, 0, 0.3)
	parts.append([_cone(0.2, 0.3, 0.1, 8), _xf(at + Vector3(0, 0.05, 0), Vector3.ONE), _lib_mat("oak_dark")])
	parts.append([_cone(0.07, 0.1, 0.95, 8), _xf(at + Vector3(0, 0.55, 0), Vector3.ONE), _lib_mat("oak")])
	parts.append([_cone(0.14, 0.08, 0.08, 8), _xf(at + Vector3(0, 1.05, 0), Vector3.ONE), _lib_mat("oak")])
	# The sloping desk, its long side across the room's diagonal, tilted towards the room.
	var across := Vector3(1, 0, -1).normalized()
	var b := Basis(across, 0.5) * Basis(Vector3.UP, PI / 4)
	var top := at + Vector3(0, 1.14, 0)
	parts.append([_cube(), Transform3D(b * Basis.from_scale(Vector3(0.66, 0.04, 0.48)), top), _lib_mat("oak_dark")])
	parts.append([_cube(), Transform3D(b * Basis.from_scale(Vector3(0.66, 0.05, 0.03)), top + b * Vector3(0, 0.03, 0.24)), _lib_mat("oak")])
	# The open book: a red cover and two fans of pages rising from the spine.
	parts.append([_cube(), Transform3D(b * Basis.from_scale(Vector3(0.6, 0.016, 0.4)), top + b * Vector3(0, 0.028, -0.01)), _lib_mat("red")])
	for sd in [-1.0, 1.0]:
		var pb := b * Basis(Vector3(0, 0, 1), -sd * 0.1)
		parts.append([_cube(), Transform3D(pb * Basis.from_scale(Vector3(0.27, 0.035, 0.36)), top + b * Vector3(sd * 0.14, 0.05, -0.01)), _lib_mat("paper")])
		# Lines of writing that glow faintly.
		for k in 4:
			parts.append([_cube(), Transform3D(pb * Basis.from_scale(Vector3(0.19, 0.004, 0.012)), top + b * Vector3(sd * 0.14, 0.07, -0.12 + k * 0.07)), _lib_mat("ghost")])
	# A candle on an arm.
	parts.append([_cube(), _xf(at + Vector3(-0.12, 0.98, 0.12), Vector3(0.025, 0.025, 0.34), Basis(Vector3.UP, PI / 4)), _lib_mat("brass")])
	parts.append([_cone(0.05, 0.03, 0.03, 8), _xf(at + Vector3(-0.24, 0.99, 0.24), Vector3.ONE), _lib_mat("brass")])
	_candle(parts, at + Vector3(-0.24, 1.0, 0.24), 0.15)
	# Books heaped at its foot.
	_book_stack(parts, at + Vector3(0.42, 0, -0.08), 4, rng)
	_book_stack(parts, at + Vector3(-0.08, 0, 0.42), 2, rng, 1.2)
	_grow(parts, 1.3)
	_baked["lectern"] = _bake(parts)
	return _baked["lectern"]


## The lectern's pages, torn loose and flying round it in a slow ring, bobbing and fluttering
## (a shader turns them; nothing moves on the CPU). They glow faintly with the whispering.
static func _add_pages(n: Node3D, at: Vector3) -> void:
	if not _baked.has("pages"):
		var parts := []
		var rng := RandomNumberGenerator.new()
		rng.seed = 62
		for i in 8:
			var a := TAU * i / 8.0 + rng.randf_range(-0.2, 0.2)
			var r := rng.randf_range(0.5, 0.75)
			var y := rng.randf_range(1.65, 2.45)
			var pb := Basis(Vector3.UP, -a) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.5, 0.5)) * Basis(Vector3(0, 0, 1), rng.randf_range(0.6, 1.2))
			parts.append([_cube(), Transform3D(pb * Basis.from_scale(Vector3(0.17, 0.006, 0.22)), Vector3(cos(a) * r, y, sin(a) * r)), _pages_mat()])
		_baked["pages"] = _bake(parts)
	var mi := _mesh(n, _baked["pages"])
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _pages_mat() -> ShaderMaterial:
	if not _baked.has("pages_mat"):
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 paper : source_color = vec4(0.85, 0.8, 0.66, 1.0);
uniform vec4 glow : source_color = vec4(0.35, 1.0, 0.82, 1.0);
varying float ph;
void vertex() {
	float a0 = atan(VERTEX.z, VERTEX.x);
	float r = length(VERTEX.xz);
	float t = TIME * 0.35;
	VERTEX.xz = vec2(cos(a0 + t), sin(a0 + t)) * r;
	VERTEX.y += sin(TIME * 1.1 + a0 * 3.0) * 0.08;
	NORMAL.xz = vec2(NORMAL.x * cos(t) - NORMAL.z * sin(t), NORMAL.x * sin(t) + NORMAL.z * cos(t));
	ph = a0;
}
void fragment() {
	ALBEDO = paper.rgb;
	ROUGHNESS = 0.9;
	EMISSION = glow.rgb * 0.22 * (0.6 + 0.4 * sin(TIME * 2.0 + ph * 5.0));
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_baked["pages_mat"] = m
	return _baked["pages_mat"]


## Books piled in a near corner (all low, so they never hide the hero), candles burning on
## them, a skull for a candlestick and an open book on the floor.
static func _book_pile() -> ArrayMesh:
	if _baked.has("book_pile"):
		return _baked["book_pile"]
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 63
	_book_stack(parts, Vector3(0.12, 0, 0.12), 5, rng, 1.15)
	var hb := _book_stack(parts, Vector3(0.62, 0, 0.08), 3, rng)
	_candle(parts, Vector3(0.6, hb, 0.08), 0.2)
	_candle(parts, Vector3(0.68, hb, 0.16), 0.12)
	var hc := _book_stack(parts, Vector3(0.08, 0, 0.62), 2, rng, 1.1)
	# A skull with a candle stuck on it.
	var sk := Vector3(0.08, hc, 0.62)
	parts.append([_sphere(), _xf(sk + Vector3(0, 0.1, 0), Vector3(0.1, 0.095, 0.11)), _lib_mat("bone")])
	parts.append([_cube(), _xf(sk + Vector3(0.03, 0.04, 0.04), Vector3(0.1, 0.05, 0.09), Basis(Vector3.UP, PI / 4)), _lib_mat("bone")])
	for e in [-1.0, 1.0]:
		var ep := Basis(Vector3.UP, PI / 4) * Vector3(e * 0.038, 0, 0.085)
		parts.append([_sphere(), _xf(sk + Vector3(0, 0.1, 0) + ep, Vector3.ONE * 0.026), _lib_mat("dark")])
	_candle(parts, sk + Vector3(0, 0.18, 0), 0.08)
	parts.append([_sphere(), _xf(sk + Vector3(0.02, 0.17, 0.02), Vector3(0.05, 0.02, 0.05)), _lib_mat("wax")])
	# An open book face up on the floor.
	var ob := Basis(Vector3.UP, -PI / 4 + 0.3)
	var oa := Vector3(0.62, 0, 0.62)
	parts.append([_cube(), Transform3D(ob * Basis.from_scale(Vector3(0.5, 0.014, 0.34)), oa + Vector3(0, 0.007, 0)), _lib_mat("navy")])
	for sd in [-1.0, 1.0]:
		parts.append([_cube(), Transform3D(ob * Basis(Vector3(0, 0, 1), -sd * 0.08) * Basis.from_scale(Vector3(0.23, 0.03, 0.31)), oa + ob * Vector3(sd * 0.12, 0.025, 0)), _lib_mat("paper")])
	_grow(parts, 1.35)
	_baked["book_pile"] = _bake(parts)
	return _baked["book_pile"]


## A library ladder leaning on the bookcases of a side wall (+X out of the wall), its hooks on
## a brass rail near the top and little brass wheels at its feet.
static func _ladder() -> ArrayMesh:
	if _baked.has("ladder"):
		return _baked["ladder"]
	var parts := []
	var foot := 0.58
	var top_y := 2.32
	var lean := atan2(foot - 0.06, top_y)
	var ln := Vector2(foot - 0.06, top_y).length()
	var b := Basis(Vector3(0, 0, 1), lean)
	var mid := Vector3((foot + 0.06) * 0.5, top_y * 0.5, 0)
	for z in [-0.24, 0.24]:
		parts.append([_cube(), Transform3D(b * Basis.from_scale(Vector3(0.05, ln, 0.05)), mid + Vector3(0, 0, z)), _lib_mat("oak")])
		parts.append([_cone(0.04, 0.04, 0.03, 10), _xf(Vector3(foot, 0.04, z), Vector3.ONE, Basis(Vector3.RIGHT, PI / 2)), _lib_mat("brass")])
		parts.append([_cube(), _xf(Vector3(0.05, top_y + 0.02, z), Vector3(0.09, 0.03, 0.03)), _lib_mat("brass")])
	for k in 7:
		var t := (k + 0.7) / 8.0
		parts.append([_cube(), _xf(Vector3(foot + (0.06 - foot) * t, top_y * t, 0), Vector3(0.04, 0.03, 0.5)), _lib_mat("oak_dark")])
	parts.append([_cube(), _xf(Vector3(0.035, top_y, 0), Vector3(0.025, 0.025, 1.8)), _lib_mat("brass")])
	_baked["ladder"] = _bake(parts)
	return _baked["ladder"]


## A tall clock against the far wall (+X out of the wall): its case, a hood round a pale face
## with black hands, a window down its trunk and the brass pendulum behind it.
static func _clock() -> ArrayMesh:
	if _baked.has("clock"):
		return _baked["clock"]
	var parts := []
	parts.append([_cube(), _xf(Vector3(0.2, 0.17, 0), Vector3(0.42, 0.34, 0.6)), _lib_mat("oak_dark")])
	parts.append([_cube(), _xf(Vector3(0.18, 0.95, 0), Vector3(0.34, 1.22, 0.46)), _lib_mat("oak")])
	parts.append([_cube(), _xf(Vector3(0.2, 1.84, 0), Vector3(0.42, 0.56, 0.58)), _lib_mat("oak_dark")])
	parts.append([_cube(), _xf(Vector3(0.21, 2.16, 0), Vector3(0.46, 0.08, 0.64)), _lib_mat("oak")])
	parts.append([_cone(0.0, 0.16, 0.12, 4), _xf(Vector3(0.2, 2.26, 0), Vector3(1.4, 1.0, 2.2), Basis(Vector3.UP, PI / 4)), _lib_mat("oak_dark")])
	parts.append([_sphere(), _xf(Vector3(0.2, 2.36, 0), Vector3.ONE * 0.04), _lib_mat("brass")])
	var face := Basis(Vector3(0, 0, 1), PI / 2)
	parts.append([_cone(0.215, 0.215, 0.02, 20), _xf(Vector3(0.415, 1.84, 0), Vector3.ONE, face), _lib_mat("brass")])
	parts.append([_cone(0.19, 0.19, 0.02, 20), _xf(Vector3(0.425, 1.84, 0), Vector3.ONE, face), _lib_mat("face")])
	for k in 12:
		var a := TAU * k / 12.0
		parts.append([_cube(), _xf(Vector3(0.437, 1.84 + cos(a) * 0.16, sin(a) * 0.16), Vector3(0.004, 0.035, 0.012), Basis(Vector3.RIGHT, -a)), _lib_mat("dark")])
	parts.append([_cube(), _xf(Vector3(0.44, 1.89, 0.02), Vector3(0.006, 0.11, 0.016), Basis(Vector3.RIGHT, 0.35)), _lib_mat("dark")])
	parts.append([_cube(), _xf(Vector3(0.442, 1.84, 0.055), Vector3(0.006, 0.016, 0.13)), _lib_mat("dark")])
	# The window and the pendulum.
	parts.append([_cube(), _xf(Vector3(0.355, 0.98, 0), Vector3(0.01, 0.78, 0.26)), _lib_mat("dark")])
	parts.append([_cube(), _xf(Vector3(0.36, 1.13, 0.03), Vector3(0.008, 0.48, 0.016), Basis(Vector3.RIGHT, 0.08)), _lib_mat("brass")])
	parts.append([_cone(0.07, 0.07, 0.015, 14), _xf(Vector3(0.365, 0.82, 0.05), Vector3.ONE, face), _lib_mat("brass")])
	_baked["clock"] = _bake(parts)
	return _baked["clock"]


## A great globe of the world on a three-legged stand, ringed in brass (+X out of the wall).
static func _globe() -> ArrayMesh:
	if _baked.has("globe"):
		return _baked["globe"]
	var parts := []
	var c := Vector3(0.48, 0, 0)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var out := Vector3(cos(a), 0, sin(a))
		var tilt := Basis(out.cross(Vector3.UP).normalized(), 0.32)
		parts.append([_cone(0.022, 0.03, 0.82, 6), _xf(c + out * 0.14 + Vector3(0, 0.39, 0), Vector3.ONE, tilt), _lib_mat("oak")])
		parts.append([_sphere(), _xf(c + out * 0.27 + Vector3(0, 0.03, 0), Vector3(0.04, 0.03, 0.04)), _lib_mat("brass")])
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.46
	ring.rings = 24
	ring.ring_segments = 6
	parts.append([ring, _xf(c + Vector3(0, 1.08, 0), Vector3.ONE), _lib_mat("oak_dark")])
	parts.append([_cone(0.05, 0.08, 0.1, 8), _xf(c + Vector3(0, 0.78, 0), Vector3.ONE), _lib_mat("oak_dark")])
	var gc := c + Vector3(0, 1.12, 0)
	var axis := Basis(Vector3(1, 0, 0), 0.41)
	parts.append([_sphere(), _xf(gc, Vector3.ONE * 0.36, axis), _lib_mat("sea")])
	var lands := [[Vector3(0.6, 0.5, 0.4), Vector3(0.16, 0.2, 0.05)], [Vector3(0.75, -0.1, 0.6), Vector3(0.12, 0.25, 0.05)],
		[Vector3(-0.3, 0.6, 0.7), Vector3(0.2, 0.12, 0.05)], [Vector3(0.9, 0.2, -0.3), Vector3(0.1, 0.14, 0.05)],
		[Vector3(-0.6, -0.3, 0.7), Vector3(0.12, 0.16, 0.05)], [Vector3(0.2, -0.6, 0.75), Vector3(0.14, 0.1, 0.05)]]
	for l: Array in lands:
		var d: Vector3 = (l[0] as Vector3).normalized()
		var lb := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
		parts.append([_sphere(), Transform3D(lb * Basis.from_scale(l[1]), gc + d * 0.345), _lib_mat("land")])
	var mer := TorusMesh.new()
	mer.inner_radius = 0.385
	mer.outer_radius = 0.41
	mer.rings = 24
	mer.ring_segments = 6
	parts.append([mer, Transform3D(axis * Basis(Vector3(0, 0, 1), PI / 2), gc), _lib_mat("brass")])
	parts.append([_sphere(), _xf(gc + axis * Vector3(0, 0.42, 0), Vector3.ONE * 0.03), _lib_mat("brass")])
	_baked["globe"] = _bake(parts)
	return _baked["globe"]


## Books stacked against a side wall (the "@books" piece of the KIT).
static func _wall_books() -> ArrayMesh:
	if _baked.has("wall_books"):
		return _baked["wall_books"]
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	_book_stack(parts, Vector3(0, 0, -0.12), 4, rng, 1.1)
	var h := _book_stack(parts, Vector3(0.05, 0, 0.26), 2, rng)
	_candle(parts, Vector3(0.05, h, 0.26), 0.14)
	_baked["wall_books"] = _bake(parts)
	return _baked["wall_books"]


## The Whispering Library's pillars: a square bookcase standing free, books on all four sides
## between oak posts, a plinth and a cornice, and a few books that glow with whispering. As wide
## as the stone pillars it stands in for.
static func bookcase_column() -> ArrayMesh:
	if _baked.has("bookcase_column"):
		return _baked["bookcase_column"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 65
	var parts := []
	var h := Room.WALL_H + 0.4
	parts.append([_cube(), _xf(Vector3(0, h * 0.5, 0), Vector3(0.72, h, 0.72)), _lib_mat("oak_dark")])
	for x in [-0.44, 0.44]:
		for z in [-0.44, 0.44]:
			parts.append([_cube(), _xf(Vector3(x, h * 0.5, z), Vector3(0.1, h, 0.1)), _lib_mat("oak")])
	parts.append([_cube(), _xf(Vector3(0, 0.08, 0), Vector3(1.0, 0.16, 1.0)), _lib_mat("oak_dark")])
	parts.append([_cube(), _xf(Vector3(0, h - 0.08, 0), Vector3(1.06, 0.16, 1.06)), _lib_mat("oak")])
	parts.append([_cube(), _xf(Vector3(0, h - 0.2, 0), Vector3(0.98, 0.08, 0.98)), _lib_mat("oak_dark")])
	var levels := [0.16, 0.68, 1.2, 1.72, 2.24]
	for k in levels.size():
		var y0: float = levels[k]
		if k > 0:
			parts.append([_cube(), _xf(Vector3(0, y0, 0), Vector3(0.96, 0.035, 0.96)), _lib_mat("oak")])
		var room := (h - 0.24 - y0) if k == levels.size() - 1 else 0.5
		for f in 4:
			var out := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][f] as Vector3
			var side := Vector3(out.z, 0, -out.x)
			var x := -0.38
			while x < 0.36:
				var w := rng.randf_range(0.045, 0.1)
				if x + w > 0.39:
					break
				if rng.randf() < 0.06:
					x += w
					continue
				var bh := minf(rng.randf_range(0.26, 0.44), room - 0.04)
				var lean := 0.0
				if rng.randf() < 0.08:
					lean = rng.randf_range(0.12, 0.25)
				var bb := Basis(out, lean) if absf(out.x) > 0.5 else Basis(out, -lean)
				var at := out * 0.425 + side * (x + w * 0.5) + Vector3(0, y0 + 0.018 + bh * 0.5, 0)
				var size := Vector3(0.15, bh, w) if absf(out.x) > 0.5 else Vector3(w, bh, 0.15)
				var col: String = "ghost" if rng.randf() < 0.025 else BOOK_COLOURS[rng.randi() % 4]
				parts.append([_cube(), Transform3D(bb * Basis.from_scale(size), at), _lib_mat(col)])
				x += w + rng.randf_range(0.0, 0.008)
	_baked["bookcase_column"] = _bake(parts)
	return _baked["bookcase_column"]


# ---------------------------------------------------------------- the Clockwork Foundry

## The Clockwork Foundry's materials (floor 9, version 250), made once.
static func _iron_mat(key: String) -> Material:
	var k := "iron_" + key
	if not _baked.has(k):
		match key:
			"iron": _baked[k] = U.mat(Color(0.19, 0.195, 0.21), 0.5)
			"iron_dark": _baked[k] = U.mat(Color(0.085, 0.085, 0.095), 0.6)
			"brass": _baked[k] = U.mat(Color(0.62, 0.46, 0.19), 0.35)
			"copper": _baked[k] = U.mat(Color(0.5, 0.26, 0.13), 0.4)
			"fire": _baked[k] = U.mat(Color(0.95, 0.24, 0.04), 0.6, 1.1)
			"coal": _baked[k] = U.mat(Color(0.05, 0.045, 0.045), 0.9)
			"face": _baked[k] = U.mat(Color(0.72, 0.68, 0.55), 0.6)
			"red": _baked[k] = U.mat(Color(0.48, 0.07, 0.05), 0.5)
			"rust": _baked[k] = U.mat(Color(0.32, 0.15, 0.07), 0.9)
	return _baked[k]


## Metal that turns or pumps by itself: a shader spins its mesh round the mesh's own X (axis
## 0) or Y (axis 1) axis, `speed` radians a second, or (axis 2) slides it up and down. Nothing
## moves on the CPU.
static func _moving_mat(key: String, axis: int, speed: float) -> ShaderMaterial:
	var k := "moving_%s_%d_%.2f" % [key, axis, speed]
	if not _baked.has(k):
		if not _baked.has("moving_shader"):
			var sh := Shader.new()
			sh.code = """
shader_type spatial;
uniform vec4 albedo : source_color = vec4(0.6, 0.45, 0.2, 1.0);
uniform float rough = 0.35;
uniform int axis = 1;
uniform float speed = 0.5;
void vertex() {
	float a = TIME * speed;
	mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	if (axis == 0) {
		VERTEX.yz = r * VERTEX.yz;
		NORMAL.yz = r * NORMAL.yz;
	} else if (axis == 1) {
		VERTEX.xz = r * VERTEX.xz;
		NORMAL.xz = r * NORMAL.xz;
	} else {
		VERTEX.y += sin(TIME * speed) * 0.32;
	}
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = rough;
}
"""
			_baked["moving_shader"] = sh
		var m := ShaderMaterial.new()
		m.shader = _baked["moving_shader"]
		var base := _iron_mat(key) as StandardMaterial3D
		m.set_shader_parameter("albedo", base.albedo_color)
		m.set_shader_parameter("rough", base.roughness)
		m.set_shader_parameter("axis", axis)
		m.set_shader_parameter("speed", speed)
		_baked[k] = m
	return _baked[k]


## A gear round its own Y axis, centred on `at`: a disc `r` across and `thick` deep with
## `teeth` square teeth, a raised rim and hub, and (big ones) four holes between spokes.
static func _gear_parts(parts: Array, at: Vector3, basis: Basis, r: float, teeth: int, thick: float, mat: Material, phase := 0.0) -> void:
	parts.append([_cone(r, r, thick, maxi(teeth * 2, 12)), Transform3D(basis, at), mat])
	var tw := TAU * r / teeth * 0.5
	for k in teeth:
		var a := TAU * k / teeth + phase
		var tb := basis * Basis(Vector3.UP, -a)
		parts.append([_cube(), Transform3D(tb * Basis.from_scale(Vector3(0.11 * r / 0.7 + 0.04, thick, tw)), at + basis * Vector3(cos(a), 0, sin(a)) * (r + 0.03)), mat])
	parts.append([_cone(r * 0.28, r * 0.28, thick * 1.6, 12), Transform3D(basis, at), mat])
	parts.append([_cone(r * 0.1, r * 0.1, thick * 1.9, 8), Transform3D(basis, at), _iron_mat("iron_dark")])


## A gear on its own MeshInstance, turning (axis 0 = its X, 1 = its Y) at `speed`.
static func _turning_gear(parent: Node3D, at: Vector3, axis: int, r: float, teeth: int, thick: float, key: String, speed: float, phase := 0.0) -> MeshInstance3D:
	var mk := "gear_%d_%.2f_%d_%.2f_%s_%.2f" % [axis, r, teeth, thick, key, phase]
	if not _baked.has(mk):
		var parts := []
		var b := Basis(Vector3(0, 0, 1), PI / 2) if axis == 0 else Basis.IDENTITY
		_gear_parts(parts, Vector3.ZERO, b, r, teeth, thick, _moving_mat(key, axis, speed), phase)
		# (the hub's dark axle turns too: give it the turning material's twin in iron)
		parts[parts.size() - 1][2] = _moving_mat("iron_dark", axis, speed)
		_baked[mk] = _bake(parts)
	var mi := _mesh(parent, _baked[mk])
	mi.position = at
	return mi


## A boiler in a far corner (+X and +Z into the room): a riveted iron tank with a domed top,
## its fire door open and glowing, coal heaped in front, a gauge, a chimney to the roof and a
## copper pipe into the wall.
static func _boiler() -> ArrayMesh:
	if _baked.has("boiler"):
		return _baked["boiler"]
	var parts := []
	var c := Vector3(0.42, 0, 0.42)
	var d := Vector3(1, 0, 1).normalized()
	parts.append([_cone(0.62, 0.66, 0.2, 16), _xf(c + Vector3(0, 0.1, 0), Vector3.ONE), _iron_mat("iron_dark")])
	parts.append([_cone(0.6, 0.6, 1.5, 16), _xf(c + Vector3(0, 0.95, 0), Vector3.ONE), _iron_mat("iron")])
	parts.append([_sphere(), _xf(c + Vector3(0, 1.7, 0), Vector3(0.6, 0.28, 0.6)), _iron_mat("iron")])
	for y in [0.3, 0.95, 1.6]:
		_band(parts, 0.62, 0.06, y, _iron_mat("brass"), 16, c)
		for k in 12:
			var a := TAU * k / 12.0
			parts.append([_sphere(), _xf(c + Vector3(cos(a) * 0.62, y + 0.06, sin(a) * 0.62), Vector3.ONE * 0.025), _iron_mat("iron_dark")])
	# The fire door, open: a black frame round the glowing coals, the door swung aside.
	var face := Basis(Vector3.UP, -PI / 4)
	var door := c + d * 0.58 + Vector3(0, 0.55, 0)
	parts.append([_cube(), Transform3D(face * Basis.from_scale(Vector3(0.12, 0.42, 0.46)), door), _iron_mat("iron_dark")])
	parts.append([_cube(), Transform3D(face * Basis.from_scale(Vector3(0.1, 0.3, 0.34)), door + d * 0.02), _iron_mat("fire")])
	var side := Vector3(1, 0, -1).normalized()
	parts.append([_cube(), Transform3D(Basis(Vector3.UP, PI / 4 - 1.2) * Basis.from_scale(Vector3(0.04, 0.4, 0.42)), door + d * 0.12 + side * 0.36), _iron_mat("iron")])
	# Coal heaped in front, a few lumps glowing.
	for k in 5:
		var a := k * 1.3
		var at := c + d * (0.85 + 0.12 * sin(a)) + side * (0.25 * cos(a * 1.7))
		parts.append([_sphere(), _xf(at + Vector3(0, 0.07, 0), Vector3(0.13, 0.08, 0.11), Basis(Vector3.UP, a)), _iron_mat("coal" if k % 3 else "fire")])
	# A gauge and a red valve wheel.
	var g := c + d * 0.6 + Vector3(0, 1.28, 0)
	parts.append([_cone(0.13, 0.13, 0.05, 16), Transform3D(face * Basis(Vector3(0, 0, 1), PI / 2), g), _iron_mat("brass")])
	parts.append([_cone(0.1, 0.1, 0.02, 16), Transform3D(face * Basis(Vector3(0, 0, 1), PI / 2), g + d * 0.03), _iron_mat("face")])
	parts.append([_cube(), Transform3D(face * Basis(Vector3.RIGHT, 0.7) * Basis.from_scale(Vector3(0.01, 0.08, 0.012)), g + d * 0.045 + Vector3(0, 0.02, 0)), _iron_mat("red")])
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.13
	torus.rings = 16
	torus.ring_segments = 6
	parts.append([torus, Transform3D(Basis(side, PI / 2), c + side * 0.66 + Vector3(0, 1.05, 0)), _iron_mat("red")])
	# The chimney up to the roof, and a pipe into the wall.
	parts.append([_cone(0.13, 0.13, 1.5, 10), _xf(c + Vector3(-0.12, 2.5, -0.12), Vector3.ONE), _iron_mat("iron_dark")])
	parts.append([_cone(0.16, 0.16, 0.08, 10), _xf(c + Vector3(-0.12, 2.0, -0.12), Vector3.ONE), _iron_mat("brass")])
	parts.append([_cone(0.07, 0.07, 0.8, 10), _xf(c + Vector3(-0.55, 1.35, 0.1), Vector3.ONE, Basis(Vector3(0, 0, 1), PI / 2)), _iron_mat("copper")])
	_baked["boiler"] = _bake(parts)
	return _baked["boiler"]


## Gears and parts heaped in a near corner (low, so they never hide the hero): loose gears
## lying and leaning, an oil can and a big spanner.
static func _cog_pile() -> ArrayMesh:
	if _baked.has("cog_pile"):
		return _baked["cog_pile"]
	var parts := []
	var gears := [[Vector3(0.25, 0.04, 0.2), Basis.IDENTITY, 0.42, 12, "brass"], [Vector3(0.6, 0.1, 0.15), Basis.IDENTITY, 0.26, 9, "iron"],
		[Vector3(0.15, 0.3, 0.12), Basis(Vector3(1, 0, -1).normalized(), 1.2), 0.3, 10, "copper"],
		[Vector3(0.3, 0.12, 0.65), Basis(Vector3.RIGHT, 0.3), 0.22, 8, "iron"], [Vector3(0.62, 0.2, 0.55), Basis(Vector3(1, 0, 1).normalized(), 0.5), 0.18, 8, "brass"]]
	for g: Array in gears:
		_gear_parts(parts, g[0], g[1], g[2], g[3], 0.06, _iron_mat(g[4]))
	# An oil can with its long spout.
	var oc := Vector3(0.85, 0, 0.3)
	parts.append([_cone(0.09, 0.11, 0.16, 12), _xf(oc + Vector3(0, 0.08, 0), Vector3.ONE), _iron_mat("red")])
	parts.append([_cone(0.012, 0.03, 0.3, 6), _xf(oc + Vector3(0.1, 0.24, 0.0), Vector3.ONE, Basis(Vector3(0, 0, 1), -0.9)), _iron_mat("brass")])
	# A spanner on the floor.
	var sb := Basis(Vector3.UP, 0.6)
	parts.append([_cube(), Transform3D(sb * Basis.from_scale(Vector3(0.5, 0.03, 0.06)), Vector3(0.75, 0.015, 0.8)), _iron_mat("iron")])
	parts.append([_cone(0.07, 0.07, 0.03, 6), Transform3D(sb, Vector3(0.75, 0.015, 0.8) + sb * Vector3(0.27, 0, 0)), _iron_mat("iron")])
	_baked["cog_pile"] = _bake(parts)
	return _baked["cog_pile"]


## A side wall's machine (+X out of the wall): an iron plate bolted to the wall and two gears
## turning on it, a big one and a small one meshing with it, the other way and faster.
static func _add_wall_gears(n: Node3D) -> void:
	if not _baked.has("gear_plate"):
		var parts := []
		parts.append([_cube(), _xf(Vector3(0.03, 1.3, 0.35), Vector3(0.06, 1.9, 2.1)), _iron_mat("iron_dark")])
		for y in [0.45, 2.15]:
			for z in [-0.6, 1.3]:
				parts.append([_sphere(), _xf(Vector3(0.07, y, z), Vector3.ONE * 0.04), _iron_mat("brass")])
		_baked["gear_plate"] = _bake(parts)
	_no_shadow(_mesh(n, _baked["gear_plate"]))
	_no_shadow(_turning_gear(n, Vector3(0.13, 1.35, 0.0), 0, 0.68, 16, 0.08, "brass", 0.45))
	_no_shadow(_turning_gear(n, Vector3(0.15, 1.35, 1.14), 0, 0.38, 9, 0.08, "copper", -0.8, PI / 9))


## A piston by the far wall (+X out of the wall): an iron frame, a cylinder at its foot, and
## the rod and crosshead pumping up and down.
static func _add_piston(n: Node3D) -> void:
	if not _baked.has("piston"):
		var parts := []
		for z in [-0.38, 0.38]:
			parts.append([_cube(), _xf(Vector3(0.3, 1.2, z), Vector3(0.12, 2.4, 0.12)), _iron_mat("iron")])
		parts.append([_cube(), _xf(Vector3(0.3, 2.42, 0), Vector3(0.16, 0.16, 0.92)), _iron_mat("iron")])
		parts.append([_cone(0.28, 0.3, 0.6, 14), _xf(Vector3(0.3, 0.3, 0), Vector3.ONE), _iron_mat("iron_dark")])
		_band(parts, 0.31, 0.06, 0.58, _iron_mat("brass"), 14, Vector3(0.3, 0, 0))
		parts.append([_cone(0.07, 0.07, 0.9, 10), _xf(Vector3(-0.0, 0.35, 0.2), Vector3.ONE, Basis(Vector3(0, 0, 1), PI / 2)), _iron_mat("copper")])
		_baked["piston"] = _bake(parts)
		var rod := []
		rod.append([_cone(0.065, 0.065, 1.0, 10), _xf(Vector3(0.3, 1.1, 0), Vector3.ONE), _moving_mat("brass", 2, 1.7)])
		rod.append([_cube(), _xf(Vector3(0.3, 1.6, 0), Vector3(0.2, 0.14, 0.7)), _moving_mat("iron_dark", 2, 1.7)])
		_baked["piston_rod"] = _bake(rod)
	_mesh(n, _baked["piston"])
	_mesh(n, _baked["piston_rod"])


## Gears and a crate of parts against a side wall (the "@cogs" piece of the KIT).
static func _wall_cogs() -> ArrayMesh:
	if _baked.has("wall_cogs"):
		return _baked["wall_cogs"]
	var parts := []
	_gear_parts(parts, Vector3(0.05, 0.35, -0.1), Basis(Vector3(0, 0, 1), PI / 2 - 0.25), 0.3, 10, 0.06, _iron_mat("iron"))
	_gear_parts(parts, Vector3(0.1, 0.04, 0.3), Basis.IDENTITY, 0.22, 8, 0.06, _iron_mat("brass"))
	_gear_parts(parts, Vector3(0.12, 0.1, 0.32), Basis(Vector3.UP, 0.3), 0.14, 7, 0.05, _iron_mat("copper"))
	_baked["wall_cogs"] = _bake(parts)
	return _baked["wall_cogs"]


## The Clockwork Foundry's pillars: an eight-sided iron column, riveted, banded in brass, a
## copper pipe climbing it and a brass gear collar turning round it. As wide as the stone
## pillars it stands in for.
static func add_iron_column(n: Node3D) -> void:
	if not _baked.has("iron_column"):
		var parts := []
		var h := Room.WALL_H + 0.4
		parts.append([_cube(), _xf(Vector3(0, 0.12, 0), Vector3(0.95, 0.24, 0.95)), _iron_mat("iron_dark")])
		parts.append([_cone(0.38, 0.38, h, 8), _xf(Vector3(0, h * 0.5, 0), Vector3.ONE, Basis(Vector3.UP, PI / 8)), _iron_mat("iron")])
		parts.append([_cube(), _xf(Vector3(0, h - 0.1, 0), Vector3(0.92, 0.2, 0.92)), _iron_mat("iron_dark")])
		for y in [0.42, 2.55]:
			_band(parts, 0.41, 0.08, y, _iron_mat("brass"), 8)
			parts[parts.size() - 1][1] = Transform3D(Basis(Vector3.UP, PI / 8), Vector3(0, y, 0))
		for y in [0.95, 2.2]:
			for k in 8:
				var a := TAU * k / 8.0 + PI / 8
				parts.append([_sphere(), _xf(Vector3(cos(a) * 0.36, y, sin(a) * 0.36), Vector3.ONE * 0.03), _iron_mat("iron_dark")])
		parts.append([_cone(0.055, 0.055, h - 0.3, 8), _xf(Vector3(0.44, h * 0.5, 0.1), Vector3.ONE), _iron_mat("copper")])
		for y in [0.8, 2.3]:
			parts.append([_cube(), _xf(Vector3(0.4, y, 0.1), Vector3(0.1, 0.05, 0.14)), _iron_mat("iron_dark")])
		_baked["iron_column"] = _bake(parts)
	_mesh(n, _baked["iron_column"])
	_turning_gear(n, Vector3(0, 1.62, 0), 1, 0.52, 14, 0.12, "brass", 0.35)


## The Starfall Abyss (floor 10, version 255): moonstone, dark stone, silver, iron for the
## chains, and the glowing stuff of fallen stars (white-blue, and a few gold).
static func _abyss_mat(key: String) -> Material:
	var k := "abyss_" + key
	if not _baked.has(k):
		match key:
			"stone": _baked[k] = U.mat(Color(0.36, 0.37, 0.43), 0.75)
			"stone_dark": _baked[k] = U.mat(Color(0.15, 0.15, 0.19), 0.8)
			"silver": _baked[k] = U.mat(Color(0.62, 0.66, 0.78), 0.3)
			"iron": _baked[k] = U.mat(Color(0.13, 0.13, 0.15), 0.45)
			"star": _baked[k] = U.mat(Color(0.7, 0.78, 1.0), 0.3, 1.6)
			"gold": _baked[k] = U.mat(Color(1.0, 0.8, 0.45), 0.3, 1.4)
	return _baked[k]


## Stone that floats: a shader lifts its mesh up and down (`amp` metres, `speed`) and turns it
## slowly round its node's upright axis (`spin` radians a second), each prop on its own beat
## (from where it stands). Nothing moves on the CPU.
static func _drift_mat(key: String, amp: float, speed: float, spin := 0.0) -> ShaderMaterial:
	var k := "drift_%s_%.2f_%.2f_%.2f" % [key, amp, speed, spin]
	if not _baked.has(k):
		if not _baked.has("drift_shader"):
			var sh := Shader.new()
			sh.code = """
shader_type spatial;
uniform vec4 albedo : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform float rough = 0.75;
uniform float glow = 0.0;
uniform float amp = 0.1;
uniform float speed = 1.0;
uniform float spin = 0.0;
void vertex() {
	float ph = dot(NODE_POSITION_WORLD.xz, vec2(1.37, 0.71));
	float a = TIME * spin + ph;
	if (spin != 0.0) {
		mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
		VERTEX.xz = r * VERTEX.xz;
		NORMAL.xz = r * NORMAL.xz;
	}
	VERTEX.y += sin(TIME * speed + ph) * amp;
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = rough;
	EMISSION = albedo.rgb * glow;
}
"""
			_baked["drift_shader"] = sh
		var m := ShaderMaterial.new()
		m.shader = _baked["drift_shader"]
		var base := _abyss_mat(key) as StandardMaterial3D
		m.set_shader_parameter("albedo", base.albedo_color)
		m.set_shader_parameter("rough", base.roughness)
		m.set_shader_parameter("glow", base.emission_energy_multiplier if base.emission_enabled else 0.0)
		m.set_shader_parameter("amp", amp)
		m.set_shader_parameter("speed", speed)
		m.set_shader_parameter("spin", spin)
		_baked[k] = m
	return _baked[k]


## A rough lump of rock: a coarse, faceted ball squashed and turned, with a second chunk
## stuck to it so no two look alike.
static func _rock(parts: Array, at: Vector3, size: Vector3, basis: Basis, mat: Material) -> void:
	if not _baked.has("rock_mesh"):
		var m := SphereMesh.new()
		m.radial_segments = 6
		m.rings = 3
		m.radius = 1.0
		m.height = 2.0
		_baked["rock_mesh"] = m
	parts.append([_baked["rock_mesh"], Transform3D(basis * Basis.from_scale(size), at), mat])
	parts.append([_baked["rock_mesh"], Transform3D(basis * Basis(Vector3(1, 0, 1).normalized(), 0.9) * Basis.from_scale(size * 0.7), at + basis * Vector3(size.x * 0.45, -size.y * 0.25, 0)), mat])


## A cold star fire on its own quad (Fx.flame, recoloured white and violet-blue).
static func _star_flame(n: Node3D, size: Vector2, at: Vector3) -> void:
	var f := Fx.flame(n, size, at)
	if not _baked.has("star_flame"):
		var m := (f.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("hot", Color(0.95, 0.96, 1.0))
		m.set_shader_parameter("cool", Color(0.35, 0.38, 1.0))
		_baked["star_flame"] = m
	f.material_override = _baked["star_flame"]


## A far corner's brazier (+X and +Z into the room): a moonstone bowl on a fluted stand and a
## silver rim, burning with cold star fire, and three rocks circling slowly over it.
static func _add_star_brazier(n: Node3D) -> void:
	if not _baked.has("star_brazier"):
		var parts := []
		var c := Vector3(0.45, 0, 0.45)
		parts.append([_cone(0.5, 0.58, 0.22, 10), _xf(c + Vector3(0, 0.11, 0), Vector3.ONE), _abyss_mat("stone_dark")])
		parts.append([_cone(0.2, 0.28, 1.0, 8), _xf(c + Vector3(0, 0.72, 0), Vector3.ONE), _abyss_mat("stone")])
		parts.append([_cone(0.55, 0.22, 0.32, 12), _xf(c + Vector3(0, 1.36, 0), Vector3.ONE), _abyss_mat("stone")])
		_band(parts, 0.56, 0.05, 1.5, _abyss_mat("silver"), 12, c)
		# Star shards heaped in the bowl, glowing.
		for k in 6:
			var a := TAU * k / 6.0
			var tilt := Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP), 0.4)
			parts.append([_cone(0.0, 0.07, 0.24, 4), Transform3D(tilt, c + Vector3(cos(a) * 0.22, 1.56, sin(a) * 0.22)), _abyss_mat("star")])
		_baked["star_brazier"] = _bake(parts)
		var ring := []
		for k in 3:
			var a := TAU * k / 3.0
			_rock(ring, Vector3(cos(a) * 0.75, 2.45 + 0.12 * k, sin(a) * 0.75), Vector3(0.16, 0.12, 0.14) * (1.0 + 0.25 * k), Basis(Vector3.UP, a), _drift_mat("stone", 0.08, 1.1, 0.35))
		_baked["star_brazier_ring"] = _bake(ring)
	_mesh(n, _baked["star_brazier"])
	var orbit := Node3D.new()
	orbit.position = Vector3(0.45, 0, 0.45)
	n.add_child(orbit)
	_no_shadow(_mesh(orbit, _baked["star_brazier_ring"]))
	_star_flame(n, Vector2(0.6, 0.85), Vector3(0.45, 1.5, 0.45))
	_star_flame(n, Vector2(0.35, 0.55), Vector3(0.58, 1.5, 0.38))


## A near corner's heap (low, so it never hides the hero): broken moonstone blocks round a
## fallen star, a gold crystal stuck in a little crater, with splinters about it.
static func _star_rubble() -> ArrayMesh:
	if _baked.has("star_rubble"):
		return _baked["star_rubble"]
	var parts := []
	var blocks := [[Vector3(0.3, 0.15, 0.7), Vector3(0.5, 0.3, 0.35), 0.3], [Vector3(0.75, 0.12, 0.25), Vector3(0.4, 0.24, 0.45), -0.5],
		[Vector3(0.2, 0.1, 0.2), Vector3(0.35, 0.2, 0.3), 1.1], [Vector3(0.62, 0.32, 0.62), Vector3(0.3, 0.2, 0.28), 0.8]]
	for b: Array in blocks:
		parts.append([_cube(), _xf(b[0], b[1], Basis(Vector3.UP, b[2]) * Basis(Vector3.RIGHT, 0.15)), _abyss_mat("stone")])
	parts.append([_cone(0.42, 0.5, 0.06, 12), _xf(Vector3(0.55, 0.03, 0.55), Vector3.ONE), _abyss_mat("stone_dark")])
	parts.append([_cone(0.0, 0.17, 0.62, 5), Transform3D(Basis(Vector3(1, 0, -1).normalized(), 0.35), Vector3(0.55, 0.26, 0.55)), _abyss_mat("gold")])
	for k in 4:
		var a := k * 1.7
		parts.append([_cone(0.0, 0.06, 0.22, 4), Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 0.6), Vector3(0.55 + cos(a) * 0.3, 0.08, 0.55 + sin(a) * 0.3)), _abyss_mat("gold" if k % 2 else "star")])
	_baked["star_rubble"] = _bake(parts)
	return _baked["star_rubble"]


## A side wall's great chain (+X out of the wall): iron links as long as a man's arm, hung
## from high above the wall down to a ring bolted at its foot.
static func _great_chain() -> ArrayMesh:
	if _baked.has("great_chain"):
		return _baked["great_chain"]
	var parts := []
	var link := TorusMesh.new()
	link.inner_radius = 0.09
	link.outer_radius = 0.14
	link.rings = 12
	link.ring_segments = 6
	var top := Room.WALL_H + 1.6
	var y := top
	var k := 0
	while y > 0.35:
		var b := Basis(Vector3.RIGHT, PI / 2) * Basis.from_scale(Vector3(1.0, 1.0, 1.7))
		if k % 2 == 1:
			b = Basis(Vector3.UP, PI / 2) * b
		parts.append([link, Transform3D(b, Vector3(0.2, y, 0)), _abyss_mat("iron")])
		y -= 0.36
		k += 1
	var ring := TorusMesh.new()
	ring.inner_radius = 0.16
	ring.outer_radius = 0.22
	ring.rings = 14
	ring.ring_segments = 6
	parts.append([ring, Transform3D(Basis(Vector3(0, 0, 1), PI / 2), Vector3(0.16, 0.22, 0)), _abyss_mat("iron")])
	parts.append([_cube(), _xf(Vector3(0.04, 0.22, 0), Vector3(0.08, 0.36, 0.36)), _abyss_mat("stone_dark")])
	_baked["great_chain"] = _bake(parts)
	return _baked["great_chain"]


## By the far wall (+X out of the wall): a standing stone carved with a constellation in
## silver and glowing stars, its broken top floating a hand's breadth above it.
static func _add_monolith(n: Node3D) -> void:
	if not _baked.has("monolith"):
		var parts := []
		parts.append([_cube(), _xf(Vector3(0.3, 0.1, 0), Vector3(0.7, 0.2, 0.95)), _abyss_mat("stone_dark")])
		parts.append([_cube(), _xf(Vector3(0.3, 1.05, 0), Vector3(0.45, 1.7, 0.75)), _abyss_mat("stone")])
		var stars := [Vector2(0.2, 1.6), Vector2(-0.15, 1.35), Vector2(0.1, 1.05), Vector2(-0.2, 0.75), Vector2(0.18, 0.5)]
		for i in stars.size():
			var sp: Vector2 = stars[i]
			parts.append([_sphere(), _xf(Vector3(0.53, sp.y, sp.x), Vector3.ONE * 0.05), _abyss_mat("gold" if i == 2 else "star")])
			if i > 0:
				var a: Vector2 = stars[i - 1]
				var mid := (a + sp) * 0.5
				var d := sp - a
				var ang := atan2(d.x, d.y)
				parts.append([_cube(), Transform3D(Basis(Vector3.RIGHT, -ang) * Basis.from_scale(Vector3(0.01, d.length(), 0.012)), Vector3(0.528, mid.y, mid.x)), _abyss_mat("silver")])
		_baked["monolith"] = _bake(parts)
		var top := []
		top.append([_cube(), _xf(Vector3(0.3, 2.42, 0), Vector3(0.45, 0.5, 0.75), Basis(Vector3.RIGHT, 0.16)), _drift_mat("stone", 0.07, 0.9)])
		top.append([_sphere(), _xf(Vector3(0.53, 2.42, 0.05), Vector3.ONE * 0.06), _drift_mat("star", 0.07, 0.9)])
		top.append([_sphere(), _xf(Vector3(0.3, 2.06, 0), Vector3.ONE * 0.07), _drift_mat("star", 0.05, 1.3)])
		_baked["monolith_top"] = _bake(top)
	_mesh(n, _baked["monolith"])
	_mesh(n, _baked["monolith_top"])


## Rocks floating by a side wall (the "@float" piece of the KIT), bobbing gently.
static func _floating_rocks() -> ArrayMesh:
	if _baked.has("floating_rocks"):
		return _baked["floating_rocks"]
	var parts := []
	_rock(parts, Vector3(0.05, 0.75, 0.0), Vector3(0.26, 0.2, 0.24), Basis(Vector3.UP, 0.4), _drift_mat("stone", 0.09, 1.2))
	_rock(parts, Vector3(0.12, 1.25, 0.35), Vector3(0.14, 0.11, 0.13), Basis(Vector3.UP, 1.3), _drift_mat("stone", 0.09, 1.2))
	_rock(parts, Vector3(0.0, 0.45, -0.32), Vector3(0.12, 0.09, 0.1), Basis(Vector3.UP, 2.2), _drift_mat("stone", 0.09, 1.2))
	parts.append([_cone(0.0, 0.07, 0.22, 4), _xf(Vector3(0.05, 0.98, 0.0), Vector3.ONE), _drift_mat("star", 0.09, 1.2)])
	_baked["floating_rocks"] = _bake(parts)
	return _baked["floating_rocks"]


## A fallen star against a side wall (the "@star" piece of the KIT): a cluster of glowing
## crystals in a little crater of broken stone.
static func _fallen_star() -> ArrayMesh:
	if _baked.has("fallen_star"):
		return _baked["fallen_star"]
	var parts := []
	parts.append([_cone(0.32, 0.4, 0.06, 10), _xf(Vector3(0.05, 0.03, 0), Vector3.ONE), _abyss_mat("stone_dark")])
	var spikes := [[Vector3(0.05, 0.2, 0), 0.0, 0.0, 0.5], [Vector3(0.12, 0.14, 0.12), 0.5, 1.0, 0.32], [Vector3(-0.05, 0.12, -0.12), 0.6, 4.0, 0.3], [Vector3(0.15, 0.1, -0.08), 0.8, 2.4, 0.24]]
	for sp: Array in spikes:
		var b := Basis(Vector3.UP, sp[2]) * Basis(Vector3.RIGHT, sp[1])
		parts.append([_cone(0.0, 0.08 * sp[3] / 0.3, sp[3], 5), Transform3D(b, sp[0]), _abyss_mat("star")])
	for k in 4:
		var a := k * 1.6 + 0.3
		parts.append([_cube(), _xf(Vector3(0.05 + cos(a) * 0.32, 0.06, sin(a) * 0.32), Vector3(0.16, 0.1, 0.12), Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.4)), _abyss_mat("stone")])
	_baked["fallen_star"] = _bake(parts)
	return _baked["fallen_star"]


## The Starfall Abyss's pillars: a moonstone column broken in three, the lower piece standing
## on its plinth and the two above floating apart, bobbing on their own beats, the top one
## turning slowly, with starlight glowing in the gaps. As wide as the stone pillars it stands
## in for.
static func add_drift_column(n: Node3D) -> void:
	if not _baked.has("drift_column"):
		var parts := []
		parts.append([_cube(), _xf(Vector3(0, 0.14, 0), Vector3(1.0, 0.28, 1.0)), _abyss_mat("stone_dark")])
		parts.append([_cone(0.4, 0.43, 0.95, 10), _xf(Vector3(0, 0.75, 0), Vector3.ONE), _abyss_mat("stone")])
		_band(parts, 0.44, 0.06, 0.34, _abyss_mat("silver"), 10)
		# The break: a jagged top, and a little star glowing just above it in the gap.
		for k in 5:
			var a := TAU * k / 5.0
			parts.append([_cone(0.0, 0.14, 0.2, 4), _xf(Vector3(cos(a) * 0.26, 1.28, sin(a) * 0.26), Vector3.ONE, Basis(Vector3.UP, a)), _abyss_mat("stone")])
		parts.append([_sphere(), _xf(Vector3(0, 1.5, 0), Vector3.ONE * 0.09), _abyss_mat("star")])
		_baked["drift_column"] = _bake(parts)
		var mid := []
		mid.append([_cone(0.39, 0.4, 0.6, 10), _xf(Vector3(0, 1.95, 0), Vector3.ONE, Basis(Vector3.RIGHT, 0.06)), _drift_mat("stone", 0.07, 0.8)])
		mid.append([_sphere(), _xf(Vector3(0, 2.42, 0), Vector3.ONE * 0.07), _drift_mat("star", 0.07, 0.8)])
		_baked["drift_column_mid"] = _bake(mid)
		var top := []
		top.append([_cone(0.38, 0.39, 0.4, 10), _xf(Vector3(0, 2.85, 0), Vector3.ONE, Basis(Vector3(0, 0, 1), 0.1)), _drift_mat("stone", 0.11, 0.6, 0.15)])
		top.append([_cube(), _xf(Vector3(0, 3.12, 0), Vector3(0.95, 0.16, 0.95)), _drift_mat("stone_dark", 0.11, 0.6, 0.15)])
		top.append([_cone(0.45, 0.45, 0.04, 10), _xf(Vector3(0, 3.02, 0), Vector3.ONE), _drift_mat("silver", 0.11, 0.6, 0.15)])
		_baked["drift_column_top"] = _bake(top)
	_mesh(n, _baked["drift_column"])
	_mesh(n, _baked["drift_column_mid"])
	_mesh(n, _baked["drift_column_top"])


## Version 256: each floor's own cover for the rooms' "c" (a stack of crates) and "b" (a
## barrel) cells, named by "cover" in Floors.THEMES, instead of the same KayKit crates and
## barrels on every floor. Each is about as wide as the circle that blocks you (0.6 for "c",
## 0.45 for "b") and about as tall, so what you see is what stops you and your shots.
## False when the floor has none of its own yet (room.gd then places the KayKit piece).
static func add_cover(n: Node3D, cell: String) -> bool:
	match str(Floors.current().get("cover", "")) + ":" + cell:
		"ice:c": _mesh(n, _ice_block())
		"ice:b": _mesh(n, _frost_urn())
		"ember:c":
			_mesh(n, _pyre())
			Fx.flame(n, Vector2(0.55, 0.75), Vector3(0.18, 1.02, 0.06))
			Fx.flame(n, Vector2(0.38, 0.52), Vector3(-0.26, 0.94, -0.12))
		"ember:b":
			_mesh(n, _fire_cage())
			Fx.flame(n, Vector2(0.4, 0.5), Vector3(0, 0.52, 0))
		"grotto:c":
			_mesh(n, _mossy_logs())
			_glow_pool(n, 1.6)
		"grotto:b":
			_mesh(n, _hollow_stump())
			_glow_pool(n, 1.2)
		"sand:c":
			n.rotation.y = PI + randf_range(-0.7, 0.7)   # its face turned towards the camera
			_mesh(n, _fallen_head())
		"sand:b": _mesh(n, _scarab_statue())
		"wreck:c":
			n.rotation.y = PI / 2 + randf_range(-0.6, 0.6)   # the stern (and the legs) towards the camera
			_mesh(n, _upturned_boat())
		"mine:c":
			n.rotation.y = randf_range(-0.6, 0.6)   # the standing half's crystals towards the camera
			_mesh(n, _split_geode())
		"mine:b": _mesh(n, _ore_heap())
		"library:c":
			n.rotation.y = randf_range(-0.5, 0.5)   # the scribe's open book towards the camera
			_mesh(n, _scribe_desk())
		"library:b": _mesh(n, _hourglass())
		"wreck:b":
			n.rotation.y = randf_range(-0.8, 0.8)   # its front porthole turned towards the camera
			_mesh(n, _diving_helmet())
		_:
			return false
	return true


## A skull looking along `look` (its face is -Z of the basis), `s` across.
static func _skull(parts: Array, at: Vector3, s: float, look: Vector3, bone: Material, dark: Material) -> void:
	var b := Basis.looking_at(look, Vector3.UP)
	parts.append([_sphere(), _xf(at, Vector3(s, s * 0.92, s * 1.05), b), bone])
	parts.append([_cube(), _xf(at + b * Vector3(0, -s * 0.62, -s * 0.38), Vector3(s * 0.95, s * 0.4, s * 0.7), b), bone])
	for ex in [-0.38, 0.38]:
		parts.append([_sphere(), _xf(at + b * Vector3(ex * s, s * 0.05, -s * 0.88), Vector3.ONE * s * 0.26), dark])


## A bone (or any rod) from `a` to `b`, `r` thick.
static func _rod_part(parts: Array, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d := b - a
	var turn := Basis.IDENTITY
	if d.normalized().dot(Vector3.UP) < -0.999:
		turn = Basis(Vector3.RIGHT, PI)
	elif d.normalized().dot(Vector3.UP) < 0.999:
		turn = Basis(Quaternion(Vector3.UP, d.normalized()))
	parts.append([_cone(r, r, 1.0, 6), _xf((a + b) * 0.5, Vector3(1, d.length(), 1), turn), mat])


## Clear ice you can see into: nearly clear in the middle of each face, white frost along
## the edges (the box's own UVs: Godot lays a box out 3 by 2) and where the face turns away
## from you, with a faint cold glow. Made for boxes; a shader, so warmup.gd draws it first.
static func _clear_ice() -> ShaderMaterial:
	if not _baked.has("clear_ice"):
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
void fragment() {
	vec2 c = fract(UV * vec2(3.0, 2.0));
	float edge = 1.0 - smoothstep(0.015, 0.085, min(min(c.x, 1.0 - c.x), min(c.y, 1.0 - c.y)));
	float turn = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float frost = clamp(max(edge, turn * 0.7), 0.0, 1.0);
	ALBEDO = mix(vec3(0.4, 0.68, 0.93), vec3(0.88, 0.95, 1.0), frost);
	ALPHA = mix(0.2, 0.9, frost);
	ROUGHNESS = mix(0.05, 0.55, frost);
	SPECULAR = 0.8;
	EMISSION = vec3(0.16, 0.42, 0.78) * 0.35 + vec3(0.55, 0.78, 1.0) * frost * 0.3;
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		_baked["clear_ice"] = m
	return _baked["clear_ice"]


## The Frozen Ossuary's crates: a great block of clear ice with a skeleton frozen inside,
## its skull tipped back and one hand reaching up flat against the top, as if it was
## climbing out when the cold took it. Shards of blue ice break up through the top corners
## and white frost spreads over the floor round its foot.
static func _ice_block() -> ArrayMesh:
	if _baked.has("ice_block"):
		return _baked["ice_block"]
	var parts := []
	var ice := _clear_ice()
	var bone := U.mat(Color(0.9, 0.92, 0.94), 0.7, 0.18)
	var dark := U.mat(Color(0.04, 0.06, 0.1), 1.0)
	var lean := Basis(Vector3.FORWARD, 0.05)
	parts.append([_cube(), _xf(Vector3(0, 0.47, 0), Vector3(1.1, 0.94, 0.98), lean), ice])
	# Frost spread on the floor round it.
	parts.append([_cone(0.8, 0.8, 0.02, 9), _xf(Vector3(0.04, 0.012, 0.02), Vector3(1, 1, 0.85)), U.mat(Color(0.56, 0.67, 0.8), 0.6)])
	# The skeleton: skull tipped back, ribs, the spine down to the hips, legs folded under,
	# one arm down and one reaching up, its hand flat under the top.
	_skull(parts, Vector3(-0.12, 0.6, 0.1), 0.21, Vector3(0.1, 0.75, 1), bone, dark)
	_rod_part(parts, Vector3(-0.08, 0.44, -0.02), Vector3(0.04, 0.12, -0.08), 0.03, bone)
	for k in 4:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.14 - k * 0.014
		torus.outer_radius = 0.165 - k * 0.014
		torus.rings = 10
		torus.ring_segments = 4
		parts.append([torus, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(-0.06 + k * 0.02, 0.42 - k * 0.07, -0.03 - k * 0.015)), bone])
	_rod_part(parts, Vector3(0.04, 0.12, -0.08), Vector3(0.34, 0.24, 0.18), 0.03, bone)
	_rod_part(parts, Vector3(0.34, 0.24, 0.18), Vector3(0.1, 0.08, 0.3), 0.026, bone)
	_rod_part(parts, Vector3(0.04, 0.12, -0.08), Vector3(-0.3, 0.16, 0.16), 0.03, bone)
	_rod_part(parts, Vector3(-0.3, 0.16, 0.16), Vector3(-0.1, 0.06, 0.34), 0.026, bone)
	var shoulder := Vector3(0.12, 0.44, 0.0)
	var elbow := Vector3(0.3, 0.64, 0.1)
	var wrist := Vector3(0.26, 0.84, 0.2)
	_rod_part(parts, shoulder, elbow, 0.026, bone)
	_rod_part(parts, elbow, wrist, 0.022, bone)
	for f in 4:
		var spread := (f - 1.5) * 0.35
		var tip := wrist + Vector3(sin(spread) * 0.14, 0.05, cos(spread) * 0.14)
		_rod_part(parts, wrist, tip, 0.014, bone)
	_rod_part(parts, Vector3(-0.26, 0.42, -0.02), Vector3(-0.38, 0.22, -0.2), 0.026, bone)
	_rod_part(parts, Vector3(-0.38, 0.22, -0.2), Vector3(-0.2, 0.1, -0.32), 0.022, bone)
	# Shards of blue ice breaking up through the top.
	var shards := [[Vector3(-0.42, 0.9, -0.34), 0.5, Vector3(-0.3, 1, -0.2)], [Vector3(-0.22, 0.9, -0.4), 0.34, Vector3(0.1, 1, -0.35)],
		[Vector3(0.44, 0.9, -0.3), 0.42, Vector3(0.35, 1, -0.1)], [Vector3(0.4, 0.9, 0.38), 0.28, Vector3(0.3, 1, 0.3)],
		[Vector3(-0.44, 0.9, 0.32), 0.24, Vector3(-0.4, 1, 0.2)]]
	for sh in shards:
		var up: Vector3 = (sh[2] as Vector3).normalized()
		var ln: float = sh[1]
		parts.append([_cone(0.0, 0.09 + ln * 0.12, ln, 4), _xf(sh[0] + up * ln * 0.45, Vector3.ONE, Basis(Quaternion(Vector3.UP, up))), _ice()])
	_baked["ice_block"] = _bake(parts)
	return _baked["ice_block"]


## The Frozen Ossuary's barrels: a stone urn of the dead, round-bellied with a narrow neck,
## skulls heaped up out of its mouth, its lip crusted with ice and hung with icicles, blue ice
## crystals growing on its belly and frost spread round its foot.
static func _frost_urn() -> ArrayMesh:
	if _baked.has("frost_urn"):
		return _baked["frost_urn"]
	var parts := []
	var stone := U.mat(Color(0.3, 0.33, 0.4), 0.75)
	var bone := U.mat(Color(0.88, 0.88, 0.85), 0.8)
	var dark := U.mat(Color(0.05, 0.05, 0.07), 1.0)
	parts.append([_cone(0.56, 0.56, 0.02, 9), _xf(Vector3(0, 0.012, 0), Vector3.ONE), U.mat(Color(0.56, 0.67, 0.8), 0.6)])
	parts.append([_cone(0.2, 0.27, 0.1, 10), _xf(Vector3(0, 0.05, 0), Vector3.ONE), stone])
	parts.append([_cone(0.17, 0.2, 0.1, 10), _xf(Vector3(0, 0.15, 0), Vector3.ONE), stone])
	parts.append([_sphere(), _xf(Vector3(0, 0.46, 0), Vector3(0.42, 0.34, 0.42)), stone])
	parts.append([_cone(0.19, 0.3, 0.16, 10), _xf(Vector3(0, 0.78, 0), Vector3.ONE), stone])
	parts.append([_cone(0.27, 0.2, 0.08, 10), _xf(Vector3(0, 0.89, 0), Vector3.ONE), stone])
	# Two handles, one each side.
	for side in [-1.0, 1.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.07
		ring.outer_radius = 0.11
		ring.rings = 8
		ring.ring_segments = 4
		parts.append([ring, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(side * 0.36, 0.7, 0)), stone])
	# Skulls heaped up out of its mouth.
	_skull(parts, Vector3(0.0, 1.06, 0.02), 0.15, Vector3(0.2, 0.45, 1), bone, dark)
	_skull(parts, Vector3(0.12, 0.96, -0.1), 0.13, Vector3(1, 0.3, -0.4), bone, dark)
	_skull(parts, Vector3(-0.13, 0.96, -0.06), 0.13, Vector3(-1, 0.3, -0.2), bone, dark)
	# Ice crusted on the lip, icicles hanging from it, crystals growing on the belly.
	_band(parts, 0.29, 0.05, 0.92, _ice(), 10)
	for k in 9:
		var a := TAU * k / 9.0 + 0.2
		var ln := 0.12 + 0.12 * (k % 3) / 2.0
		parts.append([_cone(0.035, 0.0, ln, 5), _xf(Vector3(cos(a) * 0.27, 0.88 - ln * 0.5, sin(a) * 0.27), Vector3.ONE), _ice()])
	for k in 3:
		var a := TAU * k / 3.0 + 0.9
		var out := Vector3(cos(a), 0.0, sin(a))
		for j in 2:
			var up := (out + Vector3(0, 0.9 + j * 0.5, 0) + Vector3(-out.z, 0, out.x) * (j - 0.5) * 0.6).normalized()
			var ln := 0.16 - j * 0.04
			parts.append([_cone(0.0, 0.045, ln, 4), _xf(out * 0.38 + Vector3(0, 0.36 + j * 0.05, 0) + up * ln * 0.45, Vector3.ONE, Basis(Quaternion(Vector3.UP, up))), _ice()])
	_baked["frost_urn"] = _bake(parts)
	return _baked["frost_urn"]


## Embers glowing orange (not yellow: see the Foundry's fire) for the Ember Catacomb's cover.
static func _ember_mat(k: String) -> StandardMaterial3D:
	var key := "ember_" + k
	if not _baked.has(key):
		match k:
			"coals": _baked[key] = U.mat(Color(0.95, 0.26, 0.05), 0.9, 1.6)
			"char": _baked[key] = U.mat(Color(0.085, 0.065, 0.055), 0.95)
			"bone": _baked[key] = U.mat(Color(0.62, 0.56, 0.48), 0.9)
			"iron": _baked[key] = U.mat(Color(0.12, 0.1, 0.1), 0.45)
	return _baked[key]


## The Ember Catacomb's crates: a funeral pyre. Charred logs stacked crosswise four high,
## coals glowing deep inside and at the end of every log, and the dead laid on top, burning
## (room.gd's add_cover adds the flames).
static func _pyre() -> ArrayMesh:
	if _baked.has("pyre"):
		return _baked["pyre"]
	var parts := []
	var soot := _ember_mat("char")
	var coals := _ember_mat("coals")
	var bone := _ember_mat("bone")
	var wood := _cone(0.1, 0.1, 1.12, 7)
	var end := _cone(0.075, 0.075, 0.02, 7)
	for layer in 4:
		var y := 0.1 + layer * 0.19
		var across := layer % 2 == 1
		for side in [-1.0, 1.0]:
			var off: float = side * (0.4 - layer * 0.03)
			var at := Vector3(0, y, off) if not across else Vector3(off, y, 0)
			var turn := Basis(Vector3.FORWARD, PI / 2) if not across else Basis(Vector3.RIGHT, PI / 2)
			turn = Basis(Vector3.UP, (layer - 1.5) * 0.05) * turn
			parts.append([wood, _xf(at, Vector3.ONE, turn), soot])
			for e in [-0.565, 0.565]:
				parts.append([end, _xf(at + turn * Vector3(0, e, 0), Vector3.ONE, turn), coals])
	# The fire deep in the stack, showing between the logs, and a bed of coals on top.
	parts.append([_cube(), _xf(Vector3(0, 0.36, 0), Vector3(0.66, 0.56, 0.66)), coals])
	parts.append([_cube(), _xf(Vector3(0, 0.76, 0), Vector3(0.9, 0.05, 0.84)), soot])
	for c in [Vector3(0.3, 0.79, 0.28), Vector3(-0.1, 0.79, -0.3), Vector3(0.36, 0.79, -0.22)]:
		parts.append([_sphere(), _xf(c, Vector3(0.07, 0.03, 0.07)), coals])
	# The dead laid on top: skull, ribs, arms crossed, legs.
	_skull(parts, Vector3(-0.36, 0.92, 0.0), 0.18, Vector3(-0.3, 1, 0), bone, coals)
	for k in 4:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.1
		torus.outer_radius = 0.12
		torus.rings = 10
		torus.ring_segments = 4
		parts.append([torus, Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(-0.2 + k * 0.07, 0.86, 0)), bone])
	_rod_part(parts, Vector3(-0.24, 0.84, 0.0), Vector3(0.12, 0.82, 0.0), 0.025, bone)
	_rod_part(parts, Vector3(-0.2, 0.9, -0.12), Vector3(0.02, 0.93, 0.1), 0.022, bone)
	_rod_part(parts, Vector3(-0.2, 0.9, 0.12), Vector3(0.02, 0.93, -0.1), 0.022, bone)
	_rod_part(parts, Vector3(0.12, 0.83, -0.06), Vector3(0.44, 0.83, -0.1), 0.028, bone)
	_rod_part(parts, Vector3(0.12, 0.83, 0.06), Vector3(0.44, 0.84, 0.12), 0.028, bone)
	_baked["pyre"] = _bake(parts)
	return _baked["pyre"]


## The Ember Catacomb's barrels: a cage of black iron bars on a fire bowl, a skull burning
## inside it on a heap of coals, its eyes lit (room.gd's add_cover adds the flame).
static func _fire_cage() -> ArrayMesh:
	if _baked.has("fire_cage"):
		return _baked["fire_cage"]
	var parts := []
	var iron := _ember_mat("iron")
	var coals := _ember_mat("coals")
	var soot := _ember_mat("char")
	parts.append([_cone(0.36, 0.4, 0.1, 10), _xf(Vector3(0, 0.05, 0), Vector3.ONE), iron])
	parts.append([_cone(0.38, 0.32, 0.16, 10), _xf(Vector3(0, 0.18, 0), Vector3.ONE), iron])
	parts.append([_sphere(), _xf(Vector3(0, 0.27, 0), Vector3(0.3, 0.08, 0.3)), coals])
	# The skull burning on the coals: charred, its eyes and mouth lit.
	_skull(parts, Vector3(0, 0.42, 0.02), 0.17, Vector3(0, 0.25, 1), soot, coals)
	# Bars bulging out round it, a ring halfway and one at the top under a pointed cap.
	for k in 8:
		var a := TAU * k / 8.0
		var out := Vector3(cos(a), 0, sin(a))
		_rod_part(parts, out * 0.32 + Vector3(0, 0.24, 0), out * 0.37 + Vector3(0, 0.56, 0), 0.022, iron)
		_rod_part(parts, out * 0.37 + Vector3(0, 0.56, 0), out * 0.26 + Vector3(0, 0.9, 0), 0.022, iron)
	for ring in [[0.37, 0.56], [0.26, 0.9]]:
		var t := TorusMesh.new()
		t.inner_radius = ring[0] - 0.025
		t.outer_radius = ring[0] + 0.025
		t.rings = 12
		t.ring_segments = 4
		parts.append([t, Transform3D(Basis.IDENTITY, Vector3(0, ring[1], 0)), iron])
	parts.append([_cone(0.02, 0.27, 0.16, 8), _xf(Vector3(0, 0.98, 0), Vector3.ONE), iron])
	var hook := TorusMesh.new()
	hook.inner_radius = 0.04
	hook.outer_radius = 0.065
	hook.rings = 8
	hook.ring_segments = 4
	parts.append([hook, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 1.1, 0)), iron])
	_baked["fire_cage"] = _bake(parts)
	return _baked["fire_cage"]


## Mossy stone, old roots and bark for the Glowcap Grotto's cover.
static func _grotto_mat(k: String) -> StandardMaterial3D:
	var key := "grotto_" + k
	if not _baked.has(key):
		match k:
			"stone": _baked[key] = U.mat(Color(0.25, 0.28, 0.25), 0.9)
			"moss": _baked[key] = U.mat(Color(0.16, 0.28, 0.12), 0.95)
			"root": _baked[key] = U.mat(Color(0.3, 0.2, 0.12), 0.85)
			"bark": _baked[key] = U.mat(Color(0.22, 0.16, 0.11), 0.9)
			"heart": _baked[key] = U.mat(Color(0.12, 0.08, 0.05), 1.0)
			"rings": _baked[key] = U.mat(Color(0.5, 0.38, 0.26), 0.85)
			"bone": _baked[key] = U.mat(Color(0.78, 0.76, 0.66), 0.85)
	return _baked[key]


## The Glowcap Grotto's crates: two fallen trunks, one across the other, rotten hollow, mossy
## and sprouting glowcaps along their backs; a skull looks out of one hollow end and a bony
## arm reaches out of another (add_cover puts the caps' pink glow on the floor). (A boulder
## gripped by roots was tried first: from above, roots round a lump read as a spider's legs.)
static func _mossy_logs() -> ArrayMesh:
	if _baked.has("mossy_logs"):
		return _baked["mossy_logs"]
	var parts := []
	var bark := _grotto_mat("bark")
	var heart := _grotto_mat("heart")
	var rings := _grotto_mat("rings")
	var moss := _grotto_mat("moss")
	var bone := _grotto_mat("bone")
	var rim := TorusMesh.new()
	rim.inner_radius = 0.7
	rim.outer_radius = 1.0
	rim.rings = 9
	rim.ring_segments = 4
	# [middle, radius, length, turn about Y]
	var logs := [[Vector3(0, 0.3, 0.06), 0.3, 1.26, 0.15], [Vector3(-0.04, 0.74, -0.04), 0.21, 1.02, 1.35]]
	for lg in logs:
		var mid: Vector3 = lg[0]
		var r: float = lg[1]
		var ln: float = lg[2]
		var turn := Basis(Vector3.UP, lg[3]) * Basis(Vector3.FORWARD, PI / 2)   # its length along X
		parts.append([_cone(r, r * 1.04, ln, 9), _xf(mid, Vector3.ONE, turn), bark])
		for e in [-1.0, 1.0]:
			var end_at: Vector3 = mid + turn * Vector3(0, e * ln * 0.5, 0)
			parts.append([_cone(r * 0.72, r * 0.72, 0.02, 9), _xf(end_at, Vector3.ONE, turn), heart])
			parts.append([rim, _xf(end_at, Vector3(r, 0.06, r), turn), rings])
		# Moss along its back.
		for k in 3:
			var at: Vector3 = mid + turn * Vector3(-r * 0.85, (k - 1) * ln * 0.3, 0)   # (-X of the turned trunk is up)
			parts.append([_sphere(), _xf(at, Vector3(ln * 0.14, r * 0.25, r * 0.5), Basis(Vector3.UP, lg[3])), moss])
	# A skull looking out of the bottom trunk's hollow end, a bony arm reaching out of the other.
	var low := Basis(Vector3.UP, 0.15)
	_skull(parts, Vector3(0, 0.27, 0.06) + low * Vector3(0.6, 0, 0), 0.16, low * Vector3(1, 0.15, 0), bone, heart)
	var wrist := Vector3(0, 0.0, 0.06) + low * Vector3(-0.86, 0.05, 0.12)
	_rod_part(parts, Vector3(0, 0.22, 0.06) + low * Vector3(-0.5, 0, 0.04), wrist, 0.026, bone)
	for f in 4:
		var spread := (f - 1.5) * 0.4
		_rod_part(parts, wrist, wrist + low * Vector3(-cos(spread) * 0.12, -0.02, sin(spread) * 0.12), 0.014, bone)
	# Glowcaps along the top trunk and a shelf fungus on the lower one.
	parts.append_array(FungalLook.mushroom_parts(0.42, 0.2, 0.15, Vector3(-0.04, 0.92, -0.04) + Basis(Vector3.UP, 1.35) * Vector3(0.22, 0, 0), 0.4, 4))
	parts.append_array(FungalLook.mushroom_parts(0.26, 0.12, 0.45, Vector3(-0.04, 0.9, -0.04) + Basis(Vector3.UP, 1.35) * Vector3(-0.2, 0, 0.06), 2.6, 3))
	parts.append_array(FungalLook.mushroom_parts(0.22, 0.1, 0.5, Vector3(0, 0.56, 0.06) + low * Vector3(0.34, 0, -0.12), 4.2, 2))
	_baked["mossy_logs"] = _bake(parts)
	return _baked["mossy_logs"]


## The Glowcap Grotto's barrels: the stump of a great tree, its roots spread over the floor,
## hollow inside with a skull looking out of the dark, glowing shelf fungus up one side and
## a ring of tiny glowcaps round its broken rim.
static func _hollow_stump() -> ArrayMesh:
	if _baked.has("hollow_stump"):
		return _baked["hollow_stump"]
	var parts := []
	var bark := _grotto_mat("bark")
	parts.append([_cone(0.3, 0.38, 0.8, 9), _xf(Vector3(0, 0.4, 0), Vector3.ONE), bark])
	# The broken rim: a jagged crown of bark, the hollow dark inside.
	for k in 9:
		var a := TAU * k / 9.0
		var h := 0.12 + 0.14 * float((k * 5) % 3) / 2.0
		parts.append([_cone(0.0, 0.07, h, 4), _xf(Vector3(cos(a) * 0.27, 0.8 + h * 0.5, sin(a) * 0.27), Vector3.ONE, Basis(Vector3(-sin(a), 0, cos(a)), -0.15)), bark])
	parts.append([_cone(0.25, 0.25, 0.02, 9), _xf(Vector3(0, 0.79, 0), Vector3.ONE), _grotto_mat("heart")])
	var rim := TorusMesh.new()
	rim.inner_radius = 0.23
	rim.outer_radius = 0.31
	rim.rings = 9
	rim.ring_segments = 4
	parts.append([rim, _xf(Vector3(0, 0.8, 0), Vector3(1, 0.3, 1)), _grotto_mat("rings")])
	# Roots spreading out over the floor.
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var out := Vector3(cos(a), 0, sin(a))
		_rod_part(parts, out * 0.3 + Vector3(0, 0.3, 0), out * 0.52 + Vector3(0, 0.08, 0), 0.08, bark)
		_rod_part(parts, out * 0.52 + Vector3(0, 0.08, 0), out * 0.72 + Vector3(0, 0.02, 0), 0.05, bark)
	# A skull peering out of a split in the trunk.
	parts.append([_cube(), _xf(Vector3(0, 0.38, 0.3), Vector3(0.2, 0.32, 0.1)), _grotto_mat("heart")])
	_skull(parts, Vector3(0, 0.38, 0.27), 0.13, Vector3(0, 0.05, 1), _grotto_mat("bone"), _grotto_mat("heart"))
	# Shelf fungus up one side, glowing at the rim.
	var mats := FungalLook.cap_materials()
	var half := SphereMesh.new()
	half.radius = 1.0
	half.height = 1.0
	half.is_hemisphere = true
	half.radial_segments = 10
	half.rings = 3
	for t in [[0.62, 0.2, -1.6], [0.42, 0.16, -1.1], [0.5, 0.13, -2.2]]:
		var a: float = t[2]
		var r: float = t[1]
		var out := Vector3(cos(a), 0, sin(a))
		var turn := Basis(Vector3.UP, -a)
		parts.append([half, Transform3D(turn * Basis.from_scale(Vector3(r * 1.1, r * 0.3, r * 1.4)), out * 0.32 + Vector3(0, t[0], 0)), mats[0]])
		parts.append([_cone(r, r, 0.04, 10), Transform3D(turn * Basis.from_scale(Vector3(1.1, 1, 1.4)), out * 0.32 + Vector3(0, t[0] - 0.02, 0)), mats[1]])
	# Tiny glowcaps round the rim.
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		parts.append_array(FungalLook.mushroom_parts(0.18, 0.07, 0.4, Vector3(cos(a) * 0.3, 0.78, sin(a) * 0.3), -a, 2))
	_baked["hollow_stump"] = _bake(parts)
	return _baked["hollow_stump"]


## The Sandfall Tomb's crates: the head of a fallen colossus sunk to the chin in a drift of
## sand, in a striped headdress of lapis and gold with a cobra on the brow, painted eyes,
## and a plaited beard. Its face looks along -Z.
static func _fallen_head() -> ArrayMesh:
	if _baked.has("fallen_head"):
		return _baked["fallen_head"]
	var parts := []
	var stone := _tomb_mat("stone")
	var dark := _tomb_mat("dark")
	var gold := _tomb_mat("gold")
	var lapis := _tomb_mat("lapis")
	var tilt := Basis(Vector3.RIGHT, -0.08) * Basis(Vector3.FORWARD, 0.06)
	var at := Vector3(0, 0.12, 0)
	# The drift of sand it sank into.
	parts.append([_sphere(), _xf(Vector3(0.04, 0.0, 0.06), Vector3(0.7, 0.17, 0.66)), _tomb_mat("sand")])
	parts.append([_sphere(), _xf(Vector3(-0.26, 0.0, 0.3), Vector3(0.36, 0.12, 0.3)), _tomb_mat("sand")])
	var sand_parts := parts.size()
	# The face: a block rounded at the cheeks, brow, nose, lips and chin.
	parts.append([_cube(), _xf(at + tilt * Vector3(0, 0.42, 0.02), Vector3(0.56, 0.66, 0.56), tilt), stone])
	parts.append([_sphere(), _xf(at + tilt * Vector3(0, 0.4, -0.08), Vector3(0.3, 0.33, 0.24), tilt), stone])
	parts.append([_cube(), _xf(at + tilt * Vector3(0, 0.58, -0.29), Vector3(0.46, 0.05, 0.06), tilt), stone])
	parts.append([_cube(), _xf(at + tilt * Vector3(0, 0.44, -0.33), Vector3(0.08, 0.16, 0.1), tilt * Basis(Vector3.RIGHT, -0.25)), stone])
	parts.append([_cube(), _xf(at + tilt * Vector3(0, 0.29, -0.31), Vector3(0.16, 0.04, 0.05), tilt), _tomb_mat("clay")])
	for side in [-1.0, 1.0]:
		# Painted eyes: dark almonds outlined in gold, a long line out to the temple.
		parts.append([_sphere(), _xf(at + tilt * Vector3(side * 0.12, 0.52, -0.29), Vector3(0.07, 0.03, 0.02), tilt), dark])
		parts.append([_cube(), _xf(at + tilt * Vector3(side * 0.13, 0.5, -0.295), Vector3(0.17, 0.014, 0.01), tilt), gold])
		parts.append([_cube(), _xf(at + tilt * Vector3(side * 0.22, 0.51, -0.285), Vector3(0.08, 0.014, 0.01), tilt * Basis(Vector3.FORWARD, side * 0.25)), lapis])
	# The plaited beard, banded gold and lapis, going down into the sand.
	for k in 4:
		parts.append([_cone(0.055, 0.06, 0.06, 6), _xf(at + tilt * Vector3(0, 0.17 - k * 0.065, -0.27), Vector3.ONE, tilt), gold if k % 2 == 0 else lapis])
	# The headdress: a striped cap over the top and lappets falling either side of the face.
	var cap := Vector3(0.68, 0.18, 0.62)
	for k in 7:
		var x := -cap.x * 0.5 + cap.x * (k + 0.5) / 7.0
		var lift := 0.02 * (1.0 - absf(x) / cap.x * 2.0)
		parts.append([_cube(), _xf(at + tilt * Vector3(x, 0.8 + lift, 0.04), Vector3(cap.x / 7.0 + 0.005, cap.y, cap.z), tilt), gold if k % 2 == 0 else lapis])
	parts.append([_cube(), _xf(at + tilt * Vector3(0, 0.72, -0.27), Vector3(0.66, 0.06, 0.05), tilt), gold])
	for side in [-1.0, 1.0]:
		var lap := tilt * Basis(Vector3.FORWARD, side * -0.22)
		for k in 6:
			var y := 0.66 - k * 0.1
			parts.append([_cube(), _xf(at + tilt * Vector3(side * (0.36 + (0.66 - y) * 0.22), y, -0.1), Vector3(0.1, 0.1, 0.32), lap), gold if k % 2 == 0 else lapis])
	# The cobra rearing on the brow.
	parts.append([_cone(0.025, 0.04, 0.16, 6), _xf(at + tilt * Vector3(0, 0.82, -0.3), Vector3.ONE, tilt), gold])
	parts.append([_sphere(), _xf(at + tilt * Vector3(0, 0.92, -0.31), Vector3(0.06, 0.05, 0.03), tilt), gold])
	# A colossus: the head a little bigger than a man is tall, rising out of the drift.
	for i in range(sand_parts, parts.size()):
		parts[i][1] = (parts[i][1] as Transform3D).scaled(Vector3.ONE * 1.2)
	_baked["fallen_head"] = _bake(parts)
	return _baked["fallen_head"]


## The Sandfall Tomb's barrels: a great scarab of blue-green glaze on a carved sandstone drum,
## its legs gripping the rim and a golden sun held up over its head.
static func _scarab_statue() -> ArrayMesh:
	if _baked.has("scarab_statue"):
		return _baked["scarab_statue"]
	var parts := []
	var stone := _tomb_mat("stone")
	var glaze := _tomb_mat("turq")
	var dark := _tomb_mat("dark")
	var gold := _tomb_mat("gold")
	parts.append([_cone(0.36, 0.42, 0.08, 12), _xf(Vector3(0, 0.04, 0), Vector3.ONE), _tomb_mat("stone_dark")])
	parts.append([_cone(0.34, 0.36, 0.3, 12), _xf(Vector3(0, 0.23, 0), Vector3.ONE), stone])
	_band(parts, 0.365, 0.04, 0.3, _tomb_mat("lapis"))
	_band(parts, 0.38, 0.04, 0.38, stone)
	# The beetle: a domed back split down the middle, a head plate with a toothed edge.
	parts.append([_sphere(), _xf(Vector3(0, 0.46, 0.04), Vector3(0.24, 0.12, 0.3)), glaze])
	parts.append([_cube(), _xf(Vector3(0, 0.555, 0.08), Vector3(0.012, 0.03, 0.4)), dark])
	parts.append([_cube(), _xf(Vector3(0, 0.53, -0.13), Vector3(0.36, 0.02, 0.012)), dark])
	parts.append([_sphere(), _xf(Vector3(0, 0.45, -0.27), Vector3(0.15, 0.07, 0.1)), glaze])
	for k in 5:
		parts.append([_cone(0.0, 0.025, 0.05, 4), _xf(Vector3((k - 2) * 0.05, 0.45, -0.36), Vector3.ONE, Basis(Vector3.RIGHT, -PI / 2)), glaze])
	# Legs gripping the rim of the drum.
	for side in [-1.0, 1.0]:
		for k in 3:
			var z := -0.1 + k * 0.14
			var knee := Vector3(side * 0.3, 0.46, z)
			_rod_part(parts, Vector3(side * 0.16, 0.42, z), knee, 0.022, glaze)
			_rod_part(parts, knee, Vector3(side * 0.38, 0.37, z + 0.04), 0.02, glaze)
	# Its front legs hold up the sun: a gold disc standing over the head.
	_rod_part(parts, Vector3(-0.08, 0.46, -0.28), Vector3(-0.1, 0.62, -0.32), 0.02, glaze)
	_rod_part(parts, Vector3(0.08, 0.46, -0.28), Vector3(0.1, 0.62, -0.32), 0.02, glaze)
	parts.append([_cone(0.2, 0.2, 0.05, 16), _xf(Vector3(0, 0.78, -0.3), Vector3.ONE, Basis(Vector3.RIGHT, PI / 2 - 0.35)), gold])
	parts.append([_cone(0.12, 0.12, 0.06, 16), _xf(Vector3(0, 0.78, -0.3), Vector3.ONE, Basis(Vector3.RIGHT, PI / 2 - 0.35)), _tomb_mat("clay")])
	_baked["scarab_statue"] = _bake(parts)
	return _baked["scarab_statue"]


## Sea-soaked wood, barnacles, weed and shell for the Drowned Vault's cover.
static func _wreck_mat(k: String) -> StandardMaterial3D:
	var key := "wreck_" + k
	if not _baked.has(key):
		match k:
			"wood": _baked[key] = U.mat(Color(0.42, 0.35, 0.25), 0.75)
			"wood_dark": _baked[key] = U.mat(Color(0.17, 0.16, 0.12), 0.75)
			"barnacle": _baked[key] = U.mat(Color(0.72, 0.74, 0.66), 0.8)
			"weed": _baked[key] = U.mat(Color(0.13, 0.32, 0.17), 0.6)
			"paint": _baked[key] = U.mat(Color(0.5, 0.17, 0.12), 0.7)
			"brass": _baked[key] = U.mat(Color(0.66, 0.48, 0.24), 0.35)
			"patina": _baked[key] = U.mat(Color(0.24, 0.5, 0.42), 0.6)
			"glass": _baked[key] = U.mat(Color(0.12, 0.3, 0.3), 0.08, 0.35)
			"hose": _baked[key] = U.mat(Color(0.2, 0.18, 0.16), 0.7)
			"bone": _baked[key] = U.mat(Color(0.74, 0.76, 0.68), 0.8)
			"dark": _baked[key] = U.mat(Color(0.03, 0.05, 0.05), 1.0)
	return _baked[key]


## A point on the outside of an upturned rowboat's hull. `u` runs stern (-1) to bow (1) along
## X, `v` from one gunwale on the floor (-PI/2) over the keel (0) to the other (PI/2). The bow
## comes to a point; the stern stays broad for its flat transom.
static func _hull_at(u: float, v: float, out := 0.0) -> Vector3:
	var w := 0.4 * (pow(maxf(0.0, 1.0 - u * u), 0.55) if u > 0.0 else 1.0 - 0.35 * u * u)
	var h := 0.5 - 0.06 * u * u
	return Vector3(u * 0.68, (h + out) * cos(v) + 0.02, (w + out) * sin(v))


## The Drowned Vault's crates: a rowboat lying keel up where the flood left it, its planks
## crusted with barnacles and hung with weed, a faded red stripe below the gunwale, an oar
## beside it and a drowned sailor's bony legs sticking out from beneath. Length along X.
static func _upturned_boat() -> ArrayMesh:
	if _baked.has("upturned_boat"):
		return _baked["upturned_boat"]
	var parts := []
	var wood := _wreck_mat("wood")
	var dark := _wreck_mat("wood_dark")
	# The hull, built as its own surface (flat-shaded planks show as facets).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 12
	var nv := 8
	for i in nu:
		for j in nv:
			var u0 := -1.0 + 2.0 * i / nu
			var u1 := -1.0 + 2.0 * (i + 1) / nu
			var v0 := -PI / 2 + PI * j / nv
			var v1 := -PI / 2 + PI * (j + 1) / nv
			var a := _hull_at(u0, v0)
			var b := _hull_at(u1, v0)
			var c := _hull_at(u1, v1)
			var d := _hull_at(u0, v1)
			for q in [a, b, c, a, c, d]:   # (wound so the outside faces out)
				st.add_vertex(q)
	# The transom: the flat stern board, closing the hull at u = -1.
	for j in nv:
		var v0 := -PI / 2 + PI * j / nv
		var v1 := -PI / 2 + PI * (j + 1) / nv
		for q in [Vector3(-0.68, 0.02, 0.0), _hull_at(-1.0, v1), _hull_at(-1.0, v0)]:
			st.add_vertex(q)
	st.generate_normals()
	st.index()   # (_bake merges it with indexed shapes: unindexed triangles would be dropped)
	parts.append([st.commit(), Transform3D.IDENTITY, wood])
	# Plank seams along the hull, the keel, and a faded red stripe below the gunwales.
	for v in [-1.15, -0.7, -0.3, 0.3, 0.7, 1.15]:
		for i in 8:
			_rod_part(parts, _hull_at(-1.0 + i / 4.0, v, 0.005), _hull_at(-1.0 + (i + 1) / 4.0, v, 0.005), 0.012, dark)
	for i in 8:
		_rod_part(parts, _hull_at(-1.0 + i / 4.0, 0.0, 0.02), _hull_at(-1.0 + (i + 1) / 4.0, 0.0, 0.02), 0.035, dark)
	for v in [-1.42, 1.42]:
		for i in 8:
			_rod_part(parts, _hull_at(-1.0 + i / 4.0, v, 0.005), _hull_at(-1.0 + (i + 1) / 4.0, v, 0.005), 0.03, _wreck_mat("paint"))
	# Barnacles crusted on, weed hanging over the keel.
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	for i in 18:
		var u := rng.randf_range(-0.9, 0.7)
		var v := rng.randf_range(-1.3, 1.3)
		var p := _hull_at(u, v)
		var up := (_hull_at(u, v, 0.1) - p).normalized()
		parts.append([_cone(0.014, 0.04, 0.04, 5), _xf(p + up * 0.01, Vector3.ONE, Basis(Quaternion(Vector3.UP, up))), _wreck_mat("barnacle")])
	for k in 3:
		var u := -0.55 + k * 0.5
		var side := 1.0 if k % 2 == 0 else -1.0
		var prev := _hull_at(u, 0.0, 0.03)
		for m in 4:
			var at := _hull_at(u + 0.06 * sin(m * 1.7), side * (0.35 + m * 0.38), 0.03)
			_rod_part(parts, prev, at, 0.03 - m * 0.004, _wreck_mat("weed"))
			prev = at
	# An oar lying beside it.
	_rod_part(parts, Vector3(-0.3, 0.035, 0.5), Vector3(0.42, 0.035, 0.66), 0.025, wood)
	parts.append([_cube(), _xf(Vector3(0.54, 0.03, 0.69), Vector3(0.24, 0.02, 0.11), Basis(Vector3.UP, -0.2)), wood])
	# The drowned sailor's legs sticking out from under the stern.
	var bone := _wreck_mat("bone")
	for side in [-1.0, 1.0]:
		var hip := Vector3(-0.56, 0.06, side * 0.1)
		var knee := Vector3(-0.82, 0.16, side * 0.15)
		var foot := Vector3(-1.02, 0.04, side * 0.2)
		_rod_part(parts, hip, knee, 0.028, bone)
		_rod_part(parts, knee, foot, 0.024, bone)
		parts.append([_cube(), _xf(foot + Vector3(-0.04, 0.0, 0), Vector3(0.11, 0.035, 0.06)), bone])
	_baked["upturned_boat"] = _bake(parts)
	return _baked["upturned_boat"]


## The Drowned Vault's barrels: an old brass diving helmet sunk on its collar, green with
## age, portholes all round and a drowned diver's skull looking out of the front one, its
## air hose trailing over the floor. Its face looks along +Z.
static func _diving_helmet() -> ArrayMesh:
	if _baked.has("diving_helmet"):
		return _baked["diving_helmet"]
	var parts := []
	var brass := _wreck_mat("brass")
	var green := _wreck_mat("patina")
	var glass := _wreck_mat("glass")
	# The collar plate and the dome.
	parts.append([_cone(0.36, 0.4, 0.12, 14), _xf(Vector3(0, 0.06, 0), Vector3.ONE), green])
	for k in 8:
		var a := TAU * k / 8.0
		parts.append([_sphere(), _xf(Vector3(cos(a) * 0.36, 0.12, sin(a) * 0.36), Vector3.ONE * 0.03), brass])
	parts.append([_cone(0.3, 0.33, 0.14, 14), _xf(Vector3(0, 0.19, 0), Vector3.ONE), brass])
	parts.append([_sphere(), _xf(Vector3(0, 0.52, 0), Vector3(0.34, 0.36, 0.34)), brass])
	# Green creeping over it in patches.
	parts.append([_sphere(), _xf(Vector3(-0.12, 0.75, -0.08), Vector3(0.2, 0.1, 0.18)), green])
	parts.append([_sphere(), _xf(Vector3(0.22, 0.38, -0.14), Vector3(0.13, 0.12, 0.12)), green])
	# Portholes: the big one in front with the skull behind it, small ones either side and on top.
	# (The front port has no glass: the skull's face fills it, behind three thin bars.)
	var front := Vector3(0, 0.5, 0.32)
	parts.append([_cone(0.13, 0.13, 0.06, 14), _xf(front, Vector3.ONE, Basis(Vector3.RIGHT, PI / 2)), _wreck_mat("dark")])
	_skull(parts, Vector3(0, 0.49, 0.25), 0.15, Vector3(0, 0.1, 1), _wreck_mat("bone"), _wreck_mat("dark"))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.13
	rim.outer_radius = 0.17
	rim.rings = 14
	rim.ring_segments = 4
	parts.append([rim, _xf(front + Vector3(0, 0, 0.04), Vector3(1, 1.4, 1), Basis(Vector3.RIGHT, PI / 2)), green])
	for k in 3:
		parts.append([_cube(), _xf(front + Vector3((k - 1) * 0.075, 0, 0.1), Vector3(0.012, 0.26, 0.012)), brass])
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 0.33, 0.52, 0.04)
		var b := Basis(Vector3.FORWARD, side * PI / 2)
		parts.append([_cone(0.1, 0.1, 0.05, 12), _xf(at, Vector3.ONE, b), green])
		parts.append([_cone(0.075, 0.075, 0.06, 12), _xf(at + Vector3(side * 0.005, 0, 0), Vector3.ONE, b), glass])
	parts.append([_cone(0.08, 0.09, 0.06, 12), _xf(Vector3(0, 0.88, 0), Vector3.ONE), green])
	parts.append([_cone(0.06, 0.06, 0.065, 12), _xf(Vector3(0, 0.89, 0), Vector3.ONE), glass])
	# The air hose: out of the back and in loops over the floor.
	var prev := Vector3(0, 0.5, -0.33)
	for at in [Vector3(0.02, 0.4, -0.5), Vector3(0.1, 0.12, -0.62), Vector3(0.3, 0.04, -0.66), Vector3(0.5, 0.04, -0.5), Vector3(0.62, 0.04, -0.24)]:
		_rod_part(parts, prev, at, 0.04, _wreck_mat("hose"))
		parts.append([_sphere(), _xf(at, Vector3.ONE * 0.04), _wreck_mat("hose")])
		prev = at
	_baked["diving_helmet"] = _bake(parts)
	return _baked["diving_helmet"]


## One half of a split geode: a rough dome of rock bulging along -Y, its cut face at y = 0
## facing +Y, lined with amethyst crystals that glow brightest in the middle.
static func _geode_half(parts: Array, at: Vector3, b: Basis, r: float) -> void:
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 9
	dome.rings = 3
	parts.append([dome, Transform3D(b * Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(r, r * 0.9, r)), at), _mine_mat("rock")])
	parts.append([_cone(r * 0.9, r * 0.9, 0.03, 12), Transform3D(b, at + b * Vector3(0, 0.005, 0)), _mine_mat("crystal_dim")])
	# The shell where it split: a thick rough ring of paler rock round the crystals.
	var rim := TorusMesh.new()
	rim.inner_radius = 0.76
	rim.outer_radius = 1.06
	rim.rings = 9
	rim.ring_segments = 5
	parts.append([rim, Transform3D(b * Basis.from_scale(Vector3(r, r * 0.55, r)), at), _mine_mat("shell")])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r * 1000.0)
	for i in 14:
		var a := TAU * i / 14.0 + rng.randf() * 0.3
		var d := (0.2 + 0.5 * float(i % 3) / 2.0) * r
		var base := Vector3(cos(a) * d, 0.0, sin(a) * d)
		var dir := (Vector3(0, 1, 0) - base.normalized() * 0.35).normalized()
		_prism(parts, at + b * base, b * dir, rng.randf_range(0.12, 0.22) * (1.4 - d / r), rng.randf_range(0.035, 0.055), _mine_mat("crystal") if i % 3 == 0 else _mine_mat("crystal_pale") if i % 3 == 1 else _mine_mat("crystal_dim"))
	_prism(parts, at, b * Vector3.UP, 0.26, 0.065, _mine_mat("crystal_pale"))


## The Amethyst Mine's crates: a great geode the miners split open, one half standing with
## its crystal heart facing out, the other lying rough side up in front of it, its crystals
## showing along the edge. The standing half faces +Z.
static func _split_geode() -> ArrayMesh:
	if _baked.has("split_geode"):
		return _baked["split_geode"]
	var parts := []
	_geode_half(parts, Vector3(-0.04, 0.6, -0.2), Basis(Vector3.RIGHT, PI / 2 - 0.3), 0.6)
	# The other half lies rough side up, tipped so its crystals show along the near edge.
	_geode_half(parts, Vector3(0.14, 0.34, 0.4), Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, PI - 0.75), 0.46)
	# Chips knocked off where it split.
	_rock(parts, Vector3(0.46, 0.06, -0.12), Vector3(0.1, 0.07, 0.09), Basis(Vector3.UP, 0.7), _mine_mat("rock"))
	_prism(parts, Vector3(-0.42, 0.0, 0.3), Vector3(-0.4, 0.3, 1), 0.14, 0.035, _mine_mat("crystal"))
	_prism(parts, Vector3(0.5, 0.0, 0.26), Vector3(0.6, 0.4, 0.5), 0.1, 0.03, _mine_mat("crystal_dim"))
	_baked["split_geode"] = _bake(parts)
	return _baked["split_geode"]


## The Amethyst Mine's barrels: a heap of broken ore, amethyst glinting in it, a pickaxe
## driven into the top with a lantern hung from its handle and a shovel stuck in the side.
static func _ore_heap() -> ArrayMesh:
	if _baked.has("ore_heap"):
		return _baked["ore_heap"]
	var parts := []
	var rock := _mine_mat("shell")
	var wood := _mine_mat("wood")
	var iron := _mine_mat("iron")
	var rng := RandomNumberGenerator.new()
	rng.seed = 83
	_rock(parts, Vector3(0, 0.14, 0), Vector3(0.46, 0.34, 0.44), Basis(Vector3.UP, 0.3), _mine_mat("shell"))
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.4
		var d := rng.randf_range(0.12, 0.34)
		var at := Vector3(cos(a) * d, 0.3 - d * 0.5 + rng.randf() * 0.05, sin(a) * d)
		_rock(parts, at, Vector3.ONE * rng.randf_range(0.08, 0.13), Basis(Vector3.UP, rng.randf() * TAU), rock)
		if i % 2 == 0:
			_prism(parts, at, Vector3(cos(a), 1.2, sin(a)), rng.randf_range(0.14, 0.22), 0.045, _mine_mat("crystal") if i % 4 == 0 else _mine_mat("crystal_pale"))
	# A cluster of amethyst breaking out of the top of the heap.
	for k in 4:
		var a := TAU * k / 4.0 + 0.6
		_prism(parts, Vector3(-0.1, 0.36, 0.08), Vector3(cos(a) * 0.5, 1, sin(a) * 0.5), 0.26 - k * 0.03, 0.055, _mine_mat("crystal") if k % 2 == 0 else _mine_mat("crystal_pale"))
	# The pickaxe driven into the top, its handle up and leaning.
	var grip := Vector3(0.2, 1.02, 0.12)
	var head := Vector3(-0.02, 0.38, -0.02)
	_rod_part(parts, head, grip, 0.025, wood)
	var along := (grip - head).normalized()
	var across := along.cross(Vector3.FORWARD).normalized()
	parts.append([_cone(0.0, 0.035, 0.22, 5), _xf(head + across * 0.11 - along * 0.02, Vector3.ONE, Basis(Quaternion(Vector3.UP, (across - along * 0.5).normalized()))), iron])
	parts.append([_cone(0.0, 0.035, 0.2, 5), _xf(head - across * 0.1 - along * 0.02, Vector3.ONE, Basis(Quaternion(Vector3.UP, (-across - along * 0.6).normalized()))), iron])
	parts.append([_cube(), _xf(head, Vector3(0.07, 0.07, 0.07)), iron])
	# A lantern hung from the handle, lit.
	var hook := grip - along * 0.12
	_rod_part(parts, hook, hook + Vector3(0, -0.12, 0), 0.008, iron)
	var lamp := hook + Vector3(0, -0.24, 0)
	parts.append([_cone(0.075, 0.075, 0.15, 6), _xf(lamp, Vector3.ONE), _mine_mat("lamp")])
	parts.append([_cone(0.03, 0.095, 0.06, 6), _xf(lamp + Vector3(0, 0.1, 0), Vector3.ONE), iron])
	parts.append([_cone(0.095, 0.085, 0.03, 6), _xf(lamp + Vector3(0, -0.09, 0), Vector3.ONE), iron])
	# A shovel stuck in the side of the heap.
	var blade := Vector3(-0.3, 0.16, 0.12)
	var top := Vector3(-0.52, 0.82, 0.26)
	_rod_part(parts, blade, top, 0.022, wood)
	parts.append([_cube(), _xf(top + (top - blade).normalized() * 0.03, Vector3(0.12, 0.03, 0.03), Basis(Vector3.UP, -0.55)), wood])
	parts.append([_cube(), _xf(blade - (top - blade).normalized() * 0.08, Vector3(0.16, 0.2, 0.02), Basis(Quaternion(Vector3.UP, (top - blade).normalized()))), iron])
	_baked["ore_heap"] = _bake(parts)
	return _baked["ore_heap"]


## The Whispering Library's crates: a scribe's desk where someone wrote until they died, an
## open book in front of the chair (+Z), books stacked high at the back, two candles burning,
## an inkwell and quill, a skull resting on the pages and loose pages dropped on the floor.
static func _scribe_desk() -> ArrayMesh:
	if _baked.has("scribe_desk"):
		return _baked["scribe_desk"]
	var parts := []
	var oak := _lib_mat("oak")
	var dark := _lib_mat("oak_dark")
	var brass := _lib_mat("brass")
	var paper := _lib_mat("paper")
	# The desk: a thick top, turned legs, and a pedestal of drawers on one side.
	parts.append([_cube(), _xf(Vector3(0, 0.7, 0), Vector3(1.12, 0.06, 0.72)), oak])
	parts.append([_cube(), _xf(Vector3(0, 0.66, 0), Vector3(1.04, 0.04, 0.64)), dark])
	for x in [-0.5, 0.5]:
		for z in [-0.3, 0.3]:
			if x > 0.0:
				continue
			parts.append([_cone(0.035, 0.045, 0.64, 6), _xf(Vector3(x, 0.32, z), Vector3.ONE), dark])
	parts.append([_cube(), _xf(Vector3(0.36, 0.33, 0), Vector3(0.36, 0.66, 0.62)), oak])
	for k in 3:
		var y := 0.14 + k * 0.2
		parts.append([_cube(), _xf(Vector3(0.36, y, 0.315), Vector3(0.3, 0.15, 0.01)), dark])
		parts.append([_sphere(), _xf(Vector3(0.36, y, 0.325), Vector3.ONE * 0.022), brass])
	# The open book, its pages lifting a little, and a skull resting on it.
	var tilt := Basis(Vector3.RIGHT, -0.08)
	parts.append([_cube(), _xf(Vector3(0, 0.735, 0.08), Vector3(0.62, 0.012, 0.42), tilt), _lib_mat("red")])
	for side in [-1.0, 1.0]:
		parts.append([_cube(), _xf(Vector3(side * 0.15, 0.755, 0.08), Vector3(0.29, 0.03, 0.38), tilt * Basis(Vector3.FORWARD, side * -0.08)), paper])
	for k in 4:
		parts.append([_cube(), _xf(Vector3(-0.16 + (k % 2) * 0.3, 0.774, 0.0 + (k / 2) * 0.14), Vector3(0.2, 0.004, 0.012), tilt), _lib_mat("dark")])
	_skull(parts, Vector3(0.2, 0.84, 0.14), 0.13, Vector3(-0.3, 0.3, 1), _lib_mat("bone"), _lib_mat("dark"))
	# Books stacked high at the back, two candles, the inkwell and quill.
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	_book_stack(parts, Vector3(-0.34, 0.73, -0.2), 6, rng, 1.15)
	_book_stack(parts, Vector3(0.0, 0.73, -0.24), 3, rng, 1.0)
	_candle(parts, Vector3(0.38, 0.73, -0.2), 0.22)
	_candle(parts, Vector3(0.46, 0.73, -0.06), 0.14)
	parts.append([_cone(0.04, 0.05, 0.07, 8), _xf(Vector3(0.36, 0.765, 0.18), Vector3.ONE), _lib_mat("dark")])
	parts.append([_cone(0.0, 0.03, 0.3, 4), _xf(Vector3(0.4, 0.88, 0.16), Vector3(1, 1, 0.3), Basis(Vector3.FORWARD, -0.45)), paper])
	# Loose pages dropped round its feet.
	for k in 4:
		var a := k * 1.7 + 0.4
		parts.append([_cube(), _xf(Vector3(cos(a) * 0.62, 0.008, sin(a) * 0.46 + 0.12), Vector3(0.16, 0.004, 0.2), Basis(Vector3.UP, a * 1.3)), paper])
	_baked["scribe_desk"] = _bake(parts)
	return _baked["scribe_desk"]


## Glass for the hourglass: clear, faintly green.
static func _glass_mat() -> StandardMaterial3D:
	if not _baked.has("glass_mat"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.7, 0.9, 0.85, 0.22)
		m.roughness = 0.05
		m.metallic_specular = 0.9
		_baked["glass_mat"] = m
	return _baked["glass_mat"]


## The Whispering Library's barrels: a great hourglass in a frame of dark oak and brass, its
## sand the library's own ghostly green, glowing as it runs down; a skull among the sand below.
static func _hourglass() -> ArrayMesh:
	if _baked.has("hourglass"):
		return _baked["hourglass"]
	var parts := []
	var oak := _lib_mat("oak")
	var dark := _lib_mat("oak_dark")
	var brass := _lib_mat("brass")
	var sand := _lib_mat("ghost")
	for y in [0.05, 0.97]:
		parts.append([_cone(0.36, 0.36, 0.08, 6), _xf(Vector3(0, y, 0), Vector3.ONE), oak])
		_band(parts, 0.37, 0.025, y + (0.05 if y < 0.5 else -0.05), brass, 6)
	parts.append([_sphere(), _xf(Vector3(0, 1.03, 0), Vector3(0.08, 0.05, 0.08)), brass])
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var at := Vector3(cos(a) * 0.29, 0.51, sin(a) * 0.29)
		parts.append([_cone(0.03, 0.03, 0.86, 6), _xf(at, Vector3.ONE), dark])
		for y in [-0.25, 0.0, 0.25]:
			parts.append([_sphere(), _xf(at + Vector3(0, y, 0), Vector3(0.045, 0.03, 0.045)), dark])
	# The sand: a heap below with a skull half buried, what is left above, the thread falling.
	parts.append([_cone(0.02, 0.17, 0.14, 10), _xf(Vector3(0, 0.16, 0), Vector3.ONE), sand])
	_skull(parts, Vector3(0.06, 0.2, 0.05), 0.07, Vector3(0.6, 0.3, 1), _lib_mat("bone"), _lib_mat("dark"))
	parts.append([_cone(0.13, 0.02, 0.1, 10), _xf(Vector3(0, 0.66, 0), Vector3.ONE), sand])
	parts.append([_cone(0.008, 0.008, 0.36, 4), _xf(Vector3(0, 0.42, 0), Vector3.ONE), sand])
	# The glass: two bulbs meeting at a narrow waist (drawn see-through, over the sand).
	parts.append([_sphere(), _xf(Vector3(0, 0.29, 0), Vector3(0.22, 0.22, 0.22)), _glass_mat()])
	parts.append([_sphere(), _xf(Vector3(0, 0.72, 0), Vector3(0.22, 0.22, 0.22)), _glass_mat()])
	parts.append([_cone(0.05, 0.05, 0.06, 8), _xf(Vector3(0, 0.505, 0), Vector3.ONE), brass])
	_baked["hourglass"] = _bake(parts)
	return _baked["hourglass"]

