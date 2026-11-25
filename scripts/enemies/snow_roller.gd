class_name SnowRoller
extends Enemy
## The Snow Roller (version 243, the Frostfall event): a broad skeleton packing a snowball
## in front of it. It keeps its distance, plants its feet and a strip shows where it will
## shove the ball; then the snowball rolls the length of the hall, growing as it goes, and
## flattens whatever is in the way, skeletons too. Lead its shot through a crowd. Then it
## packs a new ball, which takes a few seconds.

const PACK := 3.2         # seconds to pack the next ball
const AIM := 1.0          # the strip's warning
const ICE := Color(0.6, 0.9, 1.0)

var _pack := 1.6
var _aiming := 0.0
var _aim_dir := Vector3.FORWARD
var _ball: MeshInstance3D


func _setup() -> void:
	die_sound = "die_snow"
	init_health(48.0)
	move_speed = 1.9
	contact_damage = 10.0
	swipe_time = 0.45
	drop_chance = 0.08
	radius = 0.55
	center_height = 1.0
	var look := bones(Art.SKELETON_WARRIOR, 2.0, ICE)
	look.accent = Color(0.18, 0.3, 0.4)
	look.helmet = true
	look.attack_anim = "1H_Melee_Attack_Chop"
	look.hide = ["Skeleton_Warrior_Cloak"]
	look.shape = {"scale": {"chest": Vector3(1.4, 1.1, 1.25), "head": 0.85, "upperarm.l": 1.35, "upperarm.r": 1.35, "upperleg.l": 0.75, "upperleg.r": 0.75}}   # (v347: broad, short-legged)
	look.parts = "snowpack"
	make_visual(look)
	_ball = MeshInstance3D.new()
	_ball.mesh = Snowball._mesh()
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(_ball)
	_set_ball(0.2)


func display_name() -> String:
	return "Snow Roller"


## The ball in its hands: k 0..1 packed.
func _set_ball(k: float) -> void:
	var r := lerpf(0.1, 0.42, clampf(k, 0.0, 1.0))
	_ball.scale = Vector3.ONE * r
	_ball.position = Vector3(0, r + 0.05, -0.55 - r)
	_ball.visible = k > 0.05


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	if _aiming > 0.0:
		_aiming -= delta
		stand(delta)
		face(_aim_dir, 20.0, delta)
		if _aiming <= 0.0:
			_shove()
		return
	_pack -= delta
	_set_ball(1.0 - _pack / PACK)
	if to.length() > 8.0:
		walk(to, delta)
	elif to.length() < 4.5:
		walk(-to, delta, 0.8)
	else:
		stand(delta)
		face(to, 8.0, delta)
	if _pack <= 0.0 and to.length() < 11.0:
		_aim_dir = to.normalized()
		_aiming = AIM
		visual.attack(true)
		track(Telegraph.line(global_position + _aim_dir * 0.8, _aim_dir, 11.0, 1.3, AIM, Callable(), 0.4))


func _shove() -> void:
	_pack = PACK + randf() * 0.8
	_set_ball(0.0)
	visual.attack()
	Sfx.play("swing", 0.6, 0.8)
	Snowball.roll(global_position + _aim_dir * 0.9, _aim_dir, 8.5, 0.42, 0.85, 11.0, 13.0, "Snow Roller")
