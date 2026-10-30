class_name BoneSpider
extends Enemy
## A fast bone spider (our own model, built by tools/blender/bone_spider.py). It scuttles
## in zig-zags, then crouches, shows a red strip, and pounces along it.

enum Mode { SCUTTLE, CROUCH, POUNCE, REST }
var _mode := Mode.SCUTTLE
var _timer := 1.0
var _dir := Vector3.FORWARD
var _zig := 1.0
var _zig_t := 0.0


func _setup() -> void:
	init_health(24.0)
	move_speed = 4.4
	contact_damage = 8.0
	radius = 0.55
	center_height = 0.5
	knockback_scale = 1.2
	drop_chance = 0.11
	var look := bones("Bone_Spider", 1.15, Color(0.3, 1.0, 0.55))
	look.attack_anim = "Attack"
	make_visual(look)


func _think(hero: Hero, delta: float) -> void:
	var to := hero.global_position - global_position
	to.y = 0.0
	_timer -= delta
	match _mode:
		Mode.SCUTTLE:
			# Zig-zag towards the hero so it's harder to hit.
			_zig_t -= delta
			if _zig_t <= 0.0:
				_zig_t = randf_range(0.35, 0.7)
				_zig = -_zig
			var side := to.normalized().cross(Vector3.UP) * _zig * 0.8
			walk(to.normalized() + side, delta)
			if to.length() < 4.6 and _timer <= 0.0:
				_mode = Mode.CROUCH
				_timer = 0.55
				_dir = to.normalized()
				track(Telegraph.line(global_position, _dir, 5.5, 0.9, 0.55, Callable()))
				Sfx.play("warn", 0.6)
		Mode.CROUCH:
			stand(delta)
			face(_dir, 25.0, delta)
			visual.position.y = -0.12
			if _timer <= 0.0:
				_mode = Mode.POUNCE
				_timer = 0.3
				visual.position.y = 0.0
				visual.attack()
				contact_damage = 15.0
		Mode.POUNCE:
			move_by(_dir * 17.0 * delta, delta)
			if _timer <= 0.0:
				_mode = Mode.REST
				_timer = 0.8
				contact_damage = 8.0
				Fx.dust(global_position, 8)
		Mode.REST:
			stand(delta)
			if _timer <= 0.0:
				_mode = Mode.SCUTTLE
				_timer = 1.2
