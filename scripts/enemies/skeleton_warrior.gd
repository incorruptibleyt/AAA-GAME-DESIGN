class_name SkeletonWarrior
extends Enemy
## Slow and tough. Warns with a red strip, then lunges along it.

enum Mode { APPROACH, WIND_UP, LUNGE, RECOVER }
var _mode := Mode.APPROACH
var _timer := 0.0
var _lunge_dir := Vector3.FORWARD


func _setup() -> void:
	init_health(60.0)
	move_speed = 2.1
	contact_damage = 12.0
	radius = 0.6
	center_height = 1.15
	knockback_scale = 0.4
	make_visual(bones(Art.SKELETON_WARRIOR, 2.3, Color(1.0, 0.35, 0.2)))


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	_timer -= delta
	match _mode:
		Mode.APPROACH:
			walk(to, delta)
			if to.length() < 4.2 and _timer <= 0.0:
				_mode = Mode.WIND_UP
				_timer = 0.65
				_lunge_dir = to.normalized()
				track(Telegraph.line(global_position, _lunge_dir, 5.0, 1.1, 0.65, Callable()))
		Mode.WIND_UP:
			stand(delta)
			face(_lunge_dir, 25.0, delta)
			if _timer <= 0.0:
				_mode = Mode.LUNGE
				_timer = 0.32
				visual.attack()
				contact_damage = 22.0
		Mode.LUNGE:
			move_by(_lunge_dir * 14.0 * delta, delta)
			if _timer <= 0.0:
				_mode = Mode.RECOVER
				_timer = 0.9
				contact_damage = 12.0
				Fx.dust(global_position, 8)
		Mode.RECOVER:
			stand(delta)
			if _timer <= 0.0:
				_mode = Mode.APPROACH
				_timer = 0.8
