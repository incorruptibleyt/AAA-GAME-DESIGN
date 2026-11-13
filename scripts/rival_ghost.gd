class_name RivalGhost
extends Node3D
## The Crypt Race rival, seen (version 155, Supercell review fix 2): while the rival is in the
## same room as you, a see-through copy of its hero runs through your room fighting its own
## run (it touches nothing: no hits, no blocking, nothing to aim at). It comes in at the
## entrance when it catches up, fights round the room, falls when it falls, flinches when
## your surge stuns it, and runs out of the far door when it moves on. So a glance shows who
## is winning, the way you see the other side in an arena game.

static var _ghost_shader: Shader
var _mat: ShaderMaterial
const SPEED := 5.2
const REACH := 5.0         # it "shoots" at a skeleton this near
const SHOT_EVERY := 0.55

var rival: Race.Rival
var room_index := 0
var visual: CharacterVisual
var _alpha := 0.0          # 0 hidden .. 1 fully shown (at SEE)
var _leaving := false
var _target := Vector3.ZERO
var _retarget := 0.0
var _shot := 0.4
var _was_down := false
var _name: Label3D
var _ring: MeshInstance3D
var _facing := Vector3.FORWARD


## A ghost for `r` in room `index`: at the entrance (`entering`, the rival just caught up)
## or somewhere in the room (it was already here when you came in).
static func make(r: Race.Rival, index: int, entering: bool) -> RivalGhost:
	var g := RivalGhost.new()
	g.rival = r
	g.room_index = index
	g.name = "RivalGhost"
	var room := Room.current
	room.add_child(g)
	var start := Vector3(randf_range(-2.0, 2.0), 0, Room.HALF_L - 1.2) if entering \
		else Vector3(randf_range(-Room.HALF_W + 1.5, Room.HALF_W - 1.5), 0, randf_range(-Room.HALF_L + 3.0, 2.0))
	g.position = start
	g._build()
	return g


func _build() -> void:
	var def := Heroes.get_hero(rival.hero_id)
	var look := Heroes.look(def)
	for k in ["rim", "rim2", "rim_power"]:
		look.erase(k)   # (the hologram below draws its own edge)
	visual = CharacterVisual.new()
	add_child(visual)
	visual.build(look)
	visual.set_moving(true)
	# A see-through red hologram of the hero (the game's renderer has no per-object fade, so
	# the ghost is its own material): faint in the middle, bright at the edges, with slow
	# scan lines, so it can never be mistaken for you or for a skeleton.
	_mat = ghost_material()
	for g: GeometryInstance3D in visual._meshes:
		if is_instance_valid(g):
			g.material_override = _mat
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A soft red ring at its feet, and its name over its head.
	_ring = MeshInstance3D.new()
	var disc := TorusMesh.new()
	disc.inner_radius = 0.48
	disc.outer_radius = 0.62
	disc.rings = 24
	disc.ring_segments = 4
	_ring.mesh = disc
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position.y = 0.03
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(RaceScreen.RIVAL, 0.55)
	m.no_depth_test = false
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_name = Label3D.new()
	_name.text = rival.name
	_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name.no_depth_test = true
	_name.fixed_size = true
	_name.pixel_size = 0.0006
	_name.font_size = 36
	_name.outline_size = 10
	_name.modulate = RaceScreen.RIVAL.lightened(0.25)
	_name.outline_modulate = Color(0.08, 0.02, 0.04)
	if Hud.UI_FONT:
		_name.font = Hud.UI_FONT
	_name.position.y = 2.6
	add_child(_name)
	_apply_alpha()


## Called when the rival leaves this room (or the race ends): it runs out of the far door.
func leave() -> void:
	_leaving = true


static func ghost_material() -> ShaderMaterial:
	if _ghost_shader == null:
		_ghost_shader = Shader.new()
		_ghost_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;
uniform vec4 col : source_color = vec4(1.0, 0.35, 0.4, 1.0);
uniform float fade = 1.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.8);
	float y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float scan = 0.85 + 0.15 * sin(y * 40.0 - TIME * 6.0);
	ALBEDO = mix(col.rgb, vec3(1.0, 0.9, 0.9), f * 0.55);
	ALPHA = clamp((0.55 + 0.45 * f) * scan, 0.0, 1.0) * fade;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _ghost_shader
	m.set_shader_parameter("col", RaceScreen.RIVAL.lightened(0.15))
	return m


