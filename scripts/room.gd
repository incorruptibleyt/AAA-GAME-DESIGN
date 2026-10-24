class_name Room
extends Node3D
## Builds one crypt room from a text layout (see layouts.gd) and answers the
## "can I stand here?" questions for movement and bolts. Collision is simple circles and
## a rectangle, which is fast and predictable on phones.
##
## The far end of the room (with the exit door) is towards -Z.

const CELL := 4.0 / 3.0
const HALF_W := Layouts.COLUMNS * CELL * 0.5   # 6
const HALF_L := Layouts.ROWS * CELL * 0.5      # 10
const WALL_H := 2.6
const DOOR_HALF := 1.2

static var current: Room

var obstacles: Array = []   # [{pos: Vector3, r: float}]
var spawns: Array = []      # [{kind: String, pos: Vector3}]
var door_open := false

var _portcullis: Node3D
var _exit_light: OmniLight3D
var _torch_lights: Array[OmniLight3D] = []
var _exit_glow: MeshInstance3D


static func build(parent: Node, layout: Array, label: String) -> Room:
	if current and is_instance_valid(current):
		current.queue_free()
	var room := Room.new()
	room.name = "Room %s" % label
	parent.add_child(room)
	current = room
	room._build_shell()
	room._read_layout(layout)
	return room


static func cell_to_world(col: int, row: int) -> Vector3:
	return Vector3((col - (Layouts.COLUMNS - 1) * 0.5) * CELL, 0.0, (row - (Layouts.ROWS - 1) * 0.5) * CELL)


func player_start() -> Vector3:
	# A little up from the near wall, so the camera can keep the hero above the thumb.
	return Vector3(0, 0, HALF_L - 3.0)


# ---------------------------------------------------------------- building

func _build_shell() -> void:
	var look := Floors.current()
	var wall := U.mat(look.wall, 0.95)
	var trim := U.mat(look.trim, 0.85)
	var dark := U.mat(Color(0.02, 0.02, 0.04), 1.0)

	# Floor: textured flagstones, plus a dark surround so the room edges read clearly.
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = U.stone()
	floor_mat.albedo_color = look.floor
	floor_mat.roughness = 0.75
	floor_mat.uv1_scale = Vector3(3, 5, 1)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var f := U.floor_quad(self, Vector2(HALF_W * 2, HALF_L * 2), floor_mat)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.floor_quad(self, Vector2(70, 90), dark, Vector3(0, -0.05, 0))

	var t := 1.0
	U.box(self, Vector3(t, WALL_H, HALF_L * 2 + t * 2), wall, Vector3(-HALF_W - t / 2, WALL_H / 2, 0))
	U.box(self, Vector3(t, WALL_H, HALF_L * 2 + t * 2), wall, Vector3(HALF_W + t / 2, WALL_H / 2, 0))
	# The near wall is only a low ledge so it never hides the hero from the camera.
	U.box(self, Vector3(HALF_W * 2 + t * 2, 0.5, t), trim, Vector3(0, 0.25, HALF_L + t / 2))
	var side := HALF_W - DOOR_HALF
	U.box(self, Vector3(side, WALL_H, t), wall, Vector3(-DOOR_HALF - side / 2, WALL_H / 2, -HALF_L - t / 2))
	U.box(self, Vector3(side, WALL_H, t), wall, Vector3(DOOR_HALF + side / 2, WALL_H / 2, -HALF_L - t / 2))
	U.box(self, Vector3(1.2, 0.16, HALF_L * 2 + 2), trim, Vector3(-HALF_W - 0.5, WALL_H + 0.08, 0))
	U.box(self, Vector3(1.2, 0.16, HALF_L * 2 + 2), trim, Vector3(HALF_W + 0.5, WALL_H + 0.08, 0))

	_build_door(trim, dark)

	for z in [-6.0, 0.0, 6.0]:
		_add_torch(Vector3(-HALF_W + 0.05, 1.7, z), 1.0)
		_add_torch(Vector3(HALF_W - 0.05, 1.7, z), -1.0)
	apply_graphics(Game._high_graphics)


## Low graphics keeps only the middle pair of torch lights (made a little stronger),
## since every light costs a lot on older phones. The torch flames still show.
func apply_graphics(high: bool) -> void:
	for i in _torch_lights.size():
		var keep := high or i == 2 or i == 3
		_torch_lights[i].visible = keep
		_torch_lights[i].omni_range = 7.0 if high else 11.0
		_torch_lights[i].light_energy = Floors.current().torch_energy * (1.0 if high else 1.2)


