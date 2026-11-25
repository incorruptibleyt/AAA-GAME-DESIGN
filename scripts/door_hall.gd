class_name DoorHall
extends Node3D
## Version 374 (visual review of 366, fix 7 "rooms between rooms"): the passage beyond a
## room's exit, where the two doors to choose from stand as real archways in the crypt.
## CHOOSE YOUR DOOR was two drawn arches on a flat purple screen; now the game's own camera
## looks down a short hall of this floor's stone at two carved doorways, each lit from
## inside with the colour of what waits behind it, the light spilling over the flagstones,
## and the hero standing before them. The words (Hud.show_doors) sit in the doorways.
##
## Built far past the room's far wall as a child of the room, so it goes when the room goes;
## nothing here is drawn while the fight is on (it is out of the camera's sight).

const ARCH_W := 3.0      # a doorway's width
const ARCH_H := 5.3      # ... and its height
const ARCH_X := 2.0      # each doorway's middle, left and right of the hall's middle
const WALL_Z := -5.0     # the wall the doorways are in (hall space)
const VIEW_W := 8.5      # metres of that wall the camera shows across the phone
const LOOK_Y := 4.05     # the height the camera looks at (the doorways sit below the title)
const FAR := 45.0        # how far past the room's far wall the hall is built

## The hall on show (null when there is none).
static var current: DoorHall = null
static var _glow_shader: Shader

var _glow: Array[ShaderMaterial] = []
var _gems: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _press: Array[float] = [0.0, 0.0]
var _press_to: Array[float] = [0.0, 0.0]
var _age := 0.0


## Builds the hall behind `room` with a doorway for each colour (two) and stands the hero in
## front of them. Returns null if it can't.
static func open(room: Room, colors: Array) -> DoorHall:
	if room == null or colors.size() < 2:
		return null
	if current != null and is_instance_valid(current):
		current.queue_free()
	var h := DoorHall.new()
	h.process_mode = Node.PROCESS_MODE_ALWAYS   # (the tree is paused while the doors show)
	room.add_child(h)
	h.position = Vector3(0, 0, -Room.HALF_L - FAR)
	h._build(colors)
	current = h
	if Game.hero and is_instance_valid(Game.hero):
		Game.hero.place_at(h.to_global(Vector3(0, 0, WALL_Z + 3.3)))
	return h


## Whether the camera should look at the hall now.
static func showing() -> bool:
	return current != null and is_instance_valid(current) and not current.is_queued_for_deletion() and current.is_inside_tree()


func _exit_tree() -> void:
	if current == self:
		current = null


