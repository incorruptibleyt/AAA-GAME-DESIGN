class_name Stalker
extends Node3D
## The Omen of the Stalker (version 241, whole-game review fix 12): a see-through shade of a
## skeleton knight rises at the far end of every fight and comes for the hero until the room
## is won. Nothing can hurt it and it walks through pillars. It glides in fast while the hero
## stands still (which is when heroes attack) and barely creeps while the hero moves, so a
## fight becomes a rhythm: attack, step away, attack. A touch hurts, and the shade sinks into
## the floor and rises again at the far side of the room a few seconds later.
##
## It is not an Actor: shots, swings and blessings never aim at it, and it never holds a
## room open.
##
## (A first try that simply walked after the hero at 2-2.4 m/s made a robot Knight's room
## last three minutes instead of fifteen seconds: always walking away, never attacking.)

const SPEED := 3.0          # while the hero stands still (the hero walks 5.2)
const CREEP := 0.45         # while the hero moves or dashes
const BOSS_SPEED := 0.8     # slower in a boss fight, where the boss's attacks are the danger
const RISE := 1.2
const SINK := 0.45
const AWAY := 2.6           # seconds under the floor after a touch
const REACH := 0.85
const DAMAGE := 12.0
const COL := Color(0.45, 1.0, 0.82)
const HEIGHT := 2.9         # a head taller than a skeleton warrior
const DISPLAY_NAME := "The Stalker"

var visual: CharacterVisual
var _tag: Label3D
var _mat: ShaderMaterial
var _ring_mat: StandardMaterial3D
var _speed := SPEED
var _creep := CREEP
var _pace := 0.0      # eases between creeping and gliding
var _alpha := 0.0
var _rise := 0.0      # > 0: coming up out of the floor
var _sink := 0.0      # > 0: going down after a touch, or at the end of the fight
var _away := 0.0      # > 0: under the floor, waiting to rise at the far side
var _done := false
var _wisp := 0.0


## Puts a Stalker in `room` at the far end from the hero. `stacks` Omens make it quicker.
static func rise_in(room: Node3D, stacks: int, boss_room: bool) -> Stalker:
	var s := Stalker.new()
	s.name = "Stalker"
	var k := (1.0 + 0.15 * (stacks - 1)) * (BOSS_SPEED if boss_room else 1.0)
	s._speed = SPEED * k
	s._creep = CREEP * k
	room.add_child(s)
	s._build()
	s._come_up(s._far_spot())
	return s


func _build() -> void:
	var look := Enemy.bones(Art.SKELETON_WARRIOR, HEIGHT, COL)
	look.helmet = true
	look.weapon = "Skeleton_Blade"
	look.attack_anim = "1H_Melee_Attack_Slice_Diagonal"
	visual = CharacterVisual.new()
	add_child(visual)
	visual.build(look)
	_mat = RivalGhost.ghost_material()
	_mat.set_shader_parameter("col", COL)
	for g: GeometryInstance3D in visual._meshes:
		if is_instance_valid(g):
			g.material_override = _mat
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_mat = U.unlit(Color(COL.r, COL.g, COL.b, 0.0), U.soft_circle()).duplicate()
	U.floor_quad(self, Vector2(2.4, 2.4), _ring_mat, Vector3(0, 0.04, 0))
	# Named like an elite (enemy.gd), so nobody wastes shots on it.
	_tag = Label3D.new()
	_tag.text = "STALKER"
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = true
	_tag.pixel_size = 0.0006
	_tag.font_size = 34
	_tag.outline_size = 12
	_tag.modulate = COL
	_tag.outline_modulate = Color(0.02, 0.08, 0.06)
	if Hud.UI_FONT:
		_tag.font = Hud.UI_FONT
	_tag.position.y = HEIGHT + 0.5
	add_child(_tag)
	_set_alpha(0.0)


## The spot furthest from the hero along the room, a little to one side.
func _far_spot() -> Vector3:
	var hz := Game.hero.global_position.z if Game.hero else Room.HALF_L
	var z := -signf(hz if absf(hz) > 0.5 else 1.0) * (Room.HALF_L - 1.6)
	var x := randf_range(-Room.HALF_W + 1.6, Room.HALF_W - 1.6)
	return Vector3(x, 0.0, z)


func _come_up(at: Vector3) -> void:
	position = at
	_rise = RISE
	_sink = 0.0
	_away = 0.0
	visible = true
	visual.position.y = -1.6
	Fx.magic(global_position + Vector3.UP * 0.5, COL, 18)
	Fx.dust(global_position, 10)
	Sfx.play("warn", 0.35, 0.7)


func _process(delta: float) -> void:
	if Game.state == Game.State.PAUSED:
		return
	var hero := Game.hero
	var over := hero == null or hero.dead or Game.state != Game.State.PLAYING or not Game.fight_on()
	if over and not _done:
		_done = true
		_sink = SINK
	if _away > 0.0:
		_away -= delta
		if _away <= 0.0 and not _done:
			_come_up(_far_spot())
		return
	if _sink > 0.0:
		_sink = maxf(0.0, _sink - delta)
		var k := _sink / SINK
		_set_alpha(k)
		visual.position.y = -1.6 * (1.0 - k)
		if _sink <= 0.0:
			if _done:
				queue_free()
			else:
				visible = false
				_away = AWAY
		return
	if _rise > 0.0:
		_rise = maxf(0.0, _rise - delta)
		var k := 1.0 - _rise / RISE
		_set_alpha(k)
		visual.position.y = -1.6 * (1.0 - k) * (1.0 - k)
		return
	# Bright and gliding while the hero stands, dim and creeping while the hero moves.
	var still := not hero._moving and not hero.is_dashing()
	_pace = move_toward(_pace, 1.0 if still else 0.0, delta * (3.0 if still else 6.0))
	_set_alpha(move_toward(_alpha, lerpf(0.55, 1.0, _pace), delta * 4.0))
	var to := hero.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))
	visual.set_moving(dist > REACH and _pace > 0.4)
	if dist > REACH:
		var step := to / dist * minf(lerpf(_creep, _speed, _pace) * delta, dist - REACH * 0.8)
		position += step
		position.x = clampf(position.x, -Room.HALF_W + 0.6, Room.HALF_W - 0.6)
		position.z = clampf(position.z, -Room.HALF_L + 0.6, Room.HALF_L - 0.6)
	if dist < REACH + hero.radius * 0.5 and hero.can_be_hit():
		_touch(to / maxf(dist, 0.01))
	_wisp -= delta * _pace
	if _wisp <= 0.0:
		_wisp = 0.3
		Fx.magic(global_position + Vector3.UP * randf_range(0.4, 1.8), COL, 3)


## A touch hurts the hero, then the shade sinks into the floor and comes back later.
func _touch(dir: Vector3) -> void:
	visual.attack()
	Game.hit_source = DISPLAY_NAME
	Game.hero.take_damage(DAMAGE, dir, 9.0)
	Fx.shockwave(global_position, COL, 1.6)
	Sfx.play("swing", 0.5, 0.7)
	_sink = SINK


func _set_alpha(a: float) -> void:
	_alpha = a
	_mat.set_shader_parameter("fade", a * 0.9)
	_ring_mat.albedo_color.a = 0.5 * a
	_tag.modulate.a = a