func _build_door(trim: Material, dark: Material) -> void:
	var door := Node3D.new()
	door.position = Vector3(0, 0, -HALF_L)
	add_child(door)
	U.box(door, Vector3(0.5, 3.2, 1.3), trim, Vector3(-DOOR_HALF - 0.2, 1.6, -0.4))
	U.box(door, Vector3(0.5, 3.2, 1.3), trim, Vector3(DOOR_HALF + 0.2, 1.6, -0.4))
	U.box(door, Vector3(DOOR_HALF * 2 + 0.9, 0.5, 1.3), trim, Vector3(0, 3.2, -0.4))
	U.box(door, Vector3(DOOR_HALF * 2, 2.8, 0.2), dark, Vector3(0, 1.4, -2.2))
	_exit_glow = U.box(door, Vector3(DOOR_HALF * 2, 2.8, 0.05), U.mat(Color(0.25, 0.45, 1.0), 1.0, 2.0), Vector3(0, 1.4, -2.0))
	_exit_glow.visible = false

	_portcullis = Node3D.new()
	_portcullis.position = Vector3(0, 0, -0.1)
	door.add_child(_portcullis)
	var iron := U.mat(Color(0.17, 0.17, 0.2), 0.4)
	for i in 6:
		var x := lerpf(-DOOR_HALF + 0.15, DOOR_HALF - 0.15, i / 5.0)
		U.box(_portcullis, Vector3(0.1, 2.9, 0.1), iron, Vector3(x, 1.45, 0))
	U.box(_portcullis, Vector3(DOOR_HALF * 2, 0.1, 0.12), iron, Vector3(0, 1.0, 0))
	U.box(_portcullis, Vector3(DOOR_HALF * 2, 0.1, 0.12), iron, Vector3(0, 2.1, 0))

	_exit_light = OmniLight3D.new()
	_exit_light.light_color = Color(0.4, 0.6, 1.0)
	_exit_light.omni_range = 6.0
	_exit_light.light_energy = 0.0
	_exit_light.position = Vector3(0, 1.5, 0.8)
	door.add_child(_exit_light)