func _build(colors: Array) -> void:
	var look := Floors.current()
	var wall := Room._wall_material(look, U.mat(look.wall, 0.95))
	var trim := U.mat(look.trim, 0.85)
	var dark := U.mat(Color(0.015, 0.012, 0.03), 1.0)
	# The floor: this place's own, as it lies by a room's far wall.
	var fm := Room._floor_material(look) as ShaderMaterial
	if fm:
		fm.set_shader_parameter("shift", Vector2(0, -Room.HALF_L - WALL_Z))
		fm.set_shader_parameter("blood", 0.0)
		fm.set_shader_parameter("half_size", Vector2(40, 40))
	var f := U.floor_quad(self, Vector2(26, 18), fm if fm else U.mat(look.floor, 0.9), Vector3(0, 0, WALL_Z + 9.0))
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The wall: stone to the sides of, between and above the doorways.
	var t := 1.2
	var high := 16.0
	var edge := ARCH_X + ARCH_W * 0.5
	var mid := ARCH_X * 2.0 - ARCH_W
	for side: float in [-1.0, 1.0]:
		U.box(self, Vector3(10.0, high, t), wall, Vector3(side * (edge + 5.0), high * 0.5, WALL_Z - t * 0.5))
	U.box(self, Vector3(mid, ARCH_H, t), wall, Vector3(0, ARCH_H * 0.5, WALL_Z - t * 0.5))
	U.box(self, Vector3(edge * 2.0, high - ARCH_H, t), wall, Vector3(0, (high + ARCH_H) * 0.5, WALL_Z - t * 0.5))
	# A cornice of the floor's trim over the doorways, and a low plinth along the wall.
	U.box(self, Vector3(20.0, 0.3, 0.5), trim, Vector3(0, ARCH_H + 1.75, WALL_Z + 0.2))
	U.box(self, Vector3(20.0, 0.14, 0.3), trim, Vector3(0, ARCH_H + 1.42, WALL_Z + 0.1))
	for i in 2:
		var x := (-1.0 if i == 0 else 1.0) * ARCH_X
		var col: Color = colors[i]
		_doorway(x, col, trim, dark)
	# A fire bowl on the stone between the doors, burning in this place's own light.
	var iron := U.mat(Color(0.12, 0.11, 0.14), 0.5)
	var bowl := Node3D.new()
	bowl.position = Vector3(0, 3.55, WALL_Z)
	add_child(bowl)
	U.box(bowl, Vector3(0.16, 0.16, 0.7), iron, Vector3(0, 0.0, 0.3))
	U.cylinder(bowl, 0.34, 0.2, iron, Vector3(0, 0.02, 0.62))
	U.cylinder(bowl, 0.26, 0.06, U.mat(Color(1.0, 0.55, 0.15), 1.0, 3.0), Vector3(0, 0.2, 0.62))
	Fx.flame(bowl, Vector2(0.75, 1.15), Vector3(0, 0.72, 0.62))
	var fl := Flicker.new()
	fl.light_color = look.torch
	fl.omni_range = 8.0
	fl.light_energy = 1.7
	fl.position = Vector3(0, 4.3, WALL_Z + 1.3)
	fl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fl)


## One doorway: a frame of carved trim with stepped corbels under the lintel, a keystone set
## with a gem, a step at its foot, and the light of what is behind it.
func _doorway(x: float, col: Color, trim: Material, dark: Material) -> void:
	var d := Node3D.new()
	d.position = Vector3(x, 0, WALL_Z)
	add_child(d)
	var hw := ARCH_W * 0.5
	# the frame stands a little proud of the wall
	for side: float in [-1.0, 1.0]:
		U.box(d, Vector3(0.42, ARCH_H, 0.5), trim, Vector3(side * (hw + 0.21), ARCH_H * 0.5, 0.05))
		# corbels: two steps closing the top corners, as a pointed arch built of blocks
		U.box(d, Vector3(0.82, 0.5, 1.3), trim, Vector3(side * (hw - 0.41), ARCH_H - 0.25, -0.35))
		U.box(d, Vector3(0.44, 0.5, 1.3), trim, Vector3(side * (hw - 0.22), ARCH_H - 0.75, -0.35))
		U.box(d, Vector3(0.2, 0.45, 1.3), trim, Vector3(side * (hw - 0.1), ARCH_H - 1.22, -0.35))
		# a block at the foot of each jamb
		U.box(d, Vector3(0.6, 0.5, 0.66), trim, Vector3(side * (hw + 0.21), 0.25, 0.1))
	U.box(d, Vector3(ARCH_W + 1.2, 0.62, 0.6), trim, Vector3(0, ARCH_H + 0.31, 0.08))
	U.box(d, Vector3(0.62, 0.95, 0.7), trim, Vector3(0, ARCH_H + 0.36, 0.14))
	var gem := U.mat(col.lerp(Color(col.r * 0.6, col.g * 0.6, col.b * 0.6), 0.5), 0.3, 0.35)
	_gems.append(gem)
	var g := U.sphere(d, 0.2, gem, Vector3(0, ARCH_H + 0.4, 0.5))
	g.scale = Vector3(1.0, 1.25, 0.6)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the step
	U.box(d, Vector3(ARCH_W + 0.2, 0.16, 1.5), trim, Vector3(0, 0.08, 0.3))
	# the dark beyond, and its light
	U.box(d, Vector3(ARCH_W + 0.4, ARCH_H + 0.2, 0.2), dark, Vector3(0, ARCH_H * 0.5, -2.6))
	U.box(d, Vector3(ARCH_W + 0.4, 0.1, 2.6), dark, Vector3(0, 0.02, -1.3))
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = GLOW
	var gm := ShaderMaterial.new()
	gm.shader = _glow_shader
	gm.set_shader_parameter("col", col)
	gm.set_shader_parameter("lit", 0.0)
	_glow.append(gm)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(ARCH_W, ARCH_H)
	q.mesh = qm
	q.material_override = gm
	q.position = Vector3(0, ARCH_H * 0.5, -1.25)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(q)
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 8.0
	l.light_energy = 0.0
	l.position = Vector3(0, 1.3, 0.9)
	d.add_child(l)
	_lights.append(l)


