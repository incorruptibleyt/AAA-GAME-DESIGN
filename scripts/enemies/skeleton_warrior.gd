class_name SkeletonWarrior
extends Enemy
## Slow and tough. Warns with a red strip, then lunges along it.
## On floor 1 (and so in the tutorial run) the warning is longer and the lunge softer,
## so a new player learns to step aside before it really hurts.

enum Mode { APPROACH, WIND_UP, LUNGE, RECOVER }
var _mode := Mode.APPROACH
var _timer := 0.0
var _lunge_dir := Vector3.FORWARD


func _setup() -> void:
	init_health(60.0)
	move_speed = 2.1
	contact_damage = 9.0 if _gentle() else 12.0
	radius = 0.6
	center_height = 1.15
	knockback_scale = 0.4
	var look := bones(Art.SKELETON_WARRIOR, 2.3, Color(1.0, 0.35, 0.2))
	look.helmet = true
	look.shield = true
	look.accent = Color(0.5, 0.15, 0.12)
	look.weapon = "Skeleton_Axe"
	look.offhand = "Skeleton_Shield_Large_A"
	look.attack_anim = "1H_Melee_Attack_Slice_Diagonal"
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	_timer -= delta
	match _mode:
		Mode.APPROACH:
			walk(to, delta)
			if to.length() < 4.2 and _timer <= 0.0:
				_mode = Mode.WIND_UP
				_timer = 0.9 if _gentle() else 0.65
				_lunge_dir = to.normalized()
				track(Telegraph.line(global_position, _lunge_dir, 5.0, 1.1, _timer, Callable()))
		Mode.WIND_UP:
			stand(delta)
			face(_lunge_dir, 25.0, delta)
			if _timer <= 0.0:
				_mode = Mode.LUNGE
				_timer = 0.32
				visual.attack()
				contact_damage = (14.0 if _gentle() else 22.0) * _elite_mult()
		Mode.LUNGE:
			move_by(_lunge_dir * 14.0 * delta, delta)
			if _timer <= 0.0:
				_mode = Mode.RECOVER
				_timer = 0.9
				contact_damage = (9.0 if _gentle() else 12.0) * _elite_mult()
				Fx.dust(global_position, 8)
		Mode.RECOVER:
			stand(delta)
			if _timer <= 0.0:
				_mode = Mode.APPROACH
				_timer = 0.8


func _gentle() -> bool:
	return Game.floor_num == 1


## Elites hit 30% harder (make_elite), lunge included.
func _elite_mult() -> float:
	return 1.3 if elite else 1.0