func _add_torch(pos: Vector3, facing: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var prefab := Art.get_model(Art.TORCH)
	if prefab:
		Art.place_prop(prefab, root, 0.9)
	else:
		U.box(root, Vector3(0.3, 0.12, 0.12), U.mat(Color(0.2, 0.18, 0.16), 0.5), Vector3(0.15 * facing, -0.15, 0))
		U.box(root, Vector3(0.1, 0.4, 0.1), U.mat(Color(0.35, 0.22, 0.12)), Vector3(0.25 * facing, 0, 0))
		var flame := U.sphere(root, 0.13, U.mat(Color(1.0, 0.6, 0.2), 1.0, 4.0), Vector3(0.25 * facing, 0.28, 0))
		flame.scale = Vector3(1, 1.5, 1)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := Flicker.new()
	light.light_color = Floors.current().torch
	light.omni_range = 7.0
	light.light_energy = 1.4
	light.position = Vector3(0.8 * facing, 0.4, 0)
	root.add_child(light)
	_torch_lights.append(light)


func _read_layout(layout: Array) -> void:
	var stone := U.mat(Color(0.44, 0.42, 0.48), 0.9)
	var wood := U.mat(Color(0.47, 0.3, 0.16), 0.85)
	var iron := U.mat(Color(0.2, 0.2, 0.22), 0.4)
	for row in mini(Layouts.ROWS, layout.size()):
		var line: String = layout[row]
		for col in mini(Layouts.COLUMNS, line.length()):
			var ch := line[col]
			var p := cell_to_world(col, row)
			match ch:
				"#":
					_add_obstacle(p, 0.6)
					var prefab := Art.get_model(Art.PILLAR)
					if prefab:
						Art.place_prop(prefab, _anchor(p), WALL_H + 0.4)
					else:
						U.box(self, Vector3(1.2, 0.3, 1.2), stone, p + Vector3.UP * 0.15)
						U.cylinder(self, 0.45, WALL_H + 0.4, stone, p)
						U.box(self, Vector3(1.1, 0.25, 1.1), stone, p + Vector3.UP * (WALL_H + 0.4))
				"b":
					_add_obstacle(p, 0.45)
					var prefab := Art.get_model(Art.BARREL)
					if prefab:
						Art.place_prop(prefab, _anchor(p), 1.0)
					else:
						U.cylinder(self, 0.4, 0.95, wood, p)
						U.cylinder(self, 0.42, 0.06, iron, p + Vector3.UP * 0.2)
						U.cylinder(self, 0.42, 0.06, iron, p + Vector3.UP * 0.7)
				"c":
					_add_obstacle(p, 0.6)
					var prefab := Art.get_model(Art.CRATES)
					if prefab:
						Art.place_prop(prefab, _anchor(p), 1.4)
					else:
						var a := U.box(self, Vector3.ONE * 0.9, wood, p + Vector3.UP * 0.45)
						a.rotation.y = randf_range(-0.3, 0.3)
						var b := U.box(self, Vector3.ONE * 0.55, wood, p + Vector3(0.1, 1.175, 0.05))
						b.rotation.y = randf_range(0.3, 0.9)
				"^":
					var trap := SpikeTrap.new()
					add_child(trap)
					trap.position = p
				"m", "w", "a", "g", "K", "L", "x", "t", "s":
					spawns.append({"kind": ch, "pos": p})


func _anchor(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = randf() * TAU
	add_child(n)
	return n


func _add_obstacle(p: Vector3, r: float) -> void:
	obstacles.append({"pos": p, "r": r})


# ---------------------------------------------------------------- queries

## Moves a circle of radius `r` by `delta`, sliding along walls and around obstacles.
func resolve_move(pos: Vector3, delta: Vector3, r: float) -> Vector3:
	var p := pos + delta
	p.y = 0.0
	var min_z := -HALF_L + r
	if door_open and absf(p.x) < DOOR_HALF - r * 0.5:
		min_z = -HALF_L - 1.2
	p.x = clampf(p.x, -HALF_W + r, HALF_W - r)
	p.z = clampf(p.z, min_z, HALF_L - r)
	if p.z < -HALF_L + r:
		p.x = clampf(p.x, -DOOR_HALF + r, DOOR_HALF - r)
	for o in obstacles:
		var d: Vector3 = p - o.pos
		d.y = 0.0
		var m: float = o.r + r
		if d.length_squared() < m * m:
			var len := d.length()
			p = o.pos + (d / len * m if len > 0.0001 else Vector3.RIGHT * m)
			p.y = 0.0
	return p


## Bends a walking direction around any pillar or barrel straight ahead, so skeletons
## don't get stuck pushing into one.
func steer(pos: Vector3, dir: Vector3, r: float) -> Vector3:
	for o in obstacles:
		var to: Vector3 = o.pos - pos
		to.y = 0.0
		var ahead := to.dot(dir)
		if ahead <= 0.0 or ahead > o.r + r + 1.2:
			continue
		var side := to - dir * ahead
		if side.length() >= o.r + r:
			continue
		var tangent := dir.cross(Vector3.UP)
		if side.dot(tangent) > 0.0:
			tangent = -tangent
		elif side.length_squared() < 0.0001 and fmod(pos.x + pos.z, 2.0) < 1.0:
			tangent = -tangent
		return (dir + tangent * 1.5).normalized()
	return dir


func blocks_shot(p: Vector3, r: float) -> bool:
	if absf(p.x) > HALF_W - r or absf(p.z) > HALF_L - r:
		return true
	for o in obstacles:
		var d: Vector3 = p - o.pos
		d.y = 0.0
		if d.length_squared() < (o.r + r) * (o.r + r):
			return true
	return false


## True when a bolt could fly from `a` to `b` without hitting a pillar or barrel.
func clear_shot(a: Vector3, b: Vector3) -> bool:
	var steps := int(a.distance_to(b) / 0.4) + 1
	for i in range(1, steps):
		var p := a.lerp(b, float(i) / steps)
		for o in obstacles:
			var d: Vector3 = p - o.pos
			d.y = 0.0
			var m: float = o.r + 0.15   # a bolt's own size, as in blocks_shot
			if d.length_squared() < m * m:
				return false
	return true


func is_at_exit(p: Vector3) -> bool:
	return door_open and p.z < -HALF_L + 0.2


func open_door() -> void:
	if door_open:
		return
	door_open = true
	Sfx.play("door")
	Game.shake(0.15)
	Fx.dust(Vector3(0, 0, -HALF_L), 30)
	_exit_glow.visible = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_portcullis, "position:y", 2.9, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_exit_light, "light_energy", 2.5, 0.9)
