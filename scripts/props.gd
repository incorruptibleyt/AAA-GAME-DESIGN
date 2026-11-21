class_name Props
## Each floor has its own things in the corners and on the walls, so floors differ in shape
## and not just in colour: skull piles and candles in the Bone Crypt, icicles and ice
## crystals in the Frozen Ossuary, braziers and lava grates in the Ember Catacomb (on the
## walls, so they never look like fire on the floor), broken columns grown over with kelp
## and drains pouring water in the Drowned Vault, clumps of glowing mushrooms and shelf
## fungus in the Glowcap Grotto, obelisks, jars, painted coffins and sand pouring in through
## cracks in the walls in the Sandfall Tomb. The pieces are simple shapes baked
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
				_no_shadow(_mesh(_place(room, at), _jar() if pick[0] == "@jar" else _ore_pile()))
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
			if roll < 0.5:
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
