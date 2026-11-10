class_name MoonHowler
extends Enemy
## Blood Moon event only (events.gd, version 134). A lean hooded skeleton with a wolf's
## skull grin and blood-red eyes, fast on its feet. It circles you at a distance, then
## howls: a strip shows where it will pounce, and it leaps along it. In a Moon Surge it
## pounces twice in a row (the second strip shows as it lands). Step aside, or dash
## through it for a PERFECT.

enum Mode { CIRCLE, HOWL, POUNCE, RECOVER }

const RED := Color(1.0, 0.24, 0.2)
const POUNCE_LEN := 6.5
const POUNCE_SPEED := 17.0

var _mode := Mode.CIRCLE
var _timer := 1.5
var _dir := Vector3.FORWARD
var _spin := 1.0 if randf() < 0.5 else -1.0
var _again := false


func _setup() -> void:
	init_health(46.0)
	move_speed = 3.3
	contact_damage = 8.0
	swipe_time = 0.5
	radius = 0.5
	center_height = 1.0
	knockback_scale = 0.7
	var look := bones(Art.SKELETON_ROGUE, 2.05, RED)
	look.rim = Color(1.0, 0.2, 0.15, 0.85)
	look.rim_power = 1.8
	look.accent = Color(0.35, 0.05, 0.08)
	look.weapon = "Skeleton_Blade"
	look.attack_anim = "1H_Melee_Attack_Stab"
	make_visual(look)
	_timer = randf_range(1.2, 2.2)


func display_name() -> String:
	return "Moon Howler"


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	_timer -= delta
	match _mode:
		Mode.CIRCLE:
			# Round the hero at about five metres, closing in slowly.
			var want := 5.0
			var radial := to.normalized() * clampf((to.length() - want) * 0.6, -1.0, 1.0)
			var around := to.normalized().cross(Vector3.UP) * _spin
			walk(radial + around, delta)
			if _timer <= 0.0 and to.length() < 7.5:
				_howl(hero)
		Mode.HOWL:
			stand(delta)
			face(_dir, 25.0, delta)
			if _timer <= 0.0:
				_mode = Mode.POUNCE
				_timer = POUNCE_LEN / POUNCE_SPEED
				contact_damage = 15.0 * elite_mult()
				swipe_time = 0.0   # the strip was the warning
				visual.attack()
				Sfx.play("dash", 0.5, 0.8)
		Mode.POUNCE:
			move_by(_dir * POUNCE_SPEED * delta, delta)
			if randf() < delta * 30.0:
				Fx.magic(center(), RED, 1)
			if _timer <= 0.0:
				Fx.dust(global_position, 8)
				contact_damage = 8.0 * elite_mult()
				swipe_time = 0.5
				if _again:
					_again = false
					_howl(hero, 0.38)
				else:
					_mode = Mode.RECOVER
					_timer = 0.8
		Mode.RECOVER:
			stand(delta)
			if _timer <= 0.0:
				_mode = Mode.CIRCLE
				_timer = randf_range(1.8, 2.8)
				_spin = -_spin


## The howl: rears back with a strip along the pounce. In a surge, a second pounce follows.
func _howl(hero: Hero, wind := 0.0) -> void:
	_mode = Mode.HOWL
	if wind <= 0.0:
		wind = 0.7 if Game.floor_num <= 1 and Game.event == "run" else 0.58
		_again = Game.surge > 0.5
		Sfx.play("wraith", 0.3, 0.75)
		Fx.magic(center() + Vector3.UP * 0.6, RED, 10)
	_timer = wind
	_dir = (hero.global_position - global_position)
	_dir.y = 0.0
	_dir = _dir.normalized() if _dir.length() > 0.01 else Vector3.FORWARD
	contact_damage = 0.0
	track(Telegraph.line(global_position, _dir, POUNCE_LEN, 1.0, wind, Callable()))