func _apply_alpha() -> void:
	_mat.set_shader_parameter("fade", _alpha)
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.55 * _alpha
	_name.modulate.a = _alpha
	_name.outline_modulate.a = _alpha


func _process(delta: float) -> void:
	if rival == null or not is_instance_valid(visual):
		queue_free()
		return
	var dt := minf(delta, 0.1)
	_alpha = move_toward(_alpha, 0.0 if (_leaving and position.z < -Room.HALF_L + 0.5) else 1.0, dt * 2.5)
	_apply_alpha()
	if _leaving and _alpha <= 0.0:
		queue_free()
		return
	# Down: it lies there (as you do) until it gets up.
	var is_down := rival.down > 0.0
	if is_down != _was_down:
		_was_down = is_down
		if is_down:
			visual.knock_down()
			Fx.dust(global_position, 10)
		else:
			visual.stand_up()
	if is_down:
		return
	if rival.stun > 0.0:
		visual.set_moving(false)
		if randf() < dt * 6.0:
			Fx.sparks(global_position + Vector3(randf_range(-0.4, 0.4), 1.4, randf_range(-0.4, 0.4)), RaceScreen.TEAL)
		return
	if _leaving:
		_go(Vector3(0, 0, -Room.HALF_L - 1.5), dt)
		return
	# Late in its room it heads for the far door; before that it fights round the room.
	var frac := rival.progress() - room_index
	_retarget -= dt
	if frac > 0.85:
		_target = Vector3(clampf(position.x, -0.8, 0.8), 0, -Room.HALF_L + 1.0)
	elif _retarget <= 0.0 or position.distance_to(_target) < 0.6:
		_retarget = randf_range(1.2, 2.4)
		_target = _pick_target()
	var foe := _nearest_foe()
	_shot -= dt
	if foe != null and global_position.distance_to(foe.global_position) < REACH and frac <= 0.85:
		visual.set_moving(false)
		_face(foe.global_position - global_position, dt)
		if _shot <= 0.0:
			_shot = SHOT_EVERY * randf_range(0.85, 1.2)
			_fire(foe.global_position)
		return
	_go(_target, dt)


func _go(to: Vector3, dt: float) -> void:
	var d := to - position
	d.y = 0.0
	if d.length() < 0.15:
		visual.set_moving(false)
		return
	visual.set_moving(true)
	var dir := d.normalized()
	if Room.current:
		dir = Room.current.steer(position, dir, 0.45)
	position += dir * minf(SPEED * dt, d.length())
	position.x = clampf(position.x, -Room.HALF_W + 0.5, Room.HALF_W - 0.5)
	position.z = clampf(position.z, -Room.HALF_L - 1.6, Room.HALF_L - 0.5)
	_face(dir, dt)


func _face(dir: Vector3, dt: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_facing = _facing.slerp(dir.normalized(), 1.0 - exp(-12.0 * dt)).normalized()
	rotation.y = atan2(-_facing.x, -_facing.z)


## Somewhere to go: near a skeleton (it fights where the fight is), else anywhere open.
func _pick_target() -> Vector3:
	var foes: Array = []
	for a: Actor in Actor.all:
		if a is Enemy and not a.dead:
			foes.append(a)
	if not foes.is_empty() and randf() < 0.75:
		var f: Enemy = foes.pick_random()
		var p := f.global_position - (Room.current.global_position if Room.current else Vector3.ZERO)
		return p + Vector3(randf_range(-3.0, 3.0), 0, randf_range(2.0, 4.0))
	return Vector3(randf_range(-Room.HALF_W + 1.5, Room.HALF_W - 1.5), 0, randf_range(-Room.HALF_L + 2.5, Room.HALF_L - 2.5))


func _nearest_foe() -> Enemy:
	var best: Enemy = null
	var bd := INF
	for a: Actor in Actor.all:
		if a is Enemy and not a.dead:
			var d := global_position.distance_squared_to(a.global_position)
			if d < bd:
				bd = d
				best = a
	return best


## It swings or shoots at a skeleton, and a small red puff shows where. No bolt flies: a
## bolt in the air would look like one to dodge, and the rival is only fighting its own run.
func _fire(at: Vector3) -> void:
	visual.attack()
	Fx.magic(at + Vector3.UP * 0.9, RaceScreen.RIVAL, 4)