## Light rising from beyond the threshold: bright at the foot, dark at the top (where the
## door's name is written), with slow shafts drifting across it.
const GLOW := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 col : source_color = vec4(0.6, 0.75, 1.0, 1.0);
uniform float lit = 1.0;

void fragment() {
	float y = 1.0 - UV.y;
	float rise = pow(1.0 - y, 3.4);
	float shaft = 0.5 + 0.5 * sin(UV.x * 11.0 + TIME * 0.6 + sin(TIME * 0.37 + y * 4.0) * 1.3);
	float side = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
	float glow = rise * (1.05 + 0.3 * shaft) + 0.09 * side;
	vec3 c = mix(col.rgb, vec3(1.0), rise * rise * 0.55) * glow;
	ALBEDO = c * lit + vec3(0.012, 0.01, 0.022);
}
"""


func _process(delta: float) -> void:
	_age += delta
	for i in _glow.size():
		_press[i] = move_toward(_press[i], _press_to[i], delta * 8.0)
		# the light comes on behind each door in turn
		var lit := clampf((_age - 0.15 - 0.22 * i) * 1.8, 0.0, 1.0) * (1.0 + 0.45 * _press[i])
		_glow[i].set_shader_parameter("lit", lit)
		_lights[i].light_energy = 3.4 * lit
		_gems[i].emission_energy_multiplier = 0.35 + 0.55 * lit   # (a lit jewel, not a white lamp)


## A thumb is on door `i` (its light swells).
func press(i: int, on: bool) -> void:
	if i >= 0 and i < _press_to.size():
		_press_to[i] = 1.0 if on else 0.0


## Puts `cam` where it sees the two doorways across the phone's width, whatever the phone's
## shape (a taller phone sees more floor and more wall), drifting in a little as it opens.
## `settled`: where it comes to rest (for laying out the words).
func pose(cam: Camera3D, settled := false) -> void:
	var size := cam.get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var half_h := atan(tan(deg_to_rad(cam.fov) * 0.5) * aspect)
	var dist := VIEW_W * 0.5 / tan(half_h)
	var ease_in := 1.0 if settled else 1.0 - pow(1.0 - clampf(_age / 0.8, 0.0, 1.0), 3.0)
	dist *= lerpf(1.05, 1.0, ease_in)
	var eye := to_global(Vector3(0, LOOK_Y + 0.5, WALL_Z + dist))
	cam.look_at_from_position(eye, to_global(Vector3(0, LOOK_Y, WALL_Z)))


## Doorway `i`'s place on screen (the opening itself), for the words written in it.
func door_rect(cam: Camera3D, i: int) -> Rect2:
	var x := (-1.0 if i == 0 else 1.0) * ARCH_X
	var a := cam.unproject_position(to_global(Vector3(x - ARCH_W * 0.5, ARCH_H, WALL_Z)))
	var b := cam.unproject_position(to_global(Vector3(x + ARCH_W * 0.5, 0.0, WALL_Z)))
	return Rect2(a, b - a)
