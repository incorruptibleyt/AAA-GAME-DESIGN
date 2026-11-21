class_name ShadowStep
extends Node3D
## The Rogue's Shadow Step (version 239, whole-game review fix 8): a dash leaves a shadow
## of the Rogue standing where the dash began. For LIFE seconds it throws knives at the
## nearest skeleton it can see, then fades. It touches nothing and nothing can hit it.
##
## One shadow per hero, built the first time it is needed and moved on every dash after
## (building a character is too slow to do on every dash on a cheap phone).

const LIFE := 2.0
const EVERY := 0.45      # a knife this often
const REACH := 12.0      # at a skeleton this near
const FADE := 0.35
const COL := Color(0.5, 0.32, 1.0)
const KNIFE := Color(0.72, 0.6, 1.0)

var hero: Hero
var visual: CharacterVisual
var _mat: ShaderMaterial
var _left := 0.0
var _alpha := 0.0
var _knife := 0.15
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D


static func make(h: Hero) -> ShadowStep:
	var s := ShadowStep.new()
	s.name = "ShadowStep"
	s.hero = h
	s.top_level = true   # stays where it was left while the hero runs on
	h.add_child(s)
	s._build()
	s.visible = false
	return s


func _build() -> void:
	var look := Heroes.look(Heroes.get_hero(hero.hero_id))
	for k in ["rim", "rim2", "rim_power"]:
		look.erase(k)
	visual = CharacterVisual.new()
	add_child(visual)
	visual.build(look)
	_mat = material()
	for g: GeometryInstance3D in visual._meshes:
		if is_instance_valid(g):
			g.material_override = _mat
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_mat = U.unlit(Color(COL.r, COL.g, COL.b, 0.0), U.soft_circle()).duplicate()
	_ring = U.floor_quad(self, Vector2(1.6, 1.6), _ring_mat, Vector3(0, 0.04, 0))


## The shadow's look: the Crypt Race ghost's see-through glass, in a deep violet.
static func material() -> ShaderMaterial:
	var m := RivalGhost.ghost_material()
	m.set_shader_parameter("col", COL)
	return m


## A dash began at `at`, facing `facing`: the shadow stands there for LIFE seconds.
func appear(at: Vector3, facing: float) -> void:
	global_position = Vector3(at.x, 0.0, at.z)
	rotation = Vector3(0, facing, 0)
	_left = LIFE
	_knife = 0.12
	if not visible:
		_alpha = 0.0
	visible = true
	visual.set_moving(false)
	Fx.magic(global_position + Vector3.UP * 1.0, COL, 10)


func vanish() -> void:
	_left = 0.0
	_alpha = 0.0
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if hero == null or not is_instance_valid(hero) or hero.dead or Game.state != Game.State.PLAYING:
		if Game.state != Game.State.PAUSED:
			vanish()
		return
	_left -= delta
	if _left <= 0.0:
		vanish()
		return
	_alpha = minf(1.0, _alpha + delta * 8.0) if _left > FADE else _left / FADE
	_mat.set_shader_parameter("fade", _alpha * 0.85)
	_ring_mat.albedo_color.a = 0.45 * _alpha
	var foe := _foe()
	if foe == null:
		return
	var to := foe.global_position - global_position
	to.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-24.0 * delta))
	_knife -= delta
	if _knife > 0.0:
		return
	_knife = EVERY
	_throw(to.normalized())


## The nearest skeleton in reach it has a clear line to (or none).
func _foe() -> Actor:
	var near: Array = []
	for a: Actor in Actor.all:
		if a.team == Actor.Team.UNDEAD and a.can_be_hit():
			var d2 := a.global_position.distance_squared_to(global_position)
			if d2 < REACH * REACH:
				near.append([d2, a])
	if near.is_empty():
		return null
	near.sort_custom(func(x, y): return x[0] < y[0])
	for i in mini(near.size(), 3):
		if Room.current == null or Room.current.clear_shot(global_position, near[i][1].global_position):
			return near[i][1]
	return null


func _throw(d: Vector3) -> void:
	visual.attack()
	var h := hero
	var origin := global_position + Vector3.UP * 1.1 + d * 0.5
	var p := Projectile.fire(Actor.Team.HERO, origin, d, h.damage * Hero.KNIFE_SHARE * pow(Hero.TWIN_GAIN, h.front_bolts - 1) * Game.chain_damage(),
		h.bolt_speed * 1.15, KNIFE, h.bolt_size * 0.85, "Shot", "shard")
	p.pierce = h.pierce
	p.push = h.bolt_push * 0.5
	p.crit_chance = h.crit_chance
	p.crit_mult = h.crit_mult
	p.burn_dps = h.burn_dps
	p.frost = h.frost
	p.bounce = int(h.perks.get("ricochet", 0))
	Sfx.play("swing", 0.2, 1.75)
